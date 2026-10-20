#!/bin/sh
# help_flag.sh UPKG: host check that `upkg --help` prints the usage text alone and exits 0 (patches/0011).
# Stock opkg has no --help: getopt reports "unrecognized option", then the usage is printed with exit 1.
# A really unknown option must still be reported.
#   sh pkgs/opkg/check/help_flag.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/helpflag.XXXXXX")
trap 'rm -rf "$w"' EXIT
rc=0
"$upkg" --help >"$w/out" 2>"$w/err" || rc=$?
[ "$rc" -eq 0 ] || { echo "[FAIL] upkg --help exited $rc"; exit 1; }
if grep -qi unrecognized "$w/out" "$w/err"; then echo "[FAIL] upkg --help reports an unrecognized option: $(cat "$w/err")"; exit 1; fi
[ ! -s "$w/err" ] || { echo "[FAIL] upkg --help wrote to stderr: $(head -2 "$w/err")"; exit 1; }
grep -q '^usage: upkg \[options' "$w/out" || { echo "[FAIL] upkg --help printed no usage text"; exit 1; }
rc=0
"$upkg" --nosuch >"$w/out2" 2>"$w/err2" || rc=$?
grep -q "unrecognized option .--nosuch'" "$w/err2" || { echo "[FAIL] upkg --nosuch no longer reports it: $(cat "$w/err2")"; exit 1; }
[ "$rc" -ne 0 ] || { echo "[FAIL] upkg --nosuch exited 0"; exit 1; }
echo "[OK] upkg --help: usage only, exit 0; --nosuch still unrecognized (exit $rc)"
