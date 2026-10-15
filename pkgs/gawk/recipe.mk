# GNU awk 5.3.2 (vtcon plan 4.8), installed as `gawk`; `awk` stays the One True Awk
# (pkgs/awk). No dynamic extensions (no dlopen), no readline, no MPFR, no persistent
# malloc (pma), no NLS.
gawk_VERSION   := 5.3.2
gawk_URL       := https://ftp.gnu.org/gnu/gawk/gawk-$(gawk_VERSION).tar.xz
gawk_SHA256    := f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc
gawk_LICENSE   := GPL-3.0-or-later
gawk_DEPS      := ixcompat
gawk_CONFIGURE := --disable-nls --disable-extensions --disable-pma --without-readline --without-mpfr
gawk_HOST_CONFIGURE := --disable-nls --disable-extensions --disable-pma --without-readline --without-mpfr
gawk_ENV := CPPFLAGS="-I$(SYSINC) -DPIPES_SIMULATED"
gawk_BINS      := bin/gawk
# provisional, the awk/grep value: the regex code and the parser recurse
gawk_STACK     := 262144
gawk_STACK_VAR := 1
# configure's GCC branch rewrites extension/Makefile for -O3 even when --disable-extensions
# leaves that directory out ("sed: extension/Makefile: No such file", gawk 5.3.2): give it an
# empty file in the build tree, which nothing reads afterwards.
gawk_CONFIGURE_CMD = mkdir -p $(gawk_OBJ)/extension && touch $(gawk_OBJ)/extension/Makefile && \
	cd $(gawk_OBJ) && $(call M68K_ENV,gawk) $(gawk_ENV) $(gawk_SRC)/configure \
	--build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $(gawk_CONFIGURE)
gawk_HOST_CONFIGURE_CMD = mkdir -p $(gawk_HOBJ)/extension && touch $(gawk_HOBJ)/extension/Makefile && \
	cd $(gawk_HOBJ) && $(gawk_SRC)/configure --prefix=$(gawk_HOBJ)/inst $(gawk_HOST_CONFIGURE)
# gawk's makefiles put LDFLAGS on the link line three times, so the $STACK: cookie object
# (which M68K_ENV passes in LDFLAGS) is defined three times: the cookie rides in LIBS here.
gawk_BUILD_CMD = $(MAKE) -C $(gawk_OBJ) -j$(JOBS) LDFLAGS="-L$(SYSLIB)" AM_LDFLAGS= \
	LIBS="-Wl,$(OBJ)/gawk.stack.o $(SYSLIB)/libixcompat.a"
gawk_CHECK_DEPS := sed
