#!/bin/sh
# fpu_upgrade_switch.sh UPKG: `upkg upgrade` moves an installed add-on to the build that matches the machine (patch 0057).
#   case 1: installed foo 1.0 m68k-amigaos (10); feed foo 1.0 in m68k-amigaos and m68k-amigaos-fpu (20): becomes the fpu build
#   case 2: same installed; feed 020 1.0 + fpu 1.1: becomes fpu 1.1 (worked before, must not change)
#   case 3: installed foo 1.0 fpu, fpu arch no longer registered: feed 020 1.0 + fpu 1.0 gives the 020 1.0 build,
#           feed 020 1.1 + fpu 1.0 gives the 020 1.1 build; a feed with only the fpu build leaves it installed and in the status file
#   case 4: never a lower version: installed 020 1.1, feed 020 1.1 + fpu 1.0 stays 020 1.1
#   case 5: `upkg upgrade foo` is the same single-package path as `upkg upgrade` for case 1
#   sh pkgs/opkg/check/fpu_upgrade_switch.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/fpuup.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
export UPKG_UHC_DIR="$w/uhc"; mkdir "$w/uhc"
fail=0
feed() { # feed DIR ARCH:VER ... builds foo for each pair in DIR
python3 -I - "$here" "$@" <<'PY'
import sys, os
sys.path.insert(0, sys.argv[1])
from ipk import ipk, stanza, write_index
d = sys.argv[2]; os.makedirs(d, exist_ok=True)
idx = b''
for av in sys.argv[3:]:
    a, v = av.split(':')
    ctl = b'Package: foo\nVersion: %s\nArchitecture: %s\nMaintainer: t\nDescription: foo\n' % (v.encode(), a.encode())
    pkg = ipk([('./control', ctl, 0o644)], [('./f_foo_%s' % a, b'x\n', 0o644)])
    fn = 'foo_%s_%s.ipk' % (v, a)
    open('%s/%s' % (d, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/Packages.gz' % d, idx)
PY
}
conf() { n=$1; shift # conf NAME ARCHLINES...
  { for a in "$@"; do echo "arch $a"; done; echo "src/gz test file://$w/$n.feed"; echo "dest root $w/$n.root"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$n.$o"; done; } > "$w/$n.conf"; }
u() { n=$1; shift; "$upkg" -f "$w/$n.conf" "$@"; }
state() { grep -A8 '^Package: foo$' "$w/$1.root$w/$1.status_file" 2>/dev/null | grep '^\(Version\|Architecture\)' | sed 's/^[A-Za-z]*: //' | tr '\n' ' ' | sed 's/ $//'; }
install_first() { n=$1; arch=$2; ver=$3; shift 3 # install foo $ver in $arch only, then leave the conf as given by the caller
  feed "$w/$n.feed" $arch:$ver; u $n update >/dev/null 2>&1; u $n install foo >/dev/null 2>&1; }
expect() { # expect NAME LABEL WANT
  got=$(state $1)
  if [ "$got" = "$3" ]; then echo "[OK] $2: $got"; else echo "[FAIL] $2: got '$got', want '$3'"; fail=1; fi; }

for cmd in "upgrade" "upgrade foo"; do
  n=c1$(echo $cmd | tr -d ' '); conf $n "m68k-amigaos 10" "m68k-amigaos-fpu 20"; install_first $n m68k-amigaos 1.0
  feed "$w/$n.feed" m68k-amigaos:1.0 m68k-amigaos-fpu:1.0; u $n update >/dev/null 2>&1; u $n $cmd >/dev/null 2>&1 || true
  expect $n "case 1 '$cmd' 020 1.0 -> fpu 1.0" "1.0 m68k-amigaos-fpu"
done

n=c2; conf $n "m68k-amigaos 10" "m68k-amigaos-fpu 20"; install_first $n m68k-amigaos 1.0
feed "$w/$n.feed" m68k-amigaos:1.0 m68k-amigaos-fpu:1.1; u $n update >/dev/null 2>&1; u $n upgrade >/dev/null 2>&1 || true
expect $n "case 2 020 1.0 -> fpu 1.1" "1.1 m68k-amigaos-fpu"

for feedset in "m68k-amigaos:1.0 m68k-amigaos-fpu:1.0|1.0 m68k-amigaos" "m68k-amigaos:1.1 m68k-amigaos-fpu:1.0|1.1 m68k-amigaos" \
               "m68k-amigaos-fpu:1.0|1.0 m68k-amigaos-fpu"; do
  set=${feedset%|*}; want=${feedset#*|}
  n=c3$(echo "$set" | tr -c 'a-z0-9\n' _ | cut -c1-40); conf $n "m68k-amigaos 10" "m68k-amigaos-fpu 20"; install_first $n m68k-amigaos-fpu 1.0
  conf $n "m68k-amigaos 10"
  feed "$w/$n.feed" $set; u $n update >/dev/null 2>&1; u $n upgrade >/dev/null 2>&1 || true
  expect $n "case 3 fpu 1.0 unregistered, feed [$set]" "$want"
done

n=c4; conf $n "m68k-amigaos 10" "m68k-amigaos-fpu 20"; install_first $n m68k-amigaos 1.1
feed "$w/$n.feed" m68k-amigaos:1.1 m68k-amigaos-fpu:1.0; u $n update >/dev/null 2>&1; u $n upgrade >/dev/null 2>&1 || true
expect $n "case 4 no lower version, 020 1.1 stays" "1.1 m68k-amigaos"
exit $fail
