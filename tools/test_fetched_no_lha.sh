#!/bin/sh
# test_fetched_no_lha.sh: the .fetched rule of a package without LHA URLs runs no LHA fetch.
# It looped over `seq 1 <number of URLs>`; with no URLs that is `seq 1 0`, which BSD seq (macOS)
# answers with "1 0", so fetch.sh ran with empty arguments. Run with the system make (3.81 on macOS).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
fail() { echo "test_fetched_no_lha: $*" >&2; exit 1; }
p=fzy
rm -f "$ROOT/build/state/$p.fetched"
mkdir -p build/dl
out=$(make -n "$ROOT/build/state/$p.fetched" 2>&1) || fail "make -n failed: $out"
n=$(printf '%s\n' "$out" | grep -c 'tools/fetch.sh' || true)
[ "$n" -eq 1 ] || fail "expected exactly 1 fetch.sh call for $p (the source archive), got $n: $out"
# a package with LHA URLs: one fetch per URL, each with its own sha
lp=$(grep -l '_LHA_URLS' pkgs/*/recipe.mk | head -1 | xargs dirname | xargs basename)
urls=$(make -s print-${lp}_LHA_URLS | wc -w | tr -d ' ')
rm -f "$ROOT/build/state/$lp.fetched"
n=$(make -n "$ROOT/build/state/$lp.fetched" 2>&1 | grep -o 'tools/fetch.sh' | wc -l | tr -d ' ')
[ "$n" -eq "$urls" ] || fail "$lp: expected $urls fetch.sh calls, got $n"
echo "test_fetched_no_lha: ok"
