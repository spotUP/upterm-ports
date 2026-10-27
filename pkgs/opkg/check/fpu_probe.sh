#!/bin/sh
# fpu_probe.sh UPKG: host check of patches/0056: upkg registers architecture m68k-amigaos-fpu at priority 20 when SysBase->AttnFlags
# (here $UPKG_ATTN_FLAGS) has an FPU flag and a 68040 or 68060; m68k-amigaos keeps priority 10; a 68030 with a 68882 gets no fpu arch.
# fpu_probe_test.c runs the pure decision over faked flags. Needs the patched source (build/src/opkg) next to the host build.
#   sh pkgs/opkg/check/fpu_probe.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
build=$(cd "$(dirname "$upkg")/../../../.." && pwd)
src=$build/src/opkg
w=$(mktemp -d "${TMPDIR:-/tmp}/fpuprobe.XXXXXX")
trap 'rm -rf "$w"' EXIT
fail() { echo "[FAIL] fpu_probe: $*"; exit 1; }
[ -f "$src/libopkg/upkg_cpu.c" ] || fail "$src/libopkg/upkg_cpu.c does not exist"
cc -O1 -g -Wall -Wextra -fsanitize=address,undefined -I"$src/libopkg" -o "$w/t" "$here/fpu_probe_test.c" 2> "$w/cc.err" || { cat "$w/cc.err"; fail "fpu_probe_test.c does not build"; }
"$w/t"

{ echo "arch m68k-amigaos 10"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
arches() { UPKG_ATTN_FLAGS=$1 "$upkg" -f "$w/conf" print-architecture; }
# 060 (bits 0-3 for the lower CPUs, 3 = 040, 7 = 060) + FPU40 (bit 6)
a=$(arches 0xff)
echo "$a" | grep -qx 'arch m68k-amigaos-fpu 20' || fail "060 + FPU40: no 'arch m68k-amigaos-fpu 20' in: $(echo $a)"
echo "$a" | grep -qx 'arch m68k-amigaos 10' || fail "060 + FPU40: 'arch m68k-amigaos 10' missing"
# 030 + 68882 (bits 0-2 and 4-5)
a=$(arches 0x37)
echo "$a" | grep -q 'fpu' && fail "030 + 68882 got the fpu arch: $(echo $a)"
a=$(arches 0)
echo "$a" | grep -q 'fpu' && fail "no flags got the fpu arch"
echo "[OK] fpu_probe: 060 + FPU40 lists m68k-amigaos-fpu 20 and m68k-amigaos 10; 030 + 68882 and a bare 020 list no fpu arch"
