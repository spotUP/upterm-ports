#!/bin/sh
# browse_dispatch.sh UPKG: host check that `upkg browse ARGS` hands ARGS to the browse script untouched
# and returns its exit code (patches/0016). UPKG_BROWSE replaces the script command; here it is a stub
# that writes its arguments one per line to a file and exits 7.
#   sh pkgs/opkg/check/browse_dispatch.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/browsedisp.XXXXXX")
trap 'rm -rf "$w"' EXIT
cat >"$w/stub" <<STUB
#!/bin/sh
: >"$w/args"
for a in "\$@"; do printf '%s\n' "\$a" >>"$w/args"; done
exit 7
STUB
chmod +x "$w/stub"
export UPKG_BROWSE="$w/stub"
run() { rc=0; "$upkg" "$@" >"$w/out" 2>"$w/err" || rc=$?; }

run browse --help
[ "$rc" -eq 7 ] || { echo "[FAIL] upkg browse --help exited $rc, want 7: $(head -2 "$w/err")"; exit 1; }
[ "$(cat "$w/args")" = "--help" ] || { echo "[FAIL] upkg browse --help passed: $(cat "$w/args" 2>&1)"; exit 1; }

run browse 'a b'
[ "$rc" -eq 7 ] || { echo "[FAIL] upkg browse 'a b' exited $rc, want 7"; exit 1; }
[ "$(cat "$w/args")" = "a b" ] || { echo "[FAIL] 'a b' was split or changed: $(cat "$w/args")"; exit 1; }

run browse x '$HOME' '*'
[ "$(cat "$w/args")" = 'x
$HOME
*' ] || { echo "[FAIL] shell metacharacters were expanded: $(cat "$w/args")"; exit 1; }

run browse "it's"
[ "$rc" -eq 2 ] || { echo "[FAIL] an argument with a quote exited $rc, want 2"; exit 1; }
grep -q 'single quote' "$w/err" || { echo "[FAIL] no refusal message: $(cat "$w/err")"; exit 1; }

run -o "$w" browse -h
[ "$rc" -eq 7 ] && [ "$(cat "$w/args")" = "-h" ] || { echo "[FAIL] option before browse: rc $rc args $(cat "$w/args")"; exit 1; }

run --help
grep -q '^  browse  ' "$w/out" || { echo "[FAIL] upkg --help does not list browse"; exit 1; }
echo "[OK] upkg browse: arguments reach the script as given, its exit code is returned, --help lists it"
