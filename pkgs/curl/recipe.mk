# curl for upkg downloads, built from source so it needs no usergroup.library.
# The Aminet curl (vtcon dist/net/curl-8.22.0) links libnet, whose startup opens
# usergroup.library from an AmiTCP drawer. This one is boingball's AmigaOS branch
# (github.com/boingball/curl, branch amigaos) at commit 8347cfe8, built with ixemul
# like every other port, and its network calls go to bsdsocket.library directly
# (lib/amigaos.c, HAVE_PROTO_BSDSOCKET_H): any stack that provides that library works
# (Roadshow on real machines, the emulator's host-side bsdsocket in FS-UAE). The
# proto/ and inline/ headers come from Roadshow's netinclude (vtcon
# third_party/roadshow-netinclude): only its Amiga library headers (proto, inline, clib,
# libraries, bsdsocket) are linked into $(curl_OBJ)/rsinc and searched first, because the
# toolchain's NDK has its own proto/bsdsocket.h that breaks on ixemul's sys/socket.h;
# Roadshow's sys/mbuf.h and net/route.h are linked too (libraries/bsdsocket.h includes them); its other sys/, netdb.h and arpa/ stay out, so ixemul's own stay in force. No TLS: no port ships
# a TLS library yet, so https:// is not available (the upkg feeds are http).
curl_VERSION   := amigaos-8347cfe8
curl_COMMIT    := 8347cfe80bc1af8a27fef889fa7a8c5071038620
curl_URL       := https://github.com/boingball/curl/archive/$(curl_COMMIT).tar.gz
curl_SHA256    := f9080683b1fc684dae6940661f6156676b8c9cc848a7dcfb28e46a049b5ed7c0
curl_LICENSE   := curl
curl_DEPS      := ixcompat zlib
curl_BINS      := bin/curl
curl_STACK     := 262144
curl_STACK_VAR := 1
curl_ROADSHOW  ?= $(HOME)/Code/UP-Term/vtcon/third_party/roadshow-netinclude
# configure is not in the git tree: copy the source, run autoreconf in the copy (the
# upstream tree stays clean for make curl-patches), then configure out of tree.
curl_CONFIGURE_CMD = mkdir -p $(curl_OBJ)/rsinc && for d in proto inline clib libraries bsdsocket; do ln -sfn $(curl_ROADSHOW)/$$d $(curl_OBJ)/rsinc/$$d; done && mkdir -p $(curl_OBJ)/rsinc/sys $(curl_OBJ)/rsinc/net && ln -sfn $(curl_ROADSHOW)/sys/mbuf.h $(curl_OBJ)/rsinc/sys/mbuf.h && ln -sfn $(curl_ROADSHOW)/net/route.h $(curl_OBJ)/rsinc/net/route.h && \
	rsync -a --exclude .git $(curl_SRC)/ $(curl_OBJ)/src/ && \
	cd $(curl_OBJ)/src && LIBTOOLIZE=glibtoolize autoreconf -fi && mkdir -p $(curl_OBJ)/b && cd $(curl_OBJ)/b && \
	$(call M68K_ENV,curl) CPPFLAGS="-I$(curl_OBJ)/rsinc -I$(SYSINC) -include sys/types.h -D_SYS_MBUF_H -DHAVE_PROTO_BSDSOCKET_H=1" \
	$(curl_OBJ)/src/configure --host=m68k-amigaos --prefix=$(PREFIX) --disable-shared --enable-static \
	--disable-docs --disable-manual --disable-ipv6 --disable-threaded-resolver --disable-netrc \
	--disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp \
	--disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-ntlm \
	--disable-unix-sockets --disable-ares --without-ssl --without-libpsl --without-libidn2 \
	--without-brotli --without-zstd --without-nghttp2 --without-libssh2 --with-zlib=$(SYSROOT)$(PREFIX)
curl_BUILD_CMD = $(MAKE) -C $(curl_OBJ)/b -j$(JOBS)
curl_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin && install -m 755 $(curl_OBJ)/b/src/curl $(SYSROOT)$(PREFIX)/bin/curl
curl_LICENSE_FILES := COPYING
curl_HOST_CONFIGURE_CMD = mkdir -p $(curl_HOBJ)
curl_HOST_BUILD_CMD = mkdir -p $(curl_HOBJ)/inst/bin
