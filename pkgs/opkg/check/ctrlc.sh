#!/bin/sh
# ctrlc.sh UPKG: host check of patches/0052: Ctrl-C ends upkg while its child runs. xsystem blocked in
# waitpid (ixemul: never EINTR, and its sleep eats the break), so upkg waited for curl to finish: 23 to 25 s
# against a stalled server. A fake curl that ignores SIGINT (as the Aminet clib2 curl ignores the break) and
# sleeps 30 s stands in for the stalled transfer. SIGINT to upkg must end upkg with 130 within 8 s.
#   sh pkgs/opkg/check/ctrlc.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/ctrlc.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/etc" "$w/bin" "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
printf '#!/bin/sh\ntrap "" INT\nsleep 30\n' > "$w/bin/curl"
chmod +x "$w/bin/curl"
{ echo "arch m68k-amigaos 10"; echo "dest root /"; echo "src/gz feed http://127.0.0.1:9/x"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"
python3 -I - "$upkg" "$w" <<'PY'
import os, signal, subprocess, sys, time
upkg, w = sys.argv[1:3]
env = dict(os.environ, OPKG_CONF_DIR=w + '/etc', PATH=w + '/bin:' + os.environ['PATH'])
p = subprocess.Popen([upkg, 'update'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
time.sleep(2)
t = time.time()
p.send_signal(signal.SIGINT)
try:
    rc = p.wait(timeout=8)
except subprocess.TimeoutExpired:
    p.kill(); subprocess.run(['pkill', '-f', w + '/bin/curl'])
    print('[FAIL] ctrlc: upkg still running 8 s after SIGINT'); sys.exit(1)
dt = time.time() - t
subprocess.run(['pkill', '-f', w + '/bin/curl'])
if rc != 130:
    print('[FAIL] ctrlc: upkg exited %d, wanted 130' % rc); sys.exit(1)
print('[OK] ctrlc: SIGINT ended upkg with 130 in %.1f s while the child ignored it' % dt)
PY
