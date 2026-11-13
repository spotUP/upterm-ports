#!/bin/sh
# remove_reason.sh UPKG: host check of patches/0062: when `upkg remove` removes nothing, the closing NOTICE names the
# reason ("No packages removed: not installed.") instead of a bare "No packages removed.", and the exit code stays 5
# (UPKG_RC_NOTHING). The line "NAME is not installed." stays on stderr; the NOTICE goes to stdout, so a caller that
# keeps only stdout still sees why. Build a tree with no package installed, then remove one that is not there.
#   sh pkgs/opkg/check/remove_reason.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/rmreason.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/etc" "$w/tmp" "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
{ echo "arch m68k-amigaos 10"; echo "dest root /"; echo "option tmp_dir $w/tmp"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"

rc=0
env OPKG_CONF_DIR="$w/etc" "$upkg" remove nosuchpkg > "$w/out" 2> "$w/err" || rc=$?
[ "$rc" = 5 ] || { cat "$w/out" "$w/err"; echo "[FAIL] remove_reason: exit $rc, wanted 5"; exit 1; }
grep -q 'nosuchpkg is not installed\.' "$w/err" || { cat "$w/err"; echo "[FAIL] remove_reason: stderr lacks 'nosuchpkg is not installed.'"; exit 1; }
cat "$w/out" "$w/err" | grep -q 'No packages removed: not installed\.' || { cat "$w/out" "$w/err"; echo "[FAIL] remove_reason: closing line lacks the reason"; exit 1; }
echo "[OK] remove_reason: nothing removed says 'No packages removed: not installed.' and exits 5"
