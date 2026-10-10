# fzy (vtcon plan 3.9): the fuzzy finder (fzf is Go). Plain Makefile, no
# configure. Patch 0001 searches in the calling thread: AmigaOS has no
# pthreads, and ixemul no sysconf(_SC_NPROCESSORS_ONLN).
fzy_VERSION   := 1.0
fzy_URL       := https://github.com/jhawthorn/fzy/releases/download/$(fzy_VERSION)/fzy-$(fzy_VERSION).tar.gz
fzy_SHA256    := 80257fd74579e13438b05edf50dcdc8cf0cdb1870b4a2bc5967bd1fdbed1facf
fzy_LICENSE   := MIT
fzy_LICENSE_FILES := LICENSE
fzy_DEPS      := ixcompat
fzy_BINS      := bin/fzy
fzy_STACK     := 65536
fzy_CONFIGURE_CMD = rsync -a --exclude .git $(fzy_SRC)/ $(fzy_OBJ)/
fzy_BUILD_CMD = $(MAKE) -C $(fzy_OBJ) fzy CC="$(ROOT)/tools/m68k-cc" CFLAGS="$(CPU) -O2 -I$(SYSINC) -Ideps -DFZY_NO_THREADS" \
	LIBS="-Wl,$(OBJ)/fzy.stack.o $(SYSLIB)/libixcompat.a"
fzy_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(fzy_OBJ)/fzy $(SYSROOT)$(PREFIX)/bin/fzy && \
	install -m 644 $(fzy_SRC)/fzy.1 $(SYSROOT)$(PREFIX)/share/man/man1/fzy.1
fzy_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(fzy_SRC)/ $(fzy_HOBJ)/
fzy_HOST_BUILD_CMD = $(MAKE) -C $(fzy_HOBJ) fzy CFLAGS="-O2 -Ideps" LIBS= && mkdir -p $(fzy_HOBJ)/inst/bin && \
	cp $(fzy_HOBJ)/fzy $(fzy_HOBJ)/inst/bin/fzy
