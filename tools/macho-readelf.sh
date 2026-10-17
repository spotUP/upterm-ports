#!/bin/sh
# macho-readelf.sh --syms FILE.o: the one thing perl-cross asks of readelf (the size of
# the global `foo` in a try.o), answered for a Mach-O object (macOS host) or an Amiga hunk
# object (the m68k nm in $UPTERM_NM); neither is ELF, so readelf cannot read them.
# perl-cross greps "foo" and takes the number after the symbol value. A tentative
# definition (`T foo;`) is a common symbol whose nm value is its size.
[ "$1" = --syms ] || { echo "macho-readelf.sh: only --syms" >&2; exit 2; }
{ [ -z "${UPTERM_NM:-}" ] || "$UPTERM_NM" -g "$2" 2>/dev/null; nm -g "$2" 2>/dev/null; } |
while read -r val kind name; do
	[ "$name" = _foo ] || continue
	printf '     1: 00000000 %s OBJECT  GLOBAL DEFAULT  COM foo\n' "$((0x$val))"
	break
done
