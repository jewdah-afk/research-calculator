// Snake Wars "Venom Candy v2" Figma kit (paste at the top of EVERY use_figma script on file 6ghy7bHkwpGaQ82Ha0n5gy).
// Port of Peckwood's confirmed UI v2 kit (rc-main docs/figma/kit.js): same squared craft (square-top windows, 4 px
// continuous ink outline, Kit.button keys, steel plates, wells, steel mini chips), with Snake Wars' own identity:
// Venom Candy colours, Montserrat (owner pick 2026-10-10: Black Italic titles/numbers, ExtraBold Italic labels, Bold
// body; every text outlined + ink drop, never flat grey), faceted gem faces with
// the hex-scale texture, Length gold / rates mint, and a round red gem close key at (W-54, 10).
// Everything is self-contained (no cross-file node refs). Set PAGE_ID before pasting, or edit the line below.
const KIT_PAGE = await figma.getNodeByIdAsync(typeof PAGE_ID !== 'undefined' ? PAGE_ID : '115:1747'); await figma.setCurrentPageAsync(KIT_PAGE);
await Promise.all([['Montserrat','Black Italic'],['Montserrat','ExtraBold Italic'],['Montserrat','Bold'],['Montserrat','Black']].map(([family,style])=>figma.loadFontAsync({family,style})));
const J = o => JSON.parse(JSON.stringify(o));
const VT = [[0,1,0],[-1,0,1]];   // top -> bottom
const HT = [[1,0,0],[0,1,0]];    // left -> right
const DT = [[0.7,0.7,0],[-0.7,0.7,0.5]]; // diagonal
const IMG = {
  cart:'2b1ae5278c9ff7dae512bf2d9705afebb2491c46', snakehead:'b3a33ba3d43e7015b99d27969b57a94b501d8fa6', hatchling:'71133fcce384484fb85eef85d276b90414e3b7a9',
  scroll:'5a220908c85eb766b05659c5d1130fcd3c46900d', globe:'ffd5845f6c1564c75d46bc645c48bb77b4b99fb6', rebirth:'3b45a7abf50f65695bb351834c618736fcfcdd66',
  egg:'54a6980e93d7d9d827805dd18c121bd96f5bad93', potion:'f6f826a36abd8fc315ead7c2b974495c589ee210', gear:'3895218a80207b911ea09f0f18eaaab8f16f2b96',
  gift:'59092f75da1f49d1ab969e63dc55b6b19d747c11', calendar:'2a08d015c7e9c81572edff2d90d26a216b5f225d', trophy:'93a3500859027eea9a1e63e9acdb9c9a6493986e',
  gem:'39d393b76e4d67d9fdbc895834ffa85ec0032cc2', length:'6f47dc10f888ccdd7a29c66d815b550370ce97c1', fang:'00c4d3366bb78adfc648af41a534429212c81ebe',
  nest:'75db3f25fb9cce896b2eaab981da77958bfcf7b4', crown:'632236aa68ba5a44fee52d5d1a7e16679bd00c6d', ticket:'df209506069d1a9f0f135634a316582259d3a775',
  friends:'51bdb0e4eba5b055895c0f4347b35470571bb219', lock:'1172bd41373b447d954dd476e76e723dd6424f85', star:'732ea67293163bb3078465e416180d7403744217',
  clock:'9ef472d7d7a64f4ccab3a3d65cb7cbe78426c730', podium:'0ad6be1aafa813a223f3976f9fa413e13944d727', magnet:'94dfb770f388ae848c6e33a88e1a9d627cbdc686',
  flag:'acc4cf8b30faa1a75f1ed48741b791d641aac271', bolt:'c18016f7ce2ee27601dbfce0de7a4a69934fb840', robux:'f5177eed1402fcc20964af5fa12d1d1b0a825675',
  scales:'ae707918f737f328d33f7c8fa83ecbcf8e9d62f4', hub_backdrop:'d629bc2cb9325061a2ca92cf742c8e36d17a2658',
  egg_sprout:'2435b47969fea6ac002ca0d62501af517fb73385', egg_tide:'c2d96e0c6a888f7c267224a893f95b46b9e7571b', egg_crystal:'bd6f7492047e47237679fa9b38bf939386f86b61',
  egg_frostbite:'e0e352b907ae99e3069e06da45151f88eb0e4cea', egg_magma:'3bf5af6a2f2ba904e24c602917b6124ddd96a2d0', egg_starfall:'e44e5748e2a84a896a3bef210d33fba762c176cc',
  egg_core:'f2e5e16f953c6ce3bc5a62593a9b667c77eea12d', egg_regular:'ac134a004b184086a2553b801b08b5851a399ebb', egg_exclusive:'cc059c59efd013ce86f222e3ff3720f8db2788fd',
  w1:'9dfbb271bc7a15aa5520dd67a890ff7028bd56cf', w2:'9434a8c6fa2c7bc3f9537bc69a5c5f92f9f8f7f0', w3:'e8d7b6926d6545fc390230453386aca4482627f2',
  w4:'24e31add8763a1af46386e2fbb121d649d99eb3d', w5:'754dc12f2e682e344e38b92dddf62e99e5d0366d', void:'767347824df8f4a73f86c7ab7ea173a8f55d54ed',
  g_blizzara:'6d68e918aef7df95fc885621d3a4f05598bd7653' };
const hx = h => ({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255});
const INK = hx('#0D1418');
// Venom Candy tokens as [top, base, bevel] (light -> dark), plus steel for secondary keys
const PAL = { venom:['#7CF29E','#35D06B','#1B8A45'], gold:['#FFE48A','#FFC93C','#D9921A'], amber:['#FFC071','#FF9A2E','#C9621A'],
  sky:['#7FD0FF','#2EA8F0','#1767B5'], grape:['#B88CFF','#8C4BE6','#5A23A8'], rose:['#FF8DBD','#F0428E','#A81E5C'],
  ember:['#FF8080','#EE3B3B','#A51E24'], lime:['#CFF27A','#9AD32B','#5E8E12'], indigo:['#9488FF','#5B4BE0','#33269E'],
  slate:['#A9D9E0','#6FA9B3','#3E737D'], steel:['#5a6678','#3a4352','#262c37'], ice:['#E6F6FF','#8FD8F5','#4E9CC2'] };
const TXT = { body:'#E6F1FF', hint:'#A9C4DC', mint:'#8BF5B4', gold:'#FFC93C', amber:'#FFC071', bad:'#FF9A8A', ice:'#BFE8FF' };
const grad = (cols,k=1,a=1,tr=VT) => ({type:'GRADIENT_LINEAR',gradientTransform:J(tr),gradientStops:cols.map((c,i)=>{const x=hx(c);return {color:{r:x.r*k,g:x.g*k,b:x.b*k,a},position:i/(cols.length-1)};})});
const hgrad = cols => grad(cols,1,1,HT);
const SCALES = (op=0.07) => ({type:'IMAGE',imageHash:IMG.scales,scaleMode:'TILE',scalingFactor:0.35,opacity:op});
const IMGF = (key,mode='FILL',op=1) => ({type:'IMAGE',imageHash:IMG[key],scaleMode:mode,opacity:op});
const SHADOW = (y,r,a) => ({type:'DROP_SHADOW',color:{r:0,g:0,b:0,a},offset:{x:0,y},radius:r,spread:0,visible:true,blendMode:'NORMAL'});
const INKDS = y => ({type:'DROP_SHADOW',color:{...INK,a:1},offset:{x:0,y},radius:0,spread:0,visible:true,blendMode:'NORMAL'});
const INNER = (y,r,a,col='#000000') => ({type:'INNER_SHADOW',color:{...hx(col),a},offset:{x:0,y},radius:r,spread:0,visible:true,blendMode:'NORMAL'});
// ---------- primitives ----------
function R(p,n,x,y,w,h,r,fills){const e=figma.createRectangle(); e.name=n; e.resize(Math.max(0.01,w),Math.max(0.01,h)); e.x=x; e.y=y; e.cornerRadius=r||0; e.fills=fills||[]; p.appendChild(e); return e;}
function E(p,n,x,y,w,h,fills){const e=figma.createEllipse(); e.name=n; e.resize(w,h); e.x=x; e.y=y; e.fills=fills||[]; p.appendChild(e); return e;}
function F(p,n,x,y,w,h,r,fills,clip){const e=figma.createFrame(); e.name=n; e.resize(Math.max(0.01,w),Math.max(0.01,h)); e.cornerRadius=r||0; e.fills=fills||[]; e.clipsContent=!!clip; p.appendChild(e); e.x=x; e.y=y; return e;}
function STROKE(n,w=2,col){ n.strokes=[{type:'SOLID',color:col?hx(col):INK}]; n.strokeWeight=w; n.strokeAlign='INSIDE'; return n; }
// ---------- text ----------
// T: display (Montserrat Black Italic) titles + big numbers: ink outline ~9% of size + hard ink drop.
// L: label (Montserrat ExtraBold Italic), uppercase by default, ink outline 2 + 2 px drop.
// B: body (Montserrat Bold), ink outline 2 + 2 px drop, tinted (never flat grey).
function _txt(p,s,size,fam,st,o){const t=figma.createText(); t.name=o.name||String(s).slice(0,28); t.fontName={family:fam,style:st}; t.fontSize=size; t.characters=String(s); t.fills=[o.grad?grad(o.grad):{type:'SOLID',color:hx(o.col||'#ffffff'),opacity:o.op??1}]; if(o.ol!==0){t.strokes=[{type:'SOLID',color:INK}]; t.strokeWeight=o.ol; t.strokeAlign='OUTSIDE'; t.effects=[INKDS(o.sh)];} p.appendChild(t); if(o.w){t.textAutoResize='HEIGHT'; t.resize(o.w,t.height); t.textAlignHorizontal=o.al||'CENTER';} t.x=o.x||0; t.y=o.y||0; return t;}
function T(p,s,size,o={}){ return _txt(p,s,size,'Montserrat','Black Italic',{...o,ol:o.ol??Math.max(1.5,+(size*0.09).toFixed(1)),sh:o.sh??Math.max(1,Math.round(size*0.07))}); }
function L(p,s,size,o={}){ return _txt(p,o.keepCase?s:String(s).toUpperCase(),size,'Montserrat','ExtraBold Italic',{...o,ol:o.ol??2,sh:o.sh??2}); }
function B(p,s,size,o={}){ return _txt(p,s,size,'Montserrat','Bold',{...o,col:o.col||TXT.body,ol:o.ol??2,sh:o.sh??2}); }
function textW(s,size,fam='Montserrat',st='Black Italic'){const t=figma.createText(); t.fontName={family:fam,style:st}; t.fontSize=size; t.characters=String(s); const w=t.width; t.remove(); return w;}
const LW = (s,size) => textW(String(s).toUpperCase(),size,'Montserrat','ExtraBold Italic');
const BW = (s,size) => textW(s,size,'Montserrat','Bold');
function ICO(p,name,s,x,y,o={}){ if(!IMG[name]) throw new Error('missing image '+name); const r=R(p,'ico/'+name,x,y,s,s,0,[{type:'IMAGE',imageHash:IMG[name],scaleMode:'FIT'}]); r.effects=[{type:'DROP_SHADOW',color:{...INK,a:0.5},offset:{x:0,y:1.5},radius:0,spread:0,visible:true,blendMode:'NORMAL'}]; if(o.op!=null) r.opacity=o.op; return r;}
// ---------- keys: the game's Kit.button recipe with a Venom Candy gem face ----------
// ink body (r4) -> lip = face colours x0.58 shifted down D -> face (r2.5): gradient + hex scales 7% + one light facet
// plane + gloss cap (.45 -> .04, upper 42%). Pressed: PRESS(k). Dark (steel) faces: gloss <= .2.
function KEY(p,n,x,y,w,h,cols,o={}){const D=o.d??6; const k=F(p,n,x,y,w,h,0,[]); R(k,'ink body',0,0,w,h,o.r??4,[{type:'SOLID',color:INK}]); R(k,'lip',3,3+D,w-6,h-6-D,2.5,[grad(cols.slice(1),0.62)]);
  const fh=h-6-D; const f=F(k,'face',3,3,w-6,fh,2.5,[grad(cols),SCALES(o.steel?0.05:0.08)],true);
  const facet=figma.createPolygon(); facet.pointCount=3; facet.name='facet'; f.appendChild(facet); facet.resize(w*0.9,fh*2.2); facet.rotation=-28; facet.x=w*0.42; facet.y=-fh*0.35; facet.fills=[{type:'SOLID',color:{r:1,g:1,b:1},opacity:o.steel?0.03:0.07}];
  R(f,'gloss cap',3,2,w-12,Math.floor(fh*0.42),2,[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:o.gloss??(o.steel?0.18:0.45)},position:0},{color:{r:1,g:1,b:1,a:0.04},position:1}]}]);
  if(o.shadow!==false) k.effects=[SHADOW(4,8,0.35)]; return {k,f};}
function PRESS(k,D=6){const b=k.findChild(n=>n.name==='ink body'), l=k.findChild(n=>n.name==='lip'), f=k.findChild(n=>n.name==='face'); b.y=D; b.resize(b.width,b.height-D); f.y=D+3; if(l) l.visible=false; k.effects=[SHADOW(1,3,0.3)]; return k;}
// key with centred icon + label; o.font: 'T' (Montserrat Black Italic, default for primary) or 'L' (label)
function BTN(p,n,x,y,w,h,cols,label,o={}){const {k,f}=KEY(p,n,x,y,w,h,cols,o); const size=o.size||Math.round((h-6-(o.d??6))*0.5); const iw=o.icon?Math.round(size*(o.iconK??1.45)):0; const isL=o.font==='L'; const tw=label?(isL?LW(label,size):textW(label,size)):0; const gap=(o.icon&&label)?10:0; let x0=(f.width-iw-gap-tw)/2;
  if(o.icon){ ICO(f,o.icon,iw,x0,(f.height-iw)/2); x0+=iw+gap; }
  if(label){ const t=isL?L(f,label,size,{x:x0,col:o.textCol||'#ffffff'}):T(f,label,size,{x:x0,col:o.textCol||'#ffffff'}); t.y=Math.round((f.height-t.height)/2)+(isL?0:1); }
  return {k,f};}
// round red gem close key (Venom Candy identity), 46 px at (W-56, 10)
function CLOSE(p,x,y,s=46){const k=F(p,'btn/close',x,y,s,s,0,[]); E(k,'ink body',0,0,s,s,[{type:'SOLID',color:INK}]); E(k,'lip',3,6,s-6,s-8,[grad(PAL.ember.slice(1),0.6)]); const face=E(k,'face',3,3,s-6,s-10,[grad(PAL.ember)]);
  E(k,'gloss',9,6,s-18,(s-10)*0.42,[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:0.6},position:0},{color:{r:1,g:1,b:1,a:0.05},position:1}]}]);
  GLYPH(k,'x',20,(s-20)/2,(s-10-20)/2+3); k.effects=[SHADOW(3,6,0.4)]; return k;}
// dark steel plate (rows, panels) and recessed well (value fields, viewports)
function STEEL(p,n,x,y,w,h,o={}){const s=F(p,n,x,y,w,h,o.r??4,[grad(o.cols||['#283545','#17202a']),SCALES(0.05)],o.clip); STROKE(s,o.sw??2); s.effects=[SHADOW(4,10,0.38)]; R(s,'top highlight',4,o.sw??2,w-8,1.5,1,[{type:'SOLID',color:{r:0.85,g:0.95,b:1},opacity:0.18}]); return s;}
function WELL(p,n,x,y,w,h,o={}){const s=F(p,n,x,y,w,h,o.r??3,[{type:'SOLID',color:hx(o.col||'#0A1117'),opacity:o.op??0.85}],o.clip); STROKE(s,1.5); s.effects=[INNER(2,3,0.6)]; return s;}
// steel mini chip: icon + value (Montserrat Black Italic for numbers by default, o.font='L' for words)
function CHIP(p,n,x,y,icon,value,o={}){const size=o.size||16; const H=size+12, is=size+6, padL=6, gap=6, padR=10; const isL=o.font==='L'; const tw=isL?LW(value,size):textW(value,size); const W=Math.ceil((icon?padL+is+gap:10)+tw+padR);
  const c=F(p,n,x,y,W,H,3,[grad(o.cols||['#33404f','#161d26']),SCALES(0.05)]); STROKE(c,2); c.effects=[INKDS(2),SHADOW(4,6,0.35)]; R(c,'top highlight',4,2,W-8,1.5,1,[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0.14}]);
  let xx=10; if(icon){ ICO(c,icon,is,padL,Math.round((H-is)/2)); xx=padL+is+gap; }
  const t=isL?L(c,value,size,{x:xx,col:o.col||'#ffffff'}):T(c,value,size,{x:xx,col:o.col||'#ffffff',ol:1.4,sh:1}); t.y=Math.round((H-t.height)/2)+(isL?0:1); return c;}
// progress bar: dark track + fill + centred label
function BAR(p,n,x,y,w,h,pct,cols,label,o={}){const b=F(p,n,x,y,w,h,3,[{type:'SOLID',color:hx('#0A0F14')}],true); STROKE(b,1.5); b.effects=[INNER(2,0,0.6)]; R(b,'fill',0,0,Math.max(0,Math.round(w*pct)),h,0,[grad(cols),{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:0.35},position:0},{color:{r:1,g:1,b:1,a:0},position:0.5}]}]); if(label){ const t=L(b,label,o.size||Math.min(15,h-7),{w,ol:1.4}); t.y=Math.round((h-t.height)/2); } return b;}
// glyphs (vectors only for tiny UI glyphs)
function GLYPH(p,kind,s,x,y,col='#ffffff'){const P={x:'M6 6 L18 18 M18 6 L6 18',check:'M4.5 12.5 L9.5 17.5 L19.5 6.5',left:'M15 4 L7 12 L15 20',right:'M9 4 L17 12 L9 20',up:'M4 15 L12 7 L20 15',down:'M4 9 L12 17 L20 9',plus:'M12 5 L12 19 M5 12 L19 12',minus:'M5 12 L19 12',play:'M8 5 L19 12 L8 19 Z'}[kind]; const fill=kind==='play'?col:'none'; const n=figma.createNodeFromSvg(`<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="${P}" fill="${kind==='play'?'#0D1418':'none'}" stroke="#0D1418" stroke-width="7.5" stroke-linecap="round" stroke-linejoin="round"/><path d="${P}" fill="${fill}" stroke="${col}" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`); n.name='glyph/'+kind; p.appendChild(n); n.resize(s,s); n.x=x; n.y=y; return n;}
// fang-tip ribbon (NEW!, HERE, BOSS): a pill-less tag whose right end is a fang point
function RIBBON(p,n,x,y,label,cols,o={}){const size=o.size||14; const tw=LW(label,size); const w=Math.ceil(tw+30), h=size+12; const svg=`<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg"><path d="M2 2 H${w-16} L${w-2} ${h/2} L${w-16} ${h-2} H2 Z" fill="#0D1418"/></svg>`; const g=F(p,n,x,y,w,h,0,[]); const ink=figma.createNodeFromSvg(svg); ink.name='ink'; g.appendChild(ink); ink.x=0; ink.y=0;
  const face=figma.createNodeFromSvg(`<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg"><path d="M4 4 H${w-17} L${w-6} ${h/2} L${w-17} ${h-4} H4 Z" fill="#ffffff"/></svg>`); face.name='face'; g.appendChild(face); face.x=0; face.y=0; const fv=face.findOne(n=>n.type==='VECTOR'); if(fv) fv.fills=[grad(cols)];
  const t=L(g,label,size,{x:9,col:'#ffffff',ol:1.4}); t.y=Math.round((h-t.height)/2); g.effects=[INKDS(2)]; if(o.rot) g.rotation=o.rot; return g;}
// ---------- square-top window ----------
// header: theme gradient (left->right) + gloss dome + hex scales + depth band + 3 px ink edge, centred Montserrat title;
// o.art = image key painted into the header band (scenery header). Round red gem close at (W-56, 10).
function WINDOW(parent,name,x,y,W,H,theme,title,o={}){
  const win=F(parent,name,x,y,W,H,0,[grad(['#16222c','#0e161d']),SCALES(0.035)],true); win.effects=[SHADOW(10,24,0.5)];
  const HH=o.headH||76; const head=F(win,'header',0,0,W,HH,0,[hgrad(theme)],true);
  if(o.art){ const a=R(head,'header art',0,0,W,HH,0,[{...IMGF(o.art,'FILL',o.artOp??0.55)}]); }
  R(head,'scales',0,0,W,HH,0,[SCALES(0.08)]);
  R(head,'dome',-40,-HH*0.9,W+80,HH*1.35,9999,[{type:'GRADIENT_LINEAR',gradientTransform:J(VT),gradientStops:[{color:{r:1,g:1,b:1,a:0.32},position:0},{color:{r:1,g:1,b:1,a:0},position:1}]}]);
  R(head,'depth band',0,HH-12,W,9,0,[grad([theme[0],theme[0]],0.5)]);
  R(head,'ink',0,HH-3,W,3,0,[{type:'SOLID',color:INK}]);
  const t=T(head,title,o.titleSize||46,{}); t.x=Math.round((W-t.width)/2); t.y=Math.round((HH-12-t.height)/2)+3;
  if(o.sparkles!==false) for (const [sx,sy,ss] of [[0.18,0.28,10],[0.3,0.62,6],[0.72,0.3,8],[0.84,0.6,6],[0.62,0.18,5]]) { const st=figma.createStar(); st.name='fx/sparkle'; head.appendChild(st); st.pointCount=4; st.innerRadius=0.25; st.resize(ss,ss); st.x=W*sx; st.y=HH*sy; st.fills=[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0.85}]; }
  CLOSE(win,W-56,(HH-12-46)/2+2);
  return win;
}
// OUTLINE(win): call LAST. Continuous 4 px ink outline over every child, header included.
function OUTLINE(win){ let o=win.findChild(n=>n.name==='window outline'); if(!o){ o=figma.createRectangle(); o.name='window outline'; } o.locked=false; win.appendChild(o); o.x=0; o.y=0; o.resize(win.width,win.height); o.fills=[]; o.strokes=[{type:'SOLID',color:INK}]; o.strokeWeight=4; o.strokeAlign='INSIDE'; o.locked=true; return o; }
// segmented tabs. tabs = [{label, icon, active, locked, req, cols}]
function TABS(win,x,y,w,tabs){
  const bar=F(win,'tabs (segmented)',x,y,w,56,4,[{type:'SOLID',color:hx('#0A1117')},SCALES(0.05)]); STROKE(bar,1.75); bar.effects=[INNER(3,4,0.7)];
  const tw=(w-12-(tabs.length-1)*2)/tabs.length;
  tabs.forEach((t,i)=>{ const tx=6+i*(tw+2);
    if(t.active){ const {f}=KEY(bar,'tab/'+t.label+' (active)',tx,5,tw,46,t.cols||PAL.venom,{d:4,shadow:false}); const iw=t.icon?30:0, lw=LW(t.label,20), x0=(f.width-iw-(iw?8:0)-lw)/2; if(t.icon) ICO(f,t.icon,30,x0,(f.height-30)/2); L(f,t.label,20,{x:x0+iw+(iw?8:0),y:Math.round((f.height-26)/2)}); }
    else { const g=F(bar,'tab/'+t.label+(t.locked?' (locked)':''),tx,5,tw,46,0,[]); const iw=t.icon?28:0; const lw=Math.max(LW(t.label,19), t.req?BW(t.req,13):0); const x0=(tw-iw-(iw?8:0)-lw)/2;
      if(t.icon) ICO(g,t.icon,28,x0,t.req?4:9,{op:t.locked?0.45:0.8}); L(g,t.label,19,{x:x0+iw+(iw?8:0),y:t.req?2:10,col:TXT.hint,ol:1.2}); if(t.req) B(g,t.req,13,{x:x0+iw+(iw?8:0),y:26,col:TXT.bad}); }
  });
  return bar;
}
// spec card (auto-layout) next to a frame: sections = [[heading, [lines...]], ...]
function SPEC(parent,name,x,y,w,sections){
  const card=figma.createAutoLayout('VERTICAL',{name, itemSpacing:12}); parent.appendChild(card); card.x=x; card.y=y; card.resize(w,100); card.counterAxisSizingMode='FIXED';
  card.paddingLeft=card.paddingRight=24; card.paddingTop=card.paddingBottom=22; card.cornerRadius=4; card.fills=[{type:'SOLID',color:{r:0.09,g:0.13,b:0.16}}]; STROKE(card,3);
  const add=(s,size,fam,st,col)=>{const t=figma.createText(); t.fontName={family:fam,style:st}; t.fontSize=size; t.characters=s; t.fills=[{type:'SOLID',color:hx(col)}]; card.appendChild(t); t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT'; return t;};
  add(name.replace(/^Spec card \/ /,'SPEC · '),24,'Montserrat','Black Italic','#ffffff');
  for (const [h,lines] of sections){ add(h,17,'Montserrat','ExtraBold Italic','#FFC93C'); add(lines.join('\n'),15,'Montserrat','Bold','#E6F1FF'); }
  return card;
}
// ---------- end of kit ----------
