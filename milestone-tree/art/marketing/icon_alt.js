// icon_alt.js - two genre-first alternatives to the gem icon (out/icon_512.png), for testing which one players click:
//   B "number": the M crystal in the rift ring over a big number (the incremental genre at a glance)
//   C "tree":   the tree of layer crystals (M at the root, P and SP on the branches, T at the top) on glowing links
// Drawn at 1024 and saved at 512 (Roblox's size); the subject stays inside the central 80 % (rounded corners crop).
//   cd art/marketing && node icon_alt.js      -> out/icon_b_number.png, out/icon_c_tree.png, out/icon_options.jpg
const path = require('path'), fs = require('fs');
const { withPage, setHtml, url } = require('./lib/page');
const OUT = path.join(__dirname, 'out');
const GEM = k => url(path.join(__dirname, '..', 'gems', 'sprites', k + '.png'));

const BASE = `
.s{position:absolute;inset:0;width:1024px;height:1024px;overflow:hidden;background:#07050d}
.glow{position:absolute;border-radius:50%}
.stars{position:absolute;inset:0;background-image:radial-gradient(2px 2px at 12% 18%,#fff8,transparent),radial-gradient(2px 2px at 82% 12%,#fff6,transparent),
  radial-gradient(1.5px 1.5px at 70% 78%,#fff7,transparent),radial-gradient(2px 2px at 22% 84%,#fff5,transparent),radial-gradient(1.5px 1.5px at 90% 52%,#fff6,transparent),
  radial-gradient(1.5px 1.5px at 8% 50%,#fff5,transparent),radial-gradient(2px 2px at 45% 8%,#fff6,transparent)}
.gem{position:absolute;filter:drop-shadow(0 0 28px var(--c)) drop-shadow(0 10px 18px #000a)}
`;

function numberHtml() {
  return `<div class="s" style="background:radial-gradient(circle at 50% 36%,#3a1466 0%,#170a2c 45%,#07050d 80%)">
    <div class="stars"></div>
    <div class="glow" style="left:212px;top:40px;width:600px;height:600px;background:radial-gradient(circle,#b35cffaa 0%,#b35cff33 40%,#b35cff00 70%)"></div>
    ${['blur(22px)', 'none'].map(f => `<div style="position:absolute;left:227px;top:55px;width:570px;height:570px;border-radius:50%;filter:${f};
      background:conic-gradient(from 200deg,#ffd24a,#ff5a8a,#ff4fd8,#b35cff,#6fd6ff,#ffffff,#ffd24a);
      -webkit-mask:radial-gradient(circle,transparent 62%,#000 63.5%,#000 69%,transparent 70.5%)"></div>`).join('')}
    <img class="gem" style="--c:#b35cff;left:322px;top:150px;width:380px;height:380px;z-index:2" src="${GEM('m')}">
    <div style="position:absolute;left:0;right:0;top:560px;text-align:center;font:900 italic 300px/1 Montserrat;letter-spacing:-6px;color:#ffd24a;
      text-shadow:0 10px 0 #7a4a00,0 0 60px #ffb00099,0 0 120px #ff8a0055">1e100</div>
  </div>`;
}

function treeHtml() {
  // the links: [x1, y1, x2, y2, colour]
  const L = [[512, 830, 512, 560, '#c98bff'], [512, 600, 300, 470, '#6fd6ff'], [512, 600, 724, 470, '#ff5a8a'], [512, 560, 512, 250, '#ffd24a'],
    [300, 470, 512, 300, '#6fd6ff'], [724, 470, 512, 300, '#ff5a8a']];
  const links = L.map(([x1, y1, x2, y2, c]) => {
    const len = Math.hypot(x2 - x1, y2 - y1), a = Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI;
    return `<div style="position:absolute;left:${x1}px;top:${y1 - 5}px;width:${len}px;height:10px;border-radius:5px;background:${c};
      box-shadow:0 0 18px ${c},0 0 36px ${c};transform-origin:0 50%;transform:rotate(${a}deg)"></div>`;
  }).join('');
  const G = [['t', 512, 250, 250, '#ffd24a'], ['p', 300, 470, 220, '#6fd6ff'], ['sp', 724, 470, 220, '#ff5a8a'], ['m', 512, 800, 300, '#b35cff']];
  const gems = G.map(([k, x, y, s, c]) => `<div class="glow" style="left:${x - s * 0.75}px;top:${y - s * 0.75}px;width:${s * 1.5}px;height:${s * 1.5}px;
      background:radial-gradient(circle,${c}66 0%,${c}22 40%,${c}00 70%)"></div>
    <img class="gem" style="--c:${c};left:${x - s / 2}px;top:${y - s / 2}px;width:${s}px;height:${s}px" src="${GEM(k)}">`).join('');
  return `<div class="s" style="background:radial-gradient(circle at 50% 55%,#2a0f4a 0%,#12081f 50%,#07050d 85%)">
    <div class="stars"></div>${links}${gems}</div>`;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  await withPage(1024, 1024, async page => {
    for (const [name, html] of [['icon_b_number', numberHtml()], ['icon_c_tree', treeHtml()]]) {
      await setHtml(page, BASE, html);
      const big = path.join(OUT, name + '_1024.png');
      await page.screenshot({ path: big });
      console.log(big);
    }
  });
})().catch(e => { console.error(e); process.exit(1); });
