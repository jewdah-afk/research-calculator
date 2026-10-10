"""Snake Wars World stage scenery -> 3 parallax layers per World (Blender, no credits).
Each World is a small toy-brick diorama in the game's own look (studded road running into the distance, World props,
World sky), rendered from one camera as three separate layers so the cut-outs never leave holes:
  far  = sky + horizon (opaque, the full plate: nothing is cut out of it)
  mid  = the studded road, the gate wall and the World's props (transparent)
  fg   = big foreground props at the edges (transparent)
Usage: python3 scenery.py <world|all> <out_dir> [--w 1600] [--h 760] [--samples 24]"""
import sys, os, math, random, argparse
import bpy, mathutils

ap = argparse.ArgumentParser(); ap.add_argument('which'); ap.add_argument('out')
ap.add_argument('--w', type=int, default=1600); ap.add_argument('--h', type=int, default=760); ap.add_argument('--samples', type=int, default=24)
a = ap.parse_args(sys.argv[1:]); os.makedirs(a.out, exist_ok=True)

def C(h, k=1.0):
    h = h.lstrip('#'); return tuple(min(1, (int(h[i:i + 2], 16) / 255) ** 2.2 * k) for i in (0, 2, 4)) + (1,)

W = {
 'meadow':  dict(sky=('#7fd3ff', '#fff3c4'), ground='#7cc94a', ground2='#5aa83a', road='#e9cf98', stud='#f3dcab', edge=('#ffffff', '#3a9be0'),
                 sun='#fff2c0', sun_e=4.0, props='meadow', hill='#9bd66a', hill2='#6fbf4a', fog='#dff4ff'),
 'tidepool':dict(sky=('#5ee0ff', '#e9fffb'), ground='#2fd0d8', ground2='#1ab3c8', road='#f0dcae', stud='#f8e8c0', edge=('#ffffff', '#2a8fe0'),
                 sun='#fff6d8', sun_e=4.0, props='tide', hill='#f2dba8', hill2='#7fe6e0', fog='#d8fffb'),
 'crystal': dict(sky=('#2a1450', '#7a3fb0'), ground='#3a1f6a', ground2='#2a1450', road='#6b4bc4', stud='#8466dc', edge=('#c79bff', '#5a2aa0'),
                 sun='#ffb3f0', sun_e=1.6, props='crystal', hill='#4a2a86', hill2='#2f1a5e', fog='#5a2f90'),
 'frost':   dict(sky=('#a9dcff', '#f4fbff'), ground='#f4f9ff', ground2='#d6e9fb', road='#bcd8f4', stud='#d4e7fb', edge=('#ffffff', '#5aa0e0'),
                 sun='#ffffff', sun_e=3.6, props='frost', hill='#ffffff', hill2='#cfe3f7', fog='#e6f4ff'),
 'magma':   dict(sky=('#3a0f14', '#ff7a2a'), ground='#3a2622', ground2='#24161a', road='#5a3f36', stud='#6e4f44', edge=('#ffc93b', '#ff5a1f'),
                 sun='#ffb070', sun_e=2.2, props='magma', hill='#2a1618', hill2='#4a2620', fog='#a03a1c'),
 'void':    dict(sky=('#0a0620', '#3a1a7a'), ground='#1a0f3a', ground2='#100828', road='#2a1d5c', stud='#3a2a78', edge=('#ff4fd8', '#52f2ff'),
                 sun='#c8b0ff', sun_e=1.4, props='void', hill='#1c1040', hill2='#2a1660', fog='#3a1a7a'),
}

def mat(name, col, rough=.6, emit=None):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = col; b.inputs['Roughness'].default_value = rough
    if emit: b.inputs['Emission Color'].default_value = col; b.inputs['Emission Strength'].default_value = emit
    return m

def put(o, m, coll, flat=True):
    o.data.materials.clear(); o.data.materials.append(m)
    for c in o.users_collection: c.objects.unlink(o)
    coll.objects.link(o)
    if not flat:
        for p in o.data.polygons: p.use_smooth = True
    return o

def prim(kind, coll, m, loc, scale=(1, 1, 1), rot=(0, 0, 0), flat=True, **kw):
    getattr(bpy.ops.mesh, 'primitive_' + kind + '_add')(location=loc, rotation=rot, **kw)
    o = bpy.context.object; o.scale = scale; return put(o, m, coll, flat)

def build(wid):
    w = W[wid]; random.seed(hash(wid) & 0xffff)
    bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
    cols = {k: bpy.data.collections.new(k) for k in ('far', 'mid', 'fg')}
    for c in cols.values(): sc.collection.children.link(c)
    far, mid, fg = cols['far'], cols['mid'], cols['fg']
    # sky: gradient world + a big backdrop card so the far layer is fully opaque
    wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True; nt = wd.node_tree
    bg = nt.nodes['Background']; tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB'); nt.links.new(tc.outputs['Window'], sep.inputs[0]); nt.links.new(sep.outputs['Y'], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = C(w['sky'][1]); ramp.color_ramp.elements[0].position = .35
    ramp.color_ramp.elements[1].color = C(w['sky'][0]); nt.links.new(ramp.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 1.0
    sky_m = bpy.data.materials.new('sky'); sky_m.use_nodes = True; st = sky_m.node_tree; st.nodes.clear()
    tc2 = st.nodes.new('ShaderNodeTexCoord'); sp2 = st.nodes.new('ShaderNodeSeparateXYZ'); r2 = st.nodes.new('ShaderNodeValToRGB')
    em2 = st.nodes.new('ShaderNodeEmission'); o2 = st.nodes.new('ShaderNodeOutputMaterial')
    st.links.new(tc2.outputs['Window'], sp2.inputs[0]); st.links.new(sp2.outputs['Y'], r2.inputs[0])
    r2.color_ramp.elements[0].color = C(w['sky'][1]); r2.color_ramp.elements[0].position = .3; r2.color_ramp.elements[1].color = C(w['sky'][0])
    st.links.new(r2.outputs[0], em2.inputs[0]); st.links.new(em2.outputs[0], o2.inputs[0])
    prim('plane', far, sky_m, (0, 95, 20), (120, 1, 40), rot=(math.radians(90), 0, 0))
    # ground and far hills
    gm = mat('ground', C(w['ground'])); g2 = mat('ground2', C(w['ground2'])); hm = mat('hill', C(w['hill'])); h2 = mat('hill2', C(w['hill2']))
    prim('plane', far, g2, (0, 40, -0.02), (120, 120, 1))
    for i in range(14):
        x = random.uniform(-70, 70); s = random.uniform(10, 22)
        if abs(x) < 6: x += 12 * (1 if x >= 0 else -1)
        kind = 'cone' if wid in ('frost', 'magma', 'crystal') else 'uv_sphere'
        if kind == 'cone':
            o = prim('cone', far, hm if i % 2 else h2, (x, random.uniform(60, 85), s * .45), (s * .6, s * .6, s * .9), vertices=7)
            if wid == 'frost':                                            # snow cap
                prim('cone', far, mat('snow', C('#ffffff')), (x, o.location.y - .3, s * .45 + s * .9 * .45), (s * .33, s * .33, s * .5), vertices=7)
            if wid == 'magma' and i % 4 == 0:                             # volcano glow
                prim('uv_sphere', far, mat('lavaglow', C('#ff6a1f'), emit=6), (x, o.location.y, s * .45 + s * .85), (s * .1, s * .1, s * .05), segments=12, ring_count=6)
        else:
            prim('uv_sphere', far, hm if i % 2 else h2, (x, random.uniform(55, 85), -s * .25), (s, s * .7, s * .6), segments=14, ring_count=8)
    sun = prim('uv_sphere', far, mat('sun', C(w['sun']), emit=w['sun_e']), (-22, 90, 24), (5, 5, 5), segments=24, ring_count=12, flat=False)
    if wid == 'tidepool':
        prim('plane', far, mat('sea', C('#22c6e0'), rough=.15), (0, 40, 0.0), (120, 120, 1))
    if wid in ('void', 'crystal'):
        sm = mat('star', C('#ffffff'), emit=6)
        for i in range(90 if wid == 'void' else 30):
            prim('ico_sphere', far, sm, (random.uniform(-90, 90), 92, random.uniform(2, 50)), (.15, .15, .15), subdivisions=1)
    # mid: studded road running away from the camera, edge kerbs, a gate wall in the distance
    rm = mat('road', C(w['road'])); sm_ = mat('stud', C(w['stud']), rough=.35)
    road = prim('cube', mid, rm, (0, 30, -.25), (3.2, 40, .25))
    stud = prim('cylinder', mid, sm_, (-2.9, -9.6, .06), (.2, .2, .07), vertices=12, flat=False)
    ar = stud.modifiers.new('a', 'ARRAY'); ar.count = 12; ar.relative_offset_displace = (2.6, 0, 0)
    ar2 = stud.modifiers.new('b', 'ARRAY'); ar2.count = 75; ar2.relative_offset_displace = (0, 2.7, 0)
    e1, e2 = mat('edge1', C(w['edge'][0])), mat('edge2', C(w['edge'][1]))
    for side in (-1, 1):
        for k in range(40):
            prim('cube', mid, e1 if k % 2 else e2, (side * 3.45, -9 + k * 2, .05), (.25, 1, .3))
    if wid == 'tidepool':
        pass
    # ground beside the road (mid, so props stand on something), gate wall near the horizon
    for side in (-1, 1):
        prim('cube', mid, gm, (side * 14, 30, -.3), (10.3, 40, .3))
    gate_m = mat('gate', C('#ffb347'), rough=.4); gate2 = mat('gate2', C('#ffffff'))
    for side in (-1, 1):
        prim('cube', mid, gate2, (side * 4.2, 34, 1.6), (.7, .7, 1.9))
        prim('cube', mid, gate_m, (side * 4.2, 34, 3.7), (.85, .85, .25))
    prim('cube', mid, mat('wall', C(w['edge'][1]), rough=.3), (0, 34.2, 1.4), (3.4, .2, 1.4))
    # props
    P = w['props']
    def tree(coll, x, y, s):
        prim('cylinder', coll, mat('trunk', C('#8a5a34')), (x, y, s * .6), (s * .18, s * .18, s * .6), vertices=8)
        prim('ico_sphere', coll, mat('leaf', C(random.choice(['#69c43c', '#7fd34b', '#5ab532']))), (x, y, s * 1.6), (s * .75, s * .75, s * .7), subdivisions=1)
    def pine(coll, x, y, s, snow=False):
        prim('cylinder', coll, mat('trunk', C('#6b4428')), (x, y, s * .3), (s * .12, s * .12, s * .3), vertices=6)
        for k in range(3):
            prim('cone', coll, mat('pine', C('#2f7a5a')), (x, y, s * (.8 + k * .55)), (s * (.7 - k * .17),) * 2 + (s * .5,), vertices=7)
            if snow: prim('cone', coll, mat('snow', C('#ffffff')), (x, y, s * (1.05 + k * .55)), (s * (.38 - k * .1),) * 2 + (s * .26,), vertices=7)
    def crystal(coll, x, y, s, col):
        m = mat('cr', C(col), rough=.15, emit=1.2)
        for k in range(3):
            prim('cone', coll, m, (x + random.uniform(-.4, .4) * s, y, s * .7), (s * .3, s * .3, s * random.uniform(.8, 1.4)),
                 rot=(0, random.uniform(-.4, .4), 0), vertices=6)
    def rock(coll, x, y, s, col):
        prim('ico_sphere', coll, mat('rock', C(col)), (x, y, s * .3), (s, s * .8, s * .6), subdivisions=1)
    for side in (-1, 1):
        for k in range(9):
            x = side * random.uniform(5.5, 16); y = random.uniform(2, 45); s = random.uniform(1.2, 2.4)
            if P == 'meadow': tree(mid, x, y, s)
            elif P == 'frost': pine(mid, x, y, s * 1.2, snow=True)
            elif P == 'crystal': crystal(mid, x, y, s, random.choice(['#ff8be0', '#b98bff', '#7fe8ff']))
            elif P == 'tide': rock(mid, x, y, s * .7, random.choice(['#c9b48a', '#9fd6e0'])) if k % 2 else crystal(mid, x, y, s * .7, random.choice(['#ff7a5c', '#ff5fa8']))
            elif P == 'magma': rock(mid, x, y, s * .8, '#3a2622')
            elif P == 'void': prim('cube', mid, mat('ob', C('#2a1d5c'), rough=.2), (x, y, random.uniform(1, 6)), (s, s, .3), rot=(0, 0, random.uniform(0, 1)))
        if P == 'magma':      # lava rivers beside the causeway
            prim('cube', mid, mat('lava', C('#ff6a1f'), emit=4), (side * 5.3, 30, -.15), (1.4, 40, .1))
        if P == 'meadow':
            for k in range(30):
                prim('ico_sphere', mid, mat('fl', C(random.choice(['#ffffff', '#ff9fd0', '#ffe066']))), (side * random.uniform(4.2, 12), random.uniform(-6, 30), .1), (.15, .15, .1), subdivisions=1)
        if P == 'void':
            prim('torus', mid, mat('ring', C(random.choice(['#ff4fd8', '#52f2ff'])), emit=5), (side * 7, 20, 5), (1, 1, 1), rot=(math.radians(90), 0, 0), major_radius=2.2, minor_radius=.12)
    # fg: big props hugging the frame edges
    for side in (-1, 1):
        x = side * random.uniform(5.2, 6.5); y = random.uniform(-4, -1)
        if P == 'meadow': tree(fg, x, y, 3.0)
        elif P == 'frost': pine(fg, x, y, 3.2, snow=True)
        elif P == 'crystal': crystal(fg, x, y, 2.4, '#ff8be0')
        elif P == 'tide': crystal(fg, x, y, 1.8, '#ff7a5c'); rock(fg, x - side * 1.2, y - 1, 1.3, '#d8c08e')
        elif P == 'magma': rock(fg, x, y, 2.2, '#24161a'); prim('cone', fg, mat('fire', C('#ffb020'), emit=5), (x, y, 2.4), (.6, .6, 1.2), vertices=8)
        elif P == 'void': prim('cube', fg, mat('ob', C('#1c1240'), rough=.2), (x, y, 1.2), (2.2, 2.2, .35), rot=(0, 0, .5))
    # lighting + camera
    sl = bpy.data.lights.new('sun', 'SUN'); sl.energy = 3.2 if wid not in ('crystal', 'void', 'magma') else 1.4; sl.angle = math.radians(8)
    so = bpy.data.objects.new('sun', sl); so.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(so)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 28; cam.location = (0, -15, 6.2); cam.rotation_euler = (math.radians(78), 0, 0)
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = a.samples; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = a.w, a.h; sc.view_settings.view_transform = 'Standard'
    # mist so far things sit back
    sc.view_layers[0].use_pass_mist = False
    return cols

def render_layers(wid):
    cols = build(wid); sc = bpy.context.scene; vl = sc.view_layers[0]
    for layer in ('far', 'mid', 'fg'):
        for k, c in cols.items():
            lc = vl.layer_collection.children[k]
            lc.exclude = False
            lc.holdout = False
            # the mid layer is held out by fg (fg sits in front), far is drawn without mid/fg so it is complete
            if layer == 'far': lc.exclude = (k != 'far')
            elif layer == 'mid': lc.exclude = (k == 'fg'); lc.holdout = (k == 'far')
            else: lc.holdout = (k != 'fg')
        sc.render.film_transparent = layer != 'far'
        sc.render.filepath = os.path.join(a.out, f'{wid}_{layer}.png'); bpy.ops.render.render(write_still=True)

for wid in (W if a.which == 'all' else a.which.split(',')):
    render_layers(wid); print('done', wid)
