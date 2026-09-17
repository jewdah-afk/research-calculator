# The EditableMesh Technique Cookbook: Runtime Geometry as a General Creative Instrument

Chapter 21 covers the raw `EditableMesh` API surface. This chapter covers **what to build
with it**: the algorithms, working Luau, the frame-time cost, and which genres each
technique serves.

Every API signature below was read out of `Roblox/creator-docs`
(`content/en-us/reference/engine/classes/EditableMesh.yaml`, `AssetService.yaml`,
`MeshPart.yaml`, `datatypes/Content.yaml`, `enums/MeshAttribute.yaml`) — the repository the
Creator Hub reference page is generated from — on **2026-09-17**, against `main`. Nothing
here is quoted from memory.

**Sourcing caveat, stated up front.** `create.roblox.com` and `devforum.roblox.com` are
blocked by this session's egress policy. Official API facts therefore come from the
creator-docs *source repository* (identical content, upstream of the website). DevForum
numbers are marked **[secondary]** — they were recovered through search-engine summaries of
those threads rather than by reading the pages, so treat the exact digits as
"reported, re-measure before you budget on them". Numbers pulled out of open-source code on
GitHub are marked **[code]** and are directly verifiable at the cited path.

---

## TL;DR for builders

- **Visual vertex edits do NOT require a mesh rebuild.** The docs are explicit: *"Visual
  changes to the mesh will always be immediately reflected by the engine, without the need
  to call `AssetService:CreateMeshPartAsync()`."* You can move vertices every frame. This
  single fact is what makes water, cloth, softbodies, morphs and trails viable.
- **Collision and fluid geometry DO require a rebuild.** `CreateMeshPartAsync()` +
  `MeshPart:ApplyMesh()` is the only way to resync physics with the visual mesh, and the
  docs tell you to do it once *at the end of a conceptual edit*, never per-operation.
- **`CreateMeshPartAsync` is the wall.** Reported at a **fixed ~22 ms plus ~0.27 ms per 1k
  triangles even with `CollisionFidelity.Box` and `CanCollide = false`** [secondary]. At
  60 Hz a frame is 16.6 ms. One rebuild is *already* a dropped frame. Architect so that
  rebuilds are rare, batched, and off the hot path.
- **Hard caps: 60,000 vertices and 20,000 triangles per `EditableMesh`.** Exceeding them
  errors (`AddTriangle` throws *"Triangle count above limit"*). Real production code caps
  itself lower — 50,000 verts / 17,000 tris per batch — because fan-triangulating quads
  can blow the triangle cap while still under the vertex cap [code].
- **A non-`FixedSize` `EditableMesh` reserves the full 60k-vertex worst case against the
  client memory budget.** That is why people hit a wall at roughly **8 dynamic meshes on
  the client** [secondary], and it is why the universal production idiom is
  **build dynamic → `CreateEditableMeshAsync(Content.fromObject(em), {FixedSize = true})`
  → `Destroy()` the dynamic one.** One shipped project holds **81 live fixed-size
  EditableMeshes (47k verts) simultaneously** on a client doing exactly this [code].
- **`CreateDataModelContentAsync` is the escape hatch from the editable budget entirely.**
  It bakes an `EditableMesh` into opaque, DataModel-scoped `Content` that you feed to
  `CreateMeshPartAsync`; after that you can `Destroy()` the `EditableMesh` and hold *zero*
  editable budget while the geometry stays on screen.
- **`Content` holding an `Object` does not replicate.** The docs warn that a replicated
  Instance with an `Object`-source `Content` becomes an unusable placeholder that renders
  as a cyan/magenta checkerboard. Treat `EditableMesh` as a **client-side (or
  bake-then-replicate) technology**.
- **Every generated `MeshPart` is unique `MeshContent`, so every one is its own draw
  call.** Roblox instances identical `MeshContent` into one draw call; procedurally
  generated chunks are all different, so chunk *count* is a draw-call budget, not just a
  triangle budget.
- **Batch APIs exist and you should use them.** `BatchAdd`, `BatchSetValues`,
  `BatchGetValues`, `BatchSetFaceAttributes`, `BatchSetVertexFaceAttributes`,
  `BatchRemove` and friends replace per-element calls; the docs call batching *"typically
  much more performant"*. Per-vertex `SetPosition` is the classic profile killer.
- **All read/query methods are `thread_safety: Safe`; all mutators are `Unsafe`.** That is
  a first-class architecture fact: `RaycastLocal`, `FindClosestPointOnSurface`,
  `FindVerticesWithinSphere`, `GetPosition`, every `BatchGet*` can run in parallel Luau
  Actors. Writes must happen in the serial phase.
- **Skinning IS supported.** `AddBone`, `SetVertexBones`, `SetVertexBoneWeights`,
  `GetFacsPoses`/`SetFacsPose` are all in the current reference. But queries
  (`RaycastLocal`, `FindClosestPointOnSurface`, `FindVerticesWithinSphere`) explicitly run
  against the **bind pose**, not the deformed runtime mesh.
- **`CreateMeshPartAsync` re-centres the geometry on the part.** You must restore
  placement from your own bounding-box centre or your chunk lands in the wrong place
  [code]. This burns everyone once.
- **Don't use `EditableMesh` where a cheaper primitive wins.** WindShake animates 77,750
  leaf meshes at 220+ FPS with plain CFrames [secondary]. Skinned meshes, `Beam`, `Trail`
  and `Terrain` are all *faster* than editable geometry at what they already do. Reach for
  `EditableMesh` when the shape itself must change.

---

## 0. The one question that governs everything: rebuild or not?

The answer is precise, and it is three-valued.

### 0.1 Visual changes: no rebuild

From `EditableMesh.yaml`:

> To recalculate collision and fluid geometry after editing, you can again call
> `AssetService:CreateMeshPartAsync()` and `MeshPart:ApplyMesh()` to update an existing
> `MeshPart`. It's generally recommended to do this at the end of a conceptual edit, not
> after individual calls to methods that manipulate geometry. **Visual changes to the mesh
> will always be immediately reflected by the engine, without the need to call
> `AssetService:CreateMeshPartAsync()`.**

So: a `MeshPart` renders *from* its live `EditableMesh` object. Move a vertex, the picture
changes next frame. Add a triangle (on a non-`FixedSize` mesh), the picture changes next
frame. Remove a face, likewise. This is verified by shipped code — an open-source softbody
simulator calls `SetPosition` on every vertex every frame and never rebuilds:

```lua
-- plirt/Softbody-physics, src/SoftbodyHandler/mesh_build.luau (paraphrased)
function mesh_builder.Update(editable_mesh, vert_ids, mesh_part, pos)
    local N = #vert_ids
    local sum = Vector3.zero
    for i = 1, N do sum += pos[i] end
    local com = sum / N
    mesh_part.CFrame = CFrame.new(com)      -- move the part, not the verts
    for i = 1, N do
        editable_mesh:SetPosition(vert_ids[i], pos[i] - com)
    end
    return com
end
```

Note the trick in there: translate the *part*, and keep vertices local. Vertex churn that
is really rigid motion should always be hoisted into the `CFrame`.

### 0.2 Collision / fluid: rebuild required

`MeshPart:ApplyMesh(meshPart)` copies, per `MeshPart.yaml`:

- `MeshContent` (implicitly updates `MeshId`)
- `TextureContent` (implicitly updates `TextureID`)
- `RenderFidelity`
- `CollisionFidelity` (with any internal collision geometry)
- `FluidFidelity` (with any internal aero geometry)
- `MeshSize`

There is no `RecomputeCollision()`. The round trip is mandatory:

```lua
local rebuilt = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
    CollisionFidelity = Enum.CollisionFidelity.Box,
    RenderFidelity    = Enum.RenderFidelity.Automatic,
    FluidFidelity     = Enum.FluidFidelity.Automatic,
})
existingPart:ApplyMesh(rebuilt)
rebuilt:Destroy()
```

### 0.3 The hidden third cost: per-frame re-transcode

A dirty `EditableMesh` has to be re-uploaded to the GPU. Roblox's MicroProfiler names that
stage `DynamicGeometryManager :: transcodeVerticesAndCalculateBounds`, and a 2025 engine
regression made it run at **40–70 ms of frame time** on affected Windows clients
[secondary]. Two consequences:

1. The cost scales with the **whole mesh's vertex count**, not with how many vertices you
   changed. Moving one vertex of a 20,000-vertex mesh pays a 20,000-vertex re-upload.
   *(Strongly indicated by the symptom and the scope name; I could not read the engine
   source — verify with your own MicroProfiler capture before betting a design on it.)*
2. Therefore: **split anything that deforms into the smallest meshes you can tolerate the
   draw calls for**, and mark only those dirty. Static geometry belongs in separate,
   never-touched meshes (ideally baked with `CreateDataModelContentAsync` so it is not an
   `EditableMesh` at all).

### 0.4 The decision table

| You changed… | Visual updates? | Collision updates? | Cost |
|---|---|---|---|
| Vertex positions (`SetPosition`, `BatchSetValues`) | Yes, next frame | **No** | Luau writes + re-transcode of that mesh |
| Normals / UVs / colors | Yes, next frame | No (irrelevant) | same |
| Topology (`AddTriangle`, `RemoveFace`, `BatchRemove`) | Yes, next frame | **No** | same |
| Anything, and you need physics | — | Only via `CreateMeshPartAsync` + `ApplyMesh` | **~22 ms + 0.27 ms/1k tri** [secondary] |
| Anything, and you need aero/buoyancy | — | Only via rebuild (`FluidFidelity`) | same |

**The architecture rule that falls out:** design every system so the *shape* changes
continuously and the *collision* changes discretely and rarely. A deforming ocean never
rebuilds. A destructible wall rebuilds once per chunk per hit, time-sliced. A voxel world
rebuilds a chunk when its edit batch settles, never per-voxel.

---

## 1. Deformation of existing meshes

### 1.1 The general pattern: displace vertices by a function

Every deformation in this section is one function
`f(restPosition, time, params) -> newPosition` applied over a cached rest pose. Cache the
rest pose **once**; never read positions back from the mesh in a loop (reads are cheap but
not free, and a read-modify-write drifts).

```lua
--!strict
--!native
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

export type Deformer = {
    mesh: EditableMesh,
    ids: { number },        -- vertex ids, dense array
    rest: { Vector3 },      -- parallel rest positions
    scratch: { Vector3 },   -- reused write buffer (avoid per-frame allocation)
}

local Deform = {}

function Deform.capture(mesh: EditableMesh): Deformer
    local ids = mesh:GetVertices()
    -- One batched read instead of N calls to GetPosition.
    local rest = mesh:BatchGetValues(ids) :: { Vector3 }
    return {
        mesh = mesh,
        ids = ids,
        rest = rest,
        scratch = table.create(#ids, Vector3.zero),
    }
end

-- fn(restPos, index) -> Vector3. Applied to every vertex, written in ONE batch call.
function Deform.apply(d: Deformer, fn: (Vector3, number) -> Vector3)
    local rest, out = d.rest, d.scratch
    for i = 1, #rest do
        out[i] = fn(rest[i], i)
    end
    d.mesh:BatchSetValues(d.ids, out)
end

return Deform
```

`BatchGetValues(ids)` returns `(values, alphas)` — `alphas` is `nil` for anything but color
IDs, so the `:: { Vector3 }` cast above is taking the first return only. `BatchSetValues`
requires `#ids == #values` exactly, and all IDs must be the same attribute type.

**Cost.** The Luau side is one loop over N vertices with one table write each. The engine
side is one `BatchSetValues` marshalling call plus one re-transcode. Compare with the
naive version: N separate `SetPosition` calls, each crossing the Luau↔C++ boundary. A
production ocean harness keeps both paths and falls back only if batching is unavailable
[code, `ng643/Mythic`, `tools/OceanCapabilityLab.client.luau`]:

```lua
local ok, err = pcall(function()
    mesh:BatchSetValues(vertexIds, positionBuffer)
    if updateNormals then mesh:BatchSetValues(normalIds, normalBuffer) end
end)
if not ok then
    batchAvailable = false
    for index = 1, VERTEX_COUNT do
        mesh:SetPosition(vertexIds[index], positionBuffer[index])
        if updateNormals then mesh:SetNormal(normalIds[index], normalBuffer[index]) end
    end
end
```

That harness runs a **33×33 grid (1,089 vertices, 2,048 triangles)** and publishes
`updateMs` per frame as a `Workspace` attribute — copy this methodology; it is the right
way to get a number for *your* device mix rather than trusting mine.

### 1.2 Bend

Bend maps a straight axis onto a circular arc. For bending around +Y with the bend axis
along Z, radius `R`, over the object's local X extent:

```lua
local function bend(p: Vector3, k: number): Vector3
    -- k = curvature (1/radius). k -> 0 must degrade to identity.
    if math.abs(k) < 1e-6 then return p end
    local R = 1 / k
    local theta = p.X * k              -- arc length -> angle
    local r = R - p.Y
    return Vector3.new(r * math.sin(theta), R - r * math.cos(theta), p.Z)
end
```

Genres: weapon flex on impact, bending bars in a prison-break game, a deforming bow,
cartoon anticipation on a melee swing.

### 1.3 Twist

```lua
local function twist(p: Vector3, radPerStud: number): Vector3
    local a = p.Y * radPerStud
    local c, s = math.cos(a), math.sin(a)
    return Vector3.new(p.X * c - p.Z * s, p.Y, p.X * s + p.Z * c)
end
```

Genres: obby hazards, wringing-out cartoon physics, corkscrew projectiles, tornado pull.

### 1.4 Squash and stretch

Volume-preserving squash is the single highest-value-per-line game-feel deformation.
Scale one axis by `s`, the other two by `1/sqrt(s)`:

```lua
local function squash(p: Vector3, s: number): Vector3
    local inv = 1 / math.sqrt(s)
    return Vector3.new(p.X * inv, p.Y * s, p.Z * inv)
end
```

Drive `s` from a spring so a landing impact gives `s = 0.6` then oscillates back to 1.
Genres: *everything* — platformers, pets, fruit-collection games, tycoon mascots.

### 1.5 Melt

Melting is a height-dependent radial spread plus a downward collapse, gated by a "melt
front" that rises over time:

```lua
local function melt(p: Vector3, front: number, spread: number, minY: number): Vector3
    if p.Y >= front then return p end
    local t = math.clamp((front - p.Y) / math.max(front - minY, 1e-3), 0, 1)
    local flat = t * t                          -- ease-in: puddle forms late, fast
    local radial = Vector3.new(p.X, 0, p.Z) * (1 + spread * flat)
    local y = p.Y + (minY - p.Y) * flat
    return Vector3.new(radial.X, y, radial.Z)
end
```

Genres: horror (dissolving enemies), survival (ice melting), candy/simulator games.

### 1.6 Inflate (and its correct form)

The naive inflate — `p + p.Unit * k` — inflates about the origin and is wrong for anything
non-convex. The correct inflate pushes along the **vertex normal**. `EditableMesh` stores
normals per face-corner, so build a smooth per-vertex normal first (see §10.4), then:

```lua
local function inflate(p: Vector3, n: Vector3, k: number): Vector3
    return p + n * k
end
```

Genres: balloon/bubble mechanics, "grow" simulators, pufferfish enemies, bloat status
effects.

### 1.7 Wind sway on foliage

The classic vertex-shader wind, done on the CPU. Displacement must be **weighted by height
above the trunk base** so the roots stay put, and phase-offset per instance so a forest
doesn't pulse in lockstep:

```lua
local WIND_DIR = Vector3.new(1, 0, 0.35).Unit

local function windSway(p: Vector3, t: number, instancePhase: number, stiffness: number): Vector3
    local h = math.max(p.Y, 0)
    local weight = (h / 6) ^ 2 / stiffness      -- quadratic: tips move most
    local gust   = math.sin(t * 1.3 + instancePhase + p.X * 0.12)
                 + 0.4 * math.sin(t * 3.1 + instancePhase * 1.7 + p.Z * 0.31)
    return p + WIND_DIR * (gust * weight)
end
```

**Cost reality check.** Do not use this for a forest. WindShake animates **77,750 leaf
meshes at 220+ FPS** by CFraming whole parts [secondary], and `SkinnedGrass` does
interactive foliage with skinned meshes and octree LOD. `EditableMesh` wind is worth it
only for a *small number of hero plants* where the silhouette must actually bend — a
single giant tree the player climbs, a boss-arena centrepiece, a plant the player is
watering. For a field, use skinned meshes.

### 1.8 Jiggle / wobble

Give each vertex a 1-D spring against its rest position, driven by the part's acceleration:

```lua
-- state: vel[i] (Vector3), offset[i] (Vector3)
local STIFF, DAMP = 220.0, 14.0

local function jiggleStep(d, accel: Vector3, dt: number)
    local rest, out = d.rest, d.scratch
    for i = 1, #rest do
        local o = d.offset[i]
        local a = -STIFF * o - DAMP * d.vel[i] - accel * d.weight[i]
        local v = d.vel[i] + a * dt
        o = o + v * dt
        d.vel[i], d.offset[i] = v, o
        out[i] = rest[i] + o
    end
    d.mesh:BatchSetValues(d.ids, out)
end
```

`d.weight[i]` should be 0 at anchored regions (a belly's spine attachment) and 1 at free
regions. Keep the mesh small — this is O(N) per frame *and* dirties the whole mesh.
Genres: pets/companions, cartoon combat, character customization preview, gelatinous
enemies.

### 1.9 Impact dents

A dent is a local, **permanent** deformation: find vertices near the impact, push them
along the impact direction with a falloff, and clamp so the surface cannot invert.

```lua
local function dent(mesh: EditableMesh, localPoint: Vector3, dir: Vector3,
                    radius: number, depth: number)
    local ids = mesh:FindVerticesWithinSphere(localPoint, radius)
    if #ids == 0 then return false end
    local pos = mesh:BatchGetValues(ids) :: { Vector3 }
    local out = table.create(#ids)
    local invR = 1 / radius
    for i = 1, #ids do
        local p = pos[i]
        local d = (p - localPoint).Magnitude * invR
        -- smoothstep falloff: C1-continuous, no crease at the rim
        local w = 1 - d * d * (3 - 2 * d)
        out[i] = p + dir * (depth * math.max(w, 0))
    end
    mesh:BatchSetValues(ids, out)
    return true
end
```

`FindVerticesWithinSphere(center, radius)` is a documented, `thread_safety: Safe` query —
it is the right tool, and it is far cheaper than scanning `GetVertices()`.

**Accumulating dents is the whole trick for vehicle damage.** Never rebuild collision per
dent. Accumulate dents visually; rebuild collision on a timer (say, 250 ms of quiescence)
or at a gameplay beat (vehicle stops, round ends). Genres: racing/demolition derby,
vehicle sims, armour damage in RPGs, boxing/fighting.

---

## 2. Destruction and damage

### 2.1 The damage ladder (pick the cheapest rung that sells it)

| Rung | Technique | Rebuild needed | Cost |
|---|---|---|---|
| 0 | Vertex-color darkening / decal via `EditableImage` | none | ~free |
| 1 | Dent (§1.9) | none (defer collision) | O(local verts) |
| 2 | Crater / hole punch (`BatchRemove` faces) | yes, deferred | O(local faces) + rebuild |
| 3 | Plane cut into two meshes | yes, ×2 | O(faces) + 2 rebuilds |
| 4 | Voronoi shatter into N shards | yes, ×N | O(N × faces) + N rebuilds |

Rung 4 is where `CreateMeshPartAsync`'s fixed cost eats you alive: 12 shards × ~22 ms is
**a quarter of a second of frozen client**. Everything below is about avoiding paying that
synchronously.

### 2.2 Punching a hole (cratering, bullet holes in walls)

```lua
local function punchHole(mesh: EditableMesh, localPoint: Vector3, radius: number): number
    local doomed = {}
    for _, fid in mesh:GetFaces() do
        local vids = mesh:GetFaceVertices(fid)
        local a = mesh:GetPosition(vids[1])
        local b = mesh:GetPosition(vids[2])
        local c = mesh:GetPosition(vids[3])
        local centroid = (a + b + c) / 3
        if (centroid - localPoint).Magnitude <= radius then
            table.insert(doomed, fid)
        end
    end
    if #doomed == 0 then return 0 end
    mesh:BatchRemove(doomed)     -- one call, not #doomed calls
    mesh:RemoveUnused()          -- reclaim orphaned verts/normals/UVs/colors
    return #doomed
end
```

Two documented behaviours matter here. `BatchRemove` *"removes a batch of faces"* but
**does not delete the vertices and attributes they used** — you must call `RemoveUnused()`.
And an invalid or already-removed ID *"throws an error and removes nothing"*, so never
feed it stale IDs from a previous frame.

This leaves a raw, unclosed hole. For walls that is often fine (add a scorch decal). For a
hole that must look thick, extrude the rim: for every boundary edge of the removed region,
emit a quad inward by the wall thickness. Boundary edges are those referenced by exactly
one surviving face.

**Progressive structural damage** is this loop with a per-region HP table: partition the
wall's faces into a coarse grid at build time, subtract HP per hit, and punch a region's
faces when its HP crosses zero. That gives you damage states without per-hit geometry work.

### 2.3 Plane cut: the full algorithm

This is the one people ask for and the one that's genuinely fiddly. A plane
`(n, d)` with `dot(n, p) - d` as the signed distance splits a triangle mesh into a positive
and a negative mesh, with a flat cap sealing each side.

**Algorithm**

1. **Classify** every vertex: `s = dot(n, p) - d`. `s > eps` → POS, `s < -eps` → NEG, else
   ON. Snap ON vertices to the plane so degenerate slivers don't appear.
2. **Split crossing edges.** For each triangle edge `(a, b)` with `s_a * s_b < 0`, compute
   `t = s_a / (s_a - s_b)` and the intersection `p = lerp(a, b, t)`. **Memoize by the
   unordered edge key** so both adjacent triangles produce the *same* new vertex — this is
   what prevents cracks. Interpolate UV and color at `t` too.
3. **Re-triangulate each triangle** by its sign pattern. There are only three cases up to
   symmetry:
   - all same side → emit whole into that side;
   - 1 vs 2 → the lone vertex plus its two edge points make one triangle on its side; the
     other two vertices plus the two edge points make a quad → two triangles on the other
     side;
   - a vertex exactly ON → a single split into two triangles.
4. **Collect the cut loop.** Every edge point pair produced by a crossing triangle is a
   segment of the cut boundary. Build an adjacency map from these segments and walk it to
   extract closed loops. Multiple loops are normal (cutting a torus gives two).
5. **Cap each loop.** Project the loop into the plane's 2-D basis `(u, v)` where
   `u = any unit vector ⟂ n`, `v = n × u`. Ear-clip the 2-D polygon. Emit the resulting
   triangles into the POS mesh with normal `-n`, and the mirrored winding into the NEG
   mesh with normal `+n`.

```lua
--!strict
local AssetService = game:GetService("AssetService")

export type CutResult = { pos: EditableMesh?, neg: EditableMesh? }

local EPS = 1e-4

local function planeCut(src: EditableMesh, n: Vector3, d: number): CutResult
    n = n.Unit
    local posM = AssetService:CreateEditableMesh()
    local negM = AssetService:CreateEditableMesh()
    if not posM or not negM then return { pos = nil, neg = nil } end

    -- 1. classify ----------------------------------------------------------
    local srcIds  = src:GetVertices()
    local srcPos  = src:BatchGetValues(srcIds) :: { Vector3 }
    local sign, byId, posOf = {}, {}, {}
    for i, id in srcIds do
        local p = srcPos[i]
        posOf[id] = p
        byId[id] = i
        local s = n:Dot(p) - d
        sign[id] = if s > EPS then 1 elseif s < -EPS then -1 else 0
    end

    -- lazily-created per-mesh vertex ids
    local mapPos, mapNeg = {}, {}
    local function vidIn(mesh, map, key, p: Vector3): number
        local v = map[key]
        if not v then v = mesh:AddVertex(p); map[key] = v end
        return v
    end

    -- 2. edge split memo ---------------------------------------------------
    local cutPoints: { [string]: Vector3 } = {}
    local function edgeKey(a: number, b: number): string
        return if a < b then `{a}_{b}` else `{b}_{a}`
    end
    local function splitEdge(a: number, b: number): (string, Vector3)
        local k = edgeKey(a, b)
        local p = cutPoints[k]
        if not p then
            local pa, pb = posOf[a], posOf[b]
            local sa = n:Dot(pa) - d
            local sb = n:Dot(pb) - d
            local t = sa / (sa - sb)
            p = pa:Lerp(pb, t)
            cutPoints[k] = p
        end
        return k, p
    end

    local loopSegments: { { string } } = {}

    -- 3. per-triangle re-triangulation ------------------------------------
    for _, fid in src:GetFaces() do
        local v = src:GetFaceVertices(fid)
        local a, b, c = v[1], v[2], v[3]
        local sa, sb, sc = sign[a], sign[b], sign[c]

        if sa >= 0 and sb >= 0 and sc >= 0 then
            posM:AddTriangle(vidIn(posM, mapPos, a, posOf[a]),
                             vidIn(posM, mapPos, b, posOf[b]),
                             vidIn(posM, mapPos, c, posOf[c]))
        elseif sa <= 0 and sb <= 0 and sc <= 0 then
            negM:AddTriangle(vidIn(negM, mapNeg, a, posOf[a]),
                             vidIn(negM, mapNeg, b, posOf[b]),
                             vidIn(negM, mapNeg, c, posOf[c]))
        else
            -- rotate so that `lone` is the vertex alone on its side
            local tri = { a, b, c }
            local sg  = { sa, sb, sc }
            local lone = 1
            for i = 1, 3 do
                local j, k = i % 3 + 1, (i + 1) % 3 + 1
                if sg[i] ~= 0 and sg[j] == -sg[i] and sg[k] == -sg[i] then lone = i break end
            end
            local L  = tri[lone]
            local M1 = tri[lone % 3 + 1]
            local M2 = tri[(lone + 1) % 3 + 1]
            local k1, p1 = splitEdge(L, M1)
            local k2, p2 = splitEdge(L, M2)
            table.insert(loopSegments, { k1, k2 })

            local loneMesh, loneMap, otherMesh, otherMap
            if sg[lone] > 0 then
                loneMesh, loneMap, otherMesh, otherMap = posM, mapPos, negM, mapNeg
            else
                loneMesh, loneMap, otherMesh, otherMap = negM, mapNeg, posM, mapPos
            end
            -- lone side: one triangle L, p1, p2
            loneMesh:AddTriangle(
                vidIn(loneMesh, loneMap, L,  posOf[L]),
                vidIn(loneMesh, loneMap, k1, p1),
                vidIn(loneMesh, loneMap, k2, p2))
            -- other side: quad p1, M1, M2, p2 -> two triangles
            local q1 = vidIn(otherMesh, otherMap, k1, p1)
            local q2 = vidIn(otherMesh, otherMap, M1, posOf[M1])
            local q3 = vidIn(otherMesh, otherMap, M2, posOf[M2])
            local q4 = vidIn(otherMesh, otherMap, k2, p2)
            otherMesh:AddTriangle(q1, q2, q3)
            otherMesh:AddTriangle(q1, q3, q4)
        end
    end

    -- 4+5. cap: walk `loopSegments` into loops, ear-clip in the plane basis.
    capLoops(posM, mapPos, negM, mapNeg, cutPoints, loopSegments, n)

    posM:RemoveUnused(); negM:RemoveUnused()
    return { pos = posM, neg = negM }
end
```

`capLoops` is the standard 2-D ear-clip: build `adj[key] -> {otherKey}`, walk each
connected component into an ordered ring, project with `u, v`, then repeatedly clip the
ear with the smallest reflex-free angle. (`Roblox/resources` ships an ear-clip in
`ReplicatedFirst.Geometry` used by its Landmass generator [code].)

**Cost.** O(F) Luau work plus **two** `CreateMeshPartAsync` calls. A 2,000-triangle prop
cut in half costs roughly `2 × (22 + 0.27 × 2) ≈ 45 ms` of rebuild alone [secondary]. That
is 3 dropped frames. **Cut on a hitch you can hide** (a hit-stop freeze, a slow-mo, a
camera punch) — this is why every good slicing game has a dramatic pause at the moment of
the cut.

Genres: sword games, ninja/fruit-slicing, surgery sims, mining, sawmill/lumber tycoons.

### 2.4 Voronoi shattering

**Algorithm**

1. Scatter `k` **seed points** inside the object's bounding volume. Bias them toward the
   impact point (sample in a normal distribution around it) so the break is dense where it
   was hit and coarse at the edges — this is what makes it look physical rather than
   random.
2. Each shard is the **Voronoi cell** of its seed: the intersection of half-spaces
   `dot(x - (si+sj)/2, sj - si) <= 0` for every other seed `sj`.
3. Compute each cell by **iterated plane-clipping**: start with the object's convex hull
   (or bounding box) and clip it by each bisector plane. That's the §2.3 plane cut, keeping
   only the negative side, run `k-1` times per shard.
4. In practice you clip against only the seed's **nearest ~12 neighbours** — distant
   bisectors never touch the cell. Use a k-d tree or a uniform grid over the seeds.
5. Emit one `EditableMesh` per shard, give it the parent's material/color, unanchor,
   apply an impulse radially from the impact.

**The performance shape.** Luau cost is O(k · 12 · F_hull), which is small — hulls are
tens of faces. The killer is **k rebuilds**. Mitigations, in order of effectiveness:

- **Pre-fracture offline.** Shatter the mesh in Studio at build time, upload the shards as
  real assets, and at runtime just unanchor them. This is what most shipped destruction
  does and it costs ~0 ms. Runtime Voronoi is only worth it when the fracture must depend
  on *where* the hit landed in a way pre-fracture can't fake.
- **Amortise.** Spawn shards over several frames; show a particle burst to cover the first
  two frames while the mesh parts stream in.
- **Bake once, reuse.** `CreateDataModelContentAsync` each shard's geometry into opaque
  `Content` and cache it keyed by (mesh, seed pattern). The second identical break is free
  and — bonus — identical `MeshContent` instances *instance into one draw call*.
- **Hybrid.** Big shards as real geometry (2–4), small debris as pre-made generic chunks.

A community resource, *Calculon™ Episode 6 — Physics Aware Voronoi Fracture Integration*,
publishes a free/open-source implementation with a benchmarks section [secondary]. Another
shipped system splits a part into "about 12 convex shards, each committed to a real
`MeshPart` at runtime with `CreateEditableMesh` → `CreateDataModelContentAsync` →
`CreateMeshPartAsync`" [secondary] — and that same report documents a **live bug**: once
the shards settle, walking a character into one makes them all **snap back to their
original positions**. Test physics interaction on runtime-created MeshParts before you
ship a destruction system.

### 2.5 Debris generation

Don't generate debris geometry. Generate debris *instances* from a pre-baked pool:

```lua
-- Build once at load: N generic chunk shapes, baked to opaque Content.
local debrisContent: { Content } = {}
for i = 1, 8 do
    local em = makeIrregularChunk(i)               -- displaced tetra/box, ~40 tris
    local res, content = AssetService:CreateDataModelContentAsync(Content.fromObject(em))
    em:Destroy()
    if res == Enum.CreateContentResult.Success then
        table.insert(debrisContent, content)
    end
end
```

Then every debris spawn is `CreateMeshPartAsync(debrisContent[i], {CollisionFidelity =
Enum.CollisionFidelity.Box})` — still ~22 ms, so **pool the MeshParts too** and recycle
them by CFrame. A recycled debris part costs a CFrame write.

---

## 3. Terrain and landscape

### 3.1 Heightmap → mesh

```lua
--!strict
--!native
local AssetService = game:GetService("AssetService")

-- size: cells per side. spacing: studs per cell. height(x,z) -> studs.
local function buildHeightChunk(size: number, spacing: number,
                                originX: number, originZ: number,
                                height: (number, number) -> number)
    local em = AssetService:CreateEditableMesh()
    if not em then return nil end

    local side = size + 1
    local positions = table.create(side * side)
    local uvs       = table.create(side * side)
    for z = 0, size do
        for x = 0, size do
            local i = z * side + x + 1
            local wx, wz = originX + x * spacing, originZ + z * spacing
            positions[i] = Vector3.new(x * spacing, height(wx, wz), z * spacing)
            uvs[i] = Vector2.new(x / size, z / size)
        end
    end

    local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, positions)
    local uids = em:BatchAdd(Enum.MeshAttribute.UV, uvs)

    local faces = table.create(size * size * 2)
    for z = 0, size - 1 do
        for x = 0, size - 1 do
            local a = z * side + x + 1
            local b = a + 1
            local c = a + side
            local dd = c + 1
            -- flip the diagonal per-quad so ridges don't all lean one way
            if ((x + z) % 2) == 0 then
                table.insert(faces, { vids[a], vids[c], vids[dd] })
                table.insert(faces, { vids[a], vids[dd], vids[b] })
            else
                table.insert(faces, { vids[a], vids[c], vids[b] })
                table.insert(faces, { vids[b], vids[c], vids[dd] })
            end
        end
    end
    local fids = em:BatchAdd(Enum.MeshAttribute.Face, faces)

    -- assign UVs per corner, one batched call
    local uvArrays = table.create(#fids)
    for i, f in faces do
        uvArrays[i] = { uids[indexOf(vids, f[1])], uids[indexOf(vids, f[2])], uids[indexOf(vids, f[3])] }
    end
    em:BatchSetFaceAttributes(fids, uvArrays)
    return em, vids, positions
end
```

(In real code keep a `vid -> index` map rather than `indexOf`; it is shown that way only
to keep the listing readable.)

**Chunk sizing against the caps.** A `size × size` grid costs `(size+1)²` vertices and
`2·size²` triangles. The triangle cap of 20,000 binds first:

| `size` | vertices | triangles | fits? |
|---|---|---|---|
| 32 | 1,089 | 2,048 | comfortably |
| 64 | 4,225 | 8,192 | comfortably |
| 96 | 9,409 | 18,432 | just barely |
| 100 | 10,201 | 20,000 | **exactly at the cap** |
| 128 | 16,641 | 32,768 | **rejected** |

So **a single-mesh heightfield chunk maxes out at 100×100 cells.** Anything larger must be
split. In practice pick 64 and accept more chunks — smaller chunks re-transcode faster when
edited and cull better.

### 3.2 Runtime sculpting brushes

All four classic brushes are the same loop with a different `apply`:

```lua
--!strict
export type Brush = "raise" | "lower" | "smooth" | "flatten"

-- Falloff curves. t in [0,1] where 0 = brush centre, 1 = rim.
local Falloff = {
    smooth   = function(t) return 1 - t * t * (3 - 2 * t) end,  -- smoothstep, C1
    linear   = function(t) return 1 - t end,
    sharp    = function(t) return (1 - t) ^ 3 end,
    constant = function(t) return 1 end,
    bell     = function(t) return math.exp(-4 * t * t) end,      -- gaussian-ish
}

local function sculpt(mesh: EditableMesh, centre: Vector3, radius: number,
                      strength: number, brush: Brush, curve, dt: number)
    local ids = mesh:FindVerticesWithinSphere(centre, radius)
    if #ids == 0 then return false end
    local pos = mesh:BatchGetValues(ids) :: { Vector3 }

    -- 'flatten' and 'smooth' need an aggregate first
    local targetY = 0
    if brush == "flatten" or brush == "smooth" then
        for i = 1, #pos do targetY += pos[i].Y end
        targetY /= #pos
    end

    local out = table.create(#ids)
    local invR = 1 / radius
    for i = 1, #ids do
        local p = pos[i]
        local w = curve(math.clamp((p - centre).Magnitude * invR, 0, 1)) * strength * dt
        local y = p.Y
        if brush == "raise" then
            y += w
        elseif brush == "lower" then
            y -= w
        elseif brush == "flatten" then
            y += (centre.Y - y) * math.min(w, 1)
        else -- smooth: pull toward the local mean
            y += (targetY - y) * math.min(w, 1)
        end
        out[i] = Vector3.new(p.X, y, p.Z)
    end
    mesh:BatchSetValues(ids, out)
    return true
end
```

**`smooth` done properly** uses each vertex's own 1-ring, not the brush-wide mean:
`GetAdjacentVertices(vertexId)` gives the neighbours, and the umbrella operator is
`p' = p + λ(mean(neighbours) - p)`. That is O(N·deg) and worth it for a real sculpting
tool; the brush-mean version above is the cheap approximation good enough for a gameplay
"level the ground" action.

**The architecture that makes sculpting tractable:**

- Drag the brush every frame → **only** `BatchSetValues`. No rebuild. It looks live.
- On mouse-up (or after 200 ms idle) → rebuild collision for the touched chunks only.
- Keep a dirty-set of chunk keys; the rebuild pass pops one chunk per frame.

```lua
local dirty: { [string]: true } = {}
local queue: { string } = {}
RunService.Heartbeat:Connect(function()
    local key = table.remove(queue)
    if not key then return end
    dirty[key] = nil
    local chunk = chunks[key]
    local rebuilt = AssetService:CreateMeshPartAsync(Content.fromObject(chunk.mesh), {
        CollisionFidelity = Enum.CollisionFidelity.Default,
    })
    chunk.part:ApplyMesh(rebuilt)
    rebuilt:Destroy()
end)
```

**One chunk rebuild per frame** is the correct time-slice. At ~22 ms fixed cost you cannot
afford two.

### 3.3 Digging and tunnelling

Heightfields cannot represent overhangs, so digging *into* a hill needs a volumetric
representation (§4). But two cheaper tricks cover most games:

- **Pit digging on a heightfield**: the `lower` brush plus a rim skirt. If the pit walls
  need to be vertical, insert a ring of duplicated vertices at the rim radius and drop the
  inner ring — you get a cylinder wall without leaving the 2.5-D model.
- **Prefab tunnel segments**: represent the tunnel as a spline and mesh it with §5.5's
  tube generator, then punch the heightfield where the tunnel mouth meets the surface.
  This is how most mining games actually do it; it's O(spline) instead of O(volume).

### 3.4 Runtime erosion

Droplet (hydraulic) erosion on a heightfield, one droplet at a time, is genuinely cheap and
can run as a background task:

```lua
local function erodeDroplet(h: { number }, side: number, x: number, z: number)
    local vel, water, sediment = 0.0, 1.0, 0.0
    local dx, dz = 0.0, 0.0
    for _ = 1, 30 do
        local gx, gz = gradientAt(h, side, x, z)
        dx = dx * 0.05 - gx        -- inertia
        dz = dz * 0.05 - gz
        local len = math.sqrt(dx*dx + dz*dz)
        if len < 1e-5 then break end
        dx, dz = dx/len, dz/len
        local nx, nz = x + dx, z + dz
        if nx < 1 or nz < 1 or nx >= side or nz >= side then break end
        local dh = heightAt(h, side, nx, nz) - heightAt(h, side, x, z)
        local capacity = math.max(-dh * vel * water * 4.0, 0.01)
        if sediment > capacity or dh > 0 then
            local drop = if dh > 0 then math.min(dh, sediment) else (sediment - capacity) * 0.3
            deposit(h, side, x, z, drop); sediment -= drop
        else
            local erode = math.min((capacity - sediment) * 0.3, -dh)
            erodeAt(h, side, x, z, erode, 3); sediment += erode
        end
        vel = math.sqrt(math.max(vel*vel + dh * -9.81, 0))
        water *= 0.99
        x, z = nx, nz
    end
end
```

Run `N` droplets per Heartbeat inside a budget (`while os.clock() - t0 < 0.002 do ... end`),
flush the modified heightfield to the mesh with one `BatchSetValues` per frame, and rebuild
collision every second or so. Genres: survival/world-sim, god games, geology education,
world-generation showcases.

### 3.5 Cave systems

Caves need real volume. Two approaches:

- **3-D noise + surface extraction** (§4). A density field `d(x,y,z) = noise3(...) - bias`
  with ridged/worley noise gives the classic cave network; run Surface Nets or Dual
  Contouring on it.
- **Tunnel graph + tube meshing.** Generate a graph of cave passages (random walk, or a
  space-colonization tree §5.1), then sweep a varying-radius tube along each edge (§5.5)
  and blend junctions with a metaball union (§6.7). Far cheaper, fully controllable, and
  the passages are guaranteed connected — which random noise does not guarantee.

An open-source Roblox cave generator builds exactly this way and notes the retention rule
in a one-liner worth stealing [code, `GeoCodeCrafter/Cave`]:

```lua
local keepAlive: { any } = {} -- the EditableMeshes stay referenced so their geometry isn't freed
```

### 3.6 The chunking architecture

This is the part that decides whether any of §3 works at all.

```
world  →  chunk grid (key = "cx_cz" or Vector3 for 3-D)
chunk  →  { mesh: EditableMesh, part: MeshPart, state, lastEdit, lod }
```

Rules, each earned from the constraint above it:

1. **Chunk size ≤ 100×100 cells** (the 20k-triangle cap, §3.1). Prefer 64.
2. **One MeshPart per chunk = one draw call per chunk.** Procedural chunks all have unique
   `MeshContent`, so Roblox's instancing never kicks in for them. Keep the *visible* chunk
   count in the low hundreds on desktop, ~64 on mobile.
3. **Skirts, not seam-matching.** At a chunk boundary, drop a vertical skirt of ~2 studs
   from the edge vertices instead of trying to match neighbouring LODs exactly. It hides
   T-junction cracks for free and costs `4 × size` triangles.
4. **LOD by chunk, not by vertex.** Rebuild a distant chunk at half resolution. Because
   rebuild is expensive, hysteresis is mandatory: only change LOD when the camera crosses a
   distance band by more than 20% of the band width.
5. **Pool everything.** Keep a free list of `MeshPart`s and of `EditableMesh`es. Creating
   an `EditableMesh` can fail (returns `nil`) under budget pressure — a pooled one cannot.
6. **A creation queue, not creation on demand.** One shipped project wraps this in a
   `Heartbeat`-drained ring buffer that hands out `EditableMesh`es as the budget allows
   [code, `cameronpcampbell/genesis`, `packages/utils/eMeshQueue`]:

```lua
self.Connection = RunService.Heartbeat:Connect(function()
    while true do
        DrainCancelled(self)
        if self.Queue:IsEmpty() then return end
        local eMesh = AssetService:CreateEditableMesh()
        if not eMesh then return end          -- budget exhausted: try again next frame
        local thread = self.Queue:Pop() :: thread
        coroutine.resume(thread, eMesh)
    end
end)
```

That `if not eMesh then return end` is the whole point. `CreateEditableMesh()` **returns
`nil`** when the device-specific budget is exhausted; it does not throw. Code that assumes
success crashes on mobile.

---

## 4. Voxel and marching-cubes worlds

### 4.1 Greedy meshing (blocky worlds)

The naive blocky mesher emits 12 triangles per solid voxel. A 32³ chunk of solid stone
would be 393,216 triangles — **20× over the cap**. Greedy meshing merges coplanar,
same-material faces into the largest possible rectangles, typically cutting triangle count
by 5–20×.

**Algorithm (the standard 6-sweep form).** For each of the 3 axes `d ∈ {0,1,2}` and each of
the 2 directions:

1. Let `u = (d+1)%3`, `v = (d+2)%3`. Sweep a slicing plane `x[d] = 0 … N`.
2. Build a 2-D **mask** over `(u, v)` for this slice: `mask[j][i] = material` if the voxel
   on the near side is solid and the one on the far side is not (i.e. this face is
   visible), else `0`.
3. Greedily consume the mask: scan for the first non-zero cell, extend **width** `w` along
   `u` while `mask` matches, then extend **height** `h` along `v` while the entire
   `w`-wide row matches. Emit one quad of size `w × h`. Zero out the consumed rectangle.
4. Repeat until the mask is empty; advance the slice.

```lua
--!strict
--!native
-- voxelAt(x,y,z) -> material id (0 = air). N = chunk side.
local function greedyMesh(N: number, voxelAt: (number, number, number) -> number, emitQuad)
    local dims = { N, N, N }
    for d = 0, 2 do
        local u, v = (d + 1) % 3, (d + 2) % 3
        local x = { 0, 0, 0 }
        local q = { 0, 0, 0 }; q[d + 1] = 1
        local mask = table.create(dims[u + 1] * dims[v + 1], 0)

        x[d + 1] = -1
        while x[d + 1] < dims[d + 1] do
            -- 2. build the mask for this slice
            local n = 1
            for j = 0, dims[v + 1] - 1 do
                for i = 0, dims[u + 1] - 1 do
                    x[u + 1], x[v + 1] = i, j
                    local a = if x[d + 1] >= 0 then voxelAt(x[1], x[2], x[3]) else 0
                    local b = if x[d + 1] < dims[d + 1] - 1
                        then voxelAt(x[1] + q[1], x[2] + q[2], x[3] + q[3]) else 0
                    -- a face exists only where exactly one side is solid;
                    -- sign encodes which way it points
                    if (a ~= 0) == (b ~= 0) then mask[n] = 0
                    elseif a ~= 0 then mask[n] = a
                    else mask[n] = -b end
                    n += 1
                end
            end

            x[d + 1] += 1

            -- 3. consume the mask greedily
            n = 1
            for j = 0, dims[v + 1] - 1 do
                local i = 0
                while i < dims[u + 1] do
                    local c = mask[n]
                    if c == 0 then i += 1; n += 1; continue end

                    local w = 1
                    while i + w < dims[u + 1] and mask[n + w] == c do w += 1 end

                    local h = 1
                    local done = false
                    while j + h < dims[v + 1] and not done do
                        for k = 0, w - 1 do
                            if mask[n + k + h * dims[u + 1]] ~= c then done = true break end
                        end
                        if not done then h += 1 end
                    end

                    x[u + 1], x[v + 1] = i, j
                    local du = { 0, 0, 0 }; du[u + 1] = w
                    local dv = { 0, 0, 0 }; dv[v + 1] = h
                    emitQuad(x, du, dv, c)          -- c < 0 means flip winding

                    for l = 0, h - 1 do
                        for k = 0, w - 1 do mask[n + k + l * dims[u + 1]] = 0 end
                    end
                    i += w; n += w
                end
            end
        end
    end
end
```

`emitQuad` then does `AddVertex ×4` + `AddTriangle ×2` — or, far better, accumulates into
arrays and issues **one** `BatchAdd(Enum.MeshAttribute.Vertex, …)` and one
`BatchAdd(Enum.MeshAttribute.Face, …)` at the end.

**The texturing catch.** A `w × h` merged quad needs UVs that tile `w` by `h`, which means
either a repeating texture (UV values > 1) or a texture atlas with per-face UV bounds. If
you need per-voxel texture variety, merge only within a material *and* within a
texture-variant id.

**Budget.** With greedy meshing, a 32³ chunk of typical terrain (caves, overhangs, a
surface) lands around 1,500–5,000 triangles — comfortably under the cap. A 16³ chunk lands
around 400–1,200. Reported community experience is that the *scan* (checking six faces of
4,096 blocks in a 16³ chunk) is itself noticeable in Luau [secondary] — which is the
argument for running the mask build in a parallel Actor and only the `Batch*` writes
serially.

### 4.2 Marching cubes (smooth voxel terrain)

**Algorithm.**

1. Sample a scalar density field at the 8 corners of each cell. Build an 8-bit
   `caseCode` where bit *i* is set if corner *i* is inside the surface.
2. `edgeTable[caseCode]` is a 12-bit mask of which of the cell's 12 edges are crossed.
3. For each crossed edge, place a vertex by **linear interpolation on the density**:
   `t = (iso - d0) / (d1 - d0)`, `p = lerp(c0, c1, t)`. (Using `t = 0.5` instead gives you
   *blocky* marching cubes — that's the difference between smooth and stair-stepped.)
4. `triTable[caseCode]` is a list of up to 15 edge indices (5 triangles), `-1`-terminated.
   Emit triangles from the interpolated edge vertices in that order.

The two tables are the well-known 256-entry `edgeTable` and 256×16 `triTable` from Paul
Bourke / Lorensen & Cline. They are pure data — transcribe them, don't derive them.

**Marching cubes' two real problems**, and why nobody ships plain MC:

- **Vertex duplication.** Each cell emits its own edge vertices, so every interior vertex
  is created 4–6 times. You must deduplicate by edge key (`cellIndex × 3 + axis`) or your
  vertex count explodes past 60,000 in a 32³ chunk.
- **Ambiguous cases.** Six of the 256 cases are topologically ambiguous; naive tables
  produce holes between adjacent cells. The fix is the extended 33-case table or
  **Transvoxel**, which additionally solves LOD seams.

### 4.3 Surface Nets (the one to actually use)

Surface Nets ("naive surface nets" / dual method) is simpler than MC, produces **one vertex
per cell** instead of up to 15, and is naturally watertight.

**Algorithm.**

1. For each cell, compute the 8 corner densities and the `caseCode`. Skip cells that are
   entirely inside or entirely outside.
2. For each of the 12 edges with a sign change, compute the interpolated crossing point.
3. Place the cell's single vertex at the **average of those crossing points**.
4. For each edge of the grid (not the cell) that has a sign change, emit a **quad** joining
   the vertices of the 4 cells sharing that edge. Winding follows the sign direction.

```lua
--!strict
--!native
local CORNER = {
    Vector3.new(0,0,0), Vector3.new(1,0,0), Vector3.new(1,0,1), Vector3.new(0,0,1),
    Vector3.new(0,1,0), Vector3.new(1,1,0), Vector3.new(1,1,1), Vector3.new(0,1,1),
}
local EDGE = { -- 12 edges as (cornerA, cornerB), 1-based
    {1,2},{2,3},{3,4},{4,1}, {5,6},{6,7},{7,8},{8,5}, {1,5},{2,6},{3,7},{4,8},
}

-- density(x,y,z) < 0 == inside. Returns vertex positions keyed by cell index.
local function surfaceNetVertices(N: number, density, iso: number)
    local verts: { [number]: Vector3 } = {}
    local d = table.create(8)
    for z = 0, N - 1 do for y = 0, N - 1 do for x = 0, N - 1 do
        local mask = 0
        for c = 1, 8 do
            local o = CORNER[c]
            d[c] = density(x + o.X, y + o.Y, z + o.Z) - iso
            if d[c] < 0 then mask = bit32.bor(mask, bit32.lshift(1, c - 1)) end
        end
        if mask ~= 0 and mask ~= 255 then
            local sum, n = Vector3.zero, 0
            for e = 1, 12 do
                local a, b = EDGE[e][1], EDGE[e][2]
                local da, db = d[a], d[b]
                if (da < 0) ~= (db < 0) then
                    local t = da / (da - db)
                    sum += CORNER[a]:Lerp(CORNER[b], t)
                    n += 1
                end
            end
            verts[(z * N + y) * N + x] = Vector3.new(x, y, z) + sum / n
        end
    end end end
    return verts
end
```

Then emit quads: for every grid edge along +X with a sign change between `(x,y,z)` and
`(x+1,y,z)`, join the cells `(x,y,z)`, `(x,y-1,z)`, `(x,y-1,z-1)`, `(x,y,z-1)` — and
similarly for +Y and +Z. Flip the winding when the sign goes the other way.

**Why this is the right default on Roblox:** one vertex per surface cell keeps you far
under the 60,000-vertex cap (a 32³ chunk has at most 32,768 cells and realistically a few
thousand *surface* cells), the mesh is manifold, and the vertex positions are
**independently movable** — which means a dig operation can *slide* existing vertices
rather than rebuilding topology, and that avoids a `CreateMeshPartAsync` call entirely for
small edits.

### 4.4 Dual Contouring (sharp features)

Surface Nets rounds every corner. Dual Contouring recovers hard edges by placing each
cell's vertex at the **QEF minimiser** instead of the crossing-point average: given the
crossing points `p_i` and the field **gradients** `n_i` there, minimise
`Σ (n_i · (x - p_i))²`. That is a 3×3 symmetric normal-equations solve; clamp the result
into the cell when the system is ill-conditioned.

An open-source Roblox implementation does exactly this, adaptively, on an octree, and
prints instrumented timings per stage [code, `MrChickenRocket/sdf-procedural-toolkit`,
`src/ReplicatedFirst/SdfMesher3.luau`]:

```
[SdfMesher3] leaves %d | %d→%d tris | octree %.0fms qef %.0fms dc %.0fms decimate %.0fms bake %.0fms total %.0fms
```

Its config carries `triCap = 40000` by default — **above the 20,000 engine cap**, which
means anything hitting that ceiling must be split across MeshParts. Worth knowing before
you copy a `triCap`.

Its bake path is the modern one and worth copying verbatim:

```lua
local res, content = AssetService:CreateDataModelContentAsync(Content.fromObject(em))
em:Destroy()                                    -- editable budget released immediately
if res ~= Enum.CreateContentResult.Success then return nil, tostring(res) end
local meshPart = AssetService:CreateMeshPartAsync(content, opts)
```

### 4.5 Transvoxel and chunk seams

Adjacent chunks at different LODs produce cracks, because the high-res side has vertices
the low-res side doesn't. Three fixes, in increasing order of quality and effort:

1. **Skirts.** Extend a curtain downward at every chunk boundary. Ugly from below, invisible
   from above, free. Use this unless you're shipping a voxel game as the core loop.
2. **Stitch band.** Force the outermost cell-ring of every chunk to the *coarsest* LOD in
   the neighbourhood. One extra ring of triangles, no cracks, slight detail loss at seams.
3. **Transvoxel.** Eric Lengyel's algorithm: a second set of "transition cell" tables that
   mesh a half-resolution face against a full-resolution one, exactly. This is what a
   shipped Roblox planet renderer uses — its tables are `regularCellClass`,
   `regularCellData`, `regularVertexData` (the canonical Transvoxel names)
   [code, `elokore/roblox-voxel-terrain`, `src/shared/Renderer/init.luau`].

That same renderer demonstrates the **incremental edit** pattern that avoids full rebuilds:
it keeps **one persistent `EditableMesh` per render area**, removes the faces of a changed
voxel with `RemoveFace`, recycles the freed vertex IDs, and time-slices at a fixed budget:

```lua
local VOXELS_RENDER_PER_FRAME: number = 500
...
if renderIsEmpty then
    self.State = "Idle"
    self._mesh:RemoveUnused()
    table.clear(self._recycleVertices)
    if not self._meshPart and self.GeometryContainer.FaceCount > 0 then
        task.defer(function()
            local part: MeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(self._mesh))
            ...
        end)
    end
end
```

Three things to steal: **500 voxels per frame**, `task.defer` for the `CreateMeshPartAsync`
so it lands outside the render path, and creating the `MeshPart` **once** — thereafter the
same `EditableMesh` object keeps rendering as it's edited.

### 4.6 What the triangle budget actually allows on Roblox

| Representation | Tris per 32³ chunk (typical terrain) | Chunks under the 20k cap |
|---|---|---|
| Naive per-voxel cubes | ~30,000–90,000 | **0** — over cap on its own |
| Greedy meshed blocks | ~1,500–5,000 | 4–13 chunks' worth per mesh |
| Marching cubes | ~8,000–20,000 | ~1 |
| Surface Nets | ~4,000–10,000 | ~2 |
| Dual Contouring + QEM decimation | ~1,000–4,000 | 5–20 |

Each chunk is its own draw call regardless. On mobile, a practical ceiling is roughly
**64 visible chunks**; on desktop, a few hundred. That, not the triangle cap, is usually
what limits view distance.

---

## 5. Procedural object generation

### 5.1 Trees — space colonization

Space colonization (Runions et al.) grows a skeleton toward a cloud of "attractor" points.
It produces much more natural branching than L-systems and is trivially art-directable by
shaping the attractor cloud.

**Algorithm.**

1. Scatter `M` attractors in the desired crown volume (an ellipsoid, a cone, a scanned
   silhouette).
2. Seed the skeleton with a root node and grow straight up until a node is within
   `attractionDist` of any attractor.
3. Each iteration: for every attractor, find its **nearest node** within `attractionDist`.
   Every node with at least one such attractor grows a child in the **normalised sum of
   directions** to those attractors, at a fixed `segmentLength`.
4. Delete any attractor now within `killDist` of a node.
5. Repeat until no growth happens or an iteration cap is hit.
6. Assign radii bottom-up with **da Vinci's rule**: `r_parent^n = Σ r_child^n`, with
   `n ≈ 2.05–3`.
7. Mesh: sweep a ring of `k` vertices along each branch with the parallel-transport frames
   of §5.5. Cap tips. Leaves are quads or cross-quads at terminal nodes.

```lua
--!strict
local function spaceColonize(attractors: { Vector3 }, root: Vector3,
                             segLen: number, attractDist: number, killDist: number,
                             maxIter: number)
    local nodes = { { pos = root, parent = 0, dir = Vector3.yAxis } }
    local alive = table.clone(attractors)

    for _ = 1, maxIter do
        local pull: { [number]: Vector3 } = {}
        local count: { [number]: number } = {}
        for ai = #alive, 1, -1 do
            local a = alive[ai]
            local best, bestD2 = 0, attractDist * attractDist
            for ni, nd in nodes do
                local d2 = (a - nd.pos).Magnitude ^ 2
                if d2 < bestD2 then best, bestD2 = ni, d2 end
            end
            if best > 0 then
                if math.sqrt(bestD2) < killDist then
                    table.remove(alive, ai)
                else
                    pull[best] = (pull[best] or Vector3.zero) + (a - nodes[best].pos).Unit
                    count[best] = (count[best] or 0) + 1
                end
            end
        end
        if next(pull) == nil then break end
        for ni, v in pull do
            local dir = (v / count[ni] + nodes[ni].dir * 0.35).Unit   -- 0.35 = trunk inertia
            table.insert(nodes, { pos = nodes[ni].pos + dir * segLen, parent = ni, dir = dir })
        end
    end
    return nodes
end
```

**Cost.** The inner loop is O(attractors × nodes) per iteration — fine for a few hundred
attractors, quadratic pain beyond. Put the nodes in a spatial hash if you go above ~1,000.
This is **build-time work**, not per-frame; generate on a background coroutine with a time
budget, or bake in Studio and upload.

### 5.2 Trees — L-systems

L-systems are better when you want *stylised, repeatable* plants (bamboo, ferns, alien
flora) and they cost almost nothing. Rewrite a string with production rules, then interpret
it with a turtle:

```lua
local RULES = { F = "FF", X = "F[+X][-X]FX" }   -- classic fractal plant
local function expand(axiom: string, n: number): string
    for _ = 1, n do
        local out = {}
        for i = 1, #axiom do
            local c = axiom:sub(i, i)
            table.insert(out, RULES[c] or c)
        end
        axiom = table.concat(out)
    end
    return axiom
end
-- turtle: 'F' forward+emit segment, '+'/'-' yaw, '&'/'^' pitch, '[' push, ']' pop CFrame
```

Add a small random jitter to every angle or every plant looks identical.

### 5.3 Rocks — displaced icospheres

```lua
local function makeRock(subdiv: number, seed: number, scale: Vector3): EditableMesh
    local em = AssetService:CreateEditableMesh()
    local verts, faces = icosphere(subdiv)          -- unit sphere, subdiv 2 -> 162 verts
    local rng = Random.new(seed)
    local ox, oy, oz = rng:NextNumber() * 100, rng:NextNumber() * 100, rng:NextNumber() * 100
    local pos = table.create(#verts)
    for i, v in verts do
        -- 3 octaves of fBm displacement along the radius
        local amp, freq, disp = 0.32, 1.4, 0.0
        for _ = 1, 3 do
            disp += math.noise(v.X * freq + ox, v.Y * freq + oy, v.Z * freq + oz) * amp
            amp *= 0.5; freq *= 2.1
        end
        -- flatten the bottom so it sits on the ground
        local r = 1 + disp
        local p = v * r * scale
        pos[i] = if p.Y < -scale.Y * 0.55 then Vector3.new(p.X, -scale.Y * 0.55, p.Z) else p
    end
    local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, pos)
    local tri = table.create(#faces)
    for i, f in faces do tri[i] = { vids[f[1]], vids[f[2]], vids[f[3]] } end
    em:BatchAdd(Enum.MeshAttribute.Face, tri)
    return em
end
```

Subdivision counts for an icosphere: 0→12 verts/20 tris, 1→42/80, 2→162/320, 3→642/1280,
4→2,562/5,120, 5→10,242/20,480 (**over the triangle cap**). Subdiv 3 is the sweet spot for
a hero rock; subdiv 1–2 for scatter.

Flat-shade the result for a low-poly look by giving every face its own three normals
(`AddNormal(nil)` auto-computes), or smooth-shade by sharing one normal per vertex. The
official `buildShapeMesh` sample shows the exact idiom [code, `stravant/roblox-materialflip`]:

```lua
function b.tri(self, v0, v1, v2, n0, n1, n2)
    local f = self.em:AddTriangle(v0, v1, v2)
    self.em:SetFaceNormals(f, {n0, n1 or n0, n2 or n0})
end
```

### 5.4 Buildings — floor plan → extrude → roof

1. **Plan** as a closed CCW polygon (rectangles for cheap, or a random rectilinear layout).
2. **Extrude** walls: for each polygon edge, emit a quad from `(p, q)` up to
   `(p + H·ŷ, q + H·ŷ)`. Emit both the outer face and (winding reversed, inset by wall
   thickness) the inner face if the interior is enterable.
3. **Punch openings** before triangulating: subtract door/window rectangles from each wall
   quad, producing 4 sub-quads around the hole (top / bottom / left / right).
4. **Floor and ceiling**: ear-clip the plan polygon.
5. **Roof**: for a hipped/gabled roof, compute the polygon's **straight skeleton** and lift
   ridge vertices by `inset × slope`. For the 95% case (rectangular footprint) just emit a
   gable directly: two quads meeting at a ridge line along the long axis, plus two triangles
   at the gable ends.

Budget one `EditableMesh` per *material group* (walls, roof, trim), not per building — that
minimises both draw calls and rebuild count. A mid-detail house lands at 400–1,500
triangles.

### 5.5 Roads, pipes and cables — sweeping with rotation-minimizing frames

The one algorithm everybody gets wrong. Naively computing a frame per point with
`CFrame.lookAt(p, p + tangent)` makes the ring **spin** around the curve wherever the
tangent passes near the up-vector, which twists the texture and creases the mesh.

**Double-reflection parallel transport** (Wang et al. 2008) is exact, cheap, and four lines:

```lua
--!strict
-- points: {Vector3}, tangents: {Vector3} (unit). Returns a reference vector per point
-- that never twists about the curve.
local function rotationMinimizingFrames(points: { Vector3 }, tangents: { Vector3 },
                                        seedRef: Vector3): { Vector3 }
    local refs = table.create(#points)
    -- seed: any unit vector perpendicular to tangents[1]
    local r = (seedRef - tangents[1] * seedRef:Dot(tangents[1]))
    refs[1] = if r.Magnitude > 1e-5 then r.Unit
              else tangents[1]:Cross(Vector3.xAxis).Unit

    for i = 1, #points - 1 do
        local v1 = points[i + 1] - points[i]
        local c1 = v1:Dot(v1)
        if c1 < 1e-12 then refs[i + 1] = refs[i]; continue end
        -- first reflection: reflect r_i and t_i across the plane of v1
        local rL = refs[i]     - v1 * (2 / c1) * v1:Dot(refs[i])
        local tL = tangents[i] - v1 * (2 / c1) * v1:Dot(tangents[i])
        -- second reflection: align tL with t_{i+1}
        local v2 = tangents[i + 1] - tL
        local c2 = v2:Dot(v2)
        refs[i + 1] = if c2 < 1e-12 then rL.Unit
                      else (rL - v2 * (2 / c2) * v2:Dot(rL)).Unit
    end
    return refs
end
```

With `refs[i]` in hand, the frame at point `i` is `(refs[i], tangents[i]:Cross(refs[i]),
tangents[i])` and the ring vertices are
`points[i] + refs[i]*cos(θ)*r + binormal*sin(θ)*r`.

**Tube along a spline:**

```lua
local function sweepTube(em: EditableMesh, points, tangents, radius: (number) -> number,
                         sides: number, closed: boolean)
    local refs = rotationMinimizingFrames(points, tangents, Vector3.yAxis)
    local rings = table.create(#points)
    local allPos = {}
    for i = 1, #points do
        local t, r = tangents[i], refs[i]
        local b = t:Cross(r)
        local rad = radius((i - 1) / (#points - 1))
        local ring = table.create(sides)
        for s = 0, sides - 1 do
            local a = (s / sides) * math.pi * 2
            table.insert(allPos, points[i] + (r * math.cos(a) + b * math.sin(a)) * rad)
            ring[s + 1] = #allPos
        end
        rings[i] = ring
    end
    local vids = em:BatchAdd(Enum.MeshAttribute.Vertex, allPos)
    local faces = {}
    for i = 1, #points - 1 do
        for s = 1, sides do
            local s2 = s % sides + 1
            local a, b = vids[rings[i][s]],     vids[rings[i][s2]]
            local c, d = vids[rings[i+1][s2]],  vids[rings[i+1][s]]
            table.insert(faces, { a, b, c })
            table.insert(faces, { a, c, d })
        end
    end
    em:BatchAdd(Enum.MeshAttribute.Face, faces)
end
```

**Cost:** `sides × segments` vertices, `2 × sides × segments` triangles. A 12-sided pipe
with 60 segments is 720 verts / 1,440 tris — you can fit 13 such pipes in one
`EditableMesh`, which is exactly what you should do: **batch many pipes into one mesh** to
collapse draw calls.

### 5.6 Roads and paths — polyline → ribbon with correct joins

A road is the 2-D special case, and the interesting part is the **join**. At an interior
vertex, offsetting both incoming and outgoing edges by `w` and intersecting gives the miter
point:

```lua
-- Returns the left/right offset points at an interior polyline vertex.
local function miterOffsets(prev: Vector3, cur: Vector3, nxt: Vector3, w: number)
    local d1 = (cur - prev).Unit
    local d2 = (nxt - cur).Unit
    local n1 = Vector3.new(-d1.Z, 0, d1.X)      -- left normal (flat road)
    local n2 = Vector3.new(-d2.Z, 0, d2.X)
    local m = (n1 + n2)
    if m.Magnitude < 1e-5 then return cur + n1 * w, cur - n1 * w end   -- 180° hairpin
    m = m.Unit
    local scale = w / math.max(m:Dot(n1), 0.2)   -- clamp: prevents infinite spikes
    return cur + m * scale, cur - m * scale
end
```

The `math.max(..., 0.2)` clamp is the **miter limit**. Without it a sharp turn produces a
vertex hundreds of studs away. When the limit trips, fall back to a **bevel** join: emit
both offset points and a triangle between them.

A simple production version of the whole ribbon (road with thickness, closed ends) is in
`ddavness/curve`, `dev/mkmesh.luau` [code] — it walks a list of `CFrame`s and emits top,
bottom, and both side quads per segment.

Genres: racing tracks, city generators, hiking-trail games, pipe-networks in factory games,
power lines, tentacles (§6.6), and any "draw a path, get geometry" builder tool.

### 5.7 Fences, walls and modular kit assembly

The general **modular kit** pattern beats bespoke generation for anything repetitive:

1. Author a handful of kit pieces (post, rail, corner, gate) as ordinary meshes, or
   generate each once at startup into an `EditableMesh`.
2. To place a run: for each segment, **append the piece's transformed geometry into one
   shared output `EditableMesh`**. Keep appending until you approach 50,000 verts / 17,000
   tris, then flush to a MeshPart and start a new one.
3. That gives you one draw call per ~17k triangles of fence instead of one per post.

```lua
local function appendPiece(dst: EditableMesh, src: { pos: { Vector3 }, tri: { { number } } },
                           cf: CFrame, out: { Vector3 }, outTri: { { number } }, base: number)
    for _, p in src.pos do table.insert(out, cf:PointToWorldSpace(p)) end
    for _, t in src.tri do
        table.insert(outTri, { base + t[1], base + t[2], base + t[3] })
    end
    return base + #src.pos
end
```

Note the tradeoff: merging kills instancing-by-`MeshContent`, but procedurally generated
meshes never got instancing anyway, and it kills the *per-part* overhead (physics, culling,
streaming) which is usually the larger cost for hundreds of small objects.

---

## 6. Dynamic surfaces

### 6.1 Water — Gerstner waves

Gerstner (trochoidal) waves displace **horizontally as well as vertically**, which is what
gives crests their sharp peaks and broad troughs. Sine waves cannot do that.

```lua
--!strict
--!native
export type GerstnerWave = {
    dir: Vector2, amplitude: number, steepness: number,
    waveLength: number, speed: number, phase: number,
}

local function gerstner(waves: { GerstnerWave }, x: number, z: number, t: number)
    local px, py, pz = x, 0.0, z
    -- also accumulate the analytic normal via partial derivatives
    local dx, dz = Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
    for _, w in waves do
        local k = 2 * math.pi / w.waveLength
        local c = w.speed
        local f = k * (w.dir.X * x + w.dir.Y * z) - c * t + w.phase
        local a = w.steepness / k
        local cosf, sinf = math.cos(f), math.sin(f)
        px += w.dir.X * a * cosf
        pz += w.dir.Y * a * cosf
        py += a * sinf
        local wa = w.steepness * sinf
        local wb = w.steepness * cosf
        dx += Vector3.new(-w.dir.X * w.dir.X * wa, w.dir.X * wb, -w.dir.X * w.dir.Y * wa)
        dz += Vector3.new(-w.dir.X * w.dir.Y * wa, w.dir.Y * wb, -w.dir.Y * w.dir.Y * wa)
    end
    return Vector3.new(px, py, pz), dz:Cross(dx).Unit
end
```

**Steepness must be budgeted**: `Σ steepness ≤ 1` across all waves, or the surface
self-intersects into visible loops. Use `steepness_i = S / (k_i · A_count)`.

**Shipped numbers.** A Roblox team reports an EditableMesh ocean running at **~2 ms with 12
Gerstner waves** and a custom water shader [secondary]. Another public ocean project cites
multithreading, frustum culling, and **vertex lerping where distant vertices are not
updated every frame** [secondary]. A third uses a *checkerboard* update — half the vertices
on even frames, half on odd — halving the per-frame cost for a barely-visible artifact
[secondary].

**The optimisation ladder for water, in the order you should apply it:**

1. **Clipmap rings**: dense grid near the camera, coarser rings outward, flat parts at the
   horizon. A shipped renderer caps the near field at `MAX_INITIAL_VERTICES = 12000` and
   the horizon at `MAX_HORIZON_OBJECTS = 64` plain Parts [code, `ng643/Mythic`].
2. **Follow the camera in grid steps**: snap the mesh's CFrame to `floor(camXZ / spacing) *
   spacing` so vertices never need to move to "scroll" the ocean.
3. **`BatchSetValues` for positions and normals**, two calls per frame, never per-vertex.
4. **Skip normals entirely** if you can live with a flat-shaded or texture-driven look —
   that halves the writes.
5. **Checkerboard / distance-banded update rates.**
6. **Never rebuild.** Water has no useful collision mesh; do buoyancy analytically by
   evaluating the same Gerstner function at the boat's position.

### 6.2 Cloth, banners and flags

Verlet cloth is the right simulation: positions only, no velocities, unconditionally stable
constraints.

```lua
--!strict
--!native
-- p, prev: {Vector3}; pinned: {[number]: true}; links: {{a,b,restLen}}
local GRAVITY = Vector3.new(0, -60, 0)

local function clothStep(p, prev, pinned, links, wind: Vector3, dt: number, iters: number)
    local dt2 = dt * dt
    for i = 1, #p do
        if pinned[i] then continue end
        local cur = p[i]
        p[i] = cur + (cur - prev[i]) * 0.985 + (GRAVITY + wind) * dt2
        prev[i] = cur
    end
    for _ = 1, iters do                       -- 3-6 is plenty
        for _, l in links do
            local a, b, rest = l[1], l[2], l[3]
            local delta = p[b] - p[a]
            local d = delta.Magnitude
            if d < 1e-6 then continue end
            local corr = delta * ((d - rest) / d * 0.5)
            if not pinned[a] then p[a] += corr end
            if not pinned[b] then p[b] -= corr end
        end
    end
end
```

Link set: structural (grid neighbours), shear (diagonals), and bend (2-apart) — bend links
are what stop a flag folding into a pancake. Then one `BatchSetValues`.

A 16×24 flag is 384 vertices, 690 triangles, ~1,150 links. Six constraint iterations is
~7k vector ops per frame — trivial. **Wind should be `dot(faceNormal, windDir)`-weighted**
so the cloth catches the wind rather than being uniformly pushed; recompute face normals
every few frames, not every frame.

Genres: medieval/fantasy (banners), sailing games, capture-the-flag, superhero capes,
horror (curtains), fashion/dress-up.

### 6.3 Soft bodies

Shape-matching soft bodies are far more stable than pure spring lattices: each frame,
compute the optimal rigid transform between the rest particle cloud and the current one,
then pull particles toward their rest positions *under that transform* by a stiffness
factor. That gives a blob that deforms but always wants its shape back.

The mesh side is §0.1's pattern verbatim: keep the `MeshPart.CFrame` at the centre of mass
and write local positions. `plirt/Softbody-physics` does exactly this on an icosphere
[code].

### 6.4 Ropes and cables

For a *visual* rope, don't simulate a mesh — simulate a polyline (Verlet, 12–24 nodes) and
re-sweep the tube (§5.5) each frame onto a **fixed-topology** `EditableMesh`. Fixed topology
means one `BatchSetValues` per frame and zero rebuilds. 12 nodes × 8 sides = 96 vertices.

Hanging cables that never move should just use the **catenary** closed form:
`y = a·cosh((x - x0)/a) + c`, solved for `a` by Newton iteration against the desired
slack — then meshed once and never touched.

### 6.5 Tentacles and creature limbs

Same tube sweep, but drive the spine with **FABRIK** (forward-and-backward reaching inverse
kinematics) so the tip follows a target while segment lengths stay constant. Vary the
radius along the parameter (`radius(t) = R * (1 - t)^0.7`) for taper. Add a travelling
sine on the spine's binormal for idle motion.

### 6.6 Blobs and metaballs

Metaballs are a density field, so §4.3's Surface Nets meshes them directly:

```lua
local function metaballField(balls: { { pos: Vector3, r: number } })
    return function(x: number, y: number, z: number): number
        local p, sum = Vector3.new(x, y, z), 0.0
        for _, b in balls do
            local d2 = (p - b.pos).Magnitude ^ 2
            local r2 = b.r * b.r
            if d2 < r2 then
                local t = 1 - d2 / r2
                sum += t * t * t          -- Wyvill falloff: C2, compact support
            end
        end
        return 0.5 - sum                  -- < 0 inside
    end
end
```

Restrict the sampling grid to the union of the balls' bounding boxes — that is the entire
performance story. With 8 balls on a 24³ local grid, you get a smooth blob in a few
thousand field evaluations. Rebuild at a fixed rate (10 Hz) rather than per frame, and
accept the pop; nobody notices on a liquid blob.

Genres: slime/ooze enemies, liquid tycoons, lava, magic effects, alien biology, WebGL-style
water toys. (A public port of "WebGL Water" to Roblox `EditableMesh` exists —
`Y-Workplace/Liquid-Simulation` [code].)

---

## 7. Character and creature work

### 7.1 Does `EditableMesh` support skinning? — Yes, verified

The current reference lists a complete skinning and facial-animation surface:

| Area | Methods |
|---|---|
| Bones | `AddBone(props)`, `RemoveBone`, `GetBones`, `GetBoneByName`, `GetBoneName`/`SetBoneName`, `GetBoneCFrame`/`SetBoneCFrame`, `GetBoneParent`/`SetBoneParent`, `GetBoneIsVirtual`/`SetBoneIsVirtual` |
| Skin weights | `GetVertexBones`/`SetVertexBones`, `GetVertexBoneWeights`/`SetVertexBoneWeights` |
| FACS | `GetFacsPoses`, `GetFacsPose(actionUnit)`, `SetFacsPose(actionUnit, boneIds, cframes)`, `SetFacsBonePose`, `GetFacsCorrectivePoses`, `GetFacsCorrectivePose`, `SetFacsCorrectivePose` |

`AddBone` takes `{ Name, ParentId, CFrame, Virtual }`; names must be unique, ≤100
characters. `SetVertexBoneWeights` must be called **after** `SetVertexBones` and the arrays
are index-parallel. Roblox's own art spec caps a vertex at **4 bone influences**.

Two documented limitations to design around:

- **Queries use the bind pose.** `RaycastLocal`, `FindClosestPointOnSurface` and
  `FindVerticesWithinSphere` all state: *"When the mesh is skinned, this query operates
  against the bind-pose geometry, not the deformed mesh as it appears at runtime."* So you
  cannot hit-test a running character's *animated* silhouette with `RaycastLocal` — use
  real world-space raycasts against the `MeshPart` for that.
- **Corrective FACS poses cannot mix left and right action units.** The docs name
  `LeftCheekPuff` + `RightEyeClosed` as an example of a combination that *"is not currently
  possible"*.

### 7.2 Morph targets / blendshapes by hand

Roblox has no blendshape primitive. You implement one by lerping between vertex sets:

```lua
--!strict
export type MorphRig = {
    mesh: EditableMesh,
    ids: { number },
    base: { Vector3 },
    targets: { [string]: { Vector3 } },   -- absolute positions, same order as ids
    scratch: { Vector3 },
}

local function applyMorphs(rig: MorphRig, weights: { [string]: number })
    local base, out = rig.base, rig.scratch
    for i = 1, #base do out[i] = base[i] end
    for name, w in weights do
        if w == 0 then continue end
        local t = rig.targets[name]
        if not t then continue end
        for i = 1, #out do
            out[i] = out[i] + (t[i] - base[i]) * w     -- additive deltas: stackable
        end
    end
    rig.mesh:BatchSetValues(rig.ids, out)
end
```

Store targets as **deltas**, not absolutes, if memory matters — and note that additive
delta blending is what lets "smile 0.7" and "angry 0.4" compose. Because the vertex order
must match across targets, build every target by *editing a copy of the base*, never by
importing separately-authored meshes (their vertex order will differ).

**Cost:** O(V × activeTargets) per update. A 2,000-vertex head with 4 active morphs is 8,000
Vector3 lerps — run it only when a weight actually changes, not every frame.

### 7.3 Body-shape customization sliders — the official path

Roblox documents a specific supported pipeline for avatar body editing, and it is **not**
"edit the render mesh". It is `WrapDeformer` + an `EditableMesh` of the **cage**:

```lua
-- Roblox/creator-docs, content/en-us/avatar/in-experience-creation.md
local function deformBodyPart(meshPart: MeshPart, controlPointCenter: Vector3,
                              controlPointRadius: number, controlPointDeformation: Vector3)
    local wrapTarget = meshPart:FindFirstChildWhichIsA("WrapTarget")
    local cageMeshId = wrapTarget.CageMeshId
    local wrapDeformer = Instance.new("WrapDeformer")
    wrapDeformer.Parent = meshPart

    local cageEditableMesh = AssetService:CreateEditableMeshAsync(cageMeshId)
    local verticesWithinSphere =
        cageEditableMesh:FindVerticesWithinSphere(controlPointCenter, controlPointRadius)
    for _, vertexId in verticesWithinSphere do
        local vertexPosition = cageEditableMesh:GetPosition(vertexId)
        cageEditableMesh:SetPosition(vertexId, vertexPosition + controlPointDeformation)
    end
    wrapDeformer:SetCageMeshContent(Content.fromObject(cageEditableMesh))
end
```

Why this matters: **`WrapDeformer` preserves skinning and FACS data through the edit**.
Deforming the render mesh directly would destroy the rig. The cage is low-poly, so
`FindVerticesWithinSphere` touches tens of vertices, and a slider drag is genuinely cheap.

The setup step in the same document also shows the required rigid-mesh path and the
`FixedSize = true` default:

```lua
local editableMesh = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId),
    { FixedSize = true })
local newMeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
newMeshPart.Size = meshPart.Size
newMeshPart.CFrame = meshPart.CFrame
newMeshPart.TextureContent = meshPart.TextureContent
meshPart:ApplyMesh(newMeshPart)
```

Genres: avatar-creation experiences, character creators in RPGs, UGC design tools,
dress-up/fashion.

### 7.4 Growth and evolution

Growth is morph targets plus a scale curve plus, occasionally, topology. Rules that keep it
cheap:

- **Scale, don't re-mesh.** A creature that doubles in size is a `MeshPart.Size` change (or
  a uniform vertex scale) — no rebuild, no new geometry.
- **Morph between life stages.** Author "larva", "juvenile", "adult" as vertex sets with
  identical topology and lerp. Continuous, free, and animators can author it.
- **Add topology only at discrete evolution events**, and pay one rebuild there. Growing a
  new limb means splicing a new tube (§5.5) into the mesh — do it during the evolution VFX
  flash, which hides the hitch.

### 7.5 The mesh-space scale-factor gotcha

Roblox's own avatar sample documents a trap that costs people hours: `EditableMesh`
coordinates are in the mesh's **object space**, which is *not* the same scale as
`MeshPart.Size`. Converting between them requires a per-mesh scale factor
[code, `Roblox/avatar`, `ReferenceBodyCreator/.../MeshUtils.lua`]:

```lua
function MeshUtils.GetScaleFactor(meshPart, vertexPositions)
    local min, max = MeshUtils.GetVertexBounds(vertexPositions)
    local editableMeshSize = max - min
    return editableMeshSize / meshPart.Size
end
```

Any raycast you do in world space must be converted into mesh space **and scaled** before
`RaycastLocal`, and the hit point scaled back on the way out.

---

## 8. Trails, ribbons and effects geometry

`Beam` and `Trail` are cheaper than `EditableMesh` and you should use them by default.
Reach for geometry when you need what they structurally cannot express: **a ribbon with
real width variation along an arbitrary 3-D path**, **a surface that isn't a flat strip**,
**per-vertex colour**, **branching**, or **a shape that persists and can be hit-tested**.

### 8.1 Sword trails (the swept-quad ribbon)

The correct sword trail is not a camera-facing strip; it is the **swept surface between the
blade's tip and hilt** over time. Sample both each frame and stitch:

```lua
--!strict
local SEGMENTS = 24                    -- ring buffer length
local trail = { tip = {}, base = {}, head = 0, count = 0 }

-- Fixed topology: SEGMENTS*2 verts, (SEGMENTS-1)*2 tris. Built ONCE.
local function buildTrailMesh(em: EditableMesh)
    local pos = table.create(SEGMENTS * 2, Vector3.zero)
    local ids = em:BatchAdd(Enum.MeshAttribute.Vertex, pos)
    local faces = {}
    for i = 1, SEGMENTS - 1 do
        local a, b = ids[i * 2 - 1], ids[i * 2]
        local c, d = ids[i * 2 + 1], ids[i * 2 + 2]
        table.insert(faces, { a, b, d })
        table.insert(faces, { a, d, c })
    end
    em:BatchAdd(Enum.MeshAttribute.Face, faces)
    return ids
end

local function pushSample(em: EditableMesh, ids, tipW: Vector3, baseW: Vector3, partCF: CFrame)
    trail.head = trail.head % SEGMENTS + 1
    trail.tip[trail.head]  = partCF:PointToObjectSpace(tipW)
    trail.base[trail.head] = partCF:PointToObjectSpace(baseW)
    trail.count = math.min(trail.count + 1, SEGMENTS)

    local out = table.create(SEGMENTS * 2)
    for i = 1, SEGMENTS do
        local k = (trail.head - i) % SEGMENTS + 1
        local valid = i <= trail.count
        out[i * 2 - 1] = if valid then trail.base[k] else trail.base[trail.head]
        out[i * 2]     = if valid then trail.tip[k]  else trail.base[trail.head]
    end
    em:BatchSetValues(ids, out)
end
```

Fade with **vertex alpha**, not transparency: `BatchSetValues(colorIds, alphas)` where
`alphas` is an array of numbers (the docs explicitly allow a number array for colour IDs to
set alpha). Newest segment alpha 1, oldest 0. Set `MeshPart.Transparency` to a small
epsilon (e.g. `0.02`) to force the translucent render queue — a trick a shipped renderer
uses precisely because the opaque queue alpha-*tests* instead of blending
[code, `turtlesoupy/robloquake`].

**Cost: zero rebuilds, 48 vertices, one `BatchSetValues` per frame.** This is the cheapest
non-trivial EditableMesh technique in the chapter and it looks dramatically better than a
`Trail`.

### 8.2 Motion ribbons and projectile paths

Same ring buffer, but the "base" samples come from a fixed offset rather than a second
attachment, and the ribbon is oriented by §5.5's rotation-minimizing frames so it doesn't
flip when the projectile loops. For a homing missile's smoke ribbon, widen with age:
`width(t) = w0 + (w1 - w0) * t` and taper alpha with the same `t`.

### 8.3 Force fields, shields and portals

- **Force field**: an icosphere (§5.3, subdiv 3 = 1,280 tris) with `DoubleSided = true`,
  vertex colour driven by `abs(dot(vertexNormal, toCamera))` for a Fresnel rim, and a small
  radial noise displacement that ripples outward from hit points:
  `r = R + Σ hits A·sin(k·(d - c·t))·exp(-λ(t - t_hit))`.
- **Portal**: a disc of `N` ring segments; animate the rim vertices with a rotating
  multi-frequency sine for the "liquid edge" look, and keep the interior flat with an
  `EditableImage` texture doing the actual portal render.
- **Shield impact**: hexagonal tessellation instead of a triangulated sphere — build the
  hexes as separate face groups so you can pop individual cells' alpha on hit.

### 8.4 What genuinely cannot be done with `Beam`/`Trail`

Branching lightning (a tree of ribbons meeting at forks), a slash that leaves a
**hit-testable** surface behind, ribbons whose cross-section is not a flat quad (a
twisting flat *tape* needs real frames), ground-decal geometry that conforms to uneven
terrain, and anything needing per-vertex colour gradients across the width as well as the
length.

---

## 9. Utility and debug geometry

A debug-draw library is the highest return-on-investment thing in this chapter, because it
makes every *other* system in your game debuggable. The design that works: **one persistent
`EditableMesh` per draw category, rebuilt-free, with a fixed vertex pool and an immediate-mode
API.**

### 9.1 The immediate-mode debug-draw core

```lua
--!strict
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local MAX_TRIS = 16000
local MAX_VERTS = MAX_TRIS * 3

local DebugDraw = {}
local em: EditableMesh, part: MeshPart
local vids: { number }, cids: { number }
local posBuf: { Vector3 }, colBuf: { Color3 }, alphaBuf: { number }
local cursor = 0

function DebugDraw.init()
    em = AssetService:CreateEditableMesh()
    assert(em, "editable mesh budget exhausted")
    posBuf = table.create(MAX_VERTS, Vector3.zero)
    colBuf = table.create(MAX_VERTS, Color3.new(1, 1, 1))
    alphaBuf = table.create(MAX_VERTS, 0)
    vids = em:BatchAdd(Enum.MeshAttribute.Vertex, posBuf)
    cids = em:BatchAdd(Enum.MeshAttribute.Color, colBuf, alphaBuf)
    local faces, fcols = {}, {}
    for i = 1, MAX_TRIS do
        local a, b, c = vids[i*3-2], vids[i*3-1], vids[i*3]
        faces[i] = { a, b, c }
        fcols[i] = { cids[i*3-2], cids[i*3-1], cids[i*3] }
    end
    local fids = em:BatchAdd(Enum.MeshAttribute.Face, faces)
    em:BatchSetFaceAttributes(fids, fcols)

    part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
        RenderFidelity = Enum.RenderFidelity.Precise,
    })
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.CastShadow = false
    part.Transparency = 0.02             -- force the translucent queue
    part.DoubleSided = true
    part.Material = Enum.Material.Neon
    part.Size = Vector3.one              -- geometry is authored in world units
    part.CFrame = CFrame.identity
    part.Parent = workspace
end

local function tri(a: Vector3, b: Vector3, c: Vector3, col: Color3, alpha: number)
    if cursor + 3 > MAX_VERTS then return end
    posBuf[cursor+1], posBuf[cursor+2], posBuf[cursor+3] = a, b, c
    colBuf[cursor+1], colBuf[cursor+2], colBuf[cursor+3] = col, col, col
    alphaBuf[cursor+1], alphaBuf[cursor+2], alphaBuf[cursor+3] = alpha, alpha, alpha
    cursor += 3
end

-- A "line" is a screen-facing quad of a fixed world thickness.
function DebugDraw.line(a: Vector3, b: Vector3, col: Color3, thickness: number?)
    local w = (thickness or 0.08) * 0.5
    local d = b - a
    if d.Magnitude < 1e-5 then return end
    local up = if math.abs(d.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
    local side = d.Unit:Cross(up).Unit * w
    tri(a - side, a + side, b + side, col, 1)
    tri(a - side, b + side, b - side, col, 1)
end

function DebugDraw.box(cf: CFrame, size: Vector3, col: Color3)
    local h = size * 0.5
    local c = {}
    for i = 0, 7 do
        c[i+1] = cf:PointToWorldSpace(Vector3.new(
            if bit32.band(i,1)==0 then -h.X else h.X,
            if bit32.band(i,2)==0 then -h.Y else h.Y,
            if bit32.band(i,4)==0 then -h.Z else h.Z))
    end
    local E = {{1,2},{3,4},{5,6},{7,8},{1,3},{2,4},{5,7},{6,8},{1,5},{2,6},{3,7},{4,8}}
    for _, e in E do DebugDraw.line(c[e[1]], c[e[2]], col) end
end

-- Call at the END of every frame's debug drawing.
function DebugDraw.flush()
    for i = cursor + 1, MAX_VERTS do
        posBuf[i] = Vector3.zero          -- collapse unused tris to degenerate
        alphaBuf[i] = 0
    end
    em:BatchSetValues(vids, posBuf)
    em:BatchSetValues(cids, colBuf)
    em:BatchSetValues(cids, alphaBuf)     -- number array sets alpha
    cursor = 0
end

RunService.Heartbeat:Connect(DebugDraw.flush)
return DebugDraw
```

**Why this design.** Topology is allocated once and never changes, so there is **never a
`CreateMeshPartAsync` call after init**. Unused triangles are collapsed to a point
(degenerate = not rasterised). One mesh = one draw call for your entire debug overlay,
versus hundreds of Parts. `Material = Neon` makes it readable against any scene.

### 9.2 Built on that core

- **Wireframe of any mesh**: for every face, three `DebugDraw.line` calls between
  `GetPosition(GetFaceVertices(fid)[k])`. For a 5,000-tri mesh that's 15,000 lines =
  30,000 debug triangles — over budget, so wireframe only a *selection* or use a second
  mesh dedicated to it.
- **Normals**: `line(p, p + normal * 0.5, Color3.new(0,0,1))` per face-corner. Tangent
  visualisation needs the UV-derived tangent (§10.5).
- **Hitboxes and collisions**: `DebugDraw.box(part.CFrame, part.Size, col)` over a query
  result set. For `OverlapParams` debugging, draw the query volume in one colour and each
  hit in another.
- **Spatial partitions**: recursively draw octree/quadtree node bounds with per-depth
  colour. This is where the one-mesh design pays — a 4-level octree is thousands of boxes.
- **Graphs and node networks in 3-D**: nodes as small icospheres (subdiv 0, 20 tris),
  edges as lines, and **arrowheads** as a 6-triangle cone for directed edges. Invaluable
  for pathfinding, dialogue trees, quest DAGs, factory belt networks.
- **Persistent vs transient**: keep two meshes. One flushed every frame (`DebugDraw`
  above), one append-only for things you want to *accumulate* (a bullet's whole flight
  path, every position an NPC has stood in).

### 9.3 Ship it disabled

Guard `init()` behind a flag, and behind `RunService:IsStudio()` or an attribute, because
that persistent 48,000-vertex mesh holds real editable budget. `Destroy()` it when the flag
turns off — don't rely on GC (§"budget refunds take 15–25 s", below).

---

## 10. Mesh analysis and repair

### 10.1 Reading an existing asset

```lua
local ok, em = pcall(function()
    return AssetService:CreateEditableMeshAsync(Content.fromAssetId(ASSET_ID))
end)
-- or from a live part, which is usually what you want:
local em2 = AssetService:CreateEditableMeshAsync(meshPart.MeshContent)
em2:Triangulate()   -- docs: currently a no-op, but recommended after CreateEditableMeshAsync
```

Two rules, both documented. **Permissions:** `CreateEditableMeshAsync` only loads an asset
owned by / shared with the game owner, the Studio user, or (client-side) the logged-in
player — otherwise it throws. And the whole API fails by default in published games until
the creator is 13+ **and** ID-verified **and** has toggled *Enable Mesh / Image APIs* on the
Creator Dashboard. **Meshes read this way are `FixedSize` by default** — you can move
vertices but not add or remove them. Pass `{ FixedSize = false }` if you need topology
edits, and accept the ~2.8 MB worst-case budget charge.

### 10.2 Bounds, surface area and volume

```lua
local function analyse(em: EditableMesh)
    local center, size = em:GetCenter(), em:GetSize()   -- both O(1), from the engine
    local area, vol = 0.0, 0.0
    local faces = em:GetFaces()
    for _, fid in faces do
        local v = em:GetFaceVertices(fid)
        local a = em:GetPosition(v[1])
        local b = em:GetPosition(v[2])
        local c = em:GetPosition(v[3])
        local cross = (b - a):Cross(c - a)
        area += cross.Magnitude * 0.5
        -- signed tetrahedron volume with the origin (divergence theorem).
        -- Correct only for a closed, consistently-wound manifold.
        vol += a:Dot(b:Cross(c)) / 6
    end
    return { center = center, size = size, area = area,
             volume = math.abs(vol), triangles = #faces }
end
```

`GetCenter()` returns the **bounding-box centre**, not the centroid, and `GetSize()` the
bounding-box dimensions — both documented that way, both `thread_safety: Safe`. Uses:
buoyancy from volume, damage scaling from surface area, auto-sizing prompts and
`ProximityPrompt` offsets from bounds, procedural mass.

### 10.3 Degenerate triangle detection

```lua
local function findDegenerate(em: EditableMesh, areaEps: number, edgeEps: number)
    local bad = {}
    for _, fid in em:GetFaces() do
        local v = em:GetFaceVertices(fid)
        local a, b, c = em:GetPosition(v[1]), em:GetPosition(v[2]), em:GetPosition(v[3])
        local ab, ac = b - a, c - a
        local twiceArea = ab:Cross(ac).Magnitude
        local dup = v[1] == v[2] or v[2] == v[3] or v[1] == v[3]
        local tiny = ab.Magnitude < edgeEps or ac.Magnitude < edgeEps
                     or (c - b).Magnitude < edgeEps
        if dup or tiny or twiceArea * 0.5 < areaEps then
            table.insert(bad, fid)
        end
    end
    return bad
end
```

Degenerates matter because they produce NaN normals, break tangent generation, and
(critically) **`CreateEditableMeshAsync` silently culls zero-area triangles when it makes a
FixedSize copy** — production code documents a batch that passed a face-count guard on the
dynamic mesh and then copied to an *empty* mesh, which `CreateMeshPartAsync` then rejected
[code, `turtlesoupy/robloquake`]. Check the face count **after** the copy, not before.

`MergeVertices(tolerance)` is the engine's welding pass: it merges vertices that touch to a
single vertex ID *while keeping the other attribute IDs*, and returns an old→new ID map.
Run it, then `RemoveUnused()`, then re-check for degenerates — welding creates them.

### 10.4 Recomputing normals — the area-weighted formula

The correct smooth normal at a vertex is the **area-weighted** (equivalently,
cross-product-magnitude-weighted) sum of adjacent face normals:

```
n_v  =  normalize( Σ_{f ∈ faces(v)}  (b_f − a_f) × (c_f − a_f) )
```

The un-normalised cross product's magnitude is exactly `2 × area`, so summing the raw
crosses *is* area weighting — you do not multiply by anything. (Angle weighting, which
weights by the interior angle at `v`, is the alternative and is better for meshes with
wildly uneven triangle sizes; area weighting is standard and matches most DCC tools.)

```lua
local function recomputeNormals(em: EditableMesh, smoothAngleDeg: number)
    local cosLimit = math.cos(math.rad(smoothAngleDeg))
    local accum: { [number]: Vector3 } = {}
    local faceN: { [number]: Vector3 } = {}

    for _, fid in em:GetFaces() do
        local v = em:GetFaceVertices(fid)
        local a, b, c = em:GetPosition(v[1]), em:GetPosition(v[2]), em:GetPosition(v[3])
        local cross = (b - a):Cross(c - a)          -- magnitude == 2*area
        faceN[fid] = cross
        for k = 1, 3 do
            accum[v[k]] = (accum[v[k]] or Vector3.zero) + cross
        end
    end

    -- Split at hard edges: a corner uses the smooth normal only if the face
    -- normal agrees with it; otherwise it keeps the flat face normal.
    local vertexIds, faceIds, normalIds = {}, {}, {}
    for fid, cross in faceN do
        local fn = if cross.Magnitude > 1e-9 then cross.Unit else Vector3.yAxis
        for _, vid in em:GetFaceVertices(fid) do
            local s = accum[vid]
            local sn = if s.Magnitude > 1e-9 then s.Unit else fn
            local n = if fn:Dot(sn) >= cosLimit then sn else fn
            table.insert(vertexIds, vid)
            table.insert(faceIds, fid)
            table.insert(normalIds, em:AddNormal(n))
        end
    end
    em:BatchSetVertexFaceAttributes(vertexIds, faceIds, normalIds)
end
```

`BatchSetVertexFaceAttributes(vertexIds, faceIds, attrIds)` is the right call here — it
sets the attribute at each `(vertex, face)` **corner**, which is precisely the split-normal
model `EditableMesh` uses. Alternatively `AddNormal(nil)` lets the engine auto-compute, and
`ResetNormal(id)` / `BatchSetValues(normalIds, nil)` reverts to auto-computed.

### 10.5 UV inspection and tangents

UVs live per corner. To audit them:

```lua
local faces = em:GetFaces()
local uvSets = em:BatchGetFaceAttributes(Enum.MeshAttribute.UV, faces)
for i, fid in faces do
    local ids = uvSets[i]
    local a, b, c = em:GetUV(ids[1]), em:GetUV(ids[2]), em:GetUV(ids[3])
    -- signed UV area: negative means a mirrored/flipped island
    local uvArea = ((b - a).X * (c - a).Y - (b - a).Y * (c - a).X) * 0.5
    -- texel density: 3D area per UV area. Wildly varying values = stretching.
end
```

Roblox has no tangent API; if you need one (for your own normal-map maths inside an
`EditableImage`) derive it per triangle from the UV gradient:
`T = ((c−a)·Δv_ab − (b−a)·Δv_ac) / (Δu_ab·Δv_ac − Δu_ac·Δv_ab)`, then Gram-Schmidt against
the vertex normal.

The official avatar sample shows the inverse operation — converting a mesh hit into a UV
coordinate, which is how you paint on a mesh with an `EditableImage`
[code, `Roblox/avatar`]:

```lua
function MeshUtils.GetTextureCoordinate(editableMesh, triangleId, barycentricCoordinate)
    local faceUVs = editableMesh:GetFaceUVs(triangleId)
    return (barycentricCoordinate.x * editableMesh:GetUV(faceUVs[1]))
         + (barycentricCoordinate.y * editableMesh:GetUV(faceUVs[2]))
         + (barycentricCoordinate.z * editableMesh:GetUV(faceUVs[3]))
end
```

**`RaycastLocal` return-order warning.** The reference YAML says it returns *"the point of
intersection, face ID, and barycentric coordinates"*, but Roblox's own published sample
destructures it as `local triangleId, hitPoint, barycentricCoordinate =
editableMesh:RaycastLocal(...)`, and `FindClosestPointOnSurface` is documented as
*(faceId, point, barycentric)*. **These cannot both be right.** Do not hardcode either —
sniff it once at startup:

```lua
local r1, r2 = em:RaycastLocal(origin, dir)
local faceIdFirst = typeof(r1) == "number"
```

### 10.6 Runtime simplification (decimation)

Roblox ships no decimation API, so you implement **Quadric Error Metrics** (Garland &
Heckbert) if you need it:

1. For each vertex, accumulate the 4×4 **quadric** `Q_v = Σ_{f} K_f` where
   `K_f = p·pᵀ` for the face plane `p = (a, b, c, d)` with `a²+b²+c²=1`.
2. For each edge `(u, v)`, the collapse cost is `v̄ᵀ (Q_u + Q_v) v̄` minimised over the
   contraction target `v̄` — solve the 3×3 system from the top-left of `Q_u + Q_v`; if
   singular, pick the best of `u`, `v`, midpoint.
3. Push edges into a priority queue by cost; pop, collapse, update the quadrics and costs
   of the affected 1-ring, repeat until the triangle target or an error threshold.
4. Reject collapses that flip a face normal by more than ~90° (prevents fold-over) or that
   would create a non-manifold edge.

`MrChickenRocket/sdf-procedural-toolkit` ships a working QEM pass (`SdfDecimate`) driven by
`qemMaxError` and a `triCap`, and reports the decimation stage separately in its timing
line [code].

**When it's worth it:** you generated something that blew the 20,000-triangle cap and
must fit it into one mesh; or you want distance LODs of a *runtime-generated* object, where
you cannot pre-author them. **When it isn't:** almost always. QEM in Luau on a 20k-triangle
mesh is hundreds of milliseconds. Generate at the right density instead (adaptive octree
DC, coarser marching-cubes grid, fewer icosphere subdivisions) — that is strictly cheaper
than generating fine and decimating.
