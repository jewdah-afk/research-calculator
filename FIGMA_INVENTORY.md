# Peckwood Figma UI: Birb parity inventory (2026-10-09)

Source of truth for layout: parity build `playtest/` on branch `claude/exciting-mccarthy-5em6b3`
(`js/main.js`: `WINS`, `drawPanel`, `drawHud`, `castleHtml`; `index.html`). Figma state from HANDOUT.md
(UI v2 windows, Missing screens board `168:7`, Map boards `178:7`).

Status: **E** = exists in UI v2 and matches parity · **D** = exists but differs from parity · **M** = missing in Figma.
Every D/E is re-checked frame by frame when its group is designed.

## 1. HUD (always on screen)
| Element | Parity content | Figma | Status |
|---|---|---|---|
| Wallet chips | up to 11: eggs, plumes, seeds, golden eggs, moneta, twigs, wood, echo eggs, brute ore, gold ore, SP (in a run); each with +rate/s | HUD `8:271` capsules | D (rates, full currency set, overflow order) |
| Area banner | map name (+ "DESERT TREE" / "ARCHIVIST'S BRANCH" view) | `8:271` | E |
| Travel arrows | left/right/up/down arrows with destination label, locked state | none | M |
| Companions [TAB] | dropdown: Sparrow, Seagull, Red Panda, Crow, Dave, Parrot with levels | left menu group tiles | D |
| AUTO button | context: fishing (AUTO n/10), mine player auto, expedition auto-attack, forest auto-collect | game only | M |
| Context top bar | Bridge fishing level+XP · Mine area milestone · Expedition floor HUD (level/XP/rebirb, points x, time, floor, night) · Echo field count/chance · Desert golden chance + sandstorm · Nest build tier progress | goal bar `8:271` only | M (6 variants) |
| Bottom hotbar | Bridge CAST + rod/bait/hook/lure slots · Mine GIANT ORE challenge · Expedition HP bar + potion + artifact slots + RESET FLOOR | none | M (3 variants) |
| Utility buttons | TRAVEL, FISH, PROFILE, SETTINGS (bottom right) | left tiles | D |
| Prompts | station "name: desc · E to buy", seed platform, portal "[E] Enter the Expedition", "[E] AQUARIUM / FISH MARKET" | none | M |
| Toast | one-line notices | `8:271` | E |
| Robux shop dock | (ours, not in Birb) | `130:7`, `132:7` | E (keep) |

## 2. Shop drawer (tabs: EGGS, MOLT, SEEDS, NEST, MINE)
| Tab | Parity content | Figma | Status |
|---|---|---|---|
| EGGS | upgrade rows + Eggs / Golden / Echo currency switch | Eggs, Golden, Echo windows (separate) | D (parity = one tab with a switch) |
| MOLT | reset hero (+N plumes, MOLT) + PLUME KEEPSAKES rows; +N badge on tab | Molt | E |
| SEEDS | seed rows + seeds/s note | Seeds | E |
| NEST / SHOP | tree-box phase, planting bed expansion, specials, 3 twig ups, automation toggles | Nest shop (3 rows), Cultivation `173:7` | D |
| NEST / LAKE | fish breeding: parent A/B, preview, incubation | none | M |
| NEST / RIVERSIDE | Lumberyard, Pollinator, Compost, Grove, Nursery | Riverside `173:465` | D |
| NEST / SAWMILL | WOOD + SAWMILL sub-tabs, Sawmill LV hero, SAW / AUTO | Carpentry `173:873` | D |
| NEST / OWNED | owned specials list | none | M |
| MINE | area / crow damage / gold ore header + mine rows | Mine shop (4 rows) | D (header) |

## 3. Windows
| Window | Parity tabs / content | Figma | Status |
|---|---|---|---|
| Castle / Monster | talk state, SATISFACTION %, 6 feed lines, HOLD TO FEED, EVOLVE, 5-stage checklist | Evolve | D |
| Fishing | COLLECTION (fish + active buffs) / EQUIPMENT (rods, bait, hook, lure) / FISHDEX | Rods, Baits, Fish Index, Tackle `176:1294` | D (regroup into 3 tabs) |
| Sparrow | seed feeder, seed snacks, mitosis + rebirb, milestones | Sparrow, Mitosis/Resonance `176:2160` | D |
| Seagull | the seagull, gulls, hybrids | Seagull, Migrations/Frenzy `176:1735` | D |
| Red Panda | name the red panda, tiers | Red Panda | E |
| Crow | crow level, rebirbs, tracks | Mine/Tree + crow rebirb `171:383` | D |
| Dave | level, XP, branches | Dave, Branches `176:2501` | D |
| Parrot | OVERVIEW / UPGRADE / EQUIPMENT (+FORGE) / INDEX / REBIRB | Parrot, Gear `174:7`, Artifacts `174:299`, Rebirb `174:623` | D (5-tab structure, Overview, Index, Forge missing) |
| Parrot forge | upgrade/evolve/refine, aura convert/dismantle, infuse/fuse, potions, materials | none | M |
| Expedition floors | floor list, day/night, totem | Floors + boss `174:948` | D (night, totem) |
| Treasure Room (mine tree) | mine tree nodes | Mine/Tree `171:383` | D |
| Mine areas | area picker, ore HP, giant timer, coffer | Mine/Areas `171:7` | D |
| Sacrifice | 18 tiers, expansion + MYTHIC SACRIFICE (3 levels) | Sacrifice, All tiers `174:1697` | D (mythic) |
| Objectives | QUESTS (pin) / QUEST INDEX / BONUSES | Quests, Quests/Main `174:1289` | D |
| Aquarium | BIOMES / RESONANCE / TOTAL / FISH MARKET | Aquarium | D |
| Fish Market | reputation rank, offers, accepted, active buffs, reroll | none | M |
| Profile | all stats | Profile + ALL STATS | E |
| Settings | settings + tree view toggle (+dev) | Profile/Settings `177:434` | D |
| Fast Travel | map list | game only | M |
| Seeds / Sunflower tree | (Birb: world stations) | `176:873` | E |
| Desert research tree | (Birb: world stations) | `176:432` | D (hero icon still a popcorn bucket) |
| Archivist tree | (Birb: world stations) | `176:7` | E |

## 4. Popups and small UI
| Element | Figma | Status |
|---|---|---|
| Offline earnings (8h cap) | `177:877` | E |
| Leaderboards (ours) | `177:7` | E |
| Confirm dialog (wipe / reset / sacrifice) | none | M |
| Level-up (sparrow, seagull, crow, Dave, parrot) | none | M |
| Rewards (boss, chest, contract claim) | none | M |
| Area / feature unlock (Mine open, Desert, Archivist book, gate open) | none | M |
| Monster / Red Panda intro dialogue | none | M |
| Map overview | map boards `178:7` (world), no UI | M |
