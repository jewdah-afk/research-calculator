"""Build every Peckwood UI icon in Blender and render it (cel shaded, subtle tinted outline, transparent).

Run:  python3 birb-icons/build_icons.py [icon names...]      (no names = all)
Out:  birb-icons/renders/<name>.png  (512px) and birb-icons/peckwood_icons.blend
Each icon lives in its own collection `icon/<name>`, centred on the origin, front facing -Y.
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from lib import *
from icons import ICONS

HERE = os.path.dirname(os.path.abspath(__file__))
names = [a for a in sys.argv[1:] if not a.startswith('-')] or list(ICONS)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24
sc.cycles.use_denoising = False; sc.cycles.max_bounces = 2; sc.cycles.transparent_max_bounces = 16
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = 512
sc.view_settings.view_transform = 'Standard'
sc.render.image_settings.color_mode = 'RGBA'

cam_data = bpy.data.cameras.new('cam'); cam_data.type = 'ORTHO'
cam = bpy.data.objects.new('cam', cam_data); sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)   # looks along +Y, straight on

made = []
for n in names:
    col = bpy.data.collections.new('icon/' + n); sc.collection.children.link(col)
    lc = bpy.context.view_layer.layer_collection.children[col.name]
    bpy.context.view_layer.active_layer_collection = lc
    ICONS[n]()
    made.append(n)

def bounds(col):
    from mathutils import Vector
    dg = bpy.context.evaluated_depsgraph_get(); xs, zs = [], []
    for o in col.all_objects:
        if o.type != 'MESH': continue
        ev = o.evaluated_get(dg)
        for v in ev.data.vertices:
            w = ev.matrix_world @ v.co; xs.append(w.x); zs.append(w.z)
    return min(xs), max(xs), min(zs), max(zs)

for n in made:
    for c in sc.collection.children: c.hide_render = (c.name != 'icon/' + n)
    col = bpy.data.collections['icon/' + n]
    x0, x1, z0, z1 = bounds(col)
    cam.location = ((x0 + x1) / 2, -20, (z0 + z1) / 2)
    cam_data.ortho_scale = max(x1 - x0, z1 - z0) * 1.18   # ~8% padding each side
    sc.render.filepath = os.path.join(HERE, 'renders', n + '.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', n)

for c in sc.collection.children: c.hide_render = False
if set(made) == set(ICONS):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'peckwood_icons.blend'))
