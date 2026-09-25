// Parallax depth 6, `fg` (f = 1.3): the foliage you look through (REALM.md sections 4, 7, 8; realm.json layers[fg]).
// Out-of-focus framing only. A leafy canopy hangs from the top edge, with a clearing above the crown, and vines hang
// from it. Ferns, broad leaves and grass rise from the bottom. On the rift side there are thorn brambles, dark crystals
// and torn strands. A few glowing buds are the only bright bits. Everything lives at the layer edges: every hard
// keep-clear zone is fully empty, every soft zone stays below alpha 0.25, and the middle 60% of the height holds only
// thin, faint tips. The six swaying `vine_fg` sprites hang from the same canopy, so the painted vines leave their
// columns free.
//
// Pipeline: paint in layer-local px at PS = 2 x res.HIGH canvas px per local px, in three depth planes (back, mid,
// front; the front plane gets extra defocus). Then the section 4 atmosphere pass runs in float, premultiplied: shade
// toward the haze colour, desaturate, flatten contrast, clamp luma, and apply a 10 local px gaussian depth-of-field
// blur. Then the keep-clear guarantee, a 2x downsample to size x res.HIGH = 1572x1092, and an alpha bleed. The PNG
// comes from a WebGL canvas (premultipliedAlpha: false), so the bled colour of transparent pixels survives export. A
// 2D canvas would write it black.
(function () {
  'use strict';
  // ---- contract snapshot (realm.json layers[fg], sprites[vine_fg]). window.REALM wins when a pipeline injects it.
  const SNAP = {
    size: [5240, 3640], res: 0.3, splitX: 3309, fade: 150,
    atm: { hazeColor: [8, 4, 18], hazeRift: [22, 4, 14], haze: 0.55, hazeBottom: 0, saturation: 0.6, contrast: 0.6, blur: 10, maxLuma: 0.25, emissiveMax: 0.6 },
    hard: [['m', 2074, 2657.2, 168, 191], ['mm', 1658, 2735.2, 168, 191], ['em', 2490, 2735.2, 168, 191], ['p', 2074, 2241.2, 168, 191],
      ['pe', 1476, 1877.2, 168, 191], ['sp', 1853, 1812.2, 168, 191], ['pb', 2295, 1812.2, 168, 191], ['pp', 2672, 1877.2, 168, 191],
      ['se', 1619, 1461.2, 168, 191], ['hp', 2074, 1396.2, 168, 191], ['ep', 2529, 1461.2, 168, 191], ['hb', 1658, 1045.2, 168, 191],
      ['ap', 2074, 980.2, 168, 191], ['mp', 2490, 1045.2, 168, 191], ['t', 2074, 603.2, 168, 191], ['pm', 4219, 2215.2, 168, 191],
      ['pep', 3751, 1721.2, 168, 191], ['cr', 4687, 1747.2, 168, 191], ['cm', 4921, 1396.2, 168, 191], ['ex', 4219, 1201.2, 168, 191],
      ['ach', 800, 967.2, 168, 191]],
    softR: [255, 240],
    landmarks: { tree: [2074, 1651], crown: [2074, 585], island: [2074, 2756], rift: [4219, 2080], shrine: [800, 988], outcrop: [4804, 1872] },
    vines: [[3644, 236.3, 1108.8], [2879.2, 226.5, 965.9], [1103.4, 190, 856.4], [4545.7, 269, 1200.1], [56.5, 175.2, 747.6], [5057.3, 283.8, 1072.5]],
  };
  const RJ = typeof window !== 'undefined' && window.REALM && window.REALM.layers ? window.REALM : null;
  const CFG = (() => {
    const L = RJ && RJ.layers.find(l => l.id === 'fg');
    if (!L) return { ...SNAP, soft: SNAP.hard.map(z => [z[0], z[1], z[2], SNAP.softR[0], SNAP.softR[1]]) };
    const V = RJ.sprites && RJ.sprites.find(s => s.name === 'vine_fg');
    return { size: L.size, res: L.res.HIGH, splitX: L.biomeLocal.splitX, fade: L.biomeLocal.fadeHalfWidth, atm: L.atmosphere,
      hard: L.keepClear.hard, soft: L.keepClear.soft, landmarks: L.landmarks, vines: V ? V.instances.map(o => [o.x, o.s, o.h]) : SNAP.vines };
  })();

  const [LW, LH] = CFG.size, PS = 2 * CFG.res;                  // local px -> paint canvas px
  const CW = Math.round(LW * PS), CH = Math.round(LH * PS);
  const OW = Math.round(LW * CFG.res), OH = Math.round(LH * CFG.res);
  const BAND = [0.2 * LH, 0.8 * LH];                             // the middle 60%: thin, faint tips only
  const TAU = Math.PI * 2;
  const LDIR = (() => { const d = Math.hypot(-0.45, -0.62); return [-0.45 / d, -0.62 / d]; })();   // toward the key light
  const KEY = [255, 214, 150], LILAC = [205, 182, 255], CRIMSON = [255, 46, 99], EMBER = [255, 90, 31], MAGENTA = [232, 70, 190];
  const CORRUPT = [57, 255, 20], PINK = [255, 140, 220], CYAN = [120, 220, 255], GOLD = [255, 214, 150];
  // silhouette colours per depth plane before the atmosphere pass (it shades them toward near-black violet)
  const PLANE = { back: [40, 24, 74], mid: [22, 12, 42], front: [13, 7, 26] };
  const RIFT = CFG.landmarks.rift, OUTCROP = CFG.landmarks.outcrop;
  const riftW = x => smooth(CFG.splitX - CFG.fade, CFG.splitX + CFG.fade, x);
  const mk = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
  const c2 = (c, read) => c.getContext('2d', read ? { willReadFrequently: true } : undefined);
  const luma = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
  const rot = (v, a) => [v[0] * Math.cos(a) - v[1] * Math.sin(a), v[0] * Math.sin(a) + v[1] * Math.cos(a)];

  // ---------------------------------------------------------------- keep-clear
  const inside = (x, y, z, grow = 0) => { const dx = (x - z[1]) / (z[3] + grow), dy = (y - z[2]) / (z[4] + grow); return dx * dx + dy * dy < 1; };
  /** true when none of the points comes within `m` local px of a soft zone (the blur spreads ~2.5 sigma). */
  const clearOf = (pts, m = 26) => !pts.some(([x, y]) => CFG.soft.some(z => inside(x, y, z, m)));
  /** Allowed alpha at a local point: 0 in (and just around) the hard zones, <= 0.22 in the soft zones, 1 beyond. */
  function allowance(x, y) {
    let a = 1;
    for (let i = 0; i < CFG.hard.length; i++) {
      const h = CFG.hard[i], s = CFG.soft[i];
      const dh = Math.hypot((x - h[1]) / h[3], (y - h[2]) / h[4]), ds = Math.hypot((x - s[1]) / s[3], (y - s[2]) / s[4]);
      let v;
      if (dh <= 1.03) v = 0;
      else if (ds < 1) v = 0.22 * smooth(1.03, 1.2, dh);
      else v = 0.22 + 0.78 * smooth(1, 1.3, ds);
      if (v < a) a = v;
    }
    return a;
  }

  // ---------------------------------------------------------------- lighting
  /** Rim lights for an element at local (x, y): the key light from the upper left (lilac, gold toward the sun
   *  corner), the rift's crimson from its own direction, and a faint corrupted green near the outcrop. */
  function lightsAt(x, y) {
    const out = [];
    const sunK = clamp(1 - Math.hypot(x / LW, y / LH * 0.8) * 0.9);
    out.push({ dir: LDIR, col: mix(LILAC, KEY, 0.25 + 0.6 * sunK), a: 0.72 * (1 - 0.55 * riftW(x)) });
    const rw = riftW(x);
    if (rw > 0.02) {
      const dx = RIFT[0] - x, dy = RIFT[1] - y, d = Math.hypot(dx, dy) || 1;
      out.push({ dir: [dx / d, dy / d], col: CRIMSON, a: 0.85 * rw * clamp(1.25 - d / 2600, 0.35, 1) });
    }
    const dc = Math.hypot(OUTCROP[0] - x, OUTCROP[1] - y);
    if (dc < 1400) out.push({ dir: [(OUTCROP[0] - x) / dc, (OUTCROP[1] - y) / dc], col: CORRUPT, a: 0.4 * (1 - dc / 1400) });
    return out;
  }
  /** Shade a closed shape drawn by path() in a frame rotated by `ang` around (0, 0) of that frame: a lit sheen on
   *  the side facing each light and a crisp rim along the lit edge. (cx, cy, R) bound the shape in its frame. */
  function light(c, path, ang, cx, cy, R, lights, rimW) {
    c.save(); path(); c.clip();
    for (const Lt of lights) {
      if (Lt.a <= 0.01) continue;
      const d = rot(Lt.dir, -ang);
      const sh = c.createLinearGradient(cx + d[0] * R, cy + d[1] * R, cx - d[0] * R * 0.2, cy - d[1] * R * 0.2);
      sh.addColorStop(0, rgba(Lt.col, Lt.a * 0.22)); sh.addColorStop(1, rgba(Lt.col, 0));
      c.fillStyle = sh; path(); c.fill();
      const g = c.createLinearGradient(cx + d[0] * R, cy + d[1] * R, cx + d[0] * R * 0.1, cy + d[1] * R * 0.1);
      g.addColorStop(0, rgba(Lt.col, Lt.a)); g.addColorStop(1, rgba(Lt.col, 0));
      c.strokeStyle = g; c.lineWidth = 2 * rimW; c.lineJoin = 'round'; path(); c.stroke();
    }
    c.restore();
  }

  // ---------------------------------------------------------------- shapes (leaf frame: base at 0, pointing +x)
  function leafPath(c, len, wid, bend, asym) {
    const wu = wid * (1 + asym), wl = wid * (1 - asym), ty = bend * len;
    c.beginPath(); c.moveTo(0, 0);
    c.bezierCurveTo(len * 0.16, -wu * 1.25, len * 0.6, -wu * 1.2 + ty * 0.45, len, ty);
    c.bezierCurveTo(len * 0.6, wl * 1.2 + ty * 0.45, len * 0.16, wl * 1.25, 0, 0);
    c.closePath();
  }
  function heartPath(c, len, wid, bend) {
    const ty = bend * len;
    c.beginPath(); c.moveTo(len * 0.04, 0);
    c.bezierCurveTo(-len * 0.2, -wid * 1.05, len * 0.3, -wid * 1.45 + ty * 0.3, len, ty);
    c.bezierCurveTo(len * 0.3, wid * 1.45 + ty * 0.3, -len * 0.2, wid * 1.05, len * 0.04, 0);
    c.closePath();
  }
  /** Leaf-shaped points in local px (for keep-clear tests). */
  const leafPts = (x, y, ang, len, wid) => [[0, 0], [len * 0.5, -wid], [len * 0.5, wid], [len, 0], [len * 0.25, 0], [len * 0.75, 0]]
    .map(p => { const q = rot(p, ang); return [x + q[0], y + q[1]]; });

  /** One leaf. o: { x, y, ang, len, wid, bend, asym, col, heart, vein } */
  function leafAt(c, o) {
    c.save(); c.translate(o.x, o.y); c.rotate(o.ang); if (o.alpha != null) c.globalAlpha = o.alpha;
    const path = () => (o.heart ? heartPath : leafPath)(c, o.len, o.wid, o.bend || 0, o.asym || 0);
    c.fillStyle = rgba(o.col); path(); c.fill();
    light(c, path, o.ang, o.len * 0.5, 0, o.len * 0.55, o.lights || lightsAt(o.x, o.y), Math.max(3, o.wid * 0.12));
    if (o.vein) { // midrib: a slightly darker line, only survives the blur on big leaves
      c.strokeStyle = rgba(mix(o.col, [0, 0, 0], 0.45), 0.7); c.lineWidth = Math.max(2.5, o.wid * 0.07); c.lineCap = 'round';
      c.beginPath(); c.moveTo(o.len * 0.03, 0); c.quadraticCurveTo(o.len * 0.55, (o.bend || 0) * o.len * 0.35, o.len * 0.93, (o.bend || 0) * o.len * 0.9); c.stroke();
    }
    c.restore();
  }
  /** Tapered stroke along a sampled spline (lib.js spline), widths from S[i].w. */
  function stem(c, S, col, lights) {
    const sh = outline(S);
    c.fillStyle = rgba(col); poly(c, sh); c.fill();
    if (lights) {
      const m = at(S, 0.5), R = Math.max(40, S.len * 0.5);
      light(c, () => poly(c, sh), 0, m.x, m.y, R, lights.map(L => ({ ...L, a: L.a * 0.7 })), 3);
    }
  }
  /** Emissive bud: silhouette cup on the paint plane + light on the emissive plane. */
  function bud(c, e, x, y, r, col, rr, plane) {
    c.fillStyle = rgba(plane);
    for (let k = 0; k < 4; k++) { const a = -Math.PI / 2 + (k - 1.5) * 0.7 + (rr() - 0.5) * 0.3; c.save(); c.translate(x, y); c.rotate(a); leafPath(c, r * 2.1, r * 0.55, 0, 0); c.fill(); c.restore(); }
    blob(e, x, y, r * 5.5, col, 0.28);
    blob(e, x, y, r * 2.4, col, 0.55);
    blob(e, x, y, r * 1.05, mix(col, [255, 255, 255], 0.55), 1, 0.4);
  }

  // ---------------------------------------------------------------- species
  const glows = [];                                  // emissive buds (drawn after the planes so they sit on top)
  const budCol = (x, rr) => {
    const rw = riftW(x);
    if (rw > 0.5) return [CRIMSON, EMBER, MAGENTA, CRIMSON][Math.floor(rr() * 4)];
    return [PINK, PINK, CYAN, GOLD][Math.floor(rr() * 4)];
  };
  const idx = (S, s) => { const i = S.findIndex(p => p.s >= s); return i < 0 ? S.length - 1 : i; };
  /** The clear prefix of a sampled spline (it stops before the first point that nears a soft zone). */
  function clearPrefix(S, m = 30) {
    const cut = S.findIndex(p => !clearOf([[p.x, p.y]], m));
    if (cut === 0 || cut === 1) return null;
    const T = cut === -1 ? S : S.slice(0, cut);
    T.len = T[T.length - 1].s;
    return T;
  }

  /** Leaf spray: a branch hanging from above with big leaves along it. The canopy's building block. */
  function spray(P, pts, seed, plane, o = {}) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    const T = clearPrefix(spline(pts, 16));
    if (!T) return;
    stem(c, T, col, lightsAt(T[T.length >> 1].x, T[T.length >> 1].y));
    const Lmax = o.leaf || 300, maxY = o.maxY || BAND[0] + 60, leaves = [];
    let side = rr() < 0.5 ? -1 : 1;
    for (let s = 30 + rr() * 40; s < T.len; s += Lmax * (0.13 + rr() * 0.1)) {
      const p = T[idx(T, s)], t = s / T.len;
      side = -side;
      const len = Lmax * lerp(1, 0.6, t) * (0.72 + rr() * 0.42);
      const tang = Math.atan2(p.ty, p.tx);
      // leaves fan out from the stem and droop: halfway between "sideways off the stem" and "straight down"
      const ang = lerp(tang + side * (0.8 + rr() * 0.6), Math.PI / 2 + side * (0.25 + rr() * 0.45), o.droop == null ? 0.6 : o.droop);
      leaves.push({ x: p.x, y: p.y, ang, len, wid: len * (o.wr || 0.25) * (0.85 + rr() * 0.3), bend: side * (0.06 + rr() * 0.14),
        asym: (rr() - 0.5) * 0.3, heart: rr() < (o.heart || 0), t });
    }
    const e = T[T.length - 1];
    leaves.push({ x: e.x, y: e.y, ang: Math.atan2(e.ty, e.tx) + (rr() - 0.5) * 0.3, len: Lmax * 0.62, wid: Lmax * 0.62 * (o.wr || 0.25), bend: 0.08, asym: 0, t: 1 });
    for (const L of leaves) {
      if (L.y + Math.sin(L.ang) * L.len > maxY) continue;
      if (!clearOf(leafPts(L.x, L.y, L.ang, L.len, L.wid))) continue;
      leafAt(c, { ...L, col: mix(col, [0, 0, 0], rr() * 0.3), vein: L.len > 200 });
      if (o.buds && rr() < o.buds) glows.push({ x: L.x + Math.cos(L.ang) * 14, y: L.y + Math.sin(L.ang) * 14, r: 7 + rr() * 4, col: budCol(L.x, rr), plane });
    }
  }

  /** A vine hanging from the canopy: a tapering stem, drooping leaves, a curl or a glowing bud at the tip. */
  function vine(P, x0, y0, len, seed, plane, { budAt = true, thorny = false, leaf = 130 } = {}) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane], N = makeNoise(seed);
    const pts = [];
    for (let k = 0; k <= 10; k++) {
      const t = k / 10;
      pts.push([x0 + 46 * N(t * 2.2, 1.7) * t + 18 * Math.sin(t * 5 + seed), y0 + len * t, lerp(thorny ? 22 : 16, 4, Math.pow(t, 0.8))]);
    }
    const T = clearPrefix(spline(pts, 12), 30);
    if (!T) { console.log('fg: vine at', x0, 'skipped (keep-clear)'); return; }
    stem(c, T, col, lightsAt(x0, y0 + len * 0.4));
    let side = rr() < 0.5 ? -1 : 1;
    for (let s = 50; s < T.len - 20; s += (thorny ? 30 : 46) * (0.75 + rr() * 0.5)) {
      const p = T[idx(T, s)], t = s / T.len;
      side = -side;
      if (thorny) {
        const a = Math.atan2(p.ty, p.tx) + side * (1.0 + rr() * 0.4), tl = lerp(40, 16, t);
        const q = rot([1, 0], a), n = [-q[1], q[0]];
        c.fillStyle = rgba(col); c.beginPath();
        c.moveTo(p.x + n[0] * 6, p.y + n[1] * 6); c.lineTo(p.x + q[0] * tl - p.tx * tl * 0.3, p.y + q[1] * tl - p.ty * tl * 0.3); c.lineTo(p.x - n[0] * 6, p.y - n[1] * 6); c.fill();
        if (rr() < 0.3) {   // a narrow, jagged leaf
          const ang = Math.PI / 2 + side * (0.6 + rr() * 0.5), l = lerp(150, 70, t);
          if (p.y + Math.sin(ang) * l < BAND[0] + 200 && clearOf(leafPts(p.x, p.y, ang, l, l * 0.13)))
            leafAt(c, { x: p.x, y: p.y, ang, len: l, wid: l * 0.13, bend: 0.12 * side, col });
        }
        continue;
      }
      const deep = smooth(BAND[0] - 60, BAND[0] + 320, p.y);          // into the middle band: smaller and fainter tips
      const l = lerp(leaf, leaf * 0.45, t) * (0.75 + rr() * 0.5) * (1 - 0.45 * deep), ang = Math.PI / 2 + side * (0.5 + rr() * 0.6);
      if (!clearOf(leafPts(p.x, p.y, ang, l, l * 0.3))) continue;
      leafAt(c, { x: p.x, y: p.y, ang, len: l, wid: l * 0.27, bend: -0.12 * side, asym: (rr() - 0.5) * 0.3, col, alpha: 1 - 0.55 * deep });
    }
    const e = T[T.length - 1];
    if (budAt) glows.push({ x: e.x, y: e.y + 10, r: 10 + rr() * 5, col: budCol(e.x, rr), plane });
    else { // a curling tendril
      c.strokeStyle = rgba(col); c.lineWidth = 5; c.lineCap = 'round'; c.beginPath();
      for (let k = 0; k <= 30; k++) { const a = k / 30 * TAU * 1.2, r = 30 * (1 - k / 34); const px = e.x + Math.cos(a + 1.6) * r, py = e.y + 30 + Math.sin(a + 1.6) * r; k ? c.lineTo(px, py) : c.moveTo(px, py); }
      c.stroke();
    }
  }

  /** A fern frond rising from (x0, y0): an arching rachis with pinnae, longest in the lower third. Stops below maxTop. */
  function frond(P, x0, y0, ang, len, arch, seed, plane, { pinna = 1, maxTop = -1e9, wr = 0.23 } = {}) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    let px = x0, py = y0; const P2 = [];
    for (let k = 0; k <= 10; k++) {
      if (k) { const t = (k - 1) / 10, a = ang + arch * t * t; px += Math.cos(a) * len / 10; py += Math.sin(a) * len / 10; }
      P2.push([px, py, lerp(26, 4, k / 10)]);
    }
    const S = spline(P2, 10);
    const cut = S.findIndex(p => p.y < maxTop || !clearOf([[p.x, p.y]], 30));
    const T = cut === -1 ? S : cut > 3 ? S.slice(0, cut) : null;
    if (!T) return null;
    T.len = T[T.length - 1].s;
    stem(c, T, col, lightsAt(x0, y0 - len * 0.4));
    const pl = Math.min(len * 0.2, 200) * pinna;
    for (let i = 4; i < T.length; i += 3) {
      const p = T[i], t = p.s / S.len, prof = Math.pow(Math.sin(Math.PI * (0.1 + 0.9 * t)), 0.6) * (1 - 0.5 * t);
      for (const sd of [-1, 1]) {
        const l = pl * prof * (0.85 + rr() * 0.3); if (l < 24) continue;
        const a = Math.atan2(p.ty, p.tx) + sd * (0.85 + rr() * 0.25) - sd * 0.3 * t;
        const tipY = p.y + Math.sin(a) * l;
        if (tipY < maxTop || !clearOf(leafPts(p.x, p.y, a, l, l * wr))) continue;
        leafAt(c, { x: p.x, y: p.y, ang: a, len: l, wid: l * wr, bend: 0.16 * sd, col: mix(col, [0, 0, 0], rr() * 0.25) });
      }
    }
    return T[T.length - 1];
  }

  /** A broad (elephant-ear) leaf on a petiole rising from the bottom. */
  function broadLeaf(P, x0, y0, tx, ty, len, seed, plane, droop = 0.5) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    const S = spline([[x0, y0, 30], [lerp(x0, tx, 0.45) + (rr() - 0.5) * 80, lerp(y0, ty, 0.55), 22], [tx, ty, 14]], 14);
    const ang = Math.atan2(ty - y0, tx - x0) + droop * Math.sign(tx - x0 || 1);
    if (!clearOf(leafPts(tx, ty, ang, len, len * 0.5)) || !S.every(p => clearOf([[p.x, p.y]]))) { console.log('fg: broad leaf', seed, 'skipped'); return; }
    stem(c, S, col, lightsAt(tx, ty));
    leafAt(c, { x: tx, y: ty, ang, len, wid: len * 0.4, bend: (rr() - 0.5) * 0.25, heart: true, col, vein: true });
  }

  /** A clump of grass blades fanning out from one root. */
  function grass(P, x0, y0, n, hTop, seed, plane) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    for (let k = 0; k < n; k++) {
      const h = (y0 - hTop) * (0.45 + 0.55 * Math.pow(rr(), 0.7)), lean = (rr() - 0.5) * h * 0.7, w = 9 + rr() * 11;
      const bx = x0 + (rr() - 0.5) * 60, tx = bx + lean, ty = y0 - h, mx = bx + lean * 0.2, my = y0 - h * 0.62;
      const curl = lean * 0.25;
      if (!clearOf([[tx + curl, ty], [mx, my]], 24)) continue;
      c.fillStyle = rgba(mix(col, [0, 0, 0], rr() * 0.3)); c.beginPath();
      c.moveTo(bx - w, y0); c.quadraticCurveTo(mx - w * 0.5, my, tx + curl, ty); c.quadraticCurveTo(mx + w * 0.5, my, bx + w, y0); c.closePath(); c.fill();
      const Lt = lightsAt(tx, ty)[0];
      c.strokeStyle = rgba(Lt.col, Lt.a * 0.55); c.lineWidth = 3.5; c.lineCap = 'round';
      c.beginPath(); c.moveTo(bx - w, y0); c.quadraticCurveTo(mx - w * 0.5, my, tx + curl, ty); c.stroke();
    }
  }
  /** A low bush: leaves fanning up from a root, tips below hTop. */
  function bush(P, x0, y0, n, len, hTop, seed, plane) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    const L = [];
    for (let k = 0; k < n; k++) {
      const a = -Math.PI / 2 + (rr() - 0.5) * 2.3, l = len * (0.6 + rr() * 0.5);
      const bx = x0 + (rr() - 0.5) * len * 0.5, by = y0 - rr() * len * 0.25;
      L.push({ x: bx, y: by, ang: a, len: l, wid: l * 0.3, bend: (rr() - 0.5) * 0.3, asym: (rr() - 0.5) * 0.3, heart: rr() < 0.25 });
    }
    L.sort((p, q) => Math.abs(q.ang + Math.PI / 2) - Math.abs(p.ang + Math.PI / 2));
    for (const o of L) {
      if (o.y + Math.sin(o.ang) * o.len < hTop) continue;
      if (!clearOf(leafPts(o.x, o.y, o.ang, o.len, o.wid))) continue;
      leafAt(c, { ...o, col: mix(col, [0, 0, 0], rr() * 0.3) });
    }
  }

  /** Thorn branch (rift side): a limb along points with thorns on both flanks. Returns the clear part. */
  function thornLimb(P, pts, seed, plane, { thorn = 1 } = {}) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane];
    const S = clearPrefix(spline(pts, 14), 36);
    if (!S) { console.log('fg: thorn limb', seed, 'skipped'); return null; }
    stem(c, S, col, lightsAt(S[S.length >> 1].x, S[S.length >> 1].y));
    for (let s = 20; s < S.len - 20; s += (24 + rr() * 34) / thorn) {
      const p = S[idx(S, s)], sd = rr() < 0.5 ? -1 : 1, t = s / S.len;
      const a = Math.atan2(p.ty, p.tx) + sd * (0.95 + rr() * 0.4), tl = (0.45 + rr() * 0.6) * p.w + 10;
      const q = rot([1, 0], a), base = [p.x + p.nx * p.w * 0.42 * sd, p.y + p.ny * p.w * 0.42 * sd], n = [-q[1], q[0]], bw = Math.max(4, p.w * 0.2);
      const tip = [base[0] + q[0] * tl + p.tx * tl * 0.35, base[1] + q[1] * tl + p.ty * tl * 0.35];
      if (!clearOf([tip], 30)) continue;
      c.fillStyle = rgba(col); c.beginPath();
      c.moveTo(base[0] + n[0] * bw, base[1] + n[1] * bw); c.quadraticCurveTo(base[0] + q[0] * tl * 0.4, base[1] + q[1] * tl * 0.4, tip[0], tip[1]); c.lineTo(base[0] - n[0] * bw, base[1] - n[1] * bw); c.fill();
      if (t > 0.25 && rr() < 0.07) glows.push({ x: tip[0], y: tip[1], r: 6 + rr() * 4, col: rr() < 0.6 ? CRIMSON : EMBER, plane, tiny: true });
    }
    return S;
  }
  /** Dark crystal prism with a lit facet; its ridge line and tip glow go to the emissive plane. */
  function crystal(P, E, x, y, ang, len, wid, seed, plane, glowCol) {
    const c = P[plane], col = PLANE[plane];
    const q = rot([1, 0], ang), n = [-q[1], q[0]], tip = [x + q[0] * len, y + q[1] * len];
    const sh = wid * 0.5, pts = [[x + n[0] * sh, y + n[1] * sh], [x + n[0] * sh + q[0] * len * 0.76, y + n[1] * sh + q[1] * len * 0.76], tip,
      [x - n[0] * sh + q[0] * len * 0.76, y - n[1] * sh + q[1] * len * 0.76], [x - n[0] * sh, y - n[1] * sh]];
    if (!clearOf(pts)) return false;
    c.fillStyle = rgba(col); poly(c, pts); c.fill();
    const Lt = lightsAt(x, y), lit = Lt[Lt.length > 1 ? 1 : 0];
    const d = lit.dir[0] * n[0] + lit.dir[1] * n[1] > 0 ? 1 : -1;
    const half = [[x, y], [x + q[0] * len * 0.76, y + q[1] * len * 0.76], tip, pts[d > 0 ? 1 : 3], pts[d > 0 ? 0 : 4]];
    c.fillStyle = rgba(lit.col, lit.a * 0.4); poly(c, half); c.fill();
    c.strokeStyle = rgba(lit.col, lit.a * 0.9); c.lineWidth = 4; c.lineJoin = 'round';
    c.beginPath(); c.moveTo(...pts[d > 0 ? 0 : 4]); c.lineTo(...pts[d > 0 ? 1 : 3]); c.lineTo(...tip); c.stroke();
    E.strokeStyle = rgba(glowCol, 0.85); E.lineWidth = Math.max(5, wid * 0.1); E.lineCap = 'round';
    E.beginPath(); E.moveTo(x + q[0] * len * 0.15, y + q[1] * len * 0.15); E.lineTo(tip[0] - q[0] * len * 0.05, tip[1] - q[1] * len * 0.05); E.stroke();
    blob(E, tip[0], tip[1], wid * 1.1, glowCol, 0.45);
    blob(E, lerp(x, tip[0], 0.5), lerp(y, tip[1], 0.5), len * 0.5, glowCol, 0.1);
    return true;
  }

  /** A torn strand hanging from a rift limb: a thin wavering thread with ragged tatters. */
  function strand(P, x0, y0, len, seed, plane) {
    const rr = rng(seed), c = P[plane], col = PLANE[plane], N = makeNoise(seed);
    const pts = [];
    for (let k = 0; k <= 8; k++) { const t = k / 8; pts.push([x0 + 30 * N(t * 2.5, 3) * t, y0 + len * t, lerp(7, 2.5, t)]); }
    const T = clearPrefix(spline(pts, 10), 30);
    if (!T) return;
    stem(c, T, col, null);
    for (let s = 30; s < T.len - 20; s += 38 + rr() * 50) {
      const p = T[idx(T, s)], sd = rr() < 0.5 ? -1 : 1, l = 14 + rr() * 22;
      c.fillStyle = rgba(col); c.beginPath(); c.moveTo(p.x, p.y - 4); c.lineTo(p.x + sd * l * 0.6, p.y + l); c.lineTo(p.x, p.y + 6); c.fill();
    }
  }

  // ---------------------------------------------------------------- composition
  function paint() {
    const P = {}, E0 = mk(CW, CH), E = c2(E0);
    for (const k of ['back', 'mid', 'front']) { P[k + 'C'] = mk(CW, CH); P[k] = c2(P[k + 'C']); P[k].setTransform(PS, 0, 0, PS, 0, 0); }
    E.setTransform(PS, 0, 0, PS, 0, 0);
    const R = rng(1300), N = makeNoise(1301);
    const vineCols = CFG.vines.map(v => v[0]);

    // --- top: a dark band above the visible edge (y < ~318 only shows in rubber-band views), then the canopy
    for (const pl of ['back', 'mid']) {
      const c = P[pl]; c.fillStyle = rgba(PLANE[pl]); c.beginPath(); c.moveTo(-10, -10);
      for (let x = -10; x <= LW + 10; x += 20) {
        let y = (pl === 'back' ? 150 : 120) + 40 * N(x / 260, pl === 'back' ? 1 : 2) + 22 * N(x / 70, 5);
        y = Math.min(y, 90 + Math.pow(Math.abs(x - 2074) / 420, 2) * 90 + 25 * N(x / 90, 6));
        c.lineTo(x, y);
      }
      c.lineTo(LW + 10, -10); c.closePath(); c.fill();
    }
    // realm canopy: sprays hanging from above ([points], leaf size). The clearing above the crown comes from the zones.
    const back = [
      [[[120, -60, 40], [200, 200, 30], [300, 470, 16]], 240], [[[640, -60, 36], [700, 180, 26], [760, 420, 12]], 220],
      [[[1160, -60, 36], [1200, 190, 24], [1230, 450, 12]], 220], [[[1560, -60, 32], [1590, 150, 22], [1640, 380, 10]], 200],
      [[[2560, -60, 32], [2560, 170, 22], [2540, 420, 10]], 210], [[[2980, -60, 36], [3000, 200, 24], [3040, 480, 12]], 230],
      [[[3300, -60, 36], [3330, 190, 24], [3380, 430, 12]], 210],
    ];
    back.forEach(([pts, leaf], i) => spray(P, pts, 40 + i, 'back', { leaf, maxY: 700 }));
    const mid = [
      [[[-160, -80, 64], [-10, 220, 44], [140, 520, 26], [230, 760, 12]], 330, 0.05],
      [[[360, -80, 50], [430, 170, 36], [470, 420, 20], [480, 600, 10]], 290, 0.1],
      [[[880, -80, 50], [930, 190, 36], [990, 430, 20], [1010, 560, 10]], 280, 0.05],
      [[[1320, -80, 46], [1370, 200, 32], [1440, 440, 16], [1500, 560, 8]], 270, 0.1],
      [[[1760, -80, 40], [1760, 160, 28], [1740, 330, 12]], 230, 0],
      [[[2400, -80, 40], [2390, 170, 28], [2400, 360, 12]], 230, 0],
      [[[2730, -80, 50], [2700, 200, 34], [2650, 450, 18], [2610, 620, 8]], 290, 0.1],
      [[[3180, -80, 52], [3120, 220, 36], [3060, 500, 18], [3040, 700, 8]], 300, 0.05],
    ];
    mid.forEach(([pts, leaf, buds], i) => spray(P, pts, 60 + i, 'mid', { leaf, buds, heart: 0.12 }));
    // nearest: two huge corner sprays, extra defocus
    spray(P, [[-220, 40, 90], [-40, 300, 60], [170, 640, 30], [300, 860, 12]], 90, 'front', { leaf: 440, heart: 0.2, maxY: 900 });
    spray(P, [[2900, -100, 70], [2870, 180, 50], [2820, 470, 24], [2780, 640, 10]], 91, 'front', { leaf: 360, maxY: 760 });

    // rift canopy: thorn limbs arching down into view (y 330-730), dark crystals and torn strands hanging from them
    const limbs = [
      [[[3620, -60, 50], [3700, 200, 38], [3820, 420, 22], [3900, 560, 8]], 'back'],
      [[[4520, -60, 50], [4560, 220, 36], [4520, 440, 20], [4480, 600, 8]], 'back'],
      [[[3230, -80, 72], [3380, 200, 58], [3600, 380, 42], [3860, 470, 28], [4080, 520, 14], [4200, 560, 6]], 'mid'],
      [[[4050, -80, 70], [4180, 180, 56], [4400, 360, 40], [4640, 450, 26], [4830, 500, 12], [4950, 520, 6]], 'mid'],
      [[[5340, 180, 96], [5100, 380, 72], [4880, 560, 48], [4700, 690, 26], [4580, 760, 8]], 'front'],
    ];
    limbs.forEach(([pts, pl], i) => {
      const S = thornLimb(P, pts, 200 + i, pl, { thorn: 1.2 });
      if (!S) return;
      const rr = rng(210 + i);
      for (let k = 0; k < (pl === 'back' ? 1 : 3); k++) {
        const p = at(S, 0.3 + rr() * 0.55);
        crystal(P, E, p.x, p.y + p.w * 0.3, Math.PI / 2 + (rr() - 0.5) * 0.45, 120 + rr() * 130, 36 + rr() * 22, 220 + i * 7 + k, pl, p.x > 4550 && rr() < 0.5 ? CORRUPT : rr() < 0.75 ? CRIMSON : MAGENTA);
      }
      for (let k = 0; k < 2; k++) { const p = at(S, 0.35 + rr() * 0.6); strand(P, p.x, p.y, 260 + rr() * 320, 230 + i * 5 + k, pl === 'front' ? 'mid' : pl); }
    });
    // sparse dark leaves behind the first limb so the canopy stays continuous across the biome split
    spray(P, [[3450, -60, 34], [3470, 190, 22], [3500, 440, 10]], 120, 'back', { leaf: 210, wr: 0.16, maxY: 740 });

    // hanging vines (painted; the vine_fg sprites hang at their own columns)
    const vines = [[300, 120, 860, 'mid', {}], [760, 150, 540, 'front', { leaf: 150 }], [1260, 110, 980, 'mid', {}], [1630, 90, 620, 'back', { budAt: false }],
      [2570, 120, 640, 'mid', {}], [3200, 150, 1020, 'mid', { budAt: false }], [3420, 250, 760, 'mid', { thorny: true }],
      [3880, 460, 480, 'back', { thorny: true }], [4300, 380, 560, 'mid', { thorny: true }], [4790, 500, 600, 'front', { thorny: true }]];
    vines.forEach(([x, y, len, pl, o], i) => { if (vineCols.some(v => Math.abs(v - x) < 140)) console.log('fg: vine', x, 'near a sprite vine'); vine(P, x, y, len, 300 + i, pl, o); });

    // --- bottom: a ground band below anything a view reaches (y > ~3420), then leaves rising into view
    for (const pl of ['back', 'mid']) {
      const c = P[pl]; c.fillStyle = rgba(PLANE[pl]); c.beginPath(); c.moveTo(-10, LH + 10);
      for (let x = -10; x <= LW + 10; x += 20) {
        const corner = Math.max(smooth(1100, 0, x), smooth(4200, LW, x));
        c.lineTo(x, (pl === 'back' ? 3470 : 3500) - 60 * corner + 26 * N(x / 200, pl === 'back' ? 7 : 8) + 12 * N(x / 50, 9));
      }
      c.lineTo(LW + 10, LH + 10); c.closePath(); c.fill();
    }
    // the allowed top of the bottom foliage: low in the middle (the island nodes), rising toward the corners
    const topAt = x => 3000 - 360 * smooth(1300, 0, x) - 380 * smooth(3700, 5240, x) - 60 * smooth(2900, 3300, x);
    // back plane: grass and low bushes everywhere
    for (let x = -30, i = 0; x < LW + 30; x += 110 + R() * 110, i++) {
      const top = topAt(x);
      grass(P, x, LH + 20, 6 + Math.floor(R() * 5), top + 40, 400 + i, 'back');
      if (riftW(x) < 0.5 && R() < 0.55) bush(P, x + 50, 3460, 9, 240 + R() * 80, top + 20, 450 + i, 'back');
    }
    // realm: big fronds and broad leaves at the left corner, lower growth across the middle
    const fr = [[-90, -1.02, 1.0, 1250, 'mid'], [190, -1.3, 0.8, 1080, 'mid'], [480, -1.62, -0.7, 960, 'back'], [820, -1.2, 0.6, 820, 'mid'],
      [1150, -1.9, -0.6, 760, 'mid'], [2950, -1.95, -0.6, 900, 'mid'], [3230, -1.55, 0.5, 860, 'front']];
    fr.forEach(([x, a, arch, len, pl], i) => {
      const tip = frond(P, x, LH + 60, a, len, arch, 500 + i, pl, { maxTop: topAt(x) - 20, pinna: 1.1 });
      const rr = rng(520 + i);
      if (tip && rr() < 0.7) glows.push({ x: tip.x, y: tip.y - 6, r: 9 + rr() * 5, col: budCol(tip.x, rr), plane: pl });
    });
    broadLeaf(P, 30, LH + 60, 300, 3110, 470, 601, 'front', 0.3);
    broadLeaf(P, 520, LH + 60, 690, 3200, 440, 602, 'mid', 0.6);
    broadLeaf(P, 1120, LH + 60, 1010, 3240, 360, 603, 'mid', -0.7);
    broadLeaf(P, 2760, LH + 60, 2880, 3250, 330, 604, 'mid', 0.6);
    [[1480, 300], [1860, 260], [2200, 280], [2560, 300]].forEach(([x, l], i) => bush(P, x, 3460, 11, l, topAt(x), 610 + i, 'mid'));
    for (let x = 0, i = 0; x < 3400; x += 170 + R() * 120, i++) grass(P, x, LH + 20, 5 + Math.floor(R() * 4), topAt(x), 650 + i, 'mid');
    // rift: brambles arching up, crystal clusters, corrupted glints near the outcrop
    const brambles = [
      [[3380, 3700, 50], [3420, 3380, 38], [3560, 3170, 24], [3740, 3110, 12]],
      [[3780, 3700, 52], [3830, 3300, 38], [3710, 3080, 22], [3580, 3000, 10]],
      [[4100, 3700, 56], [4170, 3260, 42], [4340, 3030, 26], [4540, 2950, 12]],
      [[4560, 3700, 64], [4600, 3230, 48], [4700, 2960, 30], [4850, 2840, 16], [4960, 2800, 8]],
      [[5300, 2980, 80], [5060, 2900, 54], [4880, 2740, 30], [4800, 2600, 10]],
    ];
    brambles.forEach((pts, i) => thornLimb(P, pts, 700 + i, i % 2 ? 'front' : 'mid'));
    for (let x = 3300, i = 0; x < LW + 30; x += 150 + R() * 110, i++) grass(P, x, LH + 20, 4 + Math.floor(R() * 3), topAt(x) + 60, 760 + i, 'mid');
    const crys = [[3470, 3440, -1.9, 300, 74], [3560, 3450, -1.35, 220, 56], [3990, 3420, -1.7, 360, 84], [4080, 3440, -1.2, 240, 60],
      [4380, 3380, -1.95, 420, 96], [4470, 3400, -1.45, 290, 68], [4700, 3330, -1.8, 460, 100], [4790, 3350, -1.3, 320, 74], [4620, 3360, -2.2, 260, 60]];
    crys.forEach(([x, y, a, len, w], i) => {
      const cor = x > 4580 ? 1 : 0;
      crystal(P, E, x, y, a, len, w, 800 + i, i % 3 === 2 ? 'front' : 'mid', cor ? (i % 2 ? CORRUPT : CRIMSON) : (i % 2 ? MAGENTA : CRIMSON));
    });
    // corrupted glints: a broken row of tiny squares, as if the world were failing to render there
    const gr = rng(900);
    for (let k = 0; k < 8; k++) {
      const x = 4450 + gr() * 370, y = k < 5 ? 2920 + gr() * 200 : 440 + gr() * 220, s = 12 + gr() * 16;
      if (!clearOf([[x, y]])) continue;
      E.fillStyle = rgba(CORRUPT, 0.8); E.fillRect(x, y, s, s * (gr() < 0.5 ? 1 : 0.35));
      blob(E, x + s / 2, y + s / 2, s * 3, CORRUPT, 0.18);
    }

    // --- sides: nothing in the middle band. The corners and the swaying vine_fg sprites frame the left and right edges.

    // --- a few more buds among the canopy leaves
    const br = rng(1000);
    for (let k = 0; k < 8; k++) {
      const x = 80 + br() * 3150, y = 330 + br() * 300;
      if (!clearOf([[x, y]], 60)) continue;
      glows.push({ x, y, r: 7 + br() * 5, col: budCol(x, br), plane: br() < 0.5 ? 'mid' : 'back' });
    }
    glows.forEach((g, i) => { if (!clearOf([[g.x, g.y]], 60)) return; bud(P[g.plane], E, g.x, g.y, g.r * (g.tiny ? 0.9 : 1.55), g.col, rng(1100 + i), PLANE[g.plane]); });

    // --- merge the planes: the front plane is closer to the camera, so it gets extra defocus
    const base = mk(CW, CH), b = c2(base, true);
    b.drawImage(P.backC, 0, 0);
    b.drawImage(P.midC, 0, 0);
    b.save(); b.filter = `blur(${(8 * PS).toFixed(2)}px)`; b.drawImage(P.frontC, 0, 0); b.restore();
    return { base, emis: E0 };
  }

  // ---------------------------------------------------------------- float post: atmosphere, blur, keep-clear, bleed
  function atmosphere(base, emis) {
    const A = CFG.atm, n = CW * CH;
    const bd = c2(base, true).getImageData(0, 0, CW, CH).data, ed = c2(emis, true).getImageData(0, 0, CW, CH).data;
    const R = new Float32Array(n), G = new Float32Array(n), B = new Float32Array(n), Al = new Float32Array(n);
    const hz = [], sat = A.saturation, con = A.contrast, maxL = A.maxLuma, emax = A.emissiveMax;
    for (let x = 0; x < CW; x++) { const t = smooth(CFG.splitX - CFG.fade, CFG.splitX + CFG.fade, x / PS), c = mix(A.hazeColor, A.hazeRift, t).map(v => v / 255); hz.push([...c, luma(...c)]); }
    const tr = (r, g, b, h, k, out) => {
      const L = luma(r, g, b);
      let r1 = L + (r - L) * sat, g1 = L + (g - L) * sat, b1 = L + (b - L) * sat;
      r1 = h[3] + (r1 - h[3]) * con; g1 = h[3] + (g1 - h[3]) * con; b1 = h[3] + (b1 - h[3]) * con;
      out[0] = r1 + (h[0] - r1) * k; out[1] = g1 + (h[1] - g1) * k; out[2] = b1 + (h[2] - b1) * k;
    };
    const c1 = [0, 0, 0], c3 = [0, 0, 0];
    for (let y = 0; y < CH; y++) {
      const k = A.haze + A.hazeBottom * smooth(0.35, 1, y / CH);
      for (let x = 0; x < CW; x++) {
        const i = y * CW + x, j = i * 4, ba = bd[j + 3] / 255, ea = ed[j + 3] / 255;
        if (ba <= 0 && ea <= 0) continue;
        const h = hz[x];
        let pr = 0, pg = 0, pb = 0;
        if (ba > 0) {
          tr(bd[j] / 255, bd[j + 1] / 255, bd[j + 2] / 255, h, k, c1);
          const L = luma(c1[0], c1[1], c1[2]); if (L > maxL) { const s = maxL / L; c1[0] *= s; c1[1] *= s; c1[2] *= s; }
          pr = c1[0] * ba; pg = c1[1] * ba; pb = c1[2] * ba;
        }
        let oa = ba;
        if (ea > 0) {  // self-lit: shaded far less than the silhouettes, clamped to emissiveMax
          tr(ed[j] / 255, ed[j + 1] / 255, ed[j + 2] / 255, h, k * 0.25, c3);
          const L = luma(c3[0], c3[1], c3[2]); if (L > emax) { const s = emax / L; c3[0] *= s; c3[1] *= s; c3[2] *= s; }
          const er = clamp(c3[0]) * ea, eg = clamp(c3[1]) * ea, eb = clamp(c3[2]) * ea;
          pr = pr + er - pr * er; pg = pg + eg - pg * eg; pb = pb + eb - pb * eb; oa = ba + ea - ba * ea;
        }
        R[i] = pr; G[i] = pg; B[i] = pb; Al[i] = oa;
      }
    }
    return [R, G, B, Al];
  }
  /** Gaussian blur of planar premultiplied channels: three running-sum box passes per axis (zero outside). */
  function blur(ch, w, h, sigma) {
    const n = 3, wIdeal = Math.sqrt(12 * sigma * sigma / n + 1); let wl = Math.floor(wIdeal); if (wl % 2 === 0) wl--;
    const m = Math.round((12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4));
    const radii = [0, 1, 2].map(i => ((i < m ? wl : wl + 2) - 1) / 2);
    const tmp = new Float32Array(w * h);
    const pass = (src, dst, len, lines, stride, lineStride, r) => {
      const inv = 1 / (2 * r + 1);
      for (let l = 0; l < lines; l++) {
        const o = l * lineStride; let acc = 0;
        for (let k = 0; k <= r && k < len; k++) acc += src[o + k * stride];
        for (let x = 0; x < len; x++) {
          dst[o + x * stride] = acc * inv;
          const a = x + r + 1, s = x - r;
          if (a < len) acc += src[o + a * stride];
          if (s >= 0) acc -= src[o + s * stride];
        }
      }
    };
    for (const c of ch) for (const r of radii) { pass(c, tmp, w, h, 1, w, r); pass(tmp, c, h, w, w, 1, r); }
  }
  function downsample2(ch, w, h) {
    const w2 = w >> 1, h2 = h >> 1;
    return ch.map(c => {
      const o = new Float32Array(w2 * h2);
      for (let y = 0; y < h2; y++) for (let x = 0; x < w2; x++) {
        const i = 2 * y * w + 2 * x; o[y * w2 + x] = 0.25 * (c[i] + c[i + 1] + c[i + w] + c[i + w + 1]);
      }
      return o;
    });
  }
  /** Quantize premultiplied float to straight RGBA8, then give every alpha-0 pixel the colour of its nearest
   *  visible pixel (8-neighbour BFS), keeping alpha 0. */
  function toRGBA8(ch, w, h) {
    const [R, G, B, A] = ch, n = w * h, out = new Uint8Array(n * 4), dist = new Int32Array(n).fill(-1), q = new Int32Array(n);
    let qt = 0;
    for (let i = 0; i < n; i++) {
      const a = A[i], a8 = Math.round(clamp(a) * 255);
      if (a8 === 0) continue;
      out[i * 4] = Math.round(clamp(R[i] / a) * 255); out[i * 4 + 1] = Math.round(clamp(G[i] / a) * 255);
      out[i * 4 + 2] = Math.round(clamp(B[i] / a) * 255); out[i * 4 + 3] = a8; dist[i] = 0; q[qt++] = i;
    }
    for (let qh = 0; qh < qt; qh++) {
      const i = q[qh], x = i % w, y = (i / w) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy; if ((!dx && !dy) || nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const k = ny * w + nx; if (dist[k] >= 0) continue;
        dist[k] = dist[i] + 1; out[k * 4] = out[i * 4]; out[k * 4 + 1] = out[i * 4 + 1]; out[k * 4 + 2] = out[i * 4 + 2]; q[qt++] = k;
      }
    }
    return out;
  }
  /** A canvas whose PNG export keeps straight (non-premultiplied) RGBA, including the colour of alpha-0 pixels. */
  function straightCanvas(px, w, h) {
    const c = mk(w, h), gl = c.getContext('webgl', { premultipliedAlpha: false, preserveDrawingBuffer: true, alpha: true, antialias: false });
    const sh = (t, s) => { const o = gl.createShader(t); gl.shaderSource(o, s); gl.compileShader(o); return o; };
    const pr = gl.createProgram();
    gl.attachShader(pr, sh(gl.VERTEX_SHADER, 'attribute vec2 p;varying vec2 u;void main(){u=p*0.5+0.5;gl_Position=vec4(p,0,1);}'));
    gl.attachShader(pr, sh(gl.FRAGMENT_SHADER, 'precision highp float;varying vec2 u;uniform sampler2D t;void main(){gl_FragColor=texture2D(t,vec2(u.x,1.0-u.y));}'));
    gl.linkProgram(pr); gl.useProgram(pr);
    const tex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, px);
    for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
    const bf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, bf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(pr, 'p'); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    gl.viewport(0, 0, w, h); gl.disable(gl.BLEND); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    return c;
  }

  LAYERS.fg = async function () {
    W = CW; H = CH;                                             // lib.js globals (canvas() defaults), unused here
    const t0 = performance.now();
    const { base, emis } = paint();
    let ch = atmosphere(base, emis);
    blur(ch, CW, CH, CFG.atm.blur * PS);
    ch = downsample2(ch, CW, CH);
    // keep-clear guarantee at output resolution (local = (px + 0.5) / res)
    const [R, G, B, A] = ch;
    const stat = { hardMax: 0, softMax: 0, bandMax: 0, bandOver30: 0, clampedPx: 0 };
    let bandN = 0;
    for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
      const i = y * OW + x, a = A[i]; if (a <= 0) continue;
      const lx = (x + 0.5) / CFG.res, ly = (y + 0.5) / CFG.res, al = allowance(lx, ly);
      if (a > al) { const s = al / a; R[i] *= s; G[i] *= s; B[i] *= s; A[i] = al; stat.clampedPx++; }
    }
    for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
      const i = y * OW + x, a = A[i], lx = (x + 0.5) / CFG.res, ly = (y + 0.5) / CFG.res;
      if (CFG.hard.some(z => inside(lx, ly, z))) stat.hardMax = Math.max(stat.hardMax, a);
      else if (CFG.soft.some(z => inside(lx, ly, z))) stat.softMax = Math.max(stat.softMax, a);
      if (ly > BAND[0] && ly < BAND[1]) { bandN++; stat.bandMax = Math.max(stat.bandMax, a); if (a > 0.3) stat.bandOver30++; }
    }
    stat.bandOver30 = +(stat.bandOver30 / bandN).toFixed(4);
    const px = toRGBA8(ch, OW, OH);
    let cover = 0; for (let i = 3; i < px.length; i += 4) if (px[i] >= 2) cover++;
    stat.coverage = +(cover / (OW * OH)).toFixed(3);
    console.log('fg', OW + 'x' + OH, JSON.stringify(stat), Math.round(performance.now() - t0) + ' ms');
    const out = straightCanvas(px, OW, OH);
    window.__fgStats = stat;
    window.__last = out;
    return out;
  };
})();
