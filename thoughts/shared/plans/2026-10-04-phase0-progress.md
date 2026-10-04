---
date: 2026-10-04
topic: Unix tool ports, phase 0 (items 0.1-0.4, 0.8) and the first tool (1.1 grep), progress ledger
tags: [plan, progress, ports, ixemul, libixcompat, ncurses, grep, posix_spawn, wchar]
status: draft
---

# Phase 0 progress

Plan: vtcon `thoughts/shared/plans/2026-10-04-unix-tool-ports.md` (owner answers D1-D5:
current upstream, separate source archive, grow vsh, am-git optional, Neovim optional).
This ledger covers the items this session was given: 0.1, 0.2, 0.3, 0.4, 0.8 and 1.1.
Not in scope here: 0.5 (rig runner), 0.6 (vsh builtins), 0.7 (ixnet in the kit).

Repos: `~/Code/upterm-ports` (main, no remote), `~/Code/ixemul-vtcon` branches
`feature/posix-spawn` (0f62d3e) and `feature/wide-chars` (stacked on it), not pushed.
The ixcompat recipe builds whatever ixemul-vtcon has checked out (feature/wide-chars).

## Checklist (6 items: 6 built and host-checked, 0 rig-checked)

- [x] **0.1 ports repo**: top Makefile, `pkgs/<pkg>/recipe.mk`, sha256-verified downloads
      into `build/dl`, sources as git trees in `build/src/<pkg>` (patches via git am),
      stamps `build/state/<pkg>.{fetched,unpacked,configured,built,installed,checked}`,
      `host-<pkg>` + expected outputs, `kit-stage` with SOURCES.txt. Commits 460e48c, the
      kit-stage fix after c9d3925.
      Open: `make sysroot` builds libixcompat and ncurses; zlib arrives with item 2.1.
- [x] **0.2 posix_spawn** (ixemul-vtcon 0f62d3e, feature/posix-spawn). Rig: spawnprobe
      **not run** (step R1 below).
- [x] **0.3 wide chars + POSIX calls** (ixemul-vtcon feature/wide-chars: 672d4f7 headers,
      aea8ab7 __eprintf, 2e152be wide layer, a8d7bdb more headers). Measured on grep 3.12
      and ncurses 6.6. Host tests: `make -C compat test` (codec, all 1,114,112 code points
      against unicodedata 16.0.0, wcwidth). Rig: through grep's UTF-8 cases (R2).
      Not added, because no tool has failed on them yet: clock_gettime, getaddrinfo
      (neovim-amiga's netdb.c is the one to move when a tool needs it).
- [x] **0.4 check_bin** (d8818b2): `tools/check_bin.sh` + `tools/m68k_scan.py` (flow-following,
      so tables in the code hunk do not count). Negative tests: FPU, fork, pflusha/move16
      and a wrong $STACK all fail (scratch binaries, 2026-10-04).
- [x] **0.8 ncurses 6.6 wide** (c9d3925): libncursesw/panelw/menuw/formw in the sysroot; tput tset
      reset clear infocmp tic toe tabs pass check_bin. Rig: R3.
- [x] **1.1 grep 3.12** (01c7372): m68k build passes check_bin (224,248 bytes); `make host-grep`
      writes 17 expected outputs. Rig: R2.

## Decisions (not to re-litigate)

- Versions: grep 3.12 (current GNU), ncurses 6.6 (current). GPG signatures not checked
  (keys not in the keyring); the sha256 in each recipe is from an https download.
- Link libixcompat by path: `-mcrt=ixemul` puts the SDK's `-L` before ours (map-proven).
- The CPU flag goes only to compiles (`tools/m68k-cc`): a link with -m68020 picks libnix's crt0.
- Wide layer: UTF-8 by the LC_CTYPE name's codeset, else ISO 8859-1; wcwidth = vtcon's
  `engine/vtwidth.h` (include, no copy); classes from a table generated from the same
  Unicode version; rules = neovim-amiga's wctype.c.
- Newlib headers that leak from sys-include are fixed by giving ixemul the header
  (alloca.h, sys/select.h, wchar.h, wctype.h, spawn.h) when the host-side build also
  sees the config (ncurses); config.site answers otherwise (stdio_ext.h, getopt.h,
  inttypes.h, xlocale.h).
- $STACK for grep is a provisional 262144 until measured on the rig (R2).

## Gotchas

- ixemul's vfork child gets a copy of the stack: data the child hands back must be static.
- gnulib's cross guesses: `gl_cv_func_mbrtowc_C_locale_sans_EILSEQ=yes` stops it wrapping
  mbrtowc/mbrlen/btowc; ALTMON_* in langinfo.h stops it wrapping nl_langinfo.
- Installing ixemul-vtcon's new headers into the toolchain SDK without its new
  libixcompat.a breaks links (MB_CUR_MAX calls __ixc_mb_cur_max). Install both or neither.

## Sizes (build/state/sizes.tsv, bytes, unstripped hunk files)

grep 224,248; tput 110,688; tset/reset 111,596; clear 101,424; infocmp 216,332;
tic 239,432; toe 160,224; tabs 105,756. Staged with SOURCES.txt by `make kit-stage`.

## Rig steps for the session that owns the rig

- R1 spawnprobe: copy `~/Code/ixemul-vtcon/compat/test/spawnprobe` to VTC:, run
  `VTC:spawnprobe` in an UP-Term window (needs T:). PASS: every line [OK], exit 0.
- R2 grep: copy `build/sysroot/SYS/UP-Term/bin/grep` and `pkgs/grep/check/data/` to the rig,
  run each line of `pkgs/grep/check/cases` through vsh in that directory, compare stdout and
  exit status with `build/expected/grep/<case>.txt`. Also measure the stack (stackprobe
  approach) of `grep -E "(a|b)*c"` on a long line to replace the provisional $STACK.
- R3 ncurses: copy tput, reset, clear, infocmp to VTC: (kit terminfo installed):
  `tput cols` / `tput lines` equal the window size, `infocmp vtcon` prints the entry,
  `clear` clears, `reset` restores after garbage; `tput -V` equals the expected output.
