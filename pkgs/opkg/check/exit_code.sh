#!/bin/sh
# exit_code.sh UPKG: host check of patches/0036: upkg never exits with a negative code. main() started with err = -1
# and returned it on a failed start or command (host rc 255); on AmigaOS a negative rc makes the Shell print
# "Unknown command" after the real error message. A failure now exits RETURN_FAIL (20), success 0, and the
# positive codes a command returns itself (1 for "no package matches") are left alone.
#   sh pkgs/opkg/check/exit_code.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/exitcode.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/etc" "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
{ echo "arch m68k-amigaos 10"; echo "dest root /"; echo "option tmp_dir $w/absent"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"

rc=0
env OPKG_CONF_DIR="$w/etc" "$upkg" list-installed > "$w/out" 2>&1 || rc=$?
[ "$rc" = 20 ] || { cat "$w/out"; echo "[FAIL] exit_code: a failed start exited $rc, wanted 20 (RETURN_FAIL)"; exit 1; }
echo "[OK] exit_code: a failed start exits 20, never a negative code"
