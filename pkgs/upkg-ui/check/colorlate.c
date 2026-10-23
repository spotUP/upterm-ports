/* colorlate.c: driver for colorlate.sh. Starts curses first and sets ui_opt.colors afterwards, as
 * `upkg browse` does (it is one program with its own option parsing; the colour switch belongs to
 * the menu it shows, not to ui_start). The second (unselected) row carries the code \Z2 (green). */
#include <upkgui/ui.h>

int main(void)
{
	static entry ent[2] = { { "alpha", "available" }, { "beta", "\\Z2installed" } };

	if (ui_start("colorlate"))
		return 2;
	ui_opt.kind = K_MENU;
	ui_opt.title = "Menu";
	ui_opt.prompt = "p";
	ui_opt.entries = ent;
	ui_opt.nentries = 2;
	ui_opt.colors = 1;
	ui_prepare();
	ui_run();
	ui_stop();
	return 0;
}
