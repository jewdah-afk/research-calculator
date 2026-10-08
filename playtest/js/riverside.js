// Peckwood playtest, Phase 3b: Riverside (Nest IV + Evolution 6) and the sawmill (carpentry), copied from Birb's
// nestManager riverside / carpentry code. Numbers only; the code is written fresh.
// Riverside: five twig buildings (Pollinator Garden, Lumberyard, Composter, Riverside Grove x4, Nursery).
// The Lumberyard turns felled trees into wood (24 tree HP = 1 wood) and opens the sawmill, which cuts wood into planks
// and sells WOOD / SAWMILL upgrades for twigs, wood and planks. Riverside and the sawmill survive Evolution; wood does not.
"use strict";
(function () {
  const PT = window.PT;
  const r12 = (x) => Number(Number(x).toPrecision(12));

  // ------------------------------------------------------------------ riverside constants (Birb maps cq/aj/cr/cs/ct/cu/cv/cw/cx/cA)
  PT.RIV_IDS = ["pollinator", "lumberyard", "compost", "grove", "nursery"];
  const RIV_COST = { pollinator: 1e7, lumberyard: 5e5, compost: 6e7, nursery: 2.5e8 };
  const GROVE_COST = [1e8, 1.6e8, 2.4e8, 3.6e8];
  const BASE_SLOTS = 24, RIV_TIER = 3, RIV_EVO = 6, COMPOST_KILLS = 20, NURSERY = 0.75, LUMBER_REFUND = 0.5, POLLINATOR = 1.25;
  PT.RIV_INFO = {
    pollinator: { name: "Pollinator Garden", text: "Cornfield and Sunflower Field work 25% better (egg respawn x2.5, seed production x2.5).", req: "Requires Cornfield and Sunflower Field" },
    lumberyard: { name: "Lumberyard", text: "Felled trees give wood. Your overkill pecks return 50% as twigs. Opens the sawmill.", req: "" },
    compost: { name: "Composter", text: "Every 20 felled trees, a quad planting bed is composted: its next four harvests give a full extra tree of twigs.", req: "Requires a quad planting bed" },
    grove: { name: "Riverside Grove", text: "Adds a quad planting bed by the river (up to 4).", req: "Requires 24 quad planting beds" },
    nursery: { name: "Nursery", text: "Hybrid incubation takes 25% less time.", req: "Requires the Breeding Lake" },
  };
  const REQ_TEXT = { tier: "Requires Nest IV and Evolution 6", fields: PT.RIV_INFO.pollinator.req, boxes: "", breeding: PT.RIV_INFO.nursery.req };

  const isQuad = (b) => Array.isArray(b.extraTrees) && b.extraTrees.length >= 2;
  const clampInt = (v, max) => { const n = Number(v); return Number.isFinite(n) ? Math.min(max, Math.max(0, Math.floor(n))) : 0; };

  // ------------------------------------------------------------------ state (Birb la defaults + Gk / vs / es normalizers, version 4 / balance 6)
  PT.rivState = function (s) {
    const n = s.nest || (s.nest = {}), r = n.riverside || (n.riverside = {});
    r.upgrades ||= {};
    for (const id of PT.RIV_IDS) r.upgrades[id] = clampInt(r.upgrades[id], id === "grove" ? GROVE_COST.length : 1);
    r.compostProgress = clampInt(r.compostProgress, COMPOST_KILLS);
    r.compostSlot = r.compostSlot == null ? null : clampInt(r.compostSlot, 27);
    r.compostMask = r.compostSlot === null ? 0 : clampInt(r.compostMask, 15);
    r.nextCompostSlot = clampInt(r.nextCompostSlot, 27);
    return r;
  };
  PT.carpState = function (s) {
    const n = s.nest || (s.nest = {}), c = n.carpentry || (n.carpentry = {});
    c.workbenchLevel = Math.max(1, Math.min(3, Math.floor(Number(c.workbenchLevel) || 1)));
    c.woodRemainderHp = Number.isFinite(Number(c.woodRemainderHp)) ? Math.max(0, Number(c.woodRemainderHp)) % WOOD_HP : 0;
    const p = c.production || (c.production = {});
    p.workshopUnlocked = p.workshopUnlocked === true;
    p.toolLevel = clampInt(p.toolLevel, TOOLS.length); p.expansionLevel = clampInt(p.expansionLevel, Number.MAX_SAFE_INTEGER);
    p.upgrades ||= {}; for (const k of UPG) p.upgrades[k] = clampInt(p.upgrades[k], UPG_MAX);
    p.yieldRemainder = Math.max(0, Math.min(0.999999, Number(p.yieldRemainder) || 0));
    p.autoEnabled = p.autoEnabled !== false;
    p.xp = Math.max(0, Math.min(XP_MAX, Number(p.xp) || 0));
    p.stock ||= {}; p.stock.plank = Math.max(0, Math.floor(Number(p.stock.plank) || 0));
    p.progress ||= {}; p.progress.plank = Math.max(0, Math.min(0.999999, Number(p.progress.plank) || 0));
    return c;
  };
  const tierOk = (s) => { const n = PT.nestState(s); return n.tier >= RIV_TIER && (s.evolutionCount || 0) >= RIV_EVO; };

  // ------------------------------------------------------------------ riverside shop (Birb Vk snapshot, purchaseRiversideUpgrade)
  PT.rivSnapshot = function (s) {
    const r = PT.rivState(s), n = PT.nestState(s), c = n.cultivation, sp = c.specialUpgrades, ok = tierOk(s);
    return {
      visible: ok || PT.RIV_IDS.some((id) => r.upgrades[id] > 0),
      items: PT.RIV_IDS.map((id) => {
        const L = r.upgrades[id], max = id === "grove" ? GROVE_COST.length : 1, cost = id === "grove" ? GROVE_COST[Math.min(L, max - 1)] : RIV_COST[id];
        const req = !ok ? "tier"
          : id === "pollinator" && !(sp.cornfield && sp.sunflowerField) ? "fields"
          : (id === "grove" && c.treeBoxes.filter((b) => b.slotIndex < BASE_SLOTS && isQuad(b)).length < BASE_SLOTS) || (id === "compost" && !c.treeBoxes.some(isQuad)) ? "boxes"
          : id === "nursery" && !n.fishBreeding.unlocked ? "breeding" : null;
        return { id, level: L, max, cost, requirement: req, canBuy: L < max && !req && PT.has(s, "twigs", cost) };
      }),
    };
  };
  PT.rivReqText = (it) => (it.requirement === "boxes" ? PT.RIV_INFO[it.id].req : REQ_TEXT[it.requirement] || "");
  PT.rivBuy = function (s, id) {
    const it = PT.rivSnapshot(s).items.find((x) => x.id === id);
    if (!it) return "Unknown";
    if (it.level >= it.max) return "Maxed";
    if (it.requirement) return PT.rivReqText(it);
    if (!it.canBuy) return "Not enough twigs";
    PT.sub(s, "twigs", it.cost); PT.rivState(s).upgrades[id]++;
    const inc = PT.nestState(s).fishBreeding.incubation, now = Date.now();
    if (id === "nursery" && inc) { inc.hatchAt = now + Math.max(0, inc.hatchAt - now) * NURSERY; inc.baseDurationMs *= NURSERY; inc.startedAt = inc.hatchAt - inc.baseDurationMs; }
    PT.rivSyncGrove(s);
    return "";
  };
  // Birb Xk: drop a stale compost slot; once all 24 base beds are quad, place one quad bed per Grove level in slots 24-27
  PT.rivSyncGrove = function (s) {
    const r = PT.rivState(s), c = s.nest.cultivation; if (!c) return [];
    if (!c.treeBoxes.some((b) => b.slotIndex === r.compostSlot && isQuad(b))) { r.compostSlot = null; r.compostMask = 0; }
    if (c.treeBoxes.filter((b) => b.slotIndex < BASE_SLOTS && isQuad(b)).length < BASE_SLOTS) return [];
    const added = [];
    for (let i = 0; i < r.upgrades.grove; i++) { const slot = BASE_SLOTS + i; if (!c.treeBoxes.some((b) => b.slotIndex === slot)) { c.treeBoxes.push({ slotIndex: slot, specialized: true, extraTrees: [{}, {}] }); added.push(slot); } }
    c.treeBoxCount = c.treeBoxes.length;
    return added;
  };

  // ------------------------------------------------------------------ riverside effects
  const sp = (s) => PT.nestState(s).cultivation.specialUpgrades;
  const has = (s, id) => (s.nest?.riverside?.upgrades?.[id] || 0) > 0;
  PT.rivHas = has;
  PT.nestRespawnMult = (s) => (sp(s).cornfield ? 2 * (has(s, "pollinator") ? POLLINATOR : 1) : 1); // Birb getPopcornRespawnMultiplier
  PT.nestSeedProdMult = (s) => (sp(s).sunflowerField ? 2 : 1) * PT.nestWellMult(s) * (sp(s).sunflowerField && has(s, "pollinator") ? POLLINATOR : 1);
  // Lumberyard: when a player hit fells a tree, half of the wasted damage of that hit batch comes back as twig hits
  PT.rivLumberRefund = function (s, hp, maxHp, dmg, hits) {
    if (!has(s, "lumberyard") || dmg < hp || hp <= 0 || hits <= 0) return 0;
    const per = dmg / hits, waste = Math.ceil(hp / per) * per - hp;
    return Math.max(0, Math.min(maxHp, waste)) * LUMBER_REFUND;
  };
  // Composter (Birb jk): every felled tree counts; after 20, the next quad bed gets 4 marked trees; a marked tree pays its max HP again
  PT.rivCompost = function (s, slot, treeIdx, maxHp) {
    const r = PT.rivState(s); if (!r.upgrades.compost) return 0;
    let bonus = 0; const bit = 1 << (treeIdx ?? 0);
    if (slot === r.compostSlot && r.compostMask & bit) { r.compostMask &= ~bit; bonus = maxHp; if (!r.compostMask) r.compostSlot = null; }
    r.compostProgress = Math.min(COMPOST_KILLS, r.compostProgress + 1);
    if (r.compostProgress < COMPOST_KILLS || r.compostMask) return bonus;
    const quads = s.nest.cultivation.treeBoxes.filter(isQuad);
    const pick = quads.find((b) => b.slotIndex >= r.nextCompostSlot && b.slotIndex !== slot) ?? quads.find((b) => b.slotIndex !== slot) ?? quads[0];
    if (pick) { r.compostSlot = pick.slotIndex; r.compostMask = 15; r.nextCompostSlot = pick.slotIndex + 1; r.compostProgress = 0; }
    return bonus;
  };
  // Wood (Birb mf): each felled tree once, (harvest HP x Timber recovery) / 24 with the remainder carried
  PT.rivWood = function (s, t) {
    if (!has(s, "lumberyard") || t.carpentryHarvested) return 0;
    t.carpentryHarvested = true;
    const c = PT.carpState(s), p = c.production, hp = Math.max(0, t.harvestBaseHp ?? t.maxHp);
    const r = c.woodRemainderHp + hp * woodMult(p.upgrades.timber, p.expansionLevel), w = Math.floor(r / WOOD_HP);
    c.woodRemainderHp = r - w * WOOD_HP;
    if (w > 0) PT.add(s, "wood", w);
    return w;
  };
  // called by nest.js when a tree falls (any source)
  PT.rivOnTreeFelled = function (G, tgt) {
    const s = G.s, t = tgt.t, per = PT.nestRewardPerHit(s);
    const hits = PT.rivCompost(s, tgt.box ? tgt.slot : undefined, tgt.box ? tgt.idx : undefined, t.maxHp);
    if (hits > 0) { const tw = r12(hits * per); PT.nestAddTwigs(s, tw); G.gain("twigs", tw); G.onFloat && G.onFloat(tgt.x, tgt.y - 48, "+" + PT.fmt(tw) + " compost", "#9ccf6a"); }
    const w = PT.rivWood(s, t);
    if (w > 0) { G.gain && G.gain("wood", w); G.onFloat && G.onFloat(tgt.x, tgt.y - 62, "+" + PT.fmt(w) + " wood", "#c58a4a"); }
  };

  // ------------------------------------------------------------------ sawmill tables (Birb maps Qe/Ie/Oe/Ne/Ee/Te/Fe/ds/fs, cs=5, ws=1, Ms=24)
  const UPG = ["forestry", "timber", "saw"], UPG_MAX = 999, WOOD_GATE = 5, AUTO_LEVEL = 5, AUTO_SEC = 1, WOOD_HP = 24;
  const WORKSHOP_COST = { twigs: 0, wood: 600, plank: 0 };
  const UPG_COST = {
    forestry: { softcap: 40, twigs: 0, twigGrowth: 1, wood: 100, woodGrowth: 1.3 },
    timber: { softcap: 25, twigs: 0, twigGrowth: 1, wood: 25, woodGrowth: 1.28 },
    saw: { softcap: 30, twigs: 1e6, twigGrowth: 1.16, wood: 40, woodGrowth: 1.14 },
  };
  const BENCH = [{ level: 20, costs: { twigs: 8e6, wood: 250, plank: 1500 } }, { level: 40, costs: { twigs: 6e7, wood: 1e3, plank: 12e3 } }];
  const TOOLS = [[10, 1, 0, 0, 100], [15, 1, 5e5, 50, 400], [20, 2, 2e6, 100, 1e3], [25, 2, 5e6, 150, 1500], [30, 2, 12.5e6, 200, 3e3], [34, 2, 8e6, 200, 3e3], [38, 2, 12e6, 250, 4e3],
    [42, 3, 2e7, 350, 5e3], [46, 3, 3e7, 500, 8e3], [50, 3, 5e7, 700, 1e4], [54, 3, 1.8e8, 600, 12e3], [58, 3, 2.4e8, 800, 16e3], [62, 3, 3e8, 1e3, 22e3], [66, 3, 4.5e8, 1500, 3e4], [70, 3, 6.3e8, 2100, 4e4]]
    .map(([level, workbench, twigs, wood, plank]) => ({ level, workbench, costs: { twigs, wood, plank } }));
  const XP_TABLE = [0];
  for (let L = 1; L < 99; L++) { const a = L - 1; XP_TABLE.push(XP_TABLE[L - 1] + 10 * Math.round((150 + 12 * a + 6 * a ** 2.2) / 10)); }
  const XP_MAX = XP_TABLE[98];
  PT.carpLevel = function (xp) { // Birb ys
    let L = 1; while (L < 99 && xp >= XP_TABLE[L]) L++;
    const cur = xp - XP_TABLE[L - 1], next = L === 99 ? 0 : XP_TABLE[L] - XP_TABLE[L - 1];
    return { level: L, current: cur, next, fraction: next > 0 ? Math.min(1, cur / next) : 1 };
  };
  const toolStage = (t) => Math.min(TOOLS.length, Math.max(0, Math.floor(t))) / 5; // Birb Ge
  const lvlInt = (v) => { const n = Number(v); return Number.isFinite(n) ? Math.min(Number.MAX_SAFE_INTEGER, Math.max(0, Math.floor(n))) : 0; };
  const expMult = (x = 0) => (1 + lvlInt(x) / 4) ** 2; // Birb We: Sawmill efficiency
  const seriesCost = (base, g, softcap, from, count) => { // Birb qe: exponential to the softcap, then quadratic
    if (!base || count <= 0) return 0;
    let sum = 0; while (from < softcap && count > 0) { sum += Math.ceil(base * g ** from++); count--; }
    if (count === 0) return sum;
    const r = Math.round(2 / (g - 1)), o = r + from - softcap, a = count;
    return sum + Math.ceil((base * g ** softcap) / r ** 2) * (a * o ** 2 + o * a * (a - 1) + (a * (a - 1) * (2 * a - 1)) / 6);
  };
  const upgCost = (id, L, n = 1, x = 0) => { const a = UPG_COST[id], m = expMult(x), f = lvlInt(L); return { twigs: seriesCost(a.twigs * m, a.twigGrowth, a.softcap, f, n), wood: seriesCost(a.wood * m, a.woodGrowth, a.softcap, f, n), plank: 0 }; };
  const expCost = (L) => { const e = expMult(L) * (1 + lvlInt(L) / 10); return { twigs: Math.ceil(1e9 * e), wood: Math.ceil(5e3 * e), plank: Math.ceil(24e3 * e) }; };
  const twigMult = (f, tools, x = 0) => { const t = lvlInt(f); return 1.08 ** Math.min(40, t) * (1 + 0.08 * Math.max(0, t - 40)) * 2.5 ** toolStage(tools) * expMult(x); }; // Birb Ze
  const woodMult = (tb, x = 0) => { const t = lvlInt(tb); return 1.15 ** Math.min(25, t) * (1 + 0.15 * Math.max(0, t - 25)) * expMult(x); }; // Birb Ke
  const plankYield = (bench, saw, x = 0) => Math.min(3, Math.max(1, bench)) * (1 + 0.1 * lvlInt(saw)) * expMult(x); // Birb _e
  const xpPerPlank = (bench, tools = 0) => 10 * ((bench >= 3 ? 1.5 : bench >= 2 ? 1.25 : 1) + 0.25 * toolStage(tools)); // Birb us
  PT.carpFns = { upgCost, expCost, twigMult, woodMult, plankYield, xpPerPlank, expMult, XP_TABLE, XP_MAX };

  PT.carpTwigMult = (s) => { const p = s.nest?.carpentry?.production; return p ? twigMult(p.upgrades?.forestry || 0, p.toolLevel || 0, p.expansionLevel || 0) : 1; };
  const baseResMult = PT.nestResourceMult;
  PT.nestResourceMult = (s) => baseResMult(s) * PT.carpTwigMult(s); // Birb getResourceMultiplier x carpentry forestry

  // ------------------------------------------------------------------ sawmill shop (Birb yk snapshot, purchaseCarpentryUpgrade)
  PT.CARP_IDS = ["timber", "forestry", "workshop", "saw", "bench", "tools", "mastery", "expansion"];
  PT.CARP_INFO = {
    forestry: { name: "Forest management", text: "Increases twig gains.", unit: "Twig yield" },
    timber: { name: "Timber recovery", text: "Increases wood gained per tree.", unit: "Wood per tree" },
    saw: { name: "Precision cutting", text: "Increases planks produced per wood.", unit: "Planks per wood" },
    bench: { name: "Sawmill workbench", text: "Larger batches from the same wood, plus 25% base XP per stage.", unit: "Planks per wood" },
    tools: { name: "Forest carpentry", text: "More twigs and +5% base XP per level.", unit: "Twig yield" },
    mastery: { name: "Advanced sawmill", text: "Unlocks Sawmill efficiency, including its first level.", unit: "Twigs · Wood · Planks" },
    expansion: { name: "Sawmill efficiency", text: "Permanently increases twig, wood and plank gains.", unit: "Twigs · Wood · Planks" },
    workshop: { name: "Sawmill", text: "Unlocks plank production in the workshop. Manual cutting first; AUTO at level 5.", unit: "" },
  };
  PT.carpSnapshot = function (s) {
    const n = PT.nestState(s), c = PT.carpState(s), p = c.production, bench = c.workbenchLevel;
    const visible = n.unlocked && n.tier >= 3 && (s.evolutionCount || 0) >= 6 && has(s, "lumberyard");
    const shop = has(s, "lumberyard") && p.workshopUnlocked, mastered = p.expansionLevel > 0, skill = PT.carpLevel(p.xp).level;
    const nestDone = n.tier >= 3 && n.forest.tierTwigsProgress >= PT.NEST_TIER_COST[3];
    const tw = PT.num(PT.res(s, "twigs")), wd = PT.num(PT.res(s, "wood"));
    const afford = (k) => p.stock.plank >= k.plank && tw >= k.twigs && wd >= k.wood;
    const items = PT.CARP_IDS.map((id) => {
      const isUpg = UPG.includes(id), isExp = id === "mastery" || id === "expansion";
      const L = id === "workshop" ? Number(shop) : id === "mastery" ? Number(mastered) : id === "bench" ? bench : id === "tools" ? p.toolLevel : id === "expansion" ? p.expansionLevel : p.upgrades[id];
      const max = id === "workshop" || id === "mastery" ? 1 : id === "bench" ? BENCH.length + 1 : id === "tools" ? TOOLS.length : UPG_MAX;
      const tier = id === "bench" ? BENCH[L - 1] : id === "tools" ? TOOLS[L] : undefined;
      const costN = (k) => (isUpg ? upgCost(id, L, k, p.expansionLevel) : { twigs: 0, wood: 0, plank: 0 });
      const costs = isUpg ? costN(1) : id === "workshop" ? { ...WORKSHOP_COST } : isExp ? expCost(id === "mastery" ? 0 : L) : { ...(tier?.costs ?? { twigs: 0, wood: 0, plank: 0 }) };
      const reqLevel = isUpg ? 1 : isExp ? 50 : tier?.level ?? 0;
      const reqBench = isExp ? 3 : id === "saw" && L === 0 ? 2 : id === "tools" ? TOOLS[L]?.workbench ?? 3 : 1;
      const woodDone = p.upgrades.timber >= WOOD_GATE && p.upgrades.forestry >= WOOD_GATE;
      const open = id === "timber" || id === "forestry" || (id === "workshop" ? woodDone || shop : shop && (id !== "expansion" || mastered));
      const met = open && skill >= reqLevel && bench >= reqBench && (!isExp || (nestDone && (p.toolLevel >= TOOLS.length || mastered)));
      const vis = visible && open && (met || L >= max || (shop && (id === "bench" || id === "tools" || (id === "expansion" && mastered))));
      const bonus = (t) => (id === "workshop" ? t : isExp ? expMult(t) : id === "forestry" ? twigMult(t, 0) : id === "tools" ? twigMult(0, t) : id === "timber" ? woodMult(t) : id === "bench" ? plankYield(t, p.upgrades.saw, p.expansionLevel) : plankYield(bench, t, p.expansionLevel));
      let count = 0; const maxCosts = { twigs: 0, wood: 0, plank: 0 };
      if (vis && met && L < max) {
        if (isUpg) {
          const room = max - L; let lo = 0, hi = Math.min(1, room);
          while (hi < room && afford(costN(hi))) { lo = hi; hi = Math.min(room, 2 * hi); }
          while (lo < hi) { const mid = lo + Math.ceil((hi - lo) / 2); if (afford(costN(mid))) lo = mid; else hi = mid - 1; }
          count = lo; Object.assign(maxCosts, costN(lo));
        } else if (id === "tools" || id === "expansion") {
          for (let i = L; i < max; i++) {
            const t = id === "tools" ? TOOLS[i] : undefined;
            if (t && (skill < t.level || bench < t.workbench)) break;
            const k = t?.costs ?? expCost(i), sum = { twigs: maxCosts.twigs + k.twigs, wood: maxCosts.wood + k.wood, plank: maxCosts.plank + k.plank };
            if (!afford(sum)) break;
            Object.assign(maxCosts, sum); count++;
          }
        } else if (afford(costs)) { count = 1; Object.assign(maxCosts, costs); }
      }
      return { id, visible: vis, level: L, max, requiredLevel: reqLevel, requiredWorkbench: reqBench, requirementsMet: met, nestComplete: nestDone,
        currentBonus: bonus(L), nextBonus: bonus(L >= max ? L : L + 1), maxBonus: bonus(L + count), costs, canBuy: count > 0, maxBuyCount: count, maxCosts };
    });
    return { visible, workshopUnlocked: shop, workbenchLevel: bench, skillLevel: skill, stock: { twigs: tw, wood: wd, plank: p.stock.plank }, items };
  };
  PT.carpBuy = function (s, id, max = false) {
    const it = PT.carpSnapshot(s).items.find((x) => x.id === id);
    if (!it || !it.visible) return "Locked";
    if (it.level >= it.max) return "Maxed";
    if (!it.requirementsMet) return id === "mastery" || id === "expansion" ? (it.nestComplete ? "Needs Sawmill Lv. 50, Workbench 3 and Forest carpentry maxed" : "Complete Nest IV") : "Needs Sawmill Lv. " + it.requiredLevel + " and Workbench " + it.requiredWorkbench;
    if (!it.canBuy) return "Not enough materials";
    const c = PT.carpState(s), p = c.production, n = max ? it.maxBuyCount : 1, k = max ? it.maxCosts : it.costs;
    PT.sub(s, "twigs", k.twigs); PT.sub(s, "wood", k.wood); p.stock.plank = Math.max(0, p.stock.plank - k.plank);
    if (id === "workshop") p.workshopUnlocked = true;
    else if (id === "bench") c.workbenchLevel = c.workbenchLevel === 1 ? 2 : 3;
    else if (id === "tools") p.toolLevel += n;
    else if (id === "mastery") p.expansionLevel = 1;
    else if (id === "expansion") p.expansionLevel += n;
    else p.upgrades[id] += n;
    return "";
  };

  // ------------------------------------------------------------------ plank cutting (Birb editors $s / el / al / rl / nl)
  PT.carpCanCut = (s) => { const c = PT.carpState(s), p = c.production; return p.workshopUnlocked && has(s, "lumberyard") && PT.carpLevel(p.xp).level >= 1 && PT.has(s, "wood", 1); };
  PT.carpAutoOn = (s) => { const p = PT.carpState(s).production; return PT.carpLevel(p.xp).level >= AUTO_LEVEL && p.autoEnabled !== false; };
  PT.carpCut = function (s) { // one craft: 1 wood -> planks (workbench x saw x efficiency, fractions carried), XP per plank
    if (!PT.carpCanCut(s)) return 0;
    const c = PT.carpState(s), p = c.production;
    PT.sub(s, "wood", 1);
    const y = plankYield(c.workbenchLevel, p.upgrades.saw, p.expansionLevel) + p.yieldRemainder, made = Math.floor(y + 1e-9);
    p.yieldRemainder = Math.max(0, y - made);
    p.stock.plank += made;
    p.xp = Math.min(XP_MAX, p.xp + made * xpPerPlank(c.workbenchLevel, p.toolLevel));
    return made;
  };
  // manual sawing: each stroke switches side; every second switch cuts one wood (the playtest SAW button is one stroke)
  PT.carpStroke = function (G) {
    const w = G.saw || (G.saw = { clock: 0, side: 0, turns: 0, manualAt: -Infinity });
    const side = w.side === 1 ? -1 : 1;
    if (w.side !== 0) { w.turns++; w.manualAt = w.clock; }
    w.side = side;
    if (w.turns < 2) return 0;
    w.turns = 0; return PT.carpCut(G.s);
  };
  // AUTO: while the sawmill is open, one craft per second once 1 s has passed since the last manual stroke
  PT.carpUpdate = function (G, dt, working) {
    const w = G.saw || (G.saw = { clock: 0, side: 0, turns: 0, manualAt: -Infinity });
    const r = Number.isFinite(dt) ? Math.max(0, Math.min(dt, 0.25)) : 0;
    w.clock += r;
    if (!working || !PT.carpAutoOn(G.s) || w.clock - w.manualAt < 1 || !PT.carpCanCut(G.s)) return;
    const p = PT.carpState(G.s).production, step = Math.min(r, Math.max(0, w.clock - w.manualAt - 1));
    if (step === 0) return;
    p.progress.plank += step / AUTO_SEC;
    if (p.progress.plank + 1e-9 >= 1) { p.progress.plank = Math.max(0, p.progress.plank - 1); const m = PT.carpCut(G.s); if (m > 0 && G.gain) G.gain("plank", m); }
  };
  PT.carpToggleAuto = (s) => { const p = PT.carpState(s).production; if (PT.carpLevel(p.xp).level < AUTO_LEVEL) return "AUTO at Sawmill Lv. 5"; p.autoEnabled = !PT.carpAutoOn(s); return ""; };

  // ------------------------------------------------------------------ hooks into the nest (tree boxes, breeding, evolution)
  const wrap = (name, after) => { const f = PT[name]; PT[name] = function (...a) { const r = f.apply(this, a); after(a, r); return r; }; };
  wrap("nestBuyTreeBox", ([s], r) => { if (!r) PT.rivSyncGrove(s); });
  wrap("nestBuyExpansion", ([s], r) => { if (!r) PT.rivSyncGrove(s); });
  wrap("breedStart", ([s], r) => { // Birb: incubation time x0.75 with the Nursery
    const inc = PT.nestState(s).fishBreeding.incubation;
    if (r || !inc || !has(s, "nursery")) return;
    inc.baseDurationMs *= NURSERY; inc.hatchAt = inc.startedAt + inc.baseDurationMs;
  });
  wrap("nestOnEvolve", ([G]) => { G.s.resources.wood = PT.D(0); PT.rivState(G.s); PT.carpState(G.s); PT.rivSyncGrove(G.s); }); // nest resources (twigs, wood) reset
  wrap("nestState", ([s]) => { if (!s.nest.__riv) { Object.defineProperty(s.nest, "__riv", { value: true, enumerable: false }); PT.rivState(s); PT.carpState(s); PT.rivSyncGrove(s); } });
})();
