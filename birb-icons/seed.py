"""Hand-built sunflower seed icon (replaces the sheet cut, which was hidden behind the log on the sheet).
Same style as the set: navy body with cel bands, pale stripes, gloss, ink outline matching the cutter's ring."""
import cairosvg, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'final', 'seed.png')
# teardrop: round top, tapered tip at the bottom; tilted like the sheet's seed
body = "M256 66 C356 66 408 150 402 258 C396 352 318 432 262 474 C258 477 254 477 250 474 C194 432 112 352 110 258 C106 150 158 66 256 66 Z"
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="420" height="448" viewBox="46 40 420 448">
<defs>
  <linearGradient id="g" x1="0" y1="0" x2="1" y2="0.3">
    <stop offset="0" stop-color="#6a7cc0"/><stop offset="0.55" stop-color="#4a5a9c"/><stop offset="1" stop-color="#2c3770"/>
  </linearGradient>
  <clipPath id="c"><path d="{body}"/></clipPath>
</defs>
<g transform="rotate(-14 256 266)">
  <path d="{body}" fill="none" stroke="#0B0C10" stroke-width="30" stroke-linejoin="round"/>
  <path d="{body}" fill="url(#g)"/>
  <g clip-path="url(#c)">
    <path d="M300 60 C330 200 325 330 290 480 L370 480 C400 330 395 200 360 60 Z" fill="#26306a" opacity=".55"/>
    <path d="M236 50 C262 190 262 330 238 480 L270 480 C296 330 296 190 270 50 Z" fill="#dfe8fb"/>
    <path d="M246 50 C268 190 268 330 248 480 L256 480 C278 330 278 190 256 50 Z" fill="#ffffff" opacity=".7"/>
    <path d="M150 120 C165 230 168 330 196 450 L208 450 C182 330 178 230 166 110 Z" fill="#b9c6ee" opacity=".85"/>
    <path d="M350 110 C360 230 352 330 312 455 L322 458 C364 330 372 230 364 110 Z" fill="#9fb0e6" opacity=".55"/>
    <ellipse cx="172" cy="175" rx="26" ry="62" transform="rotate(18 172 175)" fill="#ffffff" opacity=".35"/>
    <path d="{body}" fill="none" stroke="#1b2350" stroke-width="10" opacity=".35"/>
  </g>
</g>
</svg>'''
cairosvg.svg2png(bytestring=svg.encode(), write_to=OUT, output_width=240, output_height=256)
print('wrote', OUT)

from PIL import Image                                   # pad to the set's 256x256 square
im = Image.open(OUT).transpose(Image.FLIP_TOP_BOTTOM); sq = Image.new('RGBA', (256, 256), (0, 0, 0, 0)); sq.paste(im, (8, 0), im); sq.save(OUT)
