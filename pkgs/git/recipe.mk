# git 2.56.0 (vtcon plan FP4.4 part 4a): the git program, local commands only.
# No configure: git's own Makefile, driven by variables. ixemul has vfork but no
# fork, no threads, no sockets worth a daemon, so the build is NO_PTHREADS and
# patches/0001 turns start_command into vfork + exec (the child only execs) and
# makes the raw fork() callers (start_async, daemonize, the transport helper loop)
# fail with "git: ... not supported on AmigaOS" instead of linking _fork.
# https: git-remote-http links the sysroot libcurl (pkgs/curl, AmiSSL, bsdsocket-direct) plus
# -lamisslstubs -lamisslauto; git-remote-https is a two-line sh script that runs it. NO_EXPAT stays,
# so only http push (WebDAV) is missing; clone, fetch and ls-remote over https work.
# The ssh transport demux is a later step.
# uname probes: config.mak.uname would take macOS settings on the Mac, so the
# system is named AmigaOS; gcc predefines AMIGA, which git does not look at.
git_VERSION   := 2.56.0
git_URL       := https://www.kernel.org/pub/software/scm/git/git-$(git_VERSION).tar.xz
git_ARCHIVE   := $(DL)/git-$(git_VERSION).tar.xz
git_SHA256    := 26c56c296b38c0695b26fa95f475f1d01704d2d38e73465ca30b0b2f5dc789d3
git_LICENSE   := GPL-2.0-only
# The feed (vtcon tools/pkg_rows.py): the package id and the Packages Description.
git_FEED_ID   := up-git
git_SUMMARY   := git 2.56 version control, local commands only, in UP-Term:bin and UP-Term:share/git-core
git_SUMMARY   := git 2.56.0 in UP-Term:bin and UP-Term:share/git-core
git_FEED_MIN_BASE := 1.0
git_LICENSE_FILES := COPYING LGPL-2.1
git_DEPS      := ixcompat zlib curl
git_FLAGS     := NO_PTHREADS=1 NO_OPENSSL=1 NO_EXPAT=1 NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 NO_PYTHON=1 \
	NO_RUST=1 NO_ICONV=1 NO_NSEC=1 NO_MEMMEM=1 NO_STRCASESTR=1 NO_MKDTEMP=1 NO_PREAD=1 NO_REGEX=NeedsStartEnd NO_INSTALL_HARDLINKS=1 NO_TRUSTABLE_FILEMODE=1 SKIP_DASHED_BUILT_INS=1 \
	GIT_VERSION=$(git_VERSION)
git_CONFIGURE_CMD = (cd $(git_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(git_OBJ) && chmod -R u+w $(git_OBJ)
git_BUILD_CMD = $(MAKE) -C $(git_OBJ) -j$(JOBS) $(git_FLAGS) uname_S=AmigaOS uname_M=m68k uname_O=AmigaOS uname_R=3.2 uname_P=unknown \
	CC="$(ROOT)/tools/m68k-cc" AR=$(CROSS)ar RANLIB=$(CROSS)ranlib \
	CFLAGS="$(CPU) -O2 -I$(SYSINC) -DUSE_VFORK -DNO_STATVFS" LDFLAGS="-L$(SYSLIB) $(AMISSL_LDFLAGS)$(if $(git_STACK), -Wl$(comma)$(OBJ)/git.stack.o)" \
	EXTLIBS="$(SYSLIB)/libz.a $(SYSLIB)/libixcompat.a" ZLIB_PATH=$(SYSROOT)$(PREFIX) CURLDIR=$(SYSROOT)$(PREFIX) \
	CURL_LIBCURL="-L$(SYSLIB) -lcurl -lamisslstubs -lamisslauto $(SYSLIB)/libz.a" prefix=$(PREFIX) git git-remote-http
# SKIP_DASHED_BUILT_INS drops the dashed names of the built-ins, but upstream's Makefile
# still installs git-upload-pack, git-receive-pack and git-upload-archive in bin/ (the
# `ALL_COMMANDS_TO_INSTALL` else-branch): a clone/fetch/push over file:// or ssh runs
# `sh -c "git-upload-pack <dir>"` on the remote side, so they must be on PATH. The AmigaOS
# volume has no hard links (NO_INSTALL_HARDLINKS is set), and a full copy of git per name
# costs 3.7 MB each, so each name is a two-line #!/bin/sh script that runs `git <command>`
# (ixemul's __load_seg runs #! scripts through shell_path_alias). The templates are what
# `git init` copies into .git.
git_INSTALL_CMD = mkdir -p $(SYSROOT)$(PREFIX)/bin && cp $(git_OBJ)/git $(SYSROOT)$(PREFIX)/bin/git && cp $(git_OBJ)/git-remote-http $(SYSROOT)$(PREFIX)/bin/git-remote-http && \
	printf '\#!/bin/sh\nexec git-remote-http "$$@"\n' > $(SYSROOT)$(PREFIX)/bin/git-remote-https && chmod 755 $(SYSROOT)$(PREFIX)/bin/git-remote-https && \
	for h in $(git_HELPERS); do printf '\#!/bin/sh\nexec git %s "$$@"\n' $${h\#git-} > $(SYSROOT)$(PREFIX)/bin/$$h && \
	chmod 755 $(SYSROOT)$(PREFIX)/bin/$$h || exit 1; done && \
	$(MAKE) -C $(git_OBJ)/templates install DESTDIR=$(SYSROOT) prefix=$(PREFIX) NO_GETTEXT=1 SHELL_PATH=/bin/sh
git_HOST_CONFIGURE_CMD = (cd $(git_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(git_HOBJ) && chmod -R u+w $(git_HOBJ)
git_HOST_BUILD_CMD = $(MAKE) -C $(git_HOBJ) -j$(JOBS) NO_OPENSSL=1 NO_CURL=1 NO_EXPAT=1 NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 NO_PYTHON=1 \
	NO_RUST=1 GIT_VERSION=$(git_VERSION) prefix=$(git_HOBJ)/inst install
git_HELPERS   := git-upload-pack git-receive-pack git-upload-archive
git_CHECK_DEPS := coreutils
git_BINS      := bin/git bin/git-upload-pack bin/git-receive-pack bin/git-upload-archive bin/git-remote-http bin/git-remote-https
git_DATA      := share/git-core/templates
git_STACK     := 262144
git_STACK_VAR := 1
