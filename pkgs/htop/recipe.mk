# htop 3.5.3: the process viewer, C and ncurses. Upstream has no AmigaOS platform: the build takes its
# `unsupported` platform (configure falls back to it for an unknown host) and patch 0001 fills it with the
# exec task lists (as vtcon proc/tasks_amiga.c does for ps/top) and AvailMem. No CPU percent (top owns the
# VBlank sampler), one CPU, no swap.
htop_VERSION   := 3.5.3
htop_URL       := https://github.com/htop-dev/htop/releases/download/$(htop_VERSION)/htop-$(htop_VERSION).tar.xz
htop_SHA256    := a8b164386494cb85bb255a415a3f5f80afe7a0c4491da5d113b3a0f951087e65
htop_LICENSE   := GPL-2.0-or-later
htop_LICENSE_FILES := COPYING
htop_DEPS      := ixcompat ncurses
htop_CONFIGURE := --with-curses=ncursesw --disable-unicode --disable-hwloc --disable-sensors --disable-capabilities --disable-delayacct
htop_ENV       = CPPFLAGS="-I$(SYSINC) -I$(SYSINC)/ncursesw" LIBS="-lncursesw -lm $(SYSLIB)/libixcompat.a" HTOP_NCURSESW_CONFIG_SCRIPT=false
htop_HOST_DEPS := ncurses
htop_BINS      := bin/htop
htop_STACK     := 262144
# started by vfork+exec (vsh, ptyrun), which ignore the $STACK: cookie: define __stack too
htop_STACK_VAR := 1
htop_LIBS      := -lncursesw
htop_CHECK_DEPS := grep sed
