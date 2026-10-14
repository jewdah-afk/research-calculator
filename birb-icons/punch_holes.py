"""Punch real see-through holes into cut icons (padlock shackle and keyhole, locket ring, gaps inside arrows, etc.).
Run: python3 birb-icons/punch_holes.py name1 name2 ...   (files in birb-icons/final/<name>.png)
A hole = a near-black region fully enclosed by the icon (it doesn't touch the transparent outside). It is cut to
alpha 0 and gets the same ink ring as the outer outline, so the cut edge reads like the rest of the icon."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
INK = np.array([11, 12, 16])

def punch(name, dark=40, min_area=25, ring=3, gap=3):
    p = os.path.join(HERE, 'final', name + '.png')
    im = np.asarray(Image.open(p).convert('RGBA')).astype(np.int32)
    rgb, a = im[..., :3], im[..., 3]
    solid = a > 8
    cand = solid & (rgb.max(2) < dark)
    # thin ink bridges (gaps in arrows, open arcs) join pockets to the outline: erode them away first
    core = nd.binary_erosion(cand, iterations=gap)
    lab, n = nd.label(core)
    outside = nd.binary_dilation(~solid, iterations=gap + 3)
    keep = np.zeros(a.shape, bool)
    for k in range(1, n + 1):
        reg = lab == k
        if reg.sum() < min_area or (reg & outside).any(): continue
        keep |= reg
    if not keep.any():
        return 0
    holes = nd.binary_dilation(keep, iterations=gap - 1) & cand
    edge = nd.binary_dilation(holes, iterations=ring) & ~holes & solid
    out = im.copy()
    out[holes, 3] = 0
    out[edge, :3] = INK; out[edge, 3] = 255
    Image.fromarray(out.astype(np.uint8)).save(p)
    return int(holes.sum())

if __name__ == '__main__':
    for nm in sys.argv[1:]:
        print(nm, punch(nm))
