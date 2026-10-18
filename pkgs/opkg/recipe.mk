# opkg 0.9.0 (vtcon plan P10.2): the Yocto package manager, the base of upkg.
# First CMake package in the framework (opkg_CMAKE: mk/amiga-ixemul.cmake).
# No libcurl (downloads go through the wget backend until P10.3 replaces it
# with a curl exec backend), no gpgme, no libsolv (internal solver), sha256 on.
# libarchive and liblzma come from the sysroot, static.
opkg_VERSION   := 0.9.0
opkg_URL       := https://downloads.yoctoproject.org/releases/opkg/opkg-$(opkg_VERSION).tar.gz
opkg_SHA256    := 440ef321862e01f83da4d02884a0cbb4d9d7b32f82faa81a6a85493f0c89d0f5
opkg_LICENSE   := GPL-2.0-or-later (COPYING)
opkg_CMAKE     := 1
opkg_DEPS      := ixcompat zlib bzip2 xz libarchive
opkg_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DWITH_BZIP2=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF \
	-DSTATIC_LIBOPKG=ON -DWITH_LIBOPKG_API=OFF
opkg_LIBS      := -llzma -lbz2 -lz
opkg_BINS      := bin/opkg
opkg_STACK     := 131072
opkg_HOST_DEPS := xz libarchive
opkg_HOST_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF -DWITH_LIBOPKG_API=OFF \
	-DCMAKE_PREFIX_PATH="$(HOSTB)/libarchive/inst;$(HOSTB)/xz/inst" \
	"-DCMAKE_C_FLAGS=-I$(HOSTB)/libarchive/inst/include -I$(HOSTB)/xz/inst/include" \
	-DSTATIC_LIBOPKG=ON "-DCMAKE_EXE_LINKER_FLAGS=-lz -lbz2 -liconv $(HOSTB)/xz/inst/lib/liblzma.a"
