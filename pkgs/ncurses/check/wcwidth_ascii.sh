#!/bin/sh
# wcwidth_ascii.sh NCURSES: host check for no wcwidth call per ASCII cell (patches/0007).
# wcwidth_ascii.c is built against the host libncursesw.a (same patched source as the m68k build);
# the check fails when that patch is reverted.
#   sh pkgs/ncurses/check/wcwidth_ascii.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=${TMPDIR:-/tmp}/ncurses-wcwidth_ascii.$$
mkdir -p "$w"
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" -o "$w/wcwidth_ascii" "$here/wcwidth_ascii.c" "$inst/lib/libncursesw.a" || { echo "[FAIL] wcwidth_ascii did not build"; exit 1; }
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$term TERMINFO=$ti "$w/wcwidth_ascii" 2>&1 < /dev/null) && rc=0 || rc=$?
if [ "$rc" = 0 ]; then echo "[OK] ncurses wcwidth_ascii ($out)"; else echo "[FAIL] ncurses wcwidth_ascii: $out"; exit 1; fi
