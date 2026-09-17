# Presentation Prompt — Shark Incremental: UI, HUD, UX, GFX, VFX, SFX

> Send with `HANDOUT.md`. This is the **entire presentation layer** — everything
> the player sees, hears and touches. Quality bar: hero-grade. An incremental
> game's UI *is* the game; there is no 3D spectacle to hide behind.

---

## Mission

Build Shark Incremental's complete presentation layer in Roblox — screens, HUD,
interaction feel, generated art, effects and sound — using the technique
catalogue in `docs/research/`, not Roblox default components with rounded
corners.

**Read first:** the handout, then **63** (incremental-game UI — number
formatting, virtualized lists, the screens, mobile), **40** (EditableImage
cookbook — this is your art department), **23** (rendering, lighting, materials,
and the shader-substitutes table), **45** (VFX, audio, game feel), **43**
(springs, easing, frame-rate-independent damping), **60** (big-number
formatting and notation).

---

## GFX — generate the art, don't hand-author it

The image cookbook is the point. For each technique: **use it, or write one
line saying why it doesn't apply.** No silent skipping.

- **Procedural icon generation** — generate the whole icon set (upgrades,
  currencies, achievements, zones) from parameters rather than authoring
  hundreds of images by hand. This is the single biggest art-effort win.
- **Atlas consolidation** — pack generated icons into one image addressed with
  `ImageRectOffset`/`ImageRectSize`. This simultaneously defeats the memory
  budget, the one-update-per-frame limit and draw-call overhead. Non-optional.
- **Masked recolouring** — one icon, many rarity/tier variants from a mask.
- **Procedural frames and panels** — 9-slice panel textures generated with
  noise and gradients, sliced with `SliceCenter`/`SliceScale`.
- **Backgrounds** — generated gradients, caustics, depth washes per zone.
  Animate subtly; a static background reads as cheap.
- **Charts and graphs drawn to an image** — production history, progression
  curves, prestige projections. Drawing to a canvas beats assembling hundreds
  of Frames, and it is the correct use of the pixel budget.
- **Progress rings and radial meters** — drawn, not faked with rotated frames.
- **Image filters** — blur (use the integral-image O(1) box blur), threshold,
  posterize, LUT colour grading per zone/tier so tiers read as distinct.
- **Palette quantization and dithering** — if any surface takes a stylised
  treatment, do it deliberately with ordered or blue-noise dither.
- **Animated textures** — scrolling, morphing, flipbooks for living UI surfaces.
- **Text rendered into images** — Roblox exposes no font rasteriser. If you need
  baked text, use a bitmap-font or SDF atlas. Know this before planning one.
- **Full-screen overlays** — vignettes, tier-up washes, screen flashes. You
  **cannot read the rendered frame**, so these are overlays, not post.

**Route every asset explicitly.** Plugin-time generated + uploaded, or runtime
generated? Most UI art is static — generate it in a Studio plugin at edit time,
upload, ship plain asset IDs. That clears the verification gate, the memory
budget, the replication problem, the per-frame throttle and mobile risk at once.
Spend runtime generation only on what must change live: charts, the reveal
minimap, per-player variation. Produce the table.

---

## UI and HUD

- **Framework: Vide.** Fine-grained reactivity fits "hundreds of independent
  numbers updating at ~15 Hz" — one changed source touches exactly the effects
  reading it, with no component re-execution or tree diff. If the studio already
  runs React-Lua, keep it for structure and route the hot numeric path through
  imperative refs.
- **Number formatting is the genre's signature.** Standard suffixes, scientific,
  engineering, letter (`aa/ab/ac`), hyper-E, arrow. **AlyaNum's own formatter is
  process-global** (`changeSuffixes`, `changeDecimalPoints` write file-local
  upvalues), so a per-player notation setting — the most-requested feature in
  the genre — **cannot** be built on it. Write your own formatter. AlyaNum also
  ships no engineering and no letter notation. (Quintillion is `Qt`, not `Qi`.)
- **Quantize → compare → skip.** This is the one optimisation shape that repeats
  everywhere: text, colours, bar sizes, row rebinds. Update text at 10–20 Hz,
  never per tick. Assigning `.Text` is not free. Cache formatted strings; a
  number that hasn't visibly changed must not touch the UI.
- **Virtualize long lists.** Recycle row objects; only instantiate what's
  visible. Use `ScrollingFrame.AbsoluteWindowSize` (AbsoluteSize minus scrollbar
  gutters) as the viewport — `AbsoluteSize` under-counts and leaves a one-row
  gap. `GetScrollVelocity()` is the clean way to keep rebinding through touch
  momentum.
- **`CanvasGroup` is ruled out for lists** — it consumes extra texture memory,
  is capped by the client's QualityLevel, **renders as a blank texture past the
  cap**, and is documented as "recommended with static sizes". A mobile failure
  mode.
- **The GuiEffect trap, straight from Roblox's own MicroProfiler tag table:**
  *"If there are too many Process GuiEffect labels, consider reducing the use of
  `UIGradient` and `UICorner` on text labels."* For a genre with hundreds of
  TextLabels this is the most actionable published performance fact that exists.
  Bake gradients and corners into generated images instead.
- Note `gui count` counts **LayerCollectors**, not GuiObjects — splitting the UI
  across twenty ScreenGuis has a measurable cost.

**Screens to build:** currency/rate HUD bar · generator and upgrade lists with
bulk-buy (x1/x10/x100/Max) and affordability states · prestige screen with
projected gains · achievements · stats · settings (notation, autosave, reduced
effects) · offline welcome-back modal · tooltips with follow-cursor positioning
· notification/toast queue.

**Bulk-buy needs the closed form** for "how many can I afford" on a geometric
cost curve — looping is far too slow at scale.

---

## UX and feel

- **Springs over tweens** for anything that should read as alive.
  `TweenService:SmoothDamp` is a real critically-damped spring and most existing
  Roblox material predates it. Frame-rate-independent smoothing is
  `1 - math.exp(-k*dt)`; naive per-frame lerp is a bug.
- **The purchase loop is the core interaction.** A player buys fifty things a
  minute. Make it feel good *and* cheap: tween + sound + particle + number
  popup, pooled, with the timing tuned in milliseconds.
- **Hold-to-buy-repeatedly**, clear disabled/affordable states, and instant
  response on press — never wait for a server round-trip to show feedback.
- **Log-scale progress bars.** A linear bar is useless when the next goal is
  1e50. Show time-to-next-milestone.
- **Onboarding**: the first sixty seconds decide retention. First purchase
  should happen within seconds.
- **Offline welcome-back** should feel like a reward, not a receipt.
- **Mobile is the default platform**, not an afterthought. Thumb reachability,
  minimum touch targets, one-handed operation, dense text that stays legible.

---

## VFX and SFX

- **Particles**: `LightEmission` vs `LightInfluence` is the biggest quality
  lever — understand the difference before tuning anything. Use flipbooks. Use
  emitter shapes. Burst with `:Emit(n)` for events, not continuous Rate.
- **Beam** as a general textured-quad primitive — its curve is a cubic Bézier
  driven by attachment *orientation*, not just position. Scrolling textures via
  TextureSpeed for energy effects.
- **Trauma-based screen shake** (decay by trauma², noise-driven). Random jitter
  reads cheap.
- **Hit stop** on big events — a few frames of pause sells impact.
- **`Highlight` caps at 255 client instances** and disabled ones still hold a
  slot. Delete, don't disable.
- **Animate post-processing as feedback** — a ColorCorrection pulse on prestige,
  a bloom swell on a milestone. Tune bloom to avoid the blown-out amateur look.
- **Audio is half of feel.** Layer sounds for one event. **Randomise
  `PlaybackSpeed` on repeated sounds** — the easiest quality win available, and
  its absence is why most Roblox games sound cheap. Pool sounds, duck under
  stingers, preload with ContentProvider, use SoundGroups for mixing.
- **Pool everything.** At this purchase rate, instantiating effects per event
  will kill the frame.
- **Impact-stack timing** — stagger, don't fire simultaneously. Audio at t=0,
  particles at +16 ms, number popup at +80 ms, counter at +150 ms. The popup is
  the most commonly mistimed element, and the staggering is where the quality
  actually lives.
- **`LightInfluence` has an insertion-default trap**: it defaults to **1** when
  inserted via Studio and **0** via `Instance.new()`. Artist-authored and
  code-authored emitters will silently differ. Set it explicitly, always.
- **Log-space spring counters.** A linear lerp between 1e6 and 1e9 is visually
  invisible — the number appears to jump. Animate counters in log space. This is
  the genre-specific feel win and most implementations get it wrong.
- **Deprecated / unusable, confirmed:** `ParticleEmitter.VelocitySpread` and
  `ContentProvider:Preload` are deprecated; `ParticleEmitter:FastForward`,
  `Highlight.LineThickness` and `Highlight.ReservedId` are `RobloxScriptSecurity`
  and unavailable to you.
- **Decide the audio architecture up front.** Legacy `Sound` and the advanced
  `AudioPlayer`/`AudioEmitter` system are separate, and several `SoundService`
  properties explicitly do not affect the advanced one. Mixing them means your
  global mix tuning applies to only half your sounds. Pick one.

---

## Hard constraints

1. **One displayed `EditableImage` updates per frame, globally.** N live
   canvases refresh at 60/N fps. Atlas aggressively.
2. **1024² max, not resizable.** Per-pixel realtime work tops out ~100×100 to
   256×256; 512² is the outer limit (~9.7 ms for a full repaint). Blitting
   reaches 1024².
3. **~8 live editable objects**, likely a ~32 MB shared budget. Smaller canvases
   may buy more — verify early.
4. **Editable assets are client-side** — `Content` holding an Object does not
   replicate.
5. **Mutators are `Unsafe` for parallel Luau** — compute parallel into a
   `buffer`, commit serial.
6. **Native codegen is server-only** — client generation runs interpreted, on
   phones.
7. **Three gates, three failures**: verification toggle (published only), asset
   permissions **throw**, memory budget **returns `nil`**. No pre-check exists.
   `pcall` + nil-check + degraded fallback at every creation site.
8. **Beam/Trail/ParticleEmitter/Sky image sinks may silently no-op** — assignment
   succeeds but support is undocumented. Verify each in-engine.
9. **Runtime PBR by construction** (`CreateSurfaceAppearanceAsync`), never by
   assignment into an existing SurfaceAppearance.

---

## Verification

- **Blind side-by-side against a real reference.** Screenshot a screen, and a
  screen from a genuinely premium game, strip labels, have a critic agent that
  did not build it pick the better one and say why. **Do not score against a
  rubric** — rubric scores inflate and stop discriminating by round three.
  Iterate until yours wins, not until a round counter expires.
- **Profile on a real low-end phone.** Studio lies about performance.
- **You cannot read the client's graphics quality.**
  `UserGameSettings.GraphicsQualityLevel` is `RobloxScriptSecurity`, and the one
  property you *can* read, `SavedQualityLevel`, returns `Automatic` by default
  and tells you nothing. So "degrade by quality tier" is not implementable as
  written anywhere — build the fallback on **measured frame time** instead, and
  do not let an agent claim a quality-tier check that cannot exist.
- **Check the MicroProfiler `Process GuiEffect` labels specifically.**
- **Verify every silent-failure surface** — did that sink accept the image, or
  no-op?
- Sixty-second cold-start test with someone who has never seen the game.

## How to work

Stagger agents in batches of ~5. Write files incrementally. Commit per batch.
Pair every builder with a critic that did not write the work; seed a planted
defect occasionally to prove the critic can actually fail something.

**First reply: don't start building.** Confirm what you read, propose the
screen inventory and the asset-routing table, name which catalogue techniques
map to which screens, and flag anything in the constraints you think is wrong.
