#!/bin/sh
# curl_argv.sh UPKG: host check of the P10.3 download backend. A fake curl on PATH records its
# argv and exits 22 (HTTP error): the backend must call `curl -fsSL -o <dest> <src>` and upkg
# must turn the non-zero exit into a failed update. Used with the host build:
#   sh pkgs/opkg/check/curl_argv.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/curlargv.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/fake"
printf '#!/bin/sh\necho "$@" > %s/argv\nexit 22\n' "$w" > "$w/fake/curl"
chmod +x "$w/fake/curl"
{ echo "src/gz test http://127.0.0.1:1/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/upkg.conf"
if PATH="$w/fake:$PATH" "$upkg" -f "$w/upkg.conf" update 2>"$w/err"; then echo "[FAIL] update succeeded with a failing curl"; exit 1; fi
read -r a1 a2 a3 a4 a5 < "$w/argv"
[ "$a1 $a2 $a4" = "-fsSL -o http://127.0.0.1:1/feed/Packages.gz" ] || { echo "[FAIL] argv: $(cat "$w/argv")"; exit 1; }
case $a3 in "$w"/cache_dir/*) b=${a3##*/}; [ ${#b} -eq 30 ] || { echo "[FAIL] dest: $a3"; exit 1; } ;; *) echo "[FAIL] dest: $a3"; exit 1 ;; esac
grep -q 'curl returned 22' "$w/err" || { echo "[FAIL] no curl error text"; exit 1; }
echo "[OK] opkg download backend: curl -fsSL -o <dest> <src>, exit 22 -> failed update"
