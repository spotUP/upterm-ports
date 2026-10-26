#!/bin/sh
# test_m68k_cc.sh: a call to tools/m68k-cc that compiles and links in one go keeps the CPU flags
# for the compile. The wrapper dropped -m68020 on every linking call, so "cc -m68020 -o x a.c"
# compiled a.c for 68000 (column, sqlite3, ptyrun). A fake gcc logs each call's arguments; the
# real toolchain, when installed, shows extb.l (a 68020-only instruction) in the linked program.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d "${TMPDIR:-/tmp}/test_m68k_cc.XXXXXX")
trap 'rm -rf "$t"' EXIT
bad=0
fail() { echo "test_m68k_cc: $*" >&2; bad=1; }

mkdir -p "$t/fake/bin"
cat > "$t/fake/bin/m68k-amigaos-gcc" <<'G'
#!/bin/sh
echo "$*" >> "$LOG"
for a; do case $a in -o) o=1 ;; *) [ "${o:-}" = 1 ] && : > "$a"; o= ;; esac; done
G
chmod +x "$t/fake/bin/m68k-amigaos-gcc"
export LOG="$t/log"
cd "$t"
run() { : > "$LOG"; AMIGA="$t/fake" "$ROOT/tools/m68k-cc" "$@"; }

run -m68020 -O2 -I inc -o prog a.c b.c -Wl,stack.o lib.a -lm
compiles=$(grep -c -- ' -c ' "$LOG" || true)
[ "$compiles" = 2 ] || fail "one-shot a.c b.c: $compiles compile calls, want 2"
grep -- ' -c ' "$LOG" | grep -v -- '-m68020' > /dev/null && fail "a compile call lost -m68020"
grep -- ' -c ' "$LOG" | grep -- '-I inc' > /dev/null || fail "compile call lost -I inc"
grep -- ' -c ' "$LOG" | grep -E -- 'lib\.a|-lm|-Wl,|-o prog' > /dev/null && fail "compile call got link-only arguments"
linkl=$(grep -v -- ' -c ' "$LOG")
case $linkl in *-m68020*) fail "link call kept -m68020: $linkl" ;; esac
case $linkl in *'-o prog'*'1.o'*'2.o'*'-Wl,stack.o lib.a -lm'*) ;; *) fail "link call wrong: $linkl" ;; esac

# Options whose value is a separate word keep it next to them: a bare --param in the compile
# took the following -I as its value and lost the include drawer (ncurses configure).
run -m68020 --param max-inline-insns-single=1200 -I inc -B bdir -u sym -o prog a.c
cl=$(grep -- ' -c ' "$LOG")
case $cl in *'--param max-inline-insns-single=1200 -I inc -B bdir'*) ;; *) fail "compile call split a separate value: $cl" ;; esac
case $cl in *' -u '*|*sym*) fail "compile call got the link-only -u sym: $cl" ;; esac
linkl=$(grep -v -- ' -c ' "$LOG")
case $linkl in *'-B bdir -u sym -o prog'*) ;; *) fail "link call lost a separate value: $linkl" ;; esac

run -m68020 -O2 -c a.c -o a.o
[ "$(wc -l < "$LOG")" -eq 1 ] && grep -- '-m68020 -O2 -c a.c -o a.o' "$LOG" > /dev/null || fail "compile-only call changed"

run -m68020 -o prog a.o b.o
case $(cat "$LOG") in *-m68020*) fail "link-only call kept -m68020" ;; esac

AMIGA=${AMIGA:-$HOME/opt/amiga}
if [ -x "$AMIGA/bin/m68k-amigaos-gcc" ]; then
	printf 'volatile signed char c = -2;\nint main(void) { long l = c; return l == -2 ? 0 : 1; }\n' > "$t/ext.c"
	AMIGA=$AMIGA "$ROOT/tools/m68k-cc" -m68020 -O2 -o "$t/ext" "$t/ext.c"
	"$AMIGA/bin/m68k-amigaos-objdump" -m m68k:68020 -d "$t/ext" | sed -n '/<_main>:/,/rts/p' | grep -q 'extbl' ||
		fail "one-shot -m68020 build of main has no extb.l: compiled for 68000"
else
	echo "test_m68k_cc: no toolchain, real compile skipped"
fi
[ $bad = 0 ] && echo "test_m68k_cc: ok"
exit $bad
