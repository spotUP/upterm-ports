#!/usr/bin/env python3
"""UP-MCC theme file -> OpenMUI global.prefs (IFF FORM PREF: PRHD, MUIC), so the
stock MUI classes of every application take the UP-MCC colours with no source
change. usage: theme2prefs.py Dark.theme > Dark.prefs
Frames: every MUICFG_Frame_* key is type B (FST_ROUNDED, frame_round.c
frame_rounded_draw, drawn by Libs/OpenMUI/Zframes.mui): a one-pixel rounded outline, the
area's background clipped to the same radius (arearound.c), as UP-Button draws its
rounded face. Never the two-tone bevels of the stock defaults (configdata.c
DefFramespecValues) and never type 1 (FST_RECT, the shine pen: a white box). The spec is
8 digits, "B" + stock state and inner spacing + radius + width (frame.c
zune_frame_spec_to_intern); the radius is the theme's gui.radius_small for small widgets
and gui.radius for groups and lists (UP-MCC tokens.h defaults 4 and 6), at most 15.
frame_rounded_draw skips the outline of a box not taller and wider than 2 * radius + 4.
shortcut: the outline pen is MPEN_HALFSHADOW, which OpenMUI derives from the screen's
shadow and background pens (window.c InitRenderInfoPens); no prefs key sets the MUI
pens, so the theme's outline colour needs a muimaster patch. The stock classes still
draw the widgets, not UP-*.mcc: a muimaster patch (class substitution) is needed for that."""
import struct, sys

# MUICFG id -> ("2:" image spec or bare pen spec, theme key). Ids: libraries/mui.h / muimaster config ids.
IMG = {0x37: "background", 0x38: "background", 0x95: "background", 0x54: "background",   # window, requester, page, register
       0x39: "surface_raised", 0x3d: "surface_raised", 0x3c: "surface", 0x5b: "surface",  # button, popup, prop, slider
       0x3a: "surface", 0x96: "surface", 0x3b: "surface", 0x5a: "background",             # list, readlist, text, framed
       0x3e: "surface_pressed", 0x3f: "surface_hover", 0x40: "accent", 0x41: "accent",    # selected, list cursor/select/selcur
       0x5c: "accent",                                                                    # slider knob
       0x84: "surface", 0x86: "surface_raised"}                                           # string background, active
# MUICFG_Frame_* id -> stock default spec (configdata.c DefFramespecValues): type digit,
# state (0 up, 1 down), inner left/right/top/bottom. Rounded = type digit "B", the radius
# and width digits appended. Button and image button get 2 px more inner spacing per side
# than stock (2211 -> 4433), the padding UP-Button has.
FRAME = {0x2b: "204433", 0x2c: "204433", 0x2d: "212211", 0x2e: "302211",  # button, image button, text, string
         0x2f: "212211", 0x30: "202211", 0x31: "202211", 0x32: "210000",  # readlist, inputlist, prop, gauge
         0x33: "314444", 0x34: "112211", 0x35: "212211", 0x36: "400000",  # group, popup, virtual, slider
         0x90: "202200", 0x18: "300000"}                                  # knob, drag
ROUNDED = "B"
WIDTH = 1
LARGE = {0x2f, 0x30, 0x33, 0x35}   # readlist, inputlist, group, virtual: gui.radius; others radius_small
RADIUS_DEFAULT = {"radius": 6, "radius_small": 4}   # UP-MCC tokens.h
PEN = {0x85: "text", 0x87: "text", 0x400: "accent", 0x401: "accent", 0x402: "accent_text",  # string text/cursor/marked
       0x8f: "focus_ring"}                                                                 # active object


def chunk(cid, body):
    return cid + struct.pack(">L", len(body)) + body + b"\0" * (len(body) & 1)


def prefs(theme_text):
    t = {}
    for line in theme_text.splitlines():
        if line.startswith("gui.") and "=" in line:
            k, v = line[4:].split("=", 1)
            t[k.strip()] = v.strip()
    rec = b""
    for table, lead in ((IMG, "2:r"), (PEN, "r")):
        for cid, key in sorted(table.items()):
            s = (lead + "%06X" % int(t[key], 16)).encode() + b"\0"   # KeyError: the theme lacks a colour we need
            rec += struct.pack(">LL", cid, len(s)) + s
    for cid, spec in sorted(FRAME.items()):
        key = "radius" if cid in LARGE else "radius_small"
        radius = min(15, max(0, int(t.get(key, RADIUS_DEFAULT[key]))))
        s = (ROUNDED + spec[1:] + "%X%X" % (radius, WIDTH)).encode() + b"\0"
        rec += struct.pack(">LL", cid, len(s)) + s
    out = b"FORM" + struct.pack(">L", 0) + b"PREF" + chunk(b"PRHD", bytes(6)) + chunk(b"MUIC", rec)
    return out[:4] + struct.pack(">L", len(out) - 8) + out[8:]


if __name__ == "__main__":
    data = prefs(open(sys.argv[1]).read())
    assert data[8:12] == b"PREF" and len(data) % 2 == 0 and data.count(b"2:r") == len(IMG)
    sys.stdout.buffer.write(data)
