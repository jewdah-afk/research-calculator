"""Turn an AI VFX flipbook on black into a Roblox-ready sheet: brightness becomes alpha, colour is un-premultiplied,
so the glow composites over any background without additive blending (Roblox GUI has none).
Run: python3 birb-icons/vfx_alpha.py <sheet.png> <out.png> [cols rows frame_list out_prefix]"""
import sys
import numpy as np
from PIL import Image

def to_alpha(img):
    a = np.asarray(img.convert('RGB')).astype(np.float32) / 255
    al = a.max(2)
    al = np.clip((al - 0.04) / 0.96, 0, 1)            # crush the near-black noise floor
    rgb = np.where(al[..., None] > 0, a / np.maximum(a.max(2, keepdims=True), 1e-4), 0)
    rgb = np.clip(rgb, 0, 1)
    return Image.fromarray(np.dstack([rgb, al]).__mul__(255).astype(np.uint8), 'RGBA')

if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    im = to_alpha(Image.open(src)); im.save(out)
    if len(sys.argv) > 3:
        cols, rows = int(sys.argv[3]), int(sys.argv[4]); frames = [int(f) for f in sys.argv[5].split(',')]; pre = sys.argv[6]
        cw, ch = im.width // cols, im.height // rows
        for f in frames:
            i = f - 1; im.crop(((i % cols) * cw, (i // cols) * ch, (i % cols + 1) * cw, (i // cols + 1) * ch)).save(f'{pre}_f{f:02d}.png')
