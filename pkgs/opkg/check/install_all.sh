#!/bin/sh
# install_all.sh UPKG: host check of `upkg install --all` and `upkg upgrade --all` (patch 0041).
# Install All asks the install questions of every package that has some ONCE, before any install, then installs
# unattended: the answers given are written into each package's questions file (the default field), so the
# unchanged postinst, which runs upkg-ask (a copy is in upkg-ask.fixture) without a terminal, takes them as its answers.
# The question pass here runs a counting stub ($UPKG_ASK_CMD) that answers "ANSWERED" to every question.
# Asserts: the stub ran once per interactive package and before any postinst; the postinst of the interactive
# package recorded ANSWERED (not the packaged default); a plain package installed; --all with names is refused;
# a second `install --all` has nothing to do; `upgrade --all` upgrades like `upgrade` and asks nothing (the postinst's stdin is empty).
#   sh pkgs/opkg/check/install_all.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/install.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed1" "$w/feed2" "$w/bin"
cp "$here/upkg-ask.fixture" "$w/bin/upkg-ask"
chmod +x "$w/bin/upkg-ask"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
QUESTIONS = b'# the questions\nflavour|string|Which flavour?|vanilla|\nsure|yesno|Are you sure?|no|\n'
def build(feed, name, ver, interactive, upg=False):
    ctl = b'Package: %s\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s check\n' % (name.encode(), ver.encode(), name.encode())
    if interactive:
        ctl += b'UP-Term-Interactive: yes\n'
    files = [('./share/%s/f' % name, b'x\n', 0o644)]
    ctl_files = [('./control', ctl, 0o644)]
    if interactive:
        stage = './T/upkg-stage/%s-%s/Files/' % (name, ver)
        files.append((stage + 'questions', QUESTIONS, 0o644))
        # real shape of the generated postinst: ask over the staged questions, source the answers
        post = ('#!/bin/sh\nq=%s/T/upkg-stage/%s-%s/Files/questions\n'
                '"$ASKBIN/upkg-ask" "$q" "$q.answers" %s-%s && . "$q.answers"\n'
                'echo "$flavour/$sure" >> "$ROOT/answers-%s"\n'
                'IFS= read -r line || line=EOF; echo "$line" >> "$ROOT/stdin-%s"\n') % ('$ROOT', name, ver, name, ver, name, name)
        ctl_files.append(('./postinst', post.encode(), 0o755))
    pkg = ipk(ctl_files, files)
    fn = '%s_%s_m68k-amigaos.ipk' % (name, ver)
    open('%s/%s/%s' % (w, feed, fn), 'wb').write(pkg)
    return stanza(ctl, fn, pkg) + b'\n'
def feed(dirn, ver):
    write_index('%s/%s/Packages.gz' % (w, dirn),
                build(dirn, 'plain', ver, False) + build(dirn, 'asky', ver, True) + build(dirn, 'asky2', ver, True))
feed('feed1', '1.0')
feed('feed2', '2.0')
PY
# the question pass: a counting stub; its answers are what the postinst must record
cat > "$w/bin/ask" <<STUB
#!/bin/sh
# ask QUESTIONS ANSWERS NAME: count the call, check no package was installed yet, answer every question
echo "\$3" >> "$w/asked"
[ ! -e "$w/root/answers-asky" ] || echo "asked after an install" >> "$w/late"
printf "flavour='ANSWERED'\nsure='yes'\n" > "\$2"
STUB
chmod +x "$w/bin/ask"
conf() {
  { echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/$1"; echo "dest root $w/root"
    for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
}
mkdir "$w/root"
export ROOT="$w/root" ASKBIN="$w/bin"
conf feed1
"$upkg" -f "$w/conf" update >/dev/null 2>&1

"$upkg" -f "$w/conf" install --all plain >"$w/out" 2>&1 && { echo "[FAIL] install --all with a name was accepted"; exit 1; }
grep -q "takes no package names" "$w/out" || { echo "[FAIL] install --all plain: wrong refusal: $(cat "$w/out")"; exit 1; }

UPKG_ASK_CMD="$w/bin/ask" "$upkg" -f "$w/conf" install --all >"$w/out" 2>&1 || { echo "[FAIL] install --all: rc=$? $(tail -n 8 "$w/out")"; exit 1; }
inst=$("$upkg" -f "$w/conf" list-installed 2>&1 | sort | tr '\n' ' ')
[ "$inst" = "asky - 1.0 asky2 - 1.0 plain - 1.0 " ] || { echo "[FAIL] installed after install --all: $inst"; exit 1; }
[ "$(sort "$w/asked" | tr '\n' ' ')" = "asky-1.0 asky2-1.0 " ] || { echo "[FAIL] question pass ran for: $(cat "$w/asked" 2>/dev/null)"; exit 1; }
[ ! -e "$w/late" ] || { echo "[FAIL] a question was asked after an install had started"; exit 1; }
for n in asky asky2; do
  [ "$(cat "$w/root/answers-$n")" = "ANSWERED/yes" ] || { echo "[FAIL] $n postinst recorded '$(cat "$w/root/answers-$n" 2>/dev/null)', not the answers given up front"; exit 1; }
done
rm -f "$w/asked"
UPKG_ASK_CMD="$w/bin/ask" "$upkg" -f "$w/conf" install --all >"$w/out" 2>&1 || { echo "[FAIL] second install --all: $(cat "$w/out")"; exit 1; }
grep -q "Every add-on in the feeds is installed" "$w/out" || { echo "[FAIL] second install --all: $(cat "$w/out")"; exit 1; }
[ ! -e "$w/asked" ] || { echo "[FAIL] second install --all asked questions"; exit 1; }

conf feed2
"$upkg" -f "$w/conf" update >/dev/null 2>&1
echo TYPED | "$upkg" -f "$w/conf" upgrade --all >"$w/out" 2>&1 || { echo "[FAIL] upgrade --all: rc=$? $(tail -n 8 "$w/out")"; exit 1; }
inst=$("$upkg" -f "$w/conf" list-installed 2>&1 | sort | tr '\n' ' ')
[ "$inst" = "asky - 2.0 asky2 - 2.0 plain - 2.0 " ] || { echo "[FAIL] installed after upgrade --all: $inst"; exit 1; }
# Update All asks no questions: the postinst of an upgraded package reads nothing from the terminal (its stdin is
# /dev/null, so upkg-ask takes the defaults, a "<PATH" default being the answer the earlier install kept)
for n in asky asky2; do
  [ "$(tail -n 1 "$w/root/stdin-$n")" = "EOF" ] || { echo "[FAIL] $n postinst on upgrade --all could read the terminal: '$(tail -n 1 "$w/root/stdin-$n")'"; exit 1; }
done
echo "[OK] install --all asks each interactive package once up front, installs unattended with those answers; upgrade --all upgrades all"
