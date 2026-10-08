// Peckwood playtest, Phase 6a: the Expedition core, copied from Birb's expeditionManager (class fI), its depth
// balance (pI), the enemy stat tables (editors gy / fy / iS / tS), the game-side parrot stats (lb, Gy, gC) and the
// parrot rebirb gates (m_ / g_ / f_). Floors, collision boxes, portals and enemy base stats come from
// js/expedition_data.js (pulled from Birb's live engine by tools/build_expedition_data.js).
// Combat (enemy AI + the parrot) lives in expedition_ai.js. Loot, gear, artifacts, quests and sacrifice follow in 6b/6c.
// Night mode (the post-game ice-fire floor) is not copied yet.
"use strict";
(function () {
  const PT = window.PT, X = (PT.EXP = {}), DATA = window.EXPEDITION_DATA;
  const { D } = PT;
  X.DATA = DATA;
  PT.EXP_HUB_MAP = DATA.hub.mapId; // 5
  X.FLOOR_MAP = {}; X.MAP_FLOOR = {};
  for (const [f, v] of Object.entries(DATA.floors)) { X.FLOOR_MAP[f] = v.mapId; X.MAP_FLOOR[v.mapId] = +f; }
  PT.MAPS[PT.EXP_HUB_MAP] = { id: PT.EXP_HUB_MAP, key: "expedition-hub", name: "EXPEDITION", w: 1056, h: 792 };
  for (const [f, v] of Object.entries(DATA.floors)) PT.MAPS[v.mapId] = { id: v.mapId, key: "expedition-floor-" + f, name: "FLOOR " + f, w: 2000, h: 4000, side: true, floor: +f };
  // night mode (Birb activeRun.nightMode): parrot rebirb III, floor 1 only, on its own map; stats and loot use floor 10 + floor - 1 (Birb Qt)
  X.NIGHT_MAP = DATA.night[1].mapId; X.MAP_FLOOR[X.NIGHT_MAP] = 1; X.NIGHT_MAX_FLOOR = 1;
  { const b = DATA.night[1].bounds; PT.MAPS[X.NIGHT_MAP] = { id: X.NIGHT_MAP, key: "expedition-night-floor-1", name: "NIGHT FLOOR 1", w: Math.ceil(b.maxX + 160), h: Math.ceil(b.maxY + 160), side: true, floor: 1, night: true }; }
  X.isRunMap = (m) => m in X.MAP_FLOOR;
  X.nightRun = () => !!PT.G?.s?.expedition?.activeRun?.nightMode; // Birb reads this.state.activeRun?.nightMode inside the stat wrappers
  X.canNight = (s) => X.rebirbs(s) >= 3; // Birb $ / Ma
  X.qt = (f, night = X.nightRun()) => (night ? 10 + f - 1 : f); // Birb Qt
  X.runMap = (floor, night = X.nightRun()) => (night && floor === 1 ? X.NIGHT_MAP : X.FLOOR_MAP[floor]); // Birb getRunMapForFloor
  const FD = (m) => (m === X.NIGHT_MAP ? DATA.night[1] : DATA.floors[X.MAP_FLOOR[m]]);

  // ------------------------------------------------------------------ constants (Birb fI statics, editors / maps consts)
  const K = X.K = {
    MAX_FLOOR: 9, BASE_HP: 100, BASE_DAMAGE: 100, HP_PER_POINT: 1, REGEN_PER_POINT: 1, DAMAGE_PER_POINT: 1, LEASH: 450,
    COMBAT_FEEL: 2, GROUP_SPACING: 1.1, BOSS_RESPAWN: 480, ELITE_RESPAWN: 300,
    ELITE: { health: 5.5, attack: 1.42, speed: 1.14, xp: 9.5, skillPoints: 4.5 },
    SPAWN_COLL_W: 20, SPAWN_COLL_H: 10, ACQUIRE_INSET: 12, PROC_GROUP_MIN: 180, DEPTH_GUARD_MIN: 170, ELITE_GROUP_MIN: 220,
    PORTAL_PAD: 56, SPAWN_MIN: 36, MINI_FLY_SPAWN_MIN: 16, MINI_FLY_MAX_PER_PARENT: 4, MINI_FLY_READY: 2, MINI_FLY_BASE: 120,
    MINI_FLY_ACCEL: 95, MINI_FLY_MAX: 430, MINI_FLY_LAND: 10, SEP: 28, MINI_FLY_SEP: 14, POTION_DROP: 0.02,
    COBRA_TICK: 1, COBRA_TICKS: 3, FLOOR3_MAX_FLY: 0, ANKH_CD: 3.8, COFFIN_CD: 12.5, ANUBIS_SUMMONS: 3,
    HARPY_Y: 50, WIZARD_Y: 3, BRUTE_Y: 27, CHIEFTAIN_Y: 30,
    CULTISTS: 5, CULT_RX: 176, CULT_RY: 144, CULT_SACRIFICE: 1.05, ARCH_TRANSFORM: 2.32,
    ARCH: { enrageHealthRatio: 0.5, firstCastDelay: 2.4, cooldown: 5, enragedCooldown: 3.6, castRange: 560, chainWindup: 1.35, chainTravel: 0.3, chainRadius: 46, chainDamage: 1.35, sealWindup: 1.4, sealInterval: 0.34, sealRadius: 40, sealDamage: 0.7, recovery: 0.65 },
  };

  // ------------------------------------------------------------------ state (Birb maps lA / oA, game vC)
  // Birb nA/tA: XP to the next parrot level
  X.xpReq = (L) => { const e = Math.max(1, Math.floor(Number(L) || 1)), s = Math.log10(e); return Math.max(1, Math.floor(Math.pow(10, 2 + (-1 / 6) * s + (11 / 6) * s * s))); };
  PT.expState = function (s) {
    const e = s.expedition || (s.expedition = {});
    e.saveVersion ??= 3; e.enemyRespawnCooldowns ||= {}; e.unlocked ??= false;
    e.progress ||= { level: 1, xp: 0, xpToNextLevel: X.xpReq(1), totalXpEarned: 0 };
    e.totalRuns ??= 0; e.successfulRuns ??= 0; e.totalEnemiesDefeated ??= 0; e.highestFloorReached ??= 1; e.activeRun ??= null;
    e.isAutoAttack ??= false; e.archivistDefeated ??= false;
    e.questStats ||= { killsByFloor: {}, bossClearsByFloor: {}, killsByEnemyType: {} };
    return e;
  };
  PT.parrotState = function (s) {
    const p = s.parrot || (s.parrot = { unlocked: false, level: 1, xp: 0, skillPoints: 0, rebirbCount: 0, skills: { hp: 0, lifeRegen: 0, damage: 0 },
      artifactInventory: [], equipmentUpgrades: { beak: { rarity: "common", level: 1 }, armor: { rarity: "common", level: 1 }, aura: { rarity: "common", level: 1 } }, strangeKeys: 0 });
    p.skills ||= { hp: 0, lifeRegen: 0, damage: 0 }; p.skillPoints ??= 0; p.rebirbCount ??= 0; p.strangeKeys ??= 0;
    p.equipmentUpgrades ||= { beak: { rarity: "common", level: 1 }, armor: { rarity: "common", level: 1 }, aura: { rarity: "common", level: 1 } };
    return p;
  };
  // Birb: unlockExpeditionIfTierTwoComplete (the second nest level's build bar complete, or any higher nest level)
  X.syncUnlock = function (s) {
    const e = PT.expState(s); if (e.unlocked) return;
    const b = PT.nestBuild ? PT.nestBuild(s) : null;
    if (b && (b.tier > 1 || (b.tier === 1 && b.isComplete))) { e.unlocked = true; PT.parrotState(s).unlocked = true; }
  };
  X.archivistDefeated = (s) => !!PT.expState(s).archivistDefeated;
  X.maxFloorForEvo = (s) => ((s.evolutionCount || 0) >= 5 ? 9 : 3); // Birb os / ul
  X.rebirbs = (s) => Math.max(0, Math.floor(PT.parrotState(s).rebirbCount || 0));

  // ------------------------------------------------------------------ parrot stats (Birb lb + Gy, getParrotSkillAdditions, getEquipmentMultipliers)
  const GEAR_BEAK = { common: [0.1, 0.325, 0.55, 0.775, 1], uncommon: [1, 2, 3, 4, 5], rare: [5, 8, 12, 17, 25], epic: [25, 40, 60, 85, 120], legendary: [150, 190, 255, 340, 430] };
  X.GEAR = {
    beak: GEAR_BEAK,
    armor: { common: [1, 2, 3, 4, 5], uncommon: [5, 7.5, 10, 12.5, 15], rare: [15, 22, 32, 45, 65], epic: [65, 100, 150, 220, 320], legendary: [400, 520, 720, 1e3, 1320] },
    aura: Object.fromEntries(Object.entries(GEAR_BEAK).map(([k, v]) => [k, v.map((x) => x / 2)])),
  };
  const RAR = new Set(["common", "uncommon", "rare", "epic", "legendary"]);
  // Birb Oq: legendary gear also scales with the mine's expedition refinements (1.25^t, then +1% steps) — 0 refinements until that system lands
  const refineMult = (t) => (t <= 3 ? Math.pow(1.25, t) : Math.pow(1.25, 3) * (1 + 0.01 * (t - 3 + Math.floor((t - 3) / 3))));
  X.gearMult = function (s, slot) {
    const u = PT.parrotState(s).equipmentUpgrades[slot] || {}, r = RAR.has(u.rarity) ? u.rarity : "common", L = Math.max(1, Math.min(5, Math.floor(Number(u.level) || 1)));
    const t = r === "legendary" ? Math.max(0, Math.floor(s.mine?.expeditionCycle?.refinements?.[slot] || 0)) : 0;
    return X.GEAR[slot][r][L - 1] * refineMult(t);
  };
  X.gearMults = (s) => ({ beakMult: X.gearMult(s, "beak"), armorMult: X.gearMult(s, "armor"), auraMult: X.gearMult(s, "aura") });
  // Birb gC: rebirb skill point multiplier (x2 / x4 / x8, plus 0.1% per parrot level from 2 rebirbs)
  X.rebirbSpMult = (s) => { const n = X.rebirbs(s), i = Math.max(1, PT.expState(s).progress.level || 1); return Math.max(1, (n >= 3 ? 8 : n >= 2 ? 4 : n >= 1 ? 2 : 1) * (n >= 2 ? 1 + 0.001 * i : 1)); };
  const fishM = (s, t) => Math.max(0, PT.activeFishMult ? PT.activeFishMult(s, t) : 1);
  const aqM = (s, t) => Math.max(0, PT.aqModifier ? PT.aqModifier(s, t) || 1 : 1);
  X.skillAdditions = function (s) {
    const sk = PT.parrotState(s).skills, sun = (id) => PT.sunLevel(s, id);
    const tree = { hpMult: 0.1 * sun("d_spirit_shell"), damageMult: 0.1 * sun("d_spirit_scouting"), attackSpeedMult: 0.02 * sun("d_spirit_momentum"), moveSpeedMult: 0.02 * sun("d_spirit_momentum") };
    const oasis = 1 + 0.1 * sun("d_desert_oasis_recovery"), r = {};
    for (const k of ["hp", "life_regen", "damage", "skill_point", "attack_speed", "move_speed"]) r[k] = fishM(s, "parrot_" + k + "_mult") * aqM(s, "parrot_" + k + "_mult");
    return {
      hp: sk.hp * K.HP_PER_POINT, lifeRegen: sk.lifeRegen * K.REGEN_PER_POINT, damage: sk.damage * K.DAMAGE_PER_POINT,
      hpMult: (1 + tree.hpMult) * r.hp - 1, lifeRegenMult: r.life_regen * oasis - 1, damageMult: (1 + tree.damageMult) * r.damage - 1,
      skillPointMult: r.skill_point * X.rebirbSpMult(s) - 1, attackSpeedMult: (1 + tree.attackSpeedMult) * r.attack_speed - 1,
      moveSpeedMult: (1 + tree.moveSpeedMult) * r.move_speed - 1, rangeMult: 0,
    };
  };
  const nz = (v, d) => (Number.isFinite(v) ? Number(v) : d), q0 = (v, d = 0) => Math.max(0, nz(v, d)), y1 = (v) => q0(v, 1), w1 = (v) => Math.max(0, 1 + nz(v, 0));
  // Birb Gy: (base + skills + artifact adds) x gear x artifact x progression x external x final
  X.combine = function (o) {
    return {
      maxHealth: (q0(o.base.maxHealth) + q0(o.skill.maxHealth) + q0(o.art.maxHealth)) * y1(o.gear.armor) * w1(o.artM.maxHealthMult) * w1(o.prog.maxHealthMult) * w1(o.ext.maxHealthMult) * y1(o.fin.maxHealth),
      damage: (q0(o.base.damage) + q0(o.skill.damage)) * y1(o.gear.beak) * w1(o.artM.damageMult) * w1(o.prog.damageMult) * w1(o.ext.damageMult) * y1(o.fin.damage),
      lifeRegen: (q0(o.base.lifeRegen) + q0(o.skill.lifeRegen) + q0(o.art.lifeRegen)) * y1(o.gear.aura) * w1(o.artM.lifeRegenMult) * w1(o.prog.lifeRegenMult) * w1(o.ext.lifeRegenMult) * y1(o.fin.lifeRegen),
      attackSpeed: w1(o.artM.attackSpeedMult) * w1(o.prog.attackSpeedMult) * w1(o.ext.attackSpeedMult),
      moveSpeed: w1(o.artM.moveSpeedMult) * w1(o.prog.moveSpeedMult) * w1(o.ext.moveSpeedMult),
    };
  };
  // Hooks the loot / quest / sacrifice phases fill in (Birb artifactManager.calculateParrotBonuses, getQuestMerchantExpeditionBonuses, Ia)
  X.artifactBonuses = () => ({ hpAdd: 0, lifeRegenAdd: 0, hpMult: 0, damageMult: 0, lifeRegenMult: 0, attackSpeedMult: 0, moveSpeedMult: 0, inventorySpace: 0, combatRegenPenaltyReduction: 0 });
  // Birb getQuestMerchantExpeditionBonuses: desert nodes, Muad'Birb, community goals; quest merchant, fish market parrot buffs and
  // the crow's expedition tracks join in 6c (they read 0 until then)
  X.questBonus = () => 0; X.crowBonus = () => 0;
  // Birb getActiveParrotBuffBonus: the larger of a legacy bought parrot buff and the sum of live contract buffs of that type
  X.marketParrotBuff = (s, k, now = Date.now()) => { const b = s.aquarium?.market?.activeParrotBuffs?.[k], r = b && b.expiresAt > now ? Math.max(0, Number(b.value) || 0) : 0; return Math.max(0, Math.max(r, PT.contractBonus ? PT.contractBonus(s, k, now) : 0)); };
  X.muadBirb = (s) => { if (!PT.hasSun(s, "d_desert_muad_birb")) return 1; const t = PT.res(s, "goldenPopcorn"), n = t.lte(0) ? D(1) : t.div(15e7).sqrt().add(1); return n.lte(20) ? Math.max(1, n.toNumber()) : 20 + 4.4 * n.div(20).ln(); };
  X.community = (k) => (PT.COMMUNITY && PT.COMMUNITY[k]) || 1;
  X.externalBonuses = (s) => {
    const q = X.questBonus, f = X.marketParrotBuff, w = PT.sunLevel(s, "d_desert_warpath");
    return {
      damageMult: q(s, "expedition_damage_mult") + f(s, "expedition_damage_mult") + 0.1 * w,
      hpMult: q(s, "expedition_hp_mult") + f(s, "expedition_hp_mult") + (PT.hasSun(s, "d_desert_rebirb_parrot_vitality") ? 0.25 : 0) + (PT.hasSun(s, "d_desert_guarded_plumage") ? 0.15 : 0),
      lifeRegenMult: f(s, "expedition_life_regen_mult"), finalDamageMult: X.crowBonus(s, "damage"),
      finalHpMult: (1 + X.crowBonus(s, "armor")) * (PT.mineHas && PT.mineHas(s, "expedition_rivets") ? 1.15 : 1) - 1, finalLifeRegenMult: X.crowBonus(s, "regen"),
      combatRegenPenaltyReduction: X.crowBonus(s, "regenPenalty") + (PT.hasSun(s, "d_desert_combat_regen_penalty") ? 0.2 : 0),
      skillPointMult: q(s, "expedition_skill_point_mult") + f(s, "expedition_skill_point_mult") + (PT.hasSun(s, "d_desert_expedition_points") ? 1 : 0) + (X.muadBirb(s) - 1) + (X.community("skillPointGain") - 1),
      attackSpeedMult: f(s, "expedition_attack_speed_mult"), moveSpeedMult: f(s, "expedition_move_speed_mult"), chestChanceFlat: q(s, "expedition_chest_chance_flat"),
      chestRewardMult: q(s, "expedition_chest_reward_mult") + f(s, "expedition_chest_reward_mult") + (PT.hasSun(s, "d_desert_salvage_rights") ? 0.25 : 0) + (PT.hasSun(s, "d_desert_dune_scouts") ? 0.5 : 0) + (X.community("chestRewards") - 1),
      contractChestRewardBonus: f(s, "expedition_chest_reward_mult"), lootAuraChanceFlat: PT.hasSun(s, "d_desert_blossom_route") ? 0.05 : 0,
    };
  };
  X.mythicFinal = (s) => ((s.expedition?.mythicSacrifice?.level ?? 0) >= 1 ? 1.2 : 1);
  X.sacrificeMilestone = () => ({ parrotAttackSpeedMultiplier: 1, parrotMoveSpeedMultiplier: 1 });
  // Birb refreshParrotBonuses: the run-time parrot numbers
  X.parrotBonuses = function (s) {
    const o = X.skillAdditions(s), c = X.artifactBonuses(s), g = X.gearMults(s), p = X.externalBonuses(s), l = X.sacrificeMilestone(s), mf = X.mythicFinal(s);
    const m = X.combine({
      base: { maxHealth: K.BASE_HP, damage: K.BASE_DAMAGE, lifeRegen: 0 }, skill: { maxHealth: o.hp, damage: o.damage, lifeRegen: o.lifeRegen },
      art: { maxHealth: c.hpAdd, lifeRegen: c.lifeRegenAdd }, gear: { armor: g.armorMult, beak: g.beakMult, aura: g.auraMult },
      artM: { maxHealthMult: c.hpMult, damageMult: c.damageMult, lifeRegenMult: c.lifeRegenMult, attackSpeedMult: c.attackSpeedMult, moveSpeedMult: c.moveSpeedMult },
      prog: { maxHealthMult: o.hpMult, damageMult: o.damageMult, lifeRegenMult: o.lifeRegenMult, attackSpeedMult: o.attackSpeedMult, moveSpeedMult: o.moveSpeedMult },
      ext: { maxHealthMult: p.hpMult, damageMult: p.damageMult, lifeRegenMult: p.lifeRegenMult, attackSpeedMult: (p.attackSpeedMult || 0) + (l.parrotAttackSpeedMultiplier - 1), moveSpeedMult: (p.moveSpeedMult || 0) + (l.parrotMoveSpeedMultiplier - 1) },
      fin: { maxHealth: (1 + (p.finalHpMult || 0)) * mf, damage: (1 + (p.finalDamageMult || 0)) * mf, lifeRegen: 1 + (p.finalLifeRegenMult || 0) },
    });
    return { hp: m.maxHealth - K.BASE_HP, lifeRegen: m.lifeRegen, damage: m.damage - K.BASE_DAMAGE, inventorySpace: c.inventorySpace, skillPointMult: o.skillPointMult || 0,
      attackSpeedMult: m.attackSpeed - 1, moveSpeedMult: m.moveSpeed - 1, rangeMult: o.rangeMult || 0, sacRadiusMult: X.sacRadiusMult ? X.sacRadiusMult(s) : 1, combatRegenPenaltyReduction: c.combatRegenPenaltyReduction || 0 };
  };
  // Birb getParrotTotalStats (lb): what the parrot window shows
  PT.parrotTotalStats = function (s) {
    const b = X.parrotBonuses(s);
    return { hp: K.BASE_HP + b.hp, damage: K.BASE_DAMAGE + b.damage, lifeRegen: b.lifeRegen, attackSpeed: 1 + b.attackSpeedMult, moveSpeed: 1 + b.moveSpeedMult };
  };
  // Birb: spending skill points (1 point = +1 HP / +1 regen / +1 damage) and the reset cost (chests, Phase 6b)
  PT.parrotSpend = function (s, skill, n) {
    const p = PT.parrotState(s), a = Math.min(Math.floor(p.skillPoints), Math.max(1, Math.floor(n || 1)));
    if (a <= 0 || !(skill in p.skills)) return false;
    p.skills[skill] += a; p.skillPoints -= a; X.refreshRunParrot(s); return true;
  };
  PT.parrotResetCost = (s) => { const sk = PT.parrotState(s).skills, t = (sk.hp || 0) + (sk.lifeRegen || 0) + (sk.damage || 0); return t <= 0 ? 0 : Math.max(1, Math.ceil(Math.sqrt(0.01 * t))); };

  // ------------------------------------------------------------------ progress: XP from skill points (Birb addXp / awardProgressFromSkillPoints / uU)
  X.addXp = function (s, n) {
    const pr = PT.expState(s).progress; pr.xp += n; pr.totalXpEarned += n; let up = false;
    while (pr.xp >= pr.xpToNextLevel) { pr.xp -= pr.xpToNextLevel; pr.level++; pr.xpToNextLevel = X.xpReq(pr.level); up = true; }
    PT.parrotState(s).level = pr.level;
    const run = PT.expState(s).activeRun;
    if (up && run?.parrot) { X.refreshRunParrot(s); run.parrot.health = run.parrot.maxHealth; }
  };
  X.grantSkillPoints = function (s, n) { n = Math.max(0, Math.floor(n)); if (n <= 0) return; PT.parrotState(s).skillPoints += n; X.addXp(s, n); };

  // ------------------------------------------------------------------ floors (Birb editors iS / tS / AS / cS)
  X.PLAN = [
    { boss: "cobra", packs: [["masked-forest-spirit", 10], ["twig-blight", 12], ["flower-monster", 10]], group: [2, 4] },
    { boss: "witch", packs: [["harpy", 12], ["cobra", 12], ["skeleton-warrior", 12]], group: [2, 4] },
    { boss: "anubis", packs: [["mummy", 14], ["anubis-warrior", 13]], group: [3, 5] },
    { boss: "fishfolk-brute", packs: [["fishfolk-whipe", 16], ["fishfolk-inkbender", 14]], group: [2, 3] },
    { boss: "fishfolk-horror", packs: [["fishfolk-pugilist", 8], ["sea-horror", 8], ["sea-gramlin", 11], ["elemental", 8]], group: [3, 5] },
    { boss: "frosty-slime", packs: [["frost-wisp", 10], ["arctic-whisper", 10], ["ice-harpy", 7], ["frozy-cube", 8]], group: [3, 5] },
    { boss: "frogfolk-chieftain", packs: [["frogfolk-wizard", 12], ["frogfolk-brute", 6], ["giant-fly", 6]], group: [3, 5] },
    { boss: "giant-black-pudding", packs: [["black-pudding", 22], ["ghost", 10], ["doppelganger", 5]], group: [3, 5] },
    { boss: "the-archivist", packs: [["hell-critter", 8], ["imp", 5], ["cacodaemon", 5], ["cultist-brute", 6]], group: [3, 5], diversity: { minDistinctTypes: 2, maxSameType: 2 } },
  ];
  X.NIGHT_PLAN = { ...X.PLAN[0], boss: "ice-fire-guardian", packs: [["elven-assassin", 11], ["zombie-cultist", 11], ["shardsoul-slayer", 10]] }; // Birb vl(1, true)
  X.NIGHT_POOL = ["elven-assassin", "zombie-cultist", "shardsoul-slayer"]; // Birb mn
  const plan = (f) => (X.nightRun() && f === 1 ? X.NIGHT_PLAN : X.PLAN[Math.max(1, Math.min(9, Math.floor(f) || 1)) - 1]);
  X.floorConfig = function (f) { // Birb tS
    const t = Math.max(1, Math.min(9, Math.floor(Number(f) || 1)));
    const i = t <= 1 ? 8 : t === 2 ? 10 : t <= 4 ? 6 : 13, a = t <= 1 ? 6 : t === 2 ? 8 : t === 3 ? 9 : t === 4 ? 7 : 11;
    return { coverageTargetPerBand: i, maximumRegularsPerBand: a, minimumGroupsPerBand: t <= 1 ? 3 : t === 2 ? 4 : t <= 4 ? 2 : 5, eliteLeaderGroups: t <= 1 ? 1 : t === 2 ? 2 : t === 4 ? 1 : 3 };
  };
  X.bounds = (mapId) => FD(mapId)?.bounds || { minX: 160, maxX: 1840, minY: 160, maxY: 3680 };
  X.collisions = (mapId) => {
    const f = X.MAP_FLOOR[mapId]; const raw = f ? FD(mapId).collisions : mapId === PT.EXP_HUB_MAP ? DATA.hub.collisions : [];
    return raw.map ? (raw._rects ||= raw.map(([l, t, r, b]) => ({ left: l, top: t, right: r, bottom: b }))) : [];
  };
  X.portals = (mapId) => (X.MAP_FLOOR[mapId] ? FD(mapId).portals : mapId === PT.EXP_HUB_MAP ? DATA.hub.portals : []);
  X.portal = (mapId, type) => { const p = X.portals(mapId).find((q) => q.type === type); return p ? { x: p.x, y: p.y, radius: p.r } : null; };
  X.portalZones = (mapId, pad = K.PORTAL_PAD) => X.portals(mapId).map((p) => ({ x: p.x, y: p.y, radius: p.r + pad }));
  const inZones = (x, y, zs) => zs.some((z) => (x - z.x) ** 2 + (y - z.y) ** 2 <= z.radius * z.radius);
  // Birb F / G: depth ratio along y (map 32, the night floor, is reversed)
  X.depthRatio = (mapId, x, y) => { const b = X.bounds(mapId); return Math.max(0, Math.min(1, (y - b.minY) / Math.max(1, b.maxY - b.minY))); };
  X.depthY = (mapId, ratio) => { const b = X.bounds(mapId); return b.minY + (b.maxY - b.minY) * ratio; };
  X.band = (r) => { const t = Math.max(0, Math.min(1, r)); return t < 0.2 ? 0 : t < 0.4 ? 1 : t < 0.6 ? 2 : t < 0.8 ? 3 : 4; };
  X.bandCenter = (i) => [0.1, 0.3, 0.5, 0.7, 0.9][Math.max(0, Math.min(4, i))];

  // ------------------------------------------------------------------ enemy stats (Birb editors my/gy/fy + pI depth balance)
  const TYPE_MULT = {
    "masked-forest-spirit": [1, 1, 1, 1], "twig-blight": [0.9, 1.08, 0.95, 1], "giant-fly": [1.22, 1.02, 1.25, 1.1], anubis: [1.36, 1.24, 1.38, 1.24],
    cobra: [1.18, 1.15, 1.22, 1.12], ghoul: [1.2, 1.14, 1.24, 1.12], "skeleton-warrior": [1.22, 1.16, 1.25, 1.13], witch: [1.3, 1.22, 1.34, 1.2],
    "flower-monster": [1.32, 1.12, 1.28, 1.1], harpy: [1.16, 1.2, 1.3, 1.15], "ice-harpy": [1.16, 1.2, 1.3, 1.15], "fishfolk-horror": [1.48, 1.32, 1.46, 1.32],
    "fishfolk-pugilist": [1.28, 1.26, 1.34, 1.22], "sea-horror": [1.24, 1.18, 1.3, 1.16], "sea-gramlin": [1.14, 1.1, 1.22, 1.08], elemental: [1.2, 1.22, 1.28, 1.12],
    "frost-wisp": [1.12, 1.28, 1.32, 1.18], "arctic-whisper": [1.18, 1.24, 1.34, 1.18], "frosty-slime": [1.52, 1.34, 1.48, 1.34], "frozy-cube": [1.2, 1.22, 1.3, 1.16],
    "ice-fire-guardian": [1.34, 1.28, 1.4, 1.24], "frogfolk-wizard": [1.28, 1.34, 1.46, 1.26], "frogfolk-brute": [1.42, 1.38, 1.52, 1.28], "frogfolk-chieftain": [1.56, 1.44, 1.62, 1.36],
    ghost: [1.42, 1.42, 1.58, 1.32], doppelganger: [1.54, 1.48, 1.68, 1.4], "black-pudding": [1.5, 1.42, 1.6, 1.34], "giant-black-pudding": [1.68, 1.5, 1.78, 1.48],
    "hell-critter": [1.56, 1.5, 1.7, 1.4], imp: [1.48, 1.58, 1.72, 1.4], cacodaemon: [1.62, 1.62, 1.76, 1.42], cultist: [1.5, 0, 0, 0], "cultist-brute": [1.68, 1.66, 1.8, 1.46],
    "the-archivist": [2.4, 2.05, 2.2, 1.85], "mini-fly": [0.25, 0.65, 0, 0],
  };
  const py = (e, t = 0) => (Number.isFinite(e) ? Math.max(t, Math.round(e)) : t), hy = (e) => (Number.isFinite(e) ? Math.max(1, Math.floor(e)) : 1);
  X.baseStats = (type) => DATA.enemyBaseStats[type] || null;
  // Birb gy (ml) then fy (gl): floor and boss scaling of the base stats
  X.enemyStats = function (type, floor, isBoss) {
    const a = X.baseStats(type); if (!a) return null;
    const r = hy(floor), n = TYPE_MULT[type] || [1, 1, 1, 1], A = isBoss ? 8 : 1, c = isBoss ? 1.28 : 1, d = isBoss ? 14 : 1, u = isBoss ? 6 : 1, mini = type === "mini-fly";
    const f = py(a.skillPointReward * n[3], 0) + Math.floor((r - 1) / 2);
    const g = { health: py(a.health * n[0] * Math.pow(2.4, r - 1) * A, 1), attack: py(a.attack * n[1] * Math.pow(1.35, r - 1) * c, 1), defense: py(a.defense, 0), speed: py(a.speed, 1),
      xpBase: mini ? 0 : py(a.xpBase * n[2] * Math.pow(2.05, r - 1) * d, 0), skillPointReward: mini ? 0 : py(f * u, 0) };
    const k = Math.max(0, r - 1);
    return { health: py(g.health * Math.pow(1.1483, k) * (isBoss ? 1.1 : 1), 1), attack: py(g.attack * Math.pow(1.1112, k) * (isBoss ? 1.08 : 1), 1), defense: py(g.defense, 0),
      speed: py(g.speed, 1), xpBase: py(g.xpBase * Math.pow(1.1236, k), 0), skillPointReward: py(g.skillPointReward, 0), isBoss: !!isBoss };
  };
  { const es = X.enemyStats; X.enemyStats = (type, floor, isBoss) => es(type, X.qt(floor), isBoss); }
  const BANDS = {
    2: [[18, 36], [100, 160], [430, 560], [1200, 1800], [4500, 6e3]], 3: [[13, 17], [140, 220], [900, 1300], [4500, 7e3], [22e3, 3e4]],
    4: [[6, 12], [48, 84], [360, 600], [1800, 2800], [4600, 6200]], 5: [[18, 36], [80, 120], [280, 420], [1e3, 1500], [3500, 5200]],
    6: [[18, 36], [88, 112], [260, 380], [800, 1200], [2400, 3600]], 7: [[18, 36], [72, 144], [288, 576], [1152, 2304], [4608, 9216]],
    1: [[18, 36], [360, 540], [1800, 2400], [9e3, 1e4], [45e3, 6e4]],
  };
  X.healthBand = (ratio, floor) => { const i = Math.max(1, Math.floor(Number(floor) || 1)), [min, max] = BANDS[i >= 7 ? 7 : i][X.band(ratio)]; return { min, max }; };
  X.floorHealthMult = (f) => { const t = Math.max(1, Math.floor(Number(f) || 1)); if (t <= 1) return 1; const T = { 2: 1200, 3: 25e4, 4: 3e8, 5: 6e10, 6: 18e12, 7: 54e14, 8: 1188e15 }; return T[t] ?? 54e14 * Math.pow(1200, t - 7); };
  X.roundHealth = (e) => { const t = Math.max(1, Math.round(e)); if (t < 100) return t; const a = Math.pow(10, Math.max(0, Math.floor(Math.log10(t)) - 1)); return Math.max(1, Math.round(t / a) * a); };
  X.depthHealthAt = function (type, h, ratio, floor, q) {
    const r = X.healthBand(ratio, floor), s = X.floorHealthMult(floor), l = (r.min + Math.max(0, Math.min(1, q)) * (r.max - r.min)) * s;
    const c = Math.max(1, X.baseStats(type)?.health || h || 1), d = Math.max(0.2, (h || c) / c);
    return X.roundHealth(l * d);
  };
  { const dh = X.depthHealthAt; X.depthHealthAt = (type, h, ratio, floor, q) => dh(type, h, ratio, X.qt(floor), q); }
  X.attackFromLife = (atk, hp, life, boss) => { const a = Math.max(1, +atk || 1), r = Math.max(1, +hp || 1), s = Math.max(1, +life || 1) / 25, o = Math.max(1, r / 5); let l = s * Math.max(0.95, Math.min(1.05, a / o)); if (boss) l *= 1.12; return Math.max(1, Math.round(l)); };
  X.spFromHealth = function (hp, minSp, boss) {
    const i = Math.max(1, +hp || 1); let a = i <= 60 ? 3 : Math.max(3, Math.round(16.61 * Math.log10(i) - 23.23));
    a = Math.max(3, Math.round(a * (i <= 120 ? 1 : Math.pow(i / 120, 0.14)))); if (boss) a = Math.max(a, Math.round(2.5 * a));
    return Math.max(a, Math.max(0, Math.floor(+minSp || 0)));
  };
  X.minSpForBand = function (type, h, minSp, boss, floor, bandIdx) {
    const s = Math.max(0, Math.min(4, Math.floor(+bandIdx || 0))), o = Math.max(1, Math.floor(+floor || 1)), l = X.floorHealthMult(o);
    const c = Math.max(1, X.baseStats(type)?.health || h || 1), d = Math.max(0.2, (h || c) / c), u = o === 8 ? 4 : 1;
    const hh = o >= 4 ? Math.ceil(X.minSpForBand(type, h, minSp, boss, o - 1, 4) * u) : 0;
    let p = hh;
    for (let m = 0; m <= s; m++) {
      const e = X.healthBand(X.bandCenter(m), o), t = X.roundHealth(e.min * l * d), a = X.spFromHealth(t, minSp, boss), r = m <= 0 ? hh : Math.ceil(2.5 * p), cc = Math.max(a, r);
      if (m === s) return cc; p = cc;
    }
    return 0;
  };
  X.spReward = (type, life, h, minSp, boss, floor, ratio) => (type === "mini-fly" ? 0 : Math.max(X.spFromHealth(life, minSp, boss), X.minSpForBand(type, h, minSp, boss, floor, X.band(ratio))));
  { const sr = X.spReward; X.spReward = (type, life, h, minSp, boss, floor, ratio) => sr(type, life, h, minSp, boss, X.qt(floor), ratio); }
  X.floorSpScale = (e, f, ratio = 0) => floorSpScaleRaw(e, X.qt(f), ratio);
  const floorSpScaleRaw = function (e, f, ratio = 0) {
    const i = Math.max(0, Math.floor(+e || 0)); if (i <= 0) return 0; const n = 1 - Math.max(0, Math.min(1, +ratio || 0));
    if (f >= 9) return Math.round(2.4 * i); if (f >= 7) return Math.round(2 * i);
    if (f === 6) return Math.round(i * (2 + 0.8 * n)); if (f === 5) return Math.round(i * (2.8 + 1.6 * n)); if (f === 4) return Math.round(i * (2.4 + 3.8 * n)); if (f === 3) return Math.round(i * (2.2 + 10.7 * n));
    if (f === 2) { const e2 = Math.max(0, Math.min(1, +ratio || 0)); if (e2 < 0.2) return Math.round(3 * i); if (e2 < 0.4) return Math.round(1.5 * i); }
    return i;
  };
  // Birb getExpeditionShinyEnemyChance + rollExpeditionEnemyShiny
  X.shinyChance = (s) => Math.min(1, PT.hasSun(s, "d_desert_shiny_enemies") || PT.hasSun(s, "d_desert_mineral_tracker") ? 0.01 : 0);
  X.rollShiny = (s, type, sp) => { if (type === "mini-fly" || Math.max(0, Math.floor(+sp || 0)) <= 0) return { isShiny: false, hm: 1 }; const n = X.shinyChance(s); return n <= 0 || Math.random() >= n ? { isShiny: false, hm: 1 } : { isShiny: true, hm: 1.2 + 0.3 * Math.random() }; };

  // ------------------------------------------------------------------ enemy creation (Birb createSpawnedEnemy)
  const RANGE = { "flower-monster": 22, harpy: 34, "ice-harpy": 34, witch: 220, anubis: 280, "anubis-warrior": 180, "fishfolk-archpriest": 170, imp: 260, cacodaemon: 270, cultist: 0, "the-archivist": 68,
    "giant-black-pudding": 74, "arctic-whisper": 42, "frozy-cube": 36, "frosty-slime": 68, "ice-fire-guardian": 40, "frogfolk-wizard": 46, "frogfolk-brute": 52, "frogfolk-chieftain": 60, "fishfolk-brute": 38, "fishfolk-horror": 38 };
  const R34 = ["cobra", "ghoul", "skeleton-warrior", "mummy", "fishfolk-whipe", "fishfolk-inkbender", "fishfolk-pugilist", "sea-horror", "sea-gramlin", "elemental", "frost-wisp", "ghost", "doppelganger", "black-pudding", "hell-critter", "cultist-brute"];
  for (const t of R34) RANGE[t] = 34;
  let nextId = 1;
  X.createEnemy = function (s, run, type, x, y, st, mapId, respawnKey) {
    const floor = X.MAP_FLOOR[mapId] || run.currentFloor, H = X.depthRatio(mapId, x, y);
    const Q = X.depthHealthAt(type, st.health, H, floor, Math.random());
    const Y = X.attackFromLife(st.attack, st.health, Q, st.isBoss);
    const G = X.floorSpScale(X.spReward(type, Q, st.health, st.skillPointReward, st.isBoss, floor, H), floor, H);
    const V = X.rollShiny(s, type, G), hp = V.isShiny ? X.roundHealth(Q * V.hm) : Q;
    const e = { id: "enemy_" + nextId++, type, x, y, targetX: x, targetY: y, speed: st.speed, health: hp, maxHealth: hp, attack: Y, defense: st.defense,
      isShiny: V.isShiny || undefined, shinyHealthMultiplier: V.isShiny ? V.hm : undefined, xpReward: st.xpBase, skillPointReward: G, attackCooldown: 0,
      attackRange: RANGE[type] ?? 40, hitFlash: 0, animFrame: 0, animTimer: 0, facingRight: Math.random() > 0.5, state: type === "flower-monster" ? "hide" : "idle", roamTimer: 0,
      isBoss: !!st.isBoss, respawnKey, originalX: x, originalY: y, groupCenterX: x, groupCenterY: y };
    if (type === "flower-monster") e.flowerEmerged = false;
    if (type === "zombie-cultist") { e.state = "respawn"; e.attackCooldown = 1.1; } // Birb: night cultists rise first
    if (type === "anubis") Object.assign(e, { anubisAction: "", anubisAttackSide: "right", anubisAnkhCooldown: 1.6, anubisCoffinCooldown: 6.8, anubisActionApplied: false, anubisCoffinPhase: "", anubisCoffinFrame: 0, anubisCoffinSpawned: false });
    if (type === "anubis-warrior") e.anubisWarriorAttackMode = "range";
    if (type === "doppelganger") e.doppelgangerForm = "human";
    if (type === "fishfolk-archpriest") Object.assign(e, { archpriestAttackMode: "damage", archpriestHealCooldown: 2.6 });
    if (type === "fishfolk-brute") e.fishfolkBruteAttackStage = "windup";
    if (type === "fishfolk-pugilist") Object.assign(e, { fishfolkPugilistAttackMode: "left", fishfolkPugilistNextSide: "right", fishfolkPugilistSuccessfulHits: 0, fishfolkPugilistSpecialReady: false });
    if (type === "elemental") Object.assign(e, { elementalAttackMode: "normal", elementalSpecialCooldown: 4.5, elementalSpecialLastHitFrame: -1, elementalOrbitAngle: Math.random() * Math.PI * 2 });
    if (type === "black-pudding" || type === "giant-black-pudding") e.blackPuddingAttackMode = "attack";
    if (type === "cultist") Object.assign(e, { cultistRitualTimer: 5.5 + 3 * Math.random(), cultistSacrificeTimer: 0, cultistSacrificeApplied: false });
    if (type === "the-archivist") Object.assign(e, { archivistPhase: "dormant", archivistTransformationTimer: 0, archivistSacrificesReceived: 0, archivistAttackMode: "attack1", state: "idle" });
    X.applyPersistentRespawn(s, e);
    return e;
  };
  X.applyElite = function (e) { // Birb applyEliteHalfBossBonus
    const dead = e.health <= 0 && (e.respawnTimer ?? 0) > 0;
    e.maxHealth = X.roundHealth(e.maxHealth * K.ELITE.health); if (!dead) e.health = e.maxHealth;
    e.attack = Math.max(1, Math.round(e.attack * K.ELITE.attack)); e.speed = Math.max(1, Math.round(e.speed * K.ELITE.speed));
    e.xpReward = Math.max(0, Math.round(e.xpReward * K.ELITE.xp)); e.skillPointReward = Math.max(1, Math.round(e.skillPointReward * K.ELITE.skillPoints)); e.isElite = true;
  };
  // Birb rescaleEnemyStatsForDepthPosition: after an enemy is moved to another depth band
  X.rescale = function (s, e, mapId, floor) {
    if (!e || e.type === "mini-fly") return; const i = X.enemyStats(e.type, floor, e.isBoss); if (!i) return;
    const a = X.depthRatio(mapId, e.originalX ?? e.x, e.originalY ?? e.y), r = X.depthHealthAt(e.type, i.health, a, floor, Math.random());
    const sh = e.isShiny ? X.roundHealth(r * Math.max(1, +e.shinyHealthMultiplier || 1.2)) : r, o = e.isElite ? X.roundHealth(sh * K.ELITE.health) : sh;
    const l = Math.max(1, +e.maxHealth || +e.health || 1), c = Math.max(0, +e.health || 0), d = Math.max(0, Math.min(1, c / l));
    e.maxHealth = o; e.health = c > 0 ? Math.max(1, Math.round(o * d)) : 0;
    const h = X.attackFromLife(i.attack, i.health, r, e.isBoss); e.attack = e.isElite ? Math.max(1, Math.round(h * K.ELITE.attack)) : h;
    const m = X.floorSpScale(X.spReward(e.type, r, i.health, i.skillPointReward, e.isBoss, floor, a), floor, a);
    e.skillPointReward = e.isElite ? Math.max(1, Math.round(m * K.ELITE.skillPoints)) : m;
  };
  X.rerollShinyOnRespawn = function (s, e, mapId, floor) {
    const i = X.enemyStats(e.type, floor, e.isBoss), base = i ? X.depthHealthAt(e.type, i.health, X.depthRatio(mapId, e.originalX ?? e.x, e.originalY ?? e.y), floor, Math.random()) : X.roundHealth(Math.max(1, e.maxHealth) / (e.isShiny ? Math.max(1, e.shinyHealthMultiplier || 1.2) : 1));
    const v = X.rollShiny(s, e.type, e.skillPointReward); e.isShiny = v.isShiny || undefined; e.shinyHealthMultiplier = v.isShiny ? v.hm : undefined;
    const o = v.isShiny ? X.roundHealth(base * v.hm) : base; e.maxHealth = e.isElite ? X.roundHealth(o * K.ELITE.health) : o;
  };

  // ------------------------------------------------------------------ respawn cooldowns (Birb enemyRespawnCooldowns: boss / elite keys survive runs)
  X.respawnKey = (kind, mapId, floor, tag) => `${kind}:${mapId}:${floor}:${tag}`;
  X.bossKey = (mapId, floor) => X.respawnKey("boss", mapId, floor, "primary");
  X.effectiveRespawn = (s, sec) => { const t = Math.max(0, +sec || 0); return t <= 0 ? 0 : X.rebirbs(s) >= 2 ? 0.5 * t : t; };
  X.respawnVariance = (sec) => (sec <= 0 ? 0 : sec * (0.8 + Math.random() * 0.4));
  const cds = (s) => PT.expState(s).enemyRespawnCooldowns;
  X.deadline = (s, e) => { const t = Math.floor(+e.respawnAt || 0); if (t > 0) return t; if (!e.respawnKey) return 0; const i = Math.floor(+cds(s)[e.respawnKey] || 0); if (i > 0) e.respawnAt = i; return i; };
  X.remaining = (s, e) => { const t = X.deadline(s, e); if (t <= 0) return 0; const n = (t - Date.now()) / 1e3; if (n <= 0) { X.clearCooldown(s, e); return 0; } return n; };
  X.setCooldown = (s, e, sec) => { const i = Math.max(0, +sec || 0); if (i <= 0) return X.clearCooldown(s, e); const a = Date.now() + Math.floor(1e3 * i); e.respawnAt = a; if (e.respawnKey) cds(s)[e.respawnKey] = a; };
  X.setRetry = (s, e, sec) => { e.respawnTimer = sec; if (!e.respawnKey) { e.respawnAt = undefined; return; } const a = Date.now() + Math.floor(1e3 * sec); e.respawnAt = a; cds(s)[e.respawnKey] = a; };
  X.clearCooldown = (s, e) => { e.respawnAt = undefined; if (e.respawnKey) delete cds(s)[e.respawnKey]; };
  X.advanceRespawn = (s, e, dt) => { if (e.respawnKey) { const t = X.remaining(s, e); e.respawnTimer = t > 0 ? t : 0; return e.respawnTimer; } if (e.respawnTimer === undefined) return null; e.respawnTimer -= dt; return e.respawnTimer; };
  X.applyPersistentRespawn = (s, e) => { const t = X.remaining(s, e); if (t <= 0) return; e.health = 0; e.respawnTimer = t; e.respawnAt = X.deadline(s, e) || undefined; e.xpGranted = true; e.spawnedDeadFromCooldown = true; e.state = "idle"; };
  X.primeOnKill = function (s, e) { // Birb primePersistentRespawnCooldownOnKill
    if (!e || e.health > 0) return;
    if (e.type === "the-archivist") return X.finalizeArchivist && X.finalizeArchivist(s, e);
    if (e.respawnTimer === undefined) { if (e.isBoss) X.setCooldown(s, e, X.effectiveRespawn(s, K.BOSS_RESPAWN)); else if (e.isElite) X.setCooldown(s, e, X.effectiveRespawn(s, K.ELITE_RESPAWN)); }
  };
  X.normalizeCooldowns = (s) => { const n = Date.now(), c = cds(s); for (const k of Object.keys(c)) if (!(Math.floor(+c[k]) > n)) delete c[k]; };
  X.collapseBossCooldowns = function (s, mapId, floor) {
    const c = cds(s), pre = X.respawnKey("boss", mapId, floor, ""), key = X.bossKey(mapId, floor), now = Date.now(); let m = 0;
    for (const [k, v] of Object.entries(c)) if (k.startsWith(pre) && Math.floor(+v) > now) m = Math.max(m, Math.floor(+v));
    for (const k of Object.keys(c)) if (k.startsWith(pre) && k !== key) delete c[k];
    if (m > now) c[key] = m; else delete c[key];
    return m;
  };
  X.clearBossCooldowns = (s, mapId, floor) => { const pre = X.respawnKey("boss", mapId, floor, ""); for (const k of Object.keys(cds(s))) if (k.startsWith(pre)) delete cds(s)[k]; };
  X.applyRespawnedState = function (e) { // Birb applyRespawnedEnemyState
    e.elvenAssassin = undefined; e.zombieCultist = undefined; e.guardianBoss = undefined;
    e.animFrame = 0; e.animTimer = 0; e.attackCooldown = 0; e.isLeashing = false; e.archivistSpells = undefined;
    if (e.type === "zombie-cultist") { e.state = "respawn"; e.attackCooldown = 1.1; return; }
    if (e.type === "flower-monster") { e.flowerEmerged = false; e.state = "hide"; }
    else if (e.type === "frost-wisp" || e.type === "ghost") { e.state = "respawn"; e.attackCooldown = 0.55; }
    else if (e.type === "giant-black-pudding") { e.state = "respawn"; e.attackCooldown = 1.35; }
    else if (e.type === "the-archivist") Object.assign(e, { archivistPhase: "dormant", archivistTransformationTimer: 0, archivistSacrificesReceived: 0, archivistAttackMode: "attack1", state: "idle" });
    else e.state = "idle";
  };
  X.returnsToSpawn = (e) => ["hell-critter", "imp", "cacodaemon", "cultist-brute", "the-archivist"].includes(e.type);
  X.respawnPos = (e) => ({ x: e.originalX ?? e.groupCenterX ?? e.x, y: e.originalY ?? e.groupCenterY ?? e.y });
  // Birb reconcileRunMapBossState: a boss killed on an earlier run stays dead until its cooldown ends
  X.reconcileBoss = function (s, run, mapId, floor) {
    if (floor === 9 && X.archivistDefeated(s)) { run.enemies = run.enemies.filter((e) => !(e.cultistArchivistId || (e.type === "the-archivist" && (e.health > 0 || e.xpGranted)))); X.clearBossCooldowns(s, mapId, floor); return; }
    const key = X.bossKey(mapId, floor), now = Date.now(), r = X.collapseBossCooldowns(s, mapId, floor), sOn = r > now;
    const dead = run.enemies.filter((e) => e.isBoss && e.health <= 0 && ((e.respawnTimer ?? 0) > 0 || sOn));
    if (run.enemies.some((e) => e.isBoss && e.health > 0)) {
      if (dead.length <= 0 && r <= now) return;
      run.enemies = run.enemies.filter((e) => !e.isBoss || e.health > 0 || (X.clearCooldown(s, e), false)); X.clearBossCooldowns(s, mapId, floor); return;
    }
    const l = dead.reduce((m, e) => { const n = Math.max(0, +e.respawnTimer || 0); return n <= 0 ? m : Math.max(m, now + Math.ceil(1e3 * n)); }, 0), c = Math.max(r, l);
    if (c <= now) return;
    let kept = false;
    run.enemies = run.enemies.filter((e) => !e.isBoss || e.health > 0 || (!!((e.respawnTimer ?? 0) > 0 || sOn) && (kept ? (X.clearCooldown(s, e), false) : ((kept = true), (e.respawnKey = key), (e.respawnTimer = Math.max(0, (c - now) / 1e3)), (e.spawnedDeadFromCooldown = true), true))));
    cds(s)[key] = c;
  };
  X.bossOnCooldown = (run) => run.enemies.some((e) => e.isBoss && e.health <= 0 && (e.respawnTimer ?? 0) > 0);
  // Birb syncNextFloorPortalWithBossCooldown: the next-floor portal opens while the boss is down
  X.syncExitPortal = function (run, mapId) {
    if (!X.isRunMap(mapId) || (!run.nightMode && run.currentFloor >= K.MAX_FLOOR) || !X.bossOnCooldown(run)) { run.exitPortal = null; return; }
    const n = X.portal(mapId, "next_floor"), b = run.enemies.find((e) => e.isBoss);
    run.exitPortal = { x: n?.x ?? b?.x ?? 0, y: n?.y ?? b?.y ?? 0, active: true };
  };

  // ------------------------------------------------------------------ spawn geometry (Birb clampToBounds / collision checks / spawn point search)
  const clamp = (x, y, b, i = 80) => ({ x: Math.max(b.minX + i, Math.min(b.maxX - i, x)), y: Math.max(b.minY + i, Math.min(b.maxY - i, y)) });
  X.clamp = clamp;
  const farFrom = (x, y, pts, d) => { if (d <= 0 || !pts.length) return true; const a = d * d; for (const p of pts) if ((x - p.x) ** 2 + (y - p.y) ** 2 < a) return false; return true; };
  X.spawnBlocked = function (mapId, x, y) {
    const i = 0.5 * K.SPAWN_COLL_W, a = x - i, r = y - K.SPAWN_COLL_H, s2 = x + i;
    for (const l of X.collisions(mapId)) if (s2 > l.left && a < l.right && y > l.top && r < l.bottom) return true;
    return false;
  };
  X.occupied = function (run, x, y, d, exclude) {
    if (d <= 0) return false; const r = d * d;
    for (const e of run.enemies) { if (!e || (exclude && e.id === exclude) || e.health <= 0 || e.projectileKind || e.state === "death") continue; if ((x - e.x) ** 2 + (y - e.y) ** 2 < r) return true; }
    return false;
  };
  X.safePoint = function (mapId, x, y, b, rng) {
    const r = b ? clamp(x, y, b, 96) : { x, y };
    if (!X.spawnBlocked(mapId, r.x, r.y)) return r;
    for (let d = 0; d < 84; d++) {
      const t = 1 + Math.floor(d / 12), n = 20 + 18 * t, a = rng ? rng() * Math.PI * 2 : ((d % 12) / 12) * Math.PI * 2 + 0.35 * t;
      let o = r.x + Math.cos(a) * n, l = r.y + Math.sin(a) * n;
      if (b) ({ x: o, y: l } = clamp(o, l, b, 96));
      if (!X.spawnBlocked(mapId, o, l)) return { x: o, y: l };
    }
    if (!b) return null;
    const R = rng || Math.random;
    for (let d = 0; d < 80; d++) { const n = b.minX + 96 + (b.maxX - b.minX - 192) * R(), i = b.minY + 96 + (b.maxY - b.minY - 192) * R(); if (!X.spawnBlocked(mapId, n, i)) return { x: n, y: i }; }
    return null;
  };
  X.safeFreePoint = function (run, mapId, x, y, b, opt = {}) {
    const rng = opt.rng, d0 = Math.max(0, +opt.minDistance || K.SPAWN_MIN), ex = opt.excludeEnemyId, R = rng || Math.random;
    const c = X.safePoint(mapId, x, y, b, rng); if (!c) return null;
    if (!X.occupied(run, c.x, c.y, d0, ex)) return c;
    const d = b ? clamp(c.x, c.y, b, 96) : c;
    for (let g = 0; g < 120; g++) {
      const t = 1 + Math.floor(g / 12), n = Math.max(d0, 10) + t * Math.max(10, Math.floor(0.65 * d0)), a = R() * Math.PI * 2;
      let cx = d.x + Math.cos(a) * n, cy = d.y + Math.sin(a) * n; if (b) ({ x: cx, y: cy } = clamp(cx, cy, b, 96));
      const h = X.safePoint(mapId, cx, cy, b, rng); if (h && !X.occupied(run, h.x, h.y, d0, ex)) return h;
    }
    if (!b) return null;
    for (let g = 0; g < 120; g++) { const t = b.minX + 96 + (b.maxX - b.minX - 192) * R(), n = b.minY + 96 + (b.maxY - b.minY - 192) * R(), a = X.safePoint(mapId, t, n, b, rng); if (a && !X.occupied(run, a.x, a.y, d0, ex)) return a; }
    return null;
  };
  X.bandCenterPoint = function (mapId, b, band, pts, minD, zones = [], rng = Math.random) {
    const o = b.maxX - b.minX, l = b.maxY - b.minY, c = X.bandCenter(band), d = Math.max(30, 0.08 * l);
    for (let u = 0; u < 220; u++) {
      const x = b.minX + o * (0.18 + 0.64 * rng()), y = X.depthY(mapId, c) + (rng() - 0.5) * d * 2, p = clamp(x, y, b, 90), h = X.safePoint(mapId, p.x, p.y, b, rng);
      if (h && farFrom(h.x, h.y, pts, minD) && !inZones(h.x, h.y, zones)) return h;
    }
    return null;
  };
  X.proceduralPoint = function (mapId, rng, b, used, minD, avoidR, centers = [], centerMin = 0, zones = []) {
    const c = b.minX + 96, d = b.maxX - 96, u = b.minY + 96, h = b.maxY - 96, px = 0.5 * (b.minX + b.maxX), py2 = 0.5 * (b.minY + b.maxY);
    for (let i = 0; i < 240; i++) {
      const x = c + (d - c) * rng(), y = u + (h - u) * rng();
      if ((x - px) ** 2 + (y - py2) ** 2 < avoidR * avoidR || inZones(x, y, zones)) continue;
      if (used.some((e) => (x - e.x) ** 2 + (y - e.y) ** 2 < minD * minD)) continue;
      if (centerMin > 0 && centers.some((e) => (x - e.x) ** 2 + (y - e.y) ** 2 < centerMin * centerMin)) continue;
      if (!X.spawnBlocked(mapId, x, y)) return { x, y };
    }
    return null;
  };
  X.memberPoint = function (mapId, center, b, rnd, used, zones, minR, maxR) {
    const l = Math.max(4, minR), c = Math.max(l + 1, maxR);
    for (let d = 0; d < 36; d++) {
      const a = rnd(d) * Math.PI * 2, r = l + (c - l) * rnd(d + 9973), g = clamp(center.x + Math.cos(a) * r, center.y + Math.sin(a) * r, b, 96), f = X.safePoint(mapId, g.x, g.y, b);
      if (f && !inZones(f.x, f.y, zones) && farFrom(f.x, f.y, used, K.SPAWN_MIN)) return f;
    }
    return null;
  };
  X.seeded = (seed) => { let t = seed >>> 0 || 1; return () => ((t = (1664525 * t + 1013904223) >>> 0), t / 4294967296); };
  // Birb ST / CT: front-line, ranged and support roles keep groups mixed
  X.role = (t) => (/archpriest|witch|wizard/.test(t) ? "support" : /imp|cacodaemon|anubis$|giant-fly|elemental|frost-wisp/.test(t) ? "ranged" : "front");
  const mixRoles = (pool, chosen) => { const n = new Set(chosen.map(X.role)), i = pool.filter((e) => !n.has(X.role(e))); return i.length ? i : pool; };
  X.groupComposition = function (floor, lead, size, pool, rng, remaining) {
    const s = Math.max(0, Math.floor(size)); if (s <= 0) return [];
    const o = plan(floor).diversity;
    if (!o) { const e = remaining?.get(lead) ?? s; return Array.from({ length: Math.min(s, Math.max(0, e)) }, () => lead); }
    const l = [...new Set(pool)].filter((e) => !!X.baseStats(e)); if (!l.includes(lead) && X.baseStats(lead)) l.unshift(lead);
    const c = [], d = new Map(), left = (e) => { const t = remaining?.get(e); return t === undefined ? Infinity : Math.max(0, t - (d.get(e) || 0)); }, add = (e) => { c.push(e); d.set(e, (d.get(e) || 0) + 1); };
    if (left(lead) > 0) add(lead);
    while (c.length < s) {
      let e = l.filter((t) => left(t) > 0 && (d.get(t) || 0) < o.maxSameType); if (!e.length) break;
      if (d.size < o.minDistinctTypes) { const t = e.filter((x) => !d.has(x)); if (t.length) e = t; } else { const t = Math.min(...e.map((x) => d.get(x) || 0)); e = e.filter((x) => (d.get(x) || 0) === t); }
      e = mixRoles(e, c); add(e[Math.floor(rng() * e.length)] || e[0]);
    }
    return c;
  };

  // ------------------------------------------------------------------ floor population (Birb spawnProceduralEnemiesForMap + the enforce / ensure passes)
  const procAvoid = (f) => (f <= 1 ? 80 : f === 2 ? 96 : f === 3 ? 108 : 120);
  const procGroupMin = (f) => K.PROC_GROUP_MIN + (f <= 1 ? 0 : f === 2 ? 20 : f === 3 ? 30 : 40);
  const guardMin = (f) => K.DEPTH_GUARD_MIN + (f <= 1 ? 0 : f === 2 ? 20 : f === 3 ? 30 : 40);
  const coverageSize = (f) => (f <= 1 ? [2, 3] : f === 2 ? [2, 4] : f === 3 || f === 4 ? [2, 3] : [3, 5]);
  const POOL = (f) => (X.nightRun() && f === 1 ? [...X.NIGHT_POOL] : f <= 1 ? ["masked-forest-spirit", "twig-blight", "flower-monster"] : f === 2 ? ["harpy", "cobra", "skeleton-warrior"] : f === 3 ? ["mummy", "anubis-warrior"] : f >= 9 ? ["hell-critter", "imp", "cacodaemon", "cultist-brute"] : f >= 8 ? ["black-pudding", "ghost"] : f >= 7 ? ["frogfolk-wizard", "frogfolk-brute", "giant-fly"] : f >= 6 ? ["frost-wisp", "arctic-whisper", "ice-harpy", "frozy-cube"] : f >= 5 ? ["fishfolk-pugilist", "sea-horror", "sea-gramlin", "elemental"] : ["fishfolk-whipe", "fishfolk-inkbender"]);
  const COVERAGE_POOL = (f) => (X.nightRun() && f === 1 ? [...X.NIGHT_POOL] : f <= 1 ? ["twig-blight", "masked-forest-spirit", "flower-monster"] : POOL(f));
  X.spawnProcedural = function (s, run, mapId, floor) {
    const P = plan(floor), b = X.bounds(mapId), zones = X.portalZones(mapId), avoid = procAvoid(floor), gmin = procGroupMin(floor);
    const nonce = run.floorResetNonce || 0;
    const seed = ((Math.floor((run.startTime || Date.now()) / 1e3) >>> 0) ^ ((83492791 * nonce) >>> 0) ^ ((73856093 * mapId) >>> 0) ^ ((19349663 * floor) >>> 0)) >>> 0;
    const rng = X.seeded(seed), used = [], centers = [], perBand = [0, 0, 0, 0, 0], typeBands = new Map(), priest = floor === 4 ? X.enemyStats("fishfolk-archpriest", floor, false) : null;
    let priestUsed = false;
    const left = new Map(); for (const [t, n] of P.packs) left.set(t, (left.get(t) || 0) + Math.max(0, n));
    const bossSt = X.baseStats(P.boss) ? X.enemyStats(P.boss, floor, true) : null;
    if (bossSt && !(floor === 9 && X.archivistDefeated(s))) {
      const x = b.minX + (b.maxX - b.minX) * (0.4 + 0.2 * rng()), y = X.depthY(mapId, 1 - (96 + 120 * rng()) / (b.maxY - b.minY)), o = X.safePoint(mapId, x, y, b, rng);
      if (o && !inZones(o.x, o.y, zones)) { run.enemies.push(X.createEnemy(s, run, P.boss, o.x, o.y, bossSt, mapId, X.bossKey(mapId, floor))); used.push({ ...o }); centers.push({ ...o }); perBand[X.band(X.depthRatio(mapId, o.x, o.y))]++; }
    }
    for (const [type] of P.packs) {
      if (!X.baseStats(type)) continue;
      const tb = typeBands.get(type) || new Set(); typeBands.set(type, tb);
      if (type === "doppelganger") {
        let a = Math.min(left.get(type) || 0, 5);
        for (const band of [0, 1, 2, 3, 4].filter((e) => !tb.has(e)).sort((x, y) => perBand[x] - perBand[y])) {
          if (a <= 0) break;
          const o = X.bandCenterPoint(mapId, b, band, centers, Math.max(150, gmin), zones, rng); if (!o) continue;
          run.enemies.push(X.createEnemy(s, run, type, o.x, o.y, X.enemyStats(type, floor, false), mapId)); used.push({ ...o }); centers.push({ ...o }); tb.add(band); perBand[band]++; left.set(type, Math.max(0, (left.get(type) || 0) - 1)); a--;
        }
        continue;
      }
      const [gmn, gmx] = P.group; let n = left.get(type) || 0, idx = 0;
      while (n > 0) {
        const x = gmn + Math.floor(rng() * (gmx - gmn + 1)), pool = P.packs.map((p) => p[0]).filter((t) => (left.get(t) || 0) > 0 && t !== "doppelganger" && X.baseStats(t));
        const total = pool.reduce((m, t) => m + (left.get(t) || 0), 0), size = Math.min(total, Math.max(1, x)), comp = X.groupComposition(floor, type, size, pool, rng, left);
        if (!comp.length) break;
        const all = [0, 1, 2, 3, 4], free = all.filter((e) => !tb.has(e)), order = (free.length ? free : all).sort((x2, y2) => perBand[x2] - perBand[y2]);
        let I = null, B = -1;
        for (const band of order) { const c = X.bandCenterPoint(mapId, b, band, centers, Math.max(120, gmin), zones, rng); if (c) { I = c; B = band; break; } }
        if (!I) { I = X.proceduralPoint(mapId, rng, b, used, 120, avoid, centers, gmin, zones); if (I) B = X.band(X.depthRatio(mapId, I.x, I.y)); }
        if (!I) break;
        const gid = `pack_${floor}_${idx++}_${Math.floor(1e5 * rng())}`, withPriest = !!priest && floor === 4 && type !== "fishfolk-archpriest" && comp.length > 1 && (!priestUsed || rng() < 0.42);
        let placed = 0; const types = new Set();
        for (let i = 0; i < comp.length; i++) {
          const pt = X.memberPoint(mapId, I, b, () => rng(), used, zones, floor === 4 ? 28 : 18, floor === 4 ? 92 : 62); if (!pt) continue;
          const o = comp[i] || type, last = withPriest && i === comp.length - 1, t2 = last ? "fishfolk-archpriest" : o, st = last ? priest : X.enemyStats(t2, floor, false); if (!st) continue;
          const e = X.createEnemy(s, run, t2, pt.x, pt.y, st, mapId); e.groupId = gid; e.groupCenterX = I.x; e.groupCenterY = I.y; run.enemies.push(e); used.push({ ...pt });
          if (last) priestUsed = true; left.set(o, Math.max(0, (left.get(o) || 0) - 1)); types.add(t2); placed++;
        }
        if (placed <= 0) break;
        centers.push({ x: I.x, y: I.y });
        if (B >= 0) { for (const t2 of types) { const set = typeBands.get(t2) || new Set(); set.add(B); typeBands.set(t2, set); } perBand[B]++; }
        n = left.get(type) || 0;
      }
    }
  };
  X.ensureBoss = function (s, run, mapId, floor) {
    if (floor === 9 && X.archivistDefeated(s)) return;
    if (run.enemies.some((e) => e.isBoss && (e.health > 0 || (e.respawnTimer ?? 0) > 0))) return;
    const type = plan(floor).boss, st = X.enemyStats(type, floor, true); if (!st) return;
    const b = X.bounds(mapId), arch = floor === 9 ? DATA.archivistCenter : null, c = arch || { x: b.minX + (b.maxX - b.minX) / 2, y: X.depthY(mapId, 1 - 144 / (b.maxY - b.minY)) };
    const d = arch || X.safeFreePoint(run, mapId, c.x, c.y, b, { minDistance: K.SPAWN_MIN }) || X.safeFreePoint(run, mapId, c.x, c.y, b, { minDistance: 18 }) || X.safeFreePoint(run, mapId, c.x, c.y, b, { minDistance: 0 }) || X.safePoint(mapId, c.x, c.y, b);
    if (d) run.enemies.push(X.createEnemy(s, run, type, d.x, d.y, st, mapId, X.bossKey(mapId, floor)));
  };
  X.ensureDepthCoverage = function (s, run, mapId, floor) {
    const b = X.bounds(mapId), zones = X.portalZones(mapId), cfg = X.floorConfig(floor), minGroups = cfg.minimumGroupsPerBand, cap = cfg.maximumRegularsPerBand, target = Math.min(cap, cfg.coverageTargetPerBand);
    const [smin, smax] = coverageSize(floor), gmin = guardMin(floor), priest = floor === 4 ? X.enemyStats("fishfolk-archpriest", floor, false) : null;
    const bands = Array.from({ length: 5 }, () => ({ enemies: [], count: 0 })), centers = Array.from({ length: 5 }, () => []), seen = Array.from({ length: 5 }, () => new Set());
    for (const e of run.enemies) {
      if (e.health <= 0 || e.type === "mini-fly" || e.isBoss || e.isElite) continue;
      const n = X.band(X.depthRatio(mapId, e.originalX ?? e.x, e.originalY ?? e.y)); bands[n].enemies.push(e); bands[n].count++;
      const g = e.groupId || "solo_" + e.id; if (!seen[n].has(g)) { seen[n].add(g); centers[n].push({ x: e.groupCenterX ?? e.originalX ?? e.x, y: e.groupCenterY ?? e.originalY ?? e.y }); }
    }
    const groupSizes = (list) => { const m = new Map(); for (const e of list) { const g = e.groupId || "solo_" + e.id; m.set(g, (m.get(g) || 0) + 1); } return m; };
    const groupTypes = (list) => { const m = new Map(); for (const e of list) { const g = e.groupId || "solo_" + e.id; if (!m.has(g)) m.set(g, e.type); } return m; };
    const leastType = (list, opts) => { if (!opts.length) return null; const n = new Map(); for (const e of list) n.set(e.type, (n.get(e.type) || 0) + 1); let lo = Infinity, a = []; for (const r of opts) { const c = n.get(r) || 0; if (c < lo) { lo = c; a = [r]; } else if (c === lo) a.push(r); } return a[Math.floor(Math.random() * a.length)] || a[0] || null; };
    for (let y = 0; y < 5; y++) {
      const p = bands[y], pool = COVERAGE_POOL(floor).filter((t) => X.baseStats(t)); if (!pool.length) continue;
      for (let guard = 0; guard++ < 24;) {
        const u = groupSizes(p.enemies), A = groupTypes(p.enemies), needGroups = u.size < minGroups, needCount = p.count < target;
        if (!needGroups && !needCount) break;
        const have = new Set(A.values()), fresh = pool.filter((t) => !have.has(t)), C = leastType(p.enemies, fresh.length ? fresh : pool);
        if (!C || !X.enemyStats(C, floor, false)) break;
        const E = cap - p.count;
        if (E <= 0) {
          const per = new Map(); for (const t of A.values()) per.set(t, (per.get(t) || 0) + 1);
          let r = null, fall = null;
          for (const e of p.enemies) { const g = e.groupId || "solo_" + e.id; if ((u.get(g) || 0) <= 1) continue; fall ||= e; const t = A.get(g); if (t && (per.get(t) || 0) > 1) { r = e; break; } }
          const sp = r || fall; if (!sp) break;
          const o = X.bandCenterPoint(mapId, b, y, centers[y], gmin, zones); if (!o) break;
          Object.assign(sp, { x: o.x, y: o.y, targetX: o.x, targetY: o.y, originalX: o.x, originalY: o.y, groupId: `depth_split_${floor}_${y}_${Math.floor(1e5 * Math.random())}`, groupCenterX: o.x, groupCenterY: o.y });
          X.rescale(s, sp, mapId, floor); centers[y].push({ ...o }); continue;
        }
        const k = Math.max(0, minGroups - u.size), T = needGroups ? Math.max(0, k - 1) : 0, I = Math.max(1, E - T), Bm = Math.min(smax, I), Fm = Math.min(smin, Bm);
        const R = Fm + Math.floor(Math.random() * (Bm - Fm + 1)), comp = X.groupComposition(floor, C, R, pool, Math.random), withPriest = !!priest && floor === 4 && C !== "fishfolk-archpriest" && comp.length > 1 && Math.random() < 0.38;
        const L = X.bandCenterPoint(mapId, b, y, centers[y], gmin, zones); if (!L) break;
        const gid = `depth_guard_${floor}_${y}_${Math.floor(1e5 * Math.random())}`; let placed = 0;
        for (let r = 0; r < comp.length; r++) {
          const off = 1e6 * Math.random(), o = X.memberPoint(mapId, L, b, (e) => { const t = 0.21 * (r + 1) + 0.17 * e + off; return t - Math.floor(t); }, run.enemies, zones, floor === 4 ? 26 : 16, floor === 4 ? 86 : 58);
          if (!o) continue;
          const last = withPriest && r === comp.length - 1, t2 = last ? "fishfolk-archpriest" : comp[r] || C, st = last ? priest : X.enemyStats(t2, floor, false); if (!st) continue;
          const e = X.createEnemy(s, run, t2, o.x, o.y, st, mapId); e.groupId = gid; e.groupCenterX = L.x; e.groupCenterY = L.y; run.enemies.push(e); p.enemies.push(e); p.count++; placed++;
        }
        if (placed <= 0) break;
        centers[y].push({ x: L.x, y: L.y });
      }
    }
  };
  X.enforcePopulationCap = function (run, mapId, floor) {
    const r = Math.max(1, X.floorConfig(floor).maximumRegularsPerBand), by = new Map(), prio = (e) => (e.isBoss ? 100 : e.isElite ? 80 : e.leaderId ? 40 : 60);
    run.enemies.forEach((e, i) => { if (e.type === "mini-fly") return; const a = X.band(X.depthRatio(mapId, e.originalX ?? e.x, e.originalY ?? e.y)); (by.get(a) || by.set(a, []).get(a)).push({ e, i }); });
    const drop = new Set();
    for (const l of by.values()) { if (l.length <= r) continue; const keep = new Set([...l].sort((a, b) => prio(b.e) - prio(a.e) || a.i - b.i).slice(0, r).map((x) => x.e.id)); for (const x of l) if (!keep.has(x.e.id)) drop.add(x.e.id); }
    if (drop.size) run.enemies = run.enemies.filter((e) => !drop.has(e.id));
  };
  X.spawnElites = function (s, run, mapId, floor) {
    const b = X.bounds(mapId), pool = POOL(floor).filter((t) => X.baseStats(t)), priest = floor === 4 ? X.enemyStats("fishfolk-archpriest", floor, false) : null; if (!pool.length) return;
    const n = X.floorConfig(floor).eliteLeaderGroups, w = b.maxX - b.minX, ly = X.depthY(mapId, 0.56), centers = [], seen = new Set(); let made = 0;
    for (const e of run.enemies) { if (e.health <= 0 || e.type === "mini-fly") continue; const g = e.groupId || "solo_" + e.id; if (!seen.has(g)) { seen.add(g); centers.push({ x: e.groupCenterX ?? e.originalX ?? e.x, y: e.groupCenterY ?? e.originalY ?? e.y }); } }
    for (let y = 0; y < n; y++) {
      const type = pool[y % pool.length], st = X.enemyStats(type, floor, false); if (!st) continue;
      let p = null;
      for (const minD of [K.ELITE_GROUP_MIN, Math.max(140, K.ELITE_GROUP_MIN - 60), Math.max(90, K.ELITE_GROUP_MIN - 120), 0]) {
        for (let k = 0; k < 120; k++) { const r = clamp(b.minX + ((y + 1) * w) / (n + 1) + 70 * (Math.random() - 0.5), ly + 120 * (Math.random() - 0.5), b, 90), d = X.safeFreePoint(run, mapId, r.x, r.y, b); if (d && (!(minD > 0) || farFrom(d.x, d.y, centers, minD))) { p = d; break; } }
        if (p) break;
      }
      if (!p) continue;
      const gid = `elite_pack_${floor}_${y}_${Math.floor(1e5 * Math.random())}`, withPriest = !!priest && floor === 4 && type !== "fishfolk-archpriest" && (y === 0 || Math.random() < 0.45);
      const A = X.createEnemy(s, run, type, p.x, p.y, st, mapId, X.respawnKey("elite", mapId, floor, "group:" + y)); X.applyElite(A); A.groupId = gid; A.groupCenterX = p.x; A.groupCenterY = p.y; run.enemies.push(A); centers.push({ ...p }); made++;
      const comp = X.groupComposition(floor, type, 3, pool, Math.random);
      for (let a = 0; a < 2; a++) {
        const ang = a === 0 ? 0.82 * Math.PI : 1.18 * Math.PI, r = (floor === 4 ? 64 + 26 * Math.random() : 42 + 16 * Math.random()) * K.GROUP_SPACING, l = clamp(p.x + Math.cos(ang) * r, p.y + Math.sin(ang) * r, b, 90), c = X.safeFreePoint(run, mapId, l.x, l.y, b);
        if (!c) continue;
        const pr = withPriest && a === 0, t2 = pr ? "fishfolk-archpriest" : comp[a + 1] || type, st2 = pr ? priest : X.enemyStats(t2, floor, false); if (!st2) continue;
        const f = X.createEnemy(s, run, t2, c.x, c.y, st2, mapId); f.groupId = gid; f.groupCenterX = p.x; f.groupCenterY = p.y; f.leaderId = A.id; run.enemies.push(f);
      }
    }
    if (made > 0) return;
    const type = pool[0], st = X.enemyStats(type, floor, false); if (!st) return; let m = null;
    for (let k = 0; k < 240 && !m; k++) m = X.safeFreePoint(run, mapId, b.minX + Math.random() * w, b.minY + Math.random() * (b.maxY - b.minY), b);
    if (!m) return;
    const e = X.createEnemy(s, run, type, m.x, m.y, st, mapId, X.respawnKey("elite", mapId, floor, "fallback:0")); X.applyElite(e); e.groupId = `elite_pack_${floor}_fallback_${Math.floor(1e5 * Math.random())}`; e.groupCenterX = m.x; e.groupCenterY = m.y; run.enemies.push(e);
  };
  X.enforceTypeDiversity = function (s, run, mapId, floor) {
    if (floor < 3) return;
    const b = X.bounds(mapId), zones = X.portalZones(mapId), gmin = guardMin(floor), groups = new Map();
    for (const h of run.enemies) {
      if (!h || h.health <= 0 || h.type === "mini-fly" || h.isBoss || h.isElite || h.anubisSummon) continue;
      const k = h.groupId || "solo_" + h.id, g = groups.get(k);
      if (g) g.members.push(h); else groups.set(k, { key: k, type: h.type, members: [h], cx: h.groupCenterX ?? h.originalX ?? h.x, cy: h.groupCenterY ?? h.originalY ?? h.y, band: 0 });
    }
    if (!groups.size) return;
    const list = [...groups.values()];
    for (const g of list) { if (g.members.length > 1) { g.cx = g.members.reduce((m, t) => m + (t.originalX ?? t.x), 0) / g.members.length; g.cy = g.members.reduce((m, t) => m + (t.originalY ?? t.y), 0) / g.members.length; } g.band = X.band(X.depthRatio(mapId, g.cx, g.cy)); }
    const keys = Array.from({ length: 5 }, () => []), pts = Array.from({ length: 5 }, () => []);
    for (const g of list) { keys[g.band].push(g.key); pts[g.band].push({ x: g.cx, y: g.cy }); }
    const typesIn = (i) => new Set(keys[i].map((k) => groups.get(k)?.type).filter(Boolean));
    const move = (g, to) => {
      const o = X.bandCenterPoint(mapId, b, to, pts[to], gmin, zones); if (!o) return false;
      const dx0 = g.cx, dy0 = g.cy;
      for (const a of g.members) { const p = clamp(o.x + (a.x - dx0), o.y + (a.y - dy0), b, 96), l = X.safeFreePoint(run, mapId, p.x, p.y, b, { minDistance: K.SPAWN_MIN + 6, excludeEnemyId: a.id }) || p; Object.assign(a, { x: l.x, y: l.y, targetX: l.x, targetY: l.y, originalX: l.x, originalY: l.y, groupCenterX: o.x, groupCenterY: o.y }); X.rescale(s, a, mapId, floor); }
      keys[g.band] = keys[g.band].filter((k) => k !== g.key); pts[g.band] = pts[g.band].filter((e) => (e.x - dx0) ** 2 + (e.y - dy0) ** 2 > 4);
      g.cx = o.x; g.cy = o.y; g.band = to; keys[to].push(g.key); pts[to].push({ ...o }); return true;
    };
    for (let h = 0; h < 5; h++) {
      const seenT = new Set(), dup = [];
      for (const k of [...keys[h]]) { const g = groups.get(k); if (!g) continue; if (seenT.has(g.type)) dup.push(k); else seenT.add(g.type); }
      for (const k of dup) {
        const g = groups.get(k); if (!g) continue;
        const to = [0, 1, 2, 3, 4].filter((n) => n !== h && !typesIn(n).has(g.type)).sort((x, y) => keys[x].length - keys[y].length || Math.abs(x - h) - Math.abs(y - h));
        for (const t of to) if (move(g, t)) break;
      }
    }
  };
  X.enforceWitchGuards = function (s, run, mapId, floor) {
    if (floor !== 2) return;
    run.enemies = run.enemies.filter((e) => e.type !== "ghoul");
    const w = run.enemies.find((e) => e.type === "witch" && e.isBoss), st = w && X.enemyStats("ghoul", floor, false); if (!w || !st) return;
    const b = X.bounds(mapId), gid = `witch_guard_${floor}_${Math.floor(1e5 * Math.random())}`;
    for (const off of [{ x: -90, y: 12 }, { x: 90, y: 12 }]) {
      const dir = off.x < 0 ? -1 : 1; let placed = false;
      for (let o = 0; o < 12 && !placed; o++) {
        const g = clamp(w.x + off.x + dir * 5 * o + 10 * (Math.random() - 0.5), w.y + off.y + 8 * (Math.random() - 0.5), b, 96), f = X.safeFreePoint(run, mapId, g.x, g.y, b);
        if (!f) continue; const e = X.createEnemy(s, run, "ghoul", f.x, f.y, st, mapId); Object.assign(e, { groupId: gid, groupCenterX: w.x, groupCenterY: w.y, leaderId: w.id }); run.enemies.push(e); placed = true;
      }
      if (!placed) { const l = clamp(w.x + off.x, w.y + off.y, b, 96), e = X.createEnemy(s, run, "ghoul", l.x, l.y, st, mapId); Object.assign(e, { groupId: gid, groupCenterX: w.x, groupCenterY: w.y, leaderId: w.id }); run.enemies.push(e); }
    }
  };
  X.enforceFloor3 = function (s, run, mapId, floor) {
    if (floor !== 3) return;
    // giant flies are capped at 0 on floor 3 (Birb FLOOR3_MAX_GIANT_FLY_COUNT); the plan has none, so only the anubis safety pass matters
    run.enemies = run.enemies.filter((e) => !(e.type === "mini-fly" && !e.projectileKind));
    const a = run.enemies.find((e) => e.type === "anubis" && e.isBoss); if (!a) return;
    const band = X.band(X.depthRatio(mapId, a.originalX ?? a.x, a.originalY ?? a.y));
    run.enemies = run.enemies.filter((t) => t.id === a.id || t.isBoss || t.health <= 0 || t.type === "mini-fly" || X.band(X.depthRatio(mapId, t.originalX ?? t.x, t.originalY ?? t.y)) !== band || (t.x - a.x) ** 2 + (t.y - a.y) ** 2 > 67600);
  };
  X.ensureCultists = function (s, run, mapId, floor) {
    if (X.archivistDefeated(s) || floor !== 9) return;
    const i = run.enemies.find((e) => e.type === "the-archivist" && e.isBoss && e.health > 0); if (!i) return;
    const phase = i.archivistPhase || "dormant", r = DATA.archivistCenter || { x: i.x, y: i.y };
    const ox = Number.isFinite(i.originalX) ? i.originalX : i.x, oy = Number.isFinite(i.originalY) ? i.originalY : i.y, dx = r.x - ox, dy = r.y - oy;
    if (phase !== "active") Object.assign(i, { x: r.x, y: r.y, targetX: r.x, targetY: r.y }); else if (Math.abs(dx) > 0.001 || Math.abs(dy) > 0.001) { i.x += dx; i.y += dy; i.targetX += dx; i.targetY += dy; }
    Object.assign(i, { originalX: r.x, originalY: r.y, groupCenterX: r.x, groupCenterY: r.y });
    const mine = run.enemies.filter((e) => e.type === "cultist" && e.cultistArchivistId === i.id);
    for (const c of mine) { const a = +c.cultistWorshipAngle; if (!Number.isFinite(a)) continue; const t = r.x + Math.cos(a) * K.CULT_RX, n = r.y + Math.sin(a) * K.CULT_RY; if (phase !== "active" || c.health <= 0) Object.assign(c, { x: t, y: n, targetX: t, targetY: n, originalX: t, originalY: n }); c.groupCenterX = r.x; c.groupCenterY = r.y; }
    if (phase !== "dormant") return;
    const alive = mine.filter((e) => e.health > 0), need = Math.max(0, K.CULTISTS - alive.length), st = X.enemyStats("cultist", floor, false); if (need <= 0 || !st) return;
    const b = X.bounds(mapId), taken = new Set(alive.map((e) => Math.round(1e3 * (+e.cultistWorshipAngle || 0)))); let made = 0;
    for (let k = 0; k < K.CULTISTS && made < need; k++) {
      const ang = -Math.PI / 2 + (2 * Math.PI * k) / K.CULTISTS; if (taken.has(Math.round(1e3 * ang))) continue;
      const t = r.x + Math.cos(ang) * K.CULT_RX, a = r.y + Math.sin(ang) * K.CULT_RY, p = X.safePoint(mapId, t, a, b) || { x: Math.max(b.minX, Math.min(b.maxX, t)), y: Math.max(b.minY, Math.min(b.maxY, a)) };
      const o = X.createEnemy(s, run, "cultist", p.x, p.y, st, mapId);
      Object.assign(o, { groupId: "archivist-cultists-" + i.id, leaderId: i.id, groupCenterX: r.x, groupCenterY: r.y, cultistArchivistId: i.id, cultistWorshipAngle: ang, state: "ritual" });
      run.enemies.push(o); made++;
    }
  };
  // Birb initializeFloor + spawnEnemiesFromMapData (no floor has hand-placed spawns, so everything is procedural)
  X.populateFloor = function (s, run, floor) {
    const mapId = X.runMap(floor);
    X.collapseBossCooldowns(s, mapId, floor);
    X.spawnProcedural(s, run, mapId, floor);
    X.reconcileBoss(s, run, mapId, floor); X.ensureBoss(s, run, mapId, floor); X.reconcileBoss(s, run, mapId, floor);
    X.ensureDepthCoverage(s, run, mapId, floor); X.spawnElites(s, run, mapId, floor); X.enforcePopulationCap(run, mapId, floor);
    X.ensureDepthCoverage(s, run, mapId, floor); X.enforceTypeDiversity(s, run, mapId, floor); X.enforceWitchGuards(s, run, mapId, floor);
    X.enforceFloor3(s, run, mapId, floor); X.enforceTypeDiversity(s, run, mapId, floor); X.ensureCultists(s, run, mapId, floor);
  };
  X.refreshRunParrot = function (s) {
    const run = PT.expState(s).activeRun, b = X.parrotBonuses(s); X.bonuses = b;
    if (!run?.parrot) return;
    const p = run.parrot, old = p.maxHealth || 1, frac = p.health / old;
    p.maxHealth = K.BASE_HP + b.hp; p.damage = K.BASE_DAMAGE + b.damage; p.health = frac * p.maxHealth;
  };
  X.initFloor = function (s, run, floor) {
    run.enemies = []; run.exitPortal = null; run.combatArmed = false;
    if (!run.parrot) {
      X.refreshRunParrot(s); const b = X.bonuses, hp = K.BASE_HP + b.hp;
      run.parrot = { x: 0, y: 0, targetEnemyId: null, manualTargetEnemyId: null, preferredFollowSide: -1, preferredStrikeSide: -1, facingRight: true, animFrame: 0, animTimer: 0,
        speed: 90, health: hp, maxHealth: hp, damage: K.BASE_DAMAGE + b.damage, state: "idle", hitCooldown: 0, poisonTicksRemaining: 0, poisonTickTimer: 0, poisonDamagePerTick: 0 };
    } else if (run.parrot.state !== "death") Object.assign(run.parrot, { targetEnemyId: null, manualTargetEnemyId: null, state: "idle" });
    X.populateFloor(s, run, floor);
    X.syncExitPortal(run, X.runMap(floor));
  };

  // ------------------------------------------------------------------ run flow (Birb startRun / advanceToNextFloor / endRun)
  X.startRun = function (G, floor, night = false) {
    const s = G.s, e = PT.expState(s); if (e.activeRun) return false;
    const want = Math.max(1, Math.floor(floor || 1)); if (night && (!X.canNight(s) || want > X.NIGHT_MAX_FLOOR)) return false; if (want > X.maxFloorForEvo(s)) return false;
    X.normalizeCooldowns(s);
    const l = Math.min(e.highestFloorReached || 1, K.MAX_FLOOR, want);
    e.activeRun = { startTime: Date.now(), elapsedTime: 0, currentFloor: l, nightMode: !!night, secretRoomOriginMapId: null, floorResetNonce: 0, exitPortal: null, phase: "active", enemies: [], parrot: null,
      lootDrops: [], damageNumbers: [], collectedResources: {}, equipmentChestsCollected: {}, enemiesDefeated: 0, artifacts: [], skillPointFractionCarry: 0 };
    e.highestFloorReached = Math.max(e.highestFloorReached || 1, l); e.totalRuns++;
    X.goToFloorMap(G, l); X.initFloor(s, e.activeRun, l); X.placeAtPortal(G, "return_hub");
    if (night && e.activeRun.parrot) { const q = X.portal(G.s.currentMap, "return_hub"); if (q) { e.activeRun.parrot.x = q.x - 36; e.activeRun.parrot.y = q.y + 50; } } // Birb: the night parrot starts by the portal
    return true;
  };
  X.goToFloorMap = (G, floor) => { G.s.currentMap = X.runMap(floor); G.target = null; G.vx = G.vy = 0; };
  X.placeAtPortal = function (G, type) { // Birb placePlayerAtExpeditionSpawn: 50 px below the portal
    const m = G.s.currentMap, p = X.portal(m, type) || { x: 528, y: 130 }, run = PT.expState(G.s).activeRun;
    G.s.player.x = p.x; G.s.player.y = p.y + 50;
    if (run?.parrot) Object.assign(run.parrot, { x: G.s.player.x, y: G.s.player.y, targetEnemyId: null, manualTargetEnemyId: null, stunTimer: 0, state: run.parrot.state === "death" ? "death" : "idle" });
  };
  X.advanceFloor = function (G) {
    const s = G.s, e = PT.expState(s), run = e.activeRun; if (!run || !run.exitPortal?.active) return false;
    if (run.currentFloor >= (run.nightMode ? X.NIGHT_MAX_FLOOR : K.MAX_FLOOR)) { run.exitPortal = null; X.endRun(G, run.nightMode === true); return true; }
    if (run.currentFloor + 1 > X.maxFloorForEvo(s)) return false;
    run.currentFloor++; run.floorResetNonce = 0; run.exitPortal = null; run.enemies = []; run.lootDrops = []; run.damageNumbers = [];
    if (run.parrot && run.parrot.state !== "death") Object.assign(run.parrot, { targetEnemyId: null, manualTargetEnemyId: null, state: "idle" });
    if (run.currentFloor > (e.highestFloorReached || 1)) e.highestFloorReached = Math.min(run.currentFloor, K.MAX_FLOOR);
    X.goToFloorMap(G, run.currentFloor); X.initFloor(s, run, run.currentFloor); X.placeAtPortal(G, "return_hub");
    return true;
  };
  X.endRun = function (G, success, inPlace = false) { // inPlace: Birb endRun(.., mapId, false) keeps the player where they are (a totem run ending in the background)
    const s = G.s, e = PT.expState(s), run = e.activeRun; if (!run) return null;
    if (success) e.successfulRuns++;
    e.totalEnemiesDefeated += run.enemiesDefeated;
    if (X.onEndRun) X.onEndRun(s, run);
    const res = { floor: run.currentFloor, kills: run.enemiesDefeated, time: (Date.now() - run.startTime) / 1e3 };
    e.activeRun = null; if (X.totemRemaining && X.totemRemaining(s) === 0) X.totemResetPlacement(); // Birb: an unbroken totem is picked up when the run ends
    if (!inPlace) { s.currentMap = PT.EXP_HUB_MAP; const p = X.portal(PT.EXP_HUB_MAP, "enter_expedition"); s.player.x = p.x; s.player.y = p.y + 90; G.target = null; }
    return res;
  };
  // Birb: hold to reset the floor seed (rerolls this floor's enemies)
  X.resetFloor = function (G) {
    const s = G.s, run = PT.expState(s).activeRun; if (!run || run.phase !== "active") return false;
    run.floorResetNonce = (run.floorResetNonce || 0) + 1; run.enemies = []; X.populateFloor(s, run, run.currentFloor); X.syncExitPortal(run, X.runMap(run.currentFloor)); run.combatArmed = false; return true;
  };

  // ------------------------------------------------------------------ parrot rebirb (Birb m_ / g_ / f_ and the rebirb table)
  PT.parrotRebirbReady = function (s) {
    const n = X.rebirbs(s), hf = Math.max(1, PT.expState(s).highestFloorReached || 1);
    return (n === 0 && (s.evolutionCount || 0) >= 4 && hf >= 3) || (n === 1 && hf >= 7) || (n === 2 && X.archivistDefeated(s));
  };
  PT.parrotRebirbNeed = (s) => ["Evolution 4 and floor 3", "floor 7", "defeat the Archivist (floor 9)", "maxed"][Math.min(3, X.rebirbs(s))];
  PT.parrotRebirb = function (G) {
    const s = G.s; if (!PT.parrotRebirbReady(s) || PT.expState(s).activeRun) return false;
    const p = PT.parrotState(s), e = PT.expState(s);
    p.rebirbCount = X.rebirbs(s) + 1; p.level = 1; p.xp = 0; p.skillPoints = 0; p.skills = { hp: 0, lifeRegen: 0, damage: 0 };
    p.equipmentUpgrades = { beak: { rarity: "common", level: 1 }, armor: { rarity: "common", level: 1 }, aura: { rarity: "common", level: 1 } };
    if (X.totemResetPlacement) X.totemResetPlacement();
    if (X.onParrotRebirb) X.onParrotRebirb(s); // inventory / chests / sacrifice (6b, 6c)
    e.progress = { level: 1, xp: 0, xpToNextLevel: X.xpReq(1), totalXpEarned: 0 };
    return true;
  };
  // Birb getFieldNotesSkillPointsPerSecond: Field Notes gives 1 SP/s (x rebirb multiplier) during a run
  X.fieldNotesRate = (s) => (PT.hasSun(s, "d_desert_field_notes") && PT.expState(s).activeRun ? X.passiveSpMult(s) : 0);
  // Birb getPassiveSkillPointMultiplier x gC (artifact SP roll is 1 for passive gains)
  X.passiveSpMult = (s) => (X.passiveArtifactSpMult ? X.passiveArtifactSpMult(s) : 1) * (X.sacSpMult ? X.sacSpMult(s) : 1) * (1 + (X.parrotBonuses(s).skillPointMult || 0)) * (1 + (X.externalBonuses(s).skillPointMult || 0)) * X.rebirbSpMult(s);
})();
