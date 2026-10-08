# mandoc (vtcon plan 1.9): man(1) and the formatter. Its configure runs test
# programs, so every answer is in configure.local (measured on the rig).
# The pager is started with posix_spawnp (patch 0001); man and mandoc are
# the same program, chosen by its name.
mandoc_VERSION   := 1.14.6
mandoc_URL       := https://mandoc.bsd.lv/snapshots/mandoc-$(mandoc_VERSION).tar.gz
mandoc_SHA256    := 8bf0d570f01e70a6e124884088870cbed7537f36328d512909eb10cd53179d9c
mandoc_LICENSE   := ISC (LICENSE)
mandoc_DEPS      := ixcompat zlib
mandoc_BINS      := bin/mandoc bin/man
mandoc_STACK     := 262144
mandoc_CONFIGURE_CMD = rsync -a --exclude .git $(mandoc_SRC)/ $(mandoc_OBJ)/ && \
	cp $(ROOT)/pkgs/mandoc/configure.local $(mandoc_OBJ)/ && \
	printf '%s\n' 'CC="$(ROOT)/tools/m68k-cc"' 'CFLAGS="$(CPU) -O2 -I$(SYSINC)"' \
	  'LDFLAGS="-L$(SYSLIB)"' 'LDADD="$(OBJ)/mandoc.stack.o $(SYSLIB)/libixcompat.a"' \
	  'AR="$(CROSS)ar"' \
	  >> $(mandoc_OBJ)/configure.local && \
	cd $(mandoc_OBJ) && ./configure
mandoc_BUILD_CMD = $(MAKE) -C $(mandoc_OBJ) mandoc
mandoc_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 \
	$(SYSROOT)$(PREFIX)/share/man/man7 && \
	install -m 755 $(mandoc_OBJ)/mandoc $(SYSROOT)$(PREFIX)/bin/mandoc && \
	install -m 755 $(mandoc_OBJ)/mandoc $(SYSROOT)$(PREFIX)/bin/man && \
	install -m 644 $(mandoc_SRC)/man.1 $(mandoc_SRC)/mandoc.1 $(SYSROOT)$(PREFIX)/share/man/man1/ && \
	install -m 644 $(mandoc_SRC)/mdoc.7 $(mandoc_SRC)/man.7 $(mandoc_SRC)/roff.7 $(SYSROOT)$(PREFIX)/share/man/man7/
mandoc_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(mandoc_SRC)/ $(mandoc_HOBJ)/ && \
	cd $(mandoc_HOBJ) && ./configure
mandoc_HOST_BUILD_CMD = $(MAKE) -C $(mandoc_HOBJ) mandoc && mkdir -p $(mandoc_HOBJ)/inst/bin && \
	cp $(mandoc_HOBJ)/mandoc $(mandoc_HOBJ)/inst/bin/mandoc && cp $(mandoc_HOBJ)/mandoc $(mandoc_HOBJ)/inst/bin/man
# the terminal case pages through less (PAGER): stage it beside man
mandoc_CHECK_DEPS := less
