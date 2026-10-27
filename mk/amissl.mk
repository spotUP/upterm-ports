# AmiSSL 5.27 for ports that do TLS (curl; lynx, mutt, git follow). AmiSSL is
# bsdsocket.library-direct: the port compiles its socket calls against the NDK
# netinclude (the inline stubs of <proto/bsdsocket.h>) while the rest stays ixemul libc,
# so it needs a running TCP/IP stack and AmiSSL on the Amiga (the base kit installs AmiSSL).
#
# The header clash: NDK <proto/bsdsocket.h> includes <sys/mbuf.h>, <netinet/in.h> and
# the like, and gcc searches ixemul's include drawer, a system drawer, before any -I of
# the NDK's (a -I of a system drawer is dropped), so ixemul's sys/mbuf.h and
# sys/socket.h meet the NDK's structs ("MSIZE undeclared"). An overlay drawer of
# symlinks to the NDK's sys/mbuf.h, sys/socket.h, sys/sockio.h, net/, netinet/, arpa/
# and netdb.h is no system drawer, so -I puts it first. mk/amiga-net.h (forced in) adds
# the __uint32_t the NDK's in.h wants.
#
# Use in a recipe's configure command:
#   $(call AMISSL_OVERLAY,<pkg>) && $(call M68K_ENV,<pkg>) CFLAGS="$(CPU) -O2 $(call AMISSL_CFLAGS,<pkg>)" CPPFLAGS="-I$(SYSINC) $(call AMISSL_CPPFLAGS,<pkg>)" \
#     LDFLAGS="... $(AMISSL_LDFLAGS)" ...
AMISSL_SDK  ?= $(VTCON)/vendor/amissl-5.27/AmiSSL/Developer
NDK_NETINC  ?= $(AMIGA)/m68k-amigaos/ndk-include
AMISSL_LDFLAGS := -L$(AMISSL_SDK)/lib/AmigaOS3
# curl's configure (CURL_CONVERT_INCLUDE_TO_ISYSTEM) rewrites every word starting with -I in CFLAGS and
# CPPFLAGS to -isystem, and an -isystem drawer loses to the toolchain's ixemul drawer (measured: api.c
# fails with MSIZE undeclared). --include-directory= is gcc's long spelling of -I and escapes the rewrite.
AMISSL_CFLAGS = --include-directory=$(OBJ)/$(1)/netinc
AMISSL_CPPFLAGS = -I$(AMISSL_SDK)/include -include $(ROOT)/mk/amiga-net.h
AMISSL_OVERLAY = rm -rf $(OBJ)/$(1)/netinc && mkdir -p $(OBJ)/$(1)/netinc/sys && \
	for f in mbuf socket sockio; do ln -s $(NDK_NETINC)/sys/$$f.h $(OBJ)/$(1)/netinc/sys/$$f.h; done && \
	for d in net netinet arpa; do ln -s $(NDK_NETINC)/$$d $(OBJ)/$(1)/netinc/$$d; done && \
	ln -s $(NDK_NETINC)/netdb.h $(OBJ)/$(1)/netinc/netdb.h
