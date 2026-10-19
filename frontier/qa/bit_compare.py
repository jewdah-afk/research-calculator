#!/usr/bin/env python3
"""Bit-style Reaper entrance: 1080p stills, a side-by-side sheet against the current game, and an
animated preview.

Run after `python3 run.py test_bitstyle.luau` (which writes qa/out/bit_reaper_*.png).

Usage: python3 bit_compare.py --ref DIR --dest DIR [--luau PATH] [--fps 30] [--secs 10]
  --ref   folder holding the current-game captures f_0.5.jpg, f_2.5.jpg, f_4.jpg, f_6.5.jpg, f_9.5.jpg
  --dest  where bit_reaper_compare.png, bit_reaper.mp4 and the bit_frames/ folder go
"""
import argparse
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
sys.dont_write_bytecode = True  # importing run.py must not leave a __pycache__ in qa/
sys.path.insert(0, HERE)
from run import parse  # noqa: E402  (same @@IMG protocol as the harness)

MOMENTS = [("0.5", "05"), ("2.5", "25"), ("4", "40"), ("6.5", "65"), ("9.5", "95")]
SCALE = 4  # 480x270 -> 1920x1080, nearest


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(os.path.join("/usr/share/fonts/truetype/dejavu", name), size)
    except OSError:
        return ImageFont.load_default()


def stills():
    """Every still upscaled 4x nearest to 1920x1080."""
    out = {}
    for _, tag in MOMENTS:
        im = Image.open(os.path.join(OUT, f"bit_reaper_{tag}.png")).convert("RGB")
        big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
        big.save(os.path.join(OUT, f"bit_reaper_{tag}_1080.png"))
        out[tag] = big
    return out


def sheet(big, ref_dir, dest):
    pw, ph = 640, 360
    gap, label_w, head = 12, 74, 44
    W = label_w + pw * 2 + gap * 3
    H = head + (ph + gap) * len(MOMENTS) + gap
    s = Image.new("RGB", (W, H), (12, 10, 20))
    d = ImageDraw.Draw(s)
    f_head, f_lab = font(20, True), font(18, True)
    x_left, x_right = label_w + gap, label_w + gap * 2 + pw
    d.text((x_left, 12), "Current game", fill=(220, 220, 230), font=f_head)
    d.text((x_right, 12), "Bit style (480x270 indexed, Luau)", fill=(255, 214, 92), font=f_head)
    for row, (t, tag) in enumerate(MOMENTS):
        y = head + row * (ph + gap)
        ref = Image.open(os.path.join(ref_dir, f"f_{t}.jpg")).convert("RGB").resize((pw, ph), Image.LANCZOS)
        # 1920 -> 640 is exactly 1/3: a box filter keeps each art pixel an even 4/3 px block
        bit = big[tag].resize((pw, ph), Image.BOX)
        s.paste(ref, (x_left, y))
        s.paste(bit, (x_right, y))
        d.text((12, y + ph // 2 - 10), f"{t} s", fill=(200, 196, 220), font=f_lab)
    path = os.path.join(dest, "bit_reaper_compare.png")
    s.save(path)
    return path


def animation(luau, dest, fps, secs):
    frames_dir = os.path.join(dest, "bit_frames")
    shutil.rmtree(frames_dir, ignore_errors=True)
    os.makedirs(frames_dir)
    p = subprocess.run(
        [luau, "--codegen", "-O2", "test_bitstyle.luau", "-a", "dump", str(fps), str(secs)],
        cwd=HERE, capture_output=True, timeout=900,
    )
    if p.returncode != 0:
        sys.exit("dump failed:\n" + p.stderr.decode("utf-8", "replace")[-2000:])
    _, _, images, _ = parse(p.stdout)
    for k, (_, w, h, raw) in enumerate(images):
        Image.frombytes("RGBA", (w, h), raw).convert("RGB").save(os.path.join(frames_dir, f"{k:04d}.png"))
    mp4 = os.path.join(dest, "bit_reaper.mp4")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(frames_dir, "%04d.png"),
         "-vf", "scale=1920:1080:flags=neighbor", "-c:v", "libx264", "-crf", "14", "-preset", "slow",
         "-pix_fmt", "yuv420p", mp4],
        check=True,
    )
    return mp4, len(images), frames_dir


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--luau", default=os.environ.get("LUAU", "luau"))
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--secs", type=int, default=10)
    ap.add_argument("--no-video", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    big = stills()
    print("sheet:", sheet(big, a.ref, a.dest))
    if not a.no_video:
        mp4, n, frames = animation(a.luau, a.dest, a.fps, a.secs)
        print(f"video: {mp4} ({n} frames, frames in {frames})")


if __name__ == "__main__":
    main()
