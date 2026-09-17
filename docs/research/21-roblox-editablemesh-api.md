# Roblox `EditableMesh`: The Definitive Internal Reference

> Runtime geometry generation in Roblox Studio — creation, the ID-based data model,
> rendering, collision, queries, performance, and the traps.
>
> Every claim in this chapter is traceable to a fetched URL listed in **Sources**.
> Where the documentation does not say, the text says `[UNVERIFIED]` rather than guessing.
>
> Primary source of truth: the machine-readable YAML that Roblox generates its own
> reference site from —
> `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableMesh.yaml`
> (fetched 2026-09-17).

---

## TL;DR

- **`EditableMesh` is a live, mutable mesh object.** The class doc states it "changes the applied visual mesh when linked to a `Class.MeshPart`, allowing for querying and modification of the mesh both in Studio and in-game." [EditableMesh.yaml]
- **Visual mutation is live; collision mutation is not.** Verbatim: *"Visual changes to the mesh will always be immediately reflected by the engine, without the need to call `Class.AssetService:CreateMeshPartAsync()`."* But: *"To recalculate collision and fluid geometry after editing, you can again call `Class.AssetService:CreateMeshPartAsync()` and `Class.MeshPart:ApplyMesh()`."* [EditableMesh.yaml] See [Does mutation live-update?](#does-mutation-live-update).
- **It fails by default in published games.** You must be 13+ age verified **and** ID verified, then toggle **Enable Mesh / Image APIs** on the Creator Dashboard. [EditableMesh.yaml]
- **The data model is ID-based, not array-based.** Vertex, normal, UV, color, face and bone IDs are *stable* `int64` handles. Deleting leaves holes: `{1,2,3,4,5}` minus `4` gives `{1,2,3,5}`. Never assume contiguity; always iterate `GetVertices()` / `GetFaces()`. [EditableMesh.yaml]
- **Positions are per-vertex; normals, UVs and colors are per-face-corner**, living in their own ID spaces. This is exactly how one position carries split UVs and hard edges. `AddTriangle` auto-reuses a vertex's existing attribute IDs (smooth/continuous) unless you explicitly create new ones (seam/crease). [EditableMesh.yaml]
- **Hard caps: 60,000 vertices and 20,000 triangles per `EditableMesh`.** Exceeding them errors. [EditableMesh.yaml]
- **`FixedSize` defaults to `true` for meshes created from an asset** (`CreateEditableMeshAsync`) and is always `false` for blank meshes (`CreateEditableMesh`). Fixed-size costs less memory but forbids topology changes. [AssetService.yaml]
- **Client-side editable memory is budgeted; server/Studio/plugins are unlimited.** On exhaustion `CreateEditableMesh`/`CreateEditableMeshAsync` return `nil` (not an error). [AssetService.yaml, EditableMesh.yaml]
- **All mutators are `thread_safety: Unsafe`; nearly all getters and all spatial queries are `Safe`.** That is the precise boundary for parallel Luau: read/raycast in parallel, write in serial. [EditableMesh.yaml]
- **Batch APIs exist and are the performance story**: `BatchAdd`, `BatchSetValues`, `BatchGetValues`, `BatchSetFaceAttributes`, `BatchGetVertexFaceAttributes`, `BatchRemove`. Docs: *"Batching your mesh operations is typically much more performant than handling them one by one."* [EditableMesh.yaml]
- **Tuple order genuinely differs between two sibling queries.** `RaycastLocal` returns `(point, faceId, barycentric)`; `FindClosestPointOnSurface` returns `(faceId, point, barycentric)`. This is what the YAML says. [EditableMesh.yaml]
- **Do not put an `EditableMesh` in a replicating `Content` property on the server.** `Datatype.Content` `Object` values do not replicate; clients get an unusable placeholder that renders as a cyan/magenta checkerboard. [Content.yaml]
- **Skinning is supported**: bones (`AddBone`/`SetVertexBones`/`SetVertexBoneWeights`), plus full FACS pose authoring for dynamic heads.
- **Generated meshes cannot be uploaded as permanent mesh assets** by any documented `AssetService` API — `CreateAssetAsync` does not list a mesh type. [AssetService.yaml] See [Saving and uploading](#12-saving-and-uploading).

---

## The verification gate

This is the first thing that kills a project, and it is not a code problem.

`EditableMesh.yaml`, section **"Enabling for published games"**, verbatim:

> For security purposes, using `EditableMesh` fails by default for published games. To enable usage of `EditableMesh`, you must be 13+ age verified and ID verified. After you are verified, open the [Creator Dashboard](https://create.roblox.com/dashboard/creations) and toggle on **Enable Mesh / Image APIs**. Remember to review the [Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use#creators-restrictions-on-use) before enabling the toggle.

Consequences for a team:

- The toggle is **per creator/experience owner**, on the Creator Dashboard, not a Studio setting and not a script flag.
- It works in Studio without the toggle. It fails in the published game. Your test coverage must include a published test place, or you will ship a broken build.
- Because it is tied to a *verified individual*, a group-owned experience inherits the gate from the group's owner context. Plan who owns the place before you build a runtime-geometry pipeline on it.

### Asset-loading permissions

`EditableMesh.yaml`, section **"Permissions"**, verbatim:

> To prevent misuse, `Class.AssetService:CreateEditableMeshAsync()` only allows you to load and edit mesh assets if any of the following is true:
>
> - Owned by or explicitly shared with the game owner.
> - Owned by or explicitly shared with the logged in Studio user.
> - Owned by or explicitly shared with the logged in player if the `EditableMesh` is on the client side.
> - Owned by a group where the game owner, Studio user, or player has a role with permission to edit the group's assets.
>
> The APIs throw an error if they are used to load an asset that does not meet the criteria above.

Note the asymmetry that most teams miss: the **third** bullet only applies **client-side**. A client can crack open a mesh the *player* owns; the server cannot. If your design lets players import their own meshes, that logic must live on the client.

Note also the failure mode difference:

| Situation | Failure shape |
|---|---|
| Permission denied on `CreateEditableMeshAsync` | **throws** — wrap in `pcall` |
| Editable memory budget exhausted | **returns `nil`** — check the return value |
| Exceeding 60,000 verts / 20,000 tris | **throws** |
| `CreateMeshPartAsync` fails | **throws** ("It throws errors if creation fails.") [AssetService.yaml] |

So correct creation code checks **both**:

```lua
local ok, meshOrErr = pcall(function()
	return AssetService:CreateEditableMeshAsync(Content.fromAssetId(ASSET_ID), { FixedSize = false })
end)
if not ok then
	warn("EditableMesh load failed (permission/verification):", meshOrErr)
	return
end
local editableMesh = meshOrErr
if editableMesh == nil then
	warn("EditableMesh creation failed: editable memory budget exhausted")
	return
end
```

---

## 1. Creation

There are exactly two entry points, both on `AssetService`.

### `AssetService:CreateEditableMesh(editableMeshOptions: Dictionary?) -> EditableMesh`

- **Yields:** no. **Thread safety:** `Unsafe`. **Capability:** `DynamicGeneration`. [AssetService.yaml]
- Summary: *"Creates a new, empty `Class.EditableMesh`. Vertices, triangles, and their attributes can be added dynamically to it. If the device-specific editable memory budget is exhausted, creation will fail and this method will return `nil`."*
- Options table: *"Currently no options are available since `Class.EditableMesh.FixedSize|FixedSize` will always be `false` for empty editable meshes."*

So: **a blank mesh is never fixed-size.** Pass nothing.

```lua
local AssetService = game:GetService("AssetService")
local mesh = AssetService:CreateEditableMesh()  -- may be nil on a memory-starved client
```

### `AssetService:CreateEditableMeshAsync(content: Content, editableMeshOptions: Dictionary?) -> EditableMesh`

- **Yields:** yes (`tags: [Yields]`). **Thread safety:** `Unsafe`. **Capability:** `AssetRead`. [AssetService.yaml]
- Description, verbatim: *"Returns a new `Class.EditableMesh` object created from an existing `Class.EditableMesh` or mesh `Datatype.Content` ID. By default, an `Class.EditableMesh` created from this method will be fixed size such that mesh data can only be modified, not added nor removed. A fixed size `Class.EditableMesh` consumes less memory and should be preferred when possible."*
- Also: *"If the device-specific editable memory budget is exhausted, creation will fail and this method will return `nil`."*
- Options table, verbatim: *"`FixedSize` – A `bool`. Default value is `true`, and the returned `Class.EditableMesh` will not allow you to add or remove vertices, only modify their values. Set to `false` if the ability to change the mesh topology is required, at the expense of using more memory."*

Three ways to build the `Content` argument (all shown in `EditableMesh.yaml`):

```lua
-- 1. From an asset ID
AssetService:CreateEditableMeshAsync(Content.fromAssetId(ASSET_ID))

-- 2. From another EditableMesh (a deep copy / snapshot)
AssetService:CreateEditableMeshAsync(Content.fromObject(OTHER_EDITABLE_MESH))

-- 3. From an existing MeshPart already in the world
AssetService:CreateEditableMeshAsync(MESH_PART.MeshContent)
```

`Content` constructors [Content.yaml]:

| Constructor | Meaning |
|---|---|
| `Content.fromUri(uri: string)` | asset URI string referencing content external to the place |
| `Content.fromAssetId(assetId: number)` | numeric asset ID |
| `Content.fromObject(object: Object)` | strong reference to an in-place `Object` (an `EditableMesh` or `EditableImage`) |
| `Content.none` | empty value, `SourceType = Enum.ContentSourceType.None` |

Readback properties: `Content.SourceType`, `Content.Uri`, `Content.Object`, `Content.Opaque`.

### Failure modes summary

| Cause | Symptom | Detect with |
|---|---|---|
| Not age+ID verified / dashboard toggle off, in a published game | usage of `EditableMesh` fails | published-place smoke test; `pcall` |
| Asset not owned/shared per the Permissions rules | **throws** | `pcall` |
| Editable memory budget exhausted (client) | **returns `nil`** | explicit `nil` check |
| `FixedSize = true` (the default from an asset) and you call `AddVertex`/`AddTriangle`/`RemoveFace` | topology change rejected | pass `{FixedSize = false}` up front; read `mesh.FixedSize` |
| More than 60,000 vertices | **throws** ("An error is thrown if the mesh already contains 60,000 vertices.") | pre-count |
| More than 20,000 triangles | **throws** | pre-count |

### Lifetime

- `EditableMesh:Destroy()` exists (`thread_safety: Unsafe`).
- `EditableMesh:Clear()` exists — empties the mesh without destroying the object (`Unsafe`).
- The class is tagged `NotCreatable` and inherits from `Object` (**not** `Instance`). You cannot `Instance.new("EditableMesh")`, and it has no `Parent`. [EditableMesh.yaml: `inherits: [Object]`, `tags: [NotCreatable]`]

---

## 2. The data model

This is the part that confuses everyone, so read it slowly.

### 2.1 IDs are stable handles, not array indices

`EditableMesh.yaml`, section **"Stable IDs"**, verbatim:

> Many `EditableMesh` methods take **vertex**, **normal**, **UV**, **color** and **face** IDs. These are represented as integers in Luau but they require some special handling. The main difference is that IDs are stable and they remain the same even if other parts of the mesh change. For example, if an `EditableMesh` has five vertices `{1, 2, 3, 4, 5}` and you remove vertex `4`, the new vertices will be `{1, 2, 3, 5}`.
>
> Note that the IDs are not guaranteed to be in order and there may be holes in the numbering, so when iterating through vertices or faces, you should iterate through the table returned by `Class.EditableMesh:GetVertices()|GetVertices()` or `Class.EditableMesh:GetFaces()|GetFaces()`.
>
> For debugging purposes, it can be very helpful to get a more readable string for a stable ID with `Class.EditableMesh:IdDebugString()|IdDebugString()`.

Three hard rules follow:

1. **Never do `for i = 1, vertexCount do`.** Always `for _, vid in ipairs(mesh:GetVertices()) do`.
2. **Never persist an ID across a rebuild** into a different `EditableMesh`. IDs are per-mesh.
3. **Holes are permanent within a mesh.** The documentation says removal leaves the numbering with holes; it does **not** say IDs are recycled. `IdDebugString` returns a string *"like `f17` or `v12`, containing the type, ID number, **and version**"* — the presence of a version field is strong evidence that an ID slot can be reused with a bumped version, which would make a stale ID detectably invalid rather than silently aliasing. **`[UNVERIFIED]`: the docs do not state whether the numeric slot is ever reused; treat stale IDs as invalid and do not rely on either reuse or non-reuse.**

`IdDebugString(id) -> string` also means a single integer encodes its own type. That is why several batch methods can infer the attribute from the IDs you hand them ("or the type already encoded in each mesh ID").

### 2.2 Separate ID spaces: position is per-vertex, everything else is per-face-corner

`EditableMesh.yaml`, section **"Split vertex attributes"**, verbatim:

> A **vertex** is a corner of a face, and topologically connects faces together. Each vertex has a single **position**, while its **normal**, **UV coordinate**, and **color** (with transparency) are stored per face corner. A vertex shared by multiple faces can use the same values on every face, or different values on each.
>
> Sometimes it's useful for all faces that touch a vertex to use the same attribute values, but sometimes you'll want different faces to use different attribute values on the same vertex. For example, on a smooth sphere, each vertex will only have a single normal. In contrast, at the corner of a cube, the vertex will have 3 different normals (one for each adjacent face). You can also have seams in the UV coordinates or sharp changes in the vertex colors.

Mental model:

```
Vertex ID  ──> exactly one Vector3 position          (GetPosition / SetPosition)

(Vertex ID, Face ID) ──> one Normal ID  ──> Vector3   (GetVertexFaceNormal / SetNormal)
                    ──> one UV ID      ──> Vector2   (GetVertexFaceUV     / SetUV)
                    ──> one Color ID   ──> Color3+α  (GetVertexFaceColor  / SetColor,SetColorAlpha)

Face ID    ──> ordered list of 3 Vertex IDs           (GetFaceVertices / SetFaceVertices)
           ──> ordered list of 3 Normal IDs           (GetFaceNormals  / SetFaceNormals)
           ──> ordered list of 3 UV IDs               (GetFaceUVs      / SetFaceUVs)
           ──> ordered list of 3 Color IDs            (GetFaceColors   / SetFaceColors)
```

There are therefore **five independent ID spaces**: vertices, faces, normals, UVs, colors (plus a sixth for bones). A normal ID is not a vertex ID. The per-corner arrays are always *"in the same order as `GetFaceVertices()`"* [BatchGetFaceAttributes description].

Key consequence: **sharing an attribute ID between corners = smooth/continuous; separate IDs = seam/crease.** That is the *only* mechanism. There is no "smoothing group" or "hard edge" flag.

### 2.3 What `AddTriangle` does automatically

`AddTriangle(vertexId0, vertexId1, vertexId2) -> faceId` takes **only vertex IDs**. Verbatim from its description:

> - If the vertex **already belongs to another face**, the new triangle corner **reuses** the same normal, UV, and color IDs from the existing face. This produces smooth shading and continuous UVs across adjacent faces by default.
> - If the vertex **does not yet belong to any face**, new normal, UV, and color IDs are created with default values (auto-computed normal, UV coordinate of `(0, 0)`, and white color).

So a naive from-scratch build produces: **smooth shading everywhere and all UVs at (0,0)**. You get the flat-shaded, correctly-textured result only by doing extra work.

Two correction strategies, both documented:

**(a) Change values in place** — cheaper, leaves no garbage IDs:

```lua
local faceId = mesh:AddTriangle(v0, v1, v2)
local uvId0 = mesh:GetVertexFaceUV(v0, faceId)
local uvId1 = mesh:GetVertexFaceUV(v1, faceId)
local uvId2 = mesh:GetVertexFaceUV(v2, faceId)
mesh:SetUV(uvId0, Vector2.new(0, 0))
mesh:SetUV(uvId1, Vector2.new(1, 0))
mesh:SetUV(uvId2, Vector2.new(0, 1))
```

The docs call this *"more performant and avoids leaving unused IDs in the mesh."*

**(b) Create new attribute IDs and bind them** — required for a seam:

```lua
local faceId = mesh:AddTriangle(v0, v1, v2)
local uv0 = mesh:AddUV(Vector2.new(0, 0))
local uv1 = mesh:AddUV(Vector2.new(1, 0))
local uv2 = mesh:AddUV(Vector2.new(0, 1))
mesh:SetFaceUVs(faceId, {uv0, uv1, uv2})
```

### 2.4 Hard edges

`AddNormal(normal: Vector3?)` with **no argument** creates a normal ID whose value is *auto-computed* from mesh shape. `ResetNormal(normalId)` reverts a manually-set normal back to automatic. To crease an edge, give each face its own normal ID:

```lua
local fid1 = mesh:AddTriangle(v0, v1, v2)
local fid2 = mesh:AddTriangle(v0, v3, v1)
local n1 = mesh:AddNormal()  -- auto-computed for fid1
local n2 = mesh:AddNormal()  -- auto-computed for fid2
mesh:SetFaceNormals(fid1, {n1, n1, n1})
mesh:SetFaceNormals(fid2, {n2, n2, n2})
```

### 2.5 Cleanup semantics

- `RemoveFace(faceId)`: *"The vertices and attributes that were used by the face are **not** automatically deleted; call `RemoveUnused()` afterward if you want to clean up unused vertices and attributes."*
- `RemoveUnused() -> Array`: *"Removes all vertices, normals, UVs, and colors which are not used in any face, and returns the removed IDs."* Returns the removed IDs so you can invalidate your own caches.
- `MergeVertices(mergeTolerance: float) -> Map`: *"Merges vertices that touch together, to use a single vertex ID but keep the other original attribute IDs."* Returns *"A mapping of old vertex ID to new vertex ID for vertices that have been merged."* Note the design: **welding positions does not weld normals/UVs/colors** — exactly the behavior you want when stitching a seamed mesh.
- `Clear()`: empties the mesh. `Triangulate()`: converts the mesh to triangles (`Unsafe`, no args, no return).

---

## Verified API surface

Generated directly from `EditableMesh.yaml` (fetched 2026-09-17). **94 methods, 1 property, 0 events, 0 callbacks.**
Every method carries `capabilities: [DynamicGeneration]` and `security: None`.

**Property**

| Property | Type | Access | Thread safety | Meaning |
|---|---|---|---|---|
| `EditableMesh.FixedSize` | `boolean` | read: `None`, write: `RobloxEngineSecurity` (i.e. **read-only to you**) | `ReadSafe` | *"Fixed-sized meshes allow changing the values of vertex attributes but do not allow vertices and triangles to be added or deleted."* |

**Thread-safety legend:** `Safe` = callable from a parallel-Luau (desynchronized) context; `Unsafe` = must run in serial. See [Performance and parallelism](#11-performance-and-parallelism).


#### 1. Lifetime & housekeeping

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `Clear()` | `()` | Unsafe | Clears all of an EditableMesh's geometry. |
| `Destroy()` | `()` | Unsafe | Destroys the mesh. |
| `IdDebugString(id: int64)` | `string` | Unsafe | String that describes the ID in human-readable format. |
| `MergeVertices(mergeTolerance: float)` | `Map` | Unsafe | A mapping of old vertex ID to new vertex ID for vertices that have been merged. |
| `RemoveUnused()` | `Array` | Unsafe | All of the removed IDs. |
| `Triangulate()` | `()` | Unsafe | Splits all faces on the mesh to be triangles. |

#### 2. Adders

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `AddColor(color: Color3, alpha: float)` | `int64` | Unsafe | Color ID of the new color. |
| `AddNormal(normal: Vector3?)` | `int64` | Unsafe | Normal ID of the new normal. |
| `AddTriangle(vertexId0: int64, vertexId1: int64, vertexId2: int64)` | `int64` | Unsafe | Face ID of the new face. |
| `AddUV(uv: Vector2)` | `int64` | Unsafe | UV ID of the new UV. |
| `AddVertex(p: Vector3)` | `int64` | Unsafe | Vertex ID of the new vertex. |

#### 3. Removers

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `RemoveFace(faceId: int64)` | `()` | Unsafe | Removes a face using its face ID. |

#### 4. Setters

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `ResetNormal(normalId: int64)` | `()` | Unsafe | Reset this normal ID to be automatically calculated. |
| `SetColor(colorId: int64, color: Color3)` | `()` | Unsafe | Sets the color for a color ID. |
| `SetColorAlpha(colorId: int64, alpha: float)` | `()` | Unsafe | Sets the color alpha (transparency) for a color ID. |
| `SetFaceColors(faceId: int64, ids: Array)` | `()` | Unsafe | Sets the face's vertex colors to new color IDs. |
| `SetFaceNormals(faceId: int64, ids: Array)` | `()` | Unsafe | Sets the face's vertex normals to new normal IDs. |
| `SetFaceUVs(faceId: int64, ids: Array)` | `()` | Unsafe | Sets the face's vertex UVs to new UV IDs. |
| `SetFaceVertices(faceId: int64, ids: Array)` | `()` | Unsafe | Sets the face's vertices to new vertex IDs. |
| `SetNormal(normalId: int64, normal: Vector3)` | `()` | Unsafe | Set the normal for a normal ID. |
| `SetPosition(vertexId: int64, p: Vector3)` | `()` | Unsafe | Sets a vertex position in the mesh's local object space. |
| `SetUV(uvId: int64, uv: Vector2)` | `()` | Unsafe | Sets UV coordinates for a UV ID. |
| `SetVertexFaceColor(vertexId: int64, faceId: int64, colorId: int64)` | `()` | Unsafe | Sets the color ID of a vertex/face pair. |
| `SetVertexFaceNormal(vertexId: int64, faceId: int64, normalId: int64)` | `()` | Unsafe | Sets the normal ID of a vertex/face pair. |
| `SetVertexFaceUV(vertexId: int64, faceId: int64, uvId: int64)` | `()` | Unsafe | Sets the UV ID of a vertex/face pair. |

#### 5. Getters

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `GetAdjacentFaces(faceId: int64)` | `Array` | Safe | List of face IDs adjacent to the given face. |
| `GetAdjacentVertices(vertexId: int64)` | `Array` | Safe | List of IDs of adjacent vertices around the given vertex ID. |
| `GetColor(colorId: int64)` | `Color3?` | Safe | Color for the requested color ID. |
| `GetColorAlpha(colorId: int64)` | `float?` | Safe | Color alpha at the request color ID. |
| `GetColors()` | `Array` | Safe | List of color IDs. |
| `GetFaceColors(faceId: int64)` | `Array` | Safe | List of color IDs used for the vertices on the given face. |
| `GetFaceNormals(faceId: int64)` | `Array` | Safe | List of normal IDs used for the vertices on the given face. |
| `GetFaceUVs(faceId: int64)` | `Array` | Safe | List of UV IDs used for the vertices on the given face. |
| `GetFaceVertices(faceId: int64)` | `Array` | Safe | List of vertex IDs around the given face. |
| `GetFaces()` | `Array` | Safe | List of face IDs. |
| `GetFacesWithAttribute(id: int64)` | `Array` | Safe | List of face IDs which use the given attribute ID. **DEPRECATED** |
| `GetFacesWithColor(colorId: int64)` | `Array` | Safe | List of face IDs that use the provided color ID. |
| `GetFacesWithNormal(normalId: int64)` | `Array` | Safe | List of face IDs that use the provided normal ID. |
| `GetFacesWithUV(uvId: int64)` | `Array` | Safe | List of face IDs that use the provided UV ID. |
| `GetNormal(normalId: int64)` | `Vector3?` | Safe | Normal vector at the requested normal ID. |
| `GetNormals()` | `Array` | Safe | List of normal IDs. |
| `GetPosition(vertexId: int64)` | `Vector3` | Safe | Position of a vertex in the mesh's local object space. |
| `GetUV(uvId: int64)` | `Vector2?` | Safe | UV coordinates at the requested UV ID. |
| `GetUVs()` | `Array` | Safe | List of UV IDs. |
| `GetVertexColors(vertexId: int64)` | `Array` | Safe | Array of color IDs of faces attached to the given vertex. |
| `GetVertexFaceColor(vertexId: int64, faceId: int64)` | `int64` | Safe | Color ID of the vertex/face pair. |
| `GetVertexFaceNormal(vertexId: int64, faceId: int64)` | `int64` | Safe | Normal ID of the vertex/face pair. |
| `GetVertexFaceUV(vertexId: int64, faceId: int64)` | `int64` | Safe | UV ID of the vertex/face pair. |
| `GetVertexFaces(vertexId: int64)` | `Array` | Safe | Array of face IDs attached to the given vertex. |
| `GetVertexNormals(vertexId: int64)` | `Array` | Safe | Array of normal IDs of faces attached to the given vertex. |
| `GetVertexUVs(vertexId: int64)` | `Array` | Safe | Array of UV IDs of faces attached to the given vertex. |
| `GetVertices()` | `Array` | Safe | List of vertex IDs. |
| `GetVerticesWithAttribute(id: int64)` | `Array` | Safe | List of vertex IDs which use the given attribute ID. **DEPRECATED** |
| `GetVerticesWithColor(colorId: int64)` | `Array` | Safe | List of face IDs that use the provided color ID. |
| `GetVerticesWithNormal(normalId: int64)` | `Array` | Safe | List of vertex IDs that use the provided normal ID. |
| `GetVerticesWithUV(uvId: int64)` | `Array` | Safe | List of vertex IDs that use the provided UV ID. |

#### 6. Queries & bounds

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `FindClosestPointOnSurface(point: Vector3)` | `Tuple` | Safe | Tuple of the face ID, point on the mesh in local object space, and the barycentric coordinate of the position within the face. |
| `FindClosestVertex(toThisPoint: Vector3)` | `int64` | Safe | Closest vertex ID to the specified point in space. |
| `FindVerticesWithinSphere(center: Vector3, radius: float)` | `Array` | Safe | List of vertex IDs within the requested sphere. |
| `GetCenter()` | `Vector3` | Safe | Center of the bounding box of the `EditableMesh`. |
| `GetSize()` | `Vector3` | Safe | Size of the `EditableMesh`. |
| `RaycastLocal(origin: Vector3, direction: Vector3)` | `Tuple` | Safe | Tuple of the point of intersection, face ID, and barycentric coordinates. |

#### 7. Batch

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `BatchAdd(attr: MeshAttribute, data: Array)` | `Array` | Unsafe | Ordered array of new element IDs matching the input order. |
| `BatchGetFaceAttributes(attr: MeshAttribute, faceIds: Array)` | `Array` | Safe | 2D array where `result[i]` is the array of attribute IDs at the corners of `faceIds[i]`. |
| `BatchGetValues(ids: Array)` | `Tuple` | Safe | A tuple of two values. The first is an array of attribute values: `Datatype.Vector3` for vertex or normal IDs, `Datatype.Vector2` for UV IDs, `Datatype.Color3` for color IDs. The second i... |
| `BatchGetVertexAttributes(attr: MeshAttribute, vertexIds: Array)` | `Array` | Safe | 2D array where `result[i]` is the array of attribute IDs associated with `vertexIds[i]`. |
| `BatchGetVertexFaceAttributes(attr: MeshAttribute, vertexIds: Array, faceIds: Array)` | `Array` | Safe | Array of attribute IDs at each corner, in the same order as the inputs. |
| `BatchRemove(faceIds: Array)` | `()` | Unsafe | Removes a batch of faces. |
| `BatchSetFaceAttributes(faceIds: Array, attrIdArrays: Array)` | `()` | Unsafe | Sets the per-corner attribute IDs for each face in a batch. |
| `BatchSetValues(ids: Array, values: Array)` | `()` | Unsafe | Writes attribute values to a batch of mesh element IDs. |
| `BatchSetVertexFaceAttributes(vertexIds: Array, faceIds: Array, attrIds: Array)` | `()` | Unsafe | Sets the attribute at a specific corner for each vertex–face pair in a batch. |

#### 8. Bones / skinning

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `AddBone(boneProperties: Dictionary)` | `int64` | Unsafe | Bone ID of the new bone. |
| `GetBoneByName(boneName: string)` | `int64` | Safe | Bone ID of the bone with the given name. |
| `GetBoneCFrame(boneId: int64)` | `CFrame` | Safe | Initial `Datatype.CFrame` of the bone in the bind pose of the mesh, in the mesh's local space. |
| `GetBoneIsVirtual(boneId: int64)` | `boolean` | Safe | Whether the bone with the given bone ID is virtual. Virtual bones can only be bound to a `Class.FaceControls` instance. |
| `GetBoneName(boneId: int64)` | `string` | Safe | Name of the bone with the given bone ID. |
| `GetBoneParent(boneId: int64)` | `int64` | Safe | Bone ID for the parent of the bone with the given bone ID. If there is no parent, returns `0`. |
| `GetBones()` | `Array` | Safe | List of bone IDs. |
| `GetVertexBoneWeights(vertexId: int64)` | `Array` | Safe | Skinning blend weights for each bone that is associated with the vertex. |
| `GetVertexBones(vertexId: int64)` | `Array` | Safe | Bone IDs associated with the vertex for skinning. |
| `RemoveBone(boneId: int64)` | `()` | Unsafe | Removes a bone using its bone ID. |
| `SetBoneCFrame(boneId: int64, cframe: CFrame)` | `()` | Unsafe | Set the initial `Datatype.CFrame` for a bone in the mesh's bind pose. |
| `SetBoneIsVirtual(boneId: int64, virtual: boolean)` | `()` | Unsafe | Set whether a bone is virtual. |
| `SetBoneName(boneId: int64, name: string)` | `()` | Unsafe | Sets the name for a bone. |
| `SetBoneParent(boneId: int64, parentBoneId: int64)` | `()` | Unsafe | Set a parent for a bone. |
| `SetVertexBoneWeights(vertexId: int64, boneWeights: Array)` | `()` | Unsafe | Sets skinning blend weights for each bone associated with the vertex. |
| `SetVertexBones(vertexId: int64, boneIDs: Array)` | `()` | Unsafe | Assign a list of bones with the vertex for skinning. |

#### 9. FACS

| Method | Returns | Thread safety | Notes / return meaning |
|---|---|---|---|
| `GetFacsCorrectivePose(actions: Array)` | `Tuple` | Safe | Array of bone IDs and corresponding array of bone `Datatype.CFrame\|CFrames`. |
| `GetFacsCorrectivePoses()` | `Array` | Safe | Array of corrective poses. Each corrective pose is specified by a small array of 2 or 3 `Enum.FacsActionUnit` values. |
| `GetFacsPose(action: FacsActionUnit)` | `Tuple` | Safe | Array of bone IDs and corresponding array of bone `Datatype.CFrame`. |
| `GetFacsPoses()` | `Array` | Safe | Array of `Enum.FacsActionUnit`, one for each FACS action unit that has a pose defined. |
| `SetFacsBonePose(action: FacsActionUnit, boneId: int64, cframe: CFrame)` | `()` | Unsafe | Set `Datatype.CFrame` for an individual bone in a specific FACS action unit. |
| `SetFacsCorrectivePose(actions: Array, boneIds: Array, cframes: Array)` | `()` | Unsafe | Set pose for all bones in a specific FACS corrective pose. |
| `SetFacsPose(action: FacsActionUnit, boneIds: Array, cframes: Array)` | `()` | Unsafe | Set pose for all bones in a specific FACS action unit. |

#### `AssetService` methods that matter here

| Method | Returns | Yields | Thread safety | Capability |
|---|---|---|---|---|
| `AssetService:CreateEditableMesh(editableMeshOptions: Dictionary?)` | `EditableMesh` (or `nil` on budget exhaustion) | no | Unsafe | `DynamicGeneration` |
| `AssetService:CreateEditableMeshAsync(content: Content, editableMeshOptions: Dictionary?)` | `EditableMesh` (or `nil` on budget exhaustion) | **yes** | Unsafe | `AssetRead` |
| `AssetService:CreateMeshPartAsync(meshContent: Content, options: Dictionary = nil)` | `MeshPart` | **yes** | Unsafe | `Basic` |

#### `MeshPart` members that matter here

| Member | Type | Notes |
|---|---|---|
| `MeshPart.MeshContent` | `Content` | *"The mesh that is displayed on the `MeshPart`. Supports asset URIs and `EditableMesh` objects."* Read-only at runtime. |
| `MeshPart.MeshId` | `ContentId` | *"Reads and writes to `MeshContent`."* |
| `MeshPart.TextureContent` | `Content` | *"Supports asset URIs and `EditableImage` objects."* |
| `MeshPart.RenderFidelity` | `RenderFidelity` | `NotReplicated` |
| `MeshPart.DoubleSided` | `boolean` | *"Determines whether to render both faces of polygons in the mesh."* |
| `MeshPart.HasSkinnedMesh` | `boolean` | `Hidden`. *"Indicates whether the mesh currently applied to the `MeshPart` contains skinning (bone and joint) data."* |
| `MeshPart:ApplyMesh(meshPart: Instance)` | `()`, `Unsafe` | Copies `MeshContent`, `TextureContent`, `RenderFidelity`, `CollisionFidelity` (with collision geometry), `FluidFidelity` (with aero geometry), and `MeshSize` from the source part. Throws if the argument is not a `MeshPart`. |

#### Documented tuple returns (exact order)

| Method | Returns, in order |
|---|---|
| `RaycastLocal(origin, direction)` | **1.** point of intersection (local object space) · **2.** face ID · **3.** barycentric coordinates |
| `FindClosestPointOnSurface(point)` | **1.** face ID · **2.** point on the mesh (local object space) · **3.** barycentric coordinate within the face |
| `BatchGetValues(ids)` | **1.** array of values (`Vector3` for vertex/normal IDs, `Vector2` for UV IDs, `Color3` for color IDs) · **2.** `nil` for every type **except color**, where it is an array of alpha numbers |
| `GetFacsPose(action)` | Tuple — see [Skinning, bones and FACS](#10-skinning-bones-and-facs) |
| `GetFacsCorrectivePose(actions)` | Tuple — see [Skinning, bones and FACS](#10-skinning-bones-and-facs) |

> **The tuple-order inconsistency is real and it is in the official source.**
> `RaycastLocal` gives you `(point, faceId, bary)`. `FindClosestPointOnSurface` gives you `(faceId, point, bary)`.
> Two methods that return the same three things return them in a different order. Write a wrapper once, in one module, and never call them raw:
>
> ```lua
> local function raycast(mesh, origin, dir)
> 	local point, faceId, bary = mesh:RaycastLocal(origin, dir)
> 	return faceId, point, bary   -- normalized to (faceId, point, bary)
> end
> local function closest(mesh, p)
> 	local faceId, point, bary = mesh:FindClosestPointOnSurface(p)
> 	return faceId, point, bary
> end
> ```

#### Deprecated — do not use

| Method | Replacement |
|---|---|
| `GetFacesWithAttribute(id)` | `GetFacesWithColor` / `GetFacesWithNormal` / `GetFacesWithUV` / `GetVertexFaces` |
| `GetVerticesWithAttribute(id)` | `GetVerticesWithColor` / `GetVerticesWithNormal` / `GetVerticesWithUV` / `GetFaceVertices` |

Both carry `deprecation_message: "This method is deprecated. Do not use it for new work."`

---

## Does mutation live-update?

**Yes for visuals. No for physics.** This is the single most architecture-defining fact about `EditableMesh`, and the source states it unambiguously.

`EditableMesh.yaml`, lines 117–123, verbatim and complete:

> To recalculate collision and fluid geometry after editing, you can again call `Class.AssetService:CreateMeshPartAsync()` and `Class.MeshPart:ApplyMesh()` to update an existing `Class.MeshPart`. It's generally recommended to do this at the end of a conceptual edit, not after individual calls to methods that manipulate geometry. **Visual changes to the mesh will always be immediately reflected by the engine, without the need to call `Class.AssetService:CreateMeshPartAsync()`.**

And the class summary, lines 10–12:

> `EditableMesh` changes the applied visual mesh when linked to a `Class.MeshPart`, allowing for querying and modification of the mesh both in Studio and in-game.

### What that means precisely

| Thing you change | Propagates to the rendered `MeshPart`? | Propagates to collision? | Propagates to fluid/aero? |
|---|---|---|---|
| `SetPosition` (vertex moved) | **Immediately, automatically** | **No** — stale until rebuild | **No** |
| `SetNormal` / `ResetNormal` | **Immediately** | n/a | n/a |
| `SetUV` | **Immediately** | n/a | n/a |
| `SetColor` / `SetColorAlpha` | **Immediately** | n/a | n/a |
| `AddVertex` / `AddTriangle` / `RemoveFace` / `SetFaceVertices` (topology) | **Immediately** *(same "visual changes" clause; the doc draws no distinction between attribute edits and topology edits)* | **No** | **No** |
| `Batch*` setters | **Immediately** (same semantics as the singular methods) | **No** | **No** |
| Bone `CFrame`s / skin weights | `[UNVERIFIED]` — not called out separately in the doc | **No** | **No** |

### There is nothing to "commit"

There is **no** `Commit()`, `Flush()`, `Apply()`, `Update()`, `Rebuild()` or `Changed` event on `EditableMesh`. The YAML has `events: []` and `callbacks: []`. The link is a live reference, not a snapshot: `MeshPart.MeshContent` holds a `Content` whose `Object` is your `EditableMesh`, and the renderer reads through it.

This is why the class summary says it "**changes the applied visual mesh**" rather than "produces a mesh".

### The rebuild you *do* need

Collision (and fluid) geometry is **baked** at `CreateMeshPartAsync` time. To refresh it:

```lua
-- Expensive. Do this ONCE per conceptual edit, not per vertex.
local rebuilt = AssetService:CreateMeshPartAsync(
	Content.fromObject(editableMesh),
	{ CollisionFidelity = Enum.CollisionFidelity.Box }
)
existingMeshPart:ApplyMesh(rebuilt)
```

`MeshPart:ApplyMesh(meshPart)` description, verbatim:

> Overwrites the `Class.MeshPart.MeshContent|MeshContent`, `Class.MeshPart.TextureContent|TextureContent`, and collision geometry properties of this `Class.MeshPart` from the given source `meshPart`.
>
> Most of these properties are read-only and cannot be changed during runtime on their own directly. To keep `Class.MeshPart.MeshContent|MeshContent` and physics data in sync, they must be updated together.
>
> Copies the following properties:
> - `Class.MeshPart.MeshContent` (implicitly updates `MeshId`)
> - `Class.MeshPart.TextureContent` (implicitly updates `TextureID`)
> - `Class.MeshPart.RenderFidelity`
> - `Class.MeshPart.CollisionFidelity` (with any internal collision geometry)
> - `Class.MeshPart.FluidFidelity` (with any internal aero geometry)
> - `Class.MeshPart.MeshSize`

Note `MeshSize` is in that list. **`MeshSize` does not track live vertex edits either** — if you deform a mesh outward, the part's `MeshSize` (and therefore its bounding box, and therefore streaming/culling behavior) stays at the value baked when the `MeshPart` was created, until you `ApplyMesh` a rebuilt part. `[UNVERIFIED]` for exactly what the engine does with a visually-larger-than-`MeshSize` mesh in between; the docs only state that `ApplyMesh` copies `MeshSize`.

### Multi-referencing

`EditableMesh.yaml`, lines 89–92:

> You can create more `Class.MeshPart` instances that reference the same `EditableMesh` `Datatype.Content`, or link to an existing `Class.MeshPart` through `Class.MeshPart:ApplyMesh()`.

One `EditableMesh` can back N `MeshPart`s. Since visual changes are live, **editing the mesh once visually updates all N parts at once**, for one mesh's worth of editable memory. The memory-limits section explicitly recommends this: *"in some scenarios, linking one `EditableMesh` to multiple `Class.MeshPart|MeshParts` (multi-referencing) can help with memory optimization."*

### The architectural rule this implies

> **Animate with mutation. Rebuild only when physics must agree.**

- Pure visual deformation (wind, water, morphs, LOD blending, damage decals as vertex color, breathing/pulsing shapes): mutate every frame. Zero `CreateMeshPartAsync` calls. This is cheap.
- Geometry the player collides with, that changes shape: mutate for the visual, then debounce a `CreateMeshPartAsync` + `ApplyMesh` rebuild — once per "conceptual edit", as the docs advise, not per method call.
- If collision precision is irrelevant (e.g. the part is a decorative shell, or you use an invisible simple-part collider alongside), you may never rebuild at all. **This is the single biggest performance lever in the whole API.**

A practical pattern — visual-now, physics-later:

```lua
local pendingRebuild = false

local function markDirty(mesh, part)
	if pendingRebuild then return end
	pendingRebuild = true
	task.defer(function()
		pendingRebuild = false
		local ok, rebuilt = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if ok and rebuilt then
			part:ApplyMesh(rebuilt)
			rebuilt:Destroy()
		end
	end)
end
```

---

## 3. Limits, `FixedSize`, and the memory budget

### Hard topology caps

`EditableMesh.yaml`, section **"Limitations"** (line 291), verbatim:

> `EditableMesh` currently has a limit of 60,000 vertices and 20,000 triangles. Attempting to add too many vertices or triangles will cause an error.

`AddVertex` restates it: *"An error is thrown if the mesh already contains 60,000 vertices."*

Read those numbers carefully — **they are not in a 3:1 ratio the way a triangle soup would be.** 20,000 triangles at 3 unshared vertices each would need 60,000 vertices, so the caps are exactly consistent with a fully-split (no shared vertices) mesh. In practice:

- A fully **welded** mesh (shared vertices, smooth shading) hits the **20,000-triangle** cap first — a closed manifold has roughly `V ≈ T/2`, so 20,000 triangles needs only ~10,000 vertices.
- A fully **split** mesh (every triangle has its own 3 vertices — what you get from naive voxel/marching-cubes output) hits **both caps at once**, at 20,000 triangles.
- Therefore **welding is worth doing** (`MergeVertices`) whenever you are near the cap, and `RemoveUnused()` after any removal pass.

**Plan for chunking from day one.** 20,000 triangles is small. Any terrain, voxel world, destructible building or large procedural structure must be split across multiple `EditableMesh` + `MeshPart` pairs. Size your chunk so that worst-case triangle count stays under ~18,000 with headroom.

### `FixedSize`

| | `CreateEditableMesh()` | `CreateEditableMeshAsync(content)` | `CreateEditableMeshAsync(content, {FixedSize=false})` |
|---|---|---|---|
| `FixedSize` | always `false` | **`true`** (default) | `false` |
| Can change vertex/attribute *values* | yes | yes | yes |
| Can add/remove vertices, faces, attributes | yes | **no** | yes |
| Can call `Clear()` | yes | **no** — throws | yes |
| Memory | higher | **lower** | higher |

The property itself is `ReadOnly` to scripts (`write: RobloxEngineSecurity`) and `ReadSafe`, so you can check `mesh.FixedSize` from parallel code but never assign it. **It is decided at creation and cannot be changed afterward** — if you need topology edits on an imported asset, you must pass `{FixedSize = false}` at load time, or re-load.

Why it exists, per the docs: *"Fixed-size meshes are more efficient in terms of memory but you cannot change the number of vertices, faces, or attributes. Only the values of vertex attributes and positions can be edited."* A fixed-size mesh can pack its data in flat, tightly-sized arrays because nothing will ever be inserted; a growable mesh needs slack and an ID-slot map.

**The practical read:** almost every *deformation* use case (character morphs, wind, water, terrain height animation, blend shapes, softbody) only needs `SetPosition` / `SetNormal` / `SetUV` / `SetColor`, so it should use the default `FixedSize = true` and save memory. Only *generative* use cases (build it from nothing, add/remove geometry at runtime) need `FixedSize = false`.

### The memory budget

`EditableMesh.yaml`, section **"Memory limits"**, verbatim:

> Editable assets are currently expensive for memory usage. To minimize its impact on client performance, `EditableMesh` has strict client-side memory budgets, although the server, Studio, and plugins operate with unlimited memory. Using `Class.EditableMesh.FixedSize|FixedSize` may help you stay within the memory budget and, in some scenarios, linking one `EditableMesh` to multiple `Class.MeshPart|MeshParts` (multi-referencing) can help with memory optimization.

`EditableImage.yaml` carries a word-for-word parallel section, confirming this is a **shared "editable assets" budget policy**, not a mesh-specific one — your `EditableImage` usage and your `EditableMesh` usage compete for the same allowance. `AssetService:CreateEditableImage` and `CreateEditableImageAsync` fail the same way.

Behavior at the cap:

> If the device-specific editable memory budget is exhausted, creation will fail and this method will return `nil`. — `AssetService:CreateEditableMesh` and `CreateEditableMeshAsync`

So the budget is enforced **at creation**, per device, by returning `nil`. It is *not* enforced by throwing, and it is *not* enforced mid-edit. You must null-check every creation call on the client.

> `[UNVERIFIED]` — **no numeric budget figure is published anywhere in `creator-docs`.** I searched the whole repository tree (9,368 files, `main` @ 2026-09-17): there is no `editable-assets` guide directory and no editable-assets memory-budget guide page; `content/en-us/studio/optimization/memory-usage.md` does not mention editable assets at all. The only official statements are the qualitative ones quoted above. Any specific MB number you find is community-sourced.
>
> `[COMMUNITY, SECOND-HAND]` DevForum threads titled "Editable mesh memory budget reached" exist, confirming developers hit the ceiling in practice on client devices. Treat any figure quoted there as unversioned folklore. Source: DevForum topic 3469104 (via web-search summary only; devforum.roblox.com is not directly reachable from this environment).

Defensive posture, since the number is unknown:

1. `Destroy()` every `EditableMesh` you are done with — *"Destroys the contents of the mesh, immediately reclaiming used memory."*
2. Prefer `FixedSize = true`.
3. Prefer multi-referencing one mesh from N `MeshPart`s over N meshes.
4. Do heavy editable work on the **server** or in a **plugin** where memory is unlimited, and ship the result down. (Subject to the replication caveat in [Gotchas](#gotchas) — you cannot replicate a `Content` `Object`.)
5. Null-check, and have a non-editable fallback path for low-memory devices.

---

## 4. Collision and fluid geometry

### The rule

Collision geometry is **baked into a `MeshPart` at `CreateMeshPartAsync` time** and does **not** follow live `EditableMesh` mutation. To refresh it, call `CreateMeshPartAsync` again and `ApplyMesh` the result onto the existing part. `ApplyMesh` copies `CollisionFidelity` *"(with any internal collision geometry)"* and `FluidFidelity` *"(with any internal aero geometry)"*. [EditableMesh.yaml, MeshPart.yaml]

### `CreateMeshPartAsync` options

```lua
AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh), {
	CollisionFidelity = Enum.CollisionFidelity.Box,       -- default: Enum.CollisionFidelity.Default
	RenderFidelity    = Enum.RenderFidelity.Precise,      -- default: Enum.RenderFidelity.Automatic
	FluidFidelity     = Enum.FluidFidelity.Automatic,     -- default: Enum.FluidFidelity.Automatic
})
```

All three default as listed *"if the option is absent or the `options` table is `nil`."* [AssetService.yaml]

### `Enum.CollisionFidelity` — all five values [CollisionFidelity.yaml]

| Value | Documented behavior | Cost profile for runtime geometry |
|---|---|---|
| `Default` (0) | *"voxel-based convex-hull decomposition that is relatively fast but may not be highly accurate, especially for holes, doorways, and cavities in general."* | Middle. The usual choice for static imported art; still a decomposition pass every rebuild. |
| `Hull` (1) | *"the convex hull of the visual mesh."* | Cheap-ish; wrong for anything concave. Good for rocks, debris, projectiles. |
| `Box` (2) | *"a bounding box that encompasses the visual mesh."* | **Cheapest.** The correct default for frequently-rebuilt geometry. |
| `PreciseConvexDecomposition` (3) | *"a convex-hull decomposition of the visual mesh which is computed by a variation of an algorithm called HACD. This option is the most accurate representation of collision geometry for complex objects with built-in tolerances to reduce the total number of convex-hulls by compromising on accuracy when justified."* | **Most expensive.** HACD on 20,000 triangles at runtime is not a per-frame operation. |
| `Tunable` (4) | *"Collision model that supports precision tuning of convex decomposition fidelity."* | Tunable via the part's tunable-collision properties. `[UNVERIFIED]` exactly which properties `CreateMeshPartAsync` lets you set for this mode — the options table documents only the enum. |

### The practical choice for large or frequently-changing geometry

> **Use `CollisionFidelity.Box` on the generated `MeshPart`, and carry real collision on separate, simple parts.**

Reasoning, all from the cited docs: (a) `CreateMeshPartAsync` yields and is the only way to rebuild collision; (b) `PreciseConvexDecomposition` is explicitly the most expensive fidelity; (c) the docs already advise rebuilding *"at the end of a conceptual edit, not after individual calls"*. So a shape that changes many times a second simply cannot afford accurate mesh collision.

Concrete patterns:

- **Terrain / heightmap chunk:** visual `MeshPart` with `CollisionFidelity.Box` and `CanCollide = false`; a separate invisible collider (a grid of `Part`s, or a wedge mesh at coarse resolution rebuilt on a slow cadence). Or use real Roblox `Terrain` for collision and `EditableMesh` only for the visual skin.
- **Destructible structure:** rebuild collision only at the moment a chunk's state settles, not while the destruction animation plays.
- **Deforming creature / softbody:** collision stays a simple capsule or box the whole time; nobody notices.
- **Player-built geometry:** rebuild once at "place confirmed", never during preview.

### Fluid fidelity [FluidFidelity.yaml]

| Value | Meaning |
|---|---|
| `Automatic` (0) | *"Let the physics engine select the geometric representation for aerodynamic force and torque calculations."* |
| `UseCollisionGeometry` (1) | *"Use the current collision geometry specified by `TriangleMeshPart.CollisionFidelity` for aerodynamic force and torque calculations."* |
| `UsePreciseGeometry` (2) | *"Force the engine to compute aerodynamic forces and torques using a more precise geometry representation based on the original mesh. This option may increase join and replication time if used on a large scale."* |

Leave it `Automatic` unless the object flies. `UsePreciseGeometry` carries an explicit join/replication-time warning at scale.

---

## 5. Spatial queries and traversal

All query methods are `thread_safety: Safe` — they may be called from parallel Luau. All inputs and outputs are in the **mesh's local object space**, never world space. You must transform yourself with the `MeshPart`'s `CFrame`.

### Ray and proximity

| Method | Signature | Returns (exact order) |
|---|---|---|
| `RaycastLocal` | `(origin: Vector3, direction: Vector3) -> Tuple` | `point, faceId, barycentric` |
| `FindClosestPointOnSurface` | `(point: Vector3) -> Tuple` | `faceId, point, barycentric` |
| `FindClosestVertex` | `(toThisPoint: Vector3) -> int64` | the closest vertex ID |
| `FindVerticesWithinSphere` | `(center: Vector3, radius: float) -> Array` | list of vertex IDs inside the sphere |

`RaycastLocal` description: *"Casts a ray and returns a point of intersection, face ID, and barycentric coordinates. The inputs and outputs of this method are in the mesh's local object space."* Plus: *"A **barycentric coordinate** is a way of specifying a point within a face as a weighted combination of the 3 vertices of the face. This is useful as a general way of blending vertex attributes."*

**Skinned-mesh caveat — stated identically on all four:** *"When the mesh is skinned, this query operates against the bind-pose geometry, not the deformed mesh as it appears at runtime."* So you cannot raycast a skinned character's *animated* silhouette with `RaycastLocal`; you get the T-pose. For animated hit detection you still need normal `Workspace:Raycast`.

World-space wrapper:

```lua
local function worldRaycast(meshPart, editableMesh, worldOrigin, worldDir)
	local inv = meshPart.CFrame:Inverse()
	local localOrigin = inv * worldOrigin
	local localDir = inv:VectorToWorldSpace(worldDir)      -- rotate only, no translation
	local point, faceId, bary = editableMesh:RaycastLocal(localOrigin, localDir)
	if not faceId then return nil end
	return meshPart.CFrame * point, faceId, bary
end
```

Barycentric blending — the canonical use — reads an attribute at an arbitrary surface point:

```lua
local point, faceId, bary = mesh:RaycastLocal(origin, dir)
local uvIds = mesh:GetFaceUVs(faceId)
local uv = mesh:GetUV(uvIds[1]) * bary.X
        + mesh:GetUV(uvIds[2]) * bary.Y
        + mesh:GetUV(uvIds[3]) * bary.Z
```

### Bounds

| Method | Returns |
|---|---|
| `GetCenter() -> Vector3` | *"the center of the mesh's axis-aligned bounding box, in the mesh's local object space."* |
| `GetSize() -> Vector3` | *"the size of the mesh's axis-aligned bounding box, in the mesh's local object space."* |

These are **live on the `EditableMesh`**, unlike `MeshPart.MeshSize`, which is only refreshed by `ApplyMesh`. Use `GetSize()` when you need the true current extent of a mesh you have been deforming.

### Topology traversal

| Method | Returns |
|---|---|
| `GetVertices() -> Array` | *"all vertex IDs... The IDs may not be contiguous. Use this list to iterate over vertices safely, rather than assuming consecutive numbering."* |
| `GetFaces() -> Array` | all face IDs |
| `GetNormals()` / `GetUVs()` / `GetColors()` | all IDs in each attribute space |
| `GetFaceVertices(faceId) -> Array` | the 3 vertex IDs, **in winding order** |
| `GetFaceNormals` / `GetFaceUVs` / `GetFaceColors` `(faceId) -> Array` | the 3 per-corner attribute IDs, same order as `GetFaceVertices` |
| `GetVertexFaces(vertexId) -> Array` | *"all faces that have the given vertex as one of their corners. Use this to traverse the mesh topology around a vertex, for example to find all faces affected by moving a vertex."* |
| `GetVertexNormals` / `GetVertexUVs` / `GetVertexColors` `(vertexId) -> Array` | every attribute ID used at any corner touching that vertex — i.e. **this is how you detect a seam**: `#ids > 1` means the vertex is split for that attribute |
| `GetAdjacentFaces(faceId) -> Array` | faces adjacent to a face |
| `GetAdjacentVertices(vertexId) -> Array` | vertices adjacent to a vertex (the one-ring) |
| `GetVertexFaceNormal` / `GetVertexFaceUV` / `GetVertexFaceColor` `(vertexId, faceId) -> int64` | the single attribute ID at one specific corner |
| `GetFacesWithNormal` / `GetFacesWithUV` / `GetFacesWithColor` `(id) -> Array` | reverse lookup: which faces use this attribute ID |
| `GetVerticesWithNormal` / `GetVerticesWithUV` / `GetVerticesWithColor` `(id) -> Array` | reverse lookup: which vertices use this attribute ID |

Note `GetVertexFaces` + `GetAdjacentVertices` + the reverse lookups give you a full half-edge-equivalent traversal without maintaining your own adjacency structure. That is worth a lot: mesh smoothing, flood fills, region selection, normal recomputation, and marking "dirty" neighborhoods after a local edit are all straightforward.

Value getters (nilable — they return `nil` for an invalid ID rather than throwing):

| Method | Returns |
|---|---|
| `GetPosition(vertexId) -> Vector3` | (not nilable in the YAML) |
| `GetNormal(normalId) -> Vector3?` | |
| `GetUV(uvId) -> Vector2?` | |
| `GetColor(colorId) -> Color3?` | |
| `GetColorAlpha(colorId) -> float?` | |

---

## 6. Skinning, bones, and FACS

**Yes — bone/joint weight data is fully supported.** This is a genuine skinned-mesh authoring API, not just a static-geometry one.

### Bones

| Method | Notes |
|---|---|
| `AddBone(boneProperties: Dictionary) -> int64` | Options: `Name` (string, unique within the mesh, max 100 chars), `ParentId` (optional bone ID), `CFrame` (bind-pose `CFrame`, mesh local space), `Virtual` (boolean). *"Adds a new bone to the mesh and returns a bone ID that persists across topology changes."* Throws if the name is taken, the parent ID is invalid, or the bone cap is reached. |
| `GetBones() -> Array` | all bone IDs |
| `GetBoneByName(name) -> int64` | *"Errors if no bone with that name exists."* |
| `GetBoneName` / `SetBoneName` | |
| `GetBoneParent(boneId) -> int64` | *"If the bone has no parent, returns `0`."* |
| `SetBoneParent(boneId, parentBoneId)` | *"Pass a valid bone ID to parent the bone, or `0` to make it a root bone. The engine validates that the new parent does not create a cycle in the bone hierarchy and throws an error if the parent ID is invalid or would produce a circular dependency."* |
| `GetBoneCFrame` / `SetBoneCFrame` | *"initial `CFrame` of the bone in the bind pose of the mesh, in the mesh's local space."* |
| `GetBoneIsVirtual` / `SetBoneIsVirtual` | *"Virtual bones can only be bound to a `Class.FaceControls` instance."* |
| `RemoveBone(boneId)` | *"Any vertex skinning weights that referenced the removed bone are also cleared."* |

### Skin weights

| Method | Notes |
|---|---|
| `SetVertexBones(vertexId, boneIDs: Array)` | *"This method should be called **before** calling `SetVertexBoneWeights()`."* |
| `SetVertexBoneWeights(vertexId, boneWeights: Array)` | *"This method should be called **after** calling `SetVertexBones()`."* |
| `GetVertexBones(vertexId) -> Array` | **"A vertex can be influenced by up to 4 bones."** Index-aligned with the weights array. |
| `GetVertexBoneWeights(vertexId) -> Array` | *"blend weights (each between `0` and `1`)"*, index-aligned with the bone array. |

So the influence limit is the industry-standard **4 bones per vertex**, and the ordering contract is strict: bones first, weights second. `GetVertexBoneWeights(v)[i]` is the weight for `GetVertexBones(v)[i]`.

`MeshPart.HasSkinnedMesh` (hidden, read-only) reports *"whether the mesh currently applied to the `MeshPart` contains skinning (bone and joint) data."*

`[UNVERIFIED]` — the docs do not state whether skin weights survive a `FixedSize = true` load, nor whether `Bone` instances in the DataModel auto-bind to `EditableMesh` bones by name at `ApplyMesh` time. Test before committing to a runtime-rigging pipeline.

### FACS (facial animation)

Full authoring surface for animatable heads, per `EditableMesh.yaml`'s **"FACS poses"** section:

> Each FACS pose is specified by an `Enum.FacsActionUnit` value. For the FACS pose, virtual bones can each have a `Datatype.CFrame` that transforms the bones' initial `Datatype.CFrame` in the bind pose of the mesh into the `Datatype.CFrame` for that FACS action unit's pose. All bone `Datatype.CFrame|CFrames` are in the mesh's local space.

| Method | Notes |
|---|---|
| `GetFacsPoses() -> Array` | *"all base FACS poses currently defined on this mesh"*, as `Enum.FacsActionUnit` values |
| `GetFacsPose(action) -> Tuple` | returns **array of bone IDs, array of corresponding bone `CFrame`s** |
| `SetFacsPose(action, boneIds, cframes)` | *"All referenced bones must be virtual (non-virtual bones throw an error). This replaces any previously defined pose for the given action unit."* Arrays must be equal length. |
| `SetFacsBonePose(action, boneId, cframe)` | incremental single-bone edit within a pose; *"The bone must be virtual."* |
| `GetFacsCorrectivePoses() -> Array` | each entry is an array of **2 or 3** `Enum.FacsActionUnit` values |
| `GetFacsCorrectivePose(actions) -> Tuple` | bone IDs + `CFrame`s for that combination |
| `SetFacsCorrectivePose(actions, boneIds, cframes)` | *"overrides the blended result of 2 or 3 base poses when they are active simultaneously... Throws if the action combination is not a valid corrective."* |

Documented limitation, verbatim: *"corrective poses that operate on both left and right action units are not currently expressible. For example, using `LeftCheekPuff` and `RightEyeClosed` together in a corrective pose is not currently possible."*

---

## 7. Batch operations

`EditableMesh.yaml`, section **"Batching"**, verbatim:

> The **batch** methods let you create, read, update, and remove many mesh elements in a single call instead of invoking the singular methods (`AddVertex()`, `SetPosition()`, `GetColor()`, and so on) once per element. **Batching your mesh operations is typically much more performant than handling them one by one.**
>
> Rather than one method per attribute, each batch method shares a small set of general entry points and uses an `Enum.MeshAttribute` value (or the type already encoded in each mesh ID) to determine which attribute you mean. For example, `BatchSetValues()` sets positions when called with vertex IDs, but sets normals when called with normal IDs. **You cannot mix-and-match ID types within a single call.**
>
> Batch setters take parallel arrays: element `i` of every argument array describes the same logical operation. In `BatchSetValues(ids, values)`, `values[i]` is written to `ids[i]`. **All argument arrays must be the same length or the call errors.** Batch getters take an array of IDs and return results in the same order.
>
> **If a mesh ID is invalid, batching still applies updates to all elements before the invalid ID, then stops.**

That last sentence is a trap: **batch operations are not atomic.** A bad ID halfway through leaves the mesh half-updated and does not report which index failed. Validate IDs before batching, or keep batches small enough to reason about.

### `Enum.MeshAttribute` [MeshAttribute.yaml]

| Value | # | Meaning |
|---|---|---|
| `Vertex` | 0 | per-element vertex position, `Vector3` in object space |
| `Normal` | 1 | per-element surface normal, `Vector3` |
| `Color` | 2 | per-element `Color3` plus a float alpha |
| `UV` | 3 | per-element `Vector2` texture coordinate |
| `Face` | 4 | the face channel — topology elements connecting vertex positions into triangles |

### The batch methods, with their exact data shapes

```lua
-- CREATE. Always needs an explicit MeshAttribute (raw values have no IDs to inspect).
local vIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)     -- positions: {Vector3}
local nIds = mesh:BatchAdd(Enum.MeshAttribute.Normal, normals)       -- normals:   {Vector3}
local uIds = mesh:BatchAdd(Enum.MeshAttribute.UV, uvs)               -- uvs:       {Vector2}
local cIds = mesh:BatchAdd(Enum.MeshAttribute.Color, colors, alphas) -- {Color3}, {number}
local fIds = mesh:BatchAdd(Enum.MeshAttribute.Face, {
	{vIds[1], vIds[2], vIds[3]},
	{vIds[1], vIds[3], vIds[4]},
})
-- Throws "if the attribute type is invalid, the data format does not match, or
--  adding the elements would exceed mesh limits."

-- READ VALUES. Attribute inferred from the ID type.
local positions = mesh:BatchGetValues(vertexIds)     -- {Vector3}
local normals   = mesh:BatchGetValues(normalIds)     -- {Vector3}
local uvs       = mesh:BatchGetValues(uvIds)         -- {Vector2}
local colors, alphas = mesh:BatchGetValues(colorIds) -- {Color3}, {number}
-- Second return value is nil for every type EXCEPT color.

-- WRITE VALUES.
mesh:BatchSetValues(vertexIds, positions)
mesh:BatchSetValues(normalIds, normals)
mesh:BatchSetValues(uvIds, uvs)
mesh:BatchSetValues(colorIds, colors)   -- {Color3} sets colors
mesh:BatchSetValues(colorIds, alphas)   -- {number} sets alphas  (mixing types in one call is an error)
mesh:BatchSetValues(normalIds, nil)     -- resets each normal to auto-computed

-- PER-FACE CORNER ATTRIBUTE IDs. result[i] is the array of IDs at faceIds[i]'s corners,
-- in the same order as GetFaceVertices().
local faceNormals = mesh:BatchGetFaceAttributes(Enum.MeshAttribute.Normal, faceIds) -- {{normalId}}
local faceVerts   = mesh:BatchGetFaceAttributes(Enum.MeshAttribute.Vertex, faceIds) -- {{vertexId}}
mesh:BatchSetFaceAttributes(faceIds, { {n1,n2,n3}, {n4,n5,n6} })

-- PER-VERTEX GATHER: every attribute ID across all faces touching each vertex.
local adjFaces = mesh:BatchGetVertexAttributes(Enum.MeshAttribute.Face, vertexIds) -- {{faceId}}

-- SINGLE CORNER, identified by a (vertex, face) pair.
local cornerColors = mesh:BatchGetVertexFaceAttributes(Enum.MeshAttribute.Color, vertexIds, faceIds)
mesh:BatchSetVertexFaceAttributes(vertexIds, faceIds, colorIds)

-- DELETE. Same cleanup semantics as RemoveFace: attributes are not auto-deleted.
mesh:BatchRemove(faceIds)
mesh:RemoveUnused()
```

All batch methods carry `tags: [CustomLuaState]` (they marshal raw Luau tables directly). All batch **getters** are `Safe`; all batch **setters and `BatchAdd`/`BatchRemove`** are `Unsafe`.

---

## 8. Performance and parallelism

### Thread-safety metadata — the exact split

From `EditableMesh.yaml`: **53 methods are `Safe`, 41 are `Unsafe`.** The line is drawn with total consistency:

- **Every single `Get*`, `Find*`, `Batch*Get*` method and `RaycastLocal` is `Safe`.** (Zero exceptions — I checked all 94.)
- **Every mutator is `Unsafe`**: all `Add*`, `Set*`, `Remove*`, `Batch*Set*`, `BatchAdd`, `BatchRemove`, `Clear`, `Destroy`, `Triangulate`, `MergeVertices`, `ResetNormal`.
- `IdDebugString` is `Unsafe` (it is a debug formatter, do not call it in parallel).
- The `FixedSize` property is `ReadSafe`.
- `AssetService:CreateEditableMesh`, `CreateEditableMeshAsync` and `CreateMeshPartAsync` are all `Unsafe`.

Roblox's own definition of those levels [multithreading.md]:

| Safety level | For properties | For functions |
|---|---|---|
| **Unsafe** | Cannot be read or written in parallel. | Cannot be called in parallel. |
| **Read Parallel** | Can be read but not written in parallel. | N/A |
| **Local Safe** | Can be used within the same `Actor`; can be read but not written to by other `Actor`s in parallel. | Can be called within the same `Actor`; cannot be called by other `Actor`s in parallel. |
| **Safe** | Can be read and written. | Can be called. |

And: *"If an API member doesn't specify a thread safety level, by default its thread safety level is **Unsafe**."*

### The parallel pattern this dictates

**Read/analyze in parallel; write in serial.** This is exactly the shape Parallel Luau wants.

```lua
-- Inside a script under an Actor
local function rebuildChunk(mesh, params)
	-- PARALLEL PHASE: pure computation + Safe reads. No mutation allowed here.
	task.desynchronize()
	local vertexIds = mesh:GetVertices()            -- Safe
	local oldPositions = mesh:BatchGetValues(vertexIds)  -- Safe
	local newPositions = table.create(#oldPositions)
	for i, p in ipairs(oldPositions) do
		newPositions[i] = computeDisplacement(p, params)  -- pure Luau, the expensive bit
	end

	-- SERIAL PHASE: one batched write.
	task.synchronize()
	mesh:BatchSetValues(vertexIds, newPositions)    -- Unsafe -> must be serial
end
```

The win is real because the *expensive* part of procedural geometry — noise, SDF evaluation, marching cubes, spline math, physics integration — is pure arithmetic on plain tables, which parallelizes perfectly. Only the final `BatchSetValues` must be serial, and it is one call.

You can also run `RaycastLocal` / `FindClosestPointOnSurface` / `FindVerticesWithinSphere` across many actors simultaneously against a shared mesh — all `Safe`. That makes `EditableMesh` a genuinely good spatial-query structure for things like multi-agent sensing.

### Cost of building N triangles

`[UNVERIFIED]` — **Roblox publishes no timing figures for `AddVertex`/`AddTriangle`/`BatchAdd`/`CreateMeshPartAsync`.** What the documentation does assert, which is all you can build on:

1. *"Batching your mesh operations is typically much more performant than handling them one by one."* → prefer `BatchAdd` + `BatchSetValues` over per-element calls, always.
2. Changing values in place *"is more performant and avoids leaving unused IDs in the mesh"* than creating new attribute IDs. → reuse IDs when you can.
3. *"It's generally recommended to do this [`CreateMeshPartAsync` + `ApplyMesh`] at the end of a conceptual edit, not after individual calls to methods that manipulate geometry."* → `CreateMeshPartAsync` is the expensive operation, by the engine team's own framing.
4. `CreateMeshPartAsync` is tagged `Yields`, so it never blocks a frame outright, but it does cost a scheduler round trip and cannot be called from parallel code.

The defensible model: **per-element Luau→C++ boundary crossings dominate build cost; the collision bake dominates rebuild cost.** Measure with the MicroProfiler rather than trusting any number you read online.

### Time-slicing and chunking patterns

Because a single mesh caps at 20,000 triangles and `CreateMeshPartAsync` yields, large worlds must be built incrementally.

**(a) Budgeted build loop** — never exceed a frame budget:

```lua
local BUDGET_SECONDS = 1 / 240  -- ~4ms of a 60Hz frame

local function buildInSlices(mesh, triangles)
	local t0 = os.clock()
	local i = 1
	while i <= #triangles do
		-- Push a bounded batch, then yield if we're over budget.
		local stop = math.min(i + 255, #triangles)
		local slice = table.move(triangles, i, stop, 1, {})
		mesh:BatchAdd(Enum.MeshAttribute.Face, slice)
		i = stop + 1
		if os.clock() - t0 > BUDGET_SECONDS then
			task.wait()
			t0 = os.clock()
		end
	end
end
```

**(b) Chunk grid.** One `EditableMesh` + one `MeshPart` per spatial cell. Cell size chosen so worst-case triangles stay under ~18,000. Rebuild only dirty cells. This also gives you free frustum culling and streaming, because each chunk is an independent `MeshPart`.

**(c) Double-buffering to avoid a visible pop.** Because visual changes are live, you can build a *new* `EditableMesh` off-screen, then swap by creating a `MeshPart` from it and calling `ApplyMesh` on the visible part — one atomic-looking swap instead of watching the mesh assemble itself.

**(d) Deform, don't rebuild.** If the *topology* is constant and only positions change, allocate once with `FixedSize` and never touch `CreateMeshPartAsync` again. This is by far the cheapest dynamic-geometry mode the API offers.

### Draw calls

Each `MeshPart` is its own object. Merging many small pieces into one `EditableMesh` — as in [Recipe 3](#recipe-3-merge-many-pieces-into-one-mesh) — trades the 20,000-triangle cap against the number of instances the renderer must handle. That is usually the right trade for static scenery and the wrong trade for anything that needs independent movement, independent collision, or independent streaming.

---

## 9. Saving and uploading

**Yes — a runtime-generated `EditableMesh` can become a permanent Roblox asset, but only from a plugin or Open Cloud, never from a running experience.**

### `AssetService:CreateAssetAsync(object, assetType, requestParameters) -> Tuple`

`AssetService.yaml`, verbatim: *"Uploads a new asset to Roblox from the given object. **Currently, this method can only be used in locally loaded plugins and uploads assets without prompting first.**"*

Supported types include, verbatim:

> - `Enum.AssetType.Mesh` – with `object` as any valid `Class.EditableMesh` root.
> - `Enum.AssetType.Image` – with `object` as any valid `Class.EditableImage` root.

`requestParameters`: `Name` (defaults to `[object.Name]`), `Description` (defaults to `"Created with AssetService:CreateAssetAsync"`), `CreatorId` (defaults to the logged-in Studio user in Plugin context; **required** for Open Cloud Luau Execution), `CreatorType` (`Enum.AssetCreatorType`, defaults to `User` in Plugin context; **required** for Open Cloud), `IsPackage` (Model only).

Returns *"The `Enum.CreateAssetResult` and asset ID pair if successful."* Tagged `Yields`, `capabilities: [AssetCreateUpdate]`.

`AssetService:CreateAssetVersionAsync(object, assetType, assetId, requestParameters)` does the same for a new version of an existing asset, with the same plugin-only restriction and the same `Mesh`/`EditableMesh` support.

**So the production pipeline is:** generate in a **plugin** (or Open Cloud Luau Execution) at edit time → `CreateAssetAsync` with `Enum.AssetType.Mesh` → you now have a normal mesh asset ID that loads like any other, with no verification gate and no editable-memory cost at runtime. That is the correct architecture for anything that does not truly need to vary per-session.

**What you cannot do:** a `Script`/`LocalScript` in a live experience cannot persist generated geometry as an asset. Runtime-generated meshes are session-local.

### `AssetService:CreateDataModelContentAsync(content, options?) -> Tuple`

A distinct, less-known method: *"Creates ephemeral, `Class.DataModel`-scoped content from the provided content input."* Its `content` parameter *"currently only supports `Datatype.Content` wrapping a `Class.EditableMesh` or `Class.EditableImage`."*

Returns *"a tuple containing an `Enum.CreateContentResult` indicating the success or failure of the request, and the resulting `Class.DataModel`-scoped `Enum.ContentSourceType|Opaque` `Datatype.Content`."* On failure: *"If the server storage budget is exhausted during this call, the creation will fail and the method will return `Enum.CreateContentResult.StorageLimitExceeded` alongside an empty `Datatype.Content` object."* Tagged `Yields`, `capabilities: [DynamicGeneration]`.

This converts a live `EditableMesh` into an **`Opaque`** `Content` scoped to the `DataModel` — a frozen, engine-managed snapshot rather than a live editable object, bounded by a **server storage budget** (distinct from the client editable-memory budget).

> `[UNVERIFIED]` — **whether `Opaque` `DataModel`-scoped `Content` replicates from server to client.** The `Content` datatype doc only states that **`Object`** values do not replicate. Given that `CreateDataModelContentAsync` is server-callable, yields, is bounded by a *server storage* budget, and produces a non-`Object` source type, it looks very much like the intended server→client path for generated geometry — but the documentation does not say so. **Test this before designing around it.** If it works, it is the answer to "how do I generate on the server and show it to everyone."

---

## Gotchas

### G1. Winding order decides which side you see

`EditableMesh.yaml`, section **"Winding"**, verbatim:

> Mesh faces have a front side and a back side. When drawing meshes, only the front of the faces are drawn by default, although you can change this by setting the mesh' `Class.MeshPart.DoubleSided|DoubleSided` property to `true`.
>
> The order of the vertices around the face determines whether you are looking at the front or the back. **The front of the face is visible when the vertices go counterclockwise around it.**

So: **counter-clockwise as seen from the front = visible.** The classic symptom of getting it wrong is a mesh that looks fine from inside and invisible from outside, or a cube missing three faces. Fixes: reverse the argument order to `AddTriangle`, or set `MeshPart.DoubleSided = true` (which doubles what the rasterizer draws — a real cost, not a free fix).

`SetFaceVertices(faceId, ids)` *"Replaces the vertex IDs at each corner of the given face, in winding order. The existing normal, UV, and color attributes on each corner are preserved."* — so you can flip a face in place without rebuilding its attributes.

### G2. Every UV starts at (0,0)

`AddTriangle` gives brand-new vertices *"UV coordinate of `(0, 0)`"*. A from-scratch mesh with a texture applied will show the single texel at the texture's origin stretched over the entire surface — which reads as a flat solid color and is very often misdiagnosed as "textures don't work on EditableMesh". **You must set UVs explicitly.**

`[UNVERIFIED]` — the docs never state the UV origin convention (whether `V=0` is the top or bottom of the image). The `Winding.png` diagram is the only visual, and it covers winding, not UVs. Determine empirically with an asymmetric test texture before authoring a UV layout.

### G3. Everything is smooth unless you make it sharp

Because `AddTriangle` *reuses* a vertex's existing normal ID, a cube built naively renders as a lumpy rounded blob. Hard edges require one normal ID per face (see [§2.4](#24-hard-edges)). The `makeSharpCube` sample in `EditableMesh.yaml` is the reference implementation and is reproduced in [Recipe 2](#recipe-2-a-sharp-cube).

### G4. `Content` `Object` values do not replicate — cyan/magenta checkerboard

`Content.yaml`, **Warning**, verbatim:

> Replication is not yet supported for `Datatype.Content.Object|Object` values. When an `Class.Instance` with a `Datatype.Content` property containing a `Datatype.Content.Object|Object` value is replicated, an unusable placeholder `Class.Object` of the same type will be used instead of the `Class.Object` itself, and any attempt to read or write the contents of that placeholder object will throw. These placeholder objects will render as a cyan and magenta checkerboard pattern.
>
> This will be replaced with standard replication behavior in the future. For now, **do not use `Class.EditableImage` or `Class.EditableMesh` as `Datatype.Content` on the server on an `Class.Instance` that can replicate to clients.**

**This is the #1 architectural landmine.** If you build a mesh on the server and parent the `MeshPart` into `Workspace`, every client sees a magenta/cyan checkerboard. Runtime-generated geometry is effectively **client-side**: replicate the *parameters* (seed, heightfield, edit list) over a `RemoteEvent` and have each client build its own `EditableMesh` deterministically. Keep the server authoritative over gameplay state with ordinary parts or raw data, not over the mesh object.

### G5. `FixedSize` silently blocks the operation you wanted

`CreateEditableMeshAsync` defaults to `FixedSize = true`. If you load a mesh to subdivide it, cut a hole in it, or `Clear()` it, you must pass `{FixedSize = false}`. `Clear()` explicitly *"cannot be called on a fixed-size mesh... Attempting to do so throws an error."*

### G6. Batch operations are not atomic

*"If a mesh ID is invalid, batching still applies updates to all elements before the invalid ID, then stops."* No exception index, no rollback.

### G7. `RemoveFace` leaks

Vertices and attributes of a removed face survive. Long-lived meshes that add and remove geometry will drift toward the 60,000-vertex cap unless you call `RemoveUnused()` on a cadence. `RemoveUnused()` returns the removed IDs so you can purge your own lookup tables in the same pass.

### G8. Tuple orders differ between `RaycastLocal` and `FindClosestPointOnSurface`

`(point, faceId, bary)` vs `(faceId, point, bary)`. Wrap both once. (See [Verified API surface](#verified-api-surface).)

### G9. Queries see the bind pose on skinned meshes

All four `Find*`/`Raycast*` methods: *"When the mesh is skinned, this query operates against the bind-pose geometry, not the deformed mesh as it appears at runtime."*

### G10. `MeshPart.MeshSize` and collision are stale until `ApplyMesh`

Live visuals mislead you into thinking everything updated. Bounding box, collision geometry and aero geometry are all baked. `EditableMesh:GetSize()` is live; `MeshPart.MeshSize` is not.

### G11. `RenderFidelity` / LOD

`Enum.RenderFidelity` [RenderFidelity.yaml] with `Automatic` (the `CreateMeshPartAsync` default):

| Distance from camera | Fidelity used |
|---|---|
| < 250 studs | Highest |
| 250–500 studs | Medium |
| ≥ 500 studs | Lowest |

`Precise` renders *"in the highest fidelity regardless of its distance from the camera."* `Performance` will *"push performance as much as possible... discarding appearance if that's necessary."*

Implication: a procedurally-detailed mesh viewed from 300 studs is being decimated by the engine, and your careful vertex work is invisible. If the LOD reduction is what is making your generated mesh look wrong at range, pass `RenderFidelity = Enum.RenderFidelity.Precise`. `[UNVERIFIED]` whether the engine generates LODs for an `EditableMesh`-backed `MeshPart` at all, or whether `Automatic` degrades to something else when there is no pre-baked LOD chain; the docs describe `RenderFidelity` only in terms of imported meshes.

### G12. `SurfaceAppearance` overrides the texture, not the geometry

`SurfaceAppearance` *"Applies PBR textures to the mesh surface and doesn't affect its geometry."* [meshes.md] Its maps can be driven at runtime from `EditableImage` via `AssetService:CreateSurfaceAppearanceAsync(content)` — note its caveat: *"the `Class.EditableImage` assigned to each map cannot be reassigned or swapped after the `Class.SurfaceAppearance` is created."* Also: *"most `Class.SurfaceAppearance` properties cannot be modified by scripts, as the necessary pre-processing is usually too expensive during runtime."* [SurfaceAppearance.yaml]

`[UNVERIFIED]` — **how `EditableMesh` vertex colors interact with `SurfaceAppearance`, `MeshPart.Color`, `TextureContent` and `MaterialVariant`.** The `EditableMesh` docs establish that per-corner colors with alpha exist and are settable, but nowhere in `creator-docs` is it stated how they are blended with (or overridden by) the part's material/texture stack. This is a real, documented-nowhere gap. Verify empirically with a plain white texture before relying on vertex color for gameplay-visible information (team tint, damage, biome blending).

### G13. Mobile

The memory budget is described as *"device-specific"* and *"client-side"*, with server/Studio/plugins unlimited. That means **Studio will never reproduce a mobile failure.** Test on a real low-end device, and always handle `CreateEditableMesh*` returning `nil` by falling back to a static asset.

### G14. What stale tutorials get wrong

- **"`EditableMesh` is a beta you enable in Studio's Beta Features."** It shipped; the gate is now age+ID verification plus the Creator Dashboard **Enable Mesh / Image APIs** toggle, per the current `EditableMesh.yaml`.
- **"Call `AssetService:CreateEditableMesh(meshId)`."** Obsolete. The parameterized form is `CreateEditableMeshAsync(Content...)`; `CreateEditableMesh` takes only an options table.
- **"Set `meshPart.MeshId = ...` / assign the `EditableMesh` to `MeshContent`."** `MeshContent` and `MeshId` are read-only at runtime. Use `CreateMeshPartAsync` + `ApplyMesh`.
- **"You must call `CreateMeshPartAsync` after every edit to see the change."** False. *"Visual changes to the mesh will always be immediately reflected by the engine, without the need to call `AssetService:CreateMeshPartAsync()`."* You only rebuild for **collision** and **fluid** geometry.
- **"`GetVerticesWithAttribute` / `GetFacesWithAttribute`."** Both are now `Deprecated` — *"Do not use it for new work."*
- **"Iterate vertices 1..N."** IDs are stable and sparse. Iterate `GetVertices()`.
- **"Limit is 20,000 vertices."** It is **60,000 vertices and 20,000 triangles.**
- **"Set vertex normals per vertex."** Normals are per **face corner**, not per vertex.
- **Any per-element `AddVertex` loop in a 2023–2024 tutorial.** The `Batch*` family exists now and the docs say it is *"typically much more performant."*

---
## Community addenda

`[COMMUNITY, SECOND-HAND]` — from web-search summaries of DevForum threads only; `devforum.roblox.com` is not directly reachable from this environment, so these are not first-hand quotes and are not in the official docs.

- **Vertex color and `SurfaceAppearance` are reported to be mutually exclusive.** Community reports state that vertex coloring affects only Roblox materials/textures and has **no effect** when a `SurfaceAppearance` is present — i.e. you cannot combine a PBR-mapped mesh with vertex colors. If true, this is decisive for any design that wanted per-vertex tinting on a PBR surface. Sources (titles only): "SurfaceAppearence ColorMap does not respect baked vertex colors" (DevForum 985602); "Vertex Coloring Support for SurfaceAppearance" (DevForum 3981469) — filed as a *feature request*, which implies it is still unsupported.
- **Vertex colors reported not to render inside `ViewportFrame`** (DevForum 4433191, Feb 2026), while rendering correctly in `Workspace`. Relevant if you preview generated meshes in UI.
- **Developers do hit the editable memory ceiling on client devices**: "Editable mesh memory budget reached" (DevForum 3469104).
- There is active documentation feedback on `EditableMesh:AddColor` (DevForum 4620152), suggesting the color API's behavior is still a common point of confusion.

Treat all four as hypotheses to verify in-engine, not as facts.

---

## Worked recipes

All recipes are genre-neutral and assume:

```lua
local AssetService = game:GetService("AssetService")
```

### Recipe 1: a correct quad

Two triangles, counter-clockwise from the front, with a proper 0–1 UV square and no wasted attribute IDs.

```lua
-- Returns the face IDs of the quad (v0,v1,v2,v3 given counter-clockwise from the front).
local function addQuad(mesh, v0, v1, v2, v3, uv0, uv1, uv2, uv3)
	local f1 = mesh:AddTriangle(v0, v1, v2)
	local f2 = mesh:AddTriangle(v0, v2, v3)

	-- Set UVs in place on the auto-created IDs: cheaper, and leaves no orphan IDs.
	-- NOTE: corner (vertex, face) pairs, because UVs are per-corner, not per-vertex.
	mesh:SetUV(mesh:GetVertexFaceUV(v0, f1), uv0)
	mesh:SetUV(mesh:GetVertexFaceUV(v1, f1), uv1)
	mesh:SetUV(mesh:GetVertexFaceUV(v2, f1), uv2)
	mesh:SetUV(mesh:GetVertexFaceUV(v0, f2), uv0)
	mesh:SetUV(mesh:GetVertexFaceUV(v2, f2), uv2)
	mesh:SetUV(mesh:GetVertexFaceUV(v3, f2), uv3)

	return f1, f2
end

local function makeQuad(size)
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then return nil end
	local h = size / 2
	local v0 = mesh:AddVertex(Vector3.new(-h, -h, 0))
	local v1 = mesh:AddVertex(Vector3.new( h, -h, 0))
	local v2 = mesh:AddVertex(Vector3.new( h,  h, 0))
	local v3 = mesh:AddVertex(Vector3.new(-h,  h, 0))
	addQuad(mesh, v0, v1, v2, v3,
		Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(1, 1), Vector2.new(0, 1))
	return mesh
end
```

Note the diagonal: both triangles share `v0` and `v2`, so `f2`'s corners at `v0` and `v2` **reuse** `f1`'s UV IDs. Writing the same value twice is harmless; what matters is that we never created a seam we did not want.

### Recipe 2: a sharp cube

This is Roblox's own reference sample from `EditableMesh.yaml`, reproduced verbatim — it is the canonical demonstration of per-face normal IDs.

```lua
-- Given 4 vertex IDs, adds a new normal and 2 triangles, making a sharp quad
local function addSharpQuad(editableMesh, vid0, vid1, vid2, vid3)
	local nid = editableMesh:AddNormal() -- This creates a normal ID which is automatically computed

	local fid1 = editableMesh:AddTriangle(vid0, vid1, vid2)
	editableMesh:SetFaceNormals(fid1, {nid, nid, nid})

	local fid2 = editableMesh:AddTriangle(vid0, vid2, vid3)
	editableMesh:SetFaceNormals(fid2, {nid, nid, nid})
end

-- Makes a cube with creased edges between the 6 sides
local function makeSharpCube()
	local editableMesh = AssetService:CreateEditableMesh()

	local v1 = editableMesh:AddVertex(Vector3.new(0, 0, 0))
	local v2 = editableMesh:AddVertex(Vector3.new(1, 0, 0))
	local v3 = editableMesh:AddVertex(Vector3.new(0, 1, 0))
	local v4 = editableMesh:AddVertex(Vector3.new(1, 1, 0))
	local v5 = editableMesh:AddVertex(Vector3.new(0, 0, 1))
	local v6 = editableMesh:AddVertex(Vector3.new(1, 0, 1))
	local v7 = editableMesh:AddVertex(Vector3.new(0, 1, 1))
	local v8 = editableMesh:AddVertex(Vector3.new(1, 1, 1))

	addSharpQuad(editableMesh, v5, v6, v8, v7) -- Front
	addSharpQuad(editableMesh, v1, v3, v4, v2) -- Back
	addSharpQuad(editableMesh, v1, v5, v7, v3) -- Left
	addSharpQuad(editableMesh, v2, v4, v8, v6) -- Right
	addSharpQuad(editableMesh, v1, v2, v6, v5) -- Bottom
	addSharpQuad(editableMesh, v3, v7, v8, v4) -- Top

	editableMesh:RemoveUnused()
	return editableMesh
end
```

Points worth internalizing:

- Only **8 vertices** for a cube — positions are shared. The *creases* come from 6 separate normal IDs, one per side, not from splitting vertices.
- Each face's vertex order is chosen so the winding is counter-clockwise **as seen from outside**. Compare "Front" (`v5,v6,v8,v7`) against "Back" (`v1,v3,v4,v2`) — the back face's order is reversed relative to the front's, because you view it from the opposite side.
- `RemoveUnused()` at the end cleans up the normal/UV/color IDs that `AddTriangle` auto-created and `SetFaceNormals` then orphaned.
- UVs on this cube are still all `(0,0)`. Add a `SetFaceUVs` pass per side for a textured cube.

### Recipe 3: a heightmap surface

An `N × N` grid, fully batched. This is the base for terrain, water, cloth, and any parametric surface.

```lua
local function makeHeightmap(n, spacing, heightFn)
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then return nil end

	-- 1. Positions and UVs as flat arrays, one pass, no engine calls in the loop.
	local positions, uvs = table.create(n * n), table.create(n * n)
	for z = 0, n - 1 do
		for x = 0, n - 1 do
			local i = z * n + x + 1
			positions[i] = Vector3.new(x * spacing, heightFn(x, z), z * spacing)
			uvs[i] = Vector2.new(x / (n - 1), z / (n - 1))
		end
	end

	-- 2. Two batched creates.
	local vIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	local uvIds = mesh:BatchAdd(Enum.MeshAttribute.UV, uvs)

	-- 3. Triangles, counter-clockwise viewed from +Y.
	local tris, order = {}, {}
	for z = 0, n - 2 do
		for x = 0, n - 2 do
			local a = z * n + x + 1        -- (x,   z)
			local b = a + 1               -- (x+1, z)
			local c = a + n               -- (x,   z+1)
			local d = c + 1               -- (x+1, z+1)
			tris[#tris + 1] = { vIds[a], vIds[c], vIds[b] }
			order[#order + 1] = { uvIds[a], uvIds[c], uvIds[b] }
			tris[#tris + 1] = { vIds[b], vIds[c], vIds[d] }
			order[#order + 1] = { uvIds[b], uvIds[c], uvIds[d] }
		end
	end
	local fIds = mesh:BatchAdd(Enum.MeshAttribute.Face, tris)

	-- 4. Bind the grid UVs (overriding the auto-assigned (0,0) ones) in one call.
	mesh:BatchSetFaceAttributes(fIds, order)
	mesh:RemoveUnused()
	return mesh, vIds
end
```

**Sizing against the caps:** `(n-1)^2 * 2 <= 20000` gives `n <= 101`. A `100 × 100` grid is 10,000 vertices and 19,602 triangles — right at the ceiling. **Size your chunk to `n = 65` or smaller** to leave headroom.

Because the returned `vIds` are stable, animating this surface later is one call:

```lua
-- Every frame: recompute heights, write them all at once. No rebuild, no CreateMeshPartAsync.
local newPositions = table.create(#vIds)
for i, _ in ipairs(vIds) do newPositions[i] = computeHeight(i, os.clock()) end
mesh:BatchSetValues(vIds, newPositions)
```

### Recipe 4: merge many pieces into one mesh

Draw-call reduction: one `MeshPart` instead of N. Each source piece is offset into the destination's local space by its own `CFrame`.

```lua
-- pieces: { { mesh = <EditableMesh>, cframe = <CFrame relative to the destination> } }
local function mergeInto(dest, pieces)
	local totalTris = 0
	for _, piece in ipairs(pieces) do
		local src = piece.mesh
		local srcVerts = src:GetVertices()
		local srcFaces = src:GetFaces()
		totalTris += #srcFaces
		assert(totalTris <= 20000, "merge would exceed the 20,000-triangle cap")

		-- Transform positions into destination space and add them in one batch.
		local srcPositions = src:BatchGetValues(srcVerts)          -- Safe
		local newPositions = table.create(#srcPositions)
		for i, p in ipairs(srcPositions) do
			newPositions[i] = piece.cframe * p
		end
		local newVerts = dest:BatchAdd(Enum.MeshAttribute.Vertex, newPositions)

		-- Map src vertex ID -> dest vertex ID. IDs are sparse, so use a table, not an offset.
		local remap = {}
		for i, sv in ipairs(srcVerts) do remap[sv] = newVerts[i] end

		-- Rebuild the faces through the remap, and carry the UVs across.
		local srcFaceVerts = src:BatchGetFaceAttributes(Enum.MeshAttribute.Vertex, srcFaces)
		local srcFaceUVs   = src:BatchGetFaceAttributes(Enum.MeshAttribute.UV, srcFaces)
		local newFaceVerts = table.create(#srcFaces)
		for i, corners in ipairs(srcFaceVerts) do
			newFaceVerts[i] = { remap[corners[1]], remap[corners[2]], remap[corners[3]] }
		end
		local newFaces = dest:BatchAdd(Enum.MeshAttribute.Face, newFaceVerts)

		-- Re-create UV IDs in the destination and bind them per corner.
		local uvOrder = table.create(#newFaces)
		for i, cornerUVs in ipairs(srcFaceUVs) do
			local vals = src:BatchGetValues(cornerUVs)             -- {Vector2}
			uvOrder[i] = dest:BatchAdd(Enum.MeshAttribute.UV, vals)
		end
		dest:BatchSetFaceAttributes(newFaces, uvOrder)
	end
	dest:RemoveUnused()
	return dest
end
```

Caveats to weigh before merging: you lose per-piece movement, per-piece collision fidelity, per-piece streaming and per-piece culling; and you inherit the 20,000-triangle cap for the whole batch. Merge **static scenery of the same material**; never merge anything that must move or be destroyed independently.

### Recipe 5: update a region without a full rebuild

The point of stable IDs. Keep a map from your world coordinates to vertex IDs once, then touch only what changed.

```lua
local Chunk = {}
Chunk.__index = Chunk

function Chunk.new(n, spacing, heightFn)
	local mesh, vIds = makeHeightmap(n, spacing, heightFn)
	local self = setmetatable({ mesh = mesh, vIds = vIds, n = n }, Chunk)
	self.part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,   -- cheap; rebuilt rarely
	})
	self.part.Parent = workspace
	return self
end

-- Deform a circular region. Visual result is live and immediate; no rebuild.
function Chunk:deform(centerX, centerZ, radius, delta)
	local ids, values = {}, {}
	local r2 = radius * radius
	for z = math.max(0, centerZ - radius), math.min(self.n - 1, centerZ + radius) do
		for x = math.max(0, centerX - radius), math.min(self.n - 1, centerX + radius) do
			local dx, dz = x - centerX, z - centerZ
			local d2 = dx * dx + dz * dz
			if d2 <= r2 then
				local id = self.vIds[z * self.n + x + 1]
				local p = self.mesh:GetPosition(id)
				local falloff = 1 - math.sqrt(d2) / radius
				ids[#ids + 1] = id
				values[#values + 1] = p + Vector3.new(0, delta * falloff, 0)
			end
		end
	end
	self.mesh:BatchSetValues(ids, values)   -- visual updates instantly
	self.collisionDirty = true
end

-- Call on a slow cadence (e.g. every 0.5s, or when the player stops editing).
function Chunk:flushCollision()
	if not self.collisionDirty then return end
	self.collisionDirty = false
	local rebuilt = AssetService:CreateMeshPartAsync(Content.fromObject(self.mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
	})
	self.part:ApplyMesh(rebuilt)
	rebuilt:Destroy()
end
```

Alternative region lookup when you do **not** have a coordinate map — `FindVerticesWithinSphere` does it directly, in mesh-local space, and is `Safe` so it can run in parallel:

```lua
local ids = mesh:FindVerticesWithinSphere(localCenter, radius)
local positions = mesh:BatchGetValues(ids)
-- ... displace ...
mesh:BatchSetValues(ids, positions)
```

If you changed positions enough to matter for shading, remember that normals created by `AddNormal()` with no argument are **auto-computed** and follow the shape; manually-set normals do not. `mesh:BatchSetValues(normalIds, nil)` *"Resets each normal to auto-computed"*, which is the cheapest way to refresh shading after a deformation.

### Recipe 6: a tube extruded along a spline

The general "sweep a cross-section along a path" primitive: pipes, cables, roads, rivers, tentacles, lasers, trails.

```lua
-- points:  { Vector3 }  path in mesh-local space
-- radius:  number
-- sides:   number of vertices around the tube
local function makeTube(points, radius, sides)
	local mesh = AssetService:CreateEditableMesh()
	if not mesh then return nil end

	local ringCount = #points
	assert((ringCount - 1) * sides * 2 <= 20000, "tube exceeds the 20,000-triangle cap")

	-- Parallel-transport frames: avoids the flipping you get from a naive up-vector.
	local positions = table.create(ringCount * sides)
	local uvs = table.create(ringCount * sides)
	local normal = Vector3.new(0, 1, 0)

	for i = 1, ringCount do
		local p = points[i]
		local tangent = ((i < ringCount and points[i + 1] or p) - (i > 1 and points[i - 1] or p)).Unit
		-- Re-orthogonalize the carried normal against the new tangent.
		normal = (normal - tangent * normal:Dot(tangent))
		if normal.Magnitude < 1e-4 then
			normal = tangent:Cross(Vector3.new(1, 0, 0))
			if normal.Magnitude < 1e-4 then normal = tangent:Cross(Vector3.new(0, 0, 1)) end
		end
		normal = normal.Unit
		local binormal = tangent:Cross(normal)

		for s = 0, sides - 1 do
			local a = (s / sides) * math.pi * 2
			local offset = normal * (math.cos(a) * radius) + binormal * (math.sin(a) * radius)
			local idx = (i - 1) * sides + s + 1
			positions[idx] = p + offset
			uvs[idx] = Vector2.new(s / sides, (i - 1) / (ringCount - 1))
		end
	end

	local vIds = mesh:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	local uvIds = mesh:BatchAdd(Enum.MeshAttribute.UV, uvs)

	local tris, uvOrder = {}, {}
	for i = 1, ringCount - 1 do
		for s = 0, sides - 1 do
			local s2 = (s + 1) % sides
			local a = (i - 1) * sides + s  + 1   -- this ring, this side
			local b = (i - 1) * sides + s2 + 1   -- this ring, next side
			local c = i * sides + s  + 1         -- next ring, this side
			local d = i * sides + s2 + 1         -- next ring, next side
			tris[#tris + 1] = { vIds[a], vIds[c], vIds[b] }
			uvOrder[#uvOrder + 1] = { uvIds[a], uvIds[c], uvIds[b] }
			tris[#tris + 1] = { vIds[b], vIds[c], vIds[d] }
			uvOrder[#uvOrder + 1] = { uvIds[b], uvIds[c], uvIds[d] }
		end
	end

	local fIds = mesh:BatchAdd(Enum.MeshAttribute.Face, tris)
	mesh:BatchSetFaceAttributes(fIds, uvOrder)
	mesh:RemoveUnused()
	return mesh, vIds
end
```

Notes:

- The ring closes with `s2 = (s + 1) % sides`, which **reuses the first ring vertex** — so the tube is watertight but the UV wraps back to `u = 0`, producing a visible texture seam. To fix it properly, emit `sides + 1` UV IDs per ring (with the last at `u = 1`) and use separate UV IDs at the seam corners. That is exactly the split-attribute mechanism from [§2.2](#22-separate-id-spaces-position-is-per-vertex-everything-else-is-per-face-corner).
- Triangle count is `(ringCount - 1) * sides * 2`. At `sides = 12` you can afford ~833 path segments before hitting the cap; chunk longer paths.
- Because `vIds` are stable and laid out ring-major, animating the tube (a wobbling cable, a growing vine) is a single `BatchSetValues` per frame with no topology change — so you can and should load it `FixedSize` if it came from an asset.
- Caps: add a centre vertex per end and a fan of `sides` triangles, wound so the end caps face outward.

---

## Sources

All URLs fetched 2026-09-17. `create.roblox.com`, `devforum.roblox.com`, `luau.org` and `robloxapi.github.io` are blocked by this environment's egress policy; the GitHub source of Roblox's own documentation was used instead, which is generated from the same source as the rendered site.

**Primary (engine reference YAML, `Roblox/creator-docs` @ `main`)**

| File | URL |
|---|---|
| `EditableMesh.yaml` (3,013 lines) | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableMesh.yaml |
| `AssetService.yaml` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AssetService.yaml |
| `MeshPart.yaml` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MeshPart.yaml |
| `EditableImage.yaml` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml |
| `SurfaceAppearance.yaml` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/SurfaceAppearance.yaml |
| `Content` datatype | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Content.yaml |
| `Enum.CollisionFidelity` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/CollisionFidelity.yaml |
| `Enum.RenderFidelity` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/RenderFidelity.yaml |
| `Enum.FluidFidelity` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/FluidFidelity.yaml |
| `Enum.MeshAttribute` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/MeshAttribute.yaml |
| `Enum.ContentSourceType` | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ContentSourceType.yaml |

**Guides**

| File | URL |
|---|---|
| Parallel Luau / thread safety levels | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md |
| Meshes (LOD table, SurfaceAppearance vs geometry) | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/meshes.md |
| Memory usage optimization (checked — contains **no** editable-asset content) | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/optimization/memory-usage.md |
| Assets API (checked — contains **no** editable-asset content) | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/assets/api.md |
| Procedural models (`ProceduralModel`, a *different* feature) | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/procedural-models.md |

**Repository survey**

`git clone --depth 1 --filter=blob:none https://github.com/Roblox/creator-docs` → `git ls-tree -r HEAD` over all **9,368** tracked paths. Case-insensitive search for `editable` returns only `EditableImage.yaml`, `EditableMesh.yaml` and five images under `content/en-us/assets/engine-api/classes/EditableMesh/`. **There is no `editable-assets` guide tree and no editable-assets memory-budget guide page in `main` as of 2026-09-17.** Everything the docs say about the editable memory budget is contained in the `EditableMesh.yaml` / `EditableImage.yaml` "Memory limits" sections and the `AssetService` creation-method descriptions, all quoted above.

**Community, second-hand (web-search result summaries only — never fetched directly)**

- DevForum 3469104 — "Editable mesh memory budget reached"
- DevForum 985602 — "SurfaceAppearence ColorMap does not respect baked vertex colors"
- DevForum 3981469 — "Vertex Coloring Support for SurfaceAppearance" (feature request)
- DevForum 4433191 — "Viewport Issues with vertex color"
- DevForum 4620152 — "Feedback on EditableMesh:AddColor"
- DevForum 3267293 — "[Client Beta] In-experience Mesh & Image APIs now available in published experiences"

**Everything marked `[UNVERIFIED]` in this chapter**

1. Whether removed IDs are ever reused (slot recycling) — only the *version* field in `IdDebugString` hints at it. (§2.1)
2. Whether bone `CFrame` / skin-weight mutation live-updates the rendered mesh. (Live-update table)
3. Engine behavior between a deformed mesh and a stale `MeshPart.MeshSize`. (§ Does mutation live-update?)
4. Which tunable properties `CreateMeshPartAsync` exposes for `CollisionFidelity.Tunable`. (§4)
5. Any numeric value for the editable-assets memory budget. (§3)
6. Whether skin weights survive a `FixedSize = true` load, and whether DataModel `Bone` instances auto-bind to `EditableMesh` bones. (§6)
7. Whether `Opaque` `DataModel`-scoped `Content` from `CreateDataModelContentAsync` replicates server→client. (§9)
8. The UV origin convention (V=0 at top or bottom). (G2)
9. Whether `RenderFidelity.Automatic` generates or uses LODs for an `EditableMesh`-backed `MeshPart`. (G11)
10. How vertex colors blend with `SurfaceAppearance` / `MeshPart.Color` / `TextureContent` / `MaterialVariant`. (G12 — community reports say they are incompatible with `SurfaceAppearance`; unconfirmed officially.)
