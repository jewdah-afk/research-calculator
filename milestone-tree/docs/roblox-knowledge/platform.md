# Platform, pipeline, performance and the state of the art (Roblox, as of 2026-09-25)

Part of the Roblox knowledge library for **The Milestone Tree NG+**. This file covers the asset pipeline and tooling,
the engine services and their limits, performance and memory, what shipped or was announced in 2025-2026, and what
the best-looking Roblox games do. It ends with **Opportunities for Milestone Tree**. Audio has its own file
(`audio.md`).

**How to read the tags**

* API names in `code` were checked against `globalTypes.d.luau` (the luau-lsp 1.70 definitions the repo type-checks
  with) **and** against the Roblox client API dump v0.740.19 (MaximumADHD/Roblox-Client-Tracker `Mini-API-Dump.json`),
  which also gives security levels. A member that exists but scripts cannot call is marked **(internal)** or
  **(RobloxScriptSecurity)**. `globalTypes.d.luau` does **not** mark security, so "it type-checks" does not mean "a
  game script can call it".
* **[unverified]** means the claim comes from a secondary source (community post, press, wiki) or could not be
  confirmed against docs or the API dump.
* Dates are when Roblox posted the announcement or doc update. "Studio Beta" means you **cannot publish** with it
  yet. "Client Beta" means you can. "Full Release" means it is on for everyone.

---

## 0. The ten facts that matter most for this game

1. **GUI images are still capped at 1024×1024.** Uploads can be up to 8000×8000 and are stored at up to 8K (June
   2024). 4K *rendering* shipped on 30 Jan 2026, but only for `MeshPart`, `SurfaceAppearance`, `Texture`, `Decal` and
   `MaterialVariant`, through Texture Streaming (rolled out 23 Mar 2026). "2D UI textures, SurfaceGUI textures" are
   listed as *coming next*. So `ImageLabel` tiles ≤ 1024² and the repo's own HIGH/LOW tiers are still the right
   design. ([4K](https://devforum.roblox.com/t/4k-texture-rendering/4316229),
   [Texture Streaming](https://devforum.roblox.com/t/introducing-texture-streaming/4144855),
   [high-fidelity storage](https://devforum.roblox.com/t/retaining-high-fidelity-images/3042460))
2. **Texture memory is set by pixel count, not file size.** Images are transcoded to a fixed format, so PNG
   compression and dropping alpha save nothing in memory. A 1024² texture costs 4× a 512²
   ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)).
3. **Native UI polish shipped in 2025-26:** `UIShadow` and per-corner `UICorner` (full release 23 Jun 2026), UIStroke
   `BorderStrokePosition` / `StrokeSizingMode` / `BorderOffset` and several strokes per object (full release 4 Dec 2025),
   UI Styling (Jan 2026), `StyleQuery` (May 2026) and native **Styling Transitions** (27 Jul 2026). Radial and conical
   `UIGradient` plus `TileMode` / `Scale` are **Studio Beta only (2 Sep 2026) and cannot be published yet**.
4. **Roadmap for late 2026 to early 2027:** 2D particles, animated image containers with sprite-sheet import, an
   orthographic camera, UI backdrop blur and text shadows (RDC26, 10-12 Sep 2026;
   [Fall roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208)).
5. **Studio has a built-in MCP server (5 Mar 2026).** Claude Code can connect over stdio and call `execute_luau`,
   `start_stop_play`, `screen_capture`, `user_mouse_input` and more
   ([docs](https://create.roblox.com/docs/studio/mcp)).
6. **CI can run Luau inside the real engine, headless.** The Open Cloud **Luau Execution API** runs a task for up to
   5 min against a given place *version*. Roblox's own `place-ci-cd-demo` pairs it with Rojo and the Place Publishing
   API.
7. **Data store limits were rewritten (2025-26).** Each server gets 60 + 40×players reads and writes per minute, and
   the experience as a whole gets 300 + 40×CCU reads. A value can be 4,194,304 characters, a single key can take
   4 MB/min of writes, and total storage is 500 MB + 1 MB per lifetime user.
8. **Publishing gate for young audiences.** A game that never reaches "250 unique plays by highly engaged age-checked
   users within 60 days", with 2FA, ID or age verification, and Plus/Premium or a refundable fee, stays **16+ only**
   and is left out of search and home discovery
   ([Kids & Select](https://create.roblox.com/docs/production/publishing/kids-and-select)).
9. **Your own game can measure its device.** `Stats.FrameTime` (client only), `Stats.RenderCPUFrameTime` /
   `RenderGPUFrameTime`, `Stats.UI2DDrawcallCount`, `Stats:GetTotalMemoryUsageMb()` and
   `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)` are all callable by scripts. The Harmony
   memory-target methods are internal only.
10. **Most players are on weak phones.** Android is about 65% of a typical game's players, and about 60% of those
    phones have 2-4 GB RAM ([Test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware)).
    The community target is **< 1.3 GB client memory** so 2 GB phones can play
    ([Real World Optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146)).

---

## 1. Asset pipeline

### 1.1 Open Cloud Assets API (what `art/roblox/upload.js` uses)

Endpoints (`https://apis.roblox.com/assets/v1/…`, OpenAPI spec `creator-docs/content/en-us/reference/cloud/assets/v1.json`):

| Call | Path | Scopes |
|---|---|---|
| Create | `POST /assets/v1/assets` (multipart: `request` JSON + `fileContent`) | `asset:read`, `asset:write` |
| Get operation | `GET /assets/v1/operations/{operationId}` (poll for `response.assetId`, `moderationResult.moderationState`) | `asset:read` |
| Update | `PATCH /assets/v1/assets/{assetId}`: metadata for any type, **content only for Models** | read + write |
| Get / versions / rollback | `GET /assets/v1/assets/{id}`, `…/versions`, `…/versions:rollback` | |
| Archive / restore | `POST /assets/v1/assets/{id}:archive`, `:restore` | |

An API key needs **assets** under Access Permissions, and it must be created by a user who can manage the target
group's assets ([usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets)).

**Types and limits** (usage guide, current as of Sep 2026). Each call uploads **one asset of at most 20 MB**.

| Type | Formats | Limits |
|---|---|---|
| Decal / Image | `.png .jpeg .bmp .tga` (no WebP) | smaller than **8000×8000**; not updatable (a new version = a new id) |
| Audio | `.mp3 .ogg .wav .flac` | ≤ 7 min; **100 uploads/month if ID-verified, 10/month if not**; not updatable |
| Video | `.mp4 .mov` | ≤ 5 min, ≤ 4096×2160, ≤ 3.75 GB; **20/day, 13+ and ID-verified**; **2,000 Robux per upload**; no alpha ([video frames](https://create.roblox.com/docs/ui/video-frames)) |
| Model | `.fbx .gltf .glb .rbxm .rbxmx` | imported as a `Model` of `MeshPart`s and uploaded as a **Package**; FBX/glTF updatable (new version) |
| Mesh | Roblox mesh data only | only re-uploads of Asset-Delivery downloads ([Oct 2025](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082)) |
| Animation | `.rbxm .rbxmx` | files edited outside Studio may fail |

* **Rate limits:** no per-endpoint number is published for Assets. Open Cloud documents the `x-ratelimit-limit`,
  `x-ratelimit-remaining` and `x-ratelimit-reset` headers, and says to honour `retry-after` on 429 or else back off
  exponentially. API-key limits are pooled **per owner (user or group)** across all of that owner's keys
  ([rate limits](https://create.roblox.com/docs/cloud/reference/rate-limits)). The repo's default of 50/min with
  backoff is sensible. [unverified: the community figure of about 60 creates/min]
* **Moderation:** the finished operation carries `moderationResult.moderationState` (for example
  `MODERATION_STATE_APPROVED`). Community reports say decisions usually take minutes but can take hours or days in
  busy periods ([thread](https://devforum.roblox.com/t/how-long-does-it-take-for-a-decal-to-be-approvedrejected/331206))
  [unverified]. RDC26 announced **instant asset-moderation feedback in Studio** for late 2026.
* **ID verification** is needed for: audio above 10 uploads/month, any video, EditableImage/EditableMesh in published
  games, selling on the Creator Store, and rewarded video ads
  ([account verification](https://create.roblox.com/docs/production/publishing/account-verification)).
* **Versioning for image and mesh assets** (keep the id, change the pixels) is on the roadmap for late 2026. Until it
  ships, every art change means a new asset id, which is how `uploaded.json` and `Assets.luau` already work.

### 1.2 Resolution and memory: the rules for 2D art

* **Upload**: < 8000×8000 is accepted. Since 27 Jun 2024 Roblox *stores* up to 8K instead of downsampling to 1K.
* **Render in GUI**: 1024 max. The 4K announcement (30 Jan 2026) names only MeshPart, SurfaceAppearance, Texture,
  Decal and MaterialVariant. Texture Streaming covers those plus base materials, Beam and ParticleEmitter; "2D UI
  Textures, SurfaceGUI textures" are **coming next**. Streaming runs on PC, Mac, consoles and high-end phones
  (> 3.5 GB); low-end devices get it with 4K turned off. You cannot turn streaming off, and it has no API.
* **`EditableImage`** is at most 1024×1024 (512² by default). `AssetService:CreateEditableImage()` returns `nil` when
  the device's editable-memory budget is used up.
* **`CanvasGroup`** also renders through a texture of at most 1024², is re-rendered whenever a child changes, and
  costs VRAM; many of them break rendering on low-end devices
  ([feature request](https://devforum.roblox.com/t/using-many-canvasgroups-is-unworkable-until-proper-memory-management-methods-are-implemented/3502537)).
  `CanvasGroup.ResolutionScale` exists (API ✓).
* **Memory** depends on pixels only. [Inference: at the usual RGBA8, a 1024² tile is about 4 MB, or about 5.3 MB
  with mips; REALM.md already budgets this way.] Uploading the same PNG twice gives two ids and loads twice, so dedupe
  by hash (the repo does).
* **Transparent pixels turn black on upload**, so bleed colour into alpha-0 pixels. `tile.js` already does this.

### 1.3 Asset Privacy (images, decals and meshes only)

By default images, decals and meshes are **Open Use**: any game can load them by id. You can opt in to **Restricted
on creation** in the Creator Dashboard (separately for a user or a group). A Restricted asset loads only in games you
have granted. **Game grants are permanent, and Open Use can never be switched back to Restricted**
([privacy](https://create.roblox.com/docs/projects/assets/privacy)). The painted realm is the game's main visual
asset, so decide this *before* the real upload. The creator (`ROBLOX_CREATOR=user:` vs `group:`) must match how you
plan to grant access.

### 1.4 Packages, Creator Store, importer

* **Packages**: a reusable Model with auto-update; Open Cloud model uploads *become* packages. Package overrides
  (diff, revert) are on the roadmap for late 2026.
* **Creator Store**: models can be sold since Oct 2025 (government ID and a seller account needed). Improved previews
  shipped in spring 2026.
* **3D Importer**: FBX and glTF, one-click **re-import** (shipped spring 2026), **glTF export** (GA at RDC25), and the
  revamped **Asset Manager** with bulk permission grants.

### 1.5 AI creation tools (Cube and friends)

| Tool | Status | API |
|---|---|---|
| **Cube 3D** foundation model | open-sourced 17 Mar 2025 ([GitHub](https://github.com/Roblox/cube), [TechCrunch](https://techcrunch.com/2025/03/17/roblox-releases-its-open-source-model-that-can-create-3d-objects-using-ai/)) | `GenerationService:GenerateMeshAsync(inputs, player, options, cb)` (API ✓) |
| **4D / functional objects** | early access, then public beta Feb 2026 ([Roblox](https://about.roblox.com/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model), [DevForum](https://devforum.roblox.com/t/early-access-introducing-in-experience-4d-functional-objects-and-enhanced-3d-generation/4050893)); custom schema and behaviour library mid-2026 | `GenerationService:GenerateModelAsync(inputs, schema, options)` (API ✓) |
| Texture Generator, Material Generator | in Studio ([texture generator](https://create.roblox.com/docs/studio/texture-generator)) | Studio tools |
| Procedural Models, Scene Generation | Procedural Models shipped (spring 2026); Scene Generator coming late 2026 (RDC26) | Studio |
| Text-to-Speech, Speech-to-Text, Text Generation | TTS GA at RDC25; STT launched; `TextGenerator` | `TextGenerator:GenerateTextAsync` (API ✓), `AudioTextToSpeech` (API ✓) |

For a hand-painted 2D realm, Cube is mostly useful for concept props. The tile pipeline stays in Playwright.

### 1.6 Studio Assistant and the MCP server

* The **built-in Studio MCP server** (5 Mar 2026) is the recommended bridge, and it can do everything Assistant can.
  Turn it on under Assistant → "…" → *Manage MCP Servers* → *Enable Studio as MCP server*. Claude Code runs it as a
  stdio process: macOS `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`, Windows
  `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` ([docs](https://create.roblox.com/docs/studio/mcp),
  [announcement](https://devforum.roblox.com/t/assistant-updates-studio-built-in-mcp-server-and-playtest-automation/4474643)).
* **Tools** (docs, Sep 2026):
  * scripts: `script_read`, `multi_edit`, `script_search`, `script_grep`
  * data model: `search_game_tree`, `inspect_instance`, `subagent`
  * running: `execute_luau`, `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture`
  * input: `character_navigation`, `user_keyboard_input`, `user_mouse_input`
  * assets: `generate_mesh`, `generate_material`, `generate_procedural_model`, `wait_job_finished`,
    `search_asset`, `insert_asset`, `upload_image`, `store_image`
  * other: `http_get`, `skill`, `list_roblox_studios`, `set_active_studio`
* The older standalone server is `Roblox/studio-rust-mcp-server`
  ([May 2025](https://devforum.roblox.com/t/introducing-the-open-source-studio-mcp-server/3649365)).
* Assistant itself gained Planning Mode (Apr 2026), bring-your-own LLM keys, skills, a playtest agent and "agentic
  gameplay validation" ([Planning Mode](https://devforum.roblox.com/t/announcing-planning-mode-for-roblox-assistant/4580715),
  [external LLMs](https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631)).
* Caveat: MCP needs a desktop Studio running on the same machine, so it cannot run in the headless cloud container.
  MCP clients can read and change your open places.

### 1.7 Code tooling

| Tool | State (Sep 2026) |
|---|---|
| **Rojo** | 7.5.0 (Apr 2025): `.plugin.luau`, `syncRules`, Ref linking by `Rojo_Target` attributes. 7.6.0 (Oct 2025): **`rojo syncback`** (place → project), `syncbackRules`, YAML, `sourcemap --absolute`. 7.6.1 (Nov 2025): JSONC project files. **7.7.0 (1 Jul 2026)**: syncback fixes, `init.plugin.luau`, negation in `globIgnorePaths`, DNS-rebinding protection ([changelog](https://github.com/rojo-rbx/rojo/blob/master/CHANGELOG.md)) |
| **Studio Script Sync** | full release **17 Jun 2026**: native sync between Studio scripts and files, with conflict resolution ([DevForum](https://devforum.roblox.com/t/full-release-studio-script-sync/4688454)). It syncs scripts only and does not build a place from a tree, so **Rojo stays the build tool** here |
| **Wally / pesde** | Wally is still the common registry. **pesde** has its own registry, also reads Wally and Git sources, and supports Lune as well as Roblox ([pesde](https://github.com/pesde-pkg/pesde)). Toolchains are pinned with **Rokit** (or mise) |
| **luau-lsp** | 1.70.0 in this repo's scratch tools; `luau-lsp analyze --definitions --sourcemap` is what the repo runs |
| **Luau** | the **New Type Solver** reached general release in Nov 2025 ([DevForum](https://devforum.roblox.com/t/general-release-luau%E2%80%99s-new-type-solver/4084991)). Native codegen via `--!native` / `@native` |
| **Selene / StyLua** | linter and formatter, used by Roblox's own CI demo |

### 1.8 Testing and CI

* **Jest-Lua** (`jsdotlua/jest-lua`, Roblox's port of Jest) replaces **TestEZ** and has a migration guide. It runs in
  Studio, from the CLI via `run-in-roblox`, or through the Luau Execution API
  ([Jest-Lua](https://jsdotlua.github.io/jest-lua/),
  [TestEZ migration](https://jsdotlua.github.io/jest-lua/testez-migration)).
* **Open Cloud Luau Execution API** ([reference](https://create.roblox.com/docs/cloud/reference/features/luau-execution)):
  * Create a task with `POST /cloud/v2/universes/{u}/places/{p}/luau-execution-session-tasks`, or `…/versions/{v}/…`
    to pin a place version. Poll `GET …/luau-execution-sessions/{s}/tasks/{t}` and fetch `…/logs`.
  * Scope: `universe.place.luau-execution-session:write`.
  * Limits: **5 min per task** (was 30 s), and changes to the place are not kept. It runs at game-script security, and
    physics does not step.
  * Concurrency: the Beta thread says 10 concurrent tasks per place, while Roblox's demo README says "limited to two
    concurrent requests per universe". [conflicting sources, so plan for 2]
  * The block on DataStores and HttpService was later lifted
    ([Beta thread](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185)).
* **Place Publishing API**: `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Saved|Published`
  with the `.rbxl` / `.rbxlx` as the body. It needs `universe-places` permission (scope `universe.places:write`). It
  does **not** update EditableImage, EditableMesh, PartOperation, SurfaceAppearance or BaseWrap instances
  ([guide](https://create.roblox.com/docs/cloud/guides/usage-place-publishing)).
* **Roblox/place-ci-cd-demo** puts these together with GitHub Actions: Rojo build → Selene and StyLua → publish to a
  test place → run tests with Luau Execution → publish to production on the `production` branch
  ([repo](https://github.com/Roblox/place-ci-cd-demo)).
* Other useful Open Cloud endpoints (cloud v2 spec):
  * `POST /cloud/v2/universes/{u}:restartServers` for a soft shutdown after a publish
  * `…/user-restrictions` for bans
  * the Secrets store (`universe.secret`), read in game through `HttpService` secrets
  * messaging publish, so outside tools can reach `MessagingService` topics
  * `…/users/{id}/notifications` for experience notifications

---

## 2. Engine services and their limits

### 2.1 Streaming, SLIM, parallel Luau, native code

* **Instance streaming**
  * `Workspace.StreamingEnabled` is plugin-writable.
  * Planned for late 2026: an adaptive radius, path pre-fetch, and a minimum draw distance of 500 studs on low-end
    Android.
  * This game is a ScreenGui with `CharacterAutoLoads = false`, so streaming hardly matters unless the realm moves
    into 3D (Opportunity 7).
* **SLIM** (Scalable Lightweight Interactive Models) v1 shipped in spring 2026 and replaces the LOD system
  ([SLIM](https://create.roblox.com/docs/workspace/streaming/slim)).
* **Parallel Luau** ([multithreading](https://create.roblox.com/docs/scripting/multithreading)):
  * Use `Actor` with `task.desynchronize()` / `task.synchronize()` or `RBXScriptSignal:ConnectParallel()` (the
    worker already uses `Heartbeat:ConnectParallel`). `SharedTable` / `SharedTableRegistry` share data between actors.
  * Scripts under the same Actor run serially. You cannot `require()` or write instances in a parallel phase.
* **Native code generation** ([docs](https://create.roblox.com/docs/luau/native-code-gen)):
  * Turn it on with `--!native` at the top of a script, or `@native` on one function.
  * The docs describe it for **server** scripts. It helps numeric code, especially on tables and `buffer`s.
  * Costs: compile time, extra memory, and "a limit on the total allowed amount of natively compiled code".
  * On clients: "Native code generation for Android" slipped to mid-2026 on the Spring roadmap; client support is
    partial and device-dependent. [unverified]

### 2.2 DataStoreService ([limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits))

| Limit | Value |
|---|---|
| Server default, standard Read (`GetAsync`, `UpdateAsync` read) | **60 + numPlayers × 40 /min** |
| Server default, standard Write (`SetAsync`, `IncrementAsync`, `UpdateAsync` write) | **60 + numPlayers × 40 /min** |
| Server List / RemoveVersion | 5 + numPlayers × 2 /min |
| Server Ordered write / remove | 30 + numPlayers × 5 /min |
| Experience-wide, shared with Open Cloud | Read 300 + CCU×40, Write 300 + CCU×20, List 300 + CCU×2, Remove 300 + CCU×40 /min |
| Per-key throughput | read 25 MB/min, **write 4 MB/min**, rounded up to whole KB per request |
| Value size | **4,194,304 characters per key** (measure with `HttpService:JSONEncode`) |
| Names | data store, key and scope ≤ 50 characters; metadata ≤ 300 characters in total |
| Queue | 30 requests per queue, after which errors 301-306 |
| Storage | **500 MB + 1 MB × lifetime users**, measured compressed on the latest version (don't pre-compress) |

* Tune per server with `DataStoreService:SetRateLimitForRequestType(requestType, baseLimit, perPlayerLimit)` and
  read the remaining budget with `GetRequestBudgetForRequestType` (both API ✓).
* Studio Run mode has separate, lower static limits.
* **ProfileStore** (loleris, Oct 2024) succeeds ProfileService: 300 s autosave, session-lock steals over
  MessagingService ([DevForum](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543)).
  The repo's `Store.luau` implements its own session lock with `UpdateAsync`.

### 2.3 MemoryStoreService ([docs](https://create.roblox.com/docs/cloud-services/memory-stores))

* **Memory quota:** 64 KB + 1.2 KB × users for the whole experience. After players leave, the quota takes 8 days to
  shrink.
* **Requests:** 1000 + 120 × CCU request units per minute, experience-wide. A range read costs one unit per item
  returned.
* **Per structure:** a sorted map or queue holds up to 1,000,000 items and 100 MB.
* **Per partition:** throttling starts around 30,000 units/min. A hash-map key allows about 5,000 writes and 15,000
  reads per minute. The default expiry is 45 days.
* Structures: `GetSortedMap`, `GetQueue`, `GetHashMap` and the new **`GetDistributedCounter`** (API ✓). Good for live
  global counters such as "players who reached Multiverse today".

### 2.4 MessagingService ([reference](https://create.roblox.com/docs/reference/engine/classes/MessagingService))

| Limit | Value |
|---|---|
| Message size | 1 kB |
| Sent per server | 600 + 240 × players /min |
| Received per topic | 40 + 80 × servers /min |
| Received per game | 400 + 200 × servers /min |
| Subscriptions per server | 20 + 8 × players |
| Subscribe requests | 240 /min |

Topics are 1-80 characters.

### 2.5 TeleportService, BadgeService

* **Teleport**: `TeleportService:TeleportAsync(placeId, players, TeleportOptions)` and `ReserveServerAsync` (the
  old `ReserveServer` is deprecated). Studio "test teleports" come in early 2027.
* **Badges**: `BadgeService:AwardBadgeAsync` (the old `AwardBadge` is deprecated), `UserHasBadgeAsync`,
  `CheckUserBadgesAsync`, `GetBadgeInfoAsync`. **5 badges per game per 24 h are free, then 100 Robux each**
  ([badges](https://create.roblox.com/docs/production/publishing/badges)).
* Trend: many yielding APIs were renamed to `…Async` with the old name deprecated, for example `GetProductInfo` →
  `GetProductInfoAsync` and `GetTranslatorForPlayer` → `GetTranslatorForPlayerAsync`.

### 2.6 MarketplaceService and monetisation

* **Passes**: priced 1 to 1,000,000,000 Robux. Check ownership with `UserOwnsGamePassAsync`, handle
  `PromptGamePassPurchaseFinished`, and read prices with `GetProductInfoAsync(id, Enum.InfoType.GamePass)` from the
  client so players see personalised prices. **Free trials for passes** ("try for one full session") are coming in
  late 2026.
* **Developer products**: grant them **only** in `MarketplaceService.ProcessReceipt`, never from
  `PromptProductPurchaseFinished`. Test mode exists for purchases made outside the game
  ([dev products](https://create.roblox.com/docs/production/monetization/developer-products)).
* **Subscriptions** ([docs](https://create.roblox.com/docs/production/monetization/subscriptions)):
  * In Robux: any creator, ≥ 49 Robux, 70% payout, regional pricing forced on.
  * In local currency: needs ID or phone verification; $2.99-$14.99.
  * APIs: `PromptSubscriptionPurchase`, `GetUserSubscriptionStatusAsync`.
* **Regional pricing**: discounts are at most 70%, never above the default price. `GetUsersPriceLevelsAsync` returns
  1-1000, and there is a dynamic price-check tool that finds hard-coded prices in your UI
  ([regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing)).
* **Rewarded video ads**: `AdService:ShowRewardedVideoAdAsync(player, reward, placementId)` and
  `GetAdAvailabilityNowAsync`. The reward must be a developer product. Eligibility: 13+, ID-verified, public game,
  ≥ 2,000 unique visitors a month; Roblox suggests rewards worth 3-10 Robux
  ([docs](https://create.roblox.com/docs/production/promotion/rewarded-video-ads)).
* **Pre-roll ads** (skippable, shown while the game loads) were announced at RDC26 as "coming soon".

### 2.7 AnalyticsService ([event types](https://create.roblox.com/docs/production/analytics/event-types))

Methods (API ✓), all server-side:

* `LogCustomEvent(player, name, value?, customFields?)`
* `LogFunnelStepEvent(player, funnel, sessionId?, step?, stepName?, fields?)`
* `LogOnboardingFunnelStepEvent(player, step, stepName?, fields?)`
* `LogProgressionEvent`, `LogProgressionStartEvent`, `LogProgressionCompleteEvent`, `LogProgressionFailEvent`
* `LogEconomyEvent(player, flowType, currency, amount, endingBalance, transactionType, sku?, fields?)`
* `LogJourneyEvent` (new: branching journeys, with Sankey views coming late 2026)
* `GetPlayerSegmentsAsync`

| Limit | Value |
|---|---|
| Global rate | **120 + 20 × CCU requests/min** |
| Custom fields | 3 (`Enum.AnalyticsCustomFieldKeys.CustomField01..03`); 8,000 combined values, then the rest are grouped as "Other" |
| Custom event names | 100 |
| Funnels / steps | 10 funnels / 100 steps each; the 10 most recent `funnelSessionId` per user are tracked |
| Economy | 10 currencies; 20 transaction types and 100 SKUs before "Other" |
| Latency | events aggregate daily, so charts can take up to 24 h. The Performance dashboard needs ≥ 100 DAU |

`value`, `amount` and `endingBalance` are ordinary Luau numbers (doubles). **An incremental game must log exponents
(log10) or tiers, not raw TowerNum values.**

### 2.8 Configs and experiments

* `ConfigService:GetConfigAsync()` / `GetConfigForPlayerAsync(player)` return a snapshot; call `:GetValue(key)` on
  it. This is **server only**. Publishing a config reaches servers in about 15 s to 1 min
  ([configs](https://create.roblox.com/docs/production/configs)).
* **Experiments** run for 14-60 days, split by percentage, target player attributes and cannot be edited once
  scheduled ([experiments](https://create.roblox.com/docs/production/experiments)).

### 2.9 Experience settings, maturity, audiences

* Dashboard → **Audience → Access Settings** (minimum age, regions) and **Communication Settings** (e.g. strong
  language). Security toggles include *Enable Studio Access to API Services*, which the README requires for saves in
  Studio ([configure games](https://create.roblox.com/docs/projects/configure-games)).
* **Maturity & Compliance Questionnaire** (Configure → Questionnaire) gives the label: **Minimal/Mild** games can
  reach Roblox Kids (5-8) and Select (9-15), **Moderate** reaches Select and 16+, **Restricted** is 18+ with age
  verification. Without a completed questionnaire, Roblox limits who can play the game
  ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).
* **Kids & Select requirements**: creator verification (ID if 18+, facial age estimation if younger), 2FA, 2 months
  of Plus/Premium *or* a refundable fee, the questionnaire, and **250 unique plays by highly engaged age-checked users
  within 60 days** (lowered from 500, Aug 2026). Until a game meets them it is 16+ and Trusted Friends only, and is
  not in search or home ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select),
  [DevForum](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)).

### 2.10 Localization ([automatic translation](https://create.roblox.com/docs/production/localization/automatic-translations))

* **Automatic Text Capture** collects strings from GUI objects with `AutoLocalize = true`; new strings can take days
  to appear. Roblox then fills in machine translations for blank entries and never overwrites manual ones.
* Script translation: `LocalizationService:GetTranslatorForPlayerAsync(player)` (the old non-Async name is
  deprecated).
* Real-time chat translation covers 17 languages. **Automatic translation of in-game images, icons and thumbnails**
  is on the roadmap (mid/late 2026).

### 2.11 Social and retention APIs (all API ✓)

* `ExperienceNotificationService:CanPromptOptInAsync()` / `PromptOptIn()`, then send the notifications from Open Cloud.
* `SocialService:PromptGameInvite`, `PromptLinkSharingAsync` (share links), `PromptRsvpToEventAsync`.
* `CaptureService:CaptureScreenshot`, `TakeScreenshotCaptureAsync`, `PromptShareCapture`, `StartVideoCaptureAsync`
  (screenshots and clips players can share; Moments is the discovery feed for them).
* `HapticEffect` with `Type` = `UIClick`, `UIHover`, `UINotification`, … works on most iPhones, Pixels and Galaxies
  and on PS/Xbox pads ([HapticEffect](https://create.roblox.com/docs/reference/engine/classes/HapticEffect)).
* Push notifications for turn-based and async play enter Studio Beta in Oct 2026 (RDC26).

---

## 3. Performance and memory

### 3.1 Budgets

* **Frame**: 16.67 ms at 60 FPS. Break long work into chunks or move it to Actors
  ([design](https://create.roblox.com/docs/performance-optimization/design)). PC players can raise the cap with the
  Maximum Framerate setting (May 2024,
  [DevForum](https://devforum.roblox.com/t/introducing-the-maximum-framerate-setting/2995965)), so 120+ Hz leaves
  8 ms or less.
* **Memory**: Roblox never gets all of a device's RAM. The community rule of thumb is **< 1.3 GB total client memory
  to support 2 GB phones**, about 500 scene draw calls and 500k triangles for 60 FPS on most phones, and **concern
  above roughly 150 UI draw calls** ([article](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146))
  [community numbers]. The official docs give an example of 1,000 draw calls and 1M triangles for a baseline device.
* **Devices**: Android is about 65% of a typical game's players; of those, 60% have 2-4 GB RAM, 35% have 4-8 GB and
  5% have more than 8 GB. Over half of all players are on Passmark 10k-20k devices. Suggested test phones: Infinix
  Smart 9, Moto G05, Oppo A18, Fire HD 10 (2023) and Galaxy S22 Ultra
  ([test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware)).
* **Thermal throttling**: run 10-15 min sessions on a phone and watch the FPS slide.
* **Studio is not the device**: the emulator is wrong about memory, and Studio runs client and server together.

### 3.2 Tools

| Tool | How |
|---|---|
| MicroProfiler | Ctrl+Alt+F6 / ⌘⌥F6; works on devices; save a dump and read it on desktop ([docs](https://create.roblox.com/docs/performance-optimization/microprofiler)). Label your own code with `debug.profilebegin` / `debug.profileend` |
| Developer Console (F9) | Memory: CoreMemory, **PlaceMemory**, PlaceScriptMemory, UntrackedMemory. **LuauHeap** snapshots: Graph, Object Tags, Memory Categories, Object Classes, Unique References and Unparented Instances ([memory usage](https://create.roblox.com/docs/studio/optimization/memory-usage)) |
| Script Profiler | per-function CPU time, including on live servers |
| Debug stats | Render and Summary (Shift+F-keys) show Draw(scene), CPU/GPU ms and FPS; "Performance Stats" in the in-game settings adds an overlay |
| Performance dashboard | P10/P90 client FPS, crash rate, **unexpected out-of-memory exits**, memory % of the device by device type, filtered by place version; needs ≥ 100 DAU ([docs](https://create.roblox.com/docs/production/analytics/performance)) |
| `debug.setmemorycategory("Map")` | names the Luau heap of a module in the Memory Categories view |

**PlaceMemory categories** (which match `Enum.DeveloperMemoryTag`, API ✓): HttpCache, Instances, Signals, **LuaHeap**,
Script, PhysicsCollision, PhysicsParts, GraphicsSolidModels, GraphicsMeshParts, GraphicsParticles, GraphicsParts,
GraphicsSpatialHash, GraphicsTerrain, **GraphicsTexture**, GraphicsTextureCharacter, **Sounds**, StreamingSounds,
TerrainVoxels, TerrainPhysics, **Gui**, Animation, Navigation. The enum also has GraphicsSlimModels. For this game,
watch GraphicsTexture (realm tiles and atlas), Gui (instance count), LuaHeap (view store, patch tables) and Sounds.

### 3.3 Runtime telemetry a game script can read (API ✓, security None)

* `Stats.FrameTime` is client only; 1/FrameTime is your FPS. Also `Stats.RenderCPUFrameTime`,
  `Stats.RenderGPUFrameTime` and `Stats.HeartbeatTime`.
* `Stats.UI2DDrawcallCount`, `UI2DTriangleCount`, `SceneDrawcallCount`, `InstanceCount`.
* `Stats:GetTotalMemoryUsageMb()` reads the OS figure. `Stats:GetMemoryUsageMbForTag(tag)` returns 0 unless
  `Stats.MemoryTrackingEnabled` is true.
* **Not callable**: `Stats:SetHarmonyMemoryTarget`, `ResetHarmonyMemoryTarget` and `GetHarmonyQualityLevel` (they
  need the internal `InternalTest` capability); `GuiService:GetScreenResolution()`, `GetResolutionScale()` and
  `DisplayScalingMode` (RobloxScriptSecurity); `UserGameSettings.GraphicsQualityLevel` (RobloxScriptSecurity). **No
  API reports device RAM or the automatic quality level.**

### 3.4 Detecting the device tier (what the repo's `MapView.chooseTier` can use)

| Signal | API | Notes |
|---|---|---|
| Saved graphics level | `UserSettings():GetService("UserGameSettings").SavedQualityLevel` | Usually `Automatic`, in which case the real level is hidden, so this only catches players who set it low by hand |
| Screen class | `GuiService.ViewportDisplaySize` (`Small`, `Medium`, `Large`) | Small = phone |
| Input | **`UserInputService.PreferredInput`** (`Touch`, `KeyboardAndMouse`, `Gamepad`, `MicroGamepad`) | New; better than `TouchEnabled and not KeyboardEnabled`; changes during play |
| Viewport | `workspace.CurrentCamera.ViewportSize`, `GuiService:GetGuiInset()`, `TopbarInset`, `ScreenGui.ScreenInsets` / `SafeAreaCompatibility` | Safe areas |
| TV | `GuiService:IsTenFootInterface()` | Console |
| Live pressure | `Stats.FrameTime`, `Stats:GetTotalMemoryUsageMb()` | The only direct evidence; use for **adaptive downgrade** |
| Accessibility | `GuiService.ReducedMotionEnabled`, `PreferredTransparency`, `PreferredTextSize` | The repo already honours all three |

### 3.5 GUI-specific costs

* **Pixels** decide texture memory. Keep minor images ≤ 256², and use 512² only for large on-screen art.
* **Partial transparency overdraw**: stacked translucent full-screen layers (clouds, mist, fg, vignette) cost GPU
  fill-rate, which is the typical bottleneck on low-end phones.
* **UIShadow**: "consistently faster than 9-sliced ImageLabels"; keep **≤ 100 on screen**. It does not follow a
  CanvasGroup's GroupTransparency ([bug](https://devforum.roblox.com/t/canvasgroup-grouptransparency-does-not-affect-new-uishadow-transparency/4719520)).
* **UIGradient** (new types): keep ≤ 1,000 at once. Animating `Scale`, `TileMode` or `Type` is cheaper than
  animating `Color` or `Transparency`, and two-colour gradients are fastest.
* **CanvasGroup**: 1024² cap, re-renders when any child changes, costs VRAM. Use it only for short fades.
* **Post-processing** (Bloom, ColorCorrection, DepthOfField, SunRays, the new `ColorGradingEffect`) affects the 3D
  world, not ScreenGui content [by engine design; confirm per effect].

### 3.6 Luau allocation and GC patterns ([luau.org/performance](https://luau.org/performance))

* The GC is incremental and paced, so leaks, not pauses, are the main risk.
* **Leaks**: connections are never collected while connected, and tables keyed by player grow forever. Check
  LuauHeap for "Unique References" and InstanceCount growth.
* **Per-frame**: no new tables or closures per frame. Reuse scratch tables (`table.clear`) and pre-size arrays with
  `table.create`.
* **Strings**: `string.format` on big-number labels every frame is the classic UI allocation hotspot. Format at 5 Hz
  and diff.
* **Fastcalls**: call `math.*` directly or cache it in a local. `buffer` and `vector` avoid table allocation.
  `--!native` helps numeric server code most.
* **Events**: prefer event-driven code to `RenderStepped` polling, and tween on the client, never the server.

---

## 4. What's new in 2025-2026 (things that make a game look ahead of the pack)

### 4.1 Timeline

| When | Feature | Status | Why it matters here |
|---|---|---|---|
| Jun 2024 | **Path2D** (`GetPositionOnCurveArcLength`, `SetControlPoints`) | Full ([post](https://devforum.roblox.com/t/path2d-full-release/3027288)) | Native anti-aliased curves: links between nodes, rune paths, drawn progress |
| Jul 2024 | `TextLabel.OpenTypeFeatures` | Live ([post](https://devforum.roblox.com/t/introducing-opentypefeatures/3065736)) | Tabular numbers (`tnum`) keep counters from jittering. **Custom font upload is still not supported** [unverified, community] |
| Nov 2024 / Jan 2025 | **EditableImage / EditableMesh** in published games | Client Beta; needs 13+ **ID verification** and the Dashboard toggle "Enable Mesh / Image APIs"; shared assets allowed from Apr 2026 ([post](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293)) | Procedural FX up to 1024²; `WritePixelsBuffer`, `DrawImageTransformed`, `DrawCircle`, … |
| Jan-Jul 2025 | **Unified Lighting**: `Lighting.LightingStyle` (`Realistic`/`Soft`) and `PrioritizeLightingQuality` replace `Technology` (now RobloxScriptSecurity) | Full ([post](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)) | Only matters if 3D is used |
| Feb 2024 → | **Audio API**: `AudioPlayer`, `Wire`, effects, `AudioAnalyzer:GetSpectrum()`, `AudioPlayer:Play(atTime)` | Beta, then broadly live; see `audio.md` | Music-reactive visuals, precisely timed stingers |
| Mar 2025 | Cube 3D, `GenerationService` | Open source / beta | See 1.5 |
| 2025 → 2026 | **Input Action System** (`InputAction`, `InputBinding`, `InputContext`) | Client Beta in 2025 ([post](https://devforum.roblox.com/t/client-beta-input-action-system-is-now-available-to-publish-in-experiences/3890979)), Full Release in 2026 ([post](https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416)) [exact dates unverified] | Hotkeys and gamepad rebinding done natively |
| Oct 2025 → Feb 2026 | **Emissive masks** (`SurfaceAppearance.EmissiveMaskContent`, `EmissiveStrength`, `EmissiveTint`) | Live 12 Feb 2026 ([post](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705)) | Glowing 3D surfaces |
| Dec 2025 | **UIStroke upgrades** (`BorderStrokePosition` Inner/Center/Outer, `BorderOffset`, `StrokeSizingMode`, `LineJoinMode`, several strokes) | Full ([post](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036)) | Layered neon rims without images |
| Jan 2026 | **UI Styling** (`StyleSheet`, `StyleRule`, `StyleLink`, `StyleDerive`) | Full ([post](https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082)) | CSS-like theming |
| Jan-Mar 2026 | **4K textures + Texture Streaming** (3D only) | Full | Not for ImageLabel yet |
| Mar 2026 | Studio built-in **MCP server** and playtest automation | Full | See 1.6 |
| May 2026 | **`StyleQuery`** (MinSize/MaxSize/AspectRatioRange, ViewportDisplaySize, PreferredInput, ReducedMotion, PreferredTextSize) | Full ([post](https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519)) | Responsive phone/desktop styles without code |
| Jun 2026 | **`UIShadow`** (BlurRadius up to 1000, Spread, Offset, Color, `Mode` Shape/Text, `ShowBehindParent`, negative ZIndex) and **per-corner radii** (`TopLeftRadius`, …) | Full, 23 Jun ([post](https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263)) | Real glows and drop shadows at last |
| Jun 2026 | Studio **Script Sync** | Full | See 1.7 |
| Jul 2026 | **Styling Transitions**: `StyleRule:SetPropertyTransitions({ ["*"] = TweenInfo… })` | Full, 27 Jul ([post](https://devforum.roblox.com/t/full-release-styling-transitions/4646870)) | Native (engine-side) hover and press animation |
| Sep 2026 | **Upgraded UIGradient**: `Type` Radial/Conical, `TileMode` Clamp/Repeat/Mirror, `Scale`; works on Path2D | **Studio Beta, cannot publish** (2 Sep; [post](https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594)) | Radial glows, conic progress rings and repeating stripes, once released |
| Late 2026 | **2D particles**, **animated image containers**, **sprite-sheet import**, **orthographic camera** | Roadmap (RDC26) | Native versions of the atlas sprites and particle fields |
| Early 2027 | **UI backdrop blur** (strength and colour) and **text shadows** | Roadmap | Frosted-glass panels without hacks |
| Late 2026 | Play in the browser (Chrome), standalone apps; offline play mid-2027 | Announced RDC26 | Links from the web game's community can open the Roblox port directly |

### 4.2 RDC highlights

* **RDC24** (6-7 Sep 2024) ([Roblox](https://about.roblox.com/newsroom/2024/09/rdc-2024-robloxs-next-frontier)):
  the Cube incubation, Party, Shopify commerce, a better paid-access revenue share, Price Optimization, and data
  store upgrades (session locking, a data store explorer).
* **RDC25** (5-6 Sep 2025) ([what we announced](https://devforum.roblox.com/t/rdc25-what-we-announced/3920245)):
  * 4D generation, TTS/STT and text generation, real-time translation, MCP coming to Assistant
  * 4K textures, emissive maps, SLIM
  * Server Authority early access, Configs and Experiments, Experience Betas
  * DevEx up 8.5% to $0.0038/Robux, rewarded video GA
  * Mobile stability: iOS playtime-per-crash up 66%, Android up 26%
* **RDC26** (10-12 Sep 2026) ([what we announced](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880),
  [Roblox](https://about.roblox.com/newsroom/2026/09/rdc-2026-the-world-needs-more-play)):
  * 2D game capabilities (ortho camera, animated images, sprite sheets), UI blur, text shadows, better gradients
  * Scene generation, instant asset moderation, branch and merge for places (early 2027)
  * Web player, standalone apps, offline play
  * Pre-roll ads, Roblox Wallet, push notifications for turn-based play, a 500-stud minimum draw distance on low-end
    Android
  * Early testing with up to 10 friends before publishing, an observability platform (session tracing)

---

## 5. The state of the art

### 5.1 Games people point to for visuals

| Game (studio) | What makes it special | Write-up |
|---|---|---|
| **FRONTLINES** (MAXIMILLIAN) | Near-AAA shooter: reflective materials, bespoke assets, six months on weapon audio, "the tiny details add up" | [Roblox newsroom, Jul 2026](https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos) |
| **Fluorlite showcases** (Relived, Jungle Hollow, Stormy Heights) | Photoreal set dressing: **4K textures**, **emissive maps** for fire and lava, terrain MaterialVariants, procedural props, Blender → Studio | same |
| **Creatures of Sonaria** (Twin Atlas) | Streaming across biomes, SurfaceAppearance plus emission maps on modular creatures | same |
| **Ecos: La Brea** | Photoreal fauna using PBR and CT-scan anatomy | same |
| **Hellreaver Arena** (Noahh, Canyon) | Called "the most realistic-looking game on Roblox" (Doom-like) | [Pocket Gamer](https://www.pocketgamer.com/roblox/best-looking-games/) |
| **Mist** (NoirSplash) | Painterly Kung Fu Panda / Pandaria-style showcase | same |
| **Beyond the Dark** (Roblox) | Official showcase: cyberpunk lighting, trim sheets | [creator docs](https://create.roblox.com/docs/resources/beyond-the-dark) |
| **The Mystery of Duvall Drive** (Roblox) | Official showcase: custom materials, Future lighting on mobile, **Beams as volumetric light**, streaming | [docs](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive), [DevForum](https://devforum.roblox.com/t/the-mystery-of-duvall-drive-a-vistech-showcase/1976263), [optimising it](https://devforum.roblox.com/t/optimizing-roblox-without-streamingenabled-the-mystery-of-duvall-drive/2060659) |
| **Guts & Blackpowder**, **Deepwoken** | Smoke and lighting; mood over photorealism | Pocket Gamer |
| **Doors** (LSPLASH) | Lighting-driven horror with polished UI; Best Horror 2024 | [2024 winners](https://devforum.roblox.com/t/roblox-innovation-awards-2024-winners/3152047) |
| **Sol's RNG** | **The reference for spectacle in an idle/RNG game**: rarity-tiered full-screen "aura" cutscenes (EPIC and up), 4- and 8-pointed star bursts with bass hits, custom cutscenes for globals | [wiki](https://sol-rng.fandom.com/wiki/Opening_Cutscenes) |
| **Pet Simulator 99** (BIG Games) | The UI benchmark for simulators: icon art, enchant frames, chunky readable buttons | [ArtStation (UI artist)](https://www.artstation.com/artwork/AZNZJX) |
| **Dress To Impress** | Best Creative Direction + Builderman Award 2024 | 2024 winners |
| **Steal a Brainrot** / **Dead Rails** | 2025 Best Creative Direction / Best Use of Tech (procedural terrain, moving bases) | [2025 winners](https://beebom.com/roblox-innovation-awards-2025-winners/) |
| **Wish Master** (Laksh) | Players "wish" objects into being with Cube 4D in-game | [Roblox, Feb 2026](https://about.roblox.com/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model) |

The Innovation Awards have no "best visuals" category. The nearest are **Best Creative Direction** (2024 Dress To
Impress, 2025 Steal a Brainrot) and **Best Use of Tech** (2024 Clip It, 2025 Dead Rails).

### 5.2 Community resources worth knowing

**UI frameworks**

* **React-Lua** (`jsdotlua/react-lua`, the React 17 port Roblox uses; re-render and diff)
* **Fusion** (`dphfox/Fusion`, v0.3; fine-grained reactive, scoped lifetimes)
* **Vide** (`centau/vide`, Solid-like, with a built-in `spring()`)
* Roact is legacy. The repo uses its own patch-driven renderer, which suits server-diffed views.

**State:** Charm and Reflex (littensy).

**Motion**

* **spr** (Fraktality): analytic springs, tiny ([GitHub](https://github.com/Fraktality/spr))
* **ripple** (littensy)
* **Otter** / ReactOtter (Roblox, [GitHub](https://github.com/Roblox/otter))
* **Flipper** (Reselim; last release 2021)
* Native: `TweenService`, `TweenService:SmoothDamp(...)` (API ✓; new) and Styling Transitions

**Debug UI:** **Iris** (Dear ImGui-style, SirMallard,
[DevForum](https://devforum.roblox.com/t/iris-immediate-mode-ui-library-based-on-dear-imgui/2302802)). Ideal for a
tuning and perf overlay.

**Data:** **ProfileStore** (loleris).

**Networking:** Blink, Zap, ByteNet (buffer-packed remotes) [unverified list]. The repo also has
`UnreliableRemoteEvent` available.

**2D UI effects**

* UI particle modules: [UIParticle](https://devforum.roblox.com/t/uiparticle-a-ui-particle-emitter/1831434),
  [EmitYourParticle](https://devforum.roblox.com/t/emityourparticle-a-faster-and-better-2d-particle-emitter-v101/2842247),
  [Emitter2D](https://devforum.roblox.com/t/emitter2d-convert-any-particleemitter-to-2d-with-the-click-of-a-button/3742009).
  Native 2D particles are due late 2026.
* EditableImage shaders: [RbxShader](https://devforum.roblox.com/t/rbxshader-a-robust-shader-engine-for-everyone/2965460)
  (Shadertoy-style per-pixel),
  [Lightspeed](https://devforum.roblox.com/t/lightspeed-shader-system-using-editableimage/2762254),
  [blur module](https://devforum.roblox.com/t/editableimage-image-blur-module/2828242).
* Frosted glass:
  * the classic DepthOfField plus glass-part trick, and boatbomber's
    [GlassmorphicUI](https://github.com/boatbomber/GlassmorphicUI)
  * "[Liquid Glass](https://devforum.roblox.com/t/%F0%9F%9B%A0%EF%B8%8Fliquid-glass-ui-blur-is-a-thing-of-the-past%F0%9F%9B%A0%EF%B8%8F/4416219)"
    and [DoF-blurred UIs](https://devforum.roblox.com/t/blurred-uis-using-depth-of-field-effect/4734313)
  * native UI blur is due early 2027
* Fake volumetrics: [Beams with proximity transparency](https://devforum.roblox.com/t/fake-volumetric-lighting-w-beams-proximity-transparency/2845337),
  the [Luma Light plugin](https://devforum.roblox.com/t/luma-light-volumetric-lights-plugin/3126832),
  [UI light beams](https://devforum.roblox.com/t/volumetric-light-beams-using-ui/1833616).

**Plugins:** Moon Animator 2 (Best Plugin 2025), and the Audiophile mixing console for the Audio API.

---

## Opportunities for Milestone Tree

Cost: S ≈ ≤ 1 day, M ≈ a few days, L ≈ a week or more. Risk: the chance it breaks or costs more than it returns.

1. **Runtime performance governor (safety net).** In the client, sample `Stats.FrameTime` (EMA),
   `Stats:GetTotalMemoryUsageMb()` and (with `MemoryTrackingEnabled`) `GetMemoryUsageMbForTag(GraphicsTexture / Gui /
   LuaHeap)`. With hysteresis, step down: fg foliage off → particles and ambient sprites halved → UIShadow glows off →
   LOW tiles (the repo already has the tier switch and a `Prefs.detail` override). This matters because no API
   reports RAM or the automatic quality level, and `SavedQualityLevel` is usually `Automatic`. *Cost M, risk low*
   (keep hysteresis wide to avoid flapping; memory falls only after GC and tile unload).
2. **Real-device memory and FPS telemetry.** Once per session at 60 s and 10 min, call
   `AnalyticsService:LogCustomEvent(player, "ClientMemMB", mb, {tier, PreferredInput, ViewportDisplaySize})` through a
   remote; also log FPS and texture MB. With the Performance dashboard's "unexpected OOM exits" and "memory % by
   device" charts (≥ 100 DAU), this checks REALM.md's 150 MB and 35 MB budgets on the phones players actually own.
   *Cost S, risk low* (keep within 120 + 20×CCU/min and 100 event names; send from the server; the client value can be
   spoofed but only skews stats).
3. **CI on the real engine.** Build with Rojo, publish to a *test* place with the Place Publishing API
   (`versionType=Saved`), then run the existing `roblox` suite (today on `port/tests/mock.luau`) inside the engine
   through the **Luau Execution API** with the version pinned; publish to production only from a tagged run.
   Roblox's `place-ci-cd-demo` is the template. *Cost M, risk low-medium*: a 5 min cap per task, plan for 2 concurrent
   tasks per universe, and the API key needs `universe.places:write` + `universe.place.luau-execution-session:write`.
   Keep the key out of the repo (the proxy injection pattern from `upload.js` works).
4. **Visual QA through the Studio MCP server.** On a desktop with Studio open, Claude Code connects to the built-in
   MCP. Script `start_stop_play`, then `execute_luau` to fly the map camera to the six `record.js` rest poses and
   force HIGH or LOW, then `screen_capture`. Diff the shots against the `compose.js` stills (straight-alpha mode).
   This is the first check that the Roblox render matches the Playwright simulator (seams, alpha fringes, 9.3
   snapping). *Cost S-M, risk low* (Studio has to be running on a desktop; tool names can still change).
5. **Native code on the server hot path.** Add `@native` to hot functions in `src/server/Runtime` (JSRT, BEcore),
   `vendor/TowerNum` and the corruption-grid loops, measured with Script Profiler (a tick is 7-14 ms today). Faster
   ticks mean more players per server and less `TICK_CPU_SHARE` throttling of automation. *Cost S, risk low-medium*
   (there is a cap on total native code, so don't mark the huge generated `Game/*.luau` wholesale; check that output
   is bit-identical with `port/test.sh`).
6. **Decide asset ownership and privacy before the real upload.** Turn on "Restrict on creation" for the uploading
   user or group, upload as the **same owner as the game** (`ROBLOX_CREATOR=group:<id>` if the game is
   group-owned), and grant the game once. Otherwise anyone can reuse the painted realm by id. *Cost S, risk medium*:
   Open Use can't be undone and game grants are permanent; a wrong owner means tiles that don't load, so test in a
   private published place.
7. **Prototype "realm as 3D diorama" (the unreal option).** Put each depth plane on large Parts with `Decal` or
   `Texture` (or MeshParts with `SurfaceAppearance`) at real Z depths in front of the camera. What you gain:
   * true parallax
   * **4K textures with automatic per-device mip streaming by Harmony**, fewer seams and far fewer tiles
   * real `BloomEffect`, `DepthOfFieldEffect` and `ColorCorrectionEffect` on the art (they don't touch ScreenGui)
   * emissive masks on the rift and light-falls
   * the orthographic camera, due late 2026, for exact 2D framing

   The nodes stay in the ScreenGui, projected with `Camera:WorldToViewportPoint`. *Cost L, risk high*: a MapView
   rewrite, alpha sorting between planes, DoF and Bloom off on low quality levels, 4K off on low-end devices. Start
   with the `sky` layer only, on HIGH, behind a flag.
8. **Use shipped native UI, and harden the capability probes.**
   * Adopt what has shipped: `UIShadow` glows (keep ≤ 100 on screen), per-corner radii for tabs and sheets, multiple
     `UIStroke`s with `BorderStrokePosition.Inner` for neon double rims, and **Styling Transitions** for hover and
     press. Transitions run in the engine, so there is less Luau tween churn.
   * The risk: `Theme.detect` probes Radial, Conical and TileMode by setting the property in a pcall. Those members
     exist in the 0.740 client API while the feature is **Studio Beta only**, so a probe could pass live while the
     client does not draw it (e.g. `Common.blob` would get a linear fade).
   * The fix: gate "Studio-beta" capabilities on `RunService:IsStudio()` or a `ConfigService` flag until the Full
     Release post, and test in a published private place.

   *Cost S, risk low.*
9. **Milestone "reveal" moments (Sol's RNG-grade spectacle).** Add a short full-screen overlay for big firsts:
   a new layer unlocked, Multiverse, a rare achievement. Build it from:
   * a camera push-in on the node, a star burst of atlas sprites, a `UIShadow` bloom ring and a rotating rays
     ImageLabel (native conic gradients once they ship)
   * a `HapticEffect` (`UINotification`) and a stinger timed with `AudioPlayer:Play(atTime)`

   Scale it by rarity, gate it on `Motion.reduced()`, and make it skippable. *Cost M, risk low-medium* (overuse
   numbs it; keep it rare; it must not block input when a player spams buttons).
10. **Audio-reactive realm.** Wire the music `AudioPlayer` through an `AudioAnalyzer` (`SpectrumEnabled = true`) and
    use `RmsLevel` and low bands of `GetSpectrum()` to breathe the nebula wash, the rift pulse and the firefly
    brightness a few percent. It is cheap and players notice. *Cost S-M, risk low* (audio upload quota: 10/month
    unverified, 100/month ID-verified; see `audio.md`).
11. **Analytics shaped for an incremental.**
    * `LogOnboardingFunnelStepEvent` for the first 15 minutes (first buy, first reset, first layer).
    * `LogProgressionEvent("layers", …, level = number of unlocked nodes)`.
    * A custom event per prestige with **log10 of the points** (TowerNum values are beyond doubles), using the 3
      custom fields for layer id, tier and input.
    * Then tune pacing constants live with **ConfigService** and prove changes with 14-60 day **Experiments**.

    *Cost S, risk low* (10 funnels, 100 event names; data takes up to 24 h to appear).
12. **Get into discovery and bring players back.**
    * Complete the maturity questionnaire (the game should rate Minimal).
    * Meet the Kids & Select gates (2FA, verification, Plus/Premium or the fee, 250 highly engaged plays in 60 days)
      or the game stays 16+ and out of search.
    * Add an `ExperienceNotificationService:PromptOptIn()` after the first offline-production claim and send "your
      offline progress is capped" notifications via Open Cloud.
    * Add `CaptureService:PromptShareCapture` for a "share my realm" button and `SocialService:PromptGameInvite`.

    *Cost M, risk low* (follow notification policy; don't nag).
13. **Localization without garbage.** Automatic Text Capture would scoop up thousands of transient number strings
    from the HTML → RichText output. Set `AutoLocalize = false` on every number-bearing or server-generated label.
    Translate static chrome (dock, options, toasts) with a `LocalizationTable` and
    `GetTranslatorForPlayerAsync`, and leave game text in English at first. *Cost M, risk medium* (RichText tags
    inside translatable strings; formatting of numbers stays with TowerNum).
14. **Data-store guard rails.** In `port/test.sh`, assert that the largest late-game save
    (`HttpService:JSONEncode`) is well under 4,194,304 characters and that autosave stays under 4 MB/min per key. At
    runtime, check `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)` before
    non-critical writes such as `client_` prefs. The enum still has the legacy `UpdateAsync` / `SetIncrementAsync`
    items as well as the new `StandardRead` / `StandardWrite` / `StandardList` / `StandardRemove` and `Ordered*`
    items; the limits doc uses the new ones. Consider `SetRateLimitForRequestType` so a prefs storm can't starve
    saves. *Cost S, risk low.*
15. **Procedural FX with EditableImage, HIGH tier only.** Use a 256-512² EditableImage for the corrupted outcrop
    glitch or the rift shimmer (`WritePixelsBuffer` from a `buffer`, updated at about 15 Hz), shown through
    `ImageLabel.ImageContent = Content.fromObject(img)`. Fall back to the atlas sprites when
    `CreateEditableImage` returns `nil` (budget used up). *Cost M, risk medium*: needs a 13+ ID-verified owner and
    the Dashboard toggle, uses client CPU per update, and has a strict client memory budget. Keep it off on LOW and
    under ReducedMotion.

**Sources**: every claim is linked above. The main references are the Roblox Creator Docs (read from the
`Roblox/creator-docs` repository, Sep 2026), the DevForum announcements cited next to each feature, the Roblox
newsroom (RDC24/25/26, Cube, creator interviews), the Roblox client API dump v0.740.19 (MaximumADHD tracker) and this
repo's `globalTypes.d.luau`.
