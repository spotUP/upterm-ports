#!/bin/sh
# patches.sh SRC PATCHDIR: refresh PATCHDIR from the commits on top of the "upstream" tag in SRC
# (the tree tools/unpack.sh makes) without churning the patches already there.
# A patch whose commit still matches is left byte-identical: format-patch would give it a new
# "From <hash>" line (am rewrites the commit hash) and a new git version in the signature, and
# it cuts long names, so a hand-named file would be written a second time under the short name.
# A commit that differs from the file at its position (amended) overwrites that file under its
# own name; commits beyond the existing files get the next numbers. More files than commits is
# an error (a dropped commit): delete its file by hand.
set -eu
src=$1 pdir=$2
mkdir -p "$pdir"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# the part of a patch that carries the change: without the From hash line, the index lines (stale after an earlier patch changed), the signature, the n/m of the subject and its line wrapping
norm() {
	sed -e '1d' -e '/^index [0-9a-f]*\.\.[0-9a-f]*/d' -e '/^-- $/,$d' -e 's/^Subject: \[PATCH [0-9]*\/[0-9]*\]/Subject: [PATCH]/' "$1" |
		awk 'hdr == 0 && /^ / { printf "%s", $0; next } /^$/ { hdr = 1 } NR > 1 { printf "\n" } { printf "%s", $0 } END { printf "\n" }'
}
git -C "$src" format-patch -q -o "$tmp" upstream
n=0
for g in "$tmp"/*.patch; do
	[ -f "$g" ] || continue
	n=$((n + 1))
	num=$(printf '%04d' "$n")
	set -- "$pdir/$num"-*.patch
	if [ -f "$1" ]; then
		if [ "$(norm "$1")" != "$(norm "$g")" ]; then cp "$g" "$1"; echo "updated $(basename "$1")"; fi
	else
		cp "$g" "$pdir/$(basename "$g")"; echo "new $(basename "$g")"
	fi
done
have=$(ls "$pdir"/*.patch 2>/dev/null | wc -l | tr -d ' ')
[ "$have" -le "$n" ] || { echo "patches.sh: $have patch files but $n commits in $src" >&2; exit 1; }
ls "$pdir"
