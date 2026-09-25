# Roblox 3D rendering: lighting, post-processing, materials, particles, camera (state as of September 2026)

Part of the Milestone Tree NG+ "fat library" on what Roblox can do. Topic: **the 3D renderer**. It covers lighting,
post-processing, materials, particles and FX, the camera, performance scaling, how showcase games get their look, and
what that means for the parallax realm and the glowing skill tree.

**How claims are tagged**

| Tag | Meaning |
|---|---|
| **[V]** | Checked against the engine type dump (`scratchpad/tools/globalTypes.d.luau`) **and** the official docs (creator-docs repo, `main`, snapshot 2026-09-25) |
| **[T]** | In the type dump and script-accessible, but not (or barely) documented |
| **[R]** | In the type dump but **Roblox-only** (`RobloxScriptSecurity` in the full API dump). Scripts cannot use it. Do not design around it |
| **[P]** | Readable, but writable only by plugins or Studio (`PluginSecurity`, or the write capability is `PluginOrOpenCloud`). Set it at edit time; you cannot change it at runtime |
| **[C]** | Community-reported (DevForum), not confirmed by Roblox docs |
| **[U]** | Unverified. My inference or design advice; test it in Studio before relying on it |

Security levels come from the full API dump (`MaximumADHD/Roblox-Client-Tracker`, `Full-API-Dump.json`, Sept 2026).
`Instance.new` defaults come from the rbx-dom reflection database (engine 0.728). Section 11 lists the members that
appear in `globalTypes.d.luau` but are **not** usable by game scripts. The dump includes internal members, so "it
type-checks" does not mean "it works".

---

## 0. The fifteen facts that matter most

1. **Post-processing never touches `ScreenGui`s or `ViewportFrame`s.** It applies to the 3D world, including
   `SurfaceGui`s and `BillboardGui`s with `AlwaysOnTop = false`. The corollary: **anything you want to bloom, blur or
   colour-grade has to live in Workspace.** The current realm is a ScreenGui, so today it can never receive Bloom or
   DOF. [V] ([PostEffect](https://create.roblox.com/docs/reference/engine/classes/PostEffect),
   [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame))
2. **A 3D GUI can glow for real.** With `SurfaceGui`/`BillboardGui.LightInfluence = 0`, `AlwaysOnTop = false` and
   `Brightness` > 1 (range 0–1000), the GUI emits HDR light that feeds Bloom. [V]
   ([3D GUI Brightness](https://devforum.roblox.com/t/new-brightness-property-for-3d-guis/1283855))
3. **Emissive masks are live (2026-02-12)** on `SurfaceAppearance`, `MaterialVariant` and `TerrainDetail`.
   `EmissiveStrength` and `EmissiveTint` are **scriptable at runtime**. The documented formula is
   `final = (mask · strength · tint + lighting) · ColorMap`. Emissives render at every quality level and do not fade
   with distance (Neon does). [V] ([live post](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705),
   [beta post](https://devforum.roblox.com/t/studio-beta-emissive-masks/4034414))
4. **Depth of field does not render on phones or tablets.** On desktop it needs graphics quality **8 or higher**. Treat
   DOF as PC-only garnish and **bake blur into far and near art** for everyone else. [V]
   ([Selfie Mode docs](https://create.roblox.com/docs/resources/modules/selfie-mode))
5. **The realm's "dolly law" `s_L = z / (f + (1 − f)·z)` is exactly a perspective camera dollying toward the world
   plane**, with each layer at distance `D/f`. REALM §2.3 says so itself; the derivation is in 7.3. The painted
   parallax realm can move into real 3D **with zero change to its camera maths**, and that move unlocks Bloom,
   ColorCorrection, SunRays, 3D particles, lights and DOF. [U] (the maths is exact; the port is design)
6. **Unified Lighting replaced `Lighting.Technology`.** `LightingStyle` (Realistic / Soft) and
   `PrioritizeLightingQuality` are set in Studio only. `Technology` is now Roblox-only. [V]/[P]
   ([Unified Lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512))
7. **Local lights cap at `Range` 120 studs** (was 60 until Sept 2025) and default to `Shadows = false`. [V]
   ([120-range post](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367))
8. **The Highlight limit is 255 (was 31) since 2025-11-10.** The first visible Highlight costs up to about 1 ms of GPU
   on mobile; the rest are cheap. Disabled Highlights still use a slot. [V]
   ([announcement](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534),
   [docs](https://create.roblox.com/docs/effects/highlighting))
9. **Official budgets: ~500 draw calls and ~500k triangles "in scene"**, and under 1.3 GB client memory to support
   2 GB phones. **Each ParticleEmitter and each Beam costs one draw call.** SurfaceGuis and BillboardGuis "chew up
   drawcalls very quickly". [C, Roblox staff]
   ([Real World Optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146))
10. **Instancing:** MeshParts with the same `MeshContent` **and** the same `SurfaceAppearance` (or the same
    `TextureContent`, or the same material when neither exists) draw in **one** draw call. Decals, textures and
    particles don't batch. [V] ([improve](https://create.roblox.com/docs/performance-optimization/improve))
11. **Scripts can read render timings:** `Stats.RenderGPUFrameTime`, `RenderCPUFrameTime`, `FrameTime`,
    `SceneDrawcallCount`, `SceneTriangleCount` and `ShadowsDrawcallCount`. So an **adaptive FX governor** is possible.
    `UserGameSettings.SavedQualityLevel` is readable. The live `GraphicsQualityLevel` is Roblox-only. [V]/[R]
12. **Particles:** up to 400 particles/s per emitter (100/s on mobile), lifetime capped at 20 s, flipbooks up to
    30 fps. **Custom flipbook grids of 1–64 × 1–64 on non-square textures** have been available since Oct 2025. Flipbooks
    are switched off automatically when a client runs low on memory. [V]
13. **Beams are LOD'd.** Their segment count drops with distance (about 200–1000 studs) and with graphics quality,
    and curved or low-segment beams can vanish at quality 1. [C]
    ([bypass thread](https://devforum.roblox.com/t/bypassing-forced-beam-lod/2426888))
14. **At low graphics levels the draw distance shrinks** (about 200 studs at level 1 in complex scenes [C]). Shadows
    turn off below quality 4 [V]. Keep a realm diorama **within a few hundred studs of the camera**. The Fall 2026
    roadmap plans a "minimum draw distance of 500 studs".
15. **There is no native orthographic camera yet.** It is on the roadmap for late 2026. The workaround (FOV 1–6,
    camera thousands of studs away) breaks on low quality, because the level stops rendering. [C]
    ([roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208),
    [request](https://devforum.roblox.com/t/orthographic-camera-projection-for-experiences-and-studio/3932266))

---

## 1. Mental model: what the renderer does to a frame

```
Workspace geometry (parts, meshes, terrain, decals)        ─┐
  lit by: sun/moon (Lighting), ambient, IBL from Sky,       │
          local lights (Point/Spot/Surface), emissives      │  HDR scene
Transparent pass: glass, particles, beams, trails,          │  (values can exceed 1.0)
  SurfaceGui / BillboardGui (AlwaysOnTop=false), fog/atmos  ─┘
            │
            ▼  post chain (Lighting children + CurrentCamera children)
   SunRays → DepthOfField → Bloom → Blur → ColorCorrection(s) → tonemapper (ColorGradingEffect preset)
            │   (the exact order is internal; this is the observable layering [U])
            ▼
   Highlights (own post pass), BillboardGui / SurfaceGui with AlwaysOnTop=true  (drawn after post, no blur)
            ▼
   ScreenGuis, ViewportFrames, CoreGui  (never post-processed)
```

**Which objects receive which effect**

| Object | Bloom | Blur / DOF | ColorCorrection | Atmosphere / fog | Lit by scene | Source |
|---|---|---|---|---|---|---|
| Parts, meshes, terrain | yes | yes | yes | yes | yes | [V] |
| ParticleEmitter, Beam, Trail | yes (use `Brightness`, `LightEmission`) | yes | yes | yes [U] | per `LightInfluence` | [V]/[U] |
| SurfaceGui (AlwaysOnTop=false) | yes, via `Brightness` with `LightInfluence` < 1 | **yes** | yes | yes | per `LightInfluence` | [V] ([staff reply](https://devforum.roblox.com/t/option-for-bluring-billboardguis-when-blureffect-is-enabled/2272221)) |
| BillboardGui (AlwaysOnTop=false) | yes | yes | yes | yes [C] | per `LightInfluence` (bug reports say never fully 0) | [V]/[C] |
| Surface/BillboardGui (AlwaysOnTop=true) | no (`Brightness` ignored) | **no** | no [U] | no | no (treated as `LightInfluence` 0) | [V] |
| ScreenGui | **no** | **no** | **no** | no | no | [V] |
| ViewportFrame content | **no post, no shadows**; Neon and Glass at lowest quality | no | no | no | own `Ambient`/`LightColor`/`LightDirection` | [V] |
| Highlight | drawn in its own pass | no | no | no | no | [U] |

**HDR:** since "Future Is Bright", Roblox renders HDR and tonemaps. Neon and bloom are "completely coupled", and
"glowing neon [works] all the way down to the lowest quality, [with] lower quality visuals"
([Unified Neon and Bloom](https://devforum.roblox.com/t/unified-neon-and-bloom-poll/180359)). Anything whose final
colour goes above `BloomEffect.Threshold` blooms: Neon, emissive masks, `Brightness` > 1 on particles, beams, trails
and 3D GUIs, and additive (`LightEmission = 1`) stacking.

---

## 2. Lighting

### 2.1 Technology → Unified Lighting [V]

`Lighting.Technology` is deprecated and **[R]** (Roblox-only read and write). It was replaced in 2025 by two properties
you set in **Studio's Properties window only** **[P]**: the write capability is `PluginOrOpenCloud`, so a game script
cannot switch them at runtime.

| Property | Values | Meaning |
|---|---|---|
| `Lighting.LightingStyle` | `Enum.LightingStyle.Realistic` / `.Soft` | Realistic is "the most advanced and realistic lighting and shadows Roblox can deliver". Soft is "a flat, retro-Roblox look with softer lights and shadows". |
| `Lighting.PrioritizeLightingQuality` | bool (the docs now tag it deprecated) | As quality scales down, `true` keeps "advanced shadows and high-quality shaders at closer distances" and `false` keeps view distance. |

Legacy mapping from the announcement: **Future = Realistic + true**, **ShadowMap = Soft + true**, **Voxel = Soft +
false**. `Enum.Technology` still lists `Legacy, Voxel, Compatibility, ShadowMap, Future, Unified`. For a pre-2019 look,
the docs recommend Voxel plus `ColorGradingEffect.TonemapperPreset = Retro`
([Enum.Technology](https://create.roblox.com/docs/reference/engine/enums/Technology)).

**Device scaling.** Future-style lighting reached **all Android devices on 2024-10-29**. Devices that can't hold
framerate fall back to ShadowMap
([Future on Android](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808)).
The engine drops shadows entirely **below quality level 4** [V]
([improve](https://create.roblox.com/docs/performance-optimization/improve)). Community measurements (2022, before
Unified Lighting): on PC, levels 1–2 look like Compatibility, 3–4 like ShadowMap, and 8–10 show true Future [C]
([lighting modes](https://devforum.roblox.com/t/roblox-lighting-modes-what-do-i-use-for-my-game/1687174)). Memory
averages in the same thread were Future about 700 MB, ShadowMap about 550 MB and Voxel about 600 MB [C]. Some players
report **lighting flicker** with `PrioritizeLightingQuality` on [C]
([thread](https://devforum.roblox.com/t/please-fix-roblox-lighting-flicker-prioritizelightingquality-is-enabled/4239728)).

### 2.2 `Lighting` properties (all script-writable unless noted) [V]

| Property | Range / default | Notes and tricks |
|---|---|---|
| `Ambient` | Color3; default black (docs) | Hue for sky-occluded areas. With `GlobalShadows = false` it applies **everywhere** and `OutdoorAmbient` is ignored. |
| `OutdoorAmbient` | default (127,127,127) | Clamped to ≥ `Ambient` per channel. |
| `Brightness` | number | Sun or moon intensity. Raising it increases contrast. |
| `ExposureCompensation` | **−5 … 5**, default 0; +1 = 2× exposure | Applied **before** the tonemapper. It is the cleanest global "fade to black or white" and dawn effect. |
| `ColorShift_Top` / `ColorShift_Bottom` | Color3 | Tints faces toward or away from the sun. Mostly visible with `GlobalShadows` off. |
| `EnvironmentDiffuseScale` | 0–1, default 0 | Ambient derived from the sky (IBL). Lower `Ambient`/`OutdoorAmbient` when you raise it. |
| `EnvironmentSpecularScale` | 0–1, default 0 | Sky reflections. **Metalness does nothing at 0.** For PBR the docs recommend 1/1 with both ambients black. |
| `GlobalShadows` | bool | Voxel sky-occlusion shadows use 4×4×4-stud voxels, so objects under 4 studs don't shadow properly. |
| `ShadowSoftness` | 0–1, default 0.2 | Realistic style and shadow-map-capable devices only. |
| `ClockTime` / `TimeOfDay` | 0–24 / "HH:MM:SS" | Linked. `ClockTime` is `NotReplicated`. |
| `GeographicLatitude` | degrees | Moves the sun path without changing time. Use `GetSunDirection()` and `GetMoonDirection()`. |
| `FogColor`, `FogStart`, `FogEnd` | studs | **Hidden and ignored while an `Atmosphere` exists.** Linear fog in studs, handy for small dioramas [U]. |
| `LightingStyle`, `PrioritizeLightingQuality` | see 2.1 | [P] |
| `Technology` | – | [R] |
| `ExtendLightRangeTo120` | – | Unused, not scriptable. The clamp is always 120. |

Lighting changes made from a **LocalScript are local to that client**. That is how per-screen moods (home realm
versus other screens) stay private [V, standard client/server behaviour].

### 2.3 Local lights [V]

| Class | Key props (defaults) | Emits from | Notes |
|---|---|---|---|
| `PointLight` | `Range` 8, `Brightness` 1, `Color`, `Shadows` false | the parent part's position or the attachment's `WorldPosition` | Must be a **direct child** of a `BasePart` or `Attachment` in Workspace. |
| `SpotLight` | `Angle` 90 (max 180), `Face` (Front), `Range` 16 | a part face or an attachment axis (−Z = Front) | |
| `SurfaceLight` | `Angle` 90, `Face`, `Range` 16 | the whole part face (on an attachment it acts like a SpotLight) | Good for "screen" or panel glow. |

* **`Range` is clamped to 120 studs.** Scripts that set more are clamped. One 120-range light is cheaper than four
  60-range lights covering the same area, but cost rises steeply with range
  ([post](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367)).
* **`Brightness` does not extend reach.** It only scales intensity inside `Range`.
* **Scriptable cameras must update `Camera.Focus` every frame**, at `Enum.RenderPriority.Camera` or in `PreRender`.
  The docs say "dynamic lighting from objects such as PointLights may not render at distances far from the focus".
  [V] ([Camera.Focus](https://create.roblox.com/docs/reference/engine/classes/Camera))
* **Cost drivers:** shadow-casting lights, their density, and many small shadow-receiving parts. Turn off
  `Light.Shadows` and `BasePart.CastShadow` where you don't need them, limit range and angle, and switch lights off by
  area. MicroProfiler scopes: `computeLightingPerform`, `LightGridCPU` (voxel grid), `ShadowMapSystem`. [V]
* Official docs publish no maximum light count or per-light shadow limit. Test on target phones.

### 2.4 `Atmosphere` (child of `Lighting`) [V]

| Prop | `Instance.new` default | Effect |
|---|---|---|
| `Density` | 0.395 | Particles in the air; obscures objects and terrain (not the skybox directly). |
| `Offset` | 0 | Light transmission to the sky. Low values blend distant objects into the sky, which can cause "ghosting" (the sky shows through objects). High values silhouette the horizon. |
| `Haze` | 0 | Haziness above the horizon and in the distance. Pair it with `Color`. |
| `Glare` | 0 | Glow around the sun. **Needs `Haze` > 0.** |
| `Color` | (200,170,108) | Atmosphere hue. |
| `Decay` | (92,60,14) | Hue away from the sun. **Needs `Haze` and `Glare` > 0.** |

Studio slider ranges are commonly Density and Offset 0–1, Haze and Glare 0–10 [C]. Atmosphere is tuned for
world-scale distances. On a small diorama (tens to hundreds of studs) its effect may be weak. Prefer baked haze or
legacy `Fog*` for that case, and test it [U].

### 2.5 `Sky` (child of `Lighting`) [V]

* Six faces: `SkyboxBk/Dn/Ft/Lf/Rt/Up` (or `…Content`). Each face must be seamless along all edges. The default
  textures are 512² (`sky512_*.tex`).
* `CelestialBodiesShown` (sun, moon and stars), `StarCount` (default 3000), `SunAngularSize` (default 21, clamped to
  0–60), `MoonAngularSize` (11), `SunTextureId`, `MoonTextureId`.
* **`SkyboxOrientation` (Vector3, degrees, applied Y then X then Z) is "a low-cost feature which works seamlessly
  across all platforms and visual quality levels".** Spin Y slowly in `Heartbeat` for a living cosmos. Celestial
  bodies, reflections and dynamic clouds do not rotate with it. [V]
  ([skybox](https://create.roblox.com/docs/environment/skybox))
* A `Sky` inside a `ViewportFrame` acts as that frame's reflection cubemap.

### 2.6 `Clouds` and wind [V]

* `Clouds` renders **only when parented to `Terrain`**. Props: `Cover` 0–1 (default 0.5), `Density` (0.7), `Color`
  (tinted by Lighting and Atmosphere), `Enabled`.
* `Workspace.GlobalWind` (Vector3) moves clouds, terrain grass and **particles**. For particles it needs
  `ParticleEmitter.WindAffectsDrag = true` **and** `Drag > 0`. `Fire` and `Smoke` follow the wind by default. Scripted
  gusts: lerp `GlobalWind` with `math.sin`. Reduce Motion slows grass (not direction).
  ([global wind](https://create.roblox.com/docs/environment/global-wind))

### 2.7 Terrain and water [V]

* Voxels are 4×4×4 studs. Water props: `WaterColor` (default dark teal), `WaterReflectance` 0–1 (1),
  `WaterTransparency` 0–1 (0.3), `WaterWaveSize` 0–1 studs, `WaterWaveSpeed` 0–100 per minute. Some water visuals show
  only while playtesting or at high editor quality.
* `Terrain.Decoration` (animated grass) and `GrassLength` (0.1–1) are **not scriptable**.
* Custom terrain looks come from `MaterialVariant` overrides plus `TerrainDetail` (top, side and bottom faces).
  `TerrainDetail` also supports emissive masks.

### 2.8 Time-of-day and mood tricks

* Tween `ClockTime` for sun sweeps. The sun sprite, SunRays and shadows follow. A LocalScript tween affects only that
  player.
* To place the sun behind a hero object, solve `ClockTime` and `GeographicLatitude` so that `GetSunDirection()`
  points at it. Then `SunRaysEffect` rays shape around the silhouette [U].
* Mood swaps like Duvall Drive's normal and corrupt rooms: keep preset tables (Lighting props + Atmosphere +
  ColorCorrection) and tween between them
  ([Duvall supporting systems](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/supporting-systems)).
* "Fullbright" or unlit look: `GlobalShadows = false`, `Brightness = 0`, `Ambient` near white,
  `EnvironmentDiffuseScale = 0`. Every surface then shows roughly its texture colour. Calibrate against the tonemapper
  with a grey-ramp card [U].

---

## 3. Post-processing [V]

Parent effects to **`Lighting`** (everyone sees them) or to **`Workspace.CurrentCamera`** (only the local player). Every
effect has `Enabled`. Some effects "work differently or not at all" at low `QualityLevel`, and low-end devices may use
faster algorithms ([PostEffect](https://create.roblox.com/docs/reference/engine/classes/PostEffect)).

| Effect | Properties (`Instance.new` defaults) | Stacking | Low-end / mobile |
|---|---|---|---|
| `BloomEffect` | `Intensity` 0.4, `Size` 24 (px radius; 0 disables the bleed but not the colour shift), `Threshold` 0.95 (1 = only pure white blooms, 0 = everything) | **Multiple compose** | Renders at low quality with lower fidelity (neon/bloom unified). |
| `BlurEffect` | `Size` 24 (px Gaussian radius) | **Only one**: the largest `Size` wins | "May render differently on low-end devices". |
| `ColorCorrectionEffect` | `Brightness` 0 (−1 black … 1 white), `Contrast` 0, `Saturation` 0 (−1 = greyscale), `TintColor` white (**multiplicative** per channel) | **Multiple compose** | Cheap. Use it for feedback such as a red low-health tint. |
| `ColorGradingEffect` | `TonemapperPreset`: `Default` (post-2019 vivid) / `Retro` (pre-2019, less contrast) | **One**, the most recently parented; **must be under `Lighting`** (ignored elsewhere) | – |
| `DepthOfFieldEffect` | `FarIntensity` 0.75, `NearIntensity` 0.75, `FocusDistance` 0.05 (studs), `InFocusRadius` 10 (studs, both sides) | One effective [U] | **Not rendered on phones or tablets. Desktop needs quality ≥ 8.** |
| `SunRaysEffect` | `Intensity` 0.25 (opacity), `Spread` 1 (0–1; outside is undefined) | – | "May not render on low-end devices". Occluders between camera and sun shape the rays. |

Studio slider maxima (Bloom `Size` and Blur `Size` 56, DOF `FocusDistance` 200, `InFocusRadius` 50) are
community-reported [C]. `ColorCorrectionEffect.TintColor` above 1 (for example `Color3.new(1.2,1,1)`) is untested [U].

**Combining for a stylised "cosmic neon" grade** (starting point [U]):

```lua
-- LocalScript: realm grade. Everything lives in Workspace, so all of it applies.
local L = game:GetService("Lighting")
local bloom = Instance.new("BloomEffect")      bloom.Intensity, bloom.Size, bloom.Threshold = 0.9, 36, 1.05
local cc    = Instance.new("ColorCorrectionEffect")
cc.Contrast, cc.Saturation, cc.TintColor = 0.12, 0.18, Color3.fromRGB(236, 228, 255)  -- violet cast
local rays  = Instance.new("SunRaysEffect")    rays.Intensity, rays.Spread = 0.08, 0.6
for _, e in {bloom, cc, rays} do e.Parent = L end
L.ExposureCompensation = 0.15
-- Threshold > 1 keeps ordinary painted colour from blooming; only HDR sources (Neon, emissive,
-- Brightness > 1 beams / particles / 3D GUIs) cross it.
```

**Rules of thumb**

* Raise `Threshold` above 1 (values > 1 are meaningful in HDR; confirm the accepted range in Studio [U]) and drive
  glow from **HDR sources**. A low threshold washes all the painted art out
  ([thread](https://devforum.roblox.com/t/im-trying-to-decrease-blooming-threshold-to-make-neon-parts-brighter-but-it-ends-up-making-other-parts-glow-too-that-shouldnt-glow/1789215)).
* Put per-player, transient effects (menu blur, damage flash, unlock flash) on the **Camera**. Put the world grade on
  **Lighting**.
* `BlurEffect` blurs the **3D view only**. The UI stays sharp. That is the standard "menu open" look and it costs no
  UI changes.
* Tween effects with `TweenService` (Intensity, Size, TintColor and so on). Every property is a plain number or
  Color3.

**UI blur hacks, and why not to rely on them.** (a) DOF plus an invisible Glass part in front of the camera, mapped to
a Frame's rect: it blurs part of the screen, but it hides 3D GUIs, can't coexist with another DOF, needs quality ≥ 8
and doesn't work on mobile
([thread](https://devforum.roblox.com/t/blurred-uis-using-depth-of-field-effect/4734313)). (b) "Liquid Glass": 9
meshes rendered with Highlights and repositioned every frame; high graphics (about level 6 and up) only, no mobile
([thread](https://devforum.roblox.com/t/%F0%9F%9B%A0%EF%B8%8Fliquid-glass-ui-blur-is-a-thing-of-the-past%F0%9F%9B%A0%EF%B8%8F/4416219)).
A native **UI blur effect** is on the roadmap for early 2027
([Fall 2026 roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208)).

---

## 4. Materials and surfaces

### 4.1 Built-in materials with render quirks [V]

| Material | Behaviour | Tricks and caveats |
|---|---|---|
| `Neon` | Self-lit and blooms. **Glow scales with colour Value (HSV V)**; hue and saturation don't matter, so black neon doesn't glow [C] ([neon guide](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408)). | Coupled to Bloom. It fades at distance and quality (emissive masks don't). Lowest quality inside ViewportFrames. The cheapest glow on every device. |
| `Glass` | Reflective, with perspective distortion or refraction on moderate+ settings, strongest on spheres. **Refraction is not supported on mobile.** **Semi-transparent parts behind Glass are invisible.** | Use it for lens or orb effects on PC. Mobile shows a plain transparent part. |
| `ForceField` | An animated shimmer that displays the **value range of the `MeshPart.TextureID`** from dark to light. It needs a MeshPart whose UVs cover most of 0–1 ([Enum.Material](https://create.roblox.com/docs/reference/engine/enums/Material)). | Holograms, shields, rift tears. Author a high-contrast noise texture. |
| `SmoothPlastic` | No texture. | A clean base for decals and unlit tricks. |
| `Foil`, `Metal` | Strong sun and specular response. | Needs `EnvironmentSpecularScale` > 0 to shine. |

* `BasePart.Reflectance` (0–1) reflects the sky. It is ignored at full transparency and by some materials.
* `BasePart.Transparency`: fully transparent parts are skipped, but **partial transparency costs a lot**, and
  "when transparent parts overlap, render order may act unpredictably". Sorting is per object, so avoid overlapping
  translucent parts [V].
* `LocalTransparencyModifier` is a client-only multiplier: `1 − (1 − T)(1 − LTM)`.

### 4.2 `SurfaceAppearance` (PBR on MeshParts) [V]

| Property | Script access | Notes |
|---|---|---|
| `ColorMap` / `NormalMap` / `RoughnessMap` / `MetalnessMap` (+`…Content`) | **[P]** (the `…Content` variants take an `EditableImage` at creation) | Normal maps are OpenGL tangent-space, and a flat normal is (127,127,255). Metalness needs `EnvironmentSpecularScale` > 0. |
| `EmissiveMaskContent` | **[P]** | Greyscale; only the **R channel** is used. |
| `EmissiveStrength`, `EmissiveTint` | **runtime-writable** | Suggested range 0–40 (the UGC validation cap is 40). Large values clip to white. |
| `Color` | **runtime-writable** | A multiplicative tint of the ColorMap. **Free**: one texture, many tints. Author near-white maps for the strongest tint. |
| `AlphaMode` | writable | `Overlay` (default; reveals `MeshPart.Color`), `Transparency` (see-through), `TintMask` (alpha controls where `Color` applies), `Opaque` (beta: ignores alpha). |
| `ResampleMode` | writable | `Default` (bilinear) or `Pixelated` (nearest; crisp pixel art). |

* **Two transparency paths:** `AlphaMode = Transparency` with `MeshPart.Transparency = 0` gives cutout-like, opaque,
  **depth-correct** rendering that works with DOF, refraction and water reflection. With `Transparency ≥ 0.02` you
  get smooth blending but "does not support all effects and occlusion may not be perfect". Use cutout for hard-edged
  art such as silhouettes, foliage and islands, and blend only for soft fog.
* Appearance "depends on the user's device and graphics quality level". Preview at low and high editor quality.
* **Runtime-generated PBR:** `AssetService:CreateSurfaceAppearanceAsync(maps)` with `EditableImage`s (the images can't
  be swapped afterwards), or `Content.fromObject(editableImage)` on `…Content`. EditableImage needs a 13+ ID-verified
  owner who has enabled "Mesh / Image APIs", runs under a per-device memory budget (creation returns `nil` when it is
  exhausted), and updates **only one displayed EditableImage per frame**
  ([EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage)).
* Engine texture support: **4K textures** and **texture streaming** shipped in the first half of 2026
  ([Spring 2026 roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473)).

### 4.3 Emissive masks: the new glow primitive [V]

```
Final colour = (EmissiveMask · EmissiveStrength · EmissiveTint + combined lighting) · ColorMap
```

* Shipped for published games on **2026-02-12** for `SurfaceAppearance`, `MaterialVariant` and `TerrainDetail`.
  Decals are "being worked on" (no date) ([request](https://devforum.roblox.com/t/decal-texture-emissive-maps/4743835)).
  UGC avatar emissives are planned for mid-2027+.
* "Emissives now appear at **all quality levels** and they **won't fade out in far distances**", unlike Neon.
* The mask does **not** light the scene. Pair it with a `PointLight` if you need spill.
* **The unlit-shader trick [U]:** with a white mask, strength 1, white tint and near-zero scene lighting on that
  object, `Final ≈ ColorMap`. The painted art then shows its exact colours, and `EmissiveTint` and `EmissiveStrength`
  become runtime colour-grade and HDR knobs (strength > 1 pushes it past the bloom threshold). A 4×4 white mask can be
  shared by every tile. Test how the texture pack handles it.

### 4.4 `MaterialVariant` / `MaterialService` [V]

* A `MaterialVariant` (tileable PBR plus physics) works **only as a descendant of `MaterialService`**. Apply it per part
  with `BasePart.MaterialVariant = "<name>"` (name-based, so "adaptive"), or globally with
  `MaterialService:SetBaseMaterialOverride(material, name)` (the only way onto terrain).
* Maps are [P]. `EmissiveStrength`/`EmissiveTint`, `StudsPerTile` and `MaterialPattern` (`Regular` or `Organic`) are
  writable. The ColorMap alpha is unused unless `AlphaMode` is set.
* Style swap: keep several same-named variant folders and re-parent one folder into `MaterialService` to reskin the
  whole world.

### 4.5 `Decal` / `Texture` [V]

* `Decal` gained **`UVOffset`, `UVScale`, `Rotation` and `ZIndex`**. **Normal, roughness and metalness maps** make a
  Decal a PBR surface (mid-2026; the maps are [P]). `Texture` adds `StudsPerTileU/V` and `OffsetStudsU/V`, which you
  can animate for scrolling.
* `Decal.EmissiveStrength`, `EmissiveTint` and `EmissiveMaskContent` are in the API **[T]**, but Roblox says decal
  emissive isn't live yet. Don't ship on them.
* **HDR tint trick [C]:** `Decal.Color3` values above 1 (such as `Color3.new(4,4,4)`) push it past the bloom
  threshold. The same works for `SpecialMesh.VertexColor` > 1 ([neon guide](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408)).
* Decals and textures **don't batch**: each one adds draw calls.
* Upload hygiene: transparent pixels turn black on upload, so alpha-bleed before exporting (the realm pipeline already
  does this).

### 4.6 Transparency, overdraw and sorting (checklist)

1. Opaque or cutout wherever possible. That gives depth-tested, DOF-friendly, cheap rendering.
2. Keep screen-filling translucent layers to 2–3. Overdraw is the top mobile GPU killer
   ([improve](https://create.roblox.com/docs/performance-optimization/improve)).
3. Avoid translucent objects intersecting. Use `ZOffset` on particles and beams to force order.
4. Nothing translucent behind Glass.
5. Particles: fill-rate grows with on-screen size × count. Big, soft, overlapping sprites are the worst case.

---

## 5. Particles and FX

### 5.1 `ParticleEmitter` [V]

Parent it to a `BasePart` (spawns in the part's box or `Shape`) or an `Attachment` (spawns at a point; **Sphere and
Cylinder shapes misbehave on attachments**).

| Group | Properties (`Instance.new` defaults) | Notes |
|---|---|---|
| Emission | `Rate` 20/s, `Lifetime` 5–10 s (**max 20**), `Speed` 5, `SpreadAngle` (0,0), `EmissionDirection` Top, `Shape` Box/Sphere/Cylinder/Disc, `ShapeStyle` Volume/Surface, `ShapeInOut` Outward/Inward/InAndOut, `ShapePartial` 1 | **≤ 400 particles/s per emitter (100/s on mobile)**. `:Emit(n)` for bursts, `:Clear()`. |
| Motion | `Acceleration` (world studs/s²), `Drag` (half-life in seconds; negative accelerates), `VelocityInheritance` 0–1, `LockedToPart`, `WindAffectsDrag`, `TimeScale` 0–1 (0 freezes) | `TimeScale = 0` is a clean ReducedMotion freeze. |
| Look | `Texture`, `Color` (ColorSequence), `Size` (NumberSequence with envelopes), `Transparency`, `Squash` (stretch; rain), `Rotation`, `RotSpeed`, `Orientation`, `ZOffset` (studs toward the camera without resizing) | `Orientation`: `FacingCamera`, `FacingCameraWorldUp`, `VelocityParallel`, `VelocityPerpendicular`. |
| Light | `LightEmission` 0–1 (0 = normal blend, **1 = additive**), `LightInfluence` 0–1, `Brightness` (scales emitted light when `LightInfluence` is 0) | **`LightInfluence` defaults to 0 via `Instance.new` but 1 when inserted in Studio**, so set it explicitly. `Brightness` > 1 feeds Bloom. Particles never light the world (add a `PointLight`). |
| Flipbook | `FlipbookLayout` None/Grid2x2/4x4/8x8/**Custom** (`FlipbookSizeX/Y` 1–64), `FlipbookMode` Loop/OneShot/PingPong/**Random** (cross-fade), `FlipbookFramerate` (**≤ 30 fps**), `FlipbookStartRandom`, `FlipbookBlendFrames` | Texture size must be an exact multiple of the grid. Non-square and non-power-of-two sizes have worked since the Oct 2025 custom-layout release ([post](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128)). Leave spacing between frames for mips. |

* `FastForward` (pre-warm) is **[R]**. To avoid an empty first second, `Emit` a burst with long, randomised
  lifetimes, or enable emitters behind the loading screen.
* **Cost:** one draw call per emitter [C, staff]. "Property changes to ParticleEmitters can have a dramatic impact on
  performance" [V], so don't tween emitter properties every frame. Swap between a few pre-configured emitters instead.
* **Memory:** flipbooks cost texture memory and are **auto-disabled on low-memory clients** (old phones). Reuse one
  atlas across emitters.
* Twinkling stars: `FlipbookMode = Random` with `FlipbookStartRandom` and a low framerate, or a framerate of 0 with
  random start for a random static frame per particle (documented tricks).

### 5.2 `Beam` [V]

* It draws a texture between `Attachment0` and `Attachment1` as a **cubic Bézier**:
  P1 = A0 + `CurveSize0` × A0's **+X**, P2 = A1 − `CurveSize1` × A1's **+X**. Orient the attachments to shape arcs.
* `Segments` default 10. **You need ≥ n−1 segments to display n Color/Transparency keypoints.** `Width0`/`Width1`,
  `FaceCamera`, `ZOffset` (avoids z-fighting between stacked beams).
* `Texture`, `TextureLength`, `TextureMode` (`Wrap`/`Static`: repeats = length ÷ TextureLength; `Stretch`: repeats
  TextureLength times), **`TextureSpeed` (cycles/s, default 1; negative reverses)**, `:SetTextureOffset()` for
  scripted scrolling or sync.
* `LightEmission` (additive), `LightInfluence` (0–1), **`Brightness` 0–10000** (effective when `LightInfluence` < 1).
  Duvall Drive's lightning used `Brightness = 10` together with a Bloom spike
  ([develop a moving world](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world)).
* **LOD [C]:** the engine divides `Segments` by a quality × distance factor (about 200–1000 studs). At quality 1 a
  10-segment beam can disappear. The workaround recomputes `Segments` each frame, or you can author more segments
  ([thread](https://devforum.roblox.com/t/bypassing-forced-beam-lod/2426888),
  [bug](https://devforum.roblox.com/t/beam-optimization-is-wronglypoorly-implemented/2939171)). Community reports
  also mention a per-frame cap on Beam and Trail updates (about 64 on desktop and 16 on mobile) [C].
* **Cost:** one draw call per beam [C, staff].

### 5.3 `Trail` [V]

Two attachments sweep a ribbon. `Lifetime` 0.01–20 s (default 2), `MinLength` (0.1), `MaxLength` (0 = unlimited),
`WidthScale` (a NumberSequence over lifetime, 0–1 × attachment spacing), `TextureMode` (`Stretch` shrinks when
stopped, `Wrap` tiles relative to the attachments, `Static` stamps footprints), `FaceCamera`, `LightEmission`,
`LightInfluence`, `Brightness` 0–10000, and `:Clear()`.

### 5.4 `Highlight` [V]

* Props: `Adornee`, `DepthMode` (`AlwaysOnTop`/`Occluded`), `FillColor`, `FillTransparency` (0.5), `OutlineColor`,
  `OutlineTransparency` (0), `Enabled`. **There is no outline-thickness control.** `LineThickness` and `ReservedId`
  exist but are **[R]**.
* **Limit 255 per client.** Extra ones are silently ignored, and disabled ones still use a slot. Adding or removing a
  Highlight rebuilds geometry and can spike, while changing properties is cheap, so **re-target one Highlight via
  `Adornee`** instead of creating new ones. The first visible Highlight costs up to about 1 ms GPU on mobile, and
  mobile cost grows with screen coverage. Low-end devices render it more pixelated. Avoid nesting highlighted objects
  inside other highlighted objects.

### 5.5 Legacy and other FX

* `Fire` (`Heat`, `Size`, `Color`, `SecondaryColor`, `TimeScale`), `Smoke` (`Opacity`, `RiseVelocity`, `Size`,
  `Color`, `TimeScale`) and `Sparkles` (`SparkleColor`, `TimeScale`) are quick but hard to art-direct. They follow
  `GlobalWind`, and their `FastForward` is [R]. Prefer `ParticleEmitter` [V].
* `Explosion`: `BlastRadius`, `BlastPressure`, `DestroyJointRadiusPercent` (set 0 for a cosmetic blast),
  `ExplosionType` (`Craters`/`NoCraters`), `Visible`, `TimeScale`, and the `Hit` event [V].
* `SelectionBox` / handle adornments (`LineHandleAdornment` and similar) are thin always-on-top 3D lines, useful for
  debug or "blueprint" overlays [V].
* Community volumetric light: stacked, camera-facing gradient **Beams** with proximity fade
  ([thread](https://devforum.roblox.com/t/fake-volumetric-lighting-w-beams-proximity-transparency/2845337)). Duvall
  Drive also used beams for "volumetric lighting".

### 5.6 How to make something glow (decision table)

| Want | Use | Works on low quality or mobile? |
|---|---|---|
| Solid glowing geometry | `Neon` material (colour Value = brightness) | Yes (lower fidelity) |
| Glowing *pattern* on a mesh (runes, veins, windows) | `SurfaceAppearance` emissive mask, `EmissiveStrength` 1–5, pulse by script | **Yes, every level, no distance fade** |
| Additive soft glow sprites | ParticleEmitter or Beam: `LightEmission = 1`, `LightInfluence = 0`, `Brightness` 1.5–4 | Yes (1 draw call each) |
| Glowing text or icons in the world | SurfaceGui/BillboardGui, `LightInfluence = 0`, `AlwaysOnTop = false`, `Brightness` 1.5–5 | Yes. Draw-call heavy. Content is re-rasterised when properties change |
| Actual light on surroundings | `PointLight`/`SpotLight`/`SurfaceLight` (≤ 120 studs) | Voxel-quality on low-end |
| Outline glow around an object | `Highlight` (one, re-adorned) | Yes, pixelated. First one costs about 1 ms on mobile |

---

## 6. Materials of the "look": art direction notes from the docs

* **PBR without baked light:** albedo maps shouldn't contain shading, because the engine lights them (Duvall Drive
  repainted its scans for this reason). **Painted, pre-lit art** (like the realm) should be displayed unlit
  (sections 4.3 and 2.8), or it gets lit twice [V]/[U].
* **Trim sheets and shared SurfaceAppearance packages** (Beyond the Dark: about 90% of the station used a handful of
  swappable trim sheets) make instancing and memory scale
  ([building architecture](https://create.roblox.com/docs/resources/beyond-the-dark/building-architecture)).
* **Tint instead of re-upload:** `SurfaceAppearance.Color` gives variations at zero memory [V].

---

## 7. Camera

### 7.1 Scriptable camera essentials [V]

```lua
local RunService, TweenService = game:GetService("RunService"), game:GetService("TweenService")
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable            -- default scripts stop touching CFrame
cam.FieldOfView = 30                                   -- clamped 1..120, default 70 (vertical by default)
local vel = Vector3.zero
RunService:BindToRenderStep("RealmCam", Enum.RenderPriority.Camera.Value, function(dt)
    local pos; pos, vel = TweenService:SmoothDamp(cam.CFrame.Position, targetPos, vel, 0.35, math.huge, dt)
    cam.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))  -- straight-on for a diorama
    cam.Focus = CFrame.new(focusPoint)                 -- REQUIRED for lights/LOD near the view
end)
```

* `FieldOfViewMode`: `Vertical` (default), `Diagonal` or `MaxAxis`, which decides the axis held constant on resize
  (portrait phones!). Also `DiagonalFieldOfView` and `MaxAxisFieldOfView`. `NearPlaneZ` is read-only (−0.1 to −0.5).
* `RunService.PreRender` replaces `RenderStepped`. `BindToRenderStep` priorities: input 100, camera 200.
  `TweenService:SmoothDamp` (critically damped spring; number, Vector2, Vector3, CFrame) matches the realm's fly-to
  spec.
* Projection helpers: `Camera:WorldToViewportPoint()` places ScreenGui labels over 3D nodes;
  `ViewportPointToRay()` / `ScreenPointToRay()` + `workspace:Raycast()` pick 3D nodes from taps.
* Default-camera shake without scripting a camera: `Humanoid.CameraOffset`.
* A developer freecam exists for owners and editors (Shift+P), with cinematic post-processing presets. Use it for
  capturing trailers ([free camera](https://create.roblox.com/docs/workspace/camera/free-camera)).

### 7.2 2.5D and "orthographic-ish" setups

* **Low FOV plus a distant camera** approximates ortho (FOV 1–6 at hundreds to thousands of studs)
  ([2D trick](https://devforum.roblox.com/t/faking-true-2d-with-camera-and-lighting-tricks-example-uncopylocked-side-scrolling-place-provided/1990833)).
  **Pitfalls [C]:** on low graphics and mobile "the entire level disappears" (draw distance)
  ([request](https://devforum.roblox.com/t/orthographic-camera-projection-for-experiences-and-studio/3932266)). With
  streaming on, parts near the character may take seconds to appear
  ([thread](https://devforum.roblox.com/t/camera-rendering-issue-with-very-low-fov-and-a-far-away-camera/3296775)).
  Precision and LOD also suffer, because `RenderFidelity` `Automatic` drops mesh detail beyond 250 and 500 studs.
* **Better for a parallax diorama:** a *moderate* FOV (about 20–40°) with the whole scene inside about 30–400 studs.
  That keeps the parallax (you want it!), keeps everything inside low-quality draw distance, and keeps mesh LOD high.
* **Native orthographic camera: planned for late 2026** (not in the API as of Sept 2026).

### 7.3 Parallax: real 3D reproduces the realm's dolly law exactly

Put the world plane at distance `D` in front of a camera at zoom `z = 1`, and put layer `L` at distance `D/f_L`. The
parallax factor `f` is then the classic "distance ratio". Dolly the camera forward by `D − D/z`. Layer `L`'s screen
scale relative to z = 1 is

```
s_L = (D/f) / (D/f − D + D/z) = z / (f + (1 − f)·z)
```

which is **exactly REALM §2.3's dolly law**. Pan matches as well: the screen speed of layer L relative to the world
comes out as `f / (f + (1 − f)·z)`, the same as REALM's `f·s_L / z`. So the 8-layer realm can become 8 textured planes
with no new camera maths, and every post effect, 3D particle and light then applies. For the sky there are two
choices. Keep it as a plane at `20·D`, which is exact. Or make it a real `Sky` (f = 0), which loses the small
0.85–1.01 scale drift of f = 0.05 but becomes free to rotate. For low-quality draw distance, pick D small (for example
20 studs gives sky at 400, clouds at 167, far at 80, mid at 44, near at 29, world at 20, fg at 15 and particles at
12.5 studs) and scale plane sizes to match [U].

### 7.4 Camera shake and cinematic rigs [U]

* **Shake:** add a decaying Perlin offset *after* computing the base CFrame:
  `cf * CFrame.new(noise(t*f)*a, noise(t*f+7)*a, 0) * CFrame.Angles(0, 0, noise(t*f+13)*a*0.02)`, with `a *= 0.9^(dt*60)`.
  Trauma-squared amplitude feels best. Skip it when `GuiService.ReducedMotionEnabled` is true (**readable**, [V]).
  `UserGameSettings.ReducedMotion` is [R].
* **Rigs:** keyframe `CFrame`/FOV with `TweenService` (Sine/Quint InOut) or drive them with `SmoothDamp`. A dolly
  zoom (move in while widening FOV) sells "entering" a node. FOV punches of −4 to −8° sell impacts.
* **Letterbox or "cinematic" framing** belongs in UI (ScreenGui bars) and costs nothing in 3D.

---

## 8. Performance and scaling

### 8.1 Budgets and tools

| Metric | Budget | Source |
|---|---|---|
| Scene draw calls | ~500 for a typical mid-2024 game; ~1000 on a baseline device in the docs' example | [C, staff] / [V] ([design](https://create.roblox.com/docs/performance-optimization/design)) |
| Scene triangles | ~500k (staff); 1M (docs example) | same |
| Client memory | < 1.3 GB to support 2 GB phones | [C, staff] |
| Textures | memory depends on pixel count, not file size (1024² = 4 × 512²). Most images need ≤ 512², minor ones ≤ 256². The engine streams texture quality by memory, distance and screen size | [V] |

* **Render Stats:** Shift+F2 (Draw(Scene), Draw(Shadow), CPU/GPU ms). The higher of CPU and GPU is your bottleneck.
  **MicroProfiler:** Ctrl+F6. Scopes: `Prepare and Perform`, `Perform/Scene/computeLightingPerform`, `LightGridCPU`,
  `ShadowMapSystem`, `Perform/Scene/UpdateView` (particle updates), `Perform/Scene/RenderView` (render + post). Tag
  your own code with `debug.profilebegin/profileend` [V].
* **In-script telemetry** [V]: `Stats.FrameTime`, `RenderCPUFrameTime`, `RenderGPUFrameTime`, `SceneDrawcallCount`,
  `SceneTriangleCount`, `ShadowsDrawcallCount`, `UI2DDrawcallCount`, `InstanceCount`,
  `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture | GraphicsParticles | Gui | …)`,
  `GetTotalMemoryUsageMb()`. `GetPaginatedMemoryByTexture` is [R].

### 8.2 Draw-call accounting

| Thing | Cost |
|---|---|
| N identical MeshParts (same mesh + same SurfaceAppearance, or same texture, or same material) | **1** (instanced) [V] |
| Unique meshes or textures | 1 each (and memory). Import assets **once** and duplicate in Studio [V] |
| Each ParticleEmitter, each Beam | 1 each [C, staff] |
| Decals, Textures, transparent parts with decals | don't batch [V]/[C] |
| SurfaceGui / BillboardGui | "chew up drawcalls very quickly" [C, staff]. Cached until any descendant or property changes, then re-rendered [V] |
| Highlights | draw calls per highlighted object plus one post pass whenever any is visible [V] |
| Shadow casters | a separate shadow pass (`ShadowsDrawcallCount`) [V] |

### 8.3 What degrades with quality level

| Feature | Behaviour | Source |
|---|---|---|
| Quality scale | Manual levels 1–10 (internal `QualityLevel` enum goes to 21). `GraphicsOptimizationMode`: Performance = 1–3, Balanced = 4–7, Quality = 8–10 | [V] |
| Shadows | degrade, then **off below level 4** | [V] |
| Future/Realistic lighting | falls back toward ShadowMap and voxel on weak devices and low levels | [V]/[C] |
| Draw distance | shrinks at low levels (about 200 studs at level 1 in complex scenes). Roadmap: guarantee ≥ 500 studs | [C] / roadmap |
| Bloom / Neon | still renders at low quality, with lower fidelity | [V] (2018 announcement) |
| DOF | desktop only at ≥ 8. **Never on phones or tablets** | [V] |
| SunRays | "may not render on low-end devices" | [V] |
| Glass | refraction off on mobile | [V] |
| Beams | segments reduced with quality and distance | [C] |
| Particles and beams (general) | "simpler particles, simpler beams", water and glass shaders simplified | [C, staff] |
| Flipbooks | disabled under memory pressure | [V] |
| Emissive masks | **all levels, no distance fade** | [V] |
| Skybox orientation | all levels, low cost | [V] |
| Highlights | same look, more pixelated on low-end | [V] |
| Mesh detail | `RenderFidelity` `Automatic`: full < 250 studs, medium 250–500, lowest > 500. `Precise` forces full (costly). Set it in Studio [P] | [V] |

**Detecting capability from a script:** `UserSettings():GetService("UserGameSettings").SavedQualityLevel`
(`Automatic` or `QualityLevel1–10`; readable [V]). `Automatic` tells you nothing about the live level, which is
`GraphicsQualityLevel` [R]. Combine it with `UserInputService.TouchEnabled`, `GuiService.ViewportDisplaySize` [V] and
measured `Stats.RenderGPUFrameTime` [V].

### 8.4 Streaming and LOD

* `Workspace.StreamingEnabled` is **not settable by scripts** (Studio only), and it is on by default for new places.
  `StreamingMinRadius` (default 64) and `StreamingTargetRadius` (default 1024) are Studio-only [V].
  `StreamOutBehavior.Opportunistic` is recommended for memory.
* **Instances created or cloned by client scripts are exempt from stream-out** unless parented under a server-created
  instance. A client-built realm won't pop [V]
  ([streaming](https://create.roblox.com/docs/workspace/streaming)). `Player:RequestStreamAroundAsync()` and
  `ReplicationFocus` pre-stream a region.
* `Model.LevelOfDetail` (`SLIM`, `StreamingMesh`, `Disabled`; [P]) and `Model.ModelStreamingMode` (`Atomic`,
  `Persistent`, …). SLIM v1 is in beta (PC and Mac) [V].
* Duvall Drive kept a far-away hero object always streamed by adding hidden geometry near the player. Use this
  sparingly.

### 8.5 Memory and cost hygiene

* Pause work when hidden. With a fullscreen panel open: disable emitters and beams, pause tweens, and consider pointing
  the camera at empty space. `RunService:Set3dRenderingEnabled` is **[R]**, so you can't turn 3D off.
* Preload only what's visible (`ContentProvider:PreloadAsync`, farthest layers first).
* Mobile thermal throttling shows up after 10–15 minutes. Test long sessions
  ([test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware)).

---

## 9. Showcases: what the best-looking Roblox experiences actually do

| Experience / source | Look | How they did it (documented) |
|---|---|---|
| **Beyond the Dark** (Roblox official, Vistech showcase; [docs](https://create.roblox.com/docs/resources/beyond-the-dark)) | Hi-fi sci-fi station | Modular MeshPart kits in packages; **trim sheets** for about 90% of the architecture; shared `SurfaceAppearance` "master materials" as packages (edit once, republish everywhere); dynamic cubemap reflections on metals. |
| **The Mystery of Duvall Drive** (Roblox official; [docs](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive)) | Stormy supernatural house | **Layered, semi-transparent cloud meshes spinning at different speeds** so they intersect into living cloud forms (a client `LocalSpaceRotation` tag script); **beams** for volumetric light and lightning (random textures, `Brightness` 10, **Bloom Intensity spike**); a **particle "cloud flash"** billboard for distant lightning; rain from a grid of emitter volumes with **`Squash`**; a glowing eye built as **two spheres**, a cracked transparent shell over an inner vertex-painted neon core (made before emissive masks existed); a **rendered image on a decal** far behind the eye to fake a world beyond the clouds; per-room lighting and atmosphere presets swapped by a game-state manager; `Highlight` only on dangerous or corrupted items, because highlighting everything was "overwhelming". |
| **Future Is Bright demos** ([repo](https://roblox.github.io/future-is-bright/)) | HDR, shadowed interiors | Hybrid engine: CPU voxel skylight plus shadow maps on capable hardware; `ShadowSoftness`; exposure control. |
| **RNG and aura games (e.g. Sol's RNG)** | Screen-filling "rare roll" cutscenes | Community pattern [C]: stacked additive particles and beams around the character (beams tethered to orbiting attachments), a scriptable-camera cutscene, a ColorCorrection and Bloom flash, a background swap, and music sync ([tutorial video](https://www.youtube.com/watch?v=OtauJt3ZV-M)). The closest genre analogue to milestone unlock moments. |
| **Community tech** | Volumetrics, UI glass | Beam-stack volumetrics, DOF-glass UI blur, Highlight-rendered "liquid glass" (all high-quality or PC-only; see 3 and 5.5). |

Recurring lessons: **fake depth with layers and images, spend real geometry only where light hits it, drive drama from
HDR sources plus short Bloom and ColorCorrection spikes, and keep everything cosmetic on the client.**

---

## 10. Roadmap watch-list (as of Sept 2026)

| Item | Status | Why it matters here |
|---|---|---|
| Orthographic camera (2D/isometric) | Planned for late 2026 | A true-ortho diorama with post FX |
| 2D particles for UI surfaces | Late 2026 | Screen-space sparkles without the 3D port |
| Upgraded UI gradients (radial, conic, tiling) | Late 2026 | Glows and halos in UI |
| Minimum draw distance of 500 studs | Late 2026 | Makes deep dioramas safe on low-end |
| UI blur effect | Early 2027 | Frosted panels natively |
| PBR specular controls, material layering, terrain SDF / virtual texturing | 2027+ | Richer materials |
| Decal emissive | "Being worked on" | Glowing decals |
| UI shadows and glows (`UIShadow`) | **Shipped** 2026 | The UI-side glow primitive (see the UI knowledge file) |
| Emissive masks, 4K textures, texture streaming | **Shipped** H1 2026 | Section 4 |

Sources: [2025 recap](https://devforum.roblox.com/t/creator-roadmap-2025-end-of-year-recap/4156739),
[Spring 2026](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473),
[Fall 2026](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208).

---

## 11. API verification appendix

**Verified present and script-usable** in `globalTypes.d.luau` plus the API dump:

* Classes: `Lighting`, `Atmosphere`, `Sky`, `Clouds`, `PointLight`, `SpotLight`, `SurfaceLight`, `BloomEffect`,
  `BlurEffect`, `ColorCorrectionEffect`, `ColorGradingEffect`, `DepthOfFieldEffect`, `SunRaysEffect`,
  `SurfaceAppearance`, `MaterialVariant`, `MaterialService`, `TerrainDetail`, `Decal`, `Texture`, `ParticleEmitter`,
  `Beam`, `Trail`, `Highlight`, `Fire`, `Smoke`, `Sparkles`, `Explosion`, `Camera`, `Stats`, `UserGameSettings`,
  `SurfaceGui`, `BillboardGui`, `ViewportFrame`, `EditableImage`, `UIShadow`.
* Enums: `LightingStyle {Realistic, Soft}`, `TonemapperPreset {Default, Retro}`,
  `AlphaMode {Overlay, Transparency, TintMask, Opaque}`, `ParticleFlipbookLayout {None, Grid2x2, Grid4x4, Grid8x8, Custom}`,
  `ParticleFlipbookMode {Loop, OneShot, PingPong, Random}`,
  `ParticleOrientation {FacingCamera, FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular}`,
  `TextureMode {Stretch, Wrap, Static}`, `HighlightDepthMode {AlwaysOnTop, Occluded}`,
  `SavedQualitySetting {Automatic, QualityLevel1..10}`, `GraphicsOptimizationMode {Performance, Balanced, Quality}`,
  `FieldOfViewMode {Vertical, Diagonal, MaxAxis}`, `ResamplerMode {Default, Pixelated}`,
  `RenderFidelity {Automatic, Precise, Performance}`, `ModelLevelOfDetail {Automatic, StreamingMesh, Disabled, SLIM}`,
  `RenderPriority {First, Input, Camera, Character, Last}`, `Material.Neon/Glass/ForceField/...`.
* Methods: `ParticleEmitter:Emit/Clear`, `Beam:SetTextureOffset`, `Trail:Clear`, `TweenService:SmoothDamp`,
  `RunService:BindToRenderStep`, `RunService.PreRender`, `Camera:WorldToViewportPoint/ViewportPointToRay`,
  `Lighting:GetSunDirection`, `AssetService:CreateEditableImage/CreateSurfaceAppearanceAsync`,
  `Player:RequestStreamAroundAsync`, `Stats:GetMemoryUsageMbForTag`, `GuiService.ReducedMotionEnabled`.

**In the type dump but NOT usable by game scripts** (don't be fooled by autocomplete):

| Member | Why |
|---|---|
| `Lighting.Technology` | [R] (deprecated) |
| `Lighting.LightingStyle`, `.PrioritizeLightingQuality` | readable; write is plugin or Open Cloud only [P] |
| `Highlight.LineThickness`, `Highlight.ReservedId` | [R] (hidden; no outline width for games) |
| `SurfaceGui.HorizontalCurvature`, `SurfaceGui.Shape` (`CurvedHorizontally`) | [R] (curved SurfaceGuis are internal) |
| `RunService:Set3dRenderingEnabled` | [R] |
| `ParticleEmitter:FastForward`, `Fire:FastForward` | [R] |
| `UserGameSettings.GraphicsQualityLevel`, `.ReducedMotion`, `.MaxQualityEnabled`, `.GraphicsOptimizationMode` | [R] (use `SavedQualityLevel` and `GuiService.ReducedMotionEnabled`) |
| `Stats:GetPaginatedMemoryByTexture` | [R] |
| `CanvasGroup.ResolutionScale`, `ViewportFrame.IsMirrored` | [R] |
| `SurfaceAppearance`/`MaterialVariant` map properties | [P] (EditableImage route at creation only) |
| `MeshPart.RenderFidelity`, `Model.LevelOfDetail` | [P] |
| `Workspace.StreamingEnabled/MinRadius/TargetRadius/StreamOutBehavior`, `Terrain.Decoration/GrassLength` | not scriptable |
| `Decal.Emissive*` | [T]: script-accessible, but not live per Roblox |

---

## 12. Opportunities for Milestone Tree

Context: the realm is today an 8-plane **ScreenGui** parallax (`art/REALM.md`: sky f .05, clouds .12, far .25, mid .45,
near .7, world 1.0, fg 1.3, particles 1.6; HIGH 146.8 MB / LOW 34.2 MB textures; baked haze and blur; SmoothDamp
fly-to; ReducedMotion rules). ScreenGuis can't receive post FX, so nearly everything below starts from idea 1. Costs are
rough engineering estimates [U].

| # | Idea | Cost | Risk | Mobile / low fallback |
|---|---|---|---|---|
| 1 | **Realm3D:** port the 8 layers to textured planes in Workspace | L | M | Keep the current MapGui as the LOW tier |
| 2 | **Unlit painted planes** via emissive (or the SurfaceGui `LightInfluence` 0 path) | M | M | Same path works everywhere |
| 3 | **HDR glow system:** bloom from emissive, Neon and Brightness > 1 only | S | L | Bloom degrades gracefully; glow sprites on LOW |
| 4 | **Energy-flow Beams** as skill-tree links | M | M | Instanced neon meshes and UI lines |
| 5 | **True-depth particle fields** replace the Lua field updater | S | L | Rate × 0.5, smaller sprites |
| 6 | **Rotating cosmic Skybox** plus sun placement and SunRays through the Tree | S | L | Baked god rays remain |
| 7 | **Focus-pull DOF** on node select (PC ≥ 8), baked blur for everyone | S | L | Baked blur (already in art) |
| 8 | **Era colour grades** for NG+ tiers and the rift biome | S | L | Works everywhere |
| 9 | **Milestone-unlock cinematic** (dolly, FOV punch, bloom, shards, shake) | M | L | Drop shake and DOF |
| 10 | **Living lights** at light-falls, rift and gems | S | M | Voxel-quality light |
| 11 | **Hero 3D meshes** (Tree trunk, near rocks, ringed planet) with emissive runes | L | M | Painted sprites |
| 12 | **Volumetric light-falls and god rays** via beam stacks | S | L | Fewer beams |
| 13 | **One re-adorned Highlight** for hover and selection | S | L | Ring sprite on phones |
| 14 | **World-space glowing labels** or hybrid projected ScreenGui plates | M | M | Projected ScreenGui plates |
| 15 | **Adaptive FX governor** from `Stats` render timings | S | L | It *is* the fallback system |
| 16 | **Rift tear and portal lens** (ForceField + Glass) | S | L | No refraction on mobile |
| 17 | **Duvall-style spinning nebula discs** for the clouds layer | S | M | Static tile |
| 18 | **Cosmic day cycle and "dawn of a new run"** exposure ramp | S | L | Works everywhere |
| 19 | **Idle-when-covered** 3D budget | S | L | – |
| 20 | **Client-built, stream-proof realm** | S | L | – |

### Details

**1. Realm3D (the enabling move).** Build the realm as anchored planes (a single flat MeshPart asset, so all tiles
instance) at `d_L = D/f` in front of a Scriptable camera at FOV about 30°. Section 7.3 proves REALM's dolly law is
unchanged, so `camera.js` maths ports directly: zoom z maps to camera distance `D/z`, and pan maps to camera X/Y. The
sky becomes a `Sky`, and the tiles map 1:1 to planes, with gutters handled by `Decal.UVOffset/UVScale` or baked mesh
UVs. Input: `ViewportPointToRay` + `Raycast` against invisible node hit-spheres, or keep ScreenGui hit targets at
projected positions. **Cost** L: a Map module rewrite plus colour calibration. **Risk:** colour fidelity versus the
painted look (idea 2), texture memory (the same tiles; no SurfaceGui canvases), and the node input remap. **Fallback:**
the existing ScreenGui realm stays as the LOW tier, since it is already built and memory-budgeted.

**2. Unlit painted planes.** Pick one path after a colour-card test. (a) A `SurfaceAppearance` with a shared white
emissive mask, `EmissiveStrength` 1, and the realm's own local Lighting nearly black. By the documented formula,
output ≈ ColorMap, and `EmissiveTint` then gives a **free per-layer biome tint** (violet to crimson) and
`EmissiveStrength` > 1 gives **HDR for light-falls, sun and rift** layers. (b) The fullbright Lighting setup (2.8)
with plain `TextureContent`. (c) A `SurfaceGui` with ImageLabel tiles, `LightInfluence` 0 and `Brightness` 1: exact
colours and trivial HDR, but canvas memory and draw calls. **Risk:** the tonemapper curve shifts colours. Correct it
with a `ColorCorrectionEffect` or pre-compensate in the painter pass.

**3. HDR glow system.** Set `BloomEffect.Threshold` to about 1.05, so painted art never blooms, and make only HDR
sources glow: gem cores (Neon, or emissive `EmissiveStrength` 2–4), READY rings (a pulse on `EmissiveStrength`, which
is runtime-writable and cheap), beams and particles with `Brightness` 2–4, and the rift. It replaces most `glow_circle`
sprites with physically coherent bloom that also bleeds over neighbouring art. **Mobile:** bloom still renders at low
quality. Keep the sprite glows for the LOW (2D) tier.

**4. Energy-flow Beams as links.** Each unlocked link is a Beam with a streak texture, `TextureSpeed` 0.4–1.2 (flow
toward the child node), `LightEmission` 1, `LightInfluence` 0, `Brightness` 2, `Width0` > `Width1`, and a gentle
`CurveSize` arc from rotated attachments. Unlocking animates a `Transparency` NumberSequence wipe (Segments ≥ keypoints
− 1), and "flow sparks on the incoming edge" become a second, faster beam. **Budget:** each beam is one draw call and
is LOD'd, so show Beams only for visible links near focus and the READY path. Render every other link as **one
instanced neon capsule mesh**, which costs one draw call for all of them. **Risk:** beam segment LOD at quality 1
(author 20+ segments or keep links straight).

**5. True-depth particle fields.** Replace the Lua-updated sprite fields (`motesFar`, `motesNear`, `particles`, about
360 particles × 4 cell copies per frame) with a few box-shaped `ParticleEmitter` volumes placed at their real depths.
Parallax, depth order and DOF come free, and the Lua per-frame cost drops to zero. Use `LightEmission` 1,
`LightInfluence` 0, `Brightness` 1.5–3 (so they catch bloom), a shared 4×4 twinkle flipbook with `FlipbookMode.Random`
and `FlipbookStartRandom`, and `Drag` 1 + `WindAffectsDrag` + scripted `GlobalWind` gusts for drift. ReducedMotion:
`TimeScale = 0` or `Enabled = false`. **Mobile:** 100/s cap, halve `Rate`, keep `Size` small (fill-rate).

**6. Rotating cosmic Skybox, sun and SunRays.** Paint the sky layer into six seamless cube faces (nebula, stars, cosmic
sun), set `CelestialBodiesShown = false`, and drift `SkyboxOrientation.Y` about 0.1°/s, which is "low-cost… all
platforms and quality levels". Optionally keep a real sun (`SunTextureId`, `SunAngularSize`) positioned via
`ClockTime` and `GeographicLatitude` behind the Tree's crown, with `SunRaysEffect` (Intensity 0.05–0.12,
Spread 0.5) streaming *through the branches*. **Fallback:** SunRays may not render on low-end, and the baked god rays in
the clouds art remain.

**7. Focus-pull DOF.** When a node is selected, tween `DepthOfFieldEffect.FocusDistance` to the node's camera
distance, with `InFocusRadius` about 3 and `FarIntensity` 0.3 → 0.6. It is cinematic "tilt-shift" focus on a PC at
quality ≥ 8. **Everyone else:** the baked blur (fg 10, near 2.5 local px) already provides static depth, and a
Camera-parented `BlurEffect` (Size 6–10) is a good "panel open" backdrop on all devices, because UI stays crisp.

**8. Era colour grades.** Each NG+ era or prestige tier gets a `ColorCorrectionEffect` preset (`TintColor`,
`Saturation`, `Contrast`), cross-faded over about 1.5 s. The rift biome blends a second composing ColorCorrection by
camera X (the same weights as REALM §5). `ColorGradingEffect.Retro` works as a "memory / past run" flashback. Cost is
negligible on every device.

**9. Milestone-unlock cinematic (1–1.5 s).** Sequence: SmoothDamp dolly toward the node with a FOV punch of −6° →
Bloom `Intensity` 0.9 → 2.5 → 0.9 and a ColorCorrection `Brightness` +0.25 flash (both on the Camera) →
`ParticleEmitter:Emit(40)` shard burst plus a lightning Beam (random texture, `Brightness` 10, Duvall-style) → decaying
Perlin shake → the link beams light up in sequence. Gate shake, dolly and flashes on
`GuiService.ReducedMotionEnabled`. This is the genre's "RNG aura" moment, done with engine glow instead of UI sprites.

**10. Living lights.** Add a handful (≤ 6–8) of shadowless `PointLight`s (Range ≤ 120) at light-falls, the rift and
the shrine, each flickering via `Brightness`. They only matter if some layers or props are lit 3D (ideas 11 and 16). The
painted, unlit planes won't react. Update `Camera.Focus` every frame, or lights can drop out. **Risk:** voxel-quality
light on low-end.

**11. Hero 3D meshes.** Move 2–4 signature elements into real meshes with PBR and **emissive rune masks**: the Tree's
trunk and roots, a near floating rock, the ringed planet, and the prestige shrine. Rotate them slowly
(`LocalSpaceRotation`-style client tag). They get real specular glints (`EnvironmentSpecularScale` 1), catch local
lights, and parallax perfectly. **Cost** L (art pipeline). **Fallback:** the existing painted sprites.

**12. Volumetric light-falls and god rays.** Stacks of 3–5 `FaceCamera` Beams with vertical gradient transparency,
`LightEmission` 1, slow `TextureSpeed` and a fade with camera proximity (the Duvall and community technique). Pair
them with the sun rays in idea 6. One draw call each.

**13. One Highlight, re-adorned.** For hover and selection, a single `Highlight` (`DepthMode.AlwaysOnTop`,
`OutlineColor` in the accent, `FillTransparency` 0.85) whose `Adornee` moves between nodes. Changing properties is
cheap and adding Highlights is not. On phones the first Highlight costs up to about 1 ms. Keep the ring sprite on LOW.

**14. Glowing labels.** For node plates, choose between (a) a `BillboardGui` per *nearby* node with `AlwaysOnTop`
false, `LightInfluence` 0 and `Brightness` 1.3–2, so titles pick up bloom and DOF like in-world signage; or (b) crisp
ScreenGui plates positioned each frame with `WorldToViewportPoint` (no post FX, perfect text, cheap). Recommendation:
(b) for readability, and (a) only for a few hero labels. Every property write re-rasterises a 3D GUI, so don't tween
Brightness every frame. Pulse an emissive or beam behind it instead.

**15. Adaptive FX governor.** Every 2 s, read `Stats.RenderGPUFrameTime`, `FrameTime` and `SceneDrawcallCount`
(readable [V]) and step an FX tier with hysteresis. Tier down in this order: particle `Rate` × 0.5 → SunRays off → DOF
off → secondary beams off → nebula discs static → the 2D realm. Seed the tier from `SavedQualityLevel`
(≤ 3 → LOW, as REALM §9.5 already does). Keep scene draw calls under about 300 so UI and the rest of the game have
headroom.

**16. Rift tear and portal lens.** The crimson Multiverse rift becomes a MeshPart with the `ForceField` material and a
high-contrast noise `TextureID`, giving an animated shimmer for free. The portal gets a `Glass` sphere "lens" that
refracts the realm behind it on PC. Mobile shows a transparent orb, and nothing translucent may sit behind the Glass.

**17. Spinning nebula discs.** For the clouds layer, 2–3 large semi-transparent textured discs rotating at different
speeds and intersecting (Duvall Drive's cloud vortex) make the far nebula visibly *alive*. **Risk:** overdraw. Keep them
to 2–3 and use cutout alpha where the art allows.

**18. Cosmic day cycle and "dawn of a new run".** On NG+ reset, ramp `ExposureCompensation` −2 → 0 over 3 s while
`OutdoorAmbient` and the grade warm up, like a universe re-igniting. An idle slow `ClockTime` or `SkyboxOrientation`
drift keeps the home screen moving even when the player is idle (it is an incremental, and people leave it open).

**19. Idle-when-covered.** When a fullscreen panel covers the realm, disable emitters and beams, pause tweens, and aim
the camera at empty space. That gives near-zero draw calls, because `Set3dRenderingEnabled` is [R]. It mirrors
REALM §9.7's `MapGui.Enabled = false` rule for the 3D path.

**20. Client-built, stream-proof realm.** Clone the realm from `ReplicatedStorage` in a LocalScript. Client-created
instances are exempt from stream-out, so the realm never pops. Place it far from any character spawn, give it its own
local Lighting and effects preset, and restore the defaults when the player leaves the home screen. If the game has no
large 3D world, turning `StreamingEnabled` off in Studio is also fine.

**Suggested order:** 20 → 1 (+2) as a vertical slice with one layer and the world plane → 3 → 5 → 4 → 15, then the
polish items (6, 7, 8, 9, 12, 13) → the expensive ones (11, 17).

---

## Sources

Official docs (creator-docs snapshot 2026-09-25):
[Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting) ·
[Global lighting](https://create.roblox.com/docs/environment/lighting) ·
[Light sources](https://create.roblox.com/docs/effects/light-sources) ·
[Post-processing](https://create.roblox.com/docs/environment/post-processing-effects) ·
[PostEffect](https://create.roblox.com/docs/reference/engine/classes/PostEffect) ·
[Atmosphere](https://create.roblox.com/docs/environment/atmosphere) ·
[Skybox](https://create.roblox.com/docs/environment/skybox) ·
[Clouds](https://create.roblox.com/docs/environment/clouds) ·
[Global wind](https://create.roblox.com/docs/environment/global-wind) ·
[Terrain](https://create.roblox.com/docs/parts/terrain) ·
[Materials](https://create.roblox.com/docs/parts/materials) ·
[Enum.Material](https://create.roblox.com/docs/reference/engine/enums/Material) ·
[PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) ·
[SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance) ·
[MaterialVariant](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant) ·
[Decal](https://create.roblox.com/docs/reference/engine/classes/Decal) ·
[Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) ·
[ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) ·
[Beams](https://create.roblox.com/docs/effects/beams) ·
[Trails](https://create.roblox.com/docs/effects/trails) ·
[Highlighting](https://create.roblox.com/docs/effects/highlighting) ·
[Camera guide](https://create.roblox.com/docs/workspace/camera) ·
[Camera class](https://create.roblox.com/docs/reference/engine/classes/Camera) ·
[Free camera](https://create.roblox.com/docs/workspace/camera/free-camera) ·
[SurfaceGui](https://create.roblox.com/docs/reference/engine/classes/SurfaceGui) ·
[BillboardGui](https://create.roblox.com/docs/reference/engine/classes/BillboardGui) ·
[ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame) ·
[EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage) ·
[Improve performance](https://create.roblox.com/docs/performance-optimization/improve) ·
[Design for performance](https://create.roblox.com/docs/performance-optimization/design) ·
[Test on hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware) ·
[Streaming](https://create.roblox.com/docs/workspace/streaming) ·
[Stats](https://create.roblox.com/docs/reference/engine/classes/Stats) ·
[UserGameSettings](https://create.roblox.com/docs/reference/engine/classes/UserGameSettings) ·
[Selfie Mode (DOF on mobile)](https://create.roblox.com/docs/resources/modules/selfie-mode) ·
[Beyond the Dark](https://create.roblox.com/docs/resources/beyond-the-dark) ·
[Duvall Drive: moving world](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world) ·
[creator-docs repo](https://github.com/Roblox/creator-docs)

DevForum announcements (Roblox staff):
[Unified Lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512) ·
[Light range 120](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367) ·
[Future on Android](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808) ·
[Emissive masks beta](https://devforum.roblox.com/t/studio-beta-emissive-masks/4034414) ·
[Emissive masks live](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705) ·
[Highlights 255](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534) ·
[Custom flipbooks](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128) ·
[3D GUI Brightness](https://devforum.roblox.com/t/new-brightness-property-for-3d-guis/1283855) ·
[Unified Neon and Bloom](https://devforum.roblox.com/t/unified-neon-and-bloom-poll/180359) ·
[Real World Optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146) ·
[Roadmap 2025 recap](https://devforum.roblox.com/t/creator-roadmap-2025-end-of-year-recap/4156739) ·
[Roadmap Spring 2026](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473) ·
[Roadmap Fall 2026](https://devforum.roblox.com/t/creator-roadmap-2026-fall-update/4880208) ·
[Future Is Bright](https://roblox.github.io/future-is-bright/)

Community (tag [C]):
[Lighting modes](https://devforum.roblox.com/t/roblox-lighting-modes-what-do-i-use-for-my-game/1687174) ·
[Lighting flicker](https://devforum.roblox.com/t/please-fix-roblox-lighting-flicker-prioritizelightingquality-is-enabled/4239728) ·
[Neon shader guide](https://devforum.roblox.com/t/everything-about-neon-shader-in-roblox/4053408) ·
[Bloom threshold](https://devforum.roblox.com/t/im-trying-to-decrease-blooming-threshold-to-make-neon-parts-brighter-but-it-ends-up-making-other-parts-glow-too-that-shouldnt-glow/1789215) ·
[Billboard blur (staff reply)](https://devforum.roblox.com/t/option-for-bluring-billboardguis-when-blureffect-is-enabled/2272221) ·
[DOF UI blur](https://devforum.roblox.com/t/blurred-uis-using-depth-of-field-effect/4734313) ·
[Liquid glass](https://devforum.roblox.com/t/%F0%9F%9B%A0%EF%B8%8Fliquid-glass-ui-blur-is-a-thing-of-the-past%F0%9F%9B%A0%EF%B8%8F/4416219) ·
[Beam LOD bypass](https://devforum.roblox.com/t/bypassing-forced-beam-lod/2426888) ·
[Beam LOD bug](https://devforum.roblox.com/t/beam-optimization-is-wronglypoorly-implemented/2939171) ·
[Fake 2D](https://devforum.roblox.com/t/faking-true-2d-with-camera-and-lighting-tricks-example-uncopylocked-side-scrolling-place-provided/1990833) ·
[Ortho request](https://devforum.roblox.com/t/orthographic-camera-projection-for-experiences-and-studio/3932266) ·
[Low FOV streaming](https://devforum.roblox.com/t/camera-rendering-issue-with-very-low-fov-and-a-far-away-camera/3296775) ·
[Low-level render distance](https://devforum.roblox.com/t/improve-or-prioritize-render-distance-at-low-graphics-levels/3596299) ·
[Beam volumetrics](https://devforum.roblox.com/t/fake-volumetric-lighting-w-beams-proximity-transparency/2845337) ·
[Decal emissive request](https://devforum.roblox.com/t/decal-texture-emissive-maps/4743835) ·
[Sol's RNG aura VFX tutorial](https://www.youtube.com/watch?v=OtauJt3ZV-M)

Data: [Full API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker) (security levels) ·
[rbx-dom reflection DB](https://github.com/rojo-rbx/rbx-dom) (`Instance.new` defaults) · local
`scratchpad/tools/globalTypes.d.luau` (names).
