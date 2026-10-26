# lynx 2.9.3 (TUI-PORTS 3): the text web browser, against ncursesw. No TLS: no
# libtls/openssl/amissl is in the sysroot (nc ships a tls stub), so https:// URLs are
# refused; http, gopher, ftp-less file: and local files work. External helpers (mailers,
# editors, pagers) go through ixemul's system()/popen() to vsh; lynx's own
# No fork: built with --disable-dired (the only fork user in this config); check_bin verifies.
lynx_VERSION   := 2.9.3
lynx_SUMMARY   := lynx 2.9.3 text web browser (no TLS) in UP-Term:bin
lynx_URL       := https://invisible-island.net/archives/lynx/tarballs/lynx$(lynx_VERSION).tar.gz
lynx_SHA256    := 6e99e46980974a6d89eceefbb26ca8c7aa7702b78ecb5bad383b859af225d052
lynx_LICENSE   := GPL-2.0-only
lynx_LICENSE_FILES := COPYING COPYHEADER
lynx_DEPS      := ixcompat ncurses
lynx_CONFIGURE := --with-system-type=amigaos --with-screen=ncursesw --without-ssl --without-gnutls --without-nss \
	--disable-nls --disable-ipv6 --disable-vertrace --disable-gzip-help --without-zlib --without-bzlib \
	--disable-idna --disable-finger --disable-nested-tables --disable-dired
# configure finds ncursesw6-config on PATH (MacPorts /opt/local on this Mac: host libs, Darwin
# linker flags); the sysroot's own script gives the m68k flags
lynx_ENV       := NCURSES_CONFIG=$(SYSROOT)$(PREFIX)/bin/ncursesw6-config CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw -DHAVE_INTTYPES_H"
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
lynx_LIBS      := -lncursesw
lynx_CHECK_DEPS := grep sed
