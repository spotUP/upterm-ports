#!/bin/sh
# tsv_one_row.sh UPKG: host check of patches/0054: `upkg list --tsv` prints one row per package name (the highest
# version, with the installed and upgradable flags of the name), not one row per version in the feeds. Feed: up-pi 1.0
# installed, then 1.1 added to the feed. list-upgradable --tsv keeps its one row.
#   sh pkgs/opkg/check/tsv_one_row.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/tsvone.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/uhc"
feed() { # feed VERSION...: the Packages index lists every VERSION of up-pi
python3 -I - "$w" "$here" "$@" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for v in sys.argv[3:]:
    ctl = b'Package: up-pi\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: up-pi\n' % v.encode()
    pkg = ipk([('./control', ctl, 0o644)], [('./f_up-pi', b'x\n', 0o644)])
    fn = 'up-pi_%s_m68k-amigaos.ipk' % v
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
}
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
export UPKG_UHC_DIR="$w/uhc"
u() { "$upkg" -f "$w/conf" "$@"; }
fail() { echo "[FAIL] tsv_one_row: $*"; exit 1; }
tab=$(printf '\t')

feed 1.0
u update >/dev/null 2>&1 || fail "update 1.0"
u install up-pi >/dev/null 2>&1 || fail "install up-pi 1.0"
feed 1.0 1.1
u update >/dev/null 2>&1 || fail "update 1.0 + 1.1"

u list --tsv >"$w/t"
rows=$(awk -F'\t' '$1 == "up-pi"' "$w/t")
n=$(printf '%s\n' "$rows" | grep -c . || true)
[ "$n" = 1 ] || fail "list --tsv has $n rows for up-pi, want 1: $(echo "$rows" | cut -f1-4 | tr '\t' ' ' | tr '\n' '|')"
[ "$(echo "$rows" | cut -f1-4)" = "up-pi${tab}1.1${tab}1${tab}1" ] || fail "row is not 'up-pi 1.1 1 1': $(echo "$rows" | cut -f1-4)"
u list-upgradable --tsv >"$w/t"
[ "$(awk -F'\t' '$1 == "up-pi"' "$w/t" | cut -f1-4)" = "up-pi${tab}1.1${tab}1${tab}1" ] || fail "list-upgradable --tsv row changed"
echo "[OK] tsv_one_row: one list --tsv row for up-pi: 1.1, installed 1, upgradable 1"
