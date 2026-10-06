# Birb upgrade table

This table is generated from `upgrades.json`, which was pulled straight from the game code. The cost rules are in `CORE_FORMULAS.md` §1.

In the *Effect* column, one-time upgrades show their in-game description. Leveled upgrades show the effect expression from the code, where `e` is the level.

Mine-tree nodes and the two Echo upgrades are built by generator functions in the code, so they are not listed here. See `CORE_FORMULAS.md` §7.

## Popcorn shop (P)

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `p_golden_popcorn_value` | GOLDEN POPCORN VALUE | goldenPopcorn | 10 | 1.55 | 999 | `e=>e` |
| `p_auric_silo` | AURIC SILO | goldenPopcorn | 1000 | 1.8 | 50 | `e=>2*e` |
| `p_value` | POPCORN VALUE | popcorn | 1 | 1.19 | 999 | `e=>e` |
| `p_speed` | FASTER POPCORNS | popcorn | 3 | 1.75 | 12 | `e=>Math.max(.2,2.6-.2*e)` |
| `p_capacity` | POPCORN CAP | popcorn | 3 | 1.8 | 40 | `e=>2*e` |
| `p_move_speed` | WING TRAINING | popcorn | 5 | 2.3 | 20 | `e=>1+Math.max(0,e-1)*(1/19)` |

## Rebirb shop (PR)

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `pr_golden_popcorn_mult` | GOLDEN POPCORN MULT | goldenFeathers | 1.00e17 | 2.52 | 7 | `e=>Math.pow(2,Math.max(0,e-1))` |
| `pr_popcorn_mult` | POPCORN MULT | goldenFeathers | 1 | 3.5 | 7 | `e=>Math.pow(2,e-1)` |
| `pr_radius_mult` | MAGNETIC FIELD | goldenFeathers | 4 | 5 | 5 | `e=>1+.2*e` |
| `pr_respawn_mult` | RESPAWN MULT | goldenFeathers | 10 | 4.2 | 4 | `e=>1+.5*Math.max(0,e-1)` |

## Seed shop (S)

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `s_more_popcorn` | MORE POPCORN | sunflowerSeeds | 5 | 1.3 | 999 | `e=>1+.2*Math.max(0,e-1)` |
| `s_more_feathers` | MORE FEATHERS | sunflowerSeeds | 5 | 1.3 | 999 | `e=>1+.2*Math.max(0,e-1)` |
| `s_more_seeds` | MORE SEEDS | sunflowerSeeds | 5 | 1.3 | 999 | `e=>e` |

## Mine shop (M)

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `m_ore_value` | ORE VALUE | bruteOre | 180 | 1.47876 | 9999 | Increase Brute Ore gained per HP removed from ore |
| `m_mining_power` | Mining Power | bruteOre | 240 | 1.40663 | 9999 | Increase Birb and Crow damage against ore. |
| `m_rupture` | Rupture | bruteOre | 2.00e6 | 2.7 | 16 | Increase the full-break bonus by 5 percentage points. |
| `m_charged_strike` | Charged Strike | bruteOre | 4800 | 24 | 4 | Add 1x damage to Crow's charged peck per level. |

## Sunflower tree

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `d_sunflower_machine` | SUNFLOWER VENDING | goldenFeathers | 100 |  | 1 | Unlocks sunflower platform |
| `d_unlock_archivist_tree` |  | archivist_book | 1 |  | 1 |  |
| `d_unlock_desert_tree` | UNLOCK THE DESERT TREE | strange_key | 1 |  | 1 | Use a Legendary Key to unlock a new branch |
| `d_seed_feeder` | SEED FEEDER | sunflowerSeeds | 100000 |  | 1 | Auto-feed Sparrow using a chosen % of seed income |
| `d_seed_multiplier` | SEED FERTILIZER | popcorn | 200000 |  | 1 | Feathers boost seeds |
| `d_rebirth_playtime` | TIME IS MONEY | popcorn | 250000 |  | 1 | Feathers x Playtime |
| `d_golden_harvest` | GOLDEN HARVEST | popcorn | 1.00e7 |  | 1 | 3x Seeds & Feathers |
| `d_unlock_evolve` | UNLOCKS EVOLVE | popcorn | 1.00e8 |  | 1 | New Evolutions await |
| `d_seed_synergy` | SEED SYNERGY | sunflowerSeeds | 30000 |  | 1 | Seeds boost Popcorn |
| `d_butter_bonanza` | BUTTER BONANZA | sunflowerSeeds | 100000 |  | 1 | +50% Butter Popcorn |
| `d_sparrow_snacks` | GOURMET SNACKS | sunflowerSeeds | 150000 |  | 1 | +50% Sparrow XP |
| `d_rainbow_aura` | RAINBOW AURA | sunflowerSeeds | 500000 |  | 1 | 2x Rainbow Popcorn |
| `d_cheese_powder` | CHEESE FACTORY | goldenFeathers | 3.00e6 |  | 1 | +50% Cheese Popcorn |
| `d_double_catch` | DOUBLE CATCH | tetra_silver_river | 5 |  | 1 | 10% chance 2 fish |
| `d_fast_reeling` | FAST REELING | sunflowerSeeds | 1.00e6 |  | 1 | -25% Reel Time |
| `d_seagull_synergy` | SEAGULL SYNERGY | ocean_whale_maroon | 3 |  | 1 | Fish XP buff affects Seagull |
| `d_treasure_map` | MONETA CURRENT | monetariaMoneta | 2500 |  | 1 | +50% Moneta per catch |
| `d_popcorn_cap` | POPCORN SILO | sunflowerSeeds | 50 |  | 1 | x2 Popcorn Cap |
| `d_swift_wings` | SWIFT WINGS | goldenFeathers | 5000 |  | 1 | 1.3x bird speed |
| `d_auto_gen` | AUTO GENERATOR | sunflowerSeeds | 500 |  | 1 | Auto generate seeds |
| `d_faster_seeds` | EFFICIENT FARMING | sunflowerSeeds | 10000 |  | 1 | 2x Seed Speed |
| `d_pickup_range` | VACUUM | sunflowerSeeds | 30000 |  | 1 | 1.25x Pickup Range |
| `d_seed_multiplier_unlocker` | SEED MASTERY | goldenFeathers | 20000 |  | 1 | Unlocks seed upgrade |
| `d_seed_pipeline` | SEED PIPELINE | monetariaMoneta | 1000 |  | 1 | +25% Seed Speed |
| `d_pop_max_lvl` | LIMIT BREAKER | goldenFeathers | 1.00e6 |  | 1 | +2 Pop. Mult Max Level |
| `d_spirit_scouting` | SPIRIT SCOUTING | spirit_trash | 2 | 1.5 | 5 | +10% Parrot Damage per level |
| `d_spirit_shell` | SPIRIT SHELL | spirit_trash | 2 | 1.5 | 5 | +10% Parrot Max HP per level |
| `d_spirit_momentum` | SPIRIT MOMENTUM | spirit_trash | 3 | 1.5 | 5 | +2% Parrot atk/move speed per level |
| `d_fish_seeds` | FISH SEEDS | monetariaMoneta | 55 |  | 1 | Unlock fish sales for Seeds; total Fish caught boost Seed production |
| `d_seagull_xp` | SEAGULL TRAINING | monetariaMoneta | 5500 |  | 1 | +50% Seagull XP |
| `d_seed_market` | MONETA STORE | monetariaMoneta | 100 |  | 1 | Highest Moneta held boosts Seeds from fish sales |
| `d_trophy_bonus` | TROPHY BONUS | monetariaMoneta | 3500 |  | 1 | Popcorn x Heaviest Fish Ever Caught |
| `d_double_fish_buff` | EXTRA STOMACH | monetariaMoneta | 17500 |  | 1 | Adds one more active fish buff slot |
| `d_golden_rain` | GOLDEN CASCADE | sunflowerSeeds | 5.00e8 |  | 1 | Gain 0.1% of your best completed Rebirb per second |
| `d_prism_shine` | PRISM SHINE | sunflowerSeeds | 4.00e7 |  | 1 | +25% Popcorn value |
| `d_platinum_wings` | PLATINUM WINGS | goldenFeathers | 1.00e8 |  | 1 | +15% movement speed |
| `d_deep_dive` | DEEP DIVE | monetariaMoneta | 2200 |  | 1 | +20% rare fish chance |
| `d_fish_frenzy` | FISH FRENZY | goldenFeathers | 5000 |  | 1 | -20% fishing cooldown |
| `d_sparrow_legacy` | SPARROW LEGACY | sunflowerSeeds | 1.00e8 |  | 1 | Evolution preserves 25% of Sparrow XP |
| `d_sparrow_xp_2` | BIRD BRAIN | sunflowerSeeds | 3.00e7 |  | 1 | -25% Seeds to feed / +25% XP gained |
| `d_free_seeds` | NATURE'S SUBSIDY | sunflowerSeeds | 1000 |  | 1 | Upgrades don't spend seeds |
| `d_sparrow_drain_power` | SPARROW RESONANCE | sunflowerSeeds | 1.00e6 |  | 1 | Unlocks Resonance. |
| `d_sparrow_mitosis` | SPARROW MITOSIS | sunflowerSeeds | 2.50e6 |  | 1 | Unlocks Mitosis. |
| `d_treasure_appraisal` | MONETA LEDGER | monetariaMoneta | 15000 |  | 1 | 2x Moneta per catch |
| `d_fish_value` | MARKET BOOM | goldenFeathers | 2.50e8 |  | 1 | Fish sell for 2x |
| `d_rod_chance` | PRECISION CAST | monetariaMoneta | 5500 |  | 1 | +15% relative catch chance for Progression targets |
| `d_critical_reel` | CRITICAL CAST | sunflowerSeeds | 2.50e7 |  | 1 | 10% chance of an instant catch |
| `d_xp_tome` | EXPERT ANGLER | abyssal_fish_silver | 1 |  | 1 | +50% Fishing XP |
| `d_bulk_bonus` | WHOLESALE | goldenFeathers | 5.00e8 |  | 1 | +20% Value when using Safe Sell |
| `d_profit_surge` | GOLDEN SALE | goldenFeathers | 2.00e9 |  | 1 | 10% Chance for 10x Value |
| `d_treasure_seeker` | MONETA MASTERY | monetariaMoneta | 50000 |  | 1 | 2x Moneta per catch |
| `d_shiny_scale` | PRISMATIC BADGE | sunflowerSeeds | 2.50e9 |  | 1 | +10% final Shiny chance per Highest Rod Tier |
| `d_seed_bag` | FERTILE SOIL | sunflowerSeeds | 5.00e9 |  | 1 | +50% Global Seed Generation |
| `d_sparrow_hoard` | CARRIER PIGEON | sunflowerSeeds | 5.00e9 |  | 1 | Sparrow collects 5x value |
| `d_wing_mastery_plus` | WING MASTERY | popcorn | 5.00e11 |  | 1 | +10 Wing Training Levels |
| `d_silo_mastery_plus` | SILO MASTERY | popcorn | 1.00e12 |  | 1 | +10 Popcorn Cap Levels |
| `d_butter_hose` | BUTTER HOSE | popcorn | 2.00e12 |  | 1 | x1.5 Popcorn Value |
| `d_focus_training` | FOCUS TRAINING | popcorn | 5.00e12 |  | 1 | x1.3 Pickup Radius |
| `d_quantum_corn` | QUANTUM CORN | popcorn | 1.00e13 |  | 1 | x1.2 Spawn Rate |
| `d_kernel_polish` | KERNEL POLISH | popcorn | 2.50e13 |  | 1 | x2 Popcorn Value |
| `d_sparrow_wisdom` | SPARROW WISDOM | popcorn | 5.00e13 |  | 1 | +50% Sparrow XP |
| `d_sparrow_lineage` | ANCESTRAL LINEAGE | popcorn | 1.00e14 |  | 1 | Legacy now preserves 50% of Sparrow XP |
| `d_abyssal_light` | ABYSSAL LIGHT | monetariaMoneta | 150000 |  | 1 | +50% Average Fish Weight |
| `d_net_mastery` | NET MASTERY | sunflowerSeeds | 1.00e10 |  | 1 | Auto-Fisher 10% chance for 2x fish |
| `d_amber_alchemy` | AMBER CURRENT | sunflowerSeeds | 1.00e10 |  | 1 | 20% chance to gain 100x fish value in Seeds |
| `d_leviathan_mastery` | LEVIATHAN MASTERY | goldenFeathers | 1.00e11 |  | 1 | Fish Value scales with Weight squared |
| `d_ocean_bounty` | OCEAN'S BOUNTY | monetariaMoneta | 100000 |  | 1 | Catching fish grants Seeds |
| `d_gravity_field` | GRAVITY FIELD | popcorn | 1.00e15 |  | 1 | Passive Popcorn Pull (Weak) |
| `d_golden_butter` | GOLDEN BUTTER | goldenFeathers | 1.00e10 |  | 1 | Popcorn Value scales with Golden Feathers |
| `d_crit_pop` | CRITICAL POP | popcorn | 5.00e15 |  | 1 | 1% Chance for Red Popcorn (100x) |
| `d_void_silo` | VOID SILO | popcorn | 1.00e16 |  | 1 | +10% Total Popcorn Capacity |
| `d_hyper_metabolism` | HYPER METABOLISM | popcorn | 1.00e16 |  | 1 | Popcorn grants stacking speed buff |
| `d_hive_mind` | NEURAL OVERCLOCK | sunflowerSeeds | 5.00e10 |  | 1 | Sparrow Speed Limit increased by 50% |
| `d_seed_bank` | SEED BANK | sunflowerSeeds | 1.00e11 |  | 1 | +0.0167%/s of current Seeds (5T soft cap) |
| `d_mecha_birb` | MECHA-BIRB | sunflowerSeeds | 2.50e11 |  | 1 | Sparrows collect 2x Popcorn |
| `d_ancestral_radio` | ANCESTRAL RADIO | sunflowerSeeds | 4.00e13 |  | 1 | Seagull -> Sparrow XP share 10% |
| `d_lunar_compass` | LUNAR COMPASS | goldenFeathers | 2.00e14 |  | 1 | +35% weight for Seagull catches |
| `d_legend_beacon` | LEGEND BEACON | monetariaMoneta | 5.00e6 |  | 1 | Daily legendary cooldown 24h->16h, daily shiny 1%->3% |
| `d_migration_amplifier` | SEAGULL REBIRB AMPLIFIER | goldenFeathers | 2.00e13 | 2.2 | 10 | +5% per level to Seagull Rebirb rare and XP effects only |
| `d_gull_sonar` | GULL SONAR | sunflowerSeeds | 1.00e12 |  | 1 | Seagull rolls twice and keeps the rarer catch |
| `d_rare_routes` | RARE ROUTES | sunflowerSeeds | 2.00e13 |  | 1 | +15% rare-up reroll chance on seagull catches |
| `d_echo_vectors` | ECHO VECTORS | goldenFeathers | 3.00e13 |  | 1 | +10% duplicate-catch chance |
| `d_fleet_training` | FLEET TRAINING | sunflowerSeeds | 8.00e12 | 2.25 | 4 | +6% seagull XP per level |
| `d_frenzy_reactor` | FRENZY REACTOR | popcorn | 5.00e17 |  | 1 | Frenzy duration x1.5 |
| `d_cold_start` | COLD START | popcorn | 2.00e18 |  | 1 | Frenzy cooldown x0.65 |
| `d_patrol_network` | PATROL NETWORK | popcorn | 3.00e18 | 2.18 | 5 | +1% duplicate-catch chance per level (cap 5%) |

## Desert tree

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `d_desert_tempered_glass` |  | bruteOre | 120000 |  | 1 |  |
| `d_desert_golden_reserve` |  | gold_ore | 24 |  | 1 |  |
| `d_desert_mineral_tracker` |  | bruteOre | 2.00e6 |  | 1 |  |
| `d_desert_golden_emblem` |  | gold_ore | 120 |  | 1 |  |
| `d_desert_dune_conductors` |  | bruteOre | 100000 |  | 1 |  |
| `d_desert_golden_sand` |  | gold_ore | 64 |  | 1 |  |
| `d_desert_core_mockup` | DESERT CORE | sunflowerSeeds | 5.00e11 |  | 1 | Desert popcorn has 5% chance to spawn as Golden Popcorn |
| `d_desert_quest_merchant` | Quest Merchant | goldenPopcorn | 100 |  | 1 | Unlock the quest merchant. |
| `d_desert_golden_popcorn_chance` | GILDED KERNELS | goldenPopcorn | 500 |  | 1 | +2.5% Desert Golden Popcorn chance. |
| `d_desert_seed_generation_x2` | SUNSPROUT IRRIGATION | goldenPopcorn | 10000 |  | 1 | Double sunflower seed generation. |
| `d_desert_fever` | DESERT FEVER | sunflowerSeeds | 5.00e9 |  | 1 | Desert popcorn is worth 5x more. |
| `d_desert_expedition_points` | DESERT CAMPAIGN | sunflowerSeeds | 1.00e10 |  | 1 | +100% Parrot skill points gained in Expedition. |
| `d_desert_rebirb_golden_feathers` | REBIRB MANIPULATION | sunflowerSeeds | 7.00e10 |  | 1 | +100% Golden Feathers gained on Rebirb. |
| `d_desert_rebirb_parrot_vitality` | VITAL PLUMAGE | goldenPopcorn | 50000 |  | 1 | +25% Parrot Vitality gained in Expedition. |
| `d_desert_field_notes` | FIELD NOTES | goldenPopcorn | 0 |  | 1 | Gain 1 Parrot Skill Point per second in Expedition. |
| `d_desert_scout_gull` | SCOUT GULL | goldenPopcorn | 450000 |  | 1 | Send Seagulls to expedition fishing floors. |
| `d_desert_tackle_crate` | TACKLE CRATE | goldenPopcorn | 1.30e6 |  | 1 | Dispatched seagull fishes 35% faster and rerolls weak catches. |
| `d_desert_guarded_plumage` | GUARDED PLUMAGE | goldenPopcorn | 700000 |  | 1 | +15% Expedition parrot HP. |
| `d_desert_salvage_rights` | SALVAGE RIGHTS | goldenPopcorn | 650000 |  | 1 | +25% Expedition Loot value. |
| `d_desert_signal_smoke` | SIGNAL SMOKE | goldenPopcorn | 850000 |  | 1 | 1.5x Golden Popcorn gained. |
| `d_desert_auric_bargain` | AURIC BARGAIN | goldenPopcorn | 2.50e6 |  | 1 | Reduces the price of Golden Popcorn upgrades by 25%. |
| `d_desert_golden_popcorn_chance_3` | MIRAGE KERNELS | goldenPopcorn | 5.00e6 |  | 1 | +2.5% Desert Golden Popcorn chance. |
| `d_desert_golden_popcorn_gain_2` | GOLD RUSH | goldenPopcorn | 2.00e7 |  | 1 | 1.5x Golden Popcorn gained. |
| `d_desert_popcorn_spawn_rate` | DUNE BLOOM | goldenPopcorn | 3.00e7 |  | 1 | Seeds boost Golden Popcorn gained. |
| `d_desert_bloom_netting` | BLOOM NETTING | exp_f4_reefspark_koi | 8 |  | 1 | +15% Desert Popcorn spawn rate. |
| `d_desert_blossom_route` | BLOSSOM ROUTE | exp_f4_shellbloom_bass | 7 |  | 1 | +5% Spirit Aura chance from Expedition Loot. |
| `d_desert_bloom_reservoir` | BLOOM RESERVOIR | exp_f4_crownwake_serpent | 12 |  | 1 | 1.35x Golden Popcorn gained. |
| `d_desert_dune_scouts` | DUNE SCOUTS | exp_f4_mythic_mariana_phantom | 1 |  | 1 | +50% Expedition Loot value. |
| `d_desert_gourmet_golden_popcorn` | GOURMET GOLDEN POPCORN | goldenFeathers | 1.00e21 |  | 1 | Golden Popcorn has a 25% chance to be caramelized, granting 2x Golden Popcorn. |
| `d_desert_bountiful_harvest` | BOUNTIFUL HARVEST | goldenPopcorn | 3.00e9 |  | 1 | 3x Golden Popcorn, 2x Seeds. |
| `d_desert_feathered_harvest` | FEATHERED HARVEST | goldenFeathers | 1.00e10 |  | 1 | Golden Feathers boost Golden Popcorn. |
| `d_desert_golden_popcorn_chance_5` | GILDED DUNES | goldenPopcorn | 1.50e9 |  | 1 | +2.5% Golden Popcorn chance. |
| `d_desert_combat_regen_penalty` | DUNE VIGOR | goldenPopcorn | 1.20e10 |  | 1 | 20% less Parrot combat regen penalty. |
| `d_desert_golden_popcorn_chance_4` | AURIC GLINT | goldenPopcorn | 5.00e7 |  | 1 | +2.5% Desert Golden Popcorn chance. |
| `d_desert_collared_dove` | DAVE | goldenPopcorn | 1.50e7 |  | 1 | Unlock a desert bird that scavenges popcorn in clustered swoops. |
| `d_desert_dave_golden_xp` | GILDED LESSONS | goldenPopcorn | 6.00e7 |  | 1 | Dave gains 2x XP when collecting Golden Popcorn. |
| `d_desert_dave_popcorn_xp` | STEADY PECKING | goldenPopcorn | 5.00e8 |  | 1 | Dave gains 2x XP when collecting normal Popcorn. |
| `d_desert_seed_generation_x5` | DUNE FERTILIZER | popcorn | 1.00e17 |  | 1 | Multiply sunflower seed generation by 2. |
| `d_desert_golden_popcorn_mult_unlock` | GILDED CATALYST | sunflowerSeeds | 3.00e10 |  | 1 | Unlock GOLDEN POPCORN MULT in the Rebirb Shop. |
| `d_desert_golden_popcorn_chance_2` | SUNKISSED KERNELS | goldenFeathers | 5.00e17 |  | 1 | +2.5% Desert Golden Popcorn chance. |
| `d_desert_seed_generation_x2_plus` | DUNE FERTILITY | goldenPopcorn | 100000 |  | 1 | Double the value of sunflower seeds. |
| `d_desert_auric_blueprints` | AURIC BLUEPRINTS | goldenPopcorn | 250000 |  | 1 | Unlock AURIC SILO in the Popcorn Shop. |
| `d_desert_oasis_recovery` | OASIS RECOVERY | goldenPopcorn | 300000 | 1.8 | 5 | +10% Health Regen value per level. |
| `d_desert_popcorn_gain_x2` | SANDSTORM HARVEST | goldenPopcorn | 150000 |  | 1 | Double Popcorn gained. |
| `d_desert_warpath` | DUNE WARPATH | goldenPopcorn | 130000 | 1.5 | 5 | +10% Expedition damage per level. |
| `d_desert_field_notes_plus` | GILDED MARGINS | goldenPopcorn | 5000 | 10 | 3 | +33.3% Golden Popcorn gained per level. |
| `d_desert_muad_birb` | MUAD'BIRB | goldenPopcorn | 5.00e8 |  | 1 | Golden Popcorn boosts Expedition skill points. |
| `d_desert_sandstorm` | SANDSTORM | goldenPopcorn | 4.25e9 |  | 1 | A sandstorm can occur on the desert, turning every popcorn into golden |
| `d_desert_auto_potion` | EMERGENCY FLASK | goldenPopcorn | 2.00e10 |  | 1 | Auto-use expedition potions when HP drops below a set threshold. |
| `d_desert_shiny_enemies` | AURIC ADVERSARIES | goldenPopcorn | 2.50e10 |  | 1 | Expedition enemies have a 1% chance to spawn Shiny. |
| `d_desert_golden_popcorn_x2` | TREASURED HARVEST | goldenPopcorn | 5000 |  | 1 | Double Golden Popcorn gained in Desert. |

## Archivist tree

| id | Name | Currency | Base cost | Growth | Max lvl | Effect |
|---|---|---|---|---|---|---|
| `d_archivist_popcorn_echo` |  | popcorn | 0 |  | 1 |  |
| `d_archivist_auric_rebirb` |  | echoPopcorn | 400 |  | 1 |  |
| `d_archivist_golden_ascension` |  | echoPopcorn | 200000 |  | 1 |  |
| `d_archivist_echo_chance` |  | echoPopcorn | 5000 |  | 1 |  |
| `d_archivist_echo_value_milestones` |  | echoPopcorn | 12000 |  | 1 |  |
| `d_archivist_echo_capacity_expansion` |  | echoPopcorn | 30000 |  | 1 |  |
