#!/bin/sh
# sync_frame.sh NCURSES: host check that doupdate wraps a changing frame in the Sync capability once (patches/0008).
# sync_frame.c is built against the host libncursesw.a (same patched source as the m68k build) and run on two
# throwaway terminals compiled here: one declaring Sync (vtcon's string), one without. With the capability a
# frame that changes lines is one write that starts with Sync(1) and ends with Sync(0), an unchanged frame and
# a rewrite of identical text emit nothing; without it no Sync byte appears. Fails when the patch is reverted.
#   sh pkgs/ncurses/check/sync_frame.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/syncframe.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" "$here/sync_frame.c" "$inst/lib/libncursesw.a" -o "$w/sync_frame" \
	|| { echo "[FAIL] sync_frame.c does not build against $inst"; exit 1; }
cat > "$w/t.src" <<'TI'
nosync|terminal without Sync, am, cols#80, lines#25,
	cup=\E[%i%p1%d;%p2%dH, clear=\E[H\E[2J, el=\E[K, ed=\E[J, home=\E[H,
	cuf1=\E[C, cub1=^H, cud1=^J, cr=^M, sgr0=\E[m, bold=\E[1m,
syncterm|terminal with Sync, use=nosync,
	Sync=\E[?2026%?%p1%{1}%-%tl%eh%;,
TI
mkdir "$w/ti"
"$inst/bin/tic" -x -o "$w/ti" "$w/t.src" || { echo "[FAIL] tic could not compile the test terminals"; exit 1; }
rc=0
for case in "syncterm expect-sync" "nosync expect-none"; do
	set -- $case
	out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$1 TERMINFO=$w/ti ./sync_frame $2 2>&1 < /dev/null) && r=0 || r=$?
	if [ "$r" = 0 ]; then echo "[OK] ncurses sync_frame $1: $out"; else echo "[FAIL] ncurses sync_frame $1 ($2): $out"; rc=1; fi
done
exit $rc
