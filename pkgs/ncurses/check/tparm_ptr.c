/* The tparm format cache keyed by capability address (patches/0003): repeated
 * calls with the same capability pointer skip the tree walk, and a reused
 * address holding a different format still yields the right text. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curses.h>
#include <term.h>

extern long _nc_tparm_lookups, _nc_tparm_walks;

int
main(void)
{
    int err = 0, i, bad = 0;
    long l0, w0;
    char *buf;
    const char *got;
    char text[64];

    if (setupterm(NULL, 1, &err) != OK) {
	fprintf(stderr, "setupterm failed\n");
	return 2;
    }
    if (cursor_address == NULL) {
	fprintf(stderr, "no cup\n");
	return 2;
    }
    l0 = _nc_tparm_lookups;
    w0 = _nc_tparm_walks;
    for (i = 0; i < 50; ++i) {
	got = tiparm(cursor_address, i % 5, 3);
	snprintf(text, sizeof(text), "\033[%d;4H", i % 5 + 1);
	if (got == NULL || strcmp(got, text) != 0) {
	    printf("cup %d gave wrong text\n", i);
	    ++bad;
	}
    }
    if (_nc_tparm_lookups - l0 != 50 || _nc_tparm_walks - w0 > 2) {
	printf("50 calls on one capability: lookups=%ld walks=%ld (want 50 and at most 2: the first call formats and inserts)\n",
	       _nc_tparm_lookups - l0, _nc_tparm_walks - w0);
	++bad;
    }
    /* the same address now holds another format: the cache must not serve the old one */
    buf = malloc(64);
    strcpy(buf, "\033[%p1%dm");
    got = tiparm(buf, 7);
    if (got == NULL || strcmp(got, "\033[7m") != 0) {
	printf("first format at the address gave %s\n", got ? got : "(null)");
	++bad;
    }
    strcpy(buf, "\033[%p1%d;1m");
    got = tiparm(buf, 7);
    if (got == NULL || strcmp(got, "\033[7;1m") != 0) {
	printf("reused address gave %s, want ESC[7;1m\n", got ? got : "(null)");
	++bad;
    }
    if (bad == 0)
	printf("lookups=%ld walks=%ld", _nc_tparm_lookups - l0, _nc_tparm_walks - w0);
    return bad ? 1 : 0;
}
