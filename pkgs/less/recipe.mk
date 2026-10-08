# less (vtcon plan 1.4): the pager, against ncursesw (0.8). less 710 builds
# no lesskey program (less reads a lesskey source file itself; lesskey.5 is
# installed). lessecho (libexec, for :e filename completion) is not shipped.
# `!cmd`, `|` and `v` go through ixemul's system/popen to /bin/sh (vsh).
less_VERSION   := 710
less_URL       := https://www.greenwoodsoftware.com/less/less-$(less_VERSION).tar.gz
less_SHA256    := d1008fb78dcae1323ddab664bcb352a61f022b1b131bd8018548e021d975ec7a
less_LICENSE   := GPL-3.0-or-later OR BSD-2-Clause (less licence)
less_DEPS      := ixcompat ncurses
# POSIX regcomp/regexec are ixemul's
less_CONFIGURE := --with-regex=posix
less_HOST_CONFIGURE := --with-regex=posix
less_LIBS      := -lncursesw
less_BINS      := bin/less
# provisional, grep's value: the regex code recurses
less_STACK     := 262144
less_LICENSE_FILES := COPYING LICENSE
