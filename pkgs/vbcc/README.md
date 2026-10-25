# vbcc for AmigaOS 68k (native)

The vbcc C compiler, vasm and vlink as the authors built them for AmigaOS 68k:
vbcc 0.9h patch2 (vbcc_bin_amigaos68k.lha, 2022-03-23) and the target archive
vbcc_target_m68k-amigaos.lha (2022-05-22). No build from source: `make vbcc` fetches both
archives from http://phoenix.owl.de/vbcc/current/, checks their SHA-256 (pinned in
`recipe.mk`), unpacks them unmodified and merges the two trees into one drawer,
`build/sysroot/UP-Term/vbcc`, next to our own files: `config/upterm68k` (generated from
`files/upterm68k.cfg.in`, which mirrors vtcon's `tools/vbcc-aos68k.cfg.in` with Amiga
paths), `startup.txt` and this file. The 68000 code of vc, vbccm68k, vasmm68k_mot and
vlink runs on every Amiga with OS 2.0 or later.

## Licence

vbcc, vasm and vlink: "This archive may be redistributed without modifications and used
for non-commercial purposes", with an exception for commercial use when the target is
M68k AmigaOS ("Resulting binaries may be distributed commercially without further
licensing"). So the archives must stay unmodified; the package never repacks them.

## NDK

The Amiga NDK is not part of this package: vtcon's `vendor/` carries no licence text that
allows redistribution. Download NDK 3.2 (Hyperion, https://www.hyperion-entertainment.com/ ,
or the NDK3.2 on Aminet/OS 3.2 CD) and unpack it; the cfg reads the headers from the
assign `NDKINC:`, which must point at the NDK's `Include_H` drawer.

## Startup

```
Assign VBCC: UP-Term:vbcc
Path VBCC:bin ADD
SetEnv VBCC VBCC:
```

`SetEnv VBCC` is needed: vc looks for `+name` config files in the current directory,
ENV: and VBCC:, and then in `$VBCC/config`, which is where `config/` lives. The NDK needs
one more line, `Assign NDKINC: <NDK>/Include_H`; the stock config `aos68k` of the target
archive uses the assigns `vincludeos3:` and `vlibos3:` instead (see `startup.txt`).

## Use

```
vc +upterm68k hello.c -o hello
```

`+upterm68k` is our cfg (same flags as the vtcon cross build: `-cpu`, `-O2`, vlink with
startup.o and libvc, headers from VBCC: and NDKINC:); the stock `+aos68k` works with the
assigns in `startup.txt`. Programs built for the kit still follow vtcon's stack rule
(`long __stack` and a `$STACK:` cookie); the check's hello.c is a test program without.

## Check

`python3 pkgs/vbcc/check/vbcc_rig.py` (a rig is up, the package installed, an NDK Include_H
drawer given with `--ndk`, default `../vtcon/vendor/ndk-3.2r4-Include_H`) stages the drawer
into VTC:, sets the startup lines, compiles `check/data/hello.c` and runs it.
