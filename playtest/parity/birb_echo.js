// Captures Birb's archivist branch and Echo Field (Phase 7). Derived from birb_expedition.js; captures Birb's Expedition screens for a late-game save: the hub, the floor wheel (day and night), the parrot window
// tabs (STATS / SKILLS / INVENTORY+forge), the objectives window, a floor run with its HUD, the floor 1 secret room,
// the night floor and the Sacrifice Room. Writes playtest/parity/birb_ui/expedition/*.jpg (layout reference only).
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_expedition.js ["scenario name"]
const fs = require("fs"), path = require("path");
const { chromium } = require("playwright");
const SCENARIOS = require("./scenarios.js");
const want = process.argv[2] || "archivist tree full";
const sc = SCENARIOS.find((s) => s.name === want);
const out = path.join(__dirname, "birb_ui", "echo");
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
  await p.waitForFunction(() => window.game && window.game.state && window.game.expeditionManager, null, { timeout: 60000 });
  await p.waitForTimeout(5000);
  const apply = () => p.evaluate((st) => {
    const g = window.game, s = g.state;
    const deep = (d, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { d[k] = d[k] && typeof d[k] === "object" ? d[k] : {}; deep(d[k], v); } else d[k] = v; } };
    deep(s, JSON.parse(JSON.stringify(st)));
    s.hasCompletedIntroTutorial = true; for (const k of Object.keys(s)) if (/^hasSeen/.test(k)) s[k] = true;
    s.sunflowerUpgrades = Object.assign(s.sunflowerUpgrades || {}, { d_desert_quest_merchant: 1 });
    const em = g.expeditionManager; em.state.highestFloorReached = 9; em.normalizeSacrificeState();
    g.invalidateUpgradeTreeCache && g.invalidateUpgradeTreeCache(); g.updateCurrencyHUD && g.updateCurrencyHUD();
  }, sc.state);
  const closeAll = async () => { for (let i = 0; i < 3; i++) { await p.evaluate(() => document.querySelectorAll(".birb-window-close-btn").forEach((b) => { if (b.offsetParent && !b.closest("#field-journal")) b.click(); })); await p.waitForTimeout(250); } };
  const shot = async (n) => { await p.waitForTimeout(1200); await p.screenshot({ path: path.join(out, n + ".jpg"), type: "jpeg", quality: 78 }); console.log("shot", n); };
  const go = async (map, dir = 1) => { await p.evaluate(([m, d]) => { const g = window.game; g.isTransitioning = false; g.startMapTransition(d, m); }, [map, dir]); await p.waitForTimeout(4500); };
  const safe = async (name, fn) => { try { await fn(); } catch (e) { console.log("skip", name, e.message.slice(0, 120)); } };
  await apply(); await p.evaluate(() => { window.game.state.sunflowerTreeView = "archivist"; window.game.state.player.x = 710; window.game.state.player.y = 640; }); await go(1); await apply();
  await p.evaluate(() => { window.game.state.sunflowerTreeView = "archivist"; Object.assign(window.game.state.player, { x: 710, y: 640 }); }); await closeAll(); await p.waitForTimeout(2000); await shot("archivist_branch");
  await p.evaluate(() => { Object.assign(window.game.state.player, { x: 1500, y: 700 }); }); await p.waitForTimeout(2000); await shot("archivist_branch_right");
  await go(30, -1); await closeAll(); await p.waitForTimeout(8000); await shot("echo_field");
  const tabs = await p.$$eval(".tab-btn", (bs) => bs.filter((b) => b.offsetParent).map((b) => b.innerText.trim())); console.log("tabs", tabs);
  for (const t of tabs) { await p.evaluate((t) => { const b = [...document.querySelectorAll(".tab-btn")].find((b) => b.offsetParent && b.innerText.trim() === t); b && b.click(); }, t); await shot("echo_tab_" + t.replace(/\W+/g, "_").toLowerCase()); }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
