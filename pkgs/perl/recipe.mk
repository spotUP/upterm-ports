# Perl 5.42.3 (vtcon plan 5.8): the perl interpreter, ixemul build, no threads, no dynamic
# loading (-Uusedl), XS modules linked statically (--all-static). Cross build by perl-cross
# 1.6.5 (arsv/perl-cross), which is overlaid on the perl source tree: it builds a host
# miniperl, then configures and builds the target without running target programs.
# Upstream's own Configure cannot cross-compile; its hints/amigaos.sh is AmigaOS 4 only.
# fork: d_fork=undef, so perl's pp_fork croaks and my_fork() never calls fork(), which
# keeps `_fork` out of the link (check_bin); system() goes to libc system (posix_spawn).
perl_VERSION   := 5.42.3
perl_URL       := https://www.cpan.org/src/5.0/perl-$(perl_VERSION).tar.gz
perl_ARCHIVE   := $(DL)/perl-$(perl_VERSION).tar.gz
perl_SHA256    := 1137740985837b5cdf15f0cfab932279dcb4352f912fed6fc144e8b4f0823627
perl_LICENSE   := Artistic-1.0-Perl OR GPL-1.0-or-later
perl_LICENSE_FILES := README Copying Artistic
perl_DEPS      := ixcompat
perl_CROSS_VER := 1.6.5
perl_CROSS_URL := https://github.com/arsv/perl-cross/releases/download/$(perl_CROSS_VER)/perl-cross-$(perl_CROSS_VER).tar.gz
perl_CROSS_SHA := 81130cd4b8c6d9eb2a1959f37d44391a46ad6a6794fc41fed5441f74e85e3dd0
perl_CROSS_ARC := $(DL)/perl-cross-$(perl_CROSS_VER).tar.gz
# perl-cross 1.6.5 on macOS: BSD sed has no \s (the version probe and the module list fail), and its patchset is
# 5.42.0, the newest it carries (the 5.42.x releases are bug fixes).
# the perl tree plus perl-cross on top, built in place (copy of the source)
perl_COPY = $(ROOT)/tools/fetch.sh $(perl_CROSS_URL) $(perl_CROSS_SHA) $(perl_CROSS_ARC) && \
	(cd $(perl_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(1) && \
	chmod -R u+w $(1) && tar xzf $(perl_CROSS_ARC) -C $(1) --strip-components 1 && \
	for f in $(1)/cnf/*.sh; do sed -e 's/\\s/[[:space:]]/g' $$f > $$f.tmp && mv $$f.tmp $$f; done && \
	cp -R $(1)/cnf/diffs/perl5-5.42.0 $(1)/cnf/diffs/perl5-$(perl_VERSION)
perl_CONFIGURE_CMD = $(call perl_COPY,$(perl_OBJ)) && cd $(perl_OBJ) && HOSTREADELF=$(ROOT)/tools/macho-readelf.sh READELF=$(ROOT)/tools/macho-readelf.sh UPTERM_NM=$(CROSS)nm \
	CFLAGS="$(CPU) -O2 -I$(SYSINC)" LDFLAGS="-L$(SYSLIB)$(if $(perl_STACK), -Wl$(comma)$(OBJ)/perl.stack.o)" \
	./configure --build=$(BUILD_TRIPLE) --target=m68k-amigaos --target-tools-prefix=$(CROSS) \
	--with-cc="$(ROOT)/tools/m68k-cc" --with-cpp="$(ROOT)/tools/m68k-cc -E" \
	-Dlibs="$(SYSLIB)/libixcompat.a -lm" -Dperllibs="$(SYSLIB)/libixcompat.a -lm" --prefix=$(PREFIX) --all-static --disable-mod=dist/Time-HiRes,ext/re,cpan/DB_File,ext/NDBM_File,cpan/Compress-Raw-Bzip2,cpan/Compress-Raw-Zlib --host-set-d_nanosleep=define --set-d_nanosleep=undef --host-set-byteorder=12345678 --set-byteorder=4321 \
	-Uusedl -Uusethreads -Ud_setlocale -Accflags=-DNO_LOCALE -Ud_fork -Ud_times -Dosname=amigaos -Ud_flock \
	-Doptimize=-O2 -Dman1dir=none -Dman3dir=none -Dusenm=false
perl_BUILD_CMD = $(MAKE) -C $(perl_OBJ) -j$(JOBS) perl
perl_INSTALL_CMD = $(MAKE) -C $(perl_OBJ) install.perl DESTDIR=$(SYSROOT)
perl_HOST_CONFIGURE_CMD = (cd $(perl_SRC) && tar cf - --exclude=.git .) | tar xf - -C $(perl_HOBJ) && chmod -R u+w $(perl_HOBJ) && cd $(perl_HOBJ) && \
	./Configure -des -Dprefix=$(perl_HOBJ)/inst -Uusethreads -Uusedl -Dman1dir=none -Dman3dir=none
perl_HOST_BUILD_CMD = $(MAKE) -C $(perl_HOBJ) -j$(JOBS) install
perl_BINS      := bin/perl
# the regex engine and the parser recurse deeply; provisional, joe's value
perl_STACK     := 262144
perl_STACK_VAR := 1
