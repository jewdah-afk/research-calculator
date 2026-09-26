"""pack.py - build the game's audio assets from kit.py and ambience.py: loudness-balance, pack the sprite sheets,
encode, verify.

    python3 art/audio/pack.py            (about 20 s)

1. Balance. Every variant is set to its sound's loudness TARGET (momentary max, BS.1770-4), so a hover is always a
   hover and variants never jump in level; the kit is then shifted as a whole so its integrated loudness is
   KIT_LUFS (-16 LUFS, gated, over every one-shot variant in turn), and every sound is peak-limited to -1 dBTP
   (a look-ahead limiter on 4x-oversampled peaks; most sounds never touch it). The ambience bed is set to
   BED_LUFS integrated; the Ambience bus sets its level in game.
2. Pack. Two sheets, by bus: `ui` (the UI cues) and `fx` (unlock, prestige, the portal loop), plus the `bed`
   (ambience) file. Each cue starts PRE s after its region start (a region that starts a hair late never clips an
   attack) and GAP s of silence follow it (a region that ends late never bleeds into the next cue). A loop is stored
   as [the last PAD s | one period | the first PAD s] and its region is the middle period: any imprecision at the
   region edges lands in identical audio, so the loop point stays seamless even through a lossy codec.
3. Encode (Ogg Vorbis q6, 48 kHz stereo) to art/audio/sheets/*.ogg (committed: the uploaded files), per-sound
   previews to art/ui/sfx/<name>[_<v>].ogg, lossless masters to art/audio/out/, and the region map
   art/audio/sheets/map.json (read by upload.js, which generates src/shared/AudioIds.luau).
4. Verify on the decoded Ogg files: every region's loudness and true peak, silence between cues, and the loop seams.
"""
import hashlib
import json
import os
import shutil
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp  # noqa: E402
import kit  # noqa: E402
import ambience  # noqa: E402
import look  # noqa: E402
from dsp import SR  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
OUT = os.path.join(HERE, "out")
SHEETS = os.path.join(HERE, "sheets")
PREVIEW = os.path.join(ART, "ui", "sfx")

KIT_LUFS = -16.0
BED_LUFS = -18.0
CEILING = -1.2           # dBTP after limiting (the codec adds a few tenths; the decoded files are checked at -1.0)
PRE, GAP, PAD = 0.01, 0.3, 0.5

# the balance: momentary-max loudness of each sound relative to the others (LUFS before the kit shift). Quiet ticks
# can repeat without fatigue; the moments that matter are the loud ones.
TARGET = {
    "hover": -31.5, "tab": -27.0, "press": -27.5, "panel_close": -25.5, "error": -24.5, "toast": -23.5,
    "panel_open": -23.5, "buy": -19.5, "prestige_small": -17.0, "unlock": -16.5, "prestige_big": -13.0,
    "portal_loop": -24.0,
}
SHEET_OF = {"UI": "ui", "Impacts": "fx", "Ambience": "fx"}


def balance(clips):
    """Level every clip to its TARGET, then shift the kit to KIT_LUFS and limit peaks."""
    out = []
    for name, v, bus, loop, x in clips:
        m = dsp.loudness(np.concatenate([x, x], axis=1) if loop else x)["momentary_max"]
        out.append([name, v, bus, loop, x * dsp.undb(TARGET[name] - m)])
    gap = np.zeros((2, int(0.5 * SR)))
    seq = np.concatenate([np.concatenate([c[4], gap], axis=1) for c in out if not c[3]], axis=1)
    kit_i = dsp.loudness(seq)["integrated"]
    shift = KIT_LUFS - kit_i
    for c in out:
        y = c[4] * dsp.undb(shift)
        if dsp.true_peak_db(y) > CEILING:
            y = dsp.limit(y, CEILING)
        c[4] = y
    return out, kit_i, shift


def loop_segment(x, pad=PAD):
    """[last pad s | x | first pad s] of a periodic x, and the offset of the period inside it."""
    p = int(pad * SR)
    # the outer 50 ms of the padding (never inside the region) fade, so the file has no hard edge for the codec
    return np.concatenate([dsp.fade_in(x[:, -p:], 0.05), x, dsp.fade_out(x[:, :p], 0.05)], axis=1), pad


def build_sheet(items):
    """items: [(key, stereo, loop)] -> (sheet, {key: [start, length]})."""
    parts = [np.zeros((2, int(0.05 * SR)))]
    pos = parts[0].shape[1]
    regions = {}
    for key, x, loop in items:
        if loop:
            seg, off = loop_segment(x)
            parts.append(seg)
            regions[key] = [round((pos + int(off * SR)) / SR, 6), round(x.shape[1] / SR, 6)]
            pos += seg.shape[1]
        else:
            pre = np.zeros((2, int(PRE * SR)))
            parts.append(pre)
            parts.append(x)
            regions[key] = [round(pos / SR, 6), round((pre.shape[1] + x.shape[1]) / SR, 6)]
            pos += pre.shape[1] + x.shape[1]
        g = np.zeros((2, int(GAP * SR)))
        parts.append(g)
        pos += g.shape[1]
    return np.concatenate(parts, axis=1), regions


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def wrap_ratio(y, i0, i1):
    """The step a player hears when the loop wraps (last sample of the region -> first) divided by the largest
    ordinary sample step in the second after the start: at most about 1 means the wrap never stands out (a lossy
    codec adds its own noise to every step, so a bit-exact seam is not the test)."""
    d = np.abs(np.diff(y[:, i0:i0 + SR], axis=1))
    return float(np.max(np.abs(y[:, i0] - y[:, i1 - 1])) / (np.max(d) + 1e-9))


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SHEETS, exist_ok=True)
    clips = kit.all_clips()
    clips, kit_raw, shift = balance(clips)
    bed = ambience.bed()
    bed_i = dsp.loudness(np.concatenate([bed, bed], axis=1))["integrated"]
    bed = bed * dsp.undb(BED_LUFS - bed_i)
    if dsp.true_peak_db(bed) > CEILING:
        bed = dsp.limit(bed, CEILING)

    # masters + previews
    for f in os.listdir(PREVIEW):
        if f.endswith((".ogg", ".wav")):
            os.remove(os.path.join(PREVIEW, f))
    for name, v, bus, loop, x in clips:
        key = name if v == 0 else "%s_%d" % (name, v + 1)
        wav = os.path.join(OUT, "kit_final", key + ".wav")
        dsp.write_wav(wav, x)
        dsp.encode_ogg(wav, os.path.join(PREVIEW, key + ".ogg"), q=5)
    dsp.write_wav(os.path.join(OUT, "ambience_final.wav"), bed)
    dsp.encode_ogg(os.path.join(OUT, "ambience_final.wav"), os.path.join(PREVIEW, "ambience.ogg"), q=5)

    # sheets
    groups = {"ui": [], "fx": []}
    for name, v, bus, loop, x in clips:
        groups[SHEET_OF[bus]].append(("%s#%d" % (name, v + 1), x, loop))
    sheets, sounds = {}, {}
    for sk, items in groups.items():
        sheet, regions = build_sheet(items)
        wav = os.path.join(OUT, "sheet_%s.wav" % sk)
        dsp.write_wav(wav, sheet)
        ogg = os.path.join(SHEETS, "%s.ogg" % sk)
        dsp.encode_ogg(wav, ogg, q=6)
        sheets[sk] = {"file": "sheets/%s.ogg" % sk, "length": round(sheet.shape[1] / SR, 3)}
        for key, r in regions.items():
            name = key.split("#")[0]
            s = sounds.setdefault(name, {"sheet": sk, "bus": kit.SOUNDS[name][2], "loop": kit.SOUNDS[name][3], "regions": []})
            s["regions"].append(r)
    bedseg, off = loop_segment(bed, 1.0)
    wav = os.path.join(OUT, "sheet_bed.wav")
    dsp.write_wav(wav, bedseg)
    dsp.encode_ogg(wav, os.path.join(SHEETS, "bed.ogg"), q=6)
    sheets["bed"] = {"file": "sheets/bed.ogg", "length": round(bedseg.shape[1] / SR, 3)}
    sounds["ambience"] = {"sheet": "bed", "bus": "Ambience", "loop": True, "regions": [[1.0, round(bed.shape[1] / SR, 6)]]}

    # verify the decoded files
    ok = True
    report = []
    for sk in sheets:
        path = os.path.join(HERE, sheets[sk]["file"])
        sheets[sk]["sha256"] = sha(path)
        sheets[sk]["bytes"] = os.path.getsize(path)
        y = dsp.decode(path)
        sheets[sk]["decoded_peak_db"] = round(float(dsp.db(np.max(np.abs(y)))), 2)
        covered = np.zeros(y.shape[1], bool)
        for name, s in sounds.items():
            if s["sheet"] != sk:
                continue
            s.setdefault("lufs", [])
            s.setdefault("tp", [])
            for (a, ln) in s["regions"]:
                i0, i1 = int(a * SR), int((a + ln) * SR)
                seg = y[:, i0:i1]
                if s["loop"]:
                    L = dsp.loudness(np.concatenate([seg, seg], axis=1))["integrated"]
                    w = wrap_ratio(y, i0, i1)
                    # the region end continues into the padding, which equals the region start: compare them
                    diff = float(np.max(np.abs(y[:, i1:i1 + 2000] - y[:, i0:i0 + 2000])))
                    report.append("  %-15s loop %.2f s  I %6.1f LUFS  wrap step %.2f x typical  end-vs-start max diff %.4f"
                                  % (name, ln, L, w, diff))
                    ok &= diff < 0.05 and w < 1.2
                    pad = int((1.0 if sk == "bed" else PAD) * SR)
                    covered[max(0, i0 - pad - int(0.04 * SR)):min(len(covered), i1 + pad + int(0.04 * SR))] = True
                else:
                    L = dsp.loudness(seg)["momentary_max"]
                # the codec smears up to one block (about 40 ms) around an edge
                covered[max(0, i0 - int(0.04 * SR)):min(len(covered), i1 + int(0.04 * SR))] = True
                tp = dsp.true_peak_db(seg)
                s["lufs"].append(round(float(L), 2))
                s["tp"].append(round(float(tp), 2))
                ok &= tp <= -1.0 + 1e-6
        # silence outside the regions (no bleed between cues)
        rest = y[:, ~covered]
        leak = float(dsp.db(np.max(np.abs(rest)))) if rest.size else -120.0
        report.append("  sheet %-3s %6.2f s  %4d KB  decoded peak %5.1f dBFS  outside regions max %6.1f dBFS"
                      % (sk, sheets[sk]["length"], sheets[sk]["bytes"] // 1024, sheets[sk]["decoded_peak_db"], leak))
        ok &= leak < -60
    kit_seq = []
    for name, s in sounds.items():
        if not s["loop"]:
            y = dsp.decode(os.path.join(HERE, sheets[s["sheet"]]["file"]))
            for (a, ln) in s["regions"]:
                kit_seq.append(y[:, int(a * SR):int((a + ln) * SR)])
                kit_seq.append(np.zeros((2, int(0.5 * SR))))
    kit_i = dsp.loudness(np.concatenate(kit_seq, axis=1))["integrated"]
    version = hashlib.sha256("".join(sheets[k]["sha256"] for k in sorted(sheets)).encode()).hexdigest()[:12]
    m = {
        "about": "The game's audio sprite sheets (written by art/audio/pack.py). regions = [start, length] in seconds; a "
                 "loop's region is exactly one period. upload.js uploads the sheets and generates src/shared/AudioIds.luau.",
        "version": version,
        "kit": {"integrated_lufs": round(kit_i, 2), "target_lufs": KIT_LUFS, "shift_db": round(shift, 2),
                "bed_integrated_lufs": BED_LUFS, "ceiling_dbtp": -1.0},
        "sheets": sheets,
        "sounds": sounds,
    }
    with open(os.path.join(SHEETS, "map.json"), "w") as f:
        json.dump(m, f, indent=1)
        f.write("\n")
    print("kit: raw integrated %.1f LUFS, shifted %+.1f dB -> decoded %.2f LUFS integrated (target %.0f)"
          % (kit_raw, shift, kit_i, KIT_LUFS))
    for name, s in sounds.items():
        print("  %-15s %-3s %-8s x%d  M %s  TP max %.1f" % (name, s["sheet"], s["bus"], len(s["regions"]),
                                                          " ".join("%.1f" % v for v in s["lufs"]), max(s["tp"])))
    for r in report:
        print(r)
    rows = [(("%s_%d" % (n, v + 1)), x) for n, v, b, lp, x in clips] + [("ambience (8 s)", bed[:, :8 * SR])]
    look.sheet(os.path.join(OUT, "kit_sheet.png"), rows, px_per_s=420, H=110)
    print("version %s  %s" % (version, "all checks passed" if ok else "CHECKS FAILED"))
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
