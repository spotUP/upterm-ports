/* upkg-ui: the add-on install questions of UP-Term (vtcon upkg plan P10.6), a small ncurses
 * program that replaces dialog, drawn in the AmiExpress door SDK chrome (theme "Uprough Neon
 * (muted)"). The line builders are in chrome.c (pure, unit tested); this file is curses + args.
 *
 *   upkg-ui [--title T] [--backtitle V] [--defaultno] [--no-items] [--default-item X]
 *           (--inputbox PROMPT H W [INIT] | --yesno PROMPT H W | --menu PROMPT H W MH ITEM...)
 *
 * dialog-compatible subset: H, W and MH are accepted and ignored (the screen is the whole
 * terminal). The answer goes to STDERR (curses owns stdout). Exit 0 accept, 1 cancel or No,
 * 255 Escape, 2 usage error. */
#define _XOPEN_SOURCE_EXTENDED 1
#include <langinfo.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <wchar.h>

#include <curses.h>

#include "chrome.h"

#define RAIL "/////"
#define DEFAULT_TITLE "UP-TERM ADD-ON"
#define MAX_INPUT 1024

enum kind { K_NONE, K_INPUT, K_YESNO, K_MENU };

typedef struct {
	const char *tag;
	const char *item;
} entry;

static struct {
	const char *title, *backtitle, *prompt, *default_item;
	int defaultno, no_items, kind;
	wchar_t init[MAX_INPUT];
	entry *entries;
	int nentries;
} opt;

static int utf8, tick;
static attr_t a_chrome, a_ink, a_dim, a_acc, a_sel, a_field;

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

static wchar_t buf[MAX_INPUT];
static int blen, bpos, boff, bx, by;
static int yes_chosen;
static int msel, mtop;

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

static void draw_yesno(int y)
{
	int x = 4;
	text(y, x, yes_chosen ? a_sel : a_ink, " Yes ", 5);
	text(y, x + 8, yes_chosen ? a_ink : a_sel, " No ", 4);
}

static int menu_room(int y)
{
	int r = LINES - 4 - y;
	return r < 1 ? 1 : r;
}

static void draw_menu(int y)
{
	int room = menu_room(y), i, w = COLS - 4;

	if (msel < mtop)
		mtop = msel;
	if (msel >= mtop + room)
		mtop = msel - room + 1;
	for (i = 0; i < room && mtop + i < opt.nentries; i++) {
		const entry *e = &opt.entries[mtop + i];
		int sel = mtop + i == msel;
		attr_t a = sel ? a_sel : a_ink;
		spaces(y + i, 2, w, a);
		text(y + i, 3, a, e->tag, w - 2);
		if (e->item && *e->item) {
			int x = 3 + (int)strlen(e->tag) + 2;
			text(y + i, x, sel ? a_sel : a_dim, e->item, w + 2 - x);
		}
	}
}

static const ch_hint H_INPUT[] = { { "Enter", "Accept", 1 }, { "Escape", "Cancel", 1 } };
static const ch_hint H_YESNO[] = { { "Left/Right", "Choose", 0 }, { "Enter", "Accept", 1 },
	                                { "Escape", "Cancel", 1 } };
static const ch_hint H_MENU[] = { { "Up/Down", "Move", 0 }, { "Enter", "Accept", 1 },
	                               { "Escape", "Cancel", 1 } };

static int widget_row;

static void draw_all(void)
{
	erase();
	frame_box();
	draw_masthead();
	hrule(2, G_LT, G_RT);
	widget_row = draw_prompt(3) + 1;
	hrule(LINES - 3, G_LT, G_RT);
	switch (opt.kind) {
	case K_INPUT:
		draw_input(widget_row);
		draw_footer(H_INPUT, 2);
		break;
	case K_YESNO:
		draw_yesno(widget_row);
		draw_footer(H_YESNO, 3);
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

static int key_yesno(int fn, wint_t c)
{
	if (fn) {
		if (c == KEY_LEFT || c == KEY_RIGHT)
			yes_chosen = !yes_chosen;
		else if (c == KEY_ENTER)
			return yes_chosen ? 0 : 1;
		return -1;
	}
	if (c == '\t')
		yes_chosen = !yes_chosen;
	else if (c == '\n' || c == '\r')
		return yes_chosen ? 0 : 1;
	else if (c == 'y' || c == 'Y')
		return 0;
	else if (c == 'n' || c == 'N')
		return 1;
	return -1;
}

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
	int redraw = 1;
	wint_t c;

	timeout(1000);
	for (;;) {
		int r, code;
		if (redraw) {
			draw_all();
			redraw = 0;
		}
		place_cursor();
		refresh();
		r = get_wch(&c);
		if (r == ERR) { /* a tick: the rail's cells only */
			tick++;
			paint_rail();
			continue;
		}
		if (r == KEY_CODE_YES && c == KEY_RESIZE) {
			redraw = 1;
			continue;
		}
		if (r == OK && c == 27)
			return 255;
		switch (opt.kind) {
		case K_INPUT: code = key_input(r == KEY_CODE_YES, c); break;
		case K_YESNO: code = key_yesno(r == KEY_CODE_YES, c); break;
		default: code = key_menu(r == KEY_CODE_YES, c); break;
		}
		if (code >= 0)
			return code;
		redraw = 1;
	}
}

/* ---- arguments ---- */

static int usage(const char *why)
{
	if (why)
		fprintf(stderr, "upkg-ui: %s\n", why);
	fputs("usage: upkg-ui [--title T] [--backtitle V] [--defaultno] [--no-items] [--default-item X]\n"
	      "       (--inputbox PROMPT H W [INIT] | --yesno PROMPT H W | --menu PROMPT H W MH ITEM...)\n",
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
		else if (!strcmp(a, "--defaultno"))
			opt.defaultno = 1;
		else if (!strcmp(a, "--no-items"))
			opt.no_items = 1;
		else if (!strcmp(a, "--inputbox") || !strcmp(a, "--yesno") || !strcmp(a, "--menu")) {
			int need = !strcmp(a, "--menu") ? 4 : 3; /* PROMPT H W (MH) must follow */
			int extra = 0;
			if (opt.kind != K_NONE)
				return usage("only one widget");
			opt.kind = !strcmp(a, "--inputbox") ? K_INPUT : !strcmp(a, "--yesno") ? K_YESNO : K_MENU;
			if (argc - 1 - i < need)
				return usage("missing arguments");
			opt.prompt = argv[++i];
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
	return 0;
}

int main(int argc, char **argv)
{
	int rc = parse(argc, argv), i;
	char out[MAX_INPUT * 4];

	if (rc)
		return rc;
	setlocale(LC_ALL, "");
	utf8 = strcasecmp(nl_langinfo(CODESET), "UTF-8") == 0 || strcasecmp(nl_langinfo(CODESET), "UTF8") == 0;

	if (opt.kind == K_INPUT) {
		blen = bpos = (int)wcslen(opt.init);
		wmemcpy(buf, opt.init, (size_t)blen);
	} else if (opt.kind == K_YESNO) {
		yes_chosen = !opt.defaultno;
	} else {
		for (i = 0; i < opt.nentries; i++)
			if (opt.default_item && !strcmp(opt.entries[i].tag, opt.default_item))
				msel = i;
	}

	set_escdelay(50);
	if (!initscr()) {
		fputs("upkg-ui: cannot initialise the terminal\n", stderr);
		return 2;
	}
	cbreak();
	noecho();
	nonl();
	keypad(stdscr, TRUE);
	curs_set(0);
	init_theme();
	if (opt.kind == K_INPUT)
		curs_set(1);
	rc = run();
	endwin();

	if (rc == 0) {
		if (opt.kind == K_INPUT) {
			buf[blen] = 0;
			if (wcstombs(out, buf, sizeof out) == (size_t)-1)
				out[0] = 0;
			fputs(out, stderr);
		} else if (opt.kind == K_MENU) {
			fputs(opt.entries[msel].tag, stderr);
		}
	}
	return rc;
}
