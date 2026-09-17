# 42 — The Roblox Genre Atlas: What Every Major Genre Actually Requires

> **Scope.** One profile per major Roblox genre: what it is, whether it is commercially alive, the systems it forces you to build, the specific hard problems, the performance wall you hit first, where `EditableImage`/`EditableMesh` give a defensible edge, and exemplar titles. Then four cross-cutting sections: round-based lobby architecture, what the top-100 share technically, where the genuine white space is, and the universal systems every game needs.
>
> **Evidence policy.** Roblox does not publish per-genre revenue. Official numbers come from Roblox's investor relations, newsroom, and `Roblox/creator-docs`. Everything else comes from third-party trackers (RoMonitor, RTrack, RoWatcher, Rolimon's), the DevForum, and trade press. Third-party revenue estimates are **modelled, not audited** — they are directionally useful and numerically unreliable. Claims I could not verify to a primary source are marked **[UNVERIFIED]**.
>
> **Research constraint (disclosure).** `devforum.roblox.com`, `create.roblox.com` and `about.roblox.com` were unreachable through this environment's egress proxy. DevForum/newsroom claims below are sourced from search-engine extracts of those pages plus the official `Roblox/creator-docs` GitHub mirror, which I *was* able to read directly. Engine limits quoted from creator-docs are primary-source. DevForum thread URLs are included so they can be opened and re-verified.

---

## TL;DR for builders

1. **The platform's growth engine downshifted in 2026 and it changes which genres are worth entering.** Q2 FY2026: revenue +36% to $1.5B, but *bookings* only +8% to $1.6B, and Q3 guidance was **bookings down 14–18% YoY**. DAU +10% to 123M. Roblox itself blamed "younger users shifting to lower-monetizing games" and discovery changes. Build for retention and for payers, not for raw visits.
2. **Age verification split the audience into two products.** Facial age estimation (Persona) became mandatory for chat globally by January 2026, with six age bands. DAU fell roughly 152M → 132M across that window and full-year bookings-growth guidance was cut from 22–26% to 8–12%. "All ages" is no longer a free audience.
3. **The single biggest 2026 genre signal: shooters became the top-earning category.** RIVALS topped both PC and mobile revenue in January 2026 on cosmetics and battle passes, in a genre that historically ranked ~#14 by playtime on Roblox. Skin-driven FPS monetization now beats pet-gacha monetization at the top of the chart.
4. **Roleplay/social still wins on hours; it does not win on revenue-per-hour.** Brookhaven sits near the top of CCU and all-time visits (~86.8B) but the top earners in 2026 are shooters and anime fighters. Playtime and monetization have decoupled.
5. **Simulator/incremental is not dead, it is *consolidated*.** Subgenre leaders capture a disproportionate share; the winners now are "steal/PvP-flavoured tycoon-sims" (Steal a Brainrot, Grow a Garden) rather than classic pet-hatch grinders. Entering the generic pet-sim lane in 2026 is a bad bet.
6. **Round-based lobby architecture underpins a huge fraction of the platform.** Learn the four-step pattern once: MemoryStore queue → matcher loop → `TeleportService:ReserveServer()` → `TeleportAsync()`. MemoryStore's quota is `1000 + 120 × CCU` request units/minute and `64KB + 1.2KB × users` of memory — design your queue around that, not around convenience.
7. **Your first performance wall is almost always the same three things:** draw calls (target **<1,000** on baseline devices), triangle count (**<1,000,000** on low-end), and Humanoids. Everything else is downstream.
8. **Humanoid count is the universal genre killer.** Tower defense, horror AI, RPG NPCs, and shooters all die at the same place: ~50–100 server Humanoids. The fix is identical everywhere — no Humanoid, server owns authoritative transform + state, client renders from a replicated path/spline.
9. **`EditableMesh` and `EditableImage` are real but heavily fenced.** Hard limits: EditableMesh **60,000 vertices / 20,000 triangles**, EditableImage **1024×1024 max** and **only one EditableImage can be updated per displayed frame**. Publishing with these APIs requires a 13+, ID-verified account and an explicit Creator Dashboard opt-in. Those gates are exactly why they are a moat: most competitors will not clear them.
10. **The genres where editables are transformative are the ones where the artifact *is* the game:** user-generated content sandboxes, avatar/character customization, paint/graffiti/decal systems, terrain deformation and destruction, and any "show me my own data as a picture" surface (minimaps, radar, heatmaps, progress art).
11. **Discovery now optimizes 28-day retention, not clicks.** Recommended For You evaluates Day 1 / Day 2–7 / Day 8–28 buckets across playtime, play days, qualified sessions, intentional co-play days, spend days and Robux spent — **as per-user averages**, which is why small high-quality experiences are not structurally disadvantaged.
12. **Server-authority is now affordable and expected.** Hyperion killed casual desktop exploiting, but mobile and paid executors persist. Ship the token-bucket-plus-sanity-check middleware on every remote from day one; the cost is one module.
13. **Big-number math is a solved problem — pick a library, never roll your own.** Luau `number` is a 64-bit double with ~15 significant digits and 53 bits of lossless integer precision. Use `InfiniteMath` or an arbitrary-precision library, and **never** send raw big-number objects across remotes — send a serialized `{mantissa, exponent}` pair.
14. **Universal stack recommendation, one line each:** ProfileStore for saves; a single typed `Settings` profile field; the new Audio API (`AudioPlayer`/`Wire`/`AudioEmitter`) for mixing; a context/action input layer over `ContextActionService`; `react-lua` for UI; `AnalyticsService` funnels + `GetPlayerSegmentsAsync` for analytics; remote middleware for anti-exploit; and a service-locator or ECS split (`Knit`-style services or `jecs`) over a monolithic script folder.

---

## Part 0 — The 2026 commercial baseline

Everything in the genre profiles is conditioned on these platform facts. They moved a lot in the last 12 months.

**Financials (primary: Roblox IR / earnings coverage).**

| Metric | Q2 FY2026 | Direction |
| --- | --- | --- |
| Revenue | $1.5B | +36% YoY |
| Bookings | $1.6B | +8% YoY — near low end of guidance |
| DAU | 123M | +10% YoY |
| Engagement hours | 29B | +5% YoY |
| Monthly unique payers | 27M | +15% YoY |
| Free cash flow | $294M | +66% YoY |
| **Q3 FY2026 bookings guide** | **$1.58–1.65B** | **−14% to −18% YoY** |

The gap between +36% revenue and +8% bookings is a deferred-revenue artifact; the forward guide is the real signal. Roblox attributed pressure to "younger users shifting to lower-monetizing games" and to discovery changes that favour long-term retention over near-term spend. ([gurufocus](https://www.gurufocus.com/news/8993610/roblox-corp-rblx-q2-2026-earnings-call-highlights-revenue-surges-36-to-15b-but-q3-bookings-forecast-signals-sharp-decline), [Investing.com transcript](https://www.investing.com/news/transcripts/earnings-call-transcript-roblox-q2-2026-beats-eps-but-shares-sink-on-bookings-93CH-4826338))

**The age-check discontinuity.** Roblox rolled out Persona-powered facial age estimation from November 2025 (AU/NZ/NL in December), and by **January 7, 2026** every user had to pass an age check before messaging. Six bands: Under 9, 9–12, 13–15, 16–17, 18–20, 21+. Reported effect: DAU from ~152M (Q3 2025) to ~132M (Q1 2026), an 18% single-day stock drop, and full-year bookings-growth guidance cut from 22–26% to 8–12%. ([TechCrunch](https://techcrunch.com/2026/02/06/heres-how-robloxs-age-checks-work/), [Biometric Update](https://www.biometricupdate.com/202606/roblox-shows-off-persona-age-estimation-as-it-launches-age-based-accounts), [Roblox age-estimation page](https://about.roblox.com/age-estimation))

**Design consequence:** any genre whose loop depends on free-form cross-age chat (social hangout, trading economies, roleplay) now needs *two* designs — one that works with restricted communication and one that works with full chat — or it silently loses half its funnel. This is the single most under-appreciated 2026 constraint.

**The 18+ lane is now financially privileged.** In April 2026 Roblox announced it was increasing the qualifying DevEx rate by **42%** for high-fidelity experiences aimed at 18+ players. Combined with age bands, this is the platform explicitly paying for a genre shift toward older, higher-fidelity content. ([Roblox newsroom](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42))

**Discovery.** The "Recommended For You" algorithm was rebuilt to a 28-day retention view (previously 7-day), scoring Day 1, Day 2–7 and Day 8–28 buckets across playtime, play days, qualified play sessions, intentional co-play days, spend days and Robux spent, computed as **per-user averages rather than totals**. Roblox shipped a Home Recommendations tab in Creator Analytics alongside it in December 2025. Developers reported an April 10, 2026 test that cut some games' Home impressions/CCU by 70–80% **[UNVERIFIED — developer anecdote, not an official figure]**. ([Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [DevForum announcement](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441))

**Creator economy shape.** Creators earned >$1.5B via DevEx in the March 2024–March 2025 window (+31% YoY), with Q4 2025 alone at $477M (+70% YoY). Third-party aggregation puts the top 10 creators at ~$38.5M/yr average, top 100 at ~$7M, top 1,000 at ~$980K, with ~85% of developers under $100/month and a median near $1,440/yr **[UNVERIFIED — third-party modelling]**. ([RoLearn creator economy report](https://rolearn.dev/trend-reports/creator-economy-2025-report/), [SQ Magazine](https://sqmagazine.co.uk/roblox-game-creation-and-monetization-statistics/))

**Scale records worth internalizing.** Platform peak concurrency reached ~47.4M (August 2025). Grow a Garden peaked at 22.3M CCU; Steal a Brainrot reportedly reached 25.8M; 99 Nights in the Forest 14.2M. These are not niche numbers — they mean your architecture must assume that a hit will 1000× your server count in a week, and that DataStore/MemoryStore quotas scale with CCU, not with your ambitions.

**Engine budgets you should memorize** (primary source: `Roblox/creator-docs`):

- Frame budget **16.67ms** at 60 FPS; break long work into **~5ms** chunks with `task.wait()`.
- **<1,000 draw calls** on baseline devices; **<1,000,000 triangles** for low-end devices.
- Textures **≤512×512** unless the asset occupies significant screen space; minor UI **≤256×256**. A 1024² texture costs 4× the memory of 512².
- Streaming defaults: `StreamingTargetRadius` **1024**, `StreamingMinRadius` **64**, `StreamOutBehavior` **LowMemory**; `StreamingIntegrityMode = PauseOutsideLoadedArea` recommended.
- Physics adaptive stepping runs at **60/120/240Hz**; `Fixed` mode forces 240Hz (4 steps/frame).
- MemoryStore: memory quota `64KB + 1.2KB × users`; request quota `1000 + 120 × CCU` units/minute; **1M items / 100MB** per sorted map or queue.
- EditableMesh: **60,000 vertices**, **20,000 triangles**, 4 bones/vertex, strict client-side memory budget (unlimited on server/Studio/plugins).
- EditableImage: **1024×1024 max**, buffer size `X*Y*4` bytes, and **only one EditableImage can be updated per frame on the display side**.

([performance-optimization/design.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/design.md), [workspace/streaming](https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/streaming/index.md), [EditableMesh.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableMesh.yaml), [EditableImage.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml), [memory-stores](https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md))

**The editables gate.** Publishing an experience that uses `EditableImage`/`EditableMesh` requires an account that is **13+ and ID-verified**, plus enabling "Enable Mesh / Image APIs" on the Creator Dashboard. Assets must be owned by you/your group **or explicitly shared** — shared-asset support landed April 2026, materially widening what is possible. An early beta cap of **8 concurrent editables per client** was reported; treat the current cap as "small and device-dependent" and query failure (`CreateEditableMesh` returns `nil` when the budget is exhausted) rather than assuming a number. ([Shared assets announcement](https://devforum.roblox.com/t/editablemesh-and-editableimage-now-support-shared-assets/4578818), [client beta thread](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293), [remove-limit request](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561))

---

# Genre profiles

Each profile uses the same six headings: **(a) What it is & commercial reality · (b) Core systems · (c) Hard problems · (d) Performance profile · (e) Editable-asset edge · (f) Exemplars.**

---

## 1. Obby / platformer / parkour

**(a) What it is & commercial reality.** The platform's native genre: timed or checkpointed traversal of hazard geometry. Third-party genre aggregation puts "platformer" at roughly **70M daily visits** across the Q1 2021–Q2 2025 window, behind roleplay (~116M) and simulation (~110M) **[UNVERIFIED — third-party aggregation]**. It is emphatically **not dead**: Tower of Hell holds ~20B+ lifetime visits and won Best Obby at the 2024 Roblox Innovation Awards, and Eternal Towers of Hell roughly *doubled* its average CCU in 2025.

It is, however, **the most saturated and worst-monetizing large genre on the platform**. The honest read for 2026: the genre bifurcated. Pure skill obbies (difficulty-chart towers, JToH-lineage) have a small, extremely loyal, low-spending audience. The commercially live branch is the hybrid — obby movement wrapped in gacha/collection/RNG progression ("Obby RNG"-type games), which is really an incremental game wearing a platformer's clothes. **If you enter this genre for money, you are actually entering genre #2.**

**(b) Core systems.**
- Checkpoint/progress persistence (stage index in a leaderstat + profile field), respawn CFrame handling.
- Procedural tower/stage assembly from a curated section pool with difficulty weighting (Tower of Hell's model: no checkpoints, randomly assembled tower, fixed timer, then regenerate).
- A movement layer: most serious obbies override or augment the default Humanoid controller (custom jump buffering, coyote time, ledge-grab, slide, wall-jump, air control).
- Kill/lava zones, moving platforms (tween/CFrame, not physics), conveyor surfaces, rotating hazards.
- Timer, leaderboard (OrderedDataStore or MemoryStore sorted map), spectate.
- Difficulty telemetry: per-stage death counts and time-to-clear are the genre's single most valuable analytics.

**(c) Hard problems.**
1. **Anti-cheat is genuinely hard here and is the genre's defining technical problem.** The game *requires* teleporting the character (respawns, checkpoints), so naive "magnitude since last tick" fly/teleport detection produces false positives on every legitimate respawn. The working pattern from DevForum practice: the server owns a `LegitimateTeleport` flag with a short expiry window, validates that every claimed checkpoint is `previousStage + 1` (never trust a claimed stage index), and rate-limits stage advancement against a per-stage minimum-possible-time floor. Note that exploiters can and do spoof replicated CFrame, so position-based detection is a *heuristic*, not a gate. ([anti-cheat for an obby](https://devforum.roblox.com/t/good-anti-cheat-for-an-obby/3576031), [detect CFrame fly](https://devforum.roblox.com/t/how-to-detect-cframe-fly/4565703), [anti-CFrame-teleport/anti-fly](https://devforum.roblox.com/t/how-to-make-anti-cframe-teleport-and-anti-fly/2926379))
2. **Moving-platform feel.** Standing on a tweened part gives the classic Roblox "slide off the platform" problem because the character is not welded to it and physics resolution lags the tween. Fixes: weld-on-touch with a `AlignPosition` follower, or move platforms with `CFrame` inside `PreSimulation` so physics sees a consistent position, or make the player's own client own the platform's network ownership while standing on it.
3. **Determinism across clients.** If your tower is procedurally generated, every client must see the same tower. Generate server-side from a seed, replicate the seed, and let clients reconstruct — do not replicate 3,000 parts.
4. **Difficulty calibration without a designer.** Procedural obbies need a section-difficulty model; the only reliable calibration signal is live per-section death telemetry.

**(d) Performance profile — what breaks first.** Part count and draw calls. A tower assembled from 40 hand-built sections trivially exceeds 50,000 parts; the creator-docs guidance is to start merging geometry past that point. Second failure: `Touched` events. `Touched` on every kill-brick, at 30+ players, is a Luau and physics-callback firehose — replace with a per-player `PreSimulation` region check or `workspace:GetPartBoundsInBox` against a small set of zones. Third: tween churn on hundreds of moving platforms, which should be a single manager loop writing CFrames, not hundreds of `TweenService` instances.

**(e) Editable-asset edge.**
- **Procedural section geometry.** `EditableMesh` lets you generate hazard geometry (spinning blades, warped ramps, spline-following catwalks) at runtime instead of shipping hundreds of MeshParts — fewer unique assets, more variety, and *sections that have never existed before*, which is a real differentiator in a genre whose entire value proposition is novelty. Watch the 20,000-triangle ceiling per mesh.
- **`EditableImage` for run visualization.** Render the player's route, death heatmap, or a personal "ghost trail" as a generated texture on a trophy/plaque. Cheap, unique, and impossible to copy by re-uploading assets.
- **Honest limit:** the one-EditableImage-update-per-frame display constraint means you cannot animate several generated textures at once. Budget it as "one live canvas."

**(f) Exemplars.**
- **Tower of Hell** (YXceptional Studios) — the reference architecture: sectioned procedural tower, no checkpoints, global timer, round loop, ~20B+ visits. Its design thesis is that *regeneration replaces content*.
- **Eternal Towers of Hell** — the difficulty-chart lineage; near-doubled average CCU in 2025, proving the hardcore branch is growing even as it doesn't monetize well.
- **Obby RNG-family titles** — the hybridization proof: platforming as the input to a gacha economy.
- **Steep Steps** — momentum-based climbing with a punishing fall-loss loop; a good study in how *loss aversion*, not stage count, drives session length.

---

## 2. Simulator and incremental / idle (pet-hatching, rebirth, big numbers)

**(a) What it is & commercial reality.** Click/collect → convert to currency → buy multiplier → rebirth → repeat, with a gacha layer (pets, eggs, auras) supplying the variable-ratio reward. Third-party aggregation puts simulation at ~**110M daily visits** and notes simulator revenue roughly doubled since 2018 **[UNVERIFIED]**.

The truthful 2026 read: **the classic pet-hatching simulator lane is saturated and declining, while its mutant offspring are the biggest games on the platform.** Grow a Garden (March 2025; fastest experience ever to 1B visits — 33 days; 22.3M peak CCU; ~$12M in May 2025 alone) and Steal a Brainrot (May 2025; ~68.7B visits by mid-2026; reported 25.8M peak CCU) are both structurally incremental games, but each added a second axis: *asynchronous persistence with real-time growth* (Grow a Garden) and *adversarial PvP theft* (Steal a Brainrot). Plain "hatch pets, get bigger number" without a social or adversarial axis is a dead entry point in 2026.

Note the counter-signal from the platform: Roblox explicitly cited "younger users shifting to lower-monetizing games" as a bookings headwind. The brainrot-simulator wave drives enormous hours at low ARPU. That is exactly why discovery was retuned to 28-day retention.

**(b) Core systems.**
- **Big-number arithmetic and formatting** (see below).
- Multiplier/stat aggregation pipeline: base × pet × rebirth × gamepass × event × potion, recomputed on any change, cached per player.
- Gacha with server-authoritative RNG, published odds, pity counters, and duplicate-conversion.
- Rebirth/prestige ladder with a currency reset and a permanent multiplier.
- Inventory at scale: thousands of items per player, with equip slots, mass-delete, mass-craft.
- Trading (if enabled) with two-sided confirm, server-side item escrow, and an immutable trade log.
- Extremely heavy UI: 15–40 distinct screens, all of which must be virtualized.
- Offline/AFK progression accrual computed from a server timestamp delta.

**(c) Hard problems.**
1. **The big-number problem.** Luau `number` is a 64-bit IEEE-754 double: range ±~1.7e308, ~15 significant decimal digits, **53 bits of lossless integer precision**. Incremental games blow through 2^53 within hours of launch and through 1e308 within weeks of a mature meta. Consequences if you ignore it: currency silently stops incrementing (adding 1 to 2^53 is a no-op), then becomes `inf`, and `inf` serialized to a DataStore corrupts profiles.
   - **The fix:** adopt a library. `InfiniteMath` (mantissa/exponent representation, explicitly built to pass 1e308) is the pragmatic default; `helloGMP` is the arbitrary-precision option when you need exactness (e.g. a trading economy where rounding is exploitable).
   - **Serialization rule:** never persist or replicate a big-number *object*. Persist `{m = <double>, e = <integer>}` and reconstruct. Objects with metatables do not survive DataStore round-trips or `RemoteEvent` marshalling.
   - **Comparison rule:** with mantissa/exponent, `a > b` must go through the library. A single accidental `if coins > price` on raw tables is a silent economy break.
   - **Formatting:** suffix tables (K/M/B/T/qd/Qn…) run out; beyond ~e36 switch to scientific or "aa/ab/ac" alphabetic notation, and make the choice a player setting.
   ([Luau numbers doc](https://create.roblox.com/docs/luau/numbers), [InfiniteMath](https://github.com/KdudeDev/InfiniteMath), [helloGMP](https://devforum.roblox.com/t/hellogmp-pure-luau-arbitrary-precision-math-library-for-roblox-studio/4175011), [native bigint request](https://devforum.roblox.com/t/luau-big-number-big-integer-that-runs-natively/2596674))
2. **UI is the game.** These titles are 60–80% interface. Naive implementations instantiate one `Frame` per inventory item and die at 2,000 pets. You need a virtualized scroller (render only visible rows, recycle frames from a pool), a diff-based update path (never rebuild a list on every currency tick), and currency labels updated on a throttled tick (10Hz) rather than per-change.
3. **Economy telemetry and inflation control.** Every source and sink needs an analytics event. Without a source/sink ledger you cannot diagnose why your economy inflated, and incremental economies *always* inflate.
4. **Gacha integrity.** Roll on the server, log the seed and result, and never let the client know the outcome before the server does. Client-side "preview" rolls are the most commonly exploited system in the genre.
5. **Save size.** A mature simulator profile (10k items, 200 stats, 50 quests) can approach DataStore value limits. Solutions: dictionary-key compaction (`{p=1,q=3}` not `{petId=1,quantity=3}`), run-length encoding of item stacks, and splitting rarely-touched history into a second key.

**(d) Performance profile — what breaks first.** (1) **GUI instance count and per-frame layout** — `UIGridLayout`/`UIListLayout` recomputation over thousands of children is the #1 client stall in this genre. (2) **Luau heap growth** from per-item tables and un-disconnected connections; creator-docs explicitly flags growing `LuaHeap` as a leak signal. (3) **Server `Heartbeat` load** from per-player per-pet tick loops — aggregate into a single manager iterating a flat array, not `n` coroutines. (4) **Replication churn** — updating a `NumberValue` per pet per tick is a network disaster; batch state into one throttled remote payload.

**(e) Editable-asset edge.**
- **Procedurally generated pet/aura variants via `EditableImage`.** The genre's entire monetization is "rarity you can see." Today rarity is expressed by pre-uploaded textures, which caps how many distinct visual variants you can ship and lets competitors copy them wholesale. Generating the texture at runtime from a seed (palette shift, pattern overlay, glow mask, shiny/rainbow/corrupted treatments) gives you a combinatorially unbounded rarity space and makes the *generator* — not the asset list — your IP. Cost: one canvas per frame, so generate to an offscreen image and cache to a `Content` reference rather than re-rendering.
- **`EditableMesh` for size/shape mutation.** "Mega/Titanic/Huge" variants today are just scaled MeshParts. Runtime vertex deformation (bulges, spikes, melted/corrupted forms) creates a mutation axis that cannot be replicated by asset scraping.
- **Generated stat cards / inventory thumbnails** as a single EditableImage atlas: render each pet's card once into an atlas texture, then display via UV offsets. This is one of the few ways to show 2,000 distinct item icons without 2,000 ImageLabels and 2,000 asset fetches.

**(f) Exemplars.**
- **Grow a Garden** — built initially in days by a 16-year-old (BMWLux), scaled by Splitting Point Studios with Do Big Studios as dev/distribution partner. 22.3M peak CCU; fastest to 1B visits (33 days). Architecturally it is an idle game whose key innovation is *real-time offline growth that makes logging off part of the loop*.
- **Steal a Brainrot** (BRAZILIAN SPYDER / Do Big Studios) — conveyor purchase + base defence + PvP theft. The steal mechanic converts a solo incremental loop into a social one, which is exactly what discovery's "intentional co-play days" signal rewards.
- **Pet Simulator 99 (BIG Games)** — the reference implementation of the mature pet-gacha stack: enormous inventories, trading, seasonal resets. Study it for inventory/trading architecture, not for a business plan.
- **Blox Fruits** — ~61.5B visits; technically an action RPG but economically an incremental game with a gacha (fruit) layer.

---

## 3. Tycoon (classic dropper and modern variants)

**(a) What it is & commercial reality.** Buy button → part appears → dropper emits value → conveyor → collector → currency → next button. Third-party estimates put classic tycoon revenue around $4M in 2025 across the genre **[UNVERIFIED]** — small. As a *pure* genre, the dropper tycoon is a beginner's project and commercially marginal.

But the **modern variant is the single most commercially important structure on the platform right now.** Steal a Brainrot is explicitly categorized as a tycoon: a base you build up, an income stream, and a PvP layer that puts that income at risk. Every "Brainrot/Steal/Defend" game is a tycoon with theft. The classic dropper is dead; the tycoon *skeleton* — personal plot, incremental unlocks, visible progress — is the most-cloned structure in 2026.

**(b) Core systems.**
- Plot allocation and lifecycle: claim on join, release on leave, reset or persist.
- Button → unlock dependency graph (a DAG, serialized as a set of owned node IDs).
- Dropper/collector income pipeline.
- Save/restore of the owned-node set (this is the whole save file — a bitfield or array of IDs, not a snapshot of the world).
- Multi-plot server scaling: 6–12 plots × the full tycoon cost each.
- Modern additions: raid/steal mechanics, base defence (shields, walls, turrets), rebirth, and a leaderboard.

**(c) Hard problems.**
1. **Dropper physics is the genre's signature performance disaster and it is *entirely avoidable*.** DevForum reports are consistent and damning: purely server-side droppers with ~40 droppers in one base cause visible stutter; one developer measured **~150 KB/s physics replication and ~200ms average ping** from server-simulated drops alone. Physics-simulated drop parts are the single worst idea in Roblox game design because each is an unanchored assembly the server must simulate *and* replicate to every client.
   - **The correct architecture:** the server never spawns a drop. The server maintains a scalar income rate per plot and credits currency on a timer. The *client* renders purely cosmetic drops — anchored parts moved by a single `CFrame` loop along a precomputed conveyor spline, drawn from an object pool, with no physics and no replication. Sanity-check by comparing credited income against the server's own rate model, not against client-reported drop counts.
   - ([dropper optimization](https://devforum.roblox.com/t/tycoon-dropper-optimization/1732295), [physics KB/s + ping](https://devforum.roblox.com/t/optimizing-dropper-physics-in-my-tycoon-game-%E2%80%93-high-physics-kbs-ping-issues/3464339), [tycoon optimization & architecture](https://devforum.roblox.com/t/tycoon-optimization-and-architecture/4574342))
2. **Plot instancing cost.** Eight plots × 800 parts = 6,400 parts of mostly-invisible geometry. Use `StreamingEnabled` with per-plot `Atomic` models, or keep unbuilt geometry in `ServerStorage` and parent on purchase. Never pre-place all eight fully-built tycoons and hide them with transparency — they still cost memory and draw calls.
3. **Abandonment and re-claim.** What happens when a player leaves mid-build? The honest options are: destroy and free the plot (most games), or persist and require a slot. Persisting other players' bases in a public server is a scaling trap.
4. **In modern variants: theft arbitration.** Two players contesting the same item is a classic race. The server must own the item's `heldBy` field and resolve claims atomically; client-predicted pickups will desync.

**(d) Performance profile — what breaks first.** Physics parts (if you got the architecture wrong), then instance count from plot geometry, then `Touched` on collectors. A well-built tycoon has essentially **zero** unanchored parts in steady state.

**(e) Editable-asset edge.** Weakest of any genre on this list, and you should be honest about that. The genuine opportunities:
- **Player-customized base aesthetics via `EditableImage`** — letting players paint/decal their factory walls, sign their base, or apply a generated faction pattern. This is the "make my base mine" axis that tycoons structurally lack.
- **`EditableMesh` for visible upgrade morphing** — a machine that physically grows/changes silhouette as it levels, rather than being swapped for a different MeshPart. Modest but real differentiation.
- Skip editables for the income pipeline entirely; there is nothing there for them.

**(f) Exemplars.**
- **Steal a Brainrot** — the modern template. Conveyor → purchase → base → steal → shield. ~68.7B visits.
- **Miner's Haven** (legacy) — still the deepest study of a tycoon *as an optimization puzzle* with multiplicative upgrader chains; its ore-as-entity model is exactly the physics trap described above, and studying where it strains is instructive.
- **Lumber Tycoon 2** — tycoon fused with a player-driven resource market and a genuinely persistent world; unusual and still unmatched in its niche.
- **Car Dealership Tycoon** — tycoon skeleton + vehicle collection; shows how to bolt a collection meta onto a plot game.

---

## 4. First/third-person shooter

**(a) What it is & commercial reality.** **The biggest genre story of 2026.** Historically shooters ranked around **#14 by playtime** on Roblox — a genre that dominates PC/console (Newzoo ranks shooters #1 by playtime across PC/PlayStation/Xbox) and was structurally weak on Roblox. That inverted: **RIVALS topped both PC and mobile revenue charts in January 2026**, at roughly 400K CCU and an estimated $8–15M/month **[UNVERIFIED — third-party revenue model]**, monetizing almost entirely through weapon skins and battle passes.

Why this matters strategically: it proves that (i) cosmetic-skin monetization works on Roblox at the very top of the chart, (ii) an older, more skill-motivated audience exists and spends, and (iii) the genre has room because *technical difficulty kept competitors out*. It is the clearest current example of a genre where engineering quality is the moat. It is also, therefore, the genre where being second-rate is most punished — there is no "good enough" hit registration.

**(b) Core systems.**
- **Client-predicted firing + server-authoritative validation with lag compensation** (see below).
- Weapon definition data (fire rate, damage falloff curve, spread/bloom model, recoil pattern, magazine, reload timings, penetration, muzzle velocity).
- Viewmodel rig with procedural sway/bob/ADS interpolation running on `RenderStepped`.
- Recoil model: a deterministic per-shot pattern (vertical climb + horizontal drift, optionally seeded per-magazine so it is learnable) plus visual-only camera kick that decays back to the aim point.
- Projectile or hitscan system. Phantom Forces uses **non-hitscan projectiles with travel time and gravity at 196.2 studs/s²** (Roblox's standard gravity), simulated client-side and validated server-side.
- Round/objective state machine, team assignment, respawn, killfeed, scoreboard, spectate.
- Progression: XP, unlocks, skins, battle pass, case/crate economy.
- Ranked matchmaking with MMR (MemoryStore sorted map + reserved servers).

**(c) Hard problems.**
1. **Hit registration under latency — the defining problem.** The two naive options are both wrong: trusting the client is exploitable; raycasting on the server against *live* positions punishes every high-ping player, because by the time the shot arrives the target has moved. The correct technique is **server-side rollback/rewind**, standard in Counter-Strike and Overwatch and now available on Roblox as open-source modules:
   - Keep a ring buffer of every character's hitbox transforms for **~0.5–1.0 seconds** of history, sampled at a fixed rate.
   - Client sends the shot with its own tick/timestamp.
   - Server clamps that timestamp to a legal window (this clamp is the anti-cheat — an unbounded rewind is a time-travel exploit), rewinds all hitboxes to that moment, raycasts or does OBB intersection in the historical frame, then restores.
   - `RollbackHitbox` and `Rewind` are production-oriented implementations of exactly this. ([RollbackHitbox](https://devforum.roblox.com/t/rollbackhitbox-server-authoritative-lag-compensation-for-roblox-shooters-open-source/4553295), [Rewind](https://devforum.roblox.com/t/rewind-server-authoritative-lag-compensated-hit-validation/4160622), [laggy players can't register hits](https://devforum.roblox.com/t/laggy-players-cant-register-weapon-hits-best-way-to-get-around-without-trusting-the-client/377314))
2. **Roblox character replication is not built for this.** Default character replication is position-interpolated at a modest rate and is not timestamped for you. Serious shooters build a **custom character replication layer**: the client sends compressed transform+state at a fixed tick, the server stores the history, and other clients interpolate with a deliberate render delay (typically 100–150ms behind server time). `Rewind` ships this as "custom character replication" for exactly this reason.
3. **Anti-cheat under Hyperion.** Hyperion (Byfron, acquired October 2022, shipped in the 64-bit Windows client May 2023) ended casual desktop exploiting; paid executors and mobile remain. For a shooter this means: server-side ammo/fire-rate/reload state, rejection of shots whose origin is implausible relative to the last validated position, headshot-rate and time-to-kill outlier detection, and — critically — **never** ship damage numbers from the client. Reports of ML-assisted Hyperion bypasses in January 2026 circulate but come from low-quality sources **[UNVERIFIED]**.
4. **Bullet penetration and wallbangs** need a repeated-raycast loop with material-dependent damage falloff, and must run identically in the rewound server frame — meaning your penetration code has to be shared between client prediction and server validation. Any divergence is a desync complaint.
5. **Mobile parity.** A large share of players are on touch. Aim assist, auto-fire, gyro, and a separate recoil tuning pass are not optional; they are the difference between a top-10 shooter and a PC-only niche title.

**(d) Performance profile — what breaks first.** (1) **Network** — per-shot remotes at 10 players × 600 RPM is 100 events/second; batch shots per frame and compress payloads (quantize directions to 16-bit, pack into `buffer`). (2) **Particle/effect churn** — tracers, impacts, muzzle flashes, blood. Pool everything; unpooled `Instance.new` in a firefight is a GC storm. (3) **Server raycast cost** with rollback — rewinding N characters per shot is O(shots × players); use `RaycastParams` whitelists and consider running validation in a Parallel Luau actor. (4) **Draw calls** from detailed weapon models — a hero viewmodel can quietly consume a large slice of a 1,000-draw-call budget.

**(e) Editable-asset edge.**
- **Runtime-generated weapon skins.** This is the strongest editables opportunity in any genre, because RIVALS proved skins are the revenue engine. `EditableImage` lets you generate skins procedurally — pattern seeds, palette swaps, wear/battle-scarring, kill-count-driven evolution, player-authored decals — which converts a finite catalogue into an unbounded one and creates genuine one-of-one items. CS:GO's float/pattern-index economy is the proof that procedural skins print money; nobody on Roblox has properly built it because the API gate (13+, ID-verified, dashboard opt-in) filters out most competitors.
- **Player-authored decals/stickers on weapons** with moderation applied to the *source* image — a real UGC monetization axis.
- **Dynamic damage/bullet-hole decals** painted directly into a shared surface texture instead of spawning decal parts. This kills the classic "500 bullet-hole parts" performance leak outright, and there is a documented DevForum approach for painting large surfaces from ordinary raycasts. ([painting large surfaces with EditableImage](https://devforum.roblox.com/t/use-of-editableimage-for-efficiently-painting-on-large-surfaces-globally-using-regular-raycasts/3673162))
- **`EditableMesh` for attachment-driven weapon geometry** — building the rendered weapon mesh from a modular part set at runtime rather than pre-authoring every attachment combination.

**(f) Exemplars.**
- **RIVALS** (Nosniy Games, launched May 2024) — round-based competitive FPS; #1 revenue January 2026; ~287K average CCU in March 2026; skins + battle pass. The lesson: consistent meaningful updates plus a tight round loop, not one hero feature.
- **Phantom Forces** (StyLiS Studios) — the technical ancestor. Non-hitscan ballistics, gravity at 196.2 studs/s², bullet drop, per-weapon muzzle velocity, an in-game Ballistics Tracker attachment that compensates drop. Still the reference for ballistic realism on the platform. ([Ballistics Tracker](https://roblox-phantom-forces.fandom.com/wiki/Ballistics_Tracker), [combat mechanics](https://roblox-phantom-forces.fandom.com/wiki/Mechanics/Combat))
- **Arsenal** — the arcade counterweight: hitscan, gun-game rotation, very low time-to-kill, minimal netcode ambition. Proves you can succeed without rollback *if* your design tolerates imprecision.
- **Deadline / Hypershot / Sniper Arena** — the second wave chasing RIVALS; useful for seeing which parts of the stack new entrants skip (usually: lag compensation).

---

## 5. Survival / crafting / base-building

**(a) What it is & commercial reality.** Gather → craft → build → defend, usually against a day/night cycle. Third-party aggregation puts survival at ~**70M daily visits [UNVERIFIED]**. This genre is **the clearest growth story of 2025–26 after shooters**. 99 Nights in the Forest (Grandma's Favourite Games, NZ; dev Alec Kieft / "Cracky4") hit a **14.2M peak CCU** and ~442K CCU in steady chart positions — numbers PC survival games would never see. Its arrival signalled that co-op survival with a hard fail state works on Roblox, which was not obvious before.

The genre is **growing and under-built**. There are many survival *skins* on simulators, but very few games with real crafting trees, real base persistence, and real resource scarcity. It is one of the best risk-adjusted entries in 2026.

**(b) Core systems.**
- Inventory: slot/grid model, stacking rules, weight or slot limits, hotbar, containers, drag-and-drop with server-validated moves.
- Crafting: recipe graph, station requirements, timed crafts, queue.
- Resource nodes: spawn tables, respawn timers, per-node depletion state, tool-tier gating.
- Placement system: ghost preview, grid snap, surface/normal alignment, collision and overlap validation, rotation, stacking/snapping to sockets.
- Structural integrity (optional but genre-defining): support propagation so unsupported structures collapse.
- Day/night cycle driving spawn and light state.
- Hunger/temperature/health stat decay loop.
- Base persistence: serialize a placed-object list `{id, cframe, ownerId, health, data}` and rebuild on load.
- Co-op: shared containers, shared base ownership, permissions.

**(c) Hard problems.**
1. **Placement is deceptively hard and it's where most implementations are visibly bad.** The core loop is: raycast from camera (ignoring the ghost and the character), snap the hit position to a grid (`math.round(p / gridSize) * gridSize`, applied in the *plot's* local space, not world space), align rotation to the surface normal, then validate with `workspace:GetPartBoundsInBox` against a collision group before committing. The recurring DevForum failure modes are (a) snapping in world space so rotated plots misalign, (b) not handling objects whose size is not a grid multiple — you must offset by `size % gridSize / 2`, and (c) doing validation only on the client. `GridPlacer` is the mature community module and worth reading even if you write your own. ([GridPlacer](https://devforum.roblox.com/t/gridplacer-highly-featured-module-for-part-placement-rotation-and-snapping-to-grid/2096210), [how to make a working grid system](https://devforum.roblox.com/t/how-to-make-a-working-grid-system-in-roblox/1575157), [different-sized block snapping](https://devforum.roblox.com/t/how-to-snap-to-grid-a-different-sized-block-in-a-block-building-system/2851458))
2. **Server-authoritative inventory with a responsive client.** The client must predict moves to feel good, but the server owns truth. The standard pattern: client applies optimistically, sends `(fromSlot, toSlot)`, server validates and either acks or sends a corrective full-inventory snapshot. Never send item *instances* — send IDs into a shared item definition table.
3. **Base persistence cost.** A 500-object base per player, 20 players, is 10,000 objects to serialize. Use compact records (integer ids, quantized CFrames — position to 0.1 stud as int16s, rotation as a 6-bit orientation index for grid games) and store the definition table version so you can migrate.
4. **Duplication exploits.** Every survival game gets dupe-attacked. Mitigations: server-side item UIDs, atomic transfer (remove-then-add inside one server-side operation, never two remotes), and a per-player transaction log that can be replayed.
5. **Structural integrity at scale** is a graph traversal on every destruction event. Precompute support graphs and only re-traverse the affected component.

**(d) Performance profile — what breaks first.** (1) **Instance count from placed objects** — a well-played server accumulates tens of thousands of parts; this genre *must* use `StreamingEnabled` with per-base `Atomic` models. (2) **Physics** if placed objects are unanchored — anchor everything and fake collapse with a short-lived physics burst. (3) **Server Luau** from per-node respawn timers implemented as per-node coroutines — use one manager with a sorted-by-deadline array. (4) **Replication spikes** when a base loads; creator-docs explicitly advises loading maps in chunks across multiple frames.

**(e) Editable-asset edge.** Strong, and underexploited.
- **Terrain deformation with `EditableMesh`.** Mining, digging, chopping that actually changes the world geometry rather than swapping a "stump" model. Roblox's voxel Terrain gives you deformation but not arbitrary meshes; `EditableMesh` gives you carved tunnels, hollowed trees, sculpted earth. The DevForum has active work on parallel-generated EditableMesh terrain, and the honest caveat is that it is *hard* and the 20k-triangle-per-mesh cap forces chunking. ([procedural terrain with EditableMeshes in parallel](https://devforum.roblox.com/t/procedural-terrain-generation-using-editablemeshes-in-parrallel/4582100), [editable mesh terrain](https://devforum.roblox.com/t/editable-mesh-terrain/3809642))
- **Progressive damage on structures.** Instead of three damage-state models, deform the mesh and paint scorch/crack textures with `EditableImage`. Continuous damage state is a genuinely new feel on Roblox.
- **Player-painted bases.** Signage, flags, camo patterns, clan marks — the single cheapest way to make bases feel owned, and it composes directly with moderation (filter the source, not the pixels).
- **Generated map/minimap** from the actual explored world, which is both a UX win and exactly the demonstrated `EditableImage` + Parallel Luau use case. ([realtime minimap using EditableImage & Parallel Luau](https://devforum.roblox.com/t/realtime-minimap-using-editableimage-parallel-luau/2776543))

**(f) Exemplars.**
- **99 Nights in the Forest** — 14.2M peak CCU; day/night survival with classes, base building, cooking (crockpot recipe system), and a deer boss. The design lesson is that a *bounded run* (99 nights) plus co-op plus a visible fail state beats an open-ended sandbox for retention.
- **Lumber Tycoon 2** — persistent world, player market, genuinely scarce resources; the deepest crafting economy on the platform and still without a real successor.
- **Build a Boat for Treasure** — block placement + physics validation as the core loop; the best study of "placement system as gameplay."
- **Rust-likes / DayZ-likes on Roblox** — consistently attempted, consistently fail on base persistence and raid scheduling. That failure mode is the opportunity (see white space).

---

## 6. Horror and atmospheric

**(a) What it is & commercial reality.** Healthy and durable, with a strong social-co-op skew. DOORS (LSPLASH, August 2022) remains a platform landmark; Forsaken and Dandy's World are "the big two" of the current asymmetric-horror wave; 99 Nights in the Forest is often classed in the horror/survival adjacency and posts ~442K CCU. Notably, horror monetizes modestly per-hour but retains extremely well, which is exactly what 28-day-retention discovery rewards.

The genre's commercial reality is that **pure single-player horror is a poor Roblox fit** (no social loop, short session, no repeat purchase) while **co-op and asymmetric horror are among the best-performing round-based structures on the platform.**

**(b) Core systems.**
- Lighting/atmosphere stack: `Lighting.Technology = Future`, near-black `Ambient`/`OutdoorAmbient`, `Atmosphere` with high `Density` and tuned `Haze`/`Glare`, short `FogEnd`, a flashlight with a `SpotLight` plus a shadow-casting attachment.
- Audio: layered ambience bed + stingers + proximity-driven monster audio. The new Audio API (`AudioPlayer` → `Wire` → `AudioEmitter` → `AudioListener`, with `AudioFader`, `AudioEqualizer`, `AudioCompressor`, `AudioLimiter`, `AudioEcho` and directional `AngleAttenuation`) makes real mixing possible for the first time.
- Pursuit AI: state machine (Idle → Suspicious → Search → Chase → Lost) driven by sight cones, sound events, and a last-known-position memory.
- Procedural room generation (DOORS model).
- Jumpscare sequencer: camera lock, animation, audio, post-processing, and a hard-coded duration with input suppression.
- Sanity/stamina/hiding systems.
- Round/floor progression and death/spectate handling.

**(c) Hard problems.**
1. **Pacing is a *scheduling* problem, not an art problem.** The genre's real technical system is a **director**: a server-side module that tracks time-since-last-scare, player stress proxies (heart-rate substitute: recent damage, proximity events, sprint usage), and gates the next event behind a minimum-quiet interval. Without one, you get either constant noise (players desensitize in 3 minutes) or dead air. This is the system most Roblox horror games do not have and it is why most of them are not scary past the first run.
2. **Jumpscare timing under latency.** A jumpscare must be *client-driven* to land on frame, but *server-authorized* to be fair. Pattern: server decides "entity X scares player Y now," sends one remote, the client runs the whole sequence locally (camera, sound, post-FX) and reports completion; the server applies the damage/death independently on its own timer so a client that suppresses the remote still dies.
3. **Pursuit AI without Humanoids.** `PathfindingService` + `Humanoid:MoveTo` for 8 entities across 12 servers is fine; for a chase entity that must move fast and smoothly through a generated corridor it is not. Precompute the room graph during generation and move the entity along a spline by CFrame, using pathfinding only for off-graph recovery.
4. **Procedural generation determinism.** DOORS' model — a seeded path from Door 0 to Door 100, each room assigned a type (hallway, four-way, dead-end with loot), with scripted fixed rooms at specific door numbers and a *fixed linear path* substituted during Seek chase sequences — is the canonical approach and worth copying wholesale. Generate on the server from a seed, stream rooms in ahead and destroy behind. ([DOORS room generator package](https://devforum.roblox.com/t/doors-room-generator-package/3157691), [room generation approaches](https://devforum.roblox.com/t/what-is-a-good-approach-for-room-generation/4015405))
5. **Darkness vs. mobile rendering.** `Future` lighting with many shadow-casting lights is the most reliable way to destroy a mobile frame rate. You need a lighting quality tier that swaps dynamic shadows for baked/faked darkness on low-end devices without making the game unplayable (too dark on a phone screen in daylight is its own failure).

**(d) Performance profile — what breaks first.** (1) **Lights.** Each shadow-casting `PointLight`/`SpotLight` under `Future` is expensive; cap concurrent shadow-casters (4–6) and disable shadows on decorative lights. (2) **Post-processing stacks** (blur + colour correction + bloom + depth of field simultaneously) are a mobile killer. (3) **Room instance churn** during generation — pool rooms, don't `Destroy`/`Instance.new`. (4) **Audio instance count** — the new Audio API's wire graph is cheaper than dozens of ad-hoc `Sound` objects, but an emitter per prop still adds up.

**(e) Editable-asset edge.**
- **The flashlight-as-canvas.** Painting discovered geometry into an `EditableImage` "memory map" — the player's own hand-drawn map of where they have been — is a mechanic (Darkwood/Lethal-Company-style) that no Roblox horror game currently ships and that cannot be faked with pre-made assets.
- **Dynamic gore/blood/decay painted onto surfaces** rather than spawned as decal parts: same performance argument as bullet holes, and far better looking as it accumulates.
- **`EditableMesh` entity deformation** — an entity that visibly warps, elongates, or fragments as it closes distance. Horror's currency is the uncanny, and runtime deformation is the only way to get genuinely non-repeating uncanny on this platform.
- **Procedural "wrongness" in generated rooms** — subtly warping wall meshes as sanity drops. Cheap to implement (vertex displacement on a copy), impossible to achieve with static assets.

**(f) Exemplars.**
- **DOORS** (LSPLASH — LightningSplash & RediblesQW) — seeded procedural hotel, typed rooms, scripted set-pieces at fixed door numbers, entity roster with distinct counterplay, linear-path substitution during Seek chases. The most-copied horror architecture on Roblox.
- **Forsaken** — asymmetric survivors-vs-killers with playable killers, per-character abilities, and randomized generator mechanics. Community analysis consistently attributes its edge over Dandy's World to *playable killers* and *randomized rather than skill-check-gated objectives* **[UNVERIFIED — fan analysis]**.
- **Dandy's World** — co-op mascot horror; machine-completion objectives; alpha June 2024.
- **Pressure / Apeirophobia** — the "atmosphere over monster" school; study their fog/lighting curves and sound layering.

---

## 7. RPG / open world

**(a) What it is & commercial reality.** Quests, levelling, gear, a large explorable world. Commercially this is dominated by **anime action-RPGs**, not Western-style RPGs: Blox Fruits (~61.5B visits) is the category king, and anime fighting/adventure titles are consistently the fastest-growing revenue cluster (an anime fighting game, Gakuran, was reportedly the #1 earner in August 2026 at only ~30K CCU — an extraordinary revenue-per-user figure **[UNVERIFIED]**).

The read: **"RPG" on Roblox means "anime progression game with combat" and that lane is crowded but enormous.** Traditional quest-driven Western RPGs are rare, and rare for a reason — they need content volume Roblox teams rarely sustain. The middle ground (a real open world with real quests and a real combat system) is genuinely under-served, but it is the highest-content-cost genre on the platform.

**(b) Core systems.**
- Streaming world (`StreamingEnabled`, chunked assets, `Persistent`/`Atomic` models for gameplay-critical structures).
- Quest system: a data-driven definition table, per-player state machine, objective trackers hooked to game events, and a save format that survives quest-definition edits.
- Dialogue: node graph with conditions, one-shot flags, and localization keys.
- Inventory + equipment + stat aggregation.
- Levelling/XP curves, skill trees, respec.
- Combat (see genre 11).
- NPCs: dialogue, vendors, wandering, spawn management.
- Loot tables with weighted drops and per-player loot instancing.
- World bosses / raids with cross-server coordination.
- Party/group system.

**(c) Hard problems.**
1. **Streaming a big world without breaking scripts.** The pitfalls are documented and severe: scripts referencing parts that are not streamed in will error; `StreamingIntegrityMode = PauseOutsideLoadedArea` is the recommended safety net; excessive replication foci multiply server cost "comparable to multiple players"; and overusing `Persistent` models defeats streaming entirely. The engineering discipline is: **the server never assumes the client has geometry, and the client never assumes it has any instance it did not just find.** Use `Model.ModelStreamingMode = Atomic` for anything whose parts must arrive together (a door, a vehicle, an NPC). ([instance streaming](https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/streaming/index.md))
2. **Quest state migration.** Quest definitions change every update. A save that stores "step 3 of quest 17" breaks when quest 17 is re-authored. Store **objective completion flags keyed by stable string IDs**, not indices, and version the quest table.
3. **Content volume.** A 40-hour RPG is 40 hours of authored content. The only sustainable answers on Roblox are (a) procedural/roguelite content generation, (b) a live-ops cadence that treats each update as an episode, or (c) making combat and progression the content and quests a thin wrapper — which is precisely what the anime RPGs do.
4. **Save size and profile shape** (as in simulators), plus the extra problem that RPG saves are *legally* your player's investment — a corrupt profile is a churn event. Session locking is mandatory.
5. **Server population vs. world size.** A 1 km² world with 30 players feels empty; with 60 it exceeds the streaming/physics budget. Most successful Roblox open worlds solve this by making the world small and dense, not big and sparse.

**(d) Performance profile — what breaks first.** (1) **Client memory** — creator-docs warns that too many replication foci and over-persistence make clients "more likely to be killed by the OS for using too much memory." Mobile OOM kills are this genre's signature crash. (2) **NPC Humanoids** (see genre 9's fix). (3) **Draw calls** from dense town geometry — use instancing (identical meshes with identical textures collapse into one draw call, per creator-docs) and aggressive `RenderFidelity` tiers. (4) **Server script time** from per-NPC AI ticks.

**(e) Editable-asset edge.**
- **Procedural gear appearance.** The same argument as weapon skins, applied to armour/weapons/cosmetics: generate the texture (and optionally deform the mesh) from an item's rolled affixes, so a "Flaming Sword of the Depths" *looks* like its stat roll. Diablo-style visual loot has never properly existed on Roblox and it is one of the strongest editables plays available.
- **Generated world map / fog-of-war.** Render the discovered world into an `EditableImage` map — genuinely better than a static map image, and a documented pattern.
- **`EditableMesh` for world-space destruction and dungeon variation** — breakable environment, carved dungeons, per-run geometry variation.
- **Caveat:** in a streaming world, editables are client-side and per-client memory-budgeted. Generate on demand near the player and release aggressively; do not attempt a world-wide editable terrain.

**(f) Exemplars.**
- **Blox Fruits** — ~61.5B visits. Enormous grind ladder, fruit gacha, sea-based zone progression; architecturally a set of linked places with heavy server-side stat authority.
- **Arcane Odyssey** (Vetex) — the closest thing to a real Western-style open-world RPG on Roblox: custom magic/combat system, ships, exploration, a written story. Its long development and relatively modest CCU versus the anime grinders is itself the genre's cautionary evidence.
- **Anime Vanguards / Jujutsu Shenanigans** (~169K CCU) — the current shape of the money: fast combat, gacha units, short sessions.
- **Swordburst / Dungeon Quest lineage** — the "raid + loot table" template; simplest viable RPG architecture on the platform.

---

## 8. Roleplay and social hangout

**(a) What it is & commercial reality.** **The largest category by playtime on Roblox.** Third-party aggregation puts "Roleplay & Avatar Sim" at ~**116M daily visits**, the top genre **[UNVERIFIED — third-party]**, and Brookhaven RP sits at the top of the all-time visit list (~86.8B visits) with ~513K CCU.

But **2026 is the year this genre got structurally harder**, for one reason: age verification. A roleplay game's core loop *is* communication. With mandatory age checks and age-banded chat since January 2026, a single social design no longer serves the whole audience. Roleplay remains the biggest genre by hours and is still a top revenue genre, but the revenue crown moved to shooters and anime fighters. Expect continued high hours, flat-to-declining monetization, and increasing compliance overhead.

**(b) Core systems.**
- Avatar/appearance customization (Roblox avatar + in-experience layers: outfits, morphs, accessories, emotes).
- Housing: plot claim, furniture placement, interior customization, permissions (roommate/family roles), persistence.
- Vehicles (see genre 10).
- Roles/jobs with props and job-specific abilities.
- Chat: `TextChatService` integration is **mandatory** — all in-experience text chat must go through it per Community Standards, and any user-originated text you display must be filtered. Architecture: `TextChannel` (routing) → `TextSource` (per-user permissions) → `TextChatMessage`, with `ShouldDeliverCallback` (server) for proximity/party gating and `OnIncomingMessage` (client) for formatting.
- Emotes/animations, photo mode, group/party.
- Moderation: reporting, per-server mute/kick, name filtering, an appeal path, and logging.

**(c) Hard problems.**
1. **Moderation is the genre's real engineering burden.** You must filter *everything* user-authored: chat, names, pet names, signs, house names, decals, and any image or text surface. Critically, `TextService:FilterStringAsync` is required for **any** displayed user text, not just chat, and custom chat systems that bypass `TextChatService` have resulted in moderation action against the experience. Build one `SafeText` module that every surface calls; never let a raw string reach a `TextLabel`. ([TextChatService overview](https://github.com/Roblox/creator-docs/blob/main/content/en-us/chat/in-experience-text-chat.md), [custom chat causing moderation action](https://devforum.roblox.com/t/custom-chat-system-causing-moderation-action/4183600), [chat guidelines](https://github.com/Roblox/creator-docs/blob/main/content/en-us/chat/guidelines.md))
2. **Age-banded design.** Post-January-2026 you need a communication tier model: full chat for verified older bands, restricted/preset messaging for younger bands, and a social loop that still works in the restricted tier (emotes, reactions, preset phrases, co-op activities). Roblox itself shipped preset-message systems for this reason. Designing one loop for "everyone" now means designing a loop the platform silently halves.
3. **Housing persistence cost — and the notable decision to avoid it.** Brookhaven, the biggest game in the genre, **does not persist house decoration in public servers**; your setup resets when you leave, and persistence is effectively a private-server feature. That is a deliberate architectural trade: it eliminates per-player world-state saves at 500K+ CCU. If you persist housing, budget for it seriously — per-player object lists, versioned furniture tables, and a migration path.
4. **Permission systems.** Roommate/family/guest roles with per-door, per-vehicle, per-object access control is a real ACL problem, and it is where roleplay games leak griefing bugs.
5. **Server population and the "empty server" problem.** Social games need density. A 20-player roleplay server with 4 people in it is dead. Matchmaking that *fills* servers (rather than spreading players) is a genre requirement, not a nicety.

**(d) Performance profile — what breaks first.** (1) **Avatar rendering** — 30 fully-layered avatars with accessories and layered clothing is one of the heaviest scenes Roblox produces; creator-docs lists `TextureCharacter` as its own memory category for a reason. Mitigation: avatar LOD, accessory culling at distance, and capping server size. (2) **GUI** for customization menus (hundreds of thumbnails — the `EditableImage` atlas trick applies). (3) **Instance count** from placed furniture. (4) **Vehicle physics** in open worlds.

**(e) Editable-asset edge.** This is, alongside sandbox, the genre where editables are most obviously transformative — because the genre's entire value is self-expression.
- **In-experience clothing/texture creation.** `EditableImage` support for `SurfaceAppearance` (the "Build-a-Texture" feature) means players can author their own clothing textures, decals and patterns *inside your game*, on their avatar or house. No competitor without the API gate can match that. ([EditableImage support for SurfaceAppearance](https://devforum.roblox.com/t/in-experience-build-a-texture-editableimage-support-for-surfaceappearance/3866947))
- **Player-drawn art in the world**: paintings, signs, graffiti, tattoos, nail art, car wraps. Moderate the *authoring inputs* (stamp/brush library, filtered text) rather than trying to moderate arbitrary pixels — this is the key design constraint and the reason most teams should offer a constrained editor, not a free canvas.
- **`EditableMesh` body/face morphing** — sliders that actually deform geometry (with FACS pose support in the API) rather than swapping preset heads.
- **Generated profile cards / photo mode output** — render a shareable card as an EditableImage.
- **Moderation reality check:** any pixel-level UGC needs review. The defensible pattern is a *constrained generator* (seeds, palettes, stamps, filtered text) whose output space is safe by construction.

**(f) Exemplars.**
- **Brookhaven RP** (Wonder Works / now under Voldex) — ~86.8B visits, ~513K CCU. Plot-based housing (21 standard plots, 15 free + 6 gamepass-gated, 47 free houses), furniture library, roommate/family permission roles, no public-server persistence. The most instructive architecture on the platform for *what to leave out*.
- **Adopt Me!** (Uplift Games) — 43.5B+ visits, 1.92M CCU record (April 2021), a 50,000+ line codebase, and a custom filesystem sync tool ("Rosync") so the team could use git and standard editors. The trading economy is the deepest in the genre and a good study in escrow design.
- **Welcome to Bloxburg** — the housing/building benchmark: free-form furniture placement, wall/floor editing, persistent lots. Shows what full persistence costs.
- **Livetopia / Berry Avenue** — the current mid-tier roleplay cohort; useful for seeing how smaller teams handle the chat-tier problem.

---

## 9. Tower defense and wave-based

**(a) What it is & commercial reality.** Place towers along a path, survive escalating waves. A **stable, mid-sized, reliably monetizing** genre on Roblox with a clear ceiling: Tower Defense Simulator and the anime-TD wave (Anime Defenders, Anime Vanguards adjacency) sustain healthy CCU but rarely reach the top 5. Monetization is excellent — units are gacha, and gacha is the most proven Roblox monetization there is.

Saturation read: **crowded but not closed.** The genre is dominated by anime-IP-adjacent reskins with near-identical architecture. Mechanical differentiation (co-op raid TD, PvP TD, roguelite-deck TD) is rare and is where the remaining room is.

**(b) Core systems.**
- Wave definition data: `{count, enemyType, spacing, delay}` sequences, plus modifiers.
- Enemy movement along a fixed path (waypoints or a spline) with per-enemy progress `t`.
- Tower placement with grid/zone validation, upgrade paths, sell/refund.
- Targeting: first/last/closest/strongest selection over enemies sorted by path progress.
- Damage, status effects (slow, burn, stun), and armour types.
- Co-op: shared economy or per-player economy, host/ready states, vote-to-skip.
- Unit gacha, inventory, loadouts, levelling.
- Round/match state machine with lobby (see cross-cutting section).

**(c) Hard problems.**
1. **Entity count is the whole game.** DevForum threads on this genre converge on the same answer and it is worth stating bluntly: **do not use Humanoids, do not use `Humanoid:MoveTo`, do not use `PathfindingService` per enemy.** `MoveTo` is repeatedly described as laggy and unoptimized at scale. The production architecture is:
   - The server stores each enemy as a **plain table**: `{id, typeId, pathProgress, hp, statuses}`. No Instance at all.
   - A single server loop advances `pathProgress` by `speed * dt` for all enemies in one pass.
   - The server replicates a compact delta (ids + progress + hp, packed into a `buffer`) at 10–20Hz.
   - **Clients** instantiate the visual models and interpolate position from `pathProgress` along the shared spline, so 500+ enemies cost the server almost nothing.
   - Because path position is a scalar, targeting ("first"/"last") is just a sort on `pathProgress` — O(n log n) on numbers, not spatial queries.
   ([how to make an optimized tower defense game](https://devforum.roblox.com/t/how-to-make-optimized-tower-defense-game/2782375), [smooth enemy movement](https://devforum.roblox.com/t/tower-defense-smooth-enemy-movement/2571665), [enemies lagging behind](https://devforum.roblox.com/t/tower-defence-enemies-lagging-behind/2738378))
2. **Corner smoothing.** Lerping between waypoints produces visible snapping at turns and the classic "enemy cuts the corner" complaint. Use a Catmull-Rom spline through waypoints, or lerp orientation separately with a turn-rate cap.
3. **Animation at scale.** 500 walking enemies with `Animator` instances is unaffordable. Options: client-side `AnimationController` only for enemies near the camera, distance-based animation LOD, or fully baked vertex animation.
4. **Deterministic co-op.** If four players each see a slightly different wave state, damage numbers disagree. The server must be the only authority on HP and wave progression; clients render only.
5. **Flow-field alternative.** For maze-building TD (where players alter the path), per-enemy A* is wrong; run a single **flow field / Dijkstra map** from the goal once per maze change and have every enemy read its cell's direction. ([Red Blob Games: flow field pathfinding for tower defense](https://www.redblobgames.com/pathfinding/tower-defense/))

**(d) Performance profile — what breaks first.** Humanoids, then Instances, then animation, then network. A correctly-built TD is server-cheap and client-bound; an incorrectly-built one dies on the server at wave 15.

**(e) Editable-asset edge.**
- **Generated enemy variants** (`EditableImage` palette/pattern + `EditableMesh` scale/deformation) so "Wave 40 Elite" is visibly a mutation of the base enemy rather than a separate uploaded asset. This lets you ship 200 visually distinct enemies from 12 base meshes.
- **Tower skins as procedural cosmetics** — the same skin-economy argument as shooters, applied to the genre that already has the gacha habit.
- **`EditableImage` for the tactical map/HUD:** a real-time top-down render of lane state, leak paths and tower coverage drawn as a single image instead of dozens of frames. `OSGL` exists precisely for this kind of 2D drawing. ([OSGL](https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757))
- **Range indicators and heatmaps** drawn as a texture on the ground plane instead of transparent cylinder parts — cheaper and much more expressive (overlapping coverage, DPS heat).

**(f) Exemplars.**
- **Tower Defense Simulator** (Paradoxum Games) — the genre reference on Roblox: co-op waves, tower upgrade paths, event content cadence.
- **Anime Defenders / Anime Adventures** — gacha-unit TD; the current commercial shape of the genre.
- **Tower Battles** — the older PvP-flavoured branch (send enemies at opponents); a reminder that the PvP axis is under-explored.

---

## 10. Racing and vehicle games

**(a) What it is & commercial reality.** Mid-sized and durable rather than explosive. Jailbreak (~7.8B visits) remains the biggest vehicle-centric experience, and Driving Empire (Voldex — the same studio that operates Brookhaven; ~2.74B visits, 300+ licensed cars/boats) is the open-world car-collection leader. Corsa Legends represents the simulation branch.

Saturation read: **not saturated, but structurally constrained.** Roblox's physics and replication model make high-quality racing genuinely hard, which suppresses supply. Monetization is strong (cars are the perfect collectible). This is a genre where good engineering still buys market share, but the ceiling is lower than shooters or roleplay.

**(b) Core systems.**
- Chassis: raycast suspension (preferred) or constraint-based (`CylindricalConstraint`/`SpringConstraint`) wheels, with engine torque curve, gearbox, differential model, brake/handbrake, steering with speed-sensitive lock and Ackermann.
- Network ownership management (the genre's central problem).
- Track/checkpoint/lap system with anti-shortcut validation.
- Spawn/despawn and garage systems; vehicle persistence and customization.
- Camera (chase, hood, cinematic) with speed-driven FOV.
- Race matchmaking, ghost/replay, leaderboards.

**(c) Hard problems.**
1. **Network ownership is the whole ballgame.** Official guidance is explicit: the server owns anchored parts; unanchored parts near a player tend to be auto-assigned to that player; and for a vehicle, **the first occupant gains assembly ownership**, so a passenger who enters before the driver makes the driver's controls feel unresponsive. You must explicitly `SetNetworkOwner(driver)` and assign **every loose part on the vehicle** to the same client. ([network ownership](https://github.com/Roblox/creator-docs/blob/main/content/en-us/physics/network-ownership.md))
2. **Ownership handoff is where the bugs live.** Transferring ownership mid-motion — on driver swap, on a vehicle entering a new region, on a client disconnect — produces the freeze/desync class of bug reported repeatedly on the DevForum (players' replication "frozen for a significant amount of time" after ownership changes). Mitigations: change ownership only at low relative velocity, pre-warm the new owner by replicating state before the switch, and never change ownership every frame. ([massive physics network ownership replication lag/desync](https://devforum.roblox.com/t/massive-physics-network-ownership-replication-lagdesync/4620373), [resurfaced issue](https://devforum.roblox.com/t/resurfaced-issue-of-massive-physics-network-ownership-replication-lagdesync/4820710))
3. **Fast objects and remote observers.** At 300 studs/s, the ~15Hz physics replication other clients see means positions arrive ~20 studs apart. You need client-side extrapolation (dead reckoning with velocity + angular velocity) and a visual/physical split: the physical assembly is a simple invisible body, the visible car is a cosmetic model smoothly interpolated toward it.
4. **Vehicle–vehicle and vehicle–player collisions across ownership boundaries** are the source of the infamous "flinging" bug, because two clients each simulate the contact differently. The pragmatic answer used by most large games is **collision groups that prevent player-vehicle and often vehicle-vehicle physical interaction**, with scripted collision responses instead.
5. **Anti-cheat for lap times.** The client owns the car, so the client can teleport it. Validate checkpoints in order, enforce a minimum segment time per checkpoint pair, and sanity-check speed against the vehicle's stats.
6. **Deterministic handling feel across framerates.** Do chassis force application in `PreSimulation` with `dt`-scaled forces, not `RenderStepped`.

**(d) Performance profile — what breaks first.** (1) **Physics solver** — each vehicle is a multi-part assembly with constraints; creator-docs warns to minimize constraints/joints and self-collision. 20 constraint-heavy cars will exceed the physics budget. Raycast suspension (one assembly + four rays) is dramatically cheaper than four constrained wheel assemblies. (2) **Replication bandwidth** — assemblies in motion are the most expensive thing Roblox replicates. (3) **Streaming pop-in** at speed — a car outruns `StreamingTargetRadius`; raise it for vehicle games and accept the memory cost, or pre-stream along the track. (4) **Draw calls** from detailed car models with many unique materials.

**(e) Editable-asset edge.**
- **Livery/wrap editor via `EditableImage`.** This is the obvious, high-value, currently-unbuilt feature: let players design and share car wraps in-game, the way Forza does. It is a monetization engine (wrap slots, stamp packs, featured liveries), a retention engine (showcase/vote), and it is essentially impossible without the API. Moderation via a constrained stamp/decal library plus filtered text.
- **Procedural damage** — `EditableMesh` deformation on impact plus `EditableImage` scratch/dirt accumulation. Visual damage on Roblox today is a swapped model; continuous deformation is a new feel.
- **Track surface effects** — skid marks and dirt painted into a shared road texture instead of spawned decal parts (the classic performance leak).
- **Generated minimaps/track maps** from the actual geometry.

**(f) Exemplars.**
- **Jailbreak** (Badimo) — cops-and-robbers open world; the most-studied Roblox vehicle implementation, notable for custom chassis work and a long history of public developer commentary on physics replication.
- **Driving Empire** (Voldex) — arcade, drift-friendly handling tuned for accessibility; 300+ vehicles with per-car handling characteristics. Proof that *collection*, not simulation, is the monetizable axis.
- **Corsa Legends** — the sim branch: aerodynamics, throttle modelling, damage, engine swaps, suspension setups, tyre compounds.
- **A-Chassis** (free model) — the community's default chassis and, per DevForum bug reports, a common source of joint/network-ownership problems. Know it, don't ship it.

---

## 11. Fighting and combat games

**(a) What it is & commercial reality.** **Together with shooters, the fastest-growing revenue cluster.** Anime fighting/combat games make up, with roleplay, more than half of the most-visited experiences on Roblox by some third-party counts **[UNVERIFIED]**; Jujutsu Shenanigans sits around 169K CCU; anime fighters have posted extraordinary revenue-per-CCU (Gakuran reportedly #1 earning in August 2026 at ~30K CCU **[UNVERIFIED]**).

Saturation read: **extremely crowded at the low end, wide open at the high end.** There are hundreds of "M1 + 4 abilities" anime games. There are almost none with real netcode, real frame data, and real competitive integrity. The difficulty gradient is the moat.

**(b) Core systems.**
- Hitbox detection: **spatial queries** (`workspace:GetPartBoundsInBox` / `GetPartsInPart`) for sweeping attacks, **shaped raycasts** for thrusts and precise strikes. `Raycast Hitbox 4.01` is the long-standing community module for attachment-based melee raycasting.
- Combo system: an index, a cancel window, an input buffer, and an idle-reset timeout.
- State machine per character: Idle / Startup / Active / Recovery / Hitstun / Blockstun / Invulnerable / Ragdoll.
- Ability system: cooldowns, resource costs, targeting, VFX.
- Status effects, damage types, blocking/parrying/perfect-block.
- Ragdoll and knockback physics.
- Matchmaking/arena, ranked, spectating.

**(c) Hard problems.**
1. **The client/server split that actually works.** The consensus pattern on the DevForum: **animations, hitbox visuals and VFX on the client; hit validation, cooldowns and damage on the server.** The client raycasts/queries for responsiveness and sends candidate hits; the server re-validates with a **tolerance radius of roughly 1–2 studs** to absorb latency, and rejects anything wildly out of range. Naive server-only hitboxes feel bad (attacks whiff visibly); naive client-only hitboxes are the most exploited system on Roblox.
2. **Animation cancelling is a *design* decision you must encode in data.** The concrete pattern: define a cancel window in the attack data (e.g. frames 12–18 of a 24-frame animation) during which a buffered input transitions to the next combo step; reset the combo index after an idle timeout (0.8–1.2s is a commonly cited range). The server must validate that the claimed combo timing is *physically possible* — this is the specific check that stops packet-edited instant combos.
3. **Netcode.** For anything fast-paced, rollback is the right answer and is what serious projects converge on; in practice most Roblox fighters ship delay-based/authoritative-server hybrids. The pragmatic middle: server-authoritative state with client prediction on your own character only, plus a 100–150ms render delay for opponents. Full rollback with state resimulation is achievable but is a large engineering project; treat it as a deliberate moat, not a default.
4. **Hitbox/animation sync.** A hitbox attached to a hand bone must be sampled at the animation's actual pose, but animations play at slightly different times on client and server. Solution: drive hitboxes from **animation keyframe markers** (`GetMarkerReachedSignal`) rather than wall-clock offsets, and run server validation against the *declared* attack timing rather than a server-side replay of the animation.
5. **Ragdoll replication.** Ragdolls are unanchored multi-part assemblies — the most expensive thing to replicate. Make ragdolls client-only visuals wherever the outcome doesn't matter, and destroy them aggressively.

**(d) Performance profile — what breaks first.** (1) **VFX/particle count** — anime combat is a particle firehose; pool and cap emitters, and cull by distance. (2) **Server spatial queries** — `GetPartBoundsInBox` per attack per player is fine; per frame per player is not. (3) **Ragdoll physics.** (4) **Animation replication** — many simultaneous `Animator`s with high-bone-count rigs.

**(e) Editable-asset edge.**
- **Procedural VFX with `EditableImage`.** Anime combat lives on its effects. Generating slash trails, shockwave rings, energy textures and impact flashes at runtime — parameterized by damage, element and charge level — gives you effects that scale continuously with gameplay state instead of three preset variants. This is a *feel* differentiator competitors cannot clone by downloading your assets.
- **`EditableMesh` slash trails and deformed limbs** — true swept-geometry trails built from the weapon's motion history, rather than a stretched billboard.
- **Environment destruction** — craters, shattered ground, deformed walls from heavy attacks. This is the single most requested missing feature in Roblox anime fighters and it is exactly what EditableMesh enables. Budget it as "a few chunked meshes near the impact," not world-wide.
- **Character customization** via generated textures for a cosmetic economy (the genre's monetization is already skins-and-units).

**(f) Exemplars.**
- **Jujutsu Shenanigans** — ~169K CCU; the modern reference for *feel*: tight combo windows, readable startup/recovery, very high animation quality. Study its cancel windows.
- **The Strongest Battlegrounds** — the "battlegrounds" subgenre template: simple movesets, high readability, enormous audience.
- **Blade Ball** — a reaction-timing fighter; shows how much of "fighting game" can be reduced to one input if the netcode is honest about latency.
- **Rogue Lineage / Deepwoken** (Deepwoken especially) — the hardcore permadeath combat branch; deep stamina/posture systems and the most punishing combat design on the platform, with a small but extraordinarily loyal audience.

---

## 12. Sports and physics games

**(a) What it is & commercial reality.** A **small but genuinely growing and under-served** category. Volleyball Legends currently leads tracked Roblox sports/racing experiences by CCU; Football Fusion 2 is the American-football standard; and real leagues have official presences (NFL Universe Football, NHL Blast, Super League Soccer), which signals platform investment.

Saturation read: **the least saturated large-appeal genre on this list.** Very few teams attempt it because ball physics under Roblox's replication model is unforgiving, and because sports needs excellent animation. Both are solvable. If you want a genre where good engineering is rare, this is it — with the caveat that sports audiences are smaller and more seasonal.

**(b) Core systems.**
- Ball physics: the single authoritative ball, with spin (Magnus effect if you want curve), bounce/restitution tuning, and drag.
- Possession/ownership model (see below).
- Player movement with sport-specific states: sprint, juke, tackle, dive, jump-block.
- Animation-driven actions with contact windows (a catch is a hitbox on the hands during a catch animation).
- Rules engine: out-of-bounds, scoring, fouls, downs/sets/innings, clock, overtime.
- Team management, positions, substitutions, spectating.
- Match state machine (lobby → warmup → play → halftime → end), replays.

**(c) Hard problems.**
1. **The ball ownership problem — the genre's defining issue.** A single physics ball interacting with many players cannot feel right for everyone. DevForum reports of "client and server balls not in sync due to having different network owners" are the canonical symptom. Three viable architectures:
   - **(i) Server-owned ball + client prediction.** Server simulates; clients extrapolate. Feels laggy on contact but is fair and exploit-resistant. Best for competitive.
   - **(ii) Possession-based ownership.** The ball's network ownership follows whoever last touched it; contests are arbitrated server-side with a short ownership lockout after transfer to prevent thrash. Feels great for the holder, can feel unfair to defenders. Most Roblox sports games do this.
   - **(iii) Fully deterministic scripted ball.** No physics at all — the ball is a CFrame animated along a computed trajectory, recomputed on each server-validated contact. Perfectly consistent for everyone; loses emergent physics. Best for arcade sports (this is effectively how many volleyball/dodgeball games work).
   Pick one deliberately. The failure mode is picking (ii) by default and discovering it is unarbitrable.
2. **Contact arbitration.** Two players diving for the same ball is the same race as item theft in survival games: the server must own `lastTouchedBy` and resolve with a timestamped, latency-clamped comparison.
3. **Animation-gameplay coupling.** In sports, the animation *is* the hitbox timing. Use keyframe markers to open/close catch and tackle windows, and validate on the server from the declared attack/catch window, not from replicated limb positions.
4. **Rules as data.** Sports rules are where spaghetti accumulates. Model the match as an explicit state machine with a transition table, not nested conditionals.
5. **Mobile controls.** Sports inputs are analog and contextual; a touch UI that maps sprint/pass/shoot/juke without a joystick fight is a genuine design problem and is where most Roblox sports games lose mobile players.

**(d) Performance profile — what breaks first.** (1) **Replication of the ball and players at speed** — same dead-reckoning requirements as racing. (2) **Physics contacts** if you use real physics bodies for players. (3) **Animation count** — a stadium of 22 animated players plus crowd. (4) Crowd/stadium **draw calls** — use instanced crowd meshes or billboard crowds.

**(e) Editable-asset edge.**
- **Team kit / jersey designer** (`EditableImage`): players design their team's strip, numbers, sponsor patches. This is the sports equivalent of the livery editor and it is the obvious missing feature in every Roblox sports game. It is also a natural monetization surface (kit slots, pattern packs) and a natural social surface (league identity).
- **Pitch/court wear** — studs marks, wet patches, damage painted into the surface texture over a match.
- **Live stat overlays and shot charts rendered as images** — broadcast-quality HUDs drawn once per event rather than assembled from dozens of frames.
- **`EditableMesh` for ball deformation** on impact — small, but exactly the kind of detail that reads as "high production value."

**(f) Exemplars.**
- **Volleyball Legends** — currently leading sports/racing CCU; a good study in reducing a complex sport to a few well-tuned timing windows.
- **Football Fusion 2** — the American football standard; catch/tackle windows, route running, and a genuinely complex rules engine.
- **Soccer: Touch Football** — the ball-physics-forward branch.
- **NFL Universe Football / NHL Blast / Super League Soccer** — official league experiences; useful as evidence that the platform is investing in the category.

---

## 13. Sandbox / building / user-generated content games

**(a) What it is & commercial reality.** Games whose content is made by players inside the game. Build a Boat for Treasure, Lumber Tycoon 2, and the block-building cohort. Commercially this is a **small-to-mid genre with outsized strategic importance**, because it is the genre where Roblox's newest APIs change what is possible.

Honest read: **currently under-monetized and under-built, but this is the highest-leverage white space on the platform.** Every existing Roblox sandbox builds from a fixed palette of parts. The APIs to let players author *geometry* and *textures* landed in production only recently and are gated behind verification requirements most developers won't clear. That is a real, temporary moat.

**(b) Core systems.**
- Part/voxel placement with snapping, rotation, mirroring, group select, copy/paste, undo/redo.
- A creation serialization format (and versioning for it).
- Validation: part-count caps, bounding-volume caps, forbidden configurations.
- Sharing: publish, browse, rate, remix, moderation queue.
- Simulation of creations (physics for vehicles, function for machines).
- Economy: part unlocks, save slots, featured creations.
- Moderation: the hardest requirement, since players are authoring content other players see.

**(c) Hard problems.**
1. **Moderation of player-authored content is the genre's existential problem.** Roblox requires filtering of user-originated text everywhere; player-authored *geometry and images* have no automatic filter. The only architectures that work: (a) constrain the authoring space so the output set is safe by construction (stamps, palettes, symmetric generators, filtered text only), (b) gate public sharing behind human/automated review with a report-and-takedown path, or (c) keep creations private/friends-only. Do not ship an unconstrained public pixel canvas.
2. **Serialization and versioning.** A creation format must survive part-table changes for years. Store part definition IDs (never indices), a format version, and write migrations. Quantize transforms. For large builds, store as a `buffer` blob rather than a nested table — it is dramatically smaller and faster to (de)serialize.
3. **Physics validation of arbitrary creations.** Players will build a 4,000-part 800-constraint monstrosity specifically to crash your server. Enforce hard caps at *placement* time, and simulate creations in an isolated "sandbox zone" with its own collision group.
4. **Load/replication cost** of instancing a large creation. Creator-docs explicitly advises loading in chunks across frames; do that, and stream creations only to players who are near them.
5. **Discoverability of UGC** — a sandbox with no browse/rating layer is a diary, not a platform.

**(d) Performance profile — what breaks first.** Instance count, then physics (constraint count in creations), then the editable memory budget if you go the generated-geometry route, then network on creation load.

**(e) Editable-asset edge — this is the genre where editables are genuinely transformative, not incremental.**
- **Players authoring actual meshes.** `EditableMesh` (vertex/triangle/UV/colour/bone APIs, `RaycastLocal`, `FindVerticesWithinSphere`, `MergeVertices`, `Triangulate`) is a complete in-game modelling toolkit. A sculpting or voxel-to-mesh tool inside a Roblox game was impossible before; it is now merely hard. The 60k-vertex / 20k-triangle per-mesh cap forces chunking, which is a normal engineering constraint, not a blocker.
- **Players authoring textures.** `EditableImage` + `SurfaceAppearance` support means in-game texture painting that affects PBR maps, not just decals.
- **Combined with Roblox's Cube/4D generation**, the sandbox thesis becomes: *players describe an object, the platform generates functional geometry, and your game lets them edit and place it.* Roblox shipped Cube 3D (a 1.8B-parameter text-to-3D foundation model trained on ~1.5M assets, available in Studio **and as an in-experience Lua API**), then 4D functional objects in early access (generated cars that drive, planes that fly), then CubePart for part-controllable generation. The in-experience API is the important part: it means generation is a *gameplay mechanic*, not just a Studio feature. ([Cube](https://about.roblox.com/newsroom/2025/03/introducing-roblox-cube), [Cube 3D tools & APIs](https://devforum.roblox.com/t/beta-cube-3d-generation-tools-and-apis-for-creators/3558947), [in-experience 4D functional objects](https://devforum.roblox.com/t/early-access-introducing-in-experience-4d-functional-objects-and-enhanced-3d-generation/4050893), [CubePart](https://about.roblox.com/newsroom/2026/05/cubepart-roblox-open-vocabulary-part-controllable-3d-generator))
- **The defensibility argument.** Every other Roblox differentiator is copyable: a competitor can reverse-engineer your loop, buy the same assets, and clone your UI in a week. They cannot clone a generator pipeline they cannot legally enable (13+, ID-verified, dashboard opt-in) and do not have the engineering depth to rebuild. Editable-asset sandboxes are the rare Roblox moat.

**(f) Exemplars.**
- **Build a Boat for Treasure** — block placement + physics + a run that tests the build. The cleanest "build then validate" loop on the platform.
- **Lumber Tycoon 2** — persistent, player-driven world; still the best study of sandbox economy.
- **Blocktales / Block Mania-type builders** — the voxel branch.
- **Roblox Studio itself** — worth studying as a design document for in-game tooling: the selection, snap, and undo affordances players already expect.
- *(No shipped large-scale `EditableMesh` sandbox is publicly documented as of this writing — which is the point.)* **[UNVERIFIED — absence of evidence]**

---

## 14. Puzzle, story, and narrative games

**(a) What it is & commercial reality.** Small, low-monetizing, high-critical-regard. Story games ("The Mimic", "Apeirophobia"-adjacent narrative horror, escape-room games) sustain modest but stable audiences. Pure puzzle games are rare.

Honest read: **commercially the weakest genre on this list, and you should know that going in.** Narrative content is consumed once. There is no repeat loop, no gacha, no competitive ladder. Story games monetize through chapter unlocks and cosmetics at low rates, and the new discovery algorithm — which rewards Day 8–28 return behaviour — is structurally hostile to a genre where finishing the content is the goal.

Where it *does* work: (i) narrative as a **wrapper** on a replayable loop (DOORS has a story; it is not a story game), (ii) **episodic** releases that reset the 28-day clock, (iii) **co-op** story games where the social experience is the replay value.

**(b) Core systems.**
- Dialogue graph: nodes with conditions, choices, effects, and localization keys. Community modules (`Advanced Dialogue System V2`, May 2026; `Dialogue Kit for Story Games`) offer typewriter effects with per-node speed, multiple choice, location banners and server-side action hooks.
- Cutscene system: camera keyframes, timed events, skip handling, and an "everyone is watching" sync for co-op.
- Flag/state store for narrative branching (a flat `Set<string>` of set flags is almost always the right model).
- Checkpoint/chapter progression persistence.
- Puzzle primitives: pressure plates, sequences, inventory-key matching, timed mechanisms.
- Multiple endings and an ending-collection meta.

**(c) Hard problems.**
1. **Branching state explosion.** Do not model branches as a tree. Model as a **flag set plus predicate conditions** on nodes — this keeps the state linear in the number of decisions rather than exponential, and makes saves trivially small and migration-safe.
2. **Co-op narrative sync.** If four players are in a cutscene and one leaves or lags, the server must own scene progression and clients must be able to *rejoin mid-scene*. The pattern: the server broadcasts `sceneId + elapsedTime`, the client seeks to that offset.
3. **Skip/pace control.** Every player skips; some don't. You need per-player skip that doesn't desync shared state — only the *presentation* is skippable, never the state transition.
4. **Localization.** Narrative games are the genre most damaged by English-only text, and Roblox's international growth (reported DAU growth of ~67% in Japan and ~64% in India) makes this a real revenue question. Keys, not strings, from day one.
5. **Puzzle anti-spoiler design.** Solutions spread in 20 minutes. Seeded per-server puzzle variation is the only real answer.

**(d) Performance profile — what breaks first.** Rarely performance-bound. The exceptions: (1) heavily scripted set-pieces that instantiate large scenes at once (chunk the load), (2) cinematic post-processing stacks on mobile, (3) voice/audio asset memory if you ship voiced dialogue.

**(e) Editable-asset edge.**
- **Generated documents, letters, photographs, and evidence boards** — a detective/mystery game where the case file is *rendered* from the actual procedurally-generated case (names, times, locations composited into a believable document image) is a genre that does not exist on Roblox and cannot be built without `EditableImage`.
- **Player-drawn journals/maps** as a mechanic.
- **Procedural puzzle artifacts** — generated circuit diagrams, constellation charts, cipher wheels, each unique per server.
- This is the genre where editables convert a weak commercial position into a novel one: *the puzzle content itself becomes generative*, which fixes the "solutions spread instantly" problem and the "content is consumed once" problem simultaneously. That is the strongest argument for editables in any genre on this list.

**(f) Exemplars.**
- **The Mimic** — chapter-based Japanese-horror narrative; the most successful Roblox story-game structure (episodic, co-op, horror-flavoured).
- **Apeirophobia** — level-based liminal-space progression; narrative delivered environmentally rather than through dialogue.
- **Escape-room cohort** (various) — the puzzle branch; almost all suffer the spoiler problem.
- **Break In / Break In 2** — narrative wrapped around a round-based co-op loop; the commercially smartest structure in this space.

---

## 15. Horror/social hybrids and party games ("lobby + round")

**(a) What it is & commercial reality.** Short rounds, rotating roles, a lobby between rounds: Murder Mystery 2, Flee the Facility, Forsaken, Dandy's World, Epic Minigames, Break In, and a long tail. **This is the single most durable structural category on Roblox** — it has produced hits continuously for a decade and continues to (Forsaken and Dandy's World are both recent).

Why it works, stated plainly: the round loop produces exactly the metrics the 2026 discovery algorithm measures. Short sessions with a clear "one more round" hook maximize *play days* and *qualified play sessions*; asymmetric roles maximize *intentional co-play days*; and the between-round lobby is a natural, non-intrusive monetization surface (cosmetics you show off while waiting). If you want to align with discovery rather than fight it, build here.

Saturation read: **crowded but continuously renewing.** The mechanics are cheap to copy; the *feel* and content cadence are not.

**(b) Core systems.** See the cross-cutting section below — this genre *is* the lobby architecture, plus:
- Role assignment with weighted fairness (players who haven't been the killer recently get priority).
- Per-round map rotation and voting.
- Spectating with free-cam and player-follow.
- Cosmetic economy displayed in the lobby (this is where the money is).
- Round-result screens, XP, and a battle pass.
- Late-join and mid-round-leave handling.

**(c) Hard problems.**
1. **Late joiners.** The default failure is a player joining mid-round into an unwinnable state. Options: hold in lobby until next round (best for competitive), join as spectator (best for social), or join as a "reinforcement" role. Pick explicitly and communicate it.
2. **Role-assignment fairness.** Pure random produces the "I've been survivor 11 times" complaint that kills retention. Implement a per-player recency-weighted bag draw, persisted across rounds *and* across sessions if possible.
3. **Round state machine robustness.** The state machine must be crash-safe: a script error mid-round must not soft-lock the server. Wrap each phase in `pcall`, have a global watchdog that force-advances after a phase timeout, and never let a phase transition depend on an event that might not fire.
4. **Team-based information leakage.** In asymmetric games the client must not receive information about hidden roles. Replicate role data *only* to entitled clients; do not set a `Value` object on the character. This is the most commonly botched security issue in the genre.
5. **Cosmetic-heavy lobbies** are a rendering problem: 30 players with maximum cosmetics in one small room is the worst-case avatar scene.

**(d) Performance profile — what breaks first.** (1) **Avatar/cosmetic rendering in the lobby** (ironically worse than the round). (2) **Map load/unload churn** between rounds — pool maps or teleport to fresh reserved servers rather than destroying and rebuilding. (3) **Server memory drift** across many rounds from leaked connections — this genre is where `LuaHeap` leaks surface, because the server runs for hours through dozens of round cycles.

**(e) Editable-asset edge.**
- **Generated cosmetics** for the lobby economy — the same procedural-skin argument, applied to the genre whose monetization surface *is* the lobby.
- **Per-round generated maps** with `EditableMesh` — the "regeneration replaces content" thesis from obbies, applied to a genre with more room for it.
- **End-of-round infographics** rendered as images (chase heatmaps, kill timelines, escape routes) — high shareability, effectively zero on the platform today.
- **Player-decorated lobby spaces** as an expression and monetization axis.

**(f) Exemplars.**
- **Murder Mystery 2** (Nikilis) — the genre's monetization archetype: rounds are free, knives are the product, and the trading economy for knives is the actual game.
- **Flee the Facility** — asymmetric hide-and-escape; the cleanest round state machine to study.
- **Forsaken** — the current wave leader; playable killers with distinct abilities and randomized objectives.
- **Epic Minigames** — the pure party-game structure; dozens of micro-games in one round loop, which is the most demanding version of the architecture (each minigame is effectively its own game mode).

---

# Cross-cutting: the round-based lobby architecture

This is the most reusable piece of architecture on Roblox. It underpins every party game, every asymmetric horror game, every competitive shooter, most tower defense, and every "raid instance" in an RPG. Learn it once.

## The two topologies

**Topology A — single-place round loop.** One place, one server, a state machine that cycles Intermission → RoleAssign → Playing → Results → Intermission. Players stay in the same server across rounds. Simple, no teleport latency, no reserved-server cost. Used by Murder Mystery 2, Flee the Facility, Epic Minigames. **Choose this unless you need isolation.**

**Topology B — lobby place + match place.** A lobby place holds a queue; matches run in reserved servers of a separate place. Necessary when: matches must be isolated from non-participants, match size differs from server size, you need skill-based matchmaking, or maps are too large to load alongside a lobby. Used by competitive shooters, raid instances, tournament modes.

## The reserved-server pattern (Topology B), step by step

1. **Enqueue.** The lobby server writes the player (userId, MMR, party ID, region hint) into a **MemoryStore queue** or **sorted map**. Sorted map keyed by MMR is better when you want skill banding; a plain queue is fine for casual.
2. **Match loop.** One server (or every server, using a MemoryStore lock to elect a leader) periodically reads a batch, forms a balanced group, and **removes those entries atomically**. The atomic removal is the critical correctness point — two servers matching the same player is the classic bug.
3. **Reserve.** `TeleportService:ReserveServer(placeId)` returns an **access code**. The reserved server stays alive as long as it has ≥1 player, plus roughly a 30-second grace after the last player leaves; after that the access code is dead and cannot be reused. **Do not cache access codes.**
4. **Teleport.** `TeleportService:TeleportAsync(placeId, players, teleportOptions)` with `TeleportOptions.ReservedServerAccessCode` set, plus `SetTeleportData` carrying the match config (mode, map, team assignments, MMR snapshot).
5. **Register.** On arrival, the match server publishes its `game.JobId` and match metadata back into MemoryStore so the lobby can show it, so late joiners can be routed to it, and so it can be found again for rejoin.
6. **Report and drain.** At match end, write results (XP, MMR deltas, stats) to DataStore/MemoryStore, then `TeleportAsync` everyone back to the lobby place. Have a fallback: if the teleport fails, retry with backoff, then kick with a clear message rather than stranding players.

([public vs reserved servers](https://devforum.roblox.com/t/public-servers-vs-reserved-servers/3471347), [matchmaking with MemoryStore + TeleportService](https://devforum.roblox.com/t/matchmaking-system-using-only-memory-stores-and-teleportservice/1487240), [teleporting to an existing reserved server](https://devforum.roblox.com/t/teleporting-people-to-an-already-existing-reserved-server/3382607), [ServerTeleport reference implementation](https://github.com/Hollower233/ServerTeleport))

## Budget the quotas before you design

MemoryStore quotas scale with your player count, not your ambition:
- Memory: `64KB + 1.2KB × [number of users]`, computed game-wide, with an eight-day traceback after users leave.
- Requests: `1000 + 120 × [CCU]` units/minute. Most calls cost 1; `GetRangeAsync()` is charged **per item returned**; `UpdateAsync()` on a hash map costs **at least 2**.
- Caps: **1,000,000 items** and **100MB** per sorted map or queue.

The practical implications: (a) a matchmaking loop polling `GetRangeAsync(100)` every second costs ~6,000 units/minute on its own — poll at 2–5 second intervals and read smaller pages; (b) put queue entries in a compact form (userId + one packed number), not a rich table; (c) shard your queue across several keys by region/mode so a single key doesn't hit the item cap.

## The round state machine

Model it explicitly. A minimal robust version:

```
States: Waiting → Intermission → Preparing → Playing → Ending → (Waiting | Intermission)
Each state has: onEnter, onExit, a max duration, and a set of legal transitions.
```

Non-negotiables:
- **A watchdog.** Every state has a hard timeout that force-transitions. A round that can hang is a round that will hang.
- **`pcall` every phase body.** One erroring script must not soft-lock the server for everyone.
- **Idempotent transitions.** `EndRound()` called twice must not double-award.
- **A single source of truth**, replicated as one state object (`{phase, phaseEndsAt, roundId}`) rather than a dozen booleans. Clients drive all UI from `phaseEndsAt` minus `workspace:GetServerTimeNow()`, which keeps timers synchronized without per-second remotes.
- **Round ID on everything.** Every score event, damage event and reward carries the round ID so late-arriving packets from the previous round are discarded.

## Spectating

Three implementations, increasing cost:
1. **Camera-follow:** set `Camera.CameraSubject` to the target's Humanoid. Trivial, and sufficient for most games.
2. **Free-cam:** custom camera with WASD/drag, `CameraType.Scriptable`. Needed for competitive and for content creators.
3. **Replay:** record a compressed transform stream and play it back. Expensive; only worth it for esports-flavoured titles.

**The security note everyone gets wrong:** a spectating client has the full replicated data model. If dead players can spectate living ones in a hidden-information game (a mystery, a hider/seeker game), they can wallhack for their team over voice. Either restrict spectating to the player's own team, delay spectator view, or lock spectating until the round ends.

## Rejoining

- Keep a MemoryStore hash-map entry: `userId → {jobId, accessCode, placeId, expiresAt}` written when a player enters a match.
- On rejoin to the lobby, look it up; if it's live, offer "rejoin match" and teleport with the stored access code.
- Store the player's in-match state (score, role, position) **server-side in the match server**, keyed by userId, with a grace window; restore on reconnect.
- If the match server has died, clear the entry and route to lobby. Always have this path — stale entries that teleport players into nothing are the most common rejoin bug.

## Where this architecture breaks

- **Teleport failures at scale.** `TeleportAsync` can fail; you must handle `onFailed` and retry. At 100K CCU, a 0.5% failure rate is 500 stranded players.
- **Reserved-server cost.** Every reserved server is a server. A 4-player match size at high CCU means enormous server counts; prefer larger matches or Topology A.
- **The 30-second grace.** If your match "ends" and everyone teleports out simultaneously, the server dies and any async result writes in flight are lost. Write results *before* teleporting, and use `game:BindToClose` with a short wait as a backstop.
- **Cross-server messaging.** `MessagingService` has its own rate limits and is best-effort, not guaranteed. Never build match correctness on it; use it for notifications only.

---

# Cross-cutting: what the top-100 have in common technically

Patterns that recur regardless of genre. If your game lacks these, you are not competing with the top of the chart.

1. **The server owns all state that matters; the client owns all feel.** Every large game draws this line identically: the client predicts and renders immediately, the server validates and corrects. Where they differ is only *how much* tolerance the server grants (1–2 studs for melee, a 0.5–1.0s rewind window for shooters, an income-rate ceiling for tycoons).

2. **Session-locked, versioned, auto-saving persistence — never raw DataStore.** Effectively all serious games use `ProfileStore`/`ProfileService` or an equivalent. The reasons are concrete: session locking prevents duplication via multi-server login, `Reconcile()` handles schema additions, and ProfileStore's move to a 300-second autosave (from 30s) plus `MessagingService`-assisted lock handoff cuts DataStore call volume ~10× — which matters because DataStore budgets are the first backend limit a hit game hits.

3. **Almost no unanchored parts in steady state.** Physics is the most expensive thing Roblox does per-part and the most expensive thing to replicate. Top games anchor everything and animate by CFrame: tycoon drops, tower defense enemies, projectiles, effects, moving platforms. Physics is reserved for the few places where emergent behaviour *is* the product (vehicles, ragdolls, sandbox creations).

4. **Humanoid avoidance.** Every genre's scaling story ends at the same wall. Top games use `Humanoid` for the player character and almost nothing else; NPCs and enemies are tables with client-rendered visuals.

5. **Object pooling everywhere.** Bullets, particles, enemies, UI rows, drop parts, rooms. `Instance.new`/`Destroy` in a hot loop is the most common self-inflicted stutter on the platform.

6. **Client-side rendering of server-owned simulation.** The universal scaling pattern: server computes a scalar/compact state, replicates a delta, client builds the visuals. This appears in tower defense (path progress), tycoons (income rate), shooters (character history), and survival (base contents).

7. **Batched, throttled, compressed replication.** No top game sends a remote per event per frame. They accumulate into a per-tick payload, quantize numbers, and increasingly pack into `buffer` objects. Creator-docs states the rule plainly: don't replicate every frame, and send only what changed.

8. **`StreamingEnabled` for anything with a world.** With `Atomic` models for gameplay-critical groups and `PauseOutsideLoadedArea` integrity mode. Teams that avoid streaming end up shipping mobile OOM crashes.

9. **Data-driven content.** Weapons, pets, towers, quests, rooms, recipes are all definition tables, not code. This is what makes a weekly live-ops cadence possible, and weekly cadence is what the 28-day retention algorithm rewards. The top games ship content updates on a schedule; the architecture that permits that is the moat.

10. **A real analytics loop.** D1/D7/D30 retention, session time, payer conversion and ARPPU on a dashboard, plus **funnels** for onboarding and purchase, plus `AnalyticsService:GetPlayerSegmentsAsync()` for in-experience personalization. Uplift Games (Adopt Me) publicly describes using Roblox's analytics and experimentation platform for live A/B testing — that capability, not intuition, is how the top 100 tune.

11. **Anti-exploit as middleware, not as scattered checks.** One module wrapping every remote: type check → rate limit (token bucket) → sanity check against the server's world model → act. Silent rejection (never tell the exploiter which check failed).

12. **Mobile-first performance discipline.** Profiling on a real low-end phone, not in Studio. Creator-docs is explicit that Studio "lies" about draw-call cost relative to target devices and that emulators misreport memory.

13. **Cosmetic-led monetization is winning.** The 2026 revenue leaders (RIVALS; anime fighters) sell appearance, not power. Cosmetics are infinitely re-sellable, don't break balance, and align with a skill-based audience. Pay-to-win gamepasses still work in simulators but are the declining branch.

14. **A codebase that a team can work in.** Adopt Me is 50,000+ lines with custom tooling (Rosync) built specifically to let the team use git and normal editors. Every game at scale ends up with an external toolchain — Rojo, a package manager, CI, and typed Luau.

15. **Cross-platform input parity from day one.** Roblox's audience is majority mobile; a control scheme retrofitted to touch is a control scheme that loses the majority of the funnel.

