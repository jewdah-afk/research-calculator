// Peckwood playtest - Phase 6b: expedition loot. Spirit Aura drops on kills, equipment chests from
// bosses and elites, healing potions, the parrot inventory, equipping artifacts and their stat bonuses.
// Numbers and formulas copied from Birb (handleEnemyLootDrops, rM/tM/iM, RT.calculateParrotBonuses,
// Dr/PU inventory, rollEquipmentChestRarity, tryDropPotionFromEnemyKill, useExpeditionPotion).
(function () {
  const PT = window.PT, X = PT.EXP, DATA = window.EXPEDITION_DATA;
  const ITEMS = DATA.items, BY_ID = new Map(ITEMS.map((a) => [a.id, a])), BY_NAME = new Map(ITEMS.map((a) => [a.name, a]));
  X.ITEMS = ITEMS; X.itemById = (id) => BY_ID.get(id); X.itemByName = (n) => BY_NAME.get(n);
  const RAR = ["common", "uncommon", "rare", "epic", "legendary"], RAR6 = [...RAR, "mythic"];
  const AURA_ID = { common: "spirit_trash", uncommon: "uncommon_spirit_trash", rare: "rare_spirit_trash", epic: "epic_spirit_trash", legendary: "legendary_spirit_trash", mythic: "mythic_spirit_trash" };
  X.AURA_ID = AURA_ID; X.auraName = (r) => BY_ID.get(AURA_ID[r]).name;
  const K = { BASE_INV: 33, POTION_DROP: 0.02, POTION_CD: 3, TEMPERED_GLASS: 1.5, BASE_SLOTS: 3, STAT_INFUSE: 0.12, EFFECT_INFUSE: 0.04, REGEN_RELIEF: 0.2 };
  X.LOOT_K = K;
  const RELICS = ["Heart of the Veil", "Watcher's Oath"]; // mythic relics take their own slot (6c)
  const isRelic = (n) => RELICS.includes(n);
  const HEAL = { heal_20_pct: 0.2, heal_35_pct: 0.35, heal_60_pct: 0.5, instant_heal_25: 0.35, instant_heal_50: 0.5, instant_heal_full: 1 };

  // ------------------------------------------------------------------ helpers (Birb eM / tM / iM / Kw / Zw)
  const pickWeighted = (keys, w, fb) => { const e = keys.map((k) => [k, Math.max(0, +w[k] || 0)]), t = e.reduce((a, [, v]) => a + v, 0); if (t <= 0) return fb; let r = Math.random() * t; for (const [k, v] of e) if (v > 0 && (r -= v) <= 0) return k; return e[e.length - 1][0]; };
  const softRoot = (e, t) => { const n = Math.max(0, Number.isFinite(e) ? e : 0); return n <= t ? n : 2 * Math.sqrt(t) * Math.sqrt(n) - t; };
  const rewardMult = (e, t = 0) => { const n = Math.max(0, Number.isFinite(e) ? e : 0), i = Math.min(n, Math.max(0, Number.isFinite(t) ? t : 0)); return 1 + softRoot(n - i, 0.25) + i; };
  X.softRoot = softRoot; X.rewardMult = rewardMult;
  const AURA_W = { 1: [100, 0, 0, 0, 0], 2: [90, 10, 0, 0, 0], 3: [20, 80, 0, 0, 0], 4: [0, 90, 10, 0, 0], 5: [0, 25, 75, 0, 0], 6: [0, 0, 90, 10, 0], 7: [0, 0, 25, 75, 0], 8: [0, 0, 0, 95, 5] };
  X.auraWeights = (f) => { const a = AURA_W[Math.max(1, Math.floor(f || 1))] || [0, 0, 0, 85, 15]; return Object.fromEntries(RAR.map((r, i) => [r, a[i]])); };
  X.auraCap = (f) => { const t = Math.max(1, Math.floor(f || 1)); return t === 1 ? "common" : t <= 3 ? "uncommon" : t <= 5 ? "rare" : t <= 7 ? "epic" : "legendary"; };
  // Birb rM: roll a rarity from the floor weights, cap it at the floor's top rarity, maybe promote one step (night mode mythic in 6c)
  X.rollAuraRarity = function (floor, promo) {
    const w = { ...X.auraWeights(floor), mythic: 0 }, i = pickWeighted(RAR6, w, "common"), r = RAR6.indexOf(X.auraCap(floor)), s = Math.min(r, RAR6.indexOf(i));
    return RAR6[Math.min(r, s + (Math.random() < Math.max(0, Math.min(1, promo)) ? 1 : 0))];
  };
  const CHEST_W = { 1: [100, 0, 0, 0, 0], 2: [43.75, 56.25, 0, 0, 0], 3: [16, 46, 32, 6, 0], 4: [6, 30, 52, 10, 2], 5: [4, 26, 59.8, 10, 0.2] };
  X.chestWeights = (f) => { const a = f <= 1 ? CHEST_W[1] : CHEST_W[f] || [4, 26, 58, 10, 2]; return Object.fromEntries(RAR.map((r, i) => [r, a[i]])); };
  X.potionWeights = (f) => (f <= 1 ? { minor: 0.7, medium: 0.3, major: 0 } : f === 2 ? { minor: 0.55, medium: 0.3, major: 0.15 } : { minor: 0.4, medium: 0.35, major: 0.25 });

  // ------------------------------------------------------------------ inventory (Birb Dr / PU / cb)
  const inv = (s) => { const p = PT.parrotState(s); p.artifactInventory ||= []; p.equippedArtifacts ||= []; p.discoveredArtifacts ||= []; normEquipped(s, p); return p; };
  // Birb load normalization: equipped ids must exist, at most 2 copies of a name, one relic, no more than the slot count
  const normEquipped = (s, p) => {
    const n = X.slotCount(s), seen = new Map(), have = new Map(p.artifactInventory.map((e) => [e.instanceId, e]));
    p.equippedArtifacts = p.equippedArtifacts.slice(0, n).map((id) => { const it = id && have.get(id); if (!it || isRelic(it.name)) return null; const c = seen.get(it.name) || 0; if (c >= 2) return null; seen.set(it.name, c + 1); return id; });
    if (p.relicSlot && !have.has(p.relicSlot)) p.relicSlot = null; if (p.potionSlot && !have.has(p.potionSlot)) p.potionSlot = null;
  };
  const category = (it) => (it?.inventoryCategory === "material" ? "material" : "artifact");
  X.invCapacity = function (s, cat = "artifact") {
    const p = inv(s), max = Math.max(0, K.BASE_INV + Math.floor(X.artifactBonuses(s).inventorySpace || 0));
    const used = p.artifactInventory.reduce((a, e) => a + (e && typeof e.name === "string" && category(BY_NAME.get(e.name)) === cat ? 1 : 0), 0);
    return { used, max, isFull: used >= max };
  };
  let uid = 0;
  X.addItem = function (s, item, amount = 1, opts = {}) {
    const p = inv(s), d = BY_NAME.get(item.name) || item, n = Math.max(1, Math.floor(+amount || 1));
    if (d.id === "gold_ore") { const m = PT.mineState(s); m.goldOre = Math.floor(m.goldOre || 0) + n; return true; } // Birb Jy moves Gold Ore to the mine
    const stack = d.stackable === true || d.type === "consumable";
    const ignoreCap = item.id === "strange_key" || opts.ignoreCapacity, hit = stack ? p.artifactInventory.find((e) => e.name === item.name) : null;
    let id;
    if (hit) { hit.count = Math.max(1, hit.count || 1) + n; id = hit.instanceId; }
    else { if (!ignoreCap && X.invCapacity(s, category(d)).isFull) return false; const e = { instanceId: `art_${Date.now()}_${++uid}`, name: item.name, count: n }; p.artifactInventory.push(e); id = e.instanceId; }
    if (!p.potionSlot && d.type === "consumable") p.potionSlot = id;
    if (!p.discoveredArtifacts.includes(item.name)) p.discoveredArtifacts.push(item.name);
    X.bonusesDirty = true; return true;
  };
  X.addItemById = (s, id, n = 1, o) => (BY_ID.get(id) ? X.addItem(s, BY_ID.get(id), n, o) : false);
  X.auraCount = (s, r) => X.itemCount(s, X.auraName(r));

  // ------------------------------------------------------------------ equipping (Birb CC / EC / fC / lC)
  X.slotCount = (s) => K.BASE_SLOTS + Math.min(2, X.rebirbs(s));
  X.equippedNames = function (s) {
    const p = inv(s), find = (id) => p.artifactInventory.find((e) => e.instanceId === id);
    const n = p.equippedArtifacts.map((id) => { const nm = id ? find(id)?.name || null : null; return isRelic(nm) ? null : nm; });
    const r = find(p.relicSlot)?.name; n.push(isRelic(r) ? r : null); return n;
  };
  X.equippedInfusion = function (s) {
    const p = inv(s), o = {};
    [...p.equippedArtifacts, p.relicSlot ?? null].forEach((id, i) => { if (!id) return; const a = p.artifactInventory.find((e) => e.instanceId === id); if (a && (a.infusionLevel ?? 0) > 0) o[`slot:${i}`] = a.infusionLevel; });
    return o;
  };
  const copyLimit = (names) => { const m = new Map(); let relic = false; return names.map((e) => { const t = typeof e === "string" && e.trim() ? e.trim() : null; if (!t) return false; if (isRelic(t)) return !relic && (relic = true); const a = m.get(t) ?? 0; if (a >= 2) return false; m.set(t, a + 1); return true; }); };
  const limited = (names) => { const ok = copyLimit(names); return names.map((e, i) => (ok[i] ? e : null)); };
  X.equip = function (s, instanceId, slot) {
    const p = inv(s), it = p.artifactInventory.find((e) => e.instanceId === instanceId), d = it && BY_NAME.get(it.name);
    if (!d || d.inventoryCategory === "material" || d.type === "consumable") return false;
    if (isRelic(d.name)) { p.relicSlot = instanceId; X.bonusesDirty = true; return true; }
    const n = X.slotCount(s); p.equippedArtifacts.length = Math.max(p.equippedArtifacts.length, n);
    for (let i = 0; i < n; i++) if (p.equippedArtifacts[i] === instanceId) p.equippedArtifacts[i] = null;
    if (p.equippedArtifacts.filter((id) => id && p.artifactInventory.find((e) => e.instanceId === id)?.name === d.name).length >= 2) return false;
    let at = slot ?? p.equippedArtifacts.findIndex((e, i) => i < n && !e); if (at < 0 || at >= n) at = n - 1;
    p.equippedArtifacts[at] = instanceId; X.bonusesDirty = true; return true;
  };
  X.unequip = function (s, instanceId) { const p = inv(s); p.equippedArtifacts = p.equippedArtifacts.map((e) => (e === instanceId ? null : e)); if (p.relicSlot === instanceId) p.relicSlot = null; X.bonusesDirty = true; };
  X.discard = function (s, instanceId) { X.unequip(s, instanceId); const p = inv(s); p.artifactInventory = p.artifactInventory.filter((e) => e.instanceId !== instanceId); if (p.potionSlot === instanceId) p.potionSlot = null; };

  // ------------------------------------------------------------------ artifact effects (Birb RT)
  const statInfuse = (l) => 1 + K.STAT_INFUSE * Math.max(0, Math.floor(+l || 0));
  const effectInfuse = (l) => 1 + K.EFFECT_INFUSE * Math.max(0, Math.floor(+l || 0));
  const ALIAS = { splitter_haste_5th_3s: ["splitter_haste_5th_3s", "crit_5th_hit"], crit_5th_hit: ["crit_5th_hit", "splitter_haste_5th_3s"], hunter_momentum_3s: ["hunter_momentum_3s", "kill_cooldown_reset"],
    kill_cooldown_reset: ["kill_cooldown_reset", "hunter_momentum_3s"], sp_gain_10: ["sp_gain_10", "xp_gain_2"], xp_gain_2: ["xp_gain_2", "sp_gain_10"] };
  const matches = (e, t) => !!t && (ALIAS[e] ? ALIAS[e].includes(t) : t === e);
  X.countEffect = (s, eff) => limited(X.equippedNames(s)).reduce((a, n) => a + (n && matches(eff, BY_NAME.get(n)?.effectId) ? 1 : 0), 0);
  X.effectPower = function (s, eff) {
    const names = limited(X.equippedNames(s)), inf = X.equippedInfusion(s), bySlot = Object.keys(inf).some((k) => k.startsWith("slot:")), r = [];
    names.forEach((n, i) => { if (n && matches(eff, BY_NAME.get(n)?.effectId)) r.push(effectInfuse(bySlot ? inf[`slot:${i}`] : inf[n])); });
    r.sort((a, b) => b - a); const c = Math.min(r.length, 2);
    return { copies: c, primaryPower: c >= 1 ? r[0] : 0, secondaryPower: c >= 2 ? r[1] : 0 };
  };
  const relicStats = (name, lvl, boost) => { const a = statInfuse(lvl) * (boost ? 2 : 1); return { damage: name === RELICS[0] ? 0.75 * a : 0, attackSpeed: name === RELICS[0] ? 0.15 * a : 0, maxHealth: name === RELICS[1] ? a : 0, lifeRegen: name === RELICS[1] ? a : 0 }; };
  X.relicBoost = () => false; // mythic sacrifice III doubles the relic (6c)
  X.artifactBonuses = function (s) {
    const a = { damageMult: 0, hpMult: 0, hpAdd: 0, lifeRegenAdd: 0, lifeRegenMult: 0, combatRegenPenaltyReduction: 0, attackSpeedMult: 0, moveSpeedMult: 0, inventorySpace: 0 };
    if (!s.parrot) return a;
    const run = PT.expState(s).activeRun, r = run ? run.currentFloor ?? 1 : 1, l = limited(X.equippedNames(s)), n = X.equippedInfusion(s), bySlot = Object.keys(n).some((k) => k.startsWith("slot:"));
    const rp = X.effectPower(s, "combat_regen_relief_10"); a.combatRegenPenaltyReduction = Math.max(0, Math.min(1, K.REGEN_RELIEF * (rp.primaryPower + rp.secondaryPower)));
    l.forEach((e, t) => {
      if (!e || isRelic(e)) return; const i = BY_NAME.get(e); if (!i) return; const o = statInfuse(bySlot ? n[`slot:${t}`] : n[e]), st = i.stats; if (!st) return;
      if (st.damage) a.damageMult += st.damage * o; if (st.maxHealth) a.hpMult += st.maxHealth * o; if (st.maxHealthAdd) a.hpAdd += st.maxHealthAdd * o; if (st.lifeRegen) a.lifeRegenAdd += st.lifeRegen * o;
      if (st.lifeRegenMult) a.lifeRegenMult += st.lifeRegenMult * o; if (st.attackSpeed) a.attackSpeedMult += st.attackSpeed * o; if (st.moveSpeed) a.moveSpeedMult += st.moveSpeed * o;
    });
    if (run) {
      const t = X.countEffect(s, "scale_per_floor"); if (t > 0) { const e = (0.08 + (t >= 2 ? 0.04 : 0)) * Math.max(0, r - 1); a.damageMult += e; a.hpMult += e; }
      const k = X.countEffect(s, "scale_per_kill"); if (k > 0) a.damageMult += 0.006 * Math.floor(Math.max(0, Math.floor(run.enemiesDefeated || 0)) / 100) * k;
    }
    const h = l.filter(Boolean).length, m = X.countEffect(s, "scale_per_artifact");
    if (m > 0) a.damageMult += Math.max(0, h - m) * (0.08 + (m >= 2 ? 0.04 : 0));
    const g = l.findIndex((e) => isRelic(e));
    if (g >= 0) { const e = l[g], t = relicStats(e, n[`slot:${g}`] ?? n[e] ?? 0, X.relicBoost(s));
      a.damageMult = (1 + a.damageMult) * (1 + t.damage) - 1; a.hpMult = (1 + a.hpMult) * (1 + t.maxHealth) - 1; a.lifeRegenMult = (1 + a.lifeRegenMult) * (1 + t.lifeRegen) - 1; a.attackSpeedMult = (1 + a.attackSpeedMult) * (1 + t.attackSpeed) - 1; }
    return a;
  };
  const SP_EFF = { xp_gain_2: 0.1, sp_gain_10: 0.1, sp_gain_15: 0.15, sp_gain_20: 0.2, sp_gain_25: 0.25, sp_gain_30: 0.3 };
  X.artifactSpMult = (s) => 1 + limited(X.equippedNames(s)).reduce((a, n) => a + (n ? SP_EFF[BY_NAME.get(n)?.effectId] || 0 : 0), 0);
  X.pointHoardCopies = (s) => X.countEffect(s, "sp_triple_jackpot");
  X.pointHoardChance = (s) => { const t = X.pointHoardCopies(s); return t >= 2 ? 0.15 : t === 1 ? 0.1 : 0; };
  X.expectedSpMult = (s) => X.artifactSpMult(s) * (1 + 2 * X.pointHoardChance(s));
  X.lootAuraChanceBonus = (s) => { const p = X.effectPower(s, "loot_aura_chance_5"); return 0.05 * (p.primaryPower + p.secondaryPower); };
  X.dmgTakenMult = () => { const s = X.curState; if (!s) return 1; let m = 1; for (const n of limited(X.equippedNames(s))) if (n && BY_NAME.get(n)?.effectId === "dmg_reduce_5") m *= 0.95; return m; };

  // Birb rollSkillPointMultiplierForEnemy: SP roll per kill (Point Hoard: 10% / 15% for x3 and a short attack speed / range buff)
  X.spKillMult = function (s, run) {
    const m = X.artifactSpMult(s), c = X.pointHoardCopies(s), ch = X.pointHoardChance(s);
    let roll = m;
    if (ch > 0 && Math.random() < ch) {
      roll = m * 3; const t = Math.min(2, c);
      if (run) { run.pointHoardBuff = { timer: t >= 2 ? 5 : 3, atk: 0.1 * t, range: 0.05 * t }; }
    }
    return roll * (X.sacSpMult ? X.sacSpMult(s) : 1);
  };
  X.passiveArtifactSpMult = (s) => X.artifactSpMult(s); // Birb getPassiveSkillPointMultiplier(equipped names)

  // ------------------------------------------------------------------ kill drops (Birb handleEnemyLootDrops / grantLootAura / grantEquipmentChest)
  X.lootFloor = (run) => (run.nightMode ? 10 + run.currentFloor - 1 : run.currentFloor);
  X.lootAuraExpectedRolls = function (s) {
    const ext = X.externalBonuses(s), chanceBonus = X.sacChestChanceBonus ? X.sacChestChanceBonus(s) : 0;
    const t = Math.max(0, chanceBonus) + Math.max(0, ext.chestChanceFlat || 0) + Math.max(0, (ext.lootAuraChanceFlat || 0) + X.lootAuraChanceBonus(s));
    const i = Math.max(0, X.sacProfile ? X.sacProfile(s).auraChanceMultiplier : 1), a = Math.max(0, (0.2 + t) * i);
    return Number.isFinite(a) ? softRoot(a, 0.3) : 0.2;
  };
  X.lootAuraQuantity = function (s) {
    const e = PT.expState(s), c = (e.lootQuantityCarry ||= { aura: 0 }), ext = X.externalBonuses(s), n = rewardMult(ext.chestRewardMult || 0, ext.contractChestRewardBonus || 0);
    const i = Math.max(1, X.sacProfile ? X.sacProfile(s).auraQuantityMultiplier : 1) * n + Math.max(0, +c.aura || 0), a = Math.max(1, Math.floor(i + 1e-6));
    c.aura = Math.max(0, i - a); return a;
  };
  const RCOL = { common: "#b0b0b0", uncommon: "#86efac", rare: "#60a5fa", epic: "#c084fc", legendary: "#facc15", mythic: "#f472b6" };
  X.grantLootAura = function (s, run, rarity, at) {
    const extra = rarity === "mythic" ? X.externalBonuses(s).mythicAuraCopyChance || 0 : 0, n = X.lootAuraQuantity(s) + (extra > 0 && Math.random() < extra ? 1 : 0);
    if (n <= 0 || !X.addItemById(s, AURA_ID[rarity], n)) return;
    run.lootLog = run.lootLog || {}; run.lootLog[rarity + " aura"] = (run.lootLog[rarity + " aura"] || 0) + n;
    X.dmgNumber(run, at, `+${n} ${rarity.toUpperCase()} AURA`, RCOL[rarity]);
  };
  X.grantEquipmentChest = function (run, rarity, at) {
    run.equipmentChestsCollected ||= {}; run.equipmentChestsCollected[rarity] = Math.max(0, Math.floor(run.equipmentChestsCollected[rarity] || 0)) + 1;
    X.dmgNumber(run, at, `+1 ${rarity.toUpperCase()} EQUIP CHEST`, RCOL[rarity]);
  };
  X.handleLootDrops = function (s, run, e) {
    const f = X.lootFloor(run);
    if (e.isBoss || e.isElite) { X.grantEquipmentChest(run, pickWeighted(RAR, X.chestWeights(f), "common"), e); return; }
    const x = Math.max(0, X.lootAuraExpectedRolls(s)), k = Math.floor(x), rolls = k + (Math.random() < x - k ? 1 : 0);
    const promo = X.sacProfile ? X.sacProfile(s).auraRarityPromotionChance : 0;
    for (let i = 0; i < rolls; i++) X.grantLootAura(s, run, X.rollAuraRarity(f, promo), e);
  };
  X.rollPotion = function (f) {
    const w = X.potionWeights(f), a = [["minor_heal_pot", w.minor], ["full_potion", w.medium], ["full_recovery_pot", w.major]], t = a.reduce((x, [, v]) => x + v, 0);
    let o = Math.random() * Math.max(1e-4, t); for (const [id, v] of a) if ((o -= v) <= 0) return BY_ID.get(id); return BY_ID.get(a[a.length - 1][0]);
  };
  X.tryPotionDrop = function (s, run, e) {
    if (Math.random() >= K.POTION_DROP) return; const a = X.rollPotion(X.lootFloor(run)); if (!a || !X.addItem(s, a, 1, { ignoreCapacity: true })) return;
    X.dmgNumber(run, e, `+1 ${a.rarity} potion`, RCOL[a.rarity]);
  };
  // Birb order: loot, legendary key (boss), potion, SP. X.onKill runs before the key and SP in expedition_ai.
  X.onKill = function (s, run, e) { X.handleLootDrops(s, run, e); if (!e.isBoss) X.tryPotionDrop(s, run, e); };
  const keyOrig = X.tryLegendaryKey;
  X.tryLegendaryKey = function (s, run, e) { keyOrig(s, run, e); if (e.isBoss) X.tryPotionDrop(s, run, e); };

  // ------------------------------------------------------------------ potions (Birb useExpeditionPotion / tryAutoUseParrotPotion)
  X.usePotion = function (s) {
    const p = inv(s), run = PT.expState(s).activeRun, par = run?.parrot, it = p.potionSlot && p.artifactInventory.find((e) => e.instanceId === p.potionSlot), d = it && BY_NAME.get(it.name), a = d && HEAL[d.effectId];
    if (!par || par.state === "death" || par.health <= 0 || (par.potionCooldown || 0) > 0 || typeof a !== "number") return false;
    const r = PT.hasSun(s, "d_desert_tempered_glass") ? K.TEMPERED_GLASS : 1;
    par.health = Math.min(par.maxHealth, par.health + par.maxHealth * a * r); par.potionCooldown = par.maxPotionCooldown = K.POTION_CD; par.potionEffectTimer = 0.9;
    if (PT.hasSun(s, "d_desert_golden_reserve") && Math.random() < 0.5) X.dmgNumber(run, par, "SAVED", "#ffd95a"); // Golden Reserve: 50% to keep the potion
    else if ((it.count || 1) > 1) it.count = (it.count || 1) - 1; else { p.artifactInventory = p.artifactInventory.filter((e) => e !== it); p.potionSlot = null; }
    return true;
  };
  X.autoPotionThreshold = (s) => { const t = Math.floor(+PT.parrotState(s).autoPotionHealthThreshold || 0); return !Number.isFinite(t) || t <= 0 ? 30 : Math.max(5, Math.min(95, 5 * Math.round(t / 5))); };
  X.autoPotion = function (s) {
    const p = PT.parrotState(s); if (!PT.hasSun(s, "d_desert_auto_potion") || p.autoPotionEnabled !== true) return;
    const par = PT.expState(s).activeRun?.parrot; if (!par || par.health <= 0 || par.maxHealth <= 0 || (par.potionCooldown ?? 0) > 0 || (par.health / par.maxHealth) * 100 > X.autoPotionThreshold(s)) return;
    if (!p.potionSlot || !p.artifactInventory.find((e) => e.instanceId === p.potionSlot)) { const a = p.artifactInventory.find((e) => BY_NAME.get(e.name)?.type === "consumable"); if (!a) return; p.potionSlot = a.instanceId; }
    X.usePotion(s);
  };
  const updOrig = X.update;
  X.update = function (G, dt) { X.curState = G.s; const run = PT.expState(G.s).activeRun; if (run) X.tickLoot(G.s, run, dt); return updOrig(G, dt); };
  X.tickLoot = function (s, run, dt) {
    const par = run.parrot; if (par && par.potionCooldown > 0) par.potionCooldown = Math.max(0, par.potionCooldown - dt);
    if (run.pointHoardBuff && (run.pointHoardBuff.timer -= dt) <= 0) run.pointHoardBuff = null;
    X.autoPotion(s);
  };
  X.tempAttackSpeed = (run) => (run?.pointHoardBuff ? run.pointHoardBuff.atk : 0);
  X.tempRange = (run) => (run?.pointHoardBuff ? run.pointHoardBuff.range : 0);

  // ------------------------------------------------------------------ equipment chests (Birb chest manager equipment_* tables)
  const EXCLUDE = new Set(["spirit_trash", "uncommon_spirit_trash", "rare_spirit_trash", "epic_spirit_trash", "legendary_spirit_trash", "grand_field_pack", "strange_key", "archivist_book", ...ITEMS.filter((a) => a.type === "consumable").map((a) => a.id)]);
  X.CHEST_POOL = Object.fromEntries(RAR.map((r) => [r, ITEMS.filter((a) => a.rarity === r && a.dropSource !== "mythic-sacrifice" && !EXCLUDE.has(a.id))]));
  X.chestCounts = function (s) {
    const e = PT.expState(s), a = e.equipmentChests || {}, b = e.activeRun?.equipmentChestsCollected || {};
    return Object.fromEntries(RAR.map((r) => [r, Math.max(0, Math.floor(a[r] || 0)) + Math.max(0, Math.floor(b[r] || 0))]));
  };
  const takeChest = (s, r) => { const e = PT.expState(s), run = e.activeRun; if (run?.equipmentChestsCollected?.[r] > 0) { run.equipmentChestsCollected[r]--; return true; } if ((e.equipmentChests?.[r] || 0) > 0) { e.equipmentChests[r]--; return true; } return false; };
  X.openChest = function (s, r) {
    const pool = X.CHEST_POOL[r]; if (!pool?.length) return null; const a = pool[Math.floor(Math.random() * pool.length)];
    if (category(a) !== "material" && X.invCapacity(s, "artifact").isFull) return { full: true };
    if (!takeChest(s, r)) return null; X.addItem(s, a, 1); return a;
  };
  const endOrig = X.endRun;
  X.endRun = function (G, ok) {
    const s = G.s, run = PT.expState(s).activeRun, ch = run ? { ...(run.equipmentChestsCollected || {}) } : null, r = endOrig(G, ok);
    if (ch) { const e = PT.expState(s); e.equipmentChests ||= {}; for (const k of RAR) e.equipmentChests[k] = Math.max(0, Math.floor(e.equipmentChests[k] || 0)) + Math.max(0, Math.floor(ch[k] || 0)); }
    return r;
  };
  // Birb resetForParrotRebirb + ParrotRebirb: clear chests, keep strange keys and the inventory items Birb keeps
  const prevRebirb = X.onParrotRebirb;
  X.onParrotRebirb = function (s) {
    if (prevRebirb) prevRebirb(s);
    const e = PT.expState(s); e.equipmentChests = {}; e.lootQuantityCarry = { aura: 0 };
    // Birb keeps Archivist's Book stacks and folds every Strange Key into one stack
    const p = inv(s), book = BY_ID.get("archivist_book").name, key = BY_ID.get("strange_key").name, keys = p.artifactInventory.filter((it) => it.name === key);
    const kept = p.artifactInventory.filter((it) => it.name === book), n = keys.reduce((a, it) => a + Math.max(1, Math.floor(+it.count || 1)), 0);
    p.artifactInventory = keys.length ? [...kept, { ...keys[0], count: Math.max(1, n) }] : kept;
    p.equippedArtifacts = Array.from({ length: X.slotCount(s) }, () => null); p.relicSlot = null; p.potionSlot = null; p.artifactInventoryLayout = []; p.materialInventoryLayout = [];
  };
})();
