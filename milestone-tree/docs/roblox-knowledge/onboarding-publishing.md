# Onboarding, guides and publishing assets: knowledge base (state as of September 2026)

Part of the Milestone Tree NG+ "fat library" on what Roblox can do. Topic: **teaching the game** (first-run tutorial,
contextual Guide, hint rules, accessibility, drop-off analytics) and **selling the game** (icon, thumbnails, video
previews, sponsored ads, trailer music). It closes with a concrete plan for this game.

**How claims are tagged**

| Tag | Meaning |
|---|---|
| **[V]** | Checked against the engine type dump (`scratchpad/tools/globalTypes.d.luau`) **and** the official docs (creator-docs repo, `main` @ `cc850a8`, 2026-09-25) |
| **[D]** | Official Roblox docs (Creator Hub pages in the same repo); not an engine API |
| **[A]** | Official Roblox DevForum announcement or a Roblox staff reply |
| **[S]** | Read directly in source code: our `game-js/`, Antimatter Dimensions, Cookie Clicker, The Modding Tree docs |
| **[C]** | Community or third-party report, not confirmed by an official source |
| **[U]** | Unverified: my inference or design advice. Test it or treat it as a proposal |

API "added" dates come from the engine change logs at <https://robloxapi.github.io/ref/updates/2025.html> and
`/2026.html`.

---

## 0. The ten findings that matter most

1. **Roblox's own guidance: short, visual, contextual.** "FTUEs that get users into the fun quickly tend to do better
   on Roblox. Lengthy, detailed tutorials are liable to bore users" ([Design for Roblox](https://create.roblox.com/docs/production/game-design/design-for-roblox)).
   The recommended techniques are visual elements, contextual (just-in-time) tutorials and timed hints
   ([Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques)). [D]
2. **The best incremental tutorial is tiny and state-driven.** Antimatter Dimensions' whole tutorial is **6 glow states**.
   Each state advances when a game condition becomes true, and it runs only before the first full completion.
   Everything else lives in a **How-to-Play codex** of about 55 entries, each gated by `isUnlocked`
   ([tutorial.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/tutorial.js),
   [h2p.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/secret-formula/h2p.js)). [S]
3. **Most of this game's content should never be hinted.** Of the 187 milestones in `game-js/layers/m.js`, **98 (52%)
   only change a number** ("X is boosted", "^1.005"). 48 unlock something, 23 automate something, 9 keep things
   through resets and 9 change challenge rules. The Guide needs about 65 moments, not 400 items (§3). [S]
4. **Onboarding funnel rules have sharp edges.** `LogOnboardingFunnelStepEvent` works **server-only and in published
   games only**. It counts **only the first instance** of each step, and logging a later step **auto-completes the
   skipped earlier ones**. Log real progress, and log "tutorial skipped" as a custom event instead
   ([Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)). [V]
5. **AnalyticsService calls are `thread_safety: Unsafe`.** Our game runs each player's session in a parallel Actor
   (`src/worker/Worker.server.luau`), so call `task.synchronize()` before logging. [V]
6. **New analytics tools in 2026:** `LogJourneyEvent` (non-linear paths as a Sankey diagram, added 2026-07-21) and
   `GetPlayerSegmentsAsync` (a runtime bucket such as `WhenUserFirstPlayed`, added 2026-03-17). Roblox's docs
   suggest using segments to give newer players "additional tutorials, tooltips, and simplified content"
   ([Analytics overview](https://create.roblox.com/docs/production/analytics)). [V]
7. **Spotlight masks are easy; input blocking is the hard part.** A Frame with a huge `UIStroke`
   (`BorderStrokePosition.Outer`, added 2025-07-29) or a 9-slice ring plus 4 frames gives the hole. Blocking taps
   outside it needs `GuiButton`s or the brand-new `GuiObject.InputSink` (added **2026-09-08**; our code already
   guards it with `Theme.caps.InputSink`). [V]
8. **Video on the game page is now free, uploaded and moderated.** Video previews launched **2025-11-13**, "no more
   500 Robux" ([announcement](https://devforum.roblox.com/t/video-previews-for-your-games-page/4068103)), and have
   shown in **Recommended For You on Home since 2026-08-31**
   ([announcement](https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601)).
   The quota is **3 uploads a month**, and rejected uploads still count
   ([Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)). [A/D]
9. **Video rules forbid what trailers usually do.** No voice-over or narration, **no music with lyrics**, no
   promotional text or claims, no real-life footage, no "artificial visuals". Logo overlays, camera work, light
   grading, curated highlight reels and **Roblox-catalog music** are allowed. [D]
10. **Creator Store music is licensed for Roblox only.** It may be used in the Roblox video preview (docs) and in
    gameplay captures posted to social media. It may **not** be used in commercials or in trailers that are not
    gameplay. A trailer or off-platform ad needs music we own or have licensed ourselves (§14; see also
    `audio.md` §6.6). [D/A/C]

---

# PART 1: Tutorials and guides for incremental games

## 1. What the best ones actually do

| Game | Technique | What to take from it | Evidence |
|---|---|---|---|
| **Antimatter Dimensions** | 6-state tutorial (`DIM1 → DIM2 → TICKSPEED → DIMBOOST → GALAXY → AUTOMATOR`). Each state glows one button and advances when the *next* state's condition is true (`Currency.antimatter.gte(100)`, `AntimatterDimension(2).bought > 0`, …). It is active only while `player.records.fullGameCompletions === 0`. The H2P button is emphasized until the first Dimension Boost. | The tutorial is a **condition table**, not a script. Glow the one thing to press, and stop teaching once the player has shown the skill. | [S] [tutorial.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/tutorial.js) |
| **Antimatter Dimensions** | **How to Play codex**: about 55 entries, each with `isUnlocked` ("visible and searchable"), `tags` for search, and `tab`, which "will default the h2p to this entry if opened" from that tab. | A spoiler-free, **searchable** Guide log whose entries unlock with progress. Opening it on a panel jumps to that panel's entry. | [S] [h2p.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/secret-formula/h2p.js) |
| **Cookie Clicker** | No tutorial. Locked buildings show as `???` with a `???` description and a mystery icon. With the screen-reader preference on, they read "This building is not yet unlocked." | Show *that* something is coming without explaining it. The first action (click the cookie) is self-evident. Accessibility can be a preference. | [S] [main.js](https://orteil.dashnet.org/cookieclicker/main.js) (`Game.Object.refresh`, `me.locked`) |
| **The Modding Tree / Prestige Tree** (our engine) | `milestonePopups`, and `shouldNotify` / `glowColor` node highlights ("automatically highlighted if you can buy an upgrade"). Node `tooltip()` / `tooltipLocked()`. | Our port already has the **"can act" layer** (READY tray, node glow, toasts). The Guide must add **meaning** ("why it matters"), never duplicate "you can buy". | [S] [TMT layer-features.md](https://github.com/Acamaeda/The-Modding-Tree/blob/master/docs/layer-features.md) |
| **Melvor Idle** | "Tutorial Island" (v1.0): new characters start there and complete basic tasks. **Skippable** by a button. Takes about 10–20 min. Pays roughly 6k GP. | A task chain with a **reward** and a **skip**. It is still long; ours must be shorter. | [C] search snippet of [patch notes](https://melvoridle.com/update/PatchNotes1.0.html) (page returned 403 to the fetcher) |
| **Legends of Idleon** | Quest-giver NPC Scripticus: 12 quests that teach combat, the shop and anvil, talents, mining, and building more characters, leading to the first boss. | **Quest chain = tutorial.** Each system gets its own short chain when it arrives. | [C] [IdleOn wiki](https://idleon.wiki/wiki/Scripticus) |
| **Bee Swarm Simulator** (Roblox) | Black Bear is the first quest giver. Pollen quests teach fields and swarm growth and pay honey, tickets and eggs. | Diegetic quest givers are the classic Roblox-simulator tutorial. | [C] [BSS wiki](https://bee-swarm-simulator.fandom.com/wiki/Black_Bear) |
| **Hello Kitty Cafe** (Roblox) | The target button is **spotlighted, the screen dimmed, a pink outline and an arrow** point at it. | Spotlight = one unmistakable next action. | [D] [Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques) |
| **Squishmallows** (Roblox) | Contextual tutorial fires when the player holds two identical Squishmallows (combine station). The market tutorial fires when the player finds the market. | **Trigger on state, when the player can act.** | [D] same page |
| **Plant** (Roblox reference project) | Timed hint: most players press PLANT within 10 s, so a highlight appears at **11 s**, only the first time, only for players who need it. | Timed hints tuned from playtest data. Use Configs to set the delay. | [D] same page |
| **Color or Die / Jailbreak** | An in-world sign explains the core mechanic without blocking play. Footprints hint at an escape route. | Diegetic hints: our painted realm can carry them (runes, light trails on the map). | [D] same page |
| **RoCitizens** | A tutorial quest pop-up with a reward. Roblox lists quest-based tutorials' advantages: active learning, small steps, "spread out over time", **built-in analytics**, and a reward. | Quest-shaped "next goal" = tutorial and funnel in one. | [D] [Quest design](https://create.roblox.com/docs/production/game-design/introduction-to-quest-design) |

NGU Idle, Idle Slayer and Realm Grinder were **not source-checked in this pass**, so they are left out of the evidence
table. Community knowledge only would add nothing firmer than the patterns above.

**Top Roblox simulators, observed pattern [U]:** a persistent quest tracker ("Hatch 3 eggs 1/3"), a beam or trail
toward the next zone, "!" badges on buttons, a free starter item, and a big celebratory rebirth pop-up. Roblox's own
onboarding page frames the goal as "teach the essentials, get to the fun quickly, leave players wanting more", with
low early thresholds and an intentional "moment of joy" at the end of onboarding
([Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)). [D]

## 2. FTUE pattern catalogue: when to use which

| Pattern | Use it for | Avoid when | Notes |
|---|---|---|---|
| **Diegetic** (signs, NPCs, world light) | First impression and the core fantasy | Precise UI steps | Our realm map is painted: use a pulsing rune on the M shrine and a light trail along tree links to a newly woken node [U] |
| **Spotlight / cut-out mask** | The one button that must be pressed now (first claim, first prestige, first challenge entry) | More than about 6 times in the whole game | Dims everything else. Must never trap: provide Skip and tap-through rules (§7) |
| **Coach mark** (pointer + chip, no dim) | A new node, tab or automation | Things the READY tray already says | The ≤ 6-word chip rule from DESIGN.md §9 fits: "hints ≤ 6 words… longer hints move into the ⓘ / tooltip, or a first-use coach mark" |
| **Contextual / just-in-time** | Every system after the first 5 minutes | n/a | Roblox: "increased learning retention, faster onboarding, reduced cognitive load" [D]. NN/g: highlight features "when it's actionable for them" ([NN/g](https://www.nngroup.com/articles/mobile-app-onboarding/)) |
| **Front-loaded deck of cards** | Never | Always | NN/g: it "tends to make the interface appear more complicated than it actually is, and strains user's memory"; tutorials "didn't improve task performance" |
| **Timed hint** | Stalls: no action after N seconds while an action is available | Instant pop-ups | Roblox: show "only the first time… only to those who need it" [D]. Tune N from data |
| **Quest / goal chain, "next goal" tracker** | Mid-term motivation and the funnel | Replacing player choice | Roblox: surfacing short/mid/long goals "provides a frequent reminder to players of what they're working towards" [D] |
| **Codex / How-to-Play log** | Re-reading, deeper rules, formulas | Being the only teaching tool | AD's H2P pattern [S]. Entries unlock when seen |
| **Skippable + replayable** | All tutorials | n/a | Melvor skip [C]. GAG: contextual help, objective reminders, practice without failure ([GAG](https://gameaccessibilityguidelines.com/include-contextual-in-game-helpguidancetips/)) |

## 3. Deciding what is "significant"

**Rubric [U]:** score each candidate moment and add up the points.

| Signal | +pts | Example in our game |
|---|---|---|
| A new **verb** or node/tab/map appears | +3 | Prestige at 5 milestones, Exploration, Corruptions |
| A **risky or irreversible** decision | +3 | First Super-Prestige wipes prestige upgrades. The last Atomic challenge "on enter sets milestones and points to 0". The Multiverse gate |
| A state that **looks like a bug** without an explanation | +3 | Milestone cost scaling at 14, the 1st-milestone softcap, milestone overflow at 170, points *divided* inside the Prestige Universe |
| **Automation or rule change** that changes optimal play | +2 | Passive prestige points at 20, auto-milestones (1st Meta-Milestone), "Prestige Boost doesn't reset anything" |
| New **UI type** seen for the first time | +2 | First repeatable purchase (Super-Prestige buyable at 77), first challenge, D-pad on the exploration map |
| Already signalled by the game (glow, READY, toast) | −2 | "Unlock 2 new Prestige Upgrades" (the node glows anyway) |
| Pure number change | −5 | 98 of 187 milestones |

**Tiers:** ≥ 5 → **S** (spotlight / fly-to card) · 3–4 → **A** (pointer + chip) · 1–2 → **B** (Guide log + quiet
toast) · ≤ 0 → nothing.

**Grounding stats [S]** (regex over `effectDescription` in `m.js`):

* unlock (48): 5, 10, 15, 21, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 77, 80, 85, 95, 99, 104, 109, 111, 115, 123–125,
  127–130, 132, 136, 137, 140, 142, 146, 151, 155, 158–161, 178, 181, 183–185, 187
* automation (23): 20, 57, 75, 83, 90, 103, 107, 108, 110, 113, 114, 116–121, 126, 131, 133, 157, 170, 175
* keep (9): 26, 81, 82, 100–102, 134, 153, 162
* challenge rules (9): 112, 122, 138, 141, 144, 145, 147, 150, 180

About half of the "unlock" lines only add a row of upgrades, and the node glow already announces those. The **187th
milestone says "Unlock a new layer in Prestige Universe" but nothing in v2.044 reads it**, so it is a placeholder:
don't hint it.

**Data-driven second pass [U]:** after launch, find the milestone counts where the time to the next milestone spikes
*and* sessions end (funnel "MilestoneRoad", §6). Add a hint there, or promote an existing one. Incremental walls
(scaling at 14, Super-Prestige at 25 because it needs 1e98 prestige points, the softcap) are the usual suspects.

## 4. Avoiding hint spam

Rules I recommend [U]. The Roblox and NN/g principles they come from are cited inline.

1. **Edges, not levels.** A hint fires when its condition *becomes* true, and at most **once per save**.
2. **Backfill on load.** When a save loads (especially an **imported web save**, which the port supports), every
   condition that is already true is marked *seen* silently. Otherwise a late-game import triggers 50 hints.
3. **Resolve on act.** If the player does the thing (opens the new node, buys the upgrade), the hint disappears and
   is logged as *acted*.
4. **One at a time, with a budget.** Show at most 1 on screen. Leave at least **45 s** between unsolicited hints and
   show at most **6 per 10 min**. The queue is ordered by tier, S > W > A > B. The numbers are a Config key, so they
   can be tuned and A/B-tested ([Configs](https://create.roblox.com/docs/production/configs)).
5. **Only when actionable.** Show a hint when the player is on the map or in the relevant panel, never during a hold,
   a modal, or the 2 s after a reset flash. If the moment has passed (10 min), the hint goes to the Guide log without
   a pop-up.
6. **Never restate the game's own signals.** READY and CAN BUY are the tray's job. The Guide explains *why* the new
   thing matters, once.
7. **Timed hints only for stalls.** For example, 12 s on the first claim with no input → pulse the spotlight. Show it
   once, only to the players who stall (Roblox *Plant* example [D]).
8. **Copy budget:** a title of ≤ 6 words and a body of ≤ 18 words, in second person, plain words. Never use "layer",
   "row", "buyable", "reset tier", ids or formulas. Formulas go in the codex.
9. **Guide OFF means OFF:** no spotlights, arrows, coach marks or next-goal chip. The game's own toasts, glows, READY
   tray and HUD warnings stay. The codex keeps collecting entries silently.

## 5. Accessibility

| Need | What Roblox gives us | Apply to tutorial and Guide |
|---|---|---|
| Text size | `GuiService.PreferredTextSize` (`Enum.PreferredTextSize`). `AutomaticSize` elements grow, and `TextScaled` text is **not** scaled by it ([Accessibility](https://create.roblox.com/docs/production/publishing/accessibility)) [V] | Chips and cards use `AutomaticSize`, not `TextScaled` |
| Motion | `GuiService.ReducedMotionEnabled`. The docs suggest `TweenInfo.Time = 0` when it is on [V] | No bobbing or pulsing; spotlight fades become instant. Also honour our own `Prefs.motion` (SYSTEM/FULL/REDUCED) |
| Transparency | `GuiService.PreferredTransparency`: multiply background transparency by it [V] | Card backgrounds use it. The dim scrim stays fixed so contrast holds |
| Colour | Docs: color contrast and **colour non-reliance** [D] | Warnings get an icon and a word, not just amber. DESIGN.md asks for ≥ 7:1 on the first-run chip |
| Input | `UserInputService.PreferredInput` (`Enum.PreferredInput`: Touch / KeyboardAndMouse / Gamepad / MicroGamepad; added 2025-05-27), `GuiService.SelectedObject` [V] | Wording follows the device ("Tap" / "Click" / "Press Ⓐ"). On gamepad, set `SelectedObject` to the spotlight target |
| Cognitive | GAG: "gradually introducing concepts… avoids overburdening" and objective reminders ([GAG](https://gameaccessibilityguidelines.com/include-contextual-in-game-helpguidancetips/), [Silence hints](https://gameaccessibilityguidelines.com/silence-hints/)) [C] | Next-goal chip = objective reminder. Codex = re-readable help. Replay tutorial |
| Help is accessible too | XAG 121: "in-game Help systems like tutorial hints… should also follow accessibility guidelines" ([XAG 121](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/121)) [C] | Hints are never timed out faster than they can be read. Allow ≥ 1 s per 3 words and at least 6 s, or require "Got it" |
| Language | Roblox recommends visual-first tutorials because "this visual emphasis also simplifies translation" [D] | All strings in one table, ready for `LocalizationService` auto-translation. No text baked into images |

## 6. Measuring drop-off with AnalyticsService

**API (all [V]; every method is server-only and `thread_safety: Unsafe`):**

| Method | Use | Key rules |
|---|---|---|
| `LogOnboardingFunnelStepEvent(player, step, stepName?, customFields?)` | The single onboarding funnel | One-time per user. Only the first instance of each step counts. Logging step N marks all steps below N complete. Filters (device, etc.) apply **at the first step**; cohort = the day of the first step |
| `LogFunnelStepEvent(player, funnelName, funnelSessionId?, step?, stepName?, customFields?)` | Progression funnels | **≤ 10 funnels, ≤ 100 steps each.** `funnelSessionId` only for recurring funnels. Analytics keeps the 10 most recent session ids per user per funnel |
| `LogCustomEvent(player, eventName, value?, customFields?)` | Guide adoption, skips, toggles | **≤ 100 event names**. Counters or values |
| `LogJourneyEvent(player, journeyName, nodeName, journeySessionId?, customFields?)` | Non-linear paths, shown as a Sankey diagram in Creator Hub | Added 2026-07-21. Names may not contain `, " '` or a newline, and node names may not start with `__` |
| `LogProgressionEvent` / `…Start/Complete/FailEvent` | Level attempts | The docs say it "does not currently display in any Roblox-provided charts". **Prefer funnels** |
| `GetPlayerSegmentsAsync(player)` | Runtime segments: `HasData`, `ActivePayerStatus`, `WhenUserFirstPlayed`, `PlatformSpenderStatus` | Added 2026-03-17. Yields, and results are cached per server session. Returns `HasData = false` instead of throwing |

**Limits** ([Event types](https://create.roblox.com/docs/production/analytics/event-types)) [D]: a global rate of
**120 + 20 × CCU requests a minute**. **3 custom fields** (`Enum.AnalyticsCustomFieldKeys.CustomField01..03.Name`,
string values) with at most **8,000 combined values** before the rest are grouped as "Other". Charts take **about
24 h** to appear, and **View Events** shows a near-real-time list for debugging. Events do not send from the client
or from Studio ([Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)). Validate any
client-reported step on the server, as the doc's example does.

**Experiments** [V/D]: use `ConfigService:GetConfigForPlayerAsync(player)` and then `ConfigSnapshot:GetValue(key)`.
The first `GetValue` call enrolls the player, so call it only when the player reaches the tested feature. Results
appear after at least 24 h. For multi-session onboarding tests, the docs say to "persist the value yourself, such as
in a data store" ([Experiments](https://create.roblox.com/docs/production/experiments)).

## 7. Roblox implementation notes

### 7.1 Spotlight masks: three recipes

| Recipe | How | Pros | Cons |
|---|---|---|---|
| **A. Huge stroke** | Hole `Frame` (transparent) + `UICorner` + `UIStroke{ BorderStrokePosition = Outer, Thickness = 10000, Color = black, Transparency = 0.45 }`. `SpotlightUI` (Jan 2026) uses exactly "a `Frame` with a `UIStroke` set to `10,000` thickness" ([thread](https://devforum.roblox.com/t/spotlightui-guided-focus-module/4267581/1)) | One instance, rounded hole, animates by tweening the Frame | The stroke sinks no input. The forum reports "UIStroke thickness has limits" ([thread](https://devforum.roblox.com/t/how-to-achieve-a-spotlight-gui-effect/3397197)) [C], so test on a 4K display |
| **B. 9-slice ring + 4 frames** (recommended) | A 64 px black image with a feathered transparent hole, `ScaleType = Slice` and `SliceCenter` = the hole, sized to target + feather. Four frames (top, bottom, left, right) fill the rest with the same black and alpha ([9-slice](https://create.roblox.com/docs/ui/9-slice)) | Exact full-screen coverage, a soft AAA edge, no overlaps, and the 4 frames double as input blockers | Two moving parts to keep in sync |
| **C. CanvasGroup** | Put overlay + callout in a `CanvasGroup` and fade with `GroupTransparency` | One-knob fades | "Consumes extra texture memory… When exceeding the memory cap, `CanvasGroup` will render as a blank texture", and it should have static sizes ([CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup)) [V]. Use it only on the small callout card, never full-screen |

**Input:** make the 4 blockers `TextButton`s (`Text = ""`, `AutoButtonColor = false`). They swallow taps outside the
hole, and nothing covers the hole, so the real button underneath gets the tap. Where available, set
`InputSink = Enum.InputSink.All`. It is "a more granular successor to the boolean `Active`", which only sinks input to
the 3D world. It was added 2026-09-08, so guard it with `pcall`, as `Overlay/Modals.luau` already does [V]. Whether a
non-button `ImageLabel` over a button lets clicks through should be checked in Studio [U].

### 7.2 Following the target, and pointing at map nodes

* UI targets: read `AbsolutePosition` / `AbsoluteSize` every `RenderStepped` while visible, or on their
  `GetPropertyChangedSignal`. Put the overlay in the same inset space as the target's `ScreenGui`, or add the first
  return of `GuiService:GetGuiInset()` [V].
* **Our map is a 2D GUI world** (nodes are positioned in 3840×2560 map units inside `view.nodes`). There is no need
  for `Camera:WorldToViewportPoint` (that is for 3D parts [V]). Target `nodes:widget(layer)` or
  `nodes:ringRect(layer)` (`Map/Nodes.luau`). If the node is off-screen, reuse the **edge markers**
  (`Map/Markers.luau`) and the existing fly-to, then spotlight after the camera settles.
* Curved pointer: `Path2D` with `Path2DControlPoint.new(pos, leftTangent, rightTangent)`. Place and rotate the
  arrowhead with `GetPositionOnCurve(1)` and `GetTangentOnCurve(1)` [V] ([2D paths](https://create.roblox.com/docs/ui/2D-paths)).
* Layering: one `ScreenGui` with a `DisplayOrder` above the HUD, panel and toasts, `ResetOnSpawn = false` and
  `ZIndexBehavior = Sibling` [V].

### 7.3 Mobile and console

* Keep cards inside `GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)` and clear of `GuiService.TopbarInset`
  (Roblox's top bar). Use `ScreenInsets = None` only for the full-screen scrim [V].
* Hit targets ≥ 44 px (DESIGN.md already uses 44 du). "Got it" goes in the lower half, reachable by a thumb. Callouts
  must not sit over the READY tray, the capsule or the phone band [U].
* Console: `GuiService.SelectedObject = target`. Blockers must not be `Selectable` [V]. Video previews are **not shown
  on Xbox, PlayStation or VR** [D], so the in-game FTUE is the only pitch those players get.

### 7.4 Persistence

* **Guide on/off** is a user preference. Add `guide = { "ON", "OFF" }` to `Prefs.ALLOWED` (`src/client/Core/Prefs.luau`).
  The server already validates prefs and saves them under the `client_<userId>` key (`Store.savePrefs`) [S].
* **Tutorial beat and seen hints** belong to the *save*. Store them next to `rec.options` in the session-locked save
  record (`Store.luau`), for example `rec.guide = { v = 1, tut = beat, skip = bool, seen = "<bitset>" }`. They are
  cleared by Hard Reset, never exported in the web export string, and backfilled on import (§4.2) [U].
* An A/B variant for onboarding must also be persisted there (Experiments docs, §6).

### 7.5 Where the conditions live

`port/rbx/view.js` builds everything the player sees and runs inside the game (transpiled, and tested in both
engines). Adding `rbx_guide()` there returns a compact **condition vector** (for example `"0110…"`, one char per
moment in §Opportunities C) and the next numeric goal. The Luau `Session` diffs it against `rec.guide.seen`, emits
edges to the client and logs analytics [U]. This reuses `getPointGen()` from `rbx_hud()` (the costly call is already
made once per view) and keeps every condition next to the JS it references.

### 7.6 Sketches

```lua
--!strict
-- Client: recipe B spotlight (9-slice ring + 4 blocker buttons). Sketch; wire to Motion/Theme in the real module.
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local DIM, FEATHER, SRC = 0.45, 24, 64 -- scrim alpha; feather px baked in the 64 px ring image

local function spotlight(playerGui: PlayerGui, ringImage: string)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.DisplayOrder, gui.IgnoreGuiInset = "GuideSpot", 60, true
	gui.ResetOnSpawn, gui.ZIndexBehavior, gui.Enabled = false, Enum.ZIndexBehavior.Sibling, false
	gui.Parent = playerGui

	local ring = Instance.new("ImageLabel")
	ring.BackgroundTransparency, ring.Image = 1, ringImage
	ring.ImageColor3, ring.ImageTransparency = Color3.new(0, 0, 0), DIM
	ring.ScaleType, ring.SliceCenter = Enum.ScaleType.Slice, Rect.new(FEATHER, FEATHER, SRC - FEATHER, SRC - FEATHER)
	ring.Parent = gui

	local blockers: { TextButton } = {}
	for i = 1, 4 do
		local b = Instance.new("TextButton")
		b.Text, b.AutoButtonColor, b.Selectable, b.BorderSizePixel = "", false, false, 0
		b.BackgroundColor3, b.BackgroundTransparency = Color3.new(0, 0, 0), DIM
		pcall(function() (b :: any).InputSink = (Enum :: any).InputSink.All end) -- added 2026-09-08
		b.Parent = gui
		blockers[i] = b
	end

	local target: GuiObject?, conn: RBXScriptConnection? = nil, nil
	local function place()
		local t = target
		if not t or not t.Visible then return end
		local sg = t:FindFirstAncestorWhichIsA("ScreenGui")
		local inset = if sg and not sg.IgnoreGuiInset then (GuiService:GetGuiInset()) else Vector2.zero
		local p = t.AbsolutePosition + inset - Vector2.new(8, 8)
		local s = t.AbsoluteSize + Vector2.new(16, 16)
		local vp = gui.AbsoluteSize
		local x0, y0, x1, y1 = p.X - FEATHER, p.Y - FEATHER, p.X + s.X + FEATHER, p.Y + s.Y + FEATHER
		ring.Position, ring.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0)
		local r = {
			{ 0, 0, vp.X, y0 }, { 0, y1, vp.X, vp.Y - y1 },       -- top, bottom
			{ 0, y0, x0, y1 - y0 }, { x1, y0, vp.X - x1, y1 - y0 }, -- left, right
		}
		for i, q in r do
			blockers[i].Position = UDim2.fromOffset(q[1], q[2])
			blockers[i].Size = UDim2.fromOffset(math.max(0, q[3]), math.max(0, q[4]))
		end
	end
	return {
		show = function(t: GuiObject)
			target, gui.Enabled = t, true
			if conn then conn:Disconnect() end
			conn = RunService.RenderStepped:Connect(place)
			if GuiService.ReducedMotionEnabled then place() end -- else tween DIM in (omitted)
		end,
		hide = function()
			target, gui.Enabled = nil, false
			if conn then conn:Disconnect(); conn = nil end
		end,
		blocked = blockers, -- connect .Activated to "tap outside" counting (3 taps → offer Skip)
	}
end
return spotlight
```

```lua
--!strict
-- Server (Worker actor): log a guide edge. AnalyticsService is thread-unsafe, so synchronize first.
local AnalyticsService = game:GetService("AnalyticsService")
local CF = Enum.AnalyticsCustomFieldKeys

local function logEdge(plr: Player, kind: "onboard" | "road" | "hint", step: number, name: string, cohort: string)
	task.synchronize()
	local fields = { [CF.CustomField01.Name] = cohort } -- "fresh" | "import" | variant id
	pcall(function()
		if kind == "onboard" then
			AnalyticsService:LogOnboardingFunnelStepEvent(plr, step, name, fields)
		elseif kind == "road" then
			AnalyticsService:LogFunnelStepEvent(plr, "MilestoneRoad", nil, step, name, fields)
		else
			AnalyticsService:LogCustomEvent(plr, "GuideHintShown", 1, { [CF.CustomField01.Name] = name,
				[CF.CustomField02.Name] = cohort })
		end
	end)
	task.desynchronize()
end
```

---

# PART 2: Publishing assets on Roblox (2025–2026)

## 8. Experience icon [D]

([Icons](https://create.roblox.com/docs/production/publishing/experience-icons))

* A **square, at least 512×512** template. It scales down to about **150×150** in places, so preview it small.
* **One icon per locale.** It is auto-generated from defaults on the first publish. Upload it under Creator Dashboard
  → Configure → Places → start place → **Icon**.
* It **must pass moderation** before others see it.
* Best practice: express the theme, tone and genre. No ambiguous corner graphics. Use colour and contrast to signal
  tone.

## 9. Thumbnail images [D]

([Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails))

* **Up to 10 images or videos** on the detail page. **16:9**, ideally **1920×1080**. Formats `.jpg .gif .png .tga
  .bmp`. Non-16:9 uploads are **stretched**. Alt text can be set per thumbnail.
* **Home-page personalization:** activate **2–5** thumbnails, each **under 3 MB and 1920×1080**. Roblox shows each one
  to random users and then favours the winner per user group. In testing, this gave an average **+8.5% qualified
  play-through rate**, and up to +50% for some games. Keep several active, and refresh the set with each major update.
* Metrics: Impressions, Qualified Plays, Average Playtime, Qualified Play-Through Rate, Winning Segment.
* **Keep essential text and elements out of the bottom band**, because metadata such as the player count covers it.
* The auto-generated option comes from Studio's camera at the last publish. Uploaded images and videos are moderated
  against the Community Rules and Terms of Use.

## 10. Video previews (game page and Home)

| Item | Value | Tag / source |
|---|---|---|
| Where to upload | Creator Dashboard → Configure → Places → place → **Videos** | [D] |
| Cost | Free (the old YouTube-link video cost 500 Robux) | [A] [2025-11-13 announcement](https://devforum.roblox.com/t/video-previews-for-your-games-page/4068103) |
| YouTube links | Can no longer be added. A Jan 2026 bug report got a staff reply pointing to the Video Previews announcement | [A/C] [thread](https://devforum.roblox.com/t/cant-upload-youtube-video-as-thumbnail-anymore/4267781) |
| Placement | "Appears **first** on your game's detail page, and it can also be shown on the Home page." Since 2026-08-31 in **Recommended For You** | [D], [A] [Home announcement](https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601) |
| Results quoted | Superstar Baseball +30% RFY plays and +31% playtime. Notoriety +41% RFY plays and +39% playtime. "Video" annotations in the Acquisition, Engagement and Retention tabs | [A] same |
| Quota | **3 uploads a month**. **Rejected videos count against the quota**. Users report failed uploads consuming quota too | [D], [C] |
| Specs | **MP4 or MOV, under 100 MB, ≤ 60 s, 640×360–1920×1080, 16:9, about 15 Mbps** (requirements as quoted by a developer in Apr 2026). The launch post mentioned 60-second videos | [C] [thread](https://devforum.roblox.com/t/video-thumbnail-upload-failing-despite-meeting-requirements/4591866) |
| Review time | About 24 h (staff comment on the Home post). Reports exist of weeks-long reviews | [A/C] |
| Not shown on | Xbox, PlayStation, VR headsets. Private games cannot have video previews | [D], [A] |
| **Allowed** | Varied camera angles and free-camera shots (Studio freecam: Shift+P in a solo test). Minor brightness and contrast work. **Logo or branding overlay**. **Curated highlight-reel sequences** of real gameplay. In-game UI text. **Music from Roblox's catalog** "as governed by Roblox's internal licensing arrangements" | [D] |
| **Rejected** | Misrepresented gameplay or theme. Artificially enhanced graphics. Real-life footage. **Voice-overs, narration, voice chat, music with lyrics**. Ads, promos or subjective claims ("50% off", "Free UGC!"). Overlay text only "sparingly… to describe gameplay contexts" | [D] |
| Best practice (Roblox) | "Show real, current in-game footage and your core gameplay loop." "Keep the video focused and easy to understand within the first few seconds." Avoid cinematic trailers and dramatized gameplay | [A] Home post |

Social links (a separate field) can point to YouTube, Discord, Twitch, X/Twitter, Facebook, Guilded or a Roblox
community, one of each type ([Social links](https://create.roblox.com/docs/production/promotion/social-media-links)). [D]

## 11. Description [D]

([Descriptions](https://create.roblox.com/docs/production/publishing/descriptions))

* The **first ~160 characters are the hook**, used for search snippets and first impressions. The limit is **1,000
  characters**.
* Tags and hashtags are "explicitly not recommended". They don't help ranking.
* Don't list controls: "New players should learn the controls through a clear tutorial."

## 12. Sponsored games, search ads and other formats [D]

([Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager),
[Search ads](https://create.roblox.com/docs/production/promotion/search-ads),
[Advertise on Roblox](https://create.roblox.com/docs/production/promotion/advertise-on-roblox))

* **Campaign goals.**
  * **Plays**: broad reach. It helps recommendation systems learn and can lead into Recommended For You.
  * **Earnings**: limited availability.
  * **Engagement**: age-checked, highly engaged players, counted toward the **Roblox Kids & Select** threshold. It has
    a higher cost per play, and it does not auto-pause.
* **The docs tie ads to FTUE:** "If you don't see progress after 3–5 days, consider improving your game's onboarding
  and first-time user experience before continuing."
* **Creatives** are the thumbnail on Home. There are **up to 10 per campaign**, evenly distributed and toggleable. They
  display at **16:9** (other ratios are resized). You can reuse existing thumbnails, upload new ones, or use **AI
  generate**, which makes 3 variations from a text prompt.
* **Asset library**: images *or videos*, auto-moderated (typically within 48 h), with appeals.
* **Placement:** campaigns show on **both Home and Search** automatically. Games that closely resemble existing games
  are deprioritized ("no ad spend and no conversions").
* **Search ads:** **up to 10 keywords per Ad Set** with exact match. A relevance-weighted second-price auction. Reaches
  **13+**, all regions, with no audience targeting. Bid only on relevant words.
* **Payment:** card or **ad credits**. Converting Robux is available to users 13+, is permanent, and uses the 18+ US
  DevEx-rate Robux first. Group games are supported.
* **Immersive ad units** (billboards, portals, rewarded video) inside other games accept games, videos and images as
  advertised content. Rewarded video runs 6–30 s ([Rewarded video](https://create.roblox.com/docs/production/promotion/rewarded-video-ads)).
* **Roblox's own numbers:** a **150% lift in impressions, +24% plays and +16% playtime** for games that run ads.
  **Hypershot** scaled from **10 to 25 creatives**, paused the weak ones, and gets **up to 10% of plays** from Sponsored
  ([Advertise](https://create.roblox.com/docs/production/promotion/advertise)).
* **Standards:** everything must follow the Advertising Standards. Independent ads need clear disclosure, and the
  `PolicyService:GetPolicyInfoForPlayerAsync().AreAdsAllowed` check applies to in-game ad content
  ([Advertising standards](https://create.roblox.com/docs/production/promotion/comply-with-advertising-standards)).

## 13. Promotion craft: the first 3 seconds

* **TikTok (official):** "Introduce your content proposition in the **first 3 seconds** for better recall", and put
  the hook in the first 6 s. Use 9:16 at ≥ 720p, captions or overlays at 5–10 words a second, and keep inside the UI
  safe zone ([TikTok creative best practices](https://ads.tiktok.com/help/article/creative-best-practices?lang=en)). [C: official TikTok, non-Roblox]
* **Roblox Home video:** make it understandable "within the first few seconds", and show the core loop and real
  footage. [A]
* **Industry consensus** (third-party, [C]): gameplay beats polish for install intent. Design for **sound off**, with
  captions. Test **3–5 hook variants** per edit.
* **For an incremental game [U]:** the hook is **the number going vertical plus the reset flash**. Open on a
  milestone claim that cascades: the points capsule rolls through e-notation, the realm camera pulls back, and the
  tree lights up node by node. No logo first, no black frames. The core verb (claim → prestige) should be on screen
  before second 3.

## 14. Music for trailers and ads: what is licensed where

| Use | Creator Store / APM / partner music | Our commissioned or owned music | Source |
|---|---|---|---|
| In-game | ✓ (licensed for use on Roblox) | ✓ (upload under the group; we must hold all rights) | [D] [Audio assets](https://create.roblox.com/docs/audio/assets); `audio.md` §6 |
| **Roblox video preview** on the game page or Home | ✓ "Videos can contain music from Roblox's catalog" (no lyrics) | ✓ (instrumental) | [D] Thumbnails |
| Gameplay capture on YouTube, TikTok, X… | ✓ only if the music is "synchronized with the Roblox game content featured on the video capture" | ✓ | [C] search snippet of [Using Licensed Music in Videos](https://en.help.roblox.com/hc/en-us/articles/360038525351-Using-Licensed-Music-in-Videos) (403 to the fetcher) |
| **Trailer** with cinematics, logo cards or non-gameplay animation | ✗ "not permitted… in game trailers that do not feature gameplay or only partially include gameplay" | ✓ | [C] reply in [DevForum thread](https://devforum.roblox.com/t/questions-regarding-usage-of-licensed-music-off-platform/3639860), May 2025 |
| Film, TV, **commercial**, merch, another game off Roblox | ✗ (APM terms, same help article) | ✓ if the contract covers ads | [C] |

**Options for off-platform music:**

* **Commission an original score** as a buyout or an exclusive license. The contract should cover in-game use,
  Roblox uploads, the Roblox video preview, off-platform trailers, **paid ads** and social posts. **Ask the composer
  not to register the tracks with YouTube Content ID**, or to whitelist our channel and creators. Otherwise
  YouTubers' gameplay videos of our game get claimed [U].
* **Subscription libraries:** Epidemic Sound's **Pro** plan adds "digital ads" and client sublicensing; the basic
  plans don't cover paid ads ([plans](https://www.epidemicsound.com/our-plans/)) [C]. Read the licence text for the
  exact channel list before buying.
* **YouTube Audio Library:** its standard license is YouTube-scoped. **CC-BY** tracks require credit in the video
  description ([YouTube Help](https://support.google.com/youtube/answer/3376882)). CC-BY is awkward for the Roblox
  video preview, which has no credits field and allows no promo text [U].

---

# Opportunities for Milestone Tree

What exists today [S]: first-run mode while `player.m.best == 0` (`h.fr` in `rbx_hud`). A **START HERE** chip bobs over
M. The READY tray, portal, zoom and rate pill are hidden. The cue leaves after the first milestone (DESIGN.md §7.12,
`Map/Nodes.luau`). The READY tray has a one-time gesture hint, "Tap to open · hold to prestige" (`Hud/Ready.luau`).
The portal pill reads "SEALED n/185". Everything below builds on that.

## A. First-run tutorial script (8 beats, about 5 minutes)

It runs only on a **fresh save** (`m.best == 0` and not imported) and can be skipped at any time with a **Skip** chip
top-right in the safe area. Tapping the scrim 3 times also offers Skip. It can be replayed from Options as a tour with
Next buttons. Every beat completes on **game state**, AD-style, so a player who races ahead skips beats naturally.
Onboarding funnel steps log real progress, not tutorial UI.

| # | Beat | Trigger | UI | Copy (≤ 6-word title / body) | Completes when | Onboarding step |
|---|---|---|---|---|---|---|
| 0 | Arrive | Save loaded, fresh | Existing START HERE chip; realm camera eases to the M shrine | (chip) **Start here** / Get your first milestone | n/a | 1 "Joined" |
| 1 | First claim | Beat 0 + 1.5 s | **S**: spotlight M node, then the claim button in the M panel. Timed pulse after 12 s idle | **Claim your first milestone** / You start with 10 points, just enough | `player.m.best.gte(1)` | 2 "First milestone" |
| 2 | Points flow | Beat 1 done | **A**: pointer at the points capsule and rate pill for 4 s; confetti burst on the first rate tick | **Milestones make points** / Every second, forever. Claim more to go faster | `player.m.best.gte(2)` or 6 s | n/a |
| 3 | The ladder | M panel open, or 20 s | **A**: pointer at the NEXT milestone card | **Each milestone adds a power** / At 5 milestones, a new node wakes | Panel opened (`player.tab == "m"`) and closed again | 3 "Opened milestones" |
| 4 | Next goal | Beat 3 done | Next-goal chip appears under the capsule: "5 milestones · Prestige" with a bar | (chip only) | `player.m.best.gte(5)` | 4 "Five milestones" |
| 5 | A node wakes | `m.best` reaches 5 | **S**: camera flies to P as it wakes, link lights from M → P, then a card | **Prestige is awake** / Trade points for prestige points. Milestones are never lost | Card dismissed or P opened | n/a |
| 6 | First prestige | `canReset("p")` (≥ 3,000 points) | READY tray reappears. **A**: pointer at the gem, with the existing "Tap to open · hold to prestige" | **Hold to prestige** / Points reset; prestige points arrive | `player.p.total.gt(0)` | 5 "First prestige" |
| 7 | First upgrade | `player.p.points.gte(1) && !hasUpgrade("p", 11)` | **S**: spotlight Prestige Boost I in the P panel | **Spend it on an upgrade** / Upgrades keep working until a bigger reset | `hasUpgrade("p", 11)` | 6 "First upgrade" |
| 8 | Your Guide | Beat 7 done + 2 s | Moment of joy: trophy sparkle, then a card with two buttons | **The tree is yours** / I'll point out only the big moments. **[Keep Guide on] [Turn off]** (also in Options) | A button is pressed | 7 "Tutorial done" (+ custom `GuideChoice` 1/0) |

The later onboarding steps are logged as progress continues, whatever the tutorial state: 8 "10 milestones",
9 "25 milestones", 10 "First Super-Prestige". Custom events: `TutorialSkipped` (value = beat), `TutorialReplayed`,
`SaveImported` (value = `m.best`).

## B. Guide rules (on/off toggle)

1. **Scope:** only the moments in table C, about 65 across the whole game. Never ordinary upgrades or number boosts.
2. **Default ON** for fresh saves. Imported or late saves stay ON but are **backfilled** (every true condition is
   marked seen), and they get one card: "Welcome back: I'll only point out what's new from here."
3. **Tiers:**
   * **S**: camera fly-to + spotlight + card. Reserved for new nodes, universe changes and risky entries.
   * **A**: pointer + chip + ⓘ.
   * **W**: an amber warning chip with an icon and a word.
   * **B**: Guide log entry + quiet toast.
4. **Budget:** 1 visible at a time; ≥ 45 s apart; ≤ 6 per 10 min; S may jump the queue. Nothing during holds, modals
   or 2 s after a reset. The values come from Config keys so they can be tuned (§4).
5. **Once per save, resolve on act, expire into the log** after 10 min if the player never came near it.
6. **Guide log ("?" on the dock):** searchable, entries unlock when seen, 2–3 sentences plus the exact rule. Opening
   it while a panel is open jumps to that node's entry (AD's H2P `tab` field).
7. **Next-goal chip:** the next unmet milestone-count moment ("25 milestones · Super-Prestige") with a progress bar.
   After 160 milestones it becomes the rift countdown. Hidden when the Guide is OFF unless pinned.
8. **Guide OFF:** turns off S, A and B pop-ups, pointers and the goal chip. The game's own toasts, glows, READY tray,
   HUD softcap and overflow lines and the portal pill stay. Warnings (W) still reach the log.
9. **Copy:** plain second-person language; a title of ≤ 6 words and a body of ≤ 18. No internal words ("layer", "row",
   "buyable", ids). Use the game's own `format()` for numbers.
10. **Accessibility:** follow §5 (text size, reduced motion, controller selection, device-aware verbs, no
    colour-only meaning, no timeouts faster than reading speed).
11. **Measure:** log `GuideHintShown`, `GuideHintActed` and `GuideHintDismissed`, with CustomField01 = moment id and
    CustomField02 = tier, plus `GuideToggled` (value 0 or 1). Compare D1 and D7 retention by `GuideChoice`.

## C. Significant moments (65)

The conditions use `game-js` names. `canReset`, `hasUpgrade`, `hasMalware` and `challengeCompletions` are the game's
own helpers (`hasMalware(l, i)` = `player[l].pseudoBuys.includes(i)`, with **0-based** milestone indices). "When" is
the usual point in a run. T = tutorial beat.

### Act I: the first tree (0–26 milestones)

| # | When | Moment | Trigger | Tier | Hint (why it matters) |
|---|---|---|---|---|---|
| 1 | start | First milestone | `player.m.best.gte(1)` | T | Milestones are your main power. Each one makes points flow faster, forever. |
| 2 | m1 | First trophy | `hasAchievement('ach',11)` (points/sec ≥ 1) | B | Trophies give small permanent bonuses. Peek at the trophy shelf now and then. |
| 3 | m5 | Prestige wakes | `player.m.best.gte(5)` | T/S | A new node woke up. Prestige trades points for prestige points, and your milestones are never lost. |
| 4 | ~3k pts | First prestige ready | `canReset('p') && player.p.total.eq(0)` | T | You can prestige now. Points go back to zero, but you come back stronger. |
| 5 | first PP | First prestige upgrade | `player.p.points.gte(1) && !hasUpgrade('p',11)` | T | Spend prestige points on upgrades. They keep working until a bigger reset. |
| 6 | m10 | Self-growing prestige | `player.m.best.gte(10)` | B | Two new prestige upgrades make prestige points grow themselves. |
| 7 | m14 | Milestones get pricier | `player.m.best.gte(tmp.m.getScalingStart)` (14 + trophy/upgrade shifts; also `hasAchievement('ach',13)`) | W | Milestones now cost more each time. That's normal, and later upgrades make them cheaper. |
| 8 | m20 | Automatic prestige points | `player.m.best.gte(20)` | A | Prestige points now pour in on their own. You rarely need to prestige by hand. |
| 9 | m25 | Super-Prestige wakes | `player.m.best.gte(25)` | S | Super-Prestige: a bigger reset for a much bigger reward. It needs 1e98 prestige points. |
| 10 | 1e98 PP | First Super-Prestige ready | `canReset('sp') && player.sp.total.eq(0) && player.m.best.lt(26)` | W | Heads up: this clears your prestige upgrades too, until you reach 26 milestones. |
| 11 | m26 | Upgrades survive | `player.m.best.gte(26)` | B | Prestige upgrades now survive Super-Prestige. |

### Act II: automation and boosts (27–98)

| # | When | Moment | Trigger | Tier | Hint |
|---|---|---|---|---|---|
| 12 | m40 | Meta-Milestones | `player.m.best.gte(40)` | S | Meta-Milestones are milestones for your milestones. The first one buys milestones for you. |
| 13 | mm1 | Auto-milestones | `player.mm.best.gte(1)` | A | Milestones now buy themselves. Put your attention on upgrades and resets. |
| 14 | m45 | Cheaper milestones | `player.m.best.gte(45)` (prestige upgrades 31–34 appear) | A | These upgrades make milestones cheaper. They're the best buy when you feel stuck. |
| 15 | m50 | Prestige Boost | `player.m.best.gte(50)` | S | Prestige Boosts make every prestige point stronger. Each boost costs more than the last. |
| 16 | m57 | Automatic super-prestige points | `player.m.best.gte(57)` | B | Super-prestige points now come in on their own. |
| 17 | m60 | Hyper-Prestige | `player.m.best.gte(60)` | S | Hyper-Prestige is the third tier of reset, and the biggest reward so far. |
| 18 | m65 | Free boosts | `player.m.best.gte(65)` | B | Taking a Prestige Boost no longer resets anything. Grab them freely. |
| 19 | m75 | Automatic hyper points | `player.m.best.gte(75)` | B | Hyper-prestige points now come in on their own. |
| 20 | m77 | First repeatable upgrade | `player.m.best.gte(77)` | A | This upgrade can be bought again and again. Hold the button to buy fast. |
| 21 | m80 | Atomic-Prestige | `player.m.best.gte(80)` | S | Atomic-Prestige unlocked, and Prestige Boosts are now collected for you. |
| 22 | AP up. 22 | First challenge | `hasUpgrade('ap',22)` (Atomic challenge "No Super-Prestige" unlocks) | S | Challenges: play with a handicap to earn a lasting reward. You can leave anytime. |
| 23 | first clear | Challenge cleared | any `challengeCompletions('ap', id) > 0` | B | Cleared! Many challenges can be cleared again for a bigger reward. |
| 24 | m95 | "No Prestige" challenge | `player.m.best.gte(95)` | B | A new Atomic challenge, and Hyper-Prestige's repeatable upgrade now buys itself. |

### Act III: Transcend and the slowdowns (99–180)

| # | When | Moment | Trigger | Tier | Hint |
|---|---|---|---|---|---|
| 25 | varies | Softcap | `getPointGen().gte(getPointSoftcapStart().sqrt())` (the HUD `softcap` warning) | W | Your points are slowing down. Look for anything that says "softcap starts later". |
| 26 | m99 | Transcend | `player.m.best.gte(99)` | S | Transcend: a new reset with its own upgrades and challenges. |
| 27 | m103 | Auto Atomic clears | `player.m.best.gte(103)` | B | Atomic challenges now clear themselves each time you Transcend. |
| 28 | m104 | Hyper Boost + Transcend challenges | `player.m.best.gte(104)` | S | Hyper Boost unlocked, plus your first Transcend challenge. |
| 29 | m110 | Transcend trickle | `player.m.best.gte(110)` | B | Transcend points now trickle in, and Atomic challenges can be finished without leaving. |
| 30 | m116 | Auto Hyper Boosts | `player.m.best.gte(116)` | B | Hyper Boosts are now collected for you. |
| 31 | m123 | Softcap Delayer | `player.m.best.gte(123)` | A | Softcap Delayer: a repeatable buy that pushes the slowdown back. |
| 32 | m125 | Prestige Energy | `player.m.best.gte(125)` | S | Prestige Energy resets nothing, so take it whenever you can. |
| 33 | m130 | Special Transcend Points | `player.m.best.gte(130)` | A | New Transcend tab: earn special points inside Transcend challenges for big boosts. |
| 34 | m140 | Super Energy | `player.m.best.gte(140)` | S | Super Energy unlocked, and Atomic challenge wins now stay when you Transcend. |
| 35 | m145 | Clear from outside | `player.m.best.gte(145)` | B | Some challenges can now be finished without entering them. |
| 36 | m151 | Prestige Power | `player.m.best.gte(151)` | S | Prestige Power: level up its Power Scaler to open new bonuses. |
| 37 | m160 | Exotic Prestige | `player.m.best.gte(160)` | S | Exotic Prestige and its Fusioner: a new way to multiply everything. |
| 38 | mm30 | Extra-Milestones | `player.mm.best.gte(30)` | A | Extra-Milestones: milestones for your meta-milestones. The first one collects meta-milestones for you. |
| 39 | m170 | Overflow | `player.m.points.gte(getCostOverflowStart())` (the HUD `overflow` warning) | W | Milestone costs jump again (overflow). Multiverse upgrades will soften it. |
| 40 | m170 | Auto Extra-Milestones | `player.m.best.gte(170)` | B | Extra-Milestones are now collected for you. |
| 41 | m175 | Auto Challenge Slayer | `player.m.best.gte(175)` | B | Challenge Slayer now levels itself. |
| 42 | m178 | The harshest challenge | `player.m.best.gte(178)` (Atomic challenge "Over-overflowed Milestones") | W | Careful: entering this challenge sets your milestones and points to zero. Your record stays. |

### Act IV: the Multiverse gate (181–185)

| # | When | Moment | Trigger | Tier | Hint |
|---|---|---|---|---|---|
| 43 | m181 | Multiverse Prestige | `player.m.best.gte(181)` | S | Multiverse Prestige: the road to a second universe starts here. |
| 44 | MP up. 13 | Fusioners | `hasUpgrade('mp',13)` | A | Fusioners turn Multiverse points into lasting boosts, and you can respec them. |
| 45 | m183 | Multiverse challenges | `player.m.best.gte(183)` | B | Multiverse challenges unlocked. Their rewards strengthen your Fusioners and Prestige Power. |
| 46 | m160+ | Rift countdown | `player.m.best.gte(160) && player.m.best.lt(185)` | goal chip | The rift to the Prestige Multiverse opens at 185 milestones. |
| 47 | m185 | The rift opens | `player.m.best.gte(185)` (`rbx_mapGate().show`) | S | The Prestige Multiverse is open. Entering wipes your normal currencies. You keep your best milestones and upgrades. |
| 48 | inside | First crossing | `player.mp.activeChallenge == 21` (first time) | S | Welcome to the Prestige Universe. Here your milestones slow points down, and that's the rule. |
| 49 | inside | Finish available | `canCompleteChallenge('mp',21)` (the gate's `fin`) | A | You can finish this crossing now for its reward. |

### Act V: the Prestige Universe

| # | When | Moment | Trigger | Tier | Hint |
|---|---|---|---|---|---|
| 50 | pm1 | Prestige Milestones | `player.pm.best.gte(1)` | A | Prestige Milestones turn that slowdown into prestige essence, which multiplies your points. |
| 51 | pm5 | Exotic returns | `player.pm.best.gte(5)` | S | Exotic Prestige returns with brand-new powers. |
| 52 | pm6 | Corruptions | `player.pm.best.gte(6)` | S | Corruptions: reset to plant malware on a disk, tap it to start, then fix it for essences. |
| 53 | first fix | Corruption fixed | `player.cp.totalCorrupt >= 1` | B | Fixed! Every corruption you fix counts toward a new kind of milestone. |
| 54 | pm7 | Two at once | `hasUpgrade('cp',11)` | B | You can now fix two corruptions at the same time. |
| 55 | pm10 | Corrupted Milestones | `player.pm.best.gte(10)` | S | Corrupted Milestones reward you for every corruption fixed. |
| 56 | cm4 | Antivirus | `player.cm.best.gte(4)` | A | Antivirus now fixes weak corruptions for you. |
| 57 | pm12 | Universe challenges + Milestone Dilation | `player.pm.best.gte(12)` | A | New challenges here, and Milestone Dilation now turns milestones into Prestige Ashes. |
| 58 | pm15 | Infect milestones | `hasUpgrade('mp',21)` (visible at `pm.best ≥ 15`) | S | You can infect milestones: pay a mountain of points to give one a second, stronger effect. |
| 59 | first infect | First infection | `player.m.pseudoBuys.length >= 1` | B | Infected! Each milestone can carry one extra effect. |
| 60 | malware 5th | Upgrade Perks | `hasMalware('m',4)` | A | Upgrade Perks: earn perks to unlock hidden prestige upgrades. You can respec them. |
| 61 | malware 10th | Exploration | `hasMalware('m',9) && player.mp.activeChallenge == 21` | S | Exploration: walk a map to discover new powers. |
| 62 | first EX point | Moving on the map | `player.ex.points.gte(1)` | A | Move with the arrow pad or arrow keys. The yellow star marks the next reward. |
| 63 | malware 15th | Portals | `hasMalware('m',14)` | A | Portals lead to new zones; the yellow arrow takes you back. |
| 64 | malware 16th | Spark Milestones | `hasMalware('m',15)` | S | Burn Prestige Ashes to light Spark Milestones. They burn out, so relight them. |
| 65 | e1e45 pts | The end, for now | `isEndgame()` (points ≥ e1e45) | S | You've reached the top of the tree, for now. |

**Deliberately excluded:**

* `m.js` number boosts (98 milestones), including every "is boosted" / "^x" upgrade.
* Rows of new upgrades: the node glow covers them.
* The 187th milestone (a placeholder).
* The "Caution" tab (`unlocked() {return false}` in `cp.js`).
* Per-zone exploration rewards: the game already glows the EX node and names the zone (`shouldNotify`).

## D. Build plan (smallest useful slice first) [U]

1. `port/rbx/view.js`: add `rbx_guide()` → `{ c: "<65-char condition vector>", next: { id, have, need } }`, and add
   `v.guide` to `rbx_view()`. It is covered by the existing JS↔Luau view comparison.
2. `Session.luau`: diff `c` against `rec.guide.seen`, backfill on load and import, and choose edges (budget rules
   B.4). Send `{ id, tier }` in the patch. Log analytics after `task.synchronize()`.
3. Client:
   * `Overlay/Guide.luau`: spotlight (recipe B), pointer (`Path2D`), card and chip, using Theme, Kit and Motion.
   * Reuse `Map/Markers.luau` and fly-to for off-screen nodes.
   * Add a `guide` key to `Prefs.luau`.
   * In Options: GUIDE ON/OFF, REPLAY TUTORIAL, GUIDE LOG.
4. Strings: one Lua table `GuideText` (id → title, body, more), ready for localization.
5. Experiments: Config keys `guide_budget_gap_s` (45), `guide_budget_10min` (6), `tut_idle_hint_s` (12). Run an A/B
   of `tut_variant` = full (8 beats) vs. lean (beats 0, 1, 5, 6, 8), measuring D1 retention. Persist the variant in
   `rec.guide`.

## E. Analytics plan

| Instrument | Name | Steps / fields |
|---|---|---|
| Onboarding funnel | (built-in) | 1 Joined · 2 First milestone · 3 Opened milestones · 4 Five milestones · 5 First prestige · 6 First upgrade · 7 Tutorial done · 8 10 milestones · 9 25 milestones · 10 First Super-Prestige. CustomField01 = `fresh`, `import` or the variant |
| Funnel | `MilestoneRoad` | m 5, 10, 14, 20, 25, 40, 50, 60, 80, 99, 104, 125, 140, 151, 160, 170, 181, 185 (18 steps) |
| Funnel | `PrestigeUniverse` | entered · pm1 · pm5 · pm6 · pm10 · pm12 · pm15 · exploration · spark |
| Custom events | `GuideHintShown` / `Acted` / `Dismissed`, `GuideToggled`, `GuideChoice`, `TutorialSkipped`, `TutorialReplayed`, `SaveImported` | CF01 = moment id, CF02 = tier, CF03 = guide on/off. About 65 × 5 × 2 value combinations, far under 8,000 |
| Journey | `FirstHour` | Node opened (M, P, trophies, options, rift…) to see where new players wander |
| Segments | `GetPlayerSegmentsAsync` | `WhenUserFirstPlayed` decides between the "Welcome back" card and the first run on an existing account |

## F. Trailer, thumbnail and icon plan

**Icon (512×512 master, designed at 1024):** the M milestone crystal at the crown of the tree, haloed by the conical
rift ring (#ff2e63 → #b35cff → #ff5a1f → #ffd34d, the portal's own gradient) on the void (#07060d). No text. Check
that it reads at 150 px and at 50 px. Variant B: the rift portal alone. Test both through locale icons or a
re-upload per update [U].

**Thumbnails (5 active for personalization; 1920×1080; < 3 MB; key content in the top 80%; ≤ 3 words each):**

| # | Scene (real game states) | Words |
|---|---|---|
| 1 | The painted realm at full bloom: every node lit, links glowing, e-notation points capsule | "GROW THE TREE" |
| 2 | Prestige flash: the READY gem's charge ring completing, numbers bursting | "PRESTIGE" |
| 3 | The Multiverse rift open, crimson aura, the Prestige Universe beyond | "ENTER THE MULTIVERSE" |
| 4 | Corruption disks: green malware on the grid, the Antivirus lit | "FIX THE CORRUPTION" |
| 5 | Exploration map with the D-pad, the gold star and a portal | "EXPLORE" |

Stage every scene from **real saves**. The port imports web-game saves, so use real mid- and late-game saves rather
than `port/gen_states.js` random states, which are plausible but not played.

**Video preview (≤ 60 s, 16:9 1080p MP4 H.264 about 15 Mbps, < 100 MB, instrumental original music, no VO, no
lyrics, overlay text only as gameplay context):**

| t (s) | Shot | On-screen text (sparingly) |
|---|---|---|
| 0–3 | A milestone claim cascades: the points capsule rolls into e-notation, the camera pulls back from M to the whole glowing tree | none |
| 3–12 | Core loop: claim → points climb → READY gem → hold → charge ring → prestige flash | "Claim milestones. Prestige." |
| 12–26 | Nodes waking one after another (P → SP → HP → AP → T…), 1.5 s each, links lighting | "21 layers" |
| 26–38 | Challenges panel, Spark Milestones burning, Fusioners | none |
| 38–50 | The rift opens, the crossing (palette shifts), corruption disks, exploration steps | "A second universe" |
| 50–60 | Wide realm shot, logo overlay (allowed) | logo only |

Captured at real speed. If some shots are sped up with `devSpeed`, label them "time-lapse" and keep them short.
Whether that counts as a "curated sequence" or an "artificial" alteration is untested with moderation [U]. Upload
only when final: 3 uploads a month, and rejections burn quota.

**Off-platform cut (TikTok, Shorts, Reels):**

* 9:16, 15–30 s, with the same first-3-seconds hook.
* Captions for sound-off viewing.
* May use VO or lyrics, since it is not the Roblox preview.
* **Music must be our own or properly licensed for ads** (§14). No Creator Store tracks.

**Sponsored ads:**

* Launch with the **Plays** goal and 5–10 creatives (the 5 thumbnails plus hook variants). Pause losers after 3–5
  days. If plays convert but D1 retention is weak, fix the FTUE first, as the docs themselves advise.
* Search ads keywords, relevant only: "incremental", "idle", "prestige", "milestone", "skill tree".
* Description hook, under 160 characters: "Claim milestones, prestige through 21 layers and cross into a corrupted second
  universe: a cosmic incremental tree." [U]

**Pre-publish checklist:**

* Icon passes the 150 px test.
* 5 thumbnails active, with nothing important in the bottom band.
* Video reviewed against the allowed and rejected lists.
* Music rights in writing.
* Onboarding funnel verified in "View Events" on the published place (not Studio).

---

## Sources

Roblox docs (creator-docs `main` @ `cc850a8`, read locally and linked live):
[Onboarding](https://create.roblox.com/docs/production/game-design/onboarding) ·
[Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques) ·
[Design for Roblox](https://create.roblox.com/docs/production/game-design/design-for-roblox) ·
[Quest design](https://create.roblox.com/docs/production/game-design/introduction-to-quest-design) ·
[UI/UX design](https://create.roblox.com/docs/production/game-design/ui-ux-design) ·
[Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events) ·
[Event types](https://create.roblox.com/docs/production/analytics/event-types) ·
[Custom events](https://create.roblox.com/docs/production/analytics/custom-events) ·
[Custom fields](https://create.roblox.com/docs/production/analytics/custom-fields) ·
[Analytics overview](https://create.roblox.com/docs/production/analytics) ·
[AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService) ·
[Experiments](https://create.roblox.com/docs/production/experiments) ·
[Configs](https://create.roblox.com/docs/production/configs) ·
[Accessibility](https://create.roblox.com/docs/production/publishing/accessibility) ·
[CanvasGroup](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup) ·
[GuiObject](https://create.roblox.com/docs/reference/engine/classes/GuiObject) ·
[UIStroke](https://create.roblox.com/docs/reference/engine/classes/UIStroke) ·
[9-slice](https://create.roblox.com/docs/ui/9-slice) ·
[Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) ·
[Icons](https://create.roblox.com/docs/production/publishing/experience-icons) ·
[Descriptions](https://create.roblox.com/docs/production/publishing/descriptions) ·
[Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) ·
[Search ads](https://create.roblox.com/docs/production/promotion/search-ads) ·
[Advertise on Roblox](https://create.roblox.com/docs/production/promotion/advertise-on-roblox) ·
[Advertise](https://create.roblox.com/docs/production/promotion/advertise) ·
[Advertising standards](https://create.roblox.com/docs/production/promotion/comply-with-advertising-standards) ·
[Rewarded video](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) ·
[Social links](https://create.roblox.com/docs/production/promotion/social-media-links) ·
[Audio assets](https://create.roblox.com/docs/audio/assets).

DevForum:
[Video Previews (2025-11-13)](https://devforum.roblox.com/t/video-previews-for-your-games-page/4068103) ·
[Gameplay Videos on Home (2026-08-31)](https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601) ·
[YouTube thumbnail removed (Jan 2026)](https://devforum.roblox.com/t/cant-upload-youtube-video-as-thumbnail-anymore/4267781) ·
[Video upload requirements (Apr 2026)](https://devforum.roblox.com/t/video-thumbnail-upload-failing-despite-meeting-requirements/4591866) ·
[SpotlightUI (Jan 2026)](https://devforum.roblox.com/t/spotlightui-guided-focus-module/4267581/1) ·
[Spotlight GUI techniques](https://devforum.roblox.com/t/how-to-achieve-a-spotlight-gui-effect/3397197) ·
[Licensed music off platform (May 2025)](https://devforum.roblox.com/t/questions-regarding-usage-of-licensed-music-off-platform/3639860).

Other:
[Roblox Support: Using Licensed Music in Videos](https://en.help.roblox.com/hc/en-us/articles/360038525351-Using-Licensed-Music-in-Videos) (403; search snippet) ·
[Antimatter Dimensions tutorial.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/tutorial.js) ·
[AD h2p.js](https://github.com/IvarK/AntimatterDimensionsSourceCode/blob/master/src/core/secret-formula/h2p.js) ·
[Cookie Clicker main.js](https://orteil.dashnet.org/cookieclicker/main.js) ·
[The Modding Tree layer features](https://github.com/Acamaeda/The-Modding-Tree/blob/master/docs/layer-features.md) ·
[Melvor Idle v1.0 notes](https://melvoridle.com/update/PatchNotes1.0.html) ·
[IdleOn wiki: Scripticus](https://idleon.wiki/wiki/Scripticus) ·
[BSS wiki: Black Bear](https://bee-swarm-simulator.fandom.com/wiki/Black_Bear) ·
[NN/g mobile onboarding](https://www.nngroup.com/articles/mobile-app-onboarding/) ·
[GAG contextual help](https://gameaccessibilityguidelines.com/include-contextual-in-game-helpguidancetips/) ·
[GAG Silence hints](https://gameaccessibilityguidelines.com/silence-hints/) ·
[XAG 121](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/121) ·
[TikTok creative best practices](https://ads.tiktok.com/help/article/creative-best-practices?lang=en) ·
[Epidemic Sound plans](https://www.epidemicsound.com/our-plans/) ·
[YouTube Audio Library help](https://support.google.com/youtube/answer/3376882) ·
[Engine API change logs](https://robloxapi.github.io/ref/updates/2026.html).

Game sources: `milestone-tree/game-js/layers/*.js`, `game-js/mod.js`, `game-js/game.js` (`layerDataReset` keeps
`best`), `port/rbx/view.js` (`rbx_mapGate`, `rbx_hud`), `docs/design/DESIGN.md` §4.5, §4.6, §7.12,
`src/client/Map/Nodes.luau`, `src/client/Hud/Ready.luau`, `src/client/Core/Prefs.luau`, `src/server/Store.luau`,
`src/worker/Worker.server.luau`.
