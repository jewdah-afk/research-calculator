// scenes.js - the approval samples. Real game content (the S13 / S19 saves of the design mockups): numbers, names
// and requirement texts come from docs/design/mockups and game-js/layers. Every scene is 1920 x 1080 unless noted.
const SCENES = {};
const BG = '/ui/out/bg/';

// ------------------------------------------------------------------------------------------------ the docked map
// the game's layout: the map Box shrinks to a 760 px strip beside the sheet; the sheet area shows the realm
// blurred and dimmed behind the floating frame
function mapStrip(R, L, { strip, wide, C, nodes, hud = {} }) {
  const T = UI_THEMES[L];
  O.abs(R, 0, 0, 1920, 1080, `background:url(${BG}${wide}) 0 0/1920px 1080px;filter:blur(9px) brightness(.42) saturate(.85)`);
  O.abs(R, 0, 0, 1920, 1080, `background:radial-gradient(ellipse 55% 45% at 72% 8%,${KIT_HEX(T.hue, 0.16)},transparent 70%),radial-gradient(ellipse 50% 40% at 100% 100%,${KIT_HEX(T.hue, 0.1)},transparent 70%)`);
  O.abs(R, 0, 0, 760, 1080, `background:url(${BG}${strip}) 0 0/760px 1080px`);
  O.abs(R, 700, 0, 90, 1080, 'background:linear-gradient(90deg,rgba(5,3,10,0),rgba(5,3,10,.55))');
  const S = (wx, wy) => [(wx - C[0]) * 0.9 + 380, (wy - C[1]) * 0.9 + 540];
  for (const n of nodes) { const [x, y] = S(n.w[0], n.w[1]); O.node(R, n.key, x, y, Object.assign({ size: 80, hue: UI_THEMES[n.key] ? UI_THEMES[n.key].hue : n.hue }, n)); }
  robloxBar(R);
  O.plaque(R, 214, 10, 400, Object.assign({}, hud.plaque || {}));
  O.dock(R, 14, 936);
  O.shelf(R, 432, 968, 312, hud.shelf || {});
}
function robloxBar(R) {   // the Roblox top-bar buttons (not ours): the HUD keeps clear of them
  for (const [x, t] of [[16, 'RBX'], [70, 'chat']]) O.abs(R, x, 12, 44, 44, 'border-radius:50%;background:rgba(10,8,16,.55);display:grid;place-items:center;font:700 11px Montserrat;color:#aaa', t);
}
function KIT_HEX(h, a) { const c = h.replace('#', ''); return `rgba(${parseInt(c.slice(0, 2), 16)},${parseInt(c.slice(2, 4), 16)},${parseInt(c.slice(4, 6), 16)},${a})`; }

const P_NODES = [
  { key: 'p', w: [1500, 1580], letter: 'P', name: 'PRESTIGE', value: 'e1.029e25', sel: true },
  { key: 'm', w: [1500, 1900], letter: 'M', name: 'MILESTONE', value: '164' },
  { key: 'mm', w: [1180, 1960], letter: 'MM', name: 'META', value: '27', ready: true },
  { key: 'em', w: [1820, 1960], letter: '?', locked: true },
  { key: 'sp', w: [1330, 1250], letter: 'SP', name: 'SUPER', value: 'e1.262e24' },
  { key: 'pb', w: [1670, 1250], letter: 'PB', name: 'BOOST', value: '1e13,760 P', locked: true },
];

// ------------------------------------------------------------------------------------------------ the P panel
const PX0 = 800, PY0 = 66, PW = 1072, PH = 958;
function prestigePanel(R, { tabs = 'A', hoverLift = 0, buyPulse = 0.8, locked4 = true, k = 1 } = {}) {
  const L = 'p';
  const F = PANEL.frame(R, L, PX0, PY0, PW, PH, { title: 'PRESTIGE', sub: [PANEL.subChip('ROW 1', L), PANEL.subCap('Resets for prestige points')] });
  const c = F.content;
  const TABS = [{ label: 'Upgrades', w: 210, on: true, badge: '2' }, { label: 'Buyables', w: 190, badge: '1' }, { label: 'Perks', w: 150, dot: true }];
  const chips = `<span class="subchip">${O.icon('bolt', 13, '#ffd34d')}<span class="nr">2</span> READY</span><span class="subchip" style="box-shadow:inset 0 0 0 1.5px #4be07a,inset 0 0 0 3px #0c2a16,0 1px 3px #000"><span class="nr">14 / 16</span> OWNED</span>`;
  if (tabs === 'A') PANEL.tabsA(c, L, 30, 104, PW - 60, TABS, { right: chips });
  else PANEL.tabsB(c, L, 30, 106, PW - 60, TABS);
  // hero row
  const hero = PANEL.hero(c, L, 40, 178, { amt: 'e1.029e25', res: 'PRESTIGE POINTS' });
  const cta = PANEL.cta(c, L, PW - 44 - 410, 172, 410, 104, { title: 'PRESTIGE', gain: '+e1.073e25 PP', key: 'P' });
  PANEL.chip(c, PW - 44 - 410, 286, 200, 'Points', 'e6.424e23');
  PANEL.chip(c, PW - 44 - 200, 286, 200, 'Passive', '+e1.073e25/s', { valColor: '#9ff3b4' });
  // tier board (tab B has no strip for the chips: they head the board)
  if (tabs !== 'A') O.abs(c, 40, 296, 400, 30, 'display:flex;gap:8px', chips);
  const X = 96, CW = 224, G = 14;
  const cx = i => X + i * (CW + G);
  const r1 = 346, r2 = 426, r3 = 494, r4 = 780;
  PANEL.rail(c, L, 38, r1 + 10, r4 + 130, [[r1 + 34, 1, 'owned'], [r2 + 18, 2, 'owned'], [r3 + 136, 3, 'open'], [r4 + 74, 4, 'locked']]);
  [['11', 'Prestige Boost I', '×e2.296e21'], ['12', 'Prestige Boost II', '×e1.725e22'], ['13', 'Prestige Self-Synergy II', '×e9.411e20'], ['14', 'Prestige Self-Synergy II', '×e7.886e20']]
    .forEach(([n, t, e], i) => PANEL.compactOwned(c, cx(i), r1, CW, 68, { n, title: t, eff: e }));
  PANEL.ownedBar(c, cx(0), r2, cx(3) + CW - cx(0), 36, { tier: 2, names: 'Exponental Boost I · Exponental Boost II · Prestige Boost III · Prestige Boost IV' });
  const cards = {};
  cards[31] = PANEL.cardBuy(c, L, cx(0), r3, CW, 270, { n: 31, title: 'Prestige Scaling Reducer I', desc: 'Milestone Cost Scaling is weaker based on your prestige points.', cur: '1.9745x weaker', cost: '1.00e6810 PP', pulse: buyPulse, lift: hoverLift });
  cards[32] = PANEL.cardOwned(c, cx(1), r3, CW, 270, { n: 32, title: 'Prestige Scaling Reducer II', desc: 'Prestige Upgrade 31 is boosted.' });
  cards[33] = PANEL.cardOwned(c, cx(2), r3, CW, 270, { n: 33, title: 'Prestige Scaling Reducer III', desc: 'Prestige Upgrade 31 is boosted.' });
  cards[34] = PANEL.cardBuy(c, L, cx(3), r3, CW, 270, { n: 34, title: 'Prestige Scaling Reducer IV', desc: 'Prestige Upgrade 31 is boosted.', cost: '1e16,335 PP', pulse: 1 - buyPulse * 0.6 });
  const L4 = [['41', 'Prestige Boost V', 'Complete AP Challenge 4 19.7 times'], ['42', 'Prestige Boost VI', 'Complete AP Challenge 3 14.1 times'],
    ['43', 'Prestige Buyable Boost I', 'Buy while in T Challenge 2'], ['44', 'Prestige Buyable Boost II', 'Buy while in T Challenge 4']];
  L4.forEach(([n, t, rq], i) => { cards[n] = PANEL.cardLocked(c, cx(i), r4, CW, 150, { n, title: t, req: rq, chain: locked4 || i > 0, chainY: 76 }); });
  // scroll affordance: a fade at the bottom edge and a thin hue scrollbar
  O.abs(c, 14, PH - 34, PW - 28, 22, 'background:linear-gradient(180deg,rgba(7,11,20,0),rgba(7,11,20,.8))');
  O.abs(c, PW - 24, 350, 5, 560, 'border-radius:3px;background:rgba(255,255,255,.07)');
  O.abs(c, PW - 24, 350, 5, 420, `border-radius:3px;background:linear-gradient(${UI_THEMES.p.hueHi},${UI_THEMES.p.hue});box-shadow:0 0 6px ${UI_THEMES.p.hue}`);
  return { F, c, cards, cx, rows: { r1, r2, r3, r4 }, CW, hero, cta };
}

function pScene(tabs) {
  return async () => {
    const R = O.root(); R.style.cssText = 'width:1920px;height:1080px';
    mapStrip(R, 'p', { strip: 'strip_p.png', wide: 'wide_p.png', C: [1500, 1640], nodes: P_NODES, hud: { shelf: { gems: [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP']] } } });
    prestigePanel(R, { tabs });
  };
}
SCENES.a = pScene('A');
SCENES.b = pScene('B');

// ------------------------------------------------------------------------------------------------ (c) the M panel
const M_NODES = [
  { key: 'm', w: [1500, 1900], letter: 'M', name: 'MILESTONE', value: '164', sel: true },
  { key: 'p', w: [1500, 1580], letter: 'P', name: 'PRESTIGE', value: 'e1.029e25', ready: true },
  { key: 'mm', w: [1180, 1960], letter: 'MM', name: 'META', value: '27', ready: true },
  { key: 'em', w: [1820, 1960], letter: '?', locked: true },
];
function ladderRow(c, L, x, y, w, h, st, { n, title, desc, req, need, pr }) {
  const T = UI_THEMES[L];
  if (st === 'next') {
    O.slice(c, 'glow9', x - 20, y - 20, w + 40, h + 40, { k: 0.9, tint: T.hue, style: 'opacity:.7' });
    O.slice(c, `card_${L}`, x, y, w, h, { k: 0.72 });
    O.abs(c, x + 22, y + 16, w - 44, h - 30, 'display:flex;justify-content:space-between;align-items:center;gap:20px',
      `<div style="display:flex;flex-direction:column;gap:6px">${O.caps('Next milestone', '#e6dcf6', 12)}${O.tx(title, { size: 24, weight: 900, ow: 5, sh: 3, grad: ['#fff', T.hueHi, T.hue] })}<span class="body">${O.esc(desc)}</span></div>
       <div style="display:flex;flex-direction:column;align-items:flex-end;gap:8px;flex:none">${O.caps('Requires', '#e6dcf6', 12)}<span style="font:800 20px Sarpanch;color:#fff">${O.nf(need, '#efe6ff')}</span>
       <div style="display:flex;align-items:center;gap:10px"><div class="bar" style="width:170px"><i style="width:${pr * 100}%;background:linear-gradient(#fff,${T.hueHi} 40%,${T.hue});box-shadow:0 0 8px ${T.hue}"></i></div><span style="font:800 16px Sarpanch;color:#fff">${Math.round(pr * 100)}%</span></div></div>`);
  } else if (st === 'owned') {
    O.slice(c, 'card_owned', x, y, w, h, { k: 0.6 });
    O.abs(c, x + 22, y, w - 44, h, 'display:flex;align-items:center;gap:14px',
      `${O.icon('check', 18, '#9be8a9')}<div style="display:flex;flex-direction:column;gap:3px"><span style="font:italic 800 17px Montserrat;color:#fff0cf;text-shadow:0 2px 0 #000">${O.esc(title)}</span><span style="font:600 14px Montserrat;color:#e8dcc0">${O.esc(desc)}</span></div>`);
  } else if (st === 'locked') {
    PANEL.lockedRow(c, x, y, w, h, { title, req });
  } else {   // collapsed group
    O.slice(c, 'card_owned', x, y, w, h, { k: 0.5, style: 'opacity:.9' });
    O.abs(c, x + 20, y, w - 40, h, 'display:flex;align-items:center;gap:14px;white-space:nowrap',
      `<span style="font:800 13px Montserrat;color:#ffe08a">▸</span><span style="font:800 15px Sarpanch;color:#fff0cf">${O.esc(title)}</span><span style="display:inline-flex;align-items:center;gap:4px;font:800 13px Sarpanch;color:#bff0c8">${O.icon('check', 12, '#9be8a9')}10</span><span style="font:600 14px Montserrat;color:#e8dcc0">${O.esc(desc)}</span>`);
  }
}
SCENES.c = async () => {
  const R = O.root(); R.style.cssText = 'width:1920px;height:1080px';
  mapStrip(R, 'm', { strip: 'strip_m.png', wide: 'wide_p.png', C: [1500, 1760], nodes: M_NODES, hud: { shelf: { gems: [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP']] } } });
  const L = 'm', T = UI_THEMES[L];
  const F = PANEL.frame(R, L, PX0, PY0, PW, PH, { title: 'MILESTONE', sub: [PANEL.subChip('ROW 0', L), PANEL.subCap('The root of the tree')] });
  const c = F.content;
  PANEL.hero(c, L, 40, 124, { amt: '164', res: 'MILESTONES', size: 64 });
  PANEL.cta(c, L, PW - 44 - 420, 118, 420, 118, { title: 'GET +1 MILESTONE', bar: 0.4, gain: 'need e1.057e60 points', key: 'M' });
  PANEL.chip(c, PW - 44 - 420, 246, 420, 'Auto-get', 'On · from Meta Milestones', { valColor: '#ffe08a' });
  PANEL.section(c, L, 36, 300, 660, 'MILESTONE LADDER', '<span class="subchip"><span class="nr">164 / 187</span> DONE</span>');
  // ladder: a gold rod with the number medallions, newest first (locked teaser, NEXT, owned, collapsed groups)
  const lx = 108, lw = 600, rows = [
    ['locked', 348, 70, { n: 166, title: '166th Milestone', req: 'Get the 165th milestone first' }],
    ['next', 432, 112, { n: 165, title: '165th Milestone', desc: '1st Exotic Effect is better.', need: 'e1.057e60 points', pr: 0.4 }],
    ['owned', 560, 62, { n: 164, title: '164th Milestone', desc: 'Power Scaler is ^1.5 better.' }],
    ['owned', 632, 62, { n: 163, title: '163rd Milestone', desc: 'Power Scaler is ^1.5 better.' }],
    ['owned', 704, 62, { n: 162, title: '162nd Milestone', desc: 'Keep Prestige Power upgrades on Exotic Prestige reset.' }],
    ['owned', 776, 62, { n: 161, title: '161st Milestone', desc: 'Unlock an Atomic Prestige buyable.' }],
    ['group', 850, 42, { title: '151 – 160', desc: 'Unlocks 2 new layers' }],
    ['group', 900, 42, { title: '141 – 150', desc: 'Unlocks more Super Energy upgrades' }],
  ];
  O.abs(c, 60, 356, 6, 580, 'background:linear-gradient(90deg,#3a2308,#b07a28 30%,#fff3c4 50%,#c08a2e 70%,#3a2308);border-radius:3px;opacity:.85');
  for (const [st, y, h, d] of rows) {
    ladderRow(c, L, lx, y, lw, h, st, d);
    const cy = y + h / 2;
    if (st === 'next') {
      O.sprite(c, 'glow', 63, cy, 150, 150, { color: T.hue, alpha: 0.7 });
      O.image(c, `medal_${L}`, 63, cy, { k: 0.66 });
      O.abs(c, 23, cy - 20, 80, 40, 'display:grid;place-items:center', O.tx('165', { size: 24, font: 'num', ow: 5, sh: 2 }));
    } else if (st === 'locked') O.image(c, 'seal_locked', 63, cy, { k: 0.5 });
    else if (st === 'owned') {
      O.image(c, 'socket_empty', 63, cy, { k: 0.78 });
      O.abs(c, 33, cy - 14, 60, 28, 'display:grid;place-items:center', `<span style="font:800 15px Sarpanch;color:#ffe08a;text-shadow:0 1px 0 #000">${d.n}</span>`);
    } else O.abs(c, 57, cy - 6, 12, 12, 'border-radius:50%;background:radial-gradient(circle at 35% 35%,#fff3c4,#c08a2e 60%,#3a2308)');
  }
  O.abs(c, 14, PH - 40, PW - 28, 28, 'background:linear-gradient(180deg,rgba(12,8,20,0),rgba(12,8,20,.85))');
  // right column: notes, jump-to, filters
  const rx = 744, rw = PW - 44 - rx;
  O.slice(c, 'toast', rx, 300, rw, 214, { k: 0.8 });
  O.abs(c, rx + 22, 318, rw - 44, null, 'display:flex;flex-direction:column;gap:10px', O.caps('Notes', '#ffe3a1', 12) +
    [['Milestone cost scaling starts at', '17.8965'], ['Milestone cost exponent is', '27.4414'], ['Prestige Essences boosts points after softcap by', 'e6.424e23x']]
      .map(([t, v]) => `<div style="display:flex;gap:8px;font:600 14px/1.3 Montserrat;color:#ece6f7"><span style="color:${T.hue}">◆</span><span>${O.esc(t)} <b style="font:800 15px Sarpanch;color:#fff">${O.nf(v)}</b></span></div>`).join(''));
  O.slice(c, 'toast', rx, 530, rw, 286, { k: 0.8 });
  O.abs(c, rx + 22, 548, null, null, '', O.caps('Jump to', '#ffe3a1', 12));
  ['Next · 165', '151 – 164', '126 – 150', '101 – 125', '76 – 100'].forEach((t, i) => {
    const y = 574 + i * 44, on = i === 0;
    if (on) { O.sprite(c, 'glow', rx + rw / 2, y + 18, rw * 1.1, 80, { color: T.hue, alpha: 0.45 }); O.slice(c, `tabB_${L}`, rx + 14, y - 2, rw - 28, 40, { k: 0.5 }); }
    else O.slice(c, 'tabB_bar', rx + 18, y, rw - 36, 36, { k: 0.4 });
    O.abs(c, rx + 34, y, rw - 68, 36, 'display:flex;align-items:center;justify-content:space-between',
      (on ? O.tx(t, { size: 16, weight: 900, ow: 4, sh: 2 }) : `<span style="font:800 15px Sarpanch;color:#e2dbee">${O.nf(t)}</span>`) + `<span style="font:800 15px Montserrat;color:${on ? '#fff' : '#b9aecb'}">›</span>`);
  });
  PANEL.chip(c, rx, 830, rw, 'Show', 'All', { valColor: '#fff' });
  PANEL.chip(c, rx, 874, rw, 'Order', 'Newest first', { valColor: '#fff' });
};

// ------------------------------------------------------------------------------------------------ (d) the CR panel
const CR_NODES = [
  { key: 'cp', w: [3510, 1200], letter: 'CR', name: 'CORRUPTED', value: '23', sel: true, ready: true },
  { key: 'cm', w: [3690, 930], letter: 'CM', name: 'CORRUPTED MS', value: 'e1.833e11' },
  { key: 'ex', w: [3150, 780], letter: 'EX', name: 'EXPLORE', value: '3', ready: true },
  { key: 'pm', w: [3150, 1560], letter: 'PM', ready: true },
];
function diskCell(c, x, y, w, h, d) {
  const T = UI_THEMES.cp, n = d.n;
  if (!d.kind) {
    O.slice(c, 'tabB_bar', x, y, w, h, { k: 0.4, style: 'opacity:.85' });
    O.abs(c, x, y, w, h, 'display:grid;place-items:center;font:700 15px RobotoMono;color:#7f9a86', String(n));
    return;
  }
  const col = d.kind === 'trojan' ? T.hue : d.kind === 'backdoor' ? T.glitch.alt : '#ffc94d';
  O.slice(c, 'glow9', x - 16, y - 16, w + 32, h + 32, { k: 0.7, tint: col, style: `opacity:${d.active ? 0.9 : 0.55}` });
  O.slice(c, d.kind === 'trojan' ? 'card_cp' : d.kind === 'backdoor' ? 'card_locked' : 'card_owned', x, y, w, h, { k: 0.5 });
  if (d.kind === 'backdoor') O.abs(c, x + 6, y + 6, w - 12, h - 12, `background:radial-gradient(ellipse at 50% 40%,${KIT_HEX(col, 0.28)},transparent 70%)`);
  O.abs(c, x, y + 8, w, h - 14, 'display:flex;flex-direction:column;align-items:center;justify-content:space-between',
    `<span style="font:700 13px RobotoMono;letter-spacing:.06em;color:${d.active ? '#ffe08a' : col};text-shadow:0 0 6px ${col},0 1px 0 #000">${d.label}</span>
     <span style="display:flex;align-items:baseline;gap:5px"><span style="font:800 13px Montserrat;color:#e8f2e6">LV</span>${O.tx(String(d.lv), { size: 24, font: 'num', ow: 4, sh: 2, grad: ['#fff', d.active ? '#ffe08a' : col] })}</span>
     <span style="font:700 14px RobotoMono;color:#fff;text-shadow:0 1px 0 #000">${n}</span>`);
  if (d.active) { O.abs(c, x + 14, y + h - 12, w - 28, 5, 'border-radius:3px;background:rgba(0,0,0,.7)'); O.abs(c, x + 14, y + h - 12, (w - 28) * 0.63, 5, 'border-radius:3px;background:linear-gradient(#fff3c4,#ffc233);box-shadow:0 0 6px #ffc233'); }
}
SCENES.d = async () => {
  const R = O.root(); R.style.cssText = 'width:1920px;height:1080px';
  mapStrip(R, 'cp', { strip: 'strip_cr.png', wide: 'wide_cr.png', C: [3380, 1180], nodes: CR_NODES,
    hud: { plaque: { label: 'POINTS · PRESTIGE MULTIVERSE', value: '4.48e10', rate: 'Goal met: leaving will finish' }, shelf: { title: '4 READY', gems: [['pm', 'PM'], ['cp', 'CR'], ['ex', 'EX']] } } });
  const L = 'cp', T = UI_THEMES[L], G = T.glitch;
  const F = PANEL.frame(R, L, PX0, PY0, PW, PH, { title: 'CORRUPTED PRESTIGE', titleSize: 40, crestX: 0.73,
    sub: [PANEL.subChip('MULTIVERSE · ROW 1', L), `<span class="term" style="color:${T.hue};text-shadow:0 0 6px ${T.hue}">C:\\MULTIVERSE\\CORRUPTED&gt;_</span>`] });
  const c = F.content;
  PANEL.tabsA(c, L, 30, 104, PW - 60, [{ label: 'Corruptions', w: 230, on: true }, { label: 'Upgrades', w: 180, dot: true }, { label: 'Antivirus', w: 180 }],
    { right: `<span class="term" style="font-size:14px;color:#9fdc92">sys.integrity <b style="color:${G.alt}">31%</b></span>` });
  // stats + the CORRUPT button
  O.abs(c, 40, 172, null, null, 'display:flex;gap:26px;align-items:flex-end',
    `<div style="display:flex;flex-direction:column;gap:4px">${O.caps('Caused', '#d7e8d2', 13)}${O.tx('23', { size: 58, font: 'num', ow: 7, sh: 4, grad: ['#fff', '#e8ffe0', '#b8f5a8'] })}</div>
     <div style="width:2px;height:70px;background:linear-gradient(transparent,${T.hue},transparent)"></div>
     <div style="display:flex;flex-direction:column;gap:4px">${O.caps('Fixed', '#d7e8d2', 13)}${O.tx('16', { size: 58, font: 'num', ow: 7, sh: 4, grad: ['#fff', T.hueHi, T.hue] })}</div>`);
  PANEL.chip(c, 298, 178, 330, 'Corruption essences', 'e569,142,978', { valColor: T.hueHi });
  PANEL.chip(c, 298, 222, 330, 'Points & PE gain', '×e423,228,229', { valColor: T.hueHi });
  PANEL.cta(c, L, PW - 44 - 390, 168, 390, 104, { title: 'CORRUPT', gain: '20 / 20 charges · next at 7.33e13 pts' });
  O.slice(c, 'toast', PW - 44 - 84, 178, 70, 28, { k: 0.4 }); O.abs(c, PW - 44 - 84, 178, 70, 28, 'display:grid;place-items:center;font:800 13px Montserrat;color:#ffe9b0', 'Ctrl+C');
  // mode selector
  O.abs(c, 40, 296, null, null, '', O.caps('Essence & recharge mode', '#d7e8d2', 12));
  const mode = (x, w, on, t, s) => {
    if (on) { O.slice(c, 'glow9', x - 16, 300, w + 32, 94, { k: 0.7, tint: T.hue, style: 'opacity:.6' }); O.slice(c, `card_${L}`, x, 316, w, 62, { k: 0.5 }); }
    else O.slice(c, 'toast', x, 316, w, 62, { k: 0.5 });
    O.image(c, on ? `socket_${L}` : 'socket_empty', x + 30, 347, { k: 0.5 });
    O.abs(c, x + 56, 316, w - 70, 62, 'display:flex;flex-direction:column;justify-content:center;gap:4px',
      `<span style="font:italic 900 16px Montserrat;color:${on ? '#fff' : '#d8e4d4'};text-shadow:0 2px 0 #000">${t}</span><span style="font:600 14px Montserrat;color:${on ? '#dcf5d4' : '#b9c9b4'}">${O.nf(s)}</span>`);
  };
  mode(36, 488, true, 'PRESTIGE ESSENCE BOOST', 'But lose ^0.5 of Prestige Essences');
  mode(540, 492, false, 'POINTS BOOST', 'But nullify Prestige Essences');
  // disk terminal
  const wx = 36, wy = 394, ww = 604, wh = 496;
  O.slice(c, 'toast', wx, wy, ww, wh, { k: 0.7 });
  O.abs(c, wx + 12, wy + 12, ww - 24, wh - 24, `background:repeating-linear-gradient(0deg,rgba(57,255,20,.035) 0 2px,transparent 2px 4px)`);
  O.abs(c, wx + 22, wy + 18, ww - 44, 30, 'display:flex;align-items:center;gap:10px',
    `<span style="width:10px;height:10px;border-radius:50%;background:${G.alt}"></span><span style="width:10px;height:10px;border-radius:50%;background:#ffc94d"></span><span style="width:10px;height:10px;border-radius:50%;background:${T.hue}"></span>
     <span class="term" style="color:#dff5d8;margin-left:6px">C:\\CORRUPTION\\DISKS</span><span style="flex:1"></span>
     <span class="subchip" style="box-shadow:inset 0 0 0 1.5px ${T.hue},0 1px 3px #000;color:${T.hueHi}"><span class="nr">7</span> corrupted</span><span class="subchip" style="box-shadow:inset 0 0 0 1.5px #ffc94d,0 1px 3px #000;color:#ffe08a"><span class="nr">1</span> fixing</span>`);
  const D = {
    101: { kind: 'trojan', label: 'TROJAN', lv: 3 }, 103: { kind: 'backdoor', label: 'BACKDOOR', lv: 2 }, 202: { kind: 'active', label: 'TROJAN', lv: 6, active: true },
    204: { kind: 'trojan', label: 'TROJAN', lv: 1 }, 301: { kind: 'backdoor', label: 'BACKDOOR', lv: 4 }, 305: { kind: 'trojan', label: 'TROJAN', lv: 2 }, 403: { kind: 'trojan', label: 'TROJAN', lv: 3 },
  };
  for (let r = 0; r < 4; r++) for (let q = 0; q < 5; q++) {
    const n = (r + 1) * 100 + q + 1;
    diskCell(c, wx + 26 + q * 112, wy + 62 + r * 98, 102, 88, Object.assign({ n }, D[n] || {}));
  }
  O.abs(c, wx + 26, wy + wh - 42, ww - 52, 24, 'display:flex;gap:18px;align-items:center;font:600 14px Montserrat;color:#d8e4d4',
    `<span><b style="color:${T.hue}">▣</b> Trojan: ÷ points</span><span><b style="color:${G.alt}">▣</b> Backdoor: ÷ essences</span><span><b style="color:#ffc94d">▣</b> Active</span>`);
  // active disk inspector
  const ax = 660, aw = PW - 44 - ax;
  O.slice(c, 'toast', ax, wy, aw, wh, { k: 0.7 });
  O.abs(c, ax + 22, wy + 22, aw - 44, null, 'display:flex;flex-direction:column;gap:14px',
    `<div style="display:flex;justify-content:space-between">${O.caps('Active disk', '#d7e8d2', 12)}<span style="font:600 14px Montserrat;color:#d8e4d4">Disk <span class="nr">202</span> · row <span class="nr">2</span>, slot <span class="nr">2</span></span></div>
     <div style="display:flex;align-items:center;gap:10px">${O.tx('TROJAN', { size: 30, ow: 5, sh: 3, grad: ['#fff', '#ffe08a', '#ffc233'] })}<span style="font:800 15px Montserrat;color:#fff">LV</span>${O.tx('6', { size: 30, font: 'num', ow: 5, sh: 3 })}<span class="subchip" style="color:#ffe08a">FIXING</span></div>
     <div class="term" style="color:#ffe08a;text-shadow:0 0 6px #ffb300">[██████████====] -&lt; 63% &gt;-</div>
     <div style="display:flex;justify-content:space-between;align-items:flex-start;font:600 14px Montserrat;color:#e2ecdf"><span>To fix, get (while active)</span><span style="text-align:right"><b style="font:800 16px Sarpanch;color:#fff">7.10e10</b> points<br><span style="color:#b9c9b4">you have <span class="nr">4.48e10</span></span></span></div>
     <div class="hr" style="--c:${T.hue}"></div>
     <div style="display:flex;justify-content:space-between;font:600 14px Montserrat;color:#e2ecdf"><span>While active, points gain</span><b style="font:800 16px Sarpanch;color:${G.alt}">÷153.90</b></div>
     <div class="hr" style="--c:${T.hue}"></div>
     <div style="display:flex;justify-content:space-between;font:600 14px Montserrat;color:#e2ecdf"><span>Reward on fix</span><span><b style="font:800 16px Sarpanch;color:${T.hueHi}">e423,228,138</b> essences</span></div>`);
  O.sprite(c, 'glow', ax + aw / 2, wy + 312, aw * 1.2, 150, { color: '#ffc233', alpha: 0.35 });
  O.slice(c, 'btn_gold', ax + 22, wy + 284, aw - 44, 58, { k: 0.5 });
  O.abs(c, ax + 22, wy + 284, aw - 44, 58, 'display:grid;place-items:center', O.tx('DEACTIVATE', { size: 21, ow: 5, sh: 2 }));
  O.abs(c, ax + 22, wy + 360, aw - 44, null, 'display:flex;flex-direction:column;gap:9px',
    `<div style="display:flex;justify-content:space-between">${O.caps('Other disks', '#d7e8d2', 12)}<span style="font:600 13px Montserrat;color:#b9c9b4">Tap to inspect</span></div>
     <div style="display:flex;flex-wrap:wrap;gap:7px">${[['101', 'Trojan 3', 0], ['103', 'Backdoor 2', 1], ['204', 'Trojan 1', 0], ['301', 'Backdoor 4', 1]]
      .map(([n, t, b]) => `<span class="subchip" style="box-shadow:inset 0 0 0 1.5px ${b ? G.alt : T.hue},0 1px 3px #000"><span class="nr">${n}</span> ${t}</span>`).join('')}</div>`);
  O.abs(c, ax + 22, wy + wh - 40, aw - 44, 24, '', `<span class="term" style="color:${T.hueHi}">&gt; To activate corruption, click on it. <span style="background:${T.hue};color:${T.hue}">█</span></span>`);
  O.abs(c, 70, 902, PW - 150, 30, 'display:flex;gap:8px;align-items:center', `<span class="term" style="font-size:14px;color:#cfe3ca">ⓘ When you do a Corruption Reset, a malware will appear on a random disk. Fix them for essences. <b style="color:${T.hue}">MORE ▾</b></span>`);
};

// ------------------------------------------------------------------------------------------------ (e) home map HUD
SCENES.e = async () => {
  const R = O.root(); R.style.cssText = 'width:1920px;height:1080px';
  O.abs(R, 0, 0, 1920, 1080, `background:url(${BG}home.png) 0 0/1920px 1080px`);
  const S = (wx, wy) => [(wx - 1760) * 0.5 + 960, (wy - 1110) * 0.5 + 540];
  const N = [
    ['t', 1500, 320, 'T', 'TRANSCEND', '1.00e70'], ['hb', 1180, 660, 'HB', 'HYPER BOOST', '1e413,950 HP', { locked: true }], ['ap', 1500, 610, 'AP', 'ATOMIC', 'e4.234e18'],
    ['mp', 1820, 660, 'MP', 'MULTIVERSE', '0', { ready: true }], ['se', 1150, 980, 'SE', 'SUPER ENERGY', '4.49e24'], ['hp', 1500, 930, 'HP', 'HYPER', 'e8.502e20'],
    ['ep', 1850, 980, 'EP', 'EXOTIC', 'e1,329,005', { ready: true }], ['pe', 1040, 1300, 'PE', 'ENERGY', '2.06e25'], ['sp', 1330, 1250, 'SP', 'SUPER', 'e1.262e24'],
    ['pb', 1670, 1250, 'PB', 'BOOST', '1e13,760 P', { locked: true }], ['pp', 1960, 1300, 'PP', 'POWER', 'e798,769,126'], ['p', 1500, 1580, 'P', 'PRESTIGE', 'e1.029e25'],
    ['m', 1500, 1900, 'M', 'MILESTONE', '164'], ['mm', 1180, 1960, 'MM', 'META', '27', { ready: true }], ['em', 1820, 1960, '?', null, null, { locked: true }],
    ['ach', 520, 600, '★', 'ACHIEVEMENTS', '13 / 18'],
  ];
  for (const [key, wx, wy, letter, name, value, extra] of N) {
    const [x, y] = S(wx, wy);
    O.node(R, key, x, y, Object.assign({ size: 60, letter, name, value, hue: UI_THEMES[key] ? UI_THEMES[key].hue : '#ffd34d', k: 0.86 }, extra || {}));
  }
  robloxBar(R);
  O.plaque(R, 740, 10, 440, {});
  // toasts (top right) + the sealed-rift tooltip
  O.toast(R, 1478, 70, 420, { title: 'Milestone Gotten!', chip: '×10', sub: '18th – 27th Meta-Milestone', icon: 'star', color: '#ffd34d' });
  O.toast(R, 1478, 154, 420, { title: 'Achievement Gotten!', sub: 'Even more boosters!!', icon: 'trophy', color: '#9d8cff' });
  O.slice(R, 'toast', 1770, 238, 110, 34, { k: 0.4 }); O.abs(R, 1770, 238, 110, 34, 'display:grid;place-items:center;font:800 14px Montserrat;color:#f2eefc', '+3 more');
  const tx = 1200, ty = 520, tw = 370, th = 196;
  O.slice(R, 'shadow', tx - 18, ty - 8, tw + 36, th + 34, { style: 'opacity:.85' });
  O.slice(R, 'toast', tx, ty, tw, th, { k: 0.8 });
  O.abs(R, tx + 22, ty + 18, tw - 44, null, 'display:flex;flex-direction:column;gap:9px',
    `${O.tx('The rift is sealed', { size: 19, weight: 800, ow: 4, sh: 2, grad: ['#fff', '#ff9ab2', '#ff2e63'] })}<span class="body">Reach 185 milestones to reveal the Prestige Multiverse.</span>
     <div style="display:flex;justify-content:space-between;font:600 14px Montserrat;color:#e6def3"><span>Need</span><b style="font:800 15px Sarpanch;color:#fff">185 <span class="nw">milestones</span></b></div>
     <div style="display:flex;justify-content:space-between;font:600 14px Montserrat;color:#e6def3"><span>Have</span><b style="font:800 15px Sarpanch;color:#fff">164 <span class="nw">milestones</span></b></div>
     <div style="display:flex;align-items:center;gap:10px"><div class="bar" style="flex:1"><i style="width:88%;background:linear-gradient(#fff,#ff9ab2 40%,#ff2e63);box-shadow:0 0 8px #ff2e63"></i></div><b style="font:800 15px Sarpanch">88%</b></div>`);
  // bottom: dock, zoom, READY gem shelf, the Multiverse portal
  O.dock(R, 16, 936);
  O.slice(R, 'plaque', 280, 1000, 150, 48, { k: 0.5 });
  O.abs(R, 280, 1000, 150, 48, 'display:flex;align-items:center;justify-content:space-between;padding:0 26px;box-sizing:border-box;font:800 18px Montserrat;color:#ffe9b0',
    `<span>−</span><span style="font:800 16px Sarpanch;color:#fff">51%</span><span>+</span>`);
  O.shelf(R, 1060, 912, 690, { title: '3 READY', sub: '· 4 can buy', gems: [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP'], ['p', 'P'], ['pe', 'PE'], ['sp', 'SP']], chips: ['+1', '+e4.84e8', '+1', 'BUY', 'BUY', 'BUY'] });
  const px = 1826, py = 936;
  O.abs(R, px - 56, py - 56, 112, 112, 'border-radius:50%;background:radial-gradient(circle at 50% 50%,#12040c 0%,#3a0a1e 45%,#ff2e63 78%,#5a0a24 100%);box-shadow:inset 0 0 30px #000');
  O.sprite(R, 'ring', px, py, 150, 150, { color: '#ff2e63', alpha: 0.7 });
  O.sprite(R, 'glow', px, py, 230, 230, { color: '#ff2e63', alpha: 0.35 });
  O.abs(R, px - 30, py - 30, 60, 60, 'display:grid;place-items:center', O.tx('?', { size: 44, font: 'num', ow: 6, sh: 3, grad: ['#fff', '#ffc2d1'] }));
  O.image(R, 'portal_ring', px, py, { k: 0.78 });
  O.slice(R, 'plaque', px - 94, 1010, 188, 60, { k: 0.55 });
  O.abs(R, px - 94, 1016, 188, null, 'display:flex;flex-direction:column;align-items:center;gap:3px',
    `${O.tx('MULTIVERSE', { size: 16, weight: 900, ow: 4, sh: 2, grad: ['#fff', '#ffc2d1'] })}<span style="font:800 13px Montserrat;color:#f2e6ee">SEALED <span class="nr">164/185</span></span>`);
};

// ------------------------------------------------------------------------------------------------ (f) phone 844 x 390
SCENES.f = async () => {
  const R = O.root(); R.style.cssText = 'width:844px;height:390px';
  O.abs(R, 0, 0, 844, 390, `background:url(${BG}phone_p.png) 0 0/844px 390px;filter:blur(4px) brightness(.5)`);
  const L = 'p', T = UI_THEMES[L], k = 0.5, X = 16, Y = 16, W = 812, H = 360;
  const F = PANEL.frame(R, L, X, Y, W, H, { k, crest: false, medalK: 1.1 });
  const c = F.content;
  O.abs(c, 58, 6, null, null, 'display:flex;align-items:center;gap:10px', O.tx('PRESTIGE', { size: 26, grad: ['#fff', T.hueHi, T.hue], ow: 5, sh: 3 }) + PANEL.subChip('ROW 1', L));
  // READY gems pill (the phone's READY switcher) left of the close gem
  O.slice(c, 'plaque', 546, 6, 200, 38, { k: 0.42 });
  [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP']].forEach(([g, l], i) => O.gem(c, g, 584 + i * 34, 25, 30, { letter: l }));
  O.abs(c, 676, 5, 60, 40, 'display:flex;align-items:center;gap:3px;font:800 14px Sarpanch;color:#ffe08a', `+4${O.icon('bolt', 12, '#ffd34d')}`);
  // left column: resource hero + CTA
  O.slice(c, 'toast', 10, 50, 222, 300, { k: 0.55 });
  O.sprite(c, 'glow', 120, 100, 300, 150, { color: T.hue, alpha: 0.3 });
  O.abs(c, 26, 64, 200, null, 'display:flex;flex-direction:column;gap:4px',
    O.caps('You have', '#d8d0ea', 12) + O.tx('e1.029e25', { size: 31, font: 'num', grad: ['#fff', T.hueHi, T.hue], ow: 5, sh: 3 }) + O.tx('PRESTIGE POINTS', { size: 16, grad: [T.hueHi, T.hueHi], ow: 3, sh: 2 }));
  PANEL.chip(c, 20, 160, 202, 'Points', 'e6.424e23', { h: 32 });
  PANEL.chip(c, 20, 198, 202, 'Passive', '+e1.073e25/s', { h: 32, valColor: '#9ff3b4' });
  PANEL.cta(c, L, 16, 250, 210, 86, { title: 'PRESTIGE', gain: '+e1.073e25 PP', k: 0.78 });
  // right column: tabs A, then the tier board (2 cards per row), scrolling
  PANEL.tabsA(c, L, 242, 50, 560, [{ label: 'Upgrades', w: 164, on: true, badge: '2' }, { label: 'Buyables', w: 150, badge: '1' }, { label: 'Perks', w: 100, dot: true }], { h: 38, font: 15 });
  const board = O.abs(c, 242, 94, 560, 256, 'overflow:hidden');
  O.abs(board, 0, 4, 560, 30, 'display:flex;align-items:center;gap:8px', `<span class="subchip">${O.icon('bolt', 12, '#ffd34d')}<span class="nr">2</span> READY</span><span class="subchip" style="box-shadow:inset 0 0 0 1.5px #4be07a,inset 0 0 0 3px #0c2a16,0 1px 3px #000"><span class="nr">14 / 16</span> OWNED</span><span style="flex:1"></span><span style="font:800 13px Montserrat;color:#ffe08a">Tiers 1–2 owned · Show ▾</span>`);
  PANEL.cardBuy(board, L, 4, 52, 268, 212, { n: 31, title: 'Prestige Scaling Reducer I', desc: 'Milestone Cost Scaling is weaker based on your prestige points.', cost: '1.00e6810 PP', pulse: 0.9 });
  PANEL.cardOwned(board, 286, 52, 268, 212, { n: 32, title: 'Prestige Scaling Reducer II', desc: 'Prestige Upgrade 31 is boosted.' });
  O.abs(c, 242, 324, 560, 26, 'background:linear-gradient(180deg,rgba(7,11,20,0),rgba(7,11,20,.9))');
  O.abs(c, 800, 100, 4, 240, 'border-radius:2px;background:rgba(255,255,255,.08)');
  O.abs(c, 800, 100, 4, 90, `border-radius:2px;background:${T.hue};box-shadow:0 0 5px ${T.hue}`);
};

// ------------------------------------------------------------------------------------------------ pieces sheet (2x)
SCENES.sheet = async () => {
  const W = 2400, H = 3000;
  const R = O.root(); R.style.cssText = `width:${W}px;height:${H}px;background:radial-gradient(ellipse at 30% 0%,#231a38,#0b0913 60%,#07060c)`;
  document.body.style.width = W + 'px';
  const head = (y, t, s) => O.abs(R, 60, y, W - 120, 60, 'display:flex;align-items:baseline;gap:18px;border-bottom:1px solid rgba(255,220,150,.18);padding-bottom:8px',
    O.tx(t, { size: 34, grad: ['#fff', '#ffe08a', '#ffc233'], ow: 5, sh: 3 }) + `<span style="font:600 18px Montserrat;color:#bdb3d3">${s}</span>`);
  const lab = (x, y, t) => O.abs(R, x, y, null, null, 'font:700 15px Montserrat;color:#a79fbd;letter-spacing:.04em', t);
  O.abs(R, 60, 34, null, null, '', O.tx('THE MILESTONE TREE NG+ · UI KIT', { size: 46, grad: ['#fff', '#e8dcff'], ow: 6, sh: 4 }) +
    `<div style="font:600 19px Montserrat;color:#c9c0dc;margin-top:10px">Cosmic ornate relic kit · pieces at 2x (native texture resolution) · gold + crystal rendered in Blender Cycles, fills / bodies / stone / VFX painted in canvas</div>`);
  let y = 150;
  for (const L of ['m', 'p', 'cp']) {
    const T = UI_THEMES[L];
    head(y, `${T.name} FRAME KIT`, `${T.motif} · hue ${T.hue}`);
    const y0 = y + 90;
    O.image(R, `corner_${L}_tl`, 60 + 100, y0 + 100, { k: 2 }); lab(60, y0 + 392, 'corner (anchor = frame corner)');
    O.image(R, `crest_${L}`, 520 + 160, y0 + 114, { k: 2 }); lab(520, y0 + 220, 'top gem crest');
    O.sprite(R, 'glow', 1000 + 128, y0 + 128, 300, 300, { color: T.hue, alpha: 0.35 });
    O.image(R, `medal_${L}`, 1000 + 128, y0 + 128, { k: 2 });
    O.abs(R, 1000 + 78, y0 + 78, 100, 100, 'display:grid;place-items:center', O.tx(T.sym, { size: T.sym.length > 1 ? 58 : 76, font: 'num', ow: 9, sh: 4 })); lab(1000, y0 + 270, 'emblem medallion');
    O.image(R, `socket_${L}`, 1300 + 64, y0 + 64, { k: 2 }); lab(1300, y0 + 140, 'buyable socket');
    O.slice(R, `tabA_${L}`, 1480, y0, 320, 96, { k: 2 }); lab(1480, y0 + 104, 'tab A active plate (9-slice)');
    O.slice(R, `tabB_${L}`, 1840, y0, 256, 96, { k: 2 }); lab(1840, y0 + 104, 'tab B active segment');
    O.slice(R, `btn_${L}`, 1480, y0 + 150, 512, 160, { k: 2 }); lab(1480, y0 + 318, 'primary button (9-slice, 512 x 160)');
    O.slice(R, `card_${L}`, 2040, y0 + 150, 192, 192, { k: 2 }); lab(2040, y0 + 350, 'buyable card plate');
    y += 520;
  }
  // relic cards composed (the P kit), scaled 2x
  head(y, 'RELIC CARD STATES', 'buyable socket glows · owned gilded + engraved seal · locked carved stone + chain + rune seal (shown 2x)');
  const cards = O.abs(R, 60, y + 110, 1200, 300, 'transform:scale(2);transform-origin:0 0');
  PANEL.cardBuy(cards, 'p', 16, 20, 224, 270, { n: 31, title: 'Prestige Scaling Reducer I', desc: 'Milestone Cost Scaling is weaker based on your prestige points.', cur: '1.9745x weaker', cost: '1.00e6810 PP', pulse: 1 });
  PANEL.cardOwned(cards, 262, 20, 224, 270, { n: 32, title: 'Prestige Scaling Reducer II', desc: 'Prestige Upgrade 31 is boosted.' });
  PANEL.cardLocked(cards, 508, 20, 224, 150, { n: 41, title: 'Prestige Boost V', req: 'Complete AP Challenge 4 19.7 times', chainY: 76 });
  PANEL.compactOwned(cards, 508, 190, 224, 68, { n: 11, title: 'Prestige Boost I', eff: '×e2.296e21' });
  // tabs composed, 2x
  const tabs = O.abs(R, 1560, y + 120, 400, 300, 'transform:scale(1.5);transform-origin:0 0');
  PANEL.tabsA(tabs, 'p', 0, 10, 520, [{ label: 'Upgrades', w: 200, on: true, badge: '2' }, { label: 'Buyables', w: 180, badge: '1' }, { label: 'Perks', w: 110 }]);
  PANEL.tabsB(tabs, 'p', 0, 110, 520, [{ label: 'Upgrades', on: true, badge: '2' }, { label: 'Buyables', badge: '1' }, { label: 'Perks' }]);
  PANEL.tabsA(tabs, 'cp', 0, 210, 520, [{ label: 'Corruptions', w: 200, on: true }, { label: 'Upgrades', w: 140 }, { label: 'Antivirus', w: 130 }]);
  lab(1560, y + 110, 'tabs A (engraved strip + lit gem plate) and B (relic bar + raised segment), 1.5x');
  y += 830;
  head(y, 'HUD + SHARED', 'plaque · coin · dock medallion · seals · sockets · close gem · portal ring · gem shelf · toast · chain · divider');
  const y1 = y + 100;
  O.slice(R, 'plaque', 60, y1, 700, 144, { k: 2 }); lab(60, y1 + 150, 'points plaque (9-slice)');
  O.image(R, 'coin', 860, y1 + 72, { k: 2 }); O.image(R, 'dock_medal', 1080, y1 + 96, { k: 2 });
  O.abs(R, 1040, y1 + 56, 80, 80, 'display:grid;place-items:center', O.icon('trophy', 64, '#ffc94d', 'filter:drop-shadow(0 0 10px #ffc94d) drop-shadow(0 3px 0 #000)'));
  O.image(R, 'seal_owned', 1280, y1 + 64, { k: 2 }); O.image(R, 'seal_locked', 1440, y1 + 80, { k: 2 }); O.image(R, 'socket_empty', 1600, y1 + 64, { k: 2 });
  O.image(R, 'close_btn', 1740, y1 + 64, { k: 2 });
  O.abs(R, 1880, y1 - 30, 400, 400, 'border-radius:50%;', '');
  O.sprite(R, 'glow', 2090, y1 + 170, 420, 420, { color: '#ff2e63', alpha: 0.3 });
  O.image(R, 'portal_ring', 2090, y1 + 170, { k: 2 });
  lab(860, y1 + 200, 'coin · dock medallion · owned seal · locked seal · socket · close gem');
  O.slice(R, 'shelf', 60, y1 + 240, 900, 176, { k: 2 }); lab(60, y1 + 424, 'READY gem shelf (9-slice)');
  O.slice(R, 'toast', 1000, y1 + 240, 420, 192, { k: 2 }); lab(1000, y1 + 440, 'toast / tooltip frame');
  O.tile(R, 'chain', 60, y1 + 480, 1024, 64, { k: 2 }); lab(60, y1 + 550, 'chain (tiles horizontally)');
  O.slice(R, 'divider', 1120, y1 + 480, 760, 64, { k: 2 }); lab(1120, y1 + 550, 'divider rod');
  O.slice(R, 'card_owned', 1460, y1 + 240, 192, 192, { k: 2 }); O.slice(R, 'card_locked', 1680, y1 + 240, 192, 192, { k: 2 });
  lab(1460, y1 + 440, 'owned plate · locked plate');
  // VFX atlas on black
  O.abs(R, 60, y1 + 600, 520, 520, 'background:#000;border:1px solid #332b44');
  O.image(R, 'glow9', -1000, -1000, {});
  O.el(R, 'img', 'position:absolute;left:64px;top:' + (y1 + 604) + 'px;width:512px;height:512px').src = '/ui/out/pieces/vfx.png';
  lab(600, y1 + 610, 'VFX atlas (1024², white sprites tinted in the client): sweep, flare, rings, glow, star, glint, streak, rim shimmer, ember, spark, 6 runes, stone + crystal shards, chain links');
  O.tile(R, 'tex_p', 600, y1 + 650, 540, 470); O.tile(R, 'tex_cp', 1160, y1 + 650, 540, 470); O.tile(R, 'tex_stone', 1720, y1 + 650, 300, 470, { style: 'background-color:#2e2a37' });
  lab(600, y1 + 1126, 'body textures (tile): P crystal facets · CR scanlines + data noise · stone');
};
