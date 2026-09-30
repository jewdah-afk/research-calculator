# Stud City Incremental: HTML rough draft

Stud City Incremental, playable, built on the real Upgrade Land engine (Andy175, galaxy.click/play/873). It includes the latest Red update (red v1.3).
Open `index.html` in a browser. No build step and no server needed.

This draft doubles as the **build reference for the Roblox version**:
- `docs/REFERENCE.md` covers every system with exact numbers and Roblox equivalents.
- `docs/LUA_PORT.md` covers the math port.
- The in-game **FX LAB** plays and documents every effect, sound, haptic and UI motion, and exports them all as JSON.

## What is in it

- **The whole game, same math.**
  - All 722 Upgrade Land nodes (697 upgrades, 15 rebuild portals, 10 info signs) and all 63 currencies, run by a port of its engine.
  - `tools/parity-test.js` proves bit-for-bit parity with the original.
  - The data is byte-identical to the live game (checked 2026-09-30). Yellow and Blue plates are listed as coming soon.
- **World.** An isometric LEGO archipelago. Every baseplate is a themed island.
  - Studded floors with baked conveyor belts.
  - Brick machines that grow with level and turn gold at max, with lit windows at night.
  - Portals with spinning spirals, and 50 kinds of themed props (turbines, windmills, fountains, minecarts, lava pools, palms, stalls, obelisks and more).
  - Sun shadows that swing with the clock.
  - Shallows, caustics and foam on the sea.
- **Life.**
  - Wandering minifigs, and a builder who runs to what you buy.
  - Automation drones carrying bricks.
  - Boat, whale, gulls, balloon, and a plane towing a banner.
  - Jumping fish, buoys, a duck family.
  - A lighthouse and a waterfall.
  - Fireflies and theme particles.
- **Weather and time.**
  - A day and night cycle with a colour grade.
  - Clear, rain with a rainbow after, storms with lightning, dawn fog, rare night snow, gusting wind.
- **First impression (the wow layer).**
  - A first-play intro: dive through the clouds, watch the city build itself tile by tile, the builder parachutes in and the HUD slams into place. Replay it from Settings.
  - Every new plot assembles from 25 falling tiles, then its machines pop up.
  - The city grows through Village, Town, City and Metropolis, each with a one-time celebration: a STUD CITY hillside sign that gains a letter per plot, a downtown skyline with a live billboard and searchlights, and the Stud Express train looping the city.
  - Golden-hour god rays over a painted sunset sea, aurora on the night water, light reflections, tappable shooting stars, a brick sea serpent, milestone takeovers from 1K to a googol, and bloom on Ultra.
  - Photo mode TOUR flies over every plot you own.
- **Effects.** 39 catalogued effects under an attention budget (hero, support, ambient), including:
  - hit-stop, letterbox, zoom punch and camera shake on hero moments
  - flash limits
  - Full, Reduced and Minimal modes
- **Walk mode.**
  - Your own minifig. WASD, joystick or tap to move; sprint and jump.
  - Locked plots are walls that tell you what they need.
  - Proximity prompts: hold E to keep buying.
  - Footsteps change with the surface, and you can wear trails.
- **Meta (cosmetic only).**
  - 32 badges.
  - 8 hidden golden code bricks, plus 5 secret codes and a launch code.
  - A wardrobe of hats, outfits, trails and boat paint.
  - A next goal guide.
  - A stats panel with a chart.
- **HUD.**
  - Brick-letter title screen.
  - Ticker counters.
  - Machine cards with a live next-press preview, hold-to-buy, and a DATA tab with the raw formulas.
  - Minimap.
  - Photo mode with a time slider, filters, tilt-shift and snapshot.
  - Settings for quality, UI size, reduce flashing and five volume buses.
  - Phone portrait and landscape layouts.
- **Sound.** Synthesized: adaptive generative music, per-theme ambience, weather audio, spatial effects and haptics. 75 catalogued sounds and 14 haptics.
- **Offline gain** is capped at 3:00, or 5:00 with the Offline Pass toggle.

## Dev bar

| Button | What it does |
| --- | --- |
| MAX NEXT PLOT | Maxes every machine on the next unfinished plot (endless towers stop at the last payable level). 52 presses build all 39 plots |
| SIM TO NEXT PLOT | The bot plays at warp speed until a new plot is built, then reports the play time |
| SPEED / BOT | x1 to x100 game speed; the bot plays for you |
| FX LAB | Every effect, sound, haptic and UI motion: play, read the spec and Roblox recipe, export JSON |
| TIMELINE | Your play time per plot next to the bot benchmark |
| WEATHER | Auto, clear, rain, storm, fog, snow |
| TIME +6H / AWAY 1H / NAMES | Day cycle skip, offline cap test, Stud City or Upgrade Land names |

## Controls

| Action | Mouse and keyboard | Touch |
| --- | --- | --- |
| Pan / zoom / turn | Drag or WASD, wheel, Q and E | Drag, pinch, twist |
| Open a machine | Click | Tap |
| Buy / max / buy mode / buy all | B, M, 1 to 4, Space (or hold BUY) | Card buttons, hold BUY |
| Walk mode | V, then WASD, Shift, Space, hold E | WALK, joystick, JUMP, action button |
| Photo mode / FX Lab / help | P, L, ? | PHOTO button |
| Skip the intro | Esc | SKIP |
| Close | Esc | X |

## Tests and tools

```
NODE_PATH=$(npm root -g) node tools/parity-test.js path/to/upgtree/index.html   # math parity
NODE_PATH=$(npm root -g) node tools/smoke.js shots/      # core flow + screenshots
NODE_PATH=$(npm root -g) node tools/smoke2.js shots/     # v2 systems + screenshots
NODE_PATH=$(npm root -g) node tools/wow.js shots/ [phone] # intro, tour, replay
NODE_PATH=$(npm root -g) node tools/wow-city.js shots/   # tiers, train, sign, downtown
NODE_PATH=$(npm root -g) node tools/wow-sky.js shots/    # sky and sea spectacle, sound ids
node tools/balance.js 16 --write-benchmark               # bot timeline
```

## Known limits

- **The bot stalls.** It builds 14 plots, reaching Cookie Cove at 3h41m of play. Past that, use real play or MAX NEXT PLOT.
- **Fragments hit the number limit on purpose.** The Finale is built to fill them past 1.7e308, which unlocks the World Two reset.
- **No license.** The upgtree repository has no license file. Get Andy175's go-ahead before shipping anything built on this data.
