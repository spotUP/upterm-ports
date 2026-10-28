#!/bin/sh
# test_amisslstubs_no_poll.sh: a port that links -lamisslstubs (or takes AMISSL_LDFLAGS from mk/amissl.mk) holds raw bsdsocket descriptors, and
# libixcompat's poll() takes ixemul fds only (vtcon thoughts/spot/term-findings/ixcompat-poll-bsdsocket.md),
# so such a port must not use poll(). Static check of the recipe text (comments stripped):
#   - no HAVE_POLL defined anywhere in it;
#   - curl (configure) says ac_cv_func_poll=no;
#   - lynx and mutt carry -DAMIGA_BSDSOCKET (select -> WaitSelect patch);
#   - git reaches the network only through the sysroot libcurl (-lcurl), which is checked above.
# Any other recipe that links -lamisslstubs fails until it is given a rule here.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bad=0
code() { sed -e 's/[[:space:]]#.*$//' -e '/^[[:space:]]*#/d' "$ROOT/pkgs/$1/recipe.mk"; }
fail() { echo "test_amisslstubs_no_poll: $*" >&2; bad=1; }
for f in "$ROOT"/pkgs/*/recipe.mk; do
	p=$(basename "$(dirname "$f")")
	code "$p" | grep -q -e '-lamisslstubs' -e 'AMISSL_LDFLAGS' || continue
	code "$p" | grep -q 'HAVE_POLL' && fail "$p: links -lamisslstubs but defines HAVE_POLL"
	case "$p" in
		curl) code curl | grep -q 'ac_cv_func_poll=no' || fail "curl: links -lamisslstubs but does not set ac_cv_func_poll=no" ;;
		lynx|mutt) code "$p" | grep -q -e '-DAMIGA_BSDSOCKET' || fail "$p: links -lamisslstubs but lacks -DAMIGA_BSDSOCKET (select -> WaitSelect)" ;;
		git) code git | grep -q -e '-lcurl' || fail "git: links -lamisslstubs but not through the sysroot libcurl" ;;
		*) fail "$p: links -lamisslstubs; add its no-poll rule to tools/test_amisslstubs_no_poll.sh" ;;
	esac
done
[ $bad = 0 ] && echo "test_amisslstubs_no_poll: ok"
exit $bad
