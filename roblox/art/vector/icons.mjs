// Icon set, drawn as flat vector art and exported as PNG (see build.mjs).
// Style: thick black outline with a hard drop, a flat base tone, a darker rim
// on the lower edge, a lighter band on the top edge, hand-placed facets where a
// shape has planes, and one white highlight. Canvas is 128x128; geometry stays
// inside 10..118 so the outline and drop never touch the edge.

const INK = '#0b0c10';
const OUT = 12;  // silhouette stroke (6 units outside the shape)
const SEP = 7;   // outline each part draws over the parts behind it
const DROP = 6;  // hard drop under the silhouette

// ---------- colour ----------
const hex = c => c.match(/\w\w/g).map(h => parseInt(h, 16));
const mix = (a, b, t) => '#' + hex(a).map((v, i) => Math.round(v + (hex(b)[i] - v) * t).toString(16).padStart(2, '0')).join('');
export const dark = (c, t = .3) => mix(c, '#241338', t);
export const light = (c, t = .35) => mix(c, '#ffffff', t);
const tones = (c, d = .32, l = .38) => ({ base: c, dark: dark(c, d), light: light(c, l) });

// ---------- geometry ----------
const f1 = n => +n.toFixed(2);
const rot = ([x, y], a, cx, cy) => { const r = a * Math.PI / 180, dx = x - cx, dy = y - cy; return [cx + dx * Math.cos(r) - dy * Math.sin(r), cy + dx * Math.sin(r) + dy * Math.cos(r)]; };
// rounded polygon as a path of absolute M/L/Q commands
export function roundPoly(pts, rad) {
  const n = pts.length; let d = '';
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n];
    const v = (a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy); return [dx / L, dy / L, L]; };
    const [ax, ay, la] = v(p1, p0), [bx, by, lb] = v(p1, p2);
    const r = Math.min(Array.isArray(rad) ? rad[i] : rad, la / 2, lb / 2);
    d += `${i ? 'L' : 'M'}${f1(p1[0] + ax * r)} ${f1(p1[1] + ay * r)}Q${f1(p1[0])} ${f1(p1[1])} ${f1(p1[0] + bx * r)} ${f1(p1[1] + by * r)}`;
  }
  return d + 'Z';
}
// rotate every coordinate pair of a path made of absolute M/L/C/Q/Z commands
export function rotPath(d, a, cx, cy) {
  return d.replace(/(-?[\d.]+)[ ,](-?[\d.]+)/g, (_, x, y) => rot([+x, +y], a, cx, cy).map(f1).join(' '));
}
const rrect = (cx, cy, w, h, r, a = 0) => {
  const p = [[cx - w / 2, cy - h / 2], [cx + w / 2, cy - h / 2], [cx + w / 2, cy + h / 2], [cx - w / 2, cy + h / 2]];
  return roundPoly(a ? p.map(q => rot(q, a, cx, cy)) : p, r);
};
const circleD = (cx, cy, r) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`;
const arcPts = (cx, cy, r, a0, a1) => { const p = a => [f1(cx + r * Math.cos(a * Math.PI / 180)), f1(cy + r * Math.sin(a * Math.PI / 180))]; return [p(a0), p(a1)]; };
const arc = (cx, cy, r, a0, a1) => { const [s, e] = arcPts(cx, cy, r, a0, a1); return `M${s[0]} ${s[1]}A${r} ${r} 0 ${Math.abs(a1 - a0) > 180 ? 1 : 0} 1 ${e[0]} ${e[1]}`; };
function starPts(cx, cy, R, r, n = 5, rot0 = -90) {
  const p = [];
  for (let i = 0; i < n * 2; i++) { const a = (rot0 + i * 180 / n) * Math.PI / 180, rr = i % 2 ? r : R; p.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); }
  return p;
}

// ---------- parts ----------
// fill part: a closed path with tones. Options:
//   rim [dx,dy]  offset of the lit copy; what it leaves uncovered is the dark rim (default [0,-7])
//   band          height of the light band along the top edge (0 = none)
//   facets        markup drawn over the base, clipped to the part
//   recess        true = sunk into the surface: dark band on top instead of bottom
//   sep           false = no separating outline of its own
//   sil           false = not part of the silhouette (sits fully inside other parts)
export const fill = (d, t, o = {}) => ({ kind: 'fill', d, t: typeof t === 'string' ? tones(t) : t, ...o });
// stroke part: a thick line (shackle, stem, handle) with its own outline
export const stroke = (d, color, w, o = {}) => ({ kind: 'stroke', d, color, w, ...o });

let uid = 0, iconN = 0;
function renderFill(p) {
  const id = 'i' + iconN + 'k' + (uid++);
  const { base, dark: dk, light: lt } = p.t;
  const [rx, ry] = p.recess ? [0, 6] : (p.rim ?? [0, -7]);
  const band = p.recess ? 0 : (p.band ?? 5);
  const R = c => `<rect width="128" height="128" fill="${c}"/>`;
  let s = `<clipPath id="${id}"><path d="${p.d}"/></clipPath>`;
  s += `<clipPath id="${id}r"><path d="${p.d}" transform="translate(${rx} ${ry})"/></clipPath>`;
  if (band) s += `<clipPath id="${id}b"><path d="${p.d}" transform="translate(${rx} ${ry + band})"/></clipPath>`;
  s += `<g clip-path="url(#${id})">${R(dk)}<g clip-path="url(#${id}r)">`;
  s += band ? `${R(lt)}<g clip-path="url(#${id}b)">${R(base)}</g>` : R(base);
  s += `</g>${p.facets ?? ''}</g>`;
  return s;
}

export function icon(parts, { top = '' } = {}) {
  uid = 0; iconN++;
  const silOf = p => p.sil === false ? '' : p.kind === 'fill'
    ? `<path d="${p.d}" fill="${INK}" stroke="${INK}" stroke-width="${OUT}" stroke-linejoin="round"/>`
    : `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${p.w + OUT}" stroke-linecap="round" stroke-linejoin="round"/>`;
  const sil = parts.map(silOf).join('');
  let s = `<g transform="translate(0 ${DROP})">${sil}</g>${sil}`;
  for (const p of parts) {
    if (p.kind === 'fill') {
      if (p.sep !== false) s += `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${SEP}" stroke-linejoin="round"/>`;
      s += renderFill(p);
    } else {
      if (p.sep !== false) s += `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${p.w + SEP}" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${p.d}" fill="none" stroke="${p.color}" stroke-width="${p.w}" stroke-linecap="round" stroke-linejoin="round"/>`;
      if (p.shine) s += `<path d="${p.shine}" fill="none" stroke="#fff" stroke-width="${p.shineW ?? 3}" stroke-linecap="round" opacity=".85"/>`;
    }
    s += p.over ?? '';
  }
  s += top;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">${s}</svg>`;
}

// ---------- shared details ----------
const glint = (cx, cy, rx, ry, a = -35, o = .95) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" transform="rotate(${a} ${cx} ${cy})" fill="#fff" opacity="${o}"/>`;
const dot = (cx, cy, r, o = .95) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#fff" opacity="${o}"/>`;
const shineArc = (cx, cy, r, a0, a1, w = 5, o = .9) => `<path d="${arc(cx, cy, r, a0, a1)}" fill="none" stroke="#fff" stroke-width="${w}" stroke-linecap="round" opacity="${o}"/>`;
const sparkle = (x, y, r = 7) => `<path d="M${x} ${y - r}Q${x + r * .16} ${y - r * .16} ${x + r} ${y}Q${x + r * .16} ${y + r * .16} ${x} ${y + r}Q${x - r * .16} ${y + r * .16} ${x - r} ${y}Q${x - r * .16} ${y - r * .16} ${x} ${y - r}Z" fill="#fff" stroke="${INK}" stroke-width="3" stroke-linejoin="round"/>`;
const spark = (x, y, r) => sparkle(x, y, r).replace('fill="#fff"', 'fill="#ffd84a"');
// carved line: dark groove with a lit lower lip
const carve = (d, c, w = 10, k = 1) => `<g fill="none" stroke-linecap="round" stroke-linejoin="round">` +
  `<path d="${d}" stroke="${light(c, .55)}" stroke-width="${w}" transform="translate(0 ${2.5 * k})"/>` +
  `<path d="${d}" stroke="${dark(c, .55)}" stroke-width="${w}"/>` +
  `<path d="${d}" stroke="${dark(c, .75)}" stroke-width="${w * .4}" transform="translate(0 ${-1.5 * k})" opacity=".55"/></g>`;
// light the faces of a faceted shape from the top-left
const LIGHT = [-0.55, -0.83];
function facetColor(t, nx, ny) {
  const L = Math.hypot(nx, ny) || 1, k = (nx * LIGHT[0] + ny * LIGHT[1]) / L; // -1..1
  return k >= 0 ? mix(t.base, t.light, k) : mix(t.base, t.dark, -k);
}
const tri = (a, b, c, col) => `<polygon points="${[a, b, c].map(p => p.map(f1).join(',')).join(' ')}" fill="${col}"/>`;

export const ICONS = {};

// ---------- currency ----------
{ // coin: gold with a recessed face and an engraved $
  const t = tones('#ffc83d', .3, .45);
  const dollar = 'M75 47C72 42 66 40 62 40C55 40 51 44 51 49C51 55 57 57 64 59C71 61 77 63 77 70C77 76 71 79 64 79C58 79 53 76 51 72M64 34V85';
  ICONS.coin = icon([
    fill(circleD(64, 58, 47), t),
    fill(circleD(64, 58, 33), { base: '#f6b02a', dark: '#d8860f', light: '#f6b02a' }, { recess: true, sep: false, sil: false,
      over: `<circle cx="64" cy="58" r="33" fill="none" stroke="#c97a0c" stroke-width="3"/>` }),
  ], { top: carve(dollar, '#f6b02a', 8) + shineArc(64, 58, 40, 200, 245) + dot(96, 34, 3.5) });
}

{ // cash: a stack of banknotes, front one detailed
  const g = tones('#5fd97a', .32, .4);
  const note = (y, t, extra, a = 0) => fill(rrect(64, y, 100, 50, 9, a), t, extra);
  const border = (y, a) => `<rect x="24" y="${y - 16}" width="80" height="32" rx="6" transform="rotate(${a} 64 ${y})" fill="none" stroke="#2f9e4d" stroke-width="3" opacity=".7"/>`;
  ICONS.cash = icon([
    note(46, tones('#44c463', .35, .3), { band: 4, over: border(46, -6) }, -6),
    note(56, tones('#52cf6f', .35, .3), { band: 4, over: border(56, 4) }, 4),
    note(70, g, { over:
      `<rect x="24" y="54" width="80" height="32" rx="6" fill="none" stroke="#2f9e4d" stroke-width="3"/>` +
      `<circle cx="64" cy="70" r="12" fill="#3fb85e" stroke="#2f9e4d" stroke-width="3"/>` +
      `<circle cx="35" cy="70" r="3.5" fill="#2f9e4d"/><circle cx="93" cy="70" r="3.5" fill="#2f9e4d"/>` +
      `<path d="M69 64.5C67.5 62.8 65.8 62.3 64 62.3C61.3 62.3 59.5 63.8 59.5 66C59.5 68.4 62 69.1 64.5 69.8C67 70.5 69.2 71.4 69.2 74C69.2 76.3 67 77.7 64.2 77.7C61.9 77.7 60 76.7 59 75M64 59.5V80.5" fill="none" stroke="#e9ffe9" stroke-width="3.6" stroke-linecap="round"/>` }),
  ], { top: glint(30, 52, 8, 3, -8, .8) });
}

{ // gem: brilliant cut, every facet lit from the top-left
  const t = { base: '#3fc4f2', dark: '#1d5fb5', light: '#d9f8ff' };
  const A = [18, 44], B = [36, 18], C = [92, 18], D = [110, 44], E = [64, 112];
  const m1 = [46, 44], m2 = [82, 44], t1 = [52, 18], t2 = [76, 18];
  const F = (pts, n) => `<polygon points="${pts.map(p => p.join(',')).join(' ')}" fill="${facetColor(t, ...n)}"/>`;
  const facets = [
    F([A, B, m1], [-1, -1]), F([B, t1, m1], [-.2, -1]), F([t1, t2, m2, m1], [0, -1]), F([t2, C, m2], [.3, -1]), F([C, D, m2], [1, -.8]),
    F([A, m1, E], [-1, .25]), F([m1, m2, E], [.1, .5]), F([m2, D, E], [1, .4]),
  ].join('') + `<path d="M18 44H110M46 44L36 18M46 44L52 18M82 44L76 18M82 44L92 18M46 44L64 112M82 44L64 112" fill="none" stroke="#1d5fb5" stroke-width="2" stroke-linejoin="round" opacity=".45"/>`;
  ICONS.gem = icon([fill(roundPoly([A, B, C, D, E], [4, 5, 5, 4, 6]), t, { facets, rim: [0, 0], band: 0 })],
    { top: `<polygon points="40,23 50,23 44,40 32,40" fill="#fff" opacity=".9"/>` + dot(90, 50, 3) + sparkle(108, 16, 7) });
}

{ // robux-style hex coin
  const hexP = (cx, cy, r) => Array.from({ length: 6 }, (_, i) => rot([cx, cy - r], i * 60, cx, cy));
  const outer = roundPoly(hexP(64, 60, 50), 12), inner = roundPoly(hexP(64, 60, 25), 5);
  ICONS.robux = icon([
    fill(outer, { base: '#eef1f6', dark: '#a9b1c2', light: '#ffffff' }),
    fill(inner, { base: '#33c94f', dark: '#1d8a35', light: '#33c94f' }, { recess: true, sil: false }),
  ], { top: glint(42, 30, 10, 4, -30) });
}

// ---------- stats ----------
ICONS.players = icon([
  fill(circleD(86, 36, 15), tones('#3a8ff0', .3, .3)),
  fill('M58 98C58 78 70 64 86 64C102 64 112 78 112 98Z', tones('#3a8ff0', .3, .3), { rim: [0, -6] }),
  fill(circleD(48, 44, 19), tones('#5cd2ff', .32, .45)),
  fill('M14 108C14 86 28 72 48 72C68 72 82 86 82 108Z', tones('#5cd2ff', .32, .45), { rim: [0, -6] }),
], { top: glint(41, 35, 7, 4) + glint(30, 86, 7, 3, -50, .85) });

{ // stopwatch: purple (tickrate)
  const p = tones('#c47dff', .32, .4);
  const ticks = Array.from({ length: 12 }, (_, i) => { const [a, b] = [rot([64, 38], i * 30, 64, 66), rot([64, i % 3 ? 42 : 45], i * 30, 64, 66)];
    return `<path d="M${f1(a[0])} ${f1(a[1])}L${f1(b[0])} ${f1(b[1])}" stroke="${i % 3 ? '#b9bdc8' : '#6b7080'}" stroke-width="${i % 3 ? 2.5 : 4}" stroke-linecap="round"/>`; }).join('');
  ICONS.stopwatch = icon([
    fill(rrect(64, 23, 12, 10, 2), tones('#9aa0ab', .3, .3), { band: 0 }),
    fill(rrect(64, 17, 26, 10, 4), p, { band: 3 }),
    fill(rrect(100, 30, 15, 10, 3, 45), p, { band: 3 }),
    fill(circleD(64, 66, 44), p),
    fill(circleD(64, 66, 32), { base: '#ffffff', dark: '#d5d9e6', light: '#ffffff' }, { recess: true, over: ticks +
      `<path d="M64 66V44" stroke="${INK}" stroke-width="6" stroke-linecap="round"/><path d="M64 66L81 76" stroke="#ff4f6a" stroke-width="4.5" stroke-linecap="round"/>` +
      `<circle cx="64" cy="66" r="5.5" fill="${INK}"/><circle cx="64" cy="66" r="2" fill="#fff"/>` }),
  ], { top: shineArc(64, 66, 38, 205, 250, 5) });
}

ICONS.orb = icon([
  fill(circleD(64, 60, 47), { base: '#3fdc5a', dark: '#1d9a3a', light: '#3fdc5a' }, { rim: [-3, -8], band: 0, facets:
    `<circle cx="56" cy="50" r="31" fill="#6cea80"/><circle cx="52" cy="45" r="19" fill="#93f3a2"/>` +
    `<path d="${arc(64, 60, 39, 100, 150)}" fill="none" stroke="#9cf5aa" stroke-width="4" stroke-linecap="round" opacity=".7"/>` }),
], { top: glint(44, 36, 13, 7.5) + dot(78, 28, 3.5) + sparkle(108, 18, 7) });

ICONS.ghost = icon([
  fill('M20 96V58C20 33 39 14 64 14C89 14 108 33 108 58V96C108 104 99 106 94.7 100C91 95 84 95 80.3 100C76 106 67.6 106 64 100C60 95 52 95 48 100C44 106 35 106 33 100C29 95 20 95 20 96Z',
    { base: '#f2f4ff', dark: '#adb5df', light: '#ffffff' }, { over:
    `<ellipse cx="50" cy="54" rx="7" ry="10" fill="${INK}"/><ellipse cx="78" cy="54" rx="7" ry="10" fill="${INK}"/>` +
    `<circle cx="52.5" cy="50" r="3" fill="#fff"/><circle cx="80.5" cy="50" r="3" fill="#fff"/>` +
    `<ellipse cx="38" cy="70" rx="6" ry="3.5" fill="#ff9ec8" opacity=".75"/><ellipse cx="90" cy="70" rx="6" ry="3.5" fill="#ff9ec8" opacity=".75"/>` +
    `<path d="M58 70Q64 76 70 70" fill="none" stroke="${INK}" stroke-width="3.5" stroke-linecap="round"/>` }),
], { top: glint(40, 30, 10, 5, -35) });

{ // bolt: faceted, light left plane and shadowed right plane
  const t = { base: '#3aa8ff', dark: '#1a5fc4', light: '#9adcff' };
  const P = [[76, 10], [28, 68], [58, 68], [46, 114], [100, 50], [70, 50], [88, 10]];
  const facets = `<polygon points="0,0 82,0 64,50 52,114 0,128" fill="${t.light}"/>` + `<polygon points="88,10 70,50 100,50 128,30 128,0" fill="${mix(t.base, t.dark, .25)}"/>`;
  ICONS.bolt_blue = icon([fill(roundPoly(P, [4, 4, 3, 4, 4, 3, 4]), t, { band: 0, rim: [-2, -6], facets })],
    { top: `<polygon points="72,20 78,20 60,46 54,46" fill="#fff" opacity=".9"/>` });
}

{ // rune bulk: three rune stones fanned out (more runes per roll)
  const t = tones('#ff4848', .32, .4);
  const tab = (cx, cy, a, w = 44, h = 52) => fill(rrect(cx, cy, w, h, 10, a), t);
  const g = (cx, cy, a, s) => `<g transform="translate(${cx} ${cy}) rotate(${a}) scale(${s}) translate(-64 -64)">${carve('M54 94V34L78 54', '#ff4848', 11)}</g>`;
  ICONS.rune_bulk = icon([
    { ...tab(36, 54, -18), over: g(36, 54, -18, .45) },
    { ...tab(92, 54, 18), over: g(92, 54, 18, .45) },
    { ...tab(64, 74, 0, 46, 54), over: g(64, 74, 0, .5) },
  ], { top: glint(51, 55, 6, 2.5, -20) + glint(22, 38, 5, 2, -38, .85) });
}

ICONS.magnifier = icon([
  stroke('M82 82L102 102', '#6b4a3a', 16, { shine: 'M89 86L99 96', shineW: 3 }),
  fill(circleD(54, 52, 38), tones('#ff8a3d', .3, .4)),
  fill(circleD(54, 52, 25), { base: '#a6ecff', dark: '#5fbfe8', light: '#a6ecff' }, { recess: true }),
], { top: shineArc(54, 52, 17, 200, 260, 5) + dot(64, 40, 2.5) + glint(30, 30, 7, 3, -45, .9) });

ICONS.camera = icon([
  fill(rrect(50, 26, 28, 16, 5), tones('#2f6fe0', .3, .3), { band: 3 }),
  fill(rrect(64, 66, 104, 76, 16), tones('#3aa8ff', .3, .4), { over: `<rect x="86" y="38" width="16" height="9" rx="3" fill="#dff4ff" stroke="${INK}" stroke-width="3"/>` }),
  fill(circleD(64, 68, 28), { base: '#e9edf5', dark: '#9aa3b6', light: '#ffffff' }),
  fill(circleD(64, 68, 17), { base: '#262a3e', dark: '#12131c', light: '#262a3e' }, { recess: true, sep: false, sil: false }),
], { top: glint(57, 61, 6, 3.5) + dot(70, 74, 2) + glint(26, 44, 8, 3.5, -15, .85) + `<circle cx="28" cy="88" r="4" fill="#ff4f6a" stroke="${INK}" stroke-width="2.5"/>` });

ICONS.lock = icon([
  stroke('M40 60V44C40 30 50 22 64 22C78 22 88 30 88 44V60', '#c9ced9', 12, { shine: 'M44 42C45 34 50 29 56 27' }),
  fill(rrect(64, 82, 88, 56, 12), tones('#ffc63a', .3, .45), { over:
    `<path d="M64 70C59 70 56 73.5 56 78C56 81 57.5 83.5 60 84.8V92C60 94 61.5 95 64 95C66.5 95 68 94 68 92V84.8C70.5 83.5 72 81 72 78C72 73.5 69 70 64 70Z" fill="${INK}"/>` }),
], { top: glint(32, 66, 9, 3.5, -10) });

{ // check: two-plane bevel along the centre line
  const t = { base: '#3fdc5a', dark: '#178a2c', light: '#9cf5a8' };
  const P = [[12, 62], [32, 42], [52, 62], [96, 18], [116, 38], [52, 104]];
  ICONS.check = icon([fill(roundPoly(P, 7), t, { band: 0, rim: [0, -6], facets: `<polygon points="0,0 128,0 128,6 106,28 52,83 22,52 0,30" fill="${t.light}"/>` })],
    { top: `<polygon points="96,24 104,32 99,37 91,29" fill="#fff" opacity=".9"/>` });
}

{ // star: each arm split into a lit and a shaded plane
  const t = { base: '#ffcb2e', dark: '#d9800c', light: '#fff1a0' };
  const c = [64, 66], P = starPts(64, 66, 54, 25);
  let facets = '';
  for (let i = 0; i < 10; i += 2) {
    const o = P[i], a = P[(i + 9) % 10], b = P[i + 1];
    const n = (p, q) => { const mx = (p[0] + q[0]) / 2 - c[0], my = (p[1] + q[1]) / 2 - c[1]; return [mx, my]; };
    facets += tri(c, a, o, facetColor(t, ...n(a, o))) + tri(c, o, b, facetColor(t, ...n(o, b)));
  }
  ICONS.star_gold = icon([fill(roundPoly(P, P.map((_, i) => i % 2 ? 3 : 8)), t, { band: 0, rim: [0, 0], facets })],
    { top: glint(56, 30, 3.5, 9, 20) + sparkle(110, 18, 6) + sparkle(18, 104, 5) });
}

{ // dice: clone chance
  const t = tones('#ffd84a', .3, .45), pip = '#8a5a00';
  const pips = (cx, cy, a, pts, r) => pts.map(([x, y]) => { const [px, py] = rot([cx + x, cy + y], a, cx, cy);
    return `<circle cx="${f1(px)}" cy="${f1(py + 1.6)}" r="${r}" fill="${light('#ffd84a', .55)}"/><circle cx="${f1(px)}" cy="${f1(py)}" r="${r}" fill="${pip}"/>`; }).join('');
  ICONS.dice = icon([
    fill(rrect(86, 42, 44, 44, 10, 18), tones('#ffe48a', .3, .45), { over: pips(86, 42, 18, [[-10, -10], [10, 10]], 4.5) }),
    fill(rrect(54, 72, 66, 66, 14, -10), t, { over: pips(54, 72, -10, [[-17, -17], [17, -17], [0, 0], [-17, 17], [17, 17]], 6) }),
  ], { top: glint(33, 51, 8, 3.5, -25) });
}

{ // clone: a rune stone with its copy, plus a green +
  const t = tones('#ffd84a', .3, .45);
  ICONS.clone = icon([
    fill(rrect(76, 46, 54, 60, 11), tones('#ffeaa0', .3, .45), { over: `<g transform="translate(76 46) scale(.5) translate(-64 -64)">${carve('M52 34V94M52 50L78 36M52 66L78 52', '#ffeaa0', 12)}</g>` }),
    fill(rrect(52, 72, 54, 60, 11), t, { over: `<g transform="translate(52 72) scale(.5) translate(-64 -64)">${carve('M52 34V94M52 50L78 36M52 66L78 52', '#ffd84a', 12)}</g>` }),
    fill(circleD(98, 94, 14), tones('#46ef55', .3, .4), { band: 3, over: `<path d="M98 87V101M91 94H105" stroke="#fff" stroke-width="5" stroke-linecap="round"/>` }),
  ], { top: glint(36, 52, 7, 3, -20) });
}

{ // four-leaf clover: heart leaves meeting in the middle
  const t = tones('#4cf05a', .35, .4);
  const heart = 'M64 58C52 50 38 42 38 29C38 19 46 13 54 14C59 15 62 18 64 23C66 18 69 15 74 14C82 13 90 19 90 29C90 42 76 50 64 58Z';
  const leaves = [0, 90, 180, 270].map(a => fill(rotPath(heart, a, 64, 58), t, { rim: [0, -6], band: 3,
    over: `<path d="${rotPath('M64 54L64 30', a, 64, 58)}" stroke="#239c36" stroke-width="3" stroke-linecap="round" opacity=".6"/>` }));
  ICONS.clover = icon([
    stroke('M70 64C76 82 84 96 100 108', '#2a9c3a', 9, { sep: true }),
    ...leaves,
  ], { top: glint(52, 24, 6, 3.5, -30) + glint(30, 44, 5, 3, -60, .85) + `<circle cx="64" cy="58" r="4" fill="#239c36"/>` });
}

ICONS.anvil = icon([
  fill('M10 40C22 36 30 30 42 30L112 30L112 48L94 48C86 48 82 54 82 62L82 74L92 74C98 74 102 78 102 84L102 96L26 96L26 84C26 78 30 74 36 74L46 74L46 62C46 54 40 50 32 50C22 50 14 46 10 40Z',
    tones('#8f98ad', .4, .45), { band: 6 }),
], { top: glint(52, 36, 14, 2.5, 0, .9) + spark(92, 15, 9) + spark(108, 22, 6) + spark(78, 18, 5) });

{ // gift: lid, box, ribbon and bow
  const box = tones('#b45cff', .32, .4), rib = tones('#ffd84a', .3, .45);
  const band = (x, y, h) => `<rect x="${x}" y="${y}" width="16" height="${h}" fill="${rib.base}"/><rect x="${x + 11}" y="${y}" width="5" height="${h}" fill="${rib.dark}" opacity=".55"/>`;
  ICONS.gift = icon([
    fill(rrect(64, 88, 84, 44, 6), box, { band: 0, facets: band(56, 60, 60) }),
    fill(rrect(64, 58, 100, 22, 7), box, { band: 4, facets: band(56, 40, 40) }),
    fill('M64 46C56 30 40 22 32 28C26 33 30 43 40 46C48 48 58 47 64 46Z', rib, { band: 0 }),
    fill('M64 46C72 30 88 22 96 28C102 33 98 43 88 46C80 48 70 47 64 46Z', rib, { band: 0 }),
    fill(circleD(64, 45, 8), rib, { band: 2 }),
  ], { top: glint(26, 53, 7, 2.5, -5, .85) + glint(38, 32, 4, 2, -40, .9) });
}

const arrow = flip => {
  const t = { base: '#e8ebf2', dark: '#9aa1b1', light: '#ffffff' };
  const P = [[14, 48], [62, 48], [62, 18], [114, 64], [62, 110], [62, 80], [14, 80]].map(([x, y]) => [flip ? 128 - x : x, y]);
  return icon([fill(roundPoly(P, [5, 3, 6, 6, 6, 3, 5]), t, { band: 0, rim: [0, -6], facets: `<rect width="128" height="62" fill="${t.light}"/>` })]);
};
ICONS.arrow_r = arrow(false);
ICONS.arrow_l = arrow(true);

// ---------- rune stones ----------
export const RUNE_COLORS = ['#ffd64a', '#c8c4d2', '#7cffc8', '#46a0ff', '#ff6a1f', '#5cf2ff', '#ff5caa', '#fff0a0', '#ffc43c', '#e3a6ff'];
const GLYPHS = [
  'M52 34V94M52 50L78 36M52 66L78 52',
  'M48 94V34L80 52V94',
  'M52 34V94M52 46L76 64L52 82',
  'M54 94V34L78 54',
  'M76 36L50 64L76 92',
  'M46 94V34L82 70M82 94V34L46 70',
  'M42 36V92L86 36V92Z',
  'M72 32L50 56L78 72L56 96',
  'M64 94V34M42 40L64 62L86 40',
  'M64 32L86 64L64 96L42 64Z',
];
RUNE_COLORS.forEach((c, i) => {
  const t = tones(c, .4, .4);
  const face = `<rect x="27" y="22" width="74" height="76" rx="12" fill="${light(c, .14)}"/>` +
    `<rect x="27" y="22" width="74" height="76" rx="12" fill="none" stroke="${dark(c, .22)}" stroke-width="2.5" opacity=".7"/>`;
  ICONS['rune' + i] = icon([
    fill(rrect(64, 60, 96, 98, 20), t, { band: 5, over: face + `<g transform="translate(64 60) scale(.82) translate(-64 -64)">${carve(GLYPHS[i], light(c, .14), 12)}</g>` }),
  ], { top: glint(32, 24, 9, 3.5, -15) + (i >= 5 ? sparkle(108, 16, 6) : '') });
});
