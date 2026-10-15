# GNU coreutils 9 (vtcon plan 3.7), replacing the kit's Geek Gadgets coreutils 5.2.1 (dist/gg/coreutils-5.2.1).
# Separate programs (AmigaOS has no symlinks for commands, so --enable-single-binary=symlinks cannot stand in).
coreutils_VERSION   := 9.12
coreutils_URL       := https://ftp.gnu.org/gnu/coreutils/coreutils-$(coreutils_VERSION).tar.xz
# verified against coreutils-9.12.tar.xz.sig with the GNU keyring (2026-10-11)
coreutils_SHA256    := a480198559733e9b3da999e90543ac6f888a2caa544d8d664c5a1f17e528e210
coreutils_LICENSE   := GPL-3.0-or-later
coreutils_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed: --disable-year2038; no ACLs, xattrs, SELinux, capabilities, GMP or OpenSSL
# on the Amiga; no stdbuf (an LD_PRELOAD library: AmigaOS has no shared objects; configure took the m68k
# linker's -shared for yes and libstdbuf.so failed on crt0's main)
coreutils_CONFIGURE := --disable-nls --disable-threads --disable-year2038 --disable-acl --disable-xattr \
                       --without-selinux --disable-libcap --without-gmp --without-openssl --disable-rpath \
                       --enable-no-install-program=stdbuf
coreutils_HOST_CONFIGURE := --disable-nls --without-gmp --without-openssl
# provisional, grep's value: sort, du, ls and cp recurse or sort in memory
coreutils_STACK     := 262144
