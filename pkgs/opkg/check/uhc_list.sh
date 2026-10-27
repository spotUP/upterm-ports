#!/bin/sh
# uhc_list.sh UPKG: host check of patches/0045: the UHC rows in upkg list, list-installed, list-upgradable, info
# uhc:<n>, and the --tsv form of the three lists (nine tab-separated columns: name, version, installed, upgradable,
# size, section, launch, src, description). Feed: alpha (installed, Section net, Launch alpha-go), beta (not installed, Launch beta-go), unzip (a
# name the UHC fixture drawer check/uhc/Packages also has: curl installed, unzip 5.40 installed with 5.42 in the
# script, lzx available).
#   sh pkgs/opkg/check/uhc_list.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/uhclist.XXXXXX")
trap '[ -n "${KEEP:-}" ] || rm -rf "$w"' EXIT
mkdir "$w/feed"
python3 -I - "$w" "$here" <<'PY'
import sys
w = sys.argv[1]; sys.path.insert(0, sys.argv[2])
from ipk import ipk, stanza, write_index
idx = b''
for name, extra in (('alpha', b'Section: net\nLaunch: alpha-go\n'), ('beta', b'Launch: beta-go\n'), ('unzip', b'')):
    ctl = b'Package: %s\nVersion: 1.0\nArchitecture: m68k-amigaos\nMaintainer: t\n%sDescription: %s\tcheck\n' % (name.encode(), extra, name.encode())
    pkg = ipk([('./control', ctl, 0o644)], [('./f_%s' % name, b'x\n', 0o644)])
    fn = '%s_1.0_m68k-amigaos.ipk' % name
    open('%s/feed/%s' % (w, fn), 'wb').write(pkg)
    idx += stanza(ctl, fn, pkg) + b'\n'
write_index('%s/feed/Packages.gz' % w, idx)
PY
cp -R "$here/uhc/Packages" "$w/uhc"
{ echo "arch m68k-amigaos 10"; echo "src/gz test file://$w/feed"; echo "dest root $w/root"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/$o"; done; } > "$w/conf"
export UPKG_UHC_DIR="$w/uhc"
mkdir "$w/env" "$w/env/UHC"
printf 'UP-Term:uhc/ExtBin/' > "$w/env/UHC/EXTBIN"; printf 'UP-Term:uhc/Docs/' > "$w/env/UHC/EXTDOC"
export UPKG_UHC_ENV="$w/env/"
u() { "$upkg" -f "$w/conf" "$@"; }
fail() { echo "[FAIL] $*"; exit 1; }
has() { grep -qxF "$2" "$1" || fail "$3: no line '$2' in: $(cat "$1")"; }
tab=$(printf '\t')

u update >/dev/null 2>&1 || fail "update"
u install alpha >/dev/null 2>&1 || fail "install alpha"
bsize=$(wc -c < "$w/feed/beta_1.0_m68k-amigaos.ipk" | tr -d ' ')

# text lists: the UHC rows follow the feed rows, tagged uhc:<name> (the argument install takes)
u list >"$w/o" 2>&1
has "$w/o" "uhc:lzx - 1.21r - Compressor and decompressor for lzx archives" "list"
has "$w/o" "uhc:unzip - 5.42 - Extractor for zip-archives" "list"
grep -q '^alpha - 1.0' "$w/o" || fail "list lost the ipk row"
u list-installed >"$w/o" 2>&1
has "$w/o" "uhc:curl - 7.10.5 - Command line tool for transferring data with URL syntax" "list-installed"
has "$w/o" "uhc:unzip - 5.40 - Extractor for zip-archives" "list-installed"
! grep -q 'lzx' "$w/o" || fail "list-installed shows the uninstalled lzx"
u list-upgradable >"$w/o" 2>&1
has "$w/o" "uhc:unzip - 5.40 - 5.42" "list-upgradable"
! grep -q 'curl' "$w/o" || fail "list-upgradable shows the current curl"
# name search: the glob reaches the UHC rows; no match is still an error
u list '*lz*' >"$w/o" 2>&1; has "$w/o" "uhc:lzx - 1.21r - Compressor and decompressor for lzx archives" "glob"
u list 'uhc:lzx' >"$w/o" 2>&1 && [ "$(wc -l <"$w/o" | tr -d ' ')" = 1 ] || fail "uhc:lzx glob: $(cat "$w/o")"
rc=0; u list '*nothing*' >/dev/null 2>&1 || rc=$?; [ "$rc" = 5 ] || fail "no-match glob rc=$rc"
# info
u info uhc:lzx >"$w/o" 2>&1
has "$w/o" "Package: uhc:lzx" "info"; has "$w/o" "Version: 1.21r" "info"; has "$w/o" "Status: not installed" "info"
rc=0; u info uhc:nosuch >/dev/null 2>&1 || rc=$?; [ "$rc" = 12 ] || fail "info of a missing uhc package rc=$rc"

# --tsv: exact rows, nine columns everywhere
u list --tsv >"$w/t"
awk -F'\t' 'NF != 9 { bad = 1; print "line " NR " has " NF " columns: " $0 } END { exit bad }' "$w/t" || fail "tsv column count"
has "$w/t" "alpha${tab}1.0${tab}1${tab}0${tab}2${tab}net${tab}alpha-go${tab}upkg${tab}alpha check" "tsv ipk row"
has "$w/t" "beta${tab}1.0${tab}0${tab}0${tab}${bsize}${tab}${tab}beta-go${tab}upkg${tab}beta check" "tsv uninstalled ipk row: launch from the feed index, tab in the description"
has "$w/t" "lzx${tab}1.21r${tab}0${tab}0${tab}${tab}${tab}UP-Term:uhc/ExtBin/lzx${tab}uhc${tab}Compressor and decompressor for lzx archives" "tsv uhc row"
has "$w/t" "unzip${tab}5.42${tab}1${tab}1${tab}${tab}${tab}UP-Term:uhc/ExtBin/UnZip${tab}uhc${tab}Extractor for zip-archives" "tsv uhc upgradable row"
[ "$(grep -c "^unzip$tab" "$w/t")" = 2 ] || fail "the unzip clash is not two rows"
u list-installed --tsv >"$w/t"
awk -F'\t' 'NF != 9 { exit 1 }' "$w/t" || fail "list-installed tsv column count"
has "$w/t" "alpha${tab}1.0${tab}1${tab}0${tab}2${tab}net${tab}alpha-go${tab}upkg${tab}alpha check" "installed tsv ipk row"
has "$w/t" "unzip${tab}5.40${tab}1${tab}1${tab}${tab}${tab}UP-Term:uhc/ExtBin/UnZip${tab}uhc${tab}Extractor for zip-archives" "installed tsv uhc row"
[ "$(wc -l <"$w/t" | tr -d ' ')" = 3 ] || fail "list-installed tsv: want alpha, curl, unzip(uhc): $(cat "$w/t")"
u list-upgradable --tsv >"$w/t"
[ "$(cat "$w/t")" = "unzip${tab}5.42${tab}1${tab}1${tab}${tab}${tab}UP-Term:uhc/ExtBin/UnZip${tab}uhc${tab}Extractor for zip-archives" ] || fail "list-upgradable tsv: $(cat "$w/t")"
u list --tsv '*zip*' >"$w/t"
[ "$(wc -l <"$w/t" | tr -d ' ')" = 2 ] && has "$w/t" "unzip${tab}5.42${tab}1${tab}1${tab}${tab}${tab}UP-Term:uhc/ExtBin/UnZip${tab}uhc${tab}Extractor for zip-archives" "tsv glob" || fail "tsv glob: $(cat "$w/t")"
u --help 2>&1 | grep -q -- '--tsv' || fail "--tsv is not in the help text"
echo "[OK] upkg list, list-installed, list-upgradable include UHC rows (uhc:<n>); info uhc:<n>; --tsv has 9 columns with exact ipk and uhc rows; glob reaches UHC"
