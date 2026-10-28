# libgsasl (GNU SASL 2.2.4, the library only): a static libgsasl.a in the sysroot for mutt's
# SMTP/IMAP/POP authentication (mutt --with-gsasl). Mechanisms: PLAIN, LOGIN, CRAM-MD5, SCRAM-SHA-1,
# SCRAM-SHA-256 (plus the always-built ANONYMOUS, EXTERNAL). No GSSAPI/Kerberos, NTLM, DIGEST-MD5,
# libgcrypt, libidn or readline: the crypto is gnulib's own. The gsasl command line tool and the
# docs are not built; only gl/ and lib/ are.
libgsasl_VERSION   := 2.2.4
libgsasl_SUMMARY   := libgsasl 2.2.4 SASL library (PLAIN, LOGIN, CRAM-MD5, SCRAM) static, for mutt
libgsasl_URL       := https://ftp.gnu.org/gnu/gsasl/gsasl-$(libgsasl_VERSION).tar.gz
libgsasl_ARCHIVE   := $(DL)/gsasl-$(libgsasl_VERSION).tar.gz
libgsasl_SHA256    := d32be15efd3a04cb19b232f721bdca02cc6ad7ab415df7d79fb2dd2c0da3e0be
libgsasl_LICENSE   := LGPL-2.1-or-later
libgsasl_LICENSE_FILES := COPYING.LESSER
libgsasl_DEPS      := ixcompat
libgsasl_BINS      :=
libgsasl_ENV       := CPPFLAGS="-I$(SYSINC)" LDFLAGS="-L$(SYSLIB)" LIBS="$(SYSLIB)/libixcompat.a"
libgsasl_CONFIGURE := --disable-shared --enable-static --disable-nls --disable-gssapi --disable-ntlm \
	--disable-digest-md5 --disable-gs2 --disable-saml20 --disable-openid20 --disable-securid \
	--enable-scram-sha1 --enable-scram-sha256 --without-libgcrypt --without-libidn --without-libreadline \
	--disable-doc --disable-gtk-doc --disable-server
libgsasl_BUILD_CMD = $(MAKE) -C $(libgsasl_OBJ)/gl -j$(JOBS) && $(MAKE) -C $(libgsasl_OBJ)/lib -j$(JOBS)
libgsasl_INSTALL_CMD = $(MAKE) -C $(libgsasl_OBJ)/lib install DESTDIR=$(SYSROOT)
libgsasl_HOST_CONFIGURE_CMD = mkdir -p $(libgsasl_HOBJ)
libgsasl_HOST_BUILD_CMD = mkdir -p $(libgsasl_HOBJ)/inst/bin
