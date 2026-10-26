# figlet: large text banners (Frank, Glenn and Ian's FIGlet, 2.2.5 from the cmatsuoka mirror). Plain Makefile.
figlet_VERSION   := 2.2.5
figlet_URL       := https://github.com/cmatsuoka/figlet/archive/refs/tags/$(figlet_VERSION).tar.gz
figlet_ARCHIVE   := $(DL)/figlet-$(figlet_VERSION).tar.gz
figlet_SHA256    := 4d366c4a618ecdd6fdb81cde90edc54dbff9764efb635b3be47a929473f13930
figlet_LICENSE   := BSD-3-Clause
figlet_LICENSE_FILES := LICENSE
figlet_DEPS      := ixcompat
figlet_BINS      := bin/figlet
figlet_STACK     := 65536
figlet_CONFIGURE_CMD = rsync -a --exclude .git $(figlet_SRC)/ $(figlet_OBJ)/
figlet_BUILD_CMD = $(MAKE) -C $(figlet_OBJ) figlet CC="$(ROOT)/tools/m68k-cc" LD="$(ROOT)/tools/m68k-cc" \
	LDFLAGS="-Wl,$(OBJ)/figlet.stack.o" CFLAGS="$(CPU) -O2 -include unistd.h -I$(SYSINC)" DEFAULTFONTDIR=$(PREFIX)/share/figlet \
	OBJS="figlet.o zipio.o crc.o inflate.o utf8.o $(SYSLIB)/libixcompat.a"
figlet_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/figlet && \
	install -m 755 $(figlet_OBJ)/figlet $(SYSROOT)$(PREFIX)/bin/figlet && \
	install -m 644 $(figlet_SRC)/fonts/standard.flf $(SYSROOT)$(PREFIX)/share/figlet/
figlet_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(figlet_SRC)/ $(figlet_HOBJ)/
figlet_HOST_BUILD_CMD = $(MAKE) -C $(figlet_HOBJ) figlet CFLAGS="-O2 -include unistd.h" DEFAULTFONTDIR=$(figlet_HOBJ)/fonts && mkdir -p $(figlet_HOBJ)/inst/bin && \
	cp $(figlet_HOBJ)/figlet $(figlet_HOBJ)/inst/bin/figlet
figlet_FEED_ID   := up-figlet
figlet_SUMMARY   := FIGlet large text banners in UP-Term:bin with the standard font in UP-Term:share/figlet
