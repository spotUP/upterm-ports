#!/bin/sh
# hotstale.sh INST-DIR: host check that ui_hotkey() describes the LAST ui_run only. A menu shown
# twice (ui_prepare + ui_run, no ui_view) used to keep the first run's hotkey, so the Enter that
# accepted the second run still read as the typed key (amarchy-menu: "st" then Enter gave
# "Filter: stt"). Keys 's' then Enter: run 1 must report 's', run 2 must report 0 (Enter).
#   sh pkgs/upkg-ui/check/hotstale.sh build/host/upkg-ui/inst
set -eu
inst=$(cd "$1" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
nc=$root/build/host/ncurses/inst
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
w=$(mktemp -d "${TMPDIR:-/tmp}/hotstale.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O2 -Wall -I"$inst/include" -I"$nc/include/ncursesw" -I"$nc/include" -o "$w/drv" "$here/hotstale.c" \
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
drain(1.0); os.write(m, b"s"); drain(0.7); os.write(m, b"\r"); drain(0.7)
end = time.time() + 5
while time.time() < end:
    p, _ = os.waitpid(pid, os.WNOHANG)
    if p: break
    time.sleep(0.05)
else:
    os.kill(pid, 9); print("[FAIL] hotstale: driver hung"); sys.exit(1)
got = open(w + "/out").read().split() if os.path.exists(w + "/out") else []
want = [str(ord("s")), "0"]
if got == want: print("[OK] hotstale: hotkeys %s" % got)
else: print("[FAIL] hotstale: hotkeys %s, want %s (stale hotkey after a second run)" % (got, want)); sys.exit(1)
PY
