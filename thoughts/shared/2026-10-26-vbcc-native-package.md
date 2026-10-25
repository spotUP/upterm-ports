---
date: 2026-10-26
topic: vbcc native AmigaOS 68k package for upterm-ports
status: implemented, rig-verified on rig 5 (060)
---

# vbcc native package

Owner decision 2026-10-26: package the ready-made vbcc binaries, no build from source. Package: `pkgs/vbcc`. Version 0.9h patch 2 (`$VER: vbcc 0.908 (20.03.2022)`).

## What the package is

Two unmodified lha archives from phoenix.owl.de, SHA256 pinned in `pkgs/vbcc/recipe.mk`: `vbcc_bin_amigaos68k.lha` (vc, vbccm68k, vasmm68k_mot, vlink, ar and more, plus docs) and `vbcc_target_m68k-amigaos.lha` (vbcc libc headers, startup.o, libvc, the stock configs). `tools/unpack-lha.sh` unpacks each archive untouched; the recipe merges both into `build/sysroot/UP-Term/vbcc`, adds the package config `config/upterm68k` (generated from `files/upterm68k.cfg.in`) and sets mode 755 on `bin/*`. `mk/common.mk` gained `<p>_LHA_URLS` and `<p>_LHA_SHA256S` for packages that ship prebuilt archives. The recipe needs host `lha`. The package sets `vbcc_NO_KIT`: kit-stage has no shape yet for a prebuilt drawer.

## License (quoted from the manuals in doc/*.pdf)

vbcc, manual section 1.2: "vbcc is copyright in 1995-2022 by Volker Barthelmann. This archive may be redistributed without modifications and used for non-commercial purposes. An exception for commercial usage is granted, provided that the target CPU is M68k and the target OS is AmigaOS. Resulting binaries may be distributed commercially without further licensing. In all other cases you need my written consent."

vasm: "vasm is copyright in 2002-2022 by Volker Barthelmann. This archive may be redistributed without modifications and used for non-commercial purposes. An exception for commercial usage is granted, provided that the target CPU is M68k and the target OS is AmigaOS. Resulting binaries may be distributed commercially without further licensing. In all other cases you need my written consent."

vlink: "vlink is copyright 1995-2022 by Frank Wille. This archive may be redistributed without modifications and used for non-commercial purposes. An exception for commercial usage is granted, provided that the target OS is AmigaOS/68k. Resulting binaries may be distributed commercially without further licensing. In all other cases you need my written consent."

Consequence: the archives must stay unmodified, so the package never repacks them; it ships its own files (config, startup, README) next to the unpacked tree. vbcc also embeds the ucpp license (BSD style).

## NDK

The vtcon vendor copies (`vendor/ndk-3.2r4-Include_H`, `ndk-3.2r4-netinclude`) carry no license, readme or copyright file, and a search for "redistribut" found nothing. The NDK is therefore NOT bundled. The package config points at the `NDKINC:` assign; the user (or the rig check) assigns it to an Include_H drawer.

## Rig result (rig 5, 060, OS 3.2)

`UPTERM_RIG=5 python3 pkgs/vbcc/check/vbcc_rig.py`, exit 0, "[OK] vbcc: 8 of 8 lines". Output text lines: `[exit vc upterm68k 0]`, `VBCC-NATIVE-OK 0.9h`, `[exit hello 0]`, `[exit vc aos68k 0]`, `VBCC-NATIVE-OK 0.9h`, `[exit hello2 0]`, `[exit vc ndk 0]`, `VBCC-NDK-OK`, `[exit ndk 0]`. Startup lines used: `Assign VBCC:`, `Path VBCC:bin ADD`, `SetEnv VBCC VBCC:`, `Assign NDKINC:`, `vincludeos3:` and `vlibos3:` assigns. Both the package config (+upterm68k) and the stock config (+aos68k) work.

## Unverified

- Which lookup path vc used for the config (`$VBCC/config` or the VBCC: assign); both are set, the result works.
- Exec bit on a real A1200 (only the rig, which stages through a host directory).
- Not in kit-stage; nothing installed from a kit.
- The check test programs (hello.c, ndk.c) have no `__stack` or `$STACK` cookie: they are throwaway tests, not shipped programs.
- A real vtcon source was not compiled.

## 2026-10-25 kit and upkg route (session vtcon-05)

### Evidence
- kit-stage (Makefile:43-46, tools/kit-stage.sh) staged only `<p>_BINS` plus a licence plus the `$ARCHIVE` copy (variables documented in mk/common.mk:80-90). `KIT_PKGS` skips `_NO_KIT`, `_KIT_HOLD` and packages without a `.installed` stamp.
- The package `upkg install` fetches is NOT built in upterm-ports. It is built in the vtcon repo: dist/packages.txt, dist/slim.txt with tools/slim.py, Makefile `SLIM_STAGE` and `dist-<id>`, tools/pkgs.py (`SUMMARY`, `NEW_PACKAGES`, `ipk()`, `feed()`), dist/addons/<id>/, dist/aminet/<id>.readme.in, tools/mkinstaller.py, tests/test_dist_*.py. The fix is therefore two commits in two repos.
- Closest existing shape: the up-bitchx add-on (vtcon 85df88f5). The Python add-on supplies the `S:User-Startup` block pattern (`;BEGIN <name>` to `;END <name>`) and its removal through `vsh ENVARC:up-term/unstartup.sh <name>`.
- Removing `vbcc_NO_KIT` alone would put the 8.4 MB drawer into the base kit of everyone. It must land with the slim.txt rows `vbcc vbcc` and `vbcc licenses/vbcc`.

### Design
- upterm-ports: `<p>_DRAWER` in kit-stage (6121cfd), test in tools/test_kit_stage.sh (ef92098; passes, fails with kit-stage.sh reverted). `vbcc_NO_KIT` replaced by `vbcc_DRAWER := vbcc`.
- vtcon branch addon/vbcc-kit (d66d89ce): add-on dist/addons/vbcc, row `vbcc up-vbcc` in packages.txt, `dist-vbcc` target, slim rows, tests. `make dist-vbcc` builds build/dist/up-vbcc and a 3.0 MB up-vbcc_1.0_m68k-amigaos.ipk (feed built with the branch's own tools/pkgs.py).
- upterm-ports aadb4f8: pkgs/vbcc/check/vbcc_rig.py `--upkg <vtcon tree> [--no-drawer]`: one-package feed, http server, base kit install, `upkg update`, `upkg install up-vbcc`, run of the S:User-Startup block (VBCC: removed first), NDKINC: assigned, the same compiles, then `upkg remove up-vbcc` and absence checks.

### Result: reachability NOT proven
- Python dist tests (addons, assemble, manifest, packages, slim) pass with nice 19; manifest and slim skip their full-tree parts (no full build tree in the worktree). Not run with SLIM_REQUIRE=1.
- Rig 2 was not mine: it was started at 23:50:20 by another session (start.args purpose "Selecta session: I340 screen size check on rig 2"); my own start said "already running". I used it before noticing (base kit install and base uninstall through the install_rig fixtures; fixtures restored; the rig lock was free). Stopped using it; did NOT stop it.
- Both script runs (logs vbcc-kit-rig-nodrawer.log and vbcc-kit-rig-pass.log in the session scratchpad) got through feed, base install and uninstall, then `upkg update` failed: "curl returned -1 (is curl installed and in PATH?)" for http://127.0.0.1:<port>/Packages.gz. Cause not found (rig 2 network, or curl missing from the base kit install on that rig). Everything after it is therefore unverified: install of up-vbcc, the startup block, `VBCC-NATIVE-OK 0.9h`, remove. The fail-before (no drawer) was not shown either.

### Open items
- Rerun `UPTERM_RIG=<own rig> python3 pkgs/vbcc/check/vbcc_rig.py --upkg <vtcon worktree>` on a rig with working network (check upkg_rig.py passes there first), then with `--no-drawer` for the fail-before.
- `repos.lock` in the `upterm` meta-repo must pin both new commits (not done).
- Worktrees remain: upterm-ports .claude/worktrees/vbcc-kit (port/vbcc-kit) and vtcon .claude/worktrees/vbcc-kit (addon/vbcc-kit); remove after merge. build/ in the vtcon worktree is untracked.
