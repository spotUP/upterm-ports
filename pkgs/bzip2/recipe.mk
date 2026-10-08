# bzip2 (vtcon plan 2.2): the program and libbz2.a for libarchive. A plain
# makefile building in its source directory, so a copy is built. bunzip2 and
# bzcat are copies of bzip2, which picks its mode from its name.
bzip2_VERSION   := 1.0.8
bzip2_URL       := https://sourceware.org/pub/bzip2/bzip2-$(bzip2_VERSION).tar.gz
bzip2_SHA256    := ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269
bzip2_LICENSE   := bzip2 (BSD-like, LICENSE)
bzip2_LICENSE_FILES := LICENSE
bzip2_DEPS      := ixcompat
bzip2_BINS      := bin/bzip2 bin/bunzip2 bin/bzcat
bzip2_STACK     := 65536
bzip2_CONFIGURE_CMD = rsync -a --exclude .git $(bzip2_SRC)/ $(bzip2_OBJ)/
bzip2_BUILD_CMD = $(MAKE) -C $(bzip2_OBJ) libbz2.a bzip2 CC="$(ROOT)/tools/m68k-cc $(CPU)" \
	AR=$(CROSS)ar RANLIB=$(CROSS)ranlib CFLAGS="-O2 -D_FILE_OFFSET_BITS=32 -I$(SYSINC)" \
	LDFLAGS="$(OBJ)/bzip2.stack.o $(SYSLIB)/libixcompat.a"
bzip2_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSINC) $(SYSLIB) $(SYSROOT)$(PREFIX)/share/man/man1 && \
	for b in bzip2 bunzip2 bzcat; do install -m 755 $(bzip2_OBJ)/bzip2 $(SYSROOT)$(PREFIX)/bin/$$b; done && \
	install -m 644 $(bzip2_OBJ)/libbz2.a $(SYSLIB)/ && install -m 644 $(bzip2_OBJ)/bzlib.h $(SYSINC)/ && \
	install -m 644 $(bzip2_OBJ)/bzip2.1 $(SYSROOT)$(PREFIX)/share/man/man1/
bzip2_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(bzip2_SRC)/ $(bzip2_HOBJ)/
bzip2_HOST_BUILD_CMD = $(MAKE) -C $(bzip2_HOBJ) bzip2 && mkdir -p $(bzip2_HOBJ)/inst/bin && \
	for b in bzip2 bunzip2 bzcat; do cp $(bzip2_HOBJ)/bzip2 $(bzip2_HOBJ)/inst/bin/$$b; done
bzip2_CHECK_DEPS := sed
