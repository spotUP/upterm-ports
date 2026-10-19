#define _XOPEN_SOURCE_EXTENDED 1
#define NCURSES_WIDECHAR 1
/* The vid_puts attribute memo (patches/0004).  Bold, plain, bold, plain on one
 * colour pair must emit the same bytes as the real code (memo off), the repeats
 * must hit the memo, verify mode must find no difference, and a changed colour
 * pair must flush the memo so the new colours come out. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curses.h>
#include <term.h>

extern int _nc_vidmemo_mode;
extern long _nc_vidmemo_hits, _nc_vidmemo_misses, _nc_vidmemo_bad;

static char cap[4096];
static size_t caplen;

static int
outc(int c)
{
    if (caplen < sizeof(cap) - 1)
	cap[caplen++] = (char) c;
    return c;
}

/* one run of the sequence; each step's bytes are appended, separated by '|' */
static void
run(char *dst, size_t n, short fg2)
{
    static const struct {
	attr_t a;
	short p;
    } step[] = {
	{A_BOLD, 1}, {A_NORMAL, 0}, {A_BOLD, 1}, {A_NORMAL, 0},
	{A_REVERSE, 1}, {A_BOLD, 1}, {A_UNDERLINE, 2}, {A_BOLD, 1}
    };
    size_t i, used = 0;
    init_pair(1, COLOR_WHITE, COLOR_BLUE);
    init_pair(2, fg2, COLOR_BLACK);
    vid_puts(A_NORMAL, 0, NULL, outc);
    for (i = 0; i < sizeof(step) / sizeof(step[0]); ++i) {
	caplen = 0;
	vid_puts(step[i].a, step[i].p, NULL, outc);
	if (used + caplen + 2 < n) {
	    memcpy(dst + used, cap, caplen);
	    used += caplen;
	    dst[used++] = '|';
	}
    }
    dst[used] = '\0';
}

int
main(void)
{
    char real[2048], memo[2048], flushed[2048], after[2048], verify[2048];
    int bad = 0;
    long hits0;
    FILE *out = fopen("/dev/null", "w");
    SCREEN *sp = newterm(NULL, out, stdin);

    if (sp == NULL || !has_colors()) {
	fprintf(stderr, "no colour terminal\n");
	return 2;
    }
    start_color();

    _nc_vidmemo_mode = 0;
    run(real, sizeof(real), COLOR_YELLOW);
    _nc_vidmemo_mode = 1;
    run(memo, sizeof(memo), COLOR_YELLOW);
    hits0 = _nc_vidmemo_hits;
    run(memo, sizeof(memo), COLOR_YELLOW);
    if (strcmp(real, memo) != 0) {
	printf("memo bytes differ from the real code\n");
	++bad;
    }
    if (_nc_vidmemo_hits == hits0) {
	printf("second run of the sequence had no memo hits (hits=%ld misses=%ld)\n",
	       _nc_vidmemo_hits, _nc_vidmemo_misses);
	++bad;
    }
    _nc_vidmemo_mode = 2;
    _nc_vidmemo_bad = 0;
    run(verify, sizeof(verify), COLOR_YELLOW);
    if (_nc_vidmemo_bad != 0 || strcmp(real, verify) != 0) {
	printf("verify mode found %ld differences\n", _nc_vidmemo_bad);
	++bad;
    }
    /* another colour in pair 2: the memo must be flushed, not serve the old colour */
    _nc_vidmemo_mode = 0;
    run(flushed, sizeof(flushed), COLOR_GREEN);
    _nc_vidmemo_mode = 1;
    run(after, sizeof(after), COLOR_GREEN);
    if (strcmp(flushed, after) != 0 || strcmp(flushed, real) == 0) {
	printf("memo served stale bytes after init_pair changed a colour\n");
	++bad;
    }
    endwin();
    delscreen(sp);
    if (bad == 0)
	printf("hits=%ld misses=%ld", _nc_vidmemo_hits, _nc_vidmemo_misses);
    return bad ? 1 : 0;
}
