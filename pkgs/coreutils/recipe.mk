# GNU coreutils 9 (vtcon plan 3.7), replacing the kit's Geek Gadgets coreutils 5.2.1 (dist/gg/coreutils-5.2.1).
# Separate programs (AmigaOS has no symlinks for commands, so --enable-single-binary=symlinks cannot stand in).
coreutils_VERSION   := 9.12
coreutils_URL       := https://ftp.gnu.org/gnu/coreutils/coreutils-$(coreutils_VERSION).tar.xz
# verified against coreutils-9.12.tar.xz.sig with the GNU keyring (2026-10-11)
coreutils_SHA256    := a480198559733e9b3da999e90543ac6f888a2caa544d8d664c5a1f17e528e210
coreutils_LICENSE   := GPL-3.0-or-later
coreutils_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed: --disable-year2038; no ACLs, xattrs, SELinux, capabilities, GMP or OpenSSL
# on the Amiga; no stdbuf (an LD_PRELOAD library: AmigaOS has no shared objects; configure took the m68k
# linker's -shared for yes and libstdbuf.so failed on crt0's main)
coreutils_CONFIGURE := --disable-nls --disable-threads --disable-year2038 --disable-acl --disable-xattr \
                       --without-selinux --disable-libcap --without-gmp --without-openssl --disable-rpath \
                       --enable-no-install-program=stdbuf,who,pinky,timeout \
                       gl_cv_func_posix_spawnp_secure_exec=yes \
                       gl_cv_const_PTHREAD_MUTEX_RECURSIVE=no
# who and pinky are dropped: libixcompat lacks inet_pton, inet_ntop and gai_strerror (gnulib canon_host links them).
# timeout is dropped: it calls fork() itself (ixemul has vfork only).
# gnulib's cross guess for posix_spawnp_secure_exec is no, which swaps in its own spawni.c (links fork): yes keeps
# libixcompat's posix_spawn, as make does.
# config.site says no pthread.h, so gnulib's pthread.h wrapper stands alone but its probe still answered yes via
# libixcompat's stub header: =no makes the wrapper define PTHREAD_MUTEX_* for gnulib's pthread-mutex.c (measured 2026-10-16).
coreutils_HOST_CONFIGURE := --disable-nls --without-gmp --without-openssl
# provisional, grep's value: sort, du, ls and cp recurse or sort in memory
coreutils_STACK     := 262144
coreutils_STACK_VAR := 1
# every program the install step puts in bin/ (read from build/obj/coreutils/src after the build; ginstall installs as install)
coreutils_BINS      := bin/[ bin/b2sum bin/base32 bin/base64 bin/basename bin/basenc bin/cat bin/chgrp bin/chmod bin/chown bin/chroot bin/cksum bin/comm bin/cp bin/csplit bin/cut bin/date bin/dd bin/dir bin/dircolors bin/dirname bin/du bin/echo bin/env bin/expand bin/expr bin/factor bin/false bin/fmt bin/fold bin/install bin/groups bin/head bin/hostid bin/id bin/join bin/link bin/ln bin/logname bin/ls bin/md5sum bin/mkdir bin/mkfifo bin/mknod bin/mktemp bin/mv bin/nice bin/nl bin/nohup bin/nproc bin/numfmt bin/od bin/paste bin/pathchk bin/pr bin/printenv bin/printf bin/ptx bin/pwd bin/readlink bin/realpath bin/rm bin/rmdir bin/seq bin/sha1sum bin/sha224sum bin/sha256sum bin/sha384sum bin/sha512sum bin/shred bin/shuf bin/sleep bin/sort bin/split bin/stat bin/stty bin/sum bin/sync bin/tac bin/tail bin/tee bin/test bin/touch bin/tr bin/true bin/truncate bin/tsort bin/tty bin/uname bin/unexpand bin/uniq bin/unlink bin/users bin/vdir bin/wc bin/whoami bin/yes
