# mutt 2.2.16 (vtcon tui-port-candidates): the text-mode mail client, C and ncursesw.
# Local mailboxes plus IMAP, POP and SMTP, with imaps/pops/smtps and STARTTLS through AmiSSL 5.27
# (the same way as curl and lynx, see mk/amissl.mk and pkgs/lynx/recipe.mk). AmiSSL's SSL_set_fd
# needs a bsdsocket.library socket, which an ixemul fd is not, so mutt's socket layer is
# bsdsocket-direct: patch 0003 (AMIGA_BSDSOCKET, set below) routes close/read/write/select
# through CloseSocket/recv/send/WaitSelect and registers errno with bsdsocket.library
# (SBTC_ERRNOPTR) at start. It needs a running TCP/IP stack (Roadshow, AmiTCP) and AmiSSL.
# SMTP/IMAP/POP login goes through GNU SASL (libgsasl, --with-gsasl; Cyrus SASL stays off).
# Built without GnuTLS, Cyrus SASL, GSSAPI, NLS, iconv, hcache, Berkeley DB and the dotlock helper.
# Mail is sent by an external sendmail-style program or SMTP. fork() is gone: the patch uses vfork.
mutt_VERSION   := 2.2.16
mutt_SUMMARY   := mutt 2.2.16 mail client (IMAP, POP, SMTP, TLS via AmiSSL) in UP-Term:bin
# ftp.mutt.org serves no valid https; the OSU OSL mirror holds the same file (sha256 below matches).
mutt_URL       := https://ftp.osuosl.org/pub/blfs/conglomeration/mutt/mutt-$(mutt_VERSION).tar.gz
mutt_ARCHIVE   := $(DL)/mutt-$(mutt_VERSION).tar.gz
mutt_SHA256    := 1d3109a743ad8b25eef97109b2bdb465db7837d0a8d211cd388be1b6faac3f32
mutt_LICENSE   := GPL-2.0-or-later
mutt_LICENSE_FILES := COPYRIGHT GPL
mutt_DEPS      := ixcompat ncurses libgsasl
mutt_BINS      := bin/mutt
mutt_STACK     := 262144
# started by ptyrun (vfork+exec), which ignores the $STACK: cookie (see nnn): define __stack too
mutt_STACK_VAR := 1
# configure's --with-ssl links -lssl/-lcrypto, which AmiSSL does not have: the cache answers stand in
# and the link line is replaced at make time (mutt_BUILD_CMD).
mutt_CONFIGURE := ac_cv_func_getaddrinfo=no --with-curses=$(SYSROOT)$(PREFIX) --disable-nls --disable-iconv --disable-hcache --disable-doc \
	--disable-dotlock --disable-fcntl --with-mailpath=/T --enable-imap --enable-pop --enable-smtp --with-ssl \
	--without-gnutls --without-sasl --with-gsasl=$(SYSROOT)$(PREFIX) --without-gss \
	ac_cv_lib_z_deflate=no ac_cv_lib_crypto_X509_STORE_CTX_new=yes ac_cv_lib_ssl_SSL_new=yes \
	ac_cv_have_decl_SSL_set_mode=yes ac_cv_have_decl_SSL_MODE_AUTO_RETRY=yes ac_cv_have_decl_X509_V_FLAG_PARTIAL_CHAIN=yes
mutt_CONFIGURE_CMD = $(call AMISSL_OVERLAY,mutt) && cd $(mutt_OBJ) && $(call M68K_ENV,mutt) \
	CPPFLAGS="-DHAVE_INTTYPES_H -I$(SYSINC) -I$(SYSINC)/ncursesw" LIBS="-lncursesw $(SYSLIB)/libixcompat.a" \
	LDFLAGS="-L$(SYSLIB) $(AMISSL_LDFLAGS) -Wl,$(OBJ)/mutt.stack.o" $(mutt_SRC)/configure \
	--build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $(mutt_CONFIGURE)
# The forced mk/amiga-net.h and the netinc overlay stay out of configure (they break its link probes);
# they are given to make only, with the AmiSSL libs in place of -lssl -lcrypto.
mutt_BUILD_CMD = $(MAKE) -C $(mutt_OBJ) -j$(JOBS) \
	CPPFLAGS="$(call AMISSL_CFLAGS,mutt) -DHAVE_INTTYPES_H -I$(SYSINC) -I$(SYSINC)/ncursesw -DAMIGA_BSDSOCKET $(call AMISSL_CPPFLAGS,mutt)" \
	MUTTLIBS="-lncursesw -lgsasl -lamisslstubs -lamisslauto"
mutt_HOST_DEPS := ncurses
mutt_HOST_CONFIGURE := --with-curses=$(HOST_NCURSES) --disable-nls --disable-iconv --disable-hcache --disable-doc \
	--disable-dotlock --disable-fcntl --with-mailpath=/T --without-ssl --without-gnutls --without-sasl --without-gss \
	CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw"
