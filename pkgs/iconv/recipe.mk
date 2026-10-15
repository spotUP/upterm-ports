# GNU libiconv 1.17: the iconv program (vtcon plan 4.9). The library is built
# static into the program (no NLS: src/iconv_no_i18n is the program); only the program and its page are installed, so
# libiconv's iconv.h and library never shadow what other packages build against.
iconv_VERSION   := 1.17
iconv_URL       := https://ftp.gnu.org/gnu/libiconv/libiconv-$(iconv_VERSION).tar.gz
iconv_SHA256    := 8f74213b56238c85a50a5329f77e06198771e70dd9a739779f4c02f65d971313
iconv_LICENSE   := GPL-3.0-or-later
iconv_LICENSE_FILES := COPYING
iconv_DEPS      := ixcompat
iconv_CONFIGURE := --disable-nls --enable-static --disable-shared --disable-rpath
iconv_HOST_CONFIGURE := --disable-nls --disable-rpath
iconv_BINS      := bin/iconv
iconv_STACK     := 65536
iconv_CHECK_DEPS := sed
iconv_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(iconv_OBJ)/src/iconv_no_i18n $(SYSROOT)$(PREFIX)/bin/iconv && \
	install -m 644 $(iconv_SRC)/man/iconv.1 $(SYSROOT)$(PREFIX)/share/man/man1/iconv.1
