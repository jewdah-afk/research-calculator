// page.js - a Playwright page for the marketing compositors: the Montserrat / Sarpanch fonts from art/ui/fonts and
// local files under /f/<absolute path>, so a page can draw realm stills, gem sprites and text in one place.
//   const { withPage } = require('./page');
//   await withPage(1920, 1080, async page => { await page.setContent(html); ... });
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ART = path.join(__dirname, '..', '..');
const FONTS = [
  ['Montserrat', 600, 'normal', 'montserrat-latin-600-normal'], ['Montserrat', 700, 'normal', 'montserrat-latin-700-normal'],
  ['Montserrat', 700, 'italic', 'montserrat-latin-700-italic'], ['Montserrat', 800, 'normal', 'montserrat-latin-800-normal'],
  ['Montserrat', 800, 'italic', 'montserrat-latin-800-italic'], ['Montserrat', 900, 'normal', 'montserrat-latin-900-normal'],
  ['Montserrat', 900, 'italic', 'montserrat-latin-900-italic'], ['Sarpanch', 700, 'normal', 'sarpanch-latin-700-normal'],
  ['Sarpanch', 800, 'normal', 'sarpanch-latin-800-normal'], ['Sarpanch', 900, 'normal', 'sarpanch-latin-900-normal'],
  ['RobotoMono', 500, 'normal', 'roboto-mono-latin-500-normal'], ['RobotoMono', 700, 'normal', 'roboto-mono-latin-700-normal'],
];
const FONT_CSS = FONTS.map(([f, w, s, file]) => `@font-face{font-family:${f};font-weight:${w};font-style:${s};src:url(http://mk.local/fonts/${file}.woff2)}`).join('\n');
const TYPES = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.woff2': 'font/woff2', '.js': 'text/javascript', '.svg': 'image/svg+xml' };
const url = file => 'http://mk.local/f/' + encodeURIComponent(path.resolve(file));

async function withPage(w, h, fn, { scale = 1 } = {}) {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
    page.on('pageerror', e => console.log('pageerror', e.message));
    page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log('console', m.text()); });
    await page.route('http://mk.local/**', route => {
      const u = new URL(route.request().url());
      let file = null;
      if (u.pathname === '/') return route.fulfill({ contentType: 'text/html', body: '<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>' });
      if (u.pathname.startsWith('/fonts/')) file = path.join(ART, 'ui', 'fonts', path.basename(u.pathname));
      else if (u.pathname.startsWith('/f/')) file = decodeURIComponent(u.pathname.slice(3));
      if (!file || !fs.existsSync(file)) return route.fulfill({ status: 404, body: '' });
      return route.fulfill({ body: fs.readFileSync(file), contentType: TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream' });
    });
    await page.goto('http://mk.local/');
    return await fn(page);
  } finally {
    await browser.close();
  }
}
// set a full HTML body (with the fonts) and wait for fonts and images
async function setHtml(page, css, body) {
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${FONT_CSS}
    html,body{margin:0;padding:0;background:#000;overflow:hidden}*{box-sizing:border-box}${css}</style></head><body>${body}</body></html>`,
  { waitUntil: 'load' });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(im => im.complete ? 0 : new Promise(r => { im.onload = im.onerror = r; })));
  });
}
module.exports = { withPage, setHtml, url, FONT_CSS, ART };
