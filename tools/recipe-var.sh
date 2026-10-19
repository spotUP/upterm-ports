# recipe-var.sh: var P FIELD prints recipe variable <P>_<FIELD> (empty when unset), through the
# Makefile's print-% rule. Sourced by kit-stage.sh and test_recipe_var.sh; needs ROOT.
var() { make -s -C "$ROOT" "print-$1_$2"; }
