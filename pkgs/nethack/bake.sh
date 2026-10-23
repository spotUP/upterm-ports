#!/bin/sh
# bake.sh: bake NetHack's generated game data on a rig with the m68k tools, into pkgs/nethack/data/.
#
# Why on the Amiga: lev_comp, dgn_comp and `makedefs -q` write raw structs; their layout (8-byte long,
# little endian on the Mac) differs from m68k's, so the Mac cannot produce the data. The result is
# committed as generated data; `make nethack` installs it.
#
#   UPTERM_RIG=5 python3 <vtcon>/tools/rig/rig.py start --max     (the rig must be up; never rig 1)
#   make nethack                                                  (builds the m68k tools; the install stops
#                                                                  until data/ exists: then bake)
#   UPTERM_RIG=5 sh pkgs/nethack/bake.sh
#
# Steps, upstream's order (dat/Makefile + sys/unix/Makefile.top): makedefs -d -r -q -h -s -v -e,
# dgn_comp dungeon.pdf, lev_comp on every .des, dlb cf nhdat $(DATDLB). Outputs, fetched into data/:
# nhdat, symbols, date.h (the game is compiled against it: make nethack again after a bake) and STAMP (source version and hashes of every input and output). Rerunnable: the
# stage drawer is deleted and made again, the same inputs give the same STAMP.
# Env: UPTERM_VTCON (the vtcon checkout, default ../vtcon), UPTERM_RIG (the rig number), BAKE_LOGS.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
ports=$(cd "$here/../.." && pwd)
vtcon=${UPTERM_VTCON:-$ports/../vtcon}
rigdir=$vtcon/tools/rig
obj=$ports/build/obj/nethack
data=$here/data
logs=${BAKE_LOGS:-${TMPDIR:-/tmp}}
[ "${UPTERM_RIG:-1}" != 1 ] || { echo "bake.sh: set UPTERM_RIG to your own rig (never rig 1)" >&2; exit 1; }
for t in util/makedefs.m68k util/lev_comp util/dgn_comp util/dlb dat/dungeon.def; do
	[ -f "$obj/$t" ] || { echo "bake.sh: $obj/$t is missing: make nethack first" >&2; exit 1; }
done
file "$obj/util/lev_comp" | grep -q AmigaOS || { echo "bake.sh: util/lev_comp is not an m68k tool" >&2; exit 1; }
vtc=$(cd "$rigdir" && python3 -I -c 'import sys; sys.path.insert(0, "."); import paths; print(paths.RIG / "vtc")')
[ -d "$vtc" ] || { echo "bake.sh: $vtc: the rig is not set up" >&2; exit 1; }
# ami.py is a script in a directory of its own modules: run it from there
ami() ( cd "$rigdir" && python3 ami.py "$@" )
ami ping > /dev/null || { echo "bake.sh: the rig does not answer: rig.py start --max" >&2; exit 1; }

# 1. stage: VTC:nhbake/{util,dat,include}
stage=$vtc/nhbake
ami exec 'Delete >NIL: VTC:nhbake ALL QUIET FORCE' 60 > /dev/null || true
rm -rf "$stage"
mkdir -p "$stage/util" "$stage/dat" "$stage/include"
cp "$obj/util/makedefs.m68k" "$stage/util/makedefs"
cp "$obj/util/lev_comp" "$obj/util/dgn_comp" "$obj/util/dlb" "$stage/util/"
# the inputs: everything in dat/ that is source text (the .des files, the .txt files, data.base, ...)
for f in "$obj"/dat/*; do
	case $f in
	*.lev|*/dungeon|*/dungeon.pdf|*/nhdat|*/options|*/data|*/rumors|*/quest.dat|*/oracles|*/engrave|*/epitaph|*/bogusmon|*/Makefile|*/GENFILES|*/mdgrep.pl) ;;
	*) cp "$f" "$stage/dat/" ;;
	esac
done

# 2. the script, run by vsh on the rig (LC_ALL=C: the order of the dlb members)
cat > "$stage/bake.sh" <<'S'
cd VTC:nhbake/dat
export LC_ALL=C
export PATH=/VTC/nhbake/util:$PATH
set -e
../util/makedefs -d
../util/makedefs -r
../util/makedefs -q
../util/makedefs -h
../util/makedefs -s
../util/makedefs -v
../util/makedefs -e
../util/dgn_comp dungeon.pdf
for d in bigroom castle endgame gehennom knox medusa mines oracle sokoban tower yendor Arch Barb Caveman Healer Knight Monk Priest Ranger Rogue Samurai Tourist Valkyrie Wizard; do
../util/lev_comp $d.des
done
../util/dlb cf nhdat help hh cmdhelp keyhelp history opthelp wizhelp dungeon tribute asmodeus.lev baalz.lev bigrm-*.lev castle.lev fakewiz?.lev juiblex.lev knox.lev medusa-?.lev minend-?.lev minefill.lev minetn-?.lev oracle.lev orcus.lev sanctum.lev soko?-?.lev tower?.lev valley.lev wizard?.lev ???-goal.lev ???-fil?.lev ???-loca.lev ???-strt.lev bogusmon data engrave epitaph oracles options quest.dat rumors
echo "[bake done]"
S
rm -f "$stage/dat/nhdat"
ami exec 'VTC:vsh VTC:nhbake/bake.sh >VTC:nhbake/bake.log' 600 > "$logs/bake.rc" 2>&1 || true
cp "$stage/bake.log" "$logs/bake.log" 2>/dev/null || true
tail -3 "$logs/bake.log" 2>/dev/null
grep -q '^\[bake done\]' "$stage/bake.log" 2>/dev/null || { echo "bake.sh: the bake failed: see $logs/bake.log" >&2; exit 1; }
[ -s "$stage/dat/nhdat" ] || { echo "bake.sh: no nhdat" >&2; exit 1; }

# 3. fetch and stamp
mkdir -p "$data"
cp "$stage/dat/nhdat" "$stage/dat/symbols" "$data/"
# date.h from the m68k makedefs -v: the port name (global.h picks "Unix" for the m68k build, not "MacOSX") and the
# VERSION_SANITY values (struct sizes with the m68k 4-byte long) are the target's; the Mac makedefs
# writes the Mac's. nhbuild.sh copies it over include/date.h before the game is compiled.
[ -s "$stage/include/date.h" ] || { echo "bake.sh: no include/date.h" >&2; exit 1; }
cp "$stage/include/date.h" "$data/date.h"
sha() { shasum -a 256 | cut -d' ' -f1; }
{
	echo "nethack $(make -s -C "$ports" print-nethack_VERSION)"
	echo "source-sha256 $(make -s -C "$ports" print-nethack_SHA256)"
	echo "patches-sha256 $(cat "$here"/patches/*.patch | sha)"
	echo "inputs-sha256 $(cd "$obj/dat" && cat *.des bogusmon.txt engrave.txt epitaph.txt oracles.txt quest.txt data.base dungeon.def rumors.tru rumors.fal help hh cmdhelp keyhelp history opthelp wizhelp tribute symbols | sha)"
	echo "nhdat-sha256 $(sha < "$data/nhdat")"
	echo "nhdat-bytes $(wc -c < "$data/nhdat" | tr -d ' ')"
} > "$data/STAMP"
cat "$data/STAMP"
ami exec 'Delete >NIL: VTC:nhbake ALL QUIET FORCE' 60 > /dev/null || true
