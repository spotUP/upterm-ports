#!/bin/sh
# no_requesters.sh UPKG: host check for patches/0026 (upkg sets pr_WindowPtr to -1).
# A full or absent volume makes DOS open a requester that takes the keys and blocks the writer (rig 4,
# 2026-10-22: a browse install on a full System: froze). pr_WindowPtr is Amiga-only, so the host sees two
# things: the slot write upkg_window_ptr_off stores -1, and upkg's main calls upkg_no_requesters before it
# opens the config (its first disk access). The Amiga proof is the rig case (a volume that is not there):
# vtcon tools/rig/upkg_browse_extra_rig.py, step "no requester".
#   sh pkgs/opkg/check/no_requesters.sh build/host/opkg/inst/bin/upkg
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$here/../../../build/src/opkg" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/norequest.XXXXXX")
trap 'rm -rf "$w"' EXIT
cat > "$w/t.c" <<'C'
#include <stdio.h>
#include <stdarg.h>
#include "upkg_wrap.h"
int main(void)
{
    void *slot = NULL;
    upkg_window_ptr_off(&slot);
    if (slot != (void *) -1) { puts("slot not -1"); return 1; }
    return 0;
}
C
# the declaration must exist too (a prototype of upkg_no_requesters is looked up by name)
grep -q 'void upkg_no_requesters(void);' "$src/libopkg/upkg_wrap.h" || { echo "[FAIL] upkg_wrap.h does not declare upkg_no_requesters"; exit 1; }
cc -I"$src/libopkg" -o "$w/t" "$w/t.c" 2>"$w/err" || { echo "[FAIL] upkg_wrap.h has no upkg_window_ptr_off/upkg_no_requesters: $(head -3 "$w/err")"; exit 1; }
"$w/t" || { echo "[FAIL] upkg_window_ptr_off did not store -1"; exit 1; }
# the call in main comes before opkg_conf_init
awk '/^int main\(/ {m=1} m && /upkg_no_requesters\(\);/ {a=NR} m && /opkg_conf_init\(\)/ && !b {b=NR} END {exit !(a && b && a < b)}' "$src/src/opkg.c" \
  || { echo "[FAIL] main does not call upkg_no_requesters before opkg_conf_init"; exit 1; }
echo "[OK] upkg_window_ptr_off stores -1; main calls upkg_no_requesters before the config opens"
