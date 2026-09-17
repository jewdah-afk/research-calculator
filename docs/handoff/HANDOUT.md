# Handout — Porting Shark Incremental to Roblox

Knowledge package for the chat that will do the port. Pair this with
`PROMPT.md`, which carries the instructions; this file carries the findings.

Everything below was verified against primary sources — the `Roblox/creator-docs`
generated YAML, the live engine reflection dump
(`MaximumADHD/Roblox-Client-Tracker`, client 0.739.0.7390687), Luau VM source,
and library source read directly. Depth lives in `docs/research/` (20 chapters,
37,000+ lines). Claims that could not be verified are marked and should be
treated as open.

---

## 1. The number problem is solved

**AlyaNum reaches `E(4)` with enormous headroom.** `eeee1` = 10↑↑4 is stored as
`{multiplicand = 1e10, exponent = 2}` — two of seven fields, with `exponent`
able to hold up to 2^53−1. The library's real ceiling is **heptation**
(`10↑↑↑↑↑n`), via a flat 7-field struct
`{sign, multiplicand, exponent, tetrate, pentate, hexate, heptate}`. When
`heptate` would exceed 2^53−1 there is no eighth field and the ladder stops.

- MIT licensed, actively maintained (v1.2.0, Aug 2026), by `evilbocchi`.
  `wally add evilbocchi/alyanum`. It is a rewrite-fork of OmegaNum.
- **Full operator overloading** — `+ - * / % == < <=`, unary minus, `tostring`,
  `..`. Mixed `AlyaNum + number` works; raw numbers get promoted.
- **Fast path for ordinary magnitudes**: `add`/`sub`/`mul` check whether all
  four hyperoperation fields are 0 and `exponent < 2`, and if so do raw float64
  math. Below ~1e308 you pay one allocation and a branch, not a tower walk.
- **Every operation allocates** a fresh 7-field table. There is no public
  mutate-in-place API. Design the tick loop around that allocation budget.
- **Formatting is first-class**: `toSuffix`, `toScientific`, `toEChain`,
  `toEnt`, `toHyperE`, `toString` (auto-escalating). But
  `changeDecimalPoints` and `changeSuffixes` are **process-global mutable
  state** — set once at init, never per-player.
- **Serialization**: the underlying `BaseAlyaNum` is a plain flat 7-number
  table, so it round-trips through JSON. `lbencode`/`toSingle` is a **lossy**
  order-preserving encoding for `OrderedDataStore` leaderboards — never use it
  as a save format.

**Two footguns.** `AlyaNum.new` on an existing AlyaNum returns *the same
object*, and `toBaseAlya()` strips the metatable **in place** — the library's
own source comment says so. Aliasing bugs here are silent. And never let a raw
`number` and a big-number share a variable; enforce it with types, because the
type solver will not catch it for you.

## 2. The editable-asset constraints, and they compound

Each is individually survivable. Together they define a narrow corridor.

| Constraint | Consequence |
|---|---|
| `Content` holding an Object **does not replicate** | Editable assets are **client-side**. A server-side one on a replicating instance renders as a cyan/magenta checkerboard. |
| **Native codegen is server-only** | Heavy pixel/mesh math runs **interpreted**, on the client, on phones. |
| `EditableImage`: **one display-side update per frame, globally**; 1024² max, not resizable | A hard throughput ceiling, corroborated independently by two chapters. |
| Mutators are **`Unsafe`** for parallel Luau | Only legal pattern: **compute parallel, commit serial** — parallel phase produces a `buffer`, serial phase does one write. |
| Published experiences need **13+ age + ID verification** plus the Creator Dashboard **Mesh / Image APIs** toggle | An account action, not a code action. Confirm before designing on it. |

**`AssetService:CreateDataModelContentAsync`** converts an editable asset into
DataModel-scoped `Opaque` Content and is the documented escape hatch from the
replication problem. Whether `Opaque` actually replicates is **unverified** —
resolve this early, it is load-bearing.

### Thread safety is clean and decisive
- `EditableMesh`: **53 `Safe`** members (every getter, query, `BatchGet*`,
  `RaycastLocal`, `FindClosest*`) / **41 `Unsafe`** (every mutator, including
  `BatchSetValues`). Zero exceptions.
- `EditableImage`: **only `ReadPixelsBuffer` is `Safe`**; `Size` is `ReadSafe`;
  `WritePixelsBuffer` and every `Draw*` are `Unsafe`.

### Mutation is live — this is the good news
Visual changes to an `EditableMesh` linked to a `MeshPart` are reflected
**immediately and automatically**. There is no `Commit`/`Flush`/`Apply` method
because none is needed. `CreateMeshPartAsync` + `ApplyMesh` is only for
recalculating **collision and fluid** geometry. So: **animate by mutating,
rebuild only when physics must agree.** `MeshPart.MeshSize` also stays stale
until `ApplyMesh`.

### Runtime PBR works — by construction, not assignment
`SurfaceAppearance.*MapContent` and all `MaterialVariant` maps are
**`PluginSecurity`-write**; you cannot assign into them from a game script.
But `CreateSurfaceAppearanceAsync` and `CreateDecalAsync` are `security: None`,
capability `Basic`, and their documented contract is EditableImage-only maps.
Build a new appearance rather than writing into an existing one.
`MaterialVariant` and `TerrainDetail` are genuinely out of reach.

**Write-security and EditableImage support are orthogonal.** `Beam`, `Trail`,
`ParticleEmitter` and `Sky` content properties are `write: None`, so assignment
*succeeds* — but none document EditableImage support, and
`ParticleEmitter.TextureContent` write-throughs to a legacy `ContentId` string
that cannot hold an object. **Expect silent no-ops, not errors.** Verify each
sink in-engine before depending on it.

### Numbers that are actually verified
- `EditableMesh` caps: **60,000 vertices, 20,000 triangles.** (The commonly
  repeated "20k vertices" is wrong.)
- Front faces are **counter-clockwise**. New vertices get UV `(0,0)` and reuse
  normals — hence the default "everything is smooth and untextured".
- Up to **4 bones per vertex**.
- Batch operations are **not atomic**: they apply updates up to the first
  invalid ID, then stop.
- `RemoveFace` leaks attributes until `RemoveUnused()`.
- **Tuple orders differ between sibling methods**: `RaycastLocal` returns
  `(point, faceId, bary)`; `FindClosestPointOnSurface` returns
  `(faceId, point, bary)`. Wrap both.
- **No numeric memory budget is published anywhere.** Two agents confirmed this
  by exhaustive search. Image and mesh share one budget. The ~32MB figure in
  circulation is hearsay.

### Three gates, three different failure shapes
Most code handles this wrong:

| Gate | Failure |
|---|---|
| Verification + dashboard toggle | Published places only |
| Asset permissions | **Throws** |
| Memory budget | **Returns `nil`** |

`CanEditAssetAsync` is `RobloxScriptSecurity`, so there is **no pre-check
available**. `pcall` plus a nil check is mandatory on every creation call.

## 3. The recommended art pipeline

**Generate at edit time in a Studio plugin, upload, ship plain asset IDs.**
`CreateAssetAsync` accepts an editable root but works only from locally loaded
plugins or Open Cloud. This single decision clears the verification gate, the
memory budget, the replication landmine, the one-update-per-frame throttle and
the mobile-performance risk **simultaneously**.

Reserve true runtime generation for content that genuinely must change live.
For an incremental game — whose art is overwhelmingly static — this should be
the default, not the exception.

## 4. Incremental-game architecture

**Do not build offline progress as a feature.** Store `meta.lastAdvancedAt`
(server `os.time()`, inside the session-locked profile) and expose one
function, `advanceTo(state, now)`, which closed-form-integrates from
`lastAdvancedAt` to `now` and re-anchors the timestamp **in a single
mutation**, so any save writes balance and timestamp atomically. Offline
progress is then simply a large `dt`.

This makes online and offline **provably identical**, kills rejoin-farming, and
yields the most valuable test in the suite: *12 hours in one jump must equal
12 hours of 4Hz ticks.* Clamp elapsed to `[0, cap]`, treat negative elapsed as
a tamper signal, and apply an efficiency factor to the rates rather than
forking the code path.

**`balance += rate*dt` at 60Hz silently no-ops** once balance dwarfs the
addend — `1e20 + 1e5 == 1e20`. Closed-form integration removes the whole bug
class.

### Persistence
- **Do not pre-compress saves.** Roblox compresses automatically and
  pre-compression "may reduce the effectiveness" of theirs. Any byte >127 fails
  `UpdateAsync`, so binary output must be base64'd regardless.
- Budgets: per-server `60 + numPlayers × 40`; experience-wide
  `300 + CCU × 40` read, `300 + CCU × 20` write. `UpdateAsync` decrements both.
  `SetRateLimitForRequestType` configures per-server limits (call once at init).
- **`os.time()` on the client is attacker-settable**, and
  `Workspace:GetServerTimeNow()` is documented "not secure" — display only.
- **DataStore2 is officially deprecated**, with an official migration tool.
  Default to **ProfileStore**; Lapis has better declarative migrations but its
  own README still warns it is not battle-tested in a large production game.

## 5. Rendering notes that contradict most guides

- **`Lighting.Technology` is superseded and non-scriptable.** `LightingStyle`
  (Realistic/Soft) plus `PrioritizeLightingQuality` replace it. No runtime A/B.
- **`EnvironmentDiffuseScale` and `EnvironmentSpecularScale` default to 0** —
  the mechanical cause of the flat default-Roblox look. PBR has nothing to
  reflect until raised.
- **`Highlight` caps at 255 client instances**, and disabled ones still consume
  a slot. Delete rather than disable.
- **Shadows are disabled entirely below graphics quality level 4.**
- Instancing rule: identical `MeshContent` batches when `SurfaceAppearance`s
  are identical if present, otherwise when `TextureContent`s are identical.
  **Colour tinting does not break batching.**
- Local light `Range` is clamped to 120 studs. Normal maps are tangent-space
  **OpenGL** (+Y); flat is `(127,127,255)`; meshes must export tangents.

## 6. Open questions — resolve in-engine, early

These could not be settled from documentation and are load-bearing:

1. Does `Opaque` DataModel-scoped `Content` replicate server→client?
2. Do `Beam`/`Trail`/`ParticleEmitter`/`Sky` sinks actually accept an
   EditableImage, or silently no-op?
3. What is the real editable-assets memory budget, in megabytes?
4. Are removed `EditableMesh` IDs ever reused?
5. UV origin convention — is V=0 top or bottom?
6. Do vertex colours render alongside `SurfaceAppearance`? (Community reports
   say no, and there is an open feature request.)
7. Does `RenderFidelity.Automatic` generate LODs for an EditableMesh-backed
   `MeshPart`?
8. Premultiplied vs straight alpha in the `EditableImage` pixel buffer.

Build a scratch place that answers all eight before committing to an
architecture. It is a few hours of work that de-risks months.

## 7. What is still needed from the project owner

The port is blocked on **readable source for Shark Incremental** — formulas,
content tables, save format, and the art. A minified bundle is not enough.
Place code under `game-source/` and imagery under `game-assets/`.

Rights are settled: this work is being done alongside Mr Red Shark, the
developer, with his involvement.

## 8. Where to read more

`docs/research/README.md` indexes all 20 chapters. The four that matter most
for this port: **60** (big numbers), **61** (incremental architecture),
**62** (JS→Luau port method and equivalence testing), **64** (QA and CI).
