/*
 * sync_frame.c: doupdate brackets a frame that changes the screen with the
 * terminal's Sync capability exactly once (patches/0008).
 *
 * Linked against the host libncursesw.a.  Draws a frame, refreshes, then
 *   frame A: changes every line      -> output starts with Sync(1), ends with Sync(0),
 *                                       each present exactly once, and it is one write
 *   frame B: refresh with no change  -> no bytes at all (no Sync)
 *   frame C: rewrites the same text  -> nothing drawn: no Sync
 * and prints "begin=<n> end=<n> first=<0|1> last=<0|1> writes=<w> | empty=<bytes> same=<bytes>".
 * Usage: sync_frame expect-sync | expect-none   (the terminal comes from $TERM)
 * Exit 0 when the output matches the expectation.
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/uio.h>
#include <unistd.h>
#include <curses.h>

static long wr_calls;
static int wr_on;

ssize_t
write(int fd, const void *buf, size_t len)
{
    struct iovec iov;
    if (wr_on)
	wr_calls++;
    iov.iov_base = (void *) buf;
    iov.iov_len = len;
    return writev(fd, &iov, 1);
}

static size_t
drain(int fd, char *buf, size_t max)
{
    size_t n = 0;
    ssize_t r;
    while (n < max && (r = read(fd, buf + n, max - n)) > 0)
	n += (size_t) r;
    return n;
}

static int
count(const char *buf, size_t n, const char *pat)
{
    size_t pl = strlen(pat), i;
    int c = 0;
    for (i = 0; i + pl <= n; i++)
	if (memcmp(buf + i, pat, pl) == 0)
	    c++;
    return c;
}

static void
fill(const char *tag)
{
    int y;
    for (y = 0; y < LINES; ++y)
	mvprintw(y, 0, "%s line %02d", tag, y);
}

int
main(int argc, char **argv)
{
    static char buf[65536];
    int pfd[2], expect_sync, begin, end, first, last, ok;
    size_t n, nempty, nsame;
    long writes;
    const char *on = "\033[?2026h", *off = "\033[?2026l";
    FILE *out;
    SCREEN *sp;

    if (argc != 2 || pipe(pfd) != 0)
	return 2;
    expect_sync = strcmp(argv[1], "expect-sync") == 0;
    fcntl(pfd[0], F_SETFL, O_NONBLOCK);
    out = fdopen(pfd[1], "w");
    sp = newterm(NULL, out, stdin);
    if (sp == NULL) {
	fprintf(stderr, "newterm failed (TERM=%s)\n", getenv("TERM") ? getenv("TERM") : "");
	return 2;
    }
    fill("one");
    refresh();
    drain(pfd[0], buf, sizeof(buf));

    fill("two");
    wr_on = 1;
    refresh();
    wr_on = 0;
    n = drain(pfd[0], buf, sizeof(buf));
    writes = wr_calls;
    begin = count(buf, n, on);
    end = count(buf, n, off);
    first = n >= strlen(on) && memcmp(buf, on, strlen(on)) == 0;
    last = n >= strlen(off) && memcmp(buf + n - strlen(off), off, strlen(off)) == 0;

    refresh();			/* nothing changed */
    nempty = drain(pfd[0], buf, sizeof(buf));
    fill("two");		/* same text again: lines are dirty, nothing to draw */
    refresh();
    nsame = drain(pfd[0], buf, sizeof(buf));

    endwin();
    delscreen(sp);
    printf("begin=%d end=%d first=%d last=%d writes=%ld | empty=%lu same=%lu\n",
	   begin, end, first, last, writes, (unsigned long) nempty, (unsigned long) nsame);
    if (expect_sync)
	ok = begin == 1 && end == 1 && first && last && writes == 1 && nempty == 0 && nsame == 0;
    else
	ok = begin == 0 && end == 0 && nempty == 0 && nsame == 0;
    return ok ? 0 : 1;
}
