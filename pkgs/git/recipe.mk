# git 2.56.0 (vtcon plan FP4.4 part 4a): the git program, local commands only.
# No configure: git's own Makefile, driven by variables. ixemul has vfork but no
# fork, no threads, no sockets worth a daemon, so the build is NO_PTHREADS and
# patches/0001 turns start_command into vfork + exec (the child only execs) and
# makes the raw fork() callers (start_async, daemonize, the transport helper loop)
# fail with "git: ... not supported on AmigaOS" instead of linking _fork.
# Network (curl, ssh transport demux) is a later step.
# uname probes: config.mak.uname would take macOS settings on the Mac, so the
# system is named AmigaOS; gcc predefines AMIGA, which git does not look at.
git_VERSION   := 2.56.0
git_URL       := https://www.kernel.org/pub/software/scm/git/git-$(git_VERSION).tar.xz
git_ARCHIVE   := $(DL)/git-$(git_VERSION).tar.xz
git_SHA256    := 26c56c296b38c0695b26fa95f475f1d01704d2d38e73465ca30b0b2f5dc789d3
git_LICENSE   := GPL-2.0-only
git_LICENSE_FILES := COPYING LGPL-2.1
git_DEPS      := ixcompat zlib
git_FLAGS     := NO_PTHREADS=1 NO_OPENSSL=1 NO_CURL=1 NO_EXPAT=1 NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 NO_PYTHON=1 \
	NO_RUST=1 NO_ICONV=1 NO_NSEC=1 NO_MEMMEM=1 NO_STRCASESTR=1 NO_MKDTEMP=1 NO_PREAD=1 NO_REGEX=NeedsStartEnd NO_INSTALL_HARDLINKS=1 SKIP_DASHED_BUILT_INS=1 RUNTIME_PREFIX=1 \
	GIT_VERSION=$(git_VERSION)
git_CONFIGURE_CMD = (cd $(git_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(git_OBJ) && chmod -R u+w $(git_OBJ)
git_BUILD_CMD = $(MAKE) -C $(git_OBJ) -j$(JOBS) $(git_FLAGS) uname_S=AmigaOS uname_M=m68k uname_O=AmigaOS uname_R=3.2 uname_P=unknown \
	CC="$(ROOT)/tools/m68k-cc" AR=$(CROSS)ar RANLIB=$(CROSS)ranlib \
	CFLAGS="$(CPU) -O2 -I$(SYSINC) -DUSE_VFORK -DNO_STATVFS" LDFLAGS="-L$(SYSLIB)$(if $(git_STACK), -Wl$(comma)$(OBJ)/git.stack.o)" \
	EXTLIBS="$(SYSLIB)/libz.a $(SYSLIB)/libixcompat.a" ZLIB_PATH=$(SYSROOT)$(PREFIX) prefix=$(PREFIX) git
git_INSTALL_CMD = mkdir -p $(SYSROOT)$(PREFIX)/bin && cp $(git_OBJ)/git $(SYSROOT)$(PREFIX)/bin/git
git_HOST_CONFIGURE_CMD = (cd $(git_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(git_HOBJ) && chmod -R u+w $(git_HOBJ)
git_HOST_BUILD_CMD = $(MAKE) -C $(git_HOBJ) -j$(JOBS) NO_OPENSSL=1 NO_CURL=1 NO_EXPAT=1 NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 NO_PYTHON=1 \
	NO_RUST=1 GIT_VERSION=$(git_VERSION) prefix=$(git_HOBJ)/inst install
git_BINS      := bin/git
git_STACK     := 262144
git_STACK_VAR := 1
