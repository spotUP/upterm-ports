#!/usr/bin/env python3
"""vbcc_rig.py -- reachability check of the vbcc package on a rig (UPTERM_RIG=<n>, rig up).

Stages build/sysroot/UP-Term/vbcc (`make vbcc` in the ports repo) and an NDK Include_H
drawer into VTC:vbcc-pkg, runs the startup lines of the package (Assign VBCC:, Path,
SetEnv VBCC, Assign NDKINC:), then compiles and runs check/data/hello.c with the package's
own config (+upterm68k) and with the stock one (+aos68k), and check/data/ndk.c (NDK
headers, inline pragmas). Passes when every compile exits 0 and the sentinel lines
appear. Output is text only: build/<rig>/vbcc-pkg-out.txt.

  UPTERM_RIG=5 python3 pkgs/vbcc/check/vbcc_rig.py [--ndk <Include_H>]

--upkg <vtcon tree> checks the package the way a user gets it: the vtcon tree (a checkout or worktree
that has `dist-vbcc` built, build/dist/up-vbcc) is packed into a one-package feed, served over http, the
UP-Term base kit is installed on the rig, and `upkg update; upkg install up-vbcc` runs. Then the block
vbcc wrote to S:User-Startup is executed (VBCC: removed first), NDKINC: is assigned as the owner does,
and the same compiles run. Then `upkg remove up-vbcc` must leave no drawer, assign or startup block.
--no-drawer packs the package without Files/userland/vbcc (the fail-before: vc is not found).

  UPTERM_RIG=2 python3 pkgs/vbcc/check/vbcc_rig.py --upkg <vtcon tree> [--no-drawer]
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


HEAD_SYSROOT = """Assign VBCC: VTC:vbcc-pkg/vbcc
Path VBCC:bin ADD
SetEnv VBCC VBCC:
"""
HEAD_UPKG = """Execute VTC:vbcc-pkg/startup-block.script
"""
BODY = SCRIPT.split("Assign NDKINC:", 1)[1].split("\n", 1)[1]
SCRIPT = HEAD_SYSROOT + "Assign NDKINC: VTC:vbcc-pkg/ndk\n" + BODY


def feed_for(tree, no_drawer, tmp):
    """tmp/ipk: a feed of the one row `vbcc` of <tree>/dist/packages.txt, built by the tree's own tools/pkgs.py."""
    import subprocess
    tmp.mkdir(parents=True)
    dist = tmp / "dist"
    if no_drawer:
        subprocess.run(["cp", "-Rc", str(tree / "build/dist"), str(dist)], check=True)
        shutil.rmtree(dist / "up-vbcc/Files/userland/vbcc")
    else:
        dist.symlink_to(tree / "build/dist")
    rows = [l for l in (tree / "dist/packages.txt").read_text().splitlines()
            if l.startswith("#") or l.split()[:1] == ["vbcc"]]
    (tmp / "packages.txt").write_text("\n".join(rows) + "\n")
    code = ("import sys, pathlib; sys.path.insert(0, %r); import pkgs; t = pathlib.Path(%r); "
            "pkgs.ipk(t, t / 'packages.txt'); pkgs.write_feed(t, t / 'packages.txt')" % (str(tree / "tools"), str(tmp)))
    subprocess.run([sys.executable, "-I", "-c", code], check=True)
    return tmp / "ipk"


def add_control(feed, ipk):
    """Add a prebuilt ipk to the one-package feed (its stanza is copied from the Packages next to it): the package name."""
    import re
    src = (ipk.parent / "Packages").read_text()
    stanza = next(s for s in src.split("\n\n") if "Filename: %s\n" % ipk.name in s + "\n")
    shutil.copyfile(ipk, feed / ipk.name)
    with open(feed / "Packages", "a") as f:
        f.write("\n" + stanza.strip() + "\n")
    return re.search(r"^Package: (\S+)", stanza, re.M).group(1)


def user_startup_block(name):
    text = ami.read_file("S:User-Startup").decode("latin-1")
    lines, on, got = text.splitlines(), False, []
    for l in lines:
        if l.strip() == ";BEGIN " + name:
            on = True
        if on:
            got.append(l)
        if l.strip() == ";END " + name:
            return "\n".join(got) + "\n"
    return ""


def via_upkg(a):
    import tempfile
    sys.path.insert(0, str(VTCON / "tools/rig"))
    import install_rig as ir, upkg_rig as ur
    tree = pathlib.Path(a.upkg).resolve()
    feed = feed_for(tree, a.no_drawer, pathlib.Path(tempfile.mkdtemp(prefix="vbccfeed")) / "f")
    control = add_control(feed, pathlib.Path(a.control).resolve()) if a.control else None
    fails, seen = [], []

    def ck(ok, what, detail=""):
        seen.append("[%s] %s %s" % ("OK" if ok else "FAIL", what, "" if ok else str(detail)[-300:]))
        if not ok:
            fails.append(what)

    with paths.rig_lock():
        ir.put_vsh()
        fx = ir.Fixtures()
        rel = ur.Release()
        base = False
        try:
            fx.take()
            ir.prepare(None)
            # a user who runs upkg picked curl in the Installer (upkg downloads through it; the rig's system
            # disk carries AmiSSL); the rig is a 68060
            (ur.VTC / "runinstall").write_text(
                "Execute VTC:distkit/Files/install.dos VTC:distkit/Files NOCONSOLE NODEVICE CURL CPU060\n")
            ir.base_install(ck)
            # prepare() assigned LIBS: as Install sees it, without the rig's AmiSSL drawer: curl needs
            # amisslmaster.library even for the http feed (the same step as upkg_browse_rig.py)
            for line in ir.rig_libs():
                ir.run(line)
            # a freshly cloned system disk has no AmiSSL: the kit's amisslmaster.library (v5) goes beside the
            # rig's amissl_v362.library in VTC:amissl, which RIG_LIBS puts in LIBS:
            ir.run("Copy VTC:distkit/Files/AmiSSL/Libs/AmigaOS3/amisslmaster.library VTC:amissl CLONE QUIET")
            base = True
            ur.VTC.joinpath("upkg-rig.conf").write_text(ur.conf_for((VTCON / "dist/upkg.conf").read_text(), rel.url))
            ir.run("Copy VTC:upkg-rig.conf %s" % ur.CONF)
            rel.set(feed, (feed / "Packages").read_text())
            rc, out = ur.upkg("vbccupd", "update")
            ck(rc == 0, "upkg update: exit 0", out)
            if os.environ.get("VBCC_STACK"):
                _slow = ir.run_slow
                ir.run_slow = lambda n, c, t=600: _slow(n, "Stack %s\n%s" % (os.environ["VBCC_STACK"], c), t)
            if control:
                rc, out = ur.upkg("vbccctl", "install " + control, 900)
                ck(rc == 0 and "Illegal instruction" not in out, "control upkg install %s: exit 0, no crash" % control, out)
            rc, out = ur.upkg("vbccinst", "install up-vbcc", 900)
            ck(rc == 0 and "Illegal instruction" not in out, "upkg install up-vbcc: exit 0, no crash", out)
            (paths.RIG / "vbcc-upkg-install.txt").write_text(out, encoding="latin-1")
            ck(ur.exists("UP-Term:vbcc/bin/vc"), "UP-Term:vbcc/bin/vc landed")
            ck(ur.exists("UP-Term:pkg/up-vbcc/VERSIONS"), "the record UP-Term:pkg/up-vbcc/VERSIONS is there")
            block = user_startup_block("vbcc")
            ck(bool(block), "S:User-Startup carries the ;BEGIN vbcc block")
            d = VTC / "vbcc-pkg"
            if d.exists():
                run("Delete >NIL: VTC:vbcc-pkg ALL QUIET FORCE", 120)
                shutil.rmtree(d, ignore_errors=True)
            shutil.copytree(a.ndk, d / "ndk", symlinks=True)
            (d / "work").mkdir()
            for f in ("hello.c", "ndk.c"):
                shutil.copyfile(HERE / "data" / f, d / "work" / f)
            (d / "startup-block.script").write_text("Assign VBCC: REMOVE\n" + block, encoding="latin-1")
            script = SCRIPT.replace(HEAD_SYSROOT, HEAD_UPKG)
            (d / "check.script").write_text(script, encoding="latin-1")
            run("Execute VTC:vbcc-pkg/check.script >VTC:vbcc-pkg/out.txt", 240)
            got = (d / "out.txt").read_text(encoding="latin-1") if (d / "out.txt").exists() else ""
            (paths.RIG / "vbcc-pkg-out.txt").write_text(got, encoding="latin-1")
            lines = [l.strip() for l in got.splitlines()]
            missing = [w for w in WANT if w not in lines]
            ck(not missing, "compile and run lines", "missing: %s; output tail: %s" % (", ".join(missing), got[-600:]))
            # the compile script assigned vincludeos3:/vlibos3: into the drawer (the owner puts these in his own
            # startup, not the package): they lock include and lib, so no Delete of the drawer can succeed
            for n in ("vincludeos3:", "vlibos3:", "NDKINC:"):
                run("Assign >NIL: %s REMOVE" % n)
            rc, out = ur.upkg("vbccrm", "remove up-vbcc", 600)
            ck(rc == 0, "upkg remove up-vbcc: exit 0", out)
            ck(not ur.exists("UP-Term:vbcc"), "remove: UP-Term:vbcc is gone")
            ck(not ur.exists("UP-Term:pkg/up-vbcc"), "remove: the record is gone")
            ck(not user_startup_block("vbcc"), "remove: the ;BEGIN vbcc block is gone")
            ck(run("Assign VBCC: EXISTS")[0] != 0, "remove: the VBCC: assign is gone")
        finally:
            rel.close()
            try:
                ir.run("Delete >NIL: %s QUIET" % ur.CONF)
                if base:
                    ir.run_long("rununinstall")
            finally:
                fx.restore()
                ir.show_close()
    print("\n".join(seen))
    print("[%s] vbcc via upkg: %d failed of %d" % ("FAIL" if fails else "OK", len(fails), len(seen)))
    sys.exit(1 if fails else 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ndk", default=str(VTCON / "vendor/ndk-3.2r4-Include_H"))
    ap.add_argument("--upkg", help="vtcon tree with build/dist/up-vbcc: check the upkg install of it")
    ap.add_argument("--control", help="with --upkg: an extra known-good ipk, added to the feed and installed first (crash-hunt control)")
    ap.add_argument("--no-drawer", action="store_true", help="with --upkg: pack the package without the vbcc drawer")
    a = ap.parse_args()
    if a.upkg:
        return via_upkg(a)
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
