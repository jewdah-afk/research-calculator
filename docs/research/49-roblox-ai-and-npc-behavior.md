# AI and NPC Behavior on Roblox

*Pathfinding, decision-making, perception, combat, and the engineering that makes hundreds of agents cheap.*

**Research date:** 2026-09-17.
**Verification status:** Every Roblox API claim in this chapter was verified against the live `Roblox/creator-docs` repository (`main` branch) on the research date — that repo is the source the Creator Hub renders, so it is the same primary source as `create.roblox.com/docs`. The classic game-AI literature (Reynolds, Nystrom, Millington, Isla, Orkin, Mark, Emerson, Harabor, van den Berg) could **not** be re-fetched in this session: the research sandbox's egress proxy allowed only `github.com` / `raw.githubusercontent.com`, and blocked `create.roblox.com`, `devforum.roblox.com`, `gameprogrammingpatterns.com`, `red3d.com`, `gameaipro.com`, `arxiv.org` and `wikipedia.org`. Those sections are written from established knowledge with canonical citations, and are marked **[lit — not re-verified 2026-09]**. DevForum numbers are marked **[devforum — via search summary]** and should be treated as developer-reported anecdote, not measurement.

---

## TL;DR for builders

- **`PathfindingService` is a navmesh query service, not an NPC controller.** It gives you a list of `PathWaypoint`s and nothing else. Every bit of steering, arrival detection, jumping, re-pathing and stuck-recovery is yours to write. The official sample path-follower in the docs is ~160 lines and is the *minimum*.
- **`Path:ComputeAsync()` yields and is `thread_safety: Unsafe`.** It cannot run inside `task.desynchronize()`/an `Actor` parallel phase. It is the one piece of your AI stack that will never parallelize. Budget it: a global path-request queue with a per-frame cap is not optional above ~30 agents.
- **Hard engine limits, verified:** 3,000 studs straight-line start→finish; a 20,000-node search budget that can exhaust *well* before 3,000 studs in open worlds or mazes; waypoints outside Y ∈ [−65,536, 65,536] ignored. Beyond those, you get `PathStatus.NoPath` and no diagnostic.
- **`PathStatus` has exactly two live values.** `Success` and `NoPath`. `ClosestNoPath`, `ClosestOutOfRange`, `FailStartNotEmpty`, `FailFinishNotEmpty` are all deprecated legacy-engine values. Do not branch on them. Also check `Status ~= Success` *and* `pcall` — `ComputeAsync` can throw.
- **`Humanoid` is the dominant per-NPC cost**, and Roblox says so in its own performance guide: "Although powerful, a `Humanoid` comes with a significant computation cost." The three levers, in order of payoff: don't have one; `Humanoid.EvaluateStateMachine = false`; `Humanoid:SetStateEnabled(state, false)` for every state you don't use.
- **`EvaluateStateMachine = false` is the big documented switch** — no forces, **no sensors** (no floor/ladder/auto-jump spatial queries), no collision-state changes, no automatic state transitions or replication. That is the per-Humanoid physics/query cost gone, while keeping the Humanoid for its rendering, `HumanoidDescription` and FastCluster benefits.
- **For crowds, prefer CFrame-driven rigs with an `Animator` (no `Humanoid`, no physics) moved in bulk via `Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)`.** Developer reports put ~300 humanoid-less rigs at ~150 FPS and ~1,000 at ~40–50 FPS on a desktop client, versus ~150 with Humanoids even with states disabled. **[devforum — via search summary]**
- **Animation LOD is already in the engine and most people don't know.** `Workspace.ClientAnimatorThrottling` (`Enum.ClientAnimatorThrottlingMode`) throttles animation evaluation on remotely-simulated models using camera visibility, FPS and active-animation count; `Animator.PreferLodEnabled` (default `true`) opts a single animator out; `Animator.EvaluationThrottled` tells you, per frame, whether the pose is stale so your procedural layer can skip.
- **`CollectionService:CreateCollection()` (new, query-based `Collection` datatype) is the right NPC registry now.** One engine-side subscription per step dispatches to every member — `function col.OnHeartbeat(npc, dt)` instead of N separate `Heartbeat:Connect` closures — plus `OnAdded`/`OnRemoved`/`OnTouched`/`OnPropertyChanged.X`/`OnAttributeChanged.X` wrappers with automatic teardown.
- **Perception is where O(n²) hides.** Never iterate all agents × all targets. Use a uniform spatial hash (bucket size ≈ your largest query radius) for neighbor queries, and `Workspace:GetPartBoundsInRadius` with a pre-built `OverlapParams` for world queries. Raycasts and the `GetPart*` family are `thread_safety: Safe`, so perception — unlike pathfinding — *does* parallelize under `Actor`s.
- **Pick the decision architecture by branching factor, not by fashion:** ≤5 behaviours → priority list; ≤10 with clear modes → FSM/HFSM; reactive with reusable subtrees → behavior tree; many soft, competing, continuous concerns (a Sims-like, a squad shooter, an RPG companion) → **utility AI** — it produces the most natural-feeling behaviour per line of code; only reach for GOAP when the *sequence* of actions genuinely must be discovered at runtime.
- **The Halo "attack token" pattern is the single highest-value combat trick**: a shared budget of N attack permits per target means five enemies surround you and two attack, instead of five attacking simultaneously and killing you in 0.4 s. It costs ~40 lines and transforms perceived fairness. **[lit — not re-verified 2026-09]**
- **AI fairness is engineering, not design mercy:** a reaction delay (150–400 ms), a telegraph window (wind-up animation ≥ player reaction time), deliberately imperfect aim (spread that tightens with time-on-target), and a "search last known position" behaviour do more for game feel than any amount of planner sophistication.
- **Build the debug draw first.** Path polylines, FOV cones, current BT/FSM node as a BillboardGui, and a ring buffer of decision events per agent. AI bugs are invisible without them, and you will write them eventually — writing them on day one is strictly cheaper.

---

## 1. `PathfindingService` in full

### 1.1 The object model

Three objects, one enum family:

| Thing | What it is | Verified source |
|---|---|---|
| `PathfindingService` | A `Service`, `NotCreatable`, `NotReplicated`. Its only non-deprecated method is `CreatePath`. | `PathfindingService.yaml` |
| `Path` | The result object. Property `Status`; methods `ComputeAsync`, `GetWaypoints`; events `Blocked`, `Unblocked`. | `Path.yaml` |
| `PathWaypoint` | A **datatype** (not an Instance): `Position: Vector3`, `Action: Enum.PathWaypointAction`, `Label: string`. Constructed by `PathWaypoint.new(position, action, label?)`. | `PathWaypoint.yaml` |

`PathfindingService:FindPathAsync(start, finish)` still exists and still works, but is formally deprecated: *"This function has been superseded by the sequential method of calling `PathfindingService:CreatePath()` followed by `Path:ComputeAsync()`."* `ComputeRawPathAsync`, `ComputeSmoothPathAsync` and the `EmptyCutoff` property belong to a pathfinding system that has been **removed** from the engine — `EmptyCutoff`'s deprecation message says so outright. Never use them.

### 1.2 `CreatePath` and every agent parameter

Verified verbatim against `content/en-us/characters/pathfinding.md`:

| Key | Meaning | Type | Default |
|---|---|---|---|
| `AgentRadius` | Agent radius in studs; the minimum separation the navmesh keeps from obstacles. | integer | `2` |
| `AgentHeight` | Agent height in studs. Empty space smaller than this (e.g. under stairs) is marked non-traversable. | integer | `5` |
| `AgentCanJump` | Whether jumping is allowed during pathfinding. | boolean | `true` |
| `AgentCanClimb` | Whether climbing `TrussPart`s is allowed. A climbable path segment gets `PathWaypoint.Label == "Climb"`, and its cost is `1` by default. | boolean | `false` |
| `WaypointSpacing` | Spacing between intermediate waypoints. **`math.huge` produces no intermediate waypoints** — only corners. | number | `4` |
| `Costs` | Table mapping `Enum.Material` **name strings** and `PathfindingModifier.Label` / `PathfindingLink.Label` strings to traversal cost. | table | `nil` |

Notes that matter and are easy to miss:

- `AgentRadius` and `AgentHeight` are documented as **integers**. Passing `2.5` is not a documented contract; round.
- `WaypointSpacing = math.huge` is the single most under-used performance knob. It turns the returned array from "one waypoint every 4 studs along a 400-stud path" (≈100 entries) into "one per corner" (often 4–8). If your follower steers toward corners rather than replaying a breadcrumb trail — which it should, see §2.6 — you want this.
- `Costs` keys are **strings**, not `Enum.Material` values. `Costs = { Water = 20 }`, not `Costs = { [Enum.Material.Water] = 20 }`. All materials default to cost `1`; `math.huge` marks a material non-traversable. The docs explicitly note there is no engine-enforced upper cap below `math.huge`, so `1000` is a legitimate "absolute last resort" value.
- There are **no** parameters for max search distance, timeout, or agent max slope. `AgentMaxSlope`, `AgentCollisionGroupName`, `MaterialWeights` and `CollectionWeights` appear in old DevForum threads; they are not in the current documented parameter table. Treat any code you find using them as folklore.

```lua
--!strict
local PathfindingService = game:GetService("PathfindingService")

-- A path template is reusable: create ONE per agent archetype, not one per request.
local WALKER_PARAMS = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = math.huge,   -- corners only; we steer, we don't breadcrumb
    Costs = {
        Water       = 20,     -- prefer dry land ~20:1
        CrackedLava = 1000,   -- absolute last resort
        DangerZone  = math.huge, -- a PathfindingModifier.Label — never enter
        UseBoat     = 2,      -- a PathfindingLink.Label — cheaper than swimming
    },
}
```

### 1.3 `ComputeAsync` — the yield, and what it actually costs

```lua
local path = PathfindingService:CreatePath(WALKER_PARAMS)
local ok, err = pcall(function()
    path:ComputeAsync(startPosition, goalPosition)
end)
if not ok or path.Status ~= Enum.PathStatus.Success then
    -- handle failure; see §1.4
end
local waypoints = path:GetWaypoints()
```

Facts, verified:

- `ComputeAsync` **yields** and is `thread_safety: Unsafe`. It therefore cannot be called from a desynchronized (`Actor`) parallel phase. This is the structural reason pathfinding does not scale the way perception does.
- `ComputeAsync` can **throw**, not merely fail. Always `pcall`. The official sample does.
- `GetWaypoints()` returns an **empty array** when computation failed, and is also `Unsafe`.
- A `Path` object is reusable: you may call `ComputeAsync` on the same `Path` repeatedly. Reusing the object avoids re-allocating the Instance, but does **not** avoid the navmesh query.
- The first waypoint is essentially your own position; walking to it is a no-op that wastes a frame. The official sample's `findStartingPoint()` skips forward while the next waypoint is within 2 studs horizontally.

**Cost.** Roblox publishes no per-call cost figure. What is documented is the *shape* of the cost: an A*-family search over a voxelized navmesh with a hard ceiling of **20,000 expanded nodes**. Empirically-reported behaviour from developers:

- Typical short paths (tens of studs, simple geometry) complete in single-digit milliseconds. **[devforum — via search summary]**
- Long or maze-like paths at 100–200 studs have been reported at **2–3 seconds** in pathological cases, and one 2026 bug report cites **20+ seconds** with the improved-search algorithm enabled. **[devforum — via search summary: "ComputeAsync Pathfinding Calculation Taking Absurd Amounts of Time" (3044789); "PathfindingService - ComputeAsync taking as long as 20+ seconds with UseImprovedSearch enabled" (4572521)]**
- Degradation with call volume has been reported repeatedly — "lagging after creating enough paths", "slows down with every call" — with one report citing onset at roughly 150 created paths. **[devforum — via search summary: 4677784, 1468961]** The mitigation everyone converges on is the same: **reuse `Path` objects, do not create one per request.**

The practical rule the community settled on is **one re-path per agent per ~0.5 s maximum**, i.e. ≤2 Hz. That gives you a first-order budget: at 60 Hz, a 0.5 s re-path interval and N agents means N/30 `ComputeAsync` calls per frame. At N = 300 that is 10 yielding, unparallelizable navmesh queries every frame. That is not viable; see §1.8 and §7.

### 1.4 `PathStatus` — every value and what it means

Verified from `PathStatus.yaml`:

| Value | Int | Status | Meaning |
|---|---|---|---|
| `Success` | 0 | live | Path found. |
| `ClosestNoPath` | 1 | **deprecated** | Legacy: no path, returns path to closest point. |
| `ClosestOutOfRange` | 2 | **deprecated** | Legacy: goal beyond `MaxDistance`, returns closest reachable. |
| `FailStartNotEmpty` | 3 | **deprecated** | Legacy: start point occupied. |
| `FailFinishNotEmpty` | 4 | **deprecated** | Legacy: finish point occupied. |
| `NoPath` | 5 | live | Path doesn't exist. |

So in practice you get a **binary** answer with no diagnostic. `NoPath` conflates at least six distinct causes, and the docs enumerate four of them under "Limitations and failure factors":

1. **Path request too long** — straight-line start→finish exceeds **3,000 studs**.
2. **Node budget exhausted** — the search exceeded **20,000 nodes**, which "may exceed 20,000 nodes well before reaching the distance cap of 3,000 studs, especially when pathfinding in a vast open world or through complex mazes."
3. **Incompatible agent parameters** — e.g. the only route requires a jump but `AgentCanJump = false`; or `AgentHeight` exceeds the clearance of every route.
4. **Vertical waypoint limits** — candidate waypoints with bottom global Y below −65,536 or above 65,536 studs are ignored.

Plus two the docs imply rather than state: the start or goal is **off the navmesh entirely** (mid-air, inside geometry, on a `CanCollide = false` part), and **streaming** has not loaded the relevant geometry on a client.

Because the engine won't tell you which, instrument it yourself:

```lua
--!strict
local function diagnoseNoPath(startPos: Vector3, goalPos: Vector3, params): string
    local d = (goalPos - startPos).Magnitude
    if d > 3000 then
        return ("TOO_FAR (%d studs > 3000 limit)"):format(d)
    end
    if goalPos.Y < -65536 or goalPos.Y > 65536 then
        return "GOAL_OUT_OF_VERTICAL_RANGE"
    end
    -- Is the goal even on ground? Cast down; if nothing within AgentHeight*2, it's mid-air.
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { workspace.NPCs }
    local hit = workspace:Raycast(goalPos + Vector3.yAxis * 2, Vector3.yAxis * -50, rp)
    if not hit then
        return "GOAL_NOT_OVER_GROUND"
    end
    -- Retry with a permissive agent to distinguish "unreachable" from "params too strict".
    local loose = game:GetService("PathfindingService"):CreatePath({
        AgentRadius = 1, AgentHeight = 3, AgentCanJump = true, AgentCanClimb = true,
        WaypointSpacing = math.huge,
    })
    local ok = pcall(function() loose:ComputeAsync(startPos, goalPos) end)
    if ok and loose.Status == Enum.PathStatus.Success then
        return "AGENT_PARAMS_TOO_STRICT"
    end
    return "GENUINELY_UNREACHABLE_OR_NODE_BUDGET"
end
```

Run that only on failure, and only at a throttled rate — it costs a second `ComputeAsync`.

### 1.5 `Blocked` / `Unblocked` and correct re-pathing

```lua
-- Path.Blocked(blockedWaypointIdx: int)   -- 1-based
-- Path.Unblocked(unblockedWaypointIdx: int)
```

The critical subtlety, called out explicitly in the docs: **a path can become blocked *behind* the agent.** Rubble falling on the route you already ran down still fires `Blocked`. Re-pathing on every `Blocked` fire is a classic bug that turns one falling crate into a re-path storm across every NPC in the level.

```lua
blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
    if blockedWaypointIndex >= nextWaypointIndex then   -- only if AHEAD of us
        blockedConnection:Disconnect()                  -- stop listening until recomputed
        resetWaypointData()
        requestRepath()                                  -- goes through the budget queue
    end
end)
```

`Path:CheckOcclusionAsync(startIndex)` still exists (returns the first blocked waypoint index from `startIndex`, or `-1`) but is **deprecated in favour of the `Blocked` event**, and it yields. Don't poll it.

Streaming interacts with this directly. The docs' streaming-compatibility guidance: geometry streaming in ahead of a running character *will* block paths, so "it's highly recommended that you use the handling-blocked-paths technique and re-compute the path when necessary." And client-side `ComputeAsync` to an object that hasn't streamed in will fail — the recommended fix is to target a `BasePart` inside a **persistent** model and wait on `Workspace.PersistentLoaded`.

### 1.6 `PathfindingModifier`: cost regions and `PassThrough`

Two properties, both verified:

| Property | Type | Meaning |
|---|---|---|
| `Label` | string | Name of the navigation area inside/on top of the enclosed parts. Match this key in `Costs`. |
| `PassThrough` | boolean | The enclosed parts are traversable **even if they would normally be collided with**. |

Usage is: anchored part, `CanCollide = false`, `PathfindingModifier` child, set `Label`, then reference that label in `Costs`. `math.huge` makes the region impassable.

`PassThrough` is the interesting one and is widely misunderstood. It is not "walk through walls" — it is **"let the path be computed as if the obstacle weren't there."** The docs' own example is a door: the zombie's path extends *beyond* a closed door, so the zombie "reacts as if it 'hears' the character behind the door." Your script is then responsible for actually opening/breaking the door when the agent reaches that waypoint. This is the correct way to build:

- doors, gates and breakable walls that AI knows how to deal with,
- destructible cover,
- one-way drop-downs the navmesh would otherwise refuse,
- "AI can take this route, players can't" and vice versa (put the blocker on a collision group players collide with and NPCs don't).

**Verified caveat worth flagging:** a 2026 bug report states `PathfindingModifier` does not update the navmesh when destroyed. **[devforum — via search summary: 4665647; unverified]** If you dynamically remove modifiers, test that paths actually change, and consider toggling `Label`/`PassThrough` rather than destroying.

### 1.7 `PathfindingLink`: jumps, ladders, teleports, vehicles

Four properties, all verified:

| Property | Type | Meaning |
|---|---|---|
| `Attachment0` | Attachment | Originating attachment. |
| `Attachment1` | Attachment | Landing attachment. |
| `IsBidirectional` | boolean, default `true` | Whether the link may be traversed both ways. |
| `Label` | string | Classifying string; **included in the waypoint generated by this link**. |

The traversal contract:

1. Place two `Attachment`s. Create a `PathfindingLink` in the workspace, wire `Attachment0`/`Attachment1`, set `Label` (e.g. `"UseBoat"`).
2. Add a matching key in `Costs` with a value *lower* than the alternative (the docs' example: `UseBoat = 2` vs `Water = 20`).
3. When the path crosses the link, the generated waypoint carries `Action = Enum.PathWaypointAction.Custom` and `Label = "UseBoat"`. The docs' sample script *looks one waypoint ahead* (`waypoints[i+1].Label == "UseBoat"`) and hands off to a custom routine.

`IsBidirectional = false` gives you one-way links — the correct way to model a drop-down ledge, a zipline, or a one-way vent.

The three canonical uses:

- **Ladders/elevators/teleporters** — the navmesh has no concept of these; links are the only way.
- **Long jumps and gap crossings** the automatic jump-link generator won't make. (`PathWaypoint.Label` is documented as `"Jump"` for *automatic* jump links, which is how you distinguish engine-generated jumps from your own links.)
- **Vehicles.** Link the driver seat to the destination dock; the AI "knows" the boat is a shortcut and prices it against swimming.

```lua
--!strict
-- Waypoint dispatch table — the clean way to handle Custom links.
local LINK_HANDLERS: { [string]: (agent: Model, wp: PathWaypoint) -> () } = {}

function LINK_HANDLERS.UseBoat(agent, wp)
    -- seat the agent, drive the boat, unseat at the far attachment
end
function LINK_HANDLERS.Ladder(agent, wp)
    -- drive a climb animation + CFrame lerp up the rungs
end
function LINK_HANDLERS.Zipline(agent, wp) end

local function stepWaypoint(agent: Model, wp: PathWaypoint, humanoid: Humanoid)
    if wp.Action == Enum.PathWaypointAction.Custom then
        local handler = LINK_HANDLERS[wp.Label]
        if handler then return handler(agent, wp) end
        warn(("Unhandled PathfindingLink label %q"):format(wp.Label))
    elseif wp.Action == Enum.PathWaypointAction.Jump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    humanoid:Move(wp.Position - humanoid.RootPart.Position)
end
```

### 1.8 What the navmesh actually is, and its behaviour

Roblox does not publish the navmesh's internals. What is verifiable:

- **You can see it.** Studio's *Visualization Options* widget (upper-right of the 3D viewport) has **Navigation mesh**, **Pathfinding modifiers** and **Pathfinding links** toggles. With Navigation mesh on, "colored areas show where a character might walk or swim. Small arrows indicate areas that a character will attempt to reach by jumping." Use it constantly — most "pathfinding is broken" reports are "there is no navmesh there."
- **It is voxel-derived and auto-generated**, and it regenerates when geometry changes. There is no API to force a rebuild, query it, or read its triangles.
- **It includes terrain water** as swimmable (hence the `Water` cost key).
- **It auto-generates jump links** — the arrows in the visualizer — and labels the resulting waypoints `"Jump"`.
- **It is over-simplified in places.** A 2025 bug report titled "PathfindingService useless from over-optimized NavMesh" **[devforum — via search summary: 3327143; unverified]** captures a real, recurring complaint: the navmesh merges/simplifies geometry aggressively, so thin walkways, railings and small platforms can vanish from it.
- **`ComputeAsync` returns the *shortest* path by default, with one exception:** "it attempts to avoid jumps." That is why paths sometimes take long detours around a trivially jumpable gap.

**2024–2026 change — the improved search algorithm.** Verified in `Workspace.yaml`: the property `Workspace.PathfindingUseImprovedSearch`, type `Enum.PathfindingUseImprovedSearch`, tagged **`NotScriptable`** (Studio-property only, not settable from code). The enum has `Default = 0` ("engine-default behavior"), `Disabled = 1` ("legacy pathfinding search algorithm"), `Enabled = 2` ("improved pathfinding search algorithm"). Timeline from announcements **[devforum — via search summary]**: announced 2024-11-15 as "Improving Pathfinding Quality With New Algorithm" (fixes for poor-quality path generation and paths failing to generate); rolled back during runtime after a sporadic crash while remaining available in Studio; production opt-in **restored 2025-03-10** ("PathfindingUseImprovedSearch Is Now Restored"). There are open reports of pathological compute times under the new algorithm (see §1.3). **Action:** flip it to `Enabled` in Studio, profile your worst-case paths, and keep `Disabled` as a rollback lever if you hit the slow-path bug.

### 1.9 The honest assessment

**What `PathfindingService` is genuinely good at:**

- Zero-authoring navigation over arbitrary, artist-built geometry. No manual navmesh baking, no waypoint graph to maintain. For a mid-size map this saves weeks.
- Multi-level geometry — stairs, bridges, buildings, ramps — which naive grid A* handles badly.
- Automatic jump links across gaps you never annotated.
- Material and region cost shaping without writing a cost function.
- Correct results. When it returns `Success`, the path is walkable.

**Where it is too slow:**

- **At scale.** It yields, it's `Unsafe` (no parallel), the reported degradation with call volume is real, and there is no batch API. Past roughly 30–50 simultaneously re-pathing agents you are managing a queue, not calling a function.
- **For frequent re-paths.** Chasing a moving player at 2 Hz per agent is the standard pattern and it is already the ceiling.
- **For long routes.** The 20,000-node budget bites long before 3,000 studs in open worlds.

**Where it is too dumb:**

- No steering, no local avoidance, no agent-vs-agent awareness. Two NPCs pathing through the same doorway will fight. The navmesh is static with respect to other agents.
- No dynamic obstacles except via the coarse `Blocked` signal.
- No path *quality* control beyond costs — no preference for cover, no "stay near walls", no flanking routes. You cannot ask for the *second*-best path.
- No partial paths. `NoPath` gives you nothing, where a partial path toward the goal is almost always better than standing still.
- No multi-agent coordination, no formations, no flow.

**The architecture that actually ships**, and the one this chapter recommends:

> Use `PathfindingService` for **coarse, infrequent, long-range route planning** — "which way is the player, roughly" — at ≤2 Hz per agent through a global budget queue. Use **steering behaviours** (§3) at full frame rate for everything local: following the corridor between waypoints, avoiding other agents, avoiding the immediate obstacle, arriving smoothly. When 200+ agents share one goal, throw the navmesh away for them entirely and use a **flow field** (§2.4).

### 1.10 A production path-request budget queue

```lua
--!strict
-- PathBudget.lua — one global queue for all ComputeAsync calls.
-- Because ComputeAsync yields and is Unsafe, this is the only place it should be called.

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local PathBudget = {}

local MAX_COMPUTES_PER_FRAME = 2      -- tune by profiling; 2 is safe on a busy server
local MAX_QUEUE = 256                 -- drop the oldest beyond this

type Request = {
    path: Path,
    from: Vector3,
    to: Vector3,
    priority: number,                 -- higher = sooner
    enqueuedAt: number,
    resolve: (ok: boolean, waypoints: { PathWaypoint }?, status: Enum.PathStatus) -> (),
}

local queue: { Request } = {}
local running = false

-- Insertion into a priority-ordered array. Fine at these sizes; if your queue
-- routinely exceeds a few hundred, swap in the binary heap from section 2.1.
local function enqueue(req: Request)
    if #queue >= MAX_QUEUE then
        table.remove(queue, #queue)   -- drop lowest priority
    end
    local lo, hi = 1, #queue
    while lo <= hi do
        local mid = (lo + hi) // 2
        if queue[mid].priority >= req.priority then lo = mid + 1 else hi = mid - 1 end
    end
    table.insert(queue, lo, req)
end

--- Request a path. `path` must be a Path you own and reuse (one per agent).
function PathBudget.request(
    path: Path, from: Vector3, to: Vector3, priority: number,
    resolve: (boolean, { PathWaypoint }?, Enum.PathStatus) -> ()
)
    enqueue({
        path = path, from = from, to = to,
        priority = priority, enqueuedAt = os.clock(), resolve = resolve,
    })
end

local function pump()
    if running then return end
    running = true
    task.spawn(function()
        while true do
            for _ = 1, MAX_COMPUTES_PER_FRAME do
                local req = table.remove(queue, 1)
                if not req then break end
                local t0 = os.clock()
                local ok = pcall(function()
                    req.path:ComputeAsync(req.from, req.to)
                end)
                local status = req.path.Status
                local elapsed = os.clock() - t0
                if elapsed > 0.010 then
                    warn(("[PathBudget] slow ComputeAsync: %.1f ms, %d studs, status=%s")
                        :format(elapsed * 1000, (req.to - req.from).Magnitude, tostring(status)))
                end
                if ok and status == Enum.PathStatus.Success then
                    req.resolve(true, req.path:GetWaypoints(), status)
                else
                    req.resolve(false, nil, status)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

pump()
return PathBudget
```

Priority suggestions that work in practice: `1000` for an NPC currently in combat with a player, `500` for an NPC that just lost line of sight, `100` for routine patrol, `10` for ambient wandering. Agents whose requests time out in the queue should fall back to "steer straight at the goal and let obstacle avoidance sort it out" — a bad path now beats a good path in 800 ms.

---

## 2. Rolling your own pathfinding

You write your own when: your world is a grid or graph you already own (tile games, tower defence, hex strategy, base builders); you need hundreds of agents to the same goal; you need path *quality* control the navmesh can't give (cover, flanking, stealth routes); or you need paths computed off the main thread, which `ComputeAsync` structurally cannot do.

Everything in this section is `thread_safety`-neutral pure Luau — it runs fine inside an `Actor` parallel phase.

### 2.1 A* with a real binary heap

**The single most common performance bug in Roblox A* implementations** is an open set implemented as an array that gets `table.sort`ed (or linearly scanned for the minimum) every iteration. That is O(n log n) or O(n) *per node expansion*, turning an O(E log V) algorithm into O(V²log V). On a 100×100 grid the difference is roughly two orders of magnitude.

A binary min-heap gives O(log n) push and pop. Here is a complete, correct one with decrease-key support (needed when you find a cheaper route to a node already in the open set):

```lua
--!strict
--!native
-- BinaryHeap.lua — indexed min-heap with decrease-key.

local BinaryHeap = {}
BinaryHeap.__index = BinaryHeap

export type Heap<T> = {
    items: { T },
    priorities: { number },
    index: { [T]: number },   -- item -> position, for decrease-key
    size: number,
}

function BinaryHeap.new<T>(): Heap<T>
    return setmetatable({ items = {}, priorities = {}, index = {}, size = 0 }, BinaryHeap) :: any
end

local function swap(h, a: number, b: number)
    h.items[a], h.items[b] = h.items[b], h.items[a]
    h.priorities[a], h.priorities[b] = h.priorities[b], h.priorities[a]
    h.index[h.items[a]] = a
    h.index[h.items[b]] = b
end

local function siftUp(h, i: number)
    while i > 1 do
        local parent = i // 2
        if h.priorities[i] < h.priorities[parent] then
            swap(h, i, parent); i = parent
        else
            break
        end
    end
end

local function siftDown(h, i: number)
    while true do
        local l, r = i * 2, i * 2 + 1
        local smallest = i
        if l <= h.size and h.priorities[l] < h.priorities[smallest] then smallest = l end
        if r <= h.size and h.priorities[r] < h.priorities[smallest] then smallest = r end
        if smallest == i then break end
        swap(h, i, smallest); i = smallest
    end
end

function BinaryHeap:push<T>(item: T, priority: number)
    local existing = self.index[item]
    if existing then
        -- decrease-key (or increase, though A* only ever decreases)
        local old = self.priorities[existing]
        self.priorities[existing] = priority
        if priority < old then siftUp(self, existing) else siftDown(self, existing) end
        return
    end
    self.size += 1
    self.items[self.size] = item
    self.priorities[self.size] = priority
    self.index[item] = self.size
    siftUp(self, self.size)
end

function BinaryHeap:pop<T>(): (T?, number?)
    if self.size == 0 then return nil, nil end
    local item, priority = self.items[1], self.priorities[1]
    self.index[item] = nil
    if self.size > 1 then
        self.items[1] = self.items[self.size]
        self.priorities[1] = self.priorities[self.size]
        self.index[self.items[1]] = 1
    end
    self.items[self.size] = nil
    self.priorities[self.size] = nil
    self.size -= 1
    if self.size > 1 then siftDown(self, 1) end
    return item, priority
end

function BinaryHeap:contains<T>(item: T): boolean
    return self.index[item] ~= nil
end

function BinaryHeap:isEmpty(): boolean
    return self.size == 0
end

return BinaryHeap
```

And A* on a 2D grid, written to be honest about the details people get wrong:

```lua
--!strict
--!native
-- AStar.lua

local BinaryHeap = require(script.Parent.BinaryHeap)

local AStar = {}

-- 8-way neighbours; the diagonal cost of sqrt(2) matters for path quality.
local NEIGHBOURS = {
    { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
    { 1, 1, 1.41421356 }, { 1, -1, 1.41421356 },
    { -1, 1, 1.41421356 }, { -1, -1, 1.41421356 },
}

-- Octile distance: the ADMISSIBLE heuristic for 8-way movement with sqrt(2)
-- diagonals. Using Euclidean here under-estimates and wastes expansions;
-- using Manhattan OVER-estimates and breaks optimality.
local SQRT2 = 1.41421356
local function octileDistance(ax: number, ay: number, bx: number, by: number): number
    local dx, dy = math.abs(ax - bx), math.abs(ay - by)
    local lo, hi = math.min(dx, dy), math.max(dx, dy)
    return SQRT2 * lo + (hi - lo)
end

-- Pack (x, y) into one integer key. Fast table keys, no allocation.
-- Works for grids up to 65535 wide.
local function key(x: number, y: number): number
    return x * 65536 + y
end
local function unkey(k: number): (number, number)
    return k // 65536, k % 65536
end

export type GridWorld = {
    width: number,
    height: number,
    -- cost of ENTERING (x, y); math.huge = impassable
    costAt: (x: number, y: number) -> number,
}

--- Returns an array of {x, y} from start to goal inclusive, or nil.
--- `maxExpansions` bounds the work; return nil if exceeded (caller should
--- fall back to steering toward the goal).
function AStar.find(
    world: GridWorld,
    sx: number, sy: number, gx: number, gy: number,
    maxExpansions: number?
): ({ { number } })?
    local limit = maxExpansions or 20000
    local goalKey = key(gx, gy)

    local open = BinaryHeap.new()
    local gScore: { [number]: number } = { [key(sx, sy)] = 0 }
    local cameFrom: { [number]: number } = {}
    local closed: { [number]: boolean } = {}

    open:push(key(sx, sy), octileDistance(sx, sy, gx, gy))

    local expansions = 0
    while not open:isEmpty() do
        local current = open:pop() :: number
        if current == goalKey then
            -- Reconstruct.
            local out = {}
            local node = current
            while node do
                local x, y = unkey(node)
                table.insert(out, 1, { x, y })
                node = cameFrom[node]
            end
            return out
        end
        if not closed[current] then
            closed[current] = true
            expansions += 1
            if expansions > limit then return nil end

            local cx, cy = unkey(current)
            local cg = gScore[current]

            for _, n in NEIGHBOURS do
                local nx, ny = cx + n[1], cy + n[2]
                if nx >= 1 and ny >= 1 and nx <= world.width and ny <= world.height then
                    local nk = key(nx, ny)
                    if not closed[nk] then
                        local enterCost = world.costAt(nx, ny)
                        if enterCost < math.huge then
                            -- Prevent corner-cutting through diagonal wall gaps.
                            local passable = true
                            if n[1] ~= 0 and n[2] ~= 0 then
                                if world.costAt(cx + n[1], cy) == math.huge
                                   or world.costAt(cx, cy + n[2]) == math.huge then
                                    passable = false
                                end
                            end
                            if passable then
                                local tentative = cg + n[3] * enterCost
                                local existing = gScore[nk]
                                if existing == nil or tentative < existing then
                                    gScore[nk] = tentative
                                    cameFrom[nk] = current
                                    open:push(nk, tentative + octileDistance(nx, ny, gx, gy))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

return AStar
```

Things worth knowing about this implementation:

- **Integer keys, not `Vector2` or `{x=,y=}` tables.** Table keys that are numbers hit Luau's array/hash fast path; allocating a table per node visit is the second most common A* performance bug after the open-set sort.
- **Corner-cutting check.** Without it, agents slice diagonally through the gap between two wall corners and clip geometry. Every grid A* needs this.
- **`maxExpansions`.** Never let a search run unbounded on the main thread. 20,000 is the same order as Roblox's own navmesh node budget, which is a reasonable reference point.
- **`--!native`.** Native codegen helps hot numeric loops substantially; cross-reference chapter 22 for the caveats (native codegen has a compile cost and does not help table-heavy code as much).
- **Tie-breaking.** For nicer-looking paths on open grids, multiply the heuristic by `(1 + 1/1000)`. This makes A* slightly inadmissible but strongly prefers straight lines toward the goal and cuts expansions on ties. Use it for cosmetic paths, not for anything where optimality is a game rule.

### 2.2 Dijkstra for multi-target and "nearest of many"

Dijkstra is A* with `h = 0`. That sounds like a downgrade, and for single-source-single-target it is. But two cases make it the right tool:

**Nearest-of-many.** "Which of these 12 health packs is closest by *travel* distance, not by straight line?" Seed the open set with the agent's position and stop at the first goal popped. One search, not twelve.

**Many-to-one (the reverse Dijkstra).** Seed with *all* the goals at cost 0 and run to exhaustion. Every node now carries its distance-to-nearest-goal and a parent pointer toward it. This is the foundation of flow fields (§2.4), and it is the correct answer for "50 zombies, one player" — **one** search serves every agent.

```lua
--!strict
--!native
-- Dijkstra.lua

local BinaryHeap = require(script.Parent.BinaryHeap)
local Dijkstra = {}

--- Multi-source Dijkstra over the whole grid.
--- Returns dist[key] and next[key] (the neighbour key to step toward, i.e. a
--- ready-made "follow me home" field).
function Dijkstra.fromSources(world, sources: { { number } })
    local open = BinaryHeap.new()
    local dist: { [number]: number } = {}
    local nextStep: { [number]: number } = {}

    local function key(x, y) return x * 65536 + y end

    for _, s in sources do
        local k = key(s[1], s[2])
        dist[k] = 0
        open:push(k, 0)
    end

    local NEIGHBOURS = {
        { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
        { 1, 1, 1.41421356 }, { 1, -1, 1.41421356 },
        { -1, 1, 1.41421356 }, { -1, -1, 1.41421356 },
    }

    while not open:isEmpty() do
        local current, d = open:pop()
        if d == dist[current] then          -- skip stale heap entries
            local cx, cy = current // 65536, current % 65536
            for _, n in NEIGHBOURS do
                local nx, ny = cx + n[1], cy + n[2]
                if nx >= 1 and ny >= 1 and nx <= world.width and ny <= world.height then
                    local c = world.costAt(nx, ny)
                    if c < math.huge then
                        local nk = key(nx, ny)
                        local nd = d + n[3] * c
                        if dist[nk] == nil or nd < dist[nk] then
                            dist[nk] = nd
                            nextStep[nk] = current   -- step TOWARD the source
                            open:push(nk, nd)
                        end
                    end
                end
            end
        end
    end
    return dist, nextStep
end

return Dijkstra
```

Cost: one full-grid Dijkstra on a 128×128 grid is ~16k node expansions. In Luau with a proper heap that is a few milliseconds; amortized across 200 agents that are all heading to the same place, it is essentially free per agent. Compare against 200 × `ComputeAsync`.

### 2.3 Jump Point Search

JPS (Harabor & Grastien, AAAI 2011) is an optimality-preserving optimization of A* for **uniform-cost grids**. It exploits the fact that on a uniform grid, many optimal paths are symmetric permutations of each other, so most intermediate nodes need never be expanded. Instead of expanding every neighbour, JPS "jumps" along a direction until it finds a **jump point**: the goal, or a node with a *forced neighbour* (a node that's only reachable optimally through this node because an obstacle blocks the straight alternative). Reported speedups are typically **an order of magnitude**, sometimes far more on open maps, with identical optimal paths. **[lit — not re-verified 2026-09; Harabor & Grastien, "Online Graph Pruning for Pathfinding on Grid Maps", AAAI 2011]**

**The preconditions matter, and they disqualify JPS for many Roblox games:**

- The grid must be **uniform cost**. JPS does not work with varying terrain costs. (JPS+ and weighted variants exist but are considerably more complex.)
- The grid must be **static** during the search, and JPS+ pre-computation assumes a static map entirely.
- It is 8-connected grid only — no arbitrary graphs, no navmeshes, no hex (there is a hex variant, but it's research-grade).

So: JPS is superb for a tile-based game with binary walkable/blocked terrain and a large open map. It is the wrong tool the moment you have mud that costs 3× to cross.

Sketch of the core (the `jump` recursion is the whole algorithm):

```lua
--!strict
--!native
-- The jump function: travel in direction (dx, dy) from (x, y) until we find a
-- jump point, hit a wall, or leave the grid. Returns the jump point or nil.
local function jump(world, x: number, y: number, dx: number, dy: number, gx: number, gy: number)
    local nx, ny = x + dx, y + dy
    if not world.walkable(nx, ny) then return nil end
    if nx == gx and ny == gy then return nx, ny end

    if dx ~= 0 and dy ~= 0 then
        -- Diagonal: forced neighbour if a straight blocker sits beside us.
        if (world.walkable(nx - dx, ny + dy) and not world.walkable(nx - dx, ny))
           or (world.walkable(nx + dx, ny - dy) and not world.walkable(nx, ny - dy)) then
            return nx, ny
        end
        -- Diagonal moves must first check both straight components.
        if jump(world, nx, ny, dx, 0, gx, gy) or jump(world, nx, ny, 0, dy, gx, gy) then
            return nx, ny
        end
    elseif dx ~= 0 then
        -- Horizontal: forced neighbour above or below.
        if (world.walkable(nx, y + 1) and not world.walkable(x, y + 1))
           or (world.walkable(nx, y - 1) and not world.walkable(x, y - 1)) then
            return nx, ny
        end
    else
        -- Vertical: forced neighbour left or right.
        if (world.walkable(x + 1, ny) and not world.walkable(x + 1, y))
           or (world.walkable(x - 1, ny) and not world.walkable(x - 1, y)) then
            return nx, ny
        end
    end
    return jump(world, nx, ny, dx, dy, gx, gy)   -- keep going
end
```

The outer loop is ordinary A*, except successors come from `jump()` along the pruned direction set rather than from the 8 neighbours, and `g` costs use the actual distance to the jump point. Recursion depth can reach grid width — convert to an iterative loop for the straight cases if your grid is large.

### 2.4 Flow fields — the right answer for crowds

**When 50+ agents share one goal, computing 50 paths is the wrong shape of computation entirely.** A flow field (a.k.a. vector field pathfinding) inverts it: compute the field **once**, and every agent's per-frame "where do I go" becomes a single array lookup plus a lerp. This is how RTS games move 500 units, and it is the technique behind Supreme Commander 2's crowd movement. **[lit — not re-verified 2026-09; Elijah Emerson, "Crowd Pathfinding and Steering Using Flow Field Tiles", *Game AI Pro* (2013)]**

The algorithm has three stages:

1. **Cost field** — per-cell traversal cost (1 for open, higher for rough terrain, 255/∞ for walls).
2. **Integration field** — a multi-source Dijkstra from the goal cell(s) outward, producing "total cost to reach goal from here". Because all edge costs are positive and you only need the *scalar* field, this is the same Dijkstra as §2.2. On uniform-cost grids you can use a BFS with a simple FIFO queue, which is dramatically faster.
3. **Flow field** — per cell, the unit vector toward the lowest-integration neighbour. Precompute once; agents read it.

```lua
--!strict
--!native
-- FlowField.lua — build once per goal change, read by every agent every frame.

local FlowField = {}
FlowField.__index = FlowField

local UNREACHABLE = math.huge

export type Field = {
    width: number, height: number, cellSize: number, origin: Vector3,
    cost: { number },          -- [i] = cost to ENTER cell i; math.huge = wall
    integration: { number },   -- [i] = accumulated cost to reach goal
    flowX: { number },         -- [i] = unit x
    flowZ: { number },         -- [i] = unit z
}

local function idx(f, x: number, z: number): number
    return (z - 1) * f.width + x
end

function FlowField.new(width: number, height: number, cellSize: number, origin: Vector3)
    local f = setmetatable({
        width = width, height = height, cellSize = cellSize, origin = origin,
        cost = table.create(width * height, 1),
        integration = table.create(width * height, UNREACHABLE),
        flowX = table.create(width * height, 0),
        flowZ = table.create(width * height, 0),
    }, FlowField)
    return f
end

--- Stage 2: integration field. Multi-source Dijkstra with a bucket queue.
--- With uniform costs this degenerates to BFS and runs in O(cells).
function FlowField:integrate(goals: { { number } })
    local n = self.width * self.height
    local integration = self.integration
    table.move(table.create(n, UNREACHABLE), 1, n, 1, integration)

    -- Simple FIFO wavefront. For non-uniform costs, swap for the binary heap.
    local queue = table.create(n)
    local head, tail = 1, 0
    for _, g in goals do
        local i = idx(self, g[1], g[2])
        if self.cost[i] < UNREACHABLE then
            integration[i] = 0
            tail += 1; queue[tail] = i
        end
    end

    local W, H = self.width, self.height
    while head <= tail do
        local i = queue[head]; head += 1
        local base = integration[i]
        local z = (i - 1) // W + 1
        local x = i - (z - 1) * W

        for dz = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dz ~= 0 then
                    local nx, nz = x + dx, z + dz
                    if nx >= 1 and nz >= 1 and nx <= W and nz <= H then
                        local ni = idx(self, nx, nz)
                        local c = self.cost[ni]
                        if c < UNREACHABLE then
                            local step = (dx ~= 0 and dz ~= 0) and 1.41421356 or 1
                            local nd = base + step * c
                            if nd < integration[ni] then
                                integration[ni] = nd
                                tail += 1; queue[tail] = ni
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Stage 3: gradient. Point each cell at its cheapest neighbour.
function FlowField:computeFlow()
    local W, H = self.width, self.height
    local integration = self.integration
    for z = 1, H do
        for x = 1, W do
            local i = idx(self, x, z)
            if integration[i] == UNREACHABLE then
                self.flowX[i], self.flowZ[i] = 0, 0
            else
                local best, bx, bz = integration[i], 0, 0
                for dz = -1, 1 do
                    for dx = -1, 1 do
                        if dx ~= 0 or dz ~= 0 then
                            local nx, nz = x + dx, z + dz
                            if nx >= 1 and nz >= 1 and nx <= W and nz <= H then
                                local v = integration[idx(self, nx, nz)]
                                if v < best then best, bx, bz = v, dx, dz end
                            end
                        end
                    end
                end
                local len = math.sqrt(bx * bx + bz * bz)
                if len > 0 then
                    self.flowX[i], self.flowZ[i] = bx / len, bz / len
                else
                    self.flowX[i], self.flowZ[i] = 0, 0
                end
            end
        end
    end
end

--- Per-agent read: BILINEAR sample so agents don't snap between cells.
--- This is the difference between "crowd flows" and "crowd stutters on grid lines".
function FlowField:sample(worldPos: Vector3): Vector3
    local local_ = worldPos - self.origin
    local fx = local_.X / self.cellSize + 0.5
    local fz = local_.Z / self.cellSize + 0.5
    local x0 = math.clamp(math.floor(fx), 1, self.width - 1)
    local z0 = math.clamp(math.floor(fz), 1, self.height - 1)
    local tx, tz = math.clamp(fx - x0, 0, 1), math.clamp(fz - z0, 0, 1)

    local i00 = idx(self, x0, z0)
    local i10 = idx(self, x0 + 1, z0)
    local i01 = idx(self, x0, z0 + 1)
    local i11 = idx(self, x0 + 1, z0 + 1)

    local vx = (self.flowX[i00] * (1 - tx) + self.flowX[i10] * tx) * (1 - tz)
             + (self.flowX[i01] * (1 - tx) + self.flowX[i11] * tx) * tz
    local vz = (self.flowZ[i00] * (1 - tx) + self.flowZ[i10] * tx) * (1 - tz)
             + (self.flowZ[i01] * (1 - tx) + self.flowZ[i11] * tx) * tz

    local v = Vector3.new(vx, 0, vz)
    return v.Magnitude > 1e-4 and v.Unit or Vector3.zero
end

function FlowField:rebuild(goals: { { number } })
    self:integrate(goals)
    self:computeFlow()
end

return FlowField
```

**Why this wins so decisively.** Per-agent per-frame cost is one bilinear sample: ~12 table reads and ~20 arithmetic ops, no allocation, no yield, no Instance access. It parallelizes trivially (pure Luau, `Safe`). Rebuild cost is O(cells) and is paid **once per goal change**, not once per agent. A 256×256 field is 65,536 cells; the integration pass is a few milliseconds in native Luau. Rebuild it at 2–5 Hz when the goal moves and you have a 1,000-agent crowd for a fraction of the cost of *ten* `ComputeAsync` calls.

**When to use it:** tower defence (creeps → exit), zombie waves (all → nearest player), RTS move orders (one field per order group), stampedes, herding, evacuation, any "everything goes there" scenario.

**When not to:** when each agent has a genuinely different destination. Then you need per-agent paths — or you bucket agents into a small number of destination groups and build one field per group. Three fields for 300 agents is still a massive win.

**Multi-goal is free.** Seed the integration with *every* player's cell and every agent automatically routes to its nearest player by travel distance. That is a feature you would otherwise have to build.

**Hierarchical flow fields** (the *Game AI Pro* technique) tile the world into e.g. 32×32 sectors, compute a coarse sector-level field, and only compute fine fields for sectors containing agents. This is what makes flow fields viable on very large maps.

### 2.5 Hierarchical pathfinding (HPA*)

For large maps, the fix is to not search the whole map. HPA* (Botea, Müller & Schaeffer, 2004) partitions the grid into clusters, identifies **entrances** (contiguous walkable borders between adjacent clusters), places **transition nodes** at entrances, precomputes intra-cluster costs between a cluster's own transition nodes, and searches the resulting abstract graph — which is orders of magnitude smaller. The concrete path is then refined cluster-by-cluster, lazily, as the agent arrives. **[lit — not re-verified 2026-09; Botea et al., "Near Optimal Hierarchical Path-Finding", *JGDV* 2004]**

Structure:

```
Level 0: the raw grid (e.g. 1024 × 1024 = 1M cells)
Level 1: 16 × 16 clusters of 64 × 64 cells, with transition nodes at entrances
         → abstract graph of maybe 2,000 nodes
Search:  A* on the abstract graph (fast), then refine only the first 1–2
         clusters of the concrete path; refine the rest as the agent arrives.
```

The trade: paths are *near*-optimal (typically within a few percent), and you pay a precomputation cost plus incremental repair when terrain changes. For a map big enough to need it, that trade is always worth taking. For a map that fits in a 128×128 grid, HPA* is over-engineering — use plain A*.

**Roblox-specific note:** `PathfindingService` almost certainly does something structurally similar internally, which is one reason its 20,000-node budget is expressed in nodes rather than studs. If you find yourself building HPA* over the navmesh, you're rebuilding the engine — build it over your own grid instead.

### 2.6 Path smoothing and the funnel algorithm

Raw grid A* produces staircase paths that look terrible and are longer than necessary. Two fixes, in increasing quality:

**String-pulling by line-of-sight (cheap, good enough for grids).** Walk the path; from the current anchor, find the furthest waypoint with clear line of sight; discard everything between.

```lua
--!strict
-- Greedy string pull. O(n²) worst case but n is small after A*.
local function smoothPath(points: { Vector3 }, agentRadius: number): { Vector3 }
    if #points <= 2 then return points end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { workspace.NPCs }
    params.RespectCanCollide = true

    local function clear(a: Vector3, b: Vector3): boolean
        -- Cast three parallel rays (centre + both shoulders) so the agent's
        -- radius is respected; a single centre ray lets agents clip corners.
        local dir = b - a
        local flat = Vector3.new(dir.X, 0, dir.Z)
        if flat.Magnitude < 1e-3 then return true end
        local side = Vector3.new(-flat.Z, 0, flat.X).Unit * agentRadius
        for _, offset in { Vector3.zero, side, -side } do
            if workspace:Raycast(a + offset, dir, params) then return false end
        end
        return true
    end

    local out = { points[1] }
    local anchor = 1
    while anchor < #points do
        local furthest = anchor + 1
        for j = #points, anchor + 2, -1 do
            if clear(points[anchor], points[j]) then furthest = j; break end
        end
        table.insert(out, points[furthest])
        anchor = furthest
    end
    return out
end
```

**The simple stupid funnel algorithm (correct, for navmesh-style corridors).** When your path is a sequence of *portals* (shared edges between adjacent polygons/cells) rather than points, the funnel algorithm produces the **exact shortest path** through the corridor in O(n). Maintain an apex plus left and right funnel vectors; for each portal, tighten the funnel; when a new side crosses the opposite side, the opposite endpoint becomes the new apex and you emit a corner. **[lit — not re-verified 2026-09; Mikko Mononen, "Simple Stupid Funnel Algorithm" (2010); the standard implementation ships in Recast/Detour]**

```lua
--!strict
-- 2D cross product of (b-a) × (c-a); sign tells us which side c is on.
local function triarea2(a: Vector2, b: Vector2, c: Vector2): number
    return (b.X - a.X) * (c.Y - a.Y) - (c.X - a.X) * (b.Y - a.Y)
end

--- portals: array of { left: Vector2, right: Vector2 }, from start to goal.
--- The first and last portals should be degenerate (left == right == the point).
local function funnel(portals: { { left: Vector2, right: Vector2 } }): { Vector2 }
    local out = {}
    local apex = portals[1].left
    local portalLeft, portalRight = portals[1].left, portals[1].right
    local apexIndex, leftIndex, rightIndex = 1, 1, 1
    table.insert(out, apex)

    local i = 2
    while i <= #portals do
        local left, right = portals[i].left, portals[i].right

        -- Tighten the RIGHT side.
        if triarea2(apex, portalRight, right) <= 0 then
            if apex == portalRight or triarea2(apex, portalLeft, right) > 0 then
                portalRight, rightIndex = right, i          -- narrowed
            else
                -- Right crossed left: left endpoint becomes the new apex.
                table.insert(out, portalLeft)
                apex = portalLeft
                apexIndex = leftIndex
                portalLeft, portalRight = apex, apex
                leftIndex, rightIndex = apexIndex, apexIndex
                i = apexIndex + 1
                continue
            end
        end

        -- Tighten the LEFT side.
        if triarea2(apex, portalLeft, left) >= 0 then
            if apex == portalLeft or triarea2(apex, portalRight, left) < 0 then
                portalLeft, leftIndex = left, i
            else
                table.insert(out, portalRight)
                apex = portalRight
                apexIndex = rightIndex
                portalLeft, portalRight = apex, apex
                leftIndex, rightIndex = apexIndex, apexIndex
                i = apexIndex + 1
                continue
            end
        end
        i += 1
    end
    table.insert(out, portals[#portals].left)
    return out
end
```

**On Roblox specifically:** `WaypointSpacing = math.huge` already gives you corner-only waypoints from the engine's own smoothing, so funnel is only relevant for *your own* pathfinder. But `smoothPath` above is still worth running over `ComputeAsync` output when you want to shorten conservative navmesh detours — three raycasts per test is cheap and the visual improvement is large.

---

## 3. Steering and local movement

Craig Reynolds' framework (GDC 1999) decomposes autonomous movement into three layers: **action selection** (where do I want to go — §4), **steering** (produce a desired force), and **locomotion** (turn force into animation). Steering behaviours each return a *desired velocity*; the steering force is `desired - currentVelocity`, truncated to a max force. **[lit — not re-verified 2026-09; Craig W. Reynolds, "Steering Behaviors For Autonomous Characters", GDC 1999, red3d.com/cwr/steer/gdc99/]**

### 3.1 The formulas

Given agent position `P`, velocity `V`, `maxSpeed`, `maxForce`:

| Behaviour | Desired velocity | Notes |
|---|---|---|
| **Seek(T)** | `(T − P).Unit * maxSpeed` | Overshoots the target and orbits. Never use alone for a destination. |
| **Flee(T)** | `(P − T).Unit * maxSpeed` | Optionally zero outside a panic radius. |
| **Arrive(T, r)** | `(T − P).Unit * maxSpeed * min(1, d/r)` where `d = ‖T − P‖` | The fix for Seek's overshoot. `r` = slowing radius. |
| **Pursue(Q)** | `Seek(Q.P + Q.V * τ)`, `τ = ‖Q.P − P‖ / maxSpeed` | Lead the target. Cap `τ` or the agent aims at the horizon. |
| **Evade(Q)** | `Flee(Q.P + Q.V * τ)`, same `τ` | |
| **Wander** | Project a circle `d` ahead of radius `r`; jitter a point on it by `j` each tick; seek it | Jitter the *angle*, not the point, to keep it on the circle. |
| **ObstacleAvoid** | Cast ahead by `lookahead = ‖V‖ * t`; if blocked, steer along the surface normal, scaled by `1 − hitDistance/lookahead` | Roblox: use `Spherecast` with the agent radius, not `Raycast`. |
| **Separation** | `Σ (P − Nᵢ) / ‖P − Nᵢ‖²` over neighbours within `rₛ`, normalized | Inverse-square is the key — near neighbours dominate. |
| **Cohesion** | `Seek(mean(Nᵢ.P))` | |
| **Alignment** | `mean(Nᵢ.V)` normalized × maxSpeed | |

Boids = separation + cohesion + alignment, classically weighted roughly 1.5 : 1.0 : 1.0 with separation dominant. Reynolds' original flocking used exactly these three. **[lit]**

### 3.2 A complete steering module

```lua
--!strict
--!native
-- Steering.lua — pure functions. No Instances, no yields: Actor-safe.

local Steering = {}

export type Agent = {
    position: Vector3,
    velocity: Vector3,
    maxSpeed: number,
    maxForce: number,
}

local function truncate(v: Vector3, maxLen: number): Vector3
    local m = v.Magnitude
    if m > maxLen and m > 0 then return v * (maxLen / m) end
    return v
end

local function flat(v: Vector3): Vector3
    return Vector3.new(v.X, 0, v.Z)
end

function Steering.seek(a: Agent, target: Vector3): Vector3
    local d = flat(target - a.position)
    if d.Magnitude < 1e-4 then return Vector3.zero end
    return truncate(d.Unit * a.maxSpeed - a.velocity, a.maxForce)
end

function Steering.flee(a: Agent, threat: Vector3, panicRadius: number?): Vector3
    local d = flat(a.position - threat)
    local dist = d.Magnitude
    if dist < 1e-4 then return Vector3.zero end
    if panicRadius and dist > panicRadius then return Vector3.zero end
    return truncate(d.Unit * a.maxSpeed - a.velocity, a.maxForce)
end

function Steering.arrive(a: Agent, target: Vector3, slowRadius: number, stopRadius: number?): Vector3
    local d = flat(target - a.position)
    local dist = d.Magnitude
    local stop = stopRadius or 1
    if dist < stop then
        return truncate(-a.velocity, a.maxForce)   -- actively brake
    end
    local speed = a.maxSpeed * math.min(1, (dist - stop) / math.max(slowRadius, 1e-3))
    return truncate(d.Unit * speed - a.velocity, a.maxForce)
end

function Steering.pursue(a: Agent, targetPos: Vector3, targetVel: Vector3, maxLead: number?): Vector3
    local toTarget = flat(targetPos - a.position)
    local tau = math.min(toTarget.Magnitude / math.max(a.maxSpeed, 1e-3), maxLead or 2)
    return Steering.seek(a, targetPos + targetVel * tau)
end

function Steering.evade(a: Agent, threatPos: Vector3, threatVel: Vector3, maxLead: number?): Vector3
    local toThreat = flat(threatPos - a.position)
    local tau = math.min(toThreat.Magnitude / math.max(a.maxSpeed, 1e-3), maxLead or 2)
    return Steering.flee(a, threatPos + threatVel * tau)
end

-- Wander keeps state: the current angle on the projection circle.
export type WanderState = { angle: number }

function Steering.wander(
    a: Agent, state: WanderState, dt: number,
    distance: number, radius: number, jitterRate: number
): Vector3
    -- Jitter the ANGLE (bounded), not the point (unbounded random walk).
    state.angle += (math.random() * 2 - 1) * jitterRate * dt
    local heading = a.velocity.Magnitude > 0.1 and flat(a.velocity).Unit or Vector3.xAxis
    local centre = a.position + heading * distance
    local offset = Vector3.new(math.cos(state.angle), 0, math.sin(state.angle)) * radius
    return Steering.seek(a, centre + offset)
end

--- Obstacle avoidance via spherecast. `params` should be a cached OverlapParams-
--- style RaycastParams; building one per call allocates.
function Steering.avoidObstacles(
    a: Agent, agentRadius: number, lookaheadTime: number, params: RaycastParams
): Vector3
    local speed = a.velocity.Magnitude
    if speed < 0.1 then return Vector3.zero end
    local dir = flat(a.velocity).Unit
    local lookahead = math.max(speed * lookaheadTime, agentRadius * 2)

    local hit = workspace:Spherecast(a.position, agentRadius, dir * lookahead, params)
    if not hit then return Vector3.zero end

    -- Steer along the surface, away from it. Urgency scales with closeness.
    local n = flat(hit.Normal)
    if n.Magnitude < 1e-3 then n = Vector3.new(-dir.Z, 0, dir.X) end
    local urgency = 1 - (hit.Distance / lookahead)
    local lateral = n.Unit
    return truncate(lateral * a.maxSpeed * urgency - a.velocity * 0, a.maxForce) * 1.5
end

--- Neighbour-based behaviours. `neighbours` comes from the spatial hash (§7.5).
function Steering.separation(a: Agent, neighbours: { Agent }, radius: number): Vector3
    local steer = Vector3.zero
    local count = 0
    for _, other in neighbours do
        local offset = flat(a.position - other.position)
        local d = offset.Magnitude
        if d > 1e-4 and d < radius then
            steer += offset.Unit / d      -- inverse-distance weighting
            count += 1
        end
    end
    if count == 0 then return Vector3.zero end
    steer /= count
    if steer.Magnitude < 1e-4 then return Vector3.zero end
    return truncate(steer.Unit * a.maxSpeed - a.velocity, a.maxForce)
end

function Steering.cohesion(a: Agent, neighbours: { Agent }, radius: number): Vector3
    local centre, count = Vector3.zero, 0
    for _, other in neighbours do
        local d = (other.position - a.position).Magnitude
        if d > 1e-4 and d < radius then centre += other.position; count += 1 end
    end
    if count == 0 then return Vector3.zero end
    return Steering.seek(a, centre / count)
end

function Steering.alignment(a: Agent, neighbours: { Agent }, radius: number): Vector3
    local sum, count = Vector3.zero, 0
    for _, other in neighbours do
        local d = (other.position - a.position).Magnitude
        if d > 1e-4 and d < radius then sum += other.velocity; count += 1 end
    end
    if count == 0 then return Vector3.zero end
    sum = flat(sum / count)
    if sum.Magnitude < 1e-4 then return Vector3.zero end
    return truncate(sum.Unit * a.maxSpeed - a.velocity, a.maxForce)
end

return Steering
```

### 3.3 Combining behaviours: weights, priority, truncation

Three approaches, each with a real failure mode.

**Weighted sum.** `F = Σ wᵢ Fᵢ`, then truncate to `maxForce`. Simple, smooth, and **the cause of most "my AI walks into walls" bugs**: a strong seek can swamp avoidance, and opposing forces can cancel to zero, leaving an agent frozen between two equally attractive options.

**Prioritized truncation (recommended).** Evaluate behaviours in strict priority order, accumulate into a force budget, and stop once the budget is spent. Safety behaviours (avoidance, separation) go first and can consume the whole budget; goal-seeking gets whatever is left. This *guarantees* avoidance is never drowned out.

```lua
--!strict
-- Prioritized truncated accumulation. Returns the final steering force.
local function accumulate(a: Agent, behaviours: { { force: Vector3, weight: number } }): Vector3
    local total = Vector3.zero
    local remaining = a.maxForce
    for _, b in behaviours do
        local f = b.force * b.weight
        local mag = f.Magnitude
        if mag < 1e-5 then continue end
        if mag < remaining then
            total += f
            remaining -= mag
        else
            total += f.Unit * remaining
            break                      -- budget spent; lower priorities ignored
        end
    end
    return total
end

-- Priority order for a melee chaser. Order IS the design.
local force = accumulate(agent, {
    { force = Steering.avoidObstacles(agent, 2, 0.6, rayParams), weight = 2.0 },
    { force = Steering.separation(agent, neighbours, 6),          weight = 1.5 },
    { force = Steering.arrive(agent, nextCorner, 8, 1.5),         weight = 1.0 },
    { force = Steering.wander(agent, wanderState, dt, 6, 3, 4),   weight = 0.2 },
})
```

**Priority dithering.** Reynolds' cheapest option: each behaviour has a probability of being the *only* one evaluated this tick; roll once and use that behaviour alone. O(1) instead of O(behaviours) per agent. Produces slightly jittery motion but is a genuine option at 500+ agents where you cannot afford to evaluate nine behaviours per agent per frame.

### 3.4 Local avoidance: RVO / ORCA

Separation stops agents from overlapping but produces the classic "two agents mirror each other and deadlock in a doorway" failure, because each reacts to where the other *is*, not where it's *going*. **Reciprocal Velocity Obstacles** (van den Berg et al., 2008) and its refinement **ORCA** (Optimal Reciprocal Collision Avoidance, 2011) fix this by having each agent choose a velocity outside the set of velocities that would collide within a time horizon `τ` — and, crucially, assume the other agent takes *half* the responsibility for avoidance. That reciprocity assumption is what eliminates oscillation. **[lit — not re-verified 2026-09; van den Berg, Lin & Manocha, "Reciprocal Velocity Obstacles for Real-Time Multi-Agent Navigation", ICRA 2008; van den Berg et al., ORCA, ISRR 2011; reference implementation: RVO2, gamma.cs.unc.edu/RVO2/]**

Full ORCA is a linear program per agent per frame (solve for the velocity closest to preferred, subject to N half-plane constraints). That is real work, and on Roblox it is usually **not worth it**. The 90% version that is:

```lua
--!strict
-- Poor man's reciprocal avoidance. O(neighbours), no LP.
-- Predicts closest approach; if a collision is imminent, steer perpendicular,
-- with a deterministic tie-break so both agents pick OPPOSITE sides.
local function reciprocalAvoid(
    a: Agent, aId: number, neighbours: { { agent: Agent, id: number } },
    radiusSum: number, horizon: number
): Vector3
    local steer = Vector3.zero
    for _, entry in neighbours do
        local b = entry.agent
        local relP = Vector3.new(b.position.X - a.position.X, 0, b.position.Z - a.position.Z)
        local relV = Vector3.new(a.velocity.X - b.velocity.X, 0, a.velocity.Z - b.velocity.Z)
        local vv = relV:Dot(relV)
        if vv < 1e-6 then continue end

        -- Time of closest approach.
        local t = relP:Dot(relV) / vv
        if t < 0 or t > horizon then continue end

        local closest = relP - relV * t
        local dist = closest.Magnitude
        if dist >= radiusSum then continue end

        -- Perpendicular escape direction; deterministic side by id comparison.
        local side = (aId < entry.id) and 1 or -1
        local perp = Vector3.new(-relV.Z, 0, relV.X).Unit * side
        -- Urgency: closer in time AND space = stronger.
        local urgency = (1 - t / horizon) * (1 - dist / radiusSum)
        steer += perp * a.maxSpeed * urgency * 0.5   -- 0.5 = reciprocity share
    end
    return steer
end
```

The `aId < entry.id` tie-break is the whole trick: it guarantees two agents on a head-on course pick opposite sides instead of mirroring. Without it you get the doorway deadlock.

**When you actually need real ORCA:** dense crowds (>10 agents/100 studs²) that must not interpenetrate, in a game where clipping is visible and harmful. Otherwise: separation + reciprocal perpendicular + letting agents softly overlap at distance (players don't notice) is the better trade.

### 3.5 Making movement look natural

Raw steering output looks robotic. Four cheap fixes, in order of impact:

**1. Turn-rate limiting.** Nothing living snaps its facing. Clamp the yaw change per frame.

```lua
local MAX_TURN_RATE = math.rad(220)   -- deg/s; humans ~180–360, tanks ~45

local function limitTurn(currentLook: Vector3, desiredLook: Vector3, dt: number): Vector3
    local a = Vector3.new(currentLook.X, 0, currentLook.Z)
    local b = Vector3.new(desiredLook.X, 0, desiredLook.Z)
    if a.Magnitude < 1e-4 or b.Magnitude < 1e-4 then return currentLook end
    a, b = a.Unit, b.Unit
    local dot = math.clamp(a:Dot(b), -1, 1)
    local angle = math.acos(dot)
    local maxStep = MAX_TURN_RATE * dt
    if angle <= maxStep then return b end
    -- Rotate a toward b by maxStep around Y.
    local sign = (a.X * b.Z - a.Z * b.X) >= 0 and 1 or -1
    local c, s = math.cos(maxStep * sign), math.sin(maxStep * sign)
    return Vector3.new(a.X * c - a.Z * s, 0, a.X * s + a.Z * c)
end
```

Couple it to speed: an agent turning hard should slow down. `effectiveSpeed = maxSpeed * (0.35 + 0.65 * math.max(0, currentLook:Dot(desiredLook)))` reads as weight and momentum for one line.

**2. Acceleration, not teleportation.** `velocity += (force / mass) * dt`, then clamp to `maxSpeed`. Separate `maxAccel` from `maxDecel` — things stop faster than they start, and a higher decel makes `arrive` crisp without making starts twitchy.

**3. Anticipation.** Begin the turn/slow *before* the corner. Sample the path one waypoint ahead and blend: `aimPoint = lerp(nextWaypoint, waypointAfter, clamp(1 - distToNext / anticipationDist, 0, 1))`. This single change is the difference between "follows a path" and "drives a racing line".

**4. Desynchronized noise.** Give every agent a per-instance random phase and slightly different `maxSpeed` (±8%), turn rate, and wander jitter. Identical agents moving identically is the strongest "these are robots" signal there is, and it costs one `math.random()` at spawn.

---

## 4. Decision architectures

### 4.1 Finite state machines, and hierarchical FSMs

An FSM is a set of states, each with `enter`/`update`/`exit`, plus transitions. It is the right answer more often than the internet admits: it is trivially debuggable (one string tells you everything), has zero per-frame allocation, and every programmer on your team understands it instantly.

Its documented failure mode is **transition explosion**: N states need up to N(N−1) transitions, and adding "flee when low health" means touching every state. Nystrom's *Game Programming Patterns* covers the standard escapes — concurrent state machines (one FSM for movement, one for weapons), pushdown automata (a state stack, so "reload" can return to whatever you were doing), and hierarchical states (a state inherits its parent's transitions). **[lit — not re-verified 2026-09; Robert Nystrom, *Game Programming Patterns*, "State", gameprogrammingpatterns.com/state.html]**

```lua
--!strict
-- FSM.lua — hierarchical, allocation-free per frame.

local FSM = {}
FSM.__index = FSM

export type State = {
    name: string,
    parent: string?,                            -- HFSM: inherit parent transitions
    enter: ((ctx: any) -> ())?,
    update: ((ctx: any, dt: number) -> ())?,
    exit: ((ctx: any) -> ())?,
    -- Transitions are checked in array order: first true wins.
    transitions: { { to: string, when: (ctx: any) -> boolean } },
}

function FSM.new(states: { [string]: State }, initial: string, ctx: any)
    local self = setmetatable({
        states = states, current = initial, ctx = ctx,
        timeInState = 0, history = table.create(16),
    }, FSM)
    local s = states[initial]
    if s and s.enter then s.enter(ctx) end
    return self
end

function FSM:_transitionsFor(name: string)
    -- Walk up the parent chain so child states inherit parent transitions.
    local out = {}
    local s = self.states[name]
    while s do
        for _, t in s.transitions do table.insert(out, t) end
        s = s.parent and self.states[s.parent] or nil
    end
    return out
end

function FSM:changeTo(name: string)
    if name == self.current then return end
    local from = self.states[self.current]
    if from and from.exit then from.exit(self.ctx) end
    table.insert(self.history, { from = self.current, to = name, t = os.clock() })
    if #self.history > 16 then table.remove(self.history, 1) end
    self.current = name
    self.timeInState = 0
    local to = self.states[name]
    if to and to.enter then to.enter(self.ctx) end
end

function FSM:update(dt: number)
    self.timeInState += dt
    for _, t in self:_transitionsFor(self.current) do
        if t.when(self.ctx) then
            self:changeTo(t.to)
            break
        end
    end
    local s = self.states[self.current]
    if s and s.update then s.update(self.ctx, dt) end
end

return FSM
```

The `history` ring buffer is not decoration: it is the debug tool that makes FSM bugs solvable (§9.2).

Use an FSM when: behaviours are genuinely mutually exclusive modes (Idle / Patrol / Chase / Attack / Flee / Dead), and there are ≤10 of them. Stop using one when you find yourself adding boolean flags to states to remember what you were doing.

### 4.2 Behavior trees

A behavior tree is a tree re-evaluated (fully or from a remembered point) each tick; every node returns `Success`, `Failure`, or `Running`. `Running` is the whole point — it's what lets a tree express multi-frame actions without an explicit state machine. **[lit — not re-verified 2026-09; the standard modern treatment is Chris Simpson, "Behavior trees for AI: How they work", Game Developer, 2014; and Isla's Halo 2 behavior-DAG work, GDC 2005]**

**Node taxonomy:**

| Category | Node | Semantics |
|---|---|---|
| Composite | **Sequence** | Tick children in order. First `Failure` → `Failure`. First `Running` → `Running`. All `Success` → `Success`. (Logical AND / "do these in order".) |
| Composite | **Selector** (Fallback) | Tick children in order. First `Success` → `Success`. First `Running` → `Running`. All `Failure` → `Failure`. (Logical OR / "try these until one works".) |
| Composite | **Parallel** | Tick all children each tick. Succeed/fail on a policy (e.g. succeed when M of N succeed; fail on first failure). |
| Composite | **RandomSelector** | Selector with weighted-random child order. Cheap variety. |
| Decorator | **Inverter** | Flip Success ↔ Failure; pass Running. |
| Decorator | **Succeeder / Failer** | Force a result (pass Running). |
| Decorator | **Repeat(n) / RepeatUntilFail** | Loop a child. |
| Decorator | **Cooldown(t)** | `Failure` if the child succeeded less than `t` ago. |
| Decorator | **TimeLimit(t)** | `Failure` if the child stays Running past `t`. |
| Decorator | **Condition / Guard** | Run the child only if a blackboard predicate holds. |
| Leaf | **Action** | Do the thing; may return Running across frames. |
| Leaf | **Condition** | Pure test → Success/Failure. |

**Blackboard**: a shared key-value store per agent (and often a second one per squad). Nodes never talk to each other directly; they read and write the blackboard. This is what keeps subtrees reusable.

```lua
--!strict
-- BehaviorTree.lua — a complete, small, fast BT. No per-tick allocation.

local BT = {}

export type Status = "success" | "failure" | "running"
export type Node = { tick: (self: Node, bb: any, dt: number) -> Status, reset: ((self: Node) -> ())? }

-- ---------- Composites ----------

function BT.Sequence(children: { Node }): Node
    local node = { children = children, index = 1 }
    function node:reset()
        self.index = 1
        for _, c in self.children do if c.reset then c:reset() end end
    end
    function node:tick(bb, dt): Status
        while self.index <= #self.children do
            local status = self.children[self.index]:tick(bb, dt)
            if status == "running" then return "running" end
            if status == "failure" then self:reset(); return "failure" end
            self.index += 1
        end
        self:reset()
        return "success"
    end
    return node :: any
end

function BT.Selector(children: { Node }): Node
    local node = { children = children, index = 1 }
    function node:reset()
        self.index = 1
        for _, c in self.children do if c.reset then c:reset() end end
    end
    function node:tick(bb, dt): Status
        while self.index <= #self.children do
            local status = self.children[self.index]:tick(bb, dt)
            if status == "running" then return "running" end
            if status == "success" then self:reset(); return "success" end
            self.index += 1
        end
        self:reset()
        return "failure"
    end
    return node :: any
end

--- Parallel with an explicit success policy.
function BT.Parallel(children: { Node }, successCount: number, failureCount: number): Node
    local node = { children = children }
    function node:reset() for _, c in self.children do if c.reset then c:reset() end end end
    function node:tick(bb, dt): Status
        local s, f = 0, 0
        for _, c in self.children do
            local r = c:tick(bb, dt)
            if r == "success" then s += 1 elseif r == "failure" then f += 1 end
        end
        if s >= successCount then self:reset(); return "success" end
        if f >= failureCount then self:reset(); return "failure" end
        return "running"
    end
    return node :: any
end

--- Priority Selector that re-evaluates from the top every tick. This is the
--- "reactive" selector — use it at the ROOT so high-priority branches
--- (flee, react to damage) can interrupt a running low-priority branch.
function BT.ReactiveSelector(children: { Node }): Node
    local node = { children = children, running = nil }
    function node:reset()
        self.running = nil
        for _, c in self.children do if c.reset then c:reset() end end
    end
    function node:tick(bb, dt): Status
        for i, c in self.children do
            local status = c:tick(bb, dt)
            if status ~= "failure" then
                -- A higher-priority branch took over: reset the interrupted one.
                if self.running and self.running ~= i then
                    local prev = self.children[self.running]
                    if prev.reset then prev:reset() end
                end
                self.running = (status == "running") and i or nil
                return status
            end
        end
        self.running = nil
        return "failure"
    end
    return node :: any
end

-- ---------- Decorators ----------

function BT.Inverter(child: Node): Node
    local node = { child = child }
    function node:reset() if self.child.reset then self.child:reset() end end
    function node:tick(bb, dt): Status
        local r = self.child:tick(bb, dt)
        if r == "success" then return "failure" elseif r == "failure" then return "success" end
        return "running"
    end
    return node :: any
end

function BT.Cooldown(child: Node, seconds: number): Node
    local node = { child = child, readyAt = 0 }
    function node:reset() if self.child.reset then self.child:reset() end end
    function node:tick(bb, dt): Status
        local now = os.clock()
        if now < self.readyAt then return "failure" end
        local r = self.child:tick(bb, dt)
        if r == "success" then self.readyAt = now + seconds end
        return r
    end
    return node :: any
end

function BT.TimeLimit(child: Node, seconds: number): Node
    local node = { child = child, startedAt = nil }
    function node:reset() self.startedAt = nil; if self.child.reset then self.child:reset() end end
    function node:tick(bb, dt): Status
        self.startedAt = self.startedAt or os.clock()
        if os.clock() - self.startedAt > seconds then self:reset(); return "failure" end
        local r = self.child:tick(bb, dt)
        if r ~= "running" then self:reset() end
        return r
    end
    return node :: any
end

function BT.Guard(predicate: (bb: any) -> boolean, child: Node): Node
    local node = { child = child }
    function node:reset() if self.child.reset then self.child:reset() end end
    function node:tick(bb, dt): Status
        if not predicate(bb) then return "failure" end
        return self.child:tick(bb, dt)
    end
    return node :: any
end

-- ---------- Leaves ----------

function BT.Action(fn: (bb: any, dt: number) -> Status, name: string?): Node
    return { name = name, tick = function(_, bb, dt) return fn(bb, dt) end } :: any
end

function BT.Condition(fn: (bb: any) -> boolean, name: string?): Node
    return {
        name = name,
        tick = function(_, bb) return fn(bb) and "success" or "failure" end,
    } :: any
end

function BT.Wait(seconds: number): Node
    local node = { until_ = nil }
    function node:reset() self.until_ = nil end
    function node:tick(): Status
        self.until_ = self.until_ or (os.clock() + seconds)
        if os.clock() >= self.until_ then self.until_ = nil; return "success" end
        return "running"
    end
    return node :: any
end

return BT
```

A real guard tree, showing the shape that works:

```lua
--!strict
local tree = BT.ReactiveSelector({
    -- Priority 1: survive.
    BT.Guard(function(bb) return bb.health / bb.maxHealth < 0.25 end,
        BT.Sequence({
            BT.Action(function(bb) bb.alertLevel = "panic"; return "success" end),
            BT.Action(fleeToNearestCover, "FleeToCover"),
        })),

    -- Priority 2: fight what we can see.
    BT.Guard(function(bb) return bb.visibleTarget ~= nil end,
        BT.Selector({
            BT.Sequence({
                BT.Condition(function(bb) return bb.distanceToTarget <= bb.attackRange end, "InRange"),
                BT.Cooldown(BT.Action(attack, "Attack"), 1.4),
            }),
            BT.Action(chaseTarget, "Chase"),
        })),

    -- Priority 3: investigate a lost target for 12 s, then give up.
    BT.Guard(function(bb) return bb.lastKnownPosition ~= nil end,
        BT.TimeLimit(BT.Sequence({
            BT.Action(moveToLastKnown, "MoveToLastKnown"),
            BT.Wait(2),
            BT.Action(searchAround, "SearchAround"),
            BT.Action(function(bb) bb.lastKnownPosition = nil; return "success" end),
        }), 12)),

    -- Priority 4: the default.
    BT.Action(patrol, "Patrol"),
})
```

**Roblox-specific BT notes.** Ticking a BT every `Heartbeat` for 200 agents is wasteful — decisions rarely need 60 Hz. Tick at 5–10 Hz via the time-slicing scheduler in §7.4 and keep steering at full rate. Build trees **once per archetype and share the structure**, but note the implementation above keeps per-node state (`index`, `readyAt`) — so either instantiate one tree per agent (a few KB, fine) or refactor node state into the blackboard keyed by node id. Instantiating per agent is simpler and almost always the right call.

### 4.3 Utility AI — the one that feels most alive

Utility AI replaces "which branch is true" with "which action scores highest". Each action has a set of **considerations**; each consideration maps a normalized input to a score in [0,1] through a **response curve**; the action's utility is the (usually compensated) product of its considerations. Pick the max, or sample from the top K for variety. **[lit — not re-verified 2026-09; Dave Mark, *Behavioral Mathematics for Game AI* (2009), and Mark & Dill, "Improving AI Decision Modeling Through Utility Theory", GDC 2010 — the Infinite Axis Utility System]**

**Why it feels better than a BT:** a BT gives you "if X then A else B", which reads as a rule. Utility gives you "A is a bit better than B right now", which reads as a preference — and preferences shift smoothly as the world changes, so the agent looks like it's *weighing* things. It also degrades gracefully: add a new action and it competes without you rewriting any conditionals.

**The formulation.**

```
score(action) = compensate( Π  curve_i( normalize_i( input_i ) ) )
```

The naive product has a known problem: with many considerations each < 1, scores collapse toward zero and an action with 6 considerations can never beat one with 2. Dave Mark's **compensation factor** corrects it:

```
modification = 1 − 1/n           (n = number of considerations)
makeUpValue  = (1 − rawScore) * modification
finalScore   = rawScore + (makeUpValue * rawScore)
```

**Response curves** — four shapes cover nearly everything:

| Curve | Formula | Use for |
|---|---|---|
| Linear | `m*(x − c) + b` | "More is proportionally better." |
| Quadratic / polynomial | `m*(x − c)^k + b` | `k>1`: only matters when high (ammo). `k<1`: matters immediately then plateaus. |
| Logistic (sigmoid) | `1 / (1 + e^(−k*(x − c)))` | Thresholds with soft edges — "low health" without a cliff. |
| Logit | `c + (1/k) * ln(x/(1−x))` | Inverse S; strong pull at both extremes. |

```lua
--!strict
--!native
-- Utility.lua — Infinite-Axis-style scoring.

local Utility = {}

export type Curve = (x: number) -> number

function Utility.linear(m: number, c: number, b: number): Curve
    return function(x) return math.clamp(m * (x - c) + b, 0, 1) end
end

function Utility.polynomial(m: number, k: number, c: number, b: number): Curve
    return function(x)
        local v = x - c
        local p = (v < 0 and k % 2 == 0) and -math.abs(v) ^ k or (v >= 0 and v ^ k or -(-v) ^ k)
        return math.clamp(m * p + b, 0, 1)
    end
end

function Utility.logistic(k: number, c: number): Curve
    return function(x) return math.clamp(1 / (1 + math.exp(-k * (x - c))), 0, 1) end
end

export type Consideration = {
    name: string,
    input: (ctx: any) -> number,   -- MUST return normalized [0,1]
    curve: Curve,
}

export type UtilityAction = {
    name: string,
    weight: number,                              -- static priority multiplier
    considerations: { Consideration },
    isValid: ((ctx: any) -> boolean)?,           -- hard gate, evaluated first
    execute: (ctx: any) -> (),
}

--- Score one action, with Dave Mark's compensation factor and early-out.
function Utility.score(action: UtilityAction, ctx: any, cutoff: number): number
    if action.isValid and not action.isValid(ctx) then return 0 end
    local n = #action.considerations
    if n == 0 then return action.weight end
    local modification = 1 - 1 / n
    local result = action.weight

    for _, c in action.considerations do
        -- EARLY-OUT: a running product can only go down, so bail as soon as it
        -- cannot beat the best score so far. This is the single biggest
        -- performance win in utility AI and costs one comparison.
        if result <= cutoff then return 0 end
        local raw = c.curve(math.clamp(c.input(ctx), 0, 1))
        local makeUp = (1 - raw) * modification
        result *= (raw + makeUp * raw)
    end
    return result
end

--- Pick the best action. `topK > 1` samples among the K best for variety.
function Utility.select(actions: { UtilityAction }, ctx: any, topK: number?): UtilityAction?
    local best, bestScore = nil, 0
    local k = topK or 1
    if k <= 1 then
        for _, a in actions do
            local s = Utility.score(a, ctx, bestScore)
            if s > bestScore then best, bestScore = a, s end
        end
        return best
    end
    local scored = {}
    for _, a in actions do
        local s = Utility.score(a, ctx, 0)
        if s > 0 then table.insert(scored, { a = a, s = s }) end
    end
    table.sort(scored, function(x, y) return x.s > y.s end)
    local pool = math.min(k, #scored)
    if pool == 0 then return nil end
    return scored[math.random(1, pool)].a
end

return Utility
```

A guard's action set, which is where the expressiveness shows:

```lua
local actions: { Utility.UtilityAction } = {
    {
        name = "AttackTarget", weight = 1.0,
        isValid = function(ctx) return ctx.visibleTarget ~= nil end,
        considerations = {
            { name = "HasTarget", input = function(ctx) return ctx.visibleTarget and 1 or 0 end,
              curve = Utility.linear(1, 0, 0) },
            { name = "InRange",   input = function(ctx) return 1 - math.min(ctx.distanceToTarget / 60, 1) end,
              curve = Utility.logistic(12, 0.55) },     -- sharp-ish falloff past range
            { name = "MyHealth",  input = function(ctx) return ctx.health / ctx.maxHealth end,
              curve = Utility.polynomial(1, 0.5, 0, 0) }, -- willing to fight even hurt
            { name = "AmmoLeft",  input = function(ctx) return ctx.ammo / ctx.maxAmmo end,
              curve = Utility.polynomial(1, 2, 0, 0) },   -- only matters when it gets low
        },
        execute = function(ctx) ctx:fireAt(ctx.visibleTarget) end,
    },
    {
        name = "TakeCover", weight = 1.1,
        isValid = function(ctx) return ctx.nearestCover ~= nil end,
        considerations = {
            { name = "LowHealth",   input = function(ctx) return 1 - ctx.health / ctx.maxHealth end,
              curve = Utility.logistic(14, 0.62) },       -- kicks in hard below ~38% hp
            { name = "UnderFire",   input = function(ctx) return math.min(ctx.recentDamage / 40, 1) end,
              curve = Utility.linear(1, 0, 0) },
            { name = "CoverIsNear", input = function(ctx) return 1 - math.min(ctx.coverDistance / 40, 1) end,
              curve = Utility.polynomial(1, 2, 0, 0) },
        },
        execute = function(ctx) ctx:moveTo(ctx.nearestCover) end,
    },
    {
        name = "Reload", weight = 1.0,
        isValid = function(ctx) return ctx.ammo < ctx.maxAmmo end,
        considerations = {
            { name = "AmmoLow",  input = function(ctx) return 1 - ctx.ammo / ctx.maxAmmo end,
              curve = Utility.polynomial(1, 3, 0, 0) },
            { name = "Safe",     input = function(ctx) return ctx.visibleTarget and 0.2 or 1 end,
              curve = Utility.linear(1, 0, 0) },
        },
        execute = function(ctx) ctx:reload() end,
    },
    { name = "Patrol", weight = 0.3, considerations = {}, execute = function(ctx) ctx:patrol() end },
}
```

Two production details: **hysteresis** (give the currently-running action a ×1.15 bonus so the agent doesn't flip-flop between two near-equal choices every tick), and **the early-out cutoff** in `score` — with 20 actions × 4 considerations that's 80 curve evaluations per decision without it, and typically ~20 with it.

### 4.4 GOAP, and whether it's worth it

Goal-Oriented Action Planning (Jeff Orkin, *F.E.A.R.*, 2005) gives each action **preconditions** and **effects** as symbolic world-state predicates, gives the agent a **goal** (a desired world state), and runs **A\* backwards through action space** — from the goal, finding actions whose effects satisfy unmet conditions — to produce a plan: an ordered action sequence. The agent executes it, and re-plans when the plan is invalidated. **[lit — not re-verified 2026-09; Jeff Orkin, "Three States and a Plan: The AI of F.E.A.R.", GDC 2006]**

What it buys: emergent action sequences you never authored. An F.E.A.R. soldier that wants `TargetDead` discovers, on its own, "I have no ammo → Reload requires ammo → I have no ammo → so: MoveToCover, then Reload, then Attack" — from action definitions alone.

```lua
--!strict
-- GOAP action shape. The planner is A* over sets of world-state predicates.
export type GoapAction = {
    name: string,
    cost: number,
    preconditions: { [string]: boolean },
    effects: { [string]: boolean },
    checkProceduralPrecondition: ((agent: any) -> boolean)?,   -- e.g. "cover exists"
    perform: (agent: any) -> boolean,
}

local actions = {
    { name = "Attack", cost = 1,
      preconditions = { weaponLoaded = true, targetVisible = true },
      effects = { targetDead = true } },
    { name = "Reload", cost = 2,
      preconditions = { hasAmmo = true },
      effects = { weaponLoaded = true } },
    { name = "MoveToCover", cost = 3,
      preconditions = {},
      effects = { inCover = true, targetVisible = false } },
    { name = "Flank", cost = 5,
      preconditions = { inCover = false },
      effects = { targetVisible = true } },
}
-- Plan for goal { targetDead = true } from state { hasAmmo = true, targetVisible = false }
-- → MoveToCover? no... → Flank, Reload, Attack.
```

**The honest verdict: usually not worth it on Roblox.** The costs are real — planning is an A* search per re-plan (and re-plans are frequent in dynamic games), the symbolic world state is fiddly to keep accurate, and the emergent behaviour is *hard to debug and harder to design against*, because you cannot easily answer "why did it do that?" Ship GOAP when: the *ordering* of actions genuinely cannot be authored (a survival/crafting sim, a heist sim, an immersive sim with many interacting verbs), and you have the tooling budget for a plan visualizer. For a shooter, a tower defence, an obby, a simulator or a fighting game, utility AI gives you 90% of the perceived intelligence for 20% of the complexity, and you can actually reason about it.

### 4.5 Priority-list AI

The one everyone under-rates:

```lua
--!strict
-- The first rule that fires, wins. That's the entire architecture.
local RULES = {
    { when = function(s) return s.health <= 0 end,                 act = die },
    { when = function(s) return s.health < 0.2 * s.maxHealth end,  act = flee },
    { when = function(s) return s.canAttack and s.inRange end,     act = attack },
    { when = function(s) return s.visibleTarget ~= nil end,        act = chase },
    { when = function(s) return s.lastKnownPosition ~= nil end,    act = investigate },
    { when = function(s) return true end,                          act = patrol },
}

local function think(s)
    for _, rule in RULES do
        if rule.when(s) then return rule.act(s) end
    end
end
```

Ten lines, zero allocation, trivially debuggable, and genuinely sufficient for the majority of shipped Roblox NPCs. Start here. Graduate when the rule list exceeds ~8 entries, when you need multi-frame actions (→ BT), or when the rules start needing "sort of" (→ utility).

### 4.6 The decision table

See **[Architecture decision table](#architecture-decision-table)** below.

---

## 5. Perception

Perception is the *other* half of "feels intelligent". An agent with a perfect A* and a brilliant planner that sees through walls reads as a cheater; an agent with a dumb FSM and believable senses reads as alive.

### 5.1 The sensor pipeline

Run perception as an explicit pipeline with early-outs, cheapest test first. This ordering is the whole performance story:

```
1. Broad phase   — spatial hash bucket lookup (§7.5).  O(k), no engine calls.
2. Range         — squared distance vs sightRange².    ~1 op. Never use .Magnitude here.
3. FOV cone      — dot product vs cos(halfAngle).      ~5 ops.
4. Line of sight — ONE raycast.                        The only expensive step.
5. Memory update — write to blackboard.
```

Steps 1–3 eliminate 90–99% of candidates before any raycast happens. Getting this order wrong is the difference between 200 agents and 20.

### 5.2 Field-of-view and line of sight

```lua
--!strict
--!native
local Perception = {}

-- Cache these; constructing RaycastParams per call allocates.
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true
losParams.RespectCanCollide = true   -- ignore CanCollide=false decoration

--- FOV test. `halfAngleCos` is precomputed: math.cos(math.rad(fovDegrees / 2)).
function Perception.inCone(
    eyePos: Vector3, lookDir: Vector3, targetPos: Vector3,
    rangeSq: number, halfAngleCos: number
): boolean
    local offset = targetPos - eyePos
    local distSq = offset:Dot(offset)              -- squared distance, no sqrt
    if distSq > rangeSq or distSq < 1e-6 then return distSq <= rangeSq end
    -- Normalize only after the range test passes.
    local dir = offset / math.sqrt(distSq)
    return lookDir:Dot(dir) >= halfAngleCos
end

--- Line of sight with multi-point sampling so a target isn't "invisible"
--- because one pixel of its torso is behind a lamp post.
local SAMPLE_OFFSETS = { Vector3.new(0, 1.5, 0), Vector3.new(0, 0, 0), Vector3.new(0, -1.5, 0) }

function Perception.hasLineOfSight(
    eyePos: Vector3, targetRoot: BasePart, ignoreList: { Instance }
): (boolean, number)
    losParams.FilterDescendantsInstances = ignoreList
    local visibleSamples = 0
    for _, offset in SAMPLE_OFFSETS do
        local p = targetRoot.Position + offset
        local dir = p - eyePos
        local hit = workspace:Raycast(eyePos, dir, losParams)
        if not hit or hit.Instance:IsDescendantOf(targetRoot.Parent :: Instance) then
            visibleSamples += 1
        end
    end
    -- Return a CONFIDENCE, not just a boolean. Partial visibility should
    -- produce partial confidence, which drives accuracy and reaction time.
    return visibleSamples > 0, visibleSamples / #SAMPLE_OFFSETS
end

return Perception
```

**Roblox specifics that matter here:**

- `RaycastParams.RespectCanCollide` (`true`) makes the ray ignore `CanCollide = false` parts. Without it, every decorative non-colliding leaf blocks sight. This is the most common LOS bug on Roblox.
- Set `BasePart.CanQuery = false` on anything that should never block a ray (foliage, particles' host parts, UI anchors). It's cheaper than filter lists.
- `workspace:Raycast` is `thread_safety: Safe` — verified. Perception is the part of your AI stack that parallelizes.
- Prefer a **single** raycast per target with 3 vertical samples over a full `Blockcast`; `Blockcast`/`Spherecast` are heavier and, per the docs, do not detect parts that already intersect the shape at the start.

### 5.3 Hearing and noise events

Hearing is a push system, not a poll. Anything that makes noise publishes an event; the spatial hash decides who hears it.

```lua
--!strict
-- NoiseSystem — push-based; O(agents in radius), not O(all agents).
local NoiseSystem = {}
local grid = require(script.Parent.SpatialHash)

export type Noise = {
    position: Vector3, loudness: number, source: Instance?, kind: string, at: number,
}

function NoiseSystem.emit(noise: Noise)
    -- Loudness is a radius in studs; occlusion halves it per wall crossed.
    for _, agent in grid:queryRadius(noise.position, noise.loudness) do
        local d = (agent.position - noise.position).Magnitude
        local occlusionFactor = NoiseSystem.occlusion(noise.position, agent.position)
        local heardLoudness = noise.loudness * occlusionFactor - d
        if heardLoudness > 0 then
            agent.brain:onHeard(noise, heardLoudness / noise.loudness)
        end
    end
end

local occlusionParams = RaycastParams.new()
occlusionParams.RespectCanCollide = true

function NoiseSystem.occlusion(from: Vector3, to: Vector3): number
    -- One ray: hit = something between us = muffled. Good enough; 1 ray beats
    -- a proper acoustic solve by ~1000x and players cannot tell the difference.
    local hit = workspace:Raycast(from, to - from, occlusionParams)
    return hit and 0.45 or 1
end

return NoiseSystem
```

Standard loudness values that feel right: footstep walking 15 studs, running 35, gunshot 250, suppressed 60, door slam 80, body falling 40, glass breaking 120. Emit them from the systems that cause them, not from the AI.

### 5.4 Memory, last-known-position, and the search behaviour

The single behaviour that most raises perceived intelligence: **the agent goes to where it last saw you, then searches nearby, then gives up.**

```lua
--!strict
export type TargetMemory = {
    target: Model,
    lastSeenPosition: Vector3,
    lastSeenVelocity: Vector3,
    lastSeenTime: number,
    confidence: number,          -- decays over time
    investigated: boolean,
}

local MEMORY_DURATION = 25       -- s before the target is forgotten entirely
local CONFIDENCE_HALFLIFE = 6    -- s for confidence to halve

local Memory = {}
Memory.__index = Memory

function Memory.new() return setmetatable({ targets = {} :: { [Model]: TargetMemory } }, Memory) end

function Memory:see(target: Model, position: Vector3, velocity: Vector3, quality: number)
    local m = self.targets[target]
    if not m then
        m = { target = target, confidence = 0, investigated = false } :: any
        self.targets[target] = m
    end
    m.lastSeenPosition = position
    m.lastSeenVelocity = velocity
    m.lastSeenTime = os.clock()
    m.confidence = math.min(1, m.confidence + quality * 0.6)
    m.investigated = false
end

function Memory:update()
    local now = os.clock()
    for target, m in self.targets do
        local age = now - m.lastSeenTime
        if age > MEMORY_DURATION or not target.Parent then
            self.targets[target] = nil
        else
            m.confidence = 0.5 ^ (age / CONFIDENCE_HALFLIFE)
        end
    end
end

--- Where should I look? Extrapolate from last-seen velocity, but decay the
--- extrapolation with confidence so the guess degrades into a plain "there".
function Memory:predictedPosition(m: TargetMemory): Vector3
    local age = os.clock() - m.lastSeenTime
    local lead = math.min(age, 2.5) * m.confidence
    return m.lastSeenPosition + m.lastSeenVelocity * lead
end

--- Search points: a ring of positions around the last known position, ordered
--- by how plausible an escape route each is (toward last-seen velocity first).
function Memory:searchPoints(m: TargetMemory, count: number, radius: number): { Vector3 }
    local pts = {}
    local bias = m.lastSeenVelocity.Magnitude > 1 and m.lastSeenVelocity.Unit or Vector3.xAxis
    local baseAngle = math.atan2(bias.Z, bias.X)
    for i = 0, count - 1 do
        -- Alternate left/right of the escape direction, widening.
        local spread = (i // 2 + 1) * (math.pi * 2 / (count + 1))
        local sign = (i % 2 == 0) and 1 or -1
        local a = baseAngle + spread * sign
        pts[i + 1] = m.lastSeenPosition + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
    end
    return pts
end

return Memory
```

### 5.5 Alertness states

Three or four levels, with **asymmetric transitions** — alertness rises fast and falls slowly. That asymmetry is what makes stealth games tense.

| Level | Enter when | Behaviour | Decay |
|---|---|---|---|
| **Unaware** | default | Patrol, normal walk speed, relaxed animation set | — |
| **Suspicious** | a noise, or a target seen for < reactionDelay | Stop, turn toward stimulus, scan. Speed ×0.7 | → Unaware after 8–12 s |
| **Searching** | lost a confirmed target, or suspicion maxed | Move to last-known, then `searchPoints`. Calls out to allies | → Suspicious after 20–30 s |
| **Alert** | confirmed visual for ≥ reactionDelay | Full combat. Shares target with squad | → Searching when LOS lost > 3 s |

Model suspicion as a 0→1 meter that fills at a rate proportional to `stimulusStrength × visibilityQuality / distance`, rather than a boolean — that gives you the Metal Gear "?" moment for free, and lets a player back out of detection.

### 5.6 Group awareness and shared perception

Give every squad a **shared blackboard**. One agent's detection becomes the squad's, after a short, *visible* propagation delay (a shout, a radio callout) — never instantly, or players correctly perceive it as cheating.

```lua
--!strict
export type SquadBlackboard = {
    members: { any },
    sharedTargets: { [Model]: { position: Vector3, time: number, reportedBy: any } },
    attackTokens: number,            -- see §6.4
    claimedCover: { [BasePart]: any },
    claimedFlankSlots: { [number]: any },
}

local function reportContact(squad: SquadBlackboard, reporter, target: Model, pos: Vector3)
    squad.sharedTargets[target] = { position = pos, time = os.clock(), reportedBy = reporter }
    reporter:playCallout("ContactLeft")              -- telegraph the share
    task.delay(0.5 + math.random() * 0.6, function()  -- propagation delay
        for _, m in squad.members do
            if m ~= reporter and m.alive then
                m.memory:see(target, pos, Vector3.zero, 0.5)  -- low confidence: hearsay
                m:setAlertness("Searching")
            end
        end
    end)
end
```

Note the low confidence on hearsay: an ally who was *told* about you should search, not snap-aim.

### 5.7 Making AI feel fair

This is engineering, and it's mostly four numbers.

**1. Reaction delay.** Never react on the frame of detection. Humans take 200–300 ms to react to a visual stimulus. Give each agent `reactionDelay = base + random jitter`:

| Difficulty | Reaction delay |
|---|---|
| Easy | 0.55–0.90 s |
| Normal | 0.30–0.55 s |
| Hard | 0.18–0.30 s |
| Unfair (bosses only) | 0.08–0.15 s |

**2. Telegraphing.** Every damaging action gets a wind-up that is (a) longer than the player's reaction time, and (b) *visually and audibly distinct per attack*. Heavy attack = 0.8 s wind-up with a distinct pose and a sound cue. A player who dies to an untelegraphed attack blames the game; a player who dies to a telegraphed one blames themselves. This is the highest-leverage single thing in combat AI.

**3. Deliberately imperfect aim.** Perfect hitscan is never fun.

```lua
--!strict
-- Aim error that TIGHTENS with time-on-target: missing the first shots and
-- then converging reads as "it's ranging me in", which players find fair and
-- also gives them a window to break line of sight.
local function aimPoint(ctx, targetPos: Vector3): Vector3
    local timeOnTarget = os.clock() - ctx.acquiredAt
    local convergence = math.clamp(timeOnTarget / ctx.convergeTime, 0, 1)
    local spread = ctx.maxSpreadStuds * (1 - convergence) + ctx.minSpreadStuds * convergence
    -- Movement penalty: a strafing player is genuinely harder to hit.
    local targetSpeed = ctx.targetVelocity.Magnitude
    spread *= 1 + math.min(targetSpeed / 16, 1) * 0.8
    local a = math.random() * math.pi * 2
    local r = math.sqrt(math.random()) * spread          -- uniform over the disc
    return targetPos + Vector3.new(math.cos(a) * r, (math.random() - 0.5) * spread, math.sin(a) * r)
end
```

**4. Grace rules.** The unwritten ones every good shooter uses: the *first* shot at a newly-acquired target always misses; an enemy never fires within 0.5 s of the player entering its FOV; damage from off-screen enemies is reduced or delayed; if the player's health is below a threshold, enemies briefly reduce their attack-token allotment. None of these are visible, all of them are felt.

---

## 6. Combat AI

### 6.1 Target selection and threat

A threat table beats "nearest target" for anything with more than one attacker.

```lua
--!strict
--!native
-- Threat accumulates from damage, healing (aggro on healers), taunts, and
-- proximity; it decays so the table doesn't freeze on the first attacker.
local Threat = {}
Threat.__index = Threat

local DECAY_PER_SECOND = 0.06        -- 6%/s: ~11 s half-life
local PROXIMITY_THREAT = 1.5         -- per second within melee range
local HEAL_THREAT_RATIO = 0.5
local TAUNT_MULTIPLIER = 1.3         -- must beat the current top by this margin

function Threat.new() return setmetatable({ table_ = {} :: { [Model]: number }, top = nil }, Threat) end

function Threat:add(source: Model, amount: number)
    self.table_[source] = (self.table_[source] or 0) + amount
end

function Threat:onDamaged(by: Model, damage: number) self:add(by, damage) end
function Threat:onHealed(healer: Model, amount: number) self:add(healer, amount * HEAL_THREAT_RATIO) end

function Threat:onTaunt(by: Model)
    local current = self.table_[self.top or by] or 0
    self.table_[by] = math.max(self.table_[by] or 0, current * TAUNT_MULTIPLIER + 1)
end

function Threat:update(dt: number, myPosition: Vector3, meleeRange: number)
    local decay = (1 - DECAY_PER_SECOND) ^ dt
    local best, bestValue = nil, -1
    for target, value in self.table_ do
        if not target.Parent then self.table_[target] = nil; continue end
        value *= decay
        local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root and (root.Position - myPosition).Magnitude < meleeRange then
            value += PROXIMITY_THREAT * dt
        end
        if value < 0.5 then self.table_[target] = nil else self.table_[target] = value end
        if value > bestValue then best, bestValue = target, value end
    end
    -- STICKINESS: only switch if the new top beats the current by 10%.
    -- Without this, two similar attackers make the AI spin in place.
    if self.top and self.table_[self.top] and best ~= self.top then
        if bestValue < self.table_[self.top] * 1.1 then best = self.top end
    end
    self.top = best
end

return Threat
```

For non-MMO genres, score targets with a small utility function instead: `score = w1*(1/distance) + w2*isLowHealth + w3*isHealer + w4*isDamagingMe + w5*hasLineOfSight - w6*alliesAlreadyTargeting`. The last term is what stops five enemies dogpiling one player.

### 6.2 Attack timing

Three timers per attacker, and they are not the same thing:

- **Wind-up** (telegraph): animation plays, no damage yet, cannot be cancelled after a commit point. This is your fairness budget.
- **Active**: hit window.
- **Recovery + cooldown**: vulnerability window + the gate before the next attack.

Add a **global attack rhythm** on top of per-agent cooldowns, or a group of enemies with the same 1.5 s cooldown will synchronize into a metronome. Jitter each agent's cooldown by ±20% at spawn, and re-jitter on each use.

### 6.3 Positioning — flanking, kiting, cover

**Flank slots.** Divide the ring around the target into N slots; agents claim one from the squad blackboard. Claiming is what prevents two enemies from standing in the same place.

```lua
--!strict
local function claimFlankSlot(squad, agent, targetPos: Vector3, radius: number, slots: number): Vector3
    -- Free any slot this agent already held.
    for i, holder in squad.claimedFlankSlots do
        if holder == agent then squad.claimedFlankSlots[i] = nil end
    end
    local best, bestCost = nil, math.huge
    for i = 1, slots do
        if squad.claimedFlankSlots[i] == nil then
            local a = (i - 1) * (math.pi * 2 / slots)
            local p = targetPos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
            local cost = (p - agent.position).Magnitude
            if cost < bestCost then best, bestCost = i, cost end
        end
    end
    if not best then return targetPos end
    squad.claimedFlankSlots[best] = agent
    local a = (best - 1) * (math.pi * 2 / slots)
    return targetPos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
end
```

**Kiting.** Maintain a distance *band*, not a distance. Move away below `minRange`, toward above `maxRange`, strafe inside the band. A single target distance produces the classic jitter.

```lua
local function kiteDesire(agent, targetPos: Vector3, minR: number, maxR: number): Vector3
    local offset = targetPos - agent.position
    local d = offset.Magnitude
    local dir = d > 1e-3 and offset.Unit or Vector3.xAxis
    if d < minR then return -dir                                   -- back off
    elseif d > maxR then return dir                                -- close in
    else return Vector3.new(-dir.Z, 0, dir.X) * agent.strafeSign end -- orbit
end
```
Flip `strafeSign` every 1.5–3 s (randomized) so the orbit isn't a perfect circle.

**Cover.** Pre-author cover points as tagged parts with an attachment indicating the protected direction; at runtime score each candidate: `score = protectionFromThreat * w1 + shootingAngleQuality * w2 - distanceToReach * w3 - occupiedPenalty`. Validate `protectionFromThreat` with a single raycast from the threat's eye height to the cover's stand position. Claim cover in the squad blackboard exactly like flank slots.

### 6.4 The attack token pattern

**The problem:** five enemies surround the player, all decide "in range, attack", and the player takes five simultaneous hits and dies without a readable moment. The game feels cheap, and no amount of per-enemy tuning fixes it, because the problem is *coordination*, not individual behaviour.

**The solution**, popularized by Bungie's Halo AI work and now standard: a target owns a small pool of **attack tokens**. An enemy must hold a token to commit to an attack. Everyone else circles, repositions, taunts, and *looks* threatening. **[lit — not re-verified 2026-09; Damian Isla's Halo 2/3 AI talks, GDC 2005 & GDC 2008 "Building a Better Battle"; the pattern is documented across the *Game AI Pro* series]**

```lua
--!strict
-- AttackTokens.lua — one pool per target.
local AttackTokens = {}
AttackTokens.__index = AttackTokens

function AttackTokens.new(capacity: number, minHoldTime: number, maxHoldTime: number)
    return setmetatable({
        capacity = capacity, holders = {} :: { [any]: number },
        count = 0, minHold = minHoldTime, maxHold = maxHoldTime,
    }, AttackTokens)
end

function AttackTokens:request(agent, priority: number): boolean
    if self.holders[agent] then return true end
    if self.count < self.capacity then
        self.holders[agent] = os.clock()
        self.count += 1
        return true
    end
    -- Pool full: steal from the lowest-priority holder that has held long enough.
    local now = os.clock()
    local victim, victimPriority = nil, priority
    for holder, since in self.holders do
        if now - since >= self.minHold and holder.attackPriority < victimPriority then
            victim, victimPriority = holder, holder.attackPriority
        end
    end
    if victim then
        self:release(victim)
        self.holders[agent] = now
        self.count += 1
        return true
    end
    return false
end

function AttackTokens:release(agent)
    if self.holders[agent] then
        self.holders[agent] = nil
        self.count -= 1
    end
end

--- Force-expire long holds so one agent can't camp a token.
function AttackTokens:update()
    local now = os.clock()
    for holder, since in self.holders do
        if now - since > self.maxHold or not holder.alive then self:release(holder) end
    end
end

return AttackTokens
```

Tuning that works in practice:

| Enemy count around the player | Token capacity |
|---|---|
| 1–2 | 1 |
| 3–4 | 2 |
| 5–8 | 2–3 |
| 9+ (horde) | 3–4, plus a short global cooldown between any two attacks landing |

Melee and ranged should use **separate pools** — 2 melee tokens and 2 ranged tokens reads very differently from 4 shared. And the agents *without* a token must not stand still: circling, repositioning, weapon-ready poses and callouts are what sell "they're waiting for an opening" rather than "they're idle".

### 6.5 Difficulty scaling

Scale in this order, because this is the order of "least to most likely to feel cheap":

1. **Reaction delay and attack-token capacity** — invisible, hugely effective.
2. **Aim spread and convergence time.**
3. **Attack cooldowns and the number of simultaneous attackers.**
4. **Perception ranges and FOV angle.**
5. **Enemy count and composition.**
6. **Damage and health numbers** — last resort. Raising enemy health is the least satisfying difficulty lever in games and the one players notice most.

Never scale: pathfinding quality, player-position knowledge (an enemy that "just knows" where you are is the #1 cause of "this game cheats" reviews), or movement speed beyond ~15%.

### 6.6 Boss phase machines

A boss is an FSM over *phases*, where each phase swaps the attack set, and transitions are gated on health thresholds with **hysteresis and a mandatory transition state**.

```lua
--!strict
local BOSS_PHASES = {
    { name = "Phase1", healthAbove = 0.66,
      attacks = { "Slam", "Sweep" }, moveSpeed = 12, tokenCapacity = 1 },
    { name = "Phase2", healthAbove = 0.33,
      attacks = { "Slam", "Sweep", "Charge", "SummonAdds" }, moveSpeed = 16, tokenCapacity = 2 },
    { name = "Phase3", healthAbove = 0.0,
      attacks = { "Slam", "Charge", "Enrage", "ArenaWide" }, moveSpeed = 20, tokenCapacity = 2 },
}

-- Three rules that make boss phases read well:
-- 1. A transition is an EVENT, not a threshold crossing: play a locked,
--    invulnerable-or-not transition animation so the player SEES the change.
-- 2. Never transition mid-attack; queue it for the next recovery window.
-- 3. Phases only go forward. Healing the boss above a threshold must not
--    regress the phase, or you get flicker.
local function maybeAdvancePhase(boss)
    if boss.transitioning or boss.inAttack then return end
    local frac = boss.humanoid.Health / boss.humanoid.MaxHealth
    local target = #BOSS_PHASES
    for i, p in BOSS_PHASES do
        if frac > p.healthAbove then target = i; break end
    end
    if target > boss.phaseIndex then
        boss.transitioning = true
        boss:playPhaseTransition(BOSS_PHASES[target], function()
            boss.phaseIndex = target
            boss.transitioning = false
        end)
    end
end
```

Within a phase, pick attacks with a small utility function (range, cooldown, how recently used, player position relative to the arena) rather than random selection — random produces the same attack three times in a row, which reads as a bug.

---

## 7. Performance at scale — the hard problem

### 7.1 The cost model

Per-NPC cost decomposes into six terms, and they are wildly unequal:

| Term | Where it's paid | Rough share for a default R15 NPC |
|---|---|---|
| **Humanoid simulation** (`stepHumanoid`) | server + owning client | **dominant** |
| **Animation evaluation** (`stepAnimation`) | server (if server-side) + client | large |
| **Rendering** (draw calls, skinning) | client only | large on client |
| **Physics** (`physicsStepped`, `worldStep`) | server + owner | large if unanchored |
| **Replication** | server → all clients | grows with N × update rate |
| **Your Luau AI** | wherever you run it | usually the *smallest* term |

The last row is the important one. **Developers reliably optimize the wrong thing.** A behavior tree tick is tens of microseconds; a `Humanoid` step is engine C++ that you cannot profile from Luau and cannot make faster except by not having one. Profile with the MicroProfiler and look for `stepHumanoid`, `stepAnimation`, `physicsStepped` and `updateInvalidatedFastClusters` before you micro-optimize your BT.

Budget anchors, verified from Roblox's own performance docs: the frame budget is **16.67 ms** (60 FPS) on both client and server; **server heartbeat is capped at 60 FPS for all games**; and total server memory is **`6.25 GiB + (100 MiB × largest_number_of_connected_players)`**, with a recommendation to stay under 50%.

### 7.2 Why `Humanoid` is the dominant cost, and how to run without one

Roblox states it directly in `performance-optimization/improve.md`: *"`Humanoid` is a class that provides a wide range of functionalities to player and non player characters (NPCs). Although powerful, a `Humanoid` comes with a significant computation cost."*

What a `Humanoid` does every frame, per the `EvaluateStateMachine` documentation:

- Applies **forces** to its parts (a physics controller per NPC).
- Runs **spatial queries** ("sensors") to detect floors, ladders and auto-jump obstacles. **This is a per-Humanoid, per-frame raycast/overlap workload that you did not write and cannot see.**
- Mutates **collision state** on character parts.
- Evaluates **state transitions** and **replicates** them.

**The four levers, in order of payoff:**

**Lever 1 — don't have a Humanoid.** Roblox's own recommendation: *"For static NPCs, use a simple `AnimationController` … For moving NPCs, consider implementing your own movement controller and using an `AnimationController` for animations."* Note that `AnimationController:LoadAnimation()` is deprecated — create an `Animator` and call `Animator:LoadAnimation()` directly; `AnimationController` is documented as "nothing more than an empty shell for a child `Animator`".

**Lever 2 — `Humanoid.EvaluateStateMachine = false`.** The documented middle path. You keep the Humanoid Instance (and therefore `HumanoidDescription`, accessories, layered clothing, the unified FastCluster benefit, and the Animate script receiving state events if you set states manually) but lose all forces, all sensors, all collision-state changes and all automatic transitions. You then drive the rig with CFrames yourself. This is the single best lever for "I want avatar-quality NPCs and hundreds of them".

**Lever 3 — `Humanoid:SetStateEnabled(state, false)`** for every unused state. Roblox: *"There is a performance cost to leaving certain HumanoidStateTypes enabled. Disable any that are not needed."*

```lua
--!strict
-- The standard NPC state cull. Keep only what the NPC actually does.
local KEEP = {
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.Dead] = true,
    -- Add Jumping/Freefall/Landed only if the NPC jumps.
}
local function cullStates(humanoid: Humanoid)
    for _, state in Enum.HumanoidStateType:GetEnumItems() do
        if state ~= Enum.HumanoidStateType.None and not KEEP[state] then
            pcall(function() humanoid:SetStateEnabled(state, false) end)
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
end
```
(`pcall` because `StrafingNoPhysics` and `None` reject `ChangeState`/`SetStateEnabled` in some engine versions.)

**Lever 4 — play animations on the client.** Roblox: *"In games with a large number of NPCs, consider creating the `Animator` on the client and running the animations locally. This reduces the load on the server and the need for unnecessary replication. It also makes additional optimizations possible (such as only playing animations for NPCs who are near to the character)."*

**A humanoid-less NPC that still looks right:**

```lua
--!strict
-- LightNPC — no Humanoid, no physics, anchored root, CFrame-driven.
-- Animations via a manually created Animator on an AnimationController.
local LightNPC = {}
LightNPC.__index = LightNPC

function LightNPC.new(rig: Model)
    local root = rig.PrimaryPart :: BasePart
    root.Anchored = true                    -- no physics solver involvement
    for _, d in rig:GetDescendants() do
        if d:IsA("BasePart") then
            d.CanCollide = false            -- no broadphase entries
            d.CanTouch = false              -- no touch events
            d.CanQuery = false              -- not hit by other NPCs' rays
            d.Massless = true
        end
    end
    local controller = Instance.new("AnimationController")
    controller.Parent = rig
    local animator = Instance.new("Animator")
    animator.Parent = controller
    return setmetatable({
        rig = rig, root = root, animator = animator,
        position = root.Position, velocity = Vector3.zero,
        maxSpeed = 16, maxForce = 60, lookDir = root.CFrame.LookVector,
        tracks = {},
    }, LightNPC)
end

function LightNPC:step(dt: number, steeringForce: Vector3)
    self.velocity += steeringForce * dt
    local speed = self.velocity.Magnitude
    if speed > self.maxSpeed then self.velocity *= self.maxSpeed / speed; speed = self.maxSpeed end
    self.velocity *= (1 - math.min(dt * 3, 1))          -- damping, no physics
    self.position += self.velocity * dt
    if speed > 0.5 then
        self.lookDir = limitTurn(self.lookDir, self.velocity.Unit, dt)
    end
    -- Ground snap: ONE raycast, and only for tiers that need it (see §7.3).
    -- Cheaper still: sample a precomputed height grid and skip the raycast.
    return CFrame.lookAlong(self.position, self.lookDir)
end
```

Then move every NPC in one call:

```lua
--!strict
-- BULK MOVE: one engine call for all NPCs, instead of N property sets.
local parts, cframes = table.create(1000), table.create(1000)
local function flushMovement(npcs)
    table.clear(parts); table.clear(cframes)
    for i, npc in npcs do
        parts[i] = npc.root
        cframes[i] = npc.pendingCFrame
    end
    workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end
```

`BulkMoveTo` is verified: *"This provides a very fast way to move large numbers of parts, as you don't have to pay the cost of separate property sets for each individual part."* The `FireCFrameChanged` mode fires only the `CFrame` changed signal instead of `Position`, `Orientation` **and** `CFrame` — a 3× reduction in signal dispatch. The docs also, correctly, caution not to reach for it unless part movement is a measured bottleneck; with 500+ NPCs it is.

**Caveat worth knowing (verified):** the docs note a *reverse* case — skinned MeshParts in a Model **without** a Humanoid are grouped into spatially-organized FastClusters, and moving them forces cluster rebuilds; *"a highly effective workaround is to embed a Humanoid within the Model. The presence of a Humanoid overrides the default spatial clustering behavior, mandating the use of a single, unified FastCluster for the entire Model."* So for **skinned-mesh** NPCs that move, a Humanoid with `EvaluateStateMachine = false` may genuinely outperform no Humanoid at all. Profile both. This is the one case where the usual advice inverts.

### 7.3 LOD for AI — tier definitions

Everything below is a design you implement; Roblox provides no AI LOD. Define tiers by distance to the *nearest* player (or camera, client-side) and by whether the agent is on screen.

| Tier | Trigger | AI update rate | Movement | Perception | Animation | Physics/Model |
|---|---|---|---|---|---|---|
| **T0 — Hero** | in combat with a player, or scripted-important | 20–30 Hz | Full steering + avoidance, per-agent path | Full: FOV + LOS raycasts, hearing | Full, `Animator.PreferLodEnabled = false` | Full rig, Humanoid if needed |
| **T1 — Near** | < 120 studs and on screen | 10 Hz decisions, 30 Hz steering | Steering + separation, shared/queued paths | FOV + LOS at 5 Hz | Full rig, engine LOD throttling on | Full rig, no Humanoid |
| **T2 — Mid** | 120–300 studs, or off screen near | 2–5 Hz | Flow field or straight-line lerp, no avoidance | Distance + FOV only, **no raycasts** | Idle/walk loop only, throttled | Simplified rig or single mesh |
| **T3 — Far** | 300–800 studs | 0.5–1 Hz | Position extrapolated along a path; teleport-on-arrival is fine | None | None (static pose) | Billboard / impostor, or SLIM composite |
| **T4 — Statistical** | > 800 studs, or streamed out | event-driven only | **No position at all** — just "is in region X, will arrive at time T" | None | None | **No Instance** |

**T4 is the tier that actually buys you the big numbers.** An NPC nobody can see does not need a position; it needs a *schedule*. A patrol is `{route = 7, phase = 0.62, speedFactor = 1.0}` — three numbers. When a player comes into range, you evaluate the schedule to a position and spawn a real rig from the pool. This is how a world can contain 5,000 "NPCs" and simulate 80.

```lua
--!strict
-- LODManager: assigns tiers, hysteresis-banded so NPCs don't thrash at borders.
local TIER_ENTER = { 0, 120, 300, 800 }     -- distance to enter tier N
local TIER_EXIT  = { 0, 145, 340, 880 }     -- must exceed this to LEAVE tier N-1
local Players = game:GetService("Players")

local function nearestPlayerDistanceSq(pos: Vector3): number
    local best = math.huge
    for _, plr in Players:GetPlayers() do
        local char = plr.Character
        local root = char and char.PrimaryPart
        if root then
            local d = (root.Position - pos)
            local dsq = d:Dot(d)
            if dsq < best then best = dsq end
        end
    end
    return best
end

local function assignTier(npc): number
    local dsq = nearestPlayerDistanceSq(npc.position)
    local d = math.sqrt(dsq)
    local current = npc.tier
    -- Rising: use ENTER thresholds. Falling: use EXIT thresholds. Hysteresis.
    local t = 4
    for i = 4, 1, -1 do
        local threshold = (i > current) and TIER_ENTER[i] or TIER_EXIT[i]
        if threshold and d < threshold then t = i - 1 end
    end
    if npc.isHero then t = 0 end
    return math.clamp(t, 0, 4)
end
```

**Engine-level LOD you get for free**, all verified:

- `Workspace.ClientAnimatorThrottling` (`Enum.ClientAnimatorThrottlingMode` = `Default`/`Disabled`/`Enabled`): *"When enabled, animations on remotely-simulated `Model` instances will begin to throttle. The throttler calculates throttling intensity using: visibility of a `Model` in relation to the `Camera`; in-game FPS; number of active animations."*
- `Animator.PreferLodEnabled` (default `true`): *"the engine may reduce animation evaluation frequency for remotely-simulated characters based on distance, screen coverage, and frame budget."* Set `false` on hero NPCs only — *"disabling LOD for many animators simultaneously can impact performance."*
- `Animator.EvaluationThrottled` (read-only, per frame): *"When `true`, the `Animator` reused the pose from the previous frame instead of evaluating fresh animation data."* Use it to skip your procedural animation layer — *"if evaluation was throttled, applying procedural offsets would fight the stale pose and should be skipped."*
- `Workspace.EnableSLIMAvatars` + `StreamingEnabled` renders platform avatars as lightweight SLIM representations *with full animation support* as camera distance increases. SLIM classifies models into four distance zones, from full part-by-part rendering, through composite rendering with full instances present, to composite-only with the hierarchy streamed out, to not rendered. Roblox ships a demo place, "SLIM Platform Avatars", described as **200 animated avatars rendered with SLIM**. Prerequisites: `StreamingEnabled`, place saved to Roblox (cloud transcoding), and Team Create enabled.

### 7.4 Time-slicing AI updates

The core technique: **do not update every agent every frame.** Partition agents into `N` buckets and update one bucket per frame. With `N = 10` at 60 FPS, every agent thinks at 6 Hz and you pay 1/10 of the per-frame cost. Nobody can tell.

```lua
--!strict
-- Scheduler.lua — LOD-aware round-robin with a hard per-frame time budget.
local RunService = game:GetService("RunService")

local Scheduler = {}
Scheduler.__index = Scheduler

-- Frames between updates, per LOD tier.
local TIER_INTERVAL = { [0] = 2, [1] = 6, [2] = 20, [3] = 120, [4] = math.huge }

function Scheduler.new(budgetMs: number)
    return setmetatable({
        agents = {}, frame = 0, budget = budgetMs / 1000, cursor = 1,
        stats = { updated = 0, skipped = 0, overBudgetFrames = 0 },
    }, Scheduler)
end

function Scheduler:add(agent) table.insert(self.agents, agent); agent.nextFrame = self.frame end
function Scheduler:remove(agent)
    local i = table.find(self.agents, agent)
    if i then
        -- Swap-remove: O(1). table.remove is O(n) and shows up at 1000 agents.
        self.agents[i] = self.agents[#self.agents]
        self.agents[#self.agents] = nil
    end
end

function Scheduler:step(dt: number)
    self.frame += 1
    local deadline = os.clock() + self.budget
    local n = #self.agents
    if n == 0 then return end

    local updated, examined = 0, 0
    -- Start where we left off so a budget overrun doesn't starve the tail.
    while examined < n do
        local i = ((self.cursor - 1) % n) + 1
        local agent = self.agents[i]
        self.cursor = i + 1
        examined += 1

        if agent and self.frame >= agent.nextFrame then
            local interval = TIER_INTERVAL[agent.tier] or 20
            if interval < math.huge then
                -- Elapsed time SINCE THIS AGENT last thought — not frame dt.
                local now = os.clock()
                local agentDt = now - (agent.lastThink or now)
                agent.lastThink = now
                agent:think(agentDt)
                updated += 1
                -- Jitter the next slot so agents never re-synchronize.
                agent.nextFrame = self.frame + interval + math.random(0, math.max(1, interval // 4))
            else
                agent.nextFrame = self.frame + 600
            end
        end

        if os.clock() > deadline then
            self.stats.overBudgetFrames += 1
            break
        end
    end
    self.stats.updated += updated
end

return Scheduler
```

Three details that make this work rather than merely exist:

1. **Pass the agent's own elapsed time**, not the frame `dt`. An agent that thinks every 20 frames must integrate 20 frames' worth of change, or everything runs at 1/20 speed.
2. **Jitter the interval.** Without it, agents added in the same frame stay in the same bucket forever, and you get a periodic spike.
3. **Cursor-based resumption.** If the budget cuts the loop short, the next frame continues from where it stopped. Restarting at index 1 starves the tail of the list — a bug that only shows up under load, which is exactly when it hurts.

Separate **thinking** (5–10 Hz, time-sliced) from **moving** (30–60 Hz, every frame, cheap). Steering integration and `BulkMoveTo` run every frame for T0–T2; decisions do not.

### 7.5 Spatial partitioning for perception

Naive neighbour queries are O(n²): 200 agents = 40,000 distance checks per evaluation. A uniform spatial hash makes it O(n·k) where k is the average occupancy of the queried cells.

```lua
--!strict
--!native
-- SpatialHash.lua — uniform grid, integer keys, no allocation on query when
-- the caller supplies the output buffer.

local SpatialHash = {}
SpatialHash.__index = SpatialHash

--- cellSize should be roughly your LARGEST query radius. Too small and a query
--- touches many cells; too large and each cell holds too many agents.
function SpatialHash.new(cellSize: number)
    return setmetatable({ cellSize = cellSize, cells = {} :: { [number]: { any } }, keyOf = {} }, SpatialHash)
end

local OFFSET = 32768   -- so negative world coords stay non-negative
local function hashKey(cx: number, cz: number): number
    return (cx + OFFSET) * 65536 + (cz + OFFSET)
end

function SpatialHash:_cellCoords(pos: Vector3): (number, number)
    return math.floor(pos.X / self.cellSize), math.floor(pos.Z / self.cellSize)
end

function SpatialHash:insert(agent, pos: Vector3)
    local cx, cz = self:_cellCoords(pos)
    local k = hashKey(cx, cz)
    local bucket = self.cells[k]
    if not bucket then bucket = {}; self.cells[k] = bucket end
    bucket[#bucket + 1] = agent
    self.keyOf[agent] = k
end

function SpatialHash:remove(agent)
    local k = self.keyOf[agent]
    if not k then return end
    local bucket = self.cells[k]
    if bucket then
        local i = table.find(bucket, agent)
        if i then bucket[i] = bucket[#bucket]; bucket[#bucket] = nil end
        if #bucket == 0 then self.cells[k] = nil end
    end
    self.keyOf[agent] = nil
end

--- Only touches the hash when the agent actually crosses a cell boundary.
--- This is the difference between "rebuild every frame" and "nearly free".
function SpatialHash:update(agent, pos: Vector3)
    local cx, cz = self:_cellCoords(pos)
    local k = hashKey(cx, cz)
    if self.keyOf[agent] == k then return end
    self:remove(agent)
    self:insert(agent, pos)
end

--- Query into a caller-supplied buffer: zero allocation per call.
function SpatialHash:queryRadius(pos: Vector3, radius: number, out: { any }): number
    table.clear(out)
    local r = math.ceil(radius / self.cellSize)
    local cx, cz = self:_cellCoords(pos)
    local radiusSq = radius * radius
    local count = 0
    for dz = -r, r do
        for dx = -r, r do
            local bucket = self.cells[hashKey(cx + dx, cz + dz)]
            if bucket then
                for _, agent in bucket do
                    local d = agent.position - pos
                    if d:Dot(d) <= radiusSq then
                        count += 1
                        out[count] = agent
                    end
                end
            end
        end
    end
    return count
end

return SpatialHash
```

**Rebuild strategy matters.** Rebuilding the whole hash every frame is O(n) allocations; the `update`-on-cell-change above is nearly free for slow-moving agents. For very dense, very fast crowds, a **double-buffered full rebuild** into two preallocated tables (swap each frame) avoids the per-agent `table.find` in `remove` entirely.

**For world geometry, use the engine's broadphase instead of your own.** `Workspace:GetPartBoundsInRadius(position, radius, overlapParams)` is a documented, `thread_safety: Safe` spatial query against the engine's own structures. Cache the `OverlapParams` (default is `OverlapParams{MaxParts=0, Tolerance=0, BruteForceAllSlow=false, RespectCanCollide=false, CollisionGroup=Default, FilterDescendantsInstances={}}`) and set `MaxParts` to bound the result — an unbounded query in a dense scene returns thousands of parts and allocates a table for all of them. Note the documented caveat: `GetPartBoundsInBox`/`InRadius` test **bounding boxes**, not exact volumes; use `GetPartsInPart` when precision matters, at higher cost.

### 7.6 Pooling

Roblox's own guidance: *"Instead of destroying an NPC completely, send the NPC to a pool of inactive NPCs… This process is called pooling, which minimizes the amount of times characters need to be instantiated."* And the reason it matters so much for NPCs specifically: *"Instantiating, modifying, and respawning models with `Humanoid`s or skinned `MeshPart`s frequently… can be intensive for the engine to process, particularly if these models use layered clothing"*, with *"lengthy `updateInvalidatedFastClusters` tags (over 4 ms)"* as the MicroProfiler signature.

```lua
--!strict
-- NPCPool — park rigs far away rather than reparenting to nil, which avoids
-- the DataModel add/remove churn that triggers FastCluster invalidation.
local PARK = CFrame.new(0, -5000, 0)

local NPCPool = {}
NPCPool.__index = NPCPool

function NPCPool.new(template: Model, size: number, parent: Instance)
    local self = setmetatable({ free = {}, inUse = {}, template = template }, NPCPool)
    for _ = 1, size do
        local rig = template:Clone()
        rig:PivotTo(PARK)
        rig.Parent = parent
        table.insert(self.free, rig)
    end
    return self
end

function NPCPool:acquire(cf: CFrame): Model?
    local rig = table.remove(self.free)
    if not rig then return nil end          -- pool exhausted: prefer this to growing mid-frame
    rig:PivotTo(cf)
    self.inUse[rig] = true
    return rig
end

function NPCPool:release(rig: Model)
    if not self.inUse[rig] then return end
    self.inUse[rig] = nil
    -- Reset state WITHOUT touching the hierarchy: no adds, no removes, no
    -- size/scale changes (all of which invalidate FastClusters).
    local hum = rig:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = hum.MaxHealth end
    rig:PivotTo(PARK)
    table.insert(self.free, rig)
end

return NPCPool
```

Roblox also warns against **size/scale changes** and **avatar-hierarchy modifications** at runtime for the same FastCluster reason, and recommends: for procedural animation, update `Motor6D.Transform` rather than `JointInstance.C0`/`C1`; and attach extra `BasePart`s **outside** the avatar `Model` hierarchy.

### 7.7 Replicating NPCs as state, not models

The default pattern — server owns full NPC models, everything replicates — costs you server simulation *and* network bandwidth *and* client physics ownership handling. The scalable pattern inverts it.

| Approach | Server holds | Network per NPC per update | Client does | Good for |
|---|---|---|---|---|
| **Full server model** | Complete rig + Humanoid | Full CFrame replication, engine-managed | Nothing | ≤50 NPCs, authoritative combat |
| **Server logic + client visuals** | Invisible root part or no Instance at all; positions in a table | ~8–16 bytes (packed position + state byte) via a batched `RemoteEvent`/`UnreliableRemoteEvent` | Owns the rig, interpolates, animates | 100–1,000 NPCs |
| **Fully client-simulated ambient** | Nothing (a seed) | 0 | Runs the entire agent | Crowds, birds, fish, traffic |

The middle row is the workhorse. Pack aggressively: quantize position to 0.25 studs as three `int16`s relative to a chunk origin (6 bytes), yaw to one byte (1.4° resolution), animation-state to a 4-bit enum. That's 8 bytes per NPC per update; at 10 Hz for 300 visible NPCs that's 24 KB/s per client before compression — acceptable. Send it as one `buffer` through a single `UnreliableRemoteEvent` per tick, not 300 separate events. (Cross-reference chapter 28 for the bit-packing and remote-batching machinery.)

Client-side interpolation is mandatory with this pattern: buffer two state snapshots and render at `now - interpolationDelay` (100–150 ms), so 10 Hz updates render as smooth 60 Hz motion.

**Authority rule:** anything that affects game outcomes (damage, drops, objectives) stays server-authoritative. The client simulates *appearance*. An exploiter who fakes an NPC's position on their screen has changed nothing that matters. (Cross-reference chapter 47.)

### 7.8 Parallel Luau for AI

Verified facts that determine what can and cannot be parallelized:

| API | Thread safety | Parallel-phase usable? |
|---|---|---|
| `workspace:Raycast` | **Safe** | ✅ |
| `workspace:GetPartBoundsInRadius` / `InBox` / `GetPartsInPart` | **Safe** | ✅ |
| `Path:ComputeAsync` | **Unsafe** | ❌ |
| `Path:GetWaypoints` | **Unsafe** | ❌ |
| `PathfindingService:CreatePath` | **Unsafe** | ❌ |
| `workspace:BulkMoveTo` | **Unsafe** | ❌ (must `task.synchronize()` first) |
| Pure Luau (steering, BT, utility, A*, flow fields) | n/a | ✅ |

So the parallel AI architecture is forced into a specific shape: **perceive and decide in parallel; act in serial.**

```lua
--!strict
-- AIActor.lua — a Script under an Actor. Clone one per BUCKET of agents.
local RunService = game:GetService("RunService")
local actor = script:GetActor()

local myAgents = {}                       -- populated via actor:BindToMessage("Assign", ...)
local rayParams = RaycastParams.new()     -- built in the serial phase, reused in parallel
rayParams.FilterType = Enum.RaycastFilterType.Exclude

actor:BindToMessage("Assign", function(agents) myAgents = agents end)

RunService.PostSimulation:ConnectParallel(function(dt)
    -- PARALLEL PHASE: perception + decision + steering integration.
    -- Raycasts and GetPartBounds* are Safe here. No Instance writes.
    for _, agent in myAgents do
        agent:perceive(rayParams)         -- raycasts: Safe
        agent:decide(dt)                  -- pure Luau
        agent:integrate(dt)               -- computes pendingCFrame, writes nothing
    end

    task.synchronize()
    -- SERIAL PHASE: the only place we touch the DataModel.
    -- Collect into module-level buffers and let ONE script call BulkMoveTo.
    MovementQueue.submit(myAgents)
end)
```

Roblox's documented guidance on actor count: *"For the best performance, use more `Actor`s. Even if the device has fewer cores than `Actor`s, the granularity allows for more efficient load balancing between the cores… it's reasonable to use 64 `Actor`s and more instead of just 4, even if you're targeting 4-core systems."* For AI: bucket ~8–16 agents per Actor, and target 32–64 Actors. Also documented: **`require()` cannot be called in a desynchronized parallel phase** — require every module in the serial phase first. And scripts under the *same* Actor always run serially with respect to each other, so one Actor per NPC archetype is not parallelism.

Use `SharedTable` for cross-actor data (the squad blackboard, the flow field) and `Actor:SendMessage`/`BindToMessageParallel` for work dispatch.

**Realistic expectation:** parallel Luau gives you the pure-Luau and raycast portions of your AI across cores. It does **not** touch `stepHumanoid`, `stepAnimation`, physics or replication — which, per §7.1, are the dominant terms. Parallelizing a BT that costs 0.4 ms and leaving 8 ms of `stepHumanoid` alone is not a win. Fix the Humanoid first, *then* parallelize.

### 7.9 What 50, 200, and 1,000 NPCs actually cost

No published Roblox benchmark exists for this, so the table below combines (a) documented engine behaviour, (b) developer-reported figures retrieved via search summaries, and (c) the cost model in §7.1. **Treat the numbers as order-of-magnitude planning figures, not measurements, and benchmark your own rig.**

| NPC count | Naive (full Humanoid, server `MoveTo`, server animations) | Optimized (no Humanoid, CFrame + `BulkMoveTo`, client animation, LOD + time-slicing) |
|---|---|---|
| **50** | Fine everywhere. Server heartbeat healthy. This is where most games sit and never need to optimize. | Overkill. Don't bother. |
| **200** | Server heartbeat degrades; `stepHumanoid` + `stepAnimation` dominate the profile; ping rises. Community reports put the practical wall for Humanoid NPCs around **150** even with all states disabled. **[devforum — via search summary]** | Comfortable. AI thinking ~1–2 ms/frame with 10-bucket slicing; movement dominated by `BulkMoveTo` and rendering. |
| **1,000** | Not viable. | Achievable on desktop clients: **~40–50 FPS at 1,000 rigs** reported with R6 models, no Humanoid, no Animate script, no collision, TweenService movement and adaptive physics stepping; **~150 FPS at 300 rigs** with the same setup. **[devforum — via search summary]** Multiple developers report **1,000–1,500 total NPCs** in a live game "mostly without lag" when most are LOD'd down. **[devforum — via search summary]** |
| **5,000+** | — | Only via §7.3 T4 (statistical, no Instance) + pooling: simulate ~100–200, represent the rest as schedule state. |

The gap between the columns is roughly **5–7×**, and essentially all of it comes from three decisions: no Humanoid, client-side animation, and LOD + time-slicing. Nothing else in this chapter moves the number as much.

