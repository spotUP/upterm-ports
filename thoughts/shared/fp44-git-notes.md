# FP4.4 part 4a: git 2.56.0 port notes (local commands)

Branch feature/fp44-git. Recipe pkgs/git/recipe.mk, patches 0001 (vfork + clean fork failures) and
0002 (NO_STATVFS), cases pkgs/git/check/cases. Source audit: vtcon thoughts/shared/research/2026-10-17_fp44-git-fork.md.

## Route
git's own Makefile, no configure; `git` only (builtins live in the one binary, 3.7 MB).
Variables: NO_PTHREADS NO_OPENSSL NO_CURL NO_EXPAT NO_GETTEXT NO_TCLTK NO_PERL NO_PYTHON NO_ICONV NO_RUST.
-DUSE_VFORK selects the patched paths:
- start_command: vfork() instead of fork(); parent restores signal dispositions and child_notifier
  after vfork returns; the child does not switch the die/error/warn routines.
- start_async (NO_PTHREADS branch): error "git: asynchronous processes ... not supported on AmigaOS"
  (fetch-pack/send-pack sideband demux, clean/smudge filters). daemonize() returns -1/ENOSYS
  (gc --auto then runs in the foreground). transport-helper copy loop dies with the same wording.
  No other fork() in the source (grep of *.c, builtin/, compat/), so `_fork` is not linked.

## Measured quirks (each from a build failure)
- uname probes: uname_S=AmigaOS etc. on the make command line (else Darwin settings on the Mac).
- 2.56 builds Rust (libgitcore) by default: NO_RUST=1.
- struct stat has no st_mtim: NO_NSEC=1. libc gaps with git compat code: NO_MEMMEM, NO_STRCASESTR,
  NO_MKDTEMP, NO_PREAD. statvfs() missing (header present): patch 0002.
- zlib is not found by the link: EXTLIBS gets libz.a explicitly.
- RUNTIME_PREFIX=1 aborts at start (`exec-cmd.c: assertion executable_dirname`): not used.
- Host build (expected outputs) keeps iconv (macOS needs it for precompose_utf8).
- recipe.mk edits re-run the unpack and wipe uncommitted edits in build/src/git: commit, then `make git-patches`.

## Checks
Cases init, commit, log, status, diff, merge compare against the Mac build (fixed dates; user.name/email,
core.pager=cat, gc.auto=0 via -c). `clone`: the Mac clones fine and the Amiga build must fail, so the
case prints `clone: ok` for success or the "not supported on AmigaOS" message and nothing else
(a crash or other error prints nothing); the rig run's clone.err shows which one happened.

## Final state (rig 2: 7 of 7 pass)
- Patch 0003: csprng_bytes fallback (clock, pid, counter) under USE_VFORK. ixemul has no arc4random/getrandom/getentropy//dev/urandom. Proper fix: getentropy in libixcompat.
- RUNTIME_PREFIX removed (exec-cmd.c assertion on executable_dirname).
- NO_TRUSTABLE_FILEMODE=1: ixemul stat reports the exec bit on every file, so git recorded 100755.
- zlib recipe now builds with -O0: gcc -O2 miscompiles deflate on this toolchain (loose object had a stray 0x00 byte before the adler32 trailer, "inflate: data stream error"). -O0 gives byte-identical output to the Mac zlib. Root cause (which -O2 pass) not isolated; try -O1 or per-file flags.
- clone: a path like VTC:userland/work/git/r7 contains a colon, so git treats it as ssh host "VTC". Clone fails with "cannot run ssh ... fatal: unable to fork". The case accepts that or "not supported on AmigaOS".
- Open: templates not shipped (stderr warning); fetch/push/pull unsupported (start_async); binary 3.7 MB.
