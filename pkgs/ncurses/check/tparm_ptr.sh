#!/bin/sh
# tparm_ptr.sh NCURSES: host check for the tparm format lookup cache keyed by capability address (patches/0003).
# tparm_ptr.c is built against the host libncursesw.a (same patched source as the m68k build);
# the check fails when that patch is reverted.
#   sh pkgs/ncurses/check/tparm_ptr.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=${TMPDIR:-/tmp}/ncurses-tparm_ptr.$$
mkdir -p "$w"
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" -o "$w/tparm_ptr" "$here/tparm_ptr.c" "$inst/lib/libncursesw.a" || { echo "[FAIL] tparm_ptr did not build"; exit 1; }
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$term TERMINFO=$ti "$w/tparm_ptr" 2>&1 < /dev/null) && rc=0 || rc=$?
if [ "$rc" = 0 ]; then echo "[OK] ncurses tparm_ptr ($out)"; else echo "[FAIL] ncurses tparm_ptr: $out"; exit 1; fi
