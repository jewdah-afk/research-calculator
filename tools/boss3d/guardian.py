"""Snake Wars World guardians -> cel-shaded, ink-outlined toy renders (Blender, no credits).
A coiled snake (tube along a rising spiral, scale pattern, belly, big toy eyes, two fang tips) wears a per-World crown:
OAKCOIL (branches + leaves + blossoms), CORALCROWN (coral), PRISMARA (crystals), BLIZZARA (ice horns), IGNIS (gold horns +
flames), VOID WARDEN (glowing halo, starry body). Same cel recipe as inflate.py (light / mid / shadow bands from a fixed key,
rim band, crisp highlight) and the same inverted-hull ink outline. Outputs <out>/<id>_still.png, <id>_look.png (+ .json),
<id>.glb.  Usage: python3 guardian.py <id|all> <out_dir> [--size 512] [--frames 17] [--samples 32]"""
import sys, os, json, math, argparse
import bpy, mathutils
from PIL import Image

ap = argparse.ArgumentParser(); ap.add_argument('which'); ap.add_argument('out')
ap.add_argument('--size', type=int, default=512); ap.add_argument('--frames', type=int, default=17)
ap.add_argument('--samples', type=int, default=32); ap.add_argument('--still-only', action='store_true')
a = ap.parse_args(sys.argv[1:]); os.makedirs(a.out, exist_ok=True)

def hexc(h, k=1.0):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(min(1, (x ** 2.2) * k) for x in c) + (1,)          # sRGB -> linear

# body / belly / scale-dark / accent colours and the cel band tints (shadow, rim) per World
G = {
    'oakcoil':    dict(name='OAKCOIL', body='#5fae3a', belly='#e8dca0', dark='#2f6b25', rim='#ffe27a', shadow='#3b4a7a', crown='oak'),
    'coralcrown': dict(name='CORALCROWN', body='#3cc7c9', belly='#fbe3c4', dark='#1f7f8f', rim='#ffd0e0', shadow='#2c3f7c', crown='coral'),
    'prismara':   dict(name='PRISMARA', body='#9a5ae0', belly='#f3d9ff', dark='#5a2aa0', rim='#ff9be8', shadow='#2a1f66', crown='crystal'),
    'blizzara':   dict(name='BLIZZARA', body='#8fb6dc', belly='#f2f8ff', dark='#4f78a8', rim='#bff3ff', shadow='#334a8c', crown='ice'),
    'ignis':      dict(name='IGNIS', body='#3b2a2a', belly='#ffb347', dark='#1c1414', rim='#ff7a2a', shadow='#2a1638', crown='fire'),
    'voidwarden': dict(name='VOID WARDEN', body='#2a1d5c', belly='#7a6cff', dark='#130b33', rim='#52f2ff', shadow='#120a2e', crown='void'),
}
KEY = mathutils.Vector((-.45, -.6, .66)).normalized()

def cel_mat(name, col, shadow, rim, scales=None, gloss=.35, emit=None):
    """Emission-only cel shader: colour x (shadow | mid | light) band + rim band away from the key + a crisp highlight.
    scales=(dark colour, scale) adds a faint snake-scale Voronoi pattern (the Venom Candy panel texture, on the body)."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear(); N = nt.nodes.new; L = nt.links.new
    geo = N('ShaderNodeNewGeometry')
    kd = N('ShaderNodeCombineXYZ'); kd.inputs[0].default_value, kd.inputs[1].default_value, kd.inputs[2].default_value = KEY
    ndl = N('ShaderNodeVectorMath'); ndl.operation = 'DOT_PRODUCT'; L(geo.outputs['Normal'], ndl.inputs[0]); L(kd.outputs[0], ndl.inputs[1])
    mr = N('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = -1; L(ndl.outputs['Value'], mr.inputs['Value'])
    band = N('ShaderNodeValToRGB'); band.color_ramp.interpolation = 'CONSTANT'; e = band.color_ramp.elements
    sh = shadow; e[0].position = 0; e[0].color = (.3 + sh[0] * .6, .3 + sh[1] * .6, .36 + sh[2] * .6, 1)
    e[1].position = .45; e[1].color = (.74, .72, .82, 1); e.new(.74).color = (1.0, .98, .95, 1)
    L(mr.outputs[0], band.inputs[0])
    base = N('ShaderNodeRGB'); base.outputs[0].default_value = col; src = base.outputs[0]
    if scales:
        tc = N('ShaderNodeTexCoord'); vo = N('ShaderNodeTexVoronoi'); vo.feature = 'DISTANCE_TO_EDGE'; vo.inputs['Scale'].default_value = scales[1]
        L(tc.outputs['Object'], vo.inputs['Vector'])
        edge = N('ShaderNodeMath'); edge.operation = 'LESS_THAN'; edge.inputs[1].default_value = .045; L(vo.outputs['Distance'], edge.inputs[0])
        fe = N('ShaderNodeMath'); fe.operation = 'MULTIPLY'; fe.inputs[1].default_value = .4; L(edge.outputs[0], fe.inputs[0])
        mx = N('ShaderNodeMix'); mx.data_type = 'RGBA'; L(fe.outputs[0], mx.inputs['Factor']); L(src, mx.inputs[6])
        dk = N('ShaderNodeRGB'); dk.outputs[0].default_value = scales[0]; L(dk.outputs[0], mx.inputs[7]); src = mx.outputs[2]
    mul = N('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
    L(src, mul.inputs[6]); L(band.outputs['Color'], mul.inputs[7])
    lw = N('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = .3
    rr = N('ShaderNodeValToRGB'); rr.color_ramp.interpolation = 'CONSTANT'; rr.color_ramp.elements[0].color = (0, 0, 0, 1)
    rr.color_ramp.elements[1].position = .72; rr.color_ramp.elements[1].color = tuple(c * .55 for c in rim[:3]) + (1,)
    L(lw.outputs['Facing'], rr.inputs[0])
    away = N('ShaderNodeMath'); away.operation = 'LESS_THAN'; away.inputs[1].default_value = .3; L(ndl.outputs['Value'], away.inputs[0])
    rm = N('ShaderNodeMix'); rm.data_type = 'RGBA'; L(away.outputs[0], rm.inputs['Factor']); rm.inputs[6].default_value = (0, 0, 0, 1); L(rr.outputs['Color'], rm.inputs[7])
    inc = N('ShaderNodeVectorMath'); inc.operation = 'ADD'; L(geo.outputs['Incoming'], inc.inputs[0]); L(kd.outputs[0], inc.inputs[1])
    hn = N('ShaderNodeVectorMath'); hn.operation = 'NORMALIZE'; L(inc.outputs[0], hn.inputs[0])
    ndh = N('ShaderNodeVectorMath'); ndh.operation = 'DOT_PRODUCT'; L(geo.outputs['Normal'], ndh.inputs[0]); L(hn.outputs[0], ndh.inputs[1])
    sp = N('ShaderNodeValToRGB'); sp.color_ramp.interpolation = 'CONSTANT'; sp.color_ramp.elements[0].color = (0, 0, 0, 1)
    sp.color_ramp.elements[1].position = .975; sp.color_ramp.elements[1].color = (gloss, gloss, gloss, 1); L(ndh.outputs['Value'], sp.inputs[0])
    a1 = N('ShaderNodeMix'); a1.data_type = 'RGBA'; a1.blend_type = 'ADD'; a1.inputs['Factor'].default_value = 1; L(mul.outputs[2], a1.inputs[6]); L(rm.outputs[2], a1.inputs[7])
    a2 = N('ShaderNodeMix'); a2.data_type = 'RGBA'; a2.blend_type = 'ADD'; a2.inputs['Factor'].default_value = 1; L(a1.outputs[2], a2.inputs[6]); L(sp.outputs['Color'], a2.inputs[7])
    em = N('ShaderNodeEmission'); L(a2.outputs[2], em.inputs['Color'])
    if emit: em.inputs['Strength'].default_value = emit
    o = N('ShaderNodeOutputMaterial'); L(em.outputs[0], o.inputs['Surface'])
    return m

def ink_mat():
    m = bpy.data.materials.new('ink'); m.use_nodes = True; it = m.node_tree; it.nodes.clear(); N = it.nodes.new; L = it.links.new
    out = N('ShaderNodeOutputMaterial'); geo = N('ShaderNodeNewGeometry'); mix = N('ShaderNodeMixShader')
    em = N('ShaderNodeEmission'); em.inputs['Color'].default_value = (.004, .005, .01, 1); tr = N('ShaderNodeBsdfTransparent')
    L(geo.outputs['Backfacing'], mix.inputs['Fac']); L(em.outputs[0], mix.inputs[1]); L(tr.outputs[0], mix.inputs[2])
    lp = N('ShaderNodeLightPath'); m2 = N('ShaderNodeMixShader'); t2 = N('ShaderNodeBsdfTransparent')
    L(lp.outputs['Is Camera Ray'], m2.inputs['Fac']); L(t2.outputs[0], m2.inputs[1]); L(mix.outputs[0], m2.inputs[2]); L(m2.outputs[0], out.inputs['Surface'])
    return m

def link(ob): bpy.context.scene.collection.objects.link(ob); return ob

def finish(ob, mat, ink, thick=.035, smooth=True):
    ob.data.materials.append(mat); ob.data.materials.append(ink)
    if smooth:
        for p in ob.data.polygons: p.use_smooth = True
    s = ob.modifiers.new('ink', 'SOLIDIFY'); s.thickness = thick; s.offset = 1; s.use_flip_normals = True; s.use_rim = False; s.material_offset = 1
    return ob

def mesh_from(op, **kw):
    op(**kw); return bpy.context.object

def tube(points, radii, name, res=20):
    """Bezier tube through points with per-point radius (tapers), converted to a mesh."""
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 1; cu.bevel_resolution = 6; cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(len(points) - 1)
    for bp, p, r in zip(sp.bezier_points, points, radii):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = 'AUTO'; bp.radius = r
    ob = link(bpy.data.objects.new(name, cu)); bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects: o.select_set(False)
    ob.select_set(True); bpy.ops.object.convert(target='MESH'); return bpy.context.object

def ell(loc, scale, name, seg=40):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc); o = bpy.context.object
    o.scale = scale; o.name = name; bpy.ops.object.transform_apply(scale=True); return o

def cone(loc, r1, r2, depth, rot, name, verts=24):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; return o

def horn(base, direction, length, r, curl, name, segs=7):
    """Curved tapering horn as a tube: from base along direction, bending upward/back by curl."""
    d = mathutils.Vector(direction).normalized(); pts, rad = [], []
    for i in range(segs):
        t = i / (segs - 1); bend = mathutils.Vector((0, curl * t * t, curl * .6 * t * t))
        pts.append(mathutils.Vector(base) + d * length * t + bend); rad.append(r * (1 - t) + .012)
    return tube(pts, rad, name, res=10)

def build(gid):
    g = G[gid]; bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
    sh = hexc(g['shadow']); rim = hexc(g['rim']); ink = ink_mat()
    body_m = cel_mat('body', hexc(g['body']), sh, rim, scales=(hexc(g['dark']), 6.5), gloss=.3, emit=1.0)
    belly_m = cel_mat('belly', hexc(g['belly']), sh, rim, gloss=.3)
    white_m = cel_mat('white', hexc('#ffffff'), sh, rim, gloss=.0)
    pupil_m = cel_mat('pupil', hexc('#0b0b14'), sh, rim, gloss=.9)
    parts = []
    # coil: a rising spiral behind the head (two loops, tail tip at the front), tapering to the tail
    pts, rad = [], []
    n = 22
    for i in range(n):
        t = i / (n - 1); ang = math.radians(-60 + 600 * t); R = 1.15 - .35 * t
        pts.append(mathutils.Vector((math.cos(ang) * R, math.sin(ang) * R * .8 + .25, .32 + 1.25 * t)))
        rad.append(.16 + .26 * t)
    pts = pts[::-1]; rad = rad[::-1]                       # thick end first (neck), tail last
    # neck rises from the top of the coil into the head
    top = pts[0]; head_c = mathutils.Vector((0, -.35, 2.55))
    neck = [head_c + mathutils.Vector((0, .25, -.45)), (head_c + top) / 2 + mathutils.Vector((0, -.1, 0)), top]
    body = tube(neck[:2] + pts, [.40, .42] + rad, 'body'); parts.append(finish(body, body_m, ink))
    # head: a chubby toy head with a snout, looking at the camera (-Y)
    S = 1.3; V = lambda x, y, z: head_c + mathutils.Vector((x * S, y * S, z * S))
    hd = ell(head_c, (.78 * S, .62 * S, .58 * S), 'head'); parts.append(finish(hd, body_m, ink, .045))
    sn = ell(V(0, -.42, -.16), (.5 * S, .36 * S, .3 * S), 'snout'); parts.append(finish(sn, body_m, ink, .04))
    jaw = ell(V(0, -.36, -.33), (.42 * S, .32 * S, .16 * S), 'jaw'); parts.append(finish(jaw, belly_m, ink, .035))
    for sx in (-1, 1):
        ey = ell(V(.34 * sx, -.5, .2), (.25 * S, .22 * S, .27 * S), 'eye'); parts.append(finish(ey, white_m, ink, .035))
        pu = ell(V(.31 * sx, -.68, .17), (.14 * S, .07 * S, .17 * S), 'pupil'); pu.data.materials.append(pupil_m); parts.append(pu)
        gl = ell(V(.26 * sx, -.745, .27), (.05 * S, .02 * S, .055 * S), 'glint'); gl.data.materials.append(white_m); parts.append(gl)
        fg = cone(V(.15 * sx, -.6, -.47), .065 * S, .0, .22 * S, (math.pi, 0, 0), 'fang'); parts.append(finish(fg, white_m, ink, .022))
        ns = ell(V(.12 * sx, -.77, -.06), (.045 * S, .02 * S, .03 * S), 'nostril'); ns.data.materials.append(pupil_m); parts.append(ns)
    c = g['crown']; top_h = head_c + mathutils.Vector((0, .05, .62))
    if c == 'ice':
        ice = cel_mat('ice', hexc('#f4fbff'), sh, rim, gloss=.8)
        for sx in (-1, 1):
            h = horn(top_h + mathutils.Vector((.32 * sx, 0, -.05)), (.9 * sx, .3, .9), 1.05, .2, .5, 'horn'); parts.append(finish(h, ice, ink, .03))
        for i, sx in enumerate((-.45, -.15, .15, .45)):
            ic = cone(head_c + mathutils.Vector((sx, .1, .62)), .1, 0, .34, (math.radians(-12), 0, 0), 'spike'); parts.append(finish(ic, ice, ink, .025))
    elif c == 'oak':
        bark = cel_mat('bark', hexc('#7a4e2c'), sh, rim, gloss=0); leaf = cel_mat('leaf', hexc('#7bd34b'), sh, rim, gloss=.2)
        blos = cel_mat('blossom', hexc('#ff9fd0'), sh, rim, gloss=.2)
        for sx in (-1, 1):
            b = horn(top_h + mathutils.Vector((.28 * sx, 0, -.05)), (.6 * sx, .2, 1), .95, .11, .25, 'branch'); parts.append(finish(b, bark, ink, .025))
            tip = top_h + mathutils.Vector((.6 * sx, .3, .85))
            for k, off in enumerate(((0, 0, 0), (.22 * sx, -.1, -.12), (-.18 * sx, .05, -.1))):
                lf = ell(tip + mathutils.Vector(off), (.26, .18, .16), 'leaf'); parts.append(finish(lf, leaf, ink, .025))
            bl = ell(tip + mathutils.Vector((.05 * sx, -.2, .1)), (.1, .08, .1), 'blossom'); parts.append(finish(bl, blos, ink, .02))
    elif c == 'coral':
        cor = cel_mat('coral', hexc('#ff7a5c'), sh, rim, gloss=.2); cor2 = cel_mat('coral2', hexc('#ff5fa8'), sh, rim, gloss=.2)
        for k, (sx, ln, m) in enumerate(((-.42, .8, cor), (-.15, 1.0, cor2), (.15, .95, cor), (.42, .75, cor2))):
            h = horn(top_h + mathutils.Vector((sx * .8, 0, -.05)), (sx, .1, 1), ln, .09, .15, 'coral'); parts.append(finish(h, m, ink, .022))
            br = horn(top_h + mathutils.Vector((sx * .8 + sx * .3, .03, ln * .45)), (sx * 1.6, 0, .8), ln * .4, .06, .05, 'branch'); parts.append(finish(br, m, ink, .02))
    elif c == 'crystal':
        cr = cel_mat('crystal', hexc('#ff8be0'), sh, rim, gloss=.9); cr2 = cel_mat('crystal2', hexc('#c8a6ff'), sh, rim, gloss=.9)
        for k, (sx, ln, tilt, m) in enumerate(((0, 1.0, 0, cr), (-.32, .7, -22, cr2), (.32, .72, 22, cr2), (-.58, .45, -38, cr), (.58, .45, 38, cr))):
            q = cone(top_h + mathutils.Vector((sx, .05, ln * .4)), .17 * ln + .04, 0, ln, (0, math.radians(tilt), 0), 'crystal', verts=6)
            q.data.polygons.foreach_set('use_smooth', [False] * len(q.data.polygons)); parts.append(finish(q, m, ink, .025, smooth=False))
    elif c == 'fire':
        gold = cel_mat('gold', hexc('#ffc93b'), sh, rim, gloss=.9); fl = cel_mat('flame', hexc('#ff6a1f'), sh, rim, gloss=0, emit=1.25)
        fl2 = cel_mat('flame2', hexc('#ffd23f'), sh, rim, gloss=0, emit=1.2)
        for sx in (-1, 1):
            h = horn(top_h + mathutils.Vector((.32 * sx, 0, -.05)), (.75 * sx, .45, .8), .95, .18, .55, 'horn'); parts.append(finish(h, gold, ink, .03))
        for k, (sx, ln, m) in enumerate(((0, .75, fl), (-.22, .5, fl2), (.22, .5, fl2))):
            f = cone(top_h + mathutils.Vector((sx, .02, ln * .4)), .2, 0, ln, (0, math.radians(sx * 50), 0), 'flame', verts=12); parts.append(finish(f, m, ink, .025))
    elif c == 'void':
        halo = cel_mat('halo', hexc('#52f2ff'), sh, rim, gloss=.5, emit=1.4)
        bpy.ops.mesh.primitive_torus_add(major_radius=.82, minor_radius=.09, major_segments=64, minor_segments=16,
                                         location=head_c + mathutils.Vector((0, .25, .95)), rotation=(math.radians(70), 0, 0))
        parts.append(finish(bpy.context.object, halo, ink, .025))
        star = cel_mat('star', hexc('#ffffff'), sh, rim, gloss=0, emit=1.5)
        import random; random.seed(7)
        for k in range(14):
            p = pts[random.randrange(len(pts))] + mathutils.Vector((random.uniform(-.2, .2), random.uniform(-.35, -.15), random.uniform(-.1, .2)))
            s = ell(p, (.035, .035, .035), 'star', seg=8); s.data.materials.append(star); parts.append(s)
    return g, parts

def render_set(gid):
    g, parts = build(gid); sc = bpy.context.scene
    root = bpy.data.objects.new('root', None); sc.collection.objects.link(root)
    for p in parts: p.parent = root
    # glb (outline modifiers off so the hull isn't baked in; Roblox draws its own outline or uses the flipbook)
    for p in parts:
        for m in p.modifiers: m.show_viewport = False
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(a.out, gid + '.glb'), use_selection=True, export_format='GLB', export_apply=True)
    for p in parts:
        for m in p.modifiers: m.show_viewport = True
    wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True; wd.node_tree.nodes['Background'].inputs[1].default_value = 0
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    bpy.context.view_layer.update()
    lo = mathutils.Vector((1e9,) * 3); hi = -lo
    for p in parts:
        for c in p.bound_box:
            w = p.matrix_world @ mathutils.Vector(c); lo = mathutils.Vector(map(min, lo, w)); hi = mathutils.Vector(map(max, hi, w))
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * 1.12
    tgt = (lo + hi) / 2; r = 12; el = math.radians(10)
    def aim(yaw):
        cam.location = tgt + mathutils.Vector((math.sin(yaw) * r * math.cos(el), -math.cos(yaw) * r * math.cos(el), r * math.sin(el)))
        cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = a.samples; sc.cycles.use_denoising = True
    sc.render.film_transparent = True; sc.render.resolution_x = sc.render.resolution_y = a.size
    sc.view_settings.view_transform = 'Standard'; sc.render.filter_size = 1.2
    aim(0); sc.render.filepath = os.path.join(a.out, gid + '_still.png'); bpy.ops.render.render(write_still=True)
    if a.still_only: return
    n = a.frames; cols = math.ceil(math.sqrt(n)); rows = math.ceil(n / cols); sheet = Image.new('RGBA', (cols * a.size, rows * a.size))
    for i in range(n):
        aim(math.radians(-40 + 80 * i / (n - 1))); f = os.path.join(a.out, f'_t{i:02d}.png'); sc.render.filepath = f; bpy.ops.render.render(write_still=True)
        sheet.paste(Image.open(f), ((i % cols) * a.size, (i // cols) * a.size)); os.remove(f)
    sheet.save(os.path.join(a.out, gid + '_look.png'))
    json.dump({'frames': n, 'cols': cols, 'size': a.size, 'yaw': [-40, 40], 'name': g['name']}, open(os.path.join(a.out, gid + '_look.json'), 'w'))

for gid in (G if a.which == 'all' else a.which.split(',')):
    render_set(gid); print('done', gid)
