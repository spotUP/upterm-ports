# upkg-ui (vtcon upkg plan P10.6): our own, replaces dialog for the add-on install questions
# (upkg-ask). Full-screen ncursesw widgets (inputbox, yesno, menu) drawn in the AmiExpress door
# SDK chrome, theme "Uprough Neon (muted)". chrome.c is pure (no curses) and has its own unit
# test, test_chrome.c, run by the host build. No fork. ui.c + chrome.c are libupkgui.a (installed to the sysroot with ui.h): upkg-ui links it,
# and so does `upkg browse` inside upkg (opkg).
upkg-ui_OWN       := 1
upkg-ui_VERSION   := 1.1
upkg-ui_LICENSE   := own
upkg-ui_DEPS      := ixcompat ncurses
upkg-ui_BINS      := bin/upkg-ui
upkg-ui_STACK     := 65536
upkg-ui_HOST_DEPS := ncurses
upkg-ui_CHECK_SH_BIN := bin/upkg-ui
upkg-ui_CONFIGURE_CMD = mkdir -p $(upkg-ui_OBJ)
upkg-ui_CC = $(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -I$(SYSINC) -I$(SYSINC)/ncursesw
upkg-ui_BUILD_CMD = $(upkg-ui_CC) -c -o $(upkg-ui_OBJ)/ui.o $(upkg-ui_SRC)/ui.c && \
	$(upkg-ui_CC) -c -o $(upkg-ui_OBJ)/chrome.o $(upkg-ui_SRC)/chrome.c && \
	rm -f $(upkg-ui_OBJ)/libupkgui.a && $(CROSS)ar rcs $(upkg-ui_OBJ)/libupkgui.a $(upkg-ui_OBJ)/ui.o $(upkg-ui_OBJ)/chrome.o && \
	$(upkg-ui_CC) -o $(upkg-ui_OBJ)/upkg-ui $(upkg-ui_SRC)/upkg-ui.c $(upkg-ui_OBJ)/libupkgui.a \
	-Wl,$(OBJ)/upkg-ui.stack.o $(SYSLIB)/libncursesw.a $(SYSLIB)/libixcompat.a
upkg-ui_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSLIB) $(SYSINC)/upkgui && \
	install -m 755 $(upkg-ui_OBJ)/upkg-ui $(SYSROOT)$(PREFIX)/bin/upkg-ui && \
	install -m 644 $(upkg-ui_OBJ)/libupkgui.a $(SYSLIB)/libupkgui.a && \
	install -m 644 $(upkg-ui_SRC)/ui.h $(upkg-ui_SRC)/chrome.h $(SYSINC)/upkgui/
upkg-ui_HOST_CONFIGURE_CMD = mkdir -p $(upkg-ui_HOBJ)
upkg-ui_HOST_NC = -I$(HOST_NCURSES)/include/ncursesw -I$(HOST_NCURSES)/include
upkg-ui_HOST_BUILD_CMD = cc -O2 -Wall -Wextra -o $(upkg-ui_HOBJ)/test_chrome $(upkg-ui_SRC)/test_chrome.c $(upkg-ui_SRC)/chrome.c && \
	$(upkg-ui_HOBJ)/test_chrome && \
	cc -O2 -Wall $(upkg-ui_HOST_NC) -c -o $(upkg-ui_HOBJ)/ui.o $(upkg-ui_SRC)/ui.c && \
	cc -O2 -Wall -c -o $(upkg-ui_HOBJ)/chrome.o $(upkg-ui_SRC)/chrome.c && \
	rm -f $(upkg-ui_HOBJ)/libupkgui.a && ar rcs $(upkg-ui_HOBJ)/libupkgui.a $(upkg-ui_HOBJ)/ui.o $(upkg-ui_HOBJ)/chrome.o && \
	cc -O2 -Wall $(upkg-ui_HOST_NC) -o $(upkg-ui_HOBJ)/upkg-ui $(upkg-ui_SRC)/upkg-ui.c $(upkg-ui_HOBJ)/libupkgui.a \
	-L$(HOST_NCURSES)/lib -lncursesw && \
	mkdir -p $(upkg-ui_HOBJ)/inst/bin $(upkg-ui_HOBJ)/inst/lib $(upkg-ui_HOBJ)/inst/include/upkgui && \
	cp $(upkg-ui_HOBJ)/upkg-ui $(upkg-ui_HOBJ)/inst/bin/upkg-ui && \
	cp $(upkg-ui_HOBJ)/libupkgui.a $(upkg-ui_HOBJ)/inst/lib/ && cp $(upkg-ui_SRC)/ui.h $(upkg-ui_SRC)/chrome.h $(upkg-ui_HOBJ)/inst/include/upkgui/
