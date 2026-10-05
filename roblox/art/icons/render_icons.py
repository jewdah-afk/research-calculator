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
