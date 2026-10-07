"""Replace the generic red/white bobber on each rod icon with its themed bobber (bobbers/bob_<style>.png).
Rod art is untouched: only the old bobber blob (found from its red cap, line cut away by an opening) is erased."""
import numpy as np
from PIL import Image
from scipy import ndimage as nd
MAP = {'ancient': 'jade', 'banana': 'banana', 'blue': 'blue', 'carbon': 'gunmetal', 'coco': 'coco', 'divine': 'divine',
       'fiberglass': 'enamel', 'green': 'green', 'infernal': 'lava', 'lizard': 'snake', 'mechanic': 'mechanic', 'pirate': 'pirate',
       'prism': 'prism', 'pro': 'pro', 'reinforced': 'reinforced', 'roots': 'roots', 'rune': 'rune', 'shark': 'shark',
       'simple': 'wood', 'skeleton': 'skeleton', 'void_v2': 'void'}
for rod, sty in MAP.items():
    im = Image.open(f'final_old/rod_{rod}.png').convert('RGBA'); a = np.asarray(im).astype(int)
    al = a[..., 3] > 40
    red = (a[..., 0] > 170) & (a[..., 1] < 90) & (a[..., 2] < 90) & al
    # the bobber is the red blob in the upper-right quarter (where the line hangs)
    lab, n = nd.label(red)
    best, bs = None, 0
    for k in range(1, n + 1):
        ys, xs = np.nonzero(lab == k)
        if xs.mean() > 150 and ys.mean() < 150 and len(ys) > bs: best, bs = k, len(ys)
    if not best: print(rod, 'no bobber'); continue
    ys, xs = np.nonzero(lab == best)
    rx0, rx1, ry0, ry1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx = (rx0 + rx1) / 2; r = (rx1 - rx0) / 2 + 1
    cy = ry1                                   # red cap on top, white bottom: the float's centre is at the cap's lower edge
    R = r + 7                                  # + the ink ring
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    disc = (xx - cx) ** 2 + (yy - cy) ** 2 <= R * R
    out = a.copy(); out[disc, 3] = 0
    y0, y1, x0, x1 = int(cy - R), int(cy + R), int(cx - R), int(cx + R)
    o = Image.fromarray(out.astype(np.uint8), 'RGBA')
    b = Image.open(f'bobbers/bob_{sty}.png').convert('RGBA')
    bb = b.getbbox(); b = b.crop(bb)
    h = int((y1 - y0 + 1) * 1.08); w = int(b.width * h / b.height)
    b = b.resize((w, h), Image.LANCZOS)
    o.alpha_composite(b, (int(cx - w / 2), int(cy - h * 0.55)))
    # redraw the ink ring at the rods' weight (6 px at 256): the pasted bobber's own ring shrank with it
    na = np.asarray(o).astype(int)
    bm = np.zeros(na.shape[:2], bool)
    px, py = int(cx - w / 2), int(cy - h * 0.55)
    ba = np.asarray(b)[..., 3] > 100
    ys_, xs_ = np.nonzero(ba)
    ok = (ys_ + py >= 0) & (ys_ + py < 256) & (xs_ + px >= 0) & (xs_ + px < 256)
    bm[ys_[ok] + py, xs_[ok] + px] = True
    ring = nd.binary_dilation(bm, iterations=5) & ~bm & (na[..., 3] < 250)
    # anti-aliased edge: distance-based alpha on the outer pixel
    dist = nd.distance_transform_edt(~bm)
    na[ring, 0:3] = (11, 12, 16)
    na[ring, 3] = np.maximum(na[ring, 3], np.clip((5.6 - dist[ring]) * 255, 0, 255)).astype(int)
    o = Image.fromarray(na.astype(np.uint8), 'RGBA')
    o.save(f'final/rod_{rod}.png'); print(rod, sty, (x0, y0, x1, y1))
