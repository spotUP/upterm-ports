# The One True Awk (vtcon plan 1.3): Kernighan's awk, second edition, as
# `awk`. A plain makefile (no configure); the build happens in a copy of the
# source, because the makefile writes its objects next to the sources.
# system() and | pipes go through ixemul's popen/system (vfork + /bin/sh).
awk_VERSION   := 20260426
awk_URL       := https://codeload.github.com/onetrueawk/awk/tar.gz/refs/tags/$(awk_VERSION)
awk_ARCHIVE   := $(DL)/awk-$(awk_VERSION).tar.gz
awk_SHA256    := 7ae5b9fc6a8149bc45ea0ba3ba434a69a16d1460d19f6d01b6f04cc885b8e02b
awk_LICENSE   := MIT-like (Lucent Technologies, LICENSE)
awk_DEPS      := ixcompat
awk_BINS      := bin/awk
# provisional, grep's value: the parser and the regex code recurse
awk_STACK     := 262144
# maketab and the bison grammar run on the Mac (HOSTCC, YACC); the objects
# are cross-compiled by the makefile (CFLAGS also reaches HOSTCC, so the m68k
# flags ride in CC), and the link is ours: the makefile links -lm, which
# with -mcrt=ixemul finds newlib's libm (undefined _impure_ptr); ixemul's
# libc has the math functions itself.
awk_CONFIGURE_CMD = rsync -a --exclude .git $(awk_SRC)/ $(awk_OBJ)/
AWK_OBJS := awkgram.tab.o b.o main.o parse.o proctab.o tran.o lib.o run.o lex.o
awk_BUILD_CMD = $(MAKE) -C $(awk_OBJ) $(AWK_OBJS) HOSTCC=cc CFLAGS=-O2 \
	CC="$(ROOT)/tools/m68k-cc $(CPU) -I$(SYSINC)" && \
	cd $(awk_OBJ) && $(ROOT)/tools/m68k-cc -o a.out $(AWK_OBJS) \
	$(OBJ)/awk.stack.o $(SYSLIB)/libixcompat.a
awk_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(awk_OBJ)/a.out $(SYSROOT)$(PREFIX)/bin/awk && \
	install -m 644 $(awk_SRC)/awk.1 $(SYSROOT)$(PREFIX)/share/man/man1/awk.1
awk_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(awk_SRC)/ $(awk_HOBJ)/
awk_HOST_BUILD_CMD = $(MAKE) -C $(awk_HOBJ) a.out && \
	mkdir -p $(awk_HOBJ)/inst/bin && cp $(awk_HOBJ)/a.out $(awk_HOBJ)/inst/bin/awk
