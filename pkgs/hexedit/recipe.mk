# hexedit 1.6 (pixel/hexedit): the text-mode hex editor, C and ncursesw.
# GitHub publishes only the tag archive (no pre-built configure), so the configure
# step runs autoconf + autoheader on a copy of the tree (autogen.sh's two commands).
# The configure script looks for -lcurses / -lncurses: a directory of symlinks to
# libncursesw.a answers it. Colours (--color) are on: ncursesw has use_default_colors.
hexedit_VERSION   := 1.6
hexedit_URL       := https://github.com/pixel/hexedit/archive/refs/tags/$(hexedit_VERSION).tar.gz
hexedit_ARCHIVE   := $(DL)/hexedit-$(hexedit_VERSION).tar.gz
hexedit_SHA256    := 598906131934f88003a6a937fab10542686ce5f661134bc336053e978c4baae3
hexedit_LICENSE   := GPL-2.0-or-later
hexedit_LICENSE_FILES := COPYING
hexedit_DEPS      := ixcompat ncurses
hexedit_BINS      := bin/hexedit
hexedit_STACK     := 262144
# started by ptyrun (vfork+exec), which ignores the $STACK: cookie (see nnn): define __stack too
hexedit_STACK_VAR := 1
hexedit_ENV       = CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" LIBS="-L$(hexedit_OBJ)/lib -lncursesw $(SYSLIB)/libixcompat.a"
hexedit_HOST_DEPS := ncurses
hexedit_CONFIGURE_CMD = cp -R $(hexedit_SRC)/. $(hexedit_OBJ)/ && cd $(hexedit_OBJ) && autoconf && autoheader && \
	mkdir -p lib && cp $(SYSLIB)/libncursesw.a lib/libncurses.a && \
	$(call M68K_ENV,hexedit) $(hexedit_ENV) ./configure --build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX)
hexedit_HOST_CONFIGURE_CMD = cp -R $(hexedit_SRC)/. $(hexedit_HOBJ)/ && cd $(hexedit_HOBJ) && autoconf && autoheader && \
	mkdir -p lib && cp $(HOST_NCURSES)/lib/libncursesw.a lib/libncurses.a && \
	CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" LIBS="-L$(hexedit_HOBJ)/lib -L$(HOST_NCURSES)/lib -lncursesw" \
	./configure --prefix=$(hexedit_HOBJ)/inst
