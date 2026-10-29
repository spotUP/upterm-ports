# lynx 2.9.3 (TUI-PORTS 3): the text web browser, against ncursesw, with https:// through
# AmiSSL 5.27 (the same way as curl, see pkgs/curl/recipe.mk and mk/amissl.mk). AmiSSL's
# SSL_set_fd needs a bsdsocket.library socket, which an ixemul (ixnet) fd is not, so lynx's
# sockets are bsdsocket-direct: patch 0002 (AMIGA_BSDSOCKET, set below) routes NETCLOSE/
# NETWRITE/SOCKET_READ/IOCTL/select through the NDK stubs (WaitSelect, never libixcompat
# poll()) and registers errno with bsdsocket.library (SBTC_ERRNOPTR) at start. The rest of
# lynx stays ixemul libc, so it needs a running TCP/IP stack (Roadshow, AmiTCP) and AmiSSL.
# lynx's configure only knows pkg-config/libssl, so it runs --without-ssl and the SSL switches
# (USE_SSL, USE_OPENSSL_INCL) come in on CPPFLAGS. http, gopher, file: and local files work as before.
# External helpers (mailers,
# editors, pagers) go through ixemul's system()/popen() to vsh; lynx's own
# No fork: built with --disable-dired (the only fork user in this config); check_bin verifies.
lynx_VERSION   := 2.9.3
lynx_SUMMARY   := lynx 2.9.3 text web browser (https via AmiSSL) in UP-Term:bin
# The invisible-island.net tarball has answered 403 since 2026-10-29; the author's own GitHub tag
# (ThomasDickey/lynx-snapshots v2-9-3) unpacks to a tree identical to Debian's lynx_2.9.3.orig.tar.bz2
# (diff -r, no differences). The default archive name would be v2-9-3.tar.gz, so name it.
lynx_URL       := https://github.com/ThomasDickey/lynx-snapshots/archive/refs/tags/v2-9-3.tar.gz
lynx_ARCHIVE   := $(DL)/lynx-$(lynx_VERSION).tar.gz
lynx_SHA256    := 914e1dfb7dd53c876a0549f7128f85e558e18a05b7e675a402d745507d05e964
lynx_LICENSE   := GPL-2.0-only
lynx_LICENSE_FILES := COPYING COPYHEADER
lynx_DEPS      := ixcompat ncurses
lynx_CONFIGURE := --with-system-type=amigaos --with-screen=ncursesw --without-ssl --without-gnutls --without-nss \
	--disable-nls --disable-ipv6 --disable-vertrace --disable-gzip-help --without-zlib --without-bzlib \
	--disable-idna --disable-finger --disable-nested-tables --disable-dired
# configure finds ncursesw6-config on PATH (MacPorts /opt/local on this Mac: host libs, Darwin
# linker flags); the sysroot's own script gives the m68k flags
lynx_CONFIGURE_CMD = $(call AMISSL_OVERLAY,lynx) && cd $(lynx_OBJ) && $(call M68K_ENV,lynx) \
	NCURSES_CONFIG=$(SYSROOT)$(PREFIX)/bin/ncursesw6-config CFLAGS="$(CPU) -O2" \
	CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw -DHAVE_INTTYPES_H" \
	LDFLAGS="-L$(SYSLIB) $(AMISSL_LDFLAGS) -Wl,$(OBJ)/lynx.stack.o" $(lynx_SRC)/configure \
	--build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $(lynx_CONFIGURE)
# The forced mk/amiga-net.h and the netinc overlay stay out of configure (they declare mktime,
# gettimeofday ... and break its link probes); they are given to make only.
lynx_BUILD_CMD = $(MAKE) -C $(lynx_OBJ) -j$(JOBS) \
	CPPFLAGS="$(call AMISSL_CFLAGS,lynx) -I$(SYSINC) -I$(SYSINC)/ncursesw -DHAVE_INTTYPES_H -DUSE_SSL -DUSE_OPENSSL_INCL -DAMIGA_BSDSOCKET $(call AMISSL_CPPFLAGS,lynx)"
# (mk/config.site answers no to inttypes.h for gnulib; ixemul has one with intptr_t, PRIx*, which HTUtils needs)
lynx_HOST_DEPS := ncurses
lynx_HOST_CONFIGURE := --with-screen=ncursesw --without-ssl --disable-nls --without-zlib --without-bzlib --disable-idna \
	--disable-dired \
	NCURSES_CONFIG=$(HOST_NCURSES)/bin/ncursesw6-config \
	CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include -DNCURSES_WIDECHAR" \
	LIBS="-L$(HOST_NCURSES)/lib -lncursesw" am_cv_func_iconv=no
lynx_BINS      := bin/lynx
# the binary reads /UP-Term/etc/lynx.cfg and /UP-Term/etc/lynx.lss (strings on bin/lynx: LYNX_CFG_FILE,
# LYNX_LSS_FILE); without them it starts with no config and no colour styles
lynx_DATA      := etc/lynx.cfg etc/lynx.lss
lynx_STACK     := 262144
# started by vfork+exec (vsh, ptyrun), which ignore the $STACK: cookie: define __stack too
lynx_STACK_VAR := 1
lynx_LIBS      := -lncursesw -lamisslstubs -lamisslauto
lynx_CHECK_DEPS := grep sed
