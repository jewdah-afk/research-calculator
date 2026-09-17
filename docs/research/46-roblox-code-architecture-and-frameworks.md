# Roblox/Luau Code Architecture: Frameworks, Patterns, and a Codebase That Scales

*Research chapter. Status verified September 2026. Every maintenance claim below is dated and sourced; anything I could not verify from a primary source is explicitly flagged.*

---

## TL;DR for builders

- **The DataModel *is* your architecture.** Container choice is not organization, it is a security and replication decision. `ServerScriptService`/`ServerStorage` never reach the client; `ReplicatedStorage`/`ReplicatedFirst` always do. Anything you put in `ReplicatedStorage` is readable by every exploiter in your game. ([Roblox: Data model](https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/data-model.md))
- **Use the single-entry-point pattern.** One `Script` bootstraps the server, one `LocalScript`/client `Script` bootstraps the client, and *everything else is a ModuleScript*. Roblox's own Plant reference project does exactly this, and names the reason: "Greater control over the order in which different systems are executed in." Multiple entry points execute "in a non-deterministic order." ([Plant reference project](https://github.com/Roblox/creator-docs/blob/main/content/en-us/resources/plant-reference-project.md))
- **`Script.RunContext` changed the rules but did not delete the old ones.** `RunContext` is `Legacy`(0) / `Server`(1) / `Client`(2) / `Plugin`(3). It exists only on `Script` — `LocalScript` cannot use it. `LocalScript` is *not* deprecated. Roblox now recommends client `Script`s with `RunContext = Client` in `ReplicatedStorage` over `LocalScript`s in Starter containers, mainly for debuggability. ([RunContext enum](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/RunContext.yaml), [Script types and locations](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/locations.md))
- **Script load order is genuinely unreliable and you must not design around it.** Roblox states plainly: "The Roblox Engine doesn't guarantee the order in which objects (and changes to objects) are replicated from the server to the client." The only guaranteed ordering is `ReplicatedFirst` first. ([Replication order](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/attributes.md))
- **Knit is archived (31 July 2024) and you should not start a new project on it.** Sleitnick's own `ARCHIVAL.md` explains why and, notably, does not name a replacement: "ModuleScripts themselves can already work in this way out of the box" and, for networking, write "a shallow wrapper around RemoteEvents et. al." ([Knit ARCHIVAL.md](https://github.com/Sleitnick/Knit/blob/main/ARCHIVAL.md))
- **Matter is effectively dormant.** Its most recent commit on `main` is from **November 2024** — roughly 22 months stale as of this writing — with `0.8.5` as the last stable and a `0.9.0-beta.0` that never shipped. Jecs, by contrast, was committed to in **July 2026**. If you want ECS on Roblox in 2026, pick Jecs. ([matter commits](https://github.com/matter-ecs/matter/commits/main), [jecs commits](https://github.com/Ukendio/jecs/commits/main))
- **Flamework is excellent and irrelevant to most teams: it requires TypeScript.** Its own README is one line — "It requires typescript and offers many useful features and abstractions." If you are not committing the whole studio to roblox-ts, Flamework is off the table. ([flamework/core](https://github.com/rbxts-flamework/core))
- **My recommendation: no framework. Plain typed modules + a small set of hand-picked libraries.** Every general-purpose Roblox framework of the last five years is either archived (Knit), dormant (Matter), or language-locked (Flamework). Conventions you own do not get archived. Section 3 defends this at length.
- **Prefer a pure-Luau `Signal` over `BindableEvent` for all in-process events.** `BindableEvent` *serializes* its arguments across the C++ boundary: non-string table keys silently become strings, mixed tables lose elements, metatables are stripped, table identity is not preserved. A Luau Signal passes references, costs less, and is typeable with `Signal<T...>`. ([Bindable argument limitations](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/events/bindable.md))
- **Never `InvokeClient`.** A malicious client sets `OnClientInvoke = function() task.wait(9e9) end` and your server thread is gone forever. Client→server `RemoteFunction` is merely bad (it blocks a server thread on request); server→client is a free denial-of-service primitive. Use two `RemoteEvent`s with a correlation id.
- **ProfileStore, not ProfileService.** ProfileService is unsupported; ProfileStore is the successor by the same author (loleris), with faster session-lock conflict resolution via MessagingService and a ~10x reduction in DataStore calls. Session locking is non-negotiable — it is what prevents item duping. ([ProfileStore](https://github.com/MadStudioRoblox/ProfileStore))
- **Version your save schema from commit one.** Nobody does this and everybody regrets it. `Profile:Reconcile()` fills in *missing* keys from a template; it cannot rename a field, change a type, or restructure a subtree. You need an explicit `dataVersion` and an ordered migration chain. Section 9 has the implementation.
- **`--!strict` everywhere, including the awkward parts.** Roblox's own reference project uses "`strict` typechecking ... for every script" and documents the three workarounds you will need (typed class syntax, post-guard casts, DataModel traversal). The new type solver reached general release around 20 November 2025 and is controlled by `Workspace.UseNewLuauTypeSolver`; default mode is set by `Workspace.LuauTypeCheckMode`.
- **TestEZ is archived (14 Sep 2024). Use Jest Lua.** Roblox uses Jest Lua internally for its apps, core scripts and Studio plugins. Run pure-logic tests under Lune in CI; run DataModel-touching tests in Studio or Open Cloud. ([testez](https://github.com/Roblox/testez), [jest-lua](https://github.com/jsdotlua/jest-lua))
- **Your CI is: Rokit → Wally install → StyLua check → Selene → Lune tests → Rojo build.** That is five minutes of setup and it is the difference between a codebase and a pile of scripts. Section 11 has a working workflow.

---

## Framework comparison table

| | **Knit** | **Flamework** | **Matter** (ECS) | **Jecs** (ECS) | **Plain modules + conventions** |
|---|---|---|---|---|---|
| **What it solves** | Boilerplate for server/client singletons + auto-generated remotes | DI container, lifecycle, components, typed networking — a real IoC framework | Data-oriented simulation: decouple behaviour from identity | Same, plus first-class entity *relationships* | Nothing, by design — you solve exactly your problems |
| **Unit model** | `Service` (server) / `Controller` (client); `service.Client` table is auto-exposed | `@Service` / `@Controller` / `@Component` classes, constructor-injected | `World` + `component()` + systems scheduled by a `Loop` | `world:entity()`, `world:component()`, `world:query()`, `pair()` | Whatever you decide: singleton modules, classes, systems |
| **Networking** | Auto RemoteFunction/RemoteEvent from `Client` table; Promise-returning by default (`ServicePromises`) | `@rbxts/flamework` networking module with TS-derived runtime validation | None (out of scope) | None (out of scope) | Yours — a ~150-line typed wrapper, or Blink/Zap |
| **Language** | Luau | **TypeScript only** (roblox-ts) | Luau | Luau (+ rbxts bindings) | Luau |
| **Status (Sep 2026)** | 🔴 **Archived 31 Jul 2024** | 🟢 Active, but TS-locked | 🟠 **Dormant — last commit Nov 2024** | 🟢 Active (Jul 2026) | 🟢 Immortal |
| **Learning cost** | Low (a day) | High (DI + decorators + TS toolchain) | Medium-high (ECS mental model + topological hooks) | Medium-high (ECS + relationships) | Low upfront, high discipline |
| **Typing quality** | Poor — the stated reason for archival: "Knit cannot fully benefit from types, and thus does not have good intellisense" | Excellent (TS) | Moderate | Good — "Type-safe Luau API", `jecs.Id<T>` | As good as you write |
| **Right call when** | Never, for new work | Your studio is all-in on roblox-ts | Legacy projects already on it | Thousands of simulated entities, heavy per-frame queries | **Almost always** |

**Verdict up front: build on plain typed modules with strict conventions, and add Jecs only for the subsystem that genuinely needs ECS.** The justification is in §3.4.

---

## 1. The DataModel as architecture

### 1.1 Containers are a security boundary, not a filing cabinet

New Roblox developers treat `ReplicatedStorage` as "the shared folder." It is not. It is **a public broadcast**. Everything in it is sent to every client, and every client can read it with a script executor. The container table, from Roblox's own docs:

| Container | Replicates to client? | Scripts run? | Use for |
|---|---|---|---|
| `Workspace` | Yes (subject to streaming) | Server `Script`s (Legacy) | The 3D world |
| `ReplicatedFirst` | **Yes, first, once** | Client scripts | The *absolute minimum* to show a loading screen |
| `ReplicatedStorage` | Yes | `Script` with `RunContext = Client` or `Server`; **`LocalScript`s do not run here** | Shared ModuleScripts, remotes, prefabs |
| `ServerScriptService` | **No** | Server `Script`s | Server entry point + server-only modules |
| `ServerStorage` | **No** | **No** — but server scripts can `require()` ModuleScripts here | Server-only modules, map/prefab assets not yet needed |
| `StarterPlayerScripts` | Copied → `Player.PlayerScripts` | `LocalScript`s, on join | Persistent client scripts |
| `StarterCharacterScripts` | Copied → `Player.Character` | `LocalScript`s, on spawn | Per-life character scripts |
| `StarterGui` | Copied → `Player.PlayerGui` (emptied on respawn) | `LocalScript`s | UI prefabs |
| `StarterPack` | Copied → `Player.Backpack` | `LocalScript`s | `Tool`s |

Two consequences most codebases get wrong:

1. **`ServerStorage` is the underused one.** Roblox's own guidance: it "is ideal for large objects that don't need to be immediately replicated to clients when they join a game." Every map, every enemy prefab, every rarely-used model you park in `ReplicatedStorage` is join-time bandwidth you are charging every player. Move it to `ServerStorage` and clone it into `Workspace` on demand. The Plant project does exactly this with its `Farm` template.
2. **`ReplicatedFirst` is a budget, not a folder.** "The more instances that are placed in `ReplicatedFirst`, the longer the wait for them to replicate before code in `ReplicatedFirst` can run." Put the loading screen and the bootstrap starter in it. Nothing else.

### 1.2 Script types and `RunContext` — verified

Three script types, and the rules are genuinely asymmetric:

- `Script` — runs on server *or* client depending on location **and** `RunContext`.
- `LocalScript` — client only. **Has no `RunContext`.** Inherits from `Script` in the class hierarchy, but `RunContext` is unusable on it. Not deprecated.
- `ModuleScript` — never runs on its own; no `RunContext`.

`Enum.RunContext` values, verified against the API dump:

| Value | Name | Behaviour |
|---|---|---|
| 0 | `Legacy` | **Default.** Container-based behaviour: a `Script` is server-side and runs only in a server container (`Workspace`, `ServerScriptService`, …) |
| 1 | `Server` | Runs on the server regardless of container — including `ReplicatedStorage` (don't) |
| 2 | `Client` | Runs on the client regardless of container — `ReplicatedStorage`, `ReplicatedFirst`, and the Starter containers |
| 3 | `Plugin` | Runs as a descendant of a `Plugin` |

Changing `RunContext` at runtime "terminates any active threads and restarts the script under the new context if conditions permit."

**The trap nobody mentions:** setting `RunContext = Client` on a `Script` inside a **Starter container** runs it *twice*. Roblox's docs say it directly: "Starter containers are copied to clients, though, so the original script **and** the copy run, which isn't desirable." So the rule is clean:

> `RunContext = Client` scripts live in `ReplicatedStorage`/`ReplicatedFirst`. `LocalScript`s live in Starter containers. Never mix.

Roblox's current recommendation is the former, for a specific and good reason: when you click an error in Output, you land on `ReplicatedStorage.YourScript` — "the stable location of the script" — rather than `Players.YourName.PlayerScripts.YourScript`, "the ephemeral location that the script was copied to at runtime." That matters a lot when you are debugging a live game.

There is one real reason to keep using Starter containers: `StarterCharacterScripts` gives you per-life lifecycle for free. If you want a script that dies and respawns with the character, that container *is* the feature.

### 1.3 Why load order is unreliable

This is the single most under-appreciated fact in Roblox architecture. From the replication-order docs:

> "The Roblox Engine doesn't guarantee the order in which objects (and changes to objects) are replicated from the server to the client, which makes the `Instance:WaitForChild()` method essential for accessing objects in client scripts."

And more sharply:

> "if a server script changes a property of some instance in the Workspace and then calls `RemoteEvent:FireAllClients()`, the property change might replicate to the client before or after `OnClientEvent` fires."

The one useful guarantee: *changes of the same type generally do arrive in order* (two attribute writes will land in order).

The *only* deterministic part of client startup is:

1. `ReplicatedFirst` contents load.
2. Client scripts in `ReplicatedFirst` run. These can safely `require` things **in `ReplicatedFirst`** with no `WaitForChild`.
3. The rest of the game loads.
4. `DataModel.Loaded` fires / `game:IsLoaded()` returns true.

Note step 2's sharp edge: a `ReplicatedFirst` script requiring `ReplicatedStorage.Something` is *not safe* — that service may not have loaded. You can `WaitForChild` it, but then you have given up the entire point of being in `ReplicatedFirst`.

**Architecturally, all of this collapses into one rule: never let correctness depend on which script ran first. Have one script.**

### 1.4 The single-entry-point pattern

Roblox's Plant reference project frames the tradeoff honestly:

| Single entry point | Multiple entry points |
|---|---|
| One `Script` + one `LocalScript` | New scripts created as needed |
| "Greater control over the order in which different systems are started" | "Greater ability to isolate code" |
| "Can pass objects by reference between systems" | Can use `Actor`s and multithreading |
| | **"Execution is in a non-deterministic order"** |

Take the single entry point. The `Actor`/multithreading argument is the only real counter, and you handle it by giving each `Actor` its own small bootstrap — a deliberate, enumerated exception rather than ambient chaos.

Here is the bootstrap I would actually ship. Note the explicit two-phase lifecycle: **every module is constructed before any module starts**, which is what kills the entire class of "A needs B but B isn't ready" bugs.

```lua
--!strict
-- ServerScriptService/Main.server.luau  (RunContext = Legacy is fine here)

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ServerStorage:WaitForChild("Source")

-- Explicit manifest. Not a folder scan.
-- Order here is *construction* order; see below for why it barely matters.
local SERVICES: { ModuleScript } = {
    Modules.data.PlayerDataService,
    Modules.economy.CurrencyService,
    Modules.combat.CombatService,
    Modules.rounds.RoundService,
    Modules.net.NetworkService,
}

type Lifecycle = {
    name: string,
    init: (() -> ())?,   -- wire up state; MUST NOT yield, MUST NOT call other services
    start: (() -> ())?,  -- may yield, may call any other service
}

local loaded: { Lifecycle } = {}

-- Phase 1: require everything. Modules run their top-level code here.
for _, moduleScript in SERVICES do
    local ok, result = pcall(require, moduleScript)
    if not ok then
        error(`[Bootstrap] failed to require {moduleScript:GetFullName()}: {result}`, 0)
    end
    result.name = moduleScript.Name
    table.insert(loaded, result :: Lifecycle)
end

-- Phase 2: init, synchronously, in manifest order. No yielding allowed.
for _, service in loaded do
    if service.init then
        debug.profilebegin(`init:{service.name}`)
        service.init()
        debug.profileend()
    end
end

-- Phase 3: start, concurrently. Yielding is fine; every service already exists.
for _, service in loaded do
    if service.start then
        task.spawn(function()
            debug.setmemorycategory(service.name)
            service.start()
        end)
    end
end

print(`[Bootstrap] {#loaded} services online`)
```

Why this shape:

- **`init` must not yield.** That is the invariant that makes phase 2 meaningful. If `init` yields, phase 3 can begin for some services while others are half-constructed, and you are back to non-determinism. Enforce it in code review; it is worth a lint rule.
- **`start` runs in `task.spawn`.** One slow service (a DataStore warm-up, a MessagingService subscription) must not block the others. A service that errors in `start` takes down only itself.
- **Explicit manifest, not a folder scan.** Auto-discovery by `GetDescendants()` is seductive and wrong: it reintroduces the non-determinism you just eliminated (child order is stable but *renaming a file changes your boot order*), it makes dead code invisible, and it makes "why did this load?" unanswerable. A list you can read is worth the twelve seconds it costs to maintain.
- **`debug.setmemorycategory`** buys you per-service memory attribution in the Developer Console for free. Do it.

The client bootstrap is the mirror image, with one addition — it waits for the game to finish loading before starting UI:

```lua
--!strict
-- ReplicatedStorage/Client/Main.client.luau  (Script, RunContext = Client)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Client")

local CONTROLLERS = {
    Modules.net.NetworkController,
    Modules.data.PlayerDataController,
    Modules.ui.UIController,
    Modules.input.InputController,
    Modules.camera.CameraController,
}

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ... identical three-phase loop ...
```

---

## 2. Module patterns

### 2.1 `require` semantics, precisely

Two properties, both load-bearing:

> "When you call `require()` on a `ModuleScript`, it runs once and returns a single item as a reference. Calling `require()` again returns the exact same reference ... The module itself doesn't run multiple times."

> "If you require a `ModuleScript` from both sides of the client-server boundary ... the `ModuleScript` returns a unique reference for each side."

So: **the module cache is per-Luau-VM.** Server and each client get their own instance. This is exactly what makes the singleton pattern work — and it is also the trap that catches people who think a shared `ReplicatedStorage` module gives them shared *state*. It gives shared *code*.

Circular requires error with `Requested module was required recursively`.

### 2.2 The four module shapes

**(a) Singleton service** — no `new()`, dot-call methods, state lives in the module.

The Plant project's rationale is worth quoting because it names the mechanism: singletons "take advantage of the fact that requiring a `ModuleScript` caches its returned value ... requiring the same singleton `ModuleScript` from different places consistently provides the same returned object." And the convention: "As singletons are not instantiated, the `self` syntax is not used and methods are instead called with a dot (`.`) rather than a colon (`:`)."

That dot/colon split is a genuinely good convention. At a glance you know whether you are looking at a global or an instance.

```lua
--!strict
-- CurrencyService.luau  (singleton)
local Signal = require(script.Parent.Parent.util.Signal)

local CurrencyService = {}

local balances: { [Player]: number } = {}

CurrencyService.balanceChanged = Signal.new() :: Signal.Signal<Player, number>

function CurrencyService.get(player: Player): number
    return balances[player] or 0
end

function CurrencyService.add(player: Player, amount: number): number
    assert(amount == amount and amount ~= math.huge, "amount must be finite") -- NaN/inf guard
    local new = (balances[player] or 0) + amount
    balances[player] = new
    CurrencyService.balanceChanged:Fire(player, new)
    return new
end

function CurrencyService.init() end

function CurrencyService.start()
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        balances[player] = nil
    end)
end

return CurrencyService
```

**(b) Class with `__index`** — the idiomatic Lua form is *not* strict-Luau friendly. The version that is:

```lua
--!strict
-- Projectile.luau
local Projectile = {}
Projectile.__index = Projectile

-- The type is derived from setmetatable, and `self` is declared explicitly.
export type Projectile = typeof(setmetatable(
    {} :: {
        position: Vector3,
        velocity: Vector3,
        owner: Player,
        alive: boolean,
    },
    Projectile
))

function Projectile.new(owner: Player, origin: Vector3, velocity: Vector3): Projectile
    local self = {
        position = origin,
        velocity = velocity,
        owner = owner,
        alive = true,
    }
    return setmetatable(self, Projectile)
end

-- Declared with a dot so `self` can be typed. Still *called* with a colon.
function Projectile.step(self: Projectile, dt: number)
    if not self.alive then return end
    self.velocity += Vector3.new(0, -196.2 * dt, 0)
    self.position += self.velocity * dt
end

function Projectile.destroy(self: Projectile)
    self.alive = false
end

return Projectile
```

Roblox documents both costs of this pattern honestly: "The definition of `self` is duplicated, both in the type declaration and in the constructor. This introduces a maintainability burden, but warnings will be flagged if the two definitions fall out of sync." And: "Class methods are declared with a dot, so `self` can be explicitly declared to be of type `ClassType`. Methods can still be called with a colon as expected."

Pay the duplication. The alternative — `type Projectile = typeof(Projectile.new())` — breaks the moment your constructor takes runtime-only values like a `Player`.

**Prefer composition to inheritance.** Plant again: "the project opts to instead allow classes to extend each other through **composition**." Luau metatable inheritance works, but multi-level `__index` chains are slow to resolve, opaque to the type checker, and a nightmare to refactor. A `self.button = Button.new(...)` field costs you three forwarding methods and buys you clarity.

**(c) Pure function library** — stateless, trivially testable, no lifecycle.

```lua
--!strict
local Grid = {}

function Grid.toCell(position: Vector3, size: number): (number, number)
    return math.floor(position.X / size), math.floor(position.Z / size)
end

function Grid.neighbors(x: number, z: number): { { x: number, z: number } }
    return {
        { x = x + 1, z = z }, { x = x - 1, z = z },
        { x = x, z = z + 1 }, { x = x, z = z - 1 },
    }
end

return table.freeze(Grid)
```

`table.freeze` on stateless libraries is cheap insurance against someone monkey-patching your module at runtime — which, because the cache is shared, would affect every consumer in the VM.

**(d) Factory** — returns a configured closure or table. The right shape when you need several independent instances but no method dispatch, and the best shape for dependency injection:

```lua
--!strict
export type RateLimiter = {
    check: (key: string) -> boolean,
}

local function createRateLimiter(maxPerWindow: number, windowSeconds: number): RateLimiter
    local counts: { [string]: { n: number, windowStart: number } } = {}

    return {
        check = function(key: string): boolean
            local now = os.clock()
            local entry = counts[key]
            if not entry or now - entry.windowStart >= windowSeconds then
                counts[key] = { n = 1, windowStart = now }
                return true
            end
            if entry.n >= maxPerWindow then
                return false
            end
            entry.n += 1
            return true
        end,
    }
end

return createRateLimiter
```

### 2.3 Circular dependencies and how to break them

A circular `require` is a hard error, not a warning. The four fixes, in descending order of how much I like them:

**1. Extract the shared thing (best).** `A` and `B` both need `Types` or `Constants` or a `Signal`. Pull it into `C`, and the cycle is gone. Nine times in ten the cycle is telling you that a third concept exists and you haven't named it yet.

**2. Invert with events.** `Inventory` needs to tell `Quests` that an item was picked up. Don't `require(Quests)` — fire a signal that `Quests` subscribes to. The dependency now points one way: `Quests → Inventory`.

**3. Inject the dependency at init.** The consumer receives what it needs instead of fetching it:

```lua
--!strict
local TradeService = {}

local currency: CurrencyService.Type
local inventory: InventoryService.Type

function TradeService.configure(deps: { currency: CurrencyService.Type, inventory: InventoryService.Type })
    currency = deps.currency
    inventory = deps.inventory
end
```

**4. Deferred require (last resort).** Move the `require` inside the function so it resolves after both modules have finished loading:

```lua
--!strict
local Quests = nil :: typeof(require(script.Parent.QuestService))?

local function quests()
    if not Quests then
        Quests = require(script.Parent.QuestService)
    end
    return Quests :: typeof(require(script.Parent.QuestService))
end

function InventoryService.grant(player: Player, itemId: string)
    -- ...
    quests().notifyItemGranted(player, itemId)
end
```

This works and it is ugly. The `typeof(require(...))` dance preserves types without executing the require at load time (`typeof` on a require expression is resolved statically by the type checker, not at runtime — **verify this holds under the new type solver in your Studio version before relying on it**). Treat every use of this pattern as a TODO.

### 2.4 Dependency injection vs direct requires

The honest framing: **direct `require` is DI with the container hard-coded to the module cache.** It is fine, it is fast, and it is what Roblox's own reference project does. It has exactly one real cost: you cannot substitute a fake in a unit test without touching the DataModel.

So the pragmatic rule:

> **Direct-require your singletons. Inject anything that touches the outside world** — DataStores, `MarketplaceService`, `HttpService`, the clock, the RNG.

```lua
--!strict
-- The seam is small and deliberate.
export type Clock = () -> number
export type Random = (min: number, max: number) -> number

export type Deps = {
    now: Clock,
    randomInt: Random,
    dataStore: DataStoreLike,
}

local function createRoundService(deps: Deps)
    local service = {}
    function service.pickMap(): string
        return MAPS[deps.randomInt(1, #MAPS)]
    end
    return service
end
```

Now `pickMap` is deterministic in a test and random in production, and you did not adopt an IoC container to get there. Full constructor-injection-everywhere is the thing Flamework gives you; if you find yourself building it by hand across fifty modules, that is the signal to actually adopt Flamework (and roblox-ts with it), not to hand-roll a worse version.

### 2.5 Lazy loading

Two genuinely useful forms.

**Lazy submodule table**, for big namespaces where consumers touch a fraction:

```lua
--!strict
local folder = script.Parent.effects

local Effects = setmetatable({}, {
    __index = function(self, key: string)
        local child = folder:FindFirstChild(key)
        if not child or not child:IsA("ModuleScript") then
            error(`Unknown effect '{key}'`, 2)
        end
        local value = require(child)
        rawset(self, key, value)  -- memoize
        return value
    end,
})

return Effects
```

Cost: **the type checker cannot see through `__index`.** `Effects.Explosion` is `any`. That is a real loss, and it is why I would use this only for genuinely dynamic registries (effect names from data, ability ids from a config) — never for your service layer.

**Deferred heavy init**, for modules that are cheap to require but expensive to warm:

```lua
--!strict
local cache: { [string]: PathGrid }? = nil

local function grid(): { [string]: PathGrid }
    if not cache then
        cache = buildNavigationGrids() -- 200ms, only pay it if someone pathfinds
    end
    return cache :: { [string]: PathGrid }
end
```

---

## 3. Frameworks — a real comparison

### 3.1 Knit — archived, and its obituary is the best architecture doc in the ecosystem

**Status: archived 31 July 2024.** The repo banner reads "⚠️ No Longer Maintained ⚠️ — Knit has been archived and will no longer receive updates."

What it did: `Knit.CreateService{ Name = "MoneyService" }` on the server, `Knit.CreateController{}` on the client, and any method you put on `service.Client` was automatically exposed across the boundary as a `RemoteFunction`. `Knit.Start()` returned a Promise. From the client:

```lua
local MoneyService = Knit.GetService("MoneyService")
MoneyService:GetMoney():andThen(function(money) print(money) end)
```

Under the hood Knit built the `RemoteFunction`, wired `self.Server` back to the root service, and — with `ServicePromises = false` — could even make the call look synchronous.

This was genuinely nice, and the reason it died is the important part. From `ARCHIVAL.md`:

> "Changes such as intellisense within Studio's script editor and the introduction of Luau have given developers better tools to build their Roblox experiences."

> "Knit cannot fully benefit from types, and thus does not have good intellisense."

That is the whole story. Knit's magic — string-keyed service lookup, auto-generated remotes — is precisely what a static type system cannot follow. `Knit.GetService("MoneyService")` returns `any`. In 2020 that cost you nothing because nothing was typed. In 2026, with `--!strict` and the new solver, it costs you the entire benefit of the type system at every network boundary in your game.

Sleitnick's replacement advice is deliberately library-free:

> "In order to preserve the longevity of this writing, no libraries can be offered as a solution, as such libraries come and go."

> "ModuleScripts themselves can already work in this way out of the box."

> For networking: write "a shallow wrapper around RemoteEvents et. al." and "adding generic runtime type checks is harder, but can also be trivial for bespoke setups."

He is right, and this chapter's recommendation is essentially an elaboration of that paragraph.

**Should you use Knit?** No, not for new work. If you have a large shipped game on Knit: it still runs, it was battle-tested, and rewriting a working game for framework hygiene is a bad trade. Migrate incrementally — new subsystems as plain modules, wrap Knit service calls behind typed facades at the seams.

### 3.2 Flamework — excellent, and gated behind TypeScript

Flamework is a real IoC framework: `@Service`, `@Controller`, `@Component` decorators, constructor-based dependency injection, lifecycle interfaces (`OnInit`, `OnStart`, `OnTick`, `OnPhysics`, `OnRender`), a component system that binds classes to tagged instances, and a networking module that derives **runtime validators from TypeScript types** via a compiler transformer.

That last feature is the killer one, and it is why Flamework can be typed where Knit couldn't: the transformer sees your `interface FireRequest { weapon: string, direction: Vector3 }` at compile time and emits an actual runtime guard. You get end-to-end type safety across the network boundary with no duplicate schema.

**The blocker is stated in one line in its own README: "It requires typescript."** Flamework is a roblox-ts package. Adopting it means adopting:

- the roblox-ts compiler (actively developed — commits through **16 September 2026**),
- npm/`@rbxts/*` packaging alongside or instead of Wally,
- a compile step between editing and running,
- and a hiring pool of Roblox developers who know TypeScript, which is much smaller than the one that knows Luau.

**When it's the right call:** your studio has web/TS engineers, you're greenfield, and you want the strongest type guarantees available on the platform. For a team of Luau developers it is a large, mostly-orthogonal bet — you would be adopting a language to get a framework.

### 3.3 Matter and Jecs — see §4, but the status matters here

**Matter** is the better-documented, more "Roblox-shaped" ECS: `World`, `component()`, systems as plain functions, a `Loop` that topologically sorts systems by `priority`/`after` constraints and binds them to events, React-style hooks (`useEvent`, `useDeltaTime`, `useThrottle`) built on a topologically-scoped runtime, and a genuinely good built-in visual debugger.

**But it is dormant.** Latest commit on `main`: **November 2024**. Last stable release `0.8.5`; `0.9.0-beta.0` was tagged and never promoted. Its README notes it was "originally pioneered by @evaera" and now sits under the community `matter-ecs` org — a stewardship handoff that has not produced a release in a long time. It is not archived and it is not broken; it is unmaintained in practice. **Verify current status before adopting**; a maintainer could pick it up.

**Jecs** is alive: commits through **July 2026**, "Type-safe Luau API", zero dependencies, archetype/SoA storage, and first-class entity **relationships** (`pair(Likes, alice)`) which is a capability Matter does not have. Its headline claim is "Iterate 800,000 entities at 60 frames per second," with published benchmarks over "21,000 entities 125 archetypes 4 random components queried."

Jecs is lower-level. It gives you a world and queries; it does **not** give you a scheduler, hooks, or a debugger. You write your own `Loop`. For a team that wanted Matter's batteries, that is real work.

### 3.4 Plain modules with conventions — and why this is my recommendation

> **Recommendation: build on plain typed ModuleScripts with enforced conventions. Add Jecs only for the specific subsystem that needs ECS. Do not adopt a general-purpose framework.**

The reasoning, in order of weight:

**1. The empirical record is brutal.** Of the general-purpose Roblox frameworks a team could plausibly have adopted since 2020: **Knit is archived. Matter is dormant. Rodux is superseded. TestEZ is archived. Roact is superseded by community React-Lua. ProfileService is unsupported.** Flamework survives, and it survives partly because it is tied to roblox-ts, which has a compiler team behind it. This is not bad luck — it is what happens when a single volunteer maintainer carries infrastructure for an ecosystem. Betting your five-year codebase on it is betting on that person's next five years.

**2. The frameworks' own authors agree.** Sleitnick archived Knit and told people to use ModuleScripts and a thin remote wrapper. That is not a bitter retreat; it is the verdict of the person who spent four years learning what the abstraction bought and cost.

**3. Frameworks fight the type system.** Every framework benefit on Roblox routes through a string key or dynamic lookup — `Knit.GetService("X")`, tag-driven component binding, folder-scanned auto-registration. Those are precisely the constructs Luau cannot type. In 2020 that didn't matter. Under `--!strict` with the new solver, giving up types at your boundaries is the expensive choice.

**4. The framework's value is mostly ~300 lines you will write once.** Concretely, what Knit gave you: a bootstrap with lifecycle (§1.4, ~60 lines), a typed remote wrapper (§7.2, ~150 lines), a Signal (~80 lines, vendored from `RbxUtil`). That's it. You now own it, it does exactly what you need, it types perfectly, and nobody can archive it.

**5. The conventions are the actual product.** What makes a large codebase work is not the framework — it is that every module has the same shape, every service has the same lifecycle, every remote goes through one place, and every file's location is predictable. Those are decisions, not dependencies.

**When you should override this and take a framework:**

- **Flamework**, if your studio is committing to roblox-ts anyway. Don't adopt TS *for* Flamework; do adopt Flamework if you're adopting TS.
- **Jecs**, for the simulation core of a game with thousands of interacting entities (§4.6).
- **Knit**, only to keep an existing shipped game running.

**When "no framework" fails:** if your team is >6 engineers and you have not written down and *enforced* the conventions, "plain modules" degenerates into "every engineer's personal framework." The conventions must be a linted, reviewed, documented artifact — §12 is that artifact. If you will not maintain it, take Flamework and let a compiler enforce structure for you.

---

## 4. ECS on Roblox specifically

### 4.1 What ECS buys you

Entity-Component-System inverts the usual object model. Instead of `Zombie` being a class with fields and methods, an entity is a bare id; **components** are plain data attached to ids; **systems** are functions that query for "every entity with `Position` and `Velocity`" and transform them in bulk.

The four real wins:

1. **Behaviour becomes composable without inheritance.** `Burning`, `Stunned`, `Flying`, `Networked` are components you add and remove. In OOP those become either a deep inheritance tree or a pile of boolean flags on a god-object.
2. **Iteration is cache-friendly.** Archetype/SoA storage groups entities with identical component sets into contiguous columns, so a system iterating `Position, Velocity` walks packed arrays instead of chasing pointers through 5,000 tables. Jecs explicitly advertises "Cache friendly archetype/SoA storage" and "Optimized for column-major operations."
3. **Systems are trivially testable.** A system is `(world, dt) -> ()`. No DataModel, no `Player`, no yield. Give it a world, assert on the world.
4. **State is centralized and inspectable.** Everything about the game is in one queryable world. This is why Matter's debugger is good: there's one place to look.

### 4.2 What it costs

- **A hard mental reframe.** "Where does the code for zombies live?" has no answer in ECS. It's spread across every system that queries a zombie-ish component set. Teams feel this as a productivity cliff for the first month.
- **Queries are not free at small N.** Below a few hundred entities, a plain array of objects and a `for` loop is faster and vastly simpler. ECS overhead (archetype lookup, iterator setup) is real; Jecs even documents inlining via `query:archetypes()` "for maximum performance to eliminate function call overhead which is roughly 60-80% of the cost for iteration." That number cuts both ways — it tells you iteration overhead *is* the dominant cost at small scale.
- **Ordering becomes a first-class problem.** With OOP you call methods in order. With ECS you must declare system order (Matter: `priority` and `after`), and Matter warns that constraint sets can be "in an unresolvable state. In which case, `scheduleSystems` will error."
- **No yielding inside systems.** Matter: "Yielding is not allowed in systems. Doing so will result in the system thread being closed early." Every async operation must be hoisted out of the simulation into a command/event queue. This is correct design, and it is extra work.

### 4.3 How Matter models it

```lua
--!strict
local Matter = require(ReplicatedStorage.Packages.Matter)

local Position = Matter.component("Position")
local Velocity = Matter.component("Velocity")
local Model    = Matter.component("Model")

-- A system is a plain function. Its arguments come from Loop.new(...).
local function applyVelocity(world, state)
    for id, position, velocity in world:query(Position, Velocity) do
        local dt = Matter.useDeltaTime()
        world:insert(id, position:patch({
            value = position.value + velocity.value * dt,
        }))
    end
end

local function syncModels(world)
    for id, model, position in world:query(Model, Position) do
        model.instance:PivotTo(CFrame.new(position.value))
    end
end

local world = Matter.World.new()
local loop  = Matter.Loop.new(world, {})   -- extra args are passed to every system

loop:scheduleSystems({
    { system = applyVelocity, event = "Heartbeat", priority = 0 },
    { system = syncModels,    event = "Heartbeat", after = { applyVelocity } },
})

loop:begin({
    Heartbeat    = RunService.Heartbeat,
    RenderStepped = RunService.RenderStepped,
})
```

Matter's distinguishing features: **components are immutable** (you `:patch()` and re-`insert`, which is what makes its change-detection and debugger work), systems are scheduled declaratively, and hooks like `useDeltaTime`/`useEvent`/`useThrottle` work via a topologically-scoped runtime so a plain function call knows which system and which call-site it belongs to. `Loop:addMiddleware` lets you wrap every system call (profiling, error capture).

### 4.4 How Jecs models it

```lua
--!strict
local jecs = require(ReplicatedStorage.Packages.jecs)
local pair = jecs.pair

local world = jecs.world()

-- Component ids carry their data type in the Luau type system.
local Position = world:component() :: jecs.Id<vector>
local Velocity = world:component() :: jecs.Id<vector>
local Health   = world:component() :: jecs.Id<number>

local e = world:entity()
world:set(e, Position, vector.create(0, 5, 0))
world:set(e, Velocity, vector.create(0, 0, 10))

local function applyVelocity(dt: number)
    for id, pos, vel in world:query(Position, Velocity) do
        world:set(id, Position, pos + vel * dt)
    end
end
```

Jecs's real differentiator is **relationships as first-class pairs**:

```lua
local ChildOf = world:component()
local Wielding = world:component()

world:add(sword, pair(ChildOf, player))
world:add(player, pair(Wielding, sword))

-- "every entity parented to this player"
for id in world:query(pair(ChildOf, player)) do ... end
```

Its tutorials describe this as letting you "describe entity graphs natively in ECS ... without having to build complex data structures for it." For inventories, sockets/attachments, ownership, targeting, and squad membership this is genuinely better than the alternatives. Queries also support `query:with(...)` (must-have, value not needed) and `query:without(...)` filters.

**Jecs vs Matter, concretely:**

| | Matter | Jecs |
|---|---|---|
| Component data | Immutable tables, `:patch()` | Direct values, `world:set` |
| Relationships | ✗ | ✓ (`pair`) |
| Scheduler | ✓ (`Loop`, priority/after) | ✗ (write your own) |
| Hooks | ✓ (`useEvent`, `useDeltaTime`, `useThrottle`) | ✗ |
| Debugger | ✓ (visual, in-game) | ✗ (docs importable to Studio) |
| Typing | Moderate | Better (`jecs.Id<T>`) |
| Status Sep 2026 | 🟠 dormant (Nov 2024) | 🟢 active (Jul 2026) |

**If you need ECS today, take Jecs and write the ~120-line scheduler yourself.** You need it anyway — Matter's scheduler is coupled to Matter.

### 4.5 The hard part: ECS meets the DataModel

This is where every Roblox ECS project gets uncomfortable, and it is not a library problem — it is ontological. **The DataModel is inherently OOP.** A `Part` is an object with identity, a parent, properties, and events. ECS wants ids and columns. These do not compose; they have to be *bridged*, and the bridge is where bugs live.

Three bridging strategies:

**(a) Instance-as-component (most common).** Store the `Instance` on the entity and have a single "render" system push ECS state onto it.

```lua
local Model = world:component() :: jecs.Id<Model>

-- ECS is the source of truth. The DataModel is a projection of it.
local function renderTransforms()
    for id, model, pos in world:query(Model, Position) do
        model:PivotTo(CFrame.new(pos))
    end
end
```

The rule that makes this work: **one direction only.** ECS → Instance. The moment something else writes `model.CFrame` you have two sources of truth and desync is inevitable. Every mutation of a bridged Instance goes through a system.

**(b) Instance-to-entity map for inbound events.** Roblox events give you an `Instance`; you need the entity.

```lua
local entityOf: { [Instance]: jecs.Entity } = {}

part.Touched:Connect(function(hit)
    local id = entityOf[hit]
    if id then
        queue.push({ kind = "touched", entity = id })  -- defer, never mutate in the callback
    end
end)
```

Two non-negotiables: (1) queue the event, do not mutate the world inside a Roblox callback — systems must own all mutation or ordering is meaningless; (2) clear `entityOf` on despawn or you leak Instances forever.

**(c) Tag-driven spawn.** `CollectionService:GetTagged("Enemy")` → create entity + components. Clean for level-authored content; still needs the `entityOf` map for teardown.

**Lifecycle is the sharp edge.** An entity despawn must destroy the Instance, and an Instance being destroyed (by streaming, by `Debris`, by a rogue script) must despawn the entity. Jecs has cleanup traits and hooks (`100_cleanup_traits`, `110_hooks`) for exactly this; use them rather than hand-rolling. Get this wrong and you get invisible zombies: entities with no model, or models with no entity, both accumulating.

**And the killer constraint: ECS does not replicate.** Roblox replicates the DataModel automatically; it has no idea your world exists. You must write a replication layer — typically "server world is authoritative; a system diffs changed components and sends them over a networking layer; client world applies them." This is the single largest hidden cost of ECS on Roblox and neither Matter nor Jecs solves it for you. Budget weeks, not days.

### 4.6 Which genres actually benefit

**Genuinely benefits:**
- **Simulation / tycoon / idle at scale** — thousands of plots, machines, resources ticking. Uniform data, uniform updates. Textbook ECS.
- **Bullet-hell, tower defense, RTS, swarm combat** — hundreds-to-thousands of homogeneous short-lived entities with identical per-frame math.
- **Survival/crafting with deep status effects** — where `Burning + Wet + Poisoned + Slowed` combinatorics would otherwise be an inheritance nightmare.
- **Anything with rich entity relationships** — inventories, attachment trees, ownership graphs. Jecs's `pair` is a real advantage here.

**Does not benefit (use plain modules):**
- **Obbies, showcases, social hangouts, most simulator-tappers** — dozens of entities, the DataModel *is* your state, ECS is pure overhead.
- **Round-based PvP with ≤30 players** — 30 characters is not a data-oriented problem. Character controllers, matchmaking and scoring are all better as plain services.
- **UI-heavy games** — ECS for UI is a research project, not a shipping strategy. Use §5.
- **Story/narrative games** — bespoke, branching, low-entity-count. ECS actively hurts.

**The best answer is usually hybrid:** ECS for the simulation core, plain services for everything around it (data persistence, matchmaking, monetization, UI, chat). Do not let "we use ECS" become "everything must be an entity."

---

## 5. Reactive UI state

### 5.1 The four options

| | **React-Lua** (`jsdotlua/react-lua`) | **Fusion** | **Vide** | **Imperative** |
|---|---|---|---|---|
| Model | VDOM + reconciliation, hooks | Fine-grained reactive graph, scopes | Fine-grained, Solid-inspired | Direct instance mutation |
| Typing | Good (Flow→Luau translated) | Moderate | Designed for it — "fully type-checkable" | Perfect (it's just instances) |
| Perf shape | Reconciliation cost per update | Surgical updates, no diffing | Surgical updates, no diffing | Fastest possible, if correct |
| Status Sep 2026 | 🟢 active community fork | 🟡 active (Feb 2026) but **0.3 still self-described as beta** | 🟢 active (Aug 2026) | n/a |
| Ecosystem | Largest (React knowledge transfers) | Medium | Small | n/a |

**React-Lua** is "a comprehensive translation of upstream ReactJS 17.x into Lua," and its critical property is that the `jsdotlua` fork is the *community-maintainable* one: Roblox's own `roblox/react-lua` repo is "a read-only mirror of their internal project, and as such cannot be contributed to by the community. They have not published React to any public package registry." Use `jsdotlua`. Roblox uses this lineage internally for its apps, core scripts, and Studio plugins — it is the most battle-tested UI stack on the platform.

**Fusion 0.3** introduced scopes (`doCleanup`), contextuals, and a hybrid execution model. It is actively developed (commits through February 2026). But its own 0.3 release notes say: "There are a lot of features that don't work, aren't implemented, aren't documented fully or which may be tweaked or removed," and recommend against using it for major projects if you can't accept breaking changes. **That warning has been standing for a long time; weigh it accordingly.**

**Vide** is "a reactive Luau UI library inspired by Solid," explicitly designed to be type-checkable, with sources/derived/effects and scoped cleanup. Actively developed (August 2026). It is the best-typed of the declarative options and the smallest ecosystem.

**Imperative** deserves more respect than it gets. Roblox's own Plant reference project **chose imperative** — building UI visually in Studio, storing prefabs in `ReplicatedStorage`, and cloning + mutating them at runtime — "under the notion that showing the transformations directly gives a more effective overview of how UI is created and manipulated." The docs are equally clear about the cost: "complex representations of state can become very hard to find and debug. It's common for errors to emerge ... especially when state and the UI becomes desynchronized due to multiple updates interacting in an unexpected order."

**My recommendation:**
- **Small/medium UI, designer-driven, prefab-heavy:** imperative with a strict component discipline (see §5.3). This is the underrated choice, and Roblox's flagship sample does it.
- **Large, stateful, menu-heavy UI (inventories, shops, crafting, battle passes):** **React-Lua** (`jsdotlua`). Hiring, documentation and the sheer weight of transferable React knowledge dominate.
- **Vide** if you want declarative + best-in-class typing and your team accepts a smaller ecosystem.
- **Fusion** if you already know it and accept the beta warning.

### 5.2 State management: Rodux → Reflex → Charm

The lineage is worth knowing because everyone's tutorials are from a different point on it:

- **Rodux** — Roblox's Redux port. Single store, reducers, actions, middleware. Verbose, superseded.
- **Reflex** — "inspired by Rodux and Silo," with producers, built-in networking, and less boilerplate. Last commit **December 2025** — maintained, not dead.
- **Charm** — "Atomic state management for Roblox," inspired by Jotai and Nanostores, and explicitly "designed to be a more composable alternative to Reflex." Last commit **June 2026**. This is the current default.

Charm's model: independent **atoms** rather than one big store, `computed()` for derived memoized values, `subscribe()`/`effect()` for reactions, `batch()` to coalesce updates, and `untracked()` to read without subscribing (renamed from `peek()` in v0.11 — a breaking change, so check your version).

The important piece for game architecture is **CharmSync**: server-side `addSignalsToClient()` / client-side `patch(updates)`, with delta compression and per-player filtering. That means your server state atoms can replicate to client atoms with one wiring step rather than a bespoke `RemoteEvent` per value.

```lua
--!strict
-- shared/atoms.luau
local Charm = require(ReplicatedStorage.Packages.Charm)

export type Inventory = { [string]: number }

local inventoryAtom = Charm.atom({} :: Inventory)
local coinsAtom     = Charm.atom(0)

-- Derived state is memoized and recomputes only when its inputs change.
local inventoryCountAtom = Charm.computed(function()
    local n = 0
    for _, count in inventoryAtom() do n += count end
    return n
end)

return { inventory = inventoryAtom, coins = coinsAtom, inventoryCount = inventoryCountAtom }
```

```lua
--!strict
-- client: a React component reads the atom and re-renders on change
local function CoinCounter()
    local coins = ReactCharm.useAtom(Atoms.coins)
    return React.createElement("TextLabel", { Text = `{coins} coins` })
end
```

**Caveat: Charm's per-version API churn is real** (the v0.11 rename is the documented example). Pin an exact version in `wally.toml` and read the changelog before bumping.

### 5.3 How UI state should relate to game state

This is the architectural question, and it has a firm answer:

> **UI state and game state are different things, they live in different places, and one flows into the other in exactly one direction.**

Three tiers:

1. **Authoritative game state** — server only. Inventory contents, currency, cooldowns, positions. The client's copy is a *cache*, always potentially stale, never trusted.
2. **Replicated client state** — the client's mirror of (1). This is what Charm atoms (or Plant's `PlayerDataClient`) hold. Read-only from the UI's perspective.
3. **Pure UI state** — which tab is open, scroll position, whether the tooltip is showing, the text in an unsubmitted search box. Never leaves the client, never persists, never touches the server.

The rules that follow:

- **UI never mutates replicated state directly.** A "Buy" button does not decrement `coinsAtom`. It fires a request. The server decides. The server's decision replicates back and `coinsAtom` changes. Optimistic UI is a deliberate, per-feature opt-in with an explicit rollback path — not a default.
- **UI state is not saved.** Do not persist "last open tab" into the player's profile without thinking hard; it bloats your save and couples UI refactors to data migrations.
- **Prefer replicating state over sending UI commands.** Plant's guidance is excellent here: rather than firing a bespoke `UpdateCoins` remote, call `PlayerDataServer.setValue(player, "coins", 5)` and let the client subscribe via `PlayerDataClient.updated`. One mechanism, not N remotes. Their ordered preference for server→client communication is worth copying wholesale:
  1. the player-data system,
  2. **instance attributes** (replicate automatically, and — crucially — "attributes set on a new instance before it is parented to the data model will replicate atomically with the instance itself," which eliminates a whole class of "wait for the data to arrive" races),
  3. **CollectionService tags**,
  4. only then a bespoke remote.

**View management deserves an explicit system.** Plant's `UIHandler` is a good, small pattern: every layer is `HUD` or `Menu`; HUD layers show only when no menu is open; menus live on a **stack** so closing one reveals the one beneath — "it allows menus to be navigated with history." Build this on day one. Retrofitting it into forty screens that each poke `frame.Visible` is miserable.

---

## 6. Events and communication

### 6.1 BindableEvent vs a pure-Luau Signal — Signal wins, decisively

`BindableEvent` looks like the "native" choice for in-process events. It is the wrong one, for three reasons, two of which are correctness reasons rather than performance reasons.

**Reason 1 — it mangles your data.** `BindableEvent` marshals arguments across the Luau↔C++ boundary, and Roblox documents the damage:

- *Non-string indices:* "If any **indices** of a passed table are non-string types, such as an `Instance`, userdata, or function, Roblox automatically converts those indices to strings." Your `{[player] = score}` map silently becomes string keys.
- *Mixed tables:* "do not pass a mixed table of numeric and string keys. Doing so can result in removed elements during the transfer."
- *`nil` values:* avoid them at any index.
- *Table identities:* not preserved — the receiver gets a copy, so `received == sent` is false and mutations don't propagate.
- *Metatables:* stripped. **Your class instances do not survive a BindableEvent.**

That last one is fatal on its own. You cannot pass an object through a `BindableEvent`.

**Reason 2 — it cannot be typed.** `bindable.Event:Connect(function(a, b) end)` gives you `any, any`. A Luau Signal gives you `Signal<Player, number>` and the type checker verifies both the `Fire` and the `Connect`.

**Reason 3 — it's slower.** Every fire crosses the C++ boundary and copies the payload. A Luau Signal passes references and, in the standard `stravant`/`sleitnick` implementation, **reuses coroutines** rather than creating one per handler invocation.

The reference implementation is the "Batched Yield-Safe Signal" by stravant, adapted by sleitnick for Knit and now living in `RbxUtil`. Its header states the design goal exactly: "This implementation caches runner coroutines, so the ability to yield in the signal handlers comes at minimal extra cost over a naive signal implementation that either always or never spawns a thread." Its typed interface:

```lua
export type Connection = {
    Disconnect: (self: Connection) -> (),
    Destroy: (self: Connection) -> (),
    Connected: boolean,
}

export type Signal<T...> = {
    Fire: (self: Signal<T...>, T...) -> (),
    FireDeferred: (self: Signal<T...>, T...) -> (),
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    DisconnectAll: (self: Signal<T...>) -> (),
    GetConnections: (self: Signal<T...>) -> { Connection },
    Destroy: (self: Signal<T...>) -> (),
    Wait: (self: Signal<T...>) -> T...,
}
```

**Vendor this file into your repo.** Do not depend on `RbxUtil` as a package for it. It's 200 lines, it never changes, and owning it means a maintainer change upstream can't break you. (`stravant/goodsignal` is the same lineage, "implemented in pure Lua (using the task library, rather than internally using a BindableEvent), so it does not suffer from memory leaks.")

**`Fire` vs `FireDeferred`:** `Fire` runs handlers immediately and re-entrantly — a handler that fires the same signal recurses. `FireDeferred` defers to the next resumption point (`task.defer` semantics), which breaks re-entrancy but reorders your code relative to the caller. Default to `Fire`; reach for `FireDeferred` only when you have an actual re-entrancy problem, and comment why.

**The one thing `BindableEvent` is still for:** crossing an `Actor` boundary, where you genuinely need the engine's marshalling. That's it.

### 6.2 Observer pattern and event buses

The observer pattern in Luau is just a Signal on a module. The `Changed`-style shape Roblox documents is good:

```lua
--!strict
local Switch = {}
local changed = Signal.new() :: Signal.Signal<boolean>
Switch.changed = changed :: Signal.Connectable<boolean>  -- expose read-only view

local state = false
function Switch.flip(): boolean
    state = not state
    changed:Fire(state)
    return state
end
return Switch
```

Note the `Connectable` cast: consumers get `Connect`/`Once`/`Wait`, not `Fire`. Only the owner fires its own signals. That one convention prevents an enormous amount of spaghetti.

**On event buses:** a global `EventBus.publish("PlayerDied", player)` is the single most reliable way to make a large Roblox codebase unmaintainable. Specifically:

- **Untypeable.** String topics defeat the type checker entirely.
- **Ungreppable in practice.** `grep "PlayerDied"` finds the string, but not who reacts, in what order, or whether anyone does.
- **No ordering guarantees**, and it will matter eventually.
- **Silent failure.** Typo the topic and nothing happens. No error.
- **It hides your dependency graph**, which is exactly the thing you need visible to refactor safely.

The honest test: a bus is decoupling *if and only if* the publisher genuinely doesn't care whether anyone listens (telemetry, analytics, debug tracing, achievement triggers). If the publisher needs the subscriber to have run, that's not a bus — that's a function call wearing a disguise.

> **Use typed signals owned by the module that produces the event. Reach for a bus only for genuinely fire-and-forget cross-cutting concerns, and give it typed topics if you do.**

### 6.3 Promises vs coroutines vs `task`

evaera's Promise library states the problem better than I can:

> "Functions you call can yield without warning, or only yield sometimes, leading to unpredictable and surprising results. Accidentally yielding the thread is the source of a large class of bugs and race conditions that Roblox developers run into."

> "Yielding lacks easy access to introspection and the ability to cancel an operation if the value is no longer needed."

That second point is the one that actually justifies the library. **Cancellation is the feature.** Luau has no way to cancel a yielded coroutine; `task.cancel` kills a thread but doesn't unwind its resources. A Promise chain that you `:cancel()` propagates cancellation upward through `_consumerCancelled` and runs `finally` handlers. For "player left mid-DataStore-load" and "player closed the shop while the purchase prompt was in flight," that is worth real money.

The API surface, from source (v4.0.0):

- **Construction:** `Promise.new(executor)`, `Promise.defer`, `Promise.resolve`, `Promise.reject`, `Promise.try`, `Promise.promisify(fn)` (wraps a yielding function), `Promise.delay(seconds)`, `Promise.fromEvent(event, predicate)`
- **Combinators:** `Promise.all`, `Promise.allSettled`, `Promise.any`, `Promise.some(n)`, `Promise.race`, `Promise.each`, `Promise.fold`
- **Chaining:** `:andThen`, `:catch`, `:tap`, `:finally`, `:andThenCall`, `:andThenReturn`, `:finallyCall`, `:finallyReturn`
- **Resolution:** `:await()` (returns `ok, value`), `:expect()` (returns value or throws), `:awaitStatus()`, `:now()`
- **Control:** `:cancel()`, `:timeout(seconds, rejectionValue)`, `:getStatus()`
- **Retry:** `Promise.retry(fn, times, ...)`, `Promise.retryWithDelay(fn, times, seconds, ...)`
- **Diagnostics:** `Promise.onUnhandledRejection(callback)`

**Status: mature and effectively frozen.** Last commit **October 2023**; last release **4.0.0 (March 2022)**. Not archived, no successor, no known replacement. I read this as "finished" rather than "abandoned" — it is a Promises/A+ implementation, and Promises/A+ stopped changing — but **it is a dependency with no active maintainer, so vendor it or pin it exactly.**

**When to use which:**

| Use | For |
|---|---|
| `task.spawn` / `task.defer` / `task.delay` | Fire-and-forget. The overwhelming majority of async work. |
| Plain yielding function | A single awaited operation with no cancellation or composition needs. |
| **Promise** | Cancellation, timeouts, retry-with-backoff, `all`/`race` composition, or any chain whose failure must be handled in one place. |
| Raw `coroutine.*` | Almost never. Use `task.*` — it integrates with the engine scheduler and gives correct error reporting. |

**Never `coroutine.wrap(f)()` when you mean `task.spawn(f)`.** The former swallows errors silently; the latter reports them to the Output and to error analytics. This is one of the highest-value lint rules you can adopt.

### 6.4 Structuring async flows

The pattern that scales, illustrated on player join — the flow where every Roblox game eventually bleeds:

```lua
--!strict
local Promise = require(ReplicatedStorage.Packages.Promise)

local function loadPlayer(player: Player)
    return Promise.new(function(resolve, reject, onCancel)
        local cancelled = false
        onCancel(function() cancelled = true end)

        local profile = ProfileStore:StartSessionAsync(tostring(player.UserId), {
            Cancel = function()
                -- ProfileStore polls this; stop retrying if the player is gone.
                return cancelled or player.Parent == nil
            end,
        })
        if cancelled then return end
        if not profile then
            return reject("session_unavailable")
        end
        resolve(profile)
    end)
        :timeout(30, "load_timeout")
        :andThen(function(profile)
            profile:AddUserId(player.UserId)   -- GDPR association
            profile:Reconcile()                -- fill missing template keys
            return migrate(profile)            -- see §9.3
        end)
        :andThen(function(profile)
            PlayerRegistry.attach(player, profile)
            return profile
        end)
        :catch(function(err)
            warn(`[Data] load failed for {player.UserId}: {err}`)
            player:Kick("Could not load your data. Please rejoin.")
            return Promise.reject(err)
        end)
end

Players.PlayerAdded:Connect(function(player)
    local pending = loadPlayer(player)
    -- Cancellation is the whole point: if they leave, stop everything in flight.
    Players.PlayerRemoving:Once(function(leaving)
        if leaving == player then pending:cancel() end
    end)
end)
```

Three rules for async flows in a large codebase:

1. **A Promise-returning function must never also yield.** Pick one. Mixed-mode functions ("sometimes returns a value, sometimes a Promise") are the exact bug class Promises exist to eliminate.
2. **Every chain ends in `:catch`.** An unhandled rejection is a silent failure; wire `Promise.onUnhandledRejection` to your error telemetry so you find the ones you missed.
3. **Name the boundary.** Async at the edges (DataStores, HTTP, MarketplaceService, waiting on player input); synchronous in the core (combat math, inventory rules, round logic). A core that yields is a core you cannot unit test.

---

## 7. Networking abstraction

### 7.1 Raw remotes don't scale — but the reason isn't what people think

The usual complaint about raw `RemoteEvent`s is boilerplate. The real problems are worse:

1. **Every remote is an untrusted input and every one is `any`.** `OnServerEvent:Connect(function(player, a, b, c))` hands you three values of unknown type from a hostile source. There is no type checking across the boundary — ever, by construction.
2. **Discovery by string.** `ReplicatedStorage.Remotes.BuyItem` is a runtime lookup the type checker cannot follow and a rename cannot track.
3. **They accumulate.** A shipped game has 80–200 remotes. Without a registry, nobody knows what exists, what's still used, or which ones are unvalidated.
4. **Rate limits are shared and real.** `RemoteEvent` and `UnreliableRemoteEvent` share an approximate **~500 requests/second per client** budget *(community-measured; verify against current engine limits)*. Hundreds of ungoverned remotes will hit it.

### 7.2 A typed networking layer you own

Roblox's own docs show the shape — a module that encapsulates one `RemoteEvent` with an `id` argument so "you don't need to deal with `RemoteEvent` objects in the rest of your codebase." Plant does the same, and lists "Type validation for arguments received from the client at runtime" as a first-class responsibility of its `Network` module.

Here is a compact version with the two properties that matter: **a single declaration site that types both ends**, and **validation that cannot be forgotten**.

```lua
--!strict
-- ReplicatedStorage/Shared/net/Schema.luau
-- One file. Every remote in the game. Both sides import it.

export type Validator<T> = (value: unknown) -> T?

local function str(v: unknown): string? return if type(v) == "string" then v else nil end
local function num(v: unknown): number?
    return if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then v else nil
end
local function int(v: unknown): number?
    local n = num(v); return if n and n % 1 == 0 then n else nil
end
local function vec(v: unknown): Vector3?
    if typeof(v) ~= "Vector3" then return nil end
    local u = v :: Vector3
    -- Reject NaN/inf: exploiters send them to break physics and math downstream.
    if u.X ~= u.X or u.Y ~= u.Y or u.Z ~= u.Z then return nil end
    if u.Magnitude == math.huge then return nil end
    return u
end

return {
    validators = { str = str, num = num, int = int, vec = vec },

    -- id -> { validate, budget (calls per second per player) }
    BuyItem = {
        id = 1,
        validate = function(a: unknown, b: unknown): (string, number)?
            local itemId, qty = str(a), int(b)
            if not itemId or not qty or qty < 1 or qty > 99 then return nil end
            return itemId, qty
        end,
        budget = 4,
    },

    FireWeapon = {
        id = 2,
        validate = function(a: unknown): Vector3?
            return vec(a)
        end,
        budget = 20,
    },
}
```

```lua
--!strict
-- ServerStorage/Source/net/NetworkService.luau
local Schema = require(ReplicatedStorage.Shared.net.Schema)
local Signal = require(ReplicatedStorage.Shared.util.Signal)

local NetworkService = {}

local remote: RemoteEvent
local handlers: { [number]: (player: Player, ...any) -> () } = {}
local buckets: { [Player]: { [number]: { n: number, t: number } } } = {}

local function allowed(player: Player, id: number, budget: number): boolean
    local perPlayer = buckets[player]
    if not perPlayer then perPlayer = {}; buckets[player] = perPlayer end
    local b = perPlayer[id]
    local now = os.clock()
    if not b or now - b.t >= 1 then
        perPlayer[id] = { n = 1, t = now }
        return true
    end
    if b.n >= budget then return false end
    b.n += 1
    return true
end

function NetworkService.on<T...>(entry: { id: number, validate: (...any) -> T..., budget: number },
                                 handler: (player: Player, T...) -> ())
    handlers[entry.id] = function(player, ...)
        if not allowed(player, entry.id, entry.budget) then
            -- Log, don't kick: legitimate lag can burst. Kick on sustained abuse.
            return
        end
        local validated = table.pack(entry.validate(...))
        if validated[1] == nil then
            warn(`[Net] dropped malformed {entry.id} from {player.UserId}`)
            return
        end
        handler(player, table.unpack(validated, 1, validated.n))
    end
end

function NetworkService.init()
    remote = Instance.new("RemoteEvent")
    remote.Name = "Main"
    remote.Parent = ReplicatedStorage

    remote.OnServerEvent:Connect(function(player, id, ...)
        if type(id) ~= "number" then return end
        local handler = handlers[id]
        if not handler then return end
        -- task.spawn so a slow/erroring handler cannot stall the remote queue.
        task.spawn(handler, player, ...)
    end)

    game:GetService("Players").PlayerRemoving:Connect(function(p) buckets[p] = nil end)
end

return NetworkService
```

Usage is now typed and validation is structurally unforgettable:

```lua
NetworkService.on(Schema.BuyItem, function(player, itemId: string, qty: number)
    -- itemId and qty are guaranteed well-formed. Business rules still apply.
    ShopService.purchase(player, itemId, qty)
end)
```

Design notes worth copying:

- **Numeric ids, not strings.** Smaller on the wire, and it forces the schema file to be the single registry.
- **One `RemoteEvent`, multiplexed.** Fewer instances in `ReplicatedStorage`, one place to add logging/metrics/middleware. The tradeoff is you lose per-remote engine-level introspection; worth it.
- **`task.spawn` the handler.** Otherwise one yielding handler delays every subsequent remote.
- **Validators return the typed value or `nil`.** A boolean `isValid` leaves you casting afterwards; returning the value means the type checker carries the refinement forward.
- **Reject NaN and infinity explicitly.** `type(v) == "number"` is true for both, and both propagate through your physics, your economy and your DataStore.

### 7.3 Request/response, and why not `RemoteFunction`

`RemoteFunction` is documented as: "Scripts invoking a `RemoteFunction` **yield** until they receive a response from the recipient."

**Server → client (`InvokeClient`) is a denial-of-service primitive. Never use it.** The exploit is one line on the client:

```lua
-- On a modified client:
SomeRemoteFunction.OnClientInvoke = function() task.wait(9e9) end
```

Your server thread is now gone for the rest of the server's life. Repeat a few hundred times and the server is dead. And even against honest clients: if the client errors, the server gets the error; if the client disconnects mid-invoke, `InvokeClient()` errors.

**Client → server (`InvokeServer`) is merely bad.** It blocks a server thread for the duration, and if your handler yields (DataStore, `MarketplaceService`), a burst of requests parks a burst of threads. It is usable for low-frequency, fast, read-only queries. It is not usable for anything that touches persistence.

**Do this instead — request/response over two `RemoteEvent`s with a correlation id:**

```lua
--!strict
-- Client side
local nextRequestId = 0
local pending: { [number]: (ok: boolean, ...any) -> () } = {}

local function request(entry, ...): Promise.Promise
    nextRequestId += 1
    local requestId = nextRequestId
    local args = table.pack(...)

    return Promise.new(function(resolve, reject, onCancel)
        pending[requestId] = function(ok, ...)
            if ok then resolve(...) else reject(...) end
        end
        onCancel(function() pending[requestId] = nil end)
        requestRemote:FireServer(entry.id, requestId, table.unpack(args, 1, args.n))
    end):timeout(10, "request_timeout"):finally(function()
        pending[requestId] = nil
    end)
end

responseRemote.OnClientEvent:Connect(function(requestId: number, ok: boolean, ...)
    local resolver = pending[requestId]
    if resolver then resolver(ok, ...) end
end)
```

You now have: timeouts, cancellation, no blocked threads on either side, and a `Promise` you can compose. `RemoteFunction` gives you none of those.

*(Knit, notably, made all of its client→service calls Promise-returning by default for exactly this reason — `MoneyService:GetMoney():andThen(...)`.)*

### 7.4 Middleware

Once every remote flows through one function, middleware is trivial and enormously valuable:

```lua
--!strict
type Middleware = (player: Player, id: number, args: { any }) -> boolean  -- false = drop

local middleware: { Middleware } = {}

-- Enforce rate limits (shown inline above; better as middleware)
-- Reject before character spawn
table.insert(middleware, function(player, id, _args)
    if REQUIRES_CHARACTER[id] and not player.Character then return false end
    return true
end)

-- Telemetry: sample 1% of calls for latency/volume dashboards
table.insert(middleware, function(player, id, _args)
    if math.random() < 0.01 then Analytics.count("remote", { id = id }) end
    return true
end)

-- Kill switch for a specific remote without shipping a patch
table.insert(middleware, function(_player, id, _args)
    return not FeatureFlags.isRemoteDisabled(id)
end)
```

That last one is worth the whole layer. When a remote turns out to be exploitable at 2am, you flip a flag instead of publishing.

### 7.5 Batching per frame

Distinct remote calls have per-call overhead and count against the ~500/s/client budget. For anything high-frequency, coalesce:

```lua
--!strict
local queue: { [Player]: { any } } = {}
local scheduled = false

local function flush()
    scheduled = false
    for player, items in queue do
        if #items > 0 then
            eventsRemote:FireClient(player, items)
            table.clear(items)
        end
    end
end

function NetworkService.queueToClient(player: Player, payload: any)
    local q = queue[player]
    if not q then q = {}; queue[player] = q end
    table.insert(q, payload)
    if not scheduled then
        scheduled = true
        task.defer(flush)   -- one send per frame, per player
    end
end
```

`task.defer` (not `Heartbeat`) coalesces everything produced in the current resumption cycle into one send. For genuinely continuous, loss-tolerant data (cosmetic VFX positions, non-authoritative animation hints), use `UnreliableRemoteEvent` — but note its payload cap, documented by the community at roughly **900 bytes** (measured ~908) with larger payloads dropped *(community-measured; verify)*. Never use it for hit registration, currency, or anything requiring ordering.

### 7.6 The libraries, and whether to use one

| Library | What it is | Status (Sep 2026) |
|---|---|---|
| **Blink** | "IDL compiler written in Luau for ROBLOX buffer networking" — you write a `.blink` schema, it generates typed Luau for both sides with validation | 🟢 Active — version bump **0.18.8, April 2026** |
| **Zap** | Same idea: IDL → generated Luau with buffer serialization | 🟡 `0.6.x` maintained by @sasial-dev; **a rewrite is in progress on a `rewrite` branch** — i.e. the current line is in maintenance |
| **ByteNet** | Luau-API (not IDL) buffer networking, strict Luau, rbxts support | 🟡 Small (~78 commits); not archived; lower activity |
| **RbxUtil `Comm`** | Sleitnick's remote abstraction extracted from Knit | 🟡 Alive as part of RbxUtil; carries Knit's typing weakness |

All three buffer libraries do the same core thing: serialize into `buffer` objects rather than sending Luau tables, which cuts bandwidth substantially and — as Blink notes — makes traffic "significantly harder to intercept or analyze via tools like RemoteSpy." Community benchmarks put Blink ahead of Zap and ByteNet on raw throughput *(forum-sourced; treat as directional, benchmark your own payloads)*.

**My recommendation:**

- **Start with the ~150-line hand-rolled layer in §7.2.** It types perfectly, you own it, and it will carry you to a shipped game.
- **Adopt Blink when bandwidth becomes a measured problem** — which, for a game with continuous positional or state streaming, it will. Blink is the most actively maintained, and an IDL means the schema is a build artifact that types both sides automatically.
- **Don't adopt Zap's `0.6.x` for new work** while the rewrite is pending, unless you're comfortable being on a maintenance branch.
- **Whatever you choose, keep your game code behind your own facade.** `Net.fireWeapon(direction)`, not `Blink.FireWeapon.Fire(direction)`. Then swapping the transport is a day, not a quarter. This is the single most important networking decision you will make.

---

## 8. State machines

### 8.1 When a state machine beats a pile of booleans

The tell is combinatorial invalid states. When you have:

```lua
local isReloading = false
local isSprinting = false
local isAiming = false
local isStunned = false
local isDead = false
```

you have declared 32 states, of which maybe 7 are legal, and you are now maintaining the other 25 by hand in every `if` in the file. Every bug report of the form "if you reload while sprinting and get stunned, the gun never fires again" is that arithmetic coming due.

> **Rule: the moment two booleans are mutually exclusive, they are one enum. The moment transitions between those values have rules, that enum is a state machine.**

### 8.2 A typed, minimal FSM

No library needed. This is ~60 lines and types beautifully:

```lua
--!strict
-- Shared/util/StateMachine.luau

export type Machine<S, E> = {
    current: S,
    changed: Signal.Signal<S, S>,   -- (new, old)
    can: (self: Machine<S, E>, event: E) -> boolean,
    fire: (self: Machine<S, E>, event: E) -> boolean,
    destroy: (self: Machine<S, E>) -> (),
}

export type Definition<S, E> = {
    initial: S,
    transitions: { [S]: { [E]: S } },
    onEnter: { [S]: (from: S) -> () }?,
    onExit:  { [S]: (to: S) -> () }?,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new<S, E>(def: Definition<S, E>): Machine<S, E>
    local self = setmetatable({
        current = def.initial,
        changed = Signal.new(),
        _def = def,
    }, StateMachine)
    local onEnter = def.onEnter and def.onEnter[def.initial]
    if onEnter then onEnter(def.initial) end
    return (self :: any) :: Machine<S, E>
end

function StateMachine.can<S, E>(self: any, event: E): boolean
    local row = self._def.transitions[self.current]
    return row ~= nil and row[event] ~= nil
end

function StateMachine.fire<S, E>(self: any, event: E): boolean
    local row = self._def.transitions[self.current]
    local target = row and row[event]
    if not target then
        return false   -- illegal transition: ignored, not an error
    end
    local from = self.current

    local onExit = self._def.onExit and self._def.onExit[from]
    if onExit then onExit(target) end

    self.current = target

    local onEnter = self._def.onEnter and self._def.onEnter[target]
    if onEnter then onEnter(from) end

    self.changed:Fire(target, from)
    return true
end

function StateMachine.destroy(self: any)
    self.changed:Destroy()
end

return StateMachine
```

Applied to a round loop — the canonical Roblox use case:

```lua
--!strict
type RoundState = "Idle" | "Intermission" | "Loading" | "Playing" | "Ending"
type RoundEvent = "enoughPlayers" | "timerDone" | "mapReady" | "winCondition" | "abort"

local machine = StateMachine.new({
    initial = "Idle" :: RoundState,
    transitions = {
        Idle         = { enoughPlayers = "Intermission" },
        Intermission = { timerDone = "Loading",  abort = "Idle" },
        Loading      = { mapReady = "Playing",   abort = "Idle" },
        Playing      = { winCondition = "Ending", abort = "Ending" },
        Ending       = { timerDone = "Idle" },
    } :: { [RoundState]: { [RoundEvent]: RoundState } },
    onEnter = {
        Intermission = function() Countdown.start(20) end,
        Loading      = function() MapService.load(MapService.pick()) end,
        Playing      = function() CombatService.setEnabled(true) end,
        Ending       = function() CombatService.setEnabled(false); Scoreboard.show() end,
    },
    onExit = {
        Playing = function() MapService.unload() end,
    },
})
```

Three properties this buys you that the boolean version cannot:

1. **Illegal transitions are impossible**, not merely unlikely. `fire("winCondition")` while `Idle` returns `false` and changes nothing.
2. **The rules are data you can read in ten seconds** — and print, diagram, or validate in a test.
3. **Cleanup is structural.** `onExit` is the only place that unloads the map, so it cannot be forgotten on one of six exit paths.

### 8.3 Hierarchical state machines

Flat FSMs blow up on character controllers, because `Grounded` and `Airborne` each have sub-states and each duplicates the transitions they share. HSMs fix this: a state can contain a machine, events bubble from child to parent, and the parent handles what the child doesn't.

```lua
--!strict
-- Parent: Alive | Dead
-- Alive contains: Grounded | Airborne
-- Grounded contains: Idle | Walking | Sprinting | Crouching
-- Airborne contains: Jumping | Falling | Gliding

local function fireHierarchical(machine, event): boolean
    -- Deepest state gets first refusal.
    if machine.child and fireHierarchical(machine.child, event) then
        return true
    end
    return machine:fire(event)
end
```

The win: `"damaged"` → `"Dead"` is declared **once**, on the parent, and works from all eight leaf states. In a flat machine that is eight transition entries you must remember to add every time you add a leaf.

The cost: debugging "which level handled this?" is harder. Keep the hierarchy to two or three levels and log transitions in Studio.

### 8.4 Where to use them, concretely

- **Characters** — hierarchical, as above. Also the correct home for ability lockouts: `canFire = machine.current == "Grounded" or machine.current == "Airborne"` beats five booleans.
- **Rounds** — flat, as above. Add an `Ending → Idle` timer so a stuck round always recovers.
- **UI screens** — Plant's `UIHandler` stack is a specialized state machine; a general one works too. Don't let each screen own its own `Visible` boolean.
- **AI** — flat FSM (`Idle/Patrol/Chase/Attack/Flee/Dead`) is right for the overwhelming majority of Roblox NPCs. Behaviour trees are better for genuinely complex AI but cost a lot more; you will know when you need one, and you probably don't.
- **Connection/session lifecycle** — `Connecting → Loading → Ready → Leaving`. This one is underused and prevents a whole class of "player left during load" bugs.

**Anti-pattern: don't put async work inside a transition.** `onEnter` that yields means the machine is in the new state while the entry work is unfinished, and a second event can arrive mid-flight. Either make `onEnter` synchronous and kick off work via `task.spawn`, or add an explicit intermediate state (`Loading`) — which is what the round example does, and why.

---
