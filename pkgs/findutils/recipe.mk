# GNU findutils (vtcon plan 1.6): find and xargs. -exec, -execdir, -ok and
# xargs start their commands with posix_spawn (libixcompat over vfork), not
# fork. locate/updatedb are built but not shipped (they need cron and a DB).
findutils_VERSION   := 4.11.0
findutils_URL       := https://ftp.gnu.org/gnu/findutils/findutils-$(findutils_VERSION).tar.xz
findutils_SHA256    := bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd
findutils_LICENSE   := GPL-3.0-or-later
findutils_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed:
# --disable-year2038, as configure itself suggests
findutils_CONFIGURE := --disable-nls --disable-threads --without-selinux --disable-year2038
findutils_HOST_CONFIGURE := --disable-nls
findutils_BINS      := bin/find bin/xargs
# provisional, grep's value: find recurses with the tree (fts)
findutils_STACK     := 262144
# out of the kit until ~/opt/amiga has a cc1 with cpython-amiga 7eeb010's
# amiga/gcc/0004: the installed one miscompiles find (-type d matches nothing)
findutils_KIT_HOLD := find miscompiled by the installed cc1 (bbb opt_strcpy, gcc patch 0004)
