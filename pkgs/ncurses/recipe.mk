# ncurses 6 with wide characters (vtcon ledger N1, plan item 0.8): the
# library ncursesw for less, nano, vim, and the terminal tools.
ncurses_VERSION := 6.6
ncurses_URL     := https://invisible-island.net/archives/ncurses/ncurses-$(ncurses_VERSION).tar.gz
ncurses_SHA256  := 355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11
ncurses_LICENSE := MIT (X11)
ncurses_DEPS    := ixcompat
# The terminfo database is the kit's, compiled on the host by the host tic
# into ENVARC:up-term/terminfo (vtcon Makefile), so the cross build installs
# none (--disable-db-install) and looks there (/ENV/up-term = ENV:up-term).
# Build tools (make_hash, make_keys) run on the Mac: --with-build-cc.
# Amiga file systems ignore case: the hashed layout (76/vtcon), which the
# host tic writes too (cf_cv_mixedcase=no). --disable-stripping: install
# would run the Mac's strip on m68k files.
ncurses_CONFIGURE := --enable-widec --without-cxx --without-cxx-binding --without-ada \
	--disable-shared --with-normal --without-debug --without-profile \
	--with-terminfo-dirs=/ENV/up-term/terminfo \
	--with-default-terminfo-dir=/ENV/up-term/terminfo \
	--disable-db-install --disable-stripping --disable-pc-files \
	--with-build-cc=cc --without-tests --enable-sigwinch
ncurses_ENV     := cf_cv_mixedcase=no
ncurses_HOST_CONFIGURE := --enable-widec --without-cxx --without-cxx-binding --without-ada \
	--disable-shared --without-debug --without-tests --disable-db-install
# pkgs/ncurses/check/*.sh run against the host build (frame_write: one write per doupdate)
ncurses_CHECK_SH_BIN := bin/tput
ncurses_BINS    := bin/tput bin/tset bin/reset bin/clear bin/infocmp bin/tic bin/toe bin/tabs
# tput, tset, clear... expand terminfo through tparm; started by vfork+exec (vsh, scripts) they ignore
# the $STACK: cookie and get 16 KB, which tparm overruns (Alert 81000005): cookie and __stack both
ncurses_STACK     := 262144
ncurses_STACK_VAR := 1
# configure records LDFLAGS in ncursesw6-config --libs, so the cookie object would reach every package
# that asks the script for its libraries (lynx: multiple definition of __stack): strip it
ncurses_POST_INSTALL = sed -i.bak 's| -Wl,[^ ]*ncurses\.stack\.o||' $(SYSROOT)$(PREFIX)/bin/ncurses*-config && rm -f $(SYSROOT)$(PREFIX)/bin/ncurses*-config.bak
