// Peckwood playtest: loop, input, rendering, panels, saves and dev tools.
"use strict";
(function () {
  const PT = window.PT;
  const { D, fmt } = PT;
  const ICON = (n) => `../birb-icons/final/${n}.png`;
  const FISHICON = (id) => `../birb-icons/final/fish/${PT.baseFishId ? PT.baseFishId(id) : id}.png`;
  const CUR = {
    popcorn: { name: "Eggs", icon: "egg" },
    goldenFeathers: { name: "Plumes", icon: "plume" },
    sunflowerSeeds: { name: "Seeds", icon: "seed" },
    goldenPopcorn: { name: "Golden Eggs", icon: "egg_golden" },
    monetariaMoneta: { name: "Moneta", icon: "moneta" },
    twigs: { name: "Twigs", icon: "twig" },
    echoPopcorn: { name: "Echo Eggs", icon: "echo" },
    bruteOre: { name: "Brute Ore", icon: "ore" },
    totalFishCaught: { name: "Fish caught", icon: "fish" },
  };
  const UP_ICON = {
    p_value: "up_egg_value", p_speed: "up_egg_speed", p_capacity: "up_egg_cap", p_move_speed: "up_wing_speed",
    p_golden_popcorn_value: "up_golden_value", p_auric_silo: "up_silo_cap",
    pr_popcorn_mult: "up_egg_mult", pr_radius_mult: "up_magnet_value", pr_respawn_mult: "up_hatch_speed", pr_golden_popcorn_mult: "up_golden_mult",
    s_more_popcorn: "up_basket_value", s_more_feathers: "up_plume_value", s_more_seeds: "up_seed_value",
    m_ore_value: "up_ore_value", m_mining_power: "up_mining_power", m_charged_strike: "pickaxe_charged", m_rupture: "rupture",
  };
  // Player-facing text: Birb's words with eggs for popcorn (owner's call), Plumes for golden feathers, Molt for rebirb.
  const words = (t) => String(t || "")
    .replace(/golden feathers?/gi, "Plumes").replace(/feathers?/gi, (m) => (m[0] === "F" ? "Plumes" : "plumes"))
    .replace(/popcorns?/gi, (m) => (m[0] === "P" ? (m === m.toUpperCase() ? "EGG" + (m.endsWith("S") ? "S" : "") : "Egg" + (m.endsWith("s") ? "s" : "")) : "egg" + (m.endsWith("s") ? "s" : "")))
    .replace(/rebirth|rebirb/gi, (m) => (m === m.toUpperCase() ? "MOLT" : m[0] === "R" ? "Molt" : "molt"));
  const title = (t) => words(t).toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());

  // ------------------------------------------------------------------ game object
  const SAVE_KEY = "peckwood_playtest_v1";
  const G = (PT.G = {
    s: null, field: new PT.Field(), sparrows: [], anchor: null, rates: {}, gainAcc: {}, rateT: 0,
    seedTimer: 0, timeScale: 1, keys: new Set(), target: null, vx: 0, vy: 0, holdFeed: false,
    floats: [], tab: "eggs", t: 0,
    gain(k, v) { this.gainAcc[k] = (this.gainAcc[k] || 0) + PT.num(v); },
    onFloat(x, y, text, color) { if (G.floats.length < 60) G.floats.push({ x, y, text, color, life: 0.8, map: G.s.currentMap }); },
  });

  function serialize(s) {
    return JSON.stringify(s, (k, v) => (v instanceof Decimal ? { __D: v.toString() } : v));
  }
  function deserialize(str) {
    const base = PT.newState();
    const o = JSON.parse(str, (k, v) => (v && typeof v === "object" && "__D" in v ? new Decimal(v.__D) : v));
    const s = Object.assign(base, o);
    s.resources = Object.assign(PT.newState().resources, o.resources || {});
    for (const k in s.resources) s.resources[k] = D(s.resources[k]);
    s.totalPopcornCollected = D(s.totalPopcornCollected);
    s.sparrow = Object.assign(PT.newState().sparrow, o.sparrow || {});
    return s;
  }
  function save() { try { G.s.lastActiveAt = Date.now(); localStorage.setItem(SAVE_KEY, serialize(G.s)); } catch (e) {} }
  function load() {
    try { const t = localStorage.getItem(SAVE_KEY); if (t) return deserialize(t); } catch (e) {}
    return PT.newState();
  }
  G.s = load();
  PT.nestState(G.s);
  G.offline = PT.applyOffline(G.s); // Birb applyOfflineEarnings on load
  // Birb applyHiddenTabEarnings: when the tab comes back, pay twigs for the time the loop did not run
  let hiddenAt = 0;
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) { hiddenAt = performance.now(); return; }
    const sec = (performance.now() - hiddenAt) / 1000; if (!hiddenAt || sec < 0.25) return;
    PT.nestAdvanceBeds(G.s, sec); const tw = Math.floor(PT.hiddenTabTwigRate(G.s) * sec); if (tw > 0) { PT.nestAddTwigs(G.s, tw); toast(`+${fmt(tw)} twigs while hidden`); }
  });

  // ------------------------------------------------------------------ canvas + camera
  const cv = document.getElementById("view"), cx = cv.getContext("2d");
  const imgs = {};
  const img = (n) => { if (!imgs[n]) { imgs[n] = new Image(); imgs[n].src = ICON(n); } return imgs[n]; };
  let cam = { x: 0, y: 0, k: 1 };
  function resize() {
    const r = cv.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    cv.width = Math.round(r.width * dpr); cv.height = Math.round(r.height * dpr);
  }
  window.addEventListener("resize", resize); resize();
  function updateCam() {
    const m = PT.MAPS[G.s.currentMap], W = cv.width, H = cv.height;
    if (m.w <= 1100) { const k = Math.min(W / m.w, H / m.h); cam = { k, x: (W / k - m.w) / 2, y: (H / k - m.h) / 2 }; }
    else {
      const k = Math.min(1.1, H / 900) * (window.devicePixelRatio || 1) * 0.75;
      let x = W / k / 2 - G.s.player.x, y = H / k / 2 - G.s.player.y;
      x = Math.min(0, Math.max(W / k - m.w, x)); y = Math.min(0, Math.max(H / k - m.h, y));
      cam = { k, x, y };
    }
  }
  const toWorld = (px, py) => ({ x: px / cam.k - cam.x, y: py / cam.k - cam.y });

  // ------------------------------------------------------------------ input
  addEventListener("keydown", (e) => {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
    G.keys.add(e.key.toLowerCase());
    const k = e.key.toLowerCase();
    if (k === "5" && PT.mineOpen(G.s)) openWin("crow");
    if (k === "e" && expPortalAction()) return;
    if (k === "e" && G.s.currentMap === 17 && Math.hypot(G.s.player.x - 511, G.s.player.y - 640) < 140) { mineEntrance(); return; }
    if (k === "e") { if (G.s.currentMap === PT.SACRIFICE_MAP) openWin("sacrifice"); else if (G.s.currentMap === PT.MINE_TREE_MAP) openWin("minetree"); else if (G.s.currentMap === PT.MINE_MAP) PT.minePlayerHit(G); else if (G.s.currentMap === PT.NEST_ROOM_MAP) openWin("redpanda"); else if (G.s.currentMap === PT.FISH_MARKET_MAP) openWin("market", "market"); else if (G.s.currentMap !== 1 && PT.aquariumUnlocked(G.s)) openWin("aquarium"); else tryStation(); }
    if (k === " ") { e.preventDefault(); cast(); }
    if (k === "tab") { e.preventDefault(); G.companionsOpen = !G.companionsOpen; drawHud(); }
    if (k === "p") openWin("profile");
    if (k === "q") openWin("quests"); // Birb KeyQ opens the objectives window
    if (k === "h" && PT.expState(G.s).activeRun) { if (PT.EXP.usePotion(G.s)) save(); } // Birb uses the potion button only (no key)
    if (k === "escape") { if (G.win) closeWin(); else openWin("settings"); }
  });
  // Birb tryHandleFloorOneMineEntranceInteraction
  function mineEntrance() {
    const s = G.s, X = PT.EXP; X.repairMineEntrance(s);
    if (s.floorOneMineEntranceOpened === true) { if (X.enterMineRoom(G)) save(); return; }
    if (X.breakActive()) return;
    if (!X.canBreakMineEntrance(s)) return toast(`The wall is cracked. The parrot can break it at Parrot Rebirb II (${X.rebirbs(s)}/2) with maxed beak, armor and aura (legendary, or epic 5): ${["beak", "armor", "aura"].filter((k) => X.gearMaxed(PT.parrotState(s).equipmentUpgrades[k])).length}/3.`);
    X.startBreak(s, (n) => { const run = PT.expState(s).activeRun; if (run) X.dmgNumber(run, { x: 511, y: 600 }, n >= 3 ? "THE WALL BREAKS!" : "CRACK", "#fde68a"); if (n >= 3) { s.hasSeenMineTab = true; toast("The Mine is open"); save(); } });
  }
  function cast() { if (!PT.startCast(G)) toast(G.s.currentMap !== 2 ? "Fish on the Bridge" : G.s.evolutionCount < 1 ? "Fishing needs Evolution 1" : "Not ready"); }
  addEventListener("keyup", (e) => G.keys.delete(e.key.toLowerCase()));
  cv.addEventListener("mousedown", (e) => {
    const r = cv.getBoundingClientRect(), dpr = cv.width / r.width;
    const w = toWorld((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr);
    if (PT.EXP.isRunMap(G.s.currentMap) && PT.EXP.command(G.s, w.x, w.y, G.s.player.x, G.s.player.y)) return;
    if (expPortalAt(w.x, w.y)) { expPortalAction(); return; }
    if (G.s.currentMap === 17 && PT.EXP.inMineEntrance(w.x, w.y)) { mineEntrance(); return; }
    G.target = w;
    if (G.s.currentMap === PT.NEST_ROOM_MAP && Math.hypot(w.x - 528, w.y - 380) < 70) openWin("redpanda");
    if (G.s.currentMap === PT.MINE_MAP && Math.hypot(w.x - 528, w.y - 520) < 110) { PT.minePlayerHit(G); G.target = null; }
    if (G.s.currentMap === PT.MINE_TREE_MAP) openWin("minetree");
    if (G.s.currentMap === PT.SACRIFICE_MAP && Math.hypot(w.x - 528, w.y - 396) < 90) openWin("sacrifice");
    if (G.s.currentMap === 3 && !G.s.hasTalkedToMonster && Math.hypot(w.x - 800, w.y - 500) < 140) { G.s.hasTalkedToMonster = true; toast("The monster is hungry. Hold to feed it!"); }
  });

  // ------------------------------------------------------------------ helpers
  let toastT = 0;
  G.toast = (t) => toast(t);
  function toast(t) { const el = document.getElementById("toast"); el.textContent = t; el.style.opacity = 1; toastT = 2; }
  function stationAt(x, y) {
    if (G.s.currentMap !== 1) return null;
    for (const st of visibleStations()) if (x >= st[1] && x <= st[1] + st[3] && y >= st[2] && y <= st[2] + st[4]) return st;
    return null;
  }
  const desertView = () => G.s.sunflowerTreeView === "desert";
  const isDesertNode = (id) => id.startsWith("d_desert_") || id === "d_unlock_archivist_tree";
  function visibleStations() {
    return PT.STATIONS.filter((st) => st[0] !== "__platform" && isDesertNode(st[0]) === desertView() && PT.sunVisible(G.s, st[0]));
  }
  function tryStation() {
    const st = stationAt(G.s.player.x, G.s.player.y + 15);
    if (!st) return;
    const r = PT.buySun(G.s, st[0]);
    toast(r === "" ? "Unlocked: " + title(PT.SUN.get(st[0]).name || st[0]) : r === "owned" ? "Already owned" : r === "locked" ? "Locked" : r === "not enough" ? "Not enough" : r);
    if (r === "") save();
  }
  function onPlatform() {
    if (G.s.currentMap !== 1 || desertView() || !PT.hasSun(G.s, "d_sunflower_machine")) return false;
    const p = PT.STATIONS.find((s) => s[0] === "__platform"), x = G.s.player.x, y = G.s.player.y + 15;
    return x >= p[1] && x <= p[1] + p[3] && y >= p[2] && y <= p[2] + p[4];
  }
  function travel(dir) {
    const why = PT.travelBlock(G.s, dir);
    if (why) { if (why !== "end") toast(why); return; }
    const from = G.s.currentMap; G.s.currentMap = PT.travelTarget(G.s, dir);
    const m = PT.MAPS[G.s.currentMap];
    if (G.s.currentMap === 1) G.s.sunflowerFieldReturnMap = from === 9 ? 9 : 0;
    if (G.s.currentMap === PT.NEST_MAP) { (G.s.clickedMapArrows ||= {}).visited_map4 = true; G.s.nestReturnMap = from;
      const f = PT.nestState(G.s).forest; if (!f.hasSeenIntro) { f.hasSeenIntro = true; toast("This ancient tree has been abandoned... collect twigs to fix it"); } }
    G.s.player.x = dir > 0 ? 80 : m.w - 80; G.s.player.y = m.id === 1 ? 640 : m.h / 2; G.target = null; G.vx = G.vy = 0;
    save();
  }
  function travelVert(dir) {
    const why = PT.vertBlock(G.s, dir);
    if (why) { if (why !== "end") toast(why); return; }
    G.s.currentMap = PT.vertLinks[G.s.currentMap][dir];
    if (G.s.currentMap === PT.NEST_ROOM_MAP && !PT.redPandaState(G.s).introSeen) { toast("Something is already sleeping inside the nest..."); setTimeout(() => openWin("redpanda"), 600); }
    const m = PT.MAPS[G.s.currentMap]; G.s.player.x = m.w / 2; G.s.player.y = dir === "down" ? 140 : m.h - 140; G.target = null; G.vx = G.vy = 0;
    if (G.s.currentMap === PT.FISH_MARKET_MAP) PT.marketSync(G.s);
    if (G.s.currentMap === PT.DESERT_MAP && !G.s.hasSeenDesertMapIntro) { G.s.hasSeenDesertMapIntro = true; toast("THE DESERT: some eggs here are golden"); }
    save();
  }
  document.getElementById("go-up").onclick = () => travelVert("up");
  document.getElementById("go-down").onclick = () => travelVert("down");
  document.getElementById("btn-aquarium").onclick = () => openWin(G.s.currentMap === PT.FISH_MARKET_MAP ? "market" : "aquarium");
  document.getElementById("go-left").onclick = () => travel(-1);
  document.getElementById("go-right").onclick = () => travel(1);

  // ------------------------------------------------------------------ update
  function step(dt) {
    const s = G.s, m = PT.MAPS[s.currentMap];
    s.playTime += dt; G.t += dt;
    // movement (Birb: acceleration toward input, max speed)
    let ix = 0, iy = 0;
    if (G.keys.has("a") || G.keys.has("arrowleft")) ix--; if (G.keys.has("d") || G.keys.has("arrowright")) ix++;
    if (G.keys.has("w") || G.keys.has("arrowup")) iy--; if (G.keys.has("s") || G.keys.has("arrowdown")) iy++;
    if (ix || iy) G.target = null;
    else if (G.target) { const dx = G.target.x - s.player.x, dy = G.target.y - s.player.y, d = Math.hypot(dx, dy); if (d < 6) G.target = null; else { ix = dx / d; iy = dy / d; } }
    const vmax = PT.maxSpeed(s), acc = PT.accel(s), il = Math.hypot(ix, iy) || 1;
    if (ix || iy) { G.vx += (ix / il) * acc * dt; G.vy += (iy / il) * acc * dt; }
    else { const f = Math.max(0, 1 - 8 * dt); G.vx *= f; G.vy *= f; }
    const sp = Math.hypot(G.vx, G.vy); if (sp > vmax) { G.vx *= vmax / sp; G.vy *= vmax / sp; }
    if (PT.EXP.isRunMap(s.currentMap) || s.currentMap === PT.EXP_HUB_MAP) { // collision boxes (Birb: same boxes the enemies use)
      const rects = PT.EXP.collisions(s.currentMap), hit = (x, y) => rects.some((r) => x + 10 > r.left && x - 10 < r.right && y > r.top && y - 10 < r.bottom);
      const nx = Math.max(20, Math.min(m.w - 20, s.player.x + G.vx * dt)); if (!hit(nx, s.player.y)) s.player.x = nx; else G.vx = 0;
      const ny = Math.max(20, Math.min(m.h - 20, s.player.y + G.vy * dt)); if (!hit(s.player.x, ny)) s.player.y = ny; else G.vy = 0;
      const run = PT.expState(s).activeRun; if (run && (ix || iy)) run.combatArmed = true; // Birb registerPlayerCombatAction on movement
    } else {
    s.player.x = Math.max(20, Math.min(m.w - 20, s.player.x + G.vx * dt));
    s.player.y = Math.max(20, Math.min(m.h - 20, s.player.y + G.vy * dt));
    }

    // Park field: spawns while you're there, and while away once the Sparrow is unlocked (Birb update())
    const prof = PT.pickupProfile(s);
    if (s.currentMap === 0 || s.sparrow.unlocked) {
      const here = s.currentMap === 0;
      G.field.update(s, dt, 0, 1056, 792, PT.maxPopcorn(s), PT.spawnInterval(s), here ? {
        player: s.player, immediateRadius: prof.collectRadius, legacyRadius: legacyRadius(s), onImmediate: (p) => PT.award(G, p, "player"),
      } : null);
    }
    if (s.currentMap === 0) G.field.pickup(0, s.player.x, s.player.y, prof, dt, (p) => PT.award(G, p, "player"));

    // seeds (Birb: seedTimer, whole ticks only)
    const sr = PT.seedRate(s, onPlatform());
    if (sr.ticksPerSec > 0) {
      G.seedTimer += dt * sr.ticksPerSec;
      if (G.seedTimer >= 1) { const n = Math.floor(G.seedTimer); G.seedTimer -= n; const v = n * sr.perTick; PT.add(s, "sunflowerSeeds", v); G.gain("sunflowerSeeds", v);
        if (onPlatform()) G.onFloat(s.player.x, s.player.y - 30, "+" + fmt(v), "#22c55e"); }
    }
    PT.updateSparrows(G, dt);
    PT.updateDesert(G, dt, prof);
    PT.updateNest(G, dt);
    PT.updateMine(G, dt);
    PT.EXP.update(G, dt);
    PT.ensureFishing(s);
    PT.updateFishing(G, dt, Math.abs(G.vx) > 5 || Math.abs(G.vy) > 5);
    PT.updateSeagull(G, dt);
    if (s.currentMap === 2 && s.evolutionCount >= 3 && !s.hasMetSeagull) { s.hasMetSeagull = true; s.seagull.discovered = true; toast("A seagull joins you at the Bridge!"); }
    if (s.currentMap === 2 && s.player.x > 2240 && !s.hasEnteredDungeon && s.hasUnlockedEvolve) { s.hasEnteredDungeon = true; toast("The castle gate is open"); }
    if (G.holdFeed && s.currentMap === 3 && s.hasTalkedToMonster && s.evolutionCount < 5 && s.monsterFeedProgress < 100) PT.feedMonster(s, 10 * dt);

    // per-second income rates (used by the seed feeder, Birb currencyRates)
    G.rateT += dt;
    if (G.rateT >= 1) { for (const k of ["popcorn", "sunflowerSeeds", "goldenFeathers", "monetariaMoneta", "goldenPopcorn", "daveXp"]) { const r = (G.gainAcc[k] || 0) / G.rateT; G.rates[k] = G.rates[k] === undefined ? r : G.rates[k] * 0.6 + r * 0.4; G.gainAcc[k] = 0; } G.rateT = 0; }
    for (const f of G.floats) { f.life -= dt; f.y -= 30 * dt; }
    G.floats = G.floats.filter((f) => f.life > 0);
  }
  function legacyRadius(s) { // Birb: the 70px radius used by Gravity Field
    let me = 70; const ge = PT.level(s, "pr_radius_mult");
    if (ge > 0) me *= 1 + 0.2 * (ge - 1); if (PT.hasSun(s, "d_pickup_range")) me *= 1.25; return me;
  }

  // ------------------------------------------------------------------ render
  function render() {
    updateCam();
    const s = G.s, m = PT.MAPS[s.currentMap];
    cx.setTransform(1, 0, 0, 1, 0, 0);
    cx.fillStyle = "#1a2a1c"; cx.fillRect(0, 0, cv.width, cv.height);
    cx.setTransform(cam.k, 0, 0, cam.k, cam.x * cam.k, cam.y * cam.k);
    const bg = { 0: "#5f9a45", 1: desertView() ? "#c8a46a" : "#6fa553", 2: "#6fa553", 3: "#5c5f66" }[s.currentMap];
    cx.fillStyle = bg; roundRect(0, 0, m.w, m.h, 24); cx.fill();
    cx.lineWidth = 6; cx.strokeStyle = "#0b0c10"; cx.stroke();
    if (s.currentMap === 0) {
      for (const p of G.field.list(0)) drawEgg(p.x, p.y, PT.TYPES[p.type].color, p.type);
      for (const b of G.sparrows) drawIcon("sparrow", b.x, b.y - (b.state === "fly" ? 14 : 0), 34, b.face < 0);
    }
    if (s.currentMap === PT.DESERT_MAP) drawDesert();
    if (s.currentMap === 1) drawSunflowerField();
    if (s.currentMap === 2) drawBridge();
    if (s.currentMap === PT.AQUARIUM_MAP) drawAquarium();
    if (s.currentMap === PT.FISH_MARKET_MAP) drawMarket();
    if (s.currentMap === PT.NEST_MAP) drawNest();
    if (s.currentMap === PT.NEST_ROOM_MAP) drawNestRoom();
    if (s.currentMap === PT.MINE_MAP) drawMine();
    if (s.currentMap === PT.EXP_HUB_MAP || PT.EXP.isRunMap(s.currentMap) || PT.EXP.isSecretRoom(s.currentMap)) drawExpedition();
    if (s.currentMap === PT.MINE_MAP && PT.expState(s).activeRun) { const q = PT.EXP.portals(s.currentMap)[0]; cx.beginPath(); cx.arc(q.x, q.y, q.r, 0, 7); cx.fillStyle = "rgba(124,58,237,.45)"; cx.fill(); label("SECRET ROOM", q.x, q.y + q.r + 18, 16, "#fff"); }
    if (s.currentMap === PT.MINE_TREE_MAP) drawMineTree();
    if (s.currentMap === 3) { drawIcon("monster", 800, 500, 200); if (!s.hasTalkedToMonster) label("Click the monster", 800, 640, 22); }
    // pickup radius ring + bird
    if (s.currentMap === 0 || s.currentMap === PT.DESERT_MAP) { cx.beginPath(); cx.arc(s.player.x, s.player.y, PT.pickupProfile(s).collectRadius, 0, 7); cx.strokeStyle = "rgba(255,255,255,.25)"; cx.lineWidth = 2; cx.stroke(); }
    drawIcon("birb", s.player.x, s.player.y, 48, G.vx < -5);
    for (const f of G.floats) if (f.map === s.currentMap) { cx.globalAlpha = Math.min(1, f.life / 0.4); label(f.text, f.x, f.y, 16, f.color); cx.globalAlpha = 1; }
    if (s.currentMap === PT.DESERT_MAP && PT.sandstormOn(s)) { // Birb getDesertSandstormVisualAlpha: 1.2 s fade in and out
      const t = Math.max(0, s.desertSandstormTimeRemaining), al = Math.max(0, Math.min(1, (30 - t) / 1.2, t / 1.2));
      cx.fillStyle = `rgba(214,170,92,${0.35 * al})`; cx.fillRect(0, 0, m.w, m.h);
    }
  }
  // Birb expedition hub and floors: collision boxes, portals, enemies with HP bars, the parrot
  const ENEMY_COLOR = { boss: "#f97316", elite: "#c084fc", shiny: "#facc15" };
  function drawExpedition() {
    const s = G.s, X = PT.EXP, m = PT.MAPS[s.currentMap], run = PT.expState(s).activeRun, floor = X.MAP_FLOOR[s.currentMap];
    cx.fillStyle = floor ? ["#3f6b3a", "#5d3f74", "#a08a5a", "#2e5a6b", "#2b4a66", "#9fc4d8", "#3d5a2e", "#2b2b38", "#4a1f1f"][floor - 1] : "#1b1d24"; roundRect(0, 0, m.w, m.h, 24); cx.fill();
    if (floor) { const b = X.bounds(s.currentMap); for (let i = 0; i < 5; i++) { cx.fillStyle = `rgba(0,0,0,${0.06 * i})`; cx.fillRect(b.minX, b.minY + ((b.maxY - b.minY) * i) / 5, b.maxX - b.minX, (b.maxY - b.minY) / 5); } }
    cx.fillStyle = "rgba(10,12,16,.55)"; for (const r of X.collisions(s.currentMap)) cx.fillRect(r.left, r.top, r.right - r.left, r.bottom - r.top);
    for (const p of X.portals(s.currentMap)) {
      const on = p.type !== "next_floor" || !!run?.exitPortal?.active; if (p.type === "secret_room_enter" && !secretOpen(p)) continue;
      cx.beginPath(); cx.arc(p.x, p.y, p.r, 0, 7); cx.fillStyle = on ? (p.type === "next_floor" ? "rgba(250,204,21,.45)" : "rgba(124,58,237,.45)") : "rgba(80,80,90,.25)"; cx.fill();
      label(p.type === "enter_expedition" ? "EXPEDITION" : p.type === "return_hub" ? "RETURN" : p.type === "secret_room_enter" ? "SECRET ROOM" : p.type === "secret_room_return" ? "BACK" : on ? "NEXT FLOOR" : "BOSS FIRST", p.x, Math.max(18, p.y - p.r - 10), 16, "#fff");
    }
    if (X.isSecretRoom(s.currentMap)) { // Birb map 17: the cracked wall that leads to the Mine
      if (s.currentMap === 17) { const r = X.MINE_ENTRANCE, op = s.floorOneMineEntranceOpened === true; cx.fillStyle = op ? "#0b0c10" : X.breakActive() ? "#8a6d4a" : "#6b5a44"; cx.fillRect(r.x, r.y, r.width, r.height);
        cx.strokeStyle = op ? "#f59e0b" : "#3a2f22"; cx.lineWidth = 3; cx.strokeRect(r.x, r.y, r.width, r.height); label(op ? "MINE" : "CRACKED WALL", r.x + r.width / 2, r.y - 12, 15, op ? "#fde68a" : "#e5e7eb"); }
      const p = run?.parrot; if (p) drawIcon("parrot", p.x, p.y - 14, 36, !p.facingRight);
      if (run) for (const d of run.damageNumbers) { cx.globalAlpha = Math.min(1, d.life / 0.4); label(d.text, d.x, d.y, 15, d.color); cx.globalAlpha = 1; }
      return;
    }
    if (!run || !floor) { if (s.currentMap === PT.EXP_HUB_MAP) drawIcon("parrot", s.player.x - 40, s.player.y - 30, 34); return; }
    for (const e of run.enemies) {
      if (e.health <= 0) continue;
      const r = e.type === "mini-fly" ? 5 : e.isBoss ? 30 : e.isElite ? 20 : 14;
      cx.beginPath(); cx.arc(e.x, e.y, r, 0, 7); cx.fillStyle = e.hitFlash > 0 ? "#fff" : e.projectileKind ? "#fb923c" : e.isShiny ? ENEMY_COLOR.shiny : e.isBoss ? ENEMY_COLOR.boss : e.isElite ? ENEMY_COLOR.elite : "#d1d5db"; cx.fill();
      cx.lineWidth = 2; cx.strokeStyle = /attack|hitting/.test(e.state) ? "#ef4444" : "#0b0c10"; cx.stroke();
      if (e.type !== "mini-fly" && !e.projectileKind) { bar(e.x - 20, e.y - r - 14, 40, e.health / e.maxHealth, "#ef4444"); if (e.isBoss || e.isElite) label(e.type.replace(/-/g, " ").toUpperCase(), e.x, e.y - r - 22, 13, e.isBoss ? "#fdba74" : "#e9d5ff"); }
    }
    const p = run.parrot;
    if (p) { drawIcon("parrot", p.x, p.y - 14, 36, !p.facingRight); bar(p.x - 22, p.y - 40, 44, p.health / p.maxHealth, "#4ade80"); }
    cx.beginPath(); cx.arc(s.player.x, s.player.y, PT.EXP.K.LEASH * PT.EXP.rangeMult(), 0, 7); cx.strokeStyle = "rgba(255,255,255,.12)"; cx.lineWidth = 2; cx.stroke();
    for (const d of run.damageNumbers) { cx.globalAlpha = Math.min(1, d.life / 0.4); label(d.text, d.x, d.y, 15, d.color); cx.globalAlpha = 1; }
  }
  // Birb desert-meadow: sand field, plain and golden eggs, Dave and his sons
  function drawDesert() {
    const s = G.s, M = PT.DESERT_MAP;
    cx.fillStyle = "#e3c27a"; roundRect(0, 0, PT.DESERT_W, PT.DESERT_H, 24); cx.fill();
    cx.fillStyle = "rgba(190,140,70,.35)"; for (const [x, y, r] of [[220, 180, 90], [980, 260, 120], [420, 640, 140], [1100, 700, 80]]) { cx.beginPath(); cx.ellipse(x, y, r, r * 0.35, 0, 0, 7); cx.fill(); }
    for (const p of G.field.list(M)) { if (p.type === "golden" && p.caramel) { cx.beginPath(); cx.arc(p.x, p.y, 17, 0, 7); cx.fillStyle = "rgba(255,213,74,.35)"; cx.fill(); } drawEgg(p.x, p.y, PT.TYPES[p.type].color, p.type); }
    if (G.daves && G.daves[0]) { const a = G.daves[0]; for (const e of a.sons) drawIcon("dove", e.x, e.y - (e.state === "fly" ? 14 : 0), 24, e.face < 0); drawIcon("dove", a.x, a.y - (a.state === "fly" ? 20 : 0), 38, a.face < 0); }
  }
  function drawPine(x, y, k, hp, maxHp, active) {
    cx.fillStyle = "#6b4a2a"; cx.fillRect(x - 4 * k, y + 6 * k, 8 * k, 14 * k);
    for (let i = 0; i < 3; i++) { cx.beginPath(); cx.moveTo(x, y - 34 * k + i * 12 * k); cx.lineTo(x - (16 + 5 * i) * k, y + (i * 12 - 6) * k); cx.lineTo(x + (16 + 5 * i) * k, y + (i * 12 - 6) * k); cx.closePath(); cx.fillStyle = i % 2 ? "#2f7d3a" : "#3a9447"; cx.fill(); cx.lineWidth = 2; cx.strokeStyle = "#0b0c10"; cx.stroke(); }
    if (active) { cx.beginPath(); cx.arc(x, y, 30 * k, 0, 7); cx.strokeStyle = "#ffd27a"; cx.lineWidth = 3; cx.stroke(); }
    if (hp < maxHp) bar(x - 18, y - 46 * k, 36, hp / maxHp, "#d8a24a");
  }
  function drawNest() {
    const s = G.s, n = PT.nestState(s), f = n.forest;
    cx.fillStyle = "#6fa553"; roundRect(0, 0, 1600, 2112, 24); cx.fill();
    cx.fillStyle = "#4a8bd6"; cx.fillRect(0, 2000, 1600, 112);
    drawIcon("nest", 800, 170, 300);
    for (const t of f.trees) { const k = t.age >= 180 ? 1 : 0.35 + 0.65 * (t.age / 180); if (t.hp <= 0) cx.globalAlpha = Math.max(0, t.collapse / 0.8); drawPine(t.x, t.y, k, Math.max(0, t.hp), t.maxHp, f.activeTreeId === t.id); cx.globalAlpha = 1; }
    for (const b of n.cultivation.treeBoxes) {
      const p = PT.boxSlotPos(b.slotIndex); cx.fillStyle = "#7a4e2a"; roundRect(p.x - 50, p.y - 44, 100, 92, 10); cx.fill(); cx.lineWidth = 3; cx.strokeStyle = "#0b0c10"; cx.stroke();
    }
    const gs = PT.nestCultSnapshot(s).growthSeconds;
    for (const b of n.cultivation.treeBoxes) { const p = PT.boxSlotPos(b.slotIndex), k = (b.trees || []).length;
      (b.trees || []).forEach((t, i) => { if (t.hp <= 0) return; const x = p.x + (i % 2) * 40 - (k > 1 ? 20 : 0), y = p.y + Math.floor(i / 2) * 36 - (k > 2 ? 18 : 0);
        drawPine(x, y, 0.7 * (t.age >= gs ? 1 : 0.35 + 0.65 * (t.age / gs)), t.hp, t.maxHp, f.activeTreeId === "box" + b.slotIndex + "_" + i); });
      const g = (b.trees || []).find((t) => t.hp > 0 && t.age < gs); if (g) label(Math.ceil(gs - g.age) + "s", p.x, p.y + 40, 12); }
    if (PT.pandaAssisting(s) && G.pandaPos) drawIcon("redpanda", G.pandaPos.x, G.pandaPos.y, 40);
  }
  function drawNestRoom() {
    const s = G.s, r = PT.redPandaState(s);
    cx.fillStyle = "#5a3d24"; roundRect(0, 0, 1056, 792, 24); cx.fill();
    cx.fillStyle = "#7a5634"; roundRect(328, 300, 400, 200, 40); cx.fill();
    if (!r.introSeen || r.mode === "chill") { drawIcon("redpanda", 528, 380, 110); label(r.introSeen ? r.name + " · napping (eggs and seeds x1.25)" : "zzz...", 528, 470, 18); }
    else label(r.name + " is helping outside", 528, 400, 20, "#a2d149");
    label("Click the panda or press E", 528, 560, 16, "#ffd27a");
  }
  function drawMine() {
    const s = G.s, M = G.mine || {}, ore = M.boss || M.ore, now = Date.now();
    cx.fillStyle = "#2a2733"; roundRect(0, 0, 1056, 792, 24); cx.fill(); cx.fillStyle = "#3b3646"; roundRect(60, 600, 936, 150, 20); cx.fill();
    if (ore) {
      const R = PT.MINE_RARITY[ore.rank], sc = ore.boss ? 2.2 : 1;
      if (ore.golden) { cx.beginPath(); cx.arc(528, 520, 90 * sc, 0, 7); cx.fillStyle = "rgba(250,204,21,.25)"; cx.fill(); }
      drawIcon(ore.golden ? "ore_gold" : "ore_" + ["dirt", "iron", "stone", "crystal", "obsidian", "emerald", "ruby"][ore.tier], 528, 520, 130 * sc);
      bar(448, 520 - 90 * sc, 160, ore.hits / ore.maxHits, ore.boss ? "#ef4444" : R.color);
      label(ore.boss ? `GIANT ORE · ${Math.max(0, Math.ceil((M.bossUntil - now) / 1000))}s` : `${R.id.toUpperCase()} ${ore.tierId.toUpperCase()}${ore.golden ? " · GOLDEN" : ""}`, 528, 520 - 100 * sc, 16, ore.boss ? "#fca5a5" : R.color);
    }
    drawIcon("crow_miner", 610, 560, 70, true);
    label("Click the ore or press E to peck", 528, 720, 16, "#ffd27a");
  }
  function drawMineTree() {
    const s = G.s; cx.fillStyle = "#1f2a24"; roundRect(0, 0, 1056, 792, 24); cx.fill();
    PT.MINE_TREE.forEach((n, i) => { if (!PT.mineNodeVisible(s, n.id)) return; const x = 200 + (i % 5) * 165, y = 240 + Math.floor(i / 5) * 110, own = (s.sunflowerUpgrades["d_mine_" + n.id] || 0) > 0;
      cx.fillStyle = own ? "#3d8a3a" : PT.mineNodeUnlocked(s, n.id) ? "#c99a2e" : "#4a4f58"; roundRect(x - 70, y - 40, 140, 80, 12); cx.fill(); cx.lineWidth = 3; cx.strokeStyle = "#0b0c10"; cx.stroke(); label(n.name, x, y - 6, 14); label(own && !n.growth ? "OWNED" : "AREA " + n.area, x, y + 18, 12, "#ffe7a0"); });
    label("Click anywhere or press E for the mine tree", 528, 760, 16, "#ffd27a");
  }
  function drawAquarium() {
    const a = PT.aq(G.s);
    cx.fillStyle = "#1d3b5a"; roundRect(0, 0, 1600, 1100, 24); cx.fill();
    PT.AQ_BIOMES.forEach((b, i) => {
      const x = 120 + (i % 3) * 460, y = 200 + Math.floor(i / 3) * 260, pr = PT.aqBiome(a, b.id);
      cx.fillStyle = "#0e2236"; roundRect(x, y, 400, 220, 18); cx.fill(); cx.lineWidth = 4; cx.strokeStyle = b.color; cx.stroke();
      cx.fillStyle = b.color; cx.globalAlpha = 0.35; roundRect(x + 6, y + 220 - 6 - 208 * pr.completionRatio, 388, 208 * pr.completionRatio, 14); cx.fill(); cx.globalAlpha = 1;
      label(b.id.toUpperCase(), x + 200, y + 40, 22, b.color);
      label(`${pr.housedSpecies} / ${pr.totalSpecies} species · tier ${pr.tierCount}`, x + 200, y + 120, 16);
      label(`+${(PT.aqBiomeBuff(a, b.id) * 100).toFixed(0)}% ${b.modifierType.replace(/_mult$/, "").replace(/_/g, " ")}`, x + 200, y + 160, 15, "#c8ffb0");
    });
    label(`RESONANCE ${PT.aqPoints(a)}`, 270, 150, 24, "#ffd27a"); label("press E to donate", 1330, 150, 20, "#ffd27a");
  }
  function drawMarket() {
    cx.fillStyle = "#dfeefa"; roundRect(0, 0, 1056, 792, 24); cx.fill();
    const stall = (x, y, ic, name) => { cx.fillStyle = "#c0392b"; roundRect(x - 140, y - 90, 280, 70, 12); cx.fill(); cx.lineWidth = 4; cx.strokeStyle = "#0b0c10"; cx.stroke();
      for (let i = x - 140; i < x + 140; i += 40) { cx.fillStyle = "#f4f1ea"; cx.fillRect(i, y - 90, 20, 30); }
      cx.fillStyle = "#8a5a32"; roundRect(x - 120, y - 20, 240, 90, 10); cx.fill(); cx.stroke(); drawIcon(ic, x, y + 25, 70); label(name, x, y + 110, 18, "#0b0c10"); };
    stall(260, 420, "bait", "BAIT MERCHANT"); stall(796, 420, "quest_scroll", "FISH CONTRACTS");
    label("Press E for contracts", 528, 680, 20, "#2563eb");
  }
  function drawBridge() {
    const s = G.s, F = G.fish || {};
    cx.fillStyle = "#3a8bd6"; cx.fillRect(0, 560, 3000, 420); cx.fillStyle = "#2f74b8"; for (let x = 0; x < 3000; x += 60) cx.fillRect(x, 700 + 40 * Math.sin(x / 90 + G.t), 30, 6);
    cx.fillStyle = "#8a5a32"; cx.fillRect(0, 640, 3000, 120); cx.strokeStyle = "#0b0c10"; cx.lineWidth = 4; cx.strokeRect(0, 640, 3000, 120);
    for (let x = 0; x < 3000; x += 40) { cx.fillStyle = x % 80 ? "#9a6a3e" : "#7a4e2a"; cx.fillRect(x, 642, 38, 116); }
    cx.fillStyle = "#6b6f78"; roundRect(2260, 360, 260, 300, 16); cx.fill(); cx.stroke(); label(s.hasEnteredDungeon ? "CASTLE GATE (open)" : "CASTLE GATE", 2390, 350, 18);
    if (s.evolutionCount >= 1) label("Stand still and press SPACE to cast", 700, 610, 16);
    else label("Fishing opens at Evolution 1", 700, 610, 16);
    if (s.hasMetSeagull) s.seagull.gulls.forEach((g, i) => drawIcon("seagull", 800 + 96 * i, 560 + 10 * Math.sin(2 * G.t + i), 46));
    const p = s.player;
    if (F.casting > 0) bar(p.x - 30, p.y - 44, 60, 1 - F.casting / 0.5, "#ffd27a");
    else if (F.reeling > 0) bar(p.x - 30, p.y - 44, 60, 1 - F.reeling / Math.max(0.01, F.total), "#4fd85a");
    else if (F.cooldown > 0) bar(p.x - 30, p.y - 44, 60, 0, "#8a93a1");
    if (F.last && F.lastT > 0) { const f = F.last; label(`${PT.fishName(f.fish.id)}${f.shiny ? " SHINY" : ""} ${f.weight}kg`, p.x, p.y - 56, 15, PT.RARITY_COLOR[f.fish.rarity]); }
  }
  function bar(x, y, w, k, c) { cx.fillStyle = "#10141a"; roundRect(x, y, w, 9, 4); cx.fill(); cx.fillStyle = c; roundRect(x, y, Math.max(0, Math.min(1, k)) * w, 9, 4); cx.fill(); cx.lineWidth = 2; cx.strokeStyle = "#0b0c10"; roundRect(x, y, w, 9, 4); cx.stroke(); }
  function roundRect(x, y, w, h, r) { cx.beginPath(); cx.roundRect ? cx.roundRect(x, y, w, h, r) : cx.rect(x, y, w, h); }
  function drawIcon(n, x, y, size, flip) {
    const im = img(n); if (!im.complete || !im.naturalWidth) return;
    cx.save(); cx.translate(x, y); if (flip) cx.scale(-1, 1); cx.drawImage(im, -size / 2, -size / 2, size, size); cx.restore();
  }
  function drawEgg(x, y, color, type) {
    if (type === "plain") return drawIcon("egg", x, y, 26);
    if (type === "golden") return drawIcon("egg_golden", x, y, 28);
    cx.beginPath(); cx.ellipse(x, y, 9, 12, 0, 0, 7); cx.fillStyle = color; cx.fill(); cx.lineWidth = 2.5; cx.strokeStyle = "#0b0c10"; cx.stroke();
    cx.beginPath(); cx.ellipse(x - 3, y - 4, 2.5, 3.5, 0, 0, 7); cx.fillStyle = "rgba(255,255,255,.6)"; cx.fill();
  }
  function label(t, x, y, size, color) {
    cx.font = `${size}px "Fredoka One", sans-serif`; cx.textAlign = "center"; cx.lineJoin = "round";
    cx.lineWidth = 4; cx.strokeStyle = "#0b0c10"; cx.strokeText(t, x, y); cx.fillStyle = color || "#fff"; cx.fillText(t, x, y);
  }
  function drawSunflowerField() {
    const s = G.s;
    const plat = PT.STATIONS.find((st) => st[0] === "__platform");
    if (!desertView()) {
      cx.fillStyle = PT.hasSun(s, "d_sunflower_machine") ? "#e9c84a" : "#8a7a4a"; roundRect(plat[1], plat[2], plat[3], plat[4], 12); cx.fill(); cx.lineWidth = 3; cx.strokeStyle = "#0b0c10"; cx.stroke();
      drawIcon("seed", plat[1] + plat[3] / 2, plat[2] + 34, 44); label(PT.hasSun(s, "d_sunflower_machine") ? "SEED PLATFORM" : "LOCKED", plat[1] + plat[3] / 2, plat[2] + 74, 13);
    }
    for (const st of visibleStations()) {
      const id = st[0], def = PT.SUN.get(id), own = PT.hasSun(s, id), unl = PT.sunUnlocked(s, id);
      const c = own ? "#3d8a3a" : !unl ? "#4a4f58" : canAffordSun(id) ? "#c99a2e" : "#6a5a3a";
      cx.fillStyle = c; roundRect(st[1], st[2], st[3], st[4], 12); cx.fill(); cx.lineWidth = 3; cx.strokeStyle = "#0b0c10"; cx.stroke();
      label(title(def?.name || id).slice(0, 22), st[1] + st[3] / 2, st[2] + 30, 15);
      const cost = own ? "OWNED" : `${fmt(PT.sunCost(s, id))} ${CUR[def.costCurrency]?.name || def.costCurrency}`;
      label(cost, st[1] + st[3] / 2, st[2] + 56, 13, own ? "#c8ffb0" : "#ffe7a0");
      if (!own && def.evolutionRequired > (s.evolutionCount || 0)) label("EVO " + def.evolutionRequired, st[1] + st[3] / 2, st[2] + 78, 11, "#ff9a9a");
    }
  }
  function canAffordSun(id) { const def = PT.SUN.get(id); const c = def.costCurrency; return PT.altCurrency[c] ? PT.altCurrency[c].has(G.s, PT.sunCost(G.s, id)) : c in G.s.resources && PT.has(G.s, c, PT.sunCost(G.s, id)); }
  // ------------------------------------------------------------------ Expedition portals (Birb: hub portal opens the floor wheel; floor portals return / advance)
  // Birb tryEnterSecretRoom: floors with a secret room, not in night mode
  function secretOpen(p) { const run = PT.expState(G.s).activeRun; return !!run && !run.nightMode && !!PT.EXP.SECRET_ROOMS[run.currentFloor]; }
  function expPortalNear() {
    const s = G.s, X = PT.EXP; if (s.currentMap !== PT.EXP_HUB_MAP && !X.isRunMap(s.currentMap) && !X.isSecretRoom(s.currentMap) && s.currentMap !== PT.MINE_MAP) return null;
    for (const p of X.portals(s.currentMap)) {
      if (p.type === "next_floor" && !PT.expState(s).activeRun?.exitPortal?.active) continue;
      if (p.type === "secret_room_enter" && !secretOpen(p)) continue;
      if ((s.player.x - p.x) ** 2 + (s.player.y - p.y) ** 2 <= (p.r + 40) ** 2) return p;
    }
    return null;
  }
  function expPortalAt(x, y) { const p = expPortalNear(); return p && (x - p.x) ** 2 + (y - p.y) ** 2 <= p.r * p.r; }
  function expPortalAction() {
    const p = expPortalNear(); if (!p) return false;
    if (p.type === "enter_expedition") openWin("expfloors");
    else if (p.type === "return_hub") { const r = PT.EXP.endRun(G, false); if (r) toast(`Back at the hub: floor ${r.floor}, ${r.kills} kills`); }
    else if (p.type === "next_floor") { if (!PT.EXP.advanceFloor(G)) toast("The next floor needs Evolution 5"); }
    else if (p.type === "secret_room_enter") PT.EXP.enterSecretRoom(G);
    else if (p.type === "secret_room_return") PT.EXP.exitSecretRoom(G);
    else if (p.type === "mine_exit") PT.EXP.exitMineRoom(G);
    save(); return true;
  }
  PT.EXP.onParrotDeath = () => { const r = PT.EXP.endRun(G, false); toast(`The parrot fell on floor ${r ? r.floor : "?"}. Back to the hub.`); save(); };

  // ------------------------------------------------------------------ panels
  const panel = document.getElementById("panel"), tabsEl = document.getElementById("tabs");
  function tabs() {
    // Birb's drawer: POPCORN and REBIRB from the start, SEEDS once the Sunflower Machine is owned (updateSeedShopTabVisibility).
    const s = G.s, t = [["eggs", "EGGS", "egg"], ["molt", "MOLT", "plume"]];
    if (PT.hasSun(s, "d_sunflower_machine")) t.push(["seeds", "SEEDS", "seed"]);
    if (s.clickedMapArrows?.visited_map4) t.push(["nest", "NEST", "twig"]); // Birb updateNestShopTabVisibility
    if (PT.mineOpen(s) || PT.res(s, "bruteOre").gt(0) || s.hasSeenMineTab) t.push(["mine", "MINE", "pickaxe"]); // Birb #tab-btn-m
    if (!t.some((x) => x[0] === G.tab)) G.tab = "eggs";
    return t;
  }
  function upRow(id) {
    const s = G.s, def = PT.UP.get(id), L = PT.level(s, id), M = PT.maxLevel(s, id), maxed = L >= M;
    const cost = maxed ? 0 : PT.discounted(s, def, L), ok = !maxed && PT.has(s, def.costCurrency, cost);
    const show = (lv) => { try { return new Function("return (" + def.effectDesc + ")")()(lv); } catch (e) { return fmt(def.effectFn(lv)); } };
    const cur = CUR[def.costCurrency];
    return `<div class="row"><img class="ico" src="${ICON(UP_ICON[id] || "egg")}" alt="">
      <div><div class="t">${title(def.name)}</div><div class="g">${words(show(L))}${maxed ? "" : ` <b>›››</b> ${words(show(L + 1))}`}</div>
      <div class="d">${def.tree === "M" ? { m_ore_value: "+10% Brute Ore per HP extracted.", m_mining_power: "+10% mining damage per level.", m_charged_strike: "+1x damage to the Crow's charged peck per level." }[id] || words(def.description) : words(def.description)}</div><div class="lv">LV ${L} / ${M}</div></div>
      <div class="btns">${maxed ? `<button class="key gold">MAXED</button>` : `<button class="key ${ok ? "" : "grey"}" data-buy="${id}"><img src="${ICON(cur.icon)}" alt="">${fmt(cost)}</button>
      <button class="key small ${ok ? "violet" : "grey"}" data-max="${id}">MAX</button>`}</div></div>`;
  }
  const treeRows = (tree) => [...PT.UP.values()].filter((d) => d.tree === tree && rowVisible(d.id)).map((d) => upRow(d.id)).join("");
  function rowVisible(id) {
    const s = G.s;
    if (id === "p_golden_popcorn_value") return !!s.hasUnlockedDesertMap;
    if (id === "p_auric_silo") return PT.hasSun(s, "d_desert_auric_blueprints");
    if (id === "pr_golden_popcorn_mult") return PT.hasSun(s, "d_desert_golden_popcorn_mult_unlock");
    if (id.startsWith("m_")) return PT.mineUpShown(s, id);
    return true;
  }
  function drawPanel() {
    const s = G.s, list = tabs();
    const pend = PT.prestige(s).final;
    tabsEl.innerHTML = list.map(([k, n, ic]) => `<button class="tab ${G.tab === k ? "on" : ""}" data-tab="${k}"><img src="${ICON(ic)}" alt="">${n}${k === "molt" && pend.gte(1) ? `<span class="badge">+${fmt(pend)}</span>` : ""}</button>`).join("");
    let h = "";
    if (G.tab === "eggs") {
      // Birb POPCORN tab: a popcorn / golden popcorn switch once golden-priced upgrades exist
      const gold = [...PT.UP.values()].some((d) => d.tree === "P" && d.costCurrency === "goldenPopcorn" && rowVisible(d.id));
      if (!gold) G.eggView = "popcorn";
      const sw = gold ? `<div class="devrow">${[["popcorn", "egg", "EGGS"], ["goldenPopcorn", "egg_golden", "GOLDEN"]].map(([k, ic, l]) => `<button class="tab ${G.eggView === k ? "on" : ""}" data-eview="${k}"><img src="${ICON(ic)}" alt="">${l}</button>`).join("")}</div>` : "";
      h = `${sw}${[...PT.UP.values()].filter((d) => d.tree === "P" && d.costCurrency === G.eggView && rowVisible(d.id)).map((d) => upRow(d.id)).join("")}
      <div class="note">Molting resets eggs and these upgrades. Plumes are forever.</div>`;
    } else if (G.tab === "molt") {
      const p = PT.prestige(s), ok = p.final.gte(1);
      h = `<div class="reset"><div class="big">RESET YOUR EGGS</div>
      <div class="gain">+${fmt(p.final)}<img src="${ICON("plume")}" alt=""></div>
      <button class="key wide ${ok ? "gold" : "grey"}" data-act="molt">MOLT</button>
      <div class="note">${fmt(s.resources.goldenFeathers)} plumes · molted ${s.rebirthCount} times · 1 plume per 1,000 eggs</div></div>
      <div class="section">PLUME KEEPSAKES</div>${treeRows("PR")}<div class="note">Molting resets eggs and egg upgrades. Plumes and keepsakes are kept until you Evolve.</div>`;
    } else if (G.tab === "nest") h = nestPanel();
    else if (G.tab === "mine") {
      const st = { area: PT.mineArea(s), dmg: PT.crowDamage(s), value: PT.mineOreValue(s), iv: PT.crowInterval(s) };
      h = `<div class="note">Area ${st.area} · ${fmt(st.value * PT.mineUa(st.area) * st.dmg)} Brute Ore base per peck · Crow damage ${fmt(st.dmg)} every ${st.iv.toFixed(2)}s · ${PT.mineState(s).goldOre} Gold Ore</div>${treeRows("M")}
        <div class="note">Mine upgrades, the mine tree and the Crow's level reset on Evolve. Crow rebirbs stay.</div>`;
    }
    else if (G.tab === "seeds") {
      const sr = PT.seedRate(s, true);
      h = `${treeRows("S")}<div class="note">${fmt(sr.ticksPerSec * sr.perTick)} seeds / s on the platform${PT.hasSun(s, "d_auto_gen") ? " (auto generator: always on)" : ""}</div><div class="note">Evolving resets seeds and these upgrades.</div>`;
    }
    if (panel.dataset.last !== h) { const y = panel.scrollTop; panel.innerHTML = h; panel.scrollTop = y; panel.dataset.last = h; }
  }
  // Birb nest shop: SHOP (planting beds, buildings, twig upgrades) / LAKE (fish breeding) / OWNED
  G.nestView = "shop"; G.eggView = "popcorn";
  function nestPanel() {
    const s = G.s, n = PT.nestState(s), sn = PT.nestCultSnapshot(s), tw = PT.res(s, "twigs");
    const views = [["shop", "SHOP"], ...(PT.breedVisible(s) ? [["lake", "LAKE"]] : []), ["owned", "OWNED " + PT.NEST_SPECIALS.filter((x) => n.cultivation.specialUpgrades[x.id]).length]];
    const sw = `<div class="devrow">${views.map(([k, l]) => `<button class="tab ${G.nestView === k ? "on" : ""}" data-nview="${k}">${l}</button>`).join("")}</div>`;
    if (G.nestView === "lake") return sw + lakePanel();
    if (G.nestView === "owned") return sw + (PT.NEST_SPECIALS.filter((x) => n.cultivation.specialUpgrades[x.id]).map((x) => `<div class="row"><img class="ico" src="${ICON("nest")}" alt=""><div><div class="t">${x.name}</div><div class="d">${x.text}</div></div><div class="btns"><button class="key small gold">OWNED</button></div></div>`).join("") || '<div class="note">Nothing owned yet.</div>');
    const specials = PT.NEST_SPECIALS.filter((x) => !n.cultivation.specialUpgrades[x.id] && x.visible(s, n.cultivation)).map((x) =>
      `<div class="row"><img class="ico" src="${ICON("nest")}" alt=""><div><div class="t">${x.name}</div><div class="d">${x.text}</div></div><div class="btns"><button class="key ${tw.gte(x.cost) ? "" : "grey"}" data-nspec="${x.id}"><img src="${ICON("twig")}" alt="">${fmt(x.cost)}</button></div></div>`).join("");
    const boxCur = sn.treeBoxCostCurrency === "twigs" ? "twig" : "plume";
    const box = sn.treeBoxMaxed ? "" : `<div class="row"><img class="ico" src="${ICON("nest")}" alt=""><div><div class="t">${title(sn.phase)}</div><div class="d">${sn.phase === "TREE BOX" ? "Grows a tree outside the Nest." : sn.phase.startsWith("EVOLVE") ? (sn.phase.includes("QUAD") ? "Unlocks transforming double beds into quad beds." + (sn.quadRequirementMet ? "" : " REQUIRES NEST TIER 2") : "Unlocks transforming tree boxes into double boxes.") : sn.phase === "SPECIALIZED TREE BOX" ? "Adds +1 tree to each box." : "Adds +2 trees to each planting bed."}</div>
      <div class="lv">${sn.phaseLevel !== null ? sn.phaseLevel + " / 16 · " : ""}${sn.growthSeconds}s to grow · ${sn.treeHp} hits</div></div>
      <div class="btns"><button class="key ${PT.has(s, sn.treeBoxCostCurrency, sn.treeBoxCost) ? "" : "grey"}" data-nest="box"><img src="${ICON(boxCur)}" alt="">${fmt(sn.treeBoxCost)}</button></div></div>`;
    const exp = sn.expansionVisible && !sn.expansionMaxed ? `<div class="row"><img class="ico" src="${ICON("nest")}" alt=""><div><div class="t">Planting Bed Expansion</div><div class="d">Adds a planting bed prepared for 4 trees.</div><div class="lv">${sn.expansionCount} / 8</div></div><div class="btns"><button class="key ${tw.gte(sn.expansionCost) ? "" : "grey"}" data-nest="exp"><img src="${ICON("twig")}" alt="">${fmt(sn.expansionCost)}</button></div></div>` : "";
    const ups = Object.entries(PT.NEST_UPS).filter(([id]) => PT.nestUpVisible(s, id)).map(([id, u]) => {
      const L = PT.nestUpLevel(s, id), maxed = L >= u.max, c = maxed ? 0 : u.cost(L), ok = !maxed && tw.gte(c);
      const show = (lv) => (id === "n_twig_value" ? fmt(PT.nestTwigPerPeck(s, lv)) + " per hit" : id === "n_peck_rate" ? PT.nestHitRate(s, lv).toFixed(2) + " hits/s" : PT.nestPeckDamage(s, lv) + " damage");
      return `<div class="row"><img class="ico" src="${ICON("twig")}" alt=""><div><div class="t">${u.name}</div><div class="g">${show(L)}${maxed ? "" : ` <b>›››</b> ${show(L + 1)}`}</div><div class="d">${u.text}</div><div class="lv">LV ${L} / ${u.max}</div></div>
        <div class="btns">${maxed ? `<button class="key gold">MAXED</button>` : `<button class="key ${ok ? "" : "grey"}" data-nup="${id}"><img src="${ICON("twig")}" alt="">${fmt(c)}</button><button class="key small ${ok ? "violet" : "grey"}" data-nupmax="${id}">MAX</button>`}</div></div>`;
    }).join("");
    const auto = PT.nestAutomationUnlocked(s) ? `<div class="section">AUTOMATION (Nest level 3)</div><div class="devrow"><label><input type="checkbox" data-in="nautop" ${n.autoPopcornEnabled ? "checked" : ""}> auto egg upgrades</label><label><input type="checkbox" data-in="nautos" ${n.autoSeedsEnabled ? "checked" : ""}> auto seed upgrades</label>${PT.goldenAutomationUnlocked(s) ? `<label><input type="checkbox" data-in="nautog" ${n.autoGoldenPopcornEnabled ? "checked" : ""}> auto golden egg upgrades</label>` : ""}</div>` : "";
    return sw + `<div class="note">${fmt(tw)} twigs · ${fmt(PT.nestTwigsPerSec(s))} twigs/s possible · ${PT.NEST_TIERS[n.tier].name} (x${PT.nestResourceMult(s)})</div>${box}${exp}${specials}${ups}${auto}`;
  }
  G.breedPick = ["", ""];
  function lakePanel() {
    const s = G.s, bs = PT.nestState(s).fishBreeding;
    if (!bs.unlocked) return `<div class="row"><img class="ico" src="${ICON("aquarium")}" alt=""><div><div class="t">Fish Breeding</div><div class="d">Breed fish and speed up hatching by fishing. Needs Evolution 5 and 600 aquarium resonance.</div></div><div class="btns"><button class="key ${PT.res(s, "twigs").gte(1e6) ? "" : "grey"}" data-act="breedunlock"><img src="${ICON("twig")}" alt="">1M</button></div></div>`;
    PT.breedSyncReserve(s);
    const cands = PT.breedCandidates(s), opt = (i) => `<select data-breed="${i}"><option value="">parent ${i ? "B" : "A"}</option>${cands.map((r) => `<option value="${r.fishId}" ${G.breedPick[i] === r.fishId ? "selected" : ""}>${PT.fishName(r.fishId)} x${r.count}</option>`).join("")}</select>`;
    const pv = PT.breedPreview(s, G.breedPick[0], G.breedPick[1]), now = Date.now(), inc = bs.incubation;
    const rar = ["common", "uncommon", "rare", "epic", "legendary"];
    const incH = inc ? `<div class="hero"><div class="big">${inc.hatchAt > now ? "HYBRID FORMING" : "HYBRID READY TO HATCH"}</div><div class="sub">${PT.fishName(inc.parentAId)} × ${PT.fishName(inc.parentBId)} · ${inc.hatchAt > now ? PT.fmtTime((inc.hatchAt - now) / 1000) + " left · fishing speeds it up (same species 5s, same biome 2s, any 1s, shiny -40%)" : `<b style="color:${PT.RARITY_COLOR[inc.resultRarity]}">${inc.resultRarity}</b>${inc.resultShiny ? " SHINY" : ""}`}</div>
      ${inc.hatchAt <= now ? `<div class="devrow" style="justify-content:center"><button class="key small gold" data-act="breedclaim">HATCH</button>${bs.hybrids.map((h) => `<button class="key small blue" data-bfuse="${h.id}">FUSE into ${h.rarity}</button>`).join("")}<button class="key small grey" data-act="breeddiscard">DISCARD</button></div>` : ""}</div>` : "";
    const hy = bs.hybrids.map((h) => `<div class="row"><img class="ico" src="${FISHICON(h.dominantParentId)}" alt=""><div><div class="t" style="color:${PT.RARITY_COLOR[h.rarity]}">${h.shiny ? "★ " : ""}${PT.fishName(h.parentAId)} × ${PT.fishName(h.parentBId)}</div><div class="d">${h.rarity} · lineage ${h.lineagePoints}/100 · ${h.id === bs.activeHybridId ? "ACTIVE" : "reserve"}</div></div><div class="btns"></div></div>`).join("");
    return `${incH}${inc ? "" : `<div class="devrow">${opt(0)}${opt(1)}</div>${pv.monetaCost ? `<div class="note">Cost ${fmt(pv.monetaCost)} moneta · odds ${pv.odds.map((o, i) => rar[i] + " " + o + "%").join(", ")} · shiny ${pv.shinyChance}%${pv.shinyProgress ? " · lineage shiny " + pv.shinyProgress + "/100" : ""}</div>` : ""}
      <button class="key ${pv.valid ? "" : "grey"}" data-act="breedstart">BREED (both parents are consumed)${pv.reason && pv.monetaCost ? " · " + pv.reason : ""}</button>`}
      <div class="section">HYBRIDS (${bs.hybrids.length}/${bs.reserveSlotUnlocked ? 2 : 1})</div>${hy || '<div class="note">No hybrids yet. The active hybrid gives its parents\' fish bonuses.</div>'}`;
  }
  function crowPanel() {
    const s = G.s, m = PT.mineState(s), need = PT.crowXpNeeded(m.crowLevel), n = m.crowRebirbCount, req = PT.crowRebirbReq(s);
    const gold = (() => { const d = PT.mineCampaign(s).oreDiscoveries[PT.mineArea(s)] || {}; return d.pendingGolden ? 30 : Math.min(30, d.goldWork || 0); })();
    const dps = PT.crowDamage(s) / PT.crowInterval(s), r = n >= 8 ? 2 : 1.25;
    const rb = PT.crowRebirbUnlocked(s) ? `<div class="section">REBIRB (${n}/${PT.mineHas(s, "deep_rebirb") ? "∞" : 8})</div>
      <div class="kv"><span>DPS</span><span>${fmt(dps)} → ${fmt(req ? dps * r : dps)}</span><span>Rare ores</span><span>x${(1 + 0.1 * n).toFixed(2)} → x${(1 + 0.1 * (n + 1)).toFixed(2)}</span><span>Gold</span><span>x${(1 + 0.15 * n).toFixed(2)} → x${(1 + 0.15 * (n + 1)).toFixed(2)}</span><span>XP</span><span>x${Math.pow(1.25, n).toFixed(2)} → x${Math.pow(1.25, n + 1).toFixed(2)}</span></div>
      ${req ? `<div class="note">${m.crowLevel >= req.level ? "✔" : "✗"} LV ${req.level} · ${PT.mineArea(s) >= req.giants ? "✔" : "✗"} Giant ${req.giants} · LV → 1 · XP → 0 (keeps learned speed)</div>
      <button class="key ${PT.crowCanRebirb(s) ? "violet" : "grey"}" data-act="crowrebirb">REBIRB</button>` : `<div class="note">MAXED</div>`}` : `<div class="note">Buy Crow Rebirb (free) in the Treasure Room to unlock rebirbs.</div>`;
    return `<div class="hero"><img src="${ICON("crow_miner")}" alt=""><div class="big">LV ${m.crowLevel}</div><div class="bar"><i style="width:${Math.min(100, (m.crowXp / need) * 100)}%"></i></div>
      <div class="sub">XP ${fmt(m.crowXp)} / ${fmt(need)} · Peck ${PT.crowInterval(s).toFixed(2)}s · TRAINING LV ${m.crowTrainingLevel}${PT.crowRebirbUnlocked(s) ? ` · Next gold ${Math.round(gold * 10) / 10} / 30` : ""}</div></div>${rb}
      <div class="note">The Crow mines automatically, also while you are elsewhere. Rebirb needs Crow levels and Mine giants.</div>`;
  }
  function mineTreePanel() {
    const s = G.s;
    return `<div class="note">${fmt(PT.res(s, "bruteOre"))} Brute Ore · ${PT.mineState(s).goldOre} Gold Ore · area ${PT.mineArea(s)}</div>` + PT.MINE_TREE.filter((n) => PT.mineNodeVisible(s, n.id)).map((n) => {
      const L = s.sunflowerUpgrades["d_mine_" + n.id] || 0, own = L > 0 && !n.growth, c = PT.mineNodeCost(s, n.id), unl = PT.mineNodeUnlocked(s, n.id);
      return `<div class="row"><img class="ico" src="${ICON(n.cur === "goldOre" ? "goldore" : "ore")}" alt=""><div><div class="t">${n.name}${n.growth ? " LV " + L : ""}</div><div class="d">${n.text}</div><div class="lv">AREA ${n.area}${n.evo ? " · EVOLUTION " + n.evo : ""}</div></div>
        <div class="btns">${own ? `<button class="key small gold">OWNED</button>` : `<button class="key small ${unl ? "" : "grey"}" data-mnode="${n.id}">${c === 0 ? "FREE" : fmt(c) + (n.cur === "goldOre" ? " gold" : "")}</button>`}</div></div>`;
    }).join("");
  }
  // Birb parrot menu: STATS (level, HP, damage, regen, skill points), SKILLS (spend points: Vitality / Recovery / Strength), and the rebirb table
  G.spAmt = 1;
  // Birb parrot INVENTORY: artifacts (equip into 3-5 slots, 2 copies max), materials (aura), potions, equipment chests
  function parrotInventory() {
    const s = G.s, X = PT.EXP, p = PT.parrotState(s), eq = new Set(p.equippedArtifacts.filter(Boolean)), ch = X.chestCounts(s), ca = X.invCapacity(s, "artifact"), cm = X.invCapacity(s, "material");
    const RC = { common: "#cbd5e1", uncommon: "#4ade80", rare: "#60a5fa", epic: "#c084fc", legendary: "#facc15", mythic: "#f472b6" };
    const stat = (d) => Object.entries(d.stats || {}).map(([k, v]) => `+${Math.round(v * 100)}% ${k.replace("Mult", "").replace("maxHealth", "HP").replace("lifeRegen", "regen")}`).join(" · ") + (d.effectId ? ` · ${d.effectId.replace(/_/g, " ")}` : "");
    const row = (it) => { const d = X.itemByName(it.name) || {}, on = eq.has(it.instanceId) || p.relicSlot === it.instanceId, mat = d.inventoryCategory === "material", pot = d.type === "consumable";
      const btn = mat ? "" : pot ? `<button class="key small ${p.potionSlot === it.instanceId ? "gold" : "grey"}" data-act="inv_pot:${it.instanceId}">${p.potionSlot === it.instanceId ? "SLOTTED" : "SLOT"}</button>`
        : `<button class="key small ${on ? "gold" : ""}" data-act="inv_${on ? "off" : "on"}:${it.instanceId}">${on ? "EQUIPPED" : "EQUIP"}</button><button class="key small red" data-act="inv_drop:${it.instanceId}">✕</button>`;
      return `<div class="row"><div><div class="t" style="color:${RC[d.rarity] || "#fff"}">${it.name}${(it.count || 1) > 1 ? " ×" + fmt(it.count) : ""}${it.infusionLevel ? " +" + it.infusionLevel : ""}</div><div class="d">${d.rarity || ""} ${stat(d)}</div></div><div class="btns">${btn}</div></div>`; };
    const chests = Object.entries(ch).filter(([, n]) => n > 0).map(([r, n]) => `<button class="key small" data-act="inv_chest:${r}" style="color:${RC[r]}">OPEN ${r.toUpperCase()} ×${n}</button>`).join("");
    const arts = p.artifactInventory.filter((it) => { const d = X.itemByName(it.name); return d && d.inventoryCategory !== "material" && d.type !== "consumable"; });
    const pots = p.artifactInventory.filter((it) => X.itemByName(it.name)?.type === "consumable"), mats = p.artifactInventory.filter((it) => X.itemByName(it.name)?.inventoryCategory === "material");
    const run = PT.expState(s).activeRun, par = run?.parrot;
    return `<div class="section">EQUIPPED ${eq.size} / ${X.slotCount(s)} · ARTIFACTS ${ca.used} / ${ca.max} · MATERIALS ${cm.used} / ${cm.max}</div>
      ${chests ? `<div class="devrow" style="flex-wrap:wrap">${chests}</div>` : `<div class="note">Bosses and elites drop equipment chests.</div>`}
      <div class="section">ARTIFACTS</div>${arts.map(row).join("") || `<div class="note">None yet.</div>`}
      <div class="section">POTIONS ${par ? `· <button class="key small ${(par.potionCooldown || 0) > 0 ? "grey" : ""}" data-act="inv_use">USE (H)</button>` : ""}</div>${pots.map(row).join("") || `<div class="note">2% of kills drop a potion.</div>`}
      ${PT.hasSun(s, "d_desert_auto_potion") ? `<div class="devrow"><label><input type="checkbox" data-in="autopot" ${p.autoPotionEnabled ? "checked" : ""}> auto potion below ${PT.EXP.autoPotionThreshold(s)}% HP</label></div>` : ""}
      <div class="section">MATERIALS</div>${mats.map(row).join("") || `<div class="note">Kills drop Spirit Aura.</div>`}
      ${forgePanel(arts)}`;
  }
  // Birb forge: gear (upgrade / evolve / refine), aura convert 50 -> 1 and dismantle 1 -> 25, infuse, fuse three of one rarity
  function forgePanel(arts) {
    const s = G.s, X = PT.EXP, p = PT.parrotState(s); if (!X.forgeUnlocked(s)) return `<div class="section">FORGE</div><div class="note">Reach sacrifice milestone I to open the forge.</div>`;
    const auraLbl = (id) => (id ? X.itemById(id).name.replace(" Spirit Aura", "").replace("Spirit Aura", "Common") : "");
    const gear = ["beak", "armor", "aura"].map((k) => { const g = p.equipmentUpgrades[k], pl = X.gearPlan(s, k), m = X.gearMult(s, k);
      const cost = [pl.cost ? `${fmt(pl.cost)} ${auraLbl(pl.currency)} aura` : "", pl.gold ? `${fmt(pl.gold)} Gold Ore` : "", pl.area ? `mine area ${pl.area}` : ""].filter(Boolean).join(" + ");
      return `<div class="row"><div><div class="t">${k.toUpperCase()} · ${g.rarity.toUpperCase()} ${g.level}${pl.action === "refine" ? ` · REFINED ${X.refineLevel(s, k)}` : ""} · x${m.toFixed(2)}</div><div class="d">${pl.action.toUpperCase()}: ${cost || "free"}</div></div>
        <div class="btns"><button class="key small" data-act="frg_gear:${k}">${pl.action === "evolve" ? "EVOLVE" : pl.action === "refine" ? "REFINE" : "UP"}</button></div></div>`; }).join("");
    const auras = Object.values(X.AURA_ID).map((id) => { const n = X.itemCount(s, X.itemById(id).name), c = X.convertBounds(s, id), d = X.dismantleBounds(s, id); if (!n) return "";
      return `<div class="row"><div><div class="t">${X.itemById(id).name} ×${fmt(n)}</div></div><div class="btns">${c.max ? `<button class="key small" data-act="frg_conv:${id}:${c.max}">CONVERT ×${fmt(c.max)}</button>` : ""}${d.max ? `<button class="key small grey" data-act="frg_dis:${id}:1">DISMANTLE 1</button>` : ""}</div></div>`; }).join("");
    G.fuseSel = (G.fuseSel || []).filter((id) => arts.some((a) => a.instanceId === id));
    const inf = arts.map((it) => { const f = X.infusionInfo(s, it.instanceId); if (!f) return ""; const on = G.fuseSel.includes(it.instanceId);
      return `<div class="row"><div><div class="t">${it.name} +${f.currentLevel}/${f.maxLevel}</div><div class="d">${f.currentLevel < f.maxLevel ? `next: ${fmt(f.cost)} ${auraLbl(f.auraId)} aura` : "maxed"}</div></div><div class="btns">
        <button class="key small ${f.canInfuse ? "" : "grey"}" data-act="frg_inf:${it.instanceId}">INFUSE</button><button class="key small ${on ? "gold" : "grey"}" data-act="frg_sel:${it.instanceId}">${on ? "✔" : "FUSE?"}</button></div></div>`; }).join("");
    const fc = X.fusionCheck(s, G.fuseSel);
    return `<div class="section">FORGE · GEAR</div>${gear}<div class="section">AURA</div>${auras || `<div class="note">No aura yet.</div>`}
      <div class="section">INFUSE / FUSE (${G.fuseSel.length}/3)</div>${inf}<div class="devrow"><button class="key ${fc.valid ? "" : "grey"}" data-act="frg_fuse" style="flex:1">FUSE ${fc.valid ? `→ ${fc.targetRarity.toUpperCase()} (${fmt(fc.auraCost)} aura)` : `· ${fc.reason}`}</button></div>`;
  }
  function parrotPanel(tab) {
    const s = G.s, p = PT.parrotState(s), e = PT.expState(s), pr = e.progress, st = PT.parrotTotalStats(s), kv = (a, b) => `<span>${a}</span><span>${b}</span>`;
    const head = `<div class="hero"><img src="${ICON("parrot")}" alt=""><div class="big">LV ${pr.level}</div><div class="bar"><i style="width:${Math.min(100, (pr.xp / pr.xpToNextLevel) * 100)}%"></i></div><div class="sub">XP ${fmt(Math.floor(pr.xp))} / ${fmt(pr.xpToNextLevel)} · ${fmt(p.skillPoints)} skill points to spend · rebirb ${p.rebirbCount}</div></div>`;
    if (tab === "skills") {
      const row = (k, n, d) => `<div class="row"><img class="ico" src="${ICON(k === "hp" ? "stat_heart" : k === "damage" ? "stat_sword" : "heart")}" alt=""><div><div class="t">${n}</div><div class="d">${d}</div></div><div class="btns"><b style="color:#f1c40f;font-size:18px">${fmt(p.skills[k])}</b><button class="key small ${p.skillPoints >= 1 ? "" : "grey"}" data-pspend="${k}">+</button></div></div>`;
      return head + `<div class="devrow">${[1, 10, 100, "25%", "50%", "max"].map((a) => `<button class="key small ${G.spAmt === a ? "" : "grey"}" data-spamt="${a}">${String(a).toUpperCase()}</button>`).join("")}</div>
        ${row("hp", "VITALITY", "+1 max HP per point")}${row("lifeRegen", "RECOVERY", "+1 HP regen / s per point")}${row("damage", "STRENGTH", "+1 damage per point")}
        <div class="note">Skill points come from kills (and Field Notes). Each point spent also counts as parrot XP when earned. Birb labels the reset in chests but it keeps ${PT.parrotResetCost(s)} of the invested points.</div>
        <div class="devrow"><button class="key small red" data-act="inv_reset" style="flex:1">RESET SKILLS (REFUND ALL BUT ${fmt(PT.parrotResetCost(s))})</button></div>`;
    }
    if (tab === "rebirb") {
      const rows = [["I", "Evolution 4 and floor 3", "skill points x2"], ["II", "floor 7", "skill points x4, +0.1% per parrot level, enemy respawns x0.5"], ["III", "defeat the Archivist", "skill points x8"]];
      return head + rows.map(([n, need, gain], i) => `<div class="row"><img class="ico" src="${ICON("parrot")}" alt=""><div><div class="t">REBIRB ${n}</div><div class="d">Needs ${need} · best floor ${e.highestFloorReached}</div><div class="lv">${gain}</div></div><div class="btns">${p.rebirbCount > i ? `<button class="key small gold">DONE</button>` : p.rebirbCount === i ? `<button class="key small ${PT.parrotRebirbReady(s) ? "violet" : "grey"}" data-act="parrotrebirb">REBIRB</button>` : ""}</div></div>`).join("")
        + `<div class="note">A rebirb resets the parrot's level, skill points, skills and gear upgrades. The Legendary Key is kept.</div>`;
    }
    const B = PT.EXP.parrotBonuses(s);
    return head + `<div class="kv">${kv("Max HP", fmt(st.hp))}${kv("Damage", fmt(st.damage))}${kv("HP regen", fmt(st.lifeRegen) + "/s")}${kv("Attack speed", "x" + st.attackSpeed.toFixed(2))}${kv("Move speed", "x" + st.moveSpeed.toFixed(2))}
      ${kv("Skill point gain", "x" + (1 + B.skillPointMult).toFixed(2))}${kv("Gear", ["beak", "armor", "aura"].map((k) => k + " " + p.equipmentUpgrades[k].rarity + " " + p.equipmentUpgrades[k].level).join(" · "))}
      ${kv("Best floor", e.highestFloorReached)}${kv("Runs", e.totalRuns)}${kv("Kills", e.totalEnemiesDefeated)}${kv("Legendary Keys", p.strangeKeys)}</div>
      <div class="note">HP regen drops to 25% for 3 s after taking damage. Base 100 HP and 100 damage, times beak (damage), armor (HP) and aura (regen).</div>`;
  }
  // Birb floor wheel: pick a start floor up to your best floor (9 floors from Evolution 5, else 3)
  function expFloorsPanel() {
    const s = G.s, e = PT.expState(s), max = Math.min(e.highestFloorReached || 1, PT.EXP.maxFloorForEvo(s)), cd = e.enemyRespawnCooldowns;
    const rows = []; for (let f = 1; f <= PT.EXP.maxFloorForEvo(s); f++) { const key = PT.EXP.bossKey(PT.EXP.FLOOR_MAP[f], f), left = Math.max(0, ((cd[key] || 0) - Date.now()) / 1000), boss = PT.EXP.PLAN[f - 1].boss;
      rows.push(`<div class="row"><img class="ico" src="${ICON("map")}" alt=""><div><div class="t">FLOOR ${f}</div><div class="d">Boss: ${boss.replace(/-/g, " ")}${left > 0 ? " · respawns in " + PT.fmtTime(left) : ""}</div></div><div class="btns"><button class="key ${f <= max ? "" : "grey"}" data-expfloor="${f}">${f <= max ? "START" : "LOCKED"}</button></div></div>`); }
    return `<div class="note">The parrot fights near you (450 px leash). Move or click an enemy to start combat; AUTO lets it pick targets. Defeat the floor boss to open the next floor.</div>${rows.join("")}`;
  }
  // Birb collared-dove menu: LV + XP bar, stats row (XP/min, forage size, golden bonus, travel speed, rebirbs),
  // SEED SNACKS, REBIRB (Travel / Forage / Gilded with +, RESET, x1 / x10 / MAX), MILESTONES n / 8 (folds open)
  G.daveAmt = 1; G.daveMilestones = false;
  // Birb Sacrifice Room (map 8): sacrifice skill points toward milestone tiers I-XVIII
  function sacrificePanel() {
    const s = G.s, X = PT.EXP, lv = X.sacLevel(s), pr = X.sacProgress(s), p = PT.parrotState(s), max = X.sacMaxUnlocked(s), T = X.SACRIFICE_TIERS;
    const eff = (t) => [`aura qty x${t.auraQuantityMultiplier}`, `aura chance x${t.auraChanceMultiplier}`, `SP x${t.skillPointMultiplier}`, `popcorn x${t.popcornMultiplier}`, `seeds x${t.seedMultiplier}`,
      t.parrotRadiusMultiplier > 1 ? `radius x${t.parrotRadiusMultiplier}` : "", t.parrotAttackSpeedMultiplier > 1 ? `speed x${t.parrotAttackSpeedMultiplier}` : "", t.auraRarityPromotionChance ? `promote ${t.auraRarityPromotionChance * 100}%` : ""].filter(Boolean).join(" · ");
    const rows = T.map((t, i) => `<div class="note" style="opacity:${i < max ? 1 : 0.45}">${i < lv ? "✔" : i < max ? "○" : "🔒"} <b>${t.label}</b> (${fmt(t.cost)} SP): ${eff(t)}</div>`).join("");
    const can = pr.target > 0 && p.skillPoints >= 1;
    return `<div class="hero"><div class="big">${lv ? T[lv - 1].label : "-"}</div><div class="bar"><i style="width:${pr.cost ? Math.min(100, (pr.progress / pr.cost) * 100) : 100}%"></i></div>
      <div class="sub">${pr.target ? `${fmt(pr.progress)} / ${fmt(pr.cost)} SP to ${T[pr.level - 1].label}` : lv >= 18 ? "ALL MILESTONES" : max === 3 ? "Unlock the expansion for IV-VI" : "Parrot rebirb I opens VII-XVIII"} · you have ${fmt(Math.floor(p.skillPoints))} SP</div></div>
      <div class="devrow">${["all", "half", "quarter"].map((m) => `<button class="key ${can ? "" : "grey"}" data-act="sac_${m}" style="flex:1">${m.toUpperCase()}</button>`).join("")}</div>
      ${X.canUnlockSacExpansion(s) ? `<div class="devrow"><button class="key" data-act="sac_expand" style="flex:1">EXPANSION · 50 Spirit Aura (have ${X.itemCount(s, "Spirit Aura")})</button></div>` : ""}
      <div class="section">MILESTONES</div>${rows}`;
  }
  function davePanel() {
    const s = G.s, d = PT.dave(s), need = PT.daveXpNeeded(d.level), I = d.instincts, c = PT.daveSeedCost(d.seedTrainingLevel), pts = d.unspentRebirbPoints || 0;
    const got = PT.DAVE_MILESTONES.filter(([, r]) => PT.daveRebirbs(s) >= r).length, xpm = (G.rates.daveXp || 0) * 60;
    const stat = (k, v) => `<div class="biome"><b>${v}</b>${k}</div>`;
    const inst = (k, n, eff) => `<div class="row"><img class="ico" src="${ICON("dove")}" alt=""><div><div class="t">${n}</div><div class="d">${eff}</div></div><div class="btns"><b style="color:#f4d03f;font-size:20px">${I[k] || 0}</b>
      <button class="key small ${pts > 0 || PT.daveCanRebirb(s) ? "" : "grey"}" ${pts > 0 ? `data-dspend="${k}"` : `data-drebirb="${k}"`} title="${pts > 0 ? "Spend points" : "Rebirb into " + n}">+</button></div></div>`;
    return `<div class="hero"><div class="big">LV ${d.level}</div><div class="bar"><i style="width:${Math.min(100, (d.xp / need) * 100)}%"></i></div><div class="sub">XP: ${fmt(Math.floor(d.xp))} / ${fmt(need)}</div></div>
      <div class="biomes">${stat("XP / min", fmt(xpm))}${stat("forage size", PT.daveSweepSize(s))}${stat("golden bonus", "x" + PT.daveGoldenMult(s).toFixed(2))}${stat("travel speed", "+" + Math.round((PT.daveSpeedMult(s) - 1) * 100) + "%")}${stat("rebirbs", d.rebirbCount)}</div>
      <div class="section">SEED SNACKS · LEVEL ${d.seedTrainingLevel}</div>
      <div class="devrow"><span class="note">+${Math.round((PT.daveXpGainMult(s) - 1) * 100)}% XP gain › +${Math.round((PT.daveXpGainMult(s) - 0.92) * 100)}% XP gain</span><button class="key ${PT.res(s, "sunflowerSeeds").gte(c) ? "" : "grey"}" data-act="davetrain">${fmt(c)}<img src="${ICON("seed")}" alt=""></button></div>
      <div class="section">REBIRB · needs LV 100 (level -100, XP kept as a fraction)${PT.daveRebirbs(s) >= 100 ? " · MAXED" : ""}</div>
      ${inst("scavenger", "TRAVEL", `Travel +${Math.round(30 * (I.scavenger || 0))}% speed`)}${inst("sweep", "FORAGE", `Forage size +${20 * (I.sweep || 0)}`)}${inst("gilded", "GILDED", `Gold x${(1 + (I.gilded || 0)).toFixed(2)}`)}
      <div class="devrow"><button class="key small ${pts > 0 ? "grey" : "red"}" data-act="daverefund" style="flex:1">RESET${pts > 0 ? ` (${pts} UNSPENT)` : ""}</button>${[1, 10, "max"].map((a) => `<button class="key small ${G.daveAmt === a ? "" : "grey"}" data-damt="${a}">${a === "max" ? "MAX" : "X" + a}</button>`).join("")}</div>
      ${PT.daveMilestone(s, "workRhythm") ? `<div class="devrow"><label><input type="checkbox" data-in="daveauto" ${d.autoRebirbEnabled ? "checked" : ""} ${pts > 0 ? "disabled" : ""}> auto rebirb (${(d.autoRebirbInstinct || "pick one").toUpperCase()})</label></div>` : ""}
      <button class="section" data-act="davems" style="width:100%;text-align:left;background:none;border:0;color:inherit;cursor:pointer">MILESTONES ${got} / 8 ${G.daveMilestones ? "▴" : "▾"}</button>
      ${G.daveMilestones ? PT.DAVE_MILESTONES.map(([id, r, t]) => `<div class="note">${PT.daveRebirbs(s) >= r ? "✔" : "○"} <b>${r}</b>: ${t}</div>`).join("") : ""}
      <div class="note">Dave scavenges the Desert in clustered swoops, also while you are away. Golden eggs give 5 XP (x2 with Gilded Lessons), plain eggs 1 XP (x2 with Steady Pecking).</div>`;
  }
  function pandaPanel() {
    const s = G.s, r = PT.redPandaState(s);
    if (!r.introSeen) return `<div class="hero"><img src="${ICON("redpanda")}" alt=""><div class="big">NAME THE RED PANDA</div><div class="sub">It looks like it has been guarding the grain stores.</div>
      <div class="devrow" style="justify-content:center"><input data-in="pandaname" maxlength="12" placeholder="Red Panda"><button class="key" data-act="pandaname">OK</button></div></div>`;
    return `<div class="hero"><img src="${ICON("redpanda")}" alt=""><div class="big">${r.name.toUpperCase()}</div><div class="sub">Tier ${r.tier} · ${r.mode === "assist" ? "helping outside" : "napping in the nest"}</div>
      <div class="devrow" style="justify-content:center"><button class="key ${r.mode === "assist" ? "gold" : ""}" data-panda="assist">HELP</button><button class="key ${r.mode === "chill" ? "gold" : ""}" data-panda="chill">NAP</button></div></div>
      <div class="note"><b>HELP</b>: chops trees in the Nest at ${PT.nestCompanionDps(s).toFixed(2)} hits/s; anywhere else it gathers 55% of that, ${fmt(0.55 * PT.nestTwigsPerSec(s, "companion"))} twigs/s, also while the game is closed (up to 8 h).</div>
      <div class="note"><b>NAP</b>: eggs and seeds x1.25.</div>`;
  }
  function sunRow(id) {
    const s = G.s, def = PT.SUN.get(id), own = PT.hasSun(s, id), unl = PT.sunUnlocked(s, id), c = PT.sunCost(s, id);
    const cur = CUR[def.costCurrency] || { name: def.costCurrency, icon: "chest" };
    const ok = !own && unl && canAffordSun(id);
    return `<div class="row"><img class="ico" src="${ICON(cur.icon)}" alt=""><div><div class="t">${title(def.name || id)}</div>
      <div class="d">${words(def.description || "")}</div><div class="lv">${own ? "OWNED" : !unl ? "LOCKED" + (def.evolutionRequired > s.evolutionCount ? " · needs Evolution " + def.evolutionRequired : "") : (def.maxLevel > 1 ? `LV ${PT.sunLevel(s, id)} / ${def.maxLevel}` : "ONE-TIME")}</div></div>
      <div class="btns">${own && PT.sunLevel(s, id) >= (def.maxLevel || 1) ? `<button class="key gold">OWNED</button>` : `<button class="key ${ok ? "" : "grey"}" data-sun="${id}"><img src="${ICON(cur.icon)}" alt="">${fmt(c)}</button>`}</div></div>`;
  }
  function sparrowPanel() {
    const s = G.s, sp = s.sparrow, need = PT.sparrowXpNeeded(sp.level), feat = s.evolutionCount >= 2;
    const total = PT.sparrowTotalXp(sp.level, sp.xp), mneed = PT.mitosisNeed(s, s.sparrowCount);
    return `<div class="hero"><img src="${ICON("sparrow")}" alt=""><div class="big">THE SPARROW</div>
      <div class="sub">LV ${sp.level} · ${s.sparrowCount} sparrow${s.sparrowCount > 1 ? "s" : ""} · ${fmt(sp.xp)} / ${fmt(need)} XP · speed ${Math.round(PT.sparrowSpeed(s))} px/s</div>
      <div class="bar"><i style="width:${Math.min(100, (sp.xp / need) * 100)}%"></i></div></div>
      <div class="note">Sparrows collect eggs on the Park field (also while you are away). Each egg gives XP by type: plain 1, butter 2, caramel 3, cheese 5, rainbow 10.</div>
      <div class="section">SEED FEEDER</div>
      ${PT.hasSun(s, "d_seed_feeder") ? `<div class="devrow"><button class="key ${s.isFeedingSparrow ? "violet" : ""}" data-act="feed">${s.isFeedingSparrow ? "Stop feeding" : "Feed seeds"}</button>
        <span class="note">share of seed income</span><input type="number" min="1" max="100" value="${s.sparrowSeedFeedRatePercent}" data-in="feedpct" style="width:64px">%</div>
        <div class="note">XP per seed ${PT.seedFeedXp(s).toFixed(4)} · seed income ${fmt(G.rates.sunflowerSeeds || 0)}/s</div>` : `<div class="note">Unlock Seed Feeder in the sunflower tree.</div>`}
      <div class="section">RESONANCE</div>
      ${feat && PT.hasSun(s, "d_sparrow_drain_power") ? `<button class="key ${s.isDrainingSparrow ? "violet" : ""}" data-act="drain">${s.isDrainingSparrow ? "Stop draining" : "Drain levels"}</button>
        <div class="note">Resonance ${fmt(s.sparrowResonanceXP)} XP → eggs and seeds x${PT.sparrowDrainMult(s).toFixed(3)}</div>` : `<div class="note">Needs Evolution 2 and Sparrow Drain Power.</div>`}
      <div class="section">MITOSIS AND REBIRB</div>
      ${PT.hasSun(s, "d_sparrow_mitosis") ? `<div class="note">Total XP ${fmt(total)} / ${fmt(mneed)}</div>
        ${s.sparrowCount < 16 ? `<button class="key ${total >= mneed ? "" : "grey"}" data-act="mitosis">Mitosis (${s.sparrowCount} → ${s.sparrowCount * 2})</button>` :
        `<button class="key ${total >= mneed && PT.sparrowRebirbReady(s) ? "" : "grey"}" data-act="srebirb">Rebirb (back to 1, +1 rebirb)${PT.sparrowRebirbReady(s) ? "" : " · needs nest tier 1"}</button>`}
        <div class="devrow"><label><input type="checkbox" data-in="automitosis" ${s.sparrowAutoMitosisEnabled ? "checked" : ""}> auto mitosis</label>
        <label><input type="checkbox" data-in="autorebirb" ${s.sparrowAutoRebirbEnabled ? "checked" : ""}> auto rebirb</label></div>` : `<div class="note">Unlock Sparrow Mitosis in the sunflower tree (Evolution 3).</div>`}
      <div class="note">Rebirbs ${s.sparrowPrestigeCount} · egg spawns x${PT.sparrowRebirbBoost(s).toFixed(2)}</div>
      <div class="section">MILESTONES (Evolution 2+)</div>
      ${PT.SPARROW_MILESTONES.map((m) => `<div class="note">${PT.milestoneMet(s, m) ? "✔" : "○"} <b>${m.name}</b>: ${m.text}</div>`).join("")}`;
  }
  // Birb castle: satisfaction bar and HOLD TO FEED over the map, plus the five evolution stages.
  const EVO_STAGES = [
    ["Stage 1: Genesis", "Unlocks fishing, more tree upgrades and egg automation"],
    ["Stage 2: Exodus", "More upgrades, resources x Evolution"],
    ["Stage 3: Leviticus", "Unlocks fishing automation, more tree upgrades, the Nest"],
    ["Stage 4: Numbers", "Unlocks nest upgrades, the Expedition, the Desert map, new upgrade trees"],
    ["Stage 5: Deuteronomy", "The hell opens, unlocks the Aquarium"],
  ];
  function castleHtml() {
    const s = G.s;
    if (s.currentMap !== 3) return "";
    const stages = EVO_STAGES.map(([n, d], i) => `<div class="stage ${s.evolutionCount > i ? "done" : ""}"><b>[${s.evolutionCount > i ? "x" : " "}] ${n}</b><br>${d}</div>`).join("");
    if (!s.hasTalkedToMonster) return `<div class="section">THE MONSTER</div><div class="note">Click the monster to talk to it.</div>${stages}`;
    if (s.evolutionCount >= 5) return `<div class="section">FULLY EVOLVED</div>${stages}`;
    const n = PT.evoReq(s.evolutionCount), pr = PT.feedProgress(s), can = PT.canEvolveStage(s);
    const line = (name, fed, need) => need > 0 ? `<div class="note"><b>${name}</b> ${fmt(fed)} / ${fmt(need)}<div class="bar"><i style="width:${Math.min(100, (fed / need) * 100)}%"></i></div></div>` : "";
    return `<div class="section">SATISFACTION ${pr.toFixed(1)}%</div><div class="bar"><i style="width:${Math.min(100, pr)}%"></i></div>
      ${line("Eggs", s.monsterPopcornFed, n.popcorn)}${line("Plumes", s.monsterFeathersFed, n.feathers)}${line("Seeds", s.monsterSeedsFed, n.seeds)}
      ${line("Fish", s.monsterFishFed, n.fish)}${line("Twigs", s.monsterTwigsFed, n.twigs)}${line("Moneta", s.monsterMonetaFed, n.moneta)}
      ${pr >= 100 && can ? `<button class="key wide violet" data-act="evolve">EVOLVE</button>` : `<button class="key wide ${can ? "" : "grey"}" data-hold="feed">${can ? "HOLD TO FEED" : "Unlock Evolve in the sunflower tree"}</button>`}
      <div style="height:6px"></div>${stages}`;
  }
  function statsPanel() {
    const s = G.s, p = PT.prestige(s), prof = PT.pickupProfile(s), sr = PT.seedRate(s, true);
    const kv = (a, b) => `<span>${a}</span><span>${b}</span>`;
    return `<div class="kv">
      ${kv("Egg multiplier", "x" + fmt(PT.totalMultiplier(s)))}${kv("Spawn interval", PT.spawnInterval(s).toFixed(3) + " s")}
      ${kv("Field cap", PT.maxPopcorn(s))}${kv("On field", G.field.list(0).length)}${kv("Pickup radius", prof.collectRadius.toFixed(1) + " px")}
      ${kv("Max speed", PT.maxSpeed(s).toFixed(1) + " px/s")}${kv("Eggs / s", fmt(G.rates.popcorn || 0))}${kv("Seeds / s (platform)", fmt(sr.ticksPerSec * sr.perTick))}
      ${kv("Molt base (eggs/1000)", fmt(p.base))}${kv("Molt multiplier", (p.a * p.pay).toFixed(3))}${kv("Playtime x", p.play.toFixed(2))}
      ${kv("Sparrow drain x", PT.sparrowDrainMult(s).toFixed(3))}${kv("Evolutions", s.evolutionCount)}${kv("Molts", s.rebirthCount)}
      ${kv("Total eggs collected", fmt(s.totalPopcornCollected))}${kv("Play time", PT.fmtTime(s.playTime))}
      ${PT.desertUnlocked(s) ? kv("Desert golden chance", (PT.desertGoldenChance(s) * 100).toFixed(1) + "%") + kv("Desert spawn interval", PT.desertSpawnInterval(s).toFixed(3) + " s") + kv("Golden eggs / drop", fmt(PT.goldenPerDrop(s))) + kv("Desert egg multiplier", "x" + fmt(PT.desertEggMult(s))) + kv("Total golden eggs", fmt(s.totalGoldenPopcornCollected || 0)) : ""}</div>
      <div class="note">Every number here comes from the same formulas as Birb. Compare with the Roblox build to spot differences.</div>`;
  }
  const RANK = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4, mythic: 5 };
  const fishFilter = { rarity: "", type: "" };
  function fishCollection() {
    const s = G.s;
    PT.normalizeFishBuffs(s);
    const buffs = s.activeFishIds.map((id) => { const fi = PT.FISH_BY.get(PT.baseFishId(id)); return `<div class="note">● ${PT.fishName(id)}: ${fi.effect.type} x${fi.effect.value}${PT.isShiny(id) ? " (x" + (1 + 3 * (fi.effect.value - 1)).toFixed(2) + " for 24h)" : ""}</div>`; }).join("");
    const rows = s.fishInventory.filter((r) => r.count > 0).map((r) => ({ r, fi: PT.FISH_BY.get(PT.baseFishId(r.fishId)) }))
      .filter(({ fi }) => (!fishFilter.rarity || fi.rarity === fishFilter.rarity) && (!fishFilter.type || (fi.type || "expedition") === fishFilter.type))
      .sort((a, b) => RANK[b.fi.rarity] - RANK[a.fi.rarity]).slice(0, 80).map(({ r: row, fi }) =>
        `<div class="row"><img class="ico" src="${FISHICON(row.fishId)}" onerror="this.src='${ICON("fish")}'" alt=""><div><div class="t" style="color:${PT.RARITY_COLOR[fi.rarity]}">${PT.fishName(row.fishId)} x${row.count}</div>
        <div class="d">${fi.rarity} · ${fi.type || "expedition"} · eat: ${fi.effect.type} x${fi.effect.value} · sells ${fmt(PT.sellValue(s, row.fishId))} seeds</div></div>
        <div class="btns"><button class="key small" data-eat="${row.fishId}">EAT</button><button class="key small ${s.lockedFish.includes(fi.id) ? "violet" : "grey"}" data-lock="${fi.id}">${s.lockedFish.includes(fi.id) ? "LOCKED" : "LOCK"}</button></div></div>`).join("");
    const opt = (k, list) => `<select data-ff="${k}"><option value="">${k === "rarity" ? "RARITIES" : "TYPES"}</option>${list.map((x) => `<option ${fishFilter[k] === x ? "selected" : ""}>${x}</option>`).join("")}</select>`;
    return `<div class="filters">${opt("rarity", Object.keys(RANK))}${opt("type", [...new Set(PT.FISH.map((f) => f.type || "expedition"))])}
      <button class="key small ${PT.hasSun(s, "d_fish_seeds") ? "gold" : "grey"}" data-act="sellsafe">SAFE SELL</button></div>
      <div class="section">ACTIVE FISH BUFFS (${s.activeFishIds.length} / ${PT.maxFishBuffs(s)})</div>${buffs || '<div class="note">Eat a fish to get its effect. Shiny fish give 4x the bonus for 24h.</div>'}
      <div class="section">FISH (${s.fishInventory.reduce((a, r) => a + r.count, 0)})</div>${rows || '<div class="note">No fish caught!</div>'}
      <div class="note">Selling pays seeds and needs the Fish Seeds unlock. Safe sell keeps fish needed for rods, tackle and fish-priced sunflower nodes, plus locked and shiny fish.</div>`;
  }
  const rodIcon = (id) => "rod_" + id.replace(/^rod_/, "");
  function fishEquipment() {
    const s = G.s, f = PT.ensureFishing(s);
    const nextRod = PT.RODS.find((r) => !f.ownedRods.includes(r.id));
    const rods = PT.RODS.filter((r) => f.ownedRods.includes(r.id) || r === nextRod).map((r) => {
      const own = f.ownedRods.includes(r.id), eq = f.equippedRodId === r.id;
      const cost = r.cost.map((c) => `${PT.fishName(c.fishId)} ${Math.min(PT.speciesCount(s, c.fishId), c.count)}/${c.count}`).join(", ");
      return `<div class="row"><img class="ico" src="${ICON(rodIcon(r.id))}" alt=""><div><div class="t">${PT.itemName(r.id)} Rod</div>
        <div class="d">tier ${r.tier} · speed ${r.speedBonus} · ${r.monetaPerCatch} moneta/catch${r.evolutionRequired ? " · Evo " + r.evolutionRequired : ""}</div>${own ? "" : `<div class="lv">${cost || "free"}</div>`}</div>
        <div class="btns"><button class="key ${own ? (eq ? "gold" : "") : "blue"}" data-rod="${r.id}">${own ? (eq ? "EQUIPPED" : "EQUIP") : "CRAFT"}</button></div></div>`;
    }).join("");
    const tackle = PT.TACKLE.filter((t) => !t.shiny && (s.evolutionCount || 0) + 1 >= (t.evolutionRequired || 0)).map((t) => {
      const req = PT.tackleReq(s, t), owned = t.type === "hook" ? f.unlockedHooks.includes(t.id) : t.type === "lure" ? f.unlockedLures.includes(t.id) : (f.baitInventory.find((b) => b.baitId === t.id)?.count || 0);
      const eq = [f.equippedBaitId, f.equippedHookId, f.equippedLureId].includes(t.id);
      const cost = t.cost.map((c) => `${c.count} ${c.type === "currency" ? (CUR[c.id]?.name || c.id) : PT.fishName(c.id)}`).join(", ");
      const eff = t.effect.type === "type_boost" ? `only ${t.effect.targetType} fish` : t.effect.type === "specific_fish" ? `x${t.effect.value} for ${t.effect.targetFish.map(PT.fishName).join(", ")}` : `${t.effect.type} ${t.effect.value ?? ""}${t.effect.targetType ? " (" + t.effect.targetType + ")" : ""}`;
      return `<div class="row"><img class="ico" src="${ICON(t.id)}" alt=""><div><div class="t">${PT.itemName(t.id)} <span class="lv">${t.type}</span></div>
        <div class="d">${eff}</div><div class="lv">${req ? req.toUpperCase() : t.type === "consumable" ? "owned " + owned + " · cost " + cost : owned ? "OWNED" : "cost " + cost}</div></div>
        <div class="btns">${t.type === "consumable" || !owned ? `<button class="key small ${req ? "grey" : ""}" data-tbuy="${t.id}">${t.type === "consumable" ? "BUY 10" : "UNLOCK"}</button>` : ""}
        ${owned ? `<button class="key small ${eq ? "gold" : "blue"}" data-teq="${t.id}">${eq ? "ON" : "EQUIP"}</button>` : ""}</div></div>`;
    }).join("");
    return `<div class="note">Reel time comes from your fastest owned rod (${PT.reelDuration(s).toFixed(2)}s), Moneta from your richest. Cooldown ${PT.fishCooldown(s).toFixed(2)}s.</div>
      <div class="section">RODS</div>${rods}<div class="section">BAIT, HOOKS AND LURES</div>${tackle}`;
  }
  function fishDex() {
    const s = G.s, disc = new Set(s.discoveredFish || []), sh = new Set(s.discoveredShinyFish || []);
    const cells = [...PT.FISH].sort((a, b) => (a.minTier || 0) - (b.minTier || 0) || RANK[a.rarity] - RANK[b.rarity]).map((fi) => {
      const got = disc.has(fi.id), rec = (s.fishWeightRecords || []).find((r) => r.fishId === fi.id);
      return `<div class="${got ? "" : "no"}" title="${fi.rarity} · ${fi.type || "expedition"}"><img src="${FISHICON(fi.id)}" alt=""><br><span style="color:${PT.RARITY_COLOR[fi.rarity]}">${got ? PT.fishName(fi.id) : "???"}</span>${sh.has(fi.id) ? " ★" : ""}${rec ? `<br>${rec.weightKg} kg` : ""}</div>`;
    }).join("");
    return `<div class="note">${disc.size} / ${PT.FISH.length} species · trophy bonus from your heaviest fish (${PT.highestFishWeight(s)} kg)</div><div class="dex">${cells}</div>`;
  }
  function seagullPanel() {
    const s = G.s, sg = s.seagull, now = Date.now();
    const fid = PT.forecastAt(sg.forecastTimelineMs), fc = PT.SEAGULL_FORECAST[fid];
    const gulls = sg.gulls.map((g, i) => {
      const iv = PT.gullInterval(s, i), spec = i === 2 && sg.migrationCount >= 30, lc = g.lastCatchSummary;
      return `<div class="row"><img class="ico" src="${ICON("seagull")}" alt=""><div><div class="t">Gull ${i + 1}${spec ? " · Specialist" : ""}</div>
        <div class="d">catch every ${iv.toFixed(2)}s · next in ${Math.max(0, iv - (g.progressSeconds || 0)).toFixed(1)}s</div>
        <div class="lv">${lc ? `last: ${PT.fishName(lc.id)}${lc.shiny ? " (shiny)" : ""} ${lc.weight}kg` : ""}</div></div>
        <div class="btns">${spec ? `<button class="key small gold">BALANCED</button>` : `<select data-doc="${i}">${["balanced", "hunter", "training"].map((d) => `<option ${g.doctrine === d ? "selected" : ""}>${d}</option>`).join("")}</select>`}</div></div>`;
    }).join("");
    const frenzy = PT.frenzyOn(s, now) ? `Frenzy ${Math.ceil((sg.frenzyActiveUntil - now) / 1000)}s` : (sg.frenzyCooldownUntil || 0) > now ? `Frenzy ready in ${PT.fmtTime((sg.frenzyCooldownUntil - now) / 1000)}` : "Frenzy (x2 speed)";
    return `<div class="hero"><img src="${ICON("seagull")}" alt=""><div class="big">THE SEAGULL</div>
      <div class="sub">LV ${sg.level} / ${PT.gullCap(s)} · ${fmt(sg.xp)} / ${fmt(PT.gullXpNeeded(sg.level))} XP · ${sg.migrationCount} migrations</div>
      <div class="sub">Forecast this hour: <b>${fid.replace(/_/g, " ")}</b> (favours ${fc.fav === "*" ? "a rotating doctrine" : fc.fav})</div>
      <div class="devrow" style="justify-content:center"><button class="key ${sg.level >= PT.migrateLevel(s) ? "violet" : "grey"}" data-act="migrate">Migrate (needs LV ${PT.migrateLevel(s)})</button>
      <button class="key ${sg.migrationCount >= 1 ? "" : "grey"}" data-act="frenzy">${frenzy}</button></div>
      ${sg.migrationCount >= 50 ? `<label class="note"><input type="checkbox" data-in="gullauto" ${sg.autoRebirbEnabled ? "checked" : ""}> auto migrate</label>` : ""}</div>
      <div class="section">GULLS</div>${gulls}
      <div class="section">MILESTONES</div>
      ${[[1, "Frenzy"], [3, "Second gull"], [5, "Ancestral wisdom: 5% of gull XP to the Sparrow"], [10, "Instinct: migrate needs LV 50"], [15, "8% echo double catch"], [30, "Specialist third gull (rare+, x2.5 interval)"], [50, "Daily legendary every 24h, auto migrate, migrate needs LV 100"], [75, "+0.4 shiny chance per hour since the last shiny"], [100, "Alpha: migration bonuses x2"]]
        .map(([n, t]) => `<div class="note">${sg.migrationCount >= n ? "✔" : "○"} ${n}: ${t}</div>`).join("")}
      <div class="note">Gulls fish on their own every interval: 10 × 0.99^LV / (1 + 0.02 × migrations), times doctrine and forecast. They use your bait-free roll with your lure and hook, and pay 25% Moneta.</div>`;
  }
  const s_hasDesert = () => !!G.s.hasUnlockedDesertMap;
  function devPanel() {
    const curs = Object.keys(G.s.resources).map((k) => `<option value="${k}">${CUR[k]?.name || k}</option>`).join("");
    return `<div class="dev">
      <div class="devrow">Speed ${[1, 10, 100, 1000].map((x) => `<button class="key small ${G.timeScale === x ? "violet" : ""}" data-speed="${x}">x${x}</button>`).join("")}</div>
      <div class="devrow"><select data-in="givecur">${curs}</select><input data-in="giveamt" value="1e6" style="width:90px"><button class="key small" data-act="give">Give</button></div>
      <div class="devrow"><button class="key small" data-act="evo+">Evolution +1 (no reset)</button><button class="key small" data-act="allsun">Own all visible unlocks</button><button class="key small" data-act="fish50">+50 random fish</button></div>
      <div class="devrow"><label><input type="checkbox" data-in="community" ${PT.COMMUNITY.twigGain > 1 ? "checked" : ""}> Birb community goal active (twigs x1.5, a live server event)</label></div>
      <div class="devrow"><button class="key small" data-act="export">Export save</button><button class="key small" data-act="import">Import save</button><button class="key small grey" data-act="wipe">Wipe save</button></div>
      <textarea data-in="savebox" placeholder="Export puts the save here. Paste a save and press Import.">${saveBox}</textarea>
      ${s_hasDesert() ? `<div class="devrow"><button class="key small" data-act="treeview">Show the ${desertView() ? "sunflower" : "desert"} tree</button></div>` : ""}
      <div class="note">Done: the Park, Molt, seeds and the sunflower tree, the Sparrow, Castle evolutions, Bridge fishing and the Seagull. Also done: the Aquarium, Fish Market and the Nest (forest, planting beds, buildings, Red Panda, offline twigs, fish breeding). Riverside and the sawmill (Evolution 6), the mine, the desert, the expedition and the echo field come in later phases; their nodes show "needs ..." until then.</div></div>`;
  }

  // ------------------------------------------------------------------ windows (Birb: managed windows over the map)
  const winEl = document.getElementById("win"), winBody = document.getElementById("win-body"), winTabs = document.getElementById("win-tabs");
  const WINS = {
    fishing: { title: "FISHING", tabs: [["collection", "COLLECTION"], ["equipment", "EQUIPMENT"], ["fishdex", "FISHDEX"]], body: (t) => (t === "equipment" ? fishEquipment() : t === "fishdex" ? fishDex() : fishCollection()) },
    sparrow: { title: "SPARROW", body: () => sparrowPanel() },
    seagull: { title: "SEAGULL", body: () => seagullPanel() },
    profile: { title: "PROFILE", body: () => statsPanel() },
    settings: { title: "SETTINGS", body: () => devPanel() },
    travel: { title: "FAST TRAVEL", body: () => travelPanel() },
    aquarium: { title: "AQUARIUM", tabs: [["biomes", "BIOMES"], ["resonance", "RESONANCE"], ["total", "TOTAL"], ["market", "FISH MARKET"]], body: (t) => (t === "resonance" ? aqResonance() : t === "total" ? aqTotal() : t === "market" ? marketPanel() : aqBiomes()) },
    market: { title: "FISH MARKET", body: () => marketPanel() },
    redpanda: { title: "RED PANDA", body: () => pandaPanel() },
    crow: { title: "CROW", body: () => crowPanel() },
    dove: { title: "DAVE", body: () => davePanel() },
    parrot: { title: "PARROT", tabs: [["stats", "STATS"], ["skills", "SKILLS"], ["gear", "INVENTORY"], ["rebirb", "REBIRB"]], body: (t) => (t === "gear" ? parrotInventory() : parrotPanel(t)) },
    expfloors: { title: "EXPEDITION", body: () => expFloorsPanel() },
    minetree: { title: "TREASURE ROOM", body: () => mineTreePanel() },
    sacrifice: { title: "SACRIFICE", body: () => sacrificePanel() },
    quests: { title: "OBJECTIVES", tabs: [["active", "QUESTS"], ["index", "QUEST INDEX"], ["bonus", "BONUSES"]], body: (t) => questPanel(t) },
  };
  // Birb objectives window, quests part (the quest merchant opens with the desert node d_desert_quest_merchant)
  const QSTAT = { seed_gain_mult: "seed gain", popcorn_gain_mult: "popcorn gain", twig_gain_mult: "twig gain", feather_gain_mult: "feather gain", expedition_damage_mult: "parrot damage", expedition_hp_mult: "parrot HP",
    expedition_skill_point_mult: "skill points", expedition_chest_chance_flat: "chest chance", expedition_chest_reward_mult: "chest rewards", pickup_radius_mult: "pickup radius" };
  function questPanel(t) {
    const s = G.s, X = PT.EXP; if (!PT.hasSun(s, "d_desert_quest_merchant")) return `<div class="note">The quest merchant opens with the desert node "Quest Merchant".</div>`;
    X.questSync(s); const m = X.questState(s), Q = X.QUESTS;
    const goal = (d) => d.metric === "kills_by_floor" ? `Defeat enemies on floor ${d.floor}` : d.metric === "boss_clears_by_floor" ? `Defeat the floor ${d.floor} boss` : `Defeat ${d.enemyType.replace(/-/g, " ")}s`;
    const row = (d) => { const c = X.questProgress(s, d), tg = X.questTarget(s, d), done = X.questCompleted(s, d), pin = (m.pinnedQuestIds || []).includes(d.id);
      return `<div class="row"><img class="ico" src="${ICON("quest_scroll")}" alt=""><div><div class="t">${d.id.replace(/^(daily|main)_/, "").replace(/_/g, " ").toUpperCase()} <span class="d">${d.questType}</span></div>
        <div class="d">${goal(d)}: ${PT.fmt(Math.min(c, tg))} / ${PT.fmt(tg)} · +${+(d.rewardValue * 100).toFixed(2)}% ${QSTAT[d.rewardStat]}</div><div class="bar"><i style="width:${Math.min(100, (c / tg) * 100)}%"></i></div></div>
        <div class="btns">${done ? `<button class="key small gold">DONE</button>` : `<button class="key small ${pin ? "blue" : "grey"}" data-qpin="${d.id}">${pin ? "PINNED" : "PIN"}</button>`}</div></div>`; };
    if (t === "bonus") return `<div class="kv">${Q.BONUS_STATS.map((k) => `<span>${QSTAT[k]}</span><span>+${+(X.questMerchantBonus(s, k) * 100).toFixed(2)}%</span>`).join("")}</div>`;
    if (t === "index") return ["floor_kill", "enemy_hunt", "boss_clear"].map((f) => `<div class="section">${f.replace("_", " ").toUpperCase()}</div>` + [...Q.DAILY, ...Q.MAIN].filter((d) => d.family === f && X.questVisible(s, d)).map(row).join("")).join("");
    const act = m.activeQuestIds.map((id) => Q.BY_ID[id]).filter((d) => d && !X.questCompleted(s, d));
    return `<div class="hero"><div class="big">${X.questCompletedCount(s)} / ${X.questTotalCount(s)} COMPLETE</div><div class="sub">New daily quests in ${PT.fmtTime(X.questTimeUntilRefresh(s) / 1000)}</div></div>${act.map(row).join("") || '<div class="note">All quests done.</div>'}`;
  }
  // Birb aquarium window: BIOMES (donate per biome), RESONANCE (milestones), TOTAL (all bonuses)
  function aqBiomes() {
    const s = G.s, a = PT.aq(s), here = s.currentMap === PT.AQUARIUM_MAP;
    const bs = PT.AQ_BIOMES.map((b) => { const pr = PT.aqBiome(a, b.id); return `<button class="biome ${a.activeBiomeId === b.id ? "on" : ""}" data-biome="${b.id}"><b style="color:${b.color}">${b.id.toUpperCase()}</b>${pr.housedSpecies}/${pr.totalSpecies} · tier ${pr.tierCount}/${pr.maxTierCount}<br>+${(PT.aqBiomeBuff(a, b.id) * 100).toFixed(0)}% ${b.modifierType.replace(/_mult$/, "").replace(/_/g, " ")}</button>`; }).join("");
    const b = PT.AQ_BIOMES.find((x) => x.id === a.activeBiomeId);
    const rows = PT.FISH.filter((f) => f.type && b.fishTypes.includes(f.type)).sort((x, y) => RANK[x.rarity] - RANK[y.rarity]).map((f) => {
      const h = PT.aqHoused(a, f.id), sh = PT.aqShinyStored(a, f.id), pn = PT.aqDonatePreview(s, f.id, false), ps = PT.aqDonatePreview(s, f.id, true);
      return `<div class="row"><img class="ico" src="${FISHICON(f.id)}" style="${h ? "" : "filter:brightness(0) opacity(.5)"}" alt=""><div><div class="t" style="color:${PT.RARITY_COLOR[f.rarity]}">${(s.discoveredFish || []).includes(f.id) ? PT.fishName(f.id) : "???"}${sh ? " ★" : ""}</div>
        <div class="d">${f.rarity} · ${h ? (sh ? "shiny donated" : "donated") : "not donated"} · ${pn.availableCount} owned (${pn.usableCount} safe)${ps.availableCount ? " · " + ps.availableCount + " shiny" : ""}</div>
        <div class="lv">ref. weight ${PT.aqRefWeight(s, f.id).toFixed(2)} kg${sh ? ` · +${(PT.aqWeightBonus(PT.aqRefWeight(s, f.id)) * 100).toFixed(3)}% shiny` : ""}</div></div>
        <div class="btns">${h ? "" : `<button class="key small ${pn.canDonate ? "" : "grey"}" data-donate="${f.id}" title="${pn.reason || ""}">DONATE +${pn.pointsGain}</button>`}
        ${sh ? "" : `<button class="key small ${ps.canDonate ? "gold" : "grey"}" data-donates="${f.id}" title="${ps.reason || ""}">SHINY +${ps.pointsGain}</button>`}</div></div>`;
    }).join("");
    const all = PT.aqDonateAllPreview(s);
    return `<div class="note">${here ? "Donate one of each fish to house it. Shiny donations count double." : "Travel to the Aquarium (down from the Bridge) to donate."} Resonance <b>${PT.aqPoints(a)}</b>.</div>
      <div class="biomes">${bs}</div><div class="devrow"><button class="key small ${all.length ? "" : "grey"}" data-act="donateall">DONATE ALL (${all.length})</button></div>${rows}`;
  }
  function aqResonance() {
    const a = PT.aq(G.s), pts = PT.aqPoints(a), got = new Set(PT.aqMilestones(a).map((m) => m.id));
    return `<div class="note">Resonance ${pts}: each housed species gives 1 (common) to 6 (mythic) points, x2 if its shiny is donated. ${PT.aqHousedCount(a)} species housed, ${PT.aqShinyCount(a)} shiny.</div>
      ${[...PT.AQ_MILESTONES].sort((x, y) => x.points - y.points).map((m) => `<div class="row"><img class="ico" src="${ICON("aquarium")}" alt=""><div><div class="t">${m.title}</div><div class="d">${m.text}</div><div class="bar"><i style="width:${Math.min(100, (pts / m.points) * 100)}%"></i></div></div>
        <div class="btns"><button class="key small ${got.has(m.id) ? "gold" : "grey"}">${got.has(m.id) ? "REACHED" : pts + " / " + m.points}</button></div></div>`).join("")}`;
  }
  function aqTotal() {
    const s = G.s, kv = (a, b) => `<span>${a}</span><span>${b}</span>`;
    const types = ["popcorn_mult", "feather_mult", "seed_mult", "golden_popcorn_mult", "speed_mult", "pickup_mult", "reel_speed_mult", "xp_mult", "parrot_damage_mult"];
    const a = PT.aq(s), tiers = PT.AQ_BIOMES.reduce((n, b) => n + PT.aqBiome(a, b.id).tierCount, 0);
    const card = (k, v) => `<div class="biome"><b>${v}</b>${k}</div>`;
    return `<div class="biomes">${card("housed species", PT.aqHousedCount(a))}${card("shiny species", PT.aqShinyCount(a))}${card("resonance points", PT.aqPoints(a))}${card("biome tiers", tiers)}</div>
      <div class="section">AQUARIUM TOTAL</div><div class="kv">${types.map((t) => kv(t.replace(/_mult$/, "").replace(/_/g, " "), "x" + PT.aqModifier(s, t).toFixed(3))).join("")}
      ${kv("shiny chance", "x" + PT.aqShinyChanceMult(s).toFixed(4))}${kv("normal fish buffs", "x" + PT.aqNormalBuffMult(s).toFixed(2))}
      ${kv("shiny buff duration", PT.aqShinyBuffMs(s) / 3600e3 + " h")}${kv("extra fish buff slots", PT.aqBuffSlots(s))}${kv("fish market", PT.fishMarketUnlocked(s) ? "open" : "locked")}</div>`;
  }
  // Birb fish market: daily contracts (3 offers), reputation levels, accepted slots, rerolls, timed buffs
  function marketPanel() {
    const s = G.s; if (!PT.fishMarketUnlocked(s)) return `<div class="note">The Fish Market opens at 700 aquarium resonance.</div>`;
    PT.marketSync(s); const m = PT.market(s), rp = PT.repProgress(s), now = Date.now();
    const req = (q) => { const o = PT.contractOwned(s, q); return `<div class="req ${o >= q.count ? "ok" : ""}"><img src="${FISHICON(q.fishId)}" alt="">${q.shiny ? "★ " : ""}${PT.fishName(q.fishId)} ${Math.min(o, q.count)}/${q.count}</div>`; };
    const rew = (r) => `<b style="color:${PT.RARITY_COLOR[r.rarity]}">${r.rarity}</b> · ${r.buffType.replace(/_mult$/, "").replace(/_/g, " ").toUpperCase()} x${(1 + r.value).toFixed(2)} for ${PT.fmtTime(r.durationMs / 1000)} · +${r.reputation} rep`;
    const offers = m.contractOffers.map((c) => `<div class="contract"><div class="note">${rew(c.reward)}</div><div class="reqs">${c.requirements.map(req).join("")}</div><button class="key small" data-accept="${c.id}">ACCEPT</button></div>`).join("") || '<div class="note">No offers left today.</div>';
    const acc = m.acceptedContracts.map((c) => { const ok = c.requirements.every((q) => PT.contractOwned(s, q) >= q.count);
      return `<div class="contract"><div class="note">${rew(c.reward)}</div><div class="reqs">${c.requirements.map(req).join("")}</div><div class="devrow"><button class="key small ${ok ? "gold" : "grey"}" data-claim="${c.id}">CLAIM</button><button class="key small grey" data-abandon="${c.id}">ABANDON</button></div></div>`; }).join("") || '<div class="note">No accepted contracts.</div>';
    const buffs = Object.entries(m.activeContractBuffs).flatMap(([k, l]) => l.filter((b) => b.expiresAt > now).map((b) => `<div class="note">● ${k.replace(/_mult$/, "").replace(/_/g, " ").toUpperCase()} x${(1 + b.value).toFixed(2)} · ${PT.fmtTime((b.expiresAt - now) / 1000)} left</div>`)).join("") || '<div class="note">No active buffs.</div>';
    return `<div class="hero"><div class="big">REPUTATION RANK ${rp.level}</div><div class="bar"><i style="width:${rp.progress * 100}%"></i></div>
      <div class="sub">${rp.xp} rep${rp.next !== null ? " / " + rp.next : " (max)"} · ${m.acceptedContracts.length}/${PT.contractSlots(s)} accepted · new offers in ${PT.fmtTime((m.nextRefreshAt - now) / 1000)}${m.contractAcceptCooldownUntil > now ? " · accept cooldown " + PT.fmtTime((m.contractAcceptCooldownUntil - now) / 1000) : ""}</div>
      <button class="key small ${m.rerollsRemaining > 0 ? "blue" : "grey"}" data-act="reroll">REROLL (${m.rerollsRemaining})</button></div>
      <div class="section">OFFERS</div>${offers}<div class="section">ACCEPTED (${m.acceptedContracts.length}/${PT.contractSlots(s)})</div>${acc}
      <div class="section">ACTIVE BUFFS (${PT.contractBuffCount(s)}/${PT.contractSlots(s)})</div>${buffs}`;
  }
  PT.openWin = (id, tab) => openWin(id, tab);
  function openWin(id, tab) {
    if (id === "fishing" && G.s.evolutionCount < 1) return toast("Fish Inventory opens at Evolution 1");
    if (G.win && G.win.id === id) return closeWin();
    G.win = { id, tab: tab || (WINS[id].tabs ? WINS[id].tabs[0][0] : "") }; G.companionsOpen = false; winBody.dataset.last = ""; drawWin();
  }
  function closeWin() { G.win = null; winEl.hidden = true; }
  document.getElementById("win-close").onclick = closeWin;
  function drawWin() {
    if (!G.win) { winEl.hidden = true; return; }
    const w = WINS[G.win.id]; winEl.hidden = false;
    document.getElementById("win-title").textContent = w.title;
    const tabsH = (w.tabs || []).filter(([k]) => k !== "market" || PT.fishMarketUnlocked(G.s)).map(([k, n]) => `<button class="tab ${G.win.tab === k ? "on" : ""}" data-wtab="${k}">${n}</button>`).join("");
    if (winTabs.dataset.last !== tabsH) { winTabs.innerHTML = tabsH; winTabs.dataset.last = tabsH; }
    const h = w.body(G.win.tab);
    if (winBody.dataset.last !== h) { const y = winBody.scrollTop; winBody.innerHTML = h; winBody.scrollTop = y; winBody.dataset.last = h; }
  }
  winTabs.addEventListener("click", (e) => { const b = e.target.closest("[data-wtab]"); if (b) { G.win.tab = b.dataset.wtab; winBody.dataset.last = ""; winBody.scrollTop = 0; drawWin(); } });
  function reachable(m) { // maps you can walk to from the Park with the current gates
    const s = G.s; if (m === 0) return true;
    if (m === PT.AQUARIUM_MAP) return reachable(2) && PT.aquariumUnlocked(s);
    if (m === PT.NEST_MAP) return (s.evolutionCount || 0) >= 3;
    if (m === PT.DESERT_MAP) return PT.desertUnlocked(s);
    if (m === PT.EXP_HUB_MAP) return PT.expState(s).unlocked;
    if (PT.EXP.isRunMap(m)) return false; // floors are entered through the hub portal
    if (m === PT.MINE_MAP) return PT.mineOpen(s);
    if (m === PT.MINE_TREE_MAP) return PT.mineOpen(s) && PT.mineArea(s) >= 1;
    if (m === PT.NEST_ROOM_MAP) return (s.evolutionCount || 0) >= 3 && PT.nestState(s).tier >= 1;
    if (m === PT.FISH_MARKET_MAP) return reachable(PT.AQUARIUM_MAP) && PT.fishMarketUnlocked(s);
    const dir = m > 0 ? 1 : -1; let cur = 0;
    while (cur !== m) { const save = s.currentMap; s.currentMap = cur; const why = PT.travelBlock(s, dir); s.currentMap = save; if (why) return false; cur += dir; }
    return true;
  }
  function travelPanel() {
    return Object.values(PT.MAPS).map((m) => `<div class="row"><img class="ico" src="${ICON("map")}" alt=""><div><div class="t">${m.name}</div><div class="d">${reachable(m.id) ? (G.s.currentMap === m.id ? "You are here" : "Unlocked") : "Locked"}</div></div>
      <div class="btns"><button class="key ${reachable(m.id) && G.s.currentMap !== m.id ? "" : "grey"}" data-go="${m.id}">GO</button></div></div>`).join("");
  }
  document.getElementById("utility").addEventListener("click", (e) => { const b = e.target.closest("[data-win]"); if (b) openWin(b.dataset.win); });
  document.getElementById("btn-companions").onclick = () => { G.companionsOpen = !G.companionsOpen; drawHud(); };
  document.getElementById("companion-list").addEventListener("click", (e) => { const b = e.target.closest("[data-win]"); if (b) openWin(b.dataset.win); });
  document.getElementById("btn-autofish").onclick = () => { if (G.s.currentMap === PT.MINE_MAP) { const m = PT.mineState(G.s); if (PT.mineArea(G.s) >= 1) m.playerAutoEnabled = !m.playerAutoEnabled; else toast("Player auto opens at area 1"); } else if (G.s.currentMap === PT.NEST_MAP) { const f = PT.nestState(G.s).forest; f.autoCollectEnabled = !f.autoCollectEnabled; if (!f.autoCollectEnabled) G.target = null; } else act("autofish"); };

  // panel events
  let saveBox = "";
  function onUiClick(e) {
    const b = e.target.closest("button"); if (!b || b.dataset.wtab || b.dataset.win || b.dataset.tab) return;
    const s = G.s;
    if (b.dataset.buy) PT.buy(s, b.dataset.buy);
    else if (b.dataset.max) PT.buyMax(s, b.dataset.max);
    else if (b.dataset.pspend) { const p = PT.parrotState(s), a = G.spAmt; PT.parrotSpend(s, b.dataset.pspend, a === "max" ? p.skillPoints : String(a).endsWith("%") ? Math.max(1, Math.floor((p.skillPoints * parseInt(a)) / 100)) : a); }
    else if (b.dataset.spamt) G.spAmt = /^\d+$/.test(b.dataset.spamt) ? +b.dataset.spamt : b.dataset.spamt;
    else if (b.dataset.expfloor) { if (PT.EXP.startRun(G, +b.dataset.expfloor)) closeWin(); else toast("Floor locked"); }
    else if (b.dataset.dspend) PT.daveSpendPoint(s, b.dataset.dspend, G.daveAmt === "max" ? 100 : G.daveAmt);
    else if (b.dataset.damt) G.daveAmt = b.dataset.damt === "max" ? "max" : +b.dataset.damt;
    else if (b.dataset.drebirb) { if (!PT.daveRebirb(G, b.dataset.drebirb)) toast("Dave needs level 100"); }
    else if (b.dataset.sun) { const r = PT.buySun(s, b.dataset.sun); if (r) toast(r); }
    else if (b.dataset.speed) G.timeScale = +b.dataset.speed;
    else if (b.dataset.rod) { const r = PT.rodClick(s, b.dataset.rod); if (r) toast(r); }
    else if (b.dataset.tbuy) { const r = PT.buyTackle(s, b.dataset.tbuy, 10); if (r) toast(r); }
    else if (b.dataset.teq) PT.equipTackle(s, b.dataset.teq);
    else if (b.dataset.eat) { const r = PT.eatFish(s, b.dataset.eat); toast(r || "Buff active"); }
    else if (b.dataset.lock) { const i = s.lockedFish.indexOf(b.dataset.lock); if (i < 0) s.lockedFish.push(b.dataset.lock); else s.lockedFish.splice(i, 1); }
    else if (b.dataset.biome) PT.aq(s).activeBiomeId = b.dataset.biome;
    else if (b.dataset.nview) G.nestView = b.dataset.nview;
    else if (b.dataset.eview) G.eggView = b.dataset.eview;
    else if (b.dataset.mnode) { const r = PT.mineBuyNode(s, b.dataset.mnode); if (r) toast(r); }
    else if (b.dataset.nest) { const r = b.dataset.nest === "box" ? PT.nestBuyTreeBox(s) : PT.nestBuyExpansion(s); if (r) toast(r); }
    else if (b.dataset.nspec) { const r = PT.nestBuySpecial(s, b.dataset.nspec); if (r) toast(r); }
    else if (b.dataset.nup) { const r = PT.nestBuyUp(s, b.dataset.nup, false); if (r) toast(r); }
    else if (b.dataset.nupmax) { const r = PT.nestBuyUp(s, b.dataset.nupmax, true); if (r) toast(r); }
    else if (b.dataset.panda) PT.redPandaState(s).mode = b.dataset.panda;
    else if (b.dataset.bfuse) { const r = PT.breedFuse(s, b.dataset.bfuse); toast(r || "Fused!"); }
    else if (b.dataset.donate) { const r = PT.aqDonate(s, b.dataset.donate, false); toast(r || "Donated!"); }
    else if (b.dataset.donates) { const r = PT.aqDonate(s, b.dataset.donates, true); toast(r || "Shiny donated!"); }
    else if (b.dataset.qpin) PT.EXP.togglePinnedQuest(s, b.dataset.qpin);
    else if (b.dataset.accept) { const r = PT.acceptContract(s, b.dataset.accept); toast(r || "Contract accepted"); }
    else if (b.dataset.claim) { const r = PT.claimContract(s, b.dataset.claim); toast(r || "Contract claimed!"); }
    else if (b.dataset.abandon) { const r = PT.abandonContract(s, b.dataset.abandon); toast(r || "Contract abandoned (3h cooldown)"); }
    else if (b.dataset.go !== undefined) { const m = +b.dataset.go; if (reachable(m) && m !== s.currentMap) { s.currentMap = m; const mm = PT.MAPS[m]; s.player.x = mm.w / 2; s.player.y = m === 1 ? 640 : mm.h / 2; G.target = null; closeWin(); } }
    else if (b.dataset.act) act(b.dataset.act);
    panel.dataset.last = ""; winBody.dataset.last = ""; drawPanel(); drawWin(); drawHud(); save();
  }
  const castleEl = document.getElementById("castle"), hotbarEl = document.getElementById("hotbar");
  for (const el of [panel, winBody, castleEl, hotbarEl]) {
    el.addEventListener("click", onUiClick);
    el.addEventListener("change", onUiChange);
    el.addEventListener("pointerdown", (e) => { const b = e.target.closest("[data-hold]"); if (b) G.holdFeed = true; });
  }
  addEventListener("pointerup", () => (G.holdFeed = false));
  function onUiChange(e) {
    const k = e.target.dataset.in, s = G.s;
    if (e.target.dataset.breed !== undefined) { G.breedPick[+e.target.dataset.breed] = e.target.value; panel.dataset.last = ""; drawPanel(); return; }
    if (k === "community") PT.COMMUNITY.twigGain = e.target.checked ? 1.5 : 1;
    if (k === "nautop") PT.nestState(s).autoPopcornEnabled = e.target.checked;
    if (k === "nautog") PT.nestState(s).autoGoldenPopcornEnabled = e.target.checked;
    if (k === "autopot") PT.parrotState(s).autoPotionEnabled = e.target.checked;
    if (k === "daveauto") { const d = PT.dave(s); d.autoRebirbEnabled = (d.unspentRebirbPoints || 0) <= 0 && e.target.checked; }
    if (k === "nautos") PT.nestState(s).autoSeedsEnabled = e.target.checked;
    if (e.target.dataset.ff) { fishFilter[e.target.dataset.ff] = e.target.value; winBody.dataset.last = ""; drawWin(); return; }
    if (k === "feedpct") s.sparrowSeedFeedRatePercent = Math.max(1, Math.min(100, Math.floor(+e.target.value || 25)));
    if (k === "automitosis") s.sparrowAutoMitosisEnabled = e.target.checked;
    if (k === "autorebirb") s.sparrowAutoRebirbEnabled = e.target.checked;
    if (k === "gullauto") s.seagull.autoRebirbEnabled = e.target.checked;
    if (e.target.dataset.doc !== undefined) { const g = s.seagull.gulls[+e.target.dataset.doc]; g.pendingDoctrine = e.target.value; if (!g.lastCatchSummary) g.doctrine = e.target.value; }
  }
  tabsEl.addEventListener("click", (e) => { const b = e.target.closest("[data-tab]"); if (b) { G.tab = b.dataset.tab; panel.dataset.last = ""; drawPanel(); } });
  function act(a) {
    const s = G.s, q = (k) => winBody.querySelector(`[data-in="${k}"]`) || panel.querySelector(`[data-in="${k}"]`);
    if (a === "molt") { if (PT.molt(G)) toast("Molted!"); }
    else if (a === "treeview") s.sunflowerTreeView = desertView() ? "base" : "desert";
    else if (a === "feed") { s.isFeedingSparrow = !s.isFeedingSparrow; if (s.isFeedingSparrow) s.isDrainingSparrow = false; }
    else if (a === "drain") { s.isDrainingSparrow = !s.isDrainingSparrow; if (s.isDrainingSparrow) s.isFeedingSparrow = false; }
    else if (a === "mitosis") { if (!PT.mitosis(s)) toast("Not enough XP"); }
    else if (a === "srebirb") { if (!PT.sparrowRebirb(s)) toast("Not ready"); }
    else if (a === "cast") cast();
    else if (a === "autofish") { if (PT.autoFishUnlocked(s)) G.autoFish = !G.autoFish; else toast("Catch 10 fish by hand first"); }
    else if (a === "sellsafe") toast(PT.sellSafe(G));
    else if (a === "donateall") toast(PT.aqDonateAll(s));
    else if (a === "pandaname") { PT.nameRedPanda(s, q("pandaname")?.value); toast(s.redPanda.name + " joined you!"); }
    else if (a === "breedunlock") toast(PT.breedUnlock(s) || "Breeding Lake unlocked");
    else if (a === "breedstart") toast(PT.breedStart(s, G.breedPick[0], G.breedPick[1]) || "Breeding started");
    else if (a === "breedclaim") toast(PT.breedClaim(s) || "Hybrid hatched!");
    else if (a === "breeddiscard") toast(PT.breedDiscard(s) || "Discarded");
    else if (a === "reroll") toast(PT.marketReroll(s) || "New offers");
    else if (a === "migrate") { const r = PT.migrate(s); toast(r || "Migrated!"); }
    else if (a === "frenzy") { const r = PT.frenzy(s); toast(r || "Frenzy!"); }
    else if (a === "evolve") { if (PT.evolve(G)) toast("Evolution " + s.evolutionCount + "!"); else toast("Feed it to 100% first"); }
    else if (a === "give") { PT.add(s, q("givecur").value, D(q("giveamt").value)); }
    else if (a === "evo+") s.evolutionCount = Math.min(6, s.evolutionCount + 1);
    else if (a === "parrotrebirb") toast(PT.parrotRebirb(G) ? "Parrot rebirb " + PT.parrotState(s).rebirbCount : "Not ready: " + PT.parrotRebirbNeed(s));
    else if (a === "expauto") { const e = PT.expState(s); e.isAutoAttack = !e.isAutoAttack; const r = e.activeRun; if (r) r.combatArmed = true; }
    else if (a === "expreset") toast(PT.EXP.resetFloor(G) ? "Floor reset" : "Not in a run");
    else if (a.startsWith("frg_")) { const X = PT.EXP, [c, id, n] = a.split(":"); let m = "";
      if (c === "frg_gear") m = X.gearUpgrade(s, id); else if (c === "frg_conv") m = X.convertAura(s, id, +n); else if (c === "frg_dis") m = X.dismantleAura(s, id, +n); else if (c === "frg_inf") m = X.infuse(s, id);
      else if (c === "frg_sel") { G.fuseSel ||= []; G.fuseSel = G.fuseSel.includes(id) ? G.fuseSel.filter((x) => x !== id) : [...G.fuseSel, id].slice(-3); }
      else if (c === "frg_fuse") { const r = X.fuse(s, G.fuseSel || []); m = r.error || ""; if (r.item) { toast(`Fused into ${r.item.name} (${r.item.rarity})`); G.fuseSel = []; } }
      if (m) toast(m); X.bonuses = X.parrotBonuses(s); }
    else if (a === "inv_reset") { const n = PT.EXP.resetSkills(s); toast(n ? `Refunded ${fmt(n)} SP` : "Nothing to reset"); }
    else if (a.startsWith("inv_")) { const X = PT.EXP, [c, id] = a.split(":");
      if (c === "inv_on") { if (!X.equip(s, id)) toast("No free slot or already 2 copies"); } else if (c === "inv_off") X.unequip(s, id); else if (c === "inv_drop") X.discard(s, id);
      else if (c === "inv_pot") PT.parrotState(s).potionSlot = id; else if (c === "inv_use") { if (!X.usePotion(s)) toast("No potion ready"); }
      else if (c === "inv_chest") { const r = X.openChest(s, id); toast(!r ? "No chest" : r.full ? "Artifact bag is full" : `Got ${r.name} (${r.rarity})`); }
      X.bonuses = X.parrotBonuses(s); X.refreshRunParrot(s); }
    else if (a.startsWith("sac_")) { if (a === "sac_expand") { if (!PT.EXP.unlockSacExpansion(s)) toast("Not enough Spirit Aura"); } else { const n = PT.EXP.sacrifice(s, a.slice(4)); toast(n ? `Sacrificed ${fmt(n)} SP` : "No skill points to sacrifice"); } }
    else if (a === "davetrain") { if (!PT.daveTrain(s)) toast("Not enough seeds"); }
    else if (a === "daverefund") PT.daveRefund(s);
    else if (a === "davems") G.daveMilestones = !G.daveMilestones;
    else if (a === "crowrebirb") toast(PT.crowRebirb(s) ? "Crow rebirb " + PT.mineState(s).crowRebirbCount : "Not ready");
    else if (a === "minechallenge") { const r = PT.mineChallenge(G); if (r) toast(r); }
    else if (a === "fish50") { PT.ensureFishing(s); for (let i = 0; i < 50; i++) PT.catchFish(G, false); }
    else if (a === "allsun") { for (const st of visibleStations()) if (!PT.hasSun(s, st[0])) s.sunflowerUpgrades[st[0]] = 1; if (s.sunflowerUpgrades.d_unlock_evolve) s.hasUnlockedEvolve = true; }
    else if (a === "export") { saveBox = btoa(serialize(s)); }
    else if (a === "import") { try { G.s = deserialize(atob(q("savebox").value.trim())); G.field.clear(); toast("Loaded"); } catch (e) { toast("Bad save"); } }
    else if (a === "wipe") { if (confirm("Wipe the playtest save?")) { G.s = PT.newState(); G.field.clear(); G.sparrows = []; } }
  }

  // ------------------------------------------------------------------ HUD + prompt
  function drawHud() {
    const s = G.s, keys = ["popcorn", "goldenFeathers"];
    if (PT.hasSun(s, "d_sunflower_machine") || PT.res(s, "sunflowerSeeds").gt(0)) keys.push("sunflowerSeeds");
    for (const k of ["goldenPopcorn", "monetariaMoneta", "twigs", "echoPopcorn", "bruteOre"]) if (PT.res(s, k).gt(0) || (k === "monetariaMoneta" && s.evolutionCount >= 1)) keys.push(k);
    const goldChip = PT.mineOpen(s) ? `<div class="chip"><img src="${ICON("goldore")}" alt=""><span class="v">${fmt(PT.mineState(s).goldOre)}</span><span class="rate">gold ore</span></div>` : "";
    setHtml("wallet", goldChip + keys.map((k) => `<div class="chip"><img src="${ICON(CUR[k].icon)}" alt=""><span class="v">${fmt(s.resources[k])}</span><span class="rate">+${fmt(G.rates[k] || 0)}/s</span></div>`).join(""));
    document.getElementById("mapname").textContent = PT.MAPS[s.currentMap].name + (s.currentMap === 1 && desertView() ? " (DESERT TREE)" : "");
    document.getElementById("speedtag").textContent = G.timeScale > 1 ? `x${G.timeScale} speed` : "";
    const L = PT.travelBlock(s, -1), R = PT.travelBlock(s, 1);
    document.getElementById("go-left").classList.toggle("locked", !!L);
    document.getElementById("go-right").classList.toggle("locked", !!R);
    document.getElementById("go-left").style.display = L === "end" ? "none" : "";
    document.getElementById("go-right").style.display = R === "end" ? "none" : "";
    document.getElementById("label-left").textContent = L === "end" ? "" : L && s.currentMap === 0 ? "EVOLUTION 3" : PT.MAPS[PT.travelTarget(s, -1)]?.name || (L ? L.replace(/ \(.*\)$/, "") : "");
    document.getElementById("label-right").textContent = R === "end" ? "" : PT.MAPS[PT.travelTarget(s, 1)]?.name || "";
    for (const d of ["up", "down"]) {
      const why = PT.vertBlock(s, d), to = PT.vertLinks[s.currentMap]?.[d], el = document.getElementById("go-" + d);
      el.style.display = why === "end" ? "none" : ""; el.classList.toggle("locked", !!why);
      document.getElementById("label-" + d).textContent = why === "end" ? "" : s.currentMap === PT.FISH_MARKET_MAP ? "LEAVE MARKET" : PT.MAPS[to].name;
    }
    const aqb = document.getElementById("btn-aquarium");
    aqb.style.display = (PT.aquariumUnlocked(s) && s.currentMap !== PT.EXP_HUB_MAP && !PT.EXP.isRunMap(s.currentMap) && !PT.EXP.isSecretRoom(s.currentMap)) || s.currentMap === PT.FISH_MARKET_MAP ? "" : "none";
    aqb.textContent = s.currentMap === PT.FISH_MARKET_MAP ? "[E] FISH MARKET" : "[E] AQUARIUM";
    // companions (Birb: COMPANIONS [TAB] dropdown)
    const comps = [];
    if (s.sparrow.unlocked) comps.push(["sparrow", `${s.sparrow.level} SPARROW`]);
    if (s.hasMetSeagull) comps.push(["seagull", `${s.seagull.level} SEAGULL`]);
    if (s.redPanda?.introSeen) comps.push(["redpanda", `${PT.redPandaTier(s)} ${s.redPanda.name.toUpperCase()}`]);
    if (PT.mineOpen(s)) comps.push(["crow", `${PT.mineState(s).crowLevel} CROW`]);
    if (PT.hasSun(s, "d_desert_collared_dove")) comps.push(["dove", `${PT.dave(s).level} DAVE`]);
    if (PT.expState(s).unlocked) comps.push(["parrot", `${PT.expState(s).progress.level} PARROT`]);
    document.getElementById("btn-companions").style.display = comps.length ? "" : "none";
    setHtml("companion-list", G.companionsOpen ? comps.map(([k, n]) => `<button class="key small" data-win="${k}"><img src="${ICON(k)}" alt="">${n}</button>`).join("") : "");
    const af = document.getElementById("btn-autofish");
    if (s.currentMap === PT.MINE_MAP) { const m = PT.mineState(s); af.style.display = ""; af.className = "key small " + (m.playerAutoEnabled ? "violet" : PT.mineArea(s) >= 1 ? "" : "grey"); af.textContent = PT.mineArea(s) >= 1 ? `AUTO: ${m.playerAutoEnabled ? "ON" : "OFF"}` : "AUTO (area 1)"; }
    else if (s.currentMap === PT.NEST_MAP) { const f = PT.nestState(s).forest; af.style.display = f.autoCollectUnlocked ? "" : "none"; af.className = "key small " + (f.autoCollectEnabled ? "violet" : ""); af.textContent = `AUTO: ${f.autoCollectEnabled ? "ON" : "OFF"}`; }
    else {
    af.style.display = s.currentMap === 2 && s.evolutionCount >= 1 ? "" : "none";
    af.className = "key small " + (G.autoFish ? "violet" : PT.autoFishUnlocked(s) ? "" : "grey");
    af.textContent = PT.autoFishUnlocked(s) ? `AUTO: ${G.autoFish ? "ON" : "OFF"}` : `AUTO ${s.manualFishingCatches || 0}/10`; }
    document.querySelector('[data-win="fishing"]').classList.toggle("off", s.evolutionCount < 1);
    // Bridge: fishing level top-centre, cast hotbar bottom-centre
    if (s.currentMap === 2 && s.evolutionCount >= 1) {
      const f = PT.ensureFishing(s), F = G.fish || {}, need = PT.fishingXpNeeded(f.level);
      setHtml("fishbar", `<div class="lvl"><b>${f.level}</b><div class="bar"><i style="width:${Math.min(100, (f.xp / need) * 100)}%"></i></div><span class="note">${fmt(f.xp)}/${fmt(need)}</span></div>
        <div class="sub">${s.totalFishCaught || 0} caught · ${PT.RODS.reduce((m, r) => (f.ownedRods.includes(r.id) ? Math.max(m, r.monetaPerCatch) : m), 1)} moneta / catch</div>`);
      const state = F.casting > 0 ? "CASTING..." : F.reeling > 0 ? "REELING..." : F.cooldown > 0 ? `COOLDOWN ${F.cooldown.toFixed(1)}s` : "[SPACE] CAST";
      const slot = (id, n) => id ? `<div class="slot" title="${PT.itemName(id)}"><img src="${ICON(id.startsWith("rod_") ? rodIcon(id) : id)}" alt="">${n != null ? `<span>${n}</span>` : ""}</div>` : `<div class="slot empty"></div>`;
      const bait = f.equippedBaitId ? (f.baitInventory.find((b) => b.baitId === f.equippedBaitId)?.count || 0) : null;
      setHtml("hotbar", `<button class="key cast ${F.reeling > 0 || F.casting > 0 ? "gold" : F.cooldown > 0 ? "grey" : ""}" data-act="cast">${state}</button>
        <div class="slots">${slot(f.equippedRodId)}${slot(f.equippedBaitId, bait)}${slot(f.equippedHookId)}${slot(f.equippedLureId)}</div>`);
    } else if (s.currentMap === PT.MINE_MAP) {
      const c = PT.mineCampaign(s), a = PT.mineArea(s), k = c.areaMilestones[a] || 0, th = PT.mineAaMilestones(a), cur = c.areaDamage[a] || 0, M = G.mine || {};
      setHtml("fishbar", `<div class="lvl"><b>${a + 1}</b><div class="bar"><i style="width:${k >= 4 ? 100 : Math.min(100, (cur / th[k]) * 100)}%"></i></div><span class="note">+${4 * k}%</span></div><div class="sub">AREA ${a + 1} · +${4 * k}% damage in this area${k < 4 ? " · next at " + fmt(th[k]) + " HP mined" : ""}</div>`);
      const wait = Math.max(0, Math.ceil((PT.mineState(s).bossRespawnAt - Date.now()) / 1000));
      setHtml("hotbar", `<button class="key cast ${M.boss ? "gold" : wait ? "grey" : "violet"}" data-act="minechallenge">${M.boss ? "GIANT ORE · " + Math.max(0, Math.ceil((M.bossUntil - Date.now()) / 1000)) + "s" : wait ? "GIANT RESTS " + wait + "s" : "CHALLENGE"}</button>`);
    } else if (PT.EXP.isRunMap(s.currentMap) && PT.expState(s).activeRun) {
      const run = PT.expState(s).activeRun, p = run.parrot || { health: 0, maxHealth: 1 }, pr = PT.expState(s).progress, alive = run.enemies.filter((e) => e.health > 0 && e.type !== "mini-fly" && e.type !== "cultist").length, boss = run.enemies.find((e) => e.isBoss);
      setHtml("fishbar", `<div class="lvl"><b>${pr.level}</b><div class="bar"><i style="width:${Math.min(100, (pr.xp / pr.xpToNextLevel) * 100)}%"></i></div><span class="note">${fmt(Math.floor(pr.xp))}/${fmt(pr.xpToNextLevel)}</span></div>
        <div class="sub">FLOOR ${run.currentFloor} · HP ${fmt(Math.ceil(p.health))}/${fmt(p.maxHealth)} · ${alive} enemies · ${fmt(PT.parrotState(s).skillPoints)} SP${boss ? boss.health > 0 ? " · boss alive" : " · boss respawns in " + PT.fmtTime(boss.respawnTimer || 0) : ""}${run.combatArmed ? "" : " · move to start"}</div>`);
      setHtml("hotbar", `<button class="key cast ${PT.expState(s).isAutoAttack ? "violet" : ""}" data-act="expauto">AUTO: ${PT.expState(s).isAutoAttack ? "ON" : "OFF"}</button><button class="key small grey" data-act="expreset">RESET FLOOR</button>`);
    } else if (s.currentMap === PT.DESERT_MAP) {
      const storm = PT.sandstormOn(s), cd = s.desertSandstormCooldownRemaining || 0, hasStorm = PT.hasSun(s, "d_desert_sandstorm") || PT.hasSun(s, "d_desert_dune_conductors");
      setHtml("fishbar", `<div class="lvl"><b>${G.field.list(PT.DESERT_MAP).length}/${PT.maxPopcorn(s)}</b></div><div class="sub">GOLDEN CHANCE ${(PT.desertGoldenChance(s) * 100).toFixed(1)}% · ${fmt(PT.goldenPerDrop(s))} per golden egg${hasStorm ? ` · ${storm ? "SANDSTORM " + Math.ceil(s.desertSandstormTimeRemaining) + "s" : cd > 0 ? "next storm possible in " + PT.fmtTime(cd) : "a sandstorm can start any moment"}` : ""}</div>`);
      setHtml("hotbar", "");
    } else if (s.currentMap === PT.NEST_MAP) {
      const b = PT.nestBuild(s);
      setHtml("fishbar", `<div class="lvl"><b>${b.tier + 1}</b><div class="bar"><i style="width:${b.progress * 100}%"></i></div><span class="note">${fmt(b.current)}/${fmt(b.required)}</span></div>
        <div class="sub">TWIGS x${PT.nestTwigMult(s).toFixed(2)} · ${b.isMaxed ? "COMPLETE" : b.isComplete ? "EVOLVE TO LEVEL UP" : "Move close to a tree to start collecting."}</div>`);
      setHtml("hotbar", "");
    } else { setHtml("fishbar", ""); setHtml("hotbar", ""); }
    setHtml("castle", castleHtml());
    const pr = document.getElementById("prompt");
    const st = stationAt(s.player.x, s.player.y + 15);
    let msg = "";
    if (st) { const d = PT.SUN.get(st[0]); msg = `${title(d.name || st[0])}: ${words(d.description || "")} · press E to buy`; }
    else if (onPlatform()) msg = "On the seed platform: making seeds";
    else { const ep = expPortalNear(); if (ep) msg = ep.type === "enter_expedition" ? "[E] Enter the Expedition" : ep.type === "return_hub" ? "[E] Return to the hub (ends the run)" : ep.type === "secret_room_enter" ? "[E] Enter the secret room" : ep.type === "secret_room_return" || ep.type === "mine_exit" ? "[E] Leave" : "[E] Go to the next floor"; else if (s.currentMap === 17 && Math.hypot(s.player.x - 511, s.player.y - 640) < 140) msg = s.floorOneMineEntranceOpened ? "[E] Enter the Mine" : "[E] Break the wall"; }
    pr.style.display = msg ? "block" : "none"; pr.textContent = msg;
  }
  function setHtml(id, h) { const el = document.getElementById(id); if (el.dataset.last !== h) { el.innerHTML = h; el.dataset.last = h; } }

  // ------------------------------------------------------------------ main loop
  let last = performance.now(), uiT = 0, saveT = 0;
  function frame(now) {
    let dt = Math.min(0.25, (now - last) / 1000); last = now;
    let sim = dt * G.timeScale;
    while (sim > 0) { const h = Math.min(0.05, sim); step(h); sim -= h; }
    render();
    uiT += dt; saveT += dt; toastT -= dt;
    if (toastT <= 0) document.getElementById("toast").style.opacity = 0;
    if (uiT > 0.25) { uiT = 0; drawPanel(); drawHud(); drawWin(); }
    if (saveT > 10) { saveT = 0; save(); }
    requestAnimationFrame(frame);
  }
  addEventListener("beforeunload", save);
  drawPanel(); drawHud();
  if (G.offline && G.offline.twigs > 0) toast(`WELCOME BACK! You were away ${PT.fmtTime(G.offline.awaySeconds)}: +${fmt(G.offline.twigs)} twigs`);
  requestAnimationFrame(frame);
})();
