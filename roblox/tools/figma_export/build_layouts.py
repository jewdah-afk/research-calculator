"""Figma export (out/*.json) -> Luau layout modules for the in-game UI (src/client/UI/Figma/Layouts/*.luau).

Every Figma node becomes one table the Luau renderer (UI/Figma/Render.luau) turns into Roblox GuiObjects:
  t  kind: F frame / R rect / E ellipse / T text / I icon image / G glyph / C growth chevrons / S sparkle / B soft (blurred) ellipse
  n  name (Figma layer name, used by binders to find nodes), x y w h (px, relative to the parent), rot (deg, around the centre)
  f  fills  -> index into the module's style table P: list of layers
         {"s", hex, alpha} solid · {"g", rotation, {{t, hex, alpha}...}} linear · {"r", cx, cy, rx, ry, hex, alpha} radial
         {"t", texture, tilePx, alpha} tiled texture
  s  stroke -> P index: {hex, alpha, weight, align "I"/"O"/"C"}
  e  effects -> P index: list of {"d", dx, dy, blur, hex, alpha, spread} / {"i", ...} / {"lb", radius}
  r  corner radius, c clip, o opacity, k children, key = lip depth when the frame is a Kit key (ink body / lip / face)
  text: tx, fs, ax ("L"/"C"/"R"), ay ("T"/"C"/"B"), wrap, rich (RichText string for mixed colours), tf (text fill P index)
usage: python build_layouts.py   (reads out/, writes ../../src/client/UI/Figma/Layouts/)"""
import json, math, os, re, glob

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DEST = os.path.normpath(os.path.join(HERE, "..", "..", "src", "client", "UI", "Figma", "Layouts"))
HASH = json.load(open(os.path.join(HERE, "hashes.json"), encoding="utf-8"))
TEX = {"ui_stripes": ("stripes", 64), "ui_halftone": ("halftone", 64), "tex_lattice": ("lattice", 86)}

# Figma root id -> (module name, kind). kind "window" = one frame; "hud" = a section of components.
ROOTS = json.load(open(os.path.join(HERE, "roots.json"), encoding="utf-8"))

stats = {"vectors_skipped": 0, "unknown_images": set(), "icons": set()}


def lerp_stop(stops, p):
    """colour/alpha of a Figma stop list at position p (clamped)."""
    if p <= stops[0][1]:
        return stops[0][0], stops[0][2]
    if p >= stops[-1][1]:
        return stops[-1][0], stops[-1][2]
    for a, b in zip(stops, stops[1:]):
        if a[1] <= p <= b[1]:
            k = 0 if b[1] == a[1] else (p - a[1]) / (b[1] - a[1])
            ca = [int(a[0][i:i + 2], 16) for i in (0, 2, 4)]
            cb = [int(b[0][i:i + 2], 16) for i in (0, 2, 4)]
            c = "".join("%02x" % round(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
            return c, a[2] + (b[2] - a[2]) * k
    return stops[-1][0], stops[-1][2]


def norm_stops(raw):
    out = []
    for s in raw:
        out.append((s[0], float(s[1]), float(s[2]) if len(s) > 2 else 1.0))
    out.sort(key=lambda s: s[1])
    return out


def linear(T, raw, op):
    a, b, c = T[0], T[1], T[2]
    stops = norm_stops(raw)
    mag = math.hypot(a, b)
    if mag < 1e-6:
        col, al = stops[0][0], stops[0][2]
        return ["s", col, round(al * op, 3)]
    phi = math.atan2(b, a)
    K = abs(math.cos(phi)) + abs(math.sin(phi))
    gc = a * 0.5 + b * 0.5 + c                     # gradient coordinate at the centre
    span = K * mag
    def fig_at(t):  # figma gradient position at roblox t
        return gc + (t - 0.5) * span
    pts = {0.0, 1.0}
    for s in stops:
        t = 0.5 + (s[1] - gc) / span
        if 0 < t < 1:
            pts.add(round(t, 4))
    res = []
    for t in sorted(pts):
        col, al = lerp_stop(stops, fig_at(t))
        res.append([round(t, 4), col, round(al * op, 3)])
    # Roblox keeps at most 20 keypoints
    while len(res) > 20:
        res.pop(len(res) // 2)
    rot = round(math.degrees(phi), 2)
    return ["g", rot, res]


def radial(T, raw, op):
    a, b, c, d, e, f = T
    det = a * e - b * d
    if abs(det) < 1e-9:
        return None
    ia, ib, id_, ie = e / det, -b / det, -d / det, a / det
    gx, gy = 0.5 - c, 0.5 - f
    cx, cy = ia * gx + ib * gy, id_ * gx + ie * gy
    rx = math.hypot(ia * 0.5, id_ * 0.5)
    ry = math.hypot(ib * 0.5, ie * 0.5)
    stops = norm_stops(raw)
    col, _, al = stops[0]
    return ["r", round(cx, 4), round(cy, 4), round(rx, 4), round(ry, 4), col, round(al * op, 3)]


def paint_layers(paints, for_icon=False):
    """Figma fills -> renderer layers. Returns (layers, icon_name_or_None)."""
    layers, icon = [], None
    for p in paints or []:
        if isinstance(p, str):
            layers.append(["s", p, 1])
        elif isinstance(p, list) and len(p) == 2 and isinstance(p[0], str) and not p[0] in ("l", "r", "a", "d", "i"):
            layers.append(["s", p[0], p[1]])
        elif p[0] == "l":
            layers.append(linear(p[1], p[2], p[3]))
        elif p[0] in ("r", "a", "d"):   # radial / angular / diamond -> radial approximation
            r = radial(p[1], p[2], p[3])
            if r:
                layers.append(r)
        elif p[0] == "i":
            h, mode, scale, op = p[1], p[2], p[3], p[4]
            name = HASH.get(h)
            if name in TEX:
                tex, native = TEX[name]
                layers.append(["t", tex, round(native * scale, 2), op])
            elif name:
                icon = name
                if op < 1:
                    layers.append(["ia", op])
            else:
                stats["unknown_images"].add(h)
                layers.append(["t", "halftone", round(64 * scale, 2), op])   # unknown texture: closest tiled one
    return layers, icon


class Emitter:
    def __init__(self, D):
        self.D = D
        self.P = []
        self.PM = {}

    def intern(self, v):
        k = json.dumps(v, sort_keys=True)
        if k not in self.PM:
            self.PM[k] = len(self.P) + 1
            self.P.append(v)
        return self.PM[k]

    def name(self, n):
        v = n.get("n")
        return self.D[v] if isinstance(v, int) else v

    def ref(self, v):
        return self.D[v] if isinstance(v, int) else v

    def node(self, n, ox=0.0, oy=0.0, parent=None):
        t = n["t"]
        name = self.name(n)
        kind = "F" if t in ("F", "R", "G", "C", "I", "X") else t   # renderer kind (instances / components / groups render as frames)
        x, y, w, h = n["p"]
        x -= ox
        y -= oy
        o = {"t": kind, "n": name, "x": round(x, 1), "y": round(y, 1), "w": round(w, 1), "h": round(h, 1)}
        if "rot" in n:
            o["rot"] = n["rot"]
            cx, cy = n["cc"]
            o["x"], o["y"] = round(cx - ox - w / 2, 1), round(cy - oy - h / 2, 1)
        if "o" in n:
            o["o"] = n["o"]
        if n.get("c"):
            o["c"] = True
        if "r" in n:
            r = n["r"]
            o["r"] = max(r) if isinstance(r, list) else r
        fills = self.ref(n["f"]) if "f" in n else None
        effects = self.ref(n["e"]) if "e" in n else None
        stroke = self.ref(n["s"]) if "s" in n else None
        # ----- special leaves
        if name.startswith("glyph/"):
            o["t"] = "G"; o["kind"] = name.split("/", 1)[1]; o["col"] = n.get("gc", "ffffff")
            gsw = n.get("gsw", [7.5, 3.6]); o["ink"] = gsw[0]; o["lw"] = gsw[1]
            return o
        if name == "growth chevrons":
            o["t"] = "C"; o["col"] = n.get("gc", "5fe06a")
            return o
        if name == "swoosh":
            return None
        # an SVG glyph pasted as a frame of stroked vectors (the tree's "owned check" ticks): rebuild as a glyph
        ks0 = n.get("k") or []
        if ks0 and all(c["t"] == "V" and "s" in c for c in ks0) and len(ks0) <= 3 and parent is not None:
            strokes = [self.ref(c["s"]) for c in ks0]
            cols = []
            for st in strokes:
                sl, _ = paint_layers(st[0])
                cols.append(sl[0][1] if sl and sl[0][0] == "s" else "ffffff")
            o["t"] = "G"; o["kind"] = "check"
            o["col"] = cols[-1]
            o["ink"] = strokes[0][1]; o["lw"] = strokes[-1][1]
            o.pop("f", None)
            return o
        if t == "S":
            o["t"] = "S"
            layers, _ = paint_layers(fills)
            o["col"] = layers[0][1] if layers and layers[0][0] == "s" else "ffffff"
            return o
        if t in ("V", "B", "P", "L"):
            stats["vectors_skipped"] += 1
            return None
        layers, icon = paint_layers(fills)
        if icon and not name.startswith("ico/") and (n.get("k") or len([L for L in layers if L[0] != "ia"]) > 0):
            icon = None   # an image fill on a container: not an icon slot
        if icon:
            o["t"] = "I"
            nm = name[4:] if name.startswith("ico/") else icon
            if icon.startswith("?"):
                nm = name[4:] if name.startswith("ico/") else ""
            o["icon"] = nm
            stats["icons"].add(nm)
            for L in layers:
                if L[0] == "ia":
                    o["ia"] = L[1]
            layers = [L for L in layers if L[0] != "ia"]
        if t == "E" and effects and any(e[0] == "LA" for e in effects):
            o["t"] = "B"
        if t == "T":
            o["tx"] = n.get("tx", "")
            if n.get("tc") == "U":
                o["tx"] = o["tx"].upper()
            o["fs"] = n.get("fs") or (n["seg"][0][1] if n.get("seg") else 14)
            a = n.get("a", "LTW")
            o["ax"] = {"L": "L", "C": "C", "R": "R", "J": "L"}.get(a[0], "L")
            o["ay"] = {"T": "T", "C": "C", "B": "B"}.get(a[1], "T")
            if a[2] == "H" or "\n" in o["tx"]:
                o["wrap"] = True
            if n.get("fn") and n["fn"] != "Fredoka One/Regular":
                o["font"] = n["fn"]
            if n.get("seg") and len(n["seg"]) > 1:
                parts = []
                for s_text, s_size, s_fill in n["seg"]:
                    sl, _ = paint_layers(s_fill)
                    col = sl[0][1] if sl and sl[0][0] == "s" else (sl[0][2][0][1] if sl and sl[0][0] == "g" else "ffffff")
                    esc = s_text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                    if s_size and o["fs"] and abs(s_size - o["fs"]) > 0.5:
                        parts.append('<font color="#%s" size="%d">%s</font>' % (col, round(s_size * 0.96), esc))
                    else:
                        parts.append('<font color="#%s">%s</font>' % (col, esc))
                o["rich"] = "".join(parts)
            if layers:
                o["tf"] = self.intern(layers)
            if stroke:
                st = stroke
                sl, _ = paint_layers(st[0])
                col = sl[0][1] if sl and sl[0][0] == "s" else "0b0c10"
                al = sl[0][2] if sl and sl[0][0] == "s" else 1
                o["sw"] = st[1]
                if col != "0b0c10" or al < 1:
                    o["sc"] = [col, al]
            if effects:
                for e in effects:
                    if e[0] == "D" and e[3] == 0:
                        o["sh"] = [e[1], e[2]]
                        if e[4] != "0b0c10" or e[5] < 1:
                            o["shc"] = [e[4], e[5]]
            return o
        if layers:
            o["f"] = self.intern(layers)
        if stroke and o["t"] != "I":
            sl, _ = paint_layers(stroke[0])
            if sl and sl[0][0] == "s":
                o["s"] = self.intern([sl[0][1], sl[0][2], stroke[1], stroke[2]])
            elif sl and sl[0][0] == "g":
                o["s"] = self.intern([sl[0][2][0][1], sl[0][2][0][2], stroke[1], stroke[2]])
        if effects:
            ef = []
            for e in effects:
                if e[0] in ("D", "I"):
                    ef.append([e[0].lower(), e[1], e[2], e[3], e[4], e[5], e[6]])
                elif e[0] == "LA":
                    ef.append(["lb", e[1]])
            if ef:
                o["e"] = self.intern(ef)
        kids = n.get("k")
        if kids:
            # group children are positioned in the containing frame's space: make them group-relative
            gx, gy = (n["p"][0], n["p"][1]) if t == "G" else (0, 0)
            ks = []
            names = []
            for c in kids:
                cc = self.node(c, gx, gy, o)
                if cc:
                    ks.append(cc)
                    names.append(cc["n"])
            if ks:
                o["k"] = ks
            if "ink body" in names and "lip" in names and ("face" in names or "body" in names):
                lip = ks[names.index("lip")]
                face = ks[names.index("face") if "face" in names else names.index("body")]
                o["key"] = round(lip["y"] - face["y"], 1)
        return o


def lua_str(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")
    return '"' + s + '"'


IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua(v, ind=""):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v.is_integer():
            return str(int(v))
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        return "{" + ",".join(lua(x, ind) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        order = ["t", "n", "x", "y", "w", "h"]
        keys = [k for k in order if k in v] + [k for k in v if k not in order and k != "k"]
        for k in keys:
            parts.append((k if IDENT.match(k) else "[" + lua_str(k) + "]") + "=" + lua(v[k], ind))
        if "k" in v:
            parts.append("k={\n" + ind + " " + (",\n" + ind + " ").join(lua(c, ind + " ") for c in v["k"]) + "}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def build():
    os.makedirs(DEST, exist_ok=True)
    index = []
    for rid, meta in ROOTS.items():
        path = os.path.join(OUT, rid.replace(":", "-") + ".json")
        if not os.path.exists(path):
            print("missing export", rid, meta["mod"])
            continue
        data = json.load(open(path, encoding="utf-8"))
        em = Emitter(data["d"])
        root = data["t"]
        if meta.get("kind") == "hud":
            comps = {}
            for c in root.get("k", []):
                nm = em.name(c)
                if c["t"] in ("C", "F", "I") and nm.startswith("hud/"):
                    node = em.node(c, c["p"][0], c["p"][1])
                    node["x"], node["y"] = 0, 0
                    comps[nm] = node
            body = "return {\n P = " + lua(em.P) + ",\n C = {\n" + ",\n".join("  [" + lua_str(k) + "] = " + lua(v, "  ") for k, v in comps.items()) + "\n }\n}\n"
            index.append((meta["mod"], rid, "hud", list(comps.keys())))
        else:
            node = em.node(root)
            node["x"], node["y"] = 0, 0
            body = "return {\n id = " + lua_str(rid) + ", name = " + lua_str(em.name(root)) + ",\n P = " + lua(em.P) + ",\n root = " + lua(node, " ") + "\n}\n"
            index.append((meta["mod"], rid, "window", [em.name(root)]))
        hdr = "--!nolint\n-- GENERATED by roblox/tools/figma_export/build_layouts.py from Figma %s (%s). Do not edit by hand:\n-- re-export the frame and rebuild. Sample values in the text are Figma's placeholder save state.\n" % (rid, meta["mod"])
        with open(os.path.join(DEST, meta["mod"] + ".luau"), "w", encoding="utf-8", newline="\n") as f:
            f.write(hdr + body)
    print("modules:", len(index))
    print("vectors skipped:", stats["vectors_skipped"])
    print("unknown images:", sorted(stats["unknown_images"]))
    json.dump(sorted(stats["icons"]), open(os.path.join(HERE, "icons_used.json"), "w"))
    return index


if __name__ == "__main__":
    build()
