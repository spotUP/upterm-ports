# UP-Term Unix tool ports for AmigaOS 3.x + ixemul-vtcon (vtcon plan
# thoughts/shared/plans/2026-10-04-unix-tool-ports.md). Commands: RULES.md.
# GNU make; runs with Apple's 3.81 and with gmake.

.DEFAULT_GOAL := help
include mk/common.mk

PKGS := $(sort $(patsubst pkgs/%/recipe.mk,%,$(wildcard pkgs/*/recipe.mk)))
include $(foreach p,$(PKGS),pkgs/$(p)/recipe.mk)
$(foreach p,$(PKGS),$(if $($(p)_LOCAL),,$(eval $(call PKG_RULES,$(p)))))

.PHONY: help sysroot kit-stage sizes clean test
help:
	@echo "make <pkg>        build, install into build/sysroot, check_bin (one package)"
	@echo "make host-<pkg>   macOS build of the same source + expected outputs"
	@echo "make sysroot      the libraries the tools build against"
	@echo "make kit-stage    build/kit/userland: checked programs + SOURCES.txt"
	@echo "make test         host tests of the build tools"
	@echo "make clean-<pkg>  forget one package (sources, objects, stamps)"
	@echo "packages: $(PKGS)"

sysroot: ixcompat ncurses

# host tests of the build tools (m68k_scan.py's flow rules)
test:
	python3 tools/test_m68k_scan.py
	sh tools/test_recipe_var.sh
	cc -Wall -Wextra -o build/test_chrome pkgs/upkg-ui/src/test_chrome.c pkgs/upkg-ui/src/chrome.c && build/test_chrome

sizes:
	@column -t $(STATE)/sizes.tsv

# build/kit/userland (programs, pages, data, licences, SOURCES.txt) and
# build/kit/userland-src (the corresponding source): tools/kit-stage.sh
kit-stage:
	ROOT=$(ROOT) B=$(B) STATE=$(STATE) SYSROOT=$(SYSROOT) PREFIX=$(PREFIX) SRC=$(SRC) \
	IXEMUL=$(IXEMUL) PKGS="$(PKGS)" sh tools/kit-stage.sh
# print-<variable>: the value of exactly that variable (print-upkg-ui_OWN), as
# tools/recipe-var.sh reads it; a package name may hold a "-"
print-%:
	@printf '%s\n' '$($*)'

clean:
	rm -rf $(OBJ) $(HOSTB) $(STATE) $(EXPECT) $(SYSROOT) $(SRC) $(B)/kit
