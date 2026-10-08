"""Re-ring icons with a crisp, uniform ink outline (owner: outlines must match 1:1, clean, no soft halo).
For each 256 px icon: find the art core (opaque, non-ink pixels; enclosed holes filled so interior line art stays),
then draw a solid #0B0C10 ring exactly R px wide around it with a 1 px anti-aliased outer edge. Everything outside
the ring is transparent. Run: python birb-icons/clean_ring.py [names...]   (no names = every final/*.png)
Originals are kept in final_pre_ring/ the first time an icon is processed."""
import os, sys, shutil
import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, 'final')
BACKUP = os.path.join(HERE, 'final_pre_ring')
INK = np.array([11, 12, 16], float)
R = 6.0          # ring width in px at 256
OPEN_HOLES = ('avatar_frame', 'hook_', 'lure_', 'rod_', 'badge_regen', 'up_heart_regen')

def clean(path, name):
    src = os.path.join(BACKUP, os.path.relpath(path, FINAL))
    if not os.path.exists(src):
        os.makedirs(os.path.dirname(src), exist_ok=True); shutil.copy2(path, src)
    im = np.asarray(Image.open(src).convert('RGBA')).astype(float)
    rgb, a = im[..., :3], im[..., 3] / 255
    inkish = np.abs(rgb - INK).max(2) < 34
    core = (a > 0.9) & ~inkish
    core = nd.binary_opening(core, iterations=1)
    # keep the art's own dark line work: anything opaque that touches the core within 4 px belongs to the art
    near = nd.distance_transform_edt(~core) <= 4
    core = core | ((a > 0.9) & near & nd.binary_closing(core, iterations=3))
    if not name.startswith(OPEN_HOLES):
        core = nd.binary_fill_holes(core)
    lab, n = nd.label(core)
    if n > 1:   # drop specks
        sizes = nd.sum(core, lab, range(1, n + 1))
        core = np.isin(lab, 1 + np.flatnonzero(sizes >= max(30, sizes.max() * 0.004)))
    d = nd.distance_transform_edt(~core)
    ring_a = np.clip(R + 0.5 - d, 0, 1)
    out = np.zeros_like(im)
    out[..., :3] = INK
    out[..., 3] = ring_a * 255
    out[core, :3] = rgb[core]
    out[core, 3] = 255
    Image.fromarray(out.astype(np.uint8), 'RGBA').save(path)

if __name__ == '__main__':
    names = sys.argv[1:]
    files = []
    for root, _, fs in os.walk(FINAL):
        for f in fs:
            if f.endswith('.png') and (not names or f[:-4] in names):
                files.append(os.path.join(root, f))
    for p in files:
        clean(p, os.path.basename(p)[:-4])
    print('cleaned', len(files))
