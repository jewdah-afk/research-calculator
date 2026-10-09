"""Cut a 4x4 icon sheet on a WHITE background into transparent 256px PNGs. Background = white connected to the
sheet border; enclosed white stays (eyes, highlights). Edge pixels get alpha from their distance to white, so the
thin black outline is kept crisp with no white fringe.
python3 birb-icons/cut_white.py <sheet.png> <out_dir> name1..name16   ('-' skips a cell)"""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage as nd
OPEN_HOLES = ('avatar_frame', 'hook_', 'lure_', 'rod_', 'badge_regen', 'up_heart_regen', 'settings', 'teleport')
sheet, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
src = np.asarray(Image.open(sheet).convert('RGB')).astype(float); H, W = src.shape[:2]; ch, cw = H // 4, W // 4
white = src.min(2) > 235
lab, _ = nd.label(white); bg = np.isin(lab, np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]])) & white
bg = nd.binary_opening(bg, iterations=1)
fg = ~bg; fl, fn = nd.label(fg); os.makedirs(out, exist_ok=True)
for i, n in enumerate(names):
    if n == '-': continue
    r0, c0 = (i // 4) * ch, (i % 4) * cw
    cell = np.zeros(fg.shape, bool); cell[r0:r0 + ch, c0:c0 + cw] = True
    ids = [k for k in np.unique(fl[cell & fg]) if k and (fl[cell] == k).sum() > 0.5 * (fl == k).sum()]
    m = np.isin(fl, ids)
    if m.sum(): sz = nd.sum(m, fl, ids); m = np.isin(fl, [k for k, s in zip(ids, sz) if s > 0.002 * sz.max() and s > 30])
    if n.startswith(OPEN_HOLES):        # real see-through holes: big enclosed white areas become transparent
        hl, hn = nd.label(m & white)
        if hn: hs = nd.sum(np.ones_like(hl), hl, range(1, hn + 1)); m = m & ~np.isin(hl, 1 + np.where(hs > 3000)[0])
    ys, xs = np.nonzero(m); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb = src[y0:y1, x0:x1]; mm = m[y0:y1, x0:x1]
    # soft edge: background-adjacent fg pixels get alpha from how far they are from white
    a = mm.astype(float); edge = mm & ~nd.binary_erosion(mm)
    a[edge] = np.clip((255 - rgb[edge].min(1)) / 160, 0, 1)
    rgb2 = rgb.copy(); rgb2[edge] = np.minimum(rgb[edge], 40)          # edge pixels are outline ink
    im = Image.fromarray(np.dstack([rgb2, a * 255]).astype(np.uint8), 'RGBA')
    s = 256 * 0.98 / max(im.size); im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    c = Image.new('RGBA', (256, 256)); c.paste(im, ((256 - im.width) // 2, (256 - im.height) // 2), im); c.save(os.path.join(out, n + '.png'))
