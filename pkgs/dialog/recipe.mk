# dialog (vtcon upkg plan P10.6): curses widgets for add-on install questions (upkg-ask), against
# ncursesw. Runs as its own program, so its LGPL needs only attribution and its source.
dialog_VERSION   := 1.3-20260721
dialog_URL       := https://invisible-island.net/archives/dialog/dialog-$(dialog_VERSION).tgz
dialog_SHA256    := 62bdf59057d4f760a1cc2217827f07887b4a3eebf694c25eacd4803d2171cdc6
dialog_LICENSE   := LGPL-2.1-only
dialog_LICENSE_FILES := COPYING
dialog_DEPS      := ixcompat ncurses
# no NLS catalogues; the widgets upkg-ask uses (yesno, inputbox, menu, checklist, msgbox) are not
# extras, so the calendar/gauge/tailbox/... code stays out
dialog_CONFIGURE := --with-ncursesw --disable-nls --disable-extras --disable-rc-file
# configure would otherwise run the Mac's MacPorts ncursesw6-config and put -I/opt/local/include and
# -Wl,-search_paths_first into the m68k link tests (every curses function test then fails)
dialog_ENV       := CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" NCURSES_CONFIG=none PKG_CONFIG=none
dialog_LIBS      := -lncursesw
dialog_HOST_DEPS := ncurses
dialog_HOST_CONFIGURE := --with-ncursesw --disable-nls --disable-extras --disable-rc-file \
	NCURSES_CONFIG=none PKG_CONFIG=none \
	CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	LDFLAGS="-L$(HOST_NCURSES)/lib"
dialog_BINS      := bin/dialog
dialog_STACK     := 65536
# upkg-ui (pkgs/upkg-ui) replaced dialog in upkg-ask: built and checked, no longer shipped
dialog_NO_KIT    := 1
