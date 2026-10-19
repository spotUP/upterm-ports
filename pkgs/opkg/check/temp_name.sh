#!/bin/sh
# temp_name.sh UPKG: host check that every temp name upkg makes under its tmp_dir fits AmigaDOS
# FFS (30 characters; ixemul refuses longer new names with ENAMETOOLONG). Stock opkg 0.9.0 names
# them after the package or the cache file ("<cache name>.control.XXXXXX", 45 characters with the
# 30 hex digit cache names of patches/0003), so on the Amiga `upkg install --force-reinstall` of
# an add-on failed with "Failed to make temp file ... File name too long". The preload shim
# ffs_names.c gives the host the same refusal under the work dir. A file:// feed of one package
# with a 30 character name: install, then --force-reinstall, must both succeed.
#   sh pkgs/opkg/check/temp_name.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/tempname.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/tmp"
if [ "$(uname)" = Darwin ]; then
  cc -dynamiclib -o "$w/ffs_names.so" "$here/ffs_names.c"
  preload="DYLD_INSERT_LIBRARIES=$w/ffs_names.so"
else
  cc -shared -fPIC -o "$w/ffs_names.so" "$here/ffs_names.c" -ldl
  preload="LD_PRELOAD=$w/ffs_names.so"
fi
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
name = 'UP-Term-temp-name-check-abcdef'
assert len(name) == 30
ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: temp name check\n' % name.encode()
fn = '%s_1.0_m68k-amigaos.ipk' % name
pkg = ipk([('./control', ctl)], [('./marker', b'installed\n')])
open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
write_index('%s/feed/Packages.gz' % w, stanza(ctl, fn, pkg))
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root /"; echo "option tmp_dir $w/tmp"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/c.conf"
run() { env FFS_ROOT="$w/tmp" "$preload" "$upkg" -f "$w/c.conf" -o "$w/root" "$@" >/dev/null 2>"$w/err"; }
# the shim must bite, or the check proves nothing (a probe of our own: macOS strips DYLD_* from /bin)
printf '#include <stdlib.h>\nint main(int c, char **v) { (void)c; return mkstemp(v[1]) < 0; }\n' > "$w/probe.c"
cc -o "$w/probe" "$w/probe.c"
if env FFS_ROOT="$w/tmp" "$preload" "$w/probe" "$w/tmp/0123456789012345678901234XXXXXX"; then
  echo "[FAIL] test setup: the ffs_names shim did not refuse a 31 character name"; exit 1
fi
run update || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
run install UP-Term-temp-name-check-abcdef || { echo "[FAIL] install: $(cat "$w/err")"; exit 1; }
[ -f "$w/root/marker" ] || { echo "[FAIL] install left no marker"; exit 1; }
rm "$w/root/marker"
run install --force-reinstall UP-Term-temp-name-check-abcdef || { echo "[FAIL] reinstall: $(cat "$w/err")"; exit 1; }
[ -f "$w/root/marker" ] || { echo "[FAIL] reinstall left no marker"; exit 1; }
echo "[OK] opkg temp names: install and --force-reinstall make no temp name over 30 characters"
