#!/bin/sh
# uhc_run.sh UPKG: host check of patches/0044 (the U4 install runner and the U5 remove parser of libopkg/upkg_uhc.c).
# uhc_run_test.c includes upkg_uhc.c over a recording xsystem stub and parses EVERY script of the up-uhc archive
# (check/uhc/all, 11 files). Needs the patched source (build/src/opkg) next to the host build.
#   sh pkgs/opkg/check/uhc_run.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
build=$(cd "$(dirname "$upkg")/../../../.." && pwd)
src=$build/src/opkg
hobj=$build/host/opkg
w=$(mktemp -d "${TMPDIR:-/tmp}/uhcrun.XXXXXX")
trap 'rm -rf "$w"' EXIT
[ -f "$src/libopkg/upkg_uhc.c" ] || { echo "[FAIL] uhc_run: $src/libopkg/upkg_uhc.c does not exist"; exit 1; }
cc -O1 -g -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined \
  -I"$src/libopkg" -I"$src/src" -I"$hobj" -o "$w/uhc_run_test" "$here/uhc_run_test.c" 2> "$w/cc.err" \
  || { cat "$w/cc.err"; echo "[FAIL] uhc_run_test.c does not build"; exit 1; }
"$w/uhc_run_test" "$here/uhc/all" "$w/scratch"
