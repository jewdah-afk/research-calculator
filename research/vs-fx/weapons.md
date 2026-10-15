# Vampire Survivors v1.16: weapons, evolutions, unions (FX research)

Scope: base game only (no DLC folders), shipped build **1.16.107** (`Game Version.txt` in the data rip). This file covers every weapon record in the base-game `Weapon.json`, frame by frame where any source allows it.

Rules used here. Numbers come from the shipped data rip (`Weapon.json`, `HitVfx.json`) or from vampire.survivors.wiki pages fetched 2026-10-15. Anything marked **inferred** is my reading and has no source, so don't treat it as fact. **measure** means no reachable source gives the value, so take it from gameplay capture before you lock it in. Raw data units: times in ms (converted to s below), `power` x10 = displayed damage, `area`/`speed` are multipliers.

None of the sources reached give sprite pixel sizes, animation frame counts, per-frame timings, or rotation rates. They all need **measure** from a 1080p capture at integer zoom. Don't invent them. The catalog gives the algorithm and leaves the exact constant as a named param.

## Source keys
| Key | URL |
|-|-|
| WJ | https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Weapon.json (shipped 1.16 balance, fetched) |
| HV | https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/HitVfx.json (shipped hit-VFX table: tint, hit frame, impact frame, duration ms; fetched via git clone) |
| GV | .../VampireSurvivorsFiles/main/Game%20Version.txt (1.16.107) |
| VSB | origin/claude/vampire-survivors-mechanics-y1l323:research/vs/weapons.md / weapons.json (our earlier mechanics pass) |
| w/X | https://vampire.survivors.wiki/w/X for X = Whip, Magic_Wand, Knife, Axe, King_Bible, Santa_Water, Runetracer, Cross, Fire_Wand, Garlic, Lightning_Ring, Pentagram, Peachone, Ebony_Wings, Vandalier, Death_Spiral, Bloody_Tear, Holy_Wand, Thousand_Edge, Heaven_Sword, Unholy_Vespers, Hellfire, Soul_Eater, La_Borra, NO_FUTURE, Thunder_Loop, Gorgeous_Moon, Phiera_Der_Tuphello, Eight_The_Sparrow, Phieraggi, Song_of_Mana, Mannajja, Gatti_Amari, Vicious_Hunger, Shadow_Pinion, Valkyrie_Turner, Clock_Lancet, Infinite_Corridor, Laurel, Crimson_Shroud, Vento_Sacro, Fuwalafuwaloo, Bone, Cherry_Bomb, Carr%C3%A9llo, Celestial_Dusting, La_Robba, Greatest_Jubilee, Bracelet, Flames_of_Misspell, Victory_Sword, Santa_Javelin, Phas3r, Glass_Fandango, Ammo_Appalate, Options (all fetched, HTTP 200) |
| WIKIP | https://en.wikipedia.org/wiki/Vampire_Survivors (Phaser before 1.6, Unity from 1.6) |
| GOL | https://gamingonlinux.com/2023/08/vampire-survivors-co-op-and-new-game-engine-upgrade-is-live |
| ST1 | https://steamcommunity.com/app/1794680/discussions/0/3194745319522730122 (damage numbers "faked +-5" claim, disputed) |
| ST2 | https://steamcommunity.com/app/1794680/discussions/0/3830916907601747839 and .../3194747223954471950 (late-game projectile lag) |
| PN028 | https://vampire.survivors.wiki/w/Updates/Patch_0.2.8_-_Cloud_Saves,_Volume_Sliders,_Stats_Display, plus the dev note quoted in search results: the Electron build slowed down with "a lot of semi-transparent pixels on screen" |
| MGD | https://madegooddesigns.com/vampire-survivors-font/ (font not officially credited; guesses only) |
| PG | https://www.pocketgamer.com/vampire-survivors/weapon-evolution-combos (Death Spiral = 9 scythes) |
| AP | https://www.androidpolice.com/vampire-survivors-weapon-evolution-guide/ |
| GW | https://gamewave.fr/vampire-survivors/vampire-survivors-armes-evoluees-et-legendaires-comment-les-obtenir/ |
| ALT | https://altema.jp/vampiresurvivors/laborra |
| RR | https://rogueranker.com/vampire-survivors-evolution/ |

**Blocked or unavailable:**
- vampire-survivors.fandom.com returned **HTTP 402**.
- spriters-resource.com returned **HTTP 403**, so no sprite sheets and no pixel sizes.
- The GitHub API (api.github.com and gh) is **not enabled** for SurvivatonsAndMore/VampireSurvivorsFiles. A plain `git clone --filter=blob:none` worked, and the repo holds only JSON data and translations, no atlases or animation files.
- YouTube was not reached (no transcript access).
- Reddit only came back as search snippets; no thread had pixel or timing data.
- Wiki pages are over 100k characters, so each fetch read the first 100k only. The trailing gallery and footer were not read except on Heaven Sword, where they held nothing useful.

Reference count: 56 wiki pages fetched + 2 shipped data files + version file + about 20 search-result pages (WIKIP, GOL, ST1, ST2, PN028, MGD, PG, AP, GW, ALT, RR and the others listed in those searches).

## Shipped hit-VFX table (HV), the core of every impact
Every weapon has a `hitVFX` name in WJ. HV is keyed 0..16 and the data doesn't give the name-to-index map. The mapping below is **inferred** by matching each tint to the weapon family that uses it. Treat it as a hypothesis and verify it with a capture of each weapon.

|HV#|isTintFill|targetTint|hit frame|impact frame|dur ms|inferred name|
|-|-|-|-|-|-|-|
|0|false|#FFFFFF|-|-|120|None (no flash)|
|1|true|#FFFFFF|HitStar2|Shockwave3|120|Default (white)|
|2|true|#0000FF|feedback-4|Shockwave3|30|Blue (Eight The Sparrow)|
|3|true|#FF0000|Hit1|HitBoom2|30|Red (Phiera) or Fire|
|4|true|#220044|HitMoon2|HitBlack1|30|Dark|
|5|true|#44FFFF|HitStar2|HitStarWhite1|30|Water / Spirit|
|6|true|#DDFFDD|NoDraw|NoDraw|60|TimeFreeze (tint only)|
|7|true|#FFFFFF|s_pfx_rainbow_32|s_pfx_rainbow_64|60|Prism|
|8|true|#FFEEEE|HitCross1|HitCrossImpact1|60|Light|
|9|true|#EEEEFF|HitCross2|HitCrossImpact2|60|Beam or Light variant|
|10|true|#FFFFFF|HitStarWhite2|HitCrossImpact3|60|Light variant|
|11|true|#110022|HitMoon2|HitBlack1|30|Evil|
|12|true|#00FF00|HitStarWhite2|HitCrossImpact3|60|Wind / green|
|13|true|#FF0000|HitBoom2|HitSmoke2|60|Fire|
|14|true|#FFFC99|HitStar2|HitStarWhite1|30|Yellow (Seraphic Cry)|
|15|true|#DDDDFF|HitCloud1|bubble|60|Water|
|16|true|#A7DC29|HitGreen1|HitGreen2|120|Blood/poison green|

The hitVFX names that appear across all data folders (WJ and the DLC Weapon.json files): Light 22, Fire 19, Dark 15, None 12, Prism 9, TimeFreeze 8, Evil 5, Default 5, Water 4, Blood 4, Wind 2, Spirit 2, Red 2, Blue 2, Yellow 1, Beam 1. That's 16 names against 17 table rows. A weapon record with no `hitVFX` key presumably uses Default (inferred).

**How a hit renders (inferred from the HV fields):**
1. On damage, the enemy sprite is replaced by a **solid fill** of `targetTint` (`isTintFill` = tint-fill, not a multiply) for `duration` ms.
2. `hitFrameName` is drawn at the contact point.
3. `impactFrameName` is drawn at the enemy centre.

## Frame budget tiers
- **30:** projectile motion, hit flashes (30 to 120 ms flashes need 30 fps or they vanish).
- **15:** lingering zones, particle sparkle, explosions.
- **8:** idle loops (orbits look fine at 30 but can be computed at 15 and interpolated).

"covered" names one of our existing 89 effects or weapon styles. "NEW" is a new effect.

## 1. Effect catalog

|id|Name|VS usage|Algorithm (steps / math)|Params|tier|Covered by|Sources|
|-|-|-|-|-|-|-|-|
|W001|Whip slash sprite|Whip|1) Every cd 1.35 s, spawn a slash at the player's torso on the facing side (L/R only). 2) Horizontal flat sprite, scale = Area. 3) Play the slash frames once, then despawn. 4) Hitbox is an AABB matching the sprite, pierce all.|cd 1.35, Area 1→1.2, frames **measure**|30|covered: Verlet Whip (visual) / Whip style|WJ, w/Whip|
|W002|Whip alternate side + rise|Whip Amount≥2|slash i (0-based): side = facing × (−1)^i; y offset = +i × rowStep (each one higher); delay i × 0.1 s|ri 0.1, rowStep **measure**|30|covered: Whip style|w/Whip|
|W003|Whip same-side trick|Whip|side is sampled at each slash's spawn time, not cast time, so flipping facing inside the 0.1 s gaps puts every slash on one side|-|30|NEW (logic)|w/Whip|
|W004|Whip Area growth|Whip L4/L6|sprite scale x and y × (1+0.1 per step), anchored at the torso edge|+10% ×2|-|covered: RotSprite (nearest scale)|WJ|
|W005|Whip crit pop|Whip|20% crit ×2 → crit-style damage number|crit 0.2/2|30|covered: Damage Numbers|WJ|
|W006|Default white hit flash|Whip, most weapons|enemy tint-fill #FFFFFF for 120 ms + HitStar2 at contact + Shockwave3 at centre|HV#1|30|covered: Dither Bloom (flash) partial; NEW tint-fill shader|HV|
|W007|Bloody Tear red slash|Bloody Tear|same as W001/W002 with red slash frames; Area 1.3, Amount 2 from Lv1|A 1.3, N 2, cd 1.35|30|covered: Verlet Whip + Palette Cycling (recolour)|WJ, w/Bloody_Tear|
|W008|Dark hit flash|Bloody Tear, Vespers, Soul Eater, Ebony Wings, Gatti, Shadow Pinion, Mazzo|tint-fill #220044 for 30 ms + HitMoon2 + HitBlack1|HV#4 (inferred)|30|NEW (tint-fill)|HV, WJ|
|W009|Lifesteal heal pop|Bloody Tear crit|on ≥1 crit in the attack: +8 HP, 1 s lockout; green recovery number on the player|8 HP, 1 s|30|covered: Damage Numbers (heal colour)|w/Bloody_Tear|
|W010|Magic Wand missile|Magic Wand|1) At cast, target = nearest enemy. 2) Spawn a blue missile at the player, velocity = normalize(target−p) × v. 3) Straight line, no homing after launch (inferred from "retargets every shot"). 4) Dies on pierce exhaustion (1) or a wall.|N 1→4, P 1→2, cd 1.2→1.0, ri 0.1, S 1|30|covered: Magic Wand style|WJ, w/Magic_Wand|
|W011|Wand sequential volley|Magic Wand/Holy Wand|shot k fires at t0 + k × 0.1 s, re-acquires nearest each shot|ri 0.1|30|covered|w/Magic_Wand|
|W012|Wand missile trail|Magic Wand|short fading afterimage or sparkle trail behind the missile (**measure**; the wiki only says "blue magic missile")|alpha decay **measure**|30|covered: Dither Bloom trail (inferred)|w/Magic_Wand|
|W013|Wand wall kill|Magic Wand|missile despawns on wall contact (hitsWalls)|-|30|NEW (logic)|w/Magic_Wand|
|W014|Holy Wand stream|Holy Wand|cd 0.5, S 2, N 4, P 2; volleys overlap (next volley starts before the last finishes); on-screen count capped by pool 60|pool 60|30|covered: Magic Wand style|WJ, w/Holy_Wand|
|W015|Knife throw|Knife|1) Direction = facing (8-dir on keyboard, free on pad). 2) Knife sprite rotated to direction. 3) Straight line, infinite range until offscreen. 4) Pierce 1 → 3.|S 1, P 1→3, kb 0.5|30|covered: Knife style + RotSprite|WJ, w/Knife|
|W016|Knife parallel volley|Knife Amount|knives "in short volleys in parallel": knife i fires at i × ri with a perpendicular offset (inferred: small lateral jitter)|ri 0.1→0.04|30|covered|w/Knife|
|W017|Knife crit|Knife|30% ×3 crit|0.3/3|30|covered: Damage Numbers|WJ|
|W018|Thousand Edge stream|Thousand Edge|cd 0.35, ri 0.05, N 6, S 1.5, P 3 → effectively continuous; capped by pool 70; higher Speed = fewer on screen|pool 70|30|covered: Knife style|WJ, w/Thousand_Edge|
|W019|Axe toss arc|Axe|1) Axe 0: v0 = (0, −vy), straight up. 2) Each frame: vy += g·dt, pos += v·dt. 3) Speed scales vy (apex height). 4) Spin sprite continuously (rate **measure**). 5) Despawn offscreen bottom / pierce 3→7.|g **measure**, S 1, A ×1.3|30|covered: Axe style + RotSprite|WJ, w/Axe|
|W020|Axe fan widening|Axe Amount|axe k≥1: vx = facing × k × dvx ("progressively wider arcs"), launched at k × 0.2 s|ri 0.2, dvx **measure**|30|covered|w/Axe|
|W021|Axe Area 1.3x|Axe|sprite scale = playerArea × 1.3|-|-|covered: RotSprite|w/Axe|
|W022|Low-speed drop|Axe/Death Spiral|with very low Speed the axe barely rises and simply drops|-|30|covered|w/Axe|
|W023|Death Spiral radial burst|Death Spiral|1) 9 scythes at angles θ_i = θ0 + i × 40° (spacing **inferred** from 360/9). 2) Fired 0.05 s apart (looks like a spiral sweep). 3) Constant radial velocity, no gravity. 4) Spinning red sprite. 5) Pierce 1000, never despawn while on screen.|N 9, ri 0.05, S 0.8, A 1.2 (×1.3 → 1.44 or more), pool 50|30|covered: Axe style + RotSprite; NEW spiral spawn|WJ, w/Death_Spiral, PG|
|W024|Scythe wall stacking|Death Spiral|if the player moves with them, scythes stay on screen and pile up toward pool 50|pool 50|30|NEW (logic)|w/Death_Spiral|
|W025|Cross boomerang|Cross|1) Aim at nearest. 2) v decelerates linearly to 0 over distance D (D scales with Speed). 3) Reverse, accelerate back along the same line, exit the screen. 4) Spin continuously.|S 1→1.5, D **measure**|30|covered: Cross style|WJ, w/Cross|
|W026|Cross early stop|Cross|"stop shortly after hitting an enemy", so the turnaround triggers early on first hit (inferred reading)|-|30|NEW (logic)|w/Cross|
|W027|Heaven Sword throw|Heaven Sword|giant sword sprite, S 2, same boomerang as W025 with a longer outbound distance; spins after the throw; despawns late (5 Feb 2022)|A 1.2, cd 3.3, ri 0.5, kb 6|30|covered: Cross style + RotSprite|WJ, w/Heaven_Sword|
|W028|Light hit flash|Heaven Sword, La Borra, NO FUTURE, Peachone, Corridor, Photonstorm, Javelin|tint-fill #FFEEEE 60 ms + HitCross1 + HitCrossImpact1|HV#8 (inferred)|30|NEW|HV, WJ|
|W029|Extreme knockback push|Heaven Sword kb 6, Shroud kb 20|enemy displaced along the hit normal; magnitude ∝ weapon kb × enemy knockback stat, capped by enemy maxKB|kb 6/20|30|NEW (logic)|WJ, enemies.md|
|W030|King Bible orbit|King Bible|1) N books at angle θ_i = ωt + 2πi/N, clockwise. 2) r = r0 × Area (capped). 3) ω ∝ Speed. 4) Active Duration 3 s, then gone for the cd (cycle ~6 s).|N 1→4, A 1→1.5, S 1→1.6, D 3→4, hbd 1.7|8 (calc) / 30 (draw)|covered: King Bible style|WJ, w/King_Bible|
|W031|Bible falling pages|King Bible|occasionally emit a page particle from the ring that falls/drifts and fades|rate **measure**|15|covered: Boids-free particle (generic)|w/King_Bible|
|W032|Bible spawn/despawn|King Bible|books appear at full ring and vanish at end of Duration (pop vs fade **measure**)|-|30|NEW|w/King_Bible|
|W033|Hitbox-delay reset-all|Bible, Santa Water, Runetracer, Vespers, etc.|per-projectile per-enemy lockout hbd; when one lockout expires, all reset together|hbd|-|NEW (logic)|w/King_Bible|
|W034|Unholy Vespers ring|Unholy Vespers|red symbols, N 4, A 1.75, S 1.5, cd = Duration 3 s so the ring never ends; Dark flash; kb 4|-|8/30|covered: King Bible style + Palette Cycling|WJ, w/Unholy_Vespers|
|W035|Vespers purple pages|Unholy Vespers|as W031 but purple|-|15|covered|w/Unholy_Vespers|
|W036|Bible layering|Bible + Spellbinder|Duration > cd leaves 2 overlapping rings; draw both|-|30|NEW (logic)|w/King_Bible|
|W037|Fire Wand fireball arc|Fire Wand|1) Pick a random enemy. 2) N 3 fireballs in an arc centred on that direction; extra ones added at the arc ends. 3) Fired 0.02 s apart (near-simultaneous). 4) Slow, v × 0.75. 5) Pierce 1, blocked by walls.|N 3, ri 0.02, S 0.75, arc spacing **measure**|30|covered: Fire Wand style|WJ, w/Fire_Wand|
|W038|Fireball flicker|Fire Wand|animated fireball frames loop (**measure**)|-|15|covered: Doom Fire (sprite bake)|w/Fire_Wand|
|W039|Fire hit flash|Fire Wand, Hellfire, Valkyrie, Bracelet, Misspell|tint-fill #FF0000 60 ms + HitBoom2 + HitSmoke2|HV#13 (inferred)|30|covered: Doom Fire smoke partial; NEW tint-fill|HV, WJ|
|W040|Hellfire meteor|Hellfire|2 large meteors, random aim, slow (S 1 vs FW 0.75 in data but "slower" per wiki), pierce infinite, passes walls, ri 0.2|N 2, pool 20|30|covered: Fire Wand style + Doom Fire|WJ, w/Hellfire|
|W041|Garlic aura|Garlic|three rotating concentric circles centred on the player; radius ∝ Area; hit on entry then lockout = cd|A 1→2, cd 1.3→1.0|15|covered: Garlic style|w/Garlic|
|W042|Garlic debuff stack|Garlic|each hit: enemy knockback +0.3 (to max), freeze res −0.1|-|-|NEW (logic)|w/Garlic|
|W043|Soul Eater black aura|Soul Eater|black circle radius ∝ A 3; particles pulled inward (radial attraction), slow inward pulse|A 3, cd 1.0|15|covered: Garlic style + Boids (inward attractor)|WJ, w/Soul_Eater|
|W044|Little Heart drop|Soul Eater kills|P(spawn) = dmg × 3/140; small heart pickup|-|15|NEW (pickup)|w/Soul_Eater|
|W045|Santa Water flask drop|Santa Water|1) Bottle falls "from the sky" to the target point (first bottle at nearest enemy until Amount ≥ 4). 2) Shatters on landing.|ri 0.3|30|covered: Holy Water style|w/Santa_Water|
|W046|Holy flame pool|Santa Water|puddle + blue flames for D 2 s; radius ∝ Area (1→1.8); hbd 0.5|D 2→3|15|covered: Doom Fire (blue palette) + Falling-Sand Liquid (puddle)|WJ, w/Santa_Water|
|W047|Clockwise drop pattern|Santa Water N≥4|drop points step clockwise around the player in a rough circle|-|-|NEW (logic)|w/Santa_Water|
|W048|La Borra creeping pools|La Borra|pools move toward the player and grow as they move, up to a max size; growth ∝ Speed and MoveSpeed; Duration slows growth|A 2, N 4, D 4, cd 4, pool 30|15|covered: Falling-Sand Liquid + Doom Fire|WJ, w/La_Borra|
|W049|La Borra pale-blue colour|La Borra|"five pale blue zones" per one guide (Amount 4 in data)|-|-|covered: Palette Cycling|ALT, AP|
|W050|Runetracer diamond|Runetracer|1) Random direction. 2) Diamond rune, straight line. 3) Reflect on screen edges and obstacles (v.x or v.y negated). 4) Life 2.25 s. 5) Pierce infinite, hbd 0.5.|S 1→1.4, D 2.25→3.25, N 1→3|30|covered: NEW (bounce rune) / Knife style motion|WJ, w/Runetracer|
|W051|Rune colour trail|Runetracer|"each has a different color trail", a per-rune hue ribbon behind it|trail len **measure**|30|covered: Palette Cycling + Dither Bloom trail|w/Runetracer|
|W052|NO FUTURE laser|NO FUTURE|cyan laser, S 2.8, bounces, D 3 s active then 1 s cd|S 2.8, D 3|30|covered: Runetracer motion (W050) + Dither Bloom|WJ, w/NO_FUTURE|
|W053|NO FUTURE test-card explosion|NO FUTURE on bounce|translucent test-card pattern disc ringed by purple particles at the bounce point|radius ∝ Area|15|NEW|w/NO_FUTURE|
|W054|Retaliation burst|NO FUTURE on player hit|same explosion centred on the player, ≤ 1 per 0.5 s|0.5 s|15|NEW|w/NO_FUTURE|
|W055|Lightning bolt|Lightning Ring|1) Pick a random on-screen enemy. 2) Bolt sprite from top to target (visual only). 3) Circular hitbox at target, radius ∝ Area.|N 2→6, A 1→4, ri 0.05|30|covered: Lightning Ring style|WJ, w/Lightning_Ring|
|W056|Bolt-not-damage separation|Lightning|damage comes from the hitbox, not the bolt; draw them independently|-|-|NEW (logic)|w/Lightning_Ring|
|W057|Thunder Loop double strike|Thunder Loop|after strike 1, the same point is struck again after a short delay|delay **measure**|30|covered: Lightning Ring style|w/Thunder_Loop|
|W058|Closing-circle telegraph|Thunder Loop|orange circle with red/orange/yellow sparkle; a second circle shrinks to show strike 2|r(t) = r0 × (1 − t/T)|15|NEW|w/Thunder_Loop|
|W059|Pentagram glyph|Pentagram|purple glyph, gold lining (more detailed per level L1→L8), screen flash, erase all on screen|cd 90→60, D 1|15|NEW|w/Pentagram|
|W060|Pentagram blue variant|Pentagram|a blue glyph erases enemies only (no pickups)|-|15|covered: Palette Cycling|w/Pentagram|
|W061|Flashing-VFX gate|Pentagram/Gorgeous Moon|full-screen flash is skipped when the option is off|-|-|NEW (option)|w/Options|
|W062|Fixed damage number 655-665|Pentagram/Moon|displayed dmg = maxHP, forced into 655..665 if maxHP < 660|-|30|covered: Damage Numbers|w/Pentagram|
|W063|Gorgeous Moon glyph pulse|Gorgeous Moon|ground glyph pulses and chimes|-|15|NEW|w/Gorgeous_Moon|
|W064|Moon beams|Gorgeous Moon|8 beams 0.75 s apart, 4 at 0.375 s, 8 at 0.2 s = 20 beams over 9.1 s, each at the nearest enemy, erase + gem|timings exact|30|NEW|w/Gorgeous_Moon|
|W065|Crescent shatter|Gorgeous Moon|at 12.1 s, a waxing crescent shatters and erases the screen|t 12.1|15|covered: Sprite Shatter / Voronoi Glass|w/Gorgeous_Moon|
|W066|Waning crescent vacuum|Gorgeous Moon|waning crescent mends the glyph; all gems fly to the player|-|30|NEW (gem homing)|w/Gorgeous_Moon|
|W067|Bird follower|Peachone/Ebony/Vandalier|bird lerps toward a point behind the player at a slower speed and can drift offscreen|lerp **measure**|30|covered: Boids (seek)|w/Peachone|
|W068|Circling bombard zone|Peachone|visible zone at angle φ(t) around the player (radius fixed; Area doesn't change it), ω ∝ Speed|S 0.8|15|NEW|w/Peachone|
|W069|Bomb sets|Peachone|4 sets × 4 projectiles, 0.025 s apart; each set lands at the zone position when the set began; the set timer is independent of the zone|ri 0.025, D 4, cd 1|30|NEW|WJ, w/Peachone|
|W070|Ebony Wings mirror|Ebony Wings|same as W068/W069, rotating the opposite direction; Dark flash|-|15|covered via W068|w/Ebony_Wings|
|W071|Vandalier twin zones|Vandalier|multicolour bird, two zones (CW + CCW), 20 projectiles per set alternating zones; Prism flash|N 20, A 2.2|15|covered via W068|WJ, w/Vandalier|
|W072|Prism rainbow hit|Vandalier, Song of Mana, Mannajja, Celestial Dusting|tint-fill white 60 ms + s_pfx_rainbow_32 hit + s_pfx_rainbow_64 impact|HV#7|30|covered: Palette Cycling|HV, WJ|
|W073|Phiera red bullets|Phiera Der Tuphello|4 diagonal streams; circular red edge→white core bullet; Amount adds 1 per stream; blocked by walls|cd 1.4, ri 0.2, P 1→7|30|NEW (radial-gradient bullet)|w/Phiera_Der_Tuphello|
|W074|Eight the Sparrow blue bullets|Eight The Sparrow|as W073, blue edge; "one toward each corner of the screen"|-|30|covered via W073 + Palette Cycling|w/Eight_The_Sparrow|
|W075|Red / Blue hit flash|Phiera / Eight|tint #FF0000 or #0000FF 30 ms (HV#3/#2 inferred)|30 ms|30|NEW|HV|
|W076|Phieraggi rotating lasers|Phieraggi|4 blue lasers rotating clockwise; start a short distance from the player (blind spot); retract when idle; width ∝ Area; Speed<0 → CCW; permanent at ~−42% cd|N 4, hbd 0.2|30|NEW (beam)|w/Phieraggi|
|W077|Laser retract/extend|Phieraggi|length animates 0→L on fire and L→0 on retract|time **measure**|30|NEW|w/Phieraggi|
|W078|Song of Mana column|Song of Mana|vertical ellipse of sparkle particles bouncing between the edges of a vertical column centred on the player; moves with the player|D 0.5→2, A 1→2.75, hbd 1|15|NEW|w/Song_of_Mana|
|W079|Mannajja sound wave|Mannajja|5 concentric purple rings pulse outward in a vertical column; slow −5% per hit, floor 20%|A 6, D 2, cd 4.5|15|NEW (ring pulse)|w/Mannajja|
|W080|Gatti hexagram entry|Gatti Amari|cats enter from a hexagram at the screen edge|-|15|NEW|w/Gatti_Amari|
|W081|Cat wander|Gatti Amari|mostly straight lines, occasional heading change; claws nearby enemies|S 0.4→1|15|covered: Boids (wander)|w/Gatti_Amari|
|W082|Cartoon scuffle cloud|Gatti Amari|two cats close → large cartoon fight-cloud AoE lasting Duration|hbd 0.03 scuffle|15|NEW|w/Gatti_Amari|
|W083|Cat eats pickup|Gatti|cat over pickup → consume + effect (chicken buff, Nduja explode, clover 2x speed, Orologion freezes the cat)|-|-|NEW (logic)|w/Gatti_Amari|
|W084|Vicious Hunger eyeballs|Vicious Hunger|giant animated yellow cat eyes with a hexagram, straight paths; Evil flash; gold transmute|N 2, D 7, cd 8|15|NEW|w/Vicious_Hunger|
|W085|Evil hit flash|Vicious Hunger, Crimson Shroud|tint #110022 30 ms + HitMoon2 + HitBlack1|HV#11 (inferred)|30|NEW|HV|
|W086|Gold transmute|Vicious Hunger|pickup → gold coin; +0.05 s Gold Fever|-|15|NEW|w/Vicious_Hunger|
|W087|Shadow Pinion drill trail|Shadow Pinion|while moving: drills spawn behind the player and accelerate backward (damage zones)|ri 0.3, hbd 2|30|NEW|w/Shadow_Pinion|
|W088|Drill fire on stop|Shadow Pinion|on stop: all drills launch in the facing direction; dmg × (age_s + 1)|-|30|NEW|w/Shadow_Pinion|
|W089|Valkyrie flames → lasers|Valkyrie Turner|as W087 but flames; on stop, flames become burning lasers in the facing direction|A 1.4, S 3.5|30|covered: Doom Fire + W088|w/Valkyrie_Turner|
|W090|Clock Lancet beam|Clock Lancet|thin freezing beam, 12 clock directions fired one at a time clockwise, first at "1 o'clock"; 0 dmg, freezes|cd 2→1, D 2→6|30|NEW (beam)|w/Clock_Lancet|
|W091|TimeFreeze tint|Clock Lancet etc.|tint-fill #DDFFDD 60 ms, no sprite (NoDraw)|HV#6 (inferred)|30|covered: Palette Cycling (freeze tint)|HV|
|W092|Infinite Corridor white beam + rainbow aura|Infinite Corridor|white beam ×12; after a full rotation (12 o'clock), spinning rainbow aura → halve all on-screen HP|D 6, cd 1|15|covered: Palette Cycling (rainbow)|w/Infinite_Corridor|
|W093|Laurel shield bubble|Laurel|shield coloured by charges: blue 1, green 2, yellow 3; breaks at 0|cd 10→8|15|NEW|w/Laurel|
|W094|Crimson Shroud shield|Crimson Shroud|1 green, 2 transparent green + orange, 3 red|-|15|covered via W093|w/Crimson_Shroud|
|W095|Shroud retaliation blast|Crimson Shroud|a few shockwaves + transparent red circle + fast expand/retract inverted-colour circle slightly above the player|kb 20, A 2|30|NEW (invert-colour disc)|w/Crimson_Shroud|
|W096|Vento Sacro multi-slash|Vento Sacro|horizontal slashes in front; Speed = reach, Duration = linger; fires faster while moving|N 4→7, A 1.4→2, D 0.4|30|covered: Whip style|w/Vento_Sacro|
|W097|Walk-bonus trail|Vento Sacro|light-blue particles arc upward while walking; lifetime ∝ walking bonus|-|15|NEW|w/Vento_Sacro|
|W098|Fuwalafuwaloo slash ring|Fuwalafuwaloo|dark-red slashes in front + a circle of slashes cycling around the player; crit → explosion at the enemy|N 8, A 2|30|covered: Whip style + NEW ring cycle|w/Fuwalafuwaloo|
|W099|Bone ricochet|Bone|spinning bone, random dir, bounces off enemies/walls/edges until D|S 0.75→1.75, D 2→2.6|30|covered: W050 motion + RotSprite|w/Bone|
|W100|Cherry Bomb roll|Cherry Bomb|spinning bomb at nearest enemy, straight line, bounces, decelerates to a stop|S 1→1.6|30|covered|w/Cherry_Bomb|
|W101|Cherry firework burst|Cherry Bomb (40→60%)|shockwave + flower petals + firework|-|15|NEW|w/Cherry_Bomb|
|W102|Carréllo cart|Carréllo|horizontal cart in facing dir, bounces = Amount − 1, shatter explosion on the last|A 0.6, S 1→2|30|covered: Sprite Shatter|w/Carr%C3%A9llo|
|W103|Wheel sparks|Carréllo|mechanical sparks from the wheels while moving|-|15|NEW|w/Carr%C3%A9llo|
|W104|Flower spray|Celestial Dusting|flowers fired away from facing (89 sprites); unlimited pierce; bounce off walls; slow near the end of D|S 0.7→1.6|30|NEW|w/Celestial_Dusting|
|W105|Petal X burst|Celestial Dusting|at end of life, petals in a small X shape that deals damage|-|15|NEW|w/Celestial_Dusting|
|W106|Furniture rain|La Robba|furniture drops from the top-middle of the screen and bounces off enemies until D or offscreen|N 3→7, D 2→3|30|NEW|w/La_Robba|
|W107|Firework launch|Greatest Jubilee|fireworks burst in the top half of the screen; particles attracted to the player|N 1→5|15|covered: Boids (attractor)|w/Greatest_Jubilee|
|W108|Expanding burst hitbox|Greatest Jubilee|hitbox centred at the burst point grows over time; 1 hit per enemy per firework|-|15|NEW|w/Greatest_Jubilee|
|W109|Light-show finisher|Greatest Jubilee L9|light show along the bottom of the screen, 15 dmg, hbd 0.5|-|15|NEW|w/Greatest_Jubilee|
|W110|Bracelet sparkle cluster|Bracelet|cloudy sparkle projectiles (3) at a random enemy, ri 0.04|A 0.9, S 1.5, P 1→3|30|NEW|w/Bracelet|
|W111|Bi/Tri-Bracelet|Bi-, Tri-Bracelet|same, N 4/6, P 5/7, D 0.6/1.0|WJ|30|covered via W110|WJ|
|W112|Flame cone|Flames of Misspell|12 flame particles in a cone in the facing dir, ri 0.04, D 0.4|A 1→2|15|covered: Doom Fire|w/Flames_of_Misspell|
|W113|Ashes of Muspell|Ashes of Muspell|as W112, A 2, S 1.5, Evil flash, grows with kills|WJ|15|covered|WJ|
|W114|Victory Sword combo|Victory Sword|series of blue slashes at the nearest enemies|N 2→5, A 1.4→2|30|covered: Whip style|w/Victory_Sword|
|W115|Vertical finisher|Victory Sword L8|every 5th slash = vertical large slash|-|30|covered: Whip style rotated|w/Victory_Sword|
|W116|Retaliation 6-slash|Victory Sword|six slashes around the player, every 0.6 s max|-|30|NEW|w/Victory_Sword|
|W117|Icicle fan + shockwave|Santa Javelin|icicles drop from the sky in a fan; blue shockwave AoE on impact|cd 6.5, ri 0.125|30|NEW|w/Santa_Javelin|
|W118|Seraphic Cry|Seraphic Cry|Yellow flash HV#14 (#FFFC99) inferred; N 3, A 1.5|WJ|30|covered via W117|WJ, HV|
|W119|Phas3r colour beams|Phas3r|horizontal beams centred on an enemy, colour order red, yellow, blue, magenta (orange replaces red after shot 1); Area widens horizontally only; Amount ×4|N 1→5|30|NEW (beam)|w/Phas3r|
|W120|Photonstorm|Photonstorm|as W119, Light flash, A 2.5, N 6, 2-10x projectiles by Luck|WJ|30|covered via W119|WJ, w/Phas3r|
|W121|Glass Fandango blade|Glass Fandango|moving: short translucent blue blade forward; standing: 6 directions|A 0.7→1|30|NEW|w/Glass_Fandango|
|W122|Celestial Voulge|Celestial Voulge|N 6, S 6, freeze chance; turns Orologions|WJ|30|covered via W121|WJ|
|W123|Ammo Appalate burst|Ammo Appalate|burst of 3 at the closest enemy in front; stockpiles if no target|N 3→8, P 1→7|30|covered: Knife style|w/Ammo_Appalate|
|W124|Gunastrophe|Gunastrophe|"fires all the guns across the screen"|D 3, cd 6|30|NEW (**measure**)|WJ|
|W125|Unearthly Bolt / Spirit Disturbance|EX_FLIK1/2|Spirit flash (HV#5 inferred); crits make damaging zones|hbd 0.12|30|NEW (**measure**)|WJ|
|W126|Pako Battilia / Mazzo|BATTILIA/2|N 10/16, P 2/20, S 0.4; extra fire on HP loss|WJ|30|NEW (**measure**)|WJ|
|W127|Gaea zones|Gaze/Embrace of Gaea|ground zones, defang chance|WJ|15|NEW (**measure**)|WJ|
|W128|Magi/Kyra-Stones|EX_MAGISTONE1/2|S 1.2/1.8, kb 1|WJ|30|NEW (**measure**)|WJ|
|W129|Penshin Tonno family|EX_PENSHIN_*|7 variants, all Light flash|WJ|30|NEW (**measure**)|WJ|
|W130|Grant Knife|FOLLOWER_KNIFE1/2|hbd 0.03, P 1/3|WJ|30|covered: Knife style|WJ|
|W131|Gemini counterparts|Cygnus, Zhar Ptytsia, Red Muscle, Twice Upon a Time, Flock Destroyer, Levelin'EEE|same algorithm as the parent, different flash (TimeFreeze, Fire, Red, Blue, Dark, Light); Red Muscle angles more vertical; Zhar zone farther out|WJ|-|covered via parent|WJ, w/Phiera_Der_Tuphello, w/Ebony_Wings|
|W132|Tint-fill flash shader|all|fragment: out = mix(tex, vec4(tint, tex.a), 1) while t < dur (solid fill, alpha kept)|dur 30/60/120|30|NEW (core)|HV|
|W133|HitStar2 / HitCross / HitMoon contact sprite|all|1-shot sprite at the contact point, lifetime about the flash duration (inferred)|-|30|NEW (atlas)|HV|
|W134|Shockwave3 impact ring|Default/Blue|expanding ring at enemy centre|-|30|covered: Cooldown Sweep (ring) partial|HV|
|W135|Damage number|all|number pops at the enemy; option-toggleable; crits styled differently (**measure**); possible ±5 display jitter (disputed)|-|30|covered: Damage Numbers|w/Options, ST1|
|W136|Weapons screenshake|heavy weapons|camera shake on some weapon events; option "Weapons ScreenShake"|amp **measure**|30|NEW|w/Options|
|W137|Disable blood option|kills|toggles blood VFX|-|-|NEW (option)|w/Options|
|W138|Pool-limit cull|all|projectile spawn refused when active count ≥ poolLimit (sets on-screen density)|per WJ|-|NEW (logic)|WJ, w/Thousand_Edge|
|W139|Projectile z-order|all|ground zones (Santa Water, Garlic, glyphs) < enemies < projectiles < player < hit sprites < damage numbers (**inferred**, measure)|-|-|NEW (layering)|inferred|
|W140|Level-up immediate fire|all|levelling a weapon resets it, so it fires immediately|-|-|NEW (logic)|ST2|
|W141|Blood Astronomia ground zones|any weapon w/ Arcana XXI|planet-like orbiting zones|-|15|out of scope (Arcana)|w/Song_of_Mana|
|W142|Iron Blue Will bounce|Knife, Axe, guns|bounce off enemies up to 3x, upward momentum reversed horizontally (Axe)|-|30|out of scope (Arcana)|w/Axe|

Count: 142 entries (W001-W142). 64 are covered fully or partly by our existing effects, 9 are covered via another entry in this catalog, 67 are NEW, and 2 are out of scope (Arcana).

## 2. QA checklist per weapon (pass/fail against a 1.16.107 capture)
Each row is a check against data. Pixel and colour checks marked "measure" first need a reference capture (60 fps, nearest-neighbour, same zoom as ours).

**Global**
- [ ] A hit flash is a solid tint-fill (the silhouette goes fully flat colour), not multiply. Default lasts 120 ms (about 7 frames at 60 fps); Dark, Evil, Red and Blue last 30 ms (2 frames). HV
- [ ] Each weapon uses the HV colour in the table above (verify the inferred map: Whip white, Bloody Tear #220044, Fire Wand red, Heaven Sword #FFEEEE, Clock Lancet #DDFFDD).
- [ ] The Damage Numbers option hides numbers but keeps recovery numbers (0.9.0 fix). w/Options
- [ ] With Flashing VFX off, there's no Pentagram or Gorgeous Moon screen flash.
- [ ] Projectiles never exceed poolLimit (Whip 30, Wand 60, Knife 70, Axe 70, Cross 100, Bible 50, Fire Wand 30, Garlic 50, Santa Water 20, Runetracer 50, Lightning 50). WJ
- [ ] Levelling a weapon makes it fire immediately.

**Whip / Bloody Tear**
- [ ] Cooldown 1.35 s (81 frames at 60 fps); 2nd slash 0.1 s after the 1st.
- [ ] Lv2: two slashes on opposite sides, the 2nd higher on screen than the 1st.
- [ ] Flipping L/R between slashes puts both on one side.
- [ ] Lv8 slash is 120% the size of Lv1 (measure px; ratio must be 1.2 ±1 px).
- [ ] Bloody Tear: red slash, 130% size, 2 slashes from the start, +8 HP number on a crit, no more than once per second.

**Magic Wand / Holy Wand**
- [ ] Missile is blue and flies straight to the enemy nearest at its spawn time.
- [ ] Lv8: 4 missiles, 0.1 s apart, cd 1.0 s; each can hit 2 enemies.
- [ ] A missile dies on walls.
- [ ] Holy Wand: cd 0.5 s, double missile speed, 4 per volley, volleys overlap.

**Knife / Thousand Edge**
- [ ] Fires in the facing direction; with keyboard only 8 directions; sprite rotated to match.
- [ ] Lv8: 6 knives per volley at 0.04 s spacing, pierce 3.
- [ ] Thousand Edge: cd 0.35 s, 0.05 s spacing, speed ×1.5 (looks like a continuous stream), max 70 on screen.

**Axe / Death Spiral**
- [ ] First axe goes straight up and falls back through the player's column; spins.
- [ ] Axes 2 and 3 go toward facing in wider arcs, 0.2 s apart.
- [ ] Axe sprite = Area × 1.3. With Speed reduced, apex height drops (approximately linearly, measure).
- [ ] Death Spiral: 9 red scythes per cast, 0.05 s apart, evenly spread around 360° (verify the 40° spacing), no gravity, pierce everything, speed 0.8.

**Cross / Heaven Sword**
- [ ] Aims at the nearest enemy, decelerates, reverses, leaves the screen on the far side; spins.
- [ ] Lv3/Lv6 each give +25% Speed, so the turnaround is farther.
- [ ] Heaven Sword: giant sword, one per 3.3 s, enemies knocked back far (kb 6), #FFEEEE flash with cross-shaped hit sprite.

**King Bible / Unholy Vespers**
- [ ] Books orbit clockwise, evenly spaced (N=4 → 90°).
- [ ] Active 3 s, absent 3 s at Lv1 (cycle 6 s); Lv8 active 4 s.
- [ ] Ring radius grows with Area; book sprite grows too.
- [ ] Occasional falling pages (blue bibles); Vespers uses red symbols and purple pages and never disappears at default stats.
- [ ] The same enemy is not re-hit by the same book within 1.7 s.

**Fire Wand / Hellfire**
- [ ] 3 fireballs in an arc toward a random enemy, near-simultaneous (0.02 s), slow (0.75).
- [ ] Extra Amount adds balls at the arc ends, not the middle.
- [ ] Fireballs die on walls and after 1 hit.
- [ ] Hellfire: 2 large meteors 0.2 s apart, pierce everything, pass through walls.

**Garlic / Soul Eater**
- [ ] 3 rotating concentric circles; radius at Lv8 = 2x Lv1.
- [ ] Each enemy is hit on entry, then not again until the cooldown (1.3 s at Lv1, 1.0 s at Lv8).
- [ ] Soul Eater: black aura at 3x radius, particles pulled inward.

**Santa Water / La Borra**
- [ ] Bottle falls from above and shatters; puddle + blue flames for 2 s; 0.3 s between bottles.
- [ ] The first bottle lands at the nearest enemy (until Amount ≥ 4), then a clockwise ring.
- [ ] Lv8 flame radius = 1.8x Lv1.
- [ ] La Borra: 4 pools, 4 s, creeping toward the player and growing to a cap.

**Runetracer / NO FUTURE**
- [ ] Diamond runes in random directions, bounce off screen edges, live 2.25 s, each a different trail colour.
- [ ] NO FUTURE: cyan laser, fast (2.8x); test-card disc + purple particles at each bounce; explosion around the player when hit (≤ 2/s).

**Lightning Ring / Thunder Loop**
- [ ] 2 bolts at Lv1 to random enemies, 0.05 s apart; 6 at Lv8; hit radius 4x at Lv8.
- [ ] Thunder Loop: orange circle + shrinking 2nd circle, second strike at the same point; 6 bolts, Area 4.

**Pentagram / Gorgeous Moon**
- [ ] Purple glyph with gold lining that's more detailed at higher level; cd 90 s → 60 s.
- [ ] Damage numbers 655-665 on low-HP enemies.
- [ ] Moon: 20 beams with intervals 0.75/0.375/0.2 s over 9.1 s; crescent erase at 12.1 s; then gem vacuum.

**Peachone / Ebony Wings / Vandalier**
- [ ] Bird trails the player; the zone circles at fixed radius; Peachone and Ebony rotate opposite ways.
- [ ] 4 sets × 4 bombs 0.025 s apart; each set lands where the zone was at set start.
- [ ] Area enlarges the bomb blasts, not the zone circle.
- [ ] Vandalier: multicolour bird, 2 zones, 20 bombs per set, rainbow hit sprite.

**Others** (one line each)
- [ ] Phiera: 4 diagonal red→white-core bullets; Eight: same, blue; Phieraggi: 4 rotating blue lasers with a blind spot near the player.
- [ ] Song of Mana: vertical column of bouncing sparkles centred on the player. Mannajja: 5 purple rings.
- [ ] Gatti: cats from an edge hexagram, fight cloud when two meet. Vicious Hunger: yellow eyeballs.
- [ ] Shadow Pinion/Valkyrie: drills (or flames) trail behind while moving and launch forward on stop.
- [ ] Clock Lancet: beam 1 at 1 o'clock, then clockwise one per shot. Corridor: white beam + rainbow aura after 12.
- [ ] Laurel: blue/green/yellow by charge. Shroud: green / green+orange / red; retaliation has an inverted-colour disc.
- [ ] Vento: forward slashes + light-blue walk particles. Fuwalafuwaloo: dark red + a cycling ring of slashes.
- [ ] Bone, Cherry, Carréllo, Dusting, Robba, Jubilee, Bracelet, Misspell, Victory Sword, Javelin, Phas3r, Fandango, Ammo: per catalog rows W099-W123.

## 3. Visual hierarchy notes (weapons)
1. **Hit feedback beats projectile art.** The shipped HV table makes enemy feedback a full-silhouette tint-fill: 30 ms for fast multi-hit families (Dark/Evil/Red/Blue/Yellow), 60 to 120 ms for single big hits (Default, Light, Fire). At 300 enemies the flash, not the projectile, tells the player what's being hit. Keep that ordering: a short flash for spam weapons so the crowd doesn't strobe solid colour, a longer flash for slow heavy hits. (HV, inferred reading)
2. **Colour families encode element.** White/default for physical (Whip, Knife, Axe), red/fire, dark purple (#220044) for "dark" evolutions, near-white pink (#FFEEEE) for light/holy, rainbow sprite for Prism. Evolutions often switch their weapon's family (Whip white → Bloody Tear dark; Cross → Heaven Sword light). Our palette pass must not reuse these flash colours for enemy tints. (HV, WJ)
3. **Layering (inferred, verify):** ground zones (Santa Water, La Borra, Garlic, glyphs, Thunder Loop circles) at the bottom; then enemies; then projectiles; then the player; then contact sprites; then damage numbers on top. Big orbits (Bible/Vespers) and the Phieraggi lasers must stay readable over enemies, so draw them above enemies.
4. **Density control is the pool limit.** VS doesn't thin effects at high counts. It caps per-weapon active projectiles via poolLimit (20 to 200). Our renderer should honour the same caps rather than adding LOD. Speed reduces the on-screen count because projectiles exit sooner. (WJ, w/Thousand_Edge, w/Holy_Wand)
5. **Translucency is the perf hazard.** The devs noted slowdowns from "a lot of semi-transparent pixels" in the Electron build. Puddles, auras and Vespers are large translucent fills. Budget them at 15 fps and use dithered alpha (our Dither Bloom) instead of true blending where possible. (PN028)
6. **Lv1 vs Lv8 vs evolved readability:** levels mostly change size (Area), count (Amount) and cadence, not art. Evolutions swap the sprite and flash family and jump the counts (Holy Wand 4 per 0.5 s, Death Spiral 9, Thunder Loop 6). Our QA should check counts and sizes per level, and check art only at evolution.
7. **Telegraphs only where damage is delayed:** Thunder Loop's closing circle and Peachone's lit zone are the only pre-hit markers in the base set. Everything else hits on contact.

## Open items (need capture)
- Every sprite px size, frame count and fps, and rotation speed (Axe, Cross, Heaven Sword, Bone, Cherry).
- Gravity constant and launch velocity for Axe; Cross turnaround distance per Speed.
- Fire Wand arc angle; Knife lateral spread; Death Spiral exact angular spacing.
- Bible orbit radius in px, and ω at Speed 1.
- Thunder Loop second-strike delay.
- Confirming the HV index-to-name map.
- Damage number font, colour for crit, rise distance and lifetime.
