#!/bin/sh
# tiparm with the per-format result memo returns the right text for repeated and
# new parameter tuples. Usage: tparm_memo.sh <inst>/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
tmp=${TMPDIR:-/tmp}/ncurses-tparm-memo.$$
trap 'rm -f "$tmp"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" -o "$tmp" "$here/tparm_memo.c" "$inst/lib/libncursesw.a"
if "$tmp"; then
    exit 0
fi
echo "[FAIL] tparm_memo failed"
exit 1
