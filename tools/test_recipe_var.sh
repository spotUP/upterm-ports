#!/bin/sh
# test_recipe_var.sh: every recipe's <p>_VERSION reads back through var (tools/recipe-var.sh), the
# lookup kit-stage.sh makes for OWN, NO_KIT and LICENSE_FILES. A package name with a "-" (upkg-ui)
# read as empty: kit-stage then missed upkg-ui_OWN and asked for a licence file.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/recipe-var.sh"
bad=0
for p in $(make -s -C "$ROOT" print-PKGS); do
	[ -n "$(var "$p" VERSION)" ] || { echo "test_recipe_var: $p: ${p}_VERSION reads empty" >&2; bad=1; }
done
# A "#" in a recipe variable starts a make comment unless written "\#": git's install line was cut
# at '#!/bin/sh' and the shell failed on the open quote, so the helper scripts were never written.
case "$(var git INSTALL_CMD)" in
	*'#!/bin/sh'*'chmod 755'*) ;;
	*) echo "test_recipe_var: git_INSTALL_CMD is cut short (unescaped # in pkgs/git/recipe.mk)" >&2; bad=1 ;;
esac
# A prebuilt package (<p>_LHA_URLS: ready-made Amiga binaries, no source) has no macOS build, so
# make host-<p> cannot write expected outputs. check/cases or check/tty put vbcc in the userland
# sweep (vtcon tools/rig/userland_rig.py), which then asked for make host-vbcc, and that failed on
# "build/src/vbcc/configure: No such file or directory". Its rig check is its own script.
for p in $(make -s -C "$ROOT" print-PKGS); do
	[ -n "$(var "$p" LHA_URLS)" ] || continue
	for f in cases tty; do
		[ ! -e "$ROOT/pkgs/$p/check/$f" ] || { echo "test_recipe_var: $p: prebuilt (${p}_LHA_URLS) but has check/$f, which needs a host build" >&2; bad=1; }
	done
done
[ "$(var upkg-ui OWN)" = 1 ] || { echo "test_recipe_var: upkg-ui_OWN is not 1" >&2; bad=1; }
[ $bad = 0 ] && echo "test_recipe_var: ok"
exit $bad
