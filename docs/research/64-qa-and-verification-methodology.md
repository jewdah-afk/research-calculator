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
require each other — see [§2.4](#24-running-tests-headlessly-outside-studio-with-lune).

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

## 2. Test frameworks: TestEZ, Jest Lua, and running headless with Lune

### 2.1 TestEZ — current status and verified API

`Roblox/testez` is a BDD-style framework. Its README states it "can run within Roblox itself, as
well as inside [Lemur](https://github.com/LPGhatguy/Lemur) for testing on CI systems", and that
Roblox uses it internally for apps, core scripts, Studio plugins, Roact and Rodux. Two caveats
matter for a new port:

- The **"Running Tests"** doc page says: *"The internals of TestEZ are being reworked, so accessing
  other APIs at this time isn't recommended."* That text has been in the repo for a long time; treat
  TestEZ as **stable but in maintenance**, not as the growing option. `[UNVERIFIED]` — I could not
  confirm any formal deprecation announcement, only the absence of recent feature work.
- Its CI story points at **Lemur**, a Lua 5.1 Roblox-API shim. Lemur has not kept pace with Luau
  (no `task`, no modern `string`/`table` additions, no type syntax). Do not plan a 2026 pipeline
  around it.

Verified entry point, read from `src/TestBootstrap.lua` at `master`:

```lua
-- Signature verified in Roblox/testez @ master, src/TestBootstrap.lua
function TestBootstrap:run(roots, reporter, otherOptions)
-- roots        : table (array of Instances to scan for `*.spec` ModuleScripts) — errors if not a table
-- reporter     : defaults to Reporters.TextReporter
-- otherOptions : { showTimingInfo: boolean?, testNamePattern: string?, extraEnvironment: table? }
-- returns      : the TestResults object
```

Discovery is `Instance`-based: `isSpecScript` requires `aScript:IsA("ModuleScript")` and
`aScript.Name:match("%.spec$")`, and `init.spec` files attach to their parent folder's `describe`
block rather than creating their own. The public surface (verified from `docs/api-reference.md`):
`describe`, `it`, `expect`, `beforeAll`/`beforeEach`/`afterEach`/`afterAll`, `FOCUS`/`SKIP`/`FIXME`,
`describeFOCUS`/`describeSKIP` (aliases `fdescribe`/`xdescribe`), `itFOCUS`/`itSKIP`/`itFIXME`
(aliases `fit`/`xit`), and a write-once `context` table passed to hooks and `it` callbacks.

Matchers, verified from `src/Expectation.lua`: `:a(typeName)` / `:an(...)`, `:ok()`,
`:equal(value)`, `:near(value, limit?)`, `:throw(messageSubstring?)`, the `never` modifier, and
`Expectation:extend(matchers)` for custom matchers. **That is the whole matcher set.** There is no
`toMatchSnapshot`, no deep-equality matcher, no mocking. For a port you will write your own deep
comparison (which you want anyway, for tolerance policy — see [§3.3](#33-tolerance-policy)).

`:near(a, b, limit)` uses an **absolute** limit. That makes it unusable for big numbers; see
[§3.3](#33-tolerance-policy) for why and what to use instead.

### 2.2 Jest Lua — current status and verified API

`jsdotlua/jest-lua` is a port of JavaScript Jest, aligned to upstream Jest v27.4.7 per its README
(the CHANGELOG records an upgrade to v28.0.0 semantics in 3.4.0). Roblox uses it internally; the
README calls it "battle-tested and ready for production use". Latest version referenced in the
repository's own docs and README is **3.10.0** (2024-10-02 in `CHANGELOG.md`).

The decisive constraint, quoted from the README: **"Jest Lua can currently only run inside of
Roblox. Help is wanted to get it running in other Lua environments, such as Lune or Luvit. See
issue #2."** The Getting Started page repeats it: *"Jest Lua currently requires `run-in-roblox` to
run from the command line."*

Install and entry point, verified from `docs/docs/GettingStarted.md`:

```toml
# wally.toml
[dev-dependencies]
Jest = "jsdotlua/jest@3.10.0"
JestGlobals = "jsdotlua/jest-globals@3.10.0"
```

```lua
-- run-tests.lua (verified shape from Jest Lua's Getting Started page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local runCLI = require("@DevPackages/Jest").runCLI

local processServiceExists, ProcessService = pcall(function()
	return game:GetService("ProcessService")
end)

local status, result = runCLI(ReplicatedStorage.Packages.Project, {
	verbose = false,
	ci = false,
}, { ReplicatedStorage.Packages.Project }):awaitStatus()

if status == "Resolved" and result.results.numFailedTestSuites == 0
	and result.results.numFailedTests == 0 then
	if processServiceExists then ProcessService:ExitAsync(0) end
end
if processServiceExists then ProcessService:ExitAsync(1) end
```

```lua
-- src/jest.config.lua
return { testMatch = { "**/*.spec" } }
```

What you get over TestEZ: `expect` with the full Jest matcher family, `toMatchSnapshot`,
`jest.fn()`/`jest.mock`/`jest.spyOn` (`spyOn` added in 3.6.2; spying on Lua globals in 3.9.0), fake
timers including a mocked `task.wait` (3.8.0) and a configurable engine frame time (3.3.0),
`redactStackTrace` for stable snapshots (3.10.0), and `JestBenchmark` (3.4.0).

### 2.3 Which to choose

| Situation | Choose |
|---|---|
| Greenfield port, CI must gate merges, most tests are pure simulation | **Plain Luau + your own Lune runner** for L1/L2; Jest Lua for the Studio-only slice |
| You need snapshots, mocks or fake timers for UI/adapters | **Jest Lua** (accept `run-in-roblox` in CI, or run it as a nightly/manual job) |
| You already have thousands of TestEZ specs | **Keep TestEZ**; do not rewrite. Add a Lune path for new pure tests |
| You want one framework everywhere and can afford Studio in CI | **Jest Lua** |

For an incremental-game port the recommendation is unambiguous: **the golden-master, property and
soak suites — the ones that actually prove fidelity — should not depend on any Roblox-aware
framework at all.** They are pure functions over pure data. Making them depend on Studio is
self-inflicted.

### 2.4 Running tests headlessly outside Studio with Lune

**What Lune is and is not.** Lune is "a standalone Luau runtime" (README). Its Roblox library is
described as APIs "for manipulating Roblox place files and model files". The verified function
list is `deserializePlace`, `deserializeModel`, `serializePlace`, `serializeModel`, `getAuthCookie`,
`getReflectionDatabase`, `implementProperty`, `implementMethod`, `studioApplicationPath`,
`studioContentPath`, `studioPluginPath`, `studioBuiltinPluginPath`, plus `roblox.Instance.new`.

The API-status page lists exactly which `Instance` members exist: `new` (no second `parent`
argument), `AddTag`, `Clone`, `Destroy`, `ClearAllChildren`, the `FindFirstAncestor*`/
`FindFirstChild*` family, `GetAttribute(s)`, `GetChildren`, `GetDescendants`, `GetFullName`,
`GetTags`, `HasTag`, `IsA`, `IsAncestorOf`, `IsDescendantOf`, `RemoveTag`, `SetAttribute`; and for
`DataModel` only `GetService` and `FindService`.

> **The consequence teams miss:** there is **no `require` for a `ModuleScript`**, no
> `RBXScriptSignal`, no `Changed`, no `task` bound to instances, and no script execution. Lune
> cannot *run* a Roblox place. So **TestEZ's `TestBootstrap:run` cannot work under Lune
> unaltered** — its discovery calls `require(current)` on `ModuleScript` instances, which Lune does
> not implement. Any claim that you can "just point TestEZ at Lune" is wrong.

**The architecture that does work:** L1 modules live on disk as `.luau` files, require each other
by *path*, and the runner is Lune-native.

```lua
-- Sim/Purchase.luau — requires that work in BOTH worlds
-- Under Lune: relative-path require. Under Roblox: Rojo maps the same file, and a small
-- `require` shim (below) resolves the same string to the ModuleScript.
local Balance = require("../Balance/Upgrades")
```

Two workable strategies for dual-world requires:

1. **Luau aliases (`.luaurc`) + Rojo path parity.** Declare aliases so both runtimes resolve the
   same string:
   ```json
   // .luaurc
   { "languageMode": "strict",
     "aliases": { "sim": "./src/Shared/Sim", "balance": "./src/Shared/Balance" } }
   ```
   `[UNVERIFIED]` — alias support in Roblox's own `require` has shipped in stages and behaviour
   differs by context; verify against your current Studio version before relying on it, and keep
   strategy 2 as a fallback.
2. **A single `Require.luau` indirection** that L1 modules call, implemented twice (Lune version
   uses `require(path)`, Roblox version walks `ReplicatedStorage`). One file differs between
   worlds; everything else is identical. This is boring and always works.

**The runner.** Roughly 120 lines, and you own it:

```lua
--!strict
-- tests/run.luau — invoked as `lune run tests/run`
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

type Case = { name: string, fn: () -> (), only: boolean, skip: boolean }
local stack: { string } = {}
local cases: { Case } = {}
local befores: { { depth: number, fn: () -> () } } = {}
local afters: { { depth: number, fn: () -> () } } = {}
local anyOnly = false

local function join(): string return table.concat(stack, " › ") end

local G: { [string]: any } = {}
function G.describe(name: string, body: () -> ())
	table.insert(stack, name); body(); table.remove(stack)
end
function G.it(name: string, fn: () -> ())
	table.insert(stack, name)
	table.insert(cases, { name = join(), fn = fn, only = false, skip = false })
	table.remove(stack)
end
function G.itOnly(name: string, fn: () -> ())
	anyOnly = true
	G.it(name, fn); cases[#cases].only = true
end
function G.itSkip(name: string, fn: () -> ())
	G.it(name, fn); cases[#cases].skip = true
end
function G.beforeEach(fn: () -> ()) table.insert(befores, { depth = #stack, fn = fn }) end
function G.afterEach(fn: () -> ()) table.insert(afters, { depth = #stack, fn = fn }) end

-- Collect spec files.
local function collect(dir: string, out: { string })
	for _, entry in fs.readDir(dir) do
		local p = dir .. "/" .. entry
		if fs.isDir(p) then
			collect(p, out)
		elseif entry:match("%.spec%.luau$") then
			table.insert(out, p)
		end
	end
	return out
end

local specFiles = collect("src", {})
table.sort(specFiles)

-- Register: each spec file returns a function that calls describe/it.
for _, path in specFiles do
	local mod = require("../" .. path:gsub("%.luau$", ""))
	-- Inject the DSL by passing it in; avoids global mutation and keeps specs pure.
	mod(G)
end

local passed, failed, skipped = 0, 0, 0
local failures: { { name: string, err: string } } = {}
local t0 = os.clock()

for _, case in cases do
	if case.skip or (anyOnly and not case.only) then
		skipped += 1
		continue
	end
	for _, b in befores do b.fn() end
	local ok, err = xpcall(case.fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end)
	for _, a in afters do a.fn() end
	if ok then
		passed += 1
		stdio.write(stdio.color("green") .. "." .. stdio.color("reset"))
	else
		failed += 1
		failures[#failures + 1] = { name = case.name, err = err :: string }
		stdio.write(stdio.color("red") .. "F" .. stdio.color("reset"))
	end
end

print(("\n\n%d passed, %d failed, %d skipped in %.2fs")
	:format(passed, failed, skipped, os.clock() - t0))
for _, f in failures do
	print(stdio.color("red") .. "FAIL " .. f.name .. stdio.color("reset") .. "\n" .. f.err)
end
process.exit(if failed == 0 then 0 else 1)
```

A spec file is then a plain module that takes the DSL:

```lua
--!strict
-- src/Shared/Sim/Purchase.spec.luau
local Purchase = require("./Purchase")
local expect = require("../../../tests/expect")

return function(t)
	t.describe("Purchase.buy", function()
		t.it("refuses when the player cannot afford it", function()
			local state = { currencies = { points = 10 }, levels = { gen1 = 0 } }
			local r = Purchase.buy(state, "gen1", 1)
			expect(r.ok).toBe(false)
			expect(r.reason).toBe("insufficient_funds")
			expect(r.state).toBe(state)  -- identity: no mutation on failure
		end)
	end)
end
```

**Running it:** `lune run tests/run`. Exit code 0/1 is what CI gates on — `@lune/process` exposes
`process.exit`, verified in the Lune API reference.

### 2.5 Stubbing the Roblox surface a "pure" module still touches

Even a disciplined L1 tree sometimes wants `Vector2`, `os.clock` for an internal profiler, or a
`Random`. Three tiers, cheapest first:

**Tier 1 — inject it.** Preferred. Pass a `ClockPort`, not a global.

**Tier 2 — supply a tiny pure-Luau implementation.** For datatypes, Lune already ships many
(`CFrame`, `Color3`, `UDim2`, `Vector2`, `Vector3`, `NumberSequence`, `Enum`, and others — full list
verified on the API-status page) via `require("@lune/roblox")`. Bind them into the test's globals:

```lua
local roblox = require("@lune/roblox")
local shim = {
	Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	UDim2 = roblox.UDim2, Enum = roblox.Enum, Instance = roblox.Instance,
}
```

**Tier 3 — load the module in a controlled environment.** Use `luau.load` with `environment` to
give a module a bespoke global table. This is the only mechanism that also lets you *detect*
accidental reliance on a global (make the entry a trap, as in [§1.5](#15-enforcing-the-boundary-mechanically)):

```lua
--!strict
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local function loadWithEnv(path: string, env: { [string]: any })
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = env,
		injectGlobals = true,  -- keep the standard Luau globals; env entries win
	})
	return chunk()
end
```

`CompileOptions` (`optimizationLevel`, `coverageLevel`, `debugLevel`) and `LoadOptions`
(`debugName`, `environment`, `injectGlobals`, `codegenEnabled`) are verified from Lune's `luau`
API reference. Note its own warning: *"Setting a custom environment will deoptimize the chunk and
forcefully disable codegen."* Use it for purity gates and targeted stubbing, not for the hot path
of a 10,000-hour soak run.

**The honest trade-off table:**

| Approach | Fidelity to Roblox | Speed | CI-able without Studio |
|---|---|---|---|
| Pure Luau + Lune runner | N/A (no Roblox needed) | Fastest | Yes |
| Lune + `@lune/roblox` datatypes | Datatypes only; no engine behaviour | Fast | Yes |
| Jest Lua + `run-in-roblox` | Full engine | Slow (Studio boot per run) | Only on a runner with Studio installed (Windows/macOS) |
| TestEZ in Studio, run by hand | Full engine | Human-speed | No |

`run-in-roblox` (`rojo-rbx/run-in-roblox`) "runs a place, a model, or an individual script inside
Roblox Studio" and "pipes output from inside Roblox Studio back to stdout/stderr"; usage is
`run-in-roblox --place MyPlace.rbxlx --script starter-script.lua`, with `--script` required and
`--place` optional. Because it drives Studio, it needs a machine with Studio — GitHub's
`ubuntu-latest` runners cannot do it. `[COMMUNITY, SECOND-HAND]` Teams that need it typically use a
self-hosted Windows runner; I could not verify a first-party Roblox-supported hosted option.

---

## 3. Golden-master / characterization testing

This is the technique that makes "provably faithful" a checkable claim rather than a hope. You do
not try to re-derive the original game's intent; you **freeze its observed behaviour** and require
the port to reproduce it.

### 3.1 What to capture

Capture at three granularities, because each catches a different class of drift:

| Fixture kind | Shape | Catches |
|---|---|---|
| **Formula tables** | `input → output` for every pure function, swept across the magnitude range | Transcription errors in exponents/coefficients; off-by-one in level indexing |
| **State snapshots** | Full `SimState` at tick counts `{0, 1, 10, 100, 1e3, 1e4, 1e5, 1e6, 1e7}` | Accumulated drift; wrong update order; integer/float divergence |
| **Progression traces** | A scripted action script (`buy gen1 @t=30s`, `prestige @t=3600s`, …) plus the state after each action | Interaction bugs between subsystems; wrong reset semantics |

The action-script trace is the highest-value fixture and the one most teams skip. It is the only
one that exercises *ordering*.

### 3.2 Fixture format

Use **newline-delimited JSON (NDJSON)**, one record per line, rather than one big JSON document.
Reasons: it diffs line-by-line in review, it streams (a 10M-row formula sweep does not have to fit
in memory), and a regeneration that changes one row produces a one-line diff.

```
# fixtures/formula/upgrade_cost.ndjson   (schema line first, then records)
{"$schema":1,"fn":"Upgrades.costAt","source":"original-v4.2.1","generated":"2026-02-11T08:14:02Z","tolerance":{"kind":"relative","eps":1e-12}}
{"in":{"id":"gen1","level":0},"out":"10"}
{"in":{"id":"gen1","level":1},"out":"11.5"}
{"in":{"id":"gen1","level":250},"out":"1.3780e15"}
{"in":{"id":"gen1","level":100000},"out":"e6069.7534"}
```

Rules that pay for themselves:

- **Numbers are strings.** A JSON number round-trips through the encoder's float formatter and can
  lose the last bits; a string is exactly what the source produced. Parse it in the test.
- **Every file carries a header record** with `$schema`, the source build identifier, the
  generation timestamp, and the tolerance policy that applies to it. A fixture without provenance
  is not evidence.
- **One file per function / per trace.** Never one giant `golden.json`.
- **Sweep log-uniformly, not linearly.** An idle game spends most of its life between 1e12 and
  1e300; a linear sweep of levels 1–1000 tests almost none of the interesting range. Sample
  `level = round(10^(k/8))` for `k = 0 … 8*log10(maxLevel)`, plus every boundary the design names
  (soft-cap thresholds, tier transitions, the first level where a formula switches branch).
- **Always include the pathological inputs**: `0`, `1`, `-0`, the largest level reachable in a
  year of play, the level at which the original itself produced `Infinity`.

### 3.3 Tolerance policy

**Absolute epsilon is wrong for this domain.** IEEE-754 doubles have 53 bits of mantissa, so the
gap between adjacent representable values near a magnitude `m` is about `m * 2^-52 ≈ m * 2.2e-16`.
Near 1e300 that gap is roughly **2e284**. A test written as `math.abs(a - b) < 1e-9` is therefore:

- **Vacuous** above ~1e7, where `1e-9` is far below one ULP — it passes for any two values that are
  merely close-ish, and it *cannot fail* for two values that differ by less than one representable
  step, which is fine, but it also cannot distinguish 1e300 from 1.000000001e300.
- **Absurdly strict** below ~1e-9, where two correct results differing in the last bit fail.

Use relative error, with an absolute floor only for values genuinely near zero:

```lua
--!strict
-- tests/approx.luau
local Approx = {}

-- Relative comparison. `relEps` is a fraction (1e-12 == "agree to ~12 significant digits").
-- `absFloor` handles the neighbourhood of zero, where relative error is undefined.
function Approx.close(a: number, b: number, relEps: number?, absFloor: number?): (boolean, string?)
	local rel = relEps or 1e-12
	local floor = absFloor or 1e-300

	if a ~= a or b ~= b then                      -- NaN never compares equal, including to itself
		return false, ("NaN encountered (a=%s b=%s)"):format(tostring(a), tostring(b))
	end
	if a == b then return true end                -- also handles ±inf == ±inf
	if a == math.huge or b == math.huge or a == -math.huge or b == -math.huge then
		return false, ("infinity mismatch (a=%s b=%s)"):format(tostring(a), tostring(b))
	end

	local diff = math.abs(a - b)
	if diff <= floor then return true end
	local scale = math.max(math.abs(a), math.abs(b))
	local err = diff / scale
	if err <= rel then return true end
	return false, ("relative error %.3e exceeds %.3e (a=%.17g b=%.17g)"):format(err, rel, a, b)
end

return Approx
```

For a **big-number type** (layered/tetrational representations such as `{sign, layer, mag}`), do
*not* convert to `number` and compare — that throws away everything above 1e308. Compare
structurally:

```lua
--!strict
-- Compare two layered big numbers. `sign` and `layer` must match EXACTLY;
-- only `mag` gets a relative tolerance, and the tolerance tightens as layer rises,
-- because at layer >= 2 a tiny mag difference is an enormous value difference.
function Approx.closeBig(a, b, relEps: number?): (boolean, string?)
	if a.sign ~= b.sign then return false, "sign mismatch" end
	if a.layer ~= b.layer then
		return false, ("layer mismatch (%d vs %d)"):format(a.layer, b.layer)
	end
	-- At layer 0 the value IS mag. At layer 1 the value is 10^mag, so a relative error of e in
	-- mag becomes a relative error of ~ln(10)*mag*e in the value: scale the budget down.
	local budget = (relEps or 1e-12)
	if a.layer >= 1 then budget = budget / math.max(1, math.abs(a.mag)) end
	return Approx.close(a.mag, b.mag, budget)
end
```

Policy, written down once and referenced by every fixture header:

| Quantity | Tolerance | Rationale |
|---|---|---|
| Integer counts (levels, purchases, prestige count) | **exact** | Any drift is a bug, full stop |
| Currency / production at layer 0 | `relEps = 1e-12` | ~12 significant digits; absorbs reassociation, not logic drift |
| Layered big numbers | exact `sign`+`layer`; `mag` at `1e-12 / max(1,|mag|)` | See above |
| Values derived from `math.exp`/`math.log`/`^` chains | `relEps = 1e-9` | Transcendental implementations differ across platforms |
| Anything reaching the UI as a formatted string | **exact string equality** | Formatting is deterministic; a diff here is user-visible |

`[UNVERIFIED]` — the claim that `math.exp`/`math.pow` results are bit-identical across the
platforms Roblox ships on is one I could not confirm. Assume they are not, and set the
transcendental tolerance accordingly; if your golden-master suite is green at `1e-15` on every
platform you test, tighten it.

### 3.4 The comparison harness

```lua
--!strict
-- tests/golden.luau
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Approx = require("./approx")

local Golden = {}

function Golden.load(path: string): ({ [string]: any }, { any })
	local lines = string.split(fs.readFile(path), "\n")
	local header, records = nil, {}
	for _, line in lines do
		if line == "" then continue end
		local rec = serde.decode("json", line)
		if rec["$schema"] then header = rec else table.insert(records, rec) end
	end
	assert(header, ("fixture %s has no header record"):format(path))
	return header, records
end

-- Verify `fn` against a formula fixture. Returns a failure list, capped for readability,
-- plus the total count so a report can say "3 of 41,802 rows differ".
function Golden.verify(path: string, fn: (any) -> any, encode: (any) -> string)
	local header, records = Golden.load(path)
	local tol = header.tolerance or { kind = "relative", eps = 1e-12 }
	local failures, checked = {}, 0
	for i, rec in records do
		checked += 1
		local actual = fn(rec["in"])
		local expected = rec.out
		local ok, why
		if tol.kind == "exact" then
			ok = (encode(actual) == expected)
			why = ok and nil or ("expected %s got %s"):format(expected, encode(actual))
		else
			ok, why = Approx.close(tonumber(encode(actual)) :: number, tonumber(expected) :: number, tol.eps)
		end
		if not ok and #failures < 20 then
			table.insert(failures, ("row %d (%s): %s"):format(i, serde.encode("json", rec["in"]), why))
		end
	end
	return failures, checked
end

return Golden
```

### 3.5 Regenerating fixtures safely

Regeneration is the single most dangerous operation in this whole methodology, because a
regenerated fixture **silently blesses whatever the port currently does**. Controls:

1. **Fixtures are generated from the original, never from the port.** The generator is a separate
   script that runs against the source game (its JS/whatever build), committed under
   `tools/capture/`. There is no code path that writes a fixture from Luau. If your original is no
   longer runnable, capture once, archive the capture tool and its inputs, and treat the fixtures
   as a read-only artifact from then on.
2. **`--regenerate` is not a flag on the test runner.** Make it a separate command in a separate
   directory so it cannot be reached by muscle memory or by an agent "fixing the failing test".
3. **Every regeneration is its own PR, touching only fixtures.** No source changes in the same
   commit. The diff is then reviewable: "12,004 rows changed" is a red flag; "3 rows changed, all
   in the new tier-7 range" is a reviewable claim.
4. **Record provenance in the header** (source build id + timestamp + capture-tool commit) and have
   CI assert the header exists and its `source` matches an allowlist of known original builds.
5. **Keep a `frozen/` subtree** for fixtures that must never change — the level-0 through level-1000
   cost table, the v1 save format. CI fails on any diff under `frozen/`, regardless of PR contents.

```bash
# scripts/check-frozen.sh
git diff --name-only "origin/${BASE_REF}...HEAD" | grep -q '^fixtures/frozen/' \
  && { echo "ERROR: fixtures/frozen/ is immutable"; exit 1; } || echo "frozen fixtures untouched"
```
(Uses git only as a CI gate; the rule is what matters, adapt to your CI's diff mechanism.)

---

## 4. Property-based testing

Golden masters prove the port matches the original *on the inputs you captured*. Properties cover
the inputs you did not think of. For an idle game the high-yield invariants are few and specific.

### 4.1 A minimal generator + shrinker in Luau

You do not need a library. ~70 lines gives generation, seeding (so failures reproduce), and naive
shrinking (so failures are readable).

```lua
--!strict
-- tests/prop.luau
local Prop = {}

-- Deterministic PRNG so a failing seed reproduces exactly. xoshiro-ish; any seeded PRNG works.
local function rng(seed: number)
	local s = seed % 2147483647
	if s <= 0 then s += 2147483646 end
	return function(): number
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

export type Gen<T> = { gen: (r: () -> number, size: number) -> T, shrink: (T) -> { T } }

function Prop.int(lo: number, hi: number): Gen<number>
	return {
		gen = function(r) return lo + math.floor(r() * (hi - lo + 1)) end,
		-- Shrink toward lo, then halve the distance: 1000 -> {lo, 500, 750, 999}
		shrink = function(v)
			local out = {}
			if v > lo then table.insert(out, lo) end
			local mid = lo + (v - lo) // 2
			if mid ~= v and mid ~= lo then table.insert(out, mid) end
			if v - 1 >= lo and v - 1 ~= mid then table.insert(out, v - 1) end
			return out
		end,
	}
end

-- Log-uniform magnitudes: the distribution an idle game actually lives in.
function Prop.magnitude(minExp: number, maxExp: number): Gen<number>
	return {
		gen = function(r) return 10 ^ (minExp + r() * (maxExp - minExp)) end,
		shrink = function(v) return { 1, math.sqrt(math.max(v, 1)) } end,
	}
end

function Prop.list<T>(item: Gen<T>, maxLen: number): Gen<{ T }>
	return {
		gen = function(r, size)
			local n, out = math.floor(r() * math.min(size, maxLen)), {}
			for _ = 1, n do table.insert(out, item.gen(r, size)) end
			return out
		end,
		shrink = function(v)
			if #v == 0 then return {} end
			local half = table.move(v, 1, #v // 2, 1, {})
			local drop1 = table.move(v, 2, #v, 1, {})
			return { {}, half, drop1 }
		end,
	}
end

-- forAll: run `trials` cases, and on failure shrink greedily until no shrink still fails.
function Prop.forAll<T>(name: string, g: Gen<T>, predicate: (T) -> (boolean, string?), opts: {
	trials: number?, seed: number?, size: number?
}?)
	local o = opts or {}
	local trials, seed, size = o.trials or 200, o.seed or 1, o.size or 32
	local r = rng(seed)
	for trial = 1, trials do
		local value = g.gen(r, size)
		local ok, why = predicate(value)
		if not ok then
			local best, bestWhy, guard = value, why, 0
			while guard < 200 do
				guard += 1
				local improved = false
				for _, candidate in g.shrink(best) do
					local cok, cwhy = predicate(candidate)
					if not cok then best, bestWhy, improved = candidate, cwhy, true; break end
				end
				if not improved then break end
			end
			error(("property %q failed on trial %d (seed=%d)\n  minimal counterexample: %s\n  %s")
				:format(name, trial, seed, tostring(best), tostring(bestWhy)), 2)
		end
	end
end

return Prop
```

### 4.2 The invariants worth asserting

```lua
--!strict
-- src/Shared/Sim/Invariants.spec.luau
local Prop   = require("../../../tests/prop")
local Approx = require("../../../tests/approx")
local Sim    = require("./init")
local Save   = require("./Serialize")
local Fmt    = require("../Format/Notation")

local function freshState(seed: number) return Sim.newState({ rngSeed = seed }) end

return function(t)
t.describe("simulation invariants", function()

	-- (1) Monotonic growth: with no spending, currency never decreases across a tick.
	t.it("currency is non-decreasing under pure accrual", function()
		Prop.forAll("monotone", Prop.list(Prop.magnitude(-2, 4), 200), function(dts)
			local s = freshState(1)
			local prev = s.currencies.points
			for _, dt in dts do
				s = Sim.step(s, dt)
				if s.currencies.points < prev then
					return false, ("dropped from %.17g to %.17g on dt=%.6g"):format(prev, s.currencies.points, dt)
				end
				prev = s.currencies.points
			end
			return true
		end)
	end)

	-- (2) No NaN or Infinity ever reaches the UI. Check the FORMATTER's input and output,
	--     because that is the exact boundary a player sees.
	t.it("never emits NaN/Infinity to the UI layer", function()
		Prop.forAll("finite-ui", Prop.magnitude(0, 8), function(seconds)
			local s = Sim.step(freshState(7), seconds)
			for name, v in s.currencies do
				if v ~= v then return false, ("currency %s is NaN"):format(name) end
				if v == math.huge or v == -math.huge then return false, ("currency %s is inf"):format(name) end
				local text = Fmt.short(v)
				if text:find("nan") or text:find("inf") or text == "" then
					return false, ("formatter produced %q for %s"):format(text, name)
				end
			end
			return true
		end)
	end)

	-- (3) Currency is never negative, including after a purchase that is refused.
	t.it("currency never goes negative", function()
		Prop.forAll("non-negative", Prop.list(Prop.int(1, 50), 100), function(buys)
			local s = freshState(3)
			for _, n in buys do
				s = Sim.step(s, 1)
				local r = Sim.buy(s, "gen1", n)
				s = r.state
				for name, v in s.currencies do
					if v < 0 then return false, ("%s went negative: %.17g"):format(name, v) end
				end
			end
			return true
		end)
	end)

	-- (4) Purchase cost is STRICTLY increasing in level. A flat step means a free infinite loop.
	t.it("cost is strictly increasing in level", function()
		Prop.forAll("cost-monotone", Prop.int(0, 50000), function(level)
			local a, b = Sim.costAt("gen1", level), Sim.costAt("gen1", level + 1)
			if not (b > a) then return false, ("cost(%d)=%.17g >= cost(%d)=%.17g"):format(level, a, level + 1, b) end
			return true
		end)
	end)

	-- (5) Offline gain == online gain over the same span. The classic port bug is that offline
	--     uses a closed form and online uses integration, and they disagree past some magnitude.
	t.it("offline accrual equals online accrual over the same span", function()
		Prop.forAll("offline-parity", Prop.magnitude(0, 6), function(span)
			local base = freshState(11)
			local offline = Sim.applyOffline(base, span)
			local online, remaining, STEP = base, span, 0.25
			while remaining > 0 do
				local dt = math.min(STEP, remaining); online = Sim.step(online, dt); remaining -= dt
			end
			-- Integration error is expected; it must stay within the declared budget.
			local ok, why = Approx.close(offline.currencies.points, online.currencies.points, 1e-6)
			if not ok then return false, ("span=%.6gs: %s"):format(span, why) end
			return true
		end)
	end)

	-- (6) save -> load -> save is a fixed point (byte-identical on the SECOND save).
	t.it("save/load round-trips to a fixed point", function()
		Prop.forAll("roundtrip", Prop.magnitude(0, 7), function(seconds)
			local s = Sim.step(freshState(5), seconds)
			local blob1 = Save.encode(s)
			local restored = Save.decode(blob1)
			local blob2 = Save.encode(restored)
			if blob1 ~= blob2 then
				return false, ("save is not idempotent (%d vs %d bytes)"):format(#blob1, #blob2)
			end
			return true
		end)
	end)

	-- (7) Multiplier stacking commutes where the design says it does (pure multiplicative sets).
	--     Where it does NOT (additive-then-multiplicative tiers), assert the opposite:
	--     that a known non-commuting pair really does differ, so nobody "fixes" it later.
	t.it("multiplicative buffs commute", function()
		Prop.forAll("commute", Prop.list(Prop.magnitude(-1, 2), 12), function(mults)
			local forward = Sim.stackMultiplicative(mults)
			local reversed = {}
			for i = #mults, 1, -1 do table.insert(reversed, mults[i]) end
			local backward = Sim.stackMultiplicative(reversed)
			-- Floating-point reassociation is expected; logic divergence is not.
			return Approx.close(forward, backward, 1e-12)
		end)
	end)
end)
end
```

**Notes on making these useful rather than decorative.** (a) Print the seed on failure and accept
a `PROP_SEED` env var so CI failures reproduce locally. (b) Run a small `trials` count (200) on
every PR and a large one (20,000, with seed derived from the date) nightly. (c) Property #7 is the
place teams most often assert a falsehood: if the design has an additive tier, multiplication is
*not* commutative across tiers, and asserting that it is will either fail forever or, worse, be
"fixed" by changing the game. Write the negative test too.

---

## 5. Simulation and soak testing

A soak run is a headless fast-forward that treats the simulation as a batch job. It is cheap
(seconds of CPU for years of game time) and it finds the class of bug that unit tests structurally
cannot: *slow* failures.

### 5.1 The harness

```lua
--!strict
-- tools/soak.luau — `lune run tools/soak -- --hours 10000 --step 1 --report out/soak.ndjson`
local process, fs, serde = require("@lune/process"), require("@lune/fs"), require("@lune/serde")
local Sim, Fmt = require("../src/Shared/Sim/init"), require("../src/Shared/Format/Notation")

local HOURS, STEP = 10000, 1.0   -- parse from process.args in real use
local state = Sim.newState({ rngSeed = 20260101 })
local policy = require("./policies/greedy")   -- a scripted "player": buys the best ROI each tick
local report, breaks = {}, {}

local function isBad(v: number): string?
	if v ~= v then return "NaN" end
	if v == math.huge or v == -math.huge then return "Infinity" end
	if v < 0 then return "negative" end
	return nil
end

-- Representability check: the value must survive a round-trip through our own display/save path.
local function representable(v: number): boolean
	local text = Fmt.short(v)
	local back = Fmt.parse(text)
	if back ~= back then return false end
	local scale = math.max(math.abs(v), math.abs(back))
	return scale == 0 or math.abs(v - back) / scale < 1e-3   -- display precision budget
end

local t0 = os.clock()
for hour = 1, HOURS do
	for _ = 1, 3600 / STEP do
		state = Sim.step(state, STEP)
		state = policy.act(state)
	end
	for name, v in state.currencies do
		local bad = isBad(v)
		if bad then table.insert(breaks, { hour = hour, currency = name, kind = bad }) end
		if not representable(v) then
			table.insert(breaks, { hour = hour, currency = name, kind = "unrepresentable",
				value = string.format("%.17g", v), shown = Fmt.short(v) })
		end
	end
	if hour % 10 == 0 or hour <= 24 then
		table.insert(report, {
			hour = hour,
			points = string.format("%.17g", state.currencies.points),
			shown = Fmt.short(state.currencies.points),
			prestige = state.prestigeCount,
			levels = state.levels,
			rate = string.format("%.17g", Sim.productionRate(state)),
		})
	end
	if #breaks > 0 and #breaks < 5 then
		print(("first break at hour %d: %s"):format(hour, serde.encode("json", breaks[1])))
	end
end

local lines = {}
for _, row in report do table.insert(lines, serde.encode("json", row)) end
fs.writeFile("out/soak.ndjson", table.concat(lines, "\n"))
print(("soak: %d hours in %.1fs wall, %d breaks"):format(HOURS, os.clock() - t0, #breaks))
process.exit(if #breaks == 0 then 0 else 1)
```

### 5.2 What to look for, and the assertion for each

| Failure mode | Symptom in the trace | Assertion |
|---|---|---|
| **Overflow** | `points` becomes `inf` at some hour | `isBad(v) == nil` for every currency, every hour |
| **Precision collapse** | Rate stops changing after a purchase because the increment is below one ULP of the total | `Sim.step(s, dt).points > s.points` whenever `rate > 0` and `dt >= 1` |
| **Representability loss** | Formatter prints `1e+308` or `inf`, or `parse(format(v))` diverges | `representable(v)` every hour (above) |
| **Softlock** | No purchase becomes affordable for N consecutive hours despite non-zero production | assert "time since last state change" stays under a design-declared cap |
| **Balance break** | Prestige cadence collapses to < 1 minute, or the first 10 upgrades all unlock in hour 1 | assert hour-of-first-purchase per upgrade against a declared band |
| **Non-termination** | Wall-clock per game-hour grows superlinearly | assert `os.clock()` delta per hour stays within a factor of the first hour |

**Three-tier schedule:** fast soak (100 h) on every PR, 10,000 h nightly, 1,000,000 h weekly with the
big-number path. The weekly run is where tetration-scale representation bugs surface; a layer-0
double-only implementation dies around 1.797e308, and the exact hour it dies is a number your
design document should contain.

**Finding the representability cliff.** Rather than asserting a magnitude, bisect for it and assert
the answer moved in the right direction:

```lua
-- Returns the smallest exponent at which format→parse round-trip fails.
local function cliff(): number
	local lo, hi = 0, 4096
	while lo + 1 < hi do
		local mid = (lo + hi) // 2
		if representable(10 ^ mid) then lo = mid else hi = mid end
	end
	return hi
end
-- Regression guard: this number must never DECREASE between releases.
assert(cliff() >= EXPECTED_CLIFF, ("representability cliff regressed to 1e%d"):format(cliff()))
```

---

## 6. Save-system testing

Every other bug costs a player a session. A save bug costs them their account. Test it hardest.

### 6.1 The six test families

**(a) Round-trip fidelity.** `decode(encode(s))` must be *structurally* equal to `s` — not "close".
Write a deep comparison that reports the first differing path, and run it over golden state
snapshots plus generated states ([§4.2](#42-the-invariants-worth-asserting) property 6). The
stronger form, `encode(decode(encode(s))) == encode(s)`, is a byte-level fixed point and catches
key-ordering nondeterminism, which is the usual cause of "the save grows every session".

**(b) Schema migration — every old version must load.** Keep one committed fixture per historic
schema version, forever.

```
fixtures/saves/v1_fresh.json      fixtures/saves/v4_post_prestige.json
fixtures/saves/v1_maxed.json      fixtures/saves/v5_with_tier7.json
fixtures/saves/v2_midgame.json    fixtures/saves/v6_bignum.json
fixtures/saves/v3_corrupt_rate.json   fixtures/saves/v7_current.json
```

```lua
t.it("loads every historic save version", function()
	for _, path in fs.readDir("fixtures/saves") do
		local blob = fs.readFile("fixtures/saves/" .. path)
		local ok, state = pcall(Save.decode, blob)
		expect(ok).toBe(true, ("v-fixture %s failed to decode: %s"):format(path, tostring(state)))
		expect(state.schemaVersion).toBe(Save.CURRENT_VERSION)   -- migration ran to completion
		-- Migration must not invent or destroy value.
		expect(state.currencies.points).toBeGreaterThanOrEqual(0)
		-- And must be idempotent: migrating an already-current save is a no-op.
		expect(Save.encode(Save.decode(Save.encode(state)))).toBe(Save.encode(state))
	end
end)
```
The rule that makes this work: **adding a new schema version requires adding a fixture for the
previous one in the same PR.** Enforce with a CI check that the count of `fixtures/saves/v{N}_*`
files is non-zero for every `N < CURRENT_VERSION`.

**(c) Corrupt and truncated data.** Generate systematically rather than by hand: for a valid blob,
emit every prefix at 10% increments, every single-byte flip at 32 random offsets, an empty string,
a string of the wrong type, valid JSON of the wrong shape, and a blob whose `schemaVersion` is
*larger* than `CURRENT_VERSION` (a player rolled back to an older server).

```lua
t.it("never silently accepts damaged data", function()
	local good = Save.encode(Sim.step(Sim.newState({ rngSeed = 1 }), 3600))
	local damaged = { "", "{", "null", "[]", string.rep("A", 1000) }
	for pct = 10, 90, 10 do table.insert(damaged, string.sub(good, 1, #good * pct // 100)) end
	for _, blob in damaged do
		local ok, result = pcall(Save.decode, blob)
		-- Required behaviour: either a clean error, or a value flagged as recovered.
		-- FORBIDDEN: returning a state that looks valid but has lost progress.
		if ok then
			expect(result.recovered).toBe(true)
			expect(result.recoveredFrom).toBeTruthy()
		else
			expect(tostring(result)).toMatch("save")   -- errors must be identifiable
		end
	end
end)
```
The forbidden outcome — decoding a truncated blob into a plausible-looking fresh state and then
*saving over the good data* — is the single most destructive bug an idle game can ship. Test it
explicitly, and make the production path refuse to write when the load was `recovered`.

**(d) Session lock under rejoin.** The hazard: a player leaves server A and joins server B before
A's final save lands, so A overwrites B's newer data. Roblox's data-store best practices document
the ingredients — prefer `UpdateAsync` over `SetAsync` because it "reads the latest value into your
callback before it writes, which reduces lost updates"; process retries in order per key because
"an older request that retries after a newer request succeeds can overwrite newer data"; and choose
a save interval "shorter than any session-lock expiration" (the official player-data sample uses
180 seconds). Model the lock in a pure module and test it headlessly:

```lua
-- Sim/SessionLock.luau is pure: it takes the stored record and a claim, returns a decision.
t.it("refuses a stale server's write after a rejoin", function()
	local store = FakeStore.new():port()
	local A, B = "serverA", "serverB"
	Session.claim(store, "User_1", A, { now = 0 })
	local decision = Session.claim(store, "User_1", B, { now = 5 })
	expect(decision.kind).toBe("locked")          -- B must wait, not steal
	local stale = Session.write(store, "User_1", A, savedState, { now = 400 })
	expect(stale.ok).toBe(false)                  -- A's lock expired; its write is rejected
	expect(stale.reason).toBe("lock_lost")
end)

t.it("releases the lock after expiry so a crashed server does not brick the account", function()
	local store = FakeStore.new():port()
	Session.claim(store, "User_1", "crashedServer", { now = 0 })
	local decision = Session.claim(store, "User_1", "newServer", { now = 0 + Session.TTL + 1 })
	expect(decision.kind).toBe("acquired")
end)
```
`[UNVERIFIED]` — Roblox does not provide a first-party session-lock primitive; the pattern above is
the community-standard `UpdateAsync`-based lock. Whatever implementation you choose, the two tests
above (steal-prevention and crash-recovery) are the ones that matter.

**(e) DataStore failure injection.** Drive the `FakeStore` from [§1.3](#13-dependency-injection-for-the-parts-that-must-touch-the-datamodel)
through each failure mode and assert the *player-visible* outcome, not the internal one:

| Injected failure | Required behaviour |
|---|---|
| `get` throws on every attempt | Player is **not** given a fresh save; session enters read-only mode and refuses to write |
| `set` throws once, succeeds on retry | Save succeeds; exactly one extra request consumed |
| `set` throws always | Retries with exponential backoff and jitter, caps attempts, surfaces a visible warning |
| Budget exhausted | Writes queue rather than drop; `BindToClose` still flushes |
| Throttled (`Request was throttled`) | Backs off; does not hot-loop |

**(f) The 4 MB limit as an assertion.** `Roblox/creator-docs` gives the data-store value limit as
**4,194,304 bytes per key** and the key-name limit as **50 characters**; total user-defined metadata
is capped at 300 characters. Assert all three, and assert a *headroom* budget well below the hard
limit so you find growth before players do:

```lua
t.it("stays within DataStore limits at worst-case progression", function()
	local s = loadFixture("fixtures/saves/worst_case_endgame.json")
	local blob = Save.encode(s)
	expect(#blob).toBeLessThan(4 * 1024 * 1024)          -- hard platform limit
	expect(#blob).toBeLessThan(512 * 1024)               -- our budget: 1/8 of the limit
	expect(#("User_" .. 9999999999)).toBeLessThanOrEqual(50)   -- key-name limit
end)
```
Also add a **growth regression test**: record the encoded size of each save fixture in a committed
`sizes.json` and fail CI if any grows by more than a few percent without the fixture being
regenerated. Unbounded per-session arrays (event logs, "recent purchases") are the usual culprit,
and they are invisible until a long-lived account crosses the limit and can never save again.

---

## 7. Static analysis and types

### 7.1 `--!strict` coverage as a QA metric

Roblox's own type-checking documentation lists three modes: `--!nocheck` ("Don't check types"),
`--!nonstrict` ("Only asserts variable types if they are explicitly annotated"), and `--!strict`
("Asserts all types based off the inferred or explicitly annotated type"), and notes that in
`nonstrict` mode "all variables are assigned the type `any`" by default. For a port, `--!nonstrict`
is barely better than nothing: `any` propagates and the checker goes quiet exactly where a
transcription bug would live.

Treat strict coverage as a tracked number, not a vibe:

```bash
# scripts/strict-coverage.sh — prints coverage and fails below the ratchet
total=$(find src -name '*.luau' ! -name '*.spec.luau' | wc -l)
strict=$(grep -rl '^--!strict' src --include='*.luau' | grep -v '\.spec\.luau$' | wc -l)
pct=$(( 100 * strict / total ))
echo "strict coverage: ${strict}/${total} (${pct}%)"
[ "$pct" -ge "${STRICT_FLOOR:-85}" ] || { echo "below floor ${STRICT_FLOOR:-85}%"; exit 1; }
```
Ratchet the floor upward; never downward. Require 100% in `src/Shared/Sim` and
`src/Shared/Balance` — those are the files whose correctness *is* the product.

What strict mode actually catches in a port, in rough order of frequency: passing a `string` level
index where a `number` is expected (the original was JS, where `obj["3"]` and `obj[3]` coincide and
in Luau they do not); a function that returns a value on one branch and `nil` on another, which
strict mode reports and `nonstrict` silently types as `any`; misspelled table fields on a typed
table; `nil`-able results from `FindFirstChild`/table lookups used without a check; and arity
mismatches after a refactor.

**Type the simulation's data, not just its functions.** The highest-yield annotation in an idle
game is the state shape itself, because every migration and every fixture decoder has to produce
it:

```lua
--!strict
export type CurrencyId = "points" | "gems" | "shards"
export type SimState = {
	schemaVersion: number,
	elapsed: number,
	rngSeed: number,
	currencies: { [CurrencyId]: number },
	levels: { [string]: number },
	prestigeCount: number,
	recovered: boolean?,      -- set only by a damaged-save recovery path
}
```
A string-literal union for `CurrencyId` turns "typo in a currency name" from a silent no-op into a
compile-time error — which is precisely the bug class that a port introduces when currency keys are
retyped by hand.

### 7.2 Selene

Selene is "a blazing-fast modern Lua linter written in Rust" whose stated priority is *"It's okay
to not diagnose every problem, as long as the diagnostics that are made are never wrong."* That
makes its output safe to gate on.

Setup, verified from Selene's Roblox guide: put `std = "roblox"` in `selene.toml` and a Roblox
standard library is generated automatically (refreshed every 6 hours; force with
`selene update-roblox-std`). If you use TestEZ, the guide says to use `std = "roblox+testez"` and
supply a `testez.yml`. For reproducible CI, pin it: `roblox-std-source = "pinned"` writes
`roblox.yml` next to your config (also produced by `selene generate-roblox-std`), so the build does
not depend on a network fetch.

```toml
# selene.toml
std = "roblox+testez"
roblox-std-source = "pinned"

[lints]
# Real bugs — keep these as errors.
divide_by_zero = "deny"
unbalanced_assignments = "deny"
mismatched_arg_count = "deny"
undefined_variable = "deny"
incorrect_standard_library_use = "deny"
duplicate_keys = "deny"
almost_swapped = "deny"
suspicious_reverse_loop = "deny"
constant_table_comparison = "deny"
if_same_then_else = "deny"
ifs_same_cond = "deny"
type_check_inside_call = "deny"
shadowing = "warn"            # noisy but catches real capture bugs in tick loops
global_usage = "deny"         # a global in an idle sim is a cross-server divergence waiting to happen
unscoped_variables = "deny"
must_use = "warn"
high_cyclomatic_complexity = "warn"
manual_table_clone = "warn"
```
The full lint set (verified from Selene's documentation index) is: `almost_swapped`,
`constant_table_comparison`, `deprecated`, `divide_by_zero`, `duplicate_keys`, `empty_if`,
`empty_loop`, `global_usage`, `high_cyclomatic_complexity`, `if_same_then_else`, `ifs_same_cond`,
`incorrect_standard_library_use`, `manual_table_clone`, `mismatched_arg_count`, `mixed_table`,
`multiple_statements`, `must_use`, `parenthese_conditions`, `restricted_module_paths`,
`roblox_incorrect_color3_new_bounds`, `roblox_incorrect_roact_usage`,
`roblox_manual_fromscale_or_fromoffset`, `roblox_suspicious_udim2_new`, `shadowing`,
`suspicious_reverse_loop`, `type_check_inside_call`, `unbalanced_assignments`,
`undefined_variable`, `unscoped_variables`, `unused_variable`.

Which ones earn their place in *this* project: `divide_by_zero` (an idle game divides by a rate
that can be zero before the first generator is bought), `unbalanced_assignments` (a port artifact —
JS destructuring translated by hand), `mismatched_arg_count` (signature drift during the port),
`shadowing` (a `local rate` inside a loop shadowing the outer one silently freezes production),
`global_usage` (an accidental global is shared across every coroutine on the server),
`suspicious_reverse_loop` (`for i = #t, 1 do` without `-1` never executes — a silent no-op in a
cleanup path), and `type_check_inside_call` (`assert(type(x == "number"))` — always truthy, a
whole class of dead assertions).

CI invocation: `selene src` with `--display-style Quiet` for compact logs; `--allow-warnings` makes
it "pass when only warnings occur" — use it during migration, drop it once clean.

### 7.3 Luau's own linter and `luau-lsp analyze`

Luau's compiler ships a linter with **29 numbered warning codes**, verified from
`Config/include/Luau/LinterConfig.h` in `luau-lang/luau`: `UnknownGlobal`(1), `DeprecatedGlobal`(2),
`GlobalUsedAsLocal`(3), `LocalShadow`(4), `SameLineStatement`(5), `MultiLineStatement`(6),
`LocalUnused`(7), `FunctionUnused`(8), `ImportUnused`(9), `BuiltinGlobalWrite`(10),
`PlaceholderRead`(11), `UnreachableCode`(12), `UnknownType`(13), `ForRange`(14),
`UnbalancedAssignment`(15), `ImplicitReturn`(16), `DuplicateLocal`(17), `FormatString`(18),
`TableLiteral`(19), `UninitializedLocal`(20), `DuplicateFunction`(21), `DeprecatedApi`(22),
`TableOperations`(23), `DuplicateCondition`(24), `MisleadingAndOr`(25), `CommentDirective`(26),
`IntegerParsing`(27), `ComparisonPrecedence`(28), `RedundantNativeAttribute`(29). The header notes
several are "disabled in Studio" (`LocalShadow`, `SameLineStatement`, `LocalUnused`,
`FunctionUnused`, `ImportUnused`, `ImplicitReturn`) — meaning **Studio will not show you these; CI
must**. `IntegerParsing` and `FormatString` are directly relevant to a big-number port, and
`MisleadingAndOr` catches the `a and b or c` idiom silently failing when `b` is `false`/`nil`.

`JohnnyMorganz/luau-lsp` is the CI typechecker: its README states the tool "can run standalone …
to provide type and lint warnings in CI, with full Rojo resolution and API types support", with
`luau-lsp analyze` as the entry point, and that "the latest Roblox type definitions and
documentation are preloaded out of the box". It resolves the DataModel through a Rojo sourcemap
produced by `rojo sourcemap --watch default.project.json --output sourcemap.json` (drop `--watch`
in CI).

### 7.4 StyLua

StyLua's `--check` flag checks "whether files require formatting (but not write directly to them)",
which is the CI mode. Configuration lives in `stylua.toml` / `.stylua.toml` in the project root;
documented defaults include `column_width = 120`, `indent_type = "Tabs"`, `indent_width = 4`, and
`syntax = "Style"` disambiguates the dialect. Formatting is not a correctness control, but it is a
*review* control: a mechanically formatted diff makes a one-character constant change visible
instead of hiding it inside a reflow.

---

## The CI workflow

A pipeline that gates merges must run without Studio. Everything below runs on `ubuntu-latest`.

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  STRICT_FLOOR: "85"

jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0          # needed for the frozen-fixture diff check

      # --- Toolchain -------------------------------------------------------
      # rokit.toml pins exact versions of rojo, wally, stylua, selene, lune and luau-lsp,
      # so CI and every developer run the same binaries.
      - name: Install Rokit
        uses: CompeyDev/setup-rokit@v0.1.2
      - name: Install pinned tools
        run: rokit install --no-trust-check

      - name: Print tool versions (provenance for the build log)
        run: |
          rojo --version && wally --version && stylua --version
          selene --version && lune --version && luau-lsp --version

      # --- Dependencies ----------------------------------------------------
      - name: Cache Wally packages
        uses: actions/cache@v4
        with:
          path: |
            Packages
            DevPackages
            ~/.cache/wally
          key: wally-${{ runner.os }}-${{ hashFiles('wally.lock') }}
      - name: Install packages
        run: wally install --locked      # --locked errors without an up-to-date lockfile

      # --- Fast gates (fail in seconds, before anything expensive) ---------
      - name: Format check
        run: stylua --check src tests tools

      - name: Lint
        run: selene src tests tools --display-style Quiet

      - name: Simulation purity gate
        run: bash scripts/check-purity.sh

      - name: Frozen fixtures are immutable
        run: bash scripts/check-frozen.sh
        env:
          BASE_REF: ${{ github.base_ref || 'main' }}

      - name: Strict-mode coverage ratchet
        run: bash scripts/strict-coverage.sh

      # --- Typecheck -------------------------------------------------------
      # Wally installs packages with a flat layout; sourcemap generation makes luau-lsp
      # resolve `require(Packages.Foo)` the same way Studio will.
      - name: Generate Rojo sourcemap
        run: rojo sourcemap default.project.json --output sourcemap.json

      - name: Typecheck
        run: |
          luau-lsp analyze \
            --sourcemap=sourcemap.json \
            --settings=.vscode/settings.json \
            --ignore="Packages/**" \
            --ignore="DevPackages/**" \
            src tests tools

      # --- Tests -----------------------------------------------------------
      - name: Unit + property tests (Lune, headless)
        run: lune run tests/run

      - name: Golden-master suite
        run: lune run tests/golden_all

      - name: Fast soak (100 in-game hours)
        run: lune run tools/soak -- --hours 100 --report out/soak-pr.ndjson

      - name: Upload soak report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: soak-report
          path: out/

      # --- Build -----------------------------------------------------------
      - name: Build place file
        run: rojo build default.project.json --output build/game.rbxl

      - name: Assert the debug console is disabled in this build
        run: bash scripts/assert-debug-off.sh

      - name: Upload place artifact
        uses: actions/upload-artifact@v4
        with:
          name: place
          path: build/game.rbxl

  nightly-soak:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    timeout-minutes: 120
    steps:
      - uses: actions/checkout@v4
      - uses: CompeyDev/setup-rokit@v0.1.2
      - run: rokit install --no-trust-check
      - run: wally install --locked
      - name: Deep soak (10,000 in-game hours)
        run: lune run tools/soak -- --hours 10000 --report out/soak-nightly.ndjson
      - name: Property tests, 20k trials
        run: PROP_TRIALS=20000 PROP_SEED=${{ github.run_number }} lune run tests/run
      - uses: actions/upload-artifact@v4
        with: { name: nightly-soak, path: out/ }
```

Companion `rokit.toml` (Rokit is the Rojo org's toolchain manager, "drop-in compatibility with
projects that already use Foreman or Aftman"):

```toml
# rokit.toml — pin everything; "latest" is not a version
[tools]
rojo = "rojo-rbx/rojo@7.5.1"
wally = "UpliftGames/wally@0.3.2"
stylua = "JohnnyMorganz/StyLua@2.0.2"
selene = "Kampfkarren/selene@0.27.1"
lune = "lune-org/lune@0.8.9"
luau-lsp = "JohnnyMorganz/luau-lsp@1.32.1"
```
`[UNVERIFIED]` — the exact version numbers above are illustrative. Resolve each against the tool's
current GitHub releases when you create the file; the *practice* (pin, never float) is the point.
The `CompeyDev/setup-rokit` action is `[COMMUNITY, SECOND-HAND]`; if you prefer no third-party
action, run Rokit's documented installer script
(`curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`) in a
`run:` step instead.

**Merge gate policy.** Required checks: format, lint, purity, frozen fixtures, strict ratchet,
typecheck, unit/property, golden-master, fast soak, build, debug-off. Non-required (informational):
nightly soak, coverage trend. A PR that changes anything under `src/Shared/Sim` or
`src/Shared/Balance` additionally requires a human reviewer from a `CODEOWNERS` entry, because
those are the files where a silent constant change is indistinguishable from an intentional
balance change.

**What is deliberately *not* in this pipeline:** anything that needs Roblox Studio. Jest Lua and
TestEZ suites that require a DataModel run on a separate, self-hosted Windows runner driven by
`run-in-roblox`, on a nightly schedule and on release branches — not on every PR. Making the fast
path Studio-free is what keeps the gate fast enough that people do not route around it.

---

## 8. In-Studio and in-game QA

Headless tests cover the simulation. Everything below covers what they cannot see: replication,
UI, timing, and players behaving unreasonably.

### 8.1 Playtest checklist (per release candidate)

Studio's testing modes are documented in `creator-docs`: **Test** / **Test Here** run "solo" modes
where "Studio runs two separate simulations — one client simulation and one server simulation",
with a **Client/Server** toggle (blue border = client, green = server), a **Pause/Resume** control
that can act on client or server independently, and a **Step Forward** button that advances
1/60th of a second. Output messages are colour-labelled blue (client) or green (server).

| # | Check | Mode | Pass condition |
|---|---|---|---|
| 1 | Fresh account: first 10 minutes | Test | No errors in Output; first upgrade affordable within the designed window |
| 2 | Loaded account: paste an endgame save | Test | UI renders every magnitude without overflow or `inf`; no frame hitch on load |
| 3 | Rejoin immediately after leaving | Local Server 2 players | Progress is exactly what it was; no rollback, no duplicate rewards |
| 4 | Two clients, same account is impossible — two clients, *different* accounts | Local Server 2+ | No cross-talk; each client sees only its own currencies |
| 5 | Purchase spam (hold buy-max, 60 s) | Local Server | Server stays authoritative; no negative currency; no remote flood kick |
| 6 | Offline claim after clock manipulation | Test | Client-side clock changes cannot inflate offline gain (server computes it) |
| 7 | Shutdown mid-session | Local Server → Stop | `BindToClose` flush completes; rejoin shows the flushed state |
| 8 | Step-forward through a prestige | Test + Step Forward | No single frame shows a partially-reset state to the player |
| 9 | Every UI panel at 800×600 and at 3840×1600 | Device emulator | No clipped text, no unreachable buttons |
| 10 | Errors surfaced | Any | `ScriptContext.Error` count for the session is zero |

Check 4 needs the **multi-client** path: Studio's Local Server mode starts one server process and N
client processes on your machine. It is the only pre-production way to see replication order bugs,
and it is where "the client computed the currency and told the server" bugs become obvious — the
second client will disagree.

### 8.2 A debug console that cannot ship enabled

Three independent conditions, all server-side, all required:

```lua
--!strict
-- Server/DebugConsole.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local BuildConfig = require(game.ServerStorage.BuildConfig)  -- generated at build time

-- Condition 1: a build-time constant. CI asserts this is false on release branches.
local ENABLED_AT_BUILD: boolean = BuildConfig.DEBUG_CONSOLE

-- Condition 2: an explicit allowlist of UserIds. Never a group check, never a name check.
local ALLOWED: { [number]: true } = { [1234567] = true, [7654321] = true }

-- Condition 3: never in a production place, regardless of the other two.
local IS_PRODUCTION_PLACE = game.PlaceId == BuildConfig.PRODUCTION_PLACE_ID

local function mayUse(player: Player): boolean
	if not ENABLED_AT_BUILD then return false end
	if IS_PRODUCTION_PLACE and not RunService:IsStudio() then return false end
	return ALLOWED[player.UserId] == true
end

-- Commands are validated server-side and applied through the SAME Sim functions as normal play,
-- so a cheat command can never produce a state the simulation could not reach legitimately.
local function handle(player: Player, command: string, ...)
	if not mayUse(player) then
		Telemetry.event("debug_console_denied", { userId = player.UserId, command = command })
		return
	end
	...
end
```

The CI gate is three lines and catches the failure that actually happens (someone flips the flag to
debug something and forgets):

```bash
# scripts/assert-debug-off.sh
grep -q 'DEBUG_CONSOLE = false' src/Server/BuildConfig.luau \
  || { echo "ERROR: DEBUG_CONSOLE must be false on this branch"; exit 1; }
```
Additional rule: **the debug RemoteEvent must not exist in the built place when disabled.** Gate it
in the Rojo project or destroy it at startup — an unreachable-but-present remote is an invitation.

### 8.3 Telemetry and error reporting

Two engine hooks, both with signatures verified from `Roblox/creator-docs`:

- `ScriptContext.Error(message: string, stackTrace: string, script: Instance)` — "Fires when an
  unhandled error occurs while running a script … passing the error `message`, a formatted
  `stackTrace` string, and the `script` that was running." Its documentation also notes the
  gap you must cover another way: **"This event does not fire for errors raised by the watchdog
  when a script exceeds its execution-time limit"** (see `ScriptContext:SetTimeout()`). An infinite
  loop in a tick handler is therefore invisible to this hook — catch it with a heartbeat watchdog.
- `LogService.MessageOut(message: string, messageType: Enum.MessageType, context: table?)` — "Fires
  whenever a message is logged through the engine's output system, including calls to `print()`,
  `warn()`, and the structured logging methods on `LogService`." `context` "carries the structured
  key-value pairs when the message was emitted via a method that accepts a context table; otherwise
  it is nil."

```lua
--!strict
-- Server/ErrorPipe.luau
local ScriptContext = game:GetService("ScriptContext")
local HttpService = game:GetService("HttpService")

local seen: { [string]: number } = {}        -- fingerprint -> count, to avoid flooding
local BUDGET_PER_MINUTE = 20
local sent = 0

ScriptContext.Error:Connect(function(message: string, stackTrace: string, script: Instance)
	-- Fingerprint on message + top stack frame only, so one bug is one report.
	local top = stackTrace:match("^[^\n]*") or ""
	local fingerprint = message .. "|" .. top
	seen[fingerprint] = (seen[fingerprint] or 0) + 1
	if seen[fingerprint] > 1 or sent >= BUDGET_PER_MINUTE then return end
	sent += 1
	Telemetry.event("script_error", {
		message = message,
		stack = stackTrace,
		script = script and script:GetFullName() or "<unknown>",
		placeVersion = game.PlaceVersion,
		jobId = game.JobId,
		count = seen[fingerprint],
	})
end)
```
Ship the aggregate somewhere a human looks daily. Roblox's own backstop is the Creator Hub
**Crashes** chart, documented in `creator-docs`: it breaks crashes into **out-of-memory** ("high
memory usage that you can take direct action to fix") and **platform** crashes, and for OOM the
engine "automatically captures a compact JSON summary of the data model before the server shuts
down", browsable as a treemap and downloadable as CSV. For an idle game the OOM path is a real
risk: per-player state that grows without bound (event logs, unpruned purchase history) shows up
there long before it shows up in a unit test.

### 8.4 Staged rollout

The order that limits blast radius:

1. **Studio** → the checklist above.
2. **A private test place** built from the same artifact CI produced (never a hand-published
   build) — 5–10 internal testers, real devices, real DataStore, but a *separate data store name*
   so a save bug cannot touch production data.
3. **A copy of production data, read-only.** Load real endgame saves into the test place with
   writes disabled. This is the single highest-yield pre-launch step for a port, because real saves
   contain shapes no fixture author imagines.
4. **Production, gated.** Ship behind a server-side flag read from a config store, defaulted off;
   enable for a small allowlist, then a percentage, watching the error rate and the crashes chart
   at each step.
5. **Full rollout**, with the previous place version kept ready for rollback and a documented
   rollback procedure that includes *what happens to saves written by the new version* — this is
   the question teams forget, and the answer must be "old versions can still read them", which is
   a migration test ([§6](#6-save-system-testing) family b) you should already have.

---

## 9. Device and platform QA

Roblox's own guidance is blunt about why emulation is insufficient: "emulation can't fully
replicate what happens on real hardware. Frame rates, memory pressure, thermal throttling, and
input latency all behave differently on physical devices," and "if you're only testing on your
development machine, you're testing for the minority of your audience."

The audience numbers from the same document, which should drive your device choice: **Android is
roughly 65% of a typical game's player base; ~60% of those players have 2–4 GB of RAM, ~35% have
4–8 GB, ~5% more than 8 GB; over 50% of the whole player base plays on devices scoring 10,000–20,000
on Passmark.** The doc's suggested spread of Android test devices is "an Infinix Smart 9, a Motorola
Moto G05, an Oppo A18, an Amazon Fire HD 10 (2023), and a Samsung Galaxy S22 Ultra."

**The minimum device matrix for an idle game** (which is UI-heavy and text-heavy, so its failure
modes differ from an action game's):

| Axis | Test at least | Idle-game-specific failure to look for |
|---|---|---|
| Hardware | One 2–4 GB Android phone; one mid Android; one iPhone; one desktop | Number-heavy UI redrawn every frame tanking fps on the low-end device |
| Graphics quality | Lowest and highest tiers | UI that depends on effects disabled at low quality becoming unreadable |
| Aspect ratio | 4:3 (Fire HD), 16:9, ~20:9 tall phone, ultrawide desktop | Currency readouts clipped; buy-max buttons off-screen in portrait |
| Text scale | Largest accessible text size | Big-number strings (`1.79e308`, `ee1.5e12`) overflowing fixed-width labels |
| Network | Throttled/cellular; forced disconnect | Offline-gain claim firing twice; save lost on an abrupt drop |
| Session | Rejoin immediately; rejoin after 24 h; join a full server | Session-lock stall showing an infinite "Loading…" with no timeout |

On-device tooling, per the same doc: the **Developer Console** (<kbd>F9</kbd>) has a Memory tab and
runs on client devices, the **MicroProfiler** (<kbd>Ctrl</kbd><kbd>Alt</kbd><kbd>F6</kbd> /
<kbd>⌘</kbd><kbd>⌥</kbd><kbd>F6</kbd>) captures frame dumps on device for later analysis, and
**Performance Stats** gives an FPS/memory/ping overlay. It also flags **thermal throttling** as a
device-only phenomenon — relevant here because an idle game is frequently left running for hours,
which is exactly the sustained load that triggers it. Add a 30-minute continuous-play run on the
low-end phone to the release checklist and record fps at minute 1 and minute 30.

Two specific tests that idle ports routinely fail:

1. **Backgrounded and resumed.** Put the app in the background for 10 minutes, return. Offline gain
   must be computed once, by the server, from a server-side timestamp — not from the client's
   elapsed time, and not twice.
2. **Disconnect during a save.** Kill network mid-session. The correct outcome is that the player
   loses at most the last save interval; the incorrect outcome is a partial write or a lock the
   next server cannot break.

Roblox's adaptive-design guidance sets the UI bar: input fluidity (every action reachable by
gamepad, keyboard and touch, with prompts that reflect the active input), responsive layout,
dynamic sizing, and legibility. For an idle game, "every action reachable" specifically includes
buy-max and prestige, which are commonly bound to a modifier key on desktop and then unreachable
on touch.

---

## The review rubric

This chapter is used to QA code and documentation produced by other agents and by humans. The
rubric below is written to be **executed mechanically**: every item is a yes/no question with a
stated verification action, so two reviewers running it on the same artifact should reach the same
verdict. Score each section; any `FAIL` in section A or B blocks merge regardless of the rest.

### Section A — Source and citation integrity (blocking)

| # | Question | How to verify | Fail if |
|---|---|---|---|
| A1 | Does every factual claim about an external API carry a citation to a specific, resolvable source? | For each claim, follow the citation | Any citation is to "the docs" generically, to a URL that 404s, or is absent |
| A2 | Is each cited source **primary**? | Check the domain/repo: official docs, the tool's own repository, or the engine source | A blog, a forum post, or another LLM's output is cited as authority without a `[COMMUNITY, SECOND-HAND]` marker |
| A3 | Does the citation actually support the specific claim, not merely the topic? | Open the source, find the sentence | The source discusses the area but not the claim (the most common AI failure) |
| A4 | Are unverifiable claims marked? | Search for `[UNVERIFIED]` / hedging | A confident claim is made about something the author could not check |
| A5 | Are version numbers, limits and constants attributed? | Trace each number to its source | A number appears with no origin (e.g. "the limit is 4 MB" with no link) |
| A6 | Are blocked/unreachable sources disclosed? | Look for a scope/verification note | The doc implies it read sources it could not reach |

### Section B — API and signature accuracy (blocking)

| # | Question | How to verify | Fail if |
|---|---|---|---|
| B1 | Is every function signature copied from source, not reconstructed from memory? | Grep the named symbol in the cited repo/doc and compare parameter names, order and count | Any parameter name, order, count or type differs |
| B2 | Do the *return* values match? | Same check, return section | Returns are omitted, invented, or given in the wrong order |
| B3 | Are optional parameters and defaults stated correctly? | Compare with source | A default is asserted that the source does not state |
| B4 | Are the named methods real? | Grep for each method name in the API surface | A method is plausible but absent (e.g. `TestBootstrap:runAll`, `expect(x).toBeCloseTo` in TestEZ) |
| B5 | Are platform constraints stated? | Check the source's own caveats | A capability is claimed without its documented limitation (e.g. "run Jest Lua under Lune") |
| B6 | Are deprecations and status honestly reported? | Check README/changelog dates and wording | An unmaintained tool is presented as current, or vice versa |

### Section C — Evidence for performance and behaviour claims

| # | Question | How to verify | Fail if |
|---|---|---|---|
| C1 | Is every performance number measured, with the measurement method described? | Look for the benchmark code, the hardware, the N, the units | A number appears with no method ("this is ~10× faster") |
| C2 | Is the benchmark reproducible from what is written? | Try to reconstruct it from the text alone | Missing input sizes, missing hardware, missing iteration count |
| C3 | Are comparisons like-for-like? | Check both sides ran the same workload | Different inputs, different optimization levels, or one side includes setup cost |
| C4 | Are asserted behaviours distinguished from measured ones? | Look for hedging language on unmeasured claims | "This is faster" where the author never ran it and did not mark it |
| C5 | Are statistical claims accompanied by variance? | Look for range/median/stddev | A single number is presented as the truth for a noisy measurement |

### Section D — Code correctness and runnability

| # | Question | How to verify | Fail if |
|---|---|---|---|
| D1 | Does every non-illustrative snippet parse? | Paste into `luau`/`lune run`, or `stylua --check` on the extracted block | A syntax error |
| D2 | Does it typecheck under `--!strict`? | Run `luau-lsp analyze` on the extracted block with stubs | Type errors that indicate a real mistake (not just missing context) |
| D3 | Are all identifiers defined or clearly marked as project-specific? | Read for undefined names | A helper is used that is never defined or explained |
| D4 | Is the code consistent with its own prose? | Compare the description to the code | Prose says one thing, code does another |
| D5 | Does the code handle its stated edge cases? | Check each edge case named in the prose against the code | An edge case is discussed but not handled |
| D6 | Is error handling present where the API can fail? | Look for `pcall`/result-tuple handling around I/O and DataStore calls | A fallible call is written as if infallible |
| D7 | Are floating-point comparisons relative, or justified as absolute? | Grep for `math.abs(a - b) <` | An absolute epsilon is used on unbounded-magnitude values |
| D8 | Is anything secret, destructive, or irreversible done without a guard? | Look for deletes, overwrites, `SetAsync` without a read | A destructive operation has no precondition check |

### Section E — Edge cases and adversarial inputs

| # | Question | Fail if |
|---|---|---|
| E1 | Are zero, one, empty, and maximum inputs considered? | Only the happy path is shown |
| E2 | Are NaN and ±Infinity considered wherever arithmetic is unbounded? | Not mentioned in numeric code |
| E3 | Are negative and out-of-order inputs considered (negative `dt`, decreasing timestamps)? | Not mentioned in time-based code |
| E4 | Is concurrency/reentrancy addressed where state is shared (two servers, rejoin)? | Shared mutable state with no ordering discussion |
| E5 | Is failure of an external dependency considered (DataStore down, network dropped)? | The dependency is assumed to succeed |
| E6 | Are limits asserted rather than assumed (size, key length, rate)? | A platform limit is mentioned in prose but never checked in code |

### Section F — Hallucination detection (run this explicitly)

Executable procedure, in order. Stop and fail on the first hit.

1. **Extract every proper noun** — library names, repo names, function names, config keys, CLI
   flags, file names — into a list.
2. **For each, confirm it exists** in the cited source. Grep the repo, or fetch the doc page. A name
   that cannot be found in any primary source is a hallucination until proven otherwise.
3. **Check every version number** against the project's releases or changelog.
4. **Check every CLI flag** against `--help` output or the tool's documented CLI page. Invented
   flags are one of the most common failure modes (`selene --strict`, `rojo test`, `lune test`).
5. **Check every URL** resolves and is the thing it is described as.
6. **Look for suspiciously round or convenient numbers** ("3× faster", "handles 1 million entities")
   and demand the measurement.
7. **Look for API symmetry that does not exist.** If a doc says `serializeX`/`deserializeX` for one
   type, confirm both exist for the other types too rather than assuming.
8. **Check that quoted text is verbatim.** Search the source for the exact quoted string. A
   paraphrase presented in quotation marks is a citation-integrity failure (A3).
9. **Check the negative claims too.** "X does not support Y" needs a source as much as "X supports
   Y", and is more often wrong.

### Section G — Documentation quality (non-blocking, but tracked)

| # | Question | Fail if |
|---|---|---|
| G1 | Can a competent engineer act on this without further research? | Key steps are missing or hand-waved |
| G2 | Are trade-offs stated, not just recommendations? | A single option is presented with no alternatives or costs |
| G3 | Is the failure mode of each recommendation described? | "Do X" with no "X breaks when…" |
| G4 | Is it scoped — does it say what it does *not* cover? | Scope is implied to be total |
| G5 | Are examples specific to this project's domain rather than generic? | `foo`/`bar` examples where domain examples were possible |

### Verdict form

```
Artifact: ______________________  Reviewer: ____________  Date: __________
A (citations)   PASS / FAIL   blocking   notes: ______________________
B (signatures)  PASS / FAIL   blocking   notes: ______________________
C (evidence)    PASS / FAIL              notes: ______________________
D (code)        PASS / FAIL              notes: ______________________
E (edge cases)  PASS / FAIL              notes: ______________________
F (hallucination sweep)  items extracted: ____  unverifiable: ____
G (doc quality) score __/5
Verdict: MERGE / REVISE / REJECT
```

**Reviewer guidance for AI-generated artifacts specifically.** The failure profile differs from a
human's. Humans forget edge cases; models produce *fluent, plausible, wrong* specifics. So weight
your time toward Sections A, B and F — checking that named things exist and that quoted things were
quoted — and spend less on prose quality, which is usually the artifact's strongest dimension and
its least informative signal. A document that reads beautifully and cites nothing is a worse
artifact than a rough one with verifiable references.

---

## Sources

**Research environment note.** `create.roblox.com`, `devforum.roblox.com`, `luau.org` and
`lune-org.github.io` all returned egress-blocked/403 from the research environment and were not
retried. Roblox documentation is therefore cited from its GitHub source of record
(`Roblox/creator-docs`), Luau behaviour from compiler/analysis source in `luau-lang/luau`, and Lune
documentation from its docs repository (`lune-org/docs`) rather than the rendered site. Every URL
below was fetched successfully during research unless marked otherwise.

### Test frameworks

- `Roblox/testez` — `README.md` (Lemur/CI statement, internal usage, Apache 2.0):
  <https://raw.githubusercontent.com/Roblox/testez/master/README.md>
- `Roblox/testez` — `src/TestBootstrap.lua` (verified `run(roots, reporter, otherOptions)` signature,
  `otherOptions` keys, `.spec` discovery, `init.spec` handling):
  <https://raw.githubusercontent.com/Roblox/testez/master/src/TestBootstrap.lua>
- `Roblox/testez` — `src/init.lua` (exported surface, reporters):
  <https://raw.githubusercontent.com/Roblox/testez/master/src/init.lua>
- `Roblox/testez` — `src/Expectation.lua` (verified matcher list: `a`/`an`, `ok`, `equal`, `near`,
  `throw`, `never`, `extend`):
  <https://raw.githubusercontent.com/Roblox/testez/master/src/Expectation.lua>
- `Roblox/testez` — `docs/api-reference.md` (describe/it/expect, lifecycle hooks, FOCUS/SKIP/FIXME,
  `context`): <https://raw.githubusercontent.com/Roblox/testez/master/docs/api-reference.md>
- `Roblox/testez` — `docs/getting-started/running-tests.md` ("internals … being reworked" note):
  <https://raw.githubusercontent.com/Roblox/testez/master/docs/getting-started/running-tests.md>
- `jsdotlua/jest-lua` — `README.md` ("can currently only run inside of Roblox", issue #2, Jest
  v27.4.7 alignment, MIT): <https://raw.githubusercontent.com/jsdotlua/jest-lua/main/README.md>
- `jsdotlua/jest-lua` — `docs/docs/GettingStarted.md` (verified `wally.toml` dev-dependencies,
  `runCLI` entry point, `jest.config.lua`, `run-in-roblox` requirement):
  <https://raw.githubusercontent.com/jsdotlua/jest-lua/main/docs/docs/GettingStarted.md>
- `jsdotlua/jest-lua` — `CHANGELOG.md` (3.10.0 dated 2024-10-02; `spyOn` in 3.6.2; `task.wait` mock
  in 3.8.0; JestBenchmark in 3.4.0; v28 upgrade):
  <https://raw.githubusercontent.com/jsdotlua/jest-lua/main/CHANGELOG.md>
- `rojo-rbx/run-in-roblox` — `README.md` (purpose, stdout piping, `--place`/`--script` usage):
  <https://raw.githubusercontent.com/rojo-rbx/run-in-roblox/master/README.md>

### Lune

- `lune-org/lune` — `README.md` (standalone Luau runtime; task-scheduler port; optional Roblox
  place/model library): <https://raw.githubusercontent.com/lune-org/lune/main/README.md>
- `lune-org/docs` — `api-reference/roblox.md` (verified: `deserializePlace`, `deserializeModel`,
  `serializePlace`, `serializeModel`, `getAuthCookie`, `getReflectionDatabase`,
  `implementProperty`, `implementMethod`, `studio*Path`):
  <https://raw.githubusercontent.com/lune-org/docs/main/src/content/docs/api-reference/roblox.md>
- `lune-org/docs` — `roblox/4-api-status.md` (verified implemented `Instance`/`DataModel` members
  and datatype list — the basis for the "no `require`, no signals" finding):
  <https://raw.githubusercontent.com/lune-org/docs/main/src/content/docs/roblox/4-api-status.md>
- `lune-org/docs` — `roblox/2-examples.md` (verified `deserializePlace`/`Instance.new("DataModel")`
  examples): <https://raw.githubusercontent.com/lune-org/docs/main/src/content/docs/roblox/2-examples.md>
- `lune-org/docs` — `api-reference/luau.md` (verified `compile`/`load`, `CompileOptions`,
  `LoadOptions` including `environment`, `injectGlobals`, `codegenEnabled`, and the codegen
  warning): <https://raw.githubusercontent.com/lune-org/docs/main/src/content/docs/api-reference/luau.md>
- `lune-org/docs` — `api-reference/process.md` (`process.exit`, `args`, `env`):
  <https://raw.githubusercontent.com/lune-org/docs/main/src/content/docs/api-reference/process.md>

### Static analysis, formatting, toolchain

- `Kampfkarren/selene` — `README.md` (design priorities):
  <https://raw.githubusercontent.com/Kampfkarren/selene/main/README.md>
- `Kampfkarren/selene` — `docs/src/SUMMARY.md` (verified complete lint list used in §7.2):
  <https://raw.githubusercontent.com/Kampfkarren/selene/main/docs/src/SUMMARY.md>
- `Kampfkarren/selene` — `docs/src/roblox.md` (`std = "roblox"`, 6-hour auto-update,
  `update-roblox-std`, `std = "roblox+testez"` + `testez.yml`, `roblox-std-source = "pinned"`,
  `generate-roblox-std`): <https://raw.githubusercontent.com/Kampfkarren/selene/main/docs/src/roblox.md>
- `Kampfkarren/selene` — `docs/src/cli/usage.md` (verified flags: `--allow-warnings`,
  `--display-style`, `--config`, `--pattern`, subcommands):
  <https://raw.githubusercontent.com/Kampfkarren/selene/main/docs/src/cli/usage.md>
- `JohnnyMorganz/StyLua` — `README.md` (`--check`, `stylua.toml` discovery, defaults
  `column_width = 120`, `indent_type = "Tabs"`, `indent_width = 4`, `syntax`):
  <https://raw.githubusercontent.com/JohnnyMorganz/StyLua/main/README.md>
- `JohnnyMorganz/luau-lsp` — `README.md` (`luau-lsp analyze` as the CI entry point; Rojo sourcemap
  via `rojo sourcemap --watch default.project.json --output sourcemap.json`; Roblox definitions
  preloaded): <https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/README.md>
- `UpliftGames/wally` — `README.md` (`wally install --locked` "Intended for use on CI machines";
  `wally.toml`, `[dev-dependencies]`, realms):
  <https://raw.githubusercontent.com/UpliftGames/wally/main/README.md>
- `rojo-rbx/rojo` — `README.md`: <https://raw.githubusercontent.com/rojo-rbx/rojo/master/README.md>
- `rojo-rbx/rokit` — `README.md` (toolchain manager; Foreman/Aftman drop-in compatibility;
  installer script): <https://raw.githubusercontent.com/rojo-rbx/rokit/main/README.md>

### Luau language

- `luau-lang/luau` — `Config/include/Luau/LinterConfig.h` (verified all 29 `LintWarning::Code`
  values and `kWarningNames`, plus the "disabled in Studio" annotations):
  <https://raw.githubusercontent.com/luau-lang/luau/master/Config/include/Luau/LinterConfig.h>
- `luau-lang/luau` — `Analysis/include/Luau/Linter.h` (`LintResult`, `lint()` entry point):
  <https://raw.githubusercontent.com/luau-lang/luau/master/Analysis/include/Luau/Linter.h>
- `luau-lang/luau` — repository root, confirming that narrative documentation now lives at
  `luau.org` rather than in `/docs` (the requested `/docs` type-checking and linting pages do not
  exist at that path in `master`): <https://github.com/luau-lang/luau>

### Roblox platform documentation (from `Roblox/creator-docs`)

- Type checking (`--!nocheck` / `--!nonstrict` / `--!strict`, `any` by default in nonstrict):
  `content/en-us/luau/type-checking.md`
- Data store limits (verified **4,194,304 bytes per key**, 50-character key names, 300-character
  metadata, throughput budgets, error codes):
  `content/en-us/cloud-services/data-stores/error-codes-and-limits.md`
- Data store best practices (one key per player under the 4 MB limit; buffer in memory; save
  interval shorter than session-lock expiry with the 180 s sample; exponential backoff with jitter;
  ordered retries per key; prefer `UpdateAsync` over `SetAsync`):
  `content/en-us/cloud-services/data-stores/best-practices.md`
- Data stores overview (`RemoveAsync`, metadata, `DataStoreKeyInfo`):
  `content/en-us/cloud-services/data-stores/index.md`
- Studio testing modes (Test / Test Here / Local Server, client-server toggle and border colours,
  Pause/Resume per side, Step Forward at 1/60 s, blue/green output labels):
  `content/en-us/studio/testing-modes.md`
- `ScriptContext.Error` (verified parameters `message: string`, `stackTrace: string`,
  `script: Instance`; verified note that it does **not** fire for watchdog timeouts):
  `content/en-us/reference/engine/classes/ScriptContext.yaml`
- `LogService.MessageOut` (verified parameters `message: string`, `messageType: MessageType`,
  `context: table?`): `content/en-us/reference/engine/classes/LogService.yaml`
- Server crashes chart and out-of-memory snapshots (OOM vs platform crashes; automatic JSON
  data-model summary; treemap viewer; CSV download):
  `content/en-us/production/analytics/crashes.md`
- Test on hardware (emulation limits; Android ≈65% of player base with the 2–4 GB / 4–8 GB / >8 GB
  split; Passmark 10,000–20,000 for >50% of players; suggested device spread; Developer Console
  <kbd>F9</kbd>, MicroProfiler shortcut, Performance Stats; thermal throttling):
  `content/en-us/performance-optimization/test-on-hardware.md`
- Adaptive design guidelines (input fluidity, responsive layout, dynamic sizing, legibility):
  `content/en-us/production/publishing/adaptive-design.md`

Raw-content base for all of the above:
`https://raw.githubusercontent.com/Roblox/creator-docs/main/`

### Marked-uncertain claims in this chapter

- TestEZ's maintenance status is inferred from its own documentation wording and the absence of
  recent feature work; no formal deprecation notice was found. `[UNVERIFIED]`
- Luau `require` alias (`.luaurc`) behaviour inside Roblox differs by context and release; verify
  against your Studio version. `[UNVERIFIED]`
- Cross-platform bit-identity of `math.exp`/`math.pow` on the platforms Roblox ships was not
  confirmed; the tolerance policy in §3.3 assumes it does not hold. `[UNVERIFIED]`
- Roblox provides no first-party session-lock primitive; the `UpdateAsync`-based pattern in §6 is
  the community standard. `[UNVERIFIED]`
- Tool version pins in `rokit.toml` are illustrative and must be resolved against current releases.
  `[UNVERIFIED]`
- The `CompeyDev/setup-rokit` GitHub Action and the practice of running `run-in-roblox` on a
  self-hosted Windows runner are community practice, not first-party.
  `[COMMUNITY, SECOND-HAND]`
