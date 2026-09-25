// lib.js - shared helpers for the clean-direction option boards: DOM + text helpers, line icons, the layer hues,
// the real node positions on the painted realm, and the map nodes (Blender crystal gems or clean icon discs) with
// the reactive ENERGY RING drawn on a canvas as a pure function of time, so stills and the clip are frame-exact.
const K = (() => {
  const K = {};
  // ---------------------------------------------------------------------------------------------- colour
  K.HUES = {
    m: '#b35cff', mm: '#d17aff', em: '#e88af2', p: '#6fc3ff', pe: '#ff9a2e', sp: '#5fe0ff', pb: '#57e0b0', pp: '#ff4d6d',
    se: '#ff6a1f', hp: '#7fd9ff', ep: '#9be02c', hb: '#6dffb0', ap: '#8ff3f3', mp: '#ff5a1f', t: '#ffe93a', pm: '#ff2e63',
    pep: '#f2b04d', cp: '#39ff14', cm: '#1fbf4a', ex: '#45e07f', ach: '#ffc93c',
  };
  K.GOLD = '#ffd34d'; K.OWNED = '#4be07a'; K.LOCKED = '#8a6f7a';
  const rgb = h => { const c = h.replace('#', ''); return [0, 2, 4].map(i => parseInt(c.slice(i, i + 2), 16)); };
  K.rgba = (h, a) => { const [r, g, b] = rgb(h); return `rgba(${r},${g},${b},${a})`; };
  K.mix = (a, b, t) => { const A = rgb(a), B = rgb(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join(''); };
  K.lift = (h, t) => K.mix(h, '#ffffff', t);
  K.sink = (h, t) => K.mix(h, '#000000', t);

  // ---------------------------------------------------------------------------------------------- DOM + text
  K.root = () => document.getElementById('root');
  K.el = (parent, tag = 'div', style = '', html = '') => { const e = document.createElement(tag); if (style) e.style.cssText = style; if (html) e.innerHTML = html; (parent || K.root()).appendChild(e); return e; };
  K.abs = (parent, x, y, w, h, style = '', html = '') => K.el(parent, 'div', `position:absolute;left:${x}px;top:${y}px;${w != null ? `width:${w}px;` : ''}${h != null ? `height:${h}px;` : ''}${style}`, html);
  K.esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
  // digit runs (and e + - x . , / %) in Sarpanch, words and units in Montserrat Bold (DESIGN 9.1 / 9.9)
  K.nf = (s, unitStyle = '') => K.esc(s).replace(/([+\-−×^]?e?\d[\d.,/]*(?:e[\d.,]+)*%?)|([^\d+\-−×^]+)/g, (m, num, word) =>
    num ? `<span class="nr">${num}</span>` : `<span class="nw"${unitStyle ? ` style="${unitStyle}"` : ''}>${word}</span>`);
  K.caps = (t, { size = 13, color = '#c9cfdb', track = 0.12, weight = 700, style = '' } = {}) =>
    `<span style="font:${weight} ${size}px/1 Montserrat;letter-spacing:${track}em;text-transform:uppercase;color:${color};white-space:nowrap;${style}">${K.esc(t)}</span>`;

  // ---------------------------------------------------------------------------------------------- icons (24 grid)
  const gear = (() => {   // 8 teeth, outer 10.4, inner 7.6, hub 3.2
    let d = ''; const N = 8;
    for (let i = 0; i < N * 4; i++) {
      const a = (i / (N * 4)) * Math.PI * 2 - Math.PI / 2, r = (i % 4 === 1 || i % 4 === 2) ? 10.4 : 7.8;
      d += (i ? 'L' : 'M') + (12 + r * Math.cos(a)).toFixed(2) + ' ' + (12 + r * Math.sin(a)).toFixed(2) + ' ';
    }
    return d + 'Z M12 8.6 A3.4 3.4 0 1 0 12 15.4 A3.4 3.4 0 1 0 12 8.6 Z';
  })();
  K.ICONS = {
    home: { d: 'M3.5 11 L12 3.8 L20.5 11 M5.8 9.2 V20 H10 V14.2 H14 V20 H18.2 V9.2' },
    trophy: { d: 'M7 4 H17 V9.5 A5 5 0 0 1 7 9.5 Z M7 6 H3.8 V7.6 A3.4 3.4 0 0 0 7.2 11 M17 6 H20.2 V7.6 A3.4 3.4 0 0 1 16.8 11 M12 14.5 V18.5 M8 20.3 H16' },
    gear: { d: gear, fillRule: 'evenodd' },
    check: { d: 'M5 12.6 L9.8 17.2 L19 7.4' },
    lock: { d: 'M6 11 H18 V20.5 H6 Z M8.6 11 V8.2 A3.4 3.4 0 0 1 15.4 8.2 V11' },
    bolt: { d: 'M13.4 2.4 L5.2 13.6 H11.2 L10.2 21.6 L18.8 10 H12.8 Z', fill: true },
    close: { d: 'M6.5 6.5 L17.5 17.5 M17.5 6.5 L6.5 17.5' },
    chevD: { d: 'M7 9.8 L12 14.8 L17 9.8' },
    chevR: { d: 'M9.8 7 L14.8 12 L9.8 17' },
    plus: { d: 'M12 6 V18 M6 12 H18' },
    minus: { d: 'M6 12 H18' },
    star: { d: 'M12 2.6 L14.8 8.9 L21.6 9.5 L16.5 14 L18 20.8 L12 17.3 L6 20.8 L7.5 14 L2.4 9.5 L9.2 8.9 Z', fill: true },
    spark: { d: 'M12 2.5 C12.8 8.4 15.6 11.2 21.5 12 C15.6 12.8 12.8 15.6 12 21.5 C11.2 15.6 8.4 12.8 2.5 12 C8.4 11.2 11.2 8.4 12 2.5 Z', fill: true },
    up: { d: 'M12 19 V5.5 M6.5 11 L12 5.5 L17.5 11' },
    bell: { d: 'M6.5 16.5 V11 A5.5 5.5 0 0 1 17.5 11 V16.5 L19 18 H5 Z M10 20.2 H14' },
  };
  // stroke icons by default; fill = true paints the shape (bolt, star, spark) or `solid` forces a fill
  K.icon = (name, size, color, { sw = 1.8, solid = false, style = '' } = {}) => {
    const I = K.ICONS[name], fill = solid || I.fill;
    return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" style="${style}"><path d="${I.d}" ${fill ? `fill="${color}" fill-rule="${I.fillRule || 'nonzero'}"` : `fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"`}/></svg>`;
  };

  // ---------------------------------------------------------------------------------------------- loading
  const IMG = {};
  K.img = src => IMG[src] || (IMG[src] = new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = () => rej(new Error('no image ' + src)); im.src = src; }));
  K.GEM = key => `/gems/sprites/${key}.png`;
  K.GEM_VARIANTS = { m: ['locked', 'ready'], p: ['locked', 'ready'], t: ['locked', 'ready'] };
  K.load = async () => {
    await Promise.all(['600 16px Montserrat', '700 16px Montserrat', '800 16px Montserrat', '900 16px Montserrat', 'italic 700 16px Montserrat',
      'italic 800 16px Montserrat', 'italic 900 16px Montserrat', '700 16px Sarpanch', '800 16px Sarpanch', '900 16px Sarpanch'].map(f => document.fonts.load(f, 'Aa0')));
    const keys = Object.keys(K.HUES);
    await Promise.all(keys.map(k => K.img(K.GEM(k))).concat(Object.entries(K.GEM_VARIANTS).flatMap(([k, v]) => v.map(s => K.img(K.GEM(`${k}_${s}`))))));
    K.GEMS = {};
    for (const k of keys) K.GEMS[k] = await K.img(K.GEM(k));
    for (const [k, v] of Object.entries(K.GEM_VARIANTS)) for (const s of v) K.GEMS[`${k}_${s}`] = await K.img(K.GEM(`${k}_${s}`));
  };

  // ---------------------------------------------------------------------------------------------- the real nodes
  // world coordinates of the realm (art/realm.json), the same as the approved mockups; state = what the ring shows
  K.WORLD = [
    { key: 't', w: [1500, 320], letter: 'T', name: 'TRANSCEND', value: '1.00e70', st: 'idle' },
    { key: 'hb', w: [1180, 660], letter: 'HB', name: 'HYPER BOOST', value: '1e413,950 HP', st: 'locked' },
    { key: 'ap', w: [1500, 610], letter: 'AP', name: 'ATOMIC', value: 'e4.234e18', st: 'idle' },
    { key: 'mp', w: [1820, 660], letter: 'MP', name: 'MULTIVERSE', value: '0', st: 'ready' },
    { key: 'se', w: [1150, 980], letter: 'SE', name: 'SUPER ENERGY', value: '4.49e24', st: 'buy' },
    { key: 'hp', w: [1500, 930], letter: 'HP', name: 'HYPER', value: 'e8.502e20', st: 'idle' },
    { key: 'ep', w: [1850, 980], letter: 'EP', name: 'EXOTIC', value: 'e1,329,005', st: 'ready' },
    { key: 'pe', w: [1040, 1300], letter: 'PE', name: 'ENERGY', value: '2.06e25', st: 'buy' },
    { key: 'sp', w: [1330, 1250], letter: 'SP', name: 'SUPER', value: 'e1.262e24', st: 'buy' },
    { key: 'pb', w: [1670, 1250], letter: 'PB', name: 'BOOST', value: '1e13,760 P', st: 'locked' },
    { key: 'pp', w: [1960, 1300], letter: 'PP', name: 'POWER', value: 'e798,769,126', st: 'idle' },
    { key: 'p', w: [1500, 1580], letter: 'P', name: 'PRESTIGE', value: 'e1.029e25', st: 'buy' },
    { key: 'm', w: [1500, 1900], letter: 'M', name: 'MILESTONE', value: '164', st: 'idle' },
    { key: 'mm', w: [1180, 1960], letter: 'MM', name: 'META', value: '27', st: 'ready' },
    { key: 'em', w: [1820, 1960], letter: '?', name: null, value: null, st: 'locked' },
    { key: 'ach', w: [520, 600], letter: '★', name: 'ACHIEVEMENTS', value: '13 / 18', st: 'idle' },
  ];
  // home.png is the realm at zoom .5 centred on (1760, 1110); strip_p.png is zoom .9 centred on (1500, 1640), 760 wide
  K.HOME = { zoom: 0.5, map: (wx, wy) => [(wx - 1760) * 0.5 + 960, (wy - 1110) * 0.5 + 540] };
  K.STRIP = { zoom: 0.9, map: (wx, wy) => [(wx - 1500) * 0.9 + 380, (wy - 1640) * 0.9 + 540] };
  K.nodesFor = (view, filter) => K.WORLD.filter(n => !filter || filter.includes(n.key)).map(n => { const [x, y] = view.map(n.w[0], n.w[1]); return Object.assign({}, n, { x, y }); });

  // ---------------------------------------------------------------------------------------------- energy ring
  // One thin ring in the layer hue around the socket. Every state is a function of t (seconds):
  //   locked  dim mauve-grey hairline, no glow, still
  //   idle    slow breathe (3.2 s sine) of the glow and the core
  //   buy     a quick irregular flicker + one bright comet arc orbiting (1.6 s / turn)
  //   ready   fast bright pulse (1.0 s, sharp attack / exp decay) + a ripple ring leaving the node, and a ⚡ badge
  // Roblox build: the ring is a white ring sprite (ImageColor3 = hue) + a soft glow sprite; the comet is a UIStroke on
  // a round Frame with a UIGradient whose Rotation tweens; the ripple is a second ring sprite tweening Size + alpha.
  const frac = x => x - Math.floor(x);
  const hash = i => frac(Math.sin(i * 12.9898 + 78.233) * 43758.5453);
  const smooth = x => x * x * (3 - 2 * x);
  K.flicker = t => {
    const f = t * 13, i = Math.floor(f), v = hash(i) + (hash(i + 1) - hash(i)) * smooth(f - i);
    const dip = hash(Math.floor(t * 5.3) + 31) < 0.22 ? 0.55 : 1;
    return (0.62 + 0.38 * v) * dip;
  };
  K.ringState = (st, t) => {
    if (st === 'locked') return { st, core: 0.34, glow: 0, width: 1.3, color: '#a39cb3' };
    if (st === 'idle') { const p = 0.5 + 0.5 * Math.sin((t / 3.2) * Math.PI * 2); return { st, p, core: 0.62 + 0.28 * p, glow: 0.16 + 0.34 * p, width: 1.7 }; }
    if (st === 'buy') { const f = K.flicker(t); return { st, f, core: 0.5 + 0.3 * f, glow: 0.14 + 0.3 * f, width: 1.7, arc: (t / 1.6) * Math.PI * 2 - Math.PI * 0.5 }; }
    const ph = frac(t / 1.0), p = Math.exp(-3.2 * ph);   // ready
    return { st, ph, p, core: 0.88 + 0.12 * p, glow: 0.45 + 0.5 * p, width: 2.4 + 0.8 * p };
  };
  function strokeCircle(ctx, x, y, r, color, width, alpha, blur = 0) {
    if (alpha <= 0.002) return;
    ctx.save(); ctx.globalAlpha = Math.min(1, alpha); ctx.strokeStyle = color; ctx.lineWidth = width;
    if (blur) ctx.filter = `blur(${blur}px)`;
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
  }
  K.drawRing = (ctx, x, y, r, hue, st, t, k = 1) => {
    const S = K.ringState(st, t), hi = K.lift(hue, 0.55), core = K.lift(hue, st === 'ready' ? 0.7 : 0.4);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    if (st === 'locked') { ctx.globalCompositeOperation = 'source-over'; strokeCircle(ctx, x, y, r, S.color, S.width * k, S.core); ctx.restore(); return S; }
    // wide soft halo, tight glow, then the crisp core line
    strokeCircle(ctx, x, y, r, hue, 9 * k, S.glow * 0.55, 9 * k);
    strokeCircle(ctx, x, y, r, hue, 3.4 * k, S.glow, 2.4 * k);
    strokeCircle(ctx, x, y, r, core, S.width * k, S.core);
    if (st === 'buy') {   // comet arc: a 110 degree tail fading into the head, plus a spark at the head
      const segs = 40, len = Math.PI * 0.8;
      for (let i = 0; i < segs; i++) {
        const a0 = S.arc - len + (len * i) / segs, a1 = a0 + len / segs + 0.01, w = (i + 1) / segs;
        ctx.save(); ctx.globalAlpha = Math.pow(w, 1.6) * (0.6 + 0.4 * S.f); ctx.strokeStyle = w > 0.8 ? '#ffffff' : hi; ctx.lineWidth = (1.4 + 2.2 * w) * k;
        if (i === segs - 1 || i % 3 === 0) { ctx.shadowColor = hue; ctx.shadowBlur = 6 * k; }
        ctx.beginPath(); ctx.arc(x, y, r, a0, a1); ctx.stroke(); ctx.restore();
      }
      const hx = x + r * Math.cos(S.arc), hy = y + r * Math.sin(S.arc), g = ctx.createRadialGradient(hx, hy, 0, hx, hy, 11 * k);
      g.addColorStop(0, K.rgba('#ffffff', 0.95 * S.f)); g.addColorStop(0.35, K.rgba(hue, 0.6 * S.f)); g.addColorStop(1, K.rgba(hue, 0));
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(hx, hy, 11 * k, 0, Math.PI * 2); ctx.fill();
    }
    if (st === 'ready') {   // the ripple leaving the node (one per pulse)
      const rr = r + (r * 0.42) * smooth(Math.min(1, S.ph * 1.15)), a = Math.pow(1 - S.ph, 2);
      strokeCircle(ctx, x, y, rr, hue, 4 * k, 0.55 * a, 3 * k);
      strokeCircle(ctx, x, y, rr, hi, (1.6 * (1 - S.ph) + 0.4) * k, 0.8 * a);
    }
    ctx.restore();
    return S;
  };
  // the ⚡ badge of READY nodes (gold = ready, DESIGN 11.2)
  K.drawBolt = (ctx, x, y, s, alpha = 1) => {
    ctx.save(); ctx.globalAlpha = alpha;
    ctx.fillStyle = 'rgba(0,0,0,.55)'; ctx.beginPath(); ctx.arc(x, y + s * 0.08, s * 1.08, 0, Math.PI * 2); ctx.fill();
    const g = ctx.createLinearGradient(x, y - s, x, y + s); g.addColorStop(0, '#fff1b0'); g.addColorStop(0.55, '#ffd34d'); g.addColorStop(1, '#f0a81c');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, s, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = Math.max(1, s * 0.12); ctx.strokeStyle = '#1a1204'; ctx.stroke();
    const P = new Path2D(K.ICONS.bolt.d); ctx.translate(x - s * 0.62, y - s * 0.62); ctx.scale(s * 1.24 / 24, s * 1.24 / 24);
    ctx.fillStyle = '#1a1204'; ctx.fill(P); ctx.restore();
  };

  // ---------------------------------------------------------------------------------------------- node bodies
  // gem: the Blender sprite (locked / ready variants where they exist, a filtered sprite otherwise)
  K.drawGem = (ctx, n, x, y, size, S) => {
    const st = n.st, key = n.key;
    let im = K.GEMS[key], filter = 'none';
    if (st === 'locked') { if (K.GEMS[key + '_locked']) im = K.GEMS[key + '_locked']; else filter = 'grayscale(1) brightness(.62) contrast(.95)'; }
    if (st === 'ready' && K.GEMS[key + '_ready']) im = K.GEMS[key + '_ready'];
    if (st === 'ready' || st === 'buy') {   // light from inside the socket, in step with the ring
      const a = st === 'ready' ? 0.28 + 0.3 * S.p : 0.16 + 0.12 * S.f, R = size * 0.62, g = ctx.createRadialGradient(x, y, 0, x, y, R);
      g.addColorStop(0, K.rgba(K.HUES[key], a)); g.addColorStop(1, K.rgba(K.HUES[key], 0));
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, R, 0, Math.PI * 2); ctx.fill(); ctx.restore();
    }
    ctx.save(); ctx.filter = filter;
    if (st === 'locked') ctx.globalAlpha = 0.9;
    ctx.drawImage(im, x - size / 2, y - size / 2 - size * 0.006, size, size); ctx.restore();
    if (st === 'ready') {   // the gem itself brightens on the beat
      ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.22 * S.p; ctx.drawImage(im, x - size / 2, y - size / 2, size, size); ctx.restore();
    }
  };
  // clean icon disc: a dark glass lens, hue light pooled at the bottom, a fine hue rim, the layer letters in Sarpanch
  // Heavy lit in the hue (Roblox: one white disc sprite + ImageColor3, a UIStroke rim, a TextLabel with a glow sprite)
  K.drawIconNode = (ctx, n, x, y, r, S, k = 1) => {
    const hue = K.HUES[n.key], st = n.st, locked = st === 'locked', hot = st === 'ready';
    ctx.save();
    ctx.fillStyle = 'rgba(0,0,0,.5)'; ctx.beginPath(); ctx.arc(x, y + 2 * k, r + 1.5 * k, 0, Math.PI * 2); ctx.fill();
    const g = ctx.createLinearGradient(x, y - r, x, y + r);
    g.addColorStop(0, locked ? '#1a1a22' : '#1c1f2c'); g.addColorStop(1, locked ? '#0c0c11' : '#090a11');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    if (!locked) {
      const a = hot ? 0.42 + 0.25 * S.p : st === 'buy' ? 0.3 + 0.1 * S.f : 0.26, b = ctx.createRadialGradient(x, y + r * 0.62, 0, x, y + r * 0.62, r * 1.05);
      b.addColorStop(0, K.rgba(hue, a)); b.addColorStop(1, K.rgba(hue, 0));
      ctx.fillStyle = b; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    }
    const sh = ctx.createLinearGradient(x, y - r, x, y - r * 0.1);
    sh.addColorStop(0, 'rgba(255,255,255,' + (locked ? 0.05 : 0.1) + ')'); sh.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = sh; ctx.beginPath(); ctx.ellipse(x, y - r * 0.45, r * 0.8, r * 0.48, 0, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = 1.5 * k; ctx.strokeStyle = locked ? 'rgba(150,143,168,.32)' : K.rgba(hue, hot ? 0.95 : 0.78);
    ctx.beginPath(); ctx.arc(x, y, r - 0.75 * k, 0, Math.PI * 2); ctx.stroke();
    const L = n.letter, fs = (L.length === 1 ? 0.95 : L.length === 2 ? 0.72 : 0.56) * r;
    ctx.font = `900 ${fs}px Sarpanch`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillStyle = locked ? '#77728a' : K.lift(hue, hot ? 0.55 : 0.38);
    if (!locked) { ctx.shadowColor = hue; ctx.shadowBlur = (hot ? 12 : 8) * k; }
    if (L === '★') { const P = new Path2D(K.ICONS.star.d), s = r * 1.05; ctx.translate(x - s / 2, y - s / 2); ctx.scale(s / 24, s / 24); ctx.fill(P); }
    else ctx.fillText(L, x, y + fs * 0.06);
    ctx.restore();
    if (locked && L !== '?') {   // small lock chip at the bottom
      ctx.save(); ctx.fillStyle = '#16151d'; ctx.strokeStyle = 'rgba(190,180,205,.4)'; ctx.lineWidth = 1 * k;
      const lx = x, ly = y + r * 0.8, lr = 7.5 * k; ctx.beginPath(); ctx.arc(lx, ly, lr, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      const P = new Path2D(K.ICONS.lock.d), s = lr * 1.35; ctx.translate(lx - s / 2, ly - s / 2); ctx.scale(s / 24, s / 24);
      ctx.strokeStyle = '#b9b1c6'; ctx.lineWidth = 2.4; ctx.lineJoin = 'round'; ctx.stroke(P); ctx.restore();
    }
  };
  // a full node: body + ring (+ ⚡ + selection reticle). geo: { rSock (ring radius), gem (sprite px), disc (icon radius), k }
  K.drawNode = (ctx, n, mode, geo, t) => {
    const hue = K.HUES[n.key], k = geo.k, S = K.ringState(n.st, t);
    if (mode === 'gem') K.drawGem(ctx, n, n.x, n.y, geo.gem, S);
    else K.drawIconNode(ctx, n, n.x, n.y, geo.disc, S, k);
    K.drawRing(ctx, n.x, n.y, geo.rSock, hue, n.st, t, k);
    if (n.sel) {   // selection: a fine outer hairline with four ticks
      const R = geo.rSock + 9 * k;
      ctx.save(); ctx.strokeStyle = K.rgba(K.lift(hue, 0.6), 0.75); ctx.lineWidth = 1.2 * k;
      for (let q = 0; q < 4; q++) { const a = q * Math.PI / 2 + Math.PI / 4; ctx.beginPath(); ctx.arc(n.x, n.y, R, a - 0.42, a + 0.42); ctx.stroke(); }
      ctx.lineWidth = 2 * k;
      for (let q = 0; q < 4; q++) { const a = q * Math.PI / 2; ctx.beginPath(); ctx.moveTo(n.x + Math.cos(a) * (R - 3 * k), n.y + Math.sin(a) * (R - 3 * k)); ctx.lineTo(n.x + Math.cos(a) * (R + 5 * k), n.y + Math.sin(a) * (R + 5 * k)); ctx.stroke(); }
      ctx.restore();
    }
    if (n.st === 'ready') { const a = -Math.PI / 4, br = geo.rSock + 1 * k; K.drawBolt(ctx, n.x + Math.cos(a) * br, n.y + Math.sin(a) * br, 9.5 * k, 1); }
    return S;
  };
  // a canvas overlay covering (x, y, w, h) of the parent
  K.canvas = (parent, x, y, w, h, style = '') => {
    const c = K.el(parent, 'canvas', `position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;${style}`);
    c.width = w; c.height = h; return c;
  };
  // geometry of the painted sockets per view (measured on home.png / strip_p.png)
  K.GEO = { home: { rSock: 41, gem: 70, disc: 29, k: 1 }, strip: { rSock: 74, gem: 124, disc: 52, k: 1.8 } };
  return K;
})();
