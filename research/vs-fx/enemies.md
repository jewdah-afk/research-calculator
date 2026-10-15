# Vampire Survivors v1.16: enemies, waves, bosses, swarms, events (FX research)

Scope: base game only, focused on Mad Forest. Numbers come from the shipped data rip (Enemy.json and Stage.json, v1.16) or from vampire.survivors.wiki raw pages fetched 2026-10-15. Anything marked **inferred** is not sourced, so don't treat it as fact. Neither source gives the visual timing (flash length, animation fps, freeze RGB). Measure those from gameplay video before you lock them in.

## Source keys
| Key | URL |
|-|-|
| SD | https://raw.githubusercontent.com/SurvivatonsAndMore/VampireSurvivorsFiles/main/Data/Vampire%20Survivors/Enemy.json and .../Stage.json (shipped v1.16 data, fetched) |
| ED | https://vampire.survivors.wiki/w/Enemies (spawning, waves, caps, skills) |
| WK | https://vampire.survivors.wiki/w/Knockback |
| WF | https://vampire.survivors.wiki/w/Freeze |
| WO | https://vampire.survivors.wiki/w/Orologion |
| WRO | https://vampire.survivors.wiki/w/Rosary |
| WB | https://vampire.survivors.wiki/w/Bat_Swarm |
| WG | https://vampire.survivors.wiki/w/Ghost_Swarm |
| WFW | https://vampire.survivors.wiki/w/Flower_Wall_(event) and /w/Flower_Wall |
| WR | https://vampire.survivors.wiki/w/The_Reaper |
| WM | https://vampire.survivors.wiki/w/Mantichana |
| WV | https://vampire.survivors.wiki/w/Venus |
| WP | https://vampire.survivors.wiki/w/Pipeestrello (lists animated and death GIFs) |
| WGEM | https://vampire.survivors.wiki/w/Experience_Gem |
| WC | https://vampire.survivors.wiki/w/Curse |
| WD | https://vampire.survivors.wiki/w/Defang |
| WL | https://vampire.survivors.wiki/w/Light_source |
| W-CH | https://vampire.survivors.wiki/w/Treasure_Chest |
| W-MED | https://vampire.survivors.wiki/w/Medusa_Swarm |
| W-SW | https://vampire.survivors.wiki/w/Swarm, /w/Circle |
| W-GHO | https://vampire.survivors.wiki/w/Ghost, /w/Mad_Forest, /w/Garlic, /w/Clock_Lancet |
| GG | https://www.game.guide/vampire-survivors-normal-stage-guide (says "about 100 flowers"; unverified) |
| ST | https://steamcommunity.com/app/1794680/discussions/0/3734079567829009940, .../4634861275507103070, .../3436829654718934026 |
| COH | https://coherence.io/blog/tradecraft/vampire-survivors-online-coop-case-study (enemies are Phaser dynamic physics bodies) |
| WIKIP | https://en.wikipedia.org/wiki/Vampire_Survivors (Phaser before v1.6, Unity from v1.6) |
| misc | https://www.gfinityesports.com/guides/vampire-survivors-death-how-to-beat-final-boss, https://rogueranker.com/?p=2704 (Reaper HP; judged unreliable), https://bugtracker.arcengames.com/view.php?id=5573 (additive tint can only flash white), https://forum.gdevelop.io/t/sprite-flash-solid-white-when-damaged/29507, https://80.lv/articles/vampire-survivors-will-get-new-engine-dlcs-updates-in-2023, https://cyberpost.co/?p=474205 |

**Blocked or unavailable:** vampire-survivors.fandom.com returned HTTP 403 to curl. The GitHub API tree for SurvivatonsAndMore/VampireSurvivorsFiles is not enabled for this session, so only known raw paths can be fetched and the atlas or frame-timing files could not be listed. YouTube was not reached. Reddit and Steam returned 200 but were not mined in depth.

## Shipped stats that drive the FX (SD, raw values; the wiki shows HP at 10x)
| id | maxHp | speed | knockback taken | maxKB | deathKB | idleFrames | end | scale | alpha | res_Freeze | skills | variants |
|-|-|-|-|-|-|-|-|-|-|-|-|-|
| BAT1 | 0.1 | 140 | 1 | 3 | 2 | 4 | 29 | 1 | 1 | - | - | 1 |
| BAT2 | 0.5 | 140 | 1 | 3 | 2 | 4 | 29 | 1 | 1 | - | - | 1 |
| BAT3 | 0.5 | 140 | 1 | 3 | 2 | 4 | 16 | 1 | 1 | - | - | 1 |
| BAT4 | 5 | 140 | 1 | 3 | 2 | 4 | 29 | 1 | 1 | - | HP_x_Level | 1 |
| BAT5 | 5 | 140 | 1 | 3 | 2 | 4 | 29 | 1 | 1 | - | HP_x_Level | 1 |
| BATSWARM | 0.1 | 700 | 1 | 3 | 2 | 4 | 16 | 1 | 1 | - | Fixed_Direction | 3 |
| GHOST | 1 | 200 | 0 | 3 | 0 | 4 | 11 | 1 | 0.5 | - | - | 1 |
| GHOSTSWARM | 1 | 700 | 0 | 3 | 0 | 4 | 11 | 1 | 0.5 | - | Fixed_Direction | 1 |
| ZOMBIE | 1 | 100 | 0.8 | 3 | 4 | 4 | 20 | 1 | 1 | - | - | 3 |
| SKELETON | 1.5 | 100 | 1 | 3 | 5 | 4 | 18 | 1 | 1 | - | - | 6 |
| MUDMAN1 | 7 | 100 | 0.3 | 3 | 2 | 4 | 29 | 1 | 1 | - | - | 1 |
| MUDMAN2 | 15 | 100 | 0.3 | 3 | 2 | 4 | 29 | 1 | 1 | - | - | 1 |
| FLOWER | 3 | 20 | 1 | 3 | 2 | 4 | 29 | 1 | 1 | - | HP_x_Level | 2 |
| WEREWOLF | 18 | 130 | 0.8 | 3 | 7 | 4 | 21 | 1 | 1 | - | - | 1 |
| XLBAT | 27 | 140 | 0.1 | 3 | 2 | 4 | 17 | 1 | 1 | - | - | 1 |
| XLMANTIS | 50 | 80 | 0 | 3 | 0 | 4 | 29 | 1 | 1 | - | - | 1 |
| XLFLOWER | 50 | 80 | 0 | 3 | 0 | 4 | 29 | 1 | 1 | - | - | 1 |
| BOSS_XLBAT | 50 | 140 | 0 | 1 | 5 | 4 | 17 | 1.5 | 1 | 1 | HP_x_Level | 1 |
| BOSS_XLMANTIS | 15 | 160 | 0 | 1 | 5 | 4 | 23 | 1.5 | 1 | 1.1 | HP_x_Level | 1 |
| BOSS_XLFLOWER | 15 | 160 | 0 | 1 | 1 | 4 | 29 | 1.5 | 1 | 1.1 | HP_x_Level | 1 |
| BOSS_WEREWOLF | 20 | 130 | 0.1 | 1 | 7 | 4 | 21 | 1.5 | 1 | - | HP_x_Level | 1 |
| BOSS_XLDEATH | 65535 | 1200 | -0.5 | 0 | 0 | 8 | 29 | 1.5 | 1 | 1 | HP_x_Level | 1 |
| BOSS_XLDEATH2 | 65535 | 1200 | -0.5 | 0 | 0 | 8 | 29 | 1.5 | 1 | 1 | HP_x_Level | 1 |

Notes: 416 of the 579 enemies have idleFrameCount 4, and the Reaper has 8. Skill counts across the data: HP_x_Level 220, Fixed_Direction 74, Medusa (floaty) 17, Self_Destruct 11. My guess is that `end` is the last frame index of the death animation (**inferred**).

## 1. Effect catalog (109 entries)
FPS tier means how often the effect must update: 30 for motion and flashes, 15 for death and boss effects, 8 for idle loops. "-" means the effect is static or pure logic. "covered" names one of our existing 89 effects. "NEW" means a new effect, mostly cheap sprite logic.

|#|Name|VS usage|Algorithm|Params|FPS tier|Covered by|Sources|
|-|-|-|-|-|-|-|-|
|E001|Walk cycle loop|every walker|frame = floor(t*animFps) mod idleFrameCount over frames <base>_0..N-1|idleFrameCount 4 (416/579 enemies), 5 (38), 8 (24 incl. Reaper), 2,3,6,30,31 rare; animFps unknown, start 8 fps|8|NEW (sprite-sheet player)|SD; fps INF|
|E002|Per-instance phase offset|all crowds|phase0 = rand(0..N-1) at spawn so 300 bats do not flap in lockstep|uniform int|8|NEW|INF|
|E003|Variant pick per spawn|ZOMBIE(3), SKELETON(6), FLOWER(2), BATSWARM(3), STAGEKILLER(16)|frameNames[] random index at spawn|counts from frameNames length|-|NEW|SD|
|E004|Reaper 8-frame idle|BOSS_XLDEATH|same loop, 8 frames|idleFrameCount 8|15|NEW|SD|
|E005|Polter 3-frame idle|POLTER (Inlaid Library)|loop 3 frames|idleFrameCount 3|8|NEW|SD|
|E006|Horizontal flip toward player|all homing enemies|flipX = (player.x < self.x) xor artFacesLeft; evaluate each frame, no hysteresis needed but add 2px deadzone to stop jitter when directly above|deadzone 2px INF|30|NEW|INF|
|E007|Fixed-direction flip|BATSWARM, GHOSTSWARM, MEDUSA1|flip once at spawn from velocity sign, never re-evaluated|skill Fixed_Direction (74 entries)|-|NEW|SD|
|E008|Floaty sine path|MEDUSA1 (Medusa skill)|pos += dir*v*dt; perpendicular offset A*sin(2pi f t)|A,f unknown; MEDUSA1 speed 240|30|covered: Lissajous-like orbit (partial)|ED,SD|
|E009|Idle bob for flyers|bats, ghosts|none beyond frames; do NOT add procedural bob (not in source)|-|-|n/a|INF|
|E010|Alpha 0.5 ghost|GHOST, GHOSTSWARM|sprite alpha 0.5 constant|alpha 0.5|-|NEW (trivial)|SD|
|E011|Boss 1.5x scale|BOSS_XLBAT, BOSS_XLMANTIS, BOSS_XLFLOWER, BOSS_WEREWOLF, Reaper|nearest-neighbour scale 1.5 (non-integer => uneven pixels; use RotSprite/nearest)|scale 1.5|-|covered: RotSprite (for clean upscaling)|SD,WM,WV|
|E012|Inverse-mode tint|Mad Forest Inverse|multiply tint 0x8888EE (8947950) on stage|tint 8947950|-|covered: Palette Cycling/LUT|SD(Stage.json)|
|E013|DefaultSpriteTintHue material|5 enemies|hue-shift material variant|materialType DefaultSpriteTintHue|-|covered: Palette Cycling|SD|
|E014|Colour variants via tint|Pipeestrello-3 Yellow/Green/Purple|same frames, palette swap|bVariants list|-|covered: Palette Cycling|WP|
|E015|Collider override|XLBAT|circle collider radius 0.3 (units), offsetY -8 px|radius 0.3, offY -8|-|NEW|SD|
|E016|Hit flash white|every damage tick|draw sprite silhouette (rgb=1, keep alpha) then return; additive tint goes to white|duration unknown; target 2 frames @60 (~33 ms) INF|30|NEW (flagged #32 in NEW_ALGORITHMS)|INF; additive-white note: arcengames bugtracker 5573|
|E017|Flash re-trigger rule|multi-hit weapons|restart timer on each hit, no stacking|-|30|NEW|INF|
|E018|Damage number pop|every hit (option)|spawn text at enemy top, rise + fade|see weapons research|30|covered: Damage Numbers|INF|
|E019|Knockback impulse|every hit|for 120 ms velocity = -moveDir*speed*kbMult; kbMult = weapon.knockback * enemy.knockback|120 ms (wiki [verify]); enemy knockback 0..1, Reaper -0.5|30|NEW|WK,SD|
|E020|Knockback cap|all|clamp accumulated knockback multiplier <= maxKnockback|maxKnockback 3 typ., bosses 1, Reaper 0|30|NEW|SD,WK|
|E021|Garlic KB ramp|Garlic hits|enemy.knockback += 0.3 per hit until maxKnockback (unless debuff-immune)|+0.3|30|NEW|WK|
|E022|Negative knockback pull|Reaper|kbMult -0.5 -> enemy pulled toward player on hit|knockback -0.5|30|NEW|WR,SD|
|E023|Knockback-immune|GHOST, XLMANTIS, XLMUMMY, XLFLOWER, bosses|knockback 0 -> no displacement but still flash|0|-|NEW|SD|
|E024|Death knockback fling|every death|corpse launched along hit dir scaled by deathKB while death anim plays|deathKB 0..7 (Werewolf 7, Skeleton 5, Zombie 4, Bat 2, Ghost 0)|30|NEW|SD; motion curve INF|
|E025|Hit squash|optional polish|NOT in VS; skip for 1:1|-|-|n/a|INF|
|E026|Freeze tint blue|Clock Lancet, Orologion|multiply sprite by blue; stop anim frame advance and velocity|colour unknown, sample from screenshot; INF ~#6CA0FF|-|NEW|WF,WO|
|E027|Freeze anim halt|frozen enemies|frame index held|-|-|NEW|WF|
|E028|Frozen push|frozen enemies|player body still separates/pushes them|-|30|NEW|WF,WO|
|E029|Orologion ring|pickup|spinning blue ring around player, 10 s, then fades; newly spawned enemies also frozen|10 s|15|covered: Palette Cycling + ring (partial) / NEW ring|WO|
|E030|Freeze resistance gate|bosses|skip freeze if res_Freeze > weapon chance (1 Lancet, 0.25 Jail)|boss res 1.1; Orologion ignores|-|NEW (logic)|WF,SD|
|E031|Freeze unfreeze fade|Orologion end|tint lerp back as ring fades|duration INF|15|NEW|WO|
|E032|Ice crystal overlay|DLA freeze|NOT in VS base; optional|-|-|covered: DLA frost (#9/#40) only if style allowed|INF|
|E033|Death animation frames|all enemies|play frames after idle range up to index end; wiki hosts per-enemy (death).gif|end field: BAT1 29, BAT3 16, GHOST 11, ZOMBIE 20, SKELETON 18, WEREWOLF 21, XLBAT 17, BOSS_XLMANTIS 23; meaning of end INF|15|NEW|SD,WP,WV|
|E034|Death fade|all|alpha 1->0 over death anim tail|INF|15|covered: Ordered-dither fade (#27) or alpha|INF|
|E035|Death dissolve|optional|blue-noise dissolve|-|15|covered: Pixel dissolve (#29)|INF|
|E036|Sprite shatter on boss death|optional|NOT confirmed in VS|-|15|covered: Sprite Shatter|INF|
|E037|Rosary screen clear|Rosary|instant kill all on screen; each plays normal death|Reaper immune|15|NEW (flash overlay)|WRO|
|E038|Rosary white flash|Rosary|full-screen white flash|INF|30|covered: Dither Bloom|WRO, INF|
|E039|Corpse layer|deaths|dead sprites drawn under live enemies, no collision|-|-|NEW|INF|
|E040|Corpse budget|mass kills|cap simultaneous death anims (e.g. 200) skip extras to last frame|INF|-|NEW|INF|
|E041|Gem spawn at corpse|every kill with xp>0|gem at enemy pos, small pop offset|offset INF|30|NEW|WGEM|
|E042|Gem colour tiers|gems|blue <=2 xp, green <=9, red >9|thresholds 2/9|-|NEW|WGEM|
|E043|Gem cap merge|>400 gems|new xp goes into single red gem|400|-|NEW|WGEM|
|E044|Gem magnet pull|pickup|inside Magnet radius gem accelerates to player|radius from player stats|30|NEW|WGEM|
|E045|Gem merge physics|idle player|gems merge when player idle (patched 0.2.x)|-|8|NEW|WGEM|
|E046|Gem shimmer|gems|frame loop sparkle|INF|8|covered: Palette Cycling|WGEM(gallery)|
|E047|Chest drop from boss|bosses|chest spawns at boss pos; 1/3/5 item chances per wave|Mad Forest table|-|NEW|SD,[W-CH]|
|E048|Chest arrow indicator|offscreen chest|edge arrow pointing to chest|INF|30|NEW|INF|
|E049|Light source smash|braziers|10 hp, drops pickup; anim gif|10 hp; Forest freq 1 s, chance 10->50%, max 10|8|covered: Doom Fire (flame) + rigid debris|WL,SD|
|E050|Separation|all walkers|Phaser dynamic physics bodies push each other (circle overlap resolve)|body radius per sprite|30|covered: Boids (separation term only)|CO|
|E051|Seek player|homing|v = normalize(player-pos)*speed*stageEnemySpeed(1.1 Forest)|speeds BAT 140, ZOMBIE 100, GHOST 200|30|covered: Boids (seek)|SD,ED|
|E052|Swarm shove|BAT/GHOST swarm|swarm bodies push other enemies along path|-|30|NEW|WB,WG|
|E053|Spatial hash|300-500 enemies|uniform grid cell = 2x max radius for neighbour queries|INF|30|NEW|INF|
|E054|Y-sort|all|draw order by y (feet)|-|30|NEW|INF|
|E055|Shadow ellipse|entities|VS has no per-enemy shadow in base Forest (verify)|-|-|covered: Drop shadow (#34) optional|INF|
|E056|Off-screen spawn ring|periodic spawns|spawn just outside screen rect: pick random edge point of view rect expanded by margin|margin INF (~1 sprite)|-|NEW|ED|
|E057|Wave quota fill|each tick|if alive < minimum spawn until quota; else spawn one of each wave type|Forest min 15..|-|NEW|ED,SD|
|E058|Spawn interval|waves|interval/curse|Forest 1.0/0.5/0.25/1.5 s|-|NEW|WC,SD|
|E059|Spawn cap 300|periodic|no periodic spawns when alive>=300; bosses/events still spawn|300|-|NEW|ED|
|E060|Hard cap 500|all|max 500 enemies on screen|500|-|NEW|WC|
|E061|Despawn/relocate|far enemies|enemies despawn when far; bosses teleport back on screen|distance INF|-|NEW|ED|
|E062|Starting spawns|stage start|spawn 10 (hyper 15)|10/15|-|NEW|SD|
|E063|Spawn fade-in|spawn|not visible (off-screen); none|-|-|n/a|INF|
|E064|Bat Swarm|Forest 2:05..29:03|50 BATSWARM in fixed line across map, speed 700|50 units, speed 700, hp 0.1, power 1; delay 5000/15000/1200/2300 ms|30|covered: Boids (flock offset) + NEW line emitter|WB,SD|
|E065|Bat swarm lane math|Bat Swarm|pick side, spawn 50 within band perpendicular to dir; all v = dir*700|band width INF|30|NEW|WB,INF|
|E066|Bat swarm sprite mix|Bat Swarm|frames from Bat1/Bat2/Bat3|3 frames sets|-|NEW|SD|
|E067|Ghost Swarm|Forest 13:01/13:02, 27:00-27:03|20 GHOSTSWARM fixed direction speed 700 alpha 0.5|20 units; repeats 20 / 19 @3000 ms|30|NEW line emitter|WG,SD|
|E068|Ghost line formation|Ghost Swarm|20 ghosts placed in a line, move straight|spacing INF|30|NEW|WG|
|E069|Flower Wall ring|Forest 5:00(30 s),10:00(60 s),15:00(80%,30 s),25:10(10 s x5)|N FLOWER placed on ellipse around player, creep inward at speed 20|~100 flowers (game.guide, unverified), speed 20, power 1|30|NEW (parametric ellipse)|WFW,SD,[GG]|
|E070|Flower wall expiry|Flower Wall|after duration flowers despawn|30000/60000/10000 ms|-|NEW|SD|
|E071|Flower wall HP x Level|FLOWER|hp scales with player level at spawn|HP_x_Level|-|n/a|SD|
|E072|Cycle complete / Reaper|30:00|CYCLE_COMPLETE spawns Reaper, then one more each minute|1/min|-|NEW|SD,WR,[ST]|
|E073|Reaper rush|Reaper|speed 1200, power 65535, passes walls in DEATH2|speed 1200|30|NEW|SD,WR|
|E074|Reaper screen-dark|Reaper|INF stage darkens; verify via video|-|15|covered: Dither Bloom (vignette)|INF|
|E075|Mantichana boss|Forest 5:00|BOSS_XLMANTIS 1.5x, speed 160, res_Freeze 1.1|hp 15 raw x level|-|NEW|WM,SD|
|E076|Giant Blue Venus|Forest 25:00|BOSS_XLFLOWER 1.5x blue tint, speed 160, power 30|xp 50|-|covered: Palette Cycling|WV,SD|
|E077|Venus normal|Forest 21:00+|XLFLOWER 4 frames|-|8|NEW|WV|
|E078|Giant bat bosses|BAT4/BAT5/XLBAT|wave bosses with HP x Level|BAT4 xp 30|-|NEW|SD|
|E079|Werewolf boss|Forest|BOSS_WEREWOLF scale 1.5 deathKB 7|-|-|NEW|SD|
|E080|Boss teleport-back|bosses|if offscreen far: reposition to screen edge|-|-|NEW|ED|
|E081|Boss telegraph|bosses|base VS bosses have NO telegraph; they just walk/rush|-|-|n/a|ED (no mention), INF|
|E082|Event chance with luck|events|chance/totalLuck per repeat|-|-|NEW|ED|
|E083|Defang green|Defang|defanged enemies drawn green (toggle)|INF colour|-|covered: Palette Cycling|WD|
|E084|Medusa wall/swarm|Inlaid Library|MEDUSA_SWARM/WALL fixed dir + floaty|MEDUSA1 speed 240|30|NEW|SD,[W-MED]|
|E085|Polter self-destruct|POLTER|skill Self_Destruct|-|15|NEW|SD|
|E086|Atlas batching|all|single texture enemies_Universal / enemies atlases|2 atlases|-|NEW|SD textureName|
|E087|Off-screen cull|render|skip draw if AABB outside view+margin|margin = largest sprite|-|NEW|INF|
|E088|Anim LOD|300+|update frames at 8 fps tier for > 200 enemies|INF|8|NEW|INF|
|E089|Flash budget|mass hits|flash is cheap (tint swap) - no cap|-|-|NEW|INF|
|E090|Integer camera|render|snap camera and sprites to integer px to avoid shimmer|-|-|NEW|INF|
|E091|Engine heritage|context|Phaser physics retained after Unity port (v1.6+)|-|-|context|CO,[WIKIP]|
|E092|Day/night overlay|Mad Forest dayNight true|global tint lerp over run|dayNight flag|8|covered: Palette Cycling|SD|
|E093|Curse speed/hp scaling|all|hp,speed *= totalCurse; spawn interval /= totalCurse|+10%/rank|-|NEW|WC|
|E094|Inverse per-minute ramp|Inverse mode|hp +5%/min, speed +0.5%/min|0.05, 0.005|-|NEW|SD|
|E095|Hyper speed mod|Hyper|enemy speed x0.9 delta, startingSpawns 15|-|-|NEW|SD|
|E096|Stage enemy speed|Forest|EnemySpeed 1.1 multiplier|1.1|-|NEW|SD|
|E097|Contact damage tick|all|power applied on overlap with player i-frames|power 1..65535|-|NEW|ED|
|E098|Player push of crowd|all|player body displaces enemies (frozen too)|-|30|NEW|WF|
|E099|Swarm despawn past screen|swarms|fixed-direction units removed after leaving far side|INF|-|NEW|INF|
|E100|Swarm repeat scheduler|events|event fires repeat times every delay ms, chance per repeat|delay 1200..15000 ms|-|NEW|SD,ED|
|E101|XL elite sprites|XLMANTIS/XLMUMMY/XLFLOWER|large sprites, knockback 0|hp 50 raw (wiki 500)|8|NEW|SD,WM|
|E102|HP display x10|all|wiki shows 10x raw maxHp (Mantichana 50 vs 500)|x10|-|n/a (data)|SD,WM|
|E103|Reaper drag on hit|Reaper|pulled toward player on every hit (-0.5)|-|30|NEW|WR|
|E104|Reaper multiplicity|31:00, 32:00|one extra Reaper per minute|-|-|NEW|[ST]|
|E105|White Hand|Reaper killed with Infinite Corridor/Crimson Shroud|spawns White Hand ending run|-|-|NEW|WR (conflicts: [ST])|
|E106|Gold Fever slow|Orologion|Gold Fever decay x0.5 while frozen|0.5|-|n/a|WO|
|E107|Starry Heavens|Orologion+Celestial Voulge|frozen enemies still walk toward player, no damage|-|30|NEW|WO|
|E108|Weird Souls Purifier|Rosary+Seraphic Cry|4x clear, enemies become gems|4|15|NEW|WRO|
|E109|Freeze explosion|Out of Bounds arcana|explosion on freeze|-|15|covered: Dither Bloom|WF|

## 2. QA checklist (pass/fail)
Data-sourced checks:
- [ ] Knockback lasts 120 ms (+/-1 frame) and reverses movement direction (WK, marked [verify]).
- [ ] Knockback multiplier = weapon KB x enemy KB, capped at maxKnockback (3 for normal enemies, 1 for bosses, 0 for the Reaper).
- [ ] GHOST, XLMANTIS, XLFLOWER, XLMUMMY and the swarm ghosts are not displaced on hit, but still flash.
- [ ] Each Garlic hit adds +0.3 to enemy knockback, up to the cap.
- [ ] The Reaper moves toward the player when hit (knockback -0.5).
- [ ] Ghost alpha is exactly 0.5.
- [ ] Every boss variant renders at 1.5x the base sprite size.
- [ ] XLBAT collider radius is 0.3 with offsetY -8.
- [ ] Bat Swarm spawns exactly 50 units moving in a straight line at speed 700, and they shove other enemies out of the way.
- [ ] Ghost Swarm spawns 20 units at speed 700. At 13:01 and 13:02 the triggers fire at +1.2 s and +2.3 s into the minute, 70% chance each, 20 repeats.
- [ ] Bat Swarm minute 20 has the same 1.2 s and 2.3 s offsets. Minute 29 has 1 + 19 repeats at 3000 ms, and minute 27 ghosts follow the same pattern.
- [ ] Flower Wall at 5:00 lasts 30 s, at 10:00 lasts 60 s, at 15:00 has an 80% chance and lasts 30 s, and at 25:10 lasts 10 s x5. It closes inward at speed 20 and traps enemies too.
- [ ] Mantichana appears as a boss at 5:00 and Giant Blue Venus at 25:00. Both bosses have speed 160 and res_Freeze 1.1, so Clock Lancet (1.0) does not freeze them but Orologion does.
- [ ] Orologion freezes all enemies for 10 s, including new spawns. Enemies turn blue with their animation stopped, the player can still push them, and a blue ring spins and fades.
- [ ] No periodic spawns happen once 300 or more enemies are alive, while bosses and events still spawn. Total enemies never exceed 500.
- [ ] Gems are blue up to 2 XP, green up to 9 and red above that. Once 400 gems are on the ground, new XP goes into one red gem.
- [ ] Enemies spawn outside the visible rect and never pop in on screen. Bosses teleport back instead of despawning.
- [ ] The Reaper spawns at 30:00, then one more each minute, at speed 1200.
- [ ] Mad Forest starts with 10 enemies (15 in Hyper), and enemy speed is x1.1.
- [ ] Mad Forest Inverse uses tint 0x8888EE.
- [ ] Walk cycles use the idleFrameCount frames (4 for most enemies, 8 for the Reaper, 3 for Polter), each enemy starts at a random phase, and variant sprites are picked randomly from frameNames.

Inferred checks (calibrate against video before treating as pass/fail):
- [ ] The hit flash is a pure white silhouette for about 33 ms, and a new hit restarts it.
- [ ] Flip faces the player, with a 2 px deadzone. Fixed-direction units never re-flip.
- [ ] The death animation plays at 15 fps and the corpse fades or dissolves within 0.5 s. Corpses draw under live enemies.
- [ ] 300 enemies plus 400 gems hold 60 fps on the target device, with one atlas draw batch per layer.
- [ ] Sprites are integer-pixel snapped, with no sub-pixel shimmer.

## 3. Visual hierarchy notes
1. Draw order from the bottom up: ground, light sources, gems and pickups, corpses, live enemies sorted by Y, bosses, player, projectiles and weapon FX, damage numbers, HUD.
2. Bosses stand out mostly through 1.5x scale (and the blue tint on Giant Blue Venus). Base-game bosses have no telegraph, health bar or aura, so don't add one if the remake is meant to be 1:1.
3. At 300+ enemies, readability comes from: semi-transparent ghosts (alpha 0.5), limited palettes for each enemy family, a white hit flash that stands out against the dark Forest palette, and the blue freeze tint, which works as a global state cue.
4. Swarms read as lines or bands crossing the screen at 700 speed, roughly 5x a normal walker. Their straight paths and single flip mark them apart from homing enemies.
5. The Flower Wall reads as a closed ellipse. Keep its spacing even so the player can see the gap after breaking through.
6. Gem colour is the main reward signal. Keep blue, green and red saturated and distinct from enemy palettes, and put gems in front of corpses.
7. Performance: cull outside the view plus a margin. Above 200 enemies, run animation at the 8 fps tier with per-instance phase. Neighbour queries use a spatial hash, since separation follows Phaser circle-body behaviour (COH).
