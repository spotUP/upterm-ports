#!/bin/sh
# test_bitchx_parallel.sh: BitchX's top-level Makefile runs wserv and scr-bx as parallel sub-makes in
# source/, and both build bcompat.o and bircsig.o there. At the default JOBS=4, kit-stage failed with
# "bcompat.o: No such file or directory" (2026-10-25). Patch 0003 serialises that level with
# .NOTPARALLEL; this checks a patch adds it.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# The patch must touch the top-level Makefile.in (not source/Makefile.in) and add the line.
if awk '/^diff --git a\/Makefile.in /{top=1; next} /^diff --git /{top=0} top && /^\+\.NOTPARALLEL:/{found=1} END{exit !found}' "$ROOT"/pkgs/bitchx/patches/*.patch; then
	echo "test_bitchx_parallel: ok"
else
	echo "test_bitchx_parallel: no patch adds .NOTPARALLEL to BitchX's top-level Makefile.in" >&2
	exit 1
fi
