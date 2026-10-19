/* tiparm must return the same text for the same (format, parameters) and the
 * right text for every parameter, with the per-format result memo in place:
 * a stale or colliding memo entry would show up as a wrong color or cell. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curses.h>
#include <term.h>

static const char setaf_fmt[] =
    "\033[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m";
static const char cup_fmt[] = "\033[%i%p1%d;%p2%dH";
static const char dyn_fmt[] = "%p1%Pa%ga%d";	/* reads a dynamic variable: never memoised */

static int
expect(const char *what, const char *got, const char *want)
{
    if (got == NULL || strcmp(got, want) != 0) {
	printf("[FAIL] tparm memo: %s gave %s, want %s\n", what,
	       got ? got : "(null)", want);
	return 1;
    }
    return 0;
}

int
main(void)
{
    char want[64];
    int bad = 0;
    int n, row, col, pass;

    for (pass = 0; pass < 3; ++pass) {	/* pass 0 fills the memo, 1 and 2 hit it */
	for (n = 0; n < 256; ++n) {
	    if (n < 8)
		sprintf(want, "\033[3%dm", n);
	    else if (n < 16)
		sprintf(want, "\033[9%dm", n - 8);
	    else
		sprintf(want, "\033[38;5;%dm", n);
	    bad += expect("setaf", tiparm(setaf_fmt, n), want);
	}
	for (row = 0; row < 25; ++row) {
	    for (col = 0; col < 80; col += 7) {
		sprintf(want, "\033[%d;%dH", row + 1, col + 1);
		bad += expect("cup", tiparm(cup_fmt, row, col), want);
	    }
	}
	for (n = 0; n < 4; ++n) {
	    sprintf(want, "%d", n);
	    bad += expect("dynamic", tiparm(dyn_fmt, n), want);
	}
	if (bad)
	    return 1;
    }
    printf("[OK] ncurses tparm memo: setaf, cup and dynamic-variable formats stable over 3 passes\n");
    return 0;
}
