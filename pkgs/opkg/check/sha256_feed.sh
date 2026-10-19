#!/bin/sh
# sha256_feed.sh UPKG: host check that upkg enforces the feed's SHA256sum. The opkg CMake build had
# WITH_SHA256 only as an option, never in config.h, so `#if WITH_SHA256` was false and every
# install died with "Checksum is either missing or unsupported". Two file:// feeds of one tiny
# .ipk into a temp root: the right SHA256sum installs, a wrong one is refused and installs nothing.
#   sh pkgs/opkg/check/sha256_feed.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/sha256feed.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed.good" "$w/feed.bad"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
ctl = b'Package: shatest\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: sha256 check\n'
pkg = ipk([('./control', ctl)], [('./marker', b'installed\n')])
for d, s in (('good', None), ('bad', '0' * 64)):
    open('%s/feed.%s/shatest_1.0_m68k-amigaos.ipk' % (w, d), 'wb').write(pkg)
    write_index('%s/feed.%s/Packages.gz' % (w, d), stanza(ctl, 'shatest_1.0_m68k-amigaos.ipk', pkg, s))
PY
for d in good bad; do
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed.$d"; echo "dest root /"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$d.$o"; done; } > "$w/$d.conf"
done
"$upkg" -f "$w/good.conf" -o "$w/root.good" update >/dev/null 2>"$w/err" || { echo "[FAIL] update (good): $(cat "$w/err")"; exit 1; }
"$upkg" -f "$w/good.conf" -o "$w/root.good" install shatest >/dev/null 2>"$w/err" || { echo "[FAIL] good SHA256sum refused: $(cat "$w/err")"; exit 1; }
[ -f "$w/root.good/marker" ] || { echo "[FAIL] good install left no marker"; exit 1; }
"$upkg" -f "$w/bad.conf" -o "$w/root.bad" update >/dev/null 2>"$w/err" || { echo "[FAIL] update (bad): $(cat "$w/err")"; exit 1; }
if "$upkg" -f "$w/bad.conf" -o "$w/root.bad" install shatest >/dev/null 2>"$w/err"; then echo "[FAIL] wrong SHA256sum installed"; exit 1; fi
[ ! -e "$w/root.bad/marker" ] || { echo "[FAIL] wrong SHA256sum left files"; exit 1; }
echo "[OK] opkg sha256: matching SHA256sum installs, wrong one refused with nothing installed"
