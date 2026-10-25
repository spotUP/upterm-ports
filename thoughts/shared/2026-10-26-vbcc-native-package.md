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
