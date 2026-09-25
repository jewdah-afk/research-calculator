// styles.js - the four clean style kits. Each kit paints the same content (scenes.js: P panel, HUD, node labels)
// with its own complete vocabulary of surfaces, tabs, cards (BUY / OWNED / LOCKED), buttons and HUD pieces.
//   1 Sleek sci-fi   (Destiny 2 director, Nothing OS)  translucent dark, 1 px hairlines, corner ticks, registration marks
//   2 Sharp          (Valorant, Apex, F1 broadcast)     opaque slabs, angled cuts, position boxes, segment meters, no glow
//   3 Soft premium   (Honkai: Star Rail menus)          top-lit gradients, fine lines with diamond ends, orbit linework, rings
//   4 Frosted glass  (visionOS)                         blurred glass, specular edges, grain, capsules, recessed wells
// The map stays the hero VFX zone; the UI is restrained but crafted: a strict type system (Montserrat text, Sarpanch
// digit runs, tracked caps micro labels), depth from light (1 px specular top edges, inner edge light, grain), data as
// decoration (sparklines, completion rings, segment meters) and one accent: the layer hue.
// Panel-local grid shared by every kit so the stills compare like for like (1072 x 958 panel).
const STYLES = {};
const G = {
  pad: 40, tabsY: 114, tabsH: 46, heroY: 182, ctaW: 430, ctaH: 96, chipY: 290, chipH: 34,
  sumY: 344, sumH: 42, t3Y: 408, cardY: 432, cardH: 282, t4Y: 738, lockY: 762, lockH: 158, cw: 236, gap: 16,
};
G.cx = i => G.pad + i * (G.cw + G.gap);
const HUE = K.HUES.p, HUE_HI = K.lift(HUE, 0.55), HUE_DEEP = K.sink(HUE, 0.55);
const A = K.abs, E = K.esc;

// ================================================================================================ craft helpers
// grain: one 128 px seeded mono noise tile (Roblox: a tiled ImageLabel at ImageTransparency ~.93 under the text)
const NOISE = (() => {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const x = c.getContext('2d'), d = x.createImageData(128, 128); let s = 1234567;
  for (let i = 0; i < 128 * 128; i++) { s = (s * 1103515245 + 12345) & 0x7fffffff; const v = (s >> 8) & 255; d.data[i * 4] = d.data[i * 4 + 1] = d.data[i * 4 + 2] = v; d.data[i * 4 + 3] = 255; }
  x.putImageData(d, 0, 0); return c.toDataURL();
})();
const grain = (parent, a = 0.06, style = '') => K.el(parent, 'div', `position:absolute;inset:0;background:url(${NOISE}) 0 0/128px;opacity:${a};mix-blend-mode:overlay;pointer-events:none;border-radius:inherit;${style}`);
// four L-shaped corner ticks drawn by one element
function ticks(parent, x, y, w, h, { len = 12, th = 2, color = '#fff', out = 0, style = '' } = {}) {
  const c = `linear-gradient(${color},${color})`;
  const bg = [`${c} 0 0/${len}px ${th}px`, `${c} 0 0/${th}px ${len}px`, `${c} 100% 0/${len}px ${th}px`, `${c} 100% 0/${th}px ${len}px`,
    `${c} 0 100%/${len}px ${th}px`, `${c} 0 100%/${th}px ${len}px`, `${c} 100% 100%/${len}px ${th}px`, `${c} 100% 100%/${th}px ${len}px`].map(s => s + ' no-repeat').join(',');
  return A(parent, x - out, y - out, w + 2 * out, h + 2 * out, `background:${bg};pointer-events:none;${style}`);
}
// registration mark (+)
const reg = (parent, x, y, s = 9, color = 'rgba(255,255,255,.4)') => A(parent, x - s / 2, y - s / 2, s, s, `background:linear-gradient(${color},${color}) 50% 0/1px 100% no-repeat,linear-gradient(${color},${color}) 0 50%/100% 1px no-repeat`);
// deterministic series for sparklines (rising with texture)
function series(n, seed, { rise = 1, jitter = 0.12 } = {}) {
  let s = seed, v = []; for (let i = 0; i < n; i++) { s = (s * 16807) % 2147483647; v.push(0.08 + (i / (n - 1)) * 0.8 * rise + ((s / 2147483647) - 0.5) * jitter + Math.sin(i * 0.9) * jitter * 0.4); }
  return v;
}
let SVGID = 0;
function sparkline(w, h, color, { seed = 7, n = 26, fill = 0.22, dot = true, sw = 1.6, rise = 1, jitter = 0.12, grid = null } = {}) {
  const v = series(n, seed, { rise, jitter }), pts = v.map((y, i) => [(i / (n - 1)) * (w - 4) + 2, h - 3 - Math.max(0, Math.min(1, y)) * (h - 6)]);
  const d = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' '), id = 'sg' + (SVGID++), [lx, ly] = pts[pts.length - 1];
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="overflow:visible"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity="${fill}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    ${grid ? [0.25, 0.5, 0.75].map(f => `<line x1="0" x2="${w}" y1="${(h * f).toFixed(1)}" y2="${(h * f).toFixed(1)}" stroke="${grid}" stroke-width="1" stroke-dasharray="2 3"/>`).join('') : ''}
    ${fill ? `<path d="${d} L${lx} ${h} L2 ${h} Z" fill="url(#${id})"/>` : ''}<path d="${d}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="round"/>
    ${dot ? `<circle cx="${lx}" cy="${ly}" r="${sw + 1.6}" fill="${color}"/><circle cx="${lx}" cy="${ly}" r="${sw + 5}" fill="${color}" opacity=".22"/>` : ''}</svg>`;
}
// mini bar histogram (F1 / broadcast)
function bars(w, h, color, { seed = 11, n = 14, gap = 2, dim = 'rgba(255,255,255,.16)' } = {}) {
  const v = series(n, seed, { jitter: 0.25 }), bw = (w - gap * (n - 1)) / n;
  return `<svg width="${w}" height="${h}">${v.map((y, i) => { const bh = Math.max(3, Math.min(1, y) * h); return `<rect x="${(i * (bw + gap)).toFixed(1)}" y="${(h - bh).toFixed(1)}" width="${bw.toFixed(1)}" height="${bh.toFixed(1)}" fill="${i === n - 1 ? color : dim}"/>`; }).join('')}</svg>`;
}
// completion ring (thin arc meter), optional tick marks inside
function ring(size, frac, color, { track = 'rgba(255,255,255,.14)', sw = 2, cap = 'round', ticksN = 0, tickColor = 'rgba(255,255,255,.22)' } = {}) {
  const c = size / 2, r = c - sw, C = 2 * Math.PI * r;
  const tk = ticksN ? Array.from({ length: ticksN }, (_, i) => { const a = (i / ticksN) * Math.PI * 2, r0 = r - sw - 2, r1 = r - sw - 5; return `<line x1="${(c + r0 * Math.cos(a)).toFixed(2)}" y1="${(c + r0 * Math.sin(a)).toFixed(2)}" x2="${(c + r1 * Math.cos(a)).toFixed(2)}" y2="${(c + r1 * Math.sin(a)).toFixed(2)}" stroke="${tickColor}" stroke-width="1"/>`; }).join('') : '';
  return `<svg width="${size}" height="${size}" style="transform:rotate(-90deg)"><circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${track}" stroke-width="${sw}"/>
    <circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="${cap}" stroke-dasharray="${(C * frac).toFixed(2)} ${C.toFixed(2)}"/>${tk}</svg>`;
}
// segment meter (n cells, k lit)
const seg = (n, k, { w = 4, h = 12, gap = 2, on = HUE, off = 'rgba(255,255,255,.16)', skew = 0, radius = 0 } = {}) =>
  `<span style="display:inline-flex;gap:${gap}px;align-items:center">${Array.from({ length: n }, (_, i) => `<i style="display:block;width:${w}px;height:${h}px;background:${i < k ? on : off};border-radius:${radius}px;${skew ? `transform:skewX(${skew}deg)` : ''}"></i>`).join('')}</span>`;
const num = (v, { size = 16, weight = 800, color = '#fff', unit = '' } = {}) => `<span class="nowrap" style="font:${weight} ${size}px/1 Sarpanch;color:${color}">${K.nf(v, unit)}</span>`;
const body = (t, { size = 15, color = '#d3d9e4', lh = 1.36, style = '' } = {}) => `<div style="font:600 ${size}px/${lh} Montserrat;color:${color};${style}">${E(t)}</div>`;
const cardTitle = (t, { size = 20, color = '#fff', italic = true, style = '' } = {}) => `<div style="font:${italic ? 'italic ' : ''}800 ${size}px/1.13 Montserrat;color:${color};padding-right:4px;${style}">${E(t)}</div>`;
const gemImg = (R, key, cx, cy, s) => { const im = K.el(R, 'img', `position:absolute;left:${cx - s / 2}px;top:${cy - s / 2}px;width:${s}px;height:${s}px`); im.src = K.GEM(key); return im; };
const pct = c => (c.prog[0] / c.prog[1]) * 100;

// =============================================================================================== 1 SLEEK SCI-FI
(() => {
  const S = {}, line = 'rgba(255,255,255,.12)', lineHi = 'rgba(255,255,255,.26)', soft = '#aab4c4', text = '#f3f6fb', ink = '#06101b';
  const GOOD = '#7fe6a0', GOOD_T = '#d7f7e1';
  const hair = (a = 0.12) => `box-shadow:inset 0 0 0 1px rgba(255,255,255,${a}),inset 0 1px 0 rgba(255,255,255,${(a + 0.08).toFixed(2)})`;
  S.backdrop = { blur: 9, dim: 0.42 };
  const caps = (t, o = {}) => K.caps(t, Object.assign({ size: 12, color: soft, track: 0.16, weight: 700 }, o));
  const micro = (t, color = '#7d8797') => `<span class="nowrap" style="font:700 13px/1 Sarpanch;color:${color};letter-spacing:.04em">${K.nf(t)}</span>`;

  S.panel = (R, P, { x, y, w, h }) => {
    const F = A(R, x, y, w, h, `background:linear-gradient(180deg,rgba(10,14,22,.9),rgba(6,9,15,.94));${hair(0.1)}`);
    A(F, 0, 0, w, h, `background:radial-gradient(ellipse 60% 38% at 18% 0%,${K.rgba(HUE, 0.13)},transparent 70%),radial-gradient(ellipse 50% 30% at 100% 100%,${K.rgba(HUE, 0.05)},transparent 70%)`);
    grain(F, 0.07);
    ticks(F, 0, 0, w, h, { len: 22, th: 2, color: 'rgba(255,255,255,.85)', out: 1 });
    A(F, 40, -1, 88, 3, `background:${HUE};box-shadow:0 0 10px ${K.rgba(HUE, 0.7)}`);
    reg(F, 20, G.tabsY + G.tabsH); reg(F, w - 20, G.tabsY + G.tabsH); reg(F, 20, G.t3Y); reg(F, w - 20, G.t3Y);
    // header: diamond emblem, title, row tag + subtitle, layer code, close
    A(F, 40, 30, 58, 58, 'display:grid;place-items:center', `<div style="position:absolute;inset:8px;transform:rotate(45deg);box-shadow:inset 0 0 0 1.5px ${HUE};background:${K.rgba(HUE, 0.12)}"></div><div style="position:absolute;inset:14px;transform:rotate(45deg);box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.35)}"></div><span style="position:relative;font:900 26px/1 Sarpanch;color:#fff">${P.sym}</span>`);
    A(F, 120, 28, null, null, `font:italic 900 44px/1 Montserrat;color:${text};letter-spacing:.01em`, P.title);
    A(F, 122, 80, null, 22, 'display:flex;align-items:center;gap:12px', `<span style="padding:4px 8px;box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.6)}">${caps(P.row, { color: HUE_HI, weight: 800 })}</span><span style="font:600 14px Montserrat;color:${soft}">${E(P.sub)}</span>`);
    A(F, w - 40 - 40 - 150, 35, 132, 40, 'display:flex;flex-direction:column;align-items:flex-end;justify-content:center;gap:7px', caps('Layer', { track: 0.2 }) + `<span style="font:800 16px/1 Sarpanch;color:#fff">${P.layer[0]} <span style="color:#6d7686">/ ${P.layer[1]}</span></span>`);
    A(F, w - 40 - 40, 35, 40, 40, `display:grid;place-items:center;${hair(0.22)}`, K.icon('close', 18, '#fff', { sw: 1.6 }));
    // tabs with index numbers
    const tb = A(F, G.pad, G.tabsY, w - 2 * G.pad, G.tabsH, `display:flex;align-items:stretch;box-shadow:inset 0 -1px 0 ${line}`);
    P.tabs.forEach((t, i) => {
      const on = !!t.on;
      K.el(tb, 'div', `position:relative;display:flex;align-items:center;gap:9px;padding:0 22px;${on ? `background:linear-gradient(0deg,${K.rgba(HUE, 0.16)},transparent);box-shadow:inset 0 -2px 0 ${HUE}` : ''}`,
        micro('0' + (i + 1), on ? HUE : '#6d7686') + `<span style="font:${on ? 'italic ' : ''}800 15px/1 Montserrat;letter-spacing:.1em;text-transform:uppercase;color:${on ? '#fff' : soft}">${E(t.label)}</span>` +
        (t.badge ? `<span style="display:grid;place-items:center;min-width:20px;height:18px;padding:0 5px;background:${on ? HUE : 'rgba(255,255,255,.14)'};font:800 13px/1 Sarpanch;color:${on ? ink : '#fff'}">${t.badge}</span>` : '') +
        (t.dot ? `<span style="width:7px;height:7px;transform:rotate(45deg);background:${K.GOLD};box-shadow:0 0 6px ${K.GOLD}"></span>` : ''));
    });
    K.el(tb, 'div', 'flex:1');
    K.el(tb, 'div', 'display:flex;align-items:center;gap:14px;padding-right:2px', `<span class="row" style="gap:6px">${K.icon('bolt', 14, K.GOLD)}${num(P.ready, { size: 15, color: K.GOLD })}${caps('Ready', { color: '#ffe08a', weight: 800 })}</span><span style="width:1px;height:18px;background:${lineHi}"></span>${seg(P.ownedN[1], P.ownedN[0], { w: 3, h: 12, gap: 2, on: GOOD, off: 'rgba(255,255,255,.18)' })}<span class="row" style="gap:6px">${num(P.owned, { size: 15, color: '#fff' })}${caps('Owned', { weight: 800 })}</span>`);
    // hero + a gain sparkline as decoration
    A(F, G.pad, G.heroY + 4, 2, 112, `background:linear-gradient(${HUE},${K.rgba(HUE, 0.1)})`);
    A(F, G.pad + 20, G.heroY + 4, null, null, 'display:flex;flex-direction:column;gap:12px', caps(P.hero.cap, { size: 13 }) +
      `<span style="font:800 60px/1 Sarpanch;color:#fff;text-shadow:0 0 30px ${K.rgba(HUE, 0.35)}">${E(P.hero.amt)}</span>` +
      `<span style="font:italic 900 20px/1 Montserrat;letter-spacing:.04em;text-transform:uppercase;color:${HUE_HI}">${E(P.hero.res)}</span>`);
    A(F, 424, G.heroY + 6, 148, null, 'display:flex;flex-direction:column;gap:8px', `<span class="row" style="justify-content:space-between">${caps('Gain · 60 s', { track: 0.12 })}${micro('+4.1%', '#8ff0ad')}</span>` +
      `<div style="padding:6px 0 4px;box-shadow:inset 0 -1px 0 ${line}">${sparkline(148, 44, HUE, { seed: 5, grid: 'rgba(255,255,255,.08)' })}</div><span class="row" style="justify-content:space-between">${micro('−60 s')}${micro('now')}</span>`);
    // CTA: the one solid light surface on the panel, ink type, key hint
    const cx = w - G.pad - G.ctaW, cy = G.heroY;
    ticks(F, cx, cy, G.ctaW, G.ctaH, { len: 12, th: 2, color: HUE_HI, out: 6 });
    const cta = A(F, cx, cy, G.ctaW, G.ctaH, `background:linear-gradient(180deg,${K.lift(HUE, 0.3)},${HUE} 60%,${K.sink(HUE, 0.08)});box-shadow:inset 0 1px 0 rgba(255,255,255,.7),0 14px 34px ${K.rgba(HUE, 0.3)}`,
      `<div style="position:absolute;right:0;top:0;bottom:0;width:150px;background:repeating-linear-gradient(135deg,rgba(6,16,27,.07) 0 2px,transparent 2px 9px)"></div>
       <div style="position:absolute;left:28px;top:21px;display:flex;flex-direction:column;gap:10px"><span style="font:italic 900 30px/1 Montserrat;color:${ink}">${P.cta.title}</span><span style="font:800 17px/1 Sarpanch;color:rgba(6,16,27,.8)">${K.nf(P.cta.gain)}</span></div>
       <div style="position:absolute;right:22px;top:50%;transform:translateY(-50%);display:flex;align-items:center;gap:10px"><span style="display:grid;place-items:center;width:30px;height:30px;box-shadow:inset 0 0 0 1.5px ${ink};font:800 15px Montserrat;color:${ink}">${P.cta.key}</span>${K.icon('chevR', 22, ink, { sw: 2.4 })}</div>`);
    grain(cta, 0.1);
    P.chips.forEach(([l, v, tone], i) => A(F, cx + i * ((G.ctaW - 12) / 2 + 12), G.chipY, (G.ctaW - 12) / 2, G.chipH, `display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:rgba(255,255,255,.03);${hair(0.11)}`,
      caps(l, { track: 0.12 }) + num(v, { size: 16, color: tone === 'good' ? '#8ff0ad' : '#fff' })));
    // collapsed owned tiers
    A(F, G.pad, G.sumY, w - 2 * G.pad, G.sumH, `display:flex;align-items:center;gap:14px;padding:0 18px;background:rgba(255,255,255,.025);${hair(0.09)}`,
      `${K.icon('check', 18, GOOD, { sw: 2.4 })}${caps(P.summary.label, { size: 13, color: '#fff', weight: 800 })}${num(P.summary.count, { size: 15, color: GOOD })}<span style="width:1px;height:18px;background:${line}"></span>
       <span style="flex:1;font:600 14px Montserrat;color:${soft};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${E(P.summary.names)}</span><span class="row" style="gap:4px">${caps('Show', { color: HUE_HI, weight: 800 })}${K.icon('chevD', 16, HUE_HI, { sw: 2.2 })}</span>`);
    const tier = (y, t) => A(F, G.pad, y - 4, w - 2 * G.pad, 16, 'display:flex;align-items:center;gap:12px', `${caps(t.label, { size: 13, color: '#fff', weight: 800 })}${seg(t.n[1], t.n[0], { w: 10, h: 3, gap: 3, on: GOOD, off: 'rgba(255,255,255,.2)' })}${caps(t.count)}<span style="flex:1;height:1px;background:linear-gradient(90deg,${lineHi},${line})"></span><span style="width:5px;height:5px;background:${HUE}"></span>`);
    tier(G.t3Y, P.tier3); tier(G.t4Y, P.tier4);
    P.cards.forEach((c, i) => S.card(F, G.cx(i), G.cardY, G.cw, G.cardH, c, i));
    P.locked.forEach((c, i) => S.card(F, G.cx(i), G.lockY, G.cw, G.lockH, c, i));
    A(F, w - 16, G.cardY, 2, G.lockY + G.lockH - G.cardY, 'background:rgba(255,255,255,.08)'); A(F, w - 16, G.cardY, 2, 280, `background:${HUE}`);
    return F;
  };
  S.card = (F, x, y, w, h, c, i) => {
    const pad = 18, st = c.st;
    if (st === 'buy') {
      A(F, x, y, w, h, `background:linear-gradient(180deg,${K.rgba(HUE, 0.16)},${K.rgba(HUE, 0.04)} 46%,rgba(255,255,255,.02));box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.5)}`);
      A(F, x, y, w, 2, `background:${HUE};box-shadow:0 0 12px ${K.rgba(HUE, 0.8)}`);
      ticks(F, x, y, w, h, { len: 9, th: 2, color: HUE_HI });
    } else if (st === 'owned') {
      A(F, x, y, w, h, `background:linear-gradient(180deg,rgba(75,224,122,.07),rgba(75,224,122,.02));box-shadow:inset 0 0 0 1px rgba(75,224,122,.28),inset 0 1px 0 rgba(160,255,190,.22)`);
      ticks(F, x, y, w, h, { len: 9, th: 2, color: 'rgba(127,230,160,.5)' });
    } else {
      A(F, x, y, w, h, `background:repeating-linear-gradient(135deg,rgba(255,255,255,.028) 0 1px,transparent 1px 8px),rgba(0,0,0,.3);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)`);
    }
    const tag = st === 'buy' ? `<span style="padding:4px 7px;box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.7)}">${caps('Buy', { color: HUE_HI, weight: 800 })}</span>`
      : st === 'owned' ? `<span class="row" style="gap:5px">${K.icon('check', 14, GOOD, { sw: 2.6 })}${caps('Owned', { color: GOOD, weight: 800 })}</span>`
        : `<span class="row" style="gap:5px">${K.icon('lock', 14, '#b9aec3', { sw: 2 })}${caps('Locked', { color: '#b9aec3', weight: 800 })}</span>`;
    const idxC = st === 'buy' ? HUE : st === 'owned' ? 'rgba(127,230,160,.8)' : '#737b8b';
    A(F, x + pad, y + 16, w - 2 * pad, 26, 'display:flex;align-items:center;gap:10px', `<span style="font:800 26px/1 Sarpanch;color:${idxC}">${c.n}</span>${micro(`0${i + 1}/04`, '#6d7686')}<span style="flex:1"></span>${tag}`);
    if (st === 'locked') {
      A(F, x + pad, y + 52, w - 2 * pad, h - 52 - 16, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { size: 17, color: '#c9bfd0' }) + body(c.req, { size: 14, color: '#aea6b9', lh: 1.3 }) +
        (c.prog ? `<div class="row" style="gap:10px;margin-top:auto"><div style="flex:1;height:2px;background:rgba(255,255,255,.12)"><div style="width:${pct(c)}%;height:100%;background:#b9aec3"></div></div>${num(String(c.prog[0]), { size: 13, color: '#cfc6d8' })}</div>` : ''));
      return;
    }
    A(F, x + pad, y + 52, w - 2 * pad, null, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { color: st === 'owned' ? GOOD_T : '#fff' }) + body(c.desc, { color: st === 'owned' ? '#bfc8d6' : '#d3d9e4' }));
    if (c.cur) A(F, x + pad, y + h - 16 - 42 - 52, w - 2 * pad, 44, 'display:flex;flex-direction:column;justify-content:center;gap:6px;padding:0 12px;background:rgba(0,0,0,.35);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)', caps('Currently', { track: 0.12 }) + num(c.cur, { size: 16 }));
    if (st === 'buy') {
      A(F, x + pad, y + h - 16 - 42, w - 2 * pad, 42, `display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:linear-gradient(180deg,${K.lift(HUE, 0.25)},${HUE});box-shadow:inset 0 1px 0 rgba(255,255,255,.65)`,
        `<span style="font:italic 900 16px/1 Montserrat;color:${ink}">BUY</span>${num(c.cost, { size: 16, color: ink, unit: 'color:rgba(6,16,27,.8)' })}`);
    } else {
      A(F, x + pad, y + h - 16 - 30, w - 2 * pad, 1, 'background:rgba(127,230,160,.22)');
      A(F, x + pad, y + h - 16 - 18, w - 2 * pad, 18, 'display:flex;align-items:center;gap:7px', `${K.icon('check', 15, GOOD, { sw: 2.6 })}<span style="font:700 14px/1 Montserrat;color:#a5efbc">Active</span>`);
    }
  };
  // ---------------------------------------------------------------------------- HUD
  const plate = (R, x, y, w, h, extra = '') => { const e = A(R, x, y, w, h, `background:linear-gradient(180deg,rgba(10,14,22,.84),rgba(6,9,15,.88));${hair(0.12)};${extra}`); grain(e, 0.06); ticks(R, x, y, w, h, { len: 10, th: 2, color: 'rgba(255,255,255,.8)', out: 1 }); return e; };
  S.points = (R, x, y, H) => {
    const w = 580, h = 78; plate(R, x, y, w, h);
    A(R, x + 24, y - 1, 64, 3, `background:${K.GOLD};box-shadow:0 0 8px ${K.rgba(K.GOLD, 0.6)}`);
    A(R, x + 16, y + 15, 48, 48, 'display:grid;place-items:center', `<div style="position:absolute;inset:9px;transform:rotate(45deg);box-shadow:inset 0 0 0 1.5px ${K.GOLD}"></div><div style="width:8px;height:8px;transform:rotate(45deg);background:${K.GOLD};box-shadow:0 0 8px ${K.GOLD}"></div>`);
    A(R, x + 78, y + 15, 290, null, 'display:flex;flex-direction:column;gap:8px', caps(H.cap) + `<span class="row" style="gap:10px;align-items:baseline"><span style="font:800 34px/1 Sarpanch;color:#fff">${H.amt}</span><span style="font:700 15px Montserrat;color:${soft}">${H.unit}</span></span>`);
    A(R, x + 382, y + 14, 1, h - 28, `background:${line}`);
    A(R, x + 398, y + 14, 164, null, 'display:flex;flex-direction:column;gap:6px', `${sparkline(164, 26, '#8ff0ad', { seed: 3, rise: 0.55, jitter: 0.3, fill: 0.18 })}<span class="row" style="gap:6px">${K.icon('up', 13, '#8ff0ad', { sw: 2.4 })}${num(H.rateShort, { size: 14, color: '#8ff0ad', weight: 700 })}${caps(H.rateUnit, { color: '#8ff0ad', track: 0.06 })}</span>`);
  };
  S.dock = (R, x, y, H) => H.forEach(([ic, label, badge], i) => {
    const bx = x + i * 84; plate(R, bx, y, 60, 60, i === 0 ? `box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.6)},inset 0 -2px 0 ${HUE}` : '');
    A(R, bx, y, 60, 60, 'display:grid;place-items:center', K.icon(ic, 26, '#fff', { sw: 1.7 }));
    A(R, bx + 6, y + 6, null, null, '', micro('0' + (i + 1), i === 0 ? HUE : '#6d7686'));
    if (badge) A(R, bx + 32, y - 9, null, 18, `padding:0 6px;display:grid;place-items:center;background:${K.GOLD};font:800 13px/18px Sarpanch;color:${ink}`, badge);
    A(R, bx - 12, y + 70, 84, null, 'text-align:center', caps(label, { color: '#e6ebf2', weight: 800, track: 0.08 }));
  });
  S.tray = (R, x, y, w, T) => {
    const h = 102; plate(R, x, y, w, h);
    A(R, x + 18, y + 14, w - 36, 16, 'display:flex;align-items:center;gap:8px', `${K.icon('bolt', 15, K.GOLD)}${caps(T.title, { size: 13, color: '#ffe08a', weight: 800 })}<span style="color:${soft};font:600 13px Montserrat">· ${E(T.sub)}</span><span style="flex:1;height:1px;background:${line};margin-left:6px"></span>`);
    const n = T.items.length, cw = (w - 36) / n;
    T.items.forEach(([key, L, chip, st], i) => {
      const cx = x + 18 + cw * i + cw / 2;
      if (i === 3) A(R, x + 18 + cw * i, y + 44, 1, 44, `background:${line}`);
      gemImg(R, key, cx, y + 58, 38);
      A(R, cx - 40, y + 82, 80, 14, 'display:flex;justify-content:center', st === 'ready' ? num(chip, { size: 13, color: '#ffe08a' }) : caps(chip, { color: HUE_HI, weight: 800 }));
    });
  };
  S.toast = (R, x, y, w, T) => {
    plate(R, x, y, w, 72); A(R, x, y, 3, 72, `background:${K.GOLD}`);
    A(R, x + 22, y, w - 40, 70, 'display:flex;align-items:center;gap:16px', `${K.icon('spark', 26, K.GOLD)}<div style="display:flex;flex-direction:column;gap:7px;flex:1"><span class="row" style="gap:10px"><span style="font:italic 800 18px/1 Montserrat;color:#fff">${E(T.title)}</span><span style="padding:2px 6px;box-shadow:inset 0 0 0 1px ${K.GOLD};font:800 13px/1.1 Sarpanch;color:#ffe08a">${T.chip}</span></span><span style="font:600 14px/1 Montserrat;color:${soft}">${E(T.sub)}</span></div>${micro('4.2 s')}`);
    A(R, x + 3, y + 70, (w - 3) * 0.62, 2, `background:${K.rgba(K.GOLD, 0.8)}`);
  };
  S.zoom = (R, x, y) => {
    plate(R, x, y, 150, 44);
    A(R, x, y, 150, 44, 'display:flex;align-items:center;justify-content:space-between;padding:0 14px', K.icon('minus', 18, '#fff', { sw: 2 }) + num('51%', { size: 16 }) + K.icon('plus', 18, '#fff', { sw: 2 }));
    A(R, x + 44, y + 37, 62, 3, `background:repeating-linear-gradient(90deg,rgba(255,255,255,.3) 0 1px,transparent 1px 6px)`); A(R, x + 44, y + 35, 32, 1, `background:${HUE}`);
  };
  S.hudStrip = (R, H) => { S.points(R, 146, 12, H.points); S.dock(R, 22, 944, H.dock); S.tray(R, 278, 948, 462, H.tray); };
  S.hudHome = (R, H) => { S.points(R, 670, 12, H.points); S.toast(R, 1480, 76, 416, H.toast); S.dock(R, 24, 944, H.dock); S.zoom(R, 290, 976); S.tray(R, 1060, 948, 560, H.tray); };
  S.nodeLabel = (R, n, x, y, k = 1) => {
    if (!n.name) return;
    const hue = K.HUES[n.key], locked = n.st === 'locked';
    A(R, x - 100, y, 200, null, 'display:flex;justify-content:center', `<div style="display:flex;flex-direction:column;align-items:center;gap:${4 * k}px;padding:${5 * k}px ${10 * k}px ${6 * k}px;background:rgba(6,9,15,.8);box-shadow:inset 0 0 0 1px rgba(255,255,255,.1),inset 0 1px 0 rgba(255,255,255,.16)">
      ${caps(n.name, { size: 12 * k, color: locked ? '#c9c3d6' : '#fff', weight: 800, track: 0.12 })}
      <span class="row" style="gap:4px;font:700 ${14 * k}px/1 Sarpanch;color:${locked ? '#c9c3d6' : K.lift(hue, 0.45)}">${locked ? K.icon('lock', 12 * k, '#c9c3d6', { sw: 2.2 }) : ''}${K.nf(n.value)}</span></div>`);
  };
  STYLES[1] = S;
})();

// =============================================================================================== 2 SHARP
(() => {
  const S = {}, soft = '#a9b3c1', ink = '#071019', base = '#0c1117', s1 = '#141b23', s2 = '#1a222c', s3 = '#242d39', line = '#29333f';
  const GOOD = '#4be07a', GOOD_T = '#d7f7e1';
  S.backdrop = { blur: 9, dim: 0.42 };
  // clip-path cuts: tl/br corners (panel, buttons), tr only (cards), parallelograms (tabs, tags)
  const cut = (c, tr = false) => tr ? `clip-path:polygon(0 0,calc(100% - ${c}px) 0,100% ${c}px,100% 100%,0 100%)` : `clip-path:polygon(${c}px 0,100% 0,100% calc(100% - ${c}px),calc(100% - ${c}px) 100%,0 100%,0 ${c}px)`;
  const para = s => `clip-path:polygon(${s}px 0,100% 0,calc(100% - ${s}px) 100%,0 100%)`;
  const lit = c => `background:linear-gradient(180deg,${K.lift(c, 0.05)},${c});box-shadow:inset 0 1px 0 rgba(255,255,255,.13)`;
  const caps = (t, o = {}) => K.caps(t, Object.assign({ size: 12, color: soft, track: 0.1, weight: 800 }, o));
  const heavy = (t, size, color = '#fff', o = '') => `<span style="font:italic 900 ${size}px/1 Montserrat;text-transform:uppercase;color:${color};white-space:nowrap;${o}">${E(t)}</span>`;
  const tag = (t, bg, fg, icon = '') => `<span class="row" style="gap:5px;height:22px;padding:0 12px;background:${bg};${para(6)}">${icon}${heavy(t, 12, fg, 'letter-spacing:.04em')}</span>`;
  const chev = (n, color, { w = 10, h = 30, gap = 5 } = {}) => `<span style="display:inline-flex;gap:${gap}px">${Array.from({ length: n }, (_, i) => `<i style="display:block;width:${w}px;height:${h}px;background:${color};opacity:${(0.35 + 0.65 * (i + 1) / n).toFixed(2)};clip-path:polygon(0 0,40% 0,100% 50%,40% 100%,0 100%,60% 50%)"></i>`).join('')}</span>`;
  const posBox = (n, bg, fg, size = 26) => `<span style="display:grid;place-items:center;min-width:${size + 16}px;height:${size + 4}px;padding:0 6px;background:${bg};font:900 ${size - 4}px/1 Sarpanch;color:${fg}">${n}</span>`;
  const slabSeg = (n, k, on, o = {}) => seg(n, k, Object.assign({ w: 6, h: 14, gap: 3, on, off: '#2a3340', skew: -18 }, o));

  S.panel = (R, P, { x, y, w, h }) => {
    A(R, x + 10, y + 10, w, h, `background:rgba(0,0,0,.45);${cut(30)}`);
    const F = A(R, x, y, w, h, `background:linear-gradient(180deg,#10161d,${base} 30%);${cut(30)}`);
    grain(F, 0.07);
    A(F, 0, 0, w, 1, 'background:rgba(255,255,255,.14)');
    A(F, 0, 0, 6, h, `background:${HUE}`);
    // header: solid hue emblem, heavy title, flat tags, layer position box, close
    A(F, 40, 30, 66, 66, `display:grid;place-items:center;${lit(HUE)};${cut(14, true)}`, `<span style="font:900 40px/1 Sarpanch;color:${ink}">${P.sym}</span>`);
    A(F, 124, 24, null, null, '', heavy(P.title, 54, '#fff', 'letter-spacing:-.01em'));
    A(F, 126, 82, null, 22, 'display:flex;align-items:center;gap:12px', tag(P.row, s3, '#fff') + `<span style="font:600 14px Montserrat;color:${soft}">${E(P.sub)}</span>`);
    A(F, w - 40 - 44 - 130, 32, 118, 44, 'display:flex;align-items:center;justify-content:flex-end;gap:10px', caps('Layer') + `<span style="display:flex;align-items:stretch;height:30px">${posBox(P.layer[0], '#fff', ink, 24)}<span style="display:grid;place-items:center;padding:0 7px;background:${s3};font:800 14px/1 Sarpanch;color:${soft}">/${P.layer[1]}</span></span>`);
    A(F, w - 40 - 44, 32, 44, 44, `display:grid;place-items:center;${lit(s2)};${cut(10)}`, K.icon('close', 20, '#fff', { sw: 2.6 }));
    // tabs: parallelograms, the active one solid hue with ink type
    const tb = A(F, G.pad, G.tabsY + 2, w - 2 * G.pad, 42, 'display:flex;align-items:stretch;gap:6px');
    for (const t of P.tabs) {
      const on = !!t.on;
      K.el(tb, 'div', `display:flex;align-items:center;gap:10px;padding:0 30px;${lit(on ? HUE : s2)};${para(12)}`,
        heavy(t.label, 16, on ? ink : '#e8edf3', `font-style:${on ? 'italic' : 'normal'};font-weight:${on ? 900 : 800};letter-spacing:.04em`) +
        (t.badge ? `<span style="display:grid;place-items:center;min-width:20px;height:20px;padding:0 5px;background:${on ? ink : s3};font:800 13px/1 Sarpanch;color:${on ? HUE : '#fff'}">${t.badge}</span>` : '') +
        (t.dot ? `<span style="width:8px;height:8px;background:${K.GOLD}"></span>` : ''));
    }
    K.el(tb, 'div', 'flex:1');
    K.el(tb, 'div', 'display:flex;align-items:center;gap:12px', tag(`${P.ready} Ready`, K.GOLD, ink, K.icon('bolt', 13, ink)) + slabSeg(P.ownedN[1], P.ownedN[0], GOOD, { w: 4, h: 14, gap: 2 }) + `<span style="font:900 15px/1 Sarpanch;color:#fff">${P.owned}</span>`);
    A(F, G.pad, G.tabsY + 52, w - 2 * G.pad, 2, `background:${line}`);
    // hero + a PP/min histogram
    A(F, G.pad, G.heroY + 4, 6, 118, `background:${HUE}`);
    A(F, G.pad + 24, G.heroY + 2, null, null, 'display:flex;flex-direction:column;gap:10px', caps(P.hero.cap, { size: 13 }) +
      `<span style="font:900 64px/1 Sarpanch;color:#fff">${E(P.hero.amt)}</span>` + heavy(P.hero.res, 22, HUE));
    A(F, 440, G.heroY + 6, 128, null, 'display:flex;flex-direction:column;gap:8px', `<span class="row" style="justify-content:space-between">${caps('PP / min')}<span style="font:900 13px/1 Sarpanch;color:${GOOD}">▲ 4.1%</span></span>${bars(128, 46, HUE, { seed: 9 })}<span style="height:2px;background:${line}"></span>`);
    // CTA: a solid hue slab, flat offset block for depth (no glow), chevrons for direction
    const cx = w - G.pad - G.ctaW, cy = G.heroY;
    A(F, cx + 8, cy + 8, G.ctaW, G.ctaH, `background:${K.sink(HUE, 0.62)};${cut(18)}`);
    const cta = A(F, cx, cy, G.ctaW, G.ctaH, `background:linear-gradient(180deg,${K.lift(HUE, 0.12)},${HUE} 55%);box-shadow:inset 0 1px 0 rgba(255,255,255,.55);${cut(18)}`,
      `<div style="position:absolute;left:30px;top:20px;display:flex;flex-direction:column;gap:10px">${heavy(P.cta.title, 36, ink)}<span style="font:800 18px/1 Sarpanch;color:rgba(7,16,25,.82)">${K.nf(P.cta.gain)}</span></div>
       <div style="position:absolute;right:24px;top:50%;transform:translateY(-50%);display:flex;align-items:center;gap:16px">${chev(3, ink, { w: 11, h: 26, gap: 3 })}<span style="display:grid;place-items:center;width:40px;height:40px;background:${ink}"><span style="font:900 18px Montserrat;color:${HUE}">${P.cta.key}</span></span></div>`);
    grain(cta, 0.1);
    P.chips.forEach(([l, v, tone], i) => A(F, cx + i * ((G.ctaW - 10) / 2 + 10), G.chipY + 6, (G.ctaW - 10) / 2, G.chipH, `display:flex;align-items:center;justify-content:space-between;padding:0 14px 0 16px;${lit(s1)},inset 3px 0 0 ${tone === 'good' ? GOOD : HUE}`,
      caps(l) + `<span style="font:800 16px/1 Sarpanch;color:${tone === 'good' ? '#8ff0ad' : '#fff'}">${K.nf(v)}</span>`));
    // collapsed owned tiers
    A(F, G.pad, G.sumY + 2, w - 2 * G.pad, G.sumH - 2, `display:flex;align-items:center;gap:14px;padding:0 18px;${lit('#111b16')},inset 4px 0 0 ${GOOD}`,
      `${K.icon('check', 18, GOOD, { sw: 3 })}${heavy(P.summary.label, 15, '#fff')}${slabSeg(8, 8, GOOD, { w: 4, h: 12, gap: 2 })}<span style="font:800 15px Sarpanch;color:${GOOD}">${P.summary.count}</span>
       <span style="flex:1;font:600 14px Montserrat;color:${soft};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${E(P.summary.names)}</span>${tag('Show', HUE, ink)}`);
    const tier = (y, t) => A(F, G.pad, y - 7, w - 2 * G.pad, 22, 'display:flex;align-items:center;gap:12px', `${heavy(t.label, 20, '#fff')}${slabSeg(t.n[1], t.n[0], GOOD, { w: 8, h: 14 })}${caps(t.count, { size: 12 })}<span style="flex:1;height:2px;background:${line}"></span>${chev(3, HUE, { w: 7, h: 12, gap: 1 })}`);
    tier(G.t3Y, P.tier3); tier(G.t4Y, P.tier4);
    P.cards.forEach((c, i) => S.card(F, G.cx(i), G.cardY, G.cw, G.cardH, c));
    P.locked.forEach((c, i) => S.card(F, G.cx(i), G.lockY, G.cw, G.lockH, c));
    A(F, w - 18, G.cardY, 4, G.lockY + G.lockH - G.cardY, `background:${s2}`); A(F, w - 18, G.cardY, 4, 300, `background:${HUE}`);
    return F;
  };
  S.card = (F, x, y, w, h, c) => {
    const pad = 18, st = c.st;
    const C = A(F, x, y, w, h, st === 'locked' ? `background:repeating-linear-gradient(-45deg,#131820 0 10px,#0f1318 10px 20px);box-shadow:inset 0 1px 0 rgba(255,255,255,.06);${cut(18, true)}`
      : `${lit(st === 'buy' ? '#151d27' : '#121c17')};${cut(18, true)}`);
    grain(C, 0.08);
    A(C, 0, 0, w, 4, `background:${st === 'buy' ? HUE : st === 'owned' ? GOOD : '#3a404c'}`);
    const tg = st === 'buy' ? tag('Buy', HUE, ink) : st === 'owned' ? tag('Owned', GOOD, ink, K.icon('check', 12, ink, { sw: 3.4 })) : tag('Locked', '#2c313c', '#e2dbe8', K.icon('lock', 12, '#e2dbe8', { sw: 2.6 }));
    const box = st === 'buy' ? posBox(c.n, '#fff', ink, 24) : st === 'owned' ? posBox(c.n, GOOD, ink, 24) : posBox(c.n, '#262b35', '#9aa0ad', 24);
    A(C, pad, 16, w - 2 * pad, 30, 'display:flex;align-items:center;justify-content:space-between', box + tg);
    if (st === 'locked') {
      A(C, pad, 60, w - 2 * pad, h - 60 - 16, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { size: 17, color: '#c9bfd0' }) + body(c.req, { size: 14, color: '#b0a8bb', lh: 1.3 }) +
        (c.prog ? `<div class="row" style="gap:10px;margin-top:auto">${slabSeg(12, Math.round(12 * c.prog[0] / c.prog[1]), '#b9aec3', { w: 7, h: 8, gap: 3, off: '#262b35' })}<span style="flex:1"></span><span style="font:800 13px/1 Sarpanch;color:#cfc6d8">${c.prog[0]}</span></div>` : ''));
      return;
    }
    A(C, pad, 58, w - 2 * pad, null, 'display:flex;flex-direction:column;gap:7px', cardTitle(c.title, { color: st === 'owned' ? GOOD_T : '#fff' }) + body(c.desc, { color: st === 'owned' ? '#bcc6d2' : '#d0d7e1' }));
    if (c.cur) A(C, pad, h - 16 - 42 - 50, w - 2 * pad, 42, `display:flex;flex-direction:column;justify-content:center;gap:6px;padding:0 12px;background:${base};box-shadow:inset 3px 0 0 ${HUE}`, caps('Currently') + `<span style="font:800 16px/1 Sarpanch;color:#fff">${K.nf(c.cur)}</span>`);
    if (st === 'buy') {
      A(C, pad, h - 16 - 42, w - 2 * pad, 42, `display:flex;align-items:center;gap:10px;padding:0 14px;background:linear-gradient(180deg,${K.lift(HUE, 0.12)},${HUE} 60%);box-shadow:inset 0 1px 0 rgba(255,255,255,.5);${cut(10)}`,
        `${heavy('Buy', 17, ink)}<span style="flex:1"></span><span class="nowrap" style="font:900 16px/1 Sarpanch;color:${ink}">${K.nf(c.cost)}</span>`);
    } else {
      A(C, pad, h - 16 - 42, w - 2 * pad, 42, `display:flex;align-items:center;gap:8px;padding:0 14px;background:#0d1511;box-shadow:inset 0 0 0 1px #1d3326`, `${K.icon('check', 16, GOOD, { sw: 3 })}${heavy('Active', 14, GOOD, 'letter-spacing:.04em')}`);
    }
  };
  // ---------------------------------------------------------------------------- HUD
  const slab = (R, x, y, w, h, c = 12) => { A(R, x + 6, y + 6, w, h, `background:rgba(0,0,0,.42);${cut(c)}`); const e = A(R, x, y, w, h, `background:linear-gradient(180deg,rgba(20,27,35,.97),rgba(12,17,23,.97));box-shadow:inset 0 1px 0 rgba(255,255,255,.13);${cut(c)}`); grain(e, 0.07); return e; };
  S.points = (R, x, y, H) => {
    const w = 600, h = 76; slab(R, x, y, w, h, 14);
    A(R, x, y, 76, h, `display:grid;place-items:center;${lit(K.GOLD)};clip-path:polygon(14px 0,100% 0,calc(100% - 14px) 100%,0 100%,0 14px)`, K.icon('star', 30, ink));
    A(R, x + 90, y + 14, 300, null, 'display:flex;flex-direction:column;gap:8px', caps(H.cap) + `<span class="row" style="gap:10px;align-items:baseline"><span style="font:900 34px/1 Sarpanch;color:#fff">${H.amt}</span><span style="font:700 15px Montserrat;color:${soft}">${H.unit}</span></span>`);
    A(R, x + 404, y + 12, 2, h - 24, `background:${line}`);
    A(R, x + 420, y + 12, 164, null, 'display:flex;flex-direction:column;gap:6px', bars(164, 30, '#8ff0ad', { seed: 4, n: 18 }) + `<span class="row" style="gap:6px"><span style="font:900 13px/1 Sarpanch;color:#8ff0ad">▲</span><span style="font:800 14px/1 Sarpanch;color:#8ff0ad">${H.rateShort}</span>${caps(H.rateUnit, { color: '#8ff0ad', track: 0.04 })}</span>`);
  };
  S.dock = (R, x, y, H) => H.forEach(([ic, label, badge], i) => {
    const bx = x + i * 82, on = i === 0;
    A(R, bx + 5, y + 5, 62, 62, `background:rgba(0,0,0,.42);${cut(12)}`);
    A(R, bx, y, 62, 62, `display:grid;place-items:center;${on ? lit(HUE) : 'background:linear-gradient(180deg,rgba(20,27,35,.97),rgba(12,17,23,.97));box-shadow:inset 0 1px 0 rgba(255,255,255,.13)'};${cut(12)}`, K.icon(ic, 28, on ? ink : '#fff', { sw: 2.3 }));
    if (badge) A(R, bx + 30, y - 10, null, 20, `padding:0 8px;display:grid;place-items:center;background:${K.GOLD};font:900 13px/20px Sarpanch;color:${ink};${para(5)}`, badge);
    A(R, bx - 12, y + 70, 86, null, 'text-align:center', heavy(label, 13, '#fff', 'letter-spacing:.03em;text-shadow:0 2px 0 rgba(0,0,0,.6)'));
  });
  S.tray = (R, x, y, w, T) => {
    const h = 102; slab(R, x, y, w, h, 14);
    A(R, x, y, w, 30, `display:flex;align-items:center;gap:10px;padding:0 16px 0 0;background:${s2};clip-path:polygon(14px 0,100% 0,100% 100%,0 100%,0 14px)`,
      `<span class="row" style="gap:6px;height:30px;padding:0 18px 0 14px;${lit(K.GOLD)};${para(0)};clip-path:polygon(0 0,100% 0,calc(100% - 10px) 100%,0 100%)">${K.icon('bolt', 14, ink)}${heavy(T.title, 14, ink)}</span><span style="font:700 13px Montserrat;color:${soft}">${E(T.sub)}</span><span style="flex:1"></span>${slabSeg(6, 3, K.GOLD, { w: 5, h: 10, gap: 2 })}`);
    const n = T.items.length, cw = (w - 24) / n;
    T.items.forEach(([key, L, chip, st], i) => {
      const cx = x + 12 + cw * i + cw / 2;
      gemImg(R, key, cx, y + 58, 38);
      A(R, cx - 40, y + 82, 80, 14, 'display:flex;justify-content:center', st === 'ready' ? `<span style="font:900 13px/1 Sarpanch;color:#ffe08a">${K.nf(chip)}</span>` : heavy(chip, 12, HUE, 'letter-spacing:.04em'));
    });
  };
  S.toast = (R, x, y, w, T) => {
    slab(R, x, y, w, 72, 12);
    A(R, x, y, 64, 72, `display:grid;place-items:center;${lit(K.GOLD)};clip-path:polygon(12px 0,100% 0,calc(100% - 12px) 100%,0 100%,0 12px)`, K.icon('spark', 28, ink));
    A(R, x + 76, y, w - 90, 72, 'display:flex;flex-direction:column;justify-content:center;gap:8px', `<span class="row" style="gap:10px">${heavy(T.title, 18, '#fff')}<span style="padding:3px 7px;background:${K.GOLD};font:900 13px/1 Sarpanch;color:${ink}">${T.chip}</span></span><span style="font:600 14px/1 Montserrat;color:${soft}">${E(T.sub)}</span>`);
    A(R, x + 64, y + 68, (w - 76) * 0.62, 4, `background:${K.GOLD}`);
  };
  S.zoom = (R, x, y) => { slab(R, x, y, 150, 44, 10); A(R, x, y, 150, 44, 'display:flex;align-items:center;justify-content:space-between;padding:0 14px', K.icon('minus', 18, '#fff', { sw: 3 }) + `<span style="font:900 16px Sarpanch;color:#fff">51%</span>` + K.icon('plus', 18, '#fff', { sw: 3 })); };
  S.hudStrip = (R, H) => { S.points(R, 134, 12, H.points); S.dock(R, 22, 944, H.dock); S.tray(R, 276, 950, 462, H.tray); };
  S.hudHome = (R, H) => { S.points(R, 660, 12, H.points); S.toast(R, 1480, 110, 416, H.toast); S.dock(R, 24, 944, H.dock); S.zoom(R, 290, 976); S.tray(R, 1060, 950, 560, H.tray); };
  S.nodeLabel = (R, n, x, y, k = 1) => {
    if (!n.name) return;
    const hue = K.HUES[n.key], locked = n.st === 'locked';
    A(R, x - 100, y, 200, null, 'display:flex;justify-content:center', `<div style="display:flex;flex-direction:column;align-items:center;gap:${4 * k}px;padding:${6 * k}px ${12 * k}px ${6 * k}px;background:linear-gradient(180deg,rgba(20,27,35,.96),rgba(12,17,23,.96));box-shadow:inset 0 3px 0 ${locked ? '#3a404c' : hue};${cut(7)}">
      ${heavy(n.name, 12 * k, locked ? '#c9c3d6' : '#fff', 'letter-spacing:.04em')}
      <span class="row" style="gap:4px;font:800 ${14 * k}px/1 Sarpanch;color:${locked ? '#c9c3d6' : K.lift(hue, 0.35)}">${locked ? K.icon('lock', 12 * k, '#c9c3d6', { sw: 2.6 }) : ''}${K.nf(n.value)}</span></div>`);
  };
  STYLES[2] = S;
})();

// =============================================================================================== 3 SOFT PREMIUM
(() => {
  const S = {}, text = '#f5f3ef', soft = '#bdc0cf', ink = '#08121e', line = 'rgba(255,255,255,.1)';
  const GOOD = '#6fe3a0', GOOD_T = '#d7f7e1';
  S.backdrop = { blur: 9, dim: 0.42 };
  const caps = (t, o = {}) => K.caps(t, Object.assign({ size: 12, color: soft, track: 0.2, weight: 700 }, o));
  const microN = (t, color = '#8d91a6') => `<span style="font:700 13px/1 Sarpanch;color:${color}">${t}</span>`;
  const surf = (a = 0.07, b = 0.022) => `background:linear-gradient(180deg,rgba(255,255,255,${a}),rgba(255,255,255,${b}) 70%);box-shadow:inset 0 1px 0 rgba(255,255,255,.14),inset 0 0 0 1px rgba(255,255,255,.055)`;
  const dia = (s, c, fill = true) => `<i style="display:inline-block;width:${s}px;height:${s}px;transform:rotate(45deg);${fill ? `background:${c}` : `box-shadow:inset 0 0 0 1px ${c}`};flex:none"></i>`;
  // a fine rule that fades out at both ends, with a diamond terminal
  const rule = (parent, x, y, w, { c = 'rgba(255,255,255,.22)', d = 'left', dc = HUE } = {}) => {
    A(parent, x, y, w, 1, `background:linear-gradient(90deg,${d === 'left' ? c : 'transparent'},${c} 30%,${c} 70%,transparent)`);
    A(parent, d === 'left' ? x - 3 : x + w / 2 - 3, y - 3, 7, 7, `transform:rotate(45deg);background:${dc}`);
  };
  // primary buttons are pearl (Star Rail's light primary): ivory gradient, a fine inner line, ink type, hue diamonds
  const PINK = '#151a2a', PSUB = K.sink(HUE, 0.5);
  const pearl = (r, glow = 0.22) => `border-radius:${r}px;background:linear-gradient(180deg,#fdfcf8 0%,#efebe2 52%,#dcd5c7 100%);box-shadow:inset 0 1px 0 #fff,inset 0 -1px 0 rgba(0,0,0,.12),0 0 0 1px ${K.rgba(HUE, 0.35)},0 8px 22px ${K.rgba(HUE, glow)}`;
  const pearlLine = (parent, r, inset = 4) => K.el(parent, 'div', `position:absolute;inset:${inset}px;border-radius:${r - inset}px;box-shadow:inset 0 0 0 1px rgba(21,26,42,.16);pointer-events:none`);
  const gradText = (t, size, a = '#ffffff', b = HUE_HI, o = '') => `<span style="font:italic 900 ${size}px/1.05 Montserrat;background:linear-gradient(180deg,${a} 35%,${b});-webkit-background-clip:text;background-clip:text;color:transparent;${o}">${E(t)}</span>`;

  S.panel = (R, P, { x, y, w, h }) => {
    const F = A(R, x, y, w, h, `border-radius:22px;overflow:hidden;background:linear-gradient(180deg,rgba(40,47,72,.95) 0%,rgba(22,26,43,.96) 34%,rgba(13,15,27,.97) 100%);box-shadow:inset 0 1px 0 rgba(255,255,255,.24),inset 0 0 0 1px rgba(255,255,255,.07),0 0 0 1px rgba(0,0,0,.4),0 28px 64px rgba(0,0,0,.42)`);
    A(F, 0, 0, w, h, `background:radial-gradient(ellipse 48% 30% at 10% 0%,${K.rgba(HUE, 0.2)},transparent 72%),radial-gradient(ellipse 40% 24% at 100% 100%,${K.rgba(HUE, 0.07)},transparent 70%)`);
    // orbit linework behind the emblem (a star-chart ornament)
    A(F, 0, 0, w, 420, '', `<svg width="${w}" height="420" style="position:absolute;inset:0"><g fill="none" stroke="rgba(255,255,255,.07)"><circle cx="72" cy="62" r="92"/><circle cx="72" cy="62" r="160" stroke-dasharray="2 5"/><circle cx="72" cy="62" r="250"/></g>
      <circle cx="${72 + 160 * Math.cos(0.5)}" cy="${62 + 160 * Math.sin(0.5)}" r="3" fill="${HUE}" opacity=".8"/><circle cx="${72 + 250 * Math.cos(0.22)}" cy="${62 + 250 * Math.sin(0.22)}" r="2.2" fill="#fff" opacity=".5"/>
      <g stroke="rgba(255,255,255,.06)"><line x1="${w - 330}" y1="26" x2="${w - 170}" y2="26"/><line x1="${w - 330}" y1="22" x2="${w - 330}" y2="30"/></g></svg>`);
    grain(F, 0.06);
    A(F, 40, 0, 320, 1, `background:linear-gradient(90deg,${HUE},transparent)`);
    // emblem: a hue medallion inside a completion ring (owned upgrades)
    A(F, 32, 22, 80, 80, '', ring(80, P.ownedN[0] / P.ownedN[1], HUE_HI, { sw: 2, track: 'rgba(255,255,255,.12)', ticksN: 16 }));
    A(F, 44, 34, 56, 56, `display:grid;place-items:center;border-radius:50%;background:radial-gradient(circle at 50% 30%,${K.lift(HUE, 0.1)},${K.sink(HUE, 0.35)} 70%,${K.sink(HUE, 0.6)});box-shadow:inset 0 1px 0 rgba(255,255,255,.55),inset 0 0 0 1px rgba(255,255,255,.25),0 6px 16px ${K.rgba(HUE, 0.35)}`, `<span style="font:900 28px/1 Sarpanch;color:#fff;text-shadow:0 1px 2px rgba(0,0,0,.35)">${P.sym}</span>`);
    A(F, 128, 26, null, null, '', gradText(P.title, 44));
    A(F, 130, 80, null, 22, 'display:flex;align-items:center;gap:12px', `<span style="padding:4px 10px;border-radius:11px;background:${K.rgba(HUE, 0.16)};box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.42)}">${caps(P.row, { color: HUE_HI, weight: 800, track: 0.14 })}</span><span style="font:600 14px Montserrat;color:${soft}">${E(P.sub)}</span>`);
    A(F, w - 40 - 42 - 150, 36, 136, 40, 'display:flex;flex-direction:column;align-items:flex-end;justify-content:center;gap:7px', caps('Layer') + `<span class="row" style="gap:6px">${dia(5, HUE)}<span style="font:800 16px/1 Sarpanch;color:${text}">${P.layer[0]}</span><span style="font:700 14px/1 Sarpanch;color:#7f849a">/ ${P.layer[1]}</span></span>`);
    A(F, w - 40 - 42, 34, 42, 42, `display:grid;place-items:center;border-radius:50%;${surf(0.08, 0.03)}`, K.icon('close', 18, '#fff', { sw: 1.6 }));
    // tabs: a recessed capsule track, the active tab a lit hue capsule
    const tb = A(F, G.pad, G.tabsY, 560, G.tabsH, 'display:flex;align-items:stretch;gap:4px;padding:4px;border-radius:23px;background:rgba(0,0,0,.28);box-shadow:inset 0 1px 3px rgba(0,0,0,.55),inset 0 0 0 1px rgba(255,255,255,.05),0 1px 0 rgba(255,255,255,.06)');
    for (const t of P.tabs) {
      const on = !!t.on;
      K.el(tb, 'div', `flex:1;display:flex;align-items:center;justify-content:center;gap:9px;${on ? pearl(19, 0.2) : 'border-radius:19px'}`,
        `${on ? dia(5, HUE) : ''}<span style="font:${on ? 'italic ' : ''}800 15px/1 Montserrat;letter-spacing:.06em;text-transform:uppercase;color:${on ? PINK : soft}">${E(t.label)}</span>` +
        (t.badge ? `<span style="display:grid;place-items:center;width:20px;height:20px;border-radius:50%;background:${on ? HUE : 'rgba(255,255,255,.14)'};font:800 13px/1 Sarpanch;color:${on ? ink : '#fff'}">${t.badge}</span>` : '') +
        (t.dot ? dia(7, K.GOLD) : ''));
    }
    A(F, w - G.pad - 360, G.tabsY, 360, G.tabsH, 'display:flex;align-items:center;justify-content:flex-end;gap:16px',
      `<span class="row" style="gap:7px;height:30px;padding:0 13px;border-radius:15px;background:${K.rgba(K.GOLD, 0.1)};box-shadow:inset 0 0 0 1px ${K.rgba(K.GOLD, 0.35)}">${K.icon('bolt', 14, K.GOLD)}<span style="font:800 15px/1 Sarpanch;color:${K.GOLD}">${P.ready}</span>${caps('Ready', { color: '#ffe08a', weight: 800, track: 0.14 })}</span>
       <span class="row" style="gap:9px">${ring(26, P.ownedN[0] / P.ownedN[1], GOOD, { sw: 2.5 })}<span style="font:800 15px/1 Sarpanch;color:${text}">${P.owned}</span>${caps('Owned', { weight: 800, track: 0.14 })}</span>`);
    rule(F, G.pad + 3, G.tabsY + G.tabsH + 14, w - 2 * G.pad - 3, { c: 'rgba(255,255,255,.14)' });
    // hero + a gain gauge
    A(F, G.pad, G.heroY + 12, null, null, 'display:flex;flex-direction:column;gap:12px', caps(P.hero.cap, { size: 13, track: 0.26 }) +
      `<span style="font:800 60px/1 Sarpanch;background:linear-gradient(180deg,#fff 40%,${HUE_HI});-webkit-background-clip:text;background-clip:text;color:transparent;filter:drop-shadow(0 0 18px ${K.rgba(HUE, 0.35)})">${E(P.hero.amt)}</span>` +
      `<span class="row" style="gap:10px">${dia(6, HUE)}<span style="font:italic 900 20px/1 Montserrat;letter-spacing:.04em;text-transform:uppercase;color:${HUE_HI}">${E(P.hero.res)}</span></span>`);
    const gx = 440, gy = G.heroY + 8, gs = 104, arcF = 0.72;
    A(F, gx, gy, gs, gs, '', `<svg width="${gs}" height="${gs}" style="transform:rotate(135deg)"><circle cx="${gs / 2}" cy="${gs / 2}" r="${gs / 2 - 4}" fill="none" stroke="rgba(255,255,255,.1)" stroke-width="3" stroke-dasharray="${(Math.PI * (gs - 8) * 0.75).toFixed(1)} 999" stroke-linecap="round"/>
      <circle cx="${gs / 2}" cy="${gs / 2}" r="${gs / 2 - 4}" fill="none" stroke="${HUE}" stroke-width="3" stroke-dasharray="${(Math.PI * (gs - 8) * 0.75 * arcF).toFixed(1)} 999" stroke-linecap="round" style="filter:drop-shadow(0 0 4px ${HUE})"/>
      <circle cx="${gs / 2}" cy="${gs / 2}" r="${gs / 2 - 13}" fill="none" stroke="rgba(255,255,255,.07)" stroke-width="1" stroke-dasharray="1 4"/></svg>`);
    A(F, gx, gy + 30, gs, null, 'display:flex;flex-direction:column;align-items:center;gap:6px', `<span style="font:800 20px/1 Sarpanch;color:#fff">+4.1%</span>${caps('Per min', { size: 12, track: 0.14 })}`);
    // CTA: a lit capsule button with its gain line in a well
    const cx = w - G.pad - G.ctaW, cy = G.heroY;
    const cta = A(F, cx, cy, G.ctaW, G.ctaH, `overflow:hidden;${pearl(20, 0.3)}`,
      `<div style="position:absolute;left:34px;top:21px;display:flex;flex-direction:column;align-items:flex-start;gap:10px"><span style="font:italic 900 30px/1 Montserrat;color:${PINK}">${P.cta.title}</span><span class="row" style="gap:8px">${dia(6, HUE)}<span style="font:800 17px/1 Sarpanch;color:${PSUB}">${K.nf(P.cta.gain)}</span></span></div>
       <div style="position:absolute;right:26px;top:50%;transform:translateY(-50%);display:grid;place-items:center;width:42px;height:42px;border-radius:50%;background:${PINK};box-shadow:0 0 0 3px rgba(21,26,42,.12)"><span style="font:800 16px Montserrat;color:#fff">${P.cta.key}</span></div>`);
    pearlLine(cta, 20, 5);
    A(cta, 14, G.ctaH / 2 - 3, 6, 6, `transform:rotate(45deg);background:${HUE}`);
    grain(cta, 0.05);
    P.chips.forEach(([l, v, tone], i) => A(F, cx + i * ((G.ctaW - 12) / 2 + 12), G.chipY + 4, (G.ctaW - 12) / 2, G.chipH, `display:flex;align-items:center;justify-content:space-between;padding:0 14px;border-radius:12px;${surf()}`,
      caps(l, { track: 0.14 }) + num(v, { size: 16, color: tone === 'good' ? '#8ff0ad' : text })));
    // collapsed owned tiers
    A(F, G.pad, G.sumY, w - 2 * G.pad, G.sumH, `display:flex;align-items:center;gap:14px;padding:0 10px 0 10px;border-radius:14px;${surf(0.055, 0.02)}`,
      `<span style="display:grid;place-items:center;width:24px;height:24px;border-radius:50%;background:rgba(75,224,122,.16);box-shadow:inset 0 0 0 1px rgba(75,224,122,.45)">${K.icon('check', 14, GOOD, { sw: 2.8 })}</span><span style="font:italic 800 15px/1 Montserrat;color:${text}">${E(P.summary.label)}</span>${num(P.summary.count, { size: 15, color: GOOD })}${dia(4, 'rgba(255,255,255,.3)')}
       <span style="flex:1;font:600 14px Montserrat;color:${soft};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${E(P.summary.names)}</span><span class="row" style="gap:4px;padding:0 12px;height:28px;border-radius:14px;background:rgba(255,255,255,.06)">${caps('Show', { color: HUE_HI, weight: 800, track: 0.12 })}${K.icon('chevD', 15, HUE_HI, { sw: 2.2 })}</span>`);
    const tier = (y, t) => A(F, G.pad, y - 6, w - 2 * G.pad, 20, 'display:flex;align-items:center;gap:12px', `<span style="font:italic 800 18px/1 Montserrat;color:${text}">${E(t.label)}</span><span class="row" style="gap:5px">${Array.from({ length: t.n[1] }, (_, i) => dia(6, i < t.n[0] ? GOOD : 'rgba(255,255,255,.3)', i < t.n[0])).join('')}</span>${caps(t.count, { track: 0.14 })}<span style="flex:1;height:1px;background:linear-gradient(90deg,rgba(255,255,255,.18),rgba(255,255,255,.04))"></span>${dia(5, HUE)}`);
    tier(G.t3Y, P.tier3); tier(G.t4Y, P.tier4);
    P.cards.forEach((c, i) => S.card(F, G.cx(i), G.cardY, G.cw, G.cardH, c));
    P.locked.forEach((c, i) => S.card(F, G.cx(i), G.lockY, G.cw, G.lockH, c));
    A(F, w - 17, G.cardY + 6, 4, G.lockY + G.lockH - G.cardY - 12, 'border-radius:2px;background:rgba(255,255,255,.07)'); A(F, w - 17, G.cardY + 6, 4, 280, `border-radius:2px;background:linear-gradient(${HUE_HI},${HUE});box-shadow:0 0 6px ${K.rgba(HUE, 0.7)}`);
    return F;
  };
  S.card = (F, x, y, w, h, c) => {
    const pad = 18, st = c.st;
    const C = A(F, x, y, w, h, st === 'locked' ? 'border-radius:14px;background:rgba(0,0,0,.2);box-shadow:inset 0 1px 2px rgba(0,0,0,.5),inset 0 0 0 1px rgba(255,255,255,.05),0 1px 0 rgba(255,255,255,.05)'
      : `border-radius:14px;overflow:hidden;${surf(st === 'buy' ? 0.08 : 0.06, 0.02)},0 10px 24px rgba(0,0,0,.22)`);
    if (st === 'buy') {
      A(C, 0, 0, w, h, `background:radial-gradient(ellipse 90% 55% at 50% 0%,${K.rgba(HUE, 0.26)},transparent 70%);box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.42)};border-radius:14px`);
      A(C, 20, 0, w - 40, 1, `background:linear-gradient(90deg,transparent,${HUE_HI},transparent)`);
    } else if (st === 'owned') {
      A(C, 0, 0, w, h, 'background:radial-gradient(ellipse 90% 50% at 50% 0%,rgba(75,224,122,.13),transparent 70%);box-shadow:inset 0 0 0 1px rgba(75,224,122,.26);border-radius:14px');
    }
    const tag = st === 'buy' ? `<span style="padding:4px 10px;border-radius:11px;background:${K.rgba(HUE, 0.18)};box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.5)}">${caps('Buy', { color: HUE_HI, weight: 800, track: 0.12 })}</span>`
      : st === 'owned' ? `<span class="row" style="gap:6px"><span style="display:grid;place-items:center;width:18px;height:18px;border-radius:50%;background:rgba(75,224,122,.18)">${K.icon('check', 11, GOOD, { sw: 3.2 })}</span>${caps('Owned', { color: GOOD, weight: 800, track: 0.12 })}</span>`
        : `<span class="row" style="gap:6px"><span style="display:grid;place-items:center;width:20px;height:20px;border-radius:50%;background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.12)">${K.icon('lock', 11, '#c2b8cc', { sw: 2.4 })}</span>${caps('Locked', { color: '#b9aec3', weight: 800, track: 0.12 })}</span>`;
    A(C, pad, 16, w - 2 * pad, 24, 'display:flex;align-items:center;gap:8px', `${dia(5, st === 'buy' ? HUE : st === 'owned' ? GOOD : '#6b6f80')}${microN(c.n, st === 'buy' ? HUE_HI : st === 'owned' ? '#9fe0b8' : '#8a8d9c').replace('13px', '18px')}<span style="flex:1"></span>${tag}`);
    if (st === 'locked') {
      A(C, pad, 52, w - 2 * pad, h - 52 - 16, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { size: 17, color: '#c9bfd0' }) + body(c.req, { size: 14, color: '#aea8ba', lh: 1.3 }) +
        (c.prog ? `<div class="row" style="gap:10px;margin-top:auto"><div style="position:relative;flex:1;height:4px;border-radius:2px;background:rgba(255,255,255,.08)"><div style="width:${pct(c)}%;height:100%;border-radius:2px;background:linear-gradient(90deg,rgba(185,174,195,.3),#c9bfd0)"></div><i style="position:absolute;left:calc(${pct(c)}% - 4px);top:-2px;width:8px;height:8px;transform:rotate(45deg);background:#e2d9ea"></i></div>${num(String(c.prog[0]), { size: 13, color: '#d4ccdc' })}</div>` : ''));
      return;
    }
    A(C, pad, 52, w - 2 * pad, null, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { color: st === 'owned' ? GOOD_T : text }) + body(c.desc, { color: st === 'owned' ? '#c0c4d2' : '#d6d9e4' }));
    if (c.cur) A(C, pad, h - 16 - 42 - 52, w - 2 * pad, 44, 'display:flex;flex-direction:column;justify-content:center;gap:6px;padding:0 12px;border-radius:10px;background:rgba(0,0,0,.26);box-shadow:inset 0 1px 2px rgba(0,0,0,.4)', caps('Currently', { track: 0.14 }) + num(c.cur, { size: 16, color: text }));
    if (st === 'buy') {
      const b = A(C, pad, h - 16 - 42, w - 2 * pad, 42, `display:flex;align-items:center;justify-content:space-between;padding:0 16px;${pearl(21, 0.18)}`,
        `<span class="row" style="gap:7px">${dia(5, HUE)}<span style="font:italic 900 16px/1 Montserrat;color:${PINK}">BUY</span></span>${num(c.cost, { size: 16, color: PINK, unit: 'color:rgba(21,26,42,.75)' })}`);
      pearlLine(b, 21, 3);
    } else {
      A(C, pad + 10, h - 16 - 30, w - 2 * pad - 20, 1, 'background:linear-gradient(90deg,transparent,rgba(111,227,160,.35),transparent)');
      A(C, pad, h - 16 - 18, w - 2 * pad, 18, 'display:flex;align-items:center;justify-content:center;gap:8px', `<i style="width:6px;height:6px;border-radius:50%;background:${GOOD};box-shadow:0 0 6px ${GOOD}"></i><span style="font:700 14px/1 Montserrat;color:#a5efbc">Active</span>`);
    }
  };
  // ---------------------------------------------------------------------------- HUD
  const soft9 = (R, x, y, w, h, r = 18, extra = '') => { const e = A(R, x, y, w, h, `border-radius:${r}px;background:linear-gradient(180deg,rgba(40,47,72,.9),rgba(16,19,32,.92));box-shadow:inset 0 1px 0 rgba(255,255,255,.22),inset 0 0 0 1px rgba(255,255,255,.07),0 0 0 1px rgba(0,0,0,.35),0 12px 28px rgba(0,0,0,.35);${extra}`); grain(e, 0.05); return e; };
  const coin = (s) => `<span style="display:grid;place-items:center;width:${s}px;height:${s}px;border-radius:50%;background:radial-gradient(circle at 50% 30%,#fff3c4,#ffd34d 45%,#c98a14);box-shadow:inset 0 1px 0 rgba(255,255,255,.8),0 0 0 2px rgba(255,211,77,.25),0 4px 12px rgba(255,190,40,.3)">${K.icon('star', s * 0.5, '#6a4506')}</span>`;
  S.points = (R, x, y, H) => {
    const w = 580, h = 78; soft9(R, x, y, w, h, 22);
    A(R, x + 16, y + 14, 50, 50, '', coin(50));
    A(R, x + 82, y + 15, 290, null, 'display:flex;flex-direction:column;gap:8px', caps(H.cap, { track: 0.16 }) + `<span class="row" style="gap:10px;align-items:baseline"><span style="font:800 34px/1 Sarpanch;color:#fff">${H.amt}</span><span style="font:700 15px Montserrat;color:${soft}">${H.unit}</span></span>`);
    A(R, x + 386, y + 12, 1, h - 24, 'background:linear-gradient(transparent,rgba(255,255,255,.16),transparent)');
    A(R, x + 402, y + 12, 162, null, 'display:flex;flex-direction:column;gap:6px', `${sparkline(162, 28, '#8ff0ad', { seed: 3, rise: 0.55, jitter: 0.3, fill: 0.2, sw: 1.8 })}<span class="row" style="gap:6px">${K.icon('up', 13, '#8ff0ad', { sw: 2.4 })}${num(H.rateShort, { size: 14, color: '#8ff0ad', weight: 700 })}${caps(H.rateUnit, { color: '#8ff0ad', track: 0.06 })}</span>`);
  };
  S.dock = (R, x, y, H) => H.forEach(([ic, label, badge], i) => {
    const bx = x + i * 84, on = i === 0;
    A(R, bx - 4, y - 4, 68, 68, '', ring(68, on ? 1 : 0, HUE, { sw: 1.5, track: 'rgba(255,255,255,.18)' }));
    A(R, bx + 4, y + 4, 52, 52, `display:grid;place-items:center;${on ? pearl(26, 0.3) : 'border-radius:50%;background:linear-gradient(180deg,rgba(52,60,90,.95),rgba(20,24,40,.95));box-shadow:inset 0 1px 0 rgba(255,255,255,.4),inset 0 0 0 1px rgba(255,255,255,.12),0 6px 14px rgba(0,0,0,.35)'}`, K.icon(ic, 24, on ? PINK : '#fff', { sw: 1.9 }));
    if (badge) A(R, bx + 34, y - 8, null, 20, `padding:0 7px;border-radius:10px;display:grid;place-items:center;background:linear-gradient(#fff3c4,#ffd34d);font:800 13px/20px Sarpanch;color:#3a2506;box-shadow:0 2px 6px rgba(0,0,0,.4)`, badge);
    A(R, bx - 12, y + 72, 84, null, 'text-align:center', caps(label, { color: '#eceaf2', weight: 800, track: 0.1, style: 'text-shadow:0 1px 3px rgba(0,0,0,.8)' }));
  });
  S.tray = (R, x, y, w, T) => {
    const h = 104; soft9(R, x, y, w, h, 20);
    A(R, x + 20, y + 14, w - 40, 18, 'display:flex;align-items:center;gap:8px', `${K.icon('bolt', 15, K.GOLD)}<span style="font:italic 800 15px/1 Montserrat;color:#ffe08a">${E(T.title[0].toUpperCase() + T.title.slice(1))}</span><span style="color:${soft};font:600 13px Montserrat">· ${E(T.sub)}</span><span style="flex:1;height:1px;background:linear-gradient(90deg,rgba(255,255,255,.16),transparent);margin-left:6px"></span>${dia(5, HUE)}`);
    const n = T.items.length, cw = (w - 40) / n;
    T.items.forEach(([key, L, chip, st], i) => {
      const cx = x + 20 + cw * i + cw / 2;
      A(R, cx - 21, y + 38, 42, 42, `border-radius:50%;background:rgba(0,0,0,.25);box-shadow:inset 0 1px 2px rgba(0,0,0,.5),0 1px 0 rgba(255,255,255,.06)${st === 'ready' ? `,0 0 0 1.5px ${K.rgba(K.GOLD, 0.6)}` : ''}`);
      gemImg(R, key, cx, y + 59, 36);
      A(R, cx - 40, y + 85, 80, 14, 'display:flex;justify-content:center', st === 'ready' ? num(chip, { size: 13, color: '#ffe08a' }) : caps(chip, { color: HUE_HI, weight: 800, track: 0.12 }));
    });
  };
  S.toast = (R, x, y, w, T) => {
    soft9(R, x, y, w, 74, 18);
    A(R, x + 16, y + 14, 46, 46, '', coin(46));
    A(R, x + 76, y, w - 96, 74, 'display:flex;flex-direction:column;justify-content:center;gap:8px', `<span class="row" style="gap:10px"><span style="font:italic 800 18px/1 Montserrat;color:#fff">${E(T.title)}</span><span style="padding:3px 8px;border-radius:10px;background:${K.rgba(K.GOLD, 0.16)};box-shadow:inset 0 0 0 1px ${K.rgba(K.GOLD, 0.45)};font:800 13px/1.1 Sarpanch;color:#ffe08a">${T.chip}</span></span><span style="font:600 14px/1 Montserrat;color:${soft}">${E(T.sub)}</span>`);
    A(R, x + 76, y + 64, (w - 96) * 0.62, 2, `border-radius:1px;background:linear-gradient(90deg,${K.GOLD},${K.rgba(K.GOLD, 0.3)})`);
  };
  S.zoom = (R, x, y) => { soft9(R, x, y, 150, 44, 22); A(R, x, y, 150, 44, 'display:flex;align-items:center;justify-content:space-between;padding:0 16px', K.icon('minus', 18, '#fff', { sw: 2 }) + num('51%', { size: 16 }) + K.icon('plus', 18, '#fff', { sw: 2 })); };
  S.hudStrip = (R, H) => { S.points(R, 146, 12, H.points); S.dock(R, 26, 942, H.dock); S.tray(R, 280, 946, 460, H.tray); };
  S.hudHome = (R, H) => { S.points(R, 670, 12, H.points); S.toast(R, 1480, 76, 416, H.toast); S.dock(R, 28, 942, H.dock); S.zoom(R, 292, 976); S.tray(R, 1060, 946, 560, H.tray); };
  S.nodeLabel = (R, n, x, y, k = 1) => {
    if (!n.name) return;
    const hue = K.HUES[n.key], locked = n.st === 'locked';
    A(R, x - 100, y, 200, null, 'display:flex;justify-content:center', `<div style="position:relative;display:flex;flex-direction:column;align-items:center;gap:${4 * k}px;padding:${6 * k}px ${12 * k}px ${6 * k}px;border-radius:${9 * k}px;background:linear-gradient(180deg,rgba(40,47,72,.9),rgba(16,19,32,.9));box-shadow:inset 0 1px 0 rgba(255,255,255,.2),inset 0 0 0 1px rgba(255,255,255,.07)">
      <i style="position:absolute;left:20%;right:20%;top:0;height:1px;background:linear-gradient(90deg,transparent,${locked ? 'rgba(255,255,255,.2)' : hue},transparent)"></i>
      <span style="font:italic 800 ${12.5 * k}px/1 Montserrat;letter-spacing:.06em;text-transform:uppercase;color:${locked ? '#c9c3d6' : '#fff'}">${E(n.name)}</span>
      <span class="row" style="gap:4px;font:700 ${14 * k}px/1 Sarpanch;color:${locked ? '#c9c3d6' : K.lift(hue, 0.45)}">${locked ? K.icon('lock', 12 * k, '#c9c3d6', { sw: 2.2 }) : ''}${K.nf(n.value)}</span></div>`);
  };
  STYLES[3] = S;
})();

// =============================================================================================== 4 FROSTED GLASS
(() => {
  const S = {}, text = '#ffffff', soft = 'rgba(255,255,255,.74)', ink = '#07121d';
  const GOOD = '#7ff0a8', GOOD_T = '#dcfbe6';
  // Roblox has no backdrop blur: the glass is a pre-blurred copy of the realm layers inside a CanvasGroup mask
  S.backdrop = { blur: 2.5, dim: 0.66 };
  const caps = (t, o = {}) => K.caps(t, Object.assign({ size: 12, color: soft, track: 0.1, weight: 700 }, o));
  // the material: blurred + darkened backdrop, a lit top edge, a fine rim, grain; platters and wells sit inside it
  const glass = (r, { blur = 36, tint = 0.3, lift = 0.1 } = {}) => `border-radius:${r}px;backdrop-filter:blur(${blur}px) saturate(1.5) brightness(.66);-webkit-backdrop-filter:blur(${blur}px) saturate(1.5) brightness(.66);` +
    `background:linear-gradient(180deg,rgba(255,255,255,${lift}),rgba(255,255,255,${lift * 0.35}) 38%,rgba(255,255,255,.02)),rgba(22,20,38,${tint});` +
    `box-shadow:inset 0 1px 0 rgba(255,255,255,.42),inset 1px 0 0 rgba(255,255,255,.1),inset -1px 0 0 rgba(255,255,255,.06),inset 0 -1px 0 rgba(255,255,255,.08),0 22px 50px rgba(8,4,20,.35)`;
  const platter = (r, a = 0.08) => `border-radius:${r}px;background:linear-gradient(180deg,rgba(255,255,255,${a + 0.03}),rgba(255,255,255,${a}));box-shadow:inset 0 1px 0 rgba(255,255,255,.2),inset 0 0 0 1px rgba(255,255,255,.07)`;
  const well = r => `border-radius:${r}px;background:rgba(0,0,0,.2);box-shadow:inset 0 1px 3px rgba(0,0,0,.35),inset 0 0 0 1px rgba(0,0,0,.08),0 1px 0 rgba(255,255,255,.1)`;
  const hueBtn = `background:linear-gradient(180deg,${K.lift(HUE, 0.35)},${HUE} 55%,${K.sink(HUE, 0.06)});box-shadow:inset 0 1px 0 rgba(255,255,255,.75),inset 0 0 0 1px rgba(255,255,255,.2),0 8px 22px ${K.rgba(HUE, 0.3)}`;

  S.panel = (R, P, { x, y, w, h }) => {
    const F = A(R, x, y, w, h, glass(40));
    grain(F, 0.07);
    A(F, 60, 0, w - 120, 1, 'background:linear-gradient(90deg,transparent,rgba(255,255,255,.7),transparent)');
    // header: glass emblem inside a completion ring, title, capsule row tag, layer capsule, close
    A(F, 34, 26, 76, 76, '', ring(76, P.ownedN[0] / P.ownedN[1], HUE_HI, { sw: 2.5, track: 'rgba(255,255,255,.16)' }));
    A(F, 44, 36, 56, 56, `display:grid;place-items:center;${platter(28, 0.12)}`, `<span style="font:900 28px/1 Sarpanch;color:#fff">${P.sym}</span>`);
    A(F, 128, 30, null, null, `font:italic 900 42px/1 Montserrat;color:${text}`, P.title);
    A(F, 130, 80, null, 24, 'display:flex;align-items:center;gap:12px', `<span style="padding:5px 12px;${platter(12, 0.12)}">${caps(P.row, { color: '#fff', weight: 800 })}</span><span style="font:600 14px Montserrat;color:${soft}">${E(P.sub)}</span>`);
    A(F, w - 40 - 44 - 132, 36, 120, 40, `display:flex;align-items:center;justify-content:center;gap:8px;${well(20)}`, caps('Layer') + `<span style="font:800 15px/1 Sarpanch;color:#fff">${P.layer[0]}<span style="color:rgba(255,255,255,.5)"> / ${P.layer[1]}</span></span>`);
    A(F, w - 40 - 44, 34, 44, 44, `display:grid;place-items:center;${platter(22, 0.12)}`, K.icon('close', 18, '#fff', { sw: 2 }));
    // tabs: a recessed capsule with a bright selection platter
    const tb = A(F, G.pad, G.tabsY, 540, G.tabsH, `display:flex;gap:4px;padding:4px;${well(23)}`);
    for (const t of P.tabs) {
      const on = !!t.on;
      K.el(tb, 'div', `flex:1;display:flex;align-items:center;justify-content:center;gap:9px;border-radius:19px;${on ? 'background:linear-gradient(180deg,rgba(255,255,255,.36),rgba(255,255,255,.16));box-shadow:inset 0 1px 0 rgba(255,255,255,.7),inset 0 0 0 1px rgba(255,255,255,.14),0 4px 14px rgba(0,0,0,.22)' : ''}`,
        `<span style="font:${on ? 'italic 800' : '700'} 15px/1 Montserrat;letter-spacing:.04em;text-transform:uppercase;color:${on ? '#fff' : 'rgba(255,255,255,.78)'}">${E(t.label)}</span>` +
        (t.badge ? `<span style="display:grid;place-items:center;min-width:20px;height:20px;padding:0 5px;border-radius:10px;background:${on ? HUE : 'rgba(255,255,255,.18)'};font:800 13px/1 Sarpanch;color:${on ? ink : '#fff'}">${t.badge}</span>` : '') +
        (t.dot ? `<span style="width:8px;height:8px;border-radius:50%;background:${K.GOLD};box-shadow:0 0 6px ${K.GOLD}"></span>` : ''));
    }
    A(F, w - G.pad - 330, G.tabsY, 330, G.tabsH, `display:flex;align-items:center;justify-content:space-around;padding:0 8px;${platter(23, 0.07)}`,
      `<span class="row" style="gap:7px">${K.icon('bolt', 15, K.GOLD)}<span style="font:800 15px/1 Sarpanch;color:${K.GOLD}">${P.ready}</span>${caps('Ready', { color: '#ffe7a0', weight: 800 })}</span><span style="width:1px;height:22px;background:rgba(255,255,255,.16)"></span>
       <span class="row" style="gap:8px">${ring(24, P.ownedN[0] / P.ownedN[1], GOOD, { sw: 3, track: 'rgba(255,255,255,.16)' })}<span style="font:800 15px/1 Sarpanch;color:#fff">${P.owned}</span>${caps('Owned', { weight: 800 })}</span>`);
    // hero + a sparkline in a recessed well
    A(F, G.pad + 4, G.heroY + 12, null, null, 'display:flex;flex-direction:column;gap:12px', caps(P.hero.cap, { size: 13, track: 0.14, color: 'rgba(255,255,255,.8)' }) +
      `<span style="font:800 60px/1 Sarpanch;color:#fff;text-shadow:0 2px 12px rgba(0,0,0,.25)">${E(P.hero.amt)}</span>` +
      `<span style="font:italic 900 20px/1 Montserrat;letter-spacing:.03em;text-transform:uppercase;color:${HUE_HI}">${E(P.hero.res)}</span>`);
    A(F, 426, G.heroY + 10, 150, 104, `display:flex;flex-direction:column;gap:8px;padding:12px 14px;${well(20)}`, `<span class="row" style="justify-content:space-between">${caps('Gain')}<span style="font:800 13px/1 Sarpanch;color:${GOOD}">+4.1%</span></span>${sparkline(122, 50, HUE_HI, { seed: 5, fill: 0.3, sw: 2 })}`);
    // CTA: the one solid capsule, ink type
    const cx = w - G.pad - G.ctaW, cy = G.heroY;
    const cta = A(F, cx, cy, G.ctaW, G.ctaH, `border-radius:48px;overflow:hidden;${hueBtn}`,
      `<div style="position:absolute;left:36px;top:21px;display:flex;flex-direction:column;gap:10px"><span style="font:italic 900 30px/1 Montserrat;color:${ink}">${P.cta.title}</span><span style="font:800 17px/1 Sarpanch;color:rgba(7,18,29,.78)">${K.nf(P.cta.gain)}</span></div>
       <div style="position:absolute;right:26px;top:50%;transform:translateY(-50%);display:grid;place-items:center;width:46px;height:46px;border-radius:50%;background:rgba(7,18,29,.86);box-shadow:inset 0 1px 0 rgba(255,255,255,.18)"><span style="font:800 17px Montserrat;color:#fff">${P.cta.key}</span></div>`);
    grain(cta, 0.07);
    P.chips.forEach(([l, v, tone], i) => A(F, cx + i * ((G.ctaW - 12) / 2 + 12), G.chipY + 4, (G.ctaW - 12) / 2, G.chipH, `display:flex;align-items:center;justify-content:space-between;padding:0 16px;${platter(17, 0.07)}`,
      caps(l) + num(v, { size: 16, color: tone === 'good' ? GOOD : '#fff' })));
    // collapsed owned tiers
    A(F, G.pad, G.sumY, w - 2 * G.pad, G.sumH, `display:flex;align-items:center;gap:14px;padding:0 8px 0 10px;${platter(21, 0.06)}`,
      `<span style="display:grid;place-items:center;width:26px;height:26px;border-radius:50%;background:${GOOD}">${K.icon('check', 15, ink, { sw: 3 })}</span><span style="font:800 15px/1 Montserrat;color:#fff">${E(P.summary.label)}</span>${num(P.summary.count, { size: 15, color: GOOD })}
       <span style="flex:1;font:600 14px Montserrat;color:${soft};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${E(P.summary.names)}</span><span class="row" style="gap:4px;padding:0 14px;height:30px;${platter(15, 0.1)}">${caps('Show', { color: '#fff', weight: 800 })}${K.icon('chevD', 15, '#fff', { sw: 2.2 })}</span>`);
    const tier = (y, t) => A(F, G.pad + 4, y - 6, w - 2 * G.pad - 4, 22, 'display:flex;align-items:center;gap:12px', `<span style="font:800 18px/1 Montserrat;color:#fff">${E(t.label)}</span><span style="padding:4px 10px;${well(11)}">${caps(t.count, { color: 'rgba(255,255,255,.82)' })}</span>${seg(t.n[1], t.n[0], { w: 16, h: 4, gap: 4, on: GOOD, off: 'rgba(255,255,255,.18)', radius: 2 })}<span style="flex:1;height:1px;background:rgba(255,255,255,.14)"></span>`);
    tier(G.t3Y, P.tier3); tier(G.t4Y, P.tier4);
    P.cards.forEach((c, i) => S.card(F, G.cx(i), G.cardY, G.cw, G.cardH, c));
    P.locked.forEach((c, i) => S.card(F, G.cx(i), G.lockY, G.cw, G.lockH, c));
    A(F, w - 20, G.cardY + 10, 5, 300, 'border-radius:3px;background:rgba(255,255,255,.4)');
    return F;
  };
  S.card = (F, x, y, w, h, c) => {
    const pad = 18, st = c.st;
    const C = A(F, x, y, w, h, st === 'locked' ? well(24) : st === 'buy'
      ? `border-radius:24px;background:linear-gradient(180deg,${K.rgba(HUE, 0.24)},${K.rgba(HUE, 0.08)});box-shadow:inset 0 1px 0 ${K.rgba(HUE_HI, 0.8)},inset 0 0 0 1px ${K.rgba(HUE, 0.45)}`
      : `${platter(24, 0.07)}`);
    const tag = st === 'buy' ? `<span style="padding:4px 10px;border-radius:11px;background:${K.rgba(HUE, 0.25)};box-shadow:inset 0 0 0 1px ${K.rgba(HUE_HI, 0.5)}">${caps('Buy', { color: '#fff', weight: 800 })}</span>`
      : st === 'owned' ? `<span class="row" style="gap:5px;padding:3px 10px 3px 4px;border-radius:12px;background:rgba(127,240,168,.16)"><span style="display:grid;place-items:center;width:18px;height:18px;border-radius:50%;background:${GOOD}">${K.icon('check', 11, ink, { sw: 3.4 })}</span>${caps('Owned', { color: GOOD, weight: 800 })}</span>`
        : `<span class="row" style="gap:6px">${K.icon('lock', 14, 'rgba(255,255,255,.75)', { sw: 2.2 })}${caps('Locked', { color: 'rgba(255,255,255,.75)', weight: 800 })}</span>`;
    A(C, pad + 2, 16, w - 2 * pad - 2, 26, 'display:flex;align-items:center;justify-content:space-between', `<span style="font:800 22px/1 Sarpanch;color:${st === 'buy' ? '#fff' : st === 'owned' ? GOOD_T : 'rgba(255,255,255,.55)'}">${c.n}</span>${tag}`);
    if (st === 'locked') {
      A(C, pad + 2, 52, w - 2 * pad - 2, h - 52 - 18, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { size: 17, color: 'rgba(255,255,255,.86)' }) + body(c.req, { size: 14, color: 'rgba(255,255,255,.72)', lh: 1.3 }) +
        (c.prog ? `<div class="row" style="gap:10px;margin-top:auto"><div style="flex:1;height:6px;border-radius:3px;background:rgba(0,0,0,.25);box-shadow:inset 0 1px 1px rgba(0,0,0,.3)"><div style="width:${pct(c)}%;height:100%;border-radius:3px;background:rgba(255,255,255,.7)"></div></div>${num(String(c.prog[0]), { size: 13, color: 'rgba(255,255,255,.85)' })}</div>` : ''));
      return;
    }
    A(C, pad + 2, 52, w - 2 * pad - 2, null, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { color: st === 'owned' ? GOOD_T : '#fff' }) + body(c.desc, { color: 'rgba(255,255,255,.82)' }));
    if (c.cur) A(C, pad, h - 16 - 42 - 52, w - 2 * pad, 44, `display:flex;flex-direction:column;justify-content:center;gap:6px;padding:0 14px;${well(14)}`, caps('Currently') + num(c.cur, { size: 16 }));
    if (st === 'buy') {
      A(C, pad, h - 16 - 42, w - 2 * pad, 42, `display:flex;align-items:center;justify-content:space-between;padding:0 18px;border-radius:21px;${hueBtn}`,
        `<span style="font:italic 900 16px/1 Montserrat;color:${ink}">BUY</span>${num(c.cost, { size: 16, color: ink, unit: 'color:rgba(7,18,29,.75)' })}`);
    } else {
      A(C, pad, h - 16 - 36, w - 2 * pad, 36, `display:flex;align-items:center;justify-content:center;gap:8px;${well(18)}`, `${K.icon('check', 15, GOOD, { sw: 2.8 })}<span style="font:700 14px/1 Montserrat;color:${GOOD}">Active</span>`);
    }
  };
  // ---------------------------------------------------------------------------- HUD (glass over the living map)
  const pane = (R, x, y, w, h, r) => { const e = A(R, x, y, w, h, glass(r, { blur: 24, tint: 0.22, lift: 0.12 })); grain(e, 0.06); return e; };
  S.points = (R, x, y, H) => {
    const w = 580, h = 78; pane(R, x, y, w, h, 39);
    A(R, x + 14, y + 13, 52, 52, `display:grid;place-items:center;border-radius:50%;background:radial-gradient(circle at 50% 30%,#fff5cc,#ffd34d 50%,#e0a21e);box-shadow:inset 0 1px 0 rgba(255,255,255,.8),0 4px 10px rgba(0,0,0,.25)`, K.icon('star', 24, '#5a3a06'));
    A(R, x + 82, y + 15, 290, null, 'display:flex;flex-direction:column;gap:8px', caps(H.cap, { color: 'rgba(255,255,255,.8)' }) + `<span class="row" style="gap:10px;align-items:baseline"><span style="font:800 34px/1 Sarpanch;color:#fff">${H.amt}</span><span style="font:700 15px Montserrat;color:${soft}">${H.unit}</span></span>`);
    A(R, x + 388, y + 12, 176, 54, `display:flex;flex-direction:column;justify-content:center;gap:5px;padding:0 14px;${well(27)}`, `${sparkline(148, 20, GOOD, { seed: 3, rise: 0.55, jitter: 0.3, fill: 0.25, sw: 1.8 })}<span class="row" style="gap:6px">${K.icon('up', 13, GOOD, { sw: 2.4 })}${num(H.rateShort, { size: 14, color: GOOD, weight: 700 })}${caps(H.rateUnit, { color: GOOD, track: 0.04 })}</span>`);
  };
  S.dock = (R, x, y, H) => H.forEach(([ic, label, badge], i) => {
    const bx = x + i * 84, on = i === 0;
    const e = pane(R, bx, y, 62, 62, 31);
    if (on) A(R, bx, y, 62, 62, 'border-radius:50%;background:linear-gradient(180deg,rgba(255,255,255,.34),rgba(255,255,255,.12));box-shadow:inset 0 1px 0 rgba(255,255,255,.75),inset 0 0 0 1.5px rgba(255,255,255,.3)');
    A(R, bx, y, 62, 62, 'display:grid;place-items:center', K.icon(ic, 26, '#fff', { sw: on ? 2.2 : 1.9 }));
    if (badge) A(R, bx + 36, y - 6, null, 20, `padding:0 7px;border-radius:10px;display:grid;place-items:center;background:${K.GOLD};font:800 13px/20px Sarpanch;color:#3a2506;box-shadow:0 2px 6px rgba(0,0,0,.3)`, badge);
    A(R, bx - 12, y + 70, 86, null, 'text-align:center', `<span style="font:700 13px/1 Montserrat;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.7)">${E(label)}</span>`);
  });
  S.tray = (R, x, y, w, T) => {
    const h = 104; pane(R, x, y, w, h, 30);
    A(R, x + 22, y + 14, w - 44, 18, 'display:flex;align-items:center;gap:8px', `${K.icon('bolt', 15, K.GOLD)}<span style="font:800 15px/1 Montserrat;color:#ffe7a0">${E(T.title[0].toUpperCase() + T.title.slice(1))}</span><span style="color:${soft};font:600 13px Montserrat">· ${E(T.sub)}</span>`);
    const n = T.items.length, cw = (w - 36) / n;
    T.items.forEach(([key, L, chip, st], i) => {
      const cx = x + 18 + cw * i + cw / 2;
      gemImg(R, key, cx, y + 58, 38);
      A(R, cx - 30, y + 80, 60, 18, `display:grid;place-items:center;${st === 'ready' ? `border-radius:9px;background:${K.rgba(K.GOLD, 0.22)}` : well(9)}`, st === 'ready' ? num(chip, { size: 13, color: '#ffe7a0' }) : caps(chip, { color: '#fff', weight: 800 }));
    });
  };
  S.toast = (R, x, y, w, T) => {
    pane(R, x, y, w, 74, 37);
    A(R, x + 14, y + 13, 48, 48, `display:grid;place-items:center;border-radius:50%;background:radial-gradient(circle at 50% 30%,#fff5cc,#ffd34d 50%,#e0a21e);box-shadow:inset 0 1px 0 rgba(255,255,255,.8)`, K.icon('spark', 24, '#5a3a06'));
    A(R, x + 76, y, w - 96, 74, 'display:flex;flex-direction:column;justify-content:center;gap:8px', `<span class="row" style="gap:10px"><span style="font:italic 800 18px/1 Montserrat;color:#fff">${E(T.title)}</span><span style="padding:3px 8px;border-radius:10px;background:${K.rgba(K.GOLD, 0.25)};font:800 13px/1.1 Sarpanch;color:#ffe7a0">${T.chip}</span></span><span style="font:600 14px/1 Montserrat;color:${soft}">${E(T.sub)}</span>`);
  };
  S.zoom = (R, x, y) => { pane(R, x, y, 150, 46, 23); A(R, x, y, 150, 46, 'display:flex;align-items:center;justify-content:space-between;padding:0 16px', K.icon('minus', 18, '#fff', { sw: 2.2 }) + num('51%', { size: 16 }) + K.icon('plus', 18, '#fff', { sw: 2.2 })); };
  S.hudStrip = (R, H) => { S.points(R, 146, 12, H.points); S.dock(R, 22, 942, H.dock); S.tray(R, 278, 946, 462, H.tray); };
  S.hudHome = (R, H) => { S.points(R, 670, 12, H.points); S.toast(R, 1480, 76, 416, H.toast); S.dock(R, 24, 942, H.dock); S.zoom(R, 290, 974); S.tray(R, 1060, 946, 560, H.tray); };
  S.nodeLabel = (R, n, x, y, k = 1) => {
    if (!n.name) return;
    const hue = K.HUES[n.key], locked = n.st === 'locked';
    A(R, x - 100, y, 200, null, 'display:flex;justify-content:center', `<div style="display:flex;flex-direction:column;align-items:center;gap:${4 * k}px;padding:${6 * k}px ${13 * k}px ${7 * k}px;${glass(14 * k, { blur: 14, tint: 0.3, lift: 0.1 })}">
      <span style="font:800 ${12.5 * k}px/1 Montserrat;letter-spacing:.06em;text-transform:uppercase;color:${locked ? 'rgba(255,255,255,.75)' : '#fff'}">${E(n.name)}</span>
      <span class="row" style="gap:4px;font:700 ${14 * k}px/1 Sarpanch;color:${locked ? 'rgba(255,255,255,.75)' : K.lift(hue, 0.5)}">${locked ? K.icon('lock', 12 * k, 'rgba(255,255,255,.75)', { sw: 2.2 }) : ''}${K.nf(n.value)}</span></div>`);
  };
  STYLES[4] = S;
})();
