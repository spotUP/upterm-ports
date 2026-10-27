#!/bin/sh
# browse_resize.sh UPKG: host check that a terminal resize during an install from `upkg browse` neither
# cuts the install short nor freezes browse (owner, A1200, upkg 1.7: browse froze after a Shell resize
# while an install ran in the live box). The package's postinst prints a line, sleeps, prints more;
# after the first line reaches the screen the pty grows and upkg gets SIGWINCH. Wanted: every
# postinst line in the box, the closing [OK] line, the package installed, Return goes back to the
# list, q leaves browse with exit 0.
#   sh pkgs/opkg/check/browse_resize.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/bresize.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
post = b'#!/bin/sh\necho SLOWONE\nsleep 1\necho SLOWTWO\nsleep 1\necho SLOWTHREE\n'
ctl = b'Package: slow\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: slow check\n'
pkg = ipk([('./control', ctl, 0o644), ('./postinst', post, 0o755)], [('./f_slow', b'x\n', 0o644)])
fn = 'slow_1.0_m68k-amigaos.ipk'
open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
write_index('%s/feed/Packages.gz' % w, stanza(ctl, fn, pkg) + b'\n')
PY
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
"$upkg" -f "$w/conf" update >/dev/null 2>&1 || { echo "[FAIL] set-up: update"; exit 1; }
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
TERM=$term TERMINFO=$ti LANG=C python3 -I - "$upkg" "$w/conf" <<'PY'
import os, sys, pty, select, time, signal, fcntl, termios, struct
upkg, conf = sys.argv[1], sys.argv[2]
out = b""
def pump(sec, want=None):
    global out
    t = time.time()
    while time.time() - t < sec:
        if want is not None and want in out:
            return True
        r, _, _ = select.select([m], [], [], 0.1)
        if r:
            try:
                d = os.read(m, 65536)
            except OSError:
                return want is None
            if not d:
                return want is None
            out += d
    return want is None or want in out
def fail(msg):
    if os.environ.get("DUMP"): open(os.environ["DUMP"], "wb").write(out)
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass
    sys.stdout.write("[FAIL] %s\n" % msg)
    sys.stdout.write(out[-1500:].decode("latin-1").replace("\x1b", "^[") + "\n")
    sys.exit(1)
pid, m = pty.fork()
if pid == 0:
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    os.execv(upkg, [upkg, "-f", conf, "browse"])
pump(3, b"slow") or fail("the list never showed the slow row")
os.write(m, b"i")
pump(8, b"SLOWONE") or fail("the install box never showed the first postinst line")
fcntl.ioctl(m, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
os.kill(pid, signal.SIGWINCH)
pump(10, b"upkg install slow (exit") if b"[OK] upkg install slow" not in out else None
pump(10, b"[OK] upkg install slow") or fail("no closing [OK] line after the resize")
for line in (b"SLOWTWO", b"SLOWTHREE"):
    if line not in out:
        fail("%s missing: the resize cut the postinst output short" % line.decode())
mark = len(out)
os.write(m, b"\r")
t = time.time()
while time.time() - t < 5 and b"installed" not in out[mark:]:
    pump(0.3)
if b"installed" not in out[mark:]:
    fail("Return did not bring back the list with slow installed")
os.write(m, b"q")
t, st = time.time(), None
while time.time() - t < 5:
    pump(0.2)
    r, s = os.waitpid(pid, os.WNOHANG)
    if r:
        st = s
        break
if st is None:
    fail("browse did not leave on q: frozen")
rc = os.waitstatus_to_exitcode(st)
if rc != 0:
    fail("browse exit %d" % rc)
print("[OK] upkg browse: resize during an install keeps the postinst output whole, back to the list, q leaves with 0")
PY
