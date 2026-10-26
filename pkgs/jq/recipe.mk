# jq 1.7.1 (vtcon plan 4.7), oniguruma off (no regex filters: test, match,
# sub; the plan row's choice). Only the jq program and its page are installed
# (the tarball's libjq and jq.h stay out of the sysroot).
jq_VERSION   := 1.7.1
jq_SUMMARY   := jq 1.7.1 JSON processor (no regex filters) in UP-Term:bin
jq_URL       := https://github.com/jqlang/jq/releases/download/jq-$(jq_VERSION)/jq-$(jq_VERSION).tar.gz
jq_SHA256    := 478c9ca129fd2e3443fe27314b455e211e0d8c60bc8ff7df703873deeee580c2
jq_LICENSE   := MIT
jq_LICENSE_FILES := COPYING
jq_DEPS      := ixcompat
jq_COMMON_CONFIGURE := --without-oniguruma --disable-docs --disable-maintainer-mode --disable-valgrind
# Built in a copy of the tree without .git: jq's scripts/version would take
# the version from git ("main-<commit>" in our patched tree) instead of 1.7.1.
jq_CONFIGURE_CMD = rsync -a --exclude .git $(jq_SRC)/ $(jq_OBJ)/ && cd $(jq_OBJ) && $(call M68K_ENV,jq) \
	./configure --build=$(BUILD_TRIPLE) --host=m68k-amigaos --prefix=$(PREFIX) --disable-shared --enable-static $(jq_COMMON_CONFIGURE)
jq_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(jq_SRC)/ $(jq_HOBJ)/ && cd $(jq_HOBJ) && \
	./configure --prefix=$(jq_HOBJ)/inst $(jq_COMMON_CONFIGURE)
jq_BINS      := bin/jq
# make jq alone skips automake BUILT_SOURCES (src/builtin.inc), so they are made first
jq_BUILT     := src/builtin.inc src/config_opts.inc src/version.h
jq_STACK     := 262144
jq_CHECK_DEPS := sed
jq_BUILD_CMD = $(MAKE) -C $(jq_OBJ) $(jq_BUILT) && $(MAKE) -C $(jq_OBJ) -j$(JOBS) jq
jq_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(jq_OBJ)/jq $(SYSROOT)$(PREFIX)/bin/jq && \
	install -m 644 $(jq_OBJ)/jq.1.prebuilt $(SYSROOT)$(PREFIX)/share/man/man1/jq.1
jq_HOST_BUILD_CMD = $(MAKE) -C $(jq_HOBJ) $(jq_BUILT) && $(MAKE) -C $(jq_HOBJ) -j$(JOBS) jq && mkdir -p $(jq_HOBJ)/inst/bin && cp $(jq_HOBJ)/jq $(jq_HOBJ)/inst/bin/jq
