# QA and Verification Methodology for a Roblox Luau Game Port

> **Scope.** A reference chapter for a team porting a large incremental/idle game to Roblox
> Luau, where the acceptance bar is two-fold: the port must be **provably faithful** to the
> original simulation, and it must **not break under real players**. This is a QA chapter, not a
> testing-framework tutorial — the techniques here are chosen because they are the ones that
> actually catch port bugs (drifted formulas, save corruption, precision collapse at high
> magnitudes) rather than the ones that are easiest to write.
>
> **Verification policy for this chapter.** Every API claim below is traced to source I read
> directly (repository source files, official Roblox `creator-docs` markdown, or tool
> documentation in the tool's own repository). Claims I could not confirm against a primary
> source are marked `[UNVERIFIED]`. Community knowledge I could not verify first-hand is marked
> `[COMMUNITY, SECOND-HAND]`. `create.roblox.com`, `devforum.roblox.com` and `luau.org` were not
> reachable from the research environment, so Roblox documentation is cited from its GitHub
> source of record (`Roblox/creator-docs`) and Luau behaviour is cited from the compiler/analysis
> source in `luau-lang/luau`. See [Sources](#sources).

---

## Outline

1. [TL;DR](#tldr)
2. [The testability precondition](#1-the-testability-precondition)
3. [Test frameworks: TestEZ, Jest Lua, and running headless with Lune](#2-test-frameworks-testez-jest-lua-and-running-headless-with-lune)
4. [Golden-master / characterization testing](#3-golden-master--characterization-testing)
5. [Property-based testing](#4-property-based-testing)
6. [Simulation and soak testing](#5-simulation-and-soak-testing)
7. [Save-system testing](#6-save-system-testing)
8. [Static analysis and types](#7-static-analysis-and-types)
9. [The CI workflow](#the-ci-workflow)
10. [In-Studio and in-game QA](#8-in-studio-and-in-game-qa)
11. [Device and platform QA](#9-device-and-platform-qa)
12. [The review rubric](#the-review-rubric)
13. [Sources](#sources)

---

## TL;DR

- **Testability is an architecture decision, not a tooling decision.** The simulation (formulas,
  currency, upgrade costs, offline gain, prestige, save schema) must be a pure Luau module tree
  with **zero `Instance` references, zero service calls, and no ambient time source**. Everything
  the DataModel touches goes behind an injected port. If you get this right, ~80% of the codebase
  runs headlessly; if you get it wrong, no framework rescues you.
- **TestEZ is in maintenance.** Its own docs say "the internals of TestEZ are being reworked, so
  accessing other APIs at this time isn't recommended," and its README still points CI users at
  **Lemur**, a Lua 5.1 Roblox shim that is effectively dead. `TestBootstrap:run(roots, reporter,
  otherOptions)` is verified from source. Use TestEZ only if you already have a large TestEZ suite.
- **Jest Lua (`jsdotlua/jest-lua`) is the better framework, but its README states plainly: "Jest
  Lua can currently only run inside of Roblox."** Lune support is tracked as issue #2 and is not
  done. So Jest Lua gives you the better API and `jest.mock`/fake timers, at the cost of needing
  Studio or `run-in-roblox` in CI.
- **The CI-grade answer is neither: write your simulation tests as plain Luau and run them under
  Lune with a ~120-line runner you own.** Lune's `roblox` library manipulates *place and model
  files*; it has no `require` for `ModuleScript`s, no signals, and no task scheduler bound to
  instances (verified against Lune's own API-status page). It is a file manipulator, not a
  DataModel emulator. Design for that.
- **Stub the Roblox surface with `luau.load(source, { environment = env })`.** Lune's `@lune/luau`
  exposes `compile`/`load` with a `LoadOptions.environment` field — that is the supported hook for
  injecting fake `game`, `task`, `os.clock`, `workspace` globals into a module under test.
- **Golden-master testing is the only technique that proves a port is faithful.** Freeze
  input→output vectors from the *original* game (formula tables, state snapshots at known tick
  counts, full progression traces), commit them as fixtures, and make the port reproduce them
  bit-for-bit or within a declared tolerance. Nothing else catches "the upgrade cost exponent is
  1.15 in the original and 1.115 in the port."
- **Absolute epsilon is wrong.** `math.abs(a - b) < 1e-9` is meaningless at 1e300 (the smallest
  representable gap near 1e300 is ~1e284) and unnecessarily strict at 1e-300. Use a **relative**
  comparison on the mantissa/exponent pair, and for big-number types compare `(layer, sign,
  mag)` structurally with a relative epsilon on `mag` only.
- **Property tests catch the bugs fixtures cannot**: no NaN/Infinity ever reaches the UI,
  currency never goes negative, purchase cost is strictly increasing, offline gain over a span
  equals online gain over the same span, `save → load → save` is a fixed point, and multiplier
  stacking is commutative where the design says it is. A 60-line generator plus a naive shrinker
  is enough; you do not need a library.
- **Soak testing is a first-class deliverable, not a nice-to-have.** Fast-forward 10,000 in-game
  hours headlessly, emit a progression report (currency by hour, first-purchase times, prestige
  cadence), and assert on *representability*: the tick at which a value stops round-tripping
  through your own formatter is a bug, not a curiosity.
- **The save system is where real player harm happens.** Test round-trip fidelity, every historic
  schema version's migration path, truncated/corrupt payloads, session-lock behaviour on rejoin,
  injected DataStore failures, and the **4,194,304-byte per-key limit** as an actual assertion —
  that figure is documented in `Roblox/creator-docs` data-store limits, along with the 50-character
  key-name limit.
- **`--!strict` is a QA tool with a measurable yield.** Track "% of modules at `--!strict`" as a
  release metric. Pair it with Selene (`std = "roblox+testez"`, auto-generated Roblox std) and
  StyLua `--check`. Selene's `divide_by_zero`, `unbalanced_assignments`, `shadowing`,
  `mismatched_arg_count` and `undefined_variable` catch real port bugs; Luau's own linter has 29
  numbered codes, verified from `LinterConfig.h`.
- **Gate merges on a pipeline that runs without Studio**: Rokit installs the toolchain, Wally
  installs packages, StyLua checks format, Selene lints, `luau-lsp analyze` typechecks against a
  Rojo sourcemap, Lune runs the simulation tests and the golden-master suite, Rojo builds the
  place. A concrete workflow YAML is in [The CI workflow](#the-ci-workflow).
- **Ship a debug console that cannot ship enabled.** Gate it on a server-side allowlist plus a
  build-time constant that CI asserts is `false` on the release branch — not on a `RunService`
  check alone, and never on a client-side flag.
- **Assume your tests miss things and build the net**: `ScriptContext.Error` and
  `LogService.MessageOut` piped to an aggregator, staged rollout across place versions, and the
  Creator Hub crashes chart with out-of-memory snapshots (documented in `creator-docs`) as the
  backstop for what unit tests structurally cannot see.
- **The review rubric at the end is the deliverable for auditing AI-generated work.** Every API
  claim cites a verifiable source; every signature is verified rather than plausible; every
  performance number is measured rather than asserted; every snippet is actually runnable. Run it
  mechanically.

---

## 1. The testability precondition

### 1.1 Why the simulation must be pure

An idle game's correctness lives almost entirely in arithmetic: production rates, cost curves,
multiplier stacking, offline accrual, prestige resets, and the save schema that encodes all of it.
None of that arithmetic needs a `Part`, a `RemoteEvent`, or a frame. But in a naive Roblox port it
ends up entangled with all three, because the obvious place to write `currency += rate * dt` is
inside a `RunService.Heartbeat` handler in a `Script` under `ServerScriptService`.

Once that entanglement exists, four things become impossible:

1. **You cannot run the simulation faster than real time.** Verifying 10,000 in-game hours takes
   10,000 hours.
2. **You cannot run it outside Studio.** Every check requires a human pressing Play, so CI cannot
   gate merges.
3. **You cannot compare it to the original.** Golden-master testing needs `f(input) -> output`
   with nothing else in the loop.
4. **You cannot make failures deterministic.** Frame timing, network latency and DataStore
   latency all leak into results, so a red test is ambiguous between "logic bug" and "flaky".

The precondition is therefore stated as a hard rule:

> **Rule 0.** The simulation module tree must be requireable and fully exercisable in a Luau
> environment that has *no* `game`, *no* `Instance`, *no* `task`, and *no* wall clock.

This is testable mechanically — see [§1.5](#15-enforcing-the-boundary-mechanically) — which is
what makes it a QA control and not an aspiration.

### 1.2 The module boundary rules

Split the codebase into four layers. The rules are about *what a module is allowed to reference*,
not about where it sits in the Rojo tree (though the two should agree).

| Layer | May reference | May NOT reference | Testable headlessly |
|---|---|---|---|
| **L0 — Data** | Nothing but Luau literals and types | Everything else | Trivially (it is data) |
| **L1 — Simulation** | L0, other L1 modules, injected ports | `game`, `Instance`, `task`, `os.time`, `os.clock`, `tick`, `math.random` (unseeded), services, `require` of anything in L2/L3 | Yes — this is the 80% |
| **L2 — Adapters** | L1, L0, and exactly one Roblox concern each (DataStore, Remote, Player) | Gameplay decisions | Partially, with fakes |
| **L3 — Presentation / wiring** | Everything | — | No (test in Studio) |

Concretely, for an incremental game:

- **L0** — `Balance/Generators.luau`, `Balance/Upgrades.luau`, `Balance/PrestigeCurve.luau`,
  `SaveSchema/V1.luau` … `SaveSchema/V7.luau`. Pure tables and type aliases.
- **L1** — `Sim/State.luau`, `Sim/Tick.luau`, `Sim/Purchase.luau`, `Sim/Offline.luau`,
  `Sim/Prestige.luau`, `Sim/Multipliers.luau`, `Sim/Serialize.luau`, `Sim/Migrate.luau`,
  `Format/Notation.luau`. **Zero Roblox identifiers anywhere in these files.**
- **L2** — `Adapters/DataStoreAdapter.luau`, `Adapters/RemoteAdapter.luau`,
  `Adapters/ClockAdapter.luau`, `Adapters/RandomAdapter.luau`, `Adapters/TelemetryAdapter.luau`.
- **L3** — `Server/init.server.luau`, `Client/init.client.luau`, all UI.

Three boundary rules do the heavy lifting:

**Rule 1 — No ambient time.** `Sim` never calls `os.clock()`, `os.time()`, `tick()`,
`DateTime.now()`, `task.wait()`, or reads `RunService`. Time arrives as a parameter:

```lua
--!strict
-- Sim/Tick.luau  (L1 — pure)
local Types = require(script.Parent.Parent.Types)

local Tick = {}

--[[
	Advance the simulation by `dt` seconds. Returns a NEW state; never mutates `state`.
	Determinism contract: for a fixed (state, dt) this function returns the same result on
	every platform and every run. No I/O, no clock, no RNG except via `state.rngSeed`.
]]
function Tick.step(state: Types.SimState, dt: number): Types.SimState
	assert(dt >= 0, "dt must be non-negative")
	assert(dt == dt, "dt must not be NaN")

	local next_: Types.SimState = table.clone(state)
	next_.currencies = table.clone(state.currencies)

	local rate = Tick.productionRate(state)             -- pure
	next_.currencies.points = state.currencies.points + rate * dt
	next_.elapsed = state.elapsed + dt
	return next_
end

return Tick
```

**Rule 2 — No ambient randomness.** `math.random` uses a global, per-VM generator; two servers
will diverge. Carry a seeded `Random`-equivalent in state, or inject a `RandomPort`. For an idle
game, prefer *deterministic* derivation: `hash(seed, tickIndex)` so any tick's roll is
reproducible without replaying history.

**Rule 3 — Values in, values out.** `Sim` functions take and return plain tables and numbers (or
your big-number type). They never take a `Player`, never take an `Instance`, never fire a signal.
Signals are an L2/L3 concern; `Sim` returns an **event list** the caller may dispatch:

```lua
--!strict
-- Sim/Purchase.luau  (L1 — pure)
export type PurchaseResult = {
	ok: boolean,
	reason: string?,
	state: Types.SimState,        -- unchanged when ok == false
	events: { Types.SimEvent },   -- e.g. {{ kind = "UpgradeBought", id = "gen1", level = 4 }}
}

function Purchase.buy(state: Types.SimState, upgradeId: string, count: number): PurchaseResult
	...
end
```

The caller (L2) turns `events` into remotes, sounds and analytics. The test asserts on `events`
directly, which is far more precise than asserting "a remote fired".

### 1.3 Dependency injection for the parts that must touch the DataModel

The parts that genuinely need the DataModel are small and enumerable: persistence, remotes,
players, the clock, randomness, telemetry. Give each one a **port** (a type alias describing the
capability) and two implementations: a real adapter and a fake.

```lua
--!strict
-- Ports.luau  (L0 — types only; no runtime dependencies)
export type ClockPort = {
	-- Monotonic seconds since an arbitrary epoch. MUST be monotonic.
	now: () -> number,
	-- Wall-clock UNIX seconds. MAY jump; used only for offline accrual.
	unix: () -> number,
}

export type StorePort = {
	get: (key: string) -> (boolean, string?),          -- ok, payload (nil == no data)
	set: (key: string, payload: string) -> (boolean, string?), -- ok, errMessage
	update: (key: string, transform: (string?) -> string?) -> (boolean, string?),
}

export type RandomPort = { nextNumber: () -> number, nextInteger: (number, number) -> number }

export type TelemetryPort = { event: (name: string, payload: { [string]: any }) -> () }

export type Ports = {
	clock: ClockPort,
	store: StorePort,
	random: RandomPort,
	telemetry: TelemetryPort,
}

return {}
```

Real adapter (L2), the only file in the project allowed to name `DataStoreService`:

```lua
--!strict
-- Adapters/DataStoreAdapter.luau  (L2)
local DataStoreService = game:GetService("DataStoreService")
local Ports = require(script.Parent.Parent.Ports)

local function make(storeName: string, retries: number): Ports.StorePort
	local store = DataStoreService:GetDataStore(storeName)

	local function withRetry<T...>(fn: () -> T...): (boolean, any)
		local lastErr: any = nil
		for attempt = 1, retries do
			local results = table.pack(pcall(fn))
			if results[1] then
				return true, table.unpack(results, 2, results.n)
			end
			lastErr = results[2]
			-- Exponential backoff with jitter, per Roblox data-store best practices.
			task.wait(math.min(2 ^ attempt, 30) * (0.5 + math.random() * 0.5))
		end
		return false, lastErr
	end

	return {
		get = function(key) return withRetry(function() return store:GetAsync(key) end) end,
		set = function(key, payload) return withRetry(function() return store:SetAsync(key, payload) end) end,
		update = function(key, transform)
			return withRetry(function() return store:UpdateAsync(key, transform) end)
		end,
	}
end

return { make = make }
```

Fake adapter (test-only), which is where the interesting QA lives:

```lua
--!strict
-- TestSupport/FakeStore.luau
local FakeStore = {}
FakeStore.__index = FakeStore

export type Failure = "none" | "throw" | "timeout" | "truncate" | "corrupt" | "throttle"

function FakeStore.new()
	return setmetatable({
		data = {} :: { [string]: string },
		calls = {} :: { { op: string, key: string, at: number } },
		failNext = "none" :: Failure,
		failCount = 0,
		budget = math.huge,
	}, FakeStore)
end

function FakeStore:_maybeFail(op: string, key: string): (boolean, string?)
	if self.budget <= 0 then return false, "DataStore request budget exhausted" end
	self.budget -= 1
	if self.failCount > 0 then
		self.failCount -= 1
		local mode = self.failNext
		if mode == "throw" then return false, "502: API Services rejected request" end
		if mode == "timeout" then return false, "504: Gateway Timeout" end
		if mode == "throttle" then return false, "Request was throttled" end
	end
	return true, nil
end

function FakeStore:port()
	local self_ = self
	return {
		get = function(key)
			table.insert(self_.calls, { op = "get", key = key, at = #self_.calls })
			local ok, err = self_:_maybeFail("get", key)
			if not ok then return false, err end
			local payload = self_.data[key]
			if payload and self_.failNext == "truncate" and self_.failCount > 0 then
				self_.failCount -= 1
				payload = string.sub(payload, 1, math.max(1, #payload // 2))
			elseif payload and self_.failNext == "corrupt" and self_.failCount > 0 then
				self_.failCount -= 1
				payload = payload:gsub("%d", "x", 3)
			end
			return true, payload
		end,
		set = function(key, payload)
			table.insert(self_.calls, { op = "set", key = key, at = #self_.calls })
			local ok, err = self_:_maybeFail("set", key)
			if not ok then return false, err end
			-- Enforce the real platform limit as a test assertion, not a comment.
			assert(#payload <= 4 * 1024 * 1024,
				("payload %d bytes exceeds the 4,194,304-byte DataStore value limit"):format(#payload))
			self_.data[key] = payload
			return true, nil
		end,
		update = function(key, transform)
			local ok, err = self_:_maybeFail("update", key)
			if not ok then return false, err end
			self_.data[key] = transform(self_.data[key])
			return true, nil
		end,
	}
end

return FakeStore
```

The `#payload <= 4 * 1024 * 1024` assertion encodes a documented platform limit: `Roblox/creator-docs`
lists the data-store value size limit as **4,194,304 bytes per key**, and notes you can measure the
serialized length with `HttpService:JSONEncode()`. Putting the limit in the *fake* means every test
that saves anything is also a size-budget test, for free.

### 1.4 Mocking an `Instance`-shaped dependency without an Instance

Sometimes an L2 module legitimately wants an object with `.Value`, `:GetAttribute()`, or
`:FireClient()`. Do not reach for a full DataModel emulator; write the two-screen stub:

```lua
--!strict
-- TestSupport/FakeRemote.luau
local FakeRemote = {}
FakeRemote.__index = FakeRemote

function FakeRemote.new(name: string)
	return setmetatable({ Name = name, sent = {}, handlers = {} }, FakeRemote)
end

function FakeRemote:FireClient(player: any, ...)
	table.insert(self.sent, { player = player, args = table.pack(...) })
end

function FakeRemote:FireAllClients(...)
	table.insert(self.sent, { player = "*", args = table.pack(...) })
end

-- Mimic the `.OnServerEvent:Connect(fn)` shape without a real RBXScriptSignal.
function FakeRemote:__buildSignal()
	local conns = {}
	return {
		Connect = function(_, fn)
			table.insert(conns, fn)
			return { Disconnect = function() end, Connected = true }
		end,
		_fire = function(_, ...)
			for _, fn in conns do fn(...) end
		end,
	}
end

return FakeRemote
```

The discipline that makes this cheap: **the stub only has to satisfy the port's type**, because L1
never sees it and L2 uses exactly the three members you stubbed. If a stub starts growing methods,
that is a signal your L2 adapter has absorbed gameplay logic that belongs in L1.

### 1.5 Enforcing the boundary mechanically

A rule nobody checks is a rule nobody follows. Two cheap enforcers, both runnable in CI:

**(a) A grep gate over the simulation tree.** Fails the build if any forbidden identifier appears
in an L1 file.

```bash
# scripts/check-purity.sh — run in CI, exit non-zero on violation
set -euo pipefail
FORBIDDEN='\bgame\b|\bworkspace\b|\bscript\b|\bInstance\.|\bEnum\.|\btask\.|\bos\.time\b|\bos\.clock\b|\btick\(|RunService|DataStoreService|\bmath\.random\b|\bwait\('
if grep -REn "$FORBIDDEN" src/Shared/Sim src/Shared/Balance src/Shared/Format ; then
  echo "ERROR: simulation layer references a non-pure identifier (see matches above)" >&2
  exit 1
fi
echo "purity gate: OK"
```

Note `\bscript\b` in the list: a module that references `script` at all cannot be loaded outside a
`ModuleScript`, which is exactly what we are preventing. That has a consequence for how L1 modules
require each other — see [§2.4](#24-requires-that-work-in-both-worlds).

**(b) A load-time gate in the headless runner.** Load every L1 module in a sandboxed environment
where every Roblox global is a trap, and fail if one is touched. Lune's `@lune/luau` `load`
accepts a `LoadOptions.environment`, documented as "A custom environment to load the chunk in",
which is the supported mechanism:

```lua
--!strict
-- tests/purity_env.luau — used by the Lune runner
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local function trap(name: string)
	return setmetatable({}, {
		__index = function() error(("purity violation: simulation touched `%s`"):format(name), 3) end,
		__newindex = function() error(("purity violation: simulation wrote `%s`"):format(name), 3) end,
		__call = function() error(("purity violation: simulation called `%s`"):format(name), 3) end,
	})
end

local function sandbox(extra: { [string]: any }?): { [string]: any }
	local env: { [string]: any } = {
		-- Allowed Luau surface
		assert = assert, error = error, ipairs = ipairs, pairs = pairs, next = next,
		pcall = pcall, xpcall = xpcall, select = select, setmetatable = setmetatable,
		getmetatable = getmetatable, rawget = rawget, rawset = rawset, rawequal = rawequal,
		rawlen = rawlen, tonumber = tonumber, tostring = tostring, type = type, typeof = typeof,
		unpack = table.unpack, string = string, table = table, bit32 = bit32, buffer = buffer,
		utf8 = utf8, coroutine = coroutine, print = print,
		-- math minus the global RNG
		math = setmetatable({ random = nil, randomseed = nil }, { __index = math }),
		-- Traps
		game = trap("game"), workspace = trap("workspace"), script = trap("script"),
		Instance = trap("Instance"), task = trap("task"), os = trap("os"),
		tick = trap("tick"), wait = trap("wait"), spawn = trap("spawn"), delay = trap("delay"),
		Enum = trap("Enum"), require = trap("require"), -- replaced below by the runner's loader
	}
	if extra then for k, v in extra do env[k] = v end end
	env._G = env
	return env
end

return { sandbox = sandbox, trap = trap }
```

Running the whole L1 tree through this sandbox once, at the top of the test suite, converts "we
have a convention" into "the build fails". That is the difference between a QA process and a wiki
page.

---
