"""Builds MonivoOmaniRial-{Light,Medium,Bold}.ttf: one glyph, U+20C4 OMANI RIAL SIGN,
from the Central Bank of Oman's artwork (Wikimedia Commons, public domain), sized to
Manrope's metrics so it sits on the baseline at cap height and never changes line height."""
import re, sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.areaPen import AreaPen
from fontTools.svgLib.path import parse_path

SVG_DIR, OUT = sys.argv[1], sys.argv[2]
UPM, ASC, DESC, CAP, XH = 2000, 2132, -600, 1440, 1080   # Manrope
SIDE = 100                                               # side bearing, units
WEIGHTS = [("Light", 300, "Omani_rial_black_light.svg"),
           ("Medium", 500, "Omani_rial_black_medium.svg"),
           ("Bold", 700, "Omani_rial_black_bold.svg")]

def outline(svg_file):
    d = re.search(r'\sd="([^"]+)"', open(svg_file).read()).group(1)
    rec = RecordingPen(); parse_path(d, rec)
    b = BoundsPen(None); rec.replay(b)
    x0, y0, x1, y1 = b.bounds
    s = CAP / (y1 - y0)
    # SVG is y-down: flip, put the bottom on the baseline, left edge at SIDE.
    t = (s, 0, 0, -s, SIDE - x0 * s, y1 * s)
    out = RecordingPen(); rec.replay(TransformPen(out, t))
    area = AreaPen(); out.replay(area)
    width = round((x1 - x0) * s) + 2 * SIDE
    return out, width, area.value

for style, weight, svg in WEIGHTS:
    rec, adv, area = outline(f"{SVG_DIR}/{svg}")
    tt = TTGlyphPen(None)
    # TrueType outer contours run clockwise (negative area in fontTools' y-up sign).
    rec.replay(Cu2QuPen(tt, max_err=0.5, reverse_direction=area > 0))
    glyph = tt.glyph()
    empty = TTGlyphPen(None).glyph()

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder([".notdef", "space", "uni00A0", "uni20C4"])
    fb.setupCharacterMap({0x20: "space", 0xA0: "uni00A0", 0x20C4: "uni20C4"})
    fb.setupGlyf({".notdef": empty, "space": empty, "uni00A0": empty, "uni20C4": glyph})
    space = 520   # Manrope's space
    fb.setupHorizontalMetrics({".notdef": (UPM // 2, 0), "space": (space, 0),
                               "uni00A0": (space, 0), "uni20C4": (adv, SIDE)})
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC, lineGap=0)
    family = "Monivo Omani Rial"
    fb.setupNameTable({
        "familyName": family, "styleName": style,
        "uniqueFontIdentifier": f"MonivoOmaniRial-{style};1.000",
        "fullName": f"{family} {style}", "psName": f"MonivoOmaniRial-{style}",
        "version": "Version 1.000",
        "copyright": "Glyph: Omani Rial Sign by the Central Bank of Oman (public domain).",
        "description": "U+20C4 OMANI RIAL SIGN only, metrics matched to Manrope, for Monivo.",
    })
    fb.setupOS2(version=4, sTypoAscender=ASC, sTypoDescender=DESC, sTypoLineGap=0,
                usWinAscent=ASC, usWinDescent=-DESC, sCapHeight=CAP, sxHeight=XH,
                usWeightClass=weight, fsSelection=0x80 | (0x20 if weight >= 700 else 0x40),
                achVendID="MNVO", ulUnicodeRange1=1, ulCodePageRange1=1)
    fb.setupPost()
    fb.setupHead(unitsPerEm=UPM, macStyle=1 if weight >= 700 else 0)
    path = f"{OUT}/MonivoOmaniRial-{style}.ttf"
    fb.save(path)
    print(path, "advance", adv, f"({adv/UPM:.2f} em)", "area", round(area))
