#!/bin/sh
# no_usergroup.sh BINARY: host check that a curl binary needs no usergroup.library and
# reaches the network through bsdsocket.library. The Aminet curl (libnet) fails the first test.
#   sh pkgs/curl/check/no_usergroup.sh build/sysroot/UP-Term/bin/curl
set -eu
b=$1
[ -f "$b" ] || { echo "[FAIL] missing: $b"; exit 1; }
if strings "$b" | grep -q 'usergroup\.library'; then echo "[FAIL] curl: names usergroup.library (needs an AmiTCP drawer)"; exit 1; fi
strings "$b" | grep -q 'bsdsocket\.library' || { echo "[FAIL] curl: does not name bsdsocket.library"; exit 1; }
echo "[OK] curl: no usergroup.library, opens bsdsocket.library"
