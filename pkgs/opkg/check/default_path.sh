#!/bin/sh
# default_path.sh UPKG: host check that upkg gives its children a PATH when the shell left none (patches/0012).
# A plain AmigaDOS Shell has no PATH variable, so ixemul searched its own default for the bare `curl` and
# `/bin/sh -c` of a maintainer script and asked for a volume "usr". upkg now sets PATH to UPKG_DEFAULT_PATH
# (/UP-Term/bin:/C) at startup when it is unset or empty. A one-file package whose preinst writes $PATH to a
# file is installed through `env -i`; the script must see the default PATH, for an unset and an empty PATH.
#   sh pkgs/opkg/check/default_path.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/defpath.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
index = b''
for name in ('pathunset', 'pathempty'):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: PATH check\n' % name.encode()
    pre = b'#!/bin/sh\necho "$PATH" > %s/%s.path\necho "$IXSTACK" > %s/%s.stack\nexit 0\n' % (w.encode(), name.encode(), w.encode(), name.encode())
    pkg = ipk([('./control', ctl, 0o644), ('./preinst', pre, 0o755)], [('./%s.marker' % name, b'x\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    index += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, index)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
# env -i: no PATH at all, so the shell is run by absolute path
env -i /bin/sh -c "exec \"$upkg\" -f \"$w/conf\" update" >/dev/null 2>"$w/err" || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
env -i "$upkg" -f "$w/conf" install pathunset >/dev/null 2>"$w/err" || { echo "[FAIL] install with PATH unset: $(cat "$w/err")"; exit 1; }
env -i PATH= "$upkg" -f "$w/conf" install pathempty >/dev/null 2>"$w/err" || { echo "[FAIL] install with PATH empty: $(cat "$w/err")"; exit 1; }
for n in pathunset pathempty; do
  p=$(cat "$w/$n.path" 2>/dev/null || true)
  case $p in
    /UP-Term/bin:/C|*:/UP-Term/bin:/C) ;;
    *) echo "[FAIL] $n: the preinst saw PATH='$p', want the default /UP-Term/bin:/C"; exit 1 ;;
  esac
  [ "$(cat "$w/$n.stack" 2>/dev/null)" = 262144 ] || { echo "[FAIL] $n: the preinst saw IXSTACK='$(cat "$w/$n.stack" 2>/dev/null)', want 262144 (patches/0014)"; exit 1; }
done
echo "[OK] upkg with PATH unset or empty: maintainer scripts see /UP-Term/bin:/C and IXSTACK 262144"
