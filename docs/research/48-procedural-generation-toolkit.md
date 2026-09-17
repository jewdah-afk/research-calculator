# 48 — Procedural Generation Toolkit

**Scope.** The complete algorithmic toolkit for generating game content at runtime,
written for Luau on Roblox. Not just terrain: dungeons, cities, trees, loot, names,
quests, puzzles, waves. Every technique here is given with its algorithm, its
parameters and what they control, its failure modes, and the genres it serves.

**Relationship to other chapters.** Chapter 03 covers noise as a *texture* problem
(tiling, PBR map synthesis) and chapter 09 covers world generation as a
*simulation* problem (tectonics, climate). This chapter covers generation as a
*game-content* problem and is the one that carries the Luau implementations.
Chapter 21 (`EditableMesh`) and chapter 20 (`EditableImage`) are the output sinks
for most of what is described here; chapter 22 (Luau performance) is the budget
authority for anything in section 11.

**Verification status.** Everything about `math.noise`, `math.random` and `Random`
in section 1–2 was read out of the Luau VM source and the Roblox docs source, not
inferred — those are the strongest claims in the chapter. Items marked
**[unverified]** could not be checked against a primary source because the network
egress policy for this session blocked most of the open web (only GitHub, GitLab
and Bitbucket were reachable directly); they come from search summaries and are
flagged individually.

---

## TL;DR for builders

- **`math.noise` is not seeded.** It is Ken Perlin's improved 3-D gradient noise with
  a *fixed, hard-coded 256-entry permutation table*. The third argument is `z`, not a
  seed. It repeats **exactly every 256 units on every axis**, returns **0 at every
  integer lattice point**, and its true range is about **[-0.61, +0.75]**, not
  [-0.5, 0.5]. You "seed" it by sampling a different `z` slice — which gives you
  about 256 usefully-decorrelated worlds and no more.
- **`Random.new(seed)` is the only sanctioned deterministic stream** in the engine,
  and `Random:Shuffle` is contractually a Fisher–Yates with a fixed number of
  `NextInteger` calls, so it is stable across engine versions. `math.random` is a
  *global* PCG32-XSH-RR stream shared with every other script in the VM — never
  generate world content from it.
- **Write your own PRNG anyway.** A 20-line mulberry32 in Luau costs you nothing,
  is provably identical on client and server, survives engine updates, and can be
  snapshotted/restored (`Random` cannot be serialised). Verified test vectors below.
- **Hierarchical seeding is the single highest-leverage pattern in this chapter.**
  Derive every chunk's, room's and object's seed from a pure integer hash of
  `(worldSeed, x, y, purpose)` — never from a walked global stream. Then chunks
  generate in any order, in parallel, on either machine, and agree.
- **Rooms-plus-corridors is a solved problem:** scatter rooms, separate them with
  steering, Delaunay-triangulate the centres, take the minimum spanning tree for
  guaranteed connectivity, then add back ~12.5% of the discarded edges for loops.
  Everything else (BSP, drunkard's walk) is a variation on this or worse.
- **Cellular-automata caves want `fill = 0.45`, birth 5, survive 4, and 4–5
  iterations.** Fewer looks craggy, more stops changing. Always flood-fill
  afterwards and either discard or tunnel-connect the orphan regions — the
  algorithm does not guarantee connectivity and that is its defining failure mode.
- **Maze algorithms are chosen by texture, not by speed.** Recursive backtracker =
  long winding corridors, few dead ends. Prim's = short stubs, many dead ends,
  hostile. Kruskal's = neutral. Wilson's = unbiased uniform spanning tree.
  Eller's = O(row) memory and generates infinitely, so it is the one for streamed
  worlds.
- **WFC is a constraint solver, not a level designer.** It makes *locally* plausible
  texture and guarantees nothing globally — no reachability, no key-before-lock, no
  pacing. Use it for surfaces and set dressing; use a graph grammar for the parts
  players have to solve.
- **Lock-and-key layouts come from graph grammars, not from geometry.** Generate a
  *mission graph* (a solvable dependency DAG of keys, locks, and goals) first, then
  embed it into *space*. This is the single thing that separates a designed-feeling
  procedural level from noise.
- **Bridson's Poisson-disk sampling** (background grid at `r/√n`, `k = 30` candidate
  darts, active list) is O(N) and is the right default for scattering trees, rocks,
  spawn points and loot. Jittered grids are the cheap chunk-safe substitute.
- **Droplet erosion is worth its cost** — 8 lines of update equations turn fBm mush
  into terrain with ridges and valleys. Real parameter values are in §6.3.
- **Budget-based generation is the control mechanism for everything non-spatial:**
  loot affixes, enemy waves and quest steps all reduce to "spend N points across a
  weighted pool with exclusion rules". Learn it once, reuse it five times.
- **Generate, then *test*.** Rejection sampling with explicit quality metrics
  (connectivity, path length, solvability, difficulty estimate) is cheaper than
  trying to make a generator that can only produce good output. Spelunky's generator
  is a masterclass precisely because it constrains the space first and then fills it.
- **Never let a float decide topology.** Luau doubles are IEEE-754 and correctly
  rounded for `+ - * / sqrt`, but `sin`, `cos`, `pow`, `exp` come from the platform
  libm and may differ in the last ULP between an Android client and a Linux server.
  Branch on integer hashes; use floats only for values nobody compares.

---

## 0. Conventions used in this chapter

All code is Luau. `--!strict` is assumed off in the snippets for brevity but every
one of them type-checks with explicit annotations added. Where a snippet needs a
random source it takes an `rng` object with this interface:

```lua
export type Rng = {
    NextNumber: (self: Rng) -> number,               -- [0, 1)
    NextRange: (self: Rng, a: number, b: number) -> number,
    NextInteger: (self: Rng, a: number, b: number) -> number,  -- inclusive
    Fork: (self: Rng, tag: number) -> Rng,           -- child stream, see §1.4
}
```

`Random.new(seed)` satisfies the first three (its `NextNumber()` is `[0, 1]`
*inclusive*, which matters in exactly one place — see §1.1). The mulberry32 in §1.3
satisfies all four.

---

## 1. Randomness foundations

### 1.1 What the engine actually gives you

Two facts, read from the Luau VM source rather than from documentation:

**`math.random` is a single global PCG32-XSH-RR stream.** From
`VM/src/lmathlib.cpp`:

```cpp
#define PCG32_INC 105

static uint32_t pcg32_random(uint64_t* state)
{
    uint64_t oldstate = *state;
    *state = oldstate * 6364136223846793005ULL + (PCG32_INC | 1);
    uint32_t xorshifted = uint32_t(((oldstate >> 18u) ^ oldstate) >> 27u);
    uint32_t rot = uint32_t(oldstate >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-int32_t(rot)) & 31));
}
```

The state lives on `L->global->rngstate` — i.e. **one stream per Luau VM, shared by
every script in it**. `math.randomseed(n)` reseeds that shared state globally.
Any other script that calls `math.random` between two of your calls changes your
sequence. This makes `math.random` unusable for reproducible generation. It is fine
for cosmetic jitter.

`math.random()` with no arguments draws *two* 32-bit words and assembles a double
via `ldexp(lo | (hi << 32), -64)`, so it is a full-precision `[0, 1)` draw.
`math.random(u)` and `math.random(l, u)` use the multiply-high trick
(`(range * r32) >> 32`), which is *slightly* biased for ranges that do not divide
2³² — negligible for gameplay, not acceptable for cryptography or for
statistics-sensitive loot audits.

**`Random.new(seed)` is a separate, per-object stream.** The engine does not
document which algorithm it uses; it is not in the open-source Luau VM because
`Random` is a Roblox datatype, not a Luau library. What *is* documented and
contractual:

| Guarantee | Source |
|---|---|
| Seed range `[-9007199254740991, 9007199254740991]`, truncated toward zero; out-of-range clamps to 0 | `Random.new` docs |
| Seeds 0, 0.99 produce identical generators | `Random.new` docs |
| `NextNumber()` returns `[0, 1]` **inclusive of both endpoints** | `Random:NextNumber` docs |
| `NextInteger(min, max)` inclusive; swaps args if `min > max`; truncates toward zero | `Random:NextInteger` docs |
| `Shuffle(t)` "is defined to be a Fisher-Yates shuffle so the number of `NextInteger` calls is guaranteed to be consistent between engine versions for a given size of table" | `Random:Shuffle` docs |
| `NextUnitVector()` uniform on the sphere | `Random:NextUnitVector` docs |
| `Clone()` copies state; the two streams then advance independently | `Random:Clone` docs |

The `Shuffle` guarantee is unusually strong and worth exploiting: it means you can
shuffle a table in the middle of a seeded sequence and the *downstream* draws stay
stable across engine updates. Very few Roblox APIs promise that.

The `[0, 1]` **inclusive** range of `NextNumber()` is a real trap. `rng:NextNumber()`
can return exactly `1.0`. Code like `array[math.floor(rng:NextNumber() * #array) + 1]`
will index out of bounds roughly once in 2⁵³ draws — which, at a few thousand draws
per chunk across a live game, happens. Use `NextInteger(1, #array)` or clamp.

**What `Random` does not give you:** you cannot serialise its state. `Clone()`
duplicates it in memory but there is no `GetState`/`SetState`. If you need to
persist a generator across a server restart, or to send a generator's *position* in
its stream over the wire, you must implement your own.

### 1.2 Why seeded determinism is the load-bearing requirement

Three separate wins, and they compound:

1. **Bandwidth.** A 4096×4096-stud world that is a pure function of a 32-bit seed
   costs 4 bytes of replication instead of megabytes. See §11.1.
2. **Reproducibility.** A player reports "the bridge in chunk (12, -7) is broken".
   With hierarchical seeding you regenerate exactly that chunk in Studio from the
   world seed and the coordinates, in isolation. Without it you cannot.
3. **Parallelism.** A generator whose output depends on evaluation *order* cannot be
   split across Actors (§11.4). One whose output depends only on `(seed, coords)`
   parallelises for free.

### 1.3 A portable PRNG you own: mulberry32 in Luau

mulberry32 is a 32-bit state, 32-bit output generator. It passes gjrand's full suite
at 32 bits of state and is about as small as a usable PRNG gets. It is the right
default for game content: fast, trivially portable, and its state is one integer you
can store in a DataStore.

Luau has no 32×32→32 multiply primitive (`bit32` has no `imul`), and a naive
`a * b` overflows the 53-bit double mantissa. Split the multiply:

```lua
-- Exact 32-bit unsigned multiply. All intermediates stay under 2^49,
-- well inside the 53-bit exact-integer range of a double.
local function imul32(a: number, b: number): number
    a = a % 4294967296
    b = b % 4294967296
    local al = a % 65536
    local ah = (a - al) / 65536
    return ((ah * b % 65536) * 65536 + al * b) % 4294967296
end
```

A `bit32` version is marginally faster under native codegen but behaves identically:

```lua
local function imul32(a: number, b: number): number
    local ah = bit32.rshift(a, 16)
    local al = bit32.band(a, 0xFFFF)
    return bit32.band(bit32.lshift(ah * b, 16) + al * b, 0xFFFFFFFF)
end
```

> **`bit32` semantics you must know.** Luau converts every `bit32` argument with
> `(unsigned)(long long)(n)` (`VM/src/lnumutils.h`), i.e. **truncate toward zero to
> a 64-bit integer, then take it modulo 2³²**. So `bit32.band(-1, 0xFFFFFFFF)` is
> `0xFFFFFFFF`, `bit32.band(-1.7, ...)` truncates to `-1` first, and every `bit32`
> function returns a value in `[0, 2³²)`. Arguments outside ±2⁶³ are undefined.
> This makes `bit32` safe for negative chunk coordinates, which matters in §1.4.

The generator itself:

```lua
local Mulberry32 = {}
Mulberry32.__index = Mulberry32

function Mulberry32.new(seed: number)
    return setmetatable({ s = seed % 4294967296 }, Mulberry32)
end

function Mulberry32:NextUInt32(): number
    self.s = (self.s + 0x6D2B79F5) % 4294967296
    local t = self.s
    t = imul32(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
    t = bit32.bxor((t + imul32(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % 4294967296, t)
    return bit32.bxor(t, bit32.rshift(t, 14))
end

function Mulberry32:NextNumber(): number            -- [0, 1)
    return self:NextUInt32() / 4294967296
end

function Mulberry32:NextRange(a: number, b: number): number
    return a + (b - a) * self:NextNumber()
end

function Mulberry32:NextInteger(a: number, b: number): number  -- inclusive
    -- multiply-high; bias is 2^-32 relative, irrelevant for gameplay
    return a + math.floor(self:NextNumber() * (b - a + 1))
end

function Mulberry32:Save(): number  return self.s end
function Mulberry32:Load(s: number) self.s = s % 4294967296 end
```

**Verified test vectors.** These were produced by an exact-integer reference
implementation of the above and match the canonical JavaScript mulberry32:

```
Mulberry32.new(42):NextNumber() x5 ->
  0.6011037519, 0.4482905590, 0.8524657935, 0.6697340414, 0.1748138987
Mulberry32.new(0):NextNumber() x5 ->
  0.2664292087, 0.0003297457, 0.2232720274, 0.1462021479, 0.4673278229
```

If your Luau port does not reproduce those to 10 decimal places, your `imul32` is
wrong. (A decile histogram over 200 000 draws from seed 12345 came out
`20155 20081 20041 19811 19738 20255 19894 19931 19903 20191`, which is what you want
to see.)

**Caveats.** 32 bits of state means a period of 2³² and a birthday collision between
two independently chosen seeds after ~65 000 seeds. That is fine for per-chunk
streams (which are hashed, not chosen) and fine for a world seed a human typed. If
you are running a million concurrent per-player streams, use PCG32 (64-bit state,
32-bit output) instead — same structure, two 32-bit halves for the state, and the
LCG constants are in the `lmathlib.cpp` excerpt above.

### 1.4 Hierarchical seeding — the pattern

The mistake almost every project makes: one `Random` object walked in generation
order. Generate chunk A then chunk B and you get a different B than if you had
generated B first. That breaks streaming, breaks parallelism, and breaks client
prediction.

The fix: every generation unit derives its seed from a **pure integer hash** of the
world seed and its own identity. Use SquirrelNoise (Squirrel Eiserloh, GDC 2017
"Math for Game Programmers: Noise-Based RNG"), verified here against Gaijin's
`dag_uint_noise.h`, which copies it faithfully:

```lua
local BIT_NOISE1 = 0x68E31DA4
local BIT_NOISE2 = 0xB5297A4D
local BIT_NOISE3 = 0x1B56C4E9

-- 1-D integer hash -> uint32. Deterministic, stateless, ~4ns.
local function squirrel3(position: number, seed: number): number
    local m = imul32(position % 4294967296, BIT_NOISE1)
    m = (m + seed) % 4294967296
    m = bit32.bxor(m, bit32.rshift(m, 8))
    m = (m + BIT_NOISE2) % 4294967296
    m = bit32.bxor(m, bit32.lshift(m, 8))
    m = imul32(m, BIT_NOISE3)
    return bit32.bxor(m, bit32.rshift(m, 8))
end

local PRIME1, PRIME2 = 198491317, 6542989   -- from the original talk

local function hash2(x: number, y: number, seed: number): number
    return squirrel3(bit32.band(x + PRIME1 * y, 0xFFFFFFFF), seed)
end

local function hash3(x: number, y: number, z: number, seed: number): number
    return squirrel3(bit32.band(x + PRIME1 * y + PRIME2 * z, 0xFFFFFFFF), seed)
end
```

Verified outputs: `squirrel3(0, 0) = 2957163356`, `squirrel3(1, 0) = 2179289154`,
`hash2(12, -7, 1337) = 2327790681`.

> Watch the magnitude: `PRIME1 * y` for `|y| > 4.5e7` leaves the exact-double range
> once summed. Chunk coordinates never get near that; *world* coordinates in studs
> can. Hash chunk indices, not stud positions.

Now the pattern itself. Give every generation domain a **purpose tag** so that two
different systems asking about the same chunk get independent streams:

```lua
local PURPOSE = {
    TERRAIN   = 0x1000,
    TREES     = 0x2000,
    ROCKS     = 0x2001,
    STRUCTURES= 0x3000,
    LOOT      = 0x4000,
    NAMES     = 0x5000,
}

local function chunkRng(worldSeed: number, cx: number, cy: number, purpose: number)
    return Mulberry32.new(hash3(cx, cy, purpose, worldSeed))
end

-- Sub-derivation: a room inside a chunk, an item inside a chest.
function Mulberry32:Fork(tag: number)
    return Mulberry32.new(squirrel3(tag, self:NextUInt32()))
end
```

Three properties this buys you, all of which you should actually test for:

1. **Order independence.** `assert(generate(5,3) == generate(5,3))` regardless of
   what ran in between.
2. **Locality.** Regenerating chunk (5,3) touches nothing else. Required for
   streaming (§11.5) and for repairing a corrupted chunk.
3. **Extensibility.** Adding a new subsystem means adding a new `PURPOSE` constant.
   Existing worlds do not change. This is the difference between "we can ship an
   update" and "every player's world regenerates".

**Failure modes.**

- *Using `cx * 73856093 ~ cy * 19349663` (the Teschner spatial hash) and calling it
  done.* That hash is designed for bucket distribution, not for avalanche. Adjacent
  chunks produce correlated seeds, and you will see visible diagonal banding in
  per-chunk features. Squirrel3 avalanches properly; verify by rendering
  `hash2(x, y, seed) / 2^32` as a greyscale image and looking for structure.
- *Forgetting the purpose tag.* Trees and rocks then use the same stream, and moving
  a tree moves a rock.
- *Deriving the sub-seed from a float.* `Mulberry32.new(position.X * 1000)` is not
  reproducible across platforms (§11.2). Quantise to an integer first.

### 1.5 Weighted random selection

**Linear scan — O(n) per draw, O(1) setup.** Correct for n ≤ ~20 or when weights
change every draw.

```lua
local function weightedPick(items: {any}, weights: {number}, rng): any
    local total = 0
    for i = 1, #weights do total += weights[i] end
    local r = rng:NextNumber() * total
    for i = 1, #items do
        r -= weights[i]
        if r <= 0 then return items[i] end
    end
    return items[#items]      -- float slop guard; do not remove
end
```

That last line is not defensive paranoia — accumulated rounding in the subtraction
loop genuinely lets `r` stay positive past the end. Ship the guard.

**Prefix sums + binary search — O(log n) per draw, O(n) setup.** Right when the
table is static and you draw from it thousands of times (loot tables, tile
palettes):

```lua
local function buildCdf(weights: {number}): {number}
    local cdf, acc = table.create(#weights), 0
    for i = 1, #weights do acc += weights[i]; cdf[i] = acc end
    return cdf
end

local function pickCdf(cdf: {number}, rng): number
    local r = rng:NextNumber() * cdf[#cdf]
    local lo, hi = 1, #cdf
    while lo < hi do
        local mid = (lo + hi) // 2
        if cdf[mid] < r then lo = mid + 1 else hi = mid end
    end
    return lo
end
```

**The alias method (Vose's construction) — O(1) per draw, O(n) setup.** This is the
one to use for the hot inner loop of a generator: per-tile material selection, per
-particle type, per-scatter prop. Walker published it in 1974; Vose's 1991
construction is the numerically stable one; Keith Schwarz's "Darts, Dice, and Coins"
is the canonical exposition.

The idea: normalise the weights so they average 1, then pack n "columns" each of
total height 1, where each column contains at most two outcomes — a primary and an
"alias". A draw is then one uniform integer (which column) plus one uniform float
(which of the two).

```lua
local Alias = {}
Alias.__index = Alias

function Alias.new(weights: {number})
    local n = #weights
    local total = 0
    for i = 1, n do total += weights[i] end

    local prob  = table.create(n, 0)   -- probability of taking the PRIMARY
    local alias = table.create(n, 0)   -- fallback index
    local scaled = table.create(n, 0)
    local small, large = {}, {}

    for i = 1, n do
        scaled[i] = weights[i] * n / total
        if scaled[i] < 1 then table.insert(small, i) else table.insert(large, i) end
    end

    while #small > 0 and #large > 0 do
        local s = table.remove(small)
        local l = table.remove(large)
        prob[s]  = scaled[s]
        alias[s] = l
        scaled[l] = (scaled[l] + scaled[s]) - 1      -- written this way for stability
        if scaled[l] < 1 then table.insert(small, l) else table.insert(large, l) end
    end
    -- Whatever is left is 1.0 up to float error.
    while #large > 0 do local l = table.remove(large); prob[l] = 1; alias[l] = l end
    while #small > 0 do local s = table.remove(small); prob[s] = 1; alias[s] = s end

    return setmetatable({ n = n, prob = prob, alias = alias }, Alias)
end

function Alias:Sample(rng): number
    local i = rng:NextInteger(1, self.n)
    return (rng:NextNumber() < self.prob[i]) and i or self.alias[i]
end
```

Two details that matter. `scaled[l] = (scaled[l] + scaled[s]) - 1` rather than
`scaled[l] - (1 - scaled[s])` is Vose's stability fix; with the other ordering you
can drive a value slightly negative and corrupt the table. And the two trailing
`while` loops are required — with exact arithmetic only one list can be non-empty,
but with floats both can be, and dropping either produces `prob[i] = 0` entries that
silently reroute mass to whatever `alias[i]` happened to be.

**Cost comparison, for a table of 64 entries.** Setup: linear 0, CDF 64 adds, alias
~192 ops. Per draw: linear ~32 compares, CDF ~6 compares, alias 1 compare. At
100 000 draws per world generation the alias table pays for itself about 600×.

### 1.6 Shuffle bags and "random without streaks"

True independent draws feel unfair. Over 10 rolls at p = 0.2, the chance of *zero*
successes is 10.7% and the chance of three in a row somewhere is substantial. Players
read both as bugs.

**Fisher–Yates** (use `Random:Shuffle` when you have a `Random`; this is the portable
version):

```lua
local function shuffle(t: {any}, rng)
    for i = #t, 2, -1 do
        local j = rng:NextInteger(1, i)
        t[i], t[j] = t[j], t[i]
    end
end
```

Downward iteration with `j ∈ [1, i]` is the correct form. The common bug —
`j = rng:NextInteger(1, #t)` inside the loop — produces a distribution that is
provably non-uniform (n^n outcomes mapped onto n! permutations).

**Shuffle bag.** Put k copies of each outcome in a bag, shuffle, deal. Refill and
reshuffle when empty. Guarantees exactly the advertised rate over each bag and caps
the drought at `2 * bagSize - 1`.

```lua
local Bag = {}
Bag.__index = Bag

function Bag.new(counts: {[any]: number}, rng)
    local self = setmetatable({ proto = {}, items = {}, rng = rng }, Bag)
    for item, n in counts do
        for _ = 1, n do table.insert(self.proto, item) end
    end
    self:Refill()
    return self
end

function Bag:Refill()
    self.items = table.clone(self.proto)
    shuffle(self.items, self.rng)
end

function Bag:Draw()
    if #self.items == 0 then self:Refill() end
    return table.remove(self.items)
end
```

Use for: loot drops from a fixed table, Tetris-style piece sequences (the modern
7-bag), enemy type selection within a wave, dialogue barks (so the guard does not say
the same line twice in a row).

**Anti-repeat variant.** If you only need "never the same twice in a row", a bag is
overkill — reroll on a match, or deal from the bag but swap the first element if it
matches the previous bag's last:

```lua
function Bag:RefillNoRepeat(lastItem)
    self:Refill()
    if #self.items > 1 and self.items[#self.items] == lastItem then
        local j = self.rng:NextInteger(1, #self.items - 1)
        self.items[#self.items], self.items[j] = self.items[j], self.items[#self.items]
    end
end
```

### 1.7 Pity timers

Two production designs, both worth knowing.

**Warcraft III "pseudo-random distribution" (PRD).** Used for critical strikes and
proc chances. Instead of a constant probability `p`, use a probability that grows
linearly with the number of consecutive failures: on the n-th attempt since the last
success, `P(n) = C * n`. The constant `C` is chosen so the *long-run* rate equals the
advertised `p`. This makes streaks essentially impossible in both directions: the
maximum possible drought is `ceil(1/C)`.

`C` has no closed form; solve it once per `p` by bisection on the expected-value
equation, or use the standard table. Representative values (**[unverified]** — these
are the widely-circulated community-derived constants; regenerate them yourself with
the solver below if you depend on exact rates):

| advertised p | C |
|---|---|
| 0.05 | 0.00380 |
| 0.10 | 0.01475 |
| 0.15 | 0.03222 |
| 0.20 | 0.05570 |
| 0.25 | 0.08474 |
| 0.30 | 0.11912 |
| 0.40 | 0.20418 |
| 0.50 | 0.31104 |

```lua
-- Solve C for a target rate p. Run once at startup, or bake the table.
local function prdConstant(p: number): number
    local function rateFor(C: number): number
        -- E[trials per success] = sum over n of n * P(first success at n)
        local pNotYet, expected = 1.0, 0.0
        local maxN = math.ceil(1 / C)
        for n = 1, maxN do
            local pn = math.min(C * n, 1)
            expected += n * pn * pNotYet
            pNotYet *= (1 - pn)
        end
        return 1 / expected
    end
    local lo, hi = 0.0, 1.0
    for _ = 1, 60 do
        local mid = (lo + hi) / 2
        if rateFor(mid) < p then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end

local PrdCounter = {}
PrdCounter.__index = PrdCounter
function PrdCounter.new(p) return setmetatable({ C = prdConstant(p), n = 0 }, PrdCounter) end
function PrdCounter:Roll(rng): boolean
    self.n += 1
    if rng:NextNumber() < self.C * self.n then self.n = 0; return true end
    return false
end
```

**Soft pity + hard pity (the gacha shape).** Genshin Impact's 5★ character banner is
the canonical public example: a flat base rate of **0.6%** from pull 1 to about pull
73; from roughly pull **74** the rate climbs by about **6 percentage points per
pull**; a **hard guarantee at pull 90**. The result is that essentially every 5★
lands between 75 and 89, with an effective overall rate near 1.6%. *(Rate values
**[unverified]** — they are community-datamined and widely reported, not published by
the developer.)*

```lua
local function fiveStarChance(pullsSinceLast: number): number
    if pullsSinceLast >= 90 then return 1.0 end
    if pullsSinceLast < 74 then return 0.006 end
    return math.min(1.0, 0.006 + 0.06 * (pullsSinceLast - 73))
end
```

**Design note.** The PRD shape is right for *frequent* events (crits, procs) because
it removes variance without being noticeable. The soft/hard-pity shape is right for
*rare, high-value* events because it creates a legible promise ("90 pulls max") that
players can plan around. Do not mix them up: a hard pity on a crit chance makes
combat feel scripted, and a PRD on a jackpot removes the jackpot.

**Server authority.** All pity counters live on the server, in the player's profile,
and are incremented *before* the roll. A client-side pity counter is the easiest
duplication exploit in the genre.

### 1.8 Randomness failure modes checklist

| Symptom | Cause | Fix |
|---|---|---|
| World differs between two runs with the same seed | Walked a global stream; `pairs()` iteration order; `table.sort` with a non-total comparator | Hierarchical seeding (§1.4); sort keys before iterating; make comparators total |
| Visible grid/diagonal banding in per-chunk features | Weak spatial hash | Squirrel3 (§1.4) |
| Client and server disagree | Float-derived branch, or transcendental function in the decision path | Branch on integer hashes only (§11.2) |
| Loot "feels" broken | Independent draws; players pattern-match on streaks | Shuffle bag or PRD (§1.6–1.7) |
| Rare crash indexing an array | `Random:NextNumber()` returned exactly 1.0 | Use `NextInteger` |
| Alias table returns index 0 or nil | Dropped one of Vose's trailing loops | §1.5 |

---

## 2. Noise

### 2.1 `math.noise`: exactly what it is

Read from `VM/src/lmathlib.cpp` in the open-source Luau VM. This is the ground truth;
several widely-repeated community claims about `math.noise` are wrong.

**It is Ken Perlin's 2002 "improved" gradient noise, in 3-D, with a fixed table.**

```cpp
inline float perlin_fade(float t) { return t*t*t*(t*(t*6 - 15) + 10); }   // 6t^5-15t^4+10t^3

const float kPerlinGrad[16][3] = {
  {1,1,0},{-1,1,0},{1,-1,0},{-1,-1,0},{1,0,1},{-1,0,1},{1,0,-1},{-1,0,-1},
  {0,1,1},{0,-1,1},{0,1,-1},{0,-1,-1},{1,1,0},{0,-1,1},{-1,1,0},{0,-1,-1} };

static const unsigned char kPerlinHash[257] = { 151,160,137,91,90,15,131,13,201, ... };
```

That permutation table is Perlin's original published table, hard-coded, 257 entries
(256 plus the wrap duplicate). The 16 gradients are Perlin's 12 cube-edge vectors with
the standard 4 repeats. Indices are masked `& 255` at each of the six lookups.

Consequences, every one of which you will eventually hit:

- **There is no seed.** `math.noise(x, y, z)` takes three *coordinates*. The extremely
  common Roblox idiom `math.noise(x / scale, y / scale, seed)` is not seeding anything
  — it is sampling the z-slice at `z = seed`. Because `seed` is usually an integer and
  Perlin noise is **exactly zero at integer lattice points**, `math.noise(x, y, 12345)`
  is a legitimate 2-D noise field but `math.noise(12, 7, 12345)` is exactly `0`.
  The docs state this plainly: *"If `x`, `y`, and `z` are all integers, the return
  value will be `0`."*
- **The period is exactly 256 on every axis.** The docs: *"The noise repeats with a
  period of `256` on each axis, so `math.noise(x, y, z)` and `math.noise(x + 256, y, z)`
  return identical values."* The VM enforces this by wrapping the inputs
  (`x = fmod(x, 256.0)`) before converting to float, specifically so that large
  coordinates do not lose mantissa precision and collapse to zero.
- **Inputs are truncated to `float`.** `perlin((float)x, (float)y, (float)z)`. You have
  ~7 significant decimal digits of coordinate resolution, not 15.
- **The output range is not [-0.5, 0.5].** The documentation says *"most often between
  the range of `-1` to `1` ... but sometimes may be outside that range"* and separately
  that values *"gradually fluctuate between -0.5 and 0.5"*. A community measurement
  over 5 million samples found actual extremes of **-0.60881221294403** and
  **+0.75304806232452** (**[unverified]** — single community measurement, but it is
  consistent with the theoretical 3-D Perlin bound of ±√3/2 ≈ ±0.866). Treat the
  practical range as **[-0.75, 0.75]** and normalise explicitly; never assume [-0.5, 0.5]
  and never assume [-1, 1] without clamping.
- **It is deterministic and identical on every platform**, because it is one fixed
  table and one fixed float algorithm compiled into the engine. `math.noise(1.158, 5.723)`
  is documented to always return `0.48397532105446`. This is the strongest determinism
  guarantee available to you in the engine — stronger than `math.sin` (§11.2).

**How to actually seed it.** Vary `z` by a *fractional* offset, and keep the offsets
at least 1.0 apart, because Perlin noise decorrelates over one lattice cell:

```lua
-- 256 usefully-distinct worlds, no more. This is the ceiling of math.noise.
local function noiseSeedOffset(worldSeed: number): number
    return (hash2(0, 0, worldSeed) % 256) + 0.5
end

local zSeed = noiseSeedOffset(worldSeed)
local h = math.noise(x * 0.01, y * 0.01, zSeed)
```

Two different `zSeed` values that differ by less than ~1.0 produce *visibly
correlated* terrain. Offsetting `x` and `y` instead does not help at all — it is a
pure translation of the same field, so a player who has seen one world has seen them
all, just shifted.

**When to leave `math.noise` behind.** If you need (a) more than ~256 distinct worlds,
(b) features larger than 256 units at base frequency without repetition, (c) 4-D noise
for animated 3-D fields, (d) simplex's lack of axis-aligned artefacts, or (e) analytic
derivatives — write your own. §2.6 gives value noise and Worley; a Luau simplex is
covered in chapter 03.

### 2.2 fBm: octaves, lacunarity, persistence

Fractional Brownian motion sums octaves of noise at doubling frequency and halving
amplitude. The three knobs and what each one actually does:

| Parameter | Typical | Controls |
|---|---|---|
| `octaves` | 4–8 | How much fine detail. Each octave costs one noise call. Stop when one octave's wavelength is smaller than your sample spacing — beyond that you are computing aliasing. |
| `lacunarity` | 2.0 | Frequency multiplier per octave. 2.0 is standard. Use 1.87 or 2.13 (irrational-ish) to break the visible self-similarity that exact doubling produces. |
| `persistence` (gain) | 0.5 | Amplitude multiplier per octave. Below 0.5 = smooth rolling hills; 0.5 = "natural"; above 0.5 = rough, noisy, mountainous. This is the single most expressive knob. |

```lua
-- Returns roughly [-1, 1]. `frequency` is in cycles per world unit.
local function fbm2(x: number, y: number, z: number, octaves: number,
                    frequency: number, lacunarity: number, persistence: number): number
    local sum, amp, norm = 0, 1, 0
    for _ = 1, octaves do
        sum += amp * math.noise(x * frequency, y * frequency, z)
        norm += amp
        frequency *= lacunarity
        amp *= persistence
    end
    return (sum / norm) * 2      -- math.noise is ~±0.5, so scale to ~±1
end
```

The `/ norm` is what keeps the output range stable as you change `octaves` — without
it, adding an octave changes the overall contrast and you re-tune every downstream
threshold. Do not skip it.

> **The 256-period trap in fBm.** Your *base* octave repeats every `256 / frequency`
> world units, and so does the whole sum. At `frequency = 0.01` (≈100-stud features)
> that is **25 600 studs** — larger than most Roblox worlds, so usually fine. At
> `frequency = 0.1` it is 2 560 studs, and players *will* notice. Check
> `256 / baseFrequency` against your world size before shipping.

### 2.3 Ridged, billow, turbulence

Three one-line variants that produce completely different landforms from the same
noise field.

```lua
-- Turbulence: |noise|. Creases along the zero contour. Fire, marble, clouds.
local t = math.abs(n)

-- Billow: 2|n| - 1. Rounded blobs, cumulus, rolling dunes.
local b = 2 * math.abs(n) - 1

-- Ridged: (1 - |n|)^2. Sharp mountain ridges. THE mountain function.
local r = (1 - math.abs(n))
r = r * r
```

Ridged multifractal (Musgrave) is the production version — it weights each octave by
the previous octave's value so ridges only branch where there is already a ridge:

```lua
local function ridgedMF(x, y, z, octaves, frequency, lacunarity, persistence)
    local sum, amp, weight, norm = 0, 1, 1, 0
    local offset, gain = 1.0, 2.0
    for _ = 1, octaves do
        local n = math.noise(x * frequency, y * frequency, z) * 2   -- to ~±1
        n = offset - math.abs(n)
        n = n * n
        n = n * weight                       -- previous octave gates this one
        weight = math.clamp(n * gain, 0, 1)
        sum += amp * n
        norm += amp
        frequency *= lacunarity
        amp *= persistence
    end
    return sum / norm
end
```

`offset` (1.0) sets where the ridge crest sits; `gain` (2.0) sets how strongly ridges
suppress detail in the valleys. Raising `gain` gives knife-edge ridges with smooth
valleys; lowering it toward 1.0 approaches plain ridged fBm.

### 2.4 Domain warping

The highest quality-per-line technique in the whole noise section. Instead of
sampling `f(p)`, sample `f(p + g(p))` where `g` is itself noise. One level turns
fBm's characteristic "crumpled paper" into something that looks eroded and flowing;
two levels looks like a satellite photo.

```lua
local function warpedFbm(x, y, z, freq)
    -- Level 1
    local q1 = fbm2(x, y, z + 0.0, 4, freq, 2, 0.5)
    local q2 = fbm2(x, y, z + 5.2, 4, freq, 2, 0.5)
    -- Level 2 (comment out for the cheaper single-level version)
    local r1 = fbm2(x + 4.0 * q1, y + 4.0 * q2, z + 1.7, 4, freq, 2, 0.5)
    local r2 = fbm2(x + 4.0 * q1, y + 4.0 * q2, z + 9.2, 4, freq, 2, 0.5)
    return fbm2(x + 4.0 * r1, y + 4.0 * r2, z + 3.1, 4, freq, 2, 0.5)
end
```

The `4.0` warp amplitudes are in *world units* of displacement and are the knob:
small values (0.5–1) give gentle meander, large values (4–8) give swirling, folded
structure. The distinct `z` offsets (0.0, 5.2, 1.7, 9.2, 3.1) are how you get
independent noise fields out of a single unseeded `math.noise` — they must be
≥ 1 apart (§2.1).

Cost: single-level warp is 3× the noise calls, two-level is 5×. Budget accordingly —
at 4 octaves each, two-level warp is 20 `math.noise` calls per sample.

### 2.5 Value noise and Worley (cellular) in Luau

You need these when `math.noise`'s fixed field is not enough, and Worley in
particular has no engine equivalent.

**Value noise** — hash the lattice, interpolate with the same quintic fade. Cheaper
than gradient noise, blockier, and it is *not* zero at lattice points (which is
sometimes exactly what you want):

```lua
local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end

local function valueNoise2(x: number, y: number, seed: number): number
    local xi, yi = math.floor(x), math.floor(y)
    local xf, yf = x - xi, y - yi
    local u, v = fade(xf), fade(yf)
    local function h(ix, iy) return hash2(ix, iy, seed) / 4294967296 end
    local a = h(xi, yi)     + u * (h(xi + 1, yi)     - h(xi, yi))
    local b = h(xi, yi + 1) + u * (h(xi + 1, yi + 1) - h(xi, yi + 1))
    return a + v * (b - a)                 -- [0, 1]
end
```

**Worley / cellular noise** — one feature point per grid cell, distance to the
nearest. F1 gives cracked-mud and cell walls; `F2 - F1` gives the classic Voronoi
border; the cell *id* gives you free region labelling (biome patches, district
assignment, crystal facets).

```lua
-- Returns f1, f2, cellId. `x, y` in cell units (multiply by frequency first).
local function worley2(x: number, y: number, seed: number)
    local xi, yi = math.floor(x), math.floor(y)
    local f1, f2, id = math.huge, math.huge, 0
    for oy = -1, 1 do
        for ox = -1, 1 do
            local cx, cy = xi + ox, yi + oy
            local h = hash2(cx, cy, seed)
            local px = cx + (h % 1024) / 1024
            local py = cy + (bit32.rshift(h, 10) % 1024) / 1024
            local dx, dy = px - x, py - y
            local d = dx * dx + dy * dy
            if d < f1 then
                f2 = f1; f1 = d; id = h
            elseif d < f2 then
                f2 = d
            end
        end
    end
    return math.sqrt(f1), math.sqrt(f2), id
end
```

The 3×3 neighbourhood is correct only if every cell's feature point stays inside its
own cell (it does, here — the offsets are in [0, 1)). If you jitter points outside
their cell you must widen to 5×5.

**Uses by field:** F1 → rock cracks, crystal growth, dried lakebed, city districts.
F2−F1 → Voronoi edges for road networks, tile borders, stained glass. cellId →
biome patch assignment, per-region colour variation, chunked ownership.

### 2.6 Seamless chunk borders

Two chunks generated independently must agree on their shared edge. There are exactly
three ways to guarantee it, and only three:

1. **Sample a global continuous function at world coordinates.** Any `f(worldX, worldZ)`
   is automatically seamless because the edge samples are literally the same call.
   This is why noise-based terrain is easy and why you should push as much as possible
   into this category.
2. **Generate with a halo.** Generate chunk (cx, cy) over `[-1, size+1]` and discard
   the border after any neighbourhood operation (cellular automata, blur, erosion).
   Costs `(size+2)² / size²` extra work — 21% at size 32, 4% at size 128.
3. **Make edge features a pure function of the edge itself.** A road that crosses the
   boundary between chunks A and B must have its crossing point determined by
   `hash2(min(ax,bx), min(ay,by), EDGE_PURPOSE)` — an identity that both chunks can
   compute without talking to each other. This is the pattern for roads, rivers,
   fences, and prefab sockets.

Anything else — "generate A, then look at A while generating B" — reintroduces order
dependence and will produce seams the moment streaming loads chunks in a different
order for a different player.

