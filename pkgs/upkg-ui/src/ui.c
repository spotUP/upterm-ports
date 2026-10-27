/* libupkgui: the ncurses widgets of upkg-ui (inputbox, yesno, menu, msgbox, textbox, programbox)
 * drawn in the AmiExpress door SDK chrome (theme "Uprough Neon (muted)"), as a library: the
 * upkg-ui binary (add-on install questions, upkg-ask) and `upkg browse` (inside upkg) both link
 * it, so there is one set of widgets. The line builders are in chrome.c (pure, unit tested);
 * this file is curses and state. ui.h is the interface. */
/* wcwidth: glibc declares it only under __USE_XOPEN, which _XOPEN_SOURCE_EXTENDED alone does not
 * set; _GNU_SOURCE does, and adds nothing for ixemul or the Mac (ports CI, Linux host build) */
#define _GNU_SOURCE 1
#define _XOPEN_SOURCE_EXTENDED 1
#include <ctype.h>
#include <langinfo.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <dirent.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#include <wchar.h>

#include <curses.h>

#include "chrome.h"
#include "ui.h"

#define RAIL "/////"
#define DEFAULT_TITLE "UP-TERM ADD-ON"
#define MAX_BUTTONS 8

ui_opts ui_opt;

static int utf8, tick;
static int osd; /* the OSD style (ui_osd): menu only, no frame, masthead, rail or footer */
static FILE *keyfp; /* the terminal curses reads the keys from (open_keys) */

#define TICK_MS 1000 /* the rail moves once a second */
/* get_wch ERRs in a row that came back well before TICK_MS: no key can come (the key fd is at
 * end of file or hung up; select says ready and read gives 0). The rig spun here for ever. */
#define EARLY_ERRS 20

static long since_ms(const struct timeval *t0)
{
	struct timeval t;

	gettimeofday(&t, NULL);
	return (long)(t.tv_sec - t0->tv_sec) * 1000L + (long)(t.tv_usec - t0->tv_usec) / 1000L;
}
static attr_t a_chrome, a_ink, a_dim, a_acc, a_sel, a_field, a_col[8];

/* ---- colours: ground 0, ink 7, chrome 6, dim 8, accent 13, selection bg 5 ink 0 ---- */

static int pair_n;

static attr_t make_attr(int fg, int bg)
{
	int p = ++pair_n;
	attr_t bold = 0;
	if (fg >= 8 && COLORS < 16) {
		fg -= 8;
		bold = A_BOLD;
	}
	init_pair((short)p, (short)fg, (short)bg);
	return COLOR_PAIR(p) | bold;
}

static void init_theme(void)
{
	int i;

	if (has_colors()) {
		start_color();
		a_chrome = make_attr(6, 0);
		a_ink = make_attr(7, 0);
		a_dim = make_attr(8, 0);
		a_acc = make_attr(13, 0);
		a_sel = make_attr(0, 5);
		/* always: a program that starts curses once (`upkg browse`) sets ui_opt.colors later, per menu */
		for (i = 0; i < 8; i++)
			a_col[i] = make_attr(i, 0);
	} else {
		a_chrome = a_ink = 0;
		a_dim = A_DIM;
		a_acc = A_BOLD;
		a_sel = A_REVERSE;
	}
	a_field = a_ink | A_UNDERLINE;
}

/* ---- drawing helpers ---- */

static void text(int y, int x, attr_t a, const char *s, int n)
{
	attrset(a);
	mvaddnstr(y, x, s, n);
}

static void spaces(int y, int x, int n, attr_t a)
{
	attrset(a);
	for (; n > 0; n--, x++)
		mvaddch(y, x, ' ');
}

enum { G_H, G_V, G_UL, G_UR, G_LL, G_LR, G_LT, G_RT };

static void glyph(int y, int x, int g)
{
	attrset(a_chrome);
	if (utf8) {
		const cchar_t *w[] = { WACS_D_HLINE, WACS_D_VLINE, WACS_D_ULCORNER, WACS_D_URCORNER,
		                       WACS_D_LLCORNER, WACS_D_LRCORNER, WACS_D_LTEE, WACS_D_RTEE };
		mvadd_wch(y, x, w[g]);
	} else {
		mvaddch(y, x, g == G_H ? '=' : g == G_V ? '|' : '+');
	}
}

static void hrule(int y, int l, int r)
{
	int x;
	glyph(y, 0, l);
	for (x = 1; x < COLS - 1; x++)
		glyph(y, x, G_H);
	glyph(y, COLS - 1, r);
}

static void frame_box(void)
{
	int y;
	hrule(0, G_UL, G_UR);
	hrule(LINES - 1, G_LL, G_LR);
	for (y = 1; y < LINES - 1; y++) {
		glyph(y, 0, G_V);
		glyph(y, COLS - 1, G_V);
		spaces(y, 1, COLS - 2, a_ink);
	}
}

static const char *leader(void)
{
	return utf8 ? CH_LEADER_UTF8 : CH_LEADER_ASCII;
}

static void draw_masthead(void)
{
	ch_mast m;
	int w = COLS - 2, i;
	const char *value = ui_opt.backtitle ? ui_opt.backtitle : "";
	const char *title = ui_opt.title ? ui_opt.title : DEFAULT_TITLE;

	ch_mast_layout(&m, w, RAIL, title, value);
	text(1, 1, a_chrome, RAIL, m.rail_len);
	text(1, 1 + m.title_col, a_acc, title, m.title_len);
	attrset(a_dim);
	for (i = 0; i < m.lead_n; i++)
		mvaddstr(1, 1 + m.lead_col + i, leader());
	text(1, 1 + m.value_col, a_ink, value, m.value_len);
}

/* the tick: only the rail's own cells */
static void paint_rail(void)
{
	char f[16];
	if (osd) /* no rail in the OSD style */
		return;
	ch_rail_frame(f, sizeof f, RAIL, tick);
	text(1, 1, a_chrome, f, (int)strlen(f));
}

static void draw_footer(const ch_hint *h, int n)
{
	int x = 1, i, first = 1, w = COLS - 2;
	int y = LINES - 2;
	ch_foot f = ch_footer_fit(h, n, RAIL, w);

	spaces(y, 1, w, a_dim);
	for (i = 0; i < n; i++) {
		if (!(f.shown & (1u << i)))
			continue;
		if (!first)
			x += 2;
		first = 0;
		text(y, x, a_acc, h[i].key, w);
		x += (int)strlen(h[i].key);
		text(y, x, a_acc, ":", 1);
		x += 2;
		text(y, x, a_dim, h[i].does, w);
		x += (int)strlen(h[i].does);
	}
	if (f.rail)
		text(y, x + 2, a_dim, RAIL, w);
}

/* the prompt, wrapped; "\n" written as backslash-n counts as a line break (dialog's habit).
 * Returns the first free row. */
static int draw_prompt(int y)
{
	char *p = strdup(ui_opt.prompt ? ui_opt.prompt : ""), *s, *d;
	ch_span sp[64];
	int n, i, w = COLS - 4;

	if (!p)
		return y;
	for (s = d = p; *s; s++) {
		if (s[0] == '\\' && s[1] == 'n') {
			*d++ = '\n';
			s++;
		} else {
			*d++ = *s;
		}
	}
	*d = 0;
	n = ch_wrap_words(p, w, sp, 64);
	for (i = 0; i < n && y < LINES - 5; i++, y++)
		text(y, 2, a_ink, p + sp[i].start, sp[i].len);
	free(p);
	return y;
}

/* ---- widgets ---- */

static int widget_row;

static wchar_t buf[UI_MAX_INPUT];
static int blen, bpos, boff, bx, by;
static int msel, mtop;

/* the button row: labels split from --buttons (or Yes,No / OK), the selected one, the accepted one */
static char *blabel[MAX_BUTTONS];
static char *blist; /* the strdup'd --buttons text the labels point into; freed by the next split and ui_stop */
static int nbtn, bsel, bchosen;

/* textbox and programbox: stored lines, and the wrapped rows drawn from them */
typedef struct {
	int line, start, len;
} trow;
static char **lines;
static int nlines, lcap;
static trow *rows;
static int nrows, rcap, rows_lines, rows_w;
static int tbtop, follow, pdone;

static int cell_w(wchar_t c)
{
	int w = wcwidth(c);
	return w < 0 ? 1 : w;
}

static void draw_input(int y)
{
	int fw = COLS - 4, i, col = 0, cx = 0;

	/* scroll so the cursor stays inside the field, one cell kept for it */
	if (bpos < boff)
		boff = bpos;
	for (;;) {
		int span = 0;
		for (i = boff; i < bpos; i++)
			span += cell_w(buf[i]);
		if (span < fw || boff >= bpos)
			break;
		boff++;
	}
	spaces(y, 2, fw, a_field);
	attrset(a_field);
	for (i = boff; i < blen; i++) {
		int cw = cell_w(buf[i]);
		wchar_t one[2] = { buf[i], 0 };
		if (col + cw > fw)
			break;
		if (i < bpos)
			cx += cw;
		mvaddwstr(y, 2 + col, one);
		col += cw;
	}
	bx = 2 + cx;
	by = y;
}

static void draw_buttons(int y)
{
	int x = 4, i;
	char cell[64];

	for (i = 0; i < nbtn; i++) {
		int n = snprintf(cell, sizeof cell, " %s ", blabel[i]);
		text(y, x, i == bsel ? a_sel : a_ink, cell, n);
		x += n + 3;
	}
}

/* ---- stored lines (textbox, programbox) ---- */

/* keep one line: no newline, tabs to 8 columns, control bytes as '?' */
static void clear_lines(void);
static void add_line(const char *s)
{
	size_t n = strlen(s), k = 0;
	char *d = malloc(n * 8 + 1);
	size_t i;

	if (!d)
		return;
	for (i = 0; i < n && s[i] != '\n' && s[i] != '\r'; i++) {
		if (s[i] == '\t')
			do d[k++] = ' '; while (k % 8);
		else
			d[k++] = (unsigned char)s[i] < 32 ? '?' : s[i];
	}
	d[k] = 0;
	if (nlines == lcap) {
		char **nl = realloc(lines, (size_t)(lcap ? lcap * 2 : 64) * sizeof *lines);
		if (!nl) {
			free(d);
			return;
		}
		lines = nl;
		lcap = lcap ? lcap * 2 : 64;
	}
	lines[nlines++] = d;
}

static void add_row(int line, int start, int len)
{
	if (nrows == rcap) {
		trow *nr = realloc(rows, (size_t)(rcap ? rcap * 2 : 128) * sizeof *rows);
		if (!nr)
			return;
		rows = nr;
		rcap = rcap ? rcap * 2 : 128;
	}
	rows[nrows].line = line, rows[nrows].start = start, rows[nrows].len = len;
	nrows++;
}

/* wrap the lines not yet wrapped to the current width; a width change wraps all again */
static void sync_rows(void)
{
	int w = COLS - 4;

	if (w < 1)
		w = 1;
	if (w != rows_w)
		rows_lines = nrows = 0, rows_w = w;
	for (; rows_lines < nlines; rows_lines++) {
		const char *s = lines[rows_lines];
		ch_span *sp = malloc((strlen(s) + 2) * sizeof *sp);
		int n, i;

		if (!sp)
			return;
		n = ch_wrap_words(s, w, sp, (int)strlen(s) + 1);
		if (n == 0)
			add_row(rows_lines, 0, 0);
		for (i = 0; i < n; i++)
			add_row(rows_lines, sp[i].start, sp[i].len);
		free(sp);
	}
}

static int text_room(void)
{
	int r = LINES - 5 - widget_row;
	return r < 1 ? 1 : r;
}

static void draw_textarea(void)
{
	int room = text_room(), i, maxtop;

	sync_rows();
	maxtop = nrows > room ? nrows - room : 0;
	if (follow || tbtop > maxtop)
		tbtop = maxtop;
	if (tbtop < 0)
		tbtop = 0;
	for (i = 0; i < room && tbtop + i < nrows; i++) {
		const trow *r = &rows[tbtop + i];
		text(widget_row + i, 2, a_ink, lines[r->line] + r->start, r->len);
	}
}

static int menu_room(int y)
{
	int r = osd ? ch_osd_layout(LINES, COLS, UI_OSD_TOP_LINES, UI_OSD_FILTER_LINES, UI_OSD_GAP_LINES, UI_OSD_BOTTOM_LINES, UI_OSD_PAD).rows
	            : LINES - 4 - y;
	return r < 1 ? 1 : r;
}

/* draw s in the row's attribute `base`; with --colors the \\Z codes switch the foreground
 * (\\Z0..\\Z7 a colour, \\Zn back to base, any other \\Zx dropped). A selected row keeps base. */
static void put(int y, int x, attr_t base, int sel, const char *s, int w)
{
	attr_t a = base;
	int used = 0;
	mbstate_t st;

	if (!ui_opt.colors) {
		text(y, x, base, s, w);
		return;
	}
	memset(&st, 0, sizeof st);
	while (*s && used < w) {
		size_t len;
		wchar_t wc;
		int cw;

		if (s[0] == '\\' && s[1] == 'Z' && s[2]) {
			if (s[2] >= '0' && s[2] <= '7' && !sel && has_colors())
				a = a_col[s[2] - '0'];
			else if (s[2] == 'n')
				a = base;
			s += 3;
			continue;
		}
		len = mbrtowc(&wc, s, strlen(s), &st);
		if (len == (size_t)-1 || len == (size_t)-2 || len == 0) {
			len = 1;
			wc = (unsigned char)*s;
			memset(&st, 0, sizeof st);
		}
		cw = cell_w(wc);
		if (used + cw > w)
			break;
		text(y, x + used, a, s, (int)len);
		used += cw;
		s += len;
	}
}

/* the OSD menu: the filter line (the prompt, dim), a gap, then the rows with a full-width bar */
static void draw_menu_osd(void)
{
	ch_osd o = ch_osd_layout(LINES, COLS, UI_OSD_TOP_LINES, UI_OSD_FILTER_LINES, UI_OSD_GAP_LINES, UI_OSD_BOTTOM_LINES, UI_OSD_PAD);
	int i, w = o.bar_w - 2 * o.text_x;
	int x = o.text_x + (ui_opt.nentries ? ch_widest(&ui_opt.entries[0].tag, ui_opt.nentries, 2, ui_opt.colors) : 0) + 2;

	if (msel < mtop)
		mtop = msel;
	if (msel >= mtop + o.rows)
		mtop = msel - o.rows + 1;
	spaces(o.filter_row, o.bar_x, o.bar_w, a_ink);
	text(o.filter_row, o.text_x, a_dim, ui_opt.prompt ? ui_opt.prompt : "", w);
	for (i = 0; i < o.rows && mtop + i < ui_opt.nentries; i++) {
		const entry *e = &ui_opt.entries[mtop + i];
		int sel = mtop + i == msel;
		attr_t a = sel ? a_sel : a_ink;
		int y = o.first_row + i;
		spaces(y, o.bar_x, o.bar_w, a);
		put(y, o.text_x, a, sel, e->tag, w);
		if (e->item && *e->item) {
			int iw = ch_vis_len(e->item, ui_opt.colors), ix = o.item_end - iw;
			put(y, ix < x ? x : ix, sel ? a_sel : a_dim, sel, e->item, o.item_end - (ix < x ? x : ix));
		}
	}
}

static void draw_menu(int y)
{
	int room = menu_room(y), i, w = COLS - 4;
	/* every item in one column, two cells after the widest tag */
	int x = 3 + (ui_opt.nentries ? ch_widest(&ui_opt.entries[0].tag, ui_opt.nentries, 2, ui_opt.colors) : 0) + 2;

	if (msel < mtop)
		mtop = msel;
	if (msel >= mtop + room)
		mtop = msel - room + 1;
	for (i = 0; i < room && mtop + i < ui_opt.nentries; i++) {
		const entry *e = &ui_opt.entries[mtop + i];
		int sel = mtop + i == msel;
		attr_t a = sel ? a_sel : a_ink;
		spaces(y + i, 2, w, a);
		put(y + i, 3, a, sel, e->tag, w - 2);
		if (e->item && *e->item)
			put(y + i, x, sel ? a_sel : a_dim, sel, e->item, w + 2 - x);
	}
}

static const ch_hint H_INPUT[] = { { "Enter", "Accept", 1 }, { "Escape", "Cancel", 1 } };
static const ch_hint H_YESNO[] = { { "Left/Right", "Choose", 0 }, { "Enter", "Accept", 1 },
	                                { "Escape", "Cancel", 1 } };
static const ch_hint H_OK[] = { { "Enter", "Accept", 1 }, { "Escape", "Back", 1 } };
static const ch_hint H_TEXT[] = { { "Up/Down", "Scroll", 0 }, { "Left/Right", "Choose", 0 },
	                               { "Enter", "Accept", 1 }, { "Escape", "Back", 1 } };
static const ch_hint H_WAIT[] = { { "Wait", "Command running", 1 } };

static void draw_all(void)
{
	erase();
	if (osd && ui_opt.kind == K_MENU) {
		widget_row = UI_OSD_HEAD_LINES;
		draw_menu_osd();
		return;
	}
	frame_box();
	draw_masthead();
	hrule(2, G_LT, G_RT);
	widget_row = ui_opt.kind == K_TEXTBOX ? 3 : draw_prompt(3) + 1;
	hrule(LINES - 3, G_LT, G_RT);
	switch (ui_opt.kind) {
	case K_INPUT:
		draw_input(widget_row);
		draw_footer(H_INPUT, 2);
		break;
	case K_YESNO:
		draw_buttons(widget_row);
		draw_footer(H_YESNO, 3);
		break;
	case K_MSGBOX:
		draw_buttons(widget_row);
		draw_footer(nbtn > 1 ? H_YESNO : H_OK, nbtn > 1 ? 3 : 2);
		break;
	case K_TEXTBOX:
		draw_textarea();
		draw_buttons(LINES - 4);
		draw_footer(H_TEXT, 4);
		break;
	case K_PROGRAM:
		draw_textarea();
		if (pdone) {
			draw_buttons(LINES - 4);
			draw_footer(H_TEXT, 4);
		} else {
			draw_footer(H_WAIT, 1);
		}
		break;
	default:
		draw_menu(widget_row);
		{
			ch_hint mh[4];
			int mn = ch_menu_hints(mh, ui_opt.entry_flags && msel >= 0 && msel < ui_opt.nentries ?
			                               ui_opt.entry_flags[msel] : 0);

			draw_footer(mh, mn);
		}
		break;
	}
}

static void place_cursor(void)
{
	if (ui_opt.kind == K_INPUT)
		move(by, bx);
}

/* keys: returns -1 to go on, else the exit code */
static int key_input(int fn, wint_t c)
{
	int i;
	if (fn) {
		switch (c) {
		case KEY_LEFT: if (bpos > 0) bpos--; break;
		case KEY_RIGHT: if (bpos < blen) bpos++; break;
		case KEY_HOME: bpos = 0; break;
		case KEY_END: bpos = blen; break;
		case KEY_BACKSPACE:
			if (bpos > 0) {
				memmove(buf + bpos - 1, buf + bpos, (size_t)(blen - bpos) * sizeof *buf);
				bpos--, blen--;
			}
			break;
		case KEY_DC:
			if (bpos < blen) {
				memmove(buf + bpos, buf + bpos + 1, (size_t)(blen - bpos - 1) * sizeof *buf);
				blen--;
			}
			break;
		}
		return -1;
	}
	if (c == '\n' || c == '\r')
		return 0;
	if (c == 21) { /* Ctrl-U */
		blen = bpos = boff = 0;
	} else if (c == 8 || c == 127) {
		return key_input(1, KEY_BACKSPACE);
	} else if (c >= 32 && blen < UI_MAX_INPUT - 1) {
		for (i = blen; i > bpos; i--)
			buf[i] = buf[i - 1];
		buf[bpos++] = (wchar_t)c;
		blen++;
	}
	return -1;
}

/* the button row: returns the accepted button, else -1 */
static int key_buttons(int fn, wint_t c)
{
	int i;
	if (fn) {
		if (c == KEY_LEFT)
			bsel = (bsel + nbtn - 1) % nbtn;
		else if (c == KEY_RIGHT)
			bsel = (bsel + 1) % nbtn;
		else if (c == KEY_ENTER)
			return bsel;
		return -1;
	}
	if (c == '\t')
		bsel = (bsel + 1) % nbtn;
	else if (c == '\n' || c == '\r' || (c == ' ' && ui_opt.kind == K_MSGBOX))
		return bsel;
	else if (c < 128)
		for (i = 0; i < nbtn; i++)
			if (tolower((unsigned char)blabel[i][0]) == tolower((int)c))
				return i;
	return -1;
}

/* textbox and programbox: scrolling, the rest is the button row */
static int key_text(int fn, wint_t c)
{
	int room = text_room(), maxtop = nrows > room ? nrows - room : 0;
	if (fn) {
		switch (c) {
		case KEY_UP: tbtop--; break;
		case KEY_DOWN: tbtop++; break;
		case KEY_PPAGE: tbtop -= room; break;
		case KEY_NPAGE: tbtop += room; break;
		case KEY_HOME: tbtop = 0; break;
		case KEY_END: tbtop = maxtop; break;
		default: return key_buttons(fn, c);
		}
		if (tbtop > maxtop)
			tbtop = maxtop;
		if (tbtop < 0)
			tbtop = 0;
		return -1;
	}
	return key_buttons(fn, c);
}

static int hotkey; /* the --hotkeys key that ended the menu, 0 for Enter */

static int key_menu(int fn, wint_t c)
{
	int n = ui_opt.nentries, room = menu_room(widget_row), i;
	if (fn) {
		switch (c) {
		case KEY_UP: if (msel > 0) msel--; break;
		case KEY_DOWN: if (msel < n - 1) msel++; break;
		case KEY_HOME: msel = 0; break;
		case KEY_END: msel = n - 1; break;
		case KEY_PPAGE: msel = msel - room < 0 ? 0 : msel - room; break;
		case KEY_NPAGE: msel = msel + room > n - 1 ? n - 1 : msel + room; break;
		case KEY_ENTER: return 0;
		case KEY_LEFT: /* only a caller that lists UI_HOTKEY_LEFT hears it; for the rest Left does nothing */
			if (ui_opt.hotkeys && strchr(ui_opt.hotkeys, UI_HOTKEY_LEFT)) {
				hotkey = UI_HOTKEY_LEFT;
				return 0;
			}
			break;
		case KEY_RIGHT: /* same rule as Left: only a caller that lists UI_HOTKEY_RIGHT hears it */
			if (ui_opt.hotkeys && strchr(ui_opt.hotkeys, UI_HOTKEY_RIGHT)) {
				hotkey = UI_HOTKEY_RIGHT;
				return 0;
			}
			break;
		case KEY_BACKSPACE: /* keypad mode turns 8 and 127 into these: back to the bytes a hotkey list names */
		case KEY_DC:
			if (ui_opt.hotkeys && strchr(ui_opt.hotkeys, c == KEY_DC ? 127 : 8)) {
				hotkey = c == KEY_DC ? 127 : 8;
				return 0;
			}
			break;
		}
		return -1;
	}
	if (c == '\n' || c == '\r')
		return 0;
	/* a hotkey ends the menu; it wins over the first-letter jump */
	if (ui_opt.hotkeys && c > 0 && c < 128 && strchr(ui_opt.hotkeys, (int)c)) {
		hotkey = (int)c;
		return 0;
	}
	/* first-letter jump: the next entry after the selected one, wrapping */
	for (i = 1; i <= n; i++) {
		const char *t = ui_opt.entries[(msel + i) % n].tag;
		if (c < 128 && t[0] && strncasecmp(t, (char[]){ (char)c, 0 }, 1) == 0) {
			msel = (msel + i) % n;
			break;
		}
	}
	return -1;
}

static int (*tick_fn)(void *ctx);
static void *tick_ctx;

void ui_on_tick(int (*fn)(void *ctx), void *ctx)
{
	tick_fn = fn;
	tick_ctx = ctx;
}

static int run(void)
{
	int redraw = 1, early = 0;
	wint_t c;
	struct timeval start, t0;

	hotkey = 0; /* ui_hotkey() describes this run only, not a menu shown before it */
	timeout(TICK_MS);
	gettimeofday(&start, NULL);
	for (;;) {
		int r, code;
		if (redraw) {
			draw_all();
			redraw = 0;
		}
		place_cursor();
		refresh();
		gettimeofday(&t0, NULL);
		r = get_wch(&c);
		if (r == ERR) {
			/* the tick is wall time, not a count of ERRs: an early ERR moves nothing */
			int t = (int)(since_ms(&start) / TICK_MS);
			if (since_ms(&t0) >= TICK_MS / 2)
				early = 0;
			else if (++early >= EARLY_ERRS || !isatty(fileno(keyfp)))
				return EXIT_NO_TERMINAL;
			if (t != tick) { /* the rail's cells only */
				tick = t;
				paint_rail();
				if (tick_fn && tick_fn(tick_ctx))
					return UI_TICK;
			}
			continue;
		}
		early = 0;
		if (r == KEY_CODE_YES && c == KEY_RESIZE) {
			/* the terminal's contents are unknown after a resize: vtcon reflows its normal
			 * screen, where this UI lives (no smcup), and ncurses repaints in full only when
			 * the size it reads has changed (resizeterm's clearok). A KEY_RESIZE at a size it
			 * already knows sent only the diff, and the reflowed rows stayed (A1200: every
			 * second row blank after a Shell resize). check/resize.sh */
			clearok(curscr, TRUE);
			redraw = 1;
			continue;
		}
		if (r == OK && c == 27)
			return 255;
		switch (ui_opt.kind) {
		case K_INPUT: code = key_input(r == KEY_CODE_YES, c); break;
		case K_MENU: code = key_menu(r == KEY_CODE_YES, c); break;
		default: {
			int b = ui_opt.kind == K_TEXTBOX || ui_opt.kind == K_PROGRAM ? key_text(r == KEY_CODE_YES, c)
			                                                       : key_buttons(r == KEY_CODE_YES, c);
			code = -1;
			if (b >= 0) {
				bchosen = b;
				return ui_opt.kind == K_YESNO ? b : 0;
			}
		}
		}
		if (code >= 0)
			return code;
		redraw = 1;
	}
}

/* newterm has already sent smcup (the terminfo is only read there): refresh flushes it, rmcup
 * follows at once, and rmcup is then blanked so endwin switches nothing. tigetstr returns the
 * library's own copy of the string; nulling exit_ca_mode from term.h (dialog's way) does not
 * reach it in an ncurses built with extended numbers. rmcup also puts the cursor back where smcup
 * saved it (the Shell prompt) while ncurses believes it is home on a cleared screen; clearok makes
 * the next refresh clear and home again, or the first row is drawn at the prompt. */
static void leave_alternate_screen(void)
{
	char *smcup = tigetstr("smcup"), *rmcup = tigetstr("rmcup");

	if (smcup == (char *)-1 || !smcup || !*smcup || rmcup == (char *)-1 || !rmcup || !*rmcup)
		return;
	refresh();
	fputs(rmcup, stdout);
	fflush(stdout);
	*rmcup = 0;
	clearok(curscr, TRUE);
}

/* the button labels: --buttons split at commas, else Yes,No for yesno and OK */
const char *ui_init_buttons(void)
{
	char *list;
	char *p;

	if (ui_opt.kind == K_YESNO) {
		blabel[0] = "Yes", blabel[1] = "No", nbtn = 2;
		bsel = ui_opt.defaultno;
		return NULL;
	}
	if (!ui_opt.buttons) {
		blabel[0] = "OK", nbtn = 1;
		return NULL;
	}
	free(blist);
	blist = NULL;
	list = strdup(ui_opt.buttons);
	if (!list)
		return "out of memory";
	blist = list;
	for (p = list; nbtn < MAX_BUTTONS; ) {
		blabel[nbtn++] = p;
		p = strchr(p, ',');
		if (!p)
			break;
		*p++ = 0;
	}
	if (p)
		return "too many buttons";
	{
		int i;
		for (i = 0; i < nbtn; i++)
			if (!blabel[i][0])
				return "empty button label";
	}
	return NULL;
}

/* The terminal the keys come from: /dev/tty, else stdin (not for a programbox: its lines come
 * there), stdout or stderr, the first that is a terminal; NULL when none is. An ixemul program
 * started by a native one (vsh is sh) has no controlling terminal, so its /dev/tty opens the
 * process's console "*": under ptyrun on the rig that was NIL: (isatty 0, select ready at once,
 * read 0) while stdin and stdout were the pty, and every widget spun on ERR from get_wch. */
static FILE *open_keys(void)
{
	FILE *f = fopen("/dev/tty", "r+");
	int fd;

	if (f && isatty(fileno(f)))
		return f;
	if (f)
		fclose(f);
	for (fd = ui_opt.kind == K_PROGRAM ? 1 : 0; fd <= 2; fd++) {
		int d;
		if (!isatty(fd) || (d = dup(fd)) < 0)
			continue;
		if ((f = fdopen(d, "r+")) != NULL)
			return f;
		close(d);
	}
	return NULL;
}

/* programbox: the command's lines show as they arrive, then the OK button */
void ui_program_begin(const char *prompt)
{
	clear_lines();
	pdone = 0;
	ui_opt.kind = K_PROGRAM;
	ui_opt.prompt = prompt;
	ui_opt.buttons = NULL;
	nbtn = bsel = bchosen = 0;
	ui_init_buttons();
	follow = 1;
	draw_all();
	refresh();
}

void ui_program_line(const char *s)
{
	add_line(s);
	draw_all();
	refresh();
}

void ui_read_lines(FILE *in)
{
	char chunk[4096];

	ui_program_begin(ui_opt.prompt);
	while (fgets(chunk, sizeof chunk, in))
		ui_program_line(chunk);
}

void ui_program_done(void)
{
	flushinp(); /* keys typed while the command ran must not answer the dialog */
	follow = 0;
	pdone = 1;
}

static void clear_lines(void)
{
	int i;
	for (i = 0; i < nlines; i++)
		free(lines[i]);
	nlines = rows_lines = nrows = tbtop = follow = 0;
}

void ui_clear_lines(void) { clear_lines(); }
void ui_add_line(const char *s) { add_line(s); }

int ui_view(int kind, const char *prompt, const char *buttons)
{
	ui_opt.kind = kind;
	ui_opt.prompt = prompt;
	ui_opt.buttons = buttons;
	nbtn = bsel = bchosen = 0;
	hotkey = 0;
	if (kind != K_MENU && ui_init_buttons())
		return 2;
	return run();
}

int ui_message(const char *fmt, const char *tag)
{
	char text[256];
	snprintf(text, sizeof text, fmt, tag);
	return ui_view(K_MSGBOX, text, NULL);
}

int ui_run(void) { return run(); }
int ui_hotkey(void) { return hotkey; }
int ui_selected(void) { return msel; }
void ui_osd(int on) { osd = on; }
void ui_select(int row) { msel = row; mtop = 0; }
const char *ui_button(void) { return blabel[bchosen]; }
FILE *ui_keys(void) { return keyfp; }

void ui_prepare(void)
{
	int i;

	if (ui_opt.kind == K_INPUT) {
		blen = bpos = (int)wcslen(ui_opt.init);
		wmemcpy(buf, ui_opt.init, (size_t)blen);
	} else if (ui_opt.kind == K_MENU) {
		for (i = 0; i < ui_opt.nentries; i++)
			if (ui_opt.default_item && !strcmp(ui_opt.entries[i].tag, ui_opt.default_item))
				msel = i;
	}
}

static SCREEN *screen; /* the SCREEN newterm made; ui_stop deletes it */

int ui_start(const char *who)
{
	SCREEN *scr;

	setlocale(LC_ALL, "");
	utf8 = strcasecmp(nl_langinfo(CODESET), "UTF-8") == 0 || strcasecmp(nl_langinfo(CODESET), "UTF8") == 0;
	set_escdelay(50);
	keyfp = open_keys();
	if (!keyfp) {
		fprintf(stderr, "%s: no terminal to read the keys from\n", who);
		return EXIT_NO_TERMINAL;
	}
	scr = newterm(NULL, stdout, keyfp);
	if (!scr) {
		fprintf(stderr, "%s: cannot initialise the terminal\n", who);
		return 2;
	}
	screen = scr;
	set_term(scr);
	if (!ui_opt.keep_tite)
		leave_alternate_screen();
	cbreak();
	noecho();
	nonl();
	keypad(stdscr, TRUE);
	curs_set(0);
	init_theme();
	if (ui_opt.kind == K_INPUT)
		curs_set(1);
	return 0;
}

/* The inverse of ui_start: the terminal modes go back, the SCREEN and the key stream are released
 * and every file-scope widget state is reset, so ui_start can run again in the same process (a
 * server that opens a console window per menu). ui_opt belongs to the caller and is left alone. */
void ui_stop(void)
{
	endwin();
	if (screen) {
		delscreen(screen);
		screen = NULL;
	}
	if (keyfp) {
		fclose(keyfp);
		keyfp = NULL;
	}
	clear_lines();
	free(lines);
	lines = NULL;
	nlines = lcap = 0;
	free(rows);
	rows = NULL;
	nrows = rcap = rows_lines = rows_w = 0;
	free(blist);
	blist = NULL;
	memset(blabel, 0, sizeof blabel);
	nbtn = bsel = bchosen = 0;
	memset(buf, 0, sizeof buf);
	blen = bpos = boff = bx = by = 0;
	msel = mtop = 0;
	widget_row = 0;
	tbtop = follow = pdone = 0;
	hotkey = 0;
	tick = pair_n = 0;
	osd = 0;
	utf8 = 0;
	a_chrome = a_ink = a_dim = a_acc = a_sel = a_field = 0;
	memset(a_col, 0, sizeof a_col);
	tick_fn = NULL;
	tick_ctx = NULL;
}

void ui_suspend(void)
{
	def_prog_mode();
	endwin();
	fputs("\033[H\033[2J", stdout);
	fflush(stdout);
}

void ui_resume(void)
{
	reset_prog_mode();
	clearok(curscr, TRUE);
	refresh();
}

void ui_answer(FILE *out)
{
	char o[UI_MAX_INPUT * 4];

	if (ui_opt.kind == K_INPUT) {
		buf[blen] = 0;
		if (wcstombs(o, buf, sizeof o) == (size_t)-1)
			o[0] = 0;
		fputs(o, out);
	} else if (ui_opt.kind == K_MENU) {
		if (!ui_opt.hotkeys)
			fputs(ui_opt.entries[msel].tag, out);
		else if (hotkey)
			fprintf(out, "%c %s", hotkey, ui_opt.entries[msel].tag);
		else
			fprintf(out, "enter %s", ui_opt.entries[msel].tag);
	} else if (ui_opt.buttons) {
		fputs(blabel[bchosen], out);
	}
}
