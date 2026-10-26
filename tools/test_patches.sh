#!/bin/sh
# test_patches.sh: `make <p>-patches` on an unchanged tree leaves pkgs/<p>/patches byte-identical,
# and a new commit adds only the next numbered file. The old rule deleted every patch and wrote
# them again with format-patch: new "From <hash>" lines and signatures in all of them, and a
# hand-named file (opkg 0027, a name longer than format-patch keeps) written a second time, cut.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
p=fzy
fail() { echo "test_patches: $*" >&2; exit 1; }
mkdir -p build/dl
arc=$(make -s print-${p}_ARCHIVE)
[ -f "$arc" ] || tools/fetch.sh "$(make -s print-${p}_URL)" "$(make -s print-${p}_SHA256)" "$arc" >/dev/null
src=$(make -s print-${p}_SRC)
rm -f $ROOT/build/state/$p.unpacked
make -s $ROOT/build/state/$p.unpacked >/dev/null
pd=pkgs/$p/patches
[ -z "$(git status --porcelain $pd)" ] || fail "$pd is not clean before the test"
make -s $p-patches >/dev/null
[ -z "$(git status --porcelain $pd)" ] || fail "$p-patches on an unchanged tree changed $pd: $(git status --porcelain $pd | head -3 | tr '\n' ' ')"
n=$(ls $pd | wc -l)
echo "test" >> "$src/README.md"
git -C "$src" -c user.name=t -c user.email=t@localhost commit -qam "test: an extra commit"
make -s $p-patches >/dev/null
[ "$(ls $pd | wc -l)" -eq $((n + 1)) ] || fail "a new commit did not add exactly one file"
[ -z "$(git status --porcelain $pd | grep -v '^??')" ] || fail "a new commit changed an existing patch"
rm -f "$(git status --porcelain $pd | sed -n 's/^?? //p')"
rm -f $ROOT/build/state/$p.unpacked
[ -z "$(git status --porcelain $pd)" ] || fail "cleanup left $pd dirty"
echo "test_patches: ok"
