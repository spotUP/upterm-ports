# Lua 5.4.7 (vtcon plan 4.4), the standalone `lua` interpreter and `luac`, ixemul build:
# Unix paths (package.path under /UP-Term, see patches/) and io.popen / os.execute over
# ixemul's popen and system (vfork + /bin/sh = vsh). amiga-pi's vendor/lua-5.4 is a
# stripped copy for embedding (no io, os, package) and stays that; this is the full
# upstream source. LUA_USE_POSIX gives popen, mkstemp, flockfile-free getc; no dlopen
# (C modules are not loadable), no readline. The source builds with a plain compile and
# link here (its makefile has no install target that fits the prefix layout).
lua_VERSION   := 5.4.7
lua_SUMMARY   := Lua 5.4.7 interpreter (lua) and compiler (luac) in UP-Term:bin
lua_URL       := https://www.lua.org/ftp/lua-$(lua_VERSION).tar.gz
lua_SHA256    := 9fbf5e28ef86c69858f6d3d34eccc32e911c1a28b4120ff3e84aaa70cfbf1e30
lua_LICENSE   := MIT
lua_DEPS      := ixcompat
lua_BINS      := bin/lua bin/luac
# the parser and the garbage collector recurse (C stack limit LUAI_MAXCCALLS 200)
lua_STACK     := 262144
lua_STACK_VAR := 1
# ixemul libc gaps (to move to ixemul-vtcon): flockfile, funlockfile, getc_unlocked (no
# stdio locking: one thread).
LUA_GAPS := -D'flockfile(f)=((void)0)' -D'funlockfile(f)=((void)0)' -D'getc_unlocked(f)=getc(f)'
LUA_CORE := lapi lcode lctype ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser lstate lstring ltable ltm lundump lvm lzio \
	lauxlib lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib linit
lua_CONFIGURE_CMD = rsync -a --exclude .git $(lua_SRC)/ $(lua_OBJ)/
lua_BUILD_CMD = cd $(lua_OBJ)/src && for f in $(LUA_CORE) lua luac; do \
	$(ROOT)/tools/m68k-cc $(CPU) -O2 -DLUA_USE_POSIX $(LUA_GAPS) -I$(SYSINC) -c $$f.c -o $$f.o || exit 1; done && \
	$(ROOT)/tools/m68k-cc $(CPU) -o lua $(addsuffix .o,$(LUA_CORE)) lua.o -Wl,$(OBJ)/lua.stack.o $(SYSLIB)/libixcompat.a -lm && \
	$(ROOT)/tools/m68k-cc $(CPU) -o luac $(addsuffix .o,$(filter-out lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib linit,$(LUA_CORE))) luac.o \
	$(addsuffix .o,lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib) -Wl,$(OBJ)/lua.stack.o $(SYSLIB)/libixcompat.a -lm
lua_INSTALL_CMD = install -d $(SYSROOT)$(PREFIX)/bin $(SYSROOT)$(PREFIX)/share/man/man1 && \
	install -m 755 $(lua_OBJ)/src/lua $(lua_OBJ)/src/luac $(SYSROOT)$(PREFIX)/bin/ && \
	install -m 644 $(lua_SRC)/doc/lua.1 $(lua_SRC)/doc/luac.1 $(SYSROOT)$(PREFIX)/share/man/man1/
lua_HOST_CONFIGURE_CMD = rsync -a --exclude .git $(lua_SRC)/ $(lua_HOBJ)/
lua_HOST_BUILD_CMD = $(MAKE) -C $(lua_HOBJ)/src lua luac MYCFLAGS=-DLUA_USE_POSIX MYLIBS= && \
	mkdir -p $(lua_HOBJ)/inst/bin && cp $(lua_HOBJ)/src/lua $(lua_HOBJ)/src/luac $(lua_HOBJ)/inst/bin/
lua_LICENSE_FILES := doc/readme.html
