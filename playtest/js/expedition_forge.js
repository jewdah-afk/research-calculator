// Peckwood playtest - Phase 6b: the parrot forge. Gear upgrades (beak / armor / aura), evolving and
// legendary refinement, aura convert (50 -> 1 up) and dismantle (1 -> 25 down), artifact infusion,
// 3-artifact fusion, and the skill point reset. Everything needs sacrifice milestone I.
// Numbers copied from Birb (SU / MU / $U, UU / FU / RU, QU, WU, the skills tab reset).
(function () {
  const PT = window.PT, X = PT.EXP;
  const RAR = ["common", "uncommon", "rare", "epic", "legendary"], AURAS = ["spirit_trash", "uncommon_spirit_trash", "rare_spirit_trash", "epic_spirit_trash", "legendary_spirit_trash", "mythic_spirit_trash"];
  const K = { LEVEL_COST: [10, 100, 500, 1e3], EVOLVE_COST: 1, LEG_GOLD: [3, 8, 24, 64, 160], REFINE_GOLD: [180, 540, 1620], CONVERT: 50, DISMANTLE: 25,
    INFUSE_MAX: { common: 3, uncommon: 5, rare: 7, epic: 10, legendary: 15, mythic: 15 },
    INFUSE_COST: { common: [10, 25, 50], uncommon: [10, 25, 50, 75, 100], rare: [25, 50, 100, 150, 250, 350, 500], epic: [50, 100, 150, 250, 400, 600, 850, 1200, 1600, 2200],
      legendary: [100, 150, 250, 400, 600, 850, 1200, 1600, 2200, 3e3, 4e3, 5500, 7500, 1e4, 15e3], mythic: [4, 6, 10, 16, 24, 34, 48, 64, 88, 120, 160, 220, 300, 400, 600] },
    FUSE_COST: { common: 50, uncommon: 100, rare: 200, epic: 500 } };
  X.FORGE_K = K;
  const auraId = (r) => X.AURA_ID[r];
  const have = (s, id) => X.itemCount(s, X.itemById(id).name);
  const take = (s, id, n) => X.takeItem(s, X.itemById(id).name, n);
  const unlocked = (s) => (X.sacLevel ? X.sacLevel(s) >= 1 : false);
  X.forgeUnlocked = unlocked;
  const gold = (s) => Math.floor(PT.mineState(s).goldOre || 0);
  const takeGold = (s, n) => { const m = PT.mineState(s); if (gold(s) < n) return false; m.goldOre = gold(s) - n; return true; };

  // ------------------------------------------------------------------ gear (Birb SU / MU / Sr / Rr / fr / gr)
  const mineGate = (L) => (L <= 2 ? 1 : L <= 4 ? 3 : 5);
  const refineArea = (t) => { t = Math.max(1, t); return t <= 3 ? 4 + t : 7 + Math.floor((Math.max(0, t - 3) - 1) / 10); };
  const refineMythic = (t) => { const x = Math.max(0, t - 3) - 30 + 1; return x <= 0 ? 0 : Math.ceil(10 * 1.08 ** (x - 1)); };
  const refineGold = (t) => { t = Math.max(1, t); return t <= 3 ? K.REFINE_GOLD[t - 1] : Math.ceil(25e3 * 1.08 ** (Math.max(0, t - 3) - 1)); };
  X.refineLevel = (s, slot) => Math.max(0, Math.floor(s.mine?.expeditionCycle?.refinements?.[slot] || 0));
  X.gearPlan = function (s, slot) {
    const g = PT.parrotState(s).equipmentUpgrades[slot], area = PT.mineArea(s), leg = g.rarity === "legendary";
    if (g.level < 5) { const t = leg ? mineGate(g.level + 1) : 0;
      return { action: "upgrade", cost: leg ? 0 : K.LEVEL_COST[g.level - 1] ?? K.LEVEL_COST[3], currency: leg ? null : auraId(g.rarity), gold: leg ? K.LEG_GOLD[Math.max(0, Math.min(4, g.level))] : 0, area: area < t ? t : 0 }; }
    const i = RAR.indexOf(g.rarity);
    if (g.rarity === "epic") return { action: "evolve", next: "legendary", cost: 0, currency: null, gold: K.LEG_GOLD[0], area: area >= mineGate(1) ? 0 : mineGate(1) };
    if (i < 3) return { action: "evolve", next: RAR[i + 1], cost: K.EVOLVE_COST, currency: auraId(RAR[i + 1]), gold: 0, area: 0 };
    const n = X.refineLevel(s, slot), t = refineArea(n + 1), c = refineMythic(n + 1);
    return { action: "refine", level: n + 1, cost: c, currency: c > 0 ? "mythic_spirit_trash" : null, gold: refineGold(n + 1), area: area < t ? t : 0 };
  };
  X.gearUpgrade = function (s, slot) {
    if (!unlocked(s)) return "Needs sacrifice milestone I";
    const p = X.gearPlan(s, slot), g = PT.parrotState(s).equipmentUpgrades[slot];
    if (p.area) return `Needs mine area ${p.area}`;
    if (p.currency && have(s, p.currency) < p.cost) return "Not enough aura";
    if (gold(s) < p.gold) return "Not enough Gold Ore";
    if (p.currency) take(s, p.currency, p.cost); if (p.gold) takeGold(s, p.gold);
    if (p.action === "evolve") Object.assign(g, { rarity: p.next, level: 1 });
    else if (p.action === "refine") { const ec = (PT.mineState(s).expeditionCycle ||= { version: 1, rewardedGiants: 0 }); ec.refinements ||= {}; ec.refinements[slot] = X.refineLevel(s, slot) + 1; }
    else g.level = Math.max(1, Math.min(5, g.level + 1));
    X.refreshRunParrot(s); return "";
  };

  // ------------------------------------------------------------------ aura convert / dismantle (Birb UU / FU / RU)
  const up = (id) => { const i = AURAS.indexOf(id); return i < 0 || i >= AURAS.length - 1 ? null : AURAS[i + 1]; };
  const down = (id) => { const i = AURAS.indexOf(id); return i <= 0 ? null : AURAS[i - 1]; };
  const stackOf = (s, id) => PT.parrotState(s).artifactInventory.some((e) => e.name === X.itemById(id).name);
  const batch = (s, from, to, unit) => { // min / max batches; a full material bag only allows a batch that empties the source stack
    const r = Math.max(0, Math.floor(have(s, from) / unit)); if (r <= 0) return { min: 0, max: 0 };
    if (stackOf(s, to) || !X.invCapacity(s, "material").isFull) return { min: 1, max: r };
    const o = Math.max(1, Math.ceil(have(s, from) / unit)); return o > r ? { min: 0, max: 0 } : { min: o, max: r };
  };
  X.convertBounds = (s, id) => (id === "legendary_spirit_trash" && X.rebirbs(s) < 3 ? { min: 0, max: 0 } : up(id) ? batch(s, id, up(id), K.CONVERT) : { min: 0, max: 0 });
  X.dismantleBounds = (s, id) => (down(id) ? batch(s, id, down(id), 1) : { min: 0, max: 0 });
  X.convertAura = function (s, id, n = 1) {
    if (id === "legendary_spirit_trash" && X.rebirbs(s) < 3) return "Needs parrot rebirb III"; if (!unlocked(s)) return "Needs sacrifice milestone I";
    const to = up(id); if (!to) return "Top tier"; const b = X.convertBounds(s, id); if (b.max <= 0) return `Need ${K.CONVERT}`; if (n < b.min) return `Select ${b.min}+`;
    const c = Math.max(1, Math.min(n, b.max)); take(s, id, c * K.CONVERT); X.addItemById(s, to, c); return "";
  };
  X.dismantleAura = function (s, id, n = 1) {
    if (!unlocked(s)) return "Needs sacrifice milestone I"; const to = down(id); if (!to) return "Lowest tier"; const b = X.dismantleBounds(s, id); if (b.max <= 0) return "Need 1"; if (n < b.min) return `Select ${b.min}+`;
    const c = Math.max(1, Math.min(n, b.max)); take(s, id, c); X.addItemById(s, to, c * K.DISMANTLE); return "";
  };

  // ------------------------------------------------------------------ infusion (Birb QU) and fusion (Birb WU / tryFuseArtifacts)
  X.infusionInfo = function (s, instanceId) {
    const it = PT.parrotState(s).artifactInventory.find((e) => e.instanceId === instanceId), d = it && X.itemByName(it.name);
    if (!d || !d.stats || !Object.keys(d.stats).length || d.stackable || d.type === "consumable") return null;
    const a = Math.max(0, Math.floor(+it.infusionLevel || 0)), max = K.INFUSE_MAX[d.rarity] ?? 0, tbl = K.INFUSE_COST[d.rarity] || K.INFUSE_COST.common, cost = a < tbl.length ? tbl[a] : tbl[tbl.length - 1], aura = auraId(d.rarity);
    return { canInfuse: a < max && have(s, aura) >= cost && unlocked(s), currentLevel: a, maxLevel: max, cost, auraId: aura, auraAvailable: have(s, aura) };
  };
  X.infuse = function (s, instanceId) {
    if (!unlocked(s)) return "Needs sacrifice milestone I"; const n = X.infusionInfo(s, instanceId); if (!n) return "Cannot infuse"; if (n.currentLevel >= n.maxLevel) return "Maxed"; if (!n.canInfuse) return "Not enough aura";
    take(s, n.auraId, n.cost); PT.parrotState(s).artifactInventory.find((e) => e.instanceId === instanceId).infusionLevel = n.currentLevel + 1; X.refreshRunParrot(s); return "";
  };
  X.fusionCheck = function (s, ids) {
    const o = { valid: false, rarity: null, targetRarity: null, auraCost: 0, auraId: null, reason: "" }, p = PT.parrotState(s);
    if (!ids || ids.length !== 3) return { ...o, reason: "Pick three artifacts" };
    const eq = new Set(p.equippedArtifacts.filter(Boolean)); if (p.relicSlot) eq.add(p.relicSlot);
    const rs = [];
    for (const id of ids) { const it = p.artifactInventory.find((e) => e.instanceId === id), d = it && X.itemByName(it.name); if (!d) return { ...o, reason: "Not found" }; if (eq.has(id)) return { ...o, reason: "Unequip it first" };
      if (it.locked) return { ...o, reason: "Locked" }; if (d.stackable || d.type === "consumable" || d.inventoryCategory === "material") return { ...o, reason: "Artifacts only" }; rs.push(d.rarity); }
    if (!rs.every((r) => r === rs[0])) return { ...o, reason: "Must be the same rarity" };
    const i = RAR.indexOf(rs[0]); if (i < 0 || i >= RAR.length - 1) return { ...o, reason: "Legendary cannot fuse" };
    const r = { ...o, rarity: rs[0], targetRarity: RAR[i + 1], auraCost: K.FUSE_COST[rs[0]] ?? 0, auraId: auraId(rs[0]) };
    r.valid = have(s, r.auraId) >= r.auraCost; if (!r.valid) r.reason = "Not enough aura"; return r;
  };
  X.fuse = function (s, ids) {
    if (!unlocked(s)) return { error: "Needs sacrifice milestone I" }; const n = X.fusionCheck(s, ids); if (!n.valid) return { error: n.reason };
    const pool = X.ITEMS.filter((a) => a.rarity === n.targetRarity && !a.stackable && a.type !== "consumable" && a.inventoryCategory !== "material"); if (!pool.length) return { error: "Cannot fuse" };
    take(s, n.auraId, n.auraCost); const p = PT.parrotState(s);
    for (const id of ids) { if (p.potionSlot === id) p.potionSlot = null; p.equippedArtifacts = p.equippedArtifacts.map((e) => (e === id ? null : e)); p.artifactInventory = p.artifactInventory.filter((e) => e.instanceId !== id); }
    const a = pool[Math.floor(Math.random() * pool.length)]; p.artifactInventory.push({ instanceId: `art_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`, name: a.name });
    if (!p.discoveredArtifacts.includes(a.name)) p.discoveredArtifacts.push(a.name); return { item: a };
  };

  // ------------------------------------------------------------------ skill reset: refund every invested point minus ceil(sqrt(1% of the total))
  X.resetSkills = function (s) {
    const p = PT.parrotState(s), sk = p.skills, t = Math.max(0, Math.floor(sk.hp || 0)) + Math.max(0, Math.floor(sk.lifeRegen || 0)) + Math.max(0, Math.floor(sk.damage || 0));
    if (t <= 0) return 0; const c = PT.parrotResetCost(s), n = Math.max(0, t - c);
    p.skillPoints = (p.skillPoints || 0) + n; sk.hp = 0; sk.lifeRegen = 0; sk.damage = 0; X.refreshRunParrot(s); return n;
  };
})();
