# Snake Wars "Venom Candy" UI Audit (41 screens)

Scores 0-3 per criterion: F = Focal point, A = Real art, R = 3D renders, C = Craft consistency, M = Motion potential. Total /15.

Note: Desktop exports are 1024 wide (0.533x of 1920), so a label that looks 8px here is ~15px at 1920. I judged label size at the exported scale and flagged only text that is clearly below 15px at 1920 (about <8px in export) or tiny at phone scale (844x390 is native, so phone text size is real).

## Scores

| screen | F | A | R | C | M | total | top 3 holding it back |
|---|---|---|---|---|---|---|---|
| billboards_desktop (spec sheet) | 1 | 0 | 1 | 2 | 1 | 5 | Four mini-specs on one dark sheet, no hero; sub-labels ~7px (Fang Pad 'LENGTH FOREVER', stage sign 'RECOMMENDED'); only Egg Stall sign has a render, Fang Pad uses a flat white fang placeholder |
| boosts_desktop | 1 | 0 | 2 | 2 | 2 | 7 | No hero: ACTIVE NOW chips, 4 potion rows and 3 GET MORE cards are equal weight; 3 identical green USE/GET buttons = no primary; no scenery/stage, only dim shop under the modal |
| codes_desktop | 2 | 0 | 1 | 2 | 2 | 7 | Large empty lower half of window under YOUR CODES (dead zone); code list rows ~11px text, all CLAIMED rows same weight as the input; one flat gem icon, no stage art |
| daily_desktop | 2 | 2 | 2 | 2 | 3 | 11 | Day 7 purple hero card and gold TODAY card compete (two primaries, left-bottom vs right); day labels/captions ~8-9px; Days 5/6 locks are flat padlock-on-icon |
| daily_phone | 2 | 2 | 2 | 1 | 3 | 10 | Captions ('CLAIMED','TOMORROW','30 MIN BOOST') under 15px at phone scale; header gold ribbon much louder than the cards; Day 7 hero cramped at right edge |
| death_wars_desktop | 2 | 1 | 2 | 2 | 2 | 9 | 1,549 final length is hero but HUB (steel) and PLAY AGAIN are fine, X2 TROPHIES 249 gem button is a 3rd loud element; backdrop snakes are blurred noise not a stage; right 'YOU EARNED' column has 5 tiny stat labels |
| egg_stall_desktop | 1 | 2 | 3 | 1 | 2 | 9 | Four equal-width cards with no selected hero (pink outline on Crystal only); each card carries 3 buttons (price, gem, gift) so 6+ loud keys; rarity table text ~7px in export (13px at 1920), under the 15px floor; Frostbite lock card is a flat black silhouette |
| egg_stall_phone | 3 | 2 | 3 | 2 | 2 | 12 | Best list+detail in the file (hero egg left, odds middle, buy right); rarity rows still small, gem button green vs trophy orange are two primaries; top-left rail egg thumbnails tiny |
| free_reward_desktop | 2 | 2 | 2 | 2 | 2 | 10 | Hero hatchling on plinth is good but disabled CLAIM (grey, locked) is the dimmest element though it is the goal; 3 task rows equal weight; EXCLUSIVE chip small |
| gift_1 | 1 | 1 | 2 | 2 | 1 | 7 | Left gift card and friend list both medium weight; NEXT (green) sits far bottom-right away from the gift; friend avatars are flat letter discs; row text ~10px; large empty band left of NEXT |
| gift_2 | 2 | 0 | 2 | 2 | 1 | 7 | Small modal floating high with empty lower third; CANCEL vs 10-Robux green okay, but 'Robux is charged to you' reassurance line is ~9px and the ask is the title only |
| hatch_1_shake | 3 | 2 | 3 | 2 | 3 | 13 | Full-screen egg is clear; 'SKIP' and '2 LEFT IN STOCK' are ok. No ink line / stage edge, background is vignette not painted scenery |
| hatch_2_crack | 3 | 2 | 3 | 2 | 3 | 13 | Same as shake; crack glow and star burst are strong; 'TAP TO HATCH FASTER' ~11px |
| hatch_3_reveal | 2 | 2 | 3 | 2 | 3 | 12 | EQUIP (green) and HATCH AGAIN (gold) are twin primaries; LEGENDARY banner wider/louder than the creature name; close gem floats alone at far top-right, away from the action |
| hud_hub_desktop | 1 | 2 | 2 | 1 | 2 | 8 | Seven saturated menu tiles + SHOP + DAILY at left outweigh the gold 11.6M length (bottom-centre) the player cares about; tile sublabels ~7px; right column (OP offer, x2 Length, VIP, 3 boost chips) is a second shouting cluster; bottom row of four +1.4M/+8.3M buy buttons nearly as loud as the number |
| hud_hub_phone | 2 | 2 | 2 | 2 | 2 | 10 | Stacked currency bars with giant + buttons (3 greens) look like primaries; 11.6M is well placed but menu grid 5x2 on left is still louder; chips under 15px |
| hud_hub_phone_v2 | 2 | 2 | 2 | 2 | 2 | 10 | Better than v1 (currencies in one top row, menu column narrower) but still 4 buy-chips + 7 menu tiles + OP gift all saturated; prefer v2 |
| hud_stage_desktop | 2 | 3 | 2 | 2 | 3 | 12 | 3 wall prices (8.0K/5.0K/5.0K) + 4.6K length + +23K buy all similar gold/orange; the NEXT wall is not distinguished from far walls; right progress ladder text ~10px |
| hud_stage_phone | 2 | 2 | 2 | 1 | 3 | 10 | Bottom row cramped: +23K buy, 4.6K, 92% bar, 5.0K wall, BOOST gem fighting; labels ('NEED 400 MORE','NEXT WALL') ~10px; top-left LEAVE/0-3 SNAKES pills small |
| hud_wars_desktop | 2 | 2 | 2 | 2 | 2 | 10 | Gold 1,549 bottom-left is clear; TOP 10 panel top-right is a dense 10-row text block ~9px; left icon rail (7 items) is unlabeled and tiny; minimap clipped bottom-right |
| hud_wars_phone | 2 | 2 | 2 | 1 | 2 | 9 | BOOST gem bottom-right is the one loud key (good) but TOP 10 and your length compete; labels 'YOUR LENGTH','#37 OF 38' under 15px |
| leaderboards | 2 | 1 | 1 | 2 | 2 | 8 | Podium is the hero but is flat white/gold/orange blocks, snakes tiny gradients on top; tab pills equal weight; right list 8 identical rows with 11px names; YOU row green is the only emphasis; no scale texture visible |
| main_menu (portrait) | 1 | 1 | 2 | 2 | 1 | 7 | Seven tiles all full-saturation with equal weight and no primary (SHOP slightly larger); 7px sublabels; daily rewards strip gold shouts at bottom; tiles are flat gradient blocks |
| op_offer | 2 | 1 | 2 | 2 | 2 | 9 | Gift hero + 07:06 timer pill red on gold + What's Inside + green buy: timer pill is louder than price; yellow stage panel is a flat gradient not painted; tiny 'WHAT'S INSIDE' labels |
| pets_desktop | 1 | 2 | 3 | 1 | 2 | 9 | EQUIP BEST (large green, bottom-left) and LEVEL UP (blue) and MAKE GOLDEN (gold) are three primaries, and none sits beside the hero details; hero Sunny Sproutling at right is small (~1/5 of window) and the grid is the largest thing; grid last row clipped at the bottom edge; text 8-10px everywhere; TEAM BONUS X12.3 at top-centre is a 4th gold number |
| pets_index_desktop | 1 | 1 | 2 | 1 | 2 | 7 | Left world rail + centre grid + right reward panel but no hero; a 15-tile grid half silhouettes ('???') flat black; +10% LENGTH FOREVER is the loudest thing, fine, but the hatchlings row labels ~8px; GO TO EGGS blue and locked world rows are the same weight |
| pets_phone | 2 | 1 | 3 | 2 | 2 | 10 | Closest to the house pattern: grid left, hero details right with LEVEL UP and GOLDEN twin keys then EQUIP BEST big green (3 primaries); hero render only ~100px; 'COST 1,200 GEMS' caption small |
| quests_achievements | 2 | 0 | 1 | 2 | 2 | 7 | Left list of 5 rows equal weight with 4 grey GO buttons (good: dim) and 1 red CLAIM; right star 38/90 hero is a flat star icon; progress bars all same fill weight; row captions ~9px; no scenery |
| quests_daily | 2 | 1 | 2 | 2 | 2 | 9 | CLAIM (red) vs 'OPEN PASS' (blue) vs bonus egg hero; row 1 highlighted gold border is good; DONE row grey is fine; right hero egg render is small relative to the empty panel space; captions ~9px |
| quests_pass | 1 | 1 | 2 | 1 | 3 | 8 | Gold UNLOCK, gold selected tier 6, gold GRAND PRIZE card and red CLAIM ALL all shout; reward-track icons ~30px with ~9px captions, premium row nearly invisible dark purple; the 6-tier track is cut off at 8 of 30 with no scroll cue; Tier-30 snake is a flat gradient streak not a render |
| rebirth_desktop | 2 | 1 | 1 | 2 | 3 | 9 | Hero X3.0 on lime is right but the window ribbon, X3.0 panel and SKIP key are all the same green, so the primary is lost; locked REBIRTH (steel) is the actual action and reads as disabled; NO stage art or character: big dead lower half in 2X/AUTO REBIRTH cards; ring icon is a tiny flat purple glyph |
| rebirth_phone | 2 | 1 | 1 | 2 | 3 | 9 | Same issues; the X3.0 numeral has an artifact/glyph over the X at this scale; 'Resets Length · keeps pets & skins' ~11px and sits detached below the hero |
| settings_desktop | 1 | 0 | 1 | 2 | 1 | 5 | Two plain columns of sliders/toggles; CODES blue key bottom-left is the only accent and is secondary; large empty bottom-right; toggles ON/OFF fine; header pale blue ribbon is the only colour |
| shop_desktop | 2 | 2 | 2 | 1 | 2 | 9 | Starter Bundle hero (left) vs OP! GIFT red card (right) fight for primary; PASSES row is cut off by the window edge mid-card (below the fold, VIP half visible); 10-Robux green button repeated on both; chips 'TROPHIES / OF LENGTH' ~8px |
| shop_phone | 2 | 2 | 2 | 1 | 2 | 9 | Left tab rail vs desktop's top tabs (inconsistent); bundle chips tiny; 3 stacked buy keys all green; scroll bar the only cue for the 4 other categories |
| skins_desktop | 2 | 2 | 1 | 1 | 2 | 8 | Hero stage is left and spot-lit (good) but the snake is a flat purple gradient swoosh, not a cel render, and EQUIP sits under it full-width (fine) - however 12 grid tiles are all same size/outline and the 9-colour rarity legend row (~8px) tops the grid; bottom grid row cut off; hero stage has no 4px ink bottom line |
| starter_bundle | 2 | 2 | 2 | 2 | 2 | 10 | START STRONG illustration panel is the hero; price key (green, ~190px) is small vs the 36px banner and sits low; 4 contents chips ~8px captions; window narrower than Shop's version of the same offer |
| wait_desktop | 3 | 1 | 2 | 2 | 2 | 10 | CLAIM FREE is clearly primary; gold ribbon + large coiled snake make a clean stack; 'No thanks, leave' 11px (acceptable, ought to be dim); background HUD shows through not blurred |
| wait_phone | 3 | 1 | 2 | 2 | 2 | 10 | Same; layout is better balanced here (render left, text and key right) |
| worlds_desktop | 1 | 2 | 2 | 1 | 2 | 8 | The map is the stage but 8 equal nodes + dotted paths scatter attention; selected Frostbite node only slightly lighter; PLAY STAGE 17 green key sits bottom-right under a boss card and a 24-dot stage grid (dense 10px numerals); node labels ~9px; locked worlds 5-8 shown as black silhouettes (dead weight, 40% of the map) |
| worlds_phone | 1 | 1 | 2 | 1 | 2 | 7 | Header ribbon clipped at the very top (globe pin cut); eight world plates in a 4x2 grid with 9px labels; Frostbite label overlapped by snake mascot; PLAY STAGE 17 good but small; boss card and world card both at same weight |

Average total: 9.0/15. Averages by criterion: F 1.8, A 1.4, R 2.0, C 1.7, M 2.1.

## Ranked, worst first

1. billboards_desktop (spec sheet) - 5
2. settings_desktop - 5
3. boosts_desktop - 7
4. codes_desktop - 7
5. gift_1 - 7
6. gift_2 - 7
7. main_menu (portrait) - 7
8. pets_index_desktop - 7
9. quests_achievements - 7
10. worlds_phone - 7
11. hud_hub_desktop - 8
12. leaderboards - 8
13. quests_pass - 8
14. skins_desktop - 8
15. worlds_desktop - 8
16. death_wars_desktop - 9
17. egg_stall_desktop - 9
18. hud_wars_phone - 9
19. op_offer - 9
20. pets_desktop - 9
21. quests_daily - 9
22. rebirth_desktop - 9
23. rebirth_phone - 9
24. shop_desktop - 9
25. shop_phone - 9
26. daily_phone - 10
27. free_reward_desktop - 10
28. hud_hub_phone - 10
29. hud_hub_phone_v2 - 10
30. hud_stage_phone - 10
31. hud_wars_desktop - 10
32. pets_phone - 10
33. starter_bundle - 10
34. wait_desktop - 10
35. wait_phone - 10
36. daily_desktop - 11
37. egg_stall_phone - 12
38. hatch_3_reveal - 12
39. hud_stage_desktop - 12
40. hatch_1_shake - 13
41. hatch_2_crack - 13

## Hero-stage candidates (list + detail windows)

None of the five yet use "A boss stage" (rail left, hero stage right, primary key beside the details). Priority order by gain:
1. **Worlds and Stages** (worlds_desktop 8, worlds_phone 7): make the selected world a full-bleed painted stage (right, ~55% width) with the boss render, a 4px ink bottom line, and PLAY STAGE 17 as the one primary beside it; the 5+Void Climb list becomes a left rail of rows with dim locked rows. Replace the all-nodes map or shrink it to a strip.
2. **Pets** (pets_desktop 9, pets_index 7, pets_phone 10): hero hatchling should be at least a third of the window, with LEVEL UP as the primary beside the stats; EQUIP BEST, MERGE ALL, UNEQUIP ALL drop to steel; MAKE GOLDEN secondary. pets_phone is the nearest to the pattern.
3. **Egg Stall** (egg_stall_desktop 9): make egg_stall_phone's layout the desktop layout (rail of 4-5 egg thumbnails, one big hero egg stage, odds table, one HATCH key). Kills 6 competing buy buttons.
4. **Skins** (skins_desktop 8): hero already left; give it a real cel render, make the grid tiles quieter (rarity as 3px bottom strip, not text row), ink line at stage bottom, put EQUIP beside details.
5. **Rebirth** (rebirth_desktop 9): not a list, but needs a hero stage (coiled snake/ring render growing X2.5 -> X3.0) and a primary that is not the same green as the ribbon; REBIRTH (the action) must be the loud key, SKIP steel/gem-tinted.
Also worth the treatment: Shop (right pane Starter Bundle hero with category rail), Quests (selected quest hero), Boosts.

## File-wide patterns, ranked by impact

1. **No ONE primary per window.** Hub, Pets, Egg Stall, Hatch reveal, Shop, Quests pass, Daily, Rebirth all show 2-6 saturated keys. The cause is repeated per-card green Robux/trophy buttons and the OP! red gift. Fix: one saturated key per window, per-row keys become steel or ghost until the row is selected.
2. **Green is overloaded.** It is the mint rate colour, the primary buy key, the CLAIM key, the lime Rebirth ribbon, the Worlds ribbon and the progress fill. Rebirth and Worlds literally lose the primary into the ribbon colour. Give the primary key a distinct recipe (and ribbons their own hue), reserve mint for rates.
3. **Gold overload.** Length, trophies, GOLDEN, LEGENDARY chips, Daily and Wait ribbons, tier highlights, OP banners are all gold, so "Length is always gold" no longer identifies Length. Trophy currency should be a different warm (orange/bronze already used) and pet multipliers (X12.3, X2.40) should not be gold-yellow.
4. **Micro labels everywhere.** Sub-captions on hub tiles, chips, stage grids, rarity tables, reward captions are ~7-9px at export (about 13-17px at 1920 but many clearly under 15px on phone, where frames are native). Floor at 15px; delete captions that are not read (SUB-LABELS on hub tiles, 'COLLECT & EQUIP').
5. **Little real art.** Almost no painted scenery header or full-bleed stage ending in a 4px ink line; most windows are a dark scale-textured slab with a ribbon. Exceptions: hatch sequence, hud_stage. Windows rely on boxes inside boxes (cards in panels in window) rather than layers.
6. **Layout fold problems.** Shop PASSES row is cut mid-card; Pets grid last row clipped; Skins grid last row clipped; Quests Pass track truncated; Worlds phone header clipped at top. Mixed with dead zones: Codes, Gift confirm, Settings bottom-right, Rebirth lower area.
7. **3D renders are strong for eggs and hatchlings but weak elsewhere**: skins and boss/pass prizes are flat gradient swooshes; Fang Pad fang, ring, star, avatar discs and padlocks are flat placeholders; locked items are black silhouettes (fine as a trick but too many at once in Worlds and Pets index).
8. **Desktop vs phone divergence**: Shop (top tabs vs left rail), Egg Stall (phone better than desktop), Hub v1 vs v2. Pick one structure per window and scale.
9. **HUD hub is a menu wall**: seven equal rainbow tiles plus the right offer column outshine the gold length number, the thing the player watches.
10. **Close key**: the round red gem is consistent, but on hatch_3_reveal it floats top-right of a screen with no window; also overlaps the header ribbon in the phone frames, check hit area.
11. **Motion set-up**: strong where numbers sit in dedicated plates (Rebirth X, daily streak, hatch sequence); weak for lists with no stagger anchor (Boosts, Gift, Settings) and for HUD chips.
12. **Backdrop**: modals show the HUD dim, un-blurred, so 'SHOP' title and menu tiles compete as a ghost second window (visible in Codes, Rebirth, Daily, Wait, Settings). Blur or darken further.

## Reading order (first / second / third)

- **worlds_desktop**: (1) the glowing Frostbite Peaks node plus snake mascot at map centre, (2) the green PLAY STAGE 17 bar bottom-right, (3) the three completed purple/blue nodes top row with check badges. Intended: selected world stage, then PLAY STAGE, then boss. The Glacier Fang boss card, the world's proper hero, lands about 6th.
- **egg_stall_desktop**: (1) the pink-bordered Crystal Egg card with its NEW tag, (2) the big RESTOCK IN 06:08 pill at top, (3) the orange 4.5K and green 32 buy keys on that card. Acceptable, but the Tide Egg blue render pulls ahead of the odds and the four equal cards flatten the scene.
- **pets_desktop**: (1) the green EQUIP BEST key bottom-left, (2) the rainbow/golden hatchling cards top-left of the grid with the X8.0 plates, (3) the X12.3 team bonus top-centre; the hero Sunny Sproutling lands 4th and LEVEL UP 6th. Intended: hero, stats, LEVEL UP.
- **skins_desktop**: (1) the purple Grape Venom hero snake on the spotlight (good), (2) the green EQUIP key under it, (3) the golden/purple Legendary tile in the grid bottom-left of the grid. Reasonable order, but the grid's rarity-coloured tiles fight the stage.
- **rebirth_desktop**: (1) the lime X3.0 panel, (2) the green SKIP key beneath it, (3) the white X2.5 numeral. REBIRTH (steel with lock) is 5th and the progress bar 4th. Intended: X3.0, REBIRTH, progress.
- **shop_desktop**: (1) the red-orange OP! GIFT card with its gift render at top-right, (2) the purple STARTER BUNDLE card with the large red gift, (3) the green 10-Robux button. Intended order: Starter Bundle first; the red OP! card wins on saturation and isolation.

## Content mismatches

- worlds_desktop and worlds_phone show 8 worlds (Sprout Meadow, Tidepool Shallows, Crystal Caverns, Frostbite Peaks, Magma Hollow, Candy Canyon, Starfall Nebula, Crown Core) and "WORLD 4 OF 8". Launch is 5 Worlds plus Void Climb: Candy Canyon, Starfall Nebula, Crown Core must go; Void Climb (a climb, not an arena world) should be a distinct tail node. "Beat X boss" subtitles reference those cut worlds.
- pets_index_desktop rail lists Candy Canyon, Starfall Nebula, Crown Core as worlds; Skins shows "Starfall Egg, 0.5% chance, World 7" and "Candy Cane: Candy Canyon egg"; Egg Stall INDEX 12/40 vs Pets "48/150 hatchlings" (check against data). Index "1/8 WORLDS".
- Egg Stall shows Frostbite Egg as "World 4 locked, clear Crystal Caverns to unlock" while Worlds shows Frostbite Peaks as the current world at stage 17 and Crystal Caverns as complete: state conflict. Same mock player, so one is wrong.
- Egg Stall shows only 4 eggs; with 5 launch worlds there should be 5 (Magma Hollow). Rarity table includes SECRET on every egg: confirm which eggs can drop it.
- Skins list "Sapphire Gloss: Index crystal caverns", "Prism: Secret", "Golden Emperor: Quest Pass Tier 30" and Daily Day 7 shows an Exclusive Hatchling: fine, but Free Reward 'X2 LENGTH FOREVER' and Wait 'FREE x2 LENGTH 15 min' are two different freebies; check against monetization rules.
- 'Press ENTER - you hatch at 10 again' (death_wars_desktop) and 'TAP TO HATCH FASTER' (hatch) mix PC and touch language; 'Hold click to boost' on hud_wars_desktop is PC-only. Use input-agnostic text. Also death screen text says "you hatch at 10 again"; unclear.
- Nothing sells arena size in WARS: confirmed; hud_wars screens carry only SHOP, boosts and BOOST (no arena items). Good.
- Leaderboards show rows with values of 1.92T / 4.81T whereas the player's 11.6M: tiers are consistent with all-time board but the player is rank #1,284: fine.
- rebirth: "Rebirth at 15M" with Length 11.6M and rebirth_desktop 'X2.5 -> X3.0 (+0.5x)': matches. Rebirth Skip price 40 Robux vs Daily/other prices: confirm.
