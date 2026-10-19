#!/bin/sh
# test_check_bin.sh: check_bin.sh on files that are not linked programs. git's
# dashed helpers became #!/bin/sh scripts and git.checked failed with "not a
# hunk executable", so a script in <p>_BINS must pass and a broken one fail.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
bad=0

printf '#!/bin/sh\nexec git upload-pack "$@"\n' > "$T/git-upload-pack"
chmod 755 "$T/git-upload-pack"
if ! out=$(sh "$ROOT/tools/check_bin.sh" testpkg "" "$T/git-upload-pack"); then
	echo "test_check_bin: an executable #!/bin/sh script failed: $out" >&2; bad=1
fi

printf '#!/bin/bash\necho hi\n' > "$T/other"
chmod 755 "$T/other"
if sh "$ROOT/tools/check_bin.sh" testpkg "" "$T/other" > /dev/null; then
	echo "test_check_bin: a #!/bin/bash script passed" >&2; bad=1
fi

printf '#!/bin/sh\necho hi\n' > "$T/noexec"
chmod 644 "$T/noexec"
if sh "$ROOT/tools/check_bin.sh" testpkg "" "$T/noexec" > /dev/null; then
	echo "test_check_bin: a script that is not executable passed" >&2; bad=1
fi

printf 'plain text\n' > "$T/text"
if sh "$ROOT/tools/check_bin.sh" testpkg "" "$T/text" > /dev/null; then
	echo "test_check_bin: a text file passed as a hunk executable" >&2; bad=1
fi

[ $bad = 0 ] && echo "test_check_bin: ok"
exit $bad
