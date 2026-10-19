#define _XOPEN_SOURCE_EXTENDED 1
/* doupdate does not call libc wcwidth for printable ASCII cells (patches/0007).
 * This program defines its own wcwidth, which the linker binds the library to,
 * counts the calls during a full-screen refresh of ASCII text (must be 0), and
 * then refreshes a non-ASCII cell (must still reach wcwidth). */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <locale.h>
#include <wchar.h>
#include <curses.h>

static long calls;

int
wcwidth(wchar_t c)
{
    ++calls;
    return (c >= 0x20 && c < 0x7f) || c == 0xe9 ? 1 : -1;
}

int
main(void)
{
    FILE *out = fopen("/dev/null", "w");
    int ifd[2], y;
    SCREEN *sp;
    long ascii, wide;
    static const wchar_t e9[] = { 0xe9, 0 };

    setlocale(LC_ALL, "");
    if (pipe(ifd) != 0)
	return 2;
    sp = newterm(NULL, out, fdopen(ifd[0], "r"));
    if (sp == NULL) {
	fprintf(stderr, "newterm failed\n");
	return 2;
    }
    for (y = 0; y < LINES; ++y)
	mvprintw(y, 0, "line %02d the quick brown fox jumps over the lazy dog", y);
    calls = 0;
    refresh();
    ascii = calls;
    mvaddwstr(0, 0, e9);
    calls = 0;
    refresh();
    wide = calls;
    endwin();
    if (ascii != 0 || wide < 1) {
	fprintf(stderr, "wcwidth calls: ascii frame %ld (want 0), non-ASCII frame %ld (want >= 1)\n", ascii, wide);
	return 1;
    }
    printf("ascii frame 0 wcwidth calls, non-ASCII frame %ld", wide);
    return 0;
}
