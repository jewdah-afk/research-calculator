// Captures Birb's Aquarium and Fish Market screens for a scenario (default "aquarium full + market").
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_aquarium.js ["scenario name"]
const fs = require("fs"), path = require("path");
const { chromium } = require("playwright");
const SCENARIOS = require("./scenarios.js");
const want = process.argv[2] || "aquarium full + market";
const sc = SCENARIOS.find((s) => s.name === want);
const out = path.join(__dirname, "birb_ui", want.replace(/\W+/g, "_"));
fs.mkdirSync(out, { recursive: true });
(async () => {
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
  const p = await (await browser.newContext({ viewport: { width: 1600, height: 900 } })).newPage();
  await p.goto("https://birbplay.com/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await p.waitForTimeout(6000);
  await p.click("#start-game-btn", { force: true }); await p.waitForTimeout(2500);
  const slot = p.getByText("NEW BIRB", { exact: true });
  if (await slot.count()) { await slot.first().click({ force: true }); await p.waitForTimeout(1500); }
  if (await p.locator("#start-game-btn").isVisible().catch(() => false)) await p.click("#start-game-btn", { force: true });
  await p.waitForFunction(() => window.game && window.game.state && window.game.aquariumManager, null, { timeout: 60000 });
  await p.waitForTimeout(6000);
  const apply = () => p.evaluate((st) => {
    const g = window.game, s = g.state;
    Object.assign(s, JSON.parse(JSON.stringify(st)));
    s.hasCompletedIntroTutorial = true;
    for (const k of Object.keys(s)) if (/^hasSeen/.test(k)) s[k] = true;
    s.aquariumTutorial = null; s.sparrow && (s.sparrow.unlocked = true);
    g.aquariumManager.invalidateModifierCache(); g.fishMarketManager.normalizedMarketState = null;
    g.invalidateUpgradeTreeCache && g.invalidateUpgradeTreeCache(); g.updateCurrencyHUD && g.updateCurrencyHUD();
  }, sc.state);
  const closeAll = async () => { for (let i = 0; i < 3; i++) { await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); })); await p.waitForTimeout(250); } };
  const shot = async (n) => { await p.waitForTimeout(1000); await p.screenshot({ path: path.join(out, n + ".jpg"), type: "jpeg", quality: 78 }); };
  await apply();
  for (const m of [2, 22]) { await p.evaluate((m) => { const g = window.game; g.isTransitioning = false; g.startMapTransition(1, m); }, m); await p.waitForTimeout(4500); await apply(); await closeAll(); }
  await shot("aquarium_map");
  await p.evaluate(() => document.getElementById("aquarium-menu-btn")?.click()); await shot("aquarium_biomes");
  for (const t of ["RESONANCE", "TOTAL"]) { await p.evaluate((t) => { const b = [...document.querySelectorAll("button")].find((b) => b.offsetParent && b.innerText.trim() === t); b && b.click(); }, t); await shot("aquarium_" + t.toLowerCase()); }
  await closeAll();
  await p.evaluate(() => { const g = window.game; g.isTransitioning = false; g.syncFishMarketState && g.syncFishMarketState(true); g.startMapTransition(1, 24); }); await p.waitForTimeout(4500); await apply(); await closeAll();
  await shot("market_map");
  await p.evaluate(() => { const g = window.game; g.openFishMarketVendor && g.openFishMarketVendor(); }); await shot("market_vendor");
  await closeAll();
  await p.evaluate(() => { const g = window.game; g.openFishMarketContractsInObjectives && g.openFishMarketContractsInObjectives(); }); await shot("market_contracts");
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
