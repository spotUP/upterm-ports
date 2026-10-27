# opkg 0.9.0 (vtcon plan P10.2): the Yocto package manager, the base of upkg.
# First CMake package in the framework (opkg_CMAKE: mk/amiga-ixemul.cmake).
# P10.3 (patches/0001): the wget download backend runs `curl -fsSL -o`, the
# binary is `upkg` (GPL-2.0 rebrand: notices kept, changed files marked, the
# version line says "based on opkg"), the config is /UP-Term/etc/upkg.conf and
# state lives under /UP-Term/pkg/upkg (ixemul maps /UP-Term to UP-Term:).
# Staged into the kit as UP-Term/bin/upkg (P10.5-1); it replaced the vsh script of that name.
# No libcurl (downloads exec the curl of the base), no gpgme, no libsolv (internal solver), sha256 on.
# libarchive and liblzma come from the sysroot, static.
# patches/0003: cache files are named by 30 md5 hex digits (AmigaDOS keeps 30 characters of a name);
# the host build gets the same names from -DUPKG_SHORT_NAMES so check/cache_name.sh can see them.
# patches/0007: temp files under tmp_dir get fixed short names (control.XXXXXX, list.XXXXXX,
# unpack.XXXXXX); check/temp_name.sh runs install and --force-reinstall with check/ffs_names.c
# preloaded, which refuses names over 30 characters the way ixemul on FFS does.
# patches/0008: `upkg --help` is reflowed to 76 columns (a 640x256 hires shell fits about 77, stock opkg
# prints 103); check/help_width.sh fails on any help line over 76 columns with tabs expanded.
# patches/0009: every line upkg prints to a console follows the window width (ioctl TIOCGWINSZ, then
# COLUMNS, then 76), wrapped with a hanging indent; piped output is unchanged; check/console_width.sh.
# patches/0010: the console writer holds a partial word across print calls, so a word printed in
# pieces wraps whole instead of splitting between them; check/wrap_split.sh.
# patches/0011: `upkg --help` prints the usage text alone and exits 0 (no "unrecognized option" line);
# an unknown option is still reported; check/help_flag.sh. check/help_piped.txt lost its two error lines.
# patches/0012: upkg sets PATH to UPKG_DEFAULT_PATH (/UP-Term/bin:/C) when the shell left it unset or
# empty (a plain AmigaDOS Shell has none), so curl and /bin/sh are found; check/default_path.sh.
# patches/0013: when statvfs of the dest root fails (ixemul: "/" is no volume, EPERM from a plain Shell) the
# free-space test measures the volume holding info_dir; check/statvfs_root.sh (shim statvfs_fail.c).
# patches/0014: upkg sets IXSTACK=262144 unless set, so vfork children (curl) get a real stack; the
# default_path.sh check reads it from a preinst.
# patches/0017: list-upgradable no longer builds the file-owner index (pkg_info_preinstall_check read every installed .list and
# stat-ed every path, twice: 41 s vs 1.1 s for list-installed on an A1200); check/list_upgradable_fast.sh.
# patches/0015: when the installed package's prerm fails on an upgrade, the new package's prerm runs with
# `failed-upgrade <old-version>` (dpkg) and the install goes on if it succeeds; prerm_failed_upgrade.sh checks it.
# patches/0018-0021: no upkg command ends a no-op in silence. list/list-installed with a glob matching
# nothing: 'upkg: no package matches "<glob>"' on stderr, rc 1 (0018). "list upgradable|upgradeable|installed"
# run list-upgradable/list-installed (0019, help names them). On a terminal an empty list-upgradable /
# list-installed prints a message, through a pipe nothing, because dist/upkg-browse reads them via $(...) (0020).
# upgrade that upgraded nothing prints 'All installed add-ons are up to date.'; remove of a name matching no
# installed package prints 'X is not installed.' and exits 1 (0021); install of an installed package
# already prints 'Package X (v) installed in root is up to date.'. check/list_messages.sh.
# patches/0022: browse loads the feeds and status, writes list, list-installed and list-upgradable as piped to
# <TMPDIR|T:|/tmp>upkg-lists.<pid>.{all,inst,upg}, names them in UPKG_BROWSE_LISTS for the script and removes
# them after it; list-browse PREFIX writes the same files for a reload. Each upkg load is ~3 s on a 68k from
# PFS3, so the browse start runs one load instead of four. check/browse_lists.sh.
# patches/0023: upkg update keeps each feed's old list as lists/<feed>.prev; list-new prints the packages no .prev
# has (nothing on the first update); browse and list-browse write it as the fourth file PREFIX.new. check/list_new.sh.
# patches/0024: upkg sets stdout line buffered and the wrap code flushes at every newline when not on a terminal, so
# a reader of `upkg install | ...` sees progress while it runs. check/pipe_lines.sh (an http feed that stalls).
# patches/0025: upkg browse is C in libopkg (upkg_browse.c) over libupkgui: it draws its screens in the upkg process
# from the package hash in memory and runs install, remove and upgrade through opkg_cmd_exec. list-browse and the
# browse list/dispatch code of 0022 are gone. While an action runs, upkg_set_sink (upkg_wrap.c) sends upkg's messages and
# the output of script children (xsystem.c, through a pipe) to the progress box line by line; an add-on with
# "UP-Term-Interactive: yes" runs in the plain window (ui_suspend, Return prompt, ui_resume); the hash is reloaded after
# a change. check/browse_tty.sh covers the live box, the interactive route and Enter+Back with 0 children.
# check/browse_tty.sh also catches a stale hash after a reload: the host build of upkg is compiled with
# -fsanitize=integer-divide-by-zero (no recover), so an install from the list followed by the redraw aborts when
# hash_reload() leaves n_buckets at 0 (arm64 udiv by zero returns 0 without a trap, m68k raises SIGFPE).
# patches/0026: upkg sets pr_WindowPtr to -1 (Amiga only) so a full or absent volume returns an error, not a DOS requester that
# takes the keys; the browse box then shows '[ERROR] upkg install <pkg> (exit N)'. check/no_requesters.sh; rig case in vtcon.
# patches/0027: file_mkdir_hier returns -1 when the parent is the path itself (an absent volume root NOSUCHVOL: recursed until the
# stack overflowed). check/mkdir_absent_root.sh (shim dirname_self.c).
# patches/0043: upkg-ask records the question ids it asked in info_dir/NAME.answered (upkg passes the path as UPKG_ASK_STATE to the
# postinst and to the Install All question pass); an upgrade keeps that file and runs its scripts with the terminal, so it asks only the
# questions the old version never asked. UPKG_ASK_UNATTENDED=1 (Install All, a progress box) says the missing terminal is on purpose.
# check/upgrade_new_questions.sh (v1 asks Q1, v2 asks Q1 and Q2, v3 adds Q3 unattended); check/upkg-ask.fixture is the script's copy.
# patches/0028: write_status_files_if_changed returns -1 when the status file or a changed file list fails to write or close
# (ENOSPC shows at fclose; ferror is checked too) and every caller folds it into its result, so the command exits non-zero.
# check/status_write_rc.sh (RLIMIT_FSIZE stands in for a full disk).
# patches/0029: libopkg/upkg_rows.c holds the add-on rows (the parser of list, list-installed, list-upgradable and list-new, and
# the run of install, remove and upgrade with an output sink and the rebuild after it); upkg browse and the Workbench window use
# it, so there is one parser. Pure C, no curses. check/rows.sh + check/rows_test.c (ASan, over fixture list text).
# patches/0030: main calls upkg_wb(struct WBStartup *) when argc == 0 (a Workbench icon), after the IXSTACK setup and the feed and
# status load; any command line runs as before. check/wb_start.sh + check/wb_exec.c (an exec with an empty argv): called once
# for argc == 0, never for a command line. A host build of upkg_wb has no window: it logs "window opened, N rows".
# patches/0031 and 0032: on the Amiga upkg_wb is a GadTools (V37) window on the Workbench public screen: filter cycle, add-on listview
# (rows from upkg_rows_load), Install, Remove, Upgrade, Update, a read-only log listview and Quit; the sentinel is written once the
# list is filled. The filter, the buttons a row enables and the listview line are pure functions in upkg_rows.c (check/rows_test.c).
# Install, Remove, Upgrade and Update do nothing yet (UPKG-WB-UI G3).
# patches/0042: xsystem retries read and waitpid on EINTR. ncurses catches SIGWINCH, so a resize while browse ran an install
# ended the output pump (the pipe closed under the postinst) and left the child unreaped: the install failed with exit 20.
# ixemul never restarts a call (SA_RESTART is recorded, not used), so the retry lives here. check/browse_resize.sh.
# patches/0044: libopkg/upkg_uhc.c reads the UHC catalogue drawer (UPKG_UHC_DIR_DEFAULT UP-Term:uhc/Packages, UPKG_UHC_DIR overrides):
# script <n> with `Set PKGVERSION`, <n>.desc, Installed/<n>; check/uhc.sh + check/uhc_test.c over the fixture drawer check/uhc/Packages.
# patches/0045: upkg_row_t has src (UPKG_SRC_OPKG, UPKG_SRC_UHC); upkg_rows_load appends the UHC rows after the feed rows (no record: available,
# same version: installed, other version: upgrade); a name in both sources keeps both rows. check/rows.sh + rows_test.c.
# patches/0047: upkg list, list-installed, list-upgradable add the UHC rows (text rows tagged uhc:<name>); --tsv prints nine tab-separated
# fields per row (doc/upkg-tsv.txt); info uhc:<name>. check/uhc_list.sh.
# patches/0048: upkg browse shows a UHC row as uhc:<name> in the tag column (selection, info and the commands use that tag); check/browse_uhc.sh.
# patches/0049: stable exit codes (0 ok, 5 nothing to do, 11 usage, 12 not found, 13 network, 14 package script, 15 needs answers, 20 fail) and one
#   `[PROGRESS n/m] <phase> <name>` line per step when stdout is not a terminal (or UPKG_PROGRESS=1); doc/upkg-api.txt; check/exit_progress.sh.
# patches/0050: `upkg questions <pkg>` prints the questions an install or upgrade will ask (tab-separated, rc 5 none, rc 12 unknown), and
#   `upkg install|upgrade <pkg> --answers FILE` runs unattended with id=value answers (rc 15 naming the id when one is missing); check/questions.sh.
# patches/0052: Ctrl-C ends upkg while a child runs. xsystem waited in ixemul wait4, which never returns EINTR and whose sleep clears
# the CTRL_C break, so upkg waited out curl (23 to 25 s on a stalled server). It now polls waitpid(WNOHANG), naps with Delay, sees the
# break (SetSignal) or SIGINT, forwards SIGINT to the child (a native task gets SIGBREAKF_CTRL_C), gives it 3 s, then exits 130
# (or runs the caller's SIGINT handler). A child that ignores the break is left running. check/ctrlc.sh (fake curl that ignores SIGINT).
# patches/0053: the download child no longer holds the lock descriptor. opkg_lock sets FD_CLOEXEC on it and xsystem's vfork child closes it
# before execvp (ixemul keeps the bit but no exec path reads it), so an orphan curl after Ctrl-C cannot keep upkg locked (rc 20 on the next
# update). check/lock_child.sh (fake curl lists its open files; host record locks die with the process, so it checks the cause).
# patches/0054: upkg list --tsv prints one row per package name, the highest version, with the name's installed and upgradable flags
# (it printed one row per feed version with the same flags: up-pi 1.0 installed + 1.1 in the feed gave two "1 1" rows). list-installed and
# list-upgradable are unchanged; the text `upkg list` still prints one line per version (stock opkg). check/tsv_one_row.sh.
# patches/0055: the download error names the cause of the curl exit (22 HTTP error, 6 resolve, 7 reach, 28 timed out; the PATH hint only for
# curl not found: 127, 255, -1) instead of "is curl installed and in PATH?" for every failure. upkg_curl_fail_text; check/curl_msg.sh.
# patches/0056: upkg registers the arch m68k-amigaos-fpu at priority 20 at startup on a 68040/68060 with an FPU (SysBase->AttnFlags, host:
# $UPKG_ATTN_FLAGS); m68k-amigaos stays 10. A 68030 with a 68882 gets none (the FPU builds are compiled -m68060). upkg_cpu.c; check/fpu_probe.sh.
# patches/0057: upkg upgrade switches an installed add-on to the build that matches the machine: an installed package whose architecture is
# not registered, or registered at a lower priority than the best candidate of the same or a newer version, is replaced by that candidate
# (never a lower version). The status file keeps entries of unregistered architectures (they were dropped on load, so upgrade never saw
# them and the next status write lost them). pkg_arch_switch; check/fpu_upgrade_switch.sh.
opkg_VERSION   := 0.9.0
opkg_URL       := https://downloads.yoctoproject.org/releases/opkg/opkg-$(opkg_VERSION).tar.gz
opkg_SHA256    := 440ef321862e01f83da4d02884a0cbb4d9d7b32f82faa81a6a85493f0c89d0f5
opkg_LICENSE   := GPL-2.0-or-later (COPYING)
opkg_CMAKE     := 1
opkg_DEPS      := ixcompat zlib bzip2 xz libarchive upkg-ui ncurses
opkg_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DWITH_BZIP2=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF \
	-DSTATIC_LIBOPKG=ON -DWITH_LIBOPKG_API=OFF \
	-DSYSCONFDIR=/UP-Term/etc -DVARDIR=/UP-Term/pkg/upkg
opkg_LIBS      := -llzma -lbz2 -lz
opkg_CHECK_SH_BIN := bin/upkg
# check/byte_order.sh reads the m68k config.h, so the cross build must be configured first
$(STATE)/host-opkg.expected: $(STATE)/opkg.configured
opkg_BINS      := bin/upkg
# upkg runs curl and maintainer scripts by vfork + exec, and a Shell without a Stack command gives 4096
# bytes: `upkg install` rebooted an A1200 at the default stack (measured 2026-10-20); with 262144 it did not.
# __stack extends upkg itself; the children get IXSTACK (patches/0014). check_bin checks __stack.
opkg_STACK     := 262144
opkg_STACK_VAR := 1
opkg_HOST_DEPS := xz libarchive upkg-ui ncurses
opkg_HOST_CONFIGURE := -DWITH_CURL=OFF -DWITH_SSLCURL=OFF -DWITH_GPGME=OFF -DUSE_SOLVER_LIBSOLV=OFF \
	-DWITH_SHA256=ON -DWITH_XZ=ON -DUSE_ACL=OFF -DUSE_XATTR=OFF -DWITH_LIBOPKG_API=OFF \
	-DCMAKE_PREFIX_PATH="$(HOSTB)/libarchive/inst;$(HOSTB)/xz/inst;$(HOSTB)/upkg-ui/inst;$(HOST_NCURSES)" \
	"-DCMAKE_C_FLAGS=-I$(HOSTB)/libarchive/inst/include -I$(HOSTB)/xz/inst/include -DUPKG_SHORT_NAMES -fsanitize=integer-divide-by-zero -fno-sanitize-recover=integer-divide-by-zero" \
	-DSYSCONFDIR=/UP-Term/etc -DVARDIR=/UP-Term/pkg/upkg \
	-DSTATIC_LIBOPKG=ON "-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=integer-divide-by-zero -lz -lbz2 -liconv $(HOSTB)/xz/inst/lib/liblzma.a"
