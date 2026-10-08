# Peckwood: next chat prompt (paste everything below the line)

---

You're continuing **Peckwood**, a Roblox remake of the incremental game Birb. Read this whole prompt first, then `~/Downloads/rc-main/HANDOUT.md` section 0. The owner is very picky about visual quality: they catch every hairline, clipped edge, off-centre glyph and drifting button. **Check everything zoomed in and show a screenshot with every visual change.** Keep replies short and plain.

## Where everything is
- **Repo:** `~/Downloads/rc-main` (git, GitHub `jewdah-afk/research-calculator`). The newest work (eggs replace popcorn + upgrade icons) is on branch **`claude/egg-mining-icons`**, not merged into `main` yet: `git fetch origin claude/egg-mining-icons && git checkout claude/egg-mining-icons` (or merge it into `main` first if the owner says so). Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Roblox game (Rojo):** `rc-main/roblox`.
  - `src/client/IslandView.luau` **(new)**: the whole island is drawn on the client.
    - **Ground:** EditableMesh "bands" with real 10-sided studs on every grass tile, built centre-out.
    - **Props:** brick Models in LEGO units, snapped to the stud grid by footprint parity (`DEFS` table: oak, bigoak, pine, bush, rock, lantern, arch, cart, bench, fence, windmill + sails).
    - **Scenery:** water and waterfall, clouds, far islands, fireflies.
    - **Day cycle:** 24 real min per day (1 min = 1 game hour, from server time), keyframes `KF` driving Lighting, Atmosphere and ColorCorrection, with lanterns lit at night.
    - **`IslandView.play()`:** the unlock build-in (bands rise, props drop with dust, camera swoop).
  - `src/shared/MapData.luau`: Park tiles (0 void, 1 grass, 2 path, 3 water), `M.H` hill heights (`M.height(i,j)`), `M.objects` props in game px (1 tile = 16 px = 4 studs; LEGO stud pitch = 8 px), `M.flowers`.
  - `src/client/Controller.luau`: movement and collision come from MapData (not physics). `PROP_COLL` holds per-kind collider radius and height, the hill is a wall, and water/void are blocked.
  - `src/client/Main.client.luau`: kernels and the camera. The camera opens at `ZOOM_ALL` framing the whole island, centred left of the drawer, with smooth wheel zoom; the focus slides to the bird below `ZOOM_FOLLOW`. `IslandView.camCF` overrides the camera when set.
    - QA hooks on PlayerGui attributes: `PeckwoodBuild` (replay build-in), `PeckwoodHour` (freeze sky hour), `PeckwoodCam` (Vector3 camera position).
  - `src/server/Island.luau`: now only an empty `Island` folder plus the `toWorld`/`tileCenter` helpers. `Main.server.luau` uses them for kernel spawns (it skips hill tiles).
  - UI: `src/client/UI/Kit.luau`, `Window.luau`, `Spec.luau`, `Windows.luau`, `Hud.luau` (details in HANDOUT §0).
    - `Kit.button` is the 3D key: the lip sits only under the face, and the whole cap (ink outline included) sinks when pressed.
    - `Kit.shake` is a smooth RenderStepped shake around a fixed HOME position. Spamming restarts it and never drifts. `Kit.nope` and the wallet wiggle use it.
    - `Window.morph`: tab switches inside a group crossfade the art colours, the pill glides, and the hero icon pops. It raises the window's holder ZIndex.
    - Window outline: one thin 6px ink stroke. The baked coloured side rim and the tab-bar highlight line are covered with patches copied from the art (not black).
    - Hero subtitle: an outlined RichText line, values in the theme accent, • separators, auto-fit.
  - Shared: `Defs.luau` (unlock order `Defs.ISLANDS`), `EternityNum.luau`, `Icons.luau` (icon asset IDs), `FigmaArt.luau`, `Models.luau` (`S = 4`).
- **Icons:** `rc-main/birb-icons/final/*.png` (256px, uniform 6px ink ring). Old art is kept in `final_old/`. Rod bobbers are in `bobbers/` and applied by `swap_bobbers.py`.
  - New icons are made with Figma MCP `generate_image` (model `gpt-image-2.5-sunburst`, planKey `team::1657975936717760073`, 2048²). Ask for a 4x4 grid on pure black, "glossy chunky mobile-game icons (Brawl Stars / Clash Royale), vinyl-toy, three cel bands, one specular highlight, thin rim light, thick even near-black outline", plus "simple bold shapes, no glow/sparkles/particles" (the owner doesn't want them to look AI-made).
  - Cut with `python birb-icons/cut_grid.py <sheet> 4 4 names...`.
  - Upload with Roblox Studio MCP `upload_image` from `python -m http.server 8799` in `birb-icons/final` (add `?v=N` to force a re-upload), then update `Icons.luau`. New uploads can show blank for up to about an hour while moderation clears them.
- **Approved Park concept:** `rc-main/concepts/park.html` (artifact https://claude.ai/artifact/Ff6NEweqn7jyw8po4oXAqG). The owner said "PERFECT". Every future island follows that look.

## Workflow (every change)
1. In `rc-main/roblox` run `python -m http.server 8778 --bind 127.0.0.1` (it may already be running). After edits run `python tools/gen_manifest.py`.
2. Studio MCP: use `list_roblox_studios` and pick the one named `birb(test)` (placeId 104948155633094). Only run **one** Studio window (RAM is limited).
   - **Stop Play**, run the `tools/sync.luau` snippet with `execute_luau` in **Edit**, then **Start Play**.
3. Test from Client `execute_luau`:
   - `Remotes.Action:FireServer("dev","maxed"|"regular")`
   - `PlayerGui:SetAttribute("PeckwoodOpen","<window id>")`
   - The QA rig `PeckwoodQA = zoom` / `PeckwoodQAY = scroll` pins a window for zoomed screenshots (`screen_capture`).
   - The island hooks listed above.
   - The game camera has a narrow FOV (11°), so for wide island shots use `PeckwoodCam = Vector3.new(260,300,520)`.
4. Finish with `rojo build -o Peckwood.rbxl`, copy it to `~/OneDrive/Desktop/` and commit. Remind the owner to save or publish birb(test) in Studio.

## Hard-won technical facts
- **EditableMesh on the client:** the budget is a FIXED reservation per mesh, about 8 meshes total, regardless of size. Keep `em` alive (destroying it blanks the MeshPart). So use EditableMesh only for big merged ground chunks (≤19.5k tris / 58k verts each). Use plain Parts for props.
- **Triangle winding:** `em:AddTriangle(a,b,c)` with a,b,c counter-clockwise seen from outside is the visible front face.
- Vertex colours come from `AddColor` + `SetFaceColors`, with MeshPart Color white.
- `execute_luau` runs in a separate module environment, so `require`-ing IslandView there gives a different instance. Use the attribute hooks instead.
- Speed in Studio play: about 170 fps average, worst frame 22 ms.

## Owner's rules (settled, don't re-ask)
- Hero-quality UI. No clipping, no hairlines, no square corners, icons fully inside their slots. Buttons never drift or move when spammed.
- Windows: one thin clean black outline. **No coloured rim, no glow, no chunky outline.** A small rounded drop shadow.
- Buttons are live 3D keys (`Kit.button`). No crown on rebirb buttons. Header titles centred (no icon).
- Grouping: one window per group with tabs (Park: Popcorn/Molt, Garden: Seeds/Sparrow/Evolve, Fishing: Rods/Bait/Index/Aquarium/Seagull, Forest: Nest/Red Panda, Mine, Desert: Golden/Dave, Expedition: Parrot/Quests/Altar, Echo, Profile).
- Sound: short dry keycap clicks, played once per action. Motion: short, springy, 60fps, never a constant pulse on idle UI. Respect reduced motion.
- Big numbers always go through EternityNum. Gameplay math is 1:1 with Birb.
- Icons: 3D/glossy new-set style only, not overly AI-looking. The **owner LOVES the current icons**: don't redraw art they didn't ask about.
  - Rods: wings or misaligned reels on the divine rod were rejected. It's now a clean white/gold rod.
- Map: LEGO studded look, "top of the line". Every prop lines up with the studs. Toned natural palette. Studs only on grass tops.
- Camera: 2.5D iso, level and square-on to the island. The whole island is visible by default; zoom in and out is allowed.
- Always show screenshots. Say when it's a good time to `/compact`.
- **Eggs replace popcorn** (2026-10-08): only player-facing text and art changed; internal ids, save keys and math stay `popcorn`/`goldenPopcorn`. Golden popcorn = golden eggs.
- **Upgrade-row icons** are the CURRENT in-game icon + a painted badge in the lower-right, merged into one silhouette with one shared ink ring (`birb-icons/compose_upgrades.py` → `final/up_*.png`). Badges: green arrow = value, blue plus = cap, yellow bolt = speed, orange × = multiplier, red/yellow burst = power, teal loop = regen (`final/badge_*.png`). The owner REJECTED: hand-drawn Figma vector badges, pixel/blocky badges, tiles/circles behind badges, repainted subjects (AI look), old approved-sheet bases, the magnet-with-eggs, a bolt drawn on the wing, stacked crates. Change only what is asked; when the owner says "it was perfect before", go back to that exact version.

## Right now: no Studio access, Figma only
The owner can't open Roblox Studio for now. **Do everything visually in Figma** (file `SQOJ2gzGt12vFMGGlNRWBE`, page "UI v2" `7:7`; load the figma-use skill first). Don't touch the Roblox code until Studio is back, except to read it for data. The Studio workflow above is for later.

**World reference:** the owner's live 3D "Peckwood World Guide" artifact: https://claude.ai/artifact/Ux19BGfq7Jq4De8RCBYiwL (read it with the Artifact tool, `action: read`). It is built from `World.luau` / `IslandData` and shows the custom builds: the Park with waterfalls, Forest (falling leaves), Desert (drifting sand), Echo Field (rising sparkles), Mine (sparks), the old Bridge lane, the coast with seagulls, the windmill, LEGO brick terrain (studded grass plates, earth/rock cliff courses, paths one plate lower, sand-bed ponds), highlands with snow on top, a living sea (reef depths, foam, fish, sharks, whale, night jellyfish), the 24-min day cycle, and the sea terraforming into one landmass as areas unlock. Treat it as the source of truth for how the map looks. To get it into Figma, screenshot its views (Map view, each area, day/night, unlock steps) with the pre-installed Playwright/Chromium and upload them with `upload_assets`.

## Next tasks (in order)
1. **Gap audit (read-only).** Walk `birb-data/SYSTEMS.md`, `CORE_FORMULAS.md` and `upgrades.json` against what already has a screen in Figma (UI v2 board `8:7`, square-top atlas `117:7`) and what `roblox/src/server/Game.luau` runs. Write a built / simplified / missing checklist into HANDOUT §0. Gaps already spotted:
   - **Desert research tree (`d_*`):** 143 one-off unlocks; only ~10 used. Needs a tree screen.
   - **Echo field archivist tree** (R/E/A/V/F nodes: Nearby Response, Duet, Tuning, mushroom collectors, Flock Memory, Golden Ascension…).
   - **Nest:** cultivation (tree boxes), riverside, carpentry, forest tree tiers.
   - **Mine:** giants.
   - **Expedition:** equipment (beak/armor/aura), the 47 artifacts with infusion, floor progression/boss screens.
   - **Companions:** Seagull Frenzy, Sparrow Resonance/Mitosis states, Dave XP.
   - **Quests/Sacrifice:** the 19-quest main list and all 18 sacrifice tiers.
   - **Meta:** leaderboards, settings, offline-earnings popup (if Birb has one), unlock/new-island toasts.
2. **Design every missing screen in Figma.** Duplicate the real square-top window frames (`117:*`) and UI v2 parts (header, tabs, hero, rows, buttons, progress bars); never redraw. Use the real numbers from `birb-data` in the copy. Use existing icons from `birb-icons/final/` (and the `up_*` upgrade icons); new icons only via the icon pipeline and only when nothing fits. Add a spec card per screen like the existing ones (states, motion). Show each screen zoomed.
3. **Map board in Figma.** One board per area (Park, Garden, Castle, Bridge, Forest, Mine, Desert, Expedition, Echo Field) from the World Guide: hero shot, day and night, how it joins its neighbours, the unlock moment (sea terraforming), and where the HUD/drawer sit over it. Plus a whole-world map view in unlock order (`Defs.ISLANDS`). Annotate props and effects so it can be rebuilt in Studio later.
4. **Visual hierarchy QA (in Figma).** On full HUD + window mockups over the map:
   - **HUD reading order:** island banner → big egg counter → drawer → wallet chips → nav tiles; wallet chips must not out-shout the main counter.
   - **Window reading order:** title → hero → tabs → row title → growth line → description → level bar → buy button, stepping down the same way in all windows.
   - **Icons:** same optical size and centred in every slot; badges readable at 1x.
   - **Buttons:** BUY > BUY ALL > MAXED > can't-afford distinguishable at a glance.
   - **Contrast and colour:** readable text on every theme; no neighbouring chips or bookmarks the same colour.
   - **Map:** the bird, eggs and interactive props read above the decor, day and night.
   Deliver before/after boards per area and let the owner pick.
5. **Leftovers in Figma:** Rebirb (Dave) still shows golden popcorn and Resonance (Sparrow) shows popcorn. When Studio is back: upload eggs + `up_*` icons, map them in `Icons.luau`/`Spec.luau`, re-export `FigmaArt.luau`, and build the gameplay from task 1 server-side 1:1.
