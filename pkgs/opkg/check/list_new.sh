#!/bin/sh
# list_new.sh UPKG: host check of patches/0023: `upkg update` keeps each feed's old list as
# lists/<feed>.prev and `upkg list-new` prints the packages in the lists that no .prev has.
#   first update ever (no old list): no .prev is written, list-new prints nothing, exit 0.
#   a feed gains gamma between two updates: list-new prints gamma's `upkg list` row and nothing else.
#   an update that changes nothing: nothing is new.
#   the .prev file is not read as a feed: list and list-new do not count its packages twice, and a
#   .prev holding a package the feed lost does not appear in list.
#   sh pkgs/opkg/check/list_new.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/lnew.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed"
feed() { python3 -I - "$w" "$here" "$@" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name in sys.argv[3:]:
    name = name.encode()
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s check\n' % (name, name)
    pkg = ipk([('./control', ctl, 0o644)], [('./f_%s' % name.decode(), b'x\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name.decode()
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
}
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
u() { "$upkg" -f "$w/conf" "$@"; }
fail() { echo "[FAIL] $*"; exit 1; }

feed alpha beta; u update >/dev/null 2>&1 || fail "first update"
[ -z "$(ls "$w/lists_dir" | grep '\.prev$' || :)" ] || fail "first update wrote $(ls "$w/lists_dir")"
rc=0; u list-new >"$w/o" 2>&1 || rc=$?
[ "$rc" = 0 ] && [ ! -s "$w/o" ] || fail "list-new after the first update: rc=$rc, $(cat "$w/o")"

feed alpha beta gamma; u update >/dev/null 2>&1 || fail "second update"
[ -f "$w/lists_dir/test.prev" ] || fail "no test.prev after the second update: $(ls "$w/lists_dir")"
u list gamma >"$w/want" 2>&1; [ -s "$w/want" ] || fail "set-up: list gamma is empty"
rc=0; u list-new >"$w/o" 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "list-new rc=$rc"
cmp -s "$w/want" "$w/o" || fail "list-new is '$(cat "$w/o")', want '$(cat "$w/want")'"

# .prev is not a feed: list shows each package once, nothing the feed lost
feed alpha beta; u update >/dev/null 2>&1 || fail "third update"
u list >"$w/o" 2>&1
[ "$(wc -l <"$w/o" | tr -d ' ')" = 2 ] && ! grep -q '^gamma' "$w/o" || fail "list after gamma left the feed: $(cat "$w/o")"
rc=0; u list-new >"$w/o" 2>&1 || rc=$?
[ "$rc" = 0 ] && [ ! -s "$w/o" ] || fail "list-new after an update that added nothing: $(cat "$w/o")"
u --help 2>&1 | grep -q '^  list-new ' || fail "list-new is not in the help text"
echo "[OK] upkg update keeps <feed>.prev (none on the first update); list-new prints only what the last update added; .prev is not read as a feed"
