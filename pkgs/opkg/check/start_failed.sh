#!/bin/sh
# start_failed.sh UPKG: host check of patches/0035: a start that cannot make its temporary drawer (ixemul maps /tmp
# to TMP:, so an Amiga without `Assign TMP: T:` fails here) says why. A Shell start prints the reason on stderr and exits
# non-zero (it used to end as "Unknown command"); an argc == 0 start (a Workbench icon) calls upkg_start_failed once,
# which on the host appends "startup failed: <reason>" to $UPKG_WB_LOG (the Amiga build shows an EasyRequest), and never
# reaches upkg_wb. A start with a good tmp_dir logs no such line.
#   sh pkgs/opkg/check/start_failed.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/startfail.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/etc" "$w/tmp"
cc -O1 -Wall -o "$w/wb_exec" "$here/wb_exec.c"
conf() { # conf TMPDIR
  { echo "arch m68k-amigaos 10"; echo "dest root /"; echo "option tmp_dir $1"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"
}
mkdir "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
log=$w/wb.log

# Shell start, tmp_dir missing: reason on stderr, rc non-zero
conf "$w/absent"
rc=0
env OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$upkg" list-installed > "$w/sh.out" 2>&1 || rc=$?
[ "$rc" != 0 ] || { echo "[FAIL] start_failed: a start without a temporary drawer exited 0"; exit 1; }
grep -q 'upkg cannot make its temporary drawer .*absent.*: No such file or directory\. Is TMP: assigned' "$w/sh.out" ||
  { cat "$w/sh.out"; echo "[FAIL] start_failed: the Shell start does not name the reason on stderr"; exit 1; }
[ ! -e "$log" ] || { cat "$log"; echo "[FAIL] start_failed: a Shell start used the Workbench report"; exit 1; }

# icon start (argc == 0), tmp_dir missing: one reason line in the log, no window
rc=0
env OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$w/wb_exec" "$upkg" > "$w/wb.out" 2>&1 || rc=$?
[ "$rc" != 0 ] || { echo "[FAIL] start_failed: the icon start without a temporary drawer exited 0"; exit 1; }
n=$(grep -c '^startup failed: upkg cannot make its temporary drawer ' "$log" || true)
[ "$n" = 1 ] || { cat "$log"; echo "[FAIL] start_failed: $n startup-failed lines for the icon start, wanted 1"; exit 1; }
! grep -q '^window opened' "$log" || { echo "[FAIL] start_failed: upkg_wb ran after the failed start"; exit 1; }

# a good tmp_dir: no such line
rm -f "$log"; conf "$w/tmp"
env OPKG_CONF_DIR="$w/etc" UPKG_WB_LOG="$log" "$w/wb_exec" "$upkg" > "$w/ok.out" 2>&1 || { cat "$w/ok.out"; echo "[FAIL] start_failed: the icon start with a temporary drawer failed"; exit 1; }
! grep -q '^startup failed' "$log" || { cat "$log"; echo "[FAIL] start_failed: a good start logged a failure"; exit 1; }
echo "[OK] start_failed: a missing temporary drawer is named on stderr (Shell) and once in the icon-start report, upkg_wb not reached"
