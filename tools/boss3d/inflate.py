"""Boss icon -> smooth 'inflated toy' model (Blender). The silhouette is puffed into a soft dome (front and back), the
icon is projected onto the front (so every painted detail survives), the back gets the icon mirrored. The mesh is
smoothed (Laplacian + subdivision, UVs re-projected after), cel-shaded (hard light / mid / shadow bands, a rim band and
a crisp highlight, all from a fixed key direction) and outlined with an inverted hull. Outputs: <name>_toy.glb, <name>_toy_still.png, <name>_toy_look.png (+ .json).
Usage: python3 inflate.py <icon.png> <out_dir> [--res 160] [--frames 17] [--size 384] [--depth .55]"""
import sys, os, json, math, argparse
import numpy as np
from PIL import Image, ImageFilter
import bpy, mathutils

ap = argparse.ArgumentParser(); ap.add_argument('icon'); ap.add_argument('out')
ap.add_argument('--res', type=int, default=160); ap.add_argument('--frames', type=int, default=17); ap.add_argument('--size', type=int, default=384)
ap.add_argument('--samples', type=int, default=48); ap.add_argument('--depth', type=float, default=.55); ap.add_argument('--still-only', action='store_true')
ap.add_argument('--gloss', type=float, default=.3); ap.add_argument('--smooth', type=int, default=6); ap.add_argument('--yaw', type=float, default=0)
a = ap.parse_args(sys.argv[1:])
name = os.path.splitext(os.path.basename(a.icon))[0]; os.makedirs(a.out, exist_ok=True)

src = Image.open(a.icon).convert('RGBA'); bb = src.getbbox(); src = src.crop(bb)
pad = 4; W0, H0 = src.size; big = Image.new('RGBA', (W0 + 2 * pad, H0 + 2 * pad)); big.paste(src, (pad, pad)); src = big
# the icon's painted ink ring would smear over the curved sides: paint body colour into it (the 3D outline comes from
# an inverted hull instead, so the ink line follows the silhouette from every angle)
import cv2
arr = np.array(src); A_ = arr[..., 3]; inside = (A_ > 128).astype(np.uint8)
dist = cv2.distanceTransform(inside, cv2.DIST_L2, 5)
luma = arr[..., :3].astype(np.float32) @ np.array([.3, .59, .11])
band = (dist > 0) & (dist < .09 * max(src.size))
dark = band & (luma < 42)                                                        # the painted ink, wherever it reaches
ring = ((dist > 0) & (dist < 3)) | dark
ring = cv2.dilate(ring.astype(np.uint8), np.ones((3, 3), np.uint8)) * 255
# keep genuinely dark bodies (e.g. the black pudding) from being erased: only remove ink that hugs the edge
if dark.sum() > .85 * band.sum(): ring = (((dist > 0) & (dist < max(5, .035 * max(src.size)))) * 255).astype(np.uint8)
fillmask = np.where((ring > 0) | (inside == 0), 255, 0).astype(np.uint8)            # learn colour from the interior only
rgb = cv2.inpaint(np.ascontiguousarray(arr[..., :3]), fillmask, 8, cv2.INPAINT_TELEA)
arr[..., :3] = np.where(ring[..., None] > 0, rgb, arr[..., :3]); src = Image.fromarray(arr)
tex_path = os.path.join(a.out, name + '_tex.png'); src.save(tex_path)
w, h = src.size; s = a.res / max(w, h); W, H = max(2, round(w * s)), max(2, round(h * s))
al = np.array(src.split()[3].resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
solid = al > .5
# pillow profile: distance to the silhouette edge -> circular cross-section (round rims, full dome), capped for big shapes
import cv2
d = cv2.distanceTransform(solid.astype(np.uint8), cv2.DIST_L2, 5).astype(np.float32)
R = max(1.0, min(d.max(), .32 * max(W, H)))
t = np.clip(d / R, 0, 1); hgt = np.sqrt(t * (2 - t)) * R / max(W, H) * solid       # 0 at the rim, R at the core
hgt = cv2.GaussianBlur(hgt, (0, 0), 1.2) * solid
scale = 2.0 / H                     # ~2 m tall
dz = a.depth * 2.2 * max(W, H) * scale
verts, faces, uvs = [], [], []
idx = -np.ones((2, H, W), int)
for side, sign in ((0, 1), (1, -1)):
    for y in range(H):
        for x in range(W):
            if not solid[y, x]: continue
            idx[side, y, x] = len(verts)
            verts.append(((x - W / 2) * scale, -sign * (hgt[y, x] * dz + .004), (H - y) * scale))
            uvs.append(((x + .5) / W, 1 - (y + .5) / H))
for side in (0, 1):
    for y in range(H - 1):
        for x in range(W - 1):
            q = [idx[side, y, x], idx[side, y, x + 1], idx[side, y + 1, x + 1], idx[side, y + 1, x]]
            if min(q) < 0: continue
            faces.append(q if side == 0 else q[::-1])
# rim: join front and back along every boundary edge of the silhouette
for y in range(H):
    for x in range(W):
        for (ya, xa), (yb, xb) in (((y, x), (y, x + 1)), ((y, x), (y + 1, x))):
            if yb >= H or xb >= W or not (solid[ya, xa] and solid[yb, xb]): continue
            if ya == yb: n1 = ya > 0 and solid[ya - 1, xa] and solid[ya - 1, xb]; n2 = ya + 1 < H and solid[ya + 1, xa] and solid[ya + 1, xb]
            else: n1 = xa > 0 and solid[ya, xa - 1] and solid[yb, xb - 1]; n2 = xa + 1 < W and solid[ya, xa + 1] and solid[yb, xb + 1]
            if n1 and n2: continue
            faces.append([idx[0, ya, xa], idx[0, yb, xb], idx[1, yb, xb], idx[1, ya, xa]])
print(name, 'grid', W, H, 'verts', len(verts), 'faces', len(faces))

bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update(); me.validate()
uvl = me.uv_layers.new(name='UV')
for poly in me.polygons:
    for li in poly.loop_indices: uvl.data[li].uv = uvs[me.loops[li].vertex_index]
ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=1e-5)
bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
# smooth out the pixel staircase on the rim and the lumps on the dome, then re-project the icon onto the new surface
sm = ob.modifiers.new('smooth', 'SMOOTH'); sm.factor = .6; sm.iterations = a.smooth
bpy.ops.object.modifier_apply(modifier='smooth')
sub = ob.modifiers.new('sub', 'SUBSURF'); sub.levels = sub.render_levels = 1; bpy.ops.object.modifier_apply(modifier='sub')
for p in me.polygons: p.use_smooth = True
uvl = me.uv_layers['UV']
for li, loop in enumerate(me.loops):
    v = me.vertices[loop.vertex_index].co
    uvl.data[li].uv = (v.x / (W * scale) + .5, v.z / (H * scale))
mat = bpy.data.materials.new('cel'); mat.use_nodes = True; nt = mat.node_tree; nt.nodes.clear(); N_ = nt.nodes.new; Ln = nt.links.new
# cel shader built from the normal and a fixed key direction (Emission, so the bands stay hard; same math a Roblox
# shader-free version bakes into the texture or approximates with ViewportFrame lighting)
img = bpy.data.images.load(tex_path); tx = N_('ShaderNodeTexImage'); tx.image = img; tx.interpolation = 'Cubic'
geo_ = N_('ShaderNodeNewGeometry')
KEY = mathutils.Vector((-.45, -.55, .7)).normalized()
kd = N_('ShaderNodeCombineXYZ'); kd.inputs[0].default_value, kd.inputs[1].default_value, kd.inputs[2].default_value = KEY
ndl = N_('ShaderNodeVectorMath'); ndl.operation = 'DOT_PRODUCT'; Ln(geo_.outputs['Normal'], ndl.inputs[0]); Ln(kd.outputs[0], ndl.inputs[1])
band = N_('ShaderNodeValToRGB'); band.color_ramp.interpolation = 'CONSTANT'; e = band.color_ramp.elements
e[0].position = 0; e[0].color = (.42, .36, .62, 1)            # shadow: cool violet
e[1].position = .45; e[1].color = (.80, .76, .88, 1)          # mid
e.new(.78).color = (1.0, .97, .95, 1)                        # light: warm
mapr = N_('ShaderNodeMapRange'); mapr.inputs['From Min'].default_value = -1; Ln(ndl.outputs['Value'], mapr.inputs['Value']); Ln(mapr.outputs[0], band.inputs[0])
mul = N_('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
Ln(tx.outputs['Color'], mul.inputs[6]); Ln(band.outputs['Color'], mul.inputs[7])
# rim band (violet, the arena's crystal light) on silhouettes facing away from the key
lw = N_('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = .35
rimr = N_('ShaderNodeValToRGB'); rimr.color_ramp.interpolation = 'CONSTANT'; rimr.color_ramp.elements[0].color = (0, 0, 0, 1); rimr.color_ramp.elements[1].position = .7; rimr.color_ramp.elements[1].color = (.36, .2, .6, 1)
Ln(lw.outputs['Facing'], rimr.inputs[0])
away = N_('ShaderNodeMath'); away.operation = 'LESS_THAN'; away.inputs[1].default_value = .25; Ln(ndl.outputs['Value'], away.inputs[0])
rimm = N_('ShaderNodeMix'); rimm.data_type = 'RGBA'; rimm.blend_type = 'MULTIPLY'; Ln(away.outputs[0], rimm.inputs['Factor']); rimm.inputs[6].default_value = (0, 0, 0, 1); Ln(rimr.outputs['Color'], rimm.inputs[7])
rimm.blend_type = 'MIX'
# crisp specular dot: N.H with H from the key and the view
inc = N_('ShaderNodeVectorMath'); inc.operation = 'ADD'; Ln(geo_.outputs['Incoming'], inc.inputs[0]); Ln(kd.outputs[0], inc.inputs[1])
hn = N_('ShaderNodeVectorMath'); hn.operation = 'NORMALIZE'; Ln(inc.outputs[0], hn.inputs[0])
ndh = N_('ShaderNodeVectorMath'); ndh.operation = 'DOT_PRODUCT'; Ln(geo_.outputs['Normal'], ndh.inputs[0]); Ln(hn.outputs[0], ndh.inputs[1])
spr = N_('ShaderNodeValToRGB'); spr.color_ramp.interpolation = 'CONSTANT'; spr.color_ramp.elements[0].color = (0, 0, 0, 1); spr.color_ramp.elements[1].position = .988; spr.color_ramp.elements[1].color = (a.gloss, a.gloss, a.gloss, 1)
Ln(ndh.outputs['Value'], spr.inputs[0])
add1 = N_('ShaderNodeMix'); add1.data_type = 'RGBA'; add1.blend_type = 'ADD'; add1.inputs['Factor'].default_value = 1; Ln(mul.outputs[2], add1.inputs[6]); Ln(rimm.outputs[2], add1.inputs[7])
add2 = N_('ShaderNodeMix'); add2.data_type = 'RGBA'; add2.blend_type = 'ADD'; add2.inputs['Factor'].default_value = 1; Ln(add1.outputs[2], add2.inputs[6]); Ln(spr.outputs['Color'], add2.inputs[7])
emi = N_('ShaderNodeEmission'); Ln(add2.outputs[2], emi.inputs['Color']); o_ = N_('ShaderNodeOutputMaterial'); Ln(emi.outputs[0], o_.inputs['Surface'])
me.materials.append(mat)
# ink outline = inverted hull: Solidify outward + flipped normals, black where we see its back faces, clear elsewhere
ink = bpy.data.materials.new('ink'); ink.use_nodes = True; it = ink.node_tree; it.nodes.clear()
out = it.nodes.new('ShaderNodeOutputMaterial'); geo = it.nodes.new('ShaderNodeNewGeometry'); mix = it.nodes.new('ShaderNodeMixShader')
em = it.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (.004, .005, .008, 1); tr = it.nodes.new('ShaderNodeBsdfTransparent')
it.links.new(geo.outputs['Backfacing'], mix.inputs['Fac']); it.links.new(em.outputs[0], mix.inputs[1]); it.links.new(tr.outputs[0], mix.inputs[2]); lp = it.nodes.new('ShaderNodeLightPath'); mix2 = it.nodes.new('ShaderNodeMixShader'); tr2 = it.nodes.new('ShaderNodeBsdfTransparent')
it.links.new(lp.outputs['Is Camera Ray'], mix2.inputs['Fac']); it.links.new(tr2.outputs[0], mix2.inputs[1]); it.links.new(mix.outputs[0], mix2.inputs[2])
it.links.new(mix2.outputs[0], out.inputs['Surface'])   # outline only exists for the camera: casts no shadow, blocks no light
me.materials.append(ink)
sol = ob.modifiers.new('ink', 'SOLIDIFY'); sol.thickness = .04; sol.offset = 1; sol.use_flip_normals = True; sol.use_rim = False; sol.material_offset = 1
sol.show_render = sol.show_viewport = False
bpy.ops.export_scene.gltf(filepath=os.path.join(a.out, name + '_toy.glb'), use_selection=True, export_format='GLB', export_apply=True)
sol.show_render = sol.show_viewport = True

bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0)); bpy.context.object.is_shadow_catcher = True
def area(loc, energy, color, size, rot):
    L = bpy.data.lights.new('L', 'AREA'); L.energy = energy; L.color = color; L.size = size
    o = bpy.data.objects.new('L', L); o.location = loc; o.rotation_euler = rot; sc.collection.objects.link(o)
area((-2.6, -3.2, 4.2), 230, (1, .92, .96), 2.5, (math.radians(45), 0, math.radians(-38)))     # key: warm, top-left-front
wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True; bg = wd.node_tree.nodes['Background']
bg.inputs[0].default_value = (.5, .45, .6, 1); bg.inputs[1].default_value = .45
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam; cam.data.lens = 70
r = 6.4; el = math.radians(9)
def aim(yaw):
    cam.location = (math.sin(yaw) * r * math.cos(el), -math.cos(yaw) * r * math.cos(el), 1.0 + r * math.sin(el))
    cam.rotation_euler = mathutils.Vector((-cam.location[0], -cam.location[1], 1.0 - cam.location[2])).to_track_quat('-Z', 'Y').to_euler()
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = a.samples; sc.cycles.use_denoising = True
sc.render.film_transparent = True; sc.render.resolution_x = sc.render.resolution_y = a.size
sc.view_settings.view_transform = 'Standard'
aim(math.radians(a.yaw)); sc.render.filepath = os.path.join(a.out, name + '_toy_still.png'); bpy.ops.render.render(write_still=True)
if not a.still_only:
    n = a.frames; cols = math.ceil(math.sqrt(n)); rows = math.ceil(n / cols); sheet = Image.new('RGBA', (cols * a.size, rows * a.size))
    for i in range(n):
        aim(math.radians(-40 + 80 * i / (n - 1))); f = os.path.join(a.out, f'_t{i:02d}.png'); sc.render.filepath = f; bpy.ops.render.render(write_still=True)
        sheet.paste(Image.open(f), ((i % cols) * a.size, (i // cols) * a.size)); os.remove(f)
    sheet.save(os.path.join(a.out, name + '_toy_look.png'))
    json.dump({'frames': n, 'cols': cols, 'size': a.size, 'yaw': [-40, 40]}, open(os.path.join(a.out, name + '_toy_look.json'), 'w'))
print('done', name)
