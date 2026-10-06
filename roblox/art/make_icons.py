# Renders the game's UI icons in Blender (Cycles, CPU) to transparent PNGs.
# Style matches the existing icon set: glossy clear-coated toy plastic, rounded bevels,
# soft studio light, a few white sparkle stars.
#   blender -b -P make_icons.py -- <outdir> [name ...]
import bpy, bmesh, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/icons"
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)
RES = 256

def hexc(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (a,)

# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "Medium High Contrast"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.86, 0.95, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = w
    # camera: slight 3/4 view from above, like the reference icons
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 2.6
    co = bpy.data.objects.new("cam", cam)
    co.location = (2.2, -6.5, 3.0)
    sc.collection.objects.link(co)
    look_at(co, Vector((0, 0, 0)))
    sc.camera = co
    def area(name, loc, energy, size, color=(1, 1, 1)):
        l = bpy.data.lights.new(name, "AREA")
        l.energy, l.size, l.color = energy, size, color
        o = bpy.data.objects.new(name, l)
        o.location = loc
        sc.collection.objects.link(o)
        look_at(o, Vector((0, 0, 0)))
    area("key", (-3, -4, 5), 900, 4)
    area("fill", (5, -3, 1), 300, 5, (0.9, 0.95, 1))
    area("rim", (1, 5, 4), 700, 3)
    area("top", (0, 0, 7), 250, 6)

def look_at(o, target):
    d = target - o.location
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o

# ---------------------------------------------------------------- materials

def toy(color, rough=0.28, coat=0.7, metal=0.0, emit=0.0, sss=0.0, transmission=0.0):
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.08
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
        b.inputs["IOR"].default_value = 1.45
    if sss:
        b.inputs["Subsurface Weight"].default_value = sss
        b.inputs["Subsurface Radius"].default_value = (0.3, 0.3, 0.3)
    if emit:
        b.inputs["Emission Color"].default_value = hexc(color)
        b.inputs["Emission Strength"].default_value = emit
    return m

def setmat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o

def smooth(o, sub=2):
    for p in o.data.polygons:
        p.use_smooth = True
    if sub:
        s = o.modifiers.new("sub", "SUBSURF")
        s.levels = s.render_levels = sub
    return o

# ---------------------------------------------------------------- primitives

def rbox(size, bevel=0.18, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    bv = o.modifiers.new("bv", "BEVEL")
    bv.width, bv.segments, bv.limit_method = bevel, 6, "NONE"
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.shade_smooth() if hasattr(o.data, "shade_smooth") else None
    if m:
        setmat(o, m)
    return o

def sphere(r, loc=(0, 0, 0), m=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24)
    o = bpy.context.object
    o.scale = scale
    for p in o.data.polygons:
        p.use_smooth = True
    if m:
        setmat(o, m)
    return o

def cyl(r, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, verts=64, bevel=0.06):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    if bevel:
        bv = o.modifiers.new("bv", "BEVEL")
        bv.width, bv.segments, bv.limit_method = bevel, 5, "ANGLE"
    for p in o.data.polygons:
        p.use_smooth = True
    if m:
        setmat(o, m)
    return o

def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=64, minor_segments=24)
    o = bpy.context.object
    for p in o.data.polygons:
        p.use_smooth = True
    if m:
        setmat(o, m)
    return o

def slab(pts, depth, bevel=0.08, loc=(0, 0, 0), rot=(math.pi / 2, 0, 0), m=None):
    """extruded 2D polygon (x,y points), standing up facing the camera"""
    me = bpy.data.meshes.new("slab")
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0)) for x, y in pts]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += depth
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -depth / 2))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    o = link(bpy.data.objects.new("slab", me))
    o.location, o.rotation_euler = loc, rot
    bv = o.modifiers.new("bv", "BEVEL")
    bv.width, bv.segments, bv.limit_method = bevel, 6, "ANGLE"
    for p in me.polygons:
        p.use_smooth = True
    if m:
        setmat(o, m)
    return o

def tube(polylines, radius, m, loc=(0, 0, 0), rot=(math.pi / 2, 0, 0), scale=1.0):
    """round tubes along 2D polylines (used for rune glyphs, check marks)"""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    cu.use_fill_caps = True
    for line in polylines:
        sp = cu.splines.new("POLY")
        sp.points.add(len(line) - 1)
        for i, (x, y) in enumerate(line):
            sp.points[i].co = (x * scale, y * scale, 0, 1)
    o = link(bpy.data.objects.new("tube", cu))
    o.location, o.rotation_euler = loc, rot
    o.data.materials.append(m)
    # round the joints: convert, add caps via small spheres at every vertex
    for line in polylines:
        for x, y in line:
            s = sphere(radius, m=m)
            s.parent = o
            s.location = (x * scale, y * scale, 0)
    return o

def sparkle(loc, size=0.16):
    pts = []
    for k in range(8):
        a = k * math.pi / 4
        rr = size if k % 2 == 0 else size * 0.22
        pts.append((math.cos(a + math.pi / 2) * rr, math.sin(a + math.pi / 2) * rr))
    return slab(pts, 0.02, bevel=0.005, loc=loc, m=toy("#ffffff", emit=3.0, coat=0))

def star_pts(R, r, n=5, rot=math.pi / 2):
    return [((R if k % 2 == 0 else r) * math.cos(rot + k * math.pi / n), (R if k % 2 == 0 else r) * math.sin(rot + k * math.pi / n)) for k in range(2 * n)]

# ---------------------------------------------------------------- icons

RUNE_GLYPHS = [  # 24x24 grid strokes (same glyphs as the preview)
    [[(15.5, 4), (8.5, 12), (15.5, 20)]],
    [[(12, 3.5), (18, 9.5), (12, 15.5), (6, 9.5), (12, 3.5)], [(8.5, 13), (5, 20.5)], [(15.5, 13), (19, 20.5)]],
    [[(8.5, 3.5), (8.5, 20.5)], [(8.5, 3.5), (15.5, 8), (8.5, 12.5)]],
    [[(9, 3.5), (9, 20.5)], [(9, 3.5), (16, 10)]],
    [[(8.5, 3.5), (8.5, 20.5)], [(8.5, 7.5), (15.5, 12), (8.5, 16.5)]],
    [[(6.5, 3.5), (6.5, 20.5)], [(17.5, 3.5), (17.5, 20.5)], [(6.5, 4), (17.5, 12)], [(17.5, 4), (6.5, 12)]],
    [[(5, 5), (5, 19), (19, 5), (19, 19), (5, 5)]],
    [[(12, 4), (18, 12), (12, 20), (6, 12), (12, 4)], [(12, 4), (12, 20)]],
    [[(12, 3.5), (12, 20.5)], [(12, 11.5), (5.5, 4.5)], [(12, 11.5), (18.5, 4.5)]],
    [[(10.5, 3.5), (5.5, 8.5), (10.5, 13.5)], [(13.5, 10.5), (18.5, 15.5), (13.5, 20.5)]],
]
RUNE_COLORS = ["#ffd64a", "#c8c4d2", "#7cffc8", "#46a0ff", "#ff6a1f", "#5cf2ff", "#ff5caa", "#fff0a0", "#ffc43c", "#e3a6ff"]

def lighten(h, f):
    c = [int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02x%02x%02x" % tuple(int(v + (255 - v) * f) for v in c)

def darken(h, f):
    c = [int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02x%02x%02x" % tuple(int(v * (1 - f)) for v in c)

def rune(i):
    col = RUNE_COLORS[i]
    # rounded stone tablet, slightly tilted back
    rbox((1.75, 0.5, 1.9), bevel=0.32, m=toy(darken(col, 0.45), rough=0.35, coat=0.3))
    rbox((1.45, 0.1, 1.6), bevel=0.12, loc=(0, -0.22, 0), m=toy(darken(col, 0.66), rough=0.5, coat=0.15))
    # raised glowing glyph on the front face
    lines = [[((x - 12) / 12 * 0.62, (12 - y) / 12 * 0.62) for x, y in ln] for ln in RUNE_GLYPHS[i]]
    tube(lines, 0.115, toy(col, rough=0.18, emit=1.6, coat=0.9), loc=(0, -0.3, 0))
    sparkle((0.85, -0.3, 0.95), 0.2)
    sparkle((-0.95, -0.3, -0.75), 0.12)

def stack():  # rune bulk (red)
    for k, (dx, z) in enumerate([(0, -0.55), (0.08, 0), (-0.05, 0.55)]):
        rbox((1.8, 1.25, 0.42), bevel=0.16, loc=(dx, 0, z), rot=(0, 0, 0.12 * (k - 1)), m=toy(["#d92a2a", "#ff4848", "#ff7a6a"][k]))
    sparkle((0.95, -0.4, 0.9))

def bolt(color="#3aa8ff"):
    pts = [(0.15, 1.15), (-0.6, -0.05), (-0.05, -0.05), (-0.3, -1.15), (0.6, 0.2), (0.05, 0.2), (0.35, 1.15)]
    slab(pts, 0.35, bevel=0.1, m=toy(color))
    sparkle((0.8, -0.2, 0.8)); sparkle((-0.8, -0.2, -0.5), 0.1)

def stopwatch(color="#c47dff"):
    cyl(0.95, 0.35, rot=(math.pi / 2, 0, 0), m=toy(color))
    cyl(0.75, 0.1, loc=(0, -0.2, 0), rot=(math.pi / 2, 0, 0), m=toy("#ffffff", rough=0.3), bevel=0.03)
    rbox((0.12, 0.08, 0.55), bevel=0.04, loc=(0, -0.27, 0.22), m=toy("#2a1a3d"))
    rbox((0.12, 0.08, 0.42), bevel=0.04, loc=(0.16, -0.27, -0.08), rot=(0, 1.0, 0), m=toy("#2a1a3d"))
    cyl(0.16, 0.25, loc=(0, 0, 1.1), m=toy("#ff5050"))
    cyl(0.1, 0.18, loc=(0.75, 0, 0.75), rot=(0, 0.8, 0), m=toy("#ff5050"))
    sparkle((-0.95, -0.3, 0.9))

def gift(color="#ffd84a"):
    rbox((1.6, 1.4, 1.2), bevel=0.12, loc=(0, 0, -0.25), m=toy(color))
    rbox((1.8, 1.55, 0.38), bevel=0.12, loc=(0, 0, 0.45), m=toy(lighten(color, 0.2)))
    rib = toy("#ff4fd8")
    rbox((0.32, 1.6, 1.25), bevel=0.06, loc=(0, 0, -0.25), m=rib)
    rbox((0.34, 1.6, 0.42), bevel=0.06, loc=(0, 0, 0.45), m=rib)
    torus(0.32, 0.12, loc=(-0.3, 0, 0.85), rot=(math.pi / 2, 0, 0.5), m=rib)
    torus(0.32, 0.12, loc=(0.3, 0, 0.85), rot=(math.pi / 2, 0, -0.5), m=rib)
    sparkle((1.0, -0.4, 1.0))

def magnifier(color="#ff8a3d"):
    torus(0.62, 0.15, loc=(-0.2, 0, 0.25), rot=(math.pi / 2, 0, 0), m=toy(color))
    cyl(0.6, 0.06, loc=(-0.2, 0, 0.25), rot=(math.pi / 2, 0, 0), m=toy("#bff6ff", rough=0.05, transmission=0.85, coat=1), bevel=0.02)
    cyl(0.17, 0.85, loc=(0.55, 0, -0.5), rot=(0, 2.36, 0), m=toy(darken(color, 0.25)))
    sparkle((-0.45, -0.3, 0.5), 0.14)

def players():
    for x, c, s in [(0.45, "#b45cff", 0.9), (-0.35, "#5cf2ff", 1.0)]:
        sphere(0.36 * s, loc=(x, 0.1 if s < 1 else -0.1, 0.45 * s), m=toy(c))
        sphere(0.55 * s, loc=(x, 0.1 if s < 1 else -0.1, -0.5 * s), scale=(1, 0.8, 0.85), m=toy(c))

def orb(color="#4cf05a"):
    sphere(0.95, m=toy(color, rough=0.15, coat=1))
    sparkle((0.85, -0.4, 0.85))

def ghost():
    g = toy("#e8ecff", sss=0.3)
    sphere(0.8, loc=(0, 0, 0.25), m=g)
    cyl(0.8, 0.9, loc=(0, 0, -0.25), m=g, bevel=0)
    for k in range(4):
        sphere(0.23, loc=(-0.6 + k * 0.4, 0, -0.7), m=g)
    for x in (-0.28, 0.28):
        sphere(0.12, loc=(x, -0.72, 0.3), scale=(1, 0.6, 1.4), m=toy("#141420"))

def camera_icon():
    rbox((1.9, 0.9, 1.3), bevel=0.2, m=toy("#3aa8ff"))
    rbox((0.7, 0.6, 0.3), bevel=0.08, loc=(-0.3, 0, 0.75), m=toy("#3aa8ff"))
    cyl(0.48, 0.3, loc=(0, -0.55, -0.02), rot=(math.pi / 2, 0, 0), m=toy("#1c1e2a"))
    cyl(0.3, 0.32, loc=(0, -0.6, -0.02), rot=(math.pi / 2, 0, 0), m=toy("#bff6ff", rough=0.05, coat=1))
    sphere(0.12, loc=(0.65, -0.45, 0.42), m=toy("#ff5050", emit=1))

def lock():
    torus(0.48, 0.13, loc=(0, 0, 0.35), rot=(math.pi / 2, 0, 0), m=toy("#c8ccd6", metal=0.6, rough=0.25))
    rbox((1.4, 0.7, 1.1), bevel=0.18, loc=(0, 0, -0.4), m=toy("#ffc63a"))
    cyl(0.14, 0.2, loc=(0, -0.38, -0.35), rot=(math.pi / 2, 0, 0), m=toy("#3d2a00"))

def check():
    tube([[(-0.75, 0.0), (-0.2, -0.55), (0.8, 0.65)]], 0.22, toy("#4cf05a"))
    sparkle((0.9, -0.3, -0.4), 0.14)

def coin():
    cyl(0.95, 0.28, rot=(math.pi / 2, 0, 0), m=toy("#ffc63a", metal=0.35, rough=0.22))
    torus(0.8, 0.05, loc=(0, -0.16, 0), rot=(math.pi / 2, 0, 0), m=toy("#e09a10", metal=0.4))
    bpy.ops.object.text_add(location=(0, -0.17, 0), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.object
    t.data.body = "$"
    t.data.align_x, t.data.align_y = "CENTER", "CENTER"
    t.data.size = 1.1
    t.data.extrude = 0.05
    t.data.bevel_depth = 0.02
    setmat(t, toy("#fff1a8", metal=0.3))
    sparkle((0.9, -0.3, 0.85))

def robux():
    cyl(0.95, 0.3, rot=(math.pi / 2, 0, 0), m=toy("#f2fff5"), verts=6, bevel=0.1)
    cyl(0.6, 0.34, rot=(math.pi / 2, 0, 0), m=toy("#1db52c"), verts=6, bevel=0.06)
    cyl(0.32, 0.38, rot=(math.pi / 2, 0, 0), m=toy("#f2fff5"), verts=6, bevel=0.04)

def anvil():
    gm = toy("#9aa3b5", metal=0.7, rough=0.3)
    rbox((1.9, 0.8, 0.45), bevel=0.1, loc=(0.05, 0, 0.35), m=gm)
    slab([(0.9, 0.12), (1.45, 0.12), (0.9, -0.12)], 0.6, bevel=0.06, loc=(0, 0, 0.35), m=gm)
    rbox((0.7, 0.6, 0.6), bevel=0.08, loc=(0, 0, -0.15), m=gm)
    rbox((1.3, 0.8, 0.3), bevel=0.08, loc=(0, 0, -0.6), m=gm)
    for x, z in [(0.6, 0.9), (0.3, 1.1), (0.9, 1.05)]:
        sphere(0.07, loc=(x, -0.2, z), m=toy("#ffb13a", emit=4))

def arrow(color="#ffffff", flip=False):
    pts = [(-0.9, 0.35), (0.1, 0.35), (0.1, 0.85), (0.95, 0), (0.1, -0.85), (0.1, -0.35), (-0.9, -0.35)]
    if flip:
        pts = [(-x, y) for x, y in pts]
    slab(pts, 0.4, bevel=0.12, m=toy(color))

def star(color="#ffd84a"):
    slab(star_pts(1.05, 0.48), 0.45, bevel=0.14, m=toy(color))
    sparkle((0.95, -0.3, 0.9)); sparkle((-0.95, -0.3, -0.7), 0.1)

def cash():
    for k in range(3):
        rbox((1.8, 0.08, 1.0), bevel=0.04, loc=(-0.15 + k * 0.08, 0.1 - k * 0.12, 0.25 - k * 0.12), rot=(0, 0.12, 0), m=toy(["#5fbf63", "#7fd97f", "#9ff09a"][k]))
    coin_m = toy("#ffc63a", metal=0.35, rough=0.22)
    cyl(0.42, 0.14, loc=(0.55, -0.45, -0.55), rot=(math.pi / 2, 0, 0), m=coin_m)

ICONS = {
    **{"rune%d" % i: (lambda i=i: rune(i)) for i in range(10)},
    "stack": stack, "bolt_blue": bolt, "stopwatch": stopwatch, "gift": gift, "magnifier": magnifier,
    "players": players, "orb": orb, "ghost": ghost, "camera": camera_icon, "lock": lock, "check": check,
    "coin": coin, "robux": robux, "anvil": anvil, "arrow_r": arrow, "arrow_l": (lambda: arrow(flip=True)),
    "star_gold": star, "star_yellow": (lambda: star("#ffd84a")), "clover_rune": None,
}

for name, fn in ICONS.items():
    if fn is None or (ONLY and name not in ONLY):
        continue
    reset()
    fn()
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name, flush=True)
