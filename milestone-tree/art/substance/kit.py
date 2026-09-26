#!/usr/bin/env python3
"""kit.py - the UI kit for Substance Painter: meshes to paint, guides, interim textures, and the atlas the game uses.

  python3 substance/kit.py prep     (from art/) meshes/ui_kit.obj (+ .mtl), guides/<slot>.png, base/<slot>.png
  python3 substance/kit.py build    painted/<slot>.png where you exported one, else base/<slot>.png
                                    -> out/ui_kit.png (1024 atlas) + ui_kit.json; then: node gems/upload.js --kit ui

The slots are 9-sliced in the game (ImageLabel ScaleType Slice): the corners inside `slice` px stay 1:1, the edges
stretch along one axis and the middle both ways, so paint detail into the corners and edges and keep the middle
calm. `tint` slots are multiplied by the layer hue in the game: paint those in greys (white = full hue). Each slot is
one texture set in ui_kit.obj; its UVs cover the top part of the square texture with the slot's own aspect, so
texels stay square; build crops that part out of the square export.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
# name: (w, h, chamfer, bevel, slice, tint, material, used by)
SLOTS = {
    "cta":    (512, 128, 22, 11, 36, True,  "metal",    "the panel's big action (PRESTIGE ...), the BUY bars, primary buttons: tinted with the layer hue"),
    "button": (384, 96,  16, 9, 28, False, "gunmetal", "secondary buttons (START, OPEN, dialog buttons), the close button"),
    "tile":   (160, 160, 18, 10, 44, False, "gunmetal", "the dock tiles (HOME, TROPHIES, OPTIONS)"),
    "panel":  (512, 512, 40, 6, 110, False, "glass",   "the layer panel's frame (the sheet)"),
    "plate":  (256, 128, 14, 4, 36, False, "glass",    "HUD plates: points capsule, toasts, READY tray"),
}
ATLAS = 1024
# shelf layout in the atlas (x, y)
PLACE = {"panel": (0, 0), "cta": (512, 0), "button": (512, 128), "tile": (512, 224), "plate": (672, 224)}
EXPORT = 2048  # the square texture-set resolution the README asks for


# ------------------------------------------------------------------------------------------------ shapes
def fields(w, h, c, ss=2):
    """supersampled: inside mask and the distance (px) to the chamfered edge"""
    W, H, C = w * ss, h * ss, c * ss
    y, x = np.mgrid[0:H, 0:W].astype(np.float64) + 0.5
    d = np.minimum.reduce([x, y, W - x, H - y, (x + y - C) / math.sqrt(2), ((W - x) + (H - y) - C) / math.sqrt(2)])
    return d / ss, ss


def down(a, ss):
    H, W = a.shape[:2]
    return a.reshape(H // ss, ss, W // ss, ss, *a.shape[2:]).mean(axis=(1, 3))


def texture(name):
    w, h, c, bev, _sl, tint, mat, _ = SLOTS[name]
    d, ss = fields(w, h, c)
    rng = np.random.default_rng(abs(hash(name)) % 2**32)
    H, W = d.shape
    alpha = np.clip(d * ss, 0, 1)                             # anti-aliased edge (in supersampled px)
    # a height field: flat top, falling over the bevel; its gradient lights it from the top-left
    hgt = np.clip(d / bev, 0, 1) ** 0.7
    gy, gx = np.gradient(hgt)
    n = np.dstack([-gx * bev * ss, -gy * bev * ss, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-0.45, -0.75, 0.5]); L /= np.linalg.norm(L)
    lam = np.clip((n * L).sum(axis=2), 0, 1)
    flat = float(L[2])
    shade = lam - flat                                         # 0 on the flat top, +/- on the bevel
    yy = np.linspace(0, 1, H)[:, None]
    # brushed grain: row noise stretched along x
    grain = rng.normal(0, 1, (H, W // 16 + 2))
    grain = np.array(Image.fromarray(((grain - grain.min()) / (np.ptp(grain) + 1e-9) * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)) / 255.0 - 0.5
    fine = rng.normal(0, 1, (H, W)) * 0.5
    if mat == "metal":            # light brushed metal (tinted in game)
        base = 0.86 - 0.18 * yy + 0.05 * grain + 0.012 * fine
        base += 0.10 * np.exp(-((yy - 0.18) ** 2) / 0.006)    # a soft gloss band near the top
        col = base + 0.9 * shade
        ink = 0.35
    elif mat == "gunmetal":       # dark machined metal
        base = 0.20 - 0.07 * yy + 0.03 * grain + 0.01 * fine
        col = base + 0.55 * shade
        ink = 0.08
    else:                         # dark glass slab
        base = 0.075 - 0.03 * yy + 0.012 * grain + 0.006 * fine
        col = base + 0.35 * shade
        ink = 0.02
    # rim light: the outermost pixel, brighter where it faces up
    up = np.clip(-n[:, :, 1] * 1.5 + 0.35, 0, 1)
    rim = np.exp(-((d - 0.6) ** 2) / 0.25)
    col = col + rim * (0.35 if mat == "metal" else 0.22) * up
    # an engraved line inset from the edge (dark groove with a lit lower lip)
    inset = {"metal": 5, "gunmetal": 5, "glass": 10}[mat]
    groove = np.exp(-((d - inset) ** 2) / 0.6)
    lip = np.exp(-((d - inset - 1.2) ** 2) / 0.5)
    col = col - groove * (0.18 if mat == "metal" else 0.06) + lip * (0.10 if mat != "glass" else 0.07)
    col = np.clip(col, 0, 1)
    a = alpha * (0.93 if mat == "glass" else 1.0)
    if tint:
        rgb = np.dstack([col, col, col])
    else:  # a cool steel cast, like the rest of the Sleek UI
        rgb = np.dstack([col * 0.94, col * 0.98, col * 1.06])
        rgb = np.clip(rgb, 0, 1)
    img = np.dstack([rgb, a])
    img = down(img, ss)
    return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------------------------------------ prep
def write_obj():
    os.makedirs(os.path.join(HERE, "meshes"), exist_ok=True)
    obj, mtl = ["mtllib ui_kit.mtl"], []
    vi = 1
    x0 = 0.0
    for name, (w, h, *_rest) in SLOTS.items():
        W, H = w / 100, h / 100
        vmax = h / w if w >= h else 1.0
        umax = 1.0 if w >= h else w / h
        obj += [f"o {name}", f"usemtl {name}",
                f"v {x0:.4f} 0 0", f"v {x0 + W:.4f} 0 0", f"v {x0 + W:.4f} {H:.4f} 0", f"v {x0:.4f} {H:.4f} 0",
                # the slot fills the TOP of the square texture (v = 1 is the top row in Painter)
                f"vt 0 {1 - vmax:.6f}", f"vt {umax:.6f} {1 - vmax:.6f}", f"vt {umax:.6f} 1", "vt 0 1",
                "vn 0 0 1", f"f {vi}/{vi}/1 {vi + 1}/{vi + 1}/1 {vi + 2}/{vi + 2}/1 {vi + 3}/{vi + 3}/1"]
        mtl += [f"newmtl {name}", "Kd 0.8 0.8 0.8", ""]
        vi += 4
        x0 += W + 0.5
    # normals are shared; one vn line per object is fine for Painter, but indices are global: fix them
    out, nv = [], 0
    for line in obj:
        if line.startswith("vn"):
            nv += 1
            out.append(line)
        elif line.startswith("f "):
            out.append(" ".join(p if "/" not in p else p.rsplit("/", 1)[0] + f"/{nv}" for p in line.split(" ")))
        else:
            out.append(line)
    open(os.path.join(HERE, "meshes", "ui_kit.obj"), "w").write("\n".join(out) + "\n")
    open(os.path.join(HERE, "meshes", "ui_kit.mtl"), "w").write("\n".join(mtl))


def write_guides():
    os.makedirs(os.path.join(HERE, "guides"), exist_ok=True)
    for name, (w, h, c, bev, sl, tint, mat, use) in SLOTS.items():
        S = 1024
        k = S / max(w, h)
        g = Image.new("RGBA", (S, S), (40, 44, 52, 255))
        d = ImageDraw.Draw(g)
        cw, ch = w * k, h * k
        d.rectangle((0, 0, cw, ch), fill=(70, 76, 90, 255))
        poly = [(c * k, 0), (cw, 0), (cw, ch - c * k), (cw - c * k, ch), (0, ch), (0, c * k)]
        d.polygon(poly, outline=(255, 255, 255, 255))
        for v in (sl * k, cw - sl * k):
            d.line((v, 0, v, ch), fill=(255, 190, 60, 255), width=2)
        for v in (sl * k, ch - sl * k):
            d.line((0, v, cw, v), fill=(255, 190, 60, 255), width=2)
        d.text((8, ch + 10), f"{name}: {w}x{h} px in game, 9-slice corners {sl} px (orange lines)", fill=(255, 255, 255, 255))
        d.text((8, ch + 28), ("TINTED by the layer hue: paint in greys" if tint else "painted colours are used as they are"), fill=(255, 220, 140, 255))
        d.text((8, ch + 46), f"used for: {use}", fill=(200, 210, 230, 255))
        d.text((8, ch + 64), "only the top area of the texture is on the mesh; the rest is unused", fill=(160, 170, 190, 255))
        g.save(os.path.join(HERE, "guides", f"{name}.png"))


def prep():
    write_obj()
    write_guides()
    os.makedirs(os.path.join(HERE, "base"), exist_ok=True)
    for name in SLOTS:
        texture(name).save(os.path.join(HERE, "base", f"{name}.png"))
    print("prep: meshes/ui_kit.obj, guides/, base/ (", ", ".join(SLOTS), ")")


# ------------------------------------------------------------------------------------------------ build
def painted(name):
    """a Painter export (square), cropped to the slot's UV area and resized; None when there is none"""
    w, h = SLOTS[name][:2]
    for cand in (f"{name}.png", f"ui_kit_{name}.png", f"{name}_BaseColor.png", f"ui_kit_{name}_BaseColor.png"):
        p = os.path.join(HERE, "painted", cand)
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            S = im.width
            if im.width == im.height:
                cw, ch = (S, round(S * h / w)) if w >= h else (round(S * w / h), S)
                im = im.crop((0, 0, cw, ch))
            return im.resize((w, h), Image.LANCZOS), cand
    return None, None


def build():
    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    meta = {"about": "substance/kit.py build: the UI kit atlas. rects [x, y, w, h]; slice = 9-slice corner px; tint = multiply by the layer hue.",
            "size": ATLAS, "slots": {}}
    for name, (w, h, c, bev, sl, tint, mat, use) in SLOTS.items():
        im, src = painted(name)
        if im is None:
            p = os.path.join(HERE, "base", f"{name}.png")
            im = Image.open(p) if os.path.exists(p) else texture(name)
            src = "base"
        x, y = PLACE[name]
        atlas.alpha_composite(im, (x, y))
        meta["slots"][name] = {"rect": [x, y, w, h], "slice": sl, "tint": tint, "source": src}
        print(f"  {name:7s} {w}x{h} from {src}")
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    atlas.save(os.path.join(HERE, "out", "ui_kit.png"), optimize=True)
    json.dump(meta, open(os.path.join(HERE, "ui_kit.json"), "w"), indent=1)
    print("build: out/ui_kit.png + ui_kit.json")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    {"prep": prep, "build": build}[cmd]()
