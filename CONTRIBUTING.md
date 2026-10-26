# Contributing

A new tool is one recipe, `pkgs/<name>/recipe.mk`, plus check cases. The full guide, with a worked example and the pull request checklist, is `docs/adding-a-package.md`.

- The owner builds, checks on an Amiga and releases every package. A merged recipe runs on other people's machines, so it is read in full.
- Licences are judged case by case: say what the licence is and what it allows.
- Rules for every recipe: `RULES.md`.
- Before opening a pull request: `sh tools/recipe_lint.sh <name>` and `make host-<name>`.
- Not accepted yet: your own feeds, binary-only packages, packages that need a C library change (those go to `ixemul-vtcon` first).
