# Port: sqlite3 3.54.1 (branch port/sqlite)

Status: amiga build green (68020 soft-float, __stack 262144, 1682976 bytes). Rig checks NOT run.

## Decisions
- Locking: ixemul compiles fcntl F_SETLK out (EINVAL; ixemul-vtcon compat/lockf.c). SQLite's default
  "unix" VFS uses fcntl locks, so every open would fail. flock() works. patches/0001 makes the
  flock VFS ("unix-flock", needs -DSQLITE_ENABLE_LOCKING_STYLE=1) the default on __amigaos__, and
  drops pread/pwrite table entries (ixemul has none), fstatfs and proxy locking.
- Threads off (no pthreads), readline off (kit has none), load-extension off (no dlopen).
- --disable-math: trunc, acosh, asinh, atanh failed to link. ixemul-vtcon compat/libm.c has the
  source (acosh at line 55) but the sysroot libixcompat/libm used here lacks them. Real fix: ship
  them in ixemul-vtcon, then drop --disable-math. SQL math functions are OFF until then.
- WAL not checked: it needs mmap'd shared memory, unlikely to work on ixemul. Use delete journal.
- License: public domain (sqlite3.h carries the blessing text).

## Unverified
- Feed rows: tools/pkg_rows.py (vtcon) not found; _FEED_ID/_SUMMARY/_FEED_MIN_BASE copied from the vim/git pattern.
- Everything on 68k: flock VFS at run time, check/cases.

## Rig steps (owning session)
1. rig.py start --max --purpose "<session>: check sqlite"; make wasabi.
2. Install the package; run each line of pkgs/sqlite/check/cases on the Amiga.
3. Lock test: open one db file from two shells, write in one while the other holds a read
   transaction; expect "database is locked", not "disk I/O error".
4. PRAGMA journal_mode=wal: expect failure or fallback; record result.

## Rig check (2026-10-26, rig 8, 060 --max, vtcon origin/main a0087f2d)
- Reset count: 1 (one cold boot, no reset loop).
- userland_rig.py --only sqlite: stopped at case 2. version: output differs from the host only in "(32-bit)" vs "(64-bit)" (expected: build width; the case needs a normaliser or a host-independent command, e.g. "sqlite3 -version | cut -d' ' -f1-3"). select (`sqlite3 :memory: "select 1+1;"`): HANGS, never prints, ignores Ctrl-C. Same for any command that opens a database (-batch, /ram/x.db, .databases). Cases 3-9 not run. Two-shell test not run.
- Cause (unverified, measured symptoms only): the process is runnable (state "ready", stack 262144, ~6k used), and `wasabi snoop --entry` shows it calling FindTask(NULL) in a tight loop with no other DOS call. -version (no database open) works. Not fixed: needs a disassembly or ixemul-side look (spin in ixemul after sqlite3_initialize / first open), beyond a recipe or patch fault.
- Note: a hung sqlite3 started via EXEC occupies a run slot and ignores Ctrl-C; `wasabi free N` stops it.
