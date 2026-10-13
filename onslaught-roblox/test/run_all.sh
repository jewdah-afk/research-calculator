#!/usr/bin/env bash
# Runs every Onslaught check: JS suites, Luau unit tests, and the JS <-> Luau bit-exact parity traces.
# Needs node and lune on PATH (or LUNE=/path/to/lune).
set -euo pipefail
cd "$(dirname "$0")/.."
LUNE=${LUNE:-lune}
TMP=$(mktemp -d)
node ../onslaught-html/test/sim_test.js
node ../onslaught-html/test/expansion_test.js
EXP=$(node -e '
const X=require("../onslaught-html/expansion.js");const got=[];
for(let l=1;l<=60;l++)got.push(X.xpToNext(l));
for(const r of X.XD.research)for(let l=0;l<r.max;l++)got.push(X.researchCost(r.id,l));
for(const d of ["2026-01-01","2026-10-13","2027-02-28"])for(const it of X.dailyQuests({},d).list)got.push(it.id);
console.log(got.join(","))')
"$LUNE" run test/expansion_test.luau "$EXP"
for t in test/unit/*.luau; do [ -e "$t" ] && "$LUNE" run "$t"; done
node test/parity/trace.js > "$TMP/js.jsonl"
"$LUNE" run test/parity/trace.luau > "$TMP/lua.jsonl"
node test/parity/compare.js "$TMP/js.jsonl" "$TMP/lua.jsonl"
# Roblox place: build with Rojo, then play it headless (lobby, party, match, products)
if command -v "${ROJO:-rojo}" >/dev/null 2>&1; then
	"${ROJO:-rojo}" build default.project.json -o "$TMP/build.rbxl" >/dev/null
	"$LUNE" run test/roblox/smoke.luau "$TMP/build.rbxl" | tail -1
fi
