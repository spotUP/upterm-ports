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

Adding a package: `CONTRIBUTING.md` and `docs/adding-a-package.md`.

## Starting upkg from Workbench

`UP-Term:bin/upkg` also starts from Workbench (an icon start, no Shell). It opens the window "UP-Term Add-ons" on the Workbench screen:

- A list of the packages the feed offers, each with its state (installed, upgrade, available). The cycle gadget filters the list (All, Installed, Upgradable).
- Install and Remove buttons act on the selected package; Upgrade and Update do the same as `upkg upgrade` and `upkg update`. The window stays usable while a command runs, and the output scrolls in the log gadget.
- A package that asks questions of its own while it installs is refused with a message ("<name> asks questions of its own. Run it from a Shell: upkg install <name>"); run it from a Shell instead.
- If upkg cannot make its temporary drawer (TMP: is not assigned, or its volume is full), a requester names the reason and the hint `Assign TMP: T:`; before this, Workbench showed nothing.
- A failure ends upkg with return code 20 (RETURN_FAIL), never a negative code, so a script or the Workbench start sees it.

From a Shell nothing changes: `upkg list`, `upkg install <package>` and `upkg browse` work as before. The user text for the kit is `dist/README.txt` in the vtcon repo, section PACKAGES (upkg).
