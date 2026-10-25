# BitchX (GitHub mirror prime001/BitchX, pinned to commit 3070a76bee0f50f2e954dc3b3295b94ea60cd405 = master of 2026-10-25; no tagged release): the IRC client, C and ncurses.
# No SSL, no plugins, no IPv6, no GUI. Upstream's configure is shipped pre-built.
bitchx_VERSION   := 1.2.1
bitchx_COMMIT    := 3070a76bee0f50f2e954dc3b3295b94ea60cd405
bitchx_URL       := https://github.com/prime001/BitchX/archive/$(bitchx_COMMIT).tar.gz
bitchx_ARCHIVE   := $(DL)/bitchx-$(bitchx_COMMIT).tar.gz
bitchx_SHA256    := 36d8023222ac37d6d29fcf2ac9260c31c0bde09b9cba76010fa713d1e102053e
bitchx_LICENSE   := BSD-3-Clause
bitchx_LICENSE_FILES := COPYRIGHT
bitchx_DEPS      := ixcompat ncurses
bitchx_BINS      := bin/BitchX
# IRCLIB: the binary looks in /UP-Term/lib/bx (script/, help/, translation/, BitchX.help ...; strings on bin/BitchX
# show IRCLIB, the script path and the translation path), which is where make install puts it.
# The help topics install as .bz2 and BitchX would read them through a decompressor child (fork is gone): install them plain.
bitchx_DATA      := lib/bx
bitchx_INSTALL_CMD = $(MAKE) -C $(bitchx_OBJ) install DESTDIR=$(SYSROOT) && find $(SYSROOT)$(PREFIX)/lib/bx/help -name '*.bz2' -exec bzip2 -d -f {} +
bitchx_STACK     := 262144
bitchx_STACK_VAR := 1
bitchx_ENV       = CFLAGS="-O2 -fno-strict-aliasing -I$(SYSINC) -I$(SYSINC)/ncursesw" CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" LIBS="-L$(bitchx_OBJ)/lib -lncursesw $(SYSLIB)/libixcompat.a"
bitchx_CONFIGURE_CMD = cp -R $(bitchx_SRC)/. $(bitchx_OBJ)/ && cd $(bitchx_OBJ) && \
	mkdir -p lib && cp $(SYSLIB)/libncursesw.a lib/libncurses.a && \
	$(call M68K_ENV,bitchx) $(bitchx_ENV) ./configure --build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) --without-ssl --disable-ipv6

bitchx_HOST_DEPS := ncurses
bitchx_HOST_CONFIGURE_CMD = cp -R $(bitchx_SRC)/. $(bitchx_HOBJ)/ && cd $(bitchx_HOBJ) && \
	CFLAGS="-O2 -fno-strict-aliasing -std=gnu89 -w -I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" CPPFLAGS="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	LIBS="-L$(HOST_NCURSES)/lib -lncursesw" ./configure --prefix=$(bitchx_HOBJ)/inst --without-ssl --disable-ipv6
bitchx_HOST_BUILD_CMD = $(MAKE) -C $(bitchx_HOBJ) -j$(JOBS) install && find $(bitchx_HOBJ)/inst/lib/bx/help -name '*.bz2' -exec bzip2 -d -f {} +
