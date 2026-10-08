# GNU sed (vtcon plan 1.2): the gnulib recipe from grep (1.1).
sed_VERSION   := 4.10
sed_URL       := https://ftp.gnu.org/gnu/sed/sed-$(sed_VERSION).tar.xz
sed_SHA256    := b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7
sed_LICENSE   := GPL-3.0-or-later
sed_DEPS      := ixcompat
# no NLS catalogues in the kit; gnulib's threads would want pthreads, which
# ixemul has not; no ACL/SELinux on AmigaOS.
sed_CONFIGURE := --disable-nls --disable-threads --disable-acl --without-selinux
sed_HOST_CONFIGURE := --disable-nls
sed_BINS      := bin/sed
# provisional, grep's value, until the rig measures a deep regex
sed_STACK     := 262144
