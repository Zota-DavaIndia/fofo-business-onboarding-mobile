"""Builds the launcher icon and the "fa" mark used in the in-app logo.

The icon is the davaindia lettering (taken from the official logo in
assets/brand, recoloured white) with "fa" in Montserrat ExtraBold Italic
under its right end, on the app's clay colour. "fa" is shaped with HarfBuzz
and converted to vector paths, so neither the icon nor the app needs the
font at runtime. Montserrat is under the SIL Open Font License (see
scripts/app_icon/fonts/OFL.txt).

Needs fontTools and uharfbuzz (pip install fonttools uharfbuzz),
rsvg-convert and ImageMagick.

    python3 scripts/app_icon/generate.py
"""

import base64
import json
import subprocess
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "out"
FONT = Path(__file__).resolve().parent / "fonts/Montserrat-ExtraBoldItalic.ttf"
DART_OUT = ROOT / "lib/core/brand/logo_paths.g.dart"
LETTERING = ROOT / "assets/brand/3.0x/lettering.png"
# The "davaindia" line of the lettering image, without the (c) mark.
WORD_CROP = "614x104+0+0"
WORD_ASPECT = 614 / 104

CLAY = "#A4441A"
CLAY_LIGHT = "#F49A6A"
DARK_TILE = "#1D1916"
WHITE = "#FFFFFF"

# Layout as shares of the visible icon: lettering width, "fa" height, gap.
WORD_SHARE = 0.64
FA_SHARE = 0.38
GAP_SHARE = 0.04


class Mark:
    """"fa" shaped with HarfBuzz, in font units (y up)."""

    def __init__(self):
        font = TTFont(FONT)
        self.glyphs = font.getGlyphSet()
        order = font.getGlyphOrder()
        buf = hb.Buffer()
        buf.add_str("fa")
        buf.guess_segment_properties()
        hb.shape(hb.Font(hb.Face(hb.Blob.from_file_path(str(FONT)))), buf, {"kern": True, "liga": False})
        self.run, x = [], 0
        for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
            self.run.append((order[info.codepoint], x + pos.x_offset))
            x += pos.x_advance
        pen = BoundsPen(self.glyphs)
        self._draw(pen, (1, 0, 0, 1, 0, 0))
        self.bounds = pen.bounds

    def _draw(self, pen, t):
        a, b, c, d, e, f = t
        for name, gx in self.run:
            self.glyphs[name].draw(TransformPen(pen, (a, b, c, d, e + a * gx, f)))

    def aspect(self):
        x0, y0, x1, y1 = self.bounds
        return (x1 - x0) / (y1 - y0)

    def draw(self, pen, height, left, top):
        """Draws "fa" `height` tall with its top-left corner at (left, top),
        y down."""
        x0, y0, x1, y1 = self.bounds
        k = height / (y1 - y0)
        self._draw(pen, (k, 0, 0, -k, left - x0 * k, top + y1 * k))

    def draw_centered(self, pen, height, box):
        self.draw(pen, height, (box - height * self.aspect()) / 2, (box - height) / 2)


MARK = Mark()


def word_image():
    """The davaindia line of the official lettering, in white, as a data URI."""
    white = OUT / "davaindia-white.png"
    run("magick", str(LETTERING), "-crop", WORD_CROP, "+repage", "-fill", "white", "-colorize", "100", str(white))
    return "data:image/png;base64," + base64.b64encode(white.read_bytes()).decode()


def icon_art(word, visible, offset, fa_color):
    """davaindia on top, "fa" below it, right edges aligned, centred in a
    visible x visible area that starts at (offset, offset)."""
    ww = visible * WORD_SHARE
    wh = ww / WORD_ASPECT
    fh = visible * FA_SHARE
    gap = visible * GAP_SHARE
    top = offset + (visible - (wh + gap + fh)) / 2
    left = offset + (visible - ww) / 2
    pen = SVGPathPen(MARK.glyphs)
    MARK.draw(pen, fh, left + ww - fh * MARK.aspect(), top + wh + gap)
    return (
        f'<image x="{left:.2f}" y="{top:.2f}" width="{ww:.2f}" height="{wh:.2f}" href="{word}"/>'
        f'<path d="{pen.getCommands()}" fill="{fa_color}"/>'
    )


def svg_icon(word, size, bg, fa_color, radius=0):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">'
        f'<rect width="{size}" height="{size}" rx="{radius}" fill="{bg}"/>{icon_art(word, size, 0, fa_color)}</svg>'
    )


def svg_foreground(word):
    """Android adaptive foreground on the 108 dp canvas. About 72 dp is
    visible under the launcher mask; the art stays inside the 66 dp safe
    circle."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">'
        f"{icon_art(word, 72, 18, WHITE)}</svg>"
    )


class DartPen(BasePen):
    """Writes outlines as Flutter Path calls."""

    def __init__(self, glyphs):
        super().__init__(glyphs)
        self.calls = []

    @staticmethod
    def _pt(pt):
        return f"{pt[0]:.2f}, {pt[1]:.2f}"

    def _moveTo(self, pt):
        self.calls.append(f"p.moveTo({self._pt(pt)});")

    def _lineTo(self, pt):
        self.calls.append(f"p.lineTo({self._pt(pt)});")

    def _curveToOne(self, p1, p2, p3):
        self.calls.append(f"p.cubicTo({self._pt(p1)}, {self._pt(p2)}, {self._pt(p3)});")

    def _qCurveToOne(self, p1, p2):
        self.calls.append(f"p.quadraticBezierTo({self._pt(p1)}, {self._pt(p2)});")

    def _closePath(self):
        self.calls.append("p.close();")


def dart_mark():
    """Writes "fa" as Dart code, 100 units tall, top-left at 0,0."""
    pen = DartPen(MARK.glyphs)
    MARK.draw(pen, 100, 0, 0)
    lines = [
        "// Generated by scripts/app_icon/generate.py. Do not edit by hand.",
        "",
        "import 'dart:ui';",
        "",
        f"const faSize = Size({100 * MARK.aspect():.2f}, 100);",
        "",
        "void faMark(Path p) {",
        *[f"  {c}" for c in pen.calls],
        "}",
    ]
    DART_OUT.parent.mkdir(parents=True, exist_ok=True)
    DART_OUT.write_text("\n".join(lines) + "\n")


def run(*args):
    subprocess.run(args, check=True)


def png(svg_file, out, size, opaque=None):
    out.parent.mkdir(parents=True, exist_ok=True)
    run("rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(out), str(svg_file))
    if opaque:
        run("magick", str(out), "-background", opaque, "-alpha", "remove", "-alpha", "off", str(out))


def main():
    OUT.mkdir(exist_ok=True)
    word = word_image()

    # iOS: full-bleed square; the system applies the rounded mask.
    (OUT / "ios.svg").write_text(svg_icon(word, 1024, CLAY, WHITE))
    (OUT / "ios-dark.svg").write_text(svg_icon(word, 1024, DARK_TILE, CLAY_LIGHT))
    icons = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for old in icons.glob("*.png"):
        old.unlink()
    png(OUT / "ios.svg", icons / "AppIcon.png", 1024, opaque=CLAY)
    png(OUT / "ios-dark.svg", icons / "AppIcon-Dark.png", 1024, opaque=DARK_TILE)
    image = {"idiom": "universal", "platform": "ios", "size": "1024x1024"}
    contents = {
        "images": [
            {"filename": "AppIcon.png", **image},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-Dark.png", **image},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (icons / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    # Android 8+: clay background colour, PNG foreground per density (the
    # lettering is raster, so a vector drawable can't hold it), and the same
    # white layer for Android 13 themed icons.
    res = ROOT / "android/app/src/main/res"
    for old in ("drawable/ic_launcher_foreground.xml", "drawable/ic_launcher_monochrome.xml"):
        (res / old).unlink(missing_ok=True)
    (OUT / "android-foreground.svg").write_text(svg_foreground(word))
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for folder, scale in densities.items():
        png(OUT / "android-foreground.svg", res / f"mipmap-{folder}/ic_launcher_foreground.png", round(108 * scale))
    (res / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{CLAY}</color>\n</resources>\n'
    )
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    )

    # Android 7: round PNGs.
    (OUT / "android-legacy.svg").write_text(svg_icon(word, 432, CLAY, WHITE, radius=216))
    for folder, scale in densities.items():
        png(OUT / "android-legacy.svg", res / f"mipmap-{folder}/ic_launcher.png", round(48 * scale))

    dart_mark()

    png(OUT / "ios.svg", OUT / "preview-ios.png", 512)
    png(OUT / "ios-dark.svg", OUT / "preview-ios-dark.png", 512)
    print("Icons written. Previews in", OUT)


if __name__ == "__main__":
    main()
