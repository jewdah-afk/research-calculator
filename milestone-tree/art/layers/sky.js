// Parallax 0 — Deep space (f 0.05, opaque). Contract: realm.json layers[id="sky"], REALM.md sections 3, 4 and 8.
//
// The layer barely moves (5% of the world), so it is composed like a fixed backdrop: the cosmic sun upper left at
// (0.36 w, 0.26 h) is the warm key light for the whole realm (white-gold core, gold corona turning through amber and
// rose into the violet, the realm's one gold accent in deep space); a galactic band runs through it from the lower left to the
// upper right, cut by meandering dust lanes; a calm, dim centre sits behind the tree (bright knots compressed there);
// the right third is the Multiverse bleeding into space: a torn crimson / magenta shock shell blown out around the
// rift, with ember knots on its front, dark fingers of the medium it ploughs into, and a few teal / cold-violet wisps
// of other universes inside it; a cool cyan reflection nebula glows low on the left. Dust edges facing the sun catch
// its light and the dust throws shadow rays away from it (a real transmittance march), which ties the light direction
// to the rest of the stack.
//
// Output: the HIGH texture, size × res.HIGH = 1720×1000 px (the tiler makes the LOW tier and the gutters). All geometry
// below is in layer-local px (2752×1600); the composition is designed in the 2656×1536 frame the layer had before the
// pan margin (REALM.md 2.5), centred in it (DX, DY), and the gas, dust and stars simply run on across the margin. The
// canvas is painted per texel in linear light, tone mapped, luma-clamped with the contract's maxLuma / emissiveMax and
// dithered (no banding once the client upscales and tints it).
// Bright twinkling stars are sprites (star_twinkle), so the baked star field stays faint.
LAYERS.sky = async function () {
  // ---- contract (mirrors realm.json; window.REALM wins when a pipeline injects the manifest) ----------------------
  const SPEC = {
    size: [2752, 1600], frame: [2656, 1536], res: 0.625, sun: [0.36, 0.26],   // sun: a fraction of the design frame
    biomeLocal: { splitX: 1354.5, fadeHalfWidth: 863 },
    tree: [1307, 761.5], rift: [1389.5, 778],             // landmarks: the calm centre, behind the tear
    atmosphere: { maxLuma: 0.72, emissiveMax: 0.95 },
  };
  const RL = typeof window !== 'undefined' && window.REALM && window.REALM.layers && window.REALM.layers.find(l => l.id === 'sky');
  if (RL) {
    SPEC.size = RL.size; SPEC.res = RL.res.HIGH; SPEC.biomeLocal = RL.biomeLocal; SPEC.tree = RL.landmarks.tree; SPEC.rift = RL.landmarks.rift;
    SPEC.atmosphere = RL.atmosphere;
  }
  const [LW, LH] = SPEC.size, RES = SPEC.res, [LW0, LH0] = SPEC.frame, DX = (LW - LW0) / 2, DY = (LH - LH0) / 2;
  const TW = Math.round(LW * RES), TH = Math.round(LH * RES), N = TW * TH;
  const SX = SPEC.sun[0] * LW0 + DX, SY = SPEC.sun[1] * LH0 + DY;
  const [CX, CY] = SPEC.tree;
  const SPLIT = SPEC.biomeLocal.splitX, FHW = SPEC.biomeLocal.fadeHalfWidth;
  const MAXL = SPEC.atmosphere.maxLuma, EMIS = SPEC.atmosphere.emissiveMax;

  // ---- helpers (kept local: lib.js is shared) -----------------------------------------------------------------------
  const lin = c => [Math.pow(c[0] / 255, 2.2), Math.pow(c[1] / 255, 2.2), Math.pow(c[2] / 255, 2.2)];
  const ramp = stops => { // [[t, [r,g,b]], ...] in sRGB -> function t -> linear rgb
    const S = stops.map(([t, c]) => [t, lin(c)]);
    return t => {
      if (t <= S[0][0]) return S[0][1];
      for (let i = 1; i < S.length; i++) if (t <= S[i][0]) {
        const a = S[i - 1], b = S[i], k = (t - a[0]) / (b[0] - a[0]), s = k * k * (3 - 2 * k);
        return [lerp(a[1][0], b[1][0], s), lerp(a[1][1], b[1][1], s), lerp(a[1][2], b[1][2], s)];
      }
      return S[S.length - 1][1];
    };
  };
  const mix3 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
  const g2 = (dx, dy, rx, ry) => Math.exp(-(dx * dx) / (rx * rx) - (dy * dy) / (ry * ry));

  const REALM_R = ramp([[0, [34, 20, 96]], [0.3, [96, 52, 200]], [0.6, [160, 88, 250]], [0.82, [212, 150, 255]], [1, [255, 222, 246]]]);
  const CYAN_R = ramp([[0, [16, 42, 96]], [0.35, [40, 120, 210]], [0.7, [95, 210, 255]], [1, [210, 246, 255]]]);
  const CRIM_R = ramp([[0, [60, 6, 34]], [0.3, [140, 14, 60]], [0.6, [222, 34, 92]], [0.85, [255, 70, 118]], [1, [255, 132, 158]]]);
  const MAG_R = ramp([[0, [58, 10, 64]], [0.35, [150, 32, 140]], [0.65, [226, 70, 190]], [1, [255, 186, 240]]]);
  const TEAL = lin([70, 210, 220]), EMBER = lin([255, 96, 40]), HOT = lin([255, 186, 120]), COLD = lin([120, 110, 255]);
  // the sun's light by distance (t = d / 800 local px): white-gold core, gold corona, amber, rose, then the realm's
  // violet. It turns through the warm side of the hue wheel: gold and violet are complements, so a straight mix
  // between them goes through grey-brown mud, while gold -> amber -> rose -> violet stays saturated all the way
  // (gold only where the light is bright: dim gold reads as brown, dim rose as plum, which sits well in the violet)
  const SUN_R = ramp([[0, [255, 240, 212]], [0.05, [255, 222, 150]], [0.11, [255, 198, 104]], [0.19, [255, 164, 92]],
    [0.29, [252, 150, 158]], [0.42, [232, 138, 214]], [0.6, [194, 128, 246]], [1, [170, 118, 246]]]);
  const SUNLIGHT = new Array(1601);  // tabulated per local px
  for (let d = 0; d <= 1600; d++) SUNLIGHT[d] = SUN_R(d / 800);
  const sunLight = d => SUNLIGHT[Math.min(1600, d | 0)];

  const nA = makeNoise(1101), nB = makeNoise(1202), nC = makeNoise(1303), nD = makeNoise(1404), nE = makeNoise(1505),
    nF = makeNoise(1606), nG = makeNoise(1707), nH = makeNoise(1808), nS = makeNoise(1909), nI = makeNoise(2010), nJ = makeNoise(2111), nK = makeNoise(2212);

  // galactic band axis: through the sun, rising to the right (lower left -> upper right)
  const BA = Math.atan2(-0.3, 1), CA = Math.cos(BA), SA = Math.sin(BA);
  const [RXL, RYL] = SPEC.rift;

  // ---- pass A: fields per texel ------------------------------------------------------------------------------------
  const F = {
    dens: new Float32Array(N), wisp: new Float32Array(N), dust: new Float32Array(N), band: new Float32Array(N),
    glow: new Float32Array(N), rift: new Float32Array(N), cool: new Float32Array(N), hr: new Float32Array(N),
    acc: new Float32Array(N), acc2: new Float32Array(N), calm: new Float32Array(N), bgv: new Float32Array(N),
    broad: new Float32Array(N), front: new Float32Array(N), inner: new Float32Array(N), outer: new Float32Array(N), acc3: new Float32Array(N),
  };
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES;
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, k = j * TW + i;
      const u = (x - DX) / 900, v = (y - DY) / 900;   // the noise stays registered to the design frame
      // gentle domain warp: billowing gas without the marbled look of a strong warp
      const qx = fbm(nA, u, v, 4), qy = fbm(nA, u + 5.2, v + 1.3, 4);
      const env = fbm(nB, u * 0.7 + 3.1, v * 0.7 + 7.7, 3);                      // large-scale clumping
      const g = fbm(nC, u * 1.5 + 1.25 * qx, v * 1.5 + 1.25 * qy, 7, 2.03, 0.54); // cloud detail
      // band coordinates (through the sun, rising to the right) with a wandering, breathing width
      const dx = x - SX, dy = y - SY;
      const along = dx * CA + dy * SA;
      const across = -dx * SA + dy * CA - 110 * fbm(nD, along / 1000, 3.3, 3) - 60 * qx;
      const bw = (190 + 0.1 * Math.abs(along)) * (0.85 + 0.5 * (fbm(nD, along / 700, 8.1, 2) + 0.25));
      const alongFade = 0.4 + 0.6 * Math.exp(-(along / 1450) * (along / 1450));
      const band = Math.exp(-(across * across) / (bw * bw)) * alongFade;
      const bandHalo = Math.exp(-(across * across) / (4.5 * bw * bw)) * alongFade;
      // the Multiverse complex, right third: a torn shock shell blown out around the rift (behind the tear at the
      // sky's rift landmark), visible as a luminous crimson front arcing from the upper right to the lower right
      const rdx = x - RXL, rdy = (y - RYL) * 1.12, rr = Math.hypot(rdx, rdy);
      const ca = rdx / (rr || 1), sa = rdy / (rr || 1);
      const shD = rr - 1040 - 170 * fbm(nJ, ca * 1.7 + 4.2, sa * 1.7 + 1.9, 4) - 70 * g - 40 * qy;  // < 0 inside the shell
      const arc = smooth(1620 + DX, 2150 + DX, x + 120 * env);
      const front = Math.exp(-(shD / 85) * (shD / 85)) * arc;
      const inner = smooth(-620, -30, shD) * (1 - smooth(-30, 60, shD)) * arc;
      const outer = Math.exp(-Math.max(0, shD) / 300) * smooth(-40, 40, shD) * arc;
      const rEdge = smooth(1640 + DX, 2380 + DX, x + 240 * qx + 160 * env);
      const lobes = 0.25 + 0.6 * g2(x - DX - 2380, y - DY - 280, 560, 300) + 0.55 * g2(x - DX - 2280, y - DY - 1270, 600, 330);
      const rift = rEdge * lobes;
      // cool reflection nebula low on the left
      const cool = g2(x - DX - 380 - 110 * qy, y - DY - 1220, 600, 380);
      // calm centre behind the tree, and the readable centre band (y 0.4-0.6 h)
      const calm = g2(x - CX, y - CY - 30, 760, 460);
      const midBand = g2(0, y - 0.5 * LH, 1, 0.13 * LH0);
      // hue: realm violet -> rift palette across splitX +- fadeHalfWidth (slow start so the tree side stays violet)
      const hr = Math.pow(smooth(SPLIT - FHW, SPLIT + FHW, x + 160 * env), 1.6);
      // soft gas density and fine wisps (ridged, following the warp)
      const dens = smooth(-0.3, 0.42, g + 0.35 * env);
      const wisp = Math.pow(ridged(nE, u * 2.6 + 0.9 * qx, v * 2.6 + 0.9 * qy, 5), 4.5);
      // dust: meandering lanes along the band (contour lines of stretched noise: thin, continuous, branching),
      // soft dimming in the band core, and the dark medium outside the shell with fingers reaching into the front
      const lf = fbm(nF, along / 1500 + 0.35 * qx, across / 360 + 0.35 * qy, 6, 2.1, 0.5);
      const lf2 = fbm(nK, along / 700 + 0.5 * qx + 3.3, across / 170 + 0.5 * qy + 1.1, 5, 2.1, 0.5);
      const lw = 0.03 + 0.03 * (env + 0.5);
      const lanes = (Math.exp(-((lf - 0.04) / lw) * ((lf - 0.04) / lw)) + 0.8 * Math.exp(-((lf + 0.14) / (lw * 0.8)) * ((lf + 0.14) / (lw * 0.8))) +
        0.45 * Math.exp(-((lf2 - 0.1) / (lw * 0.6)) * ((lf2 - 0.1) / (lw * 0.6))) * smooth(-0.1, 0.1, lf)) * smooth(0.12, 0.65, bandHalo);
      const bd = fbm(nI, u * 1.6 + 0.8 * qx, v * 1.6 + 0.8 * qy, 5);
      const broadD = smooth(0.0, 0.3, bd) * (0.5 * bandHalo + 0.25 * cool);
      const fing = fbm(nG, u * 3.2 + 0.7 * qx, v * 3.2 + 0.7 * qy, 5);
      const medium = smooth(-30, 170, shD + 150 * fing) * arc * (0.55 + 0.35 * smooth(-0.1, 0.25, fing));
      const tf = fbm(nK, u * 2.4 + 0.9 * qx, v * 2.4 + 0.9 * qy, 5);
      const tendr = Math.exp(-(tf / 0.045) * (tf / 0.045)) * (0.15 + 0.6 * inner + 0.4 * cool) * (0.5 + 0.5 * smooth(-0.2, 0.3, env));
      const dSun = Math.hypot(dx, dy);
      const dust = Math.min(1, Math.max(lanes * 0.8, medium, tendr * 0.7) + broadD * 0.4) * smooth(80, 280, dSun);
      F.front[k] = front; F.inner[k] = inner; F.outer[k] = outer;
      F.dens[k] = dens; F.wisp[k] = wisp; F.dust[k] = dust; F.band[k] = band; F.glow[k] = bandHalo;
      F.rift[k] = rift; F.cool[k] = cool; F.hr[k] = hr;
      F.acc[k] = smooth(-0.12, 0.22, qy * 1.4 - env * 0.9);                         // magenta vs crimson / cyan selector
      F.acc2[k] = smooth(0.3, 0.55, fbm(nH, u * 2.2 + qx, v * 2.2 - qy, 3) + 0.2);   // rare cold filaments in the rift
      F.acc3[k] = smooth(0.0, 0.28, fbm(nJ, u * 3 + 0.6 * qx + 9, v * 3 + 0.6 * qy, 4));             // ember hot spots on the front
      F.calm[k] = 1 - 0.7 * calm - 0.25 * midBand * (1 - calm);
      F.bgv[k] = env;
      F.broad[k] = smooth(-0.4, 0.35, g + 0.4 * env);
    }
  }
  // dust edge facing a light: dust here minus dust one step toward the light (ionisation / rim fronts)
  const dustAt = (x, y) => { // bilinear, texel coords
    const fx = clamp(x - 0.5, 0, TW - 1.001), fy = clamp(y - 0.5, 0, TH - 1.001), ix = fx | 0, iy = fy | 0, ax = fx - ix, ay = fy - iy;
    const k = iy * TW + ix, D = F.dust;
    return (D[k] * (1 - ax) + D[k + 1] * ax) * (1 - ay) + (D[k + TW] * (1 - ax) + D[k + TW + 1] * ax) * ay;
  };
  const rimAt = (x, y, lx, ly, step) => {
    const dx = lx - x, dy = ly - y, d = Math.hypot(dx, dy) || 1;
    return Math.max(0, dustAt(x * RES, y * RES) - dustAt((x + dx / d * step) * RES, (y + dy / d * step) * RES));
  };

  // ---- pass B: transmittance from the sun through the dust (shadow rays behind clumps) ----------------------------
  const T = new Float32Array(N);
  const STEPS = 30, KAPPA = 0.009; // optical depth per local px of full dust
  for (let j = 0; j < TH; j++) for (let i = 0; i < TW; i++) {
    const x = (i + 0.5) / RES, y = (j + 0.5) / RES, dx = SX - x, dy = SY - y, d = Math.hypot(dx, dy);
    const L = Math.min(d, 1100), st = L / STEPS;
    let tau = 0;
    for (let s = 1; s <= STEPS; s++) { const t = s * st / d; tau += dustAt((x + dx * t) * RES, (y + dy * t) * RES); }
    T[j * TW + i] = Math.exp(-tau * st * KAPPA);
  }

  // ---- pass C: light -------------------------------------------------------------------------------------------------
  // E: emissive share (lifts the luma clamp toward emissiveMax); WM: warm-light share, tone mapped hue-preserving so
  // the sun's gold survives the roll-off instead of bleaching to a grey-white (REALM.md 8: the key light is warm)
  const R = new Float32Array(N), G = new Float32Array(N), B = new Float32Array(N), E = new Float32Array(N), WM = new Float32Array(N);
  const BG_T = lin([8, 5, 17]), BG_M = lin([14, 8, 31]), BG_B = lin([26, 13, 56]), BG_R = lin([22, 6, 24]), BG_RB = lin([36, 10, 34]);
  // (near the sun the reflection haze and the lit dust rims take sunLight(d); farther out they cool to these)
  const REFL_FAR = lin([214, 150, 236]), RIM_SUN = lin([255, 190, 222]), RIM_RIFT = lin([255, 70, 110]), WHITE = [1, 1, 1];
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES, vy = y / LH;
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, k = j * TW + i;
      const hr = F.hr[k], dust = F.dust[k], calm = F.calm[k], dens = F.dens[k];
      // background: never black; deep violet, deepening toward the top, maroon on the rift side
      let bg = vy < 0.55 ? mix3(BG_T, BG_M, smooth(0, 0.55, vy)) : mix3(BG_M, BG_B, smooth(0.55, 1, vy));   // (vy: of the whole layer)
      bg = mix3(bg, mix3(BG_R, BG_RB, smooth(0.3, 1, vy)), hr * 0.85);
      const bgk = (1 + 0.6 * F.bgv[k]) * (1 - 0.45 * dust);
      // emission: soft band glow + band clouds + the rift complex + the cool nebula + faint wisps everywhere
      const band = F.band[k], halo = F.glow[k], rift = F.rift[k], cool = F.cool[k], wisp = F.wisp[k];
      const front = F.front[k], inner = F.inner[k], outer = F.outer[k];
      const riftI = 0.34 * front * (0.4 + 0.8 * dens) + 0.2 * inner * Math.pow(dens, 1.3) + 0.05 * outer * Math.pow(dens, 1.6) +
        0.22 * rift * Math.pow(dens, 1.6);
      const I = (0.1 * halo + 0.2 * band + 0.55 * band * Math.pow(dens, 1.7) + riftI +
        0.3 * cool * Math.pow(dens, 1.4) + 0.045 * Math.pow(dens, 2.2)) * calm;
      const W = wisp * (0.02 + 0.3 * band + 0.3 * rift + 0.5 * inner + 0.16 * cool) * calm;
      const t = clamp(dens * 0.55 + band * 0.25 + rift * 0.12 + front * 0.25 + wisp * 0.5);
      // colour: realm violet (+ cyan accents) -> crimson / magenta (+ rare cold filaments)
      let realm = REALM_R(t);
      realm = mix3(realm, CYAN_R(t), clamp(cool * 1.4 + halo * 0.15) * F.acc[k] * 0.9);
      let rc = mix3(CRIM_R(t), MAG_R(t), F.acc[k] * 0.55);
      rc = mix3(rc, COLD, F.acc2[k] * 0.7 * (1 - smooth(0.55, 0.95, t)));
      rc = mix3(rc, EMBER, Math.pow(F.front[k], 0.7) * F.acc3[k] * 0.8 * smooth(0.45, 0.85, t));
      let col = mix3(realm, rc, hr);
      // other universes bleeding through the torn shell: teal / cold-violet wisps inside it (restrained, wisps only)
      const wcol = mix3(TEAL, COLD, F.acc3[k]);
      const wk = clamp(F.wisp[k] * 4) * F.inner[k] * hr * clamp(F.acc2[k] * 1.4 + 0.15) * 0.8;
      col = mix3(col, wcol, wk);
      // the sun colours the gas near it (gold at the core, amber, then rose where it meets the violet)
      const dx = x - SX, dy = y - SY, dSun = Math.hypot(dx, dy), lc = sunLight(dSun);
      col = mix3(col, lc, 0.8 * Math.exp(-(dSun / 240) * (dSun / 240)) * (1 - hr));
      const absorb = Math.exp(-2.1 * dust);
      // reflection haze lit by the sun, shadowed by the dust between (T): streaming shadow rays
      const Isun = 1 / (1 + (dSun / 300) * (dSun / 300));
      const refl = 0.22 * Isun * T[k] * Math.pow(F.broad[k], 1.2) * (1 - 0.7 * dust) * (0.6 + 0.4 * calm);
      const rcol = mix3(lc, REFL_FAR, smooth(240, 560, dSun));
      // thin rim fronts: dust edges facing the sun catch its light, gold on the nearest lanes (the warm spill of the
      // key light), rose farther out; in the rift they face the tear (crimson)
      let rimS = 0, rimR = 0;
      const warmNear = Math.exp(-(dSun / 330) * (dSun / 330)) * (1 - hr);      // how much of the sun's light is still gold
      if (dust > 0.02) {
        rimS = rimAt(x, y, SX, SY, 6) * (0.4 + 0.5 * warmNear) / (1 + (dSun / 380) * (dSun / 380)) * T[k] * (1 - hr * 0.8);
        rimR = rimAt(x, y, RXL, RYL, 7) * (0.35 * rift + 1.1 * front + 0.4 * inner) * hr * calm;
      }
      const rimC = mix3(mix3(lc, WHITE, 0.14), RIM_SUN, smooth(260, 600, dSun));
      // behind the nodes, bright knots are compressed harder than the dim gas (calm, not a hole)
      const em = (I + W) / (1 + 2.2 * (1 - calm) * (I + W));
      // hot ember knots where the shell front burns brightest (their own light, not a hue shift of the pink)
      const hot = 0.75 * Math.pow(F.front[k], 1.6) * Math.pow(F.acc3[k], 1.5) * (0.25 + 0.75 * dens) * calm * Math.sqrt(absorb) * (0.4 + 0.6 * clamp(F.wisp[k] * 3));
      const hc = mix3(EMBER, HOT, smooth(0.1, 0.3, hot));
      R[k] = hc[0] * hot; G[k] = hc[1] * hot; B[k] = hc[2] * hot;
      R[k] += bg[0] * bgk + col[0] * em * absorb + rcol[0] * refl + rimC[0] * rimS + RIM_RIFT[0] * rimR;
      G[k] += bg[1] * bgk + col[1] * em * absorb + rcol[1] * refl + rimC[1] * rimS + RIM_RIFT[1] * rimR;
      B[k] += bg[2] * bgk + col[2] * em * absorb + rcol[2] * refl + rimC[2] * rimS + RIM_RIFT[2] * rimR;
      // the gold spill (lit dust edges, sunlit haze near the core) is light, not gas: emissive for the clamp
      const spill = warmNear * clamp(rimS * 9 + refl * 5);
      E[k] = Math.max(E[k], 0.6 * spill); WM[k] = Math.max(WM[k], spill);
    }
  }

  // ---- stars (splatted in linear light, dimmed by the dust in front of them) ---------------------------------------
  const r = rng(4040);
  const splat = (lx, ly, sig, c, peak, ex = 1, ey = 1, rot = 0) => {
    const tx = lx * RES, ty = ly * RES, sx = sig * ex, sy = sig * ey, rad = Math.ceil(3 * Math.max(sx, sy));
    const x0 = Math.max(0, Math.floor(tx - rad)), x1 = Math.min(TW - 1, Math.ceil(tx + rad));
    const y0 = Math.max(0, Math.floor(ty - rad)), y1 = Math.min(TH - 1, Math.ceil(ty + rad));
    const cr = Math.cos(rot), sr = Math.sin(rot);
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const ddx = x + 0.5 - tx, ddy = y + 0.5 - ty, a = ddx * cr + ddy * sr, b = -ddx * sr + ddy * cr;
      const w = Math.exp(-0.5 * ((a * a) / (sx * sx) + (b * b) / (sy * sy))) * peak;
      if (w < 1e-4) continue;
      const k = y * TW + x; R[k] += c[0] * w; G[k] += c[1] * w; B[k] += c[2] * w;
    }
  };
  const SCOL = [lin([255, 244, 236]), lin([196, 214, 255]), lin([255, 214, 176]), lin([226, 200, 255]), lin([180, 226, 255])];
  const starCol = () => { const t = r(); return SCOL[t < 0.42 ? 0 : t < 0.64 ? 1 : t < 0.78 ? 2 : t < 0.92 ? 3 : 4]; };
  const dustLocal = (x, y) => dustAt(x * RES, y * RES);
  const bandLocal = (x, y) => { const i = clamp(Math.floor(x * RES), 0, TW - 1), j = clamp(Math.floor(y * RES), 0, TH - 1); return F.band[j * TW + i]; };
  const calmLocal = (x, y) => { const i = clamp(Math.floor(x * RES), 0, TW - 1), j = clamp(Math.floor(y * RES), 0, TH - 1); return F.calm[j * TW + i]; };
  // 1) the uniform faint field
  for (let n = 0; n < 11000; n++) {
    const x = r() * LW, y = r() * LH, m = Math.pow(r(), 3.2);
    const peak = (0.02 + 0.16 * m) * Math.exp(-2.8 * dustLocal(x, y));
    splat(x, y, 0.48 + 0.3 * m, starCol(), peak);
  }
  // 2) unresolved star clouds along the band (the grain that makes a galactic band read)
  for (let n = 0; n < 14000; n++) {
    const along = (r() * 2 - 1) * 2400, bw = 200 + 0.11 * Math.abs(along), across = gauss(r) * bw * 0.62;
    const x = SX + along * CA - across * SA, y = SY + along * SA + across * CA;
    if (x < 0 || y < 0 || x > LW || y > LH) continue;
    const m = Math.pow(r(), 4);
    const peak = (0.012 + 0.08 * m) * Math.exp(-3.2 * dustLocal(x, y));
    splat(x, y, 0.45 + 0.2 * m, starCol(), peak);
  }
  // 3) a scatter of brighter stars with a soft halo (kept modest: the bright twinklers are sprites)
  for (let n = 0; n < 420; n++) {
    let x = r() * LW, y = r() * LH;
    if (r() < 0.45) { const along = (r() * 2 - 1) * 2200, across = gauss(r) * 260; x = SX + along * CA - across * SA; y = SY + along * SA + across * CA; }
    if (x < 0 || y < 0 || x > LW || y > LH) continue;
    const m = Math.pow(r(), 2), c = starCol(), q = calmLocal(x, y);
    const peak = (0.12 + 0.7 * m) * Math.exp(-2.4 * dustLocal(x, y)) * (0.45 + 0.55 * q);
    splat(x, y, 0.62 + 0.4 * m, c, peak);
    splat(x, y, 2.4 + 2 * m, c, peak * 0.06);
  }
  // 4) distant galaxies: tiny tilted discs with a bright bulge, away from the centre and the sun
  for (let n = 0, placed = 0; n < 60 && placed < 6; n++) {
    const x = 120 + r() * (LW - 240), y = 90 + r() * (LH - 180);
    if (g2(x - CX, y - CY, 820, 470) > 0.3 || Math.hypot(x - SX, y - SY) < 520 || bandLocal(x, y) > 0.5) continue;
    const rot = r() * Math.PI, e = 0.25 + r() * 0.35, sz = 5 + r() * 7, c = r() < 0.5 ? lin([222, 204, 255]) : lin([255, 226, 200]);
    splat(x, y, sz * RES, c, 0.05, 1, e, rot);
    splat(x, y, sz * RES * 0.28, lin([255, 244, 230]), 0.16, 1, 0.8, rot);
    placed++;
  }

  // ---- the cosmic sun (emissive) -------------------------------------------------------------------------------------
  // coloured by sunLight(d): white-gold core, gold corona, amber, rose, violet (REALM.md 8: sun core (255, 214, 150))
  const STREAK = lin([255, 230, 188]), HALO = lin([110, 66, 214]);
  for (let j = 0; j < TH; j++) {
    const y = (j + 0.5) / RES, dy = y - SY;
    for (let i = 0; i < TW; i++) {
      const x = (i + 0.5) / RES, dx = x - SX, d = Math.hypot(dx, dy), k = j * TW + i;
      if (d > 1500) continue;
      const th = Math.atan2(dy, dx);
      const streamers = Math.pow(clamp(fbm(nS, Math.cos(th) * 2.2 + 11, Math.sin(th) * 2.2 + 4, 4) * 1.6 + 0.35), 2.2) *
        Math.exp(-d / 210) * smooth(18, 70, d);
      const a0 = 4 * Math.exp(-(d / 16) * (d / 16)), a1 = 1.4 * Math.exp(-(d / 48) * (d / 48)), a2 = 0.5 * Math.exp(-(d / 115) * (d / 115)) + 0.28 * streamers,
        a3 = 0.24 * Math.exp(-(d / 310) * (d / 310)), a4 = 0.1 * Math.exp(-(d / 760) * (d / 760));
      const streak = (0.14 * Math.exp(-(dy / 2.4) * (dy / 2.4)) * Math.exp(-Math.pow(Math.abs(dx) / 190, 1.3)) +
        0.06 * Math.exp(-(dy / 8) * (dy / 8)) * Math.exp(-Math.abs(dx) / 260));
      const add = [0, 0, 0];
      const lc = sunLight(d), A = a0 + a1 + a2 + a3;   // the wide a4 halo stays the realm's violet
      for (let c = 0; c < 3; c++) add[c] = lc[c] * A + HALO[c] * a4 + STREAK[c] * streak;
      // the outer glow sits behind the dust; the core and streak do not
      const veil = Math.exp(-1.6 * F.dust[k]);
      R[k] += add[0] * (d < 60 ? 1 : veil); G[k] += add[1] * (d < 60 ? 1 : veil); B[k] += add[2] * (d < 60 ? 1 : veil);
      E[k] = Math.max(E[k], clamp((a0 + a1 + a2 * 1.2 + streak * 1.5) * 1.4));
      WM[k] = Math.max(WM[k], clamp((a0 + a1 + a2 + a3 * 0.6 + streak) * 2.2));
    }
  }

  // ---- tone map, contract luma clamp (soft knee), dither, write -----------------------------------------------------
  const out = canvas(TW, TH), o = ctx(out), img = o.createImageData(TW, TH), px = img.data;
  const dr = rng(777);
  const enc = c => Math.pow(clamp(c), 1 / 2.2);
  const tm = v => 1 - Math.exp(-v * 1.05);
  for (let k = 0; k < N; k++) {
    // per-channel roll-off for the gas (bright knots bleach gently); hue-preserving (on the max channel) where the
    // light is the sun's, so the corona stays gold instead of going grey-white
    let l0 = tm(R[k]), l1 = tm(G[k]), l2 = tm(B[k]);
    const w = WM[k];
    if (w > 0) {
      const m = Math.max(R[k], G[k], B[k], 1e-6), s = tm(m) / m;
      l0 = lerp(l0, R[k] * s, w); l1 = lerp(l1, G[k] * s, w); l2 = lerp(l2, B[k] * s, w);
    }
    let c0 = enc(l0), c1 = enc(l1), c2 = enc(l2);
    const L = 0.2126 * c0 + 0.7152 * c1 + 0.0722 * c2, lim = lerp(MAXL, EMIS, E[k]), knee = lim * 0.82;
    if (L > knee) { const L2 = knee + (lim - knee) * (1 - Math.exp(-(L - knee) / (lim - knee))), s = L2 / L; c0 *= s; c1 *= s; c2 *= s; }
    const q = k * 4, dz = () => (dr() + dr() - 1) * 0.9;
    px[q] = clamp(Math.round(c0 * 255 + dz()), 0, 255); px[q + 1] = clamp(Math.round(c1 * 255 + dz()), 0, 255);
    px[q + 2] = clamp(Math.round(c2 * 255 + dz()), 0, 255); px[q + 3] = 255;
  }
  o.putImageData(img, 0, 0);
  { let sl = 0; const H = new Uint32Array(256); for (let k = 0; k < N; k++) { const l = Math.round(0.2126 * px[k * 4] + 0.7152 * px[k * 4 + 1] + 0.0722 * px[k * 4 + 2]); H[l]++; sl += l; }
    const pc = q => { let a = 0; for (let i = 0; i < 256; i++) { a += H[i]; if (a >= q * N) return i; } return 255; };
    console.log(`sky ${TW}x${TH} luma mean ${(sl / N).toFixed(1)} p10 ${pc(0.1)} p50 ${pc(0.5)} p90 ${pc(0.9)} p99 ${pc(0.99)} max ${pc(1)}`); }
  window.__last = out; window.__fields = F;   // __fields: debug hook for field dumps
  return out;
};
