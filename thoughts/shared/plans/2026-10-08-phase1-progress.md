---
date: 2026-10-08
topic: Unix tool ports, phase 1 items 1.2 onward, progress ledger
tags: [plan, progress, ports, sed, awk, less, ixemul, vsh, quoting]
status: draft
---

# Phase 1 progress (from 1.2)

Plan: vtcon `thoughts/shared/plans/2026-10-04-unix-tool-ports.md` (checklist 53 items, 12 ticked
at the start of this run). Rig: rig 3 only (`UPTERM_RIG=3`, build/rig3, port 7848, `--max`).
rig 3's `VTC:ixp6/ixemul.library` is the ixemul-vtcon build295 library of the commit named
below (rig 1's 08:36 copy kept as `build/rig3/ixemul.library.0836`).

Done per tool (caller's definition): in the kit's `SYS:UP-Term/bin`, reached through vsh's
`$PATH`, rig check passes, man page, licence met. The kit step is item 1.10, so a tool is
ticked in the plan only once 1.10 installs it.

## Items

| ID | State | Evidence |
|---|---|---|
| 1.2 sed 4.10 | built, rig 17 of 17, man page sed.1; waits for 1.10 | ports 611d360 (+ patch 0001 VOL:name -i) |
| 1.3 awk 20260426 | built, rig 14 of 17; blocked on the quoting decision Q1; man page awk.1 | ports d0a6da1, 697c3ed; ixemul-vtcon 03d9a2f (atan2), fcc2c7b (system), 511c224 (execve quoting) |
| 1.4 less 710 | next | |

## Decisions (not to re-litigate)

- Versions: sed 4.10, onetrue-awk 20260426 (repo is github.com/onetrueawk/awk, no hyphen), less 710.
- `<p>_HOST_CONFIGURE_CMD` / `<p>_HOST_BUILD_CMD` in mk/common.mk for packages without configure.
- awk links itself (the makefile's -lm finds newlib's libm); ixemul's libc has the math.
- In-place sed cases run in RAM:, not VTC: (FS-UAE host drawer caches names the runner deleted
  from the Mac: `Rename u.txt u.txt.bak` says "object already exists" after a rerun).

## Open for the owner

- **Q1 quoting, vsh -> ixemul program.** vsh writes an AmigaDOS command line (`*"`, `**` inside
  quotes); ixemul's `_cli_parse.c` reads backslash escapes and takes `*` literally. So
  `awk "BEGIN { print \"x\" }"` breaks and `"x * 2"` arrives as `x ** 2` (rig 3 argv probe).
  Options: (a) vsh detects an ixemul program (the `ixemul.library` string in its seglist) and
  writes ixemul's escapes for it; (b) ixemul's parser also reads `*"`/`**` inside quotes (an
  AmigaShell user typing `"foo.*"` then breaks). Recommended: (a).

## Gotchas

- ixemul system() ran `execve("sh")` (no path search): rc 127 always. Fixed fcc2c7b.
- ixemul execve wrote backslash escapes for native programs (vsh): fixed 511c224.
