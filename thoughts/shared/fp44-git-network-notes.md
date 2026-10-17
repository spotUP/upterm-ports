# FP4.4 FK1: git network via ix_vfork + ix_vfork_resume

Branch feature/fp44-git-network (not merged).

## Done
- pkgs/git/patches/0004: start_async under NO_PTHREADS && USE_VFORK = fflush; ix_vfork(); child: ix_vfork_resume(), close unused pipe ends, process_is_async=1, async->proc(), _exit. Parent unchanged. Sentinel: if env GIT_ASYNC_SENTINEL names a file, the child appends "async: ix_vfork_resume child ran (pid N)" (a file, not stderr: in receive-pack the stderr is the protocol pipe).
- Rig 2 (userland_rig.py --only git): clone and fetch cases PASS (8 of 8), sentinel file written by the async child in both (pids differ per run). Cases use file:// + upload-pack.

## Findings
- Local-path clone/fetch fail on the rig for a reason outside FK1: getcwd gives VTCX:userland/..., git treats "X:path" as ssh host:path. Cases build file:///VOL/... from $PWD.
- SKIP_DASHED_BUILT_INS: no git-upload-pack / git-receive-pack on PATH, so the shell transport fails ("vsh: not found"). Cases pass --upload-pack="git upload-pack"; the kit needs either those names installed or a config default.

## Open gaps
- Breaking the leaked "sh" process killed wasabid on the rig (restart needed).
- ssh/https (FK2, FK5) not touched.

## Push hang: cause and fix (2026-10-17)
- Cause: patch 0004's child read start_async locals AFTER ix_vfork_resume(). _vfork_resume (ixemul library/vfork.c ~622-655) copies only its own call frame to the child's stack and switches sp; a5 still points at the parent's start_async frame, which the parent reuses as soon as it runs on. Disassembly of the old run-command.o: child-side close(fdin[1]) at start_async+0x2a6 is `move.l -12(a5),-(sp)` (fdin[1]) and close(fdout[0]) is `-8(a5)`, both after `jsr _ix_vfork_resume`. With stale values the receive-pack muxer child (builtin/receive-pack.c:2040 unpack(), muxer.in = -1, need_in) keeps its own copy of the pipe's write end, so copy_to_sideband never sees EOF; receive-pack waits in finish_async (2058), send-pack in receive_status, its demux on receive-pack. Clone/fetch passed only because their demux needs need_out alone (a leaked read end is harmless).
- Rig evidence (old binary, push case): exec hung 90 s; wasabi ps: push job, sh, receive-pack job, two vfork()'d git (demux, muxer) all waiting; sentinel shows both async children ran.
- Fix (0004 amended): unused pipe ends closed in the child BEFORE ix_vfork_resume (parent suspended, frame valid, child's fd table already its own); proc_in/proc_out kept in struct async (as the pthread variant does); after resume the child gets only async, in a2, via a 3-line asm (`jsr _ix_vfork_resume; move.l a2,-(sp); jsr (a3)`) into async_child_main(), which reads *async only. in_async() compares getpid() with the main pid: process_is_async=1 in the child had set the shared global in the parent too.
- Rig 2 after: userland_rig --only git --force 9 of 9 PASS incl. push; sentinel 3 lines (send-pack demux, receive-pack muxers); no git/vfork tasks left.
- Residual (not seen): send-pack's sideband_demux reads fd[1] through the shared data pointer; the parent sets fd[1] = -1 after pack_objects (send-pack.c:739). A child preempted that long would close -1 and keep the write end. Same shared-memory class; not reproduced.
- push.err on the rig: "unable to access '.git/remotes/file:': Device not configured" (git probes the URL as a remote name; ixemul reads "file:" as a device). Harmless, not fixed.
