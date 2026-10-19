/* doupdate runs the typeahead check once at the start of a frame, not twice
 * (patches/0006).  A frame that changes one line must make exactly one check;
 * a frame that changes 12 lines makes one at the start plus one per 5 lines
 * changed (2 more). */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <curses.h>

extern long _nc_typeahead_checks;

static void
fill(int frame, int lines)
{
    int y;
    for (y = 0; y < lines; ++y)
	mvprintw(y, 0, "frame %d line %02d", frame, y);
}

int
main(void)
{
    FILE *out = fopen("/dev/null", "w");
    int ifd[2];
    SCREEN *sp;

    /* an input that never has data: /dev/null is always readable and would set _fifohold */
    if (pipe(ifd) != 0)
	return 2;
    sp = newterm(NULL, out, fdopen(ifd[0], "r"));
    long c0;
    int bad = 0;
    long one, many;

    if (sp == NULL) {
	fprintf(stderr, "newterm failed\n");
	return 2;
    }
    fill(0, LINES);
    refresh();
    c0 = _nc_typeahead_checks;
    mvprintw(3, 0, "changed");
    refresh();
    one = _nc_typeahead_checks - c0;
    c0 = _nc_typeahead_checks;
    fill(1, 12);
    refresh();
    many = _nc_typeahead_checks - c0;
    if (one != 1) {
	printf("one changed line made %ld typeahead checks, want 1\n", one);
	++bad;
    }
    if (many != 3) {
	printf("12 changed lines made %ld typeahead checks, want 3\n", many);
	++bad;
    }
    endwin();
    delscreen(sp);
    if (bad == 0)
	printf("one-line frame=%ld twelve-line frame=%ld", one, many);
    return bad ? 1 : 0;
}
