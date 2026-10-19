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
[ $bad = 0 ] && echo "test_kit_stage: ok"
exit $bad
