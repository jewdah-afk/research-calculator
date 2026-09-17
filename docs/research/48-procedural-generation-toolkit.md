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

---

## 3. Dungeon and level generation

The catalogue, ordered roughly by how often it is the right answer.

### 3.1 The modern default: scatter → separate → Delaunay → MST → extra edges

This is what most shipped roguelikes and roguelites do now. Popularised by the
TinyKeep developer's 2013 write-up and reproduced in dozens of tutorials. It gives
you rooms of controlled size, guaranteed connectivity, and a tunable amount of
looping — which is exactly the set of properties you want.

**Step 1 — scatter.** Place `N` rectangles at random points inside an ellipse.
Sampling inside an ellipse rather than a rectangle is what gives dungeons an organic
silhouette; a wide flat ellipse gives a horizontal "strip" dungeon.

```lua
local function randomPointInEllipse(rw: number, rh: number, rng): (number, number)
    local t = rng:NextNumber() * math.pi * 2
    local u = rng:NextNumber() + rng:NextNumber()
    local r = (u > 1) and (2 - u) or u
    return rw * r * math.cos(t), rh * r * math.sin(t)
end
```

Room dimensions should be drawn from a distribution skewed toward small — the
TinyKeep write-up uses a Park–Miller normal distribution for this. A cheap
equivalent that works well: `size = minSize + math.floor((maxSize - minSize) * rng:NextNumber()^2)`.
Squaring biases toward the minimum; use `^3` for a stronger bias.

`N = 150` is the reference value for a full dungeon floor.

**Step 2 — separate.** The rooms overlap heavily. Push them apart with separation
steering until none overlap, keeping the packing tight:

```lua
local function separate(rooms, rng, maxIters: number)
    for _ = 1, maxIters or 200 do
        local moved = false
        for i = 1, #rooms do
            local a = rooms[i]
            local vx, vy, n = 0, 0, 0
            for j = 1, #rooms do
                if i ~= j then
                    local b = rooms[j]
                    local ox = (a.w + b.w) * 0.5 - math.abs(a.x - b.x)
                    local oy = (a.h + b.h) * 0.5 - math.abs(a.y - b.y)
                    if ox > 0 and oy > 0 then
                        -- push along the axis of least penetration
                        if ox < oy then
                            vx += (a.x < b.x) and -ox or ox
                        else
                            vy += (a.y < b.y) and -oy or oy
                        end
                        n += 1
                    end
                end
            end
            if n > 0 then
                a.x += vx / n; a.y += vy / n
                moved = true
            end
        end
        if not moved then break end
    end
    for _, r in rooms do r.x = math.floor(r.x + 0.5); r.y = math.floor(r.y + 0.5) end
end
```

Naive separation is O(N²) per iteration. At N = 150 and 200 iterations that is
4.5 M distance tests — around 40 ms in Luau, acceptable once per floor, not
acceptable per frame. Above N ≈ 300, bucket the rooms into a spatial grid first.

*Alternative:* give every room a physics body and let the engine's solver separate
them. On Roblox this means anchored-then-unanchored parts and a `RunService` wait
for sleep, which is non-deterministic — **do not do this** if determinism matters.

**Step 3 — select main rooms.** Keep only rooms above a size threshold (a common
rule: `w > 1.25 * meanW and h > 1.25 * meanH`). The rest become candidate corridor
filler in step 6.

**Step 4 — Delaunay-triangulate the main room centres.** Bowyer–Watson, ~70 lines:

```lua
-- Returns a list of {a, b, c} index triples into `pts` ({x, y} each).
local function delaunay(pts)
    local n = #pts
    -- Super-triangle enclosing everything
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    for _, p in pts do
        minx = math.min(minx, p.x); maxx = math.max(maxx, p.x)
        miny = math.min(miny, p.y); maxy = math.max(maxy, p.y)
    end
    local dx, dy = maxx - minx, maxy - miny
    local dmax = math.max(dx, dy) * 10
    local mx, my = (minx + maxx) / 2, (miny + maxy) / 2
    local work = table.clone(pts)
    work[n + 1] = { x = mx - dmax, y = my - dmax }
    work[n + 2] = { x = mx,        y = my + dmax }
    work[n + 3] = { x = mx + dmax, y = my - dmax }

    local function circum(a, b, c)
        local ax, ay, bx, by, cx, cy = work[a].x, work[a].y, work[b].x, work[b].y, work[c].x, work[c].y
        local d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        if math.abs(d) < 1e-12 then return nil end
        local a2, b2, c2 = ax*ax + ay*ay, bx*bx + by*by, cx*cx + cy*cy
        local ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
        local uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
        local r2 = (ax - ux)^2 + (ay - uy)^2
        return { ux = ux, uy = uy, r2 = r2 }
    end

    local tris = { { a = n + 1, b = n + 2, c = n + 3, cc = nil } }
    tris[1].cc = circum(n + 1, n + 2, n + 3)

    for i = 1, n do
        local p = work[i]
        local edges = {}
        for t = #tris, 1, -1 do
            local tri = tris[t]
            local cc = tri.cc
            if cc and (p.x - cc.ux)^2 + (p.y - cc.uy)^2 < cc.r2 then
                -- edges of a "bad" triangle: keep only those appearing once
                local e = { {tri.a, tri.b}, {tri.b, tri.c}, {tri.c, tri.a} }
                for _, ed in e do
                    local key = math.min(ed[1], ed[2]) .. ":" .. math.max(ed[1], ed[2])
                    edges[key] = edges[key] and false or ed
                end
                table.remove(tris, t)
            end
        end
        for _, ed in edges do
            if ed then
                local tri = { a = ed[1], b = ed[2], c = i }
                tri.cc = circum(tri.a, tri.b, tri.c)
                if tri.cc then table.insert(tris, tri) end
            end
        end
    end

    local out = {}
    for _, tri in tris do
        if tri.a <= n and tri.b <= n and tri.c <= n then
            table.insert(out, { tri.a, tri.b, tri.c })
        end
    end
    return out
end
```

Two determinism hazards in that function, both real: the `edges` table is iterated
with `pairs` (order not guaranteed — but here order does not affect the *set* of
triangles produced, only their order in `tris`, which is then re-sorted downstream, so
it is safe *provided* you sort `out`); and `math.abs(d) < 1e-12` is a float
comparison on collinear points. Snap your room centres to an integer grid before
triangulating and both problems disappear.

**Step 5 — minimum spanning tree, then add edges back.** Kruskal with union-find:

```lua
local function mst(nodeCount: number, edges)  -- edges: {{u, v, w}}
    table.sort(edges, function(p, q)
        if p[3] ~= q[3] then return p[3] < q[3] end
        if p[1] ~= q[1] then return p[1] < q[1] end
        return p[2] < q[2]                    -- total order => deterministic
    end)
    local parent = table.create(nodeCount)
    for i = 1, nodeCount do parent[i] = i end
    local function find(x) while parent[x] ~= x do parent[x] = parent[parent[x]]; x = parent[x] end return x end

    local tree, extra = {}, {}
    for _, e in edges do
        local ru, rv = find(e[1]), find(e[2])
        if ru ~= rv then parent[ru] = rv; table.insert(tree, e)
        else table.insert(extra, e) end
    end
    return tree, extra
end
```

The tie-breaking in that comparator is not optional. `table.sort` in Luau is an
introsort and is **not stable**; with equal weights, two runs can order edges
differently, and then the MST differs. Make the comparator a *total order* on
`(weight, u, v)` and the MST is unique and reproducible.

Then add back a fraction of the discarded edges to create loops:

```lua
local EXTRA_EDGE_CHANCE = 0.125     -- 12.5%: the widely-used reference value
for _, e in extra do
    if rng:NextNumber() < EXTRA_EDGE_CHANCE then table.insert(tree, e) end
end
```

**What the loop fraction controls.** 0% = a pure tree, every room a cul-de-sac,
players backtrack constantly — this is what makes MST-only dungeons feel bad.
8–15% = the sweet spot: mostly branching, occasional shortcut, players feel clever
when they find a loop. Above ~30% the map stops reading as a structure and becomes a
mesh; stealth and chase gameplay break because every pursuit has three escape routes.

**Step 6 — carve corridors.** For each surviving edge, carve an L-shaped or Z-shaped
path between room centres, then promote any of the discarded small rooms that the
corridor passes through into real rooms. This is the TinyKeep trick that makes
corridors feel like they have incident geometry rather than being bare hallways.

```lua
local function carveL(grid, ax, ay, bx, by, rng)
    local horizontalFirst = rng:NextNumber() < 0.5
    if horizontalFirst then
        for x = math.min(ax,bx), math.max(ax,bx) do grid[ay][x] = FLOOR end
        for y = math.min(ay,by), math.max(ay,by) do grid[y][bx] = FLOOR end
    else
        for y = math.min(ay,by), math.max(ay,by) do grid[y][ax] = FLOOR end
        for x = math.min(ax,bx), math.max(ax,bx) do grid[by][x] = FLOOR end
    end
end
```

**Failure modes.** Separation can fail to converge if the ellipse is too small for the
total room area — cap iterations and re-scatter with a larger ellipse rather than
looping forever. Delaunay degenerates on collinear or coincident centres — snap to a
grid and de-duplicate. Very long MST edges produce absurd corridors across the whole
map — reject edges longer than some multiple of the median and re-run MST on the
filtered graph (check connectivity after filtering).

### 3.2 BSP partitioning

Split the rectangle recursively, put a room in each leaf, connect siblings on the way
back up the tree. The virtue is that it *cannot* produce overlapping rooms and gives
you a natural hierarchy (useful for "wings" of a building). The vice is that it looks
like it: everything is axis-aligned and rooms are suspiciously evenly spread.

```lua
local MIN_LEAF, MAX_LEAF = 8, 20
local SPLIT_RATIO = 0.4          -- split point in [0.4, 0.6] of the span

local function bspSplit(node, rng, depth, out)
    local w, h = node.w, node.h
    local canSplitH = h >= MIN_LEAF * 2
    local canSplitV = w >= MIN_LEAF * 2
    if depth <= 0 or (not canSplitH and not canSplitV) or
       (w <= MAX_LEAF and h <= MAX_LEAF and rng:NextNumber() < 0.25) then
        table.insert(out, node); return
    end
    -- split the longer axis, unless the aspect ratio is near 1 (then choose randomly)
    local vertical
    if canSplitV and canSplitH then
        if w / h >= 1.25 then vertical = true
        elseif h / w >= 1.25 then vertical = false
        else vertical = rng:NextNumber() < 0.5 end
    else vertical = canSplitV end

    local span = vertical and w or h
    local lo = math.floor(span * SPLIT_RATIO)
    local hi = span - lo
    local cut = rng:NextInteger(lo, hi)

    local a, b
    if vertical then
        a = { x = node.x,       y = node.y, w = cut,     h = h }
        b = { x = node.x + cut, y = node.y, w = w - cut, h = h }
    else
        a = { x = node.x, y = node.y,       w = w, h = cut }
        b = { x = node.x, y = node.y + cut, w = w, h = h - cut }
    end
    node.a, node.b = a, b
    bspSplit(a, rng, depth - 1, out)
    bspSplit(b, rng, depth - 1, out)
end
```

Then inset a room inside each leaf (`rng:NextInteger(1, leaf.w - roomW - 1)` for the
offset) and, walking back up, connect the room nearest the split line in `a` to the
one in `b`.

`SPLIT_RATIO` is the key parameter: 0.5 gives perfectly even quadrants (very
artificial), 0.3 gives strong size variety at the cost of occasionally tiny leaves.
0.4 is a good default. `MIN_LEAF` must be at least `minRoomSize + 2` or you get
leaves with no room in them.

**Use BSP for:** building interiors, office blocks, ship decks, anything that should
read as architected. **Avoid for:** caves, ruins, anything organic.

### 3.3 Cellular-automata caves

The right tool for organic caverns. The rules, the initial fill and the iteration
count are all well-established from the RogueBasin write-up and its descendants.

```lua
local FILL = 0.45        -- probability a cell starts as WALL
local BIRTH = 5          -- a FLOOR cell becomes WALL if >= 5 of its 8 neighbours are WALL
local SURVIVE = 4        -- a WALL cell stays WALL if >= 4 of its 8 neighbours are WALL
local ITERATIONS = 4     -- 4-5; the map stops changing much after 4

local function caves(w: number, h: number, rng)
    local g = {}
    for y = 1, h do
        g[y] = table.create(w)
        for x = 1, w do
            -- hard border keeps the cave enclosed
            local border = (x == 1 or y == 1 or x == w or y == h)
            g[y][x] = (border or rng:NextNumber() < FILL) and 1 or 0
        end
    end

    for _ = 1, ITERATIONS do
        local n = {}
        for y = 1, h do
            n[y] = table.create(w)
            for x = 1, w do
                local count = 0
                for dy = -1, 1 do for dx = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local yy, xx = y + dy, x + dx
                        -- out of bounds counts as WALL: keeps edges solid
                        if yy < 1 or yy > h or xx < 1 or xx > w or g[yy][xx] == 1 then
                            count += 1
                        end
                    end
                end end
                if g[y][x] == 1 then n[y][x] = (count >= SURVIVE) and 1 or 0
                else                 n[y][x] = (count >= BIRTH)   and 1 or 0 end
            end
        end
        g = n
    end
    return g
end
```

**What each parameter does.**

- `FILL` is the dominant knob. 0.40 → large open caverns, risk of one giant blob.
  0.45 → the reference value, balanced caves with passages. 0.50 → tight, maze-like,
  many disconnected pockets. Above 0.55 the map mostly fills in.
- `BIRTH`/`SURVIVE` at 5/4 is the "4-5 rule". Dropping `SURVIVE` to 3 erodes walls
  aggressively and opens everything up; raising `BIRTH` to 6 makes the CA almost
  inert.
- `ITERATIONS`: 1–2 gives craggy, noisy caves with lots of small debris (sometimes
  desirable for rubble); 4–5 is smooth; past 5 nothing changes.

**The defining failure mode is disconnection.** The CA does not know about
connectivity and routinely produces 3–10 separate caverns. You must post-process:

```lua
-- Flood fill into labelled regions; keep the largest, tunnel the rest to it.
local function regions(g, w, h)
    local label, regs = {}, {}
    for y = 1, h do label[y] = table.create(w, 0) end
    for y = 1, h do for x = 1, w do
        if g[y][x] == 0 and label[y][x] == 0 then
            local id = #regs + 1
            local cells, stack = {}, { {x, y} }
            label[y][x] = id
            while #stack > 0 do
                local c = table.remove(stack)
                table.insert(cells, c)
                for _, d in { {1,0}, {-1,0}, {0,1}, {0,-1} } do
                    local nx, ny = c[1] + d[1], c[2] + d[2]
                    if nx >= 1 and nx <= w and ny >= 1 and ny <= h
                       and g[ny][nx] == 0 and label[ny][nx] == 0 then
                        label[ny][nx] = id
                        table.insert(stack, {nx, ny})
                    end
                end
            end
            regs[id] = cells
        end
    end end
    return regs, label
end
```

Then either (a) keep only the largest region and fill the rest — simple, wastes map
area, and can produce a cave much smaller than requested; or (b) connect regions by
finding, for each pair, the closest cell pair and carving a 1–2 tile tunnel. Option (b)
is what shipped games do. If you keep only the largest region, *check its area* and
regenerate with a different seed if it is under ~35% of the map — that is a cheap and
effective quality gate (§10.2).

**Genres:** caves, mines, asteroid interiors, organic alien hives, destructible
terrain seeds, island coastlines (run the CA on a masked region).

### 3.4 Drunkard's walk

The simplest generator that produces a guaranteed-connected map. A walker starts at
the centre, carves its current tile, and steps in a random direction, repeating until
a target fraction of the map is floor.

```lua
local function drunkardsWalk(w, h, targetFraction, rng)
    local g = {}
    for y = 1, h do g[y] = table.create(w, 1) end
    local x, y = w // 2, h // 2
    local target = math.floor(w * h * targetFraction)
    local carved, dx, dy = 0, 0, 0
    local MOMENTUM = 0.7                -- chance of continuing in the same direction
    while carved < target do
        if g[y][x] == 1 then g[y][x] = 0; carved += 1 end
        if dx == 0 and dy == 0 or rng:NextNumber() > MOMENTUM then
            local d = ({ {1,0}, {-1,0}, {0,1}, {0,-1} })[rng:NextInteger(1, 4)]
            dx, dy = d[1], d[2]
        end
        x = math.clamp(x + dx, 2, w - 1)
        y = math.clamp(y + dy, 2, h - 1)
    end
    return g
end
```

`targetFraction` 0.35–0.45 is usable. `MOMENTUM` is the quality knob: at 0 you get a
blobby amoeba centred on the start; at 0.7–0.85 you get sprawling winding tunnels; at
0.95 you get near-straight corridors that clip the walls.

**Strengths:** trivially connected, trivially chunk-safe if you seed the walker per
chunk, very cheap. **Weaknesses:** no structure, no rooms, no control over shape, and
the walker spends most of its time re-carving already-carved tiles (the "target
fraction" loop can run 5–10× the number of carved tiles). Use multiple walkers from
different starts, joined by a final connectivity pass, for larger maps.

### 3.5 Maze algorithms, chosen by texture

All of these produce a spanning tree of the grid (a "perfect maze" — exactly one path
between any two cells). They differ in the *statistics* of that tree, and that is what
the player feels.

| Algorithm | Texture | Dead ends | Memory | Use when |
|---|---|---|---|---|
| **Recursive backtracker** (DFS) | Long, winding corridors; low branching | Few (~10%) | O(cells) + stack | Default. Feels like a dungeon, not a puzzle. |
| **Prim's (randomised)** | Short stubby branches radiating from the start | Many (~30%) | O(frontier) | You *want* the player frustrated; cave-ish rooms |
| **Kruskal's (randomised)** | Uniform, no directional bias, medium runs | Medium | O(cells) | Neutral texture; easy to weight specific edges |
| **Wilson's** (loop-erased random walk) | Unbiased *uniform* spanning tree | Medium | O(cells) | Research-grade unbiasedness; slow to start |
| **Aldous–Broder** | Also uniform | Medium | O(cells) | Never — Wilson's dominates it |
| **Eller's** | Slight horizontal bias, tunable | Tunable | **O(one row)** | **Infinite / streamed mazes.** The only one that generates row by row without holding the maze. |
| **Recursive division** | Rectangular rooms-within-rooms | Few | O(log n) stack | Architectural, "walls" feel |

**Recursive backtracker** (iterative, no stack-overflow risk):

```lua
local function recursiveBacktracker(w, h, rng)
    -- cells[y][x] = bitmask of open directions: 1=N 2=E 4=S 8=W
    local cells = {}
    for y = 1, h do cells[y] = table.create(w, 0) end
    local visited = {}
    for y = 1, h do visited[y] = table.create(w, false) end

    local DIRS = { {0,-1,1,4}, {1,0,2,8}, {0,1,4,1}, {-1,0,8,2} }  -- dx,dy,bit,oppositeBit
    local stack = { { rng:NextInteger(1, w), rng:NextInteger(1, h) } }
    visited[stack[1][2]][stack[1][1]] = true

    while #stack > 0 do
        local cur = stack[#stack]
        local cx, cy = cur[1], cur[2]
        -- collect unvisited neighbours
        local options = {}
        for _, d in DIRS do
            local nx, ny = cx + d[1], cy + d[2]
            if nx >= 1 and nx <= w and ny >= 1 and ny <= h and not visited[ny][nx] then
                table.insert(options, d)
            end
        end
        if #options == 0 then
            table.remove(stack)
        else
            local d = options[rng:NextInteger(1, #options)]
            local nx, ny = cx + d[1], cy + d[2]
            cells[cy][cx] = bit32.bor(cells[cy][cx], d[3])
            cells[ny][nx] = bit32.bor(cells[ny][nx], d[4])
            visited[ny][nx] = true
            table.insert(stack, { nx, ny })
        end
    end
    return cells
end
```

**Eller's algorithm** — the one nobody implements and everybody should, because it is
the only maze algorithm that streams. It processes one row at a time, maintaining only
a set id per cell in the current row:

```
for each row except the last:
  1. assign any cell without a set id a fresh unique set id
  2. for each horizontal neighbour pair in the row:
       if they are in different sets, randomly (p = horizontalBias) join them:
         carve the wall and union the two sets
  3. for each set present in the row:
       choose at least one cell (and each other cell with p = verticalBias)
       to carve downward; the chosen cells carry their set id into the next row
  4. cells not carried down start the next row with no set id
final row:
  join every horizontally adjacent pair that is in a different set
```

`horizontalBias` and `verticalBias` are the texture knobs and they are *independent*:
high horizontal / low vertical gives long east–west halls; the reverse gives vertical
shafts. Memory is one row, so an infinite scrolling maze costs O(width).

**Post-processing every maze needs:** *braiding* (removing dead ends by carving one
extra wall at each) converts a perfect maze into one with loops. Braid 100% and the
maze becomes fully connected with no cul-de-sacs (good for chase gameplay); braid
30–50% for a mix. Also *sparsification* — repeatedly erase dead-end cells entirely —
turns a full-grid maze into a sparser corridor network, which is what Nystrom's
generator (§3.6) does at the end.

### 3.6 Rooms and mazes (Nystrom)

Bob Nystrom's 2014 generator, used in Hauberk, and the cleanest way to get a dungeon
that has *both* proper rooms *and* proper corridors:

1. **Place rooms** by rejection sampling: pick a random odd-sized room at a random odd
   position, reject if it overlaps an existing room, repeat a fixed number of attempts.
   Odd sizes and positions keep everything on the same parity lattice as the maze.
2. **Flood the remaining solid space with maze** using a growing-tree algorithm,
   starting from every unvisited odd cell. The `windingPercent` parameter controls
   whether the growing tree prefers to continue in its current direction (low winding →
   long straight corridors) or pick randomly (high winding → twisty). Reference
   implementations use a low value (~10%).
3. **Find connectors** — every solid tile that is adjacent to exactly two different
   regions (a room and a maze, or two mazes).
4. **Merge regions**: pick a random connector, carve it, union the two regions. Repeat
   until one region remains. This is a spanning tree over regions. Every other
   connector that touched those two regions is now redundant and is *discarded*, except
   with probability `extraConnectorChance` (~4% in the reference) in which case it is
   also carved, creating a loop.
5. **Remove dead ends**: repeatedly find any open tile with exactly one open neighbour
   and fill it. Run to fixpoint. This deletes all the maze's cul-de-sacs and leaves
   only corridors that actually connect rooms.

Step 5 is the magic. Without it you have a room-and-maze hybrid that is 60% pointless
maze; with it you have a dungeon where every corridor goes somewhere.

*(Parameter values `windingPercent ≈ 0.1` and `extraConnectorChance ≈ 0.04` are
**[unverified]** — reported by implementations of Nystrom's Dart original; the
source article was unreachable from this session.)*

### 3.7 Prefab stitching with connection sockets

When you want hand-authored quality and procedural variety, stitch authored modules.
This is how most Roblox horror/backrooms/liminal games and most "dungeon crawler"
titles actually build their spaces.

**Data model.** Each prefab is a `Model` with a folder of `Attachment`s (or invisible
parts) tagged as sockets. A socket carries:

- `CFrame` (position + the direction the doorway faces — by convention, `LookVector`
  points *out* of the module)
- `SocketType: string` — `"corridor_2x3"`, `"door_1x2"`, `"stairs_down"`
- `Tags: {string}` — semantic constraints (`"combat"`, `"dead_end_ok"`)

**Placement.** To attach module B's socket `sb` to an already-placed socket `sa`, the
required CFrame is:

```lua
-- Align sb to face sa: rotate B 180° about its socket's up axis so the two
-- LookVectors oppose.
local function dockCFrame(sa: CFrame, sb_local: CFrame): CFrame
    local flip = CFrame.Angles(0, math.pi, 0)
    return sa * flip * sb_local:Inverse()
end
```

Then the module's world CFrame is `dockCFrame(socketWorldCFrame, socketLocalCFrame)`.

**The algorithm** is a depth-first walk with rejection:

```
open = { the start module's free sockets }
while #open > 0 and placed < budget:
    socket = pop a socket (random, or nearest-to-goal for directed growth)
    candidates = modules with a matching socket type, filtered by tags and budget
    shuffle candidates
    for each candidate, for each of its matching sockets:
        cf = dockCFrame(socket, candidateSocket)
        if not overlapsAnything(candidate, cf):        -- see below
            place it; push its other sockets onto `open`; break
    if nothing fit: cap the socket with a wall/dead-end prefab
```

**Overlap testing** is the whole difficulty. Options, in increasing order of cost and
quality:

1. **Grid occupancy.** Require every module to occupy whole cells of a coarse 3-D grid
   (e.g. 4×4×4 studs) and keep a hash set of occupied cells. O(cells per module). This
   is what you should do — it is fast, exact, and deterministic.
2. **AABB overlap** against all placed modules with a spatial hash. Cheap but rejects
   legitimate interlocking geometry (an L-shaped module's bounding box).
3. `Workspace:GetPartBoundsInBox` / `GetPartsInPart` with an `OverlapParams` filter.
   Accurate but touches the DataModel, so it cannot run in a parallel Actor and it is
   slow enough to matter at hundreds of modules.

**Failure modes.** *Dead-end explosion* — a purely random walk terminates early;
weight candidate selection by socket count to keep growing. *Loops never close* — two
branches that grow toward each other will not merge unless you explicitly test, at each
placement, whether a free socket of the new module aligns with an existing free socket
within a tolerance; if so, fuse them. *Budget overrun* — always cap total modules and
have a "cap" prefab for every socket type.

### 3.8 Graph grammars: missions, locks and keys

This is the section that separates designed-feeling levels from noise. Everything above
generates *space*. None of it generates *structure* — a reason to go left before right,
a key that must be found before a door, a boss that is gated behind three trials.

The approach is Joris Dormans' (with Sander Bakkes), published as "Generating Missions
and Spaces for Adaptable Play Experiences" (IEEE TCIAIG, 2011): **generate the mission
graph first, then embed it into space.** Two grammars, two steps.

**Step 1 — the mission graph.** Start from a trivial graph and rewrite it with
production rules. Nodes are *tasks* (`entrance`, `obtain`, `use`, `lock`, `goal`,
`fight`, `explore`); edges are *dependencies* (you must do A before B).

A minimal but genuinely useful rule set:

```
R1 (seed):        [entrance] -> [goal]
                     ==>  [entrance] -> [explore] -> [goal]

R2 (lock & key):  A -> B
                     ==>  A -> [obtain key_i] -> [lock_i] -> B
                     (the key node must be reachable without passing the lock)

R3 (branch):      A -> B
                     ==>  A -> [fork] -> {B, [side: treasure]}

R4 (gauntlet):    [lock_i] -> B
                     ==>  [lock_i] -> [fight] -> [fight] -> B

R5 (hidden key):  [obtain key_i]
                     ==>  [explore] -> [secret] -> [obtain key_i]
```

Apply rules N times, choosing a rule and a matching site with weighted random
selection. The critical invariant, which you enforce by construction rather than by
checking: **R2 only ever inserts the key node on the path *before* the lock node**, so
the graph is solvable by construction. If you ever add a rule that could violate this,
you must run a topological sort afterwards and reject any graph with a cycle in the
dependency edges.

```lua
-- Solvability proof by simulation: can a player holding nothing reach the goal?
local function isSolvable(nodes, edges, startId, goalId): boolean
    local have, doneSet = {}, {}
    local progress = true
    while progress do
        progress = false
        for id, node in nodes do
            if not doneSet[id] then
                local ready = true
                for _, e in edges do
                    if e.to == id and not doneSet[e.from] then ready = false; break end
                end
                if ready and node.kind == "lock" and not have[node.keyId] then ready = false end
                if ready then
                    doneSet[id] = true
                    if node.kind == "obtain" then have[node.keyId] = true end
                    progress = true
                end
            end
        end
    end
    return doneSet[goalId] == true
end
```

That function is short enough that you should simply run it on every generated graph
and regenerate on failure. It is the cheapest solvability proof in this chapter.

**Step 2 — embed the mission into space.** Now walk the mission graph and allocate
rooms. The rules are:

- Each mission node becomes one or more rooms. `fight` nodes want arenas; `secret`
  nodes want a hidden or awkward connection; `lock` nodes become a door between two
  rooms.
- The *dependency* edges become spatial *adjacency* constraints, but not one-to-one:
  a dependency `A -> B` only requires that a path from A to B exists that does not pass
  through any lock whose key is obtained after A.
- Extra spatial edges (loops, shortcuts) are free to add — they cannot break
  solvability, only shorten it. This is where §3.1's extra-edge pass belongs.

The practical implementation is: run §3.1 to get a room graph, then assign mission
nodes to rooms by walking the mission graph in topological order and placing each node
in a room at increasing graph distance from the entrance, with locks placed on the
edges that separate the "before" set from the "after" set. Verify with `isSolvable`
against the *spatial* graph, not just the mission graph, and regenerate on failure.

**Genres this unlocks:** Zelda-likes, Metroidvanias, immersive sims, escape rooms,
any game where the level is a puzzle rather than a battlefield. Amid Moradi's
`GraphDungeonGenerator` is a public implementation of exactly this Dormans pipeline
for Zelda-1-style dungeons.

---

## 4. Wave Function Collapse

WFC is a constraint-propagation solver dressed as a texture synthesiser. Maxim Gumin's
2016 reference implementation (`mxgmn/WaveFunctionCollapse`) is the definition; the
code below is read directly from `Model.cs`, `OverlappingModel.cs` and
`SimpleTiledModel.cs`.

### 4.1 The core loop

```
Init:
  wave[cell][pattern] = true for all cells, all patterns
  compatible[cell][pattern][dir] = number of patterns in the OPPOSITE direction
                                   that are compatible with `pattern`
Loop:
  cell = NextUnobservedNode()          -- minimum entropy, or -1 if all decided
  if cell < 0: done, read out the answer
  Observe(cell)                        -- collapse to one pattern, weighted
  if not Propagate(): CONTRADICTION -> abort
```

**Entropy.** The reference uses Shannon entropy of the *weighted* remaining set, kept
incrementally:

```
entropy[i] = log(Σ w_t) − (Σ w_t·log w_t) / (Σ w_t)      over t still possible at i
```

Both sums are maintained by `Ban()` in O(1). The tie-break is a tiny noise term:
`min = entropy + 1e-6 * random()`. Without it, large uniform regions collapse in
scanline order and the output shows directional structure.

Two cheaper heuristics ship in the reference and are worth knowing:
`MRV` (minimum remaining values — just `sumsOfOnes[i]`, ignoring weights) is faster
and nearly as good; `Scanline` simply walks in order and is dramatically faster but
produces visible directional bias. Use `Entropy` for stills, `Scanline` when you are
generating something the player only sees from one side.

**Observe.** Draw one pattern from the still-possible set, weighted by the pattern's
frequency in the input, then `Ban()` every other pattern at that cell.

**Propagate — the counter trick.** This is the part people reimplement badly. Do *not*
recompute compatibility by scanning; maintain, for each `(cell, pattern, direction)`,
a **count of supporting patterns in the neighbour on that side**. When a pattern is
banned at cell `i`, decrement the support counter of every pattern it supported in
each of the four neighbours; when a counter reaches zero, that pattern has lost all
support and is itself banned, which pushes more work onto the stack.

```
Ban(i, t):
    wave[i][t] = false
    compatible[i][t][d] = 0 for all d
    push (i, t)
    sumsOfOnes[i]   -= 1
    sumsOfWeights[i]-= w[t];  sumsOfWLogW[i] -= w[t]log w[t]
    entropy[i] = log(sumsOfWeights[i]) − sumsOfWLogW[i]/sumsOfWeights[i]

Propagate():
    while stack not empty:
        (i1, t1) = pop
        for each of the 4 directions d:
            i2 = neighbour of i1 in direction d   (wrap if periodic, else skip)
            for each t2 in propagator[d][t1]:      -- patterns t1 supported
                compatible[i2][t2][d] -= 1
                if compatible[i2][t2][d] == 0: Ban(i2, t2)
```

`propagator[d][t]` is precomputed once: the list of patterns that may sit in direction
`d` from pattern `t`.

### 4.2 The two models

**Simple tiled model** (`N = 1`). You supply tiles and an explicit adjacency list.
Symmetry classes let you declare one tile and get its rotations for free — the
reference's cardinalities are:

| symmetry | cardinality | meaning |
|---|---|---|
| `X` | 1 | fully symmetric (blank, cross) |
| `I` | 2 | 180°-symmetric bar |
| `\` | 2 | diagonal |
| `T` | 4 | T-junction |
| `L` | 4 | corner |
| `F` | 8 | no symmetry |

This is the model to use for 3-D Roblox content: your "tiles" are prefab `Model`s,
your adjacency is a socket-compatibility table, and the output is a placement grid.

**Overlapping model** (`N = 3` typical). Extract every `N×N` patch of an example
bitmap, count frequencies, and derive adjacency from patch *overlap*: patterns `p1`
and `p2` may be offset by `(dx, dy)` iff their overlapping region is pixel-identical.
Defaults in the reference driver: `N = 3`, `symmetry = 8` (all 8 dihedral
transforms), `periodicInput = true`, output size 48×48 for overlapping and 24×24
tiled.

`N` is the key parameter: `N = 2` is fast and mushy, `N = 3` is the sweet spot,
`N = 4+` reproduces larger input motifs but the pattern count explodes and
contradictions become common. `symmetry = 1` preserves the input's orientation (use
for anything with a ground/sky distinction); `symmetry = 8` maximises variety.

`ground = true` forces the bottom row to the last pattern and bans that pattern
everywhere else — this is how you get a terrain that has a floor.

### 4.3 Contradictions, retries, backtracking

The reference implementation **does not backtrack**. `Run(seed, limit)` returns
`false` on contradiction and the driver simply retries with a new seed, **up to 10
times**, then gives up on that sample. Gumin's own note: determining whether a
constraint set is satisfiable is NP-hard, so nothing can guarantee fast completion —
but in practice, for well-formed tilesets, "contradictions occur surprisingly rarely".

Retry-with-new-seed is the right default because a full restart is cheap compared to
maintaining an undo log, and because a tileset that contradicts often is a *tileset
bug*, not an algorithm problem.

When you do need backtracking (large outputs where a restart is expensive, or
tilesets with genuinely tight constraints), the standard design is:

- Snapshot the wave before each `Observe` (a bitset copy — `buffer` in Luau, one bit
  per `(cell, pattern)`).
- On contradiction, restore the snapshot, ban the pattern you just chose at that cell,
  and re-propagate. If the cell runs out of options, pop another level.
- Cap the depth (10–20) and fall back to a full restart.

Memory: `cells × patterns` bits per snapshot. A 64×64 grid with 60 patterns is
245 760 bits = 30 KB per level — fine. A 256×256 grid with 400 patterns is 3.2 MB per
level — not fine.

> **A real quirk in the reference:** `Propagate()` ends with `return sumsOfOnes[0] > 0`,
> which only inspects cell 0. A robust implementation should have `Ban()` set a
> `contradiction` flag whenever `sumsOfOnes[i]` hits zero, and check that flag. Port
> the fix, not the line.

### 4.4 Performance and Luau notes

The reference is O(cells × patterns) memory and, empirically, roughly
O(cells × patterns × log) time. Concretely, for a Luau port:

- Store `wave` as a `buffer` bitset, not a table of tables. A 64×64×64-pattern wave is
  262 144 bits = 32 KB in a `buffer` versus ~2 MB as nested Luau tables.
- `compatible` is `cells × patterns × 4` small integers — use a `buffer` of `u8`
  (counts rarely exceed 255; assert if they do).
- The propagation stack is the hot loop. Preallocate it as
  `table.create(cells * patterns)` and use an integer `stacksize`, exactly as the
  reference does — never `table.insert`/`table.remove`.
- Enable `--!native` on the model module. This is the archetypal native-codegen win:
  tight integer loops over buffers.
- WFC is **not** parallelisable across Actors within one wave (propagation is global).
  It *is* parallelisable across independent chunks if you accept seams, or if you
  pre-constrain each chunk's border from the already-solved neighbour (which
  reintroduces order dependence — see §2.6).

Budget guidance: a 48×48 output over ~60 patterns lands in the tens of milliseconds
in native Luau. A 200×200 output will hitch; time-slice it (§11.3).

### 4.5 When WFC is the wrong tool

This matters more than the algorithm.

- **When the output must be *solvable*.** WFC has no notion of reachability, of a path
  from A to B, of a key before a lock. It produces locally plausible texture. A WFC
  dungeon is frequently disconnected. If the player must traverse it, either
  post-validate and regenerate (§10.5), or use a graph grammar (§3.8) for the
  structure and WFC only for the surfaces.
- **When you need *global* structure.** "Exactly three towers, one per district" is
  not expressible as a local adjacency constraint. WFC is a local solver.
- **When the input example is hard to author.** For the overlapping model you must
  draw a bitmap that contains every motif you want *and no motif you do not want*. In
  practice this is a fiddly, unintuitive authoring loop; many teams spend more time on
  the sample image than they would have on a bespoke generator.
- **When you have fewer than ~20 tiles.** Below that, a hand-rolled constraint pass or
  simple rule-based tiling is simpler, faster and easier to debug.
- **When you need it to run every frame.** It does not degrade gracefully.

**Where WFC genuinely wins:** set dressing and surfaces (floor/wall/trim tiling,
pipe networks, decorative facades), constrained 3-D module assembly where sockets are
already a clean adjacency relation, and "infinite" texture-like content where local
plausibility is the whole requirement.

---

## 5. Placement and scattering

### 5.1 Poisson-disk sampling (Bridson)

Bridson's SIGGRAPH 2007 sketch, "Fast Poisson Disk Sampling in Arbitrary Dimensions":
O(N), trivially implementable, and the right default for scattering anything that
should look natural but not clumped.

Inputs: domain extent, minimum distance `r`, and `k` = number of candidate darts per
active sample (the paper's and everyone's value is **k = 30**).

The background grid has cell size **`r / √n`** for `n` dimensions (`r / √2` in 2-D),
which guarantees at most one sample per cell, so the neighbour test is a fixed small
window.

```lua
-- Returns {Vector2}. Points are at least `r` apart, at most ~r*2 apart.
local function poissonDisk(width: number, height: number, r: number, rng, k: number?)
    k = k or 30
    local cell = r / math.sqrt(2)
    local gw = math.ceil(width / cell)
    local gh = math.ceil(height / cell)
    local grid = table.create(gw * gh, 0)          -- 0 = empty, else index into points
    local points, active = {}, {}

    local function gridIndex(x, y)
        return math.floor(y / cell) * gw + math.floor(x / cell) + 1
    end

    local function fits(x, y): boolean
        if x < 0 or y < 0 or x >= width or y >= height then return false end
        local gx, gy = math.floor(x / cell), math.floor(y / cell)
        for yy = math.max(gy - 2, 0), math.min(gy + 2, gh - 1) do
            for xx = math.max(gx - 2, 0), math.min(gx + 2, gw - 1) do
                local pi = grid[yy * gw + xx + 1]
                if pi ~= 0 then
                    local p = points[pi]
                    local dx, dy = p.X - x, p.Y - y
                    if dx * dx + dy * dy < r * r then return false end
                end
            end
        end
        return true
    end

    local function emit(x, y)
        table.insert(points, Vector2.new(x, y))
        grid[gridIndex(x, y)] = #points
        table.insert(active, #points)
    end

    emit(rng:NextNumber() * width, rng:NextNumber() * height)

    while #active > 0 do
        local ai = rng:NextInteger(1, #active)
        local p = points[active[ai]]
        local placed = false
        for _ = 1, k do
            -- uniform in the annulus [r, 2r]
            local ang = rng:NextNumber() * math.pi * 2
            local rad = r * math.sqrt(1 + 3 * rng:NextNumber())   -- sqrt(r^2 + 3r^2*u)/r
            local x, y = p.X + math.cos(ang) * rad, p.Y + math.sin(ang) * rad
            if fits(x, y) then emit(x, y); placed = true; break end
        end
        if not placed then
            active[ai] = active[#active]
            table.remove(active)
        end
    end
    return points
end
```

Two details people get wrong. The annulus radius must be `sqrt(r² + 3r²·u)` (i.e.
area-uniform between `r` and `2r`), not `r + r·u` — the linear version over-samples
near `r` and produces a visible hexagonal lattice. And removing the exhausted active
entry with swap-remove (`active[ai] = active[#active]`) rather than `table.remove(active, ai)`
keeps the whole thing O(N) instead of O(N²).

**Parameters.** `r` is your density: expected count ≈ `0.7 * area / r²`. `k` trades
time for packing tightness — `k = 30` is fine; `k = 10` is ~15% faster and slightly
sparser; above 30 there is no measurable gain.

**Failure modes.** The algorithm is *not* chunk-friendly: it grows from a seed point
and the result depends on the whole domain, so you cannot generate chunk (5,3)
independently. For infinite worlds use §5.2 or generate per-chunk with a halo and
resolve cross-border conflicts by a deterministic rule (lower `(cx, cy)` wins).

### 5.2 Jittered grids and hash-based blue noise

The chunk-safe substitutes. A jittered (stratified) grid is a regular grid with each
sample displaced randomly within its cell:

```lua
local function jittered(cx, cy, cellSize, jitter, seed)
    -- Deterministic per world cell; no state, no ordering.
    local h = hash2(cx, cy, seed)
    local jx = ((h % 65536) / 65536 - 0.5) * jitter
    local jy = ((bit32.rshift(h, 16) % 65536) / 65536 - 0.5) * jitter
    return (cx + 0.5 + jx) * cellSize, (cy + 0.5 + jy) * cellSize
end
```

`jitter` ∈ [0, 1]: 0 is a hard grid (obvious), 1 lets neighbours touch (clumpy),
**0.6–0.8** looks natural while keeping a minimum separation. Then apply a density
mask: `if hash2(cx, cy, seed + 1) / 2^32 < density(x, y) then place() end`.

This is the technique for trees, grass, rocks and ore in an infinite world. It is
stateless, order independent, and both machines compute the same answer — everything
Poisson-disk is not.

For higher-quality blue noise that is still stateless, sample a precomputed blue-noise
tile (a 64×64 texture of thresholds) and compare against your density. Void-and-cluster
generates the tile offline.

### 5.3 Lloyd relaxation

Given a point set, repeatedly (a) compute the Voronoi diagram, (b) move each point to
its cell's centroid. Converges to a centroidal Voronoi tessellation — very even,
organic-but-regular spacing. This is what gives Amit Patel's polygon-map-generation
its characteristic look.

2–3 iterations is what you want. One iteration removes the worst clumping; by 4–5 the
result is nearly hexagonal and reads as artificial.

If you do not want to implement Voronoi, you can approximate a relaxation step with
repulsion: move each point away from its k nearest neighbours by a fraction of the
overlap. Three passes of that is visually close and much less code.

**Uses:** biome region seeds, city district centres, crystal/rock facet centres,
territory maps, hex-ish irregular grids.

### 5.4 Clustering

Naturally occurring things cluster. Two cheap models:

- **Parent–child (Neyman–Scott).** Scatter `M` cluster centres with Poisson-disk or a
  jittered grid, then around each drop `Poisson(λ)` children at Gaussian-distributed
  offsets with standard deviation `σ`. `σ` sets the clump tightness, `λ` the clump
  size. Trees, mushroom rings, ore veins, enemy camps.
- **Noise-modulated density.** `density(x, y) = base * smoothstep(t0, t1, fbm(x, y))`.
  Multiply into the jittered-grid acceptance test. This gives you clusters that are
  *correlated with the terrain*, which is usually what you actually want (forests in
  valleys, not forests at random).

### 5.5 Placement rules

Every scattered object should pass a rule stack before it is committed. The standard
set, in the order you should evaluate it (cheapest rejection first):

| Rule | Test | Typical values |
|---|---|---|
| Altitude | `y` within `[minY, maxY]`, with a soft fade band | trees 5–180, snow props > 160 |
| Slope | `normal:Dot(Vector3.yAxis) >= cos(maxSlope)` | trees ≤ 30°, buildings ≤ 8°, rocks ≤ 60° |
| Biome | `biomeAt(x, z)` in an allowed set | — |
| Water | `y > waterLevel + clearance` | clearance 0.5–2 studs |
| Proximity | no object of an excluding class within `d` | trees–trees 6, buildings–trees 12 |
| Footprint | the object's AABB fits, and the ground under all 4 corners is within `Δy` | `Δy ≤ 1.5` studs for buildings |
| Path/POI clearance | distance to any road/spawn/quest volume > `c` | 8–20 studs |

```lua
local function slopeAt(x: number, z: number, heightFn): number
    local e = 1.0
    local hL, hR = heightFn(x - e, z), heightFn(x + e, z)
    local hD, hU = heightFn(x, z - e), heightFn(x, z + e)
    local n = Vector3.new(hL - hR, 2 * e, hD - hU).Unit
    return math.deg(math.acos(math.clamp(n.Y, -1, 1)))
end
```

Evaluate the *slope from the same height function* you used to build the terrain, not
from a raycast — a raycast hits props and gives you nonsense, and it cannot run in a
parallel Actor.

