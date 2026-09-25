// ornate.js - builds sample screens from the UI kit exactly the way the client will: every surface is a kit piece
// from ui.json (9-slice via CSS border-image with the manifest's SliceCenter / SliceScale, standalone ornaments placed
// by their anchors, tiles, and white atlas sprites tinted through a CSS mask = ImageColor3). Text is live (fonts
// from art/ui/fonts), following DESIGN.md section 9: body >= 13 px, caps >= 12 px, text on art sits on a well.
const O = (() => {
  const PX = '/ui/out/pieces/';
  let MAN = null;
  const O = {};
  O.load = async () => {
    MAN = await (await fetch('/ui/ui.json')).json(); O.MAN = MAN;
    // webfonts first: layout code measures text (dividers fill what a title leaves)
    await Promise.all(['600 16px Montserrat', '700 16px Montserrat', '800 16px Montserrat', '900 16px Montserrat', 'italic 700 16px Montserrat',
      'italic 800 16px Montserrat', 'italic 900 16px Montserrat', '700 16px Sarpanch', '800 16px Sarpanch', '900 16px Sarpanch', '500 16px RobotoMono', '700 16px RobotoMono']
      .map(f => document.fonts.load(f, 'Aa0')));
    return MAN;
  };
  O.root = () => document.getElementById('root');
  O.el = (parent, tag = 'div', style = '', html = '') => { const e = document.createElement(tag); if (style) e.style.cssText = style; if (html) e.innerHTML = html; (parent || O.root()).appendChild(e); return e; };
  O.abs = (parent, x, y, w, h, style = '', html = '') => O.el(parent, 'div', `position:absolute;left:${x}px;top:${y}px;${w != null ? `width:${w}px;` : ''}${h != null ? `height:${h}px;` : ''}${style}`, html);

  // 9-slice: exactly Roblox's ScaleType.Slice (border = insets x sliceScale x k; the centre stretches)
  O.slice = (parent, name, x, y, w, h, { k = 1, style = '', tint = null } = {}) => {
    const p = MAN.pieces[name]; if (!p) throw new Error('no piece ' + name);
    const [l, t, R, B] = p.sliceCenter, r = p.size[0] - R, b = p.size[1] - B, s = p.sliceScale * k;
    const bw = `${t * s}px ${r * s}px ${b * s}px ${l * s}px`;
    if (tint) {   // a white piece tinted (ImageColor3): the piece becomes a mask over the colour
      return O.abs(parent, x, y, w, h, `box-sizing:border-box;background:${tint};-webkit-mask-box-image:url(${PX}${name}.png) ${t} ${r} ${b} ${l} / ${bw} stretch;${style}`);
    }
    return O.abs(parent, x, y, w, h, `box-sizing:border-box;border-style:solid;border-width:${bw};border-image:url(${PX}${name}.png) ${t} ${r} ${b} ${l} fill / ${bw} stretch;${style}`);
  };
  // standalone ornament: its anchor lands on (rx, ry); k scales the display size
  O.image = (parent, name, rx, ry, { k = 1, style = '', cls = '' } = {}) => {
    const p = MAN.pieces[name]; if (!p) throw new Error('no piece ' + name);
    const sc = k / MAN.scale, a = p.anchor || [p.size[0] / 2, p.size[1] / 2];
    const e = O.el(parent, 'img', `position:absolute;left:${rx - a[0] * sc}px;top:${ry - a[1] * sc}px;width:${p.size[0] * sc}px;height:${p.size[1] * sc}px;${style}`);
    e.src = PX + name + '.png'; if (cls) e.className = cls; return e;
  };
  O.tile = (parent, name, x, y, w, h, { k = 1, style = '' } = {}) => {
    const p = MAN.pieces[name];
    return O.abs(parent, x, y, w, h, `background:url(${PX}${name}.png) 0 0/${p.tileSize[0] * k}px ${p.tileSize[1] * k}px repeat;${style}`);
  };
  // atlas sprite tinted with a colour (white sprites), additive by default
  O.sprite = (parent, name, cx, cy, w, h, { color = '#fff', alpha = 1, add = true, rot = 0, style = '' } = {}) => {
    const r = MAN.atlas.sprites[name]; if (!r) throw new Error('no sprite ' + name);
    const sx = w / r[2], sy = h / r[3], S = MAN.atlas.size;
    return O.abs(parent, cx - w / 2, cy - h / 2, w, h, `background:${color};opacity:${alpha};-webkit-mask:url(${PX}vfx.png) ${-r[0] * sx}px ${-r[1] * sy}px/${S[0] * sx}px ${S[1] * sy}px no-repeat;` +
      `${add ? 'mix-blend-mode:plus-lighter;' : ''}${rot ? `transform:rotate(${rot}deg);` : ''}${style}`);
  };
  O.spriteRaw = (parent, name, cx, cy, w, h, { rot = 0, style = '' } = {}) => {   // untinted (stone shards, chain links)
    const r = MAN.atlas.sprites[name], sx = w / r[2], sy = h / r[3], S = MAN.atlas.size;
    return O.abs(parent, cx - w / 2, cy - h / 2, w, h, `background:url(${PX}vfx.png) ${-r[0] * sx}px ${-r[1] * sy}px/${S[0] * sx}px ${S[1] * sy}px no-repeat;${rot ? `transform:rotate(${rot}deg);` : ''}${style}`);
  };

  // ------------------------------------------------------------------------------------------------ text
  O.esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
  // numbers: digit runs (with . , e + - x ^ /) in Sarpanch, words / units in Montserrat Bold (DESIGN 9.9)
  O.nf = (s, unitColor) => O.esc(s).replace(/([+\-]?e?[0-9][0-9.,]*(?:e[0-9][0-9.,]*)*%?)|([A-Za-z×][A-Za-z/]*)/g, (m, num, word) =>
    num ? `<span class="nr">${num}</span>` : `<span class="nw"${unitColor ? ` style="color:${unitColor}"` : ''}>${word}</span>`);
  // outlined display text (UIStroke + UIGradient): an outline clone under a gradient fill
  O.tx = (text, { size = 44, font = 'title', grad = ['#fff', '#fff'], ow = 6, sh = 3, color = null, style = '', italic = true, weight = 900, family = null, tracking = 0 } = {}) => {
    const fam = family || (font === 'num' ? 'Sarpanch' : 'Montserrat');
    const f = `font:${italic && fam === 'Montserrat' ? 'italic ' : ''}${weight} ${size}px/1 ${fam};letter-spacing:${tracking}em;`;
    const fill = color ? `color:${color};` : `background:linear-gradient(180deg,${grad.map((c, i) => `${c} ${Math.round(i / (grad.length - 1) * 100)}%`).join(',')});-webkit-background-clip:text;background-clip:text;color:transparent;`;
    return `<span class="tx" style="${f}${style}"><span class="o" style="-webkit-text-stroke:${ow}px #07040c;text-shadow:0 ${sh}px 0 #07040c">${O.esc(text)}</span><span class="f" style="${fill}">${O.esc(text)}</span></span>`;
  };
  O.caps = (t, c = '#cfc6e4', size = 13) => `<span class="caps" style="font-size:${size}px;color:${c}">${O.esc(t)}</span>`;

  // ------------------------------------------------------------------------------------------------ HUD components
  O.icons = {
    home: '<path d="M4 13 L16 3 L28 13 L28 28 L19 28 L19 19 L13 19 L13 28 L4 28 Z"/>',
    trophy: '<path d="M9 4h14v7c0 5-3 9-7 9s-7-4-7-9Z M6 6h3v4a3 3 0 0 1-3-3Z M26 6h-3v4a3 3 0 0 0 3-3Z M14 20h4v4h4v4H10v-4h4Z"/>',
    gear: '<path d="M14 2h4l1 4 3 1.3 3.5-2.2 2.8 2.8L26 11.4l1.3 3 4 1v4l-4 1-1.3 3 2.2 3.5-2.8 2.8L22 26.7l-3 1.3-1 4h-4l-1-4-3-1.3-3.5 2.2-2.8-2.8L6 22.6l-1.3-3-4-1v-4l4-1L6 10.6 3.8 7.1l2.8-2.8L10 6.3l3-1.3Z M16 11a5 5 0 1 0 0 10a5 5 0 1 0 0-10Z" fill-rule="evenodd"/>',
    star: '<path d="M16 2l4 9 10 1-7.5 6.5L25 29l-9-5.5L7 29l2.5-10.5L2 12l10-1Z"/>',
    check: '<path d="M4 16l7 7L28 6" fill="none" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
    lock: '<path d="M9 14V10a7 7 0 0 1 14 0v4h2v14H7V14Z M13 14h6V10a3 3 0 0 0-6 0Z" fill-rule="evenodd"/>',
    bolt: '<path d="M18 2L6 18h8l-2 12 12-16h-8Z"/>',
    hand: '<path d="M12 4a2 2 0 0 1 4 0v10h1V6a2 2 0 0 1 4 0v9h1V9a2 2 0 0 1 4 0v11c0 6-4 10-10 10s-9-4-11-9l-2-6a2 2 0 0 1 4-1l2 4V4z"/>',
  };
  O.icon = (name, size, color, style = '') => `<svg viewBox="0 0 32 32" width="${size}" height="${size}" style="fill:${color};stroke:${color};${style}">${O.icons[name]}</svg>`;

  O.plaque = (parent, x, y, w, { label = 'POINTS · NORMAL UNIVERSE', value = 'e6.424e23', unit = 'points', rate = '6.21e24 OOMs/sec', k = 1 } = {}) => {
    const h = 76 * k;
    O.slice(parent, 'shadow', x - 20, y - 8, w + 40, h + 34, { k, style: 'opacity:.8' });
    O.slice(parent, 'plaque', x, y, w, h, { k });
    O.image(parent, 'coin', x + 20 * k, y + h / 2, { k: 0.62 * k });
    O.sprite(parent, 'glow', x + 20 * k, y + h / 2, 120 * k, 120 * k, { color: '#ffc94d', alpha: 0.35 });
    O.abs(parent, x + 70 * k, y + 14 * k, w - 100 * k, null, 'display:flex;flex-direction:column;gap:3px',
      `${O.caps(label, '#ffe3a1', 12)}<div style="display:flex;align-items:baseline;gap:${8 * k}px">${O.tx(value, { size: 34 * k, font: 'num', grad: ['#fff', '#ffe9a8', '#ffc233'], ow: 5 * k, sh: 2 })}<span style="font:700 ${16 * k}px Montserrat;color:#ffe9b8">${unit}</span></div>`);
    if (rate) {
      const rw = (rate.length > 20 ? 290 : 200) * k;
      O.slice(parent, 'toast', x + (w - rw) / 2 + 20 * k, y + h - 6 * k, rw, 30 * k, { k: 0.55 * k });
      O.abs(parent, x + (w - rw) / 2 + 20 * k, y + h - 6 * k, rw, 30 * k, `display:flex;align-items:center;justify-content:center;gap:6px;font:800 ${14 * k}px Montserrat;color:#8ff3a8`,
        `${O.icon('bolt', 13 * k, '#8ff3a8')}<span>${O.nf(rate, '#c9f7d6')}</span>`);
    }
  };
  O.dock = (parent, x, y, { k = 1, badge = '13/18' } = {}) => {
    const items = [['home', 'Home', '#5ee08a'], ['trophy', 'Trophies', '#ffc94d'], ['gear', 'Options', '#b49cff']];
    items.forEach(([ic, lab, col], i) => {
      const cx = x + 40 * k + i * 84 * k, cy = y + 40 * k;
      O.sprite(parent, 'glow', cx, cy, 110 * k, 110 * k, { color: col, alpha: 0.28 });
      O.image(parent, 'dock_medal', cx, cy, { k: 0.8 * k });
      O.abs(parent, cx - 20 * k, cy - 20 * k, 40 * k, 40 * k, 'display:grid;place-items:center', O.icon(ic, 30 * k, col, `filter:drop-shadow(0 0 6px ${col}) drop-shadow(0 2px 0 #000)`));
      O.abs(parent, cx - 50 * k, cy + 42 * k, 100 * k, null, `text-align:center;font:800 ${14 * k}px Montserrat;color:#f2eefc;text-shadow:0 2px 0 #000,0 0 6px #000`, lab);
      if (ic === 'trophy' && badge) {
        O.slice(parent, 'toast', cx - 30 * k, cy - 48 * k, 60 * k, 24 * k, { k: 0.45 * k });
        O.abs(parent, cx - 30 * k, cy - 48 * k, 60 * k, 24 * k, `display:grid;place-items:center;font:800 ${13 * k}px Sarpanch;color:#ffe08a`, badge);
      }
    });
  };
  O.gem = (parent, key, cx, cy, size, { letter = null, dim = false } = {}) => {
    const e = O.el(parent, 'img', `position:absolute;left:${cx - size / 2}px;top:${cy - size / 2}px;width:${size}px;height:${size}px;${dim ? 'filter:saturate(.25) brightness(.55);' : ''}`);
    e.src = `/gems/sprites/${key}.png`;
    if (letter) O.abs(parent, cx - size / 2, cy - size / 2, size, size, 'display:grid;place-items:center', O.tx(letter, { size: size * (letter.length > 1 ? 0.3 : 0.38), font: 'num', ow: Math.max(3, size / 16), sh: 2 }));
    return e;
  };
  O.shelf = (parent, x, y, w, { title = '7 READY', sub = 'Tap a gem to switch', gems = [['mm', 'MM'], ['ep', 'EP'], ['mp', 'MP']], chips = null, k = 1 } = {}) => {
    const h = (chips ? 138 : 88) * k;
    O.slice(parent, 'shadow', x - 16, y - 6, w + 32, h + 28, { k, style: 'opacity:.8' });
    O.slice(parent, 'shelf', x, y, w, h, { k });
    const gx0 = x + 22 * k;
    if (!chips) {
      gems.forEach(([key, L], i) => { const cx = gx0 + 22 * k + i * 42 * k, cy = y + h / 2 - 6 * k; O.image(parent, 'socket_empty', cx, cy, { k: 0.55 * k }); O.gem(parent, key, cx, cy, 44 * k, { letter: L }); });
      O.abs(parent, gx0 + gems.length * 42 * k + 16 * k, y + 16 * k, null, null, 'display:flex;flex-direction:column;gap:4px',
        `<div style="display:flex;align-items:center;gap:6px">${O.icon('bolt', 16 * k, '#ffd34d')}${O.tx(title, { size: 19 * k, grad: ['#fff', '#ffe08a', '#ffc233'], ow: 4, sh: 2 })}</div><span style="font:600 ${14 * k}px Montserrat;color:#e4ddf2">${sub}</span>`);
    } else {
      O.abs(parent, x + 24 * k, y + 12 * k, null, null, 'display:flex;align-items:center;gap:8px',
        `${O.icon('bolt', 16 * k, '#ffd34d')}${O.tx(title, { size: 18 * k, grad: ['#fff', '#ffe08a', '#ffc233'], ow: 4, sh: 2 })}<span style="font:700 ${14 * k}px Montserrat;color:#e4ddf2">${sub}</span>`);
      const step = (w - 60 * k) / gems.length;
      gems.forEach(([key, L], i) => {
        const cx = x + 30 * k + step * (i + 0.5), cy = y + 58 * k;
        O.image(parent, 'socket_empty', cx, cy, { k: 0.6 * k });
        O.gem(parent, key, cx, cy, 50 * k, { letter: L });
        const c = chips[i]; const buy = c === 'BUY', cw = Math.max(56, c.length * 9 + 20) * k;
        O.slice(parent, buy ? 'btn_gold' : 'toast', cx - cw / 2, cy + 30 * k, cw, 26 * k, { k: (buy ? 0.22 : 0.4) * k });
        O.abs(parent, cx - cw / 2, cy + 30 * k, cw, 26 * k, `display:grid;place-items:center;font:${buy ? 'italic 900' : '800'} ${13 * k}px ${buy ? 'Montserrat' : 'Sarpanch'};color:${buy ? '#2b1a02' : '#ffe9b0'};${buy ? '' : 'text-shadow:0 1px 0 #000'}`, O.esc(c));
      });
    }
  };
  // a map node: layer gem in its socket, letter, and an ornate name plate (plaque) with its value
  O.node = (parent, key, cx, cy, { size = 78, letter, name, value, sel = false, hue = '#fff', ready = false, locked = false, k = 1 } = {}) => {
    if (sel) { O.sprite(parent, 'glow', cx, cy, size * 2.4, size * 2.4, { color: hue, alpha: 0.55 }); O.sprite(parent, 'ring_thin', cx, cy, size * 1.45, size * 1.45, { color: hue, alpha: 0.9 }); }
    else O.sprite(parent, 'glow', cx, cy, size * 1.7, size * 1.7, { color: hue, alpha: locked ? 0.1 : 0.3 });
    O.gem(parent, key, cx, cy, size, { letter, dim: locked });
    if (name) {
      const pw = Math.max(118, name.length * 10.5 + 40) * k, ph = 46 * k, py = cy + size * 0.5 + 2;
      O.slice(parent, 'plaque', cx - pw / 2, py, pw, ph, { k: 0.52 * k });
      O.abs(parent, cx - pw / 2, py + 7 * k, pw, null, 'display:flex;flex-direction:column;align-items:center;gap:2px',
        `<span style="font:italic 900 ${13 * k}px Montserrat;letter-spacing:.06em;color:#f6f1ff;text-shadow:0 1px 0 #000">${O.esc(name)}</span><span style="font:700 ${13 * k}px Sarpanch;color:${locked ? '#c9bfd0' : '#fff'}">${locked ? O.icon('lock', 11, '#ffc94d') + ' ' : ''}${O.nf(value)}</span>`);
    }
    if (ready) {
      O.image(parent, 'socket_empty', cx + size * 0.38, cy - size * 0.38, { k: 0.3 });
      O.abs(parent, cx + size * 0.38 - 10, cy - size * 0.38 - 10, 20, 20, 'display:grid;place-items:center', O.icon('bolt', 13, '#ffd34d', 'filter:drop-shadow(0 0 3px #ffb300)'));
    }
  };
  O.toast = (parent, x, y, w, { title, sub, icon = 'star', color = '#ffd34d', chip = null, k = 1 } = {}) => {
    const h = 72 * k;
    O.slice(parent, 'shadow', x - 16, y - 6, w + 32, h + 28, { style: 'opacity:.8' });
    O.slice(parent, 'toast', x, y, w, h, { k: 0.8 });
    O.sprite(parent, 'glow', x + 38 * k, y + h / 2, 90 * k, 90 * k, { color, alpha: 0.4 });
    O.image(parent, 'dock_medal', x + 38 * k, y + h / 2, { k: 0.5 * k });
    O.abs(parent, x + 24 * k, y + h / 2 - 14 * k, 28 * k, 28 * k, 'display:grid;place-items:center', O.icon(icon, 22 * k, color, `filter:drop-shadow(0 0 4px ${color})`));
    O.abs(parent, x + 72 * k, y + 14 * k, w - 90 * k, null, 'display:flex;flex-direction:column;gap:5px',
      `<div style="display:flex;align-items:center;gap:8px">${O.tx(title, { size: 18 * k, weight: 800, ow: 4, sh: 2, grad: ['#fff', '#fff3cf'] })}${chip ? `<span class="chipg">${chip}</span>` : ''}</div><span style="font:600 ${14 * k}px Montserrat;color:#e8e2f5">${O.esc(sub)}</span>`);
  };
  return O;
})();
