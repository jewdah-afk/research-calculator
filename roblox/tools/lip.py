"""Figma button faces: remove the flat bottom (thin light line + thin dark band) and shade the lower part of the face
into a smooth, rounded 3D key (no hard lines). Reads assets/figma/btn_orig, writes assets/figma/btn."""
import glob, os
import numpy as np
from PIL import Image
SRC = 'assets/figma/btn_orig'; DST = 'assets/figma/btn'
for f in sorted(glob.glob(SRC + '/*.png')):
    a = np.asarray(Image.open(f).convert('RGBA')).astype(float)
    H, W = a.shape[:2]; cx = W // 2
    L = a[..., :3].mean(-1)
    y = H - 1
    while y > 0 and L[y, cx] < 30: y -= 1          # ink base + stroke
    dep_end = y
    band = range(max(0, dep_end - 14), dep_end + 1)
    line = max(band, key=lambda r: L[r, cx] - L[r - 3, cx])
    clean_top = line - 2
    out = a.copy()
    face = (a[..., 3] > 10) & (L > 24)
    # 1) erase line + thin band: copy each column's last clean face pixel down (keeps diagonal texture continuity roughly)
    for yy in range(clean_top, dep_end + 1):
        src = clean_top - 1 - ((yy - clean_top) % 6)
        m = face[yy] & face[src]
        out[yy, m, :3] = a[src, m, :3]
    # 2) smooth shading over the bottom 30% of the face: rounded key, no lines
    top = int(dep_end - (dep_end) * 0.30)
    for yy in range(top, dep_end + 1):
        t = (yy - top) / max(1, dep_end - top)
        shade = 1 - 0.42 * (t * t * (3 - 2 * t))
        m = face[yy]
        out[yy, m, :3] *= shade
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(os.path.join(DST, os.path.basename(f)))
