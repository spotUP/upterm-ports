# ncdu 1.x (vtcon plan 3.6): the disk usage browser, C and ncurses (2.x is Zig).
ncdu_VERSION   := 1.22
ncdu_URL       := https://dev.yorhel.nl/download/ncdu-$(ncdu_VERSION).tar.gz
ncdu_SHA256    := 0ad6c096dc04d5120581104760c01b8f4e97d4191d6c9ef79654fa3c691a176b
ncdu_LICENSE   := MIT
ncdu_LICENSE_FILES := COPYING
ncdu_DEPS      := ixcompat ncurses
ncdu_CONFIGURE := --with-ncursesw
# configure.ac asks pkg-config for ncursesw: PKG_CONFIG=true passes its version check and
# the presets answer the query (no pkg-config on the Amiga side, and none is run)
ncdu_ENV       := CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" PKG_CONFIG=true NCURSES_CFLAGS="-I$(SYSINC)/ncursesw" NCURSES_LIBS=-lncursesw
ncdu_HOST_DEPS := ncurses
ncdu_HOST_CONFIGURE := --with-ncursesw PKG_CONFIG=true CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" NCURSES_CFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	NCURSES_LIBS="-L$(HOST_NCURSES)/lib -lncursesw"
ncdu_BINS      := bin/ncdu
ncdu_STACK     := 65536
ncdu_LIBS      := -lncursesw

ncdu_CHECK_DEPS := grep sed
