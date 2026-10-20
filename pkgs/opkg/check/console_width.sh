#!/bin/sh
# console_width.sh UPKG: host check that upkg's output follows the console width (patches/0009).
# Under a pseudo-terminal of 40, 76, 80 and 120 columns (tools/ptyrun, built here when missing) every
# line of `upkg --help`, of a list against a two-package feed, of `info` and of an error message is at
# most that wide; at 120 columns lines really are longer than 76; a word longer than the line (a URL)
# breaks hard and loses nothing. Piped, nothing wraps: --help equals check/help_piped.txt (what patch
# 0008 printed), a list row is one line.
#   sh pkgs/opkg/check/console_width.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/conwidth.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -Wall -O2 -o "$w/ptyrun" "$here/../../../tools/ptyrun.c" 2>"$w/cc.err" || { echo "[FAIL] ptyrun: $(cat "$w/cc.err")"; exit 1; }
: > "$w/keys"
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
url = 'http://example.invalid/' + 'a' * 70
desc = {
  'widetest': 'A package whose description is long enough to wrap on a narrow console and to run well past seventy-six columns on a wide one, with ordinary words only.\n second line of the description, indented by one blank',
  'urltest': 'Fetch it from ' + url + ' when needed',
}
text = b''
for name, d in desc.items():
    ctl = ('Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s\n' % (name, d)).encode()
    pkg = ipk([('./control', ctl)], [('./marker', b'x\n')])
    open('%s/feed/%s_1.0_m68k-amigaos.ipk' % (w, name), 'wb').write(pkg)
    text += b'\n' + stanza(ctl, '%s_1.0_m68k-amigaos.ipk' % name, pkg)
write_index('%s/feed/Packages.gz' % w, text)
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root /"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
"$upkg" -f "$w/conf" -o "$w/root" update >/dev/null 2>"$w/err" || { echo "[FAIL] update: $(cat "$w/err")"; exit 1; }
url=http://example.invalid/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
bad=no-such-package-with-a-very-long-name-that-cannot-possibly-fit-in-forty-columns

# run NAME COLUMNS ARGS...: what upkg draws on a COLUMNS-wide terminal, carriage returns removed
run() {
  name=$1 cols=$2; shift 2
  rm -f "$w/o.$name.$cols"
  "$w/ptyrun" -s ${cols}x24 "$w/keys" "$w/o.$name.$cols" "$upkg" -f "$w/conf" -o "$w/root" "$@" >/dev/null
  tr -d '\r' < "$w/o.$name.$cols" > "$w/t.$name.$cols"
}
# maxlen FILE: the longest line
maxlen() { awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$1"; }

for cols in 40 76 80 120; do
  run help $cols --help
  run list $cols list
  run info $cols info urltest
  run err $cols install $bad
  for n in help list info err; do
    m=$(maxlen "$w/t.$n.$cols")
    [ "$(wc -l < "$w/t.$n.$cols")" -ge 1 ] || { echo "[FAIL] $n at $cols columns printed too little: $(head -3 "$w/t.$n.$cols")"; exit 1; }
    [ "$m" -le "$cols" ] || { echo "[FAIL] $n at $cols columns has a line of $m columns: $(awk -v c=$cols 'length($0) > c { print; exit }' "$w/t.$n.$cols")"; exit 1; }
  done
  # nothing lost: the URL (a word longer than any line at 40 columns) is all there, in order
  for n in list info; do
    tr -d ' \n' < "$w/t.$n.$cols" | grep -q "$url" || { echo "[FAIL] $n at $cols columns lost part of the URL"; exit 1; }
  done
  tr -d ' \n' < "$w/t.err.$cols" | grep -q "$bad" || { echo "[FAIL] error at $cols columns lost part of the name"; exit 1; }
  echo "[OK] upkg at $cols columns: help $(maxlen "$w/t.help.$cols"), list $(maxlen "$w/t.list.$cols"), info $(maxlen "$w/t.info.$cols"), error $(maxlen "$w/t.err.$cols") (limit $cols)"
done

# wide windows use the room
for n in help list; do
  m=$(maxlen "$w/t.$n.120")
  [ "$m" -gt 76 ] || { echo "[FAIL] $n at 120 columns still stops at $m"; exit 1; }
done
echo "[OK] upkg at 120 columns uses the room: help $(maxlen "$w/t.help.120"), list $(maxlen "$w/t.list.120") columns"

# piped: nothing wraps, output as opkg printed it
"$upkg" --help 2>&1 | cat > "$w/piped.help" || true
cmp -s "$w/piped.help" "$here/help_piped.txt" || { echo "[FAIL] piped --help differs from check/help_piped.txt"; diff "$w/piped.help" "$here/help_piped.txt" | head -5; exit 1; }
"$upkg" -f "$w/conf" -o "$w/root" list | cat > "$w/piped.list"
[ "$(wc -l < "$w/piped.list")" -eq 3 ] || { echo "[FAIL] piped list is not three lines: $(cat "$w/piped.list")"; exit 1; }
grep -q "^urltest - 1.0 - Fetch it from $url when needed\$" "$w/piped.list" || { echo "[FAIL] piped list row was changed: $(cat "$w/piped.list")"; exit 1; }
"$upkg" -f "$w/conf" -o "$w/root" install $bad 2>&1 | cat > "$w/piped.err" || true
grep -q "$bad" "$w/piped.err" && [ "$(wc -l < "$w/piped.err")" -le 2 ] || { echo "[FAIL] piped error wrapped: $(cat "$w/piped.err")"; exit 1; }
echo "[OK] upkg piped: --help equals check/help_piped.txt, list rows and errors on one line"
