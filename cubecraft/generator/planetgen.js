// Cube Craft planet generator, v2.
// One deterministic algorithm for the whole cube planet: the same seed gives the same planet on
// every machine, so each player's device can build its own chunks and the server only stores edits.
//
// Geometry: the planet is a cube of faces F x F blocks. Each face owns a truncated pyramid of space
// (a block belongs to the face whose axis it is furthest along), so the six faces fit together with
// no gaps and no doubled blocks, and land continues over every edge. Terrain heights come from noise
// sampled at the point's projection onto the cube surface, so it is seamless across edges.
//
// Performance: columns are cheap (2D climate + height); caves are sampled on a coarse 4-block lattice
// and blended, like Minecraft; ores are placed as small veins (a scatter, not noise on every block).
// Written without JS-only tricks so it ports line for line to Luau (bit32 for the integer ops).
(function (root) {
  "use strict";

  function mulberry32(a) {
    return function () {
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // Improved Perlin noise, seeded, with a 1024-entry table (repeats only every 1024 noise units,
  // far larger than any feature on the planet). Output roughly -1..1.
  const PS = 1024, PM = PS - 1;
  function Perlin(seed) {
    const rnd = mulberry32(seed);
    const q = new Uint16Array(PS);
    for (let i = 0; i < PS; i++) q[i] = i;
    for (let i = PS - 1; i > 0; i--) {
      const j = Math.floor(rnd() * (i + 1));
      const t = q[i]; q[i] = q[j]; q[j] = t;
    }
    const p = new Uint16Array(PS * 2 + 2);
    for (let i = 0; i < p.length; i++) p[i] = q[i & PM];
    function grad(h, x, y, z) {
      const g = h & 15;
      const u = g < 8 ? x : y;
      const v = g < 4 ? y : (g === 12 || g === 14 ? x : z);
      return ((g & 1) ? -u : u) + ((g & 2) ? -v : v);
    }
    return function (x, y, z) {
      let X = Math.floor(x), Y = Math.floor(y), Z = Math.floor(z);
      x -= X; y -= Y; z -= Z;
      X &= PM; Y &= PM; Z &= PM;
      const u = x * x * x * (x * (x * 6 - 15) + 10);
      const v = y * y * y * (y * (y * 6 - 15) + 10);
      const w = z * z * z * (z * (z * 6 - 15) + 10);
      const A = p[X] + Y, AA = p[A] + Z, AB = p[A + 1] + Z;
      const B = p[X + 1] + Y, BA = p[B] + Z, BB = p[B + 1] + Z;
      const x1 = x - 1, y1 = y - 1, z1 = z - 1;
      const a0 = grad(p[AA], x, y, z), a1 = grad(p[BA], x1, y, z);
      const b0 = grad(p[AB], x, y1, z), b1 = grad(p[BB], x1, y1, z);
      const c0 = grad(p[AA + 1], x, y, z1), c1 = grad(p[BA + 1], x1, y, z1);
      const d0 = grad(p[AB + 1], x, y1, z1), d1 = grad(p[BB + 1], x1, y1, z1);
      const ab0 = a0 + u * (a1 - a0), ab1 = b0 + u * (b1 - b0);
      const cd0 = c0 + u * (c1 - c0), cd1 = d0 + u * (d1 - d0);
      const lo = ab0 + v * (ab1 - ab0), hi = cd0 + v * (cd1 - cd0);
      return lo + w * (hi - lo);
    };
  }

  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const sstep = (a, b, v) => { const t = clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

  // ---------- cube faces ----------
  // N = outward normal, U = right, V = down, as seen from outside. Cross-shaped net:
  //            [+Y]
  //   [-X]  [+Z]  [+X]  [-Z]
  //            [-Y]
  // (U, N, V) is right-handed on every face, so local x = U, y = N (up), z = V.
  const FACES = [
    { id: "+Z", N: [0, 0, 1], U: [1, 0, 0], V: [0, -1, 0], net: [1, 1] },
    { id: "+X", N: [1, 0, 0], U: [0, 0, -1], V: [0, -1, 0], net: [2, 1] },
    { id: "-Z", N: [0, 0, -1], U: [-1, 0, 0], V: [0, -1, 0], net: [3, 1] },
    { id: "-X", N: [-1, 0, 0], U: [0, 0, 1], V: [0, -1, 0], net: [0, 1] },
    { id: "+Y", N: [0, 1, 0], U: [1, 0, 0], V: [0, 0, 1], net: [1, 0] },
    { id: "-Y", N: [0, -1, 0], U: [1, 0, 0], V: [0, 0, -1], net: [1, 2] },
  ];

  // Biomes (numbers are what the generator returns; names and map colours for display).
  const BIOMES = [
    ["deep_ocean", "Deep ocean", [28, 58, 120]],
    ["ocean", "Ocean", [44, 92, 168]],
    ["frozen_ocean", "Frozen ocean", [120, 160, 205]],
    ["river", "River", [62, 128, 210]],
    ["beach", "Beach", [226, 211, 154]],
    ["plains", "Plains", [141, 193, 82]],
    ["meadow", "Flower meadow", [168, 205, 96]],
    ["forest", "Forest", [63, 138, 52]],
    ["birch_forest", "Birch forest", [104, 168, 79]],
    ["taiga", "Taiga", [70, 112, 82]],
    ["snowy_plains", "Snowy plains", [235, 241, 246]],
    ["snowy_taiga", "Snowy taiga", [196, 214, 206]],
    ["snowy_peaks", "Snowy peaks", [255, 255, 255]],
    ["stony_peaks", "Stony peaks", [150, 152, 156]],
    ["desert", "Desert", [232, 207, 138]],
    ["savanna", "Savanna", [190, 180, 92]],
    ["volcanic", "Volcanic", [74, 66, 66]],
  ];
  const B = {};
  BIOMES.forEach((b, i) => (B[b[0]] = i));

  function create(seed, opts) {
    opts = opts || {};
    const F = opts.faceSize || 2048;
    const R = F / 2;
    const SEA = 0;
    seed = seed | 0;
    // Continents and climate zones grow with the planet; terrain detail stays human-scale.
    const K = clamp(Math.sqrt(F / 2048), 1, 3);
    const SC = { warp: 400 * K, cont: 760 * K, eros: 420 * Math.sqrt(K), ridge: 240 * Math.sqrt(K), river: 520 * Math.sqrt(K),
                 temp: 1150 * K, hum: 950 * K, volc: 320 * Math.sqrt(K), warpAmt: 60 * K };
    const P = (k) => Perlin((Math.imul(seed, 1013) + k * 7919) | 0);
    const nCont = P(1), nEros = P(2), nRidge = P(3), nTemp = P(4), nHum = P(5), nRiver = P(6),
      nDetail = P(7), nPatch = P(8), nCaveA = P(9), nCaveB = P(10), nCaveC = P(11), nVolc = P(12),
      nLava = P(13), nWarp = P(18);

    function fbm(n, x, y, z, oct) {
      let s = 0, a = 1, f = 1, t = 0;
      for (let i = 0; i < oct; i++) {
        s += a * n(x * f + i * 31.7, y * f + i * 17.3, z * f - i * 11.1);
        t += a; a *= 0.5; f *= 2;
      }
      return (s / t) * 1.9;
    }

    function hash(a, b, c, d) {
      let h = (Math.imul(a, 374761393) + Math.imul(b, 668265263) + Math.imul(c, 1274126177) + Math.imul(d, 2246822519) + Math.imul(seed, 3266489917)) | 0;
      h = Math.imul(h ^ (h >>> 13), 1274126177);
      h ^= h >>> 16;
      return (h >>> 0) / 4294967296;
    }

    // Height curve over continentalness (piecewise linear, unrolled for speed).
    const CX = [-1, -0.5, -0.22, -0.08, 0.0, 0.15, 0.5, 1], CY = [-46, -34, -12, -3, 1, 6, 15, 24];
    function contCurve(c) {
      if (c <= CX[0]) return CY[0];
      for (let i = 1; i < 8; i++) if (c <= CX[i]) return CY[i - 1] + (CY[i] - CY[i - 1]) * (c - CX[i - 1]) / (CX[i] - CX[i - 1]);
      return CY[7];
    }

    // One column at the 3D point (x, y, z) on the cube surface. Writes height and biome into out.
    function column(x, y, z, out) {
      const ws = SC.warp, wa = SC.warpAmt;
      const wx = x + fbm(nWarp, x / ws, y / ws, z / ws, 2) * wa;
      const wy = y + fbm(nWarp, y / ws + 9.1, z / ws, x / ws, 2) * wa;
      const wz = z + fbm(nWarp, z / ws - 4.7, x / ws, y / ws, 2) * wa;
      const cont = clamp(fbm(nCont, wx / SC.cont, wy / SC.cont, wz / SC.cont, 5) + 0.12, -1, 1);
      const eros = clamp(fbm(nEros, wx / SC.eros, wy / SC.eros, wz / SC.eros, 4), -1, 1);
      const e01 = (eros + 1) / 2;
      const ridge = 1 - Math.abs(fbm(nRidge, wx / SC.ridge, wy / SC.ridge, wz / SC.ridge, 4));

      let h = contCurve(cont);
      h += fbm(nDetail, x / 55, y / 55, z / 55, 4) * (3 + 11 * (1 - e01));
      const inland = sstep(0.04, 0.32, cont);
      const pk = ridge > 0.5 ? Math.pow((ridge - 0.5) / 0.5, 1.6) : 0;
      h += inland * pk * 95 * (0.2 + 0.8 * (1 - e01));

      const rv = Math.abs(fbm(nRiver, wx / SC.river, wy / SC.river, wz / SC.river, 3));
      const riverAmt = (1 - sstep(0.018, 0.05, rv)) * sstep(-0.06, 0.06, cont) * (1 - sstep(22, 42, h));
      let river = false;
      if (riverAmt > 0 && h > -3) { h = h + (-3 - h) * riverAmt; river = riverAmt > 0.55; }
      if (h > 150) h = 150;

      // climate: noise, plus cool "poles" at the centres of the top and bottom faces, and colder up high
      const ay = Math.abs(y) / Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
      const temp0 = clamp(0.58 + fbm(nTemp, x / SC.temp, y / SC.temp, z / SC.temp, 3) * 0.72 - 0.2 * sstep(0.55, 1, ay), 0, 1);
      const hum = clamp(0.5 + fbm(nHum, x / SC.hum, y / SC.hum, z / SC.hum, 3) * 0.75, 0, 1);
      const temp = temp0 - Math.max(0, h - 28) / 140;

      let b;
      if (river && h <= -1) b = temp < 0.2 ? B.frozen_ocean : B.river;
      else if (h < -16) b = temp < 0.2 ? B.frozen_ocean : B.deep_ocean;
      else if (h < -1) b = temp < 0.2 ? B.frozen_ocean : B.ocean;
      else if (h < 2 && cont < 0.08) b = temp < 0.22 ? B.snowy_plains : B.beach;
      else if (h > 62) b = temp < 0.36 ? B.snowy_peaks : B.stony_peaks;
      else if (temp < 0.25) b = hum > 0.5 ? B.snowy_taiga : B.snowy_plains;
      else if (temp > 0.68) {
        if (inland > 0.4 && fbm(nVolc, x / SC.volc, y / SC.volc, z / SC.volc, 3) > 0.38) b = B.volcanic;
        else b = hum < 0.45 ? B.desert : B.savanna;
      } else if (hum > 0.62) b = temp < 0.4 ? B.taiga : B.forest;
      else if (hum > 0.52) b = temp < 0.4 ? B.taiga : B.birch_forest;
      else b = fbm(nPatch, x / 160, y / 160, z / 160, 2) > 0.45 ? B.meadow : B.plains;
      out.h = h; out.b = b; out.t = temp;
      return out;
    }

    // Face-local block coordinates -> 3D. (u, v) may run past the face edge (used near edges).
    // Returns the projection of the column's base point onto the cube surface.
    const tmp = [0, 0, 0];
    function basePoint(f, u, v, outp) {
      const fc = FACES[f], s = u - R + 0.5, t = v - R + 0.5;
      const x = fc.N[0] * R + fc.U[0] * s + fc.V[0] * t;
      const y = fc.N[1] * R + fc.U[1] * s + fc.V[1] * t;
      const z = fc.N[2] * R + fc.U[2] * s + fc.V[2] * t;
      const m = Math.max(R, Math.abs(s), Math.abs(t));
      const k = R / m;
      outp[0] = x * k; outp[1] = y * k; outp[2] = z * k;
      return outp;
    }
    const colTmp = { h: 0, b: 0, t: 0 };
    function columnAt(f, u, v) {
      basePoint(f, u, v, tmp);
      return column(tmp[0], tmp[1], tmp[2], { h: 0, b: 0, t: 0 });
    }

    // Which face owns the 3D point (the axis it is furthest along), and its block coordinates there.
    // Blocks stand straight up from their face, so u, v are a straight projection onto the face plane
    // (they run past 0..F-1 for high ground near an edge, which the edge chunks hold).
    function locate(x, y, z) {
      const ax = Math.abs(x), ay = Math.abs(y), az = Math.abs(z);
      let f;
      if (ax >= ay && ax >= az) f = x > 0 ? 1 : 3;
      else if (ay >= az) f = y > 0 ? 4 : 5;
      else f = z > 0 ? 0 : 2;
      const fc = FACES[f];
      return { f,
        u: x * fc.U[0] + y * fc.U[1] + z * fc.U[2] + R - 0.5,
        v: x * fc.V[0] + y * fc.V[1] + z * fc.V[2] + R - 0.5,
        alt: x * fc.N[0] + y * fc.N[1] + z * fc.N[2] - R };
    }

    // The ground column reached by walking from face f block (u, v), where u, v may run past the face:
    // the walk bends over the edge onto the next face (the cube surface is unfolded).
    function walkTo(f, u, v) {
      basePoint(f, u, v, tmp);
      return locate(tmp[0], tmp[1], tmp[2]);
    }

    // ---------- chunks ----------
    const CS = opts.chunkSize || 32;
    const SLATE_LINE = -44;
    const MIN_Y = -60;
    const ORES = [
      { name: "coal", per: 7, min: 4, max: 11, lo: -220, hi: 90 },
      { name: "iron", per: 5, min: 3, max: 9, lo: -320, hi: 34 },
      { name: "gold", per: 2, min: 3, max: 8, lo: -420, hi: -14 },
      { name: "gem", per: 1, min: 2, max: 7, lo: -520, hi: -48 },
    ];
    const DENS = { forest: 0.06, birch_forest: 0.05, taiga: 0.05, snowy_taiga: 0.04, plains: 0.004, meadow: 0.006, savanna: 0.006, snowy_plains: 0.004, desert: 0.012 };
    const DENS_B = new Float32Array(BIOMES.length);
    for (const k in DENS) DENS_B[B[k]] = DENS[k];
    const PLANT = { plains: 0.22, meadow: 0.38, forest: 0.12, birch_forest: 0.14, savanna: 0.3, taiga: 0.06 };
    const PLANT_B = new Float32Array(BIOMES.length);
    for (const k in PLANT) PLANT_B[B[k]] = PLANT[k];

    // Builds chunk (cu, cv) on face f. ID maps block names to numbers (from the texture atlas).
    // Returns blocks for the chunk plus a 1-block ring of neighbours (so faces between chunks can be
    // skipped and corner shading matches), and the range to draw. Edge chunks reach past the face
    // edge just far enough to hold this face's share of the land above the edge.
    function chunk(f, cu, cv, ID) {
      const nFace = F / CS;
      let u0 = cu * CS, u1 = u0 + CS, v0 = cv * CS, v1 = v0 + CS;
      // reach past the face edge on edge chunks
      const edgeReach = (fixed, along, a0, a1) => {
        let m = 2;
        for (let k = a0; k < a1; k += 2) {
          const c = along ? columnAt(f, fixed, k) : columnAt(f, k, fixed);
          if (c.h + 3 > m) m = c.h + 3;
        }
        return Math.min(160, Math.ceil(m));
      };
      if (cu === 0) u0 -= edgeReach(0, true, v0, v1);
      if (cu === nFace - 1) u1 += edgeReach(F - 1, true, v0, v1);
      if (cv === 0) v0 -= edgeReach(0, false, u0, u1);
      if (cv === nFace - 1) v1 += edgeReach(F - 1, false, u0, u1);

      const M = 3;                                   // column margin (trees, steepness, culling)
      const cx0 = u0 - M, cz0 = v0 - M, CW = (u1 - u0) + 2 * M, CD = (v1 - v0) + 2 * M;
      const H = new Int16Array(CW * CD), BI = new Uint8Array(CW * CD), TT = new Float32Array(CW * CD);
      let minH = 1e9, maxH = -1e9;
      for (let i = 0; i < CW; i++) for (let j = 0; j < CD; j++) {
        basePoint(f, cx0 + i, cz0 + j, tmp);
        column(tmp[0], tmp[1], tmp[2], colTmp);
        const hh = Math.floor(colTmp.h), k = i * CD + j;
        H[k] = hh; BI[k] = colTmp.b; TT[k] = colTmp.t;
        if (i >= M - 1 && i < CW - M + 1 && j >= M - 1 && j < CD - M + 1) {
          if (hh < minH) minH = hh;
          if (hh > maxH) maxH = hh;
        }
      }
      const ylo = Math.min(minH - 28, MIN_Y);
      const yhi = Math.max(maxH, SEA) + 16;
      const Y = yhi - ylo + 1;
      // voxel array covers the chunk plus a 1-column ring
      const x0 = u0 - 1, z0 = v0 - 1, SX = (u1 - u0) + 2, SZ = (v1 - v0) + 2;
      const W = new Uint8Array(SX * SZ * Y);
      const fc = FACES[f];

      // --- cave lattice: noise every 4 blocks, blended in between ---
      const LX = (SX >> 2) + 2, LZ = (SZ >> 2) + 2, LY = (Y >> 2) + 2;
      const LA = new Float32Array(LX * LZ * LY), LB = new Float32Array(LX * LZ * LY), LC = new Float32Array(LX * LZ * LY);
      for (let i = 0; i < LX; i++) for (let j = 0; j < LZ; j++) {
        const s = x0 + i * 4 - R + 0.5, t = z0 + j * 4 - R + 0.5;
        for (let k = 0; k < LY; k++) {
          const a = ylo + k * 4 + 0.5;
          const qx = fc.N[0] * (R + a) + fc.U[0] * s + fc.V[0] * t;
          const qy = fc.N[1] * (R + a) + fc.U[1] * s + fc.V[1] * t;
          const qz = fc.N[2] * (R + a) + fc.U[2] * s + fc.V[2] * t;
          const n = (i * LZ + j) * LY + k;
          LA[n] = fbm(nCaveA, qx / 40, qy / 40, qz / 40, 2);
          LB[n] = nCaveB(qx / 30, qy / 30, qz / 30);
          LC[n] = nCaveC(qx / 30, qy / 30, qz / 30);
        }
      }
      function lerp3(L, i, j, y) {
        const li = i >> 2, lj = j >> 2, ly = y >> 2, fi = (i & 3) / 4, fj = (j & 3) / 4, fy = (y & 3) / 4;
        const b00 = (li * LZ + lj) * LY + ly, b10 = ((li + 1) * LZ + lj) * LY + ly;
        const b01 = (li * LZ + lj + 1) * LY + ly, b11 = ((li + 1) * LZ + lj + 1) * LY + ly;
        const c00 = L[b00] + (L[b00 + 1] - L[b00]) * fy, c10 = L[b10] + (L[b10 + 1] - L[b10]) * fy;
        const c01 = L[b01] + (L[b01 + 1] - L[b01]) * fy, c11 = L[b11] + (L[b11 + 1] - L[b11]) * fy;
        const c0 = c00 + (c10 - c00) * fi, c1 = c01 + (c11 - c01) * fi;
        return c0 + (c1 - c0) * fj;
      }

      const iSand = ID.sand, iSandstone = ID.sandstone, iStone = ID.stone, iSlate = ID.slate, iDirt = ID.dirt,
        iGrass = ID.grass, iSnowGrass = ID.snow_grass, iSnow = ID.snow, iAsh = ID.ash, iGravel = ID.gravel,
        iClay = ID.clay, iWater = ID.water, iLava = ID.lava;

      for (let i = 0; i < SX; i++) for (let j = 0; j < SZ; j++) {
        const u = x0 + i, v = z0 + j, ci = (i + M - 1) * CD + (j + M - 1);
        const Hc = H[ci], bio = BI[ci];
        const s = u - R + 0.5, t = v - R + 0.5;
        const reach = Math.max(Math.abs(s), Math.abs(t)) - R - 0.5;   // lowest altitude this face owns here
        const wet = Hc < SEA;
        let top, sub, subN = 3, l2 = 0, l2N = 0;
        switch (bio) {
          case B.desert: top = iSand; sub = iSand; subN = 4; l2 = iSandstone; l2N = 6; break;
          case B.beach: top = iSand; sub = iSand; l2 = iSandstone; l2N = 2; break;
          case B.snowy_plains: case B.snowy_taiga: top = iSnowGrass; sub = iDirt; break;
          case B.snowy_peaks: top = iSnow; sub = iSnow; subN = 2; break;
          case B.stony_peaks: top = iStone; sub = iStone; break;
          case B.volcanic: top = iAsh; sub = iAsh; break;
          default: top = iGrass; sub = iDirt;
        }
        if (wet) {
          const r = hash(u, v, f, 1);
          if (bio === B.river) top = r < 0.6 ? iGravel : iSand;
          else if (bio === B.deep_ocean) top = r < 0.5 ? iGravel : iClay;
          else top = r < 0.62 ? iSand : r < 0.85 ? iGravel : iClay;
          sub = top === iClay ? iClay : iSand;
        } else if (bio !== B.desert && bio !== B.beach) {
          let st = 0;
          const nb = [ci - CD, ci + CD, ci - 1, ci + 1];
          for (let q = 0; q < 4; q++) { const dd = Math.abs(H[nb[q]] - Hc); if (dd > st) st = dd; }
          if (st >= 4) { top = bio === B.snowy_peaks ? iSnow : iStone; sub = iStone; }
        }
        let lavaCrack = false;
        if (bio === B.volcanic) { basePoint(f, u, v, tmp); lavaCrack = Math.abs(fbm(nLava, tmp[0] / 30, tmp[1] / 30, tmp[2] / 30, 2)) < 0.07; }
        const liquid = bio === B.volcanic ? iLava : (bio === B.frozen_ocean ? iWater : iWater);
        const colBase = (i * SZ + j) * Y;
        const aTop = Math.max(Hc, SEA);
        for (let a = Math.max(ylo, Math.ceil(reach)); a <= aTop; a++) {
          const y = a - ylo;
          if (a > Hc) { W[colBase + y] = (bio === B.frozen_ocean && a === SEA) ? iSnow : liquid; continue; }
          const d = Hc - a;
          let b;
          if (d === 0) b = lavaCrack ? iLava : top;
          else if (d < subN) b = sub;
          else if (l2 && d < subN + l2N) b = l2;
          else b = iStone;
          if (b === iStone && (a < SLATE_LINE || (a < SLATE_LINE + 5 && hash(u * 3 + a, v, f, 7) < (SLATE_LINE + 5 - a) / 6))) b = iSlate;
          if (d > 4 && !(wet && d < 10) && a > ylo + 1) {
            const cheese = lerp3(LA, i, j, y);
            const boost = d > 40 ? 0.08 : d * 0.002;
            if (cheese > 0.62 - boost) { W[colBase + y] = (a < SLATE_LINE - 8 && cheese > 0.7) ? iLava : 0; continue; }
            const t1 = lerp3(LB, i, j, y);
            if (t1 > -0.055 && t1 < 0.055) {
              const t2 = lerp3(LC, i, j, y);
              if (t2 > -0.055 && t2 < 0.055) { W[colBase + y] = 0; continue; }
            }
          }
          W[colBase + y] = b;
        }
      }

      // --- ore veins: a scatter of short random walks per 16-block cell ---
      const oreIds = ORES.map((o) => [ID[o.name], ID["slate_" + o.name]]);
      const cA0 = Math.floor((ylo) / 16), cA1 = Math.floor((yhi) / 16);
      const cU0 = Math.floor((x0 - 10) / 16), cU1 = Math.floor((x0 + SX + 10) / 16);
      const cV0 = Math.floor((z0 - 10) / 16), cV1 = Math.floor((z0 + SZ + 10) / 16);
      for (let cu2 = cU0; cu2 <= cU1; cu2++) for (let cv2 = cV0; cv2 <= cV1; cv2++) for (let ca = cA0; ca <= cA1; ca++) {
        const rnd = mulberry32((Math.imul(cu2, 73856093) ^ Math.imul(cv2, 19349663) ^ Math.imul(ca, 83492791) ^ Math.imul(f + 1, 2654435761) ^ seed) | 0);
        for (let o = 0; o < ORES.length; o++) {
          const ore = ORES[o];
          const aMid = ca * 16 + 8;
          if (aMid < ore.lo || aMid > ore.hi) { rnd(); continue; }
          let n = Math.floor(ore.per * (0.5 + rnd()));
          while (n-- > 0) {
            let pu = cu2 * 16 + Math.floor(rnd() * 16), pv = cv2 * 16 + Math.floor(rnd() * 16), pa = ca * 16 + Math.floor(rnd() * 16);
            const len = ore.min + Math.floor(rnd() * (ore.max - ore.min));
            for (let st = 0; st < len; st++) {
              const i = pu - x0, j = pv - z0, y = pa - ylo;
              if (i >= 0 && j >= 0 && y >= 0 && i < SX && j < SZ && y < Y) {
                const k = (i * SZ + j) * Y + y, cur = W[k];
                if (cur === iStone) W[k] = oreIds[o][0];
                else if (cur === iSlate) W[k] = oreIds[o][1];
              }
              const dir = Math.floor(rnd() * 6);
              if (dir === 0) pu++; else if (dir === 1) pu--; else if (dir === 2) pv++; else if (dir === 3) pv--; else if (dir === 4) pa++; else pa--;
            }
          }
        }
      }

      // --- trees and plants (from the margin columns too, so canopies cross chunk borders) ---
      function put(i, j, y, id, force) {
        if (i < 0 || j < 0 || i >= SX || j >= SZ || y < 0 || y >= Y) return;
        const k = (i * SZ + j) * Y + y;
        if (force || W[k] === 0) W[k] = id;
      }
      const iLog = ID.log, iLeaves = ID.leaves, iBLog = ID.birch_log, iBLeaves = ID.birch_leaves,
        iSLog = ID.spruce_log, iSLeaves = ID.spruce_leaves, iCactus = ID.cactus, iTall = ID.tall_grass,
        iFR = ID.flower_red, iFY = ID.flower_yellow;
      for (let ii = 0; ii < CW; ii++) for (let jj = 0; jj < CD; jj++) {
        const k = ii * CD + jj, Hc = H[k], bio = BI[k];
        if (Hc < SEA + 1) continue;
        const u = cx0 + ii, v = cz0 + jj;
        const i = u - x0, j = v - z0, y0 = Hc - ylo;
        if (Math.max(Math.abs(u - R + 0.5), Math.abs(v - R + 0.5)) > R + Hc) continue; // not this face's land
        const surfType = (bio === B.desert || bio === B.beach) ? iSand : (bio === B.snowy_plains || bio === B.snowy_taiga) ? iSnowGrass : (bio === B.snowy_peaks || bio === B.stony_peaks || bio === B.volcanic) ? 0 : iGrass;
        if (!surfType) continue;
        // steep spots are bare stone, so nothing grows there
        let st = 0;
        if (ii > 0 && jj > 0 && ii < CW - 1 && jj < CD - 1) {
          st = Math.max(Math.abs(H[k - CD] - Hc), Math.abs(H[k + CD] - Hc), Math.abs(H[k - 1] - Hc), Math.abs(H[k + 1] - Hc));
        }
        if (st >= 4) continue;
        const r = hash(u, v, f, 11);
        const dens = DENS_B[bio];
        if (dens > 0 && r < dens) {
          const patch = 0.35 + 0.65 * sstep(-0.3, 0.35, fbm(nPatch, u / 40, v / 40, f * 9.3, 2));
          if (r < dens * patch && hash(u >> 2, v >> 2, f, 12) < 0.85) {
            const r2 = hash(u, v, f, 13);
            if (bio === B.desert) { for (let q = 1; q <= 2 + Math.floor(r2 * 3); q++) put(i, j, y0 + q, iCactus, true); }
            else if (bio === B.taiga || bio === B.snowy_taiga || bio === B.snowy_plains) {
              const th = 6 + Math.floor(r2 * 3);
              for (let q = 1; q <= th; q++) put(i, j, y0 + q, iSLog, true);
              const radii = [3, 2, 3, 2, 1, 2, 1, 0, 0].slice(-(th - 1));
              for (let n = 0; n < radii.length; n++) {
                const rr = radii[n];
                for (let a = -rr; a <= rr; a++) for (let b = -rr; b <= rr; b++)
                  if (Math.abs(a) + Math.abs(b) <= rr + (rr >= 2 ? 1 : 0)) put(i + a, j + b, y0 + 3 + n, iSLeaves);
              }
              put(i, j, y0 + th + 1, iSLeaves);
            } else {
              const birch = bio === B.birch_forest || (bio === B.forest && r2 < 0.25);
              const log = birch ? iBLog : iLog, lv = birch ? iBLeaves : iLeaves;
              const th = (birch ? 5 : 4) + Math.floor(r2 * 3);
              for (let q = 1; q <= th; q++) put(i, j, y0 + q, log, true);
              const t = y0 + th;
              for (let dy = -1; dy <= 2; dy++) {
                const rr = dy <= 0 ? 2 : 1;
                for (let a = -rr; a <= rr; a++) for (let b = -rr; b <= rr; b++) {
                  if (rr === 2 && Math.abs(a) === 2 && Math.abs(b) === 2 && hash(u + a, v + b, dy, 3) < 0.7) continue;
                  if (dy === 2 && Math.abs(a) + Math.abs(b) === 2) continue;
                  put(i + a, j + b, t + dy, lv);
                }
              }
            }
            continue;
          }
        }
        const pl = PLANT_B[bio];
        if (pl > 0 && surfType === iGrass && i >= 0 && j >= 0 && i < SX && j < SZ) {
          if (hash(u, v, f, 14) < pl && W[(i * SZ + j) * Y + y0] === iGrass) {
            const fl = bio === B.meadow ? 0.45 : 0.12, r4 = hash(u, v, f, 15);
            put(i, j, y0 + 1, r4 < 1 - fl ? iTall : r4 < 1 - fl / 2 ? iFR : iFY);
          }
        }
      }

      return { f, cu, cv, W, SX, SZ, Y, x0, z0, ylo, minH, maxH };
    }

    // ---------- the interior: layers down to the core ----------
    // Layers are cube-shaped shells (the core of a cube planet is a cube). depth = blocks below sea level,
    // measured to the nearest face: depth = R - max(|x|, |y|, |z|). The centre is depth R.
    const DEEP_CRUST = Math.max(300, Math.round(0.05 * R));
    const LAYERS = [
      { key: "crust", name: "Crust", top: 0, bottom: 44, rock: "stone", temp: [15, 150], dens: [2.6, 2.8], gear: "None", cave: 40 },
      { key: "deep", name: "Deep crust", top: 44, bottom: DEEP_CRUST, rock: "slate", temp: [150, 600], dens: [2.9, 3.2], gear: "Mining lamp", cave: 48 },
      { key: "mantle", name: "Mantle", top: DEEP_CRUST, bottom: Math.round(0.45 * R), rock: "mantle_rock", temp: [600, 3700], dens: [3.4, 5.6], gear: "Heat suit, tier 1", cave: 64 },
      { key: "outer", name: "Outer core", top: Math.round(0.45 * R), bottom: Math.round(0.8 * R), rock: "core_iron", temp: [3700, 5000], dens: [9.9, 12.2], gear: "Heat suit, tier 2, and pressure rig", cave: 80 },
      { key: "inner", name: "Inner core", top: Math.round(0.8 * R), bottom: R, rock: "heartstone", temp: [5000, 5600], dens: [12.8, 13.1], gear: "Core suit", cave: 56 },
    ];
    // ores per layer: [block, noise cell size, threshold] (rarer = higher threshold)
    const DEEP_ORES = {
      crust: [["coal", 4, 0.5], ["iron", 3.6, 0.57]],
      deep: [["slate_iron", 3.6, 0.6], ["slate_gold", 3.2, 0.63], ["slate_gem", 3, 0.67]],
      mantle: [["ember", 4, 0.6], ["cobalt", 3.6, 0.63]],
      outer: [["starmetal", 4, 0.62]],
      inner: [["core_crystal", 3.5, 0.62]],
    };
    const nOreD = [P(20), P(21), P(22)];
    const HEART = 14;                       // hollow chamber at the very centre
    // pressure (GPa) by fraction of the way to the centre, shaped like Earth's
    const PQ = [[0, 0], [0.006, 1], [0.05, 8], [0.1, 24], [0.45, 136], [0.8, 330], [1, 364]];
    function layerIndex(depth) {
      for (let i = 0; i < LAYERS.length; i++) if (depth < LAYERS[i].bottom) return i;
      return LAYERS.length - 1;
    }
    function conditions(depth) {
      depth = clamp(depth, 0, R);
      const i = layerIndex(depth), L = LAYERS[i], k = (depth - L.top) / Math.max(1, L.bottom - L.top), q = depth / R;
      let p = 364;
      for (let j = 1; j < PQ.length; j++) if (q <= PQ[j][0]) { p = PQ[j - 1][1] + (PQ[j][1] - PQ[j - 1][1]) * (q - PQ[j - 1][0]) / (PQ[j][0] - PQ[j - 1][0]); break; }
      return { layer: i, key: L.key, name: L.name, gear: L.gear, depth, toCore: R - depth,
        tempC: L.temp[0] + (L.temp[1] - L.temp[0]) * k, density: L.dens[0] + (L.dens[1] - L.dens[0]) * k, pressureGPa: p };
    }
    // The block at world point (x, y, z) inside the planet (below sea level). ids maps names to numbers.
    function deepBlock(x, y, z, ids) {
      const depth = R - Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
      if (depth > R - HEART) return 0;                                   // the hollow heart
      if (depth > R - HEART - 3) return ids.core_crystal;                // lined with core crystal
      // layer boundaries are ragged, not ruler-straight
      const li = layerIndex(depth + (hash(x | 0, y | 0, z | 0, 31) - 0.5) * 8);
      const L = LAYERS[li], cs = L.cave;
      const c = fbm(nCaveA, x / cs, y / cs, z / cs, 2);
      if (L.key === "outer") { if (c > -0.08) return ids.lava; }         // seas of molten metal
      else if (L.key === "mantle") { if (c > 0.6) return nCaveB(x / 50, y / 50, z / 50) > 0 ? 0 : ids.lava; }
      else if (L.key === "inner") { if (c > 0.72) return 0; }            // rare glowing caverns
      else {
        if (c > 0.62) return depth > 120 && c > 0.7 ? ids.lava : 0;
        const t1 = nCaveB(x / 30, y / 30, z / 30);
        if (t1 > -0.055 && t1 < 0.055) { const t2 = nCaveC(x / 30, y / 30, z / 30); if (t2 > -0.055 && t2 < 0.055) return 0; }
      }
      const ores = DEEP_ORES[L.key];
      for (let o = 0; o < ores.length; o++) {
        const ore = ores[o];
        if (nOreD[o](x / ore[1], y / ore[1], z / ore[1]) > ore[2]) return ids[ore[0]];
      }
      return ids[L.rock];
    }
    // A cut-out cube of the interior, centred dMid blocks down on the line from face f block (uc, vc)
    // to the planet's centre (so going deeper always heads for the core). Same layout as chunk().
    function deepRegion(f, uc, vc, dMid, size, ids) {
      const fc = FACES[f], SX = size + 2, SZ = size + 2, Y = size + 2;
      const W = new Uint8Array(SX * SZ * Y);
      const k = (R - dMid) / R, sc = (uc - R + 0.5) * k, tc = (vc - R + 0.5) * k;
      const h = SX / 2;
      for (let i = 0; i < SX; i++) for (let j = 0; j < SZ; j++) {
        const s = sc - h + i + 0.5, t = tc - h + j + 0.5;
        for (let y = 0; y < Y; y++) {
          const r = (R - dMid) - h + y + 0.5;           // distance out from the centre along the face normal
          const x = fc.N[0] * r + fc.U[0] * s + fc.V[0] * t;
          const yy = fc.N[1] * r + fc.U[1] * s + fc.V[1] * t;
          const z = fc.N[2] * r + fc.U[2] * s + fc.V[2] * t;
          W[(i * SZ + j) * Y + y] = deepBlock(Math.floor(x), Math.floor(yy), Math.floor(z), ids);
        }
      }
      return { f, W, SX, SZ, Y };
    }

    return { F, R, CS, SEA, FACES, BIOMES, LAYERS, column, columnAt, basePoint, locate, walkTo, chunk, hash,
      conditions, deepBlock, deepRegion };
  }

  const api = { create, FACES, BIOMES, Perlin };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.PlanetGen = api;
})(this);
