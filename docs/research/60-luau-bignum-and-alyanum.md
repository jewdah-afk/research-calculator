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

