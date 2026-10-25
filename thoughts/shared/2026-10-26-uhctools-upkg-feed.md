# UHC Tools as an upkg feed (research, 2026-10-26, session vtcon-05)

Verdict: feasible with conditions. UHC Tools is not a repository of many packages with an index: it is ONE
bundle per OS (uhctools_os3.lha, 150 KB) of ~28 small programs and ~30 scripts plus an on-demand downloader for
eleven third-party tools. One ipk ("up-uhc") is easy; "everything UHC offers" has no machine-readable feed to track.
Decisive condition: the licence is not stated anywhere reachable, so redistribution needs the authors' OK.

## 1. What UHC is
- http://uhc.megaburken.net/ : "programs and scripts for Amiga computers and their offsprings". No maintainer named on the
  site; Aminet https://aminet.net/util/misc/UHCTools.readme gives v2.2 by Patrik Axelsson and David Eriksson (revision file in
  the archive: Sep 28 2026). Mirrors: megaburken.net, driar.se, a1k.org, no0b.de, hex9d.com. No GitHub org found (search found none).
- Own tools in C/: aget (HTTP/HTTPS/Gemini downloader, needs AmiSSL 4+), asum, sntp, TCPBlock/Echo/Rec/Send, SynergyClient,
  UTF8Echo, UHCSearch, ForEachLine, ModifyPath, time, etc. (28 binaries); S/ has 94 files (search scripts for Aminet, OS4 Depot, WHDLoad...).
- Target: one archive per OS: uhctools_os3.lha (150052 B), _os4 (165866), _mos (164422), _aros-i386 (151175); Aminet: m68k OS 2.0.4+, bsdsocket 3.0+.
  Toolchain/libc not stated; the os3 binaries are plain loadseg executables, "68020 versions" mentioned for deps. CPU floor unverified.
- Shipping: whole-archive lha, installer script http://uhc.megaburken.net/uhcinstall (v1.48): installs to SYS:UHC, SetEnv UHCBIN, ENV:UHC/*,
  ;BEGIN UHC block in S:User-Startup running UHC:UHC-Startup (Assign UHC:, Path UHC:C UHC:S), copies uhcupdate into S:. Installs no libs in LIBS:.
- Updates: http://uhc.megaburken.net/uhctools_log (dated changelog, ~monthly in 2026); uhccheck/uhcupdate self-update the bundle in place.
- Second tier: Packages/ in the archive lists 11 third-party tools (amigae, curl, diskwiz, lzx, pipe, split, system, ttcp, unrar, unzip, xdms)
  as stub files with .desc; they are fetched on demand (not in the 150 KB archive; source URLs unverified, in the stubs).
- Licence: not stated on the site, help/aget, or Aminet summary. Full Aminet readme not read (summary only). Unverified.

## 2. UP-Term feed today
- vtcon tools/pkgs.py reads dist/packages.txt (id, archive, version, needs-base, ixemul, record, handed, consumes), `pkgs.py ipk <build>` writes one
  ipk per row from build/dist/<archive>, `pkgs.py feed` writes Packages + Packages.gz. Feed URL: dist/upkg.conf:6
  `src/gz upterm https://github.com/spotUP/vtcon/releases/latest/download` (so ipks are release assets of vtcon).
- Precedent: worktree .claude/worktrees/vbcc-kit (addon/vbcc-kit) build/dist/up-vbcc has Files, Install, LICENSES.txt, README.txt, Uninstall.

## 3. Feasibility
(a) Generator: fetch uhctools_os3.lha, stage as drawer, one row in packages.txt, ipk via existing path. No index to poll; the version is the
    `revision` file inside the archive (or Last-Modified), so a generator would check that file per release. Per-tool ipks are possible
    (split C/ by file) but upstream treats the bundle as one unit and uhcupdate would fight upkg.
(b) Needs: Assign UHC: and Path UHC:C UHC:S (UHC-Startup block, as vbcc add-on does), SetEnv UHCBIN + ENV:UHC/* defaults (uhcinstall sets them),
    S:uhcupdate copy. aget HTTPS needs AmiSSL (UP-Term ships it? not checked). uhcupdate/uhccheck would rewrite files under upkg's MANIFEST:
    must be disabled or the ipk marked self-updating. OS3 only for us; ignore the other three archives.
(c) Hosting: Filename: is relative to the feed base, so the ipk must be a vtcon release asset (mirror) or a second feed. A second
    `src/gz` feed generated UHC-side is possible only if the UHC authors publish ipks; they do not. A second UP-Term-hosted feed repo
    holding mirrored ipks is the clean split.
(d) Licence: unknown, ask the authors (contact via Aminet readme) before redistributing; keep archive unmodified and credit Axelsson/Eriksson.
    Clashes: UP-Term:bin userland has none of aget/asum/sntp/time (checked in vtcon/Files/userland/bin by name, not exhaustively); UHC's `time`
    would shadow the Amiga/unix time command by Path order: put UHC after UP-Term. Bundled curl/unzip/unrar would clash with ports if added.

## 4. Size
- 1 bundle per OS now (os3 150 KB, 264 files) + 11 on-demand third-party packages. Work: small (one agent, one batch) for the single up-uhc ipk.
- First five if split into per-tool packages: aget, asum, sntp, SynergyClient, UHCSearch (+ S/ search scripts); but recommend one bundle ipk instead.
