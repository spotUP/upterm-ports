#!/bin/sh
# run-tty.sh BINDIR CHECKDIR OUTDIR: the terminal cases of CHECKDIR/tty
# ("name<TAB>command" lines; the keys in CHECKDIR/keys/<name>, ptyrun's
# format) on the Mac, each in a fresh copy of CHECKDIR/data, on an 80x24
# pseudo-terminal with TERM=vtcon (vtcon's terminfo, compiled by the
# Mac's tic). OUTDIR/<name>.stream gets what the program drew,
# <name>.stream.marks the byte counts at each key step, <name>.txt the
# line "exit N". vtcon's tools/rig/userland_rig.py runs the same cases on
# the rig and renders both streams with the engine at each mark.
set -u
bindir=$1 check=$2 out=$3
root=$(cd "$(dirname "$0")/.." && pwd)
ptyrun=$root/build/tools/ptyrun
ti=$root/build/tools/terminfo
[ -f "$check/tty" ] || exit 0
work=$(mktemp -d "${TMPDIR:-/tmp}/tty.XXXXXX")
mkdir -p "$out"
out=$(cd "$out" && pwd)
check=$(cd "$check" && pwd)
cp -R "$check/data/." "$work/" 2>/dev/null || true
n=0
while IFS='	' read -r name cmd; do
	[ -n "$name" ] || continue
	case $name in \#*) continue ;; esac
	( cd "$work" && unset LC_ALL LC_CTYPE && LANG=C TERM=vtcon TERMINFO=$ti PATH="$bindir:$PATH" \
		sh -c "exec $ptyrun -t 30 '$check/keys/$name' '$out/$name.stream' $cmd" ) > "$out/$name.txt" 2> "$out/$name.err"
	n=$((n+1))
done < "$check/tty"
rm -rf "$work"
echo "$n terminal outputs in $out"
