// Captures Birb's Expedition screens for a late-game save: the hub, the floor wheel (day and night), the parrot window
// tabs (STATS / SKILLS / INVENTORY+forge), the objectives window, a floor run with its HUD, the floor 1 secret room,
// the night floor and the Sacrifice Room. Writes playtest/parity/birb_ui/expedition/*.jpg (layout reference only).
// Usage: NODE_PATH=/opt/node-tools/node_modules node playtest/parity/birb_expedition.js ["scenario name"]
const fs = require("fs"), path = require("path");
const { chromium } = require("playwright");
const SCENARIOS = require("./scenarios.js");
const want = process.argv[2] || "mythic III doubled relic";
const sc = SCENARIOS.find((s) => s.name === want);
const out = path.join(__dirname, "birb_ui", "expedition");
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
  await apply(); await go(5); await apply(); await closeAll();
  await shot("hub");
  await safe("wheel", async () => { await p.evaluate(() => window.game.toggleExpeditionFloorWheel(true)); await shot("floor_wheel_day");
    await p.evaluate(() => { window.game.expeditionFloorWheelState.mode = "night"; }); await shot("floor_wheel_night"); await p.evaluate(() => window.game.closeExpeditionFloorWheel(true)); });
  for (const t of ["stats", "skills", "gear"]) await safe("parrot " + t, async () => { await p.evaluate((t) => window.game.openParrotMenuTab(t), t); await shot("parrot_" + t); });
  await safe("gear scroll", async () => { await p.evaluate(() => document.querySelectorAll("#parrot-menu-container *").forEach((e) => { if (e.scrollHeight > e.clientHeight + 20) e.scrollTop = 9999; })); await shot("parrot_gear_scrolled"); });
  await closeAll();
  await safe("objectives", async () => { await p.evaluate(() => window.game.openQuestMerchantWindow()); await shot("objectives");
    const tabs = await p.$$eval("#quest-merchant-window [data-tab]", (bs) => bs.filter((b) => b.offsetParent).map((b) => b.dataset.tab));
    for (const t of tabs) { await p.evaluate((t) => document.querySelector(`#quest-merchant-window [data-tab="${t}"]`)?.click(), t); await shot("objectives_" + t); } });
  await closeAll();
  await safe("run", async () => { await p.evaluate(() => window.game.startExpeditionWithTransition(1)); await p.waitForTimeout(6000); await closeAll(); await shot("floor1_run");
    await p.evaluate(() => { window.game.state.expedition.isAutoAttack = true; }); await p.waitForTimeout(6000); await shot("floor1_fight"); });
  await safe("secret room", async () => { await p.evaluate(() => window.game.expeditionManager.tryEnterSecretRoom()); await p.waitForTimeout(4000); await shot("floor1_secret_room"); });
  await safe("end run", async () => { await p.evaluate(() => window.game.expeditionManager.endRun(false)); await go(5, -1); await closeAll(); });
  await safe("night", async () => { await p.evaluate(() => window.game.startExpeditionWithTransition(1, { nightMode: true })); await p.waitForTimeout(6000); await closeAll(); await shot("night_floor1");
    await p.evaluate(() => window.game.expeditionManager.endRun(false)); await go(5, -1); await closeAll(); });
  await safe("sacrifice", async () => { await go(8, -1); await closeAll(); await shot("sacrifice_room"); });
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
