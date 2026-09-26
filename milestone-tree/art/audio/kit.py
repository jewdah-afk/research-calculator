"""kit.py - the UI sound kit (W6): 12 sounds, with variants for the frequent ones, synthesised offline (numpy; seeded,
so every run writes the same audio). pack.py loudness-balances them and packs the sprite sheets.

One palette for the whole kit, so it reads as one instrument:
  - the voice is an FM tine (dsp.tine): a bright, soft attack settling to a pure tone, never a raw oscillator edge;
  - every tonal note is in the realm's key, E major pentatonic (E F# G# B C#), so any two cues (and the ambience bed)
    are consonant together; high notes sound in arpeggios or open voicings, never as adjacent whole tones;
  - transients are short band-limited ticks and pitched 'tocks' at low level: they carry timing, not loudness;
  - one room (UI) and one hall (impacts) reverb, the same seeds, short tails for UI.

    python3 art/audio/kit.py [--only hover,buy]     writes art/audio/out/kit/<name>_<v>.wav (float masters, raw levels)

Each SOUNDS entry: (function(rng, v) -> stereo array, variant count, bus, loop?). Variants of hover / press / tab /
buy are subtle: the same gesture on a neighbouring note of the scale and a slightly different timbre.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
from dsp import SR, TAU, hz, midi_hz, P, t_, env, tine, place, pan, reverb, fft_filter, noise, sine_sweep  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "kit")

ROOM = dsp.make_ir(rt=0.5, pre=0.007, bright=7000, dark=2400, width=0.85, seed=11)
HALL = dsp.make_ir(rt=2.4, pre=0.018, bright=6000, dark=1500, width=0.95, seed=23, length=2.9)


def blank(sec):
    return np.zeros((2, int(round(sec * SR))))


def air(n, rng, lo, hi, color="pink"):
    return fft_filter(noise(n, rng, color), lo=lo, hi=hi, order=2)


def tick(rng, dur=0.012, lo=1600, hi=5200, decay=0.0022):
    """The shared transient: a band-limited noise tick, 1-3 ms long."""
    n = int(dur * SR)
    return air(n, rng, lo, hi, "white") * env(n, 0.0003, decay, curve=1.0)


def tock(f0, f1, dur=0.12, tau=0.012, decay=0.03):
    """A pitched body tap (wood / glass block): a sine falling f0 -> f1."""
    n = int(dur * SR)
    return dsp.fade_out(sine_sweep(f0, f1, dur, tau) * env(n, 0.0008, decay), dur * 0.3)


def thump(f0, f1, dur=0.5, tau=0.04, decay=0.2, rng=None, body=0.0, body_hi=900):
    """A soft sub impact: a falling sine plus an optional low noise 'body'."""
    n = int(dur * SR)
    x = sine_sweep(f0, f1, dur, tau) * env(n, 0.002, decay)
    if body and rng is not None:
        x += body * air(n, rng, 60, body_hi, "white") * env(n, 0.001, decay * 0.22)
    return dsp.fade_out(x, dur * 0.3)


def pad(notes, dur, rng, fc0=400.0, fc1=4000.0, rise=1.0, fall=1.5, harmonics=24, detune=0.0035, vowel=True):
    """A warm pad by additive synthesis: detuned saw voices whose harmonics pass a lowpass that opens from fc0 to fc1
    over `rise` s (alias-free, and the filter sweep is exact per harmonic). Swells in over `rise`, falls with `fall`.
    `vowel` adds soft 'ah' formants (a choir tint)."""
    t = t_(dur)
    n = len(t)
    fc = fc0 * (fc1 / fc0) ** np.clip(t / max(rise, 1e-3), 0, 1)
    out = np.zeros((2, n))
    for j, m in enumerate(notes):
        f0 = midi_hz(m)
        for s, d in enumerate((-detune, 0.0, detune)):
            f = f0 * (1 + d)
            vib = 1 + 0.0025 * np.sin(TAU * (4.6 + 0.7 * rng.random()) * t + rng.random() * TAU)
            ph0 = np.cumsum(f * vib) / SR
            voice = np.zeros(n)
            for k in range(1, harmonics + 1):
                fk = f * k
                if fk > 12000:
                    break
                g = 1 / np.sqrt(1 + (fk / fc) ** 4)
                voice += (g / k) * np.sin(TAU * k * ph0 + rng.random() * TAU)
            p = (s - 1) * 0.55 + (j / max(1, len(notes) - 1) - 0.5) * 0.4
            out += pan(voice, float(np.clip(p, -0.9, 0.9))) / (3 * len(notes))
    if vowel:
        out = dsp.eq(out, [(150, -3), (400, 0), (750, 4), (1100, 2.5), (1800, -2), (2900, 1), (5000, -6), (9000, -14)])
    return out * dsp.swell(n, rise, fall, 1.6)


def room(x, mix=0.14):
    return reverb(x, ROOM, mix)


def hall(x, mix=0.25):
    return reverb(x, HALL, mix)


# ------------------------------------------------------------------------------------------------ UI
def s_hover(rng, v):
    """Hover: a tiny soft glass 'tink'. Variants: E6, F#6, E6 (brighter), G#6, F#6 (rounder)."""
    deg = (15, 16, 15, 17, 16)[v]
    glass = (0.05, 0.05, 0.12, 0.06, 0.0)[v]
    idx = (0.55, 0.6, 0.7, 0.55, 0.45)[v]
    f = hz(deg)
    x = tine(f, 0.2, decay=0.05, index=idx, idecay=0.012, attack=0.0015, glass=glass, gdecay=0.01, rng=rng)
    x += 0.07 * tine(f / 2, 0.2, decay=0.04, index=0.2, idecay=0.01, attack=0.002, detune=0, rng=rng)
    n = len(x)
    x += 0.035 * air(n, rng, 6000, 11000) * env(n, 0.0008, 0.006)
    return room(pan(x, (-0.08, 0.06, 0.0, 0.1, -0.04)[v]), 0.12)


def s_press(rng, v):
    """Press: a soft pitched 'tock' with a faint tine in key, a short tick on top for timing."""
    b0, b1 = ((840, 390), (780, 360), (900, 415), (810, 375))[v]
    deg = (13, 10, 12, 13)[v]
    dur = 0.16
    n = int(dur * SR)
    x = np.zeros(n)
    x[:int(0.012 * SR)] += 0.2 * tick(rng, 0.012, 1800, 5500, 0.0016 + 0.0003 * v)
    x += 0.7 * tock(b0, b1, dur, 0.01, 0.024)
    x += 0.16 * tock(b0 * 2.31, b1 * 2.31, dur, 0.008, 0.009)     # the block's first overtone (wood, not beep)
    x += 0.3 * tock(240, 130, dur, 0.018, 0.028)
    x += 0.13 * tine(hz(deg), dur, decay=0.06, index=0.7, idecay=0.01, attack=0.0012, glass=0.05, rng=rng)
    x = fft_filter(x, lo=90, hi=9000)
    return room(pan(x, (0.0, -0.05, 0.05, 0.02)[v]), 0.08)


def s_tab(rng, v):
    """Tab switch: two quick glass taps, one scale step up (G#5-B5, B5-C#6, C#6-E6, F#5-G#5)."""
    d = (12, 13, 14, 11)[v]
    x = blank(0.3)
    a = tine(hz(d), 0.2, decay=0.055, index=0.8, idecay=0.012, attack=0.0012, glass=0.04, rng=rng)
    b = tine(hz(d + 1), 0.26, decay=0.08, index=0.75, idecay=0.014, attack=0.0015, glass=0.05, rng=rng)
    x = place(x, pan(0.8 * a, -0.08), 0.0)
    x = place(x, pan(0.7 * b, 0.08), 0.046)
    x = place(x, 0.12 * tick(rng, 0.01, 2000, 6000, 0.0015), 0.0)
    return room(x, 0.12)


def s_panel_open(rng, v):
    """Panel open: an airy upward breath that lands on a soft strummed chord (E add9), a low 'whump' for weight."""
    x = blank(0.8)
    dur = 0.3
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = 450 * (7.5 ** (np.clip(t / 0.24, 0, 1) ** 1.2))
    br = dsp.biquad(noise(n, rng, "pink"), "bp", fc, q=0.9)
    e = np.clip(t / 0.2, 0, 1) ** 2 * np.exp(-np.maximum(0, t - 0.2) / 0.05)
    x = place(x, pan(0.45 * br * e, -0.1), 0.0)
    for i, d in enumerate((10, 13, 15, 17)):                    # E5 B5 E6 G#6, open (no seconds)
        amp = (0.32, 0.28, 0.2, 0.22)[i]
        x = place(x, pan(amp * tine(hz(d), 0.5, decay=0.22 - 0.03 * i, index=1.0, idecay=0.02, glass=0.06, rng=rng),
                         (-0.35, -0.1, 0.2, 0.4)[i]), 0.17 + 0.024 * i)
    x = place(x, 0.4 * thump(150, 72, 0.3, 0.035, 0.08), 0.16)
    return room(x, 0.2)


def s_panel_close(rng, v):
    """Panel close: a quick downward breath, two tines falling (B5 -> E5), a soft low seal."""
    x = blank(0.5)
    dur = 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = 2600 * (0.17 ** np.clip(t / 0.17, 0, 1))
    br = dsp.biquad(noise(n, rng, "pink"), "bp", fc, q=0.9)
    e = np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.07)
    x = place(x, pan(0.42 * br * e, 0.1), 0.0)
    x = place(x, pan(0.2 * tine(hz(13), 0.25, decay=0.07, index=0.8, idecay=0.012, rng=rng), 0.2), 0.015)
    x = place(x, pan(0.22 * tine(hz(10), 0.3, decay=0.1, index=0.8, idecay=0.014, rng=rng), -0.15), 0.07)
    x = place(x, 0.45 * thump(190, 88, 0.2, 0.022, 0.05, rng, body=0.25, body_hi=700), 0.1)
    return room(x, 0.15)


def s_buy(rng, v):
    """Buy: a quick rising arpeggio of glass tines over a warm e-piano root, a breath of sparkle. The variants are
    the same gesture on open voicings whose tops climb the scale (E6, F#6, G#6, B6): the combo ladder climbs them."""
    notes = ((10, 12, 13, 15), (8, 11, 14, 16), (12, 14, 15, 17), (13, 15, 17, 18))[v]   # E, B sus, C#m, E/B
    root = (5, 3, 4, 5)[v]                                     # E4, B3, C#4, E4
    x = blank(0.9)
    for i, dd in enumerate(notes):
        top = i == 3
        x = place(x, pan((0.36, 0.34, 0.34, 0.44)[i] * tine(hz(dd), 0.75, decay=(0.2, 0.22, 0.26, 0.4)[i], index=1.15,
                                                             idecay=0.022, glass=0.12 if top else 0.05, rng=rng),
                         (-0.3, -0.1, 0.12, 0.25)[i]), (0.0, 0.028, 0.056, 0.088)[i])
    x = place(x, 0.3 * tine(hz(root), 0.5, decay=0.2, index=1.8, idecay=0.03, ratio=1.0, detune=0.002, rng=rng), 0.0)
    n = int(0.5 * SR)
    sp = air(n, rng, 6500, 14000) * env(n, 0.02, 0.1)
    x = place(x, pan(0.045 * sp, 0.2), 0.05)
    return room(x, 0.2)


def s_toast(rng, v):
    """Toast: a gentle two-note chime, a fourth up (B5-E6), or a third up (G#5-B5), soft attack."""
    a, b = ((13, 15), (12, 13))[v]
    x = blank(1.0)
    x = place(x, pan(0.5 * tine(hz(a), 0.8, decay=0.32, index=0.7, idecay=0.03, attack=0.006, glass=0.05, rng=rng), -0.18), 0.0)
    x = place(x, pan(0.46 * tine(hz(b), 0.8, decay=0.4, index=0.7, idecay=0.03, attack=0.006, glass=0.06, rng=rng), 0.18), 0.09)
    return hall(room(x, 0.1)[:, :x.shape[1]], 0.14)


def s_error(rng, v):
    """Error: two muted wooden knocks falling a third (G#3 -> E3): clearly 'no', rounded, never harsh."""
    x = blank(0.4)
    for i, d in enumerate((2, 0)):
        f = hz(d)
        dur = 0.2
        n = int(dur * SR)
        k = sine_sweep(f * 1.25, f, dur, 0.008) * env(n, 0.002, 0.06)
        k = np.tanh(2.6 * k) / np.tanh(2.6)                    # a little warmth: 3rd harmonics for phone speakers
        k += 0.35 * tock(f * 3.1, f * 2.6, dur, 0.006, 0.014)    # the knock's wooden overtone
        o = sine_sweep(f * 2.5, f * 2, dur, 0.008) * env(n, 0.002, 0.05)
        k += 0.5 * np.tanh(2.0 * o) / np.tanh(2.0)             # the same knock an octave up: the phone speaker's copy
        k += 0.3 * air(n, rng, 150, 1200, "white") * env(n, 0.0005, 0.01)
        x = place(x, 0.8 * dsp.fade_out(k, 0.06), 0.115 * i)
    x = fft_filter(x, lo=80, hi=2600)
    return room(x, 0.1)


# ------------------------------------------------------------------------------------------------ impacts
def s_unlock(rng, v):
    """Layer unlock: a soft low impact with a crystal crack, a harp glissando up the scale (E5 -> E7), a bright bloom."""
    x = blank(1.5)
    x = place(x, 0.5 * thump(115, 52, 0.6, 0.045, 0.2, rng, body=0.35, body_hi=900), 0.0)
    x = place(x, 0.32 * tock(430, 230, 0.2, 0.012, 0.04), 0.0)
    n = int(0.05 * SR)
    x = place(x, pan(0.1 * air(n, rng, 1500, 6000, "white") * env(n, 0.0004, 0.01), 0.1), 0.0)
    for i, d in enumerate(range(10, 20)):                      # E5 .. C#7
        a = 0.11 + 0.06 * np.sin(np.pi * i / 9)
        x = place(x, pan(a * tine(hz(d), 0.4, decay=0.14 + 0.02 * i, index=0.9, idecay=0.012, glass=0.04, rng=rng),
                         -0.6 + 1.2 * i / 9), 0.02 + 0.023 * i)
    for i, d in enumerate((15, 17, 18, 20)):                    # E6 G#6 B6 E7
        x = place(x, pan((0.22, 0.2, 0.17, 0.11)[i] * tine(hz(d), 1.0, decay=0.55, index=0.9, idecay=0.03, glass=0.08, rng=rng),
                         (-0.4, -0.1, 0.2, 0.45)[i]), 0.25 + 0.012 * i)
    x = place(x, 0.5 * pad((64, 71, 76), 1.0, rng, 900, 2500, 0.08, 0.35, vowel=False), 0.22)
    return hall(room(x, 0.1)[:, :x.shape[1]], 0.26)


def s_prestige_small(rng, v):
    """Every later prestige: the same gesture as the big one, condensed: a breath in, a soft impact, an e-piano chord,
    a small pad swell and a short sparkle fall. Two voicings (E, E add9)."""
    chord = ((52, 59, 64, 68, 71), (52, 59, 64, 68, 73))[v]    # E3 B3 E4 G#4 B4 / E3 B3 E4 G#4 C#5 (E6)
    T0 = 0.05
    x = blank(1.6)
    n = int(T0 * SR)
    x = place(x, 0.2 * air(n, rng, 800, 5000) * np.linspace(0, 1, n) ** 3, 0.0)
    x = place(x, 0.5 * thump(100, 52, 0.5, 0.04, 0.18, rng, body=0.35, body_hi=1000), T0)
    x = place(x, 0.28 * tock(380, 200, 0.2, 0.012, 0.045), T0)
    for i, m in enumerate(chord):
        x = place(x, pan(0.2 * tine(midi_hz(m + 12), 1.1, decay=0.5, index=1.4, idecay=0.03, detune=0.0015, rng=rng),
                         -0.5 + 0.25 * i), T0 + 0.01 * i)
    x = place(x, 0.9 * pad(chord, 1.3, rng, 500, 3200, 0.3, 0.45), T0 + 0.02)
    for i, d in enumerate((20, 18, 17, 15, 13)):                # E7 B6 G#6 E6 B5 (a falling sparkle)
        x = place(x, pan(0.075 * (1 - i / 7) * tine(hz(d), 0.35, decay=0.1, index=0.8, idecay=0.01, glass=0.08, rng=rng),
                         rng.uniform(-0.7, 0.7)), T0 + 0.12 + 0.045 * i)
    return hall(x, 0.24)


def s_prestige_big(rng, v):
    """The first prestige of a layer: an impact at once (with the visual burst), then a pad RISES (a choir chord that
    swells while its lowpass opens, a breath riser under it) into a bright arrival bloom with a sparkle cascade, and a
    long hall tail."""
    T0, T1 = 0.06, 1.45
    x = blank(4.6)
    n = int(T0 * SR)
    x = place(x, 0.28 * air(n, rng, 600, 6000) * np.linspace(0, 1, n) ** 3, 0.0)
    # 1. the impact
    x = place(x, 0.62 * thump(130, 46, 1.0, 0.06, 0.45, rng, body=0.5, body_hi=1300), T0)
    x = place(x, 0.34 * tock(320, 150, 0.35, 0.015, 0.07), T0)
    m = int(0.9 * SR)
    crash = air(m, rng, 2500, 11000) * env(m, 0.001, 0.28)
    x = place(x, np.stack([0.1 * crash, 0.1 * np.roll(crash, 480)]), T0)
    for i, mm in enumerate((52, 59, 64, 68, 71, 76)):
        x = place(x, pan(0.17 * tine(midi_hz(mm), 1.6, decay=0.8, index=1.6, idecay=0.035, detune=0.0015, rng=rng),
                         -0.6 + 0.24 * i), T0 + 0.008 * i)
    # 2. the rising pad (E add9, open voicing) and a breath riser
    chord = (40, 52, 59, 64, 68, 71, 78)                        # E2 E3 B3 E4 G#4 B4 F#5 (add9 on top)
    x = place(x, 2.2 * pad(chord, 4.2, rng, 320, 5200, T1 - T0 - 0.05, 1.35), T0 + 0.05)
    r = int((T1 - 0.25) * SR)
    t = np.arange(r) / SR
    fc = 500 * (12 ** (t / t[-1]))
    riser = dsp.biquad(noise(r, rng, "pink"), "bp", fc, q=1.4) * (t / t[-1]) ** 2.2
    x = place(x, pan(0.22 * riser, 0.0), 0.25)
    # 3. the arrival: a second soft thump, a bright bloom and a sparkle cascade up and back down the scale
    x = place(x, 0.3 * thump(90, 55, 0.5, 0.04, 0.2), T1)
    for i, d in enumerate((10, 13, 15, 17, 18)):                # E5 B5 E6 G#6 B6
        x = place(x, pan(0.2 * tine(hz(d), 1.8, decay=0.9, index=1.1, idecay=0.03, glass=0.08, rng=rng),
                         (-0.5, -0.25, 0.0, 0.25, 0.5)[i]), T1 + 0.012 * i)
    seq = list(range(15, 23)) + list(range(21, 15, -1))
    for i, d in enumerate(seq):
        a = 0.085 * (1 - 0.5 * i / len(seq))
        x = place(x, pan(a * tine(hz(d), 0.45, decay=0.13, index=0.8, idecay=0.01, glass=0.1, rng=rng),
                         float(np.sin(i * 1.7)) * 0.75), T1 + 0.1 + 0.052 * i + rng.uniform(0, 0.012))
    return hall(x, 0.3)


# ------------------------------------------------------------------------------------------------ loops
LOOP_PORTAL = 8.0


def s_portal_loop(rng, v):
    """The Multiverse portal (a seamless 8 s loop): a low E drone that beats slowly, a swirl of filtered air that
    circles left-right, faint high glass partials. Every frequency is a multiple of 1/8 Hz and every modulation
    completes whole cycles, the reverb is circular: the end joins the start sample-exactly."""
    L = LOOP_PORTAL
    n = int(L * SR)
    t = np.arange(n) / SR
    q = lambda f: round(f * L) / L                              # snap a frequency to whole cycles per loop
    x = np.zeros((2, n))
    for f, a in ((midi_hz(40), 0.16), (midi_hz(47), 0.18), (midi_hz(52), 0.17), (midi_hz(59), 0.08), (midi_hz(64), 0.04)):
        for dd, pp in ((-0.125, -0.4), (0.0, 0.0), (0.25, 0.4)):
            ff = q(f) + dd
            s = np.sin(TAU * ff * t + rng.random() * TAU) + 0.18 * np.sin(TAU * 2 * ff * t + rng.random() * TAU)
            x += pan(a / 3 * s, pp)
    x *= 0.85 + 0.15 * np.cos(TAU * t / L)
    base = noise(n, rng, "pink")
    for k, (lo, hi) in enumerate(((220, 600), (500, 1300), (1100, 2600))):
        band = dsp.fft_filter_loop(base, lo=lo, hi=hi, order=2)
        ph = TAU * k / 3
        lfo = 0.5 + 0.5 * np.cos(TAU * t / (L / 2) + ph)
        rot = TAU * t / L + ph
        x += (0.3 - 0.06 * k) * np.stack([band * lfo * (0.5 + 0.5 * np.cos(rot)), band * lfo * (0.5 - 0.5 * np.cos(rot))])
    for f, per in ((hz(15), L / 3), (hz(18), L / 5), (hz(17), L / 2)):
        tr = 0.5 + 0.5 * np.cos(TAU * t / per + rng.random() * TAU)
        x += pan(0.022 * np.sin(TAU * q(f) * t) * tr ** 2, rng.uniform(-0.6, 0.6))
    ir = dsp.make_ir(rt=2.0, pre=0.015, bright=5000, dark=1400, seed=31)
    return reverb(x, ir, 0.35, loop=True)


# name: (fn, variants, bus, loop)
SOUNDS = {
    "hover": (s_hover, 5, "UI", False),
    "press": (s_press, 4, "UI", False),
    "tab": (s_tab, 4, "UI", False),
    "panel_open": (s_panel_open, 1, "UI", False),
    "panel_close": (s_panel_close, 1, "UI", False),
    "buy": (s_buy, 4, "UI", False),
    "toast": (s_toast, 2, "UI", False),
    "error": (s_error, 1, "UI", False),
    "unlock": (s_unlock, 1, "Impacts", False),
    "prestige_small": (s_prestige_small, 2, "Impacts", False),
    "prestige_big": (s_prestige_big, 1, "Impacts", False),
    "portal_loop": (s_portal_loop, 1, "Ambience", True),
}
# the longest a sound may run (its tail fades within the last 30 %)
MAXLEN = dict(hover=0.2, press=0.17, tab=0.3, panel_open=0.75, panel_close=0.48, buy=0.9, toast=1.0, error=0.38,
              unlock=1.45, prestige_small=1.5, prestige_big=4.4)


def cap(x, dur):
    """Trim the silence, then cap the length: the last 30 % fades out on a cosine, so the tail never clicks."""
    x = dsp.trim(x, -62)
    n = min(x.shape[1], int(dur * SR))
    x = x[:, :n].copy()
    f = int(n * 0.3)
    x[:, n - f:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))) ** 1.3
    return x


def render(name, v):
    """One variant, DC-free, capped (loops are returned as is: exactly one period)."""
    fn, _, _, loop = SOUNDS[name]
    rng = np.random.default_rng(1000 + 37 * list(SOUNDS).index(name) + v)
    x = dsp.stereo(fn(rng, v))
    if loop:
        return x - x.mean(axis=1, keepdims=True)
    x = fft_filter(x, lo=32, order=2)                         # no DC, no infrasonic rumble
    x = cap(x, MAXLEN[name])
    return dsp.fade_in(x, 0.0005)


def all_clips(only=None):
    out = []
    for name, (_, nv, bus, loop) in SOUNDS.items():
        if only and name not in only:
            continue
        for v in range(nv):
            out.append((name, v, bus, loop, render(name, v)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = [s for s in a.only.split(",") if s]
    for name, v, bus, loop, x in all_clips(only):
        path = os.path.join(OUT, "%s_%d.wav" % (name, v + 1))
        dsp.write_wav(path, x / max(1e-9, np.max(np.abs(x))) * 0.9)
        L = dsp.loudness(x)
        print("%-15s v%d %5.2f s  M %6.1f  I %6.1f  peak %6.1f" % (name, v + 1, x.shape[1] / SR, L["momentary_max"],
                                                                     L["integrated"], dsp.db(np.max(np.abs(x)))))


if __name__ == "__main__":
    main()
