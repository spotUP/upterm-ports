#!/usr/bin/env python3
"""Host test for theme2prefs.py: decodes the generated global.prefs the way OpenMUI
reads it (FORM PREF, MUIC records id/len/payload, dataspace.c ds_record, no padding)
and checks every MUICFG_Frame_* key is rounded (type B, FST_ROUNDED, 8 digits with the
theme's radius and width 1) and parses as a frame spec (frame.c zune_frame_spec_to_intern). usage: python3 test_theme2prefs.py"""
import os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import theme2prefs  # noqa: E402

# libs/muimaster/classes/configdata.h: every MUICFG_Frame_* id that DefFramespecValues reads
FRAME_IDS = {0x18, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x90}
KEYS = ("background", "surface", "surface_raised", "surface_pressed", "surface_hover",
        "accent", "accent_text", "text", "focus_ring")


def records(data):
    assert data[:4] == b"FORM" and data[8:12] == b"PREF"
    assert struct.unpack(">L", data[4:8])[0] == len(data) - 8
    p, chunks = 12, {}
    while p < len(data):
        cid, n = data[p:p + 4], struct.unpack(">L", data[p + 4:p + 8])[0]
        chunks[cid] = data[p + 8:p + 8 + n]
        p += 8 + n + (n & 1)
    body, q, out = chunks[b"MUIC"], 0, {}
    while q + 8 <= len(body):
        rid, n = struct.unpack(">LL", body[q:q + 8])
        assert n <= len(body) - q - 8, "record overruns the chunk"
        out[rid] = body[q + 8:q + 8 + n]
        q += 8 + n
    assert q == len(body), "trailing bytes in MUIC"
    return out


def spec_ok(spec):
    # zune_frame_spec_to_intern: 6..8 digits base 36; type < FST_COUNT (28), state 0/1, rest <= 15
    if not 6 <= len(spec) <= 8:
        return False
    vals = [int(c, 36) for c in spec]
    return vals[0] < 28 and vals[1] <= 1 and all(v <= 15 for v in vals[2:])


def main():
    theme = "\n".join("gui.%s = %06X" % (k, 0x101010 * (i + 1)) for i, k in enumerate(KEYS))
    rec = records(theme2prefs.prefs(theme + "\ngui.radius = 6\ngui.radius_small = 4"))
    missing = FRAME_IDS - rec.keys()
    assert not missing, "frame keys missing: %s" % sorted(hex(i) for i in missing)
    for rid in sorted(FRAME_IDS):
        raw = rec[rid]
        assert raw.endswith(b"\0"), hex(rid)
        spec = raw[:-1].decode()
        assert spec_ok(spec), "0x%x: bad frame spec %r" % (rid, spec)
        assert spec[0] == "B", "0x%x: frame type %s is not rounded (want B, FST_ROUNDED)" % (rid, spec[0])
        assert len(spec) == 8 and spec[7] == "1", "0x%x: %r lacks radius and width 1" % (rid, spec)
        assert spec[1:6] == theme2prefs.FRAME[rid][1:], "0x%x: stock state/spacing changed" % rid
        want = "6" if rid in theme2prefs.LARGE else "4"
        assert spec[6] == want, "0x%x: radius %s, want %s" % (rid, spec[6], want)
    # no radius keys in the theme: UP-MCC's defaults
    dflt = records(theme2prefs.prefs(theme))
    assert dflt[0x2b] == b"B0443341\0" and dflt[0x2c] == b"B0443341\0" and dflt[0x33] == b"B1444461\0", (dflt[0x2b], dflt[0x33])
    # button and image button: UP-Button padding, 2 px more per side than stock 2211
    for rid in (0x2b, 0x2c):
        assert [int(c, 16) for c in rec[rid][2:6].decode()] == [4, 4, 3, 3], hex(rid)
    assert len(theme2prefs.FRAME) == len(FRAME_IDS)
    assert rec[0x37] == b"2:r101010\0"  # colour records still there
    print("[OK] %d frame keys rounded, %d records" % (len(FRAME_IDS), len(rec)))


if __name__ == "__main__":
    main()
