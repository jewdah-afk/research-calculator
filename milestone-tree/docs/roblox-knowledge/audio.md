# Roblox Audio: knowledge base (state as of September 2026)

Part of the Milestone Tree NG+ "fat library" on what Roblox can do. Topic: **audio**. That covers the wired Audio API,
the legacy `Sound` stack, asset rules, sound design for a UI-heavy incremental, and what we can build with it.

**How claims are tagged**

| Tag | Meaning |
|---|---|
| **[V]** | Checked against the engine type dump (`scratchpad/tools/globalTypes.d.luau`) **and** the official docs (creator-docs repo, `main`, 2026-09-25) |
| **[T]** | Present in the type dump but undocumented, or documented only in the change log |
| **[NB]** | Class exists but is tagged `NotBrowsable` (unreleased or in development). Do not ship on it |
| **[C]** | Community-reported (DevForum), not confirmed by Roblox docs |
| **[U]** | Unverified. My inference or design advice; test it in Studio before relying on it |

Dates like "(added 2026-03-26)" come from the engine API change logs at
<https://robloxapi.github.io/ref/updates/2024.html>, `/2025.html` and `/2026.html`.

---

## 0. The ten facts that matter most

1. **The wired Audio API is the recommended path.** Official docs say `Sound`, `SoundGroup` and `SoundEffect` are now
   "discouraged in favor of … audio objects" ([Audio objects](https://create.roblox.com/docs/audio/objects)). The API
   entered beta in Feb 2024 and **left beta on 10 Sep 2024**
   ([exits-beta post](https://devforum.roblox.com/t/roblox-audio-api-exits-beta-enhanced-sound-controls-now-available/3153454)).
   `Sound` is discouraged but **not deprecated**; it has no deprecation tag.
2. **Every processing node is a separate Instance, and nodes connect with `Wire`s.** The graph is
   `AudioPlayer → effects → AudioDeviceOutput`, or `→ AudioEmitter … AudioListener → AudioDeviceOutput` for 3D. Wires
   fan in (many sources into one effect or bus) and fan out (one output into several targets). Cycles are rejected,
   and a cyclic wire reads `Wire.Connected = false`. [V]
3. **`AudioCompressor` has a real `"Sidechain"` input pin**, so you get true ducking: music ducks automatically under
   SFX. [V]
4. **`AudioAnalyzer` gives live `RmsLevel`, `PeakLevel` and `GetSpectrum()`** (RMS per bin, evenly spaced over 0–24 kHz).
   This is the basis for music-reactive visuals. It is client-only and returns zeros on the server. [V]
5. **Sample-accurate scheduling (added 2026-03-26):** `SoundService:GetMixerTime()` plus
   `AudioPlayer:Play(atTime)`, `:Stop(atTime)` and `:Cancel(actionId)`. Use it to start stems on the same sample,
   put stingers on bar lines, or build rhythm mechanics. [V]
6. **One `AudioPlayer` plays one voice at a time.** Overlapping one-shots need a pool of players or clones. [C]
   `ContentProvider:PreloadAsync` does **not** preload `AudioPlayer`s. Keep an `AutoLoad` player parented instead
   ([thread, Aug–Sep 2026](https://devforum.roblox.com/t/can%E2%80%99t-preload-audio-players-using-preloadasync/4819196)). [C]
7. **Upload rules:** `.mp3/.ogg/.wav/.flac`, under 20 MB, 7 minutes or less, 48 kHz or less, mono/stereo/3.0/5.1.
   Quotas are **2,000 per 30 days if ID-verified, 100 if not** (Creator Hub). The Open Cloud guide still says 100 and
   10 per month; see §6. **Audio content cannot be updated in place**, so every revision gets a new asset ID. [V]
8. **Audio is private by default.** An audio asset works in games its owner (user or group) uses it in, and must be
   granted to others explicitly. Upload under the group that owns the experience. [V]
9. **Creator Store music (APM, Monstercat, DistroKid 180k+, Too Lost since Jul 2026, and others) is licensed for use on
   Roblox only.** Using it in off-platform trailers or store pages is not covered. Commission original music if the
   game will be marketed "Steam-style". [V/C, §6]
10. **Acoustic simulation** (occlusion, diffraction, reverb from geometry) exists but is **irrelevant for a 2D-GUI realm
    map**. Skip it. [V]

---

## 1. Mental model: the audio graph

Official breakdown ([Audio objects](https://create.roblox.com/docs/audio/objects)):

- **Producers:** `AudioPlayer` (assets), `AudioDeviceInput` (microphone), `AudioTextToSpeech`, `AudioListener`
  (records the 3D world), `VideoPlayer` (the video's audio track).
- **Consumers:** `AudioDeviceOutput` (the speakers), `AudioEmitter` (a speaker placed in the 3D world),
  `AudioAnalyzer`, `AudioSpeechToText`, `AudioRecorder` [NB].
- **Modifiers (effects):** `AudioFader`, `AudioEqualizer`, `AudioFilter`, `AudioCompressor`, `AudioLimiter`,
  `AudioGate`, `AudioReverb`, `AudioEcho`, `AudioChorus`, `AudioFlanger`, `AudioDistortion`, `AudioPitchShifter`,
  `AudioTremolo`, `AudioChannelSplitter`, `AudioChannelMixer`.
- **Carrier:** `Wire`.

### Wire semantics [V]

([Wire docs](https://create.roblox.com/docs/reference/engine/classes/Wire))

- Properties: `SourceInstance`, `SourceName` (default `"Output"`), `TargetInstance`, `TargetName` (default
  `"Input"`), read-only `Connected`, and the method `RenameToDefault()`.
- `Connected` is true only when all four are set, both pins exist, **and the connection does not create a cycle**.
- Every wirable class has `GetInputPins()`, `GetOutputPins()`, `GetConnectedWires(pin)` and a
  `WiringChanged(connected, pin, wire, instance)` event.
- Pins that differ from plain Input/Output:
  - `AudioCompressor`: `Input` and `Sidechain`.
  - `AudioChannelSplitter`: outputs `Output`, `Left`, `Right`, `Center`, `SurroundLeft`, `SurroundRight`, `Sub`,
    `BackLeft`, `BackRight`, `TopLeft`, `TopRight`, `TopBackLeft`, `TopBackRight`.
  - `AudioChannelMixer`: the same names as inputs.
- A wire can be parented anywhere. **Parent one-shot wires to the source player**, so that `player:Destroy()` also
  cleans up the wire. [U, good practice]
- Wirable classes (from the Wire doc): all the `Audio*` classes above, plus `VideoPlayer` and `VideoDisplay`.

### Where audio runs [V]

- "All audio processing is disabled on the server" (`AudioAnalyzer` doc). The server may create graphs and call
  `Play()`/`Stop()`, which replicate to clients, but analysis and DSP happen on each client.
- For per-player UI audio (our whole game), **build the graph in a LocalScript.** Nothing replicates and there is no
  network cost.
- `AudioDeviceOutput.Player`: set it and only that player hears the output; leave it nil and everyone hears it.
  Created on the client, it is local anyway.
- `SoundService.DefaultListenerLocation` (`Enum.ListenerLocation`: `Default`, `None`, `Character`, `Camera`) spawns an
  `AudioListener` and an `AudioDeviceOutput` automatically. **For a GUI-only game, set it to `None`** and own the
  graph, so no stray output bypasses the master limiter. [V enum; the advice is U]

---

## 2. Class reference (with ranges)

### 2.1 `AudioPlayer` [V]

([docs](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer))

| Member | Notes |
|---|---|
| `Asset: ContentId` | `"rbxassetid://123"`. `AssetId` is deprecated and hidden. `AudioContent: Content` was added 2025-08-19 (hidden). |
| `AutoLoad` | If true, the asset loads as soon as `Asset` is set. If false, it loads on the first `Play()`. |
| `AutoPlay` | Added 2025-11. Starts on the first DataModel entry. Only for locally created or deserialized players, not replicated ones. |
| `IsReady` (read-only) | Loaded, buffered and ready. **Can flip back to false under extreme memory pressure** (the asset gets unloaded). |
| `IsPlaying` (read-only, replicates) | "playing **or planning to play**", so it includes scheduled plays. |
| `Looping`, `LoopRegion: NumberRange`, `PlaybackRegion: NumberRange` | Always active; `Sound` needed `PlaybackRegionsEnabled` for this. **Intro-then-loop from one asset:** `PlaybackRegion = 0..end`, `LoopRegion = introEnd..end`. |
| `PlaybackSpeed` | 0–20. Changes pitch **and** speed together, which is what a tape-stop effect needs. |
| `Volume` | 0–10, a linear multiplier. |
| `TimePosition`, `TimeLength` (read-only) | Seconds. |
| `Play(atTime?) → actionId?` / `Stop(atTime?) → actionId?` / `Cancel(actionId) → bool` | `atTime` is on the `SoundService:GetMixerTime()` clock and is "sample-accurate, framerate-independent" (added 2026-03-26). |
| `GetWaveformAsync(timeRange: NumberRange, samples: int) → {number}` | Values from −1 to 1, read **without playing**. Good for waveform drawings and precomputed envelopes (added 2024-10-22). Yields. |
| `Ended` / `Looped` | `Ended` does not fire for looping players, nor on a manual `Stop()`; watch `IsPlaying` for that. `Looped` does not fire when you loop manually by setting `TimePosition`. |
| `AssetRepresentation: Enum.AssetRepresentation` | `FullLength` or `ShortPreview`. Added 2026-05-12, undocumented, probably for song previews. [T] |

### 2.2 Spatial: `AudioEmitter` / `AudioListener` [V]

([Emitter](https://create.roblox.com/docs/reference/engine/classes/AudioEmitter),
[Listener](https://create.roblox.com/docs/reference/engine/classes/AudioListener))

- **Position.** The emitter uses its parent's world position when the parent is an Attachment, a Camera or a
  PVInstance; with any other parent it is **silent**. Since 2026-06-26, `PositionType` (`Parent` or `Instance`) plus
  `PositionInstance` let the position come from another instance.
- **Distance attenuation:**
  - `DistanceAttenuationMode` (`Custom`, `Inverse`, `InverseTapered`, `Linear`, `LinearSquared`) with
    `DistanceAttenuationBounds`, default `[4, 10000]`. Added 2026-07-21.
  - Or `SetDistanceAttenuation({[distance]=gain})`, a custom curve of up to 400 keys, used when the mode is `Custom`.
  - The listener has its own curve too, for things like "enhanced hearing".
- **Directional audio (angle attenuation):** `SetAngleAttenuation({[0..180]=gain})` on both emitter and listener.
  Added 2024-10-22, beta then.
- **Interaction groups:** `AudioInteractionGroup` (string). An emitter is heard only by listeners in the same group.
  Use this to keep separate "worlds" apart.
- **Audibility:**
  - `GetAudibilityFor(listener)` returns 0–1, including distance and angle. Use it to drive UI such as proximity
    glows.
  - `GetInteractingListeners()` / `GetInteractingEmitters()`.
- **Acoustic simulation:**
  - `AcousticSimulationEnabled`, plus the `SimulationMode` properties `OcclusionEnabled`, `DiffractionEnabled` and
    `ReverbEnabled` (added 2026-06-26).
  - The global switch is `SoundService.AcousticSimulationEnabled`.
  - Geometry inputs are `BasePart.AudioCanCollide` [V] and `PhysicalProperties.AcousticAbsorption` [V] (a new
    6th/7th constructor argument), plus density.
  - Timeline: Studio beta, then client beta on 2026-01-28, then an update to the thread on 2026-09-22 noting exit from
    beta ([announcement](https://devforum.roblox.com/t/client-beta-acoustic-simulation-emit-audio-with-presence/4307121)).
  - Cost: it runs background physics queries and degrades itself on low-end devices.
  - `Sound.AcousticSimulationEnabled` was added 2026-02-17 [T], so legacy Sounds are being brought to parity.

### 2.3 Effects: exact ranges [V]

All effects have `Bypass: boolean`. The `Editor: boolean` flag appears on those with a Studio visual editor
(Compressor, Equalizer, Filter, Limiter).

| Class | Key properties (range) | Use for |
|---|---|---|
| `AudioFader` | `Volume` 0–3 (a +9.5 dB ceiling) | Buses, user volume sliders, crossfades (tweenable). |
| `AudioEqualizer` | `LowGain`/`MidGain`/`HighGain` −80..+10 dB; `MidRange: NumberRange` crossovers 200–20,000 Hz | Broad tone shaping, "muffle". |
| `AudioFilter` (out of beta 2024-09) | `FilterType` (`Lowpass6/12/24/48dB`, `Highpass12/24/48dB`, `Bandpass`, `Notch`, `Peak`, `LowShelf`, `HighShelf`); `Frequency` 20–22,000 Hz; `Gain` −30..+30 dB (Peak/Shelf only); `Q` 0.1–10 (0.707 is a flat 12 dB/oct); `GetGainAt(hz)` | Cheap single-band filter. **Sweeps** (lowpass "time-stop", highpass "phone" feel). |
| `AudioCompressor` | `Threshold` −60..0 dB; `Ratio` 1–50; `Attack` 0.0001–0.5 s; `Release` 0.01–5 s; `MakeupGain` −30..+30 dB; **`Sidechain` pin** | Glue, ducking. |
| `AudioLimiter` (Dec 2024) | `MaxLevel` −12..0 dB; `Release` 0.001–1 s. Responds **instantly** ([post](https://devforum.roblox.com/t/new-audio-api-features-directional-audio-audiolimiter-and-more/3282100)) | Master-bus clip protection when many SFX stack. |
| `AudioGate` (browsable since 2025-07-22) | `Threshold: NumberRange` (low/high hysteresis, dB); `Attack`/`Release` 0.001–5 s | Mic noise gate. Rhythmic chopping in combination with sidechain tricks [U]. |
| `AudioReverb` | `DecayTime` 0.1–20 s; `DecayRatio` 0.1–1; `Density`/`Diffusion` 0.1–1; `DryLevel`/`WetLevel` −80..+20 dB; `EarlyDelayTime` 0–0.3 s; `LateDelayTime` 0–0.1 s; `HighCutFrequency`, `LowShelfFrequency`, `ReferenceFrequency` 20–20k Hz; `LowShelfGain` −36..+12 dB; `Reset()` flushes the tail | Cathedral-sized prestige tails. Space for the ambience. |
| `AudioEcho` | `DelayTime` 0.001–5 s; `Feedback` 0–1; `DryLevel`/`WetLevel` −80..+10 dB; `RampTime` (interpolates delay changes, which gives Doppler and pitch-bend effects); `Reset()` | Shimmer and rift echoes, tempo-synced delays (DelayTime = 60/BPM × fraction). |
| `AudioChorus` | `Depth` 0–1 (0–100 ms); `Mix` 0–1; `Rate` 0–20 Hz | Width, "choir" pads. |
| `AudioFlanger` | `Depth` 0.01–1 (up to 10 ms); `Mix` 0–1; `Rate` 0–20 Hz | Sci-fi sweep, corruption. |
| `AudioDistortion` | `Level` 0–1 | Grit on corrupted-zone SFX. |
| `AudioPitchShifter` | `Pitch` 0.5–2 (speed unchanged); `WindowSize` (`Small`/`Medium`/`Large`; larger means better quality and more latency). Works in the frequency domain, so extreme settings produce artifacts | Pitch variation without changing duration. |
| `AudioTremolo` (browsable since 2025-10-07) | `Depth` 0–1 (default 1); `Duty` 0–1 (default 0.5); `Frequency` 0.1–20 Hz (default 5); `Shape` 0 = triangle … 1 = sine; `Skew` −1..1; `Square` 0–1 | Pulsing drones, tempo-locked gating (Frequency = BPM/60 × n). |
| `AudioChannelSplitter` / `AudioChannelMixer` (browsable 2025-05-27) | `Layout: Enum.AudioChannelLayout` (`Mono`, `Stereo`, `Quad`, `Surround_5`, `Surround_5_1`, `Surround_7_1`, `Surround_7_1_4`) and per-channel pins | Manual stereo panning (§7.7), surround experiments. |
| `AudioAnalyzer` | `RmsLevel`, `PeakLevel` (read-only, update faster than the frame rate, **no Changed event**, so poll them); `SpectrumEnabled` (turn it off for large CPU savings when only levels are needed); `WindowSize` (`Small`/`Medium`/`Large`; bigger means more bins and fewer updates); `GetSpectrum()` returns RMS per bin, **evenly spaced from 0 to 24,000 Hz**, and is empty on the server or when fed from `AudioDeviceInput` | Music-reactive visuals, meters. |

The exact bin count per `WindowSize` is **not documented**. Read `#analyzer:GetSpectrum()` at runtime; each bin is
`24000 / #spectrum` Hz wide. [U]

**Ordering matters.** Chorus followed by distortion sounds different from the reverse order
([Audio effects](https://create.roblox.com/docs/audio/effects)).

### 2.4 Other audio classes

| Class | Status | Notes |
|---|---|---|
| `AudioDeviceInput` | [V] | Microphone input. `Player`, `Muted`, `Volume`, `AccessType` plus `SetUserIdAccessList`; `EchoCancellation`, `NoiseSuppression` and `GainControl` were added 2026-05-21. Voice-chat territory. |
| `AudioTextToSpeech` | [V] | `Text` (up to 300 characters per request), `VoiceId` (1–11 English variants, then 101–1002 for es/de/it/fr/zh/hi/ja/ar/ko/pt), `Pitch`, `Speed`, `LoadAsync()`, `Play()`/`Pause()`. Throttle: `1 + 6 × CCU` requests per minute per experience ([docs](https://create.roblox.com/docs/audio/objects#text-to-speech)). |
| `AudioSpeechToText` | [V] | Browsable since 2025-11. Throttle: `1 + 5 × CCU` per minute. 17 languages, detected automatically. |
| `AudioRecorder` | **[NB]** | "In development": records up to 60 s, and `GetTemporaryContent()` plays the result back through an `AudioPlayer`. |
| `AudioWindSynthesizer` | **[NB]** | Added 2026-08-10. Procedural wind with `Profile` = `Foliage`/`Turbulence`/`Whistle`, `Volume`, `PositionType`. Not released. |
| `AudioSearchParams` + `AssetService:SearchAudioAsync()` | [V] | Search the audio catalog in-game, returning `AudioPages`. Low rate limit, so wrap it in `pcall`. |
| `AssetService:GetAudioMetadataAsync(ids)` | [V] | Artist, title, duration and type. Useful for a "Now Playing" plaque. |
| `AudioFocusService` | [T] | Internal and voice-related (focus contexts, deafen events). Ignore it. |

### 2.5 `SoundService` members that matter [V unless noted]

- **`GetMixerTime()`** is the scheduling clock. It is derived from mixed samples, so it is monotonic and
  sample-accurate.
- `DefaultListenerLocation` (see §1).
- `AcousticSimulationEnabled` (see §2.2).
- `CharacterSoundsUseNewApi: Enum.RolloutState` decides whether core character sounds use `AudioPlayer`s or `Sound`s.
- `GetAudioInstances()` and `AudioInstanceAdded` [T]. `AudioApiByDefault`, `Get/SetAudioApiByDefault()` and
  `IsNewExpForAudioApiByDefault` were added 2025-02-11 and are undocumented. Presumably they make Studio or the Toolbox
  create wired audio by default [U].
- Legacy-only: `AmbientReverb` (`Enum.ReverbType` FMOD presets), `DopplerScale`, `DistanceFactor`, `RolloffScale`,
  `RespectFilteringEnabled`, `SetListener()`/`GetListener()`, `PlayLocalSound(sound)`, and `VolumetricAudio`
  (NotScriptable).

---

## 3. Timing, sync and adaptive music mechanics

### 3.1 Sample-aligned stems [V API; the pattern is U]

```lua
--!strict
local SoundService = game:GetService("SoundService")

local function waitReady(p: AudioPlayer)
	while not p.IsReady do p:GetPropertyChangedSignal("IsReady"):Wait() end
end

-- start N equal-length looping stems on the same sample; returns t0 (the bar-grid origin)
local function startStems(stems: { AudioPlayer }): number
	for _, s in stems do
		s.Looping = true
		s.TimePosition = 0
		waitReady(s)
	end
	local t0 = SoundService:GetMixerTime() + 0.15 -- lead time so every Play() lands on the same sample
	for _, s in stems do s:Play(t0) end
	return t0
end
```

Rules:

- Author stems at the **same length and tempo, as an integer number of bars.** Then identical loops stay aligned.
- On long sessions, check drift now and then: compare `TimePosition`s and reschedule if they differ by more than
  about 10 ms. [U] The community AudioEngine lists drift as needing more testing
  ([AudioEngine](https://devforum.roblox.com/t/audioengine-an-easy-to-use-adaptive-audio-system-for-roblox/4807450)).

### 3.2 Bar-quantized stingers and transitions

```lua
local BPM, BEATS_PER_BAR = 96, 4
local function nextGrid(t0: number, division: number): number -- division 1 = bar, 4 = beat, 16 = 16th
	local step = (60 / BPM) * BEATS_PER_BAR / division
	local now = SoundService:GetMixerTime()
	return t0 + math.ceil((now - t0 + 0.02) / step) * step -- 20 ms safety margin
end
local id = stinger:Play(nextGrid(t0, 1)) -- lands exactly on the next downbeat
-- stinger:Cancel(id) if the game state changes before it fires
```

**Latency budget.** At 96 BPM a bar is 2.5 s, a beat 625 ms and a 1/16 note 156 ms. For click feedback, play the
transient immediately and quantize only the musical tail or harmony layer.

### 3.3 Crossfading

- **Vertical layering:** every stem goes through its own `AudioFader`, and you drive `Volume` from a 0–1 weight.
- **Horizontal re-sequencing:** schedule `B:Play(nextGrid(t0, 1))` and `A:Stop(sameTime)`, with a short fader ramp to
  hide the click.
- **Equal-power curve** (no loudness dip in the middle): `gainA = cos(w·π/2)`, `gainB = sin(w·π/2)`.
- For continuous camera-driven weights, lerp every frame. For discrete events, tween with
  `TweenService:Create(fader, TweenInfo.new(2, Enum.EasingStyle.Sine), {Volume = g})`. `Volume` is a number, so it
  can be tweened.
- To convert decibels to a linear gain: `gain = 10^(dB/20)`. −6 dB ≈ 0.5, −12 dB ≈ 0.25.

### 3.4 Tape stop and slow motion

- Tween `PlaybackSpeed` from 1 to about 0.5 on **all** stems together. Pitch and speed fall together.
- They stay aligned with each other, but the mixer-time bar grid is now off. **Re-anchor `t0`** from `TimePosition`
  when you restore speed. [U]
- `AudioPitchShifter` changes pitch without changing time, but it costs FFT work and adds latency.

---

## 4. Loading, voices, memory, performance

- **One voice per `AudioPlayer`.** Calling `Play()` on a player that is already playing does not stack another voice
  ([thread](https://devforum.roblox.com/t/what-is-the-bestintended-way-to-play-multiple-audios-simultaneously-using-the-new-audio-api/3487432),
  [feature request](https://devforum.roblox.com/t/audioplayer-playing-should-overlap/4055469)). [C] Use a
  **round-robin voice pool**. The pool also caps polyphony, so voice limiting comes for free:

```lua
local function wire(src: Instance, dst: Instance, pin: string?): Wire
	local w = Instance.new("Wire")
	w.SourceInstance, w.TargetInstance = src, dst
	if pin then w.TargetName = pin end
	w.Parent = src -- destroyed together with a one-shot source
	return w
end

local function voicePool(asset: string, bus: Instance, voices: number)
	local list, i = table.create(voices) :: { AudioPlayer }, 1
	for n = 1, voices do
		local p = Instance.new("AudioPlayer")
		p.AutoLoad = true
		p.Asset = asset -- loads now and stays resident while parented
		p.Parent = bus
		wire(p, bus)
		list[n] = p
	end
	return function(speed: number?, volume: number?)
		local p = list[i]; i = i % voices + 1
		if p.IsPlaying then p:Stop() end -- steal the oldest voice
		p.TimePosition = 0
		p.PlaybackSpeed = (speed or 1) * (0.96 + math.random() * 0.08) -- +/-4% jitter
		p.Volume = volume or 1
		p:Play()
	end
end
```

- **Preloading.**
  - `PreloadAsync` is a no-op for `AudioPlayer`, and Roblox unloads audio that nothing uses. The workaround is to keep
    the instance **parented**, with `AutoLoad = true`, and wait for `IsReady`
    ([thread](https://devforum.roblox.com/t/can%E2%80%99t-preload-audio-players-using-preloadasync/4819196)). [C]
  - Under extreme memory pressure the engine may unload anyway (`IsReady` becomes false) [V]. Handle it: if a sound is
    not ready, skip it rather than wait.
- **Sprite sheets.** Pack many short UI sounds into **one** asset and play slices with `PlaybackRegion`. The benefits
  are one load, one moderation pass and one permission grant; the cost is still one voice per player instance. [U]
- **CPU.** From least to most expensive: Fader, EQ, Filter, Limiter, Compressor, then Reverb, PitchShifter and
  `AudioAnalyzer` with `SpectrumEnabled` [U, typical DSP costs].
  - **Share effects on buses** (fan-in) instead of giving every sound its own chain.
  - Turn `SpectrumEnabled` off when you only need levels [V].
- **Scale.** A community test found about 400 simultaneously playing legacy `Sound`s to be fine, with desync and
  cut-outs above that ([thread](https://devforum.roblox.com/t/total-sound-instance-limit/3736250)). [C] A UI game
  should budget 16–32 voices.
- **Diagnostics:**
  - Developer Console, Memory, then Sounds.
  - `SceneAnalysisService:GetAudioMemoryAsync()` (added 2026-04-21) [T]; its security level is unknown and it is
    probably Studio-only.
  - The community plugin **Audiophile** (Jul 2026) adds live dB meters (peak/RMS), EQ and compressor presets,
    loudness matching and sidechain ducking presets for wired audio
    ([thread](https://devforum.roblox.com/t/plugin-audiophile-a-real-time-mixing-console-for-the-new-audio-api/4719764)).

---

## 5. Legacy `Sound` / `SoundGroup` / `SoundEffect`: when to still use them

| | `Sound` stack | Wired Audio API |
|---|---|---|
| Setup | One instance. Parent it to a Part or Attachment for 3D; elsewhere it is global | Player plus wires plus output, and an emitter/listener for 3D |
| Effects | `SoundEffect`s (`Reverb/Compressor/Equalizer/PitchShift/Chorus/Distortion/Echo/Flange/TremoloSoundEffect`) as children of a Sound or SoundGroup; `Priority` orders them | Any effect graph, reusable buses, sidechain pins, Filter, Limiter, Gate, channel ops |
| Ducking | `CompressorSoundEffect.SideChain = <Sound or SoundGroup>` ([Sound groups](https://create.roblox.com/docs/sound/groups)) | `Wire.TargetName = "Sidechain"` |
| Analysis | `Sound.PlaybackLoudness` (0–1000, amplitude only) | `AudioAnalyzer` RMS, peak and **spectrum** |
| Scheduling | None (frame-bound `Play()`) | `Play(atTime)` on the mixer clock |
| Regions | `PlaybackRegionsEnabled` + `PlaybackRegion`/`LoopRegion` | Always on |
| 3D rolloff | `RollOffMode`, `RollOffMin/MaxDistance`, Doppler via `SoundService` | Attenuation curves or presets, angle attenuation, interaction groups, acoustic simulation |
| Conveniences | `PlayOnRemove`, `SoundService:PlayLocalSound()`, clicking a Toolbox audio inserts a **Sound** | None |

**Still reasonable uses for `Sound`:** quick prototypes, Toolbox-inserted assets, `PlayOnRemove` death sounds, and
existing code. `Sound.Volume` is 0–10 (default 0.5) and `SoundGroup.Volume` is a 0–10 multiplier; groups can be
nested.

**Where it is heading:**

- `SoundShimService` (added 2025-08-26) and `Sound:GetUnderlyingAudioPlayer()` (added 2026-03-10) are both
  undocumented [T].
- They strongly suggest `Sound` is being reimplemented on top of `AudioPlayer`. If so, legacy Sounds may be able to
  expose their player and be wired into new effect graphs. [U; test before relying on it]
- For new work, **use the wired API.**

---

## 6. Assets, quotas, permissions, licensing

### 6.1 Import requirements

([Audio assets](https://create.roblox.com/docs/audio/assets)) [V]

- Formats: `.mp3`, `.ogg`, `.wav`, `.flac`, as a single track or stream.
- Size and length: **under 20 MB**, **7 minutes or less**, sample rate **48 kHz or less**.
- Channels: mono, stereo 2.0, 3.0, or 5.1.
- Studio **transcodes** every import. Rejections usually mean a malformed header from an old tool; re-export the file.
- **Quota (Creator Hub):** ID-verified accounts get **2,000 free audio uploads per 30 days**; unverified accounts get
  **100**. Any daily limit has been replaced by this monthly one.
- **Discrepancy:** the Open Cloud usage guide still lists "100 uploads per month if ID-verified, 10 if not" for
  API uploads ([usage-assets](https://create.roblox.com/docs/cloud/guides/usage-assets)). Assume the lower number
  for CI pipelines until you have tested it.
- Import paths: Studio **Asset Manager** (bulk), **Creator Dashboard** (Development Items, Audio), or **Open Cloud**.

### 6.2 Open Cloud upload

```bash
curl -X POST 'https://apis.roblox.com/assets/v1/assets' \
  -H "x-api-key: $ROBLOX_API_KEY" \
  -F 'request={"assetType":"Audio","displayName":"mt_prestige_impact_v3","description":"Milestone Tree SFX",
              "creationContext":{"creator":{"groupId":"<GROUP_ID>"}}}' \
  -F 'fileContent=@"./out/mt_prestige_impact_v3.ogg";type=audio/ogg'
# returns {"path":"operations/<id>"}; poll GET https://apis.roblox.com/assets/v1/operations/<id>
```

- Content types: `audio/mpeg`, `audio/ogg`, `audio/wav`, `audio/flac`.
- API-key scopes are the assets read and write operations; OAuth uses `asset:read` and `asset:write`.
- **Audio does not support "Update Asset" content updates**, so every re-export is a new ID. Keep a manifest
  (`name → id`) in the repo and version names (`_v3`).

### 6.3 Moderation and copyright

- New uploads sit in the moderation queue and are visible only to you until approved
  ([Audio assets](https://create.roblox.com/docs/audio/assets)).
- Uploaders must hold all rights, including performance licenses, under the
  [Audio Upload License Agreement](https://en.help.roblox.com/hc/en-us/articles/23359485439124-Audio-Upload-License-Agreement).
- Roblox matches uploads against copyrighted recordings with **Audible Magic** and rejects unlicensed music. [C,
  consistent across sources] Composers of original work have reported false matches.

### 6.4 Privacy and permissions

([Asset privacy](https://create.roblox.com/docs/projects/assets/privacy),
[Dec 2023 post](https://devforum.roblox.com/t/new-asset-privacy-and-permissions-features-for-audio-and-video/2725248))

- Audio and video are **private by default**. The "Asset Privacy" toggle only affects Images, Decals and Meshes.
- The owner (user or group) can use the audio in its own games.
- It can be shared with **friends** (creators) and with specific **experiences**. Grants to games are permanent.
- Group-owned audio can be shared by members with edit permission.
- Cross-publishing a place carries over access.
- **Practical rule:** upload under the **group that owns the experience**. Many historical DevForum bugs involve
  user-owned audio in group games.

### 6.5 Discovery and visibility

- Uploads are auto-classified as **sound effect** or **song**. Sound effects can be distributed on the Creator Store.
- A song can appear on the **game details page** (with a 15-second preview) if all of these hold:
  - it passes moderation and copyright checks;
  - it meets minimum duration, unique plays and platform-age thresholds;
  - it has a meaningful title;
  - the uploader is ID-verified and has accepted the Audio Terms.
- Songs show there by default when eligible. Toggle this on the asset's Configure page and set **Song Artist**
  ([Audio assets](https://create.roblox.com/docs/audio/assets)).
- Since Feb 2025, **"What's Playing"** shows verified track details (song and artist) in the in-experience menu, for
  distributor tracks with ISRCs
  ([post](https://devforum.roblox.com/t/amplify-your-experiences-with-new-music/3164792)).

### 6.6 Free libraries

- The Creator Store has **more than 100,000 professionally produced SFX and music tracks from partners**
  ([Audio overview](https://create.roblox.com/docs/audio)).
- Partner timeline:
  - **Monstercat**: 2020, the first label to license its library for free creator use.
  - **APM Music**: royalty-free on Roblox; Roblox holds the sync, master, mechanical and performance licenses.
  - **DistroKid**: Sep 2024, more than 180k tracks, a "DistroKid Hits" section, and music charts.
  - **Clippsly** and **BSlick**.
  - **Too Lost**: 2026-07-28.
  - ([Music Ally](https://musically.com/2024/09/09/roblox-moves-into-music-discovery-with-charts-and-distrokid/),
    [Too Lost news](https://www.soundstock.com/news/2026-07-29-too-lost-partners-with-roblox-to-offer-independent-music-catalog-to-game-creators))
- The model is "gratis": artists get exposure, not royalties.
- **Usage limits:**
  - "All music on Creator Store is meant to be solely used on Roblox." Gameplay videos on YouTube, TikTok and similar
    platforms fall under those platforms' copyright systems.
  - Under the APM license, capture videos may only promote gameplay. They may not be used in commercials, films or
    separate games ([Using Licensed Music in Videos](https://en.help.roblox.com/hc/en-us/articles/360038525351-Using-Licensed-Music-in-Videos),
    via search snippet; the page returned 403 to the fetcher).
  - **Therefore: trailers, ads and any Steam-style store assets need music we own or have licensed ourselves.**
- In-game search: `AssetService:SearchAudioAsync(AudioSearchParams)` accepts `SearchKeyword`, `Artist`, `Album`,
  `Title`, `Tag`, `AudioSubType` (`Music`/`SoundEffect`) and `Min/MaxDuration`.

---

## 7. Sound design playbook for a neon, ornate, UI-first incremental

### 7.1 Bus architecture: build once on the client [V API; values are starting points, U]

```lua
--!strict
local SoundService = game:GetService("SoundService")
local root = Instance.new("Folder"); root.Name = "MT_Audio"; root.Parent = SoundService

local function node<T>(class: string, props: { [string]: any }?): T
	local inst = Instance.new(class)
	for k, v in props or {} do (inst :: any)[k] = v end
	inst.Parent = root
	return inst :: any
end
local function wire(src: Instance, dst: Instance, pin: string?)
	local w = Instance.new("Wire"); w.SourceInstance, w.TargetInstance = src, dst
	if pin then w.TargetName = pin end
	w.Parent = src
end

local out     = node("AudioDeviceOutput")
local limiter = node("AudioLimiter", { MaxLevel = -1, Release = 0.08 })
local master  = node("AudioFader", { Name = "Master" })
local music   = node("AudioFader", { Name = "Music" })     -- user slider
local amb     = node("AudioFader", { Name = "Ambience" })  -- user slider
local ui      = node("AudioFader", { Name = "UI" })        -- user slider
local impact  = node("AudioFader", { Name = "Impacts" })
local duck    = node("AudioCompressor", { Threshold = -32, Ratio = 8, Attack = 0.008, Release = 0.45 })
local hall    = node("AudioReverb", { DecayTime = 5.5, WetLevel = -8, DryLevel = -80, HighCutFrequency = 9000 }) -- send: wet only

wire(music, duck); wire(amb, duck)          -- ducked beds
wire(impact, duck, "Sidechain")             -- big moments push the beds down…
wire(ui, duck, "Sidechain")                 -- …and so do UI cues, slightly
wire(duck, master); wire(ui, master)
wire(impact, hall); wire(impact, master)    -- parallel reverb send (fan-out)
wire(hall, master)
wire(master, limiter); wire(limiter, out)
```

- Map the user sliders to `AudioFader.Volume` through a perceptual curve: `volume = slider^2`, or treat the slider as
  a dB range.
- Persist them through `Core/Prefs` (device options, server-validated). This is a new `audio` key; `Prefs.ALLOWED`
  needs extending.
- Set `SoundService.DefaultListenerLocation = None` so nothing bypasses the limiter.

### 7.2 Layering: each "event" is two to four layers

- **Transient:** a click or tick of 5–30 ms that carries timing.
- **Body:** a tonal note or chime that carries identity and pitch.
- **Tail:** a shimmer, reverb send or sparkle that carries scale.
- **Sub-thump:** only for big events. It is inaudible on phones (see §7.8).
- Scale the layer count with event magnitude:
  - buy: transient + body;
  - milestone: + tail;
  - prestige: + sub + stinger + duck + filter sweep.

### 7.3 Variation: avoid the machine-gun effect

- Use 3–5 variants per frequent sound, chosen at random **without immediate repeats**.
- Add ±3–5% `PlaybackSpeed` jitter (about ±1 semitone at most) and ±1.5 dB volume jitter. Use `AudioPitchShifter`
  instead if the duration must not change.
- **Combo pitch ladders.** Consecutive purchases within about 0.4 s step up a scale: speed =
  `2^(scaleDegree/12)` from a single pluck asset, capped at an octave, resetting after a pause. This is the classic
  "juicy" incremental feel.
- **Rate-limit held-button repeats** (buyables repeat while held): at most about 12 audible per second, while the
  pitch keeps climbing.

### 7.4 Ducking

- **Sidechain** (§7.1) is automatic and follows loudness, so it sounds natural.
- **Scripted duck:** tween `music.Volume` to 0.35 over 0.15 s, hold, then release over 1.2 s. It is deterministic,
  so use it for modals and cutscenes.
- **Legacy equivalent:** `CompressorSoundEffect.SideChain` on a SoundGroup.

### 7.5 Adaptive music

- **Vertical:** synchronized stems crossfaded by state (§3.1, §3.3).
- **Horizontal:** sections swapped on bar lines (§3.2).
- **Intro-plus-loop in one asset** via `LoopRegion`.
- **Stingers** scheduled to the grid.
- Drive the intensity weight from game state:
  - how deep the player is in the tree;
  - an active challenge;
  - how close the next prestige is (0–1, from the prestige gain ratio);
  - idle time, where the mix thins after roughly 90 s of no input.

### 7.6 Music-reactive UI with `AudioAnalyzer`

```lua
local RunService = game:GetService("RunService")
local an = node("AudioAnalyzer", { SpectrumEnabled = true, WindowSize = Enum.AudioWindowSize.Small })
wire(music, an) -- fan-out tap. Post-slider, so muted music means calm visuals; tap the pre-slider stem sum to keep them lively

local level, kickAvg, pulse = 0, 1e-4, 0
RunService.RenderStepped:Connect(function(dt)
	level += (an.RmsLevel - level) * math.min(1, dt * 10)     -- smoothed loudness (treat as linear amplitude, U)
	local spec = an:GetSpectrum()
	local n = #spec
	if n > 0 then
		local lastBin = math.max(1, math.floor(150 / (24000 / n))) -- 0-150 Hz, the kick-drum region
		local kick = 0
		for i = 1, lastBin do kick += spec[i] end
		if kick > kickAvg * 1.7 then pulse = 1 end               -- onset
		kickAvg += (kick - kickAvg) * math.min(1, dt * 2.5)
	end
	pulse = math.max(0, pulse - dt * 4)
	-- drive: node UIStroke.Transparency, link glow, field-particle speed, vignette breathing, bloom-ish ImageTransparency
end)
```

- Bins are **linear**. Group them logarithmically for bars; about 8–12 bands from 40 Hz to 16 kHz reads "musical".
- Call `GetSpectrum()` at 30 Hz or less on mobile, because it allocates a table.
- **Offline alternative:** `AudioPlayer:GetWaveformAsync()` once per track, then index by `TimePosition`. It is
  deterministic and costs zero CPU per frame. Whether the returned samples are per-bucket peaks or point samples is
  undocumented, so request enough samples and take the max abs value per window. [U]
- Legacy: `Sound.PlaybackLoudness` (0–1000) gives amplitude only.
- Respect `Prefs.motion = REDUCED`: cap how far the pulse can swing.

### 7.7 Positioning sound in a 2D world

**(a) Stereo panner.** [U, verify the up-mix behaviour]

```
player → AudioChannelSplitter(Layout=Stereo) ─Left→  FaderL → AudioChannelMixer(Layout=Stereo).Left  → bus
                                            └Right→ FaderR → AudioChannelMixer(Layout=Stereo).Right
```

- Pan with `FaderL = cos(p·π/2)` and `FaderR = sin(p·π/2)`, where `p` is the node's screen x from 0 to 1.

**(b) Spatial trick.** Put an `AudioListener` on the camera and `AudioEmitter`s on Attachments of an invisible part
laid out to mirror the 2D map. The engine then does panning and distance for free. The attenuation presets
(`Linear`, `InverseTapered`) with `DistanceAttenuationBounds` give smooth zone crossfades.

### 7.8 Mobile and accessibility

- **Phone speakers roll off below about 150–300 Hz** [U, general audio knowledge]. Make every cue identifiable in the
  1–5 kHz range and treat sub-bass as a bonus.
- Many mobile players play **muted** [U]. Never put information only in audio; pair it with visuals and
  `HapticEffect` (a class that exists [V]).
- Keep the master limiter at −1 dB. Normalize assets before upload (targets around −16 LUFS for music, peaks at
  −1 dBTP) [U].
- Budget voices: 16 or fewer on phones. Turn the spectrum off on the `detail = LOW` tier.
- Give each bus its own slider: Music, Ambience, UI, Impacts.

---

## 8. Gotchas checklist

- An emitter parented to anything that is not an Attachment, Camera or PVInstance is silent. An `AudioPlayer` wired
  nowhere is silent. A wire with `Connected = false` means a missing pin or a cycle.
- `AudioFader.Volume` tops out at 3. `AudioPlayer.Volume` tops out at 10. `PlaybackSpeed` spans 0–20.
- `Ended` does not fire for looping players or on `Stop()`. Use `IsPlaying` changes.
- Analyzer levels do **not** fire `Changed`; poll them.
- Audio processing, including the analyzer, returns nothing on the server.
- `PreloadAsync` does not preload `AudioPlayer`s [C]. Keep players parented with `AutoLoad`.
- One voice per `AudioPlayer`; pool them.
- Audio cannot be re-uploaded to the same ID. Uploads land in the moderation queue. User-owned audio may not play in
  a group game without a grant.
- `AudioRecorder` and `AudioWindSynthesizer` are `NotBrowsable`. Do not design around them yet.
- `AudioReverb.Reset()` and `AudioEcho.Reset()` flush tails. Call them on hard scene cuts, such as hard reset or a
  teleport.

---

## 9. Roblox games noted for audio, and what to learn from them

| Game | Evidence | Lesson for us |
|---|---|---|
| **Arsenal** (ROLVe) | Won **Best Sound Design** at the 7th Bloxy Awards ([Wikipedia list of Roblox games](https://en.wikipedia.org/wiki/List_of_Roblox_games)) | Crisp, instantly readable feedback: every action has a distinct transient. |
| **Doors** (LSPLASH) | Best Horror Experience, Innovation Awards 2024 ([winners](https://devforum.roblox.com/t/roblox-innovation-awards-2024-winners/3152047)). Entities are telegraphed by sound (Rush's approaching roar with flickering lights; Figure hunts by sound) [C, widely known gameplay] | Audio as **information and anticipation**. Our analogue: a rising "ready" shimmer as prestige becomes available. |
| **Sol's RNG** | Each high-tier aura has its own BGM. Auras rarer than 1 in 999,999,999 get unique cutscenes that play their BGM. Biomes have their own tracks, and an in-game soundtrack list exists ([fandom, via search](https://sol-rng.fandom.com/wiki/Auras)). Creators publish "audio visualizer" aura VFX tutorials | The **closest genre match**: rarity- and progress-tiered audio escalation, biome music, and an in-game jukebox for collected tracks. |
| **On Tap** (Diepolder) | **Best Use of Voice & Audio**, Innovation Awards 2024 ([winners](https://devforum.roblox.com/t/roblox-innovation-awards-2024-winners/3152047)) | Voice-first social design. Low relevance, but it proves Roblox rewards audio craft. |
| Rhythm games (Funky Friday, RoBeats) | [C] Historically synced to `Sound.TimePosition` on frame ticks | Since 2026-03, `GetMixerTime()` and `Play(atTime)` allow **sample-accurate** musical interaction, which few Roblox games exploit yet. |

---

## 10. Opportunities for Milestone Tree

Cost: S ≈ up to 1 dev-day, M ≈ 2–4 days, L ≈ a week or more, plus audio authoring. The game renders the realm as a 2D
painted map (`Map/MapCamera`, `shared/Realm.luau` biomes: `rift.from/to = 2300/2600` along x, and the `corrupt.rect`
outcrop). So the audio logic reads the **same Realm constants** as the visual biome wash.

1. **Audio foundation: bus graph, limiter and sliders** (§7.1).
   - Client-side graph (Music / Ambience / UI / Impacts to Master, Limiter, Output) plus sidechain duck.
   - Four sliders in Options, THIS DEVICE, stored through `Prefs` (extend `ALLOWED` and server validation).
   - `DefaultListenerLocation = None`.
   - *Cost S. Risk low.* Everything below builds on it.
2. **Biome-following ambient score.**
   - Three synchronized stem sets: **Tree** (warm violet pads), **Rift** (crimson, detuned, with an echo shimmer) and
     **Corrupted outcrop** (green, gritty, tremolo-gated).
   - All start on one sample with `Play(GetMixerTime()+0.15)`.
   - Weights come from `MapCamera`'s centre, using `Realm.biome.rift.from/to` and the distance to
     `corrupt.focus`/`light.radius`, then an equal-power crossfade, smoothed per frame.
   - Visual wash and audio wash use one formula, so they cannot disagree.
   - *Cost M, plus 3 stem sets.* Risks: authoring equal-length loops; memory for 6–9 concurrent loops on phones (use
     mono for pads on the LOW tier); rare drift, so add a resync check.
3. **Progress-driven vertical layers ("the tree grows a choir").**
   - Each unlocked realm layer, and NG+ tiers, add an instrument stem through `AudioFader`s (bass, then arpeggio,
     then choir, then celesta).
   - Nearing prestige raises a riser layer from 0 to 1 using the prestige-gain ratio.
   - *Cost M.* Risk: the composition must work at every subset. Write stems as additive from day one.
4. **Prestige impact chain.**
   - Impact SFX go through the Impacts bus into a parallel `AudioReverb` (DecayTime 5–8 s) and sidechain-duck the beds
     by about 8–10 dB.
   - Simultaneously: the music bus runs through an `AudioFilter` Lowpass24dB sweep (22 kHz to 400 Hz to 22 kHz over
     about 1.5 s), all stems get a 0.4 s **tape-stop** (`PlaybackSpeed` 1 to 0.55), and the music re-enters on the next
     downbeat with a scheduled stinger. Pair this with the screen flash and `HapticEffect`.
   - *Cost S–M.* Risks: fatigue if it fires too often, so keep the full chain for real resets and give minor layers a
     lite version; re-anchor the bar grid after the tape-stop (§3.4).
5. **Musical purchase feedback (a combo arpeggio in the score's key).**
   - One pluck asset per timbre, pitched by `PlaybackSpeed = 2^(degree/12)` along a pentatonic scale.
   - Consecutive buys climb the scale. The transient plays immediately and a soft harmonic tail is scheduled on the
     next 1/16 note.
   - Voice pool of 6, with a rate cap for hold-to-repeat buyables.
   - *Cost S.* Risk: quantization latency. Keep only the tail quantized.
6. **Music-reactive realm** (§7.6).
   - An `AudioAnalyzer` on the music bus drives node `UIStroke` glow, link-energy flow speed, field-particle drift and
     vignette breathing. Low-band onsets pulse the nearest node cluster.
   - *Cost M.* Risks:
     - CPU on low-end phones. Disable the spectrum on `detail = LOW` (RMS only), and fall back to a precomputed
       `GetWaveformAsync` envelope.
     - Motion sensitivity. `Prefs.motion = REDUCED` caps the effect.
7. **Zone FX sends for SFX.** SFX triggered inside a biome route through that biome's colour:
   - **Rift:** `AudioEcho` at dotted-eighth delay with `RampTime` pitch smear.
   - **Corrupted outcrop:** `AudioDistortion` at Level 0.1–0.2, plus `AudioFlanger` at a low mix.
   - **Tree:** clean with a light `AudioChorus`.
   - *Cost S.* Risk: taste. Keep wet levels subtle and A/B them.
8. **Relic "Now Playing" plaque and jukebox.**
   - An ornate waveform strip drawn once from `GetWaveformAsync`, a playhead from `TimePosition`, and title and artist
     from `GetAudioMetadataAsync`.
   - Tracks unlock as milestones are reached (the Sol's-RNG-style collection hook).
   - *Cost S–M.* Risk low.
9. **UI sound kit with variation and a budget.**
   - Hover (very quiet, rate-limited), panel open/close whooshes (pitch scales with panel size), tab ticks,
     toast chimes by severity, READY-tray shimmer, and an error "thunk".
   - 3–5 variants each, ±4% jitter, no immediate repeats. Ship them as one or two sprite-sheet assets played with
     `PlaybackRegion`.
   - *Cost M, mostly authoring.* Risk: over-sounding the UI. Mute hover on touch devices.
10. **Screen-position panning for node events** (§7.7a). When a node far to the left completes a milestone, its chime
    comes from the left. *Cost S.* Risk: the splitter/mixer up-mix behaviour needs a Studio test; the effect is subtle.
11. **Offline-progress "welcome back" cue and tiered fanfares.**
    - The fanfare tier comes from log10 of the gain (3 tiers), and it is scheduled on a bar line so it merges with the
      score.
    - *Cost S.* Risk low.
12. **Mobile audio profile.**
    - On phones (detected by the phone band or `TouchEnabled` plus viewport size):
      - an `AudioFilter` HighShelf/Peak lift of about +3 dB around 2–4 kHz on UI and Impacts;
      - highpass the sub layers;
      - a voice cap of 16;
      - spectrum off.
    - *Cost S.* Risk low, and it prevents a muddy, quiet mix on phone speakers.
13. **Asset pipeline script** (Node, alongside `port/`).
    - Loudness-normalize (around −16 LUFS for music, −1 dBTP), then encode `.ogg`.
    - Upload through Open Cloud **as the owning group** and write `src/shared/AudioIds.luau` from the manifest.
    - Needed because audio cannot be updated in place.
    - *Cost S–M.* Risks: moderation lag (hours), and Open Cloud possibly enforcing a lower quota than the Creator Hub
      figure (§6.1).
14. **Own the soundtrack (licensing strategy).**
    - Commission or compose original music, owned outright, rather than Creator Store tracks. Creator Store licenses are
      Roblox-only, so they do not cover trailers or an off-platform presence.
    - Upload from an ID-verified account so songs qualify for the game details page and "What's Playing" style
      discovery.
    - *Cost: money or time.* Risk: an Audible Magic false positive on original tracks. Keep project files and
      stems as proof of authorship.

**Not worth it for us:** acoustic simulation, emitter occlusion and angle attenuation (no 3D walls or characters), voice
chat and speech-to-text, `AudioRecorder` and `AudioWindSynthesizer` (unreleased). Text-to-speech lore narration is
possible, but the synthetic voices would undercut the "AAA" feel.

---

## 11. Sources

- Creator Hub: [Audio](https://create.roblox.com/docs/audio), [Audio objects](https://create.roblox.com/docs/audio/objects), [Audio effects](https://create.roblox.com/docs/audio/effects), [Audio assets](https://create.roblox.com/docs/audio/assets), [Sound groups (legacy)](https://create.roblox.com/docs/sound/groups), [Asset privacy](https://create.roblox.com/docs/projects/assets/privacy), [Open Cloud assets usage](https://create.roblox.com/docs/cloud/guides/usage-assets)
- Class references (via the [creator-docs repo](https://github.com/Roblox/creator-docs/tree/main/content/en-us/reference/engine/classes)): [AudioPlayer](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer), [AudioAnalyzer](https://create.roblox.com/docs/reference/engine/classes/AudioAnalyzer), [Wire](https://create.roblox.com/docs/reference/engine/classes/Wire), [AudioCompressor](https://create.roblox.com/docs/reference/engine/classes/AudioCompressor), [AudioEmitter](https://create.roblox.com/docs/reference/engine/classes/AudioEmitter), [AudioListener](https://create.roblox.com/docs/reference/engine/classes/AudioListener), [AudioChannelSplitter](https://create.roblox.com/docs/reference/engine/classes/AudioChannelSplitter), [SoundService](https://create.roblox.com/docs/reference/engine/classes/SoundService), [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService)
- API change logs: [2024](https://robloxapi.github.io/ref/updates/2024.html), [2025](https://robloxapi.github.io/ref/updates/2025.html), [2026](https://robloxapi.github.io/ref/updates/2026.html), [AudioWindSynthesizer](https://robloxapi.github.io/ref/class/AudioWindSynthesizer.html)
- DevForum announcements: [Audio API beta (Feb 2024)](https://devforum.roblox.com/t/new-audio-api-beta-elevate-sound-and-voice-in-your-experiences/2848873), [Exits beta (Sep 2024)](https://devforum.roblox.com/t/roblox-audio-api-exits-beta-enhanced-sound-controls-now-available/3153454), [Directional audio, AudioLimiter… (Dec 2024)](https://devforum.roblox.com/t/new-audio-api-features-directional-audio-audiolimiter-and-more/3282100), [Acoustic Simulation client beta (Jan 2026)](https://devforum.roblox.com/t/client-beta-acoustic-simulation-emit-audio-with-presence/4307121), [Asset privacy for audio/video (Dec 2023)](https://devforum.roblox.com/t/new-asset-privacy-and-permissions-features-for-audio-and-video/2725248), [Amplify your experiences with new music (Sep 2024 / Feb 2025)](https://devforum.roblox.com/t/amplify-your-experiences-with-new-music/3164792), [Innovation Awards 2024 winners](https://devforum.roblox.com/t/roblox-innovation-awards-2024-winners/3152047)
- DevForum community: [Deep dive](https://devforum.roblox.com/t/robloxs-new-audio-api-a-somewhat-deep-dive/3156011), [Simple guide](https://devforum.roblox.com/t/a-simple-guide-to-the-audio-api/3132049), [Overlapping one-shots](https://devforum.roblox.com/t/what-is-the-bestintended-way-to-play-multiple-audios-simultaneously-using-the-new-audio-api/3487432), [AudioPlayer should overlap](https://devforum.roblox.com/t/audioplayer-playing-should-overlap/4055469), [PreloadAsync vs AudioPlayer](https://devforum.roblox.com/t/can%E2%80%99t-preload-audio-players-using-preloadasync/4819196), [Sound instance limit test](https://devforum.roblox.com/t/total-sound-instance-limit/3736250), [Audiophile plugin](https://devforum.roblox.com/t/plugin-audiophile-a-real-time-mixing-console-for-the-new-audio-api/4719764), [AudioEngine (adaptive)](https://devforum.roblox.com/t/audioengine-an-easy-to-use-adaptive-audio-system-for-roblox/4807450), [Environmental audio tutorial](https://devforum.roblox.com/t/ambientsorcery%E2%80%99s-tutorial-1-creating-compelling-environmental-audio/3507022), [How do AudioAnalyzers work?](https://devforum.roblox.com/t/how-do-audioanalyzers-work/2909139)
- Licensing: [Audio Upload License Agreement](https://en.help.roblox.com/hc/en-us/articles/23359485439124-Audio-Upload-License-Agreement), [Using Licensed Music on Roblox](https://en.help.roblox.com/hc/en-us/articles/360000927163-Using-Licensed-Music-on-Roblox), [Using Licensed Music in Videos](https://en.help.roblox.com/hc/en-us/articles/360038525351-Using-Licensed-Music-in-Videos) (help-centre pages blocked the fetcher; content taken from search snippets), [Music Ally on DistroKid](https://musically.com/2024/09/09/roblox-moves-into-music-discovery-with-charts-and-distrokid/), [Too Lost partnership (Jul 2026)](https://www.soundstock.com/news/2026-07-29-too-lost-partners-with-roblox-to-offer-independent-music-catalog-to-game-creators)
- Games: [List of Roblox games (Arsenal, Bloxy sound award)](https://en.wikipedia.org/wiki/List_of_Roblox_games), [Sol's RNG auras](https://sol-rng.fandom.com/wiki/Auras)
