# Ideas: the most insane-looking game on Roblox

**Goal:** keep the Vampire Survivors look (dark pixel-art stages, flat readable sprites, screen-filling weapons) and make it better in every way with procedural EditableImage algorithms. It should run at endgame crowd sizes.

| File | What it is |
|---|---|
| `ALGORITHMS_CORE.md` | **100 pure algorithms.** The maths each effect is built from (the same kind of list as the artifact) |
| `EDITABLEIMAGE_ALGORITHMS.md` | **1000 ideas.** Uses of the algorithms across weapons, enemies, HUD, map and more. About 150 are algorithms; the rest are applications |
| `PICKS.md` | Best-of lists: the top 40 overall, the top 100 from the 1000, the top 10 to build first, and the top algorithms |
| `AAA_ROADMAP.md` | **The Cursed Survivors plan**: 6 sprints with pass checks, what runs in parallel, risks and what to do right now |

Already built, so left out of these lists: the 89 effects in PixelCore/PixelSims (artifact `L2VLi2c41hTdvKf3LNYQa9`) and the 15 modules in `../pixelfx/`.
Research behind the picks: `../research/vs-fx/` (weapons, enemies, pickups, UI, stages, hierarchy and QA).

## Rules for "better but still VS"
1. **Gameplay numbers stay 1:1.** Effects never change hitboxes or timings the player relies on.
2. **Readability first:** player, then threats, then pickups, then projectiles, then the map. Every effect has to fit that order (`../research/vs-fx/hierarchy_qa.md`).
3. **Pixel-art discipline:** integer pixels, stage palettes (snap with `PaletteDither`), 1 px dark outlines, light from the top-left.
4. **Every effect has a frame budget:** a tier (60/30/15/8 fps) and a cost cap, enforced by the frame budget manager.
5. **There is always a Classic toggle** for the flat original look.
