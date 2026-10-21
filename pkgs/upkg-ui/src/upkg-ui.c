/* upkg-ui: the add-on install questions of UP-Term (vtcon upkg plan P10.6), a small ncurses
 * program that replaces dialog, drawn in the AmiExpress door SDK chrome (theme "Uprough Neon
 * (muted)"). The line builders are in chrome.c (pure, unit tested); this file is curses + args.
 *
 *   upkg-ui [--title T] [--backtitle V] [--defaultno] [--no-items] [--default-item X]
 *           [--hotkeys KEYS] [--buttons A,B,C] [--colors] [--keep-tite]
 *           (--inputbox PROMPT H W [INIT] | --yesno PROMPT H W | --menu PROMPT H W MH ITEM... |
 *            --msgbox PROMPT H W | --textbox FILE H W | --programbox PROMPT H W)
 *
 * dialog-compatible subset: H, W and MH are accepted and ignored (the screen is the whole
 * terminal). The answer goes to STDERR (curses owns stdout). Exit 0 accept, 1 cancel or No,
 * 255 Escape, 2 usage error, 3 no terminal to read the keys from (none at the start, or it went
 * away: end of file or hangup).
 *
 * --hotkeys KEYS (menu only): pressing one of KEYS ends the menu with exit 0 and writes
 * "KEY TAG"; Enter then writes "enter TAG". Without it the answer is the bare TAG.
 *
 * Buttons: one row for yesno, msgbox, textbox and programbox. Left/Right/Tab choose, Enter accepts,
 * the first letter of a label accepts it at once. --yesno exits with the button index. --buttons
 * "A,B,C" (msgbox and textbox) sets the labels; the chosen label goes to stderr, exit 0. The
 * default is one OK button and writes nothing.
 *
 * --textbox shows FILE wrapped, scrolled with Up/Down/PgUp/PgDn/Home/End. --programbox reads its
 * lines from stdin (the keys then come from the terminal, see open_keys), keeps the end in view, and at EOF drops the
 * keys typed meanwhile and shows OK. --colors (menu): \Z0..\Z7 colour the text, \Zn resets.
 *
 * Like dialog, upkg-ui stays on the normal screen: a script that runs several screens one after
 * another (upkg browse, upkg-ask) would otherwise show the Shell between every two, as each run
 * switched to the alternate screen at the start and back at the exit. Such a script clears the
 * screen when it ends. --keep-tite keeps the switch (the Shell comes back at the exit). */
#define _XOPEN_SOURCE_EXTENDED 1
#include <ctype.h>
#include <langinfo.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/time.h>
#include <unistd.h>
#include <wchar.h>

#include <curses.h>

#include "chrome.h"

#define RAIL "/////"
#define DEFAULT_TITLE "UP-TERM ADD-ON"
#define MAX_INPUT 1024

enum kind { K_NONE, K_INPUT, K_YESNO, K_MENU, K_MSGBOX, K_TEXTBOX, K_PROGRAM };

#define MAX_BUTTONS 8

typedef struct {
	const char *tag;
	const char *item;
} entry;

static struct {
	const char *title, *backtitle, *prompt, *default_item, *hotkeys, *buttons, *file;
	int defaultno, no_items, colors, keep_tite, kind;
	wchar_t init[MAX_INPUT];
	entry *entries;
	int nentries;
} opt;

static int utf8, tick;
static FILE *keyfp; /* the terminal curses reads the keys from (open_keys) */

#define TICK_MS 1000 /* the rail moves once a second */
/* get_wch ERRs in a row that came back well before TICK_MS: no key can come (the key fd is at
 * end of file or hung up; select says ready and read gives 0). The rig spun here for ever. */
#define EARLY_ERRS 20
#define EXIT_NO_TERMINAL 3

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
	if (has_colors()) {
		start_color();
		a_chrome = make_attr(6, 0);
		a_ink = make_attr(7, 0);
		a_dim = make_attr(8, 0);
		a_acc = make_attr(13, 0);
		a_sel = make_attr(0, 5);
		if (opt.colors) {
			int i;
			for (i = 0; i < 8; i++)
				a_col[i] = make_attr(i, 0);
		}
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
	const char *value = opt.backtitle ? opt.backtitle : "";
	const char *title = opt.title ? opt.title : DEFAULT_TITLE;

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
	char *p = strdup(opt.prompt ? opt.prompt : ""), *s, *d;
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

static wchar_t buf[MAX_INPUT];
static int blen, bpos, boff, bx, by;
static int msel, mtop;

/* the button row: labels split from --buttons (or Yes,No / OK), the selected one, the accepted one */
static char *blabel[MAX_BUTTONS];
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
	int r = LINES - 4 - y;
	return r < 1 ? 1 : r;
}

/* draw s in the row's attribute `base`; with --colors the \\Z codes switch the foreground
 * (\\Z0..\\Z7 a colour, \\Zn back to base, any other \\Zx dropped). A selected row keeps base. */
static void put(int y, int x, attr_t base, int sel, const char *s, int w)
{
	attr_t a = base;
	int used = 0;
	mbstate_t st;

	if (!opt.colors) {
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

static void draw_menu(int y)
{
	int room = menu_room(y), i, w = COLS - 4;
	/* every item in one column, two cells after the widest tag */
	int x = 3 + (opt.nentries ? ch_widest(&opt.entries[0].tag, opt.nentries, 2, opt.colors) : 0) + 2;

	if (msel < mtop)
		mtop = msel;
	if (msel >= mtop + room)
		mtop = msel - room + 1;
	for (i = 0; i < room && mtop + i < opt.nentries; i++) {
		const entry *e = &opt.entries[mtop + i];
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
static const ch_hint H_MENU[] = { { "Up/Down", "Move", 0 }, { "Enter", "Accept", 1 },
	                               { "Escape", "Cancel", 1 } };

static void draw_all(void)
{
	erase();
	frame_box();
	draw_masthead();
	hrule(2, G_LT, G_RT);
	widget_row = opt.kind == K_TEXTBOX ? 3 : draw_prompt(3) + 1;
	hrule(LINES - 3, G_LT, G_RT);
	switch (opt.kind) {
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
		draw_footer(H_MENU, 3);
		break;
	}
}

static void place_cursor(void)
{
	if (opt.kind == K_INPUT)
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
	} else if (c >= 32 && blen < MAX_INPUT - 1) {
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
	else if (c == '\n' || c == '\r' || (c == ' ' && opt.kind == K_MSGBOX))
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
	int n = opt.nentries, room = menu_room(widget_row), i;
	if (fn) {
		switch (c) {
		case KEY_UP: if (msel > 0) msel--; break;
		case KEY_DOWN: if (msel < n - 1) msel++; break;
		case KEY_HOME: msel = 0; break;
		case KEY_END: msel = n - 1; break;
		case KEY_PPAGE: msel = msel - room < 0 ? 0 : msel - room; break;
		case KEY_NPAGE: msel = msel + room > n - 1 ? n - 1 : msel + room; break;
		case KEY_ENTER: return 0;
		}
		return -1;
	}
	if (c == '\n' || c == '\r')
		return 0;
	/* a hotkey ends the menu; it wins over the first-letter jump */
	if (opt.hotkeys && c > 0 && c < 128 && strchr(opt.hotkeys, (int)c)) {
		hotkey = (int)c;
		return 0;
	}
	/* first-letter jump: the next entry after the selected one, wrapping */
	for (i = 1; i <= n; i++) {
		const char *t = opt.entries[(msel + i) % n].tag;
		if (c < 128 && t[0] && strncasecmp(t, (char[]){ (char)c, 0 }, 1) == 0) {
			msel = (msel + i) % n;
			break;
		}
	}
	return -1;
}

static int run(void)
{
	int redraw = 1, early = 0;
	wint_t c;
	struct timeval start, t0;

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
			}
			continue;
		}
		early = 0;
		if (r == KEY_CODE_YES && c == KEY_RESIZE) {
			redraw = 1;
			continue;
		}
		if (r == OK && c == 27)
			return 255;
		switch (opt.kind) {
		case K_INPUT: code = key_input(r == KEY_CODE_YES, c); break;
		case K_MENU: code = key_menu(r == KEY_CODE_YES, c); break;
		default: {
			int b = opt.kind == K_TEXTBOX || opt.kind == K_PROGRAM ? key_text(r == KEY_CODE_YES, c)
			                                                       : key_buttons(r == KEY_CODE_YES, c);
			code = -1;
			if (b >= 0) {
				bchosen = b;
				return opt.kind == K_YESNO ? b : 0;
			}
		}
		}
		if (code >= 0)
			return code;
		redraw = 1;
	}
}

/* ---- arguments ---- */

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

static int usage(const char *why)
{
	if (why)
		fprintf(stderr, "upkg-ui: %s\n", why);
	fputs("usage: upkg-ui [--title T] [--backtitle V] [--defaultno] [--no-items] [--default-item X]\n"
	      "       [--hotkeys KEYS] [--buttons A,B,C] [--colors] [--keep-tite]\n"
	      "       (--inputbox PROMPT H W [INIT] | --yesno PROMPT H W | --menu PROMPT H W MH ITEM... |\n"
	      "        --msgbox PROMPT H W | --textbox FILE H W | --programbox PROMPT H W)\n",
	      stderr);
	return 2;
}

static int parse(int argc, char **argv)
{
	int i = 1, no_items_pairs = 0, j;

	for (; i < argc; i++) {
		const char *a = argv[i];
		if (!strcmp(a, "--title") && i + 1 < argc)
			opt.title = argv[++i];
		else if (!strcmp(a, "--backtitle") && i + 1 < argc)
			opt.backtitle = argv[++i];
		else if (!strcmp(a, "--default-item") && i + 1 < argc)
			opt.default_item = argv[++i];
		else if (!strcmp(a, "--hotkeys") && i + 1 < argc)
			opt.hotkeys = argv[++i];
		else if (!strcmp(a, "--buttons") && i + 1 < argc)
			opt.buttons = argv[++i];
		else if (!strcmp(a, "--colors"))
			opt.colors = 1;
		else if (!strcmp(a, "--defaultno"))
			opt.defaultno = 1;
		else if (!strcmp(a, "--keep-tite"))
			opt.keep_tite = 1;
		else if (!strcmp(a, "--no-items"))
			opt.no_items = 1;
		else if (!strcmp(a, "--inputbox") || !strcmp(a, "--yesno") || !strcmp(a, "--menu") ||
		         !strcmp(a, "--msgbox") || !strcmp(a, "--textbox") || !strcmp(a, "--programbox")) {
			int need = !strcmp(a, "--menu") ? 4 : 3; /* PROMPT H W (MH) must follow */
			int extra = 0;
			if (opt.kind != K_NONE)
				return usage("only one widget");
			opt.kind = !strcmp(a, "--inputbox") ? K_INPUT : !strcmp(a, "--yesno") ? K_YESNO :
			           !strcmp(a, "--msgbox") ? K_MSGBOX : !strcmp(a, "--textbox") ? K_TEXTBOX :
			           !strcmp(a, "--programbox") ? K_PROGRAM : K_MENU;
			if (argc - 1 - i < need)
				return usage("missing arguments");
			opt.prompt = argv[++i];
			if (opt.kind == K_TEXTBOX)
				opt.file = opt.prompt;
			i += 2; /* H W */
			if (opt.kind == K_MENU) {
				i++; /* MH */
				extra = argc - 1 - i;
				if (extra < 1)
					return usage("menu needs at least one item");
				/* tags only, or tag/item pairs; --no-items with an empty item after every
				 * tag is the pair form upkg-ask has always passed */
				no_items_pairs = !opt.no_items;
				if (opt.no_items && extra % 2 == 0) {
					no_items_pairs = 1;
					for (j = 1; j <= extra; j += 2)
						if (argv[i + 1 + j][0])
							no_items_pairs = 0;
				}
				{
					int step = (opt.no_items && !no_items_pairs) ? 1 : 2;
					if (step == 2 && extra % 2)
						return usage("menu items come as tag item pairs");
					opt.nentries = extra / step;
					opt.entries = calloc((size_t)opt.nentries, sizeof *opt.entries);
					if (!opt.entries)
						return usage("out of memory");
					for (j = 0; j < opt.nentries; j++) {
						opt.entries[j].tag = argv[i + 1 + j * step];
						opt.entries[j].item = step == 2 && !opt.no_items ? argv[i + 2 + j * step] : "";
					}
				}
				i = argc;
			} else if (opt.kind == K_INPUT) {
				if (i + 1 < argc)
					mbstowcs(opt.init, argv[++i], MAX_INPUT - 1);
				if (i + 1 < argc)
					return usage("too many arguments");
			} else if (i + 1 < argc) {
				return usage("too many arguments");
			}
		} else {
			return usage("unknown option");
		}
	}
	if (opt.kind == K_NONE)
		return usage("no widget");
	if (opt.prompt == NULL)
		return usage("missing arguments");
	if (opt.hotkeys && opt.kind != K_MENU)
		return usage("hotkeys need a menu");
	if (opt.buttons && opt.kind != K_MSGBOX && opt.kind != K_TEXTBOX)
		return usage("buttons need a msgbox or a textbox");
	if (opt.colors && opt.kind != K_MENU)
		return usage("colors need a menu");
	return 0;
}

/* the button labels: --buttons split at commas, else Yes,No for yesno and OK */
static int init_buttons(void)
{
	char *list;
	char *p;

	if (opt.kind == K_YESNO) {
		blabel[0] = "Yes", blabel[1] = "No", nbtn = 2;
		bsel = opt.defaultno;
		return 0;
	}
	if (!opt.buttons) {
		blabel[0] = "OK", nbtn = 1;
		return 0;
	}
	list = strdup(opt.buttons);
	if (!list)
		return usage("out of memory");
	for (p = list; nbtn < MAX_BUTTONS; ) {
		blabel[nbtn++] = p;
		p = strchr(p, ',');
		if (!p)
			break;
		*p++ = 0;
	}
	if (p)
		return usage("too many buttons");
	{
		int i;
		for (i = 0; i < nbtn; i++)
			if (!blabel[i][0])
				return usage("empty button label");
	}
	return 0;
}

static int load_file(void)
{
	FILE *f = fopen(opt.file, "r");
	char chunk[4096];

	if (!f) {
		fprintf(stderr, "upkg-ui: cannot read %s\n", opt.file);
		return 2;
	}
	while (fgets(chunk, sizeof chunk, f))
		add_line(chunk);
	fclose(f);
	return 0;
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
	for (fd = opt.kind == K_PROGRAM ? 1 : 0; fd <= 2; fd++) {
		int d;
		if (!isatty(fd) || (d = dup(fd)) < 0)
			continue;
		if ((f = fdopen(d, "r+")) != NULL)
			return f;
		close(d);
	}
	return NULL;
}

/* programbox: the command's lines come on stdin; show each as it arrives, then the OK button */
static void read_program(void)
{
	char chunk[4096];

	follow = 1;
	draw_all();
	refresh();
	while (fgets(chunk, sizeof chunk, stdin)) {
		add_line(chunk);
		draw_all();
		refresh();
	}
	flushinp(); /* keys typed while the command ran must not answer the dialog */
	follow = 0;
	pdone = 1;
}

int main(int argc, char **argv)
{
	int rc = parse(argc, argv), i;
	char out[MAX_INPUT * 4];
	SCREEN *scr;

	if (rc)
		return rc;
	if (init_buttons())
		return 2;
	if (opt.kind == K_TEXTBOX && load_file())
		return 2;
	setlocale(LC_ALL, "");
	utf8 = strcasecmp(nl_langinfo(CODESET), "UTF-8") == 0 || strcasecmp(nl_langinfo(CODESET), "UTF8") == 0;

	if (opt.kind == K_INPUT) {
		blen = bpos = (int)wcslen(opt.init);
		wmemcpy(buf, opt.init, (size_t)blen);
	} else if (opt.kind == K_MENU) {
		for (i = 0; i < opt.nentries; i++)
			if (opt.default_item && !strcmp(opt.entries[i].tag, opt.default_item))
				msel = i;
	}

	set_escdelay(50);
	keyfp = open_keys();
	if (!keyfp) {
		fputs("upkg-ui: no terminal to read the keys from\n", stderr);
		return EXIT_NO_TERMINAL;
	}
	scr = newterm(NULL, stdout, keyfp);
	if (!scr) {
		fputs("upkg-ui: cannot initialise the terminal\n", stderr);
		return 2;
	}
	set_term(scr);
	if (!opt.keep_tite)
		leave_alternate_screen();
	cbreak();
	noecho();
	nonl();
	keypad(stdscr, TRUE);
	curs_set(0);
	init_theme();
	if (opt.kind == K_INPUT)
		curs_set(1);
	if (opt.kind == K_PROGRAM)
		read_program();
	rc = run();
	endwin();
	if (rc == EXIT_NO_TERMINAL) {
		fputs("upkg-ui: the terminal went away (no more keys)\n", stderr);
		return rc;
	}

	if (rc == 0) {
		if (opt.kind == K_INPUT) {
			buf[blen] = 0;
			if (wcstombs(out, buf, sizeof out) == (size_t)-1)
				out[0] = 0;
			fputs(out, stderr);
		} else if (opt.kind == K_MENU) {
			if (!opt.hotkeys)
				fputs(opt.entries[msel].tag, stderr);
			else if (hotkey)
				fprintf(stderr, "%c %s", hotkey, opt.entries[msel].tag);
			else
				fprintf(stderr, "enter %s", opt.entries[msel].tag);
		} else if (opt.buttons) {
			fputs(blabel[bchosen], stderr);
		}
	}
	return rc;
}
