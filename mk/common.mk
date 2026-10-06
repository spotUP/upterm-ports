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
PREFIX  := /SYS/UP-Term
SYSINC  := $(SYSROOT)$(PREFIX)/include
SYSLIB  := $(SYSROOT)$(PREFIX)/lib

# 68020, soft float (the kit's coreutils; an A1200 without an FPU runs it).
CPU     ?= -m68020
# The Mac overheats: never more than 4 jobs.
JOBS    ?= 4
ifeq ($(shell [ $(JOBS) -le 4 ] && echo ok),)
$(error JOBS=$(JOBS): at most 4 parallel jobs on this machine)
endif

# $(call M68K_ENV,<pkg>): the cross environment for configure.
# libixcompat goes in by its path: with -mcrt=ixemul the gcc driver puts the
# SDK's -L directories before ours, so -lixcompat would find the toolchain's
# old copy in ixemul/lib, not the sysroot's (measured 2026-10-04 with -Map).
M68K_ENV = CONFIG_SITE=$(ROOT)/mk/config.site \
	CC="$(ROOT)/tools/m68k-cc" CPP="$(ROOT)/tools/m68k-cc -E" \
	AR=$(CROSS)ar RANLIB=$(CROSS)ranlib STRIP=$(CROSS)strip NM=$(CROSS)nm \
	CFLAGS="$(CPU) -O2" CPPFLAGS="-I$(SYSINC)" LDFLAGS="-L$(SYSLIB)" \
	LIBS="$($(1)_LIBS) $(if $($(1)_STACK),$(OBJ)/$(1).stack.o) $(SYSLIB)/libixcompat.a" PKG_CONFIG=false
BUILD_TRIPLE := $(shell sh $(ROOT)/tools/build-triple.sh)

# ---- the recipe driver --------------------------------------------------------
# A package <p> is pkgs/<p>/recipe.mk. It sets:
#   <p>_VERSION, <p>_URL, <p>_SHA256   the upstream archive (sha256-verified)
#   <p>_DEPS        packages whose install it builds against (stamps)
#   <p>_CONFIGURE   extra configure arguments for the m68k build
#   <p>_HOST_CONFIGURE  same for the macOS build (expected outputs)
#   <p>_BINS        installed programs to check, relative to $(SYSROOT)$(PREFIX)
#   <p>_STACK       the $STACK: cookie the programs must carry (empty: none)
#   <p>_LIBS        extra libraries before -lixcompat
#   <p>_LICENSE     for SOURCES.txt
#   <p>_POST_INSTALL  shell run after make install (optional)
# and may replace a step: <p>_CONFIGURE_CMD, <p>_BUILD_CMD, <p>_INSTALL_CMD.
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

.PHONY: $(1) host-$(1) clean-$(1) $(1)-patches
$(1): $(STATE)/$(1).checked

$(STATE)/$(1).fetched: pkgs/$(1)/recipe.mk
	@mkdir -p $(STATE)
	$(ROOT)/tools/fetch.sh $$($(1)_URL) $$($(1)_SHA256) $$($(1)_ARCHIVE)
	@touch $$@

$(STATE)/$(1).unpacked: $(STATE)/$(1).fetched $$(wildcard pkgs/$(1)/patches/*.patch)
	$(ROOT)/tools/unpack.sh $$($(1)_ARCHIVE) $$($(1)_SRC) $(ROOT)/pkgs/$(1)/patches > /dev/null
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

$(STATE)/$(1).checked: $(STATE)/$(1).installed tools/check_bin.sh
	$(ROOT)/tools/check_bin.sh $(1) "$$($(1)_STACK)" \
		$$(addprefix $(SYSROOT)$(PREFIX)/,$$($(1)_BINS))
	@touch $$@

# macOS build of the same source: the expected outputs for the rig checks
host-$(1): $(STATE)/host-$(1).expected
$(STATE)/host-$(1).built: $(STATE)/$(1).unpacked pkgs/$(1)/recipe.mk
	rm -rf $$($(1)_HOBJ) && mkdir -p $$($(1)_HOBJ)
	( cd $$($(1)_HOBJ) && $$($(1)_SRC)/configure --prefix=$$($(1)_HOBJ)/inst \
		$$($(1)_HOST_CONFIGURE) ) > $$($(1)_HOBJ)/configure.log 2>&1 || \
		{ tail -25 $$($(1)_HOBJ)/configure.log; exit 1; }
	$(MAKE) -C $$($(1)_HOBJ) -j$(JOBS) install > $$($(1)_HOBJ)/make.log 2>&1 || \
		{ grep -E 'error|Error' $$($(1)_HOBJ)/make.log | head -30; exit 1; }
	@touch $$@
$(STATE)/host-$(1).expected: $(STATE)/host-$(1).built $$(wildcard pkgs/$(1)/check/*) tools/run-cases.sh
	$(ROOT)/tools/run-cases.sh $$($(1)_HOBJ)/inst/bin pkgs/$(1)/check $(EXPECT)/$(1)
	@touch $$@

$(1)-patches:
	rm -f pkgs/$(1)/patches/*.patch
	git -C $$($(1)_SRC) format-patch -q -o $(ROOT)/pkgs/$(1)/patches upstream
	ls pkgs/$(1)/patches

clean-$(1):
	rm -rf $$($(1)_SRC) $$($(1)_OBJ) $$($(1)_HOBJ) $(EXPECT)/$(1) $(STATE)/$(1).* $(STATE)/host-$(1).*
endef
