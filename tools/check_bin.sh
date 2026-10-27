#!/bin/sh
# check_bin.sh PKG STACK BINARY...: host checks on linked m68k programs
# (vtcon plan item 0.4). For each binary:
#   hunk     an AmigaOS executable (HUNK_HEADER 0x000003F3)
#   ixemul   it opens ixemul.library (an ixemul crt0, not libnix)
#   fork     no fork(): ixemul has none (vfork only), so a _fork symbol
#            means a fork() call that fails at run time
#   stack    the $STACK: cookie, when the recipe asks for one (STACK = bytes)
#   cookies  at most one $STACK cookie in the file (two leave the size to scan order)
#   ncurses  a binary linking ncurses needs __stack and STACK >= 262144
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
# stack_var BINARY: the value of the program's __stack variable, empty when there is none.
# nm alone proves nothing: ixemul's libc links its own default __stack (stack.o) into every program.
stack_var() {
	addr=$("${X}objdump" -t "$1" 2>/dev/null | awk '$NF == "___stack" && $2 == "g" { print $1; exit }')
	[ -n "$addr" ] || return 0
	"${X}objdump" -s -j .data --start-address=$((16#$addr)) --stop-address=$((16#$addr + 4)) "$1" 2>/dev/null |
		awk '/^ [0-9a-f]+ [0-9a-f]+/ { print "0x" $2; exit }' | { read -r h; [ -n "$h" ] && printf '%d\n' "$h"; }
}
mkdir -p "$(dirname "$TSV")"
[ -f "$TSV" ] || printf 'package\tbinary\tfile\ttext\tdata\tbss\n' > "$TSV"
[ $# -gt 0 ] || { echo "[FAIL] $pkg: no binaries named (<pkg>_BINS)"; exit 1; }
for bin; do
	name=$(basename "$bin")
	if [ ! -f "$bin" ]; then bad "missing: $bin"; continue; fi
	# a #!/bin/sh script (git's dashed helpers run `git <command>`) has no
	# code to check: it must be executable and name /bin/sh
	if [ "$(head -c 2 "$bin")" = '#!' ]; then
		if [ "$(head -n 1 "$bin")" = '#!/bin/sh' ] && [ -x "$bin" ]; then ok "#!/bin/sh script"
		else bad "script without an executable #!/bin/sh line"; fi
		continue
	fi
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
	# more than one $STACK cookie: which one the loader honours depends on scan order
	# (curl's upstream min_stack "$STACK:32768" next to the port's 262144)
	cookies=$(strings -a "$bin" | grep -c '\$STACK:')
	if [ "$cookies" -gt 1 ]; then
		bad "$cookies \$STACK cookies (want one): $(strings -a "$bin" | grep -o '\$STACK: *[0-9]*' | tr '\n' ' ')"
	fi
	# __stack: a program started by vfork + exec (upkg's curl and scripts, ptyrun) ignores the cookie
	sv=$(stack_var "$bin")
	if [ -n "${STACK_VAR:-}" ]; then
		if [ -n "$sv" ] && [ "$sv" = "$stack" ]; then ok "__stack = $sv"
		else bad "__stack is '${sv:-undefined}', recipe sets STACK_VAR (want $stack; ixemul's default __stack does not count)"; fi
	fi
	# ncurses program without __stack crashes when started from a shell: a program started by
	# vfork + exec (vsh, ptyrun, upkg) ignores the $STACK: cookie and gets 16 KB, which the
	# terminfo/tparm expansion overruns (Alert 81000005). A binary that links ncurses
	# (tparm, setupterm, initscr, newterm) needs __stack and a STACK of at least 262144.
	if "${X}nm" "$bin" 2>/dev/null | awk '$3 ~ /^_?(tparm|setupterm|initscr|newterm)$/' | grep -q .; then
		if [ -n "$sv" ] && [ "$sv" -ge 262144 ]; then ok "ncurses program has __stack $sv"
		else bad "ncurses program without __stack crashes when started from a shell (__stack '${sv:-undefined}', want >= 262144; recipe needs <p>_STACK_VAR := 1)"; fi
		if [ -z "$stack" ] || [ "$stack" -lt 262144 ] 2>/dev/null; then
			bad "ncurses program with STACK '${stack:-none}' below 262144 crashes when started from a shell"
		fi
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
