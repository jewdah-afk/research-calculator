// Loads the playtest (playtest/js/*.js) headless in a Node vm context: the real logic files in index.html order,
// break_eternity.js 2.1.2 (vendored, the same library the playtest loads from jsDelivr) and a minimal DOM stub so
// main.js (the loop) loads too. main.js keeps `step` private, so the loader appends one line to the in-memory copy
// that hands `step` out (PT.G.__step); the playtest files on disk are never changed.
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm");
const ROOT = path.resolve(__dirname, "../../.."); // repo root
const PLAYTEST = path.join(ROOT, "playtest");

// Park-Miller LCG: x = x * 48271 mod (2^31 - 1). Every product stays below 2^53, so JS and Luau doubles give the
// same sequence bit for bit (roblox/tools/parity/lua_dump.luau has the twin).
function lcg(seed) {
  let x = Math.max(1, Math.floor(seed) % 2147483647);
  return () => { x = (x * 48271) % 2147483647; return x / 2147483647; };
}

// A do-nothing DOM: every property is the stub, every call returns the stub, and it reads as "" / 0.
function domStub() {
  const store = new Map();
  const target = function () {};
  const stub = new Proxy(target, {
    get(t, k) {
      if (k === Symbol.toPrimitive) return (hint) => (hint === "number" ? 0 : "");
      if (k === Symbol.iterator) return function* () {};
      if (k === "then") return undefined; // not a promise
      if (k === "length") return 0;
      return stub;
    },
    set() { return true; },
    apply() { return stub; },
    construct() { return stub; },
    has() { return true; },
  });
  const localStorage = { getItem: (k) => (store.has(k) ? store.get(k) : null), setItem: (k, v) => store.set(k, String(v)), removeItem: (k) => store.delete(k), clear: () => store.clear() };
  return { stub, localStorage };
}

const ORDER = ["data", "core", "systems", "fishing", "aquarium", "nest", "riverside", "mine", "desert", "archivist_data", "archivist", "echo_field",
  "expedition_data", "expedition", "expedition_ai", "expedition_totem", "expedition_sacrifice", "expedition_loot", "expedition_forge", "quests",
  "expedition_secret", "expedition_night", "expedition_mythic", "main"];

// Returns { ctx, PT, G, Decimal, setNow(ms), streams }. `streams.other` drives Math.random; the field and the sparrows
// get their own streams (see playtest_dump.js), so Lua can replay the same draws without matching unrelated calls.
function load(opts = {}) {
  const { stub, localStorage } = domStub();
  let now = opts.now || 1760000000000;
  const FakeDate = class extends Date { constructor(...a) { if (a.length) super(...a); else super(now); } static now() { return now; } };
  const ctx = {
    console, setTimeout: () => 0, clearTimeout: () => {}, setInterval: () => 0, clearInterval: () => {},
    requestAnimationFrame: () => 0, cancelAnimationFrame: () => {}, addEventListener: () => {}, removeEventListener: () => {},
    document: stub, navigator: stub, location: stub, Image: function () { return stub; }, HTMLElement: function () {}, getComputedStyle: () => stub,
    localStorage, performance: { now: () => now }, devicePixelRatio: 1, innerWidth: 1600, innerHeight: 900, confirm: () => false, alert: () => {},
    atob: (s) => Buffer.from(s, "base64").toString("binary"), btoa: (s) => Buffer.from(s, "binary").toString("base64"), Date: FakeDate,
  };
  ctx.window = ctx; ctx.self = ctx; ctx.globalThis = ctx;
  vm.createContext(ctx);
  const run = (code, file) => vm.runInContext(code, ctx, { filename: file });
  run(fs.readFileSync(path.join(__dirname, "vendor/break_eternity.js"), "utf8"), "break_eternity.js");
  const streams = { other: lcg(opts.seed || 7) };
  run("Math", "math").random = () => streams.other();
  for (const f of ORDER) {
    let code = fs.readFileSync(path.join(PLAYTEST, "js", f + ".js"), "utf8");
    if (f === "main") {
      const i = code.lastIndexOf("requestAnimationFrame(frame);");
      if (i < 0) throw new Error("main.js: loop start not found");
      code = code.slice(0, i) + "PT.G.__step = step; PT.G.__legacyRadius = legacyRadius;\n" + code.slice(i);
    }
    run(code, f + ".js");
  }
  return { ctx, PT: ctx.PT, G: ctx.PT.G, Decimal: ctx.Decimal, setNow: (ms) => { now = ms; }, streams, lcg };
}

module.exports = { load, lcg, ROOT, PLAYTEST };

if (require.main === module) {
  const h = load();
  console.log("loaded:", Object.keys(h.PT).length, "PT entries; step:", typeof h.G.__step, "Decimal:", typeof h.Decimal);
}
