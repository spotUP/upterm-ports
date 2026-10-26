# Exuberant ctags 5.8 (vtcon plan 4.11). The configure is autoconf 2.x with no
# out-of-tree build: the tree is copied to the object directory first (as ed
# does). Only the ctags program is installed (no etags link).
# -UAMIGA: the toolchain predefines AMIGA, which ctags reads as its native
#   AmigaDOS code (dos.library calls, no POSIX); -UAMIGA takes the POSIX path.
# config.h TMPDIR: configure writes the build Mac's $TMPDIR there; the sed sets
#   "/T" (T:), the Amiga's. Tags to stdout (-x, -f -) go through a temporary file
#   in it (measured on the rig: "cannot open temporary file").
# Host build: -D__GNUG__ stops general.h defining __unused__, which the macOS
#   headers use.
ctags_VERSION   := 5.8
ctags_SUMMARY   := Exuberant ctags 5.8 source code tag generator in UP-Term:bin
ctags_URL       := https://downloads.sourceforge.net/project/ctags/ctags/$(ctags_VERSION)/ctags-$(ctags_VERSION).tar.gz
ctags_SHA256    := 0e44b45dcabe969e0bbbb11e30c246f81abe5d32012db37395eb57d66e9e99c7
ctags_LICENSE   := GPL-2.0-or-later
ctags_LICENSE_FILES := COPYING
ctags_DEPS      := ixcompat
ctags_BINS      := bin/ctags
ctags_STACK     := 65536
ctags_CHECK_DEPS := sed
ctags_CONFIGURE_CMD = rsync -a --exclude .git $(ctags_SRC)/ $(ctags_OBJ)/ && cd $(ctags_OBJ) && \
	$(call M68K_ENV,ctags) CFLAGS="$(CPU) -O2 -UAMIGA -I$(SYSINC)" ./configure --build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) --disable-etags --disable-external-sort && \
	sed -i.orig 's|^\#define TMPDIR .*|\#define TMPDIR "/T"|' config.h
ctags_BUILD_CMD = $(MAKE) -C $(ctags_OBJ) ctags
ctags_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(ctags_OBJ)/ctags $(SYSROOT)$(PREFIX)/bin/ctags && \
	install -m 644 $(ctags_OBJ)/ctags.1 $(SYSROOT)$(PREFIX)/share/man/man1/ctags.1
ctags_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(ctags_SRC)/ $(ctags_HOBJ)/ && cd $(ctags_HOBJ) && \
	CFLAGS="-O2 -D__GNUG__=1" ./configure --prefix=$(ctags_HOBJ)/inst --disable-etags
ctags_HOST_BUILD_CMD = $(MAKE) -C $(ctags_HOBJ) ctags && mkdir -p $(ctags_HOBJ)/inst/bin && cp $(ctags_HOBJ)/ctags $(ctags_HOBJ)/inst/bin/ctags
