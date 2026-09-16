# research-calculator

Small, dependency-free calculators for idle games. Open the HTML files directly —
no build step, no server, inputs persist in `localStorage`.

| Page | What it does |
|---|---|
| [`index.html`](index.html) | Infinite research multi & rune luck gain multi — closed-form scaling |
| [`tower.html`](tower.html) | **The Tower: Idle Tower Defense** — workshop & lab upgrade planner |

## Tower Planner

Covers **48 workshop stats**, **217 lab researches** and **18 workshop
enhancements** — 42,330 tabulated levels — plus in-run cash curves, UW stone
costs, modules, bots, cards, guardians and the Vault. Every cost is an exact
table read, not a curve fit.

> **Data vintage: late June 2026.** Upstream's own stamp puts the workshop
> tables at `2026-06-27` and its last release at `2026-06-28`. Nothing shipped
> after that is reflected, and the verifier cannot detect it — it checks against
> the same tables. See the research notes for the fresher route.

- **Workshop** — coins for any level span, the stat value at each end, what your
  coins actually reach, cost to max, and a level-by-level breakdown. Applies your
  Attack/Defense/Utility discount labs.
- **Labs** — exact coins, research time and gem rush cost for any span, with your
  Labs Speed lab, relic bonus, Elite Cell boost and parallel lab count folded in.
- **Coin plan** — an indefinitely long, ordered "buy this next" sequence that
  maximises coin income. Anchored on *your* measured coins/hr, so it needs no
  enemy-scaling model. Scores income upgrades and cost-reduction labs in the
  same unit so they are actually comparable, and marks every step that leans on
  an assumption rather than a sourced curve.
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

# the rest of the systems (needs the unified-tools checkout too)
git clone --depth 1 https://github.com/SFleet89/the-tower-unified-tools.git
node tools/build-tower-extras.js ./tower-smith ./the-tower-unified-tools

# verify both (122,843 checks, no dependencies)
node tools/verify-tower-data.js ./tower-smith
node tools/verify-tower-extras.js ./tower-smith ./the-tower-unified-tools
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
