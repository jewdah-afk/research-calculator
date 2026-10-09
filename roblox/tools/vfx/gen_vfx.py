#!/usr/bin/env python3
"""Peckwood VFX textures (cel style). Re-run to regenerate everything:

    python roblox/tools/vfx/gen_vfx.py            # writes roblox/assets/vfx/*.png + manifest.json
    python roblox/tools/vfx/gen_vfx.py --preview  # also writes roblox/tools/vfx/preview/*.png (QA contact sheets)

Style: premium toy diorama, Pokemon X/Y cel look. Flat colour blocks with hard 2-3 tone steps (no soft gradients),
white hot cores, a dark ink outline (#16181e) where it reads, stepped (not smooth) glow falloff.

Every texture is drawn from boolean shape masks at 4x supersampling, then box-filtered down, so edges are crisp and
anti-aliased. Alpha is straight; the RGB under transparent pixels is bled from the nearest visible pixel so mip levels
never get a dark or white fringe. Flipbook frames run left to right, top to bottom, and keep an empty gutter (content
inside ~92 % of the frame) so neighbouring frames never bleed into each other.

"tint" textures are greyscale + ink: the game tints them per rarity through ParticleEmitter.Color / Beam.Color
(multiply), so white = the tint colour, grey tones = darker steps of it, ink stays ink. "baked" textures carry their
own colours (leaf) and are drawn with Color = white.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))  # roblox/
OUT = os.path.join(ROOT, "assets", "vfx")
PREV = os.path.join(HERE, "preview")

INK = (22, 24, 30)  # #16181e, the game's ink outline colour


def g(v):
    return (v, v, v)


def ease_out(t, p=3):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** p


def ease_in(t, p=2):
    t = min(max(t, 0.0), 1.0)
    return t ** p


def ease_back(t, s=1.7):
    t = min(max(t, 0.0), 1.0)
    return 1 + (s + 1) * (t - 1) ** 3 + s * (t - 1) ** 2


# ------------------------------------------------------------------------------------------------ canvas
class Canvas:
    """One supersampled image. Shapes are boolean masks; paint() lays a flat colour over what is already there."""

    def __init__(self, w, h=None, ss=4):
        h = h or w
        self.w, self.h, self.ss = w, h, ss
        self.W, self.H = w * ss, h * ss
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)  # premultiplied
        self.a = np.zeros((self.H, self.W), np.float32)
        xs = (np.arange(self.W, dtype=np.float32) + 0.5) / self.W * 2 - 1
        ys = (np.arange(self.H, dtype=np.float32) + 0.5) / self.H * 2 - 1
        self.X, self.Y = np.meshgrid(xs, ys)  # [-1, 1] on each axis; +Y points DOWN the image
        self.R = np.hypot(self.X, self.Y)
        self.T = np.arctan2(self.Y, self.X)

    # pixel helpers (output pixels, for non-square strips)
    def px(self, x, y):
        return ((x + 1) / 2 * self.W, (y + 1) / 2 * self.H)

    def unit(self):
        return self.W / 2  # supersampled pixels per normalized x unit

    def draw(self, fn):
        img = Image.new("L", (self.W, self.H), 0)
        fn(ImageDraw.Draw(img), self)
        return np.asarray(img) > 127

    def poly(self, pts):
        return self.draw(lambda d, c: d.polygon([c.px(x, y) for x, y in pts], fill=255))

    def circle(self, cx, cy, r):
        return (self.X - cx) ** 2 + (self.Y - cy) ** 2 <= r * r

    def grow(self, mask, w):
        """dilate by w normalized units (true Euclidean, so outlines are even everywhere)"""
        if w <= 0 or not mask.any():
            return mask
        return ndimage.distance_transform_edt(~mask) <= w * self.unit()

    def shrink(self, mask, w):
        if not mask.any():
            return mask
        return ndimage.distance_transform_edt(mask) > w * self.unit()

    def round(self, mask, r):
        """round convex corners with radius r (morphological opening)"""
        return self.grow(self.shrink(mask, r), r)

    def paint(self, mask, col, alpha=1.0):
        m = mask.astype(np.float32) * alpha
        c = np.asarray(col, np.float32) / 255.0
        self.rgb = self.rgb * (1 - m[..., None]) + c * m[..., None]
        self.a = self.a * (1 - m) + m

    def inked(self, mask, col, w):
        """flat shape with an ink outline of width w OUTSIDE it"""
        self.paint(self.grow(mask, w), INK)
        self.paint(mask, col)

    def image(self):
        s = self.ss
        rgb = self.rgb.reshape(self.h, s, self.w, s, 3).mean(axis=(1, 3))
        a = self.a.reshape(self.h, s, self.w, s).mean(axis=(1, 3))
        out = np.zeros((self.h, self.w, 4), np.float32)
        nz = a > 1e-6
        out[..., :3][nz] = rgb[nz] / a[nz][:, None]
        out[..., 3] = a
        return bleed(out)


def bleed(img):
    """float RGBA (straight alpha) -> uint8, RGB under transparent pixels copied from the nearest visible pixel"""
    a = img[..., 3]
    vis = a > 0.02
    if vis.any() and (~vis).any():
        _, (iy, ix) = ndimage.distance_transform_edt(~vis, return_indices=True)
        rgb = img[..., :3].copy()
        hid = ~vis
        rgb[hid] = img[..., :3][iy[hid], ix[hid]]
        img = np.concatenate([rgb, a[..., None]], -1)
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def sheet(frames, n):
    fw = frames[0].shape[0]
    out = np.zeros((fw * n, fw * n, 4), np.uint8)
    for k, f in enumerate(frames):
        r, c = divmod(k, n)
        out[r * fw:(r + 1) * fw, c * fw:(c + 1) * fw] = f
    return out


def local(c, cx, cy, rot, sx=1.0, sy=1.0):
    """pixel grid in a shape's local frame: translate, rotate by rot, then un-scale (sx < 0 mirrors)"""
    x, y = c.X - cx, c.Y - cy
    cr, sr = math.cos(rot), math.sin(rot)
    lx = x * cr + y * sr
    ly = -x * sr + y * cr
    sx = sx if abs(sx) > 1e-3 else 1e-3
    return lx / sx, ly / sy


def astroid(lx, ly, r, q=0.55, squash=1.0):
    """concave 4-point star (|x|^q + |y|^q <= r^q)"""
    return (np.abs(lx / r) ** q + np.abs(ly / (r * squash)) ** q) <= 1.0


def star_pts(n, r_tip, r_valley, rot=-math.pi / 2, cx=0.0, cy=0.0, long_short=None):
    pts = []
    for k in range(2 * n):
        a = rot + k * math.pi / n
        if k % 2 == 0:
            rr = r_tip if long_short is None or (k // 2) % 2 == 0 else r_tip * long_short
        else:
            rr = r_valley
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def egg_mask(lx, ly, w, h):
    """egg outline in local coords: narrower top (ly < 0), wider bottom"""
    k = 1 + 0.16 * np.clip(ly / h, -1, 1)
    return (lx / (w * k)) ** 2 + (ly / h) ** 2 <= 1.0


# ------------------------------------------------------------------------------------------------ textures
TEX = []  # (key, filename, meta)


def reg(key, img, **meta):
    fn = key + ".png"
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, fn), optimize=True)
    meta["file"] = "roblox/assets/vfx/" + fn
    meta["size"] = [img.shape[1], img.shape[0]]
    TEX.append((key, meta))
    print(f"  {fn:22s} {img.shape[1]}x{img.shape[0]}  {meta.get('layout', 'None')}")


def tex_star():
    """little 5-point star: puffy tips, two-tone facets (each arm split along its spine), ink outline"""
    c = Canvas(256)
    cy = 0.05
    m = c.round(c.poly(star_pts(5, 0.80, 0.40, cy=cy)), 0.06)
    th = (np.arctan2(c.Y - cy, c.X) + math.pi / 2) % (2 * math.pi / 5) / (2 * math.pi / 5)
    lit = th < 0.5
    c.paint(c.grow(m, 0.075), INK)
    c.paint(m, g(232))
    c.paint(m & ~lit, g(196))
    c.paint(m & c.circle(-0.20, -0.14 + cy, 0.085), g(255))
    return c.image()


def tex_sparkle():
    """4x4 twinkle: a concave 4-point star pops in (back ease), turns, holds with a breath, shrinks to nothing"""
    frames = []
    for k in range(16):
        f = k / 15
        if f < 0.3:
            s = ease_back(f / 0.3, 2.2) * 0.98
        elif f < 0.62:
            s = 1.0 + 0.05 * math.sin((f - 0.3) / 0.32 * math.pi)
        else:
            s = 1 - ease_in((f - 0.62) / 0.38, 2)
        c = Canvas(128)
        if s > 0.02:
            rot = 0.55 * f
            r = 0.74 * s
            lx, ly = local(c, 0, 0, rot)
            main = astroid(lx, ly, r, 0.52)
            dlx, dly = local(c, 0, 0, rot + math.pi / 4)
            bump = math.sin(min(1, max(0, (f - 0.12) / 0.6)) * math.pi)
            diag = astroid(dlx, dly, r * 0.66 * bump, 0.42) if bump > 0.05 else np.zeros_like(main)
            c.paint(c.grow(main | diag, 0.06), INK)
            c.paint(diag, g(232))
            c.paint(main, g(205))
            c.paint(astroid(lx, ly, r * 0.62, 0.52), g(255))
            c.paint(c.circle(0, 0, 0.16 * s), g(255))
        frames.append(c.image())
    return sheet(frames, 4)


def tex_impact():
    """4x4 impact star: flash disc -> 8-spike star bursts out -> centre punches hollow -> spikes recede to nothing"""
    frames = []
    for k in range(16):
        c = Canvas(256)
        if k == 0:
            d = c.circle(0, 0, 0.24)
            c.inked(d, g(255), 0.045)
            frames.append(c.image())
            continue
        R = 0.86 * (0.5 + 0.5 * ease_out(min(1, k / 3.0), 2))
        hollow = 0.0 if k < 4 else 0.46 * ease_out((k - 4) / 5.0, 2)
        valley0 = 0.32 * R if k < 4 else (0.32 - 0.1 * min(1, (k - 4) / 5)) * R
        L = 1.0 if k < 9 else 1 - (k - 8) / 7.0
        tip = hollow + (R - hollow) * L
        valley = max(hollow + 0.02, valley0 * L + hollow * (1 - L) * 0.98)
        rot = -math.pi / 2 + 0.05 * k
        if tip > hollow + 0.03:
            outer = c.poly(star_pts(8, tip, valley, rot, long_short=0.62))
            inner_tip = hollow + (tip - hollow) * 0.62
            inner = c.poly(star_pts(8, inner_tip, max(hollow + 0.01, valley * 0.7), rot, long_short=0.62))
            hole = c.circle(0, 0, hollow) if hollow > 0 else np.zeros_like(outer)
            outer &= ~hole
            inner &= ~hole
            c.paint(c.grow(outer, 0.04), INK)  # also inks the inner edge of the punch-out
            c.paint(outer, g(206))
            c.paint(inner, g(255))
        frames.append(c.image())
    return sheet(frames, 4)


PUFF = [(0.0, 0.06, 0.40), (-0.36, 0.15, 0.28), (0.36, 0.13, 0.30), (-0.16, -0.22, 0.30), (0.19, -0.21, 0.27),
        (0.02, -0.40, 0.20), (-0.02, 0.30, 0.26)]
PUFF_HOLES = [(-0.12, 0.02, 0.0), (0.20, 0.12, 0.0), (0.02, -0.26, 0.0)]


def puff_mask(c, gsc, f, shift=(0.0, 0.0)):
    m = np.zeros(c.X.shape, bool)
    for i, (x, y, r) in enumerate(PUFF):
        start = 0.42 + 0.05 * ((i * 37) % 7)  # each lobe starts melting at its own time
        rm = 1.0 if f < start else 1 - ease_in((f - start) / (1 - start + 1e-6), 1.6)
        if rm <= 0.02:
            continue
        m |= c.circle(x * gsc + shift[0], y * gsc + shift[1], r * gsc * rm)
    for i, (x, y, _) in enumerate(PUFF_HOLES):
        hs = 0.5 + 0.06 * i
        if f > hs:
            m &= ~c.circle(x * gsc + shift[0], y * gsc + shift[1], 0.34 * gsc * ease_out((f - hs) / (1 - hs), 2))
    return m


def tex_smoke():
    """4x4 toon smoke puff: lobes bloom out fast, drift bigger, then melt away lobe by lobe with growing holes.
    Three cool-white tones (light / lilac shade / deep rim, light from the top-left) + a thin ink outline."""
    frames = []
    for k in range(16):
        f = k / 15
        gsc = 0.38 + 0.62 * ease_out(min(1, f / 0.33), 3) + 0.22 * max(0, f - 0.33) / 0.67
        gsc *= 1.0
        c = Canvas(256)
        m = puff_mask(c, gsc, f)
        if m.any():
            s = 0.11 * gsc
            lit = puff_mask(c, gsc, f, (-s, -s * 1.1))
            lit2 = puff_mask(c, gsc, f, (-s * 0.38, -s * 0.42))
            c.paint(c.grow(m, 0.032), INK)
            c.paint(m, (186, 183, 214))
            c.paint(m & lit2, (219, 216, 238))
            c.paint(m & lit2 & lit, (255, 253, 248))
        frames.append(c.image())
    return sheet(frames, 4)


def _shard_pts():
    """a rounded-triangle shell piece whose whole rim is broken into small uneven teeth"""
    rng = np.random.default_rng(3)
    corners = [(-0.58, -0.36), (0.6, -0.3), (0.02, 0.56)]
    pts = []
    n_side = 7
    for k in range(3):
        (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 3]
        for j in range(n_side):
            t = j / n_side
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            # bulge the sides outward (curved piece), teeth on alternate points
            nx, ny = -(by - ay), (bx - ax)
            ln = math.hypot(nx, ny)
            nx, ny = nx / ln, ny / ln
            bulge = math.sin(t * math.pi) * (0.16 if k == 0 else 0.07)
            tooth = (-0.075 if j % 2 == 1 else 0.0) + rng.uniform(-0.02, 0.02)
            if k == 0:
                tooth *= 0.35  # the top edge is the smoother curved rim of the shell
            pts.append((x - nx * (bulge + tooth), y - ny * (bulge + tooth)))
    return pts


SHARD = _shard_pts()
SPECKS = [(-0.3, -0.3, 0.05), (0.04, -0.36, 0.042), (0.3, -0.24, 0.05), (-0.06, -0.1, 0.036), (0.12, 0.1, 0.03)]


def tex_shards():
    """2x2 eggshell shard tumbling (Loop): curved outer face with speckles -> edge-on -> inner face -> edge-on"""
    frames = []
    for k, (sx, rot) in enumerate([(1.0, 0.0), (0.42, 0.9), (-0.86, 1.8), (-0.34, 2.7)]):
        c = Canvas(256)

        def tf(x, y):
            x *= sx * 0.95
            y *= 0.95
            cr, sr = math.cos(rot), math.sin(rot)
            return (x * cr - y * sr, x * sr + y * cr)

        m = c.poly([tf(x, y) for x, y in SHARD])
        c.paint(c.grow(m, 0.055), INK)
        lx, ly = local(c, 0, 0, rot, sx * 0.95, 0.95)
        if sx > 0:
            c.paint(m, g(250 if sx > 0.6 else 228))
            c.paint(m & (ly > 0.02), g(222 if sx > 0.6 else 204))  # curvature shade toward the broken tip
            c.paint(m & (ly < -0.3) & (lx < -0.05) & (lx > -0.4), g(255))  # rim highlight
            for x, y, r in SPECKS:
                px, py = tf(x, y)
                c.paint(m & ((((c.X - px) / max(abs(sx), 0.3)) ** 2 + (c.Y - py) ** 2) <= r * r), g(184))
        else:
            c.paint(m, g(206 if sx < -0.6 else 190))
            c.paint(m & ~c.shrink(m, 0.05) & (ly < -0.2), g(255))  # shell thickness along the curved rim
        frames.append(c.image())
    return sheet(frames, 2)


def tumble(k, n=16):
    phi = 2 * math.pi * k / n
    return math.cos(phi), 0.39 * k + 0.2 * math.sin(phi)


def tex_confetti():
    """4x4 paper confetti tumbling (Loop): spins in-plane while flipping; front face light, back face a step darker"""
    frames = []
    for k in range(16):
        sx, rot = tumble(k)
        c = Canvas(128)
        w = max(abs(sx), 0.1)
        lx, ly = local(c, 0, 0, rot)
        m = (np.abs(lx) <= 0.25 * w) & (np.abs(ly) <= 0.56)
        m = c.round(m, 0.035) if w > 0.25 else m
        c.paint(c.grow(m, 0.075), INK)
        c.paint(m, g(250 if sx >= 0 else 196))
        # a crease highlight on the front so the flip reads
        if sx >= 0.3:
            c.paint(m & (lx < -0.25 * w * 0.35), g(255))
            c.paint(m & (lx > 0.25 * w * 0.45), g(226))
        frames.append(c.image())
    return sheet(frames, 4)


def tex_leaf():
    """4x4 leaf tumbling (Loop), baked greens: split two-tone halves, a midrib, darker back face, ink outline"""
    frames = []
    for k in range(16):
        sx, rot = tumble(k)
        c = Canvas(128)
        w = max(abs(sx), 0.1)
        lx, ly = local(c, 0, 0, rot + 0.4, w, 1)
        ly = ly + 0.06
        lens = ((lx - 0.33) ** 2 + ly ** 2 <= 0.6 ** 2) & ((lx + 0.33) ** 2 + ly ** 2 <= 0.6 ** 2)
        stem = (np.abs(lx) <= 0.06) & (ly > 0.3) & (ly < 0.72)
        m = lens | stem
        c.paint(c.grow(m, 0.075), INK)
        if sx >= 0:
            c.paint(m, (126, 196, 86))
            c.paint(m & (lx > 0), (96, 168, 72))
            c.paint(lens & (np.abs(lx) < 0.045) & (ly < 0.38), (70, 128, 58))
            c.paint(lens & (lx < -0.12) & (ly < -0.05) & (ly > -0.32), (166, 222, 112))
        else:
            c.paint(m, (88, 150, 70))
            c.paint(m & (lx < 0), (74, 132, 62))
            c.paint(lens & (np.abs(lx) < 0.045) & (ly < 0.38), (150, 206, 110))
        frames.append(c.image())
    return sheet(frames, 4)


def tex_ring_shock():
    """flat shockwave ring: ink | white rim | body tone | ink, then a two-step translucent inner glow"""
    c = Canvas(512, ss=3)
    R = c.R
    c.paint((R >= 0.50) & (R < 0.62), g(240), 0.22)
    c.paint((R >= 0.62) & (R < 0.665), g(240), 0.45)
    c.paint((R >= 0.665) & (R < 0.95), INK)
    c.paint((R >= 0.70) & (R < 0.915), g(206))
    c.paint((R >= 0.83) & (R < 0.915), g(255))
    return c.image()


def tex_ring_thin():
    """thin crisp pop ring: white band with ink both sides"""
    c = Canvas(256)
    R = c.R
    c.paint((R >= 0.74) & (R < 0.96), INK)
    c.paint((R >= 0.79) & (R < 0.91), g(255))
    return c.image()


def tex_glow():
    """stepped glow disc: four hard alpha steps (no smooth falloff), white"""
    c = Canvas(256)
    R = c.R
    for r, a in ((0.94, 0.14), (0.74, 0.34), (0.52, 0.62), (0.30, 1.0)):
        c.paint(R < r, g(255), a)
    return c.image()


def tex_rays():
    """light-ray fan: 14 wedges (long/short alternating) with three hard alpha steps along their length"""
    c = Canvas(512, ss=3)
    rng = np.random.default_rng(7)
    a_all = np.zeros(c.X.shape, np.float32)
    n = 14
    for i in range(n):
        a0 = i * 2 * math.pi / n + rng.uniform(-0.06, 0.06)
        long = i % 2 == 0
        hw = (0.17 if long else 0.1) + rng.uniform(-0.015, 0.015)
        reach = (0.95 if long else 0.66) + rng.uniform(-0.04, 0.0)
        d = np.abs((c.T - a0 + math.pi) % (2 * math.pi) - math.pi)
        taper = np.clip(1 - (c.R / reach) ** 6, 0, 1)
        m = (d < hw * (0.55 + 0.45 * c.R) * (0.35 + 0.65 * taper)) & (c.R > 0.08) & (c.R < reach)
        step = np.where(c.R < 0.4, 1.0, np.where(c.R < 0.64, 0.6, 0.3))
        a_all = np.maximum(a_all, m * step)
    c.paint(a_all > 0, g(255))
    c.a = c.a * a_all
    c.rgb = c.rgb * a_all[..., None]
    return c.image()


def tex_burst_lines():
    """anime impact lines, our way: 30 white needles pointing at the centre, thick outer end, ink outline"""
    c = Canvas(512, ss=3)
    rng = np.random.default_rng(11)
    m = np.zeros(c.X.shape, bool)
    n = 30
    for i in range(n):
        a = i * 2 * math.pi / n + rng.uniform(-0.05, 0.05)
        r0 = rng.uniform(0.42, 0.6)
        r1 = rng.uniform(0.84, 0.93)
        w = rng.uniform(0.04, 0.075)
        t = (-math.sin(a), math.cos(a))
        tip = (math.cos(a) * r0, math.sin(a) * r0)
        b = (math.cos(a) * r1, math.sin(a) * r1)
        m |= c.poly([tip, (b[0] + t[0] * w / 2, b[1] + t[1] * w / 2), (b[0] - t[0] * w / 2, b[1] - t[1] * w / 2)])
    c.inked(m, g(255), 0.022)
    return c.image()


def glyph(lx, ly, kind, s):
    """Peckwood rune glyphs in a local frame (ly = 'up' axis), size s"""
    if kind == "dot":
        return lx ** 2 + ly ** 2 <= (0.24 * s) ** 2
    if kind == "egg":
        return egg_mask(lx, ly, 0.42 * s, 0.6 * s) & ~egg_mask(lx, ly, 0.24 * s, 0.4 * s)
    if kind == "star":
        return astroid(lx, ly, 0.66 * s, 0.55)
    if kind == "leaf":
        lens = ((lx - 0.33 * s) ** 2 + ly ** 2 <= (0.6 * s) ** 2) & ((lx + 0.33 * s) ** 2 + ly ** 2 <= (0.6 * s) ** 2)
        return lens & ~((np.abs(lx) < 0.06 * s) & (ly > -0.35 * s))
    if kind == "feather":
        cr, sr = math.cos(0.35), math.sin(0.35)
        fx, fy = lx * cr + ly * sr, -lx * sr + ly * cr
        vane = ((fx - 0.22 * s) ** 2 + fy ** 2 <= (0.48 * s) ** 2) & ((fx + 0.22 * s) ** 2 + fy ** 2 <= (0.48 * s) ** 2)
        notch = (fy > 0.05 * s) & (fy < 0.14 * s) & (fx > 0)
        quill = (np.abs(fx) < 0.05 * s) & (fy > -0.62 * s) & (fy < 0.62 * s)
        return (vane & ~notch) | quill
    raise ValueError(kind)


def tex_rune_circle():
    """magic circle for hatch-scale reveals: bold double outer ring, a band of Peckwood glyphs (egg, feather, star,
    leaf, dots), ticks, a hexagram whose triangles kiss the inner circle, vertex rings, and an egg emblem with a crack.
    Lines are bold on purpose: it is seen 12-20 studs wide from a far, narrow camera."""
    c = Canvas(1024, ss=2)
    R, T = c.R, c.T
    lines = np.zeros(c.X.shape, bool)
    lines |= (R >= 0.905) & (R <= 0.945)
    lines |= (R >= 0.77) & (R <= 0.795)
    kinds = ["egg", "dot", "feather", "dot", "star", "dot", "leaf", "dot"] * 2
    for i, kind in enumerate(kinds):
        a = -math.pi / 2 + i * 2 * math.pi / len(kinds)
        cx, cy = math.cos(a) * 0.85, math.sin(a) * 0.85
        # local frame: ly points outward (radial), lx along the ring
        x, y = c.X - cx, c.Y - cy
        lx = x * -math.sin(a) + y * math.cos(a)
        ly = -(x * math.cos(a) + y * math.sin(a))
        lines |= glyph(lx, ly, kind, 0.095 if kind != "dot" else 0.07)
    for i in range(36):
        a = i * 2 * math.pi / 36
        long = i % 3 == 0
        d = np.abs((T - a + math.pi) % (2 * math.pi) - math.pi) * R
        lines |= (d < 0.009) & (R > (0.71 if long else 0.735)) & (R < 0.775)
    tri_r = 0.69
    verts = []
    for start in (-math.pi / 2, math.pi / 2):
        pts = [(math.cos(start + j * 2 * math.pi / 3) * tri_r, math.sin(start + j * 2 * math.pi / 3) * tri_r) for j in range(3)]
        verts += pts
        for j in range(3):
            (ax, ay), (bx, by) = pts[j], pts[(j + 1) % 3]
            ex, ey = bx - ax, by - ay
            L2 = ex * ex + ey * ey
            t = np.clip(((c.X - ax) * ex + (c.Y - ay) * ey) / L2, 0, 1)
            lines |= np.hypot(c.X - (ax + t * ex), c.Y - (ay + t * ey)) <= 0.014
    for vx, vy in verts:
        inside = c.circle(vx, vy, 0.07)
        lines &= ~inside
        lines |= inside & ~c.circle(vx, vy, 0.045)
        lines |= c.circle(vx, vy, 0.02)
    lines |= (R >= 0.33) & (R <= 0.358)
    # centre emblem: egg outline + zigzag crack + three dots above
    egg_o = egg_mask(c.X, c.Y - 0.01, 0.16, 0.22)
    egg_i = egg_mask(c.X, c.Y - 0.01, 0.125, 0.185)
    lines |= egg_o & ~egg_i
    zz = [(-0.16, 0.0), (-0.085, -0.06), (-0.02, 0.035), (0.045, -0.045), (0.1, 0.025), (0.16, -0.02)]
    for (ax, ay), (bx, by) in zip(zz, zz[1:]):
        ex, ey = bx - ax, by - ay
        t = np.clip(((c.X - ax) * ex + (c.Y - ay) * ey) / (ex * ex + ey * ey), 0, 1)
        lines |= (np.hypot(c.X - (ax + t * ex), c.Y - (ay + t * ey)) <= 0.013) & egg_o
    for dx in (-0.065, 0.0, 0.065):
        lines |= c.circle(dx, -0.285 + abs(dx) * 0.5, 0.02)
    c.paint(c.grow(lines, 0.016), INK)
    c.paint(lines, g(255))
    return c.image()


def tex_beam_streak():
    """beam strip, U (x, 256 px) along the beam, V (y, 64 px) across it: stepped core / mid / edge bands plus
    bright dashes that read as rising energy when TextureSpeed scrolls it. Seamless in U, empty top/bottom rows."""
    c = Canvas(256, 64, ss=4)
    ay = np.abs(c.Y)
    alpha = np.where(ay < 0.16, 1.0, np.where(ay < 0.42, 0.62, np.where(ay < 0.74, 0.3, 0.0)))
    rng = np.random.default_rng(5)
    for _ in range(9):
        y0 = rng.uniform(-0.6, 0.6)
        x0 = rng.uniform(-1, 1)
        ln = rng.uniform(0.18, 0.42)
        for off in (-2, 0, 2):  # wrap so the strip tiles in U
            dash = (np.abs(c.Y - y0) < 0.07) & (c.X >= x0 + off) & (c.X <= x0 + off + ln)
            alpha = np.where(dash & (ay < 0.74), np.maximum(alpha, 0.92), alpha)
    band = ((c.X + 1) * 4) % 2 < 1.0  # gentle stepped pulse bands along U (8 per tile)
    alpha = np.where(band & (alpha < 0.99), alpha * 0.82, alpha)
    c.paint(alpha > 0, g(255))
    c.a = c.a * alpha
    c.rgb = c.rgb * alpha[..., None]
    return c.image()


def tex_beam_runes():
    """rune band for beam rings: two border lines + Peckwood glyphs, white with ink, seamless in U (512 px = 8 slots).
    U runs along the ring, V across it (glyph 'up' = -V)."""
    c = Canvas(512, 64, ss=4)
    # work in output pixels for this strip (anisotropic normalized units)
    PX = (c.X + 1) / 2 * 512
    PY = (c.Y + 1) / 2 * 64
    lines = ((PY >= 8.5) & (PY <= 12.5)) | ((PY >= 51.5) & (PY <= 55.5))
    kinds = ["egg", "dot", "feather", "dot", "star", "dot", "leaf", "dot"]
    for i, kind in enumerate(kinds):
        cx = 32 + 64 * i
        lines |= glyph(PX - cx, PY - 32, kind, 30 if kind != "dot" else 22)
    # ink outline in pixel units: grow() measures in normalized x units -> 2 px = 2 / 256
    ink = ndimage.distance_transform_edt(~lines) <= 2.0 * c.ss
    c.paint(ink, INK)
    c.paint(lines, g(255))
    return c.image()


# ------------------------------------------------------------------------------------------------ main
def main():
    os.makedirs(OUT, exist_ok=True)
    print("writing", OUT)
    reg("smoke_puff", tex_smoke(), layout="Grid4x4", mode="OneShot", tint="baked-neutral",
        use="toon smoke puff: hatch crack ring, island-unlock dust, pet reveal poof")
    reg("impact_star", tex_impact(), layout="Grid4x4", mode="OneShot", tint="tint",
        use="star-burst / impact spike: hatch crack, level-up ding, collect (golden)")
    reg("sparkle", tex_sparkle(), layout="Grid4x4", mode="OneShot", tint="tint",
        use="sparkle twinkle: every effect")
    reg("shell_shards", tex_shards(), layout="Grid2x2", mode="Loop", tint="tint",
        use="eggshell shards tumbling out of the hatch (tint = egg colour)")
    reg("confetti", tex_confetti(), layout="Grid4x4", mode="Loop", tint="tint",
        use="paper confetti tumbling: hatch (Uncommon+), island unlock shower")
    reg("leaf", tex_leaf(), layout="Grid4x4", mode="Loop", tint="baked",
        use="tumbling leaf: island-unlock edge burst")
    reg("ring_shock", tex_ring_shock(), layout="None", tint="tint",
        use="flat ground shockwave: hatch crack, level-up, golden collect")
    reg("ring_thin", tex_ring_thin(), layout="None", tint="tint",
        use="thin pop ring: collect pop, level-up echo ring, hatch secondary ring")
    reg("glow_disc", tex_glow(), layout="None", tint="tint",
        use="stepped glow: egg glow build, flashes, pop cores (additive)")
    reg("light_rays", tex_rays(), layout="None", tint="tint",
        use="light-ray fan behind the hatch reveal (additive, slow spin)")
    reg("star", tex_star(), layout="None", tint="tint",
        use="little star bits: collect, hatch, level-up")
    reg("burst_lines", tex_burst_lines(), layout="None", tint="tint",
        use="impact lines on the hatch crack frame (Rare+)")
    reg("rune_circle", tex_rune_circle(), layout="None", tint="tint",
        use="magic circle under a Legendary/Mythic hatch (flat, spinning)")
    reg("beam_streak", tex_beam_streak(), layout="Beam", tint="tint",
        use="Beam texture: light pillars / level-up column (U along the beam, scroll with TextureSpeed)")
    reg("beam_runes", tex_beam_runes(), layout="Beam", tint="tint",
        use="Beam texture: rune band on the island-unlock magic circle rings (TextureMode Stretch)")
    man = {k: m for k, m in TEX}
    with open(os.path.join(OUT, "manifest.json"), "w") as fh:
        json.dump(man, fh, indent=1)
    if "--preview" in sys.argv:
        preview()


# ------------------------------------------------------------------------------------------------ QA preview
BGS = [(140, 192, 106), (42, 159, 224), (232, 217, 173), (27, 30, 38)]  # grass, sea, sand, night
TINTS = {"tint": [(255, 255, 255), (148, 216, 255), (255, 224, 102), (212, 166, 255)]}


def preview():
    os.makedirs(PREV, exist_ok=True)
    tile = 240
    rows = []
    for key, meta in TEX:
        img = Image.open(os.path.join(OUT, key + ".png")).convert("RGBA")
        w, h = img.size
        sc = tile / max(w, h)
        im = img.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
        arr = np.asarray(im).astype(np.float32) / 255
        tints = TINTS.get(meta["tint"], [(255, 255, 255)] * 4)
        row = Image.new("RGB", (tile * 4, tile), (0, 0, 0))
        for i, bg in enumerate(BGS):
            t = np.asarray(tints[i], np.float32) / 255
            base = np.ones((tile, tile, 3), np.float32) * (np.asarray(bg, np.float32) / 255)
            oy, ox = (tile - arr.shape[0]) // 2, (tile - arr.shape[1]) // 2
            reg_ = base[oy:oy + arr.shape[0], ox:ox + arr.shape[1]]
            a = arr[..., 3:4]
            reg_[:] = reg_ * (1 - a) + arr[..., :3] * t * a
            row.paste(Image.fromarray((base * 255).astype(np.uint8)), (i * tile, 0))
        d = ImageDraw.Draw(row)
        d.text((6, 4), key, fill=(0, 0, 0))
        rows.append(row)
    for part in range(0, len(rows), 5):
        chunk = rows[part:part + 5]
        out = Image.new("RGB", (tile * 4, tile * len(chunk)))
        for i, r in enumerate(chunk):
            out.paste(r, (0, i * tile))
        out.save(os.path.join(PREV, f"contact_{part // 5 + 1}.png"))
    print("preview ->", PREV)


if __name__ == "__main__":
    main()
