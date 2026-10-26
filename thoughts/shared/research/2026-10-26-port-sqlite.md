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

## Hang root cause (2026-10-26, rig 8, measured)
- Not ixemul, not the port patch: a miscompile by bebbo's m68k-amigaos-gcc 6.5.0b (20260819) back-end
  optimizer "bbb" (on by default at -O2) in sqlite3WhereBegin, sqlite3.c line 177022:
  `Bitmask b = pTabItem->colUsed; int n = 0; for(; b; b=b>>1, n++){}` (Bitmask = u64).
- Evidence: 8 samples of the hung task's saved PC (taskpeek: tc_SPReg frame) all fall in
  0x108451e2..0x108451f2 = segment 0 offset 0xe6caa..0xe6cba; link map (-Wl,-Map, binary identical) puts
  sqlite3.c .text at 0x56ab0, and nm of the save-temps object places that offset in _sqlite3WhereBegin. Code:
      move.l a0,d1 / move.l a1,d2        ; b copied from a0:a1 into d1:d2 once, before the loop
  L:  lsr.l #1,d1 / roxr.l #1,d2 / addq.l #1,d0
      cmp.w #0,a0 / jne L / cmp.w #0,a1 / jne L   ; tests the unchanged a0:a1 -> never ends
      move.l d1,a0 / move.l d2,a1        ; copy-back hoisted after the loop
  The same sqlite3.i compiled with -fbbb=- keeps the copy-back inside the loop (correct); with
  -fno-peephole2 the pattern is also gone. A small standalone test of the same loop compiles correctly:
  the bug needs b allocated to address registers under register pressure.
- No call in the loop: it is a pure CPU spin, so Ctrl-C (checked by ixemul on library calls) never lands.
  The FindTask(NULL) lines in `snoop --entry` are not from this loop (unexplained, unverified source).
- Reached by any statement that opens a table cursor (the shell's first statement reads sqlite_schema);
  -version opens nothing, so it works.
- Fix layer: the compiler (bbb pass in bebbo gcc). Interim for this port: build with -fbbb=- (whole
  amalgamation, since other u64 loops may hit the same pattern); then rerun the rig cases. Other ports
  built with -O2 can carry the same miscompile wherever a u64 lives in a0/a1.

## Rig check after the cc1 fix (2026-10-26, rig 8, 060 --max, vtcon origin/main 48006aec, gcc 1e025c364)
- Rebuild: make clean-sqlite && make sqlite; sqlite3.o 16:00:17 is newer than cc1 (15:57:43). make clean-sqlite also removes
  build/expected/sqlite: run make host-sqlite again before userland_rig.py.
- Hang FIXED: userland_rig.py --only sqlite: version, select, file, table, dump, error PASS (6 of 9).
- persist, journal, fts5 FAIL (the two-shell test NOT run, it needs a working file database). Every one that writes a database FILE:
  `sqlite3 RAM:y.db "create table t(a);"` -> "file is not a database"; y.db ends up 24 bytes (a full first page is 4096).
  persist.err: "file is not a database"; journal: same; fts5 (:memory:): "fts5: missing row 0 from content table 'main'.'f_content'".
- Ruled out: plain ixemul open/lseek/write/lseek/write of 4096-byte blocks on RAM: works (test program, same sysroot and flags).
- Not yet known: whether it is a second bbb miscompile (an -fbbb=- sqlite3 binary was not obtained: the manual compile command
  needed sqlite_cfg.h defines and stopped at dlfcn.h) or the flock VFS / patch 0001. Next step: build the whole amalgamation with
  -fbbb=- (recipe CFLAGS) and rerun; if the same, trace the write path (snoop the Write calls of the failing create).

## Write failure (2026-10-26, rig 8, 060 --max, vtcon origin/main 48006aec, measured)
- Two causes. (1) fts5 "missing row 0": a second bbb miscompile. Same source, `-O2 -fbbb=-` in sqlite_ENV CFLAGS: fts5 PASS (7 of 9),
  and `-O0` fts5 PASS too. Compiler bug, to bisect (Opus). Not committed: recipe keeps -O2 until the compiler is fixed.
- (2) persist/journal "file is not a database", y.db = 24 bytes of zeros: NOT the compiler (same failure at -O0 and at -O2 -fbbb=-),
  NOT the flock VFS or patch 0001 (same with -vfs unix-none, unix-flock, unix-dotfile; fails before any lock matters).
- Evidence: a test program (shim VFS over "unix" logging every xRead/xWrite/xTruncate/xFileSize, linked to the port's libsqlite3.a) shows
  the pager never calls xWrite. Sequence: xFileSize=0, then xRead(n=16, off=24) (the dbFileVers read of sqlite3PagerSharedLock) returns
  short, then xFileSize=24 -> sqlite sees a non-empty file with no valid header -> SQLITE_NOTADB (rc 26).
- Cause: ixemul lseek() (ixemul-vtcon library/lseek.c, ~line 205-232): seeking past EOF on a file opened FWRITE extends it at once
  (__extend_file writes zeros up to the new position). POSIX: lseek past EOF changes nothing; the file grows only on a write.
  Plain C test (open O_RDWR|O_CREAT on a new file, lseek(fd,24,SEEK_SET), read): lseek returns 24 and fstat/ls show size 24; read returns 0.
  An earlier "lseek+write works" test never read past EOF, so it missed this.
- Layer to fix: ixemul (lseek.c). Defer the extension: remember the position past EOF and extend in the next write()/ftruncate (or
  make the extension happen only when a write follows). No port patch is right: any program that reads beyond EOF of a writable file
  (SQLite does for every new database) is hit. After the fix: rerun userland_rig.py --only sqlite (expect 9 of 9; the two-shell lock test still unrun).

## Write failure: fix (2026-10-26, vtcon-05 session 6)
ixemul-vtcon branch fix/lseek-no-extend (38eeb96, pushed to spotUP/ixemul-vtcon): lseek() past EOF only records the
offset (f_seek_pending); read there returns 0, fstat keeps the real size, write() extends with zeros first.
Library md5 5e2453b8252cb5253bc4aef3beb835bd (FPU build, /Users/spot/Code/UP-Term/ixemul-lseek/build295/library/68020/68881/amigaos/ixemul.library, 201048 bytes).
Rig 8, old lib f8c21ce31fc769b9006f6e9bfeb478ea: lseekprobe size0 FAIL. New lib: lseekprobe 7 of 7 OK.
userland_rig.py --only sqlite on the new lib: 9 of 9 PASS (persist, journal and fts5 included). Two-shell lock test still unrun.

## Correction: the "9 of 9" above ran a stale binary (2026-10-26 evening)
build/obj/sqlite/sqlite3 was from 16:28, before recipe.mk went back to -O2. A fresh -O2 build gave 8 of 9: fts5 still
failed ("missing row 0"). Cause: a second bbb bug, opt_elim_dead_assign2 (e0) in gcc/bbb-opts.c. It deleted
`moveq #32,dN` in front of `or.b #1,dN` in sqlite3CompleteInsertion (insert flags 1, not 33), and the same way the
`moveq #0,d0` in front of `addq.w #1,d0` in adjustOrderByCol. Fix: the rule now keeps the load when the next insn
reads the register. gcc branch fix/m68k-bbb-di-loop ab34f2880 + test 9691feda3; codeberg PR branch
spotup/m68k-bbb-e0-partial-or. The fixed cc1 is installed in ~/opt/amiga (md5 133426f7..., old one kept as
cc1.pre-e0-2026-10-26).

Rig 8, ixemul md5 849ade2bcba308624f0c2125dd7d96cb, fts5 SQL three times per binary:
- installed old cc1, one-shot link (68000 code): output empty, rc 1 (bug).
- fixed cc1, one-shot link (68000 code): "hello world", rc 0. This is the shipped sysroot binary, md5 2d8c31b0.
- old cc1 -m68020 and fixed cc1 -m68020: both "hello world", rc 0 (at 68020 the old cc1 happens to keep the moveq).
userland_rig.py --only sqlite with 2d8c31b0: 9 of 9 PASS. Two-shell lock test PASS: while shell A holds a write
transaction, shell B gets "database is locked (5)" rc 1; after A commits, B succeeds and the table holds rows 1 and 2.

Open: the sqlite3 shell is built in one compile-and-link call, and tools/m68k-cc drops -m68020 on every link call, so
shell.c and sqlite3.c are compiled as 68000 code (libsqlite3.a is 68020). Wrapper fix tracked separately.
