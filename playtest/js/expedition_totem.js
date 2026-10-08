// Phase 6c: the parrot totem (Birb kT parrotTotem + TT totemRuntime). Parrot rebirb III unlocks it.
// Placed on the current run map, the totem becomes the parrot's anchor: the run keeps fighting there while you walk away
// (back to the hub, the park...). If the parrot dies the totem breaks for 1 hour, then the run restarts at the totem.
// Loaded right after expedition_ai.js so it wraps only the core run update.
(function () {
  const PT = window.PT, X = PT.EXP;
  X.TOTEM_REBIRBS = 3; X.TOTEM_COOLDOWN_MS = 36e5; // Birb To / Io
  const T = (X.totem = { position: null, brokenAt: 0, recovery: null, stats: { seconds: 0, kills: 0, skillPoints: 0, items: 0 } });
  X.totemUnlocked = (s) => X.rebirbs(s) >= X.TOTEM_REBIRBS;
  X.totemRemaining = (s, now = Date.now()) => { const t = Number(PT.expState(s).parrotTotemCooldownUntil); return Number.isFinite(t) ? Math.max(0, t - now) : 0; };
  X.totemActive = (s, now = Date.now()) => X.totemUnlocked(s) && T.position !== null && X.totemRemaining(s, now) === 0;
  const runMapNow = (s) => X.runMap(PT.expState(s).activeRun?.currentFloor || 1);
  // Birb getRunMapId: the map the totem keeps running (null when it is not in play)
  X.totemRunMap = function (s) {
    const e = PT.expState(s).activeRun;
    if (!e || !T.position || !X.totemUnlocked(s)) return null;
    if (T.position.mapId !== runMapNow(s)) return null;
    return X.totemActive(s) || e.parrot?.state === "death" ? T.position.mapId : null;
  };
  X.totemBackground = (s) => (X.totemSwap ? X.totemSwap.playerMap !== X.totemSwap.runMap : (() => { const m = X.totemRunMap(s); return m !== null && m !== s.currentMap; })());
  // the parrot fell: in the background the run ends where the player stands (Birb endRunInPlace), else the usual way
  X.totemDeath = (G) => { if (!X.totemBackground(G.s)) return false; X.endRun(G, false, true); T.endedInPlace = true; return true; };
  // Birb canPlace / place / collect / returnToTotem
  X.totemCanPlace = function (s, mapId, x, y) {
    const i = PT.expState(s).activeRun; if (!X.totemUnlocked(s) || !i?.parrot || i.parrot.health <= 0 || i.isPaused) return false;
    if (!Number.isFinite(x) || !Number.isFinite(y) || mapId !== runMapNow(s)) return false;
    const a = X.bounds(mapId); if (!(x >= a.minX + 32 && x <= a.maxX - 32 && y >= a.minY + 48 && y <= a.maxY - 24)) return false;
    return !X.spawnBlocked(mapId, x, y) && !X.portalZones(mapId).some((z) => (x - z.x) ** 2 + (y - z.y) ** 2 <= z.radius * z.radius);
  };
  X.totemPlace = function (s, mapId, x, y) {
    if (!X.totemCanPlace(s, mapId, x, y)) return false;
    T.recovery = null; PT.expState(s).isAutoAttack = true; PT.expState(s).activeRun.combatArmed = true;
    T.position = { mapId, x, y }; if (X.totemRemaining(s) === 0) T.brokenAt = 0; return true;
  };
  X.totemCollect = function (G) { const s = G.s, m = X.totemRunMap(s); T.recovery = null; T.position = null; if (m !== null && m !== s.currentMap) X.endRun(G, false, true); };
  X.returnToTotem = function (G) { const s = G.s, m = X.totemRunMap(s); if (m === null || !T.position || !X.totemActive(s)) return false; s.currentMap = m; s.player.x = T.position.x; s.player.y = T.position.y + 40; G.target = null; return true; };
  const breakTotem = (s, now = Date.now()) => { if (X.totemActive(s, now)) { PT.expState(s).parrotTotemCooldownUntil = now + X.TOTEM_COOLDOWN_MS; T.brokenAt = now; } };
  const resetPlacement = () => { T.position = null; T.brokenAt = 0; Object.assign(T.stats, { seconds: 0, kills: 0, skillPoints: 0, items: 0 }); };
  X.totemResetPlacement = resetPlacement;
  // Birb recoverWhenReady: once the hour is up and no run is going, restart the run at the totem
  const recover = (G) => {
    const s = G.s, e = T.recovery; if (!e) return;
    const run = PT.expState(s).activeRun;
    if (T.position !== e.position || !X.totemUnlocked(s) || (run && run.parrot !== e.parrot)) { T.recovery = null; return; }
    if (run || X.totemRemaining(s) > 0) return;
    T.recovery = null; const { mapId, x, y } = e.position, b = X.bounds(mapId);
    if (x < b.minX || x > b.maxX || y < b.minY || y > b.maxY || X.spawnBlocked(mapId, x, y)) return;
    const keep = { map: s.currentMap, x: s.player.x, y: s.player.y };
    if (!X.startRun(G, e.run.currentFloor, e.run.nightMode === true)) return;
    Object.assign(s, { currentMap: keep.map }); s.player.x = keep.x; s.player.y = keep.y; // Birb restartRun(run, position) does not move the player
    const r = PT.expState(s).activeRun; if (r.parrot) { r.parrot.x = x; r.parrot.y = y; }
    T.brokenAt = 0; PT.expState(s).isAutoAttack = true; r.combatArmed = true;
  };
  // Birb totemRuntime.update: run the totem's map with the totem as the anchor, wherever the player is
  const core = X.update;
  X.update = function (G, dt) {
    const s = G.s; recover(G);
    const m = X.totemRunMap(s), run = PT.expState(s).activeRun;
    if (m === null || !run) return core(G, dt);
    const p = run.parrot;
    if (p && p.health <= 0 && p.state !== "death" && T.position && X.totemActive(s)) { // Birb updateDeath: remember the run, break the totem
      T.recovery = { position: T.position, parrot: p, run: { currentFloor: run.currentFloor, nightMode: run.nightMode } }; breakTotem(s);
    }
    const keep = { map: s.currentMap, x: s.player.x, y: s.player.y }, kills = run.enemiesDefeated || 0, live = X.totemActive(s) && (p?.health ?? 0) > 0;
    X.totemSwap = { playerMap: keep.map, runMap: m };
    try { s.currentMap = m; s.player.x = T.position.x; s.player.y = T.position.y; return core(G, dt); }
    finally {
      X.totemSwap = null;
      if (PT.expState(s).activeRun === run || T.endedInPlace) { s.currentMap = keep.map; s.player.x = keep.x; s.player.y = keep.y; T.endedInPlace = false; }
      if (live) { T.stats.seconds += Math.max(0, dt); T.stats.kills += Math.max(0, (run.enemiesDefeated || 0) - kills); }
    }
  };
})();
