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
