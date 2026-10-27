# curl for upkg downloads, built from source so it needs no usergroup.library.
# The Aminet curl (vtcon dist/net/curl-8.22.0) links libnet, whose startup opens
# usergroup.library from an AmiTCP drawer. This one is boingball's AmigaOS branch
# (github.com/boingball/curl, branch amigaos) at commit 8347cfe8, built with ixemul like
# every other port (pkgs/nc does the same): its sockets are ixemul's ixnet, which opens
# usergroup.library only when present and runs on Roadshow without it. curl is built on
# the plain libc socket path: HAVE_PROTO_BSDSOCKET_H stays undefined (configure's probe
# of <proto/bsdsocket.h> is made to fail by the toolchain NDK header), so lib/amigaos.c
# compiles empty and no Roadshow header is used. ixemul's sys/socket.h needs sys/types.h
# first, hence -include sys/types.h. No pthreads (ixemul has none; configure has no switch, so
# the cache variables are preset): the mutex code would need a timespec that ixemul's
# devices/timer.h macros break. No stdatomic either: libgcc for m68k has no __atomic_exchange_4. No TLS: no port ships a TLS library
# yet, so https:// is not available (the upkg feeds are http).
curl_VERSION   := amigaos-8347cfe8
curl_COMMIT    := 8347cfe80bc1af8a27fef889fa7a8c5071038620
curl_URL       := https://github.com/boingball/curl/archive/$(curl_COMMIT).tar.gz
curl_SHA256    := f9080683b1fc684dae6940661f6156676b8c9cc848a7dcfb28e46a049b5ed7c0
curl_LICENSE   := curl
curl_DEPS      := ixcompat zlib
curl_BINS      := bin/curl
curl_STACK     := 262144
curl_STACK_VAR := 1
# configure is not in the git tree: copy the source, run autoreconf in the copy (the
# upstream tree stays clean for make curl-patches), then configure out of tree.
curl_CONFIGURE_CMD = rsync -a --exclude .git $(curl_SRC)/ $(curl_OBJ)/src/ && \
	cd $(curl_OBJ)/src && LIBTOOLIZE=glibtoolize autoreconf -fi && mkdir -p $(curl_OBJ)/b && cd $(curl_OBJ)/b && \
	$(call M68K_ENV,curl) CPPFLAGS="-I$(SYSINC) -include sys/types.h" \
	$(curl_OBJ)/src/configure --host=m68k-amigaos --prefix=$(PREFIX) --disable-shared --enable-static \
	--disable-docs --disable-manual --disable-ipv6 --disable-threaded-resolver --disable-netrc \
	--disable-ldap --disable-ldaps --disable-rtsp --disable-dict --disable-telnet --disable-tftp \
	--disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-mqtt --disable-ntlm \
	--disable-unix-sockets --disable-ares ac_cv_header_pthread_h=no ac_cv_func_pthread_create=no ac_cv_header_stdatomic_h=no --without-ssl --without-libpsl --without-libidn2 \
	--without-brotli --without-zstd --without-nghttp2 --without-libssh2 --with-zlib=$(SYSROOT)$(PREFIX)
curl_BUILD_CMD = $(MAKE) -C $(curl_OBJ)/b -j$(JOBS)
curl_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin && install -m 755 $(curl_OBJ)/b/src/curl $(SYSROOT)$(PREFIX)/bin/curl
curl_LICENSE_FILES := COPYING
curl_HOST_CONFIGURE_CMD = mkdir -p $(curl_HOBJ)
curl_HOST_BUILD_CMD = mkdir -p $(curl_HOBJ)/inst/bin
