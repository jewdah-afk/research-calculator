# Incremental / Idle Game Architecture on Roblox

*A reference for teams building generator-and-prestige games in Luau: closed-form
production math, offline progress, multiplier stacking, session-locked persistence,
and the bandwidth and exploit problems that only show up at 1e300.*

Primary sources are Roblox's own documentation, read from the public
[`Roblox/creator-docs`](https://github.com/Roblox/creator-docs) repository (the source
of truth behind `create.roblox.com/docs`), and the actual Luau source of the
persistence libraries discussed. Verified **September 2026**. Anything I could not
confirm against a primary source is flagged `[UNVERIFIED]`; anything that is
established community practice rather than documented behaviour is flagged
`[COMMUNITY, SECOND-HAND]`.

---

## Outline

1. The core loop — tick rate, accumulators, and closed-form production
2. Offline progress — the O(1) problem and the trust problem
3. State architecture — stored vs derived, dirty tracking
4. Multiplier stacking — the genre's real complexity
5. Prestige and reset layers
6. Persistence on Roblox — DataStore limits, session locking, migrations
7. Server/client split — rate replication and the exploit surface
8. Automation and lategame — autobuyers, buy-max, UI at 60 Hz
9. Balance and pacing — cost curves and tuning harnesses
10. Testing an idle game — determinism, fast-forward, golden masters
11. Reference state schema
12. Sources

---

## TL;DR

- **Do not tick per frame, and ideally do not tick at all.** The authoritative
  statement of an idle game's state is *"currency as of timestamp T"*. Everything
  else is a projection. A 60 Hz loop that does `balance += rate * dt` is the single
  most common architectural mistake in the genre: it burns CPU proportional to
  `players × generators × framerate`, it makes the simulation FPS-dependent, and it
  accumulates float error over a long session.
- **Make offline and online the same code path.** Store `lastAdvancedAt`. Any time
  you need a number, call `advanceTo(state, now)`, which integrates production from
  `lastAdvancedAt` to `now` in closed form and moves the timestamp. Offline progress
  then is not a feature — it is what happens when `now - lastAdvancedAt` is 40,000
  seconds instead of 0.2.
- **Closed form, not iteration.** For constant rates, `Δ = r·Δt`. For an
  *n*-tier generator chain (tier *k* produces tier *k−1*) the exact solution is a
  degree-*n* polynomial in `t` with factorial denominators — a nilpotent linear
  system. For an exponentially compounding multiplier, `∫r₀e^{λt} = r₀(e^{λΔt}−1)/λ`.
  Both are given in full below.
- **`os.time()` on the client is attacker-controlled.** Roblox's own docs state the
  value "uses the device's local clock" and that "users can easily disable sync
  behavior and set the system time to anything they want," recommending
  `Workspace:GetServerTimeNow()` for synchronised time. Offline elapsed time is
  computed on the server, from server-side `os.time()`, against a timestamp that
  lives inside the session-locked profile. Clamp it to `[0, cap]` — never trust that
  it is positive.
- **Luau numbers are IEEE-754 doubles**: max ≈ 1.7×10³⁰⁸, ~15 significant digits.
  If your design goes past `1e308` you need a log-space number type
  (`{sign, log10magnitude}`) before you ship, not after. Retrofitting one is a rewrite
  of every formula in the game.
- **Separate stored state from derived state, and version the derived cache.** Stored
  state is a plain, JSON-serialisable table (no `Vector3`, no `Instance`, no mixed
  numeric/string tables, no gaps in arrays, and **no `math.huge` or `NaN`** — those
  will fail serialisation). Multipliers are *recomputed* from an effect registry
  whenever a `dirty` bit is set, never stored.
- **Multiplier stacking is the real complexity of the genre.** Model it as an *effect
  registry*: many sources contribute to one named stat, in typed buckets (`add`,
  `mul`, `pow`), applied in a fixed order, then softcapped, then hardcapped. Build the
  breakdown UI on day one — "why is my number this?" is the top support question in
  every incremental game, including from your own designers.
- **Session locking is mandatory, not optional.** Use **ProfileStore** (the current
  library from the author of ProfileService; single ModuleScript, 300 s autosave,
  40 s session-steal, 630 s dead-server assumption) or **Lapis** (Promise-based,
  first-class `migrations` array, explicit validation). Plain `SetAsync` in an idle
  game is a duplication exploit with extra steps.
- **DataStore budget, verified September 2026:** per-server defaults are
  `StandardRead = 60 + numPlayers × 40` and `StandardWrite = 60 + numPlayers × 40`
  requests/min; experience-wide caps are `300 + CCU × 40` (read) and `300 + CCU × 20`
  (write). `UpdateAsync` **consumes from both read and write budgets**. Per key:
  4 MB max value, 4 MB/min write throughput, 25 MB/min read throughput, 50-character
  key names.
- **Do not compress your save yourself.** Roblox's documentation is explicit:
  "Data stores automatically compress your data before storage, so avoid
  pre-compressing it yourself. Pre-compression adds unnecessary CPU overhead and may
  reduce the effectiveness of data stores' built-in compression." Shrink the *schema*
  (short keys, arrays instead of dictionaries, omit defaults) instead.
- **Never replicate the balance every tick.** Replicate the *generating function*:
  `{t0, value0, ratePolynomial}`. The client evaluates it at render rate and gets a
  smooth number for free; the server pushes a correction only when the shape changes
  (a purchase, a prestige, a buff expiring) or on a slow keepalive.
- **Buy-max must be closed form.** For geometric costs `c(n) = b·rⁿ`, the number
  affordable is `k = ⌊ log(1 + M(r−1)/(b·r^owned)) / log r ⌋`. Looping is O(k) and
  `k` reaches millions in the lategame. For curve shapes with no inverse, binary
  search in log space — O(log k), still fine.
- **Balance with a metric, not a feeling.** Track *time-to-next-purchase*
  `T(n) = cost(n)/production(n)` across the whole progression and plot it on a log
  axis. A healthy incremental has `T(n)` gently rising within a layer and resetting
  downward at each prestige. Spikes are where players quit.
- **Test by fast-forwarding.** Inject the clock, run 10,000 simulated hours in
  milliseconds, and golden-master the progression (time to reach each milestone).
  Property-test the multiplier system: order-independence within a bucket,
  monotonicity, and buy-max agreement against a brute-force loop at small scale.

---

## 1. The core loop

### 1.1 Why an idle game should not tick per frame

Roblox gives you four per-frame server hooks. The documented ordering is
`PreAnimation → PreSimulation (was Stepped) → [physics] → PostSimulation →
Heartbeat`, and the docs describe `Heartbeat` as firing "every frame, after the
physics simulation has completed… This event is when most scripts run."

None of them is where an idle game's economy belongs, for four reasons:

1. **Cost scales with the wrong thing.** Production work per second is
   `players × generators × framerate`. A 30-player server with 24 generator types
   at 60 Hz is 43,200 generator updates per second, each of which in a naive
   implementation touches a table, multiplies a few numbers and possibly rebuilds a
   cached multiplier. That is a measurable fraction of a server's script budget to
   compute a value that nobody reads more than ten times a second.
2. **The simulation becomes frame-rate dependent.** `Heartbeat`'s `deltaTime`
   varies; `PreSimulation`/`PostSimulation` pass `deltaTimeSim`, which the docs warn
   "may deviate from the actual time between frames in Studio edit mode or when
   framerate is very low." A server that drops to 20 Hz under load must produce
   exactly the same economy as one at 60 Hz, or your balance changes with your
   player count.
3. **Float error accumulates.** `balance += rate * dt` executed 60 times a second
   for a four-hour session is 864,000 additions. With `balance` at 1e20 and
   `rate*dt` at 1e5, every one of those additions is silently discarding the
   addend entirely — `1e20 + 1e5 == 1e20` in double precision. The player watches
   a rate of 1e5/s and their balance does not move. This bug is real, it is common,
   and closed-form integration over a longer interval fixes it for free.
4. **You need the closed form anyway.** Offline progress forces you to write
   "production over an arbitrary elapsed time" as a function. Once you have it, the
   per-frame loop is redundant.

### 1.2 The timestamp model

Replace "tick the economy" with "advance the economy to a timestamp".

```lua
--!strict
-- ServerScriptService/Economy/Advance.luau

export type Ledger = {
    lastAdvancedAt: number,   -- server os.time(), seconds
    balances: { [string]: number },
}

-- The single entry point. Every read of a balance goes through this first.
local function advanceTo(ledger: Ledger, now: number, rates: { [string]: number })
    local dt = now - ledger.lastAdvancedAt
    if dt <= 0 then
        -- Clock went backwards (NTP correction, DST bug, tampering). Re-anchor,
        -- grant nothing. Never allow a negative grant.
        ledger.lastAdvancedAt = now
        return
    end
    for currency, rate in rates do
        ledger.balances[currency] = (ledger.balances[currency] or 0) + rate * dt
    end
    ledger.lastAdvancedAt = now
end
```

Every mutation of the economy — a purchase, a prestige, an offline return, a UI
query, an autosave — begins with `advanceTo(ledger, os.time(), currentRates())`.
The invariant is: *balances are exact as of `lastAdvancedAt`, and `lastAdvancedAt`
is never in the future.*

This single decision collapses three features (online production, offline
production, catch-up after a server hitch) into one function, and it is the
reason the rest of this chapter is short.

### 1.3 The heartbeat you *do* want: a fixed-rate scheduler

You still want a periodic job — not to produce currency, but to (a) push a
replication snapshot, (b) fire threshold events ("you can now afford X"),
(c) run autobuyers, and (d) drive autosave. Run it on a **fixed timestep with an
accumulator**, decoupled from the render rate:

```lua
--!strict
local RunService = game:GetService("RunService")

local TICK_HZ = 4
local TICK_DT = 1 / TICK_HZ
local MAX_CATCHUP_TICKS = 5   -- spiral-of-death guard

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime: number)
    accumulator += deltaTime
    local ticks = 0
    while accumulator >= TICK_DT and ticks < MAX_CATCHUP_TICKS do
        accumulator -= TICK_DT
        ticks += 1
        Economy.step(TICK_DT)   -- exactly TICK_DT, always
    end
    if ticks == MAX_CATCHUP_TICKS then
        -- We fell far behind (server hitch). Drop the backlog rather than
        -- spending the next frame catching up and hitching again.
        accumulator = 0
    end
end)
```

Three properties matter here:

- **`Economy.step` always receives `TICK_DT`.** Fixed timestep means the simulation
  is reproducible and testable: `step` called *n* times is exactly *n · TICK_DT* of
  game time, on any machine, at any frame rate. (This is what makes §10's
  fast-forward tests possible.)
- **The catch-up loop is bounded.** Without `MAX_CATCHUP_TICKS`, a single 3-second
  server hitch queues 12 ticks, which take longer than a frame, which queues more —
  the classic spiral of death. Because the economy is timestamp-driven, dropping
  backlog ticks costs you nothing: the next `advanceTo` integrates the whole gap.
- **`Heartbeat`, not `PreSimulation`.** You want the post-physics, "most scripts run
  here" phase. `deltaTime` on `Heartbeat` is real elapsed frame time, which is what
  an accumulator wants; `deltaTimeSim` is not.

For in-session elapsed time prefer `os.clock()` — the docs describe it as
"elapsed time in seconds since an arbitrary baseline with sub-microsecond
precision" and note that, "unlike with functions such as `os.time()` or
`DateTime.now()`, adjustments to the system clock (such as by the user or NTP) do
not cause time to jump forwards or backwards." Use `os.time()` only for the
persisted wall-clock anchor that offline progress needs (§2).

### 1.4 Closed-form production: constant rate

The trivial case, stated precisely so the next two generalise from it. If
production rate `r` is constant over `[t₀, t₁]`:

```
ΔC = r · (t₁ − t₀)
```

O(1) for any elapsed time, from one second to one year. Almost all idle games on
Roblox never need more than this, because the rate only changes at discrete
events (purchase, prestige, buff start/end) and you can simply `advanceTo` at
every such event. **Piecewise-constant integration is closed-form integration.**

### 1.5 Closed-form production: generator chains

The genre-defining structure — Antimatter Dimensions, Cookie Clicker's
grandmapocalypse tiers, every "Tier 2 produces Tier 1" design — is a chain where
tier *k* produces tier *k−1*. Let `x_k(t)` be the count of tier *k* and `m_k` be
tier *k*'s per-unit production multiplier into tier *k−1*:

```
dx_k/dt = m_k · x_{k+1}(t)
```

This is a linear system with a strictly upper-triangular (nilpotent) matrix, so
the solution is a **finite polynomial**, not an exponential:

```
                n−k                    ⎛ j−1        ⎞   t^j
x_k(t)  =  Σ         x_{k+j}(0)  ·     ⎜ Π  m_{k+i} ⎟ · ───
                j=0                    ⎝ i=0        ⎠    j!
```

In words: each higher tier contributes to tier *k* with one extra power of *t* and
one extra factorial. Tier 8 reaches your currency as a `t⁸/8!` term. This is exact
for any `t`, evaluated in O(n²) for the whole chain regardless of whether `t` is one
second or ten days.

```lua
--!strict
-- Exact closed-form advance for a nilpotent generator chain.
-- counts[1] is the currency being produced; counts[k+1] produces counts[k].
-- mults[k] is tier k's production multiplier into tier k-1 (per second, per unit).
local function advanceChain(counts: { number }, mults: { number }, t: number): { number }
    local n = #counts
    local out = table.create(n)

    for k = 1, n do
        local sum = counts[k]
        local coefficient = 1      -- Π m, running product
        local tPower = 1           -- t^j
        local factorial = 1        -- j!

        for j = 1, n - k do
            coefficient *= mults[k + j - 1]
            tPower *= t
            factorial *= j
            sum += counts[k + j] * coefficient * tPower / factorial
        end

        out[k] = sum
    end

    return out
end
```

**Numerical warning.** `tPower` overflows to `math.huge` well before `factorial`
catches it: at `t = 86400` (one day), `t⁸ ≈ 3.1e39`, which is fine, but at
`t = 8.6e6` (100 days) `t⁸ ≈ 3e55` and `8! = 40320`, so the term is ~7e50 times
the tier-8 count. With ten tiers and a long absence you will overflow. The fix is
to evaluate the term in log space and only exponentiate at the end:

```lua
-- log10 of the j-th term, for stability at extreme t.
local function logTerm(logCount: number, logCoefficient: number, t: number, j: number): number
    -- log10(count · coeff · t^j / j!)
    local logFactorial = 0
    for i = 2, j do
        logFactorial += math.log10(i)
    end
    return logCount + logCoefficient + j * math.log10(t) - logFactorial
end
```

If any `logTerm` exceeds ~307 you have left the representable range of a double
and need a log-space number type for real (§1.8).

### 1.6 Closed-form production: compounding multipliers

The other common shape is a multiplier that itself grows with time — "your
production increases by 2% per second while the buff is active", or a permanent
"time played" bonus.

**Exponential compounding.** Rate `r(t) = r₀ · e^{λt}` where
`λ = ln(1 + p)` for a per-second fractional growth `p`:

```
        Δt                    r₀ (e^{λΔt} − 1)
ΔC = ∫     r₀ e^{λt} dt   =   ────────────────
        0                            λ
```

```lua
--!strict
-- Total production over dt when the rate compounds exponentially.
-- growthPerSecond = 0.02 means "+2% per second, compounding".
local function integrateCompounding(rate0: number, growthPerSecond: number, dt: number): number
    if growthPerSecond == 0 then
        return rate0 * dt
    end
    local lambda = math.log(1 + growthPerSecond)
    -- Guard: for tiny lambda, (e^(λ·dt) − 1)/λ loses catastrophic precision.
    -- Fall back to the series expansion dt·(1 + λ·dt/2 + (λ·dt)²/6 + …).
    local x = lambda * dt
    if math.abs(x) < 1e-6 then
        return rate0 * dt * (1 + x / 2 + x * x / 6)
    end
    return rate0 * (math.exp(x) - 1) / lambda
end
```

The `1e-6` guard matters. Luau has no `math.expm1`; `math.exp(1e-9) - 1` evaluates
to roughly `1.000000082740371e-9` instead of `1e-9`, an 8e-8 relative error that
becomes visible when `dt` is large. The three-term series is exact to double
precision in that regime.

**Polynomial compounding.** Rate `r(t) = r₀·(1 + a·t)^p` (a "your bonus grows with
the square root of time online" bonus, `p = 0.5`):

```
        Δt                          r₀ [ (1 + a·Δt)^{p+1} − 1 ]
ΔC = ∫     r₀ (1 + a t)^p dt   =    ──────────────────────────
        0                                   a (p + 1)
```

with the `p = −1` case degenerating to `r₀·ln(1 + a·Δt)/a`.

```lua
local function integratePolynomial(rate0: number, a: number, p: number, dt: number): number
    if a == 0 then
        return rate0 * dt
    elseif p == -1 then
        return rate0 * math.log(1 + a * dt) / a
    end
    return rate0 * ((1 + a * dt) ^ (p + 1) - 1) / (a * (p + 1))
end
```

### 1.7 Piecewise integration when the closed form breaks

The closed form is exact only while the *shape* of the rate function is constant.
Three things break it, and each has a standard answer:

| What breaks it | Answer |
|---|---|
| A timed buff expires mid-interval | Split the interval at the expiry timestamp and integrate each piece. Keep a sorted list of "scheduled rate changes"; a return from 3 days offline typically has fewer than 10. |
| An offline autobuyer would have fired | See §8.2. Either disable autobuyers offline (most common, and defensible), or run a **bounded** number of log-spaced simulation chunks (64–256) and accept an approximation. |
| A softcap is crossed mid-interval | Solve for the crossing time analytically if the cap is invertible; otherwise bisect on the crossing time (~40 iterations for full double precision) and split there. |

The general pattern:

```lua
--!strict
-- Integrate across a set of scheduled breakpoints in O(breakpoints).
local function advanceWithBreakpoints(ledger, now: number, schedule: { number })
    local cursor = ledger.lastAdvancedAt
    table.sort(schedule)
    for _, boundary in schedule do
        if boundary > cursor and boundary < now then
            applyClosedForm(ledger, cursor, boundary)
            cursor = boundary
            recomputeRates(ledger)      -- the shape changed here
        end
    end
    applyClosedForm(ledger, cursor, now)
    ledger.lastAdvancedAt = now
end
```

### 1.8 When doubles run out

Luau's `number` is "a double-precision (64-bit) floating-point number… from
-1.7 × 10³⁰⁸ to 1.7 × 10³⁰⁸ (around 15 digits of precision)". Three consequences
for this genre:

- **15 significant digits.** Once a balance exceeds ~1e16, adding small values to it
  is a no-op. This is fine — at that scale nobody cares about the ones digit — but it
  means you cannot use a running balance as a ledger of exact small transactions.
- **1e308 is a hard wall.** Beyond it every value is `math.huge`, every comparison
  degenerates, and `inf - inf = nan`. A `nan` balance propagates through every
  formula and, critically, **cannot be JSON-encoded**, so it will also break your
  save. Luau ships `math.isfinite`, `math.isnan` and `math.isinf` — assert
  `math.isfinite(x)` at the boundary of your economy module in Studio builds.
- **If your design targets 1e1000+, adopt a log-space number type before launch.**
  The standard representation across the genre is `{sign, log10magnitude}` (or
  `{mantissa, exponent}`): multiplication becomes addition, exponentiation becomes
  multiplication, and only addition needs care. `Bnum` is a current Luau
  implementation using exactly this
  (`Value = sign × 10^logMagnitude`, `--!native`, `--!optimize 2`), in the same
  lineage as `break_infinity.js` in the web incremental scene.
  `[COMMUNITY, SECOND-HAND]` — I have not benchmarked it; evaluate before adopting.

A log-space type is contagious: every cost curve, every multiplier, every
comparison, every UI format function changes. Decide in week one.

---

## 2. Offline progress

Offline progress is the genre's defining feature and, on Roblox specifically, its
most exploitable one. Get three things right: it must be O(1), it must be
server-authoritative, and it must be idempotent.

### 2.1 The recommended architecture: there is no offline progress

The single best decision you can make is to **not implement offline progress as a
feature**. Implement §1.2's `advanceTo(state, now)` and let offline progress be an
emergent consequence of a large `now - lastAdvancedAt`.

```lua
--!strict
-- ServerScriptService/Economy/Session.luau
local Players = game:GetService("Players")

local OFFLINE_CAP_SECONDS = 12 * 3600      -- design decision, see §2.4
local OFFLINE_EFFICIENCY  = 0.5            -- offline earns 50% of online rate
local MIN_OFFLINE_SECONDS = 60             -- below this, no "welcome back" popup

type OfflineReport = {
    elapsedRaw: number,          -- true wall-clock seconds away
    elapsedCredited: number,     -- after clamping to the cap
    wasCapped: boolean,
    gains: { [string]: number },
}

local function resumeSession(state, now: number): OfflineReport?
    local elapsedRaw = now - state.meta.lastAdvancedAt

    -- Defensive clamp. elapsedRaw can be negative if the profile was written by a
    -- server whose clock was ahead, or if a save from the future was restored.
    if elapsedRaw < 0 then
        state.meta.lastAdvancedAt = now
        state.meta.clockAnomalies += 1     -- log it; investigate if it trends up
        return nil
    end

    local credited = math.min(elapsedRaw, OFFLINE_CAP_SECONDS)

    local before = table.clone(state.balances)
    -- Exactly the same integrator used online, with an efficiency factor folded
    -- into the rates. No second code path.
    Economy.integrate(state, credited, OFFLINE_EFFICIENCY)
    state.meta.lastAdvancedAt = now

    if elapsedRaw < MIN_OFFLINE_SECONDS then
        return nil
    end

    local gains = {}
    for currency, after in state.balances do
        local delta = after - (before[currency] or 0)
        if delta > 0 then
            gains[currency] = delta
        end
    end

    return {
        elapsedRaw = elapsedRaw,
        elapsedCredited = credited,
        wasCapped = elapsedRaw > OFFLINE_CAP_SECONDS,
        gains = gains,
    }
end
```

Note what is *not* here: no separate "offline simulation" function, no loop over
hours, no special-casing. `Economy.integrate` is §1.4–1.6's closed form. A
three-week absence costs exactly the same CPU as a three-second one.

### 2.2 The O(1) requirement, concretely

A player returning after 30 days is 2,592,000 seconds. At a 4 Hz tick that is
10.4 million iterations. Even at an optimistic 20 ns per iteration that is 0.2 s of
server time — *per returning player*, on the join path, while `ProfileStore` is
holding a session lock and the player is staring at a loading screen. On a server
that just restarted after an update, 30 players do this simultaneously.

Closed form makes this ~2 µs. There is no argument for simulating.

The failure mode people reach for instead — "simulate in coarse buckets of one
hour" — is worse than it looks: it is still O(hours), it is *not* the same numbers
the online path produces (so your golden-master tests diverge), and it introduces
a second implementation of every multiplier. Don't.

### 2.3 Closed form for the standard growth curves

Reusing §1: for each currency, offline gain over `Δt` is whichever of these
matches your design.

| Production shape | Offline gain over Δt | Notes |
|---|---|---|
| Constant rate `r` | `r · Δt` | The overwhelming majority of Roblox idle games. |
| Tiered chain, *n* tiers | `Σⱼ x_{k+j}(0) · (Π m) · Δtʲ / j!` | §1.5. Exact; O(n²). Watch overflow past ~1e308. |
| Exponential compounding `r₀e^{λt}` | `r₀(e^{λΔt} − 1)/λ` | §1.6. Use the series fallback for small `λΔt`. |
| Polynomial `r₀(1+at)^p` | `r₀[(1+aΔt)^{p+1} − 1] / (a(p+1)) ` | `p = −1` → `r₀ ln(1+aΔt)/a`. |
| Capacity-limited (storage fills) | `min(r · Δt, capacity − current)` | Classic "your barn is full" design; O(1) and self-capping. |
| Logistic / saturating `r·C/(1+ke^{−λt})` | `(rC/λ)·ln((1+ke^{−λt₀})/(1+ke^{−λt₁}))` | Rare, but the closed form exists. `[UNVERIFIED]` — derived here, verify numerically before shipping. |

**The capacity-limited shape deserves a mention**, because it is the cleanest way
to bound offline progress without a visible timer: give every generator a storage
capacity, have offline production fill storage, and require the player to collect.
The cap emerges from the design rather than from a rule, players understand it
immediately, and it gives them a reason to come back on a schedule.

### 2.4 Capping, efficiency, and the design of "away time"

Three separate knobs, frequently conflated:

- **Hard cap** (`OFFLINE_CAP_SECONDS`): the maximum credited elapsed time.
  Typical Roblox values are 2–12 hours at launch, extended by gamepass to 24 h.
- **Efficiency** (`OFFLINE_EFFICIENCY`): offline rate as a fraction of online rate.
  Typical 25–100%. Below ~25% players feel punished for sleeping.
- **Curve on the elapsed time itself**: instead of a hard cliff, credit
  `f(Δt) = cap · (1 − e^{−Δt/τ})` so returns diminish smoothly and there is no
  "I logged in 20 minutes too late" cliff. `[COMMUNITY, SECOND-HAND]` — this is a
  design pattern, not a documented API.

Two anti-patterns worth naming:

- **Selling the cap and the efficiency as separate products.** Players read this as
  two paywalls on the same feature.
- **Making the cap a hard cliff with no in-game display.** If the cap is 8 h, show a
  filling meter with the time remaining. Otherwise the player's mental model is
  "offline earns nothing after a while" and they stop caring.

### 2.5 Clock-tampering resistance

Roblox's documentation for `os.time()` is unusually explicit, and it is the
security argument in one paragraph:

> "Note that the returned time uses the device's local clock. Most operating
> systems automatically sync their local time against online time servers, so this
> should be within a few hundred milliseconds. **However, users can easily disable
> sync behavior and set the system time to anything they want**; for synchronized
> time between client and server, use `Workspace:GetServerTimeNow()` instead."

And `Workspace:GetServerTimeNow()` itself carries a warning that matters here:

> "…this method is not suitable for things like timed rewards, as it is not
> secure."

Put together, the rules are:

1. **The offline timestamp is written and read on the server only.** It lives in the
   session-locked profile (`state.meta.lastAdvancedAt`), never in an attribute, never
   in a `RemoteEvent` argument, never in `player:SetAttribute`.
2. **The server uses server-side `os.time()`.** A Roblox game server's clock is
   Roblox's machine, not the player's. It is not perfect — servers can drift — but it
   is not attacker-controlled. `[INFERENCE]` — the docs do not state a server clock
   accuracy guarantee.
3. **`GetServerTimeNow()` is for display only.** It is a *client's approximation* of
   server time, documented as monotonic and rate-accurate to 0.6%, and explicitly
   labelled not secure. Use it to animate a countdown; never to decide a grant.
4. **Clamp elapsed to `[0, cap]` before doing anything with it.** Negative elapsed is
   not an exception to handle, it is a number to floor at zero. Count the occurrences
   and alert if the rate rises — that is your tamper signal.
5. **`DateTime` for anything human-facing.** `DateTime.fromUnixTimestamp(t)` plus
   `:FormatLocalTime(...)` renders "you were away since Tuesday 9:14 PM" in the
   player's own locale without you doing timezone arithmetic.

### 2.6 Idempotency: the rejoin-farm exploit

The attack: join, get the offline grant, leave immediately, rejoin. If the grant is
computed from a timestamp that was not persisted *before* the grant, or if two
servers can hold the profile at once, the player farms the same interval repeatedly.

Two defences, both required:

- **Session locking** (§6.3) makes "two servers at once" impossible.
- **Advance-then-persist ordering** makes a crash-during-grant safe. Because
  `lastAdvancedAt` is moved to `now` *in the same table mutation* as the balance
  increase, any save — autosave, save-on-leave, `BindToClose` — writes both or
  neither. There is no window where the balance went up but the timestamp did not.

```lua
-- CORRECT: one mutation, atomically persisted together.
state.balances.coins += gain
state.meta.lastAdvancedAt = now

-- WRONG: two calls, with a yield between them, is a duplication bug.
grantCoins(player, gain)         -- fires a remote, yields
saveTimestamp(player, now)       -- may never run if the player leaves here
```

A third, cheap belt-and-braces measure is a monotonic guard:

```lua
if now <= state.meta.lastAdvancedAt then
    return nil  -- already credited through this instant
end
```

### 2.7 The welcome-back summary

The report is a UI problem, but it is also a retention feature — it is the first
thing a returning player sees and the moment where they decide whether the session
was worth opening. What works:

- **Lead with time, not the number.** "You were away 7 h 12 m" anchors the
  expectation before the number lands.
- **Itemise by source when there are multiple currencies**, one row each, with the
  generator that produced the most called out. Aggregate everything below 1% into
  "other".
- **Show the cap honestly.** If they were away 40 hours and the cap is 12, say
  "credited 12 h (maximum)" with a clear upsell, not a silently smaller number.
  Players compute the rate and notice.
- **Make the button grant, not dismiss.** Deferring the credit until the player taps
  "Collect" costs you nothing and gives the moment weight. (If you do this, the
  balance change must still be committed server-side at load; the button reveals a
  grant that already happened, it does not authorise it.)
- **Suppress it below a threshold.** `MIN_OFFLINE_SECONDS` above. A popup for
  45 seconds of earnings is noise.

```lua
--!strict
-- Formatting the elapsed time. DateTime handles the locale; this handles the span.
local function formatSpan(seconds: number): string
    local d = math.floor(seconds / 86400)
    local h = math.floor(seconds % 86400 / 3600)
    local m = math.floor(seconds % 3600 / 60)
    if d > 0 then
        return string.format("%dd %dh", d, h)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm", math.max(m, 1))
end
```

---
