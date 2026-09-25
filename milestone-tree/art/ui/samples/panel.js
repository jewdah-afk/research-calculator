// panel.js - the ornate layer panel (frame, header, tabs A / B, hero row, relic cards) built from kit pieces.
const PANEL = (() => {
  const P = {};
  // the frame: drop shadow, 9-slice body+rim, texture tile, header band, crest, corners, emblem medallion, close gem
  P.frame = (parent, L, X, Y, W, H, { title, sub = [], k = 1, titleSize = 44, emblem = true, crest = true, close = true, medalK = 1, crestX = 0.5 } = {}) => {
    const T = UI_THEMES[L], rim = 12 * k;
    const g = O.abs(parent, 0, 0, null, null, '');
    O.slice(g, 'shadow', X - 34 * k, Y - 18 * k, W + 68 * k, H + 70 * k, { k: 1.2 * k, style: 'opacity:.95' });
    O.slice(g, 'glow9', X - 26 * k, Y - 26 * k, W + 52 * k, H + 52 * k, { k: 1.4 * k, tint: T.hue, style: 'opacity:.16' });
    O.slice(g, `panel_${L}`, X, Y, W, H, { k });
    O.tile(g, `tex_${L}`, X + rim, Y + rim, W - 2 * rim, H - 2 * rim, { k });
    O.slice(g, `header_${L}`, X + rim, Y + rim, W - 2 * rim, 92 * k, { k });
    const content = O.abs(g, X, Y, W, H, '');
    const orn = O.abs(g, 0, 0, null, null, '');
    for (const [w, cx, cy] of [['tr', X + W, Y], ['bl', X, Y + H], ['br', X + W, Y + H]]) O.image(orn, `corner_${L}_${w}`, cx, cy, { k });
    if (!emblem) O.image(orn, `corner_${L}_tl`, X, Y, { k });
    if (crest) O.image(orn, `crest_${L}`, X + W * crestX, Y + 6 * k, { k });
    if (emblem) {
      O.image(orn, `corner_${L}_tl`, X, Y, { k });
      const mx = X + 34 * k, my = Y + 34 * k;
      O.sprite(orn, 'glow', mx, my, 190 * k * medalK, 190 * k * medalK, { color: T.hue, alpha: 0.5 });
      O.image(orn, `medal_${L}`, mx, my, { k: 0.86 * k * medalK });
      O.abs(orn, mx - 50 * k, my - 50 * k, 100 * k, 100 * k, 'display:grid;place-items:center', O.tx(T.sym, { size: (T.sym.length > 1 ? 34 : 44) * k * medalK, font: 'num', ow: 6 * k, sh: 3 * k }));
    }
    if (close) {
      const cx = X + W - 4 * k, cy = Y + 4 * k;
      O.sprite(orn, 'glow', cx, cy, 110 * k, 110 * k, { color: '#ff3b5c', alpha: 0.35 });
      O.image(orn, 'close_btn', cx, cy, { k: 0.9 * k });
    }
    if (title) {
      O.abs(content, (emblem ? 104 : 40) * k, 18 * k, null, null, 'display:flex;flex-direction:column;gap:8px',
        O.tx(title, { size: titleSize * k, grad: ['#ffffff', T.hueHi, T.hue], ow: 7 * k, sh: 4 * k }) +
        `<div style="display:flex;align-items:center;gap:10px">${sub.join('')}</div>`);
    }
    return { g, content, orn, T };
  };
  P.subChip = (t, L) => `<span class="subchip" style="--c:${UI_THEMES[L].hue}">${O.nf(t)}</span>`;
  P.subCap = (t, c = '#cdc5e2') => `<span style="font:600 14px/1 Montserrat;color:${c}">${O.esc(t)}</span>`;

  // ---------------------------------------------------------------------------------------------- tabs
  // A: engraved gold header strip; the active tab sits on a lit gem plate with a glow sliding under it
  P.tabsA = (parent, L, x, y, w, tabs, { h = 50, k = 1, font = 17, right = '' } = {}) => {
    const T = UI_THEMES[L];
    O.slice(parent, 'tabA_strip', x, y, w, h, { k: 0.62 * k });
    if (right) O.abs(parent, x, y, w - 20 * k, h, 'display:flex;align-items:center;justify-content:flex-end;gap:8px', right);
    let cx = x + 16 * k; const out = [];
    for (const t of tabs) {
      const tw = t.w * k;
      if (t.on) {
        O.sprite(parent, 'glow', cx + tw / 2, y + h / 2, tw * 1.5, h * 2.6, { color: T.hue, alpha: 0.45 });
        O.slice(parent, `tabA_${L}`, cx - 6 * k, y - 5 * k, tw + 12 * k, h + 10 * k, { k: 0.62 * k });
        O.sprite(parent, 'flare', cx + tw / 2, y + h - 1, tw * 1.25, 40 * k, { color: T.hueHi, alpha: 0.95 });
        O.sprite(parent, 'glint', cx + tw / 2, y + h - 1, 34 * k, 34 * k, { color: '#fff' });
        O.abs(parent, cx, y, tw, h, 'display:flex;align-items:center;justify-content:center;gap:8px',
          O.tx(t.label.toUpperCase(), { size: font * k, weight: 900, ow: 4 * k, sh: 2, grad: ['#ffffff', '#ffffff', T.hueHi] }) + (t.badge ? `<span class="badge on">${t.badge}</span>` : ''));
      } else {
        O.abs(parent, cx, y, tw, h, 'display:flex;align-items:center;justify-content:center;gap:8px',
          `<span class="engraved" style="font-size:${font * k}px">${O.esc(t.label)}</span>` + (t.badge ? `<span class="badge">${t.badge}</span>` : '') + (t.dot ? '<span class="dot"></span>' : ''));
      }
      out.push([cx, tw]); cx += tw + 10 * k;
    }
    return out;
  };
  // B: segmented relic bar; the active segment is a raised hue-lit crystal plate, the others dim engraved text
  P.tabsB = (parent, L, x, y, w, tabs, { h = 46, k = 1, font = 17, right = '' } = {}) => {
    const T = UI_THEMES[L], n = tabs.length, sw = w / n;
    O.slice(parent, 'tabB_bar', x, y, w, h, { k: 0.62 * k });
    for (let i = 1; i < n; i++) O.image(parent, 'tabB_div', x + sw * i, y + h / 2, { k: k * h / 48 });
    tabs.forEach((t, i) => {
      const sx = x + sw * i;
      if (t.on) {
        O.sprite(parent, 'glow', sx + sw / 2, y + h / 2, sw * 1.35, h * 3, { color: T.hue, alpha: 0.5 });
        O.slice(parent, `tabB_${L}`, sx - 4 * k, y - 7 * k, sw + 8 * k, h + 14 * k, { k: 0.66 * k });
        O.sprite(parent, 'shimmer', sx + sw / 2, y - 4 * k, sw * 0.9, 10 * k, { color: '#fff', alpha: 0.8 });
        O.abs(parent, sx, y - 2 * k, sw, h + 4 * k, 'display:flex;align-items:center;justify-content:center;gap:8px',
          O.tx(t.label.toUpperCase(), { size: (font + 1) * k, weight: 900, ow: 4 * k, sh: 2, grad: ['#ffffff', '#ffffff', T.hueHi] }) + (t.badge ? `<span class="badge on">${t.badge}</span>` : ''));
      } else {
        O.abs(parent, sx, y, sw, h, 'display:flex;align-items:center;justify-content:center;gap:8px',
          `<span class="engraved" style="font-size:${font * k}px">${O.esc(t.label)}</span>` + (t.badge ? `<span class="badge">${t.badge}</span>` : '') + (t.dot ? '<span class="dot"></span>' : ''));
      }
    });
  };

  // ---------------------------------------------------------------------------------------------- hero + CTA
  P.hero = (parent, L, x, y, { amt, res, label = 'YOU HAVE', size = 58, k = 1 } = {}) => {
    const T = UI_THEMES[L];
    O.sprite(parent, 'glow', x + 150 * k, y + 60 * k, 520 * k, 220 * k, { color: T.hue, alpha: 0.28 });
    O.abs(parent, x, y, null, null, 'display:flex;flex-direction:column;gap:4px',
      O.caps(label, '#d8d0ea', 13 * k) + O.tx(amt, { size: size * k, font: 'num', grad: ['#ffffff', T.hueHi, T.hue], ow: 7 * k, sh: 5 * k }) +
      `<div style="margin-top:4px">${O.tx(res, { size: 22 * k, grad: [T.hueHi, T.hueHi], ow: 4 * k, sh: 2 })}</div>`);
  };
  P.cta = (parent, L, x, y, w, h, { title, gain, key, bar = null, k = 1 } = {}) => {
    const T = UI_THEMES[L];
    O.sprite(parent, 'glow', x + w / 2, y + h / 2, w * 1.4, h * 2.4, { color: T.hue, alpha: 0.4 });
    O.slice(parent, `btn_${L}`, x, y, w, h, { k: 0.72 * k });
    let inner = O.tx(title, { size: 28 * k, ow: 6 * k, sh: 3 });
    if (bar != null) inner += `<div style="display:flex;align-items:center;gap:10px"><div class="bar" style="width:${w - 150 * k}px"><i style="width:${bar * 100}%"></i></div><span class="well"><span class="nr">${Math.round(bar * 100)}%</span></span></div>`;
    if (gain) inner += `<span class="well">${O.nf(gain, '#e6f2ff')}</span>`;
    O.abs(parent, x, y, w, h, `display:flex;flex-direction:column;align-items:center;justify-content:center;gap:${7 * k}px`, inner);
    if (key) { O.slice(parent, 'toast', x + w - 54 * k, y + 12 * k, 34 * k, 30 * k, { k: 0.4 * k }); O.abs(parent, x + w - 54 * k, y + 12 * k, 34 * k, 30 * k, 'display:grid;place-items:center;font:800 14px Montserrat;color:#ffe9b0;text-shadow:0 1px 0 #000', key); }
  };
  P.chip = (parent, x, y, w, label, val, { valColor = '#fff', h = 36, k = 1 } = {}) => {
    O.slice(parent, 'toast', x, y, w, h, { k: 0.5 * k });
    O.abs(parent, x + 14, y, w - 28, h, 'display:flex;align-items:center;justify-content:space-between;gap:10px',
      O.caps(label, '#d8d0ea', 12 * k) + `<span style="font:700 ${16 * k}px Sarpanch;color:${valColor}">${O.nf(val, valColor)}</span>`);
  };
  P.section = (parent, L, x, y, w, text, chips = '') => {
    const T = UI_THEMES[L];
    const row = O.abs(parent, x, y, null, 34, 'display:flex;align-items:center;gap:12px;white-space:nowrap',
      `<span class="secbar" style="--c:${T.hue}"></span>${O.tx(text, { size: 24, grad: ['#fff', T.hueHi], ow: 5, sh: 3 })}${chips}`);
    const tw = row.getBoundingClientRect().width + 14;   // the divider fills what the title leaves
    O.slice(parent, 'divider', x + tw, y + 1, w - tw, 32, { k: 0.8 });
  };

  // ---------------------------------------------------------------------------------------------- relic cards
  // BUYABLE: the layer crystal plate, a lit socket pulsing on its top edge, glow around the card
  P.cardBuy = (parent, L, x, y, w, h, { n, title, desc, cur, cost, pulse = 0.8, lift = 0 } = {}) => {
    const T = UI_THEMES[L];
    const c = O.abs(parent, x, y - lift, w, h, lift ? `filter:brightness(${1 + lift / 60})` : '');
    O.slice(c, 'glow9', -22, -22, w + 44, h + 44, { k: 0.9, tint: T.hue, style: `opacity:${0.45 + 0.35 * pulse}` });
    O.slice(c, `card_${L}`, 0, 0, w, h, { k: 0.72 });
    O.sprite(c, 'glow', w / 2, 2, 150, 110, { color: T.hue, alpha: 0.6 + 0.4 * pulse });
    O.image(c, `socket_${L}`, w / 2, 2, { k: 0.9 });
    O.sprite(c, 'glint', w / 2 - 9, -7, 36 * (0.6 + 0.4 * pulse), 36 * (0.6 + 0.4 * pulse), { color: '#fff', alpha: pulse });
    O.abs(c, 16, 20, w - 32, h - 32, 'display:flex;flex-direction:column;gap:7px',
      `<div style="display:flex;justify-content:space-between;align-items:center;height:28px"><span style="font:900 28px/1 Sarpanch;color:${T.hueHi};text-shadow:0 2px 0 #000">${n}</span><span class="buy" style="--c:${T.hue}">BUY</span></div>
       <div>${O.tx(title, { size: 19, weight: 800, ow: 4, sh: 2, grad: ['#fff', T.hueHi], style: 'white-space:normal;line-height:1.12' })}</div>
       <div class="body">${O.esc(desc)}</div><div style="flex:1"></div>
       ${cur ? `<div style="display:flex;flex-direction:column;gap:5px;align-items:flex-start">${O.caps('Currently', '#e6e0f4', 12)}<span class="well">${O.nf(cur, '#e9e6f7')}</span></div>` : ''}
       <div class="hr" style="--c:${T.hue}"></div>
       <div style="display:flex;justify-content:space-between;align-items:center">${O.caps('Cost', '#e6e0f4', 12)}<span style="font:800 18px Sarpanch;color:#fff">${O.nf(cost, '#e9e6f7')}</span></div>`);
    return c;
  };
  // OWNED: gilded rim, warm body, the engraved check seal on the top edge; calm
  P.cardOwned = (parent, x, y, w, h, { n, title, desc, eff = null } = {}) => {
    const c = O.abs(parent, x, y, w, h);
    O.slice(c, 'card_owned', 0, 0, w, h, { k: 0.72 });
    O.image(c, 'seal_owned', w / 2, 2, { k: 0.8 });
    O.abs(c, 16, 20, w - 32, h - 32, 'display:flex;flex-direction:column;gap:7px',
      `<div style="display:flex;justify-content:space-between;align-items:center;height:28px"><span style="font:900 28px/1 Sarpanch;color:#d9b36a;text-shadow:0 2px 0 #000">${n}</span><span class="owned">${O.icon('check', 14, '#ffe08a')}OWNED</span></div>
       <div style="font:italic 800 19px/1.12 Montserrat;color:#fff0cf;text-shadow:0 2px 0 #000">${O.esc(title)}</div>
       <div class="body" style="color:#eadfc6">${O.esc(desc)}</div><div style="flex:1"></div>
       <div class="hr" style="--c:#ffcf6a"></div>
       <div style="display:flex;justify-content:flex-end;align-items:center;gap:6px">${O.icon('check', 15, '#9be8a9')}<span style="font:800 15px Montserrat;color:#bff0c8">${eff ? O.nf(eff, '#bff0c8') : 'Active'}</span></div>`);
    return c;
  };
  P.compactOwned = (parent, x, y, w, h, { n, title, eff }) => {
    const c = O.abs(parent, x, y, w, h);
    O.slice(c, 'card_owned', 0, 0, w, h, { k: 0.6 });
    O.image(c, 'seal_owned', 27, h / 2, { k: 0.42 });
    O.abs(c, 52, 9, w - 64, h - 16, 'display:flex;flex-direction:column;justify-content:space-between',
      `<div style="display:flex;gap:6px;align-items:baseline"><span style="font:800 13px Sarpanch;color:#d9b36a">${n}</span><span style="font:italic 800 14px/1.1 Montserrat;color:#fff0cf">${O.esc(title)}</span></div>
       <div style="text-align:right;font:800 14px/1 Montserrat;color:#bff0c8">${eff ? O.nf(eff, '#bff0c8') : 'Active'}</div>`);
    return c;
  };
  // LOCKED: carved stone, a chain across it with the rune seal; title + requirement stay readable on a well
  P.cardLocked = (parent, x, y, w, h, { n, title, req, chain = 1, sealK = 0.62, chainY = null } = {}) => {
    const c = O.abs(parent, x, y, w, h);
    O.slice(c, 'card_locked', 0, 0, w, h, { k: 0.72 });
    O.tile(c, 'tex_stone', 8, 8, w - 16, h - 16, { style: 'opacity:.55;mix-blend-mode:soft-light' });
    O.abs(c, 16, 14, w - 32, h - 24, 'display:flex;flex-direction:column;gap:6px',
      `<div style="display:flex;gap:8px;align-items:baseline"><span style="font:900 22px/1 Sarpanch;color:#9d93ad;text-shadow:0 2px 0 #000">${n}</span><span style="font:italic 800 16px/1.1 Montserrat;color:#d6cfe0;text-shadow:0 2px 0 #000">${O.esc(title)}</span></div>
       <div style="flex:1;min-height:34px"></div><div class="well" style="white-space:normal;font:600 13px/1.3 Montserrat;color:#e2dbeb;display:flex;gap:6px;align-items:flex-start">${O.icon('lock', 13, '#c9b8ff', 'flex:none;margin-top:1px')}<span>${O.nf(req, '#e2dbeb')}</span></div>`);
    if (chain) {
      const cy = chainY != null ? chainY : h * 0.5;
      O.tile(c, 'chain', -6, cy - 16, w + 12, 32, { style: 'filter:drop-shadow(0 3px 2px rgba(0,0,0,.8))' });
      O.sprite(c, 'glow', w / 2, cy, 110, 110, { color: '#b9a8ff', alpha: 0.35 });
      O.image(c, 'seal_locked', w / 2, cy, { k: sealK });
    }
    return c;
  };
  // a collapsed tier: one gilded bar summarising an owned row
  P.ownedBar = (parent, x, y, w, h, { tier, names }) => {
    O.slice(parent, 'card_owned', x, y, w, h, { k: 0.5 });
    O.image(parent, 'seal_owned', x + 22, y + h / 2, { k: 0.34 });
    O.abs(parent, x + 42, y, w - 60, h, 'display:flex;align-items:center;gap:12px;white-space:nowrap;overflow:hidden',
      `<span style="font:italic 800 14px Montserrat;color:#fff0cf">Tier ${tier}</span><span style="font:800 13px Sarpanch;color:#bff0c8">4 / 4</span><span style="font:600 13px Montserrat;color:#e2d6bb">${O.esc(names)}</span><span style="flex:1"></span><span style="font:800 13px Montserrat;color:#ffe08a">Show ▾</span>`);
  };
  // a locked ladder row: title + requirement on the left, the chain and rune seal across the rest
  P.lockedRow = (parent, x, y, w, h, { title, req, textW = 300 }) => {
    const c = O.abs(parent, x, y, w, h);
    O.slice(c, 'card_locked', 0, 0, w, h, { k: 0.6 });
    O.tile(c, 'tex_stone', 8, 8, w - 16, h - 16, { style: 'opacity:.55;mix-blend-mode:soft-light' });
    O.tile(c, 'chain', textW, h / 2 - 16, w - textW - 4, 32, { style: 'filter:drop-shadow(0 3px 2px rgba(0,0,0,.8))' });
    O.sprite(c, 'glow', textW + (w - textW) / 2, h / 2, 110, 110, { color: '#b9a8ff', alpha: 0.35 });
    O.image(c, 'seal_locked', textW + (w - textW) / 2, h / 2, { k: 0.5 });
    O.abs(c, 20, 0, textW - 30, h, 'display:flex;flex-direction:column;justify-content:center;gap:5px',
      `<span style="font:italic 800 17px Montserrat;color:#d6cfe0;text-shadow:0 2px 0 #000">${O.esc(title)}</span><span style="display:flex;gap:6px;align-items:center;font:600 13px Montserrat;color:#e2dbeb">${O.icon('lock', 12, '#c9b8ff')}${O.esc(req)}</span>`);
    return c;
  };
  P.rail = (parent, L, x, y0, y1, nodes) => {   // tier rail: a gold rod with a medallion per tier
    const T = UI_THEMES[L];
    O.abs(parent, x + 20, y0, 6, y1 - y0, 'background:linear-gradient(90deg,#3a2308,#b07a28 30%,#fff3c4 50%,#c08a2e 70%,#3a2308);border-radius:3px;opacity:.85');
    for (const [cy, lab, st] of nodes) {
      if (st === 'open') { O.sprite(parent, 'glow', x + 23, cy, 90, 90, { color: T.hue, alpha: 0.7 }); O.image(parent, `socket_${L}`, x + 23, cy, { k: 0.62 }); }
      else if (st === 'locked') O.image(parent, 'seal_locked', x + 23, cy, { k: 0.45 });
      else O.image(parent, 'socket_empty', x + 23, cy, { k: 0.62 });
      if (st !== 'locked') O.abs(parent, x + 3, cy - 20, 40, 40, 'display:grid;place-items:center', O.tx(String(lab), { size: 18, font: 'num', ow: 4, sh: 2, color: st === 'open' ? '#fff' : '#ffe08a' }));
    }
  };
  return P;
})();
