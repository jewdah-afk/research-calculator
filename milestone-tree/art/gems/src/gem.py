"""gem.py - one faceted radiant-cut crystal (brilliant crown + step outline), gold bezel, inner glow core.
Built once; set_look(hex, variant) only swaps material values between renders."""
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # bl.py (shared bpy helpers) lives next to this file
import bl, bpy, bmesh
from mathutils import Vector

# ---------------------------------------------------------------- proportions (gem local: Z = table normal)
W = 1.0          # half width of the girdle outline
CH = 0.30        # corner chamfer (octagon)
TABLE = 0.56     # table size relative to girdle
G = 0.035        # half girdle thickness
CROWN = 0.30     # crown height above girdle top
DEPTH = 0.88     # pavilion depth below girdle bottom
STAR = 0.46      # star-point position between table edge and girdle (0..1)
PAV = 0.52       # pavilion break ring radius factor


def octagon(scale=1.0):
    c = 1.0 - CH
    pts = [(1, -c), (1, c), (c, 1), (-c, 1), (-1, c), (-1, -c), (-c, -1), (c, -1)]
    return [Vector((x * W * scale, y * W * scale, 0)) for x, y in pts]


def offset_outline(pts, d):
    """Offset a convex CCW polygon outward by d (mitred corners)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        n0 = Vector((e0.y, -e0.x, 0))
        n1 = Vector((e1.y, -e1.x, 0))
        m = n0 + n1
        out.append(p1 + m * (d / (1.0 + n0.dot(n1))))
    return out


def gem_bmesh(scale=1.0):
    bm = bmesh.new()
    oc = octagon()
    girdle = []
    for i in range(8):
        girdle.append(oc[i])
        girdle.append((oc[i] + oc[(i + 1) % 8]) * 0.5)
    zt, zb = G, -G
    ztab = G + CROWN
    zcul = -G - DEPTH
    V = lambda v, z: bm.verts.new(Vector((v.x * scale, v.y * scale, z * scale)))
    GT = [V(p, zt) for p in girdle]
    GB = [V(p, zb) for p in girdle]
    T = [V(p * TABLE, ztab) for p in oc]
    K = []
    for i in range(8):
        tm = (oc[i] + oc[(i + 1) % 8]) * 0.5 * TABLE
        gm = girdle[2 * i + 1]
        p = tm.lerp(gm, STAR)
        K.append(V(p, ztab + (zt - ztab) * (STAR * 0.92)))
    P = []
    for i in range(8):
        p = girdle[2 * i + 1] * PAV
        P.append(V(p, zb + (zcul - zb) * 0.52))
    C = V(Vector((0, 0, 0)), zcul)
    F = lambda *vs: bm.faces.new(vs)
    F(*T)                                              # table
    for i in range(8):
        j = (i + 1) % 8
        F(T[i], T[j], K[i])                            # star facets
        F(T[i], K[i], GT[2 * i])                       # kite (split) - right half
        F(T[i], GT[2 * i], K[i - 1])                   # kite - left half
        F(K[i], GT[2 * i + 1], GT[2 * i])              # upper girdle facets
        F(K[i], GT[(2 * i + 2) % 16], GT[2 * i + 1])
    for j in range(16):
        k = (j + 1) % 16
        F(GT[j], GT[k], GB[k], GB[j])                  # girdle band
    for i in range(8):
        F(GB[2 * i], GB[2 * i + 1], P[i])              # lower girdle facets
        F(GB[2 * i + 1], GB[(2 * i + 2) % 16], P[i])
        F(GB[2 * i], P[i], C)                          # pavilion mains (split kites)
        F(P[i - 1], GB[2 * i], C)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def make_gem(name="Gem", m=None, scale=1.0, coll=None):
    bm = gem_bmesh(scale)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    if m:
        me.materials.append(m)
    return ob


def make_bezel(name="Bezel", m=None, d0=0.045, hw=0.062, hz=0.125, r=0.045, zc=0.0, n_corner=5, coll=None):
    """Octagon ring swept with a rounded-rectangle profile (offset d, z)."""
    prof = []
    corners = [(d0 + hw - r, zc + hz - r, 0), (d0 - hw + r, zc + hz - r, 90),
               (d0 - hw + r, zc - hz + r, 180), (d0 + hw - r, zc - hz + r, 270)]
    for cx, cz, a0 in corners:
        for k in range(n_corner + 1):
            a = math.radians(a0 + 90 * k / n_corner)
            prof.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    oc = octagon()
    bm = bmesh.new()
    rings = []
    for d, z in prof:
        ring = [bm.verts.new(Vector((p.x, p.y, z))) for p in offset_outline(oc, d)]
        rings.append(ring)
    n, m_ = len(oc), len(rings)
    for a in range(m_):
        b = (a + 1) % m_
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[a][i], rings[a][j], rings[b][j], rings[b][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    if m:
        me.materials.append(m)
    bl.smooth(ob, 40)
    return ob


# ---------------------------------------------------------------- materials (node handles kept for fast swaps)
H = {}


def gem_material():
    """Glass surface + volume: calibrated absorption (keeps hue) + radial inner-glow emission."""
    m = bpy.data.materials.new("GemCrystal")
    nt = bl._nt(m)
    p = nt.nodes["Principled BSDF"]
    p.inputs["Transmission Weight"].default_value = 1.0
    p.inputs["Roughness"].default_value = 0.0
    p.inputs["IOR"].default_value = 2.0
    p.inputs["Base Color"].default_value = (1, 1, 1, 1)
    out = nt.nodes["Material Output"]
    ab = nt.nodes.new("ShaderNodeVolumeAbsorption")
    em = nt.nodes.new("ShaderNodeEmission")
    add = nt.nodes.new("ShaderNodeAddShader")
    # radial falloff from the glow centre (object space; gem local z = table normal)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sub = nt.nodes.new("ShaderNodeVectorMath"); sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = (0, 0, LOOK["glow_z"])
    mul = nt.nodes.new("ShaderNodeVectorMath"); mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = (1.0, 1.0, 1.5)
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], sub.inputs[0])
    nt.links.new(sub.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], ln.inputs[0])
    f = bl.map_range(nt, ln.outputs["Value"], 0.0, 0.85, 1.0, 0.0, smooth=True)
    glow_r = f.node.inputs["From Max"]
    f2 = bl.math_node(nt, "POWER", f, 2.0)
    hot = bl.math_node(nt, "MULTIPLY", f2, 1.0)                  # core gain
    stren = bl.math_node(nt, "ADD", hot, 0.0)                    # + base glow everywhere
    mixc = nt.nodes.new("ShaderNodeMix"); mixc.data_type = "RGBA"
    A, Bs, R = bl._rgba_io(mixc)
    nt.links.new(bl.math_node(nt, "POWER", f, 3.0), mixc.inputs["Factor"])
    nt.links.new(R, em.inputs["Color"])
    nt.links.new(stren, em.inputs["Strength"])
    nt.links.new(ab.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Volume"])
    H.update(gem_p=p, gem_ab=ab, gem_em=em, glow_edge=A, glow_center=Bs, glow_gain=hot.node.inputs[1],
             glow_base=stren.node.inputs[1], glow_r=glow_r)
    return m


def gold_material():
    m = bpy.data.materials.new("Gold")
    nt = bl._nt(m)
    p = nt.nodes["Principled BSDF"]
    p.inputs["Metallic"].default_value = 1.0
    p.inputs["Roughness"].default_value = 0.2
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = bl.hexc("#f2c35a")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 40.0
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    v = bl.map_range(nt, nz.outputs["Fac"], 0.3, 0.7, 0.86, 1.0, smooth=True)
    nt.links.new(bl.mix_rgb(nt, 1.0, rgb.outputs[0], v, blend="MULTIPLY"), p.inputs["Base Color"])
    H.update(gold_p=p, gold_rgb=rgb.outputs[0])
    return m


def absorption_for(c, L0=None, lum=0.25, neutral=None):
    """Volume absorption (color, density) so light crossing ~L0 of crystal ends up with the hue of c
    (Beer-Lambert per channel) instead of drifting toward the dominant channel."""
    L0 = L0 or LOOK["L0"]
    mx = max(c)
    n = LOOK["abs_neutral"] if neutral is None else neutral
    g = LOOK["abs_grey"] * min(1.3, max(0.3, (0.22 / max(lum, 0.02)) ** 0.7))  # light hues absorb less
    sig = [(1 - n) * -math.log(max(ch / mx, 0.015)) / L0 + n * g for ch in c]
    dens = max(max(sig), 1e-3)
    return tuple(1.0 - s_ / dens for s_ in sig), dens


LOOK = dict(glow_base=0.04, glow_gain=24.0, glow_r=0.5, center_white=0.15, tint=0.12, L0=3.0, env_gain=1.5,
            abs_neutral=0.75, abs_grey=0.5, lock_abs=0.4, lock_glow=1.0, lock_env=2.2, lock_spec=0.45, abs_neutral_warm=0.3, rdy_gain=1.35, rdy_white=1.2, glow_z=-0.24)


def set_look(hexcol, variant="base"):
    """Swap all color-dependent values. variant: base | locked | ready."""
    c = Vector(bl.hexc(hexcol)[:3])
    lum = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    grey = Vector((lum, lum, lum))
    white = Vector((1, 1, 1))
    k = min(2.2, max(0.7, (0.32 / max(lum, 0.04)) ** 0.5))    # dim hues get a bit more glow
    L = LOOK
    if variant == "locked":
        tintc = grey.lerp(c, 0.13) / max(lum, 0.02)            # mostly grey, faint hint of the layer hue
        H["gem_ab"].inputs["Color"].default_value = (0.8, 0.8, 0.82, 1)
        H["gem_ab"].inputs["Density"].default_value = L["lock_abs"]
        H["glow_edge"].default_value = (*tintc * 0.3, 1)
        H["glow_center"].default_value = (*tintc * 0.3, 1)
        H["glow_gain"].default_value = L["lock_glow"]
        H["glow_base"].default_value = 0.0
        H["glow_r"].default_value = L["glow_r"]
        H["gem_p"].inputs["Base Color"].default_value = (0.7, 0.72, 0.75, 1)
        H["gold_p"].inputs["Roughness"].default_value = 0.42
        H["gold_rgb"].default_value = bl.hexc("#8c857a")
        H["gem_p"].inputs["Specular IOR Level"].default_value = L["lock_spec"]
        H["env_tint"].default_value = (*tintc * 0.55, 1)
        H["env_gain"].default_value = L["lock_env"]
    else:
        rdy = variant == "ready"
        import colorsys
        hue = colorsys.rgb_to_hsv(*[bl.lin2srgb(v) for v in c])[0] * 360
        warm = 40 <= hue <= 75            # yellows/golds: let deep paths drift to amber instead of olive
        ac, dens = absorption_for(c, lum=lum, neutral=LOOK["abs_neutral_warm"] if warm else None)
        H["gem_ab"].inputs["Color"].default_value = (*ac, 1)
        H["gem_ab"].inputs["Density"].default_value = dens
        H["glow_edge"].default_value = (*c, 1)
        H["glow_center"].default_value = (*c.lerp(white, L["center_white"] * (L["rdy_white"] if rdy else 1.0)), 1)
        H["glow_gain"].default_value = L["glow_gain"] * k * (L["rdy_gain"] if rdy else 1.0)
        H["glow_base"].default_value = L["glow_base"] * k * (1.8 if rdy else 1.0)
        H["glow_r"].default_value = L["glow_r"] * (1.15 if rdy else 1.0)
        H["gem_p"].inputs["Base Color"].default_value = (*white.lerp(c / max(c), L["tint"]), 1)
        H["gold_p"].inputs["Roughness"].default_value = 0.2
        H["gold_rgb"].default_value = bl.hexc("#f2c35a")
        H["gem_p"].inputs["Specular IOR Level"].default_value = 0.5
        H["env_tint"].default_value = (*(c / max(c)), 1)
        H["env_gain"].default_value = L["env_gain"] * (1.3 if rdy else 1.0)


# ---------------------------------------------------------------- lighting: gem-lite style studio dome
ENV = dict(
    dome=("#0c0e14", "#161a24", "#050608"),
    boxes=[
        dict(dir=(-0.55, -0.75, 0.55), deg=14, color="#ffffff", power=22.0),   # key upper-left
        dict(dir=(0.62, -0.72, 0.35), deg=11, color="#eaf2ff", power=10.0),    # right
        dict(dir=(-0.2, -0.85, -0.45), deg=10, color="#fff3e6", power=6.0),    # low left
        dict(dir=(0.35, -0.9, -0.2), deg=6, color="#ffffff", power=16.0),      # small hard right-low
        dict(dir=(0.0, -0.55, 0.85), deg=18, color="#ffffff", power=1.5),      # top
        dict(dir=(-0.9, -0.2, 0.1), deg=8, color="#ffffff", power=12.0),       # side left strip
        dict(dir=(0.1, 0.9, 0.4), deg=22, color="#dfe8ff", power=5.0),         # back rim (transmitted)
        dict(dir=(0.0, 0.2, -1.0), deg=35, color="#ffffff", power=1.2),        # floor bounce
        dict(dir=(0.0, -1.0, 0.12), deg=9, color="#ffffff", power=5.0),        # camera axis (lights the table window)
    ], strength=1.0, knee=0.6)


def gem_world():
    """Dark dome + softboxes around the camera axis (-Y) so the pavilion's total internal reflections
    alternate bright/dark (scintillation). Rays that leave the crystal by refraction (transmission rays) see
    the dome tinted with the layer colour: the brilliance pattern inside keeps the exact hue (no Beer-Lambert
    hue drift), while first-surface glints and the gold bezel still reflect white light."""
    t, h, b = ENV["dome"]
    w = bl.world_studio(top=t, horizon=h, bottom=b, strength=ENV["strength"], boxes=ENV["boxes"])
    nt = w.node_tree
    bg = nt.nodes["Background"]
    src = bg.inputs["Color"].links[0].from_socket
    lp = nt.nodes.new("ShaderNodeLightPath")
    tint = nt.nodes.new("ShaderNodeRGB")
    tint.outputs[0].default_value = (1, 1, 1, 1)
    # soft-compress the dome luminance (x / (x + knee)) before tinting, so the brilliance inside the crystal
    # stays in a saturated range instead of blowing past the view transform's desaturating shoulder
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(src, bw.inputs[0])
    knee = nt.nodes.new("ShaderNodeValue")
    knee.outputs[0].default_value = ENV["knee"]
    comp = bl.math_node(nt, "DIVIDE", bw.outputs[0], bl.math_node(nt, "ADD", bw.outputs[0], knee.outputs[0]))
    tinted = bl.mix_rgb(nt, 1.0, tint.outputs[0], comp, blend="MULTIPLY")
    gain = nt.nodes.new("ShaderNodeValue")
    gain.outputs[0].default_value = 1.0
    boosted = nt.nodes.new("ShaderNodeVectorMath"); boosted.operation = "SCALE"
    nt.links.new(tinted, boosted.inputs[0]); nt.links.new(gain.outputs[0], boosted.inputs["Scale"])
    sel = bl.mix_rgb(nt, lp.outputs["Is Transmission Ray"], src, boosted.outputs[0])
    nt.links.new(sel, bg.inputs["Color"])
    H.update(env_tint=tint.outputs[0], env_gain=gain.outputs[0], env_knee=knee.outputs[0])
    return w


def build(res=512, transparent=True):
    sc = bl.reset(fps=24, frames=(1, 96))
    bl.cycles(samples=96, res=(res, res), threshold=0.015, transparent=transparent, view="Khronos PBR Neutral", look=None,
              bounces=dict(total=24, diffuse=2, glossy=12, transmission=16, volume=2, transparent=8),
              clamp_indirect=6.0, filter_glossy=0.5, color_depth="16")
    gm, au = gem_material(), gold_material()
    rig = bl.empty("GemRig", (0, 0, 0))
    gem = make_gem("Gem", gm)
    bez = make_bezel("Bezel", au)
    for o in (gem, bez):
        bl.parent(o, rig)
    rig.rotation_euler = (math.radians(90), 0, 0)      # table faces -Y (camera)
    gem_world()
    cam = bl.camera((0, -7.0, 0.9), (0, 0, 0), lens=85)
    set_look(bl.TREE["m"])
    return dict(sc=sc, gem=gem, bezel=bez, rig=rig, cam=cam)
