# FP4.4 perl 5.42.3 port notes

Result: perl builds (4.2 MB, hunk, ixemul, no `_fork`), passes check_bin, and
`userland_rig.py --only perl` passes 3 of 3 on rig 2 (print, subst, version).

## Route
perl-cross 1.6.5 overlaid on perl 5.42.3 (sha256 in pkgs/perl/recipe.mk).
It builds a host miniperl and configures the target without running target
programs. `-Ud_fork`: my_fork() never calls fork(), so `_fork` is not linked.
Backticks, piped open, fork() fail cleanly at run time. system() runs through
do_spawn/do_aspawn (patch 0001, libc system()).

## Measured quirks
- perl-cross has no patchset for 5.42.3: reuse the 5.42.0 diffs dir (copied).
- BSD sed has no `\s`: perl_COPY rewrites it to `[[:space:]]` in cnf/*.sh.
- No readelf on macOS (Mach-O host, hunk target): tools/macho-readelf.sh fakes
  `readelf --syms` for checksize from nm (nm reports a common symbol size as value).
- Byteorder cannot be probed: --host-set-byteorder=12345678, --set-byteorder=4321.
- d_nanosleep unset on non-Linux host: define for host, undef for target.
- `--with-libs=a,b` is split wrongly; use -Dlibs/-Dperllibs with the path to libixcompat.a.
- No locale support in SDK: -Ud_setlocale -Accflags=-DNO_LOCALE.
- No sys/times.h: -Ud_times (times() croaks).
- Disabled modules: Time-HiRes, DB_File, NDBM_File, Compress-Raw-Bzip2/Zlib (their
  Makefile.PL run target programs or need libs), ext/re (re_comp.o duplicates
  regcomp.o symbols at static link; `use re` unavailable, core regex works).
- Host build: perl-cross's `configure` and perl's `Configure` collide on the
  case-insensitive FS; the host tree is a plain copy of the source.
- install.perl only (install.man fails with man dirs none).
- Install tree is 26 MB under lib/perl5; the scripts need it at run time.

## Tool fix
m68k_scan.py: a switch table bounded by a register mask (moveq #7; andl) ran on
past its end and reported a false cinvl in sdbm _delpair. Mask now bounds the
table (fallback when no compare). Test added.

## Open
- Only the 3 cases tested; `use strict` / modules from lib/perl5 not tried on rig.
- scanned share of the code hunk by m68k_scan is 37 % (computed jumps), as for other ports.
