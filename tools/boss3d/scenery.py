"""Snake Wars World stage scenery -> 3 parallax layers per World (Blender, no credits).
Each World is a small toy-brick diorama in the game's own cel look (studded corridor running into the distance, World
props, World sky), rendered from one camera as three separate layers so the cut-outs never leave holes:
  far  = sky + horizon (opaque, the full plate: nothing is cut out of it)
  mid  = the studded corridor, the gate and the World's props (transparent)
  fg   = big foreground props at the frame edges (transparent)
Shading = the guardian.py cel recipe (emission-only: colour x light/mid/shadow band from a fixed key) + the same
inverted-hull ink outline, so the stages match the 3D guardians that stand on them.
Palettes: WORLDS_ART.md sections 2-7 (Worlds 1-5 + the Void Climb), EGGS.md 4.8-4.9 (Starfall, Core); Candy Canyon has no
palette yet, so its colours here are a PLACEHOLDER.
Also writes <world>_stage.json: where the guardian's feet land (floor) and the horizon, as fractions of the frame.
Usage: blender -b --factory-startup --python scenery.py -- <world|all> <out_dir> [--w 1600] [--h 720] [--samples 12]
       (or python3 scenery.py ... with the bpy module installed)"""
import sys, os, math, random, argparse, json
import bpy, mathutils
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser(); ap.add_argument('which'); ap.add_argument('out')
ap.add_argument('--w', type=int, default=1600); ap.add_argument('--h', type=int, default=720)
ap.add_argument('--samples', type=int, default=12); ap.add_argument('--threads', type=int, default=8)
a = ap.parse_args(argv); os.makedirs(a.out, exist_ok=True)

def C(h, k=1.0):
    h = h.lstrip('#'); return tuple(min(1, (int(h[i:i + 2], 16) / 255) ** 2.2 * k) for i in (0, 2, 4)) + (1,)

# floor A/B, studs, curbs A/B, ground beside the corridor, sky top/horizon, gate pylon bricks, props
W = {
 'meadow':   dict(floor=('#F2CF8C', '#E8BE74'), stud='#F7DA9F', curb=('#FFFFFF', '#7FC44A'), ground=('#86BF57', '#9BCB66'),
                  sky=('#5EB8F0', '#CFEFFF'), bricks=('#FFD84A', '#4FB0F0', '#FFFFFF'), hill=('#7FC24E', '#95CF62'), props='meadow'),
 'tidepool': dict(floor=('#F4B9C4', '#EAA6B3'), stud='#F8C9D2', curb=('#FFFFFF', '#2E9BD6'), ground=('#F6C9D1', '#FBE0E5'),
                  sky=('#4FC3EE', '#E4FBFF'), bricks=('#FFFFFF', '#2E9BD6', '#8D9CA6'), hill=('#F6C9D1', '#FBE0E5'), props='tide', sea=('#16A9B8', '#38D3CF')),
 'crystal':  dict(floor=('#6A58A0', '#5C4B8E'), stud='#7F6DB8', curb=('#3A2F55', '#C9A7FF'), ground=('#2B2140', '#3A2F55'),
                  sky=('#120C22', '#3A2F55'), bricks=('#3A2F55', '#C9A7FF', '#251B3A'), hill=('#251B3A', '#2E2348'), props='crystal'),
 'frost':    dict(floor=('#CFE2F5', '#BCD3EC'), stud='#DDEBF9', curb=('#FFFFFF', '#7FC6F0'), ground=('#E6EEF7', '#F7FAFD'),
                  sky=('#8EC9F5', '#F0F8FF'), bricks=('#DFF7FF', '#9FDDFF', '#FFFFFF'), hill=('#A9C3E0', '#BCD3EC'), props='frost'),
 'magma':    dict(floor=('#6A5A5A', '#5B4D4E'), stud='#7B6A6A', curb=('#3A3033', '#2A2327'), ground=('#3A3033', '#4A3E3E'),
                  sky=('#C8603A', '#FFD9B0'), bricks=('#3A3033', '#4A3E3E', '#2A2327'), hill=('#3A2C2C', '#4A3838'), props='magma'),
 # Void Climb (WORLDS_ART 7): graphite bands, black glass, white neon grid, rails in the tier colour (Azure tier shown).
 # No stars, no nebula, no violet, no teal.
 'void':     dict(floor=('#1C1E25', '#17191F'), stud='#2A2D36', curb=('#0E0F14', '#0E0F14'), ground=None,
                  sky=('#050608', '#1A1C24'), bricks=('#14161C', '#14161C', '#14161C'), hill=None, props='void',
                  glass='#0E0F14', grid='#E8F0FF', tier='#4FA8FF'),
 # post-launch Worlds 6-8 (dim "coming soon" stages)
 'candy':    dict(floor=('#FFB8DA', '#FFA6CF'), stud='#FFCDE5', curb=('#FFFFFF', '#FF5FA8'), ground=('#A8F0D4', '#C2F7E2'),
                  sky=('#FF9ED2', '#FFF0F8'), bricks=('#FF5FA8', '#FFFFFF', '#7FE0C0'), hill=('#F7D2A8', '#FFC2D8'), props='candy'),
 'starfall': dict(floor=('#1E2A6E', '#18225C'), stud='#2C3A86', curb=('#FFFFFF', '#7B5CFF'), ground=('#121A4A', '#1A2360'),
                  sky=('#050A26', '#2A2070'), bricks=('#2C3A86', '#9AA3C7', '#121A4A'), hill=('#141C50', '#1C2462'), props='starfall'),
 'core':     dict(floor=('#FFF4DC', '#F3E6C6'), stud='#FFFAEE', curb=('#FFFFFF', '#FFC437'), ground=('#F7E9C9', '#FFF4DC'),
                  sky=('#FFB866', '#FFF1D6'), bricks=('#FFFFFF', '#FFC437', '#E7D8B8'), hill=('#F2DFB4', '#FFE9C0'), props='core'),
}

KEY = mathutils.Vector((-.45, -.6, .66)).normalized()
_mats = {}

def cel(hexcol, emit=None):
    """Emission-only cel shader (guardian.py recipe): colour x (shadow | mid | light) band from a fixed key."""
    k = (hexcol, emit)
    if k in _mats: return _mats[k]
    m = bpy.data.materials.new(f'cel{len(_mats)}'); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear(); N = nt.nodes.new; L = nt.links.new
    out = N('ShaderNodeOutputMaterial'); em = N('ShaderNodeEmission'); col = C(hexcol)
    if emit:
        em.inputs['Color'].default_value = col; em.inputs['Strength'].default_value = emit
    else:
        geo = N('ShaderNodeNewGeometry'); kd = N('ShaderNodeCombineXYZ')
        kd.inputs[0].default_value, kd.inputs[1].default_value, kd.inputs[2].default_value = KEY
        dot = N('ShaderNodeVectorMath'); dot.operation = 'DOT_PRODUCT'; L(geo.outputs['Normal'], dot.inputs[0]); L(kd.outputs[0], dot.inputs[1])
        mr = N('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = -1; L(dot.outputs['Value'], mr.inputs['Value'])
        band = N('ShaderNodeValToRGB'); band.color_ramp.interpolation = 'CONSTANT'; e = band.color_ramp.elements
        e[0].position = 0; e[0].color = (.6, .62, .76, 1); e[1].position = .42; e[1].color = (.84, .85, .9, 1); e.new(.66).color = (1, 1, 1, 1)
        L(mr.outputs[0], band.inputs[0])
        rgb = N('ShaderNodeRGB'); rgb.outputs[0].default_value = col
        mul = N('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
        L(rgb.outputs[0], mul.inputs[6]); L(band.outputs['Color'], mul.inputs[7]); L(mul.outputs[2], em.inputs['Color'])
    L(em.outputs[0], out.inputs['Surface']); _mats[k] = m; return m

def ink_mat():
    m = bpy.data.materials.new('ink'); m.use_nodes = True; it = m.node_tree; it.nodes.clear(); N = it.nodes.new; L = it.links.new
    out = N('ShaderNodeOutputMaterial'); geo = N('ShaderNodeNewGeometry'); mix = N('ShaderNodeMixShader')
    em = N('ShaderNodeEmission'); em.inputs['Color'].default_value = (.004, .005, .01, 1); tr = N('ShaderNodeBsdfTransparent')
    L(geo.outputs['Backfacing'], mix.inputs['Fac']); L(em.outputs[0], mix.inputs[1]); L(tr.outputs[0], mix.inputs[2])
    lp = N('ShaderNodeLightPath'); m2 = N('ShaderNodeMixShader'); t2 = N('ShaderNodeBsdfTransparent')
    L(lp.outputs['Is Camera Ray'], m2.inputs['Fac']); L(t2.outputs[0], m2.inputs[1]); L(mix.outputs[0], m2.inputs[2]); L(m2.outputs[0], out.inputs['Surface'])
    return m

INK = None

def prim(kind, coll, col, loc, scale=(1, 1, 1), rot=(0, 0, 0), ink=.05, emit=None, smooth=False, **kw):
    """Add a primitive in `coll`, bake its scale (so the ink hull is even), give it a cel material + ink hull."""
    getattr(bpy.ops.mesh, 'primitive_' + kind + '_add')(location=loc, rotation=rot, **kw)
    o = bpy.context.object; o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for c in list(o.users_collection): c.objects.unlink(o)
    coll.objects.link(o)
    o.data.materials.append(cel(col, emit) if isinstance(col, str) else col)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    if ink:
        o.data.materials.append(INK)
        s = o.modifiers.new('ink', 'SOLIDIFY'); s.thickness = ink; s.offset = 1; s.use_flip_normals = True; s.use_rim = False; s.material_offset = 1
    return o

def sky_card(coll, top, horizon, y=110):
    """A huge emissive card with a screen-space vertical gradient (so the far layer is fully opaque)."""
    m = bpy.data.materials.new('sky'); m.use_nodes = True; st = m.node_tree; st.nodes.clear(); N = st.nodes.new; L = st.links.new
    tc = N('ShaderNodeTexCoord'); sp = N('ShaderNodeSeparateXYZ'); r = N('ShaderNodeValToRGB'); em = N('ShaderNodeEmission'); o = N('ShaderNodeOutputMaterial')
    L(tc.outputs['Window'], sp.inputs[0]); L(sp.outputs['Y'], r.inputs[0])
    r.color_ramp.elements[0].color = C(horizon); r.color_ramp.elements[0].position = .52; r.color_ramp.elements[1].color = C(top)
    L(r.outputs[0], em.inputs[0]); L(em.outputs[0], o.inputs[0])
    bpy.ops.mesh.primitive_plane_add(location=(0, y, 10), rotation=(math.radians(90), 0, 0)); p = bpy.context.object
    p.scale = (200, 80, 1); p.data.materials.append(m)
    for c in list(p.users_collection): c.objects.unlink(p)
    coll.objects.link(p); return p

# ------------------------------------------------------------------ props (all toy-scale, faceted, ink-outlined)
def lolli_tree(c, x, y, s, w):
    prim('cylinder', c, '#9C6A3C', (x, y, s * .55), (s * .16, s * .16, s * .55), vertices=8, ink=.04 * s)
    prim('ico_sphere', c, random.choice(['#5DAE45', '#78C152', '#4C9A40', '#6CB84B']), (x, y, s * 1.45), (s * .78, s * .78, s * .7), subdivisions=1, ink=.05 * s)
    if random.random() < .5:
        for k in range(3):
            a = random.uniform(0, 6.28); prim('ico_sphere', c, '#FF9EC8', (x + math.cos(a) * s * .55, y - s * .5, s * (1.3 + random.uniform(0, .5))), (s * .12,) * 3, subdivisions=1, ink=.02 * s)

def bush(c, x, y, s):
    for dx in (-.5, 0, .5):
        prim('ico_sphere', c, random.choice(['#5DAE45', '#6CB84B']), (x + dx * s, y, s * (.35 + (dx == 0) * .15)), (s * .5, s * .45, s * .42), subdivisions=1, ink=.04 * s)

def sprout(c, x, y, s):
    prim('cylinder', c, '#4E9A3A', (x, y, s * .45), (s * .07, s * .07, s * .45), vertices=6, ink=.03 * s)
    for sx in (-1, 1):
        prim('uv_sphere', c, '#6EE06A', (x + sx * s * .32, y, s * .95), (s * .38, s * .14, s * .2), rot=(0, sx * -.4, 0), segments=10, ring_count=6, ink=.03 * s)

def mushroom(c, x, y, s, caps):
    prim('cylinder', c, '#FFF6E6', (x, y, s * .25), (s * .12, s * .12, s * .25), vertices=8, ink=.03 * s)
    prim('uv_sphere', c, random.choice(caps), (x, y, s * .5), (s * .36, s * .36, s * .22), segments=10, ring_count=6, ink=.035 * s)

def pine(c, x, y, s, snow=True):
    prim('cylinder', c, '#6B4A35', (x, y, s * .3), (s * .12, s * .12, s * .3), vertices=6, ink=.03 * s)
    for k in range(3):
        prim('cone', c, random.choice(['#2F7A5E', '#378A68']), (x, y, s * (.75 + k * .5)), (s * (.72 - k * .17),) * 2 + (s * .5,), vertices=7, ink=.04 * s)
        if snow: prim('cone', c, '#F7FBFF', (x, y, s * (1.02 + k * .5)), (s * (.36 - k * .09),) * 2 + (s * .24,), vertices=7, ink=.025 * s)

def snowman(c, x, y, s):
    for k, r in enumerate((.5, .36, .26)):
        prim('ico_sphere', c, '#F7FBFF', (x, y, s * (.45 + k * .62)), (s * r,) * 3, subdivisions=2, ink=.03 * s)
    prim('cylinder', c, '#3F7FE0', (x, y, s * .92), (s * .3, s * .3, s * .07), vertices=10, ink=.02 * s)
    prim('cone', c, '#FF9A2E', (x, y - s * .28, s * 1.7), (s * .05, s * .05, s * .14), rot=(math.radians(90), 0, 0), vertices=6, ink=.01 * s)

def ice_block(c, x, y, s):
    prim('cube', c, random.choice(['#BFEFFF', '#9FDDFF', '#DFF7FF']), (x, y, s * .45), (s * .55, s * .5, s * .45), rot=(0, 0, random.uniform(-.5, .5)), ink=.04 * s)

def crystal(c, x, y, s, cols, emit=None):
    for k in range(3):
        col = random.choice(cols)
        prim('cone', c, col, (x + random.uniform(-.4, .4) * s, y + random.uniform(-.2, .2) * s, s * .55), (s * .26, s * .26, s * random.uniform(.6, 1.15)),
             rot=(random.uniform(-.25, .25), random.uniform(-.45, .45), 0), vertices=6, ink=.035 * s, emit=emit)

def rock(c, x, y, s, col):
    prim('ico_sphere', c, col, (x, y, s * .28), (s, s * .8, s * .6), rot=(0, 0, random.uniform(0, 3)), subdivisions=1, ink=.045 * s)

def coral(c, x, y, s):
    col = random.choice(['#FF7F66', '#F7A6C9', '#9B7BFF', '#FFC36B'])
    for k in range(4):
        a = k * 1.6 + random.uniform(0, .5)
        prim('cylinder', c, col, (x + math.cos(a) * s * .25, y + math.sin(a) * s * .2, s * .45), (s * .1, s * .1, s * .45), rot=(math.cos(a) * .4, math.sin(a) * .4, 0), vertices=6, ink=.03 * s)
        prim('ico_sphere', c, col, (x + math.cos(a) * s * .45, y + math.sin(a) * s * .35, s * .9), (s * .14,) * 3, subdivisions=1, ink=.025 * s)

def palm(c, x, y, s):
    for k in range(5):
        prim('cylinder', c, '#B98A5A', (x + k * s * .08, y, s * (.3 + k * .55)), (s * .15, s * .15, s * .3), rot=(0, .14, 0), vertices=7, ink=.03 * s)
    top = (x + 5 * s * .08, y, s * 2.9)
    for k in range(6):
        a = k / 6 * 6.28
        prim('uv_sphere', c, '#3FAE5A', (top[0] + math.cos(a) * s * .55, top[1] + math.sin(a) * s * .55, top[2] - s * .15), (s * .62, s * .16, s * .06),
             rot=(0, .35, a), segments=8, ring_count=4, ink=.03 * s)

def umbrella(c, x, y, s):
    prim('cylinder', c, '#FFFFFF', (x, y, s * .7), (s * .04, s * .04, s * .7), vertices=6, ink=.02 * s)
    prim('cone', c, random.choice(['#FF5FA8', '#FFC36B', '#2E9BD6']), (x, y, s * 1.45), (s * .75, s * .75, s * .25), vertices=10, ink=.03 * s)

def basalt(c, x, y, s):
    for k in range(3):
        h = s * random.uniform(.5, 1.3)
        prim('cylinder', c, random.choice(['#3A3033', '#2A2327', '#4A3E3E']), (x + (k - 1) * s * .42, y + random.uniform(-.2, .2) * s, h / 2), (s * .24, s * .24, h / 2), vertices=6, ink=.035 * s)

def lollipop(c, x, y, s):
    prim('cylinder', c, '#FFFFFF', (x, y, s * .8), (s * .05, s * .05, s * .8), vertices=6, ink=.02 * s)
    col = random.choice(['#FF5FA8', '#7FE0C0', '#FFC36B', '#B58CFF'])
    prim('cylinder', c, col, (x, y, s * 1.8), (s * .5, s * .5, s * .1), rot=(math.radians(90), 0, 0), vertices=16, ink=.035 * s)
    prim('cylinder', c, '#FFFFFF', (x, y - s * .11, s * 1.8), (s * .22, s * .22, s * .02), rot=(math.radians(90), 0, 0), vertices=12, ink=0)

def gumdrop(c, x, y, s):
    prim('uv_sphere', c, random.choice(['#FF5FA8', '#7FE0C0', '#FFC36B', '#B58CFF', '#5EC8FF']), (x, y, s * .3), (s * .45, s * .45, s * .5), segments=10, ring_count=6, ink=.035 * s)

def cane(c, x, y, s):
    for k in range(6):
        prim('cylinder', c, '#FFFFFF' if k % 2 else '#FF4F7A', (x, y, s * (.18 + k * .36)), (s * .12, s * .12, s * .18), vertices=8, ink=.025 * s)
    prim('torus', c, '#FF4F7A', (x + s * .32, y, s * 2.1), (1, 1, 1), rot=(math.radians(90), 0, 0), major_radius=s * .32, minor_radius=s * .12, major_segments=10, minor_segments=6, ink=.025 * s)

def moonrock(c, x, y, s, z=None):
    prim('ico_sphere', c, random.choice(['#9AA3C7', '#7E88B0']), (x, y, z if z is not None else s * .4), (s * .6, s * .55, s * .45), rot=(0, 0, random.uniform(0, 3)), subdivisions=1, ink=.04 * s)

def star_shard(c, x, y, s, z):
    prim('ico_sphere', c, random.choice(['#FFFFFF', '#3FE0D0', '#FFD66B']), (x, y, z), (s * .18, s * .18, s * .32), subdivisions=0, ink=.02 * s, emit=2.0)

def column(c, x, y, s):
    prim('cube', c, '#FFFFFF', (x, y, s * .12), (s * .5, s * .5, s * .12), ink=.03 * s)
    prim('cylinder', c, '#FFF6E6', (x, y, s * 1.3), (s * .3, s * .3, s * 1.1), vertices=10, ink=.035 * s)
    prim('cube', c, '#FFC437', (x, y, s * 2.48), (s * .46, s * .46, s * .1), ink=.03 * s)
    if random.random() < .5: prim('ico_sphere', c, '#FFC437', (x, y, s * 2.85), (s * .26,) * 3, subdivisions=2, ink=.025 * s)

def glitch_cube(c, x, y, z, s, tier):
    prim('cube', c, '#14161C', (x, y, z), (s, s, s), rot=(random.uniform(0, .6), random.uniform(0, .6), random.uniform(0, .6)), ink=.04 * s)
    prim('cube', c, tier, (x, y - s * 1.02, z), (s * .4, s * .02, s * .4), ink=0, emit=3)

# ------------------------------------------------------------------ the diorama
def build(wid):
    global INK, _mats
    w = W[wid]; random.seed(sum(map(ord, wid)) * 7)
    bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene; _mats = {}; INK = ink_mat()
    cols = {k: bpy.data.collections.new(k) for k in ('far', 'mid', 'fg')}
    for c in cols.values(): sc.collection.children.link(c)
    far, mid, fg = cols['far'], cols['mid'], cols['fg']
    wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True; wd.node_tree.nodes['Background'].inputs[0].default_value = C(w['sky'][1])
    sky_card(far, *w['sky'])
    P = w['props']; void = P == 'void'

    # far: ground plate, hills/peaks, sky dressing
    if not void:
        prim('plane', far, w['ground'][0], (0, 45, -.04), (160, 70, 1), ink=0)
    if P == 'tide':
        prim('plane', far, w['sea'][0], (0, 60, -.02), (160, 50, 1), ink=0)
        for i in range(10):     # ripple bands
            prim('cube', far, w['sea'][1], (random.uniform(-60, 60), random.uniform(25, 90), 0), (random.uniform(3, 8), .25, .01), ink=0)
    for i in range(16):
        x = random.uniform(-80, 80); s = random.uniform(9, 20)
        if abs(x) < 8: x += 14 * (1 if x >= 0 else -1)
        yy = random.uniform(62, 92)
        if P in ('frost', 'magma', 'crystal'):
            prim('cone', far, w['hill'][i % 2], (x, yy, s * .45), (s * .65, s * .6, s * .95), vertices=7, ink=.25)
            if P == 'frost': prim('cone', far, '#FFFFFF', (x, yy - .4, s * .45 + s * .95 * .52), (s * .3, s * .28, s * .45), vertices=7, ink=.18)
            if P == 'magma' and i % 3 == 0: prim('cylinder', far, '#FFB938', (x, yy - .2, s * .45 + s * .9), (s * .14, s * .14, .25), vertices=10, ink=.12, emit=4)
            if P == 'crystal' and i % 2 == 0: crystal(far, x * .9, yy - 6, s * .45, ['#FF7AD9', '#C9A7FF', '#7FE8FF'], emit=1.4)
        elif P in ('meadow', 'tide', 'candy', 'core'):
            if P == 'tide' and i % 2: continue
            prim('uv_sphere', far, w['hill'][i % 2], (x, yy, -s * .2), (s, s * .7, s * .55 if P != 'candy' else s * .9), segments=14, ring_count=8, ink=.22)
            if P == 'candy':
                prim('cylinder', far, '#FFC2D8', (x, yy - .5, s * .2), (s * .82, s * .6, .6), vertices=14, ink=.1)
        elif P == 'starfall':
            moonrock(far, x, yy, s * .5, z=random.uniform(4, 16))
    if P in ('meadow', 'tide', 'frost', 'candy'):     # chunky toy clouds
        for i in range(6):
            cx, cz = random.uniform(-55, 55), random.uniform(14, 26)
            for k in range(4):
                prim('ico_sphere', far, '#FFFFFF', (cx + (k - 1.5) * 2.4, 96, cz + (k % 2) * 1.1), (2.4, 1.6, 1.7), subdivisions=2, ink=.18)
    if P == 'magma':
        for i in range(5):    # smoke puffs
            cx, cz = random.uniform(-60, 60), random.uniform(18, 30)
            for k in range(3):
                prim('ico_sphere', far, '#8A5A4A', (cx + (k - 1) * 3, 96, cz + (k % 2) * 1.4), (3, 2, 2), subdivisions=2, ink=.18)
    if P == 'starfall':       # Starfall owns the stars (EGGS 4.8); the Void does not
        for i in range(70):
            prim('ico_sphere', far, random.choice(['#FFFFFF', '#FFFFFF', '#3FE0D0', '#FFD66B']), (random.uniform(-100, 100), 100, random.uniform(3, 46)), (.22,) * 3, subdivisions=0, ink=0, emit=3)
        for i in range(4):
            prim('torus', far, '#FFD66B', (random.uniform(-50, 50), 90, random.uniform(14, 28)), (1, 1, 1), rot=(math.radians(70), .3, 0), major_radius=4, minor_radius=.25, ink=.1)
    if P == 'core':           # the sun medallion (no crown shapes)
        prim('cylinder', far, '#FFC437', (-24, 98, 22), (5, 5, .4), rot=(math.radians(90), 0, 0), vertices=24, ink=.2, emit=1.2)
        prim('cylinder', far, '#FFF6D8', (-24, 97.5, 22), (2.2, 2.2, .4), rot=(math.radians(90), 0, 0), vertices=20, ink=0, emit=2)
        for k in range(12):
            ang = k / 12 * 6.283
            prim('cone', far, '#FFC437', (-24 + math.cos(ang) * 6.8, 98, 22 + math.sin(ang) * 6.8), (1, 1, 1.4), rot=(0, -ang + math.pi / 2, 0), vertices=4, radius1=.9, depth=1, ink=.12, emit=1.2)
    if P in ('meadow', 'tide', 'frost'):
        prim('uv_sphere', far, '#FFF6CF', (-30, 99, 30), (4, 4, 4), segments=24, ring_count=12, ink=0, emit=1.6)
    if void:
        # a faint tier-coloured grid far below, and the floors already climbed, sinking into the dark
        for k in range(-12, 13):
            prim('cube', far, w['tier'], (k * 9, 50, -26), (.05, 60, .05), ink=0, emit=.55)
        for k in range(0, 14):
            prim('cube', far, w['tier'], (0, k * 9, -26), (120, .05, .05), ink=0, emit=.55)
        for side, dz, yy in ((-1, -7, 30), (1, -13, 52), (-1, -19, 70)):
            prim('cube', far, w['glass'], (side * 16, yy, dz - 1), (5, 18, 1), ink=.15)
            prim('cube', far, w['floor'][0], (side * 16, yy, dz + .02), (4.6, 17.6, .04), ink=0)
            for sx in (-1, 1): prim('cube', far, w['tier'], (side * 16 + sx * 4.8, yy, dz + .15), (.12, 17.8, .12), ink=0, emit=3)
            for k in range(-4, 5): prim('cube', far, w['grid'], (side * 16, yy + k * 4, dz + .07), (4.6, .03, .02), ink=0, emit=1.6)

    # mid: the corridor (alternating A/B plates, studs, curbs), shoulders, gate, props
    RW = 4.2; Y0, Y1 = -14, 70
    seg = 3.0; n = int((Y1 - Y0) / seg)
    if void:
        prim('cube', mid, w['glass'], (0, (Y0 + Y1) / 2, -1.6), (RW + .8, (Y1 - Y0) / 2, 1.5), ink=.06)
    for k in range(n):
        prim('cube', mid, w['floor'][k % 2], (0, Y0 + seg * (k + .5), -.12), (RW, seg / 2, .12), ink=0)
    stud = prim('cylinder', mid, w['stud'], (-RW + .42, Y0 + .42, .06), (.2, .2, .06), vertices=12, ink=0)
    ar = stud.modifiers.new('a', 'ARRAY'); ar.count = 11; ar.use_relative_offset = False; ar.use_constant_offset = True; ar.constant_offset_displace = (.84 * (RW * 2 - .84) / (.84 * 10), 0, 0)
    ar2 = stud.modifiers.new('b', 'ARRAY'); ar2.count = int((Y1 - Y0) / .84); ar2.use_relative_offset = False; ar2.use_constant_offset = True; ar2.constant_offset_displace = (0, .84, 0)
    if void:
        for side in (-1, 1):   # neon slide rails in the tier colour + the white edge line
            prim('cube', mid, w['tier'], (side * (RW + .35), (Y0 + Y1) / 2, .2), (.16, (Y1 - Y0) / 2, .16), ink=0, emit=4)
            prim('cube', mid, w['grid'], (side * (RW - .05), (Y0 + Y1) / 2, .02), (.04, (Y1 - Y0) / 2, .02), ink=0, emit=2)
        for k in range(int((Y1 - Y0) / 6)):   # white neon grid across every few studs
            prim('cube', mid, w['grid'], (0, Y0 + k * 6, .02), (RW, .035, .02), ink=0, emit=2)
        prim('cube', mid, w['grid'], (0, (Y0 + Y1) / 2, .02), (.035, (Y1 - Y0) / 2, .02), ink=0, emit=1.2)
    else:
        for side in (-1, 1):
            for k in range(int((Y1 - Y0) / 1.6)):
                prim('cube', mid, w['curb'][k % 2], (side * (RW + .3), Y0 + .8 + k * 1.6, .1), (.3, .8, .22), ink=0)
            prim('cube', mid, w['ground'][0], (side * (RW + 30.6), 28, -.3), (30, 44, .3), ink=0)
    # gate: two pylons of toy bricks (Void: black-glass monoliths with neon edges and a floating tier cube)
    GY = 30
    for side in (-1, 1):
        gx = side * (RW + 1.6)
        if void:
            prim('cube', mid, '#14161C', (gx, GY, 3.2), (.9, .9, 3.2), ink=.08)
            for ex in (-1, 1): prim('cube', mid, w['grid'], (gx + ex * .92, GY - .92, 3.2), (.05, .05, 3.2), ink=0, emit=2.5)
            prim('cube', mid, w['tier'], (gx, GY, 7.6), (.45, .45, .45), rot=(.6, .6, 0), ink=.05, emit=2.5)
        else:
            for k in range(5):
                prim('cube', mid, w['bricks'][k % 3], (gx, GY, .55 + k * 1.1), (.95, .95, .55), ink=.07)
            for sx in (-.45, .45):
                for sy in (-.45, .45):
                    prim('cylinder', mid, w['bricks'][1], (gx + sx, GY + sy, 5.6), (.24, .24, .12), vertices=12, ink=.03)
    if void:
        prim('torus', mid, w['grid'], (0, GY, 3.6), (1, 1, 1), rot=(math.radians(90), 0, 0), major_radius=2.4, minor_radius=.08, ink=0, emit=2.5)
    else:   # the wall: an amber honeycomb membrane, low, like the game's locked Length wall
        prim('cube', mid, '#FFB547', (0, GY, 1.0), (RW + .7, .12, .9), ink=.05)
        for k in range(-6, 7):
            prim('cylinder', mid, '#FFD27A', (k * .66, GY - .14, 1.0), (.26, .26, .02), rot=(math.radians(90), 0, 0), vertices=6, ink=0)
    # side props
    for side in (-1, 1):
        for k in range(10):
            x = side * random.uniform(RW + 2.2, RW + 14); y = random.uniform(-2, 52); s = random.uniform(1.1, 2.1)
            if void:
                glitch_cube(mid, side * random.uniform(RW + 4, RW + 18), y, random.uniform(-2, 6), s * .45, random.choice([w['tier'], w['grid']]))
            elif P == 'meadow':
                r = random.random()
                if r < .45: lolli_tree(mid, x, y, s * 1.3, w)
                elif r < .65: bush(mid, x, y, s * .8)
                elif r < .82: sprout(mid, x, y, s)
                else: mushroom(mid, x, y, s * .9, ['#FF9EC8', '#B58CFF', '#FFD23F'])
            elif P == 'tide':
                r = random.random()
                if r < .35: coral(mid, x, y, s)
                elif r < .55: rock(mid, x, y, s * .6, random.choice(['#8D9CA6', '#A5B3BC']))
                elif r < .75: palm(mid, x, y, s * .9)
                else: umbrella(mid, x, y, s)
            elif P == 'crystal':
                r = random.random()
                if r < .5: crystal(mid, x, y, s * 1.2, ['#FF7AD9', '#C9A7FF', '#7FE8FF', '#B98CFF'], emit=1.15)
                elif r < .75: prim('cone', mid, '#3A2F55', (x, y, s * .9), (s * .45, s * .45, s * .9), vertices=7, ink=.05 * s)
                else: mushroom(mid, x, y, s * .8, ['#7FE8FF', '#FF7AD9'])
            elif P == 'frost':
                r = random.random()
                if r < .6: pine(mid, x, y, s * 1.25)
                elif r < .78: snowman(mid, x, y, s * .8)
                else: ice_block(mid, x, y, s * .9)
            elif P == 'magma':
                r = random.random()
                if r < .55: basalt(mid, x, y, s)
                else: rock(mid, x, y, s * .7, random.choice(['#3A3033', '#2A2327']))
            elif P == 'candy':
                r = random.random()
                if r < .4: lollipop(mid, x, y, s)
                elif r < .75: gumdrop(mid, x, y, s)
                else: cane(mid, x, y, s * .9)
            elif P == 'starfall':
                r = random.random()
                if r < .5: moonrock(mid, x, y, s)
                else: star_shard(mid, x, y, s, s * random.uniform(1, 3))
            elif P == 'core':
                r = random.random()
                if r < .55: column(mid, x, y, s)
                else: prim('ico_sphere', mid, '#FFC437', (x, y, s * .4), (s * .4,) * 3, subdivisions=2, ink=.03 * s)
        if P == 'magma':   # rivers of molten gold beside the causeway (crust edges)
            prim('cube', mid, '#FFB938', (side * (RW + 5.5), 28, -.12), (1.7, 44, .1), ink=0, emit=3.2)
            prim('cube', mid, '#FFE58A', (side * (RW + 5.5), 28, -.08), (.6, 44, .1), ink=0, emit=4)
            for sx in (-1, 1): prim('cube', mid, '#3A2420', (side * (RW + 5.5) + sx * 1.8, 28, -.1), (.25, 44, .14), ink=0)
        if P == 'meadow':
            for k in range(26):
                prim('ico_sphere', mid, random.choice(['#FFFFFF', '#FF9EC8', '#FFE066']), (side * random.uniform(RW + .9, RW + 9), random.uniform(-8, 30), .12), (.16, .16, .1), subdivisions=1, ink=0)
        if P == 'frost':
            for k in range(8):
                prim('uv_sphere', mid, '#FFFFFF', (side * random.uniform(RW + 1.5, RW + 12), random.uniform(-6, 40), -.1), (random.uniform(.8, 1.6), random.uniform(.6, 1.2), .45), segments=10, ring_count=6, ink=.04)
        if P == 'tide':    # lagoon beside the sand shoulder
            prim('cube', mid, w['sea'][1], (side * (RW + 12), 28, -.25), (5, 44, .1), ink=0)
    # fg: big props hugging the frame edges
    for side in (-1, 1):
        x = side * random.uniform(4.7, 5.1); y = random.uniform(-9.4, -8.8)
        if void: glitch_cube(fg, side * 4.6, -9, 3.2, .7, w['tier'])
        elif P == 'meadow': lolli_tree(fg, x + side * .6, y, 2.2, w); bush(fg, x - side * .2, y + 1.2, .8)
        elif P == 'frost': pine(fg, x + side * .5, y, 2.0)
        elif P == 'crystal': crystal(fg, x, y, 1.6, ['#FF7AD9', '#C9A7FF'], emit=1.15)
        elif P == 'tide': coral(fg, x, y, 1.3); rock(fg, x + side * .6, y + .8, .8, '#A5B3BC')
        elif P == 'magma': basalt(fg, x, y, 1.4)
        elif P == 'candy': lollipop(fg, x, y, 1.6); gumdrop(fg, x - side * .2, y + 1.2, .8)
        elif P == 'starfall': moonrock(fg, x, y, 1.3, z=1.2)
        elif P == 'core': column(fg, x + side * .3, y, 1.5)
    # camera: a low arena camera looking down the corridor at the gate
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 30; cam.location = (0, -15, 3.8); cam.rotation_euler = (math.radians(84.5), 0, 0)
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = a.samples; sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 2; sc.render.threads_mode = 'FIXED'; sc.render.threads = a.threads; sc.render.filter_size = 1.2
    sc.render.resolution_x, sc.render.resolution_y = a.w, a.h; sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'Standard'
    return cols, cam

def render_layers(wid):
    cols, cam = build(wid); sc = bpy.context.scene; vl = sc.view_layers[0]
    for layer in ('far', 'mid', 'fg'):
        for k in cols:
            lc = vl.layer_collection.children[k]; lc.exclude = False; lc.holdout = False
            if layer == 'far': lc.exclude = (k != 'far')
            elif layer == 'mid': lc.exclude = (k == 'fg'); lc.holdout = (k == 'far')
            else: lc.holdout = (k != 'fg')
        sc.render.film_transparent = layer != 'far'
        sc.render.filepath = os.path.join(a.out, f'{wid}_{layer}.png'); bpy.ops.render.render(write_still=True)
    # where the guardian stands (on the corridor, a little in front of the camera target) and where the horizon is
    floor = world_to_camera_view(sc, cam, mathutils.Vector((0, -1.0, 0)))
    hor = world_to_camera_view(sc, cam, mathutils.Vector((0, 400, 0)))
    json.dump({'world': wid, 'floor': [round(floor.x, 4), round(1 - floor.y, 4)], 'horizon': round(1 - hor.y, 4),
               'w': a.w, 'h': a.h}, open(os.path.join(a.out, f'{wid}_stage.json'), 'w'))

for wid in (W if a.which == 'all' else a.which.split(',')):
    render_layers(wid); print('done', wid, flush=True)
