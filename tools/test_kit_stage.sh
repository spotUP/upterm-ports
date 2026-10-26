#!/bin/sh
# test_kit_stage.sh: kit-stage.sh stops on a package that is installed but not
# checked, and leaves the old kit in place. It used to skip such a package
# quietly: a rebuild of xz, bzip2 and libarchive whose checks never ran gave a
# kit with no xz and no tar (2026-10-19).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/state" "$T/kit/userland"
echo old > "$T/kit/userland/keep"
touch "$T/state/xz.installed"
bad=0
if ROOT=$ROOT B=$T STATE=$T/state SYSROOT=$T PREFIX=/x SRC=$T IXEMUL=$T PKGS=xz \
	sh "$ROOT/tools/kit-stage.sh" > "$T/out" 2>&1; then
	echo "test_kit_stage: an unchecked xz did not stop kit-stage" >&2; bad=1
fi
grep -q "installed but not checked: xz" "$T/out" || { echo "test_kit_stage: no message naming xz" >&2; cat "$T/out" >&2; bad=1; }
[ -f "$T/kit/userland/keep" ] || { echo "test_kit_stage: the old kit was removed" >&2; bad=1; }

# A package that fails while staging (here: its licence file is missing from the
# source tree) leaves the old userland and userland-src in place, not half staged.
rm -rf "$T/kit" "$T/state"
mkdir -p "$T/state" "$T/kit/userland" "$T/kit/userland-src" "$T/x/bin"
echo old > "$T/kit/userland/keep"
echo old > "$T/kit/userland-src/keep"
touch "$T/state/xz.installed" "$T/state/xz.checked" "$T/state/ixcompat.installed"
for b in $(make -s print-xz_BINS); do echo bin > "$T/x/$b"; done
mkdir -p "$T/xz" "$T/dl"
if ROOT=$ROOT B=$T STATE=$T/state SYSROOT=$T PREFIX=/x SRC=$T IXEMUL=$T PKGS=xz \
	sh "$ROOT/tools/kit-stage.sh" > "$T/out" 2>&1; then
	echo "test_kit_stage: a missing licence file did not stop kit-stage" >&2; bad=1
fi
grep -q "no licence file" "$T/out" || { echo "test_kit_stage: no licence message" >&2; cat "$T/out" >&2; bad=1; }
[ "$(cat "$T/kit/userland/keep" 2>/dev/null)" = old ] || { echo "test_kit_stage: failed staging replaced the old userland" >&2; bad=1; }
[ -f "$T/kit/userland-src/keep" ] || { echo "test_kit_stage: failed staging replaced the old userland-src" >&2; bad=1; }
[ ! -e "$T/kit/userland.new" ] || { echo "test_kit_stage: failed staging left a temporary drawer" >&2; bad=1; }

# A staging that succeeds leaves the new userland in place (the temporary drawer's
# cleanup trap once removed it after the swap).
rm -rf "$T/kit" "$T/state" "$T/xz"
mkdir -p "$T/state" "$T/xz" "$T/dl"
touch "$T/state/xz.installed" "$T/state/xz.checked"
for f in $(make -s print-xz_LICENSE_FILES); do echo lic > "$T/xz/$f"; done
touch "$T/dl/$(basename "$(make -s print-xz_ARCHIVE)")"
ROOT=$ROOT B=$T STATE=$T/state SYSROOT=$T PREFIX=/x SRC=$T IXEMUL=$T PKGS=xz \
	sh "$ROOT/tools/kit-stage.sh" > "$T/out" 2>&1 || { echo "test_kit_stage: good staging failed" >&2; cat "$T/out" >&2; bad=1; }
[ -f "$T/kit/userland/SOURCES.txt" ] && [ -d "$T/kit/userland-src" ] && [ ! -e "$T/kit/userland.new" ] || \
	{ echo "test_kit_stage: good staging left no userland" >&2; bad=1; }

# The staged kit says which ports commit it came from (STAGED-FROM: HEAD, plus -dirty
# when tracked files differ), so vtcon's make dist can refuse a kit from an unmerged branch.
head=$(git -C "$ROOT" rev-parse HEAD)
case $(cat "$T/kit/userland/STAGED-FROM" 2>/dev/null) in
	"$head"|"$head-dirty") ;;
	*) echo "test_kit_stage: STAGED-FROM is missing or is not the ports HEAD $head" >&2; bad=1 ;;
esac

# A <p>_DRAWER package (vbcc): the drawer is copied whole, its licence is read from
# inside it, the lha archives are the source with their URLs in the SOURCES.txt row.
# A missing drawer stops kit-stage and leaves the old kit in place.
rm -rf "$T/kit" "$T/state" "$T/x" "$T/dl"
mkdir -p "$T/state" "$T/x/vbcc/bin" "$T/dl" "$T/kit/userland"
echo old > "$T/kit/userland/keep"
touch "$T/state/vbcc.installed" "$T/state/vbcc.checked"
echo vc > "$T/x/vbcc/bin/vc"; echo lic > "$T/x/vbcc/README.md"
for u in $(make -s print-vbcc_LHA_URLS); do touch "$T/dl/$(basename "$u")"; done
ROOT=$ROOT B=$T STATE=$T/state SYSROOT=$T PREFIX=/x SRC=$T IXEMUL=$T PKGS=vbcc \
	sh "$ROOT/tools/kit-stage.sh" > "$T/out" 2>&1 || { echo "test_kit_stage: drawer staging failed" >&2; cat "$T/out" >&2; bad=1; }
[ -f "$T/kit/userland/vbcc/bin/vc" ] || { echo "test_kit_stage: the vbcc drawer was not staged" >&2; bad=1; }
[ -f "$T/kit/userland/licenses/vbcc/README.md" ] || { echo "test_kit_stage: the vbcc licence was not staged" >&2; bad=1; }
grep -q "^vbcc	.*vbcc_bin_amigaos68k.lha,.*vbcc_target_m68k-amigaos.lha" "$T/kit/userland/SOURCES.txt" || \
	{ echo "test_kit_stage: no vbcc SOURCES.txt row with both lha URLs" >&2; bad=1; }
[ -f "$T/kit/userland-src/vbcc/vbcc_bin_amigaos68k.lha" ] || { echo "test_kit_stage: the vbcc lha is not in userland-src" >&2; bad=1; }
rm -rf "$T/x/vbcc" "$T/kit"; mkdir -p "$T/kit/userland"; echo old > "$T/kit/userland/keep"
if ROOT=$ROOT B=$T STATE=$T/state SYSROOT=$T PREFIX=/x SRC=$T IXEMUL=$T PKGS=vbcc \
	sh "$ROOT/tools/kit-stage.sh" > "$T/out" 2>&1; then
	echo "test_kit_stage: a missing drawer did not stop kit-stage" >&2; bad=1
fi
grep -q "no drawer vbcc" "$T/out" || { echo "test_kit_stage: no drawer message" >&2; cat "$T/out" >&2; bad=1; }
[ -f "$T/kit/userland/keep" ] || { echo "test_kit_stage: a missing drawer replaced the old kit" >&2; bad=1; }

# kit-stage depends on the packages it stages: with every stamp newer than its
# sources nothing is rebuilt, and a source that is newer (make -W) rebuilds
# exactly that package before the kit is staged (stale upkg-ui, 2026-10-21).
M=$T/mk
mkdir -p "$M/state"
cd "$ROOT"
for p in $(make -s B="$M" print-PKGS); do
	for s in $p.fetched $p.unpacked $p.configured $p.built $p.installed $p.checked host-$p.built host-$p.expected; do
		touch -t 203801010000 "$M/state/$s"
	done
done
out=$(make -n B="$M" kit-stage 2>&1 | grep -c 'touch ' || true)
[ "$out" = 0 ] || { echo "test_kit_stage: kit-stage rebuilds current packages" >&2; bad=1; }
make -n -W pkgs/upkg-ui/src/chrome.c B="$M" kit-stage 2>&1 | grep -q 'pkgs/upkg-ui/src/\. ' || \
	{ echo "test_kit_stage: kit-stage ignores a newer upkg-ui source" >&2; bad=1; }
# lynx reads /UP-Term/etc/lynx.cfg and lynx.lss at run time (strings on the binary):
# both must be in lynx_DATA or the kit ships a lynx with no configuration.
lynxdata=$(make -s print-lynx_DATA)
for f in etc/lynx.cfg etc/lynx.lss; do
	case " $lynxdata " in *" $f "*) ;; *) echo "test_kit_stage: lynx_DATA lacks $f" >&2; bad=1 ;; esac
done
[ $bad = 0 ] && echo "test_kit_stage: ok"
exit $bad
