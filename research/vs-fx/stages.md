# Vampire Survivors (base v1.16) - Stage 2D mapping & FX catalog

Scope: base-game stages only. Status column: names our existing algorithm or NEW. Every row cites a source key (see References) or says inferred. Render-px measurements come from wiki tilemap images whose scale vs. game pixels is NOT verified.

## 1. Catalog

| id | name | usage | algorithm | params | fps tier | covered | sources |
|---|---|---|---|---|---|---|---|
| MAP-001 | Tileset chunk unit | All stages; wiki positions measured in 'tilesets' | World is built from a repeating rectangular chunk ('tileset' = one square/rectangle on Milky Way Map). Positions of items are given as N tilesets from start. | chunk W,H per stage (see MAP-01x) | static | NEW | [Milky_Way_Map];[MF] |
| MAP-002 | 8-way chunk wrap (open stages) | Mad Forest, Green Acres, Bone Zone, Il Molise, Moongolow, Cappella | World position -> chunk = floor(pos/chunk); tile = pos mod chunk. Render 3x3 chunks around camera; same chunk content repeats infinitely in all 8 directions. | chunk 1024x1024 (wiki render px, MF/GA) | static | NEW | [Stages];[rogueranker];[MF img] |
| MAP-003 | Horizontal-only wrap corridor | Inlaid Library | Wrap x only; y clamped by bookshelf colliders top/bottom. Spawns only from W/E edges. | chunk 2048x928 render px | static | NEW | [IL] |
| MAP-004 | Vertical-only wrap tower | Gallo Tower | Wrap y only; x bounded by tower walls over starfield void. Spawns mostly above/below screen. | chunk 1600x2048 render px | static | NEW | [GT];[GT img] |
| MAP-005 | Bounded/narrow bridge | Tiny Bridge | Very narrow horizontal strip; enemies arrive left/right in clusters. Wrap x inferred. | inferred | static | NEW | [TB] |
| MAP-006 | Bounded arena | Boss Rash | Closed arena; items placed outside reachable only via Mad Groove => hard bounds. | arena size unknown | static | NEW | [BR] |
| MAP-007 | Bounded corridor sky | Holy Forbidden | Finite narrow corridor floating in sky; ends in false wall + invisible bridge. | length unknown | static | NEW | [HF] |
| MAP-008 | Scripted vertical start | Eudaimonia Machine | No enemies at start; player must travel upwards to entity; scripted dialog arena. | unknown | static | NEW | [EM] |
| MAP-009 | Open 2D wrap with blockers | Dairy Plant | 8-way wrap; large warehouses/milk pools block; spawn suppressed on edges blocked by solid structure. | chunk 2048x2048 render px | static | NEW | [DP];[DP img] |
| MAP-010 | Inverse mode 180 deg rotation | All base stages w/ Inverse | Rotate chunk layout 180 deg (x->W-x, y->H-y); darker + hue-shifted palette; item positions may differ. | rot=180; color grade darker+hue | static | NEW | [Stages];[MF inv img] |
| MAP-011 | Ground tile grid 16px | Mad Forest | Autocorrelation of wiki tilemap: 83.7% column equality at 16px period => ground uses 16px repeating grass tile (in render px). | tile=16 (render scale unverified) | static | NEW | measured [MF img] |
| MAP-012 | Ground tile grid 32px | Green Acres | Autocorrelation peak 0.90 at 32px; tilemap has only 8 colors => flat stylised field. | tile=32 render px | static | NEW | measured [GA img] |
| MAP-013 | Floor tile 32/64px | Inlaid Library | Peaks at 32 (0.63) and 64 (0.76) => 32px floor tile with 64px pattern. | tile 32/64 | static | NEW | measured [IL img] |
| MAP-014 | Chunk-local deterministic props | All wrap stages | Props are hand-placed in chunk, so every repeat is identical (no per-chunk RNG). Do NOT randomize per chunk. | - | static | NEW | inferred from [MF img] identical tilemap + item positions given per chunk |
| MAP-015 | Stage item placement by tileset offset | MF/IL/DP etc. | Items spawned at fixed world coords = start + k*chunk; extra copies with chance chain (e.g. Spinach 30/20/10%). | per-item | static | NEW | [MF];[IL] |
| MAP-016 | Milky Way Map overlay | All | Pause map shows chunk rectangles, player, items, coffin, chests; zoomed-in for Moongolow/Bone Zone. | zoom flag per stage | UI | NEW | [Milky_Way_Map] |
| MAP-017 | Guide arrows | All with Milky Way Map | Screen-edge arrow toward each item with its icon; non-jittering (patch 0.4.2). | clamp to screen rect | 60 | NEW | [Milky_Way_Map] |
| MAP-018 | Teleport door pairs | Astral Stair (inverse lib) | Static paired doors; walking up into door centre moves player to counterpart. | static pairs | event | NEW | [AS] |
| MAP-019 | Trap pizza pressure plates | Various | Floor plate triggers random trap map event; global cooldown = trapCooldown*Luck. | cooldown per stage | event | NEW | [Stages];[Map_event] |
| MAP-020 | Boss Rash plates | Boss Rash | Every :30 until 9:30 spawn blue hourglass plate (skip to next minute) + red skull plate (respawn bosses); despawn at next minute. | 2 plates | event | NEW | [BR] |
| LS-001 | Light source base | All stages | Destructible, 10 HP; drops weighted pickup. 20 broken unlocks Fire Wand. | hp=10 | anim 2-4f inferred | Candle Flames | [LS] |
| LS-002 | Destructible spawn tick | All | Every 1 s (Bone Zone 0.5 s, Holy Forbidden 100 s) roll chance = mapChance*Luck capped at max. | see stage table | 1Hz | NEW | [LS] |
| LS-003 | Spawn just off-screen | All | Spawn position barely outside camera rect. | margin ~1 tile inferred | event | NEW | [LS] |
| LS-004 | Oval ring spawn | Open stages | Position on ellipse around player matching screen aspect. | ellipse ~ screen bounds | event | NEW | [LS] |
| LS-005 | Predetermined slots | Library, Dairy, Gallo | Pick from authored slot list in chunk instead of oval. | slot list | event | NEW | [LS] |
| LS-006 | Cap + recycle | All | At cap dmax: spawn nearest player, despawn oldest; Luck no longer affects chance. | dmax per stage | event | NEW | [LS] |
| LS-007 | Overlap allowed | All | No overlap check; sources may stack. | - | - | NEW | [LS] |
| LS-008 | Drop table | All | Weights: Gold 50, Bag 10, Rich bag 1(lv5), Rosary 1(lv8), Orologion 2(lv4), Vacuum 2(lv12), Chicken 12, Gilded Clover 1(lv30), Little Clover 1, Nduja 1. | weights | - | NEW | [LS] |
| LS-009 | Brazier skin | Mad Forest, Bone Zone, Boss Rash | Brazier sprite variant. | - | flame loop | Candle Flames | [LS];[MF] |
| LS-010 | Candelabra skin | Library, Gallo, Cappella, HF, EM | Candelabra variant. | - | flame loop | Candle Flames | [LS];[IL] |
| LS-011 | Lamp post skin | Dairy Plant | Lamp post variant (45px icon). | - | flicker | Candle Flames | [LS];[DP] |
| LS-012 | Field lamp skin | Green Acres, Il Molise, Moongolow, Tiny Bridge | Shared variant. | - | flicker | Candle Flames | [LS] |
| LS-013 | Break burst | All | On death: small flash + pickup pop. VFX details inferred. | ~6 frames | 30 | covered: Hit Sparks (inferred) | inferred |
| LS-014 | Light source glow halo | All | No dynamic lighting confirmed in base game; sources are sprites. Additive halo optional, keep alpha<=0.3. | alpha<=0.3 | 10-15 | Shadowcast Lantern (optional, downgrade) | inferred |
| LS-015 | Dairy Cart | Dairy Plant | Spawns at left end of authored rail; 40 dmg launches it to other end at high speed, 100 dmg to touched enemies. | hp 40, dmg 100 | 60 | NEW | [DC] |
| LS-016 | Stained Glass window | Cappella Magna | Spawns at set locations; on break: vertical pillar of light, AoE damage. | pillar height ~screen | 30 | NEW (light pillar) | [CM] |
| LS-017 | Amphora clusters | Moongolow | Every 10 s spawn 6*Luck (max 18) amphoras off-screen; break -> gold auto-collected; >100 despawn; far ones teleport to edge. | 6*Luck, cap 100 | event | NEW | [MG] |
| LS-018 | Bone Zone coin-only | Bone Zone | Sources 2x as often, drop only coins/bags. | tick 0.5s | event | NEW | [BZ] |
| LS-019 | Holy Forbidden slow refill | Holy Forbidden | Set locations, 100 s attempt, limited drop table. | 100s | event | NEW | [HF];[LS] |
| DEN-001 | Mad Forest destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=FOREST base=10% max=50% dmax=10 time=30:00 | 1Hz | NEW | [Mad Forest] infobox |
| DEN-002 | Inlaid Library destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=LIBRARY base=7.5% max=50% dmax=10 time=30:00 | 1Hz | NEW | [Inlaid Library] infobox |
| DEN-003 | Dairy Plant destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=WAREHOUSE base=20% max=60% dmax=10 time=30:00 | 1Hz | NEW | [Dairy Plant] infobox |
| DEN-004 | Gallo Tower destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=TOWER base=7.5% max=50% dmax=10 time=30:00 | 1Hz | NEW | [Gallo Tower] infobox |
| DEN-005 | Cappella Magna destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=CHAPEL base=20% max=80% dmax=20 time=30:00 | 1Hz | NEW | [Cappella Magna] infobox |
| DEN-006 | Il Molise destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=MOLISE base=30% max=60% dmax=10 time=15:00 | 1Hz | NEW | [Il Molise] infobox |
| DEN-007 | Moongolow destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=SINKING base=30% max=60% dmax=10 time=15:00 | 1Hz | NEW | [Moongolow] infobox |
| DEN-008 | Green Acres destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=GREENACRES base=10% max=50% dmax=10 time=30:00 | 1Hz | NEW | [Green Acres] infobox |
| DEN-009 | The Bone Zone destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=BONEZONE base=40% max=40% dmax=10 time=30:00 | 1Hz | NEW | [The Bone Zone] infobox |
| DEN-010 | Boss Rash destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=RASH base=10% max=50% dmax=5 time=15:00 | 1Hz | NEW | [Boss Rash] infobox |
| DEN-011 | Eudaimonia M. destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=MACHINE base=7.5% max=50% dmax=10 time=99:00 | 1Hz | NEW | [Eudaimonia M.] infobox |
| DEN-012 | Holy Forbidden destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=STAGEX base=100% max=100% dmax=100 time=5:00 | 1Hz | NEW | [Holy Forbidden] infobox |
| DEN-013 | Tiny Bridge destructible density | Light source params | chance=min(base*Luck,max) each tick; count<=dmax | id=TOWERBRIDGE base=7.5% max=50% dmax=10 time=20:00 | 1Hz | NEW | [Tiny Bridge] infobox |
| MF-01 | Grass field base | Mad Forest | Dark desaturated green 16px grass tile repeated; low value contrast. | palette ~#2b4a22 inferred from img | static | Wind Grass (static mode) | [MF img] |
| MF-02 | Dirt road cross | Mad Forest | 1-tile-wide brown paths forming a cross through chunk + branch to flower ring. | width ~1 tile | static | NEW | [MF img] |
| MF-03 | Flower bed ring | Mad Forest | Rectangular flower hedge near start (bottom-center of chunk). | - | static | NEW | [MF img] |
| MF-04 | Dead tree props | Mad Forest | Sparse dark tree sprites clustered NE/NW, y-sorted with player. | sparse | static | Wind Grass sway (subtle, opt) | [MF img] |
| MF-05 | Small ponds | Mad Forest | Blue water pools NE; decorative. | - | static/slow | Water Ripples (low amp) | [MF img] |
| MF-06 | Grave/fenced plots | Mad Forest | Fenced darker patches with posts (grave plots). | - | static | NEW | [MF img] |
| MF-07 | Grass tufts scatter | Mad Forest | Sparse lighter tuft decals. | density low | static | Wind Grass | [MF img] |
| MF-08 | Bat Swarm sweep | Mad Forest | Cloud of Pipeestrello crosses map in straight line, pushes enemies. | straight line | 60 | NEW (event) | [MF] |
| MF-09 | Ghost Swarm sweep | Mad Forest | Ghost cluster straight-line sweep. | - | 60 | NEW | [MF] |
| MF-10 | Flower Wall ring | Mad Forest | Ring of Flower Walls around player, closing slowly. | radius ~screen | 60 | NEW | [MF];[Map_event img] |
| IL-01 | Wood floor | Inlaid Library | Warm brown plank floor, 32px. | - | static | NEW | [IL img] |
| IL-02 | Bookshelf walls | Inlaid Library | Top/bottom bookshelf band as collision boundary. | - | static | NEW | [IL] |
| IL-03 | Tables/pianos obstacles | Inlaid Library | Small collidable props. | - | static | NEW | [IL] |
| IL-04 | Medusa Wall | Inlaid Library | Line of enemies from one side, fixed direction, wavy (Floaty) motion. | sine path | 60 | NEW | [IL];[Map_event] |
| IL-05 | Candelabra flame | Inlaid Library | Light source flame loop. | - | 8-12 inferred | Candle Flames | [LS] |
| DP-01 | Industrial floor | Dairy Plant | Large warehouses, factory blocks. | - | static | NEW | [DP];[DP img] |
| DP-02 | Milk pools | Dairy Plant | White pools act as obstacles. | - | static/slow | Water Ripples (milk tint) | [DP] |
| DP-03 | Cart rails | Dairy Plant | Authored rail lines for Dairy Cart. | - | static | NEW | [DC] |
| DP-04 | Spawn edge suppression | Dairy Plant | If solid structure blocks screen edge, no spawns from that side. | raycast/occupancy | event | NEW | [DP] |
| DP-05 | Jellyfish Wall | Dairy Plant | Ellipsoid ring of jellyfish that contracts/expands. | ellipse | 60 | NEW | [DP] |
| DP-06 | Pile Shooter ring | Dairy Plant | Enemies fire bullets in ellipsoid ring around player. | - | 60 | NEW | [DP] |
| DP-07 | Minotaur Rush | Dairy Plant | Fast minotaur cluster straight line. | - | 60 | NEW | [DP] |
| GT-01 | Starfield void | Gallo Tower | Dark blue space with cyan stars outside tower walls. | static stars, twinkle optional | static/4 | Fireflies (as twinkle) / NEW | [GT img] |
| GT-02 | Tower floor | Gallo Tower | Indigo/purple carpet floor, vertical shaft. | - | static | NEW | [GT img] |
| GT-03 | Fog overlay | Gallo Tower | Fog layer positioned to cover transparent borders in landscape (patch note). | full-screen | slow scroll | Dithered Fog | [GT] |
| GT-04 | Shooting Star | Gallo Tower, Tiny Bridge | Markers appear; stars impact after 2 s, 30 dmg AoE. | delay 2s | 60 | NEW (telegraph) | [GT];[TB] |
| GT-05 | Dragon Stream/Swarm | Gallo Tower | Serpentine dragons traverse horizontally. | - | 60 | NEW | [GT] |
| GT-06 | Mirror rune portal | Gallo Tower | Magic mirror with floating runes leads to coffin room. | runes float | 8 | NEW | [GT] |
| GT-07 | Red ring floor marker | Gallo Tower | Red circle mark on floor (visible in tilemap). | - | static | NEW | [GT img] |
| CM-01 | Chapel floor | Cappella Magna | 4-way open chapel tileset. | chunk 2048 | static | NEW | [CM img] |
| CM-02 | Water damage zone | Cappella Magna | Player takes damage entering water. | dmg/tick unknown | static | Water Reflection (low) | [CM] |
| CM-03 | Fade to black | Cappella Magna (Ender) | At 30:00 with Yellow Sign: enemies vanish, background fades to black, 30 s countdown, reaper ghosts fly up and fuse. | fade ~? s | 60 | NEW | [CM] |
| CM-04 | Yellow hand corner | Cappella/Eudaimonia | Yellow hand sprite bottom-right removes items. | - | UI | NEW | [CM];[EM] |
| IM-01 | Grass + flowers field | Il Molise | Open grassy map; immobile Molisano enemies. | - | static | Wind Grass | [IM] |
| IM-02 | Wave erase | Il Molise | Previous wave's enemies erased at minute start. | - | event | NEW | [IM] |
| MG-01 | Sunken city | Moongolow | Walls; passive items ring spawn area. | - | static | NEW | [MG] |
| MG-02 | Red tint ramp | Moongolow eclipse | Background gradually turns red. | lerp over minutes | 10 | NEW (color grade) | [MG] |
| MG-03 | Fish-eye distortion | Moongolow eclipse 14:00 | Full-screen barrel distortion, increasing after boss. | k increases | 30 | NEW | [MG] |
| MG-04 | Orbiting eyeballs | Moongolow eclipse | Many eyeballs circle player. | - | 60 | NEW | [MG] |
| MG-05 | Freeze frame | Moongolow eclipse end | Game 'freezes' then teleports to Holy Forbidden. | 2-3 s | - | NEW | [MG] |
| MG-06 | Detuned music | Moongolow eclipse | Audio detune (non-visual). | - | - | NEW | [MG] |
| GA-01 | Flat 8-color field | Green Acres | Minimal palette tilemap (8 colors). | 32px | static | NEW | [GA img] |
| BZ-01 | Bone field | The Bone Zone | Open bone-strewn ground; Sketamari moves horizontally south. | - | static | NEW | [BZ] |
| TB-01 | Narrow bridge | Tiny Bridge | Bridge strip; Monster Rain + Shooting Star events. | - | static | NEW | [TB] |
| TB-02 | Monster Rain | Tiny Bridge | Enemies drop from above (inferred from name). | - | 60 | NEW | [TB] |
| HF-01 | Sky corridor | Holy Forbidden | Narrow corridor floating in sky. | - | static | Dithered Fog (clouds) opt | [HF] |
| HF-02 | Sky turns red at 15s | Holy Forbidden | Sky lerps to red; UI hidden; bats become angels. | t=15s | 30 | NEW | [HF] |
| HF-03 | Invisible bridge | Holy Forbidden | Walkable non-rendered tiles past false wall. | - | static | NEW | [HF] |
| EM-01 | Inverted title/home | Eudaimonia | After mirror choice screen shown inverted. | - | UI | NEW | [EM] |
| EM-02 | Garbled text boxes | Eudaimonia | Dialog with garbled text before Directer fight. | - | UI | NEW | [EM] |
| BR-01 | Arena | Boss Rash | Closed arena; Atlas Gate appears at centre 7:00. | - | static | NEW | [BR] |
| CAM-001 | Follow camera centred | All | Camera centred on player, no lead (inferred from gameplay video). | lerp=1 | 60 | NEW | inferred |
| CAM-002 | Pixel snapping | All | Snap camera to integer source pixels to avoid shimmer of 16px tiles. | round(pos*ppu)/ppu | 60 | NEW | inferred + [unity tile thread] |
| CAM-003 | Integer scaling | All | Render to low-res target, upscale by integer factor; letterbox remainder. | scale=floor(screenH/targetH) | 60 | NEW | inferred; [phaser pixelArt] |
| CAM-004 | Nearest-neighbour filter | All | Point sampling on all sprites/tiles. | pixelArt=true | - | NEW | [phaser example] |
| CAM-005 | Engine note | All | Game moved Phaser->Unity in v1.6 (Aug 2023); v1.16 behaviour is Unity build. | - | - | info | [GOL];[tildes] |
| CAM-006 | Fog covers borders landscape | Gallo | Fog must cover transparent borders when aspect wide. | - | - | Dithered Fog | [GT] |
| CAM-007 | Offscreen spawn ring | All | Enemies/destructibles spawn just outside view rect; must use camera rect not fixed radius. | margin | event | NEW | [LS];[Map_event] |
| CAM-008 | Despawn/teleport far entities | All | Enemies despawn when far; bosses/amphoras teleport back to screen edge. | distance > ~1 screen inferred | event | NEW | [Map_event];[MG] |
| CAM-009 | Map zoom per stage | Moongolow, Bone Zone | Pause map zoomed-in. | flag | UI | NEW | [Milky_Way_Map] |
| CAM-010 | No parallax confirmed | All base stages | No parallax layers documented; Gallo starfield may be static backdrop. Treat parallax as optional factor 0-0.2. | factor 0 | - | NEW | inferred [GT img] |
| CAM-011 | Y-sort props | All | Props/trees drawn sorted by foot y. | - | 60 | NEW | inferred |
| CAM-012 | 300 enemy cap | All | Periodic spawn halted at >=300 alive. | 300 | - | NEW | [Map_event] |
| VH-001 | Low-value background | All | Backgrounds mid-dark, desaturated (MF greens, GT indigo). Keep bg luminance band narrow. | bg L* 15-35 inferred from imgs | - | NEW | [MF img];[GT img] |
| VH-002 | Sparse props | Open stages | Props occupy small % of chunk; open space dominates. | <10% coverage inferred | - | NEW | [MF img] |
| VH-003 | Ambient FX alpha cap | All | Any added ambient (grass sway, ripples, fog) must stay below sprite contrast. | alpha<=0.25 | 10-15 | all ambient ours | inferred |
| VH-004 | Inverse darker grade | Inverse | Darker + hue-shifted grade. | multiply ~0.7 inferred | - | NEW | [Stages] |
| VH-005 | Pickups brightest | All | Gems/pickups saturated vs bg. | - | - | NEW | inferred |
| AMB-001 | Grass sway | MF, IM, GA | Optional per-tuft sine x-offset 1px; base game appears static. | amp 1px, 0.5Hz | 8 | Wind Grass | inferred |
| AMB-002 | Pond ripple | MF, DP milk | Concentric ripple at low amp. | amp 1px | 8 | Water Ripples | inferred |
| AMB-003 | Water reflection | CM water | Mirror nearby sprites at 20% alpha. | alpha .2 | 15 | Water Reflection | inferred |
| AMB-004 | Flame flicker | All lights | 2-4 frame loop + random scale jitter. |  | 8-12 | Candle Flames | [LS] sprites |
| AMB-005 | Fog | GT | Dithered fog drift. | speed slow | 15 | Dithered Fog | [GT] |
| AMB-006 | Star twinkle | GT void | Random stars alpha pulse. |  | 4 | Fireflies variant | [GT img] |
| AMB-007 | Fireflies | MF optional | Not documented in base; add only as polish, off by default for 1:1. | off | - | Fireflies | inferred |
| AMB-008 | Lantern shadowcast | none | No darkness mechanic in base stages (Abyss Foscari DLC has darkness). Keep off for 1:1. | off | - | Shadowcast Lantern | [AF] (DLC, out of scope) |

## 2. QA pass/fail checklist

Common to all: [ ] pixel-snapped camera, no tile shimmer; [ ] integer scale + nearest filter; [ ] background contrast below sprites (VH-001..005); [ ] Inverse = 180 deg rotation + darker grade; [ ] destructible tick/chance/dmax per DEN row; [ ] spawn just off-screen using camera rect.

### Mad Forest
- [ ] PASS/FAIL: 8-way wrap seamless at chunk seams
- [ ] PASS/FAIL: road cross + flower ring present at start
- [ ] PASS/FAIL: braziers spawn on oval off-screen, dmax 10
- [ ] PASS/FAIL: Bat/Ghost swarm + Flower Wall events
- [ ] PASS/FAIL: Spinach/Clover extra-copy chance chain

### Inlaid Library
- [ ] PASS/FAIL: x-wrap only, y blocked by shelves
- [ ] PASS/FAIL: spawns only from W/E
- [ ] PASS/FAIL: candelabra slots predetermined
- [ ] PASS/FAIL: Medusa Wall wavy line
- [ ] PASS/FAIL: Empty Tome 40/30/20% chain

### Dairy Plant
- [ ] PASS/FAIL: 8-way wrap, structures collide
- [ ] PASS/FAIL: spawn suppressed on blocked edges
- [ ] PASS/FAIL: lamp posts at slots; Dairy Cart rails 40hp/100dmg
- [ ] PASS/FAIL: Jellyfish Wall ellipse, Minotaur rush
- [ ] PASS/FAIL: Milky Way Map far south

### Gallo Tower
- [ ] PASS/FAIL: y-wrap only, starfield beyond walls
- [ ] PASS/FAIL: fog covers borders on wide aspect
- [ ] PASS/FAIL: Shooting Star 2 s telegraph 30 dmg
- [ ] PASS/FAIL: mirror -> secret coffin room
- [ ] PASS/FAIL: Randomazzo N, Sorceress' Tears S

### Cappella Magna
- [ ] PASS/FAIL: 4-way spawns
- [ ] PASS/FAIL: stained glass light pillar AoE
- [ ] PASS/FAIL: water damages player
- [ ] PASS/FAIL: dmax 20, chance 20-80%
- [ ] PASS/FAIL: Ender fade-to-black at 30:00

### Il Molise
- [ ] PASS/FAIL: 15:00 limit
- [ ] PASS/FAIL: immobile Molisano
- [ ] PASS/FAIL: waves erased each minute
- [ ] PASS/FAIL: starting spawns 1

### Moongolow
- [ ] PASS/FAIL: amphoras 6*Luck/10s cap 100
- [ ] PASS/FAIL: merchant present
- [ ] PASS/FAIL: eclipse red tint, fish-eye 14:00
- [ ] PASS/FAIL: map zoomed

### Green Acres
- [ ] PASS/FAIL: random waves from 5 base stages
- [ ] PASS/FAIL: 32px flat tileset
- [ ] PASS/FAIL: Magic Banger NE

### The Bone Zone
- [ ] PASS/FAIL: destructible tick 0.5 s, coins only
- [ ] PASS/FAIL: +0.3 hp/+0.05 spd per min
- [ ] PASS/FAIL: Sketamari south horizontal

### Boss Rash
- [ ] PASS/FAIL: bounded arena
- [ ] PASS/FAIL: plates every :30 to 9:30
- [ ] PASS/FAIL: dmax 5
- [ ] PASS/FAIL: Atlas Gate 7:00

### Eudaimonia M.
- [ ] PASS/FAIL: no enemies at start, go up
- [ ] PASS/FAIL: yellow hand
- [ ] PASS/FAIL: modes disabled

### Holy Forbidden
- [ ] PASS/FAIL: 5:00, sky red at 15 s, UI hidden
- [ ] PASS/FAIL: 100 s destructible tick
- [ ] PASS/FAIL: false wall + invisible bridge

### Tiny Bridge
- [ ] PASS/FAIL: narrow, L/R spawns
- [ ] PASS/FAIL: Monster Rain + Shooting Star
- [ ] PASS/FAIL: +0.2 hp/+0.025 spd per min

## 3. Visual hierarchy notes

- Background: dark, desaturated, narrow luminance band (Mad Forest dark green; Gallo indigo floor over near-black space). Measured from wiki tilemaps.
- Props: sparse and hand-placed per chunk; large open floor so swarms read. No parallax or dynamic lighting documented in base stages; our Shadowcast Lantern / Fireflies should be off for 1:1.
- Light sources are the only regularly bright stage objects besides pickups; that is intentional (Castlevania candle homage) - keep their flame the brightest bg element.
- Stage-wide FX are event-driven only: Moongolow eclipse (red grade, fish-eye), Holy Forbidden red sky, Cappella fade-to-black, Stained Glass light pillar.
- Ambient motion from our library (Wind Grass, Water Ripples, Fog) must be low amplitude (<=1px, alpha<=0.25) and low fps (8-15).

## References

Key -> URL. Fetched OK unless noted.

- [Stages]: https://vampire.survivors.wiki/w/Stages
- [MF]: https://vampire.survivors.wiki/w/Mad_Forest
- [IL]: https://vampire.survivors.wiki/w/Inlaid_Library
- [DP]: https://vampire.survivors.wiki/w/Dairy_Plant
- [GT]: https://vampire.survivors.wiki/w/Gallo_Tower
- [CM]: https://vampire.survivors.wiki/w/Cappella_Magna
- [IM]: https://vampire.survivors.wiki/w/Il_Molise
- [MG]: https://vampire.survivors.wiki/w/Moongolow
- [GA]: https://vampire.survivors.wiki/w/Green_Acres
- [BZ]: https://vampire.survivors.wiki/w/The_Bone_Zone
- [BR]: https://vampire.survivors.wiki/w/Boss_Rash
- [EM]: https://vampire.survivors.wiki/w/Eudaimonia_M.
- [HF]: https://vampire.survivors.wiki/w/Holy_Forbidden
- [TB]: https://vampire.survivors.wiki/w/Tiny_Bridge
- [LS]: https://vampire.survivors.wiki/w/Light_source
- [Map_event]: https://vampire.survivors.wiki/w/Map_event
- [DC]: https://vampire.survivors.wiki/w/Dairy_Cart
- [Milky_Way_Map]: https://vampire.survivors.wiki/w/Milky_Way_Map
- [AS]: https://vampire.survivors.wiki/w/Astral_Stair
- [AF]: https://vampire.survivors.wiki/w/Abyss_Foscari
- [Mazerella]: https://vampire.survivors.wiki/w/Mazerella
- [Bat_Country]: https://vampire.survivors.wiki/w/Bat_Country
- [Laborratory]: https://vampire.survivors.wiki/w/Laborratory
- [Coffin]: https://vampire.survivors.wiki/w/Coffin
- [Merchant]: https://vampire.survivors.wiki/w/Merchant
- [Gracia]: https://vampire.survivors.wiki/w/Gracia%27s_Mirror
- [Room_1665]: https://vampire.survivors.wiki/w/Room_1665
- [Candelabrador]: https://vampire.survivors.wiki/w/Candelabrador
- [Orologion]: https://vampire.survivors.wiki/w/Orologion
- [MF img]: https://vampire.survivors.wiki/images/Tilemap-Mad_Forest.png
- [MF inv img]: https://vampire.survivors.wiki/images/Tilemap-Inverse_Mad_Forest.png
- [IL img]: https://vampire.survivors.wiki/images/Tilemap-Inlaid_Library.png
- [GT img]: https://vampire.survivors.wiki/images/Tilemap-Gallo_Tower.png
- [DP img]: https://vampire.survivors.wiki/images/Tilemap-Dairy_Plant.png
- [CM img]: https://vampire.survivors.wiki/images/Tilemap-Cappella_Magna.png
- [GA img]: https://vampire.survivors.wiki/images/Tilemap-Green_Acres.png
- [Map_event img]: https://vampire.survivors.wiki/images/Map_event-Flower_Wall.jpg
- [patch 0.2.5]: https://steamcommunity.com/games/1794680/announcements/detail/3140696417050424341 (cited by wiki, not fetched)
- [rogueranker]: https://rogueranker.com/vampire-survivors-stages/ (search snippet)
- [GOL]: https://gamingonlinux.com/2023/07/vampire-survivors-switching-to-new-game-engine-on-august-17 (snippet)
- [tildes]: https://tildes.net/~games/19ha/vampire_survivors_version_1_6_new_engine_and_local_co_op (snippet)
- [phaser example]: https://phaser.io/examples-show/3172 (snippet)
- [unity tile thread]: https://discussions.unity.com/t/how-do-i-match-camera-size-game-resolution-to-my-tilemap/1537587 (snippet)
- [primagames]: https://vip-develop.primagames.com/?p=90044 (snippet: Moonspell finite map, DLC)
- [steam disc]: https://steamcommunity.com/app/1794680/discussions/0/3189118358011199590/ (snippet)
- BLOCKED: vampire-survivors.fandom.com (HTTP 403); raw.githubusercontent.com SurvivatonsAndMore/VampireSurvivorsFiles Stage.json/Props.json (404 on main) and GitHub API (repo not enabled for session)
