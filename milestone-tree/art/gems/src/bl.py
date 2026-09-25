"""bl.py - shared helpers for headless Blender 4.5 LTS (pip `bpy` module), Cycles CPU.

Conventions
  * Units: meters, Z-up (Blender). Rotations passed to helpers are in DEGREES.
  * Colors: hex strings ('#6fdc9f') are sRGB and converted to linear; tuples are taken as linear.
  * Only Cycles works headless here (EEVEE and Workbench need an OpenGL/EGL context -> crash).

Import:
    import sys; sys.path.insert(0, '<scratchpad>/blender/lib'); import bl
"""
import bpy, bmesh, math, os, sys, time, json, glob, shutil, subprocess
from mathutils import Vector, Matrix, Euler

LIB = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(LIB)
FONTS = os.path.join(LIB, "fonts")
STUD_M = 0.28  # 1 Roblox stud = 0.28 m

# ----------------------------------------------------------------------------- palettes
LUCK = {  # Luck Incremental NG+ lab UI
    "clover": "#6fdc9f", "gold": "#f0c85a", "red": "#ff7d6e",
    "dark0": "#101216", "dark1": "#181b21", "dark2": "#22262e", "dark3": "#2e333d", "grey": "#4a515e",
    "hall_red": "#ff5a4e", "hall_green": "#4fdc86", "hall_blue": "#4f9dff",
}
TREE = {  # The Milestone Tree NG+ layer colors
    "m": "#b35cff", "mm": "#d17aff", "em": "#e88af2", "p": "#6fc3ff", "pe": "#ff9a2e", "sp": "#5fe0ff",
    "pb": "#57e0b0", "pp": "#ff4d6d", "se": "#ff6a1f", "hp": "#7fd9ff", "ep": "#9be02c", "hb": "#6dffb0",
    "ap": "#8ff3f3", "mp": "#ff5a1f", "t": "#ffe93a", "pm": "#ff2e63", "pep": "#f2b04d", "cp": "#39ff14",
    "cm": "#1fbf4a", "ex": "#45e07f", "ach": "#ffc93c",
}


def log(*a):
    print("[bl]", *a, flush=True)


# ----------------------------------------------------------------------------- color
def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin2srgb(c):
    c = max(0.0, c)
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hexc(h, a=1.0):
    """'#rrggbb' (sRGB) -> linear RGBA tuple."""
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb2lin(r), srgb2lin(g), srgb2lin(b), a)


def col(c, a=None):
    """Accept hex str / RGB / RGBA (linear) -> linear RGBA 4-tuple."""
    if isinstance(c, str):
        t = hexc(c)
    elif len(c) == 3:
        t = (c[0], c[1], c[2], 1.0)
    else:
        t = tuple(c[:4])
    if a is not None:
        t = (t[0], t[1], t[2], a)
    return t


def mixc(c1, c2, t):
    a, b = col(c1), col(c2)
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(4))


def scalec(c, k):
    a = col(c)
    return (a[0] * k, a[1] * k, a[2] * k, a[3])


def kelvin(k):
    """Approx. blackbody color (linear RGBA) for 1000-40000 K."""
    t = k / 100.0
    r = 255 if t <= 66 else 329.698727446 * (t - 60) ** -0.1332047592
    g = 99.4708025861 * math.log(t) - 161.1195681661 if t <= 66 else 288.1221695283 * (t - 60) ** -0.0755148492
    b = 255 if t >= 66 else (0 if t <= 19 else 138.5177312231 * math.log(t - 10) - 305.0447927307)
    return tuple(srgb2lin(min(255, max(0, v)) / 255.0) for v in (r, g, b)) + (1.0,)


# ----------------------------------------------------------------------------- scene
def reset(fps=24, frames=(1, 120)):
    """Empty factory scene. Returns the scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = fps
    sc.frame_start, sc.frame_end = frames
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    return sc


def scene():
    return bpy.context.scene


def collection(name, parent=None, hide_render=False):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    p = parent or bpy.context.scene.collection
    if c.name not in p.children:
        p.children.link(c)
    c.hide_render = hide_render
    return c


def link(obj, coll=None):
    """Move obj into coll (default: scene collection)."""
    coll = coll or bpy.context.scene.collection
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


def parent(child, par, keep_transform=True):
    bpy.context.view_layer.update()  # matrix_world of freshly created/moved objects is stale until an update
    mw = child.matrix_world.copy()
    child.parent = par
    if keep_transform:
        child.matrix_parent_inverse = par.matrix_world.inverted()
        child.matrix_world = mw
    return child


def empty(name="Empty", loc=(0, 0, 0), rot=(0, 0, 0), kind="PLAIN_AXES", size=1.0, coll=None):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = kind
    ob.empty_display_size = size
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def select_only(*objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]


def delete(objs):
    """Remove objects and their now-unused data blocks."""
    if not isinstance(objs, (list, tuple, set)):
        objs = [objs]
    for o in objs:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if data is None or data.users:
            continue
        for T, store in ((bpy.types.Mesh, bpy.data.meshes), (bpy.types.Curve, bpy.data.curves),
                         (bpy.types.Light, bpy.data.lights), (bpy.types.Camera, bpy.data.cameras)):
            if isinstance(data, T):
                store.remove(data)
                break


def purge():
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


# ----------------------------------------------------------------------------- render settings
LOOKS = ["None", "Punchy", "Greyscale", "Very High Contrast", "High Contrast", "Medium High Contrast",
         "Base Contrast", "Medium Low Contrast", "Low Contrast", "Very Low Contrast"]


def cycles(samples=128, res=(1920, 1080), pct=100, threshold=0.02, min_samples=0, denoise=True,
           denoise_quality="HIGH", view="AgX", look="Medium High Contrast", exposure=0.0, gamma=1.0,
           transparent=False, bounces=None, clamp_indirect=10.0, filter_glossy=0.8, caustics=False,
           time_limit=0.0, persistent=False, seed=0, animated_seed=False, threads=None, motion_blur=False,
           film_filter=1.5, color_depth="8"):
    """Configure Cycles on CPU with adaptive sampling + OpenImageDenoise and AgX color management.
    bounces: dict(total, diffuse, glossy, transmission, volume, transparent) overrides."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.device = "CPU"
    try:
        bpy.context.preferences.addons["cycles"].preferences.compute_device_type = "NONE"
    except Exception:
        pass
    cy.samples = samples
    cy.preview_samples = max(1, samples // 4)
    cy.use_adaptive_sampling = threshold > 0
    if threshold > 0:
        cy.adaptive_threshold = threshold
        cy.adaptive_min_samples = min_samples
    cy.time_limit = time_limit
    cy.use_denoising = denoise
    if denoise:
        cy.denoiser = "OPENIMAGEDENOISE"
        cy.denoising_input_passes = "RGB_ALBEDO_NORMAL"
        cy.denoising_prefilter = "ACCURATE"
        if hasattr(cy, "denoising_quality"):
            cy.denoising_quality = denoise_quality
        if hasattr(cy, "denoising_use_gpu"):
            cy.denoising_use_gpu = False
    cy.use_light_tree = True
    cy.sample_clamp_direct = 0.0
    cy.sample_clamp_indirect = clamp_indirect
    cy.blur_glossy = filter_glossy
    cy.caustics_reflective = caustics
    cy.caustics_refractive = caustics
    b = dict(total=12, diffuse=4, glossy=4, transmission=12, volume=2, transparent=16)
    b.update(bounces or {})
    cy.max_bounces, cy.diffuse_bounces, cy.glossy_bounces = b["total"], b["diffuse"], b["glossy"]
    cy.transmission_bounces, cy.volume_bounces, cy.transparent_max_bounces = b["transmission"], b["volume"], b["transparent"]
    cy.seed = seed
    cy.use_animated_seed = animated_seed
    cy.filter_width = film_filter
    r = sc.render
    r.resolution_x, r.resolution_y = res
    r.resolution_percentage = pct
    r.film_transparent = transparent
    r.use_persistent_data = persistent
    r.use_motion_blur = motion_blur
    if threads:
        r.threads_mode, r.threads = "FIXED", threads
    else:
        r.threads_mode = "AUTO"
    im = r.image_settings
    im.file_format = "PNG"
    im.color_mode = "RGBA" if transparent else "RGB"
    im.color_depth = color_depth
    im.compression = 15
    color(view, look, exposure, gamma)
    return sc


def color(view="AgX", look="Medium High Contrast", exposure=0.0, gamma=1.0):
    vs = bpy.context.scene.view_settings
    bpy.context.scene.display_settings.display_device = "sRGB"
    vs.view_transform = view
    if view == "AgX" and look and look != "None":
        vs.look = look if look.startswith("AgX") else "AgX - " + look
    else:
        vs.look = "None"
    vs.exposure = exposure
    vs.gamma = gamma


def preview(pct=33, samples=24):
    """Quick test-render mode (keeps everything else)."""
    sc = bpy.context.scene
    sc.render.resolution_percentage = pct
    sc.cycles.samples = samples


# ----------------------------------------------------------------------------- node utils
def _nt(mat_or_world):
    mat_or_world.use_nodes = True
    return mat_or_world.node_tree


def _rgba_io(node):
    """For ShaderNodeMix(data_type='RGBA'): returns (A, B, Result) color sockets."""
    ins = [s for s in node.inputs if s.type == "RGBA"]
    out = [s for s in node.outputs if s.type == "RGBA"][0]
    return ins[0], ins[1], out


def _set_in(sock, v):
    """Set a socket's default value from float / color / tuple."""
    dv = sock.default_value
    if isinstance(v, str):
        v = col(v)
    if hasattr(dv, "__len__"):
        n = len(dv)
        if isinstance(v, (int, float)):
            v = (v,) * min(n, 3) + ((1.0,) if n == 4 else ())
        v = tuple(v)
        if n == 4 and len(v) == 3:
            v = v + (1.0,)
        sock.default_value = v[:n]
    else:
        sock.default_value = v


def _feed(nt, value, sock):
    """Link a socket or set a constant into `sock`."""
    if isinstance(value, bpy.types.NodeSocket):
        nt.links.new(value, sock)
    else:
        _set_in(sock, value)


def map_range(nt, src, a, b, c=0.0, d=1.0, smooth=False, clamp=True):
    n = nt.nodes.new("ShaderNodeMapRange")
    n.interpolation_type = "SMOOTHSTEP" if smooth else "LINEAR"
    n.clamp = clamp
    nt.links.new(src, n.inputs["Value"])
    n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = a, b
    n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = c, d
    return n.outputs["Result"]


def mix_rgb(nt, fac, a, b, blend="MIX"):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    n.blend_type = blend
    A, B, R = _rgba_io(n)
    _feed(nt, fac, n.inputs["Factor"])
    _feed(nt, a, A)
    _feed(nt, b, B)
    return R


def math_node(nt, op, a, b=0.0):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    _feed(nt, a, n.inputs[0])
    _feed(nt, b, n.inputs[1])
    return n.outputs[0]


# ----------------------------------------------------------------------------- world
def _world():
    sc = bpy.context.scene
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    nt = _nt(w)
    nt.nodes.clear()
    return w, nt


def _world_out(nt, color_sock_or_val, strength, camera_bg=None, camera_strength=1.0):
    bg = nt.nodes.new("ShaderNodeBackground")
    _feed(nt, color_sock_or_val, bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputWorld")
    shader = bg.outputs[0]
    if camera_bg is not None:
        cam = nt.nodes.new("ShaderNodeBackground")
        _feed(nt, camera_bg, cam.inputs["Color"])
        cam.inputs["Strength"].default_value = camera_strength
        lp = nt.nodes.new("ShaderNodeLightPath")
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
        nt.links.new(bg.outputs[0], mx.inputs[1])
        nt.links.new(cam.outputs[0], mx.inputs[2])
        shader = mx.outputs[0]
    nt.links.new(shader, out.inputs["Surface"])
    return out


def world_color(c="#101216", strength=1.0):
    w, nt = _world()
    _world_out(nt, col(c), strength)
    return w


def _world_dir(nt):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nrm = nt.nodes.new("ShaderNodeVectorMath")
    nrm.operation = "NORMALIZE"
    nt.links.new(tc.outputs["Generated"], nrm.inputs[0])
    return nrm.outputs["Vector"]


def _ramp(nt, fac, stops, interp="EASE"):
    cr = nt.nodes.new("ShaderNodeValToRGB")
    cr.color_ramp.interpolation = interp
    els = cr.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    for i, (p, c) in enumerate(stops):
        e = els[0] if i == 0 else els.new(p)
        e.position = p
        e.color = col(c)
    nt.links.new(fac, cr.inputs["Fac"])
    return cr.outputs["Color"]


def world_gradient(zenith="#1c2230", horizon="#3a4152", ground="#0c0d10", strength=1.0,
                   horizon_width=0.08, camera_bg=None, camera_strength=1.0):
    """Vertical sky gradient (ground / horizon / zenith). camera_bg: separate color seen by camera."""
    w, nt = _world()
    d = _world_dir(nt)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(d, sep.inputs[0])
    z01 = map_range(nt, sep.outputs["Z"], -1, 1, 0, 1)
    h = horizon_width
    c = _ramp(nt, z01, [(0.0, ground), (0.5 - h / 2, ground), (0.5, horizon), (0.5 + h, horizon), (1.0, zenith)])
    _world_out(nt, c, strength, col(camera_bg) if camera_bg else None, camera_strength)
    return w


def world_studio(top="#1a1d24", horizon="#2a2e37", bottom="#08090b", strength=1.0, boxes="default",
                 camera_bg=None, camera_strength=1.0):
    """Procedural 'HDRI' studio: gradient dome + round softboxes (direction, radius_deg, color, power).
    Gives nice reflections on glossy/metal surfaces. camera_bg: color the camera sees instead."""
    if boxes == "default":
        boxes = [dict(dir=(-0.7, -0.6, 0.55), deg=16, color="#fff1e0", power=14.0),   # key softbox
                 dict(dir=(0.85, -0.35, 0.35), deg=26, color="#dbe8ff", power=4.0),   # fill
                 dict(dir=(0.1, 0.95, 0.35), deg=10, color="#ffffff", power=18.0),    # rim strip
                 dict(dir=(0.0, 0.0, 1.0), deg=35, color="#ffffff", power=1.5)]      # top
    w, nt = _world()
    d = _world_dir(nt)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(d, sep.inputs[0])
    z01 = map_range(nt, sep.outputs["Z"], -1, 1, 0, 1)
    acc = _ramp(nt, z01, [(0.0, bottom), (0.47, bottom), (0.5, horizon), (1.0, top)])
    for b in boxes or []:
        dv = Vector(b["dir"]).normalized()
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        nt.links.new(d, dot.inputs[0])
        dot.inputs[1].default_value = dv
        r = math.radians(b["deg"])
        feather = b.get("feather", 0.35) * r
        m = map_range(nt, dot.outputs["Value"], math.cos(r + feather), math.cos(max(r - feather, 1e-4)), 0, 1, smooth=True)
        acc = mix_rgb(nt, m, acc, scalec(b["color"], b["power"]), blend="ADD")
    _world_out(nt, acc, strength, col(camera_bg) if camera_bg else None, camera_strength)
    return w


def world_sky(sun_elevation=25, sun_rotation=40, strength=0.35, altitude=0, air=1.0, dust=1.0, ozone=1.0,
              sun_disc=True, sun_size=0.545, sun_intensity=1.0, camera_bg=None):
    """Nishita physical sky (degrees). Pair with a sun() of matching direction for crisp shadows."""
    w, nt = _world()
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(sun_elevation)
    sky.sun_rotation = math.radians(sun_rotation)
    sky.altitude = altitude
    sky.air_density, sky.dust_density, sky.ozone_density = air, dust, ozone
    sky.sun_disc = sun_disc
    sky.sun_size = math.radians(sun_size)
    sky.sun_intensity = sun_intensity
    _world_out(nt, sky.outputs["Color"], strength, col(camera_bg) if camera_bg else None)
    return w


def sun_dir(elevation, rotation):
    """Unit vector pointing TOWARDS the Nishita sun (same angle convention as world_sky, degrees).
    Use sun(direction=-sun_dir(e, r)) to add a matching sun lamp."""
    e, r = math.radians(elevation), math.radians(rotation)
    return Vector((math.cos(e) * math.sin(r), math.cos(e) * math.cos(r), math.sin(e)))  # verified vs. rendered disc


# ----------------------------------------------------------------------------- lights
def look_at(ob, target, roll=0.0):
    """Point ob's -Z at target (cameras, lights). roll in degrees."""
    if ob.parent or hasattr(target, "matrix_world"):
        bpy.context.view_layer.update()
    t = target.matrix_world.translation.copy() if hasattr(target, "matrix_world") else Vector(target)
    d = t - ob.matrix_world.translation if ob.parent else t - ob.location
    q = d.to_track_quat("-Z", "Y")
    if roll:
        q = q @ Matrix.Rotation(math.radians(roll), 4, "Z").to_quaternion()
    ob.rotation_mode = "XYZ"
    ob.rotation_euler = q.to_euler()
    return ob


def light(kind="AREA", name=None, loc=(0, 0, 5), target=(0, 0, 0), energy=500.0, color="#ffffff", size=1.0,
          size_y=None, shape=None, spot_deg=45.0, blend=0.2, radius=0.1, angle_deg=0.5, spread_deg=None,
          shadow=True, rot=None, coll=None):
    """Generic light. energy: W for point/spot/area, W/m^2 (irradiance) for SUN."""
    ld = bpy.data.lights.new(name or kind.title(), kind)
    ld.energy = energy
    ld.color = col(color)[:3]
    ld.use_shadow = shadow
    if kind == "AREA":
        ld.shape = shape or ("RECTANGLE" if size_y else "SQUARE")
        ld.size = size
        if size_y:
            ld.size_y = size_y
        if spread_deg is not None:
            ld.spread = math.radians(spread_deg)
    elif kind == "SPOT":
        ld.spot_size = math.radians(spot_deg)
        ld.spot_blend = blend
        ld.shadow_soft_size = radius
    elif kind == "POINT":
        ld.shadow_soft_size = radius
    elif kind == "SUN":
        ld.angle = math.radians(angle_deg)
    ob = bpy.data.objects.new(ld.name, ld)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    if rot is not None:
        ob.rotation_euler = [math.radians(a) for a in rot]
    elif target is not None:
        look_at(ob, target)
    return ob


def area(name="Area", loc=(3, -3, 4), target=(0, 0, 0), energy=500, color="#ffffff", size=1.0, size_y=None,
         spread_deg=None, **kw):
    return light("AREA", name, loc, target, energy, color, size, size_y, spread_deg=spread_deg, **kw)


def spot(name="Spot", loc=(0, 0, 5), target=(0, 0, 0), energy=1000, color="#ffffff", spot_deg=35, blend=0.3,
         radius=0.05, **kw):
    return light("SPOT", name, loc, target, energy, color, spot_deg=spot_deg, blend=blend, radius=radius, **kw)


def point(name="Point", loc=(0, 0, 3), energy=100, color="#ffffff", radius=0.1, **kw):
    return light("POINT", name, loc, None, energy, color, radius=radius, **kw)


def sun(name="Sun", direction=(-0.4, 0.5, -0.75), energy=3.0, color="#fff4e5", angle_deg=1.0, **kw):
    """direction = where the light travels (points down for daylight)."""
    ob = light("SUN", name, (0, 0, 20), None, energy, color, angle_deg=angle_deg, **kw)
    ob.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    return ob


def three_point(target=(0, 0, 0), dist=6.0, key=900.0, fill_ratio=0.2, rim=1000.0, key_color=None,
                fill_color="#bcd4ff", rim_color="#cfe6ff", yaw=None, key_size=2.5, key_elev=40.0, rim_elev=45.0,
                rim_receivers=None, coll=None):
    """Key (front-left, warm), fill (front-right, soft, weak), rim (back, cool). yaw (deg) = azimuth of the
    camera around target; default: taken from scene.camera. Energies scale with (dist/6)^2.
    rim_receivers: objects the rim may light (Cycles light linking). Pass the hero objects so the rim's
    specular reflection does not glare across glossy floors/backdrops seen by a low front camera."""
    t = Vector(target)
    if yaw is None:
        cam = bpy.context.scene.camera
        if cam:
            v = cam.matrix_world.translation - t
            yaw = math.degrees(math.atan2(v.x, -v.y))
        else:
            yaw = 0.0
    k = (dist / 6.0) ** 2

    def at(az, el, d):
        a, e = math.radians(yaw + az), math.radians(el)
        return t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * d

    kc = key_color or kelvin(5200)
    rig = {
        "key": area("Key", at(-40, key_elev, dist), t, key * k, kc, key_size, coll=coll),
        "fill": area("Fill", at(55, 12, dist * 1.1), t, key * fill_ratio * k, fill_color, key_size * 2.0, coll=coll),
        "rim": area("Rim", at(165, rim_elev, dist * 0.9), t, rim * k, rim_color, key_size * 0.6, key_size * 2.2,
                    spread_deg=60, coll=coll),
    }
    if rim_receivers:
        light_link(rig["rim"], rim_receivers)
    return rig


def light_link(light_ob, receivers, name=None):
    """Cycles light linking: light_ob only illuminates `receivers` (objects)."""
    c = bpy.data.collections.new(name or f"{light_ob.name}_receivers")
    for o in receivers:
        c.objects.link(o)  # extra collection membership; the objects stay where they are
    light_ob.light_linking.receiver_collection = c
    return c


# ----------------------------------------------------------------------------- materials
def mat(name="Mat", color="#cccccc", rough=0.5, metal=0.0, emission=None, strength=0.0, transmission=0.0,
        ior=1.45, alpha=1.0, subsurface=0.0, sss_radius=(1.0, 0.4, 0.2), sss_scale=0.05, coat=0.0,
        coat_rough=0.05, sheen=0.0, specular=0.5, aniso=0.0, thin_film=0.0, noise=None, normal=None):
    """Principled BSDF material.
    noise: dict(scale=6, detail=6, color_var=0.25, color2=None, rough_var=0.15, bump=0.0, contrast=0.35,
                coord='Object', distortion=0.0) - procedural variation (breaks up flat CG look)."""
    m = bpy.data.materials.new(name)
    nt = _nt(m)
    p = nt.nodes.get("Principled BSDF")
    I = p.inputs
    base = col(color)
    I["Base Color"].default_value = base
    I["Roughness"].default_value = rough
    I["Metallic"].default_value = metal
    I["IOR"].default_value = ior
    I["Alpha"].default_value = alpha
    I["Specular IOR Level"].default_value = specular
    I["Transmission Weight"].default_value = transmission
    I["Subsurface Weight"].default_value = subsurface
    I["Subsurface Radius"].default_value = sss_radius
    I["Subsurface Scale"].default_value = sss_scale
    I["Coat Weight"].default_value = coat
    I["Coat Roughness"].default_value = coat_rough
    I["Sheen Weight"].default_value = sheen
    I["Anisotropic"].default_value = aniso
    if "Thin Film Thickness" in I:
        I["Thin Film Thickness"].default_value = thin_film
    if emission is not None and strength > 0:
        I["Emission Color"].default_value = col(emission)
        I["Emission Strength"].default_value = strength
    if noise:
        nz = dict(scale=6.0, detail=6.0, color_var=0.25, color2=None, rough_var=0.15, bump=0.0, contrast=0.35,
                  coord="Object", distortion=0.0, roughness=0.55)
        nz.update(noise)
        tc = nt.nodes.new("ShaderNodeTexCoord")
        tx = nt.nodes.new("ShaderNodeTexNoise")
        nt.links.new(tc.outputs[nz["coord"]], tx.inputs["Vector"])
        tx.inputs["Scale"].default_value = nz["scale"]
        tx.inputs["Detail"].default_value = nz["detail"]
        tx.inputs["Roughness"].default_value = nz["roughness"]
        tx.inputs["Distortion"].default_value = nz["distortion"]
        fac = tx.outputs["Fac"]
        c = nz["contrast"]
        f2 = map_range(nt, fac, 0.5 - c / 2, 0.5 + c / 2, 0, 1, smooth=True)
        if nz["color_var"]:
            c2 = col(nz["color2"]) if nz["color2"] else scalec(base, 1 - nz["color_var"])
            if nz["color2"]:
                f2m = math_node(nt, "MULTIPLY", f2, nz["color_var"])
            else:
                f2m = f2
            nt.links.new(mix_rgb(nt, f2m, base, c2), I["Base Color"])
        if nz["rough_var"]:
            rv = nz["rough_var"]
            nt.links.new(map_range(nt, fac, 0, 1, max(0, rough - rv), min(1, rough + rv)), I["Roughness"])
        if nz["bump"]:
            bn = nt.nodes.new("ShaderNodeBump")
            bn.inputs["Strength"].default_value = nz["bump"]
            bn.inputs["Distance"].default_value = 0.02
            nt.links.new(fac, bn.inputs["Height"])
            nt.links.new(bn.outputs["Normal"], I["Normal"])
    return m


def emissive(name="Glow", color="#6fdc9f", strength=8.0, base=None, rough=0.4):
    """Glowing material (principled; dark base so it reads as a light source, bakes cleanly)."""
    return mat(name, base or scalec(color, 0.2), rough=rough, emission=color, strength=strength)


def glass(name="Glass", color="#ffffff", rough=0.0, ior=1.45, tint_strength=1.0):
    return mat(name, mixc("#ffffff", color, tint_strength), rough=rough, transmission=1.0, ior=ior)


def metal(name="Metal", color="#f0c85a", rough=0.25, noise=None):
    return mat(name, color, rough=rough, metal=1.0, noise=noise)


def assign(obj, m, faces=None):
    """Append material; optionally assign it only to polygon indices `faces`."""
    me = obj.data
    if m.name not in [x.name for x in me.materials if x]:
        me.materials.append(m)
    idx = [x.name if x else None for x in me.materials].index(m.name)
    if faces is not None and obj.type == "MESH":
        for i in faces:
            me.polygons[i].material_index = idx
    return idx


# ----------------------------------------------------------------------------- geometry
def _new_obj(name, me, loc, rot, scale, m, coll):
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = scale if hasattr(scale, "__len__") else (scale,) * 3
    if m:
        me.materials.append(m)
    return ob


def _bm_to_obj(bm, name, loc, rot, scale, m, coll, base, smooth_angle):
    if base:
        zmin = min(v.co.z for v in bm.verts)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -zmin))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _new_obj(name, me, loc, rot, scale, m, coll)
    if smooth_angle is not None:
        smooth(ob, smooth_angle)
    return ob


def _bm():
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    return bm


def box(name="Box", size=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.0, segments=3,
        base=False, coll=None):
    """Cuboid (size in m). base=True puts the origin at the bottom center. bevel adds Bevel+WeightedNormal."""
    s = size if hasattr(size, "__len__") else (size,) * 3
    bm = _bm()
    bmesh.ops.create_cube(bm, size=1.0, calc_uvs=True)
    bmesh.ops.scale(bm, vec=s, verts=bm.verts)
    ob = _bm_to_obj(bm, name, loc, rot, 1, m, coll, base, None)
    if bevel:
        bevel_mod(ob, bevel, segments)
    return ob


def cyl(name="Cyl", r=0.5, depth=1.0, verts=32, r2=None, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.0,
        segments=2, base=False, smooth_angle=35, coll=None):
    """Cylinder/cone/frustum along Z (r2 = top radius)."""
    bm = _bm()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r,
                          radius2=r if r2 is None else r2, depth=depth, calc_uvs=True)
    ob = _bm_to_obj(bm, name, loc, rot, 1, m, coll, base, smooth_angle)
    if bevel:
        bevel_mod(ob, bevel, segments, smooth_first=False)
    return ob


def sphere(name="Sphere", r=0.5, loc=(0, 0, 0), rot=(0, 0, 0), segments=48, rings=24, ico=0, m=None,
           smooth_angle=180, coll=None):
    """UV sphere (or icosphere if ico>0 subdivisions)."""
    bm = _bm()
    if ico:
        bmesh.ops.create_icosphere(bm, subdivisions=ico, radius=r, calc_uvs=True)
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=r, calc_uvs=True)
    return _bm_to_obj(bm, name, loc, rot, 1, m, coll, False, smooth_angle)


def plane(name="Plane", size=(2, 2), loc=(0, 0, 0), rot=(0, 0, 0), m=None, cuts=0, coll=None):
    s = size if hasattr(size, "__len__") else (size, size)
    bm = _bm()
    bmesh.ops.create_grid(bm, x_segments=cuts + 1, y_segments=cuts + 1, size=0.5, calc_uvs=True)
    xs = [v.co.x for v in bm.verts]
    k = 1.0 / (max(xs) - min(xs))
    bmesh.ops.scale(bm, vec=(s[0] * k, s[1] * k, 1), verts=bm.verts)
    return _bm_to_obj(bm, name, loc, rot, 1, m, coll, False, None)


def cyclorama(name="Cyclorama", width=30.0, depth=20.0, height=12.0, radius=4.0, loc=(0, 0, 0), m=None,
              segments=24, coll=None):
    """Seamless studio backdrop: floor (toward -Y) curving up into a back wall at +Y. No visible horizon.
    Geometry (relative to loc): flat floor for y < -radius, curved cove for -radius..0, wall at y=0.
    Keep props at y < loc.y - radius or they sink into the cove."""
    bm = _bm()
    prof = [(-depth, 0.0)]
    y0 = -radius  # curve starts radius before the wall plane y=0
    for i in range(segments + 1):
        a = (math.pi / 2) * i / segments
        prof.append((y0 + radius * math.sin(a), radius - radius * math.cos(a)))
    prof.append((0.0, height))
    rows = []
    for x in (-width / 2, width / 2):
        rows.append([bm.verts.new((x, y, z)) for (y, z) in prof])
    uv = bm.loops.layers.uv.active
    total = sum((Vector(prof[i + 1]) - Vector(prof[i])).length for i in range(len(prof) - 1))
    acc = [0.0]
    for i in range(len(prof) - 1):
        acc.append(acc[-1] + (Vector(prof[i + 1]) - Vector(prof[i])).length)
    for i in range(len(prof) - 1):
        f = bm.faces.new((rows[0][i], rows[1][i], rows[1][i + 1], rows[0][i + 1]))
        for lp, (u, v) in zip(f.loops, ((0, acc[i]), (1, acc[i]), (1, acc[i + 1]), (0, acc[i + 1]))):
            lp[uv].uv = (u, v / total)
    ob = _bm_to_obj(bm, name, loc, (0, 0, 0), 1, m, coll, False, 60)
    return ob


def torus(name="Torus", R=1.0, r=0.25, seg=64, rseg=24, loc=(0, 0, 0), rot=(0, 0, 0), m=None, smooth_angle=180,
          coll=None):
    bm = _bm()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
        rings.append(ring)
    uv = bm.loops.layers.uv.active
    for i in range(seg):
        for j in range(rseg):
            i2, j2 = (i + 1) % seg, (j + 1) % rseg
            f = bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
            for lp, (u, v) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uv].uv = (u / seg, v / rseg)
    return _bm_to_obj(bm, name, loc, rot, 1, m, coll, False, smooth_angle)


def instance(src, name=None, loc=None, rot=None, scale=None, coll=None):
    """Linked duplicate (shares mesh data -> cheap memory). rot in degrees."""
    ob = src.copy()
    ob.name = name or src.name
    (coll or (src.users_collection[0] if src.users_collection else bpy.context.scene.collection)).objects.link(ob)
    if loc is not None:
        ob.location = loc
    if rot is not None:
        ob.rotation_euler = [math.radians(a) for a in rot]
    if scale is not None:
        ob.scale = scale if hasattr(scale, "__len__") else (scale,) * 3
    return ob


def smooth(obj, angle=30.0):
    """Shade smooth + mark edges sharper than `angle` (deg) sharp (Blender 4.1+ auto-smooth replacement)."""
    me = obj.data
    me.shade_smooth()
    if angle < 180:
        me.set_sharp_from_angle(angle=math.radians(angle))
    return obj


def flat(obj):
    obj.data.shade_flat()
    return obj


def bevel_mod(obj, width=0.02, segments=3, angle=35.0, profile=0.5, harden=True, weighted=True, clamp=True,
              smooth_first=True):
    """Bevel (angle-limited, arc miters, hardened normals) + Weighted Normal. Clean shading on hard-surface."""
    if smooth_first:
        obj.data.shade_smooth()
    b = obj.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle)
    b.profile = profile
    b.use_clamp_overlap = clamp
    b.harden_normals = harden
    b.miter_outer = "MITER_ARC"
    if weighted:
        weighted_normals(obj)
    return b


def weighted_normals(obj, weight=50, keep_sharp=True):
    for md in obj.modifiers:
        if md.type == "WEIGHTED_NORMAL":
            obj.modifiers.remove(md)
    w = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    w.mode = "FACE_AREA"
    w.weight = weight
    w.keep_sharp = keep_sharp
    return w


def mod(obj, kind, name=None, **props):
    """Generic modifier: mod(o, 'ARRAY', count=5, relative_offset_displace=(1.2,0,0))."""
    md = obj.modifiers.new(name or kind.title(), kind)
    for k, v in props.items():
        setattr(md, k, v)
    return md


def apply_modifiers(obj):
    """Bake modifiers (and curve/text -> mesh) into mesh data. Returns the (possibly new) object."""
    bpy.context.view_layer.update()  # refresh stale matrix_world / bound_box of new or moved objects
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    if obj.type != "MESH":
        new = bpy.data.objects.new(obj.name, me)
        for c in obj.users_collection:
            c.objects.link(new)
        new.matrix_world = obj.matrix_world.copy()
        new.parent = obj.parent
        if obj.parent:
            new.matrix_world = obj.matrix_world.copy()
        nm = obj.name
        delete(obj)
        new.name = nm
        return new
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    me.name = old.name
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def join(objs, name=None):
    """Join objects (converted/applied) into the first one. Returns joined object."""
    objs = [apply_modifiers(o) for o in objs]
    select_only(*objs)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    if name:
        o.name = name
        o.data.name = name
    return o


def origin_to_base(obj):
    """Move origin to bottom-center of the mesh bounds (local space) without moving geometry in world."""
    me = obj.data
    if not me.vertices:
        return obj
    xs, ys, zs = zip(*[v.co for v in me.vertices])
    b = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    me.transform(Matrix.Translation(-b))
    obj.matrix_world = obj.matrix_world @ Matrix.Translation(b)
    return obj


def bounds(objs):
    """World-space AABB (min, max, center, size) of objects."""
    bpy.context.view_layer.update()  # refresh stale matrix_world / bound_box of new or moved objects
    if not isinstance(objs, (list, tuple)):
        objs = [objs]
    pts = []
    for o in objs:
        if o.type in ("MESH", "CURVE", "FONT", "SURFACE", "META"):
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx, (mn + mx) / 2, mx - mn


def tri_count(obj):
    """Triangles after modifiers (what an exporter with 'apply modifiers' writes)."""
    if obj.type not in ("MESH", "CURVE", "FONT", "SURFACE", "META"):
        return 0
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    if me is None:
        return 0
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    ev.to_mesh_clear()
    return n


def tri_report(objs=None):
    objs = objs if objs is not None else [o for o in bpy.context.scene.objects]
    rep = {o.name: tri_count(o) for o in objs if o.type in ("MESH", "CURVE", "FONT")}
    return {"objects": rep, "total": sum(rep.values())}


def decimate_to(obj, max_tris=20000, apply=True):
    """Collapse-decimate until tris <= max_tris. Returns final count."""
    n = tri_count(obj)
    if n <= max_tris:
        return n
    d = obj.modifiers.new("Decimate", "DECIMATE")
    ratio = max_tris / n * 0.98
    for _ in range(6):
        d.ratio = ratio
        c = tri_count(obj)
        if c <= max_tris:
            break
        ratio *= max_tris / c * 0.98
    if apply:
        apply_modifiers(obj)
    return tri_count(obj)


# ----------------------------------------------------------------------------- text
def font(name="TitanOne-Regular"):
    """Load a font by file name/prefix from lib/fonts (or an absolute path)."""
    path = name if os.path.isabs(name) else None
    if path is None:
        cands = sorted(glob.glob(os.path.join(FONTS, "*.tt[fc]")) + glob.glob(os.path.join(FONTS, "*.otf")))
        low = name.lower()
        for c in cands:
            if os.path.basename(c).lower().startswith(low):
                path = c
                break
        if path is None:
            raise FileNotFoundError(f"font {name!r}; have: {[os.path.basename(c) for c in cands]}")
    return bpy.data.fonts.load(path, check_existing=True)


def text(body, name="Text", size=1.0, loc=(0, 0, 0), rot=(90, 0, 0), extrude=0.05, bevel=0.01, bevel_res=3,
         font_name="TitanOne-Regular", align="CENTER", valign="CENTER", m=None, spacing=1.0, line_spacing=1.0,
         resolution=6, to_mesh=False, coll=None):
    """3D text. Default rot=(90,0,0) stands it up facing -Y (towards a default front camera)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    f = font(font_name) if font_name else None
    if f:
        cu.font = cu.font_bold = cu.font_italic = cu.font_bold_italic = f
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = bevel_res
    cu.align_x = align
    cu.align_y = valign
    cu.space_character = spacing
    cu.space_line = line_spacing
    cu.resolution_u = resolution
    ob = bpy.data.objects.new(name, cu)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    if m:
        cu.materials.append(m)
    if to_mesh:
        ob = apply_modifiers(ob)
    return ob


# ----------------------------------------------------------------------------- camera
def camera(loc=(0, -10, 4), target=(0, 0, 0), lens=50.0, name="Camera", fstop=None, focus=None, sensor=36.0,
           clip=(0.05, 2000.0), shift=(0.0, 0.0), ortho=None, roll=0.0, blades=7, active=True, coll=None):
    """Camera looking at target. fstop enables DOF focused on `focus` (object/point/distance; default target)."""
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.sensor_width = sensor
    cd.clip_start, cd.clip_end = clip
    cd.shift_x, cd.shift_y = shift
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    ob = bpy.data.objects.new(name, cd)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    look_at(ob, target, roll)
    if fstop:
        dof(ob, focus if focus is not None else target, fstop, blades)
    if active:
        bpy.context.scene.camera = ob
    return ob


def dof(cam, focus, fstop=2.8, blades=7, ratio=1.0):
    d = cam.data.dof
    d.use_dof = True
    d.aperture_fstop = fstop
    d.aperture_blades = blades
    d.aperture_ratio = ratio
    if isinstance(focus, bpy.types.Object):
        d.focus_object = focus
    elif isinstance(focus, (int, float)):
        d.focus_distance = float(focus)
    else:
        bpy.context.view_layer.update()
        fwd = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
        d.focus_distance = max(0.01, (Vector(focus) - cam.matrix_world.translation).dot(fwd))
    return d


def frame(cam, objs, margin=1.1, target=None):
    """Aim at target (default: bbox center) and dolly along the view axis until every bbox corner of objs
    fits the frustum (tight fit, not a bounding sphere). margin > 1 adds breathing room. Returns distance."""
    if not isinstance(objs, (list, tuple)):
        objs = [objs]
    mn, mx, c, s = bounds(objs)
    c = Vector(target) if target is not None else c
    look_at(cam, c)
    bpy.context.view_layer.update()
    q = cam.matrix_world.to_quaternion()
    f, rt, up = q @ Vector((0, 0, -1)), q @ Vector((1, 0, 0)), q @ Vector((0, 1, 0))
    sc = bpy.context.scene
    aspect = sc.render.resolution_x / sc.render.resolution_y
    ang = cam.data.angle
    th, tv = (math.tan(ang / 2), math.tan(ang / 2) / aspect) if aspect >= 1 else \
        (math.tan(ang / 2) * aspect, math.tan(ang / 2))
    pts = []
    for o in objs:
        if o.type in ("MESH", "CURVE", "FONT", "SURFACE", "META"):
            pts += [o.matrix_world @ Vector(b) for b in o.bound_box]
    need = 0.0
    for p in pts:
        d = p - c
        z = d.dot(f)
        need = max(need, abs(d.dot(rt)) * margin / th - z, abs(d.dot(up)) * margin / tv - z,
                   -z + cam.data.clip_start * 2)
    cam.location = c - f * need
    return need


def orbit(cam, center=(0, 0, 0), frames=None, turns=1.0, start_deg=0.0):
    """Parent camera to an empty at center and spin it (seamless loop: last frame != first)."""
    sc = bpy.context.scene
    f0, f1 = frames or (sc.frame_start, sc.frame_end)
    piv = empty("CamPivot", center)
    piv.rotation_euler.z = math.radians(start_deg)
    parent(cam, piv)
    key(piv, "rotation_euler", [(f0, (0, 0, math.radians(start_deg))),
                                (f1 + 1, (0, 0, math.radians(start_deg + 360 * turns)))], interp="LINEAR")
    return piv


# ----------------------------------------------------------------------------- animation
def fcurves(idb):
    ad = idb.animation_data
    if not ad or not ad.action:
        return []
    try:
        from bpy_extras.anim_utils import action_get_channelbag_for_slot
        cb = action_get_channelbag_for_slot(ad.action, ad.action_slot)
        if cb is not None:
            return list(cb.fcurves)
    except Exception:
        pass
    return list(getattr(ad.action, "fcurves", []))


def key(obj, path, pairs, interp="BEZIER", index=-1):
    """Keyframe obj.<path> with [(frame, value), ...]. interp: LINEAR / BEZIER / CONSTANT / ..."""
    for f, v in pairs:
        owner, attr = obj, path
        if "." in path:
            parts = path.split(".")
            for p in parts[:-1]:
                owner = getattr(owner, p)
            attr = parts[-1]
        if index >= 0:
            getattr(owner, attr)[index] = v
        else:
            setattr(owner, attr, v)
        obj.keyframe_insert(data_path=path, frame=f, index=index)
    for fc in fcurves(obj):
        if fc.data_path == path:
            for kp in fc.keyframe_points:
                kp.interpolation = interp
    return obj


# ----------------------------------------------------------------------------- compositor
def comp(bloom=0.3, bloom_threshold=1.5, bloom_size=0.5, bloom_smooth=0.2, fog_glow=0.0, fog_threshold=2.0,
         fog_size=0.5, streaks=0.0, streaks_n=4, streaks_threshold=3.0, vignette=0.25, vignette_soft=0.45,
         distortion=0.0, dispersion=0.0, saturation=1.0, contrast=0.0, mist=None, quality="HIGH"):
    """Post chain: [mist fog] -> bloom -> fog glow -> streaks -> sat/contrast -> lens distortion -> vignette.
    Strength values are 0..1. mist: dict(start=5, depth=60, color='#..', strength=0.6, falloff='QUADRATIC').
    Compositing happens in scene-linear before the AgX view transform."""
    sc = bpy.context.scene
    sc.use_nodes = True
    sc.render.compositor_device = "CPU"
    nt = sc.node_tree
    nt.nodes.clear()
    if mist:
        sc.view_layers[0].use_pass_mist = True
        w = sc.world or bpy.data.worlds.new("World")
        sc.world = w
        w.mist_settings.start = mist.get("start", 5.0)
        w.mist_settings.depth = mist.get("depth", 60.0)
        w.mist_settings.falloff = mist.get("falloff", "QUADRATIC")
    rl = nt.nodes.new("CompositorNodeRLayers")
    img = rl.outputs["Image"]
    L = nt.links
    if mist:
        mul = nt.nodes.new("CompositorNodeMath")
        mul.operation = "MULTIPLY"
        L.new(rl.outputs["Mist"], mul.inputs[0])
        mul.inputs[1].default_value = mist.get("strength", 0.6)
        mx = nt.nodes.new("CompositorNodeMixRGB")
        L.new(mul.outputs[0], mx.inputs[0])
        L.new(img, mx.inputs[1])
        mx.inputs[2].default_value = col(mist.get("color", "#8090a8"))
        img = mx.outputs[0]

    def glare(kind, strength, thr, size=None, extra=None):
        g = nt.nodes.new("CompositorNodeGlare")
        g.glare_type = kind
        g.quality = quality
        g.inputs["Threshold"].default_value = thr
        g.inputs["Strength"].default_value = strength
        if size is not None:
            g.inputs["Size"].default_value = size
        for k, v in (extra or {}).items():
            g.inputs[k].default_value = v
        L.new(img, g.inputs["Image"])
        return g.outputs["Image"]

    if bloom > 0:
        img = glare("BLOOM", bloom, bloom_threshold, bloom_size, {"Smoothness": bloom_smooth})
    if fog_glow > 0:
        img = glare("FOG_GLOW", fog_glow, fog_threshold, fog_size)
    if streaks > 0:
        img = glare("STREAKS", streaks, streaks_threshold, None, {"Streaks": streaks_n, "Fade": 0.9})
    if saturation != 1.0:
        hs = nt.nodes.new("CompositorNodeHueSat")
        L.new(img, hs.inputs["Image"])
        hs.inputs["Saturation"].default_value = saturation
        img = hs.outputs["Image"]
    if contrast:
        bc = nt.nodes.new("CompositorNodeBrightContrast")
        L.new(img, bc.inputs["Image"])
        bc.inputs["Contrast"].default_value = contrast
        img = bc.outputs["Image"]
    if distortion or dispersion:
        ld = nt.nodes.new("CompositorNodeLensdist")
        L.new(img, ld.inputs["Image"])
        ld.inputs["Distortion"].default_value = distortion
        ld.inputs["Dispersion"].default_value = dispersion
        ld.inputs["Fit"].default_value = distortion < 0
        img = ld.outputs["Image"]
    if vignette > 0:
        em = nt.nodes.new("CompositorNodeEllipseMask")
        em.inputs["Size"].default_value = (1.0 - vignette_soft * 0.3, 1.0 - vignette_soft * 0.3)
        em.inputs["Mask"].default_value = 0.0
        em.inputs["Value"].default_value = 1.0
        bl_ = nt.nodes.new("CompositorNodeBlur")
        bl_.filter_type = "FAST_GAUSS"
        px = vignette_soft * min(sc.render.resolution_x, sc.render.resolution_y) * sc.render.resolution_percentage / 100
        bl_.inputs["Size"].default_value = (px, px)
        bl_.inputs["Extend Bounds"].default_value = False
        L.new(em.outputs["Mask"], bl_.inputs["Image"])
        mx = nt.nodes.new("CompositorNodeMixRGB")
        mx.blend_type = "MULTIPLY"
        mx.inputs[0].default_value = vignette
        L.new(img, mx.inputs[1])
        L.new(bl_.outputs["Image"], mx.inputs[2])
        img = mx.outputs[0]
    out = nt.nodes.new("CompositorNodeComposite")
    L.new(img, out.inputs["Image"])
    return nt


def comp_off():
    bpy.context.scene.use_nodes = False


# ----------------------------------------------------------------------------- rendering / video
def render(path, samples=None, pct=None, res=None):
    """Render still to PNG. Temporary overrides for samples/pct/res. Returns seconds."""
    sc = bpy.context.scene
    if sc.camera is None:
        raise RuntimeError("no active camera")
    saved = (sc.cycles.samples, sc.render.resolution_percentage, sc.render.resolution_x, sc.render.resolution_y)
    if samples:
        sc.cycles.samples = samples
    if pct:
        sc.render.resolution_percentage = pct
    if res:
        sc.render.resolution_x, sc.render.resolution_y = res
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sc.render.filepath = path
    t = time.time()
    bpy.ops.render.render(write_still=True)
    dt = time.time() - t
    w = sc.render.resolution_x * sc.render.resolution_percentage // 100
    h = sc.render.resolution_y * sc.render.resolution_percentage // 100
    log(f"render {os.path.basename(path)} {w}x{h} @{sc.cycles.samples}spp: {dt:.1f}s")
    sc.cycles.samples, sc.render.resolution_percentage, sc.render.resolution_x, sc.render.resolution_y = saved
    return dt


def render_anim(out_dir, start=None, end=None, prefix="f_", clean=True, step=1):
    """Render frames to out_dir/prefix####.png (persistent data + animated seed). Returns (pattern, n, secs)."""
    sc = bpy.context.scene
    if clean and os.path.isdir(out_dir):
        for f in glob.glob(os.path.join(out_dir, prefix + "*.png")):
            os.remove(f)
    os.makedirs(out_dir, exist_ok=True)
    s0, e0, st0 = sc.frame_start, sc.frame_end, sc.frame_step
    if start is not None:
        sc.frame_start = start
    if end is not None:
        sc.frame_end = end
    sc.frame_step = step
    sc.render.filepath = os.path.join(out_dir, prefix + "####")
    sc.render.image_settings.file_format = "PNG"
    sc.render.use_persistent_data = True
    sc.cycles.use_animated_seed = True
    t = time.time()
    bpy.ops.render.render(animation=True)
    dt = time.time() - t
    n = len(glob.glob(os.path.join(out_dir, prefix + "*.png")))
    log(f"anim {n} frames: {dt:.1f}s ({dt / max(n, 1):.2f}s/frame)")
    sc.frame_start, sc.frame_end, sc.frame_step = s0, e0, st0
    return os.path.join(out_dir, prefix + "%04d.png"), n, dt


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def encode(frames, out, fps=24, crf=None, width=None, prefix="f_"):
    """Encode PNG sequence (dir or printf pattern) -> .mp4 (H.264 yuv420p) / .webm (VP9) / .gif / .webp."""
    if os.path.isdir(frames):
        files = sorted(glob.glob(os.path.join(frames, prefix + "*.png")))
        if not files:
            raise FileNotFoundError(frames)
        first = os.path.basename(files[0])
        digits = len(first) - len(prefix) - 4
        start = int(first[len(prefix):len(prefix) + digits])
        pattern = os.path.join(frames, f"{prefix}%0{digits}d.png")
    else:
        pattern = frames
        files = sorted(glob.glob(pattern.replace("%04d", "????")))
        start = int(os.path.basename(files[0])[-8:-4]) if files else 0
    ext = out.rsplit(".", 1)[-1].lower()
    sc_ = f"scale={width}:-2:flags=lanczos" if width else "scale=trunc(iw/2)*2:trunc(ih/2)*2"
    cmd = [ffmpeg(), "-y", "-loglevel", "error", "-framerate", str(fps), "-start_number", str(start), "-i", pattern]
    if ext == "mp4":
        cmd += ["-vf", sc_, "-c:v", "libx264", "-preset", "slow", "-crf", str(crf or 18), "-pix_fmt", "yuv420p",
                "-movflags", "+faststart"]
    elif ext == "webm":
        cmd += ["-vf", sc_, "-c:v", "libvpx-vp9", "-crf", str(crf or 30), "-b:v", "0", "-pix_fmt", "yuv420p",
                "-row-mt", "1", "-deadline", "good", "-cpu-used", "2"]
    elif ext == "gif":
        w = width or 480
        cmd += ["-vf", f"scale={w}:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];"
                       f"[b][p]paletteuse=dither=bayer:bayer_scale=4", "-loop", "0"]
    elif ext == "webp":
        cmd += ["-vf", sc_, "-c:v", "libwebp_anim", "-q:v", "80", "-loop", "0"]
    else:
        raise ValueError(ext)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    t = time.time()
    subprocess.run(cmd + [out], check=True)
    log(f"encoded {os.path.basename(out)} ({os.path.getsize(out) / 1e6:.2f} MB) in {time.time() - t:.1f}s")
    return out


def montage(paths, out, cols=2, tile_w=640, bg="0x101216", pad=0, labels=None, label_size=None):
    """Grid contact sheet (cells sized from the first image's aspect). labels: captions drawn with Pillow."""
    import struct
    with open(paths[0], "rb") as f:
        hdr = f.read(24)
    w0, h0 = struct.unpack(">II", hdr[16:24])
    th = int(round(tile_w * h0 / w0 / 2)) * 2
    n = len(paths)
    rows = (n + cols - 1) // cols
    cmd = [ffmpeg(), "-y", "-loglevel", "error"]
    for p in paths:
        cmd += ["-i", p]
    fl = []
    for i in range(n):
        fl.append(f"[{i}:v]scale={tile_w}:{th}:force_original_aspect_ratio=decrease,"
                  f"pad={tile_w + pad}:{th + pad}:(ow-iw)/2:(oh-ih)/2:color={bg}[v{i}]")
    if n == 1:
        fc = fl[0]
        mp = "[v0]"
    else:
        layout = "|".join(f"{(i % cols) * (tile_w + pad)}_{(i // cols) * (th + pad)}" for i in range(n))
        fc = ";".join(fl) + ";" + "".join(f"[v{i}]" for i in range(n)) + \
            f"xstack=inputs={n}:layout={layout}:fill={bg}[m]"
        mp = "[m]"
    subprocess.run(cmd + ["-filter_complex", fc, "-map", mp, "-frames:v", "1", out], check=True)
    if labels:
        from PIL import Image, ImageDraw, ImageFont
        im = Image.open(out).convert("RGB")
        dr = ImageDraw.Draw(im)
        fs = label_size or max(12, tile_w // 28)
        ft = ImageFont.truetype(os.path.join(FONTS, "Outfit-Bold.ttf"), fs)
        for i, lab in enumerate(labels[:n]):
            x = (i % cols) * (tile_w + pad) + fs // 2
            y = (i // cols) * (th + pad) + fs // 2
            dr.text((x, y), str(lab), font=ft, fill=(255, 255, 255), stroke_width=max(1, fs // 8),
                    stroke_fill=(0, 0, 0))
        im.save(out)
    return out


def save_blend(path, pack=True):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    if pack:
        try:
            bpy.ops.file.pack_all()
        except Exception as e:
            log("pack_all failed:", e)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    return path


# ----------------------------------------------------------------------------- UV / baking
def uv_smart(obj, angle=66.0, margin=0.01, area_weight=0.0):
    """Fresh single UV map via Smart UV Project (islands packed into 0..1)."""
    me = obj.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    select_only(obj)
    with bpy.context.temp_override(active_object=obj, object=obj, edit_object=obj):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=area_weight,
                                 correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def _socket_src(sock, fallback=(0.0, 0.0, 0.0, 1.0)):
    if sock is None:
        return None, fallback
    if sock.is_linked:
        return sock.links[0].from_socket, None
    dv = sock.default_value
    try:
        v = tuple(dv)
        v = (v + (1.0,))[:4] if len(v) == 3 else v[:4]
    except TypeError:
        v = (float(dv),) * 3 + (1.0,)
    return None, v


def _bake_rule(n, mode):
    """What value an arbitrary shader node contributes to a PBR map (emission trick)."""
    I = n.inputs
    g = lambda nm: I[nm] if nm in I else None  # noqa: E731
    idn = n.bl_idname
    if idn == "ShaderNodeBsdfPrincipled":
        if mode == "albedo":
            return _socket_src(g("Base Color"))
        if mode == "roughness":
            return _socket_src(g("Roughness"))
        if mode == "metallic":
            return _socket_src(g("Metallic"))
        if mode == "emission":
            s = g("Emission Strength")
            if not s.is_linked and s.default_value <= 0:
                return None, (0, 0, 0, 1)
            return _socket_src(g("Emission Color"))
    if idn == "ShaderNodeEmission":
        if mode in ("albedo", "emission"):
            s = g("Strength")
            if mode == "emission" and not s.is_linked and s.default_value <= 0:
                return None, (0, 0, 0, 1)
            return _socket_src(g("Color"))
        return None, ((1, 1, 1, 1) if mode == "roughness" else (0, 0, 0, 1))
    if mode == "albedo":
        return _socket_src(g("Color") or g("Base Color"), (0.5, 0.5, 0.5, 1))
    if mode == "roughness":
        return _socket_src(g("Roughness"), (0.5, 0.5, 0.5, 1))
    if mode == "metallic":
        return None, ((1, 1, 1, 1) if idn in ("ShaderNodeBsdfMetallic",) else (0, 0, 0, 1))
    return None, (0, 0, 0, 1)


def _emit_trick(m, mode):
    """In-place: replace every shader node's output with an Emission of the requested property."""
    nt = m.node_tree
    skip = {"ShaderNodeMixShader", "ShaderNodeAddShader", "ShaderNodeOutputMaterial"}
    shaders = [n for n in nt.nodes if n.bl_idname not in skip and n.outputs and n.outputs[0].type == "SHADER"]
    for s in shaders:
        e = nt.nodes.new("ShaderNodeEmission")
        e.inputs["Strength"].default_value = 1.0
        src, const = _bake_rule(s, mode)
        if src is not None:
            nt.links.new(src, e.inputs["Color"])
        else:
            e.inputs["Color"].default_value = const
        targets = [l.to_socket for l in s.outputs[0].links]
        for l in list(s.outputs[0].links):
            nt.links.remove(l)
        for t in targets:
            nt.links.new(e.outputs[0], t)
    for n in nt.nodes:  # displacement would move the bake surface
        if n.bl_idname == "ShaderNodeOutputMaterial":
            for l in list(n.inputs["Displacement"].links):
                nt.links.remove(l)


BAKE_COLOR_MAPS = ("albedo", "emission")


def bake_pbr(obj, out_dir, size=1024, maps=("albedo", "roughness", "metallic", "normal", "emission"), source=None,
             name=None, extrusion=0.02, max_ray=0.0, margin=8, ao=0.0, ao_samples=48, ao_distance=None,
             reuv=True, uv_margin=0.008, assign_baked=True, keep_uv=False, isolate=True):
    """Bake PBR maps to <=size PNGs (Roblox SurfaceAppearance-ready).
    obj: low-poly target (modifiers applied, re-UV'd with Smart UV unless keep_uv).
    source: optional high-poly object -> selected-to-active bake (normals/colors from high).
    ao>0 multiplies a baked AO into albedo (0..1 amount). Returns {map: path, 'material': baked material}."""
    bpy.context.view_layer.update()  # refresh stale matrix_world / bound_box of new or moved objects
    sc = bpy.context.scene
    name = name or obj.name
    os.makedirs(out_dir, exist_ok=True)
    if obj.modifiers or obj.type != "MESH":
        obj = apply_modifiers(obj)
    if reuv and not keep_uv:
        uv_smart(obj, margin=uv_margin)
    if not obj.data.materials or not any(obj.data.materials):
        obj.data.materials.clear()
        obj.data.materials.append(mat(name + "_tmp"))
    saved = dict(engine=sc.render.engine, samples=sc.cycles.samples, dn=sc.cycles.use_denoising,
                 ad=sc.cycles.use_adaptive_sampling)
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.cycles.use_adaptive_sampling = False
    src_obj = source or obj
    hidden = []
    if isolate:  # other geometry must not occlude AO / catch rays (e.g. originals overlapping a copy)
        for o in sc.objects:
            if o not in (obj, source) and not o.hide_render and o.type in ("MESH", "CURVE", "FONT", "SURFACE", "META"):
                o.hide_render = True
                hidden.append(o)
    results = {}
    order = list(maps)
    if ao and "ao" not in order:
        order.append("ao")
    t_all = time.time()
    for mp in order:
        t = time.time()
        img = bpy.data.images.new(f"{name}_{mp}", size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = "sRGB" if mp in BAKE_COLOR_MAPS else "Non-Color"
        img.generated_color = (0.5, 0.5, 1.0, 1.0) if mp == "normal" else (0, 0, 0, 1)
        # temp material copies on the source for the emission trick
        swaps = []
        if mp in ("albedo", "roughness", "metallic", "emission"):
            for slot in src_obj.material_slots:
                if slot.material:
                    orig = slot.material
                    tmp = orig.copy()
                    _emit_trick(tmp, mp)
                    swaps.append((slot, orig, tmp))
                    slot.material = tmp
        # image node active in every target material
        added = []
        for slot in obj.material_slots:
            m = slot.material
            if m is None:
                continue
            nt = _nt(m)
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = img
            nt.nodes.active = tn
            tn.select = True
            added.append((m, tn))
        btype = {"normal": "NORMAL", "ao": "AO"}.get(mp, "EMIT")
        sc.cycles.samples = {"ao": ao_samples, "normal": 4}.get(mp, 1)
        if mp == "ao":
            w = sc.world or bpy.data.worlds.new("World")
            sc.world = w
            w.light_settings.distance = ao_distance or max(0.05, 0.15 * max(obj.dimensions))
        if source:
            select_only(obj, source)
            source.select_set(True)
        else:
            select_only(obj)
        bpy.context.view_layer.objects.active = obj
        sc.render.bake.margin_type = "EXTEND"
        bpy.ops.object.bake(type=btype, margin=margin, margin_type="EXTEND", use_selected_to_active=bool(source),
                            cage_extrusion=extrusion, max_ray_distance=max_ray, use_clear=True,
                            target="IMAGE_TEXTURES", normal_space="TANGENT")
        for m, tn in added:
            m.node_tree.nodes.remove(tn)
        for slot, orig, tmp in swaps:
            slot.material = orig
            bpy.data.materials.remove(tmp)
        results[mp] = img
        log(f"bake {name}:{mp} {size}px {time.time() - t:.1f}s")
    if ao and "albedo" in results:
        import numpy as np
        a = results["albedo"]
        o = results["ao"]
        pa = np.empty(size * size * 4, np.float32)
        po = np.empty(size * size * 4, np.float32)
        a.pixels.foreach_get(pa)
        o.pixels.foreach_get(po)
        pa = pa.reshape(-1, 4)
        po = po.reshape(-1, 4)
        lin = np.where(pa[:, :3] <= 0.04045, pa[:, :3] / 12.92, ((pa[:, :3] + 0.055) / 1.055) ** 2.4)
        lin *= (1 - ao) + ao * po[:, :1]
        pa[:, :3] = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(np.maximum(lin, 0), 1 / 2.4) - 0.055)
        a.pixels.foreach_set(pa.ravel())
        a.update()
    paths = {}
    for mp, img in results.items():
        p = os.path.join(out_dir, f"{name}_{mp}.png")
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
        img.filepath = p
        paths[mp] = p
    for o in hidden:
        o.hide_render = False
    sc.render.engine = saved["engine"]
    sc.cycles.samples = saved["samples"]
    sc.cycles.use_denoising = saved["dn"]
    sc.cycles.use_adaptive_sampling = saved["ad"]
    log(f"bake {name} total {time.time() - t_all:.1f}s")
    if assign_baked:
        paths["material"] = baked_material(obj, results, name)
    paths["object"] = obj
    return paths


def baked_material(obj, imgs, name):
    """Replace obj's materials with one Principled driven by the baked images."""
    m = bpy.data.materials.new(name + "_baked")
    m.use_backface_culling = True  # glTF doubleSided=false (Roblox MeshPart default)
    nt = _nt(m)
    p = nt.nodes.get("Principled BSDF")

    def tex(key, cs):
        if key not in imgs:
            return None
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = imgs[key]
        t.image.colorspace_settings.name = cs
        return t

    t = tex("albedo", "sRGB")
    if t:
        nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
    t = tex("roughness", "Non-Color")
    if t:
        nt.links.new(t.outputs["Color"], p.inputs["Roughness"])
    t = tex("metallic", "Non-Color")
    if t:
        nt.links.new(t.outputs["Color"], p.inputs["Metallic"])
    t = tex("normal", "Non-Color")
    if t:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    t = tex("emission", "sRGB")
    if t:
        nt.links.new(t.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = 1.0
    obj.data.materials.clear()
    obj.data.materials.append(m)
    for poly in obj.data.polygons:
        poly.material_index = 0
    return m


# ----------------------------------------------------------------------------- export (Roblox)
IMPORT_NOTE = ("Roblox Studio > Import 3D: geometry is authored in METERS (1 stud = 0.28 m). Set File Dimensions = "
               "Meters so Studio converts (studs = meters / 0.28; see dims_studs). If exported with unit='studs' the "
               "numbers are already studs -> set File Dimensions = Studs. Y-up, -Z forward, transforms applied, "
               "pivot = base center. Textures: SurfaceAppearance ColorMap=albedo, NormalMap=normal (OpenGL +Y tangent "
               "space), RoughnessMap=roughness, MetalnessMap=metallic; emission PNG is an optional glow mask.")


def export_roblox(objs, out_base, unit="meters", fbx=True, glb=True, max_tris=20000, pivot="base", center=True,
                  textures=None, names=None):
    """Export objects as Roblox-ready FBX + GLB (+ JSON report). Works on temporary copies: modifiers applied,
    text/curves converted, transforms applied, origin at base-center, Y-up. unit: 'meters' or 'studs'."""
    if not isinstance(objs, (list, tuple)):
        objs = [objs]
    os.makedirs(os.path.dirname(os.path.abspath(out_base)), exist_ok=True)
    sc = bpy.context.scene
    tmpc = collection("__export_tmp")
    """names: optional list of export names (default: object names)."""
    bpy.context.view_layer.update()  # refresh stale matrix_world / bound_box of new or moved objects
    orig_names, dupes = [], []
    for i, o in enumerate(objs):
        nm = names[i] if names else o.name
        orig_names.append((o, o.name))
        o.name = o.name + "__src"
        clash = bpy.data.objects.get(nm)
        if clash is not None:  # free the export name temporarily
            orig_names.append((clash, clash.name))
            clash.name = nm + "__tmpclash"
        mw = o.matrix_world.copy()
        d = o.copy()
        if o.data is not None:
            d.data = o.data.copy()
        d.name = nm
        d.parent = None
        d.animation_data_clear()
        tmpc.objects.link(d)
        d.matrix_world = mw
        dupes.append(d)
    out = []
    for d in dupes:
        nm = d.name
        d = apply_modifiers(d)
        d.name = nm
        me = d.data
        me.name = nm
        me.transform(d.matrix_world)
        if d.matrix_world.determinant() < 0:
            me.flip_normals()
        d.matrix_world = Matrix.Identity(4)
        if unit == "studs":
            me.transform(Matrix.Scale(1 / STUD_M, 4))
        out.append(d)
    if pivot == "base":
        if len(out) == 1:
            origin_to_base(out[0])
            if center:
                out[0].location = (0, 0, 0)
        else:
            mn, mx, c, s = bounds(out)
            for d in out:
                origin_to_base(d)
                if center:
                    d.location -= Vector((c.x, c.y, mn.z))
    bpy.context.view_layer.update()
    report = {"unit": unit, "note": IMPORT_NOTE, "objects": {}, "files": {}}
    k = STUD_M if unit == "meters" else 1.0
    for d in out:
        tris = tri_count(d)
        dims = d.dimensions
        report["objects"][d.name] = {
            "tris": tris, "ok_tris": tris <= max_tris,
            "dims_blender_xyz": [round(v, 4) for v in dims],
            "dims_m_WxDxH": [round(v * (1 if unit == "meters" else STUD_M), 4) for v in dims],
            "dims_studs_WxDxH": [round(v / k if unit == "meters" else v, 3) for v in dims],
            "materials": [m.name for m in d.data.materials if m]}
        if tris > max_tris:
            log(f"WARNING {d.name}: {tris} tris > {max_tris}")
    select_only(*out)
    if fbx:
        p = out_base + ".fbx"
        bpy.ops.export_scene.fbx(filepath=p, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                                 apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", global_scale=1.0,
                                 axis_forward="-Z", axis_up="Y", bake_space_transform=True, mesh_smooth_type="FACE",
                                 use_tspace=True, use_triangles=True, add_leaf_bones=False, bake_anim=False,
                                 path_mode="COPY", embed_textures=True, use_custom_props=False)
        report["files"]["fbx"] = p
    if glb:
        p = out_base + ".glb"
        bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_texcoords=True, export_normals=True,
                                  export_tangents=False, export_materials="EXPORT", export_image_format="AUTO",
                                  export_animations=False, export_extras=False)
        report["files"]["glb"] = p
    if textures:
        report["textures"] = {k2: v for k2, v in textures.items() if isinstance(v, str)}
    with open(out_base + ".json", "w") as f:
        json.dump(report, f, indent=2)
    report["files"]["json"] = out_base + ".json"
    for d in out:
        delete(d)
    bpy.data.collections.remove(tmpc)
    for o, nm in reversed(orig_names):
        o.name = nm
    for k2, v in report["files"].items():
        log(f"export {k2}: {v} ({os.path.getsize(v) / 1e3:.0f} KB)")
    return report


def roblox_asset(objs, out_dir, name, max_tris=20000, tex=1024, maps=("albedo", "roughness", "metallic", "normal",
                 "emission"), unit="meters", ao=0.35, hide=True):
    """One-shot: copy+join objs -> (decimate to budget, baking high->low if needed) -> Smart UV -> bake PBR PNGs
    -> baked material -> FBX + GLB + JSON. Originals untouched; the low-poly lands in collection 'RobloxExport'."""
    bpy.context.view_layer.update()  # refresh stale matrix_world / bound_box of new or moved objects
    if not isinstance(objs, (list, tuple)):
        objs = [objs]
    exc = collection("RobloxExport")
    copies = []
    for o in objs:
        d = o.copy()
        if o.data is not None:
            d.data = o.data.copy()
        d.parent = None
        exc.objects.link(d)
        d.matrix_world = o.matrix_world.copy()
        copies.append(apply_modifiers(d))
    high = join(copies, name + "_high") if len(copies) > 1 else copies[0]
    high.name = name + "_high"
    ntri = tri_count(high)
    if ntri > max_tris:
        low = high.copy()
        low.data = high.data.copy()
        exc.objects.link(low)
        low.name = name + "_rbx"
        decimate_to(low, max_tris)
        src = high
    else:
        low, src = high, None
        low.name = name + "_rbx"
    tdir = os.path.join(out_dir, "textures")
    res = bake_pbr(low, tdir, size=tex, maps=maps, source=src, name=name, ao=ao)
    low = res["object"]
    rep = export_roblox([low], os.path.join(out_dir, name), unit=unit, max_tris=max_tris, names=[name],
                        textures={k: v for k, v in res.items() if isinstance(v, str)})
    if src is not None:
        delete(src)
    exc.hide_render = hide
    rep["source_tris"] = ntri
    with open(os.path.join(out_dir, name + ".json"), "w") as f:
        json.dump({k: v for k, v in rep.items()}, f, indent=2)
    return rep, low
