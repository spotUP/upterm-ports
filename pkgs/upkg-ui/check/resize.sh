#!/bin/sh
# resize.sh UPKG-UI: host check that a resize repaints the whole dialog, not only the cells
# ncurses believes changed. upkg-ui draws on vtcon's normal screen, which vtcon reflows on a
# resize (vtengine.c vt_resize: only the primary screen reflows), so after a resize the
# terminal holds whatever the reflow left, not what ncurses last sent. ncurses repaints all
# (clearok in resizeterm) only when the size it reads has changed; a KEY_RESIZE whose size it
# already knows (a second SIGWINCH, a size read before the console updated it) sent only the
# diff, nothing, and the reflowed rows stayed on the screen (owner, A1200: every second row
# blank after a Shell resize in upkg browse). This sends SIGWINCH with the size unchanged and
# wants the dialog drawn again in full.
#   sh pkgs/upkg-ui/check/resize.sh build/host/upkg-ui/inst/bin/upkg-ui
set -eu
bin=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$bin" <<'PY'
import os, sys, pty, select, time, signal, fcntl, termios, struct

bin = sys.argv[1]

def slurp(m, sec):
    out, t = b"", time.time()
    while time.time() - t < sec:
        r, _, _ = select.select([m], [], [], 0.2)
        if r:
            try:
                d = os.read(m, 65536)
            except OSError:
                break
            if not d:
                break
            out += d
    return out

pid, m = pty.fork()
if pid == 0:
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    os.execv(bin, [bin, "--msgbox", "Hello", "0", "0"])
first = slurp(m, 1.5)
os.kill(pid, signal.SIGWINCH)
after = slurp(m, 1.5)
os.kill(pid, signal.SIGKILL)
os.waitpid(pid, 0)
ok = b"Hello" in first and b"Hello" in after
print("resize repaint %s (first draw %d bytes, after SIGWINCH %d bytes, dialog drawn again: %s)"
      % ("ok" if ok else "FAIL", len(first), len(after), "yes" if b"Hello" in after else "no"))
sys.exit(0 if ok else 1)
PY
