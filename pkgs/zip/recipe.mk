# Info-ZIP Zip 3.0 (vtcon plan 2.5): its unix makefile and configure, built
# in a copy of the source. UnZip stays the native Aminet one (README);
# bsdunzip reads zip archives too.
zip_VERSION   := 3.0
zip_URL       := https://downloads.sourceforge.net/project/infozip/Zip%203.x%20%28latest%29/3.0/zip30.tar.gz
zip_ARCHIVE   := $(DL)/zip30.tar.gz
zip_SHA256    := f0e8bb1f9b7eb0b01285495a2699df3a4b766784c1765a8f1aeedf63c0806369
zip_LICENSE   := Info-ZIP (BSD-like, LICENSE)
zip_LICENSE_FILES := LICENSE
zip_DEPS      := ixcompat
zip_BINS      := bin/zip
zip_STACK     := 65536
# the unix port on ixemul, not Zip's native Amiga one, which gcc's predefined
# AMIGA macro selects (amiga/z-stat.h wants SAS/C's dos.h)
ZIP_UNIX := -UAMIGA -Uamiga -U__AMIGA__
zip_CONFIGURE_CMD = rsync -a --exclude .git $(zip_SRC)/ $(zip_OBJ)/
# `generic` runs unix/configure into ./flags and then make with them, so its
# empty LFLAGS2 would win over ours: write flags, put the cookie and
# libixcompat into its LFLAGS2 (after the objects), then build
zip_BUILD_CMD = cd $(zip_OBJ) && $(MAKE) -f unix/Makefile flags IZ_BZIP2=no \
	CC="$(ROOT)/tools/m68k-cc $(CPU) $(ZIP_UNIX) -I$(SYSINC)" CPP="$(ROOT)/tools/m68k-cc -E $(ZIP_UNIX) -I$(SYSINC)" && \
	sed -i.orig 's|LFLAGS2=""|LFLAGS2="-Wl,$(OBJ)/zip.stack.o $(SYSLIB)/libixcompat.a"|' flags && \
	eval $(MAKE) -f unix/Makefile zips `cat flags`
zip_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(zip_OBJ)/zip $(SYSROOT)$(PREFIX)/bin/zip && \
	install -m 644 $(zip_SRC)/man/zip.1 $(SYSROOT)$(PREFIX)/share/man/man1/zip.1
# the Mac side: Zip 3.0's configure fails under clang (it then declares its
# own memset), so the expected outputs come from macOS's own Zip 3.0
zip_HOST_CONFIGURE_CMD = true
zip_HOST_BUILD_CMD = mkdir -p $(zip_HOBJ)/inst/bin && ln -sf /usr/bin/zip $(zip_HOBJ)/inst/bin/zip
zip_CHECK_DEPS := sed libarchive
