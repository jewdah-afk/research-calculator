# research-calculator

Small, dependency-free calculators for idle games. Open the HTML files directly —
no build step, no server, inputs persist in `localStorage`.

| Page | What it does |
|---|---|
| [`index.html`](index.html) | Infinite research multi & rune luck gain multi — closed-form scaling |
| [`tower.html`](tower.html) | **The Tower: Idle Tower Defense** — workshop & lab upgrade planner |

## Tower Planner

Covers **48 workshop stats** and **217 lab researches** — 36,795 tabulated
levels in total. Every cost is an exact table read, not a curve fit.

- **Workshop** — coins for any level span, the stat value at each end, what your
  coins actually reach, cost to max, and a level-by-level breakdown. Applies your
  Attack/Defense/Utility discount labs.
- **Labs** — exact coins, research time and gem rush cost for any span, with your
  Labs Speed lab, relic bonus, Elite Cell boost and parallel lab count folded in.
- **Next best coin** — ranks every stat's *next* level by coins per 1% gained.
- **Formulas** — the lab cost/time/gem model transcribed from the game bundle,
  live against your own numbers.
- **Sources** — where each number comes from, tiered by how close it sits to the
  game's own data.

### Data provenance

`data/tower-data.js` is generated from the TowerSmith "GOD tables", which are
extracted from the game's own upgrade tables. The full write-up — every source,
the bundle-level formulas, licensing and known gaps — is in
[`research/THE-TOWER-SOURCES.md`](research/THE-TOWER-SOURCES.md).

```sh
# regenerate the data
git clone --depth 1 --filter=blob:none --sparse https://github.com/AngryBrit/tower-smith.git
cd tower-smith && git sparse-checkout set tables src/data && cd ..
node tools/build-tower-data.js ./tower-smith

# verify it (79,576 checks, no dependencies)
node tools/verify-tower-data.js ./tower-smith
```

The verifier checks every per-level cost and duration for byte-identity against
upstream, and checks the lab gem model against both the GOD tables and the
published wiki rush table. Where upstream stores a display-rounded column, the
check asserts the rounding bound rather than equality — see the header comment
in the script for which is which and why.

### Licensing

The Tower data derives from [TowerSmith](https://github.com/AngryBrit/tower-smith)
and [The Tower Unified Tools](https://github.com/SFleet89/the-tower-unified-tools),
both **CC BY-NC-SA 4.0** — `tower.html` and `data/tower-data.js` inherit those
terms. Unofficial fan tool; *The Tower: Idle Tower Defense* is © Tech Tree Games.
