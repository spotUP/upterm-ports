#!/bin/sh
# rows.sh UPKG: host check of patches/0029: libopkg/upkg_rows.c, the one parser of the four browse lists and
# the one runner of install/remove/upgrade, shared by `upkg browse` and the Workbench window. rows_test.c includes
# upkg_rows.c over stubs and feeds it fixture lists; the check also fails when `upkg browse` still carries a
# parser of its own (two parsers drift apart). Needs the patched source (build/src/opkg) next to the host build.
#   sh pkgs/opkg/check/rows.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
build=$(cd "$(dirname "$upkg")/../../../.." && pwd)
src=$build/src/opkg
hobj=$build/host/opkg
w=$(mktemp -d "${TMPDIR:-/tmp}/rows.XXXXXX")
trap 'rm -rf "$w"' EXIT
[ -f "$src/libopkg/upkg_rows.c" ] || { echo "[FAIL] rows: $src/libopkg/upkg_rows.c does not exist"; exit 1; }
cc -O1 -g -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined -I"$here" -I"$src/libopkg" -I"$src/src" -I"$hobj" \
  -o "$w/rows_test" "$here/rows_test.c" 2> "$w/cc.err" || { cat "$w/cc.err"; echo "[FAIL] rows_test.c does not build"; exit 1; }
"$w/rows_test"
# one parser: browse keeps no list text of its own
if grep -n 'after_name\|find_name\|lines_set\|upkg_browse_list' "$src/libopkg/upkg_browse.c"; then
  echo "[FAIL] rows: upkg_browse.c still parses the lists itself"; exit 1
fi
grep -q 'upkg_rows_load' "$src/libopkg/upkg_browse.c" || { echo "[FAIL] rows: upkg_browse.c does not use upkg_rows_load"; exit 1; }
grep -q 'upkg_rows_run' "$src/libopkg/upkg_browse.c" || { echo "[FAIL] rows: upkg_browse.c does not use upkg_rows_run"; exit 1; }
echo "[OK] rows: upkg browse uses upkg_rows_load and upkg_rows_run, no parser of its own"
