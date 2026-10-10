// Peckwood Figma kit (paste at the top of EVERY use_figma script; plain JS, top-level await is fine).
// Builds the owner-approved squared style: game Kit.button keys, steel plates, square-top windows.
// Reference window: "Window / Sunflower Tree" (node 239:309) on the Windows board (239:307), page UI v2 (7:7).
const page = await figma.getNodeByIdAsync('7:7'); await figma.setCurrentPageAsync(page);
await Promise.all([['Fredoka One','Regular'],['Fredoka','SemiBold'],['Fredoka','Medium']].map(([family,style])=>figma.loadFontAsync({family,style})));
const KIT_REFS = await Promise.all(['213:10','171:198','171:7','171:8'].map(id=>figma.getNodeByIdAsync(id)));
const [KIT_STRIP, plateRef, winRef, headRef] = KIT_REFS;
const J = o => JSON.parse(JSON.stringify(o));
const VT = plateRef.fills[0].gradientTransform;            // vertical top->bottom
const HT = headRef.fills[0].gradientTransform;             // horizontal left->right
// ICON[name] = imageHash. Sources: the shared strip (213:10, children "src/<name>") + any frame named "icons/..." on the Windows board.
const ICON = {};
for (const c of KIT_STRIP.children) if (c.fills && c.fills[0] && c.fills[0].imageHash) ICON[c.name.replace(/^src\//,'')] = c.fills[0].imageHash;
{ const wb = await figma.getNodeByIdAsync('239:307'); if (wb) for (const f of wb.findAll(n=>n.type==='FRAME' && n.name.startsWith('icons/'))) for (const c of f.children) if (c.fills && c.fills[0] && c.fills[0].imageHash) ICON[c.name.replace(/^src\//,'')] = c.fills[0].imageHash; }
const hx = h => ({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255});
const INK = {r:11/255,g:12/255,b:16/255};
const grad = (cols,k=1,a=1,tr=VT) => ({type:'GRADIENT_LINEAR',gradientTransform:J(tr),gradientStops:cols.map((c,i)=>{const x=hx(c);return {color:{r:x.r*k,g:x.g*k,b:x.b*k,a},position:i/(cols.length-1)};})});
const hgrad = (cols) => grad(cols,1,1,HT);
const STRIPES = () => ({type:'IMAGE',imageHash:ICON['ui_stripes'],scaleMode:'TILE',scalingFactor:0.5,opacity:0.12});
const HALFTONE = (op=0.16) => ({type:'IMAGE',imageHash:ICON['ui_halftone'],scaleMode:'TILE',scalingFactor:0.5,opacity:op});
const LATT = op => { const f=J(plateRef.fills.find(f=>f.type==='IMAGE'&&f.imageHash.startsWith('cd6d57ab'))); f.opacity=op; return f; };
const SHADOW = (y,r,a) => ({type:'DROP_SHADOW',color:{r:0,g:0,b:0,a},offset:{x:0,y},radius:r,spread:0,visible:true,blendMode:'NORMAL'});
const INKDS = y => ({type:'DROP_SHADOW',color:{...INK,a:1},offset:{x:0,y},radius:0,spread:0,visible:true,blendMode:'NORMAL'});
const INNER = (y,r,a,col='#000000') => ({type:'INNER_SHADOW',color:{...hx(col),a},offset:{x:0,y},radius:r,spread:0,visible:true,blendMode:'NORMAL'});
const PAL = {
  green:['#9dff8a','#3fcf4a','#1e8a2a'], blue:['#8fd8ff','#3a9cf0','#1f5fb4'], gold:['#ffe58a','#f2b331','#b86e0c'],
  red:['#ff9a8a','#ec4a3c','#a8201a'], violet:['#e3c2ff','#a466f5','#6a2fc4'], teal:['#8af0dc','#2fb39c','#17705f'],
  cyan:['#9cecff','#2fb8e8','#13739e'], pink:['#ffc2e1','#e8649f','#9e2a62'], amber:['#ffd36b','#e89a1e','#9c5a08'],
  brown:['#e0b07a','#a8683a','#6a3a1a'], olive:['#d8ef7a','#86b832','#4c7418'], stone:['#c3cad6','#808a9c','#4a5262'],
  grey:['#7a8496','#4f5868','#343b47'], steel:['#566174','#394252','#262c37'] };
// window header themes (horizontal gradients, like the existing square-top headers)
const THEME = {
  seeds:['#3f9a2a','#7fe05a','#c8ff9a'], mine:['#2b3a8f','#4fd2ff','#ffc22e'], fishing:['#13739e','#2fb8e8','#9cecff'],
  aquarium:['#17507a','#2fa8c8','#8af0dc'], market:['#9c5a08','#e89a1e','#ffe08a'], gold:['#b86e0c','#f2b331','#ffe58a'],
  archivist:['#4a1f8a','#a466f5','#ffc2e1'], desert:['#a8640a','#e8a42a','#ffe08a'], crow:['#262c37','#566174','#c3cad6'],
  nest:['#6a3a1a','#a8683a','#e0b07a'], expedition:['#a8201a','#ec4a3c','#ffb08a'], echo:['#9e2a62','#e8649f','#ffc2e1'] };
// ---------- primitives ----------
function R(p,n,x,y,w,h,r,fills){const e=figma.createRectangle(); e.name=n; e.resize(Math.max(0.01,w),Math.max(0.01,h)); e.x=x; e.y=y; e.cornerRadius=r||0; e.fills=fills||[]; p.appendChild(e); return e;}
function F(p,n,x,y,w,h,r,fills,clip){const e=figma.createFrame(); e.name=n; e.resize(Math.max(0.01,w),Math.max(0.01,h)); e.cornerRadius=r||0; e.fills=fills||[]; e.clipsContent=!!clip; p.appendChild(e); e.x=x; e.y=y; return e;}
function STROKE(n,w=2){ n.strokes=[{type:'SOLID',color:INK}]; n.strokeWeight=w; n.strokeAlign='INSIDE'; return n; }
// text: ALL UI text is Fredoka One (the game's Kit.text uses FredokaOne for everything).
//   display/titles: T(p,s,size)  -> white, ink outline ~10% of size, hard ink drop.
//   normal/body text: BODY(p,s,size,{x,y,w,col})  -> Fredoka One, light ink outline 1.2, 1px ink drop, muted colour.
function T(p,s,size,o={}){const t=figma.createText(); t.name=o.name||String(s).slice(0,28); t.fontName={family:o.fam||'Fredoka One',style:o.st||'Regular'}; t.fontSize=size; t.characters=String(s); t.fills=[o.grad?grad(o.grad):{type:'SOLID',color:hx(o.col||'#ffffff'),opacity:o.op??1}]; if(o.ol!==0){t.strokes=[{type:'SOLID',color:INK}]; t.strokeWeight=o.ol??Math.max(1.3,+(size*0.1).toFixed(1)); t.strokeAlign='OUTSIDE'; t.effects=[INKDS(o.sh??Math.max(1,Math.round(size*0.08)))];} p.appendChild(t); if(o.w){t.textAutoResize='HEIGHT'; t.resize(o.w,t.height); t.textAlignHorizontal=o.al||'CENTER';} t.x=o.x||0; t.y=o.y||0; return t;}
function BODY(p,s,size,o={}){ return T(p,s,size,{...o,col:o.col||'#c9d2e3',ol:1.2,sh:1}); }
function textW(s,size,fam='Fredoka One',st='Regular'){const t=figma.createText(); t.fontName={family:fam,style:st}; t.fontSize=size; t.characters=String(s); const w=t.width; t.remove(); return w;}
function ICO(p,name,s,x,y,o={}){ if(!ICON[name]) throw new Error('missing icon '+name+' (upload it first into your icons/<window> frame)'); const r=R(p,'ico/'+name,x,y,s,s,0,[{type:'IMAGE',imageHash:ICON[name],scaleMode:'FIT'}]); r.effects=[{type:'DROP_SHADOW',color:{...INK,a:0.5},offset:{x:0,y:1.5},radius:0,spread:0,visible:true,blendMode:'NORMAL'}]; if(o.op!=null) r.opacity=o.op; return r;}
// ---------- the game's Kit.button (COMPANIONS header = shading reference) ----------
// ink body (r4) -> lip = face colours x0.58 shifted down D -> face (r2.5, stripes 12%) -> gloss cap (.45 -> .04, upper 42%).
// pressed: use PRESS(k) (whole key drops D, lip hidden). Dark faces: gloss .16-.2.
function KEY(p,n,x,y,w,h,cols,o={}){const D=o.d??6; const k=F(p,n,x,y,w,h,0,[]); R(k,'ink body',0,0,w,h,o.r??4,[{type:'SOLID',color:INK}]); R(k,'lip',3,3+D,w-6,h-6-D,2.5,[grad(cols,0.58)]); const f=F(k,'face',3,3,w-6,h-6-D,2.5,[grad(cols),STRIPES()],true); R(f,'gloss cap',3,2,w-12,Math.floor((h-6-D)*0.42),2,[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:o.gloss??0.45},position:0},{color:{r:1,g:1,b:1,a:0.04},position:1}]}]); if(o.shadow!==false) k.effects=[SHADOW(4,8,0.35)]; return {k,f};}
// PRESSED state (owner-approved): the WHOLE key drops by the lip depth D: ink body and face move down together,
// the body loses D of height, the lip is hidden. No black band above the face, no lip below. Call on a KEY/BTN result.
function PRESS(keyFrame,D=6){const b=keyFrame.findChild(n=>n.name==='ink body'), l=keyFrame.findChild(n=>n.name==='lip'), f=keyFrame.findChild(n=>n.name==='face'); b.y=D; b.resize(b.width,b.height-D); f.y=D+3; if(l) l.visible=false; keyFrame.effects=[SHADOW(1,3,0.3)]; return keyFrame;}
// key with centred icon + label (e.g. BUY 30K, CLAIM, ACCEPT)
function BTN(p,n,x,y,w,h,cols,label,o={}){const {k,f}=KEY(p,n,x,y,w,h,cols,o); const size=o.size||Math.round((h-6-(o.d??6))*0.5); const iw=o.icon?Math.round(size*1.35):0; const tw=label?textW(label,size):0; const gap=(o.icon&&label)?8:0; const total=iw+gap+tw; let x0=(f.width-total)/2; if(o.icon){ ICO(f,o.icon,iw,x0,(f.height-iw)/2); x0+=iw+gap; } if(label){ const t=T(f,label,size,{x:x0,y:0,col:o.textCol||'#ffffff'}); t.y=Math.round((f.height-t.height)/2); } return {k,f};}
// dark steel plate (rows, panels) and recessed well (value fields, viewports)
function STEEL(p,n,x,y,w,h,o={}){const s=F(p,n,x,y,w,h,o.r??4,[grad(o.cols||['#303a49','#1d232d']),LATT(0.06)],o.clip); STROKE(s,o.sw??2); s.effects=[SHADOW(4,10,0.38)]; R(s,'top highlight',4,o.sw??2,w-8,1.5,1,[{type:'SOLID',color:{r:0.9,g:0.82,b:1},opacity:0.2}]); return s;}
function WELL(p,n,x,y,w,h,o={}){const s=F(p,n,x,y,w,h,o.r??3,[{type:'SOLID',color:hx(o.col||'#0a0e14'),opacity:o.op??0.8}],o.clip); STROKE(s,1.5); s.effects=[INNER(2,3,0.6)]; return s;}
// small cost / value chip (owner-approved): steel mini plate, ink outline 2, top highlight, ink drop 2 + soft shadow.
// Under a node: centre it and seat its top 6 px into the node bottom.
function CHIP(p,n,x,y,icon,value,o={}){const size=o.size||13; const H=size+9, is=size+3, padL=6, gap=5, padR=8; const tw=textW(value,size); const W=Math.ceil((icon?padL+is+gap:8)+tw+padR);
  const c=F(p,n,x,y,W,H,3,[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:0.2,g:0.235,b:0.29,a:1},position:0},{color:{r:0.09,g:0.11,b:0.14,a:1},position:1}]},LATT(0.05)]); STROKE(c,2);
  c.effects=[INKDS(2),SHADOW(4,6,0.35)]; R(c,'top highlight',4,2,W-8,1.5,1,[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0.14}]);
  let xx=8; if(icon){ ICO(c,icon,is,padL,Math.round((H-is)/2)); xx=padL+is+gap; } const t=T(c,value,size,{x:xx,y:0,col:o.col||'#ffffff',ol:1.2,sh:1}); t.y=Math.round((H-t.height)/2); return c;}
// progress bar: dark track + fill + centred label
function BAR(p,n,x,y,w,h,pct,cols,label){const b=F(p,n,x,y,w,h,3,[{type:'SOLID',color:hx('#0f1115')}],true); STROKE(b,1.5); b.effects=[INNER(2,0,0.6)]; const f=R(b,'fill',0,0,Math.max(0,Math.round(w*pct)),h,0,[grad(cols),{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:0.35},position:0},{color:{r:1,g:1,b:1,a:0},position:0.5}]}]); if(label){ const t=T(b,label,Math.min(15,h-7),{w,y:0,ol:1.3,sh:1}); t.y=Math.round((h-t.height)/2); } return b;}
// SVG glyphs (vectors are allowed only for tiny UI glyphs)
function GLYPH(p,kind,s,x,y,col='#ffffff'){const P={x:'M6 6 L18 18 M18 6 L6 18',check:'M4.5 12.5 L9.5 17.5 L19.5 6.5',left:'M15 4 L7 12 L15 20',right:'M9 4 L17 12 L9 20',up:'M4 15 L12 7 L20 15',down:'M4 9 L12 17 L20 9',plus:'M12 5 L12 19 M5 12 L19 12',minus:'M5 12 L19 12'}[kind]; const n=figma.createNodeFromSvg(`<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="${P}" fill="none" stroke="#0b0c10" stroke-width="7.5" stroke-linecap="round" stroke-linejoin="round"/><path d="${P}" fill="none" stroke="${col}" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`); n.name='glyph/'+kind; p.appendChild(n); n.resize(s,s); n.x=x; n.y=y; return n;}
const CHEVRONS = (p,x,y,col='#5fe06a') => { const n=figma.createNodeFromSvg(`<svg width="34" height="16" viewBox="0 0 34 16" xmlns="http://www.w3.org/2000/svg"><path d="M3 3 L9 8 L3 13 M13 3 L19 8 L13 13 M23 3 L29 8 L23 13" fill="none" stroke="#0b0c10" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 3 L9 8 L3 13 M13 3 L19 8 L13 13 M23 3 L29 8 L23 13" fill="none" stroke="${col}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`); n.name='growth chevrons'; p.appendChild(n); n.x=x; n.y=y; return n; };
// ---------- square-top window: frame + themed header (clone of the Mine header recipe) + red close key ----------
function WINDOW(parent,name,x,y,W,H,theme,title){
  const win=F(parent,name,x,y,W,H,0,J(winRef.fills),false); STROKE(win,4); win.effects=[SHADOW(10,24,0.45)];
  const head=headRef.clone(); win.appendChild(head); head.x=0; head.y=0; head.resize(W,72); head.clipsContent=true; // nothing may spill past the window edge
  const hf=J(head.fills); hf[0]=hgrad(THEME[theme]||THEME.mine); head.fills=hf;
  for (const ch of head.children){ if(['glow','ink'].includes(ch.name)) ch.resize(W,ch.height); if(ch.name==='top highlight') ch.resize(W-8,ch.height); if(ch.type==='TEXT'){ ch.characters=title; ch.x=(W-ch.width)/2; } if(ch.name==='spec') ch.x=W/2-180; if(ch.name.startsWith('fx/sparkle')) ch.x+=(W-560); if(ch.name==='sweep'||ch.name==='sweep2') ch.x+=Math.max(0,W/2-250); if(ch.name==='dome'){ ch.resize(W+80,ch.height); ch.x=-40; } if(ch.name==='swoosh'){ ch.resize(W,ch.height); ch.x=0; } }
  const glow=head.findChild(n=>n.name==='glow'); if(glow) glow.fills=[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{...hx(THEME[theme][1]),a:0},position:0},{color:{...hx(THEME[theme][1]),a:0.55},position:1}]}];
  // header v2 (2026-10-10): the source header has no depth band / bevel / swoosh; it ends in one 4 px ink edge
  // close key (owner: this is "normal"): 44px key at (W-54, 10), X glyph 22 centred on the face
  const {f:cf}=KEY(win,'btn/close',W-54,10,44,44,PAL.red,{d:5}); GLYPH(cf,'x',22,(cf.width-22)/2,(cf.height-22)/2);
  return win;
}
// OUTLINE(win): call LAST. Owner-approved continuous 4px ink outline drawn above every child (header included).
function OUTLINE(win){ let o=win.findChild(n=>n.name==='window outline'); if(!o){ o=figma.createRectangle(); o.name='window outline'; } o.locked=false; win.appendChild(o); o.x=0; o.y=0; o.resize(win.width,win.height); o.fills=[]; o.strokes=[{type:'SOLID',color:INK}]; o.strokeWeight=4; o.strokeAlign='INSIDE'; o.locked=true; return o; }
// segmented tabs row. tabs = [{label, icon, active, locked, req}]
function TABS(win,x,y,w,tabs){
  const bar=F(win,'tabs (segmented)',x,y,w,56,4,[{type:'SOLID',color:hx('#0d1219')},LATT(0.06)]); STROKE(bar,1.75); bar.effects=[INNER(3,4,0.7)];
  const tw=(w-12-(tabs.length-1)*2)/tabs.length;
  tabs.forEach((t,i)=>{ const tx=6+i*(tw+2);
    if(t.active){ const {f}=KEY(bar,'tab/'+t.label+' (active)',tx,5,tw,46,t.cols||PAL.green,{d:4,shadow:false}); const iw=t.icon?30:0, lw=textW(t.label,19), gw=iw+(iw?8:0)+lw, x0=(f.width-gw)/2; if(t.icon) ICO(f,t.icon,30,x0,(f.height-30)/2); T(f,t.label,19,{x:x0+iw+(iw?8:0),y:Math.round((f.height-24)/2)}); }
    else { const g=F(bar,'tab/'+t.label+(t.locked?' (locked)':''),tx,5,tw,46,0,[]); const iw=t.icon?28:0; const lw=Math.max(textW(t.label,18), t.req?textW(t.req,12):0); const gw=iw+(iw?8:0)+lw, x0=(tw-gw)/2;
      if(t.icon) ICO(g,t.icon,28,x0,t.req?4:9,{op:t.locked?0.45:0.8}); T(g,t.label,18,{x:x0+iw+(iw?8:0),y:t.req?3:11,col:'#8d94a3',ol:1.2,sh:1}); if(t.req) BODY(g,t.req,12,{x:x0+iw+(iw?8:0),y:27,col:'#ff9a8a'}); if(t.locked && ICON['lock']) ICO(g,'lock',18,x0+iw-12,0); }
  });
  return bar;
}
// spec card (auto-layout) next to a window: sections = [[heading, [lines...]], ...]
function SPEC(parent,name,x,y,w,sections){
  const card=figma.createAutoLayout('VERTICAL',{name, itemSpacing:12}); parent.appendChild(card); card.x=x; card.y=y; card.resize(w,100); card.counterAxisSizingMode='FIXED';
  card.paddingLeft=card.paddingRight=24; card.paddingTop=card.paddingBottom=22; card.cornerRadius=4; card.fills=[{type:'SOLID',color:{r:0.13,g:0.16,b:0.21}}]; STROKE(card,3);
  const add=(s,size,st,col,fam)=>{const t=figma.createText(); t.fontName={family:fam,style:st}; t.fontSize=size; t.characters=s; t.fills=[{type:'SOLID',color:col}]; card.appendChild(t); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; return t;};
  add(name.replace(/^Spec card \/ /,'SPEC · '),22,'Regular',{r:1,g:1,b:1},'Fredoka One');
  for (const [h,lines] of sections){ add(h,16,'Regular',{r:1,g:0.83,b:0.42},'Fredoka One'); add(lines.join('\n'),14,'Medium',{r:0.79,g:0.82,b:0.89},'Fredoka'); }
  return card;
}
// ---------- end of kit ----------
