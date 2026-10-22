/* upkg-ui: the add-on install questions of UP-Term (vtcon upkg plan P10.6), a small ncurses
 * program that replaces dialog, drawn in the AmiExpress door SDK chrome (theme "Uprough Neon
 * (muted)"). The widgets are libupkgui (ui.c, chrome.c; `upkg browse` links the same library); this file
 * is the arguments and the answer.
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
 * another (upkg-ask) would otherwise show the Shell between every two, as each run * switched to the alternate screen at the start and back at the exit. Such a script clears the
 * screen when it ends. --keep-tite keeps the switch (the Shell comes back at the exit). */
#define _XOPEN_SOURCE_EXTENDED 1
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "ui.h"


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
			ui_opt.title = argv[++i];
		else if (!strcmp(a, "--backtitle") && i + 1 < argc)
			ui_opt.backtitle = argv[++i];
		else if (!strcmp(a, "--default-item") && i + 1 < argc)
			ui_opt.default_item = argv[++i];
		else if (!strcmp(a, "--hotkeys") && i + 1 < argc)
			ui_opt.hotkeys = argv[++i];
		else if (!strcmp(a, "--buttons") && i + 1 < argc)
			ui_opt.buttons = argv[++i];
		else if (!strcmp(a, "--colors"))
			ui_opt.colors = 1;
		else if (!strcmp(a, "--defaultno"))
			ui_opt.defaultno = 1;
		else if (!strcmp(a, "--keep-tite"))
			ui_opt.keep_tite = 1;
		else if (!strcmp(a, "--no-items"))
			ui_opt.no_items = 1;
		else if (!strcmp(a, "--inputbox") || !strcmp(a, "--yesno") || !strcmp(a, "--menu") ||
		         !strcmp(a, "--msgbox") || !strcmp(a, "--textbox") || !strcmp(a, "--programbox")) {
			int need = !strcmp(a, "--menu") ? 4 : 3; /* PROMPT H W (MH) follow */
			int extra = 0;
			if (ui_opt.kind != K_NONE)
				return usage("only one widget");
			ui_opt.kind = !strcmp(a, "--inputbox") ? K_INPUT : !strcmp(a, "--yesno") ? K_YESNO :
			           !strcmp(a, "--msgbox") ? K_MSGBOX : !strcmp(a, "--textbox") ? K_TEXTBOX :
			           !strcmp(a, "--programbox") ? K_PROGRAM : K_MENU;
			if (argc - 1 - i < need)
				return usage("missing arguments");
			ui_opt.prompt = argv[++i];
			if (ui_opt.kind == K_TEXTBOX)
				ui_opt.file = ui_opt.prompt;
			i += 2; /* H W */
			if (ui_opt.kind == K_MENU) {
				i++; /* MH */
				extra = argc - 1 - i;
				if (extra < 1)
					return usage("menu needs at least one item");
				/* tags only, or tag/item pairs; --no-items with an empty item after every
				 * tag is the pair form upkg-ask has always passed */
				no_items_pairs = !ui_opt.no_items;
				if (ui_opt.no_items && extra % 2 == 0) {
					no_items_pairs = 1;
					for (j = 1; j <= extra; j += 2)
						if (argv[i + 1 + j][0])
							no_items_pairs = 0;
				}
				{
					int step = (ui_opt.no_items && !no_items_pairs) ? 1 : 2;
					if (step == 2 && extra % 2)
						return usage("menu items come as tag item pairs");
					ui_opt.nentries = extra / step;
					ui_opt.entries = calloc((size_t)ui_opt.nentries, sizeof *ui_opt.entries);
					if (!ui_opt.entries)
						return usage("out of memory");
					for (j = 0; j < ui_opt.nentries; j++) {
						ui_opt.entries[j].tag = argv[i + 1 + j * step];
						ui_opt.entries[j].item = step == 2 && !ui_opt.no_items ? argv[i + 2 + j * step] : "";
					}
				}
				i = argc;
			} else if (ui_opt.kind == K_INPUT) {
				if (i + 1 < argc)
					mbstowcs(ui_opt.init, argv[++i], UI_MAX_INPUT - 1);
				if (i + 1 < argc)
					return usage("too many arguments");
			} else if (i + 1 < argc) {
				return usage("too many arguments");
			}
		} else {
			return usage("unknown option");
		}
	}
	if (ui_opt.kind == K_NONE)
		return usage("no widget");
	if (ui_opt.prompt == NULL)
		return usage("missing arguments");
	if (ui_opt.hotkeys && ui_opt.kind != K_MENU)
		return usage("hotkeys need a menu");
	if (ui_opt.buttons && ui_opt.kind != K_MSGBOX && ui_opt.kind != K_TEXTBOX)
		return usage("buttons need a msgbox or a textbox");
	if (ui_opt.colors && ui_opt.kind != K_MENU)
		return usage("colors need a menu");
	return 0;
}

static int load_file(void)
{
	FILE *f = fopen(ui_opt.file, "r");
	char chunk[4096];

	if (!f) {
		fprintf(stderr, "upkg-ui: cannot read %s\n", ui_opt.file);
		return 2;
	}
	while (fgets(chunk, sizeof chunk, f))
		ui_add_line(chunk);
	fclose(f);
	return 0;
}

static void read_program(void)
{
	ui_read_lines(stdin);
	ui_program_done();
}

int main(int argc, char **argv)
{
	int rc = parse(argc, argv);
	const char *bad;

	if (rc)
		return rc;
	if ((bad = ui_init_buttons()) != NULL)
		return usage(bad);
	if (ui_opt.kind == K_TEXTBOX && load_file())
		return 2;
	ui_prepare();
	rc = ui_start("upkg-ui");
	if (rc)
		return rc;
	if (ui_opt.kind == K_PROGRAM)
		read_program();
	rc = ui_run();
	ui_stop();
	if (rc == EXIT_NO_TERMINAL) {
		fputs("upkg-ui: the terminal went away (no more keys)\n", stderr);
		return rc;
	}
	if (rc == 0)
		ui_answer(stderr);
	return rc;
}
