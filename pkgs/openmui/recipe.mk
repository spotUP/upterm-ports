# OpenMUI 1.0 for AmigaOS 3.1+, native: Tobias Karlsson's free MUI replacement
# (muimaster.library, no keyfile), the author's release archive, installed UNMODIFIED.
# It already carries UP-MCC 1.0 (up-mcc.library, UP-*.mcc, Inter font, Dark/Light
# themes). mk/common.mk's <p>_LHA_URLS mode does fetch + unpack; the steps below only
# place the drawer. The licences ask that the notices and the source travel with the
# binaries: LICENSE, ReadMe and Source.tar.gz stay in the drawer.
# Default look: Themes/OpenMUI/<theme>.prefs (theme2prefs.py, from the UP-MCC theme files) is a
# ready global.prefs with rounded frames; Themes/OpenMUI/UseTheme makes the prefs drawers and
# copies the active one to ENVARC:OpenMUI/ and ENV:OpenMUI/ (kit: run it at install).
# shortcut: prebuilt payload, a source build needs -std=gnu17 (our gcc is 6.5), a host
# FlexCat and the thebar submodule; upgrade when we patch OpenMUI itself (README.md).
openmui_VERSION   := 1.0
openmui_LHA_URLS  := https://github.com/creep-ltx/openmui/releases/download/v1.0/up-opmui.lha
openmui_LHA_SHA256S := 3fe44bca5aa1d34eb56048b870bf7c20074f918091a25315782eb3c9a68a28e5
openmui_LICENSE   := AROS Public License 1.1 (core); bundled classes LGPL 2.1 and others (see LICENSE in the drawer); UP-MCC MIT, Lucide ISC, Inter OFL 1.1
openmui_DEPS      :=
# kit-stage copies <p>_BINS and licences from a source tree; a prebuilt drawer is not that shape yet
openmui_NO_KIT    := 1
openmui_DIR       := $(SYSROOT)$(PREFIX)/openmui
openmui_PAYLOAD   = $(openmui_SRC)/up-opmui/UP-OPMUI/OpenMUI
openmui_CONFIGURE_CMD = test -f $(openmui_PAYLOAD)/Libs/muimaster.library
openmui_BUILD_CMD = true
openmui_INSTALL_CMD = rm -rf $(openmui_DIR) && mkdir -p $(openmui_DIR) && \
	cp -R $(openmui_PAYLOAD)/. $(openmui_DIR)/ && \
	cp $(ROOT)/pkgs/openmui/README.md $(openmui_DIR)/README.upkg.md && \
	test -f $(openmui_DIR)/Libs/muimaster.library && test -f $(openmui_DIR)/Libs/up-mcc.library && \
	test -f $(openmui_DIR)/Libs/MUI/UP-Button.mcc && test -f $(openmui_DIR)/Prefs/OpenMUI && \
	test -f $(openmui_DIR)/LICENSE && test -f $(openmui_DIR)/Source.tar.gz && \
	mkdir -p $(openmui_DIR)/Themes/OpenMUI && for t in Dark Light; do \
	python3 $(ROOT)/pkgs/openmui/theme2prefs.py $(openmui_DIR)/Themes/UP-MCC/$$t.theme \
	> $(openmui_DIR)/Themes/OpenMUI/$$t.prefs || exit 1; done && \
	python3 $(ROOT)/pkgs/openmui/test_theme2prefs.py && \
	cp $(ROOT)/pkgs/openmui/UseTheme $(openmui_DIR)/Themes/OpenMUI/UseTheme
