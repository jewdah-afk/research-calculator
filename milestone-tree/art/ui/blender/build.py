"""build.py - render the 3D hero pieces of the UI kit (Cycles, headless bpy).

  $B/venv/bin/python art/ui/blender/build.py [--only corner_p_tl,medal_m,...] [--test] [--samples N]

Writes art/ui/out/3d/<name>.png (straight-alpha RGBA, 2x of the 1080p display size) and art/ui/out/3d/<name>.json
(the frame rect in units, so the 2D side can find the anchors). --test renders at 40 % and 12 spp.
$B = the bpy venv (Blender 4.5 as a Python module, see art/gems/README.md).
"""
import sys, os, json, time, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import relics as R          # noqa: E402  (also puts art/gems/src on sys.path)
import pieces3d as P        # noqa: E402
import bl                   # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "out", "3d"))


def jobs():
    J = {}
    for L in ("m", "p", "cp"):
        for w in ("tl", "tr", "bl", "br"):
            J[f"corner_{L}_{w}"] = (lambda L=L, w=w: P.corner_at(R.LAYERS[L], w), 64)
        for name, fn, spp in getattr(P, "LAYER_PIECES", []):
            J[f"{name}_{L}"] = (lambda L=L, fn=fn: fn(R.LAYERS[L]), spp)
    for name, fn, spp in getattr(P, "SHARED_PIECES", []):
        J[name] = (fn, spp)
    return J


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--samples", type=int, default=0)
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    J = jobs()
    names = list(J)
    if a.only:
        want = a.only.split(",")
        names = [n for n in names if any(n == w or (w.endswith("*") and n.startswith(w[:-1])) for w in want)]
    os.makedirs(OUT, exist_ok=True)
    t0 = time.time()
    for n in names:
        fn, spp = J[n]
        R.setup((64, 64))
        P.META.clear()
        objs, rect = fn()
        x0, y0, x1, y1 = rect
        w, h = round((x1 - x0) * R.PX), round((y1 - y0) * R.PX)
        sc = bl.scene()
        sc.render.resolution_x, sc.render.resolution_y = w, h
        sc.render.resolution_percentage = 40 if a.test else 100
        sc.cycles.samples = 12 if a.test else (a.samples or spp)
        R.camera_rect(*rect)
        dt = bl.render(os.path.join(OUT, n + ".png"))
        meta = dict(name=n, rect=rect, px=R.PX, size=[w, h], test=a.test)
        for k, v in P.META.items():     # polygons in local units -> image px (y down)
            meta[k] = [[round((x - x0) * R.PX, 2), round((y1 - y) * R.PX, 2)] for x, y in v]
        with open(os.path.join(OUT, n + ".json"), "w") as f:
            json.dump(meta, f)
        print(f"[ui3d] {n:22s} {w}x{h} {dt:5.1f}s", flush=True)
    print(f"[ui3d] {len(names)} pieces in {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
