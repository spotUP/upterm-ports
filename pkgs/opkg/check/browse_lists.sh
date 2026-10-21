#!/bin/sh
# browse_lists.sh UPKG: host check of patches/0022: `upkg browse` writes the three lists the browse
# script shows first (all, installed, upgradable and new), from the package hash it already loaded, and `upkg list-browse PREFIX` writes
# them again for a reload. Each upkg run costs seconds on a 68k (3 s per load from a PFS3 disk).
#   list-browse P writes P.all, P.inst, P.upg and P.new equal to list, list-installed,
#     list-upgradable and list-new read through a pipe.
#   browse puts UPKG_BROWSE_LISTS=<TMPDIR>/upkg-lists.<pid> in the script's environment, the files
#     are there while the script runs, and gone after it returns (also when it fails).
#   sh pkgs/opkg/check/browse_lists.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/blist.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed" "$w/t"
feed() { python3 -I - "$w" "$here" "$1" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2]); ver = sys.argv[3].encode()
from ipk import ipk, stanza, write_index
idx = b''
for name in (b'alpha', b'beta') + ((b'gamma',) if ver != b'1.0' else ()):
    v = ver if name == b'alpha' else b'1.0'
    ctl = b'Package: %s\nVersion: %s\nArchitecture: m68k-amigaos\nMaintainer: t\nDescription: %s check\n' % (name, v, name)
    pkg = ipk([('./control', ctl, 0o644)], [('./f_%s' % name.decode(), b'x\n', 0o644)])
    fn = '%s_%s_m68k-amigaos.ipk' % (name.decode(), v.decode())
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
}
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
u() { "$upkg" -f "$w/conf" "$@"; }
fail() { echo "[FAIL] $*"; exit 1; }
# alpha 1.0 installed, then the feed offers alpha 2.0: all three lists hold a row
feed 1.0; u update >/dev/null 2>&1 || fail "update"
u install alpha >/dev/null 2>&1 || fail "install alpha"
feed 2.0; u update >/dev/null 2>&1 || fail "update to 2.0"
u list >"$w/want.all" 2>&1; u list-installed >"$w/want.inst" 2>&1; u list-upgradable >"$w/want.upg" 2>&1; u list-new >"$w/want.new" 2>&1
grep -q '^alpha - 1.0 - 2.0$' "$w/want.upg" || fail "set-up: list-upgradable is $(cat "$w/want.upg")"
grep -q '^gamma - ' "$w/want.new" && [ "$(wc -l <"$w/want.new" | tr -d ' ')" = 1 ] || fail "set-up: list-new is $(cat "$w/want.new")"

u list-browse "$w/lb" >"$w/o" 2>&1 || fail "list-browse rc=$?: $(cat "$w/o")"
[ ! -s "$w/o" ] || fail "list-browse wrote to stdout: $(cat "$w/o")"
for e in all inst upg new; do
  cmp -s "$w/want.$e" "$w/lb.$e" || fail "list-browse .$e differs: $(cat "$w/lb.$e" 2>&1) want $(cat "$w/want.$e")"
done
# each list prints to its own file, never through fd 1: with stdout closed the lists still
# come out whole
u list-browse "$w/lc" >&- 2>"$w/o" || fail "list-browse with stdout closed rc=$?: $(cat "$w/o")"
for e in all inst upg new; do
  cmp -s "$w/want.$e" "$w/lc.$e" || fail "list-browse with stdout closed: .$e differs: $(cat "$w/lc.$e" 2>&1)"
done

# the stub copies the lists it was handed; exit 7 is returned
cat >"$w/stub" <<STUB
#!/bin/sh
printf '%s\n' "\${UPKG_BROWSE_LISTS-unset}" >"$w/seen"
for e in all inst upg new; do cp "\$UPKG_BROWSE_LISTS.\$e" "$w/got.\$e" 2>/dev/null || :; done
exit 7
STUB
chmod +x "$w/stub"
rc=0; TMPDIR="$w/t" UPKG_BROWSE="$w/stub" u browse >"$w/o" 2>&1 || rc=$?
[ "$rc" = 7 ] || fail "browse rc=$rc, want 7: $(cat "$w/o")"
case "$(cat "$w/seen")" in "$w/t/upkg-lists."[0-9]*) ;; *) fail "UPKG_BROWSE_LISTS is $(cat "$w/seen")";; esac
for e in all inst upg new; do
  cmp -s "$w/want.$e" "$w/got.$e" || fail "browse .$e differs: $(cat "$w/got.$e" 2>&1)"
done
[ -z "$(ls "$w/t")" ] || fail "browse left $(ls "$w/t")"
[ "$(basename "$(cat "$w/seen")" | wc -c)" -le 31 ] || fail "list file names over 30 characters"
echo "[OK] upkg browse hands the script its four lists from one load and removes them; list-browse writes them as piped, without fd 1"
