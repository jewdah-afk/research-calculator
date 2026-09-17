# Roblox `EditableImage`: The Definitive Internal Reference

> **Scope.** Everything a team needs to build runtime image generation on Roblox: creation,
> the verification gate, memory budgets, the pixel buffer format, the drawing API, every
> display sink, performance, uploading, and the version churn that makes most tutorials wrong.
>
> **Verification rule used throughout.** Every API claim in this document is traceable to a
> URL listed in [Sources](#sources) — primarily the machine-generated YAML in
> `Roblox/creator-docs`, which is the same source the rendered documentation site is built
> from. Anything not confirmed there is marked `[UNVERIFIED]` or
> `[COMMUNITY, SECOND-HAND]`. Nothing is guessed.
>
> **Docs snapshot:** `Roblox/creator-docs@main`, fetched 2026-09-17.

---

## Table of contents

1. [TL;DR for builders](#tldr-for-builders)
2. [The verification gate](#the-verification-gate)
3. [The replication landmine](#the-replication-landmine)
4. [Verified API surface](#verified-api-surface)
5. [Creation and lifecycle](#1-creation-and-lifecycle)
6. [Size and memory](#2-size-and-memory)
7. [Pixel access: the buffer format](#3-pixel-access-the-buffer-format)
8. [The drawing API](#4-the-drawing-api)
9. [Display sinks: where an EditableImage can actually appear](#5-display-sinks-where-an-editableimage-can-actually-appear)
10. [Performance and the cost model](#6-performance-and-the-cost-model)
11. [Parallel Luau and thread safety](#7-parallel-luau-and-thread-safety)
12. [Saving and uploading generated images](#8-saving-and-uploading-generated-images)
13. [Gotchas](#gotchas)
14. [Version churn: what changed and what stale tutorials get wrong](#version-churn-what-changed-and-what-stale-tutorials-get-wrong)
15. [Sources](#sources)

---

## TL;DR for builders

- **`EditableImage` is a runtime RGBA bitmap Instance you draw into with Luau and then hand to a
  renderer via `Content.fromObject()`.** It is `NotCreatable` — `Instance.new("EditableImage")`
  does not work. You get one only from `AssetService:CreateEditableImage(options)` (blank) or
  `AssetService:CreateEditableImageAsync(content, options)` (from an existing image).
  <sub>[EditableImage.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml)</sub>
- **It fails by default in published experiences.** The creator must be **13+ age verified AND ID
  verified**, then toggle **Enable Mesh / Image APIs** on the Creator Dashboard. See
  [The verification gate](#the-verification-gate) — this is the single most common reason
  "it works in Studio but not in-game."
- **Max resolution is 1024×1024, and `Size` is read-only.** There is no `Resize` and no `Crop`
  method. To resize or crop you create a *new* `EditableImage` and blit into it with
  `DrawImageTransformed`, then `Destroy()` the old one. The default when you pass no `Size` is
  **512×512**.
  <sub>[EditableImage.yaml → `Size`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml)</sub>
- **Pixel I/O is `ReadPixelsBuffer` / `WritePixelsBuffer`, and the layout is RGBA8, one byte per
  channel, row-major, top-left origin.** Index of pixel `(x, y)` inside a region read at
  `(0,0)` with width `W` is `(y * W + x) * 4`. The table-based `ReadPixels`/`WritePixels` are
  **gone from the live API dump** — do not use code that calls them.
- **Buffers use ALPHA; the drawing methods use TRANSPARENCY.** The docs call this out explicitly:
  "this method uses alpha instead of transparency, unlike the `EditableImage` drawing methods."
  `alpha = 255` is opaque; `transparency = 0` is opaque.
- **Only ONE `EditableImage` is pushed to the display per frame.** Three dirty displayed images
  take three frames to all appear. This is a hard engine-side throttle, not a suggestion.
  <sub>[EditableImage.yaml → "Update Limitations"](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml)</sub>
- **`ReadPixelsBuffer` is the only thread-safe member** (`thread_safety: Safe`). `Size` is
  `ReadSafe`. *Everything else — every draw call, `WritePixelsBuffer`, `Destroy` — is `Unsafe`*
  and therefore illegal in a parallel (`task.desynchronize`) context.
- **`Content.Object` does not replicate.** A server-side `EditableImage` assigned to a replicating
  property becomes an unusable placeholder on clients that renders as a **cyan/magenta
  checkerboard** and throws on access. Generate on the client, or convert with
  `AssetService:CreateDataModelContentAsync()`.
  <sub>[Content.yaml → Warning](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Content.yaml)</sub>
- **Client memory is budgeted; server/Studio/plugins are not.** If the device budget is exhausted,
  `CreateEditableImage` returns **`nil`** rather than throwing (whereas a *permission* failure
  **throws**). The budget is **shared with `EditableMesh`** — the "Memory limits" paragraph is
  word-for-word identical in both class YAMLs. **No numeric budget is published anywhere in
  creator-docs.** Always nil-check.
- **Multi-referencing is the memory trick**: point many `Content` properties at *one*
  `EditableImage` rather than making N copies. But **not every `Content` property accepts an
  object** — `ImageButton.HoverImageContent`, `Shirt`, `Pants`, `ShirtGraphic` and `ScrollingFrame`
  bars explicitly reject it, and `ViewportFrame` has no image property at all.
- **Runtime PBR works, but only by construction.** All `SurfaceAppearance.*MapContent` slots are
  `PluginSecurity`-write, so a game script cannot assign to them — it must build the instance with
  `AssetService:CreateSurfaceAppearanceAsync` / `CreateDecalAsync` (both `security: None`), and the
  maps can never be swapped afterwards.
- **Uploading generated images to permanent asset IDs works, but only from plugins and Open Cloud
  Luau execution** (`CreateAssetAsync` with `Enum.AssetType.Image`). There is **no** supported
  in-experience path to publish an `EditableImage` as a standalone image asset today:
  `PromptCreatePlatformContentAsync` "currently can only be `Enum.AssetType.Model`."

---

## The verification gate

**This is the section to read before you plan any feature around `EditableImage`.**
The APIs work in Studio for you and fail for everyone else unless this is done.

### Exact wording from the source

From `content/en-us/reference/engine/classes/EditableImage.yaml`, class description:

> #### Enabling for Published Experiences
>
> For security purposes, using `EditableImage` fails by default for published experiences. To
> enable usage, you must be 13+ age verified and ID verified. After you are verified, open the
> [Creator Dashboard](https://create.roblox.com/dashboard/creations) and toggle on
> **Enable Mesh / Image APIs**.

> #### Permissions
>
> To prevent misuse, `AssetService:CreateEditableImageAsync()` only allows you to load and edit
> image assets if any of the following is true:
>
> - Owned by or explicitly shared with the experience owner.
> - Owned by or explicitly shared with the logged in Studio user.
> - Owned by or explicitly shared with the logged in player if the `EditableImage` is on the
>   client side.
> - Owned by a group where the experience owner, Studio user, or player has a role with permission
>   to edit the group's assets. See
>   [Roles and permissions](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/groups.md)
>   for more information.
>
> See
> [Grant permissions](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/assets/privacy.md)
> to learn how to share assets with users or groups.
>
> **The APIs throw an error if they are used to load an asset that does not meet the criteria
> above.**

`EditableMesh.yaml` carries a word-for-word identical pair of sections, and the toggle is a single
shared switch ("Mesh / Image APIs") — enabling it for one enables it for both.
<sub>[EditableMesh.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableMesh.yaml)</sub>

### Decomposing the gate — there are three independent gates, not one

| # | Gate | Applies to | Failure mode |
|---|------|-----------|--------------|
| 1 | **Creator verification + dashboard toggle** | *All* `EditableImage` use in a **published** experience | Creation fails in published experiences. Studio is unaffected, which is exactly why this bites at launch and not during development. |
| 2 | **Asset ownership/sharing** | `CreateEditableImageAsync` only (loading an *existing* asset) | **Throws.** Documented as "The APIs throw an error." Wrap in `pcall`. |
| 3 | **Editable memory budget** | `CreateEditableImage` and `CreateEditableImageAsync` on **clients** | Returns **`nil`**, does *not* throw. Documented on both methods: "If the device‑specific editable memory budget is exhausted, creation fails and this method returns `nil`." |

Gates 2 and 3 have *different* failure shapes. A correct call site handles both:

```lua
local AssetService = game:GetService("AssetService")

-- Gate 2 can throw; gate 3 returns nil. Handle both, always.
local ok, imageOrErr = pcall(function()
    return AssetService:CreateEditableImageAsync(Content.fromAssetId(12345678))
end)

if not ok then
    -- Permission denied, asset not shared, moderated, or the verification gate.
    warn("CreateEditableImageAsync threw:", imageOrErr)
    return nil
end
if imageOrErr == nil then
    -- Editable memory budget exhausted on this device.
    warn("CreateEditableImageAsync returned nil: editable memory budget exhausted")
    return nil
end
local editable = imageOrErr
```

### Practical consequences for design

- **`CreateEditableImage` (blank) does not require asset permissions** — there is no asset to
  permission-check. It carries the `DynamicGeneration` capability only. `CreateEditableImageAsync`
  carries `AssetRead`. That is visible directly in the API surface:
  `CreateEditableImage → capabilities: [DynamicGeneration]`,
  `CreateEditableImageAsync → capabilities: [AssetRead]`.
  <sub>[AssetService.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AssetService.yaml)</sub>
  The *experience-level* verification toggle (gate 1) still applies to both.
- **Client-side loading of a player's own assets is legitimate.** Bullet three of the permissions
  list explicitly allows loading an asset owned by/shared with the **logged-in player**, but only
  "if the `EditableImage` is on the client side." This is the sanctioned path for
  "let the player use their own uploaded decal" features. It will *not* work if you do it on the
  server.
- **Non-asset URIs bypass the ownership check.** `CreateEditableImageAsync` documents:
  "Non-asset texture IDs such as `rbxthumb://` are supported." Avatar headshots, group emblems and
  asset thumbnails are therefore loadable without sharing anything.
  <sub>[AssetService.yaml → `CreateEditableImageAsync`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AssetService.yaml)</sub>
- **Ship a fallback.** Treat "no `EditableImage`" as a supported runtime state — a static
  `rbxassetid://` texture, a solid colour, a pre-baked sprite sheet. If the toggle is ever turned
  off, or a moderation action hits the source asset, your feature degrades instead of erroring on
  every client.
- **The toggle lives with the *creator*, not the place.** If a group owns the experience, the
  verification status that matters is the group owner's. A studio where the verified person leaves
  can lose the capability.
  `[UNVERIFIED]` — the YAML does not specify which account's verification is checked for
  group-owned experiences; it says only "you must be 13+ age verified and ID verified."

---

## The replication landmine

**Read this before you write a line of server code.** It is not mentioned in `EditableImage.yaml`
at all; it lives only in the `Content` datatype documentation, which is why so many teams ship it
broken.

Quoted verbatim from `content/en-us/reference/engine/datatypes/Content.yaml`:

> ##### Warning
>
> Replication is not yet supported for `Content.Object` values. When an `Instance` with a `Content`
> property containing a `Content.Object` value is replicated, **an unusable placeholder `Object` of
> the same type will be used instead of the `Object` itself**, and any attempt to read or write the
> contents of that placeholder object will throw. **These placeholder objects will render as a cyan
> and magenta checkerboard pattern.**
>
> This will be replaced with standard replication behavior in the future. For now, **do not use
> `EditableImage` or `EditableMesh` as `Content` on the server on an `Instance` that can replicate
> to clients.**
>
> <sub>[Content.yaml](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Content.yaml)</sub>

### What this actually means

**Runtime-generated imagery on Roblox is a client-side feature.** Not "should preferably be";
*is*. The engine has no path today for an `EditableImage` created on the server to arrive intact on
a client through ordinary property replication.

The three symptoms, in the order teams hit them:

1. **Cyan and magenta checkerboards in the live game, but not in Studio.** In Studio play-solo the
   server and client share a process, so the object reference survives and everything looks right.
   In a real server/client split it does not. This is the same class of bug as the verification
   gate: *works on my machine, fails for everyone.*
2. **Errors on the client when anything reads the property.** "Any attempt to read or write the
   contents of that placeholder object will throw." So client code that does
   `part.Decal.ColorMapContent.Object:ReadPixelsBuffer(...)` throws, not returns `nil`.
3. **Silent divergence.** A server that keeps drawing into its own copy sees changes no client ever
   sees.

### The rule

> **Replicate parameters, seeds and recipes. Never replicate images.**

```lua
-- SERVER — send the recipe, not the pixels.
GenerateBanner:FireAllClients({
    seed      = 8172634,
    palette   = "crimson",
    crestId   = guild.CrestIndex,
    tier      = guild.Tier,
})

-- CLIENT — build the image locally from the recipe.
GenerateBanner.OnClientEvent:Connect(function(spec)
    local image = buildBanner(spec)              -- AssetService:CreateEditableImage(...) etc.
    if image then
        bannerLabel.ImageContent = Content.fromObject(image)
    else
        bannerLabel.ImageContent = FALLBACK      -- budget exhausted: degrade, do not error
    end
end)
```

This is not a workaround, it is a better design: a recipe is a few hundred bytes versus megabytes,
every client pays only for what it can see, and the server never spends memory on pixels nobody
looks at.

### The one documented exception

`AssetService:CreateDataModelContentAsync()` converts an `EditableImage` into a `DataModel`-scoped
`Enum.ContentSourceType.Opaque` `Content`, which is a *different source type* from `Object`. See
[§1.6](#16-the-two-sanctioned-patterns-for-server-authored-imagery). `[UNVERIFIED]` — the docs do
not state in so many words that `Opaque` content replicates; they state only that `Object` content
does not. Prototype it before you depend on it.

### Related guardrails visible in the engine

The shipping client carries flags named `BlockEditableTypeReplication`,
`BlockUseOfReplicatedEditableX` and `DebugEditableMeshBasicReplicationEnabled`
<sub>([FVariables.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt))</sub>,
which is consistent with the engine actively blocking use of replicated editable objects rather than
merely failing to send them, and with replication being a feature under active development. Flag
names are not documentation; they are corroboration.

---

## Verified API surface

Two sources agree throughout this table:

- **DOCS** — `Roblox/creator-docs@main`, `content/en-us/reference/engine/**` (the generator source
  behind create.roblox.com).
- **DUMP** — the live engine reflection dump, `MaximumADHD/Roblox-Client-Tracker@roblox`
  `API-Dump.json`, client version **`0.739.0.7390687`**.

Where they disagree, the disagreement is called out explicitly.

### `EditableImage` — class facts

| Fact | Value | Source |
|---|---|---|
| Superclass | `Object` (**not** `Instance`) | DOCS `inherits: [Object]`; DUMP `Superclass: Object` |
| Tags | `NotCreatable` | DOCS + DUMP |
| Memory category | `Instances` | DOCS `memory_category`; DUMP `MemoryCategory` |
| Descendants | none | DOCS `descendants: []` |
| Coordinate origin | top-left `(0, 0)`; bottom-right `(Size.X - 1, Size.Y - 1)` | DOCS class description |
| Max resolution | 1024 × 1024 | DOCS `Size` description |
| Default resolution (blank) | 512 × 512 | DOCS `AssetService:CreateEditableImage` |

Because the superclass is `Object` and not `Instance`, an `EditableImage` has **no `Parent`, no
`Name`, no `:Clone()`, no `:GetChildren()`, no attributes, no `CollectionService` tags**. It is not
in the DataModel tree. It is kept alive purely by Luau references and by `Content.fromObject`
references, which the docs describe as "**strong** references that hold **shared ownership**."

### `EditableImage` — properties

| Property | Type | Tags | Thread safety | Capabilities | Notes |
|---|---|---|---|---|---|
| `Size` | `Vector2` | `ReadOnly`, `NotReplicated` | `ReadSafe` | `DynamicGeneration` | Pixel dimensions. Max 1024×1024. **Cannot be written.** |

There are **no other properties**. There are **no events** and **no callbacks**
(`events: []`, `callbacks: []` in DOCS; DUMP shows no `Event` members).

### `EditableImage` — methods

All are `security: None` and carry capability `DynamicGeneration`.

| Method | Full signature | Returns | Thread safety | In DOCS? |
|---|---|---|---|---|
| `Destroy` | `Destroy(): ()` | `()` | `Unsafe` | yes |
| `DrawCircle` | `DrawCircle(center: Vector2, radius: int, color: Color3, transparency: float, combineType: Enum.ImageCombineType, antiAliasing: Enum.AntiAliasing = Enum.AntiAliasing.Enabled): ()` | `()` | `Unsafe` | yes |
| `DrawImage` | `DrawImage(position: Vector2, image: EditableImage, combineType: Enum.ImageCombineType): ()` | `()` | `Unsafe` | yes |
| `DrawImageProjected` | `DrawImageProjected(mesh: EditableMesh, projection: Dictionary, brushConfig: Dictionary): ()` | `()` | `Unsafe` | yes |
| `DrawImageTransformed` | `DrawImageTransformed(position: Vector2, scale: Vector2, rotation: float, image: EditableImage, options: Dictionary?): ()` | `()` | `Unsafe` | yes |
| `DrawLine` | `DrawLine(p1: Vector2, p2: Vector2, color: Color3, transparency: float, combineType: Enum.ImageCombineType, antiAliasing: Enum.AntiAliasing = Enum.AntiAliasing.Enabled): ()` | `()` | `Unsafe` | yes |
| `DrawRectangle` | `DrawRectangle(position: Vector2, size: Vector2, color: Color3, transparency: float, combineType: Enum.ImageCombineType): ()` | `()` | `Unsafe` | yes |
| `DrawTriangle` | `DrawTriangle(p1: Vector2, p2: Vector2, p3: Vector2, color: Color3, transparency: float): ()` | `()` | `Unsafe` | **NO — DUMP only** |
| `ReadPixelsBuffer` | `ReadPixelsBuffer(position: Vector2, size: Vector2): buffer` | `buffer` | **`Safe`** | yes |
| `SampleImageProjected` | `SampleImageProjected(sourceMesh: EditableMesh, sourceTexture: EditableImage, projectionConfig: Dictionary, brushConfig: Dictionary): ()` | `()` | `Unsafe` | yes |
| `WritePixelsBuffer` | `WritePixelsBuffer(position: Vector2, size: Vector2, buffer: buffer): ()` | `()` | `Unsafe` | yes |

`ReadPixelsBuffer` and `WritePixelsBuffer` both carry the `CustomLuaState` tag, meaning the engine
implements custom argument marshalling for them rather than the generic reflection path.

**There is no clear/fill method.** `DrawRectangle` over the whole canvas with
`Enum.ImageCombineType.Overwrite` is the documented way to clear — see
[Clearing and filling](#clearing-and-filling).

**There is no `Resize`, no `Crop`, no `Rotate`, no `GetPixel`, no `SetPixel`, no `ReadPixels`, no
`WritePixels`, no `DrawText`, no `DrawPolygon`, no `Save`, and no `Blur`.** All of these appear in
community tutorials; none exist in DOCS or DUMP at the versions cited here.

### `AssetService` — the `EditableImage` entry points

| Method | Full signature | Yields | Capabilities | Notes |
|---|---|---|---|---|
| `CreateEditableImage` | `CreateEditableImage(editableImageOptions: Dictionary?): EditableImage` | no | `DynamicGeneration` | Blank image. Returns **`nil`** on budget exhaustion. |
| `CreateEditableImageAsync` | `CreateEditableImageAsync(content: Content, editableImageOptions: Dictionary?): EditableImage` | **yes** | `AssetRead` | From existing image. **Throws** on permission failure; returns `nil` on budget exhaustion. |
| `CreateDecalAsync` | `CreateDecalAsync(content: Dictionary): Decal` | **yes** | `Basic` | Builds an unparented `Decal` from `EditableImage` maps. |
| `CreateSurfaceAppearanceAsync` | `CreateSurfaceAppearanceAsync(content: Dictionary): SurfaceAppearance` | **yes** | `Basic` | Builds a `SurfaceAppearance` from `EditableImage` maps. Maps **cannot be swapped afterwards**. |
| `ComposeDecalAsync` | `ComposeDecalAsync(decal: Decal, layers: Array): ()` | **yes** | (none listed) | Layer-composites up to 8 PBR texture sets onto an existing `Decal`. Asset-ID based. |
| `CreateDataModelContentAsync` | `CreateDataModelContentAsync(content: Content, options: Dictionary?): (Enum.CreateContentResult, Content)` | **yes** | `DynamicGeneration` | Converts an `EditableImage`/`EditableMesh` into an **ephemeral, `DataModel`-scoped `Opaque` `Content`**. This is the replication escape hatch. |
| `CreateAssetAsync` | `CreateAssetAsync(object: Object, assetType: Enum.AssetType, requestParameters: Dictionary?): (Enum.CreateAssetResult, number)` | **yes** | `AssetCreateUpdate` | Permanent upload. **Plugins and Open Cloud Luau execution only.** Accepts `Enum.AssetType.Image` with an `EditableImage` root. |
| `CreateAssetVersionAsync` | `CreateAssetVersionAsync(object: Object, assetType: Enum.AssetType, assetId: int64, requestParameters: Dictionary?): (Enum.CreateAssetResult, number)` | **yes** | `AssetCreateUpdate` | New version of an existing asset. Same context restriction. |
| `CreateMeshPartAsync` | `CreateMeshPartAsync(meshContent: Content, options: Dictionary?): MeshPart` | **yes** | `Basic` | Not image-specific, but the usual partner call when texturing generated meshes. |
| `PromptCreatePlatformContentAsync` | `PromptCreatePlatformContentAsync(player: Player, object: Object, assetType: Enum.AssetType): (Enum.PromptCreateAssetResult, number)` | **yes** | `AssetCreateUpdate` | Server-only UGC publish prompt. **`assetType` "currently can only be `Enum.AssetType.Model`."** |

`AssetService:CreateEditableImageFromDownloadAsync(url: string)` exists in DUMP but is
`RobloxScriptSecurity` — **inaccessible to creators**. Do not plan around it.
`AssetService:CanEditAssetAsync(content: Content): bool` is likewise `RobloxScriptSecurity`; there
is no creator-accessible way to pre-check permissions, which is why `pcall` is mandatory.

### Option tables — exact field lists

```lua
-- AssetService:CreateEditableImage(editableImageOptions)
{ Size: Vector2 }               -- desired width/height. Default 512x512. Max 1024x1024.

-- AssetService:CreateEditableImageAsync(content, editableImageOptions)
{ }                             -- DOCS: "Currently no options are available since resizing
                                --  via Size is not supported."

-- EditableImage:DrawImageTransformed(position, scale, rotation, image, options)
{
  CombineType:  Enum.ImageCombineType,  -- default Enum.ImageCombineType.AlphaBlend
  SamplingMode: Enum.ResamplerMode,     -- default Enum.ResamplerMode.Default (bilinear)
  PivotPoint:   Vector2,                -- default image.Size / 2 (centre of the SOURCE image)
}

-- EditableImage:DrawImageProjected(mesh, projection, brushConfig)
projection = {
  Direction: Vector3,   -- where the projector faces
  Position:  Vector3,   -- projector position in mesh LOCAL space
  Size:      Vector3,   -- projector size
  Up:        Vector3,   -- projector up vector in mesh LOCAL space
}
brushConfig = {
  AlphaBlendType: Enum.ImageAlphaType,
  ColorBlendType: Enum.ImageCombineType,
  Decal:          EditableImage,   -- the image being projected
  FadeAngle:      number,          -- degrees; 0 = fade immediately, 90 = hard edge
  BlendIntensity: number,          -- 0..1
}

-- EditableImage:SampleImageProjected(sourceMesh, sourceTexture, projectionConfig, brushConfig)
projectionConfig = {
  Direction: Vector3,
  Position:  Vector3,
  Size:      Vector3,   -- X,Y are dimensions; Z is projection DEPTH
  Up:        Vector3,
}
brushConfig = {
  AlphaBlendType: Enum.ImageAlphaType,
  ColorBlendType: Enum.ImageCombineType,
  FadeAngle:      number,   -- 180 applies no normal-angle fade
}

-- AssetService:CreateDecalAsync(content)  -- every value must be Content.fromObject(EditableImage)
{ TextureContent, NormalMapContent, MetalnessMapContent, RoughnessMapContent }

-- AssetService:CreateSurfaceAppearanceAsync(content)
{ ColorMap, MetalnessMap, NormalMap, RoughnessMap, EmissiveMask }   -- each a Content, default nil

-- AssetService:CreateAssetAsync(object, assetType, requestParameters)
{ Name, Description, CreatorId, CreatorType, IsPackage }
```

Note the **inconsistent key naming** between the two builder calls: `CreateDecalAsync` uses
`TextureContent` / `NormalMapContent` / …, while `CreateSurfaceAppearanceAsync` uses
`ColorMap` / `NormalMap` / …. `CreateDecalAsync` "ignores unrecognized keys with a warning", so a
typo there is silent-ish; get it wrong and your normal map simply never appears.

### Relevant enums, complete

**`Enum.ImageCombineType`** — "source refers to the new pixels being drawn and destination refers
to the existing pixels in the image being drawn onto."

| Name | Value | Documented behaviour |
|---|---|---|
| `BlendSourceOver` | 1 | Source-over alpha blending of source onto destination. |
| `Overwrite` | 2 | Overwrites all destination pixels with source pixels. |
| `Add` | 3 | Adds source and destination together. |
| `Multiply` | 4 | Multiplies source and destination. RGBA multiplied as 0–1 values; values below 1 darken. |
| `AlphaBlend` | 5 | Blends by source alpha. **Unlike `BlendSourceOver`, the destination colour affects the result regardless of the destination's alpha.** |
| `NormalMapBlend` | 6 | Alpha-blends, then **renormalizes the resulting RGB as a tangent-space normal vector**. |
| `Subtract` | 7 | Subtracts source from destination. |

**`Enum.ImageAlphaType`** — used only inside `brushConfig` for the projection methods.

| Name | Value | Meaning |
|---|---|---|
| `Default` | 1 | Neither colour nor alpha locked. |
| `LockCanvasAlpha` | 2 | The image's alpha values are not modified. |
| `LockCanvasColor` | 3 | The image's colour values are not modified. |

**`Enum.ResamplerMode`** — `DrawImageTransformed.options.SamplingMode`.

| Name | Value | Meaning |
|---|---|---|
| `Default` | 0 | Bilinear filtering of the four nearest pixels. |
| `Pixelated` | 1 | Nearest-neighbour filtering of the closest pixel. |

**`Enum.AntiAliasing`** — `DrawLine` / `DrawCircle` last parameter, default `Enabled`.

| Name | Value | Meaning |
|---|---|---|
| `Disabled` | 0 | Hard edges. |
| `Enabled` | 1 | Soft edges. |

**`Enum.ContentSourceType`** — what a `Content` is wrapping.

| Name | Value | Populated field |
|---|---|---|
| `None` | 0 | — (`Content.none`) |
| `Uri` | 1 | `Content.Uri` (string) |
| `Object` | 2 | `Content.Object` (`Object`) |
| `Opaque` | 3 | `Content.Opaque` |

**`Enum.CreateContentResult`** — returned by `CreateDataModelContentAsync`.

| Name | Value |
|---|---|
| `Success` | 1 |
| `PermissionDenied` | 2 |
| `UploadFailed` | 3 |
| `StorageLimitExceeded` | 4 |
| `Unknown` | 5 |

**`Enum.CreateAssetResult`** — returned by `CreateAssetAsync` / `CreateAssetVersionAsync`.

| Name | Value |
|---|---|
| `Success` | 1 |
| `PermissionDenied` | 2 |
| `UploadFailed` | 3 |
| `Unknown` | 4 |

**`Enum.PromptCreateAssetResult`** — returned by `PromptCreatePlatformContentAsync`.

| Name | Value |
|---|---|
| `Success` | 1 |
| `PermissionDenied` | 2 |
| `Timeout` | 3 |
| `UploadFailed` | 4 |
| `NoUserInput` | 5 |
| `UnknownFailure` | 6 |
| `UGCValidationFailed` | 7 |
| `ModeratedName` | 8 |
| `PurchaseFailure` | 9 |
| `TokenInvalid` | 10 |

### `Content` datatype

| Member | Signature | Notes |
|---|---|---|
| `Content.fromUri` | `fromUri(uri: string): Content` | `SourceType = Uri`. Empty string returns `Content.none`. |
| `Content.fromAssetId` | `fromAssetId(assetId: number): Content` | Equivalent to `fromUri("rbxassetid://" .. tostring(assetId))`. `0` returns `Content.none`. **Throws on non-finite** (`math.huge`, `0/0`). |
| `Content.fromObject` | `fromObject(object: Object): Content` | `SourceType = Object`. **Strong, shared-ownership reference** — it keeps the `EditableImage` alive. **Throws if `object` is `nil`.** |
| `Content.none` | constant `Content` | `SourceType = None`. |
| `Content.SourceType` | `Enum.ContentSourceType` | Which field below is non-`nil`. |
| `Content.Uri` | `string?` | |
| `Content.Object` | `Object?` | |
| `Content.Opaque` | `Opaque?` | Produced by `CreateDataModelContentAsync`. |

---

## 1. Creation and lifecycle

### 1.1 `AssetService:CreateEditableImage(editableImageOptions)`

```lua
AssetService:CreateEditableImage(editableImageOptions: Dictionary?): EditableImage
```

- **Does not yield.** No `Yields` tag in DOCS or DUMP. Safe to call inline in a render step.
- **Options:** `{ Size = Vector2.new(w, h) }`. Omit it and you get **512×512**.
  > "By default, the resolution is set at 512×512, but you can specify a different size using the
  > method's option table."
- **Failure:** returns `nil` when "the device-specific editable memory budget is exhausted."
  It does *not* throw for that case.
- **Initial contents:** `[UNVERIFIED]` — the documentation does not state what a freshly created
  blank `EditableImage` contains. Do not rely on it being transparent black; clear it explicitly
  (see [Clearing and filling](#clearing-and-filling)) before your first composite. This costs one
  `DrawRectangle` and removes an entire class of platform-dependent bug.

```lua
local AssetService = game:GetService("AssetService")

local canvas = AssetService:CreateEditableImage({ Size = Vector2.new(256, 256) })
if not canvas then
    warn("editable memory budget exhausted")
    return
end
-- Always define your starting state rather than assuming one:
canvas:DrawRectangle(
    Vector2.zero, canvas.Size,
    Color3.new(0, 0, 0), 1,                    -- transparency = 1 → fully transparent
    Enum.ImageCombineType.Overwrite
)
```

### 1.2 `AssetService:CreateEditableImageAsync(content, editableImageOptions)`

```lua
AssetService:CreateEditableImageAsync(content: Content, editableImageOptions: Dictionary?): EditableImage
```

- **Yields** (`tags: [Yields]`). Never call it inside `RenderStepped`/`Heartbeat` without
  caching — each call is a network-backed asset fetch.
- **`content` accepts**, per DOCS:
  - `Content.fromAssetId(id)` / `Content.fromUri("rbxassetid://id")` — subject to the ownership
    gate.
  - Non-asset texture URIs: "Non-asset texture IDs such as `rbxthumb://` are supported." This is
    the documented route to avatar thumbnails, group icons and asset previews.
  - `[UNVERIFIED]` whether `Content.fromObject(someOtherEditableImage)` is accepted as a clone
    path. The parameter type is `Content`, so it is syntactically legal, but DOCS never states it
    and there is no documented `EditableImage:Clone()`. To duplicate an image, create a blank one
    of the same `Size` and `DrawImage(Vector2.zero, src, Enum.ImageCombineType.Overwrite)`.
- **Options table is empty today.** DOCS: "Currently no options are available since resizing via
  `Size` is not supported." In particular you **cannot** ask for a downscaled load.
- **Resulting `Size`** is the source image's dimensions, clamped by the platform's 1024×1024
  ceiling. `[UNVERIFIED]` — DOCS does not say whether a >1024 source is downscaled, cropped or
  rejected. Read `image.Size` after loading rather than assuming it matches the asset.
- **Failure:** *throws* on a permissions failure, returns `nil` on budget exhaustion.

### 1.3 Lifetime: this is not an `Instance`

`EditableImage` inherits from `Object`, not `Instance`. There is no `Parent`. Its lifetime is
purely reference-based:

1. A Luau variable holding it keeps it alive.
2. A `Content.fromObject(image)` sitting in any property keeps it alive — DOCS calls these
   "**strong** references that hold **shared ownership** of the `Object`. Any `Content.Object`
   reference will extend the lifetime of that `Object` and prevent it from being garbage
   collected."

So an `EditableImage` assigned to a destroyed `ImageLabel`'s `ImageContent` still holds memory
until that label is itself collected. **This is the number one source of editable-memory leaks.**

### 1.4 `EditableImage:Destroy()`

```lua
EditableImage:Destroy(): ()
```

> "Destroys the contents of the image, immediately reclaiming used memory."

Note what this does **not** say: it does not say the object becomes nil, or that references to it
break. The documented effect is that the *contents* are freed and the memory is reclaimed
immediately. This matters because it is the only way to return budget to the pool deterministically
— dropping the last reference and waiting for the Luau GC is not deterministic and is not fast
enough for a system that allocates images per-frame or per-entity.

**Rule:** any subsystem that creates `EditableImage`s must own an explicit teardown that calls
`Destroy()` on each one, and must also clear the `Content` properties that referenced them (set to
`Content.none`) so the sink does not hold a strong reference to a destroyed image.

```lua
local function releaseCanvas(label: ImageLabel, image: EditableImage)
    label.ImageContent = Content.none   -- drop the strong reference FIRST
    image:Destroy()                     -- then reclaim the pixels immediately
end
```

`[UNVERIFIED]` — DOCS does not specify what happens if you draw into, read from, or display an
`EditableImage` after `Destroy()`. Treat the handle as poisoned; null it out in your own bookkeeping.

### 1.5 Server vs client vs Studio vs plugin

| Context | Creation works? | Memory budget | Replication of `Content.Object` | Notes |
|---|---|---|---|---|
| **Client (`LocalScript`)** | Yes, subject to gates 1–3 | **Budgeted** — creation can return `nil` | n/a (local only) | The normal place to do this. Client-side loading of the *logged-in player's own* assets is explicitly sanctioned. |
| **Server (`Script`)** | Yes, subject to gates 1–2 | **Unlimited** per DOCS ("the server, Studio, and plugins operate with unlimited memory") | **Broken** — see below | Server-side player-asset loading is *not* in the permission list. |
| **Studio edit/play mode** | Yes | **Unlimited** | as above | Gate 1 (the dashboard toggle) does not apply in Studio, which is exactly why this bug ships. |
| **Plugin** | Yes | **Unlimited** | n/a | The only context where `CreateAssetAsync` upload is available (alongside Open Cloud Luau execution). |

The replication problem, quoted verbatim from `Content.yaml`:

> Replication is not yet supported for `Content.Object` values. When an `Instance` with a `Content`
> property containing a `Content.Object` value is replicated, an unusable placeholder `Object` of
> the same type will be used instead of the `Object` itself, and any attempt to read or write the
> contents of that placeholder object will throw. **These placeholder objects will render as a cyan
> and magenta checkerboard pattern.**
>
> This will be replaced with standard replication behavior in the future. For now, **do not use
> `EditableImage` or `EditableMesh` as `Content` on the server on an `Instance` that can replicate
> to clients.**

**If you see a cyan/magenta checkerboard in your game, this is the cause.** It is the engine's
"placeholder Object from a failed replication" texture.

### 1.6 The two sanctioned patterns for server-authored imagery

**Pattern A — replicate the recipe, render on the client.** Send the parameters
(seed, palette, layer list, damage values) over a `RemoteEvent` and build the `EditableImage` in a
`LocalScript`. This is the default and correct answer for almost every genre: every client spends
its own budget, nothing large crosses the wire, and exploiters can only corrupt their own view.

**Pattern B — `CreateDataModelContentAsync`.** The documented escape hatch:

```lua
AssetService:CreateDataModelContentAsync(content: Content, options: Dictionary?)
    : (Enum.CreateContentResult, Content)
```

> "Creates ephemeral, `DataModel`-scoped content from the provided content input. […] Currently,
> this only supports `Content` wrapping an `EditableMesh` or `EditableImage`. […] If the server
> storage budget is exhausted during this call, the creation will fail and the method will return
> `Enum.CreateContentResult.StorageLimitExceeded` alongside an empty `Content` object."

The returned `Content` has `SourceType == Enum.ContentSourceType.Opaque`. It is **ephemeral** —
scoped to the running `DataModel`, i.e. the server instance — and therefore not a permanent asset
ID, but it is a content handle rather than a raw object reference.

```lua
local ok, opaque = AssetService:CreateDataModelContentAsync(Content.fromObject(generated))
if ok == Enum.CreateContentResult.Success then
    part.Decal.ColorMapContent = opaque
end
```

`[UNVERIFIED]` — DOCS does not explicitly state that an `Opaque` `Content` replicates to clients,
only that `Object` content does not and that `Opaque` is `DataModel`-scoped. The wording strongly
implies it is the replication fix, and `Enum.ContentSourceType.Opaque` is a distinct source type
from `Object`, but **test this before you build a shipping feature on it.** Also unverified: the
size of the "server storage budget" and whether the content is ever garbage-collected during the
server's life.

---

## 2. Size and memory

### 2.1 `Size` is read-only, and there is no resize

```
EditableImage.Size : Vector2   -- ReadOnly, NotReplicated, thread_safety: ReadSafe
```

> "Size of the `EditableImage` in pixels. **The maximum size is 1024×1024.** An `EditableImage`
> cannot be resized; this property is read-only. In order to resize or crop an image, create a new
> `EditableImage` and use `DrawImageTransformed()` to transfer the contents; then call
> `Destroy()`."
> <sub>[EditableImage.yaml → `Size`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml)</sub>

That paragraph *is* the resize and crop API. There is no `Resize` method and no `Crop` method in
DOCS or DUMP. If a tutorial calls `image:Resize(...)` or `image:Crop(...)`, it is out of date.

**Resize, verbatim from the documented recipe:**

```lua
local function resized(src: EditableImage, newSize: Vector2, pixelated: boolean?): EditableImage?
    local dst = AssetService:CreateEditableImage({ Size = newSize })
    if not dst then return nil end

    dst:DrawImageTransformed(
        newSize / 2,                          -- destination position = where the pivot lands
        newSize / src.Size,                   -- per-axis scale factors
        0,                                    -- rotation, degrees
        src,
        {
            CombineType  = Enum.ImageCombineType.Overwrite,
            SamplingMode = pixelated and Enum.ResamplerMode.Pixelated or Enum.ResamplerMode.Default,
            PivotPoint   = src.Size / 2,      -- explicit, though this is also the default
        }
    )
    return dst
end
```

**Crop** is the same call with `scale = Vector2.one` and a `PivotPoint` chosen so that the region
you want lands inside the destination:

```lua
-- Crop the rect (origin, size) out of src into a new image of exactly `size`.
local function cropped(src: EditableImage, origin: Vector2, size: Vector2): EditableImage?
    local dst = AssetService:CreateEditableImage({ Size = size })
    if not dst then return nil end
    dst:DrawImageTransformed(
        size / 2,                 -- centre of the destination
        Vector2.one,              -- 1:1
        0,
        src,
        {
            CombineType = Enum.ImageCombineType.Overwrite,
            PivotPoint  = origin + size / 2,   -- the centre of the source region we want
        }
    )
    return dst
end
```

Remember to `Destroy()` the source when you are done with it; the budget is not returned otherwise.

### 2.2 Bytes per image

The pixel format the scripting API exposes is 8-bit RGBA (see
[§3](#3-pixel-access-the-buffer-format)), so the **logical** payload is:

```
bytes = width * height * 4
```

| Resolution | Logical bytes | MiB |
|---:|---:|---:|
| 64 × 64 | 16,384 | 0.016 |
| 128 × 128 | 65,536 | 0.063 |
| 256 × 256 | 262,144 | 0.25 |
| 512 × 512 (default) | 1,048,576 | 1.00 |
| 1024 × 1024 (max) | 4,194,304 | 4.00 |

Note that halving a dimension quarters the cost. The jump from 512 to 1024 is a **4×** memory and
**4×** per-pixel-loop cost. Most "HD" texture features on Roblox are a 512 that nobody notices is
not a 1024.

This is the *logical* size. `[UNVERIFIED]` — the engine's actual accounting almost certainly
includes a GPU-side copy and possibly mip levels, so the real charge against the budget is
**at least** `w*h*4` and plausibly ~1.33× that if mips are generated. DOCS gives no figure. Budget
your design at 2× the table above and you will not be surprised.

### 2.3 The editable memory budget

Quoted from `EditableImage.yaml`:

> #### Memory Limits
>
> Editable assets are currently expensive for memory usage. To minimize its impact on client
> performance, `EditableImage` has **strict client-side memory budgets**, although **the server,
> Studio, and plugins operate with unlimited memory**. Linking one `EditableImage` to multiple
> image-related `Content` data types (**multi-referencing**) can help with memory optimization.

And from both creation methods:

> "If the device-specific editable memory budget is exhausted, creation fails and this method
> returns `nil`."

Everything that is actually documented about the budget is in those two quotes. Specifically:

- It is **client-side only**.
- It is **device-specific** — a low-end Android phone and a desktop do not get the same budget, so
  a feature that fits on your machine can fail on a third of your players.
- It is **shared between `EditableImage` and `EditableMesh`** — the `EditableMesh.yaml` text is
  identical and refers to the same "editable memory budget". Mesh-heavy features steal image
  budget and vice versa.
- Exhaustion **returns `nil`; it does not throw.**

**No numeric budget is published in the creator-docs source.** I was not able to locate a dedicated
editable-assets memory-budget guide page in `Roblox/creator-docs@main`: the paths under
`content/en-us/assets/editable/`, `content/en-us/projects/assets/editable-assets.md`,
`content/en-us/optimization/editable-assets.md` and similar all return 404, and neither
`EditableImage.yaml` nor `EditableMesh.yaml` links to such a page (they link only to
`projects/groups.md` and `projects/assets/privacy.md`). The budget wording lives entirely inside
the two class descriptions.

`[COMMUNITY, SECOND-HAND]` DevForum discussion (accessed only via web-search summaries, not
verifiable first-hand from here) consistently cites a client-side editable budget of
**approximately 32 MB**, and developers report hitting it after roughly **5–6** large
`EditableImage`s. 32 MB / 4 MB-per-1024² is 8 images of maximum size, which is consistent with 5–6
once mesh usage and overhead are included. **Treat 32 MB as a planning heuristic, not a
specification.** Relevant threads (titles from search results; content not fetched):
"Failed to create empty EditableImage that was requested due to reaching memory budget limits
error", "Remove Editable Mesh/Image limit on the client", "EditableImage higher resolution and
memory limit".

### 2.4 Multi-referencing: the documented optimization

DOCS explicitly recommends: "Linking one `EditableImage` to multiple image-related `Content` data
types (multi-referencing) can help with memory optimization."

```lua
-- ONE image, many sinks. Costs one image's worth of budget, not four.
local shared = Content.fromObject(generatedTexture)
for _, part in workspace.Crates:GetChildren() do
    part.Decal.ColorMapContent = shared
end
```

This is the difference between a crate-texture system that costs 1 MB and one that costs 60 MB.
Design your content pipeline around *atlases and shared canvases*, not per-entity images:

- **One atlas, many UVs.** Generate a single 1024² sheet and point many `Decal`s / `MeshPart`s at
  it, using `Texture.StudsPerTileU/V` and `OffsetStudsU/V`, or mesh UVs, to pick sub-rects.
- **One canvas, many frames.** A minimap, a radar and a damage overlay can be three regions of one
  image rather than three images.
- **Pool and recycle.** Keep a fixed pool of N canvases sized to your worst case and hand them out;
  never allocate per-entity or per-frame.

### 2.5 A budget-aware allocator

Because failure is `nil` and the budget is shared and device-specific, production code should own
its allocations rather than calling `CreateEditableImage` at arbitrary call sites:

```lua
local ImagePool = {}
ImagePool.__index = ImagePool

function ImagePool.new(size: Vector2, capacity: number)
    local self = setmetatable({ size = size, free = {}, live = 0, capacity = capacity }, ImagePool)
    return self
end

function ImagePool:acquire(): EditableImage?
    local reused = table.remove(self.free)
    if reused then return reused end
    if self.live >= self.capacity then
        return nil  -- refuse before the engine does, so failure is ours to handle
    end
    local img = AssetService:CreateEditableImage({ Size = self.size })
    if img then
        self.live += 1
    end
    return img       -- may still be nil: the device budget is the real authority
end

function ImagePool:release(img: EditableImage)
    -- Clear it so a recycled canvas never leaks a previous tenant's pixels.
    img:DrawRectangle(Vector2.zero, self.size, Color3.new(), 1, Enum.ImageCombineType.Overwrite)
    table.insert(self.free, img)
end

function ImagePool:destroyAll()
    for _, img in self.free do img:Destroy() end
    table.clear(self.free)
    self.live = 0
end
```

Pick `capacity` from the *device*, not from the design: a sensible policy is to probe at startup
(allocate until you get `nil`, release everything, keep the count) or to key off
`UserInputService.TouchEnabled` and memory-class heuristics, and then hard-cap.

---

## 3. Pixel access: the buffer format

### 3.1 The two methods

```lua
EditableImage:ReadPixelsBuffer(position: Vector2, size: Vector2): buffer
EditableImage:WritePixelsBuffer(position: Vector2, size: Vector2, buffer: buffer): ()
```

DOCS, `ReadPixelsBuffer`:

> "Reads a rectangular region of pixels from an `EditableImage` and returns it as a buffer. **Each
> number in the buffer is a single byte, with pixels stored in a sequence of four bytes (red,
> green, blue, and alpha).**
>
> Note that this method uses **alpha** instead of transparency, unlike the `EditableImage` drawing
> methods."
>
> Returns: "Buffer where each pixel is represented by four bytes (red, green, blue and alpha
> respectively). **The length of the buffer can be calculated as `Size.X * Size.Y * 4` bytes.**"

DOCS, `WritePixelsBuffer`: identical format language, plus "The length of the buffer **should be**
`Size.X * Size.Y * 4` bytes."

Both carry the `CustomLuaState` tag. `ReadPixelsBuffer` is `thread_safety: Safe`;
`WritePixelsBuffer` is `Unsafe`.

### 3.2 Exact layout

| Aspect | Value | Confidence |
|---|---|---|
| Channel order | **R, G, B, A** | **Verified** — DOCS states "(red, green, blue, and alpha respectively)". |
| Bytes per channel | **1** (`u8`) | **Verified** — DOCS: "Each number in the buffer is a single byte." |
| Bytes per pixel | **4** | **Verified** — DOCS: `Size.X * Size.Y * 4`. |
| Value range | **0–255 integer**, where 255 = full intensity / fully opaque | **Verified by implication** (single unsigned byte) + community libraries write `component * 255`. |
| Semantics of the 4th channel | **Alpha**, not transparency. `255` = opaque, `0` = invisible. | **Verified** — DOCS calls this out explicitly on both methods. |
| Row order | **Top-to-bottom**, row-major (`y` outer, `x` inner) | **Verified by implication**: the class description fixes the origin at top-left with bottom-right at `(Size.X-1, Size.Y-1)`, and two independent production libraries index this way (below). |
| Premultiplied alpha? | **No — straight/unassociated alpha** | `[UNVERIFIED]` — see §3.6. |
| Colour space | `[UNVERIFIED]` — DOCS does not say whether the bytes are sRGB-encoded or linear. Treat them as sRGB (the same values you would put in a PNG), which is what every community library assumes. |

### 3.3 The index math

For a buffer read as `ReadPixelsBuffer(Vector2.new(ox, oy), Vector2.new(W, H))`, the pixel at
**image** coordinate `(x, y)` lives at **buffer** offset:

```
local lx, ly = x - ox, y - oy              -- coordinates local to the region
local offset = (ly * W + lx) * 4           -- 0-based byte offset of the R channel
-- offset + 0 = R, offset + 1 = G, offset + 2 = B, offset + 3 = A
```

`buffer` offsets in Luau are **0-based**, so the very first pixel's red byte is at offset `0` and
the last pixel's alpha byte is at `W * H * 4 - 1`.

Two independent, widely used community libraries implement exactly this:

- **OSGL** (`osgl-rbx/osgl`, `src/bitmap.luau`): `buffer.readu8(self.buffer, (y * self.width + x) * self.channels + (channel - 1))`
  — 0-based, row-major, channel-interleaved.
  <sub>[bitmap.luau](https://raw.githubusercontent.com/osgl-rbx/osgl/main/src/bitmap.luau)</sub>
- **FastCanvas** (`Ethanthegrand/FastCanvas`): `GetGridIndex(X, Y) = (X + (Y - 1) * Width) * 4 - 4`
  — the same formula written for 1-based `X, Y`, which is algebraically `((y-1)*W + (x-1))*4`.
  It then does `buffer.writeu8(Grid, Index + 0..3, R, G, B, A)` and renders with
  `EditableImage:WritePixelsBuffer(Origin, Resolution, Grid)`.
  <sub>[FastCanvas.luau](https://raw.githubusercontent.com/Ethanthegrand/FastCanvas/main/FastCanvas.luau)</sub>

### 3.4 Working code — full read

```lua
local AssetService = game:GetService("AssetService")

-- Read every pixel and compute the average colour.
local function averageColor(image: EditableImage): Color3
    local w, h = image.Size.X, image.Size.Y
    local px = image:ReadPixelsBuffer(Vector2.zero, image.Size)   -- length = w * h * 4

    local rs, gs, bs, n = 0, 0, 0, w * h
    for i = 0, n - 1 do
        local o = i * 4
        rs += buffer.readu8(px, o)
        gs += buffer.readu8(px, o + 1)
        bs += buffer.readu8(px, o + 2)
    end
    return Color3.fromRGB(rs // n, gs // n, bs // n)
end
```

Note the flat `for i = 0, n-1` loop: when you touch *every* pixel you never need `x` and `y`, and a
single-counter loop is meaningfully faster than nested loops with a multiply inside.

### 3.5 Working code — full write

```lua
-- Generate a 256x256 radial gradient from scratch and push it in one call.
local SIZE = Vector2.new(256, 256)
local W, H = SIZE.X, SIZE.Y

local image = AssetService:CreateEditableImage({ Size = SIZE })
assert(image, "editable memory budget exhausted")

local px = buffer.create(W * H * 4)

local cx, cy = (W - 1) / 2, (H - 1) / 2
local maxDist = math.sqrt(cx * cx + cy * cy)

for y = 0, H - 1 do
    local rowBase = y * W * 4
    local dy = y - cy
    for x = 0, W - 1 do
        local dx = x - cx
        local t = math.clamp(1 - math.sqrt(dx * dx + dy * dy) / maxDist, 0, 1)

        local o = rowBase + x * 4
        buffer.writeu8(px, o,     math.floor(t * 255 + 0.5))          -- R
        buffer.writeu8(px, o + 1, math.floor(t * t * 255 + 0.5))      -- G
        buffer.writeu8(px, o + 2, 40)                                 -- B
        buffer.writeu8(px, o + 3, 255)                                -- A (opaque)
    end
end

image:WritePixelsBuffer(Vector2.zero, SIZE, px)   -- ONE engine call for the whole frame
```

**Keep the `buffer` alive between frames.** `buffer.create` of 1 MB every frame is pure garbage
pressure. Allocate once, mutate in place, and call `WritePixelsBuffer` once per visible change.
That is precisely the architecture FastCanvas uses: a persistent `Grid` buffer plus a single
`Canvas:Render()` that calls `WritePixelsBuffer`.

A fast whole-pixel write, when you have the RGBA packed as one 32-bit value, is
`buffer.writeu32(px, o, packed)`. **Be careful with byte order**: Luau's `buffer.writeu32` is
little-endian, so a `u32` written at offset `o` places its *least significant* byte at `o` — i.e.
the byte that becomes **R**. The correct packing is therefore:

```lua
local packed = r + g * 0x100 + b * 0x10000 + a * 0x1000000   -- R in the low byte
buffer.writeu32(px, o, packed)
```

FastCanvas's `writeu32(Grid, index, 4294967295)` for opaque white (`0xFFFFFFFF`) is
byte-order-agnostic and so does not disambiguate this; the ordering above follows from
little-endian `buffer` semantics plus the documented R-G-B-A byte sequence. `[UNVERIFIED]` as a
direct documentation claim; verified as arithmetic.

### 3.6 Working code — a single pixel

There is **no `GetPixel`/`SetPixel`**. A single-pixel write is a 1×1 region write:

```lua
local ONE = Vector2.one
local scratch = buffer.create(4)   -- reuse this; do not allocate per call

local function setPixel(image: EditableImage, x: number, y: number, color: Color3, alpha: number)
    buffer.writeu8(scratch, 0, math.floor(color.R * 255 + 0.5))
    buffer.writeu8(scratch, 1, math.floor(color.G * 255 + 0.5))
    buffer.writeu8(scratch, 2, math.floor(color.B * 255 + 0.5))
    buffer.writeu8(scratch, 3, math.floor(alpha * 255 + 0.5))
    image:WritePixelsBuffer(Vector2.new(x, y), ONE, scratch)
end

local function getPixel(image: EditableImage, x: number, y: number): (Color3, number)
    local b = image:ReadPixelsBuffer(Vector2.new(x, y), ONE)
    return Color3.fromRGB(buffer.readu8(b, 0), buffer.readu8(b, 1), buffer.readu8(b, 2)),
           buffer.readu8(b, 3) / 255
end
```

**Do not build a renderer out of this.** Each call crosses the Luau↔C++ boundary. Writing a
256×256 image one pixel at a time is 65,536 boundary crossings versus one. The whole reason
`WritePixelsBuffer` takes a region is so you do the loop in Luau over a `buffer` and cross once.

### 3.7 Alpha vs transparency — the trap

| Surface | Parameter | Opaque | Invisible |
|---|---|---|---|
| `ReadPixelsBuffer` / `WritePixelsBuffer` | **alpha byte** | `255` | `0` |
| `DrawRectangle`, `DrawCircle`, `DrawLine`, `DrawTriangle` | **`transparency: float`** | `0` | `1` |

They are inverses, on different scales, in the same class. DOCS flags it on both buffer methods:
"this method uses alpha instead of transparency, unlike the `EditableImage` drawing methods."

Conversion: `alphaByte = math.floor((1 - transparency) * 255 + 0.5)` and
`transparency = 1 - alphaByte / 255`.

### 3.8 Premultiplication

`[UNVERIFIED]` — **nothing in creator-docs states whether `EditableImage` pixel buffers are
premultiplied.** The evidence available here points to **straight (unassociated) alpha**:

- The channels are documented as plain "red, green, blue, and alpha", with no mention of
  association.
- `Enum.ImageCombineType.Multiply` is described as "RGBA values are multiplied as values between 0
  and 1", which is a straight-alpha formulation.
- `Enum.ImageCombineType.AlphaBlend` is documented as blending "based on the alpha of the source
  pixels", and is contrasted with `BlendSourceOver` on the grounds that "the destination color in
  `AlphaBlend` affects the resulting color of the image, **regardless of the destination color's
  alpha**". That distinction only makes sense if colour and alpha are stored separately.

A practical consequence either way: **do not write `(0, 0, 0, 0)` for "empty" and then expect
bilinear-filtered upscales to look clean.** With straight alpha, filtering blends the *colour* of
fully transparent pixels into visible neighbours, which produces dark halos around sprites. Write
the intended colour with `alpha = 0` instead of black-with-zero-alpha — i.e. bleed your sprite
colours into the transparent margin. This is the classic "alpha bleed" step from 2D pipelines and
it matters here because `DrawImageTransformed` defaults to `Enum.ResamplerMode.Default`
(bilinear).

**If you need certainty, measure it**: write `(255, 0, 0, 128)` with `WritePixelsBuffer`, read it
straight back, and see whether you get `(255, 0, 0, 128)` (straight) or `(128, 0, 0, 128)`
(premultiplied). A ten-line test settles it for your engine version permanently.

---

## 4. The drawing API

Seven documented methods plus one undocumented one. All are `Unsafe` (serial-only) and all are
immediate-mode: there is no retained scene, no transform stack, no clip rect, no state object. Every
call takes its full state as arguments.

### 4.1 Primitive methods

```lua
-- Rectangle. NOTE: position CANNOT be outside the canvas, unlike every other method.
DrawRectangle(
    position: Vector2,                  -- top-left of the rect
    size: Vector2,                      -- in pixels
    color: Color3,
    transparency: number,               -- 0 opaque .. 1 invisible
    combineType: Enum.ImageCombineType
): ()

-- Circle. Anti-aliased by default.
DrawCircle(
    center: Vector2,                    -- MAY be outside the canvas
    radius: number,                     -- int, pixels
    color: Color3,
    transparency: number,
    combineType: Enum.ImageCombineType,
    antiAliasing: Enum.AntiAliasing      -- default Enum.AntiAliasing.Enabled
): ()

-- Line, exactly one pixel thick.
DrawLine(
    p1: Vector2, p2: Vector2,
    color: Color3,
    transparency: number,
    combineType: Enum.ImageCombineType,
    antiAliasing: Enum.AntiAliasing      -- default Enum.AntiAliasing.Enabled
): ()

-- UNDOCUMENTED in creator-docs; present in the live API dump. No combineType, no antiAliasing.
DrawTriangle(
    p1: Vector2, p2: Vector2, p3: Vector2,
    color: Color3,
    transparency: number
): ()
```

Notes straight from DOCS:

- `DrawCircle`: "Positions outside the canvas bounds are allowed." "If the circle is
  semi-transparent, it will be blended with the pixels behind it using **source over blending**"
  — note that this sentence describes the semi-transparent case specifically and sits alongside
  the `combineType` parameter.
- `DrawLine`: "one pixel thick". There is **no thickness parameter**. For thick lines, either draw
  N parallel lines, or blit a rotated 1×N `EditableImage` with `DrawImageTransformed`.
- `DrawRectangle`: "**Unlike other drawing methods, this cannot be outside the canvas bounds.**"
  This asymmetry is a real source of runtime errors — clamp your rect before calling.
- `DrawTriangle` exists at engine version `0.739.0.7390687` and the client carries a flag named
  `EditableImageDrawTriangleEnabled`, so it is gated and may not be on for every client.
  `[UNVERIFIED]` — behaviour, winding-order sensitivity and fill rule are undocumented.

### 4.2 Blitting: `DrawImage`

```lua
DrawImage(
    position: Vector2,                  -- where the SOURCE image's TOP-LEFT lands
    image: EditableImage,
    combineType: Enum.ImageCombineType
): ()
```

"Positions outside the canvas bounds are allowed such that only part of the new image is drawn."
Straight 1:1 copy, no scaling, no filtering, no rotation. This is the fast path — use it for
sprite-sheet composition where no transform is needed.

### 4.3 Blitting with transform: `DrawImageTransformed`

```lua
DrawImageTransformed(
    position: Vector2,                  -- where the source's PIVOT lands on THIS image
    scale: Vector2,                     -- per-axis scale factors
    rotation: number,                   -- DEGREES, around the pivot
    image: EditableImage,
    options: {
        CombineType?: Enum.ImageCombineType,   -- default AlphaBlend
        SamplingMode?: Enum.ResamplerMode,     -- default Default (bilinear)
        PivotPoint?: Vector2,                  -- default image.Size / 2
    }?
): ()
```

Three things that trip people up:

1. **`position` positions the pivot, not the top-left.** `DrawImage` positions the top-left;
   `DrawImageTransformed` positions the pivot, which defaults to the *source image's centre*. The
   two methods therefore need different `position` values to produce the same result.
2. **`rotation` is degrees, not radians.** If your sprite spins 57× too fast you passed radians.
3. **The default `CombineType` here is `AlphaBlend`**, which is *not* the default anywhere else
   (the other methods have no default and require the argument). If you want a hard copy you must
   ask for `Overwrite`.

`SamplingMode = Enum.ResamplerMode.Pixelated` is mandatory for pixel-art scaling; the default
bilinear filter will smear a 16×16 sprite into mush when scaled up.

### 4.4 Projection: `DrawImageProjected` and `SampleImageProjected`

These are the decal-painting pair, and they are what makes runtime graffiti, bullet holes, blood
splatter, paint tools and avatar tattoos possible on arbitrary meshes.

```lua
DrawImageProjected(
    mesh: EditableMesh,
    projection: { Direction: Vector3, Position: Vector3, Size: Vector3, Up: Vector3 },
    brushConfig: {
        AlphaBlendType: Enum.ImageAlphaType,
        ColorBlendType: Enum.ImageCombineType,
        Decal: EditableImage,
        FadeAngle: number,        -- degrees
        BlendIntensity: number,   -- 0..1
    }
): ()
```

Semantics: *this* `EditableImage` is the mesh's **texture map**. The method projects `brushConfig.Decal`
through the `projection` volume onto `mesh`, and writes the result into *this* image **in the mesh's
UV space**. `Position` and `Up` are "in local space with respect to the mesh" — not world space.

`FadeAngle`, quoted: "the angle in degrees for the projection edges to start to fall off. The
projection will be fully faded out at 90 degrees. An angle of 0 means fading starts immediately at 0
degrees and an angle of 90 means no fading but instead a hard edge at 90 degrees. An angle of 70
degrees would mean the projection starts to fade at 70 degrees and is fully faded out at 90
degrees." This is the grazing-angle fade that stops a projected decal from smearing down the sides
of a surface.

```lua
SampleImageProjected(
    sourceMesh: EditableMesh,
    sourceTexture: EditableImage,
    projectionConfig: { Direction: Vector3, Position: Vector3, Size: Vector3, Up: Vector3 },
    brushConfig: {
        AlphaBlendType: Enum.ImageAlphaType,
        ColorBlendType: Enum.ImageCombineType,
        FadeAngle: number,        -- 180 = no normal-angle fade
    }
): ()
```

The documented inverse: "it reads from the mesh texture and writes the sampled pixels into this
image in place." Occlusion is handled — "Only mesh surfaces facing the projector and within the
projection volume are sampled. When multiple mesh surfaces project to the same destination pixel,
the closest surface is used." In `SampleImageProjected` the projector `Size.Z` is documented as the
**projection depth**, which `DrawImageProjected` does not spell out.

The intended round-trip, per DOCS: "This makes the method suitable for **sampling a brush-sized
region, modifying it in place, and then using `DrawImageProjected()` to write it back** onto a
texture." That is a read-modify-write paint brush that never touches the whole texture — the right
architecture for an in-experience painting tool, because the per-op cost scales with the brush, not
the canvas.

### 4.5 `Enum.ImageCombineType` — the compositing math

Let `S` be the source pixel and `D` the destination pixel, each with straight (non-premultiplied)
components in `[0,1]`. DOCS gives prose, not equations; the equations below are the standard
formulations that match that prose, and are marked accordingly.

| Value | DOCS prose | Math |
|---|---|---|
| `BlendSourceOver` | "source over alpha blending" | Porter–Duff *over*: `Aᵣ = Sₐ + Dₐ(1-Sₐ)`; `Cᵣ = (Sc·Sₐ + Dc·Dₐ(1-Sₐ)) / Aᵣ` (0 when `Aᵣ = 0`). **Destination alpha participates.** `[inferred from prose]` |
| `Overwrite` | "Overwrites all pixels in the destination with pixels from the source" | `Cᵣ = Sc`, `Aᵣ = Sₐ`. Exact, no blending. **Verified.** |
| `Add` | "Adds pixels from the source and destination together" | `Cᵣ = clamp(Sc + Dc)`, `Aᵣ = clamp(Sₐ + Dₐ)`. `[inferred]` — DOCS says "pixels", implying all four channels. |
| `Multiply` | "Multiplies … RGBA values are multiplied as values between 0 and 1. Values lower than 1 have a darkening effect" | `Cᵣ = Sc · Dc`, `Aᵣ = Sₐ · Dₐ`. **Explicitly all four channels** per DOCS ("RGBA"). |
| `AlphaBlend` | "Blends by the alpha of the source pixels. Unlike **BlendSourceOver**, the destination color affects the result **regardless of the destination color's alpha**." | `Cᵣ = Sc·Sₐ + Dc·(1-Sₐ)` — a plain lerp by `Sₐ` that ignores `Dₐ` in the colour term. `[inferred from prose]` |
| `NormalMapBlend` | "alpha blending, then renormalizes the resulting RGB as a tangent-space normal vector" | Do `AlphaBlend`, then map `n = 2·C - 1`, `n = n / ‖n‖`, `C = (n + 1)/2`. **Verified in prose.** |
| `Subtract` | "Subtracts pixels of the source from pixels of the destination" | `Cᵣ = clamp(Dc - Sc)`. `[inferred]` — note the direction: **destination minus source**. |

**`AlphaBlend` vs `BlendSourceOver` is the decision you will actually have to make.** The practical
difference:

- Use **`BlendSourceOver`** when you are compositing onto a canvas that has real alpha — layering
  sprites onto a transparent UI canvas, building a sprite sheet. It preserves correct alpha
  accumulation.
- Use **`AlphaBlend`** when the destination is an opaque texture and you want the source to tint it
  — painting onto a character's albedo map, applying damage decals to an opaque wall. Here
  ignoring `Dₐ` is what you want, because the destination "should" be opaque anyway.
- Getting this backwards gives the two classic symptoms: **`BlendSourceOver` onto a fully
  transparent canvas leaves your paint invisible or washed out**, and **`AlphaBlend` onto a UI
  canvas punches opaque colour into regions you wanted to stay transparent**.

`NormalMapBlend` is the *only* correct way to composite normal maps. Alpha-blending two normal maps
with `AlphaBlend` produces vectors that are no longer unit length, which shows up as flat, dull
lighting in the blended region. If you are painting dents, scratches or wetness into a
`SurfaceAppearance`'s `NormalMapContent`, use `NormalMapBlend`.

`Subtract` is comparatively new — the client carries a flag literally named
`EditableImageSubtractImageCombineType` — so code that must run on older clients should not assume
it exists.

### 4.6 Clearing and filling

There is **no `Clear()` and no `Fill()`**. The idiom is a full-canvas `DrawRectangle` with
`Overwrite`:

```lua
-- Clear to fully transparent.
image:DrawRectangle(Vector2.zero, image.Size, Color3.new(0,0,0), 1, Enum.ImageCombineType.Overwrite)

-- Fill with an opaque colour.
image:DrawRectangle(Vector2.zero, image.Size, Color3.fromRGB(20,24,32), 0, Enum.ImageCombineType.Overwrite)
```

The alternative — and the faster one when you are already maintaining a CPU-side buffer — is
`buffer.fill` plus one `WritePixelsBuffer`:

```lua
buffer.fill(px, 0, 0)                                   -- zero the whole thing
image:WritePixelsBuffer(Vector2.zero, image.Size, px)
```

FastCanvas keeps a second, pre-filled `ClearingGrid` buffer and does `buffer.copy(Grid, 0, ClearingGrid, 0)`
for its `Clear()`, which is faster than re-filling byte patterns and lets the clear colour be
arbitrary. That is the pattern to copy if you clear every frame.

---

## 5. Display sinks: where an `EditableImage` can actually appear

The mechanism is always the same:

```lua
someInstance.SomeContentProperty = Content.fromObject(editableImage)
```

But **not every `Content`-typed property accepts an `EditableImage`.** Several are `Content`-typed
purely as a modern wrapper around a legacy `ContentId` string and explicitly reject objects. The
table below was built by enumerating every `Content`-typed property in the engine reflection dump
(80 of them) and then reading each one's documentation text. **Do not assume; this is the list.**

### 5.1 Confirmed sinks — the property text explicitly names `EditableImage`

| Class | Property | Exact supporting language | Write security |
|---|---|---|---|
| `ImageLabel` | `ImageContent` | "Supports asset URIs and `EditableImage` objects." | None |
| `ImageButton` | `ImageContent` | "Supports asset URIs and `EditableImage` objects." | None |
| `Decal` | `TextureContent` | "Supports asset URIs and `EditableImage` objects." — **but the property is deprecated**, "Use `ColorMapContent` for future work." | None |
| `Decal` | `ColorMapContent` | The modern replacement; `Content` "that determines the color and opacity of the surface". `NotReplicated`. | None |
| `Texture` | inherited from `Decal` | `Texture` inherits `Decal` (DOCS `inherits: [Decal]`) and adds only `OffsetStudsU/V` and `StudsPerTileU/V`. So `TextureContent` / `ColorMapContent` work identically. | None |
| `MeshPart` | `TextureContent` | "Supports asset URIs and `EditableImage` objects." "the `MeshContent` property cannot be directly changed during runtime **but the texture can**." | None |
| `SurfaceAppearance` | `ColorMapContent` | "The content can hold an asset URI **or a reference to an `EditableImage` object**. … Assigning an `EditableImage` is useful for dynamically generating or modifying textures at runtime." | **`PluginSecurity`** |
| `SurfaceAppearance` | `NormalMapContent` | "…or a reference to an `EditableImage` object." | **`PluginSecurity`** |
| `SurfaceAppearance` | `RoughnessMapContent` | "…or a reference to an `EditableImage` object." | **`PluginSecurity`** |
| `SurfaceAppearance` | `MetalnessMapContent` | "…or a reference to an `EditableImage` object." | **`PluginSecurity`** |
| `SurfaceAppearance` | `EmissiveMaskContent` | PBR slot; `Content`-typed, grayscale mask. | **`PluginSecurity`** |
| `FileMesh` / `SpecialMesh` | `TextureContent` | "accepts `Content` values including asset URIs and `EditableImage` objects. … **When `TextureContent` references an `EditableImage`, the texture live-updates with any edits to that object.** This property is inherited by `SpecialMesh`." | None |
| `AdGui` | `FallbackImageContent` | "Unlike `FallbackImage`, this property accepts asset URIs **and references to `EditableImage` objects**." | None |

`FileMesh.TextureContent` is the only place in the entire documentation set that states outright
that **the texture live-updates when the `EditableImage` is edited**. That is almost certainly the
general behaviour for all object-content sinks (it is the entire point of the API and matches the
"one image update per frame" throttle), but it is documented in exactly one place.

### 5.2 The `PluginSecurity` wall on `SurfaceAppearance` and `Decal` PBR slots

This is the single biggest structural gotcha in the whole feature.

**`SurfaceAppearance.ColorMapContent`, `NormalMapContent`, `RoughnessMapContent`,
`MetalnessMapContent` and `EmissiveMaskContent` all have `security: { read: None, write:
PluginSecurity }`.** So does `Decal.NormalMapContent`, `Decal.RoughnessMapContent`,
`Decal.MetalnessMapContent` and `Decal.EmissiveMaskContent`. **A normal game script cannot write
them.** Only plugins can.

The engine's answer is the two builder methods, which construct the instance with its maps already
attached:

```lua
-- PBR material, generated at runtime, from a game script.
local surface = AssetService:CreateSurfaceAppearanceAsync({
    ColorMap     = Content.fromObject(albedo),
    NormalMap    = Content.fromObject(normals),
    RoughnessMap = Content.fromObject(rough),
    MetalnessMap = Content.fromObject(metal),
    EmissiveMask = Content.fromObject(emissive),
})
surface.Parent = meshPart
```

```lua
-- PBR decal, generated at runtime, from a game script.
local decal = AssetService:CreateDecalAsync({
    TextureContent     = Content.fromObject(albedo),
    NormalMapContent   = Content.fromObject(normals),
    RoughnessMapContent= Content.fromObject(rough),
    MetalnessMapContent= Content.fromObject(metal),
})
decal.Face = Enum.NormalId.Front
decal.Parent = part
```

Both yield. Note the **different key names** between the two calls (`ColorMap` vs `TextureContent`)
— see §"Option tables". And critically, from DOCS on `CreateSurfaceAppearanceAsync`:

> "Note that the `EditableImage` assigned to each map **cannot be reassigned or swapped after the
> `SurfaceAppearance` is created**."

So: you cannot hot-swap which image a `SurfaceAppearance` points at. You can only keep editing the
*contents* of the image it already has. Design for one long-lived canvas per material, mutated over
time — not a carousel of images. `CreateDecalAsync` additionally: "Unrecognized keys are ignored
with a warning"; "raises an error if no supported maps are provided, or if any supported key has a
value that is not `Content` containing an `EditableImage`"; asset IDs, URI content and
`Content.none` are **not accepted**.

### 5.3 Confirmed NON-sinks — the docs explicitly say no

| Class | Property | Exact wording |
|---|---|---|
| `ImageButton` | `HoverImageContent` | "**Only asset URIs are supported for this property.**" |
| `ImageButton` | `PressedImageContent` | "**Only asset URIs are supported for this property.**" |
| `Shirt` | `ShirtTemplateContent` | "Although this property uses `Content`, **it does not support `EditableImage`**" |
| `Pants` | `PantsTemplateContent` | "Although this property uses `Content`, **it does not support `EditableImage`**" |
| `ShirtGraphic` | `TextureContent` | "Although this property uses `Content`, **it does not support `EditableImage`**" |
| `ScrollingFrame` | `TopImageContent`, `MidImageContent`, `BottomImageContent` | "**Only supports asset URIs as textures.**" |

The `ImageButton` case is the one that will bite a UI programmer: `ImageContent` accepts your
generated image, the hover and pressed variants silently do not. Implement hover/press states by
*redrawing* the single `ImageContent` canvas, or by stacking two `ImageLabel`s.

### 5.4 Sinks that still need a real asset ID (no `EditableImage` support documented)

These are `Content`-typed but their documentation says only "supports asset URIs" or says nothing
about objects. **Treat them as needing an uploaded asset ID until you test otherwise.**

| Class | Property | Status |
|---|---|---|
| `ParticleEmitter` | `TextureContent` | DOCS: "Supports **asset URIs**." and "This property is the `Content` equivalent of `Texture`. **Assigning `TextureContent` updates `Texture`**" — the write-through to a legacy `ContentId` strongly implies objects are not representable. `[UNVERIFIED]` but expect **no**. |
| `Sky` | `SkyboxUp/Down/Left/Right/Front/BackContent`, `SunTextureContent`, `MoonTextureContent` | DOCS describes them only as "The `Content` image displayed…". No `EditableImage` mention. `[UNVERIFIED]`. |
| `Beam` | `TextureContent` | No `EditableImage` mention in `Beam.yaml`. `[UNVERIFIED]`. |
| `Trail` | `TextureContent` | No `EditableImage` mention in `Trail.yaml`. `[UNVERIFIED]`. |
| `ImageHandleAdornment` | `ImageContent` | DOCS: "Sets the image displayed by this adornment as a `Content` value." No `EditableImage` mention. `[UNVERIFIED]`. |
| `CharacterMesh` | `BaseTextureContent`, `OverlayTextureContent`, `MeshContent` | No `EditableImage` mention. `[UNVERIFIED]`. |
| `BackpackItem` | `TextureContent` | No mention. `[UNVERIFIED]`. |
| `MaterialVariant`, `TerrainDetail` | all five PBR `*MapContent` slots | `Content`-typed, but **`PluginSecurity` on both read and write** — unusable from game scripts regardless. |
| `Mouse.IconContent`, `UserInputService.MouseIconContent`, `ClickDetector.CursorIconContent`, `DragDetector`/`UIDragDetector` cursor slots, `ScreenshotHud.CameraButtonIconContent`, `InputBinding.DisplayImage` | No `EditableImage` mention. `[UNVERIFIED]`. |

### 5.5 Two independent axes — do not conflate them

A property being **writable by a script** and a property **accepting an `EditableImage`** are
*different questions*, and confusing them is the fastest way to build a feature that silently does
nothing.

| | Write security `None` | Write security `PluginSecurity` |
|---|---|---|
| **Documented to accept `EditableImage`** | Works from a game script: `ImageLabel.ImageContent`, `ImageButton.ImageContent`, `Decal.TextureContent`/`ColorMapContent`, `Texture.*`, `MeshPart.TextureContent`, `FileMesh`/`SpecialMesh.TextureContent`, `AdGui.FallbackImageContent` | Plugin only **by property assignment** — but reachable from a game script via the builder methods: all `SurfaceAppearance.*MapContent` |
| **Not documented to accept `EditableImage`** | *A script can assign a `Content` here, but only a URI is known to render*: `ParticleEmitter.TextureContent`, `Beam.TextureContent`, `Trail.TextureContent`, all `Sky.Skybox*Content` / `SunTextureContent` / `MoonTextureContent`, `ImageHandleAdornment.ImageContent` | Unusable either way: `MaterialVariant.*MapContent`, `TerrainDetail.*MapContent` (**`PluginSecurity` on read *and* write**) |

Security levels in that table are cross-checked in **both** sources — the `security:` block in each
class YAML and the `Security` field in the reflection dump — and they agree everywhere.

The bottom-left cell is the trap. `Beam.TextureContent`, `Trail.TextureContent`,
`ParticleEmitter.TextureContent` and the eight `Sky` content properties are all
`read: None / write: None`, so **a game script may assign to them without error**. That does not
make them `EditableImage` sinks. None of their documentation mentions `EditableImage`, and
`ParticleEmitter.TextureContent`'s own text says "Supports **asset URIs**" and "Assigning
`TextureContent` updates `Texture`" — writing through to a legacy `ContentId` *string*, which cannot
represent an object. Expect assignment to succeed and the texture to not appear. `[UNVERIFIED]` —
test each one you actually need.

### 5.6 The `SurfaceAppearance` documentation contradicts itself — here is the resolution

`SurfaceAppearance.yaml`'s **class-level** description says:

> "Note that **most `SurfaceAppearance` properties cannot be modified by scripts**, as the necessary
> pre-processing is usually too expensive during runtime."

while the **property-level** description of `ColorMapContent` in the same file says:

> "The content can hold an asset URI or a reference to an `EditableImage` object. … **Assigning an
> `EditableImage` is useful for dynamically generating or modifying textures at runtime**, such as in
> avatar customization and other in-experience content creation workflows."

Both are true, and the apparent contradiction resolves cleanly once you separate the two axes above:

- **By property assignment:** plugin-only. `write: PluginSecurity` on all five map slots, in both
  DOCS and DUMP. A `Script`/`LocalScript` assigning `surfaceAppearance.ColorMapContent = ...` fails.
- **By construction:** available to any script. `AssetService:CreateSurfaceAppearanceAsync(content)`
  has `security: None` and capability `Basic` — it is **not** plugin-gated — and its documented
  contract is that "content only supports `EditableImage`". Same for
  `AssetService:CreateDecalAsync`, also `security: None` / `Basic`.

**So runtime PBR generation from a game script IS possible** — you build the instance with its maps
attached rather than attaching maps to an existing instance. What you *cannot* do at runtime is
retrofit or swap maps on a `SurfaceAppearance` that already exists (DOCS: the assigned
`EditableImage` "cannot be reassigned or swapped after the `SurfaceAppearance` is created"). Plan for
**one `SurfaceAppearance` built once per material, with long-lived canvases you keep editing in
place.**

`MaterialVariant` and `TerrainDetail` have no equivalent builder method and are `PluginSecurity` on
both read and write, so **runtime-generated `Material` variants and terrain detail maps are genuinely
out of reach** — those really do need a plugin bake and an uploaded asset ID (§8.6).

### 5.7 `ViewportFrame` is not a sink

**`ViewportFrame` has no `Content`-typed property at all** — it does not appear in the engine-wide
enumeration of `Content` properties, and `ViewportFrame.yaml` lists `Ambient`, `CurrentCamera`,
`LightColor`, `LightDirection`, `ImageColor3`, `ImageTransparency` and so on, but nothing that takes
an image. You cannot assign an `EditableImage` to a `ViewportFrame`.

What you *can* do is put a `Part`/`MeshPart` inside the `ViewportFrame` whose `TextureContent` (or
`Decal.ColorMapContent`) is your `EditableImage`. The image then appears inside the viewport by way
of the 3D object. Note that `ViewportFrame.CurrentCamera` is `NotReplicated`, so viewport setup is
client work anyway — which lines up nicely with the rule that `EditableImage` work belongs on the
client.

### 5.8 The one-update-per-frame limit

This is a **hard, global engine ceiling**, not a per-instance or per-script one, and it governs the
entire design space more than any other single fact in this chapter. Quoted from
`EditableImage.yaml`:

> #### Update Limitations
>
> **Only a single `EditableImage` can be updated per frame on the display side.** For example, if
> you update three `EditableImage` objects which are currently being displayed, it will take three
> frames for all of them to be updated.

Read this carefully — it is a limit on *display-side* updates, i.e. pushing edited pixels to the
renderer, for images that are **currently being displayed**. Consequences:

- **A 4-image composite takes 4 frames to fully appear**, at best. At 60 fps that is 67 ms of
  visible tearing between layers. If you are building something where all parts must appear at
  once (a card that flips, a loading screen), composite into **one** displayed image with
  `DrawImage`, and keep the other canvases off-screen.
- **Never drive N simultaneous animated textures.** An 8-panel animated dashboard updates each
  panel at 7.5 fps on a 60 fps client. Merge them into one atlas image and update that.
- **Off-screen work is not throttled by this rule** — the limit is on the display side. You can
  freely draw into images that are not referenced by any visible property, then blit the finished
  result into the single displayed canvas.
- This composes badly with the CPU cost of drawing: if your generation step already takes 8 ms, the
  display throttle is not your bottleneck, but as soon as you optimise the CPU side you hit this
  wall and stop getting faster.

**Architecture that respects the limit:** one visible `EditableImage` per "screen" (per UI panel,
per painted object), all sub-layers composited into it off-screen, exactly one
`WritePixelsBuffer`/`DrawImage` into the visible canvas per frame.

Together with the 1024×1024 cap and the read-only `Size`, this is the triple that bounds every
design: **one image updated per frame, at most one megapixel each, and no resizing.** Any feature
concept that needs more than that needs a different approach (an atlas, a lower resolution, or a
baked asset — §8.6).

---

## 6. Performance and the cost model

Roblox publishes no timings for these methods. What follows is a structural cost model derived from
the documented API shape plus the architecture of the community libraries that ship at scale. Any
specific number is marked.

### 6.1 The three cost axes

1. **Boundary crossings (Luau ↔ C++).** Every method call marshals arguments and re-enters engine
   code. `ReadPixelsBuffer`/`WritePixelsBuffer` are explicitly `CustomLuaState`, meaning bespoke
   marshalling, but a call is still a call. **This dominates naive code.** A 256×256 image written
   one pixel at a time is 65,536 crossings; written as one buffer it is 1.
2. **Pixels touched.** `O(w·h)` for a full write, `O(regionArea)` for a partial one, `O(πr²)` for a
   circle, `O(length)` for a line. Halving a dimension quarters the work.
3. **Display-side upload.** Capped at **one image per frame** regardless of how much you drew.

The optimisation order that follows from this is: *collapse calls* → *shrink regions* → *shrink
resolution* → *reduce the number of displayed images*.

### 6.2 Read vs write vs draw

| Operation | Shape | Where the work happens | Notes |
|---|---|---|---|
| `ReadPixelsBuffer(pos, size)` | `O(w·h)` copy out | Engine → new `buffer` | **Allocates a fresh `buffer` every call.** There is no in-place/reuse overload, so a per-frame full read creates per-frame garbage of `w·h·4` bytes. This is the most GC-hostile call in the API. |
| `WritePixelsBuffer(pos, size, buf)` | `O(w·h)` copy in | `buffer` → engine | Takes your buffer, so the buffer itself can be reused forever. Prefer this as your single per-frame sync point. |
| `DrawRectangle` | `O(area)` | Entirely engine-side | Cheapest fill. No per-pixel Luau. |
| `DrawLine` | `O(length)` | Engine-side | 1px only. AA costs extra; pass `Enum.AntiAliasing.Disabled` when you do not need it. |
| `DrawCircle` | `O(r²)` | Engine-side | AA on by default. |
| `DrawImage` | `O(area)` straight blit | Engine-side | The fast blit. No resampling. |
| `DrawImageTransformed` | `O(destArea)` with a filter tap per pixel | Engine-side | `Pixelated` (nearest) is 1 tap; `Default` (bilinear) is 4 taps. Measurably cheaper with `Pixelated`. |
| `DrawImageProjected` / `SampleImageProjected` | `O(meshTris + projectedArea)` | Engine-side, includes a depth test | The most expensive calls in the API. Keep the projector volume tight — DOCS specifically suggests brush-sized regions. |

**The single most important consequence:** if your per-pixel logic can be expressed as rectangles,
circles, lines or blits, do it with the draw methods and never touch a `buffer`. The draw methods
run entirely in engine code at native speed. `buffer` loops run in Luau. A full-canvas gradient
written pixel-by-pixel in Luau is orders of magnitude more expensive than a `DrawImage` of a
pre-made 2×2 gradient scaled up with bilinear filtering.

### 6.3 Practical resolution ceiling

Per-frame Luau pixel loops, ordered by whether they are viable at 60 fps on a mid-range device.
**These are engineering judgements, not measurements** — measure on your target hardware.

| Resolution | Pixels | Full Luau `buffer` loop each frame | Verdict |
|---:|---:|---|---|
| 64 × 64 | 4,096 | trivial | Fine every frame. |
| 128 × 128 | 16,384 | comfortable | Fine every frame. |
| 256 × 256 | 65,536 | tight | Viable at 60 fps with a simple inner loop; budget carefully. |
| 512 × 512 | 262,144 | expensive | Not every frame. Update on change, or update a sub-region. |
| 1024 × 1024 | 1,048,576 | do not | Generate once (or amortise over many frames); never regenerate per frame in Luau. |

Engine-side draw calls scale far better — a full-canvas `DrawRectangle` at 1024² is cheap. The table
above is specifically about **Luau loops over a `buffer`**.

### 6.4 Techniques that actually move the needle

- **Dirty rectangles.** Track the bounding box of what changed and call
  `WritePixelsBuffer(dirtyPos, dirtySize, subBuffer)` instead of the whole canvas. This is usually a
  10–100× win for UI-style content where only a small region changes.
- **Amortise generation across frames.** Split a 1024² generation into 16 slices of 64 rows and do
  one slice per frame. The display throttle means you cannot show more than one update per frame
  anyway.
- **Render at low resolution and upscale.** A 128² canvas on an `ImageLabel` stretched to 512 px
  with `ResampleMode` set appropriately is a quarter of the memory and a sixteenth of the pixel work.
  For stylised or blurred content nobody can tell.
- **Precompute lookup tables in `buffer`s.** Sine tables, palettes, distance fields — compute once
  at load, index at runtime. `buffer.readu8` is far cheaper than `math.sin`.
- **Use `buffer.copy` for row and block moves.** Scrolling a canvas (waveform, minimap, terminal) is
  a single `buffer.copy` of the retained region plus a small fill, not a per-pixel loop.
- **`buffer.writeu32` for whole pixels.** One 32-bit write beats four 8-bit writes when you have the
  packed value (mind the little-endian ordering in §3.5).
- **Cache `image.Size` in a local.** It is a property read across the boundary; hoist it out of
  loops. Same for the methods themselves (`local write = image.WritePixelsBuffer`).
- **Never call `CreateEditableImageAsync` in a loop.** It yields and hits the network. Load once,
  cache the `EditableImage`, blit from it.

### 6.5 Mobile

`[UNVERIFIED]` as to specifics — DOCS says only that the budget is "device-specific" and
"client-side". What follows from that:

- The budget on a low-end phone is smaller than on desktop, by an unpublished factor. A feature
  that allocates four 1024² canvases may simply return `nil` on a third of your players.
- Therefore **`nil` from `CreateEditableImage` is a normal runtime state on mobile**, not an
  exceptional one. Every allocation site needs a fallback path, and the fallback should be chosen
  at design time, not bolted on.
- Scale resolution by device class at startup: a single `TEXTURE_SIZE` constant chosen from a
  device heuristic, threaded through every allocation, is the cheapest possible insurance.
- Luau pixel loops are CPU-bound, and phone CPUs are 3–5× slower than desktop for scalar code. The
  resolution table in §6.3 should be shifted down one row for mobile.

---

## 7. Parallel Luau and thread safety

The engine's own thread-safety metadata is unambiguous, and it is bad news for anyone hoping to
render on worker actors.

| Member | `thread_safety` | Meaning in parallel code |
|---|---|---|
| `EditableImage.Size` | `ReadSafe` (shown as "Read Parallel") | **Can be read** in parallel. Cannot be written — it is `ReadOnly` anyway. |
| `EditableImage:ReadPixelsBuffer` | **`Safe`** | **Can be called** in parallel. |
| `EditableImage:WritePixelsBuffer` | `Unsafe` | **Cannot be called** in parallel. |
| `EditableImage:Destroy` | `Unsafe` | Cannot be called in parallel. |
| every `Draw*` method | `Unsafe` | **Cannot be called** in parallel. |
| `AssetService:CreateEditableImage` | `Unsafe` | Cannot be called in parallel. |
| `AssetService:CreateEditableImageAsync` | `Unsafe` | Cannot be called in parallel (and yields). |

Definitions, from the multithreading guide:

> **Unsafe** — properties: "Cannot be read or written in parallel." functions: "**Cannot be called in
> parallel.**"
> **Read Parallel** — properties: "Can be read but not written in parallel."
> **Safe** — "Can be read and written." / "Can be called."
>
> "If an API member doesn't specify a thread safety level, by default its thread safety level is
> **Unsafe**."
> <sub>[scripting/multithreading.md](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md)</sub>

### 7.1 The only correct parallel architecture

Exactly one engine call — `ReadPixelsBuffer` — is legal in parallel. Everything that *mutates* an
image must run in serial. So the pattern is:

**Parallel phase:** do the maths. Read source pixels (`ReadPixelsBuffer` is `Safe`), run your
generator over a plain Luau `buffer`, fill it.
**Serial phase (`task.synchronize()`):** one `WritePixelsBuffer`, or one `Draw*` call sequence.

```lua
-- Inside an Actor-parented script.
local px = buffer.create(W * H * 4)          -- owned by this actor, reused every frame

RunService.Heartbeat:Connect(function(dt)
    task.desynchronize()
        -- LEGAL in parallel: pure Luau + ReadPixelsBuffer.
        local src = sourceImage:ReadPixelsBuffer(Vector2.zero, sourceImage.Size)
        computeFrameInto(px, src, dt)        -- your generator, no engine calls
    task.synchronize()
        -- ILLEGAL in parallel; must be here.
        canvas:WritePixelsBuffer(Vector2.zero, CANVAS_SIZE, px)
end)
```

This is genuinely useful: for a generator where the arithmetic dominates (Perlin noise, ray
marching, cellular automata, physics-driven distortion), the expensive part is exactly the part that
parallelises. What you cannot do is fan out the *drawing* across actors.

### 7.2 Sharing buffers between actors

Actors do not share Luau state. A `buffer` created in one actor is not visible in another. Options:

- **`SharedTable`** — the guide notes "Sending a shared table to another actor doesn't make a copy of
  the data… shared tables allow safe and atomic updates by multiple scripts simultaneously." Viable
  for coordination and small payloads.
- **Partition by region.** Give each actor a disjoint horizontal band of the image, have each
  produce its own `buffer`, and in the serial phase issue one `WritePixelsBuffer` per band with the
  band's `position`/`size`. Since `WritePixelsBuffer` takes an arbitrary rectangle, N actors can
  each own N/1 of the canvas with no shared state at all. **This is the scaling pattern.**
- `[UNVERIFIED]` — whether passing a `buffer` across an actor boundary via `BindableEvent`/`SharedTable`
  copies or shares the underlying memory. Assume it copies and size your messages accordingly.

### 7.3 Race hazards even in serial code

`Content.fromObject` hands out a **strong, shared-ownership reference**. If two systems both hold
the same `EditableImage` and both draw into it, the result is interleaved by call order, with no
locking and no dirty tracking. Because multi-referencing is the *recommended* memory optimisation,
this is a realistic hazard. Give every shared canvas exactly one writer, and route all edits through
it.

---

## 8. Saving and uploading generated images

There are **three** distinct ways to persist an `EditableImage`, with very different constraints.

### 8.1 `CreateAssetAsync` — a real, permanent asset ID (plugins / Open Cloud only)

```lua
AssetService:CreateAssetAsync(object: Object, assetType: Enum.AssetType, requestParameters: Dictionary?)
    : (Enum.CreateAssetResult, number)
```

DOCS states the supported pairing explicitly:

> - `Enum.AssetType.Image` – with `object` as any valid `EditableImage` root.

and the hard restriction:

> "Currently, this method can only be used in **locally loaded plugins** and uploads assets without
> prompting first."

`requestParameters`: `{ Name, Description, CreatorId, CreatorType, IsPackage }`. `CreatorId` and
`CreatorType` "Default to the logged in Roblox Studio user for Plugin context. **Required for Open
Cloud Luau Execution context.**" — so Open Cloud Luau execution is the second supported context even
though the prose sentence only names plugins. The client also carries a flag literally named
`AllowEditableApisInCloudExecution`, consistent with that.

```lua
-- Plugin context.
local ok, idOrErr = pcall(function()
    return AssetService:CreateAssetAsync(generated, Enum.AssetType.Image, {
        Name = "GeneratedTileset",
        Description = "Built by the tileset tool",
    })
end)
-- returns (Enum.CreateAssetResult, assetId)
```

`CreateAssetVersionAsync(object, assetType, assetId, requestParameters)` updates an existing asset in
place, same contexts, returning `(Enum.CreateAssetResult, versionNumber)`.

**Result codes:** `Success`, `PermissionDenied`, `UploadFailed`, `Unknown`. Both methods carry the
`AssetCreateUpdate` capability.

**What this means in practice:** this is a *tooling* API, not a runtime one. It is how you build a
Studio plugin that bakes procedural textures into your place's assets at build time. It is **not**
how a player saves their painted skin.

### 8.2 `PromptCreatePlatformContentAsync` — the in-experience UGC path (models only, today)

```lua
AssetService:PromptCreatePlatformContentAsync(player: Player, object: Object, assetType: Enum.AssetType)
    : (Enum.PromptCreateAssetResult, number)
```

> "Allows in-experience asset creation for users by prompting a publish dialog. … Upon submitting,
> it saves the asset to the user's inventory. **Can only be invoked on the server side.**"
> `assetType`: "The asset type. **Currently can only be `Enum.AssetType.Model`.**"

So you **cannot** publish an `EditableImage` as a standalone `Image` asset from inside an experience
today. But `EditableImage.yaml` documents an indirect route:

> "When you use `AssetService:PromptCreatePlatformContentAsync()` to publish an object that has a
> `Content` property which references an `EditableImage`, **the editable image is published as an
> image and the property is set to a new asset ID**."

That is the working pattern: wrap your generated texture in a `Model` (a `MeshPart` with
`TextureContent = Content.fromObject(image)`, or a part with a `Decal`), publish the **Model**, and
the engine uploads the referenced image as a side effect and rewrites the property to the new asset
ID. This is exactly how in-experience avatar creation works.

Caveats from DOCS: the object "Currently can't contain scripts or nest non-public assets." Result
codes include `UGCValidationFailed`, `ModeratedName`, `PurchaseFailure`, `TokenInvalid`,
`NoUserInput`, `Timeout` — plan a real error-handling UI, because most of these are user-visible
outcomes rather than programmer errors.

**Server-side only**, and the `EditableImage` must be reachable from the published object. Note the
tension with the replication rule (§1.5): the object is on the server, but you must not let it
replicate to clients while it holds an `Object`-content property. Build it under `ServerStorage`,
publish, then use the returned asset ID.

### 8.3 `CreateDataModelContentAsync` — ephemeral, not permanent

Covered in §1.6. It produces a `DataModel`-scoped `Opaque` `Content` — usable while this server
instance lives, gone afterwards, not an asset ID, subject to a "server storage budget" that reports
`Enum.CreateContentResult.StorageLimitExceeded`. Use it for "this round's generated textures", not
for anything a player expects to keep.

### 8.4 Open Cloud

`[UNVERIFIED]` for anything beyond the two sentences above. DOCS mentions "Open Cloud Luau Execution
context" only as a place where `CreatorId`/`CreatorType` become required in
`CreateAssetAsync`/`CreateAssetVersionAsync`. There is no documented Open Cloud *REST* endpoint that
takes `EditableImage` pixel data — the Open Cloud assets API takes image *files*, which is a
different thing entirely. If you need a pipeline that generates textures outside Roblox and uploads
them, that is the Open Cloud Assets API with a PNG, not `EditableImage`.

### 8.5 Decision table

| You want to… | Use | Context | Permanent? |
|---|---|---|---|
| Bake procedural textures into your place at build time | `CreateAssetAsync` | Plugin / Open Cloud Luau | Yes, real asset ID |
| Let a player save a customised item to their inventory | `PromptCreatePlatformContentAsync` with a **Model** wrapping the image | Server | Yes, real asset ID |
| Share a generated texture with all clients this round | `CreateDataModelContentAsync` | Server | No, `DataModel`-scoped |
| Show a generated texture to one player | `Content.fromObject` directly | Client | No |
| Persist a generated texture across sessions | Store the **recipe** (seed/params) in a DataStore and regenerate | Either | n/a — and this is usually the right answer |

**The last row is the one most teams should take.** A 1024² image is 4 MB; a seed and a parameter
table is 200 bytes. Store the recipe, regenerate on the client at load. It is cheaper, it replicates
trivially, it dodges every permission gate, and it lets you change the art later by shipping new
generation code instead of re-uploading assets.

### 8.6 The bake-at-edit-time pipeline (the strongest production pattern)

Because `CreateAssetAsync` accepts an `EditableImage` root but only from plugins and Open Cloud Luau
execution, there is a pipeline available that most teams overlook and that **eliminates every
constraint in this document**:

1. Write your texture generator as a **module** that takes parameters and returns an
   `EditableImage`.
2. Wrap it in a **Studio plugin** that calls the module over your parameter matrix and uploads each
   result with `AssetService:CreateAssetAsync(image, Enum.AssetType.Image, {...})`.
3. Ship the resulting **asset IDs** as ordinary `rbxassetid://` content in your place.

What this buys you, item by item against the rest of this chapter:

- **No verification gate at runtime.** The shipped game uses plain asset IDs; the Mesh/Image API
  toggle is irrelevant to players.
- **No editable memory budget at runtime.** Zero. The images are ordinary compressed textures
  streamed by the engine.
- **No replication landmine.** Asset IDs replicate natively.
- **No one-image-per-frame throttle.** Nothing is being edited.
- **No mobile risk.** Standard texture streaming handles device tiers for you.
- **Better compression.** Uploaded images get the engine's texture compression; an `EditableImage`
  is uncompressed RGBA in memory.

Use runtime `EditableImage` only for content that genuinely *cannot* be enumerated ahead of time —
player-authored painting, per-match procedural variation, live data visualisation, avatar
composition. Everything that can be baked, should be. The single most common mistake in this space
is using a runtime API to solve a build-time problem.

---

## Gotchas

A consolidated re-read list. Each line restates something established above, with the section that
proves it.

### Correctness

| # | Gotcha | § |
|---|---|---|
| 1 | **Alpha vs transparency inversion.** Buffers use alpha (255 = opaque); every `Draw*` uses transparency (0 = opaque). Documented, and still the most common bug. | 3.7 |
| 2 | `DrawImageTransformed` positions the **pivot**; `DrawImage` positions the **top-left**. Swapping them shifts your sprite by half its size. | 4.3 |
| 3 | `DrawImageTransformed` rotation is in **degrees**. | 4.3 |
| 4 | `DrawImageTransformed` defaults to `AlphaBlend`; nothing else has a default. Pass `Overwrite` explicitly for a hard copy. | 4.3 |
| 5 | `DrawRectangle` **cannot** be positioned outside the canvas; every other method can. Clamp. | 4.1 |
| 6 | `DrawLine` is exactly **1 pixel** thick — no thickness parameter. | 4.1 |
| 7 | `Content.fromObject(nil)` throws; `Content.fromAssetId(math.huge)` throws. | API surface |
| 8 | A blank `EditableImage`'s initial contents are **undocumented**. Clear it explicitly. | 1.1 |
| 9 | `Size` is `ReadOnly`. Resize = new image + `DrawImageTransformed` + `Destroy` the old. | 2.1 |
| 10 | `SurfaceAppearance` maps **cannot be swapped** after creation. One canvas per material, forever. | 5.6 |

### Filtering and resampling

| # | Gotcha | § |
|---|---|---|
| 11 | **Bilinear is the default resampler.** Pixel art must pass `SamplingMode = Enum.ResamplerMode.Pixelated`. | 4.3 |
| 12 | **Alpha bleed matters.** Filtering blends the colour of fully transparent pixels into visible neighbours. Write the intended colour with `alpha = 0` in transparent margins, or you get dark halos when scaled. | 3.8 |
| 13 | **Normal maps need `NormalMapBlend`.** Anything else leaves non-unit normals and flat lighting. Roblox expects **OpenGL-format** tangent-space normals (G channel *not* inverted). | 4.5, 5.1 |
| 14 | `Multiply` multiplies **RGBA**, alpha included — not a no-op on alpha even against opaque white. | 4.5 |

### Memory and leaks

| # | Gotcha | § |
|---|---|---|
| 15 | `Content.fromObject` is a **strong, shared-ownership reference**. Set the property to `Content.none` *before* destroying the image. | 1.3 |
| 16 | Not calling `Destroy()` is a **leak**, not a slow collection. `Destroy()` reclaims immediately; the GC does not, deterministically. | 1.4 |
| 17 | `ReadPixelsBuffer` **allocates a new `buffer` every call.** Per-frame full reads are per-frame megabyte allocations. | 6.2 |
| 18 | The budget is **shared with `EditableMesh`** and **device-specific**. A pool sized on your dev machine will fail on phones. | 2.3 |
| 19 | `nil` from `CreateEditableImage` is a **normal state**, not an exception. Handle it at every call site. | Gate |

### Architecture

| # | Gotcha | § |
|---|---|---|
| 20 | Server-side `EditableImage` on a replicating instance → **cyan/magenta checkerboard**. | Landmine |
| 21 | **One display update per frame.** N animated canvases run at `60/N` fps. Composite into one. | 5.8 |
| 22 | Every **mutating** method is parallel-`Unsafe`. Only `ReadPixelsBuffer` (`Safe`) and `Size` (`ReadSafe`) are legal when desynchronized. | 7 |
| 23 | Shared canvases have **no locking**. One writer per image. | 7.3 |
| 24 | `CreateEditableImageAsync` **yields and hits the network.** Never in a loop, never per frame. | 1.2 |
| 25 | `ImageButton.HoverImageContent` / `PressedImageContent` **reject** `EditableImage`. Only `ImageContent` works. | 5.3 |
| 26 | `Decal.TextureContent` is **deprecated** in favour of `ColorMapContent`; `Decal`'s PBR slots are `PluginSecurity`-write, so use `CreateDecalAsync`. | 5.1, 5.2 |
| 27 | `ViewportFrame` has **no image-content property at all**. Texture a part inside it instead. | 5.7 |
| 28 | A property being script-writable does **not** mean it accepts an `EditableImage`. Assignment can succeed and render nothing. | 5.5 |

### Mobile

| # | Gotcha | § |
|---|---|---|
| 29 | Smaller budget, slower Luau, same 1024² ceiling. Choose a resolution per device class at startup and thread it through every allocation. `[UNVERIFIED]` — no published device tiers. | 6.5 |

---

## Version churn: what changed and what stale tutorials get wrong

`EditableImage` has been reworked repeatedly since its 2023 Studio beta. Because the API was in beta
for roughly two years, **the majority of tutorial content that ranks well is written against an API
that no longer exists.** Here is the changelog as it can be reconstructed from the live reflection
dump versus what tutorials show.

### Change 1 — pixel APIs: tables → buffers

- **Then:** `EditableImage:ReadPixels(position, size)` returned an array of numbers, and
  `EditableImage:WritePixels(position, size, pixels)` took one. `[COMMUNITY, SECOND-HAND]` The
  signature is reported as `WritePixels(position: Vector2, size: Vector2, pixels: {any})` — a Luau
  table with four entries per pixel as floats in `0..1`.
- **Now:** `ReadPixelsBuffer` / `WritePixelsBuffer`, taking a `buffer` of **u8** bytes.
- **Status:** the table-based methods are **absent from the engine reflection dump at
  `0.739.0.7390687`** and absent from `creator-docs@main`. They are removed, not merely deprecated.
- **What tutorials get wrong:** they iterate `#pixels` with `pixels[i]` and multiply by `255` at the
  wrong end. Two range changes happened at once — table floats in `0..1` became buffer bytes in
  `0..255`. Code that survived a naive port produces a black or white image.

### Change 2 — attachment: `Parent` → `Content.fromObject`

- **Then:** an `EditableImage` was parented to the instance that displayed it
  (`editableImage.Parent = imageLabel`), because it behaved like an `Instance`.
- **Now:** `EditableImage` inherits from `Object`, **has no `Parent`**, and is attached by assigning
  `Content.fromObject(image)` to a `*Content` property.
- **Status:** `inherits: [Object]` in DOCS, `Superclass: Object` in DUMP. Confirmed.
- **What tutorials get wrong:** `image.Parent = imageLabel` — which now errors, because the property
  does not exist.

### Change 3 — the `Content` rollout

The engine grew a parallel `*Content` property for nearly every legacy `ContentId` string property:
`ImageLabel.Image` → `ImageLabel.ImageContent`, `Decal.Texture` → `Decal.TextureContent`,
`MeshPart.TextureID` → `MeshPart.TextureContent`, and so on. **Only the `Content` variants accept
objects.** The legacy string properties read and write through to them (DOCS on `ImageLabel.Image`:
"Reads and writes to `ImageContent`"), but a string can only ever hold a URI.

Then a **second** wave renamed some of them again: `Decal.TextureContent` is now itself deprecated in
favour of `Decal.ColorMapContent`, as `Decal` grew a full PBR slot set (`NormalMapContent`,
`RoughnessMapContent`, `MetalnessMapContent`, `EmissiveMaskContent`).

- **What tutorials get wrong:** setting `imageLabel.Image = image` (a string property, with an
  object). Also: assuming any `Content`-typed property takes an object — §5.3 lists six that
  explicitly do not.

### Change 4 — the verification gate

- **Then:** during the Studio beta there was no creator-verification requirement; the APIs simply
  did not work in published experiences at all.
- **Now:** published-experience use requires **13+ age verification AND ID verification** plus the
  **Enable Mesh / Image APIs** dashboard toggle, and `CreateEditableImageAsync` enforces asset
  ownership/sharing.
- **Corroboration:** the shipping client carries flags named
  `EnablePermissionCheckOnCreatingEditableAsset`, `SimEnableEditablePermissionCheck`,
  `EditablePolicyCheckChained`, `EditableSkipPolicyCheckForStudioEditMode` and
  `EditableAssetPermissionCheckErrorCounter`.
  <sub>[FVariables.txt](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt)</sub>
  `EditableSkipPolicyCheckForStudioEditMode` is the mechanical reason Studio behaves differently.
- **What tutorials get wrong:** almost all of them predate the gate and say nothing about it. A
  tutorial that "works" and then does not work in your published game is usually this.

### Change 5 — `CreateEditableImageAsync` signature

- **Then:** took an asset ID string directly.
- **Now:** takes a `Content` (`CreateEditableImageAsync(content: Content, editableImageOptions: Dictionary?)`).
- **What tutorials get wrong:** `CreateEditableImageAsync("rbxassetid://123")`. Wrap it:
  `Content.fromUri("rbxassetid://123")` or `Content.fromAssetId(123)`.

### Change 6 — resize/crop removal

`EditableImage.Size` is now `ReadOnly`, and DOCS spells out the replacement recipe
("create a new `EditableImage` and use `DrawImageTransformed()` … then call `Destroy()`"), which
strongly implies a writable `Size` or a `Resize`/`Crop` method existed before. `[UNVERIFIED]` as to
what exactly was removed — neither DOCS nor the current DUMP records the old members, and
`CreateEditableImageAsync`'s option table still carries a note explaining its emptiness by reference
to resizing ("Currently no options are available since resizing via `Size` is not supported").

### Change 7 — additions still landing

New members visible in the live dump and/or DOCS that older material cannot mention:

- `EditableImage:DrawTriangle` — **in DUMP, not in DOCS**, behind a client flag named
  `EditableImageDrawTriangleEnabled`.
- `Enum.ImageCombineType.Subtract` (value 7) — flag `EditableImageSubtractImageCombineType`.
- `EditableImage:SampleImageProjected` — the inverse of `DrawImageProjected`.
- `AssetService:CreateDataModelContentAsync` and `Enum.CreateContentResult`.
- `AssetService:CreateDecalAsync`, `AssetService:CreateSurfaceAppearanceAsync`,
  `AssetService:ComposeDecalAsync`.
- `Enum.AntiAliasing` parameters on `DrawLine` and `DrawCircle`.

### How to sanity-check any tutorial in 10 seconds

Scan the code for these five tokens. Any hit means the tutorial is stale:

| Token | Verdict |
|---|---|
| `:WritePixels(` or `:ReadPixels(` without `Buffer` | Removed API |
| `.Parent =` on an `EditableImage` | Removed; `EditableImage` is an `Object` |
| `CreateEditableImageAsync("rbxassetid://` | Old string signature |
| `imageLabel.Image = <object>` | Wrong property; use `ImageContent` |
| `:Resize(` or `:Crop(` | Never existed in the current API |

---

## Sources

Every API claim in this document traces to one of the following. All URLs were fetched
**2026-09-17** and returned HTTP 200 unless noted.

### Primary — Roblox creator-docs source (`Roblox/creator-docs@main`)

These YAML/Markdown files are the generator input for create.roblox.com. They are higher fidelity
than the rendered pages because they carry the reflection metadata (tags, `thread_safety`,
`capabilities`, `security`, `serialization`) that the website does not always render.

Base: `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/`

**Classes** (`reference/engine/classes/<Name>.yaml`):

- [`EditableImage.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml) — class description (verification gate, permissions, memory limits, update limitation, coordinate system), `Size`, all 11 documented methods.
- [`AssetService.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AssetService.yaml) — `CreateEditableImage`, `CreateEditableImageAsync`, `CreateDecalAsync`, `CreateSurfaceAppearanceAsync`, `ComposeDecalAsync`, `CreateDataModelContentAsync`, `CreateAssetAsync`, `CreateAssetVersionAsync`, `CreateMeshPartAsync`, `PromptCreatePlatformContentAsync`.
- [`EditableMesh.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableMesh.yaml) — identical verification/permissions/memory paragraphs, confirming a shared budget.
- [`ImageLabel.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ImageLabel.yaml) · [`ImageButton.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ImageButton.yaml) — `ImageContent` accepts `EditableImage`; `HoverImageContent`/`PressedImageContent` do not.
- [`Decal.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Decal.yaml) — `TextureContent` (deprecated), `ColorMapContent`, PBR slots and their `PluginSecurity` write.
- [`Texture.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Texture.yaml) — `inherits: [Decal]`.
- [`MeshPart.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MeshPart.yaml) — `TextureContent`, `MeshContent`, `TextureID`.
- [`SurfaceAppearance.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/SurfaceAppearance.yaml) — all five `*MapContent` slots, `AlphaMode`, OpenGL normal-map format.
- [`FileMesh.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/FileMesh.yaml) — the only "live-updates with any edits" statement.
- [`AdGui.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/AdGui.yaml) · [`Shirt.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Shirt.yaml) · [`Pants.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Pants.yaml) · [`ShirtGraphic.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ShirtGraphic.yaml) · [`ScrollingFrame.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ScrollingFrame.yaml) · [`ParticleEmitter.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ParticleEmitter.yaml) · [`Sky.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Sky.yaml) · [`ViewportFrame.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ViewportFrame.yaml) · [`ImageHandleAdornment.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/ImageHandleAdornment.yaml) · [`Beam.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Beam.yaml) · [`Trail.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Trail.yaml) — sink and non-sink determinations in §5.

**Datatypes** (`reference/engine/datatypes/<Name>.yaml`):

- [`Content.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Content.yaml) — the replication warning, `fromUri`/`fromAssetId`/`fromObject`, strong-reference semantics.

**Enums** (`reference/engine/enums/<Name>.yaml`):

- [`ImageCombineType.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ImageCombineType.yaml) · [`ImageAlphaType.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ImageAlphaType.yaml) · [`ResamplerMode.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ResamplerMode.yaml) · [`AntiAliasing.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/AntiAliasing.yaml) · [`ContentSourceType.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ContentSourceType.yaml) · [`CreateContentResult.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/CreateContentResult.yaml) · [`CreateAssetResult.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/CreateAssetResult.yaml) · [`AssetType.yaml`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/AssetType.yaml)

**Guides** (`<path>.md`):

- [`scripting/multithreading.md`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md) — the thread-safety level definitions used in §7.
- [`projects/assets/privacy.md`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/assets/privacy.md) — asset sharing, linked from the permissions text.
- [`projects/groups.md`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/groups.md) — group roles and permissions, linked from the permissions text.
- [`avatar/in-experience-creation.md`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/avatar/in-experience-creation.md) — the canonical worked example combining `EditableImage`, `EditableMesh`, `WrapDeformer` and `AvatarCreationService`.
- [`studio/optimization/memory-usage.md`](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/optimization/memory-usage.md) — general memory categories; **contains no editable-asset budget figures**.

**Negative result, recorded deliberately:** there is **no editable-assets guide tree and no
editable-assets memory-budget guide** in `creator-docs@main`. The following all return **404**:
`assets/editable/index.md`, `assets/editable/image.md`, `assets/editable/mesh.md`,
`assets/editable/memory-budgets.md`, `assets/editable-assets.md`,
`projects/assets/editable-assets.md`, `optimization/editable-assets.md`,
`optimization/memory-budgets.md`, `performance-optimization/editable-assets.md`,
`art/modeling/editable-assets.md`, `art/modeling/editable-mesh.md`,
`art/modeling/in-experience-mesh-editing.md`, `parts/editable-meshes.md`,
`resources/editable-assets.md`. Neither `EditableImage.yaml` nor `EditableMesh.yaml` links to such a
page. This was independently confirmed by a sibling agent that cloned the repository and searched
all 9,368 tracked paths case-insensitively for "editable": the only hits are `EditableImage.yaml`,
`EditableMesh.yaml` and five images. **The entire published memory-budget guidance is the
qualitative "Memory limits" paragraph inside those two class files.**

### Primary — live engine reflection

- [`MaximumADHD/Roblox-Client-Tracker@roblox/API-Dump.json`](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json) — full reflection dump. Used for: exact signatures, `ThreadSafety`, `Capabilities`, `Security`, `Superclass`, the engine-wide enumeration of all 80 `Content`-typed properties, and the discovery of undocumented `DrawTriangle`.
- [`.../version.txt`](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/version.txt) — **`0.739.0.7390687`**, the client version every DUMP claim in this document is pinned to.
- [`.../FVariables.txt`](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/FVariables.txt) — fast-flag *names* only (no values). Used strictly as corroboration for gating and feature-age claims: `EnablePermissionCheckOnCreatingEditableAsset`, `SimEnableEditablePermissionCheck`, `EditableSkipPolicyCheckForStudioEditMode`, `BlockEditableTypeReplication`, `BlockUseOfReplicatedEditableX`, `AllowEditableApisInCloudExecution2`, `EditableImageSubtractImageCombineType`, `EditableImageForceRGBA`, `SimRuntimeContentEnforceLocalBudget`.
- [`.../DeepStrings.txt`](https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/DeepStrings.txt) — client symbol strings. Source of `EditableImageDrawTriangleEnabled`, `CreateEditableImagePermissionFailure`, `CreateEditableImageSuccess`, `CreateEditableImageOriginalSizeAsync`, `EditableMemoryTelemetryEvent`. **Symbol names, not documentation.**

### Secondary — real production Luau using these APIs

- [`Ethanthegrand/FastCanvas` → `FastCanvas.luau`](https://raw.githubusercontent.com/Ethanthegrand/FastCanvas/main/FastCanvas.luau) — persistent `buffer` grid, `GetGridIndex(X, Y) = (X + (Y - 1) * Width) * 4 - 4`, a pre-filled `ClearingGrid` for fast clears, single `WritePixelsBuffer` per `Render()`, and a `nil`-check on `CreateEditableImage` with the message "Failed to create Canvas due to EditableImage memory limit being hit!".
- [`osgl-rbx/osgl` → `src/bitmap.luau`](https://raw.githubusercontent.com/osgl-rbx/osgl/main/src/bitmap.luau) — `buffer.readu8(self.buffer, (y * self.width + x) * self.channels + (channel - 1))`, the 0-based row-major form of the same index math.

Two independent implementations agreeing on the index formula is what promotes "row-major,
top-left origin" from *inferred* to *effectively verified*.

### `[COMMUNITY, SECOND-HAND]` — DevForum, via web-search summaries only

The DevForum is not reachable from this environment; the following were surfaced only as search
result titles and generated summaries and **were not read first-hand**. Every figure below is
unverified.

- Editable memory budget cited as **≈32 MB** client-side, with reports of exhaustion after ~**5–6**
  large images. Threads: "Failed to create empty EditableImage that was requested due to reaching
  memory budget limits error" (t/3490799), "Remove Editable Mesh/Image limit on the client"
  (t/4219561), "EditableImage higher resolution and memory limit" (t/4389575), "Editable mesh memory
  budget reached" (t/3469104).
- Old signature `EditableImage:WritePixels(position: Vector2, size: Vector2, pixels: {any})`.
- Beta history: "Introducing in-experience Mesh & Image APIs [Studio Beta]" (t/2725284, 2023),
  "[Studio Beta] Major updates to in-experience Mesh & Image APIs" (t/3225681),
  "[Client Beta] In-experience Mesh & Image APIs now available in published experiences" (t/3267293,
  Jan 2025) — the announcement that introduced published-experience availability and noted the team
  would "be tweaking the memory budget and re-evaluating permissions restrictions."

### Confirmed unreachable from this environment (do not retry)

`create.roblox.com`, `devforum.roblox.com`, `luau.org`, `robloxapi.github.io`, `blog.roblox.com`,
`en.help.roblox.com`, `roblox.fandom.com`, `data.jsdelivr.com`, `api.github.com` (for this repo),
and `github.com` via `curl` (403; `WebFetch` works). `raw.githubusercontent.com` is reachable and is
the basis of everything primary above.

### Index of `[UNVERIFIED]` claims in this document

| § | Claim left unverified |
|---|---|
| Verification gate | Whose verification status is checked for a group-owned experience. |
| 1.1 | Initial contents of a freshly created blank `EditableImage`. |
| 1.2 | Whether `Content.fromObject(otherEditableImage)` is accepted by `CreateEditableImageAsync`. |
| 1.2 | Whether a >1024² source is downscaled, cropped or rejected on load. |
| 1.4 | Behaviour of an `EditableImage` after `Destroy()` (draw/read/display). |
| 1.6 | Whether `Opaque` `Content` from `CreateDataModelContentAsync` actually replicates; size of the server storage budget. |
| 2.2 | Real per-image charge against the budget (mips, GPU copy) vs the logical `w·h·4`. |
| 2.3 | Any numeric memory budget — **none is published**. The ≈32 MB figure is community hearsay. |
| 3.2 | Premultiplied vs straight alpha; colour space (sRGB vs linear) of the buffer bytes. |
| 3.5 | Little-endian `writeu32` packing order (arithmetically sound, not documented). |
| 4.1 | `DrawTriangle` behaviour, winding order, fill rule; which clients have it enabled. |
| 4.5 | Exact equations for `BlendSourceOver`, `Add`, `AlphaBlend`, `Subtract` (prose only in DOCS). |
| 5.4 | Whether `ParticleEmitter`, `Sky`, `Beam`, `Trail`, `ImageHandleAdornment`, `CharacterMesh`, `BackpackItem` and the cursor-icon slots accept `EditableImage`. Expect **no** for `ParticleEmitter`. |
| 6.x | All performance figures — no timings are published; the tables are engineering judgement. |
| 6.5 | Mobile device tiers and their budgets. |
| 7.2 | Whether a `buffer` crosses an actor boundary by copy or by reference. |
| 8.4 | Any Open Cloud REST path for `EditableImage` pixel data (almost certainly none). |
| Churn 6 | What exactly the removed resize/crop API looked like. |
