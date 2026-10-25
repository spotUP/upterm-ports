#!/bin/sh
# status_write_rc.sh UPKG: host check for patches/0028 (a status file that cannot be written or closed makes upkg exit non-zero).
# On a full disk the status file is truncated and fclose reports ENOSPC; write_status_files_if_changed ignored it and
# `upkg install|remove|flag` exited 0 over a damaged database. A full disk is not available on a host, so RLIMIT_FSIZE
# (ulimit -f, SIGXFSZ ignored) gives the same write/close failure (EFBIG) for a status file larger than the limit.
#   sh pkgs/opkg/check/status_write_rc.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/statusrc.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/root" "$w/lists" "$w/info" "$w/cache"
{ echo "arch m68k-amigaos 10"; echo "dest root $w/root"; echo "option lists_dir $w/lists"; echo "option lock_file $w/lock"
  echo "option info_dir $w/info"; echo "option status_file /status"; echo "option cache_dir $w/cache"; } > "$w/conf"
# 40 installed packages: about 4 KB of status, well over the 1 block (512 bytes) limit
i=1
while [ "$i" -le 40 ]; do
  printf 'Package: p%s\nVersion: 1.0\nArchitecture: m68k-amigaos\nStatus: install ok installed\nInstalled-Size: 1\n\n' "$i"
  i=$((i + 1))
done > "$w/root/status"
# control: without the limit the same command succeeds and exits 0
( cd "$w" && "$upkg" -f "$w/conf" flag hold p2 >"$w/out0" 2>"$w/err0" ) || { echo "[FAIL] control: flag hold without a limit exited non-zero: $(head -2 "$w/err0")"; exit 1; }
set +e
( cd "$w" && trap '' XFSZ && ulimit -f 1 && exec "$upkg" -f "$w/conf" flag hold p1 >"$w/out" 2>"$w/err" )
rc=$?
set -e
# the write must really have failed, or the check proves nothing
grep -q "Couldn't close" "$w/err" || { echo "[FAIL] test setup: the status write did not fail (stderr: $(head -2 "$w/err"))"; exit 1; }
if [ "$rc" -eq 0 ]; then
  echo "[FAIL] upkg flag exited 0 although the status file could not be written"; exit 1
fi
echo "[OK] a failed status file write makes upkg exit $rc"
