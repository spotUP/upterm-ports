---
date: 2026-10-26
topic: native C compiler on the Amiga as an upterm-ports package
status: research
---

# Native C compiler as an upterm-ports package

Owner steer: do not port gcc or vbcc, ship what exists. This document first asks for each candidate whether a ready-made native AmigaOS binary exists, and only then whether a build is needed. Nothing was downloaded, built or run; sizes and versions come from HTTP headers and the GitHub API. Claims about runtime behaviour on an Amiga are unverified.

## Findings in one paragraph

Ready-made native binaries exist for A (vbcc) and for a gcc 16 line (AmigaPorts release asset, which changes the picture for B and D). Recommended first package: vbcc, because it is small, needs no ixemul, and is exactly the toolchain vtcon builds with. The AmigaPorts gcc 16.2-rc19 m68k-amigaos .lha is the second package and needs a rig test before anything is promised.

## A. vbcc native binaries (recommended first)

- Ready-made: yes. Aminet dev/c/vbcc_bin_amigaos68k.lha, version 0.9h patch2, 2,512,493 bytes (Aminet readme: "Architecture: m68k-amigaos >= 2"). Also http://phoenix.owl.de/vbcc/current/vbcc_bin_amigaos68k.lha (Last-Modified 2022-03-23, same size) and vbcc_target_m68k-amigaos.lha at the same directory (705,685 bytes, 2022-05-22). Aminet has no vbcc_target_m68k-amigaos.lha (404). The www.compilers.de page names Frank Wille as compiler of the AmigaOS binaries; the old sun.hasenbraten.de release path returned 404.
- Contents per the readme: compiler, preprocessor, assembler (vasm), linker (vlink), vc frontend, message browser. The target archive carries libs, startup.o and headers. NDK is separate: vtcon already holds NDK3.2R4 Include_H (4.1 MB, vendor/ndk-3.2r4-Include_H).
- Build needed: none. Package is a repack and config.
- Needs ixemul: no. vbcc binaries are plain AmigaOS hunk programs; vtcon builds its own programs against vbcc's no-ixemul startup.
- Disk: about 3.2 MB archives, roughly 6 MB unpacked (the brew install on the Mac has targets/ at 5.6 MB), plus 4.1 MB NDK.
- RAM: readme says small programs translate in 1 MB, larger ones need much more (no figure). Fine for a 68060 rig; unverified on lower.
- License, decisive sentence (Aminet readme, lines 103-104): "This archive may be redistributed without modifications and used for non-commercial purposes." Line 106 adds an exception for commercial use of generated code under conditions. Consequence: UP-Term must ship the two lha unmodified, so the recipe must fetch the original archives and install them untouched (no repacking into a new archive with edited files); config files go in separate files. The same text says vc, vbcc and vsc are covered; vasm and vlink have their own terms (not checked). Redistribution from our own server needs the unmodified archive; fetching from the author's URL at install time avoids the question.
- What vtcon's Makefile needs (grep of Makefile, lines 502-517 and 556, 1001): `vc +cfg -I$(VTCON_NDK) -cpu= -O2 ...`, vbccm68k, vasmm68k_mot (-Fhunk), vlink (-bamigahunk), and the cfg template tools/vbcc-aos68k.cfg.in, whose paths use @VBCC_PREFIX@/targets/m68k-amigaos/{include,lib}. The Makefile is GNU make with brew, sed, mkdir, cmp, so building vtcon natively also needs gmake, sed, sh (vsh) from the kit; the cfg generation already is prefix-relative so only VBCC_PREFIX and VTCON_NDK change.
- Unlocks: vtcon and every vbcc-built program natively (vsh, amarchy tools). Does not unlock ixemul ports or autoconf configure scripts, because vbcc has no POSIX libc of the ixemul kind and ports expect gcc.
- Effort 1 agent-day (recipe, VBCC: assign, cfg, rig test building one vtcon program). Risk low.

## B. bebbo / AmigaPorts gcc running natively

- Ready-made: yes, one candidate. AmigaPorts/m68k-amigaos-gcc release v16.2-rc19 (published 2026-10-25) carries the asset m68k-amigaos-gcc-16.2-rc19-m68k-amigaos.lha, 119,757,545 bytes, next to arm64-darwin, x86_64-linux and MinGW installers. The README says cross builds are named by the HOST system the tools will run on, so this asset is a host=m68k-amigaos toolchain. It is gcc 16.2 (not 6.5). The README has no install, RAM or CPU requirement text for it (grepped README, doc/devel.md, doc/releng.md): unverified that it runs on a 68k machine, which CPU, how much RAM, whether it needs ixemul.library or is libnix-linked. Release notes list newlib, libnix and ixemul as target runtimes only.
- bebbo/amiga-gcc (local ~/Code/UP-Term/amiga-gcc README): "Native builds" there means native to a Mac (M1), not Amiga-hosted; no Amiga release assets found (GitHub releases query returned nothing). Building a canadian cross ourselves is the fallback and is a multi-day job with high risk.
- License: GPL; sources are the AmigaPorts repos.
- Disk: 120 MB archive; unpacked likely several hundred MB with multilibs (estimate, unverified). RAM: gcc 16 cc1 on 68k almost certainly needs well above 64 MB for real C files (estimate).
- Prerequisites: binutils are in the same toolchain; assigns and the fork/exec question are unknown. ixemul-vtcon has vfork only (research/2026-10-04_unix-tool-gaps.md), so a driver that uses fork would fail unless the binary uses its own spawn.
- Unlocks if it runs: ixemul-style ports (-mcrt=ixemul exists), C99 and later code, configure scripts, and vtcon too (vbcc not required if the Makefile gets a gcc path, which it lacks).
- Effort: package 1 agent-day if the lha runs as shipped; plus 1 day rig probe. Risk medium-high until probed.

## C. GG-Lite gcc 2.95.3 from Aminet

- Ready-made: yes (Aminet, Geek Gadgets). Ledger rows 236 and 256: owner approved the download; on rig 2 it ran the less 710 configure under vsh, exit 0, needed `assign ADD GG: GG:emul-include` and CONFIG_SHELL=VTC:vsh (vsh does not resolve /bin/sh). Uses ixemul. I did not fetch exact Aminet filename, version date or size; look up before packaging.
- License GPL, source on Aminet. C89 and partial C99 only, so it cannot build modern sources. Proven to run on our ixemul (build295). Effort 1 day, risk low, value as a stopgap for old autoconf checks only.

## D. gcc 16 built by us for native use

Superseded by B: AmigaPorts already publishes a gcc 16.2 Amiga-hosted asset. A self-built native gcc 16 would only be needed if that asset does not run; expected infeasible on 68k RAM otherwise.

## Recommendation and package shape

First: vbcc (A). Second: probe the AmigaPorts lha on a rig (one agent, one question: does it start, CPU and RAM, ixemul dependence, compiles hello.c) before deciding whether to package it.

Recipe shape for vbcc (binary-only, no configure): pkgs/vbcc/recipe.mk marks the package as a prebuilt payload (existing recipes all build from source via common.mk fetch.sh, unpack.sh and the configure/build/install hooks, so a prebuilt-lha mode needs a small new hook or an _OWN style install that lhas the two archives into the sysroot). Files installed: vbcc_bin_amigaos68k contents (vbccm68k, vc, vasmm68k_mot, vlink, vprof tools, config/ dir) under VBCC:, vbcc_target_m68k-amigaos contents under VBCC:targets/m68k-amigaos (include, lib, startup.o), NDK Include_H under VBCC:NDK (separate package or part of this one). Assigns in the user startup: `Assign VBCC: <dir>`, `Assign ADD`-free; `Path VBCC:bin ADD`. vc finds its configuration through the VBCC environment variable (ENV:VBCC, falling back to VBCC: config/aos68k); upstream's stock config is VBCC:config/aos68k. For vtcon we pass `+<cfg>` as the Makefile does, generated from tools/vbcc-aos68k.cfg.in with VBCC_PREFIX=VBCC: (the cfg uses -I paths with a colon prefix; vlink and vc accept Amiga paths). Verify that the VBCC environment lookup and the colon-path cfg work on a rig before ticking. The license requires unmodified archives, so keep our cfg as a separate file.

## Open items

1. Rig probe of the AmigaPorts m68k-amigaos .lha (unverified in every respect).
2. vasm and vlink license terms (not read).
3. Exact GG-Lite Aminet filename and size.
4. upterm-ports has no prebuilt-archive recipe mode (grepped pkgs/*/recipe.mk, mk/common.mk).
