// One command for the whole Peckwood parity run (from anywhere):  node roblox/tools/parity/run.js
//   1. gen_data.js       regenerates roblox/src/shared/Birb/Data.luau from the playtest's live tables
//   2. playtest_dump.js  playtest values + simulated runs  -> out/playtest.json, out/scenarios.json
//   3. lua_dump.luau     the same through Game.luau in lune -> out/lua.json
//      migration_check.luau (v2 -> v3 saves) and smoke_check.luau (the whole server step on every dev save)
//   4. compare.js        -> REPORT.md (exit code 1 if the Phase 1 gate is below 100%)
// ONLY=<name substring> runs a subset of scenarios (REPORT.md then covers only those).
"use strict";
const path = require("path"), fs = require("fs"), { spawnSync } = require("child_process");
const ROBLOX = path.resolve(__dirname, "../..");
const t0 = Date.now();
console.log("data:", require("./gen_data.js").generate().file);
const r = require("./playtest_dump.js").main();
console.log(`playtest: ${r.length} scenarios (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
const home = process.env.USERPROFILE || process.env.HOME || "";
const lune = [path.join(home, ".rokit/bin/lune.exe"), path.join(home, ".rokit/bin/lune"), "lune"].find((p) => p === "lune" || fs.existsSync(p));
const L = spawnSync(lune, ["run", "tools/parity/lua_dump.luau"], { cwd: ROBLOX, stdio: "inherit", env: process.env });
if (L.status !== 0) { console.error("lune failed"); process.exit(2); }
// save migration (v2 -> v3) and a whole-server-step smoke run on fresh / every NEXT AREA / MAXED save
for (const f of ["tools/parity/migration_check.luau", "tools/parity/smoke_check.luau"]) {
  const r = spawnSync(lune, ["run", f], { cwd: ROBLOX, stdio: "inherit", env: process.env });
  if (r.status !== 0) { console.error(f + " failed"); process.exit(3); }
}
const c = require("./compare.js").main();
console.log(`Phase 1 gate: ${c.gate.pass} / ${c.gate.total}  (REPORT.md)  in ${((Date.now() - t0) / 1000).toFixed(1)} s`);
process.exit(c.gate.pass === c.gate.total ? 0 : 1);
