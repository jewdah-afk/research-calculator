"""Shared helpers for the Peckwood icon scene: cel material, outline hull, primitives."""
import bpy, bmesh, math, colorsys
from mathutils import Vector

LIGHT = Vector((-0.55, -0.75, 0.85)).normalized()   # key light: upper-left, toward camera (camera looks +Y)
HULL = 0.035                                         # outline thickness in world units (icons fit a ~2u box)

def hx(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

def lin(c):  # sRGB -> linear for node colors
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def shade_of(c, k_l, hue_shift):
    h, l, s = colorsys.rgb_to_hls(*c)
    if s < 0.25 and k_l < 1:
        return tuple(x * 0.8 + t * 0.2 for x, t in zip(colorsys.hls_to_rgb(h, l * 0.8, s), (0.62, 0.6, 0.85)))
    return colorsys.hls_to_rgb((h + hue_shift) % 1, max(0, min(1, l * k_l)), min(1, s * 1.05))

def cel(name, base, stripe=None, stripe_freq=0.0, stripe_axis=0, rim=0.22, spec=True, alpha=1.0, stripe_w=0.0):
    """3-band cel emission shader: shadow (cooler, darker), base, highlight. Optional stripes."""
    if name in bpy.data.materials: return bpy.data.materials[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; N = nt.nodes; L = nt.links; N.clear()
    out = N.new('ShaderNodeOutputMaterial')
    geo = N.new('ShaderNodeNewGeometry')
    dot = N.new('ShaderNodeVectorMath'); dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = LIGHT
    L.new(geo.outputs['Normal'], dot.inputs[0])
    remap = N.new('ShaderNodeMapRange'); remap.inputs['From Min'].default_value = -1
    L.new(dot.outputs['Value'], remap.inputs['Value'])

    def ramp_for(col):
        r = N.new('ShaderNodeValToRGB'); r.color_ramp.interpolation = 'CONSTANT'
        e = r.color_ramp.elements
        sh = shade_of(col, 0.62, -0.03); hi = shade_of(col, 1.22, 0.015)
        e[0].position = 0.0; e[0].color = (*lin(sh), 1)
        e[1].position = 0.47; e[1].color = (*lin(col), 1)
        if spec:
            e3 = e.new(0.86); e3.color = (*lin(hi), 1)
        L.new(remap.outputs['Result'], r.inputs['Fac'])
        return r

    rA = ramp_for(hx(base) if isinstance(base, str) else base)
    color_out = rA.outputs['Color']
    if stripe:
        rB = ramp_for(hx(stripe))
        tc = N.new('ShaderNodeTexCoord')
        sep = N.new('ShaderNodeSeparateXYZ'); L.new(tc.outputs['Object'], sep.inputs[0])
        mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = stripe_freq
        L.new(sep.outputs[stripe_axis], mul.inputs[0])
        sn = N.new('ShaderNodeMath'); sn.operation = 'SINE'; L.new(mul.outputs[0], sn.inputs[0])
        gt = N.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = stripe_w
        L.new(sn.outputs[0], gt.inputs[0])
        mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'
        L.new(gt.outputs[0], mx.inputs['Factor']); L.new(rA.outputs['Color'], mx.inputs['A']); L.new(rB.outputs['Color'], mx.inputs['B'])
        color_out = mx.outputs['Result']
    # rim light: thin bright band on silhouette, only on the lit half
    lw = N.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.35
    rr = N.new('ShaderNodeValToRGB'); rr.color_ramp.interpolation = 'CONSTANT'
    rr.color_ramp.elements[0].color = (0, 0, 0, 1); rr.color_ramp.elements[1].position = 0.72
    rr.color_ramp.elements[1].color = (rim, rim, rim, 1)
    L.new(lw.outputs['Facing'], rr.inputs['Fac'])
    add = N.new('ShaderNodeMix'); add.data_type = 'RGBA'; add.blend_type = 'ADD'; add.inputs['Factor'].default_value = 1
    L.new(color_out, add.inputs['A']); L.new(rr.outputs['Color'], add.inputs['B'])
    em = N.new('ShaderNodeEmission'); L.new(add.outputs['Result'], em.inputs['Color'])
    if alpha < 1:
        tr = N.new('ShaderNodeBsdfTransparent'); ms = N.new('ShaderNodeMixShader')
        ms.inputs['Fac'].default_value = alpha
        L.new(tr.outputs[0], ms.inputs[1]); L.new(em.outputs[0], ms.inputs[2]); L.new(ms.outputs[0], out.inputs['Surface'])
    else:
        L.new(em.outputs[0], out.inputs['Surface'])
    return m

def ink(name, base):
    """Outline material for the inverted hull: tinted dark, only drawn on back faces."""
    key = 'ink_' + name
    if key in bpy.data.materials: return bpy.data.materials[key]
    c = hx(base) if isinstance(base, str) else base
    h, l, s = colorsys.rgb_to_hls(*c); d = colorsys.hls_to_rgb(h, 0.09, min(1, s * 0.7))
    m = bpy.data.materials.new(key); m.use_nodes = True
    N = m.node_tree.nodes; L = m.node_tree.links; N.clear()
    out = N.new('ShaderNodeOutputMaterial'); geo = N.new('ShaderNodeNewGeometry')
    em = N.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*lin(d), 1)
    tr = N.new('ShaderNodeBsdfTransparent'); mx = N.new('ShaderNodeMixShader')
    L.new(geo.outputs['Backfacing'], mx.inputs['Fac']); L.new(em.outputs[0], mx.inputs[1]); L.new(tr.outputs[0], mx.inputs[2])
    L.new(mx.outputs[0], out.inputs['Surface'])
    return m

def finish(ob, mat, outline=True, smooth=True, subdiv=0, bevel=0.0, hull=None):
    """Assign cel material, optional bevel/subdiv, and an outline hull (Solidify, flipped, ink slot)."""
    if ob.type == 'MESH' and tuple(ob.scale) != (1, 1, 1):   # bake scale so the hull stays a uniform width
        from mathutils import Matrix
        ob.data.transform(Matrix.Diagonal((*ob.scale, 1))); ob.scale = (1, 1, 1)
    if ob.type == 'MESH':                                    # outward normals so the hull grows outward
        bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(ob.data); bm.free()
    ob.data.materials.clear(); ob.data.materials.append(mat)
    if bevel:
        b = ob.modifiers.new('bevel', 'BEVEL'); b.width = bevel; b.segments = 3; b.limit_method = 'ANGLE'
    if subdiv:
        s = ob.modifiers.new('subd', 'SUBSURF'); s.levels = subdiv; s.render_levels = subdiv
    if smooth and ob.type == 'MESH':
        for p in ob.data.polygons: p.use_smooth = True
    if outline:
        base = mat.node_tree.nodes  # pull a base colour back from the first ramp
        col = [n for n in base if n.type == 'VALTORGB'][0].color_ramp.elements[1].color
        srgb = tuple((1.055 * x ** (1 / 2.4) - 0.055) if x > 0.0031308 else x * 12.92 for x in col[:3])
        ob.data.materials.append(ink(mat.name, srgb))
        so = ob.modifiers.new('outline', 'SOLIDIFY')
        so.thickness = hull if hull is not None else HULL
        so.offset = 1; so.use_flip_normals = True; so.use_rim = False
        so.material_offset = 1; so.use_even_offset = False
    return ob

# ---------- primitives (all return the new object, linked to the active collection) ----------
def _new(op, **kw):
    for o in bpy.context.selected_objects: o.select_set(False)
    op(**kw); return bpy.context.active_object

def sphere(loc=(0,0,0), scale=(1,1,1), seg=48, rings=24):
    o = _new(bpy.ops.mesh.primitive_uv_sphere_add, segments=seg, ring_count=rings, location=loc); o.scale = scale; return o
def ico(loc=(0,0,0), r=1, sub=3):
    return _new(bpy.ops.mesh.primitive_ico_sphere_add, subdivisions=sub, radius=r, location=loc)
def cyl(loc=(0,0,0), r=1, depth=1, verts=48, rot=(0,0,0), r2=None):
    if r2 is None:
        o = _new(bpy.ops.mesh.primitive_cylinder_add, vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        o = _new(bpy.ops.mesh.primitive_cone_add, vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return o
def cone(loc=(0,0,0), r=1, depth=1, verts=32, rot=(0,0,0)):
    return _new(bpy.ops.mesh.primitive_cone_add, vertices=verts, radius1=r, radius2=0, depth=depth, location=loc, rotation=rot)
def cube(loc=(0,0,0), scale=(1,1,1), rot=(0,0,0)):
    o = _new(bpy.ops.mesh.primitive_cube_add, size=2, location=loc, rotation=rot); o.scale = scale; return o
def torus(loc=(0,0,0), R=1, r=0.25, rot=(0,0,0), maj=64, mnr=24):
    return _new(bpy.ops.mesh.primitive_torus_add, major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=maj, minor_segments=mnr)

def puff(points, depth=0.18, bevel=0.14, loc=(0,0,0), rot=(math.pi/2, 0, 0), cyclic=True, smooth_pts=True):
    """Pillowy extruded 2D shape (heart, shield, star, feather). points are (x,y) in the XZ plane once rotated."""
    cu = bpy.data.curves.new('puff', 'CURVE'); cu.dimensions = '2D'; cu.fill_mode = 'BOTH'
    cu.extrude = depth; cu.bevel_depth = bevel; cu.bevel_resolution = 6; cu.resolution_u = 24
    sp = cu.splines.new('BEZIER' if smooth_pts else 'POLY')
    if smooth_pts:
        sp.bezier_points.add(len(points) - 1)
        for bp, p in zip(sp.bezier_points, points):
            bp.co = (p[0], p[1], 0); bp.handle_left_type = bp.handle_right_type = ('VECTOR' if len(p) > 2 else 'AUTO')
    else:
        sp.points.add(len(points) - 1)
        for p, q in zip(sp.points, points): p.co = (q[0], q[1], 0, 1)
    sp.use_cyclic_u = cyclic
    ob = bpy.data.objects.new('puff', cu); bpy.context.collection.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot
    for o in bpy.context.selected_objects: o.select_set(False)
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    bpy.ops.object.convert(target='MESH'); ob = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.002)
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob

def lump(ob, strength=0.12, scale=2.5, seed=0):
    """Noise displacement for organic shapes (rocks, kernels)."""
    tex = bpy.data.textures.new(f'n{seed}', 'CLOUDS'); tex.noise_scale = 1 / scale; tex.noise_depth = 1
    d = ob.modifiers.new('lump', 'DISPLACE'); d.texture = tex; d.strength = strength; d.mid_level = 0.5
    d.texture_coords = 'OBJECT' if False else 'LOCAL'
    return ob

def blobs(balls, res=0.04, thresh=0.6):
    """Metaball cluster -> mesh. balls: (x,y,z,radius[,(sx,sy,sz)])."""
    global _MB; _MB = globals().get('_MB', 0) + 1
    mb = bpy.data.metaballs.new(f'mb{_MB}x'); mb.resolution = res; mb.render_resolution = res; mb.threshold = thresh
    for b in balls:
        e = mb.elements.new(); e.co = b[:3]; e.radius = b[3]
        if len(b) > 4: e.type = 'ELLIPSOID'; e.size_x, e.size_y, e.size_z = b[4]
    ob = bpy.data.objects.new(f'mb{_MB}x', mb); bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects: o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.convert(target='MESH'); return bpy.context.active_object

def join(objs):
    for o in bpy.context.selected_objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join(); return objs[0]

def group(rot=(0,0,0), loc=(0,0,0)):
    """Parent everything in the active collection to an empty and rotate it (for 3/4 views)."""
    col = bpy.context.collection
    piv = bpy.data.objects.new('pivot', None); col.objects.link(piv)
    for o in list(col.objects):
        if o is not piv and o.parent is None: o.parent = piv
    piv.rotation_euler = rot; piv.location = loc
    return piv
