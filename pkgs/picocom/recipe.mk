# picocom 3.1 (npat-efault/picocom): the minimal serial terminal emulator, plain Makefile, no configure.
# Built in a copy of the tree (the makefile writes objects beside the sources).
# Off: HIGH_BAUD, custom baud rates and UUCP lock directories (the makefile leaves the last two off);
# flock locking and linenoise stay on, as upstream's makefile has them.
picocom_VERSION   := 3.1
picocom_SUMMARY   := picocom 3.1 serial terminal in UP-Term:bin
picocom_URL       := https://github.com/npat-efault/picocom/archive/refs/tags/$(picocom_VERSION).tar.gz
picocom_ARCHIVE   := $(DL)/picocom-$(picocom_VERSION).tar.gz
picocom_SHA256    := e6761ca932ffc6d09bd6b11ff018bdaf70b287ce518b3282d29e0270e88420bb
picocom_LICENSE   := GPL-2.0-or-later
picocom_LICENSE_FILES := LICENSE.txt
picocom_DEPS      := ixcompat
picocom_BINS      := bin/picocom
picocom_STACK     := 262144
# started by ptyrun (vfork+exec), which ignores the $STACK: cookie (see hexedit): define __stack too
picocom_STACK_VAR := 1
picocom_CONFIGURE_CMD = rsync -a --exclude .git $(picocom_SRC)/ $(picocom_OBJ)/
picocom_BUILD_CMD = $(MAKE) -C $(picocom_OBJ) picocom CC="$(ROOT)/tools/m68k-cc $(CPU)" \
	CFLAGS="-O2 -Wall -I$(SYSINC)" CPPFLAGS="-DVERSION_STR=\\\"$(picocom_VERSION)\\\" -DTTY_Q_SZ=0 -DUSE_FLOCK -DHISTFILE=\\\".picocom_history\\\" -DLINENOISE" \
	LDFLAGS="$(OBJ)/picocom.stack.o" LDLIBS="$(SYSLIB)/libixcompat.a"
picocom_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(picocom_OBJ)/picocom $(SYSROOT)$(PREFIX)/bin/picocom && \
	install -m 644 $(picocom_OBJ)/picocom.1 $(SYSROOT)$(PREFIX)/share/man/man1/picocom.1
picocom_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(picocom_SRC)/ $(picocom_HOBJ)/
picocom_HOST_BUILD_CMD = $(MAKE) -C $(picocom_HOBJ) picocom CPPFLAGS="-DVERSION_STR=\\\"$(picocom_VERSION)\\\" -DTTY_Q_SZ=0 -DUSE_FLOCK -DHISTFILE=\\\".picocom_history\\\" -DLINENOISE" && \
	mkdir -p $(picocom_HOBJ)/inst/bin && cp $(picocom_HOBJ)/picocom $(picocom_HOBJ)/inst/bin/picocom
