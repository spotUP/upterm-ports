# GNU patch (vtcon plan 1.8). It runs ed or a merge tool only for unusual
# inputs.
patch_VERSION   := 2.8
patch_URL       := https://ftp.gnu.org/gnu/patch/patch-$(patch_VERSION).tar.xz
patch_SHA256    := f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3
patch_LICENSE   := GPL-3.0-or-later
patch_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed: --disable-year2038, as configure asks
patch_CONFIGURE := --disable-nls --disable-threads --disable-year2038 --disable-xattr
patch_HOST_CONFIGURE := --disable-xattr
patch_BINS      := bin/patch
patch_STACK     := 262144
