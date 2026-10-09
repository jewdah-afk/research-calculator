// Phase 1 parity: extra save states (Birb's save shape, like playtest/parity/scenarios.js, so they could also be run
// against Birb's live engine) and the action programs both the playtest and Game.luau run step by step.
//
// Program ops (both sides implement each one; see playtest_dump.js and lua_dump.luau):
//   { op: "seed", type, pos, sparrow }   reseed the three random streams (egg type rolls, egg spots, sparrow wander)
//   { op: "map", map, x, y }             put the bird on Birb map `map` (0 Park, 1 Sunflower Field, 3 Castle) at px x, y
//   { op: "platform" }                   stand on the Sunflower Field's seed platform
//   { op: "wait", t }                    run the step for t seconds in 0.05 s steps
//   { op: "eggs", n }                    walk onto the first n eggs of the Park field, one 0.05 s step each
//   { op: "buy", id, max }               shop row: one level, or MAX
//   { op: "buyAll" }                     MAX every P1 shop row in drawer order
//   { op: "molt" } / { op: "evolve" }
//   { op: "sun", id } / { op: "sunAll" } tree node(s): one id, or every visible station in field order (one pass)
//   { op: "sparrow", what }              feed | drain | stop | mitosis | rebirb | autoMitosis | autoRebirb | rate:<pct>
//   { op: "talk" } / { op: "hold", on }  castle: talk to the monster, hold / release FEED
//   { op: "give", cur, n }               add currency (dev grant) to reach later steps
//   { op: "snap", tag }                  record every sim value under "sim <tag> ..."
"use strict";

const FULL = [
  { op: "seed", type: 11, pos: 22, sparrow: 33 },
  { op: "map", map: 0, x: 528, y: 396 },
  { op: "wait", t: 20 }, { op: "snap", tag: "a park20" },
  { op: "eggs", n: 30 }, { op: "snap", tag: "b eggs" },
  { op: "buyAll" }, { op: "snap", tag: "c shop" },
  { op: "wait", t: 40 }, { op: "eggs", n: 60 }, { op: "snap", tag: "d park" },
  { op: "molt" }, { op: "snap", tag: "e molt" },
  { op: "buyAll" }, { op: "sunAll" }, { op: "snap", tag: "f buys" },
  { op: "platform" }, { op: "wait", t: 12 }, { op: "snap", tag: "g platform" },
  { op: "map", map: 0, x: 300, y: 250 }, { op: "wait", t: 15 }, { op: "eggs", n: 40 }, { op: "snap", tag: "h park" },
  { op: "map", map: 3, x: 800, y: 500 }, { op: "talk" }, { op: "hold", on: true }, { op: "wait", t: 4 }, { op: "hold", on: false }, { op: "snap", tag: "i castle" },
  { op: "hold", on: true }, { op: "wait", t: 11 }, { op: "hold", on: false }, { op: "evolve" }, { op: "snap", tag: "j evolve" },
  { op: "wait", t: 10 }, { op: "snap", tag: "k after" },
];

// sparrow-focused program: away from the Park the flock keeps collecting; feeder, drain, mitosis, rebirb, autos
const FLOCK = [
  { op: "seed", type: 5, pos: 6, sparrow: 7 },
  { op: "map", map: 0, x: 528, y: 396 }, { op: "wait", t: 8 }, { op: "snap", tag: "a park" },
  { op: "map", map: 1, x: 900, y: 900 }, { op: "sparrow", what: "feed" }, { op: "wait", t: 20 }, { op: "snap", tag: "b away" },
  { op: "sparrow", what: "rate:60" }, { op: "platform" }, { op: "wait", t: 10 }, { op: "snap", tag: "c platform" },
  { op: "sparrow", what: "mitosis" }, { op: "snap", tag: "d mitosis" },
  { op: "sparrow", what: "rebirb" }, { op: "snap", tag: "e rebirb" },
  { op: "sparrow", what: "autoMitosis" }, { op: "sparrow", what: "autoRebirb" }, { op: "sparrow", what: "feed" }, { op: "wait", t: 20 }, { op: "snap", tag: "f autos" },
  { op: "sparrow", what: "drain" }, { op: "wait", t: 1 }, { op: "snap", tag: "g drain" },
  { op: "sparrow", what: "stop" }, { op: "map", map: 0, x: 200, y: 600 }, { op: "wait", t: 25 }, { op: "snap", tag: "h park" },
  { op: "map", map: 3, x: 800, y: 500 }, { op: "wait", t: 30 }, { op: "snap", tag: "i castle" },
];

// castle: hold FEED until 100%, evolve (the reset), then play on in the new evolution
const CASTLE = [
  { op: "seed", type: 12, pos: 13, sparrow: 14 },
  { op: "map", map: 0, x: 528, y: 396 }, { op: "wait", t: 6 }, { op: "eggs", n: 10 }, { op: "snap", tag: "a park" },
  { op: "map", map: 3, x: 800, y: 500 }, { op: "hold", on: true }, { op: "wait", t: 2 }, { op: "snap", tag: "b silent" },
  { op: "talk" }, { op: "wait", t: 6 }, { op: "snap", tag: "c feeding" },
  { op: "wait", t: 6 }, { op: "hold", on: false }, { op: "snap", tag: "d fed" },
  { op: "evolve" }, { op: "snap", tag: "e evolved" },
  { op: "wait", t: 15 }, { op: "eggs", n: 20 }, { op: "buyAll" }, { op: "snap", tag: "f after" },
  { op: "evolve" }, { op: "snap", tag: "g again" },
];

// gravity field + magnet radius: the bird stands still while eggs drift in
const GRAVITY = [
  { op: "seed", type: 1, pos: 2, sparrow: 3 },
  { op: "map", map: 0, x: 528, y: 396 }, { op: "wait", t: 30 }, { op: "snap", tag: "a pull" },
  { op: "map", map: 0, x: 120, y: 120 }, { op: "wait", t: 30 }, { op: "snap", tag: "b corner" },
  { op: "eggs", n: 80 }, { op: "snap", tag: "c eggs" },
];

const BASE_P1 = { d_sunflower_machine: 1, d_popcorn_cap: 1, d_auto_gen: 1, d_faster_seeds: 1, d_seed_multiplier: 1, d_rebirth_playtime: 1, d_golden_harvest: 1, d_unlock_evolve: 1 };

const SCENARIOS = [
  { name: "p1 types and limits", state: { rebirthCount: 6, playTime: 9000, resources: { popcorn: 4e9, goldenFeathers: 9e6, sunflowerSeeds: 5e9 },
    upgrades: { p_value: 150, p_speed: 12, p_capacity: 50, p_move_speed: 25, pr_popcorn_mult: 9, pr_radius_mult: 5, pr_respawn_mult: 4, s_more_popcorn: 20, s_more_feathers: 12, s_more_seeds: 9, f_rainbow_chance: 3 },
    sunflowerUpgrades: { ...BASE_P1, d_cheese_powder: 1, d_rainbow_aura: 1, d_butter_bonanza: 1, d_pop_max_lvl: 1, d_seed_multiplier_unlocker: 1, d_wing_mastery_plus: 1, d_silo_mastery_plus: 1, d_butter_hose: 1, d_kernel_polish: 1, d_pickup_range: 1, d_swift_wings: 1 } },
    program: FULL },
  { name: "p1 free seeds evo 2", state: { evolutionCount: 2, rebirthCount: 12, playTime: 4e4, resources: { popcorn: 6e11, goldenFeathers: 3e8, sunflowerSeeds: 2e8 },
    upgrades: { p_value: 240, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, pr_respawn_mult: 4, s_more_popcorn: 30, s_more_seeds: 25 },
    sunflowerUpgrades: { ...BASE_P1, d_free_seeds: 1, d_seed_synergy: 1, d_golden_butter: 1, d_quantum_corn: 1, d_seed_pipeline: 1, d_seed_bag: 1, d_focus_training: 1 },
    sparrow: { unlocked: true, level: 40, xp: 900, maxLevelReached: 55 }, sparrowCount: 2, sparrowResonanceXP: 2.5e5 },
    program: FULL },
  { name: "p1 sparrow flock", state: { evolutionCount: 2, rebirthCount: 15, playTime: 6e4, resources: { popcorn: 2e12, goldenFeathers: 5e9, sunflowerSeeds: 3e9 },
    upgrades: { p_value: 300, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, s_more_seeds: 40 },
    sunflowerUpgrades: { ...BASE_P1, d_seed_feeder: 1, d_sparrow_drain_power: 1, d_sparrow_mitosis: 1, d_sparrow_xp_2: 1, d_sparrow_snacks: 1, d_hive_mind: 1, d_mecha_birb: 1 },
    sparrow: { unlocked: true, level: 82, xp: 1500, maxLevelReached: 82 }, sparrowCount: 2, sparrowPrestigeCount: 0, sparrowResonanceXP: 1e4 },
    program: FLOCK },
  { name: "p1 sparrow rebirb", state: { evolutionCount: 3, rebirthCount: 25, playTime: 1e5, resources: { popcorn: 5e14, goldenFeathers: 2e11, sunflowerSeeds: 4e10, monetariaMoneta: 3e4 },
    upgrades: { p_value: 500, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, s_more_seeds: 60 },
    sunflowerUpgrades: { ...BASE_P1, d_seed_feeder: 1, d_sparrow_drain_power: 1, d_sparrow_mitosis: 1, d_sparrow_wisdom: 1, d_sparrow_hoard: 1 },
    sparrow: { unlocked: true, level: 205, xp: 5000, maxLevelReached: 210 }, sparrowCount: 16, sparrowPrestigeCount: 4, sparrowResonanceXP: 3e6,
    sparrowAutoMitosisEnabled: true, nest: { unlocked: true, tier: 1 } },
    program: FLOCK },
  { name: "p1 castle evo 1", state: { evolutionCount: 1, rebirthCount: 10, playTime: 3e4, resources: { popcorn: 3e10, goldenFeathers: 4e7, sunflowerSeeds: 1e6, monetariaMoneta: 1500 },
    upgrades: { p_value: 200, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, s_more_seeds: 10 },
    sunflowerUpgrades: { ...BASE_P1 }, monsterPopcornFed: 2e9, monsterMonetaFed: 100,
    sparrow: { unlocked: true, level: 12, xp: 30, maxLevelReached: 12 } },
    program: CASTLE },
  { name: "p1 castle evo 2 seeds", state: { evolutionCount: 2, rebirthCount: 14, playTime: 5e4, resources: { popcorn: 4e11, goldenFeathers: 1e9, sunflowerSeeds: 5e7 },
    upgrades: { p_value: 280, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, s_more_seeds: 20 },
    sunflowerUpgrades: { ...BASE_P1, d_seed_feeder: 1 }, sparrow: { unlocked: true, level: 5, xp: 10, maxLevelReached: 70 }, sparrowCount: 4, sparrowResonanceXP: 4e4 },
    program: CASTLE },
  { name: "p1 castle first evolve", state: { rebirthCount: 8, playTime: 2e4, resources: { popcorn: 4e7, goldenFeathers: 2e6, sunflowerSeeds: 3e5 },
    upgrades: { p_value: 150, p_speed: 12, p_capacity: 30, pr_popcorn_mult: 6 }, sunflowerUpgrades: { ...BASE_P1 }, hasUnlockedEvolve: true },
    program: CASTLE },
  { name: "p1 gravity field", state: { evolutionCount: 4, rebirthCount: 30, playTime: 2e5, resources: { popcorn: 1e15, goldenFeathers: 1e12, sunflowerSeeds: 1e11 },
    upgrades: { p_value: 600, p_speed: 12, p_capacity: 40, pr_popcorn_mult: 7, pr_radius_mult: 3, pr_respawn_mult: 4 },
    sunflowerUpgrades: { ...BASE_P1, d_butter_hose: 1, d_kernel_polish: 1, d_quantum_corn: 1, d_gravity_field: 1, d_void_silo: 1 } },
    program: GRAVITY },
  { name: "p1 fresh full run", state: {}, program: [
    { op: "seed", type: 9, pos: 8, sparrow: 4 }, { op: "map", map: 0, x: 528, y: 396 },
    { op: "wait", t: 10 }, { op: "eggs", n: 20 }, { op: "buyAll" }, { op: "snap", tag: "a start" },
    { op: "wait", t: 30 }, { op: "eggs", n: 40 }, { op: "buyAll" }, { op: "wait", t: 30 }, { op: "eggs", n: 40 }, { op: "snap", tag: "b grow" },
    { op: "give", cur: "popcorn", n: 2e6 }, { op: "molt" }, { op: "buyAll" }, { op: "sunAll" }, { op: "snap", tag: "c molt" },
    { op: "give", cur: "goldenFeathers", n: 1e3 }, { op: "sunAll" }, { op: "platform" }, { op: "wait", t: 20 }, { op: "buyAll" }, { op: "sunAll" }, { op: "snap", tag: "d seeds" },
  ] },
];

// the playtest's original Phase 1 scenarios get the full program too
const PROGRAMS = { "fresh start": FULL, "early eggs": FULL, "first molt done": FULL, "seeds online": FULL, "evolve unlocked": FULL, "evolution 1": FULL, "evolution 3": FULL };
const P1_NAMES = new Set(["fresh start", "early eggs", "first molt done", "seeds online", "evolve unlocked", "evolution 1", "evolution 3", ...SCENARIOS.map((s) => s.name)]);

module.exports = { SCENARIOS, PROGRAMS, P1_NAMES };
