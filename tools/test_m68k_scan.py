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
print("test_m68k_scan: %d of %d passed" % (len(CASES) - failed, len(CASES)))
sys.exit(1 if failed else 0)
