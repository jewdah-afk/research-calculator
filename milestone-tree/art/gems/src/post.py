"""post.py - sprite finishing (bloom, star sparkles, prestige rim glow, alpha bleed), cosmic background,
contact sheet and 96 px check sheet. Pure numpy + Pillow (display-referred sRGB, premultiplied maths)."""
import os, math, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(os.path.dirname(HERE), "lib", "fonts")
TREE = {
    "m": "#b35cff", "mm": "#d17aff", "em": "#e88af2", "p": "#6fc3ff", "pe": "#ff9a2e", "sp": "#5fe0ff",
    "pb": "#57e0b0", "pp": "#ff4d6d", "se": "#ff6a1f", "hp": "#7fd9ff", "ep": "#9be02c", "hb": "#6dffb0",
    "ap": "#8ff3f3", "mp": "#ff5a1f", "t": "#ffe93a", "pm": "#ff2e63", "pep": "#f2b04d", "cp": "#39ff14",
    "cm": "#1fbf4a", "ex": "#45e07f", "ach": "#ffc93c",
}
ORDER = list(TREE)
VARIANTS = [("m", "locked"), ("m", "ready"), ("p", "locked"), ("p", "ready"), ("t", "locked"), ("t", "ready")]


def rgb01(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# ------------------------------------------------------------------------------------------ image maths
def load_premult(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def blur(img, sigma):
    """Gaussian blur (FFT, zero padded) of HxW or HxWxC float arrays."""
    if sigma <= 0:
        return img.copy()
    two = img.ndim == 2
    x = img[..., None] if two else img
    h, w, c = x.shape
    p = int(math.ceil(sigma * 3))
    H, W = h + 2 * p, w + 2 * p
    yy = np.fft.fftfreq(H)[:, None]
    xx = np.fft.rfftfreq(W)[None, :]
    g = np.exp(-2 * (math.pi * sigma) ** 2 * (yy ** 2 + xx ** 2)).astype(np.float32)
    out = np.empty_like(x)
    for i in range(c):
        pad = np.zeros((H, W), np.float32)
        pad[p:p + h, p:p + w] = x[..., i]
        out[..., i] = np.fft.irfft2(np.fft.rfft2(pad) * g, s=(H, W))[p:p + h, p:p + w]
    return out[..., 0] if two else out


def add_light(pm, rgb):
    """Add emissive light (premultiplied, additive) - alpha grows so glow survives on any background."""
    out = pm.copy()
    out[..., :3] += rgb
    la = np.clip(rgb.max(-1), 0, 1)
    out[..., 3] = np.maximum(np.clip(pm[..., 3] + la * (1 - pm[..., 3]), 0, 1), np.clip(out[..., :3].max(-1), 0, 1))
    out[..., :3] = np.minimum(out[..., :3], out[..., 3:4])
    return out


def under(pm, layer):
    """Composite premultiplied `layer` underneath pm."""
    return pm + layer * (1 - pm[..., 3:4])


def star(size, cx, cy, L, inten, tint, angle=0.0, width=2.4, diag=0.38, halo=0.5):
    """4-point sparkle (+ fainter diagonal pair) as additive premultiplied RGB. L = arm length in px."""
    h, w = size
    r = int(L * 1.05) + 3
    x0, x1 = max(0, int(cx) - r), min(w, int(cx) + r + 1)
    y0, y1 = max(0, int(cy) - r), min(h, int(cy) + r + 1)
    out = np.zeros((h, w, 3), np.float32)
    if x0 >= x1 or y0 >= y1:
        return out
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs + 0.5 - cx, ys + 0.5 - cy
    rr = np.sqrt(dx * dx + dy * dy)

    def arms(ang, length, wid):
        ca, sa = math.cos(ang), math.sin(ang)
        u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        acc = 0
        for a_, b_ in ((u, v), (v, u)):
            t = np.clip(1 - np.abs(a_) / length, 0, 1)
            ww = wid * (0.2 + 0.8 * t ** 1.5)
            acc = acc + np.exp(-(b_ / ww) ** 2) * t ** 1.6
        return acc

    core = np.exp(-(rr / (L * 0.07 + 1.2)) ** 2) * 1.2
    glow = np.exp(-(rr / (L * 0.2)) ** 2) * halo + np.exp(-(rr / (L * 0.5)) ** 2) * halo * 0.25
    s = arms(angle, L, width) + diag * arms(angle + math.pi / 4, L * 0.45, width * 0.8)
    white = np.array([1, 1, 1], np.float32)
    ctint = white * 0.75 + tint * 0.25
    out[y0:y1, x0:x1] = (np.clip(s + core, 0, 1.5)[..., None] * ctint + glow[..., None] * tint) * inten
    return out


def bleed(pm):
    """Straight-alpha RGBA with colour bled into transparent pixels (no dark fringe under bilinear/mips)."""
    a = pm[..., 3]
    rgb = np.where(a[..., None] > 1e-6, pm[..., :3] / np.maximum(a[..., None], 1e-6), 0)
    fill = np.zeros_like(rgb)
    done = a > (0.5 / 255)
    for s in (2, 6, 18, 48):
        num = blur(pm[..., :3], s)
        den = blur(a, s)
        ok = (~done) & (den > 1e-4)
        fill[ok] = num[ok] / den[ok][:, None]
        done = done | ok
    out = np.concatenate([np.where((a > (0.5 / 255))[..., None], rgb, fill), a[..., None]], -1)
    return np.clip(out, 0, 1)


def save_straight(pm, path):
    Image.fromarray((bleed(pm) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


# ------------------------------------------------------------------------------------------ sprite finishing
# Sparkle anchors = the brightest glints of the render (identical for every colour: same mesh, same lights),
# in 512-px sprite coordinates: (x, y, arm length, intensity)
SPARKLES = [(102, 92, 80, 1.0), (393, 411, 44, 0.85), (165, 153, 30, 0.7), (256, 250, 26, 0.55),
            (410, 122, 20, 0.55), (440, 299, 14, 0.5), (96, 157, 12, 0.45)]


def finish_sprite(src, dst, hexcol, variant="base"):
    pm = load_premult(src)
    h, w = pm.shape[:2]
    k = w / 512.0
    tint = rgb01(hexcol)
    mask = pm[..., 3].copy()
    # bloom of near-white glints and the hot core ("whiteness" = min channel, so light hues such as yellow
    # do not bloom their whole body)
    wht = pm[..., :3].min(-1)
    thr = 0.62 if variant != "locked" else 0.85
    hi = np.clip((wht - thr) / (1 - thr), 0, 1)[..., None] * pm[..., :3]
    amt = {"base": 1.0, "ready": 1.8, "locked": 0.35}[variant]
    bloom = (blur(hi, 3 * k) * 0.35 + blur(hi, 10 * k) * 0.3 + blur(hi, 26 * k) * 0.25) * amt
    out = add_light(pm, bloom)
    # sparkles
    sp_gain = {"base": 1.0, "ready": 1.35, "locked": 0.3}[variant]
    for i, (x, y, L, it) in enumerate(SPARKLES):
        if variant == "locked" and i > 1:
            break
        out = add_light(out, star((h, w), x * k, y * k, L * k * (1.15 if variant == "ready" else 1.0),
                                  it * sp_gain, tint if variant != "locked" else np.array([0.8, 0.8, 0.85]),
                                  width=2.4 * k * (L / 80) ** 0.35))
    if variant == "ready":
        # prestige rim glow: layer-coloured halo hugging the bezel, composited underneath the gem
        hot = np.clip(tint * 0.92 + 0.08, 0, 1)
        halo = np.clip(blur(mask, 4 * k) * 1.0 + blur(mask, 12 * k) * 0.85 + blur(mask, 30 * k) * 0.6, 0, 1)
        ed = np.minimum.outer(np.minimum(np.arange(h), np.arange(h)[::-1]), np.minimum(np.arange(w), np.arange(w)[::-1]))
        halo *= np.clip(ed / (20 * k), 0, 1) ** 2          # fade to exactly 0 at the sprite border
        layer = np.concatenate([halo[..., None] * hot, halo[..., None]], -1)
        layer[..., 3] = np.clip(halo * 0.95, 0, 1)
        layer[..., :3] *= 0.95
        out = under(out, layer)
    save_straight(out, dst)
    return dst


# ------------------------------------------------------------------------------------------ cosmic background
def fbm(h, w, seed, scales=(4, 8, 16, 32, 64), amp=0.55):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    a, tot = 1.0, 0.0
    for s in scales[::-1]:
        small = rng.random((max(2, h // s + 2), max(2, w // s + 2))).astype(np.float32)
        im = Image.fromarray(small, "F").resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        acc += np.asarray(im)[s:s + h, s:s + w] * a
        tot += a
        a *= amp
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)


def cosmic_bg(w, h, seed=7):
    """Deep-space backdrop matching the tree map: navy-violet gradient, nebula wisps, stars, vignette."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xs / w, ys / h
    base = (np.array([0.020, 0.024, 0.060]) * (1 - v)[..., None] + np.array([0.045, 0.020, 0.075]) * v[..., None])
    n1 = fbm(h, w, seed, (8, 16, 32, 64, 128, 256))
    n2 = fbm(h, w, seed + 1, (8, 16, 32, 64, 128, 256))
    neb1 = np.clip((n1 - 0.52) * 3.0, 0, 1) ** 1.6
    neb2 = np.clip((n2 - 0.55) * 3.0, 0, 1) ** 1.6
    img = base + neb1[..., None] * np.array([0.20, 0.07, 0.32]) * 0.55 + neb2[..., None] * np.array([0.03, 0.14, 0.24]) * 0.5
    rng = np.random.default_rng(seed + 2)
    n = int(w * h / 1800)
    sx, sy = rng.random(n) * w, rng.random(n) * h
    sb = rng.random(n) ** 6
    stars = np.zeros((h, w), np.float32)
    np.add.at(stars, (sy.astype(int), sx.astype(int)), 0.25 + sb * 1.8)
    stars = blur(stars, 0.6) * 2.2 + blur(stars, 2.5) * 0.6
    img = img + stars[..., None] * np.array([0.85, 0.9, 1.0])
    r = np.sqrt((u - 0.5) ** 2 * (w / h) ** 2 * 0.6 + (v - 0.5) ** 2 * 1.0)
    img *= np.clip(1.15 - r * 0.9, 0.35, 1.1)[..., None]
    img = np.clip(img, 0, 1) ** (1 / 1.25)
    return img.astype(np.float32)


def over(bg, sprite_rgba, x, y, size):
    """Premultiplied-correct scaled 'over' of a straight-alpha sprite at (x, y) (top-left), size px."""
    im = sprite_rgba.convert("RGBa").resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    h, w = bg.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(w, x + size), min(h, y + size)
    sub = a[y0 - y:y1 - y, x0 - x:x1 - x]
    bg[y0:y1, x0:x1] = sub[..., :3] + bg[y0:y1, x0:x1] * (1 - sub[..., 3:4])
    return bg


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def contact_sheet(gem_dir, out, W=2400, H=1400):
    bg = cosmic_bg(W, H, seed=11)
    cols, cell_w = 7, (W - 80) // 7
    top, row_h = 170, 292
    gsz = 232
    labels = []
    items = [(k, "base") for k in ORDER] + VARIANTS
    for i, (k, var) in enumerate(items):
        r, c = divmod(i, cols)
        cx = 40 + c * cell_w + cell_w // 2 + (cell_w // 2 if r == 3 else 0)
        cy = top + r * row_h + (22 if r == 3 else 0)
        name = f"{k}.png" if var == "base" else f"{k}_{var}.png"
        spr = Image.open(os.path.join(gem_dir, name)).convert("RGBA")
        over(bg, spr, cx - gsz // 2, cy - 10, gsz)
        labels.append((cx, cy + gsz - 22, k, var))
    im = Image.fromarray((np.clip(bg, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    ft_t, ft_s = font("Audiowide-Regular.ttf", 50), font("Outfit-Bold.ttf", 24)
    ft_k, ft_h, ft_v = font("Audiowide-Regular.ttf", 34), font("Outfit-Bold.ttf", 19), font("Outfit-Bold.ttf", 20)
    d.text((56, 44), "THE MILESTONE TREE NG+", font=ft_t, fill=(236, 230, 255))
    d.text((58, 108), "LAYER GEMS  ·  radiant-cut crystal, inner glow, gold bezel  ·  512 px transparent sprites",
           font=ft_s, fill=(160, 160, 200))
    d.text((W - 56, 58), "21 layers  ·  locked / ready states", font=ft_s, fill=(160, 160, 200), anchor="ra")
    y_sep = top + 3 * row_h - 6
    d.line([(56, y_sep), (W - 56, y_sep)], fill=(70, 64, 110), width=2)
    d.text((58, y_sep + 8), "STATES", font=ft_h, fill=(150, 140, 200))
    for cx, y, k, var in labels:
        col = tuple(int(v * 255) for v in rgb01(TREE[k]))
        if var == "base":
            txt = k.upper() if k != "cp" else "CP · CR"
            d.text((cx, y), txt, font=ft_k, fill=col, anchor="ma", stroke_width=3, stroke_fill=(8, 8, 18))
            d.text((cx, y + 42), TREE[k].upper(), font=ft_h, fill=(150, 150, 185), anchor="ma")
        else:
            d.text((cx, y), k.upper(), font=ft_k, fill=col if var == "ready" else (150, 150, 165), anchor="ma",
                   stroke_width=3, stroke_fill=(8, 8, 18))
            d.text((cx, y + 42), "LOCKED" if var == "locked" else "CAN PRESTIGE", font=ft_v,
                   fill=(140, 140, 160) if var == "locked" else (255, 236, 170), anchor="ma")
    im.save(out, optimize=True)
    return out


def small_check(gem_dir, out, size=96):
    """Every sprite downscaled to `size` px (premultiplied Lanczos) on dark / mid-grey / light backgrounds."""
    items = [(k, "base") for k in ORDER] + VARIANTS
    cols, pad, lab = 9, 14, 18
    cw, ch = size + pad, size + pad + lab
    rows = (len(items) + cols - 1) // cols
    bands = [("dark cosmic", None), ("mid grey #5b6070", (0.357, 0.376, 0.439)), ("light #e9e9f0", (0.914, 0.914, 0.941))]
    band_h = rows * ch + 44
    W, H = cols * cw + 40, band_h * len(bands) + 20
    canvas = np.zeros((H, W, 3), np.float32)
    ft = font("Outfit-Bold.ttf", 13)
    ft_b = font("Outfit-Bold.ttf", 18)
    texts = []
    for b, (name, col) in enumerate(bands):
        y0 = 10 + b * band_h
        if col is None:
            canvas[y0:y0 + band_h - 6, :] = cosmic_bg(W, band_h - 6, seed=3 + b)
        else:
            canvas[y0:y0 + band_h - 6, :] = np.array(col, np.float32)
        texts.append((20, y0 + 10, f"{size} px  ·  {name}", col))
        for i, (k, var) in enumerate(items):
            r, c = divmod(i, cols)
            x = 20 + c * cw + pad // 2
            y = y0 + 38 + r * ch
            nm = f"{k}.png" if var == "base" else f"{k}_{var}.png"
            over(canvas, Image.open(os.path.join(gem_dir, nm)).convert("RGBA"), x, y, size)
            tag = k if var == "base" else f"{k} {'lock' if var == 'locked' else 'ready'}"
            texts.append((x + size // 2, y + size + 1, tag, col))
    im = Image.fromarray((np.clip(canvas, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for i, (x, y, t, col) in enumerate(texts):
        dark = col is not None and sum(col) > 1.5
        fill = (40, 40, 55) if dark else (215, 215, 235)
        if t.endswith("px") or "·" in t:
            d.text((x, y), t, font=ft_b, fill=fill)
        else:
            d.text((x, y), t, font=ft, fill=fill, anchor="ma")
    im.save(out, optimize=True)
    return out


if __name__ == "__main__":
    import sys
    cmd = sys.argv[1]
    if cmd == "sprite":
        finish_sprite(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else "base")
    elif cmd == "sheets":
        g = os.path.join(HERE, "out", "gems")
        contact_sheet(g, os.path.join(HERE, "out", "contact_sheet.png"))
        small_check(g, os.path.join(HERE, "out", "small_check.png"))
