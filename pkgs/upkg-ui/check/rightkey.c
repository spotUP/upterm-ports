/* rightkey.c: driver for rightkey.sh. Shows one menu twice: run 1 with UI_HOTKEY_RIGHT in the
 * hotkeys, run 2 without. The keys are Right, then Right and Enter. Writes
 * "<hotkey of run 1> <hotkey of run 2>" to argv[1]. */
#include <stdio.h>
#include <upkgui/ui.h>

int main(int argc, char **argv)
{
	static entry ent[2] = { { "alpha", "" }, { "beta", "" } };
	char with[3] = { 's', UI_HOTKEY_RIGHT, 0 };
	int h1, h2;
	FILE *f;
	(void)argc;
	if (ui_start("rightkey"))
		return 2;
	ui_opt.kind = K_MENU;
	ui_opt.title = "Menu";
	ui_opt.prompt = "p";
	ui_opt.entries = ent;
	ui_opt.nentries = 2;
	ui_opt.hotkeys = with;
	ui_prepare();
	ui_run();
	h1 = ui_hotkey();
	ui_opt.hotkeys = "s";
	ui_prepare();
	ui_run();
	h2 = ui_hotkey();
	ui_stop();
	f = fopen(argv[1], "w");
	fprintf(f, "%d %d\n", h1, h2);
	fclose(f);
	return 0;
}
