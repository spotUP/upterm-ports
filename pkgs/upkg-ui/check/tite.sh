#!/bin/sh
# tite.sh UPKG-UI: host check that a script running upkg-ui screens one after another does not
# show the Shell between them. Each upkg-ui used to switch the terminal to the alternate screen
# at the start (smcup, \E[?1049h) and back to the normal screen at the exit (rmcup, \E[?1049l),
# so the Shell window came up between every two dialogs of upkg browse and upkg-ask. Like
# dialog, upkg-ui now stays on the normal screen unless --keep-tite asks for the switch:
#   default      after the dialog is drawn nothing switches back to the normal screen
#   --keep-tite  the old switch: rmcup after the dialog, the Shell comes back at the exit
#   sh pkgs/upkg-ui/check/tite.sh build/host/upkg-ui/inst/bin/upkg-ui
set -eu
bin=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$bin" <<'PY'
import os, sys, pty, select, time, signal, fcntl, termios, struct

bin = sys.argv[1]
RMCUP = b"\x1b[?1049l"

def run(extra):
    """a msgbox on a pty, Enter once it has drawn; returns (exit status, bytes written)."""
    pid, m = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        os.execv(bin, [bin] + extra + ["--msgbox", "Hello", "0", "0"])
    out, sent, t = b"", False, time.time()
    while time.time() - t < 8:
        r, _, _ = select.select([m], [], [], 0.3)
        if r:
            try:
                d = os.read(m, 65536)
            except OSError:
                break
            if not d:
                break
            out += d
        elif not sent and b"Hello" in out:
            os.write(m, b"\r")
            sent = True
    for _ in range(30):
        done, st = os.waitpid(pid, os.WNOHANG)
        if done:
            break
        time.sleep(0.1)
    else:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        return "killed", out
    return os.waitstatus_to_exitcode(st), out

fail = 0
for name, extra, want_back in (("default", [], False), ("--keep-tite", ["--keep-tite"], True)):
    rc, out = run(extra)
    drawn = out.rfind(b"Hello")
    back = drawn >= 0 and RMCUP in out[drawn:]
    ok = rc == 0 and drawn >= 0 and back == want_back
    print("tite %-12s %s (exit %s, switches back to the normal screen after the dialog: %s)"
          % (name, "ok" if ok else "FAIL", rc, "yes" if back else "no"))
    fail |= not ok
sys.exit(1 if fail else 0)
PY
