# FP4.4 FK1: git network via ix_vfork + ix_vfork_resume

Branch feature/fp44-git-network (not merged).

## Done
- pkgs/git/patches/0004: start_async under NO_PTHREADS && USE_VFORK = fflush; ix_vfork(); child: ix_vfork_resume(), close unused pipe ends, process_is_async=1, async->proc(), _exit. Parent unchanged. Sentinel: if env GIT_ASYNC_SENTINEL names a file, the child appends "async: ix_vfork_resume child ran (pid N)" (a file, not stderr: in receive-pack the stderr is the protocol pipe).
- Rig 2 (userland_rig.py --only git): clone and fetch cases PASS (8 of 8), sentinel file written by the async child in both (pids differ per run). Cases use file:// + upload-pack.

## Findings
- Local-path clone/fetch fail on the rig for a reason outside FK1: getcwd gives VTCX:userland/..., git treats "X:path" as ssh host:path. Cases build file:///VOL/... from $PWD.
- SKIP_DASHED_BUILT_INS: no git-upload-pack / git-receive-pack on PATH, so the shell transport fails ("vsh: not found"). Cases pass --upload-pack="git upload-pack"; the kit needs either those names installed or a config default.

## Open gaps
- git push over file:// HANGS (send-pack + receive-pack both use start_async; 3 git processes stay alive, vsh ignores Ctrl-C, leaked processes block rm of the repo dir). Case removed from pkgs/git/check/cases until fixed; not diagnosed. Next: GIT_TRACE both sides, check receive-pack's copy_to_sideband muxer (fd 2 -> async pipe) with ix_vfork child fd table.
- Breaking the leaked "sh" process killed wasabid on the rig (restart needed).
- ssh/https (FK2, FK5) not touched.
