# script (vtcon plan 3.5): our own, a small program over libixcompat's pty
# calls (posix_openpt, grantpt, unlockpt, ptsname) and a vfork child.
script_OWN       := 1
script_VERSION   := 1.0
script_LICENSE   := own
script_DEPS      := ixcompat
script_BINS      := bin/script
script_STACK     := 65536
script_CONFIGURE_CMD = mkdir -p $(script_OBJ)
script_BUILD_CMD = $(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -I$(SYSINC) -o $(script_OBJ)/script $(script_SRC)/script.c \
	-Wl,$(OBJ)/script.stack.o $(SYSLIB)/libixcompat.a
script_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(script_OBJ)/script $(SYSROOT)$(PREFIX)/bin/script && \
	install -m 644 $(script_SRC)/script.1 $(SYSROOT)$(PREFIX)/share/man/man1/script.1
script_HOST_CONFIGURE_CMD = mkdir -p $(script_HOBJ)
script_HOST_BUILD_CMD = cc -O2 -Wall -o $(script_HOBJ)/script $(script_SRC)/script.c && mkdir -p $(script_HOBJ)/inst/bin && \
	cp $(script_HOBJ)/script $(script_HOBJ)/inst/bin/script
script_CHECK_DEPS := grep sed
