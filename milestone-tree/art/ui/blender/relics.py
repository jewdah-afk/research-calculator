"""relics.py - the 3D hero pieces of the UI kit: gold metal + layer crystal, rendered front-on (orthographic) in Cycles.

Everything is modelled in a local XY plane (x right, y up, z toward the viewer) under one rig that turns it to face -Y,
so the scene reuses the layer-gem studio (art/gems/src/gem.py: gem_world, gem_material, set_look) and the gems' colour
management (Khronos PBR Neutral: AgX shifts the layer hues). 1 unit = 100 px of the render, and renders are 2x the
1080p display size, so 1 unit = 50 display px.

A builder returns the objects of one piece; build.py sets the frame (camera rect in units) and renders it.
"""
import sys, os, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'gems', 'src'))
import bl, bpy, bmesh          # noqa: E402
import gem as G                 # noqa: E402
from mathutils import Vector, Matrix   # noqa: E402

PX = 100.0          # render px per unit
RIG = None


# ------------------------------------------------------------------------------------------------ scene
def setup(res, samples=64, threshold=0.01):
    """Fresh scene: gem studio world, the rig, Cycles at res (w, h), transparent film, Khronos PBR Neutral."""
    global RIG
    bl.reset(fps=24, frames=(1, 1))
    bl.cycles(samples=samples, res=res, threshold=threshold, transparent=True, view="Khronos PBR Neutral", look=None,
              bounces=dict(total=20, diffuse=3, glossy=10, transmission=14, volume=2, transparent=8),
              clamp_indirect=6.0, filter_glossy=0.4, color_depth="16")
    G.H.clear()
    G.gem_material()            # populates G.H (set_look needs every handle)
    G.gold_material()
    ui_world()
    RIG = bl.empty("Rig", (0, 0, 0))
    RIG.rotation_euler = (math.radians(90), 0, 0)
    return RIG


UI_ENV = dict(
    dome=("#07080c", "#0b0d13", "#040405"),
    # softboxes in LOCAL coords (x right, y up, z = toward the viewer). A face tilted by t from the viewer reflects the
    # environment at 2t from the view axis, so rounded mouldings sweep across these: bright upper-left, dark lower-right.
    boxes=[
        dict(dir=(-0.50, 0.52, 0.69), deg=17, color="#fff6ea", power=13.0),    # key, 45 deg upper-left
        dict(dir=(-0.70, 0.62, 0.30), deg=22, color="#ffe9cf", power=5.0),     # key spill, low upper-left
        dict(dir=(0.46, 0.60, 0.65), deg=15, color="#e8f0ff", power=3.2),      # upper-right fill
        dict(dir=(-0.55, -0.45, 0.70), deg=12, color="#fff0e0", power=1.6),    # lower-left kick
        dict(dir=(0.62, -0.58, 0.52), deg=10, color="#dfe8ff", power=1.1),     # lower-right rim
        dict(dir=(0.0, 0.0, 1.0), deg=13, color="#ffffff", power=0.7),         # the view axis: flat faces (dim)
        dict(dir=(0.0, 0.05, -1.0), deg=40, color="#ffffff", power=1.0),       # behind the piece (glass transmission)
    ], strength=1.0, knee=0.6)


def ui_world():
    """gem.gem_world's structure (transmission rays see the dome tinted by the layer hue, so crystals keep their
    hue) with a softbox rig laid out for front-on orthographic UI pieces."""
    saved = G.ENV
    env = dict(UI_ENV)
    env["boxes"] = [dict(b, dir=(b["dir"][0], -b["dir"][2], b["dir"][1])) for b in UI_ENV["boxes"]]   # local -> world
    G.ENV = env
    try:
        return G.gem_world()
    finally:
        G.ENV = saved


def camera_rect(x0, y0, x1, y1):
    """Orthographic camera that frames the local rect (units). The render aspect must match the rect."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = x1 - x0, y1 - y0
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = max(w, h)
    cd.clip_start, cd.clip_end = 0.1, 100
    ob = bpy.data.objects.new("Cam", cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (cx, -30.0, cy)                 # local (x, y) -> world (x, z); the camera sits at -Y
    ob.rotation_euler = (math.radians(90), 0, 0)  # looks along +Y, up = +Z
    bpy.context.scene.camera = ob
    return ob


def own(ob):
    """Parent to the rig (local XY plane -> faces the camera)."""
    ob.parent = RIG
    return ob


# ------------------------------------------------------------------------------------------------ materials
def gold(name="Gold", color="#f2c35a", rough=0.22, patina="#4a2a0c", bump=0.35, tarnish=0.0):
    """Antique gold: hammered micro bump, darker bronze in the recesses (AO), optional tarnish (CR)."""
    m = bpy.data.materials.new(name)
    nt = bl._nt(m)
    p = nt.nodes["Principled BSDF"]
    p.inputs["Metallic"].default_value = 1.0
    p.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 60.0
    nz.inputs["Detail"].default_value = 8.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    base = nt.nodes.new("ShaderNodeRGB")
    base.outputs[0].default_value = bl.hexc(color)
    dark = nt.nodes.new("ShaderNodeRGB")
    dark.outputs[0].default_value = bl.hexc(patina)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.12
    ao.samples = 8
    aof = bl.map_range(nt, ao.outputs["AO"], 0.35, 0.95, 0.0, 1.0, smooth=True)
    col = bl.mix_rgb(nt, aof, dark.outputs[0], base.outputs[0])
    v = bl.map_range(nt, nz.outputs["Fac"], 0.3, 0.7, 0.88, 1.0, smooth=True)
    col = bl.mix_rgb(nt, 1.0, col, v, blend="MULTIPLY")
    if tarnish:
        tz = nt.nodes.new("ShaderNodeTexNoise")
        tz.inputs["Scale"].default_value = 7.0
        tz.inputs["Detail"].default_value = 6.0
        nt.links.new(tc.outputs["Object"], tz.inputs["Vector"])
        tf = bl.map_range(nt, tz.outputs["Fac"], 0.5, 0.7, 0.0, tarnish, smooth=True)
        tcol = nt.nodes.new("ShaderNodeRGB")
        tcol.outputs[0].default_value = bl.hexc("#3b4a2a")
        col = bl.mix_rgb(nt, tf, col, tcol.outputs[0])
        nt.links.new(bl.map_range(nt, tz.outputs["Fac"], 0.5, 0.7, rough, rough + 0.25 * tarnish), p.inputs["Roughness"])
    nt.links.new(col, p.inputs["Base Color"])
    if bump:
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.004
        nt.links.new(nz.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], p.inputs["Normal"])
    return m


def crystal(name, hexcol, glow=3.0, tint=0.35, L0=0.35, rough=0.03):
    """Layer crystal: clear glass surface, Beer-Lambert absorption calibrated to keep the hue (gem.absorption_for),
    plus a volume glow in the hue so it reads as lit from within."""
    m = bpy.data.materials.new(name)
    nt = bl._nt(m)
    p = nt.nodes["Principled BSDF"]
    c = Vector(bl.hexc(hexcol)[:3])
    lum = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    p.inputs["Transmission Weight"].default_value = 1.0
    p.inputs["Roughness"].default_value = rough
    p.inputs["IOR"].default_value = 1.75
    w = Vector((1, 1, 1))
    p.inputs["Base Color"].default_value = (*w.lerp(c / max(c), tint), 1)
    out = nt.nodes["Material Output"]
    ab = nt.nodes.new("ShaderNodeVolumeAbsorption")
    ac, dens = G.absorption_for(tuple(c), L0=L0, lum=lum)
    ab.inputs["Color"].default_value = (*ac, 1)
    ab.inputs["Density"].default_value = dens
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*c, 1)
    k = min(2.2, max(0.7, (0.32 / max(lum, 0.04)) ** 0.5))
    em.inputs["Strength"].default_value = glow * k
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(ab.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Volume"])
    return m


def hexmix(a, b, t):
    """Mix two sRGB hex colours (in sRGB, like a painter would) -> hex."""
    ca = [int(a.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4)]
    return '#' + ''.join('%02x' % round(x + (y - x) * t) for x, y in zip(ca, cb))


def glowmat(name, hexcol, strength=6.0):
    return bl.mat(name, bl.scalec(hexcol, 0.25), rough=0.3, emission=hexcol, strength=strength)


def stone(name="Stone", color="#2a2533", color2="#4a4358", rough=0.8, bump=0.6, scale=4.0):
    """Carved stone: two-tone noise, strong bump, voronoi chisel pits."""
    m = bl.mat(name, color, rough=rough, noise=dict(scale=scale, detail=10, color_var=0.9, color2=color2, rough_var=0.1,
                                                     bump=0.0, contrast=0.8, roughness=0.6))
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.inputs["Scale"].default_value = scale * 3.0
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale * 6.0
    nz.inputs["Detail"].default_value = 12.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    h = bl.math_node(nt, "ADD", bl.math_node(nt, "MULTIPLY", vo.outputs["Distance"], 0.6), nz.outputs["Fac"])
    bn = nt.nodes.new("ShaderNodeBump")
    bn.inputs["Strength"].default_value = bump
    bn.inputs["Distance"].default_value = 0.02
    nt.links.new(h, bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], p.inputs["Normal"])
    return m


def dark_glass(name="DarkGlass", hexcol="#07060c", rough=0.3):
    """The dark crystal face of medallions: near-black glass (the highlight comes from domed geometry)."""
    return bl.mat(name, hexcol, rough=rough, coat=0.5, coat_rough=0.05, specular=0.35)


def lit_crystal(name, hexcol, mode="vertical", lo=0.12, hi=1.0, span=1.0, center=(0.0, 0.0), cells=6.0, cell_k=0.35,
                hot=(0.0, 0.0)):
    """A crystal lit from within, as a surface: dark hue base, emission following a gradient (vertical: top bright;
    radial: centre bright, offset by `hot`), broken up by voronoi 'inner facets', under a glossy clear coat so the
    softboxes give crisp highlights on its facets. Emission stays under ~1.2 so Khronos PBR Neutral keeps the hue."""
    m = bpy.data.materials.new(name)
    nt = bl._nt(m)
    p = nt.nodes["Principled BSDF"]
    c = Vector(bl.hexc(hexcol)[:3])
    p.inputs["Base Color"].default_value = (*(c * 0.12), 1)
    p.inputs["Roughness"].default_value = 0.25
    p.inputs["Coat Weight"].default_value = 1.0
    p.inputs["Coat Roughness"].default_value = 0.02
    p.inputs["Coat IOR"].default_value = 1.6
    p.inputs["Emission Color"].default_value = (*c, 1)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    if mode == "vertical":
        g = bl.map_range(nt, sep.outputs["Y"], -span, span, lo, hi, smooth=False)
    else:
        sub = nt.nodes.new("ShaderNodeVectorMath"); sub.operation = "SUBTRACT"
        sub.inputs[1].default_value = (center[0] + hot[0], center[1] + hot[1], 0)
        nt.links.new(tc.outputs["Object"], sub.inputs[0])
        ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
        nt.links.new(sub.outputs[0], ln.inputs[0])
        g = bl.map_range(nt, ln.outputs["Value"], 0.0, span, hi, lo, smooth=True)
    vo = nt.nodes.new("ShaderNodeTexVoronoi")
    vo.feature = "F1"
    vo.inputs["Scale"].default_value = cells
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    v = bl.map_range(nt, vo.outputs["Distance"], 0.0, 0.6, 1.0 - cell_k, 1.0 + cell_k * 0.6)
    st = bl.math_node(nt, "MULTIPLY", g, v)
    nt.links.new(st, p.inputs["Emission Strength"])
    return m


def lit_backing(name, hexcol, mode="vertical", lo=0.18, hi=1.6, span=1.0, center=(0.0, 0.0)):
    """Light from inside a crystal: an emission whose strength follows a gradient in object space (vertical: bright
    top -> deep bottom over +-span; radial: bright centre -> deep rim over span)."""
    m = bpy.data.materials.new(name)
    nt = bl._nt(m)
    out = nt.nodes["Material Output"]
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = bl.hexc(hexcol)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    if mode == "vertical":
        f = bl.map_range(nt, sep.outputs["Y"], -span, span, lo, hi, smooth=True)
    else:
        sub = nt.nodes.new("ShaderNodeVectorMath"); sub.operation = "SUBTRACT"
        sub.inputs[1].default_value = (center[0], center[1], 0)
        nt.links.new(tc.outputs["Object"], sub.inputs[0])
        ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
        nt.links.new(sub.outputs[0], ln.inputs[0])
        f = bl.map_range(nt, ln.outputs["Value"], 0.0, span, hi, lo, smooth=True)
    nt.links.new(f, em.inputs["Strength"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


# ------------------------------------------------------------------------------------------------ geometry helpers
def _obj(name, bm, m=None, smooth=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if m:
        me.materials.append(m)
    if smooth is not None:
        bl.smooth(ob, smooth)
    return own(ob)


def plate(name, poly, z0, h, m, bevel=0.02, seg=3, angle=35):
    """Extrude a 2D polygon [(x, y)] from z0 by h and bevel its edges."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z0)) for x, y in poly]
    f = bm.faces.new(vs)
    if f.normal.z < 0:
        f.normal_flip()
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    top = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, h))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj(name, bm, m)
    if bevel:
        bl.bevel_mod(ob, width=bevel, segments=seg, angle=angle)
    return ob


def ring_plate(name, outer, inner, z0, h, m, bevel=0.015, seg=3):
    """A flat ring between two closed polygons with the same vertex count (outer CCW)."""
    bm = bmesh.new()
    n = len(outer)
    ob_ = [bm.verts.new((x, y, z0)) for x, y in outer]
    ib_ = [bm.verts.new((x, y, z0)) for x, y in inner]
    ot_ = [bm.verts.new((x, y, z0 + h)) for x, y in outer]
    it_ = [bm.verts.new((x, y, z0 + h)) for x, y in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot_[i], ot_[j], it_[j], it_[i]))       # top
        bm.faces.new((ob_[j], ob_[i], ib_[i], ib_[j]))       # bottom
        bm.faces.new((ob_[i], ob_[j], ot_[j], ot_[i]))       # outer wall
        bm.faces.new((ib_[j], ib_[i], it_[i], it_[j]))       # inner wall
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj(name, bm, m)
    if bevel:
        bl.bevel_mod(ob, width=bevel, segments=seg, angle=35)
    return ob


def profile_sweep(name, path, prof, m, closed=True, smooth=40):
    """Sweep a 2D profile [(d, z)] (d = offset to the left of the path direction, z = height) along a closed or
    open 2D polyline path, with mitred joints. Gives mouldings with real bevels."""
    n = len(path)
    bm = bmesh.new()
    rings = []
    for i in range(n):
        p = Vector((*path[i], 0))
        if closed or 0 < i < n - 1:
            a = Vector((*path[i - 1], 0)) if (closed or i > 0) else p
            b = Vector((*path[(i + 1) % n], 0))
            e0 = (p - a).normalized()
            e1 = (b - p).normalized()
            n0 = Vector((-e0.y, e0.x, 0))
            n1 = Vector((-e1.y, e1.x, 0))
            mv = (n0 + n1)
            mv = mv / max(1e-4, (1 + n0.dot(n1)))
        else:
            e = (Vector((*path[1], 0)) - p) if i == 0 else (p - Vector((*path[i - 1], 0)))
            e.normalize()
            mv = Vector((-e.y, e.x, 0))
        rings.append([bm.verts.new(p + mv * d + Vector((0, 0, z))) for d, z in prof])
    k = len(prof)
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        for t in range(k - 1):
            bm.faces.new((rings[i][t], rings[j][t], rings[j][t + 1], rings[i][t + 1]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, m, smooth=smooth)


def tube(name, pts, r, m, taper=None, res=5, cyclic=False):
    """Round tube along 3D points (a curve with bevel). taper(t) scales the radius along it."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = res
    cu.fill_mode = "FULL"
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.use_cyclic_u = cyclic
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2] if len(p) > 2 else 0.0, 1)
        sp.points[i].radius = taper(i / max(1, len(pts) - 1)) if taper else 1.0
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(m)
    return own(ob)


def spiral(cx, cy, r0, turns, a0, cw=True, k=None, n=90, z=0.0):
    """Log spiral points from radius r0 at angle a0, curling inward over `turns`."""
    k = k if k is not None else math.log(8.0) / (turns * 2 * math.pi)
    pts = []
    for i in range(n + 1):
        t = i / n * turns * 2 * math.pi
        a = a0 - t if cw else a0 + t
        r = r0 * math.exp(-k * t)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def prism(name, r, length, tip, m, sides=6, base_k=0.75, seed=0):
    """Crystal: n-gon prism with a pointed tip, along +Z from the origin (base narrower: grows out of a cluster)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rot = rnd.random() * math.pi
    ring = lambda rr, z: [bm.verts.new((rr * math.cos(rot + 2 * math.pi * i / sides) * (1 + 0.12 * math.sin(i * 2.3 + seed)),
                                         rr * math.sin(rot + 2 * math.pi * i / sides), z)) for i in range(sides)]
    b = ring(r * base_k, 0.0)
    t = ring(r, length)
    apex = bm.verts.new((r * 0.08 * (rnd.random() - 0.5), r * 0.08 * (rnd.random() - 0.5), length + tip))
    bm.faces.new(list(reversed(b)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((b[i], b[j], t[j], t[i]))
        bm.faces.new((t[i], t[j], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _obj(name, bm, m)
    bl.flat(ob)
    return ob


def orient(ob, pos, direction, roll=0.0):
    """Point an object's +Z along `direction` (local XYZ), placed at pos (local)."""
    d = Vector(direction).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    mat = Matrix.Translation(Vector(pos)) @ q.to_matrix().to_4x4() @ Matrix.Rotation(roll, 4, "Z")
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.matrix_basis = mat
    return ob


def set_gem(name, hexcol, pos, s, z=0.0, variant="base", bezel=True):
    """A radiant-cut layer gem (the same model and material as the map gems) at local pos, table toward the viewer."""
    G.set_look(hexcol, variant)
    gm = bpy.data.materials["GemCrystal"]
    g = G.make_gem(name, gm)
    g.parent = RIG
    g.scale = (s, s, s)
    g.location = (pos[0], pos[1], z + (G.G + G.DEPTH) * s)
    out = [g]
    if bezel:
        b = G.make_bezel(name + "Bezel", bpy.data.materials["Gold"])
        b.parent = RIG
        b.scale = (s, s, s)
        b.location = g.location
        out.append(b)
    # the absorption density is per world unit: a small gem needs it scaled up to keep its colour
    ab = G.H["gem_ab"].inputs["Density"]
    ab.default_value = ab.default_value / max(0.05, s)
    return out


def cabochon(name, r, h, m, pos=(0, 0), z=0.0, seg=64):
    """A domed cabochon (squashed hemisphere) of radius r, height h."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
    for v in list(bm.verts):
        if v.co.z < -1e-6:
            v.co.z = 0.0
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    for v in bm.verts:
        v.co = Vector((v.co.x * r, v.co.y * r, v.co.z * h))
    ob = _obj(name, bm, m, smooth=180)
    ob.location = (pos[0], pos[1], z)
    return ob


def disc(name, r, h, m, pos=(0, 0), z=0.0, seg=96, bevel=0.02):
    ob = bl.cyl(name, r=r, depth=h, verts=seg, m=m, bevel=bevel)
    ob.location = (pos[0], pos[1], z + h / 2)
    own(ob)
    bl.smooth(ob, 40)
    return ob


def torus(name, R, r, m, pos=(0, 0), z=0.0):
    ob = bl.torus(name, R=R, r=r, seg=128, rseg=24, loc=(pos[0], pos[1], z), m=m)
    own(ob)
    return ob


def circle(cx, cy, r, n=96, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * i / n), cy + r * math.sin(a0 + 2 * math.pi * i / n)) for i in range(n)]


def ngon(cx, cy, r, n, a0=0.0):
    return circle(cx, cy, r, n, a0)


def catmull(pts, per=12):
    """Catmull-Rom through 2D/3D points -> dense list."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (Vector(P[i - 1]), Vector(P[i]), Vector(P[i + 1]), Vector(P[i + 2]))
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(Vector(pts[-1]))
    return [tuple(v) for v in out]


def stroke_poly(pts, width):
    """Outline polygon of a calligraphic stroke along 2D points; width(t) gives the full width at t in [0, 1]."""
    n = len(pts)
    L, Rr = [], []
    for i in range(n):
        a = Vector(pts[max(0, i - 1)][:2])
        b = Vector(pts[min(n - 1, i + 1)][:2])
        d = (b - a)
        d = d.normalized() if d.length > 1e-9 else Vector((1, 0))
        nrm = Vector((-d.y, d.x))
        w = width(i / (n - 1)) / 2
        p = Vector(pts[i][:2])
        L.append(tuple(p + nrm * w))
        Rr.append(tuple(p - nrm * w))
    poly = L + list(reversed(Rr))
    a = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return poly if a > 0 else list(reversed(poly))


def cast(name, pts, width, m, z0=0.0, h=0.06, bevel=None, seg=5):
    """A cast-metal stroke (filigree ribbon): stroke outline, extruded, heavily rounded so reflections sweep over it."""
    poly = stroke_poly(pts, width)
    wmax = max(width(t / 20) for t in range(21))
    ob = plate(name, poly, z0, h, m, bevel=bevel if bevel is not None else min(h * 0.9, wmax * 0.42), seg=seg, angle=60)
    return ob


def ribbon(name, pts, width, m, height=None, z0=0.0, k=11, cap=True, sharp=0.55):
    """Cast filigree: a stroke along 2D points with a rounded (half-ellipse) cross-section whose width follows
    width(t) and height follows height(t) (default 0.55 x width). Real curvature everywhere, so the metal catches the
    softboxes the way a hand-cast ornament does."""
    height = height or (lambda t: sharp * width(t))
    n = len(pts)
    bm = bmesh.new()
    rings = []
    for i in range(n):
        a = Vector(pts[max(0, i - 1)][:2])
        b = Vector(pts[min(n - 1, i + 1)][:2])
        d = b - a
        d = d.normalized() if d.length > 1e-9 else Vector((1, 0))
        nr = Vector((-d.y, d.x))
        t = i / (n - 1)
        w, h = max(1e-4, width(t)) / 2, max(1e-4, height(t))
        p = Vector(pts[i][:2])
        ring = []
        for j in range(k):
            u = -1 + 2 * j / (k - 1)
            q = p + nr * (u * w)
            ring.append(bm.verts.new((q.x, q.y, z0 + h * math.sqrt(max(0.0, 1 - u * u)) ** 0.8)))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(k - 1):
            bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j + 1]))
    if cap:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # bottom: close with a flat underside so it has no holes
    return _obj(name, bm, m, smooth=70)


def mirror_objects(objs, sx, sy):
    """Mirror the finished piece in local X / Y (applied to the mesh data so normals stay right)."""
    for ob in objs:
        ob.matrix_basis = Matrix.Diagonal((sx, sy, 1, 1)) @ ob.matrix_basis


# ------------------------------------------------------------------------------------------------ theme
LAYERS = {
    "m": dict(hue="#b35cff", crystal="#b35cff", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0),
    "p": dict(hue="#6fc3ff", crystal="#6fc3ff", gold="#f2c35a", patina="#4a2a0c", tarnish=0.0),
    "cp": dict(hue="#39ff14", crystal="#39ff14", gold="#d9ac4c", patina="#1f2410", tarnish=0.55),
}
