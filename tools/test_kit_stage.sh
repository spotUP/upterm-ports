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
[ $bad = 0 ] && echo "test_kit_stage: ok"
exit $bad
