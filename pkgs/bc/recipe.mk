# GNU bc 1.07.1 and dc (vtcon plan 4.6). Plain autotools; libmath.h ships
# pre-generated, so the build never runs the target's fbc (cross build).
# No readline (the vsh line editor is the kit's), no NLS.
bc_VERSION   := 1.07.1
bc_URL       := https://ftp.gnu.org/gnu/bc/bc-$(bc_VERSION).tar.gz
bc_SHA256    := 62adfca89b0a1c0164c2cdca59ca210c1d44c3ffc46daf9931cf4942664cb02a
bc_LICENSE   := GPL-3.0-or-later
bc_LICENSE_FILES := COPYING
bc_DEPS      := ixcompat
bc_CONFIGURE := --without-readline --without-libedit
bc_HOST_CONFIGURE := --without-readline --without-libedit
bc_BINS      := bin/bc bin/dc
bc_STACK     := 65536
bc_CHECK_DEPS := sed
# libmath.h is made by running fbc, which cannot run on the Mac when it is the
# cross build. The Mac build of the same source makes it (text, the same on
# both sides); a first pass builds fbc and the library, the Mac's libmath.h is
# put in, newer than both, and a second pass builds the rest.
bc_BUILD_CMD = $(MAKE) -C $(ROOT) JOBS=$(JOBS) $(STATE)/host-bc.built && \
	{ $(MAKE) -k -C $(bc_OBJ) -j$(JOBS) || true; } && \
	cp $(bc_HOBJ)/bc/libmath.h $(bc_OBJ)/bc/libmath.h && $(MAKE) -C $(bc_OBJ) -j$(JOBS)
