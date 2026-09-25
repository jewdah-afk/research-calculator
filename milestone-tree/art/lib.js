// Shared procedural-art helpers for the Milestone Tree map layers (canvas 2D).
let W = 3840, H = 2160;
const LAYERS = {};

function rng(seed) {
  return function () {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function makeNoise(seed) {
  const r = rng(seed), p = new Uint8Array(512), perm = [];
  for (let i = 0; i < 256; i++) perm[i] = i;
  for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); const t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
  for (let i = 0; i < 512; i++) p[i] = perm[i & 255];
  const gx = [1, -1, 1, -1, 1.41, -1.41, 0, 0], gy = [1, 1, -1, -1, 0, 0, 1.41, -1.41];
  return function (x, y) {
    const X = Math.floor(x), Y = Math.floor(y), xf = x - X, yf = y - Y, xi = X & 255, yi = Y & 255;
    const u = xf * xf * xf * (xf * (xf * 6 - 15) + 10), v = yf * yf * yf * (yf * (yf * 6 - 15) + 10);
    const aa = p[p[xi] + yi] & 7, ab = p[p[xi] + yi + 1] & 7, ba = p[p[xi + 1] + yi] & 7, bb = p[p[xi + 1] + yi + 1] & 7;
    const n00 = gx[aa] * xf + gy[aa] * yf, n10 = gx[ba] * (xf - 1) + gy[ba] * yf;
    const n01 = gx[ab] * xf + gy[ab] * (yf - 1), n11 = gx[bb] * (xf - 1) + gy[bb] * (yf - 1);
    const a = n00 + (n10 - n00) * u, b = n01 + (n11 - n01) * u;
    return (a + (b - a) * v) * 0.7071; // ~[-1,1]
  };
}
function fbm(n, x, y, oct = 5, lac = 2.03, gain = 0.5) {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { s += a * n(x * f, y * f); f *= lac; a *= gain; }
  return s;
}
function ridged(n, x, y, oct = 5) {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { const v = 1 - Math.abs(n(x * f, y * f)); s += a * v * v; f *= 2.1; a *= 0.5; }
  return s;
}
const clamp = (x, a = 0, b = 1) => x < a ? a : x > b ? b : x;
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
function hex(h) { h = h.replace('#', ''); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; }
function rgba(c, a = 1) { return `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`; }
function mix(c1, c2, t) { return [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)]; }

function canvas(w = W, h = H) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function ctx(c) { return c.getContext('2d'); }

// draw something on a scratch canvas, then composite it (optionally blurred / additive)
function layer(target, draw, { blur = 0, op = 'source-over', alpha = 1, w = W, h = H } = {}) {
  const c = canvas(w, h), x = ctx(c); draw(x, c);
  const t = ctx(target); t.save(); t.globalCompositeOperation = op; t.globalAlpha = alpha;
  if (blur) t.filter = `blur(${blur}px)`;
  t.drawImage(c, 0, 0, target.width, target.height); t.restore();
  return c;
}
// bloom: blurred copies of a canvas added on top of target
function bloom(target, src, radii = [6, 24, 70], strength = [0.9, 0.6, 0.45]) {
  const t = ctx(target); t.save(); t.globalCompositeOperation = 'lighter';
  radii.forEach((r, i) => { t.globalAlpha = strength[i]; t.filter = `blur(${r}px)`; t.drawImage(src, 0, 0); });
  t.restore();
}

// Catmull-Rom through points [[x,y,w],...] -> dense samples with x,y,w,nx,ny
function spline(pts, per = 24) {
  const out = [];
  const P = [pts[0], ...pts, pts[pts.length - 1]];
  for (let i = 1; i < P.length - 2; i++) {
    const p0 = P[i - 1], p1 = P[i], p2 = P[i + 1], p3 = P[i + 2];
    for (let k = 0; k < per; k++) {
      const t = k / per, t2 = t * t, t3 = t2 * t;
      const f = j => 0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3);
      out.push({ x: f(0), y: f(1), w: lerp(p1[2], p2[2], t) });
    }
  }
  const l = pts[pts.length - 1]; out.push({ x: l[0], y: l[1], w: l[2] });
  for (let i = 0; i < out.length; i++) {
    const a = out[Math.max(0, i - 1)], b = out[Math.min(out.length - 1, i + 1)];
    let dx = b.x - a.x, dy = b.y - a.y; const d = Math.hypot(dx, dy) || 1; dx /= d; dy /= d;
    out[i].tx = dx; out[i].ty = dy; out[i].nx = -dy; out[i].ny = dx;
  }
  let acc = 0; out[0].s = 0;
  for (let i = 1; i < out.length; i++) { acc += Math.hypot(out[i].x - out[i - 1].x, out[i].y - out[i - 1].y); out[i].s = acc; }
  out.len = acc;
  return out;
}
function outline(S, wob = null) {
  const L = [], R = [];
  for (const p of S) {
    const w = p.w * 0.5 * (wob ? 1 + wob(p) : 1);
    L.push([p.x + p.nx * w, p.y + p.ny * w]); R.push([p.x - p.nx * w, p.y - p.ny * w]);
  }
  return [...L, ...R.reverse()];
}
function poly(x, pts) { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) x.lineTo(pts[i][0], pts[i][1]); x.closePath(); }
function pathAlong(x, S, off = 0, from = 0, to = 1) {
  x.beginPath(); const a = Math.floor(from * (S.length - 1)), b = Math.ceil(to * (S.length - 1));
  for (let i = a; i <= b; i++) { const p = S[i]; const px = p.x + p.nx * p.w * 0.5 * off, py = p.y + p.ny * p.w * 0.5 * off; i === a ? x.moveTo(px, py) : x.lineTo(px, py); }
}
// point on sampled spline at fraction t
function at(S, t) { return S[Math.round(clamp(t) * (S.length - 1))]; }

// soft radial blob
function blob(x, cx, cy, r, c, a = 1, inner = 0) {
  const g = x.createRadialGradient(cx, cy, r * inner, cx, cy, r);
  g.addColorStop(0, rgba(c, a)); g.addColorStop(1, rgba(c, 0));
  x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, Math.PI * 2); x.fill();
}
// 4-point sparkle with long thin rays
function sparkle(x, cx, cy, r, c, a = 1, rot = 0) {
  x.save(); x.translate(cx, cy); x.rotate(rot);
  for (const [len, th] of [[r, r * 0.06], [r * 0.55, r * 0.04]]) {
    for (let k = 0; k < 2; k++) {
      x.rotate(k ? Math.PI / 2 : 0);
      const g = x.createLinearGradient(-len, 0, len, 0);
      g.addColorStop(0, rgba(c, 0)); g.addColorStop(0.5, rgba(c, a)); g.addColorStop(1, rgba(c, 0));
      x.fillStyle = g; x.beginPath(); x.ellipse(0, 0, len, Math.max(0.6, th), 0, 0, Math.PI * 2); x.fill();
    }
    x.rotate(Math.PI / 4 - Math.PI / 2);
  }
  x.restore();
  blob(x, cx, cy, r * 0.18, [255, 255, 255], a);
}
function leaf(x, cx, cy, len, wid, ang) {
  x.save(); x.translate(cx, cy); x.rotate(ang); x.beginPath();
  x.moveTo(0, 0); x.quadraticCurveTo(len * 0.45, -wid, len, 0); x.quadraticCurveTo(len * 0.45, wid, 0, 0); x.fill(); x.restore();
}
function gauss(r) { let u = 0, v = 0; while (u === 0) u = r(); v = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
