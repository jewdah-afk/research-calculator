# Porting the Stud City Incremental engine to Luau

The HTML draft runs the real Upgrade Land math. This note is for whoever builds it in Roblox.
It covers the number type, the loop, and every JS behaviour the formulas lean on that Luau does differently.

## What there is to port

| Piece | Where | Size |
| --- | --- | --- |
| Tree data: 722 nodes, 63 currencies, 118 decorations | `js/ul-data.js` | 1,360 formula functions |
| Engine: gain rates, buying, automation, resets, offline, saves | `js/engine.js` | about 550 lines |
| Plot grouping, build rules, level caps | `js/plots.js` | about 170 lines |

`ul-data.js` is copied from the original `index.html` (andyyim175/upgtree), unchanged.
`engine.js` copies the original functions line for line. Only DOM, sound and drawing calls were removed; events replace them.

## Numbers: plain doubles, no big number library

**Recommendation: use plain Luau `number`.**

- Luau numbers are IEEE doubles, the same as JS numbers. The same formula gives the same bits in both, so parity is exact.
- Upgrade Land itself runs on plain JS numbers. Every value in the game stays under 1.8e308. The largest values in the parity stress runs were around 1e50 to 1e142.
- The few places that hit infinity do so in the original too. Example: Loop Lagoon machine I05 gives x3 per level and has a max level of 1000, so 3^1000 is infinity in both.
- EternityNum or break_eternity would change results. They round differently and take many times the CPU per operation, which matters on phones.

Keep one escape hatch: route arithmetic in the few currency-total functions through a tiny module. That way a big number type could be swapped in later without touching the 1,360 formulas.

## Proof of parity (HTML side)

`tools/parity-test.js` runs the original page and this engine side by side in headless Chromium, with the same seeded `Math.random` and a fake clock. After every step it compares every currency and every level bit for bit.

- 5 scenarios: fresh play at x1 and at MAX with resets, plus 3 late-game states with all 63 currencies.
- 16,000 ticks in total. All match exactly.

Run the same kind of test for the Luau port: dump state after N ticks from both, then diff.

## Loop

- The game ticks every 100 ms (`GAME_TICK_MS`) with `dt = 0.1`. Keep a fixed-step accumulator on `Heartbeat`. Never pass a variable dt into the formulas.
- Automation runs every 200 ms of game time (`AUTOMATION_INTERVAL_MS`). It is checked at the end of the tick, the same as `tickGame`.
- Each tick: clear the frame caches first, then evaluate every discovered currency's gain rate once, in `discoveredCurrencies` order. After that, run the three loops exactly as `tickGame` does. The order matters because some formulas roll random numbers (next section).

## Caches

`cacheDirtyFrame` goes up on every tick and on every purchase. Gain rates, max levels, display costs and reset gains are cached per frame. Within one frame, a second call returns the first value.

Keep these semantics. Some formulas call `Math.random()`, so evaluating them twice in one frame would roll twice.

## Random

Ten formulas roll `Math.random()`:
- copper, silver, gold, lapis and diamonds chances
- the alpha crit (B06)
- lapis x25 (M54)
- customers (UB06, UB13)

Use one `Random.new()` and `:NextNumber()`. The odds are what matter. Draw-for-draw parity with the browser is not possible, and not needed.

## JS behaviours the formulas rely on (fix these when translating)

1. **Booleans used as numbers.** About 31 formulas multiply by a comparison, for example `(getCurr('XP') >= 10) * (getCurr('XP') / 10)` or `Math.random() <= 0.01 * lvl` used as a gain. In Luau, write `(cond and 1 or 0)`.
2. **`x || 0` treats 0, NaN and nil as 0.** In Luau, `x or 0` only catches nil. The engine uses `|| 0` for missing levels and currencies, so keep missing keys nil or write a helper.
3. **`%` on negatives.** JS keeps the sign of the left side. Luau `%` floors. Three formulas use `%`, so use `math.fmod` to match JS.
4. **`Math.round`.** JS rounds .5 up (toward +inf). Luau `math.round` rounds half away from zero. Use `math.floor(x + 0.5)`.
5. **`Math.clz32`** appears in the data. Use `bit32.countlz` on `x // 1` clamped to 32 bits.
6. **`Math.log10`, `Math.log2`, `Math.sqrt`, `Math.pow`** map to `math.log10`, `math.log(x, 2)`, `math.sqrt` and `x ^ y`. `Math.pow(neg, fraction)` is NaN in both.
7. **NaN checks.** `isNaN(x)` becomes `x ~= x`, and `isFinite(x)` becomes `x == x and math.abs(x) ~= math.huge`.
8. **Arrays are 0 based in JS.** Node `coords` and `reqs` are data, not indexes, so they port as is. `currencyOrder` and `discoveredCurrencies` are ordered lists, and the tick order depends on them.
9. **`saveGame` cleans live state.** The original sets any NaN or non-number currency or level to 0 before and after every reset. `sanitizeLiveState` in `engine.js` reproduces this.

A transpiler is the safest path for 1,360 formulas: parse `ul-data.js` with a JS parser and emit Luau with helpers for items 1 to 5. Hand-porting that many invites typos, and parity testing will catch any that slip through.

## Stud City Incremental changes (the only ones)

- **Offline:** hard cap of 3:00 (5:00 with the Offline Pass). It replaces the original softcap, which paid about 6 minutes for an hour away. It lives in `STUD_CONFIG.OFFLINE_CAP_SECONDS`. The payout rule is unchanged: rate times seconds, skipping the random and self-limiting currencies.
- **Display names only:** P shows as Studs, R as Blueprints, € as Golden Bricks, α as Alpha Bricks, and so on (`js/format.js`). Save keys keep the Upgrade Land ids.
- **Plot build rule:** a plot is built when its Upgrade Land baseplate decoration would show. Eight baseplates point at ids that do not exist in the data (B12, +B13, +B14, P16, A50, +B12, +B11, +B15), so in the original their backgrounds never appear. In Stud City those plots count as built once any machine on them has a level.

## Dev tools that are not game rules

- **MAX NEXT PLOT** sets levels directly and never touches the formulas. Each machine goes to its max level from the data, with two stops:
  - It does not follow machines that raise each other's max, because that chain runs to around 1e189.
  - It stops at the last level a player could ever pay for, where the next price would be bigger than the most any wallet can hold (about 1.8e308). This only bites on endless towers, which list a max of 1000 but price out long before. Loop Lagoon's I05 stops at 130 instead of 1000: level 629 would cost about 10^1880 Loops.

  52 presses build all 39 plots.
- **The only currency that reaches the number limit is `fragment`, and that is by design.** The Finale's 24 machines stack x2.4e13 each until fragments pass 1.7e308, and the World Two reset (`U1_RESET`) only pays when `fragment > 1.7e308`.
- **SIM TO NEXT PLOT and BOT** play through `buyUpgrade` and `executeReset` only. The greedy bot reaches 14 plots, ending with Cookie Cove at 3h41m of play, and then stalls. `js/benchmark.js` has the times.
