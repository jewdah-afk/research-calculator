"""Thicken the ink outline of icons to match the original set (~11px at 256). python3 birb-icons/bolden.py names..."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage as nd
INK = np.array([11, 12, 16]); TARGET = 11
def ring(a):
    al = a[..., 3] > 128; dark = (a[..., :3].sum(-1) < 90) & al; ws = []
    for y in range(30, 226, 6):
        xs = np.where(al[y])[0]
        if not len(xs): continue
        x, w = xs[0], 0
        while x + w < 256 and dark[y, x + w]: w += 1
        ws.append(w)
    return float(np.median(ws)) if ws else TARGET
for n in sys.argv[1:]:
    f = f'birb-icons/final/{n}.png'; im = Image.open(f).convert('RGBA'); a = np.asarray(im).astype(float)
    add = int(round(TARGET - ring(a)))
    if add <= 0: print(n, 'ok'); continue
    pad = add + 2; big = np.zeros((256 + 2 * pad, 256 + 2 * pad, 4)); big[pad:pad + 256, pad:pad + 256] = a
    al = big[..., 3] / 255.0
    dist = nd.distance_transform_edt(al < 0.5)
    grow = np.clip(add + 0.5 - dist, 0, 1)                      # anti-aliased band of `add` px outside the old edge
    out = big.copy(); w = grow * (1 - al)
    out[..., :3] = big[..., :3] * al[..., None] + INK * w[..., None]
    out[..., :3] /= np.maximum(al + w, 1e-6)[..., None]
    out[..., 3] = np.clip(al + w, 0, 1) * 255
    o = Image.fromarray(out.astype(np.uint8), 'RGBA'); bb = o.getbbox(); o = o.crop(bb)
    s = 256 / max(o.size) * 0.98; o = o.resize((max(1, int(o.width * s)), max(1, int(o.height * s))), Image.LANCZOS)
    c = Image.new('RGBA', (256, 256)); c.paste(o, ((256 - o.width) // 2, (256 - o.height) // 2), o); c.save(f); print(n, '+', add)
