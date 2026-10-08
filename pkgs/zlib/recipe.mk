# zlib (vtcon plan 2.1, the library; gzip itself is its own item): a static
# libz.a in the sysroot. mandoc reads gzipped pages through it; libarchive,
# curl and others will link it too. zlib's configure is its own (CHOST, not
# autoconf) and builds in the source directory, so a copy is built.
zlib_VERSION   := 1.3.2
zlib_URL       := https://zlib.net/zlib-$(zlib_VERSION).tar.xz
zlib_SHA256    := d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3
zlib_LICENSE   := Zlib
zlib_DEPS      := ixcompat
zlib_BINS      :=
zlib_CONFIGURE_CMD = rsync -a --exclude .git $(zlib_SRC)/ $(zlib_OBJ)/ && cd $(zlib_OBJ) && \
	CHOST=m68k-amigaos CC="$(ROOT)/tools/m68k-cc" CFLAGS="$(CPU) -O2 -I$(SYSINC)" \
	AR=$(CROSS)ar RANLIB=$(CROSS)ranlib ./configure --static --prefix=$(PREFIX)
zlib_BUILD_CMD = $(MAKE) -C $(zlib_OBJ) libz.a
zlib_INSTALL_CMD = $(MAKE) -C $(zlib_OBJ) install-libs install-headers DESTDIR=$(SYSROOT) \
	|| $(MAKE) -C $(zlib_OBJ) install DESTDIR=$(SYSROOT)
zlib_LICENSE_FILES := LICENSE
