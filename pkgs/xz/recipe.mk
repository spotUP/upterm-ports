# XZ Utils (vtcon plan 2.3; never 5.6.0/5.6.1): xz and liblzma for
# libarchive. unxz and xzcat are copies of xz, which picks its mode from its
# name. No threads (ixemul has no pthreads), no shell scripts (xzdiff...).
xz_VERSION   := 5.8.4
xz_URL       := https://github.com/tukaani-project/xz/releases/download/v$(xz_VERSION)/xz-$(xz_VERSION).tar.xz
xz_SHA256    := 4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b
xz_LICENSE   := 0BSD (liblzma, xz) and public domain parts (COPYING)
xz_LICENSE_FILES := COPYING COPYING.0BSD
xz_DEPS      := ixcompat
xz_CONFIGURE := --disable-threads --disable-nls --disable-shared --enable-static \
	--disable-scripts --disable-doc --disable-lzmadec --disable-lzmainfo \
	--disable-xzdec --disable-lzma-links --disable-year2038
xz_HOST_CONFIGURE := --disable-shared --disable-scripts --disable-doc --disable-nls
xz_BINS      := bin/xz bin/unxz bin/xzcat
xz_STACK     := 65536
# make install makes them hard links (the Mac's file system): files instead
xz_POST_INSTALL = cd $(SYSROOT)$(PREFIX)/bin && rm -f unxz xzcat && cp xz unxz && cp xz xzcat
xz_CHECK_DEPS := sed
