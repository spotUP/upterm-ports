# Shared settings and the recipe driver. Included by the top Makefile.

ROOT    := $(CURDIR)
B       := $(ROOT)/build
DL      := $(B)/dl
SRC     := $(B)/src
OBJ     := $(B)/obj
HOSTB   := $(B)/host
STATE   := $(B)/state
EXPECT  := $(B)/expected
SYSROOT := $(B)/sysroot

AMIGA   ?= $(HOME)/opt/amiga
CROSS   := $(AMIGA)/bin/m68k-amigaos-
# The workspace directory that holds this repo and its siblings (the upterm
# meta-repo creates it); the sibling defaults below hang off it.
UPTERM_ROOT ?= $(abspath $(CURDIR)/..)
IXEMUL  ?= $(UPTERM_ROOT)/ixemul-vtcon
VTCON   ?= $(UPTERM_ROOT)/vtcon

# Where the tools live on the Amiga, as ixemul spells it (/SYS/x = SYS:x).
# Every package installs with DESTDIR=$(SYSROOT), so the libraries and
# headers the next package builds against are under SYSINC/SYSLIB, and
# the files the kit ships are under $(SYSROOT)$(PREFIX)/{bin,share}.
# The kit installs into a drawer the user picks and assigns it UP-Term: (vtcon
# dist/install.dos), so the prefix is the assign, not SYS:UP-Term: nano's
# syntax files, mandoc's MANPATH and the like are found wherever it is.
PREFIX  := /UP-Term
SYSINC  := $(SYSROOT)$(PREFIX)/include
SYSLIB  := $(SYSROOT)$(PREFIX)/lib

# 68020, soft float (the kit's coreutils; an A1200 without an FPU runs it).
CPU     ?= -m68020
# The Mac overheats: never more than 4 jobs.
JOBS    ?= 4
ifeq ($(shell [ $(JOBS) -le 4 ] && echo ok),)
$(error JOBS=$(JOBS): at most 4 parallel jobs on this machine)
endif

comma := ,
# $(call M68K_ENV,<pkg>): the cross environment for configure.
# libixcompat goes in by its path: with -mcrt=ixemul the gcc driver puts the
# SDK's -L directories before ours, so -lixcompat would find the toolchain's
# old copy in ixemul/lib, not the sysroot's (measured 2026-10-04 with -Map).
# The $STACK: cookie object reaches the linker through -Wl,: libtool refuses
# an object file among a library's LIBS ("cannot build libtool library from
# non-libtool objects", xz 5.8.4); programs link it, static libraries ignore it.
M68K_ENV = CONFIG_SITE=$(ROOT)/mk/config.site \
	CC="$(ROOT)/tools/m68k-cc" CPP="$(ROOT)/tools/m68k-cc -E" \
	AR=$(CROSS)ar RANLIB=$(CROSS)ranlib STRIP=$(CROSS)strip NM=$(CROSS)nm \
	CFLAGS="$(CPU) -O2" CPPFLAGS="-I$(SYSINC)" \
	LDFLAGS="-L$(SYSLIB)$(if $($(1)_STACK), -Wl$(comma)$(OBJ)/$(1).stack.o)" \
	LIBS="$($(1)_LIBS) $(SYSLIB)/libixcompat.a" PKG_CONFIG=false
BUILD_TRIPLE := $(shell sh $(ROOT)/tools/build-triple.sh)

# $(call CHECK_PATH,<p>): the Mac bin directories a package's checks run with
CHECK_PATH = $($(1)_HOBJ)/inst/bin$(foreach d,$($(1)_CHECK_DEPS),:$(HOSTB)/$(d)/inst/bin)

# ---- the recipe driver --------------------------------------------------------
# A package <p> is pkgs/<p>/recipe.mk. It sets:
#   <p>_VERSION, <p>_URL, <p>_SHA256   the upstream archive (sha256-verified)
#   <p>_DEPS        packages whose install it builds against (stamps)
#   <p>_CONFIGURE   extra configure arguments for the m68k build
#   <p>_HOST_CONFIGURE  same for the macOS build (expected outputs)
#   <p>_HOST_DEPS   packages whose macOS build it builds against (the same
#                   library versions on both sides: ncurses for the screens)
#   <p>_CHECK_DEPS  packages whose programs its checks run (man pages
#                   through less): on PATH for the cases, Mac and rig alike
#   <p>_BINS        installed programs to check, relative to $(SYSROOT)$(PREFIX)
#   <p>_STACK       the $STACK: cookie the programs must carry (empty: none)
#   <p>_LIBS        extra libraries before -lixcompat
#   <p>_LICENSE     for SOURCES.txt
#   <p>_POST_INSTALL  shell run after make install (optional)
#   <p>_OWN         our own program: the source is pkgs/<p>/src (no download, no
#                   <p>_URL/SHA256), copied to build/src/<p> as the unpack step
# and may replace a step: <p>_CONFIGURE_CMD, <p>_BUILD_CMD, <p>_INSTALL_CMD,
# and for the macOS build <p>_HOST_CONFIGURE_CMD, <p>_HOST_BUILD_CMD (which
# must leave the programs in $(HOSTB)/<p>/inst/bin).
# Each step leaves build/state/<p>.<step>; make <p> redoes only what is
# out of date for that package (global rules section 6a).
define PKG_RULES
$(1)_SRC  ?= $(SRC)/$(1)
$(1)_OBJ  ?= $(OBJ)/$(1)
$(1)_HOBJ ?= $(HOSTB)/$(1)
$(1)_ARCHIVE ?= $(DL)/$$(notdir $$($(1)_URL))
$(1)_CONFIGURE_CMD ?= cd $$($(1)_OBJ) && $$(call M68K_ENV,$(1)) $$($(1)_ENV) $$($(1)_SRC)/configure \
	--build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) $$($(1)_CONFIGURE)
$(1)_BUILD_CMD ?= $(MAKE) -C $$($(1)_OBJ) -j$(JOBS)
$(1)_INSTALL_CMD ?= $(MAKE) -C $$($(1)_OBJ) install DESTDIR=$(SYSROOT)
$(1)_HOST_CONFIGURE_CMD ?= cd $$($(1)_HOBJ) && $$($(1)_SRC)/configure --prefix=$$($(1)_HOBJ)/inst \
	$$($(1)_HOST_CONFIGURE)
$(1)_HOST_BUILD_CMD ?= $(MAKE) -C $$($(1)_HOBJ) -j$(JOBS) install

.PHONY: $(1) host-$(1) clean-$(1) $(1)-patches
$(1): $(STATE)/$(1).checked

$(STATE)/$(1).fetched: pkgs/$(1)/recipe.mk
	@mkdir -p $(STATE)
	$$(if $$($(1)_OWN),,$(ROOT)/tools/fetch.sh $$($(1)_URL) $$($(1)_SHA256) $$($(1)_ARCHIVE))
	@touch $$@

$(STATE)/$(1).unpacked: $(STATE)/$(1).fetched $$(wildcard pkgs/$(1)/patches/*.patch) $$(if $$($(1)_OWN),$$(wildcard pkgs/$(1)/src/*))
	$$(if $$($(1)_OWN),rm -rf $$($(1)_SRC) && mkdir -p $$($(1)_SRC) && cp -R $(ROOT)/pkgs/$(1)/src/. $$($(1)_SRC)/, \
		$(ROOT)/tools/unpack.sh $$($(1)_ARCHIVE) $$($(1)_SRC) $(ROOT)/pkgs/$(1)/patches > /dev/null)
	@touch $$@

$(STATE)/$(1).configured: $(STATE)/$(1).unpacked pkgs/$(1)/recipe.mk mk/config.site \
		$$(foreach d,$$($(1)_DEPS),$(STATE)/$$(d).installed)
	rm -rf $$($(1)_OBJ) && mkdir -p $$($(1)_OBJ)
	$$(if $$($(1)_STACK),$(ROOT)/tools/m68k-cc $(CPU) -O2 -DSTACK=$$($(1)_STACK) -c \
		-o $(OBJ)/$(1).stack.o $(ROOT)/tools/stack-cookie.c)
	( $$($(1)_CONFIGURE_CMD) ) > $$($(1)_OBJ)/configure.log 2>&1 || \
		{ tail -25 $$($(1)_OBJ)/configure.log; exit 1; }
	@touch $$@

$(STATE)/$(1).built: $(STATE)/$(1).configured
	( $$($(1)_BUILD_CMD) ) > $$($(1)_OBJ)/make.log 2>&1 || \
		{ grep -E -B3 'error:|undefined reference|\*\*\*' $$($(1)_OBJ)/make.log | head -60; exit 1; }
	@touch $$@

$(STATE)/$(1).installed: $(STATE)/$(1).built
	( $$($(1)_INSTALL_CMD) ) > $$($(1)_OBJ)/install.log 2>&1 || \
		{ tail -25 $$($(1)_OBJ)/install.log; exit 1; }
	$$($(1)_POST_INSTALL)
	@touch $$@

# a library package (no <p>_BINS, e.g. zlib) has no programs to check
$(STATE)/$(1).checked: $(STATE)/$(1).installed tools/check_bin.sh
	$$(if $$($(1)_BINS),$(ROOT)/tools/check_bin.sh $(1) "$$($(1)_STACK)" \
		$$(addprefix $(SYSROOT)$(PREFIX)/,$$($(1)_BINS)),@true)
	@touch $$@

# macOS build of the same source: the expected outputs for the rig checks
host-$(1): $(STATE)/host-$(1).expected
$(STATE)/host-$(1).built: $(STATE)/$(1).unpacked pkgs/$(1)/recipe.mk \
		$$(foreach d,$$($(1)_HOST_DEPS),$(STATE)/host-$$(d).built)
	rm -rf $$($(1)_HOBJ) && mkdir -p $$($(1)_HOBJ)
	( $$($(1)_HOST_CONFIGURE_CMD) ) > $$($(1)_HOBJ)/configure.log 2>&1 || \
		{ tail -25 $$($(1)_HOBJ)/configure.log; exit 1; }
	( $$($(1)_HOST_BUILD_CMD) ) > $$($(1)_HOBJ)/make.log 2>&1 || \
		{ grep -E 'error|Error' $$($(1)_HOBJ)/make.log | head -30; exit 1; }
	@touch $$@
$(STATE)/host-$(1).expected: $(STATE)/host-$(1).built $$(wildcard pkgs/$(1)/check/* pkgs/$(1)/check/keys/*) \
		tools/run-cases.sh tools/run-tty.sh $$(if $$(wildcard pkgs/$(1)/check/tty),$(TOOLS)/ptyrun $(TOOLS)/terminfo/stamp) \
		$$(foreach d,$$($(1)_CHECK_DEPS),$(STATE)/host-$$(d).built)
	$(ROOT)/tools/run-cases.sh "$$(call CHECK_PATH,$(1))" pkgs/$(1)/check $(EXPECT)/$(1)
	$(ROOT)/tools/run-tty.sh "$$(call CHECK_PATH,$(1))" pkgs/$(1)/check $(EXPECT)/$(1)
	@touch $$@

$(1)-patches:
	rm -f pkgs/$(1)/patches/*.patch
	git -C $$($(1)_SRC) format-patch -q -o $(ROOT)/pkgs/$(1)/patches upstream
	ls pkgs/$(1)/patches

clean-$(1):
	rm -rf $$($(1)_SRC) $$($(1)_OBJ) $$($(1)_HOBJ) $(EXPECT)/$(1) $(STATE)/$(1).* $(STATE)/host-$(1).*
endef

# ---- the terminal cases' tools (pkgs/<p>/check/tty) ---------------------------
# ptyrun records what a program draws on a pseudo-terminal: the Mac build for
# the expected outputs, the Amiga one for the rig (vtcon userland_rig.py). The
# Mac's tic compiles vtcon's terminfo for the Mac side.
TOOLS := $(B)/tools
# the macOS ncurses 6 (make host-ncurses) for the screen programs' expected
# outputs: the Mac's own ncurses 5.7 draws other colour sequences
HOST_NCURSES := $(HOSTB)/ncurses/inst
$(TOOLS)/ptyrun: tools/ptyrun.c
	@mkdir -p $(TOOLS)
	cc -Wall -Wno-deprecated-declarations -O2 -o $@ tools/ptyrun.c
$(TOOLS)/ptyrun.amiga: tools/ptyrun.c $(STATE)/ixcompat.installed
	@mkdir -p $(TOOLS)
	$(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -I$(SYSINC) -o $@ tools/ptyrun.c $(SYSLIB)/libixcompat.a
$(TOOLS)/terminfo/stamp: $(VTCON)/terminfo/vtcon.terminfo
	rm -rf $(TOOLS)/terminfo && mkdir -p $(TOOLS)/terminfo
	/usr/bin/tic -x -o $(TOOLS)/terminfo $(VTCON)/terminfo/vtcon.terminfo
	@touch $@
.PHONY: tty-tools
tty-tools: $(TOOLS)/ptyrun $(TOOLS)/ptyrun.amiga $(TOOLS)/terminfo/stamp
