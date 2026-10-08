#!/bin/sh
# check_bin.sh PKG STACK BINARY...: host checks on linked m68k programs
# (vtcon plan item 0.4). For each binary:
#   hunk     an AmigaOS executable (HUNK_HEADER 0x000003F3)
#   ixemul   it opens ixemul.library (an ixemul crt0, not libnix)
#   fork     no fork(): ixemul has none (vfork only), so a _fork symbol
#            means a fork() call that fails at run time
#   stack    the $STACK: cookie, when the recipe asks for one (STACK = bytes)
#   cpu      no 68030+ instructions (MMU, move16, cache ops) and no FPU
#            ones in the code (tools/m68k_scan.py follows the flow, so
#            tables in the code hunk do not count): 68020 soft float
# and records the size in build/state/sizes.tsv (one row per binary,
# replaced on rebuild). Prints [OK]/[FAIL] lines; exit status = failures.
set -u
AMIGA=${AMIGA:-$HOME/opt/amiga}
X=$AMIGA/bin/m68k-amigaos-
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TSV=$ROOT/build/state/sizes.tsv
pkg=$1 stack=$2
shift 2
fails=0
ok()  { echo "[OK]   $pkg $name: $1"; }
bad() { echo "[FAIL] $pkg $name: $1"; fails=$((fails+1)); }
mkdir -p "$(dirname "$TSV")"
[ -f "$TSV" ] || printf 'package\tbinary\tfile\ttext\tdata\tbss\n' > "$TSV"
[ $# -gt 0 ] || { echo "[FAIL] $pkg: no binaries named (<pkg>_BINS)"; exit 1; }
for bin; do
	name=$(basename "$bin")
	if [ ! -f "$bin" ]; then bad "missing: $bin"; continue; fi
	if [ "$(od -An -tx1 -N4 "$bin" | tr -d ' \n')" = 000003f3 ]; then ok hunk
	else bad "not a hunk executable"; continue; fi
	if strings -a "$bin" | grep -q 'ixemul\.library$'; then ok ixemul
	else bad "does not open ixemul.library"; fi
	f=$("${X}nm" "$bin" 2>/dev/null | awk '$3 == "_fork" || $3 == "_fork1" || $3 == "_forkpty"')
	if [ -z "$f" ]; then ok "no fork"
	else bad "links fork: $(echo $f)"; fi
	if [ -n "$stack" ]; then
		# anywhere in a string, as vsh and AmigaOS 3.2 search for it: the
		# bytes before the cookie can be printable (find 4.11: "<Nu$STACK:")
		if strings -a "$bin" | grep -q "\\\$STACK: *$stack\$"; then ok "\$STACK: $stack"
		else bad "no \$STACK: $stack cookie (found: $(strings -a "$bin" | grep -o '\$STACK: *[0-9]*' | head -1))"; fi
	fi
	# a flow-following scan: hunk executables keep const data in the code
	# hunk, which a linear disassembly decodes as anything (m68k_scan.py)
	scan=$(python3 "$ROOT/tools/m68k_scan.py" "$bin")
	ins=$(echo "$scan" | grep -v '^scanned ' | awk '{print $3}' | sort | uniq -c |
	  sort -rn | head -5 | awk '{printf "%s%s x%s", s, $2, $1; s=", "}')
	cover=$(echo "$scan" | sed -n 's/^scanned .*(\(.*\))$/\1/p')
	if [ -z "$ins" ]; then ok "68020 soft-float code only (scanned $cover of the code hunk)"
	else bad "68030+/FPU instructions: $ins (m68k_scan.py $bin)"; fi
	set -- $("${X}size" "$bin" | awk 'NR == 2 { print $1, $2, $3 }') "$@"
	text=$1 data=$2 bss=$3; shift 3
	bytes=$(wc -c < "$bin" | tr -d ' ')
	grep -v "^$pkg	$name	" "$TSV" > "$TSV.new" || true
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pkg" "$name" "$bytes" "$text" "$data" "$bss" >> "$TSV.new"
	mv "$TSV.new" "$TSV"
	echo "       $pkg $name: $bytes bytes (text $text, data $data, bss $bss)"
done
exit $fails
