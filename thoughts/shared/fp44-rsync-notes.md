# FP4.4 part 2: rsync 3.4.1 port - BLOCKED (no recipe landed)

Tarball: https://download.samba.org/pub/rsync/src/rsync-3.4.1.tar.gz
sha256 2924bcb3a1ed8b551fc101f740b9f0fe0a202b115027647cf69850d65fd88c52 (fetched 2026-10-17; samba.org also
lists 3.4.4/3.5.x, 3.4.1 chosen as the pinned known release; a newer one has the same structure).

## Blocker: rsync's architecture needs a mid-run fork() of a running process

Source read (rsync-3.4.1), all go through util1.c do_fork() -> fork():
- main.c:1032 do_recv(): ALWAYS forks, in every transfer (local, remote, daemon). The child becomes the
  receiver (recv_files), the parent the generator. Both continue from the same in-memory state
  (file list, option globals, sockets, pipes), then exchange messages over error_pipe.
  Not an exec of a fresh program: the child resumes inside do_recv with the parent's heap.
- pipe.c:124 local_child(): a local copy (`rsync -a src/ dst/`) forks a child that runs child_main
  (the server half) in-process, with dup2'd pipes.
- pipe.c:62 piped_child() (remote shell): fork then exec; this one could use posix_spawn, but the
  server rsync it spawns still hits do_recv's fork on its side.
- socket.c:599/823 (daemon mode): fork per connection.

So even a posix_spawn rewrite of local_child() and piped_child() leaves do_recv()'s fork: the
receiver/generator split cannot be expressed as spawn+exec because the child needs the parent's
memory image. ixemul has vfork only (check_bin fails any linked `_fork`); vfork's child shares the
parent's memory and the parent is suspended, so running the whole receiver in a vfork child while the
generator (the parent) must run concurrently and talk to it is impossible. No threads on ixemul
either (grep recipe: --disable-threads).

Per task instruction (report, do not shim): not built, no recipe, no check/ cases committed.

## What would unblock it (owner decision, none is a small port patch)
1. Real fork in ixemul (copying the Amiga process address space; large ixemul-vtcon project, no MMU).
2. Rewrite rsync's receiver/generator into one process (single-process mode): a large upstream
   fork of rsync's core (io.c multiplexing, recv_files/generate_files interleaving).
3. Port a different tool for the plan row 5.7 use case (e.g. cp -a / tar over ssh, or a
   single-process sync tool) instead of rsync.
