"""Peckwood VFX: rendered toon flipbooks (Blender headless, EEVEE Next) -> 4x4 sheets with alpha.

    "C:/Program Files/Blender Foundation/Blender 4.4/blender.exe" -b --factory-startup \
        --python roblox/tools/vfx/gen_toon_flipbooks.py -- [toon_smoke toon_burst dust_puff]
    python roblox/tools/vfx/gen_toon_flipbooks.py --post      # (run automatically) assemble sheets from the frames

Each puff is a cluster of noise-displaced sphere lobes animated per frame (bloom out with an overshoot, drift, then
lobes melt away one by one). Shading is a 3-step toon ramp computed from N.L (deterministic, no light falloff):
white core / mid / shadow, constant interpolation. Ink = an inverted hull (Solidify, flipped normals, backface-culled
ink material) kept at a constant world width as the lobes scale. A PIL pass then dissolves the late frames with a noise
threshold and re-inks the rim of every hole, keeps a gutter round each frame, bleeds RGB under alpha and writes the
4x4 sheet to roblox/assets/vfx/<key>.png + its manifest entry.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "vfx")
FRAMES_DIR = os.path.join(HERE, "_frames")
N = 16
RES = 512  # rendered per frame, downsampled to 256 in the sheet

INK = (22 / 255, 24 / 255, 30 / 255)


def srgb_to_lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def ease_out(t, p=3):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** p


def ease_back(t, s=1.7):
    t = min(max(t, 0.0), 1.0)
    return 1 + (s + 1) * (t - 1) ** 3 + s * (t - 1) ** 2


# ------------------------------------------------------------------------------------------------ puff designs
# lobes: (x, z, depth y, radius, melt start) in a unit frame; motion functions return per-frame transforms
def smoke_frame(f, lobes):
    g = 0.42 + 0.58 * ease_back(min(1, f / 0.32), 1.6) + 0.34 * max(0, f - 0.32)
    out = []
    for i, (x, z, y, r, melt) in enumerate(lobes):
        m = 1.0 if f < melt else max(0.0, 1 - ((f - melt) / (1 - melt + 1e-6)) ** 1.5)
        out.append(((x * g, y, z * g + 0.2 * f), r * g * m, f * 1.3 + i))
    return out


def burst_frame(f, lobes):
    out = []
    for i, (x, z, y, r, melt) in enumerate(lobes):
        reach = 0.62 * ease_out(min(1, f / 0.32), 3) * (1 + 0.18 * f)
        s = 0.28 + 0.72 * ease_back(min(1, f / 0.28), 1.4)
        m = 1.0 if f < melt else max(0.0, 1 - ((f - melt) / (1 - melt + 1e-6)) ** 1.4)
        out.append(((x * reach, y, z * reach + 0.08 * f), r * s * m, f * 1.4 + i))
    return out


def dust_frame(f, lobes):
    out = []
    for i, (x, z, y, r, melt) in enumerate(lobes):
        spread = 0.35 + 0.75 * ease_out(min(1, f / 0.4), 2)
        s = 0.35 + 0.65 * ease_back(min(1, f / 0.3), 1.3)
        m = 1.0 if f < melt else max(0.0, 1 - ((f - melt) / (1 - melt + 1e-6)) ** 1.3)
        out.append(((x * spread, y, z + 0.1 * f * (0.5 + abs(x))), r * s * m, f * 0.4 + i))
    return out


DESIGNS = {
    "toon_smoke": dict(
        lobes=[(0.0, 0.04, 0.0, 0.38, 0.5), (-0.34, 0.12, 0.05, 0.27, 0.58), (0.35, 0.1, -0.04, 0.29, 0.46),
               (-0.16, -0.22, 0.08, 0.28, 0.66), (0.18, -0.2, -0.06, 0.26, 0.54), (0.02, -0.38, 0.0, 0.2, 0.72),
               (-0.02, 0.28, 0.1, 0.25, 0.42)],
        motion=smoke_frame, squash_z=1.0, ortho=2.15,
        light=(1.0, 0.99, 0.97), mid=(0.87, 0.86, 0.94), shadow=(0.72, 0.71, 0.85), ink_w=0.045,
        steps=(0.36, 0.68), dissolve=(0.48, 1.0), hot=0,
        use="toon smoke puff (Blender): hatch smoke ring, poofs"),
    "toon_burst": dict(
        lobes=[(0.0, 0.02, 0.0, 0.4, 0.56), (0.1, -0.12, -0.15, 0.3, 0.5)] + [
            (math.cos(a) * rr, math.sin(a) * rr * 0.86, 0.15 * math.sin(3 * a + 1), rad, melt)
            for a, rr, rad, melt in [
                (0.25, 0.95, 0.31, 0.5), (0.95, 0.7, 0.26, 0.58), (1.6, 1.05, 0.3, 0.46), (2.35, 0.8, 0.24, 0.62),
                (2.9, 1.0, 0.33, 0.52), (3.7, 0.72, 0.27, 0.44), (4.35, 1.08, 0.28, 0.6), (5.0, 0.85, 0.32, 0.48),
                (5.7, 0.62, 0.22, 0.56), (1.25, 1.35, 0.16, 0.4), (3.3, 1.4, 0.15, 0.42), (5.35, 1.3, 0.17, 0.38)]],
        motion=burst_frame, squash_z=1.0, ortho=2.25,
        light=(1.0, 1.0, 1.0), mid=(0.8, 0.8, 0.8), shadow=(0.56, 0.56, 0.56), ink_w=0.05,
        steps=(0.36, 0.68), dissolve=(0.45, 1.0), hot=2,
        use="toon impact burst (Blender, greyscale: tint pastel per rarity): hatch crack cloud"),
    "dust_puff": dict(
        lobes=[(0.0, -0.08, 0.0, 0.3, 0.5), (-0.42, -0.14, 0.06, 0.24, 0.42), (0.44, -0.12, -0.05, 0.25, 0.46),
               (-0.22, 0.04, -0.08, 0.22, 0.58), (0.24, 0.06, 0.08, 0.21, 0.54), (-0.62, -0.2, 0.0, 0.17, 0.36),
               (0.64, -0.18, 0.02, 0.18, 0.4)],
        motion=dust_frame, squash_z=0.62, ortho=2.0,
        light=(1.0, 0.98, 0.94), mid=(0.86, 0.82, 0.76), shadow=(0.7, 0.65, 0.6), ink_w=0.035,
        steps=(0.36, 0.66), dissolve=(0.45, 1.0), hot=0,
        use="soft toon dust puff (Blender, warm grey: tint per island): ground bursts, coast dust"),
}


# ------------------------------------------------------------------------------------------------ blender side
def render(keys):
    import bpy

    for key in keys:
        d = DESIGNS[key]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE_NEXT"
        sc.render.resolution_x = sc.render.resolution_y = RES
        sc.render.film_transparent = True
        sc.render.image_settings.file_format = "PNG"
        sc.render.image_settings.color_mode = "RGBA"
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        try:
            sc.eevee.taa_render_samples = 16
        except AttributeError:
            pass
        world = bpy.data.worlds.new("w")
        sc.world = world
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
        bpy.ops.object.camera_add(location=(0, -10, 0), rotation=(math.pi / 2, 0, 0))
        cam = bpy.context.object
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = d["ortho"]
        sc.camera = cam

        # toon material: N.L -> constant 3-step ramp -> emission
        def toon_material():
            m = bpy.data.materials.new(key + "_toon")
            m.use_nodes = True
            nt = m.node_tree
            nt.nodes.clear()
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            ldir = nt.nodes.new("ShaderNodeCombineXYZ")
            lx, ly, lz = -0.55, -0.5, 0.67  # from upper-left-front
            ll = math.sqrt(lx * lx + ly * ly + lz * lz)
            ldir.inputs[0].default_value = lx / ll
            ldir.inputs[1].default_value = ly / ll
            ldir.inputs[2].default_value = lz / ll
            dot = nt.nodes.new("ShaderNodeVectorMath")
            dot.operation = "DOT_PRODUCT"
            mad = nt.nodes.new("ShaderNodeMath")
            mad.operation = "MULTIPLY_ADD"
            mad.inputs[1].default_value = 0.5
            mad.inputs[2].default_value = 0.5
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            els = ramp.color_ramp.elements
            els[0].position = 0.0
            els[0].color = (*srgb_to_lin(d["shadow"]), 1)
            els[1].position = d["steps"][0]
            els[1].color = (*srgb_to_lin(d["mid"]), 1)
            e3 = els.new(d["steps"][1])
            e3.color = (*srgb_to_lin(d["light"]), 1)
            em = nt.nodes.new("ShaderNodeEmission")
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(geo.outputs["Normal"], dot.inputs[0])
            nt.links.new(ldir.outputs[0], dot.inputs[1])
            nt.links.new(dot.outputs["Value"], mad.inputs[0])
            nt.links.new(mad.outputs[0], ramp.inputs[0])
            nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            m.use_backface_culling = True
            return m, ramp

        def ink_material():
            m = bpy.data.materials.new(key + "_ink")
            m.use_nodes = True
            nt = m.node_tree
            nt.nodes.clear()
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (*srgb_to_lin(INK), 1)
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            m.use_backface_culling = True
            return m

        toon, ramp = toon_material()
        ink = ink_material()
        tex = bpy.data.textures.new(key + "_clouds", "CLOUDS")
        tex.noise_scale = 0.55
        lobes = []
        for i, _ in enumerate(d["lobes"]):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0)
            ob = bpy.context.object
            bpy.ops.object.shade_smooth()
            ob.data.materials.append(toon)
            ob.data.materials.append(ink)
            disp = ob.modifiers.new("disp", "DISPLACE")
            disp.texture = tex
            disp.strength = 0.16
            disp.mid_level = 0.5
            disp.texture_coords = "OBJECT"
            sol = ob.modifiers.new("hull", "SOLIDIFY")
            sol.offset = 1.0
            sol.use_flip_normals = True
            sol.material_offset = 1
            sol.use_rim = False
            lobes.append(ob)
        os.makedirs(os.path.join(FRAMES_DIR, key), exist_ok=True)
        for k in range(N):
            f = k / (N - 1)
            hot = k < d["hot"]
            els = ramp.color_ramp.elements
            if hot:  # white-hot first frames, then the toon ramp
                for el in els:
                    el.color = (1, 1, 1, 1)
            else:
                els[0].color = (*srgb_to_lin(d["shadow"]), 1)
                els[1].color = (*srgb_to_lin(d["mid"]), 1)
                els[2].color = (*srgb_to_lin(d["light"]), 1)
            for ob, (pos, r, spin) in zip(lobes, d["motion"](f, d["lobes"])):
                r = max(r, 1e-4)
                ob.location = pos
                ob.scale = (r, r, r * d["squash_z"])
                ob.rotation_euler = (spin * 0.7, spin * 0.4, spin)
                ob.hide_render = r < 0.01
                ob.modifiers["hull"].thickness = d["ink_w"] / r  # constant ink width in world units
            sc.render.filepath = os.path.join(FRAMES_DIR, key, "f%02d.png" % k)
            bpy.ops.render.render(write_still=True)
        print("rendered", key)


# ------------------------------------------------------------------------------------------------ post (PIL)
def post(keys):
    import numpy as np
    from PIL import Image
    from scipy import ndimage

    sys.path.insert(0, HERE)
    from gen_vfx import bleed  # same RGB bleed as the PIL textures

    man_path = os.path.join(OUT, "manifest.json")
    man = json.load(open(man_path)) if os.path.exists(man_path) else {}
    rng = np.random.default_rng(23)
    # smooth noise field (upsampled random grid) for the dissolve
    base = rng.random((12, 12))
    noise = np.asarray(Image.fromarray((base * 255).astype(np.uint8)).resize((256, 256), Image.BICUBIC)).astype(np.float32) / 255
    noise = (noise - noise.min()) / (noise.max() - noise.min())
    for key in keys:
        d = DESIGNS[key]
        frames = []
        for k in range(N):
            f = k / (N - 1)
            im = Image.open(os.path.join(FRAMES_DIR, key, "f%02d.png" % k)).convert("RGBA")
            im = im.resize((256, 256), Image.LANCZOS)
            a = np.asarray(im).astype(np.float32) / 255
            # gutter: shrink content that reaches the frame edge (keep it inside 92 %)
            ds0, ds1 = d["dissolve"]
            if f > ds0:
                th = (f - ds0) / (ds1 - ds0)
                hole = noise < th * 1.05
                vis = a[..., 3] > 0.5
                rim = (ndimage.distance_transform_edt(~hole) <= 3.2) & ~hole & vis
                a[..., 3] = np.where(hole, 0, a[..., 3])
                a[..., :3] = np.where(rim[..., None], np.array(INK, np.float32), a[..., :3])
            frames.append(bleed(a))
        sheet = np.zeros((1024, 1024, 4), np.uint8)
        for k, fr in enumerate(frames):
            r, c = divmod(k, 4)
            sheet[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256] = fr
        # enforce an empty 3 px gutter round each frame
        for k in range(16):
            r, c = divmod(k, 4)
            y0, x0 = r * 256, c * 256
            for sl in (np.s_[y0:y0 + 3, x0:x0 + 256], np.s_[y0 + 253:y0 + 256, x0:x0 + 256],
                       np.s_[y0:y0 + 256, x0:x0 + 3], np.s_[y0:y0 + 256, x0 + 253:x0 + 256]):
                sheet[sl + (3,)] = 0
        Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, key + ".png"), optimize=True)
        man[key] = {"layout": "Grid4x4", "mode": "OneShot", "tint": "tint" if key == "toon_burst" else "baked-neutral",
                    "use": d["use"], "file": "roblox/assets/vfx/%s.png" % key, "size": [1024, 1024], "blender": True}
        print("sheet", key)
    json.dump(man, open(man_path, "w"), indent=1)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if "--post" in args:
        keys = [a for a in args if a in DESIGNS] or list(DESIGNS)
        post(keys)
    else:
        keys = [a for a in args if a in DESIGNS] or list(DESIGNS)
        render(keys)
