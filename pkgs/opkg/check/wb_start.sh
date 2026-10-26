#!/bin/sh
# wb_start.sh UPKG: host check of patches/0030: a start with argc == 0 (a Workbench icon, argv is a WBStartup)
# calls upkg_wb once, after the IXSTACK setup and after the feeds and status files are loaded; any start with
# a command line never calls it. The host build's upkg_wb is a stub that appends the sentinel
# "window opened, N rows" (N from upkg_rows_load) and the IXSTACK it saw to $UPKG_WB_LOG; the Amiga build
# writes the same sentinel line to UP-Term:log/upkg-wb.log. wb_exec.c starts upkg with an empty argv.
#   sh pkgs/opkg/check/wb_start.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/wbstart.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/tmp" "$w/etc"
cc -O1 -Wall -o "$w/wb_exec" "$here/wb_exec.c"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name in ('wb-check-one', 'wb-check-two'):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: wb start check\n' % name.encode()
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    pkg = ipk([('./control', ctl)], [('./marker', b'installed\n')])
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root /"; echo "option tmp_dir $w/tmp"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"
mkdir "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
# the feed is read from the lists dir: update it with the command line first
env OPKG_CONF_DIR="$w/etc" "$upkg" update > "$w/update.out" 2>&1 || { cat "$w/update.out"; echo "[FAIL] wb_start: setup update failed"; exit 1; }

log=$w/wb.log
# argc >= 1: commands run as always and never reach upkg_wb
env OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$upkg" list > "$w/list.out" 2>&1 || { cat "$w/list.out"; echo "[FAIL] wb_start: upkg list failed"; exit 1; }
env OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$upkg" --version > /dev/null 2>&1 || true
if [ -e "$log" ]; then echo "[FAIL] wb_start: upkg_wb ran for a start with a command line"; cat "$log"; exit 1; fi
grep -q 'wb-check-two' "$w/list.out" || { echo "[FAIL] wb_start: upkg list output changed"; exit 1; }

# argc == 0: upkg_wb runs once, with the feed loaded (2 rows) and IXSTACK set (the user had none)
env -u IXSTACK OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$w/wb_exec" "$upkg" > "$w/wb.out" 2>&1 || { cat "$w/wb.out"; echo "[FAIL] wb_start: the argc == 0 start failed"; exit 1; }
n=$(grep -c '^window opened, ' "$log" || true)
[ "$n" = 1 ] || { echo "[FAIL] wb_start: upkg_wb ran $n times for argc == 0, wanted 1"; cat "$log"; exit 1; }
grep -qx 'window opened, 2 rows' "$log" || { echo "[FAIL] wb_start: sentinel is not 'window opened, 2 rows'"; cat "$log"; exit 1; }
grep -qx 'IXSTACK=262144' "$log" || { echo "[FAIL] wb_start: upkg_wb ran before the IXSTACK setup"; cat "$log"; exit 1; }
echo "[OK] wb_start: upkg_wb ran once for argc == 0 (window opened, 2 rows; IXSTACK=262144) and not for a command line"
