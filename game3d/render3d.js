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
  const SCENE3D = { 0: true, 1: true, 2: true, 4: true }; // + desert, echo field and mine, set at boot // maps with their own 3D game objects so far
  const WALK = { 0: true, 4: true }; // + desert and echo field, set at boot // maps where eggs / trees and the birb keep to open ground
  const isl = (id) => W.ISL.find((x) => x.id === ISLAND_OF(id));
  // map pixel -> world position on that map's island (the island's tile rectangle stands for the whole map)
  // where a map sits in the world: its island's tile rectangle, or for expedition floors / secret rooms a full-size arena
  // platform centred on the expedition island that keeps Birb's proportions (floors are 2000 x 4000)
  const ARENA_Y = 22; // floors float above the island so its trees never poke through
  const ROOMS = { 14: "#6b4a2c", 22: "#244a6e", 24: "#7f97aa", 26: "#26332c" }; // nest interior, aquarium, fish market, treasure room: floor colours
  const isArena = (id) => PT.EXP.isRunMap(id) || PT.EXP.isSecretRoom(id) || id in ROOMS;
  function rect(id) {
    const I = isl(id), m = PT.MAPS[id] || { w: 1056, h: 792 };
    if (!isArena(id)) return { x0: W.wx(I.oi), z0: W.wz(I.oj), w: I.W * W.S, d: I.N * W.S, m };
    const k = (I.W * W.S * (id in ROOMS ? 0.8 : 1.15)) / m.w, w = m.w * k, d = m.h * k, cx = W.wx(I.oi + I.W / 2), cz = W.wz(I.oj + I.N / 2);
    return { x0: cx - w / 2, z0: cz - d / 2, w, d, m, arena: true };
  }
  function toWorld(id, x, y) {
    const R = rect(id), wx = R.x0 + (x / R.m.w) * R.w, wz = R.z0 + (y / R.m.h) * R.d;
    return new T.Vector3(wx, R.arena ? ARENA_Y + (id in ROOMS ? 14 : 0) : W.groundY(wx, wz), wz);
  }
  function toMap(id, p) { const R = rect(id); return { x: ((p.x - R.x0) / R.w) * R.m.w, y: ((p.z - R.z0) / R.d) * R.m.h }; }
  const pxScale = (id) => { const R = rect(id); return R.w / R.m.w; }; // world units per map pixel

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
    // the Nest's forest is the game's own trees (Birb: 30 wild trees + planting beds), so the forest island's decorative trees step aside
    W.hideProps((p) => p.need === isl(PT.NEST_MAP).n && ["pine", "tree", "bush", "rock", "log", "deadtree"].includes(p.kind));
    for (const id of [PT.DESERT_MAP, PT.ECHO_FIELD_MAP, PT.MINE_MAP]) SCENE3D[id] = true;
    for (const id of Object.keys(PT.MAPS).map(Number)) if (isExp(id) || id in ROOMS) SCENE3D[id] = true;
    SCENE3D[3] = true;
    W.hideProps((p) => p.need === W.ISL.find((x) => x.id === "expedition").n); // the floors bring their own walls
    WALK[PT.DESERT_MAP] = WALK[PT.ECHO_FIELD_MAP] = true;
    buildBlocked();
    const n = reachedLevel(); W.resetTo(n); A.level = n;
    placeCamera(true);
  }
  frame.addEventListener("load", () => { const t0 = Date.now(), wait = () => { if (frame.contentWindow.WG) boot(); else if (Date.now() - t0 < 15000) setTimeout(wait, 100); }; wait(); });

  // ------------------------------------------------------------------ walkable ground: land tiles of a raised island, minus ponds and prop footprints
  const SOFT = new Set(["flowers", "sunflower", "lantern", "twigs", "mushroom", "flower", "post", "vine", "bones", "rails"]);
  const BIG = new Set(["tree", "pine", "palm", "tower", "keep", "temple", "pyramid", "greenhouse", "hut", "windmill", "monolith", "nesttree", "tent", "balloon", "mineentrance", "wall", "boat", "pier", "tank", "monster", "altar"]);
  let blocked = null;
  function buildBlocked() {
    blocked = new Set();
    for (const p of W.propsAll) {
      if (p.hidden || SOFT.has(p.kind)) continue;
      const d = W.DEFS[p.kind];
      if (p.need === 1 && d && d.w) { // park props: real footprints
        const x0 = p.x - (d.w * W.L) / 2, z0 = p.z - (d.d * W.L) / 2;
        for (let x = x0 + 0.5; x < x0 + d.w * W.L; x += 1) for (let z = z0 + 0.5; z < z0 + d.d * W.L; z += 1) blocked.add(W.key(Math.floor(x / W.S + W.COLS / 2), Math.floor(z / W.S + W.ROWS / 2)));
      } else { const r = BIG.has(p.kind) ? 1 : 0; for (let a = -r; a <= r; a++) for (let b = -r; b <= r; b++) blocked.add(W.key(p.i + a, p.j + b)); }
    }
  }
  function cellOk(id, x, y) {
    const p = toWorld(id, x, y), i = Math.floor(p.x / W.S + W.COLS / 2), j = Math.floor(p.z / W.S + W.ROWS / 2), t = W.byKey.get(W.key(i, j));
    return !!t && t.need <= Math.max(W.level, isl(id).n) && t.c !== 3 && !blocked.has(W.key(i, j));
  }
  const usesIsland = (id) => !!WALK[id];
  PT.spawnOk = (id, x, y) => !A || !usesIsland(id) || cellOk(id, x, y);
  PT.walkOk = (id, x, y) => !A || !usesIsland(id) || cellOk(id, x, y) || !cellOk(id, G.s.player.x, G.s.player.y); // never trap the birb
  const usableStart = (id) => { // drop the birb on open ground near where it stands
    if (!usesIsland(id) || cellOk(id, G.s.player.x, G.s.player.y)) return;
    const m = PT.MAPS[id];
    for (let r = 20; r < Math.max(m.w, m.h); r += 20) for (let a = 0; a < 16; a++) { const x = G.s.player.x + Math.cos(a / 16 * 6.28) * r, y = G.s.player.y + Math.sin(a / 16 * 6.28) * r;
      if (x > 20 && y > 20 && x < m.w - 20 && y < m.h - 20 && cellOk(id, x, y)) { G.s.player.x = x; G.s.player.y = y; return; } }
  };

  function reachedLevel() {
    const s = G.s, seen = (s.visitedIslands ||= ["park"]), cur = ISLAND_OF(s.currentMap);
    if (!seen.includes(cur)) seen.push(cur);
    return Math.max(1, ...seen.map((id) => W.ISL.find((x) => x.id === id)?.n || 1));
  }

  // ------------------------------------------------------------------ camera: fixed angle (looking straight north, tilted down), follows the birb, zoom clamped per island
  const POLAR = Math.PI / 2 - 0.9;
  function placeCamera(snap) {
    const R = rect(G.s.currentMap), I = { W: R.w / W.S, N: R.d / W.S }, p = A.player.position, c = W.controls, cam = W.camera;
    const r = frame.getBoundingClientRect(), aspect = r.width / Math.max(1, r.height), tanH = Math.tan((cam.fov * Math.PI) / 360);
    const span = Math.max((I.W * W.S + 40) / aspect, (I.N * W.S + 40) * Math.cos(POLAR)); // the island plus a band of sea
    c.maxDistance = Math.max(160, span / (2 * tanH)); c.minDistance = 60;
    const half = (I.W * W.S) / 2, halfD = (I.N * W.S) / 2, cx = R.x0 + R.w / 2, cz = R.z0 + R.d / 2;
    const tx = Math.max(cx - half, Math.min(cx + half, p.x)), tz = Math.max(cz - halfD, Math.min(cz + halfD, p.z));
    const want = new T.Vector3(tx, 0, tz);
    if (W.camera.fov !== 22) { W.camera.fov = 22; W.camera.updateProjectionMatrix(); }
    if (W.flying) W.stopFlight(); // the game camera always follows the birb (no long fly-overs)
    const off = cam.position.clone().sub(c.target), dist = snap ? Math.min(c.maxDistance, 260) : Math.min(c.maxDistance, Math.max(c.minDistance, off.length()));
    off.setFromSpherical(new T.Spherical(dist, POLAR, 0)); // keep the fixed angle whatever the controls did
    if (snap) c.target.copy(want); else c.target.lerp(want, 0.15);
    cam.position.copy(c.target).add(off);
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
  // ------------------------------------------------------------------ sunflower field stations: stone pedestals with a coloured top, an icon and a floating name / cost card
  const STATE_COL = { owned: "#4caf50", afford: "#f0b429", poor: "#9a7b45", locked: "#5b6170", platform: "#f2c94c" };
  const stations = new Map();
  function labelTex(name, cost, evo, state) {
    const cv = document.createElement("canvas"); cv.width = 512; cv.height = 168; const c = cv.getContext("2d");
    c.fillStyle = "rgba(11,12,16,.78)"; const r = 22; c.beginPath(); c.moveTo(r, 4); c.arcTo(508, 4, 508, 164, r); c.arcTo(508, 164, 4, 164, r); c.arcTo(4, 164, 4, 4, r); c.arcTo(4, 4, 508, 4, r); c.fill();
    c.textAlign = "center"; c.textBaseline = "middle"; c.lineJoin = "round";
    const line = (txt, y, size, col) => { c.font = `${size}px 'Fredoka One', sans-serif`; c.lineWidth = 8; c.strokeStyle = "#0b0c10"; c.strokeText(txt, 256, y); c.fillStyle = col; c.fillText(txt, 256, y); };
    line(name, cost ? 52 : 84, 46, "#ffffff"); if (cost) line(cost, 112, 38, state === "owned" ? "#b9f5a4" : state === "afford" ? "#ffe08a" : "#d9c7a4");
    if (evo) line("EVOLUTION " + evo, 150, 24, "#ff9a9a");
    const tex = new T.CanvasTexture(cv); tex.encoding = T.sRGBEncoding; return tex;
  }
  function syncStations(on) {
    const list = on ? G.fieldStations() : [], seen = new Set(), kx = pxScale(1), I = on ? isl(1) : null;
    for (const st of list) {
      seen.add(st.id); let o = stations.get(st.id);
      if (!o) {
        o = { g: new T.Group(), sig: "" };
        const base = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: new T.Color("#8d8a82").convertSRGBToLinear(), roughness: 0.85 })); base.castShadow = base.receiveShadow = true;
        const top = new T.Mesh(new T.BoxGeometry(1, 1, 1), new T.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5 })); top.castShadow = true;
        const card = new T.Sprite(new T.SpriteMaterial({ transparent: true, depthWrite: false })); card.renderOrder = 9;
        o.g.add(base, top, card); Object.assign(o, { base, top, card }); A.root.add(o.g); stations.set(st.id, o);
      }
      const c = toWorld(1, st.x + st.w / 2, st.y + st.h / 2), wW = Math.max(7, st.w * kx), wD = Math.max(7, st.h * ((I.N * W.S) / PT.MAPS[1].h));
      o.g.position.copy(c);
      o.base.scale.set(wW * 0.9, 1.6, wD * 0.9); o.base.position.y = 0.8;
      o.top.scale.set(wW * 0.8, 0.5, wD * 0.8); o.top.position.y = 1.85;
      o.top.material.color.set(STATE_COL[st.state] || "#888").convertSRGBToLinear();
      if (st.state === "afford") o.top.position.y = 1.85 + Math.abs(Math.sin(G.t * 3)) * 0.4;
      const sig = st.name + "|" + st.cost + "|" + st.evo + "|" + st.state;
      if (sig !== o.sig) { o.sig = sig; if (o.card.material.map) o.card.material.map.dispose(); o.card.material.map = labelTex(st.name, st.cost, st.evo, st.state); o.card.material.needsUpdate = true; }
      o.card.scale.set(27, 8.9, 1); o.card.position.y = 10;
    }
    for (const [id, o] of stations) if (!seen.has(id)) { A.root.remove(o.g); stations.delete(id); }
  }

  // ------------------------------------------------------------------ the Bridge: rod, line and bobber, a cast / reel bar over the birb, the last catch, seagulls
  const fishUi = document.createElement("div"); Object.assign(fishUi.style, { position: "absolute", pointerEvents: "none", transform: "translate(-50%,-100%)", textAlign: "center", font: "16px 'Fredoka One', sans-serif", color: "#fff", textShadow: "0 0 3px #000, 0 2px 0 #000", display: "none" });
  fishUi.innerHTML = '<div data-t style="white-space:nowrap;margin-bottom:4px"></div><div style="width:84px;height:12px;margin:0 auto;background:#10141a;border:2px solid #0b0c10;border-radius:6px;overflow:hidden"><i data-b style="display:block;height:100%;width:0"></i></div>';
  stage.appendChild(fishUi);
  let rig = null; const gulls = [];
  function syncBridge(on, dt) {
    if (!rig) { const lineM = new T.LineBasicMaterial({ color: 0xf5f5f5 }), g = new T.Group();
      const rod = new T.Mesh(new T.CylinderGeometry(0.12, 0.18, 9, 6), new T.MeshStandardMaterial({ color: new T.Color("#7a4b2a").convertSRGBToLinear() })); rod.castShadow = true;
      const bob = new T.Mesh(new T.SphereGeometry(0.7, 12, 8), new T.MeshStandardMaterial({ color: new T.Color("#ff3b30").convertSRGBToLinear(), roughness: 0.4 }));
      const lineG = new T.BufferGeometry().setFromPoints([new T.Vector3(), new T.Vector3()]), line = new T.Line(lineG, lineM);
      g.add(rod, bob, line); A.root.add(g); rig = { g, rod, bob, line, lineG }; }
    const F = G.fish || {}, s = G.s, busy = on && (F.casting > 0 || F.reeling > 0);
    rig.g.visible = busy;
    if (busy) {
      const face = A.player.userData.face, fw = new T.Vector3(Math.sin(face), 0, Math.cos(face)), base = A.player.position.clone();
      const tip = base.clone().add(new T.Vector3(0, 9, 0)).addScaledVector(fw, 5.5);
      rig.rod.position.copy(base).add(new T.Vector3(0, 4.5, 0)).addScaledVector(fw, 2.6); rig.rod.lookAt(tip); rig.rod.rotateX(Math.PI / 2);
      const k = F.casting > 0 ? 1 - F.casting / 0.5 : 1, far = base.clone().addScaledVector(fw, 6 + 16 * k);
      far.y = Math.max(W.SEA, W.groundY(far.x, far.z)) + (F.reeling > 0 ? Math.sin(G.t * 9) * 0.4 : 0.3);
      rig.bob.position.copy(far); rig.lineG.setFromPoints([tip, far]);
    }
    // bar + catch text over the birb
    const showBar = on && (F.casting > 0 || F.reeling > 0 || F.cooldown > 0), showTxt = on && F.last && F.lastT > 0;
    fishUi.style.display = showBar || showTxt ? "block" : "none";
    if (showBar || showTxt) {
      const p = A.player.position.clone().add(new T.Vector3(0, 9, 0)).project(W.camera), r = frame.getBoundingClientRect();
      fishUi.style.left = ((p.x + 1) / 2) * r.width + "px"; fishUi.style.top = ((1 - p.y) / 2) * r.height + "px";
      const b = fishUi.querySelector("[data-b]"), tx = fishUi.querySelector("[data-t]");
      fishUi.lastChild.style.visibility = showBar ? "visible" : "hidden";
      b.style.width = (F.casting > 0 ? (1 - F.casting / 0.5) : F.reeling > 0 ? 1 - F.reeling / Math.max(0.01, F.total) : 0) * 100 + "%";
      b.style.background = F.casting > 0 ? "#ffd27a" : "#4fd85a";
      tx.textContent = showTxt ? `${PT.fishName(F.last.fish.id)}${F.last.shiny ? " ★" : ""} ${F.last.weight}kg` : "";
      tx.style.color = showTxt ? PT.RARITY_COLOR[F.last.fish.rarity] : "#fff";
    }
    // seagulls circle the birb once met
    const n = on && s.hasMetSeagull ? s.seagull.gulls.length : 0;
    while (gulls.length < n) { const b = A.M.bird({ body: "#f4f6f8", belly: "#ffffff", wing: "#9aa4ad" }); b.scale.setScalar(A.BIRD * 0.55); A.root.add(b); gulls.push(b); }
    gulls.forEach((b, i) => { b.visible = i < n; if (i >= n) return; const a = G.t * 0.6 + (i / Math.max(1, n)) * 6.28, c = A.player.position;
      const x = c.x + Math.cos(a) * 14, z = c.z + Math.sin(a) * 9, last = b.position.clone(); b.position.set(x, c.y + 10 + Math.sin(G.t * 2 + i) * 1.2, z); animBird(b, (x - last.x) * 30, (z - last.z) * 30, dt, 0.9); });
  }

  // ------------------------------------------------------------------ Desert doves, Echo mushrooms, the Mine ore
  const doves = [], shrooms = [];
  function syncDesert(on, dt) {
    const a = on && G.daves && G.daves[0], list = a ? [a, ...a.sons] : [];
    while (doves.length < list.length) { const b = A.M.bird({ body: "#e9e4dc", belly: "#ffffff", wing: "#b9b0a3" }); A.root.add(b); doves.push(b); }
    doves.forEach((o, i) => { const b = list[i]; o.visible = !!b; if (!b) return; o.scale.setScalar(A.BIRD * (i ? 0.45 : 0.75)); const w = toWorld(PT.DESERT_MAP, b.x, b.y), last = o.userData.last || w;
      o.position.set(w.x, w.y + (b.state === "fly" ? 6 : 0), w.z); animBird(o, (w.x - last.x) * 10, (w.z - last.z) * 10, dt, b.state === "fly" ? 0.8 : 0); o.userData.last = w; });
  }
  function syncEcho(on) {
    const list = on ? PT.echoMushrooms(G.s) : [];
    while (shrooms.length < list.length) { const g = new T.Group(), st = new T.Mesh(new T.CylinderGeometry(0.5, 0.65, 1.6, 10), new T.MeshStandardMaterial({ color: new T.Color("#efe3d0").convertSRGBToLinear() }));
      const cap = new T.Mesh(new T.SphereGeometry(1.6, 16, 10, 0, 6.29, 0, 1.6), new T.MeshStandardMaterial({ color: new T.Color("#a77bff").convertSRGBToLinear(), emissive: new T.Color("#4b1d99").convertSRGBToLinear(), emissiveIntensity: 0.6 }));
      st.position.y = 0.8; cap.position.y = 1.5; st.castShadow = cap.castShadow = true; g.add(st, cap); A.root.add(g); shrooms.push(g); }
    shrooms.forEach((g, i) => { const m = list[i]; g.visible = !!m; if (m) { g.position.copy(toWorld(PT.ECHO_FIELD_MAP, m.x, m.y)); g.scale.setScalar(1.6 + Math.sin(G.t * 2 + i) * 0.05); } });
  }
  const ORE_COL = ["#8a6a4a", "#a7a9ad", "#7d7f86", "#7fd6ff", "#3a2b52", "#3fbf6f", "#e0284a"];
  let ore = null, crow = null;
  const oreBar = document.createElement("div"); Object.assign(oreBar.style, { position: "absolute", pointerEvents: "none", transform: "translate(-50%,-100%)", textAlign: "center", font: "16px 'Fredoka One', sans-serif", color: "#fff", textShadow: "0 0 3px #000, 0 2px 0 #000", display: "none" });
  oreBar.innerHTML = '<div data-t style="white-space:nowrap;margin-bottom:4px"></div><div style="width:150px;height:14px;margin:0 auto;background:#10141a;border:2px solid #0b0c10;border-radius:7px;overflow:hidden"><i data-b style="display:block;height:100%"></i></div>';
  stage.appendChild(oreBar);
  function syncMine(on, dt) {
    const Mn = G.mine || {}, o = on ? Mn.boss || Mn.ore : null;
    if (!ore) { // a chunky rock (the island's own props around it step aside)
      const I = isl(PT.MINE_MAP), ci = I.oi + (528 / PT.MAPS[PT.MINE_MAP].w) * I.W, cj = I.oj + (520 / PT.MAPS[PT.MINE_MAP].h) * I.N;
      W.hideProps((p) => p.need === I.n && Math.hypot(p.i - ci, p.j - cj) < 5); // a cluster of boxes, recoloured per ore
      ore = new T.Group(); const m = new T.MeshStandardMaterial({ roughness: 0.55, metalness: 0.15 });
      [[0, 1.6, 0, 4.4, 3.2, 4], [1.8, 0.9, 1, 2.4, 1.8, 2.4], [-1.9, 1, -0.6, 2.2, 2, 2.6], [0.4, 3.4, -0.3, 2.6, 1.6, 2.4]].forEach(([x, y, z, a, b, c]) => { const k = new T.Mesh(new T.BoxGeometry(a, b, c), m); k.position.set(x, y, z); k.rotation.y = x * 0.4; k.castShadow = true; ore.add(k); });
      ore.userData.m = m; A.root.add(ore); crow = A.M.bird({ body: "#2b2d33", belly: "#4a4d57", wing: "#1b1c21" }); crow.scale.setScalar(A.BIRD * 0.8); A.root.add(crow);
    }
    ore.visible = crow.visible = !!o; oreBar.style.display = o ? "block" : "none";
    if (!o) return;
    const c = toWorld(PT.MINE_MAP, 528, 520), sc = (o.boss ? 2.2 : 1) * 2.6;
    ore.position.copy(c); ore.scale.setScalar(sc * (1 + (Mn.hitPulse > 0 ? 0.04 : 0))); ore.rotation.y += dt * 0.15;
    ore.userData.m.color.set(o.golden ? "#ffc93c" : ORE_COL[o.tier] || "#888").convertSRGBToLinear(); ore.userData.m.metalness = o.golden ? 0.8 : 0.15;
    ore.userData.m.emissive.set(o.golden ? "#6a4400" : "#000000");
    const cw = toWorld(PT.MINE_MAP, 610, 560); crow.position.copy(cw); animBird(crow, -1, 0, dt, Math.sin(G.t * 12) * 0.15);
    const R = PT.MINE_RARITY[o.rank], p = c.clone().add(new T.Vector3(0, 9 * sc, 0)).project(W.camera), r = frame.getBoundingClientRect();
    oreBar.style.left = ((p.x + 1) / 2) * r.width + "px"; oreBar.style.top = ((1 - p.y) / 2) * r.height + "px";
    oreBar.querySelector("[data-t]").textContent = o.boss ? `GIANT ORE · ${Math.max(0, Math.ceil((Mn.bossUntil - Date.now()) / 1000))}s` : `${R.id.toUpperCase()} ${o.tierId.toUpperCase()}${o.golden ? " · GOLDEN" : ""}`;
    const b = oreBar.querySelector("[data-b]"); b.style.width = Math.max(0, Math.min(1, o.hits / o.maxHits)) * 100 + "%"; b.style.background = o.boss ? "#ef4444" : R.color;
  }

  // ------------------------------------------------------------------ Expedition: each floor is an arena on the expedition island (walls from Birb's collision boxes)
  const isExp = (id) => id === PT.EXP_HUB_MAP || id === PT.SACRIFICE_MAP || PT.EXP.isRunMap(id) || PT.EXP.isSecretRoom(id);
  const ENEMY_COL = { boss: "#f97316", elite: "#c084fc", shiny: "#facc15", normal: "#9aa3ad" };
  const exp = { map: null, walls: null, portals: [], foes: new Map(), parrot: null, totem: null, bars: new Map(), nums: new Map() };
  const expLayer = document.createElement("div"); Object.assign(expLayer.style, { position: "absolute", inset: "0", pointerEvents: "none", overflow: "hidden" }); stage.appendChild(expLayer);
  const stoneM = () => new T.MeshStandardMaterial({ color: new T.Color("#6f6a78").convertSRGBToLinear(), roughness: 0.9 });
  function buildArena(id) {
    if (exp.walls) A.root.remove(exp.walls); for (const q of exp.portals) A.root.remove(q.g); exp.portals = [];
    exp.walls = new T.Group(); const m = stoneM(), capM = new T.MeshStandardMaterial({ color: new T.Color("#8d879a").convertSRGBToLinear(), roughness: 0.8 });
    const k = pxScale(id), Rr = rect(id), kz = Rr.d / Rr.m.h;
    for (const r of PT.EXP.collisions(id)) {
      const w = (r.right - r.left) * k, d = (r.bottom - r.top) * kz; if (w < 0.5 || d < 0.5) continue;
      const c = toWorld(id, (r.left + r.right) / 2, (r.top + r.bottom) / 2), h = 5;
      const b = new T.Mesh(new T.BoxGeometry(w, h, d), m); b.position.set(c.x, c.y + h / 2, c.z); b.castShadow = b.receiveShadow = true;
      const cap = new T.Mesh(new T.BoxGeometry(w + 0.4, 0.6, d + 0.4), capM); cap.position.set(c.x, c.y + h + 0.3, c.z); exp.walls.add(b, cap);
    }
    if (Rr.arena) { // the floor itself: a raised slab in Birb's floor colour with a darker rim
      const fl = PT.MAPS[id].floor, col = PT.MAPS[id].night ? "#1d2440" : ["#4f7d47", "#6a4c84", "#b09a68", "#3b6b7c", "#355a78", "#a9cde0", "#4a6a38", "#3a3a48", "#5a2626"][(fl || 1) - 1];
      const slab = new T.Mesh(new T.BoxGeometry(Rr.w, 6, Rr.d), new T.MeshStandardMaterial({ color: new T.Color(col).convertSRGBToLinear(), roughness: 0.95 })); slab.position.set(Rr.x0 + Rr.w / 2, ARENA_Y - 3, Rr.z0 + Rr.d / 2); slab.receiveShadow = true;
      const rim = new T.Mesh(new T.BoxGeometry(Rr.w + 3, 5.4, Rr.d + 3), new T.MeshStandardMaterial({ color: new T.Color("#3b3646").convertSRGBToLinear(), roughness: 0.9 })); rim.position.set(slab.position.x, ARENA_Y - 3.4, slab.position.z);
      exp.walls.add(slab, rim);
    }
    A.root.add(exp.walls);
    for (const p of PT.EXP.portals(id)) {
      const g = new T.Group(), r = Math.max(3, p.r * k), ringM = new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.8, side: T.DoubleSide, depthWrite: false });
      const ringMesh = new T.Mesh(new T.RingGeometry(r * 0.75, r, 40), ringM); ringMesh.rotation.x = -Math.PI / 2; ringMesh.position.y = 0.4;
      const beam = new T.Mesh(new T.CylinderGeometry(r * 0.7, r * 0.7, 10, 24, 1, true), new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.18, side: T.DoubleSide, depthWrite: false })); beam.position.y = 5;
      g.add(ringMesh, beam); g.position.copy(toWorld(id, p.x, p.y)); A.root.add(g); exp.portals.push({ g, p, ringM, beam });
    }
    exp.map = id;
  }
  function foeModel(e) {
    const g = new T.Group(), col = e.isShiny ? ENEMY_COL.shiny : e.isBoss ? ENEMY_COL.boss : e.isElite ? ENEMY_COL.elite : ENEMY_COL.normal;
    const bodyM = new T.MeshStandardMaterial({ color: new T.Color(col).convertSRGBToLinear(), roughness: 0.5, emissive: new T.Color(0) });
    if (e.projectileKind) { const b = new T.Mesh(new T.SphereGeometry(0.6, 10, 8), new T.MeshBasicMaterial({ color: new T.Color("#fb923c") })); b.position.y = 1.5; g.add(b); g.userData = { bodyM }; return g; }
    const body = new T.Mesh(new T.SphereGeometry(1, 18, 14), bodyM); body.scale.set(1, 0.85, 1); body.position.y = 1; body.castShadow = true;
    const eyeW = new T.MeshStandardMaterial({ color: 0xffffff }), eyeB = new T.MeshStandardMaterial({ color: 0x111111 });
    for (const sx of [1, -1]) { const w = new T.Mesh(new T.SphereGeometry(0.2, 8, 6), eyeW); w.position.set(0.35 * sx, 1.3, 0.8); const b = new T.Mesh(new T.SphereGeometry(0.11, 6, 5), eyeB); b.position.set(0.35 * sx, 1.3, 0.97); g.add(w, b); }
    if (e.isBoss || e.isElite) for (const sx of [1, -1]) { const h = new T.Mesh(new T.ConeGeometry(0.22, 0.8, 6), new T.MeshStandardMaterial({ color: 0x2a2a2a })); h.position.set(0.5 * sx, 1.9, 0); h.rotation.z = -0.4 * sx; g.add(h); }
    g.add(body); g.userData = { bodyM, body };
    return g;
  }
  function domBar(key, x, y, frac, color, label) {
    let el = exp.bars.get(key);
    if (!el) { el = document.createElement("div"); Object.assign(el.style, { position: "absolute", transform: "translate(-50%,-100%)", textAlign: "center", font: "12px 'Fredoka One', sans-serif", color: "#fff", textShadow: "0 0 3px #000" });
      el.innerHTML = '<div data-l></div><div style="width:46px;height:7px;margin:0 auto;background:#10141a;border:2px solid #0b0c10;border-radius:4px;overflow:hidden"><i style="display:block;height:100%"></i></div>'; expLayer.appendChild(el); exp.bars.set(key, el); }
    el.dataset.live = "1"; el.style.left = x + "px"; el.style.top = y + "px"; el.firstChild.textContent = label || "";
    const i = el.querySelector("i"); i.style.width = Math.max(0, Math.min(1, frac)) * 100 + "%"; i.style.background = color;
  }
  function syncExp(on, dt) {
    const s = G.s, id = s.currentMap, run = on ? PT.expState(s).activeRun : null, r = frame.getBoundingClientRect();
    const scr = (v) => { const p = v.clone().project(W.camera); return [((p.x + 1) / 2) * r.width, ((1 - p.y) / 2) * r.height]; };
    for (const el of exp.bars.values()) el.dataset.live = "";
    if (!on) { if (exp.walls) { A.root.remove(exp.walls); exp.walls = null; for (const q of exp.portals) A.root.remove(q.g); exp.portals = []; exp.map = null; } }
    else {
      if (exp.map !== id) buildArena(id);
      for (const q of exp.portals) { const live = q.p.type !== "next_floor" || !!run?.exitPortal?.active, show = q.p.type !== "secret_room_enter" || (!!run && !run.nightMode && !!PT.EXP.SECRET_ROOMS[run.currentFloor]);
        q.g.visible = show; const col = !live ? "#55555f" : q.p.type === "next_floor" ? "#facc15" : "#a78bfa"; q.ringM.color.set(col); q.beam.material.color.set(col); q.g.rotation.y += dt * 0.8; }
    }
    // enemies
    const seen = new Set();
    if (run && PT.EXP.MAP_FLOOR[id]) for (const e of run.enemies) {
      if (e.health <= 0) continue; seen.add(e);
      let g = exp.foes.get(e); if (!g) { g = foeModel(e); A.root.add(g); exp.foes.set(e, g); }
      const w = toWorld(id, e.x, e.y), sc = e.type === "mini-fly" ? 1.1 : e.isBoss ? 6.5 : e.isElite ? 4.8 : e.projectileKind ? 1.4 : 3.4;
      g.position.set(w.x, w.y + (e.type === "mini-fly" ? 2.5 : 0), w.z); g.scale.setScalar(sc);
      const p = run.parrot; if (p) g.rotation.y = Math.atan2(p.x - e.x, p.y - e.y);
      if (g.userData.body) g.userData.body.position.y = 1 + Math.abs(Math.sin(G.t * 6 + e.x)) * 0.15;
      g.userData.bodyM.emissive.set(e.hitFlash > 0 ? "#ffffff" : /attack|hitting/.test(e.state) ? "#5a0a0a" : "#000000");
      if (e.type !== "mini-fly" && !e.projectileKind) { const [x, y] = scr(w.clone().add(new T.Vector3(0, 2.6 * sc, 0))); domBar(e, x, y, e.health / e.maxHealth, "#ef4444", e.isBoss || e.isElite ? e.type.replace(/-/g, " ").toUpperCase() : ""); }
    }
    for (const [e, g] of exp.foes) if (!seen.has(e)) { A.root.remove(g); exp.foes.delete(e); }
    // the parrot
    const p = run && run.parrot;
    if (!exp.parrot) { exp.parrot = A.M.bird({ body: "#2ecc71", belly: "#f1c40f", wing: "#e74c3c" }); exp.parrot.scale.setScalar(A.BIRD * 0.8); A.root.add(exp.parrot); }
    exp.parrot.visible = !!p && on;
    if (p && on) { const w = toWorld(id, p.x, p.y), last = exp.parrot.userData.last || w; exp.parrot.position.copy(w); animBird(exp.parrot, (w.x - last.x) * 20, (w.z - last.z) * 20, dt); exp.parrot.userData.last = w;
      const [x, y] = scr(w.clone().add(new T.Vector3(0, 7, 0))); domBar("parrot", x, y, p.health / p.maxHealth, "#4ade80"); }
    // totem
    const Tp = on ? PT.EXP.totem.position : null;
    if (!exp.totem) { exp.totem = new T.Mesh(new T.CylinderGeometry(0.9, 1.2, 7, 8), new T.MeshStandardMaterial({ color: new T.Color("#a78bfa").convertSRGBToLinear(), emissive: new T.Color("#3b1d7a") })); exp.totem.castShadow = true; A.root.add(exp.totem); }
    exp.totem.visible = !!Tp && Tp.mapId === id; if (exp.totem.visible) { exp.totem.position.copy(toWorld(id, Tp.x, Tp.y)).add(new T.Vector3(0, 3.5, 0)); exp.totem.material.color.set(PT.EXP.totemActive(s) ? "#a78bfa" : "#555555"); }
    // damage numbers
    const live = new Set();
    if (run && on) for (const d of run.damageNumbers) { live.add(d); let el = exp.nums.get(d);
      if (!el) { el = document.createElement("div"); el.textContent = d.text; Object.assign(el.style, { position: "absolute", transform: "translate(-50%,-50%)", font: "17px 'Fredoka One', sans-serif", color: d.color || "#fff", textShadow: "0 0 3px #000, 0 2px 0 #000", whiteSpace: "nowrap" }); expLayer.appendChild(el); exp.nums.set(d, el); }
      const [x, y] = scr(toWorld(id, d.x, d.y).add(new T.Vector3(0, 6, 0))); el.style.left = x + "px"; el.style.top = y + "px"; el.style.opacity = Math.min(1, d.life / 0.4); }
    for (const [d, el] of exp.nums) if (!live.has(d)) { el.remove(); exp.nums.delete(d); }
    for (const [k, el] of exp.bars) if (!el.dataset.live) { el.remove(); exp.bars.delete(k); }
  }

  // ------------------------------------------------------------------ rooms (raised platforms like the arenas) and the Castle monster
  const room = { id: null, g: null, cards: [], dyn: {} };
  const matC = (c, o = {}) => new T.MeshStandardMaterial({ color: new T.Color(c).convertSRGBToLinear(), roughness: 0.7, ...o });
  function card(pos, lines) { // a name card sprite that redraws only when its text changes
    const sp = new T.Sprite(new T.SpriteMaterial({ transparent: true, depthWrite: false })); sp.renderOrder = 9; sp.position.copy(pos); sp.scale.set(27, 8.9, 1); sp.userData.sig = "";
    sp.userData.set = (name, sub, state) => { const sig = name + "|" + sub + "|" + state; if (sig === sp.userData.sig) return; sp.userData.sig = sig; if (sp.material.map) sp.material.map.dispose(); sp.material.map = labelTex(name, sub, 0, state || "afford"); sp.material.needsUpdate = true; };
    sp.userData.set(lines[0], lines[1], lines[2]); return sp;
  }
  function box(g, w, h, d, x, y, z, m) { const b = new T.Mesh(new T.BoxGeometry(w, h, d), m); b.position.set(x, y, z); b.castShadow = b.receiveShadow = true; g.add(b); return b; }
  function buildRoom(id) {
    if (room.g) A.root.remove(room.g); room.g = new T.Group(); room.dyn = {}; room.id = id;
    const R = rect(id), cx = R.x0 + R.w / 2, cz = R.z0 + R.d / 2, Y = ARENA_Y + 14, at = (x, y) => toWorld(id, x, y);
    box(room.g, R.w, 6, R.d, cx, Y - 3, cz, matC(ROOMS[id], { roughness: 0.95 }));
    const wallM = matC(id === 24 ? "#b8ab98" : id === 22 ? "#1b3550" : id === 26 ? "#3a3a44" : "#4a3220"); // low back and side walls
    box(room.g, R.w, 6, 1.2, cx, Y + 3, R.z0 + 0.6, wallM); box(room.g, 1.2, 6, R.d, R.x0 + 0.6, Y + 3, cz, wallM); box(room.g, 1.2, 6, R.d, R.x0 + R.w - 0.6, Y + 3, cz, wallM);
    if (id === 14) { // nest interior: a woven bed, the panda
      const bed = at(528, 400); box(room.g, 22, 1.4, 11, bed.x, Y + 0.7, bed.z, matC("#9a6a3e"));
      const p = A.M.panda(); p.scale.setScalar(A.BIRD * 1.2); p.position.set(bed.x, Y + 1.4, bed.z); room.g.add(p); room.dyn.panda = p;
      room.dyn.card = card(at(528, 300).setY(Y + 14), ["Red Panda", ""]); room.g.add(room.dyn.card);
    } else if (id === 22) { // aquarium: one glass tank per biome, water filled by completion
      room.dyn.tanks = PT.AQ_BIOMES.map((b, i) => { const c = at(120 + (i % 3) * 460 + 200, 200 + Math.floor(i / 3) * 260 + 110), w = 400 * pxScale(id) * 0.9, d = 220 * (R.d / R.m.h) * 0.8;
        box(room.g, w + 1, 1, d + 1, c.x, Y + 0.5, c.z, matC("#2b2f36"));
        const glass = new T.Mesh(new T.BoxGeometry(w, 7, d), new T.MeshStandardMaterial({ color: 0xbfe6ff, transparent: true, opacity: 0.18, roughness: 0.05, metalness: 0.1 })); glass.position.set(c.x, Y + 4.5, c.z); room.g.add(glass);
        const water = box(room.g, w * 0.96, 1, d * 0.92, c.x, Y + 1, c.z, new T.MeshStandardMaterial({ color: new T.Color(b.color).convertSRGBToLinear(), transparent: true, opacity: 0.7, roughness: 0.1 }));
        const cd = card(c.clone().setY(Y + 13), [b.id.toUpperCase(), ""]); room.g.add(cd); return { b, water, cd, base: Y + 1 }; });
    } else if (id === 24) { // fish market: two stalls with striped awnings
      for (const [x, ic] of [[260, "BAIT MERCHANT"], [796, "FISH CONTRACTS"]]) { const c = at(x, 420);
        box(room.g, 16, 4, 7, c.x, Y + 2, c.z, matC("#8a5a32"));
        for (let i = 0; i < 6; i++) box(room.g, 16 / 6, 0.8, 9, c.x - 8 + (i + 0.5) * (16 / 6), Y + 8.5, c.z, matC(i % 2 ? "#f4f1ea" : "#c0392b"));
        for (const sx of [-1, 1]) box(room.g, 0.6, 8, 0.6, c.x + sx * 7.5, Y + 4, c.z + 3.5, matC("#6b3f1f"));
        room.g.add(card(c.clone().setY(Y + 15), [ic, ic === "BAIT MERCHANT" ? "" : "Press E"])); }
    } else if (id === 26) { // treasure room: one pedestal per mine-tree node
      room.dyn.nodes = PT.MINE_TREE.map((n, i) => { const c = at(200 + (i % 5) * 165, 240 + Math.floor(i / 5) * 110);
        box(room.g, 6, 1.6, 4, c.x, Y + 0.8, c.z, matC("#8d8a82")); const top = box(room.g, 5, 0.5, 3.2, c.x, Y + 1.85, c.z, matC("#888888"));
        const cd = card(c.clone().setY(Y + 6), [n.name, ""]); cd.scale.set(14, 4.6, 1); room.g.add(cd); return { n, top, cd }; });
    }
    A.root.add(room.g);
  }
  let monster = null;
  function syncRooms(cur, dt) {
    const s = G.s;
    if (cur in ROOMS) { if (room.id !== cur) buildRoom(cur); } else if (room.g) { A.root.remove(room.g); room.g = null; room.id = null; }
    if (room.id === 14) { const r = PT.redPandaState(s), nap = !r.introSeen || r.mode === "chill"; room.dyn.panda.visible = nap; room.dyn.panda.rotation.y = Math.sin(G.t * 0.5) * 0.2;
      room.dyn.card.userData.set(r.introSeen ? r.name : "zzz...", nap ? (r.introSeen ? "napping · eggs and seeds x1.25" : "Press E") : "helping outside", nap ? "owned" : "afford"); }
    if (room.id === 22) { const a = PT.aq(s); for (const q of room.dyn.tanks) { const pr = PT.aqBiome(a, q.b.id), h = Math.max(0.3, 6.4 * pr.completionRatio); q.water.scale.y = h; q.water.position.y = q.base + h / 2 - 0.5;
      q.cd.userData.set(q.b.id.toUpperCase(), `${pr.housedSpecies}/${pr.totalSpecies} · +${(PT.aqBiomeBuff(a, q.b.id) * 100).toFixed(0)}%`, pr.housedSpecies >= pr.totalSpecies ? "owned" : "afford"); } }
    if (room.id === 26) for (const q of room.dyn.nodes) { const vis = PT.mineNodeVisible(s, q.n.id), own = (s.sunflowerUpgrades["d_mine_" + q.n.id] || 0) > 0, unl = PT.mineNodeUnlocked(s, q.n.id);
      q.top.visible = q.cd.visible = vis; q.top.material.color.set(own ? "#4caf50" : unl ? "#f0b429" : "#5b6170").convertSRGBToLinear(); q.cd.userData.set(q.n.name, own ? "OWNED" : unl ? "Press E" : "locked", own ? "owned" : unl ? "afford" : "locked"); }
    // the Castle: the hungry monster
    const onCastle = cur === 3;
    if (onCastle && !monster) { monster = new T.Group(); const body = new T.Mesh(new T.SphereGeometry(1, 20, 14), matC("#6d5bd0")); body.scale.set(1.2, 1, 1); body.position.y = 1; body.castShadow = true;
      const mouth = new T.Mesh(new T.BoxGeometry(1.2, 0.25, 0.3), matC("#2a0f1f")); mouth.position.set(0, 0.85, 0.95);
      for (const sx of [1, -1]) { const e = new T.Mesh(new T.SphereGeometry(0.22, 10, 8), matC("#ffffff")); e.position.set(0.4 * sx, 1.45, 0.82); const pu = new T.Mesh(new T.SphereGeometry(0.11, 8, 6), matC("#111111")); pu.position.set(0.4 * sx, 1.45, 1); monster.add(e, pu); }
      monster.add(body, mouth); monster.scale.setScalar(9); monster.userData.card = card(new T.Vector3(0, 3.4, 0), ["THE MONSTER", ""]); monster.userData.card.scale.set(3, 1, 1); monster.add(monster.userData.card); A.root.add(monster); }
    if (monster) { monster.visible = onCastle; if (onCastle) { monster.position.copy(toWorld(3, 800, 500)); monster.scale.setScalar(9 * (1 + Math.sin(G.t * 2) * 0.03));
      monster.userData.card.userData.set("THE MONSTER", !s.hasTalkedToMonster ? "Click to talk" : s.evolutionCount >= 5 ? "Full and happy" : `Fed ${Math.floor(s.monsterFeedProgress || 0)}% · hold to feed`, s.evolutionCount >= 5 ? "owned" : "afford"); } }
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
      A.lastIsland = island; usableStart(cur);
      A.player.position.copy(toWorld(cur, s.player.x, s.player.y));
      if (!first) placeCamera(true);
    }
    // pale sand catches the glow pass, so the Desert gets a softer bloom
    const soft = island === "desert"; W.bloom.strength += ((soft ? 0.14 : 0.5) - W.bloom.strength) * 0.1; W.bloom.threshold = soft ? 0.93 : 0.78;
    const pw = toWorld(cur, s.player.x, s.player.y);
    A.player.position.lerp(pw, 0.6);
    const k = pxScale(cur);
    animBird(A.player, G.vx * k, G.vy * k, dt, G.nestAcc > 0 && cur === PT.NEST_MAP ? Math.sin(G.t * 30) * 0.2 : 0);
    const rr = cur === 0 || cur === PT.DESERT_MAP || cur === PT.ECHO_FIELD_MAP ? PT.pickupProfile(s).collectRadius * k : 0;
    A.ring.visible = rr > 0; if (rr) { A.ring.scale.setScalar(rr); A.ring.position.set(pw.x, pw.y + 0.3, pw.z); }
    syncEggs(0, G.field.list(0), cur === 0);
    syncSparrows(cur === 0);
    syncNest(cur === PT.NEST_MAP, dt);
    if (!A.gardenClear) { A.gardenClear = true; const I1 = isl(1), m1 = PT.MAPS[1]; // garden decor steps aside for the stations
      const rects = PT.STATIONS.map((st) => [I1.oi + (st[1] / m1.w) * I1.W - 1, I1.oj + (st[2] / m1.h) * I1.N - 1, I1.oi + ((st[1] + st[3]) / m1.w) * I1.W + 1, I1.oj + ((st[2] + st[4]) / m1.h) * I1.N + 1]);
      W.hideProps((p) => p.need === I1.n && rects.some(([a, b, c, d]) => p.i >= a && p.i <= c && p.j >= b && p.j <= d)); }
    syncStations(cur === 1);
    syncBridge(cur === 2, dt);
    syncEggs(PT.DESERT_MAP, G.field.list(PT.DESERT_MAP), cur === PT.DESERT_MAP);
    syncEggs(PT.ECHO_FIELD_MAP, G.field.list(PT.ECHO_FIELD_MAP), cur === PT.ECHO_FIELD_MAP);
    syncExp(isExp(cur), dt);
    syncRooms(cur, dt);
    syncDesert(cur === PT.DESERT_MAP, dt); syncEcho(cur === PT.ECHO_FIELD_MAP); syncMine(cur === PT.MINE_MAP, dt);
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
    const coast = (d) => usesIsland(s.currentMap) && !cellOk(s.currentMap, s.player.x + d * 40, s.player.y); // the shore counts as the edge
    const dir = ix < 0 && (s.player.x <= 21 || (s.player.x < m.w * 0.25 && coast(-1))) ? -1 : ix > 0 && (s.player.x >= m.w - 21 || (s.player.x > m.w * 0.75 && coast(1))) ? 1 : 0;
    if (!dir || edgeT > 0) return;
    edgeT = 0.8; G.travel(dir);
  };
})();
