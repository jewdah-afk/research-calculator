// thumbs.js - the five 1920 x 1080 Roblox thumbnails: a real-client still (stills.js) under a Sleek sci-fi title block
// (art/ui/clean/styles.js Style 1: 1 px hairlines, corner ticks, registration marks, tracked caps micro labels, one
// accent). Captions are Montserrat 900 italic. Key content stays in the top 80 % (y < 864).
//   cd art/marketing && node thumbs.js [1..5]       -> out/thumb_<n>.jpg     (also exports logoHtml for video.js)
const path = require('path'), fs = require('fs');
const { withPage, setHtml, url } = require('./lib/page');
const ST = path.join(__dirname, 'work', 'stills'), OUT = path.join(__dirname, 'out');
const GEM = path.join(__dirname, '..', 'gems', 'sprites', 'm.png');

// crop = [x, y, w, h] of a panel still; at = [left, top, scale] on the thumbnail
const THUMBS = [
  { n: 1, bg: 'tree', accent: '#ffc93c', lines: ['GROW', 'THE TREE'], tag: '21 PRESTIGE LAYERS TO UNLOCK', logo: 'big' },
  { n: 2, bg: 'prestige_bg', accent: '#6fd6ff', lines: ['PRESTIGE'], tag: 'RESET FOR POWER. GO AGAIN.', glow: [1650, 520, 330],
    card: { src: 'panel_p', crop: [812, 72, 1068, 272], at: [84, 520, 0.8] } },
  { n: 3, bg: 'rift', accent: '#ff3d7f', lines: ['ENTER THE', 'MULTIVERSE'], tag: 'NEW UNIVERSES. NEW RULES.' },
  { n: 4, bg: 'corrupt', accent: '#39ff14', lines: ['FIX THE', 'CORRUPTION'], tag: 'HUNT THE MALWARE. EARN ESSENCE.',
    card: { src: 'panel_cp', crop: [812, 72, 1068, 282], at: [84, 540, 0.74] } },
  { n: 5, bg: 'explore', accent: '#c9a6ff', lines: ['EXPLORE'], tag: 'A LIVING, HAND-PAINTED REALM', side: 'right', maxCs: 168 },
];

const CSS = `
.stage{position:absolute;inset:0;width:1920px;height:1080px;overflow:hidden;background:#07050d}
.bg{position:absolute;inset:0;width:1920px;height:1080px;object-fit:cover;filter:saturate(1.12) contrast(1.06) brightness(1.06)}
.right .scrim{background:radial-gradient(ellipse 34% 30% at 76% 26%,rgba(7,5,13,.78) 0%,rgba(7,5,13,.45) 55%,rgba(7,5,13,0) 100%),
  linear-gradient(180deg,rgba(7,5,13,.5) 0%,rgba(7,5,13,0) 22%,rgba(7,5,13,0) 78%,rgba(7,5,13,.45) 100%)}
.right .cap{left:auto;right:92px;text-align:right}.right .rule{left:auto;right:96px;transform:scaleX(-1)}.right .tag{left:auto;right:96px}
.right .micro{top:auto!important;bottom:66px}
.scrim{position:absolute;inset:0;background:
  linear-gradient(90deg,rgba(7,5,13,.88) 0%,rgba(7,5,13,.7) 28%,rgba(7,5,13,.3) 46%,rgba(7,5,13,0) 60%),
  linear-gradient(180deg,rgba(7,5,13,.55) 0%,rgba(7,5,13,0) 22%,rgba(7,5,13,0) 78%,rgba(7,5,13,.45) 100%)}
.vig{position:absolute;inset:0;background:radial-gradient(ellipse 75% 75% at 62% 45%,rgba(0,0,0,0) 55%,rgba(0,0,0,.45) 100%)}
.frame{position:absolute;left:36px;top:36px;right:36px;bottom:36px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.16)}
.tick{position:absolute;width:44px;height:44px;border-color:var(--acc);border-style:solid;border-width:0}
.tl{left:28px;top:28px;border-left-width:4px;border-top-width:4px}.tr{right:28px;top:28px;border-right-width:4px;border-top-width:4px}
.bl{left:28px;bottom:28px;border-left-width:4px;border-bottom-width:4px}.br{right:28px;bottom:28px;border-right-width:4px;border-bottom-width:4px}
.reg{position:absolute;width:15px;height:15px;background:linear-gradient(rgba(255,255,255,.55),rgba(255,255,255,.55)) 50% 0/1px 100% no-repeat,linear-gradient(rgba(255,255,255,.55),rgba(255,255,255,.55)) 0 50%/100% 1px no-repeat}
.micro{position:absolute;font:700 17px/1 Montserrat;letter-spacing:.32em;color:rgba(255,255,255,.72);white-space:nowrap}
.micro b{color:var(--acc);font-weight:800}
.logo{position:absolute;display:flex;align-items:center;gap:18px}
.logo img{filter:drop-shadow(0 0 18px rgba(179,92,255,.8))}
.logo .t{font:900 italic var(--ls)/1 Montserrat;color:#fff;letter-spacing:.04em;text-shadow:0 2px 0 rgba(0,0,0,.4),0 0 24px rgba(179,92,255,.55)}
.logo .t small{display:block;font:700 calc(var(--ls) * .42)/1 Montserrat;letter-spacing:.42em;color:rgba(255,255,255,.7);margin-top:10px;font-style:normal}
.cap{position:absolute;left:92px;font:900 italic var(--cs)/.92 Montserrat;color:#fff;text-transform:uppercase;letter-spacing:-.005em;
  text-shadow:0 6px 0 rgba(0,0,0,.35),0 0 40px rgba(0,0,0,.55)}
.cap .l{display:block;white-space:nowrap}
.cap .a{color:var(--acc);text-shadow:0 6px 0 rgba(0,0,0,.35),0 0 38px var(--glow)}
.rule{position:absolute;left:96px;height:2px;background:linear-gradient(90deg,var(--acc),rgba(255,255,255,.0));}
.rule:before{content:'';position:absolute;left:0;top:-7px;width:2px;height:16px;background:var(--acc)}
.tag{position:absolute;left:96px;font:800 30px/1 Montserrat;letter-spacing:.2em;color:#eef0f6;text-shadow:0 2px 8px rgba(0,0,0,.8);white-space:nowrap}
.card{position:absolute;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.65),0 0 0 1px rgba(255,255,255,.22),0 0 44px var(--glow);transform-origin:0 0}
.card img{position:absolute;left:0;top:0}
.cardticks{position:absolute;pointer-events:none}
`;

function logoHtml(size, x, y) {
  return `<div class="logo" style="--ls:${size}px;left:${x}px;top:${y}px"><img src="${url(GEM)}" style="width:${size * 1.9}px;height:${size * 1.9}px">
    <div class="t">THE MILESTONE TREE<small>NG+ &nbsp;·&nbsp; AN INCREMENTAL ADVENTURE</small></div></div>`;
}
const hexA = (hex, a) => `rgba(${parseInt(hex.slice(1, 3), 16)},${parseInt(hex.slice(3, 5), 16)},${parseInt(hex.slice(5, 7), 16)},${a})`;

function thumbHtml(t) {
  // caption size: the longest line fits in ~980 px (Montserrat 900 italic caps run ~0.78 em a glyph)
  const longest = Math.max(...t.lines.map(l => l.length));
  const cs = Math.min(t.maxCs || 190, Math.floor(980 / (longest * 0.78)));
  const big = t.logo === 'big';
  const capTop = big ? 300 : 150;
  const capH = t.lines.length * cs * 0.92;
  const lines = t.lines.map((l, i) => `<span class="l ${i === t.lines.length - 1 && t.lines.length > 1 ? 'a' : t.lines.length === 1 ? 'a' : ''}">${l}</span>`).join('');
  let card = '';
  if (t.card) {
    const [cx, cy, cw, ch] = t.card.crop, [ax, ay, k] = t.card.at;
    card = `<div class="card" style="left:${ax}px;top:${ay}px;width:${cw}px;height:${ch}px;transform:scale(${k})">
      <img src="${url(path.join(ST, t.card.src + '.png'))}" style="left:${-cx}px;top:${-cy}px"></div>
      <div class="tick tl" style="left:${ax - 10}px;top:${ay - 10}px;width:26px;height:26px;border-width:3px 0 0 3px"></div>
      <div class="tick" style="left:${ax + cw * k - 16}px;top:${ay + ch * k - 16}px;width:26px;height:26px;border-width:0 3px 3px 0"></div>`;
  }
  return `<div class="stage${t.side === 'right' ? ' right' : ''}" style="--acc:${t.accent};--glow:${hexA(t.accent, 0.55)}">
    <img class="bg" src="${url(path.join(ST, t.bg + '.png'))}">
    <div class="scrim"></div><div class="vig"></div>
    ${t.glow ? `<div style="position:absolute;left:${t.glow[0] - t.glow[2]}px;top:${t.glow[1] - t.glow[2]}px;width:${t.glow[2] * 2}px;height:${t.glow[2] * 2}px;border-radius:50%;mix-blend-mode:screen;background:radial-gradient(circle,${hexA(t.accent, 0.55)} 0%,${hexA(t.accent, 0.22)} 35%,${hexA(t.accent, 0)} 70%)"></div>` : ''}
    <div class="frame"></div>
    <div class="tick tl"></div><div class="tick tr"></div><div class="tick bl"></div><div class="tick br"></div>
    <div class="reg" style="left:953px;top:29px"></div><div class="reg" style="left:953px;bottom:29px"></div>
    <div class="reg" style="left:29px;top:533px"></div><div class="reg" style="right:29px;top:533px"></div>
    <div class="micro" style="right:84px;top:66px"><b>0${t.n}</b> / 05 &nbsp; ${t.lines.join(' ')}</div>
    ${big ? logoHtml(46, 84, 92) : logoHtml(24, 84, 70)}
    <div class="cap" style="--cs:${cs}px;top:${capTop}px">${lines}</div>
    <div class="rule" style="top:${capTop + capH + 34}px;width:560px"></div>
    <div class="tag" style="top:${capTop + capH + 62}px">${t.tag}</div>
    ${card}
  </div>`;
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const pick = process.argv.slice(2).map(Number);
  await withPage(1920, 1080, async page => {
    for (const t of THUMBS) {
      if (pick.length && !pick.includes(t.n)) continue;
      await setHtml(page, CSS, thumbHtml(t));
      const out = path.join(OUT, `thumb_${t.n}.jpg`);
      await page.screenshot({ path: out, type: 'jpeg', quality: 92 });
      console.log(out);
    }
  });
}
if (require.main === module) main().catch(e => { console.error(e); process.exit(1); });
module.exports = { CSS, logoHtml, hexA };
