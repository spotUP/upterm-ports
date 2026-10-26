## Package

Name and version:
Upstream URL:

## Licence (the owner judges each package case by case)

- Licence name (SPDX):
- Link to the licence text, or the file in the source:
- What it says about redistributing the compiled program and the source:

## Checklist

- [ ] `pkgs/<name>/recipe.mk` has version, URL, sha256, licence, licence files, programs and stack
- [ ] The sha256 is from the archive I downloaded myself
- [ ] `_LICENSE` and `_LICENSE_FILES` are set and match the text linked above
- [ ] `pkgs/<name>/check/cases` and `check/data` exist and cover the options people use
- [ ] The last lines of `make host-<name>` are pasted below
- [ ] `sh tools/recipe_lint.sh <name>` is ok
- [ ] Feed package only: `_FEED_ID`, `_SUMMARY` set, and `pkg_rows.py check <name>` is clean
- [ ] No binaries, archives or build output are committed
- [ ] Patches (if any) are `git format-patch` files and the install steps contain no fork

## Host build output

```
```
