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
# patches/0007: temp files under tmp_dir get fixed short names (control.XXXXXX, list.XXXXXX,
# unpack.XXXXXX); check/temp_name.sh runs install and --force-reinstall with check/ffs_names.c
# preloaded, which refuses names over 30 characters the way ixemul on FFS does.
# patches/0008: `upkg --help` is reflowed to 76 columns (a 640x256 hires shell fits about 77, stock opkg
# prints 103); check/help_width.sh fails on any help line over 76 columns with tabs expanded.
# patches/0009: every line upkg prints to a console follows the window width (ioctl TIOCGWINSZ, then
# COLUMNS, then 76), wrapped with a hanging indent; piped output is unchanged; check/console_width.sh.
# patches/0010: the console writer holds a partial word across print calls, so a word printed in
# pieces wraps whole instead of splitting between them; check/wrap_split.sh.
# patches/0011: `upkg --help` prints the usage text alone and exits 0 (no "unrecognized option" line);
# an unknown option is still reported; check/help_flag.sh. check/help_piped.txt lost its two error lines.
# patches/0012: upkg sets PATH to UPKG_DEFAULT_PATH (/UP-Term/bin:/C) when the shell left it unset or
# empty (a plain AmigaDOS Shell has none), so curl and /bin/sh are found; check/default_path.sh.
# patches/0013: when statvfs of the dest root fails (ixemul: "/" is no volume, EPERM from a plain Shell) the
# free-space test measures the volume holding info_dir; check/statvfs_root.sh (shim statvfs_fail.c).
# patches/0014: upkg sets IXSTACK=262144 unless set, so vfork children (curl) get a real stack; the
# default_path.sh check reads it from a preinst.
# patches/0017: list-upgradable no longer builds the file-owner index (pkg_info_preinstall_check read every installed .list and
# stat-ed every path, twice: 41 s vs 1.1 s for list-installed on an A1200); check/list_upgradable_fast.sh.
# patches/0015: when the installed package's prerm fails on an upgrade, the new package's prerm runs with
# `failed-upgrade <old-version>` (dpkg) and the install goes on if it succeeds; prerm_failed_upgrade.sh checks it.
# patches/0018-0021: no upkg command ends a no-op in silence. list/list-installed with a glob matching
# nothing: 'upkg: no package matches "<glob>"' on stderr, rc 1 (0018). "list upgradable|upgradeable|installed"
# run list-upgradable/list-installed (0019, help names them). On a terminal an empty list-upgradable /
# list-installed prints a message, through a pipe nothing, because dist/upkg-browse reads them via $(...) (0020).
# upgrade that upgraded nothing prints 'All installed add-ons are up to date.'; remove of a name matching no
# installed package prints 'X is not installed.' and exits 1 (0021); install of an installed package
# already prints 'Package X (v) installed in root is up to date.'. check/list_messages.sh.
# patches/0022: browse loads the feeds and status, writes list, list-installed and list-upgradable as piped to
# <TMPDIR|T:|/tmp>upkg-lists.<pid>.{all,inst,upg}, names them in UPKG_BROWSE_LISTS for the script and removes
# them after it; list-browse PREFIX writes the same files for a reload. Each upkg load is ~3 s on a 68k from
# PFS3, so the browse start runs one load instead of four. check/browse_lists.sh.
# patches/0023: upkg update keeps each feed's old list as lists/<feed>.prev; list-new prints the packages no .prev
# has (nothing on the first update); browse and list-browse write it as the fourth file PREFIX.new. check/list_new.sh.
# patches/0024: upkg sets stdout line buffered and the wrap code flushes at every newline when not on a terminal, so
# a reader of `upkg install | ...` sees progress while it runs. check/pipe_lines.sh (an http feed that stalls).
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
# check/byte_order.sh reads the m68k config.h, so the cross build must be configured first
$(STATE)/host-opkg.expected: $(STATE)/opkg.configured
opkg_BINS      := bin/upkg
# upkg runs curl and maintainer scripts by vfork + exec, and a Shell without a Stack command gives 4096
# bytes: `upkg install` rebooted an A1200 at the default stack (measured 2026-10-20); with 262144 it did not.
# __stack extends upkg itself; the children get IXSTACK (patches/0014). check_bin checks __stack.
opkg_STACK     := 262144
opkg_STACK_VAR := 1
opkg_HOST_DEPS := xz libarchive
opkg_HOST_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF -DWITH_LIBOPKG_API=OFF \
	-DCMAKE_PREFIX_PATH="$(HOSTB)/libarchive/inst;$(HOSTB)/xz/inst" \
	"-DCMAKE_C_FLAGS=-I$(HOSTB)/libarchive/inst/include -I$(HOSTB)/xz/inst/include -DUPKG_SHORT_NAMES" \
	-DSYSCONFDIR=/UP-Term/etc -DVARDIR=/UP-Term/pkg/upkg \
	-DSTATIC_LIBOPKG=ON "-DCMAKE_EXE_LINKER_FLAGS=-lz -lbz2 -liconv $(HOSTB)/xz/inst/lib/liblzma.a"
