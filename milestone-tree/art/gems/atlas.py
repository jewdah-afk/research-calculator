#!/usr/bin/env python3
"""atlas.py - pack the map node art into one 1024 x 1024 image (one Roblox upload, one texture):

  rows 0-2  the 21 layer gems (sprites/<key>.png), 146 px cells, in LAYERS order
  rows 3-5  the same gems locked: sprites/<key>_locked.png where it exists, else a desaturated, darkened copy
  row  6    the energy ring parts, white (the client tints them with ImageColor3):
            ring   the crisp core line          glow   the same ring blurred (the halo)
            comet  a 110 degree arc, alpha tail -> head (rotated for CAN BUY)
            disc   a soft round glow (light pooled in the socket)

  python3 gems/atlas.py        (from art/)  -> gems/out/node_atlas.png + gems/node_atlas.json

The ring's radius is RING_R of a cell; the client sizes the ring ImageLabel so that radius lands on the socket.
Everything is drawn 4x and downsampled, so the lines are anti-aliased.
"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
LAYERS = ["m", "mm", "em", "p", "pe", "sp", "pb", "pp", "se", "hp", "ep", "hb", "ap", "mp", "t", "pm", "pep", "cp", "cm", "ex", "ach"]
CELL, COLS, SIZE = 146, 7, 1024
RING_R = 0.42  # ring radius / cell
SS = 4


def gem(key, locked):
    base = os.path.join(HERE, "sprites", key + ("_locked" if locked else "") + ".png")
    if locked and os.path.exists(base):
        im = Image.open(base).convert("RGBA")
    else:
        im = Image.open(os.path.join(HERE, "sprites", key + ".png")).convert("RGBA")
        if locked:
            a = im.getchannel("A")
            g = ImageEnhance.Contrast(im.convert("L")).enhance(0.95)
            g = ImageEnhance.Brightness(g).enhance(0.62)
            im = Image.merge("RGBA", (g, g, g, a))
    return im.resize((CELL, CELL), Image.LANCZOS)


def ring_cell(width, blur=0.0):
    s = CELL * SS
    im = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(im)
    r = RING_R * s
    w = width * SS
    c = s / 2
    d.ellipse((c - r - w / 2, c - r - w / 2, c + r + w / 2, c + r + w / 2), fill=255)
    d.ellipse((c - r + w / 2, c - r + w / 2, c + r - w / 2, c + r - w / 2), fill=0)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur * SS))
        # renormalise so the blurred halo still peaks near full alpha
        mx = max(1, im.getextrema()[1])
        im = im.point(lambda v: min(255, int(v * 255 / mx)))
    im = im.resize((CELL, CELL), Image.LANCZOS)
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out.putalpha(im)
    return out


def comet_cell():
    s = CELL * SS
    im = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(im)
    c, r = s / 2, RING_R * s
    segs, span = 80, math.radians(110)
    head = -math.pi / 2  # the head points up (Rotation 0 = 12 o'clock)
    for i in range(segs):
        t = (i + 1) / segs
        a0 = head - span + span * i / segs
        a1 = a0 + span / segs + 0.01
        w = (1.4 + 2.6 * t) * SS
        alpha = int(255 * t ** 1.6)
        d.arc((c - r, c - r, c + r, c + r), math.degrees(a0), math.degrees(a1), fill=alpha, width=int(w))
    # the head spark
    hx, hy = c + r * math.cos(head), c + r * math.sin(head)
    spark = Image.new("L", (s, s), 0)
    ImageDraw.Draw(spark).ellipse((hx - 9 * SS, hy - 9 * SS, hx + 9 * SS, hy + 9 * SS), fill=255)
    spark = spark.filter(ImageFilter.GaussianBlur(4 * SS))
    im = Image.composite(Image.new("L", (s, s), 255), im, spark.point(lambda v: min(255, v * 2)))
    im = im.resize((CELL, CELL), Image.LANCZOS)
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out.putalpha(im)
    return out


def disc_cell():
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    a = Image.new("L", (CELL, CELL), 0)
    c = CELL / 2
    px = a.load()
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            px[x, y] = int(255 * max(0.0, 1 - d) ** 1.8)
    out.putalpha(a)
    return out


def main():
    atlas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rects = {}

    def put(name, im, i):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        atlas.alpha_composite(im, (x, y))
        rects[name] = [x, y, CELL, CELL]

    for i, k in enumerate(LAYERS):
        put(k, gem(k, False), i)
        put(k + "_locked", gem(k, True), 21 + i)
    put("ring", ring_cell(2.0), 42)
    put("glow", ring_cell(7.0, blur=3.2), 43)
    put("comet", comet_cell(), 44)
    put("disc", disc_cell(), 45)
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    png = os.path.join(HERE, "out", "node_atlas.png")
    atlas.save(png, optimize=True)
    meta = {"about": "gems/atlas.py: the map node atlas (1024 px). rects are [x, y, w, h]; ringR is the ring radius / cell.",
            "size": SIZE, "cell": CELL, "ringR": RING_R, "rects": rects}
    with open(os.path.join(HERE, "node_atlas.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("wrote", png, os.path.getsize(png) // 1024, "KB,", len(rects), "cells")


if __name__ == "__main__":
    main()
