# Vampire Survivors (v1.16 base game) UI / HUD / screen-FX research

Scope: only Vampire Survivors. This covers the UI layer: HUD, level-up, chests, Arcana, menus, results, fonts, palette, transitions and full-screen FX.
Date: 2026-10-15. Status: research draft, not committed.

**Confidence tags.** `[S#]` is a source number from the reference list (section 4). `inferred` means it comes from memory of gameplay or genre convention, with no web source found. Every `inferred` px, timing or colour value needs checking against a 1.16 capture before you lock it. The wiki gives structure (what is shown and in what colour class) but almost never pixel sizes or timings. Most numbers below are therefore marked `inferred` on purpose.

**Fps tiers.** T0 = static or event-only (redraw on change). T1 = 10-15 Hz (pixel-step animation, matches VS sprite cadence). T2 = 30 Hz. T3 = per-frame (RenderStepped).

**Covered-by.** `OURS:<name>` means one of our existing ~89 procedural algorithms covers it, or covers it with retuning. `NEW` means it needs building. Our HUD set: Portrait Medallion, Falling-Sand HP bar, Wave XP bar, Cooldown Sweep, Rolling Odometer, Typewriter Reveal, Damage Numbers.

> **1:1 warning.** The real VS HUD is plain and flat. The bars are solid fills with no sand or wave. If we want a 1:1 remake, `OURS:Falling-Sand HP` and `OURS:Wave XP` must run in a "flat" mode (simulation off) by default. Keep the fancy versions behind a flag.

---

## 1. Effect catalog (132 entries)

Columns: id | name | usage | algorithm | params | tier | covered | sources

### 1A. In-run HUD (H)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| H01 | XP bar frame | Full-width strip at the very top of the screen | 9-slice dark frame; fill rect width = W*(xp-xpPrev)/(xpNext-xpPrev); hard pixel edge, no easing | h≈12-16 px @ 1x; fill blue | T0 | OURS:Wave XP (flat mode) | S2,S19 inferred-size |
| H02 | XP bar fill colour | XP fill | solid blue (#2E5BFF-ish) with 1 px lighter top highlight row | inferred hex | T0 | OURS:Wave XP | S2, inferred |
| H03 | XP bar fill step | On gem pickup | snap fill to new value (VS does not tween); optional 1-frame brighten | - | T3 | OURS:Wave XP | inferred |
| H04 | XP bar overflow / multi-level | XP enough for several levels | fill wraps to 0 each level; level-ups queue and the menu reopens once per level | queue N | T0 | NEW (queue logic) | S6, inferred |
| H05 | Level label "LV n" | Right end of the XP bar | white text with black 1 px outline, right aligned inside the bar | font = UI font | T0 | NEW | inferred |
| H06 | Survival timer mm:ss | Top centre, under the XP bar | integer seconds; format %02d:%02d; large white outlined digits | ~2x body size | T0 (1 Hz) | OURS:Rolling Odometer (disable roll for 1:1) | S2,S20 |
| H07 | Timer at 30:00 | Reaper spawn moment | timer keeps counting; no colour change confirmed | - | T0 | NEW | inferred |
| H08 | Gold counter | Top right: coin icon + number | int; updates on pickup; no roll in the original | icon 8-16 px | T0 | OURS:Rolling Odometer (flat) | S2, inferred-pos |
| H09 | Kill counter | Top right next to gold: skull icon + number | int | - | T0 | OURS:Rolling Odometer (flat) | inferred (no web source found) |
| H10 | Weapon slot row | Top left under the XP bar: up to 6 weapon icons | 16x16 icons, 1 px gap, rendered in pick order | max 6 [S10] | T0 | NEW | S10, inferred-pos |
| H11 | Passive slot row | Second row under the weapons | same as H10 | max 6 | T0 | NEW | inferred |
| H12 | Slot empty state | Unfilled slots | dark translucent square or nothing (verify) | - | T0 | NEW | inferred |
| H13 | Slot level pips | Under or over the icon | inferred: not shown in the HUD; level is shown in pause/level-up | - | T0 | NEW | inferred |
| H14 | Weapon cooldown sweep | Optional | NOT in the original HUD; keep it off for 1:1 | - | T3 | OURS:Cooldown Sweep (disable) | inferred |
| H15 | Player HP bar | Under the player sprite, world-anchored | red fill on a dark backing; width ∝ hp/maxHp; ~player width | ~16x2 px | T3 (follows player) | OURS:Falling-Sand HP (flat mode) | inferred |
| H16 | HP bar hide at full | - | inferred: always shown | - | - | - | inferred |
| H17 | HP bar damage step | On hit | instant shrink (no trailing "ghost" bar in VS) | - | T3 | OURS:Falling-Sand HP | inferred |
| H18 | Portrait | Not in VS HUD | VS has no in-run portrait; portraits appear only in character select / results | - | - | OURS:Portrait Medallion -> menus only | S10,S5 |
| H19 | Arcana HUD icons | Small arcana cards near the slot rows (when the Arcanas mode is on) | icon per held arcana | - | T0 | NEW | S7, inferred-pos |
| H20 | Off-screen arrows | Chest/relic/boss guides at the screen edge | arrow clamped to the screen rect, rotated toward the target; yellow/gold for chests, purple for arcana chests, green for relics | edge inset ~8 px | T3 | NEW | S8,S15,S26 |
| H21 | Stage progression bar | Option "Show Stage Progression" | progress toward stage time | - | T0 | NEW | S12 |
| H22 | Virtual joystick | Mobile option | Legacy/Default types | - | T3 | NEW | S12 |
| H23 | Border option | Screen border Solid/Transparent | letterbox frame art | - | T0 | NEW | S12,S16 |
| H24 | Pickup magnet streak | Gem fly-in to player | not UI; listed for layering only | - | T3 | n/a | - |
| H25 | Damage numbers (enemy) | Over enemies when the option is ON | white integer, small font, pops up and fades; value is randomised (±~5 noted by community) | life ~0.5 s inferred | T3 | OURS:Damage Numbers | S12,S27 |
| H26 | Damage numbers toggle | Options > Damage Numbers | global bool | - | - | OURS | S12 |
| H27 | Crit damage number style | Weapons that can crit | unknown style; do not invent: render same as normal until verified | - | T3 | OURS:Damage Numbers | S28 (no style info) |
| H28 | Heal number | Floor chicken / recovery | inferred: green number at the player | - | T3 | OURS:Damage Numbers | inferred |
| H29 | Twitch mode overlay | PC option | out of scope for Roblox | - | - | skip | S12 |
| H30 | Co-op indicators | Player colour outlines | out of scope (single player) | - | - | skip | S12 |

### 1B. Level-up screen (L)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| L01 | Game pause on level-up | XP reaches threshold | timeScale=0 for the world; UI runs on unscaled time | - | T0 | NEW | S6,S19 |
| L02 | Background dim | Behind the panel | full-screen black at ~50-60% alpha, no blur | alpha inferred | T0 | NEW | inferred |
| L03 | Falling gems rain | During level-up | blue/green/red gem sprites spawn above the top edge at random x, fall with gravity, despawn below; behind the panel | ~20-40 alive inferred | T2 | NEW | S6,S19 |
| L04 | Cats rain variant | If Gatti Amari is among the options | swap the gem sprites for cat sprites | - | T2 | NEW | S6,S24 |
| L05 | Panel frame | Centre column | 9-slice dark-blue/purple panel with a lighter border; title "Level Up!" (inferred wording) at top | width ~1/3 screen inferred | T0 | NEW | inferred |
| L06 | Card count | 3 options, 4 with Luck | n = 3 + (rand < luckChance ? 1 : 0) | Luck-based | T0 | NEW | S6,S19 |
| L07 | Fill to 3 below level 3 | Since Aug 2023 | when the pool has < 3 options under level 3, pad with filler | - | T0 | NEW | S6 |
| L08 | Card row layout | Vertical stack of horizontal cards | icon left (16 px ×2), name + level line top, description below | gap ~4 px inferred | T0 | NEW | inferred |
| L09 | "New!" marker | Item not owned yet | yellow "New!" text where the level would be | colour inferred yellow | T0 | NEW | inferred |
| L10 | Level line | Owned item | "level: n" shown for the next level | - | T0 | NEW | inferred |
| L11 | Evolution hint icons | Card for a weapon/passive that is part of a discovered evolution | small partner icon(s) drawn on the card; only for evolutions already discovered | icon 8-16 px | T0 | NEW | S6 (0.3-era note "info for discovered evolutions") |
| L12 | Evolution card | When an evolution is offered | evolved weapon shown as a level-up option (actual evolution happens via chest in VS; verify for level-up) | - | T0 | NEW | S30 (low quality), S8 |
| L13 | Description text | Card body | short text, white, wraps; Typewriter not used in the original (text appears instantly) | - | T0 | OURS:Typewriter Reveal (disable for 1:1) | inferred |
| L14 | Selection highlight | Keyboard/gamepad focus | inferred: brighter border / tint on the focused card | - | T1 | NEW | S12 ("Tint UI Selection" co-op) |
| L15 | Reroll button | Only if Reroll PowerUp > 0 | button with remaining count; regenerates the option set | count per rank | T0 | NEW | S1,S6 |
| L16 | Skip button | Only if Skip PowerUp > 0 | closes the menu; VS grants some XP on skip (verify amount) | count 2/rank per S1 claim; verify | T0 | NEW | S1,S6 |
| L17 | Banish button | Only if Banish PowerUp > 0 | enter banish mode, pick a card, remove that item from the pool for the run | count per rank | T0 | NEW | S1,S6,S3 |
| L18 | Banish keeps menu | Since 2026 update | after a banish, the menu stays open | - | T0 | NEW | S6 (post-1.16; flag) |
| L19 | Preserve proc | Preserve PowerUp | 10%/rank (max 50%) chance a used reroll/skip/banish is not consumed | p=0.1*rank | T0 | NEW | S1,S7a |
| L20 | Filler options | Pool empty | Gold Coin / Floor Chicken cards | - | T0 | NEW | S17 |
| L21 | Limit Break panel | Limit Break mode, all maxed | stat-boost options; community says "right side"; "Always random" toggle | - | T0 | NEW | S17,S18 |
| L22 | Panel reveal | Menu open | inferred: instant or a short scale-in (≤0.2 s); 1.6.0 changed VFX/hierarchy | ≤200 ms inferred | T2 | NEW | S6 |
| L23 | Level-up SFX | Open | jingle; Classic/Blast Processed variants | - | - | NEW (audio) | S12 |
| L24 | Stats in level-up | Stats panel visible while levelling | side panel with player stats | see P05 | T0 | NEW | S21 |
| L25 | Button colours | Reroll/Skip/Banish | inferred: Reroll blue, Skip yellow/orange, Banish red | verify | T0 | NEW | inferred |

### 1C. Treasure chest sequence (C)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| C01 | Chest pickup pause | Touch chest | pause world, open the chest UI | - | T0 | NEW | S9,S29 |
| C02 | "Treasure Found" jingle | On pickup | then Treasure A/B/C by item count 1/3/5 | - | - | NEW (audio) | S9 |
| C03 | OPEN button | First state | button rotates out when pressed (1.6.0) | rot-out ~0.2 s inferred | T2 | NEW | S9b |
| C04 | Chest bounce/glow | Before open | light swirls around the chest | - | T2 | NEW | S29 |
| C05 | Item reels | Slot-machine reels per item | vertical strip of candidate icons scrolling fast, decelerating to the result | 1/3/5 reels | T3 | NEW | S29,S25 |
| C06 | Reel stop flash + ring | Each reel lands | white flash plus an expanding ring over the reel (sorted above the reels per 1.6.0) | - | T3 | NEW | S9b |
| C07 | Stars behind reveal | Behind the revealed weapon | twinkling star sprites | - | T1 | NEW | S9b |
| C08 | Gold count-up | Under the reels | number scales in, counts up during the music, pulses after a delay | base gold 100-200 / 300-600 / 500-1000 × Greed | T3 | OURS:Rolling Odometer | S9,S9b,S29 |
| C09 | Coloured bursts / fireworks | 3/5-item chests | particle bursts in many colours shooting from the chest; 5-item "jackpot" is more intense | - | T2 | NEW | S25,S29,S9b |
| C10 | DONE button | End state | rotates in (1.6.0); shorter delay on 1- and 2-item chests | - | T2 | NEW | S9b |
| C11 | Skip rules | Esc/right-click/B | first six chests (1-1-3-1-1-5) can't be skipped; then 1 and 3 can; 5 unlocks later | - | T0 | NEW | S9 |
| C12 | Coin-only chest | Gold-only | quick animation | - | T2 | NEW | S9 |
| C13 | Arcana chest colour | Arcana chest | purple chest + purple arrow | - | T0 | NEW | S9,S7 |
| C14 | Evolution reveal | Evolved item from chest | evolved icon shown in the reel; previous weapon replaced in the slot | - | T0 | NEW | S9b, inferred |
| C15 | Item name/desc panel | After reveal | names + descriptions of the gained items | - | T0 | NEW | inferred |

### 1D. Arcana selection (A)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| A01 | Arcana pick at run start | Before the run when Arcanas mode is on | choose any unlocked arcana or random | - | T0 | NEW | S7 |
| A02 | Arcana chest draft | Bosses at 11:00 and 21:00 | offers ≥4 random uncollected arcanas; 6 if ≥23 unlocked | n=4/6 | T0 | NEW | S7 |
| A03 | Arcana reroll | Reroll in the draft | shown cards don't recur until all have been seen | - | T0 | NEW | S7 |
| A04 | Draft skip | Since 0.11.0 | skip button | - | T0 | NEW | S31 |
| A05 | Selection toggling | Since 0.5.1 | toggle cards on/off in the menu | - | T0 | NEW | S31 |
| A06 | Card art | Tarot card sprite, roman numeral + name | portrait card ~2:3, static sprite | - | T0 | NEW | S7 |
| A07 | Card focus | Hover/focus | inferred: card lifts 2-4 px + brighter frame | - | T2 | NEW | inferred |
| A08 | Card description | Below or beside the card | effect text | - | T0 | NEW | S7 |
| A09 | Pause menu arcana info | 1.12+ | arcana info listed in pause | - | T0 | NEW | S31 |
| A10 | Darkana variant | (DLC) | out of scope | - | - | skip | S7 |

### 1E. Pause menu (P)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| P01 | Pause dim | Esc | same dim as L02 | - | T0 | NEW | inferred |
| P02 | Title "PAUSED" | Top centre | inferred | - | T0 | NEW | inferred |
| P03 | Resume / Options / Quit | Buttons | quitting still shows the results page (fixed 12 Dec 2021) | - | T0 | NEW | S4 |
| P04 | Owned weapons + passives with levels | Left column | icon + level | - | T0 | NEW | inferred |
| P05 | Stats panel | Player stats list | order follows the in-game list; differences shown as +x% vs base | 26 stats in wiki order | T0 | NEW | S21,S22,S23 |
| P06 | Grim Grimoire button | Bottom right of pause | opens the evolution recipe list; undiscovered recipes as outlines | - | T0 | NEW | S32,S33 |
| P07 | Milky Way Map | Pause | zoomable map; zoom in/out since 1.12 | - | T0 | NEW | S34,S31 |
| P08 | "Show Guides" toggle | From Milky Way Map | enables the H20 arrows | - | T0 | NEW | S34 |
| P09 | Options sub-menu | From pause | see M10 | - | T0 | NEW | S12 |

### 1F. Results / game-over (R)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| R01 | Death sequence | HP ≤ 0 | inferred: player death sprite, then "Game Over" text, then results | - | T1 | NEW | inferred |
| R02 | Revival | Revival stat > 0 | inferred: revive burst instead of game over | - | T2 | NEW | S21 |
| R03 | Results header | Top left | stage name, mode, gold bonus | - | T0 | NEW | S4 |
| R04 | Summary stats | Top left | Survived time, Gold earned, Level reached, Enemies defeated | - | T0 | NEW | S4 |
| R05 | Character block | Top right | character name (+ Golden Eggs used) | - | T0 | OURS:Portrait Medallion (optional) | S4 |
| R06 | Items list | Weapons + passives with level | max level = yellow, else white | - | T0 | NEW | S4 |
| R07 | PowerUps list | Active powerups with levels | - | - | T0 | NEW | S4 |
| R08 | Pickups tally | Each pickup type × count | - | - | T0 | NEW | S4 |
| R09 | Arcanas used | List | - | - | T0 | NEW | S4 |
| R10 | Damage table | Bottom left | columns: weapon icon, Level, Damage, Time, DPS | - | T0 | NEW | S4 |
| R11 | Top damage highlight | Damage column | the single largest value is yellow | - | T0 | NEW | S4 |
| R12 | Top DPS highlight | DPS column | the single largest value is yellow | - | T0 | NEW | S4 |
| R13 | SI number format | Damage/DPS | k, M, G, T, P, E suffixes | see QA | T0 | NEW | S4,S27a |
| R14 | Arcana damage rows | Special arcanas | added rows (since 21 Jul 2022) | - | T0 | NEW | S4 |
| R15 | DONE button | Bottom | back to main menu | - | T0 | NEW | S4 |
| R16 | Unlocks toggle | Green button if ≥1 unlock | show/hide new unlocks and achievements | green | T0 | NEW | S4 |
| R17 | Time format | Survived | mm:ss | - | T0 | NEW | S4, inferred |
| R18 | Results stat count-up | Values | inferred: instant (no odometer) | - | T0 | OURS:Rolling Odometer (off) | inferred |

### 1G. Main menu and meta screens (M)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| M01 | Epilepsy warning | Boot | full-screen text before the title (since 0.2.10) | - | T0 | NEW | S31 |
| M02 | Title logo | Main menu | custom lettering, not a font | - | T0 | NEW (asset) | S14 |
| M03 | Main buttons | Centre column | Start, Quick Start, Online, Adventures, Credits, Bestiary, Collection, Power Up, Unlocks, Secrets (top-bottom, left-right) | - | T0 | NEW | S13 |
| M04 | Green buttons | POWER UP, ADVENTURES, DLC STORE | green fill; others blue | - | T0 | NEW | S13 |
| M05 | Small lowercase buttons | Quick Start, Credits | shorter height, lowercase label | - | T0 | NEW | S13 |
| M06 | Locked buttons | Bestiary (Ars Gouda), Secrets (Morbane), Quick Start, Adventures | hidden or greyed until unlocked | - | T0 | NEW | S13 |
| M07 | Top bar | Poncle Account, Quit, Options | - | - | T0 | NEW | S13 |
| M08 | Version label | Corner | "RELEASE" removed in 1.6.0 | - | T0 | NEW | S13 |
| M09 | Gold counter (menus) | Top right of meta screens | coin icon + amount | - | T0 | OURS:Rolling Odometer (flat) | S11,S35 |
| M10 | Options menu | Sections | Favourites, Display (V-Sync, Borders, Flashing VFX, Disable Blood, Weapons ScreenShake, Pixel Font, Defanged), Sound, Gameplay (Damage Numbers, Stage Progression, Invert Stages, Joystick), Account | - | T0 | NEW | S12 |
| M11 | Character select grid | Owned tiles: name, sprite, start weapon | - | - | T0 | NEW | S10 |
| M12 | Tile states | bought / unlocked-not-bought / locked | white name + sprite / grey name + black silhouette / blue-grey tile, translucent | - | T0 | NEW | S10 |
| M13 | Character info panel | Bottom | name, sprite, start weapon, description, favourite, skin | - | T0 | OURS:Portrait Medallion | S10 |
| M14 | Character stats panel | Left | stats + max weapons + Character Setup button | - | T0 | NEW | S10 |
| M15 | Completed-stages panel | Right | stage checkmarks | - | T0 | NEW | S10 |
| M16 | FILTER button | Top right, blue | filter/sort | - | T0 | NEW | S10 |
| M17 | Setup dialog / CLEAR | red CLEAR | - | - | T0 | NEW | S10 |
| M18 | Buy character | Unlocked-not-bought | gold cost | - | T0 | NEW | S10, inferred |
| M19 | Stage select list | Stage thumbnails + info | "!" left of the thumbnail if a relic is uncollected | - | T0 | NEW | S36 |
| M20 | Mode toggles | Hyper, Hurry, Arcanas, Limit Break, Inverse, Endless | checkbox window separate from the stage modifiers | - | T0 | NEW | S36 |
| M21 | PowerUp grid | Squares: name top, icon centre, rank checkboxes | box count = max rank | - | T0 | NEW | S11 |
| M22 | PowerUp tile colours | grey = not maxed; yellowish = maxed+active; dark grey = maxed+inactive | - | - | T0 | NEW | S11 |
| M23 | PowerUp detail panel | Bottom | buy/upgrade, then activate toggle (not for Reroll/Skip/Banish/Seal) | - | T0 | NEW | S11 |
| M24 | PowerUp price | Detail | Price = Initial*(1+bought) + (TotalBought>0 ? floor(20*1.1^TotalBought) : 0) | - | T0 | NEW | S11 |
| M25 | Refund button | Blue, top bar | refunds all (slightly less, rounding) | - | T0 | NEW | S11 |
| M26 | Collection grid | Icons + names, sectioned by version | locked = "?" slot, bg colour by item type (grass = pickups, pink = relics) | - | T0 | NEW | S37 |
| M27 | Collection info panel | Click | locked: "unknown / not yet found" | - | T0 | NEW | S37 |
| M28 | Bestiary header | Count found / total, red BACK, gold | - | - | T0 | NEW | S38 |
| M29 | Bestiary list | Left, scrollable, numbered | yellow names = tied to a character unlock; selected = yellowish highlight + left arrow; unseen = dashes | - | T0 | NEW | S38 |
| M30 | Bestiary detail | Right | kills, sprite on a stage bg, description, HP/Power/Speed, resistances, skills, stages; unseen = "?" on a Mad Forest bg | - | T0 | NEW | S38 |
| M31 | Unlocks menu | List/grid of achievements | icon, name, description, reward | - | T0 | NEW | S39, inferred |
| M32 | Merchant | "Interested in this?" | rows: icon, name, type, italic desc, cost + coin | - | T0 | NEW | S40 |
| M33 | Secrets menu | Text entry for codes | - | - | T0 | NEW | S13, inferred |
| M34 | Credits roll | Credits | scrolling text | 20-30 px/s inferred | T2 | NEW | S13 |

### 1H. Popups and unlock notifications (U)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| U01 | Relic pickup popup | Relic touched | icon, name, description, unlock line; queued one at a time (low-confidence summary) | - | T0 | NEW | S15 |
| U02 | Relic arrow removal | After pickup | green arrow removed | - | T0 | NEW | S15 |
| U03 | In-run unlock toast | Achievement completed mid-run | inferred: small banner; real VS shows unlocks on the results screen (R16) | - | T1 | NEW | S4, inferred |
| U04 | Coffin character unlock | Coffin touched | inferred: panel with character + "unlocked" | - | T0 | NEW | inferred |
| U05 | New unlock badge | Menu buttons with new content | inferred: "!" badge | - | T1 | NEW | inferred |
| U06 | Typewriter text | Popups | not original; optional | - | T2 | OURS:Typewriter Reveal (optional) | - |

### 1I. Fonts and text (F)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| F01 | Default UI font | All UI text | Courier-style serif monospace (Phaser default carried into Unity) | single blog source | T0 | NEW | S41 |
| F02 | Pixel Font option | Since 1.6.0 | alternate bitmap pixel font | - | T0 | NEW | S12,S31 |
| F03 | Text outline | All HUD text | 1 px black outline (8-direction) behind white text | 1 px @ 1x | T0 | NEW | inferred |
| F04 | Integer scaling | Bitmap text | scale by 2/3/4 only; separate bitmap per size | - | T0 | NEW | S42 |
| F05 | Nearest-neighbour | Sprites + pixel font | point filtering; for Roblox use ResampleMode=Pixelated | - | T0 | NEW | S42,S43 |
| F06 | Title sizes | Screen titles | ~2x body | inferred | T0 | NEW | inferred |
| F07 | Highlight text | Max level / top values | yellow | - | T0 | NEW | S4 |
| F08 | Unlock-related names | Bestiary | yellow | - | T0 | NEW | S38 |
| F09 | Disabled text | Locked | grey / translucent | - | T0 | NEW | S10 |
| F10 | SI suffix rendering | Big numbers | 3 significant digits + suffix | - | T0 | NEW | S4 |

### 1J. Palette tokens (K)

| id | name | usage | value | src |
|---|---|---|---|---|
| K01 | xp.fill | XP bar | blue (hex inferred #3050F8) | S2 |
| K02 | hp.fill | Player HP | red (#E01010 inferred) | inferred |
| K03 | text.primary | Default | #FFFFFF | S4 |
| K04 | text.highlight | Max / top / unlock-tied | yellow (#FFD800 inferred) | S4,S38 |
| K05 | text.disabled | Locked | grey | S10 |
| K06 | btn.green | Power Up/Adventures/unlocks toggle | green | S13,S4 |
| K07 | btn.blue | Default buttons, FILTER, Refund | blue | S10,S11,S13 |
| K08 | btn.red | BACK, CLEAR | red | S10,S38 |
| K09 | tile.maxedActive | PowerUp | yellowish | S11 |
| K10 | tile.maxedInactive | PowerUp | dark grey | S11 |
| K11 | tile.locked | Char select | blue-grey | S10 |
| K12 | chest.arcana | Arcana chest/arrow | purple | S9 |
| K13 | arrow.chest | Normal chest arrow | yellow/gold | S9 |
| K14 | arrow.relic | Relic arrow | green | S15 |
| K15 | freeze.tint | Orologion | blue | S5 |
| K16 | dim | Overlay | #000 @ 0.5-0.6 | inferred |
| K17 | panel.bg | Menus | dark navy/purple, light border | inferred |
| K18 | gem.blue/green/red | Gem rain | blue ≤2 XP, green ≤9, red more | S19 |

### 1K. Screen-wide FX and transitions (X)

| id | name | usage | algorithm | params | tier | covered | src |
|---|---|---|---|---|---|---|---|
| X01 | Orologion freeze ring | Orologion pickup | blue ring spinning around the player; holds 10 s, then fades; enemies resume when the fade ends | 10 s + fade | T3 | NEW | S5,S5a |
| X02 | Frozen enemy tint | Orologion | multiply enemy sprites blue; new spawns frozen too | - | T3 | NEW | S5 |
| X03 | No grey screen | Task brief said "grey" | sources say blue tint, not a grey full screen. Do not make it grey | - | - | correction | S5,S5a |
| X04 | Rosary clear | Rosary pickup | kills all on-screen enemies; flash colour/duration not documented | inferred white flash ~0.1-0.2 s | T3 | NEW | S44 |
| X05 | Nduja / Vacuum etc. | Pickups | not UI; listed for layering | - | - | n/a | - |
| X06 | Flashing VFX toggle | Option | when OFF, suppress all X full-screen flashes and strobe | global | - | NEW | S12 |
| X07 | Epilepsy-level strobe | Late game | lots of flashing; ship with the warning (M01) | - | - | NEW | S29,S31 |
| X08 | Weapons ScreenShake toggle | Option | camera shake on some weapons; obey the toggle | - | T3 | NEW | S12 |
| X09 | Player hurt feedback | On hit | inferred: brief red tint on the player sprite; no full-screen flash confirmed | ~0.1 s, i-frames 240 ms base | T3 | NEW | S21 (i-frame), inferred |
| X10 | Enemy hit flash | Enemy damaged | white flash on the sprite | 1-2 frames | T3 | NEW | S29 |
| X11 | Enemy death dissolve | Kill | disintegrate | - | T2 | NEW | S29 |
| X12 | Disable Blood | Option | hide blood particles | - | - | NEW | S12 |
| X13 | Inverse visual flip | Inverse mode | stage rotated 180°; option to disable | - | T0 | NEW | S12,S36 |
| X14 | Screen transition | Menu ↔ run | inferred: hard cut or short black fade | ≤0.3 s inferred | T2 | NEW | inferred |
| X15 | Level-up open/close | Pause in/out | inferred: instant dim on/off | - | T0 | NEW | inferred |
| X16 | Chest flash | Reel stop | see C06 | - | T3 | NEW | S9b |
| X17 | Starry Heavens | Celestial Voulge + freeze | weapon area grows while frozen (not UI) | +275% | - | n/a | S5a |
| X18 | Arcana freeze explosions | Out of Bounds | not UI | - | - | n/a | S5a |
| X19 | Gold Fever | Gilded Clover | inferred: gold-tinted HUD gold counter during the fever | - | T1 | NEW | S45 |
| X20 | Death fade | Game over | inferred: fade to black, then results | ~1 s | T2 | NEW | inferred |

Count: H30 + L25 + C15 + A10 + P9 + R18 + M34 + U6 + F10 + K18 + X20 = **195 entries** (catalog ids). Of these, 9 are skip/n-a and 186 are actionable.

---

## 2. QA pass/fail checklist

Reference frame is 1x logical px. VS renders pixel art scaled up by an integer factor; pick a base like 640x360 (inferred) and integer-scale it. Every `inferred` row stays PENDING until it is checked against a 1.16 screenshot.

### Layout
- [ ] XP bar spans 100% of the screen width, flush with the top, and is the topmost HUD element. (S2)
- [ ] The level text sits inside the right end of the XP bar. (inferred)
- [ ] The timer is horizontally centred under the XP bar. (S2, S20)
- [ ] Gold and kill counters are top right; icon left of the number; numbers right-aligned. (inferred)
- [ ] Weapon row top left, max 6; passive row directly below, max 6; same icon size; pick order kept. (S10)
- [ ] The HP bar is centred under the player sprite, follows the player each frame, and ignores the camera dim. (inferred)
- [ ] Level-up: 3 cards (4 with the Luck proc). Reroll/Skip/Banish are hidden when their PowerUp rank is 0. (S6)
- [ ] Results: header and summary stats top left, character top right, damage table bottom left, DONE at the bottom. (S4)
- [ ] PowerUp tile: name top, icon centre, checkbox count equals max rank. (S11)
- [ ] Bestiary: list left and detail right; the selected row has a highlight and a left arrow. (S38)
- [ ] Every screen fits at phone width (Roblox mobile) with no horizontal scroll; use the portrait results split into 2 pages as VS mobile does. (S4)

### Timings
- [ ] The world is fully paused (no enemy motion, no timer increment) during level-up, chest, pause and arcana screens. (S6, S9)
- [ ] The timer increments exactly once per second of unpaused time. (S20)
- [ ] Orologion: the freeze holds 10.0 s, then the ring fades; enemies move only after the fade completes. (S5)
- [ ] Chests: the first 6 chests can't be skipped (1-1-3-1-1-5); after that, 1 and 3 item chests can be skipped with Esc/RMB/B. (S9)
- [ ] The DONE button delay is shorter on 1-item chests than on 3/5-item chests. (S9b)
- [ ] Multiple level-ups from one pickup open the menu that many times, one after another. (inferred)
- [ ] Damage numbers live ≤0.6 s and don't block input. (inferred)
- [ ] Player i-frames are 240 ms at base; any hurt tint lasts no longer than the i-frames. (S21)

### Colours
- [ ] The XP fill is blue and the player HP fill is red. (S2 / inferred)
- [ ] Results: exactly one yellow cell in the Damage column and one in the DPS column; max-level items are yellow, others white. (S4)
- [ ] PowerUp tiles: grey / yellowish / dark grey states are correct. (S11)
- [ ] Char-select: locked tiles blue-grey and translucent; unbought tiles show a black silhouette and grey name. (S10)
- [ ] Arcana chest and its arrow are purple; normal chest arrows yellow/gold; relic arrows green. (S9, S15)
- [ ] The Orologion tint is BLUE, not grey. (S5)
- [ ] Main menu: only POWER UP, ADVENTURES and DLC STORE are green. (S13)
- [ ] With Flashing VFX OFF, no full-screen alpha change > 20% inside 0.33 s (WCAG 2.3.1 three-flash rule, inferred threshold). (S12)

### Text
- [ ] All HUD text has a 1 px black outline and stays readable over the white flash. (inferred)
- [ ] Number format: below 1000 shows the integer; then k/M/G/T/P/E with ≤3 significant digits (e.g. 2.9G). (S4, S27a)
- [ ] Time format is mm:ss with zero padding; ≥60 minutes is not expected in the base game (verify). (S20)
- [ ] Pixel Font toggle switches every label, with no layout overflow at either font. (S12)
- [ ] Text uses integer scale only (no 1.5x blur). (S42)

---

## 3. Visual hierarchy rules for the UI layer

1. **Z-order, top to bottom:** system overlays (epilepsy warning, transitions) > modal panel (level-up / chest / arcana / pause) > modal dim > full-screen FX (flash, freeze tint) > screen HUD (XP bar, timer, counters, slots) > world-anchored UI (player HP bar, damage numbers, off-screen arrows) > world.
2. **One modal at a time.** Modals queue in a fixed order: chest > level-up > arcana. Inferred: VS shows level-ups that queue during a chest after it. Never stack two dims.
3. **Gem rain sits between the dim and the panel,** so it reads as celebration without covering the text. (S6)
4. **Flat over fancy.** Original VS bars and counters are flat and update instantly. Run our sand/wave/odometer/typewriter algorithms in a "1:1" preset (simulation off). Fancy is opt-in only.
5. **Yellow means "best or special".** Use it only for max-level items, top damage and top DPS, unlock-tied names and New! markers. Never use it for decoration. (S4, S38)
6. **Button colour carries meaning.** Green = progression/meta spend or bonus (Power Up, unlocks toggle). Blue = neutral or utility (Filter, Refund, default). Red = back or destructive (BACK, CLEAR). (S10, S11, S13, S38)
7. **The HUD never moves.** The HUD isn't affected by screen shake. Shake applies to the world camera only. (inferred; respect S12 toggle)
8. **Accessibility gates.** Every full-screen flash or strobe goes through `FlashingVFX`; every shake goes through `WeaponsScreenShake`; damage numbers go through `DamageNumbers`. (S12)
9. **Pixel discipline.** Use one base resolution, integer scale only, Pixelated resampling, and 1 px outlines. No anti-aliased UIStroke wider than 1 logical px. (S42, S43)
10. **The world-anchored HP bar stays under the player sprite.** Inferred: it draws above enemies so it never gets hidden.
11. **Text density.** Level-up cards show name, level/New and one description. The full stats belong in a side panel, never on the cards. (S21)
12. **The Figma rule from CLAUDE.md also applies.** If we mock these screens in Figma, duplicate the real UI v2 frames and never redraw them from scratch.

---

## 4. References

Fetched and used:
- S1 https://steamcommunity.com/app/1794680/discussions/0/3276941718958957262 (+ /3765605292808045559)
- S2 https://www.thevibes.com/articles/lifestyles/53373/vampire-survivors-an-escalating-dopamine-rush-disguised-as-a-retro-game
- S3 https://primagames.com/tips/how-to-unlock-seal-iii-in-vampire-survivors
- S4 https://vampire.survivors.wiki/w/Results
- S5 https://vampire.survivors.wiki/w/Orologion
- S5a https://rogueranker.com/starry-heavens-vampire-survivors/
- S6 https://vampire.survivors.wiki/w/Level_up
- S7 https://vampire.survivors.wiki/w/Arcanas
- S7a https://vampire.survivors.wiki/w/Preserve
- S8 https://steamcommunity.com/app/1794680/discussions/0/3201496916541636054
- S9 https://vampire.survivors.wiki/w/Treasure_Chest (S9b = same page, 1.6.0 changelog section)
- S10 https://vampire.survivors.wiki/w/Characters
- S11 https://vampire.survivors.wiki/w/PowerUps
- S12 https://vampire.survivors.wiki/w/Options
- S13 https://vampire.survivors.wiki/w/Main_Menu
- S14 https://madegooddesigns.com/vampire-survivors-font/ (search snippet; fetch 403)
- S15 https://vampire.survivors.wiki/w/Relics (summary low-confidence)
- S16 https://vampire.survivors.wiki/w/Version_history
- S17 https://vampire-survivors.fandom.com/wiki/Stages (snippet)
- S18 https://steamcommunity.com/app/1794680/discussions/0/3830916907601747839, https://primagames.com/tips/how-to-limit-break-in-vampire-survivors
- S19 https://vampire.survivors.wiki/w/Experience
- S20 https://lemmy.korz.dev/post/1032282/1685474
- S21 https://vampire.survivors.wiki/w/Stats
- S22 https://vampire.survivors.wiki/w/Health
- S23 https://vampire.survivors.wiki/w/Curse, https://vampire.survivors.wiki/w/Damage
- S24 https://vampire.survivors.wiki/w/Gatti_Amari
- S25 https://steamcommunity.com/app/1794680/discussions/0/3392911947302462433
- S26 https://vampire.survivors.wiki/w/Merchant (arrow colours via S9)
- S27 https://steamcommunity.com/app/1794680/discussions/0/3194745319522730122
- S27a https://steamcommunity.com/app/1794680/discussions/0/3194745319522985116
- S28 https://vampire-survivors.fandom.com/wiki/Victory_Sword (snippet)
- S29 https://mechanicsofmagic.com/?p=31948
- S30 https://rogueranker.com/vampire-survivors-guide/ (evolution-in-level-up claim, low trust)
- S31 https://vampire.survivors.wiki/w/Version_history (0.2.10, 0.5.1, 0.11.0, 1.6.0, 1.12 entries)
- S32 https://rogueranker.com/vampire-survivors-grimoire/
- S33 https://vampire.survivors.wiki/w/Relic
- S34 https://primagames.com/tips/where-to-find-the-milk-way-map-in-vampire-survivors, https://rogueranker.com/milky-way-map-vampire-survivors/
- S35 https://vampire.survivors.wiki/w/Bestiary (gold counter)
- S36 https://vampire.survivors.wiki/w/Stage_selection
- S37 https://vampire.survivors.wiki/w/Collection
- S38 https://vampire.survivors.wiki/w/Bestiary
- S39 https://vampire.survivors.wiki/w/Achievements, https://vampire.survivors.wiki/w/Unlocks
- S40 https://vampire.survivors.wiki/w/Merchant
- S41 https://jslegenddev.substack.com/p/why-text-in-vampire-survivors-used (search snippet; fetch 404)
- S42 https://phaser.discourse.group/t/text-becomes-blurry-on-scaling/1367, https://phaser.io/devlogs/16
- S43 https://html5gamedevs.com/topic/26872-pixelated-bitmaptext
- S44 https://vampire.survivors.wiki/w/Rosary
- S45 https://vampire-survivors.fandom.com/wiki/Gilded_Clover (snippet)
- S46 https://gamingonlinux.com/2023/07/vampire-survivors-switching-to-new-game-engine-on-august-17 (Phaser→Unity in 1.6.0, 17 Aug 2023)
- S47 https://gamingonlinux.com/2022/10/vampire-survivors-started-a-craze-and-the-10-release-is-out-now
- S48 https://vampire-survivors.fandom.com/wiki/Freeze (snippet only)
- S49 https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles (structure only: Data/<DLC>/, Translations/)
- S50 https://www.pocketgamer.com/vampire-survivors/guide (snippet)
- S51 https://apps.roytang.net/2023/01/vampire-survivors/ (snippet, chest jingle)
- S52 https://tvtropes.org/pmwiki/pmwiki.php/Main/FlashOfPain (genre convention only)

### Blocked or failed sources
- vampire-survivors.fandom.com: HTTP 402 on every fetch (Level_up, Damage_numbers, Freeze). Snippets only.
- madegooddesigns.com: 403. jslegenddev.substack.com: 404 on the fetched URL.
- primagames.com v1.2 patch notes: 403.
- api.github.com for SurvivatonsAndMore/VampireSurvivorsFiles: 403 (repo not enabled in this session). Only the HTML tree was readable. The Translations/ folder may hold the exact UI strings ("Level Up", "New!", "Reroll"…) and should be pulled next, via add_repo or raw.githubusercontent.
- vampire.survivors.wiki/w/Pause_menu and /w/Pause: 404 (no page).
- YouTube / Reddit: not fetched (no direct pages returned). Pixel sizes and timings need frame captures from a 1.16 video.

### Top open items (to resolve by screenshot or video capture)
1. Exact HUD px layout and base resolution (H01-H15).
2. Level-up card visuals: New! colour, evolution icon placement, button colours (L09, L11, L25).
3. Damage number colours and crit style (H25, H27).
4. Player hurt feedback and Rosary flash (X04, X09).
5. Exact UI strings from Translations/.
