"""ambience.py - the realm's ambience bed (W6): a seamless 32 s loop for the Ambience bus. A soft airy pad that
breathes between two voicings of the pentatonic set (E add9 with a sixth, then C#m7: a slow I - vi, each held about
11 s), a faint wind, a breath of air and a few far-away glass glints. Voicings are open (fifths, thirds, fourths):
no sustained whole tone inside one critical band, so the pad never turns muddy or rough.

Seamless by construction: every sine runs a whole number of cycles in 32 s (frequencies snapped to 1/32 Hz), every
modulation completes whole cycles, the noise is filtered circularly and the reverb is a circular convolution, so the
last sample leads into the first exactly. The pitch set is the kit's key (E F# G# B C#): every UI cue is consonant
over it.

    python3 art/audio/ambience.py        writes art/audio/out/ambience_loop.wav (one period, raw level)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
from dsp import SR, TAU, midi_hz, hz, pan, tine  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
LOOP = 32.0

# (midi, weight in voicing A over E, weight in voicing B over C#)
VOICES = (
    (37, 0.0, 0.55),    # C#2
    (40, 0.55, 0.0),    # E2
    (44, 0.0, 0.42),    # G#2
    (47, 0.45, 0.0),    # B2
    (52, 0.55, 0.55),   # E3
    (56, 0.5, 0.0),     # G#3
    (59, 0.5, 0.5),     # B3
    (64, 0.0, 0.42),    # E4
    (66, 0.42, 0.0),    # F#4
    (68, 0.0, 0.36),    # G#4
    (71, 0.0, 0.24),    # B4
    (73, 0.24, 0.0),    # C#5
)


def bed(seed=77):
    rng = np.random.default_rng(seed)
    L = LOOP
    n = int(L * SR)
    t = np.arange(n) / SR
    q = lambda f: round(f * L) / L
    u = np.cos(np.pi * t / L) ** 2                        # 1 at the loop point, 0 in the middle (periodic)
    for _ in range(2):
        u = u * u * (3 - 2 * u)                         # smoothstep twice: long holds, 5 s moves between voicings
    wA, wB = u, 1 - u
    x = np.zeros((2, n))
    for i, (m, a, b) in enumerate(VOICES):
        f = midi_hz(m)
        w = np.sqrt(a * a * wA + b * b * wB)             # equal-power move between the voicings
        breath = 1 + 0.22 * np.cos(TAU * (1 + i % 3) * t / L + rng.random() * TAU)
        tilt = 0.8 if m < 45 else 1.0
        for k, d in enumerate((-0.0021, 0.0, 0.0024)):
            ff = q(f * (1 + d))
            s = (np.sin(TAU * ff * t + rng.random() * TAU) + 0.22 * np.sin(TAU * 2 * ff * t + rng.random() * TAU)
                 + 0.07 * np.sin(TAU * 3 * ff * t + rng.random() * TAU))
            p = (k - 1) * 0.6 + rng.uniform(-0.15, 0.15)
            x += pan(0.09 * tilt * s * w * breath, float(np.clip(p, -0.9, 0.9)))
    x = dsp.fft_filter_loop(x, lo=45, hi=2400, order=1.5)
    # air: a breath of pink noise in the upper mids, slowly swelling (two swells a loop)
    for c in range(2):
        a = dsp.fft_filter_loop(dsp.noise(n, rng, "pink"), lo=700, hi=4200, order=2)
        swell = 0.55 + 0.45 * np.cos(TAU * 2 * t / L + c * 0.8 + 1.3)
        x[c] += 0.04 * a * swell
    # wind: brown noise below 800 Hz with gusts (whole cycles of L/3, L/5, L/7)
    for c in range(2):
        wnd = dsp.fft_filter_loop(dsp.noise(n, rng, "brown"), lo=110, hi=800, order=2)
        g = sum(np.cos(TAU * k * t / L + rng.random() * TAU) / k for k in (3, 5, 7))
        g = (g - g.min()) / (g.max() - g.min())
        x[c] += 0.05 * wnd * (0.25 + 0.75 * g ** 1.6)
    # far glints: soft high tines, wrapped around the loop point
    for i in range(10):
        at = (i + rng.uniform(0.1, 0.9)) * L / 10
        d = int(rng.choice((15, 16, 17, 18, 19, 20)))
        g = tine(hz(d), 2.2, decay=0.7, index=0.6, idecay=0.03, attack=0.004, glass=0.05, rng=rng)
        x = dsp.place_loop(x, pan(0.03 * g, rng.uniform(-0.8, 0.8)), at)
    ir = dsp.make_ir(rt=4.2, pre=0.03, bright=5500, dark=1300, width=1.0, seed=41, length=4.8)
    x = dsp.reverb(x, ir, 0.42, loop=True)
    x = dsp.eq(x, [(60, 0), (8000, 0), (14000, -6)], loop=True)
    return x - x.mean(axis=1, keepdims=True)


def main():
    x = bed()
    out = os.path.join(HERE, "out", "ambience_loop.wav")
    dsp.write_wav(out, x / np.max(np.abs(x)) * 0.8)
    L = dsp.loudness(np.concatenate([x, x], axis=1))
    print("ambience %.1f s  I %.1f LUFS  seam |end-start| %.5f" % (x.shape[1] / SR, L["integrated"],
                                                                   np.max(np.abs(x[:, -1] - x[:, 0]))))


if __name__ == "__main__":
    main()
