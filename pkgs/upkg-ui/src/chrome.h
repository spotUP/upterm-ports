/* chrome.h: the pure line builders of upkg-ui's screen chrome. No curses here, so test_chrome
 * can pin the exact strings. A port of the AmiExpress door SDK's sdk/engines/ui/theme/chrome.ts
 * (mastheadLine, railPattern, railFrame, footerHints). Text is ASCII: one byte is one cell, except
 * the leader, which is one cell and passed in as a string (U+00B7 in UTF-8, "." in ASCII). */
#ifndef UPKG_UI_CHROME_H
#define UPKG_UI_CHROME_H

#include <stddef.h>

#define CH_LEADER_UTF8  "\xc2\xb7"
#define CH_LEADER_ASCII "."

/* Where the pieces of a masthead sit, in cells, so the caller can colour them. A piece that does
 * not fit has length 0. lead_n leader cells start at lead_col (0 when the line is too narrow). */
typedef struct {
	int rail_col, rail_len;
	int title_col, title_len;
	int lead_col, lead_n;
	int value_col, value_len;
} ch_mast;

void ch_mast_layout(ch_mast *m, int width, const char *rail, const char *title, const char *value);

/* mastheadLine(width, rail, title, value): exactly `width` cells (a NUL ends it); returns its
 * byte length. cap must hold width * 2 + 1. Too narrow for a leader: the title is trimmed, never
 * the value. */
size_t ch_masthead_line(char *out, size_t cap, int width, const char *rail, const char *title,
                        const char *value, const char *leader);

/* railPattern(rail, width, gap, offset): the rail repeated to `width` cells. */
void ch_rail_pattern(char *out, size_t cap, const char *rail, int width, int gap, int offset);

/* railFrame(rail, tick): the rail shifted right by tick % strlen(rail), blank on the left. */
void ch_rail_frame(char *out, size_t cap, const char *rail, int tick);

/* A footer hint: "Key: does". keep = survives when the line is too short. */
typedef struct {
	const char *key;
	const char *does;
	int keep;
} ch_hint;

/* What survives fitting: bit i of `shown` is hint i; `rail` is 1 when the branding rail stays;
 * `len` is the cell width of the resulting line. Dropping order: the rail first, then hints from
 * the END of the list that are not keep. fit < 0: no fitting. At most 32 hints. */
typedef struct {
	unsigned shown;
	int rail;
	int len;
} ch_foot;

ch_foot ch_footer_fit(const ch_hint *hints, int n, const char *rail, int fit);

/* The plain footer text of a ch_foot ("Key: does  Key: does  /////"), as footerHints returns it
 * with identity paint. */
void ch_footer_text(char *out, size_t cap, const ch_hint *hints, int n, const char *rail, ch_foot f);

/* Word wrap: spans of `text` no wider than `width`, a word is never cut unless it is wider than a
 * line itself. A newline in the text ends a line. Returns the span count (at most `max`). */
typedef struct {
	int start, len;
} ch_span;

int ch_wrap_words(const char *text, int width, ch_span *out, int max);

#endif
