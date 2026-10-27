#!/bin/sh
# rightkey.sh UPKG-UI: host check that the Right arrow ends a menu as hotkey UI_HOTKEY_RIGHT (6) when the
# caller lists it, and does nothing when it does not (run 2: Right, then Enter, gives 0).
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)   # the loop hands every check inst/bin/upkg-ui, as for keyfd.sh
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
nc=$root/build/host/ncurses/inst
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
w=$(mktemp -d "${TMPDIR:-/tmp}/rightkey.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O2 -Wall -I"$inst/include" -I"$nc/include/ncursesw" -I"$nc/include" -o "$w/drv" "$here/rightkey.c" \
  "$inst/lib/libupkgui.a" -L"$nc/lib" -lncursesw
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$w" <<'PY'
import os, sys, time, fcntl, termios, struct, select
w = sys.argv[1]
m, s = os.openpty()
fcntl.ioctl(s, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
pid = os.fork()
if pid == 0:
    os.setsid(); fcntl.ioctl(s, termios.TIOCSCTTY, 0)
    for fd in (0, 1): os.dup2(s, fd)
    os.execv(w + "/drv", [w + "/drv", w + "/out"])
os.close(s)
def drain(secs):
    end = time.time() + secs
    while time.time() < end:
        if select.select([m], [], [], 0.1)[0]:
            try: os.read(m, 65536)
            except OSError: return
drain(1.0); os.write(m, b"\033OC"); drain(0.7); os.write(m, b"\033OC"); drain(0.4); os.write(m, b"\r"); drain(0.7)
end = time.time() + 5
while time.time() < end:
    p, _ = os.waitpid(pid, os.WNOHANG)
    if p: break
    time.sleep(0.05)
else:
    os.kill(pid, 9); print("[FAIL] rightkey: driver hung"); sys.exit(1)
got = open(w + "/out").read().split() if os.path.exists(w + "/out") else []
want = ["6", "0"]
if got == want: print("[OK] rightkey: hotkeys %s" % got)
else: print("[FAIL] rightkey: hotkeys %s, want %s (Right must end a menu only when UI_HOTKEY_RIGHT is listed)" % (got, want)); sys.exit(1)
PY
