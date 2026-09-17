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
