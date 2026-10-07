"""One builder per icon. Each builds into the active collection, fits ~2 units, faces -Y (the camera).
X = right, Z = up, -Y = toward camera. Keep silhouettes chunky; small details get hull=0.02."""
import bpy, math, random
from lib import *
R = math.radians
ICONS = {}
def icon(f): ICONS[f.__name__] = f; return f

# ---------------------------------------------------------------- popcorn family
def _kernel(x, y, z, r, seed):
    rnd = random.Random(seed)
    balls = [(x, y, z - r * 0.15, r * 0.95)]
    for i in range(3):
        a = R(i * 120 + rnd.uniform(-30, 30))
        balls.append((x + math.cos(a) * r * 0.5, y - abs(math.sin(a)) * r * 0.3, z + r * 0.3 + math.sin(a) * r * 0.2, r * rnd.uniform(0.62, 0.72)))
    return blobs(balls, res=0.02, thresh=0.45)

def _bucket(kcol, seed, rimcol='#fff4ea', bcol='#f23b46'):
    b = cyl((0, 0, -0.35), r=0.62, r2=0.85, depth=1.3, verts=64)
    finish(b, cel('bucket' + bcol, bcol, stripe='#fff4ea', stripe_freq=9.5, stripe_axis=0), bevel=0.03)
    finish(torus((0, 0, 0.3), R=0.86, r=0.075), cel('rim_' + rimcol, rimcol))
    km = cel('kernel_' + kcol, kcol)
    pts = [(0, 0, 0.72, 0.36), (-0.48, -0.08, 0.52, 0.3), (0.48, -0.08, 0.55, 0.3), (-0.2, -0.38, 0.48, 0.28),
           (0.24, -0.38, 0.5, 0.28), (-0.68, 0.15, 0.38, 0.24), (0.68, 0.15, 0.4, 0.24), (0, 0.25, 0.6, 0.3),
           (-0.28, 0.0, 0.98, 0.26), (0.3, 0.02, 0.95, 0.26), (0.02, -0.22, 1.15, 0.24)]
    for i, p in enumerate(pts):
        finish(_kernel(*p, seed * 100 + i), km, hull=0.022)

@icon
def popcorn(): _bucket('#fff6dc', 1)

@icon
def golden():
    _bucket('#ffc93a', 2, rimcol='#ffe27a', bcol='#f2a81c')
    for (x, z, r) in ((-0.95, 0.95, 0.16), (0.98, 0.7, 0.12)):
        pts = [(math.cos(R(90 + i * 45)) * (r if i % 2 == 0 else r * 0.3), math.sin(R(90 + i * 45)) * (r if i % 2 == 0 else r * 0.3), 'v') for i in range(8)]
        finish(puff(pts, depth=0.01, bevel=0.02, loc=(x, -0.6, z)), cel('sparkle', '#fff6c2'), hull=0.015)

@icon
def plume():
    # vane with notched barb edges, quill tucked inside; tilted like the currency icon
    left = [(-0.05, -1.0), (-0.24, -0.7), (-0.3, -0.35), (-0.2, -0.3, 'v'), (-0.34, -0.05), (-0.33, 0.35), (-0.22, 0.38, 'v'), (-0.3, 0.6), (-0.18, 0.95), (0, 1.15, 'v')]
    right = [(0.2, 0.9), (0.3, 0.55), (0.22, 0.5, 'v'), (0.33, 0.2), (0.31, -0.2), (0.2, -0.22, 'v'), (0.25, -0.55), (0.06, -1.0)]
    v = puff(left + right, depth=0.03, bevel=0.08); finish(v, cel('plume', '#4fb4ff'))
    finish(puff([(-0.04, 0.95, 'v'), (0.04, 0.95, 'v'), (0.04, -1.35, 'v'), (-0.04, -1.35, 'v')], depth=0.02, bevel=0.03, loc=(0, -0.13, 0), smooth_pts=False),
           cel('quill', '#eef6ff'), hull=0.02)
    finish(puff([(0, 0.45, 'v'), (-0.12, 0.1), (0, -0.3, 'v'), (0.12, 0.1)], depth=0.01, bevel=0.03, loc=(-0.13, -0.12, 0.3)), cel('plume_hi', '#a8dcff'), outline=False)
    group(rot=(0, R(-30), 0))

@icon
def wing():
    # classic layered cartoon wing pointing up-right: long primaries, scalloped coverts, plump shoulder
    def layer(pts, y, col, name):
        finish(puff(pts, depth=0.05, bevel=0.1, loc=(0, y, 0)), cel(name, col))
    layer([(-0.9, -0.55), (-0.5, -0.2), (0.2, 0.5), (1.05, 1.05, 'v'), (0.75, 0.55), (1.0, 0.45, 'v'), (0.62, 0.15), (0.85, 0.0, 'v'), (0.4, -0.25), (0.55, -0.45, 'v'), (0.0, -0.6), (-0.5, -0.8)], 0.0, '#3c9cf0', 'wing_p')
    layer([(-0.95, -0.5), (-0.4, -0.05), (0.2, 0.35), (0.65, 0.55, 'v'), (0.38, 0.2), (0.55, 0.05, 'v'), (0.15, -0.15), (0.25, -0.38, 'v'), (-0.2, -0.45), (-0.6, -0.72)], -0.12, '#7cc8ff', 'wing_s')
    layer([(-1.0, -0.45), (-0.6, 0.05), (-0.1, 0.25), (0.15, 0.05, 'v'), (-0.05, -0.12), (0.0, -0.3, 'v'), (-0.35, -0.38), (-0.55, -0.62)], -0.24, '#d6efff', 'wing_c')

@icon
def magnet():
    t = torus((0, 0, 0.15), R=0.62, r=0.26, rot=(R(90), 0, 0))
    bpy.ops.object.mode_set(mode='EDIT'); import bmesh
    bm = bmesh.from_edit_mesh(t.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.0001 and False] + [v for v in bm.verts if (t.matrix_world @ v.co).z < 0.149], context='VERTS')
    bmesh.update_edit_mesh(t.data); bpy.ops.object.mode_set(mode='OBJECT')
    finish(t, cel('magnet', '#f0313f'))
    for x in (-0.62, 0.62):
        finish(cyl((x, 0, -0.18), r=0.26, depth=0.66, rot=(0, 0, 0)), cel('magnet', '#f0313f'), bevel=0.02)
        finish(cyl((x, 0, -0.66), r=0.27, depth=0.32), cel('magnet_tip', '#e9eef7'), bevel=0.04)

@icon
def clock():
    finish(cyl((0, 0, 0), r=0.82, depth=0.42, rot=(R(90), 0, 0)), cel('clock_body', '#ff4a4a'), bevel=0.08)
    finish(cyl((0, -0.2, 0), r=0.64, depth=0.08, rot=(R(90), 0, 0)), cel('clock_face', '#fff8ec'), bevel=0.02)
    for a in range(12):
        x, z = math.sin(R(a * 30)) * 0.52, math.cos(R(a * 30)) * 0.52
        finish(sphere((x, -0.26, z), (0.035, 0.02, 0.035), 12, 8), cel('tick', '#3b3550'), outline=False)
    finish(cube((0, -0.28, 0.17), (0.045, 0.03, 0.22)), cel('hand', '#2b2638'), outline=False, bevel=0.02)
    h = cube((0.13, -0.29, -0.06), (0.04, 0.03, 0.16), rot=(0, R(-60), 0)); finish(h, cel('hand', '#2b2638'), outline=False, bevel=0.02)
    finish(sphere((0, -0.3, 0), (0.07, 0.04, 0.07), 16, 8), cel('pin', '#ffcf3a'), outline=False)
    for s in (-1, 1):
        finish(sphere((0.55 * s, 0, 0.78), (0.32, 0.28, 0.24)), cel('bell', '#ffcf3a'))
        finish(cyl((0.6 * s, 0, -0.85), r=0.08, depth=0.32, rot=(0, R(-25 * s), 0)), cel('clock_body', '#ff4a4a'))
    finish(cube((0, 0, 0.95), (0.08, 0.06, 0.12)), cel('bell', '#ffcf3a'), bevel=0.03)

@icon
def seed():
    s = sphere((0, 0, 0), (0.42, 0.24, 0.85))
    td = s.modifiers.new('taper', 'SIMPLE_DEFORM'); td.deform_method = 'TAPER'; td.factor = -0.55; td.deform_axis = 'Z'
    s.rotation_euler = (0, R(-18), 0)
    finish(s, cel('seed', '#565b6e', stripe='#e4e7f2', stripe_freq=24, stripe_axis=0, stripe_w=0.82, rim=0.35))

@icon
def index():
    finish(cube((0.04, 0.05, 0), (0.84, 0.18, 0.98)), cel('pages', '#fff6e2', stripe='#e2d3b6', stripe_freq=110, stripe_axis=1, stripe_w=0.4), bevel=0.04)
    finish(cube((0, -0.14, 0), (0.92, 0.06, 1.06)), cel('cover', '#3f7ff0'), bevel=0.05)
    finish(cube((0, 0.24, 0), (0.92, 0.06, 1.06)), cel('cover', '#3f7ff0'), bevel=0.05)
    finish(cube((-0.88, 0.05, 0), (0.08, 0.24, 1.06)), cel('cover_spine', '#2e5fc4'), bevel=0.05)
    finish(cube((0.05, -0.21, 0.35), (0.48, 0.02, 0.26)), cel('label', '#bfe0ff'), bevel=0.04, hull=0.02)
    finish(cube((0.05, -0.215, -0.35), (0.3, 0.015, 0.035)), cel('label', '#bfe0ff'), hull=0.015)
    finish(cube((0.55, -0.02, -1.12), (0.09, 0.02, 0.2)), cel('ribbon', '#ffcf3a'), bevel=0.02, hull=0.02)
    group(rot=(R(8), 0, R(-28)))

@icon
def crown():
    band = cyl((0, 0, -0.35), r=0.95, depth=0.42, verts=64); finish(band, cel('gold', '#ffc93a'), bevel=0.05)
    for a, h in ((-62, 0.62), (-31, 0.82), (0, 1.05), (31, 0.82), (62, 0.62)):
        x, y = math.sin(R(a)) * 0.88, -math.cos(R(a)) * 0.88
        sp = cone((x, y, -0.2 + h / 2), r=0.28, depth=h + 0.1, verts=32); sp.rotation_euler = (0, R(a * 0.25), 0)
        finish(sp, cel('gold', '#ffc93a'))
        finish(ico((x + math.sin(R(a * 0.25)) * h * 0.5, y, -0.15 + h), r=0.11, sub=3), cel('pearl', '#fff6ea'), hull=0.02)
    for x, c in ((-0.55, '#3cd0ff'), (0, '#ff3d7a'), (0.55, '#3cd0ff')):
        finish(sphere((x, -0.86, -0.35), (0.15 if x == 0 else 0.12, 0.08, 0.13)), cel('gem' + c, c), hull=0.02)

# ---------------------------------------------------------------- mine / crow
def _ore(cry):
    rock = ico((0, 0.1, -0.45), r=0.95, sub=3); rock.scale = (1.15, 0.8, 0.55)
    lump(rock, strength=0.3, scale=1.3, seed=3); finish(rock, cel('rock', '#a0a6bd', rim=0.3), subdiv=1)
    m = cel('crystal_' + cry, cry)
    for (x, z, h, r, tilt) in [(0, 0.1, 1.5, 0.28, 0), (-0.42, -0.05, 0.95, 0.2, 24), (0.42, -0.08, 1.05, 0.22, -22), (0.15, -0.2, 0.6, 0.15, -40)]:
        body = cyl((0, 0, 0), r=r, depth=h, verts=6)
        tip = cone((0, 0, h / 2 + r * 0.6), r=r, depth=r * 1.2, verts=6)
        c = join([body, tip]); c.location = (x, -0.15, z + h / 2 - 0.3); c.rotation_euler = (0, R(tilt), R(15))
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=0.001); bpy.ops.object.mode_set(mode='OBJECT')
        finish(c, m, smooth=False, hull=0.035)

@icon
def ore(): _ore('#4cc8ff')
@icon
def goldore(): _ore('#ffc93a')

def _eye(x, z, r=0.13, y=-0.75):
    finish(sphere((x, y, z), (r, r * 0.6, r)), cel('eye_white', '#ffffff'), hull=0.02)
    finish(sphere((x + r * 0.15, y - r * 0.4, z), (r * 0.55, r * 0.4, r * 0.6)), cel('pupil', '#15131c', spec=False), outline=False)
    finish(sphere((x - r * 0.1, y - r * 0.75, z + r * 0.25), (r * 0.18, r * 0.1, r * 0.18), 12, 8), cel('glint', '#ffffff'), outline=False)

@icon
def crow():
    finish(sphere((0, 0, -0.25), (0.85, 0.75, 0.8)), cel('crow', '#4a5372', rim=0.4))
    finish(sphere((0.15, -0.2, 0.55), (0.55, 0.52, 0.5)), cel('crow', '#4a5372', rim=0.4))
    w = sphere((-0.45, -0.35, -0.3), (0.35, 0.25, 0.55)); w.rotation_euler = (0, R(25), 0); finish(w, cel('crow_wing', '#2a2f42'))
    b = cone((0.78, -0.4, 0.45), r=0.2, depth=0.6, rot=(0, R(90), 0)); b.scale = (1, 1, 1); finish(b, cel('beak', '#ffc23a'))
    _eye(0.32, 0.68, 0.14, y=-0.62)
    for x in (-0.2, 0.25):
        finish(cyl((x, -0.1, -1.08), r=0.06, depth=0.3), cel('beak', '#ffc23a'), hull=0.02)

@icon
def pickaxe():
    finish(cyl((0, 0, -0.1), r=0.1, depth=2.1), cel('handle', '#b07440', stripe='#8e5a2e', stripe_freq=14, stripe_axis=2, stripe_w=0.6))
    finish(cyl((0, 0, -0.95), r=0.13, depth=0.4), cel('grip', '#5a3a6e', stripe='#432a54', stripe_freq=40, stripe_axis=2, stripe_w=0.3))
    head = puff([(-1.0, -0.3, 'v'), (-0.6, 0.12), (0, 0.32), (0.6, 0.12), (1.0, -0.3, 'v'), (0.55, -0.08), (0, -0.05), (-0.55, -0.08)],
                depth=0.1, bevel=0.07, loc=(0, 0, 0.88))
    finish(head, cel('steel', '#c9d6e6'))
    finish(cube((0, 0, 0.9), (0.2, 0.18, 0.22)), cel('handle_cap', '#7b8494'), bevel=0.05)
    group(rot=(0, R(-40), 0))

@icon
def twig():
    m = cel('wood', '#b9814a')
    finish(cyl((0, 0, 0), r=0.11, r2=0.06, depth=2.3, rot=(0, R(-40), 0)), m)
    finish(cyl((-0.15, 0, 0.45), r=0.07, r2=0.035, depth=0.9, rot=(0, R(15), 0)), m)
    finish(cyl((0.35, 0, -0.1), r=0.06, r2=0.03, depth=0.7, rot=(0, R(-95), 0)), m)
    for (x, z, a) in ((-0.07, 0.98, 20), (0.78, -0.08, -80), (-0.82, 0.98, 35)):
        l = puff([(0, -0.3, 'v'), (-0.16, 0), (0, 0.3, 'v'), (0.16, 0)], depth=0.02, bevel=0.05, loc=(x, -0.1, z), rot=(R(90), R(a), 0))
        finish(l, cel('leaf', '#6ad04a'), hull=0.022)

@icon
def nest():
    for i, (x, y, z, r) in enumerate(((-0.4, 0.15, 0.22, 0.42), (0.38, 0.12, 0.24, 0.44), (0, -0.2, 0.3, 0.44))):
        finish(sphere((x, y, z), (r * 0.8, r * 0.8, r)), cel('egg', '#fbf3e2'))
    bowl = sphere((0, 0, 0), (1.15, 0.9, 0.62))
    bpy.ops.object.mode_set(mode='EDIT'); import bmesh
    bm = bmesh.from_edit_mesh(bowl.data); bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.25], context='VERTS')
    bmesh.update_edit_mesh(bowl.data); bpy.ops.object.mode_set(mode='OBJECT')
    sol = bowl.modifiers.new('wall', 'SOLIDIFY'); sol.thickness = 0.08
    finish(bowl, cel('nest', '#9c6a3a'))
    rnd = random.Random(4); wm = cel('wood', '#c08a52')
    for i in range(26):                           # woven twigs wrapping the rim and body
        a = R(i * 360 / 26 + rnd.uniform(-6, 6)); z = rnd.uniform(-0.35, 0.22)
        k = math.sqrt(max(0.05, 1 - (z / 0.62) ** 2))
        t = cyl((math.cos(a) * 1.12 * k, math.sin(a) * 0.9 * k, z), r=0.045, depth=rnd.uniform(0.7, 1.0),
                rot=(R(rnd.uniform(-20, 20)), R(90 + rnd.uniform(-35, 35)), a + R(90)))
        finish(t, wm, hull=0.016)
    group(rot=(R(26), 0, 0))

@icon
def wood():
    finish(cyl((0, 0, 0), r=0.55, depth=1.9, rot=(0, R(90), 0)), cel('bark', '#a7683a', stripe='#7e4a22', stripe_freq=22, stripe_axis=1, stripe_w=0.6), bevel=0.04)
    finish(cyl((0.96, 0, 0), r=0.48, depth=0.04, rot=(0, R(90), 0)), cel('rings', '#f2c98c'), hull=0.0001)
    for r in (0.34, 0.2):
        finish(torus((0.985, 0, 0), R=r, r=0.018, rot=(0, R(90), 0)), cel('ringline', '#c98f52', spec=False), outline=False)
    finish(cyl((0.3, -0.1, 0.55), r=0.06, depth=0.4, rot=(R(-20), R(30), 0)), cel('bark', '#a7683a'), hull=0.018)
    group(rot=(R(10), 0, R(-38)))

@icon
def echo():
    balls = [(0, 0, 0.35, 0.9), (0, 0, -0.3, 0.85, (1, 0.8, 1.1))] + [(x, 0, -0.85, 0.36) for x in (-0.6, -0.2, 0.2, 0.6)]
    finish(blobs(balls, res=0.018, thresh=0.7), cel('echo', '#ff8fe6', rim=0.3))
    for x in (-0.3, 0.3): _eye(x, 0.3, 0.15, y=-0.72)
    finish(sphere((0, -0.78, -0.02), (0.11, 0.05, 0.07)), cel('mouth', '#6b1f5e', spec=False), outline=False)
    for x in (-0.52, 0.52): finish(sphere((x, -0.68, 0.06), (0.12, 0.03, 0.07)), cel('blush', '#ff5fc0', spec=False), outline=False)
    for (x, z, r) in ((-0.95, 0.75, 0.1), (0.95, 0.85, 0.08)):
        finish(sphere((x, 0, z), (r, r, r)), cel('echo', '#ff8fe6', rim=0.3), hull=0.015)

@icon
def mushroom():
    finish(cyl((0, 0, -0.55), r=0.35, r2=0.28, depth=1.0), cel('stem', '#fff1df'), bevel=0.08)
    cap = sphere((0, 0, 0.05), (1.0, 0.85, 0.65)); finish(cap, cel('cap', '#e74fd0'))
    for (x, z, r) in ((-0.45, 0.35, 0.16), (0.2, 0.55, 0.2), (0.6, 0.2, 0.12), (-0.05, 0.18, 0.1)):
        finish(sphere((x, -0.6, z), (r, 0.08, r * 0.85)), cel('spot', '#fff4fb'), hull=0.018)

# ---------------------------------------------------------------- expedition
@icon
def parrot():
    finish(sphere((0, 0, -0.25), (0.65, 0.55, 0.85)), cel('parrot', '#ff3a3a'))
    finish(sphere((0.05, -0.05, 0.6), (0.5, 0.48, 0.48)), cel('parrot', '#ff3a3a'))
    w = sphere((-0.3, -0.35, -0.3), (0.32, 0.22, 0.62)); w.rotation_euler = (0, R(18), 0); finish(w, cel('parrot_wing', '#2f9cff'))
    finish(sphere((-0.38, -0.45, -0.05), (0.2, 0.12, 0.25)), cel('parrot_y', '#ffd23a'), hull=0.02)
    t = puff([(-0.18, 0, 'v'), (0.18, 0, 'v'), (0.08, -0.75), (0, -0.85, 'v'), (-0.08, -0.75)], depth=0.05, bevel=0.07, loc=(-0.05, 0.15, -0.95)); finish(t, cel('parrot_wing', '#2f9cff'))
    bk = cone((0.6, -0.3, 0.5), r=0.26, depth=0.5, rot=(0, R(110), 0)); lump(bk, 0.0); finish(bk, cel('pbeak', '#fff0d0'), subdiv=1)
    finish(sphere((0.52, -0.3, 0.36), (0.13, 0.13, 0.1)), cel('pbeak_lo', '#3b3a45'), hull=0.02)
    finish(sphere((0.12, -0.45, 0.6), (0.2, 0.08, 0.17)), cel('face', '#ffffff'), hull=0.02)
    _eye(0.14, 0.64, 0.11, y=-0.52)

@icon
def sword():
    bl = puff([(-0.13, -0.2, 'v'), (0.13, -0.2, 'v'), (0.13, 1.45, 'v'), (0, 1.75, 'v'), (-0.13, 1.45, 'v')], depth=0.02, bevel=0.06, smooth_pts=False)
    finish(bl, cel('blade', '#dfe9f7'), smooth=False)
    finish(cube((0, 0, -0.25), (0.55, 0.1, 0.09)), cel('guard', '#ffc93a'), bevel=0.05)
    finish(cyl((0, 0, -0.68), r=0.1, depth=0.75), cel('grip', '#8a3e1e', stripe='#6a2c12', stripe_freq=40, stripe_axis=2))
    finish(sphere((0, 0, -1.1), (0.17, 0.17, 0.17)), cel('guard', '#ffc93a'))
    for o in [o for o in bpy.context.collection.objects]: pass
    col = bpy.context.collection
    piv = bpy.data.objects.new('pivot', None); col.objects.link(piv)
    for o in list(col.objects):
        if o is not piv: o.parent = piv
    piv.rotation_euler = (0, R(-40), 0)

@icon
def heart():
    pts = [(0, -1.05, 'v'), (-0.8, -0.2), (-0.92, 0.42), (-0.5, 0.86), (0, 0.55, 'v'), (0.5, 0.86), (0.92, 0.42), (0.8, -0.2)]
    finish(puff(pts, depth=0.12, bevel=0.24), cel('heart', '#ff3d5a'))

@icon
def shield():
    out = [(0, 1.05, 'v'), (0.95, 0.8, 'v'), (0.88, -0.1), (0, -1.15, 'v'), (-0.88, -0.1), (-0.95, 0.8, 'v')]
    finish(puff(out, depth=0.08, bevel=0.12), cel('shield_rim', '#ffc93a'))
    inn = [(p[0] * 0.75, p[1] * 0.75 - 0.03) + p[2:] for p in out]
    finish(puff(inn, depth=0.06, bevel=0.08, loc=(0, -0.16, 0)), cel('shield', '#2fbf8f'), hull=0.02)

@icon
def skill():
    pts = []
    for i in range(10):
        a = R(90 + i * 36); r = 1.0 if i % 2 == 0 else 0.45
        pts.append((math.cos(a) * r, math.sin(a) * r, 'v'))
    finish(puff(pts, depth=0.1, bevel=0.16), cel('star', '#ffcf3a'))

@icon
def monster():
    body = sphere((0, 0, -0.05), (1.0, 0.85, 1.1)); finish(body, cel('monster', '#3fd6e8'))
    for s_ in (-1, 1):
        finish(cone((0.48 * s_, 0, 1.05), r=0.2, depth=0.55, rot=(0, R(20 * s_), 0)), cel('horn', '#fff1d6'))
        a = sphere((1.0 * s_, -0.15, -0.35), (0.24, 0.22, 0.34)); a.rotation_euler = (0, R(-25 * s_), 0); finish(a, cel('monster', '#3fd6e8'))
        finish(sphere((0.38 * s_, -0.25, -1.08), (0.26, 0.24, 0.16)), cel('monster_foot', '#2bb3c6'))
    _eye(0, 0.3, 0.33, y=-0.82)
    finish(sphere((0, -0.8, -0.42), (0.5, 0.12, 0.17)), cel('mouth', '#4a1630', spec=False), hull=0.02)
    for x in (-0.25, 0.25): finish(cone((x, -0.9, -0.33), r=0.08, depth=0.16, rot=(R(180), 0, 0)), cel('tooth', '#ffffff'), hull=0.015)

@icon
def fish():
    b = sphere((0, 0, 0), (1.0, 0.4, 0.6)); finish(b, cel('fish', '#ff9a3a', stripe='#ffffff', stripe_freq=7, stripe_axis=0))
    t = puff([(0, 0, 'v'), (-0.55, 0.45, 'v'), (-0.42, 0, 'v'), (-0.55, -0.45, 'v')], depth=0.04, bevel=0.06, loc=(-0.85, 0, 0), smooth_pts=False)
    finish(t, cel('fin', '#ff6a2a'))
    finish(puff([(0, 0, 'v'), (0.3, 0.35), (0.55, 0, 'v')], depth=0.03, bevel=0.05, loc=(-0.2, 0, 0.5)), cel('fin', '#ff6a2a'), hull=0.02)
    _eye(0.55, 0.12, 0.13, y=-0.38)
