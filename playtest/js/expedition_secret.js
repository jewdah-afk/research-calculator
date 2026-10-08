// Phase 6c: expedition secret rooms and the floor 1 mine entrance (Birb tryEnterSecretRoom / tryExitSecretRoom,
// canBreakFloorOneMineEntrance, startFloorOneMineEntranceBreakSequence, updateFloorOneMineEntranceBreak).
// Floor 1's secret room (map 17) holds a cracked wall. With parrot rebirb II and all three starter gear pieces maxed
// (legendary, or epic level 5) the parrot breaks it in 3 hits and the Mine (map 25) opens for good.
(function () {
  const PT = window.PT, X = PT.EXP;
  PT.SECRET_ROOM_1_MAP = 17;
  PT.MAPS[17] = { id: 17, key: "expedition-secret-room-1", name: "SECRET ROOM", w: 1056, h: 792, side: true };
  PT.MAPS[19] = { id: 19, key: "expedition-secret-room-3", name: "SECRET ROOM", w: 1056, h: 792, side: true };
  X.SECRET_ROOMS = { 1: 17, 3: 19 }; // Birb Ht(floor) for the floors whose map has a secret_room_enter portal
  X.SECRET_RETURN = { 17: { x: 527, y: 8 }, 19: { x: 529, y: 756 } }; // secret_room_return portals
  X.MINE_ENTRANCE = { x: 447, y: 576, width: 128, height: 128 }; // Birb se
  const ANCHOR = { x: 512, y: 676 }; // Birb un / hn: the strike point (the parrot stands 42 px to either side)
  X.isSecretRoom = (m) => m === 17 || m === 19;

  // Birb Qr: a starter gear piece is maxed at legendary, or epic level 5
  X.gearMaxed = (u) => u?.rarity === "legendary" || (u?.rarity === "epic" && u?.level === 5);
  X.starterGearMaxed = (s) => ["beak", "armor", "aura"].every((k) => X.gearMaxed(PT.parrotState(s).equipmentUpgrades[k]));
  X.canBreakMineEntrance = (s) => s.currentMap === 17 && s.floorOneMineEntranceOpened !== true && X.rebirbs(s) >= 2 && X.starterGearMaxed(s);
  // Birb hasMineProgressForEntranceRepair: any mine progress on an old save reopens the entrance
  X.hasMineProgress = function (s) {
    const m = s.mine || {}, r = (v) => Math.max(0, Math.floor(Number(v ?? 0) || 0)), res = (k) => (s.resources[k] ? Number(s.resources[k].toString()) : 0);
    const area = Math.max(0, Math.floor(Number(m.collapseLevel ?? m.milestoneLevel ?? (s.mine && PT.mineArea ? PT.mineArea(s) : 0)))); // Birb's normalized mine has collapseLevel = the mine area
    const track = Math.max(r(m.crowArmorLevel ?? m.armorPlatingLevel), r(m.crowArmorXp ?? m.armorPlatingXp), r(m.crowDamageLevel), r(m.crowDamageXp), r(m.crowRegenLevel), r(m.crowRegenXp), 0);
    const tree = window.BIRB_DATA.upgrades.some((u) => u.tree === "M" && (s.upgrades?.[u.id] || 0) > 1);
    const crow = Number(m.crowLevel || 1) > 1 || Number(m.crowXp || 0) > 0 || Number(m.crowRebirbCount || 0) > 0;
    const sun = Object.entries(s.sunflowerUpgrades || {}).some(([k, v]) => k.startsWith("d_mine_") && v > 0);
    return res("bruteOre") > 0 || res("oreBars") > 0 || res("deepCores") > 0 || Number(m.runBruteOreEarned || 0) > 0 || area > 0 || track > 0 || tree || crow || sun;
  };
  X.repairMineEntrance = (s) => { if (s.floorOneMineEntranceOpened !== true && X.hasMineProgress(s)) s.floorOneMineEntranceOpened = true; };

  // Birb tryEnterSecretRoom / tryExitSecretRoom (no secret rooms in night mode)
  X.enterSecretRoom = function (G) {
    const s = G.s, run = PT.expState(s).activeRun; if (!run || run.nightMode || !X.isRunMap(s.currentMap)) return false;
    const room = X.SECRET_ROOMS[run.currentFloor]; if (!room) return false;
    run.secretRoomOriginMapId = s.currentMap; s.currentMap = room; X.breakReset(s);
    const p = X.SECRET_RETURN[room]; s.player.x = p.x; s.player.y = p.y > 400 ? p.y - 140 : p.y + 160;
    if (run.parrot && run.parrot.state !== "death") Object.assign(run.parrot, { x: s.player.x - 40, y: s.player.y, targetEnemyId: null, manualTargetEnemyId: null, state: "idle" });
    G.target = null; return true;
  };
  X.exitSecretRoom = function (G) {
    const s = G.s, run = PT.expState(s).activeRun; if (!X.isSecretRoom(s.currentMap)) return false;
    X.breakReset(s);
    if (!run) { s.currentMap = PT.EXP_HUB_MAP; const p = X.portal(PT.EXP_HUB_MAP, "enter_expedition"); s.player.x = p.x; s.player.y = p.y + 90; G.target = null; return true; }
    const back = run.secretRoomOriginMapId || X.runMap(run.currentFloor); run.secretRoomOriginMapId = null;
    s.currentMap = back; X.placeAtPortal(G, "secret_room_enter"); return true;
  };
  // Birb enterFloorOneSecretMineRoom / exitFloorOneSecretMineRoom
  X.enterMineRoom = (G) => { const s = G.s; if (s.currentMap !== 17 || !PT.expState(s).activeRun || s.floorOneMineEntranceOpened !== true) return false; X.breakReset(s); s.currentMap = PT.MINE_MAP; const m = PT.MAPS[PT.MINE_MAP]; s.player.x = m.w / 2; s.player.y = 140; G.target = null; return true; };
  X.exitMineRoom = (G) => { const s = G.s; if (s.currentMap !== PT.MINE_MAP || !PT.expState(s).activeRun) return false; s.currentMap = 17; s.player.x = X.MINE_ENTRANCE.x + 64; s.player.y = X.MINE_ENTRANCE.y - 40; G.target = null; return true; };
  X.inMineEntrance = (x, y) => { const r = X.MINE_ENTRANCE; return x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height; };

  // Birb startFloorOneMineEntranceBreakSequence + updateFloorOneMineEntranceBreak: walk to the wall, 3 hits on frame 2 of each swing
  let brk = null;
  X.breakActive = () => !!brk;
  X.breakReset = () => { brk = null; };
  X.startBreak = function (s, onHit) {
    const run = PT.expState(s).activeRun, p = run?.parrot; if (s.currentMap !== 17 || !p || p.state === "death" || p.health <= 0) return false;
    if (!brk) { brk = { hits: 0, onHit }; Object.assign(p, { state: "attack", animFrame: 0, animTimer: 0, stunTimer: 0 }); }
    return true;
  };
  X.updateBreak = function (s, dt) {
    if (!brk) return false;
    const run = PT.expState(s).activeRun, e = run?.parrot; if (s.currentMap !== 17 || !e || e.state === "death") { brk = null; return false; }
    const b = X.bonuses || X.parrotBonuses(s), i = Math.max(0.01, b.attackSpeedMult || 1), a = Math.max(0.01, b.moveSpeedMult || 1);
    e.health = Math.max(1, e.health); e.hitCooldown = Math.max(0, (e.hitCooldown ?? 0) - dt);
    const side = e.x < ANCHOR.x ? -1 : 1, an = { x: ANCHOR.x + (side < 0 ? -42 : 42), y: ANCHOR.y };
    const step = (k) => { const dx = an.x - e.x, dy = an.y - e.y, o = Math.hypot(dx, dy) || 1; return { o, go: () => { const t = Math.min(k * e.speed * a * dt, o); e.x += (dx / o) * t; e.y += (dy / o) * t; } }; };
    e.facingRight = ANCHOR.x > e.x;
    if (["attack", "follow", "idle", "return"].includes(e.state)) { const m = step(1.35); if (m.o <= 6) Object.assign(e, { state: "attacking", animFrame: 0, animTimer: 0 }); else { e.state = "attack"; m.go(); } }
    else if (e.state === "attacking") {
      e.animTimer += dt; const t = 0.1 / i;
      while (e.animTimer >= t) {
        e.animTimer -= t; e.animFrame++;
        if (e.animFrame === 2 && (e.hitCooldown ?? 0) <= 0) {
          brk.hits++; if (brk.onHit) brk.onHit(brk.hits); e.hitCooldown = 0.2 / i;
          if (brk.hits >= 3) { brk = null; s.floorOneMineEntranceOpened = true; const m = PT.mineState(s); m.expeditionCycle ||= { version: 1, rewardedGiants: 0 }; e.state = "return"; return true; }
        }
        if (e.animFrame >= 4) { e.state = "attack_wait"; e.animTimer = 0.25 / i; break; }
      }
    } else if (e.state === "attack_wait") { const m = step(1.1); if (m.o > 4) m.go(); e.animTimer -= dt; if (e.animTimer <= 0) Object.assign(e, { state: "attacking", animFrame: 0, animTimer: 0 }); }
    else if (e.state === "take_damage") Object.assign(e, { state: "attack", animFrame: 0, animTimer: 0, stunTimer: 0 });
    return true;
  };

  // in a secret room the parrot follows the player (no enemies) unless it is breaking the wall
  const updOrig = X.update;
  X.update = function (G, dt) {
    const s = G.s, run = PT.expState(s).activeRun;
    if (run && X.isSecretRoom(s.currentMap)) {
      if (s.currentMap === 17) X.repairMineEntrance(s);
      if (!X.updateBreak(s, dt) && run.parrot && run.parrot.state !== "death") { const p = run.parrot, dx = s.player.x - 40 - p.x, dy = s.player.y - p.y, o = Math.hypot(dx, dy); if (o > 8) { const t = Math.min(p.speed * 2 * dt, o); p.x += (dx / o) * t; p.y += (dy / o) * t; p.facingRight = dx > 0; } }
      for (const d of run.damageNumbers) { d.life -= dt; d.y -= 26 * dt; } run.damageNumbers = run.damageNumbers.filter((d) => d.life > 0);
    }
    return updOrig(G, dt);
  };
})();
(function () { // portals of the secret rooms and the mine room exit (during a run the mine room leads back to secret room 1)
  const PT = window.PT, X = PT.EXP, orig = X.portals;
  X.portals = (m) => X.isSecretRoom(m) ? [{ type: "secret_room_return", x: X.SECRET_RETURN[m].x, y: Math.max(60, X.SECRET_RETURN[m].y), r: 60 }]
    : m === PT.MINE_MAP && PT.expState(PT.G.s).activeRun ? [{ type: "mine_exit", x: 528, y: 60, r: 60 }] : orig(m);
})();
