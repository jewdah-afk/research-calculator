// Onslaught+ checks.  node test/expansion_test.js
const E = require("../engine.js");
const X = require("../expansion.js");
const GAME = require("../../onslaught-data/game.json");
let fails = 0, passes = 0;
function ok(c, msg) { if (c) passes++; else { fails++; console.log("FAIL:", msg); } }
function drain(G) { const f = G.fx; G.fx = []; return f; }
const maxed = { level: 99, research: {}, passes: {} };
function plus(o, loadout) {
  const L = loadout || maxed;
  const D = X.data(GAME, L);
  const opts = X.gameOpts(Object.assign({ map: "map1", mode: "sandbox", seed: 9, players: ["p1"] }, o || {}), { p1: L });
  return E.newGame(D, opts);
}

// ---- data merge and level locks
{
  const G = plus({}, { level: 1, research: {}, passes: {} });
  ok(G.D.turrets.Orange && G.D.buildOrder.indexOf("Orbital") > 0, "expansion towers merged");
  ok(!G.unlocked.Orange && G.D.turrets.Orange.levelLocked === 2, "Orange is level-locked at level 1");
  const H = plus({}, { level: 1, research: {}, passes: { arsenal: true } });
  ok(H.unlocked.Orange && H.D.turrets.Beacon.unlock === 900, "Arsenal Pass: no level locks, Beacon at 900 kills");
  ok(GAME.turrets.Orange === undefined, "classic data untouched");
}
// ---- each new tower does its job
{
  const G = plus();
  const m = E.build(G, "p1", "Orange", 150, 330);
  ok(!!m, "build mortar");
  G.energy = 1e6; E.waveSend(G);
  let blasts = 0;
  for (let i = 0; i < 12000; i++) { E.step(G); for (const f of drain(G)) if (f.k === "blast" && f.type === "small") blasts++; }
  ok(blasts > 3, "mortar shells land as small blasts (" + blasts + ")");
}
{
  const G = plus();
  const c = E.build(G, "p1", "Cyan", 150, 335);
  E.upgrade(G, "p1", c.id, "damage", true);
  ok(c.eff.damage === 2, "cryo strength 2 at max");
  const dm = E.build(G, "p1", "DamageUp", 150, 285);
  ok(c.eff.damage === 2, "damage enhancer doesn't boost cryo strength");
  E.waveSend(G);
  let slowed = false;
  for (let i = 0; i < 12000; i++) { E.step(G); for (const a of G.attackers) if (a.speed <= a.speedInit / 2 + 1e-9 && a.speed > 5) slowed = true; }
  ok(slowed, "cryo holds attackers at half speed");
}
{
  const G = plus();
  E.build(G, "p1", "Violet", 150, 330);
  G.energy = 1e9; E.waveSend(G);
  let maxHits = 0;
  for (let i = 0; i < 15000; i++) { E.step(G); const f = drain(G).filter(x => x.k === "spark" && x.look === "arc"); maxHits = Math.max(maxHits, f.length); }
  ok(maxHits === 2, "arc hits the target plus 1 jump at rate 0 (" + maxHits + ")");
}
{
  const G = plus();
  const v = E.build(G, "p1", "Vault", 150, 290);
  ok(!!v, "build vault");
  G.players.p1.cash = 10000;
  E.waveSend(G);
  ok(G.players.p1.cash === 10060, "vault pays min(cap 60, 2% of 10,000) = 60 (" + G.players.p1.cash + ")");
  E.build(G, "p1", "Vault", 230, 290); E.build(G, "p1", "Vault", 310, 290);
  ok(!E.build(G, "p1", "Vault", 390, 290), "max 3 vaults per player");
}
{
  const G = plus();
  const o = E.build(G, "p1", "Orbital", 400, 60);
  G.energy = 1e12; E.waveSend(G);
  let strikes = 0;
  for (let i = 0; i < 25000; i++) { E.step(G); for (const f of drain(G)) if (f.k === "orbital") strikes++; }
  ok(strikes >= 2 && strikes <= 3, "orbital strikes every 10 s (" + strikes + " in ~25 s)");
}
// ---- expansion combos
function comboRun(build, want) {
  const G = plus();
  G.energy = 1e9;
  let first = true;
  for (const [k, x, y] of build) {
    const t = E.build(G, "p1", k, x, y); if (!t) { ok(false, "build " + k + " " + x + "," + y); return null; }
    E.upgrade(G, "p1", t.id, "damage", true);
    if (!first) E.setDirectional(G, "p1", t.id, -90, 15);
    first = false;
  }
  E.waveSend(G);
  const seen = new Set();
  for (let i = 0; i < 25000 && !seen.has(want); i++) { E.step(G); for (const f of drain(G)) if (f.k === "combo") seen.add(f.name); }
  ok(seen.has(want), want + " fires (saw " + ([...seen].join(",") || "none") + ")");
  return G;
}
const Q = [[0, 0], [-36, -8], [36, -8], [0, -36]];
const grp = ks => ks.map((k, i) => [k, 150 + Q[i][0], 345 + Q[i][1]]);
comboRun(grp(["Orange", "Red", "Red"]), "carpet_bomb");
comboRun(grp(["Orange", "Cyan"]), "cryo_shell");
comboRun(grp(["Orange", "Violet"]), "ion_mortar");
comboRun(grp(["Cyan", "Yellow", "Green"]), "absolute_zero");
comboRun(grp(["Cyan", "Blue"]), "frost_mine");
comboRun(grp(["Violet", "Yellow", "Yellow"]), "ion_field");
comboRun(grp(["Violet", "Green"]), "storm");
// original recipes are not disturbed by new colours nearby
comboRun(grp(["Red", "Blue", "Blue", "Orange"]), "nuke");
// ---- beacon and research change combos
{
  const G = plus({}, { level: 99, research: { theory: 10 }, passes: { combomaster: true } });
  const r = E.build(G, "p1", "Red", 150, 345); E.upgrade(G, "p1", r.id, "damage", true);
  E.build(G, "p1", "Beacon", 150, 290);
  const m = G.mods.rechargeMult(G, r);
  ok(Math.abs(m - (1 - 0.15) * 0.85 * 0.75) < 1e-9, "recharge = theory x combo master x beacon (" + m.toFixed(4) + ")");
  ok(G.mods.comboDamage(G, r) === 1.2, "beacon +20% combo damage");
}
// ---- research and passes on economy
{
  const L = { level: 30, research: { funds: 10, salvage: 10, bunker: 5, bounty: 10 }, passes: { supply: true } };
  const G = plus({ mode: "medium" }, L);
  ok(G.players.p1.cash === 30 + 50 + 50, "starting cash 30 + research 50 + supply 50");
  ok(G.lives === 15, "bunker +5 lives");
  const b = E.build(G, "p1", "Blue", 150, 330);
  ok(E.sell(G, "p1", b.id) === 8, "salvage 80% resale: ceil(10*0.8) = 8");
  ok(Math.abs(G.mods.bounty(G, 10) - 12) < 1e-9, "bounty +10% research +10% supply");
}
// ---- products
{
  const G = plus({ mode: "medium" });
  G.waveNum = 20;
  const c0 = G.players.p1.cash; X.useProduct(G, "drop_m", "p1"); ok(G.players.p1.cash - c0 === 3000, "supply drop M = 10 x wave 20 x 15");
  for (let i = 0; i < 5; i++) X.useProduct(G, "life", "p1");
  ok(G.lives === 15 && !X.useProduct(G, "life", "p1"), "extra lives capped at 5 per game");
  G.lives = 1; G.lost = true; G.over = true;
  ok(X.useProduct(G, "revive", "p1") && G.lives === 5 && !G.over, "second chance revives with 5 lives");
  ok(X.revivePrice(G) === 199, "revive price doubles (" + X.revivePrice(G) + ")");
  ok(G.assisted, "products mark the run assisted");
}
// ---- progression maths
{
  ok(X.xpToNext(1) === 140, "level 1 -> 2 needs 140 XP");
  const meta = { level: 1, xp: 0, passes: {} };
  const G = { waveNum: 40, kills: 400, mode: "medium", challenge: null, won: false };
  const r = X.gameRewards(G, meta);
  ok(r.xp === Math.round(820 * 1.3 * 0.1 + 80), "medium wave 40 = 107 + 80 XP (" + r.xp + ")");
  ok(r.intel === Math.floor(Math.pow(40, 1.4) * 1.3 / 4 + 20), "intel formula (" + r.intel + ")");
  const ups = X.addXP(meta, 1000);
  ok(meta.level >= 4 && ups >= 3, "1000 XP from level 1 reaches level " + meta.level);
  ok(X.researchCost("funds", 0) === 40 && X.researchCost("funds", 10) === null, "research costs and caps");
  const S = { waveNum: 50, kills: 500, mode: "sandbox", challenge: null };
  ok(X.gameRewards(S, meta).xp === 0, "sandbox gives no XP");
}
// ---- clearance
{
  const GAME = require("../../onslaught-data/game.json");
  const m = { level: 50, xp: 0, passes: {}, research: {} };
  ok(X.prestige(m) && m.level === 1 && m.prestige === 1, "clearance resets to level 1");
  const D = X.data(GAME, m);
  ok(!D.turrets.Orbital.levelLocked && !D.turrets.Orange.levelLocked, "towers stay unlocked after clearance");
  ok(X.data(GAME, { level: 1, research: {}, passes: {} }).turrets.Orange.levelLocked === 2, "fresh level 1 still locked");
  ok(X.dailyQuests({ prestige: 1 }, "2026-10-13").list.length === 3 && X.dailyQuests({ prestige: 2 }, "2026-10-13").list.length === 4, "clearance 2 adds a 4th quest");
  const p = X.clearancePerks(10);
  ok(p.cash === 15 && p.lives === 1 && p.resale === 0.02 && p.bounty === 0.02, "tier 10 perks");
  const o = X.gameOpts({ players: ["p1"] }, { p1: { level: 1, prestige: 9, research: {}, passes: {} } });
  ok(o.lives === 11 && o.bonusCash.p1 === 15, "perks reach the game (lives " + o.lives + ", cash " + o.bonusCash.p1 + ")");
  ok(X.XD.progression.prestige.rewards.length === 10, "10 clearance tiers");
}
console.log(`${passes} passed, ${fails} failed`);
process.exit(fails ? 1 : 0);
