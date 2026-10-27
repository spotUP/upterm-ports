#!/bin/sh
# tls.sh BINARY: host check that a curl binary was built with AmiSSL TLS and talks to bsdsocket.library directly.
# Plain --with-amissl configures to "no TLS" silently when the bsdsocket probe fails (header clash), so this fails then.
#   sh pkgs/curl/check/tls.sh build/sysroot/UP-Term/bin/curl
set -eu
b=$1
[ -f "$b" ] || { echo "[FAIL] missing: $b"; exit 1; }
for n in amisslmaster.library bsdsocket.library; do
	strings "$b" | grep -q "$n" || { echo "[FAIL] curl: does not name $n (no AmiSSL TLS build)"; exit 1; }
done
strings "$b" | grep -q 'AmiSSL' || { echo "[FAIL] curl: no AmiSSL string"; exit 1; }
echo "[OK] curl: AmiSSL TLS, bsdsocket.library direct"
