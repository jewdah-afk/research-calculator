"""turntable.py - 4 s seamless turntable of the M gem.
  render : Cycles, film transparent, gem spinning about its centroid (same lights/materials as the sprites)
  post   : upscale -> bloom + glint-driven star sparkles -> over cosmic backdrop -> H.264 yuv420p mp4
usage: turntable.py render [res] [spp] [first] [last] | post | all"""
import sys, os, time, glob, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import post

OUT = os.path.join(HERE, "out")
TT = os.path.join(OUT, "turntable")
RAW, FR = os.path.join(TT, "raw"), os.path.join(TT, "frames")
FRAMES, FPS, SIZE, KEY = 96, 24, 1080, "m"


def render(res=720, spp=12, first=1, last=FRAMES):
    import gem, bl, bpy
    s = gem.build(res=res)
    sc = bl.scene()
    sc.frame_start, sc.frame_end = 1, FRAMES
    sc.render.fps = FPS
    sc.cycles.samples = spp
    sc.cycles.adaptive_threshold = 0.03
    sc.cycles.max_bounces, sc.cycles.glossy_bounces, sc.cycles.transmission_bounces = 12, 6, 8
    sc.render.image_settings.color_depth = "8"
    gem.set_look(post.TREE[KEY], "base")
    rig = s["rig"]
    rig.location = (0, -0.22, 0)                        # spin about the crystal's centroid, not the girdle
    spin = bl.empty("Spin", (0, 0, 0))
    bl.parent(rig, spin)
    bl.key(spin, "rotation_euler", [(1, (0, 0, 0)), (FRAMES + 1, (0, 0, math.radians(360)))], interp="LINEAR")
    os.makedirs(RAW, exist_ok=True)
    t = time.time()
    bl.render_anim(RAW, first, last, clean=False)
    return time.time() - t


def glints(pm, thr=0.88, n=5, gap=60):
    w = pm[..., :3].min(-1)
    pts = []
    ww = w.copy()
    for _ in range(n):
        y, x = np.unravel_index(ww.argmax(), ww.shape)
        v = ww[y, x]
        if v < thr:
            break
        pts.append((x, y, v))
        ww[max(0, y - gap):y + gap + 1, max(0, x - gap):x + gap + 1] = 0
    return pts


def post_all(files=None, fr=FR, encode=True):
    os.makedirs(fr, exist_ok=True)
    tint = post.rgb01(post.TREE[KEY])
    bg = post.cosmic_bg(SIZE, SIZE, seed=5)
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    r = np.sqrt((xs - SIZE / 2) ** 2 + (ys - SIZE / 2) ** 2) / SIZE
    aura = np.exp(-(r / 0.33) ** 2) * 0.16 + np.exp(-(r / 0.16) ** 2) * 0.1
    bg = np.clip(bg + aura[..., None] * tint, 0, 1)
    files = files or sorted(glob.glob(os.path.join(RAW, "f_*.png")))
    t = time.time()
    k = SIZE / 512.0
    for f in files:
        im = Image.open(f).convert("RGBA")
        if im.size[0] != SIZE:
            im = im.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")
        pm = np.asarray(im).astype(np.float32) / 255.0
        pm[..., :3] *= pm[..., 3:4]
        wht = pm[..., :3].min(-1)
        hi = np.clip((wht - 0.62) / 0.38, 0, 1)[..., None] * pm[..., :3]
        bloom = post.blur(hi, 3 * k) * 0.35 + post.blur(hi, 10 * k) * 0.3 + post.blur(hi, 26 * k) * 0.25
        out = post.add_light(pm, bloom)
        for x, y, v in glints(pm):
            s_ = ((v - 0.86) / 0.14) ** 1.5
            out = post.add_light(out, post.star((SIZE, SIZE), x + 0.5, y + 0.5, (30 + 60 * s_) * k,
                                                0.4 + 0.6 * s_, tint, width=2.2 * k))
        comp = out[..., :3] + bg * (1 - out[..., 3:4])
        Image.fromarray((np.clip(comp, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(
            os.path.join(fr, os.path.basename(f)))
    print(f"[tt] post {len(files)} frames {time.time() - t:.1f}s", flush=True)
    if encode:
        import bl
        bl.encode(fr, os.path.join(OUT, "turntable_m.mp4"), fps=FPS, crf=16)


def note(k, v):
    import json
    p = os.path.join(OUT, "LOG_turntable.json")
    d = json.load(open(p)) if os.path.exists(p) else {}
    d[k] = v
    json.dump(d, open(p, "w"), indent=1)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd in ("render", "all"):
        a = [int(x) for x in sys.argv[2:]]
        dt = render(*a)
        res, spp = (a + [720, 12])[:2] if a else (720, 12)
        n = len(glob.glob(os.path.join(RAW, "f_*.png")))
        print(f"[tt] render {dt:.1f}s", flush=True)
        note(f"render {'frames %d-%d' % (a[2], a[3]) if len(a) > 3 else 'all frames'}",
             f"{res}x{res}, {spp} spp max (adaptive 0.03), OIDN: {dt:.0f} s ({n} raw frames on disk)")
    if cmd in ("post", "all"):
        t = time.time()
        post_all()
        note("post + encode", f"upscale to {SIZE}, bloom, glint-driven sparkles, cosmic backdrop, H.264 yuv420p "
                              f"crf 16, {FRAMES} frames @ {FPS} fps: {time.time() - t:.0f} s")
