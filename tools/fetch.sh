#!/bin/sh
# fetch.sh URL SHA256 FILE: download URL to FILE once and verify it.
# A file already there with the right hash is kept (resumable); a wrong
# hash is an error and the file is moved aside, never used.
set -eu
url=$1 sum=$2 out=$3
mkdir -p "$(dirname "$out")"
have() { [ -f "$out" ] && [ "$(shasum -a 256 "$out" | cut -d' ' -f1)" = "$sum" ]; }
if have; then exit 0; fi
[ -f "$out" ] && mv "$out" "$out.bad"
curl -fL --retry 3 -o "$out.part" "$url"
mv "$out.part" "$out"
if ! have; then
	got=$(shasum -a 256 "$out" | cut -d' ' -f1)
	mv "$out" "$out.bad"
	echo "fetch.sh: sha256 mismatch for $url: want $sum, got $got (kept as $out.bad)" >&2
	exit 1
fi
echo "fetched $(basename "$out") (sha256 ok)"
