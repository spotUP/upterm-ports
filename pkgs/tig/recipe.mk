# tig (vtcon tui-port-candidates #3): the text-mode interface for git, C and ncursesw.
# Runs git through pipes at run time (the git package). Built without readline and
# pcre (tig's own prompt, POSIX regex); fork() is gone: the patch uses vfork.
tig_VERSION   := 2.6.0
tig_URL       := https://github.com/jonas/tig/releases/download/tig-$(tig_VERSION)/tig-$(tig_VERSION).tar.gz
tig_ARCHIVE   := $(DL)/tig-$(tig_VERSION).tar.gz
tig_SHA256    := 99d4a0fdd3d93547ebacfe511195cb92e4f75b91644c06293c067f401addeb3e
tig_LICENSE   := GPL-2.0-or-later
tig_LICENSE_FILES := COPYING
tig_DEPS      := ixcompat ncurses iconv
tig_BINS      := bin/tig
tig_STACK     := 262144
# started by ptyrun (vfork+exec), which ignores the $STACK: cookie (see nnn): define __stack too
tig_STACK_VAR := 1
tig_CONFIGURE := --without-readline
# iconv installs only its program (see pkgs/iconv): tig links the static library from its build dir
tig_ICONV     := $(OBJ)/iconv
tig_ENV       := CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw -I$(tig_ICONV)/include" LIBS="-lncursesw $(tig_ICONV)/lib/.libs/libiconv.a $(SYSLIB)/libixcompat.a" PKG_CONFIG=true NCURSES_CFLAGS="-I$(SYSINC)/ncursesw" NCURSES_LIBS="-lncursesw"
tig_HOST_DEPS := ncurses
tig_HOST_CONFIGURE := --without-readline ac_cv_lib_pcre2_posix_regexec=no ac_cv_lib_pcreposix_regexec=no ac_cv_header_pcre2posix_h=no ac_cv_header_pcreposix_h=no \
	LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw" PKG_CONFIG=true CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	NCURSES_CFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" NCURSES_LIBS="-L$(HOST_NCURSES)/lib -lncursesw"
tig_CHECK_DEPS := git
# tig builds in its source tree (its Makefile includes config.make from there)
tig_CONFIGURE_CMD = cp -R $(tig_SRC)/. $(tig_OBJ)/ && cd $(tig_OBJ) && $(call M68K_ENV,tig) $(tig_ENV) ./configure \
	--build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $(tig_CONFIGURE)
tig_HOST_CONFIGURE_CMD = cp -R $(tig_SRC)/. $(tig_HOBJ)/ && cd $(tig_HOBJ) && ./configure --prefix=$(tig_HOBJ)/inst $(tig_HOST_CONFIGURE)
# the copied source tree is a git repository (patches): without DIST_VERSION tig names itself 2.6.0-g<hash>-dirty
tig_BUILD_CMD = $(MAKE) -C $(tig_OBJ) -j$(JOBS) DIST_VERSION=$(tig_VERSION)
tig_INSTALL_CMD = $(MAKE) -C $(tig_OBJ) install DESTDIR=$(SYSROOT) DIST_VERSION=$(tig_VERSION)
tig_HOST_BUILD_CMD = $(MAKE) -C $(tig_HOBJ) -j$(JOBS) install DIST_VERSION=$(tig_VERSION)
