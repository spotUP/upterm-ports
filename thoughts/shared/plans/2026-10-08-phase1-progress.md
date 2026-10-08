---
date: 2026-10-08
topic: Unix tool ports, phase 1 items 1.2 onward, progress ledger
tags: [plan, progress, ports, sed, awk, less, nano, findutils, diffutils, patch, mandoc, kit, ixemul, gcc]
status: draft
---

# Phase 1 progress (from 1.2)

Plan: vtcon `thoughts/shared/plans/2026-10-04-unix-tool-ports.md` (checklist 53 items, 12 ticked
at the start of this run, still 12: no item reaches the caller's definition of done before the
kit installs it). Rig: rig 3 only (`UPTERM_RIG=3`, build/rig3, port 7848, `--max`); its
`VTC:ixp6/ixemul.library` is ixemul-vtcon build295 of b4630aa (rig 1's 08:36 copy kept as
`build/rig3/ixemul.library.0836`).

Done per tool (caller): in the kit's `UP-Term:bin`, reached through vsh's `$PATH`, rig check
passes, man page, licence met. The kit step is 1.10; tools are ticked when it lands.

## Items

| ID | State | Evidence |
|---|---|---|
| 1.2 sed 4.10 | rig 17/17, staged | ports 611d360 (patch 0001: -i on VOL:name) |
| 1.3 awk 20260426 | rig 17/17, staged | ports d0a6da1, 697c3ed; ixemul 03d9a2f atan2, fcc2c7b system(), 511c224 execve quoting; the other agent's 74c77ac (ReadItem parsing) fixed the vsh->ixemul quotes |
| 1.4 less 710 | rig 7/7 (3 terminal cases), staged | ports 8691fa6; ixemul 14a4b3b tsearch, ebbdc56 /dev/tty = controlling tty |
| 1.5 nano 9.2 | rig 3/3 (type+save, edit; bytes equal), staged with syntax files + etc/nanorc | ports d4d4198; ixemul 9e810a4 |
| 1.6 findutils 4.11 | rig 8/9; -type d: gcc miscompile; KIT_HOLD | ports cf5119e; gcc fix cpython-amiga 7eeb010 (amiga/gcc/0004) not installed |
| 1.7 diffutils 3.12 | rig 14/14, staged | ports 2d53f1a |
| 1.8 patch 2.8 | rig 6/6, staged | ports 2d53f1a; ixemul e5d22d5 |
| 1.9 mandoc 1.14.6 + pages | rig 8/8 (man pages through less), own pages vsh UPTerm upgetty sz | ports bcb06b5; ixemul 54bf915, b8f7643, b4630aa; vtcon 5aa2069 |
| 2.1 gzip 1.15 (+ zlib 1.3.2) | rig 9/9, staged | ports afddeaf (patch: gunzip/zcat by name) |
| 2.2 bzip2 1.0.8 | rig 6/6, staged | ports afddeaf |
| 2.3 xz 5.8.4 | rig 8/8, staged | ports afddeaf |
| 2.4 libarchive 3.8.9 (tar, cpio, bsdunzip, bsdcat) | rig 11/11, staged | ports afddeaf; ixemul 6279020 fstatfs, 610cf88, 3804757 ... |
| 2.5 zip 3.0 | rig 6/6, staged | ports 8d13faf |
| 1.10 kit | ports side done (kit-stage 76c4f8b); vtcon side held back | `thoughts/shared/handoffs/2026-10-08_vtcon-kit-userland.patch` |

## Next steps (ordered)

1. When `git status` in vtcon shows `Makefile` and `dist/Install.installer` clean (at
   19:45 Install.installer was clean but another agent had Makefile open): apply the handoff patch with
   these changes: the install.dos lines become their own part `copy-userland` (the Installer
   copies copy-parts itself, one drawer copy each: tests/test_dist_installer.py), e.g. a staged
   layout `userland/` copied as one drawer, plus the `(set #from ...)`/`(P_COPY)` entry and its
   `#kb-` size in Install.installer; also copy vtcon `man/*.1` into
   `Files/userland/share/man/man1` (sz.1 again as rz.1). Then `make dist`, install_rig (the
   grep reachability check), tick 1.2-1.5, 1.7-1.10.
2. Owner installs cpython-amiga's build/gcc/bin/cc1 (gcc patches 0001-0004) into ~/opt/amiga;
   then here: `rm -rf build/obj build/sysroot build/state/*.{configured,built,installed,checked}`,
   rebuild every package, rerun all rig cases, drop `findutils_KIT_HOLD`, tick 1.6.
3. Phase 3 (file, tree, ps/top, watch, script, ncdu, coreutils 9, fzy).

## Decisions (not to re-litigate)

- Versions: sed 4.10, onetrue-awk 20260426 (github.com/onetrueawk/awk), less 710, nano 9.2,
  findutils 4.11.0, diffutils 3.12, patch 2.8, mandoc 1.14.6, zlib 1.3.2.
- PREFIX is `/UP-Term` (the kit's assign; the user picks the drawer), sysroot
  `build/sysroot/UP-Term`.
- Terminal cases: `check/tty` + `check/keys/<name>`, run under `tools/ptyrun.c` (Mac and Amiga),
  compared screen by screen through vtcon's engine (userland_rig). Screen programs' Mac builds
  link the Mac build of ncurses 6.6 (`<p>_HOST_DEPS`).
- `<p>_CHECK_DEPS` stages other packages for a package's checks (mandoc -> less).
- Kit: pages under `UP-Term:share/man` (mandoc's default MANPATH; no vshrc MANPATH), licences
  under `UP-Term:licenses/<pkg>`, source in `UP-Term-src.lha` (D2). man and mandoc are two copies
  of one program (no links on AmigaOS).
- ncurses 6 reads hex terminfo dirs (76/vtcon); the kit must install both layouts (the patch).
- In-place sed cases run in RAM:; the rig runner deletes staged drawers from the Amiga side
  (FS-UAE caches names the Mac deleted) and assigns TMP: as install.dos does.

## Gotchas found (each fixed where it lives)

- ixemul: system() exec'd "sh" without path; execve quoted native args with backslashes;
  /dev/tty was "*" even on a pty; getgroups(0) failed; usleep was void; glob returned 0 on no
  match; missing atan2, tsearch, strnlen, strtok_r, bswap*, putwchar, nanosleep, getpgid,
  RLIMIT_NOFILE, MAP_FAILED, utime.h's time_t.
- gcc: bbb opt_strcpy deleted a load an earlier store read (find's directory modes).
- vsh: a drawer named like a command in the current directory is entered (implicit CD) before
  $PATH is searched: `man` in a directory holding a drawer `man` ran CD.
- check_bin: the $STACK cookie may follow printable bytes; m68k_scan: moveq-bounded switch tables.
- install_rig PYTHON check fails since ixemul 74c77ac: `"print(6*7)"` is `print(67)` under
  ReadItem's `*` escapes (not this work's change).
