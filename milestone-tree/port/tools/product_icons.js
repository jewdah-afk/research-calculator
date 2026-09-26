// product_icons.js - the 512 x 512 icons of the game passes and developer products (shared/Products), in the Sleek
// style: a dark slab, corner ticks, one accent colour, a big mark and a caption.
//
//   cd port && NODE_PATH=$(npm root -g) node tools/product_icons.js [outDir]    -> <key>.png (default ../art/products)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const FONTS = path.join(__dirname, '..', '..', 'art', 'ui', 'fonts');
const OUT = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'art', 'products'));

const font = (fam, w, s, f) => `@font-face{font-family:${fam};font-weight:${w};font-style:${s};src:url(data:font/woff2;base64,${fs.readFileSync(path.join(FONTS, f + '.woff2')).toString('base64')})}`;
const CSS = [
  font('M', 900, 'italic', 'montserrat-latin-900-italic'), font('M', 800, 'normal', 'montserrat-latin-800-normal'),
  font('M', 700, 'normal', 'montserrat-latin-700-normal'),
].join('\n');

// key, accent, the big mark (HTML), caption, sub
const ITEMS = [
  ['speed', '#5fe0ff', '2<span style="font-size:.55em">×</span>', 'SPEED', 'PASS'],
  ['supporter', '#ffc93c', '<svg viewBox="0 0 100 100" width="230" height="230"><path d="M50 6 61 38 95 38 67 58 78 92 50 71 22 92 33 58 5 38 39 38Z" fill="url(#g)"/><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3c4"/><stop offset="1" stop-color="#ffb000"/></linearGradient></defs></svg>', 'SUPPORTER', 'PASS'],
  ['warp1', '#b35cff', '1<span style="font-size:.45em">H</span>', 'TIME WARP', 'INSTANT PROGRESS'],
  ['warp8', '#b35cff', '8<span style="font-size:.45em">H</span>', 'TIME WARP', 'INSTANT PROGRESS'],
  ['warp24', '#ff5a8a', '24<span style="font-size:.45em">H</span>', 'TIME WARP', 'A WHOLE DAY'],
];

function page([key, c, mark, cap, sub]) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}
  html,body{margin:0;width:512px;height:512px;background:#05070c;overflow:hidden}
  .s{position:absolute;inset:0;background:radial-gradient(circle at 50% 42%, ${c}40 0%, #0c111a 55%, #05070c 100%)}
  .ring{position:absolute;left:96px;top:56px;width:320px;height:320px;border:2px solid ${c}88;transform:rotate(45deg);box-sizing:border-box}
  .ring2{position:absolute;left:126px;top:86px;width:260px;height:260px;border:1px solid #ffffff22;transform:rotate(45deg);box-sizing:border-box}
  .mark{position:absolute;left:0;right:0;top:${key === 'supporter' ? 100 : 118}px;text-align:center;font:900 italic 190px/1 M;color:#fff;
    text-shadow:0 0 30px ${c}aa, 0 6px 0 #00000080;letter-spacing:-4px}
  .cap{position:absolute;left:0;right:0;bottom:62px;text-align:center;font:800 44px/1 M;color:#fff;letter-spacing:6px}
  .sub{position:absolute;left:0;right:0;bottom:30px;text-align:center;font:700 18px/1 M;color:${c};letter-spacing:5px}
  .bar{position:absolute;left:176px;right:176px;bottom:118px;height:3px;background:${c}}
  .t{position:absolute;width:26px;height:26px;border-color:#ffffffaa;border-style:solid;border-width:0}
  </style></head><body><div class="s"></div><div class="ring2"></div><div class="ring"></div>
  <div class="mark">${mark}</div><div class="bar"></div><div class="cap">${cap}</div><div class="sub">${sub}</div>
  <div class="t" style="left:18px;top:18px;border-left-width:3px;border-top-width:3px"></div>
  <div class="t" style="right:18px;top:18px;border-right-width:3px;border-top-width:3px"></div>
  <div class="t" style="left:18px;bottom:18px;border-left-width:3px;border-bottom-width:3px"></div>
  <div class="t" style="right:18px;bottom:18px;border-right-width:3px;border-bottom-width:3px"></div>
  </body></html>`;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 512, height: 512 } });
  for (const it of ITEMS) {
    await p.setContent(page(it));
    await p.waitForTimeout(150);
    await p.screenshot({ path: path.join(OUT, it[0] + '.png') });
    console.log(path.join(OUT, it[0] + '.png'));
  }
  await b.close();
})();
