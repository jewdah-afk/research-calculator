"""Packs the generator, mesher, worker, atlas and block table into one self-contained page."""
import os, json, base64
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
atlas = json.load(open(os.path.join(ROOT, "world", "atlas.json")))
blocks_src = json.load(open(os.path.join(ROOT, "planet", "world.json")))["blocks"]
info = [{"kind": b["kind"], "t": atlas["index"].get(b["top"], 0) if b["top"] else 0,
         "s": atlas["index"].get(b["side"], 0) if b["side"] else 0,
         "b": atlas["index"].get(b["bottom"], 0) if b["bottom"] else 0} for b in blocks_src]
meta = {"names": [b["name"] for b in blocks_src], "blocks": info,
        "atlas": {k: atlas[k] for k in ("cols", "rows", "tile", "pad", "cell")}}
png = base64.b64encode(open(os.path.join(ROOT, "world", "atlas.png"), "rb").read()).decode()
read = lambda n: open(os.path.join(HERE, n)).read()
page = (read("explorer2_template.html").replace("__MESHER__", read("mesher.js")).replace("__WORKER__", read("worker.js"))
        .replace("__PLANETGEN__", read("planetgen.js")).replace("__META__", json.dumps(meta)).replace("__ATLAS__", png))
open(os.path.join(ROOT, "cubecraft_explorer.html"), "w").write(page)
local = ("<!doctype html><html><head><meta charset=\"utf-8\"><style>[hidden]{display:none!important}</style></head><body>" +
         page.replace("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js", "vendor/three.min.js")
             .replace("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js", "vendor/OrbitControls.js") +
         "</body></html>")
open(os.path.join(ROOT, "explorer_local.html"), "w").write(local)
print("page bytes", len(page))
