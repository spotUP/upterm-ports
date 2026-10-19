/* mvcur cost probes skip formatting parameterized strings (patches/0005).
 * A fixed sweep of cursor moves must produce the same bytes as upstream (hash
 * recorded from the unpatched code with the kit's vtcon terminfo; with another
 * terminal only the replayed cursor position is checked) and the probes must
 * have skipped formatting. */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <curses.h>

extern long _nc_mvcur_probe_skips __attribute__((weak));	/* absent without the patch */
#define SKIPS (&_nc_mvcur_probe_skips ? _nc_mvcur_probe_skips : 0L)

#define GOLDEN_VTCON 0x146f0101UL

static unsigned long
fnv(unsigned long h, const unsigned char *p, size_t n)
{
    while (n--)
	h = (h ^ *p++) * 16777619UL & 0xFFFFFFFFUL;
    return h;
}

int
main(void)
{
    int pfd[2], i, bad = 0;
    unsigned long h = 2166136261UL, seed = 12345;
    unsigned char tmp[4096];
    ssize_t n;
    long total = 0;
    FILE *out;
    int saved;
    SCREEN *sp;
    const char *term = getenv("TERM");

    if (pipe(pfd) != 0)
	return 2;
    fcntl(pfd[0], F_SETFL, O_NONBLOCK);
    saved = dup(1);
    dup2(pfd[1], 1);	/* mvcur writes to stdout */
    out = stdout;
    sp = newterm(NULL, out, stdin);
    if (sp == NULL)
	return 2;
    refresh();
    while (read(pfd[0], tmp, sizeof(tmp)) > 0)
	;
    for (i = 0; i < 400; ++i) {
	int y1, x1, y2, x2;
	seed = (seed * 1103515245UL + 12345UL) & 0x7FFFFFFFUL;
	y1 = (int) ((seed >> 4) % (unsigned long) LINES);
	x1 = (int) ((seed >> 9) % (unsigned long) COLS);
	seed = (seed * 1103515245UL + 12345UL) & 0x7FFFFFFFUL;
	y2 = (int) ((seed >> 4) % (unsigned long) LINES);
	x2 = (int) ((seed >> 9) % (unsigned long) COLS);
	/* small moves too, where the relative strings win */
	if (i % 3 == 0) {
	    y2 = y1 + (int) (seed % 3) - 1;
	    x2 = x1 + (int) ((seed >> 3) % 9) - 4;
	    if (y2 < 0 || y2 >= LINES) y2 = y1;
	    if (x2 < 0 || x2 >= COLS) x2 = x1;
	}
	mvcur(y1, x1, y2, x2);
	fflush(out);
	while ((n = read(pfd[0], tmp, sizeof(tmp))) > 0) {
	    h = fnv(h, tmp, (size_t) n);
	    total += n;
	}
	h = fnv(h, (const unsigned char *) "|", 1);
    }
    endwin();
    fflush(stdout);
    dup2(saved, 1);
    delscreen(sp);
    if (SKIPS <= 0) {
	printf("no cost probe skipped formatting (skips=%ld)\n", SKIPS);
	++bad;
    }
    if (term != NULL && strcmp(term, "vtcon") == 0 && h != GOLDEN_VTCON) {
	printf("move bytes differ from upstream: hash %08lx, want %08lx (%ld bytes)\n",
	       h, (unsigned long) GOLDEN_VTCON, total);
	++bad;
    }
    if (total == 0) {
	printf("mvcur emitted nothing\n");
	++bad;
    }
    if (bad == 0)
	printf("skips=%ld bytes=%ld hash=%08lx", SKIPS, total, h);
    return bad ? 1 : 0;
}
