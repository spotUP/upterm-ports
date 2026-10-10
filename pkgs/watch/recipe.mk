# watch (vtcon plan 3.4): our own, a small program (procps-ng's needs its
# library and curses, and forks). The command runs through posix_spawn.
watch_OWN       := 1
watch_VERSION   := 1.0
watch_LICENSE   := own
watch_DEPS      := ixcompat
watch_BINS      := bin/watch
watch_STACK     := 65536
watch_CONFIGURE_CMD = mkdir -p $(watch_OBJ)
watch_BUILD_CMD = $(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -I$(SYSINC) -o $(watch_OBJ)/watch $(watch_SRC)/watch.c \
	-Wl,$(OBJ)/watch.stack.o $(SYSLIB)/libixcompat.a
watch_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(watch_OBJ)/watch $(SYSROOT)$(PREFIX)/bin/watch && \
	install -m 644 $(watch_SRC)/watch.1 $(SYSROOT)$(PREFIX)/share/man/man1/watch.1
watch_HOST_CONFIGURE_CMD = mkdir -p $(watch_HOBJ)
watch_HOST_BUILD_CMD = cc -O2 -Wall -o $(watch_HOBJ)/watch $(watch_SRC)/watch.c && mkdir -p $(watch_HOBJ)/inst/bin && \
	cp $(watch_HOBJ)/watch $(watch_HOBJ)/inst/bin/watch
watch_CHECK_DEPS := sed grep
