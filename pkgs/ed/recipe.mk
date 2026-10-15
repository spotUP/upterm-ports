# GNU ed 1.20 (vtcon plan 4.10). Its configure is a hand-written script: no
# --host/--build, CC and CFLAGS as arguments; it builds in the source tree, so
# the tree is copied to the object directory first (as fzy does). Shell escapes
# (`!command`) use the system() of libixcompat. -include sys/types.h: the
# toolchain's <regex.h> uses off_t without including it (regoff_t); the gap
# belongs in ixemul-vtcon/include/regex.h, which this recipe cannot change.
ed_VERSION   := 1.20
ed_URL       := https://ftp.gnu.org/gnu/ed/ed-$(ed_VERSION).tar.lz
ed_SHA256    := c6030defe6ae172f1687906d7354054c75a6a9130af319d4e73c50a91959c5a6
ed_LICENSE   := GPL-3.0-or-later
ed_LICENSE_FILES := COPYING
ed_DEPS      := ixcompat
ed_BINS      := bin/ed
ed_STACK     := 65536
ed_CHECK_DEPS := sed
ed_CONFIGURE_CMD = rsync -a --exclude .git $(ed_SRC)/ $(ed_OBJ)/ && cd $(ed_OBJ) && \
	./configure --prefix=$(PREFIX) CC="$(ROOT)/tools/m68k-cc" CFLAGS="$(CPU) -O2" CPPFLAGS="-I$(SYSINC) -include sys/types.h" \
	LDFLAGS="-L$(SYSLIB) -Wl,$(OBJ)/ed.stack.o" LIBS="$(SYSLIB)/libixcompat.a"
ed_BUILD_CMD = $(MAKE) -C $(ed_OBJ) ed
ed_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(ed_OBJ)/ed $(SYSROOT)$(PREFIX)/bin/ed && \
	install -m 644 $(ed_OBJ)/doc/ed.1 $(SYSROOT)$(PREFIX)/share/man/man1/ed.1
ed_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(ed_SRC)/ $(ed_HOBJ)/ && cd $(ed_HOBJ) && \
	./configure --prefix=$(ed_HOBJ)/inst
ed_HOST_BUILD_CMD = $(MAKE) -C $(ed_HOBJ) ed && mkdir -p $(ed_HOBJ)/inst/bin && cp $(ed_HOBJ)/ed $(ed_HOBJ)/inst/bin/ed
