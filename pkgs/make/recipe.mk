# GNU make 4.4.1 (vtcon plan 5.5). Recipes run through /bin/sh (vsh on the Amiga);
# make 4.4 starts them with posix_spawn when the libc has it (libixcompat does),
# otherwise it forks, which check_bin refuses. No guile, no loadable objects.
make_VERSION   := 4.4.1
make_URL       := https://ftp.gnu.org/gnu/make/make-$(make_VERSION).tar.gz
make_SHA256    := dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
make_LICENSE   := GPL-3.0-or-later
make_DEPS      := ixcompat
# gnulib's getloadavg.c takes its BSD branch (ixemul defines BSD): nlist() and /dev/kmem with
# O_CLOEXEC, none of which ixemul has. LDAV_DONE switches the whole kernel lookup off; make -l
# then sees no load average (measured 2026-10-15, make 4.4.1).
# -O (output sync) needs record locks: ixemul has F_WRLCK only under RECORD_LOCKING_NOT_IMPLEMENTED,
# so NO_OUTPUT_SYNC; make -O then does nothing.
make_CONFIGURE := --disable-nls --without-guile --disable-load
make_ENV       := CPPFLAGS="-I$(SYSINC) -DLDAV_DONE -DNO_OUTPUT_SYNC"
make_HOST_CONFIGURE := --disable-nls --without-guile --disable-load
make_BINS      := bin/make
make_STACK     := 262144
make_STACK_VAR := 1
make_CHECK_DEPS := sed
