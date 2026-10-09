# Peckwood map hierarchy (2026-10-09)

Owner: "B is what we're trying, but we want absolute hierarchy built." The look is **B, realistic cartoony**
(`roblox/docs/targets/look_B_realistic_cartoony.png`: Sea of Thieves / Fortnite / Kena, golden hour, painted
materials, dense wind-blown grass, swaying ambience). It replaces the cel / Pokemon X/Y look: **no ink outlines on
scenery** any more. This file is the single rule for where everything in the world lives and how much it is
allowed to shout. Code: `roblox/src/shared/WorldTree.luau`.

---

## 1. The visual hierarchy (what the eye finds, in order)

Every frame from the game camera must read in this order. Each tier is a bit quieter than the one above it in
**value contrast, saturation, detail and motion**.

| Tier | What | How it wins attention | How it stays quiet |
|---|---|---|---|
| 1 Focus | hen, eggs, companions (`Actors`) | the only ink outlines left, brightest whites, warm rim light, always moving (hop, bob) | — |
| 2 Interactables | gold bird, monster, nest tree, tank, portals, shop stall | a light of its own or a glint, clear silhouette, a cleared ring of ground around it | no outline; at most 1 per screen region |
| 3 Landmark | ONE hero per island (Park: lighthouse) | tallest silhouette, sits on the island's far edge or a corner so it frames the play area, never in the middle | darker values than tier 1-2, slow motion only (beam, sails) |
| 4 Structure | paths, fences, lamps, benches, bridges, piers (`Props`) | leads the eye: paths point at the egg yard and the landmark | mid values, low saturation browns / greys |
| 5 Dressing | trees, bushes, grass, flowers, rocks (`Foliage`, `Rocks`) | texture and life: sways, drifts | darkest + most varied greens, denser at the island edge than in the middle (natural vignette), never on the play path |
| 6 Ground | grass top, sand, pond, path paint (`Ground`) | the stage | flat-ish, two greens, no shadows cast by it |
| 7 Backdrop | cliff skirt, sea, far islets, clouds, sky (`Sea`, `Sky`) | depth | hazy (Atmosphere), desaturated, cooler; blurred by the tilt-shift DepthOfField |

**Composition rule per island (foreground / midground / background):**
- **Foreground** (bottom of the screen, nearest the camera): low dressing only (grass, flowers, small rocks, a
  fence rail), cut by the frame edge, slightly out of focus. Never tall enough to cover the hen.
- **Midground** (the play area): tiers 1, 2, 4 and the egg yard. Kept open; dressing hugs the edges.
- **Background** (top of the screen): the landmark, big trees and the cliff edge, then sea and far islets.
- The camera looks north (pitch 52), so **tall things go on the north half**, low things on the south half.
  IslandView's flower placement already keeps the strip just north of tall props clear; keep that rule.

**Value check (do this on every screenshot):** blur the screenshot or squint. The hen and the eggs must still be
the brightest, highest-contrast spots. If a flower bed, a lamp glow or the sea is brighter, push it down.

## 2. Outlines (changed with look B)

- Ink outline (Highlight, Occluded) **only on tier 1**: the egg field (`Main`, `outline(field, ...)`) and the hen
  (`Birds`). Scenery lost its outline (the `outline(IslandView.scenery, ...)` call is gone; the `Scenery` model no
  longer exists).
- The pond keeps its own dark-blue rim Highlight for now (it sits in `Ground`); drop it in the look-B material
  pass if it reads as cel.
- Highlight budget: 31 rendered at once. Tier 1 uses 2. Hover / interact highlights may use the rest.

## 3. The Explorer tree (absolute: nothing map-related lives anywhere else)

```
Workspace
  World                      (Folder, WorldTree.root())
    Sky                      Clouds, Far (horizon islets)                 tier 7
    Sea                      Ocean.luau builds straight into it:          tier 7
                               surface + painted layers, deep, Shelf, Life (fish, sharks, whale, jellies),
                               Waves, Skirt (cliff skirt along every coast), Splash
    Islands                  one Model per open area, culled by unparenting
      park                   the Park (IslandView.build)
      garden, castle, ...    unlocked islands (IslandView.buildIsland)
      region:<id> / joins    land joins between islands
        Ground               ground parts, water, waterfalls, ToonPath (painted path), ToonPond   tier 6
        Landmarks            lighthouse, cottage, keep, temple, pyramid, tower, greenhouse, ...   tier 3
        Interactables        goldbird, monster, nesttree, tank                                    tier 2
        Props                lantern, bench, fence, YardFence, pier, footbridge, rails, ...       tier 4
        Foliage              trees, bushes, Flowers, sunflowers, vines, cactus, mushrooms          tier 5
        Rocks                rock, ore, crystal, monolith, bones, log, twigs                      tier 5
        Life                 Butterflies (later: birds, critters)                                 tier 5
        FX                   Beacon (lighthouse light), island-local emitters and lights          tier 4
    Actors                   Birds (hen), BirdShadows, Eggs                                       tier 1
    Atmosphere               Ambience (wind / pollen / leaves anchor), Fireflies, Dust            -
    Vfx                      PeckwoodVfx, PeckwoodVfxParts (Vfx engine), dust / collect bursts    -
  Terrain                    walkable tops (LandTerrain), unchanged
  Island                     server's empty folder (kept so old waits resolve)
  Camera, characters
```

**Which layer a prop goes in** is `WorldTree.LAYER_OF` (every kind in MapData / IslandData is mapped; checked
2026-10-09, 0 unmapped). Builders never pick a folder by hand: `WorldTree.layerFor(island, kind)`.

## 4. Layer rules (`WorldTree.RULES`)

| Layer | Tier | Casts shadows | Sways in wind | Studs allowed (decision C) |
|---|---|---|---|---|
| Ground | 6 | no | no | no |
| Landmarks | 3 | yes | no | yes |
| Interactables | 2 | yes | no | yes |
| Props | 4 | yes | no | yes |
| Foliage | 5 | yes | **yes** | no |
| Rocks | 5 | yes | no | no |
| Life | 5 | no | no | no |
| FX | 4 | no | no | no |

Parts thinner than 0.6 studs never cast shadows (`WorldTree.SHADOW_MIN`).

**QA (Studio command bar), must print nothing:**
```lua
print(table.concat(require(game.ReplicatedStorage.Peckwood.WorldTree).audit(), "\n"))
```
It reports: anything loose in `workspace`, a missing top folder, a non-layer child in an island, a shadow in a
no-shadow layer, a thin part casting a shadow, and any prop kind with no layer.

## 5. Status

**Built (branch `claude/peckwood-isle`), checked outside Studio only:**
- `src/shared/WorldTree.luau`: the tree, layers, kind -> layer map, rules, `audit()`.
- `IslandView`: the Park is `World.Islands.park`; every Park prop, flower patch, fence, butterfly, path, pond,
  water and the lighthouse beacon go to their layer. Unlocked islands and joins are `World.Islands.<id>` with the
  same layers (one Model, culled by unparenting; the separate `Scenery` model is gone). Clouds + far islets ->
  `Sky`; fireflies + dust -> `Atmosphere`.
- `Ocean.build(WorldTree.get("Sea"))`: the sea builds straight into `World.Sea` (cleared and rebuilt in place).
- `Birds`, `BirdShadows`, `Eggs` -> `Actors`; `Ambience` anchor -> `Atmosphere`; Vfx roots, Main's dust and collect
  bursts -> `Vfx`. `EggHatch` finds the egg field in `Actors`.
- Checks run: every changed file compiles (luau-compile 0.740); `rojo build` OK; VFX smoke test
  (`tools/vfx/smoke.luau`) 0 problems; a WorldTree unit test under Lune (tree, idempotence, layers, mapping,
  audit catches shadow / unmapped kind / loose folder) all pass.
- `Portals.luau` is unused (removed from the game earlier) and still parents to `workspace`; if it comes back it
  goes in its island's `Interactables`.

**First Studio session (owner home), in order:**
1. Sync (`tools/manifest.json` regenerated, includes WorldTree), Play, run the audit above. Expect a list of
   ground parts on the non-Park islands that still cast shadows: fix in `buildIslandGround` (Ground rule).
2. Check that the Explorer matches section 3, unlock an island (dev bar NEXT ISLAND) and watch it mount under
   `Islands`, cull (fly away / back), destroy on REGULAR.
3. Screenshot the Park: the scenery outline is gone (intended, look B). Compare with the look B target.

**Next (the look-B pass on top of this tree):**
1. Park target redrawn from the real game camera (pitch 52, FOV 11) in look B + palette / material sheet.
2. Lighting "Golden" preset (warm sun, soft shadows ~0.2, EnvironmentDiffuse/Specular back up for painted PBR,
   Atmosphere haze, Bloom, SunRays) replacing the Toy preset.
3. Wind: one `Wind` module drives everything tagged by layer: Foliage sway (already in `ambientStep` via
   SWAY_KINDS -> switch to the Foliage layer), Terrain.Decoration grass on with `GrassLength`, leaves / pollen in
   Atmosphere, cloud shadows.
4. Materials: painted SurfaceAppearance on landmarks and props, realistic-cartoony terrain MaterialVariants.
5. Density pass per island following section 1 (edges dense, middle open).
