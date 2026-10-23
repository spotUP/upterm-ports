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
# Atomic: everything is staged into userland.new / userland-src.new and swapped in
# only when every package staged and the final checks passed; a failing package
# leaves the old kit untouched (mutt's licence file name, 2026-10-23, left a
# half-staged userland and a later `make dist` failed on a missing bin/perl).
FINAL=$B/kit/userland
FINALSRC=$B/kit/userland-src
KIT=$FINAL.new
KSRC=$FINALSRC.new
. "$ROOT/tools/recipe-var.sh"

# A package that is installed but not checked was rebuilt and its check did
# not run (or failed): skipping it quietly shipped a kit with no xz and no tar
# (2026-10-19, caught only by the rig install). Stop before the old kit goes.
unchecked=
for p in $PKGS; do
	[ "$p" != ixcompat ] || continue
	[ -z "$(var "$p" NO_KIT)" ] || continue
	[ -z "$(var "$p" KIT_HOLD)" ] || continue
	[ -f "$STATE/$p.installed" ] && [ ! -f "$STATE/$p.checked" ] && unchecked="$unchecked $p"
done
if [ -n "$unchecked" ]; then
	echo "kit-stage: installed but not checked:$unchecked (run make$unchecked, or set <p>_KIT_HOLD)" >&2
	exit 1
fi

rm -rf "$KIT" "$KSRC"
trap 'rm -rf "$KIT" "$KSRC"' EXIT
mkdir -p "$KIT/bin" "$KIT/licenses" "$KSRC/ports"

for p in $PKGS; do
	# <p>_NO_KIT: built and checked, not shipped
	[ -z "$(var "$p" NO_KIT)" ] || { echo "kit-stage: $p skipped (NO_KIT)"; continue; }
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
	mkdir -p "$KSRC/$p"
	if [ -n "$(var "$p" OWN)" ]; then
		# our own program: no licence file to carry, the source is pkgs/<p>/src
		cp -R "$ROOT/pkgs/$p/." "$KSRC/$p/"
		printf '%s\t%s\t%s\t%s\t%s\n' "$p" "$(var "$p" VERSION)" "own (pkgs/$p/src)" \
			"-" "$(var "$p" LICENSE)" >> "$KIT/SOURCES.txt"
		continue
	fi
	lic=$(var "$p" LICENSE_FILES)
	[ -n "$lic" ] || lic=COPYING
	mkdir -p "$KIT/licenses/$p"
	for f in $lic; do
		[ -f "$SRC/$p/$f" ] || { echo "kit-stage: $p: no licence file $f in $SRC/$p" >&2; exit 1; }
		cp "$SRC/$p/$f" "$KIT/licenses/$p/"
	done
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
# (each package's BINS read once: one make per package, not one per program and package)
owners=$(for p in $PKGS; do for x in $(var "$p" BINS); do echo "$(basename "$x") $p"; done; done)
for b in "$KIT"/bin/*; do
	n=$(basename "$b")
	found=$(echo "$owners" | awk -v n="$n" '$1 == n { p = $2 } END { print p }')
	grep -q "^$found	" "$KIT/SOURCES.txt" || { echo "kit-stage: $n has no SOURCES.txt row" >&2; exit 1; }
done
trap - EXIT
rm -rf "$FINAL" "$FINALSRC"
mv "$KIT" "$FINAL"
mv "$KSRC" "$FINALSRC"
KIT=$FINAL
echo "kit-stage: $(ls "$KIT/bin" | wc -l | tr -d ' ') programs, $(find "$KIT/share/man" -type f | wc -l | tr -d ' ') pages, $(wc -l < "$KIT/SOURCES.txt" | tr -d ' ') packages"
cat "$KIT/SOURCES.txt"
