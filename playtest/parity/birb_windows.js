// Captures Birb's pop-up windows (companions, fish inventory, aquarium, fast travel...) for a scenario.
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_windows.js ["scenario name"]
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
  await p.waitForFunction(() => window.game && window.game.state && window.game.upgradeManager, null, { timeout: 60000 });
  await p.waitForTimeout(6000);
  const apply = () => p.evaluate((st) => {
    const g = window.game, s = g.state;
    const deep = (d, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { d[k] = d[k] && typeof d[k] === "object" ? d[k] : {}; deep(d[k], v); } else d[k] = v; } };
    deep(s, JSON.parse(JSON.stringify(st)));
    s.hasCompletedIntroTutorial = true;
    for (const k of Object.keys(s)) if (/^hasSeen/.test(k)) s[k] = true;
    if (s.evolutionCount >= 1 && s.sparrow) s.sparrow.unlocked = true;
    g.invalidateUpgradeTreeCache && g.invalidateUpgradeTreeCache(); g.updateShopState && g.updateShopState(); g.updateCurrencyHUD && g.updateCurrencyHUD();
  }, sc.state);
  const closeAll = async () => { for (let i = 0; i < 3; i++) { await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); })); await p.waitForTimeout(250); } };
  await apply();
  const go = async (m) => { await p.evaluate((m) => { const g = window.game; g.isTransitioning = false; g.startMapTransition(0, m); }, m); await p.waitForTimeout(4000); await apply(); await closeAll(); };
  const shot = async (n) => { await p.waitForTimeout(900); await p.screenshot({ path: path.join(out, n + ".jpg"), type: "jpeg", quality: 78 }); };
  const click = async (sel) => p.evaluate((sel) => { const b = document.querySelector(sel); if (b) { b.classList.remove("inactive", "is-transition-hidden"); b.click(); return true; } return false; }, sel);
  await go(2);
  console.log("fishinv", await click("#hud-fishing-inventory-btn")); await shot("win_fish_inventory"); await closeAll();
  console.log("companions", await click("#companions-menu-btn")); await shot("win_companions_menu");
  const items = await p.$$eval(".companions-menu-panel button, .companions-menu-panel [role=button], .companions-menu-panel > *", (bs) => bs.filter((b) => b.offsetParent).map((b) => b.innerText.trim()).filter(Boolean));
  console.log("companion items", items);
  for (const it of items.slice(0, 6)) {
    await closeAll(); await click("#companions-menu-btn"); await p.waitForTimeout(400);
    await p.evaluate((t) => { const b = [...document.querySelectorAll(".companions-menu-panel *")].find((b) => b.offsetParent && b.innerText && b.innerText.trim() === t); b && b.click(); }, it);
    await shot("win_companion_" + it.replace(/\W+/g, "_").toLowerCase());
  }
  await closeAll();
  console.log("fasttravel", await click("#hud-fast-travel-btn")); await shot("win_fast_travel"); await closeAll();
  console.log("aquarium", await click("#aquarium-menu-btn")); await shot("win_aquarium"); await closeAll();
  // fishing cast
  await p.keyboard.press("Space"); await p.waitForTimeout(1500); await shot("bridge_casting");
  await go(3); await shot("castle");
  await p.evaluate(() => { const g = window.game; g.state.hasTalkedToMonster = true; }); await p.mouse.click(600, 450); await shot("castle_click");
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
