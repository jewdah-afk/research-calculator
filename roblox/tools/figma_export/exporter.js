// Peckwood Figma -> Roblox layout exporter (READ-ONLY use_figma script; it never edits the file).
// Replace __ROOT__ with a node id and __PART__ with 0,1,2...; each call returns one <=19000 char slice of the
// compact JSON {d: dictionary, t: tree}, prefixed "PWX|<root>|<part>|<nparts>|". collect.py reassembles the
// slices from the session transcripts and build_layouts.py turns them into Luau layout modules.
const ROOT = '__ROOT__', PART = __PART__, CH = 19000;
const page = await figma.getNodeByIdAsync('7:7'); await figma.setCurrentPageAsync(page);
const hx = c => [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
const Q = v => Math.round(v * 10) / 10, Q2 = v => Math.round(v * 100) / 100, Q3 = v => Math.round(v * 1000) / 1000;
const D = [], DM = {};
const I = v => { const k = JSON.stringify(v); if (!(k in DM)) { DM[k] = D.length; D.push(v); } return DM[k]; };
function paints(arr) {
  if (!arr || arr === figma.mixed) return undefined; const o = [];
  for (const p of arr) {
    if (p.visible === false) continue; const op = Q2(p.opacity ?? 1);
    if (p.type === 'SOLID') o.push(op < 1 ? [hx(p.color), op] : hx(p.color));
    else if (p.type.startsWith('GRADIENT')) o.push([p.type.slice(9, 10).toLowerCase(), p.gradientTransform.flat().map(Q3), p.gradientStops.map(s => s.color.a < 1 ? [hx(s.color), Q2(s.position), Q2(s.color.a)] : [hx(s.color), Q2(s.position)]), op]);
    else if (p.type === 'IMAGE') o.push(['i', (p.imageHash || '').slice(0, 6), p.scaleMode[0], Q2(p.scalingFactor || 1), op]);
  }
  return o.length ? o : undefined;
}
function fx(n) {
  if (!n.effects || !n.effects.length) return undefined; const o = [];
  for (const e of n.effects) {
    if (e.visible === false) continue;
    if (e.type === 'DROP_SHADOW' || e.type === 'INNER_SHADOW') o.push([e.type[0], Q(e.offset.x), Q(e.offset.y), Q(e.radius), hx(e.color), Q2(e.color.a), Q(e.spread || 0)]);
    else o.push([e.type.slice(0, 2), Q(e.radius || 0)]);
  }
  return o.length ? o : undefined;
}
const TC = { FRAME: 'F', RECTANGLE: 'R', TEXT: 'T', ELLIPSE: 'E', VECTOR: 'V', GROUP: 'G', STAR: 'S', INSTANCE: 'I', COMPONENT: 'C', BOOLEAN_OPERATION: 'B', LINE: 'L', POLYGON: 'P', COMPONENT_SET: 'X' };
function node(n) {
  if (n.visible === false) return null;
  const d = { t: TC[n.type] || n.type, n: n.name.length > 3 ? I(n.name) : n.name, p: [Q(n.x), Q(n.y), Q(n.width), Q(n.height)] };
  if (n.rotation && Math.abs(n.rotation) > 0.01) { const m = n.relativeTransform; d.rot = Q(n.rotation); d.cc = [Q(m[0][2] + m[0][0] * n.width / 2 + m[0][1] * n.height / 2), Q(m[1][2] + m[1][0] * n.width / 2 + m[1][1] * n.height / 2)]; }
  if (n.opacity != null && n.opacity < 1) d.o = Q2(n.opacity);
  const f = paints(n.fills); if (f) d.f = I(f);
  if ('strokes' in n && n.strokes.length) { const s = paints(n.strokes); if (s) d.s = I([s, Q2(n.strokeWeight === figma.mixed ? (n.strokeTopWeight || 1) : n.strokeWeight), (n.strokeAlign || 'C')[0]]); }
  if ('cornerRadius' in n) { if (n.cornerRadius === figma.mixed) d.r = [n.topLeftRadius, n.topRightRadius, n.bottomRightRadius, n.bottomLeftRadius].map(Q); else if (n.cornerRadius) d.r = Q(n.cornerRadius); }
  const e = fx(n); if (e) d.e = I(e);
  if (n.clipsContent) d.c = 1;
  if (n.type === 'TEXT') {
    d.tx = n.characters; d.fs = n.fontSize === figma.mixed ? null : Q(n.fontSize);
    const fn = n.fontName === figma.mixed ? 'mixed' : n.fontName.family + '/' + n.fontName.style; if (fn !== 'Fredoka One/Regular') d.fn = fn;
    d.a = n.textAlignHorizontal[0] + n.textAlignVertical[0] + n.textAutoResize[0];
    if (n.fills === figma.mixed || n.fontSize === figma.mixed) d.seg = n.getStyledTextSegments(['fills', 'fontSize']).map(s => [s.characters, Q(s.fontSize), paints(s.fills)]);
    if (n.lineHeight && n.lineHeight !== figma.mixed && n.lineHeight.unit !== 'AUTO') d.lh = [n.lineHeight.unit[0], Q(n.lineHeight.value)];
    if (n.letterSpacing && n.letterSpacing !== figma.mixed && n.letterSpacing.value) d.ls = [n.letterSpacing.unit[0], Q(n.letterSpacing.value)];
    if (n.textCase && n.textCase !== figma.mixed && n.textCase !== 'ORIGINAL') d.tc = n.textCase[0];
  }
  if (n.type === 'INSTANCE' && n.mainComponent) d.mc = n.mainComponent.id;
  if (/^glyph\//.test(n.name) || n.name === 'growth chevrons') { const vs = n.findAll(c => c.type === 'VECTOR'); if (vs.length > 1 && vs[1].strokes[0]) d.gc = hx(vs[1].strokes[0].color); if (vs.length) d.gsw = [Q(vs[0].strokeWeight), Q(vs[vs.length - 1].strokeWeight)]; delete d.f; return d; }
  if (n.name === 'swoosh') return d;
  if (['VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'POLYGON', 'LINE'].includes(n.type)) return d;
  if ('children' in n && n.children.length) { const k = []; for (const c of n.children) { const x = node(c); if (x) k.push(x); } if (k.length) d.k = k; }
  return d;
}
const r = await figma.getNodeByIdAsync(ROOT);
const tree = r ? node(r) : null;
const s = JSON.stringify({ d: D, t: tree });
const np = Math.ceil(s.length / CH);
return 'PWX|' + ROOT + '|' + PART + '|' + np + '|' + s.slice(PART * CH, (PART + 1) * CH);
