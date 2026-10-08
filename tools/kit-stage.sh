#!/bin/sh
# kit-stage.sh: what vtcon's kit ships of the ports (plan item 1.10), from
# the checked packages. Run by `make kit-stage`, which exports ROOT, B,
# STATE, SYSROOT, PREFIX, SRC, IXEMUL and PKGS.
#
#   build/kit/userland/            copied by the kit into UP-Term: (bin, share, etc)
#     bin/                         every package's <p>_BINS
#     share/man/manN/              the pages of those programs (<name>.N*),
#                                  and <p>_MANS
#     <p>_DATA                     more installed paths (nano's syntax files)
#     etc/... from pkgs/<p>/kit/   files the ports add (nano's nanorc)
#     licenses/<p>/                <p>_LICENSE_FILES from the source tree
#     SOURCES.txt                  package, version, URL, sha256, licence
#   build/kit/userland-src/        the corresponding source (plan D2: the
#                                  separate UP-Term-src archive)
#     <p>/<archive> + pkgs/<p>/    upstream archive, recipe, patches, checks
#     ports/                       Makefile, mk/, tools/: the build scripts
#     ixcompat/libixcompat-src.tar ixemul-vtcon's compat/ and include/
#
# A package counts when its build is checked (build/state/<p>.checked, or
# ixcompat.installed): libraries too, since the programs link them. A
# recipe's <p>_KIT_HOLD (a reason) keeps a package out of the kit.
set -eu
KIT=$B/kit/userland
KSRC=$B/kit/userland-src
rm -rf "$KIT" "$KSRC"
mkdir -p "$KIT/bin" "$KIT/licenses" "$KSRC/ports"
var() { make -s -C "$ROOT" "print-$1-$2"; }

for p in $PKGS; do
	if [ "$p" = ixcompat ]; then
		[ -f "$STATE/ixcompat.installed" ] || continue
		mkdir -p "$KSRC/ixcompat" "$KIT/licenses/ixcompat"
		git -C "$IXEMUL" archive --format=tar -o "$KSRC/ixcompat/libixcompat-src.tar" HEAD compat include \
			docker/install-sdk-headers.sh COPYING COPYRIGHT LICENSES.README
		for f in COPYING COPYRIGHT LICENSES.README; do cp "$IXEMUL/$f" "$KIT/licenses/ixcompat/"; done
		printf '%s\t%s\t%s\t%s\t%s\n' ixcompat "$(git -C "$IXEMUL" describe --always)" \
			"ixemul-vtcon (UP-Term), compat/ and include/" "-" "$(var ixcompat LICENSE)" >> "$KIT/SOURCES.txt"
		continue
	fi
	[ -f "$STATE/$p.checked" ] || continue
	hold=$(var "$p" KIT_HOLD)
	if [ -n "$hold" ]; then
		echo "kit-stage: $p held back: $hold" >&2
		continue
	fi
	for b in $(var "$p" BINS); do
		cp "$SYSROOT$PREFIX/$b" "$KIT/bin/"
		n=$(basename "$b")
		for m in "$SYSROOT$PREFIX"/share/man/man*/"$n".[0-9]*; do
			[ -f "$m" ] || continue
			d=$KIT/share/man/$(basename "$(dirname "$m")")
			mkdir -p "$d" && cp "$m" "$d/"
		done
	done
	for m in $(var "$p" MANS); do
		mkdir -p "$KIT/$(dirname "$m")" && cp "$SYSROOT$PREFIX/$m" "$KIT/$m"
	done
	for d in $(var "$p" DATA); do
		mkdir -p "$KIT/$(dirname "$d")" && cp -R "$SYSROOT$PREFIX/$d" "$KIT/$(dirname "$d")/"
	done
	[ -d "$ROOT/pkgs/$p/kit" ] && cp -R "$ROOT/pkgs/$p/kit/." "$KIT/"
	lic=$(var "$p" LICENSE_FILES)
	[ -n "$lic" ] || lic=COPYING
	mkdir -p "$KIT/licenses/$p"
	for f in $lic; do
		[ -f "$SRC/$p/$f" ] || { echo "kit-stage: $p: no licence file $f in $SRC/$p" >&2; exit 1; }
		cp "$SRC/$p/$f" "$KIT/licenses/$p/"
	done
	mkdir -p "$KSRC/$p"
	cp "$B/dl/$(basename "$(var "$p" ARCHIVE)")" "$KSRC/$p/"
	cp -R "$ROOT/pkgs/$p/." "$KSRC/$p/"
	printf '%s\t%s\t%s\t%s\t%s\n' "$p" "$(var "$p" VERSION)" "$(var "$p" URL)" \
		"$(var "$p" SHA256)" "$(var "$p" LICENSE)" >> "$KIT/SOURCES.txt"
done
cp "$ROOT/Makefile" "$ROOT/RULES.md" "$KSRC/ports/"
cp -R "$ROOT/mk" "$ROOT/tools" "$KSRC/ports/"
cp "$KIT/SOURCES.txt" "$KSRC/"

# every shipped program has its package's row (a GPL binary without its
# source would be a licence violation: plan risk 7)
for b in "$KIT"/bin/*; do
	n=$(basename "$b")
	found=
	for p in $PKGS; do
		for x in $(var "$p" BINS); do [ "$(basename "$x")" = "$n" ] && found=$p; done
	done
	grep -q "^$found	" "$KIT/SOURCES.txt" || { echo "kit-stage: $n has no SOURCES.txt row" >&2; exit 1; }
done
echo "kit-stage: $(ls "$KIT/bin" | wc -l | tr -d ' ') programs, $(find "$KIT/share/man" -type f | wc -l | tr -d ' ') pages, $(wc -l < "$KIT/SOURCES.txt" | tr -d ' ') packages"
cat "$KIT/SOURCES.txt"
