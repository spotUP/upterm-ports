#!/usr/bin/env python3
"""Host tests of tools/m68k_scan.py's flow rules (make test)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import m68k_scan

CASES = [
    # (name, mnemonic base, operands as objdump prints them, the address followed)
    ("pea of a function", "pea", "1234 <_f>", 0x1234),
    ("lea of a function", "lea", "1234 <_f>,%a0", 0x1234),
    ("move of a function's address", "movel", "#1234 <_f>,%d0", 0x1234),
    # patch 2.8: a read of a data-hunk variable at the address of the $STACK: cookie
    ("move from memory is not a function reference", "movel", "564 <___upterm_stack_cookie>,%sp@-", None),
    ("movea from memory is not a function reference", "moveal", "564 <_g>,%a0", None),
    ("symbol plus offset is not a function", "pea", "56f <___upterm_stack_cookie+0xb>", None),
]

failed = 0
for name, base, ops, want in CASES:
    got = m68k_scan.func_ref(base, ops)
    if got != want:
        failed += 1
        print("[FAIL] %s: %s %s -> %r, want %r" % (name, base, ops, got, want))
# gcc switch table whose range check compares the selector in memory:
#   cmpiw #2,%a1@(56); bhiw default; clrl d1; movew %a1@(56),d1
#   movew %pc@(T,d1:l:2),d1; jmp %pc@(T,d1:w)
# T: three word offsets, then code. Read as offsets the code's words land
# mid-instruction (coreutils 9.12 chown_files: a "cpushl" at 0x33fc).
T = 0x100
TABLE_BYTES = bytes([0x00, 0x08, 0x00, 0x0a, 0x00, 0x0c,
                     0x66, 0x00, 0xf4, 0xea, 0x4e, 0x75, 0x4e, 0x75, 0x4e, 0x75])
mem = {T + i: b for i, b in enumerate(TABLE_BYTES)}
recent = [("cmpiw", "#2,%a1@(56)"), ("bhiw", "200 <_f+0x10>"), ("clrl", "%d1"),
          ("movew", "%a1@(56),%d1"), ("movew", "%pc@(100 <_f+0x20>,%d1:l:2),%d1")]
got = m68k_scan.switch_targets(T, recent, mem, T + len(TABLE_BYTES))
want = [T + 8, T + 10, T + 12]
if got != want:
    failed += 1
    CASES.append(None)
    print("[FAIL] switch table bounded by a memory cmpi: %r, want %r" % (got, want))
else:
    CASES.append(None)
print("test_m68k_scan: %d of %d passed" % (len(CASES) - failed, len(CASES)))
sys.exit(1 if failed else 0)
