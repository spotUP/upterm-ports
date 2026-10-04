#!/bin/sh
# run-cases.sh BINDIR CHECKDIR OUTDIR: run CHECKDIR/cases (one "name<TAB>
# command" per line) with BINDIR first on PATH, in a fresh copy of
# CHECKDIR/data; OUTDIR/<name>.txt gets stdout and a last line "[exit N]".
# On the host this writes the expected outputs; the rig runner (vtcon
# tools/rig/userland_rig.py, plan item 0.5) runs the same lines through vsh
# and compares. stderr goes to <name>.err and is not compared (it names
# paths and the program differently on each side). The base locale is C
# (LANG=C, no LC_*), as on a fresh Amiga; a case sets LC_ALL itself.
set -u
bindir=$1 check=$2 out=$3
work=$(mktemp -d "${TMPDIR:-/tmp}/cases.XXXXXX")
rm -rf "$out" && mkdir -p "$out"
out=$(cd "$out" && pwd)
cp -R "$check/data/." "$work/" 2>/dev/null || true
n=0
while IFS='	' read -r name cmd; do
	[ -n "$name" ] || continue
	case $name in \#*) continue ;; esac
	( cd "$work" && unset LC_ALL LC_CTYPE && LANG=C PATH="$bindir:$PATH" sh -c "$cmd" ) > "$out/$name.txt" 2> "$out/$name.err"
	echo "[exit $?]" >> "$out/$name.txt"
	n=$((n+1))
done < "$check/cases"
rm -rf "$work"
echo "$n expected outputs in $out"
