# file 5.48 (vtcon plan 3.1): libmagic and file. The full magic compiles to
# 7-8 MB; the kit ships a trimmed one of 3.4 MB (file_MAGDIR: text and
# scripts, archives, images, audio, documents, executables and the Amiga
# entries; filesystems, windows, msdos, games, console, animation, pgp ...
# are out), compiled by the Mac build of the same version (a magic.mgc of
# another byte order is read by libmagic, byte-swapped). zlib, bzip2 and xz
# are built in: file -z needs no fork (compress.c's fork path is off, as
# config.site says fork is absent).
file_VERSION   := 5.48
file_URL       := https://astron.com/pub/file/file-$(file_VERSION).tar.gz
file_SHA256    := ed14656883b23a364b4057c05595d93252da9bc473d30106519519d0da141283
file_LICENSE   := BSD-2-Clause
file_LICENSE_FILES := COPYING
file_DEPS      := ixcompat zlib bzip2 xz
file_BINS      := bin/file
file_STACK     := 65536
file_MAGDIR    := amigaos iff riff audio images jpeg pbm archive compress commands c-lang elf aout \
	coff cafebabe pdf python perl ruby lua tcl java javascript sgml web mime mail.news make diff \
	ssh ssl uuencode zip tex troff rtf unicode fonts vorbis matroska ole2compounddocs msooxml \
	gimp sql magic terminfo tapebackup varied.out varied.script motorola mips pascal fortran \
	lisp subtitle
file_MANS      := share/man/man4/magic.4
file_CONFIGURE := --disable-shared --enable-static --disable-libseccomp --enable-zlib --enable-bzlib \
	--enable-xzlib --disable-zstdlib --disable-lzlib --disable-silent-rules
file_HOST_CONFIGURE := --disable-shared --enable-static --disable-libseccomp --enable-zlib \
	--enable-bzlib --disable-xzlib --disable-zstdlib --disable-lzlib
file_ENV := CONFIG_SITE="$(ROOT)/mk/config.site $(ROOT)/pkgs/file/config.site"
file_BUILD_CMD = $(MAKE) -C $(file_OBJ)/src magic.h && $(MAKE) -C $(file_OBJ)/src -j$(JOBS) file && $(MAKE) -C $(file_OBJ)/doc file.1 magic.4
# the trimmed magic, compiled by the host's file; $(1) is the object tree
define file_MAGIC
rm -rf $(1)/trim && mkdir -p $(1)/trim/magic.d && \
	for f in $(file_MAGDIR); do cp $(file_SRC)/magic/Magdir/$$f $(1)/trim/magic.d/; done && \
	cd $(1)/trim && $(HOSTB)/file/inst/bin/file -C -m magic.d > compile.log 2>&1 && mv magic.d.mgc magic.mgc
endef
file_INSTALL_CMD = $(call file_MAGIC,$(file_OBJ)) && \
	install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/misc $(SYSROOT)$(PREFIX)/share/man/man1 \
	  $(SYSROOT)$(PREFIX)/share/man/man4 && \
	install -m 755 $(file_OBJ)/src/file $(SYSROOT)$(PREFIX)/bin/file && \
	install -m 644 $(file_OBJ)/trim/magic.mgc $(SYSROOT)$(PREFIX)/share/misc/magic.mgc && \
	install -m 644 $(file_OBJ)/doc/file.1 $(SYSROOT)$(PREFIX)/share/man/man1/file.1 && \
	install -m 644 $(file_OBJ)/doc/magic.4 $(SYSROOT)$(PREFIX)/share/man/man4/magic.4
file_HOST_BUILD_CMD = $(MAKE) -C $(file_HOBJ)/src magic.h && $(MAKE) -C $(file_HOBJ)/src -j$(JOBS) file && mkdir -p $(file_HOBJ)/inst/bin $(file_HOBJ)/inst/share/misc && \
	cp $(file_HOBJ)/src/file $(file_HOBJ)/inst/bin/file && $(call file_MAGIC,$(file_HOBJ)) && \
	cp $(file_HOBJ)/trim/magic.mgc $(file_HOBJ)/inst/share/misc/magic.mgc
file_RIG_DATA := share/misc/magic.mgc
file_CHECK_DEPS := sed
file_DATA := share/misc/magic.mgc
