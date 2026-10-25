#!/bin/sh
# unpack-lha.sh DIR ARCHIVE...: unpack each lha ARCHIVE unmodified into DIR
# (the prebuilt payload of a <p>_LHA_URLS package). DIR is emptied first; each
# archive gets its own subdirectory DIR/<archive name without .lha>, so the two
# vbcc archives stay apart (and their top drawers vbcc_bin_amigaos68k/ and
# vbcc_target_m68k-amigaos/ stay as the author made them).
set -eu
dir=$1
shift
command -v lha > /dev/null || { echo "unpack-lha.sh: lha not found (brew install lha)" >&2; exit 1; }
rm -rf "$dir"
mkdir -p "$dir"
for a in "$@"; do
	d=$dir/$(basename "$a" .lha)
	mkdir -p "$d"
	(cd "$d" && lha -xq "$a")
done
