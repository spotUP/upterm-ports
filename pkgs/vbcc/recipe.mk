# vbcc 0.9h patch2 for AmigaOS 68k, native: the author's ready-made binaries (Volker
# Barthelmann, Frank Wille), no build from source (owner decision 2026-10-26). Two lha
# archives, installed UNMODIFIED (their licence: "may be redistributed without
# modifications"): the unpacked trees are merged into one drawer, our own files
# (config/upterm68k, startup lines, README) sit next to them. mk/common.mk's
# <p>_LHA_URLS mode does fetch + unpack; the steps below only place the files.
# The Amiga NDK is NOT part of it (no redistribution licence found): the cfg reads the
# headers from the NDKINC: assign the owner points at an Include_H drawer.
vbcc_VERSION   := 0.9h-patch2
vbcc_LHA_URLS  := http://phoenix.owl.de/vbcc/current/vbcc_bin_amigaos68k.lha \
	http://phoenix.owl.de/vbcc/current/vbcc_target_m68k-amigaos.lha
vbcc_LHA_SHA256S := 0a75cf9da15d1613554e43b09c6db59e0a05d945e358f1b95d5b32d9c637b7be \
	ec734d7115359cdb5d1c70349284ecbd5712ef47e8bc28d4150117c6f8c73289
vbcc_LICENSE   := vbcc, vasm, vlink: redistributable unmodified, non-commercial use (commercial use of m68k AmigaOS output allowed)
vbcc_DEPS      :=
# kit-stage copies the whole drawer (vtcon: dist/slim.txt makes it the up-vbcc add-on, not part of the base)
vbcc_DRAWER    := vbcc
vbcc_LICENSE_FILES := README.md
vbcc_DIR       := $(SYSROOT)$(PREFIX)/vbcc
vbcc_CONFIGURE_CMD = mkdir -p $(vbcc_OBJ)
vbcc_BUILD_CMD = sed 's|@VBCC_PREFIX@/|VBCC:|g; s|@NDKINC@|NDKINC:|g' $(ROOT)/pkgs/vbcc/files/upterm68k.cfg.in > $(vbcc_OBJ)/upterm68k
vbcc_INSTALL_CMD = rm -rf $(vbcc_DIR) && mkdir -p $(vbcc_DIR) && \
	cp -R $(vbcc_SRC)/vbcc_bin_amigaos68k/vbcc_bin_amigaos68k/. $(vbcc_DIR)/ && \
	cp -R $(vbcc_SRC)/vbcc_target_m68k-amigaos/vbcc_target_m68k-amigaos/. $(vbcc_DIR)/ && \
	chmod 755 $(vbcc_DIR)/bin/* && \
	cp $(vbcc_OBJ)/upterm68k $(vbcc_DIR)/config/upterm68k && \
	cp $(ROOT)/pkgs/vbcc/files/startup.txt $(ROOT)/pkgs/vbcc/README.md $(vbcc_DIR)/ && \
	test -f $(vbcc_DIR)/bin/vc && test -f $(vbcc_DIR)/targets/m68k-amigaos/lib/startup.o
