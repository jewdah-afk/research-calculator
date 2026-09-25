/* camera.js: the Realm camera contract. Pure math, no dependencies.
 *
 *   const RC = require('./camera.js')          // node
 *   <script src="camera.js"></script>          // browser: window.RealmCamera
 *
 *   node camera.js --test      brute-force coverage + identities + tiles + sprites (exit code 1 on failure)
 *   node camera.js --build     recompute every derived field of realm.json from its inputs
 *   node camera.js --report    print the layer / tier / memory table
 *
 * The model (REALM.md section 2 has the derivation):
 *   V  viewport in map points, Vc = V/2         C  camera centre, world px        z  world zoom
 *   layer L = { f, w, h, anchor A = (w/2, h/2) }  (local px: 1 local px = 1 screen point when the layer zoom is 1)
 *   layer zoom      s = z / (f + (1 - f) z)       the dolly law: s = 1 at z = 1, ds/dz = f there (like z^f), and a
 *                                                 layer behind the world never outruns it (z^f does below z ~ 0.3)
 *   centre point    P = A + f (C - Wc)            the local point under the screen centre
 *   local -> screen x_s = Vc + s (p - P)          container origin O = Vc - s P, container size = s (w, h)
 *   visible rect    P +- V / (2 s)
 *   zMin(V) = max(V.w / 3840, V.h / 2560)         "cover": the world always fills the viewport
 * The world (f = 1, 3840 x 2560, A = Wc) gives P = C and x_s = Vc + z (p - C).
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.RealmCamera = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  // ------------------------------------------------------------------------------------------------ contract constants
  // realm.json repeats these; `--test` fails if they ever disagree.
  const WORLD = Object.freeze({ w: 3840, h: 2560, cx: 1920, cy: 1280 });
  const Z_MAX = 1.25;
  const ZOOM_SLACK = 0.06;   // rubber-band zoom may overshoot [zMin, zMax] by this fraction while a pinch/wheel settles
  const OVERSCROLL = 72;     // rubber-band pan may overshoot the pan limit by this many map points
  const DOMAIN = Object.freeze({ minW: 568, minH: 320, maxW: 2560, maxH: 1440, minAspect: 0.45, maxAspect: 3.6 });
  const TILE = Object.freeze({ maxImage: 1024, gutter: 2, maxContent: 1020, penaltyPx: 20000 });

  const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);
  const lerp = (a, b, t) => a + (b - a) * t;
  const smoothstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
  const mod = (a, n) => ((a % n) + n) % n;

  // ------------------------------------------------------------------------------------------------ viewport
  /** Map-point viewport for a device viewport (pixels/points as Roblox reports them).
   *  Keeps V inside DOMAIN: big screens are scaled up (UIScale > 1), tiny ones down (UIScale < 1), extreme aspect
   *  ratios are letterboxed. Returns { scale, w, h, box: { w, h } } where box is the device-space size of the map. */
  function mapScale(Vpx, dom = DOMAIN) {
    let bw = Vpx.w, bh = Vpx.h;
    if (bw / bh > dom.maxAspect) bw = bh * dom.maxAspect;
    if (bw / bh < dom.minAspect) bh = bw / dom.minAspect;
    let s = 1;
    if (bw > dom.maxW || bh > dom.maxH) s = Math.max(bw / dom.maxW, bh / dom.maxH);
    else if (bw < dom.minW || bh < dom.minH) s = Math.min(bw / dom.minW, bh / dom.minH);
    return { scale: s, w: bw / s, h: bh / s, box: { w: bw, h: bh } };
  }
  function inDomain(V, dom = DOMAIN, eps = 1e-6) {
    const a = V.w / V.h;
    return V.w >= dom.minW - eps && V.w <= dom.maxW + eps && V.h >= dom.minH - eps && V.h <= dom.maxH + eps &&
      a >= dom.minAspect - eps && a <= dom.maxAspect + eps;
  }

  // ------------------------------------------------------------------------------------------------ zoom
  /** Layer zoom for world zoom z. A camera dollying toward a stack of planes: plane depth d_L = d_world / f, so a
   *  layer's scale is z / (f + (1 - f) z). Its screen speed relative to the world, f s / z = f / (f + (1 - f) z), is
   *  < 1 for every f < 1 and > 1 for every f > 1 at any zoom: depth order never flips. */
  const layerZoom = (f, z) => z / (f + (1 - f) * z);
  /** Inverse: the world zoom at which layer f has scale s. */
  const layerZoomInverse = (f, s) => (s * f) / (1 - s * (1 - f));
  /** The smallest zoom at which the world still covers the viewport (the world's full width on screens wider
   *  than 3:2, its full height on narrower ones). */
  function zMin(V, world = WORLD, zMax = Z_MAX) { return Math.min(zMax, Math.max(V.w / world.w, V.h / world.h)); }
  /** Allowed zoom interval. slack = true adds the rubber-band overshoot. */
  function zoomRange(V, { slack = false, zMax = Z_MAX, zoomSlack = ZOOM_SLACK, world = WORLD } = {}) {
    const lo = zMin(V, world, zMax), k = slack ? zoomSlack : 0;
    return { lo: lo * (1 - k), hi: zMax * (1 + k) };
  }

  // ------------------------------------------------------------------------------------------------ layers
  const anchorOf = L => ({ x: L.ax != null ? L.ax : L.w / 2, y: L.ay != null ? L.ay : L.h / 2 });
  /** Local point under the screen centre. */
  function layerCenter(L, C, world = WORLD) {
    const A = anchorOf(L);
    return { x: A.x + L.f * (C.x - world.cx), y: A.y + L.f * (C.y - world.cy) };
  }
  /** Where the layer container goes: screen position of local (0,0), its zoom, and its on-screen size. */
  function layerOffset(L, C, z, V, world = WORLD) {
    const s = layerZoom(L.f, z), P = layerCenter(L, C, world);
    return { x: V.w / 2 - s * P.x, y: V.h / 2 - s * P.y, scale: s, w: L.w * s, h: L.h * s };
  }
  /** Layer-local rect the viewport shows. */
  function visibleRect(L, C, z, V, world = WORLD) {
    const s = layerZoom(L.f, z), P = layerCenter(L, C, world), hw = V.w / (2 * s), hh = V.h / (2 * s);
    return { x0: P.x - hw, y0: P.y - hh, x1: P.x + hw, y1: P.y + hh };
  }
  function localToScreen(L, C, z, V, p, world = WORLD) {
    const s = layerZoom(L.f, z), P = layerCenter(L, C, world);
    return { x: V.w / 2 + s * (p.x - P.x), y: V.h / 2 + s * (p.y - P.y) };
  }
  function screenToLocal(L, C, z, V, q, world = WORLD) {
    const s = layerZoom(L.f, z), P = layerCenter(L, C, world);
    return { x: P.x + (q.x - V.w / 2) / s, y: P.y + (q.y - V.h / 2) / s };
  }
  const worldLayer = (world = WORLD) => ({ f: 1, w: world.w, h: world.h });
  const worldToScreen = (C, z, V, p, world = WORLD) => localToScreen(worldLayer(world), C, z, V, p, world);
  const screenToWorld = (C, z, V, q, world = WORLD) => screenToLocal(worldLayer(world), C, z, V, q, world);
  /** Camera centre after zooming z -> z2 about screen point S (the world point under S stays put). */
  function zoomAt(C, z, z2, S, V) {
    const qx = C.x + (S.x - V.w / 2) / z, qy = C.y + (S.y - V.h / 2) / z;
    return { x: qx - (S.x - V.w / 2) / z2, y: qy - (S.y - V.h / 2) / z2 };
  }

  // ------------------------------------------------------------------------------------------------ clamping
  /** Range of camera centres at zoom z. overscroll is in map points (the rubber band), 0 for the hard limit. */
  function panLimits(z, V, { overscroll = 0, world = WORLD } = {}) {
    const hw = V.w / (2 * z), hh = V.h / (2 * z), o = overscroll / z;
    const ax = 2 * hw <= world.w ? [hw, world.w - hw] : [world.cx, world.cx];
    const ay = 2 * hh <= world.h ? [hh, world.h - hh] : [world.cy, world.cy];
    return { x0: ax[0] - o, x1: ax[1] + o, y0: ay[0] - o, y1: ay[1] + o };
  }
  /** Hard clamp (default) or the rubber-band envelope ({ rubber: true }). Returns { x, y, z }. */
  function clampCamera(C, z, V, { rubber = false, zMax = Z_MAX, world = WORLD } = {}) {
    const r = zoomRange(V, { slack: rubber, zMax, world });
    const zz = clamp(z, r.lo, r.hi);
    const lim = panLimits(zz, V, { overscroll: rubber ? OVERSCROLL : 0, world });
    return { x: clamp(C.x, lim.x0, lim.x1), y: clamp(C.y, lim.y0, lim.y1), z: zz };
  }
  /** iOS-style resistance: raw overshoot x (>= 0, map points) -> displayed overshoot, approaching d asymptotically. */
  const rubberBand = (x, d = OVERSCROLL, c = 0.55) => d * (1 - 1 / (x * c / d + 1));

  // ------------------------------------------------------------------------------------------------ required size
  /** Largest distance from the anchor that layer f ever shows, per axis, over every allowed (C, z, V): pan and zoom
   *  include the rubber-band slack; layers with zHide are only checked where they are visible (z >= zHide).
   *  For a given z the extent f*D + V/(2 s) is piecewise linear in V, so only the ends of the feasible V interval
   *  and the kink V = world*z are candidates; z is sampled densely (log spaced) and the result gets +0.25%. */
  function requiredSize(f, { zHide = 0, zMax = Z_MAX, zoomSlack = ZOOM_SLACK, overscroll = OVERSCROLL, dom = DOMAIN,
    world = WORLD, steps = 24000 } = {}) {
    const zHi = zMax * (1 + zoomSlack), k = 1 - zoomSlack;
    let best = { x: 0, y: 0, wx: null, wy: null };
    const zLo = Math.max(1e-3, Math.min(dom.minW / world.w, dom.minH / world.h) * k * 0.9, zHide);
    const ext = (half, span, z) => f * (Math.max(0, span / 2 - half / z) + overscroll / z) + half / layerZoom(f, z);
    for (let i = 0; i <= steps; i++) {
      const z = Math.exp(Math.log(zLo) + (Math.log(zHi) - Math.log(zLo)) * i / steps);
      if (z < zHide) continue;
      // x: Vw feasible if some Vh makes (Vw, Vh) a domain viewport whose zoom range reaches down to z
      const wLo = Math.max(dom.minW, dom.minAspect * dom.minH);
      const wHi = Math.min(dom.maxW, world.w * z / k, dom.maxAspect * dom.maxH, dom.maxAspect * world.h * z / k);
      if (wHi >= wLo && z >= dom.minH * k / world.h) for (const vw of [wLo, wHi, clamp(world.w * z, wLo, wHi)]) {
        const e = ext(vw / 2, world.w, z); if (e > best.x) best = { ...best, x: e, wx: { V: vw, z } };
      }
      const hLo = Math.max(dom.minH, dom.minW / dom.maxAspect);
      const hHi = Math.min(dom.maxH, world.h * z / k, dom.maxW / dom.minAspect, world.w * z / k / dom.minAspect);
      if (hHi >= hLo && z >= dom.minW * k / world.w) for (const vh of [hLo, hHi, clamp(world.h * z, hLo, hHi)]) {
        const e = ext(vh / 2, world.h, z); if (e > best.y) best = { ...best, y: e, wy: { V: vh, z } };
      }
    }
    const m = 1.0025;
    return { w: Math.ceil(2 * best.x * m), h: Math.ceil(2 * best.y * m), worst: { x: best.wx, y: best.wy } };
  }

  // ------------------------------------------------------------------------------------------------ tiling
  const isInt = (x) => Math.abs(x - Math.round(x)) < 1e-9;
  /** Uniform tile grid for a layer rendered at scale s (texture px = local px * s).
   *  Tile content tw x th (texture px, even, <= maxContent, tw/s and th/s whole local px); the layer size becomes
   *  nx*tw/s x ny*th/s >= required. Minimises texture pixels (tiles include a gutter on every side) + a per-tile cost.
   *  fixed = { w, h } forces an exact local size (the world). LOW = s/2 merges 2x2 HIGH tiles into one. */
  function planTiles(req, s, { fixed = null, tile = TILE } = {}) {
    const g = tile.gutter, maxC = Math.min(tile.maxContent, tile.maxImage - 2 * g);
    const axis = (need, exact) => {
      const out = [];
      for (let t = 64; t <= maxC; t += 2) {
        if (!isInt(t / s)) continue;
        const loc = Math.round(t / s);
        if (exact != null) { if (exact % loc) continue; out.push({ t, n: exact / loc, loc }); }
        else out.push({ t, n: Math.ceil(need / loc - 1e-9), loc });
      }
      return out;
    };
    let best = null;
    for (const a of axis(req.w, fixed && fixed.w)) for (const b of axis(req.h, fixed && fixed.h)) {
      const n = a.n * b.n, cost = n * ((a.t + 2 * g) * (b.t + 2 * g) + tile.penaltyPx);
      if (!best || cost < best.cost - 1e-6 || (Math.abs(cost - best.cost) < 1e-6 && a.t * b.t > best.tw * best.th))
        best = { cost, tw: a.t, th: b.t, nx: a.n, ny: b.n, lw: a.loc, lh: b.loc };
    }
    if (!best) throw new Error('no tile plan for ' + JSON.stringify({ req, s, fixed }));
    const hi = { scale: s, nx: best.nx, ny: best.ny, tiles: best.nx * best.ny, texture: [best.nx * best.tw, best.ny * best.th] };
    const cols = [], rows = [];
    for (let i = 0; i < Math.ceil(best.nx / 2); i++) cols.push(Math.min(2, best.nx - 2 * i) * best.tw / 2);
    for (let j = 0; j < Math.ceil(best.ny / 2); j++) rows.push(Math.min(2, best.ny - 2 * j) * best.th / 2);
    const lo = { scale: s / 2, nx: cols.length, ny: rows.length, tiles: cols.length * rows.length, texture: [hi.texture[0] / 2, hi.texture[1] / 2], cols, rows };
    const bytes = (cw, ch) => (cw + 2 * g) * (ch + 2 * g) * 4;
    hi.bytes = hi.tiles * bytes(best.tw, best.th);
    lo.bytes = 0; for (const c of cols) for (const r of rows) lo.bytes += bytes(c, r);
    return { size: { w: best.nx * best.lw, h: best.ny * best.lh }, tile: { w: best.tw, h: best.th, gutter: g },
      cell: { w: best.lw, h: best.lh }, HIGH: hi, LOW: lo };
  }
  /** Tile rects for a tier: local rect (display) + texture rect (inside the uploaded image, gutter excluded). */
  function tileRects(layer, tier) {
    const g = layer.tiles.gutter, T = layer.grid[tier], s = T.scale, out = [];
    const cols = T.cols || Array(T.nx).fill(layer.tiles.w), rows = T.rows || Array(T.ny).fill(layer.tiles.h);
    let ty = 0;
    rows.forEach((rh, j) => {
      let tx = 0;
      cols.forEach((cw, i) => {
        out.push({ i, j, tex: { x: tx, y: ty, w: cw, h: rh }, image: { w: cw + 2 * g, h: rh + 2 * g }, rectOffset: [g, g],
          local: { x: tx / s, y: ty / s, w: cw / s, h: rh / s } });
        tx += cw;
      });
      ty += rh;
    });
    return out;
  }

  // ------------------------------------------------------------------------------------------------ biome
  const REF_VIEW = Object.freeze({ w: 1920, h: 1080 });
  /** Share of the visible world rect (camera C, zoom z, map-point viewport V) that rect r = [x0, y0, x1, y1] covers. */
  function viewCover(r, C, z, V) {
    const hw = V.w / (2 * z), hh = V.h / (2 * z);
    const ix = Math.max(0, Math.min(C.x + hw, r[2]) - Math.max(C.x - hw, r[0]));
    const iy = Math.max(0, Math.min(C.y + hh, r[3]) - Math.max(C.y - hh, r[1]));
    return (ix * iy) / (4 * hw * hh);
  }
  /** Biome weights for camera (C, z) and viewport V (map points), each in [0, 1]:
   *    rift    = smoothstep(rift.from, rift.to, C.x)                      the camera centre crosses the tree -> rift line
   *    corrupt = rift * smoothstep(cover[0], cover[1], share of the view the outcrop rect covers)
   *  The corrupt accent depends on what is on screen, not on the centre: the hard clamp keeps a desktop camera centre
   *  at x <= 3840 - V.w/(2z), far left of the outcrop, but at the east limit the outcrop fills 15-35% of the view.
   *  z and V are required for the real weight; without them (old two-argument callers) z = C.z or 1, V = 1920x1080. */
  function biome(C, B, z, V) {
    if (z == null) z = C.z != null ? C.z : 1;
    if (!V) V = REF_VIEW;
    const rift = smoothstep(B.rift.from, B.rift.to, C.x);
    const c = B.corrupt, cover = viewCover(c.rect, C, z, V);
    const corrupt = rift * smoothstep(c.cover[0], c.cover[1], cover);
    return { rift, corrupt, cover };
  }
  /** The outcrop's light at world point p, in [0, 1]: 1 - smoothstep(falloff, |(p - focus) / radius|). Corrupt colours
   *  are laid next to the crimson where this is high (juxtaposed), never mixed over the whole screen: green and
   *  crimson are complements, and a global blend of the two reads as grey. */
  function corruptLight(B, p) {
    const c = B.corrupt, L = c.light;
    const d = Math.hypot((p.x - c.focus[0]) / L.radius[0], (p.y - c.focus[1]) / L.radius[1]);
    return 1 - smoothstep(L.falloff[0], L.falloff[1], d);
  }
  /** Layer-local centre of a corrupt bloom on layer Lg ({ f, w, h }): the spot behind the focus as seen from the
   *  bloom reference camera [x, y, z] (the east limit), so the glow sits behind the outcrop where the player sees it. */
  function bloomLocal(Lg, B, world = WORLD) {
    const c = B.corrupt, [cx, cy, cz] = c.bloom.camera, s = layerZoom(Lg.f, cz), P = layerCenter(Lg, { x: cx, y: cy }, world);
    return { x: P.x + (cz / s) * (c.focus[0] - cx), y: P.y + (cz / s) * (c.focus[1] - cy) };
  }
  const mixRGB = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
  const WHITE = Object.freeze([255, 255, 255]);
  /** The biome colours of REALM.md 5, one function per consumer (the client and the preview both call these).
   *  Tile tint (multiply) of a layer with tint { rift }: mix(white, rift, w.rift). No corrupt term: the corrupt accent
   *  never tints tiles (tint.corrupt is retired). The world (tint null) stays white. */
  function biomeTint(tint, w) { return tint ? mixRGB(WHITE, tint.rift, w.rift) : [255, 255, 255]; }
  /** The full-screen wash between mid and near: { color, alpha }, from the realm and rift entries only. */
  function biomeWash(W, w) { return { color: mixRGB(W.realm.color, W.rift.color, w.rift), alpha: lerp(W.realm.alpha, W.rift.alpha, w.rift) }; }
  /** A sprite with a colour object { realm, rift, corrupt }, whose on-screen centre lies over world point p:
   *  mix(mix(realm, rift, w.rift), corrupt, w.corrupt * corruptLight(B, p)). */
  function biomeSpriteColor(color, w, B, p) {
    return mixRGB(mixRGB(color.realm, color.rift, w.rift), color.corrupt, w.corrupt * corruptLight(B, p));
  }
  /** A field particle (palette index c, threshold cg) of kind { palette, rift, corrupt } over world point p: the rift mix of
   *  its palette colour, switched to kind.corrupt around its own threshold, smoothstep(cg - 0.12, cg + 0.12, g) with
   *  g = w.corrupt * light(p). Neighbouring particles switch at different g, so green and ember sit side by side. */
  function biomeFieldColor(kind, c, cg, w, B, p) {
    const g = w.corrupt * corruptLight(B, p), base = mixRGB(kind.palette[c % kind.palette.length], kind.rift, w.rift);
    return mixRGB(base, kind.corrupt, smoothstep(cg - 0.12, cg + 0.12, g));
  }
  /** Draw state of a corrupt bloom entry { local, size, color, alpha }: null when hidden (w.corrupt = 0). */
  function bloomState(entry, w) {
    const a = entry.alpha * w.corrupt;
    return a > 0 ? { x: entry.local[0], y: entry.local[1], w: entry.size[0], h: entry.size[1], color: entry.color, alpha: a } : null;
  }

  // ------------------------------------------------------------------------------------------------ rng / hashing
  function rng(seed) { // mulberry32, identical to lib.js
    return function () {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  const hash01 = (a, b = 0) => rng((a * 374761393 + b * 668265263) | 0)();

  // ------------------------------------------------------------------------------------------------ motion
  // Every animated channel is a closed form of time t (seconds). The Roblox client plays the same curve with
  // TweenService (REALM.md 6.2 gives the TweenInfo for each type); the preview renderer evaluates these directly.
  const EASE = {
    linear: u => u,
    quadOut: u => 1 - (1 - u) * (1 - u),
    quintOut: u => 1 - Math.pow(1 - u, 5),
    sineInOut: u => -(Math.cos(Math.PI * u) - 1) / 2,
  };
  /** One channel instance -> value to ADD to the base (x, y, rot, scale) or the absolute value (alpha, grad). */
  function channel(m, t) {
    switch (m.type) {
      case 'sine': return m.amp * Math.sin(2 * Math.PI * (t / m.period + m.phase));
      case 'drift': { const span = m.to - m.from; return m.from + mod(m.speed * t + m.phase * span, span); }
      case 'pulse': { // one eased run a -> b of length dur, then hold at b until the period ends
        const u = mod(t / m.period + m.phase, 1) * m.period;
        return u < m.dur ? lerp(m.a, m.b, EASE[m.ease || 'quadOut'](u / m.dur)) : m.b;
      }
      case 'scroll': return -1 + 2 * mod(t / m.period + m.phase, 1);
      case 'flicker': { // at most one burst per slot of length `slot`; burst lasts dur; returns 0/1 (on) or jitter
        const k = Math.floor(t / m.slot), start = k * m.slot + hash01(m.seed, k) * (m.slot - m.dur);
        const on = t >= start && t < start + m.dur ? 1 : 0;
        return m.out === 'jitter' ? on * (hash01(m.seed + 1, k) - 0.5) * 2 * m.amp : on;
      }
      default: throw new Error('unknown motion type ' + m.type);
    }
  }
  /** Evaluate all channels of a sprite instance: { dx, dy, rot, scale, alpha, grad }. */
  function spriteState(inst, t) {
    const o = { dx: 0, dy: 0, rot: 0, scale: 1, alpha: inst.a != null ? inst.a : 1, grad: 0 };
    for (const m of inst.m || []) {
      const v = channel(m, t);
      if (m.ch === 'x') o.dx += v; else if (m.ch === 'y') o.dy += v; else if (m.ch === 'rot') o.rot += v;
      else if (m.ch === 'scale') o.scale = m.type === 'pulse' ? v : o.scale + v;
      else if (m.ch === 'alpha') o.alpha = m.type === 'pulse' ? v : m.type === 'flicker' ? o.alpha * v : o.alpha + v;
      else if (m.ch === 'grad') o.grad = v;
    }
    o.alpha = clamp(o.alpha, 0, 1);
    return o;
  }

  // ------------------------------------------------------------------------------------------------ particle fields
  // A field is a pattern that repeats every cell (cw x ch local px) on a layer of factor f, with no edges: the client
  // draws the copies of each particle that fall in the visible rect. Zoom thinning keeps the on-screen count about
  // constant: particle i is shown only when z >= tau_i, where s(tau_i) = s(zFull) sqrt(u_i), u_i ~ U(0,1], so for
  // z <= zFull   E[count] = (V.w V.h / (cell area s^2)) * n * (s / s(zFull))^2 = V.w V.h n / (cell area s(zFull)^2).
  // The cell is never smaller than a screen: while the field's alpha is >= cellCover, every domain viewport shows
  // less than one cell (minus the largest particle), so no particle is ever drawn twice on one screen (a repeat that
  // the eye catches at once with big bokeh). The count formula above does not depend on the cell size.
  /** Zoom at which smoothstep(zHide, zShow, z) reaches alpha (0 when the field is always fully visible). */
  function fieldAlphaZoom(field, alpha) {
    if (!(field.zShow > field.zHide) || field.zHide <= 0) return 0;
    let lo = 0, hi = 1;
    for (let i = 0; i < 60; i++) { const m = (lo + hi) / 2; if (m * m * (3 - 2 * m) < alpha) lo = m; else hi = m; }
    return field.zHide + (field.zShow - field.zHide) * hi;
  }
  /** Largest layer-local rect (w, h) that any domain viewport shows on a layer of factor f at any allowed zoom >= zFrom
   *  (the rubber-band minimum included). V / s(z) falls with z, so the worst zoom is max(zoomRange.lo, zFrom), and the
   *  worst viewport keeps the other side as small as the domain allows (it lowers zMin); both sides are scanned. */
  function visibleExtent(f, zFrom = 0, { dom = DOMAIN, world = WORLD } = {}) {
    const best = { w: 0, h: 0, atW: null, atH: null };
    const ev = V => {
      if (!inDomain(V, dom)) return;
      const z = Math.max(zoomRange(V, { slack: true, world }).lo, zFrom), s = layerZoom(f, z);
      if (V.w / s > best.w) { best.w = V.w / s; best.atW = { V: { w: V.w, h: V.h }, z }; }
      if (V.h / s > best.h) { best.h = V.h / s; best.atH = { V: { w: V.w, h: V.h }, z }; }
    };
    for (let w = dom.minW; w <= dom.maxW; w += 1) ev({ w, h: Math.max(dom.minH, w / dom.maxAspect) });
    for (let h = dom.minH; h <= dom.maxH; h += 1) ev({ w: Math.max(dom.minW, h * dom.minAspect), h });
    ev({ w: dom.maxW, h: Math.max(dom.minH, dom.maxW / dom.maxAspect) }); ev({ w: Math.max(dom.minW, dom.maxH * dom.minAspect), h: dom.maxH });
    return best;
  }
  /** Particles of one cell at time t: local position inside [0,cw) x [0,ch) (drift wraps inside the cell, so the
   *  neighbouring copy takes over exactly where this one leaves: seamless). */
  function fieldLocal(p, cell, t) {
    const x = mod(p.x + p.vx * t, cell.w) + (p.bx ? p.bx * Math.sin(2 * Math.PI * (t / p.bt + p.bp)) : 0);
    const y = mod(p.y + p.vy * t, cell.h) + (p.by ? p.by * Math.sin(2 * Math.PI * (t / p.bt + p.bp + 0.25)) : 0);
    return { x, y };
  }
  /** Screen-space sprites of a field for camera (C, z, V) at time t.
   *  Returns [{ i, x, y, size, alpha }] (screen points, size = diameter). */
  function fieldPlace(field, C, z, V, t, { world = WORLD } = {}) {
    const vis = smoothstep(field.zHide, field.zShow, z);
    if (vis <= 0) return [];
    const L = { f: field.f, w: 0, h: 0, ax: 0, ay: 0 }, s = layerZoom(field.f, z);
    const R = visibleRect(L, C, z, V, world), cell = field.cell, pad = field.maxSize / 2 + field.maxBob;
    const out = [];
    const i0 = Math.floor((R.x0 - pad) / cell.w), i1 = Math.floor((R.x1 + pad) / cell.w);
    const j0 = Math.floor((R.y0 - pad) / cell.h), j1 = Math.floor((R.y1 + pad) / cell.h);
    field.particles.forEach((p, k) => {
      if (z < p.tau) return;
      const a = vis * smoothstep(p.tau, p.tau * 1.12, z) * (p.a + (p.ta ? p.ta * Math.sin(2 * Math.PI * (t / p.tt + p.tp)) : 0));
      if (a <= 0.004) return;
      const q = fieldLocal(p, cell, t);
      for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) {
        const lx = i * cell.w + q.x, ly = j * cell.h + q.y, r = p.size / 2;
        if (lx + r < R.x0 || lx - r > R.x1 || ly + r < R.y0 || ly - r > R.y1) continue;
        const sc = localToScreen(L, C, z, V, { x: lx, y: ly }, world);
        out.push({ i: k, x: sc.x, y: sc.y, size: p.size * s, alpha: a, kind: p.k });
      }
    });
    return out;
  }
  /** Incremental form (what a per-frame client does without recomputing from the camera): a point at screen offset u
   *  from the centre moves, when the camera goes (C0, z0) -> (C1, z1), to u (s1/s0) - s1 f (C1 - C0).  Exact. */
  function fieldStep(u, f, C0, z0, C1, z1) {
    const s0 = layerZoom(f, z0), s1 = layerZoom(f, z1);
    return { x: u.x * s1 / s0 - s1 * f * (C1.x - C0.x), y: u.y * s1 / s0 - s1 * f * (C1.y - C0.y) };
  }

  return {
    WORLD, Z_MAX, ZOOM_SLACK, OVERSCROLL, DOMAIN, TILE,
    clamp, lerp, smoothstep, mod, rng, hash01, EASE, mixRGB,
    mapScale, inDomain, layerZoom, layerZoomInverse, zMin, zoomRange, anchorOf, layerCenter, layerOffset, visibleRect,
    localToScreen, screenToLocal, worldToScreen, screenToWorld, zoomAt, panLimits, clampCamera, rubberBand,
    requiredSize, planTiles, tileRects, viewCover, biome, corruptLight, bloomLocal, biomeTint, biomeWash, biomeSpriteColor,
    biomeFieldColor, bloomState, channel, spriteState, fieldAlphaZoom, visibleExtent,
    fieldLocal, fieldPlace, fieldStep,
  };
});

// ==================================================================================================== CLI (node only)
// Everything below runs only as `node camera.js ...`; a browser page (or require()) sees just window.RealmCamera.
if (typeof require !== 'undefined' && typeof module !== 'undefined' && require.main === module) (function cli() {
  const RC = module.exports, fs = require('fs'), path = require('path');
  const FILE = path.join(__dirname, 'realm.json');
  const mode = process.argv[2] || '--test';
  if (mode === '--build') build(RC, fs, FILE);
  else if (mode === '--report') report(RC, JSON.parse(fs.readFileSync(FILE, 'utf8')));
  else if (mode === '--test') process.exit(test(RC, fs, FILE) ? 0 : 1);
  else { console.log('usage: node camera.js --test | --build | --report'); process.exit(2); }

// ---------------------------------------------------------------------------------------------------- build
function build(RC, fs, FILE) {
  const R = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  const W = RC.WORLD;
  const round = (x, d = 1) => Math.round(x * 10 ** d) / 10 ** d;
  const nodes = Object.entries(R.nodes).map(([id, [x, y]]) => ({ id, x, y }));
  const fp = R.readability.footprint;                                // node footprint in world px (ring + nameplate)
  const zRef = R.readability.zoomRange, Vref = { w: R.readability.refViewport[0], h: R.readability.refViewport[1] };
  const zs = []; for (let i = 0; i <= 64; i++) zs.push(zRef[0] * Math.pow(zRef[1] / zRef[0], i / 64));

  // ---- layers: required size, tiles, anchors, landmarks, biome split, keep-clear
  let memHi = 0, memLo = 0, tilesHi = 0, tilesLo = 0;
  for (const L of R.layers) {
    const req = L.fixedSize ? { w: L.fixedSize[0], h: L.fixedSize[1], worst: null }
      : RC.requiredSize(L.f, { zHide: L.zHide || 0 });
    L.required = { w: req.w, h: req.h, worstCase: req.worst && {
      x: `V.w=${round(req.worst.x.V)} z=${round(req.worst.x.z, 3)}`, y: `V.h=${round(req.worst.y.V)} z=${round(req.worst.y.z, 3)}` } };
    const plan = RC.planTiles(req, L.res.HIGH, { fixed: L.fixedSize ? { w: L.fixedSize[0], h: L.fixedSize[1] } : null });
    L.size = [plan.size.w, plan.size.h];
    L.anchor = [plan.size.w / 2, plan.size.h / 2];
    L.res.LOW = L.res.HIGH / 2;
    L.tiles = plan.tile; L.tileCell = [plan.cell.w, plan.cell.h];
    L.grid = { HIGH: plan.HIGH, LOW: plan.LOW };
    L.memoryMB = { HIGH: round(plan.HIGH.bytes / 1048576, 2), LOW: round(plan.LOW.bytes / 1048576, 2) };
    memHi += plan.HIGH.bytes; memLo += plan.LOW.bytes; tilesHi += plan.HIGH.tiles; tilesLo += plan.LOW.tiles;
    const Lg = { f: L.f, w: plan.size.w, h: plan.size.h };
    const aligned = (X, Y) => RC.layerCenter(Lg, { x: X, y: Y });
    L.landmarks = {};
    for (const [k, [X, Y]] of Object.entries(R.landmarks)) { const p = aligned(X, Y); L.landmarks[k] = [round(p.x), round(p.y)]; }
    const b = R.biomes, split = aligned((b.rift.from + b.rift.to) / 2, W.cy).x;
    L.biomeLocal = { splitX: round(split), fadeHalfWidth: Math.round(RC.lerp(900, 150, Math.min(1, L.f))),
      note: 'paint the rift palette (hazeRift, crimson glow) from splitX - fadeHalfWidth to splitX + fadeHalfWidth and beyond' };
    // keep-clear: hard = footprint behind/in front of each node when the camera is centred on it (any zoom in zRef);
    // soft = hard + the drift of that spot while the node stays in the central 30% of the reference viewport
    // The spot behind a node is P + (z / s)(N - C) = A + f(N - Wc) + (f - z/s)(C - N); the footprint scales by z/s.
    // Hard: C = N, worst zoom. Soft: C within 30% of the reference half-viewport of N, worst zoom.
    const kHard = Math.max(...zs.map(z => z / RC.layerZoom(L.f, z)));
    let softX = 0, softY = 0;
    for (const z of zs) {
      const k = z / RC.layerZoom(L.f, z), c = Math.abs(L.f - k);
      softX = Math.max(softX, fp.rx * k + c * 0.3 * Vref.w / (2 * z));
      softY = Math.max(softY, fp.ry * k + c * 0.3 * Vref.h / (2 * z));
    }
    L.keepClear = {
      format: '[node, cx, cy, rx, ry] ellipses in layer-local px',
      rule: L.keepClearRule,
      hard: nodes.map(n => { const p = aligned(n.x, n.y + fp.dy); return [n.id, round(p.x), round(p.y), Math.ceil(fp.rx * kHard), Math.ceil(fp.ry * kHard)]; }),
      soft: nodes.map(n => { const p = aligned(n.x, n.y + fp.dy); return [n.id, round(p.x), round(p.y), Math.ceil(softX), Math.ceil(softY)]; }),
    };
  }

  // ---- corrupt bloom: the layer-local centre of each glow (behind the outcrop, seen from the bloom reference camera)
  for (const bl of R.biomes.corrupt.bloom.layers) {
    const L = R.layers.find(l => l.id === bl.layer), p = RC.bloomLocal({ f: L.f, w: L.size[0], h: L.size[1] }, R.biomes);
    bl.local = [round(p.x), round(p.y)];
  }

  // ---- sprites: deterministic instances (HIGH list; LOW = the first count.LOW of them)
  const layerById = Object.fromEntries(R.layers.map(L => [L.id, L]));
  const pick = (r, v) => (Array.isArray(v) ? v[0] + (v[1] - v[0]) * r() : v);
  for (const S of R.sprites) {
    const L = layerById[S.layer], r = RC.rng(S.seed), inst = [], [lw, lh] = L.size;
    const norm = q => (S.place.regionsNorm ? [q[0] * lw, q[1] * lh, q[2] * lw, q[3] * lh] : q);
    const regions = (S.place.regions || []).map(q => (q === 'layer' ? [0, 0, lw, lh] : norm(q)));
    const excl = (S.excludeNorm || []).map(([fx, fy, rr]) => [fx * lw, fy * lh, rr]);
    const regionPt = () => {
      const areas = regions.map(q => (q[2] - q[0]) * (q[3] - q[1])), tot = areas.reduce((a, b) => a + b, 0);
      let u = r() * tot, k = 0; while (k < areas.length - 1 && u > areas[k]) { u -= areas[k]; k++; }
      const q = regions[k]; return [pick(r, [q[0], q[2]]), pick(r, [q[1], q[3]])];
    };
    const Lg = { f: L.f, w: lw, h: lh };
    // anchorsWorld: [X, Y, len] world points, placed on this layer where they sit behind/in front of that point when the
    // camera is centred on it; anchorsRel: [dx, dy, len] local offsets from the layer anchor (the spot behind Wc)
    const anchors = S.place.mode === 'anchorsWorld'
      ? S.place.anchors.map(([X, Y, len]) => { const p = RC.layerCenter(Lg, { x: X, y: Y }); return [p.x, p.y, len]; })
      : S.place.mode === 'anchorsRel' ? S.place.anchors.map(([dx, dy, len]) => [lw / 2 + dx, lh / 2 + dy, len]) : null;
    let tries = 0, ai = 0;
    while (inst.length < S.count.HIGH && tries < 40000) {
      tries++;
      let x, y, len;
      if (anchors) { if (ai >= anchors.length) break; [x, y, len] = anchors[ai++]; } else [x, y] = regionPt();
      const o = { x: round(x), y: round(y), s: round(pick(r, S.size)) };
      if (len != null) o.len = len;
      if (S.aspect) o.h = round(o.s * pick(r, S.aspect));
      if (!spriteClear(S, L, o)) continue;
      if (excl.some(([cx, cy, rr]) => Math.hypot(o.x - cx, o.y - cy) < rr + o.s / 2)) continue;
      if (S.place.minDist && inst.some(q => Math.hypot(q.x - o.x, q.y - o.y) < S.place.minDist)) continue;
      if (S.atlas.length > 1) o.t = Math.floor(r() * S.atlas.length);
      if (S.alpha) o.a = round(pick(r, S.alpha), 3);
      if (S.rotation) o.r = round(pick(r, S.rotation), 2);
      if (S.palette && S.palette.length > 1) o.c = Math.floor(r() * S.palette.length);
      o.m = S.motion.map(ch => {
        const m = { ch: ch.ch, type: ch.type };
        for (const [k, v] of Object.entries(ch)) {
          if (['ch', 'type', 'span', 'dirRandom', 'sync'].includes(k)) continue;
          m[k] = typeof v === 'string' ? v : round(pick(r, v), 4);
        }
        if (m.phase == null) m.phase = round(r(), 4);
        if (ch.type === 'drift') {
          const ext = ch.ch === 'x' ? o.s : (o.h || o.s);
          if (ch.span === 'layerX') { m.from = round(-ext - o.x); m.to = round(lw + ext - o.x); }
          else if (ch.span === 'layerY') { m.from = round(-ext - o.y); m.to = round(lh + ext - o.y); }
          else { m.from = round(-ch.span / 2); m.to = round(ch.span / 2); }
          if (ch.dirRandom && r() < 0.5) m.speed = -m.speed;
        }
        if (ch.type === 'flicker') m.seed = Math.floor(r() * 1e6);
        if (ch.sync) m.sync = ch.sync;
        return m;
      });
      // synced channels share period + phase; flicker channels share slot, dur and seed (one burst drives them all)
      const lead = o.m.find(m => m.sync);
      for (const m of o.m) if (m.sync && m !== lead) { m.period = lead.period; m.phase = lead.phase; }
      for (const m of o.m) delete m.sync;
      const fl = o.m.filter(m => m.type === 'flicker');
      for (const m of fl.slice(1)) { m.slot = fl[0].slot; m.dur = fl[0].dur; m.seed = fl[0].seed; }
      // an ember's alpha is locked to its rise: 0 exactly where the rise wraps
      if (S.lockAlphaToDrift) {
        const d = o.m.find(m => m.type === 'drift'), al = o.m.find(m => m.ch === 'alpha');
        const period = (d.to - d.from) / Math.abs(d.speed);
        Object.assign(al, { period: round(period, 4), phase: round(RC.mod((d.speed > 0 ? d.phase : -d.phase) - 0.25, 1), 6) });
      }
      inst.push(o);
    }
    S.instances = inst;
    if (inst.length < S.count.HIGH) console.warn(`sprite ${S.name}: ${inst.length}/${S.count.HIGH} instances (the rest did not fit)`);
  }

  // ---- particle fields
  const Vr = { w: 1920, h: 1080 };
  for (const F of R.fields) {
    const r = RC.rng(F.seed), parts = [];
    // cell: the largest local rect any domain viewport shows while the field's alpha >= cellCover, plus the largest
    // particle, rounded up to 10 px, so no particle is ever drawn twice on one screen (REALM.md 6.3)
    const zc = RC.fieldAlphaZoom(F, F.cellCover), ext = RC.visibleExtent(F.f, zc);
    const padMax = Math.max(...F.kinds.map(k => (Array.isArray(k.size) ? k.size[1] : k.size)));
    F.cell = [Math.ceil((ext.w + padMax) / 10) * 10, Math.ceil((ext.h + padMax) / 10) * 10];
    F.cellWorstCase = { fromZoom: round(zc, 4), extent: [round(ext.w), round(ext.h)], pad: padMax,
      x: `V=${round(ext.atW.V.w)}x${round(ext.atW.V.h)} z=${round(ext.atW.z, 3)}`, y: `V=${round(ext.atH.V.w)}x${round(ext.atH.V.h)} z=${round(ext.atH.z, 3)}` };
    const cellArea = F.cell[0] * F.cell[1];
    for (const kind of F.kinds) {
      const sFull = RC.layerZoom(F.f, F.zFull);
      const n = Math.max(1, Math.round(kind.target * cellArea * sFull * sFull / (Vr.w * Vr.h)));
      kind.perCell = n;
      // positions: one particle per stratum of a jittered gx x gy grid over the cell, strata taken in a shuffled order.
      // A plain uniform scatter over a cell bigger than the screen clumps (one screen empty, the next crowded); this
      // keeps every screen near its share, and the shuffle keeps the zoom-thinning order (tau) independent of position.
      const gx = Math.max(1, Math.round(Math.sqrt(n * F.cell[0] / F.cell[1]))), gy = Math.ceil(n / gx);
      const strata = Array.from({ length: gx * gy }, (_, q) => q);
      for (let q = strata.length - 1; q > 0; q--) { const j = Math.floor(r() * (q + 1)); [strata[q], strata[j]] = [strata[j], strata[q]]; }
      for (let i = 0; i < n; i++) {
        const u = (i + r()) / n; // stratified, so the visible count is smooth across zoom even with few particles
        const sx = strata[i] % gx, sy = Math.floor(strata[i] / gx);
        parts.push({ k: kind.name, x: round((sx + r()) * F.cell[0] / gx), y: round((sy + r()) * F.cell[1] / gy), size: round(pick(r, kind.size)),
          vx: round(pick(r, kind.vx), 2), vy: round(pick(r, kind.vy), 2), bx: round(pick(r, kind.bob), 1), by: round(pick(r, kind.bob), 1),
          bt: round(pick(r, kind.bobPeriod), 2), bp: round(r(), 3), a: round(pick(r, kind.alpha), 3), ta: round(pick(r, kind.twinkle), 3),
          tt: round(pick(r, kind.twinklePeriod), 2), tp: round(r(), 3), c: Math.floor(r() * kind.palette.length),
          tau: round(RC.layerZoomInverse(F.f, sFull * Math.sqrt(Math.max(u, 1e-6))), 4), t: Math.floor(r() * kind.atlas.length),
          cg: round(0.1 + 0.8 * r(), 3) }); // cg: the outcrop light at which this particle turns corrupt (REALM.md 5)
      }
    }
    parts.forEach((p, idx) => { p.low = lowKeep(F, p, idx) ? 1 : 0; });
    F.particles = parts;
    const spec = { f: F.f, cell: { w: F.cell[0], h: F.cell[1] }, zHide: F.zHide, zShow: F.zShow, particles: parts,
      maxSize: Math.max(...parts.map(p => p.size)), maxBob: Math.max(...parts.map(p => Math.max(p.bx, p.by))) };
    F.maxSize = spec.maxSize; F.maxBob = spec.maxBob;
    // pool size: the most sprites a screen can hold. Each particle drifts at its own velocity, so after a few minutes the
    // positions are an independent uniform scatter and the count in a view is a sum of independent copies: particle i
    // lands in the view (V/s grown by its size) with mean r_i = area ratio to the cell (r_i < 1 here, since the cell
    // covers the screen), variance frac(r_i)(1 - frac(r_i)). Pool = ceil(max over the domain and zoom of mean + 4 sigma),
    // and never below the most found by sampling (domain, zoom, pan, time).
    const pool = { HIGH: 0, LOW: 0 }, rr = RC.rng(4242);
    const bound = list => {
      let best = 0;
      const views = [];
      for (let w = RC.DOMAIN.minW; w <= RC.DOMAIN.maxW + 1e-9; w += (RC.DOMAIN.maxW - RC.DOMAIN.minW) / 24)
        for (let h = RC.DOMAIN.minH; h <= RC.DOMAIN.maxH + 1e-9; h += (RC.DOMAIN.maxH - RC.DOMAIN.minH) / 16) if (RC.inDomain({ w, h })) views.push({ w, h });
      for (const V of views) {
        const zr = RC.zoomRange(V, { slack: true }), lo = Math.max(zr.lo, F.zHide || 1e-3);
        for (let k = 0; k <= 40; k++) {
          const z = Math.exp(RC.lerp(Math.log(lo), Math.log(zr.hi), k / 40));
          if (RC.smoothstep(F.zHide, F.zShow, z) <= 0) continue;
          const s = RC.layerZoom(F.f, z);
          let mu = 0, v2 = 0;
          for (const p of list) {
            if (z < p.tau) continue;
            const ri = (V.w / s + p.size) * (V.h / s + p.size) / cellArea, fr = ri - Math.floor(ri);
            mu += ri; v2 += fr * (1 - fr);
          }
          best = Math.max(best, Math.ceil(mu + 4 * Math.sqrt(v2)));
        }
      }
      return best;
    };
    pool.HIGH = bound(parts); pool.LOW = bound(parts.filter(p => p.low));
    for (let i = 0; i < 6000; i++) {
      const Vw = RC.lerp(RC.DOMAIN.minW, RC.DOMAIN.maxW, rr()), a = RC.lerp(RC.DOMAIN.minAspect, RC.DOMAIN.maxAspect, rr());
      const V = RC.mapScale({ w: Vw, h: Vw / a }), zr = RC.zoomRange(V, { slack: true });
      const z = Math.exp(RC.lerp(Math.log(Math.max(zr.lo, F.zHide)), Math.log(zr.hi), rr()));
      const lim = RC.panLimits(z, V, { overscroll: RC.OVERSCROLL });
      const C = { x: RC.lerp(lim.x0, lim.x1, rr()), y: RC.lerp(lim.y0, lim.y1, rr()) };
      const n = RC.fieldPlace(spec, C, z, V, rr() * 600).length;
      pool.HIGH = Math.max(pool.HIGH, n);
      const low = RC.fieldPlace({ ...spec, particles: parts.filter(p => p.low) }, C, z, V, rr() * 600).length;
      pool.LOW = Math.max(pool.LOW, low);
    }
    F.poolMax = pool;
  }

  // ---- atlas + budget
  const atlasBytes = { HIGH: R.atlas.size[0] * R.atlas.size[1] * 4, LOW: (R.atlas.size[0] / 2) * (R.atlas.size[1] / 2) * 4 };
  const spriteObjects = tier => R.sprites.reduce((a, S) => a + Math.min(S.count[tier], S.instances.length), 0) +
    R.fields.reduce((a, F) => a + F.poolMax[tier], 0) + R.biomes.corrupt.bloom.layers.length;
  R.budget = {
    note: 'RGBA8 bytes of every uploaded image (tiles include their gutters). withMips = x4/3 in case the engine mips GUI textures. Tiles the tiler finds fully transparent are not uploaded, so these are upper bounds.',
    HIGH: { tiles: tilesHi, atlasImages: 1, textureMB: round((memHi + atlasBytes.HIGH) / 1048576, 1), withMipsMB: round((memHi + atlasBytes.HIGH) * 4 / 3 / 1048576, 1), budgetMB: R.tiers.HIGH.budgetMB, guiObjects: tilesHi + spriteObjects('HIGH') },
    LOW: { tiles: tilesLo, atlasImages: 1, textureMB: round((memLo + atlasBytes.LOW) / 1048576, 1), withMipsMB: round((memLo + atlasBytes.LOW) * 4 / 3 / 1048576, 1), budgetMB: R.tiers.LOW.budgetMB, guiObjects: tilesLo + spriteObjects('LOW') },
  };
  fs.writeFileSync(FILE, stringify(R) + '\n');
  report(RC, R);
  return R;
}
function lowKeep(F, p, idx) { // LOW keeps kinds with lowShare > 0, thinned deterministically
  const kind = F.kinds.find(k => k.name === p.k);
  return kind.lowShare > 0 && ((idx * 2654435761) >>> 0) / 4294967296 < kind.lowShare;
}

/** Does sprite instance o stay out of its layer's hard keep-clear zones? Hanging sprites (vines, light-falls) are
 *  checked along their whole length. S.clearScale shrinks the zones for thin sprites. */
function spriteClear(S, L, o) {
  if (S.keepClear === 'none') return true;
  const k = S.clearScale || 1, len = S.hangs ? (o.len || o.h || o.s) : 0, pad = S.hangs ? o.s / 2 : o.s / 2;
  const pts = S.hangs ? [0, 0.25, 0.5, 0.75, 1].map(t => [o.x, o.y + t * len]) : [[o.x, o.y]];
  return !L.keepClear.hard.some(e => pts.some(([x, y]) => ((x - e[1]) / (e[3] * k + pad)) ** 2 + ((y - e[2]) / (e[4] * k + pad)) ** 2 < 1));
}

// compact JSON: scalars, and arrays / objects whose members are scalars (or arrays of scalars), go on one line when
// they fit; everything else is indented. Strings are emitted by JSON.stringify only, never rewritten.
function stringify(v, ind = '') {
  const scalar = x => x === null || typeof x !== 'object';
  const inline = x => (scalar(x) ? JSON.stringify(x) : Array.isArray(x) ? '[' + x.map(inline).join(', ') + ']'
    : '{' + Object.entries(x).map(([k, y]) => JSON.stringify(k) + ': ' + inline(y)).join(', ') + '}');
  if (scalar(v)) return JSON.stringify(v);
  const small = y => scalar(y) || (Array.isArray(y) && y.every(scalar));
  const flat = Array.isArray(v) ? v.every(small) : Object.values(v).every(small);
  const one = inline(v);
  if (flat && one.length + ind.length <= 118) return one;
  const ni = ind + '  ';
  if (Array.isArray(v)) {
    if (v.every(scalar)) { // wrap long scalar arrays
      const lines = []; let cur = '';
      for (const p of v.map(y => JSON.stringify(y))) { if (cur && (cur + p).length + ni.length > 116) { lines.push(cur.trimEnd()); cur = ''; } cur += p + ', '; }
      lines.push(cur.replace(/, $/, ''));
      return '[\n' + lines.map(l => ni + l).join('\n') + '\n' + ind + ']';
    }
    return '[\n' + v.map(y => ni + stringify(y, ni)).join(',\n') + '\n' + ind + ']';
  }
  return '{\n' + Object.entries(v).map(([k, y]) => ni + JSON.stringify(k) + ': ' + stringify(y, ni)).join(',\n') + '\n' + ind + '}';
}

// ---------------------------------------------------------------------------------------------------- report
function report(RC, R) {
  const pad = (s, n) => String(s).padEnd(n), lp = (s, n) => String(s).padStart(n);
  console.log(pad('layer', 10) + lp('f', 6) + lp('required', 12) + lp('size', 12) + lp('res', 7) + lp('tile', 10) +
    lp('HIGH grid', 11) + lp('MB', 7) + lp('LOW grid', 10) + lp('MB', 7));
  for (const L of R.layers) {
    console.log(pad(L.id, 10) + lp(L.f, 6) + lp(L.required.w + 'x' + L.required.h, 12) + lp(L.size.join('x'), 12) +
      lp(L.res.HIGH, 7) + lp(L.tiles.w + 'x' + L.tiles.h, 10) + lp(L.grid.HIGH.nx + 'x' + L.grid.HIGH.ny, 11) +
      lp(L.memoryMB.HIGH, 7) + lp(L.grid.LOW.nx + 'x' + L.grid.LOW.ny, 10) + lp(L.memoryMB.LOW, 7));
  }
  for (const F of R.fields) console.log(`field ${F.id} f=${F.f} cell ${F.cell.join('x')} particles/cell ${F.particles.length} pool HIGH ${F.poolMax.HIGH} LOW ${F.poolMax.LOW}`);
  for (const S of R.sprites) console.log(`sprite ${pad(S.name, 18)} layer ${pad(S.layer, 7)} HIGH ${lp(Math.min(S.count.HIGH, S.instances.length), 3)} LOW ${lp(Math.min(S.count.LOW, S.instances.length), 3)}`);
  console.log('budget', JSON.stringify(R.budget.HIGH), '\n      ', JSON.stringify(R.budget.LOW));
}

// ---------------------------------------------------------------------------------------------------- test
function test(RC, fs, FILE) {
  let fails = 0, checks = 0;
  const ok = (cond, msg) => { checks++; if (!cond) { fails++; if (fails <= 40) console.log('FAIL', msg); } };
  const near = (a, b, e = 1e-6) => Math.abs(a - b) <= e * Math.max(1, Math.abs(a), Math.abs(b));
  const R = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  const W = RC.WORLD, r = RC.rng(1337);

  // -- 0. realm.json agrees with the constants here
  ok(R.world.w === W.w && R.world.h === W.h, 'world size');
  ok(R.camera.zMax === RC.Z_MAX && R.camera.zoomSlack === RC.ZOOM_SLACK && R.camera.overscroll === RC.OVERSCROLL, 'camera constants');
  for (const k of Object.keys(RC.DOMAIN)) ok(R.camera.viewportDomain[k] === RC.DOMAIN[k], 'domain ' + k);
  const world = R.layers.find(L => L.id === 'world');
  ok(world && world.f === 1 && world.size[0] === 3840 && world.size[1] === 2560, 'world layer is 3840x2560 at f=1');
  ok(R.layers.length === 7 && R.fields.some(F => F.f === 1.6), '7 baked layers + the f=1.6 particle field = 8 depths');
  const fsorted = R.layers.map(L => L.f); ok(fsorted.every((f, i) => !i || f > fsorted[i - 1]), 'layers ordered back to front');

  // -- 1. identities
  for (let i = 0; i < 3000; i++) {
    const V = RC.mapScale({ w: 300 + r() * 4000, h: 200 + r() * 2400 });
    ok(RC.inDomain(V), 'mapScale lands in the domain ' + JSON.stringify(V));
    const zr = RC.zoomRange(V), z = Math.exp(RC.lerp(Math.log(zr.lo), Math.log(zr.hi), r()));
    const lim = RC.panLimits(z, V), C = { x: RC.lerp(lim.x0, lim.x1, r()), y: RC.lerp(lim.y0, lim.y1, r()) };
    const p = { x: r() * W.w, y: r() * W.h }, q = RC.worldToScreen(C, z, V, p), p2 = RC.screenToWorld(C, z, V, q);
    ok(near(p.x, p2.x) && near(p.y, p2.y), 'world <-> screen round trip');
    const wl = { f: 1, w: W.w, h: W.h }, q2 = RC.localToScreen(wl, C, z, V, p);
    ok(near(q.x, q2.x) && near(q.y, q2.y), 'world layer == worldToScreen');
    const vr = RC.visibleRect(wl, C, z, V);
    ok(vr.x0 >= -1e-6 && vr.y0 >= -1e-6 && vr.x1 <= W.w + 1e-6 && vr.y1 <= W.h + 1e-6, 'hard clamp keeps the view inside the world');
    const L = R.layers[Math.floor(r() * R.layers.length)], Lg = { f: L.f, w: L.size[0], h: L.size[1] };
    const off = RC.layerOffset(Lg, C, z, V), v2 = RC.visibleRect(Lg, C, z, V);
    ok(near(off.x + off.scale * v2.x0, 0, 1e-6) && near(off.y + off.scale * v2.y1, V.h, 1e-6), 'offset and visibleRect agree');
    const S = { x: r() * V.w, y: r() * V.h }, z2 = z * (0.7 + r() * 0.6), C2 = RC.zoomAt(C, z, z2, S, V);
    const a = RC.screenToWorld(C, z, V, S), b = RC.screenToWorld(C2, z2, V, S);
    ok(near(a.x, b.x) && near(a.y, b.y), 'zoomAt keeps the world point under the cursor');
    const cc = RC.clampCamera({ x: C.x + (r() - 0.5) * 9000, y: C.y + (r() - 0.5) * 9000 }, z * (0.2 + r() * 3), V);
    const cc2 = RC.clampCamera(cc, cc.z, V); ok(near(cc.x, cc2.x) && near(cc.y, cc2.y) && near(cc.z, cc2.z), 'clamp is idempotent');
    // at zMin the binding axis spans the world exactly
    const zm = RC.zMin(V), vm = RC.visibleRect(wl, RC.clampCamera({ x: 0, y: 0 }, zm, V), zm, V);
    ok(near(vm.x1 - vm.x0, W.w, 1e-9) || near(vm.y1 - vm.y0, W.h, 1e-9), 'zMin fits the world width or height');
    // parallax ratio: a pan moves layer f by f * z^f / z of the world's screen motion (f at z = 1)
    const d = { x: C.x + 10, y: C.y }, sA = RC.localToScreen(Lg, C, z, V, { x: 100, y: 100 }), sB = RC.localToScreen(Lg, d, z, V, { x: 100, y: 100 });
    ok(near((sA.x - sB.x) / (10 * z), L.f * RC.layerZoom(L.f, z) / z, 1e-6), 'parallax ratio');
  }

  // -- 1b. depth order at every zoom: screen speed relative to the world rises with f, < 1 behind the world, > 1 in
  //        front; layer zoom agrees with the world at z = 1 (value 1, slope f); the inverse is exact
  const fs8 = [...R.layers.map(L => L.f), ...R.fields.map(F => F.f)].sort((a, b) => a - b);
  for (let i = 0; i <= 400; i++) {
    const z = Math.exp(RC.lerp(Math.log(0.1), Math.log(RC.Z_MAX * (1 + RC.ZOOM_SLACK)), i / 400));
    const sp = fs8.map(f => f * RC.layerZoom(f, z) / z);
    ok(sp.every((v, k) => !k || v >= sp[k - 1] - 1e-12), `depth order at z=${z}`);
    fs8.forEach((f, k) => ok(f < 1 ? sp[k] < 1 : f > 1 ? sp[k] > 1 : near(sp[k], 1), `f=${f} speed side at z=${z}`));
    for (const f of fs8) ok(near(RC.layerZoomInverse(f, RC.layerZoom(f, z)), z, 1e-9), 'layerZoomInverse');
  }
  for (const f of fs8) {
    const e = 1e-6, d = (RC.layerZoom(f, 1 + e) - RC.layerZoom(f, 1 - e)) / (2 * e);
    ok(near(RC.layerZoom(f, 1), 1) && Math.abs(d - f) < 1e-6, `layer zoom at z=1 for f=${f}`);
  }

  // -- 2. coverage: every visible layer covers the viewport for every allowed (C, z, V), rubber band included
  let samples = 0, worstMargin = Infinity, worstAt = '';
  const Vs = [];
  for (let w = RC.DOMAIN.minW; w <= RC.DOMAIN.maxW; w += 64) for (let h = RC.DOMAIN.minH; h <= RC.DOMAIN.maxH; h += 48) {
    const V = { w, h }; if (RC.inDomain(V)) Vs.push(V);
  }
  for (const [w, h] of [[2560, 1440], [2560, 711.1], [1920, 1080], [1366, 768], [1280, 720], [1024, 768], [844, 390], [932, 430],
    [667, 375], [568, 320], [568, 1262.2], [648, 1440], [1152, 320], [2560, 1066.7], [1600, 1000]]) Vs.push({ w, h });
  for (let i = 0; i < 400; i++) { const V = RC.mapScale({ w: 200 + r() * 5000, h: 150 + r() * 3000 }); Vs.push({ w: V.w, h: V.h }); }
  const checkCover = (L, C, z, V, tag) => {
    const Lg = { f: L.f, w: L.size[0], h: L.size[1] }, v = RC.visibleRect(Lg, C, z, V);
    const m = Math.min(v.x0, v.y0, Lg.w - v.x1, Lg.h - v.y1);
    samples++;
    if (m < worstMargin) { worstMargin = m; worstAt = `${L.id} V=${V.w.toFixed(0)}x${V.h.toFixed(0)} z=${z.toFixed(3)} C=${C.x.toFixed(0)},${C.y.toFixed(0)} ${tag}`; }
    ok(m >= -1e-6, `coverage ${L.id} ${tag} V=${JSON.stringify(V)} z=${z} C=${JSON.stringify(C)} margin=${m}`);
  };
  for (const L of R.layers) {
    if (L.id === 'world') continue; // the world is the content plane: it is transparent past its edges by design
    for (const V of Vs) {
      const zr = RC.zoomRange(V, { slack: true }), lo = Math.max(zr.lo, L.zHide || 0);
      if (lo > zr.hi) continue;
      for (let k = 0; k <= 24; k++) {
        const z = Math.exp(RC.lerp(Math.log(lo), Math.log(zr.hi), k / 24));
        const lim = RC.panLimits(z, V, { overscroll: RC.OVERSCROLL });
        for (const fx of [0, 0.5, 1]) for (const fy of [0, 0.5, 1]) checkCover(L, { x: RC.lerp(lim.x0, lim.x1, fx), y: RC.lerp(lim.y0, lim.y1, fy) }, z, V, 'grid');
      }
    }
    for (let i = 0; i < 60000; i++) {
      const V = RC.mapScale({ w: 200 + r() * 5000, h: 150 + r() * 3000 });
      const zr = RC.zoomRange(V, { slack: true }), lo = Math.max(zr.lo, L.zHide || 0);
      if (lo > zr.hi) continue;
      const z = Math.exp(RC.lerp(Math.log(lo), Math.log(zr.hi), r())), lim = RC.panLimits(z, V, { overscroll: RC.OVERSCROLL });
      checkCover(L, { x: RC.lerp(lim.x0, lim.x1, r()), y: RC.lerp(lim.y0, lim.y1, r()) }, z, V, 'random');
    }
    // and the clamp really is what bounds the camera: a far-out request lands inside the envelope we checked
    for (let i = 0; i < 2000; i++) {
      const V = RC.mapScale({ w: 200 + r() * 5000, h: 150 + r() * 3000 });
      const c = RC.clampCamera({ x: (r() - 0.5) * 20000, y: (r() - 0.5) * 20000 }, Math.exp((r() - 0.5) * 6), V, { rubber: true });
      if (c.z >= (L.zHide || 0)) checkCover(L, c, c.z, V, 'clamped');
    }
  }
  console.log(`coverage: ${samples} samples, tightest margin ${worstMargin.toFixed(2)} local px (${worstAt})`);

  // -- 3. required sizes are tight: the recorded worst case really reaches (almost) the required half extent
  for (const L of R.layers) {
    if (L.fixedSize) continue;
    const req = RC.requiredSize(L.f, { zHide: L.zHide || 0 }), D = RC.DOMAIN, k = 1 - RC.ZOOM_SLACK;
    ok(L.size[0] >= req.w && L.size[1] >= req.h, `${L.id} size >= required`);
    for (const ax of ['x', 'y']) {
      const w = req.worst[ax], z = w.z;
      // the smallest partner dimension keeps zMin lowest, so this viewport can reach zoom z
      const V = ax === 'x' ? { w: w.V, h: Math.max(D.minH, w.V / D.maxAspect) } : { w: Math.max(D.minW, w.V * D.minAspect), h: w.V };
      ok(RC.inDomain(V) && z >= RC.zoomRange(V, { slack: true }).lo - 1e-9, `${L.id} worst case ${ax} is reachable`);
      const lim = RC.panLimits(z, V, { overscroll: RC.OVERSCROLL });
      const v = RC.visibleRect({ f: L.f, w: L.size[0], h: L.size[1] }, { x: lim.x1, y: lim.y1 }, z, V);
      const half = ax === 'x' ? v.x1 - L.size[0] / 2 : v.y1 - L.size[1] / 2, need = (ax === 'x' ? req.w : req.h) / 2;
      ok(half >= need * 0.99 && half <= need + 1e-6, `${L.id} ${ax} tight: reaches ${half.toFixed(1)} of ${need}`);
    }
  }

  // -- 4. tiles: exact cover, image limit, LOW merge, memory budget
  for (const L of R.layers) {
    for (const tier of ['HIGH', 'LOW']) {
      const T = RC.tileRects(L, tier), s = L.grid[tier].scale;
      let area = 0;
      for (const t of T) {
        ok(t.image.w <= RC.TILE.maxImage && t.image.h <= RC.TILE.maxImage, `${L.id} ${tier} tile image <= 1024`);
        area += t.local.w * t.local.h;
        ok(Number.isInteger(t.tex.w) && Number.isInteger(t.tex.h), `${L.id} ${tier} integer tile`);
      }
      ok(Math.abs(area - L.size[0] * L.size[1]) < 1e-3, `${L.id} ${tier} tiles cover the layer exactly`);
      ok(Math.abs(L.grid[tier].texture[0] - L.size[0] * s) < 1e-6 && Math.abs(L.grid[tier].texture[1] - L.size[1] * s) < 1e-6, `${L.id} ${tier} texture size`);
      ok(T.length === L.grid[tier].tiles, `${L.id} ${tier} tile count`);
    }
    ok(L.size[0] % L.tileCell[0] === 0 && L.size[1] % L.tileCell[1] === 0, `${L.id} size is a multiple of the tile`);
  }
  // the budget holds even if the engine keeps mip chains for GUI textures (x4/3)
  for (const tier of ['HIGH', 'LOW']) ok(R.budget[tier].withMipsMB <= R.tiers[tier].budgetMB, `${tier} texture budget ${R.budget[tier].withMipsMB} <= ${R.tiers[tier].budgetMB}`);

  // -- 5. readability: sprites that must avoid nodes do (hanging ones along their length); drift spans are sane
  for (const S of R.sprites) {
    const L = R.layers.find(l => l.id === S.layer);
    ok(!!L, `sprite ${S.name} layer exists`);
    ok(S.instances.length >= S.count.LOW, `sprite ${S.name} has ${S.instances.length} >= LOW ${S.count.LOW} instances`);
    for (const a of S.atlas) ok(!!R.atlas.regions[a], `sprite ${S.name} atlas region ${a}`);
    for (const o of S.instances) {
      ok(spriteClear(S, L, o), `sprite ${S.name} at ${o.x},${o.y} inside a hard keep-clear zone`);
      for (const m of o.m) if (m.type === 'drift') ok(m.to > m.from && m.speed !== 0, `${S.name} drift span`);
    }
  }
  // atlas regions fit the sheet, do not overlap, and halve to whole pixels for the LOW sheet
  const regs = Object.entries(R.atlas.regions);
  for (const [n, [x, y, w, h]] of regs) {
    ok(x >= 0 && y >= 0 && x + w <= R.atlas.size[0] && y + h <= R.atlas.size[1], `atlas ${n} inside the sheet`);
    ok([x, y, w, h].every(v => v % 2 === 0), `atlas ${n} even`);
  }
  for (let i = 0; i < regs.length; i++) for (let j = i + 1; j < regs.length; j++) {
    const [a, A] = regs[i], [b, B] = regs[j];
    ok(A[0] + A[2] <= B[0] || B[0] + B[2] <= A[0] || A[1] + A[3] <= B[1] || B[1] + B[3] <= A[1], `atlas ${a} overlaps ${b}`);
  }

  // -- 6. motion: every parameter is a finite number or a known keyword; closed forms are periodic and bounded;
  //       ember alpha is ~0 where the rise wraps
  const KW = { ease: Object.keys(RC.EASE), out: ['jitter'] };
  for (const S of R.sprites) for (const o of S.instances) for (const m of o.m) for (const [k, v] of Object.entries(m)) {
    if (k === 'ch' || k === 'type') continue;
    ok(KW[k] ? KW[k].includes(v) : Number.isFinite(v), `${S.name} motion ${m.ch}.${k} = ${v}`);
  }
  for (const S of R.sprites) for (const o of S.instances.slice(0, 6)) {
    for (let k = 0; k < 40; k++) {
      const t = r() * 900, st = RC.spriteState(o, t);
      ok(Number.isFinite(st.dx + st.dy + st.rot + st.scale + st.alpha), `${S.name} finite state`);
      for (const m of o.m) if (m.type === 'sine') ok(near(RC.channel(m, t), RC.channel(m, t + m.period), 1e-6), `${S.name} sine periodic`);
    }
    if (S.lockAlphaToDrift) {
      const d = o.m.find(m => m.type === 'drift'), span = d.to - d.from, T = span / Math.abs(d.speed);
      const tw = RC.mod((d.speed > 0 ? 1 - d.phase : d.phase) * T, T); // time the drift wraps
      const al = RC.spriteState(o, tw);
      ok(al.alpha <= 0.02, `${S.name} alpha at wrap ${al.alpha.toFixed(3)}`);
    }
  }

  // -- 7. fields: seamless wrap, exact incremental flow, thinning keeps the count bounded
  for (const F of R.fields) {
    const spec = { f: F.f, cell: { w: F.cell[0], h: F.cell[1] }, zHide: F.zHide, zShow: F.zShow, particles: F.particles, maxSize: F.maxSize, maxBob: F.maxBob };
    for (const p of F.particles.slice(0, 20)) {
      // a particle's periodic copies form a continuous path: position(t+dt) - position(t) is small modulo the cell
      for (let k = 0; k < 20; k++) {
        const t = r() * 500, a = RC.fieldLocal(p, spec.cell, t), b = RC.fieldLocal(p, spec.cell, t + 1 / 60);
        const dx = RC.mod(b.x - a.x + spec.cell.w / 2, spec.cell.w) - spec.cell.w / 2, dy = RC.mod(b.y - a.y + spec.cell.h / 2, spec.cell.h) - spec.cell.h / 2;
        ok(Math.hypot(dx, dy) < 5, `field ${F.id} continuous (jump ${Math.hypot(dx, dy).toFixed(2)})`);
      }
    }
    // incremental flow == closed form along a random camera path
    let C = { x: 1500, y: 1100 }, z = 1, u = null;
    const V = { w: 1920, h: 1080 }, Lg = { f: F.f, w: 0, h: 0, ax: 0, ay: 0 }, p = { x: 437, y: -211 };
    u = (() => { const q = RC.localToScreen(Lg, C, z, V, p); return { x: q.x - 960, y: q.y - 540 }; })();
    for (let k = 0; k < 500; k++) {
      const C1 = { x: C.x + (r() - 0.5) * 40, y: C.y + (r() - 0.5) * 40 }, z1 = RC.clamp(z * Math.exp((r() - 0.5) * 0.05), 0.5, 1.3);
      u = RC.fieldStep(u, F.f, C, z, C1, z1); C = C1; z = z1;
    }
    const q = RC.localToScreen(Lg, C, z, V, p);
    ok(near(u.x, q.x - 960, 1e-6) && near(u.y, q.y - 540, 1e-6), `field ${F.id} incremental flow`);
    // count stays near the target across zoom (z <= zFull) at 1920x1080
    const counts = [];
    for (const zz of [Math.max(F.zShow, 0.6), 0.8, Math.min(1, F.zFull)]) {
      let n = 0; for (let k = 0; k < 40; k++) n += RC.fieldPlace(spec, { x: 800 + k * 57, y: 900 + k * 23 }, zz, V, k * 3.7).length; counts.push(n / 40);
    }
    const tgt = F.kinds.reduce((a, k) => a + k.target, 0);
    ok(counts.every(c => c > tgt * 0.4 && c < tgt * 2.2), `field ${F.id} count ~ target ${tgt}: ${counts.map(c => c.toFixed(1)).join(', ')}`);
    ok(F.poolMax.HIGH >= F.poolMax.LOW && F.poolMax.HIGH <= 3 * tgt + 12, `field ${F.id} pool ${F.poolMax.HIGH}`);
    // single screens: at z = min(1, zFull) on 1920x1080 over random pans and times the mean holds the target, and no
    // screen ever needs more sprites than the pool (checked again over the whole domain below)
    let cSum = 0, cMax = 0;
    for (let k = 0; k < 400; k++) {
      const zz = Math.min(1, F.zFull), lim = RC.panLimits(zz, V), Cq = { x: RC.lerp(lim.x0, lim.x1, r()), y: RC.lerp(lim.y0, lim.y1, r()) };
      const n = RC.fieldPlace(spec, Cq, zz, V, r() * 3600).length; cSum += n; cMax = Math.max(cMax, n);
    }
    ok(cSum / 400 > tgt * 0.8 && cSum / 400 < tgt * 1.25 && cMax <= F.poolMax.HIGH, `field ${F.id} per-screen mean ${(cSum / 400).toFixed(1)} (target ${tgt}), max ${cMax} (pool ${F.poolMax.HIGH})`);
    const lowSpec = { ...spec, particles: F.particles.filter(p => p.low) };
    let poolWorst = 0;
    for (let k = 0; k < 3000; k++) {
      const Vq = k % 3 ? Vs[Math.floor(r() * Vs.length)] : { w: 2560, h: 1440 }, zr = RC.zoomRange(Vq, { slack: true }), lo = Math.max(zr.lo, F.zHide || 0);
      if (lo > zr.hi) continue;
      const z = Math.exp(RC.lerp(Math.log(lo), Math.log(zr.hi), r())), lim = RC.panLimits(z, Vq, { overscroll: RC.OVERSCROLL });
      const Cq = { x: RC.lerp(lim.x0, lim.x1, r()), y: RC.lerp(lim.y0, lim.y1, r()) }, t = r() * 3600;
      const nh = RC.fieldPlace(spec, Cq, z, Vq, t).length, nl = RC.fieldPlace(lowSpec, Cq, z, Vq, t).length;
      poolWorst = Math.max(poolWorst, nh / F.poolMax.HIGH);
      ok(nh <= F.poolMax.HIGH && nl <= F.poolMax.LOW, `field ${F.id} needs ${nh}/${nl} sprites > pool ${F.poolMax.HIGH}/${F.poolMax.LOW}`);
    }
    console.log(`field ${F.id}: cell ${F.cell.join('x')}, 1920x1080 mean ${(cSum / 400).toFixed(1)} (target ${tgt}), sampled peak ${Math.round(poolWorst * 100)}% of pool ${F.poolMax.HIGH}`);
    // no repeats: wherever the field's alpha is >= cellCover, no domain viewport shows one cell plus the largest
    // particle, so no particle is ever drawn twice on one screen
    const zc = RC.fieldAlphaZoom(F, F.cellCover);
    ok(F.cellCover > 0 && F.cellCover <= 0.5 && near(F.zHide > 0 ? RC.smoothstep(F.zHide, F.zShow, zc) : F.cellCover, F.cellCover, 1e-6), `field ${F.id} cellCover zoom`);
    for (const Vq of Vs) {
      const zr = RC.zoomRange(Vq, { slack: true }), z = Math.max(zr.lo, zc);
      if (z > zr.hi) continue;
      const s = RC.layerZoom(F.f, z);
      ok(Vq.w / s + F.maxSize <= F.cell[0] + 1e-6 && Vq.h / s + F.maxSize <= F.cell[1] + 1e-6,
        `field ${F.id} cell ${F.cell} smaller than the view ${(Vq.w / s).toFixed(0)}x${(Vq.h / s).toFixed(0)} (V=${Vq.w.toFixed(0)}x${Vq.h.toFixed(0)} z=${z.toFixed(3)})`);
    }
    let placed = 0;
    for (let k = 0; k < 2500; k++) {
      const Vq = Vs[Math.floor(r() * Vs.length)], zr = RC.zoomRange(Vq, { slack: true }), lo = Math.max(zr.lo, zc);
      if (lo > zr.hi) continue;
      const z = Math.exp(RC.lerp(Math.log(lo), Math.log(zr.hi), r())), lim = RC.panLimits(z, Vq, { overscroll: RC.OVERSCROLL });
      const Cq = { x: RC.lerp(lim.x0, lim.x1, r()), y: RC.lerp(lim.y0, lim.y1, r()) }, seen = new Set();
      let dup = -1;
      for (const q of RC.fieldPlace(spec, Cq, z, Vq, r() * 900)) { if (seen.has(q.i)) dup = q.i; seen.add(q.i); placed++; }
      ok(dup < 0, `field ${F.id} particle ${dup} drawn twice at V=${Vq.w.toFixed(0)}x${Vq.h.toFixed(0)} z=${z.toFixed(3)} C=${Cq.x.toFixed(0)},${Cq.y.toFixed(0)}`);
    }
    ok(placed > 0, `field ${F.id} repeat test placed particles`);
  }

  // -- 8. biome: weights over reachable (hard-clamped) cameras, for every domain viewport
  const B = R.biomes, Vref = { w: 1920, h: 1080 };
  ok(RC.biome({ x: 1500, y: 1200 }, B, 1, Vref).rift === 0 && RC.biome({ x: 2700, y: 1200 }, B, 1, Vref).rift === 1, 'biome endpoints');
  const oc = B.corrupt.rect;
  ok(oc[0] >= 0 && oc[1] >= 0 && oc[2] <= W.w && oc[3] <= W.h && oc[0] < oc[2] && oc[1] < oc[3] && B.corrupt.cover[0] < B.corrupt.cover[1], 'corrupt rect / cover');
  const zSteps = V => { const zr = RC.zoomRange(V), out = []; for (let k = 0; k <= 32; k++) out.push(zr.lo * Math.pow(zr.hi / zr.lo, k / 32)); return out; };
  let eastWorst = { v: Infinity, at: '' };
  for (const V of Vs) {
    let best = 0;
    for (const z of zSteps(V)) {
      // the east limit near the outcrop's height: the accent must be reachable on every screen
      const Ce = RC.clampCamera({ x: W.w, y: 1250 }, z, V), we = RC.biome(Ce, B, z, V);
      ok(we.corrupt >= 0 && we.corrupt <= 1 && we.corrupt <= we.rift + 1e-12, 'corrupt in [0, rift]');
      best = Math.max(best, we.corrupt);
      // the tree (the camera asked to centre on the trunk, hard-clamped): never corrupt, at any zoom
      const Ct = RC.clampCamera({ x: 1500, y: 1150 }, z, V);
      ok(RC.biome(Ct, B, z, V).corrupt === 0, `corrupt at the tree V=${V.w.toFixed(0)}x${V.h.toFixed(0)} z=${z.toFixed(3)}`);
    }
    if (best < eastWorst.v) eastWorst = { v: best, at: `${V.w.toFixed(0)}x${V.h.toFixed(0)}` };
    ok(best >= 0.9, `corrupt reaches only ${best.toFixed(3)} at the east limit for V=${V.w.toFixed(0)}x${V.h.toFixed(0)}`);
    // the start camera (REALM.md 2.8): pure realm
    const zs = RC.clamp(Math.min(V.w / 1500, V.h / 1750), RC.zMin(V), 1), Cs = RC.clampCamera({ x: 1500, y: 1150 }, zs, V), ws = RC.biome(Cs, B, zs, V);
    ok(ws.rift === 0 && ws.corrupt === 0, `start camera biome ${JSON.stringify(ws)} at V=${V.w.toFixed(0)}x${V.h.toFixed(0)}`);
  }
  // the main desktop screens: at the east limit (y 1250) the accent holds >= 0.6 over the whole zoom band 1 .. zMax
  for (const V of [{ w: 1920, h: 1080 }, { w: 2560, h: 1440 }]) for (let k = 0; k <= 20; k++) {
    const z = 1 + (RC.Z_MAX - 1) * k / 20, C = RC.clampCamera({ x: W.w, y: 1250 }, z, V), w = RC.biome(C, B, z, V);
    ok(w.corrupt >= 0.6, `corrupt ${w.corrupt.toFixed(3)} at the east limit, V=${V.w}x${V.h} z=${z.toFixed(3)}`);
  }
  // the outcrop light: full on the outcrop and its nodes, off at the rift centre and everywhere west of it
  const light = (x, y) => RC.corruptLight(B, { x, y });
  ok(light(3510, 1200) >= 0.95 && light(3690, 930) >= 0.95 && light(3600, 1320) >= 0.95, 'corrupt light on CR, CM, the outcrop');
  ok(light(3150, 1480) <= 0.05 && light(3150, 1560) <= 0.05 && light(1500, 1150) === 0 && light(3089, 1180) === 0, 'corrupt light off at the rift and the tree');
  for (let k = 0; k < 2000; k++) { const v = light(r() * W.w, r() * W.h); ok(v >= 0 && v <= 1, 'corrupt light in [0, 1]'); }
  // blooms sit exactly behind the focus at their reference camera, and are drawn before their layer's tiles
  for (const bl of B.corrupt.bloom.layers) {
    const L = R.layers.find(l => l.id === bl.layer), Lg = { f: L.f, w: L.size[0], h: L.size[1] }, [cx, cy, cz] = B.corrupt.bloom.camera;
    const a = RC.localToScreen(Lg, { x: cx, y: cy }, cz, Vref, { x: bl.local[0], y: bl.local[1] }), b = RC.worldToScreen({ x: cx, y: cy }, cz, Vref, { x: B.corrupt.focus[0], y: B.corrupt.focus[1] });
    ok(Math.hypot(a.x - b.x, a.y - b.y) < 0.2, `bloom ${bl.layer} behind the focus (${(a.x - b.x).toFixed(2)}, ${(a.y - b.y).toFixed(2)})`);
    ok(R.zOrder.indexOf('corrupt bloom ' + bl.layer) >= 0 && R.zOrder.indexOf('corrupt bloom ' + bl.layer) < R.zOrder.indexOf(bl.layer + ' tiles'), `bloom ${bl.layer} z-order`);
    ok(bl.alpha > 0 && bl.alpha <= 0.5 && !!R.atlas.regions[B.corrupt.bloom.atlas], `bloom ${bl.layer} alpha / atlas`);
  }
  // tiles and the wash take no corrupt colour (the retired keys equal the rift ones, so old consumers match the rule)
  for (const L of R.layers) ok(!L.tint || L.tint.corrupt == null || L.tint.corrupt.every((v, i) => v === L.tint.rift[i]), `${L.id}: tiles take no corrupt tint`);
  ok(!B.wash.corrupt || B.wash.corrupt.color.every((v, i) => v === B.wash.rift.color[i]), 'the wash takes no corrupt colour');
  for (const F of R.fields) for (const p of F.particles) ok(p.cg >= 0.1 && p.cg <= 0.9, `field ${F.id} cg`);
  for (const F of R.fields) for (const kd of F.kinds) ok(Array.isArray(kd.corrupt) && kd.corrupt.length === 3, `field ${F.id} ${kd.name} corrupt colour`);
  // the colour helpers the client and the preview share: corrupt is local light, never a screen-wide blend
  {
    const full = { rift: 1, corrupt: 1 }, eq = (a, b) => a.every((v, i) => Math.abs(v - b[i]) < 1e-9);
    const riftP = { x: 3150, y: 1480 }, outP = { x: 3600, y: 1320 }, treeP = { x: 1500, y: 1150 };
    for (const S of R.sprites) if (S.color) {
      ok(eq(RC.biomeSpriteColor(S.color, full, B, treeP), S.color.rift), `${S.name}: no corrupt colour away from the outcrop`);
      ok(eq(RC.biomeSpriteColor(S.color, full, B, outP), S.color.corrupt), `${S.name}: corrupt colour over the outcrop`);
      const c = RC.biomeSpriteColor(S.color, full, B, riftP), d = Math.hypot(c[0] - S.color.rift[0], c[1] - S.color.rift[1], c[2] - S.color.rift[2]);
      ok(d < 6, `${S.name}: stays rift-coloured at the rift centre (${d.toFixed(1)} off)`);
      ok(eq(RC.biomeSpriteColor(S.color, { rift: 0, corrupt: 0 }, B, outP), S.color.realm), `${S.name}: realm colour at w = 0`);
    }
    for (const F of R.fields) for (const kd of F.kinds) for (const cg of [0.1, 0.5, 0.9]) {
      ok(eq(RC.biomeFieldColor(kd, 0, cg, full, B, riftP), RC.mixRGB(kd.palette[0], kd.rift, 1)), `${F.id} ${kd.name}: ember at the rift`);
      ok(eq(RC.biomeFieldColor(kd, 0, cg, full, B, outP), kd.corrupt), `${F.id} ${kd.name}: green over the outcrop`);
    }
    for (const L of R.layers) ok(eq(RC.biomeTint(L.tint, full), L.tint ? L.tint.rift : [255, 255, 255]), `${L.id}: tint takes only w.rift`);
    const wa = RC.biomeWash(B.wash, full);
    ok(eq(wa.color, B.wash.rift.color) && near(wa.alpha, B.wash.rift.alpha, 1e-12), 'wash takes only w.rift');
    for (const bl of B.corrupt.bloom.layers) {
      ok(RC.bloomState(bl, { rift: 1, corrupt: 0 }) === null, `bloom ${bl.layer} hidden at corrupt 0`);
      ok(near(RC.bloomState(bl, full).alpha, bl.alpha, 1e-12), `bloom ${bl.layer} alpha at corrupt 1`);
    }
  }
  // the old two-argument form still works (preview fallback: z = C.z or 1, V = 1920x1080)
  ok(near(RC.biome({ x: 2880, y: 1250 }, B).corrupt, RC.biome({ x: 2880, y: 1250 }, B, 1, Vref).corrupt, 1e-12), 'biome fallback');
  console.log(`biome: corrupt at the east limit reaches >= ${eastWorst.v.toFixed(3)} on every viewport (lowest at ${eastWorst.at})`);

  console.log(`${checks} checks, ${fails} failed`);
  return fails === 0;
}
})();
