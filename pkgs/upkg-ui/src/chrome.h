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

/* The menu footer for the selected entry. CH_ENTRY_INSTALLED adds "Delete: Remove"; CH_ENTRY_LAUNCH makes
 * Enter read "Launch" instead of "Accept". CH_ENTRY_BULK adds "Shift+I: Install All" and
 * "Shift+U: Update All" and leaves out "Up/Down: Move" for the room. Flags 0 gives the plain menu footer.
 * out holds 6 hints; returns the count. */
#define CH_ENTRY_INSTALLED 1u
#define CH_ENTRY_LAUNCH    2u
#define CH_ENTRY_BULK      4u
int ch_menu_hints(ch_hint *out, unsigned flags);

/* Word wrap: spans of `text` no wider than `width`, a word is never cut unless it is wider than a
 * line itself. A newline in the text ends a line. Returns the span count (at most `max`). */
typedef struct {
	int start, len;
} ch_span;

int ch_wrap_words(const char *text, int width, ch_span *out, int max);

/* The cells of s: with `colors` (--colors), the \\Z codes take none. */
int ch_vis_len(const char *s, int colors);

/* The widest of n strings, the i-th at s[i * stride] (stride 2 walks the tags of tag/item pairs).
 * A menu draws every item two cells after the widest tag, as dialog does, so the items line up
 * whatever each tag's length. */
int ch_widest(const char *const *s, int n, int stride, int colors);

/* The rows and columns of the OSD menu style (no frame): `top` blank rows, the filter line, `gap`
 * blank rows, then `rows` entry rows, then `bottom` blank rows at the end of the screen (rows is at
 * least 1). The selection bar runs bar_x..bar_x+bar_w over the whole width; text starts at text_x;
 * an entry's item is right-aligned so that it ends at item_end (exclusive), pad cells from the
 * right edge. */
typedef struct {
	int filter_row, first_row, rows;
	int bar_x, bar_w, text_x, item_end;
} ch_osd;

ch_osd ch_osd_layout(int lines, int cols, int top, int filter, int gap, int bottom, int pad);

/* Tail follow for a textbox: the keys that move the top row, and whether the view then sits on the last
 * page. ch_scroll returns the new top (clamped to 0..maxtop) after key `key` with `room` rows on a
 * page; ch_at_tail is the follow state after any move: Up/PageUp/Home leave the tail (clear it), End
 * and Down/PageDown reaching maxtop are on it (re-arm it). */
enum { CH_SCROLL_UP, CH_SCROLL_DOWN, CH_SCROLL_PPAGE, CH_SCROLL_NPAGE, CH_SCROLL_HOME, CH_SCROLL_END };
int ch_scroll(int top, int key, int room, int maxtop);
int ch_at_tail(int top, int maxtop);

/* Footer status text next to the key hints, on a line w cells wide. The text is cut to w; the hints
 * get the cells left of it (two between them), `hints_w` 0 when fewer than 12 are left (the hints
 * give way, the status never does). `col` is the cell where the text starts (right-aligned); the
 * returned value is the cells the text takes (0 for NULL or empty: footer unchanged, hints_w = w). */
int ch_status_fit(const char *text, int w, int *hints_w, int *col);

#endif
