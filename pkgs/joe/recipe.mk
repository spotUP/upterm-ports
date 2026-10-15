# JOE 4.6 (vtcon plan 4.5): Joe's Own Editor, against ncursesw (0.8). Joe has
# its own termcap/terminfo reader (--enable-termcap is the default, it also
# links curses when asked); here the ncurses terminfo path is used so that
# TERM=vtcon resolves the same way as for nano and less.
joe_VERSION   := 4.6
joe_URL       := https://downloads.sourceforge.net/project/joe-editor/JOE%20sources/joe-$(joe_VERSION)/joe-$(joe_VERSION).tar.gz
joe_SHA256    := 495a0a61f26404070fe8a719d80406dc7f337623788e445b92a9f6de512ab9de
joe_LICENSE   := GPL-2.0-or-later
joe_LICENSE_FILES := COPYING
joe_DEPS      := ixcompat ncurses
# setpgrp: ixemul declares setpgrp(pid_t, pid_t) (sysroot include/unistd.h:183); a cross
# configure cannot run joe's test and guesses the void form, which does not compile.
# asinh, cbrt, erf, erfc: found in newlib's libm by configure, absent from
# ixemul's libc (link: undefined reference, 2026-10-15); joe's calculator
# guards each with HAVE_<name>, so those four functions are left out. The gap
# is ixemul-vtcon's (libm), not this recipe's.
joe_ENV       := joe_cv_setpgrp_void=no ac_cv_search_asinh=no ac_cv_search_cbrt=no ac_cv_search_erf=no ac_cv_search_erfc=no
joe_CONFIGURE := --disable-nls
joe_LIBS      := -lncursesw
# macOS declares openpty and login_tty in <util.h>, which joe does not include
joe_HOST_DEPS := ncurses
joe_HOST_CONFIGURE := --disable-nls \
	CPPFLAGS="-I$(HOST_NCURSES)/include -I$(HOST_NCURSES)/include/ncursesw -include util.h" LDFLAGS="-L$(HOST_NCURSES)/lib" LIBS="-lncursesw"
joe_BINS      := bin/joe
# provisional, nano's value
joe_STACK     := 262144
# util/ (termidx, stringify, uniproc, checkwidths) are maintainer tools that
# need a host compiler and are not used by the build (builtins.c, termcap.c and
# the unicode tables ship pre-generated), so only joe/, rc/, syntax/ and
# colors/ are built and installed.
# configure puts -lm on the link, which with -mcrt=ixemul finds newlib's libm
# (undefined _impure_ptr); ixemul's libc has the math functions itself (as for
# awk), so the link line is given without it.
joe_BUILD_CMD = $(MAKE) -C $(joe_OBJ)/joe joe LIBS="-lncursesw $(SYSLIB)/libixcompat.a" && $(MAKE) -C $(joe_OBJ)/rc && $(MAKE) -C $(joe_OBJ)/syntax && $(MAKE) -C $(joe_OBJ)/colors
joe_INSTALL_CMD = for d in joe rc syntax colors; do $(MAKE) -C $(joe_OBJ)/$$d install SUBDIRS= DESTDIR=$(SYSROOT) || exit 1; done
joe_HOST_BUILD_CMD = for d in joe rc syntax colors; do $(MAKE) -C $(joe_HOBJ)/$$d install SUBDIRS= || exit 1; done
joe_DATA := etc/joe share/joe
# the rig's terminal cases read the system joerc and ftyperc from UP-Term:etc/joe
joe_RIG_DATA := etc/joe/joerc etc/joe/ftyperc
# joe is started by ptyrun (vfork + exec), which ignores the cookie: measured on
# the rig, ptyrun joe hangs the machine on the default stack and passes with
# IXSTACK=262144; __stack makes the program ask for it itself.
joe_STACK_VAR := 1
