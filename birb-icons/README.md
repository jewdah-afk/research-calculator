# Peckwood icons

## Final icons (use these)
`final/<name>.png`: 256×256, transparent, with a uniform ink outline (#0B0C10, the same weight on every icon).
They are cut from `approved_sheet.png`, the user-approved art, by `cut_sheet.py`:

```
python3 birb-icons/cut_sheet.py birb-icons/approved_sheet.png
```

The cutter works in four steps:
1. Takes each icon's coloured interior, filling holes so pupils and stripes are kept.
2. Assigns interior pieces to icons using `BOXES`.
3. Redraws the outline as a fixed 6px anti-aliased ring. This also repairs edges where icons touched on the sheet.
4. Closes the seed's bottom (`CAP`), because the log hid it on the sheet.

Names: popcorn, golden, plume, wing, magnet, clock, seed, index, crown, ore, goldore, crow, pickaxe, twig, nest, wood, echo, mushroom, parrot, sword, heart, shield, skill, monster, fish.

**Style rules for new icons:**
- Chunky, front facing, with a soft top-left key light.
- Three cel bands: a cool shadow, the base, and a highlight.
- A glossy specular highlight and a thin rim light.
- Saturated colours, with no muddy darks. Dark subjects (crow, seed) get a lighter base and a stronger rim.
- Leave about 8% padding.

Add new art to the sheet, or to a new sheet with an entry in `BOXES`, then re-run the cutter. QA every new icon on both a dark and a light background before use, and check: outline closed all round, no floating parts, nothing clipped.

## Blender source (the base for future 3D icons)
`build_icons.py` + `icons.py` + `lib.py` model every icon in Blender. They run as the `bpy` Python module (`pip install bpy`) with no UI:

```
python3 birb-icons/build_icons.py [names...]     # renders/<name>.png + peckwood_icons.blend
python3 birb-icons/sheet.py out.png [names...]   # contact sheet for review
```

**How it's set up for 3D ports (not exported yet):**
- Each icon is its own collection, `icon/<name>`, centred on the world origin. It faces −Y (the camera) and fits about a 2-unit box. Some icons are parented to a `pivot` empty, which holds their display tilt.
- Every mesh keeps its modifiers live: bevel, subsurf, displace and the outline `SOLIDIFY`. When exporting, apply bevel, subsurf and displace, then **drop the `outline` solidify modifier and the `ink_*` material**. Roblox should draw outlines with a `Highlight` or its own inverted hull instead.
- Materials are emission-only cel shaders (`cel()` in `lib.py`): a dot(normal, light) ramp in 3 constant bands, plus a rim from Layer Weight. For Roblox, bake each material to a small vertex-colour or texture ramp. Alternatively, use a flat colour plus a `SurfaceAppearance` and let in-engine toon lighting handle the shading.
- The planned export is FBX per collection, with origin at the base and the object's root named `icon_<name>`, under 2k triangles each. Rendered 3D icons in the UI would use a ViewportFrame with the same front camera, an ortho-like narrow FOV, and a slow ±8° idle sway.
