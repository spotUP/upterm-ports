#!/bin/sh
# vidmemo.sh NCURSES: host check for the vid_puts attribute memo (patches/0004): same bytes as the real code, hits on repeats, flushed by init_pair.
# vidmemo.c is built against the host libncursesw.a (same patched source as the m68k build);
# the check fails when that patch is reverted.
#   sh pkgs/ncurses/check/vidmemo.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=${TMPDIR:-/tmp}/ncurses-vidmemo.$$
mkdir -p "$w"
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" -o "$w/vidmemo" "$here/vidmemo.c" "$inst/lib/libncursesw.a" || { echo "[FAIL] vidmemo did not build"; exit 1; }
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$term TERMINFO=$ti "$w/vidmemo" 2>&1 < /dev/null) && rc=0 || rc=$?
if [ "$rc" = 0 ]; then echo "[OK] ncurses vidmemo ($out)"; else echo "[FAIL] ncurses vidmemo: $out"; exit 1; fi
