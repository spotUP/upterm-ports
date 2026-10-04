# upterm-ports rules

The global rules (`~/.claude/CLAUDE.md`) apply; this file adds the project's.
The plan is vtcon's `thoughts/shared/plans/2026-10-04-unix-tool-ports.md`;
progress is ledgered in `thoughts/shared/plans/2026-10-04-phase0-progress.md`.

1. **One recipe per package**, `pkgs/<pkg>/recipe.mk` (version, URL, sha256,
   licence, configure flags, the programs it ships). Upstream changes live in
   `pkgs/<pkg>/patches/` as `git format-patch` files (`make <pkg>-patches`
   writes them from `build/src/<pkg>`, which is a git tree tagged `upstream`).
2. **Runtime: ixemul-vtcon.** Everything links `libixcompat.a` from the sibling
   checkout `~/Code/ixemul-vtcon` (`make ixcompat` overlays its SDK headers and
   library into `build/sysroot`; the toolchain's own SDK is never modified).
   A libc gap is fixed in ixemul-vtcon (`compat/` or `include/`), never in a
   recipe. A header configure takes from the toolchain's newlib sys-include
   gets an ixemul header or a measured `mk/config.site` answer.
3. **No fork.** `check_bin` fails a program that links `fork`; use
   `posix_spawn` (libixcompat) or vfork + exec.
4. **Build at most 4 jobs** (`JOBS`, default 4; the Mac overheats). Never start
   an emulator from here: rig checks are steps for the session that owns it.
5. **Measure, then answer.** Every `config.site` line and every compat function
   names the build that needed it.

## Commands

| Task | Command |
|------|---------|
| Build one package (fetch, patch, configure, build, install to the sysroot, check_bin) | `make <pkg>` (e.g. `make grep`; `JOBS=2` when the Mac is busy) |
| The libraries the tools build against | `make sysroot` (libixcompat + ncurses today) |
| macOS build of the same source + expected outputs of its check cases | `make host-<pkg>` (writes `build/expected/<pkg>/<case>.txt`) |
| Host checks of one binary | `tools/check_bin.sh <pkg> "<stack bytes or empty>" <binary>...` |
| 68030+/FPU scan alone | `python3 tools/m68k_scan.py <binary>` |
| Binary sizes so far | `make sizes` (`build/state/sizes.tsv`) |
| Stage the kit drawer + SOURCES.txt | `make kit-stage` (`build/kit/userland`) |
| Refresh a package's patches after editing `build/src/<pkg>` | `make <pkg>-patches` |
| Forget one package | `make clean-<pkg>` |
| Everything | `make clean` |
| libixcompat host tests (in ixemul-vtcon) | `make -C ~/Code/ixemul-vtcon/compat test` |
| posix_spawn rig probe binary (in ixemul-vtcon) | `make -C ~/Code/ixemul-vtcon/compat spawnprobe CPPFLAGS=-I$PWD/build/sysroot/SYS/UP-Term/include` |

There is no lint or type-check step: the packages are upstream C built by their
own build systems; `check_bin` is the gate.
