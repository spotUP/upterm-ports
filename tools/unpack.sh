#!/bin/sh
# unpack.sh ARCHIVE DIR PATCHDIR: unpack ARCHIVE (top directory stripped)
# into DIR as a git tree, commit it as "upstream" and apply PATCHDIR/*.patch
# with git am, one commit each. Refresh the patches after editing DIR:
#   git -C DIR format-patch -o PATCHDIR upstream
set -eu
arc=$1 dir=$2 pdir=$3
rm -rf "$dir"
mkdir -p "$dir"
tar -xf "$arc" -C "$dir" --strip-components 1
cd "$dir"
git init -q
git -c user.name=upstream -c user.email=upstream@localhost add -A
git -c user.name=upstream -c user.email=upstream@localhost commit -qm upstream --no-verify
git tag upstream
for p in "$pdir"/*.patch; do
	[ -f "$p" ] || continue
	git -c user.name=upterm-ports -c user.email=upterm-ports@localhost am -q --keep-cr "$p"
	echo "applied $(basename "$p")"
done
