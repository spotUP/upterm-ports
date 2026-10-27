#!/bin/sh
# test_upterm_root.sh: UPTERM_ROOT (where the ixemul-vtcon and vtcon siblings are) is the same in the
# main checkout and in a git worktree below it. It was the parent of the working directory, so
# `make opkg` in .claude/worktrees/<name> looked for ixemul-vtcon/docker/install-sdk-headers.sh there.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
main=$(make -s -C "$ROOT" print-UPTERM_ROOT)
tmp=$(mktemp -d)
trap 'git -C "$ROOT" worktree remove --force "$tmp/wt" >/dev/null 2>&1; rm -rf "$tmp"' EXIT
git -C "$ROOT" worktree add --detach -q "$tmp/wt" HEAD
cp "$ROOT/mk/common.mk" "$tmp/wt/mk/common.mk"
wt=$(make -s -C "$tmp/wt" print-UPTERM_ROOT)
[ "$wt" = "$main" ] || { echo "test_upterm_root: worktree says $wt, main checkout says $main" >&2; exit 1; }
[ -d "$wt/ixemul-vtcon" ] || [ ! -d "$main/ixemul-vtcon" ] || { echo "test_upterm_root: $wt has no ixemul-vtcon" >&2; exit 1; }
echo "test_upterm_root: ok ($wt)"
