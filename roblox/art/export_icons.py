# python3 art/export_icons.py <cut dir>  ->  art/icons/<name>.png (512, Roblox) and art/icons/ui/<name>.png (128, preview)
import sys, os
from PIL import Image
src = sys.argv[1]; here = os.path.dirname(os.path.abspath(__file__))
for f in sorted(os.listdir(src)):
    im = Image.open(os.path.join(src, f)).convert('RGBA')
    for px, d in ((512, 'icons'), (128, 'icons/ui')):
        os.makedirs(os.path.join(here, d), exist_ok=True)
        im.resize((px, px), Image.LANCZOS).save(os.path.join(here, d, f), optimize=True)
print('exported', len(os.listdir(src)))
