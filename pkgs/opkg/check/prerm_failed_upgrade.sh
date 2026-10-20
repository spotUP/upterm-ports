#!/bin/sh
# prerm_failed_upgrade.sh UPKG: host check that an upgrade whose installed version has a failing
# prerm is handed to the new version's prerm as "failed-upgrade <old-version>", like dpkg.
# Stock opkg 0.9.0 ran only the old prerm and stopped with 'prerm script for package "x" failed',
# so an add-on whose old prerm could not run (its Uninstall record gone) could never be upgraded
# by a fixed package. File:// feed in a temp root, scripts run (no -o):
#   "pup" 1.0 has a prerm that exits 1; "pup" 2.0 logs its prerm arguments and exits 0
#   -> upgrade must succeed, 2.0 files in place, new prerm called with "failed-upgrade 1.0".
#   "pdown" 1.0 (bad prerm) -> 2.0 whose prerm also exits 1 -> upgrade must be refused, 1.0 kept.
#   sh pkgs/opkg/check/prerm_failed_upgrade.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/prermfail.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed1" "$w/feed2"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
def build(feed, name, ver, prerm):
    ctl = b'Package: %s\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: prerm check\n' % (name.encode(), ver.encode())
    pkg = ipk([('./control', ctl, 0o644), ('./prerm', prerm, 0o755)],
              [('./%s.marker' % name, ('version ' + ver + '\n').encode(), 0o644)])
    fn = '%s_%s_m68k-amigaos.ipk' % (name, ver)
    open('%s/%s/%s' % (w, feed, fn), 'wb').write(pkg)
    return stanza(ctl, fn, pkg) + b'\n'
bad = b'#!/bin/sh\nexit 1\n'
log = lambda n: b'#!/bin/sh\necho "$*" >> %s/%s.prerm\nexit 0\n' % (w.encode(), n.encode())
i1 = build('feed1', 'pup', '1.0', bad) + build('feed1', 'pdown', '1.0', bad)
i2 = build('feed2', 'pup', '2.0', log('pup')) + build('feed2', 'pdown', '2.0', bad)
write_index('%s/feed1/Packages.gz' % w, i1)
write_index('%s/feed2/Packages.gz' % w, i2)
PY
conf() {  # conf FEED
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/$1"; echo "dest root $w/root"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
}
st="$w/root$w/status_file"
conf feed1
"$upkg" -f "$w/conf" update >/dev/null 2>"$w/err" || { echo "[FAIL] update 1: $(cat "$w/err")"; exit 1; }
"$upkg" -f "$w/conf" install pup pdown >/dev/null 2>"$w/err" || { echo "[FAIL] install 1.0: $(cat "$w/err")"; exit 1; }
conf feed2
"$upkg" -f "$w/conf" update >/dev/null 2>"$w/err" || { echo "[FAIL] update 2: $(cat "$w/err")"; exit 1; }
"$upkg" -f "$w/conf" install pup >"$w/out" 2>"$w/err" || { echo "[FAIL] upgrade over a failing old prerm refused: $(cat "$w/err")"; exit 1; }
[ "$(cat "$w/root/pup.marker")" = "version 2.0" ] || { echo "[FAIL] pup files not upgraded"; exit 1; }
[ "$(cat "$w/pup.prerm" 2>/dev/null)" = "failed-upgrade 1.0" ] || { echo "[FAIL] new prerm not called with failed-upgrade 1.0 (got: $(cat "$w/pup.prerm" 2>/dev/null))"; exit 1; }
cat "$w/out" "$w/err" | grep -q 'pup' || { echo "[FAIL] no warning naming the packages"; exit 1; }
if "$upkg" -f "$w/conf" install pdown >/dev/null 2>"$w/err"; then echo "[FAIL] upgrade with both prerms failing succeeded"; exit 1; fi
grep -q 'prerm script for package "pdown" failed' "$w/err" || { echo "[FAIL] error not kept: $(cat "$w/err")"; exit 1; }
[ "$(cat "$w/root/pdown.marker")" = "version 1.0" ] || { echo "[FAIL] refused upgrade changed pdown files"; exit 1; }
echo "[OK] opkg prerm: a failing old prerm hands the upgrade to the new prerm (failed-upgrade), both failing refuses"
