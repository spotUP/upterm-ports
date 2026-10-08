# GNU nano (vtcon plan 1.5): the editor, against ncursesw (0.8), UTF-8.
nano_VERSION   := 9.2
nano_URL       := https://ftp.gnu.org/gnu/nano/nano-$(nano_VERSION).tar.xz
nano_SHA256    := 05ecb99247b782e8a5b3a25ed4101dd034b0236902f7449bc9795b717642f7e9
nano_LICENSE   := GPL-3.0-or-later
nano_DEPS      := ixcompat ncurses
# no NLS catalogues; no libmagic; gnulib's threads would want pthreads.
# PKG_CONFIG is off: ncursesw is named directly (sysroot include/ncursesw).
nano_CONFIGURE := --disable-nls --disable-libmagic --disable-threads --enable-utf8
nano_ENV       := NCURSESW_CFLAGS="-I$(SYSINC)/ncursesw" NCURSESW_LIBS=-lncursesw
# ncursesw also before libixcompat (it needs tsearch from there): the link
# puts NCURSESW_LIBS after LIBS
nano_LIBS      := -lncursesw
# the Mac build against the same ncurses 6.6 (host-ncurses): its colours
# and screen updates are what the rig's must match
nano_HOST_DEPS := ncurses
nano_HOST_CONFIGURE := --disable-nls --disable-libmagic --enable-utf8 \
	NCURSESW_CFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	NCURSESW_LIBS="-L$(HOST_NCURSES)/lib -lncursesw"
nano_BINS      := bin/nano
# provisional, grep's value: the regex code recurses
nano_STACK     := 262144
