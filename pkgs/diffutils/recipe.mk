# GNU diffutils (vtcon plan 1.7): diff, cmp, diff3, sdiff. diff3 and sdiff
# run diff as a child.
diffutils_VERSION   := 3.12
diffutils_URL       := https://ftp.gnu.org/gnu/diffutils/diffutils-$(diffutils_VERSION).tar.xz
diffutils_SHA256    := 7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd
diffutils_LICENSE   := GPL-3.0-or-later
diffutils_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed: --disable-year2038, as configure asks
diffutils_CONFIGURE := --disable-nls --disable-threads --disable-year2038
diffutils_HOST_CONFIGURE := --disable-nls
diffutils_BINS      := bin/diff bin/cmp bin/diff3 bin/sdiff
# provisional, grep's value: the regex code recurses
diffutils_STACK     := 262144
