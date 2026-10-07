# Peckwood: next chat prompt (paste everything below the line)

---

You're continuing **Peckwood**, a Roblox remake of the incremental game Birb. Read `~/Downloads/rc-main/HANDOUT.md` section 0 first. Then read this whole prompt before touching anything. The owner is very picky about visual quality and catches every hairline, clipped edge and overflow. **QA everything zoomed in before you say something is done** (the QA rig is described below).

## Where everything is
- **Repo:** `~/Downloads/rc-main` (git, branch `main`; GitHub `jewdah-afk/research-calculator`). Last commit `3520702`.
- **Roblox game (Rojo):** `rc-main/roblox`.
  - `src/client/UI/Kit.luau`: building blocks. `Kit.button` is the live 3D key button (face, darker lip, gloss, stripes, press sinks). `Kit.sfx` is the keycap click sounds, `Kit.reduced()` is the reduced-motion check, and `Kit.iconId` handles icon lookup with fish/rod/bait fallbacks.
  - `src/client/UI/Window.luau`: one window. The Figma render is clipped to the rounded window shape, with a black outline drawn from 1px outside the window. Also: rows, the raised progress track (the old baked track is patched out), the open/tab/slide transitions, `Window.celebrate` (upgrade flash), and the idle animations.
  - `src/client/UI/Spec.luau`: per-window theme colours and copy. `Spec.GROUPS` holds the 9 feature groups that drive the left menu tiles and each window's tabs. `trim` cuts an empty band out of a render (Profile uses it).
  - `src/client/UI/Windows.luau`: each window's binder (rows plus update from server state). `amount()` formats big numbers safely with EternityNum.
  - `src/client/UI/Hud.luau`: banner, wallet, objective bar, AUTO, dev buttons (REGULAR / MAXED / NEXT ISLAND), left hero tiles, and the sliding/collapsing drawer with its right-edge tab. It also has the **QA rig**.
  - `src/server/Game.luau`: all game logic. Main.server.luau handles players and remotes. Island.luau builds the map. The map data is in `src/shared/MapData.luau` and the models in `src/shared/Models.luau`.
  - Shared: `Defs.luau` (every upgrade, plus the island unlock order `Defs.ISLANDS`), `EternityNum.luau`, `FigmaArt.luau` (uploaded window renders and button IDs), `FigmaArtSize.luau`, `Icons.luau` (icon asset IDs).
  - Art: `roblox/assets/figma/` (window renders, `btn_orig/` for the original button faces). `roblox/tools/lip.py` exists but the Figma button images are no longer used.
  - Icons: `rc-main/birb-icons/final/*.png`. `birb-icons/dehalo.py` removes baked dark auras.
- **Map-only copy for a friend:** `roblox/mapcopy.project.json` builds `~/OneDrive/Desktop/Peckwood_MapOnly.rbxl`.
- **Old 3D HTML prototype (reference only, not the game):** `~/Birb`.
- **Figma file:** `SQOJ2gzGt12vFMGGlNRWBE`, page "UI v2", board `8:7`.

## Workflow (do this every time)
1. In `rc-main/roblox`, run `python -m http.server 8778 --bind 127.0.0.1` (it may already be running). Serve icons with `python -m http.server 8799` in `birb-icons/final`.
2. After editing, run `python tools/gen_manifest.py`. Then **stop Play**, run the `tools/sync.luau` snippet with `execute_luau` in **Edit**, and **start Play**. The Studio place is `birb(test)` (placeId 104948155633094). Use the `list_roblox_studios` id whose name contains `birb(test)`. Only run **one** Studio window: RAM is limited.
3. Test from Client `execute_luau`:
   - `Remotes.Action:FireServer("dev","maxed")` (or `"regular"`).
   - `PlayerGui:SetAttribute("PeckwoodOpen","<window id>")`.
   - **QA rig:** `PeckwoodQA = <zoom>` (0 = off) and `PeckwoodQAY = <scroll px>`. This hides the rest of the HUD and pins the window top-left. Then `screen_capture`.
4. **QA every window** on MAXED **and** REGULAR, top and bottom, at about 1.6–2.6x zoom. The window ids are: popcorn molt seeds sparrow evolve rods baits index aquarium seagull nest redpanda mine golden dave parrot quests sacrifice echo profile. Fix anything that clips, overflows, has hairlines, square corners or empty cards. Show the owner the screenshots.
5. Finish:
   - `rojo build -o Peckwood.rbxl`, then copy it to `~/OneDrive/Desktop/` and open it.
   - Commit with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
   - Update HANDOUT.md section 0.
6. Never use SendMessage to a running workflow agent. Don't work on other projects unless asked.

## Owner's rules (settled, don't re-ask)
- **Hero-quality UI.** No clipping anywhere. Every highlight has to be perfect. Icons always sit fully inside their slot.
- **Windows:** one clean black outline. **No coloured rim, no glow around windows.** The owner rejected both. The drop shadow is small and rounded, with 24px corners that match the HUD.
- **Buttons:** live 3D keys from `Kit.button`. No Figma button images and no thin lines at the bottom of buttons.
- **No crown icon on rebirb buttons.**
- **Grouping:** related things share one window as tabs, and the left menu shows one tile per group (`Spec.GROUPS`):
  - Park: Popcorn, Molt
  - Garden: Seeds, Sparrow, Evolve
  - Fishing: Rods, Bait, Index, Aquarium, Seagull
  - Forest: Nest, Red Panda
  - Mine
  - Desert: Golden, Dave
  - Expedition: Parrot, Quests, Altar
  - Echo
  - Profile
- **Left tiles:** themed hero cards with the icon inside, a sunburst behind it and a name strip. Hover lifts, press squashes, and the selected tile gets a white rim and glow.
- **Drawer:**
  - Switching groups slides it in from the right; switching tabs inside a group fades.
  - The › button collapses it to a right-edge tab.
  - Only one window is ever visible, and the island doesn't move when the drawer does.
- **Sound:** short dry keycap click (`Kit.sfx`). Opening and closing get different pitches, and hover makes a very quiet tick on desktop only. Play each sound once per action.
- **Motion:** short and springy, never a constant pulse on idle UI. Reduced motion is respected.
- **Numbers:** everything big goes through EternityNum (`EN`). Never show "inf", "NaN" or 300-digit strings. Gameplay math is 1:1 with Birb (see HANDOUT).
- **Icons:** 3D/glossy only. Flat and vector icons are rejected.
- **Screenshots:** show the owner a screenshot with every visual change.

## Task 1: thin line under the tab bar (still there)
The owner's latest screenshot is the Dave window. Between the tab bar (Golden | Dave) and the hero card, a thin grey horizontal band/line still shows. It's baked into the Figma window render, the bar art plus a strip below it. The owner sees it as an ugly leftover line.
- Remove it on every window. The fix is probably the same patch method as the progress track in `Window.luau` (`api.art`, copy a clean strip of the render over it), or a live tab-bar background that covers the band.
- QA the strip between the tabs and the hero card on every window at about 2.5x zoom.

## Task 2: hero subtitles must look good
The line under each hero title (for example "LV 100 · golden x2.00 · desert forager") is small, plain grey text. Every window has one; it's `api.hero.sub` in `Window.luau`, and the text is set in each binder in `Windows.luau`.
- Make it a clean, readable, **outlined** line that matches the title style. Use the bold rounded Fredoka font with a dark outline.
- One option: split the parts into small pills or chips separated by dots, using the theme colour for the values.
- Keep it centred, fitting within the card width (auto-shrink), on all 20 windows.

## Task 3: 60fps-smooth animation
Make every animation buttery at 60fps:
- the icon idle bob/breathe and hero icon
- the tile hover, press and select states
- the drawer slide
- the row cascade
- buy celebrations
- the Molt, Evolve and other reset flashes and toasts
- the currency pops

Specifically:
- Use TweenService or RenderStepped with dt and easing. No `task.wait` steps (for example `Kit.nope` and the wallet wiggle use stepped waits, so convert them).
- Don't set per-frame Size on many objects; prefer UIScale and Position.
- Make the reset moments (Molt, Evolve, rebirbs) feel premium.
- Measure it: check the frame rate in Play with `Stats`/`RenderStepped` dt while opening windows and buying, and report the numbers.

## Task 4: the maps (ideas in an HTML artifact first, then Roblox)
Right now every island past the Park reuses the Park map. The Desert is only a field toggle with golden drops.
- **Step A (saves usage):** build an HTML/CSS artifact that mocks each island's 3D area as a fast concept board. Show the layout, palette, landmarks and where the gameplay spots sit. Get the owner's pick or edits before building in Roblox.
  - The unlock order is in `Defs.ISLANDS`: Park → Garden (sunflowers) → Castle (Evolve monster) → Bridge (fishing) → Forest (nest/twigs, red panda) → Mine (crow, ore) → Desert (golden, Dave) → Expedition (parrot floors) → Echo Field.
  - Match the existing style: voxel/stud floating islands with a ragged underside, toned-down natural palette (owner said "way too vibrant" before), LEGO studs only on grass tops, and readable visual hierarchy (pickups and halos above the floor). For reference, look at `src/server/Island.luau` and the old `~/Birb/src/three/View3D.js`.
- **Step B:** build each island in Roblox, extending `Island.luau` with a builder per island.
  - When an island unlocks, it should **generate nicely in front of the player**: a staged build-in animation (tiles rising or popping in, scenery dropping in with a bounce, dust and sparkles, camera framing it), then **show the player** it with a short camera pan and a toast.
  - It has to perform well: build over several frames, keep the part count reasonable, and skip per-frame Part.Size changes.
- Each island's windows should travel the player there (the hero buttons "Go to …").

## Other open items (lower priority, from HANDOUT)
- `Config.GROUP_ID` is still 0. AUTO only works in Studio until the owner gives the group id.
- Upload the 426 fish icons from `birb-icons/final/fish/` and add them to `Icons.luau`. Until then, fish rows show the generic fish icon.
- Delete the temporary Figma atlas `83:7`.
- Unverified numbers are listed in HANDOUT section 0.
