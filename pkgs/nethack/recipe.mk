# NetHack 3.6.7: the roguelike, tty interface (and the curses interface) against ncursesw.
# NetHack has no configure: sys/unix/setup.sh turns a hints file into the Makefiles.
# patch 0001 adds two: sys/unix/hints/m68k-amigaos (the cross build) and sys/unix/hints/upterm-host
# (the Mac build for the expected outputs).
# The build runs the data tools (makedefs, lev_comp, dgn_comp, dlb); the Mac cannot produce the
# game's binary data for the Amiga (lev_comp and dgn_comp dump structs with 8-byte long, little
# endian), so the data is baked on the Amiga by the m68k tools: pkgs/nethack/bake.sh runs on a rig
# and writes pkgs/nethack/data/nhdat, which the install ships (share/nethack/nhdat).
nethack_VERSION   := 3.6.7
nethack_URL       := https://www.nethack.org/download/$(nethack_VERSION)/nethack-367-src.tgz
nethack_ARCHIVE   := $(DL)/nethack-367-src.tgz
nethack_SHA256    := 98cf67df6debf9668a61745aa84c09bcab362e5d33f5b944ec5155d44d2aacb2
nethack_LICENSE   := NGPL
nethack_LICENSE_FILES := dat/license
nethack_DEPS      := ixcompat ncurses
nethack_HOST_DEPS := ncurses
nethack_BINS      := bin/nethack
nethack_STACK     := 262144
nethack_STACK_VAR := 1
# the hints files are generated into Makefiles by sys/unix/setup.sh; the build is pkgs/nethack/nhbuild.sh:
#   m68k <obj> <src>: host makedefs for the generated headers and text, m68k game and tools
#   host <obj> <src>: the whole game on the Mac (expected outputs)
nethack_NH_ENV = NH_CC="$(ROOT)/tools/m68k-cc" NH_AR=$(CROSS)ar NH_RANLIB=$(CROSS)ranlib \
	NH_CFLAGS="$(CPU) -O2" NH_INC=$(SYSINC) NH_LIBS="-L$(SYSLIB) -lncursesw $(SYSLIB)/libixcompat.a" \
	CONFIG_SITE=$(ROOT)/mk/config.site
nethack_CONFIGURE_CMD = cp -R $(nethack_SRC)/. $(nethack_OBJ)/ && cd $(nethack_OBJ)/sys/unix && \
	$(nethack_NH_ENV) sh setup.sh hints/m68k-amigaos
nethack_BUILD_CMD = $(nethack_NH_ENV) sh $(ROOT)/pkgs/nethack/nhbuild.sh m68k $(nethack_OBJ)
nethack_INSTALL_CMD = sh $(ROOT)/pkgs/nethack/nhbuild.sh install $(nethack_OBJ) $(SYSROOT)$(PREFIX) $(ROOT)/pkgs/nethack/data
nethack_HOST_CONFIGURE_CMD = cp -R $(nethack_SRC)/. $(nethack_HOBJ)/ && cd $(nethack_HOBJ)/sys/unix && \
	NH_INC=$(HOST_NCURSES)/include NH_NCURSES=$(HOST_NCURSES) NH_PREFIX=$(nethack_HOBJ)/inst sh setup.sh hints/upterm-host
nethack_HOST_BUILD_CMD = NH_INC=$(HOST_NCURSES)/include NH_NCURSES=$(HOST_NCURSES) NH_PREFIX=$(nethack_HOBJ)/inst \
	sh $(ROOT)/pkgs/nethack/nhbuild.sh host $(nethack_HOBJ) $(nethack_HOBJ)/inst
nethack_DATA := share/nethack
