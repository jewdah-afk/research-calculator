"""look.py - see and measure sounds: a spectrogram contact sheet and a few numbers per clip.

    metrics(x) -> { dur, lufs_m, lufs_i, tp, centroid, centroid_attack, harsh, sub, crest }
        centroid           spectral centroid (Hz, energy-weighted over the clip)
        centroid_attack    the same over the first 60 ms (a bright, spitty attack shows here)
        harsh              share of the energy in 2.5-6 kHz (the band the ear finds sharp), in %
        sub                share below 120 Hz (inaudible on phones), in %
        crest              true peak minus momentary loudness (dB): how spiky it is
    sheet(path, clips)   clips = [(label, stereo array)], one row per clip: log-frequency spectrogram 40 Hz - 20 kHz,
                         the waveform envelope under it, the numbers at the left
"""
import numpy as np

import dsp
from dsp import SR


def _spec(m, nf=2048, hop=256):
    frames = max(1, (len(m) - nf) // hop + 1)
    if len(m) < nf:
        m = np.pad(m, (0, nf - len(m)))
        frames = 1
    win = np.hanning(nf)
    idx = np.arange(nf)[None, :] + hop * np.arange(frames)[:, None]
    return np.abs(np.fft.rfft(m[idx] * win, axis=1)) ** 2          # (frames, bins) power


def metrics(x):
    x = dsp.stereo(x)
    m = x.mean(axis=0)
    S = _spec(m)
    fr = np.fft.rfftfreq(2048, 1 / SR)
    tot = S.sum() + 1e-20
    cen = float((S.sum(axis=0) * fr).sum() / tot)
    k = max(1, int(0.06 * SR / 256))
    Sa = S[:k]
    cen_a = float((Sa.sum(axis=0) * fr).sum() / (Sa.sum() + 1e-20))
    band = lambda lo, hi: float(S[:, (fr >= lo) & (fr < hi)].sum() / tot * 100)
    L = dsp.loudness(x)
    tp = dsp.true_peak_db(x)
    return dict(dur=x.shape[1] / SR, lufs_m=L["momentary_max"], lufs_i=L["integrated"], tp=tp, centroid=cen,
                centroid_attack=cen_a, harsh=band(2500, 6000), sub=band(0, 120), mid=band(300, 4000), crest=tp - L["momentary_max"])


def line(label, mt):
    return ("%-18s %5.2f s  M %6.1f LUFS  TP %5.1f  crest %4.1f  cen %5.0f Hz (attack %5.0f)  2.5-6k %4.1f%%  <120 %4.1f%%  300-4k %4.1f%%"
            % (label, mt["dur"], mt["lufs_m"], mt["tp"], mt["crest"], mt["centroid"], mt["centroid_attack"], mt["harsh"], mt["sub"], mt["mid"]))


def sheet(path, clips, px_per_s=320, H=150):
    from PIL import Image, ImageDraw, ImageFont
    rows = []
    for label, x in clips:
        x = dsp.stereo(x)
        m = x.mean(axis=0)
        S = _spec(m, 2048, 192).T + 1e-14
        dbs = 10 * np.log10(S / S.max())
        fr = np.fft.rfftfreq(2048, 1 / SR)
        ys = np.geomspace(40, 20000, H)[::-1]
        idx = np.clip(np.searchsorted(fr, ys), 0, len(fr) - 1)
        img = np.clip((dbs[idx] + 90) / 90, 0, 1)
        W = max(8, int(x.shape[1] / SR * px_per_s))
        rgb = np.stack([img ** 0.55 * 255, img ** 1.5 * 190 + 20 * img, (1 - img) * img * 4 * 170 + img ** 3 * 255], -1)
        im = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).resize((W, H))
        rows.append((label, im, np.abs(m), metrics(x)))
    left = 250
    Wt = max(r[1].width for r in rows) + left + 20
    Ht = sum(r[1].height + 56 for r in rows) + 10
    out = Image.new("RGB", (Wt, Ht), (9, 8, 14))
    d = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 13)
    except Exception:
        font = ImageFont.load_default()
    y = 6
    for label, im, env_, mt in rows:
        d.text((10, y + 4), label, fill=(235, 232, 245), font=font)
        d.text((10, y + 24), "%.2f s   M %.1f LUFS" % (mt["dur"], mt["lufs_m"]), fill=(170, 165, 190), font=font)
        d.text((10, y + 42), "TP %.1f dB   crest %.1f" % (mt["tp"], mt["crest"]), fill=(170, 165, 190), font=font)
        d.text((10, y + 60), "centroid %.0f Hz" % mt["centroid"], fill=(170, 165, 190), font=font)
        d.text((10, y + 78), "2.5-6 kHz %.1f %%" % mt["harsh"], fill=(170, 165, 190), font=font)
        out.paste(im, (left, y))
        for f, lab in ((100, "100"), (1000, "1k"), (5000, "5k"), (10000, "10k")):
            yy = y + int((1 - np.log(f / 40) / np.log(20000 / 40)) * (H - 1))
            d.line([(left - 6, yy), (left - 1, yy)], fill=(120, 110, 150))
            d.text((left - 40, yy - 7), lab, fill=(120, 110, 150), font=font)
        W = im.width
        seg = max(1, len(env_) // W)
        mx = max(1e-9, env_.max())
        for i in range(W):
            v = env_[i * seg:(i + 1) * seg]
            h = int((v.max() if len(v) else 0) / mx * 38)
            d.line([(left + i, y + H + 44 - h), (left + i, y + H + 44)], fill=(110, 190, 255))
        y += H + 56
    out.save(path)
