"""python3 birb-icons/do_sheet.py <index 1..> <url>: download sheets/new_prompts.json[i] sheet, cut into final/, write a review frame."""
import json, sys, os, subprocess, urllib.request
from PIL import Image, ImageDraw, ImageFont
H = os.path.dirname(os.path.abspath(__file__)); i = int(sys.argv[1]) - 1
s = json.load(open(f'{H}/sheets/new_prompts.json'))[i]; png = f"{H}/sheets/{s['sheet']}.png"
subprocess.run(['curl', '-sL', '-o', png, sys.argv[2]], check=True)
subprocess.run(['python3', f'{H}/cut_grid.py', png, '4', '4', *s['names']], check=True, capture_output=True)
S = 150; n = len(s['names']); im = Image.new('RGBA', (8 * (S + 10) + 10, ((n + 7) // 8) * (S + 32) + 10), (30, 32, 38, 255)); d = ImageDraw.Draw(im)
for k, name in enumerate(s['names']):
    t = Image.open(f'{H}/final/{name}.png').resize((S, S)); x, y = 10 + (k % 8) * (S + 10), 10 + (k // 8) * (S + 32)
    im.paste(t, (x, y), t); d.text((x, y + S + 4), name[:24], fill=(220, 220, 220))
out = f"/tmp/claude-0/-home-user-research-calculator/ff032b4c-84bc-54ba-8e2f-789143dc59ef/scratchpad/{s['sheet']}.png"; im.save(out); print(out)
