#!/bin/sh
# recipe_lint.sh PKG...: static checks of pkgs/<pkg>/recipe.mk, read through recipe-var.sh (make print-%).
# Errors (exit 1): a field the build needs is empty, the URL is not https, a patch file is not *.patch,
# a program (_BINS) has no check/cases. Warning: no _LICENSE_FILES (kit-stage falls back to COPYING).
# Fields of own programs (_OWN) and prebuilt packages (_LHA_URLS) differ: no URL or sha256 is asked of them.
# The download and the sha256 compare are not here: tools/fetch.sh does that (make <pkg>.fetched, CI job "sha256").
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/recipe-var.sh"
bad=0
err() { echo "recipe_lint: $1: $2" >&2; bad=1; }
for p in "$@"; do
	[ -f "$ROOT/pkgs/$p/recipe.mk" ] || { err "$p" "no pkgs/$p/recipe.mk"; continue; }
	own=$(var "$p" OWN)
	lha=$(var "$p" LHA_URLS)
	for f in VERSION LICENSE; do
		[ -n "$(var "$p" $f)" ] || err "$p" "${p}_$f is empty"
	done
	if [ -z "$own" ] && [ -z "$lha" ]; then
		for f in URL SHA256; do
			[ -n "$(var "$p" $f)" ] || err "$p" "${p}_$f is empty"
		done
		case "$(var "$p" URL)" in
			https://*|'') ;;
			*) err "$p" "${p}_URL is not https: $(var "$p" URL)" ;;
		esac
		case "$(var "$p" SHA256)" in
			''|*[!0-9a-f]*) [ -z "$(var "$p" SHA256)" ] || err "$p" "${p}_SHA256 is not 64 lower-case hex digits" ;;
			*) [ "$(var "$p" SHA256 | wc -c | tr -d ' ')" = 65 ] || err "$p" "${p}_SHA256 is not 64 hex digits" ;;
		esac
		[ -n "$(var "$p" LICENSE_FILES)" ] || echo "recipe_lint: $p: warning: ${p}_LICENSE_FILES is empty (COPYING is assumed)" >&2
	fi
	for f in "$ROOT/pkgs/$p/patches"/*; do
		[ -e "$f" ] || break
		case "$f" in *.patch) ;; *) err "$p" "patches/$(basename "$f") is not a *.patch file" ;; esac
	done
	if [ -n "$(var "$p" BINS)" ] && [ -z "$own" ]; then
		[ -s "$ROOT/pkgs/$p/check/cases" ] || [ -d "$ROOT/pkgs/$p/check/tty" ] || err "$p" "has _BINS but no pkgs/$p/check/cases"
	fi
done
[ "$bad" = 0 ] && echo "recipe_lint: $* ok"
exit "$bad"
