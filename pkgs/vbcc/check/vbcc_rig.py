#!/usr/bin/env python3
"""vbcc_rig.py -- reachability check of the vbcc package on a rig (UPTERM_RIG=<n>, rig up).

Stages build/sysroot/UP-Term/vbcc (`make vbcc` in the ports repo) and an NDK Include_H
drawer into VTC:vbcc-pkg, runs the startup lines of the package (Assign VBCC:, Path,
SetEnv VBCC, Assign NDKINC:), then compiles and runs check/data/hello.c with the package's
own config (+upterm68k) and with the stock one (+aos68k), and check/data/ndk.c (NDK
headers, inline pragmas). Passes when every compile exits 0 and the sentinel lines
appear. Output is text only: build/<rig>/vbcc-pkg-out.txt.

  UPTERM_RIG=5 python3 pkgs/vbcc/check/vbcc_rig.py [--ndk <Include_H>]
"""
import argparse, os, pathlib, shutil, struct, sys

HERE = pathlib.Path(__file__).resolve().parent
PORTS = HERE.parents[2]
VTCON = pathlib.Path(os.environ.get("VTCON", PORTS.parent / "vtcon"))
sys.path.insert(0, str(VTCON / "tools/rig"))
import ami, paths

VTC = paths.RIG / "vtc"
SCRIPT = """Assign VBCC: VTC:vbcc-pkg/vbcc
Path VBCC:bin ADD
SetEnv VBCC VBCC:
Assign NDKINC: VTC:vbcc-pkg/ndk
Assign vincludeos3: VBCC:targets/m68k-amigaos/include
Assign vincludeos3: NDKINC: ADD
Assign vlibos3: VBCC:targets/m68k-amigaos/lib
CD VTC:vbcc-pkg/work
Delete >NIL: hello hello2 ndk QUIET
vc +upterm68k hello.c -o hello
Echo "[exit vc upterm68k $RC]"
hello
Echo "[exit hello $RC]"
vc +aos68k hello.c -o hello2
Echo "[exit vc aos68k $RC]"
hello2
Echo "[exit hello2 $RC]"
vc +upterm68k ndk.c -o ndk
Echo "[exit vc ndk $RC]"
ndk
Echo "[exit ndk $RC]"
"""
WANT = ["[exit vc upterm68k 0]", "VBCC-NATIVE-OK 0.9h", "[exit hello 0]", "[exit vc aos68k 0]",
        "[exit hello2 0]", "[exit vc ndk 0]", "VBCC-NDK-OK", "[exit ndk 0]"]


def run(cmd, timeout=240):
    b = ami.req(0x02, struct.pack('>H', timeout) + cmd.encode('latin-1'), timeout=timeout + 10)
    return struct.unpack('>I', b[:4])[0], b[4:].decode('latin-1')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ndk", default=str(VTCON / "vendor/ndk-3.2r4-Include_H"))
    a = ap.parse_args()
    pkg = PORTS / "build/sysroot/UP-Term/vbcc"
    if not (pkg / "bin/vc").exists():
        sys.exit("[ERROR] no %s: run `make vbcc` in %s" % (pkg, PORTS))
    d = VTC / "vbcc-pkg"
    if d.exists():
        run("Delete >NIL: VTC:vbcc-pkg ALL QUIET FORCE", 120)   # the Amiga side: FS-UAE's directory cache
        shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(pkg, d / "vbcc", symlinks=True)
    shutil.copytree(a.ndk, d / "ndk", symlinks=True)
    (d / "work").mkdir()
    for f in ("hello.c", "ndk.c"):
        shutil.copyfile(HERE / "data" / f, d / "work" / f)
    (d / "check.script").write_text(SCRIPT, encoding="latin-1")
    rc, out = run("Execute VTC:vbcc-pkg/check.script >VTC:vbcc-pkg/out.txt", 240)
    got = (d / "out.txt").read_text(encoding="latin-1") if (d / "out.txt").exists() else ""
    (paths.RIG / "vbcc-pkg-out.txt").write_text(got, encoding="latin-1")
    lines = [l.strip() for l in got.splitlines()]
    missing = [w for w in WANT if w not in lines]
    print(got)
    print("agent rc %s %s" % (rc, out.strip()[:200]))
    if missing:
        print("[FAIL] missing: %s" % ", ".join(missing))
        sys.exit(1)
    print("[OK] vbcc: %d of %d lines" % (len(WANT), len(WANT)))


if __name__ == "__main__":
    main()
