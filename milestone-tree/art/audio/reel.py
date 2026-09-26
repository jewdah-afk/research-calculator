"""reel.py - a short listening reel of the kit for a phone: one clean dark card per sound (its name, what plays it, its
waveform) while the sound plays, the big prestige last, then the ambience bed. The audio is cut from the decoded
sheets (art/audio/sheets/*.ogg), so it is exactly what the game plays.

    python3 art/audio/reel.py <out.mp4>          1080 x 1080, H.264 + AAC, under 20 s
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
from dsp import SR  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(os.path.dirname(HERE), "ui", "fonts")
W = H = 1080
VIOLET, GOLD, CRIMSON, TEAL = (138, 124, 255), (255, 194, 51), (255, 46, 99), (86, 214, 196)

# (sound, title, what plays it, card seconds, [(variant, at)], accent)
CARDS = [
    ("hover", "Hover", "Pointer over a card, node or button", 0.95, [(1, 0.05), (2, 0.3), (4, 0.55)], VIOLET),
    ("press", "Press", "Every button click", 0.85, [(1, 0.05), (2, 0.3), (3, 0.55)], VIOLET),
    ("tab", "Tab", "Switching a panel's tab", 0.75, [(1, 0.05), (2, 0.38)], VIOLET),
    ("panel_open", "Panel open", "A layer's panel slides in", 0.85, [(1, 0.05)], VIOLET),
    ("panel_close", "Panel close", "The panel closes", 0.65, [(1, 0.05)], VIOLET),
    ("buy", "Buy", "A purchase goes through (a quick combo climbs)", 1.35, [(1, 0.05), (2, 0.23), (3, 0.41), (4, 0.59)], VIOLET),
    ("toast", "Toast", "A milestone or achievement pops up", 0.95, [(1, 0.05)], VIOLET),
    ("error", "Error", "A locked button, a refused tap", 0.6, [(1, 0.05)], VIOLET),
    ("unlock", "Unlock", "A new layer wakes on the map", 1.45, [(1, 0.05)], GOLD),
    ("portal_loop", "Portal", "The Multiverse rift hums while it is on screen", 1.9, [(1, 0.0)], CRIMSON),
    ("prestige_small", "Prestige", "Every later prestige of a layer", 1.45, [(1, 0.05)], GOLD),
    ("prestige_big", "First prestige", "The first prestige of each layer: the big one", 3.55, [(1, 0.05)], GOLD),
    ("ambience", "Ambience", "The realm's air, softly under everything", 4.0, [(1, 0.0)], TEAL),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def card(i, n, title, sub, info, accent, env):
    im = Image.new("RGB", (W, H), (9, 8, 15))
    # a soft glow of the accent behind the title
    yy, xx = np.mgrid[0:H, 0:W]
    g = np.exp(-(((xx - W / 2) / 520) ** 2 + ((yy - 470) / 300) ** 2))
    base = np.array(im, dtype=float)
    for c in range(3):
        base[..., c] += g * accent[c] * 0.09
    im = Image.fromarray(base.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    m = 64
    hair = (58, 52, 80)
    d.rectangle([m, m, W - m, H - m], outline=hair, width=1)
    t = 26
    for (x, y, sx, sy) in ((m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)):
        d.line([(x, y), (x + sx * t, y)], fill=accent, width=3)
        d.line([(x, y), (x, y + sy * t)], fill=accent, width=3)
    small = font("montserrat-latin-700-normal.woff2", 26)
    mono = font("roboto-mono-latin-500-normal.woff2", 26)
    d.text((m + 36, m + 34), "THE MILESTONE TREE  ·  SOUND KIT", font=small, fill=(150, 144, 178))
    idx = "%02d / %02d" % (i, n)
    d.text((W - m - 36 - d.textlength(idx, font=mono), m + 34), idx, font=mono, fill=accent)
    big = font("montserrat-latin-800-normal.woff2", 104 if len(title) < 11 else 88)
    tw = d.textlength(title.upper(), font=big)
    d.text(((W - tw) / 2, 380), title.upper(), font=big, fill=(244, 242, 252))
    subf = font("montserrat-latin-600-normal.woff2", 34)
    sw = d.textlength(sub, font=subf)
    if sw > W - 2 * m - 60:
        subf = font("montserrat-latin-600-normal.woff2", 28)
        sw = d.textlength(sub, font=subf)
    d.text(((W - sw) / 2, 520), sub, font=subf, fill=(176, 170, 204))
    # the waveform of what plays on this card
    x0, x1, yc, hh = m + 60, W - m - 60, 760, 110
    cols = x1 - x0
    seg = max(1, len(env) // cols)
    mx = max(1e-9, float(env.max()))
    for k in range(cols):
        v = env[k * seg:(k + 1) * seg]
        a = float(v.max()) / mx if len(v) else 0.0
        h = max(1, int(a ** 0.7 * hh))
        d.line([(x0 + k, yc - h), (x0 + k, yc + h)], fill=tuple(int(c * (0.45 + 0.55 * a)) for c in accent))
    iw = d.textlength(info, font=mono)
    d.text(((W - iw) / 2, H - m - 80), info, font=mono, fill=(130, 124, 160))
    return im


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "sfx_reel.mp4")
    m = json.load(open(os.path.join(HERE, "sheets", "map.json")))
    sheets = {k: dsp.decode(os.path.join(HERE, v["file"])) for k, v in m["sheets"].items()}

    def clip(name, variant, loop_len=None):
        s = m["sounds"][name]
        a, ln = s["regions"][variant - 1]
        y = sheets[s["sheet"]]
        seg = y[:, int(round(a * SR)):int(round((a + ln) * SR))]
        if loop_len:
            reps = int(np.ceil(loop_len / ln))
            seg = np.concatenate([seg] * reps, axis=1)[:, :int(loop_len * SR)]
        return seg

    total = sum(c[3] for c in CARDS)
    audio = np.zeros((2, int((total + 1.0) * SR)))
    tmp = tempfile.mkdtemp()
    lines = []
    t = 0.0
    for i, (name, title, sub, dur, hits, accent) in enumerate(CARDS, 1):
        start = int(t * SR)
        card_audio = np.zeros((2, int(dur * SR) + SR * 4))
        for v, at in hits:
            if name == "portal_loop":
                x = dsp.fade_out(dsp.fade_in(clip(name, 1, dur), 0.25), 0.35) * dsp.undb(-2)
            elif name == "ambience":
                x = dsp.fade_out(dsp.fade_in(clip(name, 1, dur + 0.5), 0.8), 1.2)
            else:
                x = clip(name, v)
            card_audio = dsp.place(card_audio, x, at)
        # everything rings on; only the big prestige's long tail runs under the ambience card
        audio = dsp.place(audio, card_audio, t)
        env = np.abs(card_audio[:, :int(dur * SR)]).max(axis=0)
        L = m["sounds"][name]["lufs"]
        nv = len(m["sounds"][name]["regions"])
        info = ("%.1f LUFS" % L[0]) + (("  ·  %d variants" % nv) if nv > 1 else "") + ("  ·  seamless loop" if m["sounds"][name]["loop"] else "")
        path = os.path.join(tmp, "card%02d.png" % i)
        card(i, len(CARDS), title, sub, info, accent, env).save(path)
        lines.append("file '%s'\nduration %.3f" % (path, dur))
        t += dur
        _ = start
    lines.append("file '%s'" % os.path.join(tmp, "card%02d.png" % len(CARDS)))
    audio = audio[:, :int(total * SR)]
    audio = dsp.fade_out(audio, 0.6)
    Lr = dsp.loudness(audio)["integrated"]
    audio = audio * dsp.undb(-16 - Lr)
    if dsp.true_peak_db(audio) > -1.2:
        audio = dsp.limit(audio, -1.2)
    wav = os.path.join(tmp, "reel.wav")
    dsp.write_wav(wav, audio)
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("\n".join(lines) + "\n")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    subprocess.run([dsp.ffmpeg(), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-i", wav,
                    "-c:v", "libx264", "-preset", "slow", "-crf", "22", "-r", "30", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest", "-movflags", "+faststart", out], check=True)
    print("%s  %.1f s  %.0f KB  reel %.1f LUFS integrated" % (out, total, os.path.getsize(out) / 1024, dsp.loudness(audio)["integrated"]))


if __name__ == "__main__":
    main()
