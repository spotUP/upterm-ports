#!/bin/sh
# pipe_lines.sh UPKG: host check of patches/0024: through a pipe upkg writes each line when it
# is written, not at exit. The browse dialogs read `upkg update` / `upkg install` through a pipe
# into a programbox and must show progress while the command runs.
#   Two feeds: the first is a good file:// one, the second is an http server on 127.0.0.1 that
#   holds the answer until this script creates a file. The first feed's "Updated source" line must reach the reader while upkg is
#   still running (upkg blocked on the second); then the server is released and upkg exits.
#   Before the patch stdout was fully buffered and the line came out at exit only.
#   sh pkgs/opkg/check/pipe_lines.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/pipel.XXXXXX")
cleanup() {
  [ -z "${pid:-}" ] || kill "$pid" 2>/dev/null || :
  [ -z "${rpid:-}" ] || kill "$rpid" 2>/dev/null || :
  [ -z "${spid:-}" ] || { kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null; } || :
  [ -n "${KEEP:-}" ] || rm -rf "$w"
}
trap cleanup EXIT
mkdir "$w/one"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
ctl = b'Package: alpha\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: alpha check\n'
pkg = ipk([('./control', ctl, 0o644)], [('./f_alpha', b'x\n', 0o644)])
open('%s/one/alpha_1.0_m68k-amigaos.ipk' % w, 'wb').write(pkg)
write_index('%s/one/Packages.gz' % w, stanza(ctl, 'alpha_1.0_m68k-amigaos.ipk', pkg) + b'\n')
PY
mkfifo "$w/out"
python3 -I - "$w" <<'PY' &
import http.server, os, sys
w = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        while not os.path.exists(w + '/release'):
            import time; time.sleep(0.05)
        self.send_response(200); self.send_header('Content-Length', '0'); self.end_headers()
    def log_message(self, *a): pass
srv = http.server.ThreadingHTTPServer(('127.0.0.1', 0), H)
open(w + '/port.tmp', 'w').write(str(srv.server_address[1])); os.rename(w + '/port.tmp', w + '/port')
srv.serve_forever()
PY
spid=$!
n=0; until [ -f "$w/port" ]; do n=$((n + 1)); [ $n -le 100 ] || { echo "[FAIL] test server did not start"; exit 1; }; sleep 0.1; done
{ echo "arch m68k-amigaos 10"; echo "src/gz one file://$w/one"; echo "src two http://127.0.0.1:$(cat "$w/port")"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
fail() { echo "[FAIL] $*"; exit 1; }

# reader: appends each line to $w/seen as it arrives
: > "$w/seen"
( while IFS= read -r l; do printf '%s\n' "$l" >> "$w/seen"; done < "$w/out" ) &
rpid=$!
"$upkg" -f "$w/conf" update > "$w/out" 2>&1 &
pid=$!
n=0
until grep -q "Updated source 'one'" "$w/seen"; do
  n=$((n + 1)); [ $n -le 100 ] || fail "no 'Updated source' line within 10 s while upkg ran (seen: $(cat "$w/seen"))"
  kill -0 "$pid" 2>/dev/null || fail "upkg exited before the line was seen (seen: $(cat "$w/seen"))"
  sleep 0.1
done
kill -0 "$pid" 2>/dev/null || fail "upkg had already exited when the first line arrived: not a live pipe"
# release the second feed; upkg may fail or succeed on the empty list, only that it ends matters
: > "$w/release"
n=0
while kill -0 "$pid" 2>/dev/null; do
  n=$((n + 1)); [ $n -le 100 ] || fail "upkg did not exit after the second feed was released"
  sleep 0.1
done
wait "$pid" 2>/dev/null || :; pid=
wait "$rpid" 2>/dev/null || :; rpid=
echo "[OK] upkg through a pipe: the first line reached the reader while upkg was still running"
