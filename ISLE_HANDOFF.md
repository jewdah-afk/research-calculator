# Peckwood Isle handoff (paste this into a new local Claude Code chat)

You are on the owner's PC with Roblox Studio connected (Studio MCP). The place open in Studio is `Peckwood.rbxl` (published as **birb(test)**, placeId 104948155633094). Read `HANDOUT.md` section 0 for how the project is built and synced.

## Goal
The game map must be the World Guide's **Peckwood Isle** world (https://claude.ai/artifact/Ux19BGfq7Jq4De8RCBYiwL, default theme "Peckwood Isle", seed 1), built in the same LEGO look the Park already has in Studio: studded grass, blocky trees, lanterns, dirt paths, deep blue sea. Owner's words: the guide is "exactly how we want our terrain generation", "x10 better" than the current place.

## What is already done (branch `claude/peckwood-isle`, pushed)
- Branch = newest gameplay (`claude/exciting-mccarthy-5em6b3`: eggs as main currency, new-outline icons) merged with `shop-polish-map-tutorial` (land joins, highlands, `client/Ocean.luau` sea/reef/sea life, terraform unlocks, World Guide source).
- `src/shared/World.luau`: `World.LAYOUT = "isle"` (set to `"grid"` to get the old 3x3 grid back).
  - Each handmade area moves to its Isle spot (`IsleData.off`). The Park stays at its old coords.
  - The generated land between areas comes from `src/shared/IsleData.luau`: per area a `region:<id>` join (tiles, heights, top/side colours, trees/rocks/bushes) that rises out of the sea, outward from its area, when that area unlocks.
  - Grid bridges, grid joins and grid highlands are off in this layout (`World.bridges` is empty).
- `IsleData.luau` was exported from the guide's own `buildWorld()` by `tools/isle_export.js` (needs the guide's DATA block as `data.json` next to it).
- `client/Controller.luau`: "Go to" uses plain A* across the landmass when there are no bridges.
- `server/Main.server.luau`: Isle land counts as its area's zone (`isl.area`), so desert drops work on Desert land.
- `client/IslandView.luau`: Isle regions terraform outward from their area right after the area rises.
- Checked outside Studio only: every changed file compiles (luau-compile), and `World.luau` run under Lune loads all 9 areas + 9 regions (4,861 generated tiles, 468 props) with no overlaps; its tile map matches the guide's layout. **Nothing has been run in Studio yet.**

## Do this first
1. `git fetch origin && git checkout claude/peckwood-isle` in the local repo.
2. Data JSON changed between branches, so rebuild the place rather than only syncing scripts: `rojo build roblox/default.project.json -o roblox/Peckwood.rbxl`, open it in Studio (or sync scripts with `tools/sync.luau` over `python -m http.server 8778 --bind 127.0.0.1` in `roblox/`, and check Data matches).
3. Play. Use the dev bar: **REGULAR** (Park only), **MAXED** (every area open = the whole island), **NEXT ISLAND** (one unlock, to watch the terraform animation).
4. Screenshot the whole island zoomed out on MAXED and compare it with the guide (Map view, Peckwood Isle). Show the owner.

## Check / likely fixes
- **Frame rate** with the whole island open (much more land than the grid). IslandView culls at 4 Hz; check chunk/tri counts.
- **Output errors** on start and on MAXED (World, IslandView, Ocean, Controller).
- **Go to** on long trips: `Controller.findPath` caps at 9000 A* steps and may stop partway; raise the cap or route via area centres if needed.
- **Unlock animation** (NEXT ISLAND): the area rises, then its region grows outward with spray; camera framing.
- **Spawn / camera / bird walking** on the moved areas, hills (h up to 6), snow peaks, ponds (code 3 = water with sand bed).
- **Ocean**: reef/foam should hug the new coastline; the far islets (echo NE, small ones SW/E) sit in the sea.
- **Guide features to compare** after the map works: day cycle (24 game minutes), lanterns/fireflies at night, windmill, falling leaves (Forest), drifting sand (Desert), Echo sparkles, Mine sparks, waterfalls off Bridge/Park, seagulls, cloud shadows, fish/sharks/whale/jellyfish. Some exist already; list what is missing and ask the owner before building.

## Rules
- Follow `HANDOUT.md` and `CLAUDE.md`. Gameplay math stays 1:1 with the original Birb.
- Commit to `claude/peckwood-isle`, push, and keep the owner in the loop with screenshots.
- Icons are parked: 30 icons have the new thin outline on branch `claude/icon-outline-redo` (not merged into this branch); the other 938 wait for a Weave subscription or the free Gemini route. Don't redo icons now.
