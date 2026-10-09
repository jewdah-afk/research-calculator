// Peckwood 3D (web): a 2.5D view of the playtest. All game logic comes from ../playtest/js (1:1 with Birb); this file only draws it.
// Fixed camera angle (looking straight ahead, tilted down), orthographic, free zoom clamped to the visible world plus a band of sea.
// Maps sit side by side in one world (Nest | Park | Sunflower Field | Bridge) and you walk across their edges.
// Maps without a 3D scene yet are drawn flat (the playtest's 2D drawing) onto a 3D ground plate, so every area stays playable.
"use strict";
(function () {
  const PT = window.PT, G = PT.G, T = THREE;
  const C = (c) => new T.Color(c).convertSRGBToLinear(); // hex colours are sRGB; the renderer works in linear
  const U = 1 / 40; // world units per Birb map pixel
  const CELL = 48; // one LEGO ground column = 48 map px

  // ------------------------------------------------------------------ layout: map offsets in map pixels (x right, y down = +z)
  // Edges line up where Birb's arrows connect them; the y offsets match the spot travel() drops you at.
  const LAYOUT = { 4: { ox: -1600, oy: -200 }, 0: { ox: 0, oy: 0 }, 1: { ox: 1056, oy: -244 }, 2: { ox: 5056, oy: 56 } };
  const ROOM_BASE = { x: 0, y: 6000 }; // standalone rooms (interior, aquarium, mine, expedition...) float south of the world, one slot each
  const roomSlot = new Map();
  function origin(id) {
    if (LAYOUT[id]) return LAYOUT[id];
    if (!roomSlot.has(id)) roomSlot.set(id, roomSlot.size);
    return { ox: ROOM_BASE.x + roomSlot.get(id) * 5000, oy: ROOM_BASE.y, room: true };
  }
  const W3 = (id, x, y) => { const o = origin(id); return new T.Vector3((o.ox + x) * U, 0, (o.oy + y) * U); };

  // ------------------------------------------------------------------ renderer, scene, camera
  const stage = document.getElementById("stage"), flatCv = document.getElementById("view");
  flatCv.style.display = "none";
  const renderer = new T.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
  renderer.outputEncoding = T.sRGBEncoding; renderer.toneMapping = T.NoToneMapping;
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = T.PCFSoftShadowMap;
  const cvs = renderer.domElement; cvs.id = "view3d"; Object.assign(cvs.style, { position: "absolute", inset: "0", width: "100%", height: "100%", display: "block", cursor: "crosshair" });
  stage.insertBefore(cvs, stage.firstChild);
  const scene = new T.Scene();
  scene.background = C("#1f7fbf");
  const PITCH = 52 * Math.PI / 180; // camera tilt above the ground
  const camera = new T.OrthographicCamera(-10, 10, 10, -10, 0.1, 400);
  let viewH = 18, viewTarget = 18; // world units visible top to bottom
  const camPos = new T.Vector3(); let camInit = false;

  const hemi = new T.HemisphereLight(C("#eaf6ff"), C("#5a7d3a"), 0.85); scene.add(hemi);
  const sun = new T.DirectionalLight(C("#fff3d6"), 1.6); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048); sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.02;
  scene.add(sun, sun.target);

  // ------------------------------------------------------------------ materials
  const lin = (o) => { for (const k of ["color", "emissive"]) if (typeof o[k] === "string") o[k] = C(o[k]); return o; };
  const mat = (c, o = {}) => new T.MeshStandardMaterial(lin({ color: c, roughness: 0.75, metalness: 0, ...o }));
  const M = {
    grass: mat("#ffffff", { roughness: 0.9 }), soil: mat("#8a5a34", { roughness: 0.95 }), rock: mat("#7d7a74", { roughness: 0.95 }), sand: mat("#e8d29c", { roughness: 0.95 }),
    water: new T.MeshStandardMaterial(lin({ color: "#1f7fbf", roughness: 0.18, metalness: 0.05, transparent: true, opacity: 0.86 })),
    seabed: mat("#b9a979"), wood: mat("#9a6235"), woodDark: mat("#6b3f1f"), bark: mat("#7a4b2a"), leaf: mat("#3f8f3a", { roughness: 0.8 }), pine: mat("#2f7a46", { roughness: 0.8 }),
    straw: mat("#c99a52", { roughness: 0.95 }), white: mat("#ffffff"), black: mat("#151515", { roughness: 0.4 }), beak: mat("#ff9a1f", { roughness: 0.5 }),
    ring: new T.MeshBasicMaterial({ color: C("#ffffff"), transparent: true, opacity: 0.28, depthWrite: false }),
    hpBack: new T.MeshBasicMaterial({ color: C("#1b1b1b") }), hpFill: new T.MeshBasicMaterial({ color: C("#7bd34f") }),
  };

  // ------------------------------------------------------------------ deterministic noise for ground tint and coastlines
  const hash = (x, y, s = 0) => { let h = (Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ s) >>> 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
  const smooth = (x, y, sc, s) => { const gx = x / sc, gy = y / sc, x0 = Math.floor(gx), y0 = Math.floor(gy), fx = gx - x0, fy = gy - y0, u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
    const a = hash(x0, y0, s), b = hash(x0 + 1, y0, s), c = hash(x0, y0 + 1, s), d = hash(x0 + 1, y0 + 1, s); return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v; };

  // ------------------------------------------------------------------ ground: LEGO brick columns (top plate + studs + earth body), ragged sandy coast
  const THEME = { 0: ["#5fa83f", "#4e9435"], 4: ["#4f9640", "#3f8035"], 1: ["#7fae44", "#6a9a3a"], 2: ["#5ba243", "#4a8c3a"], 9: ["#d9b874", "#c6a460"] };
  const boxG = new T.BoxGeometry(1, 1, 1), studG = new T.CylinderGeometry(0.17, 0.17, 0.12, 12);
  const worldGroup = new T.Group(); scene.add(worldGroup);
  const built = new Map(); // map id -> { group, cells:Set }
  const landCells = new Map(); // "gx,gy" (global cells) -> top height, for the coast pass

  function buildGround(id, scene3d) {
    const m = PT.MAPS[id], o = origin(id), g = new T.Group(), [ca, cb] = THEME[id] || ["#7cbf55", "#68a847"];
    const cols = Math.ceil(m.w / CELL), rows = Math.ceil(m.h / CELL), cs = CELL * U;
    const tops = [], col = new T.Color(), A = C(ca), B = C(cb);
    for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
      const x = i * CELL + CELL / 2, y = j * CELL + CELL / 2;
      if (id === 4 && y > 2000) continue; // the Nest's south lake stays open water
      const gx = Math.round((o.ox + x) / CELL), gy = Math.round((o.oy + y) / CELL);
      const n = smooth(gx, gy, 6, 7), k = 0.5 + 0.5 * (n - 0.5) * 1.6 + (hash(gx, gy, 3) - 0.5) * 0.18;
      col.copy(A).lerp(B, Math.max(0, Math.min(1, k)));
      tops.push({ x: o.ox + x, y: o.oy + y, c: col.clone(), h: 0 });
      landCells.set(gx + "," + gy, 0); scene3d.keys.push(gx + "," + gy);
    }
    addColumns(g, tops, cs, scene3d.studs);
    return g;
  }
  function addColumns(g, tops, cs, studsPer, sand) {
    const n = tops.length; if (!n) return;
    const top = new T.InstancedMesh(boxG, sand ? M.sand : M.grass, n), body = new T.InstancedMesh(boxG, sand ? M.sand : M.soil, n);
    const st = new T.InstancedMesh(studG, sand ? M.sand : M.grass, n * studsPer * studsPer), mm = new T.Matrix4(), q = new T.Quaternion(), sc = new T.Vector3(), p = new T.Vector3();
    let si = 0;
    tops.forEach((t, i) => {
      const h = t.h, cx = t.x * U, cz = t.y * U;
      mm.compose(p.set(cx, h - 0.06, cz), q, sc.set(cs, 0.12, cs)); top.setMatrixAt(i, mm); top.setColorAt(i, t.c);
      const depth = 1.6 + h; mm.compose(p.set(cx, h - 0.12 - depth / 2, cz), q, sc.set(cs * 0.998, depth, cs * 0.998)); body.setMatrixAt(i, mm);
      body.setColorAt(i, sand ? t.c : C(hash(Math.round(t.x), Math.round(t.y), 5) < 0.5 ? "#ffffff" : "#e2cfbd")); // every instanced mesh carries colours (shared materials)
      for (let a = 0; a < studsPer; a++) for (let b = 0; b < studsPer; b++) {
        const off = (k) => (studsPer === 1 ? 0 : (k - (studsPer - 1) / 2) * (cs / studsPer));
        mm.compose(p.set(cx + off(a), h + 0.06, cz + off(b)), q, sc.set(studsPer === 1 ? 1.6 : 1, 1, studsPer === 1 ? 1.6 : 1)); st.setMatrixAt(si, mm); st.setColorAt(si++, t.c);
      }
    });
    for (const im of [top, body, st]) { im.receiveShadow = true; im.castShadow = im !== st; if (im.instanceColor) im.instanceColor.needsUpdate = true; g.add(im); }
  }
  // sand beaches: two ragged rings of lower sand columns around all land (skips cells where land already is)
  let coast = null;
  function rebuildCoast() {
    if (coast) { worldGroup.remove(coast); coast.traverse((o) => o.isInstancedMesh && o.dispose()); }
    coast = new T.Group();
    const sand = [], seen = new Set(), land = new Set();
    for (const e of built.values()) if (e.group.visible) for (const k of e.keys) land.add(k);
    for (const key of land) {
      const [gx, gy] = key.split(",").map(Number);
      for (let dy = -3; dy <= 3; dy++) for (let dx = -3; dx <= 3; dx++) {
        const k = gx + dx + "," + (gy + dy); if (land.has(k) || seen.has(k)) continue;
        const d = Math.hypot(dx, dy), r = 1.4 + 1.6 * smooth(gx + dx, gy + dy, 4, 11);
        if (d > r) continue;
        seen.add(k);
        const c = C("#e3cf9e").lerp(C("#d2bb88"), hash(gx + dx, gy + dy, 2));
        sand.push({ x: (gx + dx) * CELL, y: (gy + dy) * CELL, c, h: -0.28 - 0.12 * Math.min(2, d - 0.8) });
      }
    }
    addColumns(coast, sand, CELL * U, 1, true);
    worldGroup.add(coast);
  }

  // sea + seabed
  const sea = new T.Mesh(new T.PlaneGeometry(1, 1, 1, 1), M.water); sea.rotation.x = -Math.PI / 2; sea.position.y = -0.45; sea.receiveShadow = true;
  const bed = new T.Mesh(new T.PlaneGeometry(1, 1), M.seabed); bed.rotation.x = -Math.PI / 2; bed.position.y = -1.4;
  scene.add(sea, bed);

  // ------------------------------------------------------------------ models (clean, low-poly; not LEGO)
  const eggProfile = []; for (let i = 0; i <= 16; i++) { const t = i / 16, a = t * Math.PI; const r = Math.sin(a) * (t < 0.5 ? 0.21 : 0.21 - 0.05 * (t - 0.5) * 2); eggProfile.push(new T.Vector2(Math.max(0.001, r), -Math.cos(a) * 0.29 + 0.29)); }
  const eggG = new T.LatheGeometry(eggProfile, 20); eggG.computeVertexNormals();
  const rainbowG = (() => { const g = eggG.clone(), pos = g.attributes.position, cols = []; const pal = ["#ff5d5d", "#ffb347", "#ffe66d", "#6ddc7a", "#5ab4ff", "#a77bff"].map(C);
    for (let i = 0; i < pos.count; i++) { const k = Math.min(5, Math.floor((pos.getY(i) / 0.58) * 6)); cols.push(pal[k].r, pal[k].g, pal[k].b); } g.setAttribute("color", new T.Float32BufferAttribute(cols, 3)); return g; })();
  const EGG_MAT = {
    plain: mat("#f6eedb", { roughness: 0.45 }), butter: mat("#f2c46b", { roughness: 0.4 }), caramel: mat("#c46f2b", { roughness: 0.35 }), cheese: mat("#ffc21a", { roughness: 0.4 }),
    rainbow: new T.MeshStandardMaterial(lin({ vertexColors: true, roughness: 0.35 })), red: mat("#e8202a", { roughness: 0.22, metalness: 0.1 }),
    golden: new T.MeshStandardMaterial(lin({ color: "#ffc93c", metalness: 0.85, roughness: 0.22, emissive: "#6a4400", emissiveIntensity: 0.35 })),
    echo: new T.MeshStandardMaterial(lin({ color: "#b37bff", roughness: 0.3, emissive: "#5a20b0", emissiveIntensity: 0.6 })),
  };
  const EGG_SIZE = { plain: 1, butter: 1, caramel: 1.05, cheese: 1.08, rainbow: 1.12, red: 1.15, golden: 1.15, echo: 1.1 };
  function makeEgg(type) {
    const m = new T.Mesh(type === "rainbow" ? rainbowG : eggG, EGG_MAT[type] || EGG_MAT.plain); m.castShadow = true;
    const g = new T.Group(); g.add(m); g.userData.mesh = m; g.scale.setScalar(EGG_SIZE[type] || 1); return g;
  }
  function makeBird({ body = "#ffc23a", belly = "#ffe7a3", wing = "#f0a21c", scale = 1 } = {}) {
    const g = new T.Group(), b = new T.Group(); g.add(b);
    const bodyM = new T.Mesh(new T.SphereGeometry(0.42, 24, 18), mat(body, { roughness: 0.55 })); bodyM.scale.set(1, 0.92, 1.05); bodyM.position.y = 0.46; bodyM.castShadow = true;
    const bellyM = new T.Mesh(new T.SphereGeometry(0.3, 18, 14), mat(belly, { roughness: 0.6 })); bellyM.position.set(0, 0.38, 0.2); bellyM.scale.set(1, 0.9, 0.7);
    const beak = new T.Mesh(new T.ConeGeometry(0.09, 0.22, 12), M.beak); beak.rotation.x = Math.PI / 2; beak.position.set(0, 0.55, 0.47); beak.castShadow = true;
    const eye = (sx) => { const e = new T.Group(), w = new T.Mesh(new T.SphereGeometry(0.075, 12, 10), M.white), p = new T.Mesh(new T.SphereGeometry(0.045, 10, 8), M.black); p.position.z = 0.04; e.add(w, p); e.position.set(0.17 * sx, 0.66, 0.34); return e; };
    const wingG = new T.SphereGeometry(0.22, 14, 10), wm = mat(wing, { roughness: 0.6 });
    const wl = new T.Mesh(wingG, wm), wr = new T.Mesh(wingG, wm); wl.scale.set(0.35, 0.75, 1); wr.scale.copy(wl.scale); wl.position.set(-0.4, 0.45, -0.02); wr.position.set(0.4, 0.45, -0.02); wl.castShadow = wr.castShadow = true;
    const tail = new T.Mesh(new T.ConeGeometry(0.14, 0.3, 10), wm); tail.rotation.x = -Math.PI / 2.6; tail.position.set(0, 0.42, -0.45);
    const tuft = new T.Mesh(new T.ConeGeometry(0.06, 0.18, 8), wm); tuft.position.set(0, 0.92, 0.05); tuft.rotation.x = 0.4;
    const leg = (sx) => { const l = new T.Mesh(new T.CylinderGeometry(0.03, 0.03, 0.14, 6), M.beak); l.position.set(0.12 * sx, 0.06, 0.04); return l; };
    b.add(bodyM, bellyM, beak, eye(1), eye(-1), wl, wr, tail, tuft, leg(1), leg(-1));
    g.userData = { b, wl, wr, phase: Math.random() * 6, face: 0 };
    g.scale.setScalar(scale);
    return g;
  }
  function animBird(g, vx, vz, dt, extra = 0) {
    const u = g.userData, sp = Math.hypot(vx, vz);
    if (sp > 0.05) { const want = Math.atan2(vx, vz); let d = want - u.face; d = Math.atan2(Math.sin(d), Math.cos(d)); u.face += d * Math.min(1, dt * 12); }
    g.rotation.y = u.face;
    u.phase += dt * (sp > 0.05 ? 14 : 3);
    u.b.position.y = sp > 0.05 ? Math.abs(Math.sin(u.phase)) * 0.12 : Math.sin(u.phase) * 0.012;
    const flap = sp > 0.05 ? Math.sin(u.phase * 1.5) * 0.5 : 0.08 * Math.sin(u.phase);
    u.wl.rotation.z = 0.15 + flap + extra; u.wr.rotation.z = -0.15 - flap - extra;
  }
  function makeTree() { // nest pine: trunk + three cones
    const g = new T.Group(), tr = new T.Mesh(new T.CylinderGeometry(0.1, 0.14, 0.5, 8), M.bark); tr.position.y = 0.25; tr.castShadow = true; g.add(tr);
    [[0.62, 0.7, 0.75], [0.5, 0.6, 1.15], [0.36, 0.5, 1.5]].forEach(([r, h, y]) => { const c = new T.Mesh(new T.ConeGeometry(r, h, 9), M.pine); c.position.y = y; c.castShadow = true; g.add(c); });
    const bar = new T.Group(), bk = new T.Mesh(new T.BoxGeometry(0.9, 0.1, 0.04), M.hpBack), fl = new T.Mesh(new T.BoxGeometry(0.86, 0.07, 0.05), M.hpFill); bar.add(bk, fl); bar.position.y = 2.05; bar.rotation.x = -(Math.PI / 2 - PITCH);
    g.add(bar); g.userData = { bar, fill: fl };
    return g;
  }
  function makeRoundTree(s = 1) { const g = new T.Group(), tr = new T.Mesh(new T.CylinderGeometry(0.12, 0.16, 0.7, 8), M.bark); tr.position.y = 0.35; tr.castShadow = true;
    const c = new T.Mesh(new T.IcosahedronGeometry(0.6, 1), M.leaf); c.position.y = 1.05; c.castShadow = true; const c2 = c.clone(); c2.scale.setScalar(0.65); c2.position.set(0.35, 0.85, 0.1); g.add(tr, c, c2); g.scale.setScalar(s); return g; }
  function makeBush(s = 1) { const g = new T.Group(); for (let i = 0; i < 3; i++) { const c = new T.Mesh(new T.IcosahedronGeometry(0.28, 1), M.leaf); c.position.set((i - 1) * 0.25, 0.22, (i % 2) * 0.1); c.castShadow = true; g.add(c); } g.scale.setScalar(s); return g; }
  function makeFlower(color) { const g = new T.Group(), st = new T.Mesh(new T.CylinderGeometry(0.015, 0.015, 0.22, 4), M.leaf); st.position.y = 0.11; const h = new T.Mesh(new T.SphereGeometry(0.06, 8, 6), mat(color)); h.position.y = 0.24; g.add(st, h); return g; }
  function makePlanter() { const g = new T.Group(), b = new T.Mesh(new T.BoxGeometry(100 * U, 0.28, 92 * U), M.wood); b.position.y = 0.14; b.castShadow = b.receiveShadow = true;
    const soil = new T.Mesh(new T.BoxGeometry(100 * U - 0.2, 0.05, 92 * U - 0.2), mat("#5a3a22")); soil.position.y = 0.29; g.add(b, soil); return g; }
  function makeNest() {
    const g = new T.Group(), trunk = new T.Mesh(new T.CylinderGeometry(1.2, 1.7, 3.2, 14), M.bark); trunk.position.y = 1.6; trunk.castShadow = true;
    const canopy = new T.Mesh(new T.IcosahedronGeometry(2.6, 1), mat("#3e7f36", { roughness: 0.85 })); canopy.position.y = 4.6; canopy.scale.set(1.25, 0.8, 1); canopy.castShadow = true;
    const nest = new T.Mesh(new T.TorusGeometry(1.15, 0.42, 10, 24), M.straw); nest.rotation.x = Math.PI / 2; nest.position.set(0, 3.25, 1.2); nest.castShadow = true;
    const inside = new T.Mesh(new T.CircleGeometry(1.0, 20), mat("#7c5326")); inside.rotation.x = -Math.PI / 2; inside.position.set(0, 3.3, 1.2);
    for (let i = 0; i < 3; i++) { const e = makeEgg("plain"); e.position.set((i - 1) * 0.42, 3.3, 1.2 + (i % 2) * 0.2); g.add(e); }
    g.add(trunk, canopy, nest, inside); return g;
  }
  function makePanda() { const g = new T.Group(), body = new T.Mesh(new T.SphereGeometry(0.38, 16, 12), mat("#d8572a")); body.position.y = 0.38; body.scale.set(1, 0.85, 1.15); body.castShadow = true;
    const head = new T.Mesh(new T.SphereGeometry(0.26, 16, 12), mat("#e2672f")); head.position.set(0, 0.7, 0.3); const face = new T.Mesh(new T.SphereGeometry(0.16, 12, 10), M.white); face.position.set(0, 0.66, 0.46); face.scale.z = 0.5;
    const tail = new T.Mesh(new T.CylinderGeometry(0.1, 0.14, 0.6, 10), mat("#7a2e10")); tail.rotation.x = 1.1; tail.position.set(0, 0.35, -0.5);
    g.add(body, head, face, tail); return g; }

  // ------------------------------------------------------------------ scenes per map (3D) — the Park and the Nest so far
  const scenes = new Map();
  const SCENE3D = { 0: true, 4: true };
  function decorate(id, g) { // decor ring just outside the playable rect (never on the play area)
    const m = PT.MAPS[id], o = origin(id), rnd = (k) => hash(id * 97 + k, k * 13, 9);
    const n = Math.round((m.w + m.h) / 90);
    for (let i = 0; i < n; i++) {
      const side = i % 4, t = rnd(i), x = side < 2 ? t * m.w : side === 2 ? -30 - rnd(i + 50) * 40 : m.w + 30 + rnd(i + 50) * 40, y = side >= 2 ? t * m.h : side === 0 ? -30 - rnd(i + 70) * 40 : m.h + 30 + rnd(i + 70) * 40;
      const gx = Math.round((o.ox + x) / CELL), gy = Math.round((o.oy + y) / CELL);
      if (landCells.has(gx + "," + gy) && !(x < 0 || y < 0 || x > m.w || y > m.h)) continue;
      if (Object.values(LAYOUT).some((L) => L !== o && LAYOUT[id] && inRect(L, o.ox + x, o.oy + y))) continue; // don't block a connected neighbour
      const obj = rnd(i + 200) < 0.35 ? makeRoundTree(0.8 + rnd(i + 9) * 0.5) : rnd(i + 200) < 0.7 ? makeBush(0.8 + rnd(i) * 0.6) : makeFlower(["#ff6f91", "#ffd23f", "#ffffff", "#9b8cff"][i % 4]);
      obj.position.set((o.ox + x) * U, landCells.has(gx + "," + gy) ? 0 : -0.3, (o.oy + y) * U); obj.rotation.y = rnd(i + 300) * 6.28; g.add(obj);
    }
  }
  const inRect = (L, x, y) => { const id = +Object.keys(LAYOUT).find((k) => LAYOUT[k] === L), m = PT.MAPS[id]; return x >= L.ox - 60 && x <= L.ox + m.w + 60 && y >= L.oy - 60 && y <= L.oy + m.h + 60; };

  function ensureMap(id) {
    if (built.has(id)) return built.get(id);
    const g = new T.Group(), entry = { group: g, id, keys: [] };
    g.add(buildGround(id, { studs: id === 0 || id === 4 ? 2 : 1, keys: entry.keys }));
    if (!SCENE3D[id]) { // flat fallback: the playtest drawing on a plate just above the bricks
      const m = PT.MAPS[id], k = Math.min(1, 2048 / Math.max(m.w, m.h)), c = document.createElement("canvas"); c.width = Math.round(m.w * k); c.height = Math.round(m.h * k);
      const tex = new T.CanvasTexture(c); tex.encoding = T.sRGBEncoding; tex.anisotropy = 4;
      const plate = new T.Mesh(new T.PlaneGeometry(m.w * U, m.h * U), new T.MeshStandardMaterial({ map: tex, roughness: 0.9, transparent: true, opacity: 0.96 }));
      plate.rotation.x = -Math.PI / 2; plate.position.copy(W3(id, m.w / 2, m.h / 2)); plate.position.y = 0.14; plate.receiveShadow = true; g.add(plate);
      entry.flat = { c, tex, t: 0 };
    }
    if (LAYOUT[id]) decorate(id, g);
    if (id === 4) { const n = makeNest(); n.position.copy(W3(4, 800, 150)); g.add(n); }
    worldGroup.add(g); built.set(id, entry);
    return entry;
  }

  // ------------------------------------------------------------------ dynamic objects
  const player = makeBird(); scene.add(player);
  const ring = new T.Mesh(new T.RingGeometry(0.97, 1, 64), M.ring); ring.rotation.x = -Math.PI / 2; scene.add(ring);
  const eggs = new Map(), dying = [];
  const sparrowObjs = [];
  const trees = new Map(), planters = new Map();
  const panda = makePanda(); panda.visible = false; scene.add(panda);
  const dyn = new T.Group(); scene.add(dyn);

  function syncEggs(map, list, visible) {
    const seen = new Set();
    if (visible) for (const p of list) {
      const key = map + ":" + p.id; seen.add(key);
      let e = eggs.get(key);
      if (!e) { e = makeEgg(p.type); e.userData.born = 0; e.userData.spin = hash(p.id, 1, 4) * 6.28; dyn.add(e); eggs.set(key, e); }
      const w = W3(map, p.x, p.y); e.position.set(w.x, 0.12, w.z);
      e.userData.born = Math.min(1, e.userData.born + 1 / 14);
      const b = e.userData.born, pop = b < 1 ? 1 + Math.sin(b * Math.PI) * 0.35 : 1;
      e.userData.mesh.scale.setScalar(b * pop); e.rotation.y = e.userData.spin; e.userData.mesh.rotation.z = Math.sin(G.t * 2 + e.userData.spin) * 0.06;
    }
    for (const [key, e] of eggs) if (key.startsWith(map + ":") && !seen.has(key)) { eggs.delete(key); if (visible) dying.push({ e, t: 0 }); else dyn.remove(e); }
  }
  function updateDying(dt) {
    for (let i = dying.length - 1; i >= 0; i--) { const d = dying[i]; d.t += dt / 0.2; const k = Math.min(1, d.t);
      d.e.position.lerp(new T.Vector3(player.position.x, 0.6, player.position.z), k * 0.5); d.e.scale.setScalar(Math.max(0.01, 1 - k));
      if (k >= 1) { dyn.remove(d.e); dying.splice(i, 1); } }
  }
  function syncSparrows(visible) {
    const list = visible ? G.sparrows : [];
    while (sparrowObjs.length < list.length) { const b = makeBird({ body: "#b9845a", belly: "#efdcc0", wing: "#8a5a34", scale: 0.6 }); sparrowObjs.push(b); scene.add(b); }
    sparrowObjs.forEach((o, i) => { const b = list[i]; o.visible = !!b; if (!b) return; const w = W3(0, b.x, b.y), last = o.userData.last || w;
      o.position.set(w.x, b.state === "fly" ? 0.8 : 0, w.z); animBird(o, (w.x - last.x) * 60, (w.z - last.z) * 60, 1 / 60, b.state === "fly" ? 0.8 : 0); o.userData.last = w; });
  }
  function syncNest(visible, dt) {
    const s = G.s, n = PT.nestState(s), f = n.forest, seen = new Set();
    const put = (key, x, y, k, hp, maxHp, active, collapse) => {
      seen.add(key); let t = trees.get(key); if (!t) { t = makeTree(); dyn.add(t); trees.set(key, t); }
      const w = W3(4, x, y); t.position.set(w.x, 0, w.z);
      const fall = hp <= 0 ? Math.max(0, collapse / 0.8) : 1;
      t.scale.setScalar(Math.max(0.01, k * (hp <= 0 ? fall : 1))); t.rotation.z = hp <= 0 ? (1 - fall) * 1.2 : 0;
      t.userData.bar.visible = hp > 0 && (hp < maxHp || active); t.userData.fill.scale.x = Math.max(0.01, hp / maxHp); t.userData.fill.position.x = -0.43 * (1 - hp / maxHp);
    };
    if (visible) {
      for (const t of f.trees) { if (t.hp <= 0 && t.collapse <= 0) continue; put(t.id, t.x, t.y, t.age >= 180 ? 1 : 0.35 + 0.65 * (t.age / 180), t.hp, t.maxHp, f.activeTreeId === t.id, t.collapse); }
      const gs = PT.nestCultSnapshot(s).growthSeconds, pseen = new Set();
      for (const b of n.cultivation.treeBoxes) {
        const p = PT.boxSlotPos(b.slotIndex), pk = "pl" + b.slotIndex; pseen.add(pk);
        let pl = planters.get(pk); if (!pl) { pl = makePlanter(); dyn.add(pl); planters.set(pk, pl); } pl.position.copy(W3(4, p.x, p.y));
        const k = (b.trees || []).length;
        (b.trees || []).forEach((t, i) => { const x = p.x + (i % 2) * 40 - (k > 1 ? 20 : 0), y = p.y + Math.floor(i / 2) * 36 - (k > 2 ? 18 : 0);
          if (t.hp <= 0 && !(t.collapse > 0)) return; put("box" + b.slotIndex + "_" + i, x, y, 0.55 * (t.age >= gs ? 1 : 0.35 + 0.65 * (t.age / gs)), t.hp, t.maxHp, f.activeTreeId === "box" + b.slotIndex + "_" + i, t.collapse || 0); });
      }
      for (const [k, pl] of planters) if (!pseen.has(k)) { dyn.remove(pl); planters.delete(k); }
      for (const t of trees.values()) t.position.y = 0;
      for (const [k] of planters) { const pl = planters.get(k); } // planters sit on the ground
      for (const [key, t] of trees) if (key.startsWith("box")) t.position.y = 0.3;
    } else { for (const [k, pl] of planters) { dyn.remove(pl); planters.delete(k); } }
    for (const [key, t] of trees) if (!seen.has(key)) { dyn.remove(t); trees.delete(key); }
    panda.visible = visible && PT.pandaAssisting(s) && !!G.pandaPos;
    if (panda.visible) { const w = W3(4, G.pandaPos.x, G.pandaPos.y); panda.position.lerp(new T.Vector3(w.x, 0, w.z), Math.min(1, dt * 6)); panda.rotation.y = Math.sin(G.t * 8) * 0.15; }
  }

  // ------------------------------------------------------------------ floating texts (DOM overlay, projected from 3D)
  const floatLayer = document.createElement("div"); Object.assign(floatLayer.style, { position: "absolute", inset: "0", pointerEvents: "none", overflow: "hidden" }); stage.insertBefore(floatLayer, cvs.nextSibling);
  const floatEls = new Map();
  function syncFloats() {
    const live = new Set(), r = cvs.getBoundingClientRect();
    for (const f of G.floats) {
      live.add(f); let el = floatEls.get(f);
      if (!el) { el = document.createElement("div"); el.textContent = f.text; Object.assign(el.style, { position: "absolute", font: "18px 'Fredoka One', sans-serif", color: f.color || "#fff", textShadow: "0 0 3px #000, 0 2px 0 #000", transform: "translate(-50%,-50%)", whiteSpace: "nowrap" }); floatLayer.appendChild(el); floatEls.set(f, el); }
      const p = W3(f.map, f.x, f.y); p.y = 1.2; p.project(camera);
      el.style.left = ((p.x + 1) / 2) * r.width + "px"; el.style.top = ((1 - p.y) / 2) * r.height + "px"; el.style.opacity = Math.min(1, f.life / 0.4);
    }
    for (const [f, el] of floatEls) if (!live.has(f)) { el.remove(); floatEls.delete(f); }
  }

  // ------------------------------------------------------------------ which maps are shown: the current one plus every connected map you can walk into
  let shownT = 0, shownSig = ""; const shown = new Set([0]);
  function canEnter(from, dir) { const s = G.s, keep = s.currentMap; s.currentMap = from; try { return !PT.travelBlock(s, dir) ? PT.travelTarget(s, dir) : null; } catch (e) { return null; } finally { s.currentMap = keep; } }
  function refreshShown() {
    shown.clear(); const cur = G.s.currentMap; shown.add(cur);
    if (LAYOUT[cur]) { // flood along the connected row while each step is open
      const q = [cur];
      while (q.length) { const id = q.shift(); for (const dir of [-1, 1]) { const to = canEnter(id, dir); if (to != null && LAYOUT[to] && !shown.has(to)) { shown.add(to); q.push(to); } } }
    }
    for (const id of shown) ensureMap(id);
    for (const [id, e] of built) e.group.visible = shown.has(id);
    const sig = [...shown].sort().join(","); if (sig !== shownSig) { shownSig = sig; rebuildCoast(); }
  }
  function bounds() { // world-unit rectangle of the shown maps
    let x0 = Infinity, z0 = Infinity, x1 = -Infinity, z1 = -Infinity;
    for (const id of shown) { const o = origin(id), m = PT.MAPS[id]; x0 = Math.min(x0, o.ox * U); z0 = Math.min(z0, o.oy * U); x1 = Math.max(x1, (o.ox + m.w) * U); z1 = Math.max(z1, (o.oy + m.h) * U); }
    return { x0, z0, x1, z1 };
  }

  // ------------------------------------------------------------------ walking across connected edges (called by main.js step)
  let edgeT = 0;
  const R3D = window.R3D = {};
  R3D.edge = function (G, ix, iy, dt) {
    edgeT -= dt; const s = G.s, m = PT.MAPS[s.currentMap], from = s.currentMap;
    const dir = s.player.x <= 21 && ix < 0 ? -1 : s.player.x >= m.w - 21 && ix > 0 ? 1 : 0;
    if (!dir || edgeT > 0) return;
    edgeT = 0.6;
    const to = canEnter(from, dir);
    if (to == null) { G.travel(dir); return; } // shows the block reason as a toast
    const keepV = [G.vx, G.vy], pend = G.target ? W3(from, G.target.x, G.target.y) : null, y = s.player.y;
    G.travel(dir);
    if (LAYOUT[from] && LAYOUT[to] && s.currentMap === to) {
      const nm = PT.MAPS[to]; s.player.x = dir > 0 ? 22 : nm.w - 22; s.player.y = Math.max(20, Math.min(nm.h - 20, y + LAYOUT[from].oy - LAYOUT[to].oy));
      [G.vx, G.vy] = keepV; edgeT = 0.3;
      if (pend) G.target = { x: pend.x / U - LAYOUT[to].ox, y: pend.z / U - LAYOUT[to].oy };
    }
    refreshShown();
  };

  // ------------------------------------------------------------------ input: click to move / interact, wheel + pinch zoom
  const ray = new T.Raycaster(), ndc = new T.Vector2(), groundP = new T.Plane(new T.Vector3(0, 1, 0), 0), hit = new T.Vector3();
  function pickGround(cx, cy) { const r = cvs.getBoundingClientRect(); ndc.set(((cx - r.left) / r.width) * 2 - 1, -((cy - r.top) / r.height) * 2 + 1); ray.setFromCamera(ndc, camera); return ray.ray.intersectPlane(groundP, hit) ? hit.clone() : null; }
  cvs.addEventListener("mousedown", (e) => {
    const p = pickGround(e.clientX, e.clientY); if (!p) return;
    const cur = G.s.currentMap, o = origin(cur);
    G.clickWorld({ x: p.x / U - o.ox, y: p.z / U - o.oy }); // points beyond the edge walk you across it
  });
  cvs.addEventListener("wheel", (e) => { e.preventDefault(); viewTarget *= Math.exp(e.deltaY * 0.0012); }, { passive: false });
  let pinch = null;
  cvs.addEventListener("touchstart", (e) => { if (e.touches.length === 2) pinch = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY); }, { passive: true });
  cvs.addEventListener("touchmove", (e) => { if (e.touches.length === 2 && pinch) { const d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY); viewTarget *= pinch / d; pinch = d; } }, { passive: true });
  addEventListener("keydown", (e) => { if (e.key === "=" || e.key === "+") viewTarget /= 1.15; if (e.key === "-") viewTarget *= 1.15; });

  // ------------------------------------------------------------------ frame
  function resize() { const r = stage.getBoundingClientRect(); renderer.setSize(r.width, r.height, false); }
  addEventListener("resize", resize); resize();
  let lastMap = null;
  R3D.render = function (G, dt) {
    const s = G.s, cur = s.currentMap;
    if (cur !== lastMap || (shownT -= dt) <= 0) { shownT = 1; refreshShown(); lastMap = cur; }
    // player
    const pw = W3(cur, s.player.x, s.player.y);
    player.position.set(pw.x, built.get(cur)?.flat ? 0.14 : 0.02, pw.z);
    animBird(player, G.vx * U, G.vy * U, dt, G.nestAcc > 0 && cur === 4 ? Math.sin(G.t * 30) * 0.2 : 0);
    const rr = (cur === 0 || cur === PT.DESERT_MAP || cur === PT.ECHO_FIELD_MAP) ? PT.pickupProfile(s).collectRadius * U : 0;
    ring.visible = rr > 0; if (rr) { ring.scale.setScalar(rr); ring.position.set(pw.x, 0.03, pw.z); }
    // per map content
    syncEggs(0, G.field.list(0), shown.has(0));
    syncSparrows(shown.has(0));
    syncNest(shown.has(4), dt);
    updateDying(dt);
    for (const e of built.values()) if (e.flat && e.group.visible && e.id === cur && (e.flat.t -= dt) <= 0) { e.flat.t = 0.1; G.render2D(e.flat.c); e.flat.tex.needsUpdate = true; }
    // camera: fixed angle, follows the bird, zoom clamped to the shown world plus a band of sea
    const r = cvs.getBoundingClientRect(), aspect = r.width / Math.max(1, r.height), b = bounds(), SEA = 4;
    const sinP = Math.sin(PITCH), maxH = Math.max(8, Math.min((b.z1 - b.z0 + 2 * SEA) * sinP, (b.x1 - b.x0 + 2 * SEA) / aspect));
    viewTarget = Math.max(5, Math.min(maxH, viewTarget)); viewH += (viewTarget - viewH) * Math.min(1, dt * 10);
    const halfW = (viewH / 2) * aspect, halfD = viewH / 2 / sinP;
    const clampC = (v, lo, hi, half) => (hi - lo + 2 * SEA <= 2 * half ? (lo + hi) / 2 : Math.max(lo - SEA + half, Math.min(hi + SEA - half, v)));
    const tx = clampC(pw.x, b.x0, b.x1, halfW), tz = clampC(pw.z, b.z0, b.z1, halfD);
    if (!camInit) { camPos.set(tx, 0, tz); camInit = true; } else camPos.lerp(new T.Vector3(tx, 0, tz), Math.min(1, dt * 6));
    camera.left = -halfW; camera.right = halfW; camera.top = viewH / 2; camera.bottom = -viewH / 2; camera.updateProjectionMatrix();
    camera.position.set(camPos.x, Math.sin(PITCH) * 60, camPos.z + Math.cos(PITCH) * 60); camera.lookAt(camPos);
    // sun + shadow box follow the view
    sun.position.set(camPos.x - 14, 30, camPos.z + 10); sun.target.position.copy(camPos);
    const sc = sun.shadow.camera, ext = Math.max(halfW, halfD) + 4; sc.left = -ext; sc.right = ext; sc.top = ext; sc.bottom = -ext; sc.near = 1; sc.far = 90; sc.updateProjectionMatrix();
    // sea follows the view, gentle swell
    sea.position.x = bed.position.x = camPos.x; sea.position.z = bed.position.z = camPos.z; sea.scale.set(halfW * 4 + 40, halfD * 4 + 40, 1); bed.scale.copy(sea.scale);
    sea.position.y = -0.45 + Math.sin(G.t * 0.8) * 0.03;
    renderer.render(scene, camera);
    syncFloats();
  };
})();
