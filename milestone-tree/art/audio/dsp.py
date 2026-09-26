"""dsp.py - the shared sound toolkit of art/audio (numpy only, no scipy): oscillators, envelopes, filters, a synthetic
room / hall reverb, a peak limiter, BS.1770-4 loudness and true peak, and WAV / OGG writing.

Everything runs at SR = 48 kHz on float64 arrays: mono (n,) or stereo (2, n). Filters are zero-phase FFT masks (fast
on long signals) except `biquad`, a per-sample RBJ filter for short time-varying sweeps. The reverb IRs are seeded,
so every build writes the same audio. `loop=True` variants treat the signal as periodic (circular convolution), which
is what makes the loops seamless.

The key of the realm: E major pentatonic (E F# G# B C#). P(d) is scale degree d counted from E3 (P(10) = E5).
"""
import os
import subprocess
import wave

import numpy as np

SR = 48000
TAU = 2 * np.pi
PENTA = (0, 2, 4, 7, 9)                                  # E F# G# B C#, semitones above E


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def P(d, base=52):
    """MIDI note of pentatonic degree d (0 = E3, 5 = E4, 10 = E5, 15 = E6)."""
    o, k = divmod(int(d), 5)
    return base + 12 * o + PENTA[k]


def hz(d):
    return midi_hz(P(d))


def t_(dur):
    return np.arange(int(round(dur * SR))) / SR


def db(x):
    return 20 * np.log10(np.maximum(np.abs(x), 1e-12))


def undb(g):
    return 10 ** (g / 20)


# ------------------------------------------------------------------------------------------------ envelopes
def env(n, attack=0.003, decay=0.3, hold=0.0, curve=None):
    """A smooth attack (a raised cosine: no infinite slope, so no broadband click), optional hold, exponential decay.
    `curve` (a power) replaces the cosine for deliberately sharp transients."""
    t = np.arange(n) / SR
    u = np.clip(t / max(attack, 1e-5), 0, 1)
    a = u ** curve if curve is not None else 0.5 - 0.5 * np.cos(np.pi * u)
    d = np.exp(-np.maximum(0, t - attack - hold) / max(decay, 1e-5))
    return a * d


def swell(n, rise, fall, shape=2.0):
    """Rises over `rise` s (ease-in), then falls exponentially with time constant `fall`."""
    t = np.arange(n) / SR
    up = np.clip(t / max(rise, 1e-5), 0, 1) ** shape
    return up * np.exp(-np.maximum(0, t - rise) / max(fall, 1e-5))


def fade_out(x, sec):
    """Cosine fade over the last `sec` seconds (in place on a copy)."""
    x = np.array(x, dtype=float)
    n = min(x.shape[-1], int(sec * SR))
    if n > 1:
        w = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
        x[..., -n:] *= w
    return x


def fade_in(x, sec):
    x = np.array(x, dtype=float)
    n = min(x.shape[-1], int(sec * SR))
    if n > 1:
        x[..., :n] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


# ------------------------------------------------------------------------------------------------ sources
def tine(f, dur, decay=0.35, index=1.1, idecay=0.035, ratio=1.0, attack=0.0025, detune=0.0012, glass=0.0,
         gdecay=0.02, rng=None):
    """An FM tine (the kit's voice): a sine carrier phase-modulated by a partial at `ratio` whose index falls fast,
    so the attack is bright and the body settles to a pure tone. `glass` adds a quiet inharmonic partial (x 4.07)
    that dies in `gdecay` (the glassy 'ding'). Two copies detuned by +-detune give a slow shimmer: they start in
    phase (a full, clean onset) and their beat is held under 0.7 Hz, so it breathes in a long tail and never wobbles
    inside a short note. Every partial starts at phase 0: identical onsets, no click."""
    t = t_(dur)
    n = len(t)
    out = np.zeros(n)
    I = index * np.exp(-t / max(idecay, 1e-4))
    d = min(detune, 0.35 / max(f, 1.0))
    copies = (1 + d, 1 - d) if d > 1e-7 else (1.0,)
    for s in copies:
        ff = f * s
        out += np.sin(TAU * ff * t + I * np.sin(TAU * ratio * ff * t)) / len(copies)
    if glass:
        fg = f * 4.07
        if fg < SR * 0.42:
            out += glass * np.sin(TAU * fg * t) * np.exp(-t / gdecay)
    e = env(n, attack, decay)
    return fade_out(out * e, min(0.03, dur * 0.3))


def sine_sweep(f0, f1, dur, tau=0.03):
    """A sine whose pitch falls (or rises) exponentially from f0 to f1 with time constant tau: thumps and tocks."""
    t = t_(dur)
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    return np.sin(TAU * np.cumsum(f) / SR)


def noise(n, rng, color="white"):
    """White, pink (-3 dB/oct) or brown (-6 dB/oct) noise, unit RMS."""
    w = rng.standard_normal(n)
    if color == "white":
        return w
    W = np.fft.rfft(w)
    fr = np.fft.rfftfreq(n, 1 / SR)
    fr[0] = fr[1] if len(fr) > 1 else 1.0
    W = W / (np.sqrt(fr) if color == "pink" else fr)
    y = np.fft.irfft(W, n)
    return y / (np.sqrt(np.mean(y ** 2)) + 1e-12)


# ------------------------------------------------------------------------------------------------ filters
def fft_filter(x, lo=None, hi=None, order=2.0, gain_db=None):
    """Zero-phase band limit: Butterworth-like magnitude skirts of `order` (2 = 12 dB/oct). Works on mono or
    stereo; the signal is zero-padded, so nothing wraps around."""
    x = np.asarray(x, dtype=float)
    n = x.shape[-1]
    N = 1 << int(np.ceil(np.log2(n + 4096)))
    X = np.fft.rfft(x, N)
    fr = np.fft.rfftfreq(N, 1 / SR) + 1e-3
    m = np.ones_like(fr)
    if lo:
        m *= 1 / np.sqrt(1 + (lo / fr) ** (2 * order))
    if hi:
        m *= 1 / np.sqrt(1 + (fr / hi) ** (2 * order))
    y = np.fft.irfft(X * m, N)[..., :n]
    return y


def fft_filter_loop(x, lo=None, hi=None, order=2.0):
    """fft_filter for a periodic signal (a loop): circular, so the loop point stays seamless."""
    x = np.asarray(x, dtype=float)
    n = x.shape[-1]
    X = np.fft.rfft(x, n)
    fr = np.fft.rfftfreq(n, 1 / SR) + 1e-3
    m = np.ones_like(fr)
    if lo:
        m *= 1 / np.sqrt(1 + (lo / fr) ** (2 * order))
    if hi:
        m *= 1 / np.sqrt(1 + (fr / hi) ** (2 * order))
    return np.fft.irfft(X * m, n)


def eq(x, points, loop=False):
    """A smooth zero-phase EQ curve: points = [(hz, dB), ...] interpolated in log frequency (flat outside)."""
    x = np.asarray(x, dtype=float)
    n = x.shape[-1]
    N = n if loop else 1 << int(np.ceil(np.log2(n + 4096)))
    X = np.fft.rfft(x, N)
    fr = np.maximum(np.fft.rfftfreq(N, 1 / SR), 1.0)
    fx = np.log([p[0] for p in points])
    gy = np.array([p[1] for p in points], dtype=float)
    g = np.interp(np.log(fr), fx, gy)
    y = np.fft.irfft(X * undb(g), N)
    return y if loop else y[..., :n]


def biquad(x, kind, f, q=0.707):
    """RBJ biquad, per sample; f may be an array (a sweep; coefficients update every 32 samples). For short sounds."""
    x = np.asarray(x, dtype=float)
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


# ------------------------------------------------------------------------------------------------ space
def make_ir(rt=1.2, pre=0.012, bright=7000.0, dark=1800.0, width=0.9, er=True, seed=5, length=None):
    """A stereo room / hall impulse response: sparse early reflections, then a diffuse tail whose highs die faster
    (a crossfade from a `bright`-limited to a `dark`-limited tail), -60 dB at `rt`. Unit energy per channel."""
    rng = np.random.default_rng(seed)
    n = int((length or rt * 1.15) * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.9 * t / rt)
    chans = []
    for c in range(2):
        tail = rng.standard_normal(n) * decay
        hi = fft_filter(tail, hi=bright, order=1.5)
        lo = fft_filter(tail, hi=dark, order=1.5)
        k = np.clip(t / (rt * 0.45), 0, 1) ** 0.8
        tail = hi * (1 - k) + lo * k
        # the tail builds up over ~25 ms (diffusion), under the early reflections
        tail *= np.clip(t / 0.025, 0, 1) ** 1.5
        if er:
            for i in range(9):
                d = 0.004 + rng.uniform(0, 0.045) + 0.003 * c
                j = int(d * SR)
                if j < n:
                    tail[j] += rng.choice((-1, 1)) * rng.uniform(0.25, 0.7) * np.exp(-6.9 * d / rt) * 3.0
        chans.append(tail)
    L, R = chans
    R = L * (1 - width) + R * width
    pad = np.zeros(int(pre * SR))
    L, R = np.concatenate([pad, L]), np.concatenate([pad, R])
    L /= np.sqrt(np.sum(L ** 2)) + 1e-12
    R /= np.sqrt(np.sum(R ** 2)) + 1e-12
    return np.stack([L, R])


def reverb(x, ir, mix=0.2, loop=False):
    """Convolve (mono or stereo) x with a stereo IR; returns stereo dry * (1 - mix) + wet * mix. With loop=True the
    convolution is circular over x's length (the tail wraps to the start: a seamless loop)."""
    x = np.asarray(x, dtype=float)
    if x.ndim == 1:
        x = np.stack([x, x])
    n = x.shape[1]
    if loop:
        m = n
        irs = ir[:, :n] if ir.shape[1] > n else np.pad(ir, ((0, 0), (0, n - ir.shape[1])))
        wet = np.stack([np.fft.irfft(np.fft.rfft(x[c]) * np.fft.rfft(irs[c]), n) for c in range(2)])
        return x * (1 - mix) + wet * mix
    m = n + ir.shape[1]
    N = 1 << int(np.ceil(np.log2(m)))
    wet = np.stack([np.fft.irfft(np.fft.rfft(x[c], N) * np.fft.rfft(ir[c], N), N)[:m] for c in range(2)])
    dry = np.pad(x, ((0, 0), (0, m - n)))
    return dry * (1 - mix) + wet * mix


def pan(x, p=0.0):
    """Equal-power pan of a mono signal (-1 left .. 1 right), unity at the centre."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a) * np.sqrt(2), x * np.sin(a) * np.sqrt(2)])


def stereo(x):
    return np.stack([x, x]) if np.ndim(x) == 1 else np.asarray(x)


def place(dst, src, at):
    """Mix src (mono or stereo) into the stereo dst at `at` seconds, growing dst if needed."""
    src = stereo(src)
    i = int(round(at * SR))
    need = i + src.shape[1]
    if need > dst.shape[1]:
        dst = np.pad(dst, ((0, 0), (0, need - dst.shape[1])))
    dst[:, i:need] += src
    return dst


def place_loop(dst, src, at):
    """Mix src into the periodic stereo dst at `at` seconds, wrapping past the end (for loops)."""
    src = stereo(src)
    n = dst.shape[1]
    i = int(round(at * SR)) % n
    idx = (np.arange(src.shape[1]) + i) % n
    np.add.at(dst[0], idx, src[0])
    np.add.at(dst[1], idx, src[1])
    return dst


def trim(x, thresh_db=-66, tail=0.015):
    """Cut the silence after the last sample above the threshold (+ a short margin)."""
    a = np.max(np.abs(x), axis=0)
    idx = np.where(a > undb(thresh_db) * max(a.max(), 1e-12))[0]
    end = idx[-1] + int(tail * SR) if len(idx) else x.shape[1]
    return x[:, :min(end, x.shape[1])]


def dc_block(x):
    return fft_filter(x, lo=18, order=1.0)


# ------------------------------------------------------------------------------------------------ loudness
def _k_weight_mag(fr):
    """|H(f)| of the BS.1770 K-weighting (the 48 kHz stage 1 shelf and stage 2 high-pass)."""
    z = np.exp(-1j * TAU * fr / SR)
    b1, a1 = (1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585)
    b2, a2 = (1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621)
    h1 = (b1[0] + b1[1] * z + b1[2] * z * z) / (a1[0] + a1[1] * z + a1[2] * z * z)
    h2 = (b2[0] + b2[1] * z + b2[2] * z * z) / (a2[0] + a2[1] * z + a2[2] * z * z)
    return np.abs(h1 * h2)


def k_weight(x):
    x = stereo(x)
    n = x.shape[1]
    N = 1 << int(np.ceil(np.log2(n + 8192)))
    X = np.fft.rfft(x, N)
    fr = np.fft.rfftfreq(N, 1 / SR)
    return np.fft.irfft(X * _k_weight_mag(fr), N)[:, :n]


def _blocks(y, win, hop):
    p = np.sum(y ** 2, axis=0)                      # channel weights 1, 1 (L, R)
    c = np.concatenate([[0.0], np.cumsum(p)])
    n = y.shape[1]
    if n < win:
        return np.array([c[-1] / win])
    starts = np.arange(0, n - win + 1, hop)
    return (c[starts + win] - c[starts]) / win


def lufs(z):
    return -0.691 + 10 * np.log10(np.maximum(z, 1e-20))


def loudness(x):
    """{ integrated, momentary_max, short_max } in LUFS (BS.1770-4 gating: -70 LUFS absolute, -10 LU relative)."""
    y = k_weight(x)
    zm = _blocks(y, int(0.4 * SR), int(0.1 * SR))
    zs = _blocks(y, int(3.0 * SR), int(0.1 * SR))
    lm = lufs(zm)
    g = zm[lm > -70]
    if len(g) == 0:
        integ = -120.0
    else:
        rel = lufs(np.mean(g)) - 10
        g2 = g[lufs(g) > rel]
        integ = float(lufs(np.mean(g2))) if len(g2) else -120.0
    return {"integrated": integ, "momentary_max": float(lm.max()), "short_max": float(lufs(zs).max())}


def true_peak_db(x, os_=4):
    """True peak (dBTP) by 4x FFT oversampling."""
    x = stereo(x)
    n = x.shape[1]
    N = 1 << int(np.ceil(np.log2(n + 64)))
    X = np.fft.rfft(x, N)
    Y = np.zeros((2, N * os_ // 2 + 1), dtype=complex)
    Y[:, :X.shape[1]] = X
    y = np.fft.irfft(Y, N * os_) * os_
    return float(db(np.max(np.abs(y))))


def limit(x, ceiling_db=-1.2, look=0.0015, release=0.06):
    """A look-ahead peak limiter (stereo-linked, on 4x-oversampled peaks): gain only ever dips where needed."""
    x = stereo(x).copy()
    n = x.shape[1]
    N = 1 << int(np.ceil(np.log2(n + 64)))
    X = np.fft.rfft(x, N)
    Y = np.zeros((2, N * 2 + 1), dtype=complex)
    Y[:, :X.shape[1]] = X
    up = np.fft.irfft(Y, N * 4)[:, :n * 4] * 4
    peak = np.max(np.abs(up), axis=0).reshape(n, 4).max(axis=1)
    c = undb(ceiling_db)
    need = np.minimum(1.0, c / np.maximum(peak, 1e-12))
    la = max(1, int(look * SR))
    # look-ahead: the gain reaches its minimum before the peak (a running minimum over the window ahead)
    g = need.copy()
    for k in range(1, la + 1):
        g[:-k] = np.minimum(g[:-k], need[k:])
    # smooth: instant attack (already ahead), exponential release
    out = np.empty(n)
    r = np.exp(-1 / (release * SR))
    cur = 1.0
    for i in range(n):
        gi = g[i]
        cur = gi if gi < cur else gi + (cur - gi) * r
        out[i] = cur
    return x * out


# ------------------------------------------------------------------------------------------------ files
def write_wav(path, x, bits=24):
    """Stereo WAV, 16- or 24-bit PCM (clipped at full scale)."""
    x = stereo(x)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    if bits == 16:
        y = np.clip(np.round(x.T * 32767), -32768, 32767).astype("<i2").tobytes()
    else:
        v = np.clip(np.round(x.T * 8388607), -8388608, 8388607).astype("<i4").reshape(-1)
        b = v.view(np.uint8).reshape(-1, 4)[:, :3]
        y = b.tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(bits // 8)
        w.setframerate(SR)
        w.writeframes(y)


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, n = w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        v = np.frombuffer(raw, "<i2").astype(float) / 32768
    elif sw == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3)
        v = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        v = np.where(v >= 1 << 23, v - (1 << 24), v).astype(float) / 8388608
    else:
        raise ValueError("unsupported sample width %d" % sw)
    return v.reshape(-1, ch).T


def ffmpeg():
    env_ff = os.environ.get("FFMPEG")
    if env_ff:
        return env_ff
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def encode_ogg(wav, ogg, q=6):
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q), ogg], check=True)


def decode(path):
    """Decode any file ffmpeg reads to stereo float at SR (to check what an encoded file really holds)."""
    r = subprocess.run([ffmpeg(), "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                       check=True, capture_output=True)
    return np.frombuffer(r.stdout, "<f4").astype(float).reshape(-1, 2).T
