#!/bin/sh
# name_guard.sh UPKG: host check that upkg refuses to download into a path with a component of
# more than 30 characters. AmigaDOS FFS keeps 30 and cuts the rest silently, and the download is
# an external native curl, so ixemul cannot catch it. With volatile_cache curl writes straight to
# the lists file of a plain (not gz) src; otherwise it writes the 30 hex digit cache file and
# libopkg copies it, which ixemul sees. A src named with 31 characters makes the
# lists file name too long: `upkg update` must fail with the name-too-long error, curl must not
# run for it, and no file may be created. A second src with a short name in the same run must
# still be fetched. The host build compiles the guard through -DUPKG_SHORT_NAMES (recipe host flags).
#   sh pkgs/opkg/check/name_guard.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/nameguard.XXXXXX")
trap 'rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/fake" "$w/lists"
printf 'Package: p\nVersion: 1\nArchitecture: all\nDescription: x\n' > "$w/feed/Packages"
# fake curl (file:// sources never reach curl, so the feed is http://): copies the feed file named by
# the URL to the -o destination and records every destination
printf '#!/bin/sh\nwhile [ $# -gt 2 ]; do shift; done\necho "$1" >> %s/dests\ncp %s/feed/"${2##*/}" "$1"\n' "$w" "$w" > "$w/fake/curl"
chmod +x "$w/fake/curl"
long=0123456789012345678901234567890
[ ${#long} -eq 31 ] || { echo "[FAIL] test setup: long name is ${#long} chars"; exit 1; }
{ echo "src $long http://127.0.0.1:1/feed"; echo "src short http://127.0.0.1:1/feed"; echo "dest root $w/root"
  echo "option lists_dir $w/lists"; echo "option volatile_cache 1"
  for o in lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/upkg.conf"
if PATH="$w/fake:$PATH" "$upkg" -f "$w/upkg.conf" update >"$w/out" 2>"$w/err"; then
  echo "[FAIL] update succeeded with a 31 character src name"; exit 1
fi
grep -q 'name too long\|too long' "$w/err" || { echo "[FAIL] no name-too-long error: $(cat "$w/err")"; exit 1; }
grep -q '30 characters' "$w/err" || { echo "[FAIL] error does not name the 30 character limit: $(cat "$w/err")"; exit 1; }
[ ! -e "$w/lists/$long" ] || { echo "[FAIL] the long-named lists file was created"; exit 1; }
if [ -f "$w/dests" ] && grep -q "$long" "$w/dests"; then echo "[FAIL] curl ran for the long name"; exit 1; fi
[ -f "$w/lists/short" ] || { echo "[FAIL] the short-named src was not fetched: $(cat "$w/err")"; exit 1; }
echo "[OK] opkg name guard: 31 character src name refused without curl or file, short src still fetched"
