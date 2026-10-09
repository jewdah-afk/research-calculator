# Peckwood map: the AAA plan (2026-10-09)

Owner target: "make our game look like this but way better, super AAA quality" -> **premium toy diorama, cel-shaded**
(owner: "i fucking love celshading"). Live state today: `World.LAYOUT = "grid"` (Birb's flat islands + bridges),
painted terrain MaterialVariants, Future lighting, generate_mesh props, painted EditableImage sea.

## 0. Why the map stalled, and the one rule that fixes it
The world look changed five times in one day (Ascent terraces, flat cel, painted storybook, Valheim, cel-shaded real
life) because we built before agreeing on a picture. **Rule: no world building for an area until its target frame is
approved. Every build step ends with a side-by-side screenshot: target vs game.**

## 1. The look (art bible in one paragraph)
Each area is a hand-crafted island "plate" floating on a soft painted sea, seen from the follow camera like a tabletop
diorama. Cel-shaded: 2-3 tone lighting, crisp shadow edges, black ink outlines on hero objects (hen, eggs, portals,
buildings, trees, landmarks), saturated-but-not-neon palette per biome, soft tilt-shift blur at the top and bottom of
the screen, warm sun with a cool sky fill, gentle bloom. Shapes are chunky, bevelled and smooth: never voxel steps.
Something moves in every frame: grass and trees sway, water shimmers, pollen and leaves drift, clouds pass.
Feel references: A Short Hike, Captain Toad diorama levels, Tiny Glade, Link's Awakening (2019), Pikmin 4, Animal
Crossing NH. Our own UI already sets the bar: glossy painted icons + ink outlines; the world must match it.

## 2. Cel-shading in Roblox (there are no custom shaders, so we fake it)
| Piece | How |
|---|---|
| Light | "Toy" Lighting preset: Future, ShadowSoftness 0.04-0.08 (crisp edges), strong warm sun, cool Ambient / OutdoorAmbient, EnvironmentDiffuseScale and EnvironmentSpecularScale low (kills the realistic PBR sheen), ColorCorrection contrast +0.15 / saturation +0.15 / warm tint, Bloom small, Atmosphere light haze. One preset per biome (table in code). |
| Tilt-shift | DepthOfField: in-focus band on the hen's distance, far blur ~0.3, near blur on. The single biggest "diorama" win. |
| Materials | Every mesh: SurfaceAppearance ColorMap baked in Blender with a 2-3 band toon ramp + painted AO + light rim, roughness 1, metalness 0. Flat MaterialVariants on terrain (one colour per band + faint painted noise). |
| Outlines | Inverted-hull outline meshes (same mesh, flipped normals, +2-3 % scale, black, CastShadow off): unlimited and cheap. `Highlight` only for the hovered/interactable object (31 cap). |
| Ground | Walkable tops stay Roblox Terrain (the controller, egg spawns and physics already work on it) with toon MaterialVariants. Island skirts, cliffs, rocks, beach rims and landmarks are Blender meshes with the toon bake + outline hull. |
| Foliage | Stylised mesh clumps (generate_mesh / Blender), instanced (same MeshId), wind sway by batched client CFrame wobble or skinned bones, distance-culled. |
| Water | Keep the painted EditableImage sea; add a toon foam ring around each island and a slow caustic shimmer. |
| Hen | Remake in Blender: toon ramp bake, outline hull, squash-and-stretch walk, blink, idle peck. Same treatment for eggs (glossy + outline) and companions. |

## 3. Layout (locked)
Birb's grid of flat islands + bridges stays: fully walkable, mechanics at parity. Each island = one diorama plate:
flat play top (Birb's map data), a sculpted cliff skirt, a beach rim, 2-3 landmark props that tell the area's story
(Park fountain + windmill, Castle keep, Mine headframe...), and distant background silhouettes. Unlock reveal: a cloud
bank parts, the island rises, props drop in.

## 4. Pipeline per island (repeatable)
1. **Target frame** (key art from the game camera) -> owner OK.
2. Blockout from Birb's map data (play area fixed, nothing walkable moves).
3. Skirt + landmarks: Blender headless from a heightfield + generate_mesh with ONE shared style prompt.
4. Toon bake + outline hulls (Blender script, batch).
5. Dressing: foliage clumps, props, paths, decals.
6. Biome Lighting preset + post (from the preset table).
7. Motion: sway, particles, water, clouds.
8. Perf pass on a phone budget (below).
9. QA script: grounding (0 floating / sinking), collisions, egg spawns, camera framing, warnings.
10. Screenshots vs target -> owner sign-off -> next island.

## 5. Order and budget
- **Park vertical slice first**, every step at 100 %. It becomes the template.
- Then Garden, Bridge (+ Aquarium), Castle, Forest / Nest, Mine, Desert, Expedition hub, Echo Field.
- Rough effort: Park 2-3 sessions; then about 1 session per island once the pipeline exists.
- Phone budget per visible island (60 fps mid phone): <= 60k triangles, <= 300 draw calls (instancing), <= 200 live
  particles, shadows off on small props, StreamingEnabled with one model per island, RenderFidelity Automatic.

## 6. AAA bar (every island must pass before sign-off)
- Reads as one clear silhouette from the game camera, with foreground / midground / background layers.
- No voxel steps, nothing floating or sinking (QA script: 0 errors).
- Every hero object outlined; nothing else outlined.
- Max 3 tones per material band, colours only from the biome palette sheet.
- Something moving in every frame.
- HUD readable on top (value contrast check with the HUD mock).
- 60 fps on a mid phone, no hitches when the island streams in.

## 7. Decisions for the owner
- **A. Ground tops:** Roblox Terrain with toon MaterialVariants (cheaper, walking already works) or full mesh islands
  (most control, more work). Recommended: build both on one corner of the Park in a single session, choose from screenshots.
- **B. Target frames:** Figma AI images (fast, uses Figma AI credits) or Blender renders of a Park blockout.
  Recommended: Figma AI for the 9 area targets now, Blender for the Park blockout next.
- **C. Studs:** keep a subtle stud texture on built objects (toy read) or none. Recommended: subtle studs on
  man-made props only (benches, stalls, castle), never on nature.

**Owner decisions (2026-10-09):** A = test both on one Park corner, pick from screenshots; B = Figma AI target frames;
C = subtle studs on man-made props only.

## 8. Next steps
2. Make the 9 target frames + a biome palette sheet in Figma (board next to the map boards `178:7`).
3. Park slice in Studio (one Studio window only): Lighting preset + DepthOfField tilt-shift first (instant win),
   then the hen remake, outline hulls, skirt + landmarks, foliage, motion, perf, QA.
