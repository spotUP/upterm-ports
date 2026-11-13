# Contributing

A new tool is one recipe, `pkgs/<name>/recipe.mk`, plus check cases. The full guide, with a worked example and the pull request checklist, is `docs/adding-a-package.md`. This file is the short path and the rules.

## Overview

- A package is a recipe under `pkgs/<name>/`: `recipe.mk` (version, URL, sha256, licence, build steps, programs), optional `patches/`, and `check/cases` plus `check/data` (see `pkgs/tree/`).
- The owner reviews, builds, checks on an Amiga and releases every package. A merged recipe runs on other people's machines, so it is read in full.
- Contributors never upload anything and never push to the feed. The owner builds the feed in the vtcon repository (`make dist`) and publishes the release; the upload is the owner's step (`docs/adding-a-package.md`, section 7). You do not need an Amiga or the m68k compiler.

## Prerequisites

For the steps a contributor runs (`make host-<name>`, the lint): `curl`, `rsync`, `make` and a C compiler (`docs/adding-a-package.md`, section 2). `make <name>` (the Amiga build) needs bebbo's gcc 6.5 in `~/opt/amiga` and the `ixemul-vtcon` and `vtcon` checkouts beside this repo (`README.md`, "Build"); the owner does that build, you do not have to.

## Step by step

1. Fork `spotUP/upterm-ports` on GitHub, clone your fork, create a branch.
2. Copy the closest sibling: `cp -r pkgs/tree pkgs/<name>` (a plain Makefile program), or another package in `pkgs/` that uses the same build system. Edit `recipe.mk`; every variable starts with `<name>_`. Fields are explained in `docs/adding-a-package.md`, section 2.
3. Set `_SHA256` from the file you downloaded (`shasum -a 256 build/dl/<file>`), never from a web page.
4. Write `pkgs/<name>/check/cases` (one `name<TAB>command` per line, with one failing case) and `pkgs/<name>/check/data`.
5. Run `make host-<name> JOBS=2`. It builds the same source on your computer and writes the expected outputs to `build/expected/<name>/`.
6. Run `sh tools/recipe_lint.sh <name>`; it must print `recipe_lint: <name> ok`.
7. If the package should have its own entry in the feed, add `_FEED_ID`, `_SUMMARY` (and `_DATA` for extra drawers) and run the row generator (`docs/adding-a-package.md`, section 5).
8. Open the pull request.

The owner does the Amiga build and the rig install check after the merge (`docs/adding-a-package.md`, section 7).

## Rules a pull request must meet

Source: `RULES.md` and `docs/adding-a-package.md`, sections 3, 4 and 6.

- One recipe per package; changes to upstream source are patches in `pkgs/<name>/patches/` made with `git format-patch` (`make <name>-patches`).
- `_LICENSE` and `_LICENSE_FILES` set; the pull request says what the licence is, where its text is, and what it allows for redistribution. Licences are judged case by case.
- `_URL` is https and a release archive; `_SHA256` matches.
- Check cases exist for every program (`recipe_lint` fails otherwise).
- No `fork()`; use `posix_spawn` or vfork plus exec. A libc gap is fixed in `ixemul-vtcon`, never in a recipe.
- Every program has `_STACK`; programs started by a vfork parent also need `_STACK_VAR := 1`.
- Never name a CPU or FPU flag (`-m68020`, `-m68060`, `-m68881`) in a recipe; use `$(CPU)`, `$(SYSINC)`, `$(SYSLIB)`.
- At most 4 build jobs.
- No binaries, archives or build output in the pull request.
- Not accepted yet: your own feeds, binary-only packages, packages that need a C library change (those go to `ixemul-vtcon` first).
- Version and revision: a new upstream version changes `_VERSION`, `_URL` and `_SHA256` together, and the package goes out as revision 1 (`1.2-r1`). A change to the package only (a new patch, different build flags) with the same upstream version raises the revision (`1.2-r1` to `1.2-r2`). The recipe has no revision field: `_VERSION` is the upstream version alone, and the owner adds and bumps `-rN` when publishing the feed. Say in the pull request which kind of change it is.

## Pull request flow

- Branch: name it `port/<name>` (for example `port/htop`).
- Commits: one imperative subject line per change (for example "Add htop recipe"), no generated files.
- The pull request description follows `.github/pull_request_template.md`, which GitHub fills in for you. It states: the package and upstream version, the licence (name, text location, redistribution), the last lines of `make host-<name>`, and that `tools/recipe_lint.sh <name>` is ok. For a feed package, the output of `pkg_rows.py check`.
- GitHub runs `.github/workflows/pr.yml` on the changed packages (recipe lint, sha256 of the download, `make test`, advisory host build, feed rows check). A green run is not a release. The checklist template is `.github/pull_request_template.md`.
- After merge the owner builds, checks on a rig and publishes. You do nothing further.

## For AI agents

Do, in order, from the repository root:

1. `git switch -c port/<name>` (work in your own worktree or fork, never in another session's checkout).
2. `cp -r pkgs/tree pkgs/<name>`, or copy the closest sibling; edit `pkgs/<name>/recipe.mk`.
3. Download the archive and compute the hash: `make host-<name> JOBS=2` stops with `want` and `got` if `_SHA256` is wrong; take the value from the file, not from a web page.
4. Write `pkgs/<name>/check/cases` and `pkgs/<name>/check/data`.
5. `make host-<name> JOBS=2`, then `sh tools/recipe_lint.sh <name>`.
6. Commit by file name, imperative subject. Open the pull request with the fields listed above.

Never:

- Run `make <name>` (Amiga build), `make kit-stage`, `make dist` or start an emulator or rig; those are owner steps (`RULES.md` rule 4).
- Use more than 4 jobs (`JOBS=2` when the machine is busy).
- Commit binaries, archives, `build/` output, or a hash you did not compute.
- Name a CPU flag in a recipe, use `fork()`, or work around a libc gap inside a recipe.
- Upload to a feed, edit the vtcon repository, or publish a release.
- Guess a licence; read the source's licence file and quote it.
