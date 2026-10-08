// Captures Birb's Nest screens: the map left of the Park, its drawer tabs and windows.
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_nest.js ["scenario name"]
const fs = require("fs"), path = require("path");
const { chromium } = require("playwright");
const SCENARIOS = require("./scenarios.js");
const want = process.argv[2] || "evolution 3";
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
  await p.waitForFunction(() => window.game && window.game.state && window.game.nestManager, null, { timeout: 60000 });
  await p.waitForTimeout(6000);
  const apply = () => p.evaluate((st) => {
    const g = window.game, s = g.state;
    const deep = (d, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { d[k] = d[k] && typeof d[k] === "object" ? d[k] : {}; deep(d[k], v); } else d[k] = v; } };
    deep(s, JSON.parse(JSON.stringify(st)));
    s.hasCompletedIntroTutorial = true;
    for (const k of Object.keys(s)) if (/^hasSeen/.test(k)) s[k] = true;
    s.sparrow && (s.sparrow.unlocked = true);
    g.invalidateUpgradeTreeCache && g.invalidateUpgradeTreeCache(); g.updateShopState && g.updateShopState(); g.updateCurrencyHUD && g.updateCurrencyHUD();
    g.updateNestShopTabVisibility && g.updateNestShopTabVisibility();
  }, sc.state);
  const closeAll = async () => { for (let i = 0; i < 3; i++) { await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); })); await p.waitForTimeout(250); } };
  const shot = async (n) => { await p.waitForTimeout(1000); await p.screenshot({ path: path.join(out, n + ".jpg"), type: "jpeg", quality: 78 }); };
  await apply();
  await p.evaluate(() => { const g = window.game; g.isTransitioning = false; g.tryTransitionMap ? g.tryTransitionMap(-1) : g.startMapTransition(-1); });
  await p.waitForTimeout(5000); await apply(); await closeAll();
  console.log("map", await p.evaluate(() => window.game.currentMap));
  await shot("nest_map");
  const tabs = await p.$$eval(".tab-btn", (bs) => bs.filter((b) => b.offsetParent).map((b) => b.innerText.trim()));
  console.log("tabs", tabs);
  for (const t of tabs) { await p.evaluate((t) => { const b = [...document.querySelectorAll(".tab-btn")].find((b) => b.offsetParent && b.innerText.trim() === t); b && b.click(); }, t); await shot("nest_tab_" + t.replace(/\W+/g, "_").toLowerCase()); }
  // walk around: move the player in each direction to reveal stations
  for (const [k, ms] of [["ArrowUp", 1500], ["ArrowLeft", 1500], ["ArrowDown", 3000], ["ArrowRight", 3000]]) { await p.keyboard.down(k); await p.waitForTimeout(ms); await p.keyboard.up(k); await shot("nest_walk_" + k.toLowerCase()); }
  const text = await p.evaluate(() => JSON.stringify(window.render_game_to_text ? window.render_game_to_text() : "").slice(0, 3000));
  console.log(text);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
