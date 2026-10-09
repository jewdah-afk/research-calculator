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


# ------------------------------------------------------------------------------------------------ v2 shapes
# Round-1 QA rules: additive / glow pieces carry NO ink (flash_star, swirl_arc, ring_wave, ring_snap, glow_step,
# rays_fan, speed_line, beam_core); ink only on normal-blend pieces (feather, ink_swirl, shards, stars, confetti, ...).

def tex_flash_star():
    """hero impact flash (billboard, additive): 4 long needle spikes + 4 short diagonals + core disc, two hard alpha
    bands. Drawn twice in game: tinted + bigger behind (rarity rim), white + Brightness > 1 in front (hot core)."""
    c = Canvas(512, ss=3)

    def shape(k):
        lx, ly = local(c, 0, 0, 0)
        long = astroid(lx, ly, 0.95 * k, 0.4)
        dlx, dly = local(c, 0, 0, math.pi / 4)
        short = astroid(dlx, dly, 0.56 * k, 0.48)
        return long | short | c.circle(0, 0, 0.2 * k)

    c.paint(shape(1.0), g(255), 0.62)
    c.paint(shape(0.66), g(255), 1.0)
    return c.image()


def arc_band(c, R, a_tail, a_head, w_max, cx=0.0, cy=0.0, lead=0.33):
    """crescent band along a circle: zero width at the tail, w_max at the rounded head; the outer side leads.
    Returns (band, edge) masks (edge = the outer leading strip)."""
    span = a_head - a_tail
    if span <= 1e-3 or w_max <= 1e-3:
        z = np.zeros(c.X.shape, bool)
        return z, z
    x, y = c.X - cx, c.Y - cy
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    d = (th - a_tail) % (2 * math.pi)
    inside = d <= span
    sp = np.clip(d / span, 0, 1)
    w = w_max * np.sin(sp * math.pi / 2) ** 0.85
    lo, hi = R - w * 0.72, R + w * 0.28
    band = inside & (r >= lo) & (r <= hi)
    hx, hy = math.cos(a_head) * (R - w_max * 0.22), math.sin(a_head) * (R - w_max * 0.22)
    band = band | c.circle(cx + hx, cy + hy, w_max * 0.5)
    edge = band & (r >= hi - np.maximum(w * lead, 0.012)) & inside
    return band, edge


def tex_swirl_arc():
    """4x4 crescent swirl (clip2 shape language): a tapered arc sweeps ~300 deg round the centre, grows, then the tail
    catches the head while it thins. Outer leading strip 255, body 120: with LightEmission 1 and Brightness > 1 the
    strip blows out white-hot while the body keeps the rarity colour. No ink (additive)."""
    frames = []
    for k in range(16):
        f = k / 15
        c = Canvas(256)
        head = -math.pi / 2 + 2 * math.pi * 0.84 * ease_out(f, 2)
        span = 2 * math.pi * 0.6 * math.sin(min(1.0, f / 0.94) * math.pi) ** 0.75
        w = 0.27 * (1 - 0.6 * f)
        R = 0.58 + 0.2 * ease_out(f, 2)
        band, edge = arc_band(c, R, head - span, head, w)
        if band.any():
            c.paint(band, g(120))
            c.paint(edge, g(255))
        frames.append(c.image())
    return sheet(frames, 4)


def tex_ink_swirl():
    """4x4 dark ink accent strokes (clip2's black swirls, our ink #16181e, normal blend): two thin brush crescents at
    two radii sweep round, offset in time, then thin away."""
    frames = []
    for k in range(16):
        f = k / 15
        c = Canvas(256)
        m = np.zeros(c.X.shape, bool)
        for R, ph, w0, delay in ((0.8, 0.0, 0.12, 0.0), (0.55, 2.4, 0.085, 0.12)):
            ff = min(1.0, max(0.0, (f - delay) / (1 - delay)))
            if ff <= 0:
                continue
            head = math.pi / 2 + ph + 2 * math.pi * 0.7 * ease_out(ff, 2)
            span = 2 * math.pi * 0.45 * math.sin(min(1.0, ff / 0.92) * math.pi) ** 0.8
            band, _ = arc_band(c, R * (0.9 + 0.1 * ff), head - span, head, w0 * (1 - 0.5 * ff))
            m |= band
        if m.any():
            c.paint(m, INK)
        frames.append(c.image())
    return sheet(frames, 4)


def tex_feather():
    """4x4 feather tumbling (Loop): asymmetric vane split lit / shade, quill, two notches, thin ink; tint per palette"""
    frames = []
    for k in range(16):
        sx, rot = tumble(k)
        c = Canvas(128)
        w = max(abs(sx), 0.1)
        lx, ly = local(c, 0, 0, rot + 0.3, w, 1)
        ly = ly + 0.05
        t = np.clip((ly + 0.62) / 1.04, 0, 1)
        prof = np.clip(np.sin(t * math.pi), 0, 1) ** 0.7
        x = lx + 0.07 * (t - 0.5) ** 2
        wl, wr = 0.27 * prof * (1 - 0.2 * t), 0.18 * prof
        vane = (ly >= -0.62) & (ly <= 0.42) & (x >= -wl) & (x <= wr)
        notch1 = (x < -0.05) & (np.abs(ly - (-0.04 + 0.28 * (x + 0.05))) < 0.022)
        notch2 = (x > 0.05) & (np.abs(ly - (0.16 - 0.28 * (x - 0.05))) < 0.02)
        vane &= ~(notch1 | notch2)
        quill = (np.abs(x) <= 0.028) & (ly >= -0.5) & (ly <= 0.74)
        m = vane | quill
        c.paint(c.grow(m, 0.06), INK)
        front = sx >= 0
        c.paint(vane & (x < 0), g(255 if front else 226))
        c.paint(vane & (x >= 0), g(212 if front else 190))
        c.paint(quill, g(168))
        frames.append(c.image())
    return sheet(frames, 4)


def tex_speed_line():
    """speed line / ember streak: a needle with a round head at the TOP (row 0) and a long tail, white core band +
    a translucent outer band, no ink. Use with Orientation VelocityParallel + Squash."""
    c = Canvas(256, ss=4)
    t = np.clip((c.Y + 0.94) / 1.88, 0, 1)
    hw = 0.085 * (1 - t) ** 0.85
    body = ((np.abs(c.X) <= hw) & (c.Y >= -0.86) & (c.Y <= 0.94)) | c.circle(0, -0.86, 0.085)
    core = ((np.abs(c.X) <= hw * 0.42) & (c.Y >= -0.86) & (c.Y <= 0.7)) | c.circle(0, -0.86, 0.04)
    c.paint(body, g(255), 0.55)
    c.paint(core, g(255), 1.0)
    return c.image()


def tex_ring_wave():
    """ground wave (flat particle): an UNEVEN crescent band (thick on one side, thin / broken on others) with a white
    leading (outer) edge, a translucent body and one faint inner step. No ink. Random Rotation per play."""
    c = Canvas(512, ss=3)
    th = c.T
    gth = 0.5 + 0.36 * np.cos(th - 0.5) + 0.2 * np.cos(2 * th + 1.3) + 0.1 * np.cos(3 * th - 0.4)
    gth = np.clip((gth - 0.12) / 0.95, 0, 1)
    t = 0.02 + 0.15 * gth
    R0 = 0.94
    live = gth > 0.02
    body = live & (c.R <= R0) & (c.R >= R0 - t)
    edge = live & (c.R <= R0) & (c.R >= R0 - np.minimum(0.03, t))
    inner = live & (c.R < R0 - t) & (c.R >= R0 - t - 0.06 * gth)
    c.paint(inner, g(255), 0.22)
    c.paint(body, g(255), 0.55)
    c.paint(edge, g(255), 1.0)
    return c.image()


def tex_ring_snap():
    """collect-pop ring snap: three tapered white arcs (a broken ring), no ink"""
    c = Canvas(256)
    m = np.zeros(c.X.shape, bool)
    for a0, a1 in ((0, 108), (124, 232), (248, 350)):
        A0, A1 = math.radians(a0), math.radians(a1)
        d = (c.T - A0) % (2 * math.pi)
        sp = np.clip(d / (A1 - A0), 0, 1)
        w = 0.085 * np.clip(np.sin(sp * math.pi), 0, 1) ** 0.6
        m |= (d <= A1 - A0) & (np.abs(c.R - 0.84) <= w / 2)
    c.paint(m, g(255))
    return c.image()


def tex_glow_step():
    """cel glow: THREE hard bands (1 / 0.5 / 0.2 alpha), crisp edges, white"""
    c = Canvas(256)
    for r, a in ((0.9, 0.2), (0.62, 0.5), (0.36, 1.0)):
        c.paint(c.R < r, g(255), a)
    return c.image()


def tex_rays_fan():
    """4x4 light-ray fan (OneShot): 18 thin rays shoot out (0-0.22), hold while the fan turns a little, then die by
    THINNING to hairlines. Three hard alpha steps along each ray. White, no ink (additive, tint warm)."""
    rng = np.random.default_rng(17)
    n = 18
    base = [(i * 2 * math.pi / n + rng.uniform(-0.05, 0.05), i % 2 == 0, rng.uniform(-0.05, 0.02)) for i in range(n)]
    frames = []
    for k in range(16):
        f = k / 15
        c = Canvas(256)
        L = ease_out(min(1.0, f / 0.22), 2)
        W = 1.0 if f < 0.5 else max(0.0, 1 - (f - 0.5) / 0.5) ** 1.3
        turn = 0.18 * f
        a_all = np.zeros(c.X.shape, np.float32)
        if W > 0.02:
            for a0, long, jit in base:
                reach = ((0.96 if long else 0.64) + jit) * L
                hw = (0.1 if long else 0.066) * W
                d = np.abs((c.T - a0 - turn + math.pi) % (2 * math.pi) - math.pi)
                taper = np.clip(1 - (c.R / max(reach, 1e-3)) ** 5, 0, 1)
                m = (d < hw * (0.45 + 0.55 * c.R) * (0.3 + 0.7 * taper)) & (c.R > 0.08) & (c.R < reach)
                step = np.where(c.R < 0.4, 1.0, np.where(c.R < 0.68, 0.6, 0.32))
                a_all = np.maximum(a_all, m * step)
        c.paint(a_all > 0, g(255))
        c.a = c.a * a_all
        c.rgb = c.rgb * a_all[..., None]
        frames.append(c.image())
    return sheet(frames, 4)


def tex_beam_core():
    """beam strip (U = 256 px along the beam, V = 64 across): clean stepped bands (core / mid / edge) + three long
    tapered streaks that read as energy flowing when TextureSpeed scrolls it. Seamless in U, empty top/bottom rows."""
    c = Canvas(256, 64, ss=4)
    av = np.abs(c.Y)
    alpha = np.where(av < 0.12, 1.0, np.where(av < 0.36, 0.62, np.where(av < 0.6, 0.26, 0.0)))
    for v0, u0, ln in ((-0.24, -0.8, 0.95), (0.2, 0.1, 0.8), (-0.05, 0.55, 0.6)):
        for off in (-2, 0, 2):
            u = (c.X - (u0 + off)) / ln
            lens = (u >= 0) & (u <= 1) & (np.abs(c.Y - v0) < 0.08 * np.sin(np.clip(u, 0, 1) * math.pi))
            alpha = np.where(lens, 1.0, alpha)
    c.paint(alpha > 0, g(255))
    c.a = c.a * alpha
    c.rgb = c.rgb * alpha[..., None]
    return c.image()


CRACKS = [
    # stage 1: one short zigzag across the upper shell
    [[(-0.3, -0.18), (-0.18, -0.26), (-0.06, -0.14), (0.06, -0.24), (0.2, -0.15)]],
    # stage 2: longer + a branch running up
    [[(-0.58, -0.08), (-0.42, -0.2), (-0.3, -0.18), (-0.18, -0.26), (-0.06, -0.14), (0.06, -0.24), (0.2, -0.15),
      (0.34, -0.26), (0.5, -0.12)],
     [(0.06, -0.24), (0.1, -0.38), (0.02, -0.5)]],
    # stage 3: right round the shell + three branches
    [[(-0.86, 0.0), (-0.72, -0.12), (-0.58, -0.08), (-0.42, -0.2), (-0.3, -0.18), (-0.18, -0.26), (-0.06, -0.14),
      (0.06, -0.24), (0.2, -0.15), (0.34, -0.26), (0.5, -0.12), (0.64, -0.2), (0.86, -0.04)],
     [(0.06, -0.24), (0.1, -0.38), (0.02, -0.5), (0.08, -0.62)],
     [(-0.42, -0.2), (-0.46, -0.02), (-0.36, 0.1)],
     [(0.5, -0.12), (0.46, 0.04), (0.56, 0.16)]],
]


def tex_crack(stage):
    """egg crack decal (stage 1-3, cumulative): ink zigzags with a white core line that glows the rarity colour
    (Decal.Color3 multiplies: ink stays ink, the core takes the tint)"""
    c = Canvas(512, ss=2)
    ink = np.zeros(c.X.shape, bool)
    core = np.zeros(c.X.shape, bool)
    for line in CRACKS[stage - 1]:
        for (ax, ay), (bx, by) in zip(line, line[1:]):
            ex, ey = bx - ax, by - ay
            t = np.clip(((c.X - ax) * ex + (c.Y - ay) * ey) / (ex * ex + ey * ey), 0, 1)
            d = np.hypot(c.X - (ax + t * ex), c.Y - (ay + t * ey))
            ink |= d <= 0.03
            core |= d <= 0.011
    c.paint(ink, INK)
    c.paint(core, g(255))
    return c.image()


# ------------------------------------------------------------------------------------------------ main
TEXTURES = [
    ("smoke_puff", tex_smoke, dict(layout="Grid4x4", mode="OneShot", tint="baked-neutral", use="PIL toon puff (fallback; the Blender flipbooks replace it)")),
    ("sparkle", tex_sparkle, dict(layout="Grid4x4", mode="OneShot", tint="tint", use="inked 4-point twinkle: ambient trickle in every effect")),
    ("shell_shards", tex_shards, dict(layout="Grid2x2", mode="Loop", tint="tint", use="eggshell pieces tumbling out of the hatch")),
    ("confetti", tex_confetti, dict(layout="Grid4x4", mode="Loop", tint="tint", use="paper confetti (reveal, unlock shower)")),
    ("leaf", tex_leaf, dict(layout="Grid4x4", mode="Loop", tint="baked", use="tumbling leaf: unlock coast bursts")),
    ("star", tex_star, dict(layout="None", tint="tint", use="inked star bits")),
    ("burst_lines", tex_burst_lines, dict(layout="None", tint="tint", use="inked impact needles on the crack frame (QA: keep this look)")),
    ("rune_circle", tex_rune_circle, dict(layout="None", tint="tint", use="magic circle (hatch Legendary+, island unlock)")),
    ("flash_star", tex_flash_star, dict(layout="None", tint="tint", use="HERO flash: white core + tinted rim, billboard, additive")),
    ("swirl_arc", tex_swirl_arc, dict(layout="Grid4x4", mode="OneShot", tint="tint", use="crescent swirl sweep (particle fallback of the mesh slash)")),
    ("ink_swirl", tex_ink_swirl, dict(layout="Grid4x4", mode="OneShot", tint="baked-ink", use="dark ink accent strokes behind the bright swirls")),
    ("feather", tex_feather, dict(layout="Grid4x4", mode="Loop", tint="tint", use="tumbling feather: reveal, level-up, unlock")),
    ("speed_line", tex_speed_line, dict(layout="None", tint="tint", use="speed lines + ember streaks (VelocityParallel + Squash)")),
    ("ring_wave", tex_ring_wave, dict(layout="None", tint="tint", use="flat ground wave: uneven crescent band, white leading edge")),
    ("ring_snap", tex_ring_snap, dict(layout="None", tint="tint", use="collect pop ring snap (billboard)")),
    ("glow_step", tex_glow_step, dict(layout="None", tint="tint", use="3-band cel glow (wind-up, halo, under the feet)")),
    ("rays_fan", tex_rays_fan, dict(layout="Grid4x4", mode="OneShot", tint="tint", use="light-ray fan behind the reveal, dies by thinning")),
    ("beam_core", tex_beam_core, dict(layout="Beam", tint="tint", use="Beam strip for pillars / the level-up column")),
    ("crack_1", lambda: tex_crack(1), dict(layout="Decal", tint="tint", use="egg crack decal, stage 1")),
    ("crack_2", lambda: tex_crack(2), dict(layout="Decal", tint="tint", use="egg crack decal, stage 2")),
    ("crack_3", lambda: tex_crack(3), dict(layout="Decal", tint="tint", use="egg crack decal, stage 3")),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a[7:].split(","))
    print("writing", OUT)
    mp = os.path.join(OUT, "manifest.json")
    old = json.load(open(mp)) if os.path.exists(mp) else {}
    for key, fn, meta in TEXTURES:
        if only and key not in only:
            if key in old:
                TEX.append((key, old[key]))
            continue
        reg(key, fn(), **meta)
    # Blender flipbooks (tools/vfx/gen_toon_flipbooks.py) register themselves in the manifest too: keep them
    have = {k for k, _ in TEX}
    for key, meta in old.items():
        if meta.get("blender") and key not in have:
            TEX.append((key, meta))
    with open(mp, "w") as fh:
        json.dump({k: m for k, m in TEX}, fh, indent=1)
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
        if not os.path.exists(os.path.join(OUT, key + ".png")):
            continue
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
