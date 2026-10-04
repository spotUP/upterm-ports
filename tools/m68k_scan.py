#!/usr/bin/env python3
"""m68k_scan.py BINARY: list the 68030+/FPU instructions in the CODE of an
AmigaOS hunk executable (check_bin.sh's cpu check).

A plain linear disassembly is not enough: hunk executables keep read-only
data (string and lookup tables) in the code hunk, and a table decodes as
anything (GNU grep 3.12 showed cpushl, plpar, ftanx from libixcompat's class
table). So this follows the flow: from each symbol, instructions are live
until an unconditional transfer (rts, rte, rtr, rtd, bra, jmp); a branch
target or a switch-table target (gcc's "jmp %pc@(T,dN:w)" with word
offsets from T after it) makes them live again. Bytes reached only through
a computed jump are not scanned: the scanned share is printed.

Output: one line per forbidden instruction "address symbol mnemonic", then
"scanned N of M code bytes". Exit status 1 when any was found.
"""
import os
import re
import subprocess
import sys

AMIGA = os.environ.get("AMIGA", os.path.expanduser("~/opt/amiga"))
OBJDUMP = os.path.join(AMIGA, "bin", "m68k-amigaos-objdump")
FORBIDDEN = re.compile(r"^(move16|pflush\w*|pmove\w*|ptest\w*|pload\w*|plpa\w*|"
                       r"cinv\w*|cpush\w*|lpstop|f[a-z]+)$")
TERMINAL = re.compile(r"^(rts|rte|rtr|rtd|bra[sbwl]?|jmp|illegal)$")
BRANCH = re.compile(r"^(b[a-z]{2}[sbwl]?|db[a-z]{1,2}|jmp|jsr|bsr[sbwl]?)$")
LINE = re.compile(r"^\s*([0-9a-f]+):\t((?:[0-9a-f]{4} ?)+)\s*\t?(\S*)\s*(.*)$")
SYM = re.compile(r"^([0-9a-f]+) <(.+)>:$")
TARGET = re.compile(r"\b([0-9a-f]+) <")
FUNCREF = re.compile(r"(?:^|#)([0-9a-f]+) <_[A-Za-z_]\w*>")
TABLE = re.compile(r"%pc@\(([0-9a-f]+) <[^>]*>,%?d[0-7]:w\)")


def disasm(start=None, stop=None):
    cmd = [OBJDUMP, "-d", "-m", "m68k:68060", sys.argv[1]]
    if start is not None:
        cmd += ["--start-address=0x%x" % start, "--stop-address=0x%x" % stop]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    insns, syms, prev = {}, [], None
    for line in out.splitlines():
        m = SYM.match(line)
        if m:
            syms.append((int(m.group(1), 16), m.group(2)))
            continue
        m = LINE.match(line)
        if m:
            a = int(m.group(1), 16)
            raw = bytes.fromhex(m.group(2).replace(" ", ""))
            if not m.group(3) and prev is not None and prev[0] + len(insns[prev[0]][0]) == a:
                # objdump wraps a long instruction's bytes onto a second line
                r0, mn0, ops0 = insns[prev[0]]
                insns[prev[0]] = (r0 + raw, mn0, ops0)
                continue
            insns[a] = (raw, m.group(3), m.group(4))
            prev = (a,)
    return insns, syms


BOUND = re.compile(r"^#(-?\d+),%?d[0-7]$")


def switch_targets(T, recent, mem, end):
    """The case addresses of gcc's switch table at T. Its length is the
    range check before it ("cmpi #N,dX; bhi default": N + 1 entries); where
    the bound is in a register, the entries run to the first case after
    the table, and a target inside the table or odd is not taken."""
    count = None
    for base, ops in reversed(recent):
        if base.startswith("cmpi"):
            m = BOUND.match(ops)
            if m:
                count = int(m.group(1)) + 1
            break
    out, first, p = [], end, T
    while p + 1 in mem:
        if count is not None and (p - T) // 2 >= count:
            break
        if count is None and p + 1 >= first:
            break
        off = mem[p] << 8 | mem[p + 1]
        off -= 0x10000 if off & 0x8000 else 0
        tgt = T + off
        p += 2
        if count is None and (tgt & 1 or T <= tgt < p):
            continue
        if tgt > T:
            first = min(first, tgt)
        out.append(tgt)
    return out


def main():
    insns, syms = disasm()
    if not syms:
        sys.exit("m68k_scan.py: no symbols in %s (stripped?)" % sys.argv[1])
    mem = {}
    for a, (raw, _, _) in insns.items():
        for i, b in enumerate(raw):
            mem[a + i] = b
    end = max(mem) + 1
    syms.sort()
    lo = min(mem)
    names = [a for a, _ in syms]

    def name_of(a):
        import bisect
        i = bisect.bisect_right(names, a) - 1
        return syms[i][1] if i >= 0 else "?"

    found, scanned, seen, dropped = [], set(), set(), set()
    # Entries: the program's start (strong), and every symbol (weak: const
    # data in the code hunk has symbols too, the $STACK: cookie, tables).
    # A block runs from an entry to its first unconditional transfer. A
    # weak block holding a word that decodes to no instruction is data: it
    # is dropped with everything it would have pointed to. Strong blocks
    # (reached by a branch, call or switch from code) are code: an
    # undecodable word there is reported.
    todo = [(a, False) for a, _ in syms] + [(lo, True)]
    while todo:
        a, strong = todo.pop()
        if a in seen or (a in dropped and not strong) or not lo <= a < end or a & 1:
            continue
        if a not in insns:  # the linear decode was out of step here
            more, _ = disasm(a, min(end, a + 4096))
            insns.update(more)
            if a not in insns:
                continue
        block, targets, bad, recent, p = [], [], [], [], a
        while lo <= p < end and p not in seen and p in insns:
            raw, mn, ops = insns[p]
            base = mn.split(".")[0] if mn and mn[0] != "." else mn
            block.append((p, raw))
            if not mn or mn.startswith("."):
                bad.append("%x %s undecodable %s %s" % (p, name_of(p), mn, ops))
                if not strong:
                    break
            elif FORBIDDEN.match(base):
                bad.append("%x %s %s %s" % (p, name_of(p), mn, ops))
            if BRANCH.match(base):
                tab = TABLE.search(ops) if base == "jmp" else None
                if tab:
                    targets += switch_targets(int(tab.group(1), 16), recent, mem, end)
                else:
                    t = TARGET.search(ops)
                    if t:
                        targets.append(int(t.group(1), 16))
            elif base in ("pea", "lea", "movel", "movea", "moveal"):
                f = FUNCREF.search(ops)
                if f:
                    targets.append(int(f.group(1), 16))
            recent = (recent + [(base, ops)])[-6:]
            if TERMINAL.match(base):
                break
            p += len(raw)
        if not strong and any(" undecodable " in x for x in bad):
            dropped.add(a)
            continue
        for q, raw in block:
            seen.add(q)
            scanned.update(range(q, q + len(raw)))
        found += bad
        todo += [(t, strong) for t in targets]
    for f in found:
        print(f)
    print("scanned %d of %d code bytes (%d%%)" % (len(scanned), end - lo,
          100 * len(scanned) // max(1, end - lo)))
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
