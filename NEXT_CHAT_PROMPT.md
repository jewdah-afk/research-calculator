# Peckwood: next chat prompt (paste everything below the line)

---

You're continuing **Peckwood**, a Roblox remake of the incremental game Birb. Read this whole prompt first, then `~/Downloads/rc-main/HANDOUT.md` section 0. The owner is very picky about visual quality: they catch every hairline, clipped edge, off-centre glyph and drifting button. **Check everything zoomed in and show a screenshot with every visual change.** Keep replies short and plain.

## Where everything is
- **Repo:** `~/Downloads/rc-main` (git, branch `main`, GitHub `jewdah-afk/research-calculator`). Last commit `bb19ded`. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
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

## Next tasks (in order)
1. **Other islands.** Unlock order (`Defs.ISLANDS`): Park → Garden (sunflowers) → Castle (Evolve monster) → Bridge (fishing) → Forest (nest/twigs, red panda) → Mine (crow, ore) → Desert (golden, Dave) → Expedition (parrot floors) → Echo Field.
   - **Step A:** one cheap HTML concept board (Three.js r128 from cdnjs, like `concepts/park.html`) showing all 8 islands in the Park's LEGO style, for the owner's pick or edits.
   - **Step B:** build each island in Roblox by generalising IslandView. Give each island its own tile map and props (`MapData` per island), placed beside the Park and linked by brick bridges.
     - When an island unlocks (watch `state.island` increase in Hud/Main), call the build-in for THAT island: bands rise, props drop with dust, camera swoop, then a toast via `Hud.toast`.
     - Hook the build-in to the real unlock (it currently runs only from the `PeckwoodBuild` QA hook).
     - Each window's "Go to …" hero button should move the bird there.
   - Mind the EditableMesh budget: share or merge ground meshes across islands, or build far islands' ground from Parts or larger tiles.
2. Park polish the owner may raise: the golden-hour background below the island goes beige (tune `KF` fog and atmosphere colours), and the underside reads dark from the play angle.
3. HANDOUT open items: the window check at 1.6–2.6x zoom on MAXED and REGULAR for all 20 windows; Task 3 smooth-60fps pass (tiles, drawer, buy celebrations, Molt/Evolve reset moments); `Config.GROUP_ID` (AUTO needs the owner's group id); the 426 fish icons to upload; delete the temporary Figma atlas `83:7`.
