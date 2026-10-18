# opkg 0.9.0 (vtcon plan P10.2): the Yocto package manager, the base of upkg.
# First CMake package in the framework (opkg_CMAKE: mk/amiga-ixemul.cmake).
# P10.3 (patches/0001): the wget download backend runs `curl -fsSL -o`, the
# binary is `upkg` (GPL-2.0 rebrand: notices kept, changed files marked, the
# version line says "based on opkg"), the config is /UP-Term/etc/upkg.conf and
# state lives under /UP-Term/pkg/upkg (ixemul maps /UP-Term to UP-Term:).
# Staged into the kit as UP-Term/bin/upkg (P10.5-1); it replaced the vsh script of that name.
# No libcurl (downloads exec the curl of the base), no gpgme, no libsolv (internal solver), sha256 on.
# libarchive and liblzma come from the sysroot, static.
# patches/0003: cache files are named by 30 md5 hex digits (AmigaDOS keeps 30 characters of a name);
# the host build gets the same names from -DUPKG_SHORT_NAMES so check/cache_name.sh can see them.
opkg_VERSION   := 0.9.0
opkg_URL       := https://downloads.yoctoproject.org/releases/opkg/opkg-$(opkg_VERSION).tar.gz
opkg_SHA256    := 440ef321862e01f83da4d02884a0cbb4d9d7b32f82faa81a6a85493f0c89d0f5
opkg_LICENSE   := GPL-2.0-or-later (COPYING)
opkg_CMAKE     := 1
opkg_DEPS      := ixcompat zlib bzip2 xz libarchive
opkg_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DWITH_BZIP2=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF \
	-DSTATIC_LIBOPKG=ON -DWITH_LIBOPKG_API=OFF \
	-DSYSCONFDIR=/UP-Term/etc -DVARDIR=/UP-Term/pkg/upkg
opkg_LIBS      := -llzma -lbz2 -lz
opkg_CHECK_SH_BIN := bin/upkg
opkg_BINS      := bin/upkg
opkg_STACK     := 131072
opkg_HOST_DEPS := xz libarchive
opkg_HOST_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF -DWITH_LIBOPKG_API=OFF \
	-DCMAKE_PREFIX_PATH="$(HOSTB)/libarchive/inst;$(HOSTB)/xz/inst" \
	"-DCMAKE_C_FLAGS=-I$(HOSTB)/libarchive/inst/include -I$(HOSTB)/xz/inst/include -DUPKG_SHORT_NAMES" \
	-DSYSCONFDIR=/UP-Term/etc -DVARDIR=/UP-Term/pkg/upkg \
	-DSTATIC_LIBOPKG=ON "-DCMAKE_EXE_LINKER_FLAGS=-lz -lbz2 -liconv $(HOSTB)/xz/inst/lib/liblzma.a"
