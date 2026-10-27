#!/bin/sh
# browse_uhc.sh UPKG: host check of patches/0046: `upkg browse` tells a UHC row from an ipk row of the same name.
# The UHC fixture drawer (check/uhc/Packages) has curl, lzx and unzip; the feed has alpha and unzip, so "unzip" is in
# both sources. The list shows the UHC rows in the tag column as uhc:<name> (the same tag `upkg list` prints and
# `upkg install` takes), the ipk unzip stays plain. Install from the list routes by row: i on uhc:lzx runs the UHC
# runner (a stub `Execute` in PATH records its argument; the real one is AmigaDOS), i on the ipk unzip installs the
# feed package and never reaches the runner. Needs build/tools/ptyrun (make build/tools/ptyrun).
#   sh pkgs/opkg/check/browse_uhc.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
ptyrun=$root/build/tools/ptyrun
[ -x "$ptyrun" ] || { echo "[SKIP] no $ptyrun"; exit 0; }
w=$(mktemp -d "${TMPDIR:-/tmp}/buhc.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
fail() { echo "[FAIL] $*"; [ -f "$w/plain" ] && sed -n 1,20p "$w/plain"; exit 1; }
mkdir "$w/feed" "$w/bin"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name in ('alpha', 'unzip'):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s feed\n' % (name.encode(), name.encode())
    pkg = ipk([('./control', ctl, 0o644)], [('./f_%s' % name, b'x\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
cp -R "$here/uhc/Packages" "$w/uhc"
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
printf '#!/bin/sh\necho "$@" >> %s/exec.log\n' "$w" > "$w/bin/Execute"; chmod +x "$w/bin/Execute"
export UPKG_UHC_DIR="$w/uhc"
"$upkg" -f "$w/conf" update >/dev/null 2>&1 || fail "set-up: update"
run() { # KEYS-FILE -> $w/out, $w/plain (escape sequences stripped)
    "$ptyrun" -s 100x30 -t 20 "$1" "$w/out" env LANG=C TERM=vtcon TERMINFO="$root/build/tools/terminfo" PATH="$w/bin:$PATH" \
        "$upkg" -f "$w/conf" browse >"$w/run.log" 2>&1 || :
    grep -q '^exit 0$' "$w/run.log" || fail "browse did not exit 0: $(head -3 "$w/run.log")"
    sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$w/out" > "$w/plain"
}
# the list: UHC rows carry the source tag, the ipk rows do not
printf '600 q\n' > "$w/k1"
run "$w/k1"
for want in 'uhc:curl' 'uhc:lzx' 'uhc:unzip'; do
    grep -aq "$want" "$w/plain" || fail "list shows no '$want' tag"
done
grep -aq 'uhc:alpha' "$w/plain" && fail "an ipk row carries the uhc: tag"
grep -aq ' alpha  *available' "$w/plain" || fail "the ipk row alpha lost its plain tag"
grep -aq '|  unzip  *available' "$w/plain" || grep -aq '  unzip  *available 1.0' "$w/plain" || fail "the ipk row unzip is missing next to uhc:unzip"
# rows: alpha, unzip, uhc:curl, uhc:lzx, uhc:unzip. i on the 4th row (uhc:lzx, Down x3) reaches the UHC runner
printf '300 \\eOB\n100 \\eOB\n100 \\eOB\n100 i\n2500 \\r\n800 q\n' > "$w/k2"
run "$w/k2"
[ -f "$w/exec.log" ] || fail "i on uhc:lzx never reached the UHC runner (no Execute call)"
grep -q "uhc/lzx\$\|/lzx\$\|upkg-uhc-lzx\$" "$w/exec.log" || fail "the UHC runner was not given the lzx script: $(cat "$w/exec.log")"
grep -q "upkg install uhc:lzx" "$w/plain" || fail "the progress box does not name uhc:lzx"
# i on the 2nd row (the ipk unzip) installs the feed package and does not reach the runner
rm -f "$w/exec.log"
printf '300 \\eOB\n100 i\n2500 \\r\n800 q\n' > "$w/k3"
run "$w/k3"
[ ! -f "$w/exec.log" ] || fail "i on the ipk unzip reached the UHC runner: $(cat "$w/exec.log")"
"$upkg" -f "$w/conf" list-installed 2>&1 | grep -q '^unzip - 1.0' || fail "i on the ipk unzip did not install the feed package"
echo "[OK] upkg browse: UHC rows show uhc:<name> in the tag column, install routes uhc:lzx to the UHC runner and the ipk unzip to opkg"
