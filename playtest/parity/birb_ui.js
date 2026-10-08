// Captures Birb's real UI (birbplay.com) for a scenario: every map and every drawer tab.
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_ui.js ["scenario name"] [maps e.g. 0,1,2,3]
// Writes playtest/parity/birb_ui/<scenario>/map<id>_<tab>.png. Reference for matching the playtest layout.
const fs = require("fs"), path = require("path");
const { chromium } = require("playwright");
const SCENARIOS = require("./scenarios.js");
const want = process.argv[2] || "evolution 3";
const maps = (process.argv[3] || "0,1,2,3").split(",").map(Number);
const sc = SCENARIOS.find((s) => s.name === want);
if (!sc) throw new Error("no scenario " + want);
const out = path.join(__dirname, "birb_ui", want.replace(/\W+/g, "_"));
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
  const p = await (await browser.newContext({ viewport: { width: 1600, height: 900 } })).newPage();
  await p.goto("https://birbplay.com/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await p.waitForTimeout(6000);
  await p.click("#start-game-btn", { force: true });
  await p.waitForTimeout(2500);
  // a slot picker can appear first: pick the fresh slot
  const slot = p.getByText("NEW BIRB", { exact: true });
  if (await slot.count()) { await slot.first().click({ force: true }); await p.waitForTimeout(1500); }
  for (const sel of ["#start-game-btn"]) if (await p.locator(sel).isVisible().catch(() => false)) await p.click(sel, { force: true });
  await p.waitForFunction(() => window.game && window.game.state && window.game.upgradeManager, null, { timeout: 60000 });
  await p.waitForTimeout(6000);
  const apply = async () => p.evaluate((st) => {
    const g = window.game, s = g.state;
    const deep = (d, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { d[k] = d[k] && typeof d[k] === "object" ? d[k] : {}; deep(d[k], v); } else d[k] = v; } };
    deep(s, JSON.parse(JSON.stringify(st)));
    s.hasCompletedIntroTutorial = true;
    for (const k of Object.keys(s)) if (/^hasSeen/.test(k)) s[k] = true; // skip tutorial popups
    if (s.evolutionCount >= 1 && s.sparrow) s.sparrow.unlocked = true;
    g.invalidateUpgradeTreeCache && g.invalidateUpgradeTreeCache();
    g.updateShopState && g.updateShopState(); g.updateCurrencyHUD && g.updateCurrencyHUD(); g.updateUpgradeTree && g.updateUpgradeTree();
  }, sc.state);
  await apply();
  // close tutorial/dialogue popups
  await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn, .dialogue-close").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); }));
  for (const m of maps) {
    await p.evaluate((m) => { const g = window.game; g.isTransitioning = false; g.startMapTransition(0, m); }, m);
    await p.waitForTimeout(4000);
    await apply();
    await p.waitForTimeout(800);
    for (let i = 0; i < 4; i++) { await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); })); await p.mouse.click(600, 600); await p.waitForTimeout(300); }
    const tabs = await p.$$eval(".tab-btn", (bs) => bs.filter((b) => b.offsetParent).map((b) => b.innerText.trim()));
    await p.screenshot({ path: path.join(out, `map${m}.jpg`), type: "jpeg", quality: 78 });
    for (const t of tabs) {
      await p.evaluate((t) => { const b = [...document.querySelectorAll(".tab-btn")].find((b) => b.offsetParent && b.innerText.trim() === t); b && b.click(); }, t);
      await p.waitForTimeout(700);
      await p.screenshot({ path: path.join(out, `map${m}_${t.replace(/\W+/g, "_").toLowerCase()}.jpg`), type: "jpeg", quality: 78 });
    }
    console.log("map", m, "tabs", tabs.join(", "));
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
