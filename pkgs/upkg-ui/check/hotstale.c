/* hotstale.c: driver for hotstale.sh. Runs one menu with --hotkeys "st" twice on the same
 * terminal, as a program that re-shows a menu does (amarchy-menu). The keys are 's' then Enter;
 * writes "<hotkey of run 1> <hotkey of run 2>" to argv[1]. */
#include <stdio.h>
#include <upkgui/ui.h>

int main(int argc, char **argv)
{
	static entry ent[2] = { { "alpha", "" }, { "beta", "" } };
	int h1, h2;
	FILE *f;
	(void)argc;
	if (ui_start("hotstale"))
		return 2;
	ui_opt.kind = K_MENU;
	ui_opt.title = "Menu";
	ui_opt.prompt = "p";
	ui_opt.hotkeys = "st";
	ui_opt.entries = ent;
	ui_opt.nentries = 2;
	ui_prepare();
	ui_run();
	h1 = ui_hotkey();
	ui_prepare();
	ui_run();
	h2 = ui_hotkey();
	ui_stop();
	f = fopen(argv[1], "w");
	fprintf(f, "%d %d\n", h1, h2);
	fclose(f);
	return 0;
}
