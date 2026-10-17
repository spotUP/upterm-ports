# Vim 9.2.1202 (vtcon plan 4.1): the editor, small feature set (no GUI, no X,
# no interpreters, no terminal/channel/netbeans), against ncursesw (0.8).
# The release tarball is GitHub's tag archive of vim/vim (upstream publishes
# no checksums); the sha256 below is of the archive fetched 2026-10-17.
# Vim builds in its source tree (src/), so configure and make run in a copy.
# The m68k-amigaos gcc predefines AMIGA, which selects vim's native Amiga port
# (os_amiga.c, arp.library); -UAMIGA keeps the Unix port that ixemul runs.
# -DUSE_SYSTEM (feature.h): external commands go through system() (libixcompat,
# posix_spawn) instead of vim's fork()/exec(); ixemul has no fork.
vim_VERSION   := 9.2.1202
vim_URL       := https://github.com/vim/vim/archive/refs/tags/v$(vim_VERSION).tar.gz
vim_ARCHIVE   := $(DL)/vim-$(vim_VERSION).tar.gz
vim_SHA256    := 9e97414b85bdcb2d28d5264c65dd730d86b9a75319b005c63da0bc130c715a2f
vim_LICENSE   := Vim
vim_LICENSE_FILES := LICENSE
vim_DEPS      := ixcompat ncurses
vim_FEATURES  := --with-features=small --disable-gui --without-x --disable-nls --disable-gpm \
	--disable-sysmouse --disable-netbeans --disable-channel --disable-terminal \
	--disable-canberra --disable-libsodium --disable-acl --disable-selinux \
	--disable-perlinterp --disable-pythoninterp --disable-python3interp \
	--disable-rubyinterp --disable-tclinterp --disable-luainterp --disable-mzschemeinterp \
	--disable-cscope --disable-smack --with-tlib=ncursesw
# configure's run tests, answered for ixemul (each is the generic Unix answer;
# nothing on the rig contradicts it): vim_cv_* are vim's AC_CACHE_VAL names
vim_ENV       := vim_cv_getcwd_broken=no vim_cv_memmove_handles_overlap=yes \
	vim_cv_stat_ignores_slash=no vim_cv_terminfo=yes vim_cv_tgetent=zero \
	vim_cv_toupper_broken=no vim_cv_tty_group=world vim_cv_tty_mode=0620 \
	vim_cv_bcopy_handles_overlap=yes vim_cv_memcpy_handles_overlap=no \
	vim_cv_uname_output=AmigaOS vim_cv_uname_r_output=3.2 vim_cv_uname_m_output=m68k
vim_CONFIGURE_CMD = (cd $(vim_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(vim_OBJ) && cd $(vim_OBJ)/src && $(call M68K_ENV,vim) $(vim_ENV) \
	./configure --build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $(vim_FEATURES) \
	CPPFLAGS="-UAMIGA -DUSE_SYSTEM -I$(SYSINC) -I$(SYSINC)/ncursesw"
vim_LIBS      := -lncursesw
vim_BUILD_CMD = $(MAKE) -C $(vim_OBJ)/src -j$(JOBS) vim
vim_INSTALL_CMD = $(MAKE) -C $(vim_OBJ)/src installvimbin installrtbase DESTDIR=$(SYSROOT) STRIP=true
vim_HOST_DEPS := ncurses
vim_HOST_CONFIGURE_CMD = (cd $(vim_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(vim_HOBJ) && cd $(vim_HOBJ)/src && ./configure --prefix=$(vim_HOBJ)/inst \
	$(vim_FEATURES) CPPFLAGS="-I$(HOST_NCURSES)/include -I$(HOST_NCURSES)/include/ncursesw" \
	LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw"
vim_HOST_BUILD_CMD = $(MAKE) -C $(vim_HOBJ)/src -j$(JOBS) install
vim_BINS      := bin/vim
# provisional, joe's value; started by ptyrun (vfork + exec), so __stack too
vim_STACK     := 262144
vim_STACK_VAR := 1
vim_DATA := share/vim
# the help files are 11 MB of the 27 MB runtime; :help is not shipped
vim_POST_INSTALL = rm -rf $(SYSROOT)$(PREFIX)/share/vim/vim92/doc
