/* restart.c: driver for restart.sh. ui_start, one menu, ui_stop, then (after restart.sh resized the
 * terminal) ui_start, a second menu, ui_stop, all in one process. Writes
 * "<selected 1> <rows 1> <cols 1> <selected 2> <rows 2> <cols 2> <fds leaked>" to argv[1]; the
 * driver is run from a pty whose size restart.sh changes while the screen is stopped. */
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <curses.h>
#include <upkgui/ui.h>

static int next_fd(void)
{
	int fd = dup(0);
	close(fd);
	return fd;
}

int main(int argc, char **argv)
{
	static entry ent[2] = { { "alpha", "" }, { "beta", "" } };
	int fd0, leaked, sel1, r1, c1, sel2, r2, c2, i;
	struct stat st;
	char go[512];
	FILE *f;
	(void)argc;
	snprintf(go, sizeof go, "%s.go", argv[1]);
	fd0 = next_fd();
	for (i = 0; i < 2; i++) {
		if (ui_start("restart"))
			return 2;
		ui_opt.kind = K_MENU;
		ui_opt.title = "Menu";
		ui_opt.prompt = "p";
		ui_opt.entries = ent;
		ui_opt.nentries = 2;
		ui_opt.hotkeys = "s";
		ui_prepare();
		if (i == 0) {
			r1 = LINES, c1 = COLS;
			ui_run();
			sel1 = ui_selected();
			ui_stop();
			f = fopen(argv[1], "w"); /* tells restart.sh to resize the terminal */
			fclose(f);
			for (i = 0; i < 100 && stat(go, &st); i++)
				usleep(50000);
			i = 0;
		} else {
			r2 = LINES, c2 = COLS;
			ui_run();
			sel2 = ui_selected();
			ui_stop();
		}
	}
	leaked = next_fd() - fd0;
	f = fopen(argv[1], "w");
	fprintf(f, "%d %d %d %d %d %d %d\n", sel1, r1, c1, sel2, r2, c2, leaked);
	fclose(f);
	return 0;
}
