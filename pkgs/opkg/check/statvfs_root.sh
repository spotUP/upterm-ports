#!/bin/sh
# statvfs_root.sh UPKG: host check that the free-space test survives a root whose statvfs fails (patches/0013).
# ixemul's statfs on "/" fails with EPERM from a plain AmigaDOS Shell ("Only have 0kb available on
# filesystem /"). statvfs_fail.c makes statvfs of the dest root fail the same way; install must measure
# the volume holding info_dir instead and succeed.
#   sh pkgs/opkg/check/statvfs_root.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/statvfs.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/root"
if [ "$(uname)" = Darwin ]; then
  cc -dynamiclib -o "$w/shim.so" "$here/statvfs_fail.c"; preload="DYLD_INSERT_LIBRARIES=$w/shim.so"
else
  cc -shared -fPIC -o "$w/shim.so" "$here/statvfs_fail.c" -ldl; preload="LD_PRELOAD=$w/shim.so"
fi
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
ctl = b'Package: sv\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: statvfs check\nInstalled-Size: 4096\n'
pkg = ipk([('./control', ctl)], [('./marker', b'installed\n')])
open('%s/feed/sv_1.0_m68k-amigaos.ipk' % w, 'wb').write(pkg)
write_index('%s/feed/Packages.gz' % w, stanza(ctl, 'sv_1.0_m68k-amigaos.ipk', pkg))
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/conf"
# the shim must bite, or the check proves nothing (a probe of our own: macOS strips DYLD_* from /bin)
printf '#include <sys/statvfs.h>\nint main(int c, char **v) { struct statvfs f; (void)c; return statvfs(v[1], &f) != 0; }\n' > "$w/probe.c"
cc -o "$w/probe" "$w/probe.c"
if env STATVFS_FAIL="$w/root" "$preload" "$w/probe" "$w/root"; then
  echo "[FAIL] test setup: the statvfs shim did not fail"; exit 1
fi
run() { env STATVFS_FAIL="$w/root" "$preload" "$upkg" -f "$w/conf" "$@" >"$w/out" 2>"$w/err"; }
run update || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
run install sv || { echo "[FAIL] install with statvfs of the root failing: $(cat "$w/err")"; exit 1; }
[ -f "$w/root/marker" ] || { echo "[FAIL] install left no marker"; exit 1; }
echo "[OK] install measured the info_dir volume when statvfs of the root failed"
