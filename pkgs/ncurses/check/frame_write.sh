#!/bin/sh
# frame_write.sh NCURSES: host check that one doupdate() is one write() (patches/0001).
# newterm left the screen in ewInitial and doupdate only set ewRunning after an endwin, so
# _nc_mvcur flushed the output buffer after every cursor move inside doupdate: a full-screen
# frame went out as one write per line and the Amiga handler drew it line by line. The patch
# makes doupdate mark the screen ewRunning on its first run; the frame then leaves as one write.
# frame_write.c is built against the host libncursesw.a (same patched source as the m68k build)
# and counts the write() calls of a full-screen frame. Fails (writes=LINES) without the patch.
#   sh pkgs/ncurses/check/frame_write.sh build/host/ncurses/inst/bin/tput
set -eu
inst=$(cd "$(dirname "$1")/.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
w=$(mktemp -d "${TMPDIR:-/tmp}/framewrite.XXXXXX")
trap 'rm -rf "$w"' EXIT
cc -O -I"$inst/include" -I"$inst/include/ncursesw" "$here/frame_write.c" "$inst/lib/libncursesw.a" -o "$w/frame_write" \
	|| { echo "[FAIL] frame_write.c does not build against $inst"; exit 1; }
# vtcon's terminfo when the kit tools built it, else the system's xterm
if [ -d "$root/build/tools/terminfo" ]; then ti=$root/build/tools/terminfo; term=vtcon
else ti=/usr/share/terminfo; term=xterm; fi
out=$(cd "$w" && LINES=25 COLUMNS=80 TERM=$term TERMINFO=$ti "$w/frame_write" 2>&1 < /dev/null) && rc=0 || rc=$?
case "$rc" in
0) echo "[OK] ncurses frame write: one write per doupdate ($out)" ;;
1) echo "[FAIL] ncurses doupdate split the frame into several writes: $out (want writes=1)"; exit 1 ;;
*) echo "[FAIL] frame_write could not run: $out"; exit 1 ;;
esac
