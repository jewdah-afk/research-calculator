# HANDOUT: Peckwood (Birb remake for Roblox)

This file is the handoff for the next session or teammate. It covers what exists, where it lives, what is verified, and what comes next.

Last updated: 2026-10-07 (Roblox build)

---

## 0. Start here (Roblox build status, 2026-10-07)

The Roblox game now lives in **`roblox/`** (Rojo). The owner has synced it into the place **`birb(test)`** (placeId 104948155633094) and published it. `rojo build -o roblox/Peckwood.rbxl` makes a fresh place file.

### What is built
| Part | Where | State |
|---|---|---|
| Map, bird controller, kernels, camera (from the old place) | `src/server/Island.luau`, `src/client/{Main.client,Controller,Birds}.luau`, `src/shared/{MapData,Models}.luau` | Working. The old `UI.luau` is deleted. |
| Verified math + data | `src/shared/{EternityNum,BirbFormulas,BirbSystems}.luau`, `src/shared/Data/*.json` | Copied from `birb-data/`. A junk row was removed from `quests.json`. |
| Every shop row (cost, effect, max level) | `src/shared/Defs.luau` | All 160 upgrades resolve through `Defs.UP`. The islands progression order (`Defs.ISLANDS`) is here too. |
| Server: state, every system, actions, saves | `src/server/Game.luau` (pure logic), `src/server/Main.server.luau` (players, field, remotes) | Popcorn field, Molt, seeds, sparrow, evolve, fishing (426 fish rolls, rods, baits, aquarium), seagull, Dave, red panda, nest, crow mining, echo, expedition, quests, sacrifice, profile. |
| Dev saves | `Main.server.luau` `A.dev` | **REGULAR** (your real save), **MAXED** (everything unlocked and maxed), **NEXT ISLAND** (works on a copy and steps forward one unlock). The sandbox states never save. Only Studio, the owner, or `Config.DEV_USER_IDS` can use them. |
| AUTO = group perk | `Config.GROUP_ID` (**still 0, set it**), `A.auto` | Membership is checked on the server with `IsInGroup`. Locked players get `GroupService:PromptJoinAsync` and then a re-check. AUTO collects a kernel every 0.35s and buys the cheapest affordable upgrade every 1s. While `GROUP_ID` is 0, it only works in Studio. |
| UI | `src/client/UI/{Kit,Window,Windows,Spec,Hud}.luau` | Details below. |

### How the UI matches Figma
- **Window art is the Figma frame itself.** The temporary atlas `83:7` holds a copy of each UI v2 window with its live layers hidden (text, `ico/*`, `btn/*`, sparkles, progress fills, chevrons). Each copy was rendered at 2x (including the rim glow, with a 150px margin at 1x), uploaded, and listed in `src/shared/FigmaArt.luau`. Button faces (`btn/<window>_buy|tab|hero`, `grey_buy`, `grey_all`, `blue_all`, `gold_maxed`) were cut from `roblox/assets/figma/buttons_sheet.png`.
- **Live layers are drawn on top at the Figma coordinates** (`Window.luau`): title, tab contents, hero icon/title/subtitle/button, section label, row icon/title/growth/description/progress fill/buttons, footer, sparkles.
- **Texts and colours per window** are in `Spec.luau`, extracted from the Figma layers. Icons are the PNGs actually placed in each Figma slot, matched by image bytes rather than by the stale layer names.
- **Motion** follows the spec cards: open (0.86 to 1.04 to 1), close, rows cascading in, icons bobbing ±3px, hero icon tilting ±4°, sparkles twinkling, buy-button glow pulsing, shine sweep when something becomes affordable, can't-afford shake with red flash, wallet capsule wiggle, currency particles flying to the HUD, violet flash on Molt.
- **HUD** (`Hud.luau`): Figma `8:271` (map banner, toast, wallet capsules, objective bar, shop docked on the right). Additions: the window menu (3 columns, only unlocked windows show), the dev panel, the AUTO button, the UNLOCK button for paid island gates, and the full Fish Index overlay.
- **Gotchas found:**
  - A UIGradient on a CanvasGroup tints everything inside it. Put gradients on a child frame instead.
  - Only one UIScale applies per object. The fit-to-height scale sits on a wrapper.
  - Images taller than about 2048px did not render, so window renders are resized to fit (`assets/figma/fit/`).
  - The Roblox top-left menu covers HUD y<60.

### Open issues (do these next)
1. **Done:** all 83 Figma images load. They took about 1 hour in Roblox moderation after upload, so new uploads look blank until they clear.
   **Also fixed:**
   - MAXED froze the server: the level-up loops ran without end. They are now capped (crow 500, parrot, sparrow and Dave 1000).
   - The buy particle effect is removed (owner's call).
   **Debug hook:** `PlayerGui:SetAttribute("PeckwoodOpen", "<window id>")` opens a window, and `Remotes.Action:FireServer("dev", "maxed")` from Client `execute_luau` switches the save. Use these for screenshots without clicking.
2. Delete the Figma temp atlas `83:7` once the art loads (`use_figma`: `(await figma.getNodeByIdAsync('83:7')).remove()`).
3. Upload the 426 fish icons (`birb-icons/final/fish/`, batches of 25, serve on :8799) and add them to `Icons.luau` using `tools/rec.py` and the generator snippet. Until then, fish rows show no icon.
4. Islands other than the Park reuse the Park map. The Desert is a field toggle (golden drops). Each island still needs its own 3D area: garden, bridge/fishing spot, forest, mine, castle.
5. Visual polish pass: compare each window side by side with Figma, then work on map hierarchy (section 5).
6. Unverified numbers: seeds base 3/s (from the Figma copy), fishing cast 4s × rod speed, expedition kill rate and floor progression (simplified), Dave XP from golden pickups.

### Tools
- `roblox/tools/gen_manifest.py` writes the list of scripts to sync.
- With `python -m http.server 8778 --bind 127.0.0.1` running in `roblox/`, run the sync snippet `tools/sync.luau` through `execute_luau` in Edit mode. It pushes every `.luau` into the open place. JSON data needs `rojo build`.
- `tools/rec.py` / `tools/rec2.py` record uploaded asset IDs into `asset_ids.json` / `figma_ids.json`.

## 1. What the project is

Peckwood is a Roblox remake of **Birb** (hwonze; web build at birbplay.com). The goals:

- **Gameplay math:** must be **1:1 with the original**. Every cost, multiplier and curve is copied from the original game's code, not guessed.
- **Art and UI:** new. Uses the Peckwood UI v2 style in Figma.
- **3D item drops:** planned. They will be Blender models.

### Peckwood names for Birb concepts

Use the Peckwood name in UI and copy, and the Birb name in code comments when it helps to cross-reference the original.

| Birb (code / original) | Peckwood (UI) |
|---|---|
| Rebirb | **Molt** |
| Golden Feathers | **Plumes** |
| Popcorn | Popcorn |
| Sunflower Seeds | Seeds |
| `p_` upgrades | Popcorn shop |
| `pr_` upgrades | Molt shop ("Plume Keepsakes") |
| `s_` upgrades | Seed shop |

**Level display:** the Peckwood UI shows the internal level minus 1. Popcorn Value internal level 4 displays as "LV 3 / 998". All formulas use internal levels, so subtract 1 when displaying.

---

## 2. Repo map (`jewdah-afk/research-calculator`, branch `main`)

| Path | What it is |
|---|---|
| `birb-data/CORE_FORMULAS.md` | Core loop: cost rules, popcorn spawn and type odds, popcorn value stack, golden popcorn, rebirb (Molt) feathers |
| `birb-data/SYSTEMS.md` | Every other system (full list below) |
| `birb-data/UPGRADES.md` + `upgrades.json` | All 160 upgrades: currency, base cost, growth, max level, effect |
| `birb-data/data/*.json` | Raw game tables: 426 fish, rods, baits, 47 artifacts, 43 enemies plus type modifiers, sacrifice milestones, 33 quests |
| `birb-data/EternityNum.luau` | Big-number library (see §3) |
| `birb-data/BirbFormulas.luau` | Luau port of the core loop. Wallets are EN values. Includes `buy` and `buyAll` |
| `birb-data/BirbSystems.luau` | Luau port of the systems math |
| `birb-data/README.md` | How the files fit together, and how to drop them into Roblox |
| `.claude/settings.json` | Lets Claude use Figma tools without permission prompts |
| `index.html` | Older research/RLGM calculator. Not part of the Birb port |

`SYSTEMS.md` covers:
- Mining and the crow
- The nest: twigs, cultivation, carpentry, riverside
- Fishing
- Sparrow, Seagull, Dave and Red Panda
- Evolution
- Parrot combat and enemies
- Equipment and artifacts
- Sacrifice and the Quest Merchant
- The Echo field

**Source of truth:** the birbplay.com web build, pulled on 2026-10-06. The bundles were `game-C7SSmAJa.js`, `editors-BzRYmPQ2.js`, `maps-CcKoUYtq.js` and `main-DBny4oxD.js`. If the original game patches, re-pull these and diff them.

---

## 3. Verification status

Every Luau port was run against the original game's own functions, copied word for word out of the bundles. Every row below passed with zero mismatches.

| Check | Values compared |
|---|---|
| Upgrade costs, all 160 upgrades at levels 0–30 | 4,960 |
| Mine costs, ore and giant HP and rewards, nest costs, tree boxes, carpentry soft-cap, Parrot and Seagull XP, all 43 enemies on floors 1–12 (normal and boss) | 3,347 |
| EternityNum vs break_eternity.js: add, sub, mul, div, pow, pow10, log10, ln, sqrt, exp, floor, ceil, cmp, over layers 0–3 | 22,629 |
| Buy-all closed form, save round-trip, leaderboard encoding order | Unit-tested, all pass |

**EternityNum:**
- Same `{sign, layer, mag}` layout and function names as FoundForces' EternityNum: `add`, `mul`, `me`, `meeq`, `le`, `leeq`, `eq`, `short`, and so on.
- The original model needs a Roblox login to download, so this is a clean port of break_eternity, which is the library both EternityNum and the original Birb are built on.
- Extras:
  - Fast paths for plain numbers.
  - `geomSum` / `geomAfford` for O(1) buy-all.
  - `toString` / `fromSave` for lossless saves.
  - `lbencode` / `lbdecode` for OrderedDataStore leaderboards.

**Not covered yet:**
- Rendering, animation and multiplayer code. These aren't game balance.
- Per-enemy AI attack patterns. Their stats are covered.
- The aquarium modifier table.
- Artifact infusion caps. These come from the wiki and are unverified against the code.

---

## 4. Figma

**File:** https://www.figma.com/design/SQOJ2gzGt12vFMGGlNRWBE (page **UI v2**, node `7:7`)

Watch the file key: the letter after `GG` is a lowercase **l**. A key with a capital I opens a different file that this account can't access.

### What's on UI v2

| Node | Frame |
|---|---|
| `7:8` | Icon assets: popcorn, plume, golden, wing, magnet, clock, seed, index, crown, plus textures (studs, stripes, lattice, grain) |
| `8:7` | **Shop board**, containing the three windows and specs below |
| `8:122` | Popcorn shop (amber), layer 0 |
| `8:250` | Molt shop (violet), layer 1, with hero |
| `43:7` | Seeds shop (green), layer 2, with sunflower hero |
| `49:10` | **Golden shop** (gold, desert), with the desert hero and new textures |
| `57:7` | **Mine shop** (steel cyan, crow hero), 4 rows: Mining Power, Ore Value, Charged Strike, Rupture. Uses the final icons |
| `59:7` | **Nest shop** (cedar red-brown, nest hero), 3 rows: Twig Value, Peck Rate, Peck Power |
| `60:7` | **Echo shop** (magenta, echo spirit hero), 2 rows: Echo Value, Echo Capacity |
| `61:7` | **Parrot / expedition** (emerald, parrot hero), 3 skill-point rows: Health, Damage, Regen. Buttons read SPEND ALL |
| `62:7` | **Evolve** (crimson, castle monster hero), 3 feed rows for evolution 3 to 4: popcorn 1Qa, twigs 100K, moneta 10K. Buttons read FEED / FEED ALL |
| `45:7`, `45:19`, `45:33`, `49:161`, `57:166`, `59:166`, `60:166`, `61:166`, `62:166` | Motion spec cards under each window |
| `65:8`, `65:181`, `65:354`, `65:527` | **Companion panels** (row under the shops, label COMPANIONS): Sparrow (Feed, Resonance, Mitosis), Seagull (Route, Doctrine, Migration), Dave (Seed Training, Rebirb), Red Panda (Assist Mode). Spec cards `65:167`, `65:340`, `65:513`, `65:686`. Header, tab and hero use the new `sparrow`, `seagull`, `dove` and `redpanda` icons |
| `70:8`, `70:181`, `70:354`, `70:527` | **Fishing** (row under companions, label FISHING): Rods (craft Normal/Reinforced/Pro from fish), Bait (Coastal Chum 1, Fresh Pellet 5, River Grub 10 moneta), Fish Index (sample catches Silver Fish, Swallowtail, Huchen with EQUIP/SELL), Aquarium (2 tanks, PLACE). Shared deep-ocean base 216°; buttons per icon: rod red, worm pink, clownfish orange, seaweed green. Tabs read "Fishing / <tab>". Rows use the real tiered icons (rods by tier, baits, fish, tanks by size) |
| `75:8`, `75:181`, `75:354` | **Quests, Sacrifice, Profile** (row under Fishing). Quests: merchant hero, 3 dailies (floor kill, hunt, boss) with CLAIM/TRACK. Sacrifice: altar hero, milestone rows Tier I-III (450, 10K, 100K) using `sacrifice_I`..`XVIII` crests that grow more ornate per tier. Profile: `birb` hero, records rows (fish index, highest floor, sacrifice tier) and an **ALL STATS drop-down** (`80:7`, HIDE ▲) with 18 icon stat chips in two columns |
| `8:271` | HUD 1920×1080: money capsules, map banner, objective, toast, docked shop |

Page 1 of the same file holds an older version with studded buttons. Don't use it as a reference.

### Rules for every new screen (non-negotiable)

1. **Duplicate the real frames** (header, tabs, rows, buttons, progress bars) from the UI v2 windows. Never redraw them. Change only text, icons and theme colors.
2. **Each reset layer gets its own identity** (color and hero), while keeping the same layout order: header → tabs → hero (for reset layers) → section label → rows → footer. The footer must state what resets that layer.
3. **Premium FX on every window:**
   - Two-layer rim glow in the theme color.
   - Top edge light.
   - 4-point sparkles in the header and hero.
   - Glow on affordable buy buttons.
4. **Motion is documented in two places:** a Motion spec card under the window, and Figma annotations on the layers themselves (window, header, every `btn/buy`, every `progress`, the hero).
5. **Header:** title only, centred (no icon, user's call). The lip under the header is a 12px band in the theme's own dark tone, not black, with a 2px tinted ink line. A soft tinted drop shadow (y 6, blur 14, 38%) falls on the body, plus a tight 2px contact shadow. Keep the header clipped.
6. **Fonts:**
   - Fredoka One for titles and buttons.
   - Fredoka for body text.
   - Ink color `#0B0C10` for strokes.
   - Fredoka has no `↔` glyph. Write "to" instead.

### Theme palette so far

| Layer | Header gradient | Glow |
|---|---|---|
| Popcorn | `ffd27a → f7a634 → e07a1c → 9e4a0c` | `ffb45a` |
| Molt | `e9c4ff → b06cff → 8a3fe6 → 4f1d9c` | `b06cff` |
| Seeds | `e6ffc4 → 8fe04a → 4fb52a → 256a12` | `8fe04a` |
| Golden | the Seeds gradient hue-shifted to gold (hue 44°, darks 34°) | `ffd259` |

**Icon-matched palettes (2026-10-07).** The user wants every window coloured from its hero icon's own colours, using several of them. Each window has three roles: **p** (header, hero, body), **b** (main buttons and active tab) and **a** (row titles and stat text). Each is a target hue plus saturation and lightness factors applied to the Golden source colours:

| Window | p | b | a |
|---|---|---|---|
| Mine (crow + ore) | navy 226° | ore cyan 194° | beak yellow 46° |
| Nest | wood brown 22° (l×0.88) | leaf green 105° | egg yellow-cream 46° |
| Echo | deep violet 282° (l×0.88) | hot pink 322° | bright pink 328° |
| Parrot | red 356° (l×0.88) | wing blue 212° | yellow 50° |
| Evolve (monster) | deep teal 192° (l×0.82) | mouth purple 284° | mint 160° |
| Sparrow | chestnut 22° (l×0.85) | seed yellow 48° | cream 40° |
| Seagull | wing blue-grey 212° (s×0.7, l×0.85) | beak yellow 48° | white 50° (s×0.2) |
| Dave | dove lilac 278° (s×0.42) | leg pink 335° | pale lilac 290° |
| Red Panda | dark maroon fur 356° (l×0.78) | rust orange 20° | cream 40° |

**Rule (user's call, Mine is the reference):** a deep, darkened base hue, buttons in a bright hue far from the base, and stat text in a third contrasting hue. Never three shades of one hue.

The BUY ALL buttons and progress bars keep the Golden source colours.

**How the new windows were made:** clone `49:10` and `49:161`, add or remove `row/*` (126px pitch, window height follows), recolour by walking the clone alongside `49:10` and mapping each warm colour (hue 10–70°) to the window's p/b/a role (greys, inks, the blue BUY ALL and progress bars stay as they are), rewrite text, then upload PNGs from `birb-icons/final/` as FIT image fills on the cloned `ico/*` rectangles. The board `8:7` was widened for each.

### Textures (in `7:8`)

These are new 2026-10-07, inspired by glossy tile references: a fine dot grid, twin diagonal glass streaks, a bright inner rim and a dark bottom lip.

- `tex/halftone` (`49:7`): white dot grid, used as an OVERLAY tile. Header 35%, button faces 22%, row cards 10%.
- `tex/dunes` (`49:8`): wavy sand ripples, used as an OVERLAY on the desert hero art.
- `tex/glitter` (`49:9`): sparse 4-point glints, used as SCREEN on the hero.
- `fx/glass streak`: a wide band plus a thin band at -35°, using a SCREEN gradient. It sits on row cards and the hero art.

Use these on the remaining windows too.

### Shared motion language

The full text is on the spec cards. In short:

| Moment | Motion |
|---|---|
| Open | Scale 0.86 → 1.04 → 1 (320ms back-out) from the HUD button. Rows cascade in with a 40ms stagger |
| Close | Rows collapse in reverse first, then the window fades into the HUD button. Sparkles burst out |
| Idle | Header gloss sweep every 4.5s. Sparkles twinkle. Rim glow breathes over 2.8s. Icons bob ±3px |
| Buy | Press squash 0.94, then release with a 1.06 overshoot. The stat value pops, the bar tweens, and currency particles fly to the HUD wallet |
| Can't afford | Shake ±6px ×3 and a red cost flash. The HUD wallet wiggles too |
| Maxed | Gold plate pops in with sparkles. The level bar turns gold and shimmers |
| Tabs | The pill springs between tabs, and the whole window retints to the target layer |
| Reset moments | **Molt:** hold-to-confirm, then a violet flash, feathers fly to the Plumes counter, and rows dissolve into dust. **Evolve:** seed rows wilt brown and fall away |

### Other Figma file (can be deleted)

"Peckwood UI Kit" (`tx8B2elQnVUSzhrPNseVrq`) is an early attempt that does **not** match the v2 style. It's safe to delete once the user confirms.

---

## 5. Next steps (in order)

0. **Roblox Studio build: see section 0** (1:1 import, Regular + Maxed saves with a non-destructive next-island toggle, wiring, polish, then map hierarchy).
1. **Review the five new windows** with the user (Mine, Nest, Echo, Parrot, Evolve). Open questions: the Nest footer says Molt and Evolve keep twigs and the twig shop, which is not verified in the data; Moneta uses the fish icon; Rupture uses the sword.
3. **Fishing follow-ups:** the aquarium modifier table once it is pulled from the bundle.
4. **Quests, sacrifice and profile follow-ups:** a scrolling main-quest list (19 quests) and a full 18-tier sacrifice list.
5. **Missing icons** in the icon-set style: spirit, and any new currencies the remaining windows need.
6. **Blender models for all item drops**, matching the icon set. Not started.
7. **Roblox wiring:** drop the three ModuleScripts (`EternityNum`, `BirbFormulas`, `BirbSystems`) into ReplicatedStorage. Load `upgrades.json` and `data/*.json` as data modules.

---

**Mine shop data:** costs at level 0 are 240, 180, 4,800 and 2e6 Brute Ore. All four are non-permanent, so Evolve resets them.

**Golden shop data:** Golden Value (`p_golden_popcorn_value`, base cost 10, ×1.55, max 999), Auric Silo (`p_auric_silo`, base cost 1000, ×1.8, max 50) and Gilded Margins (`d_desert_field_notes_plus`, base cost 5000, ×10, max 3). Molt resets the two `p_` rows. The golden popcorn balance and the desert unlocks are kept. The other one-off desert unlocks still need a tree screen.

## 6. Gotchas

- **`use_figma` writes:** run them one at a time. Re-fetch nodes after a component edit, because instance child IDs change.
- **Figma connection drops:** it can disconnect mid-session. Re-load the tools with ToolSearch and keep going. The node IDs above stay stable.
- **Costs:** in the original, costs are plain numbers capped at 1.8e308. Only currency balances and Molt payouts are big numbers. The Luau port does the same.
- **Display:** show HUD numbers with `EN.short(x)` (K, M, B, T, Qa, Qi, ... then scientific notation, then layer notation).

---

## 7. Icons (2026-10-07)

The final UI icons are in `birb-icons/final/*.png` (98 UI icons) and `birb-icons/final/fish/*.png` (all 426 fish, named by fish id), 256px, transparent, with a uniform ink outline. The companion icons (sparrow, seagull, dove, redpanda) and fishing icons (moneta, rod, bait, aquarium) come from `fishing_sheet.png` and `birb-icons/companions_sheet.png` (Figma AI, gpt-image model) cut by `cut_companions.py`. The rest come from the user-approved sheet (`birb-icons/approved_sheet.png`) and were QA'd one by one on both dark and light backgrounds. `final/manifest.json` lists every icon and anything in the game data still missing one (currently nothing for fish, rods and baits). Gear sets come in visible tiers: 23 rods (`rod_<id>`, bamboo stick up to divine), hooks wood to diamond plus ancient/cursed, lures basic to legend, `tank_1`..`tank_5` drawn at growing size (cut with `!` so size is kept), 12 baits plus 13 golden `shiny_bait_*`. **Header rule (user): no icon in window headers, the title alone is centred. Everything on buttons (icon + label) is centred on the face; hero titles and subtitles are centred.** **Colour rule (user): each window uses its hero icon's colours as a multi-colour gradient (header, hero art, main button, active tab, lit buy button) with a white-top / dark-bottom shade layer on top; can't-afford buttons stay grey and BUY ALL stays blue.** **Rule from the user: anything that upgrades must look visibly better at each step, and size tiers (tanks) must grow.** New sheets: 4x4 grid on black from Figma AI (gpt-image model, see `sheets/`), cut with `python3 birb-icons/cut_grid.py <sheet> 4 4 names...`, checked with `qa.py`; fish prompts are built from the data by `fish_prompts.py` and cut by `fish_cut.py`. Use these for every new window instead of the older Figma `icon/*` set. They are placed in the Mine shop (`57:7`) by uploading the PNG as an image fill on the cloned `ico/*` rectangles (FIT). The older windows still use the old Figma `icon/*` set.

The Blender source scene (`birb-icons/*.py` and `peckwood_icons.blend`) is set up for later 3D icon ports, but nothing is exported yet. See `birb-icons/README.md` for the style rules and the export plan.
