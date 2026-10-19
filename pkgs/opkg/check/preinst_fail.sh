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
w=$(mktemp -d "${TMPDIR:-/tmp}/preinstfail.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" <<'PY'
import gzip, hashlib, io, sys, tarfile
w = sys.argv[1]
def targz(files):
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.GNU_FORMAT) as tf:
        for name, data, mode in files:
            ti = tarfile.TarInfo(name); ti.size = len(data); ti.mode = mode
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
index = b''
for name, rc in (('pfail', 1), ('pok', 0)):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: preinst check\n' % name.encode()
    pre = b'#!/bin/sh\nexit %d\n' % rc
    post = b'#!/bin/sh\necho "$*" >> %s/%s.postrm\n' % (w.encode(), name.encode())
    ipk = ar([('debian-binary', b'2.0\n'),
              ('control.tar.gz', targz([('./control', ctl, 0o644), ('./preinst', pre, 0o755), ('./postrm', post, 0o755)])),
              ('data.tar.gz', targz([('./%s.marker' % name, b'installed\n', 0o644)]))])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(ipk)
    index += ctl + b'Filename: %s\nSize: %d\nSHA256sum: %s\n\n' % (fn.encode(), len(ipk), hashlib.sha256(ipk).hexdigest().encode())
with gzip.GzipFile('%s/feed/Packages.gz' % w, 'wb', mtime=0) as gz:
    gz.write(index)
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
