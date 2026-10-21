#!/bin/sh
# list_upgradable_fast.sh UPKG: host check that list-upgradable does not index the files of every
# installed package (patches/0017). pkg_info_preinstall_check() reads every installed package's .list
# and stats each path in it (twice before the patch: once in the command, once in prepare_upgrade_list).
# On an A1200 with python, nvim and vim installed that took 41 s against 1.1 s for list-installed
# (measured 2026-10-21); the answer only needs versions and dependencies, never file ownership.
# The sentinel is the INFO line "Updating file owner list." that the indexer prints at -V2:
#   install (which needs the index) must print it, so the sentinel is live;
#   list-upgradable, list-installed and a real upgrade listing must not print it,
#   and list-upgradable must still print the upgrade ("lu - 1.0 - 2.0").
#   sh pkgs/opkg/check/list_upgradable_fast.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/lufast.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed1" "$w/feed2"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
def build(feed, ver):
    ctl = b'Package: lu\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: lu check\n' % ver.encode()
    files = [('./f%d' % i, b'x\n', 0o644) for i in range(50)]
    pkg = ipk([('./control', ctl, 0o644)], files)
    fn = 'lu_%s_m68k-amigaos.ipk' % ver
    open('%s/%s/%s' % (w, feed, fn), 'wb').write(pkg)
    write_index('%s/%s/Packages.gz' % (w, feed), stanza(ctl, fn, pkg) + b'\n')
build('feed1', '1.0')
build('feed2', '2.0')
PY
conf() {
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/$1"; echo "dest root $w/root"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
}
sentinel="Updating file owner list"
conf feed1
"$upkg" -f "$w/conf" update >/dev/null 2>&1
"$upkg" -V2 -f "$w/conf" install lu >"$w/out" 2>&1 || { echo "[FAIL] install: $(cat "$w/out")"; exit 1; }
grep -q "$sentinel" "$w/out" || { echo "[FAIL] test setup: install did not print the sentinel '$sentinel'"; exit 1; }
conf feed2
"$upkg" -f "$w/conf" update >/dev/null 2>&1
"$upkg" -V2 -f "$w/conf" list-upgradable >"$w/out" 2>&1 || { echo "[FAIL] list-upgradable: $(cat "$w/out")"; exit 1; }
grep -q '^lu - 1\.0 - 2\.0$' "$w/out" || { echo "[FAIL] list-upgradable lost the upgrade line: $(cat "$w/out")"; exit 1; }
if grep -q "$sentinel" "$w/out"; then
  echo "[FAIL] list-upgradable indexed the files of every installed package ($(grep -c "$sentinel" "$w/out") times)"; exit 1
fi
"$upkg" -V2 -f "$w/conf" list-installed >"$w/out" 2>&1
if grep -q "$sentinel" "$w/out"; then echo "[FAIL] list-installed indexed installed files"; exit 1; fi
echo "[OK] list-upgradable lists the upgrade without indexing installed files"
