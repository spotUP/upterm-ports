# nc (vtcon plan 5.1): OpenBSD's netcat (usr.bin/nc, ISC/BSD), vendored unchanged in
# pkgs/nc/src. The libc and header gaps are filled in pkgs/nc/compat, none of it in
# the OpenBSD source: amiga_nc.h (constants, socket/accept4 flags), strtonum.c (host build only;
# libixcompat has it for Amiga), nc_support.c
# (arc4random_uniform, b64_ntop), tls_stub.c (no libtls: option -c exits with one
# message). No IPv6 and no routing tables on this network stack, so -6, -V fail.
# pledge() and unveil() are no-ops. Source, OpenBSD master 2026-10-15:
#   https://github.com/openbsd/src/tree/master/usr.bin/nc
nc_OWN       := 1
nc_VERSION   := openbsd-master
nc_LICENSE   := ISC
nc_DEPS      := ixcompat
nc_BINS      := bin/nc
nc_STACK     := 65536
nc_CSRC      = $(nc_SRC)/netcat.c $(nc_SRC)/atomicio.c $(nc_SRC)/socks.c
nc_COMPAT    = $(ROOT)/pkgs/nc/compat
nc_CONFIGURE_CMD = mkdir -p $(nc_OBJ)
nc_BUILD_CMD = $(ROOT)/tools/m68k-cc $(CPU) -O2 -Wall -w -I$(SYSINC) -I$(nc_COMPAT) -I$(nc_SRC) \
	-include $(nc_COMPAT)/amiga_nc.h -D"pledge(a,b)=0" -D"unveil(a,b)=0" -o $(nc_OBJ)/nc \
	$(nc_CSRC) $(nc_COMPAT)/tls_stub.c $(nc_COMPAT)/nc_support.c \
	-Wl,$(OBJ)/nc.stack.o $(SYSLIB)/libixcompat.a
nc_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(nc_OBJ)/nc $(SYSROOT)$(PREFIX)/bin/nc && \
	install -m 644 $(nc_SRC)/nc.1 $(SYSROOT)$(PREFIX)/share/man/man1/nc.1
nc_HOST_CONFIGURE_CMD = mkdir -p $(nc_HOBJ)
nc_HOST_BUILD_CMD = cc -O2 -w -include $(nc_COMPAT)/host_compat.h -I$(nc_COMPAT) -I$(nc_SRC) -o $(nc_HOBJ)/nc \
	$(nc_CSRC) $(nc_COMPAT)/strtonum.c $(nc_COMPAT)/tls_stub.c -lresolv && mkdir -p $(nc_HOBJ)/inst/bin && \
	cp $(nc_HOBJ)/nc $(nc_HOBJ)/inst/bin/nc
