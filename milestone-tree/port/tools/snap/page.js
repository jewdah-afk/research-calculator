// page.js - draws a snap.luau PlayerGui dump as DOM, the way the engine would lay it out (close, not exact):
// UDim2 geometry, AnchorPoint, ZIndex (Sibling), UIListLayout (flex), UIPadding, AutomaticSize, UICorner, UIStroke
// (border and text), UIGradient (linear, radial, conical; background, stroke and text), UIScale, UIShadow,
// ImageLabel (rect, tint, slice, tile), Path2D (cubic curves), RichText, ScrollingFrame, CanvasGroup.
// window.SNAP.draw(dump, assets, insets) -> Promise; assets maps "rbxassetid://N" to a URL.
(() => {
  const SNAP = {};
  const ENUM = s => (typeof s === 'string' ? s.split('.').pop() : null);
  const WEIGHT = { Thin: 100, ExtraLight: 200, Light: 300, Regular: 400, Medium: 500, SemiBold: 600, Bold: 700, ExtraBold: 800, Heavy: 900 };
  const c255 = v => Math.round(Math.max(0, Math.min(1, v)) * 255);
  const rgba = (c, a = 1) => `rgba(${c255(c.R)},${c255(c.G)},${c255(c.B)},${(+a).toFixed(3)})`;
  // plain px when there is no scale part: calc(0% + Npx) against an auto-height parent would compute to auto
  const ud = u => (!u.Scale ? `${u.Offset}px` : !u.Offset ? `${(u.Scale * 100).toFixed(4)}%` : `calc(${(u.Scale * 100).toFixed(4)}% + ${u.Offset}px)`);
  const kids = (o, cls) => o.k.filter(k => k.c === cls);
  const kid = (o, cls) => o.k.find(k => k.c === cls);
  const GUI = new Set(['Frame', 'TextLabel', 'TextButton', 'TextBox', 'ImageLabel', 'ImageButton', 'ScrollingFrame', 'CanvasGroup', 'ViewportFrame', 'VideoFrame']);
  const missing = new Set();
  let ASSETS = {};

  // ------------------------------------------------------------------------------------------------ gradients
  function seqAt(seq, t, key) { // ColorSequence / NumberSequence sample
    const ks = seq.Keypoints || seq;
    if (!ks || !ks.length) return null;
    if (t <= ks[0].Time) return ks[0][key];
    for (let i = 1; i < ks.length; i++) {
      if (t <= ks[i].Time) {
        const a = ks[i - 1], b = ks[i], f = (t - a.Time) / Math.max(1e-9, b.Time - a.Time);
        if (key === 'Value' && typeof a.Value === 'object') return { R: a.Value.R + (b.Value.R - a.Value.R) * f, G: a.Value.G + (b.Value.G - a.Value.G) * f, B: a.Value.B + (b.Value.B - a.Value.B) * f };
        return a[key] + (b[key] - a[key]) * f;
      }
    }
    return ks[ks.length - 1][key];
  }
  function gradCss(g, base, baseA) {
    // base colour x gradient colour; alpha = baseA x (1 - gradient transparency)
    const col = g.p.Color, tr = g.p.Transparency;
    const times = new Set([0, 1]);
    for (const k of (col && col.Keypoints) || []) times.add(k.Time);
    for (const k of (tr && (tr.Keypoints || tr)) || []) if (k && k.Time != null) times.add(k.Time);
    const ts = [...times].sort((a, b) => a - b);
    const off = g.p.Offset || { X: 0, Y: 0 };
    const type = ENUM(g.p.Type) || 'Linear';
    const rot = g.p.Rotation || 0;
    const rad = rot * Math.PI / 180, shift = type === 'Linear' ? off.X * Math.cos(rad) + off.Y * Math.sin(rad) : 0;
    const stops = ts.map(t => {
      const c = col ? seqAt(col, t, 'Value') : { R: 1, G: 1, B: 1 };
      let a = 1;
      if (tr && typeof tr === 'object' && (tr.Keypoints || Array.isArray(tr))) a = 1 - seqAt(tr, t, 'Value');
      else if (typeof tr === 'number') a = 1 - tr;
      const m = { R: c.R * base.R, G: c.G * base.G, B: c.B * base.B };
      return `${rgba(m, a * baseA)} ${((t + shift) * 100).toFixed(2)}%`;
    });
    if (type === 'Radial') return `radial-gradient(ellipse farthest-corner at ${50 + off.X * 100}% ${50 + off.Y * 100}%, ${stops.join(',')})`;
    if (type === 'Conical') return `conic-gradient(from ${rot + 90}deg, ${stops.join(',')})`;
    return `linear-gradient(${rot + 90}deg, ${stops.join(',')})`;
  }
  const enabledGrad = o => o.k.find(k => k.c === 'UIGradient' && k.p.Enabled !== false);

  // ------------------------------------------------------------------------------------------------ rich text
  const esc = s => s.replace(/&(?!(lt|gt|amp|quot|apos);)/g, '&amp;');
  function rich(s) {
    let h = '';
    const re = /<\s*(\/?)\s*([a-zA-Z]+)([^>]*)>/g;
    let last = 0, m;
    const stack = [];
    const attr = (a, n) => { const r = new RegExp(n + '\\s*=\\s*["\']([^"\']*)["\']', 'i').exec(a); return r ? r[1] : null; };
    while ((m = re.exec(s))) {
      h += esc(s.slice(last, m.index)).replace(/\n/g, '<br>');
      last = re.lastIndex;
      const close = m[1] === '/', tag = m[2].toLowerCase(), a = m[3];
      if (tag === 'br') { h += '<br>'; continue; }
      if (close) { if (['font', 'b', 'i', 'u', 's', 'stroke', 'uc', 'uppercase', 'sc', 'smallcaps', 'mark'].includes(tag)) h += '</span>'; continue; }
      let st = '';
      if (tag === 'b') st = 'font-weight:800';
      else if (tag === 'i') st = 'font-style:italic';
      else if (tag === 'u') st = 'text-decoration:underline';
      else if (tag === 's') st = 'text-decoration:line-through';
      else if (tag === 'uc' || tag === 'uppercase') st = 'text-transform:uppercase';
      else if (tag === 'sc' || tag === 'smallcaps') st = 'font-variant:small-caps';
      else if (tag === 'font') {
        const c = attr(a, 'color'), z = attr(a, 'size'), f = attr(a, 'face') || attr(a, 'family'), w = attr(a, 'weight'), tr = attr(a, 'transparency');
        if (c) st += `color:${/^#/.test(c) ? c : c.startsWith('rgb') ? c : '#' + c};`;
        if (z) st += `font-size:${z}px;`;
        if (f) st += `font-family:${/sarpanch/i.test(f) ? 'Sarpanch' : /mono/i.test(f) ? 'RobotoMono' : 'Montserrat'};`;
        if (w) st += `font-weight:${WEIGHT[w] || (/^\d+$/.test(w) ? w : 700)};`;
        if (tr) st += `opacity:${1 - tr};`;
      } else if (tag === 'stroke') {
        const c = attr(a, 'color') || '#000', t = attr(a, 'thickness') || 1;
        st = `-webkit-text-stroke:${t * 2}px ${c};paint-order:stroke fill`;
      } else if (tag === 'mark') st = `background:${attr(a, 'color') || '#ff0'}`;
      else continue;
      h += `<span style="${st}">`;
    }
    h += esc(s.slice(last)).replace(/\n/g, '<br>');
    return h;
  }

  // ------------------------------------------------------------------------------------------------ images
  const imgCache = {}, urlCache = {};
  function loadImg(url) {
    if (!imgCache[url]) imgCache[url] = new Promise(res => { const im = new Image(); im.onload = () => res(im); im.onerror = () => res(null); im.src = url; });
    return imgCache[url];
  }
  async function imageLayer(el, o) {
    const id = o.p.Image;
    if (!id) return;
    const url = ASSETS[id] || (id.startsWith('http') || id.startsWith('/') ? id : null);
    if (!url) { missing.add(id); return; }
    const im = await loadImg(url);
    if (!im) { missing.add(id); return; }
    const ro = o.p.ImageRectOffset || { X: 0, Y: 0 }, rs = o.p.ImageRectSize || { X: 0, Y: 0 };
    const sx = ro.X, sy = ro.Y, sw = rs.X > 0 ? rs.X : im.naturalWidth - sx, sh = rs.Y > 0 ? rs.Y : im.naturalHeight - sy;
    const tint = o.p.ImageColor3;
    const ck = [url, sx, sy, sw, sh, tint ? [tint.R, tint.G, tint.B].map(v => v.toFixed(3)).join() : ''].join('|');
    let dataUrl = urlCache[ck];
    if (!dataUrl) {
    const cv = document.createElement('canvas');
    cv.width = Math.max(1, Math.round(sw)); cv.height = Math.max(1, Math.round(sh));
    const x = cv.getContext('2d');
    x.drawImage(im, sx, sy, sw, sh, 0, 0, sw, sh);
    if (tint && !(tint.R === 1 && tint.G === 1 && tint.B === 1)) {
      x.globalCompositeOperation = 'multiply'; x.fillStyle = rgba(tint); x.fillRect(0, 0, sw, sh);
      x.globalCompositeOperation = 'destination-in'; x.drawImage(im, sx, sy, sw, sh, 0, 0, sw, sh);
    }
    dataUrl = urlCache[ck] = (tint && !(tint.R === 1 && tint.G === 1 && tint.B === 1)) || sx || sy || rs.X > 0 ? cv.toDataURL() : url;
    }
    const layer = document.createElement('div');
    layer.className = 'img';
    const st = ENUM(o.p.ScaleType) || 'Stretch';
    let css = `position:absolute;inset:0;pointer-events:none;opacity:${1 - (o.p.ImageTransparency || 0)};`;
    const grad = enabledGrad(o);
    if (st === 'Slice') {
      const sc = o.p.SliceCenter || { Min: { X: 0, Y: 0 }, Max: { X: sw, Y: sh } };
      const l = sc.Min.X, t = sc.Min.Y, r = sw - sc.Max.X, b = sh - sc.Max.Y, k = o.p.SliceScale || 1;
      css += `border-style:solid;border-width:${t * k}px ${r * k}px ${b * k}px ${l * k}px;border-image:url(${dataUrl}) ${t} ${r} ${b} ${l} fill stretch;`;
    } else if (st === 'Tile') {
      const ts = o.p.TileSize || { X: { Scale: 1, Offset: 0 }, Y: { Scale: 1, Offset: 0 } };
      css += `background:url(${dataUrl}) 0 0/${ud(ts.X)} ${ud(ts.Y)} repeat;`;
    } else {
      const size = st === 'Fit' ? 'contain' : st === 'Crop' ? 'cover' : '100% 100%';
      css += `background:url(${dataUrl}) center/${size} no-repeat;`;
    }
    if (grad) { css += `-webkit-mask-image:${gradCss(grad, { R: 1, G: 1, B: 1 }, 1)};`; }
    layer.style.cssText = css;
    el.insertBefore(layer, el.firstChild);
  }

  // ------------------------------------------------------------------------------------------------ one object
  const pending = [];
  function build(o, parentEl, ctx) {
    if (o.c === 'Path2D') return path2d(o, parentEl);
    if (!GUI.has(o.c)) return;
    const p = o.p;
    const el = document.createElement('div');
    el.className = 'g ' + o.c;
    el.dataset.name = o.n;
    if (p.Visible === false) el.style.display = 'none';
    const size = p.Size || { X: { Scale: 0, Offset: 0 }, Y: { Scale: 0, Offset: 0 } };
    const pos = p.Position || { X: { Scale: 0, Offset: 0 }, Y: { Scale: 0, Offset: 0 } };
    const ap = p.AnchorPoint || { X: 0, Y: 0 };
    const auto = ENUM(p.AutomaticSize) || 'None';
    const autoX = auto === 'X' || auto === 'XY', autoY = auto === 'Y' || auto === 'XY';
    const list = kid(o, 'UIListLayout');
    const pad = kid(o, 'UIPadding');
    const scale = kid(o, 'UIScale');
    let s = el.style;
    s.position = ctx.inList ? 'relative' : 'absolute';
    s.boxSizing = 'border-box';
    if (!ctx.inList) { s.left = ud(pos.X); s.top = ud(pos.Y); }
    s.width = autoX ? 'max-content' : ud(size.X);
    s.height = autoY ? 'auto' : ud(size.Y);
    if (autoX) s.minWidth = ud(size.X);
    if (autoY) s.minHeight = ud(size.Y);
    s.flex = 'none';
    s.zIndex = String(p.ZIndex != null ? p.ZIndex : 1);
    s.isolation = 'isolate';
    const tf = [];
    if (!ctx.inList && (ap.X || ap.Y)) tf.push(`translate(${-ap.X * 100}%,${-ap.Y * 100}%)`);
    if (p.Rotation) tf.push(`rotate(${p.Rotation}deg)`);
    if (scale && scale.p.Scale != null && scale.p.Scale !== 1) tf.push(`scale(${scale.p.Scale})`);
    if (tf.length) s.transform = tf.join(' ');
    if (p.ClipsDescendants || o.c === 'ScrollingFrame' || o.c === 'CanvasGroup') s.overflow = 'hidden';
    if (o.c === 'CanvasGroup') s.opacity = String(1 - (p.GroupTransparency || 0));
    // background
    const bgA = 1 - (p.BackgroundTransparency != null ? p.BackgroundTransparency : 0);
    const bg = p.BackgroundColor3 || { R: 1, G: 1, B: 1 };
    const isText = /^Text/.test(o.c);
    const grad = enabledGrad(o);
    if (bgA > 0) s.background = grad && !(isText && p.BackgroundTransparency >= 1) ? gradCss(grad, bg, bgA) : rgba(bg, bgA);
    // shadow
    const sh = kid(o, 'UIShadow');
    const shadows = [];
    if (sh && sh.p.Enabled !== false) {
      const off = sh.p.Offset || { X: { Offset: 0 }, Y: { Offset: 0 } };
      const ox = off.X && off.X.Offset != null ? off.X.Offset : off.X || 0, oy = off.Y && off.Y.Offset != null ? off.Y.Offset : off.Y || 0;
      shadows.push(`${ox}px ${oy}px ${(sh.p.BlurRadius && sh.p.BlurRadius.Offset != null ? sh.p.BlurRadius.Offset : sh.p.BlurRadius) || 8}px ${rgba(sh.p.Color || { R: 0, G: 0, B: 0 }, 1 - (sh.p.Transparency || 0))}`);
    }
    if (shadows.length) s.boxShadow = shadows.join(',');
    // content box
    const inner = document.createElement('div');
    inner.className = 'in';
    const is = inner.style;
    if (pad) {
      const P = k => (pad.p[k] ? pad.p[k] : { Scale: 0, Offset: 0 });
      s.padding = `${P('PaddingTop').Offset}px ${P('PaddingRight').Offset}px ${P('PaddingBottom').Offset}px ${P('PaddingLeft').Offset}px`;
    }
    // AutomaticSize grows to fit offset-placed children too (engine rule); CSS max-content ignores absolute children,
    // so those frames are measured after layout (grow())
    el.dataset.fx = !pos.X.Scale && !size.X.Scale ? '1' : '0';
    el.dataset.fy = !pos.Y.Scale && !size.Y.Scale ? '1' : '0';
    if ((autoX || autoY) && !list) el.dataset.auto = (autoX ? 'x' : '') + (autoY ? 'y' : '');
    const flowInner = list || autoX || autoY || isText;
    if (flowInner) {
      is.position = 'relative';
      is.width = autoX ? 'max-content' : '100%';
      is.height = autoY ? 'auto' : '100%';
      if (autoX) is.minWidth = '100%';
      if (autoY) is.minHeight = '100%';
    } else {
      is.position = 'absolute';
      is.inset = s.padding ? s.padding.split(' ').join(' ') : '0';
    }
    if (o.c === 'ScrollingFrame') {
      const cp = p.CanvasPosition || { X: 0, Y: 0 };
      is.position = 'absolute'; is.left = `${-cp.X}px`; is.top = `${-cp.Y}px`; is.right = 'auto'; is.width = '100%';
      const acs = ENUM(p.AutomaticCanvasSize);
      is.height = acs === 'Y' || acs === 'XY' ? 'auto' : (p.CanvasSize ? ud(p.CanvasSize.Y) : '100%');
      if (acs === 'Y' || acs === 'XY') is.minHeight = '100%';
    }
    if (list) {
      const dir = ENUM(list.p.FillDirection) === 'Horizontal' ? 'row' : 'column';
      is.display = 'flex';
      is.flexDirection = dir;
      if (list.p.Wraps) is.flexWrap = 'wrap';
      const gap = list.p.Padding ? list.p.Padding.Offset : 0;
      is.gap = `${gap}px`;
      const H = { Left: 'flex-start', Center: 'center', Right: 'flex-end' }[ENUM(list.p.HorizontalAlignment) || 'Left'];
      const V = { Top: 'flex-start', Center: 'center', Bottom: 'flex-end' }[ENUM(list.p.VerticalAlignment) || 'Top'];
      if (dir === 'row') { is.justifyContent = H; is.alignItems = V; } else { is.justifyContent = V; is.alignItems = H; }
    }
    el.appendChild(inner);
    // text
    if (isText && p.Text != null && p.Text !== '') {
      const t = document.createElement('div');
      t.className = 'tx';
      const ts = t.style;
      const f = p.FontFace || {};
      ts.fontFamily = /Sarpanch/.test(f.Family || '') ? 'Sarpanch' : /Mono/i.test(f.Family || '') ? 'RobotoMono' : 'Montserrat';
      ts.fontWeight = WEIGHT[ENUM(f.Weight) || 'Regular'] || 400;
      ts.fontStyle = ENUM(f.Style) === 'Italic' ? 'italic' : 'normal';
      ts.fontSize = `${p.TextSize || 14}px`;
      ts.lineHeight = String(p.LineHeight || 1);
      const tc = p.TextColor3 || { R: 0, G: 0, B: 0 };
      ts.color = rgba(tc, 1 - (p.TextTransparency || 0));
      ts.whiteSpace = p.TextWrapped ? 'pre-wrap' : 'pre';
      ts.overflowWrap = 'break-word';
      ts.textAlign = { Left: 'left', Center: 'center', Right: 'right' }[ENUM(p.TextXAlignment) || 'Center'];
      if (ENUM(p.TextTruncate) === 'AtEnd') { ts.overflow = 'hidden'; ts.textOverflow = 'ellipsis'; }
      ts.width = autoX ? 'max-content' : '100%';
      const y = ENUM(p.TextYAlignment) || 'Center';
      is.display = 'flex'; is.flexDirection = 'column';
      is.justifyContent = { Top: 'flex-start', Center: 'center', Bottom: 'flex-end' }[y];
      if (p.RichText) t.innerHTML = rich(p.Text); else t.textContent = p.Text;
      const strokes = o.k.filter(k => k.c === 'UIStroke' && ENUM(k.p.ApplyStrokeMode) === 'Contextual' && k.p.Enabled !== false);
      if (strokes.length) {
        const k = strokes[0];
        ts.webkitTextStroke = `${(k.p.Thickness || 1) * 2}px ${rgba(k.p.Color || { R: 0, G: 0, B: 0 }, 1 - (k.p.Transparency || 0))}`;
        ts.paintOrder = 'stroke fill';
      }
      if (p.TextStrokeTransparency != null && p.TextStrokeTransparency < 1) ts.textShadow = `0 0 1px ${rgba(p.TextStrokeColor3 || { R: 0, G: 0, B: 0 }, 1 - p.TextStrokeTransparency)}`;
      if (grad && p.BackgroundTransparency >= 1) {
        ts.backgroundImage = gradCss(grad, tc, 1 - (p.TextTransparency || 0));
        ts.webkitBackgroundClip = 'text'; ts.backgroundClip = 'text'; ts.color = 'transparent';
        if (strokes.length) { ts.webkitTextStroke = ''; ts.textShadow = `0 0 0 transparent`; }
      }
      if (p.TextScaled) { t.dataset.scaled = '1'; }
      inner.appendChild(t);
    }
    // image
    if (/^Image/.test(o.c)) pending.push(imageLayer(el, o));
    // border strokes (drawn as an overlay ring outside the box)
    for (const k of o.k.filter(k => k.c === 'UIStroke' && ENUM(k.p.ApplyStrokeMode) !== 'Contextual' && k.p.Enabled !== false)) {
      const th = k.p.Thickness || 1;
      if (isText && !(bgA > 0) && ENUM(k.p.ApplyStrokeMode) !== 'Border') continue;
      const ring = document.createElement('div');
      ring.className = 'stroke';
      const sg = enabledGrad(k);
      const col = k.p.Color || { R: 0, G: 0, B: 0 };
      const posn = ENUM(k.p.BorderStrokePosition) || 'Outer';
      const out = posn === 'Inner' ? 0 : posn === 'Center' ? th / 2 : th;
      ring.style.cssText = `position:absolute;inset:${-out}px;padding:${th}px;pointer-events:none;z-index:0;opacity:${1 - (k.p.Transparency || 0)};` +
        `background:${sg ? gradCss(sg, col, 1) : rgba(col)};-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude;`;
      ring.dataset.out = out;
      el.appendChild(ring);
    }
    const cr = kid(o, 'UICorner');
    if (cr) el.dataset.corner = JSON.stringify(cr.p.CornerRadius || { Scale: 0, Offset: 8 });
    const ar = kid(o, 'UIAspectRatioConstraint');
    if (ar) s.aspectRatio = String(ar.p.AspectRatio || 1);
    const sc = kid(o, 'UISizeConstraint');
    if (sc) { if (sc.p.MaxSize) { s.maxWidth = `${Math.min(1e5, sc.p.MaxSize.X)}px`; s.maxHeight = `${Math.min(1e5, sc.p.MaxSize.Y)}px`; } if (sc.p.MinSize) { s.minWidth = `${sc.p.MinSize.X}px`; s.minHeight = `${sc.p.MinSize.Y}px`; } }
    // children in order: LayoutOrder for lists
    let ch = o.k;
    if (list) {
      const byName = ENUM(list.p.SortOrder) === 'Name';
      ch = ch.map((k, i) => [k, i]).sort((a, b) => byName ? (a[0].n < b[0].n ? -1 : a[0].n > b[0].n ? 1 : a[1] - b[1]) : ((a[0].p.LayoutOrder || 0) - (b[0].p.LayoutOrder || 0)) || a[1] - b[1]).map(x => x[0]);
    }
    for (const k of ch) build(k, inner, { inList: !!list });
    parentEl.appendChild(el);
    return el;
  }

  function path2d(o, parentEl) {
    const pts = o.p.__points;
    if (!pts || pts.length < 2 || o.p.Visible === false) return;
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'path2d');
    svg.style.cssText = `position:absolute;inset:0;width:100%;height:100%;overflow:visible;pointer-events:none;z-index:${o.p.ZIndex || 1}`;
    svg.dataset.pts = JSON.stringify(pts);
    svg.dataset.th = o.p.Thickness || 1;
    svg.dataset.col = rgba(o.p.Color3 || { R: 1, G: 1, B: 1 }, 1 - (o.p.Transparency || 0));
    parentEl.appendChild(svg);
  }
  function drawPaths() {
    for (const svg of document.querySelectorAll('svg.path2d')) {
      const w = svg.clientWidth || svg.parentElement.clientWidth, h = svg.clientHeight || svg.parentElement.clientHeight;
      const pts = JSON.parse(svg.dataset.pts);
      const P = u => [u.X.Scale * w + u.X.Offset, u.Y.Scale * h + u.Y.Offset];
      let d = '';
      pts.forEach((pt, i) => {
        const [x, y] = P(pt.Position);
        if (i === 0) { d += `M${x} ${y}`; return; }
        const prev = pts[i - 1], [px, py] = P(prev.Position);
        const rt = prev.RightTangent ? P(prev.RightTangent) : [0, 0], lt = pt.LeftTangent ? P(pt.LeftTangent) : [0, 0];
        d += ` C${px + rt[0]} ${py + rt[1]} ${x + lt[0]} ${y + lt[1]} ${x} ${y}`;
      });
      svg.innerHTML = `<path d="${d}" fill="none" stroke="${svg.dataset.col}" stroke-width="${svg.dataset.th}" stroke-linecap="round" stroke-linejoin="round"/>`;
    }
  }
  function grow() {
    const els = [...document.querySelectorAll('[data-auto]')];
    const depth = e => { let d = 0; for (let x = e; x; x = x.parentElement) d++; return d; };
    els.sort((a, b) => depth(b) - depth(a));
    for (const el of els) {
      if (el.offsetParent === null && getComputedStyle(el).position !== 'fixed') continue;
      const inner = el.querySelector(':scope > .in');
      if (!inner) continue;
      const ir = inner.getBoundingClientRect();
      let right = 0, bottom = 0;
      for (const c of inner.querySelectorAll(':scope > .g')) {
        if (getComputedStyle(c).display === 'none') continue;
        const r = c.getBoundingClientRect();
        if (c.dataset.fx === '1') right = Math.max(right, r.right - ir.left);
        if (c.dataset.fy === '1') bottom = Math.max(bottom, r.bottom - ir.top);
      }
      const cs = getComputedStyle(el);
      const padX = parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight), padY = parseFloat(cs.paddingTop) + parseFloat(cs.paddingBottom);
      if (el.dataset.auto.includes('x') && right + padX > el.offsetWidth + 0.5) el.style.minWidth = `${Math.ceil(right + padX)}px`;
      if (el.dataset.auto.includes('y') && bottom + padY > el.offsetHeight + 0.5) el.style.minHeight = `${Math.ceil(bottom + padY)}px`;
    }
  }
  function corners() {
    for (const el of document.querySelectorAll('[data-corner]')) {
      const c = JSON.parse(el.dataset.corner), w = el.offsetWidth, h = el.offsetHeight;
      const r = Math.min(Math.min(w, h) / 2, c.Scale * Math.min(w, h) + c.Offset);
      el.style.borderRadius = `${r}px`;
      for (const ring of el.querySelectorAll(':scope > .stroke')) ring.style.borderRadius = `${r + +ring.dataset.out}px`;
      for (const im of el.querySelectorAll(':scope > .img')) im.style.borderRadius = `${r}px`;
    }
  }
  function scaled() {
    for (const t of document.querySelectorAll('.tx[data-scaled]')) {
      const box = t.parentElement;
      let size = 100;
      t.style.fontSize = size + 'px';
      while (size > 6 && (t.scrollWidth > box.clientWidth + 1 || t.scrollHeight > box.clientHeight + 1)) { size -= 1; t.style.fontSize = size + 'px'; }
    }
  }

  SNAP.draw = async (dump, assets, insets) => {
    ASSETS = assets;
    const root = document.getElementById('root');
    root.innerHTML = ''; pending.length = 0;
    root.style.cssText = `position:relative;width:${dump.w}px;height:${dump.h}px;overflow:hidden;background:#000`;
    const guis = dump.gui.k.filter(g => g.c === 'ScreenGui' && g.p.Enabled !== false).map((g, i) => [g, i])
      .sort((a, b) => (a[0].p.DisplayOrder || 0) - (b[0].p.DisplayOrder || 0) || a[1] - b[1]).map(x => x[0]);
    for (const g of guis) {
      const r = insets[ENUM(g.p.ScreenInsets) || 'CoreUISafeInsets'] || [0, 0, dump.w, dump.h];
      const sg = document.createElement('div');
      sg.className = 'screen'; sg.dataset.name = g.n;
      sg.style.cssText = `position:absolute;left:${r[0]}px;top:${r[1]}px;width:${r[2]}px;height:${r[3]}px;`;
      root.appendChild(sg);
      for (const k of g.k) build(k, sg, {});
    }
    await Promise.all(pending);
    await document.fonts.ready;
    grow(); grow(); corners(); scaled(); drawPaths();
    return { missing: [...missing] };
  };
  window.SNAP = SNAP;
})();
