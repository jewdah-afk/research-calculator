# Cursed Survivors: VFX target renders

Captured from the owner's **Survivors Hierarchy Codex** artifact (https://claude.ai/artifact/CV1paj6LVyx2Yxe3rK8wde). It is the end-goal look for the game's effects. Each section pairs a Studio screenshot ("Now", in `now_studio/`) with a live 480×270 "Target" render (in `renders/`). `manifest.json` has the label for every shot. `sheet_*.png` are labelled contact sheets.

## Rules (from the codex)
- **Palette:** the dark green Hollow Wood floor. Each colour has one meaning:
  - danger red is only for enemy shots, telegraphs and the 30:00 timer;
  - XP blue is only for gems;
  - gold is only for money;
  - bone-white is for UI focus;
  - lantern gold is only for the logo and the light.
- **Lighting:** the lantern is the only real light: eight cel-banded, dithered rings reaching about 84 px. Everything outside it stays cold.
- **Tiers and brightness bands:** bands run from B0 (darkest) to B7 (brightest), and each tier may only use certain bands.
  - **Hero:** bone core at B5–B7, inside a protected 2 px dark ring.
  - **Weapons:** dithered at B2–B5. They never use red, blue, gold or amber, and they thin out while an enemy shot is in flight.
  - **Enemies:** B2–B4, with ember eyes, rim light on the side facing the hero, and a "dark tide" for distant crowds.
  - **Pickups:** gems merge so drops never flood the screen, and rest at B3–B4. Coins are the only gold objects in the world.
  - **Bosses:** a big silhouette. Telegraphs are capped at B6, and the HP bar sits on its own plate.
  - **Reaper at 30:00:** a drain wave takes the world down to the lowest bands, and only the lantern pool keeps its colour. The Reaper is bone-white with a void hood, ember eyes and a staff with a red tip.
  - **UI/HUD:** every element sits on its own dark plate. The XP bar is at the top, and the timer pulses only at 30:00.
  - **Ceremonies** (level-up, chest, death, transitions): the full band range is allowed only while the ceremony plays. No hard cuts.
