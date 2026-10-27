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

# two $STACK cookies in one program (the port's and one in upstream source, curl's
# min_stack) leave the stack size to scan order: check_bin.sh must fail it. Needs a
# linked program that is otherwise clean: the built curl, with a second cookie appended.
cur=$ROOT/build/sysroot/UP-Term/bin/curl
if [ -f "$cur" ]; then
	cp "$cur" "$T/two"
	printf '$STACK:32768\0' >> "$T/two"
	if out=$(sh "$ROOT/tools/check_bin.sh" testpkg 262144 "$T/two") ; then
		echo "test_check_bin: a program with two \$STACK cookies passed" >&2; bad=1
	elif ! echo "$out" | grep -q 'FAIL.*cookies'; then
		echo "test_check_bin: two cookies failed for another reason: $out" >&2; bad=1
	fi
else
	echo "test_check_bin: skipped the two-cookie case (no $cur)" >&2
fi

[ $bad = 0 ] && echo "test_check_bin: ok"
exit $bad
