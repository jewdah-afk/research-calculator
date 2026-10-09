"""python3 birb-icons/redo_sheet.py <sheet_name> <url> name1..name16 : download, cut into final/, write a labelled review frame."""
import sys, subprocess
from PIL import Image, ImageDraw
H = 'birb-icons'; sheet, url, names = sys.argv[1], sys.argv[2], sys.argv[3:]
png = f'{H}/sheets/{sheet}.png'; subprocess.run(['curl', '-sL', '-o', png, url], check=True)
subprocess.run(['python3', f'{H}/cut_grid.py', png, '4', '4', *names], check=True, capture_output=True)
S = 150; real = [n for n in names if n != '-']; im = Image.new('RGBA', (8 * (S + 10) + 10, ((len(real) + 7) // 8) * (S + 32) + 10), (30, 32, 38, 255)); d = ImageDraw.Draw(im)
for k, n in enumerate(real):
    t = Image.open(f'{H}/final/{n}.png').resize((S, S)); x, y = 10 + (k % 8) * (S + 10), 10 + (k // 8) * (S + 32); im.paste(t, (x, y), t); d.text((x, y + S + 4), n[:24], fill=(220, 220, 220))
out = f'/tmp/claude-0/-home-user-research-calculator/ff032b4c-84bc-54ba-8e2f-789143dc59ef/scratchpad/{sheet}.png'; im.save(out); print(out)
