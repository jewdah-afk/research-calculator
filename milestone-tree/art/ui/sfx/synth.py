"""synth.py - the UI sound set, synthesised offline (numpy only; seeded, so every run writes the same audio).

  $B/venv/bin/python art/ui/sfx/synth.py [--only hover,buy] [--sheet]

Writes art/ui/sfx/<name>.wav (48 kHz 16-bit stereo) and <name>.ogg (Vorbis q5, via the imageio-ffmpeg binary), and
prints duration / peak / RMS per sound. Every sound peaks at or below -1 dBFS; the quiet UI ticks (hover, tab, press)
sit lower so they can repeat without fatigue. The palette: glassy bell partials (inharmonic ratios), filtered-noise
air, soft low bodies for weight, and a short stereo reverb, all in the realm's key (E major pentatonic).
"""
import os, sys, wave, subprocess, argparse
import numpy as np

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
TAU = 2 * np.pi
NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)          # MIDI -> Hz
E_PENTA = [64, 66, 68, 71, 73]                          # E F# G# B C#


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env_exp(n, attack=0.004, decay=0.3, hold=0.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0, 1) ** 0.7
    d = np.exp(-np.maximum(0, t - attack - hold) / max(decay, 1e-5))
    return a * d


def env_adsr(n, a, d, s, r, total):
    t = np.arange(n) / SR
    e = np.where(t < a, t / a, np.where(t < a + d, 1 - (1 - s) * (t - a) / d, s))
    rel = total - r
    e = np.where(t > rel, e * np.clip(1 - (t - rel) / r, 0, 1), e)
    return e


def bell(f, dur, decay=0.5, partials=((1, 1.0), (2.76, 0.35), (5.40, 0.18), (8.93, 0.08)), detune=0.0015, rng=None, attack=0.002):
    """Glass bell: inharmonic partials, higher ones decay faster, a slight detuned pair per partial (shimmer)."""
    rng = rng or np.random.default_rng(1)
    t = t_(dur)
    out = np.zeros_like(t)
    for k, (r, a) in enumerate(partials):
        ff = f * r
        if ff > SR * 0.45:
            continue
        dk = decay / (1 + 0.9 * k)
        ph = rng.random() * TAU
        e = env_exp(len(t), attack, dk)
        out += a * e * 0.5 * (np.sin(TAU * ff * (1 + detune) * t + ph) + np.sin(TAU * ff * (1 - detune) * t + ph * 1.3))
    f = max(1, int(len(t) * 0.3))                  # truncation never clicks: the last 30 % eases to zero
    out[-f:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f)))
    return out


def noise(n, rng):
    return rng.standard_normal(n)


def biquad(x, kind, f, q=0.707, gain_db=0.0):
    """RBJ biquad; f may be an array (time-varying cutoff, coefficients updated every 32 samples)."""
    f = np.broadcast_to(np.asarray(f, dtype=float), x.shape)
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    B = 32
    for s in range(0, len(x), B):
        w0 = TAU * min(max(f[s], 20.0), SR * 0.45) / SR
        al = np.sin(w0) / (2 * q)
        cw = np.cos(w0)
        if kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif kind == "hp":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        elif kind == "bp":
            b0, b1, b2 = al, 0.0, -al
        else:
            raise ValueError(kind)
        a0, a1, a2 = 1 + al, -2 * cw, 1 - al
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        for i in range(s, min(s + B, len(x))):
            xi = x[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, xi, y1, yi
            y[i] = yi
    return y


def fft_filter(x, lo=None, hi=None, soft=1.5):
    """Zero-phase band limit with smooth (octave-scaled) skirts."""
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR) + 1e-3
    m = np.ones_like(fr)
    if lo:
        m *= 1 / (1 + (lo / fr) ** (2 * soft))
    if hi:
        m *= 1 / (1 + (fr / hi) ** (2 * soft))
    return np.fft.irfft(X * m, len(x))


def reverb(x, rt=1.2, mix=0.25, pre=0.012, bright=6000.0, width=1.0, seed=5):
    """Stereo convolution reverb with a synthetic IR: decorrelated noise, exponential decay, darkening tail."""
    rng = np.random.default_rng(seed)
    n = int(rt * SR * 1.2)
    t = np.arange(n) / SR
    L = rng.standard_normal(n) * np.exp(-6.9 * t / rt)
    Rr = rng.standard_normal(n) * np.exp(-6.9 * t / rt)
    # darken over time: blend a low-passed copy in as the tail goes on
    Ll, Rl = fft_filter(L, hi=bright * 0.25), fft_filter(Rr, hi=bright * 0.25)
    k = np.clip(t / (rt * 0.5), 0, 1)
    L = fft_filter(L, hi=bright) * (1 - k) + Ll * k
    Rr = fft_filter(Rr, hi=bright) * (1 - k) + Rl * k
    Rr = L * (1 - width) + Rr * width
    pad = int(pre * SR)
    irL = np.concatenate([np.zeros(pad), L])
    irR = np.concatenate([np.zeros(pad), Rr])
    irL /= np.sqrt(np.sum(irL ** 2)) + 1e-9
    irR /= np.sqrt(np.sum(irR ** 2)) + 1e-9
    m = len(x) + len(irL)
    N = 1 << int(np.ceil(np.log2(m)))
    X = np.fft.rfft(x, N)
    wl = np.fft.irfft(X * np.fft.rfft(irL, N), N)[:m]
    wr = np.fft.irfft(X * np.fft.rfft(irR, N), N)[:m]
    dry = np.concatenate([x, np.zeros(m - len(x))])
    return np.stack([dry * (1 - mix) + wl * mix * 2.2, dry * (1 - mix) + wr * mix * 2.2])


def stereo(x, pan=0.0):
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    return np.stack([x * l * 1.41, x * r * 1.41])


def place(dst, src, at):
    """Mix src (mono or stereo) into dst (stereo) at time `at` seconds, growing dst if needed."""
    if src.ndim == 1:
        src = np.stack([src, src])
    src = src.copy()
    f = min(src.shape[1], int(0.008 * SR))          # every placed segment ends with an 8 ms fade (no clicks)
    src[:, -f:] *= np.linspace(1, 0, f)
    i = int(at * SR)
    need = i + src.shape[1]
    if need > dst.shape[1]:
        dst = np.concatenate([dst, np.zeros((2, need - dst.shape[1]))], axis=1)
    dst[:, i:need] += src
    return dst


def fade_tail(x, ms=30):
    n = int(ms * SR / 1000)
    x[:, -n:] *= np.linspace(1, 0, n) ** 2
    return x


def trim(x, thresh_db=-70):
    a = np.max(np.abs(x), axis=0)
    idx = np.where(a > 10 ** (thresh_db / 20))[0]
    end = idx[-1] + int(0.02 * SR) if len(idx) else x.shape[1]
    return x[:, :min(end, x.shape[1])]


def norm(x, peak_db=-1.0):
    p = np.max(np.abs(x))
    return x * (10 ** (peak_db / 20) / max(p, 1e-9))


# ------------------------------------------------------------------------------------------------ the sounds
def s_hover(rng):
    """Hover: a tiny glass tick-chime, bright and short."""
    x = bell(NOTE(88), 0.22, decay=0.07, partials=((1, 1), (2.76, 0.25), (5.4, 0.08)), rng=rng)
    x += 0.5 * bell(NOTE(95), 0.22, decay=0.05, partials=((1, 1), (2.76, 0.2)), rng=rng)
    x += 0.15 * fft_filter(noise(len(x), rng), lo=6000) * env_exp(len(x), 0.001, 0.008)
    return fade_tail(reverb(x, rt=0.5, mix=0.18, bright=9000), 20), -9.0


def s_press(rng):
    """Press: a tactile click with a small body and a metallic ping."""
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    click = fft_filter(noise(n, rng), lo=1800, hi=7000) * env_exp(n, 0.0005, 0.006)
    f = 210 * np.exp(-t / 0.03) + 95
    body = np.sin(TAU * np.cumsum(f) / SR) * env_exp(n, 0.001, 0.035)
    ping = bell(1760, 0.16, decay=0.04, partials=((1, 1), (2.76, 0.3)), rng=rng)
    x = 0.9 * click + 0.8 * body + 0.22 * ping
    return fade_tail(reverb(x, rt=0.35, mix=0.12), 15), -4.0


def s_open(rng):
    """Panel open: an upward airy whoosh that lands on a crystalline sparkle."""
    dur = 0.62
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = 350 * (9.0 ** (np.clip(t / 0.34, 0, 1) ** 1.3))
    air = biquad(noise(n, rng), "bp", fc, q=1.1)
    e = np.clip(t / 0.26, 0, 1) ** 2 * np.exp(-np.maximum(0, t - 0.26) / 0.09)
    x = stereo(air * e * 1.3, 0.0)
    for i, m in enumerate([76, 83, 88]):
        x = place(x, stereo(0.33 * bell(NOTE(m), 0.5, decay=0.22, rng=rng), (-0.3, 0.2, 0.4)[i]), 0.25 + 0.035 * i)
    out = reverb(x[0] + x[1], rt=1.0, mix=0.28, bright=8000)
    return fade_tail(trim(out), 40), -2.0


def s_close(rng):
    """Panel close: a quicker downward whoosh that settles with a soft low tap."""
    dur = 0.42
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = 3200 * (0.12 ** (np.clip(t / 0.28, 0, 1)))
    air = biquad(noise(n, rng), "bp", fc, q=1.0)
    e = np.clip(t / 0.05, 0, 1) * np.exp(-t / 0.13)
    tap = np.sin(TAU * np.cumsum(140 * np.exp(-t / 0.05) + 70) / SR) * env_exp(n, 0.002, 0.05)
    x = air * e * 1.2
    x = x + 0.7 * np.concatenate([np.zeros(int(0.16 * SR)), tap])[:n]
    x += 0.15 * bell(NOTE(64), dur, decay=0.12, rng=rng)
    return fade_tail(trim(reverb(x, rt=0.7, mix=0.2, bright=5000)), 30), -3.0


def s_tab(rng):
    """Tab switch: a soft two-note glass tap (a step up the scale)."""
    x = 0.8 * bell(NOTE(80), 0.28, decay=0.06, partials=((1, 1), (2.76, 0.25), (5.4, 0.06)), rng=rng)
    x = stereo(x, -0.1)
    x = place(x, stereo(0.7 * bell(NOTE(83), 0.26, decay=0.07, partials=((1, 1), (2.76, 0.25)), rng=rng), 0.1), 0.045)
    x = place(x, stereo(0.3 * fft_filter(noise(int(0.02 * SR), rng), lo=2500, hi=8000) * env_exp(int(0.02 * SR), 0.0005, 0.004)), 0.0)
    out = reverb(x[0] + x[1], rt=0.5, mix=0.16, bright=9000)
    return fade_tail(trim(out), 20), -7.0


def s_buy(rng):
    """Buy: a rising pentatonic shimmer of glass bells over a warm coin ping, sparkling air on top."""
    x = np.zeros((2, int(0.1 * SR)))
    notes = [76, 80, 83, 88, 92]
    for i, m in enumerate(notes):
        x = place(x, stereo(0.45 * bell(NOTE(m), 0.7, decay=0.3 - 0.03 * i, rng=rng), -0.5 + 0.25 * i), 0.028 * i)
    ping = bell(NOTE(76), 0.6, decay=0.28, partials=((1, 1), (2.0, 0.4), (3.0, 0.15), (4.2, 0.1)), rng=rng)
    x = place(x, stereo(0.4 * ping), 0.0)
    n = int(0.6 * SR)
    sp = fft_filter(noise(n, rng), lo=7000) * env_exp(n, 0.02, 0.18) * (0.5 + 0.5 * np.sin(TAU * 31 * np.arange(n) / SR))
    x = place(x, stereo(0.18 * sp, 0.2), 0.05)
    out = reverb(x[0] + x[1], rt=1.3, mix=0.3, bright=9000)
    return fade_tail(trim(out), 40), -1.5


def s_unlock(rng):
    """Unlock: stone cracks, the chain snaps, glass shards scatter (a shower of short high pings)."""
    dur = 1.0
    x = np.zeros((2, int(dur * SR)))
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    thump = np.sin(TAU * np.cumsum(120 * np.exp(-t / 0.04) + 48) / SR) * env_exp(n, 0.001, 0.09)
    crack = fft_filter(noise(n, rng), lo=400, hi=5000) * env_exp(n, 0.0005, 0.03)
    x = place(x, stereo(0.9 * thump + 0.8 * crack), 0.0)
    # chain: a few metallic clinks
    for i in range(5):
        f = rng.uniform(1100, 2600)
        c = bell(f, 0.25, decay=0.05, partials=((1, 1), (2.41, 0.5), (3.87, 0.3), (5.2, 0.2)), rng=rng)
        x = place(x, stereo(0.28 * c, rng.uniform(-0.7, 0.7)), 0.02 + 0.035 * i + rng.uniform(0, 0.02))
    # shards
    for i in range(46):
        at = 0.015 + rng.exponential(0.09)
        if at > 0.55:
            continue
        f = rng.uniform(2400, 9000)
        s = bell(f, 0.2, decay=rng.uniform(0.02, 0.07), partials=((1, 1), (2.76, 0.3)), rng=rng)
        x = place(x, stereo(0.22 * s * np.exp(-at / 0.3), rng.uniform(-0.9, 0.9)), at)
    hiss = fft_filter(noise(int(0.4 * SR), rng), lo=5000) * env_exp(int(0.4 * SR), 0.002, 0.08)
    x = place(x, stereo(0.25 * hiss), 0.0)
    out = reverb(x[0] + x[1], rt=1.1, mix=0.26, bright=9000)
    return fade_tail(trim(out), 40), -1.0


def _impact(rng, low=52.0, dur=0.9, k=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = low * 2.2 * np.exp(-t / 0.05) + low
    boom = np.sin(TAU * np.cumsum(f) / SR) * env_exp(n, 0.002, 0.28 * k)
    body = fft_filter(noise(n, rng), lo=60, hi=900) * env_exp(n, 0.001, 0.05 * k)
    return 1.0 * boom + 0.5 * body


def _choir(rng, root, dur, swell=0.5):
    """A choir-like pad: detuned saw stacks (a chord) through three vowel formants ("ah")."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in (root, root + 7, root + 12, root + 16, root + 19):
        f0 = NOTE(m)
        for dv in (-0.006, 0.0, 0.0065):
            vib = 1 + 0.004 * np.sin(TAU * (5.2 + rng.random()) * t + rng.random() * TAU)
            ph = np.cumsum(f0 * (1 + dv) * vib) / SR
            saw = 2 * (ph % 1.0) - 1
            out += saw / 15
    v = np.zeros(n)
    for fc, q, g in ((800, 6, 1.0), (1150, 7, 0.6), (2900, 9, 0.25)):
        v += g * biquad(out, "bp", fc, q=q)
    v = fft_filter(v, hi=5000)
    e = np.clip(t / swell, 0, 1) ** 1.5 * np.exp(-np.maximum(0, t - swell) / (dur * 0.35))
    return v * e


def s_prestige_big(rng):
    """First prestige: a deep impact + glass crash, a rising shimmer, a choir chord swelling, a sparkle cascade."""
    dur = 2.6
    x = np.zeros((2, int(dur * SR)))
    # rising pre-shimmer (the build, 0 - 0.28 s)
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    rise = biquad(noise(n, rng), "bp", 800 * (8 ** (t / 0.32)), q=2.0) * (t / 0.32) ** 2
    x = place(x, stereo(0.5 * rise), 0.0)
    T0 = 0.30
    x = place(x, stereo(1.1 * _impact(rng, 48, 1.2, 1.2)), T0)
    crash = fft_filter(noise(int(0.8 * SR), rng), lo=2500) * env_exp(int(0.8 * SR), 0.001, 0.16)
    x = place(x, stereo(0.35 * crash, 0.0), T0)
    for i, m in enumerate([64, 71, 76, 80, 83, 88]):
        x = place(x, stereo(0.28 * bell(NOTE(m), 1.6, decay=0.8, rng=rng), -0.6 + 0.24 * i), T0 + 0.01 * i)
    x = place(x, stereo(0.55 * _choir(rng, 52, 2.1, swell=0.45), 0.0), T0 + 0.05)
    # sparkle cascade
    for i in range(24):
        at = T0 + 0.2 + i * 0.045 + rng.uniform(0, 0.02)
        m = E_PENTA[i % 5] + 24 + 12 * ((i // 5) % 2)
        x = place(x, stereo(0.12 * bell(NOTE(m), 0.4, decay=0.12, rng=rng) * (1 - i / 30), rng.uniform(-0.8, 0.8)), at)
    out = reverb(x[0] + x[1], rt=2.2, mix=0.32, bright=8000, seed=9)
    return fade_tail(trim(out), 80), -1.0


def s_prestige_small(rng):
    """Every later prestige: the same gesture, shorter - a small rise, a lighter impact and one bell chord."""
    dur = 1.1
    x = np.zeros((2, int(dur * SR)))
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    rise = biquad(noise(n, rng), "bp", 1200 * (6 ** (t / 0.16)), q=2.0) * (t / 0.16) ** 2
    x = place(x, stereo(0.35 * rise), 0.0)
    T0 = 0.15
    x = place(x, stereo(0.6 * _impact(rng, 70, 0.5, 0.5)), T0)
    for i, m in enumerate([71, 76, 80, 83]):
        x = place(x, stereo(0.3 * bell(NOTE(m), 0.9, decay=0.35, rng=rng), -0.4 + 0.27 * i), T0 + 0.012 * i)
    for i in range(7):
        x = place(x, stereo(0.1 * bell(NOTE(E_PENTA[i % 5] + 24), 0.3, decay=0.1, rng=rng), rng.uniform(-0.7, 0.7)), T0 + 0.1 + 0.04 * i)
    out = reverb(x[0] + x[1], rt=1.2, mix=0.26, bright=8000)
    return fade_tail(trim(out), 50), -1.5


def s_toast(rng):
    """Toast: a gentle two-note chime (a fifth up), soft attack."""
    x = stereo(0.6 * bell(NOTE(76), 0.8, decay=0.3, attack=0.006, rng=rng), -0.2)
    x = place(x, stereo(0.55 * bell(NOTE(83), 0.8, decay=0.34, attack=0.006, rng=rng), 0.2), 0.09)
    out = reverb(x[0] + x[1], rt=1.0, mix=0.25, bright=7000)
    return fade_tail(trim(out), 40), -3.0


def s_error(rng):
    """Error: two muted low 'dun' tones stepping down, rounded (low-passed square), no harshness."""
    x = np.zeros((2, int(0.1 * SR)))
    for i, m in enumerate((57, 53)):
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        sq = np.sign(np.sin(TAU * NOTE(m) * t)) * 0.5 + np.sin(TAU * NOTE(m) * t)
        sq = fft_filter(sq, hi=900) * env_exp(n, 0.004, 0.06)
        x = place(x, stereo(0.8 * sq), 0.0 + 0.11 * i)
    out = reverb(x[0] + x[1], rt=0.4, mix=0.12, bright=4000)
    return fade_tail(trim(out), 30), -4.0


def s_portal_loop(rng):
    """Portal hum (seamless 4 s loop): a low drone with slow beating, breathing filtered air, faint glass shimmer.
    Every modulation completes whole cycles in 4 s, and the reverb tail is wrapped to the start."""
    L = 4.0
    n = int(L * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a in ((55.0, 0.5), (82.5, 0.3), (110.25, 0.22), (165.0, 0.08)):
        x += a * np.sin(TAU * f * t + rng.random() * TAU)
    x *= 0.8 + 0.2 * np.sin(TAU * 0.5 * t)
    lfo = 0.5 + 0.5 * np.sin(TAU * 0.25 * t)
    wind = np.real(np.fft.irfft(np.fft.rfft(noise(n, rng)) * 1, n))
    wind = fft_filter(wind, lo=250, hi=1400)
    x += 0.25 * wind * (0.4 + 0.6 * lfo)
    for f in (NOTE(88), NOTE(95), NOTE(100)):
        x += 0.03 * np.sin(TAU * f * t) * (0.5 + 0.5 * np.sin(TAU * 0.75 * t + rng.random() * TAU))
    out = reverb(x, rt=1.2, mix=0.3, bright=4000)
    tail = out[:, n:]
    out = out[:, :n].copy()
    out[:, :tail.shape[1]] += tail[:, :n]
    return out, -6.0


MAXLEN = dict(hover=0.32, press=0.26, panel_open=0.95, panel_close=0.62, tab=0.36, buy=1.3, unlock=1.3,
              prestige_small=1.35, prestige_big=3.2, toast=1.1, error=0.5)


def cap(x, dur):
    """Trim silence, then cap the length: the last 35 % fades out on a cosine so the tail never clicks."""
    x = trim(x, -52)
    n = min(x.shape[1], int(dur * SR))
    x = x[:, :n].copy()
    f = int(n * 0.35)
    x[:, n - f:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))) ** 1.5
    return x


def spectro_sheet(path, clips):
    """One spectrogram per sound (log frequency 60 Hz - 20 kHz, dB colour), stacked: a way to *see* the set."""
    from PIL import Image, ImageDraw
    rows = []
    for name, x in clips:
        m = x.mean(axis=0)
        nf, hop = 2048, 256
        frames = max(1, (len(m) - nf) // hop)
        win = np.hanning(nf)
        S = np.array([np.abs(np.fft.rfft(m[i * hop:i * hop + nf] * win)) for i in range(frames)]).T + 1e-9
        db = 20 * np.log10(S / S.max())
        fr = np.fft.rfftfreq(nf, 1 / SR)
        H = 160
        ys = np.geomspace(60, 20000, H)[::-1]
        idx = np.clip(np.searchsorted(fr, ys), 0, len(fr) - 1)
        img = np.clip((db[idx] + 80) / 80, 0, 1)
        W = max(1, int(x.shape[1] / SR * 400))
        rgb = np.stack([img ** 0.6 * 255, img ** 1.4 * 200, (1 - img) * img * 4 * 180 + img ** 3 * 255], -1).astype(np.uint8)
        im = Image.fromarray(rgb).resize((W, H))
        env = np.abs(m)
        rows.append((name, im, env))
    Wt = max(r[1].width for r in rows) + 180
    Ht = sum(r[1].height + 60 for r in rows)
    sheet = Image.new("RGB", (Wt, Ht), (10, 10, 16))
    d = ImageDraw.Draw(sheet)
    y = 0
    for name, im, env in rows:
        d.text((8, y + 8), name, fill=(220, 220, 230))
        sheet.paste(im, (170, y))
        # waveform envelope under it
        W = im.width
        seg = max(1, len(env) // W)
        pk = [env[i * seg:(i + 1) * seg].max() if (i + 1) * seg <= len(env) else 0 for i in range(W)]
        for i, v in enumerate(pk):
            h = int(v * 50)
            d.line([(170 + i, y + im.height + 55 - h), (170 + i, y + im.height + 55)], fill=(120, 200, 255))
        y += im.height + 60
    sheet.save(path)


SOUNDS = dict(hover=s_hover, press=s_press, panel_open=s_open, panel_close=s_close, tab=s_tab, buy=s_buy,
              unlock=s_unlock, prestige_small=s_prestige_small, prestige_big=s_prestige_big, toast=s_toast,
              error=s_error, portal_loop=s_portal_loop)


def write_wav(path, x):
    y = np.clip(np.round(x.T * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())


def ffmpeg():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--sheet", default="")
    a = ap.parse_args()
    clips = []
    names = [n for n in SOUNDS if not a.only or n in a.only.split(",")]
    ff = ffmpeg()
    for i, name in enumerate(names):
        rng = np.random.default_rng(1000 + list(SOUNDS).index(name))
        x, peak = SOUNDS[name](rng)
        if name in MAXLEN:
            x = cap(x, MAXLEN[name])
        x = x - x.mean(axis=1, keepdims=True)          # no DC
        x = norm(x, peak)
        clips.append((name, x))
        wav = os.path.join(HERE, name + ".wav")
        write_wav(wav, x)
        ogg = os.path.join(HERE, name + ".ogg")
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
        pk = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
        print(f"{name:15s} {x.shape[1] / SR:5.2f} s  peak {pk:6.1f} dBFS  rms {rms:6.1f} dBFS  "
              f"wav {os.path.getsize(wav) // 1024} KB  ogg {os.path.getsize(ogg) // 1024} KB")
    if name == "portal_loop" or "portal_loop" in [c[0] for c in clips]:
        lp = dict(clips).get("portal_loop")
        if lp is not None:
            print(f"portal_loop seam: |end - start| = {np.max(np.abs(lp[:, -1] - lp[:, 0])):.4f} (full scale 1)")
    if a.sheet:
        spectro_sheet(a.sheet, clips)


if __name__ == "__main__":
    main()
