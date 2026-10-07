"""Contact sheet on dark + light for QA: python3 birb-icons/qa.py out.png name1 name2 ..."""
import sys, os
from PIL import Image
names = sys.argv[2:]; n = len(names); c = min(8, n); r = (n + c - 1) // c
o = Image.new('RGBA', (c * 140, r * 280), (30, 32, 38, 255))
for i, nm in enumerate(names):
    im = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final', nm + '.png')).resize((128, 128))
    x, y = (i % c) * 140 + 6, (i // c) * 280 + 6
    o.paste(im, (x, y), im); o.paste((232, 232, 232, 255), (x, y + 136, x + 128, y + 264)); o.paste(im, (x, y + 136), im)
o.save(sys.argv[1])
