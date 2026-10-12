// Cube Craft generation worker. Runs planetgen + mesher off the main thread.
// Messages in:  init, chunk, remesh, far, globe.   Messages out: same type with results (buffers transferred).
(function () {
  "use strict";
  let gen = null, mesh = null, ID = null, F = 0;
  const cache = new Map();           // key -> chunk blocks (most recently used last)
  const CACHE_MAX = 260;
  const BAND = 32;

  function remember(key, ch) {
    cache.delete(key); cache.set(key, ch);
    if (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value);
  }

  function meshChunk(ch, walls) {
    const sLo = ch.minH - 8 - ch.ylo, sHi = Math.max(ch.maxH, 0) + 16 - ch.ylo;
    const bands = [], transfer = [];
    let tris = 0;
    for (let y0 = 0; y0 < ch.Y; y0 += BAND) {
      const m = mesh(ch, walls, y0, y0 + BAND);
      if (!m.tris) continue;
      tris += m.tris;
      const groups = {};
      for (const k of ["opaque", "trans", "plant", "lava"]) if (m[k]) {
        const c1 = m[k].col, c3 = new Float32Array(c1.length * 3);   // grey light -> rgb for the GPU
        for (let i = 0; i < c1.length; i++) c3[i * 3] = c3[i * 3 + 1] = c3[i * 3 + 2] = c1[i];
        m[k].col = c3;
        groups[k] = m[k];
        transfer.push(m[k].pos.buffer, m[k].uv.buffer, m[k].col.buffer, m[k].idx.buffer);
      }
      bands.push({ y0, surface: y0 + BAND > sLo && y0 < sHi, groups });
    }
    return { bands, transfer, tris };
  }

  self.onmessage = function (e) {
    const msg = e.data;
    if (msg.type === "init") {
      gen = PlanetGen.create(msg.seed, { faceSize: msg.F, chunkSize: 32 });
      mesh = CubeMesher.createMesher(msg.info, msg.atlas);
      ID = msg.ID; F = msg.F;
      cache.clear();
      return;
    }
    if (msg.type === "chunk" || msg.type === "remesh") {
      const t0 = performance.now();
      let ch = cache.get(msg.key);
      let genMs = 0;
      if (!ch) { ch = gen.chunk(msg.f, msg.cu, msg.cv, ID); genMs = performance.now() - t0; }
      remember(msg.key, ch);
      const t1 = performance.now();
      const r = meshChunk(ch, msg.walls);
      const meshMs = performance.now() - t1;
      self.postMessage({ type: "chunk", key: msg.key, gen: msg.gen, f: ch.f, x0: ch.x0, z0: ch.z0, ylo: ch.ylo, minH: ch.minH, maxH: ch.maxH,
        bands: r.bands, tris: r.tris, genMs, meshMs, walls: msg.walls }, r.transfer);
      return;
    }
    if (msg.type === "far") {
      // A low-detail sheet of terrain around the focus that bends over the cube's edges.
      const { face, u0, v0, radius, step } = msg;
      const n = Math.floor((2 * radius) / step) + 1;
      const pos = new Float32Array(n * n * 3), col = new Float32Array(n * n * 3), hs = new Float32Array(n * n);
      const p = [0, 0, 0], base = [0, 0, 0];
      gen.basePoint(face, u0, v0, base);
      for (let a = 0; a < n; a++) for (let b = 0; b < n; b++) {
        const L = gen.walkTo(face, u0 - radius + a * step, v0 - radius + b * step);
        const u = Math.max(0, Math.min(F - 1, L.u)), v = Math.max(0, Math.min(F - 1, L.v));
        const c = gen.columnAt(L.f, u, v);
        gen.basePoint(L.f, u, v, p);
        const N = gen.FACES[L.f].N;
        const top = Math.max(Math.floor(c.h) + 1, 0.875) - 0.7;
        const k = a * n + b;
        hs[k] = c.h;
        pos[k * 3] = p[0] + N[0] * top - base[0];
        pos[k * 3 + 1] = p[1] + N[1] * top - base[1];
        pos[k * 3 + 2] = p[2] + N[2] * top - base[2];
        const bc = gen.BIOMES[c.h < 0 && c.b !== 2 ? (c.h < -16 ? 0 : 1) : c.b][2];
        col[k * 3] = bc[0] / 255; col[k * 3 + 1] = bc[1] / 255; col[k * 3 + 2] = bc[2] / 255;
      }
      // simple slope shading from neighbouring heights
      for (let a = 0; a < n; a++) for (let b = 0; b < n; b++) {
        const k = a * n + b;
        const h = Math.max(hs[k], 0), hl = Math.max(hs[Math.max(0, a - 1) * n + b], 0), hu = Math.max(hs[a * n + Math.max(0, b - 1)], 0);
        const s = Math.max(0.7, Math.min(1.15, 1 + ((h - hl) + (h - hu)) * 0.012));
        col[k * 3] *= s; col[k * 3 + 1] *= s; col[k * 3 + 2] *= s;
      }
      const idx = new Uint32Array((n - 1) * (n - 1) * 6);
      let q = 0;
      for (let a = 0; a < n - 1; a++) for (let b = 0; b < n - 1; b++) {
        const i0 = a * n + b, i1 = (a + 1) * n + b, i2 = (a + 1) * n + b + 1, i3 = a * n + b + 1;
        idx[q++] = i0; idx[q++] = i3; idx[q++] = i2; idx[q++] = i0; idx[q++] = i2; idx[q++] = i1;
      }
      self.postMessage({ type: "far", id: msg.id, base, pos, col, idx }, [pos.buffer, col.buffer, idx.buffer]);
      return;
    }
    if (msg.type === "deep") {
      // a cut-out cube of the interior, meshed with all four sides open
      const r = gen.deepRegion(msg.f, msg.uc, msg.vc, msg.dMid, msg.size, ID);
      // cutaway: remove the corner nearest the camera so the inside shows
      const hx = r.SX >> 1, hz = r.SZ >> 1, hy = r.Y >> 1;
      for (let i = hx; i < r.SX; i++) for (let j = hz; j < r.SZ; j++) for (let y = hy; y < r.Y; y++) r.W[(i * r.SZ + j) * r.Y + y] = 0;
      const m = meshChunk(r, { nx: true, px: true, nz: true, pz: true });
      self.postMessage({ type: "deep", id: msg.id, size: msg.size, bands: m.bands, tris: m.tris }, m.transfer);
      return;
    }
    if (msg.type === "slice") {
      // a slice through the middle of the planet, one colour per pixel
      const { f, res, colors } = msg;
      const fc = gen.FACES[f], R = F / 2, ext = R + 64, img = new Uint8ClampedArray(res * res * 4);
      for (let py = 0; py < res; py++) for (let px = 0; px < res; px++) {
        const a = (px + 0.5) / res * 2 * ext - ext, b = ext - (py + 0.5) / res * 2 * ext;   // a along U, b along N (up)
        const x = fc.U[0] * a + fc.N[0] * b, y = fc.U[1] * a + fc.N[1] * b, z = fc.U[2] * a + fc.N[2] * b;
        const m = Math.max(Math.abs(x), Math.abs(y), Math.abs(z));
        let rgb = null;
        if (m <= R) rgb = colors[gen.deepBlock(x, y, z, ID)];
        else {
          const L = gen.locate(x, y, z);
          const c = gen.columnAt(L.f, Math.max(0, Math.min(F - 1, L.u)), Math.max(0, Math.min(F - 1, L.v)));
          if (L.alt <= c.h) rgb = gen.BIOMES[c.b][2];
          else if (L.alt <= 0) rgb = [44, 92, 168];
        }
        const k = (py * res + px) * 4;
        if (rgb) { img[k] = rgb[0]; img[k + 1] = rgb[1]; img[k + 2] = rgb[2]; img[k + 3] = 255; }
      }
      self.postMessage({ type: "slice", id: msg.id, res, ext, img }, [img.buffer]);
      return;
    }
    if (msg.type === "globe") {
      const res = msg.res, faces = [];
      const transfer = [];
      for (let f = 0; f < 6; f++) {
        const n = res + 1, h = new Float32Array(n * n), c = new Uint8Array(n * n * 3);
        for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
          const u = i * F / res - 0.5, v = j * F / res - 0.5;   // exact face edges at i = 0 and i = res
          const col = gen.columnAt(f, u, v), k = i * n + j;
          h[k] = col.h;
          let bc = gen.BIOMES[col.b][2], s = 1;
          if (col.h < 0) s = 1 + Math.max(col.h, -46) / 110;
          else s = 0.92 + Math.min(col.h, 100) / 600;
          c[k * 3] = Math.min(255, bc[0] * s); c[k * 3 + 1] = Math.min(255, bc[1] * s); c[k * 3 + 2] = Math.min(255, bc[2] * s);
        }
        faces.push({ h, c });
        transfer.push(h.buffer, c.buffer);
      }
      self.postMessage({ type: "globe", id: msg.id, res, faces }, transfer);
    }
  };
})();
