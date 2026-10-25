/* test_chrome: pins the exact strings of chrome.c. Run on the host (cc test_chrome.c chrome.c).
 * Expected masthead, rail and footer strings come from chrome.ts itself:
 *   cd amiexpress-web && npx tsx -e "import {mastheadLine,railFrame,railPattern,footerHints} from
 *   './sdk/engines/ui/theme/chrome.ts'; ..." with rail "/////", title "UP-TERM ADD-ON", value
 *   "install 1/3", hints Up/Down: Move, Enter: Accept (keep), Escape: Cancel (keep), rail "/////".
 * The ASCII leader variants are the same strings with "." for the middle dot. */
#include "chrome.h"

#include <stdio.h>
#include <string.h>

static int fails, checks;

static void eq(const char *what, const char *got, const char *want)
{
	checks++;
	if (strcmp(got, want)) {
		fails++;
		printf("FAIL %s\n  got  \"%s\"\n  want \"%s\"\n", what, got, want);
	}
}

static void eqi(const char *what, long got, long want)
{
	checks++;
	if (got != want) {
		fails++;
		printf("FAIL %s: got %ld want %ld\n", what, got, want);
	}
}

static void mast(int w, const char *leader, const char *want, const char *tag)
{
	char buf[400];
	char what[64];
	snprintf(what, sizeof what, "masthead %d %s", w, tag);
	ch_masthead_line(buf, sizeof buf, w, "/////", "UP-TERM ADD-ON", "install 1/3", leader);
	eq(what, buf, want);
}

static const ch_hint MENU[] = {
	{ "Up/Down", "Move", 0 }, { "Enter", "Accept", 1 }, { "Escape", "Cancel", 1 }
};

static void foot(int fit, const char *want, unsigned shown, int rail)
{
	char buf[200], what[40];
	ch_foot f = ch_footer_fit(MENU, 3, "/////", fit);
	snprintf(what, sizeof what, "footer fit %d", fit);
	ch_footer_text(buf, sizeof buf, MENU, 3, "/////", f);
	eq(what, buf, want);
	eqi("footer shown", f.shown, shown);
	eqi("footer rail", f.rail, rail);
	eqi("footer len", f.len, (long)strlen(buf));
}

int main(void)
{
	char buf[200];
	ch_span sp[16];
	ch_mast m;
	int t, n;

	/* masthead, UTF-8 leader (from chrome.ts) */
	mast(80, CH_LEADER_UTF8,
	     "///// UP-TERM ADD-ON \xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7 install 1/3",
	     "utf8");
	mast(40, CH_LEADER_UTF8,
	     "///// UP-TERM ADD-ON \xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7\xc2\xb7 install 1/3", "utf8");
	/* masthead, ASCII leader */
	mast(80, CH_LEADER_ASCII,
	     "///// UP-TERM ADD-ON ............................................... install 1/3", "ascii");
	mast(40, CH_LEADER_ASCII, "///// UP-TERM ADD-ON ....... install 1/3", "ascii");
	/* too narrow: the title is trimmed, the value stays (chrome.ts pads to width) */
	mast(20, CH_LEADER_ASCII, "///// U install 1/3 ", "narrow");
	mast(12, CH_LEADER_ASCII, "/////  insta", "narrow");
	mast(8, CH_LEADER_ASCII, "/////  i", "narrow");
	mast(20, CH_LEADER_UTF8, "///// U install 1/3 ", "narrow utf8");

	/* layout columns of the 40-wide line */
	ch_mast_layout(&m, 40, "/////", "UP-TERM ADD-ON", "install 1/3");
	eqi("layout rail_len", m.rail_len, 5);
	eqi("layout title_col", m.title_col, 6);
	eqi("layout title_len", m.title_len, 14);
	eqi("layout lead_col", m.lead_col, 21);
	eqi("layout lead_n", m.lead_n, 7);
	eqi("layout value_col", m.value_col, 29);
	eqi("layout value_len", m.value_len, 11);
	ch_mast_layout(&m, 20, "/////", "UP-TERM ADD-ON", "install 1/3");
	eqi("narrow lead_n", m.lead_n, 0);
	eqi("narrow title_len", m.title_len, 1);
	eqi("narrow value_col", m.value_col, 8);
	eqi("narrow value_len", m.value_len, 11);

	/* rail frames 0..5 (period 5; from chrome.ts railFrame) */
	{
		static const char *const want[] = { "/////", " ////", "  ///", "   //", "    /", "/////" };
		for (t = 0; t <= 5; t++) {
			ch_rail_frame(buf, sizeof buf, "/////", t);
			eq("rail frame", buf, want[t]);
		}
		ch_rail_frame(buf, sizeof buf, "/////", -1);
		eq("rail frame -1", buf, "    /");
	}
	ch_rail_pattern(buf, sizeof buf, "/////", 7, 0, 0);
	eq("rail pattern", buf, "///////");
	ch_rail_pattern(buf, sizeof buf, "//", 7, 1, 0);
	eq("rail pattern gap", buf, "// // /");
	ch_rail_pattern(buf, sizeof buf, "//", 5, 1, 1);
	eq("rail pattern offset", buf, "/ // ");

	/* footer fitting and drop order (from chrome.ts footerHints) */
	foot(80, "Up/Down: Move  Enter: Accept  Escape: Cancel  /////", 7, 1);
	foot(50, "Up/Down: Move  Enter: Accept  Escape: Cancel", 7, 0);
	foot(40, "Enter: Accept  Escape: Cancel", 6, 0);
	foot(10, "Enter: Accept  Escape: Cancel", 6, 0); /* keep hints stay, even too wide */
	foot(-1, "Up/Down: Move  Enter: Accept  Escape: Cancel  /////", 7, 1);
	{
		/* drop from the END that is not keep: Last, then First; keep ones survive */
		static const ch_hint H[] = {
			{ "A", "one", 0 }, { "B", "two", 1 }, { "C", "three", 0 }, { "D", "four", 1 }
		};
		ch_foot f = ch_footer_fit(H, 4, "", 14);
		ch_footer_text(buf, sizeof buf, H, 4, "", f);
		eq("drop order", buf, "B: two  D: four");
		eqi("drop order mask", f.shown, 10);
	}

	/* word wrap */
	n = ch_wrap_words("Where should it install the files", 12, sp, 16);
	eqi("wrap count", n, 3);
	eqi("wrap 0", sp[0].len, 12); /* "Where should" */
	eqi("wrap 1 start", sp[1].start, 13);
	eqi("wrap 1", sp[1].len, 10); /* "it install" */
	eqi("wrap 2 start", sp[2].start, 24);
	eqi("wrap 2", sp[2].len, 9); /* "the files" */
	n = ch_wrap_words("abcdefghij kl", 4, sp, 16);
	eqi("long word count", n, 4);
	eqi("long word 0", sp[0].len, 4);
	eqi("long word 2", sp[2].len, 2);
	eqi("long word 3 start", sp[3].start, 11);
	n = ch_wrap_words("one\n\ntwo", 40, sp, 16);
	eqi("newline count", n, 3);
	eqi("newline blank", sp[1].len, 0);
	eqi("newline two", sp[2].start, 5);
	n = ch_wrap_words("", 40, sp, 16);
	eqi("empty", n, 0);

	/* menu item column (owner, 2026-10-22: "we need even columns its messy"): the items start
	 * after the WIDEST tag, so up-claude and up-pi rows put their items in one column */
	eqi("vis plain", ch_vis_len("up-pi", 0), 5);
	eqi("vis colour codes", ch_vis_len("\\Z3up-pi\\Zn", 1), 5);
	eqi("vis codes without --colors", ch_vis_len("\\Z3up-pi", 0), 8);
	{
		static const char *const pairs[] = { "up-pi", "installed 1.0", "up-claude", "x",
		                                     "up-git", "a much longer item than any tag" };
		eqi("widest tag", ch_widest(pairs, 3, 2, 0), 9);
		eqi("widest item", ch_widest(pairs + 1, 3, 2, 0), 31);
		eqi("widest none", ch_widest(pairs, 0, 2, 0), 0);
	}

	/* OSD layout: a blank row, the filter line, one gap row, entries, a blank row; bar over the
	 * full width; items end pad cells from the right edge */
	{
		ch_osd o = ch_osd_layout(16, 40, 1, 1, 1, 1, 2);
		eqi("osd filter row", o.filter_row, 1);
		eqi("osd first entry row", o.first_row, 3);
		eqi("osd entry rows", o.rows, 12);
		eqi("osd bar x", o.bar_x, 0);
		eqi("osd bar width", o.bar_w, 40);
		eqi("osd text x", o.text_x, 2);
		eqi("osd item end", o.item_end, 38);
		eqi("osd tiny screen keeps one row", ch_osd_layout(1, 40, 1, 1, 1, 1, 2).rows, 1);
	}

	printf("test_chrome: %d checks, %d failed\n", checks, fails);
	return fails ? 1 : 0;
}
