# Roblox 2D UI technology and UI VFX: knowledge base (state as of September 2026)

This is part of the Milestone Tree NG+ "fat library" on what Roblox can do. The topic is **2D UI technology and UI
VFX**: every GUI container, every visual modifier, motion, compositing tricks, input feel, performance, and how the
best-looking Roblox UIs are built. It ends with concrete, costed opportunities for our cosmic neon incremental
(painted parallax realm home screen, ornate relic-style panels).

**How claims are tagged** (the same scheme as `audio.md`)

| Tag | Meaning |
|---|---|
| **[V]** | Checked against the engine type dump (`scratchpad/tools/globalTypes.d.luau`) **and** an official doc or Roblox staff announcement |
| **[T]** | Present in the type dump but undocumented, hidden, or reported as not usable by developers |
| **[BETA]** | Announced, but Studio-only or opt-in. **It will not work in published games yet** |
| **[C]** | Community-reported (DevForum), not confirmed by Roblox docs or staff |
| **[U]** | Unverified. This is my inference or design advice; test it in Studio before relying on it |

"Staff" means a Roblox employee posting in an official DevForum announcement thread. The sources are listed at the
end.

---

## 0. The facts that matter most

1. **Upgraded UIGradient is still in Studio Beta.** That covers `Type = Radial / Conical`, `TileMode` and `Scale`,
   announced 2026-09-02. Staff say: "you can't publish live games with new UIGradient capabilities." Studio betas
   usually last at least a month, so expect a client release in Oct 2026 or later. The members are already in the
   API dump, so a `pcall` probe (as in our `Theme.detect`) **can pass even when live clients will not render
   them**. We need a manual kill switch for these features, not a probe alone. [V][BETA]
2. **The radial gradient is a circle with a fixed 1:1 aspect. Its radius is `(w + h) / 4`** (staff, jaydubs808). On
   a square frame that is the inscribed circle. Outside it, `TileMode = Clamp` paints the **last keypoint's**
   color and transparency out to the corners. If the last keypoint is not fully transparent, the frame's square
   silhouette stays visible, which reads as "the radial renders as a square". To end the ramp exactly at the
   corners of a `w×h` frame, set `Scale = 2·sqrt(w² + h²)/(w + h)` (1.414 for a square). Elliptical radials do
   not exist. Staff are "looking into adding an elliptical mode". See section 3.1. [V][BETA]
3. **These are live now:** UIShadow (drop shadows and colored glows on shapes, full release 2026-06-23), per-corner
   UICorner, and UIStroke v2 (inner/center/outer position, scaled thickness, several strokes per object, ZIndex;
   2025-12-04). Staff budgets: **≤ 100 UIShadows**, **< 300 UIStrokes** and **< 1000 UIGradients** on screen.
   UIShadow does **not** shadow text or image alpha. It shadows the rectangle (plus UICorner). [V]
4. **There is no blend mode anywhere in GUI.** Every GuiObject composites with plain alpha-over. The only real
   additive blending on Roblox is in 3D: `ParticleEmitter`/`Beam`/`Trail.LightEmission = 1`, plus `BloomEffect`.
   ScreenGui is drawn **after** post-processing, so bloom, DOF, blur and color grading never touch it. SurfaceGui
   and BillboardGui (with `AlwaysOnTop = false`) are drawn in the 3D pass and **do** get bloom and DOF. So "UI
   that actually glows" means UI in 3D. [V for classes; the render-order behavior is C, but well established]
5. **Any change to any descendant invalidates the whole LayerCollector's cached geometry.** That means one tweening
   sparkle forces a re-tessellation of every static card in the same ScreenGui. Staff advice: split mostly-static
   and mostly-dynamic UI into separate ScreenGuis. Profile `GuiLayerCollector::render2dContext`. [V]
6. **Draw calls batch only across consecutive siblings** of the same kind and texture, in tree-insertion order.
   With alternating parenting, one repro went from 22 to 288 draw calls. Staff confirmed this is by design for
   backward compatibility. Parent atlas sprites contiguously. [V]
7. **CanvasGroup renders its subtree to one offscreen texture of `AbsoluteSize × DPI`.** Its content is clipped and
   can be masked by a UIGradient on the group (a transparency mask) and a UICorner (rounded clip). But it costs
   `w·h·4` bytes. It goes blurry at graphics quality ≤ 3 or under memory pressure, and past the cap it **renders
   blank**. An invisible CanvasGroup still holds its texture. Use it for transitions, not permanent chrome. [V][C]
8. **A ViewportFrame re-renders only when its content or camera changes.** It has no shadows and no
   post-processing. Particles, beams and trails do not render in it. Neon and Glass render at lowest quality. It
   supports a Sky cubemap for reflections. A WorldModel is needed for animation and physics. A 1024² cap is
   community-reported. [V][C]
9. **Styling Transitions (full release 2026-07-27)** give engine-native, per-property tweened hover, press and
   selection states from StyleSheets. They cost less than Lua tweens and need no connections. [V]
10. **Rotated clipping works now.** `StarterGui.ClipsDescendantsSupportsRotation` became enabled by default on
    2026-09-24, and the property will be removed in Nov 2026. Rotated children and Path2D are clipped by
    non-rotated parents. Rotated parents still need a CanvasGroup, and rounded (UICorner) clipping still needs a
    CanvasGroup. The property is not in our type dump. [V][T]
11. **Images:** GUI images are effectively **1024×1024 max** (the Jan 2026 "4K textures" launch lists only
    MeshPart, SurfaceAppearance, Texture, Decal and MaterialVariant). On low-memory mobile devices the engine
    **drops mip levels**, so UI art goes blurrier (staff: "no specific work planned"). Texture streaming covers 3D
    only. "2D UI textures, SurfaceGUI textures" are "coming next". [V][C]

---

## 1. Status board: UI features added in 2024–2026

| Feature | In the API dump | Status on 2026-09-25 | Date | Notes |
|---|---|---|---|---|
| `UIShadow` (BlurRadius, Color, Offset, Spread, Transparency, ZIndex<0, Enabled) | yes | **Live** | full release 2026-06-23 | Shapes only; ≤ 100 on screen; not on Path2D; "faster than 9-sliced ImageLabels" |
| `UIShadow.Inset`, `.Mode` (`ApplyShadowMode.Shape/Text`), `.ShowBehindParent` | yes | **[T]** undocumented | — | Docs: "no text shadow support and no inset shadow support". Staff: text shadows "would launch later"; inset is "on the roadmap" |
| `UICorner.TopLeftRadius`/`TopRightRadius`/`BottomLeftRadius`/`BottomRightRadius` | yes | **Live** | 2026-06-23 | `CornerRadius` now sets all four. Setting both kinds gives "unexpected results" |
| UIStroke v2: `BorderStrokePosition`, `StrokeSizingMode`, `BorderOffset`, `ZIndex`, several strokes | yes | **Live** | 2025-12-04 | < 300 on screen |
| UIGradient `Type` Radial/Conical, `TileMode`, `Scale` | yes | **[BETA] Studio only** | 2026-09-02 | Cannot publish. Supports Path2D |
| Rotated-element and Path2D clipping (`ClipsDescendantsSupportsRotation`) | **no** | Default ON since 2026-09-24; property removed Nov 2026 | opt-in 2026-07 | Parent must be unrotated; no UICorner clip |
| UI Styling (StyleSheet/StyleRule/StyleLink/StyleDerive/StyleQuery, tokens, themes) | yes | **Live** | 2026-01-20 | Several UIStrokes per object cannot be styled separately yet (use names or tags) |
| Styling Transitions (`StyleRule:SetPropertyTransition(s)`) | yes | **Live** | 2026-07-27 | Fire only on style-driven changes (tag or GuiState) |
| Haptics: `HapticEffect`, `GuiButton.HoverHapticEffect`/`PressHapticEffect` | yes | **Live** | 2025-09-16 | Gamepads and phones; not macOS 15 controllers or PC VR |
| `GuiObject.InputSink` (None/Activate/All) | yes | **Live** | — | Default None; GuiButtons default Activate |
| Input Action System | yes | **Live** | — | — |
| `InputActionLabel` (automatic key and button glyph) | yes | **[BETA] Studio only** | 2026-08-06 | No ImageRect or TextScaled yet |
| Advanced Video API: `VideoPlayer` + `VideoDisplay` + `Wire` | yes | **[BETA] Studio** | announced Oct 2025 | Syncs one video to many surfaces; `VideoFrame` not deprecated |
| `TweenService:SmoothDamp` | yes | **Live** | v636, Aug 2024 | Critically damped spring for number, Vector2, Vector3, CFrame |
| `RunService:BindToAnimation(fn, StepFrequency?, priority?)` | yes | **[T]** added around v738 | — | Fixed Hz1–Hz60 callbacks. Check it works on a live client |
| `AnimatedImageService` / `AnimatedImageTrack` | yes | **[T]** unannounced | — | Looks like a coming native animated-image (flipbook) API. Do not ship on it |
| `CanvasGroup.ResolutionScale` | yes | **[T]** | — | Community: not settable by game scripts |
| `SurfaceGui.Shape = CurvedHorizontally`, `.HorizontalCurvature` | yes | **[T]** hidden | added 2023 | Community: exists but is not exposed or supported |
| `TextLabel.OpenTypeFeatures` | yes | **Live** | Jul 2024 | Only `zero` and `ss03` at launch (Builder Sans). **No `tnum`** |
| `EditableImage` (runtime pixels into `ImageLabel.ImageContent`) | yes | **Live** | — | 1024² max; ID-verified 13+ owner; dashboard toggle; one display update per frame |
| 4K textures | — | Live for 3D only | 2026-01-30 | GUI images are not listed |
| Texture streaming | — | Live for 3D | client rollout 2026-03-23 | 2D UI is "coming next" |
| Custom font upload | — | **Not available** | — | Use the built-in families and the Creator Store cloud fonts (`Font.fromId`) |

---

## 2. GUI containers

### 2.1 `ScreenGui` [V]

| Property | Values / default | What it is for |
|---|---|---|
| `DisplayOrder` | int | Order between ScreenGuis; higher draws on top. Each ScreenGui is also its own **render cache unit** (section 7.1) |
| `ZIndexBehavior` | `Sibling` (use this) / `Global` | **CanvasGroup only flattens under `Sibling`** |
| `ScreenInsets` | `CoreUISafeInsets` (default) / `DeviceSafeInsets` / `TopbarSafeInsets` / `None` | CoreUI: clear of the Roblox topbar and cutouts. Device: clear of notches only. Topbar: the dynamic free strip **inside** the top bar (see `GuiService.TopbarInset`). None: full bleed, for backgrounds |
| `SafeAreaCompatibility` | `FullscreenExtension` (default) / `None` | Auto-extends UI authored for screens without cutouts. Use `None` for full-bleed art |
| `ClipToDeviceSafeArea` | true | When true, descendants are clipped to the device safe area |
| `IgnoreGuiInset` | legacy | true is the same as DeviceSafeInsets; false is the same as CoreUISafeInsets |
| `IgnoresTitleBarReservation`, `OnTopOfCoreBlur` | — | **[T]** undocumented |
| `ResetOnSpawn`, `Enabled` | — | `Enabled = false` is the cheapest way to hide a whole layer; it stops rendering it |

`LayerCollector:GetGuiObjectsAtPosition(x, y)` does manual hit-testing.
`GuiService:GetInsetArea(ScreenInsets)` returns the inset Rect.
`GuiService.TopbarInset` is the free topbar rect; it changes when the unibar expands.

### 2.2 `SurfaceGui`: UI in 3D, and the only route to bloom and DOF on UI [V]

| Property | Default / range | Notes |
|---|---|---|
| `SizingMode` | `PixelsPerStud` / `FixedSize` | FixedSize with `CanvasSize` makes the SurfaceGui pixel-for-pixel compatible with ScreenGui |
| `PixelsPerStud` | 50 | Higher is sharper and smaller |
| `LightInfluence` | 0–1 | 1 = lit like paint on a part; 0 = self-lit "TV screen" |
| `Brightness` | 1, range 0–1000 | Only when `LightInfluence < 1` **and** `AlwaysOnTop = false`. With `BloomEffect` in Lighting, Brightness > 1 pushes pixels past the bloom threshold, so the UI glows (community: needs graphics quality > 1) |
| `AlwaysOnTop` | false | true = exact ScreenGui colors, sharper text, and **no lighting and no brightness**. It likely also skips bloom and DOF [U] |
| `MaxDistance` | 1000 (0 = infinite) | Distance culling |
| `ZOffset` | — | Orders several SurfaceGuis on one face without moving them |
| `ClipsDescendants` | true | — |
| `ToolPunchThroughDistance` | — | Input arbitration against held Tools |
| `Shape`, `HorizontalCurvature` | — | **[T]** hidden: curved SurfaceGuis are not usable |

Known pitfalls:

- **Color accuracy.** With `LightInfluence = 0` colors still come out a little dark (for example 233 instead of 255)
  because the tonemapper runs on them. `ColorGradingEffect.TonemapperPreset = Retro` restores exact colors, but
  for the whole scene. [V: class and enum exist; C: behavior]
- **DepthOfField** can draw a halo on SurfaceGuis. [C]
- **Atmosphere** can tint SurfaceGuis when `LightInfluence > 0`. [C]
- **Input:** interactive SurfaceGuis should live in `PlayerGui` with `Adornee` set to the part. Buttons then get
  clicks and the full `GuiState`. [C, standard practice]

### 2.3 `BillboardGui` [V]

The same lighting trio applies (`LightInfluence`, `Brightness`, `AlwaysOnTop`). It also has `MaxDistance`,
`DistanceStep` (quantizes rescaling), `StudsOffset(WorldSpace)`, `ExtentsOffset(WorldSpace)`, `SizeOffset`,
`PlayerToHideFrom`, and `GetScreenSpaceBounds()`. Use it for world-anchored nameplates or floating numbers that
must pick up bloom.

### 2.4 `CanvasGroup`: flatten, fade, tint, mask [V][C]

- **Properties:** `GroupTransparency`, `GroupColor3` (multiplies), and `ResolutionScale` [T].
  `ClipsDescendants` is always true.
- **How it works:** the subtree renders into a texture of exactly `AbsoluteSize` with DPI scaling applied. Then
  UICorner, UIGradient and UIStroke on the CanvasGroup apply to the **flattened result**. This gives you:
  - a **rounded clip mask** (UICorner) for any content, including rotated children and images;
  - a **transparency mask** (UIGradient.Transparency) over the whole group: wipes, iris-ins, edge fades, a light
    sweep that moves over text and icons together;
  - a correct **group fade**, with no double-alpha where children overlap.
- **Memory is `w × h × 4 bytes` at device pixels.** A 900×600 pt panel on a 3× phone is 2700×1800×4, about
  19.4 MB. Budget by quality level. The client caps CanvasGroup memory, and past the cap "CanvasGroup will render as
  a blank texture".
- **Quality degrades** at graphics level ≤ 3, or when an axis exceeds about 512 px under pressure (community
  reports; staff filed a ticket in Apr 2024 and it is still open). Text inside is slightly blurry.
- **Invisible CanvasGroups keep their texture.** Only `:Destroy()` frees it. Community asks for better memory
  control; staff have not replied as of Feb 2026.
- **Resizing reallocates the texture.** Keep sizes static and animate a `UIScale` or a parent instead.
- It only works under `ZIndexBehavior.Sibling`. `GroupTransparency` does **not** affect a UIShadow inside it (bug
  report).
- **Pattern:** "CanvasGroup on demand". Swap a panel into a CanvasGroup (or enable a prebuilt one) only for the
  open/close transition, then flatten it back.

### 2.5 `ViewportFrame`: 3D models inside UI [V][C]

| Property | Default | Notes |
|---|---|---|
| `CurrentCamera` | nil | A Camera parented under the VPF; its `CFrame` and `FieldOfView` drive the view |
| `Ambient` | (200,200,200) | Overall light hue |
| `LightColor` | (140,140,140) | The single directional light |
| `LightDirection` | (-1,-1,-1) | Animate it for moving glints on gems |
| `ImageColor3` / `ImageTransparency` | white / 0 | Tints or fades the rendered image (cheap; no re-render) |
| `IsMirrored` | — | [T] undocumented |
| `:CaptureSnapshotAsync()` | — | Returns a ContentId (added 2023). Security level unverified [U] |

**Cannot render:**
- shadows and post-processing (docs);
- particles, beams and trails (docs and long-standing requests, still open Jun 2026);
- Neon and Glass (lowest quality, so no neon glow);
- point, spot and surface lights (only `LightColor`/`LightDirection` plus `Ambient`) [C];
- Highlights [U].

**Can render:**
- parts and MeshParts, including `SurfaceAppearance` (PBR);
- a `Sky` child used as a reflection cubemap (docs), which makes metallic crystals look right;
- animated Humanoids and AnimationControllers, and raycasts, but **only inside a `WorldModel`** child.

**Performance:** a VPF re-renders only when its content or camera changes (community; long-standing). So many
**static** VPFs are fine, but many **spinning** ones cost a scene render each per frame. The docs' camera-orbit
sample is fine for one hero object. Resolution is community-reported as hard-capped at 1024². Mesh LOD can pick a
low level based on the *real* camera's distance; set `MeshPart.RenderFidelity = Precise` for VPF models [C].

### 2.6 `VideoFrame` (and the beta `VideoPlayer` + `VideoDisplay`) [V]

- **Upload:** 13+ ID-verified uploader. `.mp4`/`.mov`, ≤ 5 min, ≤ 4096×2160, < 3.75 GB. **2,000 Robux per
  upload**, no refund if moderation rejects it. At most 20 per day. **The alpha channel is ignored.**
- **Playback:** "A maximum of two videos can play simultaneously." `Looped`, `Playing`, `:Play()`/`:Pause()`,
  `TimePosition`, `Volume`, and `DidLoop`/`Ended`/`Loaded`. `MaximumResolution: VideoSampleSize (Small/Medium/
  Large/Full)` caps decode cost; use Small or Medium on mobile [U: that it helps is inferred].
- It must sit under a ScreenGui, SurfaceGui or BillboardGui.
- **Advanced Video API [BETA]:** one `VideoPlayer` wired to many `VideoDisplay`s, all in sync "with no impact to
  performance". Its audio can be routed through the Audio API. `VideoDisplay` has `ScaleType`, `ResampleMode`,
  `TileSize`, `VideoRectOffset/Size`, `VideoColor3` and `VideoTransparency`.
- **Use for us:** a looping nebula or "multiverse" backdrop, or a cinematic prestige interstitial. It cannot be a
  transparent overlay because there is no alpha.

### 2.7 Frame, ImageLabel/ImageButton, TextLabel, ScrollingFrame: the details that matter [V]

**`GuiObject`:**
- `AnchorPoint`, `Rotation` (always about the **center**, not the AnchorPoint), `ZIndex`, `LayoutOrder`,
  `AutomaticSize`, `ClipsDescendants`, `SizeConstraint` (RelativeXX/XY/YY);
- `Interactable`, `GuiState`, `InputSink`;
- `Selectable`, `SelectionImageObject`, `SelectionOrder`, `NextSelection*`;
- touch signals: `TouchTap`, `TouchPan`, `TouchPinch`, `TouchSwipe`, `TouchLongPress`, `TouchRotate`.

**`ImageLabel`/`ImageButton`:**

| Property | What it does |
|---|---|
| `Image` / `ImageContent` | `ImageContent` also accepts `Content.fromObject(editableImage)` |
| `ImageColor3` | Multiply tint. Author sprites **white** so one sprite serves every color |
| `ImageTransparency` | — |
| `ImageRectOffset` / `ImageRectSize` | Atlas sub-rectangles. If either size component is 0, the whole image is used |
| `ScaleType` | `Stretch`, `Tile`, `Slice`, `Fit`, `Crop` |
| `SliceCenter`, `SliceScale` | 9-slice |
| `TileSize` | Tiling starts at the top-left |
| `ResampleMode` | `Default` / `Pixelated` |
| `ContentImageSize`, `IsLoaded` | — |
| `HoverImage` / `PressedImage` (buttons only) | — |

**`TextLabel`:**
- `FontFace` (a `Font`), `TextSize`, `LineHeight`, `RichText`;
- `MaxVisibleGraphemes` (for typewriter reveals), `ContentText`, `TextBounds`, `TextFits`;
- `TextTruncate` (`AtEnd`/`SplitWord`), `TextDirection`, `OpenTypeFeatures`;
- the legacy `TextStrokeColor3/Transparency`.

**`ScrollingFrame`:**
- `AutomaticCanvasSize`, `ElasticBehavior`, `ScrollingDirection`;
- `ScrollVelocity`, `GetSampledInertialVelocity()`, `ClearInertialScrolling()`, `ScrollToTop()`;
- custom scrollbar art: `TopImage`, `MidImage`, `BottomImage`, `ScrollBarImageColor3`.

UIGradient does **not** apply to ScrollingFrame or TextBox.

`Frame.Style` has old presets such as `DropShadow`, but they are legacy; do not use them.

---

## 3. Visual modifiers

### 3.1 `UIGradient` [V][BETA for Radial, Conical, TileMode and Scale]

| Property | Semantics |
|---|---|
| `Color: ColorSequence` | Multiplies the parent's rendered color |
| `Transparency: NumberSequence` | Multiplies the parent's alpha. Keypoint envelopes are ignored. **This is the UI mask primitive** |
| `Offset: Vector2` | Moves the gradient from the parent's center, in parent sizes: (1,0) is one width to the right. For Radial and Conical it is the **center point** |
| `Rotation: number` | Clockwise degrees, starting left-to-right. For Conical it is the start angle |
| `Scale: number` [BETA] | Minimum 0.001. Linear: keypoint distance. Radial: the outer radius. Conical: the angular sweep |
| `TileMode` [BETA] | `Clamp` (default: the edge keypoints extend), `Repeat`, `Mirror` |
| `Type` [BETA] | `Linear` (default), `Radial` (radiates out from Offset), `Conical` (sweeps clockwise 0–360°) |
| `Enabled` | — |

**Applies to:** Frame (the background), TextLabel and TextButton (the glyph fill), ImageLabel and ImageButton (the
image, including its alpha), ViewportFrame (the rendered image), Path2D, UIStroke (as a child of the stroke), and a
CanvasGroup (the flattened group).

**Not supported on:** ScrollingFrame and TextBox.

**One UIGradient per object.** Several gradients on one element is still a feature request (beta thread). For
more, nest a child Frame or a stroke that has its own gradient.

**Keypoints:** ColorSequence and NumberSequence are limited to 20 keypoints [U: long-standing engine limit;
verify]. Gradient interpolation is always linear between keypoints, and there is no smoothing or step mode
(requested in the beta thread). Fake a step with two keypoints 0.001 apart, as our R6 does.

**Performance (staff, 2026-09):**
- avoid more than 1000 gradients at once;
- animating `Scale`, `TileMode` or `Type` is "cheaper than animating color or transparency values";
- two-color gradients and evenly spaced stops are faster.

Animating `Offset` and `Rotation` is the standard cheap sweep [U: cheap in practice].

**The "radial looks square" investigation.** Official behavior:
- a circle, radius `r = (w + h)/4 × Scale`, centered at `Offset`;
- a fixed 1:1 aspect ratio ("It is quite strange the Radial gradient has a constant 1 aspect ratio"). On non-square
  frames the circle is cropped, which one user described as "acts as if the frame is always a square, cropping out
  the gradient";
- beyond `r`, `Clamp` paints the last keypoint.

Why a square frame can look square:

| Symptom | Cause | Fix |
|---|---|---|
| The corners are colored or opaque and the silhouette is the frame's square | The last keypoint's transparency is < 1 (Clamp extends it to the corners) | End with `NumberSequenceKeypoint.new(1, 1)`, or reach full transparency before t=1. Add `UICorner(0.5)` if it must be a disc |
| The ramp runs into the corners | `Scale ≥ 1.414` on a square, or TileMode Repeat/Mirror producing rings | Scale 1 makes the circle touch the edges; `Scale = 2·√(w²+h²)/(w+h)` ends the ramp exactly at the corners (a vignette) |
| Works in Studio, but players see a linear ramp or nothing | The beta has not shipped to clients | Keep the sprite fallback behind a server-controlled flag (section 9) |
| You need an ellipse (wide vignette, oval aura) | Not supported | A stretched radial **sprite** (`ScaleType.Stretch`), or a square radial frame inside a clipping parent |

A 30-second test harness for Studio (the beta must be enabled):

```lua
local f = Instance.new("Frame"); f.Size = UDim2.fromOffset(200, 200); f.BackgroundColor3 = Color3.new(1,1,1)
local g = Instance.new("UIGradient"); g.Type = Enum.GradientType.Radial
g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
g.Parent = f -- expect: a crisp disc of diameter 100 (r = (200+200)/4 * 0.5), not a square
```

**Conical for progress rings:** use hard transparency keys at `p`, as in our R6. Staff are considering "scale > 1 on
conical by chopping off the tail" for better radial progress bars.

### 3.2 `UIStroke` [V]

| Property | Values | Notes |
|---|---|---|
| `ApplyStrokeMode` | `Contextual` (the text outline on a text object) / `Border` | — |
| `BorderStrokePosition` | `Outer` (default) / `Center` / `Inner` | Border strokes only |
| `BorderOffset: UDim` | — | Adds to the position; scale is relative to the shortest axis |
| `StrokeSizingMode` | `FixedSize` (px, default) / `ScaledSize` | ScaledSize makes `Thickness` a fraction of the shortest axis (0.1 on 200×300 is 20 px). Use it for resolution-independent rims |
| `LineJoinMode` | `Round` / `Bevel` / `Miter` | Use Round for text |
| `ZIndex` | — | Several strokes per object are allowed now. The order is **undefined for equal ZIndex** |
| `Color`, `Transparency`, `Thickness`, `Enabled` | — | A UIGradient **child** colors the stroke |

"Contextual strokes can only be placed on the outer border of text." So a text outline is always outside the glyph.

**Layered-stroke neon trick:**
- Borders: 2–3 UIStrokes on one Frame make a neon tube, for example Inner 1 px white core + Center 3 px cyan
  α 0.2 + Outer 8 px cyan α 0.8 with a radial or linear gradient.
- Text: whether several *Contextual* strokes stack on one TextLabel is not confirmed ("removed the limitation of one
  **border** stroke"). If it does not work, use text clones as our R3/R4 already do. [U]

**UIStroke vs `TextStroke*`:** the legacy stroke is a thin, fixed, single-color outline. UIStroke gives thickness,
joins, gradients and transparency.

**Budget:** < 300 strokes on screen for low-end devices (staff).

### 3.3 `UICorner` [V]

`CornerRadius` (sets all four) plus `TopLeftRadius`, `TopRightRadius`, `BottomLeftRadius` and `BottomRightRadius`
(UDim). `UDim.new(0.5, 0)` makes a pill or circle. It affects the background, the UIStroke Border path, UIShadow
and a CanvasGroup's clip.

Do **not** set `CornerRadius` and the per-corner properties together; staff say that gives "unexpected results".

Relic panel idea: per-corner radii give asymmetric "cut" shapes, for example a big top-left radius with square
others.

### 3.4 `UIShadow` [V]

| Property | Notes |
|---|---|
| `BlurRadius: UDim` | 0–1000. Scale is relative to the parent's shortest side |
| `Spread: UDim2` | Grows (+) or shrinks (−) the shadow shape |
| `Offset: UDim2` | Directional light offset; scale is relative to the parent |
| `Color`, `Transparency` | A saturated color with Offset 0 gives a **neon glow/aura** |
| `ZIndex` | **Negative only.** Several shadows render in increasing ZIndex |
| `Enabled` | — |

Limits:
- rectangle and UICorner shape only, so no text-glyph and no image-alpha shadows;
- not on Path2D;
- jaggy with large corner radii;
- ≤ 100 on screen;
- "consistently faster than 9-sliced ImageLabels";
- "Gradient + shadow isn't possible with our current gradient technology" (staff).

**Glow = shadow.** A cyan `UIShadow` (Offset 0, Spread +4, BlurRadius 24, Transparency 0.35) behind a card is the
cheapest real soft glow in 2D Roblox UI. Stack two (ZIndex −1 tight and bright, −2 wide and faint) for bloom-like
falloff.

### 3.5 `Path2D` [V]

- **Control points:** `Path2DControlPoint.new(position: UDim2, leftTangent: UDim2, rightTangent: UDim2)`, as cubic
  Bézier handles relative to the point.
- **Methods:** `SetControlPoints`, `InsertControlPoint`, `UpdateControlPoint` and `RemoveControlPoint`.
  There are at most **100 control points** (`GetMaxControlPoints()`).
- **Look:** `Thickness` 0–100 px, `Color3`, `Transparency`, `ZIndex`, `Visible`. `Closed = true` connects last to
  first (at least 3 points). It is **stroke only: no fill**, and there are no dashes or caps.
- **Sampling:**
  - `GetPositionOnCurve(t)` / `GetTangentOnCurve(t)` work in parameter space;
  - `GetPositionOnCurveArcLength(t)` / `GetTangentOnCurveArcLength(t)` give **even spacing**, for sprites that
    travel along a line;
  - `GetLength()` is noted as expensive when called often. Cache it.
- **Styling:** a UIGradient child colors it; the upgraded gradients "fully support Path2D". Whether the gradient
  maps to the curve's length or its bounding box is not documented; our DESIGN §18 already flags this. [U]
- **Clipping:** clipped by parents since the rotation-clipping change. It cannot have a UIShadow. Fake the glow with
  stacked wider, more transparent Path2Ds (our R11).

### 3.6 Images: atlases, 9-slice, tiling, limits [V][C]

- **Upload size:** GUI images are downscaled to **1024×1024** max (community consensus; the 2026 4K launch excludes
  GUI).
  - Atlas everything small into 1024² sheets.
  - Put big painted backdrops into several tiles, or into 3D Decals (4K capable, section 10 idea 1).
  - Leave 1–2 px of alpha-bled padding between atlas regions to prevent bleeding at fractional scales.
- **9-slice:**
  - `ScaleType = Slice` with `SliceCenter` (a pixel Rect of the stretchable middle in *source-image* pixels). The
    corners keep their size, the edges stretch along one axis, and the center stretches.
  - `SliceScale` scales the edge thickness, so the same art works at several sizes and DPIs.
  - Studio has a 9-Slice Editor.
  - With an atlas (`ImageRectOffset/Size`), our DESIGN §14.1 treats `SliceCenter` as **relative to the region**.
    The docs do not state this interaction; it is the widely used behavior. Verify once in Studio. [U]
  - Edges **stretch, not tile**. Ornate repeating borders (chains, runes) should be designed "stretch-safe"
    (gradients and smooth bands), with repeating motifs as separate `Tile` strips.
- **Tile:** `ScaleType = Tile` with `TileSize` (UDim2). It does **not** tile an ImageRect region (DESIGN §14.2), so
  a tile texture must be its own asset. Scroll it by moving the label's Position inside a clipping parent, jumping
  back by one tile.
- **`ResampleMode = Pixelated`:** nearest-neighbor for pixel art or crisp scanlines. On low-memory mobile devices
  the engine drops mips and applies block compression, and staff say pixel art will still blur there, with "no
  specific work planned".
- **Memory:** a 1024² RGBA texture is about 4 MB uncompressed. It shows in F9 under `GraphicsTexture`
  (`DeveloperMemoryTag` has `GraphicsTexture`, `GraphicsTextureCharacter` and `Gui`).
- **`EditableImage` (runtime pixels):**
  - `AssetService:CreateEditableImage({Size = Vector2})` or `CreateEditableImageAsync(content)`.
  - Drawing methods: `DrawCircle`, `DrawLine`, `DrawRectangle`, `DrawTriangle`, `DrawImage`,
    `DrawImageTransformed`, and `Read/WritePixelsBuffer`.
  - `ImageCombineType` = `AlphaBlend`, `BlendSourceOver`, **`Add`**, **`Multiply`**, **`Subtract`**,
    `Overwrite`, `NormalMapBlend`. These are real blend modes, but **only while baking pixels**, not on screen.
  - It is shown via `ImageContent = Content.fromObject(ei)`.
  - Limits: 1024² max; a client memory budget (community cites about 32 MB); **only one EditableImage display update
    per frame**; the owner must be ID-verified 13+ and "Enable Mesh / Image APIs" must be on in the dashboard.

### 3.7 Layout and sizing [V]

- **`UIScale.Scale`** multiplies the whole subtree at render time. It is the cheapest way to animate "size" (pops,
  punches, zoom), and text is re-rasterized crisply [U: crispness observed].
- **`UIAspectRatioConstraint`** (`AspectRatio`, `AspectType` FitWithinMaxSize/ScaleWithParentSize, `DominantAxis`),
  **`UISizeConstraint`** (Min/MaxSize) and **`UITextSizeConstraint`** (Min/MaxTextSize with `TextScaled`).
- **Flex:** `UIListLayout.HorizontalFlex/VerticalFlex` (`UIFlexAlignment`: None, Fill, SpaceAround, SpaceBetween,
  SpaceEvenly), `Wraps`, `ItemLineAlignment`, plus a per-child **`UIFlexItem`** (`FlexMode` None/Grow/Shrink/Fill/
  Custom with `GrowRatio`/`ShrinkRatio`, and `ItemLineAlignment`).
- **`UIPadding`** (UDim per side), **`UIGridLayout`**, **`UITableLayout`**, and **`UIPageLayout`** (a built-in
  animated pager with `EasingStyle`, `TweenTime`, `Circular`, and gamepad, touch and scroll input).
- **`UIDragDetector`**: engine-native dragging and rotation of UI, with constraint functions
  (`AddConstraintFunction`, `SetDragStyleFunction`), `BoundingUI`, and cursor icons.
- **Cost:** layout recomputes show as `UpdateUILayouts` in the MicroProfiler. **Never keep layout objects inside
  containers you move every frame** (our DESIGN §17 already says this).

### 3.8 Text and fonts [V]

**RichText tags** (with `RichText = true`):

| Tag | Attributes / notes |
|---|---|
| `<b>`, `<i>`, `<u>`, `<s>`, `<br/>`, `<!-- -->` | — |
| `<font>` | `color="#hex"`/`rgb()`, `size`, `face="Michroma"`, `family="rbxasset://fonts/families/X.json"`, `weight` (Thin–Heavy or 100–900), `transparency`, `features="zero"` |
| `<stroke>` | `color`, `thickness`/`th`, `transparency`/`tr`, `joins`, `sizing` |
| `<mark>` | `color`, `transparency` (a highlight behind the text) |
| `<uppercase>`/`<uc>`, `<smallcaps>`/`<sc>` | — |

Escapes are `&lt; &gt; &quot; &apos; &amp;`. Auto-localization strips the tags.

**Fonts:**
- `Font.new(family, weight?, style?)`, `Font.fromName("Michroma", Enum.FontWeight.Bold)`,
  `Font.fromEnum(Enum.Font.X)` and `Font.fromId(assetId, …)`.
- `Enum.Font` (verified list): AmaticSC, Antique, Arcade, Arial, ArialBold, Arimo, ArimoBold, Bangers, Bodoni,
  BuilderSans (+Bold/ExtraBold/Medium), Cartoon, Code, Creepster, DenkOne, Fantasy, Fondamento, FredokaOne,
  Garamond, Gotham (+Black/Bold/Medium), GrenzeGotisch, Highway, IndieFlower, JosefinSans, Jura, Kalam, Legacy,
  LuckiestGuy, Merriweather, Michroma, Nunito, Oswald, PatrickHand, PermanentMarker, Roboto, RobotoCondensed,
  RobotoMono, Sarpanch, SciFi, SourceSans (+Bold/Italic/Light/Semibold), SpecialElite, TitilliumWeb, Ubuntu.
- **More families** exist only as families (Montserrat, which we use; Inter; Poppins; and others).
- **Cloud fonts** (about 85, `Font.fromId`, third-party list) include display and sci-fi faces that suit a cosmic
  neon look: Audiowide 12187360881, Rajdhani 12187375422, Teko 12187376174, Unica One 12187364842, Monoton
  12187374098, Codystar 12187363887, Bungee Inline/Shade, and Silkscreen. Verify the IDs in Studio [C].
- **Custom font upload does not exist** (still requested in 2026).

**Other text features:**
- `OpenTypeFeatures`: only `zero` (slashed zero) and `ss03` were announced, and **no `tnum`**. For stable counters,
  use fixed-width digit cells or a monospace face (RobotoMono, Builder Mono via cloud) [V for the announcement].
- `MaxVisibleGraphemes` reveals text by grapheme, with correct RichText and emoji handling. Use it for typewriter
  lore text.
- `TextService:GetTextBoundsAsync(GetTextBoundsParams{Text, Font, Size, Width, RichText})` measures text and
  honors `PreferredTextSize`.
- `GuiService.PreferredTextSize` (Medium, Large, Larger, Largest) scales text at the render level. Design for it.
- `TextSize` is believed to be capped at 100 [U]. For huge hero numbers, use `UIScale` on the label.
- **Localization:** `LocalizationService`, `LocalizationTable`, `AutoLocalize` (we set false) and
  `Translator:FormatByKey`. RichText formatting is dropped by auto-translation.

### 3.9 UI Styling: CSS-like sheets with native transitions [V]

- **Objects:** a `StyleSheet` holds `StyleRule`s (a `Selector` plus properties) and is attached by a `StyleLink` on
  a ScreenGui. `StyleDerive` gives inheritance. Tokens are **attributes** on a token sheet, referenced as `"$Gold"`.
  Themes are swappable token sets.
- **Selectors:**
  - class: `"TextButton"`;
  - tag: `".Primary"` (CollectionService tags);
  - name: `"#Title"`;
  - hierarchy: `">"`;
  - GuiState pseudo-classes `:Hover`, `:Press`, `:NonInteractable` (plus `:Selected` in the docs; the `GuiState`
    enum has only Hover, Idle, NonInteractable and Press [U]);
  - pseudo-instances `::UICorner`, `::UIStroke`;
  - query selectors `@Query` driven by `StyleQuery` conditions.
- **Transitions:**

  ```lua
  rule:SetPropertyTransitions({ ["*"] = TweenInfo.new(0.25),
      BackgroundColor3 = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out) })
  ```

  They fire **only** when a value changes through styling (a tag or GuiState change), "Handled natively by the
  engine, offering better performance than manual Luau tweening". They get expensive only with "hundreds of
  Transitions" at once.
- **Fit for us:** hover and press juice on every button without a Lua connection (idea 9). Per-layer "signatures"
  could become themes (DESIGN §6).

---

## 4. Compositing: what is and is not possible

| Want | Native GUI? | How on Roblox |
|---|---|---|
| Additive / screen / overlay blend | **No** (a request open since 2019) | Fake it with bright tint plus low alpha on pre-lightened art. **Real additive exists only in 3D**: `ParticleEmitter`/`Beam`/`Trail.LightEmission = 1`, plus Bloom |
| Multiply | Partially | `ImageColor3`, `UIGradient.Color` and `CanvasGroup.GroupColor3` all *multiply* the element's own pixels, not what is behind them |
| Mask by shape | Yes | `CanvasGroup` + `UICorner` for rounded clips; `ClipsDescendants` for rectangles (rotation-safe since 2026-09) |
| Mask by gradient | Yes | `UIGradient.Transparency` on the element, or on a `CanvasGroup` for whole subtrees |
| Mask by image alpha | **Yes, for free** | A UIGradient on an ImageLabel modulates *that image*, so a light sweep on a **white duplicate of the ornament art** follows its filigree exactly. No CanvasGroup needed |
| Backdrop blur of UI behind UI | **No** | Use pre-blurred art (see idea 13). `BlurEffect` blurs only the **3D** world, never ScreenGuis. Community "liquid glass" hacks use Highlights on meshes and fail on mobile and at graphics ≤ 5 |
| Bloom / DOF / color grading on UI | Only for 3D UI | SurfaceGui or BillboardGui with `AlwaysOnTop = false`; ScreenGui is post-post |
| Real-time shaders | **No** | Gradient animation, flipbooks, EditableImage (CPU, one update per frame) |
| Group fade without overlap artifacts | Yes | `CanvasGroup.GroupTransparency` |

---

## 5. Motion

### 5.1 TweenService [V]

- **`Enum.EasingStyle` (verified; there are no new styles):** Linear, Sine, Quad, Cubic, Quart, Quint, Exponential,
  Circular, Back, Bounce, Elastic. Directions are In, Out and InOut.
- **Tweenable types:** number, boolean, CFrame, Rect, Color3, UDim, UDim2, Vector2, Vector2int16, Vector3 and
  EnumItem. A newer tween on the same property cancels the older one.
- **`TweenService:GetValue(alpha, style, dir)`** gives an eased alpha for custom per-frame drivers. Use it to drive
  NumberSequence or ColorSequence (which are not tweenable) by rebuilding keypoints, but rebuild sparingly because
  this is Lua work plus a cache invalidation.
- **`TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?) -> (value, velocity)`** is a
  critically damped spring for number, Vector2, Vector3 and CFrame. It makes a perfect "follow" motion (cursor
  parallax, camera-UI lag, number bars catching up).

### 5.2 Per-frame drivers [V]

- **`RunService.PreRender`** (it replaces the deprecated `RenderStepped`) is the right event for UI and camera
  writes before the frame draws. **`BindToRenderStep(name, priority, fn)`** gives ordering.
- **`BindToAnimation(fn, Enum.StepFrequency.Hz30, priority)`** [T] gives fixed-rate callbacks from Hz1 to Hz60. It
  is ideal for **throttled ambient loops**: run ambient sparkles at 30 Hz or 15 Hz on the LOW tier and save half
  the Lua writes. Verify it on live clients.
- `Heartbeat` runs after physics and is fine for logic but adds latency to visuals.

### 5.3 Springs

- `SmoothDamp` covers critically damped motion. For **underdamped** (bouncy) motion use a spring integrator.
- The de-facto library is **`spr`** (Fraktality): `spr.target(inst, dampingRatio, frequency, {props})`. It
  animates any property, blends retargets physically, and uses one heartbeat for everything. Alternatives are
  Ripple (littensy), Fusion's `Spring`, and roact-spring.
- **Rule of thumb [U]:**
  - damping 0.55–0.7 with frequency 3–5 Hz for UI pops;
  - damping 1 for panels;
  - never springs under reduced motion.

### 5.4 Flipbooks via `ImageRectOffset` stepping [V API; U numbers]

- **Sheet math:** a 1024² sheet holds 8×8 frames of 128², or 4×4 of 256². Leave 1–2 px of padding; alpha-bleed.
- **Stepping:** accumulate `dt` and step at 20–30 fps (`frame = floor(t * fps) % n`), setting `ImageRectOffset`
  only when the frame changes. That is one property write per step, and the texture stays the same, so it batches.
- **Frame-rate:** decouple the flipbook rate from the render rate. Pause when the label is not `Visible` or the
  ScreenGui is disabled.
- **Tools:** EasySprite, SpriteClip and similar community modules exist.
- **Watch** `AnimatedImageService` [T]: it looks like a native flipbook or GIF API on the way.

### 5.5 UI particle systems (pooled ImageLabels) [C/U]

- **Libraries:** UIParticle, 2DEmitter, UIEmitter, UIParticles and "UI Particle" (2022–2025, DevForum). They mimic
  ParticleEmitter (color, size and transparency sequences, speed, spread, acceleration, rotation). None publishes
  benchmarks.
- **How to build one well [U]:**
  1. **Pool** a fixed number of ImageLabels created once (for example HIGH 96 / LOW 32), with `Visible = false`
     when idle. Never Instance.new per spark.
  2. Put them in a **dedicated FX ScreenGui** (or FX SurfaceGui) so their per-frame writes do not invalidate the
     static panel caches (section 7.1).
  3. Make them **contiguous siblings using one atlas texture**, so they batch into roughly one draw call.
  4. Write only `Position` (UDim2 offset), `ImageTransparency`, `Rotation` and `Size` (or a `UIScale`) per live
     particle per frame, on PreRender. Precompute the curves as lookup tables.
  5. **Budget:** about 4 property writes × N particles per frame. Aim for ≤ 150–200 live sprites on phones at
     60 fps, and measure in the MicroProfiler. "Bright" sparks come from white sprites with a pre-baked soft glow
     tinted by `ImageColor3`.
- **Alternative with real additive blending:** 3D `ParticleEmitter`s in front of the camera. But they render
  *under* all ScreenGuis, so this only works if the UI they decorate is itself in 3D (SurfaceGui), or when the
  bursts happen over the 3D world.

### 5.6 Screen shake, flashes, hit-stop [U, standard technique]

- **UI shake:** offset a root container Frame, never the ScreenGui. Use trauma² decay and Perlin noise:
  `root.Position = base + UDim2.fromOffset(math.noise(t*25, 1)*A*tr², math.noise(t*25, 2)*A*tr²)`, with A about
  8–14 px. Add a rotation of about 1–2° × tr² for heavy hits. Skip it under reduced motion.
- **Punch:** `UIScale` 1 → 1.08 → 1 with a spring. Hit-stop means freezing UI tweens for 40–80 ms on a big
  prestige.
- **Flash:** a full-screen Frame on a high-DisplayOrder ScreenGui, `BackgroundTransparency` 0.2 → 1 in 0.2 s, Quad
  Out. A radial white sprite tinted with the theme color looks more like light than a flat fill.
- **Chromatic aberration:** red, cyan and white clones offset ±2 px (our R12). Grain comes from a tiled noise
  texture at α 0.03, jittered. Scanlines come from tile_scan. A vignette comes from a radial gradient (beta) or a
  sprite. God rays come from a slowly rotating `rays` sprite.
- **Camera shake** (3D) is for the world. If the realm moves into 3D (idea 1), shake the Camera CFrame and leave the
  HUD stable, which reads as more "cinematic".

### 5.7 Reduced motion and accessibility [V]

- `GuiService.ReducedMotionEnabled`: drop shakes, springs, flipbooks and parallax; keep state changes.
- `GuiService.PreferredTransparency`: multiply panel background alpha by it (our R10 does).
- `GuiService.PreferredTextSize`.

All three are read-only client settings.

---

## 6. Input and feel [V]

- **`GuiObject.Interactable`:** false makes the object stop receiving input, and `GuiState` stays `NonInteractable`.
  Pair it with a styled `:NonInteractable` look.
- **`GuiObject.GuiState`:** Idle, Hover, Press or NonInteractable. Drive hover and press visuals from it, or from
  Styling pseudo-classes.
- **`GuiObject.InputSink`:** None, Activate or All. Default None; GuiButtons default Activate. Our map art uses None
  so drags pass through.
- **Gamepad and console navigation:**
  - `GuiService.SelectedObject`, `GuiService:Select(parent)` and `GuiService.AutoSelectGuiEnabled`;
  - per-object `Selectable`, `SelectionOrder`, `NextSelectionUp/Down/Left/Right` and `SelectionImageObject` (a
    custom highlight GuiObject, sized in *scale*; it can be an animated ring);
  - `GuiBase2d.SelectionGroup` with `SelectionBehavior*` (Escape/Stop) to trap focus in modals;
  - `GuiService.GuiNavigationEnabled` and `IsTenFootInterface()`.
- **Button glyphs:** `InputActionLabel` [BETA] shows the right key or button automatically. For now use
  `UserInputService:GetImageForKeyCode()` / `GetStringForKeyCode()`, plus `UserInputService.PreferredInput`
  (KeyboardAndMouse, Gamepad, Touch, MicroGamepad) to swap hint sets.
- **Haptics:**
  - Zero code: `GuiButton.PressHapticEffect = HapticEffect(Type = UIClick)` and `HoverHapticEffect = UIHover`.
  - For custom rumble: `HapticEffect.Type = Custom` with `:SetWaveformKeys({ {Time ms, Intensity 0–1,
    Interpolation} })`; intensities below 0.1 may not trigger.
  - Other types: `UINotification`, `GameplayExplosion` and `GameplayCollision` (`Position`/`Radius`).
  - Legacy: `HapticService:SetMotor(...)`.
  - Supported on gamepads and phones.
- **Mouse:**
  - `UserInputService.MouseIcon` / `MouseIconContent`, `MouseIconEnabled` and `OverrideMouseIconBehavior`.
  - For a custom animated cursor, hide the OS icon and move an ImageLabel on PreRender, in its own tiny ScreenGui.
  - `UIDragDetector` has cursor icons of its own.
- **Hover and press states:**
  - Set `AutoButtonColor = false` and write your own states (a tint, a UIScale of 1.03 on hover and 0.96 on
    press, a stroke brighten, and a UIShadow glow grow).
  - `ImageButton.HoverImage`/`PressedImage` swap textures natively.
  - `Modal = true` frees the mouse in first-person.

---

## 7. Performance

### 7.1 The render cache per LayerCollector [V]

- **What is cached:** "Gui appearances are cached until they change." A per-ScreenGui array of rectangles and
  visuals is reused across frames.
- **What invalidates it:** any added or removed descendant, or any property change on a descendant or the Gui
  itself. This includes **non-visual descendants** (for example a `NumberValue.Value` or an attribute update under a
  ScreenGui). "Any change in any descendant of a Gui will invalidate the entire Gui's appearance."
- **Rules:**
  - separate ScreenGuis for static chrome, dynamic numbers and FX;
  - keep state *out* of the GUI tree (Lua tables, not ValueObjects or attributes under the GUI);
  - use `ScreenGui.Enabled = false` for hidden layers.
- **Profiling:** a static ScreenGui's `GuiLayerCollector::render2dContext` should be near-instant in the
  MicroProfiler.

### 7.2 Draw calls [V]

- Batching needs **consecutive siblings in tree-insertion order** of the same type and texture. Frames, text, and
  images with different textures break a batch. Staff say this is intentional for compatibility and for correct
  alpha overlap.
- Declarative frameworks (React-lua, Fusion) create children in arbitrary order, so batching is poor.
- **Practice:** a single UI atlas; group the atlas ImageLabels together in each container; create pooled FX sprites
  in one contiguous run.

### 7.3 Budgets

| Item | Budget | Source |
|---|---|---|
| UIGradient on screen | < 1000 | staff, upgraded gradients 2026 |
| UIStroke on screen | < 300 (low-end) | staff, UIStroke v2 |
| UIShadow on screen | ≤ 100 | staff, shadows launch |
| CanvasGroup | `w·h·4` bytes at device pixels each, capped per quality level; blank when over | docs and the beta post |
| ViewportFrame | static is cheap; each *changing* VPF is one extra scene render | community |
| VideoFrame | ≤ 2 playing at once | docs |
| EditableImage | 1024² max; about 32 MB client budget; 1 display update per frame | docs and community |
| Path2D | ≤ 100 control points each; `GetLength()` is costly | docs |
| Our own gates | DESIGN §17 (HUD ≤ 80 instances and ≤ 6 tweens; panel ≤ 450; glows ≤ 24 per panel) | DESIGN.md |

### 7.4 Mobile specifics [V][C]

- Low-memory devices **drop mips** on UI textures, which blurs them. Author UI at the 1:1 display scale where
  possible, and use a LOW atlas at 512² (we already do).
- CanvasGroups drop resolution at quality ≤ 3, and bloom is gone at the lowest quality. **Every "3D UI glow" idea
  needs a 2D sprite fallback.**
- **Diagnose with:**
  - the F9 console Memory tab (`GraphicsTexture`, `Gui`);
  - the MicroProfiler on the phone (Settings → MicroProfiler, then browse to the phone IP);
  - the labels `UpdateUILayouts` and `render2dContext`.

---

## 8. How the best-looking Roblox UIs are built

These are patterns seen across top titles and DevForum showcases; they are observations, not official docs.

- **Painted art plus native layout.** Artists paint frames, buttons, plates and ornaments in Photoshop, Figma or
  Procreate. They export white or grey 9-slice-ready PNGs into 1024² atlases. Text, numbers and layout stay native
  (TextLabel, UIListLayout). Colors come from `ImageColor3` tints, so one ornament serves every rarity.
- **Text treatment.** A heavy display font, a white fill with a vertical UIGradient, a thick black Contextual
  UIStroke (Round joins), and a hard offset shadow clone. This is the "simulator/anime" look; it is our R3/R4.
- **Rarity shine.** A diagonal white band made from a UIGradient `Offset` tween on an overlay, looping every 2–3 s.
  "Legendary" adds a rotating rays sprite and sparkle flipbooks behind.
- **3D previews.** One hero ViewportFrame spinning the selected item. Lists use **pre-rendered icons** (uploaded
  renders) because many live VPFs hitch low-end devices.
- **World-space menus.** Title screens and lobbies (for example the Doors and Frontlines styles) put the camera in a
  dressed 3D scene and use SurfaceGuis for "screens", so bloom, DOF and lights sell the look. A ScreenGui HUD sits
  on top. DevForum resources cover camera-attached SurfaceGuis, mouse-tilt 3D panels and parallax-corrected 3D
  SurfaceGuis.
- **Motion.** Springs (spr) for everything that responds to input; tweens for scripted sequences; UIScale pops;
  staggered list entrances (30–50 ms per item).
- **Tooling:**
  - Figma to Roblox importers (FigBloxUI, GuiForge, and a Claude skill for Figma to Roblox);
  - UI Labs (a storybook plugin);
  - Fusion, React-lua and Vide for reactive UI;
  - the "Show off your UI designs" DevForum thread for reference;
  - ArtStation "Roblox UI" portfolios for style targets (for example Deepwoken-style ornate panels and Rivals
    redesigns).
- **Kits:** the Roblox UI Kit (Figma community), "General UI Kit" (DevForum 2026, tag-based), "Epic UI Pack", and
  marketplace packs (BuiltByBit). They are useful as scaffolds; none is AAA as shipped.

---

## 9. Implications for our current code (`src/client/Core/*`)

1. **`Theme.detect` probes can report false positives.** `caps.Radial`, `caps.Conical` and `caps.TileMode` probe
   by *setting* the property. The enum items exist in the API right now, while the renderer is Studio-beta-gated.
   Add a server-published override (for example a `ReplicatedStorage` attribute `MT_UIGradientV2 = false`) that
   forces them off until Roblox announces the client release. Then flip it without a client update. R6 (Conical
   ring), R7 (Radial), R8 (dashed TileMode) and R14 (scrim hole) all depend on this.
2. **UIShadow, PerCorner, BorderStrokePosition and InputSink are live.** Their probes are reliable. R2 can use
   UIShadow for shapes today (keep ≤ 100 on screen; the panel budget of 24 glows fits).
3. **R7 radial:** ensure the outermost stop has alpha 0, or Clamp paints the corners (the "square" symptom). For
   vignettes, use `Scale = 2·√(w²+h²)/(w+h)`.
4. **Rotated clipping is on by default** (2026-09-24). Rotating rays and rune rings inside clipped panels no longer
   leak. UICorner clipping still needs a CanvasGroup.
5. **Cache hygiene:**
   - `MarkerGui` is already isolated;
   - make sure `Recipes.shine` bands, R12 glitch clones and ring shimmers live in containers whose ScreenGui is not
     the big static `PanelGui`;
   - alternatively, accept the invalidation but keep shines sparse (the shine every 2.8 s dirties PanelGui during
     each 0.9 s sweep).
6. **Styling Transitions** could replace per-button hover and press tweens in `Motion` (fewer Lua tweens, which
   frees the `BUDGET_HUD = 6` budget for real animation).

---

## 10. Opportunities for Milestone Tree

Cost: **S** < 1 day, **M** 2–5 days, **L** > 1 week. Risk means technical or visual risk. Each idea has a mobile or
LOW fallback.

| # | Idea | Cost | Risk | Mobile / LOW fallback |
|---|---|---|---|---|
| 1 | **Realm backdrop in 3D:** the painted parallax layers as camera-facing planes (Decals, 4K-capable, texture-streamed) with a perspective camera, plus Bloom, DOF and ColorGrading. The HUD stays in ScreenGui | L | High (REALM contract rewrite; tonemapper shifts painted colors, so tune with `TonemapperPreset`) | Keep today's ScreenGui MapGui as the LOW path; share the tile art |
| 2 | **Ornate relic panels:** painted 9-slice frame art (white, `ImageColor3`-tinted per layer) + native gradient fill + a **white duplicate ornament with a UIGradient sweep**, a shine that follows the filigree exactly | M | Low | Same art from the LOW atlas; sweep off under reduced motion |
| 3 | **3D relic gems in ViewportFrames:** faceted crystal MeshPart with SurfaceAppearance + a `Sky` cubemap child for reflections; `LightDirection` swept on hover for glints; spin only when focused | M | Med (VPF has no neon or particles; LOD needs `RenderFidelity=Precise`) | A pre-rendered PNG of the gem (same angle) for lists and LOW; one live VPF at most |
| 4 | **UI particle pool** (FxGui, atlas sprites, contiguous siblings, PreRender or 30 Hz `BindToAnimation`) for spark flows, prestige bursts and milestone pops | M | Low–Med (Lua cost) | HIGH 96 / LOW 32 / reduced motion 0; burst counts scale with the tier |
| 5 | **Prestige "hero moment" in 3D:** for a 2–3 s cinematic, swap to a camera-attached SurfaceGui card (`LightInfluence=0`, `Brightness` 3–6) with real Bloom, 3D ParticleEmitters (`LightEmission=1`, true additive) and Beams, then snap back to the ScreenGui | M | Med (input on the SurfaceGui, color accuracy, alignment across aspect ratios) | The 2D version: UIShadow glow + particle pool + flash; a quality check disables bloom at level ≤ 2 |
| 6 | **Neon tubes with layered UIStrokes:** Inner white 1 px core, Center tinted 3 px, Outer 8 px α 0.8 with a gradient. Several strokes per object are live since Dec 2025 | S | Low | Drop to one stroke on LOW (< 300 strokes on screen) |
| 7 | **UIShadow auras:** colored shadows (Offset 0, Spread +4, BlurRadius 24–48) as glows on cards, CTAs and the capsule; two stacked for a bloom falloff. It replaces most `glow_rr` sprites for shapes | S | Low | Keep `glow_rr` for text glows (UIShadow cannot do text) and for devices over budget |
| 8 | **Conical and radial v2** for progress rings, portal swirl, vignettes and the scrim hole. Ship behind a **server kill switch** until the client release | S (already coded) | Med (the beta could change) | The existing sprite paths (halfdisc, radial_p50/60/70) |
| 9 | **Styling Transitions** for every button's hover, press and non-interactable state (tokens per layer signature); themes for per-universe palettes | M | Low | Same styles; transitions set to 0 s under reduced motion |
| 10 | **Flipbook FX atlas:** 8×8 of 128² per 1024 sheet for the portal vortex, prestige burst, rune ignition and coin spin; stepped at 24–30 fps, paused when invisible | M (art heavy) | Low | 4×4 of 128² in a 512 LOW sheet at 12–15 fps |
| 11 | **CanvasGroup transitions only:** panel open and close wipes (a gradient mask on the group), iris-in for layer changes, a rounded clip for rotating contents, flattened back afterwards | S–M | Med (memory and blank-texture risk) | Plain `UIScale` + transparency tweens; never CanvasGroup at quality ≤ 3 |
| 12 | **Video nebula:** a looped `VideoFrame` (MaximumResolution Medium) behind the multiverse portal or the prestige interstitial | S (2,000 R$ per upload) | Med (no alpha; 2-video cap; decode cost) | A static painted image or the existing tile layers |
| 13 | **"Glass" panels over the realm:** show a pre-blurred, darkened 256–512 px copy of the current realm view under the sheet (from the LOW tier tiles, or a downsampled capture baked into an EditableImage once per open) | M | Med (EditableImage needs an ID-verified owner and the dashboard toggle; one update per frame) | A static pre-blurred realm image per biome (a tiny texture) |
| 14 | **Energy pulses along Path2D links:** pooled sparkle sprites placed with `GetPositionOnCurveArcLength(t)` (length cached), plus a moving `Offset` on the link's UIGradient | S–M | Low (check the gradient's bbox mapping) | Only 1 pulse per link on LOW; none under reduced motion |
| 15 | **Juice kit:** trauma-based root shake, UIScale punch, hit-stop, radial flash, RGB split on big numbers, and `PressHapticEffect` UIClick / custom waveform on prestige | S | Low | All gated by reduced motion and tier; haptics only where supported |
| 16 | **Console-grade navigation:** an animated `SelectionImageObject` ring (conical v2 or sprite), `SelectionGroup` traps in modals, `GuiService:Select` on panel open, and `InputActionLabel` hints once live | M | Low | The same system on touch (it is not shown) |
| 17 | **Render-cache and batching pass:** split PanelGui into Chrome (static), Values (numbers at ≤ 5 Hz) and Fx (animated) ScreenGuis with the same DisplayOrder band; order atlas sprites contiguously; audit with `render2dContext` | S–M | Low | Helps mobile most; no fallback needed |
| 18 | **Cosmic display type:** trial cloud fonts (Audiowide, Unica One, Monoton) for layer titles and hero numbers, and mono digit cells for tabular counters (no `tnum`) | S | Low (third-party IDs; verify) | Montserrat or Sarpanch (built-in families) |

**Details and notes on the big ones**

1. **Realm backdrop in 3D (idea 1).** This is the single biggest jump toward "unreal". The realm layers become
   `Part`s with Decals, each at its own depth, so parallax is real perspective with correct dolly zoom.
   - What it gains:
     - `DepthOfFieldEffect` softens far layers while you focus on nodes;
     - `BloomEffect` makes nebula cores and node lights glow;
     - `ColorGradingEffect` and `ColorCorrectionEffect` grade the scene per biome;
     - 3D `ParticleEmitter`s with `LightEmission=1` give true additive motes;
     - `Beam`s draw connections with glow;
     - Decals render up to **4K** with texture streaming, versus the 1024² cap on GUI images.
   - Nodes and plates can stay in ScreenGui, positioned via `Camera:WorldToViewportPoint` (as MarkerGui already
     does per camera frame), or become BillboardGuis to pick up bloom.
   - Risks:
     - tonemapped color shift (use `TonemapperPreset.Retro` or re-grade the art);
     - Decal texture budgets;
     - the REALM contract math must be re-expressed as a camera FOV and layer depths.
   - Prototype one biome first.
2. **Ornate relic panels (idea 2).** Paint the frame border once, white on transparent, with a transparent center,
   as a 9-slice with `SliceCenter` around the plain middle.
   - Layer stack, bottom to top:
     1. a UIShadow aura;
     2. a gradient-filled body Frame with a UICorner;
     3. a tile_noise grain at α 0.03;
     4. the ornament 9-slice tinted by the layer color;
     5. a **second copy of the ornament** tinted white with a UIGradient whose Transparency is a narrow band, with
        the band's `Offset` tweened across, which gives a light sweep clipped to the metal by the image alpha;
     6. corner "gem sockets" as small ImageLabels (or idea 3 on the hero panel).
   - Edges stretch, so design the ornament with its detail in the corners and smooth rails along the edges.
3. **Prestige hero moment in 3D (idea 5).** A Part is welded to the camera about 3 studs ahead, sized to the
   viewport via FOV math, and carries a SurfaceGui (FixedSize CanvasSize 1920×1080, `LightInfluence 0`,
   `Brightness 4`, `AlwaysOnTop = false`). Emitters and Beams go between it and the camera.
   - The HUD ScreenGui stays on top.
   - Put interactive SurfaceGuis in PlayerGui with `Adornee` set.
   - Test on a quality 1 phone, where bloom is gone, so the 2D fallback must still read well.
4. **UI particle pool (idea 4).** The module surface:
   - `Fx.burst(kind, atPos, n)` and `Fx.stream(pathOrRect, rate)`;
   - kinds are defined as atlas region + lifetime + curves (lookup tables);
   - one PreRender loop over live particles.
   - Keep it in `FxGui` (DisplayOrder just above PanelGui) so it never dirties panel caches.
   - Tier caps come from `Sprites.tier` and Motion.reduced().

---

## Sources

Official announcements and docs:
- Upgraded UI Gradients (Studio Beta, 2026-09-02): https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594 (pages 2–5 for the staff notes on radius `(w+h)/4`, the 1:1 aspect and elliptical plans)
- Shadows and individual corners (full release 2026-06-23): https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263
- UIStroke improvements (full release 2025-12-04): https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036
- Clipping for rotated elements and Path2D: https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864
- UI Styling full release (2026-01-20): https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082 · Styling Transitions (2026-07-27): https://devforum.roblox.com/t/full-release-styling-transitions/4646870 · https://create.roblox.com/docs/ui/styling
- Haptics full release: https://devforum.roblox.com/t/full-release-you-can-now-publish-haptic-effects-in-your-experience/3660577
- InputActionLabel (Studio Beta 2026-08-06): https://devforum.roblox.com/t/studio-beta-no-code-hotkey-hints-with-inputactionlabel/4779420
- Advanced Video API (Studio Beta): https://devforum.roblox.com/t/studio-beta-advanced-video-api-synchronize-video-control-3d-audio-and-more/3972775 · Video frames doc: https://create.roblox.com/docs/ui/video-frames
- CanvasGroup beta (texture semantics): https://devforum.roblox.com/t/canvasgroup-beta-group-transparency-on-ui-groups/1797885 · Class docs: https://create.roblox.com/docs/reference/engine/classes/CanvasGroup
- ViewportFrame docs: https://create.roblox.com/docs/reference/engine/classes/ViewportFrame · https://create.roblox.com/docs/ui/viewport-frames
- Static UI performance (render cache): https://devforum.roblox.com/t/static-ui-performance-improvements/222557
- Draw-call batching order: https://devforum.roblox.com/t/renderer-doesnt-batch-drawcalls-if-ui-elements-arent-parented-in-order/2740804
- Brightness for 3D GUIs: https://devforum.roblox.com/t/new-brightness-property-for-3d-guis/1283855 · SurfaceGui docs: https://create.roblox.com/docs/reference/engine/classes/SurfaceGui
- 4K texture rendering: https://devforum.roblox.com/t/4k-texture-rendering/4316229 · Texture streaming: https://devforum.roblox.com/t/introducing-texture-streaming/4144855
- Mobile UI texture compression (staff reply): https://devforum.roblox.com/t/compression-of-pixelated-imagelabels-on-mobile-unavoidably-ruins-our-games-aesthetic-graphics/2506241
- Rich text: https://create.roblox.com/docs/ui/rich-text · OpenTypeFeatures: https://devforum.roblox.com/t/introducing-opentypefeatures/3065736 · Font datatype: https://create.roblox.com/docs/reference/engine/datatypes/Font
- Path2D: https://create.roblox.com/docs/reference/engine/classes/Path2D · https://devforum.roblox.com/t/path2d-full-release/3027288
- EditableImage: https://create.roblox.com/docs/reference/engine/classes/EditableImage
- TweenService (SmoothDamp): https://create.roblox.com/docs/reference/engine/classes/TweenService · RunService: https://create.roblox.com/docs/reference/engine/classes/RunService
- GuiObject / ImageLabel / ScreenGui / UIGradient / UIShadow class docs: https://create.roblox.com/docs/reference/engine/classes/ (the `.md` variants under `/docs/en-us/reference/engine/classes/<Class>.md`)
- 9-slice: https://create.roblox.com/docs/ui/9-slice

Community:
- CanvasGroup memory: https://devforum.roblox.com/t/using-many-canvasgroups-is-unworkable-until-proper-memory-management-methods-are-implemented/3502537 · quality at low graphics: https://devforum.roblox.com/t/canvasgroup-makes-its-content-low-quality-at-certain-sizes-and-graphics-level-3-or-below/2946471 · ResolutionScale: https://devforum.roblox.com/t/canvasgroup-resolutionscale-property/3256004
- ViewportFrame limits: https://devforum.roblox.com/t/viewportframe-upgrades/3953219 · particles: https://devforum.roblox.com/t/add-support-for-particle-emitters-in-viewportframes/4706068 · LOD and quality: https://devforum.roblox.com/t/viewport-quality-differences/3887761
- SurfaceGui color accuracy: https://devforum.roblox.com/t/color-accuracy-for-lightinfluence-0/4817335 · glow needs quality > 1: https://devforum.roblox.com/t/surfacegui-glowing-effect-doesnt-work/3602752
- Blend mode requests: https://devforum.roblox.com/t/add-blend-modes-to-all-roblox-gui-objects/349549
- Liquid glass hack: https://devforum.roblox.com/t/%F0%9F%9B%A0%EF%B8%8Fliquid-glass-ui-blur-is-a-thing-of-the-past%F0%9F%9B%A0%EF%B8%8F/4416219 · GlassmorphicUI: https://github.com/sasial-dev/GlassmorphicUI
- UI particles: https://devforum.roblox.com/t/uiparticle-a-ui-particle-emitter/1831434 · https://devforum.roblox.com/t/2d-particle-emitter/3626045 · spr: https://github.com/Fraktality/spr
- 3D UI: https://devforum.roblox.com/t/parallax-corrected-3d-surfaceguis/3148539 · https://devforum.roblox.com/t/roblox-guide-3d-gui/2930494
- Cloud font IDs (third-party list): https://bloxodes.com/catalog/roblox-font-ids · font list generator: https://github.com/cxmeel/roblox-font-list-generator
- Figma pipelines: https://devforum.roblox.com/t/figbloxui-%E2%80%94-figma-to-roblox-ui-in-seconds/4446977 · https://github.com/xtrair/figma-to-roblox-ui
