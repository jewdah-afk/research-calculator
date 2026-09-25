// Parallax 1 — Far nebula clouds (f 0.12, transparent). Contract: realm.json layers[id="clouds"], REALM.md 3, 4, 8.
//
// A second, slightly faster sky between the stars and the islands. Horizontal strata so the parallax reads:
//   * an upper deck of combed, cirrus-like nebula streams, broken around the cosmic sun so its light pours through;
//   * crepuscular rays fanning from the sun (upper left) through the gaps — a real transmittance march toward the
//     sun through the cloud density, so every shaft and every shadow comes from a cloud;
//   * a calm middle band (y 0.35–0.65 h) that only carries veils, faint trails and rays, alpha < 0.25 by contract;
//   * a sea of cumulus rows below, receding upward, each puff shaded as a soft sphere under the contract's key light
//     (world.js LIGHT, upper left) with a silver lining, bellies thinning so the rows layer;
//   * on the realm side (weight GR, 1 left of the sun, 0 by splitX) the key light is gold: the rays and the sun-facing
//     linings are tinted (255, 214, 150) at the same luminance as before, and that warm light is treated as emissive
//     (kept out of the haze / desaturation, hue-preserving roll-off) so it survives the atmosphere pass;
//   * past splitX, the Multiverse side: a towering crimson cumulus wall (anvil in the deck, base in the sea, a hazy
//     column between), rimmed on the side facing the tear by the rift's crimson light, and a faint glow behind it.
// The contract's atmosphere recipe (saturation, contrast, haze toward hazeColor -> hazeRift, maxLuma with emissive
// rims / rays / glow up to emissiveMax, gaussian blur in premultiplied alpha) is applied as the final pass.
//
// Output: the HIGH texture, size × res.HIGH = 1128×672 px, straight (unpremultiplied) RGBA. Geometry is in layer-local
// px (3008×1792): the composition is designed in the 2784×1632 frame the layer had before the pan margin (REALM.md 2.5),
// centred in it (DX, DY); the streams, the cumulus rows and the sea's floor already ran past that frame's edges, so
// they fill the margin. The drifting nebula_wisp sprites add motion on top of this.
LAYERS.clouds = async function () {
  // ---- contract (mirrors realm.json; window.REALM wins when a pipeline injects the manifest) ----------------------
  const SPEC = {
    size: [3008, 1792], frame: [2784, 1632], res: 0.375, anchor: [1504, 896],
    biomeLocal: { splitX: 1455.6, fadeHalfWidth: 810 },
    rift: [1539.6, 840], tree: [1341.6, 800.4],
    atmosphere: { hazeColor: [72, 54, 150], hazeRift: [120, 36, 80], haze: 0.35, hazeBottom: 0.1, saturation: 0.8,
      contrast: 0.55, blur: 6, maxLuma: 0.55, emissiveMax: 0.7 },
    band: [0.35, 0.65], bandAlpha: 0.25, maxAlpha: 0.55,
    // the sky's sun (0.36 w, 0.26 h of the sky's 2656×1536 design frame, relative to its anchor, which is the frame's
    // centre) seen through this layer at C = world centre
    sunSky: [0.36 * 2656 - 1328, 0.26 * 1536 - 768],
  };
  const RL = typeof window !== 'undefined' && window.REALM && window.REALM.layers && window.REALM.layers.find(l => l.id === 'clouds');
  if (RL) {
    SPEC.size = RL.size; SPEC.res = RL.res.HIGH; SPEC.anchor = RL.anchor; SPEC.biomeLocal = RL.biomeLocal;
    SPEC.rift = RL.landmarks.rift; SPEC.tree = RL.landmarks.tree; SPEC.atmosphere = RL.atmosphere;
  }
  const [LW, LH] = SPEC.size, RES = SPEC.res, [LW0, LH0] = SPEC.frame, DX = (LW - LW0) / 2, DY = (LH - LH0) / 2;
  const TW = Math.round(LW * RES), TH = Math.round(LH * RES), N = TW * TH;
  const SX = SPEC.anchor[0] + SPEC.sunSky[0], SY = SPEC.anchor[1] + SPEC.sunSky[1];   // ≈ (1020, 447)
  const [RX, RY] = SPEC.rift;
  const KX = (SPEC.tree[0] + RX) / 2, KY = (SPEC.tree[1] + RY) / 2;
  const SPLIT = SPEC.biomeLocal.splitX, FHW = SPEC.biomeLocal.fadeHalfWidth, AT = SPEC.atmosphere;
  const BY0 = SPEC.band[0] * LH0 + DY, BY1 = SPEC.band[1] * LH0 + DY;   // the calm band stays behind the nodes

  // ---- helpers (kept local: lib.js is shared) -----------------------------------------------------------------------
  const lin = c => [Math.pow(c[0] / 255, 2.2), Math.pow(c[1] / 255, 2.2), Math.pow(c[2] / 255, 2.2)];
  const mix3 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  const nA = makeNoise(3101), nC = makeNoise(3303), nH = makeNoise(3808);

  // ---- pass A: cloud density from designed puffs --------------------------------------------------------------------
  // Clouds are unions of soft ellipses ("puffs") with noise-torn edges, placed by hand-tuned rules: cumulus rows for
  // the sea (round tops, sharp valleys between puffs, small puffs riding on big ones), chains of flat lenses for the
  // upper streamers, a stacked tower + anvil for the crimson wall. Designed shapes read better than thresholded
  // noise at this texture size (1 texel = 2.7 local px, then blurred).
  const D = new Float32Array(N), OP = new Float32Array(N), HR = new Float32Array(N), GR = new Float32Array(N);
  const P = [], pr = rng(5150);
  // puffs are placed in design-frame coordinates (the rules below) and stored in layer px
  const puff = (x, y, rx, ry, op, soft, kind) => P.push({ x: x + DX, y: y + DY, rx, ry, op, soft, kind });
  // upper deck streamers: [x0, x1, y0, half thickness, tilt]. The gap below-right of the sun lets its light fall
  // through the middle band as rays; the streamer ends near it catch the rim light.
  const STREAM = [
    [-260, 560, 150, 40, 0.02], [-160, 900, 318, 52, -0.03], [120, 770, 470, 30, 0.015], [620, 1560, 200, 34, -0.02],
    [1190, 2420, 380, 56, -0.035], [1340, 2200, 520, 24, 0.01], [1580, 3000, 226, 60, 0.02], [2200, 3000, 470, 36, -0.01],
  ];
  for (const [x0, x1, y0, h, tl] of STREAM) {
    const xm = (x0 + x1) / 2;
    for (let x = x0; x < x1;) {
      const t = (x - x0) / (x1 - x0), env = Math.pow(Math.sin(Math.PI * clamp(t)), 0.8);
      const rx = (90 + 170 * pr()) * (0.5 + 0.5 * env), ry = h * (0.22 + 0.4 * pr()) * env + 5;
      puff(x + rx * 0.5, y0 + tl * (x - xm) + (pr() - 0.5) * h * 0.9, rx, ry, (0.45 + 0.4 * pr()) * (0.5 + 0.5 * env), 0.75, 0);
      x += rx * (0.35 + 0.35 * pr());
    }
  }
  // two faint, broken trails across the middle band (alpha stays far under the band's 0.25)
  for (const [x0, x1, y0, h] of [[-100, 820, 700, 30], [1480, 2080, 940, 20], [300, 1200, 1010, 22]]) {
    for (let x = x0; x < x1;) { const rx = 110 + 140 * pr(); if (pr() < 0.75) puff(x + rx * 0.5, y0 + (pr() - 0.5) * 20, rx, h * (0.6 + 0.6 * pr()), 0.22, 0.85, 3); x += rx * (0.7 + 0.5 * pr()); }
  }
  // the sea: rows of cumulus receding upward (smaller, flatter, fainter), drawn back to front so each row's lit
  // tops stand on the shaded, fading bellies of the row behind; small puffs ride on the big ones
  const ROWS = [[1108, 28, 70, 0.55, 0.6], [1196, 48, 130, 0.8, 0.68], [1310, 80, 190, 0.95, 0.74], [1460, 120, 260, 1, 0.8]];
  ROWS.forEach(([y0, r0, r1, op, flat], ri) => {
    for (let x = -160; x < LW0 + 160;) {
      const r = r0 + (r1 - r0) * Math.pow(pr(), 1.6), gap = ri < 2 && pr() < 0.2;
      if (!gap) {
        const yy = y0 + (pr() - 0.45) * r * 0.7;
        puff(x, yy + r * 0.35, r * (1.05 + 0.5 * pr()), r * flat, op, 0.28, 1);
        if (r > 45) for (let q = 0, nq = 1 + (pr() * 2.6 | 0); q < nq; q++) {
          const rr = r * (0.3 + 0.32 * pr());
          puff(x + (pr() - 0.5) * r * 1.5, yy + r * 0.35 - r * flat * (0.5 + 0.4 * pr()), rr * 1.1, rr * (flat + 0.1), op, 0.28, 1);
        }
      }
      x += r * (0.75 + 0.6 * pr());
    }
  });
  // the crimson wall: base in the sea, a hazy column through the band, a tower and an anvil in the deck
  for (let n = 0; n < 16; n++) { const r = 120 + 110 * pr(); puff(1980 + pr() * 900, 1180 + pr() * 280, r * 1.1, r * 0.8, 1, 0.3, 2); }
  for (let n = 0; n < 24; n++) { const r = 70 + 80 * pr(); puff(2200 + pr() * 680, 600 + pr() * 540, r, r * 1.05, 0.3, 0.5, 2); }
  for (let n = 0; n < 16; n++) { const r = 100 + 100 * pr(); puff(1990 + pr() * 900, 290 + pr() * 300, r * 1.05, r * 0.85, 1, 0.3, 2); }
  for (let n = 0; n < 12; n++) { const r = 170 + 140 * pr(); puff(1700 + pr() * 1200, 170 + pr() * 150, r * 1.3, r * 0.34, 0.9, 0.45, 2); }
  // rasterise back to front: "over" compositing of torn ellipses, each shaded as a soft sphere lit from the sun
  // (upper left) and, on the rift side, from the tear. Channels are premultiplied by coverage.
  const LS = new Float32Array(N), RS = new Float32Array(N), LR = new Float32Array(N), RR = new Float32Array(N), AO = new Float32Array(N);
  const nEdge = makeNoise(3010), nBump = makeNoise(3020), nFib = makeNoise(3030);
  for (const q of P) {
    const bx = q.rx * 1.35, by = q.ry * 1.35;
    const i0 = Math.max(0, Math.floor((q.x - bx) * RES)), i1 = Math.min(TW - 1, Math.ceil((q.x + bx) * RES));
    const j0 = Math.max(0, Math.floor((q.y - by) * RES)), j1 = Math.min(TH - 1, Math.ceil((q.y + by) * RES));
    const hz = q.kind === 0 || q.kind === 3;
    // key light: the contract's directional LIGHT (world.js), bent 25% toward the sun so puffs beside it glow on that side
    const sdx = SX - q.x, sdy = SY - q.y, sl = Math.hypot(sdx, sdy) || 1;
    let lx = -0.45 * 0.75 + 0.25 * 0.77 * sdx / sl, ly = -0.62 * 0.75 + 0.25 * 0.77 * sdy / sl, lz = 0.64;
    { const ll = Math.hypot(lx, ly, lz); lx /= ll; ly /= ll; lz /= ll; }
    const rdx = RX - q.x, rdy = RY - q.y, rl = Math.hypot(rdx, rdy, 300), mx = rdx / rl, my = rdy / rl, mz = 300 / rl;
    for (let j = j0; j <= j1; j++) for (let i = i0; i <= i1; i++) {
      const x = (i + 0.5) / RES, y = (j + 0.5) / RES, ex = (x - q.x) / q.rx, ey = (y - q.y) / q.ry, e = Math.sqrt(ex * ex + ey * ey);
      if (e > 1.35) continue;
      const xd = x - DX, yd = y - DY;   // noise registered to the design frame
      const tear = hz ? fbm(nEdge, xd / 330, yd / 55, 4) : fbm(nEdge, xd / 110, yd / 110, 4);
      let v = smooth(1, 1 - q.soft, e + (hz ? 0.8 : 0.55) * tear) * q.op;
      if (q.kind === 1 || q.kind === 2) v *= 1 - 0.55 * smooth(-0.1, 1, ey);   // bellies thin out: rows layer
      if (hz) v *= clamp(0.5 + 1.2 * (fbm(nFib, xd / 460 + (q.x - DX) * 0.001, yd / 24, 3) + 0.2));   // combed cirrus fibres
      if (v <= 0.002) continue;
      // sphere normal, roughened
      const ee = Math.min(e, 0.999), bz = fbm(nBump, xd / 60, yd / 60, 3) * 0.35;
      let nx = ex * 0.95 + bz, ny = ey * 0.95 - bz * 0.5, nz = Math.sqrt(1 - ee * ee) * (hz ? 0.6 : 1) + 0.05;
      const nl = Math.hypot(nx, ny, nz); nx /= nl; ny /= nl; nz /= nl;
      const lam = clamp((nx * lx + ny * ly + nz * lz + 0.3) / 1.3), rim = smooth(0.55, 1.05, e) * clamp((nx * lx + ny * ly) * 1.4);
      const lamR = clamp(nx * mx + ny * my + nz * mz), rimR = smooth(0.5, 1.05, e) * clamp((nx * mx + ny * my) * 1.4);
      const ao = 1 - 0.45 * smooth(-0.3, 1, ey);
      const k = j * TW + i, w = 1 - v;
      D[k] = v + D[k] * w; LS[k] = lam * v + LS[k] * w; RS[k] = rim * v + RS[k] * w;
      LR[k] = lamR * v + LR[k] * w; RR[k] = rimR * v + RR[k] * w; AO[k] = ao * v + AO[k] * w;
    }
  }
  // interior texture, the sea's floor, veils; biome weight
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES;
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, k = j * TW + i, xd = x - DX, yd = y - DY;   // design-frame coordinates
      const wx = fbm(nA, xd / 900, yd / 420, 3);
      const floor = smooth(1480, 1640, yd + 60 * wx) * 0.95;
      const veil = smooth(0.0, 0.32, fbm(nH, xd / 1300 + wx, yd / 280, 4)) * 0.3 * (1 - smooth(1000, 1150, yd));
      const tex = 0.78 + 0.4 * fbm(nC, xd / 260 + wx, yd / 120, 4);
      if (floor > D[k]) { const add = floor - D[k]; D[k] = floor; LS[k] += 0.55 * add; AO[k] += 0.6 * add; }
      const tt = Math.min(tex, 1 / Math.max(D[k], 1e-3));
      D[k] *= tt; LS[k] *= tt; RS[k] *= tt; LR[k] *= tt; RR[k] *= tt; AO[k] *= tt;
      OP[k] = veil;
      HR[k] = smooth(SPLIT - FHW, SPLIT + FHW, x + 120 * wx);
      GR[k] = 1 - smooth(SPLIT - 380, SPLIT - 20, x + 60 * wx);   // gold key light: realm side only, gone by splitX
    }
  }
  const at = (A, x, y) => { // bilinear in local px
    const fx = clamp(x * RES - 0.5, 0, TW - 1.001), fy = clamp(y * RES - 0.5, 0, TH - 1.001), ix = fx | 0, iy = fy | 0, ax = fx - ix, ay = fy - iy;
    const k = iy * TW + ix;
    return (A[k] * (1 - ax) + A[k + 1] * ax) * (1 - ay) + (A[k + TW] * (1 - ax) + A[k + TW + 1] * ax) * ay;
  };

  // ---- pass B: transmittance toward the sun (lit tops, shaded bellies, shafts) and toward the rift ----------------
  const TS = new Float32Array(N), TR = new Float32Array(N);
  const march = (x, y, lx, ly, maxL, steps, kappa) => {
    const dx = lx - x, dy = ly - y, d = Math.hypot(dx, dy) || 1, L = Math.min(d, maxL), st = L / steps;
    let tau = 0;
    for (let s = 1; s <= steps; s++) { const t = (s - 0.5) * st / d; tau += at(D, x + dx * t, y + dy * t); }
    return Math.exp(-tau * st * kappa);
  };
  for (let j = 0; j < TH; j++) for (let i = 0; i < TW; i++) {
    const x = (i + 0.5) / RES, y = (j + 0.5) / RES, k = j * TW + i;
    TS[k] = march(x, y, SX, SY, 1600, 40, 0.0042);
    TR[k] = HR[k] > 0.02 ? march(x, y, RX, RY, 900, 24, 0.0055) : 0;
  }

  // ---- pass C: light and alpha (premultiplied, linear) --------------------------------------------------------------
  // 2.5D shading: a blurred copy of the density is a height map; its normals, lit from the sun's direction (and on the
  // rift side from the tear), give each puff a round, lit shoulder. The transmittance march adds cast shadows.
  const PR = new Float32Array(N), PG = new Float32Array(N), PB = new Float32Array(N), PA = new Float32Array(N), EM = new Float32Array(N),
    GW = new Float32Array(N);   // share of the pixel's light that is the gold key light (rays + linings, realm side)
  const llum = c => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  const SHADE = lin([86, 64, 170]), SHADE_R = lin([84, 18, 54]), LILAC = lin([226, 208, 255]), LIT_R = lin([255, 84, 128]),
    WARM = lin([255, 210, 150]), SILVER = lin([236, 226, 255]), RAY = lin([255, 222, 190]), RAY_FAR = lin([214, 186, 255]),
    RAY_GOLD = lin([255, 214, 150]), RAY_ROSE = lin([255, 180, 190]), AUR = lin([255, 204, 136]), CRIM = lin([255, 46, 99]),
    MAG = lin([232, 70, 190]), GLOW = lin([255, 60, 118]), VEIL = lin([150, 128, 230]);
  const nR = makeNoise(3909);
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES;
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, k = j * TW + i;
      const d = D[k], hr = HR[k], gr = GR[k], ts = TS[k], id = 1 / Math.max(d, 1e-4);
      const dx = x - SX, dy = y - SY, ds = Math.hypot(dx, dy) || 1, dr = Math.hypot(x - RX, (y - RY) * 1.1) || 1;
      const lam = LS[k] * id, rim = RS[k] * id, lamR = LR[k] * id, rimR = RR[k] * id, ao = AO[k] * id;
      // sun: lambert on the puff, cast shadows from the march, a warm silver lining on the sun-facing rim
      const near = 1 / (1 + (ds / 950) * (ds / 950));
      const Ls = (0.45 + 0.55 * ts) * (0.6 + 0.4 * near);
      // keep-clear (advisory): no bright crests behind the node cluster (tree + rift landmarks, soft-zone union)
      const kc = 1 - 0.4 * Math.exp(-((x - KX) / 640) * ((x - KX) / 640) - ((y - KY) / 440) * ((y - KY) / 440));
      // aureole: gas and cloud right around the sun forward-scatter its gold light (a hue shift at equal luminance, so
      // the sun seen through this layer stays gold instead of going lilac); emissive above the calm band only
      const aur = gr * Math.exp(-(ds / 300) * (ds / 300)), aurE = aur * (1 - smooth(BY0 - 70, BY0 + 50, y));
      const warmAt = c => { const w = AUR.map(v => v * llum(c) / llum(AUR)); return mix3(c, w, 0.9 * aur); };
      const shade = mix3(SHADE, SHADE_R, hr), lit = warmAt(mix3(LILAC, LIT_R, hr * 0.85));
      // lining: gold on the realm side, a cool silver toward the rift (which the tear's crimson rim then takes over)
      const lining = mix3(SILVER, WARM, gr), linI = rim * Ls * (1.1 + 1.6 * near) * (1 - 0.55 * hr) * (1 + 0.7 * gr) * kc;
      let c = [0, 0, 0];
      for (let q = 0; q < 3; q++) c[q] = shade[q] * ao + (lit[q] - shade[q]) * lam * Ls * ao * kc + lining[q] * linI;
      // crimson light from the tear on the rift side
      const Lr = (0.35 + 0.65 * TR[k]) * hr / (1 + (dr / 850) * (dr / 850));
      const rc = mix3(CRIM, MAG, smooth(-0.2, 0.3, fbm(nR, (x - DX) / 700, (y - DY) / 700, 3)));
      for (let q = 0; q < 3; q++) c[q] += rc[q] * Lr * (0.35 * lamR + 1.6 * rimR);
      const ac = SPEC.maxAlpha * (1 - Math.exp(-2.8 * d));
      // veils: broad faint sheets
      const av = OP[k] * 0.5;
      // crepuscular rays: light through the gaps, streaked by angle, fading with distance
      const th = Math.atan2(dy, dx);
      const streaks = clamp(0.25 + 1.8 * fbm(nR, th * 4.2, 0.5, 3) + 0.45 * fbm(nR, th * 11, 9.5, 2));
      const fall = smooth(40, 260, ds) * Math.exp(-ds / 950) * (0.45 + 0.55 * smooth(SY - 260, SY + 80, y));
      // (the gold shafts are a little denser at their source, above the calm band only)
      const src = 1 + 0.6 * gr * Math.exp(-(ds / 380) * (ds / 380)) * (1 - smooth(BY0 - 90, BY0 + 30, y));
      const ar = 0.42 * Math.pow(ts, 1.5) * streaks * fall * (1 - 0.55 * hr) * src;
      // gold shafts on the realm side at the luminance the lilac ones had (the centre band gets no brighter)
      const rcool = mix3(RAY, RAY_FAR, smooth(150, 1100, ds)), rwarm = mix3(RAY_GOLD, RAY_ROSE, smooth(500, 1400, ds));
      const rcol = mix3(rcool, rwarm.map(v => v * llum(rcool) / llum(rwarm)), gr);
      // crimson glow behind the rift
      const ag = hr * (0.14 * Math.exp(-(dr / 430) * (dr / 430)) + 0.05 * Math.exp(-(dr / 950) * (dr / 950)));
      // composite: glow < veil < rays < cloud (premultiplied)
      let pr_ = GLOW[0] * ag, pg = GLOW[1] * ag, pb = GLOW[2] * ag, pa = ag;
      const vc = warmAt(mix3(VEIL, LIT_R, hr * 0.7));
      pr_ = vc[0] * av + pr_ * (1 - av); pg = vc[1] * av + pg * (1 - av); pb = vc[2] * av + pb * (1 - av); pa = av + pa * (1 - av);
      pr_ = rcol[0] * ar + pr_ * (1 - ar); pg = rcol[1] * ar + pg * (1 - ar); pb = rcol[2] * ar + pb * (1 - ar); pa = ar + pa * (1 - ar);
      pr_ = c[0] * ac + pr_ * (1 - ac); pg = c[1] * ac + pg * (1 - ac); pb = c[2] * ac + pb * (1 - ac); pa = ac + pa * (1 - ac);
      PR[k] = pr_; PG[k] = pg; PB[k] = pb; PA[k] = pa;
      const emS = rim * Ls * (0.5 + near) * 1.6 * smooth(0.02, 0.2, d);
      EM[k] = clamp(ar * 6 + ag * 5 + emS + Lr * rimR * 2 * smooth(0.02, 0.2, d));
      GW[k] = Math.max(gr * clamp(ar * 6 + emS * 1.5), aurE);
    }
  }

  // ---- pass D: the contract's atmosphere recipe on the straight colour ---------------------------------------------
  const luma = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
  const HC = AT.hazeColor.map(v => v / 255), HRC = AT.hazeRift.map(v => v / 255);
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES, kh = AT.haze + AT.hazeBottom * smooth(0.35, 1, (y - DY) / LH0);
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, k = j * TW + i, a = PA[k];
      if (a < 1e-5) { PR[k] = PG[k] = PB[k] = 0; continue; }
      // straight colour, sRGB 0..1 (tone-mapped so bright rims roll off instead of clipping; where the light is the
      // gold key light the roll-off is hue-preserving, on the max channel, so the gold does not bleach to white)
      const gw = GW[k], lr = [PR[k] / a, PG[k] / a, PB[k] / a], tm = v => 1 - Math.exp(-v * 1.25);
      const mx = Math.max(lr[0], lr[1], lr[2], 1e-6), hs = tm(mx) / mx;
      let c = lr.map(v => Math.pow(lerp(tm(v), v * hs, gw), 1 / 2.2));
      const hz = mix3(HC, HRC, smooth(SPLIT - FHW, SPLIT + FHW, x)), Lh = luma(hz[0], hz[1], hz[2]);
      const L = luma(c[0], c[1], c[2]);
      const c1 = mix3(c.map(v => L + (v - L) * AT.saturation), c, gw);   // the gold keeps its saturation
      c = mix3(c1.map(v => Lh + (v - Lh) * AT.contrast), hz, kh);
      // emissive light (rays, rims, the rift glow) is not hazed away: it keeps up to 65% of its unhazed colour (the
      // gold key light up to 90%), and only it may pass maxLuma, up to emissiveMax
      c = mix3(c, c1, Math.min(0.9, 0.65 * EM[k] + 0.6 * gw));
      const lim = lerp(AT.maxLuma, AT.emissiveMax, EM[k]), L2 = luma(c[0], c[1], c[2]), knee = lim * 0.85;
      if (L2 > knee) { const L3 = knee + (lim - knee) * (1 - Math.exp(-(L2 - knee) / (lim - knee))), s = L3 / L2; c = c.map(v => v * s); }
      PR[k] = clamp(c[0]) * a; PG[k] = clamp(c[1]) * a; PB[k] = clamp(c[2]) * a;   // back to premultiplied (sRGB)
    }
  }

  // ---- pass E: gaussian blur of `blur` local px (premultiplied), then the band / max alpha guarantees --------------
  const sig = AT.blur * RES, rad = Math.ceil(sig * 3), K = [];
  let ks = 0; for (let t = -rad; t <= rad; t++) { const w = Math.exp(-(t * t) / (2 * sig * sig)); K.push(w); ks += w; }
  for (let t = 0; t < K.length; t++) K[t] /= ks;
  const blur1 = (src, horiz) => {
    const dst = new Float32Array(N);
    for (let j = 0; j < TH; j++) for (let i = 0; i < TW; i++) {
      let s = 0;
      for (let t = -rad; t <= rad; t++) {
        const ii = horiz ? clamp(i + t, 0, TW - 1) : i, jj = horiz ? j : clamp(j + t, 0, TH - 1);
        s += src[jj * TW + ii] * K[t + rad];
      }
      dst[j * TW + i] = s;
    }
    return dst;
  };
  const [BR, BG, BB, BA] = [PR, PG, PB, PA].map(A => blur1(blur1(A, true), false));

  const out = canvas(TW, TH), o = ctx(out), img = o.createImageData(TW, TH), px = img.data;
  const dr = rng(991);
  let maxBand = 0, maxAll = 0;
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES;
    // alpha ceiling: 0.24 inside the band (with a 1-texel margin), easing up to maxAlpha outside it
    const inBand = y > BY0 - 3 && y < BY1 + 3;
    const cap = inBand ? SPEC.bandAlpha - 0.012 : lerp(SPEC.bandAlpha - 0.012, SPEC.maxAlpha, Math.min(smooth(BY0, BY0 - 110, y), 1) + smooth(BY1, BY1 + 110, y));
    for (let i = 0; i < TW; i++) {
      const k = j * TW + i;
      let a = BA[k], s = 1;
      if (a > cap) { s = cap / a; a = cap; }
      const q = k * 4, dz = () => (dr() + dr() - 1) * 0.6;
      const A8 = Math.min(clamp(Math.round(a * 255 + dz()), 0, 255), inBand ? Math.floor(SPEC.bandAlpha * 255) - 1 : Math.floor(SPEC.maxAlpha * 255));
      if (A8 === 0) { px[q] = px[q + 1] = px[q + 2] = px[q + 3] = 0; continue; }
      // straight colour, with the emissiveMax luma ceiling re-applied as a safety net after the blur and the dither
      const ia = 1 / Math.max(a, 1e-6), sr = BR[k] * s * ia, sg = BG[k] * s * ia, sb = BB[k] * s * ia;
      const sl = luma(sr, sg, sb), sc = sl > AT.emissiveMax - 0.01 ? (AT.emissiveMax - 0.01) / sl : 1;
      px[q] = clamp(Math.round(sr * sc * 255 + dz()), 0, 255);
      px[q + 1] = clamp(Math.round(sg * sc * 255 + dz()), 0, 255);
      px[q + 2] = clamp(Math.round(sb * sc * 255 + dz()), 0, 255);
      px[q + 3] = A8;
      if (y >= BY0 && y <= BY1) maxBand = Math.max(maxBand, A8 / 255);
      maxAll = Math.max(maxAll, A8 / 255);
    }
  }
  o.putImageData(img, 0, 0);
  console.log(`clouds ${TW}x${TH} max alpha ${maxAll.toFixed(3)} (cap ${SPEC.maxAlpha}), in band y ${BY0.toFixed(0)}-${BY1.toFixed(0)}: ${maxBand.toFixed(3)} (< ${SPEC.bandAlpha})`);
  window.__last = out; window.__fields = { D, TS, TR, HR, GR, EM, GW, PA, LS, RS };   // __fields: debug hook for field dumps
  return out;
};
