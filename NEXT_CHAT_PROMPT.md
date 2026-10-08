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

## Next tasks (in order)
1. **Add the rest of Birb's gameplay, 1:1.** The math library is verified (`birb-data/`), but the Roblox server (`roblox/src/server/Game.luau`) only runs part of it. Start with a gap audit: walk `birb-data/SYSTEMS.md`, `CORE_FORMULAS.md` and `upgrades.json` section by section, grep `Game.luau`/`Defs.luau`, and write a checklist (built / simplified / missing) into HANDOUT §0. Gaps already spotted:
   - **Desert research tree (`d_*`):** 143 one-off unlocks in `upgrades.json`; only ~10 are referenced in the game. Needs the effects wired and a tree screen.
   - **Echo field archivist tree** (R/E/A/V/F nodes: Nearby Response, Duet, Tuning, mushroom collectors, Flock Memory, Golden Ascension…), SYSTEMS.md "Echo field".
   - **Nest:** cultivation (tree boxes), riverside, carpentry (soft-cap), forest tree tiers.
   - **Mine:** giants (HP and rewards), crow damage/speed curve check.
   - **Expedition:** equipment (beak/armor/aura) and the 47 artifacts with infusion; real floor progression and kill rate (now simplified); per-enemy behaviour.
   - **Companions:** Seagull Frenzy (Migration unlock), Sparrow Resonance/Mitosis and Dave XP from golden pickups need checking against the data.
   - **Quests/Sacrifice:** the 19-quest main list and all 18 sacrifice tiers (only 3 shown).
   - **Persistence:** confirm DataStore saves, offline progress (if Birb has it) and leaderboards (`EN.lbencode`).
   - Unverified numbers already listed in HANDOUT §0 open issue 6 (seeds 3/s, fishing cast 4s × rod speed, expedition rates).
   Build each system server-side from the ported formulas, add its UI by duplicating the real Figma frames (never redraw), test with the dev saves (REGULAR / MAXED / NEXT ISLAND), and check numbers against the original functions like §3 of the handout did.
2. **Ship eggs + the upgrade icons in game** (they exist only in Figma and `birb-icons/final/` right now; the live build still shows popcorn).
   - Upload with Studio MCP `upload_image` (serve `birb-icons/final` on :8799): `egg`, `egg_golden`, the `shop_*` egg set, and every `up_*.png` (24 files).
   - `Icons.luau`: replace the `popcorn`, `golden` and `shop_*` ids; add `up_*` ids. `Spec.luau`: point each upgrade row at its `up_*` icon (row → icon map is in HANDOUT §0 "Upgrade icons" and in `compose_upgrades.py` comments; Figma slots are named `ico/<name>`).
   - Re-export the window art from the square-top atlas `117:7` into `FigmaArt.luau` (the baked renders still say POPCORN), wait for moderation, then QA every window at 1.6–2.6x on MAXED and REGULAR.
3. **Visual hierarchy QA pass** (screenshot everything, zoomed). Work window by window and on the HUD, fix as you go:
   - **HUD reading order:** island banner → main currency (big egg counter) → window drawer → wallet chips → nav tiles. Check the eye lands in that order; the wallet chips must not out-shout the main counter (size, saturation, glow). Main counter bottom-left must stay the biggest number on screen.
   - **Window reading order:** title → hero (icon, title, subtitle, button) → tab bar → row title → growth line (`a >>> b`) → description → level bar → buy button. Check font sizes/weights step down consistently across all 20 windows; descriptions must be clearly secondary; numbers in growth lines use the theme accent.
   - **Icons:** every row icon the same optical size and centred in its slot (badged icons read slightly smaller: compare against plain ones), nothing clipped by the slot, badges visible at 1x.
   - **Buttons:** BUY (lit theme colour) > BUY ALL (blue) > MAXED (gold) > can't-afford (grey) must be distinguishable at a glance; pressed state sinks, never drifts.
   - **Colour/contrast:** text on every theme passes a quick contrast check; no two adjacent wallet chips or drawer bookmarks share a colour.
   - **Map:** the bird, eggs on the field and interactive props must read above the decor (HANDOUT §5 "map hierarchy"); check day and night.
   - Deliver a short before/after board (artifact or screenshots) per area, then implement the owner's picks.
4. **Other islands** (unchanged plan): concept board for all 8 islands in the Park LEGO style, then build each via IslandView with its own MapData, unlock build-in and "Go to …" travel.
5. **Leftovers:** Rebirb (Dave) still shows golden popcorn and Resonance (Sparrow) shows popcorn in Figma; `Config.GROUP_ID`; 426 fish icons; delete Figma temp atlases `83:7` and `117:7` only after art is re-exported; smooth-60fps pass.
