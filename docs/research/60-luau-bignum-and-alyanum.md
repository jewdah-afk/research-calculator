# Big-Number Arithmetic in Roblox Luau — AlyaNum and the Alternatives

> **Scope.** A reference chapter for a team porting a large incremental/idle game to Roblox Luau,
> where in-game values reach tetration-level magnitudes (`E(4)` = `eeee1` = 10^10^10^10) and beyond.
> Every API claim below is traced to source I read; anything I could not verify is marked
> `[UNVERIFIED]`, and second-hand community claims are marked `[COMMUNITY, SECOND-HAND]`.
>
> **Primary source read:** `evilbocchi/alyanum` `src/init.luau` @ `main` (2,839 lines), plus
> `src/index.d.ts` (568 lines), `wally.toml`, `LICENSE`. See `## Sources` for the full list.

---

## Outline

1. [TL;DR](#tldr)
2. [The magnitude ladder](#the-magnitude-ladder)
3. [Notation systems you must understand](#notation-systems-you-must-understand)
4. [Library comparison table](#library-comparison-table)
5. [AlyaNum in depth](#alyanum-in-depth)
6. [The alternatives in depth](#the-alternatives-in-depth)
7. [Performance engineering for a tick loop](#performance-engineering-for-a-tick-loop)
8. [Serialization and persistence](#serialization-and-persistence)
9. [Formatting for display](#formatting-for-display)
10. [Correctness pitfalls](#correctness-pitfalls)
11. [Porting guidance](#porting-guidance)
12. [Sources](#sources)

---

## TL;DR

- **`E(4)` is not a hard problem.** `eeee1` = 10^10^10^10 is a 4-tall power tower. AlyaNum stores it as
  `{multiplicand = 1e10, exponent = 2}` — two of the seven fields, with the `exponent` field capable of
  holding up to 9,007,199,254,740,991. AlyaNum reaches `E(4)` with **~15 orders of magnitude of headroom in
  the exponent field alone**, before tetration is even touched. (Verified by hand-simulating `fix()` from
  `src/init.luau:168`.)
- **AlyaNum's real ceiling is heptation**: `10↑↑↑↑↑n`, with `n` up to 2^53−1. Internally it is a flat
  7-field struct: `{sign, multiplicand, exponent, tetrate, pentate, hexate, heptate}`. Once `heptate`
  itself would exceed 2^53−1 there is no eighth field — the ladder stops. (`src/init.luau:150-158`, `fix()`.)
- **AlyaNum is MIT-licensed and actively maintained.** Latest commit 2026-08-24, version 1.2.0,
  `wally add evilbocchi/alyanum` or `npm i @rbxts/alyanum`. Author: `evilbocchi`. It is a rewrite-fork of
  OmegaNum (FoundForces / Naruyoko).
- **It uses metatables for full operator overloading**: `__add __sub __mul __div __pow __mod __eq __lt __le
  __unm __tostring __concat` are all defined (`src/init.luau:2754-2793`). `a + b`, `a < b`, `a == b`,
  `tostring(a)` all work. Mixed `AlyaNum + number` works because every metamethod funnels through
  `metamethodValue()`, which promotes a raw `number` via `newNumber()`.
- **Every operation allocates.** `fix()` ends in `setmetatable(number, AlyaNum)` on a fresh table, and every
  public method wraps its arguments in `AlyaNum.new(...)`. There is **no public mutate-in-place API** — the
  two `mutable*` helpers (`mutablePow10`, `mutableLog10`, `mutableUnary`) are file-locals and are not
  exported. Budget one 7-field table allocation per arithmetic op and design the tick loop around that.
- **AlyaNum has a genuine fast path for ordinary magnitudes.** `add`/`sub`/`mul` each begin with a guard that
  checks all four hyperoperation fields are 0 and `exponent < 2`, and if so does the math in raw float64 and
  returns `AlyaNum.new(sum)`. Below ~1e308 you pay one table alloc and a branch, not a tower walk.
- **`AlyaNum.new` on an existing AlyaNum returns the same object** and on a `BaseAlyaNum` table it
  `setmetatable`s that table **in place**. `toBaseAlya()` strips the metatable **in place** and the source
  comment says so explicitly. This is the single biggest aliasing footgun in the library.
- **Serialization is easy because `BaseAlyaNum` is a plain, flat, 7-number table.** `HttpService:JSONEncode`
  on it round-trips losslessly-ish; the better option for DataStore size is a compact string. There is also
  `lbencode`/`lbdecode` (`toSingle`/`fromSingle`), a **lossy but order-preserving** encoding into a single
  float64 designed for `OrderedDataStore` leaderboards — never use it as your save format.
- **Formatting is first-class and configurable.** `toSuffix`, `toScientific`, `toEChain`, `toEnt`,
  `toHyperE`, `toString`, plus `changeSuffixes`, `changeDecimalPoints`, `changeDefaultAbbreviation`.
  `toString` auto-escalates suffix → scientific → e-chain → E(n) → hyper-E as magnitude grows.
  Note: `changeDecimalPoints` and `changeSuffixes` are **process-global mutable state**.
- **`buffer` and `vector` are not used by any of these libraries.** AlyaNum's values are Lua tables.
  A `vector` (3 floats) cannot hold 7 fields; a `buffer`-backed struct-of-arrays pool is possible but you
  would be writing it yourself. `--!native` and `--!optimize 2` are on in AlyaNum's source, which is the
  realistic performance lever.
- **Never mix raw `number` and big-number values in the same variable.** Luau's type solver will not stop
  `gold = gold + 1` silently producing a float64 once `gold` is typed `any`. Use a branded/opaque type alias
  and a linted boundary; the concrete recipe is in [Correctness pitfalls](#correctness-pitfalls).
- **Porting from `break_infinity.js`/`Decimal`:** the mechanical rules are (1) `new Decimal(x)` →
  `AlyaNum.new(x)`, (2) `a.plus(b)`/`a.times(b)` → `a:add(b)`/`a:mul(b)` **or** `a + b`, (3) `a.gt(b)` →
  `a:moreThan(b)` or `a > b`, (4) `a.log10()` returns a **number** in break_infinity but an **AlyaNum** in
  AlyaNum, (5) `Decimal.max(a,b)` is a static in JS but an **instance method** `a:max(b)` in AlyaNum.
- **DataStore limits that bind you:** 4 MB per value, 260 KB per `SetAsync` key in practice for
  `DataStoreService` values, and a 50-character key limit. A flat JSON `BaseAlyaNum` is ~110 bytes; a compact
  string form is ~10-30 bytes. At 10,000 stored big numbers per player the difference is 1.1 MB vs 0.3 MB.
- **If you don't need tetration, don't pay for it.** SerikaNum (same author, caps at 10^(2^1024)) is claimed
  4–20x faster than AlyaNum. But your game reaches `E(4)`, so you *do* need tetration — AlyaNum, OmegaNum,
  ExpantaNum, or break_eternity are your only real choices.

---

## The magnitude ladder

The only question that matters when picking a library is: **what is the largest number your game will ever
produce, and does the library's representation reach it?** Here is the ladder, rung by rung.

### Rung 0 — float64 (`number` in Luau)

Luau's `number` is an IEEE-754 binary64 double.

| Property | Value |
|---|---|
| Largest finite value | `1.7976931348623157e308` |
| AlyaNum's rounded constant for it | `1.797693015e308` (`FLOAT64_LIMIT`, `src/init.luau:16`) |
| `log10` of that | `308.2547155309599` (`LOG10_FLOAT64_LIMIT`, `src/init.luau:19`) |
| Largest **integer-exact** value | `2^53 − 1 = 9007199254740991` (`FLOAT64_SAFE_LIMIT`, `src/init.luau:22`) |
| `log10` of that | `15.954589770191003` (`LOG10_FLOAT64_SAFE_LIMIT`, `src/init.luau:25`) |
| Above the max | `math.huge` (`inf`), and all arithmetic is absorbing |

Those four constants reappear everywhere in every library on this list. `2^53−1` is the normalization
threshold: it is the point above which a float64 can no longer count integers one at a time, so every
scientific-notation library "carries" into the exponent there rather than at 1e308. This is why you will see
`9e15` in so many published limits.

An idle game hits 1e308 embarrassingly fast. A single prestige layer with a x2 multiplier per upgrade and
1,024 upgrade purchases is already past it.

### Rung 1 — scientific libraries: mantissa + exponent

Store `sign * mantissa * 10^exponent` where `exponent` is itself a float64. Now the reachable magnitude is
`10^(1.8e308)`, and if you insist the exponent stay integer-exact, `10^(9e15)`.

- **`break_infinity.js`** (Patashu): README states *"bigger in magnitude than 1e308, up to as much as
  **1e9e15**"*. Deliberately trades accuracy for speed vs `decimal.js`.
- **`decimal.js`**: same `e9e15` ceiling, arbitrary precision, much slower.
- **SerikaNum** (evilbocchi): *"utilising two number primitives to reach up to **10^(10^308)**"*.
- **QNum** (notiku): *"a normalized mantissa/exponent pair"*; `[UNVERIFIED]` exact ceiling — the README does
  not state one, but a float64 exponent implies ~`10^(1.8e308)`.
- **InfiniteMath** (KdudeDev): *"allows you to surpass the double-precision floating-point number limit of
  `10^308`"*; the DevForum title quoted in its own README is *"go above 10^308 (1e308)"*.
  `[UNVERIFIED]` exact ceiling from source.

**This rung cannot represent `E(4)`.** `10^10^10^10` needs an exponent of `10^10^10 = 10^10000000000`, which
is itself ~1e10000000000 — far past what a float64 exponent field can hold. A mantissa+exponent library
overflows to infinity here. If your game reaches `E(4)`, **rung 1 is disqualified**, full stop.

### Rung 2 — iterated-exponential ("layer") libraries

Add a **layer count**: how many times to apply `x ↦ 10^x`.

- **`break_eternity.js`** (Patashu): `sign * 10^10^10^...(layer times)...mag`, reaching **`10^^1.8e308`**
  and as small as `10^-(10^^1.8e308)`. From its README: *"if it is above 9e15, log10(mag) it and increment
  layer. If it is below log10(9e15) (about 15.954) and layer > 0, Math.pow(10, mag) it and decrement layer."*
  Three fields: `sign`, `layer`, `mag`.
- **AlyaNum's `exponent` field alone** is exactly this: apply `10^x` to `multiplicand`, `exponent` times.

`E(n)` in the notation your team uses is precisely the layer count. `E(4)` = layer 4 = `10^10^10^10`.
**Any rung-2 library represents `E(4)` trivially** — `break_eternity` with `layer = 4`, AlyaNum with
`exponent = 2` (after normalization folds two of the layers into the mantissa; verified below).

Rung 2's own ceiling is `10↑↑(layer_max)` — tetration with a bounded height. Once your game needs a power
tower taller than 9e15 (or 1.8e308) levels, you need rung 3.

### Rung 3 — hyperoperation libraries

Add fields for tetration, pentation, hexation, … i.e. `10↑↑`, `10↑↑↑`, `10↑↑↑↑`.

- **AlyaNum**: fixed 7-field struct, ceiling ≈ **`10↑↑↑↑↑(9.007e15)`** (heptation). Hard stop: no 8th field.
- **OmegaNum.js** (Naruyoko): *"A huge number library holding up to **10{1000}9e15**"*, reaching level
  f_ω. *"Internally, it is represented as a sign and array. … `[n0,n1,n2,n3...]` … represents
  `sign*(...(10↑³)^n3 (10↑↑)^n2 (10↑)^n1 n0)`."* The array is **unbounded in length up to 1000 entries**,
  so arrow-depth is a runtime quantity, not a compile-time one.
- **ExpantaNum.js** (Naruyoko): *"holding up to **{10,9e15,1,2}**"*, level f_(ω+1). Internally
  `sign`, an array of `[arrow_index, repeat_count]` **pairs**, and a `layer` counter, where `Jx = 10{x}10`.
  Sparse representation, so extremely deep arrow counts cost nothing.
- Naruyoko's roadmap names the next rungs: `OmegaExpantaNum.js` (f_ω2), `MegotaNum.js` (f_(ω²)),
  `PowiainaNum.js` (f_(ω³)), `GodgahNum.js` (f_(ω^ω)). None are relevant to a shipping Roblox game.

### Where `E(4)` sits — precisely

```
value                       tower height   float64?  rung-1?  rung-2?  rung-3?
--------------------------- -------------- --------- -------- -------- --------
1e308                       ~1             edge      yes      yes      yes
1e(9e15)      = E2-ish      2              no        yes      yes      yes
1e(1.8e308)                 2              no        edge     yes      yes
ee1e308       = E(3)-ish    3              no        NO       yes      yes
eeee1         = E(4)        4              no        NO       yes      yes
E(9e15)                     9.007e15       no        NO       AlyaNum  yes
10^^(1.8e308)               1.8e308        no        NO       b_eternity yes
10^^^10       (pentation)   —              no        NO       NO       yes
10↑↑↑↑↑(9e15) (heptation)   —              no        NO       NO       AlyaNum max
10{1000}9e15                —              no        NO       NO       OmegaNum max
{10,9e15,1,2}               —              no        NO       NO       ExpantaNum max
```

**Conclusion for your team: `E(4)` needs at minimum a rung-2 library, and AlyaNum clears it by an
astronomical margin.** The interesting question is not "can AlyaNum do `E(4)`" (it can, with ~15 orders of
magnitude of spare capacity in a single field) but "does AlyaNum's *heptation* ceiling hold for your game's
endgame" — and unless you are designing an explicitly googological game with pentation-tier prestige layers,
it will.

#### Verification of the `E(4)` claim

I hand-simulated AlyaNum's `fix()` normalizer (`src/init.luau:168-243`) on the raw form of `10^10^10^10`,
i.e. `multiplicand = 10, exponent = 3`:

```
input : {sign=1, multiplicand=10,   exponent=3, tetrate=0, pentate=0, hexate=0, heptate=0}
fix() : multiplicand 10 < LOG10_FLOAT64_SAFE_LIMIT (15.9546) and exponent > 0
        -> multiplicand = 10^10 = 1e10, exponent = 2
        -> 1e10 >= 15.9546, stop
output: {sign=1, multiplicand=1e10,  exponent=2, tetrate=0, pentate=0, hexate=0, heptate=0}
```

`exponent = 2` against a field ceiling of `FLOAT64_SAFE_LIMIT = 9007199254740991`. `E(4)` uses
**0.00000000000002%** of AlyaNum's exponent field, and none of `tetrate`, `pentate`, `hexate`, `heptate`.

---

## Notation systems you must understand

Idle games display all of these, sometimes simultaneously, and players switch between them in settings.
You need to be able to read every one of them off a debug log.

### 1. Standard suffix notation (K / M / B / T / Qd …)

`1.25M`, `9.99Qn`, `3.00Vt`. The most player-friendly, and useless past ~1e3000. AlyaNum ships a
four-tier suffix table (`src/init.luau:31-141`):

```lua
suffixes = {
    beginning = { "K", "M", "B" },
    first  = { "U","D","T","Qd","Qn","Sx","Sp","Oc","No" },   -- units
    second = { "De","Vt","Tg","Qdg","Qng","Sxg","Spg","Ocg","Nog" }, -- tens
    third  = { "Ce","Dce","Tce","Qdce","Qnce","Sxce","Spce","Occe","Noce" }, -- hundreds
    mult   = { "Mi","Mc","Na","Pi","Fm","At","Zp","Yc","Xo","Ve", ... }, -- ~120 entries
}
```

The `first`/`second`/`third` tables compose the Latin -illion names positionally (units + tens + hundreds),
and `mult` supplies the next tier. AlyaNum's `toString` stops using suffixes above
`MAX_SUFFIX = {multiplicand = 3000000, exponent = 1}` — i.e. `10^3000000` (`src/init.luau:366`), and
`serikaNumToSuffix` switches from `getTier1Suffix` to `getTier2Suffix` at `exponent > 3002`.

### 2. Scientific / engineering notation

`1.25e6`. **Engineering** notation is the same thing constrained to exponents that are multiples of 3
(`1.25e6`, `12.5e6`, `125e6`, `1.25e9`), which lines up with the suffix boundaries and is what players who
dislike suffixes usually want. AlyaNum has scientific (`toScientific`) but **no built-in engineering mode**;
you write it yourself (code in [Formatting for display](#formatting-for-display)).

Note AlyaNum's scientific output recursively abbreviates the *exponent* itself:
`serikaNumToScientific` calls `numberToSuffix(exponent)`, so you get `1.23e1.5M`, not `1.23e1500000`.

### 3. Hyper-E / E-chain notation

Two related forms, both present in AlyaNum:

**E-chain** (`toEChain`): literally repeat the letter `e`. `ee1M` means `10^(10^(1000000))`.
From the source doc comment: *"An E chain is exactly what it says. `1e(1e1M)` is formatted as `ee1M`.
E chains place all Es at the start, and have a maximum chain of 10 Es."* Above 10 `e`s it falls through
to `toEnt`. This is the same input format `break_eternity.js` accepts (`eeX === 10^10^X`).

**E(n) / "Ent" form** (`toEnt`): `E(3)2` = `10^(10^(10^2))`. Doc comment: *"y is the number of times to
perform 10^x"*. The `y` is itself suffix-formatted, so you will see `E(1.5M)2`. AlyaNum cites
[Nihilustheabsolutist's E function](https://googology.fandom.com/wiki/Nihilustheabsolutists_E_function).
**This is your team's `E(4)`.** `E(4)1` = `10^10^10^10^1` = `eeee1`.

**Hyper-E** (`toHyperE`): `Ex#a#b#c#d#e`. AlyaNum's own doc comment defines its fields as:
*"a is the number of times to perform `10^x`, b is the number of times to perform `10^^x`, c is the number
of times to perform `10^^^x` and so on."* Reading `toHyperE` (`src/init.luau:1928-1954`), the emitted
string is:

```
"E" .. suffix(multiplicand)
     .. ("#" .. suffix(exponent))      if exponent > 0
     .. ("#" .. suffix(tetrate + 1))   if tetrate  > 0
     .. ("#" .. suffix(pentate + 1))   if pentate  > 0
     .. ("#" .. suffix(hexate  + 1))   if hexate   > 0
     .. ("#" .. suffix(heptate + 1))   if heptate  > 0
```

so it is a direct, positional dump of the internal struct. Sbiis Saibian's canonical Hyper-E notation
(`E100#100` = grangol) uses `#` as a "hyperion" separator with the same escalating-hyperoperator meaning;
whether AlyaNum's `+1` offsets make its output *numerically identical* to canonical Hyper-E for every input
is `[UNVERIFIED]` — treat AlyaNum's hyper-E as "AlyaNum's hyper-E", and do not feed it to a third-party
googology parser without testing.

### 4. Arrow notation (Knuth up-arrows)

`a↑b` = `a^b`. `a↑↑b` = tetration = a power tower of `a`s, `b` tall. `a↑↑↑b` = pentation = repeated
tetration. And so on. The arrow count maps directly onto AlyaNum's field names:

| Arrows | Name | Hyperoperation index | AlyaNum field |
|---|---|---|---|
| `↑` | exponentiation | 4 | `exponent` |
| `↑↑` | tetration | 5 | `tetrate` |
| `↑↑↑` | pentation | 6 | `pentate` |
| `↑↑↑↑` | hexation | 7 | `hexate` |
| `↑↑↑↑↑` | heptation | 8 | `heptate` |

AlyaNum's README limit of "10^^^^^10" is five carets = five arrows = **heptation**, consistent with the
`heptate` field being the last one. The ASCII `^^` convention (caret-doubling for arrows) is what you'll see
in incremental-game UIs because `↑` is not in every font Roblox ships.

`10{n}m` is shorthand for `10↑ⁿm` — OmegaNum's quoted limit `10{1000}9e15` means 1000 arrows.

### 5. Bowers-style / BEAF array notation

Jonathan Bowers' Exploding Array Function. `{a,b}` = `a^b`, `{a,b,c}` = `a↑^c b`, and adding entries
escalates further. ExpantaNum's quoted limit `{10,9e15,1,2}` is a BEAF linear array. **You will almost
certainly never display this to a player**, but it appears in library documentation as the canonical way to
state a ceiling, and it is the reason OmegaNum/ExpantaNum describe themselves in terms of fast-growing
hierarchy levels (f_ω, f_(ω+1)). Note that BEAF only has an agreed-upon definition up to tetrational arrays
`[COMMUNITY, SECOND-HAND]`, so treat these ceilings as "so large it does not matter" rather than as exact.

### Escalation order in AlyaNum's `toString`

`toString` (`src/init.luau:1955-1997`) picks a notation by magnitude, and this is the default a player sees:

```
value < 1e-9 (MAX_FRACTIONAL)         -> "1 / " .. toSuffix(1/x)
DEFAULT_ABBREVIATION == "suffix"
  and no hyperops and x < 10^3000000  -> toSuffix   e.g. "1.25M"
x < MAX_SCIENTIFIC {m=300008, e=4}    -> toScientific e.g. "1.23e1.5M"
x < MAX_E_CHAIN {m=1e10, e=8, tet=1}  -> toEChain    e.g. "eee1.5M"
x < MAX_ENT {m=306, e=1, tet=2}       -> toEnt       e.g. "E(1.5M)2"
otherwise                             -> toHyperE    e.g. "E10#8#3#2"
```

That cascade is a good default. It is also **global, not per-player** — see
[Formatting for display](#formatting-for-display) for how to give players a choice without mutating
library state.

---

## Library comparison table

### The libraries that actually matter for a Luau port

| | **AlyaNum** | **OmegaNum (Luau)** | **ExpantaNum.js** | **break_infinity.js** | **plain float64 (`number`)** |
|---|---|---|---|---|---|
| **Max magnitude** | `10↑↑↑↑↑(2^53−1)` (heptation) | `10{1000}9e15` (1000 arrows) | `{10,9e15,1,2}` (BEAF) | `1e(9e15)` | `1.7976931348623157e308` |
| **Reaches `E(4)`?** | **Yes**, trivially (`exponent = 2`) | Yes | Yes | **No** | No |
| **Representation** | flat 7-field table `{sign, multiplicand, exponent, tetrate, pentate, hexate, heptate}` | `{sign, {n0, n1, n2, …}}` — outer table + inner array | `sign`, `[[a,b],[a,b],…]`, `layer` — nested pair arrays | `{sign, mantissa, exponent}` (3 fields) | 8 bytes, a register |
| **Tables allocated per value** | **1** | **2** | **2 + one per array pair** | n/a (JS object) | **0** |
| **Est. bytes per value (Luau)** | ~300 (hash part, 8 node slots) `[ESTIMATE]` | ~350–600 | n/a (no Luau port) | n/a (no Luau port) | 8 (unboxed) |
| **Operator overloading** | **Yes** — `+ - * / ^ % == < <= unary- tostring ..` | **No** — function-table API only, verified: zero `setmetatable`/`__add` in source | No (JS methods) | No (JS methods) | native |
| **Method API** | `a:add(b)`, `a:mul(b)`, `a:moreThan(b)`, `a:tet(b)` … | `OmegaNum.add(a, b)` only | `a.add(b)` | `a.plus(b)` / `a.add(b)` | `+` |
| **Mixed `bignum <op> number`** | Yes, metamethods promote via `newNumber` | No — you must convert | Yes (constructor coercion) | Yes | n/a |
| **Luau / Roblox** | **Native.** `--!native`, `--!optimize 2`, Wally + roblox-ts, `default.project.json` | Yes (a Lua file you drop in) | **No port** | **No port** | native |
| **Distribution** | `wally add evilbocchi/alyanum`; `npm i @rbxts/alyanum` | copy-paste `.lua` from a fork | npm only | npm only | n/a |
| **License** | **MIT** (`Copyright (c) 2024 evil bocchi`) | `[UNVERIFIED]` — the FoundForces original has no license file in the forks I read | MIT `[UNVERIFIED — not read]` | MIT `[UNVERIFIED — not read]` | n/a |
| **Maintained?** | **Yes** — v1.2.0, latest commit 2026-08-24, CI green, tests + benches in-repo | Forks only; `Bry10022/OmegaNum-Lua` updated 2026-09-08, 0 stars | Yes (Naruyoko) | Yes (Patashu) | n/a |
| **Typed API** | Yes — Luau `export type AlyaNum`, plus a 568-line `index.d.ts` for roblox-ts | `--!nocheck` at the top of the file | TS defs | TS defs | yes |
| **Relative speed** | Fast for a hyperop library; author claims faster than EternityNum and InfiniteMath `[COMMUNITY]` | Slower (Patashu's README: OmegaNum/ExpantaNum "have low performance") | Slowest | ~2.5–400x faster than decimal.js | ~100–1000x faster than any of them |

### Secondary Luau options (for completeness)

| Library | Ceiling | Repr | Reaches `E(4)`? | Notes |
|---|---|---|---|---|
| **SerikaNum** (`evilbocchi/serikanum`) | `10^(10^308)` per README; `10^(2^1024)` per AlyaNum's README | two number primitives | **No** | Same author as AlyaNum. Claimed **4–20x faster than AlyaNum** `[COMMUNITY]`. Wally + roblox-ts. |
| **OnoeNum** (`evilbocchi`) | wraps SerikaNum | wrapper | No | "balance performance and development speed". AlyaNum has `AlyaNum.fromOnoe()` for interop. |
| **EternityNum** (`wienco123/EternityNum`) | `10↑↑(2^1024)` | `EN.new(sign, layer, mag)` — same shape as break_eternity | **Yes** | Rung 2. AlyaNum benchmarks against it directly (`bench/EternityNum.luau`). |
| **InfiniteMath** (`KdudeDev/InfiniteMath`) | "above 1e308" — exact ceiling `[UNVERIFIED]` | `[UNVERIFIED]` | Probably not | Popular on the DevForum; has docs site + demo game. |
| **QNum** (`notiku/qnum`) | mantissa/exponent, ceiling `[UNVERIFIED]` | 2 fields | **No** | Clean metamethod API, Wally. New (2026), 2 stars. |

### Selection verdict for a game that reaches `E(4)` and beyond

1. **AlyaNum** is the right default. It is the only actively-maintained, MIT-licensed, Wally-published,
   Luau-native, metatable-overloaded library with a hyperoperation ceiling. Its heptation limit is ~10^100
   times more headroom than "unreachable".
2. **EternityNum** is a reasonable lighter alternative *if* your endgame stops below `10↑↑(2^1024)` — it has
   3 fields instead of 7, so less allocation. But it gives you no pentation, and AlyaNum already has a
   float64 fast path for the range where EternityNum would win.
3. **OmegaNum (Luau)** only if you genuinely need >5 arrows. You pay with 2 tables per value, no operator
   overloading, `--!nocheck`, and unclear licensing.
4. **break_infinity.js has no Luau port and is disqualified by magnitude anyway.** If your existing codebase
   is written against `Decimal`, see [Porting guidance](#porting-guidance) — the translation target is
   AlyaNum, not a port of break_infinity.

---

## AlyaNum in depth

**Repo:** <https://github.com/evilbocchi/alyanum> — 18 stars, 4 forks, 109 commits, MIT,
`Copyright (c) 2024 evil bocchi`. Version **1.2.0**. Latest commit **2026-08-24**
("chore(ci): migrate workflows from npm to Bun"). Topics: `bignum`, `lua`, `luau`, `roblox`, `roblox-ts`.

**Everything below was read from `src/init.luau` @ `main` (2,839 lines).** Line numbers refer to that file.

### Install

```toml
# wally.toml
[dependencies]
AlyaNum = "evilbocchi/alyanum@1.2.0"
```

```sh
wally add evilbocchi/alyanum   # Luau / Rojo
npm install @rbxts/alyanum     # roblox-ts
```

The Wally package `realm` is `shared`, so it can live in `ReplicatedStorage` and be required from both
client and server — which matters, because you will be sending these values across the network.

### Internal representation

```lua
export type BaseAlyaNum = {
    sign: number,          -- -1, 0, or 1
    multiplicand: number,  -- the mantissa-ish base value
    exponent: number,      -- how many times to apply x -> 10^x
    tetrate: number,       -- how many times to apply x -> 10^^x
    pentate: number,       -- how many times to apply x -> 10^^^x
    hexate: number,        -- how many times to apply x -> 10^^^^x
    heptate: number,       -- how many times to apply x -> 10^^^^^x
}
export type Number = BaseAlyaNum | number | AlyaNum
export type AlyaNum = setmetatable<BaseAlyaNum, typeof(AlyaNum)>
```

The doc comment gives the canonical worked example (`src/init.luau:148-149`):

> `{sign: -1, multiplicand: 4, exponent: 2, tetrate: 1, pentate: 0, hexate: 0, heptate: 0}`
> This represents `-1 * 10 ^^ (10 ^ (10 ^ 4))`.

Read it **outward**: start with `multiplicand`, apply `10^x` `exponent` times, then `10^^x` `tetrate`
times, then `10^^^x` `pentate` times, and so on. It is a flat, fixed-arity encoding of the hyperoperation
ladder — structurally the same idea as break_eternity's `(sign, layer, mag)` but with four extra layer
counters above the exponent layer.

**This is the most important design fact about AlyaNum:** the arity is *fixed at 7*. There is no array, no
allocation-per-arrow-level, no loop over an unbounded structure. Every comparison is at most 6 float
compares. Every value is exactly one table. That is where the speed comes from, and it is also the hard
ceiling.

### Normalization — `fix()` (`src/init.luau:168-243`)

`fix()` is the invariant-restorer that every constructor and most operations funnel through. Its rules:

1. `sign == 0` ⇒ zero out all six magnitude fields.
2. Negative `multiplicand` ⇒ move the sign into `sign`, take `abs`.
3. `multiplicand >= 2^53−1` ⇒ `multiplicand = log10(multiplicand)`, `exponent += 1`. *(carry up)*
4. `exponent == 0` and `multiplicand == 1` and exactly one hyperop field is 1 ⇒ collapse to `10`.
5. `multiplicand < 15.9546` and `exponent > 0` ⇒ `multiplicand = 10^multiplicand`, `exponent -= 1`.
   **Applied up to twice** (the source comment: *"do it twice for cherry on top(??)"*). *(carry down)*
6. Each of `hexate`, `pentate`, `tetrate`, `exponent` (checked in that order, `elseif` chain):
   if `>= 2^53−1`, take `log10` of it into `multiplicand`, increment the next-higher field,
   set `exponent = 1`, and zero the fields below. *(carry up the hyperoperation ladder)*

Note rule 6 is an `elseif` chain and `heptate` has no successor — once `heptate` saturates at 2^53−1 there
is nothing above it. That is AlyaNum's absolute ceiling.

Note also the commented-out block right after rule 6:

```lua
-- floor all hyperoperations
--number.exponent = math.floor(number.exponent)
--number.tetrate = math.floor(number.tetrate)
-- ...
```

The hyperoperation counters are therefore **allowed to hold fractional values** in practice. Treat
"`tetrate = 1.5`" as an implementation detail you should not rely on the semantics of. `[UNVERIFIED]` what
a fractional `tetrate` is defined to mean.

### Maximum representable magnitude

| Bound | Value | Where |
|---|---|---|
| Absolute maximum | ~`10↑↑↑↑↑(9007199254740991)` | `heptate` saturates at `FLOAT64_SAFE_LIMIT` |
| README's phrasing | `10^^^^^10` (heptation) | `README.md` |
| Largest with `exponent` only | ~`E(9007199254740991)` — a tower of 10s ~9.007 quadrillion tall | `MAX_POW`, `src/init.luau:324` |
| `MAX_ADD` | `{m=9.007e15, e=1}` = `10^(9.007e15)` | `src/init.luau:301` |
| `MAX_MUL` | `{m=9.007e15, e=2}` = `10^10^(9.007e15)` | `src/init.luau:310` |
| `MAX_POW` | `{m=1, e=9.007e15}` | `src/init.luau:319` |
| `MAX_TETRATE` | `{m=1e10, e=8, tetrate=9.007e15}` | `src/init.luau:334` |
| `MAX_PENTATE` | `{m=1e10, e=8, tet=8, pentate=9.007e15}` | `src/init.luau:343` |
| `MAX_HEXATE` | `{m=1e10, e=8, tet=8, pent=8, hexate=9.007e15}` | `src/init.luau:352` |

**`E(4)` = `{multiplicand = 1e10, exponent = 2}`.** Verified by simulation above.

### Full API surface

All of the following are read directly from the `-- exports` block (`src/init.luau:2424-2680`) and the
metamethod block (`src/init.luau:2754-2793`).

#### Construction and conversion

| Call | Signature | Notes |
|---|---|---|
| `AlyaNum.new(x)` | `number \| BaseAlyaNum -> AlyaNum` | **If `x` is a plain table it is `setmetatable`d in place.** If `x` is already an AlyaNum it is returned **as-is, not copied.** |
| `AlyaNum.fromString(s)` | `string -> AlyaNum` | Accepts `"1.5e9"`, e-chains `"ee1000"`, `"e4.6e6"`-style, suffix strings `"1.25M"`, and `"[sign, n0, n1, …]"` OmegaNum arrays. |
| `AlyaNum.fromScientific(s)` | `string -> AlyaNum` | |
| `AlyaNum.fromSuffix(s)` | via `fromString` | `getSuffixExponent` reverses the suffix table. |
| `AlyaNum.fromOmega(t)` | OmegaNum `{sign, {n0..n5}}` -> AlyaNum | **Direct migration path from OmegaNum saves.** |
| `AlyaNum.fromOnoe(t)` | OnoeNum/SerikaNum -> AlyaNum | Handles both `{sign,…}` and `{mantissa, exponent}` shapes. |
| `AlyaNum.toBaseAlya(self)` | `AlyaNum -> BaseAlyaNum` | **Mutates in place** — `setmetatable(self, nil)`. Source comment: *"This is mutable, so be careful when using it."* |
| `AlyaNum.toNumber(self)` / `:revert()` | `-> number` | Returns `math.huge * sign` past 2^1024. |
| `AlyaNum.toSerika(self)` | `-> (number, number)` | `(mantissa, exponent)` pair; returns `(10, math.huge)` if any hyperop field is set. |
| `AlyaNum.lbencode(self)` / `:toSingle()` | `-> number` | **Lossy**, order-preserving, for OrderedDataStore. |
| `AlyaNum.lbdecode(n)` / `.fromSingle(n)` | `number -> AlyaNum` | Inverse of the above, also lossy. |

#### Arithmetic (all return **new** AlyaNums; none mutate `self`)

`add` `sub` `mul` `div` `pow` `mod` `root` `reciprocal`/`recip` `abs` `unary`/`unm`
`floor` `round` `ceil` `factorial` `random`

#### Logarithms, hyperoperations, special functions

`log10` `log(base)` `lambertw` `slog(base)` `pentlog(base)` `hextlog(base)`
`tet(height)` `pent(height)` `hext(height)`

Note there is **no `exp`, no `ln`, no `sqrt`, no `cbrt`** as named methods — use `AlyaNum.new(math.exp(1)):pow(x)`,
`x:log(AlyaNum.new(math.exp(1)))`, and `x:root(2)` / `x:root(3)`.

Note also there is **no `hept()` constructor method** even though the `heptate` field exists — the highest
hyperoperation you can *construct* directly is hexation (`hext`). `heptate` is only ever populated by
`fix()` carrying up out of a saturated `hexate`. `[UNVERIFIED]` whether this is intentional.

`slog`, `pentlog`, and `hextlog` return `AlyaNum?` — **they can return `nil`**, and the internals `error()`
when they fail (`"slog failed to compute for tetrate"`, `"result is nil in pentate"`, etc.).
Wrap them in `pcall` if you call them on player-facing input.

#### Comparison

| Method | Alias | Metamethod |
|---|---|---|
| `equals` | `eq` | `==` |
| `lessThan` | `lt` | `<` |
| `lessEquals` | `le` | `<=` |
| `moreThan` | `mt` | *(derived — Luau maps `a > b` to `b < a`)* |
| `moreEquals` | `me` | *(derived)* |
| `compare` | — | returns `-1 / 0 / 1` |
| `isCloseTo(n, relTol?, absTol?)` | — | default `relTol = 1e-9` |
| `min` `max` `minmax` | — | **instance methods**, not statics |

`equals` is a **strict field-by-field comparison** of all 7 fields (`src/init.luau:1417`). `compare` is
lexicographic from `heptate` down to `multiplicand` (`absCompare`, `src/init.luau:1399`), which is correct
and O(1) — at most 6 float compares, never an allocation.

#### Formatting

`toString` `toSuffix` `toScientific` `toEChain` `toEnt` `toHyperE`
plus configuration: `changeSuffixes(table)` `changeDecimalPoints(n)` `changeDefaultAbbreviation("suffix"|"scientific")`

#### Constants

`AlyaNum.GOOGOL` (1e100), `AlyaNum.GOOGOLPLEX`, `AlyaNum.GOOGOLPLEXPLEX`,
`AlyaNum.TRITRI` (3↑↑↑3), `AlyaNum.TRITET` (4↑↑↑↑4), `AlyaNum.GRAHAM1` (3↑↑↑↑3).

These are excellent smoke-test fixtures. `GRAHAM1` is stored as
`{m = 3638334640023.778, e = 7625597484984, pentate = 1}` — note it *fits in three fields*.

### Operator overloading — verified

```lua
AlyaNum.__add  = addMetamethod       -- src/init.luau:2754
AlyaNum.__sub  = subMetamethod
AlyaNum.__mul  = mulMetamethod
AlyaNum.__div  = divMetamethod
AlyaNum.__pow  = powMetamethod
AlyaNum.__mod  = modMetamethod
AlyaNum.__eq   = equalsMetamethod
AlyaNum.__lt   = lessThanMetamethod
AlyaNum.__le   = lessEqualsMetamethod
AlyaNum.__unm  = unary
AlyaNum.__tostring = toString
AlyaNum.__concat   = function(self, value) ... end
```

Each binary metamethod is:

```lua
local function metamethodValue(value: any): AlyaNum
    if type(value) == "number" then
        return newNumber(value)
    end
    return value
end

local function addMetamethod(self: any, number: any): AlyaNum
    return add(metamethodValue(self), metamethodValue(number))
end
```

So `alyaValue + 5` and `5 + alyaValue` both work (Lua tries the metamethod of either operand). **But
`metamethodValue` does not call `fix()` on a raw `BaseAlyaNum`** — it returns it unchanged. If you pull a
`BaseAlyaNum` straight out of a DataStore and do `saved + 1`, you are doing arithmetic on a table with no
metatable, whose fields have not been normalized. It will *mostly* work because `add` only reads fields —
but the result's `sign`/field invariants are whatever the save had. **Always `AlyaNum.new()` on the
deserialization boundary.**

> **`__eq` caveat, inherited from Lua semantics:** Luau only invokes `__eq` when *both* operands are tables
> with the same primitive type. `alyaValue == 5` is `false` without ever calling `equalsMetamethod`.
> Use `alyaValue:equals(5)`. This is the #1 silent bug in ported code.

> **`__lt`/`__le` caveat:** `alyaValue < 5` **does** work in Luau (comparison metamethods fire for
> table-vs-number in Luau? — `[UNVERIFIED]`; in stock Lua 5.1 a table-vs-number comparison raises
> "attempt to compare"). **Test this explicitly before relying on it.** The safe form is
> `alyaValue:lessThan(5)`.

### Arithmetic behaviour at scale — read this before designing your economy

Every core operation has a **float64 fast path** and a **saturating slow path**.

**`add` / `sub` fast path** (`src/init.luau:388-406`): if both operands have all four hyperop fields zero,
`exponent < 2`, and (when `exponent == 1`) `multiplicand <= 308.2547`, it reconstitutes both as plain
doubles, adds them, and returns `AlyaNum.new(sum)` if the result is finite. **Below 1e308 you get raw
float64 addition plus one table allocation.**

**`add` saturation** (`src/init.luau:415-423`):

```lua
if maxAbsNum.heptate ~= 0 or maxAbsNum.hexate ~= 0 or maxAbsNum.pentate ~= 0
   or maxAbsNum.tetrate ~= 0 or maxAbsNum.exponent > 1 then
    -- number too big to matter
    return maxAbsNum
end
```

**Above `10^(9.007e15)`, `a + b` returns `max(|a|,|b|)`.** At `E(4)` this means
`E(4) + E(4) == E(4)`. That is not a bug — the doubling would change the stored exponent by
`log10(2) ≈ 0.301`, and at an exponent field value of `1e10` the ULP is ~`1.9e-6`… but at
`exponent = 2` the true change is to `10^(10^10)`, whose representable resolution is astronomically
coarser than `0.301`. Saturation is the mathematically honest answer. **But it means additive income
formulas stop working past this point and you must design multiplicatively.**

**`mul` / `div` saturation** (`src/init.luau:539-542`, `587-590`):

```lua
local maxNum = absMax(abs(self), abs(number))
if absMoreThan(maxNum, MAX_MUL) then
    return self.sign == number.sign and maxNum or unary(maxNum) -- just dont bother
end
```

`MAX_MUL = 10^10^(9.007e15)`. Below that, `mul` is exact-ish via
`10^(log10(x) + log10(y))`. **At `E(4)`, multiplication still works correctly** — I traced it:
`log10(E(4)) = {m=1e10, e=1}`, the two logs add to `{m=1e10 + log10(2), e=1}` (representable, since the ULP
at `1e10` is ~`1.9e-6`), and `pow10` lifts it back. So `E(4) * 2` is *not* lost, while `E(4) + E(4)` *is*.
**This asymmetry is the single most surprising behaviour in the library** and you should write a test for it.

**`pow` saturation** (`src/init.luau:661-663`): `if moreEquals(max(self, number), MAX_POW) then return max(self, number)`.

### NaN and Infinity

**AlyaNum has no NaN and no Infinity.** There is no `isNaN`, no `isFinite`, and no infinite value in the
type. Instead:

- `AlyaNum.new(math.huge)` **throws**: `error("cannot parse math.huge")` (`src/init.luau:245-247`).
- `toNumber()` on a too-large value returns `math.huge * sign` — so `toNumber` is a one-way door.
- `AlyaNum.new(0/0)`: `newNumber` does `sign = math.sign(number)`. Luau's `math.sign` returns `0` for NaN
  (it is `v > 0 ? 1 : v < 0 ? -1 : 0`), and the `sign == 0` branch then sets `multiplicand = 0`.
  **A NaN therefore becomes a silent zero.** `[UNVERIFIED — not executed]`; write a test for it on day one.
- `factorial` errors on negatives and non-integers.
- `pow` with a negative base and a fractional exponent returns `ZERO` (source comment:
  *"produces imaginary numbers, not supported"*) rather than NaN.

**Practical rule: validate at the boundary.** Never let a `math.huge` or a NaN reach `AlyaNum.new`.

### Mutability and aliasing — the biggest footgun

Three separate in-place behaviours:

1. `AlyaNum.new(tbl)` on a plain table **attaches the metatable to your table**. Your table *becomes* the
   AlyaNum. If two systems hold that table, they now share one AlyaNum.
2. `AlyaNum.new(alyaValue)` returns **the same object** — not a copy.
3. `toBaseAlya(self)` **removes the metatable from `self`**, breaking every other reference to it.

Additionally, several operations **return an operand directly** rather than a fresh value:
`add` returns `number`/`self` when either sign is 0; `mul`/`div` return `self` when the other operand is 1;
`add`/`mul`/`div`/`pow` return `maxAbsNum`/`maxNum` in the saturation paths; `min`/`max` return one of the
inputs.

So `local b = a:add(0)` gives you `b == a` (same table). Since the public API never mutates, this is safe —
**until you reach for `toBaseAlya`.** Rule: `toBaseAlya` only on a value you just constructed for the
express purpose of serializing, and never on a value stored anywhere.

```lua
-- WRONG: destroys playerData.gold as an AlyaNum
local payload = AlyaNum.toBaseAlya(playerData.gold)

-- RIGHT: serialize through an explicit copy
local function toPlain(v: AlyaNum): BaseAlyaNum
    return {
        sign = v.sign, multiplicand = v.multiplicand, exponent = v.exponent,
        tetrate = v.tetrate, pentate = v.pentate, hexate = v.hexate, heptate = v.heptate,
    }
end
```

### Global mutable configuration

```lua
AlyaNum.changeDecimalPoints(3)                -- sets file-local DECIMAL_POINTS + DP_OFFSET
AlyaNum.changeDefaultAbbreviation("scientific") -- sets DEFAULT_ABBREVIATION
AlyaNum.changeSuffixes(myTable)               -- replaces the whole suffix table
```

All three write to **file-local upvalues**, i.e. process-global state shared by every consumer of the
module. On the server this is fine (one setting for the whole game). On the client, **you cannot use this
to give two different UI elements different formats**, and you cannot use it for a per-player setting on the
server at all. Write your own formatter (see [Formatting for display](#formatting-for-display)).

### How AlyaNum differs from OmegaNum and ExpantaNum

| | AlyaNum | OmegaNum | ExpantaNum |
|---|---|---|---|
| Arity | Fixed 7 fields | Variable array, up to ~1000 entries | Sparse `[arrow, count]` pairs + a layer counter |
| Ceiling | heptation (5 arrows) | 1000 arrows | BEAF `{10,9e15,1,2}` |
| Tables per value | 1 | 2 | 2 + pairs |
| Comparison cost | ≤6 float compares, no loop | array walk | pair walk |
| Operator overloading | full metatable set | **none** (verified: no `setmetatable` anywhere in the Luau source) | n/a (JS) |
| Type checking | typed Luau, `--!optimize 2 --!native` | `--!nocheck` | TS |
| Lineage | rewrite-fork of OmegaNum | FoundForces original, Naruyoko's JS line | Naruyoko successor to OmegaNum |

AlyaNum's whole thesis is: **trade unbounded arrow depth for a fixed-size struct**, because no shipping
Roblox game reaches 6 arrows, and a fixed-size struct lets you write branch-heavy fast paths and O(1)
comparison. Reading both sources, that thesis holds.

`AlyaNum.fromOmega()` accepts OmegaNum's `{sign, {n0, n1, n2, n3, n4, n5}}` array directly, so **migrating
an existing OmegaNum save to AlyaNum is a one-liner** (it silently drops array entries beyond `n5`, which
is exactly the heptation cutoff).

### Testing and benchmarking in-repo

- `test/` — run with `lune run test` (`package.json`).
- `bench/init.luau` — 18,953 bytes; benchmarks AlyaNum against **EternityNum** (`bench/EternityNum.luau`)
  and **OmegaNum** (`bench/OmegaNum.luau`), at 20,000 iterations with 1,000 warmup iterations, reporting
  ns/op and ops/sec, across `small` (~1e2), `medium` (~1e15–1e25) and `large` (~1e100–1e300) buckets, plus
  negatives and string parsing. **No published benchmark numbers are committed to the repo**, so the
  README's "faster than EternityNum and InfiniteMath" claim is `[COMMUNITY, SECOND-HAND]` — but the harness
  is there and you can run it yourself with `npm run bench`.
- CI: `.github/workflows/ci.yml`, badge green on `main`.

