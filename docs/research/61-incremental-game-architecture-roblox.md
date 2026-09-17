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

## 3. State architecture

### 3.1 The canonical shape

An idle game's persisted state has a shape that barely varies between titles. Write
it down as a type on day one, because every system in the game reads it.

```lua
--!strict
-- ReplicatedStorage/Shared/Schema.luau
-- The ONLY thing that is persisted. Plain data. No metatables, no Instances.

export type GeneratorState = {
    count: number,        -- how many owned
    level: number,        -- per-generator upgrade level
    unlocked: boolean,
}

export type PlayerState = {
    -- Version first, always. See §6.5.
    schema: number,

    meta: {
        firstJoinAt: number,       -- os.time()
        lastAdvancedAt: number,    -- the offline anchor, §2
        sessionCount: number,
        totalPlaytime: number,     -- seconds
        clockAnomalies: number,
    },

    -- Currencies: a flat map. Never nest currency under the thing that produces it.
    balances: { [string]: number },

    -- Lifetime totals, needed by prestige formulas and achievements.
    earned: { [string]: number },

    generators: { [string]: GeneratorState },

    -- Upgrades are a set, not a list: O(1) lookup, and order-independent saves.
    upgrades: { [string]: true },

    -- Prestige layers, keyed by layer id. See §5.
    prestige: {
        [string]: {
            currency: number,
            lifetime: number,
            resets: number,
            lastResetAt: number,
            upgrades: { [string]: true },
        }
    },

    achievements: { [string]: number },   -- id -> completion timestamp

    settings: {
        notation: string,      -- "standard" | "scientific" | "engineering"
        reducedMotion: boolean,
        autobuyEnabled: boolean,
        confirmPrestige: boolean,
    },

    -- Anything that must survive a prestige but isn't a prestige currency.
    permanent: { [string]: number },
}
```

Design notes that are load-bearing:

- **`schema` is the first field and it is a number.** §6.5 depends on it.
- **`upgrades` is a set (`{[string]: true}`), not an array.** Arrays serialise fine
  but make "do I own X?" O(n) and make diffs order-dependent. Sets also merge
  cleanly across migrations.
- **`earned` is separate from `balances`.** Prestige formulas are almost always
  functions of *lifetime earned*, not current balance, so that spending doesn't
  reduce your prestige gain. Forgetting this is a design bug that surfaces after
  launch and is painful to retrofit.
- **`prestige` is keyed by layer id, not a flat set of fields.** Adding layer 3 is
  adding a key, not rewriting the schema (§5.4).
- **`permanent` is an explicit escape hatch.** Every idle game eventually has "this
  thing survives everything"; give it a home before it starts leaking into
  `settings`.

### 3.2 Serialisation constraints you must design around

The save is a plain table that goes through Roblox's serialiser. ProfileStore's
header states the constraints bluntly, and they apply to any DataStore value:

> - Do not create numeric tables with gaps — attempting to store such tables will
>   result in an error.
> - Do not create mixed tables (some values indexed by number and others by a string
>   key) — only numerically indexed data will be stored.
> - Do not index tables by anything other than numbers and strings.
> - Do not reference Roblox Instances.
> - Do not reference userdata (Vector3, Color3, CFrame…) — serialize userdata before
>   referencing.
> - Do not reference functions.

Add two of your own:

- **No `nan`, no `±math.huge`.** They are not representable in JSON, and a `nan`
  that reaches the save turns a recoverable balance bug into an unloadable profile.
  `[UNVERIFIED]` — the `HttpService:JSONEncode` documentation does not specify
  behaviour for non-finite numbers; test it in your own build. Regardless, validate
  with `math.isfinite` before saving and you never have to find out.
- **No `nil` holes in what you think is a dictionary.** Setting `upgrades.x = nil`
  removes the key, which is correct; setting `generators[3] = nil` in an array is
  the "gaps" error above.

A save-time validator is ten lines and pays for itself the first week:

```lua
--!strict
local MAX_DEPTH = 8

local function validate(value: any, path: string, depth: number): (boolean, string?)
    if depth > MAX_DEPTH then
        return false, `{path}: exceeds max depth`
    end
    local t = typeof(value)
    if t == "number" then
        if not math.isfinite(value) then
            return false, `{path}: non-finite number ({value})`
        end
    elseif t == "boolean" or t == "string" then
        -- fine
    elseif t == "table" then
        local sawArray, sawHash = false, false
        for k, v in value do
            local kt = typeof(k)
            if kt == "number" then sawArray = true
            elseif kt == "string" then sawHash = true
            else return false, `{path}: key of type {kt}` end
            local ok, err = validate(v, `{path}.{tostring(k)}`, depth + 1)
            if not ok then return false, err end
        end
        if sawArray and sawHash then
            return false, `{path}: mixed array/hash table`
        end
    else
        return false, `{path}: unserialisable type {t}`
    end
    return true
end
```

Run it in Studio and on a sampled fraction of live saves. Never let it *block* a
live save — log loudly and save anyway, because refusing to save is worse than
saving something slightly wrong.

### 3.3 Stored vs derived: the most important split

Stored state is small and boring. Derived state is large, expensive and entirely a
function of stored state:

| Stored | Derived |
|---|---|
| `generators.miner.count = 1200` | `miner.productionPerSecond` |
| `upgrades.doubleOre = true` | `multipliers.ore.total` |
| `prestige.rebirth.currency = 40` | `prestige.rebirth.gainOnReset` |
| `balances.ore = 3.2e14` | `nextAffordableAt` (a timestamp) |
| `earned.ore = 9.1e14` | every number the UI displays |

**Derived state is never saved and never trusted across a mutation.** It is a cache
keyed by a version counter.

```lua
--!strict
-- ReplicatedStorage/Shared/Derived.luau

export type Cache = {
    version: number,               -- bumped on every stored-state mutation
    computedAtVersion: number,     -- version the cache was built from
    multipliers: { [string]: number },
    rates: { [string]: number },
    breakdown: { [string]: any },  -- §4.5
}

local Derived = {}

function Derived.invalidate(cache: Cache)
    cache.version += 1
end

function Derived.get(state, cache: Cache): Cache
    if cache.computedAtVersion == cache.version then
        return cache                        -- hit
    end
    Derived.recompute(state, cache)         -- miss: rebuild everything
    cache.computedAtVersion = cache.version
    return cache
end
```

This is deliberately the *coarsest possible* dirty system: one counter, full
rebuild. Resist the urge to do fine-grained per-stat invalidation until you have
profiled and found it matters. Reasons:

- A full rebuild for a typical Roblox idle game (30 generators, 200 upgrades, 4
  prestige layers) is a few hundred multiplications — tens of microseconds.
- Mutations are *rare*: a purchase, a prestige, a buff change. Not per frame.
- Fine-grained invalidation is where correctness bugs live. A stale multiplier that
  only appears when you buy upgrade B after upgrade A is the single hardest class of
  bug in this genre, and the coarse version cannot have it.

If you do need finer granularity later, the shape that scales is a dependency
graph: each stat declares the stats it reads, invalidating a stat marks its
dependents dirty, and `get(stat)` recomputes lazily. Build it *behind the same
`Derived.get` API* so the swap is local.

### 3.4 Where derived state lives

Two caches, not one:

- **Server cache**, authoritative, rebuilt on mutation. Used to compute grants,
  validate purchases, and produce the replication snapshot.
- **Client cache**, a mirror, rebuilt from replicated stored state using *the exact
  same module*. Shared code in `ReplicatedStorage` means the client can predict a
  purchase's effect instantly and the numbers always agree.

The rule that keeps this honest: **the client's derived values are only ever used
for display and prediction; the server recomputes independently and its answer
wins.** Shipping the same code to both sides is a UX optimisation, never a trust
decision (§7.3).

---

## 4. Multiplier stacking

This is where incremental games actually get hard. By month six you will have 300
upgrades, and forty of them will touch "ore production". If each one is a hand-written
`if state.upgrades.x then production *= 2 end`, the system is unreadable, untestable
and undebuggable, and nobody — including you — will be able to answer "why is this
number 4.7e12?"

### 4.1 The three kinds of source, and why the distinction matters

| Kind | Combines as | Player-facing name | Effect of adding one more |
|---|---|---|---|
| **flat** | `Σ vᵢ`, added to the base | "+5 ore/sec" | Constant. Dominant early, irrelevant late. |
| **add** (additive multiplier) | `1 + Σ vᵢ` | "+50% ore" | *Diminishing.* The tenth +50% takes you from 5.0× to 5.5×: a 10% gain. |
| **mul** (multiplicative) | `Π (1 + vᵢ)` or `Π vᵢ` | "×2 ore" | *Constant proportional.* Every ×2 doubles, forever. |
| **pow** (exponential) | `v ^ (Π pᵢ)` | "ore^1.05" | *Explosive.* Applies to the exponent, so it compounds with everything. |

The design lesson embedded in that table: **additive sources self-balance and
multiplicative ones do not.** Path of Exile's "increased" vs "more" distinction is
the same idea. Put the bulk of your upgrade count in the `add` bucket, reserve `mul`
for milestone rewards, and reserve `pow` for late prestige layers where you *want*
the curve to bend upward.

### 4.2 The order of application

Fix it once, write it down, and never let a feature negotiate it:

```
   1. base          = declared base value for the stat
   2. + Σ flat      = base + flat contributions
   3. × (1 + Σ add) = additive percentage bucket
   4. × Π mul       = multiplicative bucket
   5. ^ Π pow       = exponential bucket
   6. softcap(...)  = smooth compression above a threshold
   7. clamp(min,max)= hard floor/ceiling
```

Steps 3 and 4 commute with each other in the sense that multiplication is
commutative — but *which bucket a source lands in* changes the result enormously,
which is exactly why the buckets must be declared, not inferred.

### 4.3 A concrete effect registry

```lua
--!strict
-- ReplicatedStorage/Shared/Effects.luau

export type Kind = "flat" | "add" | "mul" | "pow"

export type Effect = {
    id: string,                 -- unique; also the breakdown label key
    stat: string,               -- e.g. "production.miner", "cost.all", "offline.cap"
    kind: Kind,
    -- Value is a function of state so that scaling upgrades ("+1% per rebirth")
    -- and conditional upgrades are the same mechanism.
    value: (state: any) -> number,
    -- nil means "always active".
    active: ((state: any) -> boolean)?,
    -- Free-form; shown in the breakdown UI.
    label: string,
}

local Effects = {}
local registry: { [string]: { Effect } } = {}   -- stat -> effects

function Effects.register(effect: Effect)
    local list = registry[effect.stat]
    if not list then
        list = {}
        registry[effect.stat] = list
    end
    table.insert(list, effect)
end

export type Breakdown = {
    base: number,
    flat: { { label: string, value: number } },
    add: { { label: string, value: number } },
    mul: { { label: string, value: number } },
    pow: { { label: string, value: number } },
    afterFlat: number,
    afterAdd: number,
    afterMul: number,
    afterPow: number,
    afterSoftcap: number,
    final: number,
}

export type Softcap = ((x: number) -> number)?

function Effects.evaluate(
    stat: string,
    base: number,
    state: any,
    softcap: Softcap,
    minValue: number?,
    maxValue: number?
): (number, Breakdown)

    local bd: Breakdown = {
        base = base,
        flat = {}, add = {}, mul = {}, pow = {},
        afterFlat = base, afterAdd = base, afterMul = base,
        afterPow = base, afterSoftcap = base, final = base,
    }

    local sumFlat, sumAdd, prodMul, prodPow = 0, 0, 1, 1

    for _, effect in registry[stat] or {} do
        if effect.active and not effect.active(state) then
            continue
        end
        local v = effect.value(state)
        if not math.isfinite(v) then
            warn(`[Effects] {effect.id} produced non-finite value; skipping`)
            continue
        end
        if effect.kind == "flat" then
            sumFlat += v
            table.insert(bd.flat, { label = effect.label, value = v })
        elseif effect.kind == "add" then
            sumAdd += v
            table.insert(bd.add, { label = effect.label, value = v })
        elseif effect.kind == "mul" then
            prodMul *= v
            table.insert(bd.mul, { label = effect.label, value = v })
        elseif effect.kind == "pow" then
            prodPow *= v
            table.insert(bd.pow, { label = effect.label, value = v })
        end
    end

    local x = base + sumFlat
    bd.afterFlat = x

    x *= (1 + sumAdd)
    bd.afterAdd = x

    x *= prodMul
    bd.afterMul = x

    if prodPow ~= 1 and x > 0 then
        x = x ^ prodPow
    end
    bd.afterPow = x

    if softcap then
        x = softcap(x)
    end
    bd.afterSoftcap = x

    if minValue then x = math.max(x, minValue) end
    if maxValue then x = math.min(x, maxValue) end
    bd.final = x

    return x, bd
end

return Effects
```

Registering an upgrade is then declarative, lives next to the upgrade's definition,
and is the *only* place that upgrade touches the economy:

```lua
Effects.register({
    id = "upg_sharper_picks",
    stat = "production.miner",
    kind = "add",
    label = "Sharper Picks",
    value = function(state) return 0.25 end,
    active = function(state) return state.upgrades.sharperPicks == true end,
})

Effects.register({
    id = "rebirth_scaling",
    stat = "production.all",
    kind = "mul",
    label = "Rebirths",
    -- Scaling effects are the same mechanism, not a special case.
    value = function(state) return 1 + 0.10 * state.prestige.rebirth.currency end,
})

Effects.register({
    id = "ascension_exponent",
    stat = "production.all",
    kind = "pow",
    label = "Ascension",
    value = function(state) return 1 + 0.002 * state.prestige.ascend.currency end,
    active = function(state) return state.prestige.ascend.resets > 0 end,
})
```

### 4.4 Softcaps and hardcaps

A **hardcap** is `math.min(x, cap)`. Use it sparingly: it is a wall players see and
resent, and it makes every upgrade past the cap worthless, which is worse than
making it weak.

A **softcap** compresses growth above a threshold while keeping progress monotonic.
Three standard shapes:

```lua
--!strict
-- Polynomial softcap: above `threshold`, growth exponent drops to `power`.
-- The workhorse. Continuous, monotonic, and easy to reason about in log space:
-- log(y) = log(s) + power · (log(x) − log(s)).
local function polynomialSoftcap(threshold: number, power: number)
    return function(x: number): number
        if x <= threshold then
            return x
        end
        return threshold * (x / threshold) ^ power
    end
end

-- Logarithmic softcap: growth becomes logarithmic. Very aggressive — use as a
-- ceiling on things that must never run away (e.g. offline multipliers).
local function logarithmicSoftcap(threshold: number)
    return function(x: number): number
        if x <= threshold then
            return x
        end
        return threshold * (1 + math.log(x / threshold))
    end
end

-- Dilation: compresses in log space. Antimatter Dimensions popularised this shape.
-- Applies to the ORDER OF MAGNITUDE, so it is brutal and reversible by design.
local function dilate(power: number)
    return function(x: number): number
        if x <= 1 then
            return x
        end
        return 10 ^ (math.log10(x) ^ power)
    end
end
```

Properties worth checking in a property test (§10.4):

- **Monotonic**: `x₁ < x₂ ⟹ softcap(x₁) ≤ softcap(x₂)`. A non-monotonic softcap means
  buying an upgrade can lower your production. Players find this in hours.
- **Continuous at the threshold**: all three above satisfy `softcap(threshold) =
  threshold`. A discontinuity is a visible jump and a balancing nightmare.
- **Identity below the threshold**: early-game players never touch the softcap and
  never need to understand it.

Stack softcaps by composing them at increasing thresholds; keep the list sorted and
apply in ascending threshold order.

### 4.5 Making it debuggable: the breakdown UI

Build this before you need it. It will be used by your designers daily, by your
support team weekly, and by you at 2 a.m.

```lua
--!strict
-- Renders a Breakdown as text. Hook it to a dev command and to a long-press on
-- any number in the UI.
local function renderBreakdown(stat: string, bd: Breakdown): string
    local lines = { `=== {stat} ===`, `base            {bd.base}` }

    if #bd.flat > 0 then
        table.insert(lines, "-- flat --")
        for _, e in bd.flat do
            table.insert(lines, string.format("  %-24s +%s", e.label, fmt(e.value)))
        end
        table.insert(lines, string.format("  = %s", fmt(bd.afterFlat)))
    end

    if #bd.add > 0 then
        table.insert(lines, "-- additive --")
        local total = 0
        for _, e in bd.add do
            total += e.value
            table.insert(lines, string.format("  %-24s +%.1f%%", e.label, e.value * 100))
        end
        table.insert(lines, string.format("  = x%.3f  -> %s", 1 + total, fmt(bd.afterAdd)))
    end

    if #bd.mul > 0 then
        table.insert(lines, "-- multiplicative --")
        for _, e in bd.mul do
            table.insert(lines, string.format("  %-24s x%s", e.label, fmt(e.value)))
        end
        table.insert(lines, string.format("  = %s", fmt(bd.afterMul)))
    end

    if #bd.pow > 0 then
        table.insert(lines, "-- exponential --")
        for _, e in bd.pow do
            table.insert(lines, string.format("  %-24s ^%.4f", e.label, e.value))
        end
        table.insert(lines, string.format("  = %s", fmt(bd.afterPow)))
    end

    if bd.afterSoftcap ~= bd.afterPow then
        table.insert(lines, string.format("softcap         %s -> %s",
            fmt(bd.afterPow), fmt(bd.afterSoftcap)))
    end
    if bd.final ~= bd.afterSoftcap then
        table.insert(lines, string.format("clamp           %s -> %s",
            fmt(bd.afterSoftcap), fmt(bd.final)))
    end

    table.insert(lines, `FINAL           {fmt(bd.final)}`)
    return table.concat(lines, "\n")
end
```

Three refinements that turn this from a debug tool into a shipped feature:

- **Sort each bucket descending by contribution** and collapse the tail into
  "+ 31 others (+4.2%)". Players want to know what matters, not everything.
- **Show the counterfactual.** Next to each line, "removing this: −18%". This is one
  extra `evaluate` call per line with that effect disabled, and it is the single most
  informative thing you can show.
- **Expose it on the client**, computed from the client's mirror of stored state
  (§3.4). It costs no bandwidth and no server CPU.

### 4.6 Common stacking bugs this design prevents

- **Double-application.** An effect registered under two stats, or applied once in
  the registry and once in hand-written code. The registry being the *only* path
  makes the second case a lint rule: grep for `*=` in the economy module.
- **Order-dependent results.** Because the buckets are collected first and applied in
  a fixed order, registration order cannot change the answer. Property-test it (§10.4).
- **Silent `nan` propagation.** The `math.isfinite` guard in `evaluate` contains the
  damage to one warning instead of a corrupted save.
- **Stale multipliers.** Solved structurally in §3.3, not here.
- **"Which one is broken?"** The breakdown answers it in one screenshot.

---

## 5. Prestige and reset layers

### 5.1 What a layer is

A prestige layer is three things: a **gain formula** (how much layer currency this
reset awards), a **reset spec** (what is destroyed, what survives), and an **unlock
condition**. Everything else — the upgrades it sells, the UI tab — is content.

The mistake that forces a rewrite is hard-coding layer 1 into the reset function and
then discovering that layer 2 must also reset layer 1's currency but not its
milestone unlocks. Model the reset as *data* from the start.

### 5.2 The standard gain curves

| Family | Formula | Feel | Used by |
|---|---|---|---|
| **Root** | `gain = ⌊k · (E/T)^p⌋`, `p ∈ [0.25, 0.5]` | Steady, legible. Doubling `E` gives `2^p×` gain. | Most Roblox rebirth systems (`p = 0.5`) |
| **Cube root** | `gain = ⌊(E/T)^(1/3)⌋` | Slower; long layer lifetime. | Cookie Clicker heavenly chips `[COMMUNITY, SECOND-HAND]` |
| **Logarithmic** | `gain = ⌊k · (log₁₀E − log₁₀T)⌋` | Gain is linear in *orders of magnitude*. Extremely stable across 100+ OOM. | Deep-layer incrementals |
| **Magnitude-exponential** | `gain = 10^(a·log₁₀E − b)` | Gain itself grows super-linearly in magnitude. The classic "infinity points" shape. | Antimatter Dimensions `[COMMUNITY, SECOND-HAND]` |

```lua
--!strict
-- Gain formulas share a signature so a layer can name one in data.
local GainCurves = {}

function GainCurves.root(k: number, threshold: number, power: number)
    return function(earned: number): number
        if earned < threshold then return 0 end
        return math.floor(k * (earned / threshold) ^ power)
    end
end

function GainCurves.logarithmic(k: number, threshold: number)
    return function(earned: number): number
        if earned < threshold then return 0 end
        return math.floor(k * (math.log10(earned) - math.log10(threshold)))
    end
end

function GainCurves.magnitude(a: number, b: number, threshold: number)
    return function(earned: number): number
        if earned < threshold then return 0 end
        -- Done entirely in log space: never materialise 10^300 as an intermediate.
        local logGain = a * math.log10(earned) - b
        if logGain > 308 then return math.huge end   -- caller must handle; see §1.8
        return math.floor(10 ^ logGain)
    end
end

return GainCurves
```

**Pick the logarithmic family if your game will span more than ~30 orders of
magnitude.** Root curves become numerically awkward and design-awkward at that
range: the difference between `1e80` and `1e100` earned should be meaningful, and
under `p = 0.5` it is a factor of `1e10` in gain, which no upgrade tree can absorb.

### 5.3 The reset spec

```lua
--!strict
-- ReplicatedStorage/Shared/Layers.luau

export type Layer = {
    id: string,
    displayName: string,
    -- Which stored currency drives the gain.
    sourceCurrency: string,
    gain: (earned: number) -> number,
    unlock: (state: any) -> boolean,

    -- Declarative reset. Everything not listed here SURVIVES.
    resets: {
        balances: { string },          -- currency ids zeroed
        earned: { string },            -- lifetime counters zeroed
        generators: boolean,           -- counts/levels back to defaults
        upgrades: { string },          -- upgrade id prefixes cleared, e.g. "base_"
        layers: { string },            -- lower layer ids fully reset
    },
}

local Layers: { Layer } = {
    {
        id = "rebirth",
        displayName = "Rebirth",
        sourceCurrency = "ore",
        gain = GainCurves.root(1, 1e6, 0.5),
        unlock = function(state) return state.earned.ore >= 1e6 end,
        resets = {
            balances = { "ore" },
            earned = { "ore" },
            generators = true,
            upgrades = { "base_" },
            layers = {},
        },
    },
    {
        id = "ascend",
        displayName = "Ascension",
        sourceCurrency = "rebirth",
        gain = GainCurves.logarithmic(1, 1e3),
        unlock = function(state) return state.prestige.rebirth.lifetime >= 1e3 end,
        resets = {
            balances = { "ore" },
            earned = { "ore" },
            generators = true,
            upgrades = { "base_", "rebirth_" },
            layers = { "rebirth" },       -- wipes rebirth currency, keeps its count
        },
    },
}
```

The executor is written once and never changes when a layer is added:

```lua
--!strict
local function performReset(state, cache, layer: Layer, defaults)
    -- 1. Advance first: production earned up to this instant must count.
    Economy.advanceTo(state, os.time())

    -- 2. Award, using LIFETIME EARNED, not current balance.
    local earned = if layer.sourceCurrency == "ore"
        then state.earned.ore
        else state.prestige[layer.sourceCurrency].lifetime
    local gained = layer.gain(earned)

    local node = state.prestige[layer.id]
    node.currency += gained
    node.lifetime += gained
    node.resets += 1
    node.lastResetAt = os.time()

    -- 3. Apply the reset spec.
    for _, id in layer.resets.balances do state.balances[id] = 0 end
    for _, id in layer.resets.earned do state.earned[id] = 0 end
    if layer.resets.generators then
        for id in state.generators do
            state.generators[id] = table.clone(defaults.generators[id])
        end
    end
    for _, prefix in layer.resets.upgrades do
        for id in state.upgrades do
            if string.sub(id, 1, #prefix) == prefix then
                state.upgrades[id] = nil
            end
        end
    end
    for _, lowerId in layer.resets.layers do
        local lower = state.prestige[lowerId]
        lower.currency = 0
        lower.upgrades = {}
        -- lower.lifetime and lower.resets deliberately survive: they drive
        -- milestone rewards and "total rebirths" achievements.
    end

    -- 4. Re-anchor and invalidate.
    state.meta.lastAdvancedAt = os.time()
    Derived.invalidate(cache)
    return gained
end
```

Note the upgrade-id prefix convention (`base_`, `rebirth_`, `ascend_`). It makes
"what does this layer clear?" a string operation instead of a hand-maintained list
that drifts. Enforce it in a startup assertion.

### 5.4 Adding a fourth layer without a rewrite

With the above, adding layer *n* is:

1. Append a `Layer` entry with its gain curve, unlock and reset spec.
2. Add a `prestige[id]` node to the default state and a migration (§6.5) that
   backfills it for existing players.
3. Register its effects (§4.3) — they are ordinary effects, `mul` or `pow`.
4. Add a UI tab.

None of `performReset`, `Economy`, `Effects` or the save code changes. That is the
test of whether your layer abstraction is real.

### 5.5 Design notes on multi-layer pacing

- **Each layer should make the previous layer's full run take ~1/10 the time it did
  the first time.** If layer 2's first reward doesn't visibly collapse a layer-1
  grind, players read it as a treadmill.
- **The first reset of a new layer should be reachable in one sitting** from the
  moment it unlocks. The *second* can be long.
- **Keep the number of simultaneously-relevant layers at 2–3.** Beyond that players
  cannot hold the interactions in their heads, and your softcap tuning becomes a
  multi-variable search.
- **Never reset settings, cosmetics, or anything purchased with Robux.** Put those in
  `state.permanent` (§3.1) and the reset spec structurally cannot touch them.

---

## 6. Persistence on Roblox

### 6.1 The limits, verified

From `content/en-us/cloud-services/data-stores/error-codes-and-limits.md`
(September 2026). These numbers have changed more than once; re-check before you
tune against them.

**Data limits (per key)**

| Component | Maximum |
|---|---|
| Data store name | 50 characters |
| Key name | 50 characters |
| Scope | 50 characters |
| Data (key value) | **4,194,304 characters** (4 MB) per key |
| User-defined metadata | 300 characters total |

**Throughput limits (per key, rolling 60 s window, across all servers)**

| Type | Limit |
|---|---|
| Read (`GetAsync`, `GetVersionAsync`, read half of `UpdateAsync`) | 25 MB/min |
| Write (`SetAsync`, `IncrementAsync`, `RemoveAsync`, write half of `UpdateAsync`) | 4 MB/min |

Roblox "rounds throughput up to the next kilobyte" per request — so 60 saves of
800 bytes each costs 60 KB, not 48 KB.

**Request budget — per server (defaults; configurable, see below)**

| Request type | Requests per minute |
|---|---|
| `StandardRead` | `60 + numPlayers × 40` |
| `StandardWrite` | `60 + numPlayers × 40` |
| `StandardList` | `5 + numPlayers × 2` |
| `StandardRemove` | `60 + numPlayers × 40` |
| `OrderedRead` | `60 + numPlayers × 40` |
| `OrderedWrite` | `30 + numPlayers × 5` |

**Request budget — experience-wide (shared with Open Cloud)**

| Request type | Requests per minute |
|---|---|
| Standard / Ordered **Read** | `300 + concurrentUsers × 40` |
| Standard / Ordered **Write** | `300 + concurrentUsers × 20` |
| List | `300 + concurrentUsers × 2` |
| Remove | `300 + concurrentUsers × 40` |

Three consequences that bite idle games specifically:

1. **`UpdateAsync` consumes from both the read and write budgets.** The docs state
   this explicitly: "A single call will decrement both limits." Your effective write
   budget with `UpdateAsync` is the *minimum* of the two, and `OrderedWrite`
   (`30 + n×5`) is the tightest — relevant if you keep a currency leaderboard.
2. **Servers get a startup burst.** "Servers receive a one-time startup burst of
   additional request budget when they are first created." This is why a mass-join
   after a server restart works, and why you should still stagger.
3. **You can now configure the per-server limits.**
   `DataStoreService:SetRateLimitForRequestType(requestType, baseLimit, perPlayerLimit)`
   overrides the defaults for the current server (`rateLimit = baseLimit +
   perPlayerLimit × numPlayers`). The docs say to "call this API **once per request
   type during server initialization**". `UpdateAsync` and `OnUpdate` cannot be
   configured and error if you try. `StandardRead`/`StandardWrite` accept
   `baseLimit ∈ [0,60]` and `perPlayerLimit ∈ [0,40]`. Pair it with
   `GetRequestBudgetForRequestType` to check remaining budget before a burst.

**Storage limit (experience-wide):** `500 MB + 1 MB × lifetime user count`,
measured on the *compressed* size of the latest version of each key.

### 6.2 Do not compress your save

This is the finding most likely to contradict what your team believes. Roblox's
documentation states:

> "Storage usage is measured using the **compressed size** of the latest version of
> each key. Data stores automatically compress your data before storage, so avoid
> pre-compressing it yourself. Pre-compression adds unnecessary CPU overhead and may
> reduce the effectiveness of data stores' built-in compression. By storing
> uncompressed data, you automatically benefit from improvements to Roblox's
> compression algorithms and future schema-based optimizations."

There is a second, independent reason on the write path:

> "Any string being stored in a data store must be valid UTF-8. In UTF-8, values
> greater than 127 are used exclusively for encoding multi-byte codepoints, so a
> single byte greater than 127 will not be valid UTF-8 and the `UpdateAsync()`
> attempt will fail."

Raw deflate/LZ4 output is binary and will contain bytes > 127, so a home-grown
compressor must be base64-ed (+33%) or base91-ed (+23%) before it is storable —
after which Roblox's own compressor sees high-entropy text and achieves almost
nothing. Net result: more CPU, worse ratio, new failure modes.

**Shrink the schema instead.** An idle game save is dominated by repeated keys:

```lua
-- 4.1 KB for 30 generators
generators = { ironMiner = { count = 1200, level = 14, unlocked = true }, ... }

-- ~600 bytes: positional arrays, a shared id table in code, defaults omitted
-- g[i] = {count, level} ; unlocked is implied by presence
g = { [1] = {1200, 14}, [7] = {3, 0}, ... }
```

Other high-yield schema tricks, in order of payoff:

1. **Omit anything equal to its default.** Reconcile on load (ProfileStore's
   `Profile:Reconcile()` does exactly this from the template).
2. **Sets over lists over dictionaries-of-objects** for owned/unowned flags.
3. **Short stable ids.** `"g14"` not `"ironMinerUpgradeTier3"`. Keep the mapping in
   code, versioned with the schema.
4. **Round what doesn't need precision.** `math.floor` on counts;
   3 significant figures on cosmetic statistics.
5. **Cap unbounded collections.** Achievement timestamps, per-day statistics and
   "recent purchases" logs grow forever. Put a hard length on every array in the
   schema and a startup assertion that checks it.

In practice a well-designed idle-game save is 5–40 KB and never approaches 4 MB. If
yours does, you have an unbounded collection, not a compression problem.

### 6.3 Session locking is mandatory

Two servers holding the same profile is not a theoretical risk in this genre: idle
games have high rejoin rates (players hop servers to reset boss timers, chase
events, or on purpose to duplicate), and the whole value of the save is a single
number that can be multiplied by joining twice.

`SetAsync` has no defence. `UpdateAsync` is the primitive you need — it "reads the
current key value (from whatever server last updated it) before making any changes"
and, if another server wrote in between, "will call the function again, discarding
the result of the previous call… as many times as needed until the data is saved
**or** until the callback function returns `nil`". Returning `nil` cancels the write.
That is exactly the primitive a session lock needs: *read the lock, and only write if
it is mine or expired.*

Do not implement it yourself. Use a library.

| | **ProfileStore** | **Lapis** | **ProfileService** (legacy) |
|---|---|---|---|
| Author / status | loleris / MadStudioRoblox, actively maintained | nezuo, actively maintained | loleris, superseded by ProfileStore |
| Distribution | Single ModuleScript, ~2,200 lines | Wally `nezuo/lapis` (0.3.4 at time of writing) | Single ModuleScript |
| API style | Yielding, Roblox-like (`:StartSessionAsync()`) | Promise-based (`evaera/promise@4`) | Yielding (`:LoadProfileAsync()`) |
| Session locking | Yes — 40 s steal, 630 s dead-server assumption | Yes | Yes |
| Autosave | 300 s (`AUTO_SAVE_PERIOD`, tunable via `SetConstant`) | 300 s | 30 s |
| Migrations | Manual (`Profile:Reconcile()` + your own version field) | **First-class** `migrations` array | Manual |
| Validation | No | **Yes**, `validate` callback | No |
| Immutability | Mutable `Profile.Data` | Deep-frozen by default, opt-out | Mutable |
| Cross-server messaging | `:MessageAsync()` (gift/ban while offline) | No | No |
| Version query / rollback | `:VersionQuery()`, `:GetAsync(key, version)` | Via raw DataStore APIs | Limited |
| Mock store for tests | `ProfileStore.Mock` | `DataStoreServiceMock` dev dependency | `.Mock` |
| Caveat | `Profile:IsActive()` guarantee "is only valid until code yields" | README: "has not been battle-tested in a large production game yet" | Use ProfileStore instead for new work |

**Recommendation for an idle game: ProfileStore.** Reasons specific to this genre:

- `Profile.LastSavedData` is exposed specifically for "proper developer product
  purchase receipt handling" — you need it for §7.4's idempotent `ProcessReceipt`.
- `ProfileStore:MessageAsync(key, message)` lets you grant a purchase, a gift, or a
  correction to a player who is offline, which an idle game needs constantly
  (support refunds, event rewards, compensation after a balance bug).
- `VersionQuery` gives you rollback without Open Cloud when a player reports lost
  progress (§6.6).
- `ProfileStore.OnCriticalToggle` / `IsCriticalState` surfaces DataStore outages, so
  you can disable purchases and show a banner instead of silently losing saves.

Take Lapis if you value the Promise API, deep-frozen immutability and the
declarative `migrations` array more than the above — its migration story is genuinely
better and §6.5 is the section that will hurt you most.

Roblox's own best-practices page now explicitly deprecates the other common choice:

> "DataStore2 is a legacy third-party library and you shouldn't use it for new
> experiences. If your experience currently uses DataStore2, use Roblox's official
> beta DataStore2 migration tool to migrate from its one-data-store-per-player
> pattern."

### 6.4 Save cadence, save-on-leave, and BindToClose

Roblox's guidance: "Load a player's data at the start of a session and keep a
server-local copy for gameplay… Save it periodically, when the player leaves, when
the server shuts down, and at critical checkpoints such as purchase processing.
Choose a periodic save interval that stays within your request limits **and is
shorter than any session-lock expiration**; the player data and purchasing sample
uses 180 seconds."

For an idle game specifically:

- **Autosave every 120–300 s is right.** ProfileStore's 300 s default is fine and it
  already staggers writes internally (it spreads profiles across the interval rather
  than saving them all at once — `auto_save_index_speed = AUTO_SAVE_PERIOD /
  auto_save_list_length`).
- **Force a save at critical checkpoints**: after `ProcessReceipt` grants, after a
  prestige, after any Robux-adjacent state change. Never after an ordinary purchase —
  that is what the autosave is for, and an idle game generates purchases constantly.
- **Jitter anything you schedule yourself.** "Don't start recurring requests from
  every server on the same schedule. Before starting a fixed-frequency loop, assign
  each server or player a random initial offset."
- **`advanceTo(state, os.time())` immediately before every save.** Otherwise the
  persisted balance is stale relative to the persisted timestamp and the player is
  quietly credited the same interval twice on the next load (§2.6).

`BindToClose` has a documented 30-second budget:

> "The experience server waits 30 seconds for all bound functions to stop running
> before it shuts down. After 30 seconds, the server shuts down even if functions are
> still running." Bound functions "are called in parallel and run at the same time."

ProfileStore and Lapis both bind this for you. If you bind your own, the rules are:
do not `task.wait` on a fixed timer inside it, do the saves concurrently rather than
serially, and guard with `RunService:IsStudio()` so your Studio playtests don't sit
for 30 seconds on stop.

### 6.5 Schema versioning and migration

**Your save format will change.** Budget for it in the architecture, not in a
hotfix.

```lua
--!strict
-- ReplicatedStorage/Shared/Migrations.luau
-- Index i migrates schema (i-1) -> i. Append only. NEVER edit a shipped entry.

local MIGRATIONS: { (any) -> any } = {
    -- 0 -> 1: split a single "coins" balance into per-currency balances.
    function(d)
        d.balances = { coins = d.coins or 0 }
        d.coins = nil
        return d
    end,

    -- 1 -> 2: introduce lifetime `earned` (prestige needs it). Backfill from the
    -- current balance: wrong, but monotone and better than zero.
    function(d)
        d.earned = { coins = d.balances.coins }
        return d
    end,

    -- 2 -> 3: add the second prestige layer.
    function(d)
        d.prestige = d.prestige or {}
        d.prestige.ascend = {
            currency = 0, lifetime = 0, resets = 0,
            lastResetAt = 0, upgrades = {},
        }
        return d
    end,
}

local CURRENT = #MIGRATIONS

local function migrate(data: any): any
    local from = data.schema or 0
    if from > CURRENT then
        -- Data from a NEWER version of the game. See "backwards compatibility".
        error(`save schema {from} is newer than this server's {CURRENT}`)
    end
    for v = from + 1, CURRENT do
        data = MIGRATIONS[v](data)
        data.schema = v
    end
    return data
end
```

Five rules, learned expensively:

1. **Append only.** A migration that has run on live data is frozen forever. If it
   was wrong, write a *new* migration that corrects it.
2. **Migrations must be pure and total.** No yields, no DataStore calls, no
   `os.time()`. Given the same input they must produce the same output, so you can
   golden-master them (§10.3).
3. **Handle the newer-than-me case explicitly.** This is Lapis's documented hazard:
   "a player might join a new server, leave, and then join an old server. This would
   cause the player's document to fail to load on the old server since the document's
   version would be ahead." Options are (a) Roblox's *Migrate To Latest Update*
   feature to drain old servers, or (b) write **backwards-compatible migrations** —
   add keys freely, but never remove a key until every server that reads it is gone.
   The safe pattern is *two releases*: release N stops reading the key, release N+1
   removes it.
4. **Never destroy on migrate.** When a migration drops a field, move it to
   `data._archive` for a few releases rather than deleting it. Storage is cheap
   relative to an unrecoverable mistake at scale.
5. **Run every migration chain in CI.** Keep a corpus of real (anonymised) saves at
   every historical schema version and assert that each migrates to the current
   version and passes validation. This is the single highest-value test in the
   project.

### 6.6 Handling data loss gracefully

DataStore failures happen. The design goal is that *a failure is visible and
reversible*, never silent.

- **Never start a session on a failed read.** If the load errors or the session
  cannot be locked, do not fall back to the default state — that is how a player with
  1e40 ore gets reset to zero and writes a review about it. Kick with a clear message
  and a retry prompt. ProfileStore returning `nil` from `StartSessionAsync` is a
  "do not let this player play" signal, not a "give them a fresh profile" signal.
- **Distinguish "no data" from "couldn't read data".** New player vs. outage. Only the
  first gets a default profile.
- **Detect critical state and degrade.** `ProfileStore.IsCriticalState` flips after 5
  errors within 120 s. When it is set: disable Robux purchases, disable trading,
  disable prestige, and show a banner. Taking money during an outage you cannot save
  is the worst possible outcome.
- **Keep versions.** `ProfileStore:VersionQuery(key, sortDirection, minDate, maxDate)`
  walks historical versions; the underlying `DataStore:ListVersionsAsync` /
  `GetVersionAsync` retain previous versions for a documented retention period.
  Build a support tool that restores a player to a chosen timestamp, and use it
  instead of hand-editing values.
- **Compensate with `MessageAsync`, not with a manual edit.** Grant via the
  offline-message queue so the grant is idempotent and auditable.
- **Log a save-size histogram.** Sudden growth is an unbounded collection, and you
  want to know before a player hits 4 MB and becomes permanently unsaveable.

---

## 7. Server/client split

### 7.1 What lives where

| Concern | Server | Client |
|---|---|---|
| Stored state (§3.1) | **Owns it.** Session-locked profile. | Mirror, replicated on join + on change. |
| `lastAdvancedAt`, offline grants | **Owns it.** | Never sees a writable copy. |
| Derived multipliers | Computes authoritatively. | Recomputes for display/prediction using the *same shared module*. |
| Purchase validation | **Owns it.** Cost, affordability, prerequisites, caps. | Predicts, shows the button state. |
| Prestige | **Owns it.** | Predicts the gain for the confirm dialog. |
| Autobuyers | **Owns them** (they spend currency). | Owns the *settings* UI only. |
| The number ticking up on screen | Sends rate, not value. | **Owns the animation entirely.** |
| Number formatting, notation | Never. | Owns it. |
| Particle/sound feedback | Never. | Owns it. |

The line to hold: **the client owns everything that is a function of time and
already-replicated state; the server owns every state transition.**

### 7.2 The bandwidth problem, and the fix

A naive idle game replicates the balance every tick. At 10 Hz with 30 players that
is 300 messages per second of data that the client could have computed itself, and
it *looks worse* — the number updates in visible 100 ms steps instead of smoothly.

Replicate the **generating function** instead:

```lua
--!strict
-- ReplicatedStorage/Shared/Snapshot.luau
-- Everything the client needs to draw a smooth, correct number until the next
-- snapshot. Sent on: join, any purchase, prestige, buff start/end, and a slow
-- keepalive (~15 s) to correct drift.

export type Snapshot = {
    t0: number,                      -- server timestamp this snapshot describes
    value: { [string]: number },     -- balance at t0
    -- Coefficients of the production polynomial, lowest order first:
    -- v(t) = value + c[1]·dt + c[2]·dt² + … (see §1.5)
    coeff: { [string]: { number } },
    validUntil: number?,             -- next scheduled breakpoint, if any
}
```

```lua
--!strict
-- Client: evaluate at render rate. No network, no server CPU.
local Workspace = game:GetService("Workspace")

local function evaluate(snapshot: Snapshot, currency: string, now: number): number
    local dt = math.max(0, now - snapshot.t0)
    local acc = snapshot.value[currency] or 0
    local power = 1
    for _, c in snapshot.coeff[currency] or {} do
        power *= dt
        acc += c * power
    end
    return acc
end

RunService.PreRender:Connect(function()
    -- GetServerTimeNow() is documented as monotonic and rate-accurate to 0.6%.
    -- That is exactly the right tool for display extrapolation, and explicitly
    -- NOT the right tool for deciding a grant.
    local now = Workspace:GetServerTimeNow()
    Display.setBalance(evaluate(currentSnapshot, "ore", now))
end)
```

Bandwidth falls from `O(players × tickRate)` to `O(players × stateChanges)`, which
for an idle game is a handful of messages per minute per player.

**Reconciliation.** When a new snapshot arrives, the client's extrapolated value
will differ slightly (rounding, latency, a buff the client didn't know about).
Don't snap — it reads as the number jumping backwards, which players interpret as
lost currency:

```lua
local function onSnapshot(new: Snapshot)
    local now = Workspace:GetServerTimeNow()
    local predicted = evaluate(currentSnapshot, "ore", now)
    local actual = evaluate(new, "ore", now)
    local error = actual - predicted

    if math.abs(error) <= math.abs(actual) * 0.001 then
        -- Within 0.1%: absorb it silently over the next second.
        Display.blendTo(actual, 1.0)
    elseif error > 0 then
        -- Server has more than we showed: jump up. Players never complain.
        Display.snapTo(actual)
    else
        -- Server has less: ease down over ~2 s so it reads as "catching up",
        -- not as a loss. Log it — a persistent negative error is a real bug.
        Display.blendTo(actual, 2.0)
        Telemetry.count("snapshot.negativeDrift")
    end
    currentSnapshot = new
end
```

**Transport choice.** Use a reliable `RemoteEvent` for snapshots: they are rare,
ordered matters, and losing one strands the client on a stale rate.
`UnreliableRemoteEvent` is right for high-frequency cosmetic effects (floating
"+1e6" text, particle triggers) — but note the documented limits: **payloads larger
than 1000 bytes are dropped**, and remotes are throttled at "approximately 500
requests per second, per client… shared among all remote events of the same type."

Batch client→server requests. An autobuy-spamming client firing one remote per
purchase will hit the 500/s limit; send `{generatorId, count}` instead.

### 7.3 The exploit surface

Idle games are attractive targets because the entire game state is one number and
the leaderboard makes it visible.

**Currency injection.** The client never sends amounts. Ever. The purchase remote
carries `(generatorId: string, requestedCount: number)` and nothing else; the server
computes the cost from its own state, checks affordability against its own balance,
and applies it. If your remote signature contains a price, a balance, or a
multiplier, it is already broken.

```lua
--!strict
-- Server: the only shape a purchase remote should have.
local MAX_BULK = 1e9   -- sanity bound; also guards NaN/inf via isfinite below

PurchaseRemote.OnServerEvent:Connect(function(player, generatorId, requestedCount)
    -- 1. Existence and type.
    if typeof(generatorId) ~= "string" or typeof(requestedCount) ~= "number" then return end
    -- 2. Finiteness. NaN passes `typeof(x) == "number"` and defeats every
    --    subsequent comparison, including `count > MAX_BULK`.
    if not math.isfinite(requestedCount) then return end
    -- 3. Range and integrality.
    requestedCount = math.floor(requestedCount)
    if requestedCount < 1 or requestedCount > MAX_BULK then return end
    -- 4. Context: does this generator exist, is it unlocked for this player?
    local state = Sessions.get(player); if not state then return end
    local def = GeneratorDefs[generatorId]; if not def then return end
    if not state.generators[generatorId].unlocked then return end
    -- 5. Rate limit (token bucket, per player, cleaned up on PlayerRemoving).
    if not Buckets.take(player, "purchase", 1) then return end

    -- Advance, then price, then charge. All server-side.
    Economy.advanceTo(state, os.time())
    local affordable = Economy.maxAffordable(state, def)          -- §8.1
    local count = math.min(requestedCount, affordable)
    if count < 1 then return end
    Economy.applyPurchase(state, def, count)
    Replication.pushSnapshot(player, state)
end)
```

**Time manipulation.** Covered in §2.5. The short version: the elapsed time comes
from a server-read `os.time()` differenced against a timestamp inside the
session-locked profile. The client cannot set it, send it, or read it into a form
that matters. `Workspace:GetServerTimeNow()` is documented as "not secure" and is
display-only.

**Purchase spoofing.** Robux purchases go through `ProcessReceipt`, which has a hard
contract. The documented guarantees: it is called "for all unresolved developer
product purchases" when a purchase completes, when a prompt succeeds, and **when a
user joins the server**; a purchase is only resolved when the callback returns
`PurchaseGranted` *and* Roblox records it. Consequences:

- **Idempotency on `PurchaseId` is mandatory**, because the callback will be invoked
  again on rejoin for anything not yet resolved. Store granted `PurchaseId`s in the
  profile (a bounded ring of the last ~50 is plenty) and return `PurchaseGranted`
  immediately for a repeat.
- **Grant, persist, then return `PurchaseGranted`.** Returning first and saving after
  loses the grant if the server dies in between — and Roblox will not re-deliver a
  resolved receipt.
- **Return `NotProcessedYet` on any failure.** "Unresolved developer product
  purchases are not removed or refunded after the escrow period expires", and there
  is "no time-based retry mechanism" — the callback only fires again on another
  purchase or a rejoin. `NotProcessedYet` is how the player eventually gets their
  item; swallowing the error is how they don't.
- **Do not set the callback in more than one script.** "You should only set the
  `ProcessReceipt` callback one time in a single server-side `Script`."
- **`Profile.LastSavedData`** exists precisely for this: it tells you what has
  actually reached the DataStore, so you can decide whether a grant is durable before
  acknowledging it.

**Other surfaces specific to this genre:**

- **Rejoin farming** — §2.6 (session locking + advance-then-persist).
- **Server hopping for per-server rewards.** Any "free crate every 10 minutes" that
  is tracked per-server is farmable by hopping. Track cooldowns in the profile
  against `os.time()`.
- **Leaderboard injection.** If you write to an `OrderedDataStore` from the client's
  reported value you have built a global scoreboard of exploiters. Write from the
  session-locked server state only, and cap the write rate (`OrderedWrite` is the
  tightest budget: `30 + numPlayers × 5`).
- **Information leakage.** Upgrade costs, drop tables and future-layer formulas that
  live in `ReplicatedStorage` are readable. That's usually fine for an idle game —
  but do not put unreleased content, event schedules or A/B assignments there.

---

## 8. Automation and lategame

### 8.1 Buy-max in closed form

The lategame breaks looping solutions. A player with 1e200 currency and a cost
ratio of 1.07 can afford roughly `log(1e200)/log(1.07) ≈ 6,800` of a generator they
own none of — and with 1e2000 (log-space numbers, §1.8) it is tens of thousands.
Running a loop per player per autobuy tick is not viable, and it is unnecessary:
every standard cost curve has an invertible partial sum.

**Geometric costs — `c(n) = b·rⁿ` (the default in this genre).**

The cost of buying `k` units when you already own `owned` is a geometric series:

```
S(k) = b·r^owned · (rᵏ − 1) / (r − 1)
```

Invert for the largest `k` with `S(k) ≤ M`:

```
             ⎡      M (r − 1)   ⎤
        log ⎢ 1 + ───────────── ⎥
             ⎣     b · r^owned   ⎦
k  =  ⌊ ───────────────────────── ⌋
                  log r
```

```lua
--!strict
-- Largest k such that the cost of k more units is affordable with `budget`.
-- b: base cost, r: growth ratio (> 1), owned: units already owned.
local function maxAffordableGeometric(budget: number, b: number, r: number, owned: number): number
    if budget <= 0 then return 0 end
    if r == 1 then
        -- Degenerate: constant cost. c = b, so k = floor(budget / b).
        return math.floor(budget / b)
    end
    assert(r > 1, "geometric cost ratio must be >= 1")

    -- Work in log10 to avoid overflow: b·r^owned can exceed 1e308 long before
    -- the player's balance does in a log-space-number game.
    local logNumer = math.log10(budget) + math.log10(r - 1)
    local logDenom = math.log10(b) + owned * math.log10(r)
    local A = logNumer - logDenom          -- log10( M(r-1) / (b·r^owned) )

    local inner: number
    if A > 15 then
        -- 1 + 10^A == 10^A to double precision; skip the addition entirely.
        inner = A
    elseif A < -15 then
        return 0                            -- can't even afford the first one
    else
        inner = math.log10(1 + 10 ^ A)
    end

    local k = inner / math.log10(r)
    -- Floor, then guard the boundary: floating error can put us one over.
    k = math.floor(k)
    return math.max(k, 0)
end
```

Always follow the closed form with a **verify-and-decrement**: compute `S(k)`
exactly and, if it exceeds the budget, decrement once. One extra check costs
nothing and removes an entire class of "I bought 4,001 and went negative" bug.

```lua
local function costOfGeometric(b: number, r: number, owned: number, k: number): number
    if k <= 0 then return 0 end
    if r == 1 then return b * k end
    return b * r ^ owned * (r ^ k - 1) / (r - 1)
end

local function buyMaxGeometric(budget, b, r, owned)
    local k = maxAffordableGeometric(budget, b, r, owned)
    while k > 0 and costOfGeometric(b, r, owned, k) > budget do
        k -= 1
    end
    return k, costOfGeometric(b, r, owned, k)
end
```

**Linear-increment costs — `c(n) = b + d·n`.** The partial sum is arithmetic, so the
inverse is a quadratic:

```
S(k) = k(b + d·owned) + d·k(k−1)/2        →       k = ⌊ (−B + √(B² + 2dM)) / d ⌋
                                                  with B = b + d·owned − d/2
```

```lua
local function maxAffordableLinear(budget: number, b: number, d: number, owned: number): number
    if d == 0 then return math.floor(budget / b) end
    local B = b + d * owned - d / 2
    local k = (-B + math.sqrt(B * B + 2 * d * budget)) / d
    return math.max(math.floor(k), 0)
end
```

**Polynomial costs — `c(n) = b·n^p`.** No useful closed form for the partial sum's
inverse. Binary search, which is O(log k) — ~50 iterations even for `k = 1e15`:

```lua
local function maxAffordableBisect(budget: number, costOfK: (number) -> number): number
    if costOfK(1) > budget then return 0 end
    -- Exponential probe to bracket, then bisect.
    local hi = 1
    while costOfK(hi * 2) <= budget and hi < 2 ^ 52 do
        hi *= 2
    end
    local lo = hi
    hi *= 2
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if costOfK(mid) <= budget then lo = mid else hi = mid - 1 end
    end
    return lo
end
```

**Super-exponential costs — `c(n) = b·r^(n^q)`, `q > 1`.** Here the final term
dominates the sum (each is `r^(2n+1)` times the last for `q = 2`), so solve for the
largest single affordable unit and subtract at most one:

```
log₁₀ c(n) = log₁₀ b + n^q · log₁₀ r  ≤  log₁₀ M
        n  ≤  ((log₁₀M − log₁₀b) / log₁₀r)^(1/q)
```

```lua
local function maxAffordableSuperExp(budget, b, r, q, owned)
    local n = ((math.log10(budget) - math.log10(b)) / math.log10(r)) ^ (1 / q)
    local k = math.floor(n) - owned + 1
    return math.max(k, 0)   -- then verify-and-decrement as above
end
```

### 8.2 Autobuyers

An autobuyer is server-side (it spends currency), runs on the fixed tick from §1.3,
and needs a **priority policy** because naive "buy the cheapest thing" starves the
expensive generators that actually matter.

```lua
--!strict
-- Runs once per economy tick, per player with autobuy enabled.
local function runAutobuyers(state, defs)
    Economy.advanceTo(state, os.time())

    -- Policy: highest "production gained per currency spent" first, recomputed
    -- each tick. This is the efficiency-maximising greedy and it is what players
    -- expect "auto" to do.
    local candidates = {}
    for id, def in defs do
        local g = state.generators[id]
        if not g.unlocked or not state.settings.autobuy[id] then continue end
        local cost = Economy.costOf(state, def, g.count, 1)
        local gain = Economy.marginalProduction(state, def, g.count)
        if cost > 0 and gain > 0 then
            table.insert(candidates, { id = id, def = def, ratio = gain / cost })
        end
    end
    table.sort(candidates, function(a, b) return a.ratio > b.ratio end)

    -- Reserve: never spend below the player's configured floor. This is the
    -- setting that stops an autobuyer from blocking a manual prestige.
    local reserve = state.settings.autobuyReserve or 0

    for _, c in candidates do
        local budget = state.balances[c.def.currency] - reserve
        if budget <= 0 then break end
        local k = Economy.maxAffordable(budget, c.def, state.generators[c.id].count)
        -- Bulk cap: buying 40,000 in one tick is correct but produces an
        -- unreadable UI. Cap per tick and let it catch up over a few seconds.
        k = math.min(k, 1000)
        if k > 0 then
            Economy.applyPurchase(state, c.def, k)
        end
    end
end
```

**Autobuyers and offline progress do not mix.** If autobuyers ran offline, the
closed form in §1.5 is invalid — the coefficients change every time a purchase
happens, and the number of purchases over three days is unbounded. Three defensible
answers, in order of preference:

1. **Autobuyers pause offline.** Simplest, honest, and easy to explain. State it in
   the UI. Most Roblox idle games do this.
2. **Sell "offline autobuy" as a separate, capped feature** — e.g. autobuy runs for
   the first hour of offline time only. Bounded work, clear value.
3. **Bounded log-spaced simulation.** Divide the offline interval into `N = 128`
   geometrically-increasing chunks, advance and run autobuyers once per chunk. Cost
   is O(N) regardless of elapsed time, and the geometric spacing puts the resolution
   where purchases actually happen (early). Document that it is an approximation, and
   make it *conservative* — under-granting is forgiven, over-granting is a balance
   bug you can never claw back.

### 8.3 Keeping the UI responsive

The number on screen changes every frame. Everything else must not.

- **Decouple the value from the label.** The value is computed by `evaluate()` (§7.2)
  at render rate. The *label* is written at a fixed 10–15 Hz, because updating
  `TextLabel.Text` is what costs — it invalidates text layout, and inside a
  `UIListLayout` it can force a re-layout of every sibling.
- **Only assign `.Text` when the formatted string actually changes.** At 10 Hz with
  3-significant-digit formatting, a slow-growing number changes its string only a few
  times a second.
- **Formatting must not allocate in the hot path.** `string.format` allocates; a
  suffix-ladder formatter that concatenates three times allocates three times. At
  60 Hz × 30 visible numbers that is real GC pressure. Format at 10 Hz, cache the
  result, and reuse.
- **Fixed-width digits.** Use a monospaced font or set `RichText` with a fixed-width
  span so the label does not change size every frame. Changing `AbsoluteSize` inside
  a layout is the expensive case.
- **Never rebuild the generator list.** Create the rows once, keep a `{[id]: Frame}`
  map, and update fields. `Instance.new` in a per-frame loop is the number one cause
  of idle-game UI hitching.
- **Virtualise long lists.** Beyond ~50 rows, render only the visible window
  (`ScrollingFrame.CanvasPosition` + a fixed row height makes the index arithmetic
  trivial).
- **Throttle the breakdown UI** (§4.5) to when it is open, and recompute it on a
  timer, not per frame.

```lua
--!strict
-- A suffix-ladder formatter. Cache `last` per label and skip the assignment.
local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
}

local function format(n: number): string
    if n < 1000 then
        return string.format("%.1f", n)
    end
    local tier = math.floor(math.log10(n) / 3)
    if tier >= #SUFFIXES then
        -- Past the ladder, scientific notation is clearer than invented names.
        return string.format("%.3fe%d", n / 10 ^ math.floor(math.log10(n)),
            math.floor(math.log10(n)))
    end
    return string.format("%.2f%s", n / 10 ^ (tier * 3), SUFFIXES[tier + 1])
end

local lastText: { [TextLabel]: string } = {}

local function setLabel(label: TextLabel, value: number)
    local text = format(value)
    if lastText[label] ~= text then
        lastText[label] = text
        label.Text = text
    end
end
```

Offer scientific and engineering notation in settings. A meaningful fraction of
this genre's audience prefers `1.23e15` to `1.23Qa`, and the ones who do will tell
you about it.

---

## 9. Balance and pacing

### 9.1 Cost curve families

| Family | `cost(n)` | `log₁₀ cost` grows | Purchases to 1e100 | Use for |
|---|---|---|---|---|
| Linear | `b + d·n` | logarithmically | ~1e100 | Never alone; consumables only |
| Polynomial | `b·n^p` | logarithmically | ~1e(100/p) | Levels within a generator |
| **Geometric** | `b·rⁿ` | linearly in `n` | `100/log₁₀r` (e.g. 7,800 at r=1.03) | **The default. Generators.** |
| Super-exponential | `b·r^(n^q)` | as `n^q` | `(100/log₁₀r)^(1/q)` | Hard-gated unique upgrades |
| Tetrational | `b·r^(r^n)` | doubly exponentially | <20 | Deep prestige layers only |

The reason geometric is the genre default is that it makes `log(cost)` linear in
`n`, so the *number of purchases* a player makes is proportional to the *orders of
magnitude* they traverse. Pick `r` from the purchase count you want:

```
r = 10^(ΔOOM_target / purchases_target)
```

For 100 orders of magnitude over 5,000 purchases, `r = 10^0.02 ≈ 1.047`. Typical
Roblox idle games sit at `r ∈ [1.05, 1.15]`; below 1.05 the numbers move too slowly
to feel like progress, above 1.15 individual purchases become rare and the game
feels static.

### 9.2 Time to next purchase

The one metric that predicts churn:

```
T(n) = cost(n) / production(n)
```

Plot `T(n)` for every generator across the whole progression, on a log y-axis. The
shape you want:

- **`T(n)` mildly increasing within a tier** (a few percent per purchase) so each
  purchase feels earned but the next is always visible.
- **`T(n)` never exceeding ~5 minutes** for the cheapest available purchase, at any
  point in the game. If the cheapest thing a player can buy is 20 minutes away,
  the session has nothing in it.
- **`T(n)` collapsing by 1–2 orders of magnitude at each prestige.** That collapse
  *is* the prestige reward, more than the multiplier is.
- **No spikes.** A spike is a wall. Find them by looking for
  `T(n+1)/T(n) > 3` anywhere in the curve.

The closed form for geometric costs makes this analytic. If `cost(n) = b·rⁿ` and
production is `p(n) = p₀ + m·n` (each unit adds `m`):

```
T(n) = b·rⁿ / (p₀ + m·n)
```

which grows without bound — every geometric generator eventually stalls. That is
correct and intended: it is what pushes the player to the next tier, and what makes
the tier-unlock pacing the real design problem.

### 9.3 Designing across many orders of magnitude

- **Think in `log₁₀`, always.** Your design spreadsheet's primary axis is
  "orders of magnitude of the main currency", not "hours". Every milestone, unlock
  and layer gets an OOM number.
- **Constant OOM-per-hour is the target.** A healthy incremental delivers a roughly
  constant number of orders of magnitude per hour of *active* play within a layer,
  and each new prestige layer raises that rate. Flat-lining OOM/hour is where players
  quit; check it per layer.
- **Each layer should be 2–5× longer than the previous**, not 50×. Multi-day walls
  are for the endgame, after the player has demonstrated they want one.
- **Unlock something new every 2–4 orders of magnitude** early, stretching to every
  8–10 late. "New" can be small: a generator, an upgrade tab, a cosmetic, a
  statistic.
- **Never let two currencies have the same growth rate.** If they do, one of them is
  redundant and players will notice before you do.

### 9.4 A tuning harness

The economy module must be requireable outside Roblox. That means: no
`game:GetService` at module scope, no `Instance`, no `task.wait`, and the clock
injected. Then you can run it under [Lune](https://github.com/lune-org/lune), a
standalone Luau runtime, and iterate in milliseconds instead of Studio sessions.

```lua
--!strict
-- tools/simulate.luau — run with: lune run tools/simulate
local Economy = require("../src/shared/Economy")
local Defs    = require("../src/shared/Definitions")

type Policy = (state: any) -> ()

-- A deterministic player model. Swap it to test different playstyles.
local function greedyPolicy(state)
    Economy.runAutobuyers(state, Defs)     -- buys best production-per-cost
    if Economy.prestigeGain(state, "rebirth") >= state.prestige.rebirth.currency * 0.5 then
        Economy.performReset(state, Defs.layers.rebirth)
    end
end

local function simulate(policy: Policy, hours: number, stepSeconds: number)
    local state = Economy.newState()
    local clock = 0
    local samples = {}
    local nextSample = 0

    while clock < hours * 3600 do
        clock += stepSeconds
        Economy.advanceToSimulated(state, clock)   -- injected clock, no os.time()
        policy(state)
        if clock >= nextSample then
            table.insert(samples, {
                hours = clock / 3600,
                oom = math.log10(math.max(state.earned.ore, 1)),
                rebirths = state.prestige.rebirth.resets,
                production = Economy.production(state, "ore"),
            })
            nextSample += 600      -- sample every simulated 10 minutes
        end
    end
    return samples
end

-- 10,000 simulated hours at 60 s resolution = 600,000 steps. Runs in ~1 s.
local samples = simulate(greedyPolicy, 10000, 60)

print("hours,oom,rebirths,production")
for _, s in samples do
    print(string.format("%.2f,%.3f,%d,%.4g", s.hours, s.oom, s.rebirths, s.production))
end
```

Pipe the CSV into a spreadsheet or plotting tool and look at four charts:

1. **OOM vs hours** — should be close to a straight line with a step at each layer.
2. **OOM/hour vs hours** — the derivative. Flat regions are grinds.
3. **`T(n)` heatmap** (generator × time) — find the walls.
4. **Time between prestiges** — should grow, but sub-linearly.

Then vary one constant at a time and re-run. The value of the harness is not the
first chart; it is that changing `r` from 1.07 to 1.065 takes two seconds to
evaluate instead of a playtest.

---

## 10. Testing an idle game

### 10.1 Determinism is a design requirement

Everything in this chapter is set up so that the economy is a pure function:

```
newState + (ordered list of timestamped actions) → state
```

To keep it that way:

- **Inject the clock.** `Economy.advanceTo(state, now)` takes `now`; it never calls
  `os.time()` itself. The one place that does is the session layer.
- **Inject randomness.** If anything in the economy is random (crit chance, lucky
  boxes), it takes a `Random` object seeded from state, not `math.random`.
- **No iteration over hash tables in an order-dependent way.** `pairs`/generalised
  `for` order is not specified. If a computation depends on order, sort the keys
  first. This is the most common source of "the test passes locally and fails in CI".
- **No yields inside the economy.** A yield is a place where state can change under
  you, and it makes every function untestable in isolation.

### 10.2 Fast-forwarding thousands of hours

Because production is closed-form, a test can leap:

```lua
--!strict
-- With a fixed-step harness (§9.4), a year of game time is ~525,600 steps at
-- 60 s. With pure closed-form jumps it is one call.
it("reaches the second prestige layer within 40 hours of idle play", function()
    local state = Economy.newState()
    Economy.advanceToSimulated(state, 40 * 3600)     -- one closed-form jump
    expect(Economy.prestigeGain(state, "ascend")).to.be.ok()
end)

it("credits 12 hours offline identically to 12 hours online", function()
    local a, b = Economy.newState(), Economy.newState()

    Economy.advanceToSimulated(a, 12 * 3600)         -- one jump

    for i = 1, 12 * 3600 / 0.25 do                   -- 4 Hz ticking
        Economy.advanceToSimulated(b, i * 0.25)
    end

    -- Relative tolerance, not absolute: these are 1e20-scale numbers.
    expect(relativeError(a.balances.ore, b.balances.ore) < 1e-9).to.equal(true)
end)
```

That second test is the most valuable one in the suite. It is the property that
makes offline progress correct by construction, and it catches every regression
where someone adds a term that only the tick path applies.

### 10.3 Golden-master tests on progression

Balance changes should be *visible in a diff*, not discovered by players.

```lua
--!strict
-- tests/golden/progression.spec.luau
-- The golden file records the simulated hours to reach each milestone.
-- Regenerate deliberately with `lune run tools/regen-golden`, and REVIEW THE DIFF.

local MILESTONES = { 1e6, 1e9, 1e12, 1e18, 1e30, 1e60, 1e120 }

it("matches the recorded progression curve", function()
    local actual = Simulate.timeToMilestones(greedyPolicy, MILESTONES)
    local golden = require("./progression.golden")
    for i, target in MILESTONES do
        -- 2% tolerance absorbs float noise; anything larger is a real change.
        expect(relativeError(actual[i], golden[i]) < 0.02).to.equal(true)
    end
end)
```

Two more golden suites worth having:

- **Migration golden.** A corpus of real saves at every historical schema version;
  assert each migrates to current and passes `validate` (§3.2). Add a new fixture
  every time you ship a migration.
- **Save-size golden.** Assert a fully-maxed save stays under a budget (say 200 KB).
  This is how you catch an unbounded collection the week it is introduced, not the
  month a player becomes unsaveable.

### 10.4 Property tests on the multiplier system

The effect registry (§4.3) has invariants that are cheap to test and expensive to
violate:

```lua
--!strict
-- 1. Registration order cannot change the result.
it("is order-independent", function()
    local effects = randomEffects(50)
    local a = evaluateWith(shuffle(effects))
    local b = evaluateWith(shuffle(effects))
    expect(relativeError(a, b) < 1e-12).to.equal(true)
end)

-- 2. Adding a non-negative effect never decreases the stat.
it("is monotonic in effects", function()
    local base = evaluateWith(effects)
    local more = evaluateWith(append(effects, positiveEffect()))
    expect(more >= base).to.equal(true)
end)

-- 3. Softcaps are monotonic and continuous at the threshold.
it("softcaps are monotonic", function()
    local cap = polynomialSoftcap(1e9, 0.5)
    for _ = 1, 1000 do
        local x1 = 10 ^ (math.random() * 30)
        local x2 = x1 * (1 + math.random())
        expect(cap(x2) >= cap(x1)).to.equal(true)
    end
    expect(relativeError(cap(1e9), 1e9) < 1e-12).to.equal(true)
end)

-- 4. Closed-form buy-max agrees with brute force at small scale.
it("buy-max matches a loop", function()
    for _ = 1, 500 do
        local b = 10 ^ (math.random() * 6)
        local r = 1 + math.random() * 0.5
        local owned = math.random(0, 200)
        local budget = 10 ^ (math.random() * 20)

        local closed = buyMaxGeometric(budget, b, r, owned)

        local brute, spent = 0, 0
        while brute < 100000 do
            local next = b * r ^ (owned + brute)
            if spent + next > budget then break end
            spent += next
            brute += 1
        end

        expect(closed).to.equal(brute)
    end
end)

-- 5. No operation ever produces a non-finite number.
it("never produces NaN or inf", function()
    local state = randomLateGameState()
    for _, stat in ALL_STATS do
        expect(math.isfinite(Effects.evaluate(stat, 1, state))).to.equal(true)
    end
end)
```

### 10.5 Tooling notes

- **Jest Lua** (`jsdotlua/jest-lua`) is what Roblox uses internally for its own apps
  and core scripts, and its README states it "can currently only run inside of
  Roblox" — so a Jest Lua suite needs Studio or `run-in-roblox` in CI.
- **Lune** runs plain Luau outside Roblox with no engine dependency. Pair it with a
  small hand-rolled `expect` (or any pure-Luau runner) for the economy tests, which
  is where the vast majority of your logic lives if you followed §10.1.
- **Mock DataStores.** `ProfileStore.Mock` mirrors the whole ProfileStore API against
  an in-memory store; Lapis ships `nezuo/data-store-service-mock` as a dev
  dependency. Use them for the session-locking and migration tests — those are the
  ones you cannot afford to only test in production.
- **Split your suite.** Economy + migrations run in Lune on every commit (seconds).
  Integration (remotes, replication, ProfileStore) runs in `run-in-roblox` on merge.

---

## Reference state schema

A complete, copy-paste starting point. Everything here is JSON-serialisable, free
of the ProfileStore-documented hazards (no gaps, no mixed tables, no userdata, no
Instances), and shaped so that adding a currency, a generator or a prestige layer
is an additive change.

```lua
--!strict
-- ReplicatedStorage/Shared/Schema.luau

local Schema = {}

Schema.VERSION = 3   -- must equal #Migrations; asserted at startup

export type GeneratorState = {
    count: number,          -- units owned
    level: number,          -- per-generator upgrade level
    unlocked: boolean,
}

export type LayerState = {
    currency: number,       -- spendable layer currency
    lifetime: number,       -- total ever earned in this layer (drives milestones)
    resets: number,         -- number of resets performed
    lastResetAt: number,    -- os.time()
    upgrades: { [string]: true },
}

export type PlayerState = {
    schema: number,

    meta: {
        firstJoinAt: number,
        lastAdvancedAt: number,     -- THE offline anchor (§2). Server os.time().
        lastSaveAt: number,
        sessionCount: number,
        totalPlaytime: number,
        clockAnomalies: number,     -- count of negative-elapsed events (§2.5)
    },

    balances: { [string]: number },      -- currencyId -> amount
    earned:   { [string]: number },      -- currencyId -> lifetime earned

    generators: { [string]: GeneratorState },
    upgrades:   { [string]: true },      -- set; ids prefixed by layer (§5.3)

    prestige: { [string]: LayerState },  -- layerId -> state

    achievements: { [string]: number },  -- achievementId -> completion os.time()

    -- Bounded. Enforce MAX_RECEIPTS in code and assert it at save time.
    receipts: { string },                -- last N granted PurchaseIds (§7.3)

    settings: {
        notation: string,                -- "standard" | "scientific" | "engineering"
        reducedMotion: boolean,
        confirmPrestige: boolean,
        autobuy: { [string]: boolean },  -- generatorId -> enabled
        autobuyReserve: number,
    },

    permanent: { [string]: number },     -- survives every reset; Robux purchases
}

Schema.DEFAULT = {
    schema = Schema.VERSION,
    meta = {
        firstJoinAt = 0, lastAdvancedAt = 0, lastSaveAt = 0,
        sessionCount = 0, totalPlaytime = 0, clockAnomalies = 0,
    },
    balances = { ore = 0 },
    earned   = { ore = 0 },
    generators = {
        -- id -> state. Keep ids short and stable; they are in every save forever.
        g1 = { count = 1, level = 0, unlocked = true },
    },
    upgrades = {},
    prestige = {
        rebirth = { currency = 0, lifetime = 0, resets = 0, lastResetAt = 0, upgrades = {} },
        ascend  = { currency = 0, lifetime = 0, resets = 0, lastResetAt = 0, upgrades = {} },
    },
    achievements = {},
    receipts = {},
    settings = {
        notation = "standard",
        reducedMotion = false,
        confirmPrestige = true,
        autobuy = {},
        autobuyReserve = 0,
    },
    permanent = {},
} :: PlayerState

return Schema
```

**Derived state — never persisted, rebuilt from the above:**

```lua
export type Derived = {
    version: number,             -- bumped on every stored mutation
    computedAtVersion: number,

    -- production.<currencyId>: units per second, after all effects and caps
    rates: { [string]: number },
    -- Polynomial coefficients for the closed form (§1.5, §7.2)
    coeff: { [string]: { number } },
    -- Evaluated stats with their audit trail (§4.3)
    stats: { [string]: number },
    breakdown: { [string]: any },

    -- UI conveniences
    costOfNext: { [string]: number },
    maxAffordable: { [string]: number },
    prestigeGain: { [string]: number },
    timeToNextPurchase: { [string]: number },   -- the §9.2 metric, live
}
```

**Invariants to assert at startup (in Studio) and on a sampled fraction of live
sessions:**

1. `Schema.VERSION == #Migrations`
2. Every `generators` id exists in `Definitions.generators`
3. Every `upgrades` id starts with a known layer prefix
4. Every `prestige` key exists in `Layers`
5. `#state.receipts <= MAX_RECEIPTS`
6. `math.isfinite(v)` for every number in the tree
7. `state.meta.lastAdvancedAt <= os.time()`
8. `state.earned[c] >= state.balances[c]` for every currency `c`

---

## Sources

### Roblox official documentation
Read from the public `Roblox/creator-docs` repository (the source behind
`create.roblox.com/docs`), September 2026.

- **Data store error codes and limits** —
  `content/en-us/cloud-services/data-stores/error-codes-and-limits.md`.
  Source of: the 4,194,304-character per-key limit; 50-character name/key/scope
  limits; 300-character metadata limit; per-key throughput (25 MB/min read,
  4 MB/min write, rounded up to the next kilobyte per request); experience-level
  budgets (`300 + CCU × 40` read, `300 + CCU × 20` write, shared with Open Cloud);
  per-server defaults (`StandardRead`/`StandardWrite` = `60 + numPlayers × 40`,
  `OrderedWrite` = `30 + numPlayers × 5`); the 30-request queue limit; the storage
  formula `500 MB + 1 MB × lifetime users`; and the explicit instruction not to
  pre-compress data.
- **Best practices for data stores** —
  `content/en-us/cloud-services/data-stores/best-practices.md`.
  Source of: one-key-per-player guidance; static key patterns; buffer-in-memory +
  periodic save (the official sample uses 180 s, "shorter than any session-lock
  expiration"); stagger with jitter; retry with backoff and in-order retries per
  key; prefer `UpdateAsync` over `SetAsync`; hot-key sharding; and the statement
  that **DataStore2 is legacy and should not be used for new experiences**.
- **`DataStoreService`** —
  `reference/engine/classes/DataStoreService.yaml`. Source of
  `GetRequestBudgetForRequestType` and `SetRateLimitForRequestType`
  (`rateLimit = baseLimit + perPlayerLimit × numPlayers`, per-request-type
  constraint table, "call once per request type during server initialization",
  `UpdateAsync`/`OnUpdate` not configurable).
- **`GlobalDataStore`** — `reference/engine/classes/GlobalDataStore.yaml`.
  Source of: the 4-second local read cache; `UpdateAsync` retry-until-saved
  semantics and `nil`-cancels-write; the UTF-8 validity requirement ("a single byte
  greater than 127 will not be valid UTF-8 and the `UpdateAsync()` attempt will
  fail"); Set-vs-Update comparison.
- **`DataModel:BindToClose`** — `reference/engine/classes/DataModel.yaml`.
  Source of the 30-second shutdown budget and "bound functions are called in
  parallel".
- **`RunService`** — `reference/engine/classes/RunService.yaml`. Source of the
  frame phase ordering (`PreAnimation → PreSimulation → physics → PostSimulation →
  Heartbeat`), the `Stepped`→`PreSimulation` and `RenderStepped`→`PreRender`
  migration notes, and the `deltaTimeSim` caveat.
- **`os` library** — `reference/engine/libraries/os.yaml`. Source of the
  `os.time()` warning ("uses the device's local clock… users can easily disable sync
  behavior and set the system time to anything they want") and the `os.clock()`
  monotonicity guarantee.
- **`Workspace:GetServerTimeNow`** — `reference/engine/classes/Workspace.yaml`.
  Source of: monotonic, within 0.6% of local clock rate, and "not suitable for
  things like timed rewards, as it is not secure".
- **`MarketplaceService.ProcessReceipt`** —
  `reference/engine/classes/MarketplaceService.yaml`. Source of the delivery
  guarantees (including on join), "set the callback one time in a single server-side
  Script", no time-based retry, no yield timeout, non-deterministic ordering with
  multiple pending purchases, and that unresolved purchases are not refunded.
- **`UnreliableRemoteEvent`** —
  `reference/engine/classes/UnreliableRemoteEvent.yaml`. Source of the 1000-byte
  payload drop threshold and the ~500 requests/second/client shared throttle.
- **Remote events and callbacks** — `content/en-us/scripting/events/remote.md`.
- **Numbers** — `content/en-us/luau/numbers.md`. Source of the double-precision
  range (`±1.7e308`, ~15 digits).
- **`math` library** — `reference/engine/libraries/math.yaml`. Confirms
  `math.isfinite` / `math.isnan` / `math.isinf` exist and that there is **no**
  `math.expm1` (hence the series fallback in §1.6).

### Libraries (source read directly)

- **ProfileStore** — `MadStudioRoblox/ProfileStore`, `ProfileStore.luau`
  (~2,200 lines, single ModuleScript). Source of the API surface, the serialisation
  warnings quoted in §3.2, and the constants: `AUTO_SAVE_PERIOD = 300`,
  `LOAD_REPEAT_PERIOD = 10`, `FIRST_LOAD_REPEAT = 5`, `SESSION_STEAL = 40`,
  `ASSUME_DEAD = 630`, `START_SESSION_TIMEOUT = 120`,
  `CRITICAL_STATE_ERROR_COUNT = 5`, `MAX_MESSAGE_QUEUE = 1000`, and the
  autosave-spreading logic (`auto_save_index_speed = AUTO_SAVE_PERIOD /
  auto_save_list_length`).
- **Lapis** — `nezuo/lapis`, `README.md`, `docs/Migrations.md`, `wally.toml`
  (v0.3.4, depends on `evaera/promise@4.0.0`, dev-depends on
  `nezuo/data-store-service-mock`). Source of the feature list, the declarative
  `migrations` array, the backwards-compatibility hazard ("a player might join a new
  server, leave, and then join an old server"), and the README's own caveat that it
  "has not been battle-tested in a large production game yet".
- **Jest Lua** — `jsdotlua/jest-lua`. Source of "Roblox uses Jest Lua internally"
  and "can currently only run inside of Roblox".
- **Lune** — `lune-org/lune`. Standalone Luau runtime used for the §9.4 harness.
- **Bnum** — `SillyDev2026/Bnum5`. A current Luau big-number library using
  `{sign, logMagnitude}` with `Value = sign × 10^logMagnitude`, `--!native`,
  `--!optimize 2`. `[COMMUNITY, SECOND-HAND]` — cited as an example of the standard
  representation; not benchmarked or audited here.

### Marked claims

- `[UNVERIFIED]` — `HttpService:JSONEncode` behaviour for `nan`/`±math.huge` is not
  specified in the documentation. §3.2's advice (validate with `math.isfinite`
  before saving) is correct regardless; test the specific behaviour in your build if
  you need to depend on it.
- `[UNVERIFIED]` — the logistic-growth closed form in §2.3's table is derived here,
  not taken from a source. Verify numerically against a fine-grained simulation
  before shipping it.
- `[INFERENCE]` — "a Roblox game server's clock is Roblox's machine, not the
  player's" (§2.5). This follows from the architecture but Roblox publishes no
  accuracy guarantee for server-side `os.time()`.
- `[COMMUNITY, SECOND-HAND]` — the prestige-curve attributions (Cookie Clicker's
  cube-root heavenly chips, Antimatter Dimensions' magnitude-exponential infinity
  points and dilation), the smooth offline-cap curve pattern, and the typical
  numeric ranges given for `r`, offline caps and efficiency. These are design
  folklore from the wider incremental-game community, not documented APIs. They are
  reasonable starting points, not authorities.
- Roblox DevForum threads were not used as primary sources; where community practice
  is cited it is marked and traceable to library source code where possible.

---

*Chapter 61. Companion chapters: 46 (code architecture), 47 (security and
anti-exploit), 28 (networking and data architecture), 51 (liveops and analytics).*
