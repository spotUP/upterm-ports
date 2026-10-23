#!/bin/sh
# mkdir_absent_root.sh UPKG: host check for patches/0027 (file_mkdir_hier stops when the parent is the path).
# On the Amiga an absent volume root (NOSUCHVOL:) has itself as parent and does not exist, so
# file_mkdir_hier recursed until the stack overflowed (rig 4, 2026-10-22: browse install to a missing
# volume hung). dirname_self.c makes dirname of "NOSUCHVOL:..." return "NOSUCHVOL:" like the Amiga libc;
# upkg update with lists_dir on that volume must fail with an error, not crash or hang.
#   sh pkgs/opkg/check/mkdir_absent_root.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/mkdirroot.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/root" "$w/cwd"
if [ "$(uname)" = Darwin ]; then
  cc -dynamiclib -o "$w/shim.so" "$here/dirname_self.c"; preload="DYLD_INSERT_LIBRARIES=$w/shim.so"
else
  cc -shared -fPIC -o "$w/shim.so" "$here/dirname_self.c" -ldl; preload="LD_PRELOAD=$w/shim.so"
fi
echo x | gzip > "$w/feed/Packages.gz"
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  echo "option lists_dir NOSUCHVOL:lists"
  for o in lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/conf"
# the shim must bite, or the check proves nothing (a probe of our own: macOS strips DYLD_* from /bin)
printf '#include <libgen.h>\n#include <string.h>\nint main(int c, char **v) { char b[64]; (void)c; strcpy(b, v[1]); return strcmp(dirname(b), "NOSUCHVOL:") != 0; }\n' > "$w/probe.c"
cc -o "$w/probe" "$w/probe.c"
env "$preload" "$w/probe" "NOSUCHVOL:" || { echo "[FAIL] test setup: the dirname shim did not bite"; exit 1; }
# a recursion that does not overflow quickly is a failure too: a 20 s watchdog kills it (macOS strips DYLD_*
# from /usr/bin tools such as perl, so no alarm wrapper)
set +e
( cd "$w/cwd" && env "$preload" "$upkg" -f "$w/conf" update >"$w/out" 2>"$w/err" ) &
pid=$!
( sleep 20; kill -9 "$pid" 2>/dev/null ) 2>/dev/null &
dog=$!
wait "$pid"
rc=$?
kill "$dog" 2>/dev/null; wait "$dog" 2>/dev/null || true
set -e
# upkg reports a failed update as exit 255 (-1); a crash is 128 + signal (134 abort, 139 segv, 137 watchdog)
if [ "$rc" -ne 255 ]; then
  echo "[FAIL] upkg update on an absent volume root exited $rc instead of 255 (recursion in file_mkdir_hier?)"; exit 1
fi
echo "[OK] file_mkdir_hier returned -1 for an absent volume root (upkg exit 255, no crash)"
