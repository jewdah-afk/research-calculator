# HANDOUT: Peckwood (Birb remake for Roblox)

This file is the handoff for the next session or teammate. It covers what exists, where it lives, what is verified, and what comes next.

Last updated: 2026-10-09 (Peckwood Ascent world rebuild, branch `claude/peckwood-isle`)

---

## A. Latest: the world rebuild (2026-10-09). Read this first

Branch **`claude/peckwood-isle`** (pushed). Build: `cd roblox && rojo build default.project.json -o Peckwood.rbxl`, open it in Studio (one Studio window only). The owner says it is OK to stop Play / reload the test place at any time.

### VFX (claude/peckwood-vfx): v3, after Studio QA rounds 1 + 2 and the four craft levers (2026-10-09)
Owner: "super AAA quality and fit our style" (cel toy diorama: flat pastel blocks, hard 2-3 tone steps, white-hot
cores, ink #16181e only on normal-blend pieces). Branch `claude/peckwood-vfx` (worktree `~/Downloads/rc-main-vfx`,
merged with peckwood-isle 6788d54 for ZOOM_PLAY 9). Static checks + a Lune smoke test pass; v2 is NOT yet seen in Studio.

**v3 (QA round 2, 2026-10-09): what changed after the v2 Studio pass** (kept as hero quality: the Rare crack frame,
the toon burst cloud with the swirl dome, the Mythic rune circle drawing in):
- **EditableMesh budget = 0; meshes come from the place.** Roblox caps live EditableMeshes at ~7 per client (the map
  uses 2), and store meshes the place does not own cannot be fetched by id at runtime (QA r3: "MeshContentProvider
  failed"). So `Vfx/MeshFx` clones the 8 template MeshParts saved in `ReplicatedStorage.PeckwoodVfxMeshes`
  (`assets/VfxMeshes.rbxm`, scanned, no scripts, untextured): dome 2x1x2, crescent 7.2x1.14x12.1, swirl 2.48x0.5x2.49,
  wall 10x14.9x10, ringgap 1.96x0.1x1.96, ring 2x2x2, tornado 50x48.9x33.2, star4 4x1x4 (from store meshes
  7349045196, 92572984944785, 10895746627, 131187152008585, 7741808274, 7263678713, 7029892192, 15591537807).
  Coloured by Color + Neon (glow) or SmoothPlastic (ink) + Transparency. Orientation is detected from the box (all
  normals / axes are Y except the tornado, round in X/Y so its axis reads as Z: check it stands upright; `axis = 2`
  in `MeshFx.ASSETS` pins it). The ring's 2x2x2 box is pinned to Y. `_G.__vfx("meshes")` prints size + axis.
- **Camera feel no longer needs Main**: CamFx binds its own RenderStep at Camera+2 while a shake / push / flash runs
  (reads what Main wrote, adds the feel, unbinds when idle). Main's camera lines are the originals again. Reduced
  Motion turns shake / push off and logs it once; `_G.__vfx("motion", true)` forces it on for QA.
- **Wind-up reads**: hatch egg 1.6x the field egg, bigger wobble, a big normal-blend 3-band glow, sparks + streaks
  sucked in from 5.4 studs, a small flash + specks on every crack stage, crack decals on up to 3 camera faces with
  bolder crack art.
- **Light pillar** (hatch Legendary+ 30 studs, level-up 22, unlock 42): `R.pillar` = tapered body (rarity tint,
  low emission, streak texture) + thin white core, soft bottom, fades to the top, wider base, slight width pulse.
- **Level-up**: stepped ground glow (no airbrushed bloom), column to 1.6 s, ding at 0.85 s, no feathers.
- **Reveal**: shards / sparkles about -30 %, no reveal tornado, thin warm ray fans behind the pet.
- **Re-upload these 6** (same keys, art redrawn): `feather`, `confetti`, `leaf` (tumble frames never edge-on: an edge-on
  frame was a bare ink line = the stray "stick") and `crack_1`, `crack_2`, `crack_3` (bolder lines).
- Real unlock data path checked headless with the real Garden tiles from World (343 tiles, 16 coast tiles, 46-stud
  radius, wave 0.6-2.8 s): plays clean. In Studio: `PlayerGui:SetAttribute("PeckwoodBuild", "garden")`.

**v2 textures (16 PNGs, uploaded in 026abc1)** (`roblox/assets/vfx/`, ids in `src/shared/VfxAssets.luau`; a missing id makes a layer fall
back or is skipped, and `collect_pop` keeps the old cube burst):
`flash_star` 512, `swirl_arc` 1024 4x4 OneShot, `ink_swirl` 1024 4x4 OneShot, `feather` 512 4x4 Loop, `speed_line` 256,
`ring_wave` 512, `ring_snap` 256, `glow_step` 256, `rays_fan` 1024 4x4 OneShot, `beam_core` 256x64 (Beam strip),
`crack_1/2/3` 512 (egg Decals), `toon_smoke` / `toon_burst` / `dust_puff` 1024 4x4 OneShot (Blender renders).
Kept from round 1 (ids already in): smoke_puff (fallback), sparkle, shell_shards, confetti, leaf, star, burst_lines,
rune_circle. Dropped: impact_star, ring_shock, ring_thin, glow_disc, light_rays, beam_streak, beam_runes.
Generators: `tools/vfx/gen_vfx.py` (PIL shapes, `--preview` contact sheets, `--only=a,b`) and
`tools/vfx/gen_toon_flipbooks.py` (Blender: `blender.exe -b --factory-startup --python ... -- [keys]`, then
`python ... --post`): noise-displaced sphere lobes, 3-step toon ramp from N.L (constant ColorRamp -> Emission),
inverted-hull ink at constant world width, PIL dissolve that re-inks every hole rim.

**Engine (`src/client/Vfx/`)**: init (API + scheduler), Layers (pools, curves: `pop` multi-key, `vary` envelopes,
`steps`), Recipes (shared hero flash / swirls / streaks / celebration / ground wave / glow / smoke / dust / mark),
MeshFx (six EditableMesh shapes), CamFx (shake / push / flash), Palette, Hooks, Effects/*.
- Hierarchy rule: ONE hero (flash or column), two support layers, an ambient trickle. Ink only on normal-blend pieces.
- Readable at any zoom: size multiplier `clamp(camDist / 290, 1, 2.4)`; hatch frames the egg with a push-in (stronger
  and longer for higher rarity, then sizes follow the pushed framing); level_up gentle push; unlock pushes at the finale.
- No flat beams any more (QA: they stood up as triangles / ovals). Ground pieces = flat particles or mesh wall rings.
- Lever A meshes (`MeshFx`): v3 = Creator Store mesh assets (see above), 0 EditableMeshes; `fx:mesh(kind, spec)`
  animates a pooled clone (billboard / flat / up, tilt, eased spin, ease-out growth, thinning, squash, hard-stepped fade).
- Lever C: streaks are VelocityParallel + Squash + Drag + gravity; sizes use multi-key pops; ZOffset layering (flash
  core 5.2 > rim 5 > needles 4.6 > speed 4.4 > embers 4.3 > swirls 4.2 > ink 4 > shards 3.5 > cloud 3 > smoke 2 > glow
  -0.6 > rays -2); hot cores Brightness 2-3; radial bursts use `emitSphere` / `emitRadial` (the Sphere/Disc-outward
  shape without a shape Part, because an invisible Part hides the Occluded ink Highlights); rate curves (accelerating
  suck-in, tapering sparkle trickles).
- Caps: egg_hatch 8, collect_pop 16, level_up 4, unlock 2, 48 total. Hit-stop freezes everything but the hero flash.

**Effects: layers in order (times in s)**
- `collect_pop` (0.35): t0 ring snap (white, broken, 0.24, ease-out, stepped out) + colour flash star (0.13) + white
  core (0.09) + 3-4 inked sparkles (drag stop); golden x1.25 + 2 star bits; 0.04 `onLabel`.
- `level_up` (1.6): t0 mesh wall-ring ground wave (0.34) + flat 3-band glow (0.7) + 4 dust puffs; light column shoots
  up (0.14), holds, thins 0.95-1.45; mesh spiral cone winds up (0-0.32), spins, collapses 1.05-1.45; light swell;
  hen punch; push-in. 0-1.1 rising sparkles (3/step -> 1) + speed-line streaks up the column (to 0.8). 0-1.25 three
  ribbon trails. 0.9 ding: 4-point flash (rim + core, squash gleam) + star4 mesh gleam + 3 star bits + 2 feathers.
- `egg_hatch` (A = 0.65 / 0.8 / 1.0 / 1.25 / 1.7 / 2.1 by rarity): 0 push-in (in 0.85A), egg (EggAsset stand-in
  unless `opts.egg`) rocks with ramping speed + amplitude (hops Rare+), 3-band glow charges in steps, light ramps,
  ember streaks sucked in (accelerating). 0.3A / 0.58A / 0.84A crack decal stages glowing the rarity colour + jolt +
  shell specks + twinkle + micro shake. 0.62A swirl gather (Rare+). Legendary+: 0.2 rune circle drops in + flat swirl
  trace; 0.3A..A light pillar. A-0.1 egg swells. A CRACK: hero flash (0.09, plays through the hit-stop) + inked
  needles (Uncommon+); mesh crescent slashes spin out and thin (1 Uncommon, 2 Rare+, 0.42-0.48) + ink spiral (Rare+);
  speed lines (Rare+) + embers (Uncommon+); ground mark (Rare+); toon burst cloud (0.72, white-hot 2 frames); shell
  shards; toon smoke ring; mesh wall-ring wave (0.32; a 2nd at A+0.07 on Epic+); mesh dome (Epic+, 0.42) + colour
  flash; pillar flare; shake; hit-stop 0.05-0.1. A+0.04 REVEAL: pet pops (0.4, back overshoot + hop); ray fan + halo
  (Uncommon+, 1.0-2.6, rays die by thinning; Mythic counter-rays); star4 gleam (Rare+); spiral cone round the pet
  (Legendary+, 1.1); stars + feathers + a little confetti (varied sizes; rainbow on Mythic); twinkle trickle (1.1);
  sparkle shower (Legendary+). The stand-in chick poofs at the end (`opts.pet` / `noPet` / `noEgg` to control).
- `island_unlock` (S = waveStart - 0.45): S rune circle drops in (118% -> 100%, alpha in 3 steps) + a mesh arc wall
  sweeps once round it; S+0.1 summon pillar + big mesh spiral cone + warm ray fan. waveStart: mesh wall-ring light wave
  grows from the landing with the tile wave; glints flash on sampled tiles; coast tiles burst toon dust + leaves.
  waveEnd: rune flashes out, wall-ring sweep from the centre, translucent dome blooms and flattens, star burst,
  sparkle + feather + confetti shower, shake, flash, push-in.

**QA helpers**: `_G.__vfx("egg_hatch", "Mythic")`, `_G.__vfx("hatch_all")`, `_G.__vfx("collect_pop", nil, {golden=true})`,
`_G.__vfx("level_up")`, `_G.__vfx("island_unlock")`, `"stats"`, `"stop"`; server command bar:
`PlayerGui:SetAttribute("PeckwoodVfx", "egg_hatch:Mythic#1")`, and at a world spot for frame strips:
`PlayerGui:SetAttribute("PeckwoodVfxAt", "egg_hatch:Rare:12,-4#1")` (x,z or x,y,z; y = ground there; collect_pop is
lifted 2 studs). Real unlock: `PlayerGui:SetAttribute("PeckwoodBuild", "garden")`.
**Smoke test**: `rojo build default.project.json -o <tmp>.rbxl && lune run tools/vfx/smoke.luau <tmp>.rbxl` (every
effect x rarity, caller egg + pet, 8 overlapping hatches, the QA attribute, mesh + particle-fallback paths, no-texture
degrade; mocks EditableMesh and checks budgets, bbox symmetry, sequence rules, pool / mesh leaks).

**Studio QA still open**: mesh clones render + scale right (Neon + vertex colours, both faces), billboard tilt of the
arcs reads as crescents, wall rings sit on the ground; crack decals land on the camera-facing faces of the egg mesh;
flash ZOffset keeps it out of the ground; VelocityParallel streak orientation (texture head at row 0 should lead);
particle sizes past ~100 studs (unlock wave / circle fallbacks); Brightness / bloom by day and night; push amounts at
zoom 4 / 9 / 16.
### INTEGRATED: Figma UI + VFX merged into claude/peckwood-isle (2026-10-09, latest, cbb19b8)
- `claude/peckwood-ui` (in-game Figma UI, owner placement, COMPANIONS pull-down board, Motion.key press-in on every key, layered Sfx + dev Sound Board) and `claude/peckwood-vfx` (egg_hatch / collect_pop / level_up / island_unlock, 0 EditableMeshes) are merged here. Details: sections "In-game UI from Figma" and "VFX (claude/peckwood-vfx)" below. Side branches keep going and merge isle first.
- Studio QA at merge: 0 script errors; MAXED layout = owner sketch; 643 wired keys visible at peak; only unwired GuiButtons are Roblox chat, window click-blockers and the board's pull ring (fix sent).
- Icons: all 992 icons uploaded (426 fish + every tree node / gear / item); `shared/Icons.luau`.
- VFX meshes: store meshes can't be fetched by id at runtime ("could not fetch"), so the 8 shapes are saved in the place as `ReplicatedStorage.PeckwoodVfxMeshes` (`assets/VfxMeshes.rbxm`, scanned: no scripts).
- EditableMesh budget (measured): ~7 live meshes per client, 20,000 triangles / 60,000 vertices each. Cliff = shared-vertex grid split into 19.5k-tri chunks (every island open = 3 meshes), waves = 1 mesh, VFX = 0.
- Sounds: 31 events with 3 licensed candidates each (Pro Sound Effects / Roblox UI pack / APM); first candidate is the default; owner picks by ear on the dev Sound Board (SOUNDS on the dev bar). Egg pickup = eggshell tap + buttery pop layers with warm EQ.
- Open fixes in flight: board pull-ring press, board covers AUTO + rail top, sticky hover tooltip, VFX push framing / duplicate camera bind / reveal hold, island_unlock check.

### Park life pass + camera (2026-10-09, latest)
- **Camera** starts close on the bird: `ZOOM_PLAY = 9` in Main.client (wheel still goes out to the whole island, 16). Owner: "I can't even see the vfx"; Birb's view is close too.
- **Toon flowers** replace the generated wildflower tufts (owner: they "look ass"). Each `Map.flowers` spot = a rounded leaf clump + 2-3 five-petal flowers of one pastel (white / pink / yellow / coral / lilac), scale `F = 3`. Skipped on paths, water, hills, the egg yard, prop footprints and the screen strip just north of tall props (they hid behind lamps).
- **Butterflies**: 7 toon butterflies wander between flower patches by day (hover pauses, flap 15 Hz / 6 Hz hovering), one `BulkMoveTo` per frame; hidden at night when the fireflies start.
- **In flight on side branches** (not merged, QA in Studio first): `claude/peckwood-ui` (worktree `~/Downloads/rc-main-ui`: Figma UI, now doing Birb placement + Figma motion spec + UX/SFX extras) and `claude/peckwood-vfx` (worktree `~/Downloads/rc-main-vfx`: VFX engine, round-1 fixes + v2 mesh/flipbook quality). VFX textures uploaded, ids in `VfxAssets.luau` on that branch.

**More gotchas:**
- `Part.Shape = Ball` can't be squashed: it renders as a sphere of the smallest axis. For ellipsoids use a Block part with a `SpecialMesh` (MeshType Sphere); it follows the full Size.
- An EditableMesh must stay alive: destroying it makes its MeshPart vanish (no baking). But `MeshPart:Clone()` shares the mesh, so build a shape once and pool clones.
- Studio sync: `tools/gen_manifest.py` maps `init.luau` to the folder itself; Script.Source can't be set above 200k chars from a plugin, use `ScriptEditorService:UpdateSourceAsync` (AscentData is 357k).

### Park slice v2: toon walkway, lighthouse, pond, tiered rolling sea (2026-10-09, latest, commit 2dbcdd4)
Owner verdict on the island: "looking fucking crazy"; the lighthouse beam is "super clean, keep that up".
- **Walkway** (`IslandView`, "toon walkway" block): drawn as STROKES, not from the tile mask. Ring = the egg-yard outline (`tileLoop(Map.inYard)`) pushed 2 studs outward, half width 2.3; every path branch that leaves the ring (path tiles not next to the yard) becomes one straight capsule; ring + spurs blend with a smooth-min fillet, noise wobble, painted as sand fill / toon band / brown outline into one 960x720 EditableImage decal at y -0.44. 1-tile diagonal stair steps can no longer break it into patches. New east spur (MapData rows 13-14, cols 29-31) leads to the market stall.
- **Pond**: painted into the same texture (blurred pond mask: ink edge, light shallow rim, water, darker crescent under the north bank so it reads as a dip). Terrain under pond tiles is plain turf now. `ToonPond` = stones along the smooth rim (skipped where the rim meets the sea) + lily pads, dark-blue ink Highlight. The oak that covered it moved to (60,322).
- **Lighthouse** replaces the windmill (the "2 windmills" were the generated windmill plus the old brick sails built on top). `buildLighthouse`: stone plinth, 5 tapering red/white drums, door + windows facing the camera, slate gallery + railing, glowing lantern room, stepped red cap. Light = `Beacon` part under `IslandView` (outside the outlined scenery): 2 opposite FaceCamera Beams + SpotLight, spun every frame (0.8 rad/s), faint by day, bright at night. Hitbox `lighthouse = 3.4` in Controller.
- **Sea hierarchy** (`Ocean.paint`): toon depth tiers instead of one gradient: foam line at 2.0-2.6 tiles, lagoon 8af2e2 to 4.2, reef 3fd4e8 to 6.4, mid 2a9fe0 to 9.2, then deep = the far-sea colour. Anti-aliased steps with a soft glow before each drop-off, organic noise edges. Distance cap raised to 12 tiles, PX up to 6 per tile.
- **Rolling waves** (`buildWaveFronts`): two crest fronts, each ONE EditableMesh ribbon along every coast loop (coast corners ironed out by two wide moving averages, smoothed normals, dashed by noise). Each frame a visible front slides its vertices from 7.4 to 2.5 tiles out and fades; the painted foam surges as a crest lands. The 3 painted crest images are gone.
- **Hen**: `Birds` now does `ScaleTo(GetScale() * 1.25)`. An absolute `ScaleTo(1.25)` overrode Models' sizing and made the hen huge. Ink outline Highlight on the hen.

**Gotchas learned (read before touching visuals):**
- Top-face Decals: image row 0 sits at **+Z**, column 0 at **+X** (tested with a 4x4 marker image). Write pixel `(px, py)` at `((PH-1-py)*PW + (PW-1-px))*4`. Path and sea were mirrored in Z before this fix.
- **EditableMesh memory budget is nearly full** (the cliff skirt's flat-shaded meshes use most of it). 14 per-ring wave meshes hit "Failed to create empty EditableMesh ... memory budget"; keep new EditableMesh use to a couple of meshes, and watch it when more islands unlock (more cliff loops).
- Highlights in Occluded mode are hidden behind big Transparency=1 parts: never use big invisible boxes for particle volumes (use an Attachment emitter repositioned per frame, see `Ambience` / fireflies).
- `Model:ScaleTo(x)` is absolute: always multiply by `GetScale()`.

### The new map: Peckwood Ascent
- Concept page: https://claude.ai/artifact/NsW1MDQEYJGtsaSDAdZYym (owner picked "ring of zones + verticality").
- The Park is a valley hub at sea level (lake, river to a south-east beach, portal plaza south-west of the Park).
  The 7 ring areas sit on terraces clockwise from the south-west, each higher: Garden 8, Castle 16, Bridge 24,
  Forest 32, Mine 44, Desert 52, Expedition 64 studs; the Echo Field is on the north summit at 80.
- Generated by **`roblox/tools/ascent_gen.py`** (deterministic, writes `src/shared/AscentData.luau` + a preview
  `tools/ascent_preview.png`). Edit the generator, never AscentData by hand. Handmade area cores (IslandData) are
  placed at `cores[id]` and keep their own tiles/props; generated region tiles are `i,j,code,h,base`.
- `World.LAYOUT = "ascent"` (`"isle"` = previous World Guide island, `"grid"` = old 3x3). **`World.base(i,j)`** = terrace
  height in studs; used by `Controller.heightAt` (bird walks/climbs), `IslandView.islandTopY` (render),
  `LandTerrain.column` (ponds at terrace height), server desert egg spawns, teleport/Go-to landing.
- Trail ramps rise 1 stud per tile (STEP_UP is 5 px = 1.25 studs), so the bird can walk area to area; elsewhere
  terraces meet in cliffs (walls).

### Look (owner direction: "3DS Pokemon X/Y": low-poly, smooth, cel-shaded, not all green)
- Land = **Roblox Terrain** (`src/client/LandTerrain.luau`), voxel-aligned columns, noise patches (lush/dry grass, dirt),
  sand beaches, rock cliffs. Flat colours via **MaterialVariants authored in `default.project.json` MaterialService**
  (`Flat<Material>`, ColorMapContent = white `rbxassetid://83334179566218`); scripts may NOT create MaterialVariants.
  Terrain.Decoration is off (set in project). Hard-ish shadows (ShadowSoftness 0.08), brighter day ambient (KF table).
- Sea (`Ocean.luau`): thin clear Terrain water (waves/glints) + a painted EditableImage layer just above it (guide-style
  gradient by distance to land, soft foam band, drifting sparkle); one painted far-sea floor; stale repaints cancel.
- Trees/bushes: Yasu's Stylized Tree Pack (free, no scripts) in `assets/TreeAssets.rbxm`, photo textures stripped (toon).
- Props: 35 smooth models made with Studio **generate_mesh** in `assets/PropAssets.rbxm`; `IslandView.swapProp` puts each
  on its brick prop's footprint/height/yaw (lamp lights kept). Still bricks: bench, wall, tank, tent, monolith, vine
  (bad generations, redo), goldbird / monster / nesttree (gameplay, ask owner), footbridge / pier / rails (walkable).
- Collisions (`Controller.luau`): trees block only at the trunk; bushes / flowers / sunflowers are walk-through.

### Teleporter hub (`src/client/Portals.luau`)
- Each unlocked area adds an animated portal (spinning neon ring in the area colour, swirl, sparkles, light, name
  plaque) on the Park plaza arc; every open area also has a PARK portal by its arrival spot. Walk-in fires the
  existing `PeckwoodTP` hop (same as the left-bar Teleport).

### Safety
- A free store pack ("Village Pack Low Poly Houses Nature Props", 95828990265698) carried a backdoor (fake "paste this
  into the Command Bar" GUI). Deleted before it ran. Scan every inserted asset's scripts; prefer generate_mesh.
- Asset export pipeline: SerializationService in Studio -> local POST receiver -> `lune` re-serialize (fixes the Tags
  property Rojo 7.5 can't read) -> rojo `$path`.

### Figma UI handoff + prop variety (2026-10-09, latest)
- New chat for the Figma UI at Birb parity: paste `FIGMA_UI_PROMPT.md` (repo root). Figma (edit): Peckwood-UI
  `SQOJ2gzGt12vFMGGlNRWBE`, UI v2 page node `0:1`. Layout reference = HTML parity build `playtest/` on branch
  `claude/exciting-mccarthy-5em6b3`.
- Prop variety: `VARY` table in IslandView.swapProp = per-position random yaw + size range + tilt for rock, ore,
  crystal, lantern, barrel, log, mushroom, cactus, sunflower, bones, twigs, deadtree (Park objects carry no rotation).

### MAP AAA PLAN (2026-10-09, owner asked "plan out the map build and how we AAA this")
- Read **`MAP_AAA_PLAN.md`** (repo root) before any world work. Target = premium toy diorama, cel-shaded, Birb's grid
  layout kept. Rule: no area is built before its target frame is approved; every step ends with target-vs-game
  screenshots. Park vertical slice first. Owner decisions pending: A ground tops (terrain vs mesh), B target frames
  (Figma AI vs Blender), C studs on man-made props.

### Figma windows at Birb parity: batch 1 (2026-10-09, Figma chat)
- **Windows board `239:307`** "Peckwood UI v2 / Windows at Birb parity" (page UI v2, x 5400, y 17600), one column per
  window. Built by a 9-agent workflow from one shared kit, then reviewed and fixed by hand:
  - Trees: Sunflower Tree `239:309` (SUNFLOWER tab, the reference), DESERT tab `246:3851` (+ gates board `248:2673`),
    ARCHIVIST tab `246:1796`. Real Birb grid + prerequisite links, node states (owned / can buy / need more / locked /
    unexplored), minimap, detail panel with one BUY key. Spec card for all three tabs `248:3276`.
  - Mining: Mine SHOP `246:4443`, Mine AREAS `248:1739` (+ states `248:2831`), Treasure Room `246:1525`, Crow
    `246:1276` (+ rebirb states `246:4118`).
  - Fishing: Fishing COLLECTION `246:3448` / EQUIPMENT `248:2079` / FISHDEX `248:2952` (Birb's 3 tabs; Rods, Baits and
    Tackle fold into EQUIPMENT), Aquarium BIOMES `246:2134` / RESONANCE `246:4667` / TOTAL `248:1351`, Fish Market
    `246:2574` (+ locked `248:1566`, states `248:1615`), Nest LAKE breeding `246:1462` (+ incubating `248:546`, ready
    `248:948`). Each has a spec card in its column.
- **Shared kit for any new window:** `docs/figma/kit.js` (paste at the top of every use_figma script) +
  `docs/figma/WINDOW_BRIEF.md` (rules, QA, parity sources). Helpers: WINDOW, TABS, STEEL, WELL, KEY, BTN, PRESS, CHIP,
  BAR, T, BODY, ICO, GLYPH, SPEC, OUTLINE.
- **Owner rules from this round (all in the kit):** all UI text is Fredoka One (normal text = 1.2 px outline + 1 px
  drop); close key 44 px at (W-54, 10), don't move it; continuous 4 px window outline over the header (`OUTLINE` last);
  pressed key = the WHOLE key drops by the lip depth (no black band above the face); tree connector lines = all ink
  under all colour; cost chips = steel mini plates; +/- and x are centred glyphs, never typed characters.
- **Game bug found:** `roblox/assets/ui/stripes.png` does not tile (12 px stripe period on a 64 px image), so every
  stripes texture in game shows seams. Fixed file: `roblox/assets/ui/stripes_seamless.png` (period 12.8, wrap diff 0):
  upload it and point `Icons["ui/stripes"]` at it. Figma already uses the seamless one.
- **Decisions taken (owner: "do what is best"):** EGGS = one window with an Eggs / Golden / Echo switch; Fishing = Birb's
  3 tabs; each tree tab tints its map (desert sand, archivist violet); unnamed desert nodes named from their effects;
  Treasure Room shows Deep Mine as an unexplored teaser; Crow REBIRB key stays violet (rebirb colour); spec cards keep
  their documentation font.
- **Still open:** fish display names are id-derived (Birb's translation strings are not in the parity data); no painted
  "shiny" or "hybrid egg" icon yet (star / pink egg stand in); next batch = Expedition (Parrot 5 tabs, forge, floors +
  night + totem, sacrifice + mythic, objectives), Nest SHOP / RIVERSIDE / SAWMILL / OWNED, companions + Evolve, the
  EGGS window with the currency switch, popups.

### Figma HUD at Birb parity (2026-10-09, Figma chat, group 1 of 5 done)
- **Inventory first:** `FIGMA_INVENTORY.md` (repo root) lists every Birb window / panel / popup / HUD element from the
  parity build and marks it exists / differs / missing in Figma, with node ids.
- **Board `213:7`** "Peckwood UI v2 / HUD at Birb parity (squared)" on page UI v2 (x 0, y 17600). All pieces are
  components; the screen mock uses instances only.
  - Wallet chips `215:7` section: `hud/chip/<cur>` x10 + `hud/chip-main/popcorn`, **1:1 with `Hud.luau capsule()`**
    (owner-approved in game), squared (ink 6 / face 4 / well 3). Long value hides the engraved name, never overlaps.
  - Menu tiles `hud/tile/*` (MAP TELEPORT FISH PROFILE / SHOP SETTINGS AUTO PETS, + pressed), solid keys, no label band.
  - Area rail `hud/area rail` (right edge): open areas = coloured Kit keys, current area pops out 16 px and is
    biggest, locked = grey key + greyed icon + padlock (no colour bars). Old bookmark tiles `hud/bookmark/*` kept
    in the section, unused.
  - Travel keys v2 `hud/travel/<left|right|up|down>` (+ locked): one solid key, chunky outlined chevron + destination
    on the face (old square `hud/arrow/*` kept, unused). Context AUTO `hud/auto/*` (exact parity labels + pressed).
  - Context bars `hud/context/<fishing|mine|expedition|echo|desert|nest>`: level badge + bar + info strip in one outline,
    title tab flush on the bar.
  - Hotbars `hud/hotbar/*` (fishing ready/cooldown/reeling, mine challenge/giant/resting, expedition HP+potion+relic+
    artifacts+RESET FLOOR), prompts `hud/prompt/*`, toasts `hud/toast/*`, `hud/objective`, `hud/banner/the bridge`,
    `hud/companions (open)`.
  - **Screen mock `229:7`** "HUD parity / Bridge" (1920x1080, HUD scale 0.82, 16 px margins) + **spec card `234:499`**
    (layout, hierarchy, build rules, states, motion, SFX, parity notes).
  - Icon sources strip `213:10` (uploaded from `birb-icons/final` + `ui/halftone`, `ui/stripes`).
- **Owner rules learned this round** (also in the spec card): every key = Kit.button recipe (the COMPANIONS header is
  the shading reference); press sinks the face the full lip depth with no lip showing; never a white inner shadow over
  an inside stroke (it greys the top outline, use a 1.5 px highlight strip inside); faint gloss on dark steel; squared
  corners; HUD compact, not in your face; one shared outline where parts join (no notches); fill the width (no empty
  strip ends); QA every change zoomed + check visual hierarchy.
- **Still to do (in order):** Expedition-run screen mock (floor HUD + HP hotbar + SP chip) and one mock per other area;
  then FIGMA_UI_PROMPT order steps 3-5 (missing windows: Fish Market, Parrot forge, Nest Lake/Owned, Fast Travel;
  windows that differ; popups). Open owner questions: Eggs/Golden/Echo as one tab with a switch or three windows;
  Fishing as Birb's 3 tabs.
- **Owner asks parked for later chats:** cel-shaded birb character (owner loves cel-shading), "AAA premium toy diorama"
  look for the world, SFX set (buttery keycap on every press + classic cue per effect), Upgraded UIGradients beta
  (Radial/Conical, not publishable live yet) for rings/vignettes.

### World QA pass (2026-10-09, latest)
- "Eggs in the water" was false water: pond columns wrote water at land height, so it spilled over 48 dry tiles. Ponds
  now sit one voxel below the land (`LandTerrain.column` code 3: `wt = snap(top) - 4`). QA scan: 0 water-on-land tiles.
- Water is wadeable: Controller `canStand` only blocks VOID; water height -6 px (hen sinks to its belly), speed x0.5.
- Terrain surface offset tuned to `y - 2.5` (measured: -2 -> +1.0, -3 -> -1.0, -2.5 -> -0.5 below logic ground);
  hen feet / most props now within 0.5 stud of the visible ground.
- QA script (paste in Studio, Client, after MAXED): raycast Terrain per open tile for Water on non-water tiles; every
  `Smooth` prop: bounding-box bottom vs terrain raycast; every egg vs ground; LogService warnings/errors.
- Fixed after QA: pond foam square (Ocean `openLand` now counts inland ponds as land); rounded lakes (per-tile water
  FillBall + banks within ~3 tiles dip below the waterline with noise in `LandTerrain.visualTop` + bank flooding);
  smooth props stand on the rendered ground (swapProp raycasts Terrain; QA: all 14 Park props 0 offset).
- (old) Open from QA: pond reads as a pale sunken square (water / bed colour, square shape); 3 props 3-5 studs off the
  ground; trees "sink" only by their root meshes (expected); paths read as dirt stains in places.

### Eggs + portals (2026-10-09, latest)
- Egg = generated mesh `assets/EggAsset.rbxm` (Models.kernel; golden = same mesh, solid gold). Collect: +value pops above
  the egg, the egg flies (2D icon arc) into the wallet capsule (`Hud.flyFromScreen`), no more homing into the hen.
- Egg icons uploaded (egg rbxassetid://122713849392935, golden egg 74456595363673) and mapped onto the `popcorn` /
  `golden` keys in `shared/Icons.luau` (ids kept so saves stay 1:1).
- Portals v3: generated mossy stone ring gate `assets/PortalAsset.rbxm` (7.5 studs), coloured breathing swirl disc in
  the opening + sparkles + light, plate above the arch on a static pad; Park scenery cleared off the row (IslandView
  skips Map.objects in tiles x 4..36, y 1..7.5). TODO: keep egg spawns off the portal row.
- Eggs float normally again (drop / roll removed on request). Hitboxes: Controller `FOOT` = tight footprint radius
  (studs) per kind, everything else walk-through.
- - Portals: doorway-size (R 2.4), one row on the Park's north edge facing the camera, name plate on the static pad
  (it orbited when attached to the spinning swirl). Plate still renders at the pad base: raise it next.
- NEXT (owner): Figma UI at Birb parity in our high-quality style (needs the Birb UI reference + the Figma page),
  then build the game up.

### Park polish (2026-10-09, latest)
- Hen: new storybook hen (generate_mesh, parts body/wingL/wingR) in `assets/BirdAsset.rbxm`; `Models.bird` rebuilds
  its WorldPivot at the feet (the exported pivot is lost in the asset round-trip), 1.1 * S tall, no cartoon outline.
- Terrain surface offset: WriteVoxels renders a full voxel's surface ~2 studs high, so `LandTerrain.column` writes
  3 studs lower (measured in Play with a raycast; ground now matches the bird/eggs/props).
- Hills are walkable (Controller: hill height = `LandTerrain.visualTop`, STEP_UP 13 px); props sit on the visible
  ground (`groundAtWorld` / island props use visualTop). Only call visualTop in parentheses: it returns 3 values.
- Props: `PROP_H` table in IslandView = real-world heights per kind (lamp 9, windmill 19, ...); new generated bench +
  wildflower tuft (Park flowers use it); PropAssets now 37 kinds.
- Eggs: hover 0.5 * S over a black shadow disc; physical-feeling spawn: server picks a rest spot a short roll from the
  drop point (walkable only) + `readyAt` (no pickup until landed); client animates fall, 2 bounces, rolling spin.
- Water: ripple sheet (procedural wavy strokes, two drifting Textures over the whole sea) + 3 shore-wave bands that
  light up outermost first every 4.5 s. Grass repeat broken up (tile scales 56 / 44 / 37).
- Open: pond reads as a blocky square; sand rim too white at dusk; regenerate the bad props (wall, tank, tent,
  monolith, vine); paths in the Park still show dirt patches; then the other islands; then the UI track.

### LAYOUT SWITCH (owner, 2026-10-09 late night): back to Birb's setup
- The Ascent terraces made the bird snag everywhere (cliff-foot no-walk strips, narrow ramps, hills, relief), so
  `World.LAYOUT = "grid"`: Birb's flat islands per area + bridges, Park portal hub inside the Park
  (`Portals.luau` HUB 20,23). `World.relief` returns 0 outside "ascent" (flat walkable ground). Ascent code, data and
  concept stay in the repo for later.
- Keep on top: painted terrain MaterialVariants (`Painted<Material>` in project MaterialService, tiles in
  `assets/terrain/`, uploaded ids in default.project.json), storybook lighting, generated props / trees, water,
  portals. Height only as scenery around island edges.
- Owner: "make sure it looks SOOOO GOOD FOR ROBLOX, and the chicken needs some real work": next = hen pass
  (regenerate in the look board style, size / facing / grounding, motion check), then the Park prop pass.

### ART DIRECTION LOCKED (owner, 2026-10-09 night): "Painted storybook"
- Breath of the Wild / A Short Hike / Ghibli: realistic terrain shapes and light, HAND-PAINTED textures, cute readable
  hero objects (hen, eggs, portals pop with rim light + outline). Replaces the Valheim experiment below.
- Look board (approve before building): `roblox/docs/lookboard/` park_overview.png, hen_meadow.png,
  terrain_swatches.png (Figma generate_image, team::1657975936717760073).
- Build plan: painted terrain MaterialVariants (upload painted grass / dry grass / dirt / mossy rock / sand / snow
  tiles, author in project MaterialService, SetBaseMaterialOverride), warm low key light + blue-violet shadows +
  gentle bloom + haze + painted sky, ONE generate_mesh style prompt for every asset, Park as a finished vertical
  slice first. Unique hooks: island grows with unlocks, visible flock of hens with upgrades, eggs as the star.
  Perf budget: 60 fps mid phone, mesh instancing, LOD, streaming, particle caps.

### DIRECTION CHANGE (owner, late 2026-10-09): Valheim / The Forest, Park first
- Owner rejected both the flat cel colours and the sculpted faceted-mesh land ("this map is bad, coloring is off").
  New target: **Valheim / The Forest**: really good natural terrain generation (rolling ground, dense forests,
  rocks, atmospheric light), still leaving room for every mechanic. **Design and finish the Park first**, with the
  mechanics working, then build the other areas one by one.
- Also asked: the in-game UI laid out like theirs (the original Birb game's UI) but in OUR Figma style with the
  squared HUD / UI. Separate track after the Park.
- Done so far: realistic Roblox materials (no Flat overrides applied; the Flat* variants still sit in
  MaterialService), natural earthy palette (`LandTerrain.setup`), grass blades on, Atmosphere + softer shadows +
  lower saturation (project Lighting). `World.relief(x, z)` = gentle rolling ground in studs (Park 0.7, regions 2.6),
  shared by the terrain (`LandTerrain.visualTop`), the bird (`Controller.heightAt`) and egg spawns (server), so
  nothing floats or sinks. The faceted-mesh attempt is parked at scratchpad (not in the repo).

### Art pass progress (2026-10-09, same chat)
- Owner LOVES the generate_mesh props ("exactly what we want for our assets everywhere"): use Studio generate_mesh
  for every asset (no brand names in prompts; ~3 jobs at a time or it rate-limits; check each upright in a lineup).
- Terrain now uses `Terrain:WriteVoxels` with fractional top occupancy (`LandTerrain.column`): smooth surfaces.
  `LandTerrain.visualTop`: the 3 tiles at the foot of a higher terrace slope up to it as rock (Controller
  `onSlope` makes that band a wall, path/ramp tiles exempt); hills = rolling grassy mounds; shores dip. The top two
  voxels carry the surface material (a fractional top voxel shows the one below), soil (Mud) under grass.
- Camera now follows the ground height (`Main.client.luau` bird / ISLAND_CENTRE Y = terrace base); before, it aimed
  at y=0 and ended up inside the terrain after teleporting to high areas (Echo).
- Owner still unhappy with the map look overall ("might need to do something else"): next idea = faceted low-poly
  terrain MESHES in the same style as the generate_mesh props (Blender from the AscentData heightfield, or
  generate_mesh landmark pieces such as cliffs/rock formations placed along terrace edges).

### TOP PRIORITY (owner, end of 2026-10-09): full map art pass
Owner: "the map design is amazing, but the terrain isn't smooth and it still lacks the cel-shaded look. Focus on the
full map design and go all out to match our aesthetic: a real-life map, but nicely cel-shaded." The layout
(Peckwood Ascent) is approved; the LOOK is not. Current terrain = 4-stud voxel columns, so terraces read as blocky
steps and slopes are stairs. Suggested approach (pick after a quick prototype on one area, show screenshots):
1. Smooth landforms: build a smoothed heightfield from AscentData (blur terrace edges into sloped cliffs with
   rocky faces, rolling hills from noise, river banks and beaches that slope into the water) and write it with
   `Terrain:WriteVoxels` using fractional occupancy (true smooth Roblox terrain) instead of FillBlock columns.
   Keep walkable fields flat (World.base) so the controller still works; only the scenery between them slopes.
2. Cel look on top: flat MaterialVariants (already in place), a tighter, more saturated palette per biome, crisp
   shadows, warm key light + cool ambient, Atmosphere haze for depth, sky gradient; ink outlines only where cheap
   (Highlight max ~31: bird, eggs, portals).
3. If Roblox Terrain still can't look cel-shaded enough: generate faceted low-poly terrain MESHES per area in
   Blender headless from the same heightfield (flat-shaded, vertex colours by height/slope/biome), import as
   MeshParts. Most control over the look; needs the owner's OK and a mesh upload path.
Do this before the steps below.

### Next steps (in order)
1. Playtest the Ascent in Studio: walk every ramp (Park -> Garden -> ... -> Echo), check cliffs/no snags, portals both
   ways, eggs + desert eggs on terraces, camera framing on high terraces, frame rate on MAXED (last: CPU 8.7 ms, GPU 1.2 ms).
2. Unlock reveal: locked areas under a cloud bank; on unlock the cloud parts, the trail ramp builds step by step, the
   terrace rises, props drop (IslandView.unlockIsland wave already fills terrain columns by BFS distance).
3. Prop polish: per-kind height table for swapProp (scarecrow too big, fences small); regenerate the 6 bad props + bench.
4. Ocean: verify painted shallows/foam fit the new coastline; remove the faint diagonal lines seen on the water.
5. Then the owner's bigger ask: every Birb mechanic + all windows in the Figma UI style (see section 0 gap audit).

### In-game UI from Figma (claude/peckwood-ui)
Branch **`claude/peckwood-ui`** (worktree `~/Downloads/rc-main-ui`, not merged, not pushed). Owner ask: "get our UI in
... everything rendered in till we get the rest of the game in". Every HUD element and every window on the Figma HUD
board `213:7` and Windows board `239:307` is in game (Figma look, placement per the owner's 2026-10-09 screenshot
direction on Birb's screen split), openable, with live data where a system exists and Figma's own sample save
everywhere else. QA rounds: UI_BIRB_QA_1 (tab-by-tab Studio QA against real Birb) + the owner direction on top.
- **How it matches Figma (by construction, no hand redraw):** `roblox/tools/figma_export/exporter.js` (read-only
  `use_figma` script) dumps a frame's node tree in 19 KB slices; `collect.py` reassembles the slices from the Claude
  session transcripts (`python collect.py <session dir>`); `build_layouts.py` writes one Luau layout per frame to
  `src/client/UI/Figma/Layouts/` (node id in each header). `UI/Figma/Render.luau` builds those tables node for node at
  the Figma coordinates: fills, linear gradients, radial (soft-ellipse fallback, no beta needed), tiled stripes /
  lattice / halftone, strokes (inner), ink drops, soft shadows, inner shadows, layer-blur ellipses, sparkles; glyphs
  and growth chevrons are drawn as rounded bars (all ink first, then colour). Re-export a changed frame: run the
  exporter with its node id (parts 0..n), `collect.py`, `build_layouts.py` (roots in `roots.json`). Birb features a
  frame does not have yet are explicit edits in `UI/LayoutPatches.luau` (applied once to a copy by WindowManager).
- **Modules:** `UI/Layout.luau` (Birb screen split, the ONE 8 px spacing table `Layout.S`, the window region),
  `UI/Motion.luau` (every tween + `Motion.key`, the only button feedback), `UI/Hud.luau` (HUD, placed by `reflow`),
  `UI/CompanionsBoard.luau` (the pull-down map), `UI/WindowManager.luau` + `UI/WindowDefs.luau` (every window, frames,
  tabs, views, dock), `UI/SidebarViews.luau` (sidebar NEST / MINE views generated from the SEEDS frame),
  `UI/LayoutPatches.luau`, `UI/Binders.luau` (live data, actions, accordion, filters), `UI/Screens.luau` (code-built
  windows: profile / settings / leaderboards / Fast Travel / offline / Sound Board via `UI/SoundBoard.luau`),
  `UI/Figma/FKit.luau` (Luau port of `docs/figma/kit.js`), `UI/SampleData.luau` (EVERY placeholder value),
  `UI/Sfx.luau` + `UI/SfxCandidates.luau`, `UI/RobuxShop.luau`, `UI/Figma/IconAlias.luau` (safety net only).
- **Placement (owner screenshot direction 2026-10-09, on Birb's split).** Design canvas 1080 tall (UIScale =
  viewport height / 1080). Permanent **right sidebar** 25 % wide (snapped to 8, min 384), full height, open by default,
  collapse tab (steel key 24x72) on its left edge at mid-height. Left of it is the **game area** `[0, gameRight]`;
  `TOP` = Roblox top-bar inset rounded up + 8 (72 at 1080p); `colR = gameRight - TAB_W - GAP`. Element -> anchor:

  | element | anchor (design px, game-area terms) |
  |---|---|
  | banner | top-left at (EDGE 24, TOP); just the area name (the egg count moved to the area meter) |
  | wallet | ONE column under the banner (GAP 8), progression order eggs, plumes, seeds, twigs, moneta, golden, ore, echo, skill points (Birb map0 order, ours after); every chip 300 wide (x0.85), keys 8 px apart, value right-aligned with the rate under it; the column scales down before it would pass H - 24 |
  | area meter | top-centre at TOP, every area: fishing / mine / nest / expedition / desert / echo bars, and an egg-field bar for Park / Garden / Castle (eggs on the field / cap, per egg, per second, plumes) |
  | travel up, toasts | under the meter (GAP2); toasts on the overlay above every window |
  | COMPANIONS [TAB] | top-right against the sidebar (right edge `colR`), top = TOP; the pull-down board hangs under it |
  | AUTO | under the tucked roller + pull ring (GAP 8), right edge `colR`; hidden while the board is down |
  | area rail | under AUTO (GAP2), right edge `colR` |
  | travel left / right | mid-height; left at EDGE, or right of the wallet column (GAP2) when the column reaches mid-height; right = rail left - GAP2. Label = destination name always; locked = dimmed chip + padlock, requirement in a hover / tap tooltip |
  | icon row | ONE row of 8 icon keys (52 px, 8 apart) centred at the bottom (bottom = H - 24): FISH, PETS, AUTO, SHOP, FAST TRAVEL, MAP, PROFILE, SETTINGS (Birb's core keys keep Birb's order at the right end); labels in hover tooltips |
  | objective | centred just above the icon row (GAP 8) |
  | hotbar / UNLOCK | centred above the objective (GAP 8); travel down left of the objective, bottoms aligned |
  | [E] prompt / big moment | game-area centre at 60 % / 40 % height |
  | dev bar | very top centre, scale 0.55: REGULAR / MAXED / NEXT AREA / SOUNDS |
  | windows | scaled into the WINDOW REGION (`Layout.setRegion`): below the top band (meter, or AUTO when that fits better), right of the wallet column, left of the rail, above the hotbar / objective; Fishing + companion windows dock bottom-left of it; Fast Travel = compact popup right above its key; the rest centred in it |
  | Robux shop | overlay sized to the game area |

  Esc / ButtonB / the close key close the open window only, never the sidebar; opening a window closes the other one.
  Keyboard: Tab = companions board, Q = Objectives, P = Profile (also clickable in the sidebar's hint panel).
- **COMPANIONS board (`UI/CompanionsBoard.luau`)**: a pull-down classroom map. Steel sheet 12 px wider than the
  header, squared wooden roller (12 px rod, metal end caps 12x18, ink outline, soft shadow) with a brass pull ring.
  All six companion rows sit on it; locked ones show dimmed art, a padlock and "Unlocks at <area>" (deny + tooltip on
  click). Drop: track height 0 -> H + 6 in 0.34 s Quad Out (gravity), then H - 2 (0.12 s Sine InOut) and H (0.10 s
  Sine Out); the sheet stretches 1.05 -> 1 over the first 0.20 s; each row's cover fades (0.12 s) when the roller passes
  its middle (delay = T(1 - sqrt(1 - y/H))); the pull ring swings +14 / -9 / +4 / 0 deg (0.12 / 0.18 / 0.14 / 0.12 s);
  sound board_roll_down. Roll up: H -> 0 in 0.26 s Quad In (spring loaded), rows cover as the roller passes (delay
  T sqrt(1 - y/H)), the roller overshoots 5 px into the header (0.06 s) and settles (0.16 s Back Out); sounds
  board_roll_up, then board_clack on the snap. One tweened size drives clip, sheet and roller (no per-frame Lua).
  Tab / the header / the ring toggle it; the state is saved (server pref `prefs.companions`, session attribute).
- **Sidebar = Birb's.** Tabs EGGS / MOLT / SEEDS / NEST / MINE are all sidebar views (NEST / MINE generated from the SEEDS
  frame with live twig / mine rows and a card key into the full window). **Accordion** (Birb captures desert_tab_popcorn,
  map0_seeds, mine_tab_mine): every upgrade still to buy is a card, a maxed one folds into a slim row (icon, name, LV
  chip in gold when maxed, green dot when affordable) after its gold pop; any row folds / unfolds on click (0.18 s
  height ease, rows below slide). Keybind hint panel pinned at the bottom ([WASD] MOVE, [SPACE] HOP, [TAB] COMPANIONS,
  [Q] OBJECTIVES, [P] PROFILE). The MOLT tab's pending plume gain is a violet chip inside the tab under its label; count
  badges sit inside the tab's top-right. Cards show live values (seeds / twigs / ore, per second, tier / area / crow).
- **Figma frame -> window (open from):** sidebar `260:3088` EGGS / `260:3277` golden view (currency switch) /
  `260:4397` MOLT / `260:4544` SEEDS (+ generated NEST / MINE views) · mine `246:4443` SHOP / `248:1739` AREAS (+ CROW
  tab -> crow `246:1276`) (mine meter, hotbar, sidebar MINE card) · treasure `246:1525` (mine down arrow) · trees
  `239:309` / `246:3851` / `246:1796` = SUNFLOWER TREE / DESERT TREE / ARCHIVIST'S BRANCH (title + header theme follow the
  tab) (garden up arrow, echo / desert meter) · fishing `246:3448` / `248:2079` / `248:2952` (FISH key, bridge meter,
  hotbar slots) · aquarium `246:2134` / `246:4667` / `248:1351` (bridge down arrow) + FISH MARKET tab -> market
  `246:2574` (locked `248:1566`) · nest `260:2137` SHOP / `246:1462` LAKE (BREED -> `248:546` -> HATCH -> `248:948`) /
  `260:4842` RIVERSIDE / `260:5761` SAWMILL / `261:600` OWNED (forest meter, sidebar NEST card) · parrot `256:483` /
  `260:753` / `259:613` (+ FORGE `260:3850`) / `260:1011` / `260:3443` (companions) · expedition `260:5073` · sacrifice
  `256:924` / `256:995` · objectives `256:1284` / `260:1565` / `260:2885` (objective bar, Q) · sparrow `259:788`, seagull
  `260:5560`, red panda `256:589` (+ naming `256:806`), dave `259:871` · evolve `260:2568` (castle up arrow).
  Code-built: profile / settings / leaderboards, Fast Travel, Welcome back, dev Sound Board. Debug attributes on
  PlayerGui: `PeckwoodOpen` = "mine:AREAS", `PeckwoodPrompt` = "aquarium", `PeckwoodShop`, `PeckwoodSidebar` (bool),
  `PeckwoodMoment` = text, `PeckwoodCompanions` (bool, plays the board animation). `_G.__uiKeys()` lists every live key.
- **Live vs placeholder:** live = wallet column + rates, banner, area meters, objective + UNLOCK, companions levels +
  locked rows, AUTO, fishing catches / rod, mine area, parrot level, desert chance + field, nest tier + twigs, sidebar
  rows (EGGS / golden / MOLT / SEEDS / NEST / MINE) + cards, MOLT gain + hold-to-MOLT, Mine SHOP rows, FISHDEX (426
  species), Collection / Aquarium filters (filter the Figma sample grids by real fish data), Profile stats, Fast
  Travel, Settings sound. Everything else shows the Figma sample (SampleData for HUD values).
- **Not reproduced / caveats:** header "swoosh" vectors dropped; radial gradients = soft-ellipse approximation; no
  letter spacing; the CAST cooldown conical sweep is not built; Esc belongs to the Roblox menu (ButtonB / close key
  work); only MUSIC volume in Settings; tab locks not enforced; Collection / enemy / quest grids are the Figma sample
  (Fishdex is live). Birb features still missing (need a Figma pass or a system): Parrot UPGRADE slider + typed amount
  and the PARROT CAM toggle; the Objectives GOALS (suggestions) tab; the "?" help keys and settings gear in window
  headers.
- **Keys (owner rule: every key presses in, nothing bubbly on clicks).** `Motion.key(target, kind)` is the only button
  feedback: keycaps (ink body / lip / face) drop body + face by the lip depth with the lip hidden in 40 ms and rise in
  90 ms; flat buttons (tabs, rows, cells, plates) drop 2 px; hover = +6 % veil + 2 px (keycap) / 1 px (flat) lift;
  press_down / press_up / hover_tick sounds. No squash / overshoot on any key; the hero key of a window settles 3 % on
  success (`Motion.settle`, purchase_big). Juice only on outcomes: value pops, bar tweens, fly-ins, maxed gold pop.
  Render keys, tab / btn / seg layers, rows, cells, HUD buttons, rail, arrows, icon keys, the pull ring, dropdowns and
  Kit.button (Robux shop) all go through it. `_G.__uiKeys()` returns { path, kind, pressIn, sfx, keycap, visible }.
- **Motion (all TweenService, event driven; CanvasGroup only during a transition):** open 0.86 -> 1.04 (0.2 s) -> 1
  (0.12 s) out of the button, rows cascade 40 ms; close: rows collapse in reverse, fade + shrink into the button with a
  sparkle burst. Tab switch: no re-pop, no rebuild, the pill glides (0.2 s Quint), content crossfades 0.12 s with an 8 px
  slide. Idle (open window only): header gloss sweep every 4.5 s, glow breathe 2.8 s, sparkle twinkle, up to 2 big icons
  bob, and the window's ONE primary key (its biggest hero key) catches a light sweep every ~3.5 s. Can't afford: shake
  +-6 x3, red flash, wallet wiggle. Maxed: gold pop + sparkles + shimmer, then the sidebar row folds. MOLT:
  hold-to-confirm. Evolve: feed rows wilt. Window headers end in one clean edge: a uniform 1.5 px highlight over a
  full-width 4 px ink line (no fading bevel strip).
- **UX:** wallet counters and sidebar card numbers roll (odometer); `Hud.onLabel(pos, value, cur)` = "+N" floater +
  icons flying into the chip; ONE breathing attention key (the sidebar primary BUY); "recommended" sparkle on the
  cheapest affordable row; unaffordable = desaturated icon + red cost; badges max 2 (molt > fish > eggs > seeds);
  hold-to-buy accelerates, Shift / long press = MAX; lists: thin scrollbar, edge fades, row hover, a very quiet scroll
  tick; dropdown filters (one open at a time, closed with the window); tooltips on icon keys, locked arrows / rail
  slots / Fast Travel rows; windows pre-build in spare frames; toasts stack above windows with a time-left line;
  big-moment banner with music duck.
- **Sfx (`UI/Sfx.luau`):** one function per event; provisional ids = the first licensed candidate of each event in
  `UI/SfxCandidates.luau` (Pro Sound Effects / Roblox UI pack / APM); per-category max length (ui 0.35 s, rewards
  1.2 s, messages 3 s) with a fade-out, optional start offset per id (`Sfx.START`), all ids preloaded; +-5 % pitch;
  SoundGroups ui 0.8 / rewards 1 / messages 1 / music 0.6. Events: press_down/up, hover_tick, tab_switch, window_open/
  close, row_select, dropdown_open/close, toggle_on/off, slider_tick, scroll_tick, board_roll_down/up, board_clack,
  buy_ok, purchase_big, cant_afford, denied, maxed, level_up, collect, coin_land, toast, unlock, island_unlock, molt,
  evolve, egg_hatch_crack, hatch_reveal, error. **Layered events** (`Sfx.LAYERS`): the egg pickup = an eggshell tap
  (layer A, first 0.12 s, speed 1.1-1.25, vol 0.3) + a soft round pop 7 ms later (layer B, 0.25 s, vol 0.4), both warm
  (EQ High -9 / Mid -2 / Low +3 dB), +-4 % per pickup + the combo climb; golden eggs pitch the pop up 1.12 with a faint
  sparkle tail. **Dev Sound Board** (dev bar SOUNDS): one row per event (collect has a row per layer), A-D audition
  candidates through the real path (a layer plays the whole egg sound with that candidate in), USE applies the pick
  live and saves it (server dev DataStore key `dev_sfx_picks_v1`, sent back as the `PeckwoodSfxPicks` attribute),
  COPY TABLE prints the IDS table to the output.
- **Visual hierarchy system (apply to every new screen):**
  - *Emphasis levels.* L1 primary = one saturated key per window / list (green BUY or GO; gold for premium) - the only
    element allowed to breathe or shimmer. L2 secondary = steel keys (MAX under BUY via `Binders.quietKey`, inactive
    tabs, spend amounts, popup actions, the sidebar tab). L3 tertiary = text and ghost labels. The red close key is
    fixed furniture (44 px at W-54, 10), not an action.
  - *Colour semantics.* Green = buy / go / gain / affordable. Gold = premium / maxed / golden. Red = close / danger /
    can't afford (cost text). Violet = reset (MOLT, sacrifice, the MOLT gain chip). Blue = info. Steel = neutral.
  - *Numbers vs labels.* Numbers lead, bigger / white with the ink outline; labels follow, smaller and muted; costs are
    icon + number; text is measured and fitted to its box (`Render.fit`, title + LV chip laid out by width), never clipped.
  - *Spacing.* Only `Layout.S`: EDGE 24, GAP 8 (inside a group), GAP2 16 (between groups), WIN 24; one top edge (TOP)
    for banner, meter and COMPANIONS; one bottom edge (H - 24) for the icon row.
  - *Motion budget.* Only the open window idles; on the HUD at most ONE attention animation plus max 2 badges; no key
    ever bounces; no per-frame loops.
- **Checks (no Studio used):** `rojo build` OK; `luau-lsp analyze` clean on the UI; `lune run tools/ui_harness/run.luau`
  (real UI modules on lune's instance model; tween Completed chains run) opens every window / tab / view, presses every
  key and asserts, 0 errors: sidebar open at start and with every window; every window inside the window region (the
  popup inside the game area); tab routing (open by name and click every tab layer of every tab variant); tab switches
  neither re-pop nor rebuild; sidebar collapse / reopen; no HUD group in the sidebar; **key audit** (every button-like
  node registered with press-in + sound, no Squash UIScale anywhere: 1036 / 1036 wired at the last run, 1078 live keys
  in `_G.__uiKeys()`); every icon name resolves (0 missing); the accordion (defaults, heights, fold / unfold); NEST /
  MINE views have live rows; filter bars filter and RESET restores; the COMPANIONS board drops, rolls up, holds all six
  rows with correct locked looks and hides / restores AUTO. `python tools/ui_harness/mock.py <refs> <out.png>` turns
  `tools/ui_harness/layout_dump.json` into a 1920x1080 placement mock.

---

## New chat? Paste this first
> Paste `NEXT_CHAT_PROMPT.md` (everything below its line). It is the up-to-date starter; the short version: Read `HANDOUT.md` section 0 in `~/Downloads/rc-main` (repo jewdah-afk/research-calculator, branch main). The Roblox game is in `rc-main/roblox` (Rojo), and it is synced into Studio place **birb(test)**; `~/OneDrive/Desktop/Peckwood.rbxl` is the latest build. Start `python -m http.server 8778 --bind 127.0.0.1` in `rc-main/roblox`, then push edits into Studio with the `tools/sync.luau` snippet. The owner is reviewing the build in Studio and will list fixes; do them, sync, check with the debug hook (section 0), then rebuild and copy the `.rbxl` to the Desktop.

## 0. Start here (Roblox build status, 2026-10-07)

The Roblox game now lives in **`roblox/`** (Rojo). The owner has synced it into the place **`birb(test)`** (placeId 104948155633094) and published it. `rojo build -o roblox/Peckwood.rbxl` makes a fresh place file.

### What is built
| Part | Where | State |
|---|---|---|
| Map, bird controller, kernels, camera (from the old place) | `src/server/Island.luau`, `src/client/{Main.client,Controller,Birds}.luau`, `src/shared/{MapData,Models}.luau` | Working. The old `UI.luau` is deleted. |
| Verified math + data | `src/shared/{EternityNum,BirbFormulas,BirbSystems}.luau`, `src/shared/Data/*.json` | Copied from `birb-data/`. A junk row was removed from `quests.json`. |
| Every shop row (cost, effect, max level) | `src/shared/Defs.luau` | All 160 upgrades resolve through `Defs.UP`. The islands progression order (`Defs.ISLANDS`) is here too. |
| Server: state, every system, actions, saves | `src/server/Game.luau` (pure logic), `src/server/Main.server.luau` (players, field, remotes) | Popcorn field, Molt, seeds, sparrow, evolve, fishing (426 fish rolls, rods, baits, aquarium), seagull, Dave, red panda, nest, crow mining, echo, expedition, quests, sacrifice, profile. |
| Dev saves | `Main.server.luau` `A.dev` | **REGULAR** (your real save), **MAXED** (everything unlocked and maxed), **NEXT ISLAND** (works on a copy and steps forward one unlock). The sandbox states never save. Only Studio, the owner, or `Config.DEV_USER_IDS` can use them. |
| AUTO = group perk | `Config.GROUP_ID` (**still 0, set it**), `A.auto` | Membership is checked on the server with `IsInGroup`. Locked players get `GroupService:PromptJoinAsync` and then a re-check. AUTO collects a kernel every 0.35s and buys the cheapest affordable upgrade every 1s. While `GROUP_ID` is 0, it only works in Studio. |
| UI | `src/client/UI/{Kit,Window,Windows,Spec,Hud}.luau` | Details below. |

### How the UI matches Figma
- **Superseded on branch `claude/peckwood-ui`:** the baked-art windows below were replaced by generated Figma layouts
  rendered live (section A, "In-game UI from Figma"). The notes below describe the old build on `claude/peckwood-isle`.
- **Window art is the Figma frame itself.** The temporary atlas `83:7` holds a copy of each UI v2 window with its live layers hidden (text, `ico/*`, `btn/*`, sparkles, progress fills, chevrons). Each copy was rendered at 2x (including the rim glow, with a 150px margin at 1x), uploaded, and listed in `src/shared/FigmaArt.luau`. Button faces (`btn/<window>_buy|tab|hero`, `grey_buy`, `grey_all`, `blue_all`, `gold_maxed`) were cut from `roblox/assets/figma/buttons_sheet.png`.
- **Live layers are drawn on top at the Figma coordinates** (`Window.luau`): title, tab contents, hero icon/title/subtitle/button, section label, row icon/title/growth/description/progress fill/buttons, footer, sparkles.
- **Texts and colours per window** are in `Spec.luau`, extracted from the Figma layers. Icons are the PNGs actually placed in each Figma slot, matched by image bytes rather than by the stale layer names.
- **Motion** follows the spec cards: open (0.86 to 1.04 to 1), close, rows cascading in, icons bobbing ±3px, hero icon tilting ±4°, sparkles twinkling, buy-button glow pulsing, shine sweep when something becomes affordable, can't-afford shake with red flash, wallet capsule wiggle, currency particles flying to the HUD, violet flash on Molt.
- **HUD** (`Hud.luau`): Figma `8:271` (map banner, toast, wallet capsules, objective bar, shop docked on the right). Additions: the window menu (3 columns, only unlocked windows show), the dev panel, the AUTO button, the UNLOCK button for paid island gates, and the full Fish Index overlay.
- **Gotchas found:**
  - A UIGradient on a CanvasGroup tints everything inside it. Put gradients on a child frame instead.
  - Only one UIScale applies per object. The fit-to-height scale sits on a wrapper.
  - Images taller than about 2048px did not render, so window renders are resized to fit (`assets/figma/fit/`).
  - The Roblox top-left menu covers HUD y<60.

### Eggs replace popcorn (2026-10-08, owner's call)
Eggs are now the main currency. **Only what players see changed; internal ids stay** (`popcorn`, `goldenPopcorn`, `echoPopcorn`, `p_*`/`pr_popcorn_mult` upgrade ids, save keys, `BirbFormulas`), so saves and the verified Birb math are untouched. Golden popcorn is now golden eggs, and echo popcorn is now echo eggs.
- Code: display text in `Defs`, `Shop`, `Spec`, `Windows`, `Hud`; the field pickup `Models.kernel` is now a speckled egg (gold version for golden). The field model is named `Eggs`.
- Figma UI v2: 82 text layers renamed; the popcorn and golden icon fills in all windows, the HUD icon `108:7` and `icon/popcorn`/`icon/golden` swapped to `egg`/`egg_golden`. Egg Robux shop icons are in `145:7` (the popcorn strip `128:7` is kept for reference).
- **To do:** upload `birb-icons/final/egg.png`, `egg_golden.png` and the new `shop_*.png` to Roblox and replace the `popcorn`, `golden` and `shop_*` ids in `Icons.luau`; re-export the Figma window art (`FigmaArt.luau`), since the baked window renders still say POPCORN. The `birb-data/*.json` descriptions still say popcorn (Birb source data, not shown in game).
- **Upgrade icons (2026-10-08):** stat-upgrade rows = the current icon + a painted 3D badge on the lower right (green up arrow = value, blue plus = cap, yellow bolt = speed, orange × = multiplier, red burst = power, teal circular arrow = regen). Badges are `birb-icons/final/badge_*.png` (Figma AI sheet `sheets/badges_sheet.png`); in Figma each `icon/<name>` frame next to the Icon assets strip is a `base` image + a `badge/<type>` image (62px at 68,66), merged by `birb-icons/compose_upgrades.py` (base scaled 0.9 to the top-left, badge 118px bottom-right, then `clean_ring` so icon and badge share one crisp ink outline like the wallet icons) into `final/up_<name>.png`, placed on every matching `ico/<name>` slot (square-top atlas `117:7` and UI v2). Bases come from the up-to-date set (egg/mining sheet + shop icons: carton for Egg Cap, single 3-egg crate (`shop_crateS`) for Auric Silo, basket for More Eggs, hatch for Quick Pop, gold touch for Gilded Margins, plain `magnet` + up arrow for Long Neck (owner: the magnet with eggs reads badly), miner crow for Mining Power, charged pickaxe for Charged Strike, `wing` + bolt badge in the corner for Wing Training (owner: a bolt on the wing itself looks bad)). Parrot Health/Damage/Regen are composed the same way on `stat_heart`/`stat_sword` (painted in `sheets/badges_sheet_2.png`, which also replaced the bolt and loop badges; the burst stays the first painted one, owner's pick). `badge_regen` keeps its centre hole open (OPEN_HOLES in cut_grid/clean_ring). Owner rejected hand-drawn vector badges and old approved-sheet icons. Still to upload to Roblox and map in `Icons.luau`/`Spec.luau`.
- New icons from the egg/mining sheet (cut from a low-res preview, recut from the original when available): `egg`, `egg_golden`, `egg_shiny`, `shop_*` (eggs), `ore_*` tiers, `golem`, `pickaxe_charged`, `rupture`, `mine_chest`, `crow_miner`, `anvil`, `minecart`, `tombstone`.

### Gap audit (2026-10-08): built / simplified / missing
Checked against `birb-data/SYSTEMS.md`, `CORE_FORMULAS.md`, `Game.luau`, `Spec.luau` and the Figma UI v2 page. Figma = a frame exists on UI v2; Game = playable in `roblox/`.

**Built (Figma + Game)**
- [x] Eggs shop, Molt (Plumes), Seeds, Golden, Echo shop, Mine shop (4 rows), Nest shop (3 rows), Evolve (feed + evolve)
- [x] Companions: Sparrow, Seagull, Dave, Red Panda
- [x] Fishing: Rods (craft), Baits, Fish Index (tab + full overlay), Aquarium
- [x] Expedition: Parrot skill points, Quests (3 dailies), Sacrifice (first 3 tiers), Profile + ALL STATS
- [x] HUD: wallet, left tiles, group bars, map banner, goal bar, toast, Robux shop v3 (`130:7`, `132:7`)
- [x] Game only (no Figma frame yet): Map overview, Teleport popup, Settings popup (sound toggle only), dev panel

**Simplified (works, but not 1:1 with Birb yet)**
- [ ] Twigs: a flat 1 peck/s + Peck Rate. No trees, tree HP, spawns, axe or offline efficiency.
- [ ] Mine: ore comes in as a rate. No ore HP bar, areas to pick, giants, Mineral Coffers or idle claim. Crow XP is estimated from breaks.
- [ ] Expedition: auto-fight against floor band-0 HP, 35 kills per floor. No enemy types, elites, bosses, depth bands or potions.
- [ ] Parrot stats: only skill points and quest bonuses. No equipment, artifact or progression multipliers.
- [ ] Quests: dailies only, the 19 main quests are not listed.
- [ ] Sacrifice: 3 of 18 tiers shown.
- [ ] Seagull level cap is fixed at 50.
- [ ] Desert: the golden toggle and Golden shop only. Auric Silo opens on arrival.
- [ ] Fishing: hooks and lures have icons but can't be equipped. The aquarium modifier table isn't pulled.

**Missing screens (no Figma frame, no Game UI)**
- [ ] Mine / Areas: area picker, ore HP, giant with respawn timer, coffer meter, idle claim
- [ ] Mine / Tree: mine tree nodes (cost `anchor(POWER_ANCHORS, area−1, 36)·(6+branch)`)
- [ ] Nest / Cultivation: 16 tree boxes plus the 6 buildings (Fertilizer … Watering Well)
- [ ] Nest / Riverside: Lumberyard, Pollinator, Compost, Grove ×4, Nursery
- [ ] Nest / Carpentry: Forestry, Timber, Saw, Tools tiers, Bench, Workshop, Mastery/Expansion
- [ ] Expedition / Gear: beak, armor, aura with rarity and level 1–5, spirit costs
- [ ] Expedition / Artifacts: slots (3 + rebirbs), owned list, infusion
- [ ] Expedition / Parrot Rebirb: 3 rebirbs and their requirements
- [ ] Quests / Main: the scrolling 19-quest list
- [ ] Sacrifice / all 18 tiers list
- [ ] Echo / Archivist tree: Echo Chance, Value Milestones, R/F/A nodes, mushroom collectors
- [ ] Research trees (`d_*`, 143 one-off unlocks, only 11 used in Game): **Seed tree** (~86 nodes: seeds, sparrow, fishing, seagull, spirit), **Desert tree** (51 `d_desert_*`, paid in golden eggs or Brute Ore, some gated by mine area) and **Archivist tree** (6 `d_archivist_*` + echo field nodes)
- [ ] Companions: Seagull Frenzy and route/forecast, Sparrow Resonance and Mitosis states, Dave XP bar
- [ ] Forest: tree tiers (Normal / Birch / Autumn, fresh/growing/mature HP)
- [ ] Expedition: floor select, boss / elite screens
- [ ] Meta: leaderboards, offline earnings popup (8h cap, Red Panda 55%), new-island unlock toast
- [ ] Fishing / Tackle: equip hook, lure and fish
- [ ] Settings panel (full), Map and Teleport in Figma
- [ ] Map boards per area (from the World Guide artifact): Park, Garden, Castle, Bridge, Forest, Mine, Desert, Expedition, Echo Field

Figma progress for the missing screens and map boards is logged under "Missing screens board" below.

### Missing screens board (Figma, 2026-10-08)
Board **`168:7`** "Peckwood UI v2 / Missing screens" on page UI v2 (below the shop board, y 9000). Every window is a clone of a square-top frame from `117:7` with its live layers turned back on, scaled to 1x, with text, rows and icons replaced. Icons are the PNGs from `birb-icons/final/` (image fills, FIT). Each window has a motion spec card under it (cloned from `49:161`).

| Band | Windows (node) |
|---|---|
| Mine and Nest | Mine / Areas `171:7`, Mine / Tree + crow rebirb `171:383`, Nest / Cultivation `173:7`, Nest / Riverside `173:465`, Nest / Carpentry `173:873`, Nest / Forest `173:1214` |
| Expedition | Gear `174:7`, Artifacts `174:299`, Parrot Rebirb `174:623`, Floors + boss `174:948`, Quests / Main `174:1289`, Sacrifice / All tiers `174:1697` |
| Trees and companions | Echo / Archivist tree `176:7`, Desert / Research tree `176:432`, Seeds / Sunflower tree `176:873`, Fishing / Tackle `176:1294`, Seagull / Migrations + Frenzy `176:1735`, Sparrow / Mitosis + Resonance `176:2160`, Dave / Branches `176:2501` |
| Meta | Profile / Leaderboards `177:7`, Profile / Settings `177:434`, Offline / Welcome back `177:877` |

Notes for the owner's review:
- New screens show two tabs (parent window + the new one), like the existing frames; in game the tab bar comes from `Spec.GROUPS`.
- Long Birb names were shortened so every row keeps the same type size: Near Response (Nearby Response), Desert Harvest (Treasured Harvest), Irrigation (Sunsprout Irrigation), Sand Harvest (Sandstorm Harvest), Fast Farming (Efficient Farming), Wisdom (Ancestral Wisdom), Double Catch (Echo Double Catch).
- Not in `birb-data` yet, so shown as a guess or "—": the mine tree node order per area, Lumberyard and Compost effects, the Tree Spawns cost, artifact infusion caps (wiki values).
### Hero icon outlines (2026-10-08, owner's call)
The 41 big hero icons on UI v2 had 8 stacked 2 px ink drop shadows (offsets ±2 and ±1.4 diagonal, radius 0, #0B0C10) drawing a second outline on top of the PNG's own ink ring. Removed, so only the PNG ring shows. Key and tab icons still have their thinner extra outline (1–2.4 px), untouched. The Roblox UI draws the PNG directly, so it already matches.

### Playtest: HTML copy of Birb (2026-10-08)
`playtest/` is a plain HTML/CSS/JS copy of Birb's gameplay with our names and icons, built phase by phase from the live birbplay.com code, to compare with Figma and Roblox. Done: Phase 1 (Park, Molt, seeds, sunflower tree, Sparrow, Castle evolutions), Phase 2 (Bridge fishing, Seagull) and Phase 2b (Aquarium, Fish Market) Phase 3 (Nest, planting beds, Red Panda, offline twigs, fish breeding) Phase 4 (Mine and Crow; in Birb the Mine opens after the Expedition) Phase 5 (Desert: golden eggs, sandstorm, Dave), Phase 6a (Expedition floors, enemies, the Parrot, rebirbs), Phase 6b (loot, artifacts, potions, forge, Sacrifice Room) and Phase 6c (quest merchant, fish market parrot buffs, floor 1 secret room to the Mine, night mode, mythic sacrifice, parrot totem, Birb's Expedition HUD) Phase 7 (Archivist's Book, archivist branch, Echo Field) and Phase 3b (Riverside and the sawmill). The screen layout copies Birb's real screens (captured in `playtest/parity/birb_ui/`). `playtest/parity/parity.js` loads the same save into Birb's live engine and the playtest and compares every shared formula (80461 / 80461 match). The crow's expedition tracks are in too (only saved levels count; Birb switched the drain off). Next: re-check Birb for new content. **Working on the playtest? Start with `playtest/NEXT.md`** (goal, file map, research tools in `playtest/tools/`, the ordered task list). See `playtest/README.md`, and `playtest/DIFFERENCES.md` for where our game differs from Birb.

### Map boards (Figma, 2026-10-08)
Frame **`178:7`** "Peckwood / Map boards" on page UI v2 (x 4200, y 9000), built from the owner's World Guide artifact (layout #1 "Peckwood Isle").
- **World / unlock order** `178:10`: the 9 unlock steps in `Defs.ISLANDS` order (map view), plus the whole world at night 01:00 and golden hour 18:30.
- **One board per area** (Park `178:34`, Garden `178:66`, Castle `178:102`, Bridge `178:138`, Forest `178:174`, Mine `178:210`, Desert `178:246`, Expedition `178:282`, Echo Field `178:318`): hero shot at 11:00, night 01:00, a wide shot of how it joins its neighbours, the unlock moment in four frames (before, rising, settling, after), the HUD v3 zones over the map, and a notes card (props from `IslandData.luau`, effects, joins, terrain colour, how to rebuild in Studio).
- Captured headless with `concepts/capture/world_guide_areas.js` and `world_guide_overview.js` (Playwright + SwiftShader; save the artifact HTML locally, serve it, run `node <script> <outDir> <url>`). The unlock frames freeze `performance.now` and step it 0.5s / 1.2s / 7.2s after `unlock(n)`.
- The cyan strips between areas in the world shots are the guide's shallow-water seams, not fog.

### Open issues (do these next)
1. **Done:** all 83 Figma images load. They took about 1 hour in Roblox moderation after upload, so new uploads look blank until they clear.
   **Also fixed:**
   - MAXED froze the server: the level-up loops ran without end. They are now capped (crow 500, parrot, sparrow and Dave 1000).
   - The buy particle effect is removed (owner's call).
   **Debug hook:** `PlayerGui:SetAttribute("PeckwoodOpen", "<window id>")` opens a window, and `Remotes.Action:FireServer("dev", "maxed")` from Client `execute_luau` switches the save. Use these for screenshots without clicking.
2. Delete the Figma temp atlas `83:7` once the art loads (`use_figma`: `(await figma.getNodeByIdAsync('83:7')).remove()`).
3. Upload the 426 fish icons (`birb-icons/final/fish/`, batches of 25, serve on :8799) and add them to `Icons.luau` using `tools/rec.py` and the generator snippet. Until then, fish rows show no icon.
4. Islands other than the Park reuse the Park map. The Desert is a field toggle (golden drops). Each island still needs its own 3D area: garden, bridge/fishing spot, forest, mine, castle.
5. **Next up (no Studio access for now, Figma only):** gap audit of the remaining Birb gameplay, design every missing screen in Figma, map boards per area from the owner's World Guide artifact (https://claude.ai/artifact/Ux19BGfq7Jq4De8RCBYiwL), then the visual hierarchy QA in Figma. Details in `NEXT_CHAT_PROMPT.md`.
6. Unverified numbers: seeds base 3/s (from the Figma copy), fishing cast 4s × rod speed, expedition kill rate and floor progression (simplified), Dave XP from golden pickups.

### Tools
- `roblox/tools/gen_manifest.py` writes the list of scripts to sync.
- With `python -m http.server 8778 --bind 127.0.0.1` running in `roblox/`, run the sync snippet `tools/sync.luau` through `execute_luau` in Edit mode. It pushes every `.luau` into the open place. JSON data needs `rojo build`.
- `tools/rec.py` / `tools/rec2.py` record uploaded asset IDs into `asset_ids.json` / `figma_ids.json`.

## 1. What the project is

Peckwood is a Roblox remake of **Birb** (hwonze; web build at birbplay.com). The goals:

- **Gameplay math:** must be **1:1 with the original**. Every cost, multiplier and curve is copied from the original game's code, not guessed.
- **Art and UI:** new. Uses the Peckwood UI v2 style in Figma.
- **3D item drops:** planned. They will be Blender models.

### Peckwood names for Birb concepts

Use the Peckwood name in UI and copy, and the Birb name in code comments when it helps to cross-reference the original.

| Birb (code / original) | Peckwood (UI) |
|---|---|
| Rebirb | **Molt** |
| Golden Feathers | **Plumes** |
| Popcorn | Popcorn |
| Sunflower Seeds | Seeds |
| `p_` upgrades | Popcorn shop |
| `pr_` upgrades | Molt shop ("Plume Keepsakes") |
| `s_` upgrades | Seed shop |

**Level display:** the Peckwood UI shows the internal level minus 1. Popcorn Value internal level 4 displays as "LV 3 / 998". All formulas use internal levels, so subtract 1 when displaying.

---

## 2. Repo map (`jewdah-afk/research-calculator`, branch `main`)

| Path | What it is |
|---|---|
| `birb-data/CORE_FORMULAS.md` | Core loop: cost rules, popcorn spawn and type odds, popcorn value stack, golden popcorn, rebirb (Molt) feathers |
| `birb-data/SYSTEMS.md` | Every other system (full list below) |
| `birb-data/UPGRADES.md` + `upgrades.json` | All 160 upgrades: currency, base cost, growth, max level, effect |
| `birb-data/data/*.json` | Raw game tables: 426 fish, rods, baits, 47 artifacts, 43 enemies plus type modifiers, sacrifice milestones, 33 quests |
| `birb-data/EternityNum.luau` | Big-number library (see §3) |
| `birb-data/BirbFormulas.luau` | Luau port of the core loop. Wallets are EN values. Includes `buy` and `buyAll` |
| `birb-data/BirbSystems.luau` | Luau port of the systems math |
| `birb-data/README.md` | How the files fit together, and how to drop them into Roblox |
| `.claude/settings.json` | Lets Claude use Figma tools without permission prompts |
| `index.html` | Older research/RLGM calculator. Not part of the Birb port |

`SYSTEMS.md` covers:
- Mining and the crow
- The nest: twigs, cultivation, carpentry, riverside
- Fishing
- Sparrow, Seagull, Dave and Red Panda
- Evolution
- Parrot combat and enemies
- Equipment and artifacts
- Sacrifice and the Quest Merchant
- The Echo field

**Source of truth:** the birbplay.com web build, pulled on 2026-10-06. The bundles were `game-C7SSmAJa.js`, `editors-BzRYmPQ2.js`, `maps-CcKoUYtq.js` and `main-DBny4oxD.js`. If the original game patches, re-pull these and diff them.

---

## 3. Verification status

Every Luau port was run against the original game's own functions, copied word for word out of the bundles. Every row below passed with zero mismatches.

| Check | Values compared |
|---|---|
| Upgrade costs, all 160 upgrades at levels 0–30 | 4,960 |
| Mine costs, ore and giant HP and rewards, nest costs, tree boxes, carpentry soft-cap, Parrot and Seagull XP, all 43 enemies on floors 1–12 (normal and boss) | 3,347 |
| EternityNum vs break_eternity.js: add, sub, mul, div, pow, pow10, log10, ln, sqrt, exp, floor, ceil, cmp, over layers 0–3 | 22,629 |
| Buy-all closed form, save round-trip, leaderboard encoding order | Unit-tested, all pass |

**EternityNum:**
- Same `{sign, layer, mag}` layout and function names as FoundForces' EternityNum: `add`, `mul`, `me`, `meeq`, `le`, `leeq`, `eq`, `short`, and so on.
- The original model needs a Roblox login to download, so this is a clean port of break_eternity, which is the library both EternityNum and the original Birb are built on.
- Extras:
  - Fast paths for plain numbers.
  - `geomSum` / `geomAfford` for O(1) buy-all.
  - `toString` / `fromSave` for lossless saves.
  - `lbencode` / `lbdecode` for OrderedDataStore leaderboards.

**Not covered yet:**
- Rendering, animation and multiplayer code. These aren't game balance.
- Per-enemy AI attack patterns. Their stats are covered.
- The aquarium modifier table.
- Artifact infusion caps. These come from the wiki and are unverified against the code.

---

## 4. Figma

**File:** https://www.figma.com/design/SQOJ2gzGt12vFMGGlNRWBE (page **UI v2**, node `7:7`)

Watch the file key: the letter after `GG` is a lowercase **l**. A key with a capital I opens a different file that this account can't access.

### What's on UI v2

| Node | Frame |
|---|---|
| `7:8` | Icon assets: popcorn, plume, golden, wing, magnet, clock, seed, index, crown, plus textures (studs, stripes, lattice, grain) |
| `8:7` | **Shop board**, containing the three windows and specs below |
| `8:122` | Popcorn shop (amber), layer 0 |
| `8:250` | Molt shop (violet), layer 1, with hero |
| `43:7` | Seeds shop (green), layer 2, with sunflower hero |
| `49:10` | **Golden shop** (gold, desert), with the desert hero and new textures |
| `57:7` | **Mine shop** (steel cyan, crow hero), 4 rows: Mining Power, Ore Value, Charged Strike, Rupture. Uses the final icons |
| `59:7` | **Nest shop** (cedar red-brown, nest hero), 3 rows: Twig Value, Peck Rate, Peck Power |
| `60:7` | **Echo shop** (magenta, echo spirit hero), 2 rows: Echo Value, Echo Capacity |
| `61:7` | **Parrot / expedition** (emerald, parrot hero), 3 skill-point rows: Health, Damage, Regen. Buttons read SPEND ALL |
| `62:7` | **Evolve** (crimson, castle monster hero), 3 feed rows for evolution 3 to 4: popcorn 1Qa, twigs 100K, moneta 10K. Buttons read FEED / FEED ALL |
| `45:7`, `45:19`, `45:33`, `49:161`, `57:166`, `59:166`, `60:166`, `61:166`, `62:166` | Motion spec cards under each window |
| `65:8`, `65:181`, `65:354`, `65:527` | **Companion panels** (row under the shops, label COMPANIONS): Sparrow (Feed, Resonance, Mitosis), Seagull (Route, Doctrine, Migration), Dave (Seed Training, Rebirb), Red Panda (Assist Mode). Spec cards `65:167`, `65:340`, `65:513`, `65:686`. Header, tab and hero use the new `sparrow`, `seagull`, `dove` and `redpanda` icons |
| `70:8`, `70:181`, `70:354`, `70:527` | **Fishing** (row under companions, label FISHING): Rods (craft Normal/Reinforced/Pro from fish), Bait (Coastal Chum 1, Fresh Pellet 5, River Grub 10 moneta), Fish Index (sample catches Silver Fish, Swallowtail, Huchen with EQUIP/SELL), Aquarium (2 tanks, PLACE). Shared deep-ocean base 216°; buttons per icon: rod red, worm pink, clownfish orange, seaweed green. Tabs read "Fishing / <tab>". Rows use the real tiered icons (rods by tier, baits, fish, tanks by size) |
| `75:8`, `75:181`, `75:354` | **Quests, Sacrifice, Profile** (row under Fishing). Quests: merchant hero, 3 dailies (floor kill, hunt, boss) with CLAIM/TRACK. Sacrifice: altar hero, milestone rows Tier I-III (450, 10K, 100K) using `sacrifice_I`..`XVIII` crests that grow more ornate per tier. Profile: `birb` hero, records rows (fish index, highest floor, sacrifice tier) and an **ALL STATS drop-down** (`80:7`, HIDE ▲) with 18 icon stat chips in two columns |
| `8:271` | HUD 1920×1080: money capsules, map banner, objective, toast, docked shop |

Page 1 of the same file holds an older version with studded buttons. Don't use it as a reference.

### Rules for every new screen (non-negotiable)

1. **Duplicate the real frames** (header, tabs, rows, buttons, progress bars) from the UI v2 windows. Never redraw them. Change only text, icons and theme colors.
2. **Each reset layer gets its own identity** (color and hero), while keeping the same layout order: header → tabs → hero (for reset layers) → section label → rows → footer. The footer must state what resets that layer.
3. **Premium FX on every window:**
   - Two-layer rim glow in the theme color.
   - Top edge light.
   - 4-point sparkles in the header and hero.
   - Glow on affordable buy buttons.
4. **Motion is documented in two places:** a Motion spec card under the window, and Figma annotations on the layers themselves (window, header, every `btn/buy`, every `progress`, the hero).
5. **Header:** title only, centred (no icon, user's call). The lip under the header is a 12px band in the theme's own dark tone, not black, with a 2px tinted ink line. A soft tinted drop shadow (y 6, blur 14, 38%) falls on the body, plus a tight 2px contact shadow. Keep the header clipped.
6. **Fonts:**
   - Fredoka One for titles and buttons.
   - Fredoka for body text.
   - Ink color `#0B0C10` for strokes.
   - Fredoka has no `↔` glyph. Write "to" instead.

### Theme palette so far

| Layer | Header gradient | Glow |
|---|---|---|
| Popcorn | `ffd27a → f7a634 → e07a1c → 9e4a0c` | `ffb45a` |
| Molt | `e9c4ff → b06cff → 8a3fe6 → 4f1d9c` | `b06cff` |
| Seeds | `e6ffc4 → 8fe04a → 4fb52a → 256a12` | `8fe04a` |
| Golden | the Seeds gradient hue-shifted to gold (hue 44°, darks 34°) | `ffd259` |

**Icon-matched palettes (2026-10-07).** The user wants every window coloured from its hero icon's own colours, using several of them. Each window has three roles: **p** (header, hero, body), **b** (main buttons and active tab) and **a** (row titles and stat text). Each is a target hue plus saturation and lightness factors applied to the Golden source colours:

| Window | p | b | a |
|---|---|---|---|
| Mine (crow + ore) | navy 226° | ore cyan 194° | beak yellow 46° |
| Nest | wood brown 22° (l×0.88) | leaf green 105° | egg yellow-cream 46° |
| Echo | deep violet 282° (l×0.88) | hot pink 322° | bright pink 328° |
| Parrot | red 356° (l×0.88) | wing blue 212° | yellow 50° |
| Evolve (monster) | deep teal 192° (l×0.82) | mouth purple 284° | mint 160° |
| Sparrow | chestnut 22° (l×0.85) | seed yellow 48° | cream 40° |
| Seagull | wing blue-grey 212° (s×0.7, l×0.85) | beak yellow 48° | white 50° (s×0.2) |
| Dave | dove lilac 278° (s×0.42) | leg pink 335° | pale lilac 290° |
| Red Panda | dark maroon fur 356° (l×0.78) | rust orange 20° | cream 40° |

**Rule (user's call, Mine is the reference):** a deep, darkened base hue, buttons in a bright hue far from the base, and stat text in a third contrasting hue. Never three shades of one hue.

The BUY ALL buttons and progress bars keep the Golden source colours.

**How the new windows were made:** clone `49:10` and `49:161`, add or remove `row/*` (126px pitch, window height follows), recolour by walking the clone alongside `49:10` and mapping each warm colour (hue 10–70°) to the window's p/b/a role (greys, inks, the blue BUY ALL and progress bars stay as they are), rewrite text, then upload PNGs from `birb-icons/final/` as FIT image fills on the cloned `ico/*` rectangles. The board `8:7` was widened for each.

### Textures (in `7:8`)

These are new 2026-10-07, inspired by glossy tile references: a fine dot grid, twin diagonal glass streaks, a bright inner rim and a dark bottom lip.

- `tex/halftone` (`49:7`): white dot grid, used as an OVERLAY tile. Header 35%, button faces 22%, row cards 10%.
- `tex/dunes` (`49:8`): wavy sand ripples, used as an OVERLAY on the desert hero art.
- `tex/glitter` (`49:9`): sparse 4-point glints, used as SCREEN on the hero.
- `fx/glass streak`: a wide band plus a thin band at -35°, using a SCREEN gradient. It sits on row cards and the hero art.

Use these on the remaining windows too.

### Shared motion language

The full text is on the spec cards. In short:

| Moment | Motion |
|---|---|
| Open | Scale 0.86 → 1.04 → 1 (320ms back-out) from the HUD button. Rows cascade in with a 40ms stagger |
| Close | Rows collapse in reverse first, then the window fades into the HUD button. Sparkles burst out |
| Idle | Header gloss sweep every 4.5s. Sparkles twinkle. Rim glow breathes over 2.8s. Icons bob ±3px |
| Buy | Press squash 0.94, then release with a 1.06 overshoot. The stat value pops, the bar tweens, and currency particles fly to the HUD wallet |
| Can't afford | Shake ±6px ×3 and a red cost flash. The HUD wallet wiggles too |
| Maxed | Gold plate pops in with sparkles. The level bar turns gold and shimmers |
| Tabs | The pill springs between tabs, and the whole window retints to the target layer |
| Reset moments | **Molt:** hold-to-confirm, then a violet flash, feathers fly to the Plumes counter, and rows dissolve into dust. **Evolve:** seed rows wilt brown and fall away |

### Other Figma file (can be deleted)

"Peckwood UI Kit" (`tx8B2elQnVUSzhrPNseVrq`) is an early attempt that does **not** match the v2 style. It's safe to delete once the user confirms.

---

## 5. Next steps (in order)

0. **Roblox Studio build: see section 0** (1:1 import, Regular + Maxed saves with a non-destructive next-island toggle, wiring, polish, then map hierarchy).
1. **Review the five new windows** with the user (Mine, Nest, Echo, Parrot, Evolve). Open questions: the Nest footer says Molt and Evolve keep twigs and the twig shop, which is not verified in the data; Moneta uses the fish icon; Rupture uses the sword.
3. **Fishing follow-ups:** the aquarium modifier table once it is pulled from the bundle.
4. **Quests, sacrifice and profile follow-ups:** a scrolling main-quest list (19 quests) and a full 18-tier sacrifice list.
5. **Missing icons** in the icon-set style: spirit, and any new currencies the remaining windows need.
6. **Blender models for all item drops**, matching the icon set. Not started.
7. **Roblox wiring:** drop the three ModuleScripts (`EternityNum`, `BirbFormulas`, `BirbSystems`) into ReplicatedStorage. Load `upgrades.json` and `data/*.json` as data modules.

---

**Mine shop data:** costs at level 0 are 240, 180, 4,800 and 2e6 Brute Ore. All four are non-permanent, so Evolve resets them.

**Golden shop data:** Golden Value (`p_golden_popcorn_value`, base cost 10, ×1.55, max 999), Auric Silo (`p_auric_silo`, base cost 1000, ×1.8, max 50) and Gilded Margins (`d_desert_field_notes_plus`, base cost 5000, ×10, max 3). Molt resets the two `p_` rows. The golden popcorn balance and the desert unlocks are kept. The other one-off desert unlocks still need a tree screen.

## 6. Gotchas

- **`use_figma` writes:** run them one at a time. Re-fetch nodes after a component edit, because instance child IDs change.
- **Figma connection drops:** it can disconnect mid-session. Re-load the tools with ToolSearch and keep going. The node IDs above stay stable.
- **Costs:** in the original, costs are plain numbers capped at 1.8e308. Only currency balances and Molt payouts are big numbers. The Luau port does the same.
- **Display:** show HUD numbers with `EN.short(x)` (K, M, B, T, Qa, Qi, ... then scientific notation, then layer notation).

---

## 7. Icons (2026-10-07)

The final UI icons are in `birb-icons/final/*.png` (98 UI icons) and `birb-icons/final/fish/*.png` (all 426 fish, named by fish id), 256px, transparent, with a uniform ink outline. The companion icons (sparrow, seagull, dove, redpanda) and fishing icons (moneta, rod, bait, aquarium) come from `fishing_sheet.png` and `birb-icons/companions_sheet.png` (Figma AI, gpt-image model) cut by `cut_companions.py`. The rest come from the user-approved sheet (`birb-icons/approved_sheet.png`) and were QA'd one by one on both dark and light backgrounds. `final/manifest.json` lists every icon and anything in the game data still missing one (currently nothing for fish, rods and baits). Gear sets come in visible tiers: 23 rods (`rod_<id>`, bamboo stick up to divine), hooks wood to diamond plus ancient/cursed, lures basic to legend, `tank_1`..`tank_5` drawn at growing size (cut with `!` so size is kept), 12 baits plus 13 golden `shiny_bait_*`. **Header rule (user): no icon in window headers, the title alone is centred. Everything on buttons (icon + label) is centred on the face; hero titles and subtitles are centred.** **Colour rule (user): each window uses its hero icon's colours as a multi-colour gradient (header, hero art, main button, active tab, lit buy button) with a white-top / dark-bottom shade layer on top; can't-afford buttons stay grey and BUY ALL stays blue.** **Rule from the user: anything that upgrades must look visibly better at each step, and size tiers (tanks) must grow.** New sheets: 4x4 grid on black from Figma AI (gpt-image model, see `sheets/`), cut with `python3 birb-icons/cut_grid.py <sheet> 4 4 names...`, checked with `qa.py`; fish prompts are built from the data by `fish_prompts.py` and cut by `fish_cut.py`. Use these for every new window instead of the older Figma `icon/*` set. They are placed in the Mine shop (`57:7`) by uploading the PNG as an image fill on the cloned `ico/*` rectangles (FIT). The older windows still use the old Figma `icon/*` set.

The Blender source scene (`birb-icons/*.py` and `peckwood_icons.blend`) is set up for later 3D icon ports, but nothing is exported yet. See `birb-icons/README.md` for the style rules and the export plan.
