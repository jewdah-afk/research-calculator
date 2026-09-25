// Parallax 2 — the World: the Milestone Tree on its floating island, the Multiverse rift, the achievement shrine.
// Transparent PNG, 3840x2160. Nodes are NOT drawn here (they are live UI); only their cradles and glows.
const NODES = {
  m: [1500, 1900, 'b35cff'], mm: [1180, 1960, 'd17aff'], em: [1820, 1960, 'e88af2'], p: [1500, 1580, '6fc3ff'],
  pe: [1040, 1300, 'ff9a2e'], sp: [1330, 1250, '5fe0ff'], pb: [1670, 1250, '57e0b0'], pp: [1960, 1300, 'ff4d6d'],
  se: [1150, 980, 'ff6a1f'], hp: [1500, 930, '7fd9ff'], ep: [1850, 980, '9be02c'], hb: [1180, 660, '6dffb0'],
  ap: [1500, 610, '8ff3f3'], mp: [1820, 660, 'ff5a1f'], t: [1500, 320, 'ffe93a'],
  pm: [3150, 1560, 'ff2e63'], pep: [2790, 1180, 'f2b04d'], cr: [3510, 1200, '39ff14'], cm: [3690, 930, '1fbf4a'],
  ex: [3150, 780, '45e07f'], ach: [520, 600, 'ffc93c'],
};
const DARK = [12, 6, 22], BARK = [34, 20, 62], BARKL = [128, 104, 206], RIM = [205, 182, 255], FOL = [30, 14, 58];
const LIGHT = (() => { const v = [-0.45, -0.62, 0.64]; const d = Math.hypot(...v); return v.map(a => a / d); })();

LAYERS.world = async function () {
  H = 2560;
  const sockets = [];
  const out = canvas(), o = ctx(out);
  const glow = canvas(), g = ctx(glow);         // additive light, bloomed at the end
  const R = rng(7), N = makeNoise(11), N2 = makeNoise(29);
  const col = k => hex(NODES[k][2]);

  // ---------- bark limbs ----------
  function drawLimb(x, S, { vein = null, seed = 1, rim = 1 } = {}) {
    const r = rng(seed);
    const wob = p => 0.10 * N(p.s / 90 + seed * 13, seed) + 0.05 * N(p.s / 23, seed * 3);
    const shape = outline(S, wob);
    x.save(); poly(x, shape); x.fillStyle = rgba(BARK); x.fill(); x.clip();
    // shading bands across the cylinder
    const bands = 14;
    for (let b = 0; b < bands; b++) {
      const off = -1 + (b + 0.5) * 2 / bands;
      const mid = at(S, 0.5);
      const nx = mid.nx * off, ny = mid.ny * off, nz = Math.sqrt(Math.max(0, 1 - off * off));
      const li = Math.max(0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]);
      x.strokeStyle = rgba(mix(DARK, BARKL, Math.pow(li, 2.2) * 0.42), 0.9);
      x.lineWidth = 2; x.lineCap = 'round';
      // fill band: thick stroke along the offset curve
      x.beginPath();
      S.forEach((p, i) => { const w = p.w * 0.5, px = p.x + p.nx * w * off, py = p.y + p.ny * w * off; i ? x.lineTo(px, py) : x.moveTo(px, py); });
      x.lineWidth = Math.max(2, at(S, 0).w / bands * 1.4); x.stroke();
    }
    // fibres: fine bark grain following the limb
    const nf = Math.ceil(S[0].w / 2.2);
    for (let f = 0; f < nf; f++) {
      const off0 = r() * 2 - 1, ph = r() * 100;
      const from = r() * 0.3, to = from + 0.3 + r() * 0.7;
      const mid = at(S, 0.5);
      const nx = mid.nx * off0, ny = mid.ny * off0, nz = Math.sqrt(Math.max(0, 1 - off0 * off0));
      const li = Math.max(0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]);
      const dark = r() < 0.55;
      x.strokeStyle = dark ? rgba(DARK, 0.4 + r() * 0.4) : rgba(mix(BARK, BARKL, 0.15 + Math.pow(li, 2) * 0.55), 0.14 + r() * 0.3);
      x.lineWidth = 0.8 + r() * (dark ? 2.6 : 1.6);
      x.beginPath();
      const a = Math.floor(from * (S.length - 1)), b = Math.min(S.length - 1, Math.floor(to * (S.length - 1)));
      for (let i = a; i <= b; i++) {
        const p = S[i]; const off = clamp(off0 + 0.12 * N2(p.s / 70 + ph, ph), -1, 1);
        const px = p.x + p.nx * p.w * 0.5 * off, py = p.y + p.ny * p.w * 0.5 * off;
        i === a ? x.moveTo(px, py) : x.lineTo(px, py);
      }
      x.stroke();
    }
    // knots
    const nk = Math.floor(S.len / 260);
    for (let k = 0; k < nk; k++) {
      const p = at(S, 0.1 + r() * 0.8); const off = (r() - 0.5) * 0.8;
      const cx = p.x + p.nx * p.w * 0.5 * off, cy = p.y + p.ny * p.w * 0.5 * off, rr = p.w * (0.08 + r() * 0.1);
      x.save(); x.translate(cx, cy); x.rotate(Math.atan2(p.ty, p.tx));
      x.fillStyle = rgba(DARK, 0.8); x.beginPath(); x.ellipse(0, 0, rr * 1.8, rr, 0, 0, 7); x.fill();
      x.strokeStyle = rgba(BARKL, 0.35); x.lineWidth = 1.5; x.beginPath(); x.ellipse(0, 0, rr * 2.4, rr * 1.5, 0, 0, 7); x.stroke();
      x.restore();
    }
    // edge occlusion
    x.globalAlpha = 0.75; x.strokeStyle = rgba(DARK); x.lineWidth = 6; poly(x, shape); x.stroke(); x.globalAlpha = 1;
    x.restore();
    // rim light on the side facing the light
    const side = (at(S, 0.5).nx * LIGHT[0] + at(S, 0.5).ny * LIGHT[1]) > 0 ? 1 : -1;
    x.save(); x.lineCap = 'round'; x.lineJoin = 'round';
    pathAlong(x, S.map(p => ({ ...p, w: p.w * (1 + wob(p)) })), side * 0.9); x.strokeStyle = rgba(RIM, 0.45 * rim); x.lineWidth = 1.6; x.stroke();
    x.restore();
    g.save(); g.lineCap = 'round'; pathAlong(g, S.map(p => ({ ...p, w: p.w * (1 + wob(p)) })), side * 0.92);
    g.strokeStyle = rgba(RIM, 0.07 * rim); g.lineWidth = 4; g.stroke(); g.restore();
    // energy vein
    if (vein) {
      const vc = vein;
      for (const [lw, a] of [[6, 0.22], [2.6, 0.75], [1.1, 0.95]]) {
        g.save(); g.lineCap = 'round'; g.beginPath();
        S.forEach((p, i) => { const off = 0.35 * N(p.s / 160 + seed, 7.7) ; const px = p.x + p.nx * p.w * 0.5 * off, py = p.y + p.ny * p.w * 0.5 * off; i ? g.lineTo(px, py) : g.moveTo(px, py); });
        g.strokeStyle = lw < 2 ? rgba(mix(vc, [255, 255, 255], 0.6), a) : rgba(vc, a); g.lineWidth = lw * clamp(S[0].w / 60, 0.5, 1.4); g.stroke(); g.restore();
      }
      o.save(); o.lineCap = 'round'; o.beginPath();
      S.forEach((p, i) => { const off = 0.35 * N(p.s / 160 + seed, 7.7); const px = p.x + p.nx * p.w * 0.5 * off, py = p.y + p.ny * p.w * 0.5 * off; i ? o.lineTo(px, py) : o.moveTo(px, py); });
      o.strokeStyle = rgba(mix(vc, [255, 255, 255], 0.35), 0.9); o.lineWidth = 2; o.stroke(); o.restore();
    }
  }

  // twigs: small recursive offshoots, return their tips for foliage
  const tips = [];
  function twigs(x, S, seed, avoid, accent, count = 6, depth = 0) {
    const r = rng(seed);
    for (let i = 0; i < count; i++) {
      const t = 0.25 + r() * 0.72; const p = at(S, t);
      if (avoid.some(([ax, ay]) => Math.hypot(p.x - ax, p.y - ay) < 110)) continue;
      const side = r() < 0.5 ? 1 : -1;
      let ang = Math.atan2(p.ty, p.tx) + side * (0.5 + r() * 0.6);
      // bias upwards
      const up = -Math.PI / 2; ang = ang + (up - ang) * 0.25 * (Math.abs(((up - ang + Math.PI * 3) % (Math.PI * 2)) - Math.PI) < 2 ? 1 : 0);
      const len = (depth ? 50 : 90) + r() * (depth ? 60 : 110);
      const w0 = Math.min(p.w * 0.45, depth ? 7 : 14);
      const bend = (r() - 0.5) * 0.8;
      const pts = [];
      for (let k = 0; k <= 3; k++) { const a = ang + bend * k / 3; const d = len * k / 3; pts.push([p.x + Math.cos(ang) * d + Math.cos(a) * d * 0.1, p.y + Math.sin(ang) * d + Math.sin(a) * d * 0.1 - k * 6, lerp(w0, 1.2, k / 3)]); }
      const T = spline(pts, 10);
      if (T.some(q => avoid.some(([ax, ay]) => Math.hypot(q.x - ax, q.y - ay) < 96))) continue;
      drawLimb(x, T, { seed: seed * 7 + i, rim: 0.7 });
      const e = T[T.length - 1]; tips.push([e.x, e.y, accent, depth]);
      if (depth < 1 && r() < 0.6) twigs(x, T, seed * 13 + i, avoid, accent, 2, depth + 1);
    }
  }

  // foliage cluster
  function cluster(x, cx, cy, Rr, n, accent, seed) {
    const r = rng(seed);
    // silhouette mass
    for (let i = 0; i < 7; i++) blob(x, cx + gauss(r) * Rr * 0.35, cy + gauss(r) * Rr * 0.3, Rr * (0.55 + r() * 0.35), FOL, 0.55, 0.35);
    const leaves = [];
    for (let i = 0; i < n; i++) {
      const a = r() * Math.PI * 2, d = Math.pow(r(), 0.6) * Rr;
      leaves.push({ x: cx + Math.cos(a) * d, y: cy + Math.sin(a) * d * 0.85, a, d: r(), s: 9 + r() * 17 });
    }
    leaves.sort((p, q) => p.d - q.d);
    for (const L of leaves) {
      const dx = (L.x - cx) / Rr, dy = (L.y - cy) / Rr;
      const lit = clamp(0.5 - (dx * 0.55 + dy * 0.75) * 0.6 + (L.d - 0.5) * 0.5);
      let c = mix(FOL, [92, 58, 160], lit * 0.9);
      if (L.d > 0.6) c = mix(c, accent, lit * 0.55);
      x.fillStyle = rgba(c, 0.92);
      const ang = L.a + (r() - 0.5) * 1.4;
      leaf(x, L.x, L.y, L.s, L.s * 0.38, ang);
      if (L.d > 0.7 && lit > 0.45) { x.fillStyle = rgba(mix(c, [255, 255, 255], 0.35), 0.5); leaf(x, L.x + 1, L.y - 1, L.s * 0.55, L.s * 0.14, ang); }
      if (r() < 0.07) { g.fillStyle = rgba(accent, 0.8); leaf(g, L.x, L.y, L.s * 0.9, L.s * 0.3, ang); }
    }
    // bioluminescent spores
    for (let i = 0; i < n / 14; i++) {
      const a = r() * 7, d = r() * Rr * 1.1; const px = cx + Math.cos(a) * d, py = cy + Math.sin(a) * d;
      blob(g, px, py, 4 + r() * 7, accent, 0.9); blob(g, px, py, 1.5, [255, 255, 255], 1);
    }
  }

  // ---------- floating island ----------
  function island(x, cx, top, halfW, depth, seed, moss) {
    const r = rng(seed), n = makeNoise(seed);
    const pts = [];
    for (let i = 0; i <= 80; i++) { const t = i / 80; const xx = cx - halfW + t * halfW * 2; const edge = Math.sin(t * Math.PI); pts.push([xx, top + (1 - Math.pow(edge, 0.35)) * 60 + 9 * n(xx / 90, 1) + 46 * fbm(n, xx / 520, 3.3, 3) * edge]); }
    for (let i = 160; i >= 0; i--) { const t = i / 160; const xx = cx - halfW * 0.98 + t * halfW * 1.96; const prof = Math.pow(1 - Math.pow(Math.abs(2 * t - 1), 1.7), 1.25); const jag = 0.82 + 0.3 * fbm(n, xx / 160, 9, 3) + 0.06 * n(xx / 22, 4); pts.push([xx, top + 40 + depth * prof * jag]); }
    x.save(); poly(x, pts);
    const gr = x.createLinearGradient(0, top, 0, top + depth);
    gr.addColorStop(0, rgba([62, 40, 108])); gr.addColorStop(0.12, rgba([36, 22, 68])); gr.addColorStop(0.7, rgba([22, 12, 42])); gr.addColorStop(1, rgba([30, 14, 52]));
    x.fillStyle = gr; x.fill(); x.clip();
    // strata + cracks
    for (let i = 0; i < 60; i++) {
      const y0 = top + 30 + r() * depth, x0 = cx - halfW + r() * halfW * 2, len = 80 + r() * 300;
      x.beginPath(); for (let k = 0; k <= 20; k++) { const xx = x0 + len * k / 20; const yy = y0 + 8 * n(xx / 50, y0 / 50) + k * (r() - 0.5) * 2; k ? x.lineTo(xx, yy) : x.moveTo(xx, yy); }
      x.strokeStyle = r() < 0.6 ? rgba(DARK, 0.5) : rgba([96, 70, 160], 0.22); x.lineWidth = 1 + r() * 3; x.stroke();
    }
    x.save(); x.beginPath(); for (let i = pts.length - 1; i > 80; i--) { const p = pts[i]; i === pts.length - 1 ? x.moveTo(p[0], p[1]) : x.lineTo(p[0], p[1]); } const rl = x.createLinearGradient(cx - halfW, 0, cx + halfW, 0); rl.addColorStop(0, 'rgba(200,170,255,0.55)'); rl.addColorStop(0.6, 'rgba(160,120,255,0.18)'); rl.addColorStop(1, 'rgba(120,80,220,0.05)'); x.strokeStyle = rl; x.lineWidth = 3; x.stroke(); x.restore();
    // side shading: left lit, right dark
    const sh = x.createLinearGradient(cx - halfW, 0, cx + halfW, 0);
    sh.addColorStop(0, 'rgba(150,120,255,0.10)'); sh.addColorStop(0.5, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,0,0.45)');
    x.fillStyle = sh; x.fillRect(cx - halfW, top - 100, halfW * 2, depth + 200);
    x.restore();
    // glowing moss rim along the top
    // moss: a soft lit cap on the top surface, brighter in patches
    x.save(); poly(x, pts); x.clip();
    for (let i = 0; i < 80; i++) { const p = pts[i], q = pts[i + 1]; const k = 0.5 + 0.5 * n(p[0] / 210, 5.5);
      const mg = x.createLinearGradient(0, p[1] - 4, 0, p[1] + 26); mg.addColorStop(0, rgba(moss, 0.25 + 0.55 * k)); mg.addColorStop(1, rgba(moss, 0));
      x.fillStyle = mg; x.fillRect(p[0], Math.min(p[1], q[1]) - 4, q[0] - p[0] + 1, 34); }
    x.restore();
    for (let i = 0; i < 80; i++) { const p = pts[i], q = pts[i + 1]; const k = 0.5 + 0.5 * n(p[0] / 210, 5.5);
      x.strokeStyle = rgba(mix(moss, [255, 255, 255], 0.2), 0.3 + 0.6 * k); x.lineWidth = 1.5 + 2 * k; x.beginPath(); x.moveTo(...p); x.lineTo(...q); x.stroke();
      g.strokeStyle = rgba(moss, 0.12 + 0.4 * k * k); g.lineWidth = 8; g.beginPath(); g.moveTo(...p); g.lineTo(...q); g.stroke(); }
    // bioluminescent flowers
    for (let i = 0; i < halfW / 14; i++) { const p = pts[2 + Math.floor(r() * 77)]; const c = [[255, 120, 200], [120, 230, 255], [255, 220, 120], [190, 140, 255]][Math.floor(r() * 4)]; const hh = 6 + r() * 22;
      x.strokeStyle = rgba([60, 36, 110], 0.9); x.lineWidth = 1.2; x.beginPath(); x.moveTo(p[0], p[1] + 2); x.lineTo(p[0] + (r() - 0.5) * 6, p[1] - hh); x.stroke();
      blob(g, p[0], p[1] - hh, 5 + r() * 5, c, 0.9); blob(x, p[0], p[1] - hh, 2.2, [255, 255, 255], 1); }
    // grass blades
    for (let i = 0; i < halfW * 2.2; i++) {
      const p = pts[Math.floor(r() * 81)]; const h = 4 + Math.pow(r(), 2) * 34; const lean = (r() - 0.5) * 10;
      x.strokeStyle = rgba(mix([60, 36, 110], moss, r() * 0.8), 0.9); x.lineWidth = 1 + r() * 1.5;
      x.beginPath(); x.moveTo(p[0], p[1] + 2); x.quadraticCurveTo(p[0] + lean * 0.3, p[1] - h * 0.6, p[0] + lean, p[1] - h); x.stroke();
    }
    return pts;
  }
  function crystal(x, cx, cy, h, w, ang, c, seed) {
    const r = rng(seed);
    x.save(); x.translate(cx, cy); x.rotate(ang);
    const tip = -h, sh = h * 0.22;
    const L = [[-w / 2, 0], [-w / 2, tip + sh], [0, tip], [0, 0]], Rt = [[0, 0], [0, tip], [w / 2, tip + sh], [w / 2, 0]];
    poly(x, L); const gl = x.createLinearGradient(-w / 2, 0, 0, tip); gl.addColorStop(0, rgba(mix(c, DARK, 0.55), 0.95)); gl.addColorStop(1, rgba(mix(c, [255, 255, 255], 0.45), 0.95)); x.fillStyle = gl; x.fill();
    poly(x, Rt); const gr = x.createLinearGradient(w / 2, 0, 0, tip); gr.addColorStop(0, rgba(mix(c, DARK, 0.8), 0.95)); gr.addColorStop(1, rgba(mix(c, DARK, 0.2), 0.95)); x.fillStyle = gr; x.fill();
    x.strokeStyle = rgba(mix(c, [255, 255, 255], 0.7), 0.9); x.lineWidth = 1.4; x.beginPath(); x.moveTo(0, 0); x.lineTo(0, tip); x.stroke();
    x.restore();
    g.save(); g.translate(cx, cy); g.rotate(ang); g.fillStyle = rgba(c, 0.5); poly(g, [...L, ...Rt]); g.fill(); g.restore();
    blob(g, cx + Math.sin(ang) * h * 0.9, cy - Math.cos(ang) * h * 0.9, h * 0.35, c, 0.5);
  }
  function crystalCluster(x, cx, cy, n, size, c, seed) {
    const r = rng(seed);
    const items = [];
    for (let i = 0; i < n; i++) items.push([cx + (r() - 0.5) * size * 1.4, cy + r() * 6, size * (0.35 + r() * 0.75), (r() - 0.5) * 0.9]);
    items.sort((a, b) => b[2] - a[2]);
    items.forEach((it, i) => crystal(x, it[0], it[1], it[2], it[2] * 0.26, it[3], c, seed + i));
  }

  // ---------- cradles: woven rings where nodes sit ----------
  function cradle(x, key, rr = 84, seed = 1) {
    const [cx, cy] = NODES[key], c = col(key), r = rng(seed);
    blob(g, cx, cy, rr * 2.0, c, 0.10);
    // recessed seat
    const sg = x.createRadialGradient(cx - 18, cy - 22, rr * 0.2, cx, cy, rr + 10);
    sg.addColorStop(0, rgba([30, 18, 56], 0.95)); sg.addColorStop(0.8, rgba(DARK, 0.97)); sg.addColorStop(1, rgba(DARK, 0.0));
    x.fillStyle = sg; x.beginPath(); x.arc(cx, cy, rr + 10, 0, 7); x.fill();
    // bezel: dark band, lit on the upper-left, shadowed lower-right
    x.save(); x.lineWidth = 11; x.strokeStyle = rgba(BARK); x.beginPath(); x.arc(cx, cy, rr, 0, 7); x.stroke();
    const bz = x.createLinearGradient(cx - rr, cy - rr, cx + rr, cy + rr);
    bz.addColorStop(0, rgba(RIM, 0.75)); bz.addColorStop(0.35, rgba(BARKL, 0.25)); bz.addColorStop(0.7, rgba(DARK, 0.0)); bz.addColorStop(1, rgba(DARK, 0.0));
    x.lineWidth = 2; x.strokeStyle = bz; x.beginPath(); x.arc(cx, cy, rr + 5, 0, 7); x.stroke();
    x.strokeStyle = rgba(DARK, 0.9); x.lineWidth = 2; x.beginPath(); x.arc(cx, cy, rr - 5.5, 0, 7); x.stroke();
    x.restore();
    // four curled prongs gripping the gem
    for (let i = 0; i < 4; i++) {
      const a = Math.PI / 4 + i * Math.PI / 2 + (r() - 0.5) * 0.12;
      const P = (da, dr, w) => [cx + Math.cos(a + da) * (rr + dr), cy + Math.sin(a + da) * (rr + dr), w];
      drawLimb(x, spline([P(-0.30, 16, 15), P(-0.12, 10, 13), P(0.02, 1, 10), P(0.10, -9, 5), P(0.12, -13, 2)], 10), { seed: seed * 31 + i, rim: 1.3 });
      const e = P(0.11, -11, 0); sockets.push({ tip: [e[0], e[1]], c });
    }
    // accent tick marks on the bezel in the node colour
    for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2; if (i % 6 === 3) continue; x.strokeStyle = rgba(c, i % 2 ? 0.25 : 0.55); x.lineWidth = 2; x.beginPath(); x.moveTo(cx + Math.cos(a) * (rr - 3), cy + Math.sin(a) * (rr - 3)); x.lineTo(cx + Math.cos(a) * (rr + 3), cy + Math.sin(a) * (rr + 3)); x.stroke(); }
    sockets.push({ cx, cy, rr, c });
  }

  // =============== THE MAIN TREE ===============
  // ground light
  blob(o, 1500, 2060, 900, [120, 60, 220], 0.16);
  blob(g, 1500, 2000, 520, [179, 92, 255], 0.18);

  // roots hanging below the island (behind)
  const isl = island(o, 1500, 1985, 800, 540, 3, [168, 110, 255]);
  const hr = rng(401);
  [720, 840, 960, 1090, 1230, 1380, 1640, 1790, 1930, 2060, 2190, 2290].forEach((hx, i) => {
    const under = isl.slice(81).reduce((m, p) => Math.abs(p[0] - hx) < Math.abs(m[0] - hx) ? p : m); const hy = under[1] - 10;
    const len = 110 + hr() * 260 * (1 - Math.abs(hx - 1500) / 1100), pts = [];
    let px = hx, sway = (hr() - 0.5) * 2;
    for (let k = 0; k <= 6; k++) { pts.push([px, hy + len * k / 6, lerp(22, 1.5, Math.pow(k / 6, 0.7))]); px += sway * 14 + Math.sin(k * 1.3 + i) * 10; }
    const S = spline(pts, 10);
    drawLimb(o, S, { seed: 400 + i, rim: 0.6, vein: hr() < 0.45 ? hex('b35cff') : null });
    for (let j = 0; j < 3; j++) { const p = at(S, 0.25 + hr() * 0.5), d = hr() < 0.5 ? -1 : 1, l = 30 + hr() * 50; drawLimb(o, spline([[p.x, p.y, 6], [p.x + d * l * 0.5, p.y + l * 0.5, 3], [p.x + d * l * 0.7, p.y + l, 1]], 8), { seed: 460 + i * 3 + j, rim: 0.5 }); }
    const e = S[S.length - 1]; blob(g, e.x, e.y, 12, [210, 150, 255], 0.9); blob(g, e.x, e.y, 3, [255, 255, 255], 1);
  });
  [[1000, 'd17aff'], [1320, 'b35cff'], [1560, '7fd9ff'], [1880, 'e88af2']].forEach(([hx, c], i) => {
    const under = isl.slice(81).reduce((m, p) => Math.abs(p[0] - hx) < Math.abs(m[0] - hx) ? p : m);
    for (let j = 0; j < 3; j++) crystal(o, hx + (j - 1) * 26 + hr() * 10, under[1] - 16, 50 + hr() * 70, 18, Math.PI + (hr() - 0.5) * 0.4, hex(c), 600 + i * 5 + j);
  });
  // island crystals & tufts
  [[860, 1995, 7, 60, 'd17aff'], [2150, 1990, 6, 55, 'e88af2'], [1290, 2002, 4, 34, 'b35cff'], [1720, 2000, 4, 30, '7fd9ff'], [1020, 1998, 3, 26, 'ff9a2e'], [1980, 1995, 3, 28, 'ff4d6d']]
    .forEach(([cx, cy, n, s, c], i) => crystalCluster(o, cx, cy, n, s, hex(c), 90 + i));

  const TRUNK = spline([[1500, 2030, 250], [1492, 1990, 205], [1480, 1900, 168], [1512, 1730, 142], [1500, 1580, 126], [1480, 1420, 112], [1505, 1250, 98], [1516, 1100, 88], [1498, 930, 78], [1484, 780, 67], [1503, 610, 56], [1511, 470, 44], [1500, 330, 30], [1500, 240, 14]], 20);
  const L = (pts) => spline(pts, 18);
  const limbs = {
    rootL2: L([[1478, 2012, 54], [1410, 2030, 28], [1340, 2042, 8], [1290, 2046, 2]]),
    rootR2: L([[1524, 2012, 54], [1592, 2032, 28], [1664, 2040, 8], [1716, 2044, 2]]),
    rootL: L([[1470, 2000, 80], [1380, 2016, 56], [1262, 1996, 40], [1180, 1960, 30], [1080, 1992, 18], [985, 2030, 9], [905, 2090, 3]]),
    rootR: L([[1530, 2000, 80], [1622, 2018, 56], [1742, 1996, 40], [1820, 1960, 30], [1922, 1996, 18], [2012, 2040, 9], [2090, 2095, 3]]),
    pe: L([[1495, 1475, 66], [1380, 1445, 52], [1240, 1372, 40], [1040, 1300, 30], [905, 1228, 17], [808, 1140, 6]]),
    pp: L([[1507, 1462, 66], [1628, 1424, 52], [1782, 1358, 40], [1960, 1300, 30], [2092, 1214, 17], [2172, 1118, 6]]),
    sp: L([[1492, 1402, 42], [1418, 1342, 33], [1330, 1250, 25], [1272, 1150, 12], [1246, 1066, 4]]),
    pb: L([[1508, 1398, 42], [1588, 1336, 33], [1670, 1250, 25], [1733, 1152, 12], [1762, 1072, 4]]),
    se: L([[1500, 1132, 54], [1378, 1086, 42], [1252, 1020, 31], [1150, 980, 25], [1022, 928, 12], [930, 858, 4]]),
    ep: L([[1508, 1126, 54], [1632, 1080, 42], [1758, 1020, 31], [1850, 980, 25], [1978, 922, 12], [2064, 842, 4]]),
    hb: L([[1492, 802, 46], [1388, 770, 35], [1270, 702, 27], [1180, 660, 21], [1072, 600, 10], [1002, 520, 3]]),
    mp: L([[1506, 796, 46], [1612, 760, 35], [1732, 700, 27], [1820, 660, 21], [1930, 592, 10], [1992, 512, 3]]),
    crL: L([[1500, 380, 24], [1430, 318, 14], [1360, 250, 7], [1318, 190, 2]]),
    crR: L([[1502, 385, 24], [1580, 312, 14], [1650, 246, 7], [1690, 186, 2]]),
  };
  const veinOf = { rootL2: 'm', rootR2: 'm', rootL: 'mm', rootR: 'em', pe: 'pe', pp: 'pp', sp: 'sp', pb: 'pb', se: 'se', ep: 'ep', hb: 'hb', mp: 'mp', crL: 't', crR: 't' };
  const avoid = Object.values(NODES).map(n => [n[0], n[1]]);

  // back foliage (behind limbs): the outer tips and crown
  const back = canvas(), b = ctx(back);
  const tipC = [[800, 1130, 'pe', 150], [2178, 1110, 'pp', 150], [925, 850, 'se', 130], [2070, 835, 'ep', 130], [995, 510, 'hb', 120], [1998, 500, 'mp', 120],
    [1240, 1060, 'sp', 90], [1768, 1064, 'pb', 90], [1320, 180, 't', 120], [1690, 176, 't', 120], [1500, 170, 't', 170]];
  tipC.forEach(([x0, y0, k, rr], i) => cluster(b, x0, y0, rr, Math.round(rr * 2.6), col(k), 500 + i));
  o.drawImage(back, 0, 0);

  // limbs (twigs first so the limbs overlap their bases)
  const twigC = canvas(), tw = ctx(twigC);
  Object.entries(limbs).forEach(([k, S], i) => { if (!k.startsWith('root')) twigs(tw, S, 200 + i * 17, avoid, col(veinOf[k]), k.startsWith('cr') ? 3 : 7); });
  o.drawImage(twigC, 0, 0);
  Object.entries(limbs).forEach(([k, S], i) => drawLimb(o, S, { vein: col(veinOf[k]), seed: 60 + i }));
  drawLimb(o, TRUNK, { vein: hex('b35cff'), seed: 3 });
  // secondary trunk veins in each tier colour (bottom -> top)
  [['p', 1580, 1420], ['hp', 1100, 930], ['ap', 780, 610], ['t', 470, 330]].forEach(([k, y0, y1], i) => {
    const c = col(k); const S = TRUNK.filter(p => p.y <= y0 + 160 && p.y >= y1);
    if (S.length < 2) return;
    for (const [lw, a] of [[8, 0.3], [3, 0.85]]) { g.save(); g.lineCap = 'round'; g.beginPath(); S.forEach((p, j) => { const off = -0.3 + 0.25 * N(p.s / 120, i + 4); const px = p.x + p.nx * p.w * 0.5 * off, py = p.y + p.ny * p.w * 0.5 * off; j ? g.lineTo(px, py) : g.moveTo(px, py); }); g.strokeStyle = rgba(c, a); g.lineWidth = lw; g.stroke(); g.restore(); }
  });

  // cradles on every tree node
  ['m', 'mm', 'em', 'p', 'pe', 'sp', 'pb', 'pp', 'se', 'hp', 'ep', 'hb', 'ap', 'mp', 't'].forEach((k, i) => cradle(o, k, k === 't' ? 90 : 84, 700 + i));

  // front foliage: small clusters on twig tips (skip tips close to nodes)
  const front = canvas(), f = ctx(front);
  tips.forEach(([x0, y0, c, d], i) => { if (avoid.some(([ax, ay]) => Math.hypot(x0 - ax, y0 - ay) < 105)) return; cluster(f, x0, y0, d ? 34 : 48, d ? 26 : 44, c, 900 + i); });
  o.drawImage(front, 0, 0);

  // =============== ACHIEVEMENT SHRINE (upper left) ===============
  {
    const [ax, ay] = NODES.ach; const gold = col('ach');
    blob(o, ax, ay + 40, 260, [255, 190, 60], 0.12);
    island(o, ax, ay + 88, 170, 210, 41, [255, 201, 60]);
    crystalCluster(o, ax - 120, ay + 92, 4, 40, gold, 43); crystalCluster(o, ax + 125, ay + 90, 3, 34, gold, 44);
    // arch of light behind
    for (let i = 0; i < 3; i++) { g.save(); g.strokeStyle = rgba(gold, 0.5 - i * 0.12); g.lineWidth = 4 - i; g.beginPath(); g.arc(ax, ay, 104 + i * 18, Math.PI * 1.02, Math.PI * 1.98); g.stroke(); g.restore(); }
    cradle(o, 'ach', 84, 77);
  }

  // =============== MULTIVERSE RIFT (right) ===============
  await rift(o, g, R, { cradle, sockets });

  // =============== motes ===============
  const mr = rng(99);
  for (let i = 0; i < 520; i++) {
    const x0 = mr() < 0.72 ? 700 + mr() * 1600 : 2500 + mr() * 1300, y0 = 150 + mr() * 1900;
    const c = mr() < 0.5 ? [200, 170, 255] : mr() < 0.5 ? [120, 230, 255] : [255, 150, 210];
    const s = mr() < 0.9 ? 1.2 + mr() * 2 : 3 + mr() * 3;
    blob(g, x0, y0, s * 4, c, 0.35); blob(g, x0, y0, s, [255, 255, 255], 0.9);
  }

  // keep the light out of the sockets (the live node sits there), then re-light their rims
  g.save(); g.globalCompositeOperation = 'destination-out';
  sockets.forEach(s => { if (s.cx) { g.beginPath(); g.arc(s.cx, s.cy, s.rr + 6, 0, 7); g.fill(); } }); g.restore();
  sockets.forEach(s => {
    if (s.tip) { blob(g, s.tip[0], s.tip[1], 9, s.c, 0.9); return; }
    g.save(); g.strokeStyle = rgba(s.c, 0.22); g.lineWidth = 4; g.beginPath(); g.arc(s.cx, s.cy, s.rr + 7, 0, 7); g.stroke(); g.restore();
  });
  // bloom the light layer onto the art
  o.save(); o.globalCompositeOperation = 'lighter'; o.globalAlpha = 0.85; o.drawImage(glow, 0, 0); o.restore();
  bloom(out, glow, [5, 18, 55, 140], [0.5, 0.38, 0.3, 0.22]);
  // re-seat the sockets after the bloom: a clean dark well for the live node, faintly tinted by its colour
  sockets.forEach(s => {
    if (!s.cx) return;
    o.save(); o.beginPath(); o.arc(s.cx, s.cy, s.rr - 7, 0, 7); o.clip();
    const sg = o.createRadialGradient(s.cx - 14, s.cy - 18, 4, s.cx, s.cy, s.rr - 7);
    sg.addColorStop(0, rgba(mix(DARK, s.c, 0.16), 0.9)); sg.addColorStop(0.75, rgba(DARK, 0.88)); sg.addColorStop(1, rgba(mix(DARK, s.c, 0.3), 0.7));
    o.fillStyle = sg; o.fillRect(s.cx - s.rr, s.cy - s.rr, s.rr * 2, s.rr * 2); o.restore();
  });
  window.__last = out;
  return out;
};

// The Multiverse rift: a tear in space the late layers hover around, with the corrupted crystal outcrop.
async function rift(o, g, R, api) {
  const cx = 3150, top = 1000, bot = 1960, n = makeNoise(77), r = rng(78);
  const half = y => { const t = (y - top) / (bot - top); return 205 * Math.pow(Math.sin(Math.PI * clamp(t)), 0.75) * (1 + 0.12 * Math.sin(t * 9)); };
  const L = [], Rr = [];
  for (let y = top; y <= bot; y += 6) { const h = half(y); const j = 30 * n(y / 90, 1) + 5 * n(y / 34, 2); L.push([cx - h + j + 30 * Math.sin(y / 300), y]); Rr.push([cx + h + j * 0.8 + 30 * Math.sin(y / 300), y]); }
  const shape = [...L, ...Rr.reverse()];
  // spacetime warp rings around it
  for (let i = 0; i < 9; i++) { o.save(); o.strokeStyle = `rgba(255,${90 + i * 10},${120 + i * 6},${0.10 - i * 0.008})`; o.lineWidth = 2; o.beginPath(); o.ellipse(cx + 10, (top + bot) / 2, 320 + i * 60, 560 + i * 55, 0.04, 0, 7); o.stroke(); o.restore(); }
  blob(o, cx, 1480, 820, [120, 20, 60], 0.4);
  // interior: swirling other-universe
  const bw = 700, bh = bot - top + 40, bx = cx - bw / 2, by = top - 20;
  const ic = canvas(bw, bh), ix = ctx(ic), img = ix.createImageData(bw, bh), d = img.data, n2 = makeNoise(79);
  for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) {
    const u = (x - bw / 2) / 250, v = (y - bh / 2) / 650; const rad = Math.hypot(u, v * 1.6), ang = Math.atan2(v, u);
    const sw = fbm(n2, Math.cos(ang + rad * 2.2) * rad * 2.4 + 5, Math.sin(ang + rad * 2.2) * rad * 2.4 + 5, 5);
    const k = clamp(0.5 + sw * 1.3); const core = Math.exp(-rad * rad * 3.5);
    const i = (y * bw + x) * 4;
    d[i] = clamp(0.06 + k * 0.5 + core * 0.4) * 255; d[i + 1] = clamp(0.02 + k * k * 0.18 + core * 0.25) * 255; d[i + 2] = clamp(0.10 + k * 0.32 + core * 0.35) * 255; d[i + 3] = 255;
  }
  ix.putImageData(img, 0, 0);
  // inner stars
  for (let i = 0; i < 260; i++) { const x = r() * bw, y = r() * bh; ix.fillStyle = `rgba(255,${200 + r() * 55},${200 + r() * 55},${0.4 + r() * 0.6})`; ix.beginPath(); ix.arc(x, y, r() * 1.8 + 0.3, 0, 7); ix.fill(); }
  o.save(); poly(o, shape); o.clip(); o.drawImage(ic, bx, by); o.restore();
  // hot edges
  for (const [lw, c, a, tgt] of [[26, [255, 46, 99], 0.55, g], [12, [255, 90, 31], 0.9, g], [5, [255, 200, 150], 1, o], [1.6, [255, 255, 255], 1, o]]) {
    tgt.save(); tgt.lineJoin = 'round'; poly(tgt, shape); tgt.strokeStyle = rgba(c, a); tgt.lineWidth = lw; tgt.stroke(); tgt.restore();
  }
  g.save(); poly(g, shape); g.clip(); g.filter = 'blur(18px)'; poly(g, shape); g.strokeStyle = 'rgba(255,60,110,0.3)'; g.lineWidth = 46; g.stroke(); g.restore();
  // edge filaments leaking out
  for (let i = 0; i < 70; i++) {
    const side = r() < 0.5 ? L : Rr; const p = side[Math.floor(r() * side.length)]; const dir = side === L ? -1 : 1;
    const len = 20 + r() * 90; g.save(); g.strokeStyle = rgba(r() < 0.5 ? [255, 90, 31] : [255, 46, 99], 0.5 + r() * 0.4); g.lineWidth = 1 + r() * 2;
    g.beginPath(); g.moveTo(p[0], p[1]); g.quadraticCurveTo(p[0] + dir * len * 0.5, p[1] + (r() - 0.5) * 40, p[0] + dir * len, p[1] + (r() - 0.5) * 80); g.stroke(); g.restore();
  }
  // debris drawn toward the rift
  for (let i = 0; i < 26; i++) {
    const a = r() * Math.PI * 2, dist = 330 + r() * 420; const x = cx + Math.cos(a) * dist * 0.8, y = 1480 + Math.sin(a) * dist * 1.0;
    if (y < 180 || y > 2080) continue;
    const s = 5 + r() * 15; const trailA = Math.atan2(1480 - y, cx - x);
    { const tg = g.createLinearGradient(x, y, x - Math.cos(trailA) * s * 3, y - Math.sin(trailA) * s * 3); tg.addColorStop(0, 'rgba(255,120,80,0.28)'); tg.addColorStop(1, 'rgba(255,120,80,0)'); g.save(); g.strokeStyle = tg; g.lineWidth = s * 0.5; g.lineCap = 'round'; g.beginPath(); g.moveTo(x, y); g.lineTo(x - Math.cos(trailA) * s * 3, y - Math.sin(trailA) * s * 3); g.stroke(); g.restore(); }
    o.save(); o.translate(x, y); o.rotate(r() * 7); o.beginPath(); const k = 5 + Math.floor(r() * 3);
    for (let j = 0; j < k; j++) { const aa = j / k * 7; const rr = s * (0.6 + r() * 0.5); j ? o.lineTo(Math.cos(aa) * rr, Math.sin(aa) * rr) : o.moveTo(Math.cos(aa) * rr, Math.sin(aa) * rr); }
    o.closePath(); o.fillStyle = '#1a0d2a'; o.fill(); o.strokeStyle = 'rgba(255,140,100,0.7)'; o.lineWidth = 1.5; o.stroke(); o.restore();
  }
  // floating platforms for PEP (left of rift), PM (below, inside), EX (top)
  const plat = (x, y, w, c, seed) => {
    const rr = rng(seed), pts = [];
    for (let i = 0; i <= 24; i++) { const t = i / 24; pts.push([x - w + t * w * 2, y + 6 * Math.sin(t * 9 + seed)]); }
    for (let i = 24; i >= 0; i--) { const t = i / 24; pts.push([x - w * 0.95 + t * w * 1.9, y + 14 + w * 0.9 * Math.pow(Math.sin(Math.PI * t), 1.5) * (0.6 + rr() * 0.5)]); }
    o.save(); poly(o, pts); const gr = o.createLinearGradient(0, y, 0, y + w); gr.addColorStop(0, '#3a2250'); gr.addColorStop(1, '#0c0616'); o.fillStyle = gr; o.fill(); o.restore();
    o.save(); o.beginPath(); for (let i = 0; i <= 24; i++) i ? o.lineTo(...pts[i]) : o.moveTo(...pts[i]); o.strokeStyle = rgba(c, 0.9); o.lineWidth = 3; o.stroke(); o.restore();
    g.save(); g.beginPath(); for (let i = 0; i <= 24; i++) i ? g.lineTo(...pts[i]) : g.moveTo(...pts[i]); g.strokeStyle = rgba(c, 0.6); g.lineWidth = 9; g.stroke(); g.restore();
  };
  const halo = (k, rr) => { const [x, y, h] = NODES[k]; const c = hex(h); blob(g, x, y, rr * 2.1, c, 0.3); for (const [lw, a] of [[6, 0.5], [2, 0.95]]) { g.save(); g.strokeStyle = rgba(c, a); g.lineWidth = lw; g.beginPath(); g.arc(x, y, rr, 0, 7); g.stroke(); g.restore(); } o.save(); o.strokeStyle = rgba(hex(h), 0.35); o.setLineDash([3, 9]); o.lineWidth = 2; o.beginPath(); o.arc(x, y, rr + 16, 0, 7); o.stroke(); o.restore(); };
  plat(2790, 1262, 140, hex('f2b04d'), 5);
  [[2790, 1302], [2975, 1300]].forEach(([x, y], i) => { const rr = rng(80 + i); for (let j = 0; j < 3; j++) { /* amber crystals */ } });
  plat(3150, 862, 130, hex('45e07f'), 9);
  api.cradle(o, 'pep', 84, 811); api.cradle(o, 'ex', 84, 812); api.cradle(o, 'pm', 84, 813);
  // PM floats in the core with orbit rings
  for (let i = 0; i < 3; i++) { g.save(); g.strokeStyle = `rgba(255,46,99,${0.5 - i * 0.12})`; g.lineWidth = 2; g.beginPath(); g.ellipse(3150, 1560, 150 + i * 34, 44 + i * 12, -0.18, 0, 7); g.stroke(); g.restore(); }

  // corrupted crystal outcrop (CR + CM), rendered then glitched
  const cc = canvas(), c2 = ctx(cc), cg = canvas(), g2 = ctx(cg);
  {
    const green = hex('39ff14'), dg = hex('1fbf4a');
    // floating shard rock
    const pts = []; const n3 = makeNoise(88);
    for (let i = 0; i <= 40; i++) { const t = i / 40; pts.push([3390 + t * 430, 1285 + 12 * n3(t * 6, 1) - (t > 0.55 ? (t - 0.55) * 90 : 0)]); }
    for (let i = 40; i >= 0; i--) { const t = i / 40; pts.push([3400 + t * 410, 1285 + 330 * Math.pow(Math.sin(Math.PI * t), 1.3) * (0.7 + 0.3 * (0.5 + n3(t * 12, 5)))]); }
    c2.save(); poly(c2, pts); const gr = c2.createLinearGradient(0, 1280, 0, 1640); gr.addColorStop(0, '#12301a'); gr.addColorStop(0.2, '#0b1a10'); gr.addColorStop(1, '#030805'); c2.fillStyle = gr; c2.fill(); c2.restore();
    c2.save(); c2.beginPath(); for (let i = 0; i <= 40; i++) i ? c2.lineTo(...pts[i]) : c2.moveTo(...pts[i]); c2.strokeStyle = rgba(green, 0.9); c2.lineWidth = 3; c2.stroke(); c2.restore();
    // a spire rising to CM
    const spire = [[3630, 1262], [3668, 1030], [3690, 1012], [3712, 1032], [3752, 1250]];
    c2.save(); poly(c2, spire); const sg = c2.createLinearGradient(3560, 0, 3680, 0); sg.addColorStop(0, '#1d5a2a'); sg.addColorStop(0.5, '#0e2a15'); sg.addColorStop(1, '#051008'); c2.fillStyle = sg; c2.fill(); c2.strokeStyle = rgba(green, 0.7); c2.lineWidth = 2; c2.stroke(); c2.restore();
    // crystals: saw-toothed, sharp, green
    const rc = rng(90);
    const shard = (x, y, h, w, a, c) => {
      c2.save(); c2.translate(x, y); c2.rotate(a);
      c2.beginPath(); c2.moveTo(-w / 2, 0); c2.lineTo(-w * 0.3, -h * 0.7); c2.lineTo(0, -h); c2.lineTo(w * 0.35, -h * 0.62); c2.lineTo(w / 2, 0); c2.closePath();
      const gg = c2.createLinearGradient(-w / 2, 0, w / 2, -h); gg.addColorStop(0, rgba(mix(c, DARK, 0.7))); gg.addColorStop(0.55, rgba(c, 0.95)); gg.addColorStop(1, rgba(mix(c, [255, 255, 255], 0.6))); c2.fillStyle = gg; c2.fill();
      c2.strokeStyle = rgba(mix(c, [255, 255, 255], 0.5), 0.9); c2.lineWidth = 1.2; c2.stroke();
      c2.restore();
      g2.save(); g2.translate(x, y); g2.rotate(a); g2.fillStyle = rgba(c, 0.55); g2.beginPath(); g2.moveTo(-w / 2, 0); g2.lineTo(0, -h); g2.lineTo(w / 2, 0); g2.fill(); g2.restore();
    };
    for (let i = 0; i < 22; i++) { const x = 3400 + rc() * 400; if (Math.abs(x - 3510) < 80 || Math.abs(x - 3690) < 60) continue; shard(x, 1285 - (x > 3627 ? (x - 3627) * 0.2 : 0), 30 + rc() * 110, 12 + rc() * 22, (rc() - 0.5) * 0.9, rc() < 0.7 ? green : dg); }
    for (let i = 0; i < 7; i++) shard(3632 + rc() * 116, 1245 - rc() * 130, 30 + rc() * 50, 10 + rc() * 14, (rc() - 0.5) * 1.4, green);
    // CR cradle: a jagged ring
    for (const k of ['cr', 'cm']) {
      const [x, y] = NODES[k]; blob(g2, x, y, 170, green, 0.14);
      const sg = c2.createRadialGradient(x - 16, y - 20, 10, x, y, 96); sg.addColorStop(0, 'rgba(14,40,20,0.95)'); sg.addColorStop(0.85, 'rgba(3,10,5,0.97)'); sg.addColorStop(1, 'rgba(3,10,5,0)');
      c2.fillStyle = sg; c2.beginPath(); c2.arc(x, y, 96, 0, 7); c2.fill();
      c2.save(); c2.strokeStyle = rgba(mix(green, [255, 255, 255], 0.2), 0.9); c2.lineWidth = 2; c2.beginPath();
      for (let i = 0; i <= 72; i++) { const a = i / 72 * Math.PI * 2, rr = 86 + (i % 2 ? 4 : -2) + (i % 9 === 0 ? 8 : 0); i ? c2.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr) : c2.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
      c2.closePath(); c2.stroke(); c2.restore();
      api.sockets.push({ cx: x, cy: y, rr: 84, c: green });
    }
  }
  // glitch: slice bands and shift them, plus RGB split
  const gl = canvas(), gx = ctx(gl);
  gx.drawImage(cc, 0, 0);
  const rg = rng(91);
  for (let i = 0; i < 9; i++) {
    const y = 820 + rg() * 800, h = 2 + rg() * 12, dx = (rg() - 0.5) * 34;
    gx.clearRect(3330, y, 510, h); gx.drawImage(cc, 3330, y, 510, h, 3330 + dx, y, 510, h);
  }
  o.save(); o.globalCompositeOperation = 'lighter'; o.globalAlpha = 0.35;
  o.filter = 'blur(0.5px)';
  const tint = (c, dx) => { const t = canvas(), tx = ctx(t); tx.drawImage(gl, 0, 0); tx.globalCompositeOperation = 'source-in'; tx.fillStyle = c; tx.fillRect(0, 0, W, H); o.drawImage(t, dx, 0); };
  tint('#ff0040', -5); tint('#00e5ff', 5);
  o.restore();
  o.drawImage(gl, 0, 0);
  g.drawImage(cg, 0, 0);
}
