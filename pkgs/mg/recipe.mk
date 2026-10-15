# mg 4.4 (vtcon plan 4.2): the portable OpenBSD mg (troglobit/mg), a small
# Emacs-like editor, against ncursesw (0.8). Replaces emacs-nox, which is not
# ported.
mg_VERSION   := 4.4
mg_URL       := https://github.com/troglobit/mg/releases/download/v$(mg_VERSION)/mg-$(mg_VERSION).tar.gz
mg_SHA256    := 5955f48138bd5fc3ac53945d610f4089446afc5eea99bfb5f0a01f079426907e
mg_LICENSE   := public domain / BSD / ISC
mg_LICENSE_FILES := LICENSE
mg_DEPS      := ixcompat ncurses
mg_CONFIGURE := --disable-nls
mg_ENV       := CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" CURSES_CFLAGS="-I$(SYSINC)/ncursesw" CURSES_LIBS=-lncursesw
mg_LIBS      := -lncursesw
mg_HOST_DEPS := ncurses
mg_HOST_CONFIGURE := CPPFLAGS="-I$(HOST_NCURSES)/include -I$(HOST_NCURSES)/include/ncursesw" LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw"
mg_BINS      := bin/mg
mg_STACK     := 262144
mg_STACK_VAR := 1
