#!/bin/sh
# upgrade_new_questions.sh UPKG: host check of patch 0043. A package whose v1 asks Q1 and whose v2 asks Q1 and Q2:
# `upkg upgrade` keeps the Q1 answer given at the install (not asked again, upkg-ask records the question ids in
# info_dir/NAME.answered) and asks Q2. Run on a pseudo terminal (upkg-ask asks only when stdin and stdout are one).
# Then an unattended run (stdin from /dev/null, UPKG_ASK_UNATTENDED set by upkg for Install All) of a v3 with a
# Q3 takes the default for Q3 and still keeps Q1 and Q2.
#   sh pkgs/opkg/check/upgrade_new_questions.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/newq.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed1" "$w/feed2" "$w/feed3" "$w/bin" "$w/root"
cp "$here/upkg-ask.fixture" "$w/bin/upkg-ask"
chmod +x "$w/bin/upkg-ask"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
Q = {'1.0': b'q1|string|Question one?|d1|\n',
     '2.0': b'q1|string|Question one?|d1|\nq2|string|Question two?|d2|\n',
     '3.0': b'q1|string|Question one?|d1|\nq2|string|Question two?|d2|\nq3|string|Question three?|d3|\n'}
for feed, ver in (('feed1', '1.0'), ('feed2', '2.0'), ('feed3', '3.0')):
    name = 'qpkg'
    ctl = b'Package: qpkg\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: qpkg check\nUP-Term-Interactive: yes\n' % ver.encode()
    stage = './T/upkg-stage/qpkg-%s/Files/' % ver
    post = ('#!/bin/sh\nq=$ROOT/T/upkg-stage/qpkg-%s/Files/questions\n'
            '"$ASKBIN/upkg-ask" "$q" "$q.answers" qpkg-%s && . "$q.answers"\n'
            'echo "${q1-}/${q2-}/${q3-}" >> "$ROOT/answers"\n') % (ver, ver)
    pkg = ipk([('./control', ctl, 0o644), ('./postinst', post.encode(), 0o755)],
              [('./share/qpkg/f', b'x\n', 0o644), (stage + 'questions', Q[ver], 0o644)])
    fn = 'qpkg_%s_m68k-amigaos.ipk' % ver
    open('%s/%s/%s' % (w, feed, fn), 'wb').write(pkg)
    write_index('%s/%s/Packages.gz' % (w, feed), stanza(ctl, fn, pkg) + b'\n')
PY
conf() {
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/$1"; echo "dest root $w/root"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
}
# run CMD... on a pseudo terminal, feeding the lines in $FEED; the screen text goes to $w/screen
tty_run() {
  FEED=$1 python3 -I - "$w/screen" "$@" <<'PY'
import os, pty, sys, time, select
out = sys.argv[1]; argv = sys.argv[3:]
feed = os.environ['FEED'].split('|') if os.environ['FEED'] else []
pid, fd = pty.fork()
if pid == 0:
    os.environ['UPKG_ASK_PLAIN'] = '1'
    os.execv(argv[0], argv)
buf = b''; sent = 0; last = time.time()
while True:
    r, _, _ = select.select([fd], [], [], 0.3)
    if r:
        try: d = os.read(fd, 4096)
        except OSError: break
        if not d: break
        buf += d
    if sent < len(feed) and buf.count(b'?') + buf.count(b']:') > sent and not r:
        os.write(fd, (feed[sent] + '\n').encode()); sent += 1
    if os.waitpid(pid, os.WNOHANG)[0]:
        try: buf += os.read(fd, 65536)
        except OSError: pass
        break
    if time.time() - last > 60: os.kill(pid, 9); break
open(out, 'wb').write(buf)
PY
}
export ROOT="$w/root" ASKBIN="$w/bin"
conf feed1
"$upkg" -f "$w/conf" update >/dev/null 2>&1
tty_run "ONE" "$upkg" -f "$w/conf" install qpkg
conf feed2
"$upkg" -f "$w/conf" update >/dev/null 2>&1
tty_run "TWO" "$upkg" -f "$w/conf" upgrade
last=$(tail -n 1 "$w/root/answers")
[ "$last" = "ONE/TWO/" ] || { echo "[FAIL] upgrade 1.0 -> 2.0 recorded '$last', wanted ONE/TWO/ (Q1 kept, Q2 asked)"; exit 1; }
grep -q "Question two" "$w/screen" || { echo "[FAIL] the new question was not asked on upgrade"; exit 1; }
! grep -q "Question one" "$w/screen" || { echo "[FAIL] Q1 was asked again on upgrade"; exit 1; }
conf feed3
"$upkg" -f "$w/conf" update >/dev/null 2>&1
"$upkg" -f "$w/conf" upgrade </dev/null >"$w/out" 2>&1 || { echo "[FAIL] unattended upgrade: $(tail -n 5 "$w/out")"; exit 1; }
last=$(tail -n 1 "$w/root/answers")
[ "$last" = "ONE/TWO/d3" ] || { echo "[FAIL] unattended upgrade 2.0 -> 3.0 recorded '$last', wanted ONE/TWO/d3"; exit 1; }
echo "[OK] upgrade keeps earlier answers (Q1), asks the question the old version never asked (Q2); unattended takes the default only for the new one"
