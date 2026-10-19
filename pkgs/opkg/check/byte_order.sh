#!/bin/sh
# byte_order.sh UPKG: host check that the m68k (big-endian) build's config.h defines WORDS_BIGENDIAN
# and the host (little-endian) build's does not. libopkg/sha256.c picks its byte swap with
# #ifdef WORDS_BIGENDIAN; the CMake config.h.in lacked it, so on the Amiga SHA256 swapped every word
# and every downloaded ipk failed its checksum ("Removing corrupt package file").
# The m68k config.h is read from the cross build (build/obj/opkg), next to the host one (build/host/opkg).
#   sh pkgs/opkg/check/byte_order.sh build/host/opkg/inst/bin/upkg
set -eu
hobj=$(cd "$(dirname "$1")/../.." && pwd)
cross=$(cd "$hobj/../../obj/opkg" 2>/dev/null && pwd) || { echo "[FAIL] no cross build dir next to $hobj (run make opkg)"; exit 1; }
[ -f "$cross/config.h" ] || { echo "[FAIL] $cross/config.h missing (run make opkg)"; exit 1; }
[ -f "$hobj/config.h" ] || { echo "[FAIL] $hobj/config.h missing"; exit 1; }
grep -q '^#define WORDS_BIGENDIAN' "$cross/config.h" || { echo "[FAIL] m68k config.h does not define WORDS_BIGENDIAN: sha256 would byte-swap"; exit 1; }
if grep -q '^#define WORDS_BIGENDIAN' "$hobj/config.h"; then echo "[FAIL] host config.h defines WORDS_BIGENDIAN on a little-endian host"; exit 1; fi
echo "[OK] opkg byte order: m68k config.h defines WORDS_BIGENDIAN, host config.h does not"
