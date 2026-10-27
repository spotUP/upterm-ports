#!/bin/sh
# restart.sh UPKG-UI: host check that ui_stop is the full inverse of ui_start: one process runs
# ui_start, a menu, ui_stop, the terminal is resized 80x24 -> 100x40, then ui_start, a menu, ui_stop.
# Both screens must see their own size, the second menu must return its own choice (Down, Enter ->
# row 1; the first gets Enter -> row 0) and no file descriptor may stay open (keyfp was never closed).
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)   # the loop hands every check inst/bin/upkg-ui, as for keyfd.sh
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
nc=$root/build/host/ncurses/inst
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
w=$(mktemp -d "${TMPDIR:-/tmp}/restart.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O2 -Wall -I"$inst/include" -I"$nc/include/ncursesw" -I"$nc/include" -o "$w/drv" "$here/restart.c" \
  "$inst/lib/libupkgui.a" -L"$nc/lib" -lncursesw
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$w" <<'PY'
import os, sys, time, fcntl, termios, struct, select
w = sys.argv[1]
m, s = os.openpty()
def size(r, c): fcntl.ioctl(m, termios.TIOCSWINSZ, struct.pack("HHHH", r, c, 0, 0))
size(24, 80)
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
def hung():
    os.kill(pid, 9); print("[FAIL] restart: driver hung"); sys.exit(1)
drain(1.0); os.write(m, b"\r")
end = time.time() + 5
while not os.path.exists(w + "/out"):
    if time.time() > end: hung()
    drain(0.1)
size(40, 100); open(w + "/out.go", "w").close()
drain(1.0); os.write(m, b"\033OB"); drain(0.4); os.write(m, b"\r"); drain(0.5)
end = time.time() + 5
while True:
    p, _ = os.waitpid(pid, os.WNOHANG)
    if p: break
    if time.time() > end: hung()
    drain(0.05)
got = open(w + "/out").read().split()
want = ["0", "24", "80", "1", "40", "100", "0"]
if got == want: print("[OK] restart: %s" % got)
else: print("[FAIL] restart: %s, want %s (selected/rows/cols of both runs, leaked fds)" % (got, want)); sys.exit(1)
PY
