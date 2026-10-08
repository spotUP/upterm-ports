# libixcompat.a and the SDK headers ixemul-vtcon changed, from the sibling
# checkout (no download): the libc functions ixemul.library 48.2 has no
# vectors for (poll, posix_spawn, the wide-character layer, ...). Built by
# ixemul-vtcon's own compat/Makefile, against the headers overlaid here,
# so the toolchain's SDK is never modified. wcwidth comes from vtcon's
# engine/vtwidth.h (VTCON), the table the terminal itself uses.
ixcompat_LOCAL   := 1
ixcompat_VERSION  = $(shell git -C $(IXEMUL) describe --always --dirty 2>/dev/null)
ixcompat_URL     := $(IXEMUL)
ixcompat_LICENSE := BSD (ixemul-vtcon compat/)
ixcompat_BINS    :=
IXC_DEPS := $(wildcard $(IXEMUL)/compat/*.c $(IXEMUL)/compat/Makefile \
	$(IXEMUL)/include/*.h $(IXEMUL)/include/sys/*.h $(IXEMUL)/include/machine/*.h \
	$(VTCON)/engine/vtwidth.h)

.PHONY: ixcompat clean-ixcompat
ixcompat: $(STATE)/ixcompat.installed
$(STATE)/ixcompat.installed: $(IXC_DEPS) pkgs/ixcompat/recipe.mk
	@mkdir -p $(STATE) $(SYSINC) $(SYSLIB)
	SDK=$(SYSINC) sh $(IXEMUL)/docker/install-sdk-headers.sh > /dev/null
	$(MAKE) -C $(IXEMUL)/compat libixcompat.a CPPFLAGS="-I$(SYSINC)" VTCON=$(VTCON) > /dev/null
	cp $(IXEMUL)/compat/libixcompat.a $(SYSLIB)/libixcompat.a
	@touch $@
clean-ixcompat:
	rm -f $(STATE)/ixcompat.installed $(SYSLIB)/libixcompat.a
