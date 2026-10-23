#!/bin/sh
# colorlate.sh UPKG-UI: host check that ui_opt.colors set AFTER ui_start still colours the \Z codes.
# `upkg browse` (patches/0025) starts curses once and turns colours on per menu; the colour table
# used to be built in ui_start only when ui_opt.colors was already set, so every \Z2 row came out in
# the default attribute (rig upkg_browse_rig: 0 green pixels). The row's item "\Z2installed" must
# reach the terminal after an SGR 32 (green foreground).
#   sh pkgs/upkg-ui/check/colorlate.sh build/host/upkg-ui/inst/bin/upkg-ui
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
nc=$root/build/host/ncurses/inst
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
w=$(mktemp -d "${TMPDIR:-/tmp}/colorlate.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O2 -Wall -I"$inst/include" -I"$nc/include/ncursesw" -I"$nc/include" -o "$w/drv" "$here/colorlate.c" \
  "$inst/lib/libupkgui.a" -L"$nc/lib" -lncursesw
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$w" <<'PY'
import os, sys, time, fcntl, termios, struct, select, re
w = sys.argv[1]
m, s = os.openpty()
fcntl.ioctl(s, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
pid = os.fork()
if pid == 0:
    os.setsid(); fcntl.ioctl(s, termios.TIOCSCTTY, 0)
    for fd in (0, 1): os.dup2(s, fd)
    os.execv(w + "/drv", [w + "/drv"])
os.close(s)
got = b""
def drain(secs):
    global got
    end = time.time() + secs
    while time.time() < end:
        if select.select([m], [], [], 0.1)[0]:
            try: got += os.read(m, 65536)
            except OSError: return
drain(1.0); os.write(m, b"\r"); drain(0.7)
end = time.time() + 5
while time.time() < end:
    p, _ = os.waitpid(pid, os.WNOHANG)
    if p: break
    time.sleep(0.05)
else:
    os.kill(pid, 9); print("[FAIL] colorlate: driver hung"); sys.exit(1)
if re.search(rb"\x1b\[32m(\x1b\[[0-9;]*m)*installed", got): print("[OK] colorlate: the \\Z2 row is drawn in green")
else: print("[FAIL] colorlate: no green (SGR 32) before 'installed'"); sys.exit(1)
PY
