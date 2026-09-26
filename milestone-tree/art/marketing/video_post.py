"""video_post.py - assemble out/video_preview.mp4 from the segment frames video.js rendered (work/video/plan.json).

    cd art/marketing && python3 video_post.py

Crossfades between segments, a short dissolve over the panel-open cut (the mock engine snaps the sheet open in one
frame), the end card fading in over a darkened realm, a hold on the end card, then H.264 (High, yuv420p, 30 fps,
faststart, no audio) through the imageio-ffmpeg binary. Deterministic: same frames in, same file out.
"""
import json, os, subprocess
import numpy as np
from PIL import Image
import imageio_ffmpeg

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work", "video")
OUT = os.path.join(HERE, "out", "video_preview.mp4")
HOLD = 24  # frames the finished end card holds


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def main():
    plan = json.load(open(os.path.join(WORK, "plan.json")))
    fps, xf, ec = plan["fps"], plan["xfade"], plan["endcard"]
    segs = []
    for s in plan["segments"]:
        d = os.path.join(WORK, s["name"])
        files = sorted(f for f in os.listdir(d) if f.endswith(".jpg"))
        assert len(files) == s["frames"], f"{s['name']}: {len(files)} frames, expected {s['frames']}"
        segs.append({"files": [os.path.join(d, f) for f in files], "tapAt": s.get("tapAt")})

    # the timeline as (callable -> frame) so only two images are in memory at once
    timeline, timeline_meta = [], []
    for k, s in enumerate(segs):
        files, tap = s["files"], s["tapAt"]

        def frame(i, files=files, tap=tap):
            # the panel-open cut: dissolve from the last closed frame to the settled open one over 8 frames
            if tap is not None and tap <= i < tap + 8:
                w = smooth((i - tap + 1) / 9)
                return load(files[tap - 1]) * (1 - w) + load(files[tap + 8]) * w
            return load(files[i])

        n = len(files)
        start = 0 if k == 0 else xf  # the first xf frames of a later segment live inside the crossfade
        if k > 0:
            prev_n, prev_frame = timeline_meta[-1]
            for j in range(xf):
                w = smooth((j + 1) / (xf + 1))
                timeline.append(lambda j=j, w=w, pf=prev_frame, pn=prev_n, fr=frame:
                                pf(pn - xf + j) * (1 - w) + fr(j) * w)
        end = n - xf if k < len(segs) - 1 else n
        for i in range(start, end):
            timeline.append(lambda i=i, fr=frame: fr(i))
        timeline_meta.append((n, frame))

    # the end card over the last frames, then a hold
    card = np.asarray(Image.open(os.path.join(WORK, "endcard.png")).convert("RGBA"), dtype=np.float32) / 255.0
    rgb, alpha = card[..., :3] * 255.0, card[..., 3:4]
    total = len(timeline)
    for idx in range(total - ec, total):
        w = smooth((idx - (total - ec) + 1) / ec)
        base = timeline[idx]
        timeline[idx] = (lambda b=base, w=w: _card(b(), w, rgb, alpha))
    last = timeline[-1]
    timeline += [last] * HOLD

    ff = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    cmd = [ff, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "1920x1080", "-r", str(fps), "-i", "-",
           "-an", "-c:v", "libx264", "-preset", "slow", "-profile:v", "high", "-pix_fmt", "yuv420p", "-crf", "19",
           "-maxrate", "11M", "-bufsize", "22M", "-g", str(fps * 2), "-threads", "1", "-movflags", "+faststart", "-r", str(fps), OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    cache = {}
    for n, f in enumerate(timeline):
        key = id(f)
        img = cache.get(key)
        if img is None:
            img = np.clip(f(), 0, 255).astype(np.uint8)
            cache = {key: img}  # keep only the latest (the hold repeats it)
        p.stdin.write(img.tobytes())
    p.stdin.close()
    p.wait()
    size = os.path.getsize(OUT) / 1e6
    print(f"{OUT}: {len(timeline)} frames, {len(timeline) / fps:.2f} s, {size:.1f} MB")


def _card(frame, w, rgb, alpha):
    # darken the realm a little under the card, then lay the card
    dark = frame * (1 - 0.3 * w)
    a = alpha * w
    return dark * (1 - a) + rgb * a


if __name__ == "__main__":
    main()
