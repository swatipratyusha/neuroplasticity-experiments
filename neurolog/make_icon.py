#!/usr/bin/env python3
"""Draw MenuIcon.png, the NeuroLog menu bar icon.

The icon is drawn rather than traced from artwork because a menu bar item is
18pt tall — about 30x36 device pixels — and line art with any real detail
averages into grey mush at that size. Every measurement below is in final
device pixels so the constraint stays visible: a 2px stroke needs a 3px gap to
still read as two strokes, which is what limits the design to a few marks per
hemisphere.

The form says what the study is about: ordered rungs on the left, a tangled
zigzag on the right, one fissure between them.

Regenerate with:  python3 make_icon.py   (needs Pillow)
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 30, 36          # device pixels at @2x, i.e. 15 x 18 pt
STROKE = 2.0
SUPERSAMPLE = 16


def draw(d, points, closed=False):
    scaled = [(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in points]
    if closed:
        scaled.append(scaled[0])
    d.line(scaled, fill=255, width=round(STROKE * SUPERSAMPLE), joint="curve")
    radius = STROKE * SUPERSAMPLE / 2
    for x, y in (scaled[0], scaled[-1]):        # round caps
        d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=255)


def cortex(lobes=9, amplitude=0.07, steps=200):
    """Brain outline. The lobes are the gyri bumps — the cue that reads as
    'brain' rather than 'circle' once the interior detail is gone."""
    cx, cy, rx, ry = W / 2, H / 2, W * 0.413, H * 0.428
    return [(cx + rx * (1 + amplitude * math.sin(lobes * t)) * math.cos(t),
             cy + ry * (1 + amplitude * math.sin(lobes * t)) * math.sin(t))
            for t in [i * 2 * math.pi / steps for i in range(steps)]]


def zigzag(cx, y0, y1, amplitude=3.1, humps=2.5, steps=160):
    return [(cx + amplitude * math.sin(humps * 2 * math.pi * i / steps),
             y0 + (y1 - y0) * i / steps) for i in range(steps + 1)]


def main():
    canvas = Image.new("L", (W * SUPERSAMPLE, H * SUPERSAMPLE), 0)
    d = ImageDraw.Draw(canvas)
    draw(d, cortex(), closed=True)
    draw(d, [(W / 2, H * 0.10), (W / 2, H * 0.90)])              # fissure
    for y in (0.305, 0.5, 0.695):                                # ordered hemisphere
        draw(d, [(W * 0.177, H * y), (W * 0.390, H * y)])
    draw(d, zigzag(W * 0.73, H * 0.25, H * 0.75))                # tangled hemisphere

    mask = canvas.resize((W, H), Image.LANCZOS).point(lambda v: min(255, int(v * 1.15)))
    # A template image carries shape in the alpha channel only; macOS tints it
    # to match the menu bar in light and dark.
    icon = Image.merge("RGBA", [Image.new("L", (W, H), 0)] * 3 + [mask])
    out = Path(__file__).resolve().parent / "MenuIcon.png"
    icon.save(out)
    print(out)


if __name__ == "__main__":
    main()
