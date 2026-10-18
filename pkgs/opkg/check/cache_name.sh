#!/bin/sh
# cache_name.sh UPKG: host check that every file upkg puts in its cache has a name of at most 30
# characters. AmigaDOS FFS keeps 30 and truncates the rest silently, so the stock
# "<md5hex32>_<basename>" cache name (66 chars for UP-Term-nvim_1.0_m68k-amigaos.ipk) came back
# from the disk under another name and opkg deleted the "corrupt" package: every install failed.
# The host build gets the Amiga naming from -DUPKG_SHORT_NAMES (recipe host flags).
#   sh pkgs/opkg/check/cache_name.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/cachename.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed"
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
name = 'UP-Term-nvim_1.0_m68k-amigaos.ipk'
ctl = b'Package: UP-Term-nvim\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: cache name check\n'
ipk = ar([('debian-binary', b'2.0\n'), ('control.tar.gz', targz([('./control', ctl)])),
          ('data.tar.gz', targz([('./marker', b'installed\n')]))])
open('%s/feed/%s' % (w, name), 'wb').write(ipk)
text = ctl + b'Filename: %s\nSize: %d\nSHA256sum: %s\n' % (name.encode(), len(ipk), hashlib.sha256(ipk).hexdigest().encode())
with gzip.GzipFile('%s/feed/Packages.gz' % w, 'wb', mtime=0) as gz:
    gz.write(text)
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
