# nnn (vtcon tui-port-candidates #2): the terminal file manager, one C file against ncursesw.
# Plain Makefile, no configure. Built without readline (NORL: nnn's own prompt), without
# locale hooks, sessions, X11 and the FIFO previewer. fork() is gone: the patches use vfork.
nnn_VERSION   := 5.3
nnn_URL       := https://github.com/jarun/nnn/releases/download/v$(nnn_VERSION)/nnn-v$(nnn_VERSION).tar.gz
nnn_ARCHIVE   := $(DL)/nnn-$(nnn_VERSION).tar.gz
nnn_SHA256    := c626d57d0aaa5effe04a7e8c24ec9000bc3aca012461b821ecd3c81f5131bb6d
nnn_LICENSE   := BSD-2-Clause
nnn_LICENSE_FILES := LICENSE
nnn_DEPS      := ixcompat ncurses
nnn_BINS      := bin/nnn
nnn_STACK     := 262144
# programs started by ptyrun (vfork+exec) ignore the $STACK: cookie; without __stack nnn ran on the
# tiny inherited stack and corrupted the heap ("free: start of block corrupt!" guest requester)
nnn_STACK_VAR := 1
nnn_OPTS      := O_NORL=1 O_NOLC=1 O_NOSSN=1 O_NOX11=1 O_NOFIFO=1 O_NOBATCH=1
nnn_CONFIGURE_CMD = cp -R $(nnn_SRC)/. $(nnn_OBJ)/
# the Makefile asks pkg-config for ncursesw and links -lpthread: both answered here
nnn_BUILD_CMD = $(MAKE) -C $(nnn_OBJ) nnn $(nnn_OPTS) CC="$(ROOT)/tools/m68k-cc" PKG_CONFIG=false \
	CFLAGS_OPTIMIZATION="$(CPU) -O2" CFLAGS_CURSES="-I$(SYSINC) -I$(SYSINC)/ncursesw" \
	LDLIBS_CURSES="-L$(SYSLIB) -lncursesw" LDFLAGS="-Wl,$(OBJ)/nnn.stack.o" \
	LDLIBS="-L$(SYSLIB) -lncursesw $(SYSLIB)/libixcompat.a" && :
nnn_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(nnn_OBJ)/nnn $(SYSROOT)$(PREFIX)/bin/nnn && \
	install -m 644 $(nnn_SRC)/nnn.1 $(SYSROOT)$(PREFIX)/share/man/man1/nnn.1
nnn_HOST_CONFIGURE_CMD = cp -R $(nnn_SRC)/. $(nnn_HOBJ)/
nnn_HOST_DEPS := ncurses
nnn_HOST_BUILD_CMD = $(MAKE) -C $(nnn_HOBJ) nnn $(nnn_OPTS) PKG_CONFIG=false CFLAGS_OPTIMIZATION=-O2 \
	CFLAGS_CURSES="-I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include" \
	LDLIBS="-L$(HOST_NCURSES)/lib -lncursesw" && mkdir -p $(nnn_HOBJ)/inst/bin && \
	cp $(nnn_HOBJ)/nnn $(nnn_HOBJ)/inst/bin/nnn
