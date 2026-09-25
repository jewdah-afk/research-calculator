# The Milestone Tree NG+: master build plan ("the unreal pass")

State: 2026-09-25. This plan merges the approved UI plan (ornate relic UI, the M/P/CR approval gate), the user's
additions A to F (2.5D realm, procedural everything, weather, tutorial and Guide, trailer, picture updates, Figma in
four roles) and the knowledge library in `docs/roblox-knowledge/*.md`. The library is the authority on what Roblox
can do. Each claim below cites its file (`r3d` = rendering-3d, `rc` = runtime-content, `ui` = ui-tech, `au` = audio,
`pf` = platform, `ob` = onboarding-publishing, `fg` = figma). Anything marked **[U]** still needs a Studio test before
we rely on it.

Status going in:
- Step 0 is done: app-shell step 3 is committed, and Export, Import and Hard Reset are removed.
- W1 (the ornate UI) is in progress. `art/ui/` holds the kit, pieces, sfx and sample renderers, uncommitted.
- Radial and conical gradients are switched off by `src/shared/Flags.luau`.

---

## 1. Vision

The Milestone Tree is a cosmic relic that lives, answers what you do, and keeps growing. The painted realm moves out
of the flat ScreenGui into a real 2.5D diorama in Workspace. There the engine's HDR, bloom, depth of field, lights,
particles and beams all apply to it (`r3d` §0.1, §7.3). The UI on top is carved from dark crystal and gold. Unlocking
a layer grows the tree, a reset changes the weather, the sky is a fractal that never repeats, and the score adds an
instrument for every layer you wake. Everything expensive is computed once, progressively, and then animated cheaply
(`rc` §4.6). Every effect has a baked fallback, so a 2 GB phone still gets a beautiful game and a gaming PC gets one
that makes people ask how it runs on Roblox.

### The 10 signature moments

| # | Moment | When the player sees it | What makes it possible |
|---|---|---|---|
| 1 | **The tree grows a branch.** A luminous branch grows from the trunk to the node that just woke, over about 2 s. Crystal buds open along it, the node's gem ignites and real bloom washes over the canopy. | A layer unlocks | Space colonisation seeded by UserId (`rc` §6.3). Tapered EditableMesh ribbons in Neon grown with `BatchSetValues`. The link becomes a Beam whose texture flows toward the child node. Offline-baked branch meshes stand in when the owner is not ID-verified. |
| 2 | **Every reset brings weather, and the Multiverse brings a storm.** Examples: amethyst leaf gusts shake the canopy, ice rain ripples on the island, an ember storm. Crossing the rift sets off forked green-and-crimson lightning around it, with thunder that lands on the music's downbeat and raindrops on the "lens" that bend the realm behind them. | A player-initiated prestige; a Multiverse crossing | Emitters with `Squash` and `GlobalWind` gusts. Beam lightning at `Brightness` 10 with a bloom spike and a light flash (`r3d` §5.2, Duvall Drive). Thunder scheduled with `Play(atTime)` (`au` §3.2). Glass droplet caps in front of the camera (PC). |
| 3 | **Crystal panels refract the living realm.** An open panel is a faceted crystal slab. The moving realm behind it bends through the facets, a light sweep runs along the gold filigree, and the realm behind comes into focus on the selected node. | A panel opens | A faceted Glass MeshPart locked to the camera behind the ScreenGui panel's rect: real refraction on PC (`r3d` §4.1). A DOF focus pull on PC at quality ≥ 8. A white duplicate of the ornament with a UIGradient sweep (`ui` §10 idea 2). Phones get a pre-blurred realm. |
| 4 | **A fractal sky that is never the same twice.** The nebula resolves from coarse to fine behind the splash, drifts, breathes with the bass line and is re-rendered for each NG+ era and each Multiverse crossing. | Joining; a new era | Domain-warped fBm stored as a u8 field and palette-cycled (`rc` §6.4, §5). Shown through a SurfaceGui with `Brightness` > 1, so it blooms (`r3d` §0.2). |
| 5 | **The rift is a live Julia set.** The Multiverse portal is an animated Julia fractal with glowing orbit-trap filaments. Its c parameter orbits slowly and bends toward the cursor on hover. A ForceField tear shimmers around it. | The Multiverse gate; the portal | 96² Julia with ¼ interlacing, about 1.5 ms a frame (`rc` §6.1). ForceField material on a noise-textured mesh (`r3d` §4.1). |
| 6 | **Prestige develops like a photograph.** The first prestige of a layer plays a frame flare, a shockwave and a camera punch-in with a bloom and colour-correction spike. Then a fractal flame seeded by (layer, prestige count) develops behind the hero. It is the player's own memento and stays in that panel. | First prestige per layer; later prestiges play the residual version | Chaos-game accumulation at about 14k points a frame, tone-mapped every 15 frames (`rc` §6.2). The Cine kit (§3 W3). |
| 7 | **Ray-traced gems.** Each node's gem is ray-marched once when it unlocks: a faceted SDF crystal with dispersion and iridescence. On PC, hovering a gem makes the light follow your cursor across its facets. | A node unlocks; hover | SDF raymarch of 64² per gem into the gem atlas; hover re-render at ¼ interlacing (`rc` §6.8, idea 11). |
| 8 | **Corruption is alive.** In the corrupted biome, reaction-diffusion "malware" crawls across the CR and CM surfaces from where you clicked INFECT. The CR panel shows CRT scanlines and VHS tearing, green lightning cracks the sky, and the music picks up a flanger and bitcrush send. | Panning to the outcrop; CR/CM panels; INFECT | Gray-Scott at 64², 4 steps a frame (`rc` §6.6). A `ColorGradingEffect` Retro flash. Zone FX sends (`au` §10 idea 7). |
| 9 | **The realm plays the music, and the music plays the realm.** Fireflies, the speed of the link energy, the nebula's breathing and the node rims ride the spectrum. Purchases climb a pentatonic arpeggio in the score's key, and the score gains a stem for each layer you wake. | Every session | `AudioAnalyzer:GetSpectrum()` (`au` §7.6). Sample-aligned stems via `GetMixerTime` (`au` §3). |
| 10 | **A firefly teaches you.** On a first run, a real 3D wisp with a trail and its own light flies out of the tree, circles the M shrine, lands on the button to press and then "dives through the glass" into the UI as a sprite. It never blocks you, and Skip is always there. | The first 5 minutes | A 3D wisp (Attachment + Trail + PointLight) handed off to a spotlight overlay (`ob` §7.1 recipe B). An 8-beat, state-driven tutorial (`ob` A). |

---

## 2. Architecture

### 2.1 Two render worlds, one camera contract

```
Workspace.MT_Realm (client-cloned; not streamed)       ScreenGuis (never post-processed; ui §0.4)
  planes at depth D/f  ─┐                               RealmFxGui   1  vignette, letterbox, LOW droplets
  gems, branches, beams │  HDR scene                    NodeGui      2  projected hit rings, badges, locks (crisp)
  emitters, lights      │                               PlateGui     3  nameplates (the existing Plates)
  SurfaceGuis (EI)      │                               MarkerGui    5  edge markers (unchanged)
  Glass panel slab     ─┘                               HudGui 10 / TopbarGui 12 (HUD split static/animated)
        │ post chain (client-local Lighting)            PanelChrome 20 / PanelValues 21 / PanelFx 22
        ▼ Bloom → CC → DOF (PC) → SunRays (PC)          GuideGui    25  spotlight, pointer, cards
   (AlwaysOnTop billboards) → ScreenGuis on top          OverlayGui 30 / FlashGui 40
```

- **The camera contract does not change.** Every layer sits at depth `d_L = D/f`, and zoom z moves the camera to
  distance `D/z`. That reproduces REALM's dolly law `s_L = z/(f + (1−f)z)` and its pan law exactly (`r3d` §7.3).
  `MapCamera.luau` stays pure and keeps its tests.
- **Constants [U, to confirm in the spike]:**
  - `k` = 100 world px per stud, so the world plane is 38.4 × 25.6 studs;
  - `D` = 16 studs;
  - the vertical FOV is `2·atan(V.h / (2kD))`, recomputed when the viewport changes (about 37° at 1080 map pts).
  - Depths: clouds 133, far 64, mid 35.6, near 22.9, world 16, fg 12.3, particles 10 studs.
- **Proxy rule.** A plane whose true distance is over 200 studs is drawn at 200 studs, scaled by `200/d_true`. The
  projection is identical, and it costs 2 writes a camera frame. The sky (f = .05, true depth 320) is always a proxy.
  This keeps the whole diorama inside the low-quality draw distance (`r3d` §0.14).
- **World ↔ screen stays analytic.** The world plane projects exactly as `q = Vc + z(p − C)`, so Nodes, Plates,
  Markers, the Guide spotlight and `worldToAbs` keep their maths. `Camera:WorldToViewportPoint` is only a debug
  cross-check.
- **Side sheet (the DESIGN §3.6 strip).** The 3D view always fills the screen, and the crystal panel is translucent
  over it. The strip becomes a camera offset: `C3 = C − (Vc_strip − Vc_screen)/z`. Clamps and zMin use the full
  screen, and the fly-to frames the strip. The lateral slip this gives the other layers is the "lateral dolly" DESIGN
  §3.6 already accepts.
- **Camera rig (`Realm3D/Cam3D`).**
  - It is bound at `RenderPriority.Camera` and sets the camera straight on (`CFrame.lookAt`).
  - It writes `Camera.Focus` every frame, which lights need (`r3d` §2.3).
  - Shake, FOV punch and dolly are composed after the base CFrame. Only the 3D view moves; the HUD never shakes.
  - A FOV punch with fixed plane depths reads as a dolly-zoom, which is intended.
- **Input does not change.** `MapInput` still reads `UserInputService` in screen space and calls `view:setCamera`.
  Node taps hit invisible buttons in NodeGui, placed with the analytic transform. That keeps the drag threshold,
  `InputSink = None`, gamepad selection and the Guide's GuiObject targets. Raycast picking is not needed.
- **Lighting is owned by the client.** A LocalScript builds the Lighting preset and the post effects. They are local
  by nature (`r3d` §2.2). `ColorGradingEffect` must sit under Lighting. Transient flashes go on the Camera.
- **The Backing gui** (black, DisplayOrder −1) exists only in SAFE 2D mode. In 3D mode it would hide the world.

### 2.2 Where each existing module changes

| Module | 3D mode (ULTRA / HIGH / MEDIUM / LOW) | SAFE mode (2D) |
|---|---|---|
| `Map/MapCamera` | Unchanged. Adds pure helpers `fov(V)`, `camCFrame(C, z)` and `proxy(d)` | Unchanged |
| `Map/MapView` | Its public API becomes the `RealmView` interface (setCamera, flyTo, frameStart, setRect, worldToAbs, setTier, setReduced, step, cameraChanged). A new backend, `Realm3D/RealmView3D`, implements it | This is the SAFE backend, as today |
| `Map/MapInput` | Unchanged. The "Box" is the free rect | Unchanged |
| `Map/Nodes` | The state machine is unchanged. It drives `Realm3D/Gems` (3D gem, glow, rays, aura) and `NodeChrome` (the ScreenGui hit, ring, lock, badge and challenge chip) | `NodeWidget` as today |
| `Map/NodeWidget` | Split into its chrome part (kept, now in NodeGui) and its visual part (moved to 3D) | Unchanged |
| `Map/Links` | Moves to `Realm3D/Branches`. Each cubic Bézier in `edges.json` maps **exactly** onto a Beam (A0 +X toward P1 with `CurveSize0 = |P1−P0|`, and the same at the other end). Lit links get a core beam plus a flow beam. Locked links get a dotted `Wrap` texture. Grown filaments come from W3 | Path2D stacks as today |
| `Map/Fields` | Moves to `Realm3D/Motes`: ParticleEmitter volumes at the true depths. The per-frame Lua cost drops to 0 (`r3d` §12 idea 5) | Pooled 2D fields |
| `Map/Ambient` | Translated per group (table in W2): light-falls become Beam stacks, shooting stars and embers become emitters, the rift ring becomes a ForceField mesh, crystal glints become Random flipbooks. Biome recolouring moves to `Realm3D/Grade` (ColorCorrection plus per-plane `EmissiveTint`) | Tweened sprites |
| `Map/Plates`, `Map/Markers` | Unchanged ScreenGuis. Hero labels can use a BillboardGui with glow (`r3d` §12 idea 14) | Unchanged |
| `Hud/*` | The same trees, reskinned by W1. Portal gets a window onto the Julia rift (an ImageLabel over the Live atlas). Static and animated parts go in separate ScreenGuis | Same |
| `Panel/*`, `Render` | PanelGui is split into Chrome (static), Values (numbers at ≤ 5 Hz) and Fx (animated), so a sparkle never re-tessellates the cards (`ui` §0.5, §7.1). The crystal body is translucent over the Glass slab on ULTRA and HIGH | Opaque body plus a pre-blurred realm |
| `Panel/Hero` | `Hero.juice` calls `Realm3D/Cine` (bloom and CC spike, punch-in, 3D burst) and the flame memento (W3) | 2D juice (W1 Vfx) |
| `Overlay/*` | Gains `Guide.luau` (W5). `flash` becomes a 3D bloom/CC spike plus a UI flash | UI flash |
| `App` | Chooses the backend. The Backing gui is SAFE-only. The one PreRender loop now runs input → view → Realm3D → Proc scheduler → Motion → Audio feed, with the Governor every 2 s | as today |
| `Core/Prefs` | `detail` = AUTO / ULTRA / HIGH / MEDIUM / LOW / CLASSIC. New keys: `weather`, `guide`, `music`, `sfx`, `ambience`, `seenPrestige` (all validated on the server) | same keys |
| `Core/Theme` | caps gain `editable`, `realm3d` and `glass`. The tokens come from the generated `ThemeTokens.luau` (W7) | same |
| `shared/Flags` | Gains `REALM3D`, `GLASS`, `LIVE_PROC` and `WEATHER`. A server-published ReplicatedStorage attribute can override them, so a feature can be switched off without a client update (`ui` §9.1) | same |
| `shared/Realm.luau` | Stays generated, with `k`, `D`, the depths and the proxy threshold added (`art/roblox/realm_luau.js`) | same |

### 2.3 How the painted planes stay true to the art

Painted art is pre-lit, so it has to render unlit or it gets lit twice (`r3d` §6). The W2 spike picks one of three
paths with a colour-card test (a grey ramp plus the 21 layer hues, compared against `compose.js`):

| Path | How | Pros | Cons |
|---|---|---|---|
| **A (preferred)** | A MeshPart with a SurfaceAppearance (ColorMap = tile, EmissiveMask = a shared white 4×4, strength 1) and a dark realm Lighting. Output ≈ ColorMap (`r3d` §4.3) | Per-layer grade through `EmissiveTint`, and HDR through `EmissiveStrength` > 1 for the light-falls, sun and rift. Works at every quality level. 4K plus streaming | SurfaceAppearance maps are plugin-only, so the kit is generated into the place file by the build (`art/roblox/realm3d_kit.js` → `Realm3DKit.model.json`) and cloned by the client [U: confirm that Rojo writes `*Content` map properties] |
| B | A Part with a Decal and fullbright Lighting | Scriptable at runtime | Hero meshes then can't be lit properly; decals don't batch |
| C | A SurfaceGui of ImageLabel tiles, `LightInfluence` 0 | Exact colours; `Brightness` gives HDR | Draw-call heavy; canvas memory; GUI 1024² cap |

The tonemapper's colour shift is corrected with a ColorCorrection preset or pre-compensated in the painter pass
(`r3d` §12 idea 2). EditableImage surfaces (sky, rift, corruption) always go through a SurfaceGui ImageLabel with
`LightInfluence` 0 and `Brightness` 1–3, which is the known-good route for an EditableImage (`rc` §2.2).

### 2.4 Quality tiers and the adaptive governor

The tier is seeded from `SavedQualityLevel`, `PreferredInput`, `ViewportDisplaySize` and `TouchEnabled` (`pf` §3.4).
The Governor then moves it at runtime. The player can pin a tier in Options → Map detail.

| Tier | Seeded when | Realm textures | Post FX | Procedural | 3D extras |
|---|---|---|---|---|---|
| **ULTRA** | Keyboard and mouse, `SavedQualityLevel` ≥ 8 (or Automatic with headroom) | "3D-XL" set (2048² tiles on world, mid and near; 4K where streaming allows) | Bloom, CC, SunRays, **DOF** | Live: animated sky, Julia rift, RD corruption, gem hover, flame | Glass panel slab, lens droplets, hero meshes |
| **HIGH** | PC default, strong tablets | The current HIGH set (147 MB with mips) | Bloom, CC, SunRays | Sky computed once per era then palette-cycled; rift at 64²; flame | Glass slab |
| **MEDIUM** | Consoles, large-screen touch devices | World and mid from HIGH, the rest from LOW | Bloom, CC | Static bakes into the Still atlas only | none |
| **LOW** | Phones (`ViewportDisplaySize` Small, touch without a keyboard), `SavedQualityLevel` ≤ 3 | The current LOW set (34 MB) | Bloom (low fidelity), CC | None; baked PNGs from the same generators | none |
| **SAFE** | The 3D self-test fails, the governor bottoms out, or the player picks CLASSIC | The existing 2D MapGui | none | none | none |

**Governor (`Realm3D/Governor`).**
- **Every 2 s** it takes an EMA of `Stats.FrameTime`, `RenderGPUFrameTime`, `RenderCPUFrameTime`,
  `SceneDrawcallCount` and `GetTotalMemoryUsageMb` (`r3d` §8.1, `pf` §3.3).
- **Step down** after 3 windows over 1.15 × target.
- **Step up** only after 30 s under 0.75 × target, and never above the seeded ceiling.
- **Order of knobs:**
  1. particle Rate × 0.5;
  2. SunRays off;
  3. DOF off;
  4. Glass slab off;
  5. live EditableImage animation frozen;
  6. secondary beams off;
  7. texture set down one step;
  8. SAFE.
- **Memory guard:** above 1.1 GB total on touch devices, drop one texture step.
- A `nil` from an EditableImage create switches that surface to its bake.
- Tier changes are logged to analytics (W9).

### 2.5 The EditableImage atlas scheduler (`Realm3D/Proc/Atlas`)

Constraints: one displayed EditableImage refreshes per frame (`rc` §0.4), a budget of about 32 MB shared with meshes
(§0.3), and client Luau is interpreted (§0.6).

- **Probe once** (`Theme.caps.editable`, `rc` §1). Studio always passes, so a debug chip shows whether players get the
  live path or the baked one.
- **Two 1024² atlases (8 MB):**
  - **Live** (animated):
    - sky field 512² (256² on HIGH);
    - flame 256²;
    - Julia 128²;
    - RD 64² (stretched by bilinear filtering);
    - READY metaball aura 64²;
    - gem hover 64².
  - **Still** (written once per event):
    - 21 layer crystal textures, 128² each;
    - gem atlas 21 × 64²;
    - glow stamps;
    - the personal sigil.
- **Each frame:**
  1. **Compute.** Run jobs until the slice is spent: 2 ms on desktop, 1 ms on phones, measured with `os.clock()`.
     This is pure buffer maths. Strip Actors are optional, and the image write stays serial (`rc` §4.4).
  2. **Write Live.** At most one `WritePixelsBuffer`, and only the dirty rows of the highest-priority region. The
     other regions go round-robin at their own rate: sky palette 20 Hz, Julia 30 Hz, RD 15 Hz, aura 10–15 Hz.
  3. **Write Still** only on a frame with no Live write.
- **Surfaces show windows** of the atlas: `ImageRectOffset`/`Size` on SurfaceGui (3D, bloom) and ScreenGui (panel
  hero) ImageLabels.
- **Gating.**
  - Jobs pause while their surface is off screen or covered.
  - ReducedMotion freezes the last frame.
  - Seeds (UserId, layer, prestige count, era) live in the save, never the pixels.
- **Offline twin.** Every generator is pure Luau (buffer in, buffer out) in `src/shared/Proc/`.
  `art/proc/bake.js` runs the same code with the `luau` CLI at 2048² and 4K. That gives the LOW and unverified
  fallbacks and the marketing art (`rc` idea 16).

### 2.6 Audio graph (`Core/Audio`, client-only; `au` §7.1)

```
Music stems ─► per-stem AudioFader ─► Music bus ─┐              ┌─► AudioAnalyzer (pre-slider tap) ─► reactive feed
Ambience/Weather loops ─► Ambience bus ──────────┼─► Duck (AudioCompressor, Sidechain ◄─ Impacts + UI)
UI kit (voice pools) ─► UI bus ─────────────────────────────────┼─► Master fader ─► AudioLimiter (−1 dB) ─► DeviceOutput
Impacts (prestige, thunder) ─► Impacts bus ─► Hall reverb send ─┘
Zone sends: Rift ─► AudioEcho · Corrupt ─► AudioDistortion + AudioFlanger (weighted by camera X, like the biome wash)
```

- `DefaultListenerLocation = None`.
- The bar grid `t0` comes from `GetMixerTime()`. Stingers, thunder and combo tails are quantised to it; click
  transients play at once (`au` §3.2).
- Voice pools: ≤ 32 voices on PC and ≤ 16 on phones. The spectrum is off on LOW (RMS only).
- This replaces the SoundGroup `Sfx.luau` sketch in Step 1b. The Options sliders become Music, SFX and Ambience.

### 2.7 Fallback matrix

| Feature | Owner not ID-verified | LOW (phone) | ReducedMotion | SAFE (2D) |
|---|---|---|---|---|
| Growing branch | Baked branch mesh per edge, Beam-wipe reveal | The same, no buds | Appears instantly | Path2D link lights up |
| Fractal sky | Baked sky per era (same generator) | Baked 1024² | Static | Painted sky tiles |
| Julia rift | Baked flipbook of 64 frames | Flipbook at 12 fps | Static frame | Portal sprite |
| Crystal panel | Glass slab still works (no EditableImage needed) | Pre-blurred realm image | Unchanged | Opaque body |
| Gems | Offline-raymarched gem atlas | The same | No hover | Node sprites |
| Weather | Unaffected (emitters and beams) | Lite preset (rates × 0.25, no droplets) | Lighting fade only | UI-only lite |
| Corruption RD | Flipbook | Flipbook | Static | Sprite |
| Flame memento | Curated baked flame per layer | The same | Shown fully developed | The same |
| Music-reactive | Unaffected | RMS only | Swing capped | RMS on UI glows |

---

## 3. Workstreams

### W1: Ornate relic UI (in progress: the look-samples approval gate)

| Deliverable | Files | Notes |
|---|---|---|
| Master kit plus the M, P and CR frames, tabs (both variants), the 3 card states, HUD plaque, dock and tray | `art/ui/{kit,pieces,themes,vfx,build}.js`, `art/ui/samples/*` | In progress |
| Approval pack: stills plus a ~3 s prestige clip with sound (big and residual) → the gallery's "Look samples" section | `art/ui/samples/render.js` | **Gate G1** |
| Upload and wire M, P and CR behind the fallbacks | `art/roblox/{tile,upload}.js`, `Assets.luau` (`ui` key) | UI budget: HIGH ≤ 40 MB, LOW ≤ 10 MB |
| After approval: `Sprites.slice`; the Recipes `frame`, `tabShard`, `relicCard`, `medallion` and `plaque`; the 32 flat-fill sites replaced | `Core/{Sprites,Recipes}`, `Panel/*`, `Hud/*`, `Overlay/*`, `Signatures/*` | Readability rules of DESIGN §9 |
| Research upgrades | Same | Listed below |
| `Core/Vfx.luau` (pooled UI particles, HIGH 120 / LOW 40) and the seenPrestige flag in Prefs | `Core/{Vfx,Prefs}`, server Prefs validation | Reduced motion shows a flash only |
| The other 18 layer frames and the package-J polish | `art/ui/frames/*`, Signatures | Phase 3 |

Research upgrades to fold in:
- Gold is kept separate from the tinted body: two stacked ImageLabels (`fg` §5.2).
- The light sweep runs on a white duplicate of the ornament, so it follows the filigree exactly (`ui` §10 idea 2).
- UIShadow auras (≤ 100 on screen) and layered-UIStroke neon rims.
- Styling Transitions for hover and press.
- PanelGui split into Chrome, Values and Fx.

### W2: The 2.5D realm conversion

| # | Deliverable | Files |
|---|---|---|
| 2.1 | **Spike (Gate G2).** World, sky proxy and `far` in Workspace behind `Flags.REALM3D`. Colour-card test A/B/C (§2.3). Pixel-match of the dolly law against `compose.js` stills at 6 rest poses. Draw calls and fps measured | `Realm3D/{RealmView3D,Cam3D,Stage}`, `art/roblox/realm3d_kit.js` |
| 2.2 | The `RealmView` interface. `MapView` becomes the SAFE backend, and `App` chooses | `Map/MapView`, `App` |
| 2.3 | All 7 painted planes, the proxy rule, idle-when-covered (emitters off, camera parked; `r3d` §12 idea 19) | `Realm3D/Stage` |
| 2.4 | Tiler "3d" profile (2048² for ULTRA, the current HIGH and LOW sets otherwise) and one shared plane mesh, so the planes instance | `art/roblox/tile.js`, `upload.js`, `Assets.luau` |
| 2.5 | `Realm3D/Grade`: Lighting presets (tree, rift, corrupt, eras) weighted by REALM §5 biome weights; Bloom threshold ≈ 1.05 so only HDR sources glow (`r3d` §12 idea 3) | `Realm3D/Grade` |
| 2.6 | Gems: a Blender faceted gem mesh (`art/ui/blender`), a SurfaceAppearance with an emissive mask (`EmissiveStrength` pulses READY), one re-adorned Highlight for hover and selection | `Realm3D/Gems`, `Map/Nodes`, `Map/NodeWidget` (chrome split) |
| 2.7 | Branches: exact Bézier Beams, flow textures, the unlock wipe (≥ 20 segments against Beam LOD) | `Realm3D/Branches` |
| 2.8 | Motes: emitter volumes. The Ambient translation table below | `Realm3D/{Motes,Ambient3D}` |
| 2.9 | Panel coexistence: the strip camera offset, the fg fade, a Camera `BlurEffect` backdrop on COMPACT | `Realm3D/RealmView3D`, `App` |
| 2.10 | Tests: `unit/cam3d.luau` checks a pinhole projection against camera.js at 400 zooms × 8 layers, including the proxy. Mock-engine stubs for Camera, MeshPart, Beam and ParticleEmitter. `client_smoke` runs in both backends | `port/tests/*` |

Ambient translation:

| Sprite group | In 3D |
|---|---|
| Light-falls | Beam stacks (3–5), vertical transparency ramp, slow `TextureSpeed` |
| Shooting stars | An emitter with `Squash`, `LightEmission` 1 |
| Embers | An emitter plus GlobalWind drift |
| Rift ring | A ForceField mesh plus a PointLight |
| Crystal glints | A Random flipbook, `FlipbookStartRandom` |
| Clouds | 2–3 spinning nebula discs, Duvall-style (HIGH and up) |

### W3: Procedural systems

| # | Deliverable | Files | Depends on |
|---|---|---|---|
| 3.0 | Proc core: pure generators (noise, palette, fBm, Julia, flame, Voronoi, RD, SDF, colonise, L-system), the atlas scheduler, the caps probe, the offline bake | `src/shared/Proc/*`, `Realm3D/Proc/Atlas`, `art/proc/bake.js` | none |
| 3.1 | **Growing tree** (moment 1): attractors along the `edges.json` curves plus the node, seeded by UserId. Segments with birth times become EditableMesh tapered ribbons (Neon, ≤ 20k triangles); crystal buds are instanced MeshParts. On join, rebuild without animation | `Realm3D/Tree` | 2.7, 3.0 |
| 3.2 | **Fractal sky** (moment 4): 512² or 256² field, coarse-to-fine behind the splash, palette cycle plus drift, re-rendered and cross-faded for each era or crossing | `Realm3D/Sky` | 2.3, 3.0 |
| 3.3 | **Crystal materials** (moment 3): Voronoi F2−F1 per-layer textures in the Still atlas, used by the W1 frame bodies and gem inlays; the light sweep is a LUT rotation on the open panel. **Glass slab:** a faceted MeshPart locked to the camera, sized to the panel rect by FOV maths | `Realm3D/{Crystal,Glass}` | W1 integration, 2.9 |
| 3.4 | **Reactive VFX:** Julia rift (moment 5), RD corruption (moment 8), READY metaball aura, curl-noise aurora (T), ripples (P rain) | `Realm3D/Proc/*` | 3.0 |
| 3.5 | **Ray-marched gems** (moment 7): rendered at unlock into the gem atlas for NodeChrome, the tray and the panel emblem; PC hover re-render | `Realm3D/Proc/GemRay` | 2.6 |
| 3.6 | **Prestige cinema** (moment 6): the `Cine` kit (dolly, FOV punch, trauma² shake, bloom/CC spikes, letterbox) plus the flame memento | `Realm3D/Cine`, `Panel/Hero` | 2.5, 3.0 |
| 3.7 | **Retro FX**, only in the corrupted biome and in glitch events: VHS tear strips (UI clones with offset and chroma), CRT scanlines (Pixelated tile), a Retro tonemapper flash, glitch lightning | `Signatures/{Cp,...}`, `Realm3D/Retro` | W1 |

### W4: Weather on reset

- **Trigger.** Session emits an `fx` event `{layer, first}` only on player-initiated resets (a button, a hold or a
  hotkey). Automation never triggers weather.
  - The cooldown is 120 s, set by a ConfigService key.
  - The first prestige of a layer always plays.
  - The setting is in Prefs as `weather` = OFF / RESETS (the default) / AMBIENT.
- **Presets** (`Realm3D/Weather/<preset>.luau`, one data table each, 8–15 s):

| Preset | Content |
|---|---|
| M | Amethyst leaves on curl-noise gusts; canopy sway |
| P | Ice rain with `Squash`; SurfaceGui ripples on the island |
| SP | Ember storm |
| T | Golden aurora made of Beam stacks, plus shooting stars |
| EX | Wind that sweeps the clouds (GlobalWind, disc spin) |
| CR/CM | Glitch storm: VHS tearing, green lightning |
| Multiverse | Lightning storm around the rift, with rain |

- **Tech.**
  - Emitters with `WindAffectsDrag`.
  - Lightning from midpoint displacement with branches (Beams at `Brightness` 10, a PointLight flash, a bloom spike).
  - Fog and CC grade shifts.
  - Canopy sway: an EditableMesh grid on the `fg` and `near` planes (plane bob as the fallback).
  - Lens droplets: Glass caps on ULTRA, UI sprites otherwise.
  - Thunder is scheduled on the bar grid, delayed by the strike's distance.
- **Budgets** follow §5. ReducedMotion fades the lighting only.
- **Files:** `Realm3D/Weather/*`, `Core/Prefs`, `Signatures/Options` (setting row), `port/rbx/view.js` or
  `Session.luau` (`fx` events), `unit/weather.luau` (cooldown and trigger rules).

### W5: Tutorial and Guide (`ob` Opportunities A–E)

| Deliverable | Files |
|---|---|
| `rbx_guide()` → a 65-character condition vector plus the next goal; `v.guide` (parity-tested) | `port/rbx/view.js` |
| Edge detection, backfill on load (saves from before the Guide), the budget rules (1 visible, ≥ 45 s apart, ≤ 6 per 10 min), `rec.guide` in the save | `Session.luau`, `Store.luau` |
| Analytics: the onboarding funnel (10 steps), `MilestoneRoad`, `PrestigeUniverse`, custom events, called after `task.synchronize()` (Actor) | `Worker.server.luau`, `Session.luau` |
| `Overlay/Guide.luau`: spotlight recipe B (a 9-slice ring plus 4 blocking buttons), a Path2D pointer, card and chip; the Guide log ("?" on the dock) | `Overlay/Guide`, `Hud/Dock`, GuideGui |
| The 8-beat tutorial with Skip; replay from Options | `Overlay/Guide`, `Signatures/Options` |
| **Wisp** (moment 10): a 3D firefly with a trail and a light, following Bézier flights; hands off to a UI sprite for panel targets | `Realm3D/Wisp` |
| Strings table `GuideText` (localisation-ready); Config keys `guide_budget_gap_s`, `guide_budget_10min`, `tut_idle_hint_s` | `src/shared/GuideText.luau` |
| Tests: view parity, a session edge and budget unit test, client smoke with the Guide ON and OFF | `port/tests/*` |

The Guide never repeats what the game already signals (READY, CAN BUY). Guide OFF means no spotlights, arrows,
coach marks or goal chip.

### W6: Audio and music

| Deliverable | Files |
|---|---|
| The bus graph (§2.6), Options sliders, Prefs keys | `Core/Audio`, `Core/Prefs`, `Signatures/Options` |
| UI kit: the 12 Step 1b sounds with 3–5 variants each, packed into 1–2 sprite-sheet assets, played with `PlaybackRegion` | `art/ui/sfx/*`, `art/audio/pack.js` |
| Score v1: synchronised stems for Tree, Rift and Corrupt, plus progress stems (bass → arpeggio → choir → celesta) and a prestige riser | `art/audio/score/*`, `src/shared/AudioIds.luau` |
| The prestige chain: duck, a Lowpass24 sweep, a 0.4 s tape-stop, a stinger on the next downbeat | `Core/Audio` |
| The combo arpeggio (pentatonic, a pool of 6, rate cap) | `Core/Audio` |
| Weather audio: rain and wind loops, 5 thunder variants | `art/audio/weather/*` |
| Reactive feed: bass onset and RMS → `Realm3D` parameters | `Core/Audio`, `Realm3D/*` |
| Pipeline: loudness-normalise (−16 LUFS, −1 dBTP), upload as the game's owner, a manifest (audio can't be updated in place) | `art/audio/upload.js` |

### W7: Figma in all four roles (file `o9LP1hGo5A8exWLR28mASJ`)

| Role | Deliverables | Tools and limits |
|---|---|---|
| **Hygiene first** | Remove the 8 unrelated libraries. Bind the Foundations fills to variables. Refresh the Map page to the 7-plane realm (`upload_assets` of the renders) | `use_figma`, `get_libraries` |
| **Living source of truth** | Variable collections Base, Layer, Tier, Motion and Material, with Luau paths in the code-syntax field. `art/figma/tokens.js` reads them through `use_figma` and generates `Core/ThemeTokens.luau`; a `--check` step fails CI when that file is stale. A `Relic Frame` component set (Layer × State × Tier × Size, with a content slot). Screens and Overlays pages filled from the code-first mockups. A snapshot parity check (Studio `MT_Snapshot` against `get_screenshot`) | The Variables REST API is Enterprise-only, so everything goes through MCP (`fg` §0.4); 200 reads a day |
| **Art factory** | Our own shader suite: Relic Crystal, Neon Filament, Corruption, Cosmic Dust, Rune Ignite (`create_shader`). `art/figma/shaderbake.js` runs the WGSL in Playwright with SwiftShader WebGPU and outputs PNGs and flipbooks checked by `tile.js`. Weave, after the account is linked and each run is approved: Topaz upscale and Relight of hero art, Z-depth to split plates, image→3D for relic gems | Ship bakes of **our own** shaders only (`fg` §5.3 licence note); one animated shader per page |
| **Motion lab** | Timelines for prestige (big and residual), the branch grow, weather transitions, tutorial beats and panel open. `export_video` MP4s for approval. `get_motion_context` → `art/figma/motion2luau.js` → `Core/MotionSpecs.luau`, replayed by `Motion` (only whitelisted properties) | Motion is an open beta behind the `metronome` flag |
| **Marketing studio** | Icon master (1024, shipped at 512), 5 thumbnails at 1920×1080 with the key content in the top 80%, title and logo cards, 9:16 social cuts; Buzz bulk variants | Feeds W8 |

### W8: Trailer, thumbnails and publish kit

- **Director mode.** A Studio-only attribute runs `Realm3D/Cine` shot lists: scripted flights, state setups loaded
  from real saves, UI moments.
  - Capture paths:
    - (a) the user records with OBS, or with Studio freecam (Shift+P);
    - (b) stills through Studio MCP `screen_capture`;
    - (c) the in-house pipeline (`compose.js` + Playwright + ffmpeg) for 2D-exact shots.
  - Title cards come from Figma Motion.
- **Roblox video preview.**
  - Rules: ≤ 60 s, 16:9 1080p, MP4 H.264 at about 15 Mbps, < 100 MB.
  - No voice-over, no lyrics, no promotional text. Logo overlay allowed.
  - The hook comes before second 3: a claim cascade that pulls back to the glowing tree (the `ob` §F shot list).
- **Off-platform trailer** (30–60 s) and a 9:16 cut (15–30 s) with captions. **Our own music only** (`au` §6.6).
- **Icon.** The M crystal in the conical rift ring on the void. It must read at 150 px and at 50 px.
- **Thumbnails.** 5 scenes: GROW THE TREE, PRESTIGE, ENTER THE MULTIVERSE, FIX THE CORRUPTION, EXPLORE.
- **Description.** A hook of ≤ 160 characters.
- **Publish checklist.** Put it in `STUDIO_CHECKLIST.md` §Publish (the `ob` pre-publish list plus asset privacy).

### W9: Performance and QA

| Deliverable | Files |
|---|---|
| Governor (§2.4) plus a debug overlay: tier, fps, draw calls, EditableImage MB, which path is live | `Realm3D/Governor`, a debug chip |
| Telemetry: the `ClientPerf` custom event at 60 s and 10 min (log10 values, tier, input) sent through the server | `Session`, a remote |
| Unit tests: cam3d, atlas scheduler (slice, one write a frame), governor hysteresis, vfx pool caps, weather cooldown | `port/tests/unit/*` |
| **Real-engine CI:** Rojo build → Place Publishing API to a *test* place → the `roblox` suite through the Luau Execution API (plan for 2 concurrent tasks, 5 min each) | `.github/workflows/*`, `port/ci/*` |
| **Studio MCP visual QA** (from a local Claude Code session on the user's PC): `start_stop_play` → `execute_luau` flies to the 6 rest poses per tier → `screen_capture` → diff against `compose.js` | `port/qa/studio_mcp.md`, scripts |
| Device matrix: PC high and low, Mac, iPhone, a 4 GB mid Android, a 2–3 GB low Android, a tablet, Xbox; a 15 min thermal soak; F9 memory | `STUDIO_CHECKLIST.md` |
| An adversarial runtime review each phase (nil ids, budgets, ReducedMotion, SAFE path) | none |

Every push is tested in a clean worktree first, because the user's Studio auto-pulls. Flags stay OFF until their gate
is approved.

### W10: Launch and discovery

| Step | Detail |
|---|---|
| Rating | Maturity questionnaire: aim for **Minimal** |
| Kids & Select | Verification, 2FA, Plus/Premium or the fee, then **250 highly engaged plays in 60 days**. Until then the game is 16+ and absent from search and home (`pf` §2.9) |
| Asset privacy | Decide the owner (user or group) and turn on "Restrict on creation" **before** the final uploads; it cannot be undone |
| Soft launch | Private test place, then public. Watch the onboarding funnel in View Events; D1 and D7 by `GuideChoice` |
| Discovery | Video preview (3 uploads a month, and rejections count), 5 thumbnails with personalisation, social links, notification opt-in after the first offline claim, a `PromptShareCapture` button ("share my realm") |
| Ads (optional) | Plays goal, 5–10 creatives, pause the losers after 3–5 days; fix the FTUE first if D1 is weak. Search keywords: incremental, idle, prestige, milestone, skill tree |

### Dependencies and order

```
W1 gate G1 ──► W1 integration ──► W3.3 crystal panels ──► W1 remaining 18 layers
W2 spike G2 ──► W2 conversion ──► W3.1 tree · W3.2 sky · W3.5 gems · W3.6 cinema ──► W4 weather ──► W8 capture
W3.0 proc core ─────────────────┘                                        W6 bus ──► W6 score ──► W4 audio, W8
W7 hygiene + tokens ──► W7 motion lab (specs for W3.6, W4, W5) ──► W7 marketing ──► W8
W5 view/session ──► W5 overlay + wisp (needs W2.6 NodeChrome) ──► W10 funnels
W9 governor + tests run alongside every workstream; real-engine CI before Phase 4
```

---

## 4. Phases

Each phase ends with a Studio pull, a picture batch in the gallery artifact
(https://claude.ai/artifact/MDvgSUseDTdeKorPQUtUAF), and short clips only where motion matters.

| Phase | Scope | What the user sees in Studio | What gets sent |
|---|---|---|---|
| **1. Foundations and gates** | W1 samples (**G1**). W2 spike (**G2**). W3.0 proc core and offline bake. W6 bus graph and UI kit. W7 hygiene, tokens and look-dev board. W9 governor skeleton and new unit tests | Ornate M, P and CR panels behind the fallbacks. `Flags.REALM3D` preview: world, sky and far in 3D with real bloom on the node gems, next to the 2D map. UI sounds with sliders | G1: panel stills (tabs a/b, 3 card states), HUD stills, a 3 s prestige clip with sound. G2: 2D-vs-3D stills at 3 rest poses, the colour-card result, fps and draw calls. The first fractal-sky bake |
| **2. Core spectacle** | W2 full conversion and tiers. W3.1 tree, W3.2 sky, W3.3 crystal and Glass panels, W3.5 gems, W3.6 cinema and the flame memento. W1 integration of the kit infrastructure. W6 score v1 and the reactive feed. W7 motion specs for prestige and unlock | The full 3D realm on PC with auto tiers. Branch growth on unlock. Crystal panels refracting the realm. The big and residual prestige. The live sky and the Julia rift | Clips: branch grow (5 s), panel open with refraction (3 s), prestige big (4 s), sky resolving (4 s). Stills per tier (ULTRA, HIGH, LOW) |
| **3. Content and polish** | W1 remaining 18 layers and package-J polish. W4 all weather presets. W5 tutorial, Guide and wisp. W3.4 corruption, W3.7 retro. W6 full stems and weather audio. W7 shader suite and bakes. W9 device matrix and adversarial review | The first-run tutorial with the wisp. Weather on resets with the setting. The corrupted biome alive. The Multiverse storm. All 21 layers ornate | Clips: first minute of the tutorial (20 s), 4 weather presets (4 × 4 s), the Multiverse storm (6 s), CR corruption (4 s). A contact sheet of all 21 panels |
| **4. Publish** | W8 trailer, thumbnails and icon. W9 real-engine CI and telemetry. W10 launch steps. The final `STUDIO_CHECKLIST.md` | A published private place playing like Studio; the publish checklist | The video preview MP4, the trailer and 9:16 cut, 5 thumbnails, the icon at 512/150/50, and the checklist ready for the user to upload |

CHECKPOINT (addition A): once this plan is accepted, it is a good moment for the user to run /compact before Phase 1.

---

## 5. Budgets, risks and user-only actions

### 5.1 Budgets per tier

| Budget | ULTRA | HIGH | MEDIUM | LOW | Source |
|---|---|---|---|---|---|
| Client memory, total | ≤ 2.5 GB | ≤ 1.8 GB | ≤ 1.3 GB | ≤ 1.0 GB | `pf` §3.1 (1.3 GB for 2 GB phones) |
| Realm textures (with mips) | ≤ 250 MB (streamed) | ≤ 150 MB | ≤ 80 MB | ≤ 35 MB | REALM §1 |
| UI textures | ≤ 40 MB | ≤ 40 MB | ≤ 20 MB | ≤ 10 MB | approved plan |
| EditableImage + EditableMesh | ≤ 14 MB | ≤ 10 MB | ≤ 5 MB (Still only) | 0 | `rc` §0.3 (about 32 MB cap) |
| Proc CPU slice per frame | 2 ms | 2 ms | bakes at load only | 0 | `rc` §4.6 |
| Scene draw calls | ≤ 350 | ≤ 300 | ≤ 200 | ≤ 120 | `r3d` §0.9, §12 idea 15 |
| Beams (1 draw call each) | ≤ 80 | ≤ 60 | ≤ 30 | ≤ 15 | `r3d` §5.2 |
| Emitters / live particles | 40 / 2,500 | 30 / 1,500 | 20 / 700 | 12 / 300 (≤ 100 per second per emitter) | `r3d` §0.12 |
| Point lights (shadowless) | 8 | 8 | 4 | 2 | `r3d` §2.3 |
| Highlights | 1, re-adorned | 1 | 1 | 0 (ring sprite) | `r3d` §5.4 |
| 3D realm instances | ≤ 600 | ≤ 500 | ≤ 350 | ≤ 250 | none |
| UI particle pool | 120 | 120 | 80 | 40 | approved plan |
| UIShadow / UIStroke / UIGradient on screen | ≤ 100 / < 300 / < 1000 on every tier | | | | `ui` §7.3 |
| Panel / HUD instances | ≤ 450 / ≤ 80 on every tier | | | | DESIGN §17 |
| Audio voices | 32 | 32 | 24 | 16 | `au` §4 |
| Frame target | 16.7 ms; map + UI Lua ≤ 4 ms | | | | `pf` §3.1 |

### 5.2 Risks

| Risk | Mitigation |
|---|---|
| The Mesh / Image APIs toggle is off, or a device runs out of budget, so EditableImage and EditableMesh fail in the published game (the owner is ID-verified) | Every procedural surface has an offline bake from the same generator (§2.7). A debug chip shows which path is live |
| The painted art shifts colour in 3D (the tonemapper) | Colour-card spike (G2); correction LUT or pre-compensation; `EmissiveTint` per plane |
| Draw distance at low quality at far zoom-out | The proxy rule (≤ 200 studs); the SAFE backend |
| Glass hides translucent parts behind it, and there is no refraction on mobile | The slab sits only behind the panel rect; realm planes use cutout alpha; the pre-blurred fallback |
| DOF halos on SurfaceGuis; Beam LOD at quality 1 | DOF on ULTRA only; ≥ 20 beam segments, links kept near the focus |
| Studio flatters Luau (native code there, the interpreter on clients) | Measure with `--!native` removed and with `luau -O2`; phone MicroProfiler (`rc` §4.3) |
| One EditableImage update a frame | The atlas scheduler; static content written once |
| Spectacle fatigue | Big moment first time only, residual after; weather cooldown; settings for Weather and Motion |
| Beta features: UI gradients, Figma Motion, shaders, Weave | Flags with a server override; Figma only for look-dev, and bakes are the product |
| Audio: quota, moderation, an Audible Magic false positive, no in-place updates | Sprite sheets; the manifest; upload as the owner; keep the project files as proof |
| Music licensing for the trailer | Original music only off-platform (`ob` §14) |
| A rejected video preview still burns quota | Review against the allowed and rejected lists before uploading |
| Regressions in the parity-tested port | The SAFE path and every existing test stay; flags default OFF; clean-worktree tests before each push |
| Mobile thermal throttling | 15 min soak; the governor steps down |

### 5.3 Things only the user can do

| # | Action | Why it matters |
|---|---|---|
| 1 | ~~ID-verify the account that owns the game~~ **Done:** the owner is the user account spedboyjake2 (`user:5167569069`), confirmed ID-verified on 2026-09-25. **Still to do:** turn on **Enable Mesh / Image APIs** (Creator Dashboard, or Studio › Game Settings › Security › "Allow Mesh / Image APIs") | Without it the published game ships every procedural effect as its bake: the live sky, the growing tree, the ray-marched gems, living corruption. It also raises audio uploads to 2,000 per 30 days and enables video uploads (`rc` §0.1, `au` §6.1) |
| 2 | **Turn on 2FA** (plus Plus/Premium or the refundable fee when ready) | Required for Kids & Select. Without it the game stays 16+ and out of search and home (`pf` §2.9) |
| 3 | **Choose the owner (user or group) and turn on "Restrict on creation"** before the final uploads | Open Use can never be reverted, so anyone could reuse the painted realm by id. A wrong owner means tiles that don't load (`pf` §1.3) |
| 4 | **Studio MCP and Remote Control:** in Studio, Assistant › Manage MCP Servers › *Enable Studio as MCP server*; run a local Claude Code session on the PC that connects to it (optionally with Remote Control, so this conversation can drive it) | The only way for the agent to press Play, fly the camera and take screenshots in the real engine. The cloud container can't run Studio (`pf` §1.6) |
| 5 | **Create Open Cloud API keys**: `universe.places:write` and `universe.place.luau-execution-session:write` for a test place; confirm the existing Assets key's owner | Real-engine CI (`pf` §1.8). Keys stay out of the repo (proxy injection) |
| 6 | **Link Figma to Weave** (app.weavy.ai › settings) and **approve each run's credit quote** | Weave runs are quote-then-approve every time (`fg` §3.5); Weave credits are billed separately |
| 7 | **Game settings:** complete the maturity questionnaire, set the access settings, and later publish and set the game public | Rating and reach. Studio-only engine properties (StreamingEnabled, LightingStyle) go in the Rojo project, so they are **not** on this list |
| 8 | **Choose the music** (see Q2) and sign any composer contract | Creator Store music is Roblox-only and can't be used in the trailer. A contract must cover trailers and ads, with no Content ID registration (`ob` §14) |
| 9 | **Upload the video preview, thumbnails and icon** (Creator Dashboard › Places) | 3 uploads a month, moderated; the agent prepares the files and the review against the rules |
| 10 | **Approve the gates** (G1 look, G2 3D realm, the trailer cut) and **test on your own devices** (a phone and the 15 min soak) | Taste calls and real-hardware memory and thermals |
| 11 | **Record in-engine footage** with OBS or Studio freecam if MCP stills are not enough | True in-engine trailer shots |

---

## 6. Open questions (each with a recommended default)

1. **Phones in 3D?**
   - Default: **3D on every tier** (phones get LOW textures and bloom), with SAFE 2D as the automatic fallback and a
     CLASSIC option.
   - Alternative: phones stay on the 2D realm.
2. **Where does the music come from?**
   - Default: **I compose original stems procedurally** (numpy synthesis, owned outright) for v1 and the trailer.
   - Commission a composer later if you want a human score.
3. **Weather frequency.**
   - Default: **120 s cooldown**, the first prestige of each layer always plays, automation never triggers it, and
     the setting defaults to "On resets".
4. **Growing branches.**
   - Default: **luminous branches grow over the painted tree** (it keeps the approved art).
   - Alternative: repaint the world with the trunk only and grow every branch procedurally (riskier and slower).
5. **Tutorial length.**
   - Default: **the full 8 beats with Skip**, and an A/B test of a lean 5-beat version after launch.
6. **Per-player keepsakes** (the flame memento, a personal sigil, a "share my realm" button).
   - Default: **yes to all three.** They are cheap and they give players something to share.
7. **Who owns the game: your user account or a group?**
   - **Answered:** the user account spedboyjake2 (`ROBLOX_CREATOR` in `upload.js`), which is ID-verified.
8. **Spending.**
   - Default: **no paid Weave credits and no ads** until Phase 4 retention data. Free Weave-in-Figma tools during the
     beta only.
