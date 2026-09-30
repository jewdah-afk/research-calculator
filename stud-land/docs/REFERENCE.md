# Stud City Incremental: build reference

This HTML draft is the spec for the Roblox game. Every number below comes from the code, so if the two ever disagree, the code wins.

**How to read it**
- Play it, then open **FX LAB** in the dev bar. It lists every effect, UI motion, sound and haptic. Each one has its trigger, attention tier, timings and a Roblox recipe, and a **PLAY** button.
- **FX LAB > EXPORT** downloads everything as one JSON file (`stud-city-catalog.json`) for an AI or a tool to read.
- On any machine card, the **DATA (FOR THE PORT)** tab shows the exact Upgrade Land formulas for that machine.
- Game math and the Luau port are covered in `docs/LUA_PORT.md`. This file covers everything around the math.

---

## 1. Architecture

| Layer | File | Job |
| --- | --- | --- |
| Data | `js/ul-data.js` | Upgrade Land tree: 722 nodes (697 upgrades, 15 rebuild portals, 10 info signs), 63 currencies, 118 decorations |
| Math | `js/engine.js` | Tick, buy, automation, resets, offline, save. Bit-identical to the original (`tools/parity-test.js`) |
| Plots | `js/plots.js` | Groups nodes into 5x5 plots, build rules, progression order, level caps |
| Bot | `js/bot.js` | Greedy autoplayer for SIM and balance |
| Renderer core | `js/world.js` | Projection, camera, plates, machines, sea, sun and shadows, sprite atlas, particles, signs, hooks |
| Effects | `js/fx.js` | The effects catalog (27 entries) and UI motion list, drones, fireworks, confetti, lightning, income pops |
| Props | `js/props.js` | 50 themed prop types placed on free cells |
| Weather and life | `js/env.js` | Weather director, fog, snow, storm tint, balloon, plane banner, fish, buoys, ducks |
| Walk mode | `js/walk.js` | Avatar, collision, proximity prompt, footsteps, trails |
| Meta | `js/meta.js` | Badges, code bricks, secret codes, wardrobe, next goal guide, stats history |
| HUD | `js/hud.js` | Counters, stack, zone bar, machine card, panels, settings |
| Extras | `js/ui-extras.js` | Minimap, photo mode, colour grade, title screen, weather button |
| FX Lab | `js/lab.js` | The living style guide and JSON export |
| Sound | `js/audio.js` | Synth engine: buses, reverb, music, catalog, haptics |
| Glue | `js/main.js` | Loop, input, dev bar, actions, save, offline, title flow |

**Rule:** nothing outside `engine.js` changes currencies or levels, except the explicit dev tools (MAX NEXT PLOT, SIM, BOT). Every other feature reads state and listens to engine events (`buy`, `reset`, `currency`).

**Renderer hooks.** Modules plug in with `WORLD.use(name, fn)` at these points, in this order each frame:

1. `update`
2. `underPlates`
3. `afterPlates`
4. `shadows`
5. `items`
6. `afterItems`
7. `sky`
8. `post`
9. `ui`

Separately, `grow` fires whenever a machine gains a brick. Named events use `WORLD.on` and `WORLD.emit`: `whale`, `autoQuality`.

In Roblox the same split becomes:
- **ModuleScripts:** Engine (shared), Plots, Effects (client), Props (server builds, client animates), Weather (server state, client visuals), Walk (character), Meta (server authority), HUD (client).

---

## 2. World space

- **Units.** One Upgrade Land tree cell is one world unit, and a plot is 5 x 5 units.
  - Plot key: `gx = floor((x + 2.5) / 5)`, `gy = floor((y + 2.5) / 5)`.
  - Plot origin: `x0 = gx * 5 - 2.5`.
- **Roblox scale.** Use **1 unit = 8 studs**:
  - a plot is a 40 x 40 stud island
  - a machine footprint is about 5 studs
  - the avatar is Humanoid sized
- **Heights.**
  - Plate top `TOP = 0.34`.
  - Plates are inset `INSET = 0.16` from the plot edge, which leaves a water channel between neighbours.
  - Slab sides run from -0.22 to `TOP`, with a seam at 35%.
- **Projection.** `phi = angle + 45deg`:

  ```
  sx = W/2 + ((x-cx) cos phi - (y-cy) sin phi) * K
  sy = H/2 + ((x-cx) sin phi + (y-cy) cos phi) * K * 0.5 - z * K * 0.82
  K  = 64 * zoom
  ```

  Depth for sorting is `(x-cx) sin phi + (y-cy) cos phi`. In Roblox the real 3D camera replaces all of this: use a fixed pitch of about 30 degrees over an orbiting yaw.
- **Camera.**
  - Zoom range 0.28 to 2.4.
  - Easing per second: angle 8/s, zoom 10/s, fly-to 4/s (exponential).
  - Q and E turn 90 degrees, and the slider turns freely.
  - A tap moves less than 10 px and lasts under 600 ms.
  - Pinch zooms and twists.
  - The default zoom fits one plot: `clamp(min(W, 1.5 H) / 560, 0.45, 1.25)`.
- **Bridges.**
  - Built neighbours get a plank bridge at the middle of their shared edge.
  - The Finale (3,0) and World Two Gate (5,0) are joined by a long stone causeway across the gap at x 17.5 to 22.5.

## 3. Plots, themes and props

There are 39 plots, plus Yellow and Blue shown as COMING SOON. The name, colour and theme for each are in `PLOT_INFO` (`js/plots.js`).

**Theme floors.** Each theme has a floor texture: base, alternate patches and machine pads, plus a decal:
- flowers, grid, hazard stripes, lightning bolts, confetti, shine, lanes
- cloud prints, leaves, runes, ore flecks, gems, lava cracks, checker
- stars, awning, canyon bands, bills, loops, shells, cookie chips, circus stripes

**Studs.**
- 4 studs per unit, drawn as translucent layers so they take the colour underneath.
- Conveyor belts are baked in as flat tiles between machines that are linked on the tree.
- Textures rebuild only when a machine unlocks.

**Props.** Each theme has a pool (`THEME_PROPS`). Every free cell gets one prop with 72% chance, placed by a seed from the plot key. The pools:

| Theme | Props |
| --- | --- |
| meadow | round and pine trees, bushes, flower beds, benches |
| lab | satellite dishes (sweeping), antenna towers (blinking), glowing beakers |
| factory | smoking chimneys, pipes, crates, barrels |
| energy | wind turbines (spinning), solar panels |
| studio | easels, spotlights, balloon bunches |
| gold | statue, trophy, fountain |
| gym | dumbbells, flags, cones |
| mill | windmills |
| sky | balloons, flags |
| grove | pines, stumps, mushrooms |
| sun | sunflowers (turning), beehives with bees |
| portal | glowing obelisks, crystals |
| mine | minecarts rolling on rails, lanterns |
| deep and forge | bubbling lava pools, anvils throwing sparks |
| finale | checkered flag, podium trophy |
| cosmos | telescope, floating crystals |
| market | striped stalls with fruit |
| canyon (Red update) | cacti, rock arch |
| bay, beach, lagoon | palms, umbrellas, sandcastles, spinning loop ring |
| cash | money bags, vault |
| cookie | giant cookie, milk |
| tent | circus tent |

Props cast shadows and block walking. Moving parts are drawn live, and the static parts are cached. In Roblox, build props as Models:
- Moving parts use a HingeConstraint with a motor, or CFrame tweens.
- Smoke, sparks and bubbles use ParticleEmitters.
- Glows use PointLights, enabled only at night.

**Signs.** Each built plot shows one headline:
- If a rebuild portal is unlocked there: `REBUILD +gain currency`.
- Otherwise, the currency this plot is first to produce: `+rate/s`.
- Otherwise, the amount of the plot's main cost currency.

The sign also has a level bar (levels against base max) and a red badge counting affordable machines.

Unbuilt plots next to built ones show a lock sign with the exact need, for example `Needs P05 on Golden Brick Hall`.

When signs overlap, the focused plot wins, then built plots, then whichever is nearest the screen centre. In Roblox: a BillboardGui per plot, with the overlap rule done in a client script.

## 4. Machines

- **Brick count** is `1 + min(3, floor(4 * (level / cap)^0.6))`, and 5 at max.
  - Brick height 0.14, footprint 0.6 (0.34 for half height nodes).
  - A new brick drops 1.2 units in 0.18 s, then squashes.
- **States:**
  - Blueprint hologram when not bought: translucent blue, bobbing, with a +.
  - Brick stack in the cost currency colour. The top trim shows the Upgrade Land border colour: green, orange, red or blue.
  - Gold top and studs at max, with a twinkle every few seconds.
- **Kinds** (by effect type), each with a small moving accent:

  | Kind | Accent |
  | --- | --- |
  | producer | chimney puffs in the produced currency colour |
  | multiplier | spinning gear |
  | automation | robot arm with a blinking light |
  | max level | waving flag on an antenna |
  | rebuild bonus | floating spinning star |
  | portal | stone arch, three spiral arms spinning 0.8 rad/s idle and 3 rad/s ready, motes falling inward, glow |
  | info | signpost with ? |

- **Arrows.** The best buy on the focused plot (cost as the smallest share of the wallet) gets a big yellow bouncing arrow. Other affordable machines on that plot get small green ones.
- **Night.** Lit windows appear on the machine faces, and the machines on the focused plot glow.

## 5. Light, time and colour

- **Day cycle.** 12 minutes by default; Settings offers 6, 12 or 24. It is freezable in photo mode.
  - Night factor is 0 from 7:30 to 16:30, 1 from 20:30 to 4:30, and ramps between.
- **Sea colour.**
  - Day: `#2aa9c9` to `#4fd0e0`. Night: `#0a2a48` to `#123d63`.
  - Mixed toward the sky colours at dawn (6:12) and dusk (18:36).
  - Star glints at night.
- **Sun and shadows.**
  - Azimuth follows the clock, and shadow length is `min(2.4, 0.55 / tan(elev * 1.2))`.
  - Alpha is 0.20 by day, 0.07 x night for the moon, and lower in rain.
  - In Roblox, `Lighting.ClockTime` does this for real: set `GlobalShadows` on, and use Future lighting on high-end devices.
- **Night tint and lights.** A navy overlay at 0.42 x night. Additive glow sprites (capped at 90) come from lamps, portals, lanterns, lava, crystals, the lighthouse, the boat, the avatar and the focused plot's machines. In Roblox: PointLight and SurfaceLight, `Brightness` scaled by a night value.
- **Colour grade** is a soft-light layer:
  - dawn `#ff9a5a` up to 45%
  - dusk `#ff6a8a` up to 50%
  - night `#3a4aff` at 28% x night

  In Roblox, tween ColorCorrection `TintColor` and `Saturation` by ClockTime.
- **Post effects:**
  - vignette: radial, 38% at the edges
  - tilt-shift: 3.5 px blur on the top and bottom 26%, masked. Ultra turns it on.
  - photo filters: warm, cool, vivid, noir

  In Roblox: DepthOfFieldEffect for tilt-shift, and a ColorCorrection preset for each filter.

## 6. Weather

The director lives in `js/env.js`.
- **Picking weather.** Clear lasts 3 to 7 minutes. After that it picks:
  - fog: 35% at dawn
  - snow: 12%, night only
  - rain: 27%
  - storm: 15%
  - otherwise clear again
- **Transitions** ramp over about 18 s.
- **Rain:** screen streaks scaled by density, darker sea and world, and a rainbow for 40 s after a daytime shower.
- **Storm:**
  - a tint at 34%
  - wind +0.8
  - lightning every 6 to 18 s: an 8 segment bolt, a flash limited to 2 per second, thunder delayed 0.3 to 1.8 s by distance
- **Fog:** 18 drifting soft banks at water height plus a whole-screen haze at 18%.
- **Snow:** screen flakes with sway and wind.
- **Wind** is slow drift plus gusts. It moves clouds, chimney smoke, embers and petals.

In Roblox:
- `Clouds.Cover` and `Density` tweens.
- `Atmosphere.Haze` and `Density` for fog.
- Rain and snow as ParticleEmitters on a part that follows the camera.
- Lightning as a Beam plus a `Lighting.Brightness` spike and a delayed thunder Sound.

## 7. Life around the islands

| Thing | Behaviour |
| --- | --- |
| Minifigs | 2 per built plot, up to 34; walk between free cells at 0.7 u/s, wait 1 to 5 s, some carry studs, some wear hats |
| Builder | Runs (2.4 u/s, or hops at 9 u/s when far) to whatever you buy and hammers it with sparks |
| Boat | Circles all built plots at 0.8 u/s with a V wake. Skins: red, pirate, gold |
| Whale | Every 150 to 300 s off an island edge; rises over 7 s and spouts studs. Tap it for the WHALE code |
| Birds | 5 gulls circling by day |
| Clouds | 7, drifting with the wind, casting soft shadows |
| Hot air balloon | Every 3 to 5 min, drifts across with the wind |
| Plane | Every 6 to 10 min by day, towing a STUD CITY INCREMENTAL banner |
| Fish | Jump every 4 to 11 s near the islands, splash rings at both ends |
| Buoys | 4 buoys, blinking lights |
| Ducks | A duck family paddles around Stud Square |
| Lighthouse | Its own islet off Stud Square. At night the beam sweeps 0.9 rad/s; tap it at night for the LIGHTHOUSE code |
| Waterfall | Pours off Brick Grove Falls on the side facing the camera |
| Fireflies | At night, 3 per plot on the first 15 plots |
| Ambience particles | About 3 per second per visible plot, by theme: embers, sparks, motes, twinkles, dust, petals, bubbles |

## 8. Effects and the attention budget

- **Tiers:**
  - HERO: one at a time.
  - SUPPORT: at most 3 starts per 250 ms.
  - AMBIENT: first to go.
- **Limits:**
  - Flashes: at most 2 per second, and never in Reduced mode, Minimal mode or with Reduce flashing on.
  - Particles: capped at 700.
  - Drones: capped at 14.
- **Effects setting:**
  - Full: 100% particles.
  - Reduced: 45% particles, no shake, no flash.
  - Minimal: no particles or ambience.

  Quality multiplies particles further: low 0.35, medium 0.7, high 1, ultra 1.25.
- **Hero techniques:**
  - letterbox bars (9% of height, 0.35 s)
  - camera fly-to and zoom punch (+5 to 6%)
  - hit-stop (80 to 90 ms at 4% speed)
  - shake (kick 0.6 to 0.8, decays to 2% per second)
  - screen flash
  - music stinger with ducking

The full list, with specs and Roblox recipes, is in **FX LAB > WORLD FX** and in the exported JSON.

| Effect | Tier | When |
| --- | --- | --- |
| buy | support | You buy levels |
| grow | support | A machine gains a brick |
| maxed | support | Max level reached |
| autoBuy | ambient | Automation bought something (drone) |
| reset | hero | Rebuild |
| plotBuilt | hero | New plot |
| maxPlot | support | Dev MAX NEXT PLOT |
| portalReady | ambient | A rebuild starts paying |
| newCurrency | support | First time a currency appears |
| codeFound | support | Golden brick collected |
| achievement | support | Badge |
| incomePop | ambient | Every 2.6 s, 4 nearest plots |
| fireworks | support | New plot at night |
| lightning | support | Storms |
| splash, confetti, shockwave | support | Building blocks for the others |

## 9. HUD and UI

**Design tokens.**
- Colours: ink `#1b1530`, paper `#fffaf0`, paper-2 `#f3ead8`, yellow `#ffd23f`, green `#39d98a`, blue `#4aa8ff`, red `#ff4d4d`, orange `#ff9a2e`, purple `#a56ae0`, muted `#6b6480`.
- Borders are 3 px ink, and corners are 10 to 16 px (square-ish, not pills).
- Shadows are hard, `0 4px 0` ink. Buttons press down 3 px and the shadow collapses.
- Fonts: **Luckiest Guy** for numbers, titles and buttons; **Fredoka** 600 to 700 for text. Minimum 13 px (use Roblox TextSize 26+ on phones).
- White title text gets an 8-direction ink outline (UIStroke 2 to 3 px in Roblox).

**Layout: desktop.**
- Top: the dev bar (not in the shipping game).
- Top left: the hero counter card (Studs, a ticker that eases 25% per frame and snaps on spend) with its rate pill, which bumps when the rate rises. Under it the stats stack (3 rows, MORE expands, the focused plot's currencies first).
- Top centre: the next goal guide, hidden while a machine card is open.
- Right column: tiles for REBUILD (ready count), PLOTS, BADGES (count), CODES (! when a secret is waiting) and SETTINGS.
- Right side, next to the tiles: the machine card.
- Bottom centre: the zone bar (plot tab, headline rate, level bar, buy mode X1/X5/X10/MAX, BUY ALL with count).
- Bottom left: minimap plus WALK and PHOTO.
- Bottom right: camera controls (turn, slider, zoom, home).
- Toasts sit above the zone bar.

**Layout: phone portrait.**
- The zone bar grows to two rows.
- Above it, from the bottom up: the guide, then a row with WALK/PHOTO on the left and the compact camera controls (turn and home) on the right, then toasts.
- The machine card becomes a bottom sheet.

**Layout: phone landscape.** The tiles become a 2 column grid and the minimap hides.

**Machine card.**
- Tabs: INFO and DATA.
- INFO:
  - the description
  - what it boosts
  - a live preview of the next press, measured by trying it: each affected rate or rebuild gain from before to after, as a percentage
  - a level bar and cost with what you have
  - BUY (hold to repeat: 380 ms, then 300 ms, speeding up to 55 ms) and MAX
- DATA: raw ids, requirements and formulas.
- Portals show the gain and what gets wiped, with HOLD TO REBUILD (700 ms).

**Panels:**
- REBUILD: every portal with GO TO and HOLD.
- PLOTS: progress, with GO or LOOK.
- BADGES: 26 badges.
- CODES: letter slots, redeem box, secrets with hints, wardrobe.
- STATS: a log chart of Studs and Studs/s, plus counters.
- SETTINGS: quality, tilt-shift, vignette, colour grade, UI size S/M/L/XL, reduce flashing, five volume sliders, effects mode, vibration, names, offline pass, day length, controls, hold to wipe (1.2 s).
- TIMELINE (dev).

**Title screen.**
- Brick letters drop in with a bounce, 70 ms apart.
- A loading bar and rotating tips.
- TAP TO PLAY unlocks audio. The camera then swoops from zoom 0.3 and -52 degrees into place.

**Roblox mapping.**
- One ScreenGui per region, with UICorner (10 to 16 px), UIStroke (3 px), and a shadow Frame offset 4 px.
- UIScale driven by the UI size setting.
- CanvasGroup for fading panels.
- ProximityPrompt styling copied from the walk mode prompt.

## 10. Walk mode

- **Enter** with V or the WALK button. You spawn on the focused plot, and zoom goes to at least 1.25.
- **Movement:**
  - Screen relative, with WASD, arrows or the joystick (46 px radius).
  - 3.4 u/s, sprint x1.6 with Shift.
  - Jump at 3.6 u/s with gravity 12.
  - Tap the ground to walk there.
  - The camera follows with 0.6 u of look-ahead.
- **Walkable** means built plots (inset) and bridges. Walking into an unbuilt plot bumps you with LOCKED and the exact reason (1.5 s cooldown).
- **Collision:**
  - Machines are squares (0.3 or 0.17), portals and props are circles, and holograms are walk-through.
  - Axis sliding lets you slide along walls.
- **Prompt.**
  - Shows for the nearest usable thing within 0.95 u: machine, portal, sign or code brick.
  - Key cap, action and subtitle (cost), bouncing gently.
  - E or the round action button uses it. Holding repeats buys, starting at 320 ms and speeding up to 80 ms.
  - Walking within 0.38 u of a code brick picks it up.
- **Footsteps.** Every 0.32 s, or 0.22 s when sprinting. The surface comes from the plot theme (grass, stone, metal, sand, and wood on bridges), with a dust puff and your trail cosmetic.
- **Roblox:**
  - Humanoid WalkSpeed about 27 (3.4 u x 8 studs); sprint about 43.
  - Invisible CanCollide walls around unbuilt plots.
  - ProximityPrompt per machine (MaxActivationDistance about 7.6 studs), using InputBegan and InputEnded for hold-to-repeat.

## 11. Meta (cosmetic only)

- **Badges:** 26, checked every second. Saves that already qualify on load get them silently. Maps to BadgeService.
- **Code bricks:** 8 golden bricks spell STUDCITY, one letter each on Stud Square, Blueprint Lab, Sticker Studio, Golden Brick Hall, Alpha Bonus Bay, Robo Works, Sky Tower and The Finale. A brick shows once its plot is built.
- **Codes:**

  | Code | How to find it | Reward |
  | --- | --- | --- |
  | STUDCITY | All 8 bricks | crown, stud trail, yellow outfit |
  | LIGHTHOUSE | Tap the lighthouse at night | pirate hat, pirate boat, night outfit |
  | WHALE | Tap the whale | bubble trail, green outfit |
  | REDCANYON | Build the Red plot | ember trail, red outfit, red cap |
  | NIGHTOWL | 5 minutes of night | wizard hat, sparkle trail, purple outfit |
  | BRICKS | Free launch code | pink outfit, golden boat |

  In Roblox, validate codes on the server with a RemoteFunction and store them in the DataStore profile.
- **Guide:** first a rebuild that at least doubles you, then the best buy on the focused plot, then anywhere, then the next plot to build with its need.

## 12. Sound and haptics

- **Buses:** master, music, sfx, ui and ambient, with a shared generated reverb. Music and ambience duck on hero moments.
- **Music:**
  - Generative, about 92 bpm, toy-like.
  - Major pentatonic by day, dorian by night.
  - Intensity follows buying and hero moments.
  - Stingers quantise to the beat.
- **Ambience** follows the focused plot theme and the weather.
- **Pitch ladder:** buys climb a semitone (1.0595) per quick buy, up to 14 steps, and reset after 0.9 s idle.
- **Spatial:** pan follows the effect's screen position.

Every sound and haptic is in FX LAB > SOUND and HAPTICS. Each entry has how it is synthesized and which Roblox asset and SoundGroup settings to use.

## 13. Performance rules

- **Sprite atlas.** A 2048 px atlas caches every static look (machines, holograms, props) while the camera is still. While turning or zooming, things draw live.
- **Culling:** plates, machines, links, bridges and props are culled off screen.
- **Level of detail by zoom (K):**
  - no studs under 40
  - no seams under 44
  - no belts flow under 40
  - no props under 18
- **Caps:** 700 particles, 90 glows, 14 drones. Ambience runs only on screen.
- **Caustics** render at one-third resolution every other frame.
- **Auto quality.** If frames average over 30 ms for 3 s, the canvas resolution drops half a step. After that the preset drops: ultra, high, medium, low.
- **Roblox:**
  - StreamingEnabled with plots as streaming units.
  - ParticleEmitter Rate caps by quality.
  - Lights off by distance.
  - Props as MeshParts with RenderFidelity Automatic.

## 14. Tools

| Command | What it checks |
| --- | --- |
| `node tools/parity-test.js <upgtree index.html>` | Engine matches Upgrade Land bit for bit |
| `node tools/smoke.js <dir>` | Core flow, dev bar, panels, phone, screenshots |
| `node tools/smoke2.js <dir>` | Walk, photo, FX Lab (plays all effects), codes, badges, weather, phone walk |
| `node tools/balance.js 16 --write-benchmark` | Bot timeline for the TIMELINE panel |
