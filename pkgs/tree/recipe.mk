# tree (vtcon plan 3.2): the directory lister (Steve Baker's tree, the
# Old-Man-Programmer fork). Plain Makefile, no configure.
tree_VERSION   := 2.2.1
tree_URL       := https://gitlab.com/OldManProgrammer/unix-tree/-/archive/$(tree_VERSION)/unix-tree-$(tree_VERSION).tar.gz
tree_ARCHIVE   := $(DL)/tree-$(tree_VERSION).tar.gz
tree_SHA256    := 70d9c6fc7c5f4cb1f7560b43e2785194594b9b8f6855ab53376f6bd88667ee04
tree_LICENSE   := GPL-2.0-or-later
tree_LICENSE_FILES := LICENSE
tree_DEPS      := ixcompat
tree_BINS      := bin/tree
tree_STACK     := 65536
tree_CONFIGURE_CMD = rsync -a --exclude .git $(tree_SRC)/ $(tree_OBJ)/
# the Makefile links $(LDFLAGS) before the objects: libixcompat goes in as the last of OBJS
tree_BUILD_CMD = $(MAKE) -C $(tree_OBJ) tree CC="$(ROOT)/tools/m68k-cc" LDFLAGS="-Wl,$(OBJ)/tree.stack.o" \
	CFLAGS="$(CPU) -O2 -I$(SYSINC)" OBJS="tree.o list.o hash.o color.o file.o filter.o info.o unix.o xml.o json.o html.o strverscmp.o $(SYSLIB)/libixcompat.a"
tree_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(tree_OBJ)/tree $(SYSROOT)$(PREFIX)/bin/tree && \
	install -m 644 $(tree_SRC)/doc/tree.1 $(SYSROOT)$(PREFIX)/share/man/man1/tree.1
tree_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(tree_SRC)/ $(tree_HOBJ)/
tree_HOST_BUILD_CMD = $(MAKE) -C $(tree_HOBJ) tree CFLAGS="-O2" LDFLAGS= && mkdir -p $(tree_HOBJ)/inst/bin && \
	cp $(tree_HOBJ)/tree $(tree_HOBJ)/inst/bin/tree
