#!/bin/sh
# wrap_split.sh UPKG [SRCDIR HOSTBUILDDIR]: host check that a word printed by two or more upkg print
# calls is wrapped as one word (patches/0009), also when the last piece comes with no newline
# (flushed at exit). On a 40 column pty the break would fall inside "abcdef"; the word must move
# whole to the next line and no line is wider than 39.
#   sh pkgs/opkg/check/wrap_split.sh build/host/opkg/inst/bin/upkg
# (SRCDIR and HOSTBUILDDIR default to build/src/opkg and build/host/opkg next to UPKG's build tree.)
set -eu
bld=${3:-$(cd "$(dirname "$1")/../.." && pwd)}
src=${2:-$bld/../../src/opkg}
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/wrapsplit.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -Wall -O2 -I"$bld" -I"$src/libopkg" -o "$w/ptyrun" "$here/../../../tools/ptyrun.c" 2>"$w/cc.err" || { echo "[FAIL] ptyrun: $(cat "$w/cc.err")"; exit 1; }
cc -Wall -O2 -I"$bld" -I"$src/libopkg" -o "$w/drv" "$here/wrap_split.c" "$src/libopkg/upkg_wrap.c" 2>"$w/cc.err" || { echo "[FAIL] driver: $(cat "$w/cc.err")"; exit 1; }
: > "$w/keys"
"$w/ptyrun" -s 40x24 "$w/keys" "$w/out" "$w/drv" >/dev/null
tr -d '\r' < "$w/out" > "$w/t"
grep -q '^ *abcdef and' "$w/t" || { echo "[FAIL] abc+def was split between two lines: $(cat "$w/t")"; exit 1; }
grep -q '^ *abcdef$' "$w/t" || { echo "[FAIL] abc+d+ef was split or lost at exit: $(cat "$w/t")"; exit 1; }
m=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$w/t")
[ "$m" -le 39 ] || { echo "[FAIL] a line of $m columns on a 40 column pty"; exit 1; }
echo "[OK] a word printed by several calls wraps whole, longest line $m columns"
