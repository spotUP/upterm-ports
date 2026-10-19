/*
 * frame_write.c: one doupdate() is one write().
 *
 * Statically linked against the host libncursesw.a, this program defines
 * write() itself, so every write the library makes lands here (the linker
 * binds the archive's references to the executable's definition).  It
 * draws a full screen, refreshes, then changes every line and refreshes
 * again: that second frame must leave doupdate as ONE write.  Before the
 * ewRunning patch (patches/0001) newterm left the screen in ewInitial and
 * _nc_mvcur flushed after every cursor move, so a frame was ~LINES writes
 * (the Amiga handler drew the screen line by line).
 *
 * Output goes to a pipe (no terminal needed); the program drains it after
 * each frame.  Prints "writes=<n> bytes=<b>" for the second frame and exits
 * 0 when n == 1.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/uio.h>
#include <unistd.h>
#include <curses.h>

static long wr_calls, wr_bytes;
static int wr_on;

ssize_t
write(int fd, const void *buf, size_t len)
{
    struct iovec iov;
    if (wr_on) {
	wr_calls++;
	wr_bytes += (long) len;
    }
    iov.iov_base = (void *) buf;
    iov.iov_len = len;
    return writev(fd, &iov, 1);	/* the real system call, no recursion */
}

static void
drain(int fd)
{
    char tmp[4096];
    while (read(fd, tmp, sizeof(tmp)) > 0)
	;
}

static void
fill(int frame)
{
    int y;
    for (y = 0; y < LINES; ++y) {
	wattrset(stdscr, COLOR_PAIR(1 + (y + frame) % 2) | ((y & 1) ? A_BOLD : 0));
	mvprintw(y, 0, "frame %d line %02d %*s", frame, y, COLS - 20, "");
    }
}

int
main(void)
{
    int pfd[2];
    FILE *out;
    SCREEN *sp;

    if (pipe(pfd) != 0) {
	perror("pipe");
	return 2;
    }
    fcntl(pfd[0], F_SETFL, O_NONBLOCK);
    out = fdopen(pfd[1], "w");
    sp = newterm(NULL, out, stdin);
    if (sp == NULL) {
	fprintf(stderr, "newterm failed (TERM=%s)\n", getenv("TERM") ? getenv("TERM") : "");
	return 2;
    }
    if (has_colors()) {
	start_color();
	init_pair(1, COLOR_WHITE, COLOR_BLUE);
	init_pair(2, COLOR_YELLOW, COLOR_BLACK);
    }
    fill(0);
    refresh();
    drain(pfd[0]);

    wr_on = 1;
    fill(1);
    refresh();
    wr_on = 0;
    drain(pfd[0]);

    endwin();
    delscreen(sp);
    printf("writes=%ld bytes=%ld lines=%d\n", wr_calls, wr_bytes, LINES);
    return wr_calls == 1 ? 0 : 1;
}
