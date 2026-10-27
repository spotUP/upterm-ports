#!/bin/sh
# curl_msg.sh UPKG: host check of patches/0055: the download error names the cause of the curl exit code
# (upkg_curl_fail_text), not "is curl installed and in PATH?" for every failure. A fake curl exits with each code;
# with no curl on PATH the child cannot be started and the PATH hint stays.
#   sh pkgs/opkg/check/curl_msg.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/curlmsg.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/fake" "$w/empty"
{ echo "src/gz test http://127.0.0.1:1/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/upkg.conf"
fail() { echo "[FAIL] curl_msg: $*"; exit 1; }
run() { # run PATH: the error text of a failing update
  PATH="$1" "$upkg" -f "$w/upkg.conf" update 2>"$w/err" >/dev/null || true
  grep 'Failed to download' "$w/err" | head -1
}
for c in 22:'server answered with an HTTP error' 6:'cannot resolve host' 7:'cannot reach host' \
         28:'timed out' 3:'curl returned 3'; do
  code=${c%%:*}; want=${c#*:}
  printf '#!/bin/sh\nexit %s\n' "$code" > "$w/fake/curl"; chmod +x "$w/fake/curl"
  line=$(run "$w/fake:/usr/bin:/bin")
  case $line in *"$want"*) ;; *) fail "curl exit $code: want '$want', got: $line" ;; esac
  case $line in *"in PATH"*) fail "curl exit $code names the PATH: $line" ;; esac
done
line=$(run "$w/empty")
case $line in *"curl not found"*"in PATH"*) ;; *) fail "no curl on PATH: want 'curl not found ... PATH', got: $line" ;; esac
echo "[OK] curl_msg: 22 HTTP error, 6 resolve, 7 reach, 28 timed out, 3 generic, missing curl names PATH"
