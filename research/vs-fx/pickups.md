# Vampire Survivors (base game, v1.16): pickup and reward FX catalog

Scope: Vampire Survivors base game only, rebuilt as a 2D pixel game in Roblox Luau. Covers XP gems, magnet/vacuum pull, gold, floor chicken, the Rosary/Orologion/Nduja/Gilded Clover screen effects, light sources, the treasure chest sequence, relics and magnet-radius visuals.

**Rules for numbers.** Every number either has a source tag `[Sx]` or is marked `inferred`. An inferred number is a tuning starting point for our remake. It is not a claim about the original game. Where the original timing is unknown, the entry says `timing: unknown, inferred`.

**Column key.**
- **fps tier.** `A` = per-frame tween at 60 Hz (smooth motion, UI). `B` = sprite-flip animation at 8-12 fps (the game's pixel-art cadence). `C` = event or one-shot, no animation loop.
- **Covered by.** One of our existing ~89 effect algorithms (named the way the brief names them), or `NEW` if nothing we have covers it. Names other than the ones the brief listed (Coin Fountain, Confetti Burst, Sparkle Poof, Sprite Stack Chest, Rolling Odometer, Palette Cycling, God Rays) are given as generic families such as "Tween Scale Pop". Check them against our registry.

## Sources

| id | URL | notes |
|---|---|---|
| S1 | https://vampire.survivors.wiki/w/Experience_Gem | raw wikitext fetched |
| S2 | https://vampire.survivors.wiki/w/Treasure_Chest | raw fetched, includes v1.6.0 chest-UI changelog |
| S3 | https://vampire.survivors.wiki/w/Light_source | raw fetched |
| S4 | https://vampire.survivors.wiki/w/Rosary | raw fetched |
| S5 | https://vampire.survivors.wiki/w/Orologion | raw fetched |
| S6 | https://vampire.survivors.wiki/w/Nduja_Fritta_Tanto | raw fetched |
| S7 | https://vampire.survivors.wiki/w/Vacuum | raw fetched |
| S8 | https://vampire.survivors.wiki/w/Floor_Chicken | raw fetched |
| S9 | https://vampire.survivors.wiki/w/Magnet | raw fetched |
| S10 | https://vampire.survivors.wiki/w/Attractorb | raw fetched |
| S11 | https://vampire.survivors.wiki/w/Pickups | raw fetched |
| S12 | https://vampire.survivors.wiki/w/Relics | raw fetched |
| S13 | https://vampire.survivors.wiki/w/Little_Clover | raw fetched |
| S14 | https://vampire.survivors.wiki/w/Treasure_Found_jingle | duration 0:03 |
| S15 | https://vampire.survivors.wiki/w/Treasure_A_jingle | duration 0:10 |
| S16 | https://vampire.survivors.wiki/w/Treasure_C_jingle | duration 0:19 |
| S17 | https://vampire.survivors.wiki/w/Freeze | raw fetched |
| S18 | https://vampire.survivors.wiki/w/Gilded_Clover | Gold Fever rules |
| S19 | https://vampire.survivors.wiki/w/Lavatrix_Machina | raw fetched |
| S20 | https://vampire.survivors.wiki/w/Level_up | raw fetched |
| S21 | https://vampire-survivors.fandom.com/wiki/Experience_Gem | via search summary |
| S22 | https://steamcommunity.com/app/1794680/discussions/0/3201496916536108528 | via search summary (gem merge) |
| S23 | https://steamcommunity.com/app/1794680/discussions/0/4650551739541818271 | via search summary |
| S24 | https://steamcommunity.com/app/1794680/discussions/0/3201493834358639726 | via search summary (merged gem gives 3-5 levels) |
| S25 | https://steamcommunity.com/app/1794680/discussions/0/7075781999148704534 | via search summary |
| S26 | https://steamcommunity.com/app/1794680/discussions/0/3470612993475129925 | via search summary (skip the reels with Space or right-click) |
| S27 | https://primagames.com/tips/vampire-survivors-v1-2-patch-notes-quality-of-life-update-december-15th-2022 | coin-only chest overworld anim |
| S28 | https://www.youtube.com/watch?v=vZql1Y1IP3s | Treasure A jingle audio (linked from S15; not watched) |
| S29 | https://www.youtube.com/watch?v=_Aye5U-uo04 | Treasure C jingle audio (linked from S16; not watched) |
| S30 | https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/ | game data v1.16 (Item.json weights) |
| S31 | origin/claude/vampire-survivors-mechanics-y1l323:research/vs/pickups_meta.json | our earlier data (weights, goldFeverMs) |
| S32 | https://store.steampowered.com/news/app/1794680/view/3131696199131643254 | relic roadmap (cited by S12) |
| S33 | https://www.thevibes.com/articles/lifestyles/53373/vampire-survivors-an-escalating-dopamine-rush-disguised-as-a-retro-game | review, general feel |
| S34 | https://vampire.survivors.wiki/w/Level_up (level-up invulnerability line) | same page as S20, separate claim |

Blocked or unusable: youtube.com and reddit.com only return 301 to curl, so no video frame timing could be gathered. Steam threads were read only through search summaries. The fandom wiki was not fetched directly. Frame-exact animation timings for the chest UI are **not published anywhere we could reach**, so all chest timings below are `inferred` and need checking against footage by eye.

Key facts that hold up the catalog (all cited):
- Gem tiers: blue up to 2 XP, green up to 9 XP, red anything beyond [S1].
- More than 400 gems on the ground: new XP goes into one red gem [S1][S21]. Players report "about 500" [S22] (a conflict; we use 400).
- Gems never expire and follow the player "a dozen or so screen lengths" [S22/S24 summary].
- Magnet base radius is 30. PowerUp multiplier is x1.25 per rank, max 2 ranks. Attractorb levels 1-3 give 1.5x, 1.995x and 2.49375x, up to 3.98x at level 5 [S9][S10].
- Light sources have 10 HP and drop one pickup. Sprites vary per stage (brazier, candelabra, lamppost, blue brazier) [S3]. Drop weights: Coin 50, Chicken 12, Bag 10 ... [S30][S31].
- Orologion: spinning blue ring, enemies tinted blue, freeze lasts 10 s, then the ring "begins to fade". Enemies stay pushable. Freezes new spawns too [S5][S17].
- Rosary kills every enemy on screen [S4]. Vacuum pulls every gem, "takes time to reach" [S7]. Nduja is a fire cone in the facing direction for 10 s; the flame grows as it travels [S6].
- Gilded Clover: gathers all gold and starts a 10 s Gold Fever. Each kill has a 75% chance to drop a 0.5 coin. Pickups extend the fever by +0.5/+5/+10 s, capped at 10 s [S18].
- Chest: 1/3/5 items. Gold 100-200 / 300-600 / 500-1000. Jingles: Found (3 s) then A (1 item, 10 s), B (3 items) or C (5 items, 19 s) [S2][S14-16]. The first 6 chests follow the order 1-1-3-1-1-5 and cannot be skipped [S2]. Chest UI elements named in the v1.6.0 changelog: intro blast, intro chest anim, reels, curved ribbon (lvl 3), bubbles fading in, stars behind weapon reveal, background circle (shape/speed/alpha), flash, ring scale, fireworks behind chests, coin particles, coin count-up that scales in, coin value pulse, Open/Done buttons rotating in and out with separate arrows [S2]. Coin-only chests play a short overworld anim with the amount [S2][S27]. Silver chests can evolve, bronze chests usually cannot [S2].
- Relics: a green off-screen arrow points to each one until it is collected [S12].

## 1. Effect catalog

### 1.1 XP gems (G)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| G01 | Gem tier select | choose the sprite from the XP value | `v<=2 blue; v<=9 green; else red` | thresholds 2/9 | C | NEW (logic) | S1 |
| G02 | Gem spawn at death | gem appears at the enemy's death position | spawn at the corpse position, no scatter | offset 0 (inferred) | C | NEW | inferred |
| G03 | Gem spawn pop | short scale-in on spawn | scale 0.6 to 1.0, outBack | 0.12 s (inferred) | A | Tween Scale Pop | inferred |
| G04 | Gem idle glint | idle sprite shimmer | 2-4 frame flip loop with a phase offset per gem | 8 fps (inferred) | B | Palette Cycling | inferred |
| G05 | Gem idle stillness | gems do not bob (static pixel sprite) | none | - | - | n/a | inferred from S1 sprites |
| G06 | Gem cap counter | count gems on the ground | keep an O(1) counter | cap 400 | C | NEW | S1 |
| G07 | Overflow red gem | XP above the cap goes into one red gem | `if count>=400: red.value+=xp` (spawn once, then accumulate) | cap 400 | C | NEW | S1,S21 |
| G08 | Red gem merge pulse | feedback while value is added | scale 1.0 to 1.15 to 1.0 per add, throttled | max 1 per 0.2 s (inferred) | A | Tween Scale Pop | inferred |
| G09 | Big red gem sprite | merged gem is visually the same red tier | use the red sprite, no special size (unverified) | - | C | n/a | S1 (inferred) |
| G10 | Multi-level payout | one merged gem can trigger several level-ups in a row | queue level-ups and show each screen in turn | 3-5 reported | C | NEW | S24 |
| G11 | Gem persistence | gems never despawn | no TTL | - | C | n/a | S22 |
| G12 | Far-gem follow | far-off gems trail the player | when beyond N screens, reposition near the edge (implementation guess) | ~12 screens (reported) | C | NEW | S22 summary, inferred |
| G13 | Gem pool | object pool so 400+ sprites stay cheap | preallocate 450 | 450 (inferred) | C | NEW (infra) | inferred |
| G14 | Gem off-screen cull | skip rendering outside the camera | AABB check | margin 32 px (inferred) | C | NEW (infra) | inferred |
| G15 | Magnet enter | gem starts homing when inside the magnet radius | `dist < magnet` sets state=homing | base 30 | C | NEW | S9 |
| G16 | Homing accel | gem flies to the player, speeding up | `v += a*dt; pos += dir*v*dt`; never overshoots | a=?, v0 small (inferred) | A | NEW (Magnet Pull) | inferred |
| G17 | Homing initial kick-back | small hop away before the pull (Castlevania-like) | opening velocity reversed for ~0.1 s | unverified | A | NEW | inferred, verify |
| G18 | Collect snap | gem is absorbed when within a few px | `dist<4` triggers collect | 4 px (inferred) | C | NEW | inferred |
| G19 | Collect sound tick | pickup blip per gem | throttled one-shot with slight pitch variation | max 1 per 30 ms (inferred) | C | NEW (audio) | inferred |
| G20 | XP bar fill | top HUD bar fills toward the next level | lerp the fill width | 0.1 s (inferred) | A | Rolling Odometer (bar variant) | S20 |
| G21 | XP bar full flash | bar flashes on level-up | white flash 2 frames | inferred | B | Sparkle Poof | inferred |
| G22 | Level-up pause | game pauses and the 3-4 option menu opens | timescale 0 | - | C | NEW | S20 |
| G23 | Post-level invuln | brief invulnerability after choosing | i-frames | duration unknown | C | NEW | S34 |
| G24 | Green gem variant | mid tier | same as G04 with the green palette | - | B | Palette Cycling | S1 |
| G25 | Red gem variant | top tier | same with the red palette | - | B | Palette Cycling | S1 |
| G26 | Gem depth sort | gems draw under enemies and the player | z-layer = floor+1 | - | C | n/a | inferred |
| G27 | Growth multiplier display | none (value only) | `xp*growth` | - | C | n/a | S1 |
| G28 | Light-source gem | a gem dropped by a light source holds 50 XP | value 50, so red | 50 | C | NEW (logic) | S1 |
| G29 | Rosary/Weird Souls gem conversion | (base: a Rosary kill drops normal gems) | each killed enemy drops its normal gem | - | C | n/a | S4 |
| G30 | Gem shadow | 1-px dark drop shadow (unverified) | sprite offset (0,1), alpha 0.4 | inferred | C | NEW | inferred |

### 1.2 Magnet, vacuum and pull motion (M)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| M01 | Magnet radius calc | pickup radius | `30*(charBonus)*(1.25^rank)*attractorb` | 30; 1.25; up to 3.98 | C | NEW (logic) | S9,S10 |
| M02 | Magnet radius ring (debug/our QA) | VS draws **no** visible ring normally | optional dev overlay, dashed circle | - | A | NEW | inferred |
| M03 | Attractorb level jump | radius grows when Attractorb levels up | lerp the radius over a short time | 0.2 s (inferred) | A | NEW | S10 |
| M04 | Vacuum pickup flash | on pickup | white screen flash, low alpha | 0.1 s, a=0.3 (inferred) | A | Sparkle Poof (full-screen) | inferred |
| M05 | Vacuum global pull | every gem on the map homes in | set every gem to homing with an unlimited radius | - | A | NEW (Magnet Pull) | S7 |
| M06 | Vacuum staggered arrival | "takes time to reach" | per-gem speed ramp; far gems arrive later | - | A | NEW | S7 |
| M07 | Vacuum pickup filter | vacuum ignores non-gem pickups | filter by type == GEM | - | C | n/a | S7 |
| M08 | Vacuum gem stream | a stream of gems converges on the player | emerges from M05 (no extra particle) | - | A | NEW | S7 |
| M09 | Collect chime cascade | many pickup blips in a row | global blip throttle, pitch rising slightly | inferred | C | NEW (audio) | inferred |
| M10 | Vacuum sfx | unique pickup sound | one-shot | - | C | n/a | S7 (audio fix note) |
| M11 | Map icon for vacuum | small minimap icon | static icon | - | C | NEW | S5/S7 changelog |
| M12 | Gilded Clover gold pull | every gold pickup homes in | same as M05, gold types only | - | A | NEW (Magnet Pull) | S18 |
| M13 | Chest no-attract | magnet does not pull chests | exclude TREASURE | - | C | n/a | S2 |
| M14 | Homing curve | straight line toward the player's current position | re-aim every frame | - | A | NEW | inferred |
| M15 | Homing speed cap | cap so a gem never passes through the player | `v=min(v, dist/dt)` | inferred | A | NEW | inferred |
| M16 | Pull trail | none in VS (no trails on gems) | - | - | - | n/a | inferred |
| M17 | Pickup sparkle on absorb | small sparkle at the player on collect (unverified) | 3-frame sparkle | 12 fps (inferred) | B | Sparkle Poof | inferred |
| M18 | Big-pull perf guard | 400+ simultaneous homing gems | batch-update in one loop with no per-gem tween objects | - | A | NEW (infra) | inferred |

### 1.3 Gold (C)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| C01 | Gold coin sprite | floor coin | spin flip loop | 4 frames, 8 fps (inferred) | B | NEW (Coin Spin) | S11 |
| C02 | Coin bag sprite | 10 gold | static bag | - | C | n/a | S30 |
| C03 | Rich coin bag sprite | 100 gold, level 5+ | static | - | C | n/a | S30,S31 |
| C04 | Coin pickup | +1 x Greed | add to the run gold | 1 | C | NEW (logic) | S31 |
| C05 | Bag pickup | +10 x Greed | - | 10 | C | n/a | S31 |
| C06 | Rich bag pickup | +100 x Greed | - | 100 | C | n/a | S31 |
| C07 | Big Coin Bag (level-up/chest) | +25, replaces maxed items | - | 25 | C | n/a | S2 |
| C08 | HUD gold counter tick | top-right gold number | count up to the target | 0.25 s (inferred) | A | Rolling Odometer | inferred |
| C09 | HUD gold bump | counter scale pop on gain | 1 to 1.2 to 1 | 0.1 s (inferred) | A | Tween Scale Pop | inferred |
| C10 | Gold Fever start | 10 s fever | timer = 10 | 10 s | C | NEW | S18 |
| C11 | Gold Fever kill coin | 75% chance per kill of a 0.5 coin | roll per kill | 0.75; 0.5 | C | NEW | S18 |
| C12 | Fever extend | +0.5 / +5 / +10 s per coin/bag/rich, kill coins +0.01, cap 10 | clamp | see src | C | NEW | S18 |
| C13 | Fever decay halved under Orologion | decay x0.5 | - | 0.5 | C | NEW | S5,S18 |
| C14 | Fever HUD timer | visual countdown (form unverified) | bar or tint pulse | inferred | A | NEW | inferred |
| C15 | Fever coin shower | many coins popping from kills | coin spawns with a small hop arc | hop 8 px, 0.25 s (inferred) | A | Coin Fountain | inferred |
| C16 | Coin pickup sfx | classic coin blip | throttled | - | C | n/a | inferred |
| C17 | Gold fever ms data | data: goldFeverMs on COIN = 500 | matches +0.5 s | 500 ms | C | n/a | S31 |
| C18 | Coin stack on chest gold | coin-only chest overworld anim | coin icon rises with a number above the player | ~1 s (inferred) | A | Coin Fountain + Rolling Odometer | S2,S27 |

### 1.4 Floor chicken and heal (H)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| H01 | Chicken sprite | static roast sprite | static | - | C | n/a | S8 |
| H02 | Chicken heal | +30 HP | clamp to max | 30 | C | NEW (logic) | S8 |
| H03 | HP bar refill | under-player HP bar grows | lerp | 0.15 s (inferred) | A | NEW | inferred |
| H04 | Heal tint flash | player flashes green or white (unverified) | 2-frame tint | inferred | B | NEW | inferred |
| H05 | Chicken map icon | minimap icon | static | - | C | NEW | S5 changelog |
| H06 | Chicken as level option | offered when everything is maxed | UI card | - | C | n/a | S8,S20 |
| H07 | Chicken pickup sfx | eating sound | one-shot | - | C | n/a | inferred |
| H08 | Chicken magnet behaviour | pulled like other pickups by the magnet | homing | - | A | NEW (Magnet Pull) | S11 |

### 1.5 Screen-effect pickups (R = Rosary, O = Orologion, N = Nduja, L = Clover)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| R01 | Rosary pickup flash | full-screen white flash | alpha 1 to 0 | 0.3 s (inferred) | A | NEW (Screen Flash) | inferred |
| R02 | Rosary mass kill | kill every on-screen non-immune enemy | iterate the camera rect | - | C | NEW | S4 |
| R03 | Rosary staggered deaths | death effects on many enemies at once | normal death anim per enemy, frame spread | spread 0-3 frames (inferred) | B | NEW | inferred |
| R04 | Rosary gem rain | every killed enemy drops a gem (subject to cap) | G02 per enemy | - | C | n/a | S4,S1 |
| R05 | Rosary immunity | bosses/some enemies resist | flag check | - | C | n/a | S4 |
| R06 | Rosary sfx | big holy sound | one-shot | - | C | n/a | S4 |
| R07 | Rosary map icon | - | - | - | C | NEW | S4 |
| R08 | Rosary item glow | pickup sprite glow anim | flip loop | inferred 8 fps | B | Palette Cycling | S4 (Animated-Rosary.gif) |
| O01 | Orologion spinning ring | blue ring spins around the player | ring sprite, rotation += w*dt | w ~ 180 deg/s (inferred) | A | NEW (Spin Ring) | S5 |
| O02 | Orologion ring expand-in | ring grows at the start (unverified) | scale 0 to 1 | 0.2 s (inferred) | A | Tween Scale Pop | inferred |
| O03 | Global freeze | all enemies frozen for 10 s | enemy.timeScale=0 | 10 s | C | NEW | S5 |
| O04 | Freeze blue tint | frozen enemies tinted blue | multiply the colour (0.5,0.7,1) | colour inferred | C | NEW (Tint) | S5,S17 |
| O05 | Spawn-while-frozen | new enemies spawn already frozen | apply on spawn | - | C | NEW | S5 |
| O06 | Push frozen | player can shove frozen enemies | separation impulse | - | A | NEW | S5,S17 |
| O07 | Frozen no damage | contact damage disabled | flag | - | C | n/a | S5 |
| O08 | Ring fade-out | after 10 s the ring fades, then enemies resume | alpha 1 to 0 then unfreeze | fade ~1 s (inferred) | A | NEW | S5 |
| O09 | Unfreeze untint | tint drops back to normal | lerp or snap | inferred snap | C | NEW | inferred |
| O10 | Orologion item glow | pickup glow anim | flip loop | inferred | B | Palette Cycling | S5 |
| O11 | Freeze resistance | some enemies ignore it | flag | - | C | n/a | S5 |
| N01 | Nduja fire cone | cones of flame in the facing direction | temp weapon: 12 projectiles, interval 0.04 s, cooldown 0.5 s | dmg 30, area 200%, speed 300%, amount 12, dur 1.0 | B | NEW (Flame Cone) | S6 |
| N02 | Flame grow | each flame grows as it travels | scale lerp over its lifetime | 1 s | A | NEW | S6 |
| N03 | Nduja duration | 10 s | timer | 10 s | C | n/a | S6 |
| N04 | Nduja stat scaling | uses player stats | multiply by might/area/etc | - | C | n/a | S6 |
| N05 | Flame frames | fire sprite flip | 3-4 frames | inferred 12 fps | B | NEW | inferred |
| N06 | Facing follow | the cone turns with the player's facing | aim = lastMoveDir | - | A | NEW | S6 |
| L01 | Little Clover pickup | +10% luck for the stage | stat add | 0.10 | C | n/a | S13 |
| L02 | Clover pickup sparkle | sparkle on pickup (unverified) | 3-frame sparkle | inferred | B | Sparkle Poof | inferred |
| L03 | Gilded Clover pickup | gathers gold and starts the fever | M12 + C10 | - | C | n/a | S18 |
| L04 | Fever screen tint | gold tint during the fever (unverified) | overlay tint alpha 0.1 | inferred | A | NEW | inferred |

### 1.6 Light sources (B)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| B01 | Brazier idle flame | animated fire | flip loop (the wiki has a .gif) | 3-4 frames, 8 fps (inferred) | B | NEW (Flame Loop) | S3 |
| B02 | Per-stage variant | brazier / candelabra / lamppost / blue brazier | sprite set by stage | 4 base-game sets | C | n/a | S3 |
| B03 | Light source HP | 10 HP | damage from weapons | 10 | C | n/a | S3 |
| B04 | Hit flash | white flash when hit | 1-2 frame white | inferred | B | NEW (Hit Flash) | inferred |
| B05 | Break burst | destroyed: small debris or flame poof | 4-6 particles plus a sprite swap | inferred | B | Sparkle Poof | inferred |
| B06 | Drop spawn | exactly one pickup spawns at its position | weighted roll | weights per S30 | C | NEW (logic) | S3,S30 |
| B07 | Drop pop | dropped item hops out | arc hop height 8, 0.25 s (inferred) | - | A | Coin Fountain (single) | inferred |
| B08 | Luck weights | luck scales every weight except coin and bag | `w*=luck` | - | C | n/a | S3,S31 |
| B09 | Level gates | Rosary 8, Orologion 4, Vacuum 12, Rich bag 5, Gilded 30 | filter | see src | C | n/a | S4,S5,S7,S18,S31 |
| B10 | Light source spawn | random spawns around the map | spawner | rate unknown | C | NEW | S3 |
| B11 | Break counter | 20 breaks unlock (an achievement) | counter | 20 | C | n/a | S3 |
| B12 | Light glow halo | soft glow under the flame (unverified) | additive radial, pulse | inferred | A | God Rays (radial variant) | inferred |
| B13 | Pickup item glow | rare pickups have a glow animation | gif loop | inferred | B | Palette Cycling | S4,S5,S7 |

### 1.7 Treasure chest, overworld (T)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| T01 | Chest drop from boss | chest spawns where the boss died | spawn at the death position | - | C | n/a | S2 |
| T02 | Chest tier sprite | bronze/silver (base); arcana/gold are not base-v1.16 base scope | sprite by tier | - | C | Sprite Stack Chest | S2 |
| T03 | Chest off-screen arrow | arrow pointing to the chest (unverified for chests; confirmed for relics) | clamp to the screen edge, rotate toward the target | inferred | A | NEW (Edge Arrow) | S12 analog |
| T04 | Chest idle bob/glint | idle shimmer | flip | inferred | B | Palette Cycling | inferred |
| T05 | Chest no-magnet | must be touched | - | - | C | n/a | S2 |
| T06 | Chest touch, pause | touch pauses the game and opens the treasure UI | timescale 0 | - | C | NEW | S2 |
| T07 | Treasure Found jingle | plays on touch | audio 3 s | 0:03 | C | NEW (audio cue) | S14 |
| T08 | Coin-only quick anim | if only coins, a short overworld anim with the amount | coin icon plus number above the player | inferred 1 s | A | Coin Fountain | S2,S27 |
| T09 | Quick Treasures toggle | late unlock, all instant | flag | - | C | n/a | S2 |
| T10 | Beginner sequence | first 6 chests are 1-1-3-1-1-5, not skippable | save counter | - | C | NEW (logic) | S2 |
| T11 | Tier roll | 5 / 3 / 1-item rolls x luck, with fallback | `chance*luck` vs rand 0-100 | e.g. 3/10/50 | C | NEW (logic) | S2 |
| T12 | Gold roll | 100-200 / 300-600 / 500-1000 x Greed | uniform int | - | C | n/a | S2 |

### 1.8 Treasure chest, UI sequence (U)
Order follows S2's v1.6.0 element list plus the jingle structure. **All timings inferred** (no reachable frame data).

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| U01 | Dim backdrop | screen darkens behind the UI | overlay alpha 0 to 0.6 | 0.2 s (inferred) | A | NEW (Fade Overlay) | inferred |
| U02 | Background circle | rotating or pulsing circle behind the chest | rotate plus alpha pulse; "shape, speed, alpha" are tuned | w ~ 30 deg/s (inferred) | A | God Rays | S2 |
| U03 | Intro blast | burst at the chest's entry | radial particle burst | 16 particles, 0.3 s (inferred) | A | Confetti Burst | S2 |
| U04 | Intro chest anim | chest drops or slides into the centre | tween position plus squash | 0.3 s (inferred) | A | Sprite Stack Chest | S2 |
| U05 | Open button rotate-in | "Open" button appears rotating | rotation -90 to 0 deg plus scale | 0.2 s (inferred) | A | NEW (Button Spin-In) | S2 |
| U06 | Arrows beside button | separate arrow sprites pointing at the button, bobbing | x oscillation | 4 px, 2 Hz (inferred) | A | NEW | S2 |
| U07 | Open button rotate-out | button rotates away on press | reverse of U05 | 0.15 s | A | NEW | S2 |
| U08 | Jingle A/B/C start | jingle by item count | 1 item: A (10 s), 3: B, 5: C (19 s) | - | C | NEW (audio) | S15,S16,S2 |
| U09 | Lid open | chest lid opens, light escapes | sprite swap plus God Rays | inferred | B | Sprite Stack Chest + God Rays | inferred |
| U10 | Flash | white flash drawn over the reels | scale-in then alpha out | 0.2 s (inferred) | A | Sparkle Poof | S2 |
| U11 | Ring scale | ring expands from the chest, then scales down | scale up, timed scale down | inferred | A | NEW (Shock Ring) | S2 |
| U12 | Coin particles | coins fountain from the chest during the reels; stop at a set time | emitter, gravity arc | rate 30/s (inferred) | A | Coin Fountain | S2 |
| U13 | Coin rain | coins falling across the screen (5-item) | spawn at the top, fall with spin | inferred | A | Coin Fountain (rain mode) | inferred |
| U14 | Reels (slot) | per-item vertical slot reel cycling item icons | scroll the icon strip, decelerate, snap to the result | spin 1.5-3 s (inferred) | A | NEW (Slot Reel) | S2,S26 |
| U15 | Reel stagger | in 3/5 item chests the reels stop one by one | per-reel stop delay | 0.3 s (inferred) | A | NEW | inferred |
| U16 | Far left/right reel sort | outer reels drawn behind | z-order | - | C | n/a | S2 |
| U17 | Reel decel ease | stop easing | outCubic plus 1-icon overshoot bounce | inferred | A | NEW | inferred |
| U18 | Reel stop tick | click sfx per icon passing (unverified) | audio | inferred | C | NEW | inferred |
| U19 | Winning pattern order (lvl 2) | 3-item chests reveal in a fixed order | order array | not published | C | NEW | S2 |
| U20 | Curved ribbon (lvl 3) | 5-item chests use a curved ribbon banner | arc layout of 5 slots | inferred | C | NEW (Arc Layout) | S2 |
| U21 | Ribbon length | ribbon is sized to the item count | per-tier length | - | C | n/a | S2 |
| U22 | Bubbles fade-in | item bubbles fade in (no pop) | alpha 0 to 1 | 0.2 s (inferred) | A | NEW | S2 |
| U23 | Stars behind reveal | star sprites behind a weapon reveal | rotating or twinkling stars | inferred | B | Sparkle Poof | S2 |
| U24 | Item reveal pop | final icon scale pop | 0.5 to 1.2 to 1 | 0.25 s (inferred) | A | Tween Scale Pop | inferred |
| U25 | Evolution reveal | evolved weapon icon with an extra glow | God Rays plus larger stars | inferred | A | God Rays | S2 (evo in silver) |
| U26 | Evolution sfx sting | extra sting on evolve (unverified) | audio | - | C | NEW | inferred |
| U27 | Fireworks (5-item) | fireworks behind the chests at the end | burst emitters at random positions | 5-8 bursts (inferred) | A | Confetti Burst | S2 |
| U28 | "Final fireworks" gate | skipping 5-item chests unlocks after you have seen them | flag | - | C | n/a | S2 |
| U29 | Coin count-up | gold number counts up, scaling in | odometer plus scale 0 to 1 | to 1 s (inferred) | A | Rolling Odometer | S2 |
| U30 | Coin value pulse | pulsing number after a delay | scale 1 to 1.1 loop | 2 Hz (inferred) | A | Tween Scale Pop (loop) | S2 |
| U31 | Coin value scale-out | number scales out on exit | scale 1 to 0 | 0.15 s | A | Tween Scale Pop | S2 |
| U32 | Info panel | item name or description panel with an icon | text panel | - | C | n/a | S2 |
| U33 | Done button rotate-in | appears after a delay (shorter delay for lvl 1/2) | rotate-in | delay inferred 0.5 s | A | NEW (Button Spin-In) | S2 |
| U34 | Skip input | Space/right-click skips the reels once allowed | jump to the end state | - | C | NEW | S2,S26 |
| U35 | Skip animation | dedicated quick skip anim | fast-forward all tweens | inferred 0.3 s | A | NEW | S2 |
| U36 | Background panel no-light (lvl1) | lvl 1 chest has no panel light-up | conditional | - | C | n/a | S2 |
| U37 | Panel light-up (lvl 2/3) | background panel brightens | alpha tween | inferred | A | NEW | S2 |
| U38 | Silver tint | silver chest palette | palette swap | - | C | Palette Cycling | S2 |
| U39 | Big Coin Bag reel icon | maxed items show as coin bags | icon swap | 25 g | C | n/a | S2 |
| U40 | Close and resume | UI closes, apply upgrades, timescale 1 | sequence | - | C | NEW | inferred |
| U41 | Music duck | stage BGM ducks under the jingle | volume 1 to 0.2 | inferred | A | NEW (audio) | inferred |
| U42 | Music sync | reel stop/reveal aligned to jingle length | schedule reveal at jingle-relative times: A 10 s, C 19 s | - | C | NEW | S15,S16 |
| U43 | Level-up badge on icon | shows item is levelled +1 (unverified) | text overlay | inferred | C | NEW | inferred |
| U44 | Same item repeated | duplicate icons allowed in 3/5 | data | - | C | n/a | S2 |

### 1.9 Relics, misc (X)

| id | name | VS usage | algorithm | params | fps | covered by | src |
|---|---|---|---|---|---|---|---|
| X01 | Relic sprite | floor item | static or glow | - | B | Palette Cycling | S12 |
| X02 | Relic green arrow | green off-screen arrow until collected | edge clamp plus rotation | colour green | A | NEW (Edge Arrow) | S12 |
| X03 | Relic touch collect | collected on touch, permanent | flag in save | - | C | n/a | S12 |
| X04 | Relic get banner | "found" popup (form unverified) | panel | inferred | A | NEW | inferred |
| X05 | Stage item pickup | passive items lying on the map | touch to collect | - | C | n/a | S10 |
| X06 | Map icons | minimap icons for Vacuum/Rosary/Orologion/Nduja/Chicken | icon layer | - | C | NEW | S5 |
| X07 | Pickup depth layer | pickups below the player and enemies | z | - | C | n/a | inferred |
| X08 | Pickup despawn | v1.6 fix: pickups despawned too quickly; pickups otherwise persist | none | - | C | n/a | S11 |
| X09 | Pixel snap | snap all pickup positions to whole px | round | - | A | NEW (infra) | inferred |
| X10 | Pickup sfx bus | throttled one-shot bus | voice cap 8 | inferred | C | NEW | inferred |

**Counts:** G30 + M18 + C18 + H8 + screen effects 33 (R8, O11, N6, L4) + B13 + T12 + U44 + X10 = **186 entries**.

## 2. QA pass/fail checklist

- [ ] Gem tier sprites follow the thresholds: XP 2 shows blue, 3-9 green, 10+ red [S1].
- [ ] With 400 gems on the ground, the next kill adds to exactly one red gem and spawns no new gem [S1].
- [ ] Collecting that red gem pays every banked XP, and several level-up screens chain in a row [S24].
- [ ] Gems never despawn, even after 30 minutes [S22].
- [ ] Magnet radius = 30 x char x 1.25^rank x Attractorb. PowerUp rank 2 with Poe's 1.25 gives 58.59 [S9].
- [ ] Homing gems never overshoot or orbit the player at any player speed.
- [ ] Vacuum pulls only gems, every gem on the map, and far gems arrive visibly later [S7].
- [ ] Chests are never pulled by the magnet [S2].
- [ ] A light source breaks after exactly 10 damage and drops exactly one pickup [S3].
- [ ] Over 10k rolls at 0 Luck, the drop distribution matches the S30 weights within 1% (coin ~62.1%) [S31].
- [ ] Level gates work: no Rosary before level 8, Orologion before 4, Vacuum before 12 [S4,S5,S7].
- [ ] Floor Chicken heals 30 and never goes above max HP [S8].
- [ ] Rosary kills everything on screen except immune enemies. Off-screen enemies survive [S4].
- [ ] Orologion: ring spins, enemies tint blue, new spawns are frozen, frozen enemies do no damage and can be pushed, the ring fades after 10 s, then enemies move [S5].
- [ ] Nduja fires for 10 s in the facing direction. The cone turns with the player and flames grow as they travel [S6].
- [ ] Gold Fever: 10 s, 75% coin-per-kill, +0.5/+5/+10 s extensions capped at 10 s, decay halved during Orologion [S18].
- [ ] HUD gold counter rolls up with no skipped final value. Gold = value x Greed.
- [ ] Chest touch: game pauses, Treasure Found jingle plays, the UI opens [S2,S14].
- [ ] Item count matches the jingle: 1 = A, 3 = B, 5 = C [S2].
- [ ] The first 6 chests in a fresh save are 1,1,3,1,1,5 and cannot be skipped [S2].
- [ ] Skip works for 1/3-item chests only after chest 6. Space/right-click skips the reels [S2,S26].
- [ ] Coin-only chests play the quick overworld anim when skipping is unlocked [S2,S27].
- [ ] 5-item chest: curved ribbon, fireworks drawn **behind** the chests, flash and ring drawn **over** the reels [S2].
- [ ] Coin count-up scales in (does not pop in). The Done button rotates in after a delay. The Open button rotates out [S2].
- [ ] Gold is in the band: 100-200 / 300-600 / 500-1000 x Greed [S2].
- [ ] An evolution only appears from evolution-capable (silver) chests, at most one per chest by default [S2].
- [ ] Relic green arrow points correctly from all 8 directions and disappears once collected [S12].
- [ ] Perf: 450 gems plus a Vacuum pull at once holds 60 fps on a mid-range mobile device in Roblox.
- [ ] Everything is pixel-snapped. No sub-pixel shimmer on idle gems or coins.
- [ ] The audio throttle keeps a 400-gem vacuum from clipping or stacking more than 8 voices.

## 3. Visual hierarchy notes

1. **The treasure chest UI owns the screen.** Gameplay pauses, the backdrop dims, and it is the only full-screen ceremony that comes with music (jingles of 3 s + 10-19 s) [S2,S14-16]. The intensity scales with the tier: lvl 1 has no panel light-up, lvl 3 adds the curved ribbon and fireworks [S2]. An evolution reveal must read stronger than any normal item (stars behind it, God Rays) [S2].
2. **Screen-wide pickups come next.** Rosary (flash plus mass death), Orologion (ring plus a global blue tint) and Vacuum (a sea of converging gems). These change the whole playfield but do not pause it. Keep each to one big signal (flash, tint or motion) so they can overlap without mush (inferred).
3. **Gold Fever and Nduja** are sustained 10 s states. They need a persistent but low-contrast signal (inferred) so they do not hide threats.
4. **Gems** are the densest layer (up to 400). They must stay small, still and low-animation so enemies stay readable, with colour as the only tier cue (blue < green < red) [S1]. Motion only starts on homing.
5. **Coins, chicken and floor items** sit at gem level, but their shape is distinct (round spin, roast). Rare pickups (Rosary, Orologion, Vacuum) have a glow animation that lifts them above common drops [S4,S5,S7].
6. **Light sources** are environmental: a looping flame that is readable at a glance as "hit me", with a small break poof. They should never compete with enemy hit effects.
7. **Draw order** (inferred): floor, light sources, gems/coins/pickups, enemies, player, weapon FX, screen tints (freeze, fever), flash, HUD, chest UI.
8. **The magnet radius is not drawn in VS**. Show it only as a dev/QA overlay.
