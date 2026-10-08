# UP-Term Unix tool ports for AmigaOS 3.x + ixemul-vtcon (vtcon plan
# thoughts/shared/plans/2026-10-04-unix-tool-ports.md). Commands: RULES.md.
# GNU make; runs with Apple's 3.81 and with gmake.

.DEFAULT_GOAL := help
include mk/common.mk

PKGS := $(sort $(patsubst pkgs/%/recipe.mk,%,$(wildcard pkgs/*/recipe.mk)))
include $(foreach p,$(PKGS),pkgs/$(p)/recipe.mk)
$(foreach p,$(PKGS),$(if $($(p)_LOCAL),,$(eval $(call PKG_RULES,$(p)))))

.PHONY: help sysroot kit-stage sizes clean
help:
	@echo "make <pkg>        build, install into build/sysroot, check_bin (one package)"
	@echo "make host-<pkg>   macOS build of the same source + expected outputs"
	@echo "make sysroot      the libraries the tools build against"
	@echo "make kit-stage    build/kit/userland: checked programs + SOURCES.txt"
	@echo "make clean-<pkg>  forget one package (sources, objects, stamps)"
	@echo "packages: $(PKGS)"

sysroot: ixcompat ncurses

sizes:
	@column -t $(STATE)/sizes.tsv

# build/kit/userland (programs, pages, data, licences, SOURCES.txt) and
# build/kit/userland-src (the corresponding source): tools/kit-stage.sh
kit-stage:
	ROOT=$(ROOT) B=$(B) STATE=$(STATE) SYSROOT=$(SYSROOT) PREFIX=$(PREFIX) SRC=$(SRC) \
	IXEMUL=$(IXEMUL) PKGS="$(PKGS)" sh tools/kit-stage.sh
print-%:
	@printf '%s\n' '$($(subst -,_,$(patsubst print-%,%,$@)))'

clean:
	rm -rf $(OBJ) $(HOSTB) $(STATE) $(EXPECT) $(SYSROOT) $(SRC) $(B)/kit
