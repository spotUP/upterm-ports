# SQLite 3.54.1 (amalgamation, autosetup configure): the sqlite3 shell and libsqlite3.a.
# Locking: ixemul compiles fcntl F_SETLK out (EINVAL, ixemul-vtcon compat/lockf.c), and
# SQLite's default "unix" VFS takes its locks with fcntl, so every database open would fail
# with "disk I/O error". flock works in ixemul, so patches/0001 makes the default VFS the
# flock one ("unix-flock", compiled in by SQLITE_ENABLE_LOCKING_STYLE=1): whole-file shared
# and exclusive locks, which is all SQLite needs from a lock (one writer, many readers).
# No threads (ixemul has no pthreads): --disable-threadsafe, one connection per thread
# is moot. No readline (the vsh line editor is the kit's; the shell reads plain lines),
# no loadable extensions (no dlopen). The library and header stay in the sysroot for
# later packages; only the shell and its page are shipped.
# --disable-math: trunc, acosh, asinh, atanh are not in the kit libm/libixcompat (ixemul-vtcon
# compat/libm.c has the source; the sysroot build lacks them), so SQL math functions are off.
sqlite_VERSION   := 3.54.1
sqlite_URL       := https://www.sqlite.org/2026/sqlite-autoconf-3540100.tar.gz
sqlite_SHA256    := 926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e
sqlite_LICENSE   := Public domain
sqlite_LICENSE_FILES := sqlite3.h
sqlite_DEPS      := ixcompat zlib
sqlite_COMMON_CONFIGURE := --disable-shared --enable-static --disable-threadsafe --disable-readline \
	--disable-load-extension --disable-math --fts5 --rtree
sqlite_CONFIGURE := $(sqlite_COMMON_CONFIGURE)
sqlite_HOST_CONFIGURE := $(sqlite_COMMON_CONFIGURE)
sqlite_ENV       := CFLAGS="$(CPU) -O2 -DSQLITE_ENABLE_LOCKING_STYLE=1"
sqlite_BINS      := bin/sqlite3
# the SQL parser and the b-tree code recurse
sqlite_STACK     := 262144
sqlite_STACK_VAR := 1
sqlite_CHECK_DEPS := sed
sqlite_FEED_ID   := up-sqlite3
sqlite_SUMMARY   := SQLite 3.54.1 command line shell (sqlite3) in UP-Term:bin
sqlite_FEED_MIN_BASE := 1.0
sqlite_HOST_BUILD_CMD = $(MAKE) -C $(sqlite_HOBJ) -j$(JOBS) install
