# GNU gzip (vtcon plan 2.1). gunzip and zcat are shell scripts upstream;
# here they are copies of gzip, which picks its mode from its name (no links
# on AmigaOS, and no #! scripts from the AmigaDOS Shell).
gzip_VERSION   := 1.15
gzip_URL       := https://ftp.gnu.org/gnu/gzip/gzip-$(gzip_VERSION).tar.xz
gzip_SHA256    := 9aa0cc780dec156b8282844833b342ab7cb08c25d2cd9a1869cdd0df31deff48
gzip_LICENSE   := GPL-3.0-or-later
gzip_DEPS      := ixcompat
# ixemul's time_t is 32 bits, signed: --disable-year2038, as configure asks
gzip_CONFIGURE := --disable-nls --disable-threads --disable-year2038
gzip_HOST_CONFIGURE :=
gzip_BINS      := bin/gzip bin/gunzip bin/zcat
gzip_STACK     := 65536
gzip_POST_INSTALL = cp $(SYSROOT)$(PREFIX)/bin/gzip $(SYSROOT)$(PREFIX)/bin/gunzip && \
	cp $(SYSROOT)$(PREFIX)/bin/gzip $(SYSROOT)$(PREFIX)/bin/zcat
gzip_CHECK_DEPS := sed
