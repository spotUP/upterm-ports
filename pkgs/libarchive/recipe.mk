# libarchive (vtcon plan 2.4): bsdtar as tar, bsdcpio as cpio, bsdunzip as
# unzip-alike (bsdunzip), linked statically with zlib, bzip2 and liblzma, so
# tar -z/-j/-J need no other process. BSD licence. Reads zip, 7z, lha/lzh,
# iso, ar, cab, rar too.
libarchive_VERSION   := 3.8.9
libarchive_URL       := https://github.com/libarchive/libarchive/releases/download/v$(libarchive_VERSION)/libarchive-$(libarchive_VERSION).tar.xz
libarchive_SHA256    := 888c934f9d95648ecb9163dc8e23ab80a476ecb81a8f1154704a227b5b676dde
libarchive_LICENSE   := BSD-2-Clause (COPYING)
libarchive_DEPS      := ixcompat zlib bzip2 xz
libarchive_CONFIGURE := --disable-shared --enable-static --enable-bsdtar=static \
	--enable-bsdcpio=static --enable-bsdunzip=static --enable-bsdcat=static \
	--disable-acl --disable-xattr --without-openssl --without-xml2 --without-expat \
	--without-lz4 --without-zstd --without-libb2 --without-mbedtls --without-nettle \
	--without-iconv --without-cng --disable-year2038 --with-zlib --with-bz2lib --with-lzma
libarchive_HOST_CONFIGURE := --disable-shared --without-openssl --without-xml2 --without-expat \
	--without-lz4 --without-zstd --without-libb2 --without-iconv --disable-acl --disable-xattr
libarchive_LIBS      := -llzma -lbz2 -lz
# bsdtar is tar and bsdcpio is cpio in the kit (plan 2.4); bsdunzip keeps its
# name beside the native UnZip
libarchive_BINS      := bin/tar bin/cpio bin/bsdunzip bin/bsdcat
libarchive_POST_INSTALL = cd $(SYSROOT)$(PREFIX)/bin && mv -f bsdtar tar && mv -f bsdcpio cpio && \
	cd ../share/man/man1 && mv -f bsdtar.1 tar.1 && mv -f bsdcpio.1 cpio.1
libarchive_STACK     := 131072
libarchive_HOST_BUILD_CMD = $(MAKE) -C $(libarchive_HOBJ) -j$(JOBS) install && \
	cd $(libarchive_HOBJ)/inst/bin && cp bsdtar tar && cp bsdcpio cpio
libarchive_CHECK_DEPS := sed
