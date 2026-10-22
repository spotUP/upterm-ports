#!/bin/sh
# browse_tty.sh UPKG: host check of patches/0025: `upkg browse` runs in the upkg process on a pty.
#   the list shows every row of the feed with its status (installed, upgrade X to Y, available);
#   Enter opens the info box and Escape returns to the list, with ZERO child processes: a preload shim
#   counts fork, vfork, posix_spawn, execve and system calls (check/spawn_count.c). The shim is the
#   method because the program under test must not carry a counting hook, and a child-free browse is
#   the claim of the patch. macOS strips DYLD_* from system binaries, so the probe runs upkg itself
#   (a local build). A positive control proves the shim sees children: an install whose postinst
#   runs a script counts more than zero.
#   install of a non-interactive add-on from the list runs in this process and its row turns installed
#   (the package hash in memory is updated after the install).
#   sh pkgs/opkg/check/browse_tty.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
ptyrun=$root/build/tools/ptyrun
[ -x "$ptyrun" ] || { echo "[SKIP] no $ptyrun"; exit 0; }
w=$(mktemp -d "${TMPDIR:-/tmp}/btty.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
fail() { echo "[FAIL] $*"; [ -f "$w/out" ] && sed -n 1,40p "$w/out"; exit 1; }
mkdir "$w/feed" "$w/lib"
case $(uname) in
Darwin) cc -dynamiclib -o "$w/lib/spawn_count.dylib" "$here/spawn_count.c"; shim="DYLD_INSERT_LIBRARIES=$w/lib/spawn_count.dylib" ;;
*) cc -shared -fPIC -o "$w/lib/spawn_count.so" "$here/spawn_count.c" -ldl; shim="LD_PRELOAD=$w/lib/spawn_count.so" ;;
esac
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name, ver, extra in (('alpha', '1.0', {}), ('beta', '2.0', {}), ('gamma', '1.0', {'./postinst': (b'#!/bin/sh\ntouch %s/post.ran\n' % w.encode(), 0o755)})):
    ctl = b'Package: %s\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s check\n' % (name.encode(), ver.encode(), name.encode())
    ctls = [('./control', ctl, 0o644)] + [(k, v[0], v[1]) for k, v in extra.items()]
    pkg = ipk(ctls, [('./f_%s' % name, b'x\n', 0o644)])
    fn = '%s_%s_m68k-amigaos.ipk' % (name, ver)
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
u() { "$upkg" -f "$w/conf" "$@"; }
u update >/dev/null 2>&1 || fail "set-up: update"
u install beta >/dev/null 2>&1 || fail "set-up: install beta"
run() { # KEYS-FILE -> $w/out, $w/count
    : > "$w/count"
    "$ptyrun" -s 100x30 -t 20 "$1" "$w/out" env LANG=C TERM=vtcon TERMINFO="$root/build/tools/terminfo" \
        "$shim" SPAWN_COUNT_FILE="$w/count" "$upkg" -f "$w/conf" browse >"$w/run.log" 2>&1 || :
}
printf '300 \\r\n600 \\e\n600 q\n' > "$w/keys1"
run "$w/keys1"
for want in 'alpha' 'beta' 'gamma' 'available' 'installed'; do
    grep -q "$want" "$w/out" || fail "list shows no '$want'"
done
grep -q 'Description\|Version' "$w/out" || fail "Enter showed no info box"
n=$(wc -c <"$w/count" | tr -d ' ')
[ "$n" = 0 ] || fail "list and info made $n child processes"
# positive control: the shim sees the postinst child of an install
: > "$w/count"; "$ptyrun" -t 20 /dev/null "$w/ctl" env "$shim" SPAWN_COUNT_FILE="$w/count" "$upkg" -f "$w/conf" install gamma >/dev/null 2>&1 || :
c=$(wc -c <"$w/count" | tr -d ' ')
[ "$c" -gt 0 ] || fail "positive control: the shim counted no child for an install with a postinst"
u remove gamma >/dev/null 2>&1 || :
# install from the list: alpha is first row, press i
printf '300 i\n1500 \\r\n600 q\n' > "$w/keys2"
run "$w/keys2"
u list-installed 2>&1 | grep -q '^alpha' || fail "install key did not install alpha: $(u list-installed 2>&1)"
echo "[OK] upkg browse: rows with statuses, info box and back with 0 child processes (control: $c), install runs in process"
