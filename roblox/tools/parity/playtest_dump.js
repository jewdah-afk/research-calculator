// Playtest side of the Peckwood parity harness. Loads the playtest headless (headless.js) and, for every scenario in
// playtest/parity/scenarios.js plus roblox/tools/parity/p1_scenarios.js, dumps:
//   1. every value playtest/parity/parity.js compares (its own `probe` function, read from parity.js at run time),
//   2. extra Phase 1 values ("p1 ..."): egg rolls, pickup / magnet / gravity radii, awards per egg type, seed ticks,
//      Molt parts, Sparrow formulas and milestones, castle requirements,
//   3. for Phase 1 scenarios, a simulated run ("sim <tag> ..."): the playtest's own main.js step for N seconds,
//      pickups, buys, Molt, tree purchases, the seed platform, the Sparrow, castle feeding and an evolution.
// Writes out/playtest.json (values) and out/scenarios.json (states + programs for lua_dump.luau).
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm");
const { load, lcg, PLAYTEST } = require("./headless.js");
const P1 = require("./p1_scenarios.js");

const OUT = path.join(__dirname, "out");
const SIM_DT = 0.05;
const UP_P1 = ["p_value", "p_speed", "p_capacity", "p_move_speed", "pr_popcorn_mult", "pr_radius_mult", "pr_respawn_mult", "s_more_popcorn", "s_more_feathers", "s_more_seeds",
  "p_golden_popcorn_value", "p_auric_silo", "pr_golden_popcorn_mult"];
const DRAWER = ["p_value", "p_speed", "p_capacity", "p_move_speed", "pr_popcorn_mult", "pr_radius_mult", "pr_respawn_mult", "s_more_popcorn", "s_more_feathers", "s_more_seeds"];
const TYPES = ["plain", "butter", "caramel", "cheese", "rainbow", "red", "golden"];
const ROLL_U = [...Array.from({ length: 64 }, (_, k) => k / 64), 0.8, 0.83, 0.8333, 0.8334, 0.87, 0.9, 0.95, 0.97, 0.98, 0.99, 0.995, 0.999, 0.9995, 0.9999, 0.99995, 0.99999, 0.999995, 0.999999];
const MILESTONES = ["resonance_flow", "steady_feeder", "mitosis_rhythm", "full_flock", "first_rebirb", "loop_engine"];
const EVO_KEYS = ["popcorn", "feathers", "seeds", "fish", "twigs", "moneta"];

function main() {
  const h = load({ seed: 7 });
  const { PT, G, ctx } = h;
  const Decimal = h.Decimal;
  const JSMath = vm.runInContext("Math", ctx);
  // parity.js's probe, unchanged
  const src = fs.readFileSync(path.join(PLAYTEST, "parity/parity.js"), "utf8");
  const a = src.indexOf("function probe("), b = src.indexOf("\n(async () => {");
  if (a < 0 || b < 0) throw new Error("parity.js probe not found");
  vm.runInContext(src.slice(a, b) + "\nthis.__probe = probe;", ctx);

  // random streams: egg type rolls, egg spots and sparrow wander each get their own (Lua replays the same draws)
  const streams = { type: lcg(1), pos: lcg(2), sparrow: lcg(3) };
  const withStream = (st, fn) => { const prev = JSMath.random; JSMath.random = () => streams[st](); try { return fn(); } finally { JSMath.random = prev; } };
  const rollType0 = PT.Field.prototype.rollType;
  PT.Field.prototype.rollType = function (s) { return withStream("type", () => rollType0.call(this, s)); };
  { const S0 = PT.Field.prototype.spawn; PT.Field.prototype.spawn = function (...args) { return withStream("pos", () => S0.apply(this, args)); }; }
  { const U0 = PT.updateSparrows; PT.updateSparrows = function (g, dt) { return withStream("sparrow", () => U0(g, dt)); }; }

  const big = (x) => { const d = x instanceof Decimal ? x : new Decimal(x || 0); const n = d.toNumber(); if (Number.isFinite(n)) return n; return { L: d.abs().log10().toNumber(), s: d.sign }; };
  const num = (x) => (x == null ? null : typeof x === "boolean" ? x : x instanceof Decimal ? big(x) : Number(x));

  function resetRuntime() {
    G.field.clear(); G.field.nextId = 1; G.sparrows = []; G.anchor = null; G.sparrowAcc = 0; G.rates = {}; G.gainAcc = {}; G.rateT = 0; G.seedTimer = 0;
    G.holdFeed = false; G.target = null; G.vx = 0; G.vy = 0; G.keys.clear();
  }

  function p1Values(s, put) {
    // egg rolls: the type a uniform u gives
    const field = new PT.Field();
    for (const u of ROLL_U) put(`p1 roll u=${u}`, () => { const prev = JSMath.random; JSMath.random = () => u; try { return TYPES.indexOf(rollType0.call(field, s)); } finally { JSMath.random = prev; } });
    const prof = PT.pickupProfile(s);
    put("p1 collect radius", () => prof.collectRadius); put("p1 magnet radius", () => prof.magnetRadius); put("p1 magnet speed", () => prof.magnetSpeed);
    put("p1 gravity radius", () => G.__legacyRadius(s)); put("p1 collection mult", () => PT.collectionMultiplier(s)); put("p1 max speed", () => PT.maxSpeed(s));
    // awards per egg type (popcorn emptied first so the delta is exact, then restored)
    for (const t of TYPES) for (const who of ["player", "sparrow"]) {
      const keep = { pop: s.resources.popcorn, tot: s.totalPopcornCollected, xp: s.sparrow.xp, acc: { ...G.gainAcc } };
      try {
        s.resources.popcorn = new Decimal(0); s.sparrow.xp = 0;
        PT.award(G, { type: t, x: 0, y: 0 }, who);
        put(`p1 award ${who} ${t}`, () => s.resources.popcorn);
        if (who === "sparrow") put(`p1 award sparrow xp ${t}`, () => s.sparrow.xp);
      } catch (e) { put(`p1 award ${who} ${t}`, () => { throw e; }); }
      finally { s.resources.popcorn = keep.pop; s.totalPopcornCollected = keep.tot; s.sparrow.xp = keep.xp; G.gainAcc = keep.acc; }
    }
    for (const plat of [true, false]) { const r = PT.seedRate(s, plat); put(`p1 seed ticks ${plat ? "platform" : "away"}`, () => r.ticksPerSec); put(`p1 seed per tick ${plat ? "platform" : "away"}`, () => r.perTick); }
    const pr = PT.prestige(s);
    put("p1 molt base", () => pr.base); put("p1 molt a", () => pr.a); put("p1 molt pay", () => pr.pay);
    put("p1 sparrow speed", () => PT.sparrowSpeed(s)); put("p1 sparrow drain mult", () => PT.sparrowDrainMult(s)); put("p1 sparrow rebirb boost", () => PT.sparrowRebirbBoost(s));
    put("p1 sparrow seed feed xp", () => PT.seedFeedXp(s)); put("p1 sparrow mitosis count", () => PT.mitosisCount(s)); put("p1 sparrow rebirb ready", () => PT.sparrowRebirbReady(s));
    put("p1 sparrow total xp", () => PT.sparrowTotalXp(s.sparrow.level, s.sparrow.xp));
    for (const c of [1, 2, 4, 8, 16]) put(`p1 sparrow mitosis need c${c}`, () => PT.mitosisNeed(s, c));
    for (const id of MILESTONES) put(`p1 sparrow milestone ${id}`, () => PT.milestoneMet(s, PT.SPARROW_MILESTONES.find((m) => m.id === id)));
    const req = PT.evoReq(s.evolutionCount);
    for (const k of EVO_KEYS) put(`p1 evo req ${k}`, () => req[k]);
    put("p1 feed progress", () => PT.feedProgress(s)); put("p1 evo cap", () => PT.evoCap(s));
  }

  // ---------------------------------------------------------------- simulated runs
  function snap(s, tag, put) {
    const P = `sim ${tag} `;
    for (const k of ["popcorn", "goldenFeathers", "sunflowerSeeds", "monetariaMoneta", "twigs"]) put(P + "wallet " + (k === "monetariaMoneta" ? "moneta" : k), () => s.resources[k]);
    put(P + "playTime", () => s.playTime); put(P + "totalPopcorn", () => s.totalPopcornCollected); put(P + "rebirths", () => s.rebirthCount); put(P + "evolutions", () => s.evolutionCount); put(P + "map", () => s.currentMap);
    const f = G.field.list(0);
    put(P + "field count", () => f.length); put(P + "field timer", () => G.field.timer.get(0) || 0); put(P + "field nextId", () => G.field.nextId);
    for (const t of TYPES) put(P + "field type " + t, () => f.filter((p) => p.type === t).length);
    f.slice(0, 8).forEach((p, i) => { put(P + `egg ${i} x`, () => p.x); put(P + `egg ${i} y`, () => p.y); put(P + `egg ${i} type`, () => TYPES.indexOf(p.type)); put(P + `egg ${i} id`, () => p.id); });
    put(P + "seedTimer", () => G.seedTimer); put(P + "rate popcorn", () => G.rates.popcorn ?? -1); put(P + "rate seeds", () => G.rates.sunflowerSeeds ?? -1);
    const sp = s.sparrow;
    put(P + "sparrow unlocked", () => !!sp.unlocked); put(P + "sparrow level", () => sp.level); put(P + "sparrow xp", () => sp.xp); put(P + "sparrow maxLevel", () => sp.maxLevelReached);
    put(P + "sparrow count", () => s.sparrowCount); put(P + "sparrow prestige", () => s.sparrowPrestigeCount); put(P + "sparrow resonance", () => s.sparrowResonanceXP);
    put(P + "sparrow drained", () => s.sparrowTotalEnergyDrained); put(P + "sparrow feeding", () => !!s.isFeedingSparrow); put(P + "sparrow draining", () => !!s.isDrainingSparrow);
    put(P + "bird count", () => G.sparrows.length);
    G.sparrows.slice(0, 4).forEach((bd, i) => { put(P + `bird ${i} x`, () => bd.x); put(P + `bird ${i} y`, () => bd.y); });
    const fed = { popcorn: s.monsterPopcornFed, feathers: s.monsterFeathersFed, seeds: s.monsterSeedsFed, fish: s.monsterFishFed, twigs: s.monsterTwigsFed, moneta: s.monsterMonetaFed };
    for (const k of EVO_KEYS) put(P + "castle fed " + k, () => fed[k]);
    put(P + "castle progress", () => s.monsterFeedProgress); put(P + "castle talked", () => !!s.hasTalkedToMonster);
    for (const id of UP_P1) put(P + "up " + id, () => PT.level(s, id));
    for (const [id] of PT.SUN) if ((s.sunflowerUpgrades[id] || 0) > 0) put(P + "sun " + id, () => s.sunflowerUpgrades[id]);
  }
  function runProgram(prog, put) {
    resetRuntime();
    let last = null;
    const s = () => G.s;
    const step = (dt) => G.__step(dt);
    const visibleStations = () => PT.STATIONS.filter((st) => st[0] !== "__platform" && !PT.isArchivistNode(st[0]) && !(st[0].startsWith("d_desert_") || st[0] === "d_unlock_archivist_tree") && PT.sunVisible(G.s, st[0]));
    for (const o of prog) {
      if (o.op === "seed") { streams.type = lcg(o.type); streams.pos = lcg(o.pos); streams.sparrow = lcg(o.sparrow); }
      else if (o.op === "map") { s().currentMap = o.map; s().player.x = o.x; s().player.y = o.y; G.vx = G.vy = 0; s().sunflowerTreeView = "base"; }
      else if (o.op === "platform") { const p = PT.STATIONS.find((x) => x[0] === "__platform"); s().currentMap = 1; s().sunflowerTreeView = "base"; s().player.x = p[1] + p[3] / 2; s().player.y = p[2] + p[4] / 2 - 15; G.vx = G.vy = 0; }
      else if (o.op === "wait") { const n = Math.round(o.t / SIM_DT); for (let i = 0; i < n; i++) step(SIM_DT); }
      else if (o.op === "eggs") { const eggs = G.field.list(0).slice(0, o.n).map((p) => ({ x: p.x, y: p.y })); s().currentMap = 0; for (const e of eggs) { s().player.x = e.x; s().player.y = e.y; G.vx = G.vy = 0; step(SIM_DT); } last = eggs.length; }
      else if (o.op === "buy") last = o.max ? PT.buyMax(s(), o.id) : PT.buy(s(), o.id);
      else if (o.op === "buyAll") { last = 0; for (const id of DRAWER) if (!id.startsWith("s_") || PT.hasSun(s(), "d_sunflower_machine")) last += PT.buyMax(s(), id); }
      else if (o.op === "molt") last = PT.molt(G);
      else if (o.op === "evolve") last = PT.evolve(G);
      else if (o.op === "sun") last = PT.buySun(s(), o.id);
      else if (o.op === "sunAll") { last = 0; for (const st of visibleStations()) if (PT.buySun(s(), st[0]) === "") last++; }
      else if (o.op === "sparrow") {
        const w = o.what, S = s();
        if (w === "feed") { S.isFeedingSparrow = true; S.isDrainingSparrow = false; }
        else if (w === "drain") { S.isDrainingSparrow = true; S.isFeedingSparrow = false; }
        else if (w === "stop") { S.isDrainingSparrow = false; S.isFeedingSparrow = false; }
        else if (w === "mitosis") last = PT.mitosis(S);
        else if (w === "rebirb") last = PT.sparrowRebirb(S);
        else if (w === "autoMitosis") S.sparrowAutoMitosisEnabled = true;
        else if (w === "autoRebirb") S.sparrowAutoRebirbEnabled = true;
        else if (w.startsWith("rate:")) S.sparrowSeedFeedRatePercent = +w.slice(5);
      }
      else if (o.op === "talk") s().hasTalkedToMonster = true;
      else if (o.op === "hold") G.holdFeed = o.on;
      else if (o.op === "give") PT.add(s(), o.cur, new Decimal(o.n));
      else if (o.op === "snap") { snap(s(), o.tag, put); put(`sim ${o.tag} last`, () => (typeof last === "string" ? ["", "owned", "locked", "not enough"].indexOf(last) : last ?? -1)); }
      else throw new Error("unknown op " + o.op);
    }
  }

  const scenarios = [];
  for (const sc of require(path.join(PLAYTEST, "parity/scenarios.js"))) scenarios.push({ ...sc, program: P1.PROGRAMS[sc.name] });
  for (const sc of P1.SCENARIOS) scenarios.push(sc);
  const only = process.env.ONLY;
  const results = [];
  for (const sc of scenarios) {
    if (only && !sc.name.includes(only)) continue;
    resetRuntime();
    h.setNow(1760000000000);
    const values = ctx.__probe({ side: "ours", scenario: JSON.parse(JSON.stringify(sc)) });
    const put = (k, f) => { try { values[k] = num(f()); } catch (e) { values[k] = "ERR " + String(e.message).slice(0, 60); } };
    const s = G.s;
    p1Values(s, put);
    if (sc.program) runProgram(sc.program, put);
    results.push({ name: sc.name, p1: P1.P1_NAMES.has(sc.name), values });
  }
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, "playtest.json"), JSON.stringify({ generated: new Date().toISOString(), results }));
  fs.writeFileSync(path.join(OUT, "scenarios.json"), JSON.stringify({ simDt: SIM_DT, drawer: DRAWER, upP1: UP_P1, types: TYPES, rollU: ROLL_U, milestones: MILESTONES, evoKeys: EVO_KEYS,
    scenarios: scenarios.filter((sc) => !only || sc.name.includes(only)).map((sc) => ({ name: sc.name, p1: P1.P1_NAMES.has(sc.name), echo: !!sc.echo, state: sc.state, program: sc.program || null })) }));
  return results;
}

module.exports = { main };
if (require.main === module) {
  const t0 = Date.now();
  const r = main();
  console.log(`playtest: ${r.length} scenarios, ${r.reduce((n, x) => n + Object.keys(x.values).length, 0)} values in ${Date.now() - t0} ms`);
}
