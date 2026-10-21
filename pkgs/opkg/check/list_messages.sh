#!/bin/sh
# list_messages.sh UPKG: host check of patches 0018-0020 and 0021: no upkg command ends a no-op in silence.
#   0018 list/list-installed with a glob that matches nothing: stderr 'upkg: no package matches "<glob>"', rc 1;
#        with matches the output is unchanged.
#   0019 "list upgradable", "list upgradeable", "list installed" run list-upgradable and list-installed.
#   0020 an empty list-upgradable / list-installed prints a message when stdout is a terminal (a pty from
#        python3) and nothing through a pipe: dist/upkg-browse reads these lists through $(...).
#   0021 upgrade with nothing to upgrade says so, remove of a missing package says 'X is not installed.' and exits 1;
#        install of an installed package already says 'Package X (v) installed in root is up to date.' (stock opkg, kept).
#   sh pkgs/opkg/check/list_messages.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/lmsg.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name in ('alpha', 'beta'):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s check\n' % (name.encode(), name.encode())
    pkg = ipk([('./control', ctl, 0o644)], [('./f_%s' % name, b'x\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
u() { "$upkg" -f "$w/conf" "$@"; }
fail() { echo "[FAIL] $*"; exit 1; }
# run "$@" on a pty (stdout is a terminal): prints its output
tty() { python3 -I -c '
import pty, sys
pty.spawn(sys.argv[1:])' "$@" </dev/null | tr -d '\r'; }
u update >/dev/null 2>&1 || fail "update"

# 0018 no match
rc=0; u list 'zz*' >"$w/o" 2>"$w/e" || rc=$?
[ "$rc" = 1 ] || fail "list zz* rc=$rc, want 1"
[ ! -s "$w/o" ] || fail "list zz* wrote stdout: $(cat "$w/o")"
[ "$(cat "$w/e")" = 'upkg: no package matches "zz*"' ] || fail "list zz* stderr: $(cat "$w/e")"
rc=0; u list-installed 'zz*' >"$w/o" 2>"$w/e" || rc=$?
[ "$rc" = 1 ] && [ "$(cat "$w/e")" = 'upkg: no package matches "zz*"' ] || fail "list-installed zz*: rc=$rc $(cat "$w/e")"
# match unchanged
u list 'al*' >"$w/o" 2>&1 || fail "list al* rc=$?"
[ "$(cat "$w/o")" = 'alpha - 1.0 - alpha check' ] || [ "$(cat "$w/o")" = 'alpha - 1.0' ] || fail "list al*: $(cat "$w/o")"
[ "$(u list | wc -l | tr -d ' ')" = 2 ] || fail "list without glob lost a package"

# 0019/0020 empty, nothing installed
[ -z "$(u list-installed 2>&1)" ] || fail "list-installed through a pipe is not empty"
[ -z "$(u list installed 2>&1)" ] || fail "list installed through a pipe is not empty"
[ -z "$(u list-upgradable 2>&1)" ] || fail "list-upgradable through a pipe is not empty"
[ "$(tty "$upkg" -f "$w/conf" list-installed)" = "No add-ons are installed." ] || fail "list-installed on a tty: $(tty "$upkg" -f "$w/conf" list-installed)"
[ "$(tty "$upkg" -f "$w/conf" list installed)" = "No add-ons are installed." ] || fail "list installed on a tty"
[ "$(tty "$upkg" -f "$w/conf" list-upgradable)" = "All installed add-ons are up to date." ] || fail "list-upgradable on a tty: $(tty "$upkg" -f "$w/conf" list-upgradable)"
for form in upgradable upgradeable; do
  [ "$(tty "$upkg" -f "$w/conf" list $form)" = "All installed add-ons are up to date." ] || fail "list $form on a tty"
  [ -z "$(u list $form 2>&1)" ] || fail "list $form through a pipe is not empty"
done

# 0021 remove of a missing package
rc=0; u remove alpha >"$w/o" 2>&1 || rc=$?
[ "$rc" = 1 ] || fail "remove of a missing package rc=$rc, want 1"
grep -q '^alpha is not installed\.$' "$w/o" || fail "remove of a missing package: $(cat "$w/o")"

# installed
u install alpha >/dev/null 2>&1 || fail "install alpha"
[ "$(u list-installed 2>&1)" = "alpha - 1.0" ] || fail "list-installed: $(u list-installed 2>&1)"
[ "$(u list installed 2>&1)" = "alpha - 1.0" ] || fail "list installed: $(u list installed 2>&1)"
[ "$(u list-installed 'al*' 2>&1)" = "alpha - 1.0" ] || fail "list-installed al*"
[ "$(tty "$upkg" -f "$w/conf" list installed)" = "alpha - 1.0" ] || fail "list installed on a tty with a package"
rc=0; u install alpha >"$w/o" 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "install of an installed package rc=$rc"
grep -q '^Package alpha (1\.0) installed in root is up to date\.$' "$w/o" || fail "install of an installed package: $(cat "$w/o")"
u upgrade >"$w/o" 2>&1 || fail "upgrade rc=$?"
[ "$(cat "$w/o")" = "All installed add-ons are up to date." ] || fail "upgrade with nothing to do: $(cat "$w/o")"
u upgrade alpha >"$w/o" 2>&1 || fail "upgrade alpha rc=$?"
[ "$(cat "$w/o")" = "All installed add-ons are up to date." ] || fail "upgrade alpha with nothing to do: $(cat "$w/o")"
echo "[OK] no-match error, two-word forms, tty and pipe messages for empty lists, upgrade/install/remove no-op messages"
