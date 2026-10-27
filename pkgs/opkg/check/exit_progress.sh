#!/bin/sh
# exit_progress.sh UPKG: host check of patches/0049 and doc/upkg-api.txt, the interface the Amarchy front-end drives:
# the exit codes of upkg (0 ok, 5 nothing to do, 11 usage, 12 not found, 13 network, 14 package script, 15 needs
# answers; 20, a failed start, is exit_code.sh) and one "[PROGRESS n/m] <phase> <name>" line per phase with stdout piped. A file: feed of tiny
# .ipk into a temp root; "pok" installs, "pfail" has a preinst that refuses, "pask" is UP-Term-Interactive.
#   sh pkgs/opkg/check/exit_progress.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/exitprog.XXXXXX")
trap 'rm -rf "$w"' EXIT
fail() { echo "[FAIL] exit_progress: $1"; exit 1; }
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
index = b''
for name, pre, extra in (('pok', 0, b''), ('pfail', 1, b''), ('pask', 0, b'UP-Term-Interactive: yes\n')):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: api check\n' % name.encode() + extra
    scripts = [('./control', ctl, 0o644), ('./preinst', b'#!/bin/sh\nexit %d\n' % pre, 0o755), ('./postinst', b'#!/bin/sh\nexit 0\n', 0o755)]
    pkg = ipk(scripts, [('./%s.marker' % name, b'installed\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    index += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, index)
PY
conf() { { echo "arch m68k-amigaos 10"; echo "src/gz $2 $3"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$1.$o"; done; } > "$w/$1.conf"; }
conf good test "file://$w/feed"
conf dead test "http://127.0.0.1:1/feed"
u() { "$upkg" -f "$w/good.conf" "$@"; }

# rc NAME WANT CMD...: run with stdin and stdout not a terminal, check the exit code
rc() {
  n=$1; want=$2; shift 2
  got=0; "$@" </dev/null >"$w/out" 2>"$w/err" || got=$?
  [ "$got" = "$want" ] || { cat "$w/out" "$w/err"; fail "$n exited $got, want $want"; }
}

# update: the feed is fetched, then the progress line count is checked on a piped stdout
u update </dev/null >"$w/upd" 2>"$w/err" || fail "update: $(cat "$w/err")"
[ "$(grep -c '^\[PROGRESS ' "$w/upd")" = 1 ] && grep -qx '\[PROGRESS 1/1\] update test' "$w/upd" ||
  fail "update progress lines: $(grep PROGRESS "$w/upd" | tr '\n' '|')"

rc "list of a glob that matches nothing" 5 u list 'zz*'
rc "list-installed of a glob that matches nothing" 5 u list-installed 'zz*'
rc "remove of a package that is not installed" 5 u remove pok
rc "unknown sub-command" 11 u frobnicate
rc "no sub-command" 11 u
rc "browse without a terminal" 11 u browse
rc "install of an unknown package" 12 u install nosuchpkg
rc "download of an unknown package" 12 u download nosuchpkg
rc "install of a package whose preinst refuses" 14 u install pfail
rc "install of an interactive package without a terminal" 15 u install pask
[ ! -e "$w/root/pask.marker" ] || fail "pask was installed without a terminal"
rc "update from an unreachable feed" 13 "$upkg" -f "$w/dead.conf" update

# one install with stdout piped: the plan is the package count, the phases come in order, nothing else matches
u install pok </dev/null >"$w/ins" 2>"$w/err" || fail "install pok: $(cat "$w/err")"
grep '^\[PROGRESS ' "$w/ins" > "$w/ins.p" || true
printf '[PROGRESS 1/1] install pok\n[PROGRESS 1/1] download pok\n[PROGRESS 1/1] unpack pok\n[PROGRESS 1/1] configure pok\n' > "$w/ins.want"
cmp -s "$w/ins.p" "$w/ins.want" || { diff "$w/ins.want" "$w/ins.p" || true; fail "install progress lines differ"; }
rc "install of an installed package is not an error" 0 u install pok

# remove, and UPKG_PROGRESS=1 forces the lines the piped run already has; a plain sink with the switch off is not asked
u remove pok </dev/null >"$w/rem" 2>"$w/err" || fail "remove pok: $(cat "$w/err")"
grep -qx '\[PROGRESS 1/1\] remove pok' "$w/rem" || fail "remove progress: $(grep PROGRESS "$w/rem" | tr '\n' '|')"
echo "[OK] exit_progress: rc 0/5/11/12/13/14/15 each from its case, [PROGRESS n/m] lines of update, install and remove with stdout piped"
