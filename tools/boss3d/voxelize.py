"""Boss icon -> voxel model (Blender). Every opaque icon pixel becomes a voxel column whose thickness grows toward
the middle of the shape (distance transform, so it reads puffy, not flat), coloured from the icon, front and back.
Usage: python3 voxelize.py <icon.png> <out_dir> [--res 56] [--frames 17] [--size 384]
Writes <name>.glb (Roblox-importable mesh, vertex colours), <name>_still.png and <name>_look.png (a grid of look-around
frames, yaw -40..+40 deg, for a flipbook ImageLabel) + <name>_look.json."""
import sys, os, json, math, argparse
import numpy as np
from PIL import Image
import bpy

ap = argparse.ArgumentParser(); ap.add_argument('icon'); ap.add_argument('out')
ap.add_argument('--res', type=int, default=72); ap.add_argument('--frames', type=int, default=17); ap.add_argument('--size', type=int, default=384)
ap.add_argument('--samples', type=int, default=48); ap.add_argument('--still-only', action='store_true')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
name = os.path.splitext(os.path.basename(a.icon))[0]; os.makedirs(a.out, exist_ok=True)

# ---------------------------------------------------------------- voxel grid from the icon
im = Image.open(a.icon).convert('RGBA'); bb = im.getbbox(); im = im.crop(bb)
w, h = im.size; s = a.res / max(w, h); R = (max(1, round(w * s)), max(1, round(h * s)))
px = np.array(im.resize(R, Image.LANCZOS)).astype(np.float32) / 255
alpha = px[..., 3]; solid = alpha > .6
col = px[..., :3] / np.maximum(alpha[..., None], 1e-3); col = np.clip(col, 0, 1)
# distance to the silhouette edge (cheap chamfer pass, no scipy needed)
H, W = solid.shape; d = np.where(solid, 1e9, 0.0)
for _ in range(2):
    for y in range(H):
        for x in range(W):
            if d[y, x] == 0: continue
            for dy, dx, c in ((-1, 0, 1), (0, -1, 1), (-1, -1, 1.414), (-1, 1, 1.414)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < H and 0 <= xx < W: d[y, x] = min(d[y, x], d[yy, xx] + c)
                else: d[y, x] = min(d[y, x], c)
    for y in range(H - 1, -1, -1):
        for x in range(W - 1, -1, -1):
            if d[y, x] == 0: continue
            for dy, dx, c in ((1, 0, 1), (0, 1, 1), (1, 1, 1.414), (1, -1, 1.414)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < H and 0 <= xx < W: d[y, x] = min(d[y, x], d[yy, xx] + c)
                else: d[y, x] = min(d[y, x], c)
edge = solid & (d <= 1.5)                                                         # silhouette ring = ink rim (our icon outline)
col[edge] = np.minimum(col[edge], 1) * .22 + np.array([.043, .047, .063]) * .78
half = np.where(solid, np.round(1 + np.sqrt(d) * 2.1), 0).astype(int)     # half-thickness in voxels (puffy dome)
D = int(half.max())

# ---------------------------------------------------------------- mesh: only exposed faces, flat per-face colour
verts, faces, fcol = [], [], []
def filled(x, y, z):
    return 0 <= x < W and 0 <= y < H and solid[y, x] and -half[y, x] <= z < half[y, x]
DIRS = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
        ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]
for y in range(H):
    for x in range(W):
        if not solid[y, x]: continue
        c = col[y, x]
        for z in range(-half[y, x], half[y, x]):
            for (nx, ny, nz), quad in DIRS:
                if filled(x + nx, y + ny, z + nz): continue
                shade = c if nz != 0 else c * .82            # sides a touch darker: reads like painted voxel art
                i = len(verts)
                # blender: X right, Z up (icon y flips), Y depth
                for qx, qy, qz in quad: verts.append(((x + qx - W / 2), (z + qz), (H - (y + qy)) ))
                faces.append((i, i + 1, i + 2, i + 3) if nz == 0 and ny == 0 and nx == 0 else (i, i + 1, i + 2, i + 3)); fcol.append(shade)
print(name, 'grid', W, H, 'depth', 2 * D, 'faces', len(faces))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
me.validate(); 
ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
for poly, c in zip(me.polygons, fcol):
    lin = [((v / 12.92) if v <= .04045 else ((v + .055) / 1.055) ** 2.4) for v in c]
    for li in poly.loop_indices: ca.data[li].color = (*lin, 1)
ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
for p in me.polygons: p.use_smooth = False
# fix winding so normals face out
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
k = 2.0 / H; ob.scale = (k, k, k)            # ~2 m tall
bpy.ops.object.transform_apply(scale=True)

mat = bpy.data.materials.new('vox'); mat.use_nodes = True; nt = mat.node_tree
bsdf = nt.nodes['Principled BSDF']; attr = nt.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Col'
nt.links.new(attr.outputs['Color'], bsdf.inputs['Base Color']); bsdf.inputs['Roughness'].default_value = .38
bsdf.inputs['Coat Weight'].default_value = .35; bsdf.inputs['Coat Roughness'].default_value = .15
me.materials.append(mat)
bpy.ops.export_scene.gltf(filepath=os.path.join(a.out, name + '.glb'), use_selection=True, export_format='GLB')

# ---------------------------------------------------------------- stage: shadow catcher, lights, camera
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0)); pl = bpy.context.object; pl.is_shadow_catcher = True
def area(loc, energy, color, size, rot):
    L = bpy.data.lights.new('L', 'AREA'); L.energy = energy; L.color = color; L.size = size
    o = bpy.data.objects.new('L', L); o.location = loc; o.rotation_euler = rot; sc.collection.objects.link(o)
area((-2.6, -3.2, 4.2), 260, (1, .9, .96), 2.5, (math.radians(45), 0, math.radians(-38)))      # key: warm, top-left-front
area((3.0, 2.6, 2.6), 520, (.75, .45, 1), 1.5, (math.radians(-60), 0, math.radians(135)))      # rim: violet, back-right
area((0, -3.5, .6), 45, (1, .45, .8), 3, (math.radians(85), 0, 0))                             # altar bounce: pink, low front
wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True; wd.node_tree.nodes['Background'].inputs[0].default_value = (.06, .03, .1, 1); wd.node_tree.nodes['Background'].inputs[1].default_value = .35
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 70
r = 6.4; el = math.radians(9)
def aim(yaw):
    cam.location = (math.sin(yaw) * r * math.cos(el), -math.cos(yaw) * r * math.cos(el), 1.0 + r * math.sin(el))
    d = (-(cam.location[0]), -(cam.location[1]), 1.0 - cam.location[2]); 
    import mathutils; cam.rotation_euler = mathutils.Vector(d).to_track_quat('-Z', 'Y').to_euler()
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = a.samples; sc.cycles.use_denoising = True
sc.render.film_transparent = True; sc.render.resolution_x = sc.render.resolution_y = a.size
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
aim(0); sc.render.filepath = os.path.join(a.out, name + '_still.png'); bpy.ops.render.render(write_still=True)
if not a.still_only:
    n = a.frames; cols = math.ceil(math.sqrt(n)); rows = math.ceil(n / cols); sheet = Image.new('RGBA', (cols * a.size, rows * a.size))
    for i in range(n):
        yaw = math.radians(-40 + 80 * i / (n - 1)); aim(yaw)
        f = os.path.join(a.out, f'_f{i:02d}.png'); sc.render.filepath = f; bpy.ops.render.render(write_still=True)
        sheet.paste(Image.open(f), ((i % cols) * a.size, (i // cols) * a.size)); os.remove(f)
    sheet.save(os.path.join(a.out, name + '_look.png'))
    json.dump({'frames': n, 'cols': cols, 'size': a.size, 'yaw': [-40, 40]}, open(os.path.join(a.out, name + '_look.json'), 'w'))
print('done', name)
