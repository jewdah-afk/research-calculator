// styles.js - the four clean style kits. Each kit paints the same content (scenes.js: P panel, HUD, node labels)
// with its own complete vocabulary of surfaces, tabs, cards (BUY / OWNED / LOCKED), buttons and HUD pieces.
//   1 Sleek sci-fi   (after Destiny 2)   dark translucent, 1 px hairlines, corner ticks, crisp white type, one hue
//   2 Sharp          (Valorant / Apex)   flat opaque shapes, angled cuts, heavy type, one strong hue, no glow
//   3 Soft premium   (Honkai Star Rail)  soft gradient panels, fine fading accent lines, pills, gentle depth
//   4 Frosted glass  (visionOS)          blurred-glass platters, light edges, capsules, big radii
// Panel-local grid shared by every kit (so the four stills compare like for like): header 28-110, tabs 118-166,
// hero 190-336, summary 358-406, tier 3 cards 452-742, tier 4 locked cards 792-930 inside a 1072 x 958 panel.
const STYLES = {};
const G = {
  pad: 40, tabsY: 118, tabsH: 48, heroY: 190, ctaW: 430, ctaH: 100, chipY: 300, chipH: 36,
  sumY: 358, sumH: 48, t3Y: 426, cardY: 452, cardH: 290, t4Y: 766, lockY: 792, lockH: 138, cw: 236, gap: 16,
};
G.cx = i => G.pad + i * (G.cw + G.gap);
const HUE = K.HUES.p, HUE_HI = K.lift(HUE, 0.55);
const A = K.abs, E = K.esc;
// four L-shaped corner ticks drawn by one element (8 background strokes)
function ticks(parent, x, y, w, h, { len = 12, th = 2, color = '#fff', out = 0, style = '' } = {}) {
  const c = `linear-gradient(${color},${color})`;
  const bg = [`${c} 0 0/${len}px ${th}px`, `${c} 0 0/${th}px ${len}px`, `${c} 100% 0/${len}px ${th}px`, `${c} 100% 0/${th}px ${len}px`,
    `${c} 0 100%/${len}px ${th}px`, `${c} 0 100%/${th}px ${len}px`, `${c} 100% 100%/${len}px ${th}px`, `${c} 100% 100%/${th}px ${len}px`].map(s => s + ' no-repeat').join(',');
  return A(parent, x - out, y - out, w + 2 * out, h + 2 * out, `background:${bg};pointer-events:none;${style}`);
}
const num = (v, { size = 16, weight = 800, color = '#fff', unit = '' } = {}) => `<span class="nowrap" style="font:${weight} ${size}px/1 Sarpanch;color:${color}">${K.nf(v, unit)}</span>`;
const body = (t, { size = 15, color = '#d3d9e4', lh = 1.36, style = '' } = {}) => `<div style="font:600 ${size}px/${lh} Montserrat;color:${color};${style}">${E(t)}</div>`;
const cardTitle = (t, { size = 20, color = '#fff', italic = true, style = '' } = {}) => `<div style="font:${italic ? 'italic ' : ''}800 ${size}px/1.13 Montserrat;color:${color};padding-right:4px;${style}">${E(t)}</div>`;

// =============================================================================================== 1 SLEEK SCI-FI
(() => {
  const S = {}, line = 'rgba(255,255,255,.12)', lineHi = 'rgba(255,255,255,.26)', soft = '#aab4c4', text = '#f3f6fb', ink = '#06101b';
  const GOOD = '#7fe6a0', GOOD_T = '#d7f7e1';
  const hair = (a = 0.12) => `box-shadow:inset 0 0 0 1px rgba(255,255,255,${a})`;
  S.backdrop = { blur: 9, dim: 0.42 };
  const caps = (t, o = {}) => K.caps(t, Object.assign({ size: 12, color: soft, track: 0.16, weight: 700 }, o));

  S.panel = (R, P, { x, y, w, h }) => {
    const F = A(R, x, y, w, h, `background:linear-gradient(180deg,rgba(9,13,21,.9),rgba(6,9,15,.93));${hair(0.11)}`);
    A(F, 0, 0, w, h, `background:radial-gradient(ellipse 60% 38% at 18% 0%,${K.rgba(HUE, 0.13)},transparent 70%),radial-gradient(ellipse 50% 30% at 100% 100%,${K.rgba(HUE, 0.06)},transparent 70%)`);
    ticks(F, 0, 0, w, h, { len: 22, th: 2, color: 'rgba(255,255,255,.85)', out: 1 });
    A(F, 40, -1, 88, 3, `background:${HUE};box-shadow:0 0 10px ${K.rgba(HUE, 0.7)}`);
    // header: diamond emblem, title, row tag + subtitle, close
    A(F, 40, 32, 58, 58, 'display:grid;place-items:center', `<div style="position:absolute;inset:8px;transform:rotate(45deg);box-shadow:inset 0 0 0 1.5px ${HUE};background:${K.rgba(HUE, 0.12)}"></div><div style="position:absolute;inset:14px;transform:rotate(45deg);box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.35)}"></div><span style="position:relative;font:900 26px/1 Sarpanch;color:#fff">${P.sym}</span>`);
    A(F, 120, 30, null, null, `font:italic 900 44px/1 Montserrat;color:${text};letter-spacing:.01em`, P.title);
    A(F, 122, 82, null, 22, 'display:flex;align-items:center;gap:12px', `<span style="padding:4px 8px;box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.6)}">${caps(P.row, { color: HUE_HI, weight: 800 })}</span><span style="font:600 14px Montserrat;color:${soft}">${E(P.sub)}</span>`);
    A(F, w - 40 - 40, 34, 40, 40, `display:grid;place-items:center;${hair(0.22)}`, K.icon('close', 18, '#fff', { sw: 1.6 }));
    // tabs
    const tb = A(F, G.pad, G.tabsY, w - 2 * G.pad, G.tabsH, `display:flex;align-items:stretch;box-shadow:inset 0 -1px 0 ${line}`);
    for (const t of P.tabs) {
      const on = !!t.on;
      K.el(tb, 'div', `position:relative;display:flex;align-items:center;gap:10px;padding:0 24px;${on ? `background:linear-gradient(0deg,${K.rgba(HUE, 0.16)},transparent);box-shadow:inset 0 -2px 0 ${HUE}` : ''}`,
        `<span style="font:${on ? 'italic ' : ''}800 15px/1 Montserrat;letter-spacing:.1em;text-transform:uppercase;color:${on ? '#fff' : soft}">${E(t.label)}</span>` +
        (t.badge ? `<span style="display:grid;place-items:center;min-width:20px;height:18px;padding:0 5px;background:${on ? HUE : 'rgba(255,255,255,.14)'};font:800 13px/1 Sarpanch;color:${on ? ink : '#fff'}">${t.badge}</span>` : '') +
        (t.dot ? `<span style="width:7px;height:7px;transform:rotate(45deg);background:${K.GOLD};box-shadow:0 0 6px ${K.GOLD}"></span>` : ''));
    }
    K.el(tb, 'div', 'flex:1');
    K.el(tb, 'div', 'display:flex;align-items:center;gap:16px;padding-right:4px', `<span class="row" style="gap:6px">${K.icon('bolt', 14, K.GOLD)}${num(P.ready, { size: 15, color: K.GOLD })}${caps('Ready', { color: '#ffe08a', weight: 800 })}</span><span style="width:1px;height:18px;background:${lineHi}"></span><span class="row" style="gap:6px">${num(P.owned, { size: 15, color: '#fff' })}${caps('Owned', { weight: 800 })}</span>`);
    // hero
    A(F, G.pad, G.heroY + 4, 2, 112, `background:linear-gradient(${HUE},${K.rgba(HUE, 0.1)})`);
    A(F, G.pad + 20, G.heroY + 4, null, null, 'display:flex;flex-direction:column;gap:12px', caps(P.hero.cap, { size: 13 }) +
      `<span style="font:800 60px/1 Sarpanch;color:#fff;text-shadow:0 0 30px ${K.rgba(HUE, 0.35)}">${E(P.hero.amt)}</span>` +
      `<span style="font:italic 900 20px/1 Montserrat;letter-spacing:.04em;text-transform:uppercase;color:${HUE_HI}">${E(P.hero.res)}</span>`);
    // CTA: the one solid light surface on the panel, ink type, key hint
    const cx = w - G.pad - G.ctaW, cy = G.heroY - 2;
    ticks(F, cx, cy, G.ctaW, G.ctaH, { len: 12, th: 2, color: HUE_HI, out: 6 });
    A(F, cx, cy, G.ctaW, G.ctaH, `background:linear-gradient(180deg,${K.lift(HUE, 0.3)},${HUE} 60%,${K.sink(HUE, 0.08)});box-shadow:inset 0 1px 0 rgba(255,255,255,.6),0 14px 34px ${K.rgba(HUE, 0.3)}`,
      `<div style="position:absolute;right:0;top:0;bottom:0;width:150px;background:repeating-linear-gradient(135deg,rgba(6,16,27,.07) 0 2px,transparent 2px 9px)"></div>
       <div style="position:absolute;left:28px;top:22px;display:flex;flex-direction:column;gap:10px"><span style="font:italic 900 30px/1 Montserrat;color:${ink}">${P.cta.title}</span><span style="font:800 17px/1 Sarpanch;color:rgba(6,16,27,.8)">${K.nf(P.cta.gain)}</span></div>
       <div style="position:absolute;right:22px;top:50%;transform:translateY(-50%);display:flex;align-items:center;gap:10px"><span style="display:grid;place-items:center;width:30px;height:30px;box-shadow:inset 0 0 0 1.5px ${ink};font:800 15px Montserrat;color:${ink}">${P.cta.key}</span>${K.icon('chevR', 22, ink, { sw: 2.4 })}</div>`);
    // chips under the CTA
    P.chips.forEach(([l, v, tone], i) => A(F, cx + i * ((G.ctaW - 12) / 2 + 12), G.chipY, (G.ctaW - 12) / 2, G.chipH, `display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:rgba(255,255,255,.03);${hair(0.12)}`,
      caps(l, { track: 0.12 }) + num(v, { size: 16, color: tone === 'good' ? '#8ff0ad' : '#fff' })));
    // collapsed owned tiers
    A(F, G.pad, G.sumY, w - 2 * G.pad, G.sumH, `display:flex;align-items:center;gap:14px;padding:0 18px;background:rgba(255,255,255,.025);${hair(0.1)}`,
      `${K.icon('check', 18, GOOD, { sw: 2.4 })}${caps(P.summary.label, { size: 13, color: '#fff', weight: 800 })}${num(P.summary.count, { size: 15, color: GOOD })}<span style="width:1px;height:18px;background:${line}"></span>
       <span style="flex:1;font:600 14px Montserrat;color:${soft};white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${E(P.summary.names)}</span><span class="row" style="gap:4px">${caps('Show', { color: HUE_HI, weight: 800 })}${K.icon('chevD', 16, HUE_HI, { sw: 2.2 })}</span>`);
    // tier rows
    const tier = (y, t) => A(F, G.pad, y, w - 2 * G.pad, 16, 'display:flex;align-items:center;gap:12px', `${caps(t.label, { size: 13, color: '#fff', weight: 800 })}${caps(t.count)}<span style="flex:1;height:1px;background:linear-gradient(90deg,${lineHi},${line})"></span><span style="width:5px;height:5px;background:${HUE}"></span>`);
    tier(G.t3Y, P.tier3); tier(G.t4Y, P.tier4);
    P.cards.forEach((c, i) => S.card(F, G.cx(i), G.cardY, G.cw, G.cardH, c));
    P.locked.forEach((c, i) => S.card(F, G.cx(i), G.lockY, G.cw, G.lockH, c));
    return F;
  };
  S.card = (F, x, y, w, h, c) => {
    const pad = 18;
    if (c.st === 'buy') {
      A(F, x, y, w, h, `background:linear-gradient(180deg,${K.rgba(HUE, 0.16)},${K.rgba(HUE, 0.04)} 46%,rgba(255,255,255,.02));box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.5)}`);
      A(F, x, y, w, 2, `background:${HUE};box-shadow:0 0 12px ${K.rgba(HUE, 0.8)}`);
      ticks(F, x, y, w, h, { len: 9, th: 2, color: HUE_HI, out: 0 });
    } else if (c.st === 'owned') {
      A(F, x, y, w, h, `background:linear-gradient(180deg,rgba(75,224,122,.07),rgba(75,224,122,.025));box-shadow:inset 0 0 0 1px rgba(75,224,122,.3)`);
      ticks(F, x, y, w, h, { len: 9, th: 2, color: 'rgba(127,230,160,.55)' });
    } else {
      A(F, x, y, w, h, `background:repeating-linear-gradient(135deg,rgba(255,255,255,.028) 0 1px,transparent 1px 8px),rgba(0,0,0,.3);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)`);
    }
    const tag = c.st === 'buy' ? `<span style="padding:4px 7px;box-shadow:inset 0 0 0 1px ${K.rgba(HUE, 0.7)}">${caps('Buy', { color: HUE_HI, weight: 800 })}</span>`
      : c.st === 'owned' ? `<span class="row" style="gap:5px">${K.icon('check', 14, GOOD, { sw: 2.6 })}${caps('Owned', { color: GOOD, weight: 800 })}</span>`
        : `<span class="row" style="gap:5px">${K.icon('lock', 14, '#b9aec3', { sw: 2 })}${caps('Locked', { color: '#b9aec3', weight: 800 })}</span>`;
    const idxC = c.st === 'buy' ? HUE : c.st === 'owned' ? 'rgba(127,230,160,.75)' : '#737b8b';
    A(F, x + pad, y + 16, w - 2 * pad, 26, 'display:flex;align-items:center;justify-content:space-between', `<span style="font:800 26px/1 Sarpanch;color:${idxC}">${c.n}</span>${tag}`);
    if (c.st === 'locked') {
      A(F, x + pad, y + 54, w - 2 * pad, null, 'display:flex;flex-direction:column;gap:9px', cardTitle(c.title, { size: 17, color: '#c9bfd0' }) + body(c.req, { size: 14, color: '#aea6b9', lh: 1.3 }));
      return;
    }
    A(F, x + pad, y + 52, w - 2 * pad, null, 'display:flex;flex-direction:column;gap:8px', cardTitle(c.title, { color: c.st === 'owned' ? GOOD_T : '#fff' }) + body(c.desc, { color: c.st === 'owned' ? '#bfc8d6' : '#d3d9e4' }));
    if (c.cur) A(F, x + pad, y + h - 18 - 42 - 56, w - 2 * pad, 48, 'display:flex;flex-direction:column;justify-content:center;gap:7px;padding:0 12px;background:rgba(0,0,0,.35);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)', caps('Currently', { track: 0.12 }) + num(c.cur, { size: 16 }));
    if (c.st === 'buy') {
      A(F, x + pad, y + h - 18 - 42, w - 2 * pad, 42, `display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:linear-gradient(180deg,${K.lift(HUE, 0.25)},${HUE});box-shadow:inset 0 1px 0 rgba(255,255,255,.55)`,
        `<span style="font:italic 900 16px/1 Montserrat;color:${ink}">BUY</span>${num(c.cost, { size: 16, color: ink, unit: 'color:rgba(6,16,27,.8)' })}`);
    } else {
      A(F, x + pad, y + h - 18 - 30, w - 2 * pad, 1, 'background:rgba(127,230,160,.22)');
      A(F, x + pad, y + h - 18 - 18, w - 2 * pad, 18, 'display:flex;align-items:center;gap:7px', `${K.icon('check', 15, GOOD, { sw: 2.6 })}<span style="font:700 14px/1 Montserrat;color:#a5efbc">Active</span>`);
    }
  };
  // ---------------------------------------------------------------------------- HUD
  const plate = (R, x, y, w, h, extra = '') => { const e = A(R, x, y, w, h, `background:linear-gradient(180deg,rgba(9,13,21,.82),rgba(6,9,15,.86));${hair(0.13)};${extra}`); ticks(R, x, y, w, h, { len: 10, th: 2, color: 'rgba(255,255,255,.8)', out: 1 }); return e; };
  S.points = (R, cx, y, H) => {
    const w = 440, x = cx - w / 2; plate(R, x, y, w, 100);
    A(R, x, y - 1, 70, 3, `background:${K.GOLD};left:${cx - 35}px`);
    A(R, x, y + 16, w, null, 'display:flex;flex-direction:column;align-items:center;gap:10px', caps(H.cap) +
      `<span class="row" style="gap:10px;align-items:baseline"><span style="font:800 36px/1 Sarpanch;color:#fff">${H.amt}</span><span style="font:700 16px Montserrat;color:${soft}">${H.unit}</span></span>` +
      `<span class="row" style="gap:6px;color:#8ff0ad">${K.icon('up', 14, '#8ff0ad', { sw: 2.4 })}${num(H.rate, { size: 14, color: '#8ff0ad', weight: 700 })}</span>`);
  };
  S.dock = (R, x, y, H) => H.forEach(([ic, label, badge], i) => {
    const bx = x + i * 84; plate(R, bx, y, 60, 60);
    A(R, bx, y, 60, 60, 'display:grid;place-items:center', K.icon(ic, 28, '#fff', { sw: 1.7 }));
    if (badge) A(R, bx + 30, y - 9, null, 18, `padding:0 6px;display:grid;place-items:center;background:${K.GOLD};font:800 13px/18px Sarpanch;color:${ink}`, badge);
    A(R, bx - 12, y + 70, 84, null, 'text-align:center', caps(label, { color: '#e6ebf2', weight: 800, track: 0.08 }));
  });
  S.tray = (R, x, y, w, T) => {
    const h = 104; plate(R, x, y, w, h);
    A(R, x + 18, y + 14, w - 36, 16, 'display:flex;align-items:center;gap:8px', `${K.icon('bolt', 15, K.GOLD)}${caps(T.title, { size: 13, color: '#ffe08a', weight: 800 })}<span style="color:${soft};font:600 13px Montserrat">· ${E(T.sub)}</span><span style="flex:1;height:1px;background:${line};margin-left:6px"></span>`);
    const n = T.items.length, cw = (w - 36) / n;
    T.items.forEach(([key, L, chip, st], i) => {
      const cx = x + 18 + cw * i + cw / 2;
      const im = K.el(R, 'img', `position:absolute;left:${cx - 20}px;top:${y + 38}px;width:40px;height:40px`); im.src = K.GEM(key);
      A(R, cx - 40, y + 80, 80, 16, 'display:flex;justify-content:center', st === 'ready' ? num(chip, { size: 13, color: '#ffe08a' }) : caps(chip, { color: HUE_HI, weight: 800 }));
    });
  };
  S.toast = (R, x, y, w, T) => {
    plate(R, x, y, w, 70); A(R, x, y, 3, 70, `background:${K.GOLD}`);
    A(R, x + 22, y, w - 40, 70, 'display:flex;align-items:center;gap:16px', `${K.icon('spark', 26, K.GOLD)}<div style="display:flex;flex-direction:column;gap:7px;flex:1"><span class="row" style="gap:10px"><span style="font:italic 800 18px/1 Montserrat;color:#fff">${E(T.title)}</span><span style="padding:2px 6px;box-shadow:inset 0 0 0 1px ${K.GOLD};font:800 13px/1.1 Sarpanch;color:#ffe08a">${T.chip}</span></span><span style="font:600 14px/1 Montserrat;color:${soft}">${E(T.sub)}</span></div>`);
  };
  S.zoom = (R, x, y) => { plate(R, x, y, 150, 44); A(R, x, y, 150, 44, 'display:flex;align-items:center;justify-content:space-between;padding:0 14px', K.icon('minus', 18, '#fff', { sw: 2 }) + num('51%', { size: 16 }) + K.icon('plus', 18, '#fff', { sw: 2 })); };
  S.hudStrip = (R, H) => { S.points(R, 400, 12, H.points); S.dock(R, 22, 944, H.dock); S.tray(R, 278, 948, 462, H.tray); };
  S.hudHome = (R, H) => { S.points(R, 960, 12, H.points); S.toast(R, 1480, 76, 416, H.toast); S.dock(R, 24, 944, H.dock); S.zoom(R, 290, 976); S.tray(R, 1060, 948, 560, H.tray); };
  S.nodeLabel = (R, n, x, y, k = 1) => {
    if (!n.name && n.st !== 'locked') return;
    const hue = K.HUES[n.key], locked = n.st === 'locked';
    if (!n.name) return;
    A(R, x - 100, y, 200, null, 'display:flex;justify-content:center', `<div style="display:flex;flex-direction:column;align-items:center;gap:${4 * k}px;padding:${5 * k}px ${10 * k}px ${6 * k}px;background:rgba(6,9,15,.8);box-shadow:inset 0 0 0 1px rgba(255,255,255,.1)">
      ${caps(n.name, { size: 12 * k, color: locked ? '#c9c3d6' : '#fff', weight: 800, track: 0.12 })}
      <span class="row" style="gap:4px;font:700 ${14 * k}px/1 Sarpanch;color:${locked ? '#c9c3d6' : K.lift(hue, 0.45)}">${locked ? K.icon('lock', 12 * k, '#c9c3d6', { sw: 2.2 }) : ''}${K.nf(n.value)}</span></div>`);
  };
  STYLES[1] = S;
})();
