# Stud Incremental — Map Build Spec (rough draft)

This is a complete written spec of the Stud Incremental map, for building it in Roblox Studio. It comes with screenshots of a 3D block-out of the same map (in the `shots/` folder and in the PDF). The screenshots show where everything goes, and this text says how each thing should look. Zones are numbered in the order players unlock them.

## Map layout at a glance
- **Realm One** (left/west, grey baseplate): zones 1–10 arranged around Spawn Plaza.
- **Rebirth Portal** (zone 11): on a tan bridge over the north–south water channel. It's the only way into Realm Two.
- **The Glacier / Realm Two** (right/east, snow baseplate): zones 12–16.

| # | Zone | Realm | Footprint (studs) | Position X | Position Z | Unlock |
|---|---|---|---|---|---|---|
| 1 | Spawn Plaza | Realm One | 180×160 | 300–480 | 300–460 | Start (Stack 0) |
| 2 | Brick Forge | Realm One | 160×110 | 520–680 | 300–410 | Stack 1 |
| 3 | Weld Works | Realm One | 160×90 | 520–680 | 430–520 | Stack 2 |
| 4 | Rune Shop Row | Realm One | 660×130 | 40–700 | 40–170 | Beginner & Royal Stack 1 · Basic Stack 3 · Color Stack 6 · Nature Stack 9 |
| 5 | Noob Arena | Realm One | 230×200 | 40–270 | 200–400 | Stack 4 |
| 6 | Gem Lab | Realm One | 230×130 | 40–270 | 420–550 | Stack 5 (x2 pad and talent Gem button at Stack 6) |
| 7 | Cylinder Garden | Realm One | 180×100 | 300–480 | 490–590 | Stack 7 |
| 8 | Crate Merger | Realm One | 180×120 | 300–480 | 620–740 | Stack 8 |
| 9 | Ball Tower | Realm One | 160×120 | 520–680 | 560–680 | Stack 9 (Meteors at Stack 10) |
| 10 | Obby Gates | Realm One | 230×160 | 40–270 | 580–740 | C1 Stack 6 · C2 Stack 8 · C3 1e393 Studs · C4 1e96 Studs |
| 11 | Rebirth Portal | Bridge | 130×80 | 690–820 | 340–420 | Studs > 1e2283 (~7 h in) |
| 12 | Frost Rune Row | The Glacier | 340×120 | 830–1170 | 30–150 | Polychrome after Rebirth · Cryo Anchor 3 · Arctic Union 7 · Galactic Union 750 |
| 13 | Glass Well | The Glacier | 150×150 | 830–980 | 190–340 | After first Rebirth (Stack 10+ runs on Glass) |
| 14 | Anchor Works | The Glacier | 170×150 | 1000–1170 | 190–340 | Anchor 1–3 Stack 11 · 4–6 Stack 12 · 7–9 Stack 13 |
| 15 | Union Machine | The Glacier | 340×120 | 830–1170 | 430–550 | Talent Union unlock (Gems ≥ 5e43) |
| 16 | Publish Spire | The Glacier | 240×160 | 880–1120 | 590–750 | Publish 1 Lighting · 2 Foil pad · 3 Reflectance |

## Global build style
- **Scale:** 1 unit on the layout = 1 Roblox stud. Whole map ≈ 1200 × 780 studs. X runs west→east, Z runs north→south. Realm One: X 0–745. Water channel: X 745–800 (55 studs wide). The Glacier (Realm Two): X 800–1200.
- **Everything is bricks:** floors are studded baseplates. Each zone is a coloured plate 1.2 studs above the grey world baseplate, with a 1-stud curb in a darker shade of its colour.
- **Two looks:** ground and buildings are bright toy plastic (SmoothPlastic). Everything players interact with is a dark "machine" with Neon glow.
- **Stud trail:** oversized yellow studs lead from spawn to every zone in unlock order.
- **Locked zones:** a translucent brick wall (Transparency 0.5) with a padlock and "Stack X" text across the entrance.
- **Lighting:** Realm One is bright day (ClockTime 14, warm sun). The Glacier has a cool Ambient (#C9E6FF), light Atmosphere haze and falling snow.

## Machine style (every pad and generator)
- **Base:** dark slate #262E3D block with chamfered edges, ~20×14 studs, 3 studs tall, with a lighter top step (#2F384A).
- **Glow strips:** 2 Neon strips on the front of the base, in the currency's colour.
- **Pillars:** 2 dark pillars with a tall Neon panel on the front. *Core style* has angled caps leaning in over the centre (like the "Crystal Core" concept). *Stack style* has stepped blocks (like the "Stack" concept).
- **Centre:** an octagonal dark pedestal with a glowing ring, and a 3D version of the currency icon floating above it (slow spin, ±1 stud bob).
- **Icon billboard:** a BillboardGui above the machine with the currency icon, name, cost and reward.
- **Reset pads** (Stack, Obbies, Rebirth, Anchor, Union, Publish, Reflectance, Diamond Plate): red-and-black hazard ring around the base, plus a confirm pop-up listing what gets reset.

## Name key (in-game name ↔ code name)
| In-game name | Code name | Type | Where on the map |
|---|---|---|---|
| Studs | `Energy` | Currency | Spawn Plaza · Studs machine |
| Stack | `Tier` | System · reset | Spawn Plaza · Stack machine |
| Bricks | `Flame` | Currency | Brick Forge |
| Build Points | `Realm Points` | Currency | Brick Forge |
| Welds | `Power` | Currency | Weld Works |
| Runes | `Runes` | System | Rune Shop Row, Frost Rune Row |
| Tix | `Tickets` | Currency | Rune Shop Row (Beginner/Royal/Galactic cost) |
| Noobs | `Mobs` | System | Noob Arena |
| Oofs | `Flesh` | Currency | Noob Arena |
| Builder XP | `XP` | Currency | Noob Arena |
| Builder Level | `Level` | Currency | Noob Arena scoreboard |
| Loot Crates | `Loot` | Currency | Noob Arena chest |
| Gems | `Prisms` | Currency | Gem Lab |
| Cylinders | `Orbs` | Currency | Cylinder Garden |
| Crates | `Cubes (merger)` | System | Crate Merger |
| Tools | `Gears` | System | Crate Merger |
| Thrusters | `Accelerator` | System | Crate Merger |
| Balls | `Spheres` | Currency | Ball Tower |
| Meteors | `Hail` | Currency | Ball Tower (Stack 10) |
| Obbies | `Challenges` | System · reset | Obby Gates |
| Rebirth | `Ascension` | System · reset | Rebirth Portal |
| The Glacier | `Realm Two (Arctic)` | System | Right half of the map |
| Glass | `Droplets` | Currency | Glass Well |
| Glacier | `Water` | Currency | Glass Well |
| Diamond Plate | `Ice` | Currency · reset | Glass Well |
| Frost Points | `Arctic Points` | Currency | Frost Rune Row (Cryo cost) |
| Anchor | `Freeze` | System · reset | Anchor Works |
| Force Fields | `Icicles` | Currency | Anchor Works |
| Fog | `Haze` | Currency | Anchor Works |
| Union | `Chromatize` | System · reset | Union Machine |
| Neon | `Chromium` | Currency | Union Machine |
| Foil | `Chroma` | Currency | Union Machine / Publish Spire |
| Publish | `Chromify` | System · reset | Publish Spire |
| Lighting | `Light` | Currency | Publish Spire |
| Reflectance | `Reflection` | Currency · reset | Publish Spire |
| Sparkles | `Shine` | Currency | Publish Spire |

## Reset pads: what each one wipes
| Pad | Where | Resets to 0 | Keeps |
|---|---|---|---|
| Stack | Spawn Plaza | Studs, Bricks, Welds, Oofs (and Noob level), Cylinders, Balls (and Ball levels), Crates/merger level, Tools, Thrusters, plus all their upgrades. From Stack 11 up it also wipes Glass, Glacier, Diamond Plate, Neon, Force Fields and all Anchors. | Build Points, Gems, Runes, Tix, talents |
| Obbies (entering) | Obby Gates | Everything a Stack does, plus talents (except 16 kept ones), Build Points and their upgrades, Gems, and Stack back to 0. | Runes, Tix, finished Obbies |
| Rebirth | Rebirth Portal | Everything a Stack does, talents, Build Points, almost all Runes (all but the ultra-rare ones), Gems, Stack, Builder XP and Level, Obby completions. One-time. | Ultra-rare Runes, Tix; unlocks The Glacier |
| Diamond Plate | Glass Well | Glass and Glacier. | Everything else |
| Anchor 1–9 | Anchor Works | Everything a Stack does, plus Gems, Glass, Glacier, Diamond Plate, Glass upgrades, talents (except kept) and Neon. | Stack level |
| Union | Union Machine | Talents (except kept), Gems, Neon, Foil. | Stack, Glass side |
| Publish | Publish Spire | Talents, Gems, Neon, Foil, Lighting, Reflectance, Sparkles and their upgrades. | Stack, Union level |
| Reflectance | Publish Spire | Neon, Foil, Lighting, and talents (except kept). | Gems, Publish level |

## Zones in detail

### 1. Spawn Plaza
*Screenshot: `shots/zone-01-spawn-plaza.png`*

- **Realm:** Realm One
- **Unlock:** Start (Stack 0)
- **Footprint:** 180×160 studs · X 300–480, Z 300–460
- **Floor colour:** #d6322b
- **Systems here:** Studs (`Energy`), Stack (`Tier`)

**Purpose:** Where every player spawns. It holds the two machines everyone uses from second one: Studs and Stack.

**How it looks:** A big red studded plaza. In the middle is a white round spawn pad with a red Neon disc. In the north-west corner sits the grey Studs machine: a chunky grey stud-cube floats between two white-glowing pillars. In the south-east corner is the largest machine on the map, the Stack machine: three coral bricks stacked like a wedding cake (dark red at the bottom, peach at the top with studs), with stepped dark pillars and red-orange glow, copied straight from the Stack concept. A giant red 2×4 brick monument stands in the north-east corner as a landmark.

**Build list:**
- Floor: red plate 180×160, darker red curb with 4 exits.
- Spawn pad: white cylinder 30 studs across, 1 stud tall, red Neon inner disc.
- Studs machine (Core style, white/grey glow) 20×14 base. Centre: grey rounded cube with one big stud on top, like the Studs icon.
- Stack machine (Stack style, coral glow). Scale it 1.5× so it reads as the main goal. Its billboard shows 'Stack N → N+1' and a progress bar.
- Monument: red 2×4 brick scaled to 30×24×15 studs with 8 cylinder studs on top.
- 4 lamp posts at the corners (dark poles, yellow 2×2 glowing heads).

**Feel & effects:** Busy and bright. Sparkles float up from the spawn pad, and the Stack machine hums and pulses when you can afford it.

**⚠ Reset pad — Stack:** wipes Studs, Bricks, Welds, Oofs (and Noob level), Cylinders, Balls (and Ball levels), Crates/merger level, Tools, Thrusters, plus all their upgrades. From Stack 11 up it also wipes Glass, Glacier, Diamond Plate, Neon, Force Fields and all Anchors. Keeps: Build Points, Gems, Runes, Tix, talents.

### 2. Brick Forge
*Screenshot: `shots/zone-02-brick-forge.png`*

- **Realm:** Realm One
- **Unlock:** Stack 1
- **Footprint:** 160×110 studs · X 520–680, Z 300–410
- **Floor colour:** #f07b1d
- **Systems here:** Bricks (`Flame`), Build Points (`Realm Points`)

**Purpose:** Bricks and Build Points. It's right next to spawn, so it's the first new area players walk to.

**How it looks:** A chunky brown brick forge with an orange-tile roof and a chimney with Neon flames. In front of it stand two machines. The Bricks machine has a glossy red 2×4 brick spinning in the middle with red glow strips. The Build Points machine has a green blueprint board with bar-chart bars, and green glow.

**Build list:**
- Floor: orange plate 160×110.
- Forge: brown box 70×40×50, open front arch glowing orange, chimney 15×40×15 with 3 stacked Neon flame cones.
- Bricks machine (Stack style, red glow #FF3B30).
- Build Points machine (Core style, green glow #34C759).
- Props: anvil, coal barrels, a rack of hammers.

**Feel & effects:** Warm fire crackle and ember particles from the chimney.

### 3. Weld Works
*Screenshot: `shots/zone-03-weld-works.png`*

- **Realm:** Realm One
- **Unlock:** Stack 2
- **Footprint:** 160×90 studs · X 520–680, Z 430–520
- **Floor colour:** #f5c518
- **Systems here:** Welds (`Power`)

**Purpose:** The Welds machine, directly south of the forge because Bricks feed Welds.

**How it looks:** A yellow industrial plate with hazard-stripe edges. A big hydraulic press slams down on an anvil block, throwing sparks. Next to it, the Welds machine holds a floating steel L-bracket (the Welds icon) between blue-glowing pillars.

**Build list:**
- Floor: yellow plate 160×90 with black/yellow hazard edges.
- Press: 2 grey pillars, crossbeam, yellow piston that tweens down every 2 s (camera shake + spark burst on impact).
- Welds machine (Stack style, steel-blue glow #6FA8DC). Centre: brushed-metal L-bracket.
- Props: steel beam stacks, a welding cart with a torch that sparks.

**Feel & effects:** Heavy thud and welding sparks.

### 4. Rune Shop Row
*Screenshot: `shots/zone-04-rune-shop-row.png`*

- **Realm:** Realm One
- **Unlock:** Beginner & Royal Stack 1 · Basic Stack 3 · Color Stack 6 · Nature Stack 9
- **Footprint:** 660×130 studs · X 40–700, Z 40–170
- **Floor colour:** #7a4bc4
- **Systems here:** Runes (`Runes`), Tix (`Tickets`), Bricks (`Flame`), Build Points (`Realm Points`), Balls (`Spheres`)

**Purpose:** The 5 Realm One rune packs, all on one purple street. They're ordered by unlock, going west from spawn.

**How it looks:** A long purple avenue with 5 rune machines in a row. Each one has a big faceted rune crystal floating and spinning in the middle: a chunky cut gem with a glowing pink square-in-a-square symbol in its face, like the Runes icon. The crystal is tinted for its pack (Beginner lime, Royal gold, Basic grey, Color pink, Nature green) while the glowing symbol stays hot pink. Purple arches reading 'RUNES' stand at both ends, and purple Neon lamp posts run along the back.

**Build list:**
- Floor: purple plate 660×130.
- 5 rune machines (Core style), 125 studs apart. Glow colour matches the pack.
- Rune crystal: a flat, chunky 8-sided cut gem about 10 studs across (Glass, slightly transparent, pack-tinted), leaning back about 20°. Its front face carries 3 nested square frames in Neon hot pink (#FF3DF0) with a white-hot centre. Spins at 20°/s with a pink PointLight inside.
- Billboard per machine: pack name, the currency icon it costs (Tix, Bricks, Build Points or Balls), and cost per open.
- Locked packs show a padlock over the rune until their Stack is reached.

**Feel & effects:** Magical sparkles around each rune, and a crystal chime plus a burst of pink shards on each open.

### 5. Noob Arena
*Screenshot: `shots/zone-05-noob-arena.png`*

- **Realm:** Realm One
- **Unlock:** Stack 4
- **Footprint:** 230×200 studs · X 40–270, Z 200–400
- **Floor colour:** #3aa655
- **Systems here:** Noobs (`Mobs`), Oofs (`Flesh`), Builder XP (`XP`), Builder Level (`Level`), Loot Crates (`Loot`)

**Purpose:** The mob zone. Classic noobs spawn here. Fighting them gives Oofs and Builder XP, and Loot Crates drop.

**How it looks:** A grassy green plate with a round fighting ring fenced by white brick posts. Classic noobs (yellow head, blue torso, green legs) wander and hop inside. Two machines face the ring: Oofs, with a yellow smiley head floating in it, and Builder XP, with a green star. A golden Loot Crate chest sits in the corner, and a scoreboard shows Builder Level.

**Build list:**
- Floor: green plate 230×200.
- Ring: 100 studs across, darker inner floor, 16 white fence posts.
- Noobs: classic R6 noob rigs with a level billboard. They 'oof' and fall apart into bricks on death.
- Oofs machine (Core style, yellow glow) and Builder XP machine (Core style, lime glow).
- Loot Crate chest: wooden chest with gold trim that glows when it's ready.
- Scoreboard: dark panel with the Builder Level shield icon.

**Feel & effects:** Punchy hits, 'oof' sound on kill, damage numbers.

### 6. Gem Lab
*Screenshot: `shots/zone-06-gem-lab.png`*

- **Realm:** Realm One
- **Unlock:** Stack 5 (x2 pad and talent Gem button at Stack 6)
- **Footprint:** 230×130 studs · X 40–270, Z 420–550
- **Floor colour:** #e5579b
- **Systems here:** Gems (`Prisms`)

**Purpose:** The Gems machine, the x2 pad and the Talent Tree board.

**How it looks:** A clean white lab with a pink roof. Out front is the Gems machine, which should match the Crystal Core concept exactly, but purple: a tall faceted purple gem floats between two pillars whose angled caps lean in over it, with violet glow panels and strips. Along the south edge stands a dark Talent Tree wall with glowing buttons laid out as a branching tree.

**Build list:**
- Floor: pink plate 230×130.
- Lab: white 80×35×50 building with a pink roof and blue glass windows.
- Gems machine (Core style, purple glow #A259FF), scaled 1.3×. The gem is Glass + Neon core, elongated diamond shape.
- Talent Tree board: dark wall 70×40 with rows of coloured glowing buttons.
- x2 pad: small gold pad with a 'x2' billboard, locked until Stack 6.

**Feel & effects:** Soft hum, and light beams scattering off the gem.

### 7. Cylinder Garden
*Screenshot: `shots/zone-07-cylinder-garden.png`*

- **Realm:** Realm One
- **Unlock:** Stack 7
- **Footprint:** 180×100 studs · X 300–480, Z 490–590
- **Floor colour:** #1aa39a
- **Systems here:** Cylinders (`Orbs`)

**Purpose:** Cylinders generation. It sits between Spawn and the Crate Merger.

**How it looks:** A calm teal garden. Glossy teal cylinders float in a slow ring above square hedges and flower studs. The Cylinders machine in the middle has a fat teal cylinder spinning on its pedestal, with teal glow.

**Build list:**
- Floor: teal plate 180×100.
- Cylinders machine (Core style, teal glow #2EE6C9) in the centre.
- 6–8 floating teal cylinders orbiting slowly.
- Green hedge bricks and 1×1 flower studs along the edges.

**Feel & effects:** Chill wind chimes and soft glow particles.

### 8. Crate Merger
*Screenshot: `shots/zone-08-crate-merger.png`*

- **Realm:** Realm One
- **Unlock:** Stack 8
- **Footprint:** 180×120 studs · X 300–480, Z 620–740
- **Floor colour:** #1f6fd1
- **Systems here:** Crates (`Cubes (merger)`), Tools (`Gears`), Thrusters (`Accelerator`)

**Purpose:** Crates (the cube merger), Tools (gears) and Thrusters (accelerator).

**How it looks:** A blue factory plate. A black conveyor carries wooden crates into a big blue merger machine that merges them into bigger crates. Crossed hammer-and-wrench Tools spin on a machine beside it. A Thrusters machine has a rocket thruster firing an orange flame.

**Build list:**
- Floor: blue plate 180×120.
- Conveyor: 150-stud black belt with grey rails and wooden crates riding it (they get bigger and darker as they level up).
- Merger: blue 40×35×40 box with a silver hopper, glowing window and output chute.
- Tools machine (Stack style, orange glow) with a crossed hammer and wrench.
- Thrusters machine (Core style, orange/white glow) with a rocket and a flame particle.

**Feel & effects:** Clanks, conveyor whirr, and a rocket roar from the Thrusters machine.

### 9. Ball Tower
*Screenshot: `shots/zone-09-ball-tower.png`*

- **Realm:** Realm One
- **Unlock:** Stack 9 (Meteors at Stack 10)
- **Footprint:** 160×120 studs · X 520–680, Z 560–680
- **Floor colour:** #2b3a8f
- **Systems here:** Balls (`Spheres`), Meteors (`Hail`)

**Purpose:** Balls levels. It's the tallest thing in Realm One, so you can see it from spawn as a goal.

**How it looks:** A navy plate with a wedding-cake tower of round layers that get smaller going up (navy and blue with gold trim). A huge glossy pink ball sits on top, circled by two glowing rings. At the base are a Balls machine (pink ball) and a Meteors machine: a flaming orange rock with a fire trail, which unlocks at Stack 10.

**Build list:**
- Floor: navy plate 160×120.
- Tower: 4 tiers (60/50/40/30 studs across, 25 tall each) with gold trim rings.
- Top ball: glossy pink #FF2FA8, 25 studs across, with a white highlight. Rings orbit it.
- Balls machine (Core style, pink glow).
- Meteors machine (Core style, orange-red glow) with a fire particle trail.

**Feel & effects:** Epic low hum near the tower, and meteor whooshes.

### 10. Obby Gates
*Screenshot: `shots/zone-10-obby-gates.png`*

- **Realm:** Realm One
- **Unlock:** C1 Stack 6 · C2 Stack 8 · C3 1e393 Studs · C4 1e96 Studs
- **Footprint:** 230×160 studs · X 40–270, Z 580–740
- **Floor colour:** #3b4148
- **Systems here:** Obbies (`Challenges`)

**Purpose:** The four Obbies (challenges). Each one resets you to Stack 0 with a handicap, and clearing it gives a permanent boost.

**How it looks:** A dark charcoal plate. Four tall yellow archways stand in a row, each with a glowing portal door (Obby 1 red, 2 blue, 3 green, 4 purple) and a checkered flag on top. In front of each door, a short staircase of orange floating obby blocks leads up to it, like the Obbies icon. Torches stand between the arches.

**Build list:**
- Floor: dark grey plate 230×160 with cracked-tile detail.
- 4 arches: yellow pillars and lintel, Neon translucent door, checkered flag on a pole.
- Orange obby steps (3 blocks each) in front of each door.
- Plaque above each arch: 'Obby 2 · Reach Stack 8', etc.
- Completed obbies swap the door for a gold trophy.

**Feel & effects:** Tense music, faint wind and glowing embers.

**⚠ Reset pad — Obbies (entering):** wipes Everything a Stack does, plus talents (except 16 kept ones), Build Points and their upgrades, Gems, and Stack back to 0. Keeps: Runes, Tix, finished Obbies.

### 11. Rebirth Portal
*Screenshot: `shots/zone-11-rebirth-portal.png`*

- **Realm:** Bridge
- **Unlock:** Studs > 1e2283 (~7 h in)
- **Footprint:** 130×80 studs · X 690–820, Z 340–420
- **Floor colour:** #7a4bc4
- **Systems here:** Rebirth (`Ascension`), The Glacier (`Realm Two (Arctic)`)

**Purpose:** A tan bridge over the water with a giant purple-pink Rebirth ring. Going through it is the only way into The Glacier.

**How it looks:** A studded tan bridge crosses the water. Halfway across, a huge upright ring in the Rebirth colours (purple fading to pink) spins with a swirling portal inside. On the far side, an ice-brick archway (The Glacier icon: a frosty gate with a blue swirl) welcomes you into Realm Two.

**Build list:**
- Bridge: tan plate 130×40 with brick rails and purple lamps.
- Rebirth ring: Neon torus 80 studs tall, standing upright, slowly rotating, with a particle vortex inside.
- Lock gate: grey wall with 'Rebirth: 1e2283 Studs', removed after the first Rebirth.
- Glacier gate: translucent ice-brick arch with a blue swirl, on the Glacier side of the bridge.

**Feel & effects:** A rising choir near the ring and a white flash on teleport.

**⚠ Reset pad — Rebirth:** wipes Everything a Stack does, talents, Build Points, almost all Runes (all but the ultra-rare ones), Gems, Stack, Builder XP and Level, Obby completions. One-time. Keeps: Ultra-rare Runes, Tix; unlocks The Glacier.

### 12. Frost Rune Row
*Screenshot: `shots/zone-12-frost-rune-row.png`*

- **Realm:** The Glacier
- **Unlock:** Polychrome after Rebirth · Cryo Anchor 3 · Arctic Union 7 · Galactic Union 750
- **Footprint:** 340×120 studs · X 830–1170, Z 30–150
- **Floor colour:** #5aa6e0
- **Systems here:** Runes (`Runes`), Gems (`Prisms`), Frost Points (`Arctic Points`), Neon (`Chromium`), Tix (`Tickets`)

**Purpose:** The late-game rune packs, on ice-blue machines along the north edge of The Glacier.

**How it looks:** An icy blue plate with 4 rune machines whose pillars are made of ice, with frost-blue glow. The rune crystals: Polychrome is purple with a rainbow sheen, Cryo is pale cyan and frosted, Arctic is clear white with blue edges, and Galactic is deep space-purple with star specks. All keep the glowing pink square symbol. Icicles hang off an archway behind them. Add a sign: 'Glass & Gems runes: Nature, Polychrome, Cryo, Arctic'.

**Build list:**
- Floor: blue plate 340×120 with snow patches.
- 4 rune machines (Core style), with ice pillars instead of dark ones.
- Billboards with cost icons: Polychrome = Gems, Cryo = Frost Points, Arctic = Neon, Galactic = Tix.

**Feel & effects:** Frost sparkle and soft chimes.

### 13. Glass Well
*Screenshot: `shots/zone-13-glass-well.png`*

- **Realm:** The Glacier
- **Unlock:** After first Rebirth (Stack 10+ runs on Glass)
- **Footprint:** 150×150 studs · X 830–980, Z 190–340
- **Floor colour:** #9fd8f2
- **Systems here:** Glass (`Droplets`), Glacier (`Water`), Diamond Plate (`Ice`)

**Purpose:** Glass generation plus the Glacier and Diamond Plate buttons. It's the first thing you see coming off the portal.

**How it looks:** A pale-ice plate with a stone well full of glowing water. Glass slabs rise out of it and float up. Around the well are three machines: Glass (a cyan glass slab), Glacier (a blue ice-crystal cluster) and Diamond Plate (a silver tread plate). Diamond Plate gets a hazard ring because it resets Glass and Glacier.

**Build list:**
- Floor: light ice plate 150×150.
- Well: grey brick ring 60 across, glowing blue water inside, small roof with a bucket.
- Glass machine (Core style, cyan glow).
- Glacier machine (Core style, blue glow) with an ice crystal cluster.
- Diamond Plate machine (Stack style, silver glow) with a hazard ring. Locked until Anchor 2.

**Feel & effects:** Water drips and a glassy clink on each buy.

**⚠ Reset pad — Diamond Plate:** wipes Glass and Glacier. Keeps: Everything else.

### 14. Anchor Works
*Screenshot: `shots/zone-14-anchor-works.png`*

- **Realm:** The Glacier
- **Unlock:** Anchor 1–3 Stack 11 · 4–6 Stack 12 · 7–9 Stack 13
- **Footprint:** 170×150 studs · X 1000–1170, Z 190–340
- **Floor colour:** #62b8c9
- **Systems here:** Anchor (`Freeze`), Force Fields (`Icicles`), Fog (`Haze`)

**Purpose:** All 9 Anchors (Freeze) as a 3×3 grid of small anchor machines, one row per Stack. Force Fields and Fog unlock at Stack 13.

**How it looks:** A teal plate with a 3×3 grid of small dark machines, each with a blue anchor floating in it. The glow gets brighter row by row (Stack 11 dim, Stack 13 bright). At the back, a Force Fields machine holds a purple glass dome with a tiny cube inside, and a Fog machine puffs lavender clouds. Ice spikes ring the plate.

**Build list:**
- Floor: teal plate 170×150.
- 9 Anchor machines (Stack style, blue glow), each 0.6× size, labelled Anchor 1–9 with cost in Glass. Hazard rings on all of them.
- Force Fields machine (Core style, purple glow).
- Fog machine (Core style, lavender glow) with a cloud particle emitter.
- Ice spikes around the border.

**Feel & effects:** Heavy chain clank and an ice crack on purchase.

**⚠ Reset pad — Anchor 1–9:** wipes Everything a Stack does, plus Gems, Glass, Glacier, Diamond Plate, Glass upgrades, talents (except kept) and Neon. Keeps: Stack level.

### 15. Union Machine
*Screenshot: `shots/zone-15-union-machine.png`*

- **Realm:** The Glacier
- **Unlock:** Talent Union unlock (Gems ≥ 5e43)
- **Footprint:** 340×120 studs · X 830–1170, Z 430–550
- **Floor colour:** #b690e8
- **Systems here:** Union (`Chromatize`), Neon (`Chromium`), Foil (`Chroma`)

**Purpose:** Union (Chromatize). Union 1 or higher starts Neon generation.

**How it looks:** A lavender plate with the biggest machine in The Glacier: a white-and-chrome body with a glass dome, surrounded by rainbow Neon rings spinning at different angles. Two teal cubes merge into one on top, like the Union icon. On either side stand a Neon machine (a green lightning bolt) and a Foil machine (a shimmering pink-cyan foil sheet).

**Build list:**
- Floor: lavender plate 340×120.
- Union core: white/silver 60×40×50 with a glass dome, 6 rainbow rings and the merged-teal-cubes centrepiece. Hazard ring at the pad.
- Neon machine (Core style, green glow #39FF14).
- Foil machine (Core style, iridescent pink/cyan). Locked until Union 1000.

**Feel & effects:** Electric hum, and a rising pitch when you Union.

**⚠ Reset pad — Union:** wipes Talents (except kept), Gems, Neon, Foil. Keeps: Stack, Glass side.

### 16. Publish Spire
*Screenshot: `shots/zone-16-publish-spire.png`*

- **Realm:** The Glacier
- **Unlock:** Publish 1 Lighting · 2 Foil pad · 3 Reflectance
- **Footprint:** 240×160 studs · X 880–1120, Z 590–750
- **Floor colour:** #f0c94a
- **Systems here:** Publish (`Chromify`), Lighting (`Light`), Foil (`Chroma`), Reflectance (`Reflection`), Sparkles (`Shine`)

**Purpose:** The end-game tower. Publish (Chromify) plus the Lighting, Foil and Reflectance machines.

**How it looks:** A golden plate with a 3-tier spire: white base, gold middle, white top, and a glowing gold tip shooting a beam of light into the sky. The Publish machine (a blue up-arrow rising out of a tray) sits front and centre. Around it are Lighting (a glowing bulb), Foil and Reflectance (a mirror). Sparkles particles drift around the whole plate.

**Build list:**
- Floor: gold plate 240×160.
- Spire: 100/75/50-stud tiers, 30 tall each, gold trim rings and windows that light up per Publish level.
- Publish machine (Stack style, blue glow) with a hazard ring.
- Lighting machine (Core style, warm yellow).
- Reflectance machine (Core style, silver/ice-blue) with a hazard ring.
- Sparkles: gold four-point star particles everywhere on the plate.

**Feel & effects:** Choir music and a light beam you can see from anywhere in The Glacier.

**⚠ Reset pad — Publish:** wipes Talents, Gems, Neon, Foil, Lighting, Reflectance, Sparkles and their upgrades. Keeps: Stack, Union level.

## Screenshot index
- `shots/01-view-overview.png`
- `shots/02-view-top-down.png`
- `shots/03-view-realm-one.png`
- `shots/04-view-the-glacier.png`
- `shots/05-view-from-spawn.png`
- `shots/06-view-side-south.png`
- `shots/07-view-side-west.png`
- `shots/08-view-machine-close-up.png`
- `shots/zone-01-spawn-plaza.png`
- `shots/zone-02-brick-forge.png`
- `shots/zone-03-weld-works.png`
- `shots/zone-04-rune-shop-row.png`
- `shots/zone-05-noob-arena.png`
- `shots/zone-06-gem-lab.png`
- `shots/zone-07-cylinder-garden.png`
- `shots/zone-08-crate-merger.png`
- `shots/zone-09-ball-tower.png`
- `shots/zone-10-obby-gates.png`
- `shots/zone-11-rebirth-portal.png`
- `shots/zone-12-frost-rune-row.png`
- `shots/zone-13-glass-well.png`
- `shots/zone-14-anchor-works.png`
- `shots/zone-15-union-machine.png`
- `shots/zone-16-publish-spire.png`
