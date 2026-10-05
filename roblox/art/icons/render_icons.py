"""Procedural 3D game icons rendered with Blender (bpy), front-facing.

Usage:  python render_icons.py [out_dir] [name ...]
All icons are original models built from primitives/curves/text here. The camera looks
straight at each icon (UI icons must face the player). A post-process adds a
UIStroke-style outline. Output: transparent 512x512 PNGs.
"""
import math
import os
import sys

import bpy
import bmesh

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
ONLY = set(sys.argv[2:])
SIZE = 512
SAMPLES = 96


# ------------------------------------------------------------------ scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = SAMPLES
    s.cycles.use_denoising = True
    s.render.film_transparent = True
    s.render.resolution_x = s.render.resolution_y = SIZE
    s.view_settings.view_transform = "Standard"
    s.view_settings.exposure = -1.3
    w = bpy.data.worlds.new("W")
    s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.55, 0.7, 1)
    bg.inputs[1].default_value = 0.45

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    s.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.9
    cam.location = (0, -8, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    s.camera = cam

    def area(name, loc, energy, size, color=(1, 1, 1)):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        l.data.energy, l.data.size, l.data.color = energy, size, color
        l.location = loc
        s.collection.objects.link(l)
        l.rotation_euler = (-l.location).to_track_quat("-Z", "Y").to_euler()

    area("Key", (-2.5, -5, 3.5), 1400, 3)
    area("Fill", (3, -5, -1), 350, 5, (0.8, 0.88, 1))
    area("RimL", (-4, 2, 1), 900, 2, (1, 0.7, 0.95))
    area("RimR", (4, 2, 2), 900, 2, (0.65, 0.95, 1))
    area("Top", (0, -1, 5), 500, 4)


def mat(name, light, dark=None, rough=0.25, metal=0.0, emit=0.0, coat=0.3):
    """Two-tone stylised material: lighter where the surface faces the camera, darker at edges."""
    dark = dark or tuple(c * 0.45 for c in light)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = (*light, 1)
    mix.inputs[7].default_value = (*dark, 1)
    nt.links.new(lw.outputs["Facing"], mix.inputs[0])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    nt.links.new(mix.outputs[2], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = emit
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.05
    return m


def glow_mat(color=(1, 1, 1), strength=3.0, alpha=1.0):
    m = bpy.data.materials.new("Glow")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Alpha"].default_value = alpha
    return m


def finish(obj, material, bevel=0.08, segs=6, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width, b.segments, b.limit_method = bevel, segs, "ANGLE"
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def add(op, **kw):
    getattr(bpy.ops.mesh, op)(**kw)
    return bpy.context.active_object


def shape(pts, depth, name="Shape", y=0.0):
    """Extrude a 2D polygon drawn in the XZ plane (facing the camera) along Y."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((x, 0, z)) for x, z in pts])
    r = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += depth
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, y - depth / 2, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def text(body, size, depth, loc, material, bevel=0.02):
    bpy.ops.object.text_add(location=loc)
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size
    t.data.extrude = depth
    t.data.bevel_depth = bevel
    t.data.bevel_resolution = 3
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.convert(target="MESH")
    t.data.materials.append(material)
    for p in t.data.polygons:
        p.use_smooth = True
    return t


def gloss(x, z, w, h, y=-1.2, rot=0, strength=2.5, alpha=0.85):
    """White glossy highlight decal floating just in front of the icon."""
    g = add("primitive_uv_sphere_add", radius=1, location=(x, y, z), segments=32, ring_count=16)
    g.scale = (w, 0.02, h)
    g.rotation_euler = (0, math.radians(rot), 0)
    g.data.materials.append(glow_mat((1, 1, 1), strength, alpha))
    return g


def heart(s=1.0, n=64):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * s, z / 17 * s))
    return pts


def star_pts(n, r1, r2, rot=math.pi / 2):
    return [((r1 if i % 2 == 0 else r2) * math.cos(rot + i * math.pi / n),
             (r1 if i % 2 == 0 else r2) * math.sin(rot + i * math.pi / n)) for i in range(n * 2)]


def rounded_rect(w, h, r, n=8):
    pts = []
    for cx, cz, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def puffy(pts, light, dark, name, depth=0.4, bevel=0.14, **kw):
    o = shape(pts, depth, name)
    finish(o, mat(name, light, dark, **kw), bevel=bevel, segs=8)
    return o


# ------------------------------------------------------------------ icons

GOLD = dict(light=(1.0, 0.82, 0.25), dark=(0.75, 0.32, 0.0), rough=0.18, metal=0.75, emit=0.05)


def coin(x, z, r, y):
    gold = mat("Gold", **GOLD)
    c = add("primitive_cylinder_add", radius=r, depth=0.14, vertices=64, location=(x, y, z))
    c.rotation_euler = (math.radians(90), 0, 0)
    finish(c, gold, bevel=0.04)
    rim = add("primitive_torus_add", major_radius=r * 0.78, minor_radius=0.025, location=(x, y - 0.075, z))
    rim.rotation_euler = (math.radians(90), 0, 0)
    finish(rim, gold, bevel=0)
    text("$", r * 1.25, 0.03, (x, y - 0.09, z - r * 0.05), mat("GoldDeep", (1.0, 0.7, 0.1), (0.6, 0.25, 0.0), rough=0.2, metal=0.8), bevel=0.012)


def icon_cash():
    paper = mat("Bill", (0.25, 0.85, 0.25), (0.02, 0.4, 0.08), rough=0.45, coat=0.2)
    border = mat("BillBorder", (0.12, 0.6, 0.2), (0.02, 0.3, 0.08), rough=0.4)
    seal = mat("Seal", (0.85, 1.0, 0.8), (0.4, 0.75, 0.4), rough=0.4)
    ink = mat("Ink", (0.05, 0.42, 0.12), (0.02, 0.25, 0.05), rough=0.5)
    for i, (rot, dx, dz) in enumerate(((14, 0.18, 0.12), (4, 0.05, 0.02), (-8, -0.08, -0.08))):
        y = 0.3 - i * 0.12
        parts = [(rounded_rect(1.9, 1.05, 0.08), 0.05, 0, paper, 0.015),
                 (rounded_rect(1.62, 0.8, 0.06), 0.02, -0.035, border, 0.01),
                 (rounded_rect(1.5, 0.68, 0.05), 0.02, -0.05, paper, 0.008)]
        for j, (pts, d, dy, m, bv) in enumerate(parts):
            o = shape(pts, d, f"Bill{i}_{j}", y=y + dy)
            o.location = (dx, 0, dz)
            o.rotation_euler = (0, math.radians(rot), 0)
            finish(o, m, bevel=bv, segs=3)
    md = add("primitive_cylinder_add", radius=0.3, depth=0.04, vertices=64, location=(-0.08, -0.03, -0.08))
    md.rotation_euler = (math.radians(90), 0, 0)
    finish(md, seal, bevel=0.012)
    text("$", 0.42, 0.03, (-0.08, -0.06, -0.1), ink, bevel=0.008)
    band = shape(rounded_rect(0.26, 1.15, 0.03), 0.12, "Band", y=-0.02)
    band.location = (0.55, 0, -0.06)
    band.rotation_euler = (0, math.radians(-8), 0)
    finish(band, mat("BandM", (1.0, 0.85, 0.3), (0.85, 0.4, 0.0), rough=0.3), bevel=0.02)
    coin(-0.68, -0.5, 0.36, -0.35)
    coin(-0.2, -0.62, 0.3, -0.5)
    gloss(-0.45, 0.32, 0.38, 0.06, rot=-14, alpha=0.5)


def icon_gem(light=(0.2, 0.85, 1.0), dark=(0.0, 0.15, 0.75)):
    m = mat("Gem", light, dark, rough=0.02, emit=0.15, coat=1.0)
    crown = add("primitive_cone_add", vertices=10, radius1=0.95, radius2=0.6, depth=0.38, location=(0, 0, 0.42))
    pav = add("primitive_cone_add", vertices=10, radius1=0.95, radius2=0.0, depth=1.1, location=(0, 0, -0.32))
    pav.rotation_euler = (math.pi, 0, 0)
    for o in (crown, pav):
        o.select_set(True)
    bpy.context.view_layer.objects.active = crown
    bpy.ops.object.join()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    crown.rotation_euler = (math.radians(14), 0, math.radians(18))  # table tipped toward the player
    finish(crown, m, bevel=0.012, segs=2, smooth=False)
    gloss(-0.38, 0.5, 0.22, 0.07, rot=-20, alpha=0.9)
    gloss(-0.55, 0.15, 0.07, 0.18, rot=30, alpha=0.6)
    for (x, z, s) in ((0.78, 0.72, 0.32), (-0.85, -0.45, 0.2)):
        sp = shape(star_pts(4, s, s * 0.22), 0.04, "Spark", y=-1.1)
        sp.location = (x, 0, z)
        finish(sp, glow_mat((1, 1, 1), 5), bevel=0)


def icon_clover():
    leaf = mat("Leaf", (0.2, 0.9, 0.15), (0.0, 0.35, 0.05), rough=0.3)
    vein = mat("Vein", (0.2, 0.75, 0.2), (0.02, 0.35, 0.06), rough=0.4)
    for a in (0, 90, 180, 270):
        r = math.radians(a + 90)
        h = shape(heart(0.62), 0.3, f"Leaf{a}")
        h.location = (0.5 * math.cos(r), 0, 0.5 * math.sin(r) + 0.12)
        h.rotation_euler = (0, -r + math.pi / 2, 0)  # heart tip points to the centre
        finish(h, leaf, bevel=0.12, segs=8)
    st = shape([(-0.06, 0.0), (0.06, 0.0), (0.22, -0.95), (0.1, -0.98)], 0.14, "Stem")
    finish(st, leaf, bevel=0.05)
    gloss(-0.55, 0.62, 0.16, 0.06, rot=-35, alpha=0.8)
    gloss(0.32, 0.72, 0.14, 0.05, rot=25, alpha=0.6)


def icon_bolt():
    pts = [(-0.1, 1.05), (0.62, 1.05), (0.18, 0.22), (0.62, 0.22), (-0.38, -1.1), (-0.06, -0.12), (-0.5, -0.12)]
    puffy(pts, (1.0, 0.85, 0.0), (0.9, 0.3, 0.0), "Bolt")
    gloss(-0.02, 0.72, 0.14, 0.05, rot=-60)


def icon_fastdrop():
    for i, x in enumerate((-0.48, 0.28)):
        pts = [(x - 0.32, 0.8), (x + 0.1, 0.8), (x + 0.58, 0), (x + 0.1, -0.8), (x - 0.32, -0.8), (x + 0.16, 0)]
        puffy(pts, (0.62, 0.18, 1.0), (0.25, 0.0, 0.6), f"Chev{i}", bevel=0.12)
        gloss(x - 0.05, 0.5, 0.12, 0.04, rot=-55, alpha=0.75)


def icon_star():
    puffy(star_pts(5, 1.08, 0.5), (1.0, 0.78, 0.0), (0.9, 0.3, 0.0), "Star", bevel=0.18)
    gloss(-0.28, 0.42, 0.2, 0.07, rot=-30)
    gloss(0.2, 0.62, 0.06, 0.04, rot=0, alpha=0.7)


def icon_tier():
    pts = [(0, 1.05), (0.88, 0.12), (0.36, 0.12), (0.36, -1.0), (-0.36, -1.0), (-0.36, 0.12), (-0.88, 0.12)]
    puffy(pts, (1.0, 0.12, 0.3), (0.55, 0.0, 0.1), "Arrow", bevel=0.16)
    gloss(-0.35, 0.42, 0.18, 0.05, rot=-45)


def icon_storm():
    cloud = mat("Cloud", (0.95, 0.95, 1.0), (0.35, 0.38, 0.7), rough=0.5, coat=0.2)
    for x, z, r in ((-0.55, 0.05, 0.42), (-0.05, 0.38, 0.58), (0.52, 0.1, 0.45), (0.0, -0.05, 0.5), (0.85, -0.05, 0.28), (-0.9, -0.08, 0.26)):
        s = add("primitive_uv_sphere_add", radius=r, location=(x, 0, z), segments=48, ring_count=24)
        s.scale = (1, 0.55, 1)
        finish(s, cloud, bevel=0)
    pts = [(-0.05, -0.2), (0.36, -0.2), (0.14, -0.55), (0.36, -0.55), (-0.15, -1.2), (0.0, -0.72), (-0.22, -0.72)]
    b = shape(pts, 0.22, "MiniBolt", y=-0.4)
    finish(b, mat("Bolt", (1.0, 0.85, 0.0), (0.9, 0.3, 0.0), emit=0.3), bevel=0.06)
    gloss(-0.3, 0.72, 0.22, 0.06, rot=-15, alpha=0.6)


def icon_spawn():
    for loc, light, dark, r in (((-0.48, 0, -0.38), (0.1, 0.65, 1), (0.0, 0.12, 0.6), 0.48),
                                 ((0.48, 0.1, -0.34), (1, 0.2, 0.65), (0.5, 0.0, 0.3), 0.44),
                                 ((0, -0.15, 0.4), (0.55, 1, 0.1), (0.05, 0.4, 0.0), 0.55)):
        s = add("primitive_uv_sphere_add", radius=r, location=loc, segments=64, ring_count=32)
        finish(s, mat("Orb", light, dark, rough=0.05, emit=0.2, coat=1.0), bevel=0)
        gloss(loc[0] - r * 0.32, loc[2] + r * 0.45, r * 0.28, r * 0.12, y=loc[1] - r - 0.05, rot=-25)


def icon_rebirth():
    pts = []
    for i in range(0, 291, 6):
        a = math.radians(i + 70)
        pts.append((0.72 * math.cos(a), 0.72 * math.sin(a)))
    inner = [(0.42 * x / 0.72, 0.42 * z / 0.72) for x, z in reversed(pts)]
    puffy(pts + inner, (1.0, 0.7, 0.0), (0.85, 0.25, 0.0), "Ring", bevel=0.1)
    a = math.radians(70)
    ex, ez = 0.57 * math.cos(a), 0.57 * math.sin(a)
    head = [(ex - 0.05, ez + 0.4), (ex + 0.45, ez - 0.02), (ex - 0.05, ez - 0.42)]
    puffy(head, (1.0, 0.7, 0.0), (0.85, 0.25, 0.0), "Head", bevel=0.1)
    gloss(-0.45, 0.45, 0.16, 0.05, rot=-45)


def icon_gear():
    teeth = 9
    pts = []
    for i in range(teeth * 4):
        a = i * 2 * math.pi / (teeth * 4)
        r = 1.02 if (i % 4) in (1, 2) else 0.8
        pts.append((r * math.cos(a), r * math.sin(a)))
    g = shape(pts, 0.36, "Gear")
    finish(g, mat("Steel", (0.7, 0.74, 0.86), (0.2, 0.22, 0.32), rough=0.25, metal=0.8), bevel=0.06)
    h = add("primitive_cylinder_add", radius=0.34, depth=0.5, vertices=48)
    h.rotation_euler = (math.radians(90), 0, 0)
    finish(h, mat("Hole", (0.18, 0.16, 0.28), (0.05, 0.04, 0.1), rough=0.6), bevel=0.03)
    gloss(-0.5, 0.55, 0.16, 0.05, rot=-40, alpha=0.7)


# ------------------------------------------------------------------ v2 hero icons (layered build)

def fillet(pts, r, n=6):
    """Round every corner of a polygon with an arc of radius r."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % m]
        v1 = (p0[0] - p1[0], p0[1] - p1[1]); v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1 = math.hypot(*v1); l2 = math.hypot(*v2)
        d = min(r, l1 * 0.45, l2 * 0.45)
        a = (p1[0] + v1[0] / l1 * d, p1[1] + v1[1] / l1 * d)
        b = (p1[0] + v2[0] / l2 * d, p1[1] + v2[1] / l2 * d)
        for k in range(n + 1):  # quadratic bezier a -> p1 -> b
            t = k / n
            out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t * t * b[0],
                        (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t * t * b[1]))
    return out


def scale_pts(pts, k, cx=0.0, cz=0.0):
    return [(cx + (x - cx) * k, cz + (z - cz) * k) for x, z in pts]


def layered(pts, base_light, base_dark, face_light, face_dark, name, depth=0.42, inset=0.84,
            cx=0.0, cz=0.0, bevel=0.1, face_bevel=0.06, **kw):
    """Sculpted look: deep coloured body + a lighter, slightly smaller face plate on top."""
    body = shape(pts, depth, name + "Body")
    finish(body, mat(name + "B", base_light, base_dark, **kw), bevel=bevel, segs=8)
    face = shape(scale_pts(pts, inset, cx, cz), 0.08, name + "Face", y=-depth / 2 - 0.02)
    finish(face, mat(name + "F", face_light, face_dark, **kw), bevel=face_bevel, segs=6)
    return body, face


def sparkle(x, z, s, y=-1.2, color=(1, 1, 1)):
    sp = shape(star_pts(4, s, s * 0.2), 0.04, "Spark", y=y)
    sp.location = (x, 0, z)
    finish(sp, glow_mat(color, 5), bevel=0)


def icon_star():
    pts = fillet(star_pts(5, 1.12, 0.52), 0.16)
    layered(pts, (1.0, 0.5, 0.0), (0.7, 0.12, 0.0), (1.0, 0.78, 0.02), (1.0, 0.45, 0.0), "Star",
            depth=0.5, inset=0.78, bevel=0.14, face_bevel=0.1, rough=0.2)
    # centre jewel
    j = add("primitive_uv_sphere_add", radius=0.17, location=(0, -0.42, 0.02), segments=48, ring_count=24)
    j.scale = (1, 0.4, 1)
    finish(j, mat("Jewel", (1.0, 1.0, 0.75), (1.0, 0.75, 0.1), emit=0.4, coat=1.0), bevel=0)
    gloss(-0.22, 0.48, 0.16, 0.05, rot=-55, alpha=0.9)
    gloss(-0.62, 0.12, 0.1, 0.035, rot=-15, alpha=0.6)
    sparkle(0.85, 0.85, 0.22)
    sparkle(-0.95, -0.75, 0.14)


def icon_gear():
    teeth = 8
    pts = []
    for i in range(teeth):
        a0 = i * 2 * math.pi / teeth + math.pi / 8
        for da, r in ((-0.24, 0.74), (-0.15, 1.08), (0.15, 1.08), (0.24, 0.74)):
            a = a0 + da
            pts.append((r * math.cos(a), r * math.sin(a)))
    pts = fillet(pts, 0.12, 8)
    steel = dict(rough=0.25, metal=0.85)
    body, face = layered(pts, (0.5, 0.55, 0.68), (0.1, 0.11, 0.18), (0.82, 0.85, 0.95), (0.38, 0.41, 0.54), "Gear",
                         depth=0.46, inset=0.9, bevel=0.05, face_bevel=0.025, **steel)
    # real see-through centre hole (boolean cut through body + face)
    cutter = add("primitive_cylinder_add", radius=0.3, depth=2.0, vertices=64)
    cutter.rotation_euler = (math.radians(90), 0, 0)
    for o in (body, face):
        b = o.modifiers.new("Hole", "BOOLEAN")
        b.operation = "DIFFERENCE"
        b.object = cutter
        o.modifiers.move(len(o.modifiers) - 1, 0)  # cut before bevel so the hole edge is rounded
    cutter.hide_render = True
    # bevelled collar around the hole
    collar = add("primitive_torus_add", major_radius=0.36, minor_radius=0.07, major_segments=64, minor_segments=16, location=(0, -0.3, 0))
    collar.rotation_euler = (math.radians(90), 0, 0)
    finish(collar, mat("Collar", (0.95, 0.97, 1.0), (0.45, 0.48, 0.6), **steel), bevel=0)
    gloss(-0.42, 0.6, 0.22, 0.05, rot=-38, alpha=0.8)
    gloss(-0.72, 0.1, 0.08, 0.04, rot=-70, alpha=0.6)


def icon_cash():
    paper = dict(rough=0.4, coat=0.25)
    bill_l, bill_d = (0.2, 0.85, 0.3), (0.0, 0.32, 0.08)
    face_l, face_d = (0.55, 1.0, 0.5), (0.1, 0.55, 0.15)
    ink = mat("Ink", (0.02, 0.42, 0.1), (0.0, 0.22, 0.04), rough=0.5)
    # bundle: back bills peeking (fanned), front bill is the hero
    for i, (rot, dx, dz) in enumerate(((16, 0.22, 0.2), (7, 0.1, 0.1))):
        b = shape(fillet(rounded_rect(1.95, 1.1, 0.1), 0.05), 0.12, f"Back{i}", y=0.35 - i * 0.12)
        b.location = (dx, 0, dz)
        b.rotation_euler = (0, math.radians(rot), 0)
        finish(b, mat(f"BB{i}", bill_l, bill_d, **paper), bevel=0.03, segs=4)
    front = rounded_rect(1.95, 1.1, 0.1)
    body, face = layered(front, bill_l, bill_d, face_l, face_d, "Bill", depth=0.16, inset=0.86, bevel=0.035, face_bevel=0.02, **paper)
    for o in (body, face):
        o.rotation_euler = (0, math.radians(-4), 0)
    # corner pips + centre medallion with big $
    for x, z in ((-0.72, 0.36), (0.72, 0.36), (-0.72, -0.36), (0.72, -0.36)):
        c = add("primitive_cylinder_add", radius=0.1, depth=0.04, vertices=32, location=(x, -0.17, z))
        c.rotation_euler = (math.radians(90), 0, 0)
        finish(c, ink, bevel=0.01)
    md = add("primitive_cylinder_add", radius=0.36, depth=0.08, vertices=64, location=(0, -0.18, 0))
    md.rotation_euler = (math.radians(90), 0, 0)
    finish(md, mat("Medal", (0.95, 1.0, 0.9), (0.55, 0.85, 0.5), rough=0.3), bevel=0.025)
    text("$", 0.6, 0.05, (0, -0.24, -0.02), ink, bevel=0.015)
    # gold band
    band = shape(rounded_rect(0.3, 1.24, 0.04), 0.3, "Band", y=-0.05)
    band.location = (0.62, 0, 0)
    finish(band, mat("BandM", (1.0, 0.8, 0.15), (0.8, 0.3, 0.0), rough=0.25, metal=0.4), bevel=0.04)
    # coin stack in front
    gold = mat("Gold", **GOLD)
    for k, (x, z) in enumerate(((-0.5, -0.72), (-0.5, -0.6), (-0.5, -0.48))):
        c = add("primitive_cylinder_add", radius=0.36, depth=0.12, vertices=64, location=(x, -0.55, z))
        finish(c, gold, bevel=0.03)
    coin(0.05, -0.64, 0.36, -0.75)
    gloss(-0.5, 0.36, 0.34, 0.05, y=-0.3, rot=-10, alpha=0.55)
    sparkle(0.95, 0.75, 0.18)


def icon_storm():
    cloud_l, cloud_d = (0.62, 0.66, 0.95), (0.16, 0.16, 0.42)
    top_l, top_d = (0.95, 0.96, 1.0), (0.55, 0.58, 0.85)
    # silhouette from overlapping puffs (union via 2D) -> layered cloud with flat-ish bottom
    puffs = ((-0.62, 0.0, 0.42), (-0.15, 0.32, 0.56), (0.42, 0.18, 0.5), (0.88, -0.05, 0.32), (0.1, -0.1, 0.48), (-0.95, -0.12, 0.28))
    for i, (x, z, r) in enumerate(puffs):
        s = add("primitive_uv_sphere_add", radius=r, location=(x, 0.1, z), segments=48, ring_count=24)
        s.scale = (1, 0.5, 1)
        finish(s, mat(f"CloudB{i}", cloud_l, cloud_d, rough=0.55, coat=0.1), bevel=0)
        t = add("primitive_uv_sphere_add", radius=r * 0.8, location=(x - r * 0.06, -0.12, z + r * 0.12), segments=48, ring_count=24)
        t.scale = (1, 0.45, 1)
        finish(t, mat(f"CloudT{i}", top_l, top_d, rough=0.5, coat=0.15), bevel=0)
    # rain drops
    for x, z in ((-0.55, -0.72), (0.55, -0.75), (-0.2, -0.95)):
        d = add("primitive_uv_sphere_add", radius=0.08, location=(x, -0.2, z), segments=32, ring_count=16)
        d.scale = (0.8, 0.6, 1.4)
        finish(d, mat("Drop", (0.3, 0.8, 1.0), (0.0, 0.3, 0.8), emit=0.3, coat=1.0), bevel=0)
    # hero bolt in front
    bolt = fillet([(-0.02, -0.05), (0.42, -0.05), (0.18, -0.48), (0.46, -0.48), (-0.18, -1.3), (-0.02, -0.68), (-0.3, -0.68)], 0.035, 3)
    layered(bolt, (1.0, 0.6, 0.0), (0.8, 0.2, 0.0), (1.0, 0.95, 0.3), (1.0, 0.65, 0.0), "Bolt",
            depth=0.24, inset=0.82, cx=0.08, cz=-0.62, bevel=0.05, face_bevel=0.03, emit=0.4)
    for o in bpy.context.scene.objects:
        if o.name.startswith("Bolt"):
            o.location.y -= 0.55
    gloss(-0.35, 0.68, 0.24, 0.06, rot=-12, alpha=0.7)
    sparkle(0.6, -0.25, 0.12, color=(1, 0.95, 0.5))


def icon_clover():
    body_l, body_d = (0.04, 0.55, 0.1), (0.0, 0.2, 0.03)
    face_l, face_d = (0.22, 0.92, 0.12), (0.02, 0.45, 0.06)
    for a in (0, 90, 180, 270):
        r = math.radians(a + 90)
        pts = heart(0.66)
        b, f = layered(pts, body_l, body_d, face_l, face_d, f"Leaf{a}", depth=0.34, inset=0.8,
                       cz=0.05, bevel=0.12, face_bevel=0.08, rough=0.28)
        for o in (b, f):
            o.location = (0.47 * math.cos(r), o.location.y, 0.47 * math.sin(r) + 0.15)
            o.rotation_euler = (0, -r + math.pi / 2, 0)
        # centre crease on each leaf
        c = shape(fillet([(-0.025, 0.0), (0.025, 0.0), (0.02, 0.42), (-0.02, 0.42)], 0.01, 2), 0.04, f"Crease{a}", y=-0.24)
        c.location = (0.1 * math.cos(r), 0, 0.1 * math.sin(r) + 0.15)
        c.rotation_euler = (0, -r + math.pi / 2, 0)
        finish(c, mat("Crease", (0.05, 0.55, 0.1), (0.0, 0.3, 0.05)), bevel=0.01)
    # curved stem
    stem = []
    for k in range(13):
        t = k / 12
        stem.append((0.05 + 0.35 * t * t, 0.1 - 1.15 * t))
    stem_pts = [(x - 0.06, z) for x, z in stem] + [(x + 0.06, z) for x, z in reversed(stem)]
    st = shape(stem_pts, 0.16, "Stem", y=0.08)
    finish(st, mat("Stem", body_l, body_d), bevel=0.05)
    # golden lucky centre
    g = add("primitive_uv_sphere_add", radius=0.16, location=(0, -0.3, 0.15), segments=48, ring_count=24)
    g.scale = (1, 0.5, 1)
    finish(g, mat("Lucky", (1.0, 0.9, 0.3), (0.9, 0.45, 0.0), metal=0.6, emit=0.2, coat=1.0), bevel=0)
    gloss(-0.68, 0.7, 0.16, 0.05, rot=-40, alpha=0.85)
    gloss(0.32, 0.86, 0.12, 0.04, rot=25, alpha=0.6)
    sparkle(0.95, 0.95, 0.2, color=(1, 0.95, 0.5))
    sparkle(-0.95, -0.6, 0.13)


ICONS = {
    "cash": icon_cash, "gem": icon_gem, "clover": icon_clover, "bolt": icon_bolt,
    "fastdrop": icon_fastdrop, "star": icon_star, "tier": icon_tier, "storm": icon_storm,
    "spawn": icon_spawn, "rebirth": icon_rebirth, "gear": icon_gear,
}


def add_outline(path, px=12, shadow=8):
    """UIStroke-style outline: dilate alpha, fill near-black, plus a hard drop shadow."""
    from PIL import Image, ImageFilter
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    stroke = a.filter(ImageFilter.MaxFilter(px * 2 + 1)).filter(ImageFilter.GaussianBlur(1))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh.putalpha(stroke.point(lambda v: int(v * 0.5)))
    out.alpha_composite(sh, (0, shadow))
    black = Image.new("RGBA", im.size, (10, 6, 20, 255))
    black.putalpha(stroke)
    out.alpha_composite(black)
    out.alpha_composite(im)
    out.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        if ONLY and name not in ONLY:
            continue
        reset()
        fn()
        bpy.context.scene.render.filepath = os.path.join(OUT, f"icon_{name}.png")
        bpy.ops.render.render(write_still=True)
        add_outline(bpy.context.scene.render.filepath)
        print("rendered", name)
