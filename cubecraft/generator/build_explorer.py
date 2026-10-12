"""Packs planetgen.js, the texture atlas and the block table into one self-contained page."""
import os, json, base64
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
atlas = json.load(open(os.path.join(ROOT, "world", "atlas.json")))
blocks_src = json.load(open(os.path.join(ROOT, "planet", "world.json")))["blocks"]
blocks = [{"kind": b["kind"],
           "t": atlas["index"].get(b["top"], 0) if b["top"] else 0,
           "s": atlas["index"].get(b["side"], 0) if b["side"] else 0,
           "b": atlas["index"].get(b["bottom"], 0) if b["bottom"] else 0} for b in blocks_src]
meta = {"cols": atlas["cols"], "rows": atlas["rows"], "tile": atlas["tile"], "pad": atlas["pad"], "cell": atlas["cell"],
        "blocks": blocks, "names": [b["name"] for b in blocks_src]}
png = base64.b64encode(open(os.path.join(ROOT, "world", "atlas.png"), "rb").read()).decode()
page = (open(os.path.join(HERE, "explorer_template.html")).read()
        .replace("__PLANETGEN__", open(os.path.join(HERE, "planetgen.js")).read())
        .replace("__META__", json.dumps(meta)).replace("__ATLAS__", png))
open(os.path.join(ROOT, "cubecraft_generator.html"), "w").write(page)
local = ("<!doctype html><html><head><meta charset=\"utf-8\"><style>[hidden]{display:none!important}</style></head><body>" +
         page.replace("https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js", "vendor/three.min.js")
             .replace("https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js", "vendor/OrbitControls.js") +
         "</body></html>")
open(os.path.join(ROOT, "generator_local.html"), "w").write(local)
print("page bytes", len(page))
