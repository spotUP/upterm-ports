#!/bin/sh
# help_width.sh UPKG: host check that no line of `upkg --help` is wider than 76 columns with tabs
# expanded to 8. A 640x256 hires Workbench shell (topaz 8, window borders included) fits about 77
# columns, and stock opkg prints lines up to 103, which the shell wraps in the middle of a word.
# patches/0008 reflows usage().
#   sh pkgs/opkg/check/help_width.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/helpwidth.XXXXXX")
trap 'rm -rf "$w"' EXIT
"$upkg" --help > "$w/help" 2>&1 || true
[ "$(wc -l < "$w/help")" -gt 20 ] || { echo "[FAIL] upkg --help printed too little: $(head -3 "$w/help")"; exit 1; }
expand -t8 "$w/help" | awk '{ if (length($0) > 76) { bad++; print "[FAIL] help line " NR " is " length($0) " columns: " $0 } if (length($0) > max) max = length($0) }
  END { if (bad) exit 1; print "[OK] upkg --help: longest line " max " columns (limit 76)" }'
