# mutt 2.2.16 (vtcon tui-port-candidates): the text-mode mail client, C and ncursesw.
# Local mailboxes only: built without IMAP, POP, SMTP, SSL/GnuTLS, SASL, GSSAPI, NLS,
# iconv, hcache, Berkeley DB and the dotlock helper. Mail is sent by an external
# sendmail-style program. fork() is gone: the patch uses vfork.
mutt_VERSION   := 2.2.16
mutt_URL       := http://ftp.mutt.org/pub/mutt/mutt-$(mutt_VERSION).tar.gz
mutt_ARCHIVE   := $(DL)/mutt-$(mutt_VERSION).tar.gz
mutt_SHA256    := 1d3109a743ad8b25eef97109b2bdb465db7837d0a8d211cd388be1b6faac3f32
mutt_LICENSE   := GPL-2.0-or-later
mutt_LICENSE_FILES := COPYING
mutt_DEPS      := ixcompat ncurses
mutt_BINS      := bin/mutt
mutt_STACK     := 262144
# started by ptyrun (vfork+exec), which ignores the $STACK: cookie (see nnn): define __stack too
mutt_STACK_VAR := 1
mutt_CONFIGURE := ac_cv_func_getaddrinfo=no --with-curses=$(SYSROOT)$(PREFIX) --disable-nls --disable-iconv --disable-hcache --disable-doc \
	--disable-dotlock --disable-fcntl --with-mailpath=/T --without-ssl --without-gnutls --without-sasl --without-gss
mutt_ENV       := CPPFLAGS="-DHAVE_INTTYPES_H -I$(SYSINC) -I$(SYSINC)/ncursesw" LIBS="-lncursesw $(SYSLIB)/libixcompat.a"
mutt_HOST_DEPS := ncurses
mutt_HOST_CONFIGURE := --with-curses=$(HOST_NCURSES) --disable-nls --disable-iconv --disable-hcache --disable-doc \
	--disable-dotlock --disable-fcntl --with-mailpath=/T --without-ssl --without-gnutls --without-sasl --without-gss \
	CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw"
