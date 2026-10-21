# upkg-ui (vtcon upkg plan P10.6): our own, replaces dialog for the add-on install questions
# (upkg-ask). Full-screen ncursesw widgets (inputbox, yesno, menu) drawn in the AmiExpress door
# SDK chrome, theme "Uprough Neon (muted)". chrome.c is pure (no curses) and has its own unit
# test, test_chrome.c, run by the host build. No fork.
upkg-ui_OWN       := 1
upkg-ui_VERSION   := 1.1
upkg-ui_LICENSE   := own
upkg-ui_DEPS      := ixcompat ncurses
upkg-ui_BINS      := bin/upkg-ui
upkg-ui_STACK     := 65536
upkg-ui_HOST_DEPS := ncurses
upkg-ui_CONFIGURE_CMD = mkdir -p $(upkg-ui_OBJ)
upkg-ui_BUILD_CMD = $(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -I$(SYSINC) -I$(SYSINC)/ncursesw \
	-o $(upkg-ui_OBJ)/upkg-ui $(upkg-ui_SRC)/upkg-ui.c $(upkg-ui_SRC)/chrome.c \
	-Wl,$(OBJ)/upkg-ui.stack.o $(SYSLIB)/libncursesw.a $(SYSLIB)/libixcompat.a
upkg-ui_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin && \
	install -m 755 $(upkg-ui_OBJ)/upkg-ui $(SYSROOT)$(PREFIX)/bin/upkg-ui
upkg-ui_HOST_CONFIGURE_CMD = mkdir -p $(upkg-ui_HOBJ)
upkg-ui_HOST_BUILD_CMD = cc -O2 -Wall -Wextra -o $(upkg-ui_HOBJ)/test_chrome $(upkg-ui_SRC)/test_chrome.c $(upkg-ui_SRC)/chrome.c && \
	$(upkg-ui_HOBJ)/test_chrome && \
	cc -O2 -Wall -I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include \
	-o $(upkg-ui_HOBJ)/upkg-ui $(upkg-ui_SRC)/upkg-ui.c $(upkg-ui_SRC)/chrome.c \
	-L$(HOST_NCURSES)/lib -lncursesw && \
	mkdir -p $(upkg-ui_HOBJ)/inst/bin && cp $(upkg-ui_HOBJ)/upkg-ui $(upkg-ui_HOBJ)/inst/bin/upkg-ui
