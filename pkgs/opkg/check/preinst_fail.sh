#!/bin/sh
# preinst_fail.sh UPKG: host check that a fresh install whose preinst refuses leaves no record.
# Stock opkg 0.9.0 sends every failure before unpack to pkg_is_hosed, which writes the package
# to status as "install reinstreq half-installed"; dpkg runs postrm abort-install and the package
# is not installed. upkg add-ons refuse an old base from their preinst (vtcon tools/pkgs.py), so
# the stock path left a half-installed add-on behind on every refusal. A file:// feed of two tiny
# .ipk into a temp root: "pfail" (preinst exits 1, postrm logs its arguments) must be refused with
# no files, no status stanza, and postrm called with abort-install; "pok" (preinst exits 0) must
# still install and be recorded. No -o: offline-root mode runs no maintainer scripts, so the dest
# itself is the temp root.
#   sh pkgs/opkg/check/preinst_fail.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/preinstfail.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
index = b''
for name, rc in (('pfail', 1), ('pok', 0)):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: preinst check\n' % name.encode()
    pre = b'#!/bin/sh\nexit %d\n' % rc
    post = b'#!/bin/sh\necho "$*" >> %s/%s.postrm\n' % (w.encode(), name.encode())
    pkg = ipk([('./control', ctl, 0o644), ('./preinst', pre, 0o755), ('./postrm', post, 0o755)],
              [('./%s.marker' % name, b'installed\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    index += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, index)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
st="$w/root$w/status_file"   # a dest keeps its status file under its own root
"$upkg" -f "$w/conf" update >/dev/null 2>"$w/err" || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
if "$upkg" -f "$w/conf" install pfail >/dev/null 2>"$w/err"; then echo "[FAIL] refusing preinst installed"; exit 1; fi
[ ! -e "$w/root/pfail.marker" ] || { echo "[FAIL] refused install left files"; exit 1; }
if grep -q '^Package: pfail$' "$st" 2>/dev/null; then
  echo "[FAIL] refused install left a status record: $(grep -A3 '^Package: pfail$' "$st" | tr '\n' ' ')"; exit 1
fi
[ "$(cat "$w/pfail.postrm" 2>/dev/null)" = "abort-install" ] || { echo "[FAIL] postrm abort-install not run (got: $(cat "$w/pfail.postrm" 2>/dev/null))"; exit 1; }
"$upkg" -f "$w/conf" install pok >/dev/null 2>"$w/err" || { echo "[FAIL] accepting preinst refused: $(cat "$w/err")"; exit 1; }
[ -f "$w/root/pok.marker" ] || { echo "[FAIL] pok left no marker"; exit 1; }
grep -q '^Package: pok$' "$st" || { echo "[FAIL] pok not in status"; exit 1; }
echo "[OK] opkg preinst: a refusing preinst unwinds a fresh install to not-installed, an accepting one installs"
