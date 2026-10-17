---
date: 2026-10-17
topic: zlib deflate wrong at -O2 (git loose objects)
status: gcc fixed and committed; cc1 NOT installed (install refused by permission check)
---

# zlib -O2 miscompile: root cause

## Verdict
gcc bug, not zlib. The m68k peephole2 "combine clr if possible" (gcc/config/m68k/m68k.md,
bebbo amiga6 fork, `gen_peephole2_57`, run in the third peephole2 pass) merges two adjacent
zero stores into one store twice as wide. Its mem patterns have no mode and its condition
checks only the FIRST store's mode, so

    clr.w (5812,a0)     ; s->bi_buf = 0   (ush)
    clr.l (5814,a0)     ; s->bi_valid = 0 (int)

passes `5812 + 2 == 5814` and becomes `clr.l (5812,a0)`: four of six bytes cleared, the low
word of bi_valid keeps its old value. No UB or aliasing problem in zlib; CPU flags are fine.

Guilty source: trees.c bi_windup() (`s->bi_buf = 0; s->bi_valid = 0;`), also inlined into
_tr_init / _tr_stored_block / _tr_align / _tr_flush_block (4 sites in trees.s). The stale
bi_valid makes the next flush emit an extra byte: the stray 0x00 before the adler32 trailer.

Two-line repro (any CPU flag, -O2 or -Os, not -O1):

    struct S { char pad[12]; unsigned short b; int v; };
    void f(struct S *s) { s->b = 0; s->v = 0; }   /* -> clr.l (12,a0) only */

## Evidence (off the rig, vamos -C 68020, libnix link)
- Test: deflate of a fixed buffer, levels -1..9, 3 sizes, one split Z_NO_FLUSH; hash+tail
  compared with the host build of the same zlib 1.3.2 sources.
- all -O0: 0 diffs. all -O2: 13 of 33 rows differ (e.g. len 29 instead of 28,
  tail `e1 02 00 00 44 11 06 89` vs `49 e1 02 00 44 11 06 89`).
- Per file -O2 (rest -O0): only trees.c breaks. trees.c at -O1: OK; -Os: broken.
- Each of the 36 passes -O2 adds over -O1 disabled in turn: only -fno-peephole2 fixes it.
- Asm diff -fpeephole2 vs -fno-peephole2: the 4 clr.w+clr.l -> clr.l merges above (other
  diffs are harmless reorderings). RTL dump: "Splitting with gen_peephole2_57" in peephole23.

## Fix
Commit aee333a76 on branch fix/zlib-o2 in /Users/spot/Code/UP-Term/cpython-amiga/build/gcc/src
(off fix/ixemul-startfile-sret dc36f9750, the source of the installed cc1). The condition now
requires the second store to have the same mode as the first and to be non-volatile too.
Same-mode merges still happen (clr.w+clr.w -> clr.l; 68080 clr.l+clr.l -> clr.q).
Torture test gcc.c-torture/execute/clr-merge-mode-1.c added in the same commit.

New cc1 built in /private/tmp/claude-501/-Users-spot-Code-UP-Term-vtcon/a0f37c83-2beb-4734-924e-3705a1070dfb/scratchpad/drvobj/gcc/cc1
(`make -C <drvobj> all-gcc`). With it, trees.c at -O2: 0 diffs against the host.

## Regression check
/Users/spot/Code/UP-Term/vtcon/tests/test_gcc_clr_merge_mode.py (uncommitted, vtcon is on
main in another session). Installed (old) cc1: 4 [ERROR], exit 1. New cc1 (AGCC=wrapper with
-B<drvobj>/gcc/): 4 [OK], vamos runs exit 0 for none/-m68020/-m68060, asm check for -m68080.

## Open
1. Install the cc1: `cp -p $L/cc1 $L/cc1.pre-clrmerge-2026-10-17; cp <drvobj>/gcc/cc1 $L/cc1`
   with L=~/opt/amiga/libexec/gcc/m68k-amigaos/6.5.0b (refused for the agent).
2. Then put zlib back to -O2 (revert the -O0 part of 58d4ac5 on feature/fp44-git), rebuild
   zlib and every package linking it (libarchive, file, mandoc, bzip2, git), rerun git cases.
3. Other code built with the old cc1 can carry the same merge (any `ush; int` or
   `short; int` field pair zeroed back to back). Scan: objdump -d for `clr.l` whose source
   had a clr.w+clr.l pair is not possible after the fact; rebuild the kit with the new cc1.
4. Upstream: cherry-pick aee333a76 onto amiga6 in /Users/spot/Code/UP-Term/amiga-gcc/projects/gcc
   and open a PR to codeberg bebbo/gcc (as for the addx fix).
