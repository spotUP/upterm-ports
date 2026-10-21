#!/bin/sh
# keyfd.sh UPKG-UI: host check that upkg-ui reads its keys from a terminal it really has, and
# ends (exit 3) when there is none or it goes away, instead of spinning (UPKG-UI-SPIN).
# On the rig an ixemul program under vsh (sh) has no controlling terminal: /dev/tty opened the
# process's console, NIL: under ptyrun, which selects ready and reads 0 at once, so get_wch gave
# ERR in a tight loop, every ERR counted as a one-second tick, and the keys on the pty were never
# read. The host has the same shape with a session that has no controlling terminal:
#   ctty-less  setsid, no TIOCSCTTY, stdin /dev/null, stdout the pty: Enter on the pty ends the
#              msgbox with exit 0 (unfixed: keys from /dev/null, spins, killed after 8 s)
#   hangup     the pty's master closes under a running msgbox: exit 3 (unfixed: spins)
#   none       no terminal anywhere: exit 3 at once with a message
#   sh pkgs/upkg-ui/check/keyfd.sh build/host/upkg-ui/inst/bin/upkg-ui
set -eu
bin=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
w=$(mktemp -d "${TMPDIR:-/tmp}/keyfd.XXXXXX")
trap 'rm -rf "$w"' EXIT
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$bin" "$w" <<'EOF'
import os, sys, time, signal, select, fcntl, termios, struct

bin, w = sys.argv[1], sys.argv[2]
MSG = [bin, "--msgbox", "Hello", "0", "0"]

def spawn(ctty, stdout_pty=True):
    """upkg-ui in a session of its own; returns (pid, master fd or None)."""
    m = s = None
    if stdout_pty:
        m, s = os.openpty()
        fcntl.ioctl(s, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    pid = os.fork()
    if pid == 0:
        try:
            os.setsid()
            signal.signal(signal.SIGHUP, signal.SIG_IGN)  # the rig has no SIGHUP: the read must end it
            if ctty:
                fcntl.ioctl(s, termios.TIOCSCTTY, 0)
            n = os.open(os.devnull, os.O_RDWR)
            os.dup2(s if ctty else n, 0)
            os.dup2(s if stdout_pty else os.open(os.path.join(w, "out"), os.O_WRONLY | os.O_CREAT), 1)
            os.dup2(os.open(os.path.join(w, "err"), os.O_WRONLY | os.O_CREAT | os.O_TRUNC), 2)
            os.execv(bin, MSG)
        finally:
            os._exit(127)
    if s is not None:
        os.close(s)
    return pid, m

def drain(m, secs):
    end = time.time() + secs
    while m is not None and time.time() < end:
        if select.select([m], [], [], 0.1)[0]:
            try:
                os.read(m, 65536)
            except OSError:
                return

def wait(pid, secs):
    end = time.time() + secs
    while time.time() < end:
        p, st = os.waitpid(pid, os.WNOHANG)
        if p:
            return os.waitstatus_to_exitcode(st)
        time.sleep(0.05)
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
    return "hung (killed after %d s)" % secs

def err():
    try:
        return open(os.path.join(w, "err")).read().strip()
    except OSError:
        return ""

bad = 0
def verdict(name, got, want, why):
    global bad
    if got == want:
        print("[OK] upkg-ui %s: exit %s" % (name, got))
    else:
        bad = 1
        print("[FAIL] upkg-ui %s: %s, want exit %s (%s) %s" % (name, got, want, why, err()))

pid, m = spawn(ctty=False)
drain(m, 1.5)
os.write(m, b"\r")
drain(m, 0.5)
verdict("ctty-less", wait(pid, 8), 0, "keys from stdout's pty")
os.close(m)

pid, m = spawn(ctty=True)
drain(m, 1.5)
os.close(m)
verdict("hangup", wait(pid, 8), 3, "the terminal went away")

pid, m = spawn(ctty=False, stdout_pty=False)
verdict("none", wait(pid, 8), 3, "no terminal")
sys.exit(bad)
EOF
