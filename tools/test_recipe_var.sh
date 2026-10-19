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
[ "$(var upkg-ui OWN)" = 1 ] || { echo "test_recipe_var: upkg-ui_OWN is not 1" >&2; bad=1; }
[ $bad = 0 ] && echo "test_recipe_var: ok"
exit $bad
