// Peckwood 3D (web): the game layer. The world itself (terrain, sea, props, lighting, day cycle) is the Peckwood World Guide,
// loaded as world.html in a frame; this file puts the game on it through window.WG: the birb, eggs, sparrows, nest trees,
// a fixed-angle camera that follows the birb, clamped zoom, and islands that rise as you reach them.
// All game logic comes from ../playtest/js (1:1 with Birb). main.js calls R3D.render / R3D.edge each frame.
"use strict";
(function () {
  const PT = window.PT, G = PT.G;
  const stage = document.getElementById("stage"), flatCv = document.getElementById("view");
  flatCv.style.display = "none";

  // ------------------------------------------------------------------ the world frame
  const frame = document.createElement("iframe");
  frame.src = "world.html"; frame.title = "Peckwood world";
  Object.assign(frame.style, { position: "absolute", inset: "0", width: "100%", height: "100%", border: "0", display: "block" });
  stage.insertBefore(frame, stage.firstChild);
  // maps that have no 3D scene yet: the playtest drawing in a corner panel so their stations and controls stay usable
  const mini = document.createElement("canvas"); mini.width = 640; mini.height = 400;
  Object.assign(mini.style, { position: "absolute", left: "12px", bottom: "12px", width: "min(42%, 420px)", border: "3px solid #0b0c10", borderRadius: "6px", background: "#1a2a1c", display: "none", cursor: "crosshair" });
  stage.appendChild(mini);
  mini.addEventListener("mousedown", (e) => { const r = mini.getBoundingClientRect(), m = PT.MAPS[G.s.currentMap]; G.clickWorld({ x: ((e.clientX - r.left) / r.width) * m.w, y: ((e.clientY - r.top) / r.height) * m.h }); });

  let W = null, T = null, A = null; // WG api, its THREE, our objects
  const R3D = window.R3D = { render() {}, edge() {} };

  // ------------------------------------------------------------------ Birb maps -> World Guide islands
  const ISLAND_OF = (id) => {
    if (id === 0) return "park"; if (id === 1) return "garden"; if (id === 2 || id === PT.AQUARIUM_MAP || id === PT.FISH_MARKET_MAP) return "bridge";
    if (id === 3) return "castle"; if (id === PT.NEST_MAP || id === PT.NEST_ROOM_MAP) return "forest"; if (id === PT.DESERT_MAP) return "desert";
    if (id === PT.MINE_MAP || id === PT.MINE_TREE_MAP) return "mine"; if (id === PT.ECHO_FIELD_MAP) return "echo";
    return "expedition";
  };
  const SCENE3D = { 0: true, 4: true }; // maps with their own 3D game objects so far
  const isl = (id) => W.ISL.find((x) => x.id === ISLAND_OF(id));
  // map pixel -> world position on that map's island (the island's tile rectangle stands for the whole map)
  function toWorld(id, x, y) {
    const I = isl(id), m = PT.MAPS[id] || { w: 1056, h: 792 };
    const wx = W.wx(I.oi + (x / m.w) * I.W), wz = W.wz(I.oj + (y / m.h) * I.N);
    return new T.Vector3(wx, W.groundY(wx, wz), wz);
  }
  function toMap(id, p) { const I = isl(id), m = PT.MAPS[id]; return { x: ((p.x / W.S + W.COLS / 2 - I.oi) / I.W) * m.w, y: ((p.z / W.S + W.ROWS / 2 - I.oj) / I.N) * m.h }; }
  const pxScale = (id) => { const I = isl(id), m = PT.MAPS[id]; return (I.W * W.S) / m.w; }; // world units per map pixel

  // ------------------------------------------------------------------ models (clean low-poly, sized to the world's 4-unit tiles)
  function models() {
    const C = (c) => new T.Color(c).convertSRGBToLinear();
    const mat = (c, o = {}) => new T.MeshStandardMaterial({ color: C(c), roughness: 0.6, ...o });
    const prof = []; for (let i = 0; i <= 16; i++) { const t = i / 16, a = t * Math.PI, r = Math.sin(a) * (t < 0.5 ? 0.21 : 0.21 - 0.1 * (t - 0.5)); prof.push(new T.Vector2(Math.max(0.001, r), -Math.cos(a) * 0.29 + 0.29)); }
    const eggG = new T.LatheGeometry(prof, 18);
    const rainbowG = eggG.clone(); { const pos = rainbowG.attributes.position, cols = [], pal = ["#ff5d5d", "#ffb347", "#ffe66d", "#6ddc7a", "#5ab4ff", "#a77bff"].map(C);
      for (let i = 0; i < pos.count; i++) { const k = Math.min(5, Math.floor((pos.getY(i) / 0.58) * 6)); cols.push(pal[k].r, pal[k].g, pal[k].b); } rainbowG.setAttribute("color", new T.Float32BufferAttribute(cols, 3)); }
    const EGG = { plain: mat("#f6eedb", { roughness: 0.45 }), butter: mat("#f2c46b", { roughness: 0.4 }), caramel: mat("#c46f2b", { roughness: 0.35 }), cheese: mat("#ffc21a", { roughness: 0.4 }),
      rainbow: new T.MeshStandardMaterial({ vertexColors: true, roughness: 0.35 }), red: mat("#e8202a", { roughness: 0.22, metalness: 0.1 }),
      golden: mat("#ffc93c", { metalness: 0.85, roughness: 0.22, emissive: C("#6a4400"), emissiveIntensity: 0.4 }), echo: mat("#b37bff", { roughness: 0.3, emissive: C("#5a20b0"), emissiveIntensity: 0.7 }) };
    const egg = (type) => { const g = new T.Group(), m = new T.Mesh(type === "rainbow" ? rainbowG : eggG, EGG[type] || EGG.plain); m.castShadow = true; g.add(m); g.userData.mesh = m; return g; };
    const white = mat("#ffffff"), black = mat("#151515", { roughness: 0.3 }), orange = mat("#ff9a1f", { roughness: 0.5 });
    function bird({ body = "#ffc23a", belly = "#ffe7a3", wing = "#f0a21c" } = {}) {
      const g = new T.Group(), b = new T.Group(); g.add(b);
      const add = (m, x, y, z, sx = 1, sy = 1, sz = 1) => { m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.castShadow = true; b.add(m); return m; };
      add(new T.Mesh(new T.SphereGeometry(0.42, 22, 16), mat(body, { roughness: 0.55 })), 0, 0.46, 0, 1, 0.92, 1.05);
      add(new T.Mesh(new T.SphereGeometry(0.3, 16, 12), mat(belly)), 0, 0.38, 0.2, 1, 0.9, 0.7);
      const beak = add(new T.Mesh(new T.ConeGeometry(0.09, 0.22, 10), orange), 0, 0.55, 0.47); beak.rotation.x = Math.PI / 2;
      for (const sx of [1, -1]) { add(new T.Mesh(new T.SphereGeometry(0.075, 10, 8), white), 0.17 * sx, 0.66, 0.34); add(new T.Mesh(new T.SphereGeometry(0.045, 8, 6), black), 0.17 * sx, 0.66, 0.38); }
      const wm = mat(wing), wl = add(new T.Mesh(new T.SphereGeometry(0.22, 12, 8), wm), -0.4, 0.45, -0.02, 0.35, 0.75, 1), wr = add(new T.Mesh(new T.SphereGeometry(0.22, 12, 8), wm), 0.4, 0.45, -0.02, 0.35, 0.75, 1);
      const tail = add(new T.Mesh(new T.ConeGeometry(0.14, 0.3, 8), wm), 0, 0.42, -0.45); tail.rotation.x = -Math.PI / 2.6;
      const tuft = add(new T.Mesh(new T.ConeGeometry(0.06, 0.18, 6), wm), 0, 0.92, 0.05); tuft.rotation.x = 0.4;
      for (const sx of [1, -1]) add(new T.Mesh(new T.CylinderGeometry(0.03, 0.03, 0.14, 5), orange), 0.12 * sx, 0.06, 0.04);
      g.userData = { b, wl, wr, phase: Math.random() * 6, face: 0 };
      return g;
    }
    const bark = mat("#7a4b2a"), pineM = mat("#2f7a46", { roughness: 0.8 }), barBack = new T.MeshBasicMaterial({ color: C("#1b1b1b") }), barFill = new T.MeshBasicMaterial({ color: C("#7bd34f") });
    function pine() {
      const g = new T.Group(), tr = new T.Mesh(new T.CylinderGeometry(0.1, 0.14, 0.5, 7), bark); tr.position.y = 0.25; tr.castShadow = true; g.add(tr);
      [[0.62, 0.7, 0.75], [0.5, 0.6, 1.15], [0.36, 0.5, 1.5]].forEach(([r, h, y]) => { const c = new T.Mesh(new T.ConeGeometry(r, h, 8), pineM); c.position.y = y; c.castShadow = true; g.add(c); });
      const bar = new T.Group(), bk = new T.Mesh(new T.BoxGeometry(0.9, 0.1, 0.04), barBack), fl = new T.Mesh(new T.BoxGeometry(0.86, 0.07, 0.05), barFill); bar.add(bk, fl); bar.position.y = 2.05; g.add(bar);
      g.userData = { bar, fill: fl }; return g;
    }
    const woodM = mat("#9a6235"), soilM = mat("#5a3a22");
    function planter() { const g = new T.Group(), b = new T.Mesh(new T.BoxGeometry(1, 0.28, 0.92), woodM); b.position.y = 0.14; b.castShadow = b.receiveShadow = true;
      const s = new T.Mesh(new T.BoxGeometry(0.88, 0.05, 0.8), soilM); s.position.y = 0.29; g.add(b, s); return g; }
    function panda() { const g = new T.Group(), b = new T.Mesh(new T.SphereGeometry(0.38, 14, 10), mat("#d8572a")); b.position.y = 0.38; b.scale.set(1, 0.85, 1.15); b.castShadow = true;
      const h = new T.Mesh(new T.SphereGeometry(0.26, 14, 10), mat("#e2672f")); h.position.set(0, 0.7, 0.3); const f = new T.Mesh(new T.SphereGeometry(0.16, 10, 8), white); f.position.set(0, 0.66, 0.46); f.scale.z = 0.5;
      const t = new T.Mesh(new T.CylinderGeometry(0.1, 0.14, 0.6, 8), mat("#7a2e10")); t.rotation.x = 1.1; t.position.set(0, 0.35, -0.5); g.add(b, h, f, t); return g; }
    const ringM = new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.35, depthWrite: false });
    return { egg, bird, pine, planter, panda, ring: () => { const r = new T.Mesh(new T.RingGeometry(0.96, 1, 64), ringM); r.rotation.x = -Math.PI / 2; r.renderOrder = 5; return r; } };
  }
  function animBird(g, vx, vz, dt, extra = 0) {
    const u = g.userData, sp = Math.hypot(vx, vz);
    if (sp > 0.05) { let d = Math.atan2(vx, vz) - u.face; d = Math.atan2(Math.sin(d), Math.cos(d)); u.face += d * Math.min(1, dt * 12); }
    g.rotation.y = u.face; u.phase += dt * (sp > 0.05 ? 14 : 3);
    u.b.position.y = sp > 0.05 ? Math.abs(Math.sin(u.phase)) * 0.12 : Math.sin(u.phase) * 0.012;
    const flap = sp > 0.05 ? Math.sin(u.phase * 1.5) * 0.5 : 0.08 * Math.sin(u.phase);
    u.wl.rotation.z = 0.15 + flap + extra; u.wr.rotation.z = -0.15 - flap - extra;
  }
  const hash = (a, b) => { let h = (Math.imul(a | 0, 374761393) ^ Math.imul(b | 0, 668265263)) >>> 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

  // ------------------------------------------------------------------ boot once the world is ready
  function boot() {
    W = frame.contentWindow.WG; if (!W || A) return; T = W.THREE;
    const M = models(), root = new T.Group(); W.scene.add(root);
    const BIRD = 6, EGG = 7, PINE = 5.5; // model scale in world units (a tile is 4)
    A = { M, root, player: M.bird(), ring: M.ring(), eggs: new Map(), dying: [], sparrows: [], trees: new Map(), planters: new Map(), panda: M.panda(), lastIsland: null, BIRD, EGG, PINE };
    A.player.scale.setScalar(BIRD); A.panda.scale.setScalar(BIRD * 0.9); A.panda.visible = false;
    root.add(A.player, A.ring, A.panda);
    // keys typed while the world frame has focus go to the game
    for (const type of ["keydown", "keyup"]) frame.contentWindow.addEventListener(type, (e) => { window.dispatchEvent(new KeyboardEvent(type, { key: e.key })); if (e.key === " " || e.key === "Tab") e.preventDefault(); });
    // clicks on the ground move / interact on the current map
    frame.contentWindow.WG_CLICK = (hit) => { G.clickWorld(toMap(G.s.currentMap, hit)); };
    // islands: everything you have reached so far stands; a new island rises when you first get there
    const n = reachedLevel(); W.resetTo(n); A.level = n;
    placeCamera(true);
  }
  frame.addEventListener("load", () => { const t0 = Date.now(), wait = () => { if (frame.contentWindow.WG) boot(); else if (Date.now() - t0 < 15000) setTimeout(wait, 100); }; wait(); });

  function reachedLevel() {
    const s = G.s, seen = (s.visitedIslands ||= ["park"]), cur = ISLAND_OF(s.currentMap);
    if (!seen.includes(cur)) seen.push(cur);
    return Math.max(1, ...seen.map((id) => W.ISL.find((x) => x.id === id)?.n || 1));
  }

  // ------------------------------------------------------------------ camera: fixed angle (looking straight north, tilted down), follows the birb, zoom clamped per island
  const POLAR = Math.PI / 2 - 0.9;
  function placeCamera(snap) {
    const I = isl(G.s.currentMap), p = A.player.position, c = W.controls, cam = W.camera;
    const r = frame.getBoundingClientRect(), aspect = r.width / Math.max(1, r.height), tanH = Math.tan((cam.fov * Math.PI) / 360);
    const span = Math.max((I.W * W.S + 40) / aspect, (I.N * W.S + 40) * Math.cos(POLAR)); // the island plus a band of sea
    c.maxDistance = Math.max(160, span / (2 * tanH)); c.minDistance = 60;
    const half = (I.W * W.S) / 2, halfD = (I.N * W.S) / 2, cx = W.wx(I.oi + I.W / 2), cz = W.wz(I.oj + I.N / 2);
    const tx = Math.max(cx - half, Math.min(cx + half, p.x)), tz = Math.max(cz - halfD, Math.min(cz + halfD, p.z));
    const want = new T.Vector3(tx, 0, tz);
    if (snap) { const d = Math.min(c.maxDistance, 260); W.flyTo(want, d, POLAR, 0); if (W.camera.fov !== 22) { W.camera.fov = 22; W.camera.updateProjectionMatrix(); } return; }
    if (W.flying) return;
    const off = cam.position.clone().sub(c.target), dist = Math.min(c.maxDistance, Math.max(c.minDistance, off.length()));
    off.setFromSpherical(new T.Spherical(dist, POLAR, 0)); // keep the fixed angle whatever the controls did
    c.target.lerp(want, 0.12); cam.position.copy(c.target).add(off);
  }

  // ------------------------------------------------------------------ per-frame sync
  function syncEggs(map, list, on) {
    const seen = new Set();
    if (on) for (const p of list) {
      const key = map + ":" + p.id; seen.add(key);
      let e = A.eggs.get(key);
      if (!e) { e = A.M.egg(p.type); e.userData.born = 0; e.userData.spin = hash(p.id, 3) * 6.28; e.scale.setScalar(A.EGG * (p.type === "golden" || p.type === "red" ? 1.15 : 1)); A.root.add(e); A.eggs.set(key, e); }
      e.position.copy(toWorld(map, p.x, p.y));
      const b = (e.userData.born = Math.min(1, e.userData.born + 1 / 14)), pop = b < 1 ? 1 + Math.sin(b * Math.PI) * 0.35 : 1;
      e.userData.mesh.scale.setScalar(b * pop); e.rotation.y = e.userData.spin; e.userData.mesh.rotation.z = Math.sin(G.t * 2 + e.userData.spin) * 0.06;
    }
    for (const [key, e] of A.eggs) if (key.startsWith(map + ":") && !seen.has(key)) { A.eggs.delete(key); if (on) A.dying.push({ e, t: 0 }); else A.root.remove(e); }
  }
  function syncDying(dt) {
    for (let i = A.dying.length - 1; i >= 0; i--) { const d = A.dying[i]; d.t += dt / 0.2; const k = Math.min(1, d.t);
      d.e.position.lerp(A.player.position.clone().add(new T.Vector3(0, 3, 0)), k * 0.5); d.e.scale.multiplyScalar(0.8);
      if (k >= 1) { A.root.remove(d.e); A.dying.splice(i, 1); } }
  }
  function syncSparrows(on) {
    const list = on ? G.sparrows : [];
    while (A.sparrows.length < list.length) { const b = A.M.bird({ body: "#b9845a", belly: "#efdcc0", wing: "#8a5a34" }); b.scale.setScalar(A.BIRD * 0.6); A.sparrows.push(b); A.root.add(b); }
    A.sparrows.forEach((o, i) => { const b = list[i]; o.visible = !!b; if (!b) return; const w = toWorld(0, b.x, b.y), last = o.userData.last || w;
      o.position.set(w.x, w.y + (b.state === "fly" ? 5 : 0), w.z); animBird(o, (w.x - last.x) * 10, (w.z - last.z) * 10, 1 / 60, b.state === "fly" ? 0.8 : 0); o.userData.last = w; });
  }
  function syncNest(on, dt) {
    const s = G.s, n = PT.nestState(s), f = n.forest, seen = new Set(), pseen = new Set();
    const put = (key, x, y, k, hp, maxHp, active, collapse, lift) => {
      seen.add(key); let t = A.trees.get(key); if (!t) { t = A.M.pine(); A.root.add(t); A.trees.set(key, t); }
      const w = toWorld(4, x, y); t.position.set(w.x, w.y + lift, w.z);
      const fall = hp <= 0 ? Math.max(0, collapse / 0.8) : 1;
      t.scale.setScalar(Math.max(0.01, A.PINE * k * (hp <= 0 ? fall : 1))); t.rotation.z = hp <= 0 ? (1 - fall) * 1.2 : 0;
      t.userData.bar.visible = hp > 0 && (hp < maxHp || active); t.userData.fill.scale.x = Math.max(0.01, hp / maxHp); t.userData.fill.position.x = -0.43 * (1 - hp / maxHp);
      t.userData.bar.quaternion.copy(W.camera.quaternion).premultiply(t.quaternion.clone().invert());
    };
    if (on) {
      for (const t of f.trees) { if (t.hp <= 0 && !(t.collapse > 0)) continue; put(t.id, t.x, t.y, t.age >= 180 ? 1 : 0.35 + 0.65 * (t.age / 180), t.hp, t.maxHp, f.activeTreeId === t.id, t.collapse, 0); }
      const gs = PT.nestCultSnapshot(s).growthSeconds, k4 = pxScale(4);
      for (const b of n.cultivation.treeBoxes) {
        const p = PT.boxSlotPos(b.slotIndex), pk = "pl" + b.slotIndex; pseen.add(pk);
        let pl = A.planters.get(pk); if (!pl) { pl = A.M.planter(); pl.scale.set(100 * k4, 4, 92 * k4); A.root.add(pl); A.planters.set(pk, pl); } pl.position.copy(toWorld(4, p.x, p.y));
        const k = (b.trees || []).length;
        (b.trees || []).forEach((t, i) => { if (t.hp <= 0 && !(t.collapse > 0)) return; const x = p.x + (i % 2) * 40 - (k > 1 ? 20 : 0), y = p.y + Math.floor(i / 2) * 36 - (k > 2 ? 18 : 0);
          put("box" + b.slotIndex + "_" + i, x, y, 0.55 * (t.age >= gs ? 1 : 0.35 + 0.65 * (t.age / gs)), t.hp, t.maxHp, f.activeTreeId === "box" + b.slotIndex + "_" + i, t.collapse || 0, 1.2); });
      }
    }
    for (const [k, pl] of A.planters) if (!pseen.has(k)) { A.root.remove(pl); A.planters.delete(k); }
    for (const [key, t] of A.trees) if (!seen.has(key)) { A.root.remove(t); A.trees.delete(key); }
    A.panda.visible = on && PT.pandaAssisting(s) && !!G.pandaPos;
    if (A.panda.visible) { const w = toWorld(4, G.pandaPos.x, G.pandaPos.y); A.panda.position.lerp(w, Math.min(1, dt * 6)); A.panda.rotation.y = Math.sin(G.t * 8) * 0.15; }
  }
  // floating numbers: a light DOM layer projected from the world camera
  const floatLayer = document.createElement("div"); Object.assign(floatLayer.style, { position: "absolute", inset: "0", pointerEvents: "none", overflow: "hidden" }); stage.insertBefore(floatLayer, frame.nextSibling);
  const floatEls = new Map();
  function syncFloats() {
    const live = new Set(), r = frame.getBoundingClientRect();
    for (const f of G.floats) {
      live.add(f); let el = floatEls.get(f);
      if (!el) { el = document.createElement("div"); el.textContent = f.text; Object.assign(el.style, { position: "absolute", font: "20px 'Fredoka One', sans-serif", color: f.color || "#fff", textShadow: "0 0 3px #000, 0 2px 0 #000", transform: "translate(-50%,-50%)", whiteSpace: "nowrap" }); floatLayer.appendChild(el); floatEls.set(f, el); }
      const p = toWorld(f.map, f.x, f.y); p.y += 8; p.project(W.camera);
      el.style.left = ((p.x + 1) / 2) * r.width + "px"; el.style.top = ((1 - p.y) / 2) * r.height + "px"; el.style.opacity = Math.min(1, f.life / 0.4);
    }
    for (const [f, el] of floatEls) if (!live.has(f)) { el.remove(); floatEls.delete(f); }
  }

  let miniT = 0, edgeT = 0;
  R3D.render = function (G, dt) {
    if (!A) return;
    const s = G.s, cur = s.currentMap, island = ISLAND_OF(cur);
    if (island !== A.lastIsland) { // arrived on another island: raise it if new, fly the camera over
      const n = reachedLevel();
      const first = A.lastIsland === null;
      if (n > A.level) { W.unlock(n, true); A.level = n; }
      A.lastIsland = island;
      A.player.position.copy(toWorld(cur, s.player.x, s.player.y));
      if (!first) placeCamera(true);
    }
    const pw = toWorld(cur, s.player.x, s.player.y);
    A.player.position.lerp(pw, 0.6);
    const k = pxScale(cur);
    animBird(A.player, G.vx * k, G.vy * k, dt, G.nestAcc > 0 && cur === PT.NEST_MAP ? Math.sin(G.t * 30) * 0.2 : 0);
    const rr = cur === 0 || cur === PT.DESERT_MAP || cur === PT.ECHO_FIELD_MAP ? PT.pickupProfile(s).collectRadius * k : 0;
    A.ring.visible = rr > 0; if (rr) { A.ring.scale.setScalar(rr); A.ring.position.set(pw.x, pw.y + 0.3, pw.z); }
    syncEggs(0, G.field.list(0), cur === 0);
    syncSparrows(cur === 0);
    syncNest(cur === PT.NEST_MAP, dt);
    syncDying(dt);
    placeCamera(false);
    syncFloats();
    // maps without a 3D scene yet: show their playtest drawing in the corner panel
    const flat = !SCENE3D[cur]; mini.style.display = flat ? "block" : "none";
    if (flat && (miniT -= dt) <= 0) { miniT = 0.1; const m = PT.MAPS[cur]; mini.height = Math.round(mini.width * (m.h / m.w)); G.render2D(mini); }
  };
  // walking off a map edge takes the arrow in that direction (the camera flies to the next island)
  R3D.edge = function (G, ix, iy, dt) {
    edgeT -= dt; const s = G.s, m = PT.MAPS[s.currentMap];
    const dir = s.player.x <= 21 && ix < 0 ? -1 : s.player.x >= m.w - 21 && ix > 0 ? 1 : 0;
    if (!dir || edgeT > 0) return;
    edgeT = 0.8; G.travel(dir);
  };
})();
