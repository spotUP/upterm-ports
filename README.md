# upterm-ports

Recipes and patches that build Unix tools for the UP-Term AmigaOS kit. Part of the upterm source tree.

`make kit-stage` copies the programs of every checked package to `build/kit/userland/bin` and writes `build/kit/userland/SOURCES.txt` there (package, version, URL, sha256, licence); the vtcon kit does not read it (`make dist` in vtcon does not use it).

## Build

Commands: `RULES.md`, section `## Commands`. `make sysroot` builds libixcompat and
ncurses; `make <pkg>` builds one package (e.g. `make grep`); `make host-<pkg>`
builds the same source on the Mac to produce the expected outputs the rig
compares against. Needs bebbo's gcc 6.5 in `~/opt/amiga` (`AMIGA=`), and
`../ixemul-vtcon` and `../vtcon` beside this repo (`UPTERM_ROOT=` moves them).
Not needed for the kit; the userland rig (`vtcon/tools/rig/userland_rig.py`) uses
what it builds. The whole path: the `upterm` repo's README, "Set up the whole
thing".
