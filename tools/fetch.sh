#!/bin/sh
# fetch.sh URL SHA256 FILE [MIRROR...]: download URL to FILE once and verify it.
# A URL that fails (403, 404, timeout) is followed by the next MIRROR; the same
# SHA256 check applies to whichever one served the file.
# A file already there with the right hash is kept (resumable); a wrong
# hash is an error and the file is moved aside, never used.
set -eu
url=$1 sum=$2 out=$3
shift 3
mkdir -p "$(dirname "$out")"
have() { [ -f "$out" ] && [ "$(shasum -a 256 "$out" | cut -d' ' -f1)" = "$sum" ]; }
if have; then exit 0; fi
[ -f "$out" ] && mv "$out" "$out.bad"
for u in "$url" "$@"; do
	if curl -fL --retry 3 -o "$out.part" "$u"; then url=$u; break; fi
	echo "fetch.sh: $u failed, trying next mirror" >&2; url=
done
[ -n "$url" ] || { echo "fetch.sh: every URL failed for $(basename "$out")" >&2; exit 1; }
mv "$out.part" "$out"
if ! have; then
	got=$(shasum -a 256 "$out" | cut -d' ' -f1)
	mv "$out" "$out.bad"
	echo "fetch.sh: sha256 mismatch for $url: want $sum, got $got (kept as $out.bad)" >&2
	exit 1
fi
echo "fetched $(basename "$out") (sha256 ok)"
