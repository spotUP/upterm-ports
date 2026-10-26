# Adding a package

This is how a Unix tool gets into the UP-Term package feed (`upkg install up-<name>`). You write a recipe and open a pull request. The owner reviews it, builds it, checks it on an Amiga and releases it. You do not need an Amiga or the m68k compiler.

## 1. Scope and trust

- The owner builds and releases every package. A merged recipe becomes a program, and often an install script, that runs on other people's Amigas. For that reason every recipe, patch and install script is read line by line before it is merged. Expect questions.
- A pull request adds or changes files under `pkgs/<name>/`. Nothing else is needed for a package that is only data and programs (the rows in the vtcon repository are generated, section 5).
- Licences are judged case by case. There is no fixed list of accepted licences. Say in the pull request what the licence is, where its text is (a URL or a file in the source), and what it says about redistribution of binaries and source. The owner decides each one.

## 2. Worked example: `pkgs/tree`

`pkgs/tree/recipe.mk` is the smallest real recipe (20 lines). A recipe is a make fragment: every variable starts with the package name and an underscore.

```make
tree_VERSION   := 2.2.1
tree_URL       := https://gitlab.com/OldManProgrammer/unix-tree/-/archive/$(tree_VERSION)/unix-tree-$(tree_VERSION).tar.gz
tree_ARCHIVE   := $(DL)/tree-$(tree_VERSION).tar.gz
tree_SHA256    := 70d9c6fc7c5f4cb1f7560b43e2785194594b9b8f6855ab53376f6bd88667ee04
tree_LICENSE   := GPL-2.0-or-later
tree_LICENSE_FILES := LICENSE
tree_DEPS      := ixcompat
tree_BINS      := bin/tree
tree_STACK     := 65536
```

| Line | Meaning |
|------|---------|
| `_VERSION`, `_URL` | The upstream release. Use a release archive over `https`, not a git branch. |
| `_ARCHIVE` | Where the download is kept (`$(DL)` is `build/dl`). |
| `_SHA256` | The hash of the archive. Compute it from the file you downloaded: `shasum -a 256 build/dl/<file>`. Never copy it from a web page. |
| `_LICENSE` | The licence as an SPDX name, shown in the kit's `SOURCES.txt`. |
| `_LICENSE_FILES` | The licence files inside the source tree. The build copies them into the kit's `licenses/<name>/`. Leave empty only if the file is `COPYING`. |
| `_DEPS` | Packages built first. `ixcompat` is the Unix compatibility library every program links. |
| `_BINS` | The installed programs, relative to the install prefix. These are checked after the build. |
| `_STACK` | The stack size in bytes the program asks for (a `$STACK:` cookie is linked in). Every program needs one. |

The build steps follow. `_CONFIGURE_CMD`, `_BUILD_CMD` and `_INSTALL_CMD` replace the default step (`./configure`, `make`, `make install`) when the package has no configure script. Tree has a plain Makefile:

```make
tree_CONFIGURE_CMD = rsync -a --exclude .git $(tree_SRC)/ $(tree_OBJ)/
tree_BUILD_CMD = $(MAKE) -C $(tree_OBJ) tree CC="$(ROOT)/tools/m68k-cc" LDFLAGS="-Wl,$(OBJ)/tree.stack.o" \
	CFLAGS="$(CPU) -O2 -I$(SYSINC)" OBJS="... $(SYSLIB)/libixcompat.a"
tree_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin ... && install -m 755 $(tree_OBJ)/tree $(SYSROOT)$(PREFIX)/bin/tree ...
```

The `HOST_*` commands build the same source on your own computer. Their only purpose is to produce the expected output of the check cases (next paragraph):

```make
tree_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(tree_SRC)/ $(tree_HOBJ)/
tree_HOST_BUILD_CMD = $(MAKE) -C $(tree_HOBJ) tree CFLAGS="-O2" LDFLAGS= && mkdir -p $(tree_HOBJ)/inst/bin && \
	cp $(tree_HOBJ)/tree $(tree_HOBJ)/inst/bin/tree
```

The check cases are `pkgs/tree/check/cases`: one `name<TAB>command` per line, run in a copy of `pkgs/tree/check/data`.

```
version	tree --version
basic	tree d
dirsonly	tree -d d
```

The host build runs each line and writes the output as the expected result. The owner later runs the same lines on an Amiga and compares. A good case set covers the options people use, plus one failing case (`tree nosuchdir`).

Run the example from a checkout of this repository. It needs `curl`, `rsync`, `make` and a C compiler.

```
$ make host-tree JOBS=2
...
fetched tree-2.2.1.tar.gz (sha256 ok)
...
20 expected outputs in <checkout>/build/expected/tree
```

Check your own recipe with the lint (it needs no build):

```
$ sh tools/recipe_lint.sh tree
recipe_lint: tree ok
```

Programs for the Amiga are built by the owner with `make <name>`; you cannot do that without the toolchain, and you do not have to.

## 3. Rules (from RULES.md)

1. One recipe per package: `pkgs/<name>/recipe.mk`. Changes to upstream source are patches in `pkgs/<name>/patches/`, made with `git format-patch`. After editing the unpacked source in `build/src/<name>`, `make <name>-patches` writes them.
2. No fork of the project. Everything links `libixcompat.a` from the separate `ixemul-vtcon` repository. If the program needs a C library function that is missing, the fix goes into `ixemul-vtcon` first, never into the recipe.
3. No `fork()`. A program that links `fork` fails the binary check. Patch it to `posix_spawn` or `vfork` plus `exec`.
4. Every program carries a stack cookie (`_STACK`). Programs started by a `vfork` parent also need `_STACK_VAR := 1`.
5. Build with at most 4 jobs (`JOBS`, default 4).

## 4. Pull request steps

1. `pkgs/<name>/recipe.mk` with the fields above.
2. `_SHA256` from the file you fetched. `make host-<name>` fetches it and stops with `want` and `got` if the hash is wrong.
3. Licence fields and the licence text or URL in the pull request (section 6).
4. `pkgs/<name>/check/cases` and `check/data`.
5. `make host-<name>` output: the last lines pasted into the pull request.
6. `sh tools/recipe_lint.sh <name>` is ok.
7. If it is a feed package, the generated rows (section 5).
8. No binaries, archives or build output in the pull request.

### What the checks do

The pull request workflow (`.github/workflows/pr.yml`) runs on GitHub, on the changed packages only, with no secrets:

- `recipe lint`: `tools/recipe_lint.sh`. Fails on empty required fields, a non-https URL, a program with no check cases.
- `sha256 of the download`: `tools/fetch.sh` downloads `_URL` and compares. A wrong hash fails and prints `want` and `got`:

  ```
  fetch.sh: sha256 mismatch for https://...: want 0000...0000, got 70d9...ee04 (kept as ....bad)
  ```
- `make test`: the repository's host tests.
- `host build (advisory)`: `make host-<name>`, only for recipes that define `HOST_*` commands. A failure is shown but does not block the merge, because the Linux build of the same source is a smoke test and not the Amiga build.
- `feed rows match vtcon`: for recipes that set `_FEED_ID`, `pkg_rows.py check` against the main branch of the UP-Term repository.

A green workflow is not a release. The owner still builds for the Amiga.

## 5. Making a recipe a feed package

A recipe without `_FEED_ID` is a program of the base kit (`tree` is one): it ships in the main archive and has no package of its own. To publish a separate package, add three optional fields:

```make
bitchx_FEED_ID   := up-bitchx
bitchx_SUMMARY   := BitchX IRC client in UP-Term:bin and its IRCLIB in UP-Term:lib/bx
bitchx_FEED_MIN_BASE := 1.0
```

`_FEED_ID` is the package name in the feed. `_SUMMARY` is its one-line description. `_FEED_MIN_BASE` is the lowest base version it works with (empty means the current one). `_DATA` lists extra directories the package installs (BitchX: `lib/bx`).

The rows that the vtcon repository needs (a line in `dist/packages.txt`, lines in `dist/slim.txt` and the six files of `dist/addons/<name>/`) are generated from the recipe. `$VTCON` is a checkout of https://github.com/spotUP/UP-Term. Run both commands from this repository:

```
$ python3 $VTCON/tools/pkg_rows.py emit bitchx --ports . --out /tmp/rows
pkg_rows: bitchx -> /tmp/rows
$ python3 $VTCON/tools/pkg_rows.py check bitchx --ports .
$
```

`emit` writes the rows into the directory you give (add `--write` to put them into the vtcon tables). `check` prints nothing and exits 0 when the committed rows equal the generated ones, and prints `[DRIFT]` lines naming the file and row otherwise. `bitchx` is the finished example: its row is `dist/packages.txt` line 30 and its files are in `dist/addons/bitchx/`. For a recipe with no `_FEED_ID` the tool says so and writes nothing:

```
$ python3 $VTCON/tools/pkg_rows.py emit tree --ports .
pkg_rows: tree has no _FEED_ID: a base-kit program, no feed rows
```

Text the recipe cannot say (the Installer wording, the README) comes from `tools/pkg_rows_prose/<name>.json` in the vtcon repository, or from the summary when there is none.

## 6. Licence checklist

- `_LICENSE` is set and `_LICENSE_FILES` names the licence texts in the source.
- The pull request says what the licence allows for redistribution of the compiled program and of the source.
- GPL and similar licences: the kit carries the source offer. `make kit-stage` copies the recipe, the patches and the downloaded source into `userland-src`, and writes the `SOURCES.txt` row (name, version, URL, sha256, licence). Check that your package appears there.
- The licence is judged case by case. If it restricts redistribution, say so; the owner may decline.

## 7. What the owner does

Owner steps, in order:

1. Read the diff, above all any install script and patch (they run on users' machines). Check the licence rows and the host of the URL.
2. Fetch the archive independently and compare the sha256.
3. `make <name>` (`JOBS=2` if the machine is busy), then `make host-<name>`.
4. In the vtcon repository: `python3 tools/pkg_rows.py emit <name> --ports <this checkout> --write`, apply any hunk the generator cannot write yet, then run the tests of the touched files with `make test ONLY=<suite>` (for the rows themselves: `make test ONLY=pkg_rows`, with `UPTERM_PORTS=<this checkout>` until the ports branch is merged).
5. Rig check: `python3 tools/rig/rig.py start --max --purpose "<session>: check <name> ipk"`, then `make wasabi`, `make amiga` and `python3 tools/rig/rig.py install`. Install the package with `upkg`, run the `check` cases, uninstall, confirm the drawer is gone, then `python3 tools/rig/rig.py stop`.
6. `make dist`; confirm `build/ipk/<id>_*.ipk` and the new stanza in `Packages`.
7. Merge the pull request, commit the vtcon rows, bump the version and publish the release with `gh release create` as vtcon's RULES.md describes (the upload is the owner's step).
8. On a clean rig: `upkg update && upkg install <id>`.

## 8. Not accepted yet

- Your own feed or your own package server.
- Binary-only packages (the source and a reproducible build are required).
- Packages that need a change to the C library. Those go to `ixemul-vtcon` first, then here.
