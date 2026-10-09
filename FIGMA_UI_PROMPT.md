# Peckwood: Figma UI parity chat (paste everything below the line into a new chat)

---

You are designing the **Peckwood** game UI in **Figma**, on the owner's PC (Figma MCP connected; Roblox Studio MCP available but not needed for this job). This is a design-only job: high-quality Figma frames, no Roblox code.

## Goal
Every screen of Birb (birbplay.com) gets a matching Peckwood screen in Figma: **same layout, same information and the same flow as Birb's UI** (the HTML parity build reproduces it), drawn in **our existing high-quality Figma UI style**, not Birb's art. The owner's words: "build it the same way as theirs, but with our UI style in Figma, the squared HUD / UI, high f***ing quality designs like we have it."

## Where things are
1. Repo `~/Downloads/rc-main` (GitHub jewdah-afk/research-calculator).
   - **HTML parity build** (the layout + flow reference): branch `claude/exciting-mccarthy-5em6b3`, folder `playtest/`. Read `playtest/NEXT.md`, `playtest/README.md` (phase table) and `playtest/DIFFERENCES.md`. Every window lives in `playtest/js/main.js` and the system files beside it. Open `playtest/index.html` in the built-in browser (or serve the folder) and screenshot each window as the layout reference. Parity with Birb's numbers is 80461/80461.
   - Read the game repo's `HANDOUT.md` section 0, part "How the UI matches Figma", and the gap audit (which windows exist in Figma, which only exist in game).
2. **Figma file (edit access):** https://www.figma.com/design/SQOJ2gzGt12vFMGGlNRWBE/Peckwood-UI?node-id=0-1
   - That link opens the **UI v2 page** (node `0:1`). Work there.
   - **UI v2 page contents:** our current windows (Eggs/Molt, Seeds, Golden, Echo, Mine, Nest, Evolve, Sparrow, Seagull, Dave, Red Panda, Rods, Baits, Fish Index, Aquarium, Parrot, Quests, Sacrifice, Profile, Robux shop v3 `130:7` / `132:7`). **This is the style to match exactly**: frames, rims, button faces, type, colours, row layout, spec cards.
   - HUD frame `8:271`; icon atlas `117:7`; egg icons `icon/egg`, `icon/egg_golden`; egg shop icons `145:7`.
   - Use the Figma plugin skills (`/figma-use` before any `use_figma`). Figma AI images: team key `team::1657975936717760073`.

## Rules (owner)
- **Squared** HUD and windows, the UI v2 look. Never copy Birb's art; copy only its layout, sections, data and flow.
- Icons are **glossy, painted 3D icons** (Blender-rendered or Figma AI painted, with one crisp black outline). Flat or vector icons are rejected. Reuse the existing icon set; only make new icons where a slot has none.
- Eggs replace popcorn everywhere (text and icons). Golden popcorn is now golden eggs, echo popcorn is echo eggs.
- Zero clipping: text must fit at the longest real value (use the big-number formats from the game, e.g. `1.84SpSpgDCe`).
- Every window gets a **spec card** next to it (sizes, colours, states, motion notes) like the existing ones.
- Show the owner a Figma screenshot after each window or group of windows, and ask before redesigning anything that already exists in UI v2.

## Order
1. Inventory: list every Birb window / panel / popup / HUD element from the parity build, mark each **exists in UI v2**, **exists but differs from parity**, or **missing**. Show the owner the list first.
2. HUD at parity (currency bar, area banner, goal bar, side menu, toasts), squared.
3. Missing windows, highest gameplay value first (the gap audit names trees / twigs, full mine with ore HP and areas, expedition floors / gear / forge, archivist, riverside, night mode, totem, mythic sacrifice).
4. Windows that exist but differ from parity: update layout and data rows to parity, keeping the style.
5. Popups and small UI (confirm dialogs, rewards, offline earnings, level-up, settings, teleport list).

## Keep the handout current
After each group, add a short section to `HANDOUT.md` (game repo, branch `claude/peckwood-isle`): which Figma frames were made or changed (node ids), what is still missing. Commit and push.
