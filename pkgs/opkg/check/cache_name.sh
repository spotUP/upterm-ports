#!/bin/sh
# cache_name.sh UPKG: host check that every file upkg puts in its cache has a name of at most 30
# characters. AmigaDOS FFS keeps 30 and truncates the rest silently, so the stock
# "<md5hex32>_<basename>" cache name (66 chars for UP-Term-nvim_1.0_m68k-amigaos.ipk) came back
# from the disk under another name and opkg deleted the "corrupt" package: every install failed.
# The host build gets the Amiga naming from -DUPKG_SHORT_NAMES (recipe host flags).
#   sh pkgs/opkg/check/cache_name.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/cachename.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
name = 'UP-Term-nvim_1.0_m68k-amigaos.ipk'
ctl = b'Package: UP-Term-nvim\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: cache name check\n'
pkg = ipk([('./control', ctl)], [('./marker', b'installed\n')])
open('%s/feed/%s' % (w, name), 'wb').write(pkg)
write_index('%s/feed/Packages.gz' % w, stanza(ctl, name, pkg))
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root /"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/c.conf"
"$upkg" -f "$w/c.conf" -o "$w/root" update >/dev/null 2>"$w/err" || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
"$upkg" -f "$w/c.conf" -o "$w/root" --download-only install UP-Term-nvim >/dev/null 2>"$w/err" || { echo "[FAIL] download: $(cat "$w/err")"; exit 1; }
n=0
for f in $(find "$w/root" ! -type d -path '*/c.cache_dir/*'); do
  b=$(basename "$f"); n=$((n + 1))
  [ ${#b} -le 30 ] || { echo "[FAIL] cache file name is ${#b} chars (max 30): $b"; exit 1; }
done
[ "$n" -gt 0 ] || { echo "[FAIL] no file in the cache dir"; exit 1; }
"$upkg" -f "$w/c.conf" -o "$w/root" install UP-Term-nvim >/dev/null 2>"$w/err" || { echo "[FAIL] install: $(cat "$w/err")"; exit 1; }
[ -f "$w/root/marker" ] || { echo "[FAIL] install left no marker"; exit 1; }
echo "[OK] opkg cache: $n cache file name(s), all at most 30 characters"
