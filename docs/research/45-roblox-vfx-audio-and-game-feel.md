# Roblox VFX, Audio and Game Feel

> Chapter 45 of the internal Roblox mastery corpus.
> **Audience:** the team building the full presentation layer of a large incremental/idle game.
> **Thesis:** two games with identical mechanics can feel worlds apart. This chapter is that difference.
> **Sibling chapters:** 23 (rendering/lighting/materials), 40 (EditableImage cookbook), 41 (EditableMesh cookbook), 43 (3D math toolkit), 63 (incremental UI). Cross-referenced, not duplicated.

Every engine claim below is sourced from the Roblox `creator-docs` reference YAML or the live API dump (see **Sources**). Claims that could not be verified against a primary source are marked `[UNVERIFIED]`. Community knowledge obtained only through search summaries is marked `[COMMUNITY, SECOND-HAND]`.

## Contents

1. [TL;DR](#tldr)
2. [ParticleEmitter mastery](#1-particleemitter-mastery)
3. [Beam: the general-purpose textured quad](#2-beam-the-general-purpose-textured-quad-strip)
4. [Trail](#3-trail)
5. [The juice toolkit](#4-the-juice-toolkit)
6. [Lighting as VFX](#5-lighting-as-vfx)
7. [Post-processing as feedback](#6-post-processing-as-feedback)
8. [The no-shader workarounds](#7-the-no-shader-workarounds)
9. [Audio: the other half of game feel](#8-audio-the-other-half-of-game-feel)
10. [Performance discipline](#9-performance-discipline)
11. [The make-it-feel-expensive checklist](#the-make-it-feel-expensive-checklist)
12. [Sources](#sources)

## TL;DR

- **`LightEmission` and `LightInfluence` are different axes and confusing them is the #1 cause of cheap-looking Roblox VFX.** `LightEmission` is the *blend mode* dial: 0 = alpha blending, 1 = additive blending. `LightInfluence` is the *shading* dial: 0 = particle ignores environment light and keeps full brightness, 1 = particle is lit like a `BasePart` and goes black in the dark. Fire and magic want `LightEmission ≈ 1, LightInfluence = 0`. Smoke and dust want `LightEmission = 0, LightInfluence ≈ 1`. ([ParticleEmitter.yaml](#sources))
- **`LightInfluence` has an insertion-dependent default.** Studio's insert menu gives you `1`; `Instance.new("ParticleEmitter")` gives you `0`. Effects authored in Studio and effects built in code therefore look *different by default*. Always set it explicitly. ([ParticleEmitter.yaml](#sources))
- **Your emitter budget is bytes of overdraw, not particle count.** A screen-filling additive particle at `LightEmission = 1` costs far more than ten small ones. Budget by area covered × layers, then cull by distance and by `UserSettings():GetService("UserGameSettings").SavedQualityLevel`.
- **`Beam` is not a beam.** It is a cubic-Bézier-swept textured quad strip with scrolling UVs. Treat it as your general-purpose "ribbon primitive": ground decals, connector lines between UI-adjacent world objects, conveyor belts, energy links, tether lines, rising-number ribbons, and circular ground rings.
- **The Bézier is orientation-driven, not position-driven.** P0 = `Attachment0.WorldPosition`, P1 = `CurveSize0` studs along `Attachment0`'s **+X**, P2 = `CurveSize1` studs along `Attachment1`'s **−X**, P3 = `Attachment1.WorldPosition`. Rotating an attachment with zero movement completely reshapes the beam. ([effects/beams.md](#sources))
- **Screen shake must decay as trauma², be driven by coherent noise, and never by `math.random` per frame.** Random per-frame jitter reads as a rendering glitch; smooth noise sampled along independent axes reads as impact. Give the shake rotational components, not just translational.
- **Hit-stop is 30–120 ms of frozen or near-frozen time immediately after a hit, and it is the cheapest "weight" you will ever buy.** On Roblox you implement it with `TimeScale` on emitters/explosions, by pausing tweens, and by holding a UI counter, never by changing physics timestep.
- **Springs read as alive; tweens read as authored.** `TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)` is a real critically-damped spring that returns `(newValue, newVelocity)` and supports number, `Vector2`, `Vector3`, and `CFrame`. It is public (`Security: None`) and most existing Roblox spring material predates it. ([API-Dump.json, TweenService.yaml](#sources))
- **Frame-rate-independent smoothing is `alpha = 1 - math.exp(-k * dt)`.** A bare `current = current:Lerp(target, 0.1)` inside `RenderStepped` is a bug: it converges twice as fast at 120 fps as at 60 fps.
- **Pitch randomisation on repeated sounds is the single highest ratio of perceived quality to engineering effort in the entire chapter.** One line — `sound.PlaybackSpeed = 1 + (rng:NextNumber() - 0.5) * 0.12` — removes the machine-gun sameness that marks amateur audio. Do it on every sound that can fire more than once per second.
- **Layer every important event across at least three sound slots** (transient/click, body/thump, tail/ring) with independent pitch variance and slightly different attenuation. One sample per event is what cheap games do.
- **`SoundService:GetMixerTime()` is a sample-accurate, monotonic audio clock** derived from samples processed by the mixer — the correct clock for scheduling musical stingers and beat-locked effects. `os.clock()` and `RunService` time will drift against the mixer. ([SoundService.yaml](#sources))
- **Post-processing is feedback, not set dressing.** A static `BloomEffect` is decoration; a `BloomEffect` whose `Intensity` spikes for 120 ms on a prestige is *feedback*. Animate `ColorCorrectionEffect.Saturation` and `Contrast`, and use `BlurEffect.Size` as a modal focus device.
- **Three hard engine limits to design around, not discover:** `Highlight` is capped at **255 client instances** and a *disabled* one still occupies a slot (destroy, don't disable); local light `Range` is clamped to **120 studs**; and shadows are disabled outright below graphics quality level 4, so never build a look that depends on a shadow being present.

---

## 1. ParticleEmitter mastery

`ParticleEmitter` is the workhorse. It is also where most projects leave 80% of the available quality on the table, because the properties that matter most for *looking expensive* are not the ones that are obvious in the Properties panel.

### 1.1 The two light properties — the single biggest quality lever

These two properties have similar names and completely unrelated jobs. Getting them right is most of the difference between "someone dragged a fire effect in" and "someone lit this."

**`LightEmission` (float, 0–1) is a blend-mode crossfade.**

> "Determines the blending of the `Texture` colors with the colors behind them. A value of 0 uses normal blending mode while a value of 1 uses additive blending. When changed, this property instantly affects all particles owned by the emitter, both current and future."
> — `ParticleEmitter.yaml`

It answers: *when this particle draws over what is behind it, does it replace or does it add?*

- `0` — standard alpha blending. Particle occludes what is behind it in proportion to its alpha. This is what you want for anything **opaque and physical**: smoke, dust, debris chunks, snow, leaves, fabric.
- `1` — additive blending. The particle's RGB is *added* to the framebuffer. Overlapping particles get brighter and saturate toward white. This is what you want for anything that **emits light**: fire, sparks, magic, muzzle flashes, energy, glowing coin sparkle.

Two consequences that trip people up:

1. **Under additive blending, black is invisible.** The docs state it directly on `Color`: "If an emitter has a `LightEmission` value that's greater than 0, darker colors make particles appear more transparent." This is why a greyscale texture with a hard black background looks fine at `LightEmission = 1` and looks like a black square at `LightEmission = 0`. It is also a legitimate authoring trick — a greyscale, no-alpha texture works as an additive particle without ever cutting an alpha channel. `[COMMUNITY, SECOND-HAND]` — this trick is widely repeated on DevForum; the underlying blend behaviour is documented.
2. **`LightEmission` does not light anything.** The reference is explicit: "This property does **not** cause particles to light the environment around them. To accomplish that, consider using a `PointLight`." An additive fire particle will not put orange light on the floor. If you want that, you pair the emitter with a `PointLight` (see §5).

**`LightInfluence` (float, 0–1) is a shading dial.**

> "Determines how much environmental light affects the color of individual particles when they render. It must be in the range of 0–1... At 0, particles are not influenced by light at all (they retain full brightness); at 1, particles are fully influenced by light (in complete darkness, particles will be black)."
> — `ParticleEmitter.yaml`

It answers: *does this particle participate in the scene's lighting solution, or is it self-lit?*

- `0` — unlit / emissive. The texture renders at full authored brightness regardless of time of day, `Lighting.Ambient`, or whether it is in shadow. Correct for fire, magic, UI-adjacent sparkle, and anything that should punch through at night.
- `1` — fully lit. The particle darkens in shadow and at night exactly as a part would. Correct for smoke, dust, and debris, which look *wrong* if they glow at midnight.

**The insertion-default trap.** From the reference: "By default, this value is 1 if inserted with Studio tools. If inserted using `Instance.new()`, it is 0." This means an artist's Studio-authored emitter and a programmer's `Instance.new` emitter with otherwise identical settings will not match. Every emitter your codebase creates must set `LightInfluence` explicitly, and your VFX review checklist should include "is `LightInfluence` explicit?"

**`Brightness` (float) is the gain stage for the unlit path.** It "scales the light emitted from the emitter when `LightInfluence` is 0." Use it instead of pushing `Color` past white: a `Color` of pure white with `Brightness = 4` gives you an HDR-ish overbright particle that blooms hard (§6) while keeping the hue you authored. Pushing `Color` itself just clips.

**The decision table:**

| Effect | `LightEmission` | `LightInfluence` | `Brightness` | Why |
| --- | --- | --- | --- | --- |
| Fire, flame | 1.0 | 0 | 2–5 | Emits light; must not go black at night |
| Sparks, embers | 1.0 | 0 | 3–8 | Small + very bright = reads as hot |
| Magic / mana / prestige burst | 0.8–1.0 | 0 | 2–6 | Additive, saturated, self-lit |
| Coin / currency sparkle | 1.0 | 0 | 2–4 | Wants to punch through UI-heavy scenes |
| Smoke | 0 | 0.8–1.0 | 1 | Occludes; must respond to scene light |
| Dust, dirt kick-up | 0 | 1.0 | 1 | Same |
| Debris, chunks | 0 | 1.0 | 1 | Physical matter |
| Steam / mist | 0.1–0.3 | 0.7–1.0 | 1 | Mostly physical, slight glow near a source |
| Water splash | 0.2–0.4 | 0.6–0.9 | 1–2 | Specular highlights want a little additive |

> These pairings are craft guidance, not engine specification. The *property semantics* are documented; the *values* are the author's recommended starting points. Treat as `[UNVERIFIED]` where exact numbers are concerned.

### 1.2 The emitter shape system

Four properties compose into a surprisingly capable volumetric emitter. They are all documented in `ParticleEmitter.yaml` and the corresponding `ParticleEmitterShape*` enums.

**`Shape` (`Enum.ParticleEmitterShape`)** — `Box` (0), `Sphere` (1), `Cylinder` (2), `Disc` (3). The region particles spawn in. Note the region is sized by the parent part; an emitter on an `Attachment` uses the attachment as a point.

**`ShapeStyle` (`Enum.ParticleEmitterShapeStyle`)** — `Volume` (0, default) spawns throughout the interior; `Surface` (1) spawns only on the outer surface.

**`ShapeInOut` (`Enum.ParticleEmitterShapeInOut`)** — `Outward` (0, default), `Inward` (1), `InAndOut` (2, chosen randomly per particle).

**`ShapePartial` (float)** — the overloaded one. Its meaning depends on `Shape`:

- **Cylinder** — top radius proportion. `0` turns the cylinder into a **cone**. `1` = undeformed cylinder.
- **Disc** — inner radius proportion. `0` = filled circle/ellipse. `1` = emission only on the outermost rim. Between = an **annulus** of that thickness.
- **Sphere** — the hemispherical angle over which particles emit. `1` = whole sphere. `0.5` = half dome. `0` = a single point at the north pole.

This system replaces a lot of scripted particle placement. Concrete recipes for an incremental game:

```lua
-- Prestige shockwave: a flat expanding ring on the ground.
-- Disc + Surface + rim-only + outward = a clean expanding ring, no scripting.
emitter.Shape        = Enum.ParticleEmitterShape.Disc
emitter.ShapeStyle   = Enum.ParticleEmitterShapeStyle.Surface
emitter.ShapePartial = 1        -- outermost rim only
emitter.ShapeInOut   = Enum.ParticleEmitterShapeInOut.Outward
emitter.SpreadAngle  = Vector2.new(0, 0)
```

```lua
-- "Money vacuum" collection effect: particles converge on the centre.
emitter.Shape        = Enum.ParticleEmitterShape.Sphere
emitter.ShapeStyle   = Enum.ParticleEmitterShapeStyle.Surface
emitter.ShapePartial = 1
emitter.ShapeInOut   = Enum.ParticleEmitterShapeInOut.Inward
```

```lua
-- Upward cone of light motes rising off a generator.
emitter.Shape        = Enum.ParticleEmitterShape.Cylinder
emitter.ShapePartial = 0        -- 0 top radius => cone
emitter.ShapeStyle   = Enum.ParticleEmitterShapeStyle.Volume
```

### 1.3 Orientation modes

`Orientation` (`Enum.ParticleOrientation`) picks how the quad is oriented. The reference table:

| Value | Behaviour | Use it for |
| --- | --- | --- |
| `FacingCamera` (0) | Standard camera-facing billboard quad; **default** | Almost everything: smoke, fire, sparkle, dust |
| `FacingCameraWorldUp` (1) | Faces the camera but only rotates about the world **Y** axis | Ground-anchored effects — dust columns, pillars of light, tall flames. Prevents the "billboard flips when you look down" artefact |
| `VelocityParallel` (2) | Aligned parallel to direction of movement | **Streaks**: sparks, rain, speed lines, tracer rounds. The single biggest upgrade for spark effects |
| `VelocityPerpendicular` (3) | Aligned perpendicular to direction of movement | Shockwave rings that travel, disc-shaped ripples, "slash" arcs |

`VelocityParallel` plus a short, elongated texture plus `Squash` is how you get sparks that look like sparks rather than like round dots. It is very cheap and almost never used.

### 1.4 Squash — non-uniform scale over lifetime

`Squash` is a `NumberSequence`. From the reference: "Values greater than 0 cause particles to both shrink horizontally and grow vertically, while values less than 0 cause particles to both grow horizontally and shrink vertically."

It is an *area-preserving-ish* stretch, so it is the particle-level equivalent of squash-and-stretch animation (§4.3). Uses:

- **Raindrops / sparks**: constant positive squash, paired with `VelocityParallel`.
- **Impact puffs**: start negative (wide and flat, as the puff slaps against the surface), animate toward 0 over the lifetime as it becomes a round cloud.
- **Fire licks**: gentle positive squash so flames are taller than wide.

```lua
-- Impact puff that starts flat and wide, then rounds out.
emitter.Squash = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, -0.75),
    NumberSequenceKeypoint.new(0.3, -0.2),
    NumberSequenceKeypoint.new(1.0,  0.0),
})
```

### 1.5 ZOffset — layering without sorting bugs

`ZOffset` "determines the forward-backward render position of particles, in studs, without changing their size on the screen... Positive values move particles closer to the camera and negative values move particles away. Sufficiently negative values can cause particles to render inside or behind the parent part." It accepts fractional values.

This is the *layering* control. A good explosion is not one emitter; it is four:

| Layer | `ZOffset` | Content |
| --- | --- | --- |
| Back smoke | −0.5 | Dark, `LightEmission = 0`, `LightInfluence = 1`, slow, large |
| Core flash | 0.0 | Additive white/yellow, very short lifetime |
| Fire body | +0.25 | Additive orange, flipbook |
| Sparks | +0.5 | `VelocityParallel`, tiny, very bright |

Because `ZOffset` does not change screen size, you get correct front-to-back ordering between emitters without moving anything, and without fighting transparency sort order. **Any time two emitters on the same attachment flicker against each other, the fix is `ZOffset`, not reparenting.**

### 1.6 Flipbooks

A flipbook turns the `Texture` into a sprite sheet animated over the particle's life. This is the primary "we don't have shaders" escape hatch (§7) and the difference between a rolling ball of orange and an actual fireball.

- **`FlipbookLayout`** (`Enum.ParticleFlipbookLayout`): `None` (0), `Grid2x2` (1, 4 frames), `Grid4x4` (2, 16 frames), `Grid8x8` (3, 64 frames), `Custom` (4, uses `FlipbookSizeX`/`FlipbookSizeY`).
- **`FlipbookMode`** (`Enum.ParticleFlipbookMode`): `Loop` (0), `OneShot` (1), `PingPong` (2), `Random` (3).
- **`FlipbookFramerate`** (`NumberRange`): fps, **maximum 30**. Randomisable per particle via the range.
- **`FlipbookBlendFrames`** (boolean): linear crossfade between frames instead of an instant swap.
- **`FlipbookStartRandom`** (boolean): each particle begins at a random frame.
- **`FlipbookIncompatible`** (string, read-only in practice): the error message shown when "the flipbook texture size must be an exact multiple of the flipbook layout size."

**Authoring rules, from the guide:**

1. **The texture's pixel dimensions must be an exact multiple of the grid.** 1024×1024 for `Grid8x8` (128 px frames) is the canonical example in the docs.
2. **Leave transparent spacing between frames.** The guide flags this as an *error*-severity note: "When you create a flipbook texture, include spacing between each of the particle frames. In some cases, mip filtering might require even more spacing." Without it, mip-mapping bleeds neighbouring frames into each other and you get halos that only appear at distance — a bug that is invisible in the Studio viewport and obvious in play.
3. **Flipbooks cost memory, and clients will silently turn them off.** The guide warns: "clients automatically deactivate flipbooks when they are low on memory, which is likely for older mobile phones." Design your effect so that frame 0 alone still reads as *something* — because on a low-memory phone, frame 0 alone is what the player gets.
4. **Reuse textures.** "Reusing textures costs less memory than using unique textures." One well-made 4×4 smoke sheet, recoloured via `Color`, beats six bespoke sheets.

**Mode selection:**

- `OneShot` — explosions, impact puffs, anything that plays once and is done. Note the important behaviour: with `OneShot`, `FlipbookFramerate` **does not apply**; the framerate is derived from `Lifetime / frameCount`. This means **changing `Lifetime` retimes the animation automatically**, which is exactly what you want and a common source of "why won't the framerate change" confusion.
- `Loop` — continuous fire, flowing water, sustained magic.
- `PingPong` — breathing/pulsing organic shapes; cheaper than authoring a seamless loop.
- `Random` — "play the frames in a random order, blending/crossfading from one frame to the next... useful for organic particle textures at low framerates, such as stars slowly twinkling."

**The zero-framerate trick.** Set `FlipbookStartRandom = true` and `FlipbookFramerate = NumberRange.new(0, 0)`. Each particle now renders one randomly chosen static frame from the sheet, forever. One emitter, one texture, *N* visually distinct particles. This is the correct way to do "debris chunks of varied shapes," "differently-shaped leaves," or "four styles of coin" without four emitters. The docs call this out explicitly.

### 1.7 Emission: `Rate` vs `:Emit(n)`

Two separate mechanisms, and a large fraction of bad-feeling Roblox VFX comes from using the wrong one.

- **`Rate` (float)** — particles per second while `Enabled`. "It is the inverse of frequency, meaning that a rate of 5 emits a particle every 0.2 seconds. When changed, this property has no effect on any active particles." Use for **continuous state**: a furnace burning, a generator humming, an aura.
- **`:Emit(particleCount: int = 16)`** — "will cause the `ParticleEmitter` to instantly emit the given number of particles." Use for **events**: a purchase, an impact, a level-up, a prestige.
- **`:Clear()`** — "instantly clears all existing particles that have been emitted... through its natural emission... or via `Emit()`." Use it when teleporting an effect so the old particles do not smear across the world.

The canonical bad pattern is *rate-pulsing*: setting `Enabled = true`, waiting, then `Enabled = false` to fake a burst. That produces a burst whose particle count is frame-rate dependent and whose first particle arrives up to `1/Rate` seconds late. The correct pattern:

```lua
-- Burst emitter: Rate = 0, Enabled = true, driven purely by :Emit().
local function burst(emitter: ParticleEmitter, n: number)
    emitter:Emit(n)
end
```

Leave `Enabled = true` and `Rate = 0` on burst emitters. `Enabled = false` blocks `Rate` emission but — per the reference — "any existing particles remain active until they expire," and `Emit()` on a disabled emitter is not documented to work. `[UNVERIFIED]` — the reference does not state whether `:Emit()` fires on a disabled emitter; do not rely on it either way. Keep burst emitters enabled with `Rate = 0`.

### 1.8 Motion properties

| Property | Type | What it is actually for |
| --- | --- | --- |
| `Speed` | `NumberRange` | Initial velocity in studs/s along `EmissionDirection`. **Negative values travel in reverse.** Always use a *range*, never a single value — identical speeds are the #1 tell of a cheap effect |
| `SpreadAngle` | `Vector2` | Random angular spread in degrees on the two axes perpendicular to `EmissionDirection`. `Vector2.new(180, 180)` = omnidirectional |
| `EmissionDirection` | `Enum.NormalId` | Which face of the parent emits: `Right`/`Top`/`Back`/`Left`/`Bottom`/`Front` |
| `Acceleration` | `Vector3` | Global-axis acceleration, studs/s². `Vector3.new(0, -50, 0)` for gravity-affected debris; `Vector3.new(0, 8, 0)` for rising embers. **Affects current and future particles** |
| `Drag` | float | "The rate in seconds at which individual particles will lose half their speed via exponential decay." It is a **half-life**, not a coefficient. Negative values cause exponential *growth* |
| `WindAffectsDrag` | boolean | Particles follow `Workspace.GlobalWind`. **Only applies if `Drag > 0`** |
| `VelocityInheritance` | float | Fraction of the parent `BasePart.Velocity` inherited at emission. `1` = particle matches the part exactly |
| `LockedToPart` | boolean | Particles rigidly move with the parent. Use for effects attached to fast-moving UI-driven objects; **do not** use for smoke, which should be left behind |
| `Rotation` | `NumberRange` | Initial rotation in degrees, clockwise-positive. **`NumberRange.new(0, 360)` should be your default** for any non-symmetric texture |
| `RotSpeed` | `NumberRange` | Angular speed in deg/s, randomised per particle at emission |
| `Lifetime` | `NumberRange` | Per-particle age range. **A lifetime of 0 prevents emission entirely** |
| `TimeScale` | float 0–1 | "At 1, it runs at normal speed; at 0.5 it runs at half speed; at 0 it freezes in time." This is your hit-stop handle (§4.2) |
| `VelocitySpread` | float | **Deprecated** (`Tags: ['NotReplicated', 'Deprecated']` in the API dump). Use `SpreadAngle` |

Note `Drag`'s semantics carefully: it is a half-life in seconds. `Drag = 0.5` means a particle loses half its speed every half second — aggressive. `Drag = 5` is a gentle settle. The docs also note drag scales both `Speed` and velocity inherited via `VelocityInheritance`.

### 1.9 Texture authoring — what makes a particle look cheap

The engine side is only half of it. These are the texture rules that separate professional particles from asset-library particles.

**1. Soft edges, always.** A hard-edged alpha cutoff is the loudest possible signal of a cheap particle, because it makes the quad's silhouette visible. Every particle texture should have alpha that falls off over at least ~15% of its radius. For smoke, closer to 40%. The *only* particles allowed hard edges are ones playing a physical object (a coin, a gem, a debris chunk) — and even those want a 1–2 px feathered edge to avoid aliasing.

**2. No square framing.** If your texture is a circle inscribed exactly in the 128×128 frame, the circle clips at the frame boundary at some rotations. Leave 8–10% transparent padding on all sides. This compounds with the flipbook spacing rule in §1.6.

**3. Kill the residual alpha.** Exported PNGs frequently have alpha values of 1–3 in what should be fully transparent regions. Under additive blending this is invisible; under `LightEmission = 0` it produces a faint visible rectangle around every particle. Clamp alpha below ~4/255 to zero on export.

**4. Premultiplied-alpha halos.** If your authoring tool leaves colour data as black in transparent regions, bilinear filtering blends that black toward the edges and you get a dark fringe. Flood-fill the RGB of transparent regions with the particle's dominant colour before export. This is the single most common invisible-in-Studio, obvious-in-game texture bug. `[UNVERIFIED]` — Roblox does not document its texture filtering/premultiplication behaviour; this is standard real-time-graphics practice and is presented as such.

**5. Design for tint.** Author textures **white/greyscale** and colour them with `Color`. One white smoke puff tinted grey, brown, black and purple is four effects for one texture upload, one memory allocation, and one moderation review.

**6. Resolution discipline.** A particle that is ~40 px on screen does not need a 512×512 texture. For a non-flipbook particle, 128×128 is generous and 256×256 is a lot. For flipbooks, size the *frame*, not the sheet: 128 px frames × 8×8 = 1024×1024.

**7. Vary the shape within the sheet.** Four subtly different smoke puffs in a `Grid2x2` with `FlipbookStartRandom` + `FlipbookFramerate = 0` beats one puff repeated, at identical cost.

**8. Do not put motion in the texture that the emitter can provide.** A flipbook of a particle spinning is wasted frames — `RotSpeed` does that for free. Flipbook frames should carry *shape change* (a fireball roiling, smoke curling), which the emitter cannot do.

### 1.10 A layered VFX builder

Putting §1.1–§1.9 together. This is the shape of a production effect definition — data, not code, so effects are reviewable and diffable.

```lua
--!strict
-- ReplicatedStorage/VFX/EffectDefs.luau
export type EmitterDef = {
    Texture: string,
    Color: ColorSequence?,
    Transparency: NumberSequence?,
    Size: NumberSequence?,
    Lifetime: NumberRange?,
    Speed: NumberRange?,
    SpreadAngle: Vector2?,
    Rotation: NumberRange?,
    RotSpeed: NumberRange?,
    Acceleration: Vector3?,
    Drag: number?,
    LightEmission: number?,
    LightInfluence: number?,   -- ALWAYS set this; default differs by insertion path
    Brightness: number?,
    ZOffset: number?,
    Squash: NumberSequence?,
    Orientation: Enum.ParticleOrientation?,
    FlipbookLayout: Enum.ParticleFlipbookLayout?,
    FlipbookMode: Enum.ParticleFlipbookMode?,
    FlipbookFramerate: NumberRange?,
    FlipbookStartRandom: boolean?,
    Shape: Enum.ParticleEmitterShape?,
    ShapeStyle: Enum.ParticleEmitterShapeStyle?,
    ShapeInOut: Enum.ParticleEmitterShapeInOut?,
    ShapePartial: number?,
    -- Burst-only
    EmitCount: number?,
    -- Continuous-only
    Rate: number?,
}

local function fade(peak: number): NumberSequence
    -- Standard in-and-out alpha envelope. Particles that pop in at full
    -- opacity read as cheap; give every particle a 10% fade-in.
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),
        NumberSequenceKeypoint.new(0.10, peak),
        NumberSequenceKeypoint.new(0.60, peak),
        NumberSequenceKeypoint.new(1.00, 1),
    })
end

local EffectDefs = {}

EffectDefs.PrestigeBurst = {
    -- Layer 1: the flash. Very short, very bright, additive, unlit.
    {
        Texture = "rbxassetid://0", -- soft radial gradient, white
        Color = ColorSequence.new(Color3.fromRGB(255, 244, 214)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 2),
            NumberSequenceKeypoint.new(1, 14),
        }),
        Lifetime = NumberRange.new(0.14, 0.18),
        Speed = NumberRange.new(0, 0),
        LightEmission = 1, LightInfluence = 0, Brightness = 6,
        ZOffset = 0.6,
        EmitCount = 1,
    },
    -- Layer 2: the ring. Disc + surface + rim = expanding ground ring.
    {
        Texture = "rbxassetid://0", -- soft streak, vertical
        Color = ColorSequence.new(Color3.fromRGB(120, 200, 255)),
        Transparency = fade(0.1),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.2),
            NumberSequenceKeypoint.new(1, 0.1),
        }),
        Lifetime = NumberRange.new(0.5, 0.75),
        Speed = NumberRange.new(28, 40),
        SpreadAngle = Vector2.new(6, 6),
        Drag = 0.35,
        Orientation = Enum.ParticleOrientation.VelocityParallel,
        Squash = NumberSequence.new(0.6),
        LightEmission = 1, LightInfluence = 0, Brightness = 3,
        ZOffset = 0.3,
        Shape = Enum.ParticleEmitterShape.Disc,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
        ShapePartial = 1,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        EmitCount = 44,
    },
    -- Layer 3: the smoke. Alpha-blended, LIT, sits behind everything.
    {
        Texture = "rbxassetid://0", -- 4x4 smoke flipbook
        Color = ColorSequence.new(Color3.fromRGB(190, 200, 215)),
        Transparency = fade(0.45),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3),
            NumberSequenceKeypoint.new(1, 11),
        }),
        Lifetime = NumberRange.new(0.9, 1.5),
        Speed = NumberRange.new(4, 9),
        SpreadAngle = Vector2.new(60, 60),
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-25, 25),
        Acceleration = Vector3.new(0, 3, 0),
        Drag = 1.2,
        LightEmission = 0, LightInfluence = 1, Brightness = 1,
        ZOffset = -0.5,
        FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
        FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
        FlipbookStartRandom = false,
        EmitCount = 16,
    },
}

return EffectDefs
```

```lua
--!strict
-- Applying a def. Note the explicit LightInfluence default of 0 to avoid the
-- Studio-vs-Instance.new discrepancy leaking in.
local function applyDef(emitter: ParticleEmitter, def: { [string]: any })
    emitter.LightInfluence = def.LightInfluence or 0
    emitter.Rate = def.Rate or 0
    emitter.Enabled = true           -- burst emitters stay enabled with Rate = 0
    for key, value in def do
        if key ~= "EmitCount" and key ~= "LightInfluence" and key ~= "Rate" then
            (emitter :: any)[key] = value
        end
    end
end
```

---

## 2. Beam: the general-purpose textured quad strip

Everyone learns `Beam` as "the laser thing." That framing costs you the most flexible primitive in the Roblox VFX toolbox. What `Beam` actually is: **a strip of textured, camera-optionally-facing quads swept along a cubic Bézier curve between two attachments, with a width taper, a colour/transparency gradient along its length, and a scrolling UV.** Every one of those words is a feature.

### 2.1 The geometry model

From `effects/beams.md` and `Beam.yaml`, the curve is a cubic Bézier with four control points:

- **P0** — position of `Attachment0`.
- **P1** — `CurveSize0` studs from `Attachment0`, along `Attachment0`'s **positive X** direction.
- **P2** — `CurveSize1` studs from `Attachment1`, along `Attachment1`'s **negative X** direction.
- **P3** — position of `Attachment1`.

**The critical, non-obvious consequence: beam shape depends on attachment *orientation*, not just position.** Two attachments in exactly the same places, rotated differently, produce completely different beams. This is why beams "mysteriously" change shape when the parts they're attached to rotate, and it is also the lever you use to author a curve deliberately.

Practical implications:

- A "straight" beam requires `CurveSize0 = CurveSize1 = 0`, *or* both attachments' +X axes pointing along the segment between them. If you only set the positions and leave default orientations, you will get a surprise curve as soon as `CurveSize` is non-zero.
- To make a beam arc *upward* like a thrown projectile's path: orient `Attachment0`'s +X up-and-forward and `Attachment1`'s −X down-and-backward, then dial `CurveSize0`/`CurveSize1`.
- To animate an arc, tween `CurveSize0`/`CurveSize1` — cheaper and smoother than moving attachments.

```lua
--!strict
-- Aim a beam's curve deliberately: point each attachment's +X along a chosen
-- tangent. CFrame.lookAt aims the -Z axis, so rotate to put +X where -Z was.
local function setTangent(attachment: Attachment, worldPos: Vector3, tangent: Vector3)
    local dir = tangent.Magnitude > 1e-4 and tangent.Unit or Vector3.xAxis
    local look = CFrame.lookAt(worldPos, worldPos + dir)
    -- lookAt: -Z faces `dir`. Rotate -90 degrees about Y so +X faces `dir`.
    attachment.WorldCFrame = look * CFrame.Angles(0, math.rad(-90), 0)
end

-- A beam that leaves the source upward and arrives at the target downward:
setTangent(a0, sourcePos, Vector3.new(0, 1, 0))
setTangent(a1, targetPos, Vector3.new(0, -1, 0))
beam.CurveSize0 = (targetPos - sourcePos).Magnitude * 0.4
beam.CurveSize1 = (targetPos - sourcePos).Magnitude * 0.4
```

> The `CFrame.Angles(0, -90°, 0)` correction above is derived from `CFrame.lookAt`'s documented `-Z`-forward convention (see chapter 43). Verify the sign in-engine for your setup; marked `[UNVERIFIED]` as written.

### 2.2 Segments

> "Rather than being a perfect curve, a beam is made up of straight segments. The more segments, the higher the resolution of the curve. The **Segments** property sets how many straight segments the beam is made up of, with a default value of 10."
> — `Beam.yaml`

Rules of thumb:

- **A straight beam needs `Segments = 1`.** The default 10 costs you 10× the geometry for zero visual benefit. This matters when you have dozens of connector lines on screen — extremely common in incremental games (production chains, upgrade trees, tether lines).
- A gentle curve needs 8–12.
- A tight S-curve or a long arc needs 20–30. Above ~30 you are almost certainly better off with a different approach.
- `Segments` also controls the resolution of the `Color` and `Transparency` gradients along the beam — a 2-segment beam cannot render a smooth 5-keypoint `ColorSequence`.

### 2.3 TextureMode and TextureLength — the scrolling energy recipe

`TextureMode` is `Enum.TextureMode`, shared with `Trail`. For a **Beam**:

- **`Wrap` (1)** — "the texture repetitions will equal the beam's overall length (in studs) divided by its `TextureLength`." So `TextureLength` is a length **in studs per repetition**. A beam of any length keeps a constant texture scale. **This is what you want almost always**, because it means a beam that stretches does not smear its texture.
- **`Static` (2)** — "not supported for `Beam` and therefore behaves identically to **Wrap**." Do not use it on beams; it only means something on `Trail`.
- **`Stretch` (0)** — "the texture will repeat `TextureLength` times across the beam's overall length." Here `TextureLength` is a **repetition count**. The texture scale changes with beam length. Use this deliberately when you *want* the stretch to read (a rubber band, a tractor beam that stretches as it pulls).

`TextureSpeed` is the scroll rate: "the number of texture cycles per second at which the `Texture` image moves along the beam, where one cycle is a full traversal of the texture's UV range." Positive scrolls `Attachment0 → Attachment1`; negative reverses. Default `1`.

**The scrolling-energy recipe**, which is the single most reusable beam effect:

```lua
--!strict
-- A "power flowing from A to B" link. Two stacked beams read far better
-- than one: a dim wide base and a bright narrow core.
local function makeEnergyLink(a0: Attachment, a1: Attachment, hue: Color3): (Beam, Beam)
    local base = Instance.new("Beam")
    base.Attachment0, base.Attachment1 = a0, a1
    base.Segments = 1                 -- straight: 1 segment is enough
    base.CurveSize0, base.CurveSize1 = 0, 0
    base.Width0, base.Width1 = 0.55, 0.55
    base.Texture = "rbxassetid://0"   -- soft horizontal gradient, seamless L/R
    base.TextureMode = Enum.TextureMode.Wrap
    base.TextureLength = 4            -- studs per repetition
    base.TextureSpeed = 0.6
    base.Color = ColorSequence.new(hue)
    base.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),   -- fade in at the source
        NumberSequenceKeypoint.new(0.12, 0.45),
        NumberSequenceKeypoint.new(0.88, 0.45),
        NumberSequenceKeypoint.new(1.00, 1),   -- fade out at the target
    })
    base.LightEmission = 1
    base.LightInfluence = 0
    base.Brightness = 2
    base.FaceCamera = true

    local core = base:Clone()
    core.Width0, core.Width1 = 0.16, 0.16
    core.Color = ColorSequence.new(Color3.new(1, 1, 1))
    core.Brightness = 5
    core.TextureSpeed = 1.9           -- core scrolls faster => parallax
    core.TextureLength = 2.5
    core.ZOffset = 0.05               -- ensure the core wins the sort

    return base, core
end
```

Two details make this read as expensive rather than as a stripe:

1. **Transparency fades at both ends.** A beam that starts and ends at full opacity has visible cut edges. The `NumberSequence` above hides them. This is the beam equivalent of "soft edges" from §1.9.
2. **Two layers at different scroll speeds.** The parallax between the wide dim base and the narrow bright core is what sells motion. A single scrolling texture reads as a barber pole.

`TextureSpeed` is also how you communicate *rate* in an incremental game. Scale it with production throughput and the player reads the speed of their economy without a number:

```lua
-- Throughput in items/sec => beam scroll speed, log-compressed so that a
-- 1e6x range of throughput maps to a ~10x range of visual speed.
local function speedFor(throughput: number): number
    return 0.4 + math.clamp(math.log10(1 + throughput) * 0.5, 0, 4)
end
```

### 2.4 Width, colour, brightness, facing

- **`Width0` / `Width1`** — studs at each end; the width "will change linearly" between them. A taper (`Width0 = 0.6`, `Width1 = 0.05`) makes a beam read as directional without any texture work — good for "collect" tethers pointing at the player.
- **`Color` (`ColorSequence`) / `Transparency` (`NumberSequence`)** — gradients *across the length*, sampled at `Segments` resolution.
- **`LightEmission` / `LightInfluence` / `Brightness`** — identical semantics to `ParticleEmitter` (§1.1). `Brightness` on `Beam` is documented as "1 by default and can be set to any number within the range of 0 to 10000." Energy beams want `LightEmission = 1`, `LightInfluence = 0`.
- **`FaceCamera` (boolean)** — "A `Beam` is a 2D projection existing in 3D space, meaning that it may not be visible from every angle." With `FaceCamera = false` a beam viewed edge-on vanishes. **Set `FaceCamera = true` for anything vertical or anything the camera orbits**; leave it `false` for ground decals and anything that should read as a flat plane lying on a surface.
- **`ZOffset`** — camera-relative render offset in studs, positive or negative. Same layering role as on `ParticleEmitter`.
- **`Enabled`** — visibility toggle. Unlike `Highlight`, there is no documented instance cap on `Beam`, so pooling disabled beams is fine.

### 2.5 Beam as a general primitive — a catalogue

Because a beam is really "textured quad strip between two points," it solves a surprising number of problems that people reach for meshes or `SurfaceGui` for:

| Use | Setup |
| --- | --- |
| **Straight connector line** (production chain, upgrade-tree edge) | `Segments = 1`, `CurveSize = 0`, `FaceCamera = true`, thin, `TextureSpeed = 0` |
| **Ground ring / AoE indicator** | Two attachments on opposite sides of the circle, large `CurveSize` on both, **`FaceCamera = false`**, flat against the ground. Two such beams back-to-back form a full circle |
| **Conveyor belt surface** | Beam lying flat along the belt, `TextureMode = Wrap`, `TextureSpeed` matched to belt speed, `FaceCamera = false` |
| **Tether / vacuum line** (coins flying to player) | `Attachment0` on the coin, `Attachment1` on the character; taper `Width0 → Width1`; high `TextureSpeed` toward the player |
| **Lightning** | Zig-zag alpha texture, `Wrap`, high `TextureSpeed`, and jitter `CurveSize0`/`CurveSize1` a few times per second |
| **Speed lines / motion streaks** | Short beams behind a moving object, `LightEmission = 1`, quickly-fading `Transparency` |
| **Waterfall / flowing liquid** | Wide beam, `Wrap`, downward `TextureSpeed`, `LightInfluence` around 0.7 |
| **Rope / cable** | `CurveSize0` / `CurveSize1` set to sag the curve downward, `FaceCamera = true`, `TextureSpeed = 0` |
| **Progress bar in world space** | Beam with `Transparency` `NumberSequence` whose cutoff keypoint is animated. Gives a 3D progress bar with no GUI |
| **Aura / halo ring around a purchased object** | Horizontal ring at the base; animate `Brightness` and `TextureSpeed` on state change |

### 2.6 Beam gotchas

- **Both attachments must be set and must be different objects.** A beam with only `Attachment0` renders nothing. The guide calls this out explicitly.
- **A beam with no `Texture` renders as a solid line** in `Color`. This is a legitimate, extremely cheap option for connector lines — you get a coloured, gradient-capable, width-tapered line with zero texture memory.
- **Texture not loaded = solid line too.** "this also occurs when the texture is set to an invalid content ID or the image associated with the texture has not yet loaded." Preload beam textures with `ContentProvider:PreloadAsync` (§8.7) or players will see a frame of solid colour.
- **Beam textures must tile seamlessly left-to-right** under `Wrap`, or you will see a seam scroll past at `TextureSpeed` cycles/second. Vertically they should fade to transparent at the top and bottom edges or the strip's edges will be visible.

---

## 3. Trail

`Trail` is the "something moved through here" primitive. Where a `Beam` connects two points *now*, a `Trail` records where two points *were*.

### 3.1 The geometry model

> "When the trail is `Enabled`, it records the positions of its attachments every frame and connects these positions to the attachments' positions on the previous frame, creating a polygon that is then filled in by the trail's `Color` and `Texture`."
> — `Trail.yaml`

So: two attachments define a **segment** (a line). Moving that segment through space sweeps a ribbon. **The trail's width is the distance between its two attachments** — you do not set width directly, you set attachment separation and then scale it.

This has an immediate practical consequence: to make a trail on a moving part, you place *two* attachments on the part, separated along the axis perpendicular to travel. Separation = width. The most common beginner bug is one attachment (nothing renders) or two attachments in the same place (zero-width ribbon).

### 3.2 Properties that matter

| Property | Type | Notes |
| --- | --- | --- |
| `Lifetime` | float | "how long each segment in a trail will last, in seconds, before it disappears. Defaults to **2** seconds but can be set anywhere between **0.01 and 20**." Short lifetime = short, snappy trail |
| `MinLength` | float | "If neither of the trail's attachments have moved at least this value, no new segments will be created and the endpoints of the current segment will be moved to the current position of the attachments." |
| `MaxLength` | float | "the maximum length of the trail, in studs. Its value defaults to **0**, meaning that the trail will not have a maximum length and trail segments will expire in their `Lifetime`." |
| `WidthScale` | `NumberSequence` | "scales the width of the trail over the course of its lifetime. Values can range between 0 and 1, acting as a multiplier on the distance between the trail's attachments." The example in the reference: attachments 2 studs apart, `WidthScale = 0.5` → 1-stud trail, centred between them |
| `FaceCamera` | boolean | Same as Beam: a trail is a 2D projection and can vanish edge-on |
| `TextureMode` | `Enum.TextureMode` | For a trail: `Stretch` stretches with lifetime and shrinks inward when motion stops; `Wrap` tiles as length changes but stays stationary relative to the attachments; **`Static` "rolled out as the attachments move, and they will remain in place until their lifetime is met"** |
| `Color` / `Transparency` / `LightEmission` / `LightInfluence` / `Brightness` | — | Same semantics as Beam |

**`MinLength` is the anti-jitter property and almost nobody sets it.** With `MinLength = 0`, an object that is nearly stationary but jittering (physics settling, a hover animation, network-interpolated replication) generates a new segment every frame, producing a crumpled knot of geometry at the object's position. Setting `MinLength` to something like 0.15–0.5 studs makes the trail *stretch* the existing segment instead of creating new ones. Result: a clean trail that simply stops growing when the object stops. **Set `MinLength` on every trail you ship.**

**`MaxLength` is your hard geometry budget.** With `MaxLength = 0` a fast object with a 2-second lifetime generates an enormous ribbon. Setting `MaxLength` caps segment count regardless of speed — the right way to make a trail that looks the same on a slow object and a very fast one.

**`TextureMode.Static` is the "stamped" mode** and is genuinely distinct: "ideal for trail textures that should appear 'stamped' where rendered, such as paw prints or tire tracks." This is how you do footprints, skid marks, or a "path the automation walked" trail without instancing decals.

### 3.3 What Trail is good for

- **Motion streaks on anything that moves fast** — projectiles, flying currency, a rebirth avatar dash. This is the canonical use and the reason `Trail` exists.
- **Currency flying to the HUD.** Attach two attachments to a flying coin part with ~0.4 stud separation, `Lifetime = 0.25`, `MinLength = 0.2`, `WidthScale` tapering `1 → 0`, `LightEmission = 1`. Reads as a comet.
- **Melee / tool swings.** Attachments at the base and tip of the weapon; the trail is the *swept arc* of the blade. `Lifetime` around 0.15–0.3 — longer and the arc smears into a disc.
- **Tyre tracks and footprints** via `TextureMode.Static`.
- **Conveyor item motion**, where the trail's fade communicates direction better than the item alone.
- **Prestige / rebirth character effects** — long `Lifetime`, `MaxLength` capped, additive.

### 3.4 A production-quality trail setup

```lua
--!strict
-- A flying-currency comet. Note MinLength (anti-jitter), MaxLength (budget),
-- and a WidthScale that tapers so the tail thins instead of ending square.
local function attachCometTrail(part: BasePart, tint: Color3): Trail
    local a0 = Instance.new("Attachment")
    a0.Name = "TrailA0"
    a0.Position = Vector3.new(0, 0.22, 0)
    a0.Parent = part

    local a1 = Instance.new("Attachment")
    a1.Name = "TrailA1"
    a1.Position = Vector3.new(0, -0.22, 0)  -- 0.44 studs apart => 0.44 stud width
    a1.Parent = part

    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Lifetime = 0.28                   -- snappy; 2.0 default is far too long
    trail.MinLength = 0.2                   -- do not generate geometry when idle
    trail.MaxLength = 14                    -- hard cap regardless of speed
    trail.FaceCamera = true
    trail.Texture = "rbxassetid://0"        -- soft streak, fades at top/bottom
    trail.TextureMode = Enum.TextureMode.Stretch
    trail.TextureLength = 1
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, tint),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.15),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1.0),
        NumberSequenceKeypoint.new(1.0, 0.0),   -- taper to a point
    })
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.Brightness = 3
    trail.Parent = part
    return trail
end
```

**Trail gotcha: re-enabling.** Setting `Enabled = false` then `true` on a trail that has moved a long way in between will draw a segment connecting the two positions — a streak across the map. When you pool and reuse a trail (§9.3), park the part at its new position, wait one frame, *then* enable.

---

## 4. The juice toolkit

This section is the heart of the chapter. Everything above is *what the engine can draw*; this is *when and how fast it should change*, which is where feel actually lives.

A guiding principle for the whole section: **feel is about derivatives.** Players do not perceive positions, they perceive velocity and acceleration. Anything that changes at a constant rate — a linear tween, a fixed-rate counter, a constant-amplitude shake — is invisible as *motion* and reads as mechanical. Every technique below is a way of putting a discontinuity or a curve into a derivative.

### 4.1 Trauma-based screen shake

**Why random jitter looks cheap.** The naive implementation is:

```lua
-- DON'T. This is what makes a game look like a 2009 Flash game.
camera.CFrame = base * CFrame.new(
    math.random(-1, 1) * amount,
    math.random(-1, 1) * amount,
    0
)
```

Three separate problems:

1. **It is white noise.** Consecutive frames are uncorrelated, so the camera teleports rather than moves. The human visual system reads uncorrelated per-frame displacement as *rendering error*, not as motion — the same reason a dropped frame is so noticeable. Real camera shake is a physical object with mass; its position is continuous and its *velocity* is what is noisy.
2. **Amplitude is constant, then stops.** Real impacts decay. A shake that ends abruptly reads as a bug.
3. **It is translation-only.** The dominant component of real handheld/impact camera shake is **rotational** — pitch, yaw, and especially roll. Translation-only shake reads as the whole world sliding; rotation reads as the camera being *hit*.

**The trauma model** (widely attributed to a 2016 GDC talk by Squirrel Eiserloh, "Math for Game Programmers: Juicing Your Cameras With Math"; `[COMMUNITY, SECOND-HAND]` for the attribution, the maths below is self-contained):

- Maintain a single scalar `trauma ∈ [0, 1]`.
- Events *add* trauma: `trauma = math.min(1, trauma + amount)`. It accumulates, so two hits in quick succession shake harder than one.
- Trauma **decays linearly** over time: `trauma -= decayRate * dt`.
- The shake amplitude applied each frame is **`trauma²`** (or `trauma³`).

The squaring is the whole trick. Because the decay is linear but the amplitude is quadratic, the shake falls off *fast at first and then gently*, which matches how a real object's oscillation dies and — crucially — means the shake spends almost no time in the "faint visible wobble" region that reads as a bug. Linear amplitude decay leaves a low-amplitude tail that looks like the camera is broken. `trauma³` is even punchier and is the right choice for a big, rare event like a prestige.

**Noise, not randomness.** Sample `math.noise` — Roblox's Perlin noise, documented as "Returns a Perlin noise value... most often between the range of `-1` to `1`" — along a time axis, using a **different, widely separated seed offset per output axis** so the three rotation channels are independent. Perlin noise is C¹-continuous, so the camera's motion is smooth even though its direction is unpredictable. That is exactly the character of real shake.

```lua
--!strict
-- ReplicatedStorage/Client/CameraShake.luau
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}

local trauma = 0
local traumaDecay = 1.6          -- trauma units per second
local frequency = 22             -- noise samples per second; 15-30 feels right
local maxRotation = math.rad(6)  -- peak pitch/yaw/roll at trauma = 1
local maxTranslation = 0.9       -- peak positional offset in studs at trauma = 1
local noiseSeed = 0

-- Widely-separated offsets so the six channels are decorrelated. Perlin noise
-- is periodic-ish in its lattice; offsets of ~100 are more than enough.
local OFFSETS = { 0, 137, 271, 419, 563, 701 }

function CameraShake.add(amount: number)
    trauma = math.min(1, trauma + amount)
end

function CameraShake.getTrauma(): number
    return trauma
end

local function shakeOffset(dt: number): CFrame
    if trauma <= 0 then
        return CFrame.identity
    end
    noiseSeed += dt * frequency

    -- trauma^2: linear decay, quadratic amplitude. This is the key line.
    local amp = trauma * trauma

    local function n(i: number): number
        return math.clamp(math.noise(noiseSeed, OFFSETS[i]), -1, 1)
    end

    local pitch = n(1) * maxRotation * amp
    local yaw   = n(2) * maxRotation * amp
    local roll  = n(3) * maxRotation * amp * 1.4   -- roll reads strongest
    local dx    = n(4) * maxTranslation * amp
    local dy    = n(5) * maxTranslation * amp
    local dz    = n(6) * maxTranslation * amp * 0.4 -- less dolly; it reads as zoom

    return CFrame.new(dx, dy, dz) * CFrame.fromEulerAnglesYXZ(pitch, yaw, roll)
end

RunService:BindToRenderStep("CameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
    trauma = math.max(0, trauma - traumaDecay * dt)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    -- Applied AFTER the camera script has written its CFrame, so we compose
    -- onto whatever the camera system produced this frame rather than fighting it.
    camera.CFrame = camera.CFrame * shakeOffset(dt)
end)

return CameraShake
```

**Priority matters.** `Enum.RenderPriority.Camera.Value + 1` runs *after* the default camera update, so you post-multiply onto the camera's own CFrame instead of racing it. Binding at or before `Camera` priority means your offset gets overwritten.

**Trauma budget — a calibrated table.** The most common failure after implementing shake correctly is applying too much of it. Shake is a *spice*.

| Event | Trauma added | Notes |
| --- | --- | --- |
| UI button press | 0 | Never shake for UI. Use scale (§4.7) |
| Small purchase / single unit bought | 0.05–0.10 | Barely perceptible, but felt |
| Meaningful upgrade | 0.15–0.22 | |
| Milestone reached | 0.30–0.40 | |
| Boss hit / heavy impact | 0.35–0.50 | |
| Prestige / rebirth | 0.70–1.00 | Use `trauma³`, and only here |
| Continuous ambient (machinery) | Hold ~0.04 | Set, don't add; a *separate*, low-frequency channel |

**Additional rules:**

- **Never shake for more than ~600 ms.** With `traumaDecay = 1.6`, trauma 1.0 fully decays in 625 ms and the *perceptible* part (trauma² > 0.05, i.e. trauma > 0.22) lasts about 490 ms. That is the right ceiling.
- **Offer an accessibility toggle.** Screen shake causes motion sickness for a real fraction of players. A `screenShakeIntensity` setting multiplying `maxRotation`/`maxTranslation`, persisted per-player, is table stakes. Default it on at 1.0; allow 0.
- **Do not shake during menus or modal UI.** Zero the trauma when a full-screen panel opens.

### 4.2 Hit stop / freeze frames

Hit stop is a very short pause immediately after an impact registers. It is arguably the highest-value-per-line technique in this entire chapter, because it directly manufactures the perception of *weight*, which is otherwise very hard to fake.

**Why it works:** the impact frame is the single most information-dense frame of the interaction. Holding it gives the player's eye time to actually resolve it, and the resumption afterwards reads as the impact "breaking through."

**Timing, in milliseconds.** These are the numbers that matter:

| Impact class | Freeze duration | Time scale during freeze |
| --- | --- | --- |
| Light tap / small tick | 30–50 ms | 0.15 |
| Standard hit | 60–90 ms | 0.08 |
| Heavy hit | 100–130 ms | 0.0–0.05 |
| Finishing blow / prestige | 150–220 ms | 0.0 |

Above ~250 ms it stops reading as impact and starts reading as a hitch. Below ~25 ms it is imperceptible at 60 fps (fewer than two frames).

**Never freeze completely to 0 for the short cases.** A time scale of 0.08 rather than 0.0 keeps *some* motion, which reads as "the world strained" rather than "the game hung." Reserve exact 0 for the big, rare events.

**On Roblox you cannot pause the engine.** There is no global timescale. What you *can* do:

- `ParticleEmitter.TimeScale` and `Explosion.TimeScale` — both documented as "a value between 0 and 1 that controls the speed of the particle effect. At 1, it runs at normal speed; at 0.5 it runs at half speed; at 0 it freezes in time."
- Pause `Tween`s with `Tween:Pause()` / `:Play()`.
- Hold your own simulation/animation clock — for an incremental game, all your number animations, popups and counters are driven by your own clock anyway, so scaling that clock *is* hit stop.
- Scale `Animator`/`AnimationTrack:AdjustSpeed()` on character animations.

**Do not** touch physics or `Workspace` gravity for hit stop; it desynchronises from the server and causes visible corrections.

```lua
--!strict
-- ReplicatedStorage/Client/TimeScale.luau
-- A client-side presentation clock. Everything that animates for FEEL reads
-- `TimeScale.dt` instead of the raw RenderStepped delta, so hit stop is a
-- single switch that affects the whole presentation layer coherently.
local RunService = game:GetService("RunService")

local TimeScale = {}

local scale = 1
local holdUntil = 0
local holdScale = 1
local registeredEmitters: { [ParticleEmitter]: true } = {}

TimeScale.dt = 0          -- scaled delta, for presentation systems
TimeScale.rawDt = 0       -- unscaled delta, for UI that must never freeze
TimeScale.scale = 1

--- Freeze for `durationMs` at `duringScale` (0 = full stop).
function TimeScale.hitStop(durationMs: number, duringScale: number?)
    local now = os.clock()
    local until_ = now + durationMs / 1000
    -- A stronger/longer stop wins; a weaker one does not interrupt.
    if until_ > holdUntil then
        holdUntil = until_
        holdScale = duringScale or 0.08
    end
end

function TimeScale.register(emitter: ParticleEmitter)
    registeredEmitters[emitter] = true
end

function TimeScale.unregister(emitter: ParticleEmitter)
    registeredEmitters[emitter] = nil
end

RunService:BindToRenderStep("TimeScale", Enum.RenderPriority.First.Value, function(rawDt)
    local now = os.clock()
    local target = (now < holdUntil) and holdScale or 1

    -- Ease OUT of the stop rather than snapping back: the snap-back itself is
    -- a strong cue, but an instantaneous one reads as a stutter. ~40 ms ramp.
    if target == 1 and scale < 1 then
        scale = math.min(1, scale + rawDt / 0.04)
    else
        scale = target
    end

    TimeScale.rawDt = rawDt
    TimeScale.dt = rawDt * scale
    TimeScale.scale = scale

    for emitter in registeredEmitters do
        if emitter.Parent then
            emitter.TimeScale = scale
        else
            registeredEmitters[emitter] = nil
        end
    end
end)

return TimeScale
```

**Hit stop in an incremental game.** It is not just for combat. The moments that deserve hit stop:

- **Prestige / rebirth confirmation** — 180 ms at scale 0. The single biggest "this mattered" signal you have.
- **A very large purchase completing** — 70 ms at 0.1.
- **Crossing a major numeric threshold** (first billion, first e15) — 90 ms at 0.05.
- **A rare drop** — 120 ms at 0.0, combined with a brief `ColorCorrectionEffect.Saturation` dip (§6).

Do **not** hit-stop on routine clicks. It will feel like input lag.

### 4.3 Anticipation, follow-through, squash and stretch

The classical animation principles, applied to a real-time game. These are what make an action read as *intentional* rather than as a state change.

**Anticipation** — a brief movement in the *opposite* direction before the main action. It does two things: it tells the eye where to look, and it makes the main action feel faster by contrast.

- **Duration: 60–120 ms.** Longer feels sluggish; shorter is subliminal and, oddly, still works.
- **Magnitude: 10–20% of the main action**, in the opposite direction.
- A button that is about to launch a purchase dips to 0.94 scale for ~80 ms, then punches to 1.08 and settles to 1.0.
- A chest that is about to open pulls down and compresses first.

**Follow-through / overshoot** — the action does not stop at its target, it passes it and comes back. This is what `Enum.EasingStyle.Back` and springs give you for free. Without it, everything reads as if it has infinite braking force.

- **Overshoot magnitude: 5–15%** for UI, up to 25% for playful/cartoon-styled elements.
- **Settle time: 150–350 ms** after the overshoot.

**Squash and stretch** — volume-preserving deformation along the axis of motion. It is the single strongest cue for *acceleration* and *impact material*.

- Stretch along the direction of travel when accelerating; squash perpendicular to the impact normal on landing.
- **Preserve approximate volume:** if you scale up 1.3× on Y, scale to ~1/√1.3 ≈ 0.877× on X and Z. Non-volume-preserving squash reads as the object inflating.
- **Impact squash: 40–70 ms in, 120–200 ms out.** The compression is *much* faster than the recovery — this asymmetry is what reads as impact rather than as breathing.

```lua
--!strict
-- Volume-preserving squash-and-stretch on a UI element or a part.
-- `stretch` > 1 stretches along `axis`; < 1 squashes.
local function squashVector(stretch: number): Vector3
    local lateral = 1 / math.sqrt(stretch)
    return Vector3.new(lateral, stretch, lateral)
end

-- Impact: fast compression, slow recovery. The asymmetry IS the impact.
local TweenService = game:GetService("TweenService")

local function impactSquash(part: BasePart, baseSize: Vector3, strength: number)
    local squashed = baseSize * squashVector(1 - strength)   -- e.g. strength 0.35
    TweenService:Create(part, TweenInfo.new(
        0.055,                              -- 55 ms in  -- fast
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    ), { Size = squashed }):Play()

    task.delay(0.055, function()
        TweenService:Create(part, TweenInfo.new(
            0.19,                           -- 190 ms out -- slow, with a bounce
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ), { Size = baseSize }):Play()
    end)
end
```

### 4.4 The impact stack

A single "impact" in a well-made game is **five or more simultaneous systems firing on a deliberate schedule**. Almost all of the perceived quality comes from the *timing offsets* between them, not from any individual element.

The canonical stack, with timings measured from the logical moment of impact (t = 0):

| t (ms) | Element | Why there |
| --- | --- | --- |
| **−80** | *(optional)* anticipation | Only for telegraphed actions |
| **0** | **Sound transient** (the click/crack layer) | **Audio must be first or simultaneous.** A sound that arrives after the visual reads as lag, because humans are far more sensitive to audio-lagging-video than the reverse |
| **0** | **Flash** — additive particle `:Emit(1)`, 1–2 frame lifetime; or a white `Frame` at ~0.3 transparency | The flash is what makes the *frame* of impact legible |
| **0** | **Hit stop begins** | |
| **0** | **Screen shake trauma added** | |
| **+16 (1 frame)** | **Particle burst** — sparks/debris `:Emit(n)` | Deliberately one frame late: the flash should be the first thing seen |
| **+16** | **Squash** on the impacted object begins | |
| **+30** | **Sound body** (the thump layer) | Separating body from transient by ~2 frames is what gives a sound size |
| **+60–90** | **Hit stop releases** | |
| **+80** | **Number popup spawns** | Deliberately late. It must not compete with the flash for attention. This is the most commonly mistimed element |
| **+120** | **Sound tail** (reverb/ring layer) begins its decay | |
| **+150** | **Counter begins ticking** toward the new value | Late enough that the popup has registered |
| **+250–400** | Everything has settled | |

**The rule that matters most: stagger everything.** If the particle, flash, sound, shake and popup all fire on the same frame, the brain receives one undifferentiated blob of stimulus. Staggering them across 150 ms lets the brain resolve them as a *sequence of consequences*, which is what "impact" feels like.

**The second rule: audio never lags.** If you must be off, be early. Audio 30 ms early reads as tight. Audio 60 ms late reads as broken.

```lua
--!strict
-- ReplicatedStorage/Client/ImpactStack.luau
local TweenService = game:GetService("TweenService")
local CameraShake = require(script.Parent.CameraShake)
local TimeScale = require(script.Parent.TimeScale)
local SoundManager = require(script.Parent.SoundManager)
local Popups = require(script.Parent.Popups)

export type ImpactSpec = {
    worldPosition: Vector3,
    magnitude: number,            -- 0..1, scales the whole stack
    flash: ParticleEmitter?,
    sparks: ParticleEmitter?,
    smoke: ParticleEmitter?,
    popupText: string?,
    popupColor: Color3?,
    soundFamily: string,          -- e.g. "impact_heavy"
    squashTarget: BasePart?,
    squashBaseSize: Vector3?,
}

local ImpactStack = {}

function ImpactStack.fire(spec: ImpactSpec)
    local m = math.clamp(spec.magnitude, 0, 1)

    -- t = 0 -----------------------------------------------------------------
    SoundManager.playLayered(spec.soundFamily, spec.worldPosition, m)
    if spec.flash then
        spec.flash:Emit(1)
    end
    TimeScale.hitStop(40 + 90 * m, 0.15 - 0.10 * m)
    CameraShake.add(0.08 + 0.34 * m)

    -- t = +16 ms (one frame) ------------------------------------------------
    task.delay(0.016, function()
        if spec.sparks then
            spec.sparks:Emit(math.floor(8 + 40 * m))
        end
        if spec.smoke then
            spec.smoke:Emit(math.floor(3 + 12 * m))
        end
        if spec.squashTarget and spec.squashBaseSize then
            local strength = 0.15 + 0.3 * m
            local lateral = 1 / math.sqrt(1 - strength)
            TweenService:Create(
                spec.squashTarget,
                TweenInfo.new(0.055, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = spec.squashBaseSize * Vector3.new(lateral, 1 - strength, lateral) }
            ):Play()
            task.delay(0.055, function()
                TweenService:Create(
                    spec.squashTarget,
                    TweenInfo.new(0.19, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Size = spec.squashBaseSize }
                ):Play()
            end)
        end
    end)

    -- t = +80 ms ------------------------------------------------------------
    if spec.popupText then
        task.delay(0.08, function()
            Popups.spawn(spec.worldPosition, spec.popupText, spec.popupColor, m)
        end)
    end
end

return ImpactStack
```

### 4.5 Easing as an expressive choice

`Enum.EasingStyle` has 11 members and `Enum.EasingDirection` has 3, so `TweenInfo` gives you 33 curves. Most projects use two. Each curve says something different; picking the wrong one is like using the wrong font.

The documented behaviour of each style:

| Style | Documented character | What it communicates | Use for |
| --- | --- | --- | --- |
| `Linear` | "Moves at a constant speed" | Mechanical, inanimate, ongoing | Progress bars, conveyor UVs, rotating gears, loading spinners. **Nothing that represents an object with mass** |
| `Sine` | "gentle easing motion" | Calm, organic, breathing | Ambient loops, idle float, gentle pulsing, background motion |
| `Quad` | "slightly sharper curve" than Sine | Neutral, unremarkable | The safe default when nothing else fits |
| `Cubic` | "slightly sharper curve" than Quad | Purposeful | Panel slide-ins, camera moves |
| `Quart` | "even sharper curve" than Cubic | Decisive | Snappy UI, dropdowns |
| `Quint` | "even sharper curve" than Quart | Urgent | Fast reveals, alerts |
| `Exponential` | "The sharpest curve" | Explosive / instantaneous-then-settling | Flash reveals, damage numbers appearing, "slam" entrances |
| `Circular` | "acceleration is more sudden and deceleration more gradual versus Quint or Exponential" | Mechanical arc, weighty | Heavy doors, large machinery, elevator UI |
| `Back` | "Slightly overshoots the target, then backs into place" | Playful, confident, alive | **The workhorse for incremental UI.** Button presses, panel appearances, currency icons |
| `Bounce` | "Bounces backwards multiple times after reaching the target" | Comedic, light, toy-like | Dropped items landing, cartoon reward pops. Use sparingly — it is loud |
| `Elastic` | "Moves as if attached to a rubber band, overshooting the target several times" | Very playful, springy | Rare celebratory moments only. Overused, it becomes exhausting |

And the directions:

- **`Out` — use this by default.** Fast at the start, slow at the end. Matches how things decelerate under friction and, more importantly, **it puts the fast part at the beginning, so the element responds instantly to input.** Responsiveness is perceived from the first 50 ms.
- **`In`** — slow start, fast end. Reads as *departure* or *acceleration away*. Correct for elements leaving the screen, and for anything being "sucked away."
- **`InOut`** — slow at both ends. Reads as a *considered, complete* motion. Correct for camera moves, scene transitions, and anything the player is watching rather than doing.

**The single biggest easing rule: entrances are `Out`, exits are `In`, journeys are `InOut`.** Violating this — an `In` entrance especially — makes UI feel laggy even when it is not.

**Duration guidance:**

| Interaction | Duration |
| --- | --- |
| Hover state change | 80–120 ms |
| Press/down state | 50–80 ms (must feel instant) |
| Release/up state | 120–180 ms |
| Small element appear | 180–250 ms |
| Panel slide in | 250–350 ms |
| Full-screen transition | 350–500 ms |
| Celebratory reveal | 500–900 ms |

Anything a player triggers and waits for should be **under 300 ms**. Anything over 500 ms must be interruptible.

`TweenService:GetValue(alpha, easingStyle, easingDirection)` returns the eased alpha directly, so you can use these curves in your own hand-rolled animation without creating a `Tween` object. It is `ThreadSafety: Safe` per the API dump, so it is usable from parallel code.

```lua
-- Use the engine's easing curves in a manual animation loop.
local t = math.clamp((os.clock() - startTime) / duration, 0, 1)
local a = TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
frame.Position = start:Lerp(goal, a)
```

### 4.6 Springs vs tweens — and `SmoothDamp`

**Why springs read as alive.** A tween is a *scripted trajectory*: it commits, at authoring time, to a start, an end, and a duration. If the target changes mid-flight, the tween must be cancelled and restarted, which produces a visible velocity discontinuity. A spring has **no duration and no trajectory** — it only has a current value, a current velocity, and a target. Change the target and the motion simply bends toward the new one, carrying its momentum. That continuity of velocity is exactly what the eye reads as physical, and it is why spring-driven UI feels "alive" while tween-driven UI feels "authored."

Practical rule: **if the target can change while the animation is running, you need a spring.** Cursor-following elements, values that update continuously (an idle game's currency counter!), drag interactions, camera follow, hover states that can be re-entered — all springs.

**`TweenService:SmoothDamp` is a real critically-damped spring, and it is public.** From `TweenService.yaml`:

> "Smoothly interpolates a value towards a target, simulating a critically damped spring. Returns a tuple with `(newValue, newVelocity)`. `newVelocity` needs to be fed to the next call of SmoothDamp to ensure smooth results. Supports `number`, `Vector2`, `Vector3`, and `CFrame`."

Signature: `SmoothDamp(current, target, velocity, smoothTime: number, maxSpeed: number?, dt: number?) → (newValue, newVelocity)`. The API dump confirms `Security: None`, `ThreadSafety: Safe`, `SimulationAccess: true`. Parameter notes from the reference:

- `velocity` — "used to store the stateful velocity. In most cases, initialize this with `0`, `Vector2.zero`, `Vector3.zero`, or `CFrame.identity` depending on the type."
- `smoothTime` — "the duration over which the total smoothing operation should take place. Note that since this is a damped spring, there's no guarantee `current` will be exactly `target` after this time, but it will be close. Smaller values result in quicker smoothing."
- `maxSpeed` — "Leaving this nil defaults to `math.huge`, meaning the velocity isn't clamped."
- `dt` — "If left nil, the current engine delta time will be used."

**Most existing Roblox spring material predates this and hand-rolls a spring integrator.** You almost never need to. `SmoothDamp` is critically damped, which means *no overshoot* — correct for follow/tracking behaviour. When you specifically want overshoot (a bouncy button), use an under-damped spring, which you do have to hand-roll, or use `EasingStyle.Back`.

```lua
--!strict
-- A tiny spring wrapper over SmoothDamp. Stateful, allocation-free after
-- construction, and frame-rate independent because SmoothDamp integrates dt.
local TweenService = game:GetService("TweenService")

local Spring = {}
Spring.__index = Spring

export type Spring<T> = {
    value: T,
    velocity: T,
    target: T,
    smoothTime: number,
    maxSpeed: number?,
    step: (self: Spring<T>, dt: number?) -> T,
}

function Spring.new<T>(initial: T, smoothTime: number, maxSpeed: number?): Spring<T>
    local zero: any
    if typeof(initial) == "number" then zero = 0
    elseif typeof(initial) == "Vector2" then zero = Vector2.zero
    elseif typeof(initial) == "Vector3" then zero = Vector3.zero
    elseif typeof(initial) == "CFrame" then zero = CFrame.identity
    else error("Spring supports number, Vector2, Vector3, CFrame") end

    return setmetatable({
        value = initial,
        velocity = zero,
        target = initial,
        smoothTime = smoothTime,
        maxSpeed = maxSpeed,
    }, Spring) :: any
end

function Spring:step(dt: number?)
    self.value, self.velocity = TweenService:SmoothDamp(
        self.value, self.target, self.velocity, self.smoothTime, self.maxSpeed, dt
    )
    return self.value
end

return Spring
```

`smoothTime` calibration:

| Feel | `smoothTime` |
| --- | --- |
| Snappy UI response | 0.05–0.09 |
| Standard UI follow | 0.10–0.16 |
| Camera follow | 0.18–0.30 |
| Lazy / heavy object | 0.35–0.60 |
| Ambient drift | 1.0+ |

**The under-damped spring, when you want overshoot.** `SmoothDamp` is critically damped by definition, so for bounce you integrate your own. This is the standard semi-implicit Euler spring:

```lua
--!strict
-- Under-damped spring. damping < 1 overshoots; damping = 1 is critical.
-- Semi-implicit Euler is stable here for dt up to ~1/30 s at these frequencies.
local BouncySpring = {}
BouncySpring.__index = BouncySpring

function BouncySpring.new(initial: number, frequency: number, damping: number)
    return setmetatable({
        value = initial, velocity = 0, target = initial,
        omega = 2 * math.pi * frequency,   -- angular frequency, rad/s
        zeta = damping,                    -- 1 = critical, 0.5 = bouncy, 0.2 = very bouncy
    }, BouncySpring)
end

function BouncySpring:step(dt: number): number
    -- Clamp dt so a frame hitch cannot explode the integrator.
    dt = math.min(dt, 1 / 30)
    local w, z = self.omega, self.zeta
    local accel = -2 * z * w * self.velocity - w * w * (self.value - self.target)
    self.velocity += accel * dt
    self.value += self.velocity * dt
    return self.value
end

return BouncySpring
```

Calibration: `frequency` 3–5 Hz with `damping` 0.4–0.55 is the classic "juicy UI button." `frequency` 8–12 Hz with `damping` 0.25 is a sharp, twangy pop.

### 4.6.1 Frame-rate-independent smoothing — the bug everyone ships

This is worth its own heading because it is in essentially every Roblox codebase.

```lua
-- WRONG. Frame-rate dependent. At 120 fps this converges twice as fast
-- as at 60 fps, so the game literally feels different on better hardware.
value = value + (target - value) * 0.1
```

The constant `0.1` is "10% of the remaining distance **per frame**." Frames are not a unit of time.

```lua
-- RIGHT. `k` is a rate in units of 1/second and the behaviour is identical
-- at any frame rate.
local k = 12                              -- higher = snappier
local alpha = 1 - math.exp(-k * dt)
value = value + (target - value) * alpha
```

The `1 - math.exp(-k * dt)` form is exact, not an approximation: exponential decay integrated over `dt`. `k` relates to a half-life by `k = math.log(2) / halfLife`, which is often the more intuitive parameterisation:

```lua
local function alphaForHalfLife(halfLife: number, dt: number): number
    return 1 - 0.5 ^ (dt / halfLife)      -- equivalently 1 - exp(-ln2/halfLife * dt)
end
```

Use `SmoothDamp` where you can (it handles this correctly internally and gives you a proper second-order response); use `1 - math.exp(-k*dt)` where you want a simple first-order lag with no velocity state. **Never use a bare per-frame lerp constant.**

### 4.7 Counters, buttons, hover and press

**Counters that tick up.** In an incremental game the number *is* the game, so how the number moves is a first-order design concern.

Requirements:
1. **Never snap.** A number that jumps has no perceived magnitude.
2. **Must handle a continuously-moving target** (income is always arriving) — therefore a spring, not a tween.
3. **Must feel fast for small deltas and weighty for large ones.**
4. **Must interpolate in a space that matches how the player reads the number**, which for an incremental game means **log space**, not linear.

Point 4 is the one people miss. If the displayed value goes from 1e6 to 1e9 and you lerp linearly, the display spends 99.9% of the animation showing numbers that round to 1e9 — the animation is invisible. Lerping the *logarithm* makes the digits roll at a perceptually even rate across the whole range.

```lua
--!strict
-- ReplicatedStorage/Client/TickingCounter.luau
-- Spring-driven, log-space counter. See chapters 60/61 for the big-number
-- representation this composes with; here `value` is assumed to be a plain
-- number or a {mantissa, exponent} convertible to log10.
local TweenService = game:GetService("TweenService")

local TickingCounter = {}
TickingCounter.__index = TickingCounter

local MIN_LOG = -6   -- floor so log(0) doesn't blow up

local function toLog(v: number): number
    return math.max(MIN_LOG, math.log10(math.max(v, 1e-6)))
end

function TickingCounter.new(initial: number, smoothTime: number?)
    return setmetatable({
        displayLog = toLog(initial),
        velocity = 0,
        targetLog = toLog(initial),
        smoothTime = smoothTime or 0.22,
        lastDisplayed = initial,
    }, TickingCounter)
end

function TickingCounter:setTarget(v: number)
    self.targetLog = toLog(v)
end

function TickingCounter:step(dt: number): number
    self.displayLog, self.velocity = TweenService:SmoothDamp(
        self.displayLog, self.targetLog, self.velocity, self.smoothTime, nil, dt
    )
    local v = 10 ^ self.displayLog
    -- Snap when close enough that the difference is below display precision;
    -- otherwise the last 0.1% of the spring crawls visibly.
    if math.abs(self.displayLog - self.targetLog) < 1e-4 then
        self.displayLog = self.targetLog
        self.velocity = 0
        v = 10 ^ self.targetLog
    end
    self.lastDisplayed = v
    return v
end

return TickingCounter
```

**Counter polish beyond the interpolation:**

- **Scale-punch the label on each significant increment.** `1.0 → 1.12 → 1.0` over ~180 ms with `Back Out`. Rate-limit it to at most ~6 punches/second or it becomes a vibration.
- **Tint briefly on change.** Green flash on gain, red on spend, held ~120 ms then faded over ~250 ms.
- **Colour the *rate*, not just the value.** If income per second doubled, the "/sec" label should flash. Players track derivative, not integral.
- **Add a subtle tick sound, pitch-quantised to a scale** and heavily rate-limited (§8.5). A counter that ticks musically is enormously satisfying; a counter that machine-guns the same click is torture.

**Buttons.** A button has at minimum four visual states and each needs its own timing.

| State | Change | Duration | Easing |
| --- | --- | --- | --- |
| Idle | Base | — | — |
| **Hover** | Scale 1.00 → 1.03, brightness +8%, subtle lift shadow | 100 ms | `Quad Out` |
| **Press (down)** | Scale → 0.95, brightness −6%, offset down 2 px | **60 ms** | `Quad Out` |
| **Release (up)** | Scale → 1.06 → 1.00 | 180 ms | `Back Out` |
| **Disabled** | Saturation → 0.25, transparency +0.4 | 150 ms | `Quad Out` |

**The press must be under 80 ms.** This is the difference between a responsive button and a mushy one, and it is measurable: input-to-first-visible-change latency above ~100 ms is consciously perceptible.

**The release overshoot is where the satisfaction lives.** Going straight back to 1.0 is correct and boring; overshooting to 1.06 and settling makes the button feel like it *pushed back*.

```lua
--!strict
-- ReplicatedStorage/Client/ButtonFeel.luau
local TweenService = game:GetService("TweenService")
local SoundManager = require(script.Parent.SoundManager)

local HOVER = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local ButtonFeel = {}

function ButtonFeel.bind(button: GuiButton, baseScale: number?)
    local base = baseScale or 1
    local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Scale = base
    scale.Parent = button

    local hovered, pressed = false, false

    local function refresh(info: TweenInfo, target: number)
        TweenService:Create(scale, info, { Scale = target }):Play()
    end

    button.MouseEnter:Connect(function()
        hovered = true
        if not pressed then
            refresh(HOVER, base * 1.03)
            SoundManager.play("ui_hover")      -- quiet, pitch-varied
        end
    end)

    button.MouseLeave:Connect(function()
        hovered = false
        pressed = false
        refresh(HOVER, base)
    end)

    button.MouseButton1Down:Connect(function()
        pressed = true
        refresh(PRESS, base * 0.95)
        SoundManager.play("ui_press")
    end)

    button.MouseButton1Up:Connect(function()
        if not pressed then return end
        pressed = false
        -- Overshoot lives in EasingStyle.Back; the target is the resting scale.
        refresh(RELEASE, hovered and base * 1.03 or base)
        SoundManager.play("ui_release")
    end)
end

return ButtonFeel
```

**Hover on mobile.** There is no hover on touch. Do not build affordances that only exist on hover; use the press state as the primary affordance and treat hover as a desktop bonus. Check `UserInputService.TouchEnabled` and skip hover sounds entirely on touch, or you will play a hover sound on every tap.

---

## 5. Lighting as VFX

Chapter 23 covers the lighting *system* (technology modes, `EnvironmentDiffuseScale`, shadow config, `Lighting` global properties). This section covers lighting as an **effect** — something that changes in response to gameplay.

### 5.1 The three local light types and their cost

All three inherit `Brightness` (float), `Color` (Color3), `Enabled` (boolean) and `Shadows` (boolean) from the abstract `Light` class.

| Class | Own properties | Shape | Use |
| --- | --- | --- | --- |
| `PointLight` | `Range` | Sphere around a point. "ideal for **non-directional** lights like bulbs, torches, and fireballs" | Fire, explosions, glowing pickups, generators |
| `SpotLight` | `Range`, `Angle`, `Face` (`NormalId`) | Cone with spherical base. "ideal for directional lights like street lamps, flashlights, and headlights" | Beams of light, stage lighting on a featured item |
| `SurfaceLight` | `Range`, `Angle`, `Face` (`NormalId`) | Emits from an entire face of the part, not a point. "ideal for lighting from computer screens, billboards, signs, and fluorescent panels" | Glowing UI panels, sign backlighting, screens |

**Hard constraints you must design around (from sibling chapter 23):**

- **`Range` is clamped to 120 studs.** A light cannot illuminate a large base from one point. For a big factory floor you need several lights, not one bright one.
- **Shadows are disabled entirely below graphics quality level 4.** Never build a look that depends on a cast shadow being present. Anything readable only via its shadow is invisible for a large fraction of your players.
- **`EnvironmentDiffuseScale` and `EnvironmentSpecularScale` default to 0**, so by default there is no image-based ambient contribution — scenes look flatter than the same setup in most other engines until you raise them.

**Cost model.** Local lights are the most expensive per-instance renderer feature in common use. Each one with `Shadows = true` costs dramatically more than one without. Practical budget `[UNVERIFIED]` — Roblox does not publish a number; these are conservative working limits:

- Keep **shadow-casting** local lights in the low single digits on screen at once.
- Keep total *enabled* local lights within the camera's view under ~20–30.
- **Cull by distance aggressively** (§9.4): a `PointLight` at 200 studs contributes nothing visible but still costs.

### 5.2 Light as an event, not as decor

The highest-value use of local lights in an incremental game is not ambience — it is **a 150 ms flash co-located with an impact**. A `PointLight` that spikes and decays sells an explosion far better than adding more particles, because it makes the *environment* react.

```lua
--!strict
-- A pooled one-shot light flash. Note: no shadows (too expensive for a
-- 150 ms event), short range, and a decay curve rather than a linear tween.
local TweenService = game:GetService("TweenService")

local function flash(attachment: Attachment, color: Color3, peak: number, range: number, ms: number)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = peak
    light.Range = math.min(range, 120)   -- engine clamp; be explicit
    light.Shadows = false
    light.Enabled = true
    light.Parent = attachment

    -- Quart Out decays fast then lingers -- matches how a real flash dies.
    TweenService:Create(
        light,
        TweenInfo.new(ms / 1000, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Brightness = 0 }
    ):Play()

    game:GetService("Debris"):AddItem(light, ms / 1000 + 0.05)
end
```

Timings: muzzle/impact flash **80–140 ms**; explosion **200–400 ms**; prestige **600–1000 ms** with a slow `Sine` decay.

### 5.3 Flicker and pulse patterns

Naive flicker is `math.random` per frame, and it has exactly the same problem as naive screen shake (§4.1): it is uncorrelated, so it reads as a rendering bug rather than as a flame.

**Use layered noise.** A convincing torch is two or three Perlin octaves at different frequencies:

```lua
--!strict
local RunService = game:GetService("RunService")

-- Fire flicker: slow bulk variation + fast fine detail. Never `math.random`.
local function bindFireFlicker(light: PointLight, base: number, seed: number)
    local t = 0
    return RunService.Heartbeat:Connect(function(dt)
        t += dt
        local slow = math.noise(t * 1.7, seed, 0)          -- bulk brightness
        local fast = math.noise(t * 9.0, seed + 31, 0)     -- crackle
        local flick = 1 + slow * 0.22 + fast * 0.09
        light.Brightness = base * flick
        -- Colour temperature shifts with brightness: hotter = whiter.
        light.Color = Color3.fromRGB(255, 150 + 45 * flick, 60 + 40 * flick)
    end)
end
```

Pattern vocabulary:

| Pattern | Implementation | Reads as |
| --- | --- | --- |
| **Fire flicker** | Two Perlin octaves, ±25%, plus colour-temperature coupling | Living flame |
| **Fluorescent stutter** | Mostly steady, with rare (0.5–2% chance/frame) 2–4 frame dropouts | Broken/derelict |
| **Heartbeat pulse** | `0.5 + 0.5 * math.sin` at 0.8–1.4 Hz, but with a **double-beat** envelope | Organic, alive, tension |
| **Machine hum** | Small ±4% sine at 3–6 Hz | Powered equipment |
| **Charging** | Frequency and amplitude both ramp up over 1–3 s, then a flash | Something about to happen |
| **Idle breathing** | `math.sin` at 0.25–0.4 Hz, ±10% | Calm, at rest |

The **charging** pattern is enormously useful in incremental games: it is how you telegraph an incoming payout, a completing production cycle, or a filling prestige meter, without UI.

### 5.4 Neon used well

`Material.Neon` makes a part self-illuminating in appearance. The failure modes are predictable:

- **Neon at full saturation and full brightness everywhere.** Neon's impact comes entirely from contrast. If 40% of your scene is neon, none of it glows. Target under ~5% of visible surface area.
- **Neon substituting for a light.** A Neon part looks bright but does **not** illuminate its surroundings. If you want a glowing lamp to actually light the floor, it is Neon *plus* a `PointLight`. This is the exact same trap as `LightEmission` on particles (§1.1).
- **Neon in white.** White Neon blows out to a featureless blob under bloom. Use a saturated hue and let bloom carry it toward white at the core — that gradient from saturated edge to white core is what makes it read as *hot* rather than as *bright*.
- **Animating `Color` rather than swapping materials.** Tweening a Neon part's `Color` between a dim and a bright version of the same hue is a cheap, extremely readable state indicator: a generator that is "on" versus "off," an upgrade that is affordable versus not.

Pairing rule: **Neon part (the source) + PointLight (the environmental response) + additive ParticleEmitter (the atmosphere) + BloomEffect (the camera response)**. Four systems, one apparent object. That stack is the difference between "a bright block" and "a power core."

### 5.5 Atmosphere for mood

`Atmosphere` is one instance in `Lighting` with six properties, and it has an outsized effect on how expensive a scene looks, because it produces *aerial perspective* — distant objects desaturating and shifting toward the sky colour. That single cue is most of what separates a scene with depth from a scene of floating blocks.

| Property | Type | Documented role |
| --- | --- | --- |
| `Density` | float | "the amount of particles in the air. The higher the density, the more particles and the more in-game objects/terrain will be obscured." Note: "density does not **directly** affect the skybox" |
| `Offset` | float | "Controls how light transmits between the camera and the sky background. Increase this value to create a horizon silhouette against the sky or reduce it to blend distant objects into the sky for an endless and seamless open world" |
| `Color` | Color3 | "changes the Atmosphere hue for subtle environmental moods... best combined with increased `Haze`" |
| `Decay` | Color3 | "defines the hue of the Atmosphere away from the sun, gradually falling off from `Color` towards this value. Must be used with `Haze` and `Glare` levels" |
| `Glare` | float | "the glow/glare of the Atmosphere around the sun... Must be used with a `Haze` level higher than 0 to see" |
| `Haze` | float | "the haziness of the Atmosphere with a visible effect both above the horizon and into the distance" |

The dependency chain is important and easy to miss: **`Glare` does nothing without `Haze` > 0, and `Decay` does nothing without both `Haze` and `Glare`.** People set `Glare` on a clear atmosphere, see no change, and conclude the property is broken.

**As VFX:** tween `Density` and `Color` on state transitions. Entering a "corrupted" zone, an event mode, or a post-prestige world state is enormously cheap to sell by tweening `Atmosphere.Color` and `Density` over 1.5–2.5 s with `Sine InOut`, plus a matching `ColorCorrectionEffect` shift (§6). Because atmosphere affects the *entire* view, this is one of the few single-instance changes that transforms a whole scene.

---

## 6. Post-processing as feedback

Roblox's post-processing classes (`BloomEffect`, `BlurEffect`, `ColorCorrectionEffect`, `DepthOfFieldEffect`, `SunRaysEffect`) are almost always used as static set dressing. **Their far higher-value use is as feedback: brief, animated responses to gameplay events.** A static bloom is decoration. A bloom that spikes for 120 ms when the player prestiges is the game telling the player something happened.

### 6.1 Bloom, and avoiding the blown-out amateur look

`BloomEffect` has exactly three properties:

- **`Threshold`** — "determines how bright a color can be before it blooms. If set to 1, only pure white colors will bloom. If set to 0, all colors will bloom."
- **`Intensity`** — "how intensely the colors that bloom... will additively blend with themselves. Higher values will produce brighter colors."
- **`Size`** — "the radius of the bloom effect in pixels... Larger values create a wider bloom effect, and a value of 0 will disable the bleed (but not the color adjustment)."

**Why amateur bloom looks bad, precisely:** it is almost always `Threshold` set too *low*. At `Threshold ≈ 0.5`, mid-tones bloom. Mid-tones are most of the image. The result is a uniform haze that reduces contrast everywhere, washes out colour, and — critically — **destroys the bloom's ability to signal anything**, because when everything glows, nothing does.

Bloom is a *selective* effect. Its job is to identify the handful of pixels that are genuinely emissive and give them a halo.

**Tuning recipe:**

1. **Start with `Threshold` high — 0.95 or 1.0 — and `Intensity` at 0.** Nothing blooms.
2. **Raise `Intensity`** until your intentionally-bright elements (Neon, additive particles with `Brightness` > 1, the sun) visibly glow. Typically lands around 0.6–1.2.
3. **Only now lower `Threshold`**, and only until things that *should* glow do. If a grey wall starts glowing, you have gone too far. For most stylised Roblox scenes the final value sits around **0.85–0.95**.
4. **Set `Size` last.** 12–24 px is a tight, "camera lens" bloom. Above ~40 px it becomes a soft dreamy haze — a valid stylistic choice, but it will not read as *brightness*, it reads as *fog*.

The right way to make something bloom more is not to lower `Threshold` — it is to raise that object's own brightness (`ParticleEmitter.Brightness`, `Beam.Brightness`, a brighter Neon colour) so it crosses the existing threshold. That keeps bloom selective.

**`Size = 0` is a documented special case:** "a value of 0 will disable the bleed (but not the color adjustment)." Useful as a cheap mobile fallback — you keep the tonal lift without paying for the blur.

### 6.2 Animating post effects as feedback

The core pattern is a **transient**: push a value, then decay it back over a controlled duration. Never leave a feedback effect at its peak.

```lua
--!strict
-- ReplicatedStorage/Client/PostFX.luau
-- Transient post-processing feedback. All effects live as singletons in
-- Lighting; we animate their properties rather than creating instances,
-- because creating/destroying PostEffect instances causes a shader rebuild.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local PostFX = {}

local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local blur = Lighting:FindFirstChildOfClass("BlurEffect")

-- Baselines captured once so transients always return to the authored look.
local baseBloomIntensity = bloom and bloom.Intensity or 0
local baseSaturation = cc and cc.Saturation or 0
local baseContrast = cc and cc.Contrast or 0
local baseBrightness = cc and cc.Brightness or 0

--- Bloom punch: instant spike, eased decay. 90-160 ms for a hit,
--- 400-700 ms for a prestige.
function PostFX.bloomPunch(amount: number, decayMs: number)
    if not bloom then return end
    bloom.Intensity = baseBloomIntensity + amount
    TweenService:Create(
        bloom,
        TweenInfo.new(decayMs / 1000, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Intensity = baseBloomIntensity }
    ):Play()
end

--- Saturation dip: the "impact" post effect. Desaturate hard for ~60 ms,
--- then recover over ~300 ms. Reads as a shock to the image.
function PostFX.impactDesaturate(depth: number)
    if not cc then return end
    cc.Saturation = baseSaturation - depth
    cc.Contrast = baseContrast + depth * 0.4
    task.delay(0.06, function()
        TweenService:Create(
            cc,
            TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Saturation = baseSaturation, Contrast = baseContrast }
        ):Play()
    end)
end

--- Screen flash via ColorCorrection brightness. Cheaper and more controllable
--- than a full-screen Frame, and it composites under the UI rather than over it.
function PostFX.flash(strength: number, ms: number)
    if not cc then return end
    cc.Brightness = baseBrightness + strength
    TweenService:Create(
        cc,
        TweenInfo.new(ms / 1000, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        { Brightness = baseBrightness }
    ):Play()
end

--- Modal focus: blur the world behind a panel. Blur IN fast, OUT slower.
function PostFX.modalBlur(active: boolean)
    if not blur then return end
    TweenService:Create(
        blur,
        TweenInfo.new(active and 0.18 or 0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = active and 18 or 0 }
    ):Play()
end

--- Sustained state tint, e.g. an active event or boosted period.
function PostFX.setMood(tint: Color3, saturation: number, seconds: number)
    if not cc then return end
    TweenService:Create(
        cc,
        TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { TintColor = tint, Saturation = saturation }
    ):Play()
end

return PostFX
```

### 6.3 A feedback vocabulary

| Event | Effect | Magnitude | Timing |
| --- | --- | --- | --- |
| Small purchase | — | — | Do not use post-processing. It is a global effect; reserve it for global events |
| Big purchase | `bloomPunch` | +0.25 | 160 ms decay |
| Milestone | `bloomPunch` + `flash` | +0.5, +0.12 | 300 ms / 180 ms |
| Prestige | `flash` → `impactDesaturate` → `bloomPunch` | +0.5, 0.9, +1.0 | 250 / 60+300 / 700 ms |
| Damage / loss | `impactDesaturate` + red `TintColor` | 0.6 | 80 ms in, 400 ms out |
| Modal open | `modalBlur` | 18 px | 180 ms |
| Offline-earnings summary | `modalBlur` + `setMood` warm | 14 px, sat +0.15 | 400 ms |
| Entering special zone | `setMood` | tint + saturation | 1.5–2.5 s |

**Rules:**

1. **Post-processing is global.** It affects everything the player sees, including UI-adjacent world content. Use it only for events that *are* global in significance. Firing a bloom punch on every click is the post-processing equivalent of screen-shaking on every click.
2. **Always return to a captured baseline**, never to a hard-coded 0. Otherwise a designer changing the authored look gets silently overwritten by the first transient.
3. **Do not create and destroy `PostEffect` instances at runtime.** Keep one of each in `Lighting`, `Enabled` as needed, and animate properties. `[UNVERIFIED]` — Roblox does not document a shader-rebuild cost for instance churn, but the general principle (avoid instantiating renderer objects in hot paths) applies, and property animation is strictly cheaper.
4. **`DepthOfFieldEffect` is for cinematics, not feedback.** Its four properties (`FocusDistance`, `InFocusRadius`, `NearIntensity`, `FarIntensity`) let you rack focus during a cutscene or a reward reveal, which is lovely, but animating DoF during gameplay makes the game feel unresponsive because it blurs whatever the player is looking at.
5. **`SunRaysEffect` (`Intensity`, `Spread`) is set dressing, not feedback** — it depends on the sun being on screen, which you do not control.

### 6.4 Mobile and low-end

Post-processing is full-screen and therefore fill-rate-bound — exactly what mobile GPUs are worst at. Gate the stack on quality level (§9.5):

| Quality | Bloom | ColorCorrection | Blur | DoF | SunRays |
| --- | --- | --- | --- | --- | --- |
| 1–3 | Off (or `Size = 0`) | On (cheap, and it carries your art direction) | Off | Off | Off |
| 4–6 | On, `Size ≤ 16` | On | Modal only | Off | Off |
| 7–10 | Full | On | On | On | On |

`ColorCorrectionEffect` should be the **last** thing you disable — it is comparatively cheap and it carries more of your art direction than anything else in the list.

---

## 7. The no-shader workarounds

Roblox does not expose custom shaders. Everything that would be a fragment shader in another engine has to be faked. This is the catalogue of substitutes, ordered by cost.

| Technique | What it substitutes for | Cost | Where covered |
| --- | --- | --- | --- |
| **Particle flipbooks** | Animated procedural textures (fire, smoke, dissolve) | Very low (GPU); texture memory | §1.6 |
| **Scrolling UV via `Beam`/`Trail` `TextureSpeed`** | Panning/scrolling shaders | Near-zero | §2.3 |
| **Scrolling UV via `Texture.OffsetStudsU/V`** | Same, on part surfaces | Near-zero | §7.1 |
| **`SurfaceAppearance`** | PBR material shaders | Free at runtime; authoring cost | Chapter 23 |
| **Layered transparent geometry** | Volumetrics, fresnel rims, glow | Low–medium (overdraw) | §7.2 |
| **`EditableImage`** | Genuine per-pixel procedural texturing | **High (CPU)** | Chapters 20 & 40 |
| **`EditableMesh`** | Vertex shaders, deformation | Medium–high (CPU) | Chapters 21 & 41 |
| **`BillboardGui`** | Screen-space overlays anchored in world | Low | §7.3 |
| **`ViewportFrame`** | Render-to-texture, portals, item previews | Medium | §7.4 |
| **`Highlight`** | Outline / rim shader | Low, but **hard 255-instance cap** | §7.5 |

### 7.1 Scrolling UVs on surfaces

A `Texture` instance on a part face exposes `OffsetStudsU` and `OffsetStudsV`. Animating them is a free scrolling-texture shader.

```lua
--!strict
-- Conveyor / energy-flow surface. One connection can drive many textures.
local RunService = game:GetService("RunService")

local function bindScroll(textures: { Texture }, speedU: number, speedV: number)
    local u, v = 0, 0
    return RunService.Heartbeat:Connect(function(dt)
        u += speedU * dt
        v += speedV * dt
        -- Wrap to keep the numbers small; Texture tiling is periodic in
        -- StudsPerTile, so wrapping there is seamless.
        for _, tex in textures do
            tex.OffsetStudsU = u % tex.StudsPerTileU
            tex.OffsetStudsV = v % tex.StudsPerTileV
        end
    end)
end
```

Two scrolling `Texture` layers at different speeds and opacities on the same face gives parallax — the classic cheap "flowing energy" or "moving cloud shadow" look. Combined with a `SurfaceAppearance` underneath, this covers most of what a simple panner shader would do.

### 7.2 Layered transparent geometry

A fresnel/rim glow is a shader in other engines. On Roblox it is **a slightly larger, inverted-ish copy of the mesh with a soft transparent texture**, or more simply, two or three concentric transparent shells:

- **Glow shell**: a part 10–20% larger than the object, `Material = Neon`, `Transparency` 0.85–0.95. Reads as a halo. Nearly free.
- **Volumetric light shaft**: a cone mesh, `Neon`, `Transparency` ~0.9, with `CastShadow = false`. Two nested cones at different transparencies read far better than one.
- **Force field / dome**: a sphere with a tiling hex texture, `Transparency` ~0.8, slowly rotating, plus a second counter-rotating shell.

The cost is **overdraw**, which is the mobile GPU's worst enemy. Rules: keep shells to 2–3 layers; never let a transparent shell fill the screen; disable shells beyond a distance threshold.

### 7.3 Billboards

`BillboardGui` gives you a screen-facing 2D surface anchored to a world position, with full `GuiObject` capability inside. Uses that matter here:

- **Damage/gain number popups** (§4.4). A `BillboardGui` with `AlwaysOnTop` for numbers that must not be occluded.
- **Soft glow sprites** — an `ImageLabel` with a radial gradient, `ImageTransparency` animated. Cheaper than a particle emitter for a single persistent glow, and precisely positioned.
- **Distance-scaled icons** — set `Size` in `UDim2` offset (pixels) rather than scale for a constant on-screen size regardless of distance, which is how you make world-anchored icons legible at any range.

`BillboardGui` is a UI object, so the cost model is the UI cost model (chapter 63), not the particle cost model. Hundreds of them will hurt; pool them.

### 7.4 ViewportFrame

`ViewportFrame` renders a separate 3D scene into a 2D UI region. It is the closest thing Roblox has to render-to-texture. Uses:

- **Item / upgrade previews** — a rotating 3D model of the thing you are about to buy, inside the purchase panel. This is a large perceived-quality win in shop UI and is very common in well-made incremental games.
- **Character preview** in a customisation panel.
- **Fake portals / windows** into another location.

Cost: each `ViewportFrame` is an additional scene render. A handful is fine; a grid of 40 item cards each with a live `ViewportFrame` is not — render them lazily (only while visible, only while the panel is open) and freeze rotation for off-screen cards.

### 7.5 Highlight — and the 255 cap

`Highlight` provides an outline + fill overlay on a model or part (`Adornee`, `DepthMode`, `Enabled`, `FillColor`, `FillTransparency`, `OutlineColor`, `OutlineTransparency`; `LineThickness` and `ReservedId` exist but are `RobloxScriptSecurity` and `Hidden` per the API dump, so they are not usable from your code).

**The constraint that dominates its use: `Highlight` is capped at 255 client instances, and a disabled `Highlight` still consumes a slot.** (From sibling chapter work; the cap is not stated in the public reference — treat the exact number as `[COMMUNITY, SECOND-HAND]` but the behaviour as established.)

Consequences for an incremental game, where "highlight every affordable upgrade" is an obvious feature:

1. **Never pool `Highlight` instances by disabling them.** Pooling works for beams, trails and emitters; it does not work here. `Destroy()` them.
2. **Cap your own usage well below 255** — budget perhaps 32 — and implement a strict LRU: when you need a new highlight and are at budget, destroy the least recently used one.
3. **Prefer alternatives at scale.** For "this is affordable," a `UIStroke` on the shop button, a Neon colour swap on the object, or a `SelectionBox` costs you nothing from the highlight budget.

```lua
--!strict
-- Budgeted Highlight manager. Destroys rather than disables, because a
-- disabled Highlight still occupies one of the 255 client slots.
local HighlightBudget = {}

local BUDGET = 32
local active: { [Instance]: Highlight } = {}
local order: { Instance } = {}   -- LRU, oldest first

local function touch(adornee: Instance)
    for i, v in order do
        if v == adornee then
            table.remove(order, i)
            break
        end
    end
    table.insert(order, adornee)
end

function HighlightBudget.clear(adornee: Instance)
    local h = active[adornee]
    if h then
        h:Destroy()                       -- Destroy, never Enabled = false
        active[adornee] = nil
    end
    for i, v in order do
        if v == adornee then table.remove(order, i) break end
    end
end

function HighlightBudget.set(adornee: Instance, fill: Color3, outline: Color3): Highlight
    local existing = active[adornee]
    if existing then
        existing.FillColor, existing.OutlineColor = fill, outline
        touch(adornee)
        return existing
    end

    while #order >= BUDGET do
        HighlightBudget.clear(order[1])
    end

    local h = Instance.new("Highlight")
    h.Adornee = adornee
    h.FillColor, h.OutlineColor = fill, outline
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = adornee
    active[adornee] = h
    touch(adornee)
    return h
end

return HighlightBudget
```

---

## 8. Audio: the other half of game feel

Audio is not the polish pass. It is **half of the feel**, and it is the half that is cheapest to do well and most commonly done badly. A game with excellent VFX and one un-varied click sound feels worse than a game with plain VFX and layered, varied, well-mixed audio — because audio latency and repetition are perceived far more acutely than visual imperfection.

Everything below uses the legacy `Sound`/`SoundService` API, which is what you should ship on today. The newer `AudioPlayer`/`AudioEmitter`/`AudioListener` "advanced audio system" exists alongside it (visible in `SoundService.AcousticSimulationEnabled`, `OcclusionEnabled`, `DiffractionEnabled`, `ReverbEnabled`, and `CharacterSoundsUseNewApi`), and several `SoundService` properties explicitly note they "do not impact the behavior of instances in the advanced audio system." Mixing the two systems means your global tuning silently applies to only half your sounds. **Pick one. For an incremental game, `Sound` is sufficient and far better documented.**

### 8.1 SoundService and SoundGroups — build the mixer first

`SoundGroup` has exactly one own property: `Volume` ("the volume multiplier applied to `Sounds` which belong to the `SoundGroup`. Value can range from 0 to 10"). `SoundGroup`s **nest**, so you build a mixer tree. Do this on day one; retrofitting a mixer into a shipped game is miserable.

```
Master (SoundGroup)
├── Music
│   ├── Ambient
│   └── Stingers
├── SFX
│   ├── UI
│   ├── Economy      (purchases, currency, counters)
│   ├── World        (machines, ambience, footsteps)
│   └── Events       (prestige, milestones, rare drops)
└── Voice
```

Why it must exist:

- **Player volume settings** map directly onto `Music`, `SFX`, `Voice` group volumes. Without groups you are iterating every `Sound` in the game.
- **Ducking** (§8.6) is a tween on one group's `Volume`.
- **Mix balance is a tuning knob, not a per-asset edit.** "UI is too loud" is one number.

```lua
--!strict
-- ReplicatedStorage/Audio/Mixer.luau -- run once on the client.
local SoundService = game:GetService("SoundService")

local TREE = {
    Master = {
        Music = { "Ambient", "Stingers" },
        SFX = { "UI", "Economy", "World", "Events" },
        Voice = {},
    },
}

local groups: { [string]: SoundGroup } = {}

local function build(name: string, parent: Instance, children: any)
    local g = Instance.new("SoundGroup")
    g.Name = name
    g.Volume = 1
    g.Parent = parent
    groups[name] = g
    if typeof(children) == "table" then
        for k, v in children do
            if typeof(k) == "string" then build(k, g, v) else build(v, g, {}) end
        end
    end
    return g
end

for name, children in TREE do
    build(name, SoundService, children)
end

local Mixer = {}
function Mixer.get(name: string): SoundGroup
    return groups[name] or groups.Master
end
function Mixer.setVolume(name: string, v: number)
    local g = groups[name]
    if g then g.Volume = math.clamp(v, 0, 10) end
end
return Mixer
```

**`SoundService.RespectFilteringEnabled` matters for architecture.** From the reference: "when a `LocalScript` calls `Play()` and this property is `true`, the sound will only play on the respective client. If this property is `false`, other clients will also hear the sound." Set it `true` and drive all feedback audio locally — this is both correct (feedback is per-player) and much cheaper than replicating.

### 8.2 3D sound: RollOff, distances, EmitterSize

A `Sound` is **3D (spatialised) only when it is a direct child of a `BasePart` or an `Attachment`.** Parented anywhere else (including `SoundService` or a `ScreenGui`) it is 2D and plays at full volume regardless of position. This one rule explains most "why isn't my sound positional" confusion.

Key properties:

| Property | Meaning |
| --- | --- |
| `RollOffMinDistance` | "The minimum distance, in studs, at which a `Sound`... will begin to attenuate." Inside this radius the sound is at full volume |
| `RollOffMaxDistance` | "The maximum distance, in studs, a client's listener can be from the sound's origin and still hear it" |
| `RollOffMode` | The attenuation curve; see below |
| `EmitterSize` | "The minimum distance, in studs, at which a 3D `Sound`... will begin to attenuate" — documented identically to `MinDistance`. Treat `EmitterSize`/`MinDistance`/`RollOffMinDistance` as the same concept: **the size of the thing making the sound** |
| `MinDistance` / `MaxDistance` | Older aliases of the RollOff pair |

`Enum.RollOffMode`, with the documented formulas:

| Mode | Formula (from the reference) | Character | Use for |
| --- | --- | --- | --- |
| `Inverse` | `RollOffMinDistance / distance` — "mirroring how sounds attenuate in the real world" | Realistic: drops fast up close, long quiet tail | Most world sounds. **The default choice** |
| `Linear` | `(MaxDistance/distance)/(MaxDistance − MinDistance)` | Even fade, hard cut-off at max | Sounds that must be *fully* gone at a known radius |
| `LinearSquare` | Linear, squared | Quieter in the middle distance than Linear | Localised sounds you don't want bleeding across a base |
| `InverseTapered` | "the lesser of `Inverse` and `LinearSquare`" | Realistic near-field, guaranteed silence at max | **Best of both. Use this when you want realism and a hard budget on audible radius** |

Two global modifiers in `SoundService`:

- **`RolloffScale`** — "A higher `RolloffScale` means the volume of a `Sound` will attenuate more rapidly as the distance between the listener and the `Sound` grows... the `Sound` will still be inaudible past its `RollOffMaxDistance` regardless."
- **`DistanceFactor`** — "The number of studs to be considered a meter... when simulating the Doppler effect. By default, this property is `3.33`." Paired with `DopplerScale` (default `1`). Note both are explicitly documented as Doppler-only, and as *not* affecting the advanced audio system.

**`EmitterSize` is the most underused property in Roblox audio.** It is the *size* of the sound source. A tiny `EmitterSize` (0.5) makes a sound a precise point that pans sharply as you walk past it — correct for a button, a drip, a small mechanism. A large `EmitterSize` (20–40) makes the sound diffuse and omnidirectional up close — correct for a waterfall, a large machine, a crowd, an ambient zone. Setting everything to the default makes every sound in your world feel like the same size object, which is one of the subtler reasons amateur soundscapes feel flat.

**A distance recipe table** `[UNVERIFIED — craft guidance]`:

| Source | `EmitterSize`/`RollOffMinDistance` | `RollOffMaxDistance` | `RollOffMode` |
| --- | --- | --- | --- |
| UI / feedback | n/a — keep it 2D | — | — |
| Small click, coin | 2 | 40 | `InverseTapered` |
| Machine / generator | 8 | 90 | `InverseTapered` |
| Large factory hum | 25 | 180 | `Inverse` |
| Waterfall / zone ambience | 35 | 250 | `Inverse` |
| Explosion | 12 | 400 | `Inverse` |

**Listener.** `SoundService.ListenerType` defaults to `Workspace.CurrentCamera`. For a top-down or far-zoomed incremental game, a camera listener means sounds attenuate based on camera distance, which can be wildly wrong when the camera is 200 studs up. Consider `SoundService:SetListener(Enum.ListenerType.ObjectPosition, character.PrimaryPart)` so the mix follows the player, not the camera. Retrieve current state with `SoundService:GetListener()`.

### 8.3 Pitch randomisation — the single easiest quality win

If you implement one thing from this section, implement this.

**The problem:** the same audio file played twice in 200 ms sounds, to the human ear, like a *digital artefact*, not like two events. Our hearing is extremely good at detecting exact repetition — it is how we distinguish a real sound from an echo or a recording. A shop button clicked ten times in a row with a single unvaried sample is the loudest "this is a cheap game" signal in your entire build.

**The fix, in one line:**

```lua
sound.PlaybackSpeed = 1 + (rng:NextNumber() - 0.5) * 2 * variance
```

`PlaybackSpeed` "determines the speed at which a `Sound` will play, with higher values causing the sound to play faster and at a higher pitch." (`Pitch` is the older equivalent property; prefer `PlaybackSpeed`.) Note the coupling: **changing pitch also changes duration**, because it is resampling, not a pitch shifter. This is fine — even desirable — at small variances, because the tiny timing variation adds to the sense of separate events.

**Variance calibration:**

| Sound type | Variance (±) | Notes |
| --- | --- | --- |
| UI click / hover | 0.04–0.06 | Subtle; you should not consciously hear the pitch change |
| Coin / currency tick | 0.08–0.12 | |
| Generic impact | 0.10–0.15 | |
| Footstep | 0.12–0.18 | Also vary the sample |
| Debris / particle scatter | 0.20–0.30 | Chaos is the point |
| Music / stinger | **0** | Never pitch-vary anything tonal against other tonal content |
| Voice | 0–0.03 | Beyond this it sounds like a chipmunk |

**Also randomise volume**, by ±10–15%. Pitch and volume variance together are roughly twice as effective as either alone.

**Sample rotation beats variance for high-repetition sounds.** For anything that fires more than ~3×/second, ship 3–5 variants of the sample and pick randomly *in addition* to pitch variance. Avoid immediate repeats (pick from the set minus the last-played index) — true randomness produces audible doubles surprisingly often.

**The musical alternative: pitch quantisation.** For a rapid stream of ticks (a counter rolling, coins collecting in sequence), instead of random pitch, walk a **musical scale**. Each successive tick in a run steps up a pentatonic scale; the run resets after a pause. This turns a repetitive sound into an ascending arpeggio and is one of the most satisfying effects available in an incremental game.

```lua
--!strict
-- Pentatonic ladder for run-of-ticks feedback. Semitone -> playback ratio is
-- 2^(n/12); a pentatonic scale avoids dissonance regardless of where a run stops.
local PENTATONIC = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24 }

local ladderIndex = 0
local lastTick = 0

local function ladderSpeed(now: number, resetAfter: number): number
    if now - lastTick > resetAfter then
        ladderIndex = 0
    else
        ladderIndex = math.min(ladderIndex + 1, #PENTATONIC - 1)
    end
    lastTick = now
    local semitones = PENTATONIC[ladderIndex + 1]
    return 2 ^ (semitones / 12)
end
```

### 8.4 Layered sound design for one event

A professional-sounding impact is **not one sample**. It is three or four, each doing a different job, each with independent variance. This mirrors the visual layering in §1.5 exactly, and for the same reason: the ear resolves the layers as a single rich event rather than a single thin one.

The standard decomposition:

| Layer | Frequency range | Job | Timing |
| --- | --- | --- | --- |
| **Transient / attack** | High (2–8 kHz) | The *click*. Defines the exact moment and cuts through a busy mix. This layer is what makes a sound feel *tight* | t = 0, 20–60 ms long |
| **Body / thump** | Low–mid (80–400 Hz) | The *weight*. Defines how big the thing is | t = +10 to +40 ms, 80–250 ms long |
| **Tail / ring** | Mid, decaying | The *space*. Defines where the event happened | t = +60 to +150 ms, 300 ms–2 s |
| **Detail / texture** | Variable | Material identity: glass tinkle, metal scrape, coin jingle | Sprinkled across the whole event |

**Scaling by magnitude.** The magic is that you scale *which layers play and how loud* by event magnitude, using the same three samples. A small purchase plays transient only at 0.4 volume. A prestige plays all four at full with an extra-long tail. One sound family, ten distinct intensities, no extra assets.

**Pitch-shift the body layer down for bigger events.** Scaling `PlaybackSpeed` of the body layer from 1.1 (small) to 0.78 (huge) makes the same sample read as a progressively larger object. This is how one thump sample covers a whole tier ladder.

### 8.5 A production sound manager

Pooling, pitch variance, layering, rate limiting, 2D/3D routing, in one module.

```lua
--!strict
-- ReplicatedStorage/Audio/SoundManager.luau (client)
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Mixer = require(script.Parent.Mixer)

local rng = Random.new()

export type LayerDef = {
    ids: { string },            -- 1+ variants; rotated to avoid repeats
    volume: number,
    pitchVariance: number,      -- +/- fraction
    volumeVariance: number?,    -- default 0.12
    delayMs: number?,           -- offset from event time
    minMagnitude: number?,      -- layer only plays at/above this magnitude
    pitchByMagnitude: NumberRange?, -- playback speed at magnitude 0 .. 1
    rollOffMin: number?,
    rollOffMax: number?,
    rollOffMode: Enum.RollOffMode?,
    emitterSize: number?,
    group: string?,             -- SoundGroup name
}

export type FamilyDef = {
    layers: { LayerDef },
    cooldownMs: number?,        -- rate limit for the whole family
    maxConcurrent: number?,
}

local SoundManager = {}

local families: { [string]: FamilyDef } = {}
local lastPlayed: { [string]: number } = {}
local concurrent: { [string]: number } = {}
local lastVariant: { [string]: number } = {}

-- Pool: one free-list per assetId. Pooling matters because Instance.new +
-- Parent for a Sound is not free at the rates an incremental game hits.
local pool: { [string]: { Sound } } = {}
local POOL_MAX_PER_ID = 8

local function acquire(assetId: string): Sound
    local bucket = pool[assetId]
    if bucket and #bucket > 0 then
        return table.remove(bucket) :: Sound
    end
    local s = Instance.new("Sound")
    s.SoundId = assetId
    return s
end

local function release(s: Sound)
    s:Stop()
    s.Parent = nil
    s.TimePosition = 0
    local bucket = pool[s.SoundId]
    if not bucket then
        bucket = {}
        pool[s.SoundId] = bucket
    end
    if #bucket < POOL_MAX_PER_ID then
        table.insert(bucket, s)
    else
        s:Destroy()
    end
end

function SoundManager.register(name: string, def: FamilyDef)
    families[name] = def
end

local function pickVariant(key: string, ids: { string }): string
    if #ids == 1 then return ids[1] end
    local last = lastVariant[key]
    local i = rng:NextInteger(1, #ids)
    if i == last then                        -- avoid immediate repeats
        i = (i % #ids) + 1
    end
    lastVariant[key] = i
    return ids[i]
end

local function playLayer(layer: LayerDef, at: (Vector3 | Instance)?, magnitude: number, key: string)
    if layer.minMagnitude and magnitude < layer.minMagnitude then return end

    local assetId = pickVariant(key, layer.ids)
    local s = acquire(assetId)

    -- Pitch: magnitude-driven base, then random variance on top.
    local base = 1
    if layer.pitchByMagnitude then
        base = layer.pitchByMagnitude.Min
             + (layer.pitchByMagnitude.Max - layer.pitchByMagnitude.Min) * (1 - magnitude)
    end
    local pv = layer.pitchVariance
    s.PlaybackSpeed = base * (1 + (rng:NextNumber() - 0.5) * 2 * pv)

    local vv = layer.volumeVariance or 0.12
    s.Volume = layer.volume
        * (0.35 + 0.65 * magnitude)
        * (1 + (rng:NextNumber() - 0.5) * 2 * vv)

    s.SoundGroup = Mixer.get(layer.group or "SFX")

    -- 3D only if parented to a BasePart/Attachment.
    local parent: Instance
    if typeof(at) == "Vector3" then
        local a = Instance.new("Attachment")
        a.WorldPosition = at
        a.Parent = workspace.Terrain
        parent = a
        Debris:AddItem(a, 12)
    elseif typeof(at) == "Instance" then
        parent = at
    else
        parent = SoundService          -- 2D
    end

    if parent:IsA("BasePart") or parent:IsA("Attachment") then
        s.RollOffMode = layer.rollOffMode or Enum.RollOffMode.InverseTapered
        s.RollOffMinDistance = layer.rollOffMin or 8
        s.RollOffMaxDistance = layer.rollOffMax or 120
        s.EmitterSize = layer.emitterSize or layer.rollOffMin or 8
    end

    s.Parent = parent
    s:Play()

    local family = key
    concurrent[family] = (concurrent[family] or 0) + 1
    s.Ended:Once(function()
        concurrent[family] = math.max(0, (concurrent[family] or 1) - 1)
        release(s)
    end)
    -- Safety net: Ended does not fire if the sound is stopped/destroyed early.
    Debris:AddItem(s, 15)
end

--- Play a whole layered family at a world position (or nil for 2D).
--- `magnitude` in [0,1] scales which layers fire and how loud/low they are.
function SoundManager.playLayered(name: string, at: (Vector3 | Instance)?, magnitude: number?)
    local def = families[name]
    if not def then
        warn(("SoundManager: unknown family %q"):format(name))
        return
    end

    local now = os.clock()
    local cooldown = (def.cooldownMs or 0) / 1000
    if cooldown > 0 and now - (lastPlayed[name] or -1e9) < cooldown then
        return
    end
    if def.maxConcurrent and (concurrent[name] or 0) >= def.maxConcurrent then
        return
    end
    lastPlayed[name] = now

    local m = math.clamp(magnitude or 1, 0, 1)
    for _, layer in def.layers do
        local d = (layer.delayMs or 0) / 1000
        if d > 0 then
            task.delay(d, playLayer, layer, at, m, name)
        else
            playLayer(layer, at, m, name)
        end
    end
end

--- Convenience for single-layer 2D UI sounds.
function SoundManager.play(name: string)
    SoundManager.playLayered(name, nil, 1)
end

return SoundManager
```

And a family definition showing the layering in practice:

```lua
SoundManager.register("purchase", {
    cooldownMs = 40,          -- rate limit: a held buy button must not machine-gun
    maxConcurrent = 6,
    layers = {
        -- Transient: always plays, defines the moment.
        { ids = { "rbxassetid://0", "rbxassetid://0", "rbxassetid://0" },
          volume = 0.55, pitchVariance = 0.06, delayMs = 0, group = "UI" },
        -- Body: only for meaningful purchases; pitches DOWN as magnitude rises.
        { ids = { "rbxassetid://0" },
          volume = 0.7, pitchVariance = 0.05, delayMs = 25,
          minMagnitude = 0.25,
          pitchByMagnitude = NumberRange.new(0.78, 1.10),
          group = "Economy" },
        -- Tail: big purchases only.
        { ids = { "rbxassetid://0" },
          volume = 0.35, pitchVariance = 0.03, delayMs = 110,
          minMagnitude = 0.6, group = "Economy" },
    },
})
```

**`SoundService:PlayLocalSound(sound)`** is the shortcut for fire-and-forget client-only playback: "Plays a copy of a `Sound` locally. The `Sound` will only be heard by the client calling this method, regardless of where it's parented to." Carried over into the copy: "`Volume`, `TimePosition`, `PlaybackSpeed`, and any spatialization and effects that are applied to it, including through `SoundGroups`." **Not** carried over: "`Looped` and `SoundService.AmbientReverb`."

That exclusion list is the deciding factor. `PlayLocalSound` is excellent for one-shot UI feedback (no pooling, no cleanup, respects your mixer and pitch), and wrong for anything that should sit in the room's reverb, since `AmbientReverb` does not apply to the copy.

### 8.6 Ducking

Ducking is lowering one bus while another plays, so the important thing is audible. With a `SoundGroup` tree it is a tween on one `Volume`.

```lua
--!strict
-- Duck music under a stinger or an important SFX event.
local TweenService = game:GetService("TweenService")
local Mixer = require(script.Parent.Mixer)

local duckDepth = 0
local activeDucks = 0

local function applyDuck()
    local music = Mixer.get("Music")
    local target = activeDucks > 0 and (1 - duckDepth) or 1
    TweenService:Create(
        music,
        -- Duck DOWN fast (attack), come back UP slowly (release).
        TweenInfo.new(activeDucks > 0 and 0.08 or 0.45,
            Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Volume = target }
    ):Play()
end

local function duck(depth: number, holdSeconds: number)
    duckDepth = math.max(duckDepth, depth)
    activeDucks += 1
    applyDuck()
    task.delay(holdSeconds, function()
        activeDucks -= 1
        if activeDucks <= 0 then duckDepth = 0 end
        applyDuck()
    end)
end
```

**The asymmetry is the whole technique: fast attack (60–120 ms), slow release (300–600 ms).** Fast attack means the duck is already complete by the time the loud thing hits. Slow release means the music comes back without a noticeable "pop." Symmetric timings sound like a broken volume slider.

Duck depths: a stinger ducks music by 0.5–0.7; a prestige cinematic ducks everything but `Events` by 0.8; an important UI notification ducks by 0.25.

### 8.7 Adaptive music and stingers

**The layered-stems model.** Rather than switching tracks (which always has a seam), author your music as *N* stems at the same tempo and length — e.g. `drums`, `bass`, `pad`, `lead`, `arp` — play all of them looped and perfectly synchronised from the start, and **crossfade stem volumes** to change intensity. Adding the `lead` stem as the player reaches a new tier is seamless, instant, and needs no transition logic.

For an incremental game the intensity axis is obvious: **progression tier**. Early game = pad + bass. Mid = + drums. Late = + arp. Post-prestige = all stems plus a key change (a new stem set).

```lua
--!strict
-- Stem-based adaptive music. All stems play from t=0 in lockstep; only
-- volumes change. No transition logic, no seams, no beat-matching needed.
local TweenService = game:GetService("TweenService")

local MusicLayers = {}
local stems: { [string]: Sound } = {}

function MusicLayers.start(defs: { [string]: string }, group: SoundGroup)
    for name, id in defs do
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Looped = true
        s.Volume = 0
        s.SoundGroup = group
        s.PlaybackSpeed = 1        -- NEVER pitch-vary music
        s.Parent = group
        stems[name] = s
    end
    -- Start them all in the same frame so they stay phase-locked.
    for _, s in stems do s:Play() end
end

function MusicLayers.setIntensity(levels: { [string]: number }, seconds: number)
    for name, s in stems do
        local target = levels[name] or 0
        TweenService:Create(
            s,
            TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Volume = target }
        ):Play()
    end
end

return MusicLayers
```

Crossfade over **2–4 seconds** with `Sine InOut`. Faster and the player notices the change as an event rather than as a mood shift.

**Stingers.** A stinger is a short musical phrase layered *over* the music to mark an event. Rules:

1. **Stingers must be in the same key and tempo as the music**, or they will clash. This is an authoring constraint, not a code one, and it is the one people get wrong.
2. **Never pitch-vary a stinger** (§8.3).
3. **Duck the music under it** (§8.6) by 0.4–0.6.
4. **Schedule it on a beat** where possible. `SoundService:GetMixerTime()` is documented as "stable, sample-accurate, and monotonically increasing, which makes it suitable for scheduling audible changes at precise moments" — it is the correct clock for this, because `os.clock()` and `RunService` time drift against the audio mixer. `[UNVERIFIED]` — the reference frames `GetMixerTime()` primarily around the `AudioPlayer:Play(atTime)` API of the advanced audio system; legacy `Sound:Play()` takes no scheduling argument, so with `Sound` you use it as a *reference clock* to decide when to call `Play()`, which gives you frame-accurate rather than sample-accurate placement.

```lua
--!strict
-- Beat-aligned stinger with legacy Sound. GetMixerTime is the reference clock;
-- we still call Play() from a frame, so alignment is ~frame-accurate.
local SoundService = game:GetService("SoundService")

local BPM = 120
local SECONDS_PER_BEAT = 60 / BPM
local musicStartMixerTime = 0     -- captured when the music loop started

local function beatsUntilNext(divisions: number): number
    local elapsed = SoundService:GetMixerTime() - musicStartMixerTime
    local period = SECONDS_PER_BEAT * divisions
    return period - (elapsed % period)
end

local function playStingerOnBeat(stinger: Sound, divisions: number, maxWait: number)
    local wait = beatsUntilNext(divisions)
    -- If the next slot is too far out, just play now: responsiveness beats
    -- musicality for gameplay feedback.
    if wait > maxWait then
        stinger:Play()
    else
        task.delay(wait, function() stinger:Play() end)
    end
end
```

The `maxWait` escape hatch matters. Waiting up to two seconds for a downbeat makes the game feel unresponsive. Align to the nearest 1/2 or 1/4 beat with a `maxWait` around 0.25 s, and play immediately otherwise.

### 8.8 Reverb

`SoundService.AmbientReverb` takes an `Enum.ReverbType` — 24 presets from `NoReverb` and `GenericReverb` through `PaddedCell`, `Room`, `Bathroom`, `LivingRoom`, `StoneRoom`, `Auditorium`, `ConcertHall`, `Cave`, `Arena`, `Hangar`, `CarpettedHallway`, `Hallway`, `StoneCorridor`, `Alley`, `Forest`, `City`, `Mountains`, `Quarry`, `Plain`, `ParkingLot`, `SewerPipe`, to `UnderWater`.

It is a **global** setting, so it is a *zone* tool: change it as the player moves between spaces. For an incremental game with distinct areas (a small starting shed → a warehouse → an outdoor field → an underground vault), swapping `AmbientReverb` on zone entry costs one line and adds an enormous amount of place-ness.

Caveats:

- **There is no crossfade.** Changing `AmbientReverb` is a hard switch. Change it at a doorway or during a transition, not in the middle of an open space.
- **It does not apply to `PlayLocalSound` copies** (§8.5), which is a real limitation: your UI feedback will sit outside the room's reverb. Usually this is *desirable* — UI should feel like it is in the player's head, not in the room.
- Start conservative: `NoReverb` or `Room` for most interiors, `Plain`/`City`/`Forest` for exteriors. Dramatic presets like `SewerPipe` or `Cave` are exciting for ten seconds and fatiguing for ten minutes.
- `SoundService.ReverbEnabled` exists in the API dump with `Security: None` and is **not** covered in the class reference YAML — treat it as a real but undocumented global toggle. `[UNVERIFIED]`

### 8.9 Preloading with ContentProvider

An audio asset that has not loaded does not play — it plays *later*, or not at all. Because audio timing is the thing players are most sensitive to (§4.4), unloaded sounds are worse than missing textures.

`ContentProvider:PreloadAsync(contentIdList, callback?)` "yields until all of the assets associated with the given `Instances` have loaded... For each requested asset, the callback function runs, indicating the asset's final `Enum.AssetFetchStatus`." Important documented behaviour:

- **"If any of the assets fail to load, an error message appears in the output. The method itself will not error and it will continue executing until it has processed each requested instance."** So it is safe to call on a large list, but you must use the callback to detect failures.
- `ContentProvider.RequestQueueSize` ("the number of items in the request queue that need to be downloaded") is your loading-bar denominator.
- `ContentProvider:Preload` is **deprecated** (confirmed by the `Deprecated` tag in the API dump). Use `PreloadAsync`.
- **`SurfaceAppearance` and `MaterialVariant` are not supported** by `PreloadAsync`.
- `ContentProvider.AssetFetchFailed` fires with the failing content ID — connect it and log, or you will never find out that a sound silently stopped working.

```lua
--!strict
-- Preload audio in priority tiers. Tier 1 blocks the loading screen;
-- tiers 2+ stream in the background so the player can start playing.
local ContentProvider = game:GetService("ContentProvider")

local function preloadTier(soundIds: { string }, onProgress: ((number, number) -> ())?)
    -- PreloadAsync takes Instances; build throwaway Sounds carrying the ids.
    local instances = {}
    for _, id in soundIds do
        local s = Instance.new("Sound")
        s.SoundId = id
        table.insert(instances, s)
    end

    local done, total = 0, #instances
    ContentProvider:PreloadAsync(instances, function(contentId, status)
        done += 1
        if status ~= Enum.AssetFetchStatus.Success then
            warn(("Audio preload failed: %s (%s)"):format(contentId, tostring(status)))
        end
        if onProgress then onProgress(done, total) end
    end)

    for _, s in instances do s:Destroy() end
end

-- Tier 1: everything the first 30 seconds of play can trigger.
-- Tier 2: mid-game sounds. Tier 3: rare/late-game. Prestige stingers go in 2,
-- not 3 -- a player can prestige sooner than you expect.
task.spawn(function()
    preloadTier(TIER_1)          -- blocking, behind the loading screen
    task.spawn(function() preloadTier(TIER_2) end)
    task.delay(20, function() preloadTier(TIER_3) end)
end)
```

**Also preload your VFX textures the same way** — particle textures, beam textures, UI images. Use `Sound.IsLoaded` / `Sound.Loaded` to guard playback of anything you could not preload.

---

## 9. Performance discipline

Everything in this chapter costs something. An incremental game is the worst case for VFX performance, because success means *more of everything on screen at once* — that is the genre's core fantasy. The systems below are not optional polish; without them, a successful save file becomes unplayable.

### 9.1 What actually costs money

Ranked, most expensive first, for the effects in this chapter:

1. **Full-screen overdraw.** Large transparent surfaces — particles, transparent shells, post-processing — are fill-rate bound. On mobile this is the binding constraint on nearly everything. **A single particle filling the screen costs more than 200 particles of 20 px.**
2. **Shadow-casting local lights.** See §5.1.
3. **Draw calls / instance count.** Every emitter, beam, trail, light and `BillboardGui` is a separate thing to submit.
4. **CPU: per-frame Lua.** A `RenderStepped` connection per effect instance is death by a thousand cuts. One manager loop iterating an array beats 300 connections.
5. **Instance creation/destruction.** `Instance.new` + `Parent` assignment, especially in a burst, causes measurable hitches. This is what pooling solves.
6. **Texture memory.** Mostly a mobile concern, and the reason the engine will silently disable your flipbooks (§1.6).

### 9.2 Particle budgets

`[UNVERIFIED — craft guidance, no published Roblox numbers]`. Working budgets for a mid-range target:

| Scope | Budget |
| --- | --- |
| Simultaneously *enabled* emitters in view | ≤ 40 (desktop), ≤ 15 (mobile) |
| Live particles in view | ≤ 800 (desktop), ≤ 250 (mobile) |
| Particles in a single burst | ≤ 60 |
| Screen-area coverage by additive particles | ≤ ~1.5 screens of overdraw |
| Emitters per single effect | ≤ 4 layers |

**The counterintuitive rule: make particles *smaller and brighter* rather than larger and dimmer.** A small, high-`Brightness` additive particle reads as more energetic than a large dim one and costs a fraction of the fill rate. When an effect is not reading, the instinct is to raise `Size`; the correct move is usually to raise `Brightness` and add a `PointLight`.

**Budget bursts, not rates.** An effect that emits 40 particles once is fine. The same effect triggered 30 times in a second by a held buy button is 1200 particles. Rate-limit at the *event* level (§9.6), the same way you rate-limit sound families.

### 9.3 Pooling

Never `Instance.new` a VFX object in a hot path. Pool everything with one exception.

```lua
--!strict
-- ReplicatedStorage/Client/VFXPool.luau
-- Generic pool for effect Attachments carrying pre-configured emitters.
-- Effects are authored as templates in ReplicatedStorage and cloned once.
local Debris = game:GetService("Debris")

local VFXPool = {}

local pools: { [string]: { Attachment } } = {}
local templates: { [string]: Attachment } = {}
local MAX_PER_KIND = 24

function VFXPool.registerTemplate(kind: string, template: Attachment)
    templates[kind] = template
    pools[kind] = {}
end

--- Warm the pool at load time so the first effect of each kind does not hitch.
function VFXPool.prewarm(kind: string, count: number)
    local bucket = pools[kind]
    local template = templates[kind]
    if not (bucket and template) then return end
    for _ = 1, count do
        local a = template:Clone()
        a.Parent = nil
        table.insert(bucket, a)
    end
end

function VFXPool.acquire(kind: string, worldCFrame: CFrame): Attachment?
    local bucket, template = pools[kind], templates[kind]
    if not (bucket and template) then return nil end

    local a = table.remove(bucket) or template:Clone()
    a.WorldCFrame = worldCFrame
    a.Parent = workspace.Terrain
    return a
end

function VFXPool.releaseAfter(kind: string, a: Attachment, seconds: number)
    task.delay(seconds, function()
        if not a.Parent then return end
        for _, child in a:GetChildren() do
            if child:IsA("ParticleEmitter") then
                child.Enabled = false
                child:Clear()            -- do not carry stale particles into reuse
            elseif child:IsA("Trail") then
                child.Enabled = false     -- see the Trail re-enable gotcha, section 3.4
            elseif child:IsA("Light") then
                child.Enabled = false
            end
        end
        a.Parent = nil
        local bucket = pools[kind]
        if bucket and #bucket < MAX_PER_KIND then
            table.insert(bucket, a)
        else
            a:Destroy()
        end
    end)
end

return VFXPool
```

**The exception: `Highlight`.** Pooling by disabling does not work because disabled instances still consume one of the 255 client slots. Destroy them (§7.5).

**Two pooling rules that are easy to get wrong:**

1. **`:Clear()` emitters on release.** Otherwise a reused emitter's old particles appear at the new location.
2. **Never reuse a `Trail` in the same frame you move it** — you get a streak across the world. Park, wait one frame, enable.

### 9.4 Distance culling

The most effective single optimisation, and the one most often skipped, because everything looks fine when you test standing next to it.

```lua
--!strict
-- ReplicatedStorage/Client/VFXCuller.luau
-- ONE loop for all registered effects. Never one RenderStepped per effect.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VFXCuller = {}

type Entry = {
    part: BasePart,
    emitters: { ParticleEmitter },
    lights: { Light },
    beams: { Beam },
    nearRange: number,      -- full quality inside this
    farRange: number,       -- fully off outside this
    wantEnabled: boolean,   -- gameplay state: should this be running at all?
    lastState: number,      -- 0 off, 1 reduced, 2 full
    baseRates: { number },
}

local entries: { Entry } = {}
local accumulator = 0
local INTERVAL = 0.2        -- cull at 5 Hz, not 60 Hz; distance changes slowly
local cursor = 1
local SLICE = 40            -- entries checked per tick; amortised over frames

function VFXCuller.register(entry: Entry)
    entry.lastState = -1
    entry.baseRates = {}
    for i, e in entry.emitters do
        entry.baseRates[i] = e.Rate
    end
    table.insert(entries, entry)
end

local function applyState(entry: Entry, state: number)
    if entry.lastState == state then return end
    entry.lastState = state

    for i, e in entry.emitters do
        if state == 0 then
            e.Enabled = false
            e:Clear()
        elseif state == 1 then
            e.Enabled = true
            e.Rate = entry.baseRates[i] * 0.35      -- reduced, not off
        else
            e.Enabled = true
            e.Rate = entry.baseRates[i]
        end
    end
    for _, l in entry.lights do
        l.Enabled = (state == 2)                     -- lights are near-only
    end
    for _, b in entry.beams do
        b.Enabled = (state > 0)
    end
end

RunService.Heartbeat:Connect(function(dt)
    accumulator += dt
    if accumulator < INTERVAL then return end
    accumulator = 0

    local camera = Workspace.CurrentCamera
    if not camera then return end
    local camPos = camera.CFrame.Position

    local n = #entries
    if n == 0 then return end

    for _ = 1, math.min(SLICE, n) do
        local entry = entries[cursor]
        cursor = (cursor % n) + 1
        if not entry.part.Parent then
            continue
        end
        if not entry.wantEnabled then
            applyState(entry, 0)
            continue
        end
        local d = (entry.part.Position - camPos).Magnitude
        local state = if d <= entry.nearRange then 2
            elseif d <= entry.farRange then 1
            else 0
        applyState(entry, state)
    end
end)

return VFXCuller
```

Design notes worth copying:

- **Cull at 5 Hz, not every frame.** Distance does not change meaningfully in 16 ms.
- **Amortise over frames** (`SLICE`). With 2000 registered effects, checking all of them even at 5 Hz produces a periodic spike.
- **Three states, not two.** A hard on/off boundary produces visible popping as the player walks. The middle "reduced rate" band hides it.
- **Lights are near-only.** They are the most expensive item and the least visible at range.
- **Hysteresis.** `nearRange` and `farRange` are naturally separated, which prevents an effect from flickering between states when the player stands exactly on a boundary. If you use a single threshold, add ±10% hysteresis manually.

### 9.5 Quality-level degradation

`UserSettings():GetService("UserGameSettings").SavedQualityLevel` is readable from a `LocalScript` (`Security: {Read: None, Write: None}` per the API dump) and returns an `Enum.SavedQualitySetting`: `Automatic`, or `QualityLevel1` … `QualityLevel10`.

**The catch: `Automatic` is the default**, and it tells you nothing about the level actually in use. `UserGameSettings.GraphicsQualityLevel` — the resolved value — is `RobloxScriptSecurity` in the API dump and therefore **not** readable from your code. So you need a fallback: measure frame time.

```lua
--!strict
-- ReplicatedStorage/Client/QualityTier.luau
-- Resolves a 1-3 quality tier from the player's saved setting, falling back to
-- a measured frame-time estimate when the setting is Automatic.
local UserSettings = UserSettings()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local QualityTier = {}

local settings = UserSettings:GetService("UserGameSettings")

-- 1 = low (mobile/potato), 2 = medium, 3 = high.
local tier = 2
local listeners: { (number) -> () } = {}

local function fromSavedLevel(): number?
    local saved = settings.SavedQualityLevel
    if saved == Enum.SavedQualitySetting.Automatic then
        return nil
    end
    local n = tonumber(tostring(saved.Name):match("%d+"))
    if not n then return nil end
    -- Shadows are off below level 4 (chapter 23), which is a natural boundary.
    if n <= 3 then return 1 elseif n <= 6 then return 2 else return 3 end
end

local function setTier(t: number)
    if t == tier then return end
    tier = t
    for _, fn in listeners do
        task.spawn(fn, t)
    end
end

function QualityTier.get(): number
    return tier
end

function QualityTier.onChanged(fn: (number) -> ())
    table.insert(listeners, fn)
    task.spawn(fn, tier)
end

-- Initial guess.
do
    local saved = fromSavedLevel()
    if saved then
        tier = saved
    elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        tier = 1                                  -- touch-only: assume mobile
    else
        tier = 2
    end
end

settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
    local saved = fromSavedLevel()
    if saved then setTier(saved) end
end)

-- Automatic fallback: measure a median-ish frame time over a rolling window
-- and demote (never promote aggressively) so a struggling client recovers.
task.spawn(function()
    local samples = table.create(120)
    while true do
        if fromSavedLevel() ~= nil then
            task.wait(5)
            continue
        end
        table.clear(samples)
        for _ = 1, 120 do
            table.insert(samples, RunService.RenderStepped:Wait())
        end
        table.sort(samples)
        local p75 = samples[90]                   -- 75th percentile frame time
        if p75 > 1 / 32 then
            setTier(1)
        elseif p75 > 1 / 50 then
            setTier(math.min(tier, 2))
        else
            setTier(math.min(tier + 1, 3))        -- promote at most one step
        end
        task.wait(10)
    end
end)

return QualityTier
```

**The degradation ladder.** Cut in this order — each row removes roughly the cost of everything below it:

| Tier | Particles | Lights | Post-FX | Beams/Trails | Highlights |
| --- | --- | --- | --- | --- | --- |
| **3 — High** | Full budget, flipbooks on | Full, shadows on hero lights | Full stack | Full `Segments`, both layers | Budget 32 |
| **2 — Medium** | 60% rates, burst counts × 0.6, flipbooks on | No shadows, `Range` × 0.75, cull nearer | Bloom (`Size` ≤ 16) + ColorCorrection + modal blur | `Segments` capped at 8, core layer only on hero effects | Budget 16 |
| **1 — Low** | 30% rates, burst × 0.35, **flipbooks off**, ambient emitters off entirely | Event flashes only, no ambient/flicker lights | ColorCorrection only | `Segments` = 1–4, single layer, no scrolling on non-hero beams | Budget 4 |

**Never degrade these, at any tier:**

- **Audio.** It is cheap and carries the feel. A low-end player should get the full soundscape.
- **The impact stack's *timing*** (§4.4). Fewer particles is fine; a mistimed stack is not.
- **Button press response** (§4.7). Input responsiveness is not a graphics setting.
- **Screen shake** — it costs one CFrame multiply.

That last point is worth stating plainly: **the techniques in §4 are nearly free.** Hit stop, easing, springs, staggered timing, pitch variance and layered audio cost essentially no GPU. A low-end player can have 90% of your game's *feel* with 30% of its *pixels*. Build accordingly.

### 9.6 Event rate limiting

An incremental game generates events at rates no VFX system can honour. A held buy button, an autoclicker, 10,000 units producing simultaneously — these must be collapsed *before* they reach the effect layer.

```lua
--!strict
-- Coalesce a storm of small events into periodic aggregate effects.
-- This is the difference between a playable late game and a slideshow.
local Coalescer = {}
Coalescer.__index = Coalescer

function Coalescer.new(windowMs: number, flush: (count: number, magnitude: number) -> ())
    return setmetatable({
        window = windowMs / 1000,
        flush = flush,
        count = 0,
        magnitude = 0,
        scheduled = false,
    }, Coalescer)
end

function Coalescer:push(magnitude: number)
    self.count += 1
    self.magnitude = math.max(self.magnitude, magnitude)   -- peak, not sum
    if self.scheduled then return end
    self.scheduled = true
    task.delay(self.window, function()
        local c, m = self.count, self.magnitude
        self.count, self.magnitude, self.scheduled = 0, 0, false
        -- Scale the effect by log(count) so 1000 events is bigger than 10,
        -- but not 100x bigger.
        self.flush(c, math.min(1, m + math.log10(1 + c) * 0.15))
    end)
end

return Coalescer
```

Windows: 60–100 ms for purchases, 150–250 ms for passive production ticks, 500 ms for background accrual. Use **peak** magnitude rather than sum, and scale the visual by `log(count)` — this is the same perceptual-compression logic as the log-space counter in §4.7.

### 9.7 Mobile specifics

- **Fill rate is the binding constraint.** Cut particle *size* before particle *count*.
- **Touch has no hover.** Gate hover states and hover sounds on `UserInputService.TouchEnabled` (§4.7).
- **Screen real estate is scarce**, so world-space effects compete with UI. Prefer effects near the centre and away from thumb zones.
- **Flipbooks may be auto-disabled by the engine on low-memory devices** (§1.6). Design frame 0 to stand alone.
- **Battery and thermals.** A game that pegs the GPU throttles within minutes, so the *sustained* frame rate matters more than the peak. Ambient/idle effects — the ones running constantly — are where you should be most aggressive, not the rare dramatic ones.

---

## The make-it-feel-expensive checklist

Ordered by impact per hour of work. Work top to bottom; do not skip ahead. Items 1–8 are achievable in a day and will account for most of the perceived difference between a prototype and a shipped game.

1. **Pitch- and volume-randomise every repeatable sound.** ±5% pitch on UI, ±10–15% on world sounds, ±12% volume. One line per sound. Nothing else in this list has a comparable ratio of perceived quality to effort. (§8.3)
2. **Fix every naive per-frame lerp.** Replace `v += (target - v) * 0.1` with `1 - math.exp(-k*dt)` or `TweenService:SmoothDamp`. Your game currently feels different on different hardware. (§4.6.1)
3. **Make buttons respond in under 80 ms, with an overshoot on release.** Press → 0.95 in 60 ms `Quad Out`; release → 1.06 → 1.00 in 180 ms `Back Out`. (§4.7)
4. **Set `LightEmission` and `LightInfluence` deliberately on every emitter.** Emissive things: `LightEmission = 1, LightInfluence = 0`. Physical things: `LightEmission = 0, LightInfluence = 1`. Set both *explicitly*, because the default differs between Studio insertion and `Instance.new`. (§1.1)
5. **Build the `SoundGroup` mixer tree and route everything through it.** Master → Music/SFX/Voice → sub-buses. Ducking, player volume settings and mix balance all become one-line changes. (§8.1)
6. **Stagger the impact stack.** Sound at t=0, flash at t=0, particles at +16 ms, popup at +80 ms, counter at +150 ms. Do not fire everything on the same frame. (§4.4)
7. **Add trauma-based screen shake with `trauma²` decay and Perlin-noise drive, including rotation.** Add an intensity setting. Never exceed 0.5 trauma outside of prestige-tier events. (§4.1)
8. **Layer every important sound into transient + body + tail**, scaled by event magnitude, with the body pitch-shifted down for bigger events. Three files cover a whole intensity ladder. (§8.4)
9. **Make counters spring toward their target in log space**, and scale-punch the label on significant changes. In an incremental game the number *is* the game. (§4.7)
10. **Add hit stop to your three or four biggest moments.** 180 ms at scale 0 for prestige; 70–90 ms at 0.05–0.1 for milestones. Ease *out* of the stop over ~40 ms. (§4.2)
11. **Layer every hero effect into 3–4 emitters separated by `ZOffset`**: back smoke (lit, alpha), core flash (additive, 2 frames), body (additive, flipbook), sparks (`VelocityParallel`, tiny, very bright). (§1.5)
12. **Pair every emissive effect with a `PointLight` flash.** 80–140 ms, `Quart Out` decay, `Shadows = false`. The environment reacting is what makes an effect feel like it happened *in the world*. (§5.2)
13. **Tune bloom properly: `Threshold` high (0.85–0.95), `Intensity` to taste, `Size` 12–24.** If grey walls glow, your threshold is too low. Raise object brightness, not bloom sensitivity. (§6.1)
14. **Use `EasingStyle.Back Out` for UI entrances**, `In` for exits, `InOut` for camera moves. Stop using `Linear` for anything with mass. (§4.5)
15. **Set `MinLength` on every `Trail`** (0.15–0.5) and `MaxLength` as a budget. Fixes the crumpled-knot artefact on near-stationary objects. (§3.2)
16. **Add scrolling `Beam` links between related objects**, with two layers at different `TextureSpeed` for parallax, and transparency fading at both ends. Scale `TextureSpeed` with throughput so the player reads their economy's rate. (§2.3)
17. **Add `Atmosphere` with non-zero `Haze`** and tune `Offset` for aerial perspective. Remember `Glare` needs `Haze`, and `Decay` needs both. (§5.5)
18. **Add post-processing transients for global events only** — bloom punch on milestones, desaturate-and-recover on loss, modal blur on panels. Always return to a captured baseline. (§6.2)
19. **Preload tier-1 audio and VFX textures behind the loading screen**, tier 2 in the background. Connect `ContentProvider.AssetFetchFailed` and log. (§8.9)
20. **Pool every effect object and prewarm the pools.** Never `Instance.new` in a hot path. `:Clear()` emitters on release. Destroy `Highlight`s rather than disabling them. (§9.3, §7.5)
21. **Coalesce high-frequency events** before they reach the effect layer, with a 60–250 ms window, peak magnitude and `log(count)` scaling. (§9.6)
22. **Implement distance culling in one manager loop** at 5 Hz, amortised, with three states and hysteresis. (§9.4)
23. **Implement the quality-tier ladder**, with a measured-frame-time fallback for `Automatic`. Degrade particles, lights and post-FX — never audio, timing or input response. (§9.5)
24. **Add adaptive music as synchronised stems**, crossfading over 2–4 s by progression tier, with key-matched stingers ducked over the music. (§8.7)
25. **Set `EmitterSize` per sound source size** and `AmbientReverb` per zone. Different-sized sounds is what makes a soundscape feel like a place. (§8.2, §8.8)
26. **Add anticipation to telegraphed actions** (60–120 ms, 10–20% counter-movement) and volume-preserving squash-and-stretch on impacts (40–70 ms in, 120–200 ms out). (§4.3)
27. **Add `ViewportFrame` previews to shop and upgrade cards**, rendered lazily. (§7.4)
28. **Audit for the cheap-texture tells**: hard alpha edges, no transparent padding, residual alpha above 4/255, black RGB in transparent regions, coloured textures that should have been white-and-tinted. (§1.9)

---

## Sources

All engine claims are sourced from the following. Fetched 2026-09-17.

**Roblox `creator-docs` engine reference (YAML)** — `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/…`

- Classes: `ParticleEmitter`, `Beam`, `Trail`, `Attachment`, `Highlight`, `Sound`, `SoundService`, `SoundGroup`, `TweenService`, `Light`, `PointLight`, `SpotLight`, `SurfaceLight`, `Explosion`, `ContentProvider`, `BloomEffect`, `BlurEffect`, `ColorCorrectionEffect`, `DepthOfFieldEffect`, `SunRaysEffect`, `Atmosphere`, `Lighting`
- Enums: `ParticleOrientation`, `ParticleFlipbookLayout`, `ParticleFlipbookMode`, `ParticleEmitterShape`, `ParticleEmitterShapeStyle`, `ParticleEmitterShapeInOut`, `EasingStyle`, `EasingDirection`, `TextureMode`, `RollOffMode`, `ReverbType`, `NormalId`, `PlaybackState`
- Datatypes: `TweenInfo`, `NumberSequence`, `NumberRange`, `ColorSequence`, `Random`, `CFrame`
- Libraries: `math` (for `math.noise`, documented as Perlin noise in the range −1 to 1)

**Roblox `creator-docs` guides (Markdown)** — `https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/…`

- `effects/particle-emitters.md` — flipbook authoring rules (exact-multiple texture sizing, inter-frame spacing, memory-driven auto-disable, texture reuse), shape examples
- `effects/beams.md` — the cubic Bézier control-point definition (P0–P3), `TextureMode`/`TextureLength` semantics, `FaceCamera`
- `effects/trails.md` — trail construction, lifetime, texture length/mode, facing
- `effects/light-sources.md` — `PointLight`/`SpotLight`/`SurfaceLight` roles and shared properties

**Live engine reflection dump** — `https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json`

Used to confirm security levels and catch undocumented members. Specifically confirmed:

- `TweenService:SmoothDamp` — `Security: None`, `ThreadSafety: Safe`, `SimulationAccess: true`; signature `(current: Variant, target: Variant, velocity: Variant, smoothTime: float, maxSpeed: float?, dt: float?) → (Variant, Variant)`
- `SoundService:GetMixerTime` — `Security: None`
- `ParticleEmitter.VelocitySpread` — tagged `Deprecated`, `NotReplicated`
- `ParticleEmitter:FastForward` — `RobloxScriptSecurity`; exists but is not usable from game code
- `ContentProvider:Preload` — tagged `Deprecated`; `PreloadAsync` tagged `Yields`
- `Highlight.LineThickness` and `Highlight.ReservedId` — `RobloxScriptSecurity` + `Hidden`; not usable
- `UserGameSettings.SavedQualityLevel` — readable (`Security: None`); `UserGameSettings.GraphicsQualityLevel` — `RobloxScriptSecurity`, **not** readable from game code
- `SoundService.ReverbEnabled`, `OcclusionEnabled`, `DiffractionEnabled` — `Security: None` but absent from the class reference YAML; undocumented public members
- `Enum.SavedQualitySetting` — `Automatic`, `QualityLevel1` … `QualityLevel10`

**Sibling chapters in this corpus** (facts folded in rather than rediscovered):

- Beam cubic-Bézier control-point derivation and the orientation dependency
- `Highlight` 255-client-instance cap, with disabled instances still consuming slots
- `TweenService:SmoothDamp` availability and semantics
- Frame-rate-independent smoothing via `1 - math.exp(-k*dt)`
- `EnvironmentDiffuseScale` / `EnvironmentSpecularScale` defaulting to 0
- Local light `Range` clamped to 120 studs; shadows disabled below graphics quality level 4

Cross-references: chapter 20 & 40 (`EditableImage`), 21 & 41 (`EditableMesh`), 22 (Luau performance), 23 (rendering, lighting, materials), 43 (3D math), 61 (incremental architecture), 63 (incremental UI).

**Community, second-hand** — obtained via web-search summaries only; DevForum itself was not reachable:

- The greyscale-no-alpha-texture-with-`LightEmission = 1` authoring trick. `[COMMUNITY, SECOND-HAND]`
- Attribution of the trauma-based screen-shake model to Squirrel Eiserloh's GDC talk "Math for Game Programmers: Juicing Your Cameras With Math" (2016). The mathematics presented in §4.1 is self-contained and does not depend on this attribution. `[COMMUNITY, SECOND-HAND]`
- Search entry points: Roblox Creator Hub `ParticleEmitter` reference page, `robloxapi.github.io` unofficial reference, DevForum threads on particle performance and `LightInfluence`. Note that `create.roblox.com`, `devforum.roblox.com`, `luau.org` and `api.github.com` return 403 to this toolchain and were not fetched directly.

**Explicitly unverified in this chapter** (marked inline as `[UNVERIFIED]`):

- All numeric *craft* recommendations — trauma budgets, hit-stop durations, easing durations, particle budgets, light counts, sound distance tables, `smoothTime` calibrations. These are the author's working values, not engine specifications.
- Whether `ParticleEmitter:Emit()` fires on an emitter with `Enabled = false`. Not documented; use `Rate = 0` with `Enabled = true` instead.
- Premultiplied-alpha / bilinear-filtering halo behaviour on Roblox textures — standard real-time-graphics practice, but Roblox does not document its filtering pipeline.
- Whether creating/destroying `PostEffect` instances triggers a shader rebuild.
- The exact `CFrame.Angles(0, -90°, 0)` correction for aiming an `Attachment`'s +X axis in §2.1 — derived from `CFrame.lookAt`'s `-Z`-forward convention; verify the sign in-engine.
- `SoundService:GetMixerTime()` as a scheduling clock for *legacy* `Sound` playback — the reference frames it around the advanced audio system's `AudioPlayer:Play(atTime)`.
- Roblox does not publish per-instance cost figures for lights, emitters or overdraw; the budgets in §9 are conservative working limits.
