/* ui.h: the interface of libupkgui (ui.c, chrome.c). One screen at a time on the terminal; the
 * caller fills ui_opt (what to show), calls ui_start once, then ui_view or ui_run for each widget,
 * and ui_stop at the end. upkg-ui does that once per run; `upkg browse` (inside upkg) keeps the
 * screen up and shows many widgets in a row. */
#ifndef UPKG_UI_H
#define UPKG_UI_H

#include <stdio.h>
#include <wchar.h>

#define EXIT_NO_TERMINAL 3 /* no terminal to read keys from (none at the start, or it went away) */
#define UI_MAX_INPUT 1024

enum kind { K_NONE, K_INPUT, K_YESNO, K_MENU, K_MSGBOX, K_TEXTBOX, K_PROGRAM };

typedef struct {
	const char *tag;
	const char *item;
} entry;

typedef struct {
	const char *title, *backtitle, *prompt, *default_item, *hotkeys, *buttons, *file;
	int defaultno, no_items, colors, keep_tite, kind;
	wchar_t init[UI_MAX_INPUT];
	entry *entries;
	int nentries;
	const unsigned *entry_flags; /* optional, one CH_ENTRY_* (chrome.h) per entry: what the menu footer offers; NULL is the plain footer */
} ui_opts;

extern ui_opts ui_opt;

/* The OSD style (ui_osd): a launcher look for a menu in a borderless window. No masthead, rail,
 * frame or footer. UI_OSD_TOP_LINES blank rows come first, then the filter line, the next
 * UI_OSD_GAP_LINES rows are a gap, then one menu entry per row, then UI_OSD_BOTTOM_LINES blank
 * rows; the selected row is a bar across the full width. Text sits UI_OSD_PAD cells from the left
 * edge and an entry's item (a group's ">") is right-aligned, UI_OSD_PAD cells from the right edge.
 * A caller sizing its window for n entries needs UI_OSD_HEAD_LINES + n + UI_OSD_BOTTOM_LINES rows
 * and its widest "tag  item" line + 2 * UI_OSD_PAD columns. */
#define UI_OSD_PAD_LINES    1 /* blank rows of vertical padding: a cell is about twice as tall as wide, so one row looks as wide as UI_OSD_PAD (2) cells (measured 16 px by 16 px on the rig) */
#define UI_OSD_TOP_LINES    UI_OSD_PAD_LINES /* above the filter line */
#define UI_OSD_FILTER_LINES 1 /* the filter line */
#define UI_OSD_GAP_LINES    1 /* blank rows between the filter line and the first entry */
#define UI_OSD_BOTTOM_LINES UI_OSD_PAD_LINES /* below the last entry row */
#define UI_OSD_HEAD_LINES   (UI_OSD_TOP_LINES + UI_OSD_FILTER_LINES + UI_OSD_GAP_LINES)
#define UI_OSD_PAD          2 /* cells of padding left of the text (and right of it) */

/* Turn the OSD style on or off. Set before the menu is shown; default off (the framed look). */
void ui_osd(int on);

/* the terminal: locale, keys, curses, theme; 0, EXIT_NO_TERMINAL or 2 (a message on stderr,
 * prefixed with who). ui_stop ends curses. */
int ui_start(const char *who);
void ui_stop(void);

/* input text and menu default from ui_opt, before the first ui_run */
void ui_prepare(void);

/* The button labels of ui_opt.buttons (comma separated), else Yes,No or OK; NULL, or why not. */
const char *ui_init_buttons(void);

/* run the widget ui_opt describes: 0 accepted, 1 No, 255 Escape, EXIT_NO_TERMINAL */
int ui_run(void);
/* fn runs once each tick while a widget waits for a key; a nonzero return ends ui_run with
 * UI_TICK, keeping ui_selected() and the filter as they were. NULL turns it off. */
#define UI_TICK 4
void ui_on_tick(int (*fn)(void *ctx), void *ctx);
/* the same for a widget of KIND on the screen already up: prompt and buttons replace ui_opt's;
 * 2 when the buttons are bad */
int ui_view(int kind, const char *prompt, const char *buttons);
/* a message box with printf format FMT (one %s: TAG) and an OK button */
int ui_message(const char *fmt, const char *tag);

/* the text of a textbox or programbox: one line at a time (a newline ends it) */
void ui_clear_lines(void);
void ui_add_line(const char *s);
/* programbox: begin shows the box, each line is added and drawn, done drops the keys typed
 * meanwhile and arms the OK button (then ui_view(K_PROGRAM) waits for it) */
void ui_program_begin(const char *prompt);
void ui_program_line(const char *s);
void ui_program_done(void);
/* programbox from stdin or a pipe: begin, lines to the end, done */
void ui_read_lines(FILE *in);

/* menu hotkeys: put this byte (Ctrl-B) in ui_opt.hotkeys and the Left arrow ends the menu with
 * ui_hotkey() == UI_HOTKEY_LEFT, as Backspace does with 8 or 127. Without it Left does nothing. */
#define UI_HOTKEY_LEFT 2

/* what the last widget answered */
int ui_hotkey(void);              /* the --hotkeys key that ended a menu, 0 for Enter */
int ui_selected(void);            /* the menu row */
void ui_select(int row);          /* put the menu cursor on row (the top follows) */
const char *ui_button(void);      /* the chosen button's label */
void ui_answer(FILE *out);        /* what upkg-ui writes for the last widget (stderr) */

/* the terminal curses reads keys from */
FILE *ui_keys(void);
/* Leave curses for a program that draws on the real terminal (a package's scripts), and come
 * back: ui_suspend clears the screen; ui_resume repaints. */
void ui_suspend(void);
void ui_resume(void);

#endif
