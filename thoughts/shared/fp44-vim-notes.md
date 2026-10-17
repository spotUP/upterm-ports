# FP4.4 part 1: vim 9.2.1202 port notes

Branch feature/fp44-vim. Recipe pkgs/vim/recipe.mk, patch 0001 (os_unixx.h), checks edit and new
(pkgs/vim/check/tty + keys). Rig 2 result: `vim: PASS, 2 of 2 cases pass` (edit: append text, insert,
:wq, file byte-equal to the Mac build; screens match at every key step).

Measured answers (each from a build failure):
- gcc predefines AMIGA -> vim picks its native Amiga port (arp.library): -UAMIGA.
- configure takes uname for Darwin: vim_cv_uname_output=AmigaOS (else -DMACOS_X).
- fork linked by check_bin: -DUSE_SYSTEM (feature.h); that path needs sys/wait.h (patch 0001).
- tarball is GitHub's tag archive (no upstream checksum); sha256 computed 2026-10-17.

Open:
- xxd not built/installed: it needs stpcpy, missing from ixemul/libixcompat (a libc gap; fix in ixemul-vtcon).
- :help not shipped (doc/ pruned, 11 MB); runtime is 16 MB under share/vim/vim92.
- Shell commands (:!cmd) go through system(); not exercised on the rig.
- Checks run with -u NONE, so the runtime files (syntax, defaults.vim) are not exercised on the rig.
- Stack: 262144 provisional (joe's); no crash seen, no smaller value measured.
