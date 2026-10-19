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
[ "$(var upkg-ui OWN)" = 1 ] || { echo "test_recipe_var: upkg-ui_OWN is not 1" >&2; bad=1; }
[ $bad = 0 ] && echo "test_recipe_var: ok"
exit $bad
