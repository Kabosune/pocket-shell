#!/usr/bin/env python3
"""Draws the headphone girl (an original character) for the fetch card and
turns her into ASCII art: quickshell/PortraitFrames.js.

She is drawn as SVG line art below. Every line is thinned, the drawing is
rasterised, cut into a grid of character cells, and each cell gets the
ASCII character whose shape matches it best (rendered in JetBrains Mono).
A second drawing with her eyes shut gives the blink, and a mask picks the
cells drawn in the theme colour (headphones and eyes).

Needs PySide6 (to rasterise SVG), Pillow and numpy:
    python3 tools/make-portrait.py
"""
import json
import os
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = str(ROOT / "fonts" / "jetbrainsmono" / "JetBrainsMono[wght].ttf")
COLS, ROWS = 72, 36
CROP = (30, 24, 370, 436)        # the part of the 400x440 drawing used
THIN = 0.35                      # line width factor before matching
CW, CH = 10, 22                  # glyph cell for matching, in pixels
CHARS = list(" .,:;'-_~^\"/\\|()[]{}<>!+*=?7LJTYVXZOQ0@#$%&MWNmw8gpqdbo")

HAIR = "#000"

def eye(cx, flip, closed):
    s = -1 if flip else 1
    X = lambda x: cx + s * (x - 160)
    if closed:
        return (f'<path fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" '
                f'd="M{X(184)},254 Q{X(160)},264 {X(136)},252 L{X(128)},246"/>')
    return f'''
    <circle cx="{X(160)}" cy="256" r="14" fill="none" stroke="#e8e8e8" stroke-width="4.5"/>
    <ellipse cx="{X(160)}" cy="259" rx="4.5" ry="8" fill="#9a9a9a"/>
    <circle cx="{X(154)}" cy="249" r="4" fill="#fff"/>
    <path fill="#000" d="M{X(124)},226 L{X(196)},226 L{X(186)},247 C{X(172)},237 {X(150)},235 {X(136)},242 Z"/>
    <path fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" d="M{X(186)},247 C{X(172)},236 {X(150)},234 {X(136)},241 L{X(124)},232"/>
    <path fill="none" stroke="#fff" stroke-width="2.5" d="M{X(142)},268 Q{X(158)},274 {X(178)},266"/>'''

def headphones(fill_cup="#000"):
    return f'''
    <path fill="none" stroke="#fff" stroke-width="16" stroke-linecap="round" d="M84,176 C84,60 316,60 316,176"/>
    <path fill="none" stroke="#000" stroke-width="7" stroke-linecap="round" d="M84,176 C84,60 316,60 316,176"/>
    
    <rect x="58" y="150" width="54" height="104" rx="22" fill="{fill_cup}" stroke="#fff" stroke-width="5"/>
    <rect x="68" y="166" width="34" height="72" rx="14" fill="#000" stroke="#fff" stroke-width="3"/>
    <rect x="288" y="150" width="54" height="104" rx="22" fill="{fill_cup}" stroke="#fff" stroke-width="5"/>
    <rect x="298" y="166" width="34" height="72" rx="14" fill="#000" stroke="#fff" stroke-width="3"/>'''

HAIR = "#000"

def drawing(closed=False):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="440" viewBox="0 0 400 440">
  <rect width="400" height="440" fill="#000"/>
  <!-- long hair behind -->
  <path fill="{HAIR}" stroke="#fff" stroke-width="3" d="M58,440 C38,300 46,140 112,80 C150,46 250,46 288,80 C354,140 362,300 342,440 Z"/>
  <g fill="none" stroke="#e8e8e8" stroke-width="3.5" stroke-linecap="round">
    <path d="M76,430 C62,330 70,200 112,120"/><path d="M324,430 C338,330 330,200 288,120"/>
    <path d="M96,436 C86,340 94,240 124,170"/><path d="M304,436 C314,340 306,240 276,170"/>
    <path d="M150,62 C128,90 110,130 100,180"/><path d="M66,400 C56,320 60,240 86,180"/><path d="M334,400 C344,320 340,240 314,180"/><path d="M110,436 C104,380 106,320 112,270"/><path d="M290,436 C296,380 294,320 288,270"/><path d="M250,62 C272,90 290,130 300,180"/>
  </g>
  <!-- hoodie -->
  <path fill="#000" stroke="#fff" stroke-width="5" d="M20,440 C40,384 116,360 172,354 L200,386 L228,354 C284,360 360,384 380,440 Z"/>
  <path fill="none" stroke="#e0e0e0" stroke-width="4" d="M140,362 C150,334 250,334 260,362"/>
  <path fill="none" stroke="#fff" stroke-width="3" stroke-dasharray="6 5" d="M200,388 L200,440"/>
  <path fill="none" stroke="#e0e0e0" stroke-width="3" d="M184,384 C182,404 178,416 176,430 M216,384 C218,404 222,416 224,430"/>
  <circle cx="176" cy="432" r="4" fill="#fff"/><circle cx="224" cy="432" r="4" fill="#fff"/>
  <!-- neck + choker -->
  <path fill="#000" stroke="#fff" stroke-width="3" d="M178,316 L174,362 L226,362 L222,316 Z"/>
  <rect x="174" y="334" width="52" height="9" fill="#d8d8d8"/>
  <circle cx="200" cy="348" r="5" fill="none" stroke="#fff" stroke-width="2.5"/>
  <!-- face -->
  <path fill="#000" stroke="#fff" stroke-width="5" d="M122,182 C120,252 156,314 200,332 C244,314 280,252 278,182 Z"/>
  {eye(160, False, closed)}
  {eye(240, True, closed)}
  <!-- nose, smirk -->
  <path fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" d="M203,276 L199,284"/>
  <path fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" d="M188,302 Q198,306 212,299 L216,294"/>
  <!-- plaster on the cheek -->
  <g transform="rotate(-18 144 290)">
    <rect x="128" y="284" width="32" height="12" rx="5" fill="none" stroke="#fff" stroke-width="3"/>
    <circle cx="140" cy="290" r="1.6" fill="#fff"/><circle cx="148" cy="290" r="1.6" fill="#fff"/>
  </g>
  <!-- bangs, swept over the right eye -->
  <path fill="{HAIR}" stroke="#fff" stroke-width="3" stroke-linejoin="round" d="M116,218 C112,150 150,100 204,96 C258,100 290,150 284,222
     C282,246 272,268 258,282 C256,256 250,236 238,222 C236,238 230,250 220,258
     C220,238 216,224 208,212 C202,224 194,232 184,236 C186,222 184,210 178,200
     C170,214 162,222 150,226 C152,214 150,204 144,196 C138,208 130,216 120,222 Z"/>
  <g fill="none" stroke="#e8e8e8" stroke-width="3.5" stroke-linecap="round">
    <path d="M170,104 C160,130 160,160 172,196"/><path d="M204,100 C206,140 214,170 232,212"/>
    <path d="M236,106 C252,140 262,180 262,250"/><path d="M144,120 C136,150 138,176 146,192"/><path d="M188,100 C180,140 184,170 194,206"/><path d="M262,124 C270,160 276,200 274,236"/>
  </g>
  <!-- locks over the shoulders -->
  <path fill="{HAIR}" stroke="#fff" stroke-width="3" d="M114,236 C104,300 96,380 84,440 L118,440 C124,380 130,300 128,246 Z"/>
  <path fill="{HAIR}" stroke="#fff" stroke-width="3" d="M286,236 C296,300 304,380 316,440 L282,440 C276,380 270,300 272,246 Z"/>
  <!-- headphones -->
  {headphones()}
  <!-- a hair clip -->
  <path fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" d="M132,150 L152,170 M152,150 L132,170"/>
</svg>'''

def accent_mask():
    # white where the theme colour goes: headphones and irises
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="440" viewBox="0 0 400 440">
  <rect width="400" height="440" fill="#000"/>
  <path fill="none" stroke="#fff" stroke-width="18" d="M84,176 C84,60 316,60 316,176"/>
  <rect x="56" y="148" width="58" height="108" rx="22" fill="#fff"/>
  <rect x="286" y="148" width="58" height="108" rx="22" fill="#fff"/>
  <circle cx="160" cy="258" r="17" fill="#fff"/><circle cx="240" cy="258" r="17" fill="#fff"/>
</svg>'''



def thin(svg):
    return re.sub(r'stroke-width="([\d.]+)"', lambda m: f'stroke-width="{float(m.group(1)) * THIN:.2f}"', svg)


def rasterise(svg):
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PySide6.QtCore import QByteArray
    from PySide6.QtGui import QGuiApplication, QImage, QPainter
    from PySide6.QtSvg import QSvgRenderer
    QGuiApplication.instance() or QGuiApplication(sys.argv)
    img = QImage(400, 440, QImage.Format_RGB32)
    img.fill(0)
    painter = QPainter(img)
    painter.setRenderHint(QPainter.Antialiasing)
    QSvgRenderer(QByteArray(svg.encode())).render(painter)
    painter.end()
    buf = img.convertToFormat(QImage.Format_Grayscale8)
    arr = np.frombuffer(buf.constBits(), dtype=np.uint8).reshape(440, buf.bytesPerLine())[:, :400]
    return Image.fromarray(arr.copy()).crop(CROP)


def glyphs():
    font = ImageFont.truetype(FONT, 16)
    out = []
    for ch in CHARS:
        im = Image.new("L", (CW, CH), 0)
        ImageDraw.Draw(im).text((CW / 2, CH / 2), ch, font=font, fill=255, anchor="mm")
        out.append(np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255)
    return np.stack(out)


def to_ascii(img, stack):
    src = img.resize((COLS * CW, ROWS * CH), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    a = np.asarray(src, dtype=np.float32) / 255
    rows = []
    for r in range(ROWS):
        line = ""
        for c in range(COLS):
            patch = a[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW]
            line += CHARS[int(((stack - patch) ** 2).sum(axis=(1, 2)).argmin())]
        rows.append(line)
    return rows


def mask(img):
    m = np.asarray(img.resize((COLS, ROWS), Image.BOX), dtype=np.float32) / 255
    return ["".join("1" if v > 0.35 else "0" for v in row) for row in m]


if __name__ == "__main__":
    stack = glyphs()
    accent = mask(rasterise(accent_mask()))
    frames = [{"rows": to_ascii(rasterise(thin(drawing(closed))), stack), "accent": accent}
              for closed in (False, True)]
    out = ROOT / "quickshell" / "PortraitFrames.js"
    out.write_text("// Generated by tools/make-portrait.py; edit the drawing there.\n"
                   ".pragma library\n\n"
                   f"var frames = {json.dumps(frames, indent=1)};\n")
    for line in frames[0]["rows"]:
        print(line)
    print(f"wrote {out}")
