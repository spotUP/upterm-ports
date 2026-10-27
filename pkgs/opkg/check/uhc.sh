#!/bin/sh
# uhc.sh UPKG: host check of patches/0044: libopkg/upkg_uhc.c, the reader of the UHC catalogue drawer (script <n> with
# PKGVERSION, <n>.desc, Installed/<n>). uhc_test.c includes upkg_uhc.c and reads the fixture drawer check/uhc/Packages
# (real scripts from the up-uhc archive). Needs the patched source (build/src/opkg) next to the host build.
#   sh pkgs/opkg/check/uhc.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
build=$(cd "$(dirname "$upkg")/../../../.." && pwd)
src=$build/src/opkg
hobj=$build/host/opkg
w=$(mktemp -d "${TMPDIR:-/tmp}/uhc.XXXXXX")
trap 'rm -rf "$w"' EXIT
[ -f "$src/libopkg/upkg_uhc.c" ] || { echo "[FAIL] uhc: $src/libopkg/upkg_uhc.c does not exist"; exit 1; }
cc -O1 -g -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined -I"$src/libopkg" -I"$src/src" -I"$hobj" \
  -o "$w/uhc_test" "$here/uhc_test.c" 2> "$w/cc.err" || { cat "$w/cc.err"; echo "[FAIL] uhc_test.c does not build"; exit 1; }
"$w/uhc_test" "$here/uhc/Packages" "$w/scratch"
