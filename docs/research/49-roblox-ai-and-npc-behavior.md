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

