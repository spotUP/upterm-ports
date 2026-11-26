# openmui

OpenMUI 1.0 (https://github.com/creep-ltx/openmui, Tobias Karlsson): a free
replacement for MUI on AmigaOS 3.1+, 68000 and up, no FPU, no keyfile. The recipe
installs the author's release archive `up-opmui.lha` unmodified into
`build/sysroot/UP-Term/openmui`.

## What is in the drawer

| Drawer path | Goes to on the Amiga |
|---|---|
| `Libs/muimaster.library` | `LIBS:` |
| `Libs/up-mcc.library` | `LIBS:` |
| `Libs/OpenMUI/*.mui` | `LIBS:OpenMUI/` (class files, loaded on demand) |
| `Libs/MUI/*.mcc`, `*.mcp` | `LIBS:MUI/` (41 bundled classes plus UP-MCC's `UP-*.mcc`) |
| `Prefs/OpenMUI`, `.info` | `SYS:Prefs/` |
| `Fonts/Inter-Regular.ttf` | `FONTS:` |
| `Themes/UP-MCC/*.theme` | `ENVARC:UP-MCC/` and `ENV:UP-MCC/` |
| `Locale/` | `LOCALE:Catalogs/` (optional) |
| `Install` | the author's Installer script: does all of the above with backup and uninstall record |

Settings live in `ENVARC:OpenMUI` / `ENV:OpenMUI`. A reboot is needed after the
library is replaced.

## Licences

Core: AROS Public License 1.1. Bundled classes: LGPL 2.1 and others. UP-MCC: MIT.
Lucide icons: ISC. Inter font: OFL 1.1. The notices (`LICENSE`, `ReadMe`) and the
source (`Source.tar.gz`) must travel with the binaries; the recipe keeps them.

## Not built from source yet

A source build needs: `-std=gnu17` (our m68k-amigaos-gcc is 6.5; upstream uses
GCC 16), a host FlexCat, sfdc, fd2sfd, and the `thebar` git submodule. Do that when
OpenMUI itself has to change (for example UP-MCC as the built-in default look).

## Default look: UP-MCC colours for every MUI application

`make openmui` also writes `Themes/OpenMUI/Dark.prefs` and `Light.prefs`
(`theme2prefs.py`, generated from `Themes/UP-MCC/*.theme`). Each is a complete
OpenMUI `global.prefs` (IFF PREF/MUIC) that sets the stock classes' backgrounds,
string gadget colours and focus ring to the theme's colours as RGB pen specs.

| File | Target |
|---|---|
| `Themes/OpenMUI/<theme>.prefs` | `ENVARC:OpenMUI/global.prefs` and `ENV:OpenMUI/global.prefs` |

Install the Dark one by default, and copy the matching one wherever
`ENV:UP-MCC/theme` is switched. Applications started after the copy use it; a
running one keeps its colours until restarted. Do not overwrite a `global.prefs`
the user saved from Prefs/OpenMUI without a backup.

Limit: colours only. Frames, shine/shadow and label text use the screen's pens,
and the widgets are still drawn by the stock classes, not by UP-*.mcc. Drawing
them with UP-MCC needs a muimaster source patch (class substitution).
