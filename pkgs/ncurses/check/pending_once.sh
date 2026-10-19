#!/bin/sh
# pending_once.sh NCURSES: host check for one typeahead check at the start of doupdate (patches/0006).
# pending_once.c is built against the host libncursesw.a (same patched source as the m68k build);
# the check fails when that patch is reverted.
#   sh pkgs/ncurses/check/pending_once.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=${TMPDIR:-/tmp}/ncurses-pending_once.$$
mkdir -p "$w"
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" -o "$w/pending_once" "$here/pending_once.c" "$inst/lib/libncursesw.a" || { echo "[FAIL] pending_once did not build"; exit 1; }
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$term TERMINFO=$ti "$w/pending_once" 2>&1 < /dev/null) && rc=0 || rc=$?
if [ "$rc" = 0 ]; then echo "[OK] ncurses pending_once ($out)"; else echo "[FAIL] ncurses pending_once: $out"; exit 1; fi
