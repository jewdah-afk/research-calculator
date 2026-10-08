// Peckwood playtest: core engine. A 1:1 copy of Birb's game rules (birbplay.com build, game-Cwl23x5W.js),
// written fresh from that code with our own names and assets. Function comments name the Birb source.
// Internal ids stay Birb's (popcorn, goldenFeathers, ...); the UI shows Peckwood names (Eggs, Plumes, ...).
"use strict";
(function () {
  const PT = (window.PT = window.PT || {});
  const DATA = window.BIRB_DATA;

  // ------------------------------------------------------------------ big numbers (break_eternity, as in Birb)
  const D = (x) => (x instanceof Decimal ? x : new Decimal(x || 0));
  PT.D = D;
  PT.num = (x) => D(x).toNumber();

  const SUFFIX = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"];
  // Display: K/M/B... up to Vg, then scientific. Small values keep up to 2 decimals.
  PT.fmt = function (x, dp) {
    const d = D(x);
    if (d.lt(1000)) {
      const n = d.toNumber();
      if (Math.abs(n - Math.round(n)) < 1e-9) return String(Math.round(n));
      return n.toFixed(dp ?? (n < 10 ? 2 : 1)).replace(/\.?0+$/, "");
    }
    const e = Math.floor(d.log10().toNumber());
    const k = Math.floor(e / 3);
    if (k < SUFFIX.length) {
      const m = d.div(Decimal.pow(10, k * 3)).toNumber();
      return (m >= 100 ? m.toFixed(1) : m.toFixed(2)).replace(/\.?0+$/, "") + SUFFIX[k];
    }
    const m = d.div(Decimal.pow(10, e)).toNumber();
    return m.toFixed(2) + "e" + e;
  };
  PT.fmtTime = function (s) {
    s = Math.max(0, Math.floor(s));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    return h ? `${h}h ${m}m` : m ? `${m}m ${r}s` : `${r}s`;
  };

  // ------------------------------------------------------------------ upgrade data
  // Effects are Birb's own expressions (upgrades.json keeps them as source). Mine-tree effects
  // name helper functions that live in the mine phase; they return 1 until then.
  const UP = new Map();
  const SUN = new Map(); // one-off sunflower / desert / archivist nodes (Birb: mk)
  for (const u of DATA.upgrades) {
    const def = Object.assign({}, u);
    if (typeof def.effect === "string" && def.effect.startsWith("e=>")) {
      def.effectFn = new Function("return (" + def.effect + ")")();
    } else def.effectFn = () => 1;
    if (def.id.startsWith("d_")) SUN.set(def.id, def);
    else UP.set(def.id, def);
  }
  PT.UP = UP;
  PT.SUN = SUN;
  PT.STATIONS = DATA.stations;

  // ------------------------------------------------------------------ state (Birb: createDefaultState, Phase 1 fields)
  PT.newState = function () {
    return {
      saveVersion: 1,
      resources: { popcorn: D(0), goldenPopcorn: D(0), echoPopcorn: D(0), goldenFeathers: D(0), sunflowerSeeds: D(0), monetariaMoneta: D(0), twigs: D(0), bruteOre: D(0) },
      player: { x: 528, y: 396 },
      upgrades: {},
      sunflowerUpgrades: {},
      sparrow: { unlocked: false, level: 1, xp: 0, maxLevelReached: 1 },
      sparrowCount: 1,
      sparrowPrestigeCount: 0,
      sparrowResonanceXP: 0,
      sparrowTotalEnergyDrained: 0,
      sparrowSeedFeedRatePercent: 25,
      isFeedingSparrow: false,
      isDrainingSparrow: false,
      sparrowAutoMitosisEnabled: false,
      sparrowAutoRebirbEnabled: false,
      totalPopcornCollected: D(0),
      playTime: 0,
      hasEnteredDungeon: false,
      hasTalkedToMonster: false,
      hasUnlockedEvolve: false,
      monsterFeedProgress: 0,
      monsterPopcornFed: 0, monsterFeathersFed: 0, monsterSeedsFed: 0, monsterFishFed: 0, monsterTwigsFed: 0, monsterMonetaFed: 0,
      evolutionCount: 0,
      rebirthCount: 0,
      totalFishCaught: 0,
      currentMap: 0,
      lastActiveAt: Date.now(),
    };
  };

  // ------------------------------------------------------------------ resources (Birb: hs add, ao subtract, ho has)
  PT.res = (s, k) => D(s.resources[k]);
  PT.add = (s, k, v) => { s.resources[k] = D(s.resources[k]).add(v); };
  PT.sub = (s, k, v) => { s.resources[k] = Decimal.max(0, D(s.resources[k]).sub(v)); };
  PT.has = (s, k, v) => D(s.resources[k]).gte(v);

  // ------------------------------------------------------------------ sunflower nodes (Birb: getSunflowerLevel / hasSunflowerUpgrade)
  PT.sunLevel = (s, id) => (SUN.has(id) && s.sunflowerUpgrades[id]) || 0;
  PT.hasSun = (s, id) => PT.sunLevel(s, id) >= 1;

  // ------------------------------------------------------------------ leveled upgrades (Birb: upgradeManager)
  PT.maxLevel = function (s, id) {
    const def = UP.get(id);
    if (!def) return 0;
    let n = def.maxLevel || 0;
    if (id === "pr_popcorn_mult" && PT.hasSun(s, "d_pop_max_lvl")) n += 2;
    if (id === "p_move_speed" && PT.hasSun(s, "d_wing_mastery_plus")) n += 10;
    if (id === "p_capacity" && PT.hasSun(s, "d_silo_mastery_plus")) n += 10;
    return n;
  };
  // p_/pr_/s_/m_ start at level 1 (p_auric_silo only with Auric Blueprints), everything else at 0.
  PT.level = function (s, id) {
    const def = UP.get(id);
    let t;
    if (def && def.initialLevel !== undefined) t = s.upgrades[id] ?? def.initialLevel;
    else if ((id.startsWith("p_") || id.startsWith("pr_") || id.startsWith("s_") || id.startsWith("m_")) &&
      (id !== "p_auric_silo" || PT.hasSun(s, "d_desert_auric_blueprints"))) t = s.upgrades[id] || 1;
    else t = s.upgrades[id] || 0;
    const m = PT.maxLevel(s, id);
    return m > 0 ? Math.min(t, m) : t;
  };
  PT.effect = function (s, id) {
    const def = UP.get(id);
    if (!def) return 0;
    return def.effectFn(PT.level(s, id));
  };

  // Cost of the next level, charged at the current level L (CORE_FORMULAS.md §1, verified against the bundle).
  PT.cost = function (def, L) {
    const id = def.id;
    if (id === "p_echo_value") {
      const t = Math.min(999, Math.max(1, Math.floor(L)));
      return Math.floor(10 * 1.35 ** Math.min(24, t - 1) * 1.114 ** Math.min(75, Math.max(0, t - 25)) * 1.14 ** Math.max(0, t - 100));
    }
    if (id === "m_rupture") return Math.ceil(2e6 * 2.7 ** (L - 1));
    if (id === "m_charged_strike") return 4800 * 24 ** (L - 1);
    if (id.startsWith("d_") && def.costMultiplier !== undefined) {
      const a = Math.max(0, Math.floor(L));
      const r = id === "d_mine_abyssal_forge" ? 3 ** Math.min(200, a) * 2.85 ** Math.max(0, a - 200) : def.costMultiplier ** a;
      return Math.ceil((def.cost ?? def.baseCost) * r);
    }
    if (id === "p_value") return L < 5 ? L : Math.floor(4 * 1.3312 ** (L - 4));
    const base = def.baseCost ?? def.cost ?? 0;
    const mult = def.costMultiplier ?? 1;
    const t = def.tree;
    if (t === "P" || t === "PR" || t === "S" || t === "M") return Math.floor(base * mult ** Math.max(0, L - (def.initialLevel ?? 1)));
    return Math.floor(base * mult ** L);
  };
  // Birb: getDiscountedUpgradeCost (Auric Bargain: golden-popcorn prices x0.75, min 1)
  PT.discounted = function (s, def, L) {
    const c = PT.cost(def, L);
    if (c > 0 && def.costCurrency === "goldenPopcorn" && PT.hasSun(s, "d_desert_auric_bargain")) return Math.max(1, Math.floor(0.75 * c));
    return c;
  };
  const freeSeeds = (s, cur) => cur === "sunflowerSeeds" && PT.hasSun(s, "d_free_seeds");

  // Birb: purchaseUpgrade
  PT.buy = function (s, id) {
    const def = UP.get(id);
    if (!def) return false;
    const L = PT.level(s, id);
    if (L >= PT.maxLevel(s, id)) return false;
    if (def.requires && typeof def.requires === "object" && PT.level(s, def.requires.upgrade) < def.requires.level) return false;
    const c = PT.discounted(s, def, L);
    if (!PT.has(s, def.costCurrency, c)) return false;
    if (!freeSeeds(s, def.costCurrency)) PT.sub(s, def.costCurrency, c);
    s.upgrades[id] = L + 1;
    return true;
  };
  // Birb: purchaseUpgradeMax (buys one level at a time until it can't)
  PT.buyMax = function (s, id) {
    let n = 0;
    while (PT.buy(s, id)) n++;
    return n;
  };

  // ------------------------------------------------------------------ sunflower tree rules (Birb: fk.getSunflowerParentIds ...)
  PT.sunParents = function (id) {
    if (id === "d_unlock_archivist_tree") return ["d_desert_golden_reserve", "d_desert_golden_sand", "d_desert_golden_emblem"];
    const n = SUN.get(id);
    if (!n) return [];
    if (id === "d_gravity_field") return ["d_kernel_polish", "d_quantum_corn"];
    if (id === "d_desert_muad_birb") return ["d_desert_oasis_recovery", "d_desert_field_notes_plus"];
    if (id === "d_desert_collared_dove") return ["d_desert_tackle_crate", "d_desert_signal_smoke"];
    if (id === "d_desert_golden_popcorn_chance_4") return ["d_desert_golden_popcorn_gain_2", "d_desert_popcorn_spawn_rate"];
    if (id === "d_desert_auto_potion" || id === "d_desert_shiny_enemies") return ["d_desert_sandstorm"];
    return n.requires ? [n.requires] : [];
  };
  const needsAllParents = (id) => id === "d_unlock_archivist_tree" || id === "d_desert_auto_potion";
  PT.chainConnected = function (s, id, memo = new Map()) {
    if (memo.has(id)) return memo.get(id);
    const n = SUN.get(id);
    if (!n) { memo.set(id, false); return false; }
    const ps = PT.sunParents(id);
    let r;
    if ((n.permanent && (n.mineAreaRequired || id === "d_unlock_archivist_tree") && PT.hasSun(s, id)) || ps.length === 0) r = true;
    else r = needsAllParents(id) ? ps.every((p) => PT.hasSun(s, p) && PT.chainConnected(s, p, memo)) : ps.some((p) => PT.hasSun(s, p) && PT.chainConnected(s, p, memo));
    memo.set(id, r);
    return r;
  };
  PT.mineArea = (s) => s.mine?.area || 0;
  PT.sunUnlocked = function (s, id) {
    if (id === "d_unlock_archivist_tree" && PT.hasSun(s, id)) return true;
    const n = SUN.get(id);
    if (!n) return false;
    if ((n.mineAreaRequired || 0) > PT.mineArea(s)) return false;
    if (n.evolutionRequired && (s.evolutionCount || 0) < n.evolutionRequired) return false;
    if (n.nestTierRequired && ((s.nest?.tier || 0) + 1) < n.nestTierRequired) return false;
    if (n.parrotRebirbRequired && (s.parrot?.rebirbCount || 0) < n.parrotRebirbRequired) return false;
    const ps = PT.sunParents(id);
    if (ps.length === 0) return true;
    const memo = new Map();
    return needsAllParents(id) ? ps.every((p) => PT.hasSun(s, p) && PT.chainConnected(s, p, memo)) : ps.some((p) => PT.hasSun(s, p) && PT.chainConnected(s, p, memo));
  };
  // Birb: isSunflowerUpgradeVisible (nodes show one evolution early if their parent chain is owned)
  PT.sunVisible = function (s, id) {
    const t = SUN.get(id);
    if (!t) return false;
    if (!t.requires) return true;
    const n = s.evolutionCount || 0, need = t.evolutionRequired ?? 0;
    if (need > n + 1) return false;
    const ps = PT.sunParents(id);
    const parentOk = () => ps.length === 0 || ps.some((p) => PT.hasSun(s, p) && PT.chainConnected(s, p));
    if (need > n) return parentOk();
    if (PT.hasSun(s, id)) return PT.chainConnected(s, id);
    return parentOk();
  };
  PT.sunCost = function (s, id) {
    const n = SUN.get(id);
    if (!n) return 0;
    return PT.discounted(s, Object.assign({ cost: n.cost }, n), PT.sunLevel(s, id));
  };
  // Birb: purchaseSunflowerUpgrade. Returns "" on success or the reason it failed.
  PT.buySun = function (s, id) {
    const n = SUN.get(id);
    if (!n) return "unknown";
    const L = PT.sunLevel(s, id);
    if (L >= (n.maxLevel || 1)) return "owned";
    const ps = PT.sunParents(id);
    if (ps.length && !(needsAllParents(id) ? ps.every((p) => PT.hasSun(s, p)) : ps.some((p) => PT.hasSun(s, p)))) return "locked";
    if (!PT.sunUnlocked(s, id)) return "locked";
    const cur = n.costCurrency, c = PT.sunCost(s, id);
    if (cur === "totalFishCaught") { if ((s.totalFishCaught || 0) < c) return "not enough"; }
    else if (!(cur in s.resources)) return "needs " + cur; // fish, gold ore, keys, books: later phases
    else { if (!PT.has(s, cur, c)) return "not enough"; if (!freeSeeds(s, cur)) PT.sub(s, cur, c); }
    s.sunflowerUpgrades[id] = L + 1;
    if (id === "d_unlock_evolve") s.hasUnlockedEvolve = true;
    if (id === "d_unlock_desert_tree") s.hasUnlockedDesertMap = true;
    return "";
  };
})();
