// Keeps birbplay.com open; POST JS (body) to http://127.0.0.1:9333/ -> JSON result of evaluating it in the page (async fn body).
const http = require("http"); const { chromium } = require("playwright");
(async () => {
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
  const p = await (await browser.newContext({ viewport: { width: 1600, height: 900 } })).newPage();
  await p.goto("https://birbplay.com/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await p.waitForTimeout(6000);
  await p.click("#start-game-btn", { force: true }); await p.waitForTimeout(2500);
  const slot = p.getByText("NEW BIRB", { exact: true });
  if (await slot.count()) { await slot.first().click({ force: true }); await p.waitForTimeout(1500); }
  if (await p.locator("#start-game-btn").isVisible().catch(() => false)) await p.click("#start-game-btn", { force: true });
  await p.waitForFunction(() => window.game && window.game.state && window.game.expeditionManager, null, { timeout: 60000 });
  await p.waitForTimeout(3000);
  http.createServer((req, res) => { let b = ""; req.on("data", (c) => (b += c)); req.on("end", async () => {
    try { const r = await p.evaluate(`(async () => { ${b} })()`); res.end(JSON.stringify(r, null, 1)); }
    catch (e) { res.end("ERR " + e.message); }
  }); }).listen(9333, () => console.log("ready"));
  if (process.argv[2] === "shot") {}
  global.page = p;
})();
