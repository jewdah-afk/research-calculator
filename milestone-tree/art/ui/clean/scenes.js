// scenes.js - the option boards. Every screen is 1920 x 1080 over the real painted realm (art/ui/out/bg):
//   CLEAN.panel(n)  the P panel docked beside the map strip, in style n (1 sleek sci-fi, 2 sharp, 3 soft premium, 4 frosted glass)
//   CLEAN.hud(n)    the home map with only the HUD, in style n
//   CLEAN.nodes()   node bodies compared: crystal gems vs clean icon discs, both with the energy ring, every state
//   CLEAN.board()   2 x 2 contact board of the four panel stills
//   CLEAN.clip*     the energy-ring clip (clip.js drives CLEAN.clipFrame(t))
const BG = '/ui/out/bg/';
const CLEAN = {};

// ------------------------------------------------------------------------------------------------ backgrounds
function realmHome(R) { K.abs(R, 0, 0, 1920, 1080, `background:url(${BG}home.png) 0 0/1920px 1080px`); }
// the game's docked layout: the map strip (760 px) beside the sheet; the sheet area shows the realm blurred + dimmed
function realmDocked(R, { blur = 9, dim = 0.42, hue = K.HUES.p } = {}) {
  K.abs(R, 0, 0, 1920, 1080, `background:url(${BG}wide_p.png) 0 0/1920px 1080px;filter:blur(${blur}px) brightness(${dim}) saturate(.85);transform:scale(1.02)`);
  K.abs(R, 0, 0, 1920, 1080, `background:radial-gradient(ellipse 55% 45% at 72% 8%,${K.rgba(hue, 0.12)},transparent 70%)`);
  K.abs(R, 0, 0, 760, 1080, `background:url(${BG}strip_p.png) 0 0/760px 1080px`);
  K.abs(R, 700, 0, 90, 1080, 'background:linear-gradient(90deg,rgba(5,3,10,0),rgba(5,3,10,.5))');
}
// the Roblox top-bar buttons (not ours): the HUD keeps clear of them
function robloxBar(R) {
  for (const [x, t] of [[16, 'RBX'], [70, 'chat']]) K.abs(R, x, 12, 44, 44, 'border-radius:50%;background:rgba(10,8,16,.55);display:grid;place-items:center;font:700 11px Montserrat;color:#aaa', t);
}

// ------------------------------------------------------------------------------------------------ nodes on a view
function mapNodes(R, view, geo, keys, { mode = 'gem', t = 0.3, sel = null, label = null, ox = 0, oy = 0, w = 1920, h = 1080 } = {}) {
  const nodes = K.nodesFor(view, keys).map((n, i) => Object.assign(n, { x: n.x - ox, y: n.y - oy, sel: n.key === sel, off: n.st === 'buy' ? i * 0.41 : 0 }));
  const cv = K.canvas(R, 0, 0, w, h), ctx = cv.getContext('2d');
  for (const n of nodes) K.drawNode(ctx, n, mode, geo, t + n.off);
  if (label) for (const n of nodes) if (n.name || n.st === 'locked') label(R, n, n.x, n.y + geo.rSock + (geo.labelGap != null ? geo.labelGap : 10) * geo.k);
  return { nodes, cv, ctx };
}

// ------------------------------------------------------------------------------------------------ the P panel (content shared by all styles)
const P = {
  title: 'PRESTIGE', row: 'Row 1', sub: 'Resets for prestige points', sym: 'P',
  tabs: [{ label: 'Upgrades', on: true, badge: '2' }, { label: 'Buyables', badge: '1' }, { label: 'Perks', dot: true }],
  ready: '2', owned: '14 / 16',
  hero: { cap: 'You have', amt: 'e1.029e25', res: 'Prestige points' },
  cta: { title: 'PRESTIGE', gain: '+e1.073e25 PP', key: 'P' },
  chips: [['Points', 'e6.424e23', null], ['Passive', '+e1.073e25/s', 'good']],
  summary: { label: 'Tiers 1 – 2', count: '8 / 8', names: 'Prestige Boost I – IV  ·  Exponental Boost I – II  ·  Self-Synergy I – II' },
  tier3: { label: 'Tier 3', count: '2 / 4 owned' },
  tier4: { label: 'Tier 4', count: 'Locked' },
  cards: [
    { n: 31, st: 'buy', title: 'Prestige Scaling Reducer I', desc: 'Milestone Cost Scaling is weaker based on your prestige points.', cur: '1.9745x weaker', cost: '1.00e6810 PP' },
    { n: 32, st: 'owned', title: 'Prestige Scaling Reducer II', desc: 'Prestige Upgrade 31 is boosted.' },
    { n: 33, st: 'owned', title: 'Prestige Scaling Reducer III', desc: 'Prestige Upgrade 31 is boosted.' },
    { n: 34, st: 'buy', title: 'Prestige Scaling Reducer IV', desc: 'Prestige Upgrade 31 is boosted.', cost: '1e16,335 PP' },
  ],
  locked: [
    { n: 41, st: 'locked', title: 'Prestige Boost V', req: 'Complete AP Challenge 4 19.7 times' },
    { n: 42, st: 'locked', title: 'Prestige Boost VI', req: 'Complete AP Challenge 3 14.1 times' },
    { n: 43, st: 'locked', title: 'Prestige Buyable Boost I', req: 'Buy while in T Challenge 2' },
    { n: 44, st: 'locked', title: 'Prestige Buyable Boost II', req: 'Buy while in T Challenge 4' },
  ],
};
// the HUD content
const HUD = {
  points: { cap: 'Points · Normal Universe', amt: 'e6.424e23', unit: 'points', rate: '+6.21e24 OOMs/sec' },
  dock: [['home', 'Home'], ['trophy', 'Trophies', '13/18'], ['gear', 'Options']],
  tray: { title: '3 ready', sub: '4 can buy', items: [['mm', 'MM', '+1', 'ready'], ['ep', 'EP', '+e4.84e8', 'ready'], ['mp', 'MP', '+1', 'ready'], ['p', 'P', 'Buy', 'buy'], ['pe', 'PE', 'Buy', 'buy'], ['sp', 'SP', 'Buy', 'buy']] },
  toast: { title: 'Milestone Gotten!', chip: '×10', sub: '18th – 27th Meta-Milestone' },
};
const STRIP_KEYS = ['sp', 'pb', 'p', 'm', 'mm', 'em'];

CLEAN.panel = async n => {
  const R = K.root(); R.style.cssText = 'width:1920px;height:1080px';
  const S = STYLES[n];
  realmDocked(R, S.backdrop || {});
  mapNodes(R, K.STRIP, K.GEO.strip, STRIP_KEYS, { mode: 'gem', sel: 'p', label: (R, nd, x, y) => S.nodeLabel(R, nd, x, y, 1.1) });
  robloxBar(R);
  S.hudStrip(R, HUD);
  S.panel(R, P, { x: 800, y: 66, w: 1072, h: 958 });
};
CLEAN.hud = async n => {
  const R = K.root(); R.style.cssText = 'width:1920px;height:1080px';
  const S = STYLES[n];
  realmHome(R);
  mapNodes(R, K.HOME, K.GEO.home, null, { mode: 'gem', label: (R, nd, x, y) => S.nodeLabel(R, nd, x, y, 1) });
  robloxBar(R);
  S.hudHome(R, HUD);
};

// ------------------------------------------------------------------------------------------------ node comparison
function neutralLabel(R, n, x, y) {
  const hue = K.HUES[n.key], locked = n.st === 'locked';
  if (!n.name) return;
  K.abs(R, x - 90, y, 180, null, 'display:flex;justify-content:center', `<div style="display:flex;flex-direction:column;align-items:center;gap:3px;padding:5px 10px 6px;border-radius:6px;background:rgba(8,10,18,.72);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)">
    ${K.caps(n.name, { size: 12, color: locked ? '#c9c3d6' : '#ffffff', weight: 800, track: 0.1 })}
    <span class="row" style="gap:4px;font:700 14px/1 Sarpanch;color:${locked ? '#c9c3d6' : K.lift(hue, 0.45)}">${locked ? K.icon('lock', 12, '#c9c3d6', { sw: 2.2 }) : ''}${K.nf(n.value)}</span></div>`);
}
CLEAN.nodes = async () => {
  const R = K.root(); R.style.cssText = 'width:1920px;height:1160px;background:#07070c';
  const keys = K.WORLD.filter(n => n.key !== 'ach').map(n => n.key), X0 = 350;
  for (const [side, mode, title, sub] of [[0, 'gem', 'A · Crystal gems', 'Blender gem sprites + energy ring'], [1, 'icon', 'B · Clean icons', 'Letter discs + energy ring']]) {
    const H = K.abs(R, side * 960, 0, 960, 1080, 'overflow:hidden');
    K.abs(H, -X0, 0, 1920, 1080, `background:url(${BG}home.png) 0 0/1920px 1080px`);
    mapNodes(H, K.HOME, K.GEO.home, keys, { mode, ox: X0, w: 960, label: neutralLabel });
    K.abs(H, 28, 24, null, null, 'display:flex;flex-direction:column;gap:6px;padding:14px 18px 15px;border-radius:10px;background:rgba(7,8,14,.78);box-shadow:inset 0 0 0 1px rgba(255,255,255,.1)',
      `<span style="font:italic 900 26px/1 Montserrat;color:#fff">${title}</span><span style="font:600 14px/1 Montserrat;color:#c9cfdb">${sub}</span>`);
  }
  K.abs(R, 959, 0, 2, 1080, 'background:rgba(255,255,255,.35);box-shadow:0 0 0 1px rgba(0,0,0,.5)');
  // legend: the four states and which real nodes show them
  const L = [['locked', 'Locked', 'dim + still', 'HB · PB · ?'], ['idle', 'Idle', 'slow breathe', 'T · AP · HP · PP · M'], ['buy', 'Can buy', 'flicker + comet', 'P · SP · SE · PE'], ['ready', 'Ready', 'fast pulse + ⚡', 'MM · EP · MP']];
  K.abs(R, 0, 1080, 1920, 1, 'background:rgba(255,255,255,.14)');
  const lg = K.abs(R, 0, 1081, 1920, 79, 'display:flex;align-items:center;justify-content:center;gap:64px');
  K.el(lg, 'div', '', K.caps('Energy ring states', { size: 13, color: '#8f98aa', weight: 800 }));
  L.forEach(([st, name, what, who], i) => {
    const cell = K.el(lg, 'div', 'display:flex;align-items:center;gap:12px');
    const c = K.el(cell, 'canvas', 'width:56px;height:56px'); c.width = 56; c.height = 56;
    const cx = c.getContext('2d'); K.drawIconNode(cx, { key: 'p', letter: 'P', st }, 28, 28, 13, K.ringState(st, 0.3), 0.6);
    K.drawRing(cx, 28, 28, 19, K.HUES.p, st, st === 'buy' ? 0.55 : 0.3, 0.7);
    if (st === 'ready') K.drawBolt(cx, 42, 14, 6);
    K.el(cell, 'div', 'display:flex;flex-direction:column;gap:5px', `<span class="row" style="gap:8px">${K.caps(name, { size: 13, color: '#fff', weight: 800 })}<span style="font:600 13px Montserrat;color:#c9cfdb">${what}</span></span><span style="font:700 13px Montserrat;color:#9ea7b8">${who}</span>`);
  });
};

// ------------------------------------------------------------------------------------------------ contact board
CLEAN.board = async () => {
  const W = 2560, H = 1440, R = K.root(); R.style.cssText = `width:${W}px;height:${H}px;background:#08070d`;
  const names = ['Sleek sci-fi', 'Sharp', 'Soft premium', 'Frosted glass'], refs = ['Destiny 2', 'Valorant / Apex', 'Honkai: Star Rail', 'visionOS'];
  for (let i = 0; i < 4; i++) {
    const x = (i % 2) * 1280, y = Math.floor(i / 2) * 720;
    const im = K.el(R, 'img', `position:absolute;left:${x}px;top:${y}px;width:1280px;height:720px`); im.src = `/ui/clean/out/style${i + 1}_p_panel.png`;
    K.abs(R, x + 20, y + 640, null, null, 'display:flex;align-items:center;gap:14px;padding:10px 20px 10px 10px;border-radius:12px;background:rgba(6,7,12,.88);box-shadow:0 6px 20px rgba(0,0,0,.5),inset 0 0 0 1px rgba(255,255,255,.14)',
      `<span style="display:grid;place-items:center;width:44px;height:44px;border-radius:9px;background:#fff;font:900 26px Sarpanch;color:#0b0d14">${i + 1}</span>
       <span style="display:flex;flex-direction:column;gap:5px"><span style="font:italic 900 24px/1 Montserrat;color:#fff">${names[i].toUpperCase()}</span><span style="font:600 14px/1 Montserrat;color:#c9cfdb">after ${refs[i]}</span></span>`);
  }
  K.abs(R, 1279, 0, 2, H, 'background:#000'); K.abs(R, 0, 719, W, 2, 'background:#000');
};
