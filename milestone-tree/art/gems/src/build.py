"""build.py - render every layer gem sprite from ONE scene (only material values change between renders).
usage: build.py [--samples N] [--only m,p:ready,...] [--no-blend]
out/raw/<name>.png = Cycles render (film transparent), out/gems/<name>.png = finished sprite (post.py)."""
import sys, os, time, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gem, bl, bpy, post

ap = argparse.ArgumentParser()
ap.add_argument("--samples", type=int, default=64)
ap.add_argument("--res", type=int, default=512)
ap.add_argument("--only", default="")
ap.add_argument("--no-blend", action="store_true")
a = ap.parse_args(sys.argv[1:])

OUT = os.path.join(HERE, "out")
RAW, GEMS = os.path.join(OUT, "raw"), os.path.join(OUT, "gems")
os.makedirs(RAW, exist_ok=True)
os.makedirs(GEMS, exist_ok=True)
jobs = [(k, "base") for k in post.ORDER] + post.VARIANTS
if a.only:
    want = [x.split(":") for x in a.only.split(",")]
    want = {(w[0], w[1] if len(w) > 1 else "base") for w in want}
    jobs = [j for j in jobs if j in want]

t0 = time.time()
s = gem.build(res=a.res)
sc = bl.scene()
sc.render.use_persistent_data = True          # keep BVH/shaders between renders: only colours change
sc.render.image_settings.color_depth = "8"
sc.cycles.samples = a.samples
t_build = time.time() - t0
rows = []
for k, var in jobs:
    name = k if var == "base" else f"{k}_{var}"
    gem.set_look(post.TREE[k], var)
    raw = os.path.join(RAW, name + ".png")
    dt = bl.render(raw)
    t1 = time.time()
    post.finish_sprite(raw, os.path.join(GEMS, name + ".png"), post.TREE[k], var)
    rows.append((name, post.TREE[k], var, dt, time.time() - t1))
    print(f"[gem] {name:10s} render {dt:5.1f}s  post {rows[-1][4]:4.1f}s", flush=True)

if not a.no_blend:
    gem.set_look(post.TREE["m"], "base")
    sc.render.filepath = os.path.join(RAW, "")
    bl.save_blend(os.path.join(HERE, "gems.blend"), pack=False)

stamp = time.strftime("%Y-%m-%d %H:%M")
with open(os.path.join(OUT, "LOG_sprites.tsv"), "a") as f:
    for r in rows:
        f.write(f"{stamp}\t{r[0]}\t{r[2]}\t{a.res}\t{a.samples}\t{r[3]:.1f}\t{r[4]:.1f}\n")
print(f"[gem] scene build {t_build:.1f}s, total {time.time() - t0:.1f}s, {len(rows)} sprites")
