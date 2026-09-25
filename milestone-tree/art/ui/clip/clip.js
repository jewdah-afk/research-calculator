// clip.js - the prestige clip: sample (a) animated by a pure function of time. CLIP.setup() builds the scene from
// the kit (samples/scenes.js prestigePanel) plus every VFX sprite it will ever need (seeded emitters, no pooling),
// CLIP.frame(t) poses everything for time t (so any frame can be rendered in any order). The timeline and its sounds
// are in CLIP.EVENTS (record.js mixes the same list into the audio track).
const CLIP = (() => {
  const C = {};
  const clamp = (x, a = 0, b = 1) => x < a ? a : x > b ? b : x;
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  const eo = x => 1 - Math.pow(1 - x, 3);                         // ease out cubic
  const eio = x => x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  const back = x => { const c1 = 1.7, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); };
  const bump = (t, a, p, b) => t <= a || t >= b ? 0 : t < p ? eo((t - a) / (p - a)) : 1 - eio((t - p) / (b - p));
  // times (s)
  const T = { open: 0.0, hover: 0.78, buy: 1.3, unlock: 2.05, press1: 2.7, big: 3.0, press2: 4.55, small: 4.7, end: 6.0 };
  C.T = T;
  C.DURATION = 6.0;
  C.EVENTS = [['panel_open', 0.0], ['hover', 0.76], ['press', 1.28], ['buy', 1.30], ['unlock', 2.05], ['press', 2.68], ['prestige_big', 2.70],
    ['press', 4.53], ['prestige_small', 4.55]];

  let S = null;
  const HUE = UI_THEMES.p.hue, HI = UI_THEMES.p.hueHi;

  function mk(parent, name, w, h, color = '#fff', add = true) {
    const e = O.sprite(parent, name, w / 2, h / 2, w, h, { color, alpha: 0, add });
    return { e, w, h };
  }
  function mkRaw(parent, name, w, h) { const e = O.spriteRaw(parent, name, w / 2, h / 2, w, h); e.style.opacity = 0; return { e, w, h }; }
  function put(p, x, y, s = 1, rot = 0, a = 1) {
    p.e.style.transform = `translate(${x - p.w / 2}px,${y - p.h / 2}px) rotate(${rot}deg) scale(${s})`;
    p.e.style.opacity = a <= 0.002 ? 0 : a;
  }
  // a seeded burst: every particle is an element with fixed parameters
  function burst(parent, seed, t0, o) {
    const R = rng(seed), out = [];
    for (let i = 0; i < o.n; i++) {
      const name = typeof o.name === 'function' ? o.name(i, R) : o.name;
      const sz = o.size[0] + R() * (o.size[1] - o.size[0]);
      const p = o.raw ? mkRaw(parent, name, sz * (o.aspect || 1), sz) : mk(parent, name, sz * (o.aspect || 1), sz, typeof o.color === 'function' ? o.color(i, R) : o.color);
      const a = (o.dir != null ? o.dir : 0) + (R() - 0.5) * (o.spread != null ? o.spread : Math.PI * 2);
      const sp = o.speed[0] + R() * (o.speed[1] - o.speed[0]);
      const x0 = o.x + (o.jx ? (R() - 0.5) * o.jx : 0), y0 = o.y + (o.jy ? (R() - 0.5) * o.jy : 0);
      out.push({ p, t0: t0 + (o.stagger ? R() * o.stagger : 0), x0, y0, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: o.life[0] + R() * (o.life[1] - o.life[0]),
        drag: o.drag || 2, g: o.grav || 0, rot0: R() * 360, spin: (R() - 0.5) * (o.spin || 0), shrink: o.shrink != null ? o.shrink : 0.6, fade: o.fade || 0.5 });
    }
    return out;
  }
  function poseBurst(list, t) {
    for (const q of list) {
      const dt = t - q.t0;
      if (dt < 0 || dt > q.life) { q.p.e.style.opacity = 0; continue; }
      const k = (1 - Math.exp(-q.drag * dt)) / q.drag;
      const x = q.x0 + q.vx * k, y = q.y0 + q.vy * k + 0.5 * q.g * dt * dt;
      const u = dt / q.life;
      put(q.p, x, y, 1 - q.shrink * u, q.rot0 + q.spin * dt, u < 1 - q.fade ? 1 : (1 - u) / q.fade);
    }
  }

  C.setup = async () => {
    const R = O.root(); R.style.cssText = 'width:1920px;height:1080px';
    const stage = O.abs(R, 0, 0, 1920, 1080, 'transform-origin:1400px 420px');
    mapStrip(stage, 'p', { strip: 'strip_p.png', wide: 'wide_p.png', C: [1500, 1640], nodes: P_NODES, hud: { shelf: { gems: [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP']] } } });
    const mapFx = O.abs(stage, 0, 0, 1920, 1080, 'pointer-events:none');
    const P = prestigePanel(stage, { tabs: 'A', buyPulse: 0.8 });
    const g = P.F.g, pc = P.c;
    g.style.transformOrigin = `${PX0 + PW / 2}px ${PY0 + PH / 2}px`;
    const X = PX0, Y = PY0;
    const c31 = P.cards[31], c41 = P.cards[41];
    const r3 = P.rows.r3, r4 = P.rows.r4, cxs = P.cx;
    // the owned version of 31 and the unlocked (buyable) version of 41 wait underneath
    const o31 = PANEL.cardOwned(pc, cxs(0), r3, P.CW, 270, { n: 31, title: 'Prestige Scaling Reducer I', desc: 'Milestone Cost Scaling is weaker based on your prestige points.', eff: '1.9745x weaker' });
    o31.style.opacity = 0;
    pc.insertBefore(o31, c31);
    const b41 = PANEL.cardBuy(pc, 'p', cxs(0), r4, P.CW, 150, { n: 41, title: 'Prestige Boost V', desc: '', cost: 'e1.52e25 PP', pulse: 1 });
    b41.style.opacity = 0;
    const seal31 = o31.querySelector('img[src*="seal_owned"]');
    const fx = O.abs(stage, 0, 0, 1920, 1080, 'pointer-events:none');
    // open sweep, clipped to the panel
    const clip = O.abs(fx, X + 12, Y + 12, PW - 24, PH - 24, 'overflow:hidden');
    const sweep = mk(clip, 'sweep', 260, 1500, '#ffffff');
    const shimmer = mk(fx, 'shimmer', 420, 22, '#ffffff');
    const shimmerB = mk(fx, 'shimmer', 420, 22, HI);
    // key points (screen)
    const s31 = [X + cxs(0) + P.CW / 2, Y + r3 + 2], k31 = [X + cxs(0) + P.CW / 2, Y + r3 + 135];
    const L41 = [X + cxs(0), Y + r4], ch41 = [X + cxs(0) + P.CW / 2, Y + r4 + 76];
    const cta = [X + PW - 44 - 205, Y + 172 + 52];
    const node = [380, (1580 - 1640) * 0.9 + 540];
    // buy flare
    const buyFlare = mk(fx, 'flare', 520, 90, HI), buyRing = mk(fx, 'ring', 300, 300, HI), buyGlint = mk(fx, 'glint', 110, 110, '#ffffff');
    const buySparks = burst(fx, 11, T.buy + 0.03, { n: 18, name: 'spark', size: [14, 30], color: (i, R) => R() < 0.5 ? '#ffffff' : HI, x: s31[0], y: s31[1], speed: [220, 560], life: [0.4, 0.8], drag: 3.2, grav: 320 });
    // unlock
    const rune = mk(fx, 'rune0', 120, 120, '#c9b8ff'), runeGlow = mk(fx, 'glow', 260, 260, '#b9a8ff'), unlockFlash = mk(fx, 'glow', 420, 260, '#ffffff');
    const links = burst(fx, 21, T.unlock + 0.07, { n: 10, raw: true, name: (i) => i % 2 ? 'link' : 'link_half', size: [22, 30], aspect: 1.3, x: ch41[0], y: ch41[1], jx: P.CW, jy: 6,
      speed: [260, 620], dir: -Math.PI / 2, spread: 2.6, life: [0.7, 1.0], drag: 1.2, grav: 1500, spin: 900, shrink: 0.1, fade: 0.3 });
    const stones = burst(fx, 22, T.unlock + 0.07, { n: 14, raw: true, name: (i) => 'shard_stone' + (i % 6), size: [14, 30], x: ch41[0], y: ch41[1], jx: 60, jy: 30,
      speed: [240, 700], dir: -Math.PI / 2, spread: 3.2, life: [0.6, 0.95], drag: 1.4, grav: 1700, spin: 700, shrink: 0.2, fade: 0.3 });
    const runeSparks = burst(fx, 23, T.unlock + 0.05, { n: 16, name: 'spark', size: [12, 26], color: '#d9ccff', x: ch41[0], y: ch41[1], speed: [200, 520], life: [0.35, 0.7], drag: 3, grav: 200 });
    // big prestige
    const flash = O.abs(R, 0, 0, 1920, 1080, `background:radial-gradient(ellipse at ${cta[0]}px ${cta[1]}px,#ffffff,${HI} 35%,${HUE} 70%,rgba(0,0,0,0));mix-blend-mode:plus-lighter;opacity:0`);
    const ring1 = mk(fx, 'ring', 1000, 1000, HI), ring2 = mk(fx, 'ring_thin', 1000, 1000, '#ffffff'), bigFlare = mk(fx, 'flare', 1800, 200, '#ffffff'), bigGlow = mk(fx, 'glow', 800, 800, HUE);
    const charge = burst(fx, 30, T.press1 + 0.02, { n: 14, name: 'spark', size: [12, 22], color: HI, x: cta[0], y: cta[1], speed: [0, 0], life: [0.28, 0.3] });
    charge.forEach((q, i) => { const a = i / charge.length * Math.PI * 2; q.ang = a; q.r0 = 150 + (i % 3) * 30; });
    const shards = burst(fx, 31, T.big, { n: 26, name: (i) => 'shard_crystal' + (i % 4), size: [30, 60], color: (i, R) => R() < 0.3 ? '#ffffff' : R() < 0.6 ? HI : HUE, x: cta[0], y: cta[1],
      speed: [600, 1300], life: [0.9, 1.35], drag: 2.2, grav: 700, spin: 800, shrink: 0.3, fade: 0.4 });
    const sparks = burst(fx, 32, T.big, { n: 46, name: 'spark', size: [14, 34], color: (i, R) => R() < 0.4 ? '#ffffff' : HI, x: cta[0], y: cta[1], speed: [300, 1500], life: [0.5, 1.1], drag: 3, grav: 380 });
    const stars = [[X, Y], [X + PW, Y], [X, Y + PH], [X + PW, Y + PH], [X + PW / 2, Y + 6]].map(() => mk(fx, 'star', 170, 170, '#ffffff'));
    const nodeRing = mk(mapFx, 'ring', 400, 400, HI), nodeGlow = mk(mapFx, 'glow', 360, 360, HUE);
    const banner = O.abs(fx, X, Y + 380, PW, 200, 'display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;opacity:0',
      O.tx('PRESTIGE!', { size: 112, grad: ['#ffffff', HI, HUE], ow: 12, sh: 7 }) +
      `<div style="display:flex;align-items:center;gap:12px">${O.tx('FIRST PRESTIGE', { size: 26, grad: ['#fff3c4', '#ffc233'], ow: 5, sh: 3 })}<span style="font:800 20px Montserrat;color:#fff;text-shadow:0 2px 0 #000">·</span>${O.tx('+e1.073e25 PP', { size: 26, font: 'num', ow: 5, sh: 3 })}</div>`);
    const bannerFlare = mk(fx, 'flare', 1500, 160, HI);
    // residual
    const ringS = mk(fx, 'ring', 1000, 1000, HI), glowS = mk(fx, 'glow', 500, 500, HUE);
    const sparksS = burst(fx, 41, T.small, { n: 16, name: 'spark', size: [12, 26], color: (i, R) => R() < 0.5 ? '#ffffff' : HI, x: cta[0], y: cta[1], speed: [240, 800], life: [0.4, 0.8], drag: 3, grav: 300 });
    const shardsS = burst(fx, 42, T.small, { n: 8, name: (i) => 'shard_crystal' + (i % 4), size: [24, 42], color: HI, x: cta[0], y: cta[1], speed: [400, 800], life: [0.6, 0.9], drag: 2.4, grav: 600, spin: 600 });
    const floatTx = O.abs(fx, cta[0] - 200, cta[1] - 30, 400, 60, 'display:grid;place-items:center;opacity:0', O.tx('+e1.073e25 PP', { size: 30, font: 'num', ow: 5, sh: 3, grad: ['#fff', HI] }));
    // cursor (the Roblox arrow)
    const cursor = O.abs(R, 0, 0, 34, 40, '', `<svg viewBox="0 0 34 40" width="34" height="40"><path d="M3 2 L3 32 L11 25 L17 38 L23 35 L17 23 L28 23 Z" fill="#fff" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/></svg>`);
    S = { stage, g, gGlow: g.children[1], gPanel: g.children[2], c31, o31, seal31, c41, b41, fx, sweep, shimmer, shimmerB, buyFlare, buyRing, buyGlint, buySparks, rune, runeGlow, unlockFlash,
      links, stones, runeSparks, flash, ring1, ring2, bigFlare, bigGlow, charge, shards, sparks, stars, nodeRing, nodeGlow, banner, bannerFlare, ringS, glowS, sparksS, shardsS, floatTx,
      cursor, hero: P.hero, cta: P.cta, s31, k31, ch41, ctaP: cta, node, X, Y, cornersXY: [[X, Y], [X + PW, Y], [X, Y + PH], [X + PW, Y + PH], [X + PW / 2, Y + 6]] };
  };

  const heroHTML = (amt) => O.caps('YOU HAVE', '#d8d0ea', 13) + O.tx(amt, { size: 58, font: 'num', grad: ['#ffffff', HI, HUE], ow: 7, sh: 5 }) +
    `<div style="margin-top:4px">${O.tx('PRESTIGE POINTS', { size: 22, grad: [HI, HI], ow: 4, sh: 2 })}</div>`;
  let lastHero = '';

  C.frame = (t) => {
    const s = S;
    // ---- panel open: rise + scale + fade, light sweep, rim shimmer
    const o = eo(seg(t, 0.0, 0.42));
    s.g.style.transform = `translateY(${(1 - o) * 26}px) scale(${0.965 + 0.035 * o})`;
    s.g.style.opacity = o;
    put(s.sweep, -300 + (PW + 600) * eio(seg(t, 0.14, 0.8)), PH / 2, 1, 18, 0.55 * bump(t, 0.14, 0.4, 0.8));
    const sh1 = seg(t, 0.35, 1.05), sh2 = seg(t, 5.15, 5.95);
    put(s.shimmer, s.X + PW * eio(sh1), s.Y + 6, 1, 0, 0.9 * bump(t, 0.35, 0.6, 1.05));
    put(s.shimmerB, s.X + PW * eio(sh2), s.Y + 6, 1, 0, 0.8 * bump(t, 5.15, 5.45, 5.95));
    // ---- cursor path
    const path = [[0.4, 1990, 1000], [0.8, s.k31[0] + 40, s.k31[1] + 30], [1.95, s.k31[0] + 40, s.k31[1] + 30], [2.5, s.ctaP[0] + 60, s.ctaP[1] + 26], [6.0, s.ctaP[0] + 60, s.ctaP[1] + 26]];
    let cx = path[0][1], cy = path[0][2];
    for (let i = 0; i < path.length - 1; i++) if (t >= path[i][0] && t <= path[i + 1][0]) { const u = eio(seg(t, path[i][0], path[i + 1][0])); cx = path[i][1] + (path[i + 1][1] - path[i][1]) * u; cy = path[i][2] + (path[i + 1][2] - path[i][2]) * u; }
    if (t > path[path.length - 1][0]) { cx = path[path.length - 1][1]; cy = path[path.length - 1][2]; }
    const press = Math.max(bump(t, 1.26, 1.3, 1.4), bump(t, 2.66, 2.7, 2.8), bump(t, 4.51, 4.55, 4.65));
    s.cursor.style.transform = `translate(${cx}px,${cy}px) scale(${1 - 0.15 * press})`;
    s.cursor.style.opacity = t < 0.4 ? 0 : 1;
    // ---- hover lift on 31 (then it becomes owned)
    const lift = eo(seg(t, T.hover, T.hover + 0.18)) * (1 - eo(seg(t, 1.55, 1.85)));
    s.c31.style.transform = `translateY(${-9 * lift}px) scale(${1 + 0.02 * lift})`;
    s.c31.style.filter = `brightness(${1 + 0.12 * lift + 0.5 * bump(t, T.buy, T.buy + 0.06, T.buy + 0.4)})`;
    s.c31.refs.glow.style.opacity = 0.65 + 0.35 * lift + 0.3 * Math.sin(t * 6) * (1 - lift);
    const xf = eio(seg(t, 1.45, 1.68));
    s.c31.style.opacity = 1 - xf;
    s.o31.style.opacity = xf;
    s.o31.style.transform = `translateY(${-9 * lift}px)`;
    if (s.seal31) s.seal31.style.transform = `scale(${1 + 0.7 * (1 - back(seg(t, 1.5, 1.8)))})`;
    // ---- buy: socket flare
    const bf = bump(t, T.buy + 0.02, T.buy + 0.1, T.buy + 0.55);
    put(s.buyFlare, s.s31[0], s.s31[1] - 9 * lift, 0.3 + 0.9 * eo(seg(t, T.buy, T.buy + 0.3)), 0, bf);
    const br = seg(t, T.buy + 0.02, T.buy + 0.55);
    put(s.buyRing, s.s31[0], s.s31[1] - 9 * lift, 0.15 + 0.95 * eo(br), 0, br > 0 && br < 1 ? (1 - br) * 0.9 : 0);
    put(s.buyGlint, s.s31[0] - 8, s.s31[1] - 16, 0.5 + 0.9 * bf, t * 90, bf);
    poseBurst(s.buySparks, t);
    // ---- unlock: rune flares, chain + seal shatter, stone -> crystal plate
    const ru = seg(t, T.unlock, T.unlock + 0.5);
    put(s.rune, s.ch41[0], s.ch41[1], 1 + 1.4 * eo(ru), 0, ru > 0 && ru < 1 ? (1 - ru) : 0);
    put(s.runeGlow, s.ch41[0], s.ch41[1], 1, 0, 0.9 * bump(t, T.unlock, T.unlock + 0.07, T.unlock + 0.5));
    put(s.unlockFlash, s.ch41[0], s.ch41[1] - 20, 1, 0, 0.8 * bump(t, T.unlock + 0.05, T.unlock + 0.1, T.unlock + 0.35));
    const gone = t >= T.unlock + 0.07;
    if (s.c41.refs) { s.c41.refs.chain.style.opacity = gone ? 0 : 1; s.c41.refs.seal.style.opacity = gone ? 0 : 1; s.c41.refs.glow.style.opacity = gone ? 0 : 0.35 + 0.6 * bump(t, T.unlock - 0.2, T.unlock, T.unlock + 0.07); }
    poseBurst(s.links, t); poseBurst(s.stones, t); poseBurst(s.runeSparks, t);
    const ux = eio(seg(t, T.unlock + 0.15, T.unlock + 0.45));
    s.c41.style.opacity = 1 - ux; s.b41.style.opacity = ux;
    s.b41.style.transform = `scale(${1 + 0.05 * bump(t, T.unlock + 0.15, T.unlock + 0.3, T.unlock + 0.6)})`;
    // ---- CTA charge + big prestige
    const chg = seg(t, T.press1, T.big);
    s.cta.glow.style.opacity = 0.4 + 0.6 * eo(chg) * (1 - seg(t, T.big + 0.1, T.big + 0.8)) + 0.6 * bump(t, T.small - 0.1, T.small, T.small + 0.5);
    s.cta.btn.style.filter = `brightness(${1 + 0.5 * eo(chg) * (1 - seg(t, T.big, T.big + 0.4)) + 0.3 * bump(t, T.press2, T.small, T.small + 0.4)})`;
    s.cta.btn.style.transform = `scale(${1 - 0.03 * press})`;
    for (const q of s.charge) {
      const u = seg(t, T.press1 + 0.02, T.big);
      if (u <= 0 || u >= 1) { q.p.e.style.opacity = 0; continue; }
      const r = q.r0 * (1 - eio(u)), a = q.ang + u * 2.5;
      put(q.p, s.ctaP[0] + Math.cos(a) * r, s.ctaP[1] + Math.sin(a) * r * 0.6, 0.6 + 0.6 * u, 0, Math.min(1, u * 4));
    }
    s.flash.style.opacity = 0.62 * bump(t, T.big - 0.01, T.big + 0.03, T.big + 0.32);
    const w1 = seg(t, T.big, T.big + 0.85), w2 = seg(t, T.big + 0.08, T.big + 0.9);
    put(s.ring1, s.ctaP[0], s.ctaP[1], 0.06 + 2.6 * eo(w1), 0, w1 > 0 && w1 < 1 ? Math.pow(1 - w1, 1.3) : 0);
    put(s.ring2, s.ctaP[0], s.ctaP[1], 0.05 + 1.9 * eo(w2), 0, w2 > 0 && w2 < 1 ? 0.8 * (1 - w2) : 0);
    put(s.bigFlare, s.ctaP[0], s.ctaP[1], 0.2 + 1.0 * eo(seg(t, T.big, T.big + 0.25)), 0, bump(t, T.big, T.big + 0.05, T.big + 0.45));
    put(s.bigGlow, s.ctaP[0], s.ctaP[1], 1, 0, 0.9 * bump(t, T.big - 0.05, T.big + 0.05, T.big + 0.9));
    poseBurst(s.shards, t); poseBurst(s.sparks, t);
    s.cornersXY.forEach(([x, y], i) => put(s.stars[i], x, y, 0.4 + 0.8 * bump(t, T.big + 0.05 + 0.04 * i, T.big + 0.15 + 0.04 * i, T.big + 0.6 + 0.04 * i), t * 60 + i * 20,
      bump(t, T.big + 0.05 + 0.04 * i, T.big + 0.15 + 0.04 * i, T.big + 0.6 + 0.04 * i)));
    // frame flare (both prestiges; the later one is the residual version)
    const ff = bump(t, T.big, T.big + 0.08, T.big + 0.95), fs = bump(t, T.small, T.small + 0.06, T.small + 0.55);
    s.gGlow.style.opacity = 0.16 + 0.8 * ff + 0.35 * fs;
    s.gPanel.style.filter = `brightness(${1 + 0.9 * bump(t, T.big, T.big + 0.05, T.big + 0.45) + 0.35 * fs})`;
    // camera punch-in + shake (first prestige only)
    const pin = t < T.big ? 0 : t < T.big + 0.08 ? eo(seg(t, T.big, T.big + 0.08)) : 1 - eo(seg(t, T.big + 0.08, T.big + 0.75));
    const shk = (1 - seg(t, T.big, T.big + 0.4)) * (t >= T.big ? 1 : 0);
    s.stage.style.transform = `translate(${Math.sin(t * 91) * 6 * shk}px,${Math.cos(t * 77) * 5 * shk}px) scale(${1 + 0.035 * pin})`;
    // map node pulse
    const np = seg(t, T.big + 0.05, T.big + 0.8);
    put(s.nodeRing, s.node[0], s.node[1], 0.25 + 0.8 * eo(np), 0, np > 0 && np < 1 ? 1 - np : 0);
    put(s.nodeGlow, s.node[0], s.node[1], 1, 0, 0.8 * bump(t, T.big, T.big + 0.1, T.big + 1.0));
    // banner
    const bi = seg(t, T.big + 0.02, T.big + 0.24), bo = seg(t, T.big + 0.85, T.big + 1.15);
    s.banner.style.opacity = t < T.big ? 0 : Math.min(1, bi * 2) * (1 - bo);
    s.banner.style.transform = `scale(${1.4 - 0.4 * back(bi)}) translateY(${-20 * bo}px)`;
    put(s.bannerFlare, s.X + PW / 2, s.Y + 470, 0.3 + 0.9 * eo(bi), 0, 0.9 * bump(t, T.big + 0.02, T.big + 0.12, T.big + 0.8));
    // residual prestige
    const rs = seg(t, T.small, T.small + 0.55);
    put(s.ringS, s.ctaP[0], s.ctaP[1], 0.06 + 0.95 * eo(rs), 0, rs > 0 && rs < 1 ? 0.85 * Math.pow(1 - rs, 1.2) : 0);
    put(s.glowS, s.ctaP[0], s.ctaP[1], 1, 0, 0.8 * bump(t, T.small - 0.03, T.small + 0.05, T.small + 0.5));
    poseBurst(s.sparksS, t); poseBurst(s.shardsS, t);
    const fl = seg(t, T.small + 0.02, T.small + 0.9);
    s.floatTx.style.opacity = fl > 0 && fl < 1 ? Math.min(1, fl * 5) * (1 - Math.pow(fl, 3)) : 0;
    s.floatTx.style.transform = `translateY(${-80 * eo(fl)}px) scale(${0.8 + 0.2 * back(Math.min(1, fl * 3))})`;
    // the number rolls over at each impact
    const amt = t < T.big + 0.05 ? 'e1.029e25' : t < T.small + 0.05 ? 'e2.102e25' : 'e3.175e25';
    if (amt !== lastHero) { s.hero.innerHTML = heroHTML(amt); lastHero = amt; }
    s.hero.style.filter = `brightness(${1 + 1.2 * bump(t, T.big, T.big + 0.06, T.big + 0.5) + 0.6 * bump(t, T.small, T.small + 0.05, T.small + 0.4)})`;
  };
  return C;
})();
