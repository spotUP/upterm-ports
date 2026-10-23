#!/bin/sh
# nhbuild.sh MODE OBJDIR [ARGS]: the NetHack build steps of recipe.mk (NetHack has no configure; the
# Makefiles come from sys/unix/setup.sh and a hints file).
#   m68k OBJ [DATA]       game and data tools for the Amiga; makedefs for the Mac builds the generated
#                         headers and text, then the m68k objects replace its objects
#   host OBJ INST         the whole game on the Mac into INST
#   install OBJ ROOT DATA bin/nethack and the playground ROOT/share/nethack (nhdat from DATA, baked
#                         on the Amiga: pkgs/nethack/bake.sh)
set -eu
mode=$1 obj=$2
cd "$obj"
case $mode in
m68k)
	# 1. makedefs for the Mac: the headers (date.h, onames.h, pm.h, vis_tab.h) and the text data.
	# -DNOMAIL as in the game's hints file: onames.h counts the objects, and objects.c has one fewer
	# (no mail scroll) with NOMAIL; without it every object index after SCR_MAIL is off by one on the
	# Amiga (init-prob error for class 13)
	make -C util makedefs CC=cc LINK=cc CFLAGS="-O -include sys/cdefs.h -I../include -Wno-everything -DNOMAIL" LFLAGS= > util.host.log 2>&1 || { tail -20 util.host.log; exit 1; }
	mv util/makedefs util/makedefs.mac
	rm -f util/*.o src/*.o
	cp util/makedefs.mac util/makedefs
	# 2. the generated files, with the Mac makedefs
	( cd util && ./makedefs -v && ./makedefs -o && ./makedefs -p && ./makedefs -z ) > gen.log 2>&1 || { tail -20 gen.log; exit 1; }
	# the Mac makedefs stays: the m68k tools do not link it again
	sed -i.bak 's/^\t\$(CC) \$(LFLAGS) -o makedefs \$(MAKEOBJS)$/\tcp makedefs.mac makedefs/' util/Makefile
	# 3. date.h baked on the rig by the m68k makedefs (bake.sh); newer than every source, so make keeps it
	# and the src Makefile's date.h rule (the Mac makedefs -v) must not run again. It goes in BEFORE the
	# tools: dgn_comp and lev_comp write its VERSION_SANITY values into dungeon and the levels, and the
	# Mac makedefs -v computes them with 8-byte longs (game: Configuration incompatibility for file dungeon)
	if [ -f "$3/date.h" ]; then
		cp "$3/date.h" include/date.h
		sed -i.bak 's|^\t\.\./util/makedefs -v$|\t@echo "date.h: baked on the rig"|' src/Makefile
		grep -q 'date.h: baked on the rig' src/Makefile || { echo "nhbuild.sh: src/Makefile date.h rule not found" >&2; exit 1; }
		touch include/date.h
	fi
	# 4. the m68k tools and the game (-o makedefs: the Mac copy stays)
	make -C util lev_comp dgn_comp dlb > util.m68k.log 2>&1 || { grep -E -B2 'error|undefined' util.m68k.log | head -40; exit 1; }
	# makedefs for the Amiga too: bake.sh runs it there (makedefs -q writes raw structs); the Mac one stays
	# as util/makedefs, the m68k one is util/makedefs.m68k
	rm -f util/makedefs util/makedefs.o
	make -C util -f Makefile.bak makedefs > util.m68k.makedefs.log 2>&1 || { grep -E -B2 'error|undefined' util.m68k.makedefs.log | head -40; exit 1; }
	mv util/makedefs util/makedefs.m68k
	cp util/makedefs.mac util/makedefs
	make -C src nethack > src.m68k.log 2>&1 || { grep -E -B2 'error|undefined' src.m68k.log | head -40; exit 1; }
	;;
host)
	inst=$3
	make all > make.host.log 2>&1 || { grep -E -B2 'error:|undefined|\*\*\*' make.host.log | head -40; exit 1; }
	mkdir -p "$inst/bin" "$inst/share/nethack"
	cp src/nethack "$inst/bin/nethack"
	cp dat/nhdat dat/license dat/symbols sys/unix/sysconf "$inst/share/nethack/"
	: > "$inst/share/nethack/record"; : > "$inst/share/nethack/perm"; : > "$inst/share/nethack/logfile"; : > "$inst/share/nethack/xlogfile"
	;;
install)
	root=$3 data=$4
	[ -f "$data/date.h" ] && cmp -s "$data/date.h" include/date.h || { echo "nhbuild.sh: the game was not built with the baked date.h: bake.sh, then make nethack again" >&2; exit 1; }
	mkdir -p "$root/bin" "$root/share/nethack"
	cp src/nethack "$root/bin/nethack"
	[ -f "$data/nhdat" ] || { echo "nhbuild.sh: $data/nhdat is missing: run pkgs/nethack/bake.sh on a rig" >&2; exit 1; }
	cp "$data/nhdat" dat/license dat/symbols sys/unix/sysconf "$root/share/nethack/"
	for f in record perm logfile xlogfile; do : > "$root/share/nethack/$f"; done
	;;
esac
