# icon_tree.py - icon option D: the game's own painted tree (a 1024 square render of the lit tree, plates and HUD
# hidden), saturated, vignetted to the tree and downscaled to 512; then out/icon_options.jpg compares A, B, D and C at
# 512 / 150 / 64 px. Render the still first:
#   node -e "require('./lib/snap').still({scene:'s13_none',cam:'1499,1060,0.52',size:'1024x1024',hide:['hud','plates'],out:'work/stills/icon_tree_a.png'})"
#   python3 icon_tree.py
from PIL import Image, ImageDraw, ImageEnhance
import numpy as np

im = Image.open('work/stills/icon_tree_a.png').convert('RGB')
im = ImageEnhance.Contrast(ImageEnhance.Color(im).enhance(1.25)).enhance(1.12)
a = np.asarray(im).astype(np.float32) / 255
h, w = a.shape[:2]
y, x = np.mgrid[0:h, 0:w]
r = np.sqrt(((x - 512) / 470) ** 2 + ((y - 480) / 560) ** 2)
a = a * np.clip(1 - (r - 0.62) * 1.6, 0.06, 1.0)[..., None]                     # dark edges: the eye goes to the tree
g = np.exp(-(((x - 512) / 240) ** 2 + ((y - 560) / 380) ** 2))[..., None] * np.array([0.18, 0.06, 0.28])
a = np.clip(a + g * 0.3, 0, 1)                                                   # a soft violet lift behind the trunk
Image.fromarray((a * 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS).save('out/icon_d_tree_render.png')

opts = [('A: gem (current)', 'icon_512.png'), ('B: number', 'icon_b_number.png'), ('D: the tree (render)', 'icon_d_tree_render.png'),
        ('C: tree (drawn)', 'icon_c_tree.png')]
sheet = Image.new('RGB', (len(opts) * 552 + 40, 800), (27, 29, 31))
d = ImageDraw.Draw(sheet)
def rounded(img, s):
    img = img.resize((s, s), Image.LANCZOS)
    m = Image.new('L', (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.12), fill=255)
    return img, m
for i, (label, f) in enumerate(opts):
    img = Image.open('out/' + f).convert('RGB')
    x0 = 40 + i * 552
    for s, (px, py) in [(512, (x0, 20)), (150, (x0, 560)), (64, (x0 + 180, 600))]:
        t, m = rounded(img, s)
        sheet.paste(t, (px, py), m)
    d.text((x0, 740), label, fill=(230, 230, 230))
sheet.save('out/icon_options.jpg', quality=92)
