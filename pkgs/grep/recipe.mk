# GNU grep (vtcon plan 1.1): the first gnulib port; sets the recipe pattern.
grep_VERSION   := 3.12
grep_URL       := https://ftp.gnu.org/gnu/grep/grep-$(grep_VERSION).tar.xz
grep_SHA256    := 2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9
grep_LICENSE   := GPL-3.0-or-later
grep_DEPS      := ixcompat
# PCRE (-P) off at first (plan 1.1); no NLS catalogues in the kit; gnulib's
# threads would want pthreads, which ixemul has not.
grep_CONFIGURE := --disable-nls --disable-perl-regexp --disable-threads
grep_HOST_CONFIGURE := --disable-nls --disable-perl-regexp
# egrep and fgrep are shell scripts in grep 3.x (exec grep -E/-F)
grep_BINS      := bin/grep
# provisional until the rig's stackprobe measures grep -E on a deep pattern
grep_STACK     := 262144
