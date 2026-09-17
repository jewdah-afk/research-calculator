# Roblox Rendering, Lighting, and Materials — A Premium Look Without Shader Access

> **Mastery-level internal knowledge base, chapter 23.**
> Roblox exposes **no custom shader authoring**. There is no HLSL/GLSL entry point, no
> material graph, no compute, no render-target you can write a fragment program against.
> Everything you see in a Roblox experience is produced by a fixed set of engine systems
> whose *parameters* you control. The craft is therefore not "write a shader" — it is
> **knowing every lever the engine gives you, what each costs, and how to combine them
> so the result reads as deliberate art direction rather than default Roblox.**
>
> Every API claim below is checked against Roblox's own documentation source
> (`github.com/Roblox/creator-docs`) and, where security levels or exact members matter,
> against the live client API dump (`MaximumADHD/Roblox-Client-Tracker/API-Dump.json`).
> Claims that could not be verified against a primary source are marked `[UNVERIFIED]`.
> Claims sourced from community practice are marked `[COMMUNITY, SECOND-HAND]`.

---

## TL;DR

- **`Lighting.Technology` is the single highest-leverage property in the engine.** `Future` gives per-light shadow maps and specular highlights from local lights; `ShadowMap` gives crisp sun shadows only; `Voxel` is the 4×4×4-stud voxel-grid legacy path; `Legacy` is deprecated and should never ship. Choose `Future` for anything that wants to look premium and can afford it, `ShadowMap` for mid-range, `Voxel` for mobile-first.
- **`Atmosphere` is the fastest route to a professional look**, full stop. A single `Atmosphere` instance with tuned `Density`, `Haze`, `Glare`, and a `Color`/`Decay` pair gives aerial perspective — the depth cue that distinguishes a real-looking scene from a flat one — for almost no cost. It is the highest ratio of visual payoff to effort in Roblox.
- **`EnvironmentDiffuseScale` / `EnvironmentSpecularScale` are the "PBR on/off" switches most people never touch.** They control how much of the sky/ambient environment contributes diffuse and specular lighting. Setting them to 0 makes everything look like 2015 Roblox; tuning them is what makes metal read as metal.
- **`SurfaceAppearance` and `MaterialVariant` DO have `Content`-typed map slots that accept an `EditableImage`** — `ColorMapContent`, `NormalMapContent`, `MetalnessMapContent`, `RoughnessMapContent`, `EmissiveMaskContent`. **But every one of them is `PluginSecurity` on write.** They are usable from a Studio plugin, not from a runtime game script. Runtime EditableImage texturing must instead go through `MeshPart.TextureContent`, `Decal.TextureContent`, `Texture.TextureContent`, `ImageLabel.ImageContent`, `Beam.TextureContent`, `Trail.TextureContent`, `ParticleEmitter.TextureContent`, and `Sky.Skybox*Content` — all of which are `Read: None / Write: None`. Details and the full table in §4.
- **Post-processing is four instances and a pile of taste.** `BloomEffect`, `ColorCorrectionEffect`, `DepthOfFieldEffect`, `SunRaysEffect`, `BlurEffect`. The amateur signature is bloom with `Threshold` near 0 and `Intensity` above 1; the professional signature is `Threshold ≈ 1.5–2.0`, `Intensity ≈ 0.3–0.7`, and a `ColorCorrectionEffect` doing a real grade.
- **`Beam` and `Trail` are the engine's general-purpose textured-quad primitives**, not just VFX toys. A `Beam` is a cubic Bézier ribbon with per-segment width, color gradient, transparency gradient and a scrolling texture — that covers lasers, god rays, water surfaces, energy fields, magic circles and cheap volumetrics. The Bézier control points are derived from the two attachment positions and `CurveSize0`/`CurveSize1` along each attachment's local `+X`.
- **Flipbook particles are Roblox's closest thing to an animated shader.** `ParticleEmitter.FlipbookLayout` (`Grid2x2`/`4x4`/`8x8`) + `FlipbookMode` + `FlipbookFramerate` turn a sprite sheet into a played-back animation per particle — smoke, fire, explosions, dissolve effects.
- **What breaks batching:** different materials, different colors on non-instanced geometry, different textures, `SurfaceAppearance`, transparency, and per-part unique meshes. Identical `MeshPart`s sharing the same `MeshId` **and** the same `SurfaceAppearance`/`TextureID` are the only reliable instancing win.
- **Transparency is the expensive one.** Transparent surfaces cannot z-reject, must be sorted, and overdraw multiplies fill cost. Long stacks of layered transparent geometry are the #1 cause of "looks great on my PC, 12fps on a phone".
- **Texture memory math: `bytes ≈ width × height × 4 × 1.333`** (RGBA8 plus the mip chain), before platform compression. A 1024×1024 texture is ~5.6 MB uncompressed-equivalent. Mobile budgets are small enough that resolution discipline — 256/512 for most props, 1024 reserved for hero assets — is a hard requirement, not a nicety.
- **`StudsPerTile` on `MaterialVariant` and `StudsPerTileU/V` on `Texture` are your UV-scale knob** in a world with no shader-side UV math. Offset-scrolling a `Texture`'s `OffsetStudsU/V` per frame is the standard "scrolling shader" substitute (water, conveyor belts, lava).
- **`RenderFidelity` is per-`MeshPart` LOD control**: `Automatic` (distance-based), `Precise` (always full detail), `Performance` (always reduced). Mass-setting everything to `Precise` is a common and expensive mistake.
- **The default-Roblox look comes from three things**: `Technology = Voxel`, no `Atmosphere`, and unconstrained saturated `BrickColor` palettes. Fixing those three moves a project further than any amount of asset work.
- **Art direction beats technology.** The best-looking Roblox experiences win on palette discipline, value contrast and silhouette readability — not on having more effects enabled. A tight 5–7 hue palette with controlled value range reads as "premium" even at `Voxel` quality.

---

## 1. Lighting technologies and the `Lighting` service

### 1.1 The four (six) technologies

`Lighting.Technology` is an `Enum.Technology`. Critically, **it is non-scriptable** —
the docs state plainly: *"This property is non-scriptable and only modifiable in Studio."*
You set it once, in the Properties panel, and it is baked into the place. There is no
runtime A/B switch between Voxel and Future.

| Value | Enum value | Status | What it does |
|---|---|---|---|
| `Legacy` | 0 | **Deprecated**, cannot be selected in Studio | The original pre-2015 flat lighting model. |
| `Voxel` | 1 | Supported | *"Uses a 4×4×4 voxel map for light and shadow calculation."* |
| `Compatibility` | 2 | **Deprecated**, cannot be selected in Studio | Simulated the removed legacy technology. The docs' migration advice: *"To achieve a similar look, use `Voxel` Lighting and add a `ColorGradingEffect` post-processing effect set to the `Retro` preset."* |
| `ShadowMap` | 3 | Supported | *"Features shadow mapping that produces more realistic and crisp shadows from sunlight or directional light sources."* |
| `Future` | 4 | Supported | *"Features the most advanced technology for high-fidelity lighting and shadows."* |
| `Unified` | 5 | **Deprecated**, cannot be selected in Studio | An experimental unified-lighting path that never shipped publicly. |

Source: `reference/engine/enums/Technology.yaml`.

**In practice, you have three choices: `Voxel`, `ShadowMap`, `Future`.**

### 1.2 What each one actually buys you

**`Voxel`** — the world is diced into 4×4×4-stud lighting voxels. Sun occlusion and local
light contribution are accumulated into this grid. Consequences that matter:

- **Shadows are chunky and soft by nature.** The `GlobalShadows` doc is explicit:
  *"Shadows are calculated using a voxel system and each lighting voxel is 4×4×4 studs.
  This means objects need to be larger than 4×4×4 studs to display a realistic shadow."*
  A fence post, a chair leg, a thin railing — none of these cast a meaningful shadow under `Voxel`.
- **Local lights do not cast shadows at all.** A `PointLight` inside a closed box lights
  the outside of the box too, because the voxel grid is coarse and there is no per-light
  shadow pass.
- **It is cheap and it scales to every device Roblox runs on.** This is why it is the default.
- `ShadowSoftness` has **no effect** — the docs say it *"only works when `Technology` mode is
  `ShadowMap` or `Future`."*

**`ShadowMap`** — adds a real shadow-map pass for the **directional light only** (sun/moon).
You get crisp, correctly-shaped sun shadows from arbitrarily thin geometry. Local lights
(`PointLight`, `SpotLight`, `SurfaceLight`) still do **not** cast shadows and still use the
voxel path for their contribution. `ShadowSoftness` becomes live (PCF-style blur radius on
the sun shadow). This is the sweet spot for "looks modern, runs everywhere" outdoor games.

**`Future`** — the full path. Every local light can cast its own shadow, local lights produce
specular highlights, and the shading model is materially closer to real PBR. The visual
difference is not subtle: under `Voxel`/`ShadowMap` a lamp is a glowing blob that brightens
a region; under `Future` a lamp is a light source that throws a shaped pool of light with a
shadow behind every object in it, and puts a specular hotspot on nearby metal.

**Cost ordering is `Voxel` < `ShadowMap` < `Future`, and the gap between `ShadowMap` and
`Future` is dominated by the number of *shadow-casting local lights in view*.** Each such
light is effectively another render pass over the geometry it touches. A corridor with
forty shadow-casting `PointLight`s is a frame-rate catastrophe; the same corridor with four
shadow-casting lights and thirty-six with `Shadows = false` is fine. **`Light.Shadows` is
the throttle you must use.** `[COMMUNITY, SECOND-HAND — the per-light pass cost model is
widely reported by Roblox developers and matches standard forward-shadow-map behaviour;
Roblox does not publish an exact per-light cost figure.]`

### 1.3 The newer axis: `LightingStyle` + `PrioritizeLightingQuality`

This is the part most older guides get wrong. Roblox's own enum documentation now says:

> *"Note that `Lighting.Technology` has been superseded by `Lighting.LightingStyle` which
> determines the artistic intent behind lighting, and `Lighting.PrioritizeLightingQuality`
> which indicates whether you prefer lighting/shading quality or view distance to scale down
> first."*
> — `reference/engine/enums/Technology.yaml`

`Enum.LightingStyle`:

| Value | Meaning (verbatim) |
|---|---|
| `Realistic` (0) | *"The most advanced and realistic lighting and shadows Roblox can deliver."* |
| `Soft` (1) | *"A flat, retro-Roblox look with softer lights and shadows."* |

`Lighting.PrioritizeLightingQuality` (boolean):

> *"Indicates whether you prefer lighting/shading quality or view distance to scale down
> first. As the rendering quality level reduces, a setting of `true` prioritizes features
> such as advanced shadows and high-quality shaders at closer distances, while a setting of
> `false` prioritizes view distance."*

And critically, from the `LightingStyle` property description:

> *"The actual shadowing path also depends on `PrioritizeLightingQuality` (for example, Soft
> with that property enabled uses shadow maps rather than voxel lighting)."*

**The mental model has shifted.** You no longer pick a fixed technology tier and hope it
runs. You declare *intent* (`Realistic` vs `Soft`) and a *degradation preference*
(`PrioritizeLightingQuality`), and the engine selects the shadowing path per device.
Legacy `Technology` values still exist and still work for places authored against them; new
work should be expressed in `LightingStyle` terms.

- Stylized / illustrated / mobile-first project → `LightingStyle = Soft`.
- Realism, horror, showcase, architectural → `LightingStyle = Realistic`.
- Close-quarters game where shadow detail is the point (horror, stealth, interiors) →
  `PrioritizeLightingQuality = true`.
- Open-world game where seeing far matters more than crisp shadows (racing, survival,
  flight) → `PrioritizeLightingQuality = false`.

### 1.4 Every `Lighting` property that matters

All summaries and descriptions below are quoted or paraphrased from
`reference/engine/classes/Lighting.yaml`.

**`Ambient : Color3`** — *"The lighting hue applied to areas that are occluded from the sky,
such as indoor areas."* Defaults to `[0,0,0]`. This is your **shadow colour**. The single
most effective "stop looking like default Roblox" move is to set `Ambient` to a desaturated
*complement* of your sun colour — a warm sun with a cool blue-grey `Ambient` is the classic
outdoor read.

There is a clamping rule people trip over: *"The effective `OutdoorAmbient` value is clamped
to be greater than or equal to `Ambient` in all channels."* So if you raise `Ambient` past
`OutdoorAmbient` in any channel, `Ambient`'s hue starts leaking into outdoor areas too.
Keep `Ambient ≤ OutdoorAmbient` channel-wise unless you want that.

**`OutdoorAmbient : Color3`** — *"The lighting hue applied to outdoor areas."* Defaults to
`[127,127,127]`. This is your **skylight fill**. It is the ambient term applied where the
sky is visible.

**`GlobalShadows : boolean`** — *"Toggles voxel-based dynamic lighting in the place."*
Two things to internalise:
1. When `false`, *"there is no distinction between areas occluded from the sky and
   non-occluded areas. In this case, `OutdoorAmbient` will be ignored and the hue from the
   `Ambient` property will be applied everywhere."* That is: **turning off `GlobalShadows`
   also disables `OutdoorAmbient`**, which surprises people who expected only shadows to go.
2. *"Shadows are also recalculated when `BaseParts` are moving."* Large amounts of moving
   geometry is a lighting-update cost, not just a physics cost.

**`Brightness : float`** — *"The intensity of illumination in the place."* Scales the sun/moon
contribution. Typical range 1–3 for natural daylight; 0–0.5 for night/horror. Note the doc's
warning that `Ambient`/`OutdoorAmbient` also affect apparent brightness, so there are three
knobs fighting over the same perceptual quantity. Discipline: set `Brightness` for the *sun*,
`OutdoorAmbient` for the *sky fill*, `Ambient` for the *shadow floor*, and never use one to
compensate for another.

**`EnvironmentDiffuseScale : float`** — *"Ambient light that is derived from the environment
with a default of `0`. This property is similar to `Ambient` and `OutdoorAmbient` but it's
**dynamic and can change according to the sky and time of day**. When this property is
increased, it's recommended to decrease `Ambient` and `OutdoorAmbient` accordingly."*

**`EnvironmentSpecularScale : float`** — *"Specular light derived from environment with a
default of `0`. This property will make smooth objects reflect the environment and it is
**especially important to make metal look more realistic**."*

**These two default to 0 and that default is the reason most Roblox places look flat.**
With `EnvironmentSpecularScale = 0`, a `Metal` part or a `SurfaceAppearance` with
`MetalnessMap` white has nothing to reflect and renders as a dull grey. Turning it up is
what makes PBR content pay off. Standard outdoor starting point: both at `0.5`–`1.0`, with
`OutdoorAmbient` pulled down (e.g. to `[70,70,80]`) to compensate, exactly as the docs advise.

**`ExposureCompensation : float`** — *"Determines the exposure compensation amount which
applies a bias to the exposure level of the scene prior to the tonemap step. Defaults to `0`
(no exposure compensation) and has a range from `-5` to `5`. A value of `1` indicates twice
as much exposure and `-1` means half as much exposure."*

This is a **stop-based** control (each ±1 is a doubling/halving) applied *before* tonemapping,
which is the important distinction from `ColorCorrectionEffect.Brightness` (applied after).
Use `ExposureCompensation` to set the overall exposure of the scene, and `ColorCorrection`
to grade what survives the tonemapper. Negative values (−0.5 to −1.5) plus high `Brightness`
give you rich, contrasty, filmic highlights instead of blown-out white.

**`ShadowSoftness : float`** — *"Controls how blurry the shadows are with a default of `0.2`.
This property only works when `Technology` mode is `ShadowMap` or `Future` and the device is
capable of rendering shadow maps."* Low values (0–0.1) read as harsh noon/desert/horror;
high values (0.5–1.0) read as overcast, soft, stylized. It is a cheap, high-impact mood knob.

**`ClockTime : float`** and **`TimeOfDay : string`** — two views of the same value.
`ClockTime` is hours as a float (`14.5` = 14:30); `TimeOfDay` is a `"HH:MM:SS"` string.
`SetMinutesAfterMidnight(n)` sets both. `GetMinutesAfterMidnight()` reads it back.
Note: *"this property does not correspond with the actual time of day and will not change
during gameplay unless it has been changed by a script"* — Roblox has no automatic day cycle;
you write one.

**`GeographicLatitude : float`** — *"The geographic latitude, in degrees, of the scene,
influencing the result of `Lighting` time on the position of the sun and moon. When
calculating the position of the sun, the earth's tilt is also taken into account."*

This is the property that controls **sun elevation arc**, and it is wildly under-used.
At latitude 0, the sun passes near-vertically overhead at noon (harsh top-down light, short
shadows, tropical read). At high latitude (±60–70), the sun tracks low across the sky even at
noon, giving permanently long raking shadows — the "golden hour all day" look that flatters
architecture and terrain. **Setting `GeographicLatitude` to a high value is the cheapest way
to get cinematic shadow length without touching `ClockTime`.**

**Reading the actual sun direction:** `Lighting:GetSunDirection()` returns a `Vector3`
(unit direction *toward* the sun) and `Lighting:GetMoonDirection()` the analogue.
`Lighting:GetMoonPhase()` returns the current phase. Use `GetSunDirection()` when you need
gameplay or VFX to agree with the lighting — e.g. orienting a `SunRaysEffect`-adjacent
`Beam`, deciding whether a point is in sun, or driving a "vampire burns in daylight" system:

```lua
local Lighting = game:GetService("Lighting")
local sunDir = Lighting:GetSunDirection()          -- unit Vector3 toward the sun
local isDaytime = sunDir.Y > 0                      -- sun above the horizon
local ray = workspace:Raycast(part.Position, sunDir * 2000, params)
local inDirectSun = isDaytime and ray == nil
```

**`ColorShift_Top` / `ColorShift_Bottom : Color3`** — legacy-era tints applied to surfaces
facing toward / away from the sun. The docs themselves note that *"the influence of
`ColorShift_Bottom` can be very hard to identify when `GlobalShadows` is enabled (default)."*
Treat these as vestigial. Do not build a look on them.

**`FogColor` / `FogStart` / `FogEnd`** — the pre-`Atmosphere` fog model. Linear distance fog:
fully clear at `FogStart`, fully `FogColor` at `FogEnd`. **`Atmosphere` supersedes this for
almost every purpose** (see §2). Legacy fog is still useful for one thing: a hard, controllable
draw-distance cutoff that hides streaming pop-in, since `FogEnd` is an exact stud distance
whereas `Atmosphere.Density` is a physically-motivated falloff. To disable legacy fog when
using `Atmosphere`, set `FogEnd` to a very large number (e.g. `100000`).

**`ShadowColor : Color3`** — the docs say: *"This is supposed to change the color of player
shadows, but currently doesn't do anything."* Ignore it.

**`Outlines : boolean`** — the old part-outline toggle. Deprecated look; leave off.

**`ExtendLightRangeTo120 : RolloutState`** — *"Unused. Light `Range` is always clamped to
120 studs."* This is a useful hard fact: **no `PointLight`/`SpotLight`/`SurfaceLight` can
exceed 120 studs of range**, regardless of what you type.

**`LightingChanged` event** — *"fires when a `Lighting` property is changed or a `Sky` is
added or removed from `Lighting`."* Useful for driving dependent systems (e.g. recolouring
UI to match time of day) without polling.

### 1.5 Local lights: `PointLight`, `SpotLight`, `SurfaceLight`

All three inherit from `Light`, which provides `Brightness`, `Color`, `Enabled` and
`Shadows`. Beyond that:

| Class | Extra properties | Shape |
|---|---|---|
| `PointLight` | `Range` | Omnidirectional from a point. |
| `SpotLight` | `Range`, `Angle`, `Face` | Cone from a point, pointed along `Face`. |
| `SurfaceLight` | `Range`, `Angle`, `Face` | Emits from the whole chosen face of the parent part — a soft area light. |

Rules of engagement:

1. **`Range` is hard-clamped to 120 studs** (per `ExtendLightRangeTo120`'s doc text). Large
   spaces need multiple lights, not one big one.
2. **`Shadows` is per-light and is the dominant cost under `Future`.** Default to
   `Shadows = false` for decorative lights (a glowing sign, a ceiling strip, a fire's glow)
   and reserve `Shadows = true` for lights whose *shadow* is the point.
3. **`SurfaceLight` is the most flattering and the most often forgotten.** It is the closest
   thing Roblox gives you to a softbox: emitting from a face rather than a point gives
   gradients rather than hotspots. Use it for windows, light panels, and screen glow.
4. **A `SpotLight` with a narrow `Angle` and `Shadows = true` under `Future` gives you
   gobo-free but shaped light** — the single most "AAA" thing you can do with Roblox lighting.
5. **Parent lights to `Attachment`s**, not directly to parts, when you need to position them
   independently of the part's centre. `PointLight` in an `Attachment` emits from the
   attachment's `WorldPosition`.

There is an engine limit on how many local lights can affect a given region simultaneously;
Roblox does not publish the exact number and it varies by technology and quality level.
`[UNVERIFIED — a per-cluster light-count cap exists in practice, but no primary-source figure
was found. Budget by profiling, not by a remembered constant.]`

---

## 2. Atmosphere, sky and clouds — the fastest route to a professional look

### 2.1 Why `Atmosphere` is the single highest-ROI object in Roblox

Roblox's own description is unusually direct about what `Atmosphere` is for:

> *"The **Atmosphere** object pushes Roblox closer toward realistic environments where
> sunlight scatters in different ways depending on density and other air particle properties.
> It simulates real-world **'aerial perspective'** and lets you control light transmission from
> the background sky through distant objects."*
> — `reference/engine/classes/Atmosphere.yaml`

**Aerial perspective is the reason this matters more than anything else you can toggle.**
In the real world, distant objects lose contrast and shift toward the sky's colour because
you are looking through kilometres of scattering air. The human visual system uses this as a
primary depth cue. A render with no aerial perspective — which is exactly what Roblox gives
you by default — reads as a flat diorama no matter how good the models are. Add an
`Atmosphere`, and the same scene suddenly has depth, scale, and a sense of being a *place*.

It is also nearly free: it is a screen-space/per-pixel fog-and-scattering evaluation, not
geometry, not extra passes over the scene. For roughly zero frame cost and about ninety
seconds of work you get the biggest perceptual improvement available.

**Insert `Atmosphere` as a child of `Lighting`.** Note the side effect, stated in the class
docs: *"Fog properties are hidden when Lighting contains an Atmosphere object."* The legacy
`FogColor`/`FogStart`/`FogEnd` properties are superseded and disappear from the Properties
panel.

### 2.2 The six `Atmosphere` properties, and their dependency graph

| Property | Type | What it does (source: `Atmosphere.yaml` + `environment/atmosphere.md`) |
|---|---|---|
| `Density` | float | *"Defines the amount of particles in the air. The higher the density, the more particles and the more in-game objects/terrain will be obscured by them."* Note: *"density does not **directly** affect the skybox — it merely affects in-game objects/terrain and visibility of the skybox through them."* |
| `Offset` | float | *"Controls how light transmits between the camera and the sky background. Increase this value to create a horizon silhouette against the sky or reduce it to blend distant objects into the sky for an endless and seamless open world."* |
| `Color` | Color3 | *"Changes the Atmosphere hue for subtle environmental moods. This is best combined with increased `Haze` to expand the visible effect."* |
| `Decay` | Color3 | *"Defines the hue of the Atmosphere **away from the sun**, gradually falling off from `Color` towards this value."* |
| `Glare` | float | *"Specifies the glow/glare of the Atmosphere around the sun. More glare results in an increased effect of sunlight cast onto the sky and world."* |
| `Haze` | float | *"Defines the haziness of the Atmosphere with a visible effect both above the horizon and into the distance."* |

**The dependency graph is the part that trips everyone up**, and the docs state it explicitly:

- `Glare` has **no effect** unless `Haze > 0`.
- `Decay` has **no effect** unless **both** `Haze > 0` **and** `Glare > 0`.
- `Color` is barely visible unless `Haze` is raised.

So the authoring order is forced: **`Density` → `Haze` → `Color` → `Glare` → `Decay` → `Offset`.**
If you set `Decay` to a gorgeous sunset orange and see nothing, it is because `Glare` is 0.

### 2.3 The `Density` / `Offset` balance

This is the one genuine trap in `Atmosphere`, and the docs warn about it in both directions:

> *"Offset should be balanced against `Density` and carefully tested in your place. A **low
> offset may cause 'ghosting'** where the skybox can be seen through objects/terrain. This can
> be corrected by increasing the offset, which more clearly silhouettes distant objects/terrain
> against the sky, but **too much offset may reveal level-of-detail 'popping'** for far distant
> terrain and meshes."*

Practical reading:

- **High `Density`, low `Offset`** → distant geometry dissolves into the sky. Beautiful for
  open worlds and "endless" horizons; risks the skybox bleeding through mountains.
- **High `Offset`** → distant geometry stays silhouetted against the sky. Reads as crisper and
  more graphic; exposes mesh LOD popping and terrain chunk transitions.
- Tune `Offset` **while flying the camera to your maximum expected view distance**, not while
  standing in the middle of the map. The failure modes only appear at range.

### 2.4 Value ranges that actually read well

`[COMMUNITY, SECOND-HAND + practitioner synthesis — Roblox publishes only comparison images,
not recommended numeric ranges. These are working starting points, not doctrine.]`

| Mood | Density | Offset | Haze | Glare | Color | Decay |
|---|---|---|---|---|---|---|
| Crisp clear day | 0.30 | 0.25 | 0.5 | 0.2 | `[199,199,199]` | `[106,112,125]` |
| Hazy summer | 0.40 | 0.10 | 1.8 | 0.6 | `[210,205,190]` | `[140,130,120]` |
| Golden sunset | 0.42 | 0.10 | 2.4 | 1.0 | `[255,215,180]` | `[255,90,80]` |
| Overcast / grey | 0.45 | 0.30 | 2.6 | 0.0 | `[190,192,196]` | `[150,152,158]` |
| Horror fog | 0.55 | 0.00 | 3.5 | 0.0 | `[95,100,105]` | `[40,42,48]` |
| Alien / toxic | 0.48 | 0.15 | 3.0 | 0.8 | `[180,255,170]` | `[60,120,70]` |
| Underwater | 0.60 | 0.00 | 4.0 | 0.3 | `[60,140,170]` | `[15,50,80]` |

A note on `Decay`: because it is the hue *away from the sun*, the strongest painterly move
available is to make `Color` warm and `Decay` cool (or vice versa). That gives you a real
warm-to-cool gradient across the sky and across distant geometry, which is the single most
recognisable signature of deliberate art direction. The docs' own example pairs
`Color = [255,255,255]` against `Decay = [255,90,80]`.

### 2.5 `Sky` and custom skyboxes

`Sky` is a child of `Lighting`. It is a cubemap plus celestial bodies.

**Six face properties** (`ContentId` form / `Content` form):
`SkyboxBk`/`SkyboxBackContent`, `SkyboxDn`/`SkyboxDownContent`, `SkyboxFt`/`SkyboxFrontContent`,
`SkyboxLf`/`SkyboxLeftContent`, `SkyboxRt`/`SkyboxRightContent`, `SkyboxUp`/`SkyboxUpContent`.

> *"Each image must be seamless along **all edges** of neighboring images when 'folded' into a
> cube."* — `environment/skybox.md`

**Celestial bodies:**

| Property | Notes |
|---|---|
| `CelestialBodiesShown : boolean` | Master toggle for sun, moon and stars. |
| `SunTextureId` / `SunTextureContent` | Sun sprite. |
| `SunAngularSize : float` | Apparent sun size in **degrees**. |
| `MoonTextureId` / `MoonTextureContent` | Moon sprite. |
| `MoonAngularSize : float` | *"Defaults to `11` and is clamped to the range `[0, 60]`."* |
| `StarCount : int` | Number of stars. |
| `SkyboxOrientation : Vector3` | Degrees; *"rotation is **applied** first around the **Y** axis, then **X**, and then **Z**."* |

Two sharp, useful facts from the guide:

1. **You can kill the sun or moon without killing the stars.** *"To disable all celestial
   bodies, you can toggle off `CelestialBodiesShown`. Alternatively, you can disable only the
   sun and/or moon (while keeping the stars) by setting `SunAngularSize` or `MoonAngularSize`
   to `0`."* This is how you build a starfield-only night sky or a sunless alien world.
2. **`Sky` doubles as the reflection cubemap for `ViewportFrame`.** *"The `Sky` object can be
   used as a cubemap for reflections in `ViewportFrames`."* — relevant in §5.

**All six `Skybox*Content` properties are `Read: None / Write: None`** in the API dump, meaning
they are freely scriptable — including assigning an `EditableImage`. A procedurally generated
skybox at runtime is therefore possible, though the 1024×1024 `EditableImage` size cap applies
per face.

Animating the skybox is a one-liner, per the official sample:

```lua
-- Spin the sky about Y while holding a fixed 30 degree tilt on X.
RunService.Heartbeat:Connect(function(dt)
    sky.SkyboxOrientation = Vector3.new(30, (sky.SkyboxOrientation.Y + 5 * dt) % 360, 0)
end)
```

**Art-direction note:** a custom skybox is the second-highest-leverage change after
`Atmosphere`, because the skybox is simultaneously (a) a large fraction of screen pixels in
any outdoor shot, (b) the source of `EnvironmentDiffuseScale`/`EnvironmentSpecularScale`
ambient contribution, and (c) the thing `Atmosphere` blends your distant geometry *into*.
A mismatched skybox — cartoon clouds under a realistic atmosphere, or vice versa — is the
most common "why does this look wrong and I can't tell why" failure.

### 2.6 `Clouds`

**`Clouds` does not go in `Lighting`.** From the guide: *"clouds only render if you parent the
object under the `Terrain` class."* This is a genuine gotcha — putting `Clouds` in `Lighting`
alongside `Atmosphere` and `Sky` silently does nothing.

| Property | Range / notes |
|---|---|
| `Cover : float` | *"Valid range is from 0 to 1 (sparse cloud cover to full cloud cover)."* |
| `Density : float` | *"Controls the particulate density of clouds... mainly affecting their transparency. Lower values produce light, semi-translucent clouds, and higher values produce heavy, dark clouds with a stormy appearance."* |
| `Color : Color3` | *"Controls the material color of cloud particles. However, cloud color is influenced by several `Lighting` and `Atmosphere` properties, so it is **not intended as a dedicated property to simulate colored sunsets**."* |
| `Enabled : boolean` | *"Useful for toggling on/off different `Clouds` objects that exist in the same place."* |

Clouds drift, and their **direction and speed come from global wind**
(`Workspace.GlobalWind`), not from a property on `Clouds` itself. One `Vector3` therefore
drives clouds, foliage sway and `Trail`/`ParticleEmitter` wind response together — set it
once and the whole world agrees on which way the wind blows.

`Clouds` is a volumetric raymarched effect and is **the most expensive of the three
environment objects**. Budget it as a real cost on low-end devices, and use `Enabled = false`
as a quality-scaling lever. `[UNVERIFIED — Roblox does not publish a cost figure for `Clouds`;
the volumetric characterisation follows from its visual behaviour and community profiling.]`

### 2.7 Weather as a system, not a setting

Because `Atmosphere`, `Clouds`, `Lighting` and `GlobalWind` are all plain properties, a
weather system is just interpolation. The professional version tweens *everything together*
so the transition reads as one physical change rather than five independent sliders:

```lua
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")

local function applyWeather(preset, seconds)
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    TweenService:Create(Lighting, info, preset.lighting):Play()
    TweenService:Create(atmo,     info, preset.atmosphere):Play()
    TweenService:Create(clouds,   info, preset.clouds):Play()
    -- GlobalWind is a Workspace property and tweens the same way.
    TweenService:Create(workspace, info, {GlobalWind = preset.wind}):Play()
end

local STORM = {
    lighting   = {Brightness = 0.8, OutdoorAmbient = Color3.fromRGB(70,75,85),
                  Ambient = Color3.fromRGB(30,33,40), ExposureCompensation = -0.4},
    atmosphere = {Density = 0.48, Haze = 2.9, Glare = 0.0,
                  Color = Color3.fromRGB(150,155,165), Decay = Color3.fromRGB(80,85,95)},
    clouds     = {Cover = 0.95, Density = 0.35, Color = Color3.fromRGB(120,125,135)},
    wind       = Vector3.new(60, 0, 20),
}
```

Do this on the **client**, not the server, if you want per-player weather; `Lighting` changes
replicate from the server otherwise, which is usually what you want for a shared world.

---

## 3. Post-processing — every effect, its cost, and tasteful tuning

### 3.1 The rules that apply to all of them

All post-processing effects inherit from **`PostEffect`**, whose only member is
`Enabled : boolean`. That single property is your quality-scaling switch.

**Where you parent them determines who sees them** — this is the most important structural
fact and the docs state it plainly:

> *"When you add post-processing effects to the `Lighting` service, they display to **all
> players** who enter the game. This is useful for effects that affect the global environment,
> such as sun rays. When you add post-processing effects to the `Camera` object, they only
> display to a **specific player**."*
> — `environment/post-processing-effects.md`

So: **`Lighting` = art direction; `Camera` = feedback and UI.** A global colour grade goes in
`Lighting`. A red damage flash, a menu blur, a drunk/poisoned effect, a night-vision tint goes
in `Workspace.CurrentCamera` from a `LocalScript`. Effects under `Camera` are client-local and
never replicate, which is exactly right for per-player feedback.

**Multiple instances of the same effect stack.** Two `ColorCorrectionEffect`s compose, which is
the intended architecture: one in `Lighting` as the permanent grade, one in `Camera` as a
transient feedback layer that you tween to zero when done. Never mutate the base grade for
transient feedback — you will lose it.

**The six effects, complete list:** `BloomEffect`, `BlurEffect`, `ColorCorrectionEffect`,
`DepthOfFieldEffect`, `SunRaysEffect`, `ColorGradingEffect`.

A Studio gotcha worth knowing: *"Depending on your Studio settings, some effects may not
appear. To increase your rendering quality level: Studio Settings → Rendering → Editor
Quality Level → highest."* If a colleague says "I don't see your bloom", this is why.

### 3.2 `BloomEffect` — and how to avoid the amateur signature

Three properties:

| Property | Doc text |
|---|---|
| `Threshold` | *"Determines how bright a color can be before it blooms. If set to 1, only pure white colors will bloom. If set to 0, all colors will bloom."* |
| `Intensity` | *"Determines how intensely the colors that bloom will additively blend with themselves. Higher values will produce brighter colors."* |
| `Size` | *"Determines the radius of the bloom effect **in pixels**... Larger values create a wider bloom effect, and **a value of 0 will disable the bleed (but not the color adjustment)**."* |

**The amateur look, precisely diagnosed.** Default-ish bloom with `Threshold` low (≤1) and
`Intensity` high (>1) causes *everything moderately bright* to bloom. The result: white
haloes around ordinary surfaces, no black point anywhere in the frame, text and UI washed
out, and total loss of material differentiation. It reads as "someone found the glow slider."

**The professional configuration:**

- **`Threshold` is a gate, so set it above your scene's normal diffuse range.** Values of
  **1.5–2.5** mean only genuinely emissive things — neon, `SurfaceAppearance` emissive, the
  sun disc, a `SpotLight` filament, a highlighted item — bloom at all. Everything else stays
  crisp. This is what makes bloom read as "that object is emitting light" rather than "the
  screen is foggy."
- **`Intensity` stays low: 0.3–0.8.** Bloom should be a suggestion. If you can point at it
  and say "that's bloom," it is too strong.
- **`Size` 12–24** for a soft filmic halo; **`Size` 4–8** for a tight, graphic glow that suits
  stylized art. Note that `Size` is in *pixels*, so it is resolution-relative: bloom tuned on a
  4K monitor looks tighter on a phone.
- **Pair bloom with a lowered `Lighting.ExposureCompensation` (−0.3 to −0.8).** This is the
  actual trick. Pull global exposure down so the scene has a proper black point and midtones
  sit low, then let only the truly bright things punch through the bloom threshold. That is
  the difference between "HDR" and "hazy."

Cost: a downsample/blur chain over the frame. Cheap on desktop, real but acceptable on
mobile. `Size = 0` still does the colour adjustment without the blur chain, so it is not a
free disable — set `Enabled = false` for that.

### 3.3 `ColorCorrectionEffect` — your grade, and your feedback channel

| Property | Doc text |
|---|---|
| `Brightness` | *"Determines by how much the colors of pixels will be shifted. A value of `-1` will cause all pixels to be completely black while a value of `1` will cause them to be white."* |
| `Contrast` | *"Determines the separation between the dark and light colors. Values less than `0` have reduced contrast while values greater than `0` have increased contrast."* |
| `Saturation` | *"Determines the change in intensity of pixel colors. Values above `1` will cause colors to be more vivid while values below `0` will make colors more dull, eventually reaching full desaturation at `-1`."* |
| `TintColor` | *"Determines by what factors the RGB channels of pixel colors are **scaled**. The effect is **multiplicative**, so changing this to `[255, 0, 0]` (red) would cause the green and blue channels to be multiplied by `0`."* |

**`TintColor` is multiplicative, which is the single most misunderstood thing here.** It is a
per-channel *multiply*, not an overlay. `[255,0,0]` does not "tint red" — it deletes green and
blue entirely. Real grading tints are subtle: `[255, 248, 235]` for warm, `[235, 243, 255]`
for cool. Anything below about 200 in a channel is already a heavy stylisation.

**Grade recipes** (put these in `Lighting`):

| Look | Brightness | Contrast | Saturation | TintColor |
|---|---|---|---|---|
| Neutral filmic | `-0.02` | `0.10` | `0.05` | `[255,252,248]` |
| Warm / nostalgic | `0.02` | `0.08` | `0.12` | `[255,244,228]` |
| Cold / clinical | `-0.03` | `0.15` | `-0.10` | `[232,240,255]` |
| Bleach-bypass action | `0.00` | `0.30` | `-0.35` | `[250,250,250]` |
| Horror | `-0.10` | `0.20` | `-0.30` | `[225,232,240]` |
| Vibrant commercial | `0.03` | `0.12` | `0.25` | `[255,250,245]` |
| Sepia memory | `0.00` | `0.05` | `-0.55` | `[255,230,190]` |

**As feedback**, per the docs: *"You can also use this effect to provide player feedback, such
as tinting the screen red when their character's health is low."* The pattern:

```lua
-- LocalScript. A dedicated effect under Camera, tweened, leaving the Lighting grade alone.
local cam = workspace.CurrentCamera
local fx = Instance.new("ColorCorrectionEffect")
fx.Parent = cam

local function damageFlash()
    fx.TintColor = Color3.fromRGB(255, 120, 120)
    fx.Saturation = -0.2
    fx.Brightness  = 0.05
    TweenService:Create(fx, TweenInfo.new(0.45), {
        TintColor  = Color3.new(1,1,1),
        Saturation = 0,
        Brightness = 0,
    }):Play()
end
```

This is Roblox's substitute for a screen-space damage shader, and it is the correct one:
one instance, one tween, no per-frame work, zero replication.

Cost: a per-pixel colour transform. Effectively free.

### 3.4 `ColorGradingEffect` — the tonemapper

Exactly one property: `TonemapperPreset : Enum.TonemapperPreset`.

| Preset | Doc text |
|---|---|
| `Default` (0) | *"Sets the tone mapper to use the post-2019 Roblox appearance which provides vivid colors and high contrasts."* |
| `Retro` (1) | *"Sets the tone mapper to imitate the pre-2019 Roblox appearance. Colors look less saturated and there is less contrast between them."* |

This is the **only** control Roblox exposes over the tone-mapping curve — the step that maps
the renderer's internal high-dynamic-range values into displayable colour. In an engine with
shaders this would be a full ACES/filmic curve with parameters; here you get two presets.

Two concrete uses:

1. **Deliberate retro / nostalgic art direction.** The docs give the full recipe:
   *"If you wish to recreate a full pre-2019 Roblox look for your game, experiment with
   `TonemapperPreset.Retro` and set the brightness of all lights to a maximum of `1.0`."*
2. **The official migration path off the deprecated `Compatibility` technology.** From
   `Technology.yaml`: *"To achieve a similar look, use `Voxel` Lighting and add a
   `ColorGradingEffect` post-processing effect set to the `Retro` preset."*

`Retro` also flattens contrast, which is genuinely useful for **stylized / illustrated** looks
where you want flat colour fields rather than photographic contrast — pair it with a
`ColorCorrectionEffect` that pushes `Saturation` back up and you get a clean cel/gouache read.

### 3.5 `DepthOfFieldEffect` — framing, not decoration

Four properties, and they define a piecewise blur profile along the view ray:

| Property | Doc text |
|---|---|
| `FocusDistance` | *"Controls the distance away from the camera (in studs) where objects are in focus."* |
| `InFocusRadius` | *"Controls the distance away from `FocusDistance` (on both sides) where no blur is applied. Measured in studs."* |
| `NearIntensity` | *"Intensity of the near field blur, between the camera and the `FocusDistance` point **minus** `InFocusRadius`."* |
| `FarIntensity` | *"Intensity of the far field blur, moving out in distance from the `FocusDistance` point **plus** `InFocusRadius`."* |

So the geometry is:

```
camera ──── near blur ────┤   sharp band   ├──── far blur ──── ∞
                          │                │
        FocusDistance − InFocusRadius   FocusDistance + InFocusRadius
```

**The default DOF configuration is aggressive and is the reason many places look like a
diorama.** Real cinematic DOF on a wide-ish game camera is *subtle*. Three disciplined uses:

1. **Atmospheric far-only DOF.** `NearIntensity = 0`, `FarIntensity = 0.5–0.75`,
   `FocusDistance ≈ 30–60`, `InFocusRadius ≈ 25–50`. The near field stays perfectly sharp
   (crucial — blurring the player's own character or held items looks broken), and distance
   softens. Combined with `Atmosphere`, this is a very strong depth cue.
2. **UI / shop / inspection focus.** Crank `FarIntensity` to 1 and pull `FocusDistance` in to
   the inspected object's distance while a menu is open, then tween back. Cheaper and more
   controllable than a full-screen `BlurEffect` because the subject stays sharp.
3. **Cutscene racking.** Tween `FocusDistance` between two subjects' distances. This is a
   rack focus and it instantly reads as "cinematic" because no one else on the platform does it.

```lua
-- Rack focus: keep the shot's subject sharp as it moves.
RunService.RenderStepped:Connect(function()
    local d = (subject.Position - cam.CFrame.Position).Magnitude
    dof.FocusDistance = dof.FocusDistance + (d - dof.FocusDistance) * 0.12  -- smoothed
end)
```

Cost: a depth-driven variable blur — the **most expensive** of the standard effects, because
it needs the depth buffer and a multi-tap blur. It is the first thing to disable on low-end
devices.

### 3.6 `SunRaysEffect`

| Property | Doc text |
|---|---|
| `Intensity` | *"Determines the opacity of the sun rays. Values closer to 0 are less visible, while values closer to 1 become more visible."* |
| `Spread` | *"Determines how wide the sun rays will spread across the sky. Its value should be set between 0 and 1 as values outside that range have undefined behavior."* |

> *"Creates a halo of light with rays around the sun that move based on the `ClockTime` or
> `TimeOfDay` property. **Objects between the player's camera and the sun shape this effect**,
> allowing for realistic visuals of light and shadow."*

That last sentence is the important one: this is **screen-space occlusion-shaped god rays**,
not a flat overlay. Trees, buildings and terrain edges carve into the rays, which is why it
reads as real volumetric light despite being a 2D effect.

Tuning: **`Intensity` 0.1–0.25, `Spread` 0.6–1.0.** Anything above 0.3 intensity turns into a
white smear that destroys the scene. It only fires when the sun is on screen, so it is a
low-angle (sunrise/sunset) effect by nature — which pairs naturally with a high
`GeographicLatitude` (§1.4).

**Important limitation:** because it is screen-space and anchored to the sun, it can only
produce god rays *from the sun*. For volumetric shafts from a window, a lamp, or a doorway,
you need the `Beam`-based fake described in §5.

Cost: a radial-blur pass. Moderate. Disable on low quality.

### 3.7 `BlurEffect`

One property: `Size : float` — *"controls the blur radius, measured in pixels."*

This is a full-screen Gaussian blur. It has exactly one legitimate use, which the docs name:
*"blur the background when a player has a menu open, allowing them to focus on the most
important details."* Use it under `Camera`, tween `Size` from 0 to ~18 on menu open and back
on close. Never leave it on during gameplay.

Two secondary uses worth knowing: a **death/unconscious** transition (tween `Size` up while
tweening a `ColorCorrectionEffect` toward desaturation), and a **dream/flashback** framing
device (a light constant blur of 3–6 plus a warm grade).

Cost: proportional to `Size` and screen resolution. A large blur on a high-res mobile screen
is not cheap. Tween it down to 0 and set `Enabled = false` when idle.

### 3.8 A complete, tasteful default stack

The stack below is a good neutral starting point for almost any project. It is deliberately
restrained — five instances, no value that draws attention to itself.

```lua
-- Run once, in Studio or a server script at startup. Parent: Lighting.
local Lighting = game:GetService("Lighting")

local bloom = Instance.new("BloomEffect")
bloom.Threshold = 1.8      -- only genuinely emissive things bloom
bloom.Intensity = 0.55
bloom.Size      = 18
bloom.Parent    = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness = -0.02
grade.Contrast   =  0.10
grade.Saturation =  0.05
grade.TintColor  = Color3.fromRGB(255, 252, 248)
grade.Parent     = Lighting

local dof = Instance.new("DepthOfFieldEffect")
dof.FocusDistance = 45
dof.InFocusRadius = 40
dof.NearIntensity = 0          -- never blur the player's own character
dof.FarIntensity  = 0.60
dof.Parent        = Lighting

local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.15
rays.Spread    = 0.85
rays.Parent    = Lighting

Lighting.ExposureCompensation = -0.35   -- give the frame a real black point
```

---

## 4. Materials and PBR

### 4.1 The `Enum.Material` set

Every `BasePart` has a `Material`. These are not decorative labels — each one carries a
built-in tiling texture set (colour + normal + roughness + metalness) authored by Roblox, plus
default physical properties. The full enum, with values, from
`reference/engine/enums/Material.yaml`:

**Plastics / special (256–288):** `Plastic` (256), `SmoothPlastic` (272), `Neon` (288)
**Wood (512–528):** `Wood` (512), `WoodPlanks` (528)
**Stone / masonry (784–912):** `Marble` (784), `Basalt` (788), `Slate` (800), `CrackedLava` (804),
`Concrete` (816), `Limestone` (820), `Granite` (832), `Pavement` (836), `Brick` (848),
`Pebble` (864), `Cobblestone` (880), `Rock` (896), `Sandstone` (912)
**Metals (1040–1088):** `CorrodedMetal` (1040), `DiamondPlate` (1056), `Foil` (1072), `Metal` (1088)
**Ground / natural (1280–1392):** `Grass` (1280), `LeafyGrass` (1284), `Sand` (1296), `Fabric` (1312),
`Snow` (1328), `Mud` (1344), `Ground` (1360), `Asphalt` (1376), `Salt` (1392)
**Transmissive / terrain-only (1536–2048):** `Ice` (1536), `Glacier` (1552), `Glass` (1568),
`ForceField` (1584), `Air` (1792), `Water` (2048)
**2021+ additions (2304–2311):** `Cardboard` (2304), `Carpet` (2305), `CeramicTiles` (2306),
`ClayRoofTiles` (2307), `RoofShingles` (2308), `Leather` (2309), `Plaster` (2310), `Rubber` (2311)

Practitioner notes on the ones that behave unusually:

- **`Neon`** ignores scene lighting and renders as a flat, self-lit emissive colour. It is
  **the only way to get an emissive surface on a plain `Part`**, and it is the single most
  overused material on the platform. Used with restraint — a thin strip, a sign, an eye — it is
  excellent. Used on whole buildings it is the visual equivalent of shouting. Neon surfaces
  are what `BloomEffect.Threshold` should be tuned to catch.
- **`ForceField`** renders as an animated translucent shell with a moving hex/scanline pattern.
  It is a genuine free "shader" the engine gives you; treat it as a stylistic choice, not a
  utility.
- **`Glass`** under `Future` lighting gets real refraction-ish treatment and looks genuinely
  good; under `Voxel` it is just translucent plastic. It is also a transparency cost (see §6).
- **`SmoothPlastic`** is the neutral canvas: no surface texture, clean colour. It is the
  correct default for stylized work where you want the `Color3` and the lighting to carry the
  look rather than a tiling texture.
- **`Air`** and **`Water`** are terrain-only. `Water` on terrain has its own properties on
  `Terrain` (`WaterColor`, `WaterTransparency`, `WaterReflectance`, `WaterWaveSize`,
  `WaterWaveSpeed`) which are a separate, and very good, free water system.
- **`Plastic`** (the default) has a subtle noise texture that reads as "cheap" at close range.
  Switching a project's default from `Plastic` to `SmoothPlastic` is a one-click quality win.

### 4.2 `MaterialVariant` — custom tiling materials

A `MaterialVariant` is a child of `MaterialService`. It is *"for customizing the appearance of
reusable tileable material"* as opposed to `SurfaceAppearance` which is *"for customizing the
visual appearance of a specific mesh with UV mapping."* `MaterialVariant` instances *"also have
physical properties that `SurfaceAppearance` instances don't."* (`parts/materials.md`)

| Property | Type | Notes |
|---|---|---|
| `BaseMaterial` | `Enum.Material` | *"Category Material this variant belongs to."* Determines which built-in material it can stand in for. |
| `ColorMap` / `ColorMapContent` | ContentId / Content | Albedo. *"The alpha channel is not used."* |
| `NormalMap` / `NormalMapContent` | ContentId / Content | Tangent-space normal map (§4.5). |
| `MetalnessMap` / `MetalnessMapContent` | ContentId / Content | Grayscale metallic mask. |
| `RoughnessMap` / `RoughnessMapContent` | ContentId / Content | Grayscale roughness. |
| `EmissiveMaskContent` | Content | Grayscale emissive mask. |
| `EmissiveTint` / `EmissiveStrength` | Color3 / float | Emissive colour and multiplier. |
| `StudsPerTile` | float | *"Determines the scale of textures. Larger values for this property will lead to the textures appearing larger, and repeating less frequently."* |
| `MaterialPattern` | `Enum.MaterialPattern` | `Regular` (0) = *"ordered pattern, usually man-made, like brick or wood planks"*; `Organic` (1) = *"less repetition, like stone or dirt."* Affects the tiling method. |
| `AlphaMode` | `Enum.AlphaMode` | Marked `NotBrowsable`; beta. |
| `CustomPhysicalProperties` | PhysicalProperties | Density/friction/elasticity for parts using this variant. |

**`StudsPerTile` is your UV-scale knob.** In an engine with shaders you would multiply UVs in
the fragment stage; here, `StudsPerTile` is the whole mechanism for controlling world-space
texture density on parts. Getting it right is the difference between a brick wall and a wall
with a photo of bricks on it. Match `StudsPerTile` to the real-world scale of the pattern:
if your brick texture contains 8 courses of brick and a course is ~0.25 studs, the tile should
be ~2 studs.

**`MaterialPattern = Organic` is the anti-tiling feature.** For stone, dirt, moss and sand,
setting `Organic` changes the tiling algorithm to break up the visible grid repetition. This is
the engine's built-in substitute for the stochastic/hex-tiling shader trick you would otherwise
write. Always set it on natural materials; never on brick or planks.

### 4.3 `MaterialService` and base-material overrides

`MaterialService` holds the variants and exposes three scriptable methods
(all `security: None`, so callable from ordinary scripts):

| Method | Signature | Purpose |
|---|---|---|
| `SetBaseMaterialOverride` | `(material: Enum.Material, name: string) -> ()` | *"Set a `MaterialVariant` name that overrides a built-in material."* |
| `GetBaseMaterialOverride` | `(material: Enum.Material) -> string` | *"Get the override `MaterialVariant` name of specified Material type."* |
| `GetMaterialVariant` | `(material: Enum.Material, name: string) -> MaterialVariant?` | *"Get the effective MaterialVariant reference given a MaterialVariant name and BaseMaterial. This MaterialVariant must be a descendant of MaterialService. Returns `nil` if no matching instance exists."* |

**This is a global re-skin lever and it is very powerful.** One call:

```lua
local MaterialService = game:GetService("MaterialService")
-- Every part and every terrain voxel that uses Enum.Material.Grass now uses
-- the "StylizedGrass" MaterialVariant instead. No per-part edits.
MaterialService:SetBaseMaterialOverride(Enum.Material.Grass, "StylizedGrass")
```

Two facts from `parts/materials.md` that make this load-bearing:

1. ***"Material overrides are the only way to apply custom materials to terrain."*** You cannot
   set a `MaterialVariant` on terrain directly. If you want custom terrain materials, overrides
   are the mechanism, full stop.
2. ***"The materials for terrain are global per place, so you can't apply multiple variants of
   the same base material to the terrain in a single place."*** One variant per base material,
   globally. Plan your material budget around that.

`TerrainDetail` instances (children of a `MaterialVariant` used as an override) let you give
terrain's **top**, **side** and **bottom** faces separate texture maps, studs-per-tile and
pattern — the correct way to get grass-on-top / dirt-on-the-sides cliffs.

**Physical-property resolution order** (most to least specific), per the same guide:
part-specific `CustomPhysicalProperties` → the override variant's `CustomPhysicalProperties` →
the base material's default physical properties. `MaterialVariant.CustomPhysicalProperties`
*"apply only when that value was constructed with explicit values"*, otherwise it falls through.

### 4.4 `SurfaceAppearance` — per-mesh PBR

A `SurfaceAppearance` is a child of a `MeshPart`. It *"overwrites the original assigned texture."*

| Property | Type | Role |
|---|---|---|
| `ColorMap` / `ColorMapContent` | ContentId / Content | Albedo + alpha. |
| `NormalMap` / `NormalMapContent` | ContentId / Content | Tangent-space normals. |
| `MetalnessMap` / `MetalnessMapContent` | ContentId / Content | Grayscale metallic mask. |
| `RoughnessMap` / `RoughnessMapContent` | ContentId / Content | Grayscale roughness. |
| `EmissiveMaskContent` | Content | *"A grayscale image where black pixels correspond to no emissivity, and white pixels correspond to full emissivity."* |
| `EmissiveStrength` | float | Emissive multiplier; clamps to white if pushed past dynamic range. |
| `EmissiveTint` | Color3 | Emissive hue. |
| `Color` | Color3 | *"Applies a tint to your existing colormap."* |
| `AlphaMode` | `Enum.AlphaMode` | See below. |
| `ResampleMode` | `Enum.ResamplerMode` | `Default` (bilinear) or `Pixelated` (nearest-neighbour). |
| `TexturePack` / `TexturePackContent` | ContentId / Content | **`RobloxSecurity` — internal only.** |

**The emissive maths, stated in the docs:** *"The emissive contribution gets added to total
lighting contribution across the surface, and the sum gets multiplied by the albedo texture."*
So emissive is not an additive overlay on top of the final colour — it is added to the
*lighting* term and then multiplied by albedo. A black region of the ColorMap will not glow no
matter how high `EmissiveStrength` goes.

**`Enum.AlphaMode` — four values, and the choice matters:**

| Mode | Behaviour (from `art/modeling/surface-appearance.md`) |
|---|---|
| `Overlay` (0) — **default** | *"Overlays the ColorMap over the underlying mesh's `MeshPart.Color`. Color maps using overlay mode reveal the base color of the mesh anywhere transparency is present."* |
| `Transparency` (1) | *"Removes the visible mesh based on transparency in the ColorMap. This renders the mesh see-through and does not reveal the original mesh color."* |
| `TintMask` (2) | *"Blends the tinted ColorMap over the un-tinted ColorMap"* — the alpha channel controls **how much `SurfaceAppearance.Color` tinting is applied**, per-pixel. |
| `Opaque` (3) | *"Ignores the alpha channel of the ColorMap altogether... the alpha value is assumed to be 1."* Marked `NotBrowsable`; documented as beta. |

There is a subtle and important performance/quality fork inside `Transparency` mode:

> *"When set to `Transparency` and the `MeshPart.Transparency` is set to `0`, opaque pixels in
> the ColorMap will render as completely opaque in the 3D scene. **This combination works better
> with depth-based effects and occlusion.** When set to `Transparency` and the
> `MeshPart.Transparency` is set to at least `0.02`, a different blending method is used that
> can better represent smooth transparency gradients and soft edges. **This combination does not
> support all effects and occlusion may not be perfect.**"*

Translation: `MeshPart.Transparency = 0` gives you **alpha-test / cutout** behaviour (cheap,
z-correct, works with DOF); `Transparency ≥ 0.02` gives you **alpha-blend** behaviour (soft
edges, but sorting artefacts and effect incompatibility). For foliage, chain-link and grates,
keep `Transparency = 0`. For smoke cards, glass and gradients, use `≥ 0.02`.

**`TintMask` + `Color` is the memory-saving variation trick, and the docs endorse it:**

> *"Tinting does not affect performance and you can save on memory by reusing a single color
> map with different tints... `Color` tinting applies as a multiplier, so the final appearance
> is a function of `Color3` (texel color) times `Color`. This means that authoring your original
> ColorMap in **near-white grayscale colors** creates the strongest tinting effect."*
> — and, from the performance guide: *"Instead of using separate textures for different colors,
> upload a single texture and use the `SurfaceAppearance.Color` property to apply various tints."*

So the professional pipeline for a prop with ten colourways is: **one near-white grayscale
ColorMap with a `TintMask` alpha marking which regions are tintable, ten `SurfaceAppearance`
instances differing only in `Color`.** One texture in memory, ten looks.

### 4.5 The normal-map convention — get this exactly right

`MaterialVariant.NormalMap`'s description is the most precise statement Roblox publishes on
this, and it is worth quoting nearly in full because every detail is actionable:

> *"Normal maps are RGB images that modify the surface's normal vector used for lighting
> calculations. The R, G, and B channels of the NormalMap correspond to the X, Y, and Z
> components of the local surface vector respectively, and **byte values of 0 and 255 for each
> channel correspond linearly to normal vector components of −1 and 1.016** respectively. This
> range is stretched slightly from −1 to 1 **so that a byte value of 127 maps to exactly 0**.
> The normal vector's Z axis is always defined as the direction of the underlying mesh's normal.
> **A uniform (127,127,255) image translates to a completely flat normal map.** This format is
> called **'tangent space'** normal maps. **Roblox does not support world space or object space
> normal maps.**"*
>
> *"Incorrectly flipped normal components can make bumps appear like indents. If you import a
> normal map and notice the lighting looks off, you may need to **invert the G channel**...
> The terms 'DirectX format' and 'OpenGL format' are sometimes used to describe whether the G
> channel of the normal map is inverted or not. **Roblox expects the OpenGL format.**"*
>
> *"Roblox expects imported meshes to include **tangents**. Modeling software may also refer to
> this as 'tangent space' information. **If you apply a normal map and it does not seem to make
> any visual difference, you may need to re-export your mesh along with its tangent
> information.**"*

The five rules, condensed:

1. **Tangent space only.** World-space and object-space normal maps are not supported.
2. **OpenGL format (+Y up).** Substance Painter / Marmoset default to DirectX for many presets —
   **invert the green channel** on export, or pick an OpenGL preset. Blender's Principled BSDF
   convention is already OpenGL.
3. **Flat is `(127, 127, 255)`**, not `(128, 128, 255)`. The encoding is deliberately stretched
   to −1 → 1.016 so that 127 lands on exactly zero.
4. **Bumps look like dents** ⇒ your green channel is inverted. That is the diagnostic.
5. **Normal map does nothing at all** ⇒ your mesh has no tangents. Re-export with tangent data.

### 4.6 The EditableImage question — the plain answer

**Do `SurfaceAppearance` and `MaterialVariant` accept `Content` from an `EditableImage`?**

**Yes, the `Content`-typed slots exist and are documented to accept an `EditableImage` — but
every one of them is gated behind `PluginSecurity`, so you can set them from a Studio plugin
or command bar, and NOT from a runtime game script.**

Verified against both `Roblox/creator-docs` YAML and the live `API-Dump.json`:

| Instance | Property | Type | Read security | Write security | Runtime-settable from a game script? |
|---|---|---|---|---|---|
| `SurfaceAppearance` | `ColorMapContent` | `Content` | None | **PluginSecurity** | **No** |
| `SurfaceAppearance` | `NormalMapContent` | `Content` | None | **PluginSecurity** | **No** |
| `SurfaceAppearance` | `MetalnessMapContent` | `Content` | None | **PluginSecurity** | **No** |
| `SurfaceAppearance` | `RoughnessMapContent` | `Content` | None | **PluginSecurity** | **No** |
| `SurfaceAppearance` | `EmissiveMaskContent` | `Content` | None | **PluginSecurity** | **No** |
| `SurfaceAppearance` | `TexturePackContent` | `Content` | RobloxScriptSecurity | RobloxSecurity | **No** (Roblox-internal) |
| `MaterialVariant` | `ColorMapContent` | `Content` | **PluginSecurity** | **PluginSecurity** | **No** |
| `MaterialVariant` | `NormalMapContent` | `Content` | PluginSecurity | PluginSecurity | **No** |
| `MaterialVariant` | `MetalnessMapContent` | `Content` | PluginSecurity | PluginSecurity | **No** |
| `MaterialVariant` | `RoughnessMapContent` | `Content` | PluginSecurity | PluginSecurity | **No** |
| `MaterialVariant` | `EmissiveMaskContent` | `Content` | PluginSecurity | PluginSecurity | **No** |

Note the documentation is internally inconsistent here and you should be aware of it:
`SurfaceAppearance.ColorMapContent`'s own description says *"The content can hold an asset URI
or a reference to an `EditableImage` object... **Assigning an `EditableImage` is useful for
dynamically generating or modifying textures at runtime**, such as in avatar customization and
other in-experience content creation workflows"* — while the same file records
`write: PluginSecurity`. The class-level doc is blunter and matches the security flag:
*"most `SurfaceAppearance` properties cannot be modified by scripts, as the necessary
pre-processing is usually too expensive during runtime."*

**Read that as a signposted direction of travel, not a current capability.** Roblox has clearly
built the plumbing for runtime PBR-map assignment and gated it. `[UNVERIFIED — whether the
PluginSecurity gate on `SurfaceAppearance.*MapContent` will be lifted for runtime scripts.
Re-check `API-Dump.json` before designing around it.]`

**What you CAN drive with an `EditableImage` at runtime.** These are all `Read: None /
Write: None` in the API dump — freely scriptable, and the actual integration surface:

| Instance | `Content` property | Use |
|---|---|---|
| `MeshPart` | `TextureContent` | The whole point: a generated texture on a mesh. |
| `Decal` | `TextureContent` | Generated decal on a part face. |
| `Texture` | `TextureContent` | Generated tiling texture with `StudsPerTileU/V`. |
| `ImageLabel` / `ImageButton` | `ImageContent` | Generated UI / `SurfaceGui` / `BillboardGui` content. |
| `Beam` | `TextureContent` | Generated ribbon texture. |
| `Trail` | `TextureContent` | Generated trail texture. |
| `ParticleEmitter` | `TextureContent` | Generated particle sprite or flipbook sheet. |
| `Sky` | `Skybox{Up,Down,Left,Right,Front,Back}Content`, `SunTextureContent`, `MoonTextureContent` | Generated skybox and celestial bodies. |

The assignment idiom is always the same:

```lua
local AssetService = game:GetService("AssetService")
local img = AssetService:CreateEditableImage({Size = Vector2.new(512, 512)})
-- ... draw into img ...
meshPart.TextureContent = Content.fromObject(img)
```

Three `EditableImage` constraints that shape every design built on it, from the class docs:

1. **`Size` maxes at 1024×1024 and cannot be changed after creation.** *"An `EditableImage`
   cannot be resized; this property is read-only."* To "resize", create a new one and
   `DrawImageTransformed()` into it.
2. **One update per frame, globally, on the display side.** *"Only a single `EditableImage` can
   be updated per frame on the display side. For example, if you update three `EditableImage`
   objects which are currently being displayed, it will take three frames for all of them to be
   updated."* This is a hard throughput ceiling: **you cannot drive many animated generated
   textures at once.** Budget one animated `EditableImage` per frame and no more.
3. **It must be enabled on your account and is permission-gated.** *"Using `EditableImage` fails
   by default for published experiences. To enable usage, you must be 13+ age verified and ID
   verified,"* then toggle **Enable Mesh / Image APIs** on the Creator Dashboard.
   `CreateEditableImageAsync()` only loads assets owned by / shared with the experience owner,
   the Studio user, the logged-in player (client-side only), or an appropriate group.

Also note: *"Linking one `EditableImage` to multiple image-related `Content` data types
(multi-referencing) can help with memory,"* and `PromptCreatePlatformContentAsync()` will
publish an `EditableImage`-referencing object, baking the image into a real asset ID.

---

## 5. Substitutes for shaders — the full catalogue

Everything a custom shader would do, and the engine system that stands in for it.

### 5.1 Part colour and vertex tinting

`BasePart.Color : Color3` multiplies into the material's albedo. `SurfaceAppearance.Color` and
`MaterialVariant`-less `MeshPart.Color` do the same for meshes. `Decal.Color3`,
`ImageLabel.ImageColor3`, `Beam.Color`, `Trail.Color`, `ParticleEmitter.Color` are the same
multiply on their respective primitives.

- **Look:** palette variation, faction colours, damage states, day/night recolouring.
- **Cost:** free. Does **not** cost memory (one texture, N tints) and does not break batching
  for identical meshes (colour is per-instance data).
- **Idiom:** author textures **near-white grayscale** so the multiply has full range, then tint.

`ColorSequence` / `NumberSequence` are the engine's substitute for a gradient lookup: `Beam`,
`Trail` and `ParticleEmitter` all take `ColorSequence` for colour and `NumberSequence` for
transparency/size/width over their parameter. That is a real, if constrained, ramp-texture.

### 5.2 Texture atlasing and trim sheets

The performance guide's own advice: *"**Use trim sheets** to ensure maximum texture reuse in 3D
maps"* and *"consider using sprite sheets to load many smaller UI images as a single image. You
can then use `ImageLabel.ImageRectOffset` and `ImageLabel.ImageRectSize` to display portions of
the sheet."*

- **Look:** varied architecture from one texture; large UI icon sets.
- **Cost:** one texture in memory instead of N; one draw-call-friendly material instead of N.
- **Caveat:** atlased UVs and tiling do not mix — a trim sheet region cannot tile infinitely
  unless you lay it out as a strip that tiles in one axis.

### 5.3 `Decal` and `Texture` — the UV-math substitute

`Decal` stretches one image across a whole part face. `Texture` **tiles** it, and exposes the
four properties that constitute Roblox's entire user-facing UV toolkit:

| Property | Meaning |
|---|---|
| `StudsPerTileU` | *"Sets the horizontal size, in studs, of the tiled image."* |
| `StudsPerTileV` | *"Sets the vertical size, in studs, of the tiled image."* |
| `OffsetStudsU` | *"Determines the offset in studs of the rendered texture's horizontal coordinate."* |
| `OffsetStudsV` | *"...the vertical coordinate."* |

**Offset scrolling is the single most important shader substitute on the platform.** Animating
`OffsetStudsU/V` per frame is how you do conveyor belts, waterfalls, lava flow, river surfaces,
energy conduits, scrolling starfields, treadmills, and moving clouds on a plane:

```lua
-- Scrolling water surface. One Texture, zero geometry, ~free.
local RunService = game:GetService("RunService")
local tex = workspace.Water.Texture
RunService.Heartbeat:Connect(function(dt)
    tex.OffsetStudsV = (tex.OffsetStudsV + 1.5 * dt) % tex.StudsPerTileV
    tex.OffsetStudsU = (tex.OffsetStudsU + 0.4 * dt) % tex.StudsPerTileU
end)
```

Two layers of the same `Texture` on slightly offset parts, scrolling at different speeds and
different `Transparency`, gives you parallax and breaks the obvious repeat — the classic
two-layer water fake.

`Decal` additionally carries a full **PBR slot set** (`NormalMap`, `RoughnessMap`,
`MetalnessMap`, `EmissiveMaskContent` plus their `Content` variants) and, notably,
**`UVOffset : Vector2`** and **`UVScale : Vector2`** — *"Shifts the UV coordinates by adding an
offset before texture mapping"* and *"Stretches or compresses the UV coordinates by multiplying
a scale factor."* Those two are a literal UV transform exposed as properties.
`Decal.ZIndex` *"determines the rendering order when multiple decals are assigned the same
face"* — that is your layer-order control for stacked decals.

- **Cost:** *"Objects like decals, textures, and particles don't batch well and introduce
  additional draw calls."* (`performance-optimization/improve.md`) Each one is roughly a draw
  call. Use them deliberately, not as wallpaper.

### 5.4 `Beam` — the cubic Bézier textured ribbon

`Beam` is the most under-appreciated general-purpose primitive in the engine. It is not a
"laser object"; it is **an arbitrary textured, gradient-coloured, camera-facing ribbon along a
cubic Bézier curve.**

**The geometry, stated exactly** (`effects/beams.md`):

> *"Beams are configured to use a cubic Bézier curve formed by four control points."*
> - **P0** — position of `Attachment0`.
> - **P1** — `CurveSize0` studs from `Attachment0`, **in the positive X direction of `Attachment0`**.
> - **P2** — `CurveSize1` studs from `Attachment1`, **in the negative X direction of `Attachment1`**.
> - **P3** — position of `Attachment1`.

So the curve is the standard cubic Bézier

```
B(t) = (1−t)³·P0 + 3(1−t)²t·P1 + 3(1−t)t²·P2 + t³·P3,   t ∈ [0,1]

P0 = A0.WorldPosition
P1 = A0.WorldPosition + CurveSize0 * A0.WorldCFrame.RightVector     -- +X of Attachment0
P2 = A1.WorldPosition - CurveSize1 * A1.WorldCFrame.RightVector     -- −X of Attachment1
P3 = A1.WorldPosition
```

**Consequences you can exploit:** the shape depends on the *orientation* of the attachments,
not just their position. Rotating `Attachment0` swings the curve's tangent. Setting
`CurveSize0 = CurveSize1 = 0` gives a straight line. Setting them large and opposite gives an
S-curve. You can compute a point on the beam in Lua with the formula above to attach gameplay
(e.g. a projectile that follows a grapple beam).

> *"A beam renders its texture using two triangles drawn between `Segments`, and the segments
> are laid out between the two attachment points' orientation."*

Full property set and what each is for:

| Property | Use |
|---|---|
| `Attachment0` / `Attachment1` | Endpoints. |
| `CurveSize0` / `CurveSize1` | Bézier control-point distances (above). |
| `Segments : int` | Tessellation. More = smoother curve, more triangles. Drop to 1–3 for straight beams. |
| `Width0` / `Width1 : float` | Ribbon width in studs at each end. Taper a beam by making them unequal. |
| `Color : ColorSequence` | Gradient along the beam. |
| `Transparency : NumberSequence` | Fade along the beam — soft ends, pulsing. |
| `Texture` / `TextureContent` | The ribbon image. |
| `TextureMode : Enum.TextureMode` | `Stretch`: *"the texture will repeat `TextureLength` times across the beam's overall length."* `Wrap`: *"texture repetitions will equal the beam's overall length (in studs) divided by its `TextureLength`."* `Static` is **not supported for `Beam`** and behaves as `Wrap`. |
| `TextureLength : float` | Repeat length, interpreted per `TextureMode`. |
| `TextureSpeed : float` | **Scroll speed.** The engine does the scrolling for you — no per-frame Lua. |
| `LightEmission : float` | *"Determines to what degree the colors of the beam are blended with the colors behind it."* 1 = additive glow. |
| `LightInfluence : float` | *"The degree to which the beam is influenced by the environment's lighting."* 0 = unlit/self-illuminated. |
| `Brightness : float` | Scales emitted light when `LightInfluence < 1`. |
| `FaceCamera : boolean` | Billboard the segments toward the camera. |
| `ZOffset : float` | *"The distance, in studs, the beam display is offset relative to the CurrentCamera."* Your z-fighting fix for coplanar beams. |
| `Beam:SetTextureOffset(n)` | Manually set the texture cycle offset — for syncing beams. |

**`LightEmission = 1` + `LightInfluence = 0` is the "unlit additive" combination** and it is
what almost every energy/magic/glow effect wants. `LightEmission = 0` + `LightInfluence = 1`
makes the beam behave like a lit surface — correct for water, cloth banners and ribbons that
should sit in the scene.

**What `Beam` substitutes for:**

| Effect wanted | Beam configuration |
|---|---|
| Laser / energy bolt | Straight (`CurveSize = 0`), `LightEmission = 1`, `LightInfluence = 0`, thin, `TextureSpeed` high |
| God rays from a window | Wide `Width0/1`, very low `Transparency` at edges, `LightEmission = 1`, `FaceCamera = false`, several stacked at slight angles |
| Waterfall | Vertical, `LightInfluence = 1`, tiling water texture, `TextureMode = Wrap`, `TextureSpeed` moderate |
| Force field / dome shell | Many beams radially arranged, additive, animated `Transparency` |
| Grapple / rope / cable | `CurveSize` proportional to distance, gravity-suggesting S-curve, `LightInfluence = 1` |
| Magic circle | Beams laid flat in a ring, `FaceCamera = false`, scrolling rune texture |
| Speed lines | Short beams spawned around the camera, additive, high `TextureSpeed` |
| River surface | Flat beam along a spline path, `Wrap` mode, `LightInfluence = 1` |

**Cost:** `Segments + 1` quads, one draw call, transparent (so it participates in sorting).
Cheap individually; the danger is hundreds of overlapping additive beams causing overdraw.

### 5.5 `Trail` — motion-driven ribbons

`Trail` is the same ribbon primitive but the curve is **generated from the motion history of
its two attachments**, rather than from a Bézier.

| Property | Use |
|---|---|
| `Attachment0` / `Attachment1` | The two edges of the ribbon. Their *separation* is the trail's width. |
| `Lifetime : float` | *"How long each segment in a trail will last, in seconds."* |
| `MinLength` / `MaxLength` | Clamp the ribbon's extent. |
| `WidthScale : NumberSequence` | *"Scales the width of the trail over the course of its lifetime."* — taper. |
| `Color` / `Transparency` | Sequences over lifetime. |
| `Texture` / `TextureContent` / `TextureLength` / `TextureMode` | As `Beam`, with one addition: |
| `TextureMode = Static` | *"The texture will be rolled out as the attachments move, and they will remain in place until their lifetime is met. This setting is ideal for trail textures that should appear 'stamped' where rendered, such as paw prints or tire tracks."* |
| `FaceCamera`, `LightEmission`, `LightInfluence`, `Brightness` | As `Beam`. |
| `Trail:Clear()` | Wipe the ribbon — essential when teleporting an object, or you get a streak across the map. |

**`TextureMode = Static` is the sleeper feature**: footprints, tyre tracks, skid marks, blood
trails, ski tracks — all one `Trail`, no instancing, no cleanup.

- **Look:** sword arcs, vehicle tyre smoke, projectile trails, jet contrails, footprints.
- **Cost:** as `Beam`, plus the engine retaining motion history. `Trail:Clear()` on teleport.

### 5.6 `ParticleEmitter`, and flipbooks as animated shading

`ParticleEmitter` is the general sprite system. The properties that matter for *looks* rather
than motion: `Texture`/`TextureContent`, `Color : ColorSequence`,
`Transparency : NumberSequence`, `Size : NumberSequence`, `LightEmission`, `LightInfluence`,
`Squash : NumberSequence` (*"values greater than 0 cause particles to both shrink horizontally
and grow vertically"* — free non-uniform stretch, i.e. speed-streak particles),
`Orientation : Enum.ParticleOrientation`, and `ZOffset`.

**Flipbooks are the closest thing Roblox has to an animated procedural texture.**
(`effects/particle-emitters.md`)

| Property | Values / behaviour |
|---|---|
| `FlipbookLayout` | `None`, `Grid2x2` (4 frames), `Grid4x4` (16), `Grid8x8` (64), `Custom` (via `FlipbookSizeX`/`FlipbookSizeY`). |
| `FlipbookFramerate` | FPS, min/max randomisable, **maximum 30 fps**. |
| `FlipbookMode` | `Loop`; `OneShot` (*"framerate is determined by the particle's `Lifetime` divided evenly by the number of frames"*); `PingPong`; `Random` (*"play the frames in a random order, **blending/crossfading** from one frame to the next"*). |
| `FlipbookStartRandom` | Each particle starts on a random frame. |

Two authoring rules the docs state as hard requirements:

1. ***"When you create a flipbook texture, include spacing between each of the particle frames.
   In some cases, mip filtering might require even more spacing."*** Without padding, mipmaps
   bleed adjacent frames into each other and you get ghosting.
2. ***"Features with custom textures such as flipbooks cost memory to render. If you use many
   flipbooks... clients automatically deactivate flipbooks when they are low on memory, which is
   likely for older mobile phones."*** A 1024×1024 8×8 flipbook is 64 frames of 128×128 —
   acceptable; ten of them on a phone is not, and the engine will silently turn them off.

**Two non-obvious tricks:**
- `FlipbookStartRandom = true` with `FlipbookFramerate = 0` turns a flipbook into a **random
  static variant picker** — *"causing each emitted particle to be a static frame chosen randomly
  from the flipbook texture."* That is free per-particle variety from one texture.
- `FlipbookMode = Random` crossfades, which is *"useful for organic particle textures at low
  framerates, such as stars slowly twinkling."*

- **Cost:** particles are transparent quads; overdraw is the killer. The performance guide
  warns specifically that *"property changes to `ParticleEmitters` can have a dramatic impact on
  performance."* Budget by **screen area covered**, not particle count: 50 small particles are
  cheaper than 5 fullscreen ones.

### 5.7 `Highlight` — silhouette and outline shading

`Highlight` gives you a fill + outline on an `Adornee`, which is what an outline/rim-light
shader would otherwise do.

| Property | Use |
|---|---|
| `Adornee` | The `Instance` (part or model) highlighted. |
| `FillColor` / `FillTransparency` | Interior overlay. |
| `OutlineColor` / `OutlineTransparency` | Silhouette edge. |
| `DepthMode` | `AlwaysOnTop` (0) — *"display regardless if there are objects between the camera and the highlighted object"*; `Occluded` (1) — *"hides the Highlight if there are objects between the camera and the highlighted object."* |
| `Enabled` | Toggle. |

**The hard limit, from the class docs:** *"As a performance limit, Studio only displays **255
simultaneous `Highlight` instances** on the client at a time. If you exceed this limit, the
additional instances are silently **ignored**. Note that while a `Highlight` with `Enabled` set
to `false` doesn't display, it **still takes one of the 255 available slots**, so if you plan to
permanently disable a `Highlight` instance, it's best to **delete it rather than disable it**."*

That is a budget you must manage: **pool `Highlight` instances, do not create one per object.**
A single `Highlight` whose `Adornee` you reassign is the correct pattern for hover/selection.

- **Look:** interactable affordance, outlined enemies through walls (`AlwaysOnTop`), selection
  feedback, a cel-shaded outline pass if applied broadly (`FillTransparency = 1`,
  `OutlineTransparency = 0`).
- **Cost:** a stencil/silhouette pass per highlight. Real but modest; the 255 cap is the binding
  constraint.

### 5.8 Adornments (`SelectionBox`, `BoxHandleAdornment`, `SphereHandleAdornment`, …)

3D `GuiBase3d`/`PVAdornment` objects drawn without geometry: `SelectionBox` (wireframe box with
`LineThickness`, `SurfaceColor3`, `SurfaceTransparency`), `BoxHandleAdornment`,
`SphereHandleAdornment`, `CylinderHandleAdornment`, `ConeHandleAdornment`, `LineHandleAdornment`,
`ImageHandleAdornment`. They accept `AlwaysOnTop` and `ZIndex`.

- **Look:** debug visualisation, build-mode grids and placement previews, targeting reticles,
  area-of-effect indicators, holographic UI in world space.
- **Cost:** cheap, but each is a draw call and they are transparent. Fine for a handful,
  not for hundreds.

### 5.9 `ViewportFrame`

A GUI object that renders a *separate* 3D scene into a rectangle, with its own `CurrentCamera`
and its own contents. Per the skybox guide: *"The `Sky` object can be used as a **cubemap for
reflections in `ViewportFrames`**."*

- **Look:** inventory item previews with live rotation, character preview in a shop, minimaps,
  security-camera monitors, portals, "render texture" effects, 3D icons in 2D UI.
- **Cost:** **a second scene render.** This is the most expensive thing in this list per pixel.
  Keep viewport frames small, few, and static where possible; do not animate a dozen of them.
  It is also the only way to composite genuinely separate 3D content into the frame, which is
  what makes it worth the cost when you need it.

### 5.10 `SurfaceGui` and `BillboardGui` as render surfaces

`SurfaceGui` maps a 2D GUI onto a part's face; `BillboardGui` maps one to a camera-facing quad
at a position. Because you can put `Frame`s, `ImageLabel`s, `UIGradient`s, `UIStroke`s and
`TextLabel`s inside them, they are a full 2D compositing system pasted onto 3D geometry.

- **Look:** screens and monitors, animated signage, holograms, health bars, damage numbers,
  nameplates, arbitrary animated patterns on a surface (via `UIGradient` rotation, tweened
  `ImageRectOffset` sprite sheets, or an `EditableImage`).
- **Key properties:** `SurfaceGui.PixelsPerStud` (resolution — the direct cost knob),
  `LightInfluence` (0 = self-lit/unlit, 1 = lit by the scene), `AlwaysOnTop`, `Adornee`,
  `MaxDistance` (culling), `SizingMode`.
- **Cost:** a GUI render per surface, plus transparency. `PixelsPerStud` is quadratic in cost —
  halving it quarters the work. `MaxDistance` culling is mandatory for anything repeated.
- **Trick:** `SurfaceGui` with `LightInfluence = 0` is the cheapest reliable way to get a
  perfectly flat, perfectly readable emissive panel — better than `Neon` because you control
  the exact pixels.

### 5.11 Layered transparent geometry

Stacking two or three slightly offset semi-transparent surfaces produces effects a shader would
otherwise do with a fresnel or a parallax step: fake subsurface scattering on foliage, depth in
glass, holographic shimmer, interior parallax behind windows, atmospheric layering.

- **Cost:** **the most dangerous item in this document.** Every transparent layer is full
  overdraw of the pixels it covers, cannot early-z-reject, and must be depth-sorted. Three
  layers over a full screen is 3× fill. On mobile this is the classic cause of a 60 → 12 fps
  collapse. See §6.4.
- **Discipline:** cap layer count (2 is usually enough), keep layers small in screen area, and
  prefer an alpha-tested cutout (`AlphaMode = Transparency` with `MeshPart.Transparency = 0`)
  wherever soft edges are not essential.

### 5.12 `EditableImage`-generated animated textures

The only true *procedural texture generation* on the platform. `AssetService:CreateEditableImage`
/ `CreateEditableImageAsync`, then `DrawCircle`, `DrawRectangle`, `DrawLine`, `DrawImage`,
`DrawImageTransformed`, `DrawImageProjected`, `WritePixelsBuffer`/`ReadPixelsBuffer`.

- **Look:** damage/decal systems that paint onto a surface, player-drawn canvases, dynamic
  minimaps, generated skyboxes, procedurally varied props, avatar customisation, heat maps,
  data-driven textures.
- **Cost and hard limits** (§4.6): **1024×1024 max, fixed at creation; exactly one
  `EditableImage` updated per frame on the display side; account verification required.**
- **Cannot** drive `SurfaceAppearance`/`MaterialVariant` PBR maps at runtime (PluginSecurity).
  Route generated textures through `MeshPart.TextureContent`, `Decal.TextureContent`,
  `Texture.TextureContent`, `ImageLabel.ImageContent`, `Beam`/`Trail`/`ParticleEmitter`
  `TextureContent`, or `Sky.Skybox*Content`.
- **The one-update-per-frame rule is the design constraint.** Architect around a single
  "canvas" image that everything shares, not many small animated images.

### 5.13 Terrain water as a free water shader

`Terrain` exposes `WaterColor`, `WaterTransparency`, `WaterReflectance`, `WaterWaveSize` and
`WaterWaveSpeed`. That is a complete, animated, reflective, refractive water system with no
shader and no cost you control beyond the terrain itself. If your scene can use terrain water,
**use it** — nothing you build out of parts and beams will match it. Its limitation is that it
is terrain-bound and globally uniform per place.

---

## 6. Rendering performance

All quoted text in this section is from `performance-optimization/improve.md` unless noted.

### 6.1 Draw calls and what breaks batching

> *"A draw call is a set of instructions from the engine to the GPU to render something. Draw
> calls have significant overhead. Generally, the fewer draw calls per frame, the less
> computational time is spent rendering a frame."*

**Measure it:** Studio → **Render Stats → Timing**; in the client, **Shift+F2**.

**The exact instancing rule**, stated by Roblox:

> *"Multiple meshes with the same `MeshPart.MeshContent` are handled in a single draw call when:
> — `SurfaceAppearance`s are identical if present, otherwise when `MeshPart.TextureContent`s are
> identical. — Materials are identical when both `SurfaceAppearance` and `MeshPart.TextureID`
> don't exist."*

So instancing requires **same mesh asset** *and* **same texture/`SurfaceAppearance` identity**.
That yields the definitive list of **what breaks batching**:

1. **Different `MeshId`/`MeshContent`** — even for visually identical meshes. This is the
   #1 real-world cause and it comes from a specific mistake: *"A common cause of this problem
   is when an entire scene is imported at once, rather than individual assets being imported
   into Roblox and then duplicated post-import to assemble the scene."* Roblox ships a
   diagnostic script for it; the ideal output is `LargeRock, rbxassetid://… (x144)` on one line.
2. **Different `SurfaceAppearance` instances** on otherwise identical meshes.
3. **Different `TextureID`/`TextureContent`**.
4. **Mixed presence** — one copy with a `SurfaceAppearance`, one without.
5. **`Decal`s, `Texture`s and particles**: *"Objects like decals, textures, and particles don't
   batch well and introduce additional draw calls."*
6. **Transparency** — transparent surfaces are sorted and drawn separately from opaque ones.
7. **High object density**: *"If a large number of objects are concentrated with a high density,
   then rendering this area of the scene requires more draw calls. If you are finding your frame
   rate drops when looking at a certain part of the map, this can be a good signal that object
   density in this area is too high."*

Note what does **not** break batching: **`BasePart.Color` / `MeshPart.Color` /
`SurfaceAppearance.Color` tinting.** Colour is per-instance. This is why the tint-a-grayscale-
texture pattern (§4.4) is doubly good — it saves memory *and* preserves instancing.

**Mitigations Roblox names:** upload each mesh once and duplicate in Studio; use **Packages**
for reuse; import maps asset-by-asset rather than whole.

### 6.2 Culling

> *"By default, the engine skips draw calls for objects outside the camera's field of view
> (frustum culling) and parts, meshes, and terrain occluded from view by other objects
> (occlusion culling). In certain scenarios, such as indoor environments, you might be able to
> implement a room or portal system and manually cull objects."*

Frustum **and** occlusion culling are automatic. Manual room/portal culling (parenting a room's
model in and out of `Workspace`, or toggling `Model` visibility) still pays off for dense
interiors, and is the same mechanism you use to turn local lights on and off per room.

### 6.3 `RenderFidelity` and LOD

`MeshPart.RenderFidelity : Enum.RenderFidelity`, with the distance table from
`enums/RenderFidelity.yaml`:

| `Automatic` (0) — distance-driven | Fidelity |
|---|---|
| < 250 studs | Highest |
| 250–500 studs | Medium |
| ≥ 500 studs | Lowest |

`Precise` (1) — *"rendered in the highest fidelity regardless of its distance from the camera."*
`Performance` (2) — *"Push performance as much as possible... the performance will always be
excellent, but mesh visuals may be affected negatively."*

> *"Scenes with the `MeshPart.RenderFidelity` property set to `Precise` on too many meshes"* is
> called out as a common problem.

**Rule:** `Automatic` by default. `Precise` only for hero assets the player inspects up close
(a held weapon, a shop display, a boss). `Performance` for background set dressing, distant
terrain props, and anything repeated hundreds of times.

**Beyond `RenderFidelity`, Roblox now exposes SLIM LOD:**
> *"Enable instance streaming and set your world models' `Model.LevelOfDetail` property to
> `Enum.ModelLevelOfDetail.SLIM` to render optimized lightweight SLIM meshes for models as
> distance from the camera increases."* And for characters: *"set `Workspace.EnableSLIMAvatars`
> to render platform avatars as optimized lightweight SLIM representations with full animation
> support as distance from the camera increases."*

Also: *"Although not as important as the number of draw calls, the number of triangles in a
scene does influence how long a frame takes to render."* Draw calls first, triangles second.

### 6.4 Transparency and sort cost

> *"**High transparency overdraw** — Placing objects with partial transparency near each other
> forces the engine to render the overlapping pixels multiple times, which can hurt performance."*

Why it is worse than it sounds: a transparent surface (a) cannot be rejected by the depth test,
so every pixel it covers is shaded; (b) must be **sorted back-to-front**, which costs CPU and
produces visible sorting errors when surfaces intersect; (c) multiplies with every other
transparent layer over the same pixels.

Practical rules:
- **Count layers along the view ray, not objects.** Two overlapping transparent walls, a
  particle system, a `Beam` and a `SurfaceGui` in the same line of sight is 5× fill.
- **Prefer alpha-test to alpha-blend.** `SurfaceAppearance.AlphaMode = Transparency` with
  `MeshPart.Transparency = 0` gives cutout behaviour that is depth-correct and cheap, and
  *"works better with depth-based effects and occlusion"* (§4.4). Foliage, fences, grates.
- **Use `ZOffset`** on `Beam`/`ParticleEmitter`/`SurfaceGui` to resolve sorting fights rather
  than nudging geometry.
- **Budget particles by screen area covered**, not by count.

### 6.5 Shadow cost

> *"**Excessive shadow casting** — Handling shadows is an expensive process, and maps that
> contain a high number and density of light objects that cast shadows (or a high number and
> density of small parts influenced by shadows) can have performance issues."*

Roblox's own mitigation list, verbatim in substance:

- *"The Roblox engine automatically degrades shadow quality as client graphics quality level
  decreases, **eventually disabling shadows altogether at quality levels below 4**."*
- *"Use the `BasePart.CastShadow` property to disable shadow casting on small parts where
  shadows are unlikely to be visible. This strategy is particularly effective when applied to
  parts that are far away from the user's camera."* (With the warning: *"This might result in
  visual artifacts on shadows."*)
- *"Disable shadows on moving objects when possible."*
- *"Disable `Light.Shadows` on light instances where the object does not need to cast shadows."*
- *"**Limit the range and angle** of light instances."*
- *"**Use fewer light instances.**"*
- *"Consider **disabling lights that are outside of a specific range or on a room-by-room
  basis** for indoor environments."*

The "quality level below 4 disables shadows" fact is load-bearing for art direction: **if your
look depends on shadows, a meaningful fraction of your players will never see it.** Design a
scene that still reads with shadows off — usually by ensuring value separation comes from
`Ambient`/`OutdoorAmbient` and material choice, not only from shadowing.

### 6.6 Other engine-level traps Roblox calls out

- **Skinned `MeshPart` movement:** *"Skinned MeshParts that are part of a Model without a
  Humanoid are grouped using spatially-organized FastClusters. When these MeshParts move, they
  must be continually added to and removed from these spatial clusters, forcing the clusters to
  be rebuilt."* The documented workaround is to **embed a `Humanoid` in the Model**, which
  *"mandates the use of a single, unified FastCluster for the entire Model"* — but *"this
  technique should be reserved exclusively for MeshParts with expected movement, as it may
  introduce memory overhead."*
- **Too many parts in one `Model`:** *"could cause rebuilds more often due to the potential for
  a part's property to change leading to requiring a full rebuild."*
- **Avatar hierarchy churn:** *"For custom procedural animations, don't update the
  `JointInstance.C0`/`C1` properties. Instead, update the `Motor6D.Transform` property."* And
  *"if you need to attach any `BasePart` objects to the avatar, do so **outside** the hierarchy
  of the avatar `Model`."*

### 6.7 MicroProfiler scopes worth knowing

| Scope | What it measures |
|---|---|
| `Prepare and Perform` | Overall rendering |
| `Perform/Scene/computeLightingPerform` | Light grid and shadow updates |
| `LightGridCPU` | Voxel light grid updates |
| `ShadowMapSystem` | Shadow mapping |
| `Perform/Scene/UpdateView` | Render preparation and **particle updates** |
| `Perform/Scene/RenderView` | Rendering and **post-processing** |

If `LightGridCPU` is hot, you have too much moving geometry invalidating the voxel grid. If
`ShadowMapSystem` is hot, you have too many shadow-casting lights. If `UpdateView` is hot, it is
your particles. These map one-to-one onto the levers above.

### 6.8 Graphics quality levels and what they disable

`Enum.SavedQualitySetting` runs `Automatic` (0) plus `QualityLevel1` … `QualityLevel10`, with
*"level 1 — the lowest explicit quality setting"* and *"level 10 — the highest."*
`UserGameSettings.SavedQualityLevel` is *"saved across sessions and applied as the initial
quality setting on next launch."* The related `Enum.QualityLevel` is the runtime rendering level.

The only degradation threshold Roblox states numerically is the shadow one: **shadows are
disabled entirely below quality level 4.** Beyond that, as quality drops the engine reduces
render distance, shadow resolution, texture resolution, post-processing effects, particle
counts and mesh detail — and `Lighting.PrioritizeLightingQuality` (§1.3) is the property that
tells it *which* of those to sacrifice first.

`[UNVERIFIED — a precise per-level table of exactly which features are disabled at each of
levels 1–10 is not published by Roblox. Treat level-specific claims found in community posts
with suspicion and test on real low-end hardware instead.]`

**The practical consequence:** you should have a client-side quality-response system.

```lua
-- LocalScript. Scale your own effects in sympathy with the device's level.
local UserSettings = UserSettings():GetService("UserGameSettings")
local Lighting = game:GetService("Lighting")

local function applyQuality()
    local q = UserSettings.SavedQualityLevel.Value  -- 0 = Automatic, 1..10
    local low = (q ~= 0 and q <= 4)
    for _, fx in ipairs(Lighting:GetChildren()) do
        if fx:IsA("DepthOfFieldEffect") or fx:IsA("SunRaysEffect") then
            fx.Enabled = not low                      -- most expensive first
        end
    end
    local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
    if clouds then clouds.Enabled = not low end
end

UserSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(applyQuality)
applyQuality()
```

### 6.9 `StreamingEnabled`'s role

`Workspace.StreamingEnabled` makes the server send only the region of `Workspace` near each
player, and reclaim it as they move away. It is primarily a **memory and load-time** feature,
but it has direct rendering consequences:

- Fewer instances resident ⇒ fewer candidates for draw calls, less light-grid work, less
  physics.
- It is the **prerequisite for SLIM LOD**: *"Enable instance streaming and set your world
  models' `Model.LevelOfDetail` property to `SLIM`."* No streaming, no SLIM.
- `Model.ModelStreamingMode` (`Default`, `Atomic`, `Persistent`, `PersistentPerPlayer`,
  `Nonatomic`) controls per-model streaming behaviour — `Atomic` keeps a model together,
  `Persistent` never streams it out (use for the things that must always exist).
- Tuning knobs: `StreamingTargetRadius` (the distance the client tries to keep loaded),
  `StreamingMinRadius` (the always-loaded core) and `StreamOutBehavior`.

**The rendering trap:** streaming causes **pop-in** at the streaming radius. The art-direction
fix is `Atmosphere` — set `Density` high enough and `Offset` low enough that the streaming
boundary sits inside the fog. This is the clearest example in the engine of an art tool solving
a technical problem, and it is why large open-world Roblox games are almost always foggy.

---

## 7. Texture memory

### 7.1 The bytes-per-texture math

Roblox states the shape of the rule precisely:

> *"Graphics memory consumption for a texture is unrelated to the size of the texture on the
> disk; **the number of pixels in the texture determines memory usage**. For example, a
> 1024×1024 pixel texture consumes **four times** the graphics memory of a 512×512 texture."*
>
> *"Images uploaded to Roblox are **transcoded to a fixed format**, so there is **no memory
> benefit to uploading images in a color model associated with fewer bytes per pixel**.
> Similarly, compressing images prior to upload or **removing the alpha channel from images that
> don't need it can decrease image size on disk, but doesn't improve memory usage**."*

That second paragraph kills three common "optimisations": uploading JPEG instead of PNG,
stripping alpha, and pre-compressing. None of them help GPU memory. **Only pixel count does.**

The working model (4 bytes/pixel uncompressed-equivalent, plus a full mip chain which adds
1/3 more):

```
bytes ≈ width × height × 4 × 4/3
```

| Resolution | Pixels | ≈ bytes (4bpp + mips) |
|---|---|---|
| 128×128 | 16 K | ~87 KB |
| 256×256 | 65 K | ~350 KB |
| 512×512 | 262 K | ~1.4 MB |
| 1024×1024 | 1.05 M | ~5.6 MB |
| 2048×2048 | 4.19 M | ~22.4 MB |

`[UNVERIFIED — the 4 bytes/pixel figure and the ×4/3 mip factor are the standard RGBA8 + full
mip chain model, and match Roblox's stated "4× for 2× resolution" relationship. Roblox does not
publish the exact transcoded on-GPU format, which on most platforms will be a block-compressed
format (BC/ASTC/ETC) using materially fewer bytes. Use the table for **relative** budgeting,
which is what it is good for, not as an absolute byte count.]*

**A PBR set multiplies this.** A `SurfaceAppearance` with ColorMap + NormalMap + RoughnessMap +
MetalnessMap at 1024² is **four textures**, ~22 MB by the model above. This is why PBR is a
hero-asset technique on Roblox, not a universal one.

### 7.2 Resolution discipline

Roblox's own guidance is unusually concrete and you should adopt it as policy:

> *"**Limit the pixels of images** to no more than the necessary amount. Unless an image is
> occupying a large amount of physical space on the screen, it usually needs **at most 512×512
> pixels. Most minor images should be smaller than 256×256 pixels.**"*

A working budget table:

| Asset class | Resolution |
|---|---|
| Hero asset the player inspects up close (weapon, boss, shop item) | 1024² (and only the ColorMap; share normal/roughness) |
| Standard environment prop | 512² |
| Small prop, background set dressing | 256² |
| UI icon | 128²–256², atlased into a sprite sheet |
| Tiling material / trim sheet | 512²–1024² (shared across dozens of assets — worth the budget) |
| Particle sprite | 128²–256² |
| Flipbook (8×8 = 64 frames @128²) | 1024² |
| Skybox face | 1024²–2048² (six of them; this is the biggest single memory item in most places) |

### 7.3 Mipmapping and streaming

> *"As a game loads, the engine automatically starts with lower quality textures and then ramps
> up quality based on available device memory, distance from the camera, amount of screen-space
> that the texture takes up, and other factors."*

Mipmaps are generated and used automatically — you do not control them, but you must **author
for them**:

- **Pad flipbook and atlas frames.** *"When you create a flipbook texture, include spacing
  between each of the particle frames. In some cases, mip filtering might require even more
  spacing."* At low mip levels, adjacent atlas cells bleed into each other. Padding is the fix.
- **Expect thin high-contrast detail to vanish at distance.** Wires, text, fine trim: they mip
  away to grey. If a detail must read at range, put it in the silhouette (geometry) or in a
  large-scale value change, not in a fine texture pattern.
- **`SurfaceAppearance.ResampleMode = Pixelated`** disables the smoothing filter — the correct
  and only choice for deliberate pixel-art looks.

### 7.4 The mobile ceiling

Roblox is a majority-mobile platform. The relevant engine behaviours:

- **The engine deactivates features under memory pressure without telling you.**
  *"Clients automatically deactivate flipbooks when they are low on memory, which is likely for
  older mobile phones."* Your effect simply will not appear.
- **Shadows are off below quality level 4.**
- Texture quality is scaled down automatically based on *"available device memory, distance
  from the camera, amount of screen-space."*

**Therefore:** design so that removing shadows, post-processing, clouds and flipbooks still
leaves a coherent image. That means the look must be carried by **albedo values, palette and
silhouette** — which is exactly the §8 argument.

**Mitigations Roblox names**, all of which are texture-memory strategies:
*"Only upload assets once"*; *"Find and fix duplicate assets"*; *"Instead of using separate
textures for different colors, upload a single texture and use the `SurfaceAppearance.Color`
property to apply various tints"*; *"Import assets in map separately"*; *"Use trim sheets"*;
*"consider using sprite sheets... with `ImageRectOffset` and `ImageRectSize`."*

And on preloading: *"a common mistake is overutilizing `ContentProvider:PreloadAsync()` to
preload more assets than are actually required. An example of a bad practice is loading the
entire `Workspace`."* Preload only *"images in the loading screen, important images in your game
menu, important assets in the starting or spawning area."*

---

## 8. Art direction — how the best-looking Roblox experiences get their look

### 8.1 The default-Roblox look, diagnosed

"Looks like Roblox" is not a technical limit; it is a set of five defaults nobody changed:

1. **`Technology = Voxel` / `LightingStyle = Soft` with no other lighting work.** Flat,
   shadowless, no directional read.
2. **No `Atmosphere`.** No aerial perspective ⇒ no depth ⇒ diorama.
3. **`Ambient = [0,0,0]`, `OutdoorAmbient = [127,127,127]`, `Brightness = 2`.** Neutral grey
   fill everywhere; nothing has a colour temperature.
4. **`EnvironmentDiffuseScale = 0`, `EnvironmentSpecularScale = 0`.** Nothing reflects anything;
   metal is grey plastic.
5. **Unconstrained `BrickColor` palettes.** Every part a different fully-saturated hue from the
   1960s colour picker.

Fixing 1–4 takes ten minutes (§9.1). Fixing 5 takes discipline and matters more than all the
rest.

### 8.2 Palette discipline

The single strongest differentiator between amateur and professional Roblox work is
**how many hues are in the frame**.

- **Pick 5–7 hues total for an environment and derive everything from them.** Not 5–7 colours —
  5–7 *hues*, each expressed across a range of value and saturation.
- **Keep saturation low in the environment and high only on gameplay-critical objects.** This is
  a readability mechanism, not just taste: if the world is desaturated and the pickup is
  saturated orange, the player finds the pickup without a marker. If everything is saturated,
  nothing is.
- **Use one warm/cool axis consistently.** Warm key light + cool shadows (`Ambient` cool,
  `OutdoorAmbient`/sun warm) is the default of nearly every film and game, because it produces
  colour separation between lit and unlit surfaces for free.
- **`SmoothPlastic` + a disciplined `Color3` beats a badly-lit PBR mesh.** Stylized Roblox
  experiences with tiny asset budgets routinely look better than realistic ones with big budgets
  for exactly this reason.

### 8.3 Value contrast and readability

Squint at a screenshot. If gameplay-critical elements do not separate from the background in
pure value (convert it to greyscale), players will miss them regardless of colour.

- **Reserve the brightest values and the darkest values for the things that matter.** Let the
  environment occupy the middle of the value range. `ExposureCompensation` slightly negative
  plus a `ColorCorrectionEffect` with a small positive `Contrast` does this globally.
- **Silhouette first.** Roblox's default camera distance is far enough that fine texture detail
  is invisible. The shape read is what the player gets. This is also mip-safe (§7.3) and
  quality-level-safe (shadows off below level 4).
- **Do not use bloom or DOF to create focus.** They are post-hoc softening; focus comes from
  value contrast, colour saturation contrast, and composition.

### 8.4 Lighting setups that read as deliberate

Borrow the three-point vocabulary, adapted to Roblox's instances:

| Role | Roblox instance |
|---|---|
| **Key** | The sun — `Lighting.Brightness` + `ClockTime` + `GeographicLatitude` for angle |
| **Fill** | `OutdoorAmbient` and `EnvironmentDiffuseScale` (sky-derived, dynamic) |
| **Ambient / shadow floor** | `Lighting.Ambient` — the colour of everything the sun does not reach |
| **Practical / rim** | `SpotLight` and `SurfaceLight` placed as in-world fixtures |
| **Specular / sheen** | `EnvironmentSpecularScale` + `RoughnessMap`/`MetalnessMap` |

Four patterns that consistently look good:

- **Low-angle key.** High `GeographicLatitude` (55–70) or `ClockTime` near 7 or 17. Long raking
  shadows describe form and terrain. Costs nothing.
- **Colour-separated key and fill.** Warm sun (`ColorShift_Top` is vestigial; do it via
  `ColorCorrectionEffect.TintColor` and `Atmosphere.Color`/`Decay`), cool `Ambient`.
- **Practicals that motivate the light.** Every pool of light in an interior should have a
  visible fixture. Players read "this is lit" as arbitrary unless they see the lamp.
- **Negative fill.** Set `Ambient` genuinely dark (`[15,18,25]`) and let `SurfaceLight`s do the
  work. This is how horror and noir looks get their depth — and it is one property.

### 8.5 Concrete examples worth studying

The strongest citable examples are Roblox's own, because they ship as **editable place files**
you can open in Studio and read the property values directly:

- **Beyond the Dark (Vistech Showcase)** — `roblox.com/games/7208091524`. Roblox describes it as
  *"an official Roblox game used to showcase Studio's various features and tools to create a
  high-fidelity environment... **non-copylocked and editable in Studio**."* It is the
  best-documented high-fidelity Roblox environment in existence, with accompanying articles on
  modular architecture, custom skinned characters, layered clothing, sound design and UI
  (including a **parallax map effect** built from layered 2D — a §5.11 technique).
  **Open it and read the `Lighting`, `Atmosphere` and `SurfaceAppearance` values.**
  (`resources/beyond-the-dark/index.md`)
- **Environment Art curriculum places** — a laser-tag FPS environment shipped in three states:
  `roblox.com/games/14447721254` (greyboxed) and `roblox.com/games/14447845297` (optimized).
  Comparing the greybox to the finished version is the single most instructive exercise
  available, because the gameplay geometry is identical and *only the art direction differs*.
  The curriculum also documents the **trim-sheet workflow** (`resources/beyond-the-dark/
  building-architecture.md#create-trim-sheets`) and the **layered-transparency audit**.
- **The layered-transparency case study** is worth quoting because it shows how an art decision
  becomes a performance decision: *"consider the following view of a planter in the sample
  environment. The engine must render the transparent areas of the leaves between the plant
  closest to the camera to the plant closest to the outdoor area in layers, equating to
  **hundreds of thousands of overdrawn pixels**... it's important to review the layout of all
  semi-transparent objects in your environment, and ensure there aren't too many places where
  there are many layers of overlap, especially in large areas of the screen."*
  (`tutorials/curriculums/environmental-art/optimize-your-experience.md`)

Community-recognised visual benchmarks, for reference only:
**Frontlines** and **Hellreaver Arena** (modern FPS lighting and material work),
**Livetopia** (large, coherent stylized open world), and showcase places such as
**Afternoon Glow**, **Mist** and **The Beach Cave** (pure lighting/atmosphere studies).
`[COMMUNITY, SECOND-HAND — these are press/aggregator listings of visually notable Roblox
experiences, not Roblox technical documentation, and no property values are published for them.]`

### 8.6 The transferable lesson

Look at what the good ones share and the list is short and cheap:
**an `Atmosphere`; a custom skybox that matches it; a tight palette; a warm/cool key/fill split;
`EnvironmentDiffuseScale` and `EnvironmentSpecularScale` turned on; a restrained bloom threshold
above the diffuse range; and geometry whose silhouette reads at gameplay distance.**
None of that is a shader. None of it requires an art budget. It requires knowing the levers.

---

## Shader substitutes table

| Effect wanted (what a shader would do) | Roblox technique | Cost |
|---|---|---|
| Albedo tint / material colour variant | `BasePart.Color`, `MeshPart.Color`, `SurfaceAppearance.Color` (+ `AlphaMode.TintMask`) | Free. Does **not** break batching, does **not** add texture memory. |
| Colour ramp / gradient LUT | `ColorSequence` on `Beam`/`Trail`/`ParticleEmitter`; `UIGradient` in a `SurfaceGui` | Free. |
| UV scale | `Texture.StudsPerTileU/V`; `MaterialVariant.StudsPerTile`; `Decal.UVScale` | Free. |
| UV offset / scrolling shader | Animate `Texture.OffsetStudsU/V`, or `Decal.UVOffset`; `Beam`/`Trail` `TextureSpeed` (engine-driven, no Lua) | Near free; each `Texture`/`Decal` is ≈1 draw call. |
| Anti-tiling / stochastic tiling | `MaterialVariant.MaterialPattern = Organic` | Free. |
| Normal / bump mapping | `SurfaceAppearance.NormalMap`, `MaterialVariant.NormalMap`, `Decal.NormalMap` (tangent space, OpenGL, flat = 127,127,255, mesh needs tangents) | Texture memory; no per-frame cost. |
| Metal / gloss (PBR) | `MetalnessMap` + `RoughnessMap` **plus** `Lighting.EnvironmentSpecularScale > 0` | Texture memory ×2; specular scale is ~free. |
| Emissive surface | `Material = Neon`; `SurfaceAppearance.EmissiveMaskContent` + `EmissiveStrength`/`EmissiveTint`; `SurfaceGui` with `LightInfluence = 0` | Cheap. Emissive adds to the *lighting* term then multiplies albedo. |
| Bloom / glow around emissives | `BloomEffect` with `Threshold` 1.5–2.5, `Intensity` 0.3–0.8 | One downsample/blur chain. |
| Colour grading / LUT | `ColorCorrectionEffect` (Brightness/Contrast/Saturation/multiplicative TintColor) | Per-pixel transform; effectively free. |
| Tonemapping curve | `ColorGradingEffect.TonemapperPreset` (`Default` / `Retro`) — the only tonemap control | Free. |
| Exposure control | `Lighting.ExposureCompensation` (stops, −5…+5, applied **pre**-tonemap) | Free. |
| Screen-space god rays from the sun | `SunRaysEffect` (occlusion-shaped, sun only) | Radial-blur pass; moderate. |
| Volumetric light shafts from any source | Stacked `Beam`s, `LightEmission = 1`, `LightInfluence = 0`, low-alpha gradient texture | Transparent overdraw; the cost is fill, not geometry. |
| Depth of field / focus | `DepthOfFieldEffect` (`FocusDistance` ± `InFocusRadius`, `Near/FarIntensity`) | **Most expensive standard effect** (depth + multi-tap blur). |
| Fullscreen blur (menus) | `BlurEffect.Size` under `Camera` | Proportional to `Size` × resolution. |
| Aerial perspective / distance fog | `Atmosphere` (`Density`, `Offset`, `Haze`, `Glare`, `Color`, `Decay`) | Near free. **Highest value per unit cost in the engine.** |
| Hard draw-distance cutoff | Legacy `Lighting.FogStart`/`FogEnd` (hidden when `Atmosphere` present) | Free. |
| Volumetric clouds | `Clouds` under `Terrain` (`Cover`, `Density`, `Color`); motion from `Workspace.GlobalWind` | Raymarched — the most expensive environment object. |
| Custom sky / environment map | `Sky` six-face cubemap + `SkyboxOrientation`; also the cubemap for `ViewportFrame` reflections | Texture memory (6 faces; the biggest memory item in most places). |
| Screen-space damage/status tint | Second `ColorCorrectionEffect` parented to `Camera`, tweened | Free; client-local, no replication. |
| Outline / rim / silhouette shader | `Highlight` (`FillColor`/`OutlineColor`, `DepthMode` `AlwaysOnTop`/`Occluded`) | **Hard cap of 255 instances client-side; disabled ones still consume a slot.** Pool them. |
| Arbitrary curved textured ribbon | `Beam` — cubic Bézier, `Width0/1`, `Segments`, `ColorSequence`, `TextureSpeed`, `ZOffset` | `Segments+1` quads, 1 draw call, transparent. |
| Motion ribbon / tracks / footprints | `Trail` (+ `TextureMode = Static` for stamped tracks); `Trail:Clear()` on teleport | As `Beam` plus motion history. |
| Animated procedural texture | `ParticleEmitter` flipbooks (`Grid2x2`/`4x4`/`8x8`/`Custom`, max 30 fps, `Loop`/`OneShot`/`PingPong`/`Random`) | Texture memory; **auto-disabled on low-memory clients**. Pad frames for mipping. |
| Per-particle random variation | `FlipbookStartRandom = true` with `FlipbookFramerate = 0` | Free variety from one texture. |
| Non-uniform particle stretch (speed lines) | `ParticleEmitter.Squash : NumberSequence` | Free. |
| Render-to-texture / second scene | `ViewportFrame` (own camera + contents; `Sky` as reflection cubemap) | **A second scene render.** Most expensive item here per pixel. |
| 2D compositing on a 3D surface | `SurfaceGui` (`PixelsPerStud`, `LightInfluence`, `MaxDistance`) / `BillboardGui` | GUI render per surface; `PixelsPerStud` is quadratic. |
| Debug / world-space overlays | `SelectionBox`, `*HandleAdornment`, `ImageHandleAdornment` (`AlwaysOnTop`, `ZIndex`) | Cheap, but ≈1 draw call each and transparent. |
| Fresnel / parallax / fake SSS | Layered semi-transparent geometry (2 layers max) | **Full overdraw per layer.** The #1 mobile frame-rate killer. |
| Procedurally generated texture | `EditableImage` → `MeshPart.TextureContent`, `Decal`, `Texture`, `ImageLabel`, `Beam`, `Trail`, `ParticleEmitter`, `Sky.Skybox*Content` | ≤1024², **one update per frame globally**, account verification required. |
| Runtime-generated **PBR** maps | **Not available to game scripts.** `SurfaceAppearance`/`MaterialVariant` `*MapContent` are `PluginSecurity`. | — |
| Animated water | Terrain `Water` (`WaterColor`, `WaterTransparency`, `WaterReflectance`, `WaterWaveSize`, `WaterWaveSpeed`); or scrolling `Texture` layers; or a flat `Beam` | Terrain water is free and unbeatable — but terrain-bound and global per place. |
| Pixel-art / nearest-neighbour filtering | `SurfaceAppearance.ResampleMode = Pixelated` | Free. |
| Global material re-skin | `MaterialService:SetBaseMaterialOverride(Enum.Material.X, "VariantName")` — also the **only** way to skin terrain | Free at runtime; one variant per base material, globally. |

---

## Lighting recipes

Each recipe is a complete property set. Apply to `Lighting` and its children unless noted.

### 9.1 Good lighting in 10 minutes (the universal baseline)

The highest-value 10 minutes you will ever spend on a Roblox project.

```lua
local Lighting = game:GetService("Lighting")

-- 1. Technology / style (Technology itself is Studio-only and non-scriptable).
--    In Studio: Lighting.Technology = Future  (or LightingStyle = Realistic)
Lighting.LightingStyle = Enum.LightingStyle.Realistic
Lighting.PrioritizeLightingQuality = true

-- 2. Sun angle: low latitude sun is harsh; high latitude rakes. 17:00 + lat 55 = warm raking.
Lighting.ClockTime          = 16.5
Lighting.GeographicLatitude = 55
Lighting.Brightness         = 2.2
Lighting.GlobalShadows      = true
Lighting.ShadowSoftness     = 0.25

-- 3. Colour-separated fill. Cool shadows, neutral-cool sky fill. NEVER leave Ambient black.
Lighting.Ambient        = Color3.fromRGB(48, 54, 68)     -- shadow floor (cool)
Lighting.OutdoorAmbient = Color3.fromRGB(96, 104, 118)   -- sky fill; must be >= Ambient per channel

-- 4. Turn PBR on. These default to 0 and that default is why places look flat.
Lighting.EnvironmentDiffuseScale  = 0.6
Lighting.EnvironmentSpecularScale = 0.6

-- 5. Give the frame a real black point.
Lighting.ExposureCompensation = -0.35

-- 6. Atmosphere. The single biggest visual win available.
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.35
atmo.Offset  = 0.15
atmo.Haze    = 1.6
atmo.Glare   = 0.5
atmo.Color   = Color3.fromRGB(210, 205, 195)
atmo.Decay   = Color3.fromRGB(120, 125, 140)
atmo.Parent  = Lighting

-- 7. Restrained post. Threshold ABOVE the diffuse range is the whole trick.
local bloom = Instance.new("BloomEffect")
bloom.Threshold, bloom.Intensity, bloom.Size = 1.8, 0.55, 18
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness, grade.Contrast, grade.Saturation = -0.02, 0.10, 0.05
grade.TintColor = Color3.fromRGB(255, 252, 248)
grade.Parent = Lighting
```

Then, outside the script: add a **custom `Sky`** whose colours agree with the `Atmosphere`, and
switch your default part material from `Plastic` to `SmoothPlastic`.

### 9.2 Stylized / illustrated

Goal: flat colour fields, soft forms, no photographic contrast. Looks intentional at every
quality level, including on phones with shadows disabled.

| Property | Value |
|---|---|
| `LightingStyle` | `Soft` |
| `PrioritizeLightingQuality` | `false` (view distance matters more than shadow crispness) |
| `Brightness` | `2.8` |
| `ClockTime` | `13` (near-overhead, minimal dramatic shadow) |
| `GeographicLatitude` | `10` |
| `ShadowSoftness` | `0.9` (very soft, almost ambient occlusion) |
| `Ambient` | `[120, 118, 130]` — **high**, so shadows stay light and colourful |
| `OutdoorAmbient` | `[170, 172, 180]` |
| `EnvironmentDiffuseScale` | `0.8` |
| `EnvironmentSpecularScale` | `0.15` (low — stylized surfaces should not look wet) |
| `ExposureCompensation` | `0.15` |
| `Atmosphere.Density` | `0.25` |
| `Atmosphere.Offset` | `0.35` (silhouette distant shapes cleanly) |
| `Atmosphere.Haze` | `1.2` |
| `Atmosphere.Glare` | `0.2` |
| `Atmosphere.Color` | `[235, 238, 245]` |
| `Atmosphere.Decay` | `[190, 205, 225]` |
| `Clouds.Cover` / `Density` / `Color` | `0.55` / `0.10` / `[255,255,255]` |
| `BloomEffect` | `Threshold 2.2`, `Intensity 0.35`, `Size 12` |
| `ColorCorrectionEffect` | `Brightness 0.02`, `Contrast -0.05`, `Saturation 0.30`, `TintColor [255,252,248]` |
| `ColorGradingEffect` | `Retro` (flattens contrast — pair with the raised Saturation above) |
| `DepthOfFieldEffect` | Disabled |
| `SunRaysEffect` | Disabled |

Materials: `SmoothPlastic` almost everywhere. Palette: 5 hues, held saturation, value range
compressed into the upper-middle. No normal maps.

### 9.3 Moody horror

Goal: darkness that is legible. The mistake is making it merely dark; the fix is a dark
`Ambient` plus *motivated practical lights* so the player's eye has somewhere to go.

| Property | Value |
|---|---|
| `LightingStyle` | `Realistic` (needs local shadows) — in Studio, `Technology = Future` |
| `PrioritizeLightingQuality` | `true` |
| `Brightness` | `0.4` |
| `ClockTime` | `0` |
| `GeographicLatitude` | `41` |
| `ShadowSoftness` | `0.05` (hard, anxious shadow edges) |
| `Ambient` | `[10, 12, 18]` — near-black, cool |
| `OutdoorAmbient` | `[22, 26, 34]` |
| `EnvironmentDiffuseScale` | `0.15` |
| `EnvironmentSpecularScale` | `0.7` (wet, reflective highlights read as menace) |
| `ExposureCompensation` | `-0.6` |
| `Atmosphere.Density` | `0.55` |
| `Atmosphere.Offset` | `0.0` (let things dissolve into the dark) |
| `Atmosphere.Haze` | `3.4` |
| `Atmosphere.Glare` | `0.0` |
| `Atmosphere.Color` | `[92, 98, 105]` |
| `Atmosphere.Decay` | `[38, 42, 50]` |
| `Sky` | Dark custom skybox; `SunAngularSize = 0`, `MoonAngularSize = 6`, `StarCount ≈ 1500` |
| `BloomEffect` | `Threshold 1.2`, `Intensity 0.9`, `Size 26` (few things are bright; let them halo) |
| `ColorCorrectionEffect` | `Brightness -0.10`, `Contrast 0.22`, `Saturation -0.32`, `TintColor [222,230,240]` |
| `DepthOfFieldEffect` | `FocusDistance 18`, `InFocusRadius 14`, `NearIntensity 0`, `FarIntensity 0.85` |
| `SunRaysEffect` | Disabled |

Lights: sparse `SpotLight`s with narrow `Angle` and `Shadows = true`; everything else
`Shadows = false`. Flicker by tweening `Light.Brightness`, never by toggling `Enabled`
(toggling causes a shadow-map rebuild). Remember §6.5: **players below quality level 4 get no
shadows at all**, so keep a value read that survives without them.

### 9.4 Bright commercial

Goal: the clean, high-key, high-saturation look of a simulator or tycoon — reads instantly on a
phone thumbnail, never fatigues, never hides the UI.

| Property | Value |
|---|---|
| `LightingStyle` | `Soft` (cheap; runs everywhere) |
| `PrioritizeLightingQuality` | `false` |
| `Brightness` | `3.0` |
| `ClockTime` | `14` |
| `GeographicLatitude` | `23` |
| `ShadowSoftness` | `0.5` |
| `Ambient` | `[105, 108, 118]` |
| `OutdoorAmbient` | `[165, 168, 178]` |
| `EnvironmentDiffuseScale` | `0.7` |
| `EnvironmentSpecularScale` | `0.35` |
| `ExposureCompensation` | `0.20` |
| `Atmosphere.Density` | `0.25` |
| `Atmosphere.Offset` | `0.25` |
| `Atmosphere.Haze` | `0.9` |
| `Atmosphere.Glare` | `0.35` |
| `Atmosphere.Color` | `[245, 245, 250]` |
| `Atmosphere.Decay` | `[190, 215, 245]` |
| `Clouds.Cover` / `Density` / `Color` | `0.45` / `0.08` / `[255,255,255]` |
| `BloomEffect` | `Threshold 2.0`, `Intensity 0.45`, `Size 14` |
| `ColorCorrectionEffect` | `Brightness 0.03`, `Contrast 0.12`, `Saturation 0.28`, `TintColor [255,251,246]` |
| `DepthOfFieldEffect` | Disabled (it fights UI readability) |
| `SunRaysEffect` | `Intensity 0.10`, `Spread 0.9` |

Palette: high-saturation primaries on interactables, desaturated mid-value environment.
Materials: `SmoothPlastic` and `Neon` only, with `Neon` reserved for currency, rewards and
progress — which the `Threshold 2.0` bloom will then catch and nothing else will.

### 9.5 Golden-hour cinematic (bonus — showcase / trailer)

| Property | Value |
|---|---|
| `LightingStyle` | `Realistic`; `PrioritizeLightingQuality = true` |
| `ClockTime` / `GeographicLatitude` | `17.2` / `62` — low, long, raking |
| `Brightness` / `ShadowSoftness` | `2.6` / `0.35` |
| `Ambient` / `OutdoorAmbient` | `[42, 48, 70]` / `[88, 96, 120]` (strongly cool against the warm sun) |
| `EnvironmentDiffuseScale` / `EnvironmentSpecularScale` | `0.55` / `1.0` |
| `ExposureCompensation` | `-0.5` |
| `Atmosphere` | `Density 0.42`, `Offset 0.10`, `Haze 2.4`, `Glare 1.0`, `Color [255,215,180]`, `Decay [255,90,80]` |
| `Clouds` | `Cover 0.7`, `Density 0.14`, `Color [255,240,225]` |
| `BloomEffect` | `Threshold 1.6`, `Intensity 0.7`, `Size 22` |
| `ColorCorrectionEffect` | `Brightness -0.02`, `Contrast 0.16`, `Saturation 0.14`, `TintColor [255,246,232]` |
| `DepthOfFieldEffect` | `FocusDistance 55`, `InFocusRadius 45`, `NearIntensity 0`, `FarIntensity 0.7` |
| `SunRaysEffect` | `Intensity 0.22`, `Spread 0.95` |

The `Color`-warm / `Decay`-cool split is doing most of the work here, exactly as in the docs'
own `[255,255,255]` vs `[255,90,80]` comparison.

