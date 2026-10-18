#!/bin/sh
# sha256_feed.sh UPKG: host check that upkg enforces the feed's SHA256sum. The opkg CMake build had
# WITH_SHA256 only as an option, never in config.h, so `#if WITH_SHA256` was false and every
# install died with "Checksum is either missing or unsupported". Two file:// feeds of one tiny
# .ipk into a temp root: the right SHA256sum installs, a wrong one is refused and installs nothing.
#   sh pkgs/opkg/check/sha256_feed.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/sha256feed.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed.good" "$w/feed.bad"
python3 -I - "$w" <<'PY'
import gzip, hashlib, io, sys, tarfile
w = sys.argv[1]
def targz(files):
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.GNU_FORMAT) as tf:
        for name, data in files:
            ti = tarfile.TarInfo(name); ti.size = len(data); ti.mode = 0o644
            tf.addfile(ti, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(filename='', mode='wb', fileobj=out, mtime=0) as gz:
        gz.write(raw.getvalue())
    return out.getvalue()
def ar(members):
    out = b'!<arch>\n'
    for name, data in members:
        out += b'%-16s%-12d%-6d%-6d%-8s%-10d`\n' % ((name + '/').encode(), 0, 0, 0, b'100644', len(data))
        out += data + (b'\n' if len(data) % 2 else b'')
    return out
ctl = b'Package: shatest\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: sha256 check\n'
ipk = ar([('debian-binary', b'2.0\n'), ('control.tar.gz', targz([('./control', ctl)])),
          ('data.tar.gz', targz([('./marker', b'installed\n')]))])
good = hashlib.sha256(ipk).hexdigest()
for d, s in (('good', good), ('bad', '0' * 64)):
    open('%s/feed.%s/shatest_1.0_m68k-amigaos.ipk' % (w, d), 'wb').write(ipk)
    text = ctl + b'Filename: shatest_1.0_m68k-amigaos.ipk\nSize: %d\nSHA256sum: %s\n' % (len(ipk), s.encode())
    with gzip.GzipFile('%s/feed.%s/Packages.gz' % (w, d), 'wb', mtime=0) as gz:
        gz.write(text)
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
