#!/bin/sh
# questions.sh UPKG: host check of patch 0050, the question channel for a front-end without a terminal (Amarchy).
#   upkg questions PKG: tab-separated id, kind, default, choices, prompt, answered|new; rc 0, 5 none, 12 unknown
#   upkg install|upgrade PKG --answers FILE: id=value lines; runs with no terminal; a missing answer is rc 15 naming the
#   id on stderr (nothing installed); a bad answer is rc 11.
# qpkg 1.0 asks q1, 2.0 asks q1 (kind choice) and q2; plain has no questions. q1 is answered on a pseudo terminal so
# NAME.answered holds it, which the second column group of `questions` shows after the upgrade feed arrives.
#   sh pkgs/opkg/check/questions.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/newq.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed1" "$w/feed2" "$w/bin" "$w/root"
cp "$here/upkg-ask.fixture" "$w/bin/upkg-ask"
chmod +x "$w/bin/upkg-ask"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
Q = {'1.0': b'q1|string|Question one?|d1|\n',
     '2.0': b'q1|string|Question one?|d1|\nq2|choice|Question two?|red|red,green\n'}
for feed, ver in (('feed1', '1.0'), ('feed2', '2.0')):
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
    pc = b'Package: plain\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: no questions\n'
    pp = ipk([('./control', pc, 0o644)], [('./share/plain/f', b'x\n', 0o644)])
    open('%s/%s/plain_1.0_m68k-amigaos.ipk' % (w, feed), 'wb').write(pp)
    write_index('%s/%s/Packages.gz' % (w, feed), stanza(ctl, fn, pkg) + b'\n' + stanza(pc, 'plain_1.0_m68k-amigaos.ipk', pp) + b'\n')
PY
# conf FEED [SUFFIX]: a second SUFFIX gives a second, empty install root with its own state
conf() {
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/$1"; echo "dest root $w/root${2:-}"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o${2:-}"; done; } > "$w/conf${2:-}"
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
fail() { echo "[FAIL] $*"; exit 1; }
# U ARGS...: upkg on the first root; Z ARGS...: on the second, both with no terminal
U() { "$upkg" -f "$w/conf" "$@"; }
conf feed1
U update >/dev/null 2>&1

# --- questions: rc and columns ---
U questions plain >"$w/q.out" 2>/dev/null && rc=0 || rc=$?
[ "$rc" = 5 ] || fail "questions of a package with none: rc $rc, wanted 5"
U questions nosuchpkg >"$w/q.out" 2>/dev/null && rc=0 || rc=$?
[ "$rc" = 12 ] || fail "questions of an unknown package: rc $rc, wanted 12"
U questions qpkg >"$w/q.out" 2>/dev/null || fail "questions qpkg: rc $?"
tab=$(printf '\t')
[ "$(cat "$w/q.out")" = "q1${tab}string${tab}d1${tab}${tab}Question one?${tab}new" ] || fail "questions qpkg printed: $(cat "$w/q.out")"

# --- install --answers: a missing id is rc 15 naming it, nothing installed; a bad id value is rc 11 ---
: > "$w/ans"
U install qpkg --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" && rc=0 || rc=$?
[ "$rc" = 15 ] || fail "install with a missing answer: rc $rc, wanted 15 ($(cat "$w/err"))"
grep -q 'needs an answer for q1' "$w/err" || fail "stderr does not name q1: $(cat "$w/err")"
[ ! -e "$w/root/answers" ] || fail "a package was installed with a missing answer"
echo 'q1=a|b' > "$w/ans"
U install qpkg --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" && rc=0 || rc=$?
[ "$rc" = 11 ] || fail "install with a bad answer: rc $rc, wanted 11"
# the answers are given for a package that asks them, with no terminal: the question text carries a quote
printf '# comment\nq1=it'"'"'s Z\nother=ignored\n' > "$w/ans"
U install qpkg --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" || fail "install --answers: $(tail -n 5 "$w/out" "$w/err")"
[ "$(tail -n 1 "$w/root/answers")" = "it's Z//" ] || fail "install --answers recorded '$(tail -n 1 "$w/root/answers")', wanted it's Z//"
U remove qpkg >/dev/null 2>&1

# --- an interactive install records q1; the upgrade feed adds q2 ---
tty_run "ONE" "$upkg" -f "$w/conf" install qpkg
[ "$(tail -n 1 "$w/root/answers")" = "ONE//" ] || fail "terminal install recorded '$(tail -n 1 "$w/root/answers")'"
conf feed2
U update >/dev/null 2>&1
U questions qpkg >"$w/q.out" 2>/dev/null || fail "questions qpkg (2.0): rc $?"
[ "$(sed -n 1p "$w/q.out")" = "q1${tab}string${tab}d1${tab}${tab}Question one?${tab}answered" ] || fail "q1 line: $(sed -n 1p "$w/q.out")"
[ "$(sed -n 2p "$w/q.out")" = "q2${tab}choice${tab}red${tab}red,green${tab}Question two?${tab}new" ] || fail "q2 line: $(sed -n 2p "$w/q.out")"
[ "$(wc -l < "$w/q.out" | tr -d ' ')" = 2 ] || fail "questions printed $(wc -l < "$w/q.out") lines, wanted 2"

# --- upgrade --answers: q1 is answered already, q2 is missing (15), not a choice (11), then given ---
: > "$w/ans"
U upgrade --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" && rc=0 || rc=$?
[ "$rc" = 15 ] || fail "upgrade with a missing answer: rc $rc, wanted 15"
grep -q 'needs an answer for q2' "$w/err" || fail "stderr does not name q2: $(cat "$w/err")"
grep -q 'q1' "$w/err" && fail "stderr names q1, which an earlier install answered"
[ "$(tail -n 1 "$w/root/answers")" = "ONE//" ] || fail "the package was upgraded with a missing answer"
echo 'q2=blue' > "$w/ans"
U upgrade --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" && rc=0 || rc=$?
[ "$rc" = 11 ] || fail "upgrade with a value outside the choices: rc $rc, wanted 11"
echo 'q2=green' > "$w/ans"
U upgrade --answers "$w/ans" </dev/null >"$w/out" 2>"$w/err" || fail "upgrade --answers: $(tail -n 5 "$w/out" "$w/err")"
[ "$(tail -n 1 "$w/root/answers")" = "ONE/green/" ] || fail "upgrade --answers recorded '$(tail -n 1 "$w/root/answers")', wanted ONE/green/"
echo "[OK] questions lists id, kind, default, choices, prompt and answered|new (rc 0, 5 none, 12 unknown); install and upgrade --answers run with no terminal, a missing answer is rc 15 naming the id, a bad one rc 11"
