# Icon inventory (2026-10-09)

What the game needs vs what is in `birb-icons/final` (204 icons + 426 fish). "Stand-in" = the playtest shows a generic icon there today.

## Have (complete sets)
| Set | Count |
|---|---|
| Fish (`fish/`) | 426 / 426 |
| Rods | 23 / 23 |
| Baits | 12 / 12 (+ 13 shiny baits) |
| Hooks / lures | 7 / 7, 5 / 5 |
| Sacrifice tiers I–XVIII | 18 / 18 |
| Currencies | eggs, golden egg, shiny egg, plume, seed, moneta, twig, wood, echo, brute ore, gold ore, skill point |
| Shop products | 17 |
| Egg / seed / plume / mine / echo upgrades (`up_*`) | 24 |
| Aquarium tanks | 5 |
| Companions | sparrow, dove (Dave), seagull, crow (+ miner), parrot, red panda, golem, monster |
| Mine ores | 8 (dirt, stone, iron, gold, crystal, obsidian, emerald, ruby) |
| Quest types | 6 (boss, daily, floor, hunt, merchant, scroll) |
| UI | map, teleport, settings, profile/index, leaderboard, trophy, crown, clock, auto, shop, badges x6, frame, lattice |

## Added 2026-10-09 (Figma AI, gpt-image, 22 sheets in `sheets/items_01.png` and `sheets/set_01..21.png`, cut by `cut_grid.py` via `do_sheet.py`)

All 340 are in `final/`. Prompts: `sheets/new_prompts.json`.

**Expedition items (47):** `quest_archivist_book`, `item_veil_heart`, `item_watcher_oath`, `item_simple_book`, `item_small_shield`, `item_pair_of_boots`, `item_flute`, `item_spirit_vests`, `item_spirit_feather`, `item_holy_symbol`, `item_divine_symbol`, `item_spirit_amulete`, `item_strange_key`, `item_empty_potion`, `item_garden_cheese`, `item_single_boot`, `item_mythic_spirit_trash`, `item_spirit_trash`, `item_uncommon_spirit_trash`, `item_rare_spirit_trash`, `item_epic_spirit_trash`, `item_legendary_spirit_trash`, `item_crow_feather`, `item_egg`, `item_spirit_soup`, `item_bone`, `item_famous_book`, `item_golden_amulet`, `item_harp`, `item_lava_bucket`, `item_legendary_book`, `item_magic_mushroom`, `item_money_bag`, `item_mythic_book`, `item_pile_of_points`, `item_poison_pie`, `item_shadow_shield`, `item_predator_instinct`, `item_echo_shell`, `item_blood_beak`, `item_relentless_hunter`, `item_storm_locket`, `item_skull`, `item_minor_heal_pot`, `item_full_potion`, `item_full_recovery_pot`, `item_gold_ore`

**Parrot gear and skills (20):** `gear_beak_common`, `gear_beak_uncommon`, `gear_beak_rare`, `gear_beak_epic`, `gear_beak_legendary`, `gear_armor_common`, `gear_armor_uncommon`, `gear_armor_rare`, `gear_armor_epic`, `gear_armor_legendary`, `gear_aura_common`, `gear_aura_uncommon`, `gear_aura_rare`, `gear_aura_epic`, `gear_aura_legendary`, `gear_aura_mythic`, `skill_hp`, `skill_regen`, `skill_damage`, `parrot_rebirb`

**Enemies (44):** `enemy_elven_assassin`, `enemy_zombie_cultist`, `enemy_shardsoul_slayer`, `enemy_masked_forest_spirit`, `enemy_twig_blight`, `enemy_giant_fly`, `enemy_cobra`, `enemy_ghoul`, `enemy_skeleton_warrior`, `enemy_mummy`, `enemy_anubis_warrior`, `enemy_fishfolk_archpriest`, `enemy_fishfolk_whipe`, `enemy_fishfolk_inkbender`, `enemy_fishfolk_brute`, `enemy_fishfolk_horror`, `enemy_fishfolk_pugilist`, `enemy_sea_horror`, `enemy_sea_gramlin`, `enemy_elemental`, `enemy_frost_wisp`, `enemy_arctic_whisper`, `enemy_frosty_slime`, `enemy_frozy_cube`, `enemy_ice_fire_guardian`, `enemy_frogfolk_wizard`, `enemy_frogfolk_brute`, `enemy_frogfolk_chieftain`, `enemy_ghost`, `enemy_doppelganger`, `enemy_black_pudding`, `enemy_giant_black_pudding`, `enemy_hell_critter`, `enemy_imp`, `enemy_cacodaemon`, `enemy_cultist`, `enemy_cultist_brute`, `enemy_the_archivist`, `enemy_witch`, `enemy_anubis`, `enemy_flower_monster`, `enemy_harpy`, `enemy_ice_harpy`, `enemy_mini_fly`

**Nest buildings (9):** `nest_fertilizer`, `nest_specialized_fertilizer`, `nest_grain_silo`, `nest_cornfield`, `nest_sunflower_field`, `nest_watering_well`, `nest_tree_box`, `nest_quad_box`, `nest_expansion`

**Riverside (5):** `riv_pollinator`, `riv_lumberyard`, `riv_compost`, `riv_grove`, `riv_nursery`

**Sawmill and planks (9):** `saw_timber`, `saw_forestry`, `saw_sawmill`, `saw_precision`, `saw_workbench`, `saw_tools`, `saw_mastery`, `saw_efficiency`, `plank`

**Dave milestones (8):** `dave_firsthop`, `dave_quickfeet`, `dave_sharpeyes`, `dave_davessons`, `dave_workrhythm`, `dave_fieldsense`, `dave_davesfamily`, `dave_masterforager`

**Crow, Expedition and Echo extras (11):** `crow_rebirb`, `crow_training`, `night_mode`, `totem`, `mythic_sacrifice`, `secret_room`, `echo_nearby`, `echo_meeting`, `echo_trail`, `relic`, `legendary_key`

**Sunflower tree (84):** `node_sunflower_machine`, `node_seed_feeder`, `node_seed_multiplier`, `node_rebirth_playtime`, `node_golden_harvest`, `node_unlock_evolve`, `node_seed_synergy`, `node_butter_bonanza`, `node_sparrow_snacks`, `node_rainbow_aura`, `node_cheese_powder`, `node_double_catch`, `node_fast_reeling`, `node_seagull_synergy`, `node_treasure_map`, `node_popcorn_cap`, `node_swift_wings`, `node_auto_gen`, `node_faster_seeds`, `node_pickup_range`, `node_seed_multiplier_unlocker`, `node_seed_pipeline`, `node_pop_max_lvl`, `node_spirit_scouting`, `node_spirit_shell`, `node_spirit_momentum`, `node_fish_seeds`, `node_seagull_xp`, `node_seed_market`, `node_trophy_bonus`, `node_double_fish_buff`, `node_golden_rain`, `node_prism_shine`, `node_platinum_wings`, `node_deep_dive`, `node_fish_frenzy`, `node_sparrow_legacy`, `node_sparrow_xp_2`, `node_free_seeds`, `node_sparrow_drain_power`, `node_sparrow_mitosis`, `node_treasure_appraisal`, `node_fish_value`, `node_rod_chance`, `node_critical_reel`, `node_xp_tome`, `node_bulk_bonus`, `node_profit_surge`, `node_treasure_seeker`, `node_shiny_scale`, `node_seed_bag`, `node_sparrow_hoard`, `node_wing_mastery_plus`, `node_silo_mastery_plus`, `node_butter_hose`, `node_focus_training`, `node_quantum_corn`, `node_kernel_polish`, `node_sparrow_wisdom`, `node_sparrow_lineage`, `node_abyssal_light`, `node_net_mastery`, `node_amber_alchemy`, `node_leviathan_mastery`, `node_ocean_bounty`, `node_gravity_field`, `node_golden_butter`, `node_crit_pop`, `node_void_silo`, `node_hyper_metabolism`, `node_hive_mind`, `node_seed_bank`, `node_mecha_birb`, `node_ancestral_radio`, `node_lunar_compass`, `node_legend_beacon`, `node_migration_amplifier`, `node_gull_sonar`, `node_rare_routes`, `node_echo_vectors`, `node_fleet_training`, `node_frenzy_reactor`, `node_cold_start`, `node_patrol_network`

**Archivist branch (28):** `node_unlock_archivist_tree`, `node_archivist_popcorn_echo`, `node_archivist_auric_rebirb`, `node_archivist_golden_ascension`, `node_archivist_echo_chance`, `node_archivist_echo_value_milestones`, `node_archivist_echo_capacity_expansion`, `node_archivist_echo_near_response`, `node_archivist_echo_duet`, `node_archivist_echo_tuning`, `node_archivist_echo_trail`, `node_archivist_echo_chord`, `node_archivist_echo_harvest`, `node_archivist_echo_mycelium`, `node_archivist_echo_meeting`, `node_archivist_echo_network`, `node_archivist_echo_roots`, `node_archivist_echo_coordination`, `node_archivist_echo_route`, `node_archivist_echo_flock_memory`, `node_archivist_echo_golden_memory`, `node_archivist_echo_veil`, `node_archivist_echo_knowledge`, `node_archivist_echo_ancient_roots`, `node_archivist_echo_deep_memory`, `node_archivist_echo_resonant_grove`, `node_archivist_echo_forever`, `node_unlock_archivist_tree`

**Desert tree (52):** `node_unlock_desert_tree`, `node_desert_tempered_glass`, `node_desert_golden_reserve`, `node_desert_mineral_tracker`, `node_desert_golden_emblem`, `node_desert_dune_conductors`, `node_desert_golden_sand`, `node_desert_core_mockup`, `node_desert_quest_merchant`, `node_desert_golden_popcorn_chance`, `node_desert_seed_generation_x2`, `node_desert_fever`, `node_desert_expedition_points`, `node_desert_rebirb_golden_feathers`, `node_desert_rebirb_parrot_vitality`, `node_desert_field_notes`, `node_desert_scout_gull`, `node_desert_tackle_crate`, `node_desert_guarded_plumage`, `node_desert_salvage_rights`, `node_desert_signal_smoke`, `node_desert_auric_bargain`, `node_desert_golden_popcorn_chance_3`, `node_desert_golden_popcorn_gain_2`, `node_desert_popcorn_spawn_rate`, `node_desert_bloom_netting`, `node_desert_blossom_route`, `node_desert_bloom_reservoir`, `node_desert_dune_scouts`, `node_desert_gourmet_golden_popcorn`, `node_desert_bountiful_harvest`, `node_desert_feathered_harvest`, `node_desert_golden_popcorn_chance_5`, `node_desert_combat_regen_penalty`, `node_desert_golden_popcorn_chance_4`, `node_desert_collared_dove`, `node_desert_dave_golden_xp`, `node_desert_dave_popcorn_xp`, `node_desert_seed_generation_x5`, `node_desert_golden_popcorn_mult_unlock`, `node_desert_golden_popcorn_chance_2`, `node_desert_seed_generation_x2_plus`, `node_desert_auric_blueprints`, `node_desert_oasis_recovery`, `node_desert_popcorn_gain_x2`, `node_desert_warpath`, `node_desert_field_notes_plus`, `node_desert_muad_birb`, `node_desert_sandstorm`, `node_desert_auto_potion`, `node_desert_shiny_enemies`, `node_desert_golden_popcorn_x2`

**Mine tree (23):** `node_mine_work_perch`, `node_mine_precise_peck`, `node_mine_rich_vein`, `node_mine_impact_transfer`, `node_mine_peck_rhythm`, `node_mine_deep_survey`, `node_mine_seismic_strike`, `node_mine_mineral_temper`, `node_mine_clean_extraction`, `node_mine_unbroken_rhythm`, `node_mine_work_pulse`, `node_mine_gold_beacon`, `node_mine_crown_survey`, `node_mine_fine_cut`, `node_mine_royal_mastery`, `node_mine_deep_mine`, `node_mine_royal_impact`, `node_mine_mineral_coffers`, `node_mine_seismic_echo`, `node_mine_royal_cut`, `node_mine_abyssal_forge`, `node_mine_abyssal_treasure`, `node_mine_deep_rebirb`

Still to do: hook them into the playtest / 3D build and `Icons.luau`, and place them in Figma.
