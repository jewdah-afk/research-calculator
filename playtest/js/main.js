// Peckwood playtest: loop, input, rendering, panels, saves and dev tools.
"use strict";
(function () {
  const PT = window.PT;
  const { D, fmt } = PT;
  const ICON = (n) => `../birb-icons/final/${n}.png`;
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
  function save() { try { localStorage.setItem(SAVE_KEY, serialize(G.s)); } catch (e) {} }
  function load() {
    try { const t = localStorage.getItem(SAVE_KEY); if (t) return deserialize(t); } catch (e) {}
    return PT.newState();
  }
  G.s = load();

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
    if (e.key.toLowerCase() === "e") tryStation();
    if (e.key.toLowerCase() === "f" && !PT.startCast(G)) toast(G.s.currentMap !== 2 ? "Fish on the Bridge" : G.s.evolutionCount < 1 ? "Fishing needs Evolution 1" : "Wait for the cooldown");
  });
  addEventListener("keyup", (e) => G.keys.delete(e.key.toLowerCase()));
  cv.addEventListener("mousedown", (e) => {
    const r = cv.getBoundingClientRect(), dpr = cv.width / r.width;
    const w = toWorld((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr);
    G.target = w;
    if (G.s.currentMap === 3 && !G.s.hasTalkedToMonster && Math.hypot(w.x - 800, w.y - 500) < 140) { G.s.hasTalkedToMonster = true; toast("The monster is hungry. Feed it!"); }
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
    G.s.currentMap += dir;
    const m = PT.MAPS[G.s.currentMap];
    G.s.player.x = dir > 0 ? 80 : m.w - 80; G.s.player.y = m.id === 1 ? 640 : m.h / 2; G.target = null; G.vx = G.vy = 0;
    save();
  }
  document.getElementById("go-left").onclick = () => travel(-1);
  document.getElementById("go-right").onclick = () => travel(1);
  document.getElementById("btn-save").onclick = () => { save(); toast("Saved"); };

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
    s.player.x = Math.max(20, Math.min(m.w - 20, s.player.x + G.vx * dt));
    s.player.y = Math.max(20, Math.min(m.h - 20, s.player.y + G.vy * dt));

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
    PT.ensureFishing(s);
    PT.updateFishing(G, dt, Math.abs(G.vx) > 5 || Math.abs(G.vy) > 5);
    PT.updateSeagull(G, dt);
    if (s.currentMap === 2 && s.evolutionCount >= 3 && !s.hasMetSeagull) { s.hasMetSeagull = true; s.seagull.discovered = true; toast("A seagull joins you at the Bridge!"); }
    if (s.currentMap === 2 && s.player.x > 2240 && !s.hasEnteredDungeon && s.hasUnlockedEvolve) { s.hasEnteredDungeon = true; toast("The castle gate is open"); }
    if (G.holdFeed && s.currentMap === 3 && s.hasTalkedToMonster && s.evolutionCount < 5 && s.monsterFeedProgress < 100) PT.feedMonster(s, 10 * dt);

    // per-second income rates (used by the seed feeder, Birb currencyRates)
    G.rateT += dt;
    if (G.rateT >= 1) { for (const k of ["popcorn", "sunflowerSeeds", "goldenFeathers", "monetariaMoneta"]) { const r = (G.gainAcc[k] || 0) / G.rateT; G.rates[k] = G.rates[k] === undefined ? r : G.rates[k] * 0.6 + r * 0.4; G.gainAcc[k] = 0; } G.rateT = 0; }
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
    if (s.currentMap === 1) drawSunflowerField();
    if (s.currentMap === 2) drawBridge();
    if (s.currentMap === 3) { drawIcon("monster", 800, 500, 200); label(s.hasTalkedToMonster ? `FED ${PT.feedProgress(s).toFixed(1)}%` : "Click the monster", 800, 640, 22); }
    // pickup radius ring + bird
    if (s.currentMap === 0) { cx.beginPath(); cx.arc(s.player.x, s.player.y, PT.pickupProfile(s).collectRadius, 0, 7); cx.strokeStyle = "rgba(255,255,255,.25)"; cx.lineWidth = 2; cx.stroke(); }
    drawIcon("birb", s.player.x, s.player.y, 48, G.vx < -5);
    for (const f of G.floats) if (f.map === s.currentMap) { cx.globalAlpha = Math.min(1, f.life / 0.4); label(f.text, f.x, f.y, 16, f.color); cx.globalAlpha = 1; }
  }
  function drawBridge() {
    const s = G.s, F = G.fish || {};
    cx.fillStyle = "#3a8bd6"; cx.fillRect(0, 560, 3000, 420); cx.fillStyle = "#2f74b8"; for (let x = 0; x < 3000; x += 60) cx.fillRect(x, 700 + 40 * Math.sin(x / 90 + G.t), 30, 6);
    cx.fillStyle = "#8a5a32"; cx.fillRect(0, 640, 3000, 120); cx.strokeStyle = "#0b0c10"; cx.lineWidth = 4; cx.strokeRect(0, 640, 3000, 120);
    for (let x = 0; x < 3000; x += 40) { cx.fillStyle = x % 80 ? "#9a6a3e" : "#7a4e2a"; cx.fillRect(x, 642, 38, 116); }
    cx.fillStyle = "#6b6f78"; roundRect(2260, 360, 260, 300, 16); cx.fill(); cx.stroke(); label(s.hasEnteredDungeon ? "CASTLE GATE (open)" : "CASTLE GATE", 2390, 350, 18);
    if (s.evolutionCount >= 1) label("Stand still and press F to fish", 700, 610, 16);
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
  function canAffordSun(id) { const def = PT.SUN.get(id); const c = def.costCurrency; return c in G.s.resources && PT.has(G.s, c, PT.sunCost(G.s, id)); }

  // ------------------------------------------------------------------ panels
  const panel = document.getElementById("panel"), tabsEl = document.getElementById("tabs");
  function tabs() {
    const s = G.s, t = [["eggs", "EGGS", "egg"]];
    if (s.rebirthCount > 0 || PT.res(s, "popcorn").gte(1000) || PT.res(s, "goldenFeathers").gt(0)) t.push(["molt", "MOLT", "plume"]);
    if (PT.hasSun(s, "d_sunflower_machine")) t.push(["seeds", "SEEDS", "seed"]);
    if (s.rebirthCount > 0) t.push(["tree", "TREE", "up_seed_value"]);
    if (s.sparrow.unlocked) t.push(["sparrow", "SPARROW", "sparrow"]);
    if (s.hasUnlockedEvolve || s.evolutionCount > 0) t.push(["castle", "EVOLVE", "monster"]);
    if (s.evolutionCount >= 1) t.push(["fishing", "FISHING", "rod"]);
    if (s.hasMetSeagull) t.push(["seagull", "SEAGULL", "seagull"]);
    t.push(["stats", "STATS", "index"], ["dev", "DEV", "settings"]);
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
      <div class="d">${words(def.description)}</div><div class="lv">LV ${L - (id.startsWith("p_") || id.startsWith("pr_") || id.startsWith("s_") ? 1 : 0)} / ${M - 1}</div></div>
      <div class="btns">${maxed ? `<button class="key gold">MAXED</button>` : `<button class="key ${ok ? "" : "grey"}" data-buy="${id}"><img src="${ICON(cur.icon)}" alt="">${fmt(cost)}</button>
      <button class="key small ${ok ? "blue" : "grey"}" data-max="${id}">BUY MAX</button>`}</div></div>`;
  }
  const treeRows = (tree) => [...PT.UP.values()].filter((d) => d.tree === tree && rowVisible(d.id)).map((d) => upRow(d.id)).join("");
  function rowVisible(id) {
    const s = G.s;
    if (id === "p_golden_popcorn_value") return !!s.hasUnlockedDesertMap;
    if (id === "p_auric_silo") return PT.hasSun(s, "d_desert_auric_blueprints");
    if (id === "pr_golden_popcorn_mult") return PT.hasSun(s, "d_desert_golden_popcorn_mult_unlock");
    return true;
  }
  function drawPanel() {
    const s = G.s, list = tabs();
    tabsEl.innerHTML = list.map(([k, n, ic]) => `<button class="tab ${G.tab === k ? "on" : ""}" data-tab="${k}"><img src="${ICON(ic)}" alt="">${n}</button>`).join("");
    let h = "";
    if (G.tab === "eggs") {
      h = `<div class="hdr">EGGS</div><div class="section">EGG UPGRADES</div>${treeRows("P")}
      <div class="note">Molting resets eggs and these upgrades. Plumes are forever.</div>`;
    } else if (G.tab === "molt") {
      const p = PT.prestige(s), ok = p.final.gte(1);
      h = `<div class="hdr">MOLT</div><div class="hero"><img src="${ICON("plume")}" alt=""><div class="big">MOLT</div>
      <div class="sub">${fmt(s.resources.goldenFeathers)} plumes · molted ${s.rebirthCount} times · 1 plume per 1,000 eggs</div>
      <button class="key wide ${ok ? "violet" : "grey"}" data-act="molt">${ok ? `Molt for +${fmt(p.final)} Plumes` : "Needs 1,000 eggs"}</button></div>
      <div class="section">PLUME KEEPSAKES</div>${treeRows("PR")}<div class="note">Molting resets eggs and egg upgrades. Plumes and keepsakes are kept until you Evolve.</div>`;
    } else if (G.tab === "seeds") {
      const sr = PT.seedRate(s, true);
      h = `<div class="hdr">SEEDS</div><div class="hero"><img src="${ICON("seed")}" alt=""><div class="big">SUNFLOWERS</div>
      <div class="sub">${fmt(s.resources.sunflowerSeeds)} seeds · ${fmt(sr.ticksPerSec * sr.perTick)} / s on the platform${PT.hasSun(s, "d_auto_gen") ? " (auto)" : ""}</div></div>
      <div class="section">SEED UPGRADES</div>${treeRows("S")}<div class="note">Evolving resets seeds and these upgrades.</div>`;
    } else if (G.tab === "tree") {
      const vis = visibleStations(), owned = vis.filter((st) => PT.hasSun(s, st[0])).length;
      h = `<div class="hdr">${desertView() ? "DESERT TREE" : "SUNFLOWER TREE"}</div>
      <div class="hero"><div class="sub">${owned} / ${vis.length} visible unlocks owned. Walk onto a station in the Sunflower Field and press E (or click Buy here).</div>
      ${s.hasUnlockedDesertMap ? `<button class="key small" data-act="treeview">Switch to ${desertView() ? "sunflower" : "desert"} tree</button>` : ""}</div>
      ${vis.map((st) => sunRow(st[0])).join("")}`;
    } else if (G.tab === "sparrow") h = sparrowPanel();
    else if (G.tab === "castle") h = castlePanel();
    else if (G.tab === "fishing") h = fishingPanel();
    else if (G.tab === "seagull") h = seagullPanel();
    else if (G.tab === "stats") h = statsPanel();
    else if (G.tab === "dev") h = devPanel();
    if (panel.dataset.last !== h) { const y = panel.scrollTop; panel.innerHTML = h; panel.scrollTop = y; panel.dataset.last = h; }
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
    return `<div class="hdr">SPARROW</div><div class="hero"><img src="${ICON("sparrow")}" alt=""><div class="big">THE SPARROW</div>
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
  function castlePanel() {
    const s = G.s, n = PT.evoReq(s.evolutionCount), pr = PT.feedProgress(s), can = PT.canEvolveStage(s);
    const line = (name, fed, need, cur) => need > 0 ? `<div class="note"><b>${name}</b> ${fmt(fed)} / ${fmt(need)}<div class="bar"><i style="width:${Math.min(100, (fed / need) * 100)}%"></i></div></div>` : "";
    return `<div class="hdr">EVOLVE</div><div class="hero"><img src="${ICON("monster")}" alt=""><div class="big">CASTLE MONSTER</div>
      <div class="sub">Evolution ${s.evolutionCount} → ${s.evolutionCount + 1} · ${pr.toFixed(1)}% fed${s.currentMap === 3 ? "" : " · go to the Castle to feed"}</div>
      <button class="key wide ${s.currentMap === 3 && s.hasTalkedToMonster ? "" : "grey"}" data-hold="feed">Hold to feed (10% of each need / s)</button>
      <div style="height:6px"></div><button class="key wide ${pr >= 100 && can ? "violet" : "grey"}" data-act="evolve">Evolve</button></div>
      <div class="section">FEED THE MONSTER</div>
      ${line("Eggs", s.monsterPopcornFed, n.popcorn)}${line("Plumes", s.monsterFeathersFed, n.feathers)}${line("Seeds", s.monsterSeedsFed, n.seeds)}
      ${line("Fish", s.monsterFishFed, n.fish)}${line("Twigs", s.monsterTwigsFed, n.twigs)}${line("Moneta", s.monsterMonetaFed, n.moneta)}
      <div class="note">Evolving resets eggs, plumes, seeds, golden and echo eggs, moneta, twigs, every non-permanent upgrade and sunflower unlock, and the sparrow. Evolution 1 unlocks the Sparrow. From Evolution 2, eggs, seeds and plumes are multiplied by your evolution count.</div>`;
  }
  function statsPanel() {
    const s = G.s, p = PT.prestige(s), prof = PT.pickupProfile(s), sr = PT.seedRate(s, true);
    const kv = (a, b) => `<span>${a}</span><span>${b}</span>`;
    return `<div class="hdr">STATS</div><div class="kv">
      ${kv("Egg multiplier", "x" + fmt(PT.totalMultiplier(s)))}${kv("Spawn interval", PT.spawnInterval(s).toFixed(3) + " s")}
      ${kv("Field cap", PT.maxPopcorn(s))}${kv("On field", G.field.list(0).length)}${kv("Pickup radius", prof.collectRadius.toFixed(1) + " px")}
      ${kv("Max speed", PT.maxSpeed(s).toFixed(1) + " px/s")}${kv("Eggs / s", fmt(G.rates.popcorn || 0))}${kv("Seeds / s (platform)", fmt(sr.ticksPerSec * sr.perTick))}
      ${kv("Molt base (eggs/1000)", fmt(p.base))}${kv("Molt multiplier", (p.a * p.pay).toFixed(3))}${kv("Playtime x", p.play.toFixed(2))}
      ${kv("Sparrow drain x", PT.sparrowDrainMult(s).toFixed(3))}${kv("Evolutions", s.evolutionCount)}${kv("Molts", s.rebirthCount)}
      ${kv("Total eggs collected", fmt(s.totalPopcornCollected))}${kv("Play time", PT.fmtTime(s.playTime))}</div>
      <div class="note">Every number here comes from the same formulas as Birb. Compare with the Roblox build to spot differences.</div>`;
  }
  function fishingPanel() {
    const s = G.s, f = PT.ensureFishing(s), F = G.fish || {};
    const rodIcon = (id) => "rod_" + id.replace(/^rod_/, "");
    const curRod = PT.RODS.find((r) => r.id === f.equippedRodId);
    const state = F.casting > 0 ? "Casting..." : F.reeling > 0 ? `Reeling ${F.reeling.toFixed(1)}s` : F.cooldown > 0 ? `Cooldown ${F.cooldown.toFixed(1)}s` : "Ready";
    const last = F.last ? `Last: <b style="color:${PT.RARITY_COLOR[F.last.fish.rarity]}">${PT.fishName(F.last.fish.id)}</b>${F.last.shiny ? " (shiny)" : ""} · ${F.last.weight} kg${F.last.record ? " · new best!" : ""}` : "";
    PT.normalizeFishBuffs(s);
    const buffs = s.activeFishIds.map((id) => { const fi = PT.FISH_BY.get(PT.baseFishId(id)); return `<div class="note">● ${PT.fishName(id)}: ${fi.effect.type} x${fi.effect.value}${PT.isShiny(id) ? " (x" + (1 + 3 * (fi.effect.value - 1)).toFixed(2) + " for 24h)" : ""}</div>`; }).join("");
    const inv = [...s.fishInventory].sort((a, b) => ({ common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4, mythic: 5 }[PT.FISH_BY.get(PT.baseFishId(b.fishId)).rarity] - { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4, mythic: 5 }[PT.FISH_BY.get(PT.baseFishId(a.fishId)).rarity])).slice(0, 40).map((row) => {
      const fi = PT.FISH_BY.get(PT.baseFishId(row.fishId));
      return `<div class="row"><img class="ico" src="${ICON("fish")}" alt=""><div><div class="t" style="color:${PT.RARITY_COLOR[fi.rarity]}">${PT.fishName(row.fishId)} x${row.count}</div>
        <div class="d">${fi.rarity} · ${fi.type || "expedition"} · eat: ${fi.effect.type} x${fi.effect.value} · sells ${fmt(PT.sellValue(s, row.fishId))} seeds</div></div>
        <div class="btns"><button class="key small" data-eat="${row.fishId}">EAT</button><button class="key small ${s.lockedFish.includes(fi.id) ? "violet" : "grey"}" data-lock="${fi.id}">${s.lockedFish.includes(fi.id) ? "LOCKED" : "LOCK"}</button></div></div>`;
    }).join("");
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
      return `<div class="row"><img class="ico" src="${ICON(t.type === "consumable" ? "bait" : t.id)}" onerror="this.src='${ICON("bait")}'" alt=""><div><div class="t">${PT.itemName(t.id)} <span class="lv">${t.type}</span></div>
        <div class="d">${eff}</div><div class="lv">${req ? req.toUpperCase() : t.type === "consumable" ? "owned " + owned + " · cost " + cost : owned ? "OWNED" : "cost " + cost}</div></div>
        <div class="btns">${t.type === "consumable" || !owned ? `<button class="key small ${req ? "grey" : ""}" data-tbuy="${t.id}">${t.type === "consumable" ? "BUY 10" : "UNLOCK"}</button>` : ""}
        ${owned ? `<button class="key small ${eq ? "gold" : "blue"}" data-teq="${t.id}">${eq ? "ON" : "EQUIP"}</button>` : ""}</div></div>`;
    }).join("");
    return `<div class="hdr">FISHING</div><div class="hero"><img src="${ICON(rodIcon(f.equippedRodId))}" alt=""><div class="big">THE BRIDGE</div>
      <div class="sub">Fishing LV ${f.level} · ${fmt(f.xp)} / ${fmt(PT.fishingXpNeeded(f.level))} XP · ${s.totalFishCaught || 0} caught · ${state}</div>
      <div class="sub">reel ${PT.reelDuration(s).toFixed(2)}s (fastest rod) · cooldown ${PT.fishCooldown(s).toFixed(2)}s · moneta from your best rod</div>
      <div class="devrow" style="justify-content:center"><button class="key" data-act="cast">Cast (F)</button>
      <button class="key ${G.autoFish ? "violet" : PT.autoFishUnlocked(s) ? "" : "grey"}" data-act="autofish">${PT.autoFishUnlocked(s) ? "Auto: " + (G.autoFish ? "ON" : "OFF") : "Auto " + (s.manualFishingCatches || 0) + "/10"}</button>
      <button class="key ${PT.hasSun(s, "d_fish_seeds") ? "gold" : "grey"}" data-act="sellsafe">Sell safe fish</button></div><div class="note">${last}</div></div>
      <div class="section">ACTIVE FISH BUFFS (${s.activeFishIds.length} / ${PT.maxFishBuffs(s)})</div>${buffs || '<div class="note">Eat a fish to get its effect. Shiny fish give 4x the bonus for 24h.</div>'}
      <div class="section">RODS</div>${rods}
      <div class="section">FISH (${s.fishInventory.reduce((a, r) => a + r.count, 0)})</div>${inv || '<div class="note">No fish yet.</div>'}
      <div class="note">Selling pays seeds and needs the Fish Seeds unlock. "Safe" keeps fish needed for rods, tackle and fish-priced sunflower nodes, plus locked and shiny fish.</div>
      <div class="section">TACKLE (bait, hooks, lures)</div>${tackle}`;
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
    return `<div class="hdr">SEAGULL</div><div class="hero"><img src="${ICON("seagull")}" alt=""><div class="big">THE SEAGULL</div>
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
  function devPanel() {
    const curs = Object.keys(G.s.resources).map((k) => `<option value="${k}">${CUR[k]?.name || k}</option>`).join("");
    return `<div class="hdr">DEV</div><div class="dev">
      <div class="devrow">Speed ${[1, 10, 100, 1000].map((x) => `<button class="key small ${G.timeScale === x ? "violet" : ""}" data-speed="${x}">x${x}</button>`).join("")}</div>
      <div class="devrow"><select data-in="givecur">${curs}</select><input data-in="giveamt" value="1e6" style="width:90px"><button class="key small" data-act="give">Give</button></div>
      <div class="devrow"><button class="key small" data-act="evo+">Evolution +1 (no reset)</button><button class="key small" data-act="allsun">Own all visible unlocks</button></div>
      <div class="devrow"><button class="key small" data-act="export">Export save</button><button class="key small" data-act="import">Import save</button><button class="key small grey" data-act="wipe">Wipe save</button></div>
      <textarea data-in="savebox" placeholder="Export puts the save here. Paste a save and press Import.">${saveBox}</textarea>
      <div class="note">Phase 1 covers the Park, Molt, seeds and the sunflower tree, the Sparrow and Castle evolutions. Fishing, the nest, the mine, the desert, the expedition and the echo field come in later phases; their nodes show "needs ..." until then.</div></div>`;
  }

  // panel events
  let saveBox = "";
  panel.addEventListener("click", (e) => {
    const b = e.target.closest("button"); if (!b) return;
    const s = G.s;
    if (b.dataset.buy) PT.buy(s, b.dataset.buy);
    else if (b.dataset.max) PT.buyMax(s, b.dataset.max);
    else if (b.dataset.sun) { const r = PT.buySun(s, b.dataset.sun); if (r) toast(r); }
    else if (b.dataset.speed) G.timeScale = +b.dataset.speed;
    else if (b.dataset.rod) { const r = PT.rodClick(s, b.dataset.rod); if (r) toast(r); }
    else if (b.dataset.tbuy) { const r = PT.buyTackle(s, b.dataset.tbuy, 10); if (r) toast(r); }
    else if (b.dataset.teq) PT.equipTackle(s, b.dataset.teq);
    else if (b.dataset.eat) { const r = PT.eatFish(s, b.dataset.eat); toast(r || "Buff active"); }
    else if (b.dataset.lock) { const i = s.lockedFish.indexOf(b.dataset.lock); if (i < 0) s.lockedFish.push(b.dataset.lock); else s.lockedFish.splice(i, 1); }
    else if (b.dataset.act) act(b.dataset.act);
    panel.dataset.last = ""; drawPanel(); save();
  });
  panel.addEventListener("pointerdown", (e) => { const b = e.target.closest("[data-hold]"); if (b) G.holdFeed = true; });
  addEventListener("pointerup", () => (G.holdFeed = false));
  panel.addEventListener("change", (e) => {
    const k = e.target.dataset.in, s = G.s;
    if (k === "feedpct") s.sparrowSeedFeedRatePercent = Math.max(1, Math.min(100, Math.floor(+e.target.value || 25)));
    if (k === "automitosis") s.sparrowAutoMitosisEnabled = e.target.checked;
    if (k === "autorebirb") s.sparrowAutoRebirbEnabled = e.target.checked;
    if (k === "gullauto") s.seagull.autoRebirbEnabled = e.target.checked;
    if (e.target.dataset.doc !== undefined) { const g = s.seagull.gulls[+e.target.dataset.doc]; g.pendingDoctrine = e.target.value; if (!g.lastCatchSummary) g.doctrine = e.target.value; }
  });
  tabsEl.addEventListener("click", (e) => { const b = e.target.closest("[data-tab]"); if (b) { G.tab = b.dataset.tab; panel.dataset.last = ""; drawPanel(); } });
  function act(a) {
    const s = G.s, q = (k) => panel.querySelector(`[data-in="${k}"]`);
    if (a === "molt") { if (PT.molt(G)) toast("Molted!"); }
    else if (a === "treeview") s.sunflowerTreeView = desertView() ? "base" : "desert";
    else if (a === "feed") { s.isFeedingSparrow = !s.isFeedingSparrow; if (s.isFeedingSparrow) s.isDrainingSparrow = false; }
    else if (a === "drain") { s.isDrainingSparrow = !s.isDrainingSparrow; if (s.isDrainingSparrow) s.isFeedingSparrow = false; }
    else if (a === "mitosis") { if (!PT.mitosis(s)) toast("Not enough XP"); }
    else if (a === "srebirb") { if (!PT.sparrowRebirb(s)) toast("Not ready"); }
    else if (a === "cast") { if (!PT.startCast(G)) toast(s.currentMap !== 2 ? "Go to the Bridge" : "Not ready"); }
    else if (a === "autofish") { if (PT.autoFishUnlocked(s)) G.autoFish = !G.autoFish; else toast("Catch 10 fish by hand first"); }
    else if (a === "sellsafe") toast(PT.sellSafe(G));
    else if (a === "migrate") { const r = PT.migrate(s); toast(r || "Migrated!"); }
    else if (a === "frenzy") { const r = PT.frenzy(s); toast(r || "Frenzy!"); }
    else if (a === "evolve") { if (PT.evolve(G)) toast("Evolution " + s.evolutionCount + "!"); else toast("Feed it to 100% first"); }
    else if (a === "give") { PT.add(s, q("givecur").value, D(q("giveamt").value)); }
    else if (a === "evo+") s.evolutionCount = Math.min(6, s.evolutionCount + 1);
    else if (a === "allsun") { for (const st of visibleStations()) if (!PT.hasSun(s, st[0])) s.sunflowerUpgrades[st[0]] = 1; if (s.sunflowerUpgrades.d_unlock_evolve) s.hasUnlockedEvolve = true; }
    else if (a === "export") { saveBox = btoa(serialize(s)); }
    else if (a === "import") { try { G.s = deserialize(atob(q("savebox").value.trim())); G.field.clear(); toast("Loaded"); } catch (e) { toast("Bad save"); } }
    else if (a === "wipe") { if (confirm("Wipe the playtest save?")) { G.s = PT.newState(); G.field.clear(); G.sparrows = []; } }
  }

  // ------------------------------------------------------------------ HUD + prompt
  function drawHud() {
    const s = G.s, keys = ["popcorn", "goldenFeathers", "sunflowerSeeds"];
    for (const k of ["goldenPopcorn", "monetariaMoneta", "twigs", "echoPopcorn", "bruteOre"]) if (PT.res(s, k).gt(0)) keys.push(k);
    document.getElementById("wallet").innerHTML = keys.map((k) => `<div class="chip"><img src="${ICON(CUR[k].icon)}" alt="">${fmt(s.resources[k])}${G.rates[k] ? `<span class="rate">+${fmt(G.rates[k])}/s</span>` : ""}</div>`).join("");
    document.getElementById("mapname").textContent = PT.MAPS[s.currentMap].name + (s.currentMap === 1 && desertView() ? " (DESERT TREE)" : "");
    document.getElementById("speedtag").textContent = G.timeScale > 1 ? `x${G.timeScale} speed` : "";
    document.getElementById("go-left").classList.toggle("locked", !!PT.travelBlock(s, -1));
    document.getElementById("go-right").classList.toggle("locked", !!PT.travelBlock(s, 1));
    const pr = document.getElementById("prompt");
    const st = stationAt(s.player.x, s.player.y + 15);
    let msg = "";
    if (st) { const d = PT.SUN.get(st[0]); msg = `${title(d.name || st[0])}: ${words(d.description || "")} · press E to buy`; }
    else if (onPlatform()) msg = "On the seed platform: making seeds";
    else if (s.currentMap === 2 && G.fish && G.fish.reeling > 0) msg = "Reeling... stand still";
    pr.style.display = msg ? "block" : "none"; pr.textContent = msg;
  }

  // ------------------------------------------------------------------ main loop
  let last = performance.now(), uiT = 0, saveT = 0;
  function frame(now) {
    let dt = Math.min(0.25, (now - last) / 1000); last = now;
    let sim = dt * G.timeScale;
    while (sim > 0) { const h = Math.min(0.05, sim); step(h); sim -= h; }
    render();
    uiT += dt; saveT += dt; toastT -= dt;
    if (toastT <= 0) document.getElementById("toast").style.opacity = 0;
    if (uiT > 0.25) { uiT = 0; drawPanel(); drawHud(); }
    if (saveT > 10) { saveT = 0; save(); }
    requestAnimationFrame(frame);
  }
  addEventListener("beforeunload", save);
  drawPanel(); drawHud();
  requestAnimationFrame(frame);
})();
