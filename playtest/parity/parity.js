// Parity test: puts the same save state into Birb's live engine (birbplay.com, window.game)
// and into the playtest, then compares every formula both sides expose.
// Run from the repo root:  NODE_PATH=/opt/node-tools/node_modules node playtest/parity/parity.js
// Writes playtest/parity/REPORT.md. Needs network access to birbplay.com.
const fs = require("fs"), path = require("path"), http = require("http");
const { chromium } = require("playwright");
const ROOT = path.resolve(__dirname, "../..");
const SCENARIOS = require("./scenarios.js");
const DATA = (() => { const window = {}; eval(fs.readFileSync(path.join(ROOT, "playtest/js/data.js"), "utf8")); return window.BIRB_DATA; })();

const MIME = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".json": "application/json" };
function serve() {
  return new Promise((ok) => {
    const srv = http.createServer((req, res) => {
      const f = path.join(ROOT, decodeURIComponent(req.url.split("?")[0]));
      if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { "content-type": MIME[path.extname(f)] || "application/octet-stream" });
      fs.createReadStream(f).pipe(res);
    });
    srv.listen(0, "127.0.0.1", () => ok(srv));
  });
}

// The probe runs inside each page. `side` is "birb" or "ours"; both get the same scenario and return a flat {key: number|bool}.
function probe({ side, scenario }) {
  const D = window.BIRB_DATA;
  const num = (x) => (x == null ? null : typeof x === "boolean" ? x : typeof x === "object" && x.toNumber ? x.toNumber() : typeof x === "object" && "mantissa" in x ? x.mantissa * Math.pow(10, x.exponent) : Number(x));
  const deep = (dst, src) => { for (const [k, v] of Object.entries(src)) { if (v && typeof v === "object" && !Array.isArray(v)) { dst[k] = dst[k] && typeof dst[k] === "object" ? dst[k] : {}; deep(dst[k], v); } else dst[k] = v; } };
  const fresh = () => ({ aquarium: { activeBiomeId: "coast", housedFish: {}, researchedFishCounts: {}, releasedShinyFishes: {}, releasedShinyWeightsKg: {} }, fishInventory: [], discoveredFish: [], discoveredShinyFish: [], fishWeightRecords: [], activeFishIds: [], activeFishBuffs: {}, lockedFish: [], fishBuffThirdSlotUnlocked: false });
  let A;
  if (side === "birb") {
    const g = window.game, s = g.state;
    s.upgrades = {}; s.sunflowerUpgrades = {};
    for (const k of Object.keys(s.resources)) s.resources[k] = 0;
    Object.assign(s, fresh());
    const st = JSON.parse(JSON.stringify(scenario.state));
    deep(s, st);
    if (g.invalidateUpgradeTreeCache) g.invalidateUpgradeTreeCache();
    g.aquariumManager.invalidateModifierCache(); g.activeFishEffectSnapshot = null; g.fishMarketManager.normalizedMarketState = null;
    const mm = g.fishMarketManager, am = g.aquariumManager;
    A = {
      level: (id) => g.getUpgradeLevel(id), max: (id) => g.getUpgradeMaxLevel(id), eff: (id) => g.getUpgradeEffect(id),
      cost: (d) => g.getDiscountedUpgradeCost(d, g.getUpgradeLevel(d.id)),
      maxPopcorn: () => g.getMaxPopcorn(0), interval: () => g.getSpawnInterval(0), total: () => g.getTotalMultiplier(),
      prestige: () => g.getPotentialPrestigePoints().final, playtime: () => g.getPlaytimeMultiplier(), payout: () => g.getPrestigePayoutMultiplier(),
      radius: () => g.getPickupRadius(), sunUnlocked: (id) => g.isSunflowerUpgradeUnlocked(id), sunVisible: (id) => g.isSunflowerUpgradeVisible(id),
      sunCost: (d) => g.getDiscountedUpgradeCost(d, g.getSunflowerUpgradeLevel(d.id)),
      fish: (t) => g.getFishMultiplier(t), canEvolve: () => g.canEvolveCurrentStage(), sparrowXp: (L) => g.getSparrowXpNeeded(L),
      aqMod: (t) => am.getModifierMultiplier(t), aqShiny: () => am.getShinyChanceMultiplier(), aqNormal: () => am.getNormalFishBuffMultiplier(),
      aqShinyMs: () => am.getShinyBuffDurationMs(), aqSlots: () => am.getFishBuffSlotBonus(), aqPoints: () => am.getResonancePoints(),
      aqTier: (b) => am.getBiomeProgress(b).tierCount, aqHoused: () => am.getHousedSpeciesCount(), marketOpen: () => g.isFishMarketUnlocked(),
      maxBuffs: () => g.fishingManager.getMaxActiveFishBuffs(), aqUnlocked: () => g.isAquariumUnlocked(),
      contracts: (c, r) => { mm.ensureState(); mm.generateContractOffers(c, r); return JSON.stringify(s.aquarium.market.contractOffers); },
      repLevel: (x) => mm.getContractReputationLevel(x),
    };
  } else {
    const G = window.PT.G, PT = window.PT, s = Object.assign(PT.newState(), fresh());
    const st = JSON.parse(JSON.stringify(scenario.state));
    const res = st.resources || {}; delete st.resources;
    deep(s, st);
    for (const [k, v] of Object.entries(res)) s.resources[k] = new Decimal(v);
    G.s = s; PT.ensureFishing && PT.ensureFishing(s);
    A = {
      level: (id) => PT.level(s, id), max: (id) => PT.maxLevel(s, id), eff: (id) => PT.effect(s, id),
      cost: (d) => PT.discounted(s, PT.UP.get(d.id), PT.level(s, d.id)),
      maxPopcorn: () => PT.maxPopcorn(s), interval: () => PT.spawnInterval(s), total: () => PT.totalMultiplier(s),
      prestige: () => PT.prestige(s).final, playtime: () => PT.playtimeMult(s), payout: () => PT.prestigePayoutMult(s),
      radius: () => PT.pickupProfile(s).collectRadius, sunUnlocked: (id) => PT.sunUnlocked(s, id), sunVisible: (id) => PT.sunVisible(s, id),
      sunCost: (d) => PT.sunCost(s, d.id),
      fish: (t) => PT.fishMult(s, t), canEvolve: () => PT.canEvolveStage(s), sparrowXp: (L) => PT.sparrowXpNeeded(L),
      aqMod: (t) => PT.aqModifier(s, t), aqShiny: () => PT.aqShinyChanceMult(s), aqNormal: () => PT.aqNormalBuffMult(s),
      aqShinyMs: () => PT.aqShinyBuffMs(s), aqSlots: () => PT.aqBuffSlots(s), aqPoints: () => PT.aqPoints(PT.aq(s)),
      aqTier: (b) => PT.aqBiome(PT.aq(s), b).tierCount, aqHoused: () => PT.aqHousedCount(PT.aq(s)), marketOpen: () => PT.fishMarketUnlocked(s),
      maxBuffs: () => PT.maxFishBuffs(s), aqUnlocked: () => PT.aquariumUnlocked(s),
      contracts: (c, r) => { PT.market(s); return JSON.stringify(PT.generateContracts(s, c, r)); },
      repLevel: (x) => PT.repLevel(x),
    };
  }
  const out = {}, put = (k, f) => { try { out[k] = num(f()); } catch (e) { out[k] = "ERR " + e.message.slice(0, 60); } };
  for (const d of D.upgrades.filter((u) => !u.id.startsWith("d_"))) {
    put(`upgrade ${d.id} level`, () => A.level(d.id)); put(`upgrade ${d.id} max`, () => A.max(d.id));
    put(`upgrade ${d.id} effect`, () => A.eff(d.id)); put(`upgrade ${d.id} cost`, () => A.cost(d));
  }
  put("egg cap", A.maxPopcorn); put("spawn interval", A.interval); put("total multiplier", A.total);
  put("molt plumes", A.prestige); put("playtime mult", A.playtime); put("molt payout mult", A.payout); put("pickup radius", A.radius);
  put("can evolve", A.canEvolve);
  for (const t of ["popcorn_mult", "seed_mult", "feather_mult", "speed_mult", "pickup_mult", "spawn_mult", "reel_speed_mult", "xp_mult"]) put(`fish mult ${t}`, () => A.fish(t));
  for (const L of [1, 2, 10, 50]) put(`sparrow xp needed L${L}`, () => A.sparrowXp(L));
  for (const t of ["popcorn_mult", "seed_mult", "feather_mult", "golden_popcorn_mult", "speed_mult", "pickup_mult", "reel_speed_mult", "xp_mult", "shiny_chance_mult", "parrot_damage_mult", "sell_mult"]) put(`aquarium modifier ${t}`, () => A.aqMod(t));
  put("aquarium shiny chance mult", A.aqShiny); put("aquarium normal buff mult", A.aqNormal); put("aquarium shiny buff ms", A.aqShinyMs);
  put("aquarium buff slots", A.aqSlots); put("aquarium resonance", A.aqPoints); put("aquarium housed species", A.aqHoused); put("aquarium unlocked", A.aqUnlocked);
  put("fish market unlocked", A.marketOpen); put("max fish buffs", A.maxBuffs);
  for (const b of ["coast", "reef", "freshwater", "ocean", "abyssal", "creatures", "mystic", "mechanical", "expedition"]) put(`aquarium tier ${b}`, () => A.aqTier(b));
  for (const x of [0, 99, 100, 650, 6200, 9999]) put(`market rep level at ${x}`, () => A.repLevel(x));
  if (scenario.state.aquarium) for (const [c, r] of [[20000, 0], [20001, 0], [20001, 2]]) out[`contract offers cycle ${c} reroll ${r}`] = A.contracts(c, r);
  for (const [id] of D.stations) { if (id.startsWith("__")) continue; put(`tree ${id} unlocked`, () => A.sunUnlocked(id)); put(`tree ${id} visible`, () => A.sunVisible(id)); put(`tree ${id} cost`, () => A.sunCost(D.upgrades.find((u) => u.id === id))); }
  return out;
}

(async () => {
  const srv = await serve(), port = srv.address().port;
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-unsafe-swiftshader"] });
  const birb = await (await browser.newContext({ viewport: { width: 1600, height: 900 } })).newPage();
  await birb.goto("https://birbplay.com/", { waitUntil: "domcontentloaded", timeout: 90000 });
  await birb.waitForTimeout(6000);
  await birb.click("#start-game-btn", { force: true });
  await birb.waitForFunction(() => window.game && window.game.state && window.game.upgradeManager, null, { timeout: 60000 });
  await birb.waitForTimeout(3000);
  await birb.evaluate((d) => { window.BIRB_DATA = d; }, DATA); // CSP blocks script tags; evaluate goes through devtools
  const ours = await (await browser.newContext()).newPage();
  const errs = [];
  ours.on("pageerror", (e) => errs.push(e.message));
  await ours.goto(`http://127.0.0.1:${port}/playtest/index.html`);
  await ours.evaluate(() => localStorage.clear());
  await ours.reload(); await ours.waitForFunction(() => window.PT && window.PT.G);
  await ours.evaluate(() => { window.PT.G.paused = true; });

  const lines = [], close = (a, b) => (typeof a === "number" && typeof b === "number" ? Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(a), Math.abs(b)) : a === b);
  let total = 0, bad = 0;
  const summary = [];
  for (const sc of SCENARIOS) {
    const b = await birb.evaluate(probe, { side: "birb", scenario: sc });
    const o = await ours.evaluate(probe, { side: "ours", scenario: sc });
    const rows = [];
    for (const k of Object.keys(b)) { total++; if (!close(b[k], o[k])) { bad++; rows.push(`| ${k} | ${b[k]} | ${o[k]} |`); } }
    summary.push(`| ${sc.name} | ${Object.keys(b).length} | ${rows.length} |`);
    lines.push(`\n### ${sc.name}\n`, rows.length ? "| Value | Birb | Playtest |\n|---|---|---|\n" + rows.join("\n") : "All match.");
  }
  const report = `# Parity report\n\nBirb's live engine (birbplay.com \`window.game\`) vs the playtest, same save state per scenario. Generated ${new Date().toISOString().slice(0, 16)}Z by \`playtest/parity/parity.js\`.\n\n**${total - bad} / ${total} values match.**\n\n| Scenario | Values | Mismatches |\n|---|---|---|\n${summary.join("\n")}\n${errs.length ? "\nPlaytest page errors:\n" + errs.map((e) => "- " + e).join("\n") + "\n" : ""}${lines.join("\n")}\n`;
  fs.writeFileSync(path.join(__dirname, "REPORT.md"), report);
  console.log(`${total - bad}/${total} match`);
  console.log(summary.join("\n"));
  await browser.close(); srv.close();
})().catch((e) => { console.error(e); process.exit(1); });
