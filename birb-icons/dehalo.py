"""Remove baked dark auras from final/ icons and redraw the standard 6px ink ring (cut_sheet.py method).
Interior = coloured pixels (plus enclosed darks), smoothed; everything outside it is replaced by a clean ring.
Usage: python dehalo.py [names...]   -> writes final_clean/<name>.png for review, --apply copies over final/."""
import sys, os, glob
import numpy as np
from PIL import Image
from scipy import ndimage as nd
INK = np.array([11, 12, 16.]); RING = 6.0

def dehalo(path):
    a = np.asarray(Image.open(path).convert('RGBA')).astype(float)
    al = a[..., 3]; rgb = a[..., :3]
    lum = rgb.mean(-1); sat = rgb.max(-1) - rgb.min(-1)
    vis = al > 40
    colored = vis & ~((lum < 75) & (sat < 80))
    lab, n = nd.label(colored); sizes = nd.sum(colored, lab, range(1, n + 1))
    big = np.isin(lab, 1 + np.where(sizes > 60)[0])
    m = nd.binary_closing(big, iterations=3)
    m = nd.binary_fill_holes(m)
    m = nd.binary_opening(m, iterations=1)
    # keep only the interior's own pixels; ring drawn outside it
    dist = nd.distance_transform_edt(~m)
    ring_a = np.clip(RING + 0.5 - dist, 0, 1)
    out = np.zeros_like(a)
    out[..., :3] = np.where(m[..., None], rgb, INK)
    out[..., 3] = np.where(m, np.maximum(al, 255 * (al > 40)), 255 * ring_a)
    # soften the colour edge into the ink like the cutter
    edge = m & (nd.distance_transform_edt(m) <= 1.2)
    out[..., :3][edge] = rgb[edge] * 0.35 + INK * 0.65
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

if __name__ == '__main__':
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    os.makedirs('final_clean', exist_ok=True)
    for name in args:
        im = dehalo(f'final/{name}.png')
        im.save(f'final_clean/{name}.png')
        if '--apply' in sys.argv: im.save(f'final/{name}.png')
