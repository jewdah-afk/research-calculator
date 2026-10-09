"""Composite QA mock of the in-game HUD placement (no Studio needed).

Reads tools/ui_harness/layout_dump.json (written by `lune run tools/ui_harness/run.luau`: design-px rects of every HUD
piece, the sidebar and a docked window, computed by the real Hud / WindowManager code) and pastes Figma renders of
each component (get_screenshot PNGs, see REFS) into those rects on a 1920x1080 canvas. Use it to check line-up,
margins and overlaps against the Birb captures before the Studio pass.

usage: python mock.py <refs dir> <out.png> [--window]
refs dir holds <key>.png for every key in REFS (Figma renders at 1x, contentsOnly)."""
import json, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REFS = {   # dump key (group|component) -> ref file key
    "banner|hud/banner/the bridge": "banner", "wallet|hud/chip-main/popcorn": "chip_main",
    "wallet|hud/chip/plume": "chip_plume", "wallet|hud/chip/seed": "chip_seed", "wallet|hud/chip/moneta": "chip_moneta",
    "wallet|hud/chip/twig": "chip_moneta", "wallet|hud/chip/egg_golden": "chip_moneta", "wallet|hud/chip/ore": "chip_plume",
    "wallet|hud/chip/echo": "chip_plume", "wallet|hud/chip/skill_point": "chip_seed",
    "companions|hud/companions (open)": "companions", "auto|hud/auto/fish off": "auto", "auto|hud/auto/fish on": "auto",
    "auto|hud/auto/fish locked": "auto", "rail|hud/area rail": "rail",
    "context|hud/context/fishing": "context", "hotbar|hud/hotbar/fishing (ready)": "hotbar", "objective|hud/objective": "objective",
    "toast|hud/toast/info": "toast", "travel left|hud/travel/left": "left", "travel right|hud/travel/right": "right",
    "travel down|hud/travel/down": "down",
}
for t in ("map", "teleport", "fish", "profile", "shop", "settings", "auto", "pets"):
    REFS["tiles|hud/tile/" + t] = "tile_" + t
# Figma node sizes (unscaled) of each ref, to map the render (which includes overhangs / shadows) onto the node rect
NODE = {"banner": (372, 82), "chip_main": (390, 92), "chip_plume": (250, 70), "chip_seed": (250, 70), "chip_moneta": (250, 70),
        "companions": (300, 420), "auto": (196, 66), "rail": (100, 616), "context": (560, 106), "hotbar": (600, 86),
        "objective": (680, 64), "toast": (470, 76), "left": (170, 70), "right": (194, 70), "down": (180, 70)}
for t in ("map", "teleport", "fish", "profile", "shop", "settings", "auto", "pets"):
    NODE["tile_" + t] = (104, 119)
OVERHANG_LEFT = {"chip_main", "chip_plume", "chip_seed", "chip_moneta"}   # the wallet icon sticks out left / up


def main():
    refs, out = sys.argv[1], sys.argv[2]
    d = json.load(open(os.path.join(HERE, "layout_dump.json")))
    W, H = int(d["W"]), int(d["H"])
    img = Image.new("RGB", (W, H), (58, 132, 168))
    dr = ImageDraw.Draw(img)
    # game area / sidebar split
    gr = d["gameRight"]
    dr.rectangle([0, 0, gr, H], fill=(64, 148, 120))
    dr.line([gr, 0, gr, H], fill=(255, 255, 255), width=1)
    items = d["items"]
    def paste(key, rect, companions_header_only=False):
        ref = REFS.get(key)
        if not ref:
            return False
        path = os.path.join(refs, ref + ".png")
        if not os.path.exists(path):
            return False
        im = Image.open(path).convert("RGBA")
        nw, nh = NODE.get(ref, im.size)
        sx = rect[2] / nw
        iw, ih = im.size
        ox = (iw - nw) if ref in OVERHANG_LEFT else (iw - nw) / 2
        oy = (ih - nh) if ref in OVERHANG_LEFT else 0
        if companions_header_only:
            im = im.crop((0, 0, iw, int(62 * iw / nw)))
            ih = im.size[1]
        im = im.resize((max(1, int(iw * sx)), max(1, int(ih * sx))), Image.LANCZOS)
        img.paste(im, (int(rect[0] - ox * sx), int(rect[1] - oy * sx)), im)
        return True
    order = sorted(items.items(), key=lambda kv: (kv[0].startswith("window"), kv[0].startswith("sidebar")))
    for key, r in order:
        if key.startswith("sidebar"):
            sb = os.path.join(refs, "sidebar.png")
            if os.path.exists(sb):
                im = Image.open(sb).convert("RGBA")
                # the Figma drawer is 540x860; in game it stretches to full height: paste the top, extend the body
                s = r[2] / 540
                top = im.crop((0, 0, im.size[0], im.size[1]))
                top = top.resize((int(im.size[0] * s), int(im.size[1] * s)), Image.LANCZOS)
                dr.rectangle([r[0], r[1], r[0] + r[2], r[1] + r[3]], fill=(24, 30, 40))
                img.paste(top, (int(r[0] - 24 * s), int(r[1] - 24 * s)), top)
            continue
        if key.startswith("window"):
            if "--window" in sys.argv and key == "window|fishing":
                wp = os.path.join(refs, "window_fishing.png")
                if os.path.exists(wp):
                    im = Image.open(wp).convert("RGBA")
                    s = r[2] / 1150
                    im = im.resize((int(im.size[0] * s), int(im.size[1] * s)), Image.LANCZOS)
                    img.paste(im, (int(r[0] - 24 * s), int(r[1] - 24 * s)), im)
            continue
        if not paste(key, r, key.startswith("companions")):
            dr.rectangle([r[0], r[1], r[0] + r[2], r[1] + r[3]], outline=(255, 80, 80), width=2)
            dr.text((r[0] + 4, r[1] + 4), key.split("|")[1], fill=(255, 255, 255))
    # guides: shared top margin, edges, game-area centre
    top = d["top"]
    for y in (top, H - 24):
        dr.line([0, y, gr, y], fill=(255, 230, 0), width=1)
    for x in (24, gr / 2):
        dr.line([x, 0, x, H], fill=(255, 230, 0), width=1)
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
