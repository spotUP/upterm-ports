# mutt: safe_open failure on ixemul, and the fgetwc shim

Probes: scratchpad/mutt2/sprobe.c and sprobe2.c (sprobe2 is mutt 2.2.16's safe_open,
safe_rename and mkwrapdir step by step with errno printed), built with the ports
toolchain (-mcrt=ixemul -m68060, libixcompat.a from build/sysroot), run on rig 5.

## Measured
- Full wrap-directory flow works for absolute paths: /tmp/mutt-x (mkdtemp, open O_EXCL,
  link, unlink, rmdir, open, lstat/fstat compare_stat all succeed), T:/x, RAM:T/x, DH0:t/x.
  st_dev/st_ino of lstat and fstat agree, so the compare_stat step is NOT the failing call.
- Bare relative target (no slash, e.g. "mutt-z"; mutt then uses parent "."):
  link(".muttXXXXXX/mutt-z", "mutt-z") returns -1 errno=5 (EIO).
  mutt's safe_rename falls back to rename() only for EXDEV, ENOSYS, EPERM, ENOTSUP,
  EOPNOTSUPP (lib.c:499), so EIO makes safe_rename return -1, safe_open fails, and the
  caller reports "Could not create temporary file!". rename() itself works there.
- On RAM: root (RAM:/x), link() succeeds but a later rename() of the same file returns
  EXDEV (errno 18); st_dev there is a negative pointer-like value (-3988).
- Not reproduced: the exact failing path of the original read-quit case was not
  recorded, so which path form mutt used is UNVERIFIED. The only failing call measured
  is link() -> EIO for a slash-less target.

## Layer
The fix belongs in ixemul-vtcon (compat link()): it must either implement a hard link
properly or fail with ENOSYS/EOPNOTSUPP (the errno every portable caller, mutt, git,
dpkg, treats as "no hard links, use rename"), never EIO. An EIO from link() is a
libc-level lie about an unsupported operation; patching mutt (patch 0002) hides it
for one program. Check also why link() succeeds on /tmp and RAM: but EIO for a cwd-relative
target (path resolution of the wrap dir against the process cwd). Patch 0002 can be
dropped once link() is fixed and a rig case runs mutt read-quit with a relative TMPDIR.

## fgetwc / ungetwc shim (mutt handler.c, patch 0001)
ixemul has no fgetwc/ungetwc; mutt's patch defines them byte-wide (C locale, ISO 8859-1).
Belongs in ixemul-vtcon compat (stdio wide-char stubs, byte-wide in the C locale), declared
in an ixemul header so configure checks see them.
Other ports whose source references fgetwc/getwc/ungetwc/fputwc (grep of build/src/*.c;
whether the code path is compiled in is UNVERIFIED): coreutils (2 files), findutils (2),
sed (2), gzip (1). None carries a patch for it today (grep pkgs/*/patches: mutt only), so
the gain is mainly removing mutt's patch and letting configure find the functions.
