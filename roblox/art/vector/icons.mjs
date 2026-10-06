// Hand-authored vector icon set in the chunky mobile-game style:
// thick black outline with a hard drop, flat base tone, a darker rim
// on the bottom-right, a lighter top band and one white highlight.
// Every icon is a 128x128 SVG. `node art/vector/build.mjs` writes the
// SVGs, the PNGs for Roblox and the contact sheet.

const INK = '#0b0c10';
const OUT = 11;   // outline stroke width
const DROP = 6;   // hard drop below the outline

const hex = c => c.match(/\w\w/g).map(h => parseInt(h, 16));
const mix = (a, b, t) => '#' + hex(a).map((v, i) => Math.round(v + (hex(b)[i] - v) * t).toString(16).padStart(2, '0')).join('');
export const dark = (c, t = .3) => mix(c, '#1a1030', t);
export const light = (c, t = .35) => mix(c, '#ffffff', t);

let uid = 0;
const attrs = a => Object.entries(a).map(([k, v]) => `${k}="${v}"`).join(' ');
const el = (s, extra = {}) => `<${s.tag} ${attrs({ ...s.a, ...extra })}/>`;

// shape constructors
export const circle = (cx, cy, r) => ({ tag: 'circle', a: { cx, cy, r } });
export const ellipse = (cx, cy, rx, ry) => ({ tag: 'ellipse', a: { cx, cy, rx, ry } });
export const rect = (x, y, width, height, rx = 0) => ({ tag: 'rect', a: { x, y, width, height, rx } });
export const path = d => ({ tag: 'path', a: { d } });
export const poly = pts => ({ tag: 'polygon', a: { points: pts } });

// A filled part: base colour with an auto rim shadow and top light band.
// `inner` replaces the auto shading with custom markup clipped to the part.
export const part = (shape, color, o = {}) => ({ shape, color, ...o });

function shade(p) {
  const id = 'c' + (uid++);
  const sx = p.rim?.[0] ?? -4, sy = p.rim?.[1] ?? -5;
  const lift = p.band ?? 5;
  let s = `<clipPath id="${id}">${el(p.shape)}</clipPath>`;
  s += el(p.shape, { fill: p.dk ?? dark(p.color) });
  s += `<g clip-path="url(#${id})">`;
  if (p.inner) s += p.inner;
  else {
    const id2 = id + 'b';
    s += el(p.shape, { fill: lift ? light(p.color, .3) : p.color, transform: `translate(${sx} ${sy})` });
    if (lift) s += `<clipPath id="${id2}">${el(p.shape, { transform: `translate(${sx} ${sy})` })}</clipPath>` +
      `<g clip-path="url(#${id2})">${el(p.shape, { fill: p.color, transform: `translate(${sx} ${sy + lift})` })}</g>`;
  }
  return s + '</g>';
}

// Stroke-only details (lines drawn on top of fills) can carry their own outline.
export const line = (d, color, w = 8, o = {}) => ({ line: true, d, color, w, ...o });

export function icon(parts, { hi = [], deco = '', under = '' } = {}) {
  uid = 0;
  const fills = parts.filter(p => !p.line), lines = parts.filter(p => p.line);
  const sil = fills.filter(p => !p.noOutline).map(p => el(p.shape, { fill: INK, stroke: INK, 'stroke-width': OUT, 'stroke-linejoin': 'round' })).join('')
    + lines.filter(l => l.outline !== false).map(l => `<path d="${l.d}" fill="none" stroke="${INK}" stroke-width="${l.w + OUT}" stroke-linecap="round" stroke-linejoin="round"/>`).join('');
  let s = under;
  s += `<g transform="translate(0 ${DROP})">${sil}</g>${sil}`;
  // parts and lines are painted in order so lines can sit between fills
  for (const p of parts) {
    if (p.line) {
      if (p.outline === 'inner') s += `<path d="${p.d}" fill="none" stroke="${INK}" stroke-width="${p.w + 6}" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${p.d}" fill="none" stroke="${p.color}" stroke-width="${p.w}" stroke-linecap="round" stroke-linejoin="round"/>`;
    } else {
      if (p.innerOutline) s += el(p.shape, { fill: 'none', stroke: INK, 'stroke-width': 6, 'stroke-linejoin': 'round' });
      s += shade(p);
    }
  }
  s += deco;
  s += hi.map(h => h.d ? `<path d="${h.d}" fill="#fff" opacity="${h.o ?? .95}"/>` :
    `<ellipse cx="${h[0]}" cy="${h[1]}" rx="${h[2]}" ry="${h[3]}" transform="rotate(${h[4] ?? -35} ${h[0]} ${h[1]})" fill="#fff" opacity="${h[5] ?? .95}"/>`).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">${s}</svg>`;
}

const sparkle = (x, y, r = 7) => `<path d="M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}Z" fill="#fff" stroke="${INK}" stroke-width="3" stroke-linejoin="round"/>`;

function starPts(cx, cy, R, r, n = 5, rot = -90) {
  const p = [];
  for (let i = 0; i < n * 2; i++) {
    const a = (rot + i * 180 / n) * Math.PI / 180, rr = i % 2 ? r : R;
    p.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
  }
  return p;
}
// rounded polygon path (quadratic corners)
function roundPoly(pts, rad) {
  const n = pts.length; let d = '';
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n];
    const v = (a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy); return [dx / L, dy / L, L]; };
    const [ax, ay, la] = v(p1, p0), [bx, by, lb] = v(p1, p2);
    const r = Math.min(rad, la / 2, lb / 2);
    const s = [p1[0] + ax * r, p1[1] + ay * r], e = [p1[0] + bx * r, p1[1] + by * r];
    d += (i ? 'L' : 'M') + s.map(x => x.toFixed(1)).join(' ') + 'Q' + p1.map(x => x.toFixed(1)).join(' ') + ' ' + e.map(x => x.toFixed(1)).join(' ');
  }
  return d + 'Z';
}

const dollar = (cx, cy, s, color) => {
  const k = s / 40;
  const d = `M${cx + 12 * k} ${cy - 11 * k}C${cx + 8 * k} ${cy - 18 * k} ${cx - 13 * k} ${cy - 18 * k} ${cx - 13 * k} ${cy - 8 * k}C${cx - 13 * k} ${cy + 2 * k} ${cx + 13 * k} ${cy - 2 * k} ${cx + 13 * k} ${cy + 8 * k}C${cx + 13 * k} ${cy + 19 * k} ${cx - 9 * k} ${cy + 19 * k} ${cx - 13 * k} ${cy + 11 * k}M${cx} ${cy - 24 * k}V${cy + 24 * k}`;
  return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${9 * k}" stroke-linecap="round" stroke-linejoin="round"/>`;
};

export const ICONS = {};
const G = '#ffd23f';

ICONS.coin = icon([
  part(circle(64, 61, 48), G, { dk: '#e0900f' }),
  part(circle(64, 61, 33), '#f6b41f', { dk: '#ffe27a', rim: [4, 5], band: 0 }),
], { deco: dollar(64, 62, 40, '#b66a05'), hi: [[38, 34, 13, 6], [97, 40, 3, 3, 0]] });

ICONS.cash = icon([
  part(rect(14, 24, 92, 56, 9), '#2fbf5a', { dk: '#178a3c' }),
  part(rect(24, 44, 92, 56, 9), '#5be37a', { dk: '#24a64a' }),
  part(circle(70, 72, 17), '#2fbf5a', { dk: '#d8ffe0', rim: [3, 4], band: 0 }),
], { deco: dollar(70, 72, 26, '#0f6b2c') + `<circle cx="38" cy="58" r="4" fill="#24a64a"/><circle cx="102" cy="86" r="4" fill="#24a64a"/>`, hi: [{ d: 'M32 51h30a4 4 0 0 1 0 6h-30a3 3 0 0 1 0-6z', o: .8 }] });

{ // gem: faceted crown + pavilion, each facet its own tone
  const base = '#4fd4ff';
  const facets = [
    ['20,46 38,22 50,22 44,46', light(base, .45)],
    ['44,46 50,22 78,22 84,46', light(base, .2)],
    ['84,46 78,22 90,22 108,46', base],
    ['20,46 44,46 64,110', base],
    ['44,46 84,46 64,110', dark(base, .12)],
    ['84,46 108,46 64,110', dark(base, .35)],
  ].map(([p, c]) => `<polygon points="${p}" fill="${c}"/>`).join('');
  ICONS.gem = icon([part(poly('20,46 38,22 90,22 108,46 64,110'), base, { inner: facets })],
    { deco: `<path d="M20 46H108M44 46L50 22M84 46L78 22M44 46L64 110M84 46L64 110" stroke="${dark(base, .5)}" stroke-width="2.5" fill="none" opacity=".5"/>` + sparkle(104, 18),
      hi: [{ d: 'M40 27h12l-5 15h-15z', o: .9 }] });
}

{ // robux-style hex coin
  const hexP = (cx, cy, r) => Array.from({ length: 6 }, (_, i) => { const a = (i * 60 - 90) * Math.PI / 180; return [cx + Math.cos(a) * r, cy + Math.sin(a) * r]; });
  ICONS.robux = icon([
    part(path(roundPoly(hexP(64, 62, 52), 12)), '#f2f4f7', { dk: '#a9b0bd' }),
    part(path(roundPoly(hexP(64, 62, 26), 6)), '#3fdc5a', { dk: '#e8ffe9', rim: [3, 4], band: 0, innerOutline: true }),
  ], { hi: [[40, 30, 10, 5, -30]] });
}

ICONS.players = icon([
  part(circle(86, 40, 17), '#3a9bff'),
  part(path('M58 104c0-24 12-38 28-38s28 14 28 38z'), '#3a9bff'),
  part(circle(48, 46, 20), '#5cf2ff', { dk: '#25a6c8' }),
  part(path('M14 112c0-28 14-44 34-44s34 16 34 44z'), '#5cf2ff', { dk: '#25a6c8' }),
], { hi: [[40, 36, 7, 4], [30, 84, 6, 3, -60]] });

ICONS.stopwatch = icon([
  part(rect(54, 8, 20, 16, 5), '#c47dff'),
  part(rect(90, 22, 16, 13, 4), '#c47dff', { band: 0 }),
  part(circle(64, 70, 47), '#ff5fbf', { dk: '#c02a8a' }),
  part(circle(64, 70, 35), '#ffffff', { dk: '#d8dbe6', rim: [4, 5], band: 0, innerOutline: true }),
  line('M64 70V48', INK, 8, { outline: false }),
  line('M64 70L78 80', INK, 8, { outline: false }),
], { deco: `<circle cx="64" cy="70" r="6" fill="#ff5fbf" stroke="${INK}" stroke-width="3"/>`, hi: [[34, 44, 9, 4, -50]] });

ICONS.orb = icon([
  part(circle(64, 62, 50), '#3fdc5a', { dk: '#1f9a3a', inner:
    `<circle cx="58" cy="54" r="46" fill="#3fdc5a"/><circle cx="52" cy="46" r="32" fill="${light('#3fdc5a', .25)}"/>` }),
], { hi: [[42, 34, 14, 8], [86, 88, 4, 3, 0, .6]], deco: sparkle(110, 20) });

ICONS.ghost = icon([
  part(path('M22 108V60c0-26 18-46 42-46s42 20 42 46v48l-14-10-14 12-14-12-14 12-14-12z'), '#f4f6ff', { dk: '#a9b2d6', rim: [-4, -6] }),
], { deco: `<ellipse cx="50" cy="58" rx="7" ry="10" fill="${INK}"/><ellipse cx="78" cy="58" rx="7" ry="10" fill="${INK}"/><ellipse cx="52" cy="54" rx="2.5" ry="3.5" fill="#fff"/><ellipse cx="80" cy="54" rx="2.5" ry="3.5" fill="#fff"/><ellipse cx="38" cy="74" rx="6" ry="4" fill="#ff9ec8" opacity=".7"/><ellipse cx="90" cy="74" rx="6" ry="4" fill="#ff9ec8" opacity=".7"/>`,
  hi: [[42, 30, 11, 5, -30]] });

ICONS.bolt_blue = icon([
  part(path(roundPoly([[76, 8], [26, 72], [58, 72], [44, 120], [102, 50], [70, 50], [88, 8]], 4)), '#3aa8ff', { dk: '#1c63c9' }),
], { hi: [{ d: 'M74 16h8l-14 28h-9z', o: .9 }], deco: sparkle(26, 30, 6) + sparkle(104, 98, 5) });

ICONS.stack = icon([
  part(rect(16, 84, 96, 26, 13), '#ff4848', { dk: '#b81d2b' }),
  part(rect(16, 54, 96, 26, 13), '#ff4848', { dk: '#b81d2b' }),
  part(rect(16, 24, 96, 26, 13), '#ff4848', { dk: '#b81d2b' }),
], { hi: [[36, 31, 12, 3.5, 0], [36, 61, 12, 3.5, 0, .7], [36, 91, 12, 3.5, 0, .6]] });

ICONS.magnifier = icon([
  line('M80 80L110 110', '#ff8a3d', 18),
  part(circle(54, 54, 40), '#ff8a3d', { dk: '#c45412' }),
  part(circle(54, 54, 26), '#8fe6ff', { dk: '#4cb4e6', rim: [4, 5], band: 0, innerOutline: true }),
], { hi: [[44, 42, 9, 5]] });

ICONS.camera = icon([
  part(rect(36, 18, 30, 16, 6), '#2f6fe0', { band: 0 }),
  part(rect(10, 28, 108, 80, 16), '#3aa8ff', { dk: '#1c63c9' }),
  part(circle(64, 68, 28), '#f2f4f7', { dk: '#a9b0bd', innerOutline: true }),
  part(circle(64, 68, 15), '#2a2d40', { dk: '#14151f', band: 0, innerOutline: true }),
], { deco: `<circle cx="100" cy="44" r="6" fill="#ff4f6a" stroke="${INK}" stroke-width="3"/>`, hi: [[24, 42, 9, 4, -20], [58, 62, 5, 3]] });

ICONS.lock = icon([
  line('M38 58V42a26 26 0 0 1 52 0v16', '#b9bdc8', 14),
  part(rect(18, 54, 92, 62, 14), '#ffc63a', { dk: '#d08a0c' }),
], { deco: `<path d="M64 74a9 9 0 0 1 5 16.5V100h-10V90.5A9 9 0 0 1 64 74z" fill="${INK}"/>`, hi: [[34, 66, 10, 4, -15]] });

ICONS.check = icon([
  part(path(roundPoly([[10, 66], [28, 48], [52, 72], [100, 18], [118, 36], [52, 108]], 7)), '#46ef55', { dk: '#1a9c2a' }),
], { hi: [{ d: 'M98 26l8 8-4 4-8-8z', o: .9 }] });

ICONS.star_gold = icon([
  part(path(roundPoly(starPts(64, 68, 56, 26), 7)), G, { dk: '#e0900f' }),
], { hi: [{ d: 'M60 28l6 0-4 22-8 2z', o: .9 }], deco: sparkle(108, 18) + sparkle(18, 108, 5) });

ICONS.anvil = icon([
  part(path('M14 34h76c10 0 24 4 28 10H90v12c0 8-10 14-20 16v16h12c6 0 10 4 10 10v8H36v-8c0-6 4-10 10-10h12V72C40 70 30 60 26 48H14z'), '#8b93a8', { dk: '#4c5266' }),
], { hi: [[30, 40, 12, 3, 0]], deco: `<path d="M86 24l6-12M100 28l10-8M74 22l-2-12" stroke="#ffd23f" stroke-width="6" stroke-linecap="round"/>` });

ICONS.gift = icon([
  part(rect(16, 50, 96, 24, 8), '#c47dff', { band: 0 }),
  part(rect(24, 70, 80, 46, 8), '#b45cff', { dk: '#7a3fe0' }),
  part(rect(56, 50, 16, 66, 0), '#ffd84a', { dk: '#e0a412', noOutline: true }),
  line('M64 48C56 30 34 22 34 38c0 10 18 12 30 10', '#ffd84a', 8, { outline: 'inner' }),
  line('M64 48C72 30 94 22 94 38c0 10-18 12-30 10', '#ffd84a', 8, { outline: 'inner' }),
], { hi: [[30, 56, 8, 3, 0]] });

const arrow = flip => {
  const pts = [[10, 64], [56, 18], [56, 44], [116, 44], [116, 84], [56, 84], [56, 110]].map(([x, y]) => [flip ? 128 - x : x, y]);
  return icon([part(path(roundPoly(pts, 7)), '#ffffff', { dk: '#9aa0ab' })], { hi: [] });
};
ICONS.arrow_l = arrow(false);
ICONS.arrow_r = arrow(true);

{ // four-leaf clover
  // build as a single compound path so outline/shading work on one shape
  const leafD = r => {
    const t = (x, y) => { const a = r * Math.PI / 180, dx = x - 64, dy = y - 58; return `${(64 + dx * Math.cos(a) - dy * Math.sin(a)).toFixed(1)} ${(58 + dx * Math.sin(a) + dy * Math.cos(a)).toFixed(1)}`; };
    return `M${t(64, 58)}C${t(48, 50)} ${t(34, 42)} ${t(36, 28)}C${t(38, 14)} ${t(58, 12)} ${t(64, 26)}C${t(70, 12)} ${t(90, 14)} ${t(92, 28)}C${t(94, 42)} ${t(80, 50)} ${t(64, 58)}Z`;
  };
  ICONS.clover = icon([
    line('M64 62C66 84 72 98 88 114', '#2a9c3a', 9),
    part(path([0, 90, 180, 270].map(leafD).join('')), '#4cf05a', { dk: '#1f9a3a' }),
  ], { deco: `<path d="M64 58L64 34M64 58L88 58M64 58L64 82M64 58L40 58" stroke="#2a9c3a" stroke-width="3" stroke-linecap="round" opacity=".7"/>`, hi: [[50, 30, 6, 3.5], [32, 50, 4, 2.5, -60, .7]] });
}

// rune stones: rounded tablet in the rune's colour with a carved glyph
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
  const deep = dark(c, .5);
  const glyph = `<path d="${GLYPHS[i]}" fill="none" stroke="${light(c, .55)}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" transform="translate(0 3)"/>` +
    `<path d="${GLYPHS[i]}" fill="none" stroke="${deep}" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>` +
    `<path d="${GLYPHS[i]}" fill="none" stroke="${dark(c, .7)}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" transform="translate(0 -2)" opacity=".6"/>`;
  ICONS['rune' + i] = icon([
    part(rect(14, 12, 100, 104, 22), c, { dk: dark(c, .38) }),
  ], { deco: glyph + (i >= 5 ? sparkle(108, 16, 7) : ''), hi: [[34, 26, 10, 4, -20]] });
});
