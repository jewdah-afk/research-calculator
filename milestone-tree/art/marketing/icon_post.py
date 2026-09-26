"""icon_post.py - finish the icon master (work/icon_1024.png from icon.js).

    cd art/marketing && python3 icon_post.py

out/icon_512.png     the upload: 512 x 512 RGB (Roblox rounds the corners itself)
out/icon_preview.jpg the icon at 512, 150 and 50 px side by side, square and with the rounded Roblox mask, on the
                     dark and the light site themes, so it can be checked at the sizes players see
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
WORK, OUT = os.path.join(HERE, "work"), os.path.join(HERE, "out")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"  # labels only


def rounded(im, radius_frac=0.11):
    """The icon as Roblox shows it on game cards (rounded corners)."""
    w, h = im.size
    mask = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), radius=int(w * 4 * radius_frac), fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def label_font(size):
    for f in (FONT,):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main():
    os.makedirs(OUT, exist_ok=True)
    master = Image.open(os.path.join(WORK, "icon_1024.png")).convert("RGB")
    icon = master.resize((512, 512), Image.LANCZOS)
    icon.save(os.path.join(OUT, "icon_512.png"), optimize=True)
    # the small sizes are made from the 512 upload, the way the site scales it
    sizes = [512, 150, 50]
    themes = [((25, 27, 29), (230, 232, 235)), ((242, 244, 245), (57, 59, 61))]  # Roblox dark / light site themes
    pad, gap = 48, 56
    W = pad * 2 + sum(sizes) + 150 + 50 + gap * 4 + 60
    row_h = 512 + 80
    H = row_h * 2
    sheet = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    f = label_font(22)
    for r, (bg, fg) in enumerate(themes):
        d.rectangle((0, r * row_h, W, (r + 1) * row_h), fill=bg)
        y0 = r * row_h + 20
        x = pad
        for i, s in enumerate(sizes):
            im = rounded(icon.resize((s, s), Image.LANCZOS))
            sheet.paste(im, (x, y0 + (512 - s) // 2 + 10), im)
            d.text((x, y0 + 512 + 26), f"{s} px", fill=fg, font=f)
            x += s + gap
        # the square (uncropped) versions at the two small sizes, for comparison
        for s in (150, 50):
            im = icon.resize((s, s), Image.LANCZOS)
            sheet.paste(im, (x, y0 + (512 - s) // 2 + 10))
            d.text((x, y0 + 512 + 26), f"{s} square", fill=fg, font=f)
            x += s + gap
    sheet.save(os.path.join(OUT, "icon_preview.jpg"), quality=92)
    print("out/icon_512.png, out/icon_preview.jpg")


if __name__ == "__main__":
    main()
