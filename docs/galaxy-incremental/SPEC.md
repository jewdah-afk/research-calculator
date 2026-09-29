# GALAXY INCREMENTAL — Master Conversion Spec

> **Status:** Draft v1 (pre-production) · **Scope:** Full presentation conversion of the existing *Ascension Incremental / Stud Incremental* place (`AI_copy.rbxl`) into **Galaxy Incremental**.
> **Source of truth for numbers:** [`reference/Stud_Incremental_Balance.md`](reference/Stud_Incremental_Balance.md). It covers all 444 scripts, every formula, every rune and all 248 upgrade configs.
> **Source of truth for structure:** the place file itself. Section 3 is the extracted map (445 script instances, 48 remotes, 28,547 instances).

---

## 0. How to use this document

This is the one spec every human and agent works from. It is long on purpose. Read it in this order:

| If you are… | Read first | Then |
|---|---|---|
| Starting the project | §1 Prime Directive, §2 Non-negotiables | §21 Roadmap |
| Touching any script | §3 Architecture map, §4 Reskin architecture | §19 Bug policy |
| Writing any player-facing text | §5 Master Lexicon, §6 Collision rules | §22 Consistency lint |
| Building world / art | §11 World, §12 Sky, §15 Art pipeline | §17 Performance |
| Building UI | §14 UI system | §5 Lexicon |
| Building VFX / EditableImage / EditableMesh | §16 Rendering tech | §17 Performance |
| Running agents | §20 Agent structure | §22 QA |

Conventions:
- `code font` = **internal** name (script, stat, datastore key, instance name). These never change unless §4.6 explicitly allows it.
- **Bold** = **display** name (what the player sees).
- "Epoch N" = internal `Stats.Tier == N`.
- Every requirement marked **MUST** is a merge-blocking acceptance criterion.

---

## 1. Prime Directive

> **The balance is already solved.** This project is not asking you to invent another incremental game. It is asking you to turn an existing, fully working incremental framework into a premium cosmic experience **without damaging its mathematical progression.**

| Layer | State |
|---|---|
| Gameplay engine (formulas, costs, resets, runes, upgrades, automation, saves) | **DONE — frozen** |
| World | NOT DONE |
| Visual identity | NOT DONE |
| UX / onboarding / readability | NOT DONE |
| Presentation (VFX, cinematics, audio, UI) | NOT DONE |

The source already contains the cosmic arc. The late-game Galactic rune pack is literally `CosmicDust → Star → Constellation → Planet → Rocket → Galaxy → Axium → Paracosm`. We are not fighting the design to make "Galaxy" work. We are exposing something the balance already points at, and upgrading how it looks.

### 1.1 The player-facing arc (the whole game in one column)

The player should be able to understand the entire game from this sequence, and every screen, world zone and reset cinematic serves it:

```
STARLIGHT            (Energy)            ─┐
SOLAR ENERGY         (Flame)              │  Realm I · The Stellar Frontier
GRAVITY              (Power)              │  Epochs 0 → 10
COSMIC POINTS        (Realm Points)       │
STAR CHARTS          (Tickets)            │
CELESTIAL DISCOVERIES(Runes)              │
BIOMASS / IMPACT     (Flesh / Damage)     │
CELESTIAL ORBS       (Orbs)               │
SPACE CUBES          (Merger / Cubes)     │
PLANETS              (Spheres)           ─┘
      ▼  SUPERNOVA   (Ascension One)
COSMIC DUST          (Droplets)          ─┐
NEBULA GAS           (Water)              │  Realm II · The Galactic Expanse
FROZEN MATTER        (Ice)                │  Epochs 11 → 13
CRYO ENERGY          (Arctic Points)      │
GRAVITATIONAL COLLAPSE I–IX (Freeze1–9)   │
STELLAR SHARDS       (Icicles)           ─┘
      ▼  GALAXY FORMATION (Chromatize)
DARK MATTER          (Chromium)          ─── Sector III · The Void
      ▼  (Chromatize ≥ 1000)
ASTRAL MATTER        (Chroma)            ─── Sector IV · The Primordial Universe
      ▼  REALITY BREAK (Chromify)
RADIANCE             (Light)             ─── Sector V · The Collapsed Realm
REALITY ECHO         (Reflection)        ─── Sector VI · The Paracosm
      ▼
PARACOSM → MULTIVERSE (Galactic Expedition endgame)
```

---

## 2. Non-negotiables (MUST)

1. **No formula, constant, cost, cap, cooldown, chance, requirement or reset list changes** unless a ticket explicitly authorizes it and the Balance Auditor signs off (§20). This includes the known bugs (§19). The live balance depends on them.
2. **No datastore key or stat instance name changes.** `Stats.Energy` stays `Energy`. `Game_Key = "Release_1"` stays. A rename that touches a saved key wipes or corrupts real player saves.
3. **No remote event renames.** 48 remotes are referenced by name through `Framework:GetEvent`, which auto-creates missing events, so a typo fails silently.
4. **All player-facing text goes through the Lexicon** (§4.2). No new hardcoded display strings anywhere.
5. **Zero legacy display names ship.** No "Energy", "Flame", "Tier", "Rune", "Droplets" and so on visible anywhere (§22.3 lint).
6. **Every reset cinematic is skippable** after its first viewing and **never blocks the server-side reset**. Visuals follow state; they never gate it.
7. **Mobile first-class.** Every screen works at 1334×750 (small phone) with 44 px minimum touch targets.
8. **Performance budget** (§17) is enforced by the Performance Engineer on every milestone.
9. **Server authority stays as is.** Presentation code is client-side only and reads replicated `Player.Stats/Upgrades/Runes` values. It never writes them.
10. **Nothing that looks like default Roblox, a generic simulator, an asset-pack dump, AI slop or an empty baseplate ships** (§20, Final Art Director gate).

---

## 3. Existing Architecture Map (extracted from the place file)

### 3.1 Top-level

| Location | Contents | Conversion impact |
|---|---|---|
| `ReplicatedStorage.Framework` (ModuleScript, "Cookie Framework v0.8") | `Services`, `Events` (auto-creating), `GetService/GetClientModule/GetSharedModule/GetLibrary/GetEvent/GetRemoteFunction/SendClientMessage` | Add `GetLexicon()` and `GetTheme()` helpers here (§4.2). |
| `ReplicatedStorage.Framework.Main` (Script) | Bootstrap | Untouched. |
| `ReplicatedStorage.Framework.Shared.Modules` | `Formulas` (2447 lines), `RuneFormulas` (346 fns), `RuneInfo`, `Resets`, `Cooldowns`, `Colors`, `Prefixes` (empty), `Mob_Info`, `RandomElixir`, `StatBoosts`, `SystemMessages`, `ChatData`, `Days`, `Months` | **Frozen:** Formulas, RuneFormulas, RuneInfo, Resets, Cooldowns. **Reskin:** SystemMessages, ChatData, Colors, Mob_Info (display fields only). |
| `ReplicatedStorage.Framework.Libraries` | `Automations`, `Upgrades` (+248 upgrade modules), `Runes` (+9 packs), `GlobalRune`, `AncientRune`, `MadnessRune`, `UltraRune`, `Datastore` (+`Reconcile`), `EternityNum`, `Mob` (+`Mob.1`), `MobsHandler`, `Merger`, `MultiplierButtons` (+Water, Ice), `ProductHandler` (+Conditions, Decode, Functions, Gifting, Messages, RTokenPrices), `Leaderboard` (+Encode/Decode), `Overhead`, `Character`, `ChatCommands`, `DateJoin`, `GlobalGoals` (disabled), `Messenger`, `RichText`, `Thumbnail`, `Time`, `TweenHandler` | Frozen, except display-only fields (§4.4). |
| `ReplicatedStorage.Framework.Client.Modules` (38) | One module per layer/board: `Accelerator, Arctic Points, Ascended, Challenges, Chroma, Chromatize, Chromify, Cubes, DropletsBoard, Flame, Freeze, Gears, Hail, Haze, IceButtons, Icicles, Light, Loot, Mobs, MultiplierButtons(.Ice,.Water), Orbs, PlaytimeRewards, Power, Realm Points, Reflection, RuneStarring, RuneStarring_Setup, Runes, Shine, Spheres, Talent Tree, Tickets, Tier` | **Primary reskin surface.** These hold hardcoded strings like `` `+{…} FLAME` `` and drive the SurfaceGui boards. Each gets Lexicon routing plus a presentation hook (§4.3). |
| `ReplicatedStorage.Framework.Client.Scripts` | `Client Loop`, `UI` (+AscensionOne, FollowRewards, Index, LoadingScreen, Options, Profile, RuneStarring, Runes, Stats, Store(+11), Teleporter, TierBar), `UI Animations`, `VFX Handler`, `SFX Handler`, `Leaderboards`, `Upgrades`, `Gamepass Ads`, `Hide Players`, `Chat`, `Anti Afk`, `Volume Control` | Rebuilt UI binds here (§14). |
| `ReplicatedStorage.Framework.UI` | Templates: `Market Test`, `Popup`, `Random Stat Popup`, `Stat Popup`, `Runes.Holder.{Ancient,Arctic,Basic,Beginner,Color,Cryo,Galactic,Global,Madness,Nature,Polychrome,Royal,Ultra}.Handler` | Rune UIs become Discovery UIs (§9). |
| `ReplicatedStorage.{Runes_Storage, Talents_Storage, Layers_Storage}` | Parked instances. `Layers_Storage` is where client modules re-parent locked layers (`module.Toggle`). | New world models must support the same Toggle re-parent pattern, or a visibility flag. |
| `ReplicatedStorage.Later` | `Glacium` model, `Gradients` (≈100 UIGradients named per rune/stat), `Ignore For Now` | The gradient library becomes the seed for Theme tokens (§14.2). |
| `ReplicatedStorage.Other Mobs` | Polygonal Dragon ×3, Giant Bee, King Cobra, One Eyed Bat, Spiderling Venom, Treant, Wolf | Replaced by Anomalies (§10.7). |
| `ServerScriptService` | `Main`, `CodeServer`, `GameInfo`, `RealmHandling` (Realm Two teleport, `Energy > 1e3003`), `Script` | Frozen, except `RealmHandling` teleport targets (new world CFrames). |
| `ServerStorage.Framework.Modules` | `Freeze` (+Data), `runeStarring` (+data), `CodeData` | Frozen. |
| `ServerStorage.Framework.Scripts` | `Ascensions`, `Remotes`, `Player Connections`, `Products`, `Gifting`, `Settings`, `Soft Shutdown`, `TeleportHandler`, `TeleportPads`, `WaterButtonsServer`, `Follow Rewards`, `Global Elixir`, `Server Elixir`, `ChatTags`, `RequestData`, `Anti AFK` | Frozen, except TeleportPads/Handler destination CFrames. |
| `ServerStorage.TagList` | CollectionService tags: `AscensionOne, ButtonSFX, Hover, Layer_Buttons, Layers, MultiplierButtons, RuneStarring, Runes, TalentUpgrade, Teleporter, UpgradeButtons, Upgrades, buttonClickSize, frameHoverSize` | **New world pads MUST carry the same tags**, or the automation loop won't see them. |
| `StarterGui` | ScreenGuis: `AscensionOne, CurrentEvent, GreyFrame, Index, RunePopup, RuneStarring, Shutdown, Teleporter, TierBar, TierBar2, TierBar3, UpdateLog` + `LocalScript` | All redesigned (§14.5). |
| `StarterPlayerScripts` | `MiscEffects`, `PromptFavorite` | Keep; reskin text. |
| `SoundService` | `Click, Flame, Hover, Power, Purchase, Realm Points, Tier, Upgrade` + `Freeze` module | Replaced by the cosmic sound set (§18). |
| `Lighting` | `Atmosphere, Bloom, Blur, ColorCorrection, DepthOfField, Sky, SunRays` + empty `Script` | Rebuilt per zone (§13). |
| `MaterialService` | `Matte`, `Reflective`, `Reflective2` | Replaced by the Substance material library (§15.3). |

### 3.2 Workspace (the map being replaced)

| Instance | Role today | Galaxy replacement |
|---|---|---|
| `Workspace.Baseplate` (`IncrementalBase2_Base/Outlines/Sectors`) | Central hub floor | **The Observatory** platform (§11.2) |
| `Workspace.Layers.Tier` (`Button`, `Ascender`, `TierBoard`, `XpBar`) | Tier pad and board | **Epoch Engine** at the Observatory core |
| `Workspace.Layers.Flame` (`Flame`, `FlameBoard`, `Multiplier`) | Flame pad | **Stellar Forge** |
| `Workspace.Layers.Power` (`Power`, `PowerBoard`, `PowerUpgrades`, `Multiplier`) | Power pad | **Gravity Well** |
| `Workspace.Layers.Realm Points` (`Realm Points`, `RPBoard`, `RPUpgrades`, `Info`) | RP pad | **Cosmic Research Array** |
| `Workspace.Layers.Flesh` (`FleshBoard`, `FleshUpgrades`, `Health`, `LevelBar`, `NextLevel`, `PreviousLevel`, `Info`) | Mob arena | **Anomaly Containment Ring** |
| `Workspace.Layers.Orbs` (`Incrementor`, `Orbs_*` pads) | Orbs | **Orb Observatory** |
| `Workspace.Layers.Merger` (`Merger`, `Board`, `Orbs_RuneBulk`, `Orbs_SpawnLevel`, `Orbs_SpawnTime`) | Cube merger | **Cube Fusion Bay** |
| `Workspace.Layers.Gears` | Gears | **Orbital Gyroscope** |
| `Workspace.Layers.Accelerator` | Accelerator | **Particle Accelerator ring** |
| `Workspace.Layers.Spheres` (`Ascender`, `Milestones`, `SphereUpgrades`, `Info`) | Spheres | **Planetarium** |
| `Workspace.Layers.TalentTree` (`Talents`, `PrismButton`, `PrismsBoard`, `ToTree`, `Back`) | Talent tree | **The Cosmology** entrance (§12) |
| `Workspace.Layers.Challenges` | Challenge pad | **Trial Gate** |
| `Workspace.Layers.Arctic Points` | AP pad | **Cryo Reactor** (Realm II) |
| `Workspace.Areas.Spawn Island.{Beginner,Royal,Basic,Color,Nature,Polychrome,Galactic}` (each: pack model, `RuneUI`, `RuneUI2`, `Stand`) | Rune stands | **Telescope Bays**, one per Discovery pack (§9.6) |
| `Workspace.Areas.Spawn Island.Tickets` / `Loot` / `Teleporter` / `Upgrade Tree Island` | Misc | Star Chart Terminal / Salvage Beacon / Warp Gate / Cosmology Isle |
| `Workspace.Areas.Spawn Island.Map.*` (Trees, Grass, Bush, Mushrooms, Logs, Mud, Rocks, Hill, Leaves, Trunks, Wind, Pillars, Chains, Collars, Path, Bases, Ads, Tips, Info, gamepass ads `x2RuneLuck`, `x2RuneSpeed`, `x3Damage`, `x3Energy`, `Walkspeed`, `Fast`, `Ascension1`, `HallOfFame`) | Nature dressing | **Deleted**, replaced by the Frontier dressing (§11.3). Gamepass ad parts become holo-billboards. |
| `Workspace.Areas.Arctic.*` (Freeze, Ice, IceButtons, WaterButtons, Icicles, Cryo, Chromatizer, Chromifier, Chroma, Light, Reflection, Shine, Hail, Haze, Ascended, Caps, TalentTree2, Upgrade Tree Island 2, DropletBoard, StatsBoard, PlaytimeRwards, Teleporter, Tickets, snow dressing) | Realm Two | **Galactic Expanse** + Sectors III–VI (§11.4) |
| `Workspace.Islands.FloatingIsland` ×8 | Background islands | Asteroid / planetoid set pieces |
| `Workspace.HallOfFame` (Pillars, Statue, `CurrentPrisms`, `TotalEnergy`, `Playtime`, `RobuxSpent`, `RunesOpened`, `Contributors`, Waterfall) | Leaderboards | **Hall of Observers** |
| `Workspace.Starring` (`SellPad_*`, `Beam*`, `Trigger`, `Info`) | Rune Starring pad | **Star Mapping Altar** |
| `Workspace.Rewards`, `ChestOpen` | Rewards / chest VFX origin | **Artifact Dais** |
| `Workspace.Mobs`, `Overheads`, `Temp`, `Texture` (126 Texture Parts), `InvisibleWalls` | Runtime folders / dressing | Keep runtime folders. Rebuild the walls as a visible **containment field**. Delete `Texture`. |
| `Workspace.Donkey (Shrek)`, `Workspace.Rig`, `Workspace.Polygonal Treant` | Stray test / meme assets | **Delete** (confirm with owner). |

### 3.3 Remote events (48, frozen)

`AFK, AscensionOne, Broadcast, Buy_Accelerator, Buy_Gears, Buy_Upgrade, ClearLBs, Client, Enter_Challenge, Equip_Event, Follow_Request, Freeze_Tiers, Get_TierData, GlobalGoalsLB, GlobalMessage, Layer_Reward, Layer_VFX, LeaderboardUpdate, Mob_Hit, Mob_Refresh, Mob_Respawn, Mob_Update, Mob_UpdateHP, Play_SFX, Popup, Purchase_Gamepass, Purchase_Product, RTokenToggle, Redeem_Code, Request_Data, Request_Gifting, RobuxToggle, Run_Client, Rune_Reward, Send_Gift, Send_Global, Shutdown, Stat_Popup, Teleport_Realm, Toggle_Setting, Toggle_Tag, Update_Cubes, Upgrade_Spheres, Use_Elixir, Use_Global, Use_Potion, Verify, Water_Buttons, realm_Two` (+ `RemoteEvents.rune_Starring`).

**Presentation hooks to subscribe to (client side only):** `Layer_VFX`, `Layer_Reward`, `Rune_Reward`, `Stat_Popup`, `Popup`, `AscensionOne`, `realm_Two`, `Mob_*`, `Update_Cubes`, `Play_SFX`, `Freeze_Tiers`. If a cinematic needs a signal that doesn't exist, **derive it client-side from a replicated value change** (for example, `Stats.Chromatize.Changed`). Do not add server remotes without Architect sign-off.

### 3.4 Save schema (Reconcile) — stats that exist

Currencies and progress (all in `Player.Stats`): `Energy, Flame, Power, Realm Points, Tickets, Flesh, Orbs, Spheres, Sphere_Levels, Prisms, Droplets, Water, Ice, ArcticPoints, Icicles, Chromium, Chroma, Light, Reflection, Haze, Hail, Loot, Shine, Gears, Accelerator, Cube_Level, Highest_Cube, XP, Level, Tier, Highest_Tier, Chromatize, Chromify, AscensionOne, Realm, R1_Purchased, R2_Purchased, C1–C4, InChallenge, CurrentChallenge, Mobs_Level, Mobs_SetLevel, Mobs_Killed, Mobs_TotalKilled, RobuxTokens, Total_Tickets, Total_Energy, Runes_Opened, RawRunes_Opened, <Pack>_Opened ×9, <Pack>_Rune_Luck/Bulk, Global_Rune_Luck/Bulk, *StartTime/*TotalTime (Haze, Hail, Loot, Chroma, Shine, Ascended, Light), Playtime, TierTwelveTime, LikeReward, Tutorial_Finished, Location`, plus flags (`Verified, RLBoost, RBBoost, RSBoost, RSBoost2, BulkFix, Blitz, BanTracker, RobuxSpent, RobuxDonated`).
Folders: `Stats, Settings, Upgrades, Runes, Gamepasses, ChatSettings`.

**Rule:** the new game adds presentation state (for example `Settings.SkipCinematics` or `Settings.ReducedMotion`) **only** through the existing `Settings` reconcile pattern, and only with Architect sign-off. The **Reality Echo history** (§10.6) needs one additive key. See §4.6.

---

## 4. Reskin Architecture

### 4.1 Principle: two names per thing

Every concept has an **internal ID** (unchanged forever) and a **display record** (owned by the Lexicon). Code never builds display text from internal IDs. Today's code does exactly that (`` `x{…} FLAME` ``, `` `+{…} ENERGY` ``), so every such site gets rewritten.

### 4.2 `Lexicon` module (new, MUST)

Location: `ReplicatedStorage.Framework.Shared.Modules.Lexicon`. Accessed through `Framework:GetSharedModule("Lexicon")`.

```lua
-- Shape (illustrative)
Lexicon.Stats["Energy"] = {
    Display  = "Starlight",       -- Title case
    Upper    = "STARLIGHT",       -- boards and headers
    Short    = "SL",              -- tight UI and tooltips
    Icon     = "rbxassetid://…",  -- static fallback icon
    Token    = "starlight",       -- theme token key (§14.2)
    Blurb    = "Light gathered from your first star. Everything begins here.",
}
Lexicon.Layers["Tier"]      = { Display = "Epoch", Action = "Advance Epoch", … }
Lexicon.Packs["Beginner"]   = { Display = "Stellar Survey", Verb = "Scan", … }
Lexicon.Runes["Noob"]       = { Display = "Meteor", Preset = "Meteor", … }
Lexicon.Upgrades["RP_Energy"] = { Display = "Stellar Density", Desc = "Boosts Starlight gain." }
Lexicon.Challenges["C1"]    = { Display = "Trial of Light", … }
Lexicon.Epochs[0..13]       = { Display = "Particle", … }        -- §7
Lexicon.Collapse[1..9]      = { Display = "Collapse I", Object = "Dense Star" } -- §10.3

function Lexicon.fmt(statId, amount, opts) -> "+1.25e12 STARLIGHT"
function Lexicon.mult(statId, amount)       -> "×1.25e12 STARLIGHT"
```

- **Single source.** Section 5 of this doc *is* the Lexicon contents. When they disagree, the doc wins and the module is fixed.
- **Localization-ready.** Store keys so `LocalizationService` tables can come later. English only for launch.
- **Upgrade descriptions** are generated from the upgrade's currency and target stat names plus a curated title (§5.9). No upgrade is left with a raw name like `Prisms_Flame2`.

### 4.3 Presentation hooks

Each `Client.Modules.<Layer>` keeps its `Toggle(HasReq)` and `Update(Currency)` contract. Add:

```lua
module.Present = PresentationBus:Register("<Layer>")  -- e.g. "Flame"
-- inside Update(): PresentationBus:Emit("Flame", { amount = Currency, perTick = gain })
-- inside Toggle(true) first-time: PresentationBus:Emit("Flame.Unlocked")
```

`PresentationBus` (new, client) routes events to **World Presenters** (3D object states), **UI Presenters** (HUD), the **Audio Director** and the **Cinematic Director**. Presenters are pure: `state → visuals`. They must tolerate receiving any state at any time: join mid-progress, rejoin, or teleport.

### 4.4 Where display strings live today (must all migrate)

- `Client.Modules.*`: board text (`Board.SurfaceGui.Main.*`, `BillboardGui` labels).
- **TextLabels baked into instances.** About 4,300 TextLabel/Button `Text` values in the place. Currency words appear in hundreds of them (for example "Tickets" ≈250, "Prisms" ≈350, "Chromium" ≈400, "Spheres" ≈230). These are **replaced by rebuilt UI and boards**, not patched one by one.
- `Shared.Modules.SystemMessages`, `ChatData`, `ProductHandler.Messages`, `Credits`, `UpdateLog`, `Index`, `Store.*` data tables, `Mob_Info`, and upgrade modules' `Name`/`Description` fields if present.
- Chat commands and system chat colors (`Colors.System`, `Title`, `Version`).
- Leaderstats. The `leaderstats` child names show in the player list. Their names are display-only, so they get renamed to **Epoch / Supernova / …**. Verify `Leaderboard` and `Leaderstats sync` don't read them by name before changing.
- Gamepass and product names/descriptions on the Roblox website (owner action, not code).

### 4.5 Theme module (new)

`Shared.Modules.Theme` holds color tokens, gradient definitions and font choices (§14.2). It replaces `Later.Gradients` usage and the random-color fallback in `Colors.__index`. **An unknown key must error in Studio and log once in live play. It must not render a random color.**

### 4.6 Allowed data additions (additive only)

| Key | Where | Purpose | Default |
|---|---|---|---|
| `Settings.SkipCinematics` | Settings | skip seen cinematics | false |
| `Settings.ReducedMotion` | Settings | accessibility | false |
| `Settings.GraphicsTier` | Settings | Low/Med/High presenter budget | "Auto" |
| `Stats.SeenCinematics` | Stats (string bitset) | first-view tracking | "" |
| `Stats.EchoHistory` | Stats (string, JSON, capped at 16 entries) | Reality Echo sky ghosts (§10.6) | "[]" |

**No other schema changes.** Each addition goes through `Reconcile` with a default, so old saves load cleanly.

---

## 5. Master Lexicon

### 5.1 Currencies and stats

| Internal stat | Display | Short | Proposal ref | Visual identity (one line) | Token |
|---|---|---|---|---|---|
| `Energy` | **Starlight** | SL | Primary currency | warm white-gold motes flowing into the Starlight Core | `starlight` |
| `Flame` | **Solar Energy** | SOL | Stellar Forge | orange plasma, corona flicker | `solar` |
| `Power` | **Gravity** | GRV | Gravity Well | black sphere, violet lensing rim | `gravity` |
| `Realm Points` | **Cosmic Points** | CP | Research Array | cyan holographic glyph points | `cosmic` |
| `Tickets` | **Star Charts** | SC | Discovery currency | folded holographic map with star pins | `charts` |
| `Flesh` | **Biomass** | BIO | Anomaly drop | bioluminescent teal organics | `biomass` |
| `Damage` (derived) | **Impact** | IMP | Combat stat | white shock ring | `impact` |
| `Orbs` | **Celestial Orbs** | ORB | Orb Observatory | glassy orbs with inner starfield | `orbs` |
| `Cube_Level` / Merger | **Space Cubes** (level: **Cube Tier**) | CUBE | Cube Fusion Bay | metallic cubes with glowing seams | `cubes` |
| `Spheres` | **Planets** | PLN | Planetarium | procedural planet per milestone | `planets` |
| `Sphere_Levels` | **Planet Grade** | — | — | extra rings or moons per grade | `planets` |
| `Prisms` | **Prisms** | PRZ | kept | faceted crystal, spectral split | `prisms` |
| `Droplets` | **Cosmic Dust** | DUST | post-Supernova primary | orbiting glitter swarm around player | `dust` |
| `Water` | **Nebula Gas** | GAS | Nebula Engine | swirling magenta-teal gas | `nebula` |
| `Ice` | **Frozen Matter** | FRZ | Absolute Zero Chamber | pale-blue crystal lattice | `frozen` |
| `ArcticPoints` | **Cryo Energy** | CRYO | Cryo Reactor | cold white-blue charge arcs | `cryo` |
| `Icicles` | **Stellar Shards** | SHD | star-crack reset | fractured star fragments | `shards` |
| `Chromium` | **Dark Matter** | DM | Galaxy Formation currency | black-purple lensing substance | `darkmatter` |
| `Chroma` | **Astral Matter** | AM | endgame | black crystal with moving galaxies inside | `astral` |
| `Light` | **Radiance** | RAD | Reality Break | pure white ribbons, geometric light | `radiance` |
| `Reflection` | **Reality Echo** | ECHO | Echo reset | ghosted translucent duplicates | `echo` |
| `Haze` | **Solar Wind** | WIND | secret stat (24 h claim, Epoch 13) | streaming particle lanes | `wind` |
| `Hail` | **Meteor Shower** | MTR | secret stat (24 h claim, Epoch 10) | streak rain across the sky | `meteor` |
| `Loot` | **Salvage** | SLV | secret stat (10 min claim, Epoch 4) | drifting wreck beacon | `salvage` |
| `Shine` | **Luminance** | LUM | secret stat (30 s claim) | soft glint pulses | `luminance` |
| `Gears` | **Orbital Gyros** | GYRO | speeds cooldowns | nested spinning gimbals | `gyro` |
| `Accelerator` | **Particle Accelerator** (levels: **Accelerator Stages**) | ACC | Prism/Cube speed | collider ring with racing particle | `accel` |
| `XP` | **Astronomy XP** | XP | — | thin blue progress beam | `xp` |
| `Level` | **Observer Level** | LV | — | badge with orbit pips | `xp` |
| `RobuxTokens` | **Astral Tokens** | AT | premium-style token | gold-violet coin with a star cut-out | `tokens` |
| `Runes_Opened` | **Objects Discovered** | — | stat | — | — |
| `Total_Energy` | **Lifetime Starlight** | — | Hall of Observers | — | — |
| `Mobs_Level` | **Anomaly Threat Level** | THR | — | — | `biomass` |
| `Playtime` | **Observation Time** | — | — | — | — |

### 5.2 Layers, resets and progression verbs

| Internal | Display | Verb on button | Notes |
|---|---|---|---|
| `Tier` (0–13) | **Epoch** | "ADVANCE EPOCH" | Per-Epoch names in §7. `Highest_Tier` → **Furthest Epoch**. |
| Flame pad | **Stellar Forge** | "IGNITE" | deducts Starlight (`Flame_Cost = 50`) |
| Power pad | **Gravity Well** | "COMPRESS" | resets Solar Energy and Starlight |
| Realm Points pad | **Research Array** | "RESEARCH" | |
| `AscensionOne` | **Supernova** | "GO SUPERNOVA" | one-time, `Energy > 1e2283` |
| `Freeze1–9` | **Gravitational Collapse I–IX** | "COLLAPSE" | §10.3 |
| `Chromatize` | **Galaxy Formation** (level = **Galaxy Rank**) | "FORM GALAXY" | Prisms gate, 1 s CD, cap 1000 in practice |
| `Prisms_Chromatizer` | **Galaxy Forge** (unlock) | | |
| `Chromify` | **Reality Break** (level = **Breach**) | "BREAK REALITY" | Astral Matter gate, 3 levels |
| `Chromium_Chromifier` | **Reality Engine** (unlock) | | |
| `Reflection` (pad) | **Reality Echo** | "ECHO" | §10.6 |
| `Icicles` pad | **Shatter Star** | "SHATTER" | Epoch 13, Frozen Matter > 1e17 |
| `C1–C4` | **Cosmic Trials** | "ENTER TRIAL" | §10.5 |
| `Realm` One/Two | **Realm I · Stellar Frontier / Realm II · Galactic Expanse** | "WARP" | |
| `R2_Purchased` | **Expanse Warp License** | | redundant purchase (balance note), leave as is |
| Merger | **Cube Fusion** | | |
| Rune Starring | **Star Mapping** (stages **Charted I, II, III → Supercharted → Complete**) | "MAP" | §9.8 |
| Water buttons | **Nebula Condensers** | "CONDENSE" | |
| Ice buttons | **Cryo Condensers** | "FREEZE" | resets Cosmic Dust and Nebula Gas, so the UI must warn |
| Timed claim pads | **Beacons** (Solar Wind Beacon, Meteor Shower Beacon, Salvage Beacon, Luminance Beacon, Radiance Beacon, Astral Beacon, Convergence Beacon for `Ascended`) | "CLAIM" | |
| Talent tree | **The Cosmology** | "STUDY" | §12 |
| Talent tree 2 (Arctic) | **The Cosmology · Outer Ring** | | |
| Elixirs (Stats, RuneLuck, RuneSpeed, Server, Global) | **Catalysts** (Stellar Catalyst, Fortune Catalyst, Scan-Speed Catalyst, Server Catalyst, Galactic Catalyst) | "ACTIVATE" | |
| Rune Luck | **Discovery Luck** | | |
| Rune Bulk | **Scan Bulk** | | |
| Rune Speed | **Scan Speed** (shown as **Scans/sec**) | | |
| Rune Clone | **Echo Scan** (double discovery) | | |
| Chest | **Cosmic Artifact** | | |
| Mobs | **Anomalies** | | |
| Walkspeed | **Thruster Speed** | | |
| Hall of Fame | **Hall of Observers** | | |
| Teleporter | **Warp Gate** | | |
| Codes | **Transmission Codes** | | |
| Likes reward | **Community Signal** | | |
| Favorites luck | **Stargazer Bonus** | | |
| Donation | **Patronage** | | |
| Follow rewards (`Ayla_Follow`, etc.) | **Crew Bonus** | | keep creator names |

### 5.3 Discovery (rune) system nouns

| Internal | Display |
|---|---|
| Rune | **Discovery** (plural **Discoveries**; a specific instance is a "celestial object") |
| Rune pack | **Survey** (the stand is a **Telescope Bay**) |
| Open / Roll | **Scan** |
| Rune Index (`Index` UI) | **Star Catalog** |
| Pity | **Signal Lock** ("Signal lock at 73%") |
| `RuneLuck=false` chase items | **Deep-Field Objects** (unaffected by luck; UI must say so) |

### 5.4 Discovery packs (summary)

| Internal pack | Display survey | Currency | Cost/scan | Unlock | World location |
|---|---|---|---|---|---|
| `Beginner` | **Stellar Survey** | Star Charts | 1 | Epoch ≥ 1 | Frontier, bay 1 |
| `Royal` | **Zodiac** | Star Charts | 50 | Epoch ≥ 1 | Frontier, bay 2 |
| `Basic` | **Stellar Classes** | Solar Energy | 1e3 | Epoch ≥ 3 | Frontier, bay 3 |
| `Color` | **Stellar Hues** | Cosmic Points | 2.5e4 | Epoch ≥ 6 | Frontier, bay 4 |
| `Nature` | **Nebula** | Planets | 5e27 | Epoch ≥ 9 | Frontier, bay 5 |
| `Polychrome` | **Spectral** | Prisms | 1e15 | Supernova | Frontier, bay 6 (sealed until Supernova) |
| `Cryo` | **Deep Space** | Cryo Energy | 50 | Supernova + Collapse III | Expanse |
| `Arctic` | **Cosmic Web** | Dark Matter | 1e6 | Supernova + Galaxy Rank ≥ 7 | Expanse / Void edge |
| `Galactic` | **Galactic Expedition** | **Star Charts** | 500 | Supernova + Galaxy Rank ≥ 750 | Frontier summit (visible from turn one as a locked monument) |

> ⚠ **Correction to the proposal:** the Galactic pack is paid with **Star Charts** (`Tickets`, 500/scan), not Cosmic Dust. The proposal's Nebula pack currency "Celestial Orbs / Planets" resolves to **Planets** (`Spheres`) only.

### 5.5 Full Discovery rename table (every rune, all 134)

Rarity bands are **display-only** and derived from the listed "1 in X" (Common < 10 · Uncommon < 1e3 · Rare < 1e6 · Epic < 1e10 · Legendary < 1e20 · Mythic < 1e100 · Celestial < 1e200 · Cosmic < 1e300 · Transcendent ≥ 1e300). For the four special pools, "1 in X" is the *effective* chance, because their thresholds are non-cumulative (a known bug, left as is).

#### STELLAR SURVEY  ·  internal pack `Beginner`

Cost: **1 Star Charts** per scan · Unlock: Epoch ≥ 1

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Noob` | **Meteor** | 1.05 | Common | small tumbling rock with ember trail |
| `Intermediate` | **Asteroid** | 20 | Uncommon | cratered rock, slow spin |
| `Experienced` | **Comet** | 2e3 | Rare | icy nucleus + long ion tail |
| `Master` | **Moon** | 5e5 | Rare | cratered grey sphere with terminator shadow |
| `Champion` | **Red Giant** | 1e7 | Epic | swollen red star, soft corona |
| `Legend` | **Blue Giant** | 7.5e8 | Epic | hot blue star, sharp flare spikes |
| `Elite` | **White Dwarf** | 5e10 | Legendary | tiny intense white core, halo ring |
| `Superstar` | **Hypergiant** | 2.5e10 | Legendary | enormous unstable star shedding shells |
| `Overlord` | **Quasar** | 5e58 | Mythic | bright core with twin relativistic jets |
| `Sorcerer` | **Ancient Star** | 1e234 | Cosmic | dim ember star wrapped in runic orbit rings |
| `Vanguard` | **Primordial Star** | 4e267 | Cosmic | Population-III star, pure white-violet, no metals |
| `Hyperion` | **Hyperion** | 5e306 | Transcendent | impossible star: nested counter-rotating shells |

#### ZODIAC  ·  internal pack `Royal`

Cost: **50 Star Charts** per scan · Unlock: Epoch ≥ 1

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Gilded` | **Aries** | 1.01 | Common | ram constellation, gold line-art |
| `Royalty` | **Taurus** | 2.5e5 | Rare | bull constellation + Pleiades cluster |
| `Crown` | **Gemini** | 7.5e7 | Epic | twin stars orbiting each other |
| `Throne` | **Cancer** | 1e10 | Legendary | crab constellation + Beehive cluster |
| `Monarch` | **Leo** | 2e12 | Legendary | lion constellation, Regulus flare |
| `Imperial` | **Virgo** | 1e14 | Legendary | maiden constellation, Spica blue-white |
| `Sovereign` | **Libra** | 2.5e15 | Legendary | balance constellation, twin scales orbit |
| `Kingslayer` | **Scorpio** | 2.5e11 | Legendary | scorpion constellation, Antares red heart |
| `Divinity` | **Sagittarius** | 7.5e16 | Legendary | archer constellation aimed at galactic core |
| `Prosperity` | **Capricorn** | 2.5e22 | Mythic | sea-goat constellation, gold particle wake |
| `Immortality` | **Aquarius** | 2e82 | Mythic | water-bearer pouring star-fluid |
| `Odyssey` | **Pisces** | 1.5e109 | Celestial | two fish circling a cosmic cord |
| `Destiny` | **Ophiuchus** | 5e121 | Celestial | the hidden 13th sign, serpent of light |
| `Triarch` | **Orion's Belt** | 1.5e165 | Celestial | three perfectly aligned supergiants |
| `Liberty` | **Polaris** | 3.5e256 | Cosmic | the unmoving star; everything else rotates around it |

#### STELLAR CLASSES  ·  internal pack `Basic`

Cost: **1e3 Solar Energy** per scan · Unlock: Epoch ≥ 3

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Basic` | **Class M** | 2 | Common | small red dwarf |
| `Unique` | **Class K** | 3.33 | Common | orange dwarf |
| `Rare` | **Class G** | 5.56 | Common | yellow sun-like star |
| `Ascendant` | **Class F** | 50.5 | Uncommon | yellow-white star |
| `Exotic` | **Class A** | 2e3 | Rare | white star with bright halo |
| `Unknown` | **Class B** | 2.5e6 | Epic | blue-white giant |
| `Mystery` | **Class O** | 1e12 | Legendary | violet-blue hot giant |
| `HyperFinality` | **Wolf-Rayet** | 7.5e32 | Mythic | star blowing off expanding shells |
| `Shyft` | **Cepheid** | 7.5e55 | Mythic | pulsating variable, rhythmic brightness |
| `Array` | **Open Cluster** | 1e135 | Celestial | loose cluster of young blue stars |
| `Disarray` | **Globular Cluster** | 7.5e174 | Celestial | dense ancient sphere of stars |
| `Apex` | **Luminous Blue Variable** | 2.5e212 | Cosmic | eruptive star inside twin lobes |
| `Strix` | **Carbon Star** | 2.5e256 | Cosmic | deep crimson star in soot shell |
| `Nexus` | **Kilonova** | 1e303 | Transcendent | two neutron stars merging, gold-forge flash |

#### STELLAR HUES  ·  internal pack `Color`

Cost: **2.5e4 Cosmic Points** per scan · Unlock: Epoch ≥ 6

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Tinted` | **Redshift** | 1.82 | Common | receding star, red-stretched light |
| `Colorful` | **Amber** | 4 | Common | warm amber star |
| `Radiance` | **Gold** | 5.88 | Common | golden star (NOT 'Radiance': that is a currency) |
| `Neon` | **Neon** | 40 | Uncommon | hard-edged neon green planet |
| `Chrome` | **Cyan** | 200 | Uncommon | reflective cyan planet |
| `Rainbow` | **Rainbow** | 3e4 | Rare | planet with rainbow ring system |
| `Vibrance` | **Vibrance** | 5e7 | Epic | nebula pulsing through the spectrum |
| `Bloom` | **Bloom** | 7.5e9 | Epic | nebula blooming like a flower |
| `Gleam` | **Aurora** | 1e47 | Mythic | curtain nebula with aurora ribbons |
| `Vanta` | **Vanta** | 7e95 | Mythic | light-eating sphere, only rim visible |
| `Whirl` | **Blueshift** | 1e204 | Cosmic | approaching star, blue-compressed light |
| `Onyx` | **Onyx** | 1.25e248 | Cosmic | black crystal nebula with starlight veins |

#### NEBULA  ·  internal pack `Nature`

Cost: **5e27 Planets** per scan · Unlock: Epoch ≥ 9

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Oak` | **Dust Cloud** | 1.67 | Common | soft brown molecular cloud |
| `Moss` | **Emission Nebula** | 5 | Common | glowing red-pink gas |
| `Dew` | **Stellar Nursery** | 6.67 | Common | gas pillars with newborn stars |
| `Skylight` | **Protostar** | 21.1 | Uncommon | collapsing cloud, bright core, jets |
| `Nightshade` | **Dark Nebula** | 400 | Uncommon | opaque silhouette cloud |
| `Wavecaller` | **Ion Storm** | 1e4 | Rare | crackling blue plasma cloud |
| `Thunderstorm` | **Solar Flare** | 2.5e5 | Rare | arcing flare loop |
| `Earthvein` | **Planetary Nebula** | 3e6 | Epic | ring nebula around a dying star |
| `Emberglow` | **Pulsar** | 2.5e8 | Epic | spinning neutron star, lighthouse beams |
| `Dreamscape` | **Magnetar** | 1.25e9 | Epic | neutron star with visible field lines |
| `Thorn` | **Wormhole** | 1e13 | Legendary | lensing tunnel mouth |
| `Squid` | **Crab Nebula** | 1e130 | Celestial | filamentary supernova remnant |
| `Cyclone` | **Hypernova** | 2.5e140 | Celestial | collapsar explosion shell (NOT 'Supernova': that is the reset) |
| `Bolt` | **Gamma-Ray Burst** | 1.75e182 | Celestial | twin beams piercing the scene |
| `Riptide` | **Accretion Disk** | 2e205 | Cosmic | superheated disk around an unseen mass |
| `Torrent` | **Quantum Storm** | 2.5e228 | Cosmic | flickering probabilistic cloud |
| `Hurricane` | **Cosmic Tempest** | 1e304 | Transcendent | galaxy-scale storm vortex |

#### SPECTRAL  ·  internal pack `Polychrome`

Cost: **1e15 Prisms** per scan · Unlock: Supernova

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Glow` | **Glow Shard** | 1 | Common | softly lit crystal shard |
| `Shimmer` | **Shimmer** | 5e4 | Rare | iridescent floating shard cluster |
| `Iridium` | **Iridium** | 5e6 | Epic | metallic artifact with spectral sheen |
| `Spectrum` | **Spectrum** | 7.5e8 | Epic | prism splitting a beam into bands |
| `Prismatic` | **Prismatic Star** | 5e9 | Epic | star with faceted crystal surface |
| `Refraction` | **Refraction** | 1e12 | Legendary | bending light-lens artifact |
| `Aether` | **Aether** | 1.5e10 | Legendary | translucent flowing artifact |
| `Vexed` | **Vex Crystal** | 5e10 | Legendary | jagged unstable crystal |
| `Abyssium` | **Abyssium** | 1.25e20 | Mythic | deep-violet abyss crystal |
| `Oscillon` | **Oscillon** | 3.33e27 | Mythic | standing-wave energy knot |
| `Oblivion` | **Oblivion** | 5e73 | Mythic | artifact that erases the space around it |
| `Zephyr` | **Zephyr** | 5e191 | Celestial | wind of light spiraling a core |
| `Raze` | **Raze** | 7.5e286 | Cosmic | shattering artifact, fragments orbit |

#### DEEP SPACE  ·  internal pack `Cryo`

Cost: **50 Cryo Energy** per scan · Unlock: Supernova + Collapse III

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Mist` | **Frost Star** | 1.01 | Common | pale blue cold star |
| `Breeze` | **Cryo Moon** | 5e5 | Rare | ice-crusted moon with geysers |
| `Shiver` | **Frozen Planet** | 7.5e7 | Epic | white planet with crack patterns |
| `Frigid` | **Ice Giant** | 2.5e11 | Legendary | banded teal gas giant |
| `Icequake` | **Frozen Nebula** | 7.5e12 | Legendary | crystallised nebula |
| `Garmin` | **Dead Star** | 1e42 | Mythic | black dwarf, faint rim |
| `Stray` | **Void Star** | 1e160 | Celestial | star seen only by lensing |
| `Buff` | **Absolute Zero** | 2e222 | Cosmic | perfectly still frost sphere |
| `Bozo` | **Dark Horizon** | 1e295 | Cosmic | horizon line cutting space |
| `Mommy` | **Event Horizon** | 7.5e304 | Transcendent | black disk with photon ring |
| `Soup` | **Heat Death** | 2.5e307 | Transcendent | greyed-out universe fragment |

#### COSMIC WEB  ·  internal pack `Arctic`

Cost: **1e6 Dark Matter** per scan · Unlock: Supernova + Galaxy Formation ≥ 7

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `Snowflake` | **Web Strand** | 1.01 | Common | thin dark filament |
| `Snow` | **Filament** | 100 | Uncommon | glowing filament with galaxy beads |
| `Icy` | **Dark Halo** | 2.5e5 | Rare | invisible halo shown by orbiting stars |
| `Avalanche` | **Cosmic Wall** | 1.5e8 | Epic | sheet of galaxies |
| `Hailstorm` | **Void Bubble** | 2.5e10 | Legendary | empty sphere outlined by galaxies |
| `Frostveil` | **Great Attractor** | 5e12 | Legendary | point everything drifts toward |
| `Subzero` | **Dark Flow** | 2.5e14 | Legendary | streaming matter current |
| `Blizzard` | **Axion Cloud** | 1e11 | Legendary | faint shimmering dark cloud |
| `Mirror` | **Mirror Matter** | 7.5e60 | Mythic | inverted twin object |
| `Frostbite` | **WIMP Lattice** | 3e103 | Celestial | crystal grid of dark particles |
| `Glint` | **Dark Star** | 3.33e296 | Cosmic | dark-matter powered star |

#### GALACTIC EXPEDITION  ·  internal pack `Galactic`

Cost: **500 Star Charts** per scan · Unlock: Supernova + Galaxy Formation ≥ 750

| Internal rune | Display name | 1 in X | Rarity band | Object form (CosmicObjectRenderer preset) |
|---|---|---|---|---|
| `CosmicDust` | **Stardust** | 1e207 | Cosmic | (NOT 'Cosmic Dust': that is a currency) |
| `Star` | **Starborn** | 2.5e208 | Cosmic | first star of a new galaxy |
| `Constellation` | **Constellation** | 2.5e223 | Cosmic | full living constellation |
| `Planet` | **Homeworld** | 3.33e238 | Cosmic | inhabited world with city lights (NOT 'Planet': currency) |
| `Rocket` | **Starship** | 1.5e260 | Cosmic | starship leaving homeworld |
| `Galaxy` | **Spiral Galaxy** | 1.5e304 | Transcendent | full spiral galaxy |
| `Axium` | **Galaxy Cluster** | 1e306 | Transcendent | cluster of galaxies bound together |
| `Paracosm` | **Paracosm** | 4e307 | Transcendent | multiple universes intersecting |

#### COSMIC RAYS  ·  internal pool `GlobalRune`

| Internal rune | Display name | Effective 1 in X | Rarity band |
|---|---|---|---|
| `Lightmatter` | **Luminous Matter** | 1.11 | Common |
| `Darkmatter` | **Umbral Matter** | 21.7 | Uncommon |
| `Antimatter` | **Antimatter** | 526 | Uncommon |
| `Etherborn` | **Zero-Point** | 1e4 | Rare |

#### ANCIENT RELICS  ·  internal pool `AncientRune`

| Internal rune | Display name | Effective 1 in X | Rarity band |
|---|---|---|---|
| `Dust` | **Fossil Light** | 1.47 | Common |
| `Bone` | **Meteorite** | 7.58 | Common |
| `Glyph` | **Star Glyph** | 61.5 | Uncommon |
| `Sigil` | **Star Sigil** | 667 | Uncommon |
| `Ankh` | **Ankh of Eternity** | 4.55e3 | Rare |
| `Omen` | **Omen Comet** | 3.33e4 | Rare |

#### CHAOS FIELD  ·  internal pool `MadnessRune`

| Internal rune | Display name | Effective 1 in X | Rarity band |
|---|---|---|---|
| `Mad` | **Unstable Particle** | 1.01 | Common |
| `Rage` | **Chaos Flare** | 205 | Uncommon |
| `Violence` | **Rift** | 1.07e4 | Rare |
| `Vehemence` | **Spacetime Tear** | 3.33e4 | Rare |
| `Malevolence` | **Void Maw** | 1e5 | Rare |

#### FUNDAMENTAL FORCES  ·  internal pool `UltraRune`

| Internal rune | Display name | Effective 1 in X | Rarity band |
|---|---|---|---|
| `Omniscient` | **Electromagnetism** | 1.23 | Common |
| `Omnipotent` | **Weak Force** | 12.3 | Uncommon |
| `Almighty` | **Strong Force** | 128 | Uncommon |
| `Boundless` | **Inflaton** | 1.25e3 | Rare |
| `Primordial` | **Big Bang Seed** | 7e3 | Rare |
| `Eternal` | **Eternity** | 1.75e4 | Rare |

### 5.6 Special-pool presentation

The four special pools (`GlobalRune`, `AncientRune`, `MadnessRune`, `UltraRune`) have no currency or cost in their modules. They are triggered elsewhere (products, codes, `Chromium_UltraRunes`). They present as **event discoveries**: a full-screen **Cosmic Ray Strike / Relic Recovery / Chaos Surge / Force Manifestation** cutaway, not the telescope scan (§9.5).

### 5.7 Upgrade naming grammar

Rule: `<Board noun>: <Target display> <Roman numeral>`. The board noun comes from the paying board (Research, Gravity, Bio, Planetary, Orb, Chart, Dust, Cryo, Radiant, Echo, Permanent, Cosmology · <source>). The target display comes from §5.1. The numeral is the trailing digit of the internal name. Freeze upgrades are **Gravitational Collapse I–IX**. Three upgrades get hero names: **GALAXY FORGE** (`Prisms_Chromatizer`), **REALITY ENGINE** (`Chromium_Chromifier`) and **Cosmology · Prisms: Impact Exponent** (`Prisms_DMG`, which raises the Gravity→Impact exponent 0.075→0.175 and would otherwise collide with `Prisms_Damage`).

Each upgrade also gets a one-line **flavor title** in the Lexicon (`Title`), written by the Cosmic Design Director. Examples: `RP_Energy` → *"Stellar Density"*, `RP_Power` → *"Gravity Control"*, `Spheres_Spheres2` → *"Planetary Resonance"*, `Orbs_SpawnLevel` → *"Matter Compression"*, `Prisms_Chromium1` → *"Dark Energy"*, `Prisms_Energy1` → *"Star Formation"*. The grammar name stays visible as the subtitle, so players can always see *what* an upgrade boosts.

Tooltip template (MUST): `<Title>` / `<Grammar name>` / `Boosts <Target> ×<current> → ×<next>` / `Cost <n> <Currency>` / `Requires <requirement in display terms>`.

<details><summary><b>Full upgrade display table (247 rows parsed from the balance sheet; the sheet says 248, and the Consistency Agent must find the missing module in the place file)</b></summary>

| Board (internal folder) | Upgrade (internal) | Display name | Paid in | Max Lv |
|---|---|---|---|---|
| Arctic_Points | `AP_AP1` | Cryo: Cryo Energy I | Cryo Energy | 400 |
| Arctic_Points | `AP_Chromium1` | Cryo: Dark Matter I | Cryo Energy | 4 |
| Arctic_Points | `AP_Droplets1` | Cryo: Cosmic Dust I | Cryo Energy | 300 |
| Arctic_Points | `AP_Prisms1` | Cryo: Prisms I | Cryo Energy | 60 |
| Arctic_Points | `AP_Prisms2` | Cryo: Prisms II | Cryo Energy | 60 |
| Arctic_Points | `AP_Spheres1` | Cryo: Planets I | Cryo Energy | 300 |
| Arctic_Points | `AP_Water1` | Cryo: Nebula Gas I | Cryo Energy | 300 |
| Droplets | `Droplets_AP1` | Dust: Cryo Energy I | Cosmic Dust | 100 |
| Droplets | `Droplets_Chromium1` | Dust: Dark Matter I | Cosmic Dust | 2 |
| Droplets | `Droplets_Droplets1` | Dust: Cosmic Dust I | Cosmic Dust | 100 |
| Droplets | `Droplets_Spheres1` | Dust: Planets I | Cosmic Dust | 100 |
| Droplets | `Droplets_Water1` | Dust: Nebula Gas I | Cosmic Dust | 100 |
| Flesh | `Flesh_DMG` | Bio: Impact | Biomass | 750 |
| Flesh | `Flesh_Energy` | Bio: Starlight | Biomass | 1000 |
| Flesh | `Flesh_Flame` | Bio: Solar Energy | Biomass | 1000 |
| Flesh | `Flesh_Flame2` | Bio: Solar Energy II | Biomass | 1 |
| Flesh | `Flesh_Flesh` | Bio: Biomass | Biomass | 210 |
| Flesh | `Flesh_Orbs` | Bio: Celestial Orbs | Biomass | 1000 |
| Flesh | `Flesh_Orbs2` | Bio: Celestial Orbs II | Biomass | 1000 |
| Flesh | `Flesh_Power` | Bio: Gravity | Biomass | 1000 |
| Flesh | `Flesh_Power2` | Bio: Gravity II | Biomass | 540 |
| Flesh | `Flesh_Prisms` | Bio: Prisms | Biomass | 1 |
| Flesh | `Flesh_RP` | Bio: Cosmic Points | Biomass | 1000 |
| Flesh | `Flesh_Spheres` | Bio: Planets | Biomass | 500 |
| Flesh | `Flesh_Spheres2` | Bio: Planets II | Biomass | 1000 |
| Freeze | `Freeze1` | Gravitational Collapse I | Cosmic Dust | 1 |
| Freeze | `Freeze2` | Gravitational Collapse II | Cosmic Dust | 1 |
| Freeze | `Freeze3` | Gravitational Collapse III | Cosmic Dust | 1 |
| Freeze | `Freeze4` | Gravitational Collapse IV | Cosmic Dust | 1 |
| Freeze | `Freeze5` | Gravitational Collapse V | Cosmic Dust | 1 |
| Freeze | `Freeze6` | Gravitational Collapse VI | Cosmic Dust | 1 |
| Freeze | `Freeze7` | Gravitational Collapse VII | Cosmic Dust | 1 |
| Freeze | `Freeze8` | Gravitational Collapse VIII | Cosmic Dust | 1 |
| Freeze | `Freeze9` | Gravitational Collapse IX | Cosmic Dust | 1 |
| Light | `Light_Chrome1` | Radiant: Astral Matter I | Radiance | 100 |
| Light | `Light_Chrome2` | Radiant: Astral Matter II | Radiance | 200 |
| Light | `Light_Light` | Radiant: Radiance | Radiance | 200 |
| Orbs | `Orbs_Energy` | Orb: Starlight | Celestial Orbs | 1e6 |
| Orbs | `Orbs_Flame` | Orb: Solar Energy | Celestial Orbs | 1e6 |
| Orbs | `Orbs_Orbs` | Orb: Celestial Orbs | Celestial Orbs | 1e6 |
| Orbs | `Orbs_SpawnLevel` | Orb: Cube Tier | Celestial Orbs | 100000 |
| Orbs | `Orbs_SpawnTime` | Orb: Cube Fusion Speed | Celestial Orbs | 20 |
| Permanent | `Orbs_RuneBulk` | Permanent: Scan Bulk | Celestial Orbs | 1 |
| Permanent | `Orbs_RuneLuck` | Permanent: Discovery Luck | Celestial Orbs | 1 |
| Permanent | `Orbs_RuneSpeed` | Permanent: Scan Speed | Celestial Orbs | 1 |
| Power | `Power_Energy` | Gravity: Starlight | Gravity | 200 |
| Power | `Power_Flame` | Gravity: Solar Energy | Gravity | 200 |
| Power | `Power_Flesh` | Gravity: Biomass | Gravity | 200 |
| Power | `Power_Orbs` | Gravity: Celestial Orbs | Gravity | 120 |
| Power | `Power_Power` | Gravity: Gravity | Gravity | 200 |
| Power | `Power_Spheres` | Gravity: Planets | Gravity | 200 |
| Power | `Power_Spheres2` | Gravity: Planets II | Gravity | 1 |
| Power | `Power_XP` | Gravity: Astronomy XP | Gravity | 200 |
| Realm_Points | `RP_DMG` | Research: Impact | Cosmic Points | 400 |
| Realm_Points | `RP_DMG2` | Research: Impact II | Cosmic Points | 180 |
| Realm_Points | `RP_Energy` | Research: Starlight | Cosmic Points | 400 |
| Realm_Points | `RP_Energy2` | Research: Starlight II | Cosmic Points | 400 |
| Realm_Points | `RP_Flame` | Research: Solar Energy | Cosmic Points | 400 |
| Realm_Points | `RP_Orbs` | Research: Celestial Orbs | Cosmic Points | 400 |
| Realm_Points | `RP_Orbs2` | Research: Celestial Orbs II | Cosmic Points | 270 |
| Realm_Points | `RP_Power` | Research: Gravity | Cosmic Points | 400 |
| Realm_Points | `RP_Prisms` | Research: Prisms | Cosmic Points | 225 |
| Realm_Points | `RP_RP` | Research: Cosmic Points | Cosmic Points | 400 |
| Realm_Points | `RP_RP2` | Research: Cosmic Points II | Cosmic Points | 240 |
| Realm_Points | `RP_Spheres` | Research: Planets | Cosmic Points | 400 |
| Realm_Points | `RP_Spheres2` | Research: Planets II | Cosmic Points | 300 |
| Realm_Points | `RP_XP` | Research: Astronomy XP | Cosmic Points | 400 |
| Reflection | `Reflection_Chrome1` | Echo: Astral Matter I | Reality Echo | 200 |
| Reflection | `Reflection_Light1` | Echo: Radiance I | Reality Echo | 200 |
| Reflection | `Reflection_RPS1` | Echo: Scans/sec I | Reality Echo | 2 |
| Spheres | `Spheres_DMG` | Planetary: Impact | Planets | 30 |
| Spheres | `Spheres_Energy` | Planetary: Starlight | Planets | 360 |
| Spheres | `Spheres_Energy2` | Planetary: Starlight II | Planets | 360 |
| Spheres | `Spheres_Flame` | Planetary: Solar Energy | Planets | 360 |
| Spheres | `Spheres_Flesh` | Planetary: Biomass | Planets | 360 |
| Spheres | `Spheres_Orbs` | Planetary: Celestial Orbs | Planets | 360 |
| Spheres | `Spheres_Orbs2` | Planetary: Celestial Orbs II | Planets | 100 |
| Spheres | `Spheres_Power` | Planetary: Gravity | Planets | 360 |
| Spheres | `Spheres_Spheres2` | Planetary: Planets II | Planets | 1 |
| Spheres | `Spheres_XP` | Planetary: Astronomy XP | Planets | 360 |
| Talent | `Chromium_AP1` | Cosmology · Dark Matter: Cryo Energy I | Dark Matter | 5 |
| Talent | `Chromium_AP2` | Cosmology · Dark Matter: Cryo Energy II | Dark Matter | 3 |
| Talent | `Chromium_AP3` | Cosmology · Dark Matter: Cryo Energy III | Dark Matter | 1 |
| Talent | `Chromium_AP4` | Cosmology · Dark Matter: Cryo Energy IV | Dark Matter | 1 |
| Talent | `Chromium_AP5` | Cosmology · Dark Matter: Cryo Energy V | Dark Matter | 1 |
| Talent | `Chromium_AP6` | Cosmology · Dark Matter: Cryo Energy VI | Dark Matter | 5 |
| Talent | `Chromium_AutoChroma` | Cosmology · Dark Matter: Auto Astral Beacon | Astral Tokens | 1 |
| Talent | `Chromium_Automation1` | Cosmology · Dark Matter: Condenser Automation I | Dark Matter | 1 |
| Talent | `Chromium_Automation2` | Cosmology · Dark Matter: Condenser Automation II | Dark Matter | 1 |
| Talent | `Chromium_Automation3` | Cosmology · Dark Matter: Condenser Automation III | Dark Matter | 22 |
| Talent | `Chromium_Chrome1` | Cosmology · Dark Matter: Astral Matter I | Astral Matter | 1 |
| Talent | `Chromium_Chrome10` | Cosmology · Dark Matter: Astral Matter X | Astral Matter | 5 |
| Talent | `Chromium_Chrome11` | Cosmology · Dark Matter: Astral Matter XI | Astral Matter | 100 |
| Talent | `Chromium_Chrome12` | Cosmology · Dark Matter: Astral Matter XII | Astral Matter | 1 |
| Talent | `Chromium_Chrome13` | Cosmology · Dark Matter: Astral Matter XIII | Astral Matter | 1 |
| Talent | `Chromium_Chrome14` | Cosmology · Dark Matter: Astral Matter XIV | Astral Matter | 1 |
| Talent | `Chromium_Chrome15` | Cosmology · Dark Matter: Astral Matter XV | Astral Matter | 2 |
| Talent | `Chromium_Chrome16` | Cosmology · Dark Matter: Astral Matter XVI | Astral Matter | 15 |
| Talent | `Chromium_Chrome17` | Cosmology · Dark Matter: Astral Matter XVII | Astral Matter | 3 |
| Talent | `Chromium_Chrome18` | Cosmology · Dark Matter: Astral Matter XVIII | Radiance | 1 |
| Talent | `Chromium_Chrome19` | Cosmology · Dark Matter: Astral Matter XIX | Astral Matter | 50 |
| Talent | `Chromium_Chrome2` | Cosmology · Dark Matter: Astral Matter II | Astral Matter | 2 |
| Talent | `Chromium_Chrome20` | Cosmology · Dark Matter: Astral Matter XX | Astral Matter | 1 |
| Talent | `Chromium_Chrome21` | Cosmology · Dark Matter: Astral Matter XXI | Astral Matter | 1 |
| Talent | `Chromium_Chrome22` | Cosmology · Dark Matter: Astral Matter XXII | Astral Matter | 10 |
| Talent | `Chromium_Chrome3` | Cosmology · Dark Matter: Astral Matter III | Astral Matter | 1 |
| Talent | `Chromium_Chrome4` | Cosmology · Dark Matter: Astral Matter IV | Astral Matter | 2 |
| Talent | `Chromium_Chrome5` | Cosmology · Dark Matter: Astral Matter V | Astral Matter | 2 |
| Talent | `Chromium_Chrome6` | Cosmology · Dark Matter: Astral Matter VI | Astral Matter | 3 |
| Talent | `Chromium_Chrome7` | Cosmology · Dark Matter: Astral Matter VII | Astral Matter | 10 |
| Talent | `Chromium_Chrome8` | Cosmology · Dark Matter: Astral Matter VIII | Astral Matter | 1 |
| Talent | `Chromium_Chrome9` | Cosmology · Dark Matter: Astral Matter IX | Astral Matter | 10 |
| Talent | `Chromium_Chromifier` | REALITY ENGINE | Astral Matter | 1 |
| Talent | `Chromium_Chromium1` | Cosmology · Dark Matter: Dark Matter I | Dark Matter | 3 |
| Talent | `Chromium_Chromium2` | Cosmology · Dark Matter: Dark Matter II | Dark Matter | 4 |
| Talent | `Chromium_Chromium3` | Cosmology · Dark Matter: Dark Matter III | Dark Matter | 4 |
| Talent | `Chromium_Droplets1` | Cosmology · Dark Matter: Cosmic Dust I | Dark Matter | 1 |
| Talent | `Chromium_Droplets2` | Cosmology · Dark Matter: Cosmic Dust II | Dark Matter | 2 |
| Talent | `Chromium_Hail1` | Cosmology · Dark Matter: Meteor Shower I | Astral Tokens | 1 |
| Talent | `Chromium_Ice1` | Cosmology · Dark Matter: Frozen Matter I | Dark Matter | 4 |
| Talent | `Chromium_Ice2` | Cosmology · Dark Matter: Frozen Matter II | Dark Matter | 1 |
| Talent | `Chromium_Icicles1` | Cosmology · Dark Matter: Stellar Shards I | Dark Matter | 6 |
| Talent | `Chromium_Icicles2` | Cosmology · Dark Matter: Stellar Shards II | Dark Matter | 1 |
| Talent | `Chromium_Icicles3` | Cosmology · Dark Matter: Stellar Shards III | Dark Matter | 1 |
| Talent | `Chromium_Icicles4` | Cosmology · Dark Matter: Stellar Shards IV | Dark Matter | 1 |
| Talent | `Chromium_Light1` | Cosmology · Dark Matter: Radiance I | Astral Matter | 1 |
| Talent | `Chromium_Light10` | Cosmology · Dark Matter: Radiance X | Astral Matter | 1 |
| Talent | `Chromium_Light2` | Cosmology · Dark Matter: Radiance II | Astral Matter | 2 |
| Talent | `Chromium_Light3` | Cosmology · Dark Matter: Radiance III | Astral Matter | 25 |
| Talent | `Chromium_Light4` | Cosmology · Dark Matter: Radiance IV | Astral Matter | 1 |
| Talent | `Chromium_Light5` | Cosmology · Dark Matter: Radiance V | Astral Matter | 4 |
| Talent | `Chromium_Light6` | Cosmology · Dark Matter: Radiance VI | Astral Matter | 1 |
| Talent | `Chromium_Light7` | Cosmology · Dark Matter: Radiance VII | Astral Matter | 3 |
| Talent | `Chromium_Light8` | Cosmology · Dark Matter: Radiance VIII | Astral Matter | 1 |
| Talent | `Chromium_Light9` | Cosmology · Dark Matter: Radiance IX | Radiance | 3 |
| Talent | `Chromium_LightUpgrade1` | Cosmology · Dark Matter: Radiance Lens I | Astral Matter | 1 |
| Talent | `Chromium_LightUpgrade2` | Cosmology · Dark Matter: Radiance Lens II | Astral Matter | 1 |
| Talent | `Chromium_Multi1` | Cosmology · Dark Matter: All-Stat Amplifier I | Dark Matter | 2 |
| Talent | `Chromium_NewStat` | Cosmology · Dark Matter: Luminance Beacon | Astral Matter | 1 |
| Talent | `Chromium_Prisms1` | Cosmology · Dark Matter: Prisms I | Dark Matter | 2 |
| Talent | `Chromium_Prisms2` | Cosmology · Dark Matter: Prisms II | Dark Matter | 1 |
| Talent | `Chromium_Prisms3` | Cosmology · Dark Matter: Prisms III | Dark Matter | 1 |
| Talent | `Chromium_Prisms4` | Cosmology · Dark Matter: Prisms IV | Dark Matter | 5 |
| Talent | `Chromium_Prisms5` | Cosmology · Dark Matter: Prisms V | Dark Matter | 1 |
| Talent | `Chromium_RPS1` | Cosmology · Dark Matter: Scans/sec I | Astral Matter | 1 |
| Talent | `Chromium_RPS10` | Cosmology · Dark Matter: Scans/sec X | Astral Matter | 2 |
| Talent | `Chromium_RPS2` | Cosmology · Dark Matter: Scans/sec II | Astral Matter | 1 |
| Talent | `Chromium_RPS3` | Cosmology · Dark Matter: Scans/sec III | Astral Matter | 3 |
| Talent | `Chromium_RPS4` | Cosmology · Dark Matter: Scans/sec IV | Astral Matter | 1 |
| Talent | `Chromium_RPS5` | Cosmology · Dark Matter: Scans/sec V | Astral Tokens | 4 |
| Talent | `Chromium_RPS6` | Cosmology · Dark Matter: Scans/sec VI | Astral Matter | 1 |
| Talent | `Chromium_RPS7` | Cosmology · Dark Matter: Scans/sec VII | Astral Matter | 2 |
| Talent | `Chromium_RPS8` | Cosmology · Dark Matter: Scans/sec VIII | Astral Matter | 1 |
| Talent | `Chromium_RPS9` | Cosmology · Dark Matter: Scans/sec IX | Astral Tokens | 3 |
| Talent | `Chromium_Reflection1` | Cosmology · Dark Matter: Reality Echo I | Astral Matter | 1 |
| Talent | `Chromium_RuneLuck1` | Cosmology · Dark Matter: Discovery Luck I | Dark Matter | 1 |
| Talent | `Chromium_RuneSpeed` | Cosmology · Dark Matter: Scan Speed | Dark Matter | 1 |
| Talent | `Chromium_RuneStarring` | Cosmology · Dark Matter: Star Mapping | Dark Matter | 1 |
| Talent | `Chromium_Shine1` | Cosmology · Dark Matter: Luminance I | Astral Tokens | 2 |
| Talent | `Chromium_Shine2` | Cosmology · Dark Matter: Luminance II | Astral Tokens | 10 |
| Talent | `Chromium_SpheresEnhance` | Cosmology · Dark Matter: Planetary Resonance | Dark Matter | 1 |
| Talent | `Chromium_Tickets1` | Cosmology · Dark Matter: Star Charts I | Astral Matter | 3 |
| Talent | `Chromium_Tickets2` | Cosmology · Dark Matter: Star Charts II | Astral Matter | 1 |
| Talent | `Chromium_UltraRunes` | Cosmology · Dark Matter: Fundamental Forces Access | Astral Tokens | 10 |
| Talent | `Chromium_Water1` | Cosmology · Dark Matter: Nebula Gas I | Dark Matter | 3 |
| Talent | `Prisms_AP1` | Cosmology · Prisms: Cryo Energy I | Prisms | 1 |
| Talent | `Prisms_Accelerator` | Cosmology · Prisms: Accelerator Stages | Prisms | 6 |
| Talent | `Prisms_AutoAttack` | Cosmology · Prisms: Auto-Impact | Prisms | 1 |
| Talent | `Prisms_AutoAttackSpeed` | Cosmology · Prisms: Auto-Impact Rate | Prisms | 9 |
| Talent | `Prisms_AutoFlame` | Cosmology · Prisms: Auto-Ignite | Prisms | 1 |
| Talent | `Prisms_AutoLevel` | Cosmology · Prisms: Auto Threat Escalation | Prisms | 1 |
| Talent | `Prisms_AutoPower` | Cosmology · Prisms: Auto-Compress | Prisms | 1 |
| Talent | `Prisms_AutoPower2` | Cosmology · Prisms: Auto-Compress II | Prisms | 19 |
| Talent | `Prisms_AutoPower3` | Cosmology · Prisms: Auto-Compress III | Prisms | 19 |
| Talent | `Prisms_Caps` | Cosmology · Prisms: Upgrade Caps | Prisms | 2 |
| Talent | `Prisms_Chromatizer` | GALAXY FORGE | Prisms | 1 |
| Talent | `Prisms_Chromium1` | Cosmology · Prisms: Dark Matter I | Prisms | 2 |
| Talent | `Prisms_DMG` | Cosmology · Prisms: Impact Exponent | Prisms | 1 |
| Talent | `Prisms_Damage` | Cosmology · Prisms: Impact | Prisms | 3 |
| Talent | `Prisms_Droplets1` | Cosmology · Prisms: Cosmic Dust I | Prisms | 5 |
| Talent | `Prisms_Droplets2` | Cosmology · Prisms: Cosmic Dust II | Prisms | 1 |
| Talent | `Prisms_Energy1` | Cosmology · Prisms: Starlight I | Prisms | 1 |
| Talent | `Prisms_Energy2` | Cosmology · Prisms: Starlight II | Prisms | 1 |
| Talent | `Prisms_Flame1` | Cosmology · Prisms: Solar Energy I | Prisms | 3 |
| Talent | `Prisms_Flame2` | Cosmology · Prisms: Solar Energy II | Prisms | 2 |
| Talent | `Prisms_Flesh` | Cosmology · Prisms: Biomass | Prisms | 2 |
| Talent | `Prisms_Flesh2` | Cosmology · Prisms: Biomass II | Prisms | 1 |
| Talent | `Prisms_Flesh3` | Cosmology · Prisms: Biomass III | Prisms | 1 |
| Talent | `Prisms_Multi` | Cosmology · Prisms: All-Stat Amplifier | Prisms | 2 |
| Talent | `Prisms_Orbs1` | Cosmology · Prisms: Celestial Orbs I | Prisms | 4 |
| Talent | `Prisms_Orbs2` | Cosmology · Prisms: Celestial Orbs II | Prisms | 3 |
| Talent | `Prisms_OrbsAutoBuy` | Cosmology · Prisms: Orb Autobuyer | Prisms | 1 |
| Talent | `Prisms_OrbsEnhance` | Cosmology · Prisms: Orb Resonance | Prisms | 1 |
| Talent | `Prisms_Power` | Cosmology · Prisms: Gravity | Prisms | 5 |
| Talent | `Prisms_Prisms1` | Cosmology · Prisms: Prisms I | Prisms | 1 |
| Talent | `Prisms_Prisms2` | Cosmology · Prisms: Prisms II | Prisms | 1 |
| Talent | `Prisms_Prisms3` | Cosmology · Prisms: Prisms III | Prisms | 2 |
| Talent | `Prisms_Prisms4` | Cosmology · Prisms: Prisms IV | Prisms | 1 |
| Talent | `Prisms_RP1` | Cosmology · Prisms: Cosmic Points I | Prisms | 2 |
| Talent | `Prisms_RP2` | Cosmology · Prisms: Cosmic Points II | Prisms | 1 |
| Talent | `Prisms_RPEnhance` | Cosmology · Prisms: Research Resonance | Prisms | 1 |
| Talent | `Prisms_RPS` | Cosmology · Prisms: Scans/sec | Astral Tokens | 8 |
| Talent | `Prisms_RPS2` | Cosmology · Prisms: Scans/sec II | Astral Tokens | 24 |
| Talent | `Prisms_RTokens` | Cosmology · Prisms: Astral Token Rate | Astral Tokens | 6 |
| Talent | `Prisms_RuneBulk` | Cosmology · Prisms: Scan Bulk | Prisms | 2 |
| Talent | `Prisms_RuneBulk2` | Cosmology · Prisms: Scan Bulk II | Astral Tokens | 1 |
| Talent | `Prisms_RuneBulk3` | Cosmology · Prisms: Scan Bulk III | Astral Tokens | 10 |
| Talent | `Prisms_RuneBulk4` | Cosmology · Prisms: Scan Bulk IV | Astral Tokens | 8 |
| Talent | `Prisms_RuneClone` | Cosmology · Prisms: Echo Scan | Astral Tokens | 1 |
| Talent | `Prisms_RuneLuck` | Cosmology · Prisms: Discovery Luck | Prisms | 2 |
| Talent | `Prisms_RuneLuck2` | Cosmology · Prisms: Discovery Luck II | Prisms | 1 |
| Talent | `Prisms_RuneSpeed` | Cosmology · Prisms: Scan Speed | Prisms | 1 |
| Talent | `Prisms_RuneSpeed2` | Cosmology · Prisms: Scan Speed II | Astral Tokens | 100 |
| Talent | `Prisms_RuneSpeed3` | Cosmology · Prisms: Scan Speed III | Astral Tokens | 250 |
| Talent | `Prisms_SpawnSpeed` | Cosmology · Prisms: Anomaly Respawn | Prisms | 12 |
| Talent | `Prisms_Spheres1` | Cosmology · Prisms: Planets I | Prisms | 5 |
| Talent | `Prisms_Spheres2` | Cosmology · Prisms: Planets II | Prisms | 3 |
| Talent | `Prisms_Spheres3` | Cosmology · Prisms: Planets III | Prisms | 1 |
| Talent | `Prisms_Spheres4` | Cosmology · Prisms: Planets IV | Prisms | 1 |
| Talent | `Prisms_Spheres5` | Cosmology · Prisms: Planets V | Prisms | 4 |
| Talent | `Prisms_SpheresEnhance` | Cosmology · Prisms: Planetary Resonance | Prisms | 1 |
| Talent | `Prisms_Tickets` | Cosmology · Prisms: Star Charts | Prisms | 1 |
| Talent | `Prisms_Tickets2` | Cosmology · Prisms: Star Charts II | Astral Tokens | 4 |
| Talent | `Prisms_Walkspeed` | Cosmology · Prisms: Thruster Speed | Prisms | 1 |
| Talent | `Prisms_Water1` | Cosmology · Prisms: Nebula Gas I | Prisms | 3 |
| Tickets | `Tickets_Chrome1` | Chart: Astral Matter I | Star Charts | 30 |
| Tickets | `Tickets_Chromium` | Chart: Dark Matter | Star Charts | 1 |
| Tickets | `Tickets_Droplets` | Chart: Cosmic Dust | Star Charts | 60 |
| Tickets | `Tickets_Energy` | Chart: Starlight | Star Charts | 60 |
| Tickets | `Tickets_Flame` | Chart: Solar Energy | Star Charts | 60 |
| Tickets | `Tickets_Flesh` | Chart: Biomass | Star Charts | 60 |
| Tickets | `Tickets_Ice` | Chart: Frozen Matter | Star Charts | 60 |
| Tickets | `Tickets_Icicles` | Chart: Stellar Shards | Star Charts | 60 |
| Tickets | `Tickets_Orbs` | Chart: Celestial Orbs | Star Charts | 60 |
| Tickets | `Tickets_Power` | Chart: Gravity | Star Charts | 60 |
| Tickets | `Tickets_RuneBulk` | Chart: Scan Bulk | Star Charts | 1 |
| Tickets | `Tickets_RuneBulk2` | Chart: Scan Bulk II | Star Charts | 25 |
| Tickets | `Tickets_RuneBulk3` | Chart: Scan Bulk III | Star Charts | 75 |
| Tickets | `Tickets_RuneBulk4` | Chart: Scan Bulk IV | Star Charts | 1 |
| Tickets | `Tickets_RuneLuck` | Chart: Discovery Luck | Star Charts | 1 |
| Tickets | `Tickets_RuneLuck2` | Chart: Discovery Luck II | Star Charts | 25 |
| Tickets | `Tickets_RuneSpeed` | Chart: Scan Speed | Star Charts | 1 |
| Tickets | `Tickets_RuneSpeed2` | Chart: Scan Speed II | Star Charts | 25 |
| Tickets | `Tickets_RuneSpeed3` | Chart: Scan Speed III | Star Charts | 150 |
| Tickets | `Tickets_Spheres` | Chart: Planets | Star Charts | 60 |
| Tickets | `Tickets_Tickets` | Chart: Star Charts | Star Charts | 2 |
| Tickets | `Tickets_Water` | Chart: Nebula Gas | Star Charts | 60 |
</details>

### 5.8 Anomalies (mobs) and artifacts (chests)

Mob HP, level, reward and chest math are unchanged (`Libraries.Mob`, `MobsHandler`). There is one mob type ("Magma") in code. The Anomaly roster is **cosmetic, chosen by Threat Level band**:

| Threat Level (`Mobs_SetLevel`) | Anomaly | Form | Hit feedback |
|---|---|---|---|
| 1–24 | **Rogue Planet** | cracked drifting planetoid | chunks spall off |
| 25–74 | **Void Beast** | quadruped silhouette of negative space | edges flicker white |
| 75–149 | **Star Eater** | maw-ringed creature orbiting a small star | star dims per hit |
| 150–299 | **Gravity Wraith** | cloak of lensing distortion | lens ripple |
| 300–499 | **Cosmic Serpent** | long segmented constellation serpent | segments detach |
| 500–799 | **Nebula Leviathan** | gas-body whale with skeletal core | gas bursts |
| 800–999 | **Black Hole Entity** | event-horizon body, accretion limbs | photon-ring flash |
| 1000+ (HP formula switches to 1e303·4^(L−1000)) | **Reality Devourer** | broken-geometry titan (Sector V aesthetic) | screen-space glitch slice |

Chest spawn = **Anomaly collapses into a Cosmic Artifact** (×3 HP variant with a gold-violet rim). Reward branches (unchanged odds): Astral Tokens (35–175 or 1–10), Catalysts (1 or 3), Biomass ×100. The artifact floats in a miniature galaxy on the **Artifact Dais** (`Workspace.ChestOpen` origin) and bursts on claim.

Legacy "Polygonal *" rigs in `ReplicatedStorage.Other Mobs` are retired. Anomalies are EditableMesh or Blender assets driven by the same `Mob_Update/Mob_UpdateHP/Mob_Hit` remotes.

---

## 6. Name-Collision Rules (resolved)

The proposal reused several names in two places. These are the final rulings:

| Clash | Ruling |
|---|---|
| **Radiance** = `Light` currency *and* Color rune `Radiance` | Currency keeps **Radiance**. Rune → **Gold**. |
| **Spectrum** = proposed Color pack name *and* Polychrome rune `Spectrum` *and* "Spectral" pack | Color pack → **Stellar Hues**. Polychrome pack → **Spectral**. Rune keeps **Spectrum**. |
| **Supernova** = Ascension reset *and* proposed Nebula discovery | Reset keeps **Supernova**. Discovery → **Hypernova** (`Cyclone`). |
| **Cosmic Dust** = `Droplets` currency *and* Galactic rune `CosmicDust` | Currency keeps **Cosmic Dust**. Rune → **Stardust**. |
| **Planet(s)** = `Spheres` currency *and* Galactic rune `Planet` *and* Beginner idea | Currency keeps **Planets**. Rune → **Homeworld**. Beginner doesn't use it. |
| **Star** rune (Galactic) | → **Starborn** (too generic otherwise). |
| **Dark Matter** = `Chromium` *and* Global rune `Darkmatter` | Currency keeps **Dark Matter**. Rune → **Umbral Matter**; `Lightmatter` → **Luminous Matter**. |
| **Black Hole** = Collapse VI *and* proposed Nebula discovery | Collapse keeps it. Nebula uses **Accretion Disk** instead. |
| **Pulsar / Magnetar** listed in both Beginner and Nebula | Nebula only (`Emberglow`, `Dreamscape`). |
| **Galaxy** = rune `Galaxy`, Galaxy Formation, Galaxy Core | Rune → **Spiral Galaxy**. Reset = **Galaxy Formation**. Hub object = **Galaxy Core**. |
| **Axium** | Displayed as **Galaxy Cluster** per proposal (internal `Axium` untouched). |
| **Unknown** = Collapse IX object *and* Basic rune `Unknown` | Collapse IX object → **???** (rendered as a censored silhouette). Rune → **Class B**. |
| **Reflection** kept vs **Reality Echo** | Final: **Reality Echo** everywhere player-facing. |
| **Gravity** = `Power` *and* physics theme of Trial | Trial is **Trial of Gravity**, and the UI always shows the currency with its icon. Acceptable. |
| **Prismatic** (rune) vs **Prisms** (currency) | Rune → **Prismatic Star**. |
| **Primordial** = Ultra rune *and* Sector IV name *and* Beginner `Vanguard` | Sector keeps **Primordial Universe**. Ultra rune → **Big Bang Seed**. `Vanguard` → **Primordial Star** (acceptable: an object, not a place). |

**Rule going forward:** a display name may be used by exactly one internal ID. The Consistency Agent enforces this with a uniqueness check over the Lexicon module (§22.3).

---

## 7. Epochs (Tier 0–13): progression identity

`Tier` is the spine. Every Epoch has a name, a **Cosmic Core state** (§11.5), a **sky state** (§13), and an unlock beat. The timing column comes from the balance simulation (active F2P player).

| Epoch (Tier) | Name | Reached at (sim) | Advance cost (unchanged) | New thing unlocked (automation gates) | Cosmic Core shows |
|---|---|---|---|---|---|
| 0 | **Particle** | 0 s | 100 Starlight | Starlight generation | a single glowing mote in a containment ring |
| 1 | **Dust Cloud** | 6 s | 1e6 Starlight | Stellar Forge (Solar Energy), Research Array, Stellar Survey, Zodiac | mote gathers a swirl of dust |
| 2 | **Protostar** | ~1–2 min (interp.) | 5e9 | Gravity Well | dust collapses, core ignites, jets form |
| 3 | **Star System** | 5.5 min | 2.5e15 | Stellar Classes survey | a true star with 2 tiny planets |
| 4 | **Constellation** | ~10 min (interp.) | 7.5e23 | Astronomy XP / Observer Level, Anomalies, Auto-Impact, Salvage Beacon | star + faint constellation lines to 6 neighbors |
| 5 | **Planetary Age** | ~17 min | 1e40 | Prisms generation | planets gain rings, moons, atmospheres |
| 6 | **Solar System** | ~27 min | 1e65 | Stellar Hues survey, Prism ×2 pad, Cosmology prism node | full orrery: 8 orbits, asteroid belt |
| 7 | **Nebula** | ~67 min | 1e153 | Celestial Orbs | system sits inside a colorful nebula shell |
| 8 | **Galaxy** | ~1.4 h | 1e276 | Space Cubes / Cube Fusion | zoom-out: the system is one point in a small spiral |
| 9 | **Galaxy Cluster** | ~1.8 h | "1e978" | Planets (Spheres), Nebula survey | 3–5 galaxies orbiting |
| 10 | **Supercluster** | ~3.1 h | **Droplets-gated from here** (1e52 after the balance change) | Meteor Shower Beacon, Cosmic Trials matter now | filament web of clusters |
| — | **SUPERNOVA** | ~7.1 h | `Energy > 1e2283` | Cosmic Dust, Spectral survey, Realm II path | *explodes* (§10.2) |
| 11 | **Universe** | ~0.5 day (post-change est.) | 7.5e113 Cosmic Dust | Collapse I, observation streak | an entire bubble universe with cosmic web |
| 12 | **Multiverse** | ~1.4 days after E11 | 1e195 Cosmic Dust | Collapse IV–VI, Global Goal hooks (disabled) | 3 bubble universes touching |
| 13 | **Beyond** | — | unreachable cap | Solar Wind Beacon, Stellar Shards, Collapse VII–IX | the bubbles fold into a single white seam |

**Epoch-up moment (every tier):** 1.2 s total. The camera does a subtle pull-back (8° FOV widen), the Cosmic Core morphs to its next state, and an Epoch title card slides in ("EPOCH 3 · STAR SYSTEM"). A shockwave ring runs across the Observatory floor and the new unlock's platform powers on with a beam from the core to it. Skippable. Never delays input.

**Post-Supernova replays** of Epochs 0–10 use a **compressed variant** (0.5 s, no title card after the first replay), because they happen roughly 10× faster.

---

## 8. System-by-System Presentation Spec

Every entry has the same fields: **Internal**, **Where**, **Idle state**, **Growth states** (keyed to log10 of the amount), **Action feedback**, **UI**, **Tech**, **Acceptance**.

### 8.1 Starlight (`Energy`)

- **Where:** the **Starlight Core**, dead center of the Observatory. It is the first thing the player sees. The spawn faces it.
- **Idle:** a small star inside a mechanical containment ring (3 nested gimbals, counter-rotating). About 40 motes drift inward from the surrounding asteroid field every second. Each accepted gain tick makes the core pulse (scale 1.00→1.04, 120 ms).
- **Growth states** (by log10 Starlight): 0–3 mote swarm sparse · 3–10 motes denser, inner ring glows · 10–40 motes become streams · 40–150 streams braid into ribbons · 150–1000 ribbons + periodic starburst (every 8 s) · 1000+ (pre-Supernova) core overdriven, lens flare, subtle screen-edge bloom, "unstable" warning glyphs appear near 1e2283.
- **Feedback:** the gain number floats up from the core with physical overshoot. It is not a UI toast; it's a BillboardGui with a tweened `Size` and EditableImage glyph glow. It is rate-limited to 4/s, and in between gains aggregate ("+1.2e40 ×3").
- **HUD:** the hero readout (§14.4), with an animated starfield *inside the digits* (EditableImage mask).
- **Tech:** motes = one pooled `ParticleEmitter` with its rate driven by the state band, plus 1 EditableMesh ribbon strip (≤ 512 tris) for states ≥ 40.
- **Acceptance:** a new player identifies "the number that matters" within 10 s without text (Playtest Agent, §22.4).

### 8.2 Solar Energy (`Flame`) — the Stellar Forge

- **Unlock:** Epoch 1. The first unlock is staged: a ring structure that was dark from spawn powers up and a miniature sun ignites inside it. Title: "SOLAR ENERGY GENERATED".
- **Idle:** plasma shell (EditableMesh sphere, 642 verts, vertex noise displacement at 10 Hz), 3 prominence arcs (Beams), corona EditableImage (256², animated noise, 15 Hz).
- **Growth:** the prominence count and corona radius scale with log10(Flame). From 1e6 Solar Energy on (the Flame→XP multiplier unlock at `Flame_XP`), a second corona layer appears and the board line switches from "XP MULTI UNLOCKED AT 1M SOLAR ENERGY" to the live multiplier.
- **Action (IGNITE pad):** a Starlight stream is visibly sucked from the Core to the Forge (cost 50). A flare pops on success.
- **Board:** *Solar Energy · ×N Starlight · ×N Astronomy XP*. It replaces the `FlameBoard` SurfaceGui.
- **Acceptance:** the flare pops at the same moment as the server gain (±1 frame of `Stats.Flame.Changed`).

### 8.3 Gravity (`Power`) — the Gravity Well

- **Unlock:** Epoch 2. A black sphere floats above a pedestal. Nearby debris starts orbiting it.
- **Behaviour:** Power resets Solar Energy and Starlight. The cinematic shows both being **pulled in**: the Forge sun and the Core motes stretch toward the Well and vanish over 0.6 s, then relight at zero.
- **Growth:** lens-rim thickness, orbiting debris count (max 48, pooled) and the distortion radius scale with log10(Gravity). The player can walk through a **gravity field** ring with a slight camera sway and a screen-edge lens shader (a viewport-overlay EditableImage, cheap). **No physics changes to walkspeed** (that's a formula).
- **Board:** *Gravity · ×N Impact (Gravity^0.075 / ^0.175 with Impact Exponent) · ×N Planets (Gravity^0.01 when Planetary Resonance II owned)*.
- **Auto-Compress** (`Prisms_AutoPower`): the Well pulses on its own rhythm (`AutoPower` CD) with a softer visual (no stretch cinematic).

### 8.4 Cosmic Points (`Realm Points`) — the Cosmic Research Array

- Huge floating holographic rings around a central star (a second small star, distinct from the Core). Each purchased RP upgrade lights a **discovered phenomenon node** on the rings. The rings physically **expand outward** as more nodes light (ring radius = base + 0.4 studs × owned levels, capped).
- The 14 RP upgrades are shown as 14 phenomena on the ring: Stellar Density (`RP_Energy`), Gravity Control (`RP_Power`), Solar Ignition (`RP_Flame`), Impact Theory (`RP_DMG`), Orbital Mechanics (`RP_Orbs`), Planetary Formation (`RP_Spheres`), Research Loop (`RP_RP`), Observation (`RP_XP`), Prism Optics (`RP_Prisms`); post-Supernova "II" variants appear on an outer ring.
- Auto-buy at Galaxy Rank ≥ 1: nodes light on their own with a faint scanning sweep.

### 8.5 Star Charts (`Tickets`) and the Chart Terminal

- Charts drop from **every scan** (per-open roll `Ticket_Chance`). Each drop produces a folded holographic chart that flies from the bay to the player's HUD counter. Batch it: at most 1 flyer per 0.25 s, and the counter shows "+N".
- The **Star Chart Terminal** (old `Spawn Island.Tickets`) hosts the Chart upgrades (`Tickets_*`) as a star-map console.

### 8.6 Biomass / Impact / Anomalies (`Flesh`, `Damage`, mobs)

- **Where:** the **Anomaly Containment Ring**, a circular arena with an energy fence. `NextLevel/PreviousLevel` pads become **Threat ▲ / Threat ▼** consoles. `LevelBar` becomes a threat meter. `Health` is the anomaly's HP ring.
- **Hit:** a player strike sends an Impact shock ring. The number pops in impact white. Auto-Impact shows a turret-drone firing on the Auto-Impact CD.
- **Kill:** the anomaly dissolves into Biomass (teal bioluminescent motes flying to the player).

### 8.7 Celestial Orbs (`Orbs`)

- The **Orb Observatory**: a lattice of glass orbs with a starfield inside each. The `Incrementor` becomes the **Orb Condenser**. One orb is added to the lattice per order of magnitude, up to 24, and after that the orbs brighten instead.
- Permanent upgrades (`Orbs_RuneBulk/RuneLuck/RuneSpeed`) are three **golden orbs** marked PERMANENT, because they survive resets. The UI must mark them **"Survives Epoch resets."**

### 8.8 Space Cubes (Merger / `Cube_Level`)

- **Cube Fusion Bay:** metallic cubes spawn on a conveyor ring (`Cubes` CD) and fuse in pairs (the Merger). Cube Tier shows as seam color and size, cycling through 12 palette steps and then adding emissive rune-lines per 100 tiers.
- Cube Tier milestones that the formulas reference (20: faster spawns; 35, 55, 400, 1350, 1440 upgrade gates) each get a **milestone plaque** on the bay wall that lights when reached.

### 8.9 Planets (`Spheres`) — the Planetarium

- **Where:** a dome with a procedural **planet** at its center. `Sphere_Levels` = Planet Grade.
- The planet's look is keyed to Spheres milestones (these are the formula thresholds, displayed as **Planetary Milestones** on the `Milestones` board): 100 (×25 Starlight), 1e7 (×5 Planets), 2.5e14 (Research ×3 speed), 2.5e17 (×25 Orbs), 5e20 (Prism ×2), 1e27 (×2 Charts), 1e69 (luck/speed), 5e72 (+3 bulk), 1e98 (×1e15 Biomass), 1e150, 1e184, 1e199, 1e202, 1e275, 1e282, 1e291. Each milestone adds a planetary feature: rings, moons, oceans, city lights, orbital stations, a Dyson swarm, and so on. That gives 16 visible stages.
- **Tech:** `CosmicObjectRenderer` Planet preset with parameters driven by milestone index (§16.3).

### 8.10 Prisms

- Prisms stay **Prisms**, the bridge currency between realms. They are faceted crystals that split light into a spectrum. The **Prism Refractor** (old `PrismsBoard`/`PrismButton`) is on Cosmology Isle. Standing on it (the ×2 pad, Epoch ≥ 6) splits a beam across the player.
- A Prism gain drops a crystal that shatters into a spectrum splash across the HUD counter.

### 8.11 Cosmic Dust (`Droplets`), post-Supernova primary

- A glittering **dust swarm permanently orbits the player's character** after Supernova. Density bands follow log10(Cosmic Dust), up to 256 pooled particles. It must be client-only and visible only on your own character by default. Other players' swarms show at 25% density (setting).
- The **Dust Board** (old `DropletBoard`) shows the Cosmic Dust→Planets, Nebula Gas→Cosmic Dust and Frozen Matter chains as an animated flow diagram.
- ⚠ The Droplets loop multiplies the whole balance every 0.5 s in Realm ≠ One (a known bug). Presentation must **not** try to animate every tick. Use a smoothed display value (log-lerp) for the counter.

### 8.12 Nebula Gas (`Water`) — the Nebula Engine

- A huge rotating machine that vents nebula clouds. **Nebula Condensers** (Water multiplier buttons, cost 25·7.5^(n−1) Cosmic Dust) are vents around it. Buying one opens that vent.
- The **world responds:** the Expanse sky nebula density and saturation lerp with log10(Nebula Gas), and small stars ignite inside the clouds (≤ 64 sprites).

### 8.13 Frozen Matter (`Ice`) — the Absolute Zero Chamber

- A giant frozen ring. **Cryo Condensers** (Ice buttons) **reset Cosmic Dust and Nebula Gas**, so the confirm UI shows exactly that ("Consumes all Cosmic Dust and Nebula Gas").
- **World-state change:** a frost decal spreads across nearby geometry (EditableImage mask on a projected layer, radius by log10 Ice), crystals grow (instanced mesh, ≤ 40), and the local particle speed drops by 30%.

### 8.14 Cryo Energy (`ArcticPoints`) — the Cryo Reactor

- A white-blue reactor with arcing charge. The board lists Cryo upgrades (`AP_*`).
- Note: Arctic Points' Epoch bonus is computed but never applied (a known bug). **Do not display** an Epoch bonus for Cryo Energy.

### 8.15 Dark Matter (`Chromium`)

- Unlocked by Galaxy Rank ≥ 1. Dark Matter is never a flat icon. It is a black-purple **gravitational substance** that bends light around itself.
- **Recipe:** a dark core mesh + a Fresnel rim (SurfaceAppearance, emissive via color trick) + a **lensing ring** (an EditableImage that samples a *pre-rendered* starfield texture with a radial displacement; we don't sample the live framebuffer, which Roblox doesn't support) + inward-falling particles.
- The HUD card shows a live dark blob that "eats" the card's own starfield background.

### 8.16 Astral Matter (`Chroma`)

- Unlocks at Galaxy Rank ≥ 1000 (or Vanguard ≥ 1e19 for the pad; the gates are as coded). A transparent black crystal with **moving galaxy textures inside** (a flipbook EditableImage, 256², 8 frames, projected onto the crystal via `EditableImage` projection), surrounded by tiny stars.
- ~60 Chroma-paid Cosmology nodes: this is the densest part of the tree (§12.4).

### 8.17 Radiance (`Light`) and Reality Echo (`Reflection`): see §10.4 and §10.6

### 8.18 Beacons (timed claim stats)

| Beacon | Internal | Recharge | Unlock | Visual |
|---|---|---|---|---|
| Salvage Beacon | `Loot` | 10 min | Epoch 4 | wreck with a blinking distress light |
| Meteor Shower Beacon | `Hail` | 24 h | Epoch 10 | a sky-wide meteor shower plays on claim |
| Solar Wind Beacon | `Haze` | 24 h | Epoch 13 | particle lanes sweep the Expanse |
| Radiance Beacon | `Light` | 2 s (as coded) | Breach ≥ 1 | white pillar |
| Convergence Beacon | `Ascended` (gives Astral Matter) | 2 s | Breach ≥ 2 | two light pillars converge |
| Astral Beacon | `Chroma` | 10 s | Galaxy Rank ≥ 1000 | crystal pulse |
| Luminance Beacon | `Shine` | 30 s | `Chromium_NewStat` | soft glint |

Every beacon shows a **radial recharge ring** and a "READY" state that is visible from 200 studs (a vertical light shaft). Claiming plays a 0.8 s burst.

### 8.19 Orbital Gyros (`Gears`) and Particle Accelerator (`Accelerator`)

- Gyros are nested gimbals whose spin speed = `Gears_Speed` (a cooldown reduction, visualised).
- The Accelerator is a collider ring: one particle races faster per stage (30–60 stages via `Accelerator_Levels`). Cost 1e243·75^n, so this is a late Realm I object. It sits at the Frontier rim.

### 8.20 Astronomy XP / Observer Level

- XP bar = a thin beam under the Epoch readout. Level-ups get a small badge flip. `Level_Energy = 1.3^Level` is shown as "Observer bonus ×N Starlight".

### 8.21 Astral Tokens (`RobuxTokens`)

- A gold-violet coin with a star cut-out. They tick up over time (the `RobuxTokens` CD); the coin spins once per tick. Token-priced Cosmology nodes are marked with a coin glyph.

---

## 9. Celestial Discoveries (the rune system)

### 9.1 How the engine really behaves (constraints the presentation must respect)

- Scanning is **continuous**. While a player stands on a bay pad, the automation loop opens `Bulk = clamp(Rune_Afford, 0, Rune_Bulk)` every `Rune_Speed` seconds (min 1/60 s). Late-game bulk reaches the billions per tick.
- Rewards are queued and **flushed every 5 s** (Pending queue, 1 s wait per rune type). The client learns about gains through `Rune_Reward` and `Player.Runes.<Name>` changes.
- `Rune:GetResult` runs twice per open (a known bug, §19). Presentation shows **what the player actually received** (the value delta), never a separately computed roll.
- Pity accrues in attributes named `<Name>Pity` for chance-limited items.
- `RuneLuck=false` items ignore luck entirely.

**So:** we can't animate every scan. Presentation is **tiered**, as below.

### 9.2 Presentation tiers

| Tier | When | What plays | Budget |
|---|---|---|---|
| **Scan Feed** | always, while on a bay | The bay telescope sweeps. A strip of thumbnail objects scrolls in the bay's holo-panel. The HUD shows "Scanning · 1.2e9 scans/sec" | 1 EditableImage 512×128, 10 Hz |
| **Discovery Toast** | a flush contains an object ≥ the player's toast threshold (default **Uncommon**) | A card slides in from the right with the object preview, name, rarity, "+N" and new total. Stacks up to 3, then merges | UI only |
| **Discovery Reveal** (the signature moment) | a **first-ever** discovery of an object at Rare+, or any Legendary+ | the full 7-step cinematic (§9.3), ≤ 3.5 s, skippable, one at a time, the queue collapses to the best item | full-screen |
| **Deep-Field Event** | any Mythic+ (1e20+) | Reveal + a server-wide chat broadcast (existing `Broadcast`/`GlobalMessage`) + a sky event over the bay for everyone nearby | full-screen + world |

Player settings: toast threshold, reveal threshold, "reveal first-time only", reduced motion.

### 9.3 The Discovery Reveal cinematic (storyboard)

| t (s) | Beat | Implementation |
|---|---|---|
| 0.00 | A Star Chart unfolds at screen center (it's what paid for the scan) | UI sprite + EditableImage fold animation |
| 0.25 | The camera "zooms into space": the viewport darkens, and a starfield parallax rushes outward | full-screen EditableImage starfield (shared, §16.2), 3 depth layers |
| 0.70 | A scanner sweep (a radar arc) crosses the field. Thousands of star points flare as it passes | same image, additive pass |
| 1.40 | The reticle **locks on one star**. The lock sound pitch-steps by rarity | UI reticle |
| 1.80 | The object resolves: `CosmicObjectRenderer` spawns the preset in a ViewportFrame, scale 0→1 with overshoot | §16.3 |
| 2.30 | The rarity plate slams in: band color, band name, "1 in 7.5e8" and a **Deep-Field** tag if luck-immune | UI |
| 2.80 | The object flies to the Star Catalog icon and the count ticks | tween |
| 3.50 | Done | — |

Rarity scales the beats: Common/Uncommon skip straight to a toast. Celestial+ add a 0.6 s pre-roll where the sky of the *actual world* dims and a beam hits the bay.

### 9.4 Rarity band styling

| Band | Plate color token | Frame | Reveal extra | SFX |
|---|---|---|---|---|
| Common | `rar.common` slate | thin line | — | soft blip |
| Uncommon | `rar.uncommon` teal | line + corner ticks | — | blip ×2 |
| Rare | `rar.rare` blue | double line | reticle lock | lock chime |
| Epic | `rar.epic` violet | double + glow | star points flare | rising chime |
| Legendary | `rar.legendary` gold | ornate observatory brass | lens flare | brass hit |
| Mythic | `rar.mythic` magenta-white | animated spectral border | screen-edge chroma | choir pad |
| Celestial | `rar.celestial` white-cyan | constellation border that draws itself | world sky dims | deep boom |
| Cosmic | `rar.cosmic` black + rainbow rim | lensing border | camera shake 0.2 | sub-bass swell |
| Transcendent | `rar.transcendent` pure white, inverted UI | UI inverts for 0.4 s | full world freeze-frame | silence → single tone |

### 9.5 Special-pool events

| Pool | Event name | Look |
|---|---|---|
| GlobalRune | **Cosmic Ray Strike** | a streak from the sky hits the player; a particle-shower HUD |
| AncientRune | **Relic Recovery** | a stone relic rises from an asteroid, glyphs light |
| MadnessRune | **Chaos Surge** | a glitch-slice across the screen, a red rift opens then seals |
| UltraRune | **Force Manifestation** | four field-line diagrams converge into a symbol |

### 9.6 Telescope Bays (world)

Each survey gets a **Telescope Bay** replacing `Spawn Island.<Pack>` (model + `Stand` + `RuneUI` + `RuneUI2`):
- A telescope (Blender hero asset, one per pack with a unique dish/finish) aimed at a region of the sky where **that pack's objects are painted into the skybox** (§13). Players literally look where they're scanning.
- A holo-panel (`RuneUI` → pack info: cost, scans/sec, bulk, luck, your best find). A second panel (`RuneUI2` → odds table: display names, 1-in-X, owned count, Signal Lock %).
- A pad ring on the floor (the existing stand-on trigger, tags preserved).
- Locked bays show a sealed dome with the unlock condition in display terms ("Requires Epoch 6 · Solar System").

### 9.7 Star Catalog (the `Index` UI)

- A grid by survey. Unknown objects are shown as black silhouettes with "???". Found objects rotate live on hover/tap (one ViewportFrame at a time; the rest show cached thumbnails, §16.4).
- For each object: display name, rarity, 1-in-X, owned count, **what it boosts** (from `RuneFormulas` names mapped through the Lexicon, e.g. "Starlight ×(1 + 0.1 per)", "caps at ×1e300"), Signal Lock %, and first-found date (from the client cache only; no new saved data).
- The balance note says Epoch 11→12 needs the right packs (Cosmic Dust/Prisms boosts live in Nebula, Spectral, Deep Space, Cosmic Web). The Catalog gets a **"What should I scan?" hint**: it highlights surveys containing objects that boost the player's current bottleneck currency (the lowest ratio to next gate). This is a presentation-only helper.

### 9.8 Star Mapping (Rune Starring)

- The **Star Mapping Altar** (old `Workspace.Starring`). The player pays one family object (Zodiac→`Odyssey`/Pisces, Stellar Hues→`Vibrance`, Spectral→`Refraction`, Cosmic Web→`Subzero`/Dark Flow) to chart that family.
- Stages: **Charted I → Charted II → Charted III → Supercharted → Complete.** The known quirk (the state after stage 3 is labeled Superstar but grants Star3) is displayed honestly: the UI shows **the reward you will receive on the next purchase**, read from `runeStarring.data`, not the stage label.
- On Supercharted/Complete the family's objects are halved/zeroed. The confirm dialog must say so in red: *"Your Pisces will be consumed. Zodiac objects will be halved."*

---

## 10. Resets and Cinematics

**Universal rules (MUST):**
1. Each reset has a **confirm sheet** listing (a) what you gain, (b) **exactly what is reset**, generated from the `Resets` module's reset lists mapped through the Lexicon (not hand-written), and (c) what survives (e.g. KEEP16 Cosmology nodes).
2. The cinematic starts **after** the server confirms (a stat `.Changed`), plays client-side, and is skippable. The first view of each is unskippable for 1.5 s max.
3. Every cinematic has a Reduced Motion version (cross-fade + title card).

### 10.1 Epoch Advance (`Tier`), described in §7

### 10.2 SUPERNOVA (`AscensionOne`, one-time)

- **Trigger:** `Energy > 1e2283`, one-time. Pad: the old `Map.Ascension1` becomes the **Supernova Trigger**, a pylon under the Starlight Core that only rises from the floor when the requirement is ≥ 90% (log scale).
- **Resets (from `Ascensions`):** Epoch, Cosmology nodes except KEEP16, Cosmic Points + Research, every Discovery with chance ≥ 1e-8, Prisms, Epoch, Astronomy XP, Observer Level, Furthest Epoch, Trials C1–C4.
- **Gains:** Cosmic Dust generation, Spectral survey, ×10 Cosmic Points, ×3 Prisms, ×5e4 Orbs, Realm I luck ×2 and bulk +10 (display these as a "Supernova Legacy" card).
- **Storyboard (12 s, first view; 3 s replay variant not needed since it's one-time):**
  1. 0–2 s: the map starts shaking (camera noise, amplitude ramps). All orbiting objects accelerate. Music drops out.
  2. 2–4 s: the Starlight Core **collapses**: it shrinks to a white point, and every platform's light is dragged inward along the beams.
  3. 4–5 s: silence. The screen tints to white over 1 s.
  4. 5–5.3 s: **BOOM**. Full white, a sub-bass hit, a shock ring expanding in the white.
  5. 5.3–9 s: fade from white into **empty space**: a new sector with no platforms, a faint new mote where the Core was, and ghosted outlines of the old platforms dissolving outward.
  6. 9–12 s: the title card **"SUPERNOVA · COSMIC EVOLUTION UNLOCKED"**, then the new Cosmic Dust swarm spirals onto the player. The platforms rebuild in fast motion (0.3 s each).
- **World delta after Supernova:** the Frontier gets **supernova remnant** dressing forever (a filamentary shell in the sky, drifting debris), and the Core base changes material to scorched stellar metal. Players can always tell who has gone Supernova (an overhead badge + a Dust swarm).

### 10.3 GRAVITATIONAL COLLAPSE I–IX (`Freeze1–9`)

- Each is a one-level upgrade bought with Cosmic Dust, gated by Epoch 11/12/13. **Resets** (from `Resets.Freeze`): the Epoch-reset set (minus the >10 branch) + Prisms, Cosmic Dust, Frozen Matter, Nebula Gas, all Dust upgrades, Cosmology except KEEP16, Dark Matter. The Epoch is not touched.
- The **Collapse Monument** in the Expanse holds a single central object that **changes each level**:

| Level | Object | Visual | Cost (Cosmic Dust) | Gate |
|---|---|---|---|---|
| I | **Dense Star** | a star visibly compresses 20% | 1e19 | Epoch 11 |
| II | **White Dwarf** | tiny white star, hard halo | 2.5e34 | Epoch 11 |
| III | **Neutron Star** | 10-stud sphere, surface lightning, unlocks Deep Space | 5e51 | Epoch 11 |
| IV | **Pulsar** | twin beams sweep the Expanse (visible from anywhere) | 2.5e109 | Epoch 12 |
| V | **Magnetar** | visible magnetic field loops, starquake shakes | 7.5e136 | Epoch 12 |
| VI | **Black Hole** | event horizon + photon ring + accretion disk (§16.3 preset) | 2.5e185 | Epoch 12 |
| VII | **Supermassive Black Hole** | disk spans 200 studs; the Expanse skybox swirls toward it | 1e234 | Epoch 13 |
| VIII | **Singularity** | the disk vanishes; a point with lensing so strong the sky wraps | 5e278 | Epoch 13 |
| IX | **???** | a censored, glitching silhouette. *Note:* `Freeze9` price is `2` due to a typo (§19). The UI shows the real price the engine charges | "2" (bug) | Epoch 13 |

- **Collapse cinematic (4 s):** the monument object implodes to the new form, a pressure wave flattens nearby particles, and the title "COLLAPSE IV · PULSAR" appears.
- A second, older Freeze implementation exists in `ServerStorage.Modules.Freeze` (string-compare tiers, "NOT DONE" levels 8–9). The Architect must confirm which path is live before the monument binds to it. Bind to **`Upgrades.FreezeN.Value`** by default.

### 10.4 GALAXY FORMATION (`Chromatize`)

- **Requires** Galaxy Forge (`Prisms_Chromatizer`) and `Prisms > Chromatize_Cost`. Not deducted. 1 s cooldown. **Resets:** Cosmology except KEEP16 (Galaxy Forge re-set to 1), Prisms, Dark Matter, Astral Matter.
- The player sacrifices their current cosmic progression to grow a permanent **Galaxy Core**. It lives in a new sky layer above the Expanse and **is visible from both realms**.
- **Galaxy growth by Rank** (continuous, log-scaled):

| Rank | Galaxy | Notes |
|---|---|---|
| 1 | small irregular galaxy | Dark Matter unlocks; Research auto-buy |
| 2–10 | small spiral, arms tighten per rank | ×1e4 Cosmic Dust at 2; Dark Matter boosts |
| 10 | large spiral with bar | Chart ×2 |
| 100 | massive grand-design spiral + satellites | |
| 150+ | scan bulk bonus begins (+1%/rank, cap ×4.5) | |
| 750 | galaxy spawns a **companion**; Galactic Expedition unlocks | |
| 850 | Astral Token rate up | |
| 1000 | **galaxy cluster**; Astral Matter unlocks | cap display "/1M" as coded |

- **Cinematic (2.5 s, replay 0.8 s):** the Prisms stream from the player to the sky, the galaxy absorbs them, and the arms rotate one extra turn. A Rank number stamps on.
- ⚠ Cost is non-monotonic past rank 10 (§19). The UI shows the real next cost and **must not** show a "cost curve" graph that would expose the dip as a bug. Flag for the owner.

### 10.5 COSMIC TRIALS (`C1–C4`)

All four reset identically (Epoch reset + Cosmology except KEEP16 + Cosmic Points + Research + Prisms + Epoch 0). The restrictions live in Formulas. The mapping is by mechanic:

| Internal | Trial | Real restriction (unchanged) | Goal | Permanent reward (display) | World modifier (client-only visual) |
|---|---|---|---|---|---|
| `C1` | **Trial of Light** | Starlight gain ^0.425 (also Cosmic Points, Gravity) | reach Epoch 6 | Starlight ×1e12, Prisms ×2, Orbs ×1e6, Solar ×1e12 | **Overexposed**: everything blinding-bright, bloom maxed, detail washed out, "your light is drowned" |
| `C2` | **Trial of Entropy** | Discoveries dampened (^0.33) or skipped | reach Epoch 8 | ×20 to most currencies (display "Entropy Mastery ×20") | stars flicker, objects shed particles and slowly crumble, the Catalog shows static |
| `C3` | **Trial of the Void** | Solar Energy and Cosmic Points produce **0** | Starlight ≥ 1e393 | Starlight/Solar/Orbs ^1.1 | map almost black; only the Core and progression objects lit |
| `C4` | **Trial of Gravity** | almost everything ^0.5 | Starlight ≥ 1e96 | Prisms ×15 | heavy: planets orbit faster, particles curve toward the Core, lensing everywhere |

- The **Trial Gate** (old `Layers.Challenges`) is a ring with four portals. The active trial shows a persistent HUD ribbon: "TRIAL OF THE VOID · Solar Energy disabled · Goal 1e393 Starlight".

### 10.6 REALITY BREAK (`Chromify`) and REALITY ECHO (`Reflection`)

**Reality Break** (3 levels): requires the Reality Engine and `Chroma > Chromify_Cost` (1e23 / 7.5e36 / 1e78; level 3 is a wall). **Resets:** Cosmology except KEEP19, Galaxy Forge re-set, Prisms, Dark Matter, Astral Matter, Radiance, Reality Echo, Luminance + the Radiance/Echo upgrades.

- **Cinematic (6 s first, 2 s replay):** the map **fragments**. Platforms split along seams and rotate in impossible directions. The geometry duplicates (ghost copies offset), UI elements tear (EditableImage slice shader on a full-screen capture of a *prepared* UI layer), and everything collapses to a line. Title: **"REALITY HAS BEEN BREACHED"**. Breach 1 unlocks the Radiance Beacon, Breach 2 the Convergence Beacon, Breach 3 the Echo pad.
- **World delta:** Sector V (§11.4) appears: white stars, energy ribbons, geometric constellations and floating mathematical structures.

**Reality Echo** (repeatable): requires Breach ≥ 3 and `Radiance > 1e20`. **Resets:** Cosmology except KEEP19, Galaxy Forge re-set, Dark Matter, Astral Matter, Radiance, Radiance upgrades.

- Each Echo writes a snapshot to `Stats.EchoHistory` (additive key, §4.6): `{rank = Chromatize, breach = Chromify, t = os.time(), hue = hash}`.
- **Sky memory:** each snapshot renders a **ghost galaxy** in the sky (a translucent, desaturated copy of the player's Galaxy Core at that rank), placed on a slow orbit ring. After 16 echoes the oldest ones merge into a faint band. *The sky contains your history.*
- **Echo cinematic (3 s):** the current galaxy detaches a translucent copy that drifts up to its place in the ring.

### 10.7 STELLAR SHARDS (`Icicles`)

- Requires Epoch 13, `Frozen Matter > 1e17`, 5 s CD. Gain = `Icicles(P, log10(Ice/1e17)^5)`. **Resets** Cosmic Dust, Nebula Gas, Frozen Matter.
- **The Shatter Star:** a giant frozen star above the Absolute Zero Chamber. On SHATTER it **cracks** and shards fall. The shard count visual is logarithmic (≤ 60 meshes), and shards collect into a floating **Shard Crown** around the chamber that grows with total Stellar Shards.
- The board shows the (display-only, "TODO"-marked) boost list correctly, fixing the `I+2` display bug **in presentation only**: show `(Shards + 1)` as the engine computes it.

---

## 11. World

### 11.1 World pillars

1. **Everything you own is visible in the world.** No currency exists only as a number.
2. **The center tells your progress.** The Cosmic Core (Realm I) and Galaxy Core (Realm II/sky) state = your Epoch/Rank.
3. **Look up to see your future.** Locked systems are visible as dormant silhouettes, in the sky or on distant platforms.
4. **Readable at a glance.** One hero object per platform, clear silhouettes, a consistent light language (warm = Realm I currencies, cold = Realm II, violet = Dark, white = Reality).

### 11.2 Realm I · The Stellar Frontier (replaces Spawn Island + central Layers)

```
                               [ GALACTIC EXPEDITION SUMMIT ]  (locked monument, visible from spawn)
                                             |
            [ TELESCOPE BAYS 4–6 ]     [ COSMOLOGY ISLE ]      [ HALL OF OBSERVERS ]
                         \                   |                     /
   [ ORB OBSERVATORY ] — [ RESEARCH ARRAY ] — [ THE OBSERVATORY ] — [ STELLAR FORGE ] — [ GRAVITY WELL ]
                         /             (Starlight Core ·            \
            [ TELESCOPE BAYS 1–3 ]      Epoch Engine ·        [ ANOMALY CONTAINMENT RING ]
                         \               Supernova Trigger)        /
      [ CUBE FUSION BAY ] — [ PLANETARIUM ] — [ TRIAL GATE ] — [ PARTICLE ACCELERATOR (rim) ]
                                             |
                                   [ SPAWN: arrival pad ]
                                             |
                                    [ WARP GATE → Realm II ]
```

- **The Observatory:** a circular platform, 140-stud radius, three terraces. The Starlight Core is at its center (the Cosmic Core in Realm I). The Epoch Engine pad and board are at the Core's base. The spawn arrival pad sits 60 studs south, facing the Core.
- **8 orbital platforms** (radius 230–320 studs, heights varied ±20) connected by light-bridges. Each hosts one system (§8). Unlock order goes **clockwise from spawn** so the path of progress is literally a loop around the Core: Forge (E1) → Research (E1) → Bays 1–2 (E1) → Gravity Well (E2) → Bay 3 (E3) → Anomaly Ring (E4) → Bay 4 (E6) → Orb Observatory (E7) → Cube Fusion (E8) → Planetarium + Bay 5 (E9) → Accelerator rim.
- Platforms that are **locked** are present but dark, with a hologram showing the unlock Epoch. They're unlit and their bridges retracted. (The existing `Toggle()` re-parent to `Layers_Storage` must be replaced by a presenter-driven "dormant" state. The **stand-on pad** stays re-parented/disabled so automation logic is unchanged.)
- **Dressing:** floating asteroids (instanced, 3 LODs), broken satellites, antennas, energy conduits between platforms (Beams, pulse-scrolling), distant planets on the horizon, a giant ring structure overhead, and a slow drift of cosmic dust in the air. No trees, grass, logs or mushrooms.
- **Floor language:** dark observatory metal with thin luminous inlay lines that run *from the Core to each platform* and light up as systems unlock. This is the most important piece of wayfinding.

### 11.3 Navigation and wayfinding

- **Next Objective beacon:** a subtle vertical light shaft over the platform that holds the player's next affordable/meaningful action, computed client-side from the next gate (Epoch cost vs current, cheapest affordable upgrade on the most-boosting board). Toggle in settings.
- **Cosmic elevators** for vertical moves between terraces. **Jump rings** (a launch pad plus an arc trail) between platforms. Walkspeed is formula-driven (`Formulas.Walkspeed`), so we add **no movement buffs**. Jump rings are the fast path.
- The **Warp Gate** (old `Teleporter` with `TeleportPads`/`TeleportHandler`/`realm_Two`) opens at `Energy > 1e3003` (as coded, ~10.7 h) or with the Expanse Warp License. The warp cinematic is a 2 s hyperspace tunnel.
- **Minimap-free design:** the Core is always visible (tall light column), the Summit is always visible, and platform landmarks have unique silhouettes.

### 11.4 Realm II · The Galactic Expanse and Sectors III–VI

Only two physical realms exist in code (`Realm = "One"/"Two"`). Sectors III–VI are **regions within Realm II** (the old `Areas.Arctic`), revealed client-side by the stat gates below. No new realm logic.

| Sector | Name | Reveal gate (display only) | Hosts (old Arctic folders) | Mood |
|---|---|---|---|---|
| II | **The Galactic Expanse** | arrival | Nebula Engine (`WaterButtons`), Absolute Zero Chamber (`Ice`, `IceButtons`), Cryo Reactor (`Cryo`, Arctic Points layer), Dust Board, Stats Board, Observation Streak (`PlaytimeRwards`), Chart Terminal II, Warp Gate, Collapse Monument (`Freeze`) | galaxies everywhere, cold blue-violet, dense nebula |
| III | **The Void** | Galaxy Rank ≥ 1 | Galaxy Forge (`Chromatizer`), Dark Matter systems, Cosmology Outer Ring (`TalentTree2`, `Upgrade Tree Island 2`), Cosmic Web bay, Meteor Shower Beacon (`Hail`), Solar Wind Beacon (`Haze`), `Caps` | almost dark; objects lit only by their own emission |
| IV | **The Primordial Universe** | Galaxy Rank ≥ 1000 | Astral Beacon (`Chroma`), Astral Matter Cosmology, Galactic Expedition second approach | everything *forming*: protostars, hot gas, flashes |
| V | **The Collapsed Realm** | Breach ≥ 1 | Reality Engine (`Chromifier`), Radiance Beacon (`Light`), Convergence Beacon (`Ascended`), Luminance Beacon (`Shine`) | broken physics, floating math structures, white light ribbons |
| VI | **The Paracosm** | Breach ≥ 3 | Echo pad (`Reflection`), echo sky ring | several universes overlap; mirrored geometry |

Shatter Star (`Icicles`) sits between II and III.

### 11.5 Cosmic Core state machine (hub centerpiece)

Realm I Core state = `f(Epoch, AscensionOne)` (§7 column). Realm II hub centerpiece = **Galaxy Core** state = `f(Chromatize, Chromify, EchoCount)`: galaxy (Rank) → cluster (1000) → cluster wrapped in fractures (Breach 1–2) → multiple universes (Breach 3) → ghost ring (Echoes). The Core is **one presenter** with pooled layers. Transitions are 1.2 s morphs, never pops.

### 11.6 Hall of Observers

The old HallOfFame pillars and statue become an observatory gallery. Leaderboards (`TotalEnergy` → **Lifetime Starlight**, `CurrentPrisms` → **Prisms**, `Playtime` → **Observation Time**, `RunesOpened` → **Objects Discovered**, `RobuxSpent` → **Patrons**, `Contributors` → **Crew**) are holo-tables. The top 3 per board get a small star named after them in the Hall's ceiling dome.

---

## 12. The Cosmology (talent tree)

### 12.1 What exists

- Talent upgrades live in `Libraries.Upgrades.Talent` (≈110 modules), paid in **Prisms, Dark Matter, Astral Matter, Radiance, or Astral Tokens**. Purchase happens by **standing on physical talent pads** (tag `TalentUpgrade`, in `Workspace.Layers.TalentTree.Talents` and Arctic `TalentTree2`) and via the `Buy_Upgrade` remote.
- KEEP16 / KEEP19 nodes survive resets.

### 12.2 The new presentation: a 3D holographic star map

- **Cosmology Isle** keeps the physical pads (automation and stand-on buying keep working), restyled as **node plinths** in a star-map constellation layout on the ground. Each plinth projects its node's celestial object above it.
- The **Cosmology Viewer** is a full-screen UI star map opened from the Isle or HUD. It fires the existing `Buy_Upgrade` for the node. **Verify with the Architect that `Buy_Upgrade` accepts Talent upgrades and runs `HasRequirement` server-side** before exposing remote buying.
- **Zoom levels** (semantic zoom, not just scale): Universe (currency regions) → Galaxy (branch) → Star System (cluster of nodes) → Star (single node detail) → Planet/Civilization/Particle (flavor art only at the deepest zoom for hero nodes).
- **Regions by currency:**

| Region | Currency | Theme | Node object style |
|---|---|---|---|
| Stellar Core | Prisms (≈45 `Prisms_*`) | Realm I automation and multipliers | stars and planets |
| Dark Sector | Dark Matter (≈35 `Chromium_*` paid in Chromium) | Realm II / Collapse synergies | dark stars, halos |
| Astral Reach | Astral Matter (≈45 Chroma-paid) | endgame | crystals, galaxies |
| Radiant Spire | Radiance (2 nodes) | Reality | white geometric forms |
| Patron Ring | Astral Tokens (≈16 RT-paid) | scan speed / bulk | gold rings |

- **Edges** are drawn from each node's `HasRequirement` (upgrade dependencies parsed from the requirement expressions in the balance sheet), and visually as constellation lines. Stat gates (Epoch/Rank/rune counts) show as a lock glyph with the display condition.
- **Anchored** badge on KEEP16/KEEP19 nodes: *"Survives resets."*
- Illustrative spine (from the proposal):

```
                 DARK MATTER
                     |
              GALAXY FORMATION
                /           \
          GRAVITY          RADIANCE
             |                |
          STARS            LIGHT
             \                /
                STELLAR CORE
                     |
                  STARLIGHT
```

### 12.3 Node states

Undiscovered (requirement unmet, silhouette) · Discoverable (requirement met, can't afford: dim pulse) · Affordable (bright pulse + price in currency color) · Owned partial (orbit pips = level / max) · Maxed (full ring, steady glow) · Anchored (gold rim).

---

## 13. Sky, Lighting and Atmosphere

### 13.1 The sky is a progression system

The sky is not a static Skybox. It is layered:

| Layer | Tech | Driven by |
|---|---|---|
| L0 base | `Sky` 6-face cubemap per zone (authored, 1024²) | Realm / Sector |
| L1 star density | large inverted sphere mesh with an EditableImage star layer (1024×512 equirect, regenerated only on state change) | Epoch (Realm I) / Rank (Realm II) |
| L2 nebula | 2–4 billboard quads with shared nebula EditableImages (512²), slow UV scroll | Nebula Gas, Epoch ≥ 7 |
| L3 galaxies | instanced galaxy billboards (atlas) | Epoch ≥ 8, Galaxy Rank |
| L4 pack regions | per-survey painted regions the telescopes point at | pack unlocks |
| L5 events | meteor showers, pulsar beams, supernova remnant, Galaxy Core, Echo ghost ring | beacons, Collapse, Supernova, Echo |
| L6 fracture | screen-space cracks and duplicated sky slices | Breach |

**Progression target:** Epoch 0 = a few stars → E3 more stars → E7 nebula → E8 a galaxy → E9–10 clusters → Supernova remnant → Expanse: galaxies everywhere → Void: darkness → Primordial: forming → Collapsed: fractured → Paracosm: multiple universes floating around the player.

### 13.2 Lighting profiles (per zone)

| Zone | ClockTime / Ambient | Atmosphere | Bloom | ColorCorrection | Notes |
|---|---|---|---|---|---|
| Frontier | night, ambient 25,22,35 | density 0.2, warm haze | 1.1 / 0.95 thresh | +0.05 sat, warm tint | the Core is the key light |
| Expanse | night, ambient 20,25,40 | cool, density 0.3 | 1.0 | cool tint | nebula fill |
| Void | ambient 5,5,8 | density 0.05 | 1.4 | contrast +0.15 | emissives only |
| Primordial | ambient 35,20,20 | hot haze | 1.3 | warm, sat +0.1 | flashes |
| Collapsed | ambient 60,60,70 | clear | 1.6 | desat −0.3, bright | white world |
| Paracosm | ambient 30,25,45 | iridescent | 1.2 | hue drift ±5° | mirrored |
| Trial overrides | §10.5 | | | | tweened in 1.5 s |

Profiles blend on zone boundary (trigger volumes, 2 s tween). Use `Lighting.Technology = Future` on High, and ShadowMap on Med/Low. The Graphics tier setting (§17) switches this.

---

## 14. UI System — "Observatory Instrumentation"

### 14.1 Design language

**Scientific observatory equipment, not a mobile game.** Hard edges. Layered panels. Thin luminous lines (1–2 px). Technical labels in small caps. Orbital diagrams as decoration. Tiny metadata ("SEC-II · RA 14h 29m · Δ+3.2%"). Progress bars shaped like instruments: arc gauges, spectrum strips, oscilloscope traces.

**Banned:** default rounded Roblox buttons, big `UICorner` pills, cartoon drop shadows, rainbow gradients on everything, emoji, stock icon packs, Comic/Cartoon fonts. (The current UI uses 1,151 `UICorner`s and 6,062 `UIGradient`s, so it is replaced, not restyled.)

**Sub-themes** (same grammar, different accent): Observatory (default, brass + cyan), Stellar (gold/orange), Nebula (magenta/teal), Void (violet on near-black), Astral (black crystal + spectral rim), Reality (inverted white).

### 14.2 Tokens (`Theme` module)

```
color.bg.0        #05060B   deep space
color.bg.1        #0B0E18   panel
color.bg.2        #121828   raised
color.line        #2A3350   hairline
color.line.hot    #7FE3FF   luminous line
color.text.hi     #EAF2FF
color.text.mid    #9AA7C7
color.text.low    #5B6685
color.brass       #C9A45C   observatory accent
currency tokens:  starlight #FFE7A3 · solar #FF9A3C · gravity #9B6BFF · cosmic #4FE3FF · charts #8FD3FF
                  biomass #3CF2B5 · impact #FFFFFF · orbs #B7C8FF · cubes #A9B4C8 · planets #5FB0FF
                  prisms #F7B2FF · dust #E8D9FF · nebula #FF5FD2 · frozen #BDEBFF · cryo #9FF0FF
                  shards #D8F6FF · darkmatter #6B2BD9 · astral #1A1030(+spectral rim) · radiance #FFFFFF
                  echo #C8C8FF@60% · wind #FFD27A · meteor #FFB38A · salvage #9CA3AF · luminance #FFF6C2
                  tokens #E3B34A
rarity tokens:    §9.4
radius:           0 (panels) · 2 (chips) · never > 4
stroke:           1 px hairline · 2 px emphasis
spacing scale:    4 · 8 · 12 · 16 · 24 · 32
```

Every currency color was chosen to be distinguishable under deuteranopia **with its icon** (the icon shape carries identity, not only the color). The Mobile QA agent verifies this with a simulator filter.

### 14.3 Typography

Display/headers: a technical wide face (e.g. **Michroma** or **Sarpanch**). Body: **Titillium Web / Jura / Builder Sans**. Numbers: a monospaced face (**Roboto Mono**) so counters don't jitter. *The UI/UX Director confirms the final choices against the Studio font picker.* Numbers go through the existing `EN.Format` (suffix/scientific rules unchanged) and use tabular alignment.

### 14.4 HUD layout

```
┌──────────────────────────────────────────────────────────────────────────┐
│ EPOCH 7 · NEBULA ▸▸▸▸▸▸▱▱▱ 64%  (log bar to next Epoch)   [⚙] [★ Catalog] │
│                                                                          │
│   STARLIGHT   2.41e152   (+3.9e150/s)   ← hero readout, starfield digits │
│   ☉ Solar 1.2e40   ◉ Gravity 8.8e33   ⌬ Cosmic 3.1e21   ▦ Charts 4.4e9   │  ← secondary strip, contextual
│                                                                          │
│                                                     [ Discovery toasts ] │
│                                                                          │
│ [NEXT: Advance Epoch — 1e153 Starlight · 4m est.]            [Store][…]  │
└──────────────────────────────────────────────────────────────────────────┘
```

- The **secondary strip is contextual**: it shows the 4–6 currencies relevant to the player's current Epoch/Realm, and the rest are one tap away in the **Ledger** (full currency panel).
- The **Epoch bar** replaces `TierBar/TierBar2/TierBar3` (they share `Tier_Cost` log progress: Starlight pre-E10, Cosmic Dust E10+, Astral Matter bar for Breach). One component with three data sources.
- **Next action** chip (the same logic as the world beacon, §11.3).

### 14.5 Screen inventory (every ScreenGui to rebuild)

| Old | New | Notes |
|---|---|---|
| HUD / `Stats` UI | **HUD + Ledger** | §14.4 |
| `TierBar`, `TierBar2`, `TierBar3` | **Epoch Gauge** | one component |
| `Index` | **Star Catalog** | §9.7 |
| `RunePopup` (+ `Stat Popup`, `Random Stat Popup`) | **Discovery Toasts / Reveal** | §9.2 |
| Rune pack UIs (`UI.Runes.Holder.*` ×13) | **Survey Panels** | one template, per-pack theme |
| `RuneStarring` | **Star Mapping** | §9.8 |
| `AscensionOne` | **Supernova Sheet + Cinematic** | §10.2 |
| `Teleporter` | **Warp Console** | |
| `Store` (+Buttons, Codes, Donations, Elixirs, Gamepasses, Gifting, Products, RTokens, Runes, Stats, Tickets) | **Supply Depot** (tabs: Passes, Catalysts, Astral Tokens, Charts, Gifts, Patronage, Transmission Codes) | product/gamepass IDs unchanged |
| `Options` | **Settings** (+ Graphics tier, Skip cinematics, Reduced motion, Toast thresholds, Hide others' dust) | |
| `Profile` | **Observer Profile** | Level, Furthest Epoch, Rank, Breach, Echoes, discovery stats |
| `FollowRewards` | **Crew Bonus** | |
| `LoadingScreen` | **Loading flight** | camera flies asteroid field → nebula → galaxy → black hole. Pre-rendered layers, ≤ 6 s, skippable once loaded |
| `UpdateLog` | **Transmission Log** | |
| `CurrentEvent` | **Cosmic Event** banner | |
| `Shutdown` / Soft Shutdown | **Relocation notice** | |
| `GreyFrame` | modal scrim | |
| Challenges UI | **Trial Gate panel** | |
| Talent Tree client | **Cosmology Viewer** | §12 |
| Boards (SurfaceGuis ×292, BillboardGuis ×150) | **World Holo-Panels** | one templating system, §14.6 |

### 14.6 World holo-panels (boards)

- One `HoloPanel` component renders all SurfaceGui boards: a header (system name + glyph), a primary readout, a list of "×N <Target>" effect lines (from the Lexicon), and a footer (next unlock).
- `PixelsPerStud` is standardized at 50 for boards within 60 studs and 25 beyond. `LightInfluence = 0`, with an emissive feel via `Brightness 1.5` on High.
- Animated backgrounds use a **shared** EditableImage per theme (not one per board; §16.2).

### 14.7 Input and platform

- **PC:** hover states, keyboard shortcuts (C Catalog, T Cosmology, L Ledger, Esc close).
- **Controller:** full focus navigation (`GuiService.SelectedObject`), bumpers switch tabs, the Cosmology star map pans with the sticks.
- **Touch:** 44 px minimum targets, bottom-reachable primary actions, no hover-only info (long-press = tooltip).
- **Safe areas:** respect `ScreenInsets` (notches, the Roblox top bar).
- **Target resolutions** (Mobile QA): 1334×750, 1792×828, 2436×1125, 2048×1536 (iPad 4:3), 1920×1080, 2560×1440, 3440×1440 (ultrawide).

### 14.8 Accessibility

Reduced Motion (no shake, no flashes > 3 Hz, cross-fades), colorblind-safe token pairs + icons, text scale option (100/115/130%), subtitle-style captions on cinematics, and an option to disable screen-space distortion.

---

## 15. Art Pipeline

### 15.1 Ownership

| Stage | Tool | Owner agent |
|---|---|---|
| Concept / moodboards / UI | Figma (Claude Design) | Cosmic Design Director, UI/UX Director |
| Materials | Substance 3D (Designer for graphs, Painter for hero props) | Substance Material Director |
| Meshes | Blender | Blender Asset Director |
| Runtime procedural | EditableMesh / EditableImage | EditableMesh / EditableImage Engineers |
| Import / placement | Roblox Studio (+ Studio MCP) | World Builder |

### 15.2 Blender asset library (required families)

| Family | Assets | Tri budget (LOD0/1/2) |
|---|---|---|
| Stars | dwarf, giant, red giant, blue giant, neutron, pulsar shells | procedural preferred; shell meshes ≤ 2k |
| Planets | rocky, gas, ice, lava, ocean, alien (base spheres + ring meshes) | 2k / 800 / 200 |
| Cosmic structures | asteroid set (12 variants), asteroid belt segment, nebula card set, wormhole throat, black-hole disk, galaxy disk, cluster | asteroids 600/200/60 |
| Architecture | Observatory platform kit (floor tiles, terraces, railings, pylons), space station modules, telescopes ×9 (one per survey), reactor, Stellar Forge ring, Gravity Well pedestal, Research Array rings, cosmic elevator, warp gate, collapse monument plinth, Anomaly ring fence, Planetarium dome, Cube Fusion conveyor | hero ≤ 20k, kit pieces ≤ 3k |
| Props | satellites, antennas, consoles, energy conduits, holo-projector bases, floating panels, cable runs | ≤ 1.5k |
| Anomalies | 8 creatures (§5.8), rigged (≤ 40 bones), 2 anims each (idle, hurt, death) | ≤ 12k |

**Naming:** `GI_<Family>_<Asset>_<Variant>_LOD<n>` (e.g. `GI_Arch_Telescope_Nebula_LOD0`). **Units:** 1 Blender unit = 1 stud; apply transforms; +Y up on export (FBX, Roblox preset). **Pivot:** base center for architecture, geometric center for celestial bodies.

### 15.3 Substance material families

Stellar (plasma, emissive star, scorched, molten) · Cosmic (nebula metal, cosmic stone, dark-matter crystal, astral glass) · Technology (observatory metal, brushed titanium, dark alloy, holographic glass) · Ancient (cosmic ruins, fractured stone, celestial crystal).

- Export **PBR metal/rough** at 1024² (hero) / 512² (kit) / 256² (props), as `SurfaceAppearance` (Color, Normal, Metalness, Roughness). Trim sheets for architecture (one 2048×1024 trim per family) so the kit shares textures.
- Also publish **MaterialVariants** (tiling) for large surfaces: `GI_ObservatoryMetal`, `GI_CosmicStone`, `GI_DarkAlloy`, `GI_ScorchedStellar`. They replace `Matte/Reflective/Reflective2`.
- Emission: Roblox has no emissive PBR map. Fake glow with Neon inlay parts, `SurfaceAppearance.Color` brightness plus bloom, and ParticleEmitters/Beams. Don't bake "glow" into albedo.

### 15.4 Import checklist (MUST per asset)

Correct scale · collision fidelity set (`Box`/`Hull`, never `Default` on decorative meshes) · `CanCollide/CanQuery/CanTouch` off on decoration · `CastShadow` off on small props · LOD via `RenderFidelity = Automatic` or manual swap · textures ≤ budget · named per convention · placed in the correct `Workspace` folder with tags preserved for gameplay pads.

---

## 16. Rendering Tech: EditableImage and EditableMesh

> Both APIs are available in published experiences (client beta since Jan 2025) and are **memory-budgeted per device**. Creation can fail when the budget is hit. **Every call site MUST handle failure and fall back** to a static asset. Re-check the current API surface and permission requirements in the Roblox docs at project start (the Architect owns this).

### 16.1 Core rules

1. **Create few, reuse many.** Shared images are referenced by many surfaces through `Content.fromObject(editableImage)`.
2. **Update selectively.** Only dirty regions (`WritePixelsBuffer` on sub-rects), at ≤ 15 Hz for ambient effects, ≤ 30 Hz for hero effects, **0 Hz when off-screen/out of range**.
3. **Pool everything.** No create/destroy per event.
4. **Degrade gracefully.** Graphics tier Low = zero runtime EditableImages except the HUD hero readout; static textures everywhere else.
5. **Fixed-size meshes** for anything long-lived (clone a fixed-size EditableMesh after authoring) to reduce budget reservation.

### 16.2 Shared EditableImage registry (`CosmicImages`)

| Key | Size | Rate | Used by |
|---|---|---|---|
| `starfield.hud` | 512×128 | 15 Hz | Starlight digits mask, currency cards |
| `starfield.full` | 1024×512 | on demand | Discovery Reveal, Supernova, loading |
| `corona.solar` | 256×256 | 15 Hz | Stellar Forge, star presets |
| `nebula.a/b` | 512×512 | 5 Hz | sky L2, Nebula Engine, nebula presets |
| `lens.dark` | 256×256 | 10 Hz | Dark Matter visuals |
| `galaxy.flip` | 256×256 × 8 frames | 12 fps | Astral Matter crystal, Galaxy Core |
| `holo.panel.<theme>` | 256×256 | 10 Hz | board backgrounds (one per sub-theme) |
| `frost.mask` | 512×512 | on change | Frozen Matter frost spread |
| `scan.feed.<bay>` | 512×128 | 10 Hz, only nearest bay | Scan Feed |
| `sky.stars` | 1024×512 | on state change | sky L1 |

**Hard caps (default, Performance Engineer tunes):** ≤ 12 live EditableImages on High, ≤ 6 on Med, ≤ 1 on Low. Total ≤ 16 MB image memory on High.

### 16.3 `CosmicObjectRenderer` (EditableMesh + presets)

One reusable module generates every celestial object from a descriptor:

```lua
CosmicObjectRenderer.spawn({
    Preset   = "Galaxy",        -- Star | Planet | Moon | Asteroid | Comet | Nebula | Galaxy | Cluster
                                -- | BlackHole | Pulsar | Wormhole | Portal | Crystal | Constellation | Anomaly
    Rarity   = "Mythic",        -- drives rim, particles, aura intensity
    Scale    = 4.5,
    Seed     = 918273,          -- deterministic look (hash of internal rune name)
    Palette  = "nebula",        -- theme token
    Rotation = "dynamic",       -- static | dynamic | tidal
    Aura     = "Void",          -- None | Solar | Void | Astral | Radiant | Echo
    Particles= 3,               -- emitter count (pooled)
    Orbiters = 7,               -- satellites (instanced)
    Target   = viewportFrame or worldCFrame,
    LOD      = "auto",
}) -> handle (handle:SetState(...), handle:Release())
```

- **Geometry:** icosphere generator (subdiv 1–4), ring/annulus, spiral-disk (galaxy arms as a vertex-colored triangle fan with arm density function), billboard clusters, noise displacement (seeded), vertex colors from palette.
- **Every one of the 134 discoveries maps to a preset + seed + palette** (the "Object form" column in §5.5 is the brief). Hero objects (Hyperion, Paracosm, Heat Death, Event Horizon, Kilonova, Polaris…) may get a bespoke Blender mesh on top.
- **Output modes:** `Viewport` (UI previews; renders once, then caches a snapshot where possible), `World` (MeshPart via `AssetService:CreateMeshPartAsync(Content.fromObject(mesh))`).
- **Caps:** ≤ 20 live runtime meshes on High, 10 on Med, 4 on Low. Faces per mesh ≤ 5k (heroes ≤ 20k).

### 16.4 Thumbnails

The Star Catalog and toasts use **pre-baked thumbnails** (rendered offline in Studio from the renderer, uploaded as images, 256²). The live renderer is used only for the focused item. This single decision keeps the Catalog cheap on mobile.

### 16.5 Screen-space effects

Shake (camera offset noise), flash (full-screen frame), lensing overlay (EditableImage with a radial warp of a *prepared* texture), glitch slices (UI layer offset strips), white-out. There's no framebuffer access in Roblox, so every "distortion" works on prepared content, never live pixels.

---

## 17. Performance Budgets (enforced per milestone)

| Metric | Low (mobile) | Med | High (PC) |
|---|---|---|---|
| Frame time (client, hub, 10 players) | ≤ 33 ms (30 fps) | ≤ 22 ms | ≤ 16.6 ms |
| Client memory | ≤ 1.2 GB | ≤ 1.8 GB | ≤ 2.5 GB |
| Live EditableImages | 1 | 6 | 12 |
| Live runtime EditableMeshes | 4 | 10 | 20 |
| Particle emitters active in view | 20 | 45 | 80 |
| Draw calls (hub) | ≤ 900 | ≤ 1600 | ≤ 2500 |
| Instances in Workspace (streamed-in) | ≤ 12k | ≤ 18k | ≤ 25k |
| Presenter Lua time / frame | ≤ 1.5 ms | ≤ 2.5 ms | ≤ 3.5 ms |
| Network: presentation-originated remotes | **0** (presentation is read-only) | | |

- Turn on **StreamingEnabled** with the Observatory + current platform as persistent/atomic models. Pads needed by automation must be streamed or server-side, so the Architect verifies that the stand-on raycasts (15 studs down, server) are unaffected.
- The `Graphics tier = Auto` picks from device memory and the `UserGameSettings.SavedQualityLevel` heuristic.
- The existing heavy loops (1/60 s automation, Droplets ×multiplier bug, `UserOwnsGamePassAsync` every 0.5 s) are **server-side and frozen**. Their cost is measured and reported, not changed without sign-off (§19).

---

## 18. Audio

| Cue | Replaces | Direction |
|---|---|---|
| UI hover / click | `Hover`, `Click` | soft instrument ticks, glassy |
| Purchase / upgrade | `Purchase`, `Upgrade` | brass-and-glass chime, pitch rises with level |
| Stellar Forge ignite | `Flame` | whoosh + plasma crackle |
| Gravity Well compress | `Power` | downward pitch bend + sub thump |
| Research | `Realm Points` | data-chirp arpeggio |
| Epoch advance | `Tier` | rising 3-note motif, a variation per Epoch |
| Collapse | `Freeze` module | implosion + pressure hiss |
| Discovery bands | — | §9.4 ladder |
| Supernova | — | silence → sub-bass boom → choir swell |
| Reality Break | — | tape-stop + glitch granular |

**Music:** adaptive layers per zone (Frontier ambient-synth, Expanse orchestral pads, Void near-silence drones, Primordial pulsing, Collapsed sparse piano with reverse FX, Paracosm layered/mirrored). Stems cross-fade on zone change. `Volume Control` keeps its sliders (Music / SFX / UI). All audio is licensed or original, uploaded to the group, and has attribution tracked in `/docs/galaxy-incremental/audio-credits.md` (to be created).

---

## 19. Known Bugs: Policy

These exist in the live balance (balance sheet §"Known bugs"). **Default: do not fix.** Each needs an explicit owner decision because fixing changes live progression. Presentation must display **what the engine actually does**.

| Bug | Presentation rule | Owner decision |
|---|---|---|
| `Freeze9` price `2,5e313` → costs 2 | show "2 Cosmic Dust" (truth). Optionally style the monument IX as "anomalous" | ☐ fix ☐ keep |
| Wrong rune passed (`Earthvein_Energy`→Oak, `Thunderstorm_Flesh`→Vibrance, `Omniscient/Almighty_Droplets`→Frostveil, `Primordial_ChestChance`→Prosperity) | Catalog "boosts" lines show the **effective** source (e.g. "Planetary Nebula's Starlight bonus scales with your Dust Clouds") | ☐ fix ☐ keep |
| `Prisms_Orbs1` evaluated at `Prisms_Orbs2` level | tooltip shows the effective value | ☐ |
| Arctic Points Epoch bonus never applied | don't display it | ☐ |
| `Draco_Follow` missing `.Value` (always ×1.25) | show the Crew bonus as always active if the stat exists | ☐ |
| `Rune_Clone` always returns 2 | Echo Scan shows "active" for everyone | ☐ |
| Chromatize cost non-monotonic past 10 | show the real next cost only | ☐ |
| `Additive_Scale` unread; `Base_Effect` only added when `Effect_Scale ≤ 1` | tooltips compute via the engine's `GetEffect`, never re-derive | ☐ |
| Droplets loop multiplies the whole balance every 0.5 s | smoothed counter | ☐ |
| `Rune:GetResult` called twice per open | show actual deltas | ☐ |
| Global Goals never starts | hide any Global Goals UI | ☐ enable ☐ keep off |
| `WaterAuto` CD capped at 1 s | show real rate | ☐ |
| Special pools' non-cumulative thresholds | show effective odds (§5.5) | ☐ |
| Freeze server module string-compares tiers and applies boosts on failed payment | confirm which Freeze path is live (§10.3) | ☐ |
| Icicles board `I+2` display | presentation shows the correct `(I+1)` | presentation-only fix ✅ |
| Buy-max with `Price_Scale == 0` returns a number | Ledger/board buy-max UI must not call that path for such upgrades | ☐ |
| Rune Clone with both product and upgrade but failed chance → ×1 | none | ☐ |
| `GetRuneTable` break entry has no RuneLuck/RuneClone flags | none | ☐ |

The balance sheet's two applied changes (rune payout swap; Epoch 11 cost 5e60→1e52) are considered **part of the frozen baseline**. Confirm with the owner that the target build includes them (§23).

---

## 20. Agent Structure

The project runs as a multi-agent pipeline. Agents validate **inside Studio** through the Roblox Studio MCP server (inspect/edit scripts, insert models, run Luau, drive Play mode), not just by generating files.

### 20.1 Roster

| # | Agent | Owns | Inputs | Outputs | Gate power |
|---|---|---|---|---|---|
| 1 | **System Architect** | protects mechanics; module boundaries (Lexicon, Theme, PresentationBus); approves any data/remote change | this spec, place file | architecture PRs, sign-offs | **blocks** any formula/data/remote diff |
| 2 | **Balance Auditor** | reads the whole balance sheet; checks progression, costs, unlocks, reset interactions, impossible states, dead currencies | balance sheet, sim | audit reports; diff-verification that frozen modules are byte-identical | **blocks** changes to frozen modules |
| 3 | **Cosmic Design Director** | the entire visual identity; Lexicon flavor text; moodboards | §5–13 | style bible, Lexicon content | approves identity |
| 4 | **World Builder** | platforms, structures, landmarks, navigation, pad placement with tags | §11, kit | Workspace builds | — |
| 5 | **Blender Asset Director** | 3D library (§15.2) | art briefs | FBX + source .blend | — |
| 6 | **Substance Material Director** | material library (§15.3) | briefs | .sbsar/.spp + exported maps, MaterialVariants | — |
| 7 | **EditableImage Engineer** | `CosmicImages`, dynamic textures, UI effects, sky layers | §16 | modules + perf reports | — |
| 8 | **EditableMesh Engineer** | `CosmicObjectRenderer`, anomalies' procedural parts, deformation | §16.3 | module + preset library | — |
| 9 | **UI/UX Director** | hierarchy, readability, PC/mobile/controller, accessibility | §14 | Figma + UI implementation | approves UX |
| 10 | **Motion Designer** | transitions, zooms, camera, currency animation, reset sequences | §7, §9.3, §10 | cinematic modules | — |
| 11 | **VFX Director** | particles, beams, explosions, gravity effects, stars, portals | §8–10 | VFX library | — |
| 12 | **Lighting Director** | atmosphere, contrast, focal points, per-zone profiles | §13 | Lighting profiles | — |
| 13 | **Performance Engineer** | memory, Editable counts, update frequency, replication, mobile perf, frame time | §17 | budget reports per milestone | **blocks** over-budget merges |
| 14 | **QA Agent** | fresh account, progression, reset, currency, save/load, UI, mobile, exploit tests | §22 | test reports | blocks on P0/P1 |
| 15 | **Playtest Agent** | plays through Studio MCP as a new player: *"If I knew nothing about this game, could I figure out what to do?"* | build | session logs with confusion points | — |
| 16 | **Visual QA Agent** | screenshots at checkpoints (§22.5); checks visual progression is obvious | build | screenshot sets + verdicts | — |
| 17 | **Economy QA** | detects useless currencies, no-effect upgrades, dead ends, runaway multipliers, unreachable content | balance sheet + telemetry | findings (report only, no fixes) | — |
| 18 | **Consistency Agent** | every name; no "Energy" anywhere (UI, icons, descriptions, boards, tooltips, chat, store) | Lexicon, place | lint reports (§22.3) | **blocks** on any legacy term |
| 19 | **Mobile QA** | 4:3, 16:9, small iPhone, large iPad, touch targets, overlap, performance | §14.7 | device matrix report | blocks on P0 |
| 20 | **Final Art Director** | last gate: *"Does this look like a premium Roblox game?"* Rejects default-Roblox, generic simulator, AI slop, mobile-game UI, empty baseplate, random asset pack | everything | pass / send-back list | **final veto** |

### 20.2 Workflow

1. **Ticket** (one system or zone) → Architect confirms touch points.
2. **Build** (owning agents) on a branch.
3. **Automatic gates:** frozen-module hash check (Balance Auditor), Lexicon lint (Consistency), perf capture (Performance).
4. **Play gates:** QA scripted runs + Playtest session + Visual QA screenshots.
5. **Art gate:** Final Art Director.
6. Merge.

### 20.3 Frozen-module hash check

Maintain `docs/galaxy-incremental/frozen-manifest.json` (to be created in M0): SHA-256 of each frozen script's `Source` (Formulas, RuneFormulas, RuneInfo, Resets, Cooldowns, Automations, Upgrades engine + all 248 upgrade modules' numeric fields, Runes + 9 packs, 4 special pools, Datastore, Reconcile, Mob, MobsHandler, Merger, MultiplierButtons, ProductHandler, Freeze, runeStarring, Ascensions, RealmHandling logic). Upgrade and rune modules may change **only** display fields (`Name`, `Description`, display color). The check parses the module and compares numeric/logic fields, not raw text.

---

## 21. Roadmap and Milestones

| Milestone | Goal | Exit criteria |
|---|---|---|
| **M0 · Foundation** | extract the place to a Rojo/Wally-style project (or keep the place-first workflow), frozen manifest, Lexicon + Theme + PresentationBus skeletons, QA harness | frozen hashes committed; a fresh account plays to Epoch 3 on the unchanged game through the new Lexicon with **zero legacy terms** in the touched UI |
| **M1 · Vertical Slice (Epoch 0–3)** | Observatory + Starlight Core + Stellar Forge + Gravity Well + Research Array + Stellar Survey bay; new HUD; Epoch cinematic; Discovery Reveal; Frontier lighting and sky L0–L1 | Playtest: a new player reaches Epoch 3 without help; Final Art Director pass on slice; perf budgets met on Low |
| **M2 · Realm I complete (Epoch 0–10)** | all 8 platforms, 6 Frontier bays, Anomalies, Orbs, Cubes, Planetarium, Trials, Cosmology Isle + Viewer, Catalog, Supply Depot | full Realm I Visual QA set; Economy QA report; Consistency lint clean for Realm I |
| **M3 · Supernova + Realm II** | Supernova cinematic, Cosmic Dust swarm, Expanse, Nebula Engine, Absolute Zero, Cryo Reactor, Deep Space bay, Collapse Monument I–IX, Shatter Star | reset matrix tests pass; save/load across Supernova verified |
| **M4 · Late game** | Galaxy Formation + Galaxy Core sky, Void/Primordial/Collapsed/Paracosm sectors, Dark/Astral Matter, Reality Break, Reality Echo sky memory, Cosmic Web + Galactic Expedition bays | full-arc Visual QA; perf on late-game sky |
| **M5 · Polish and launch** | audio, loading flight, accessibility, localization keys, store copy, thumbnails/icon, website text, final art gate | all gates green; soft launch |

Suggested order inside M1 (critical path): Lexicon → HUD → Observatory kit → Starlight Core presenter → Forge → Epoch cinematic → Survey bay + Reveal → perf pass → art pass.

---

## 22. QA Plans

### 22.1 Scripted progression tests (Studio MCP, server Luau)

- **Fresh account:** new DataStore scope (`Studio_*` key path already exists in `Datastore`). Run automation with a stat-injection helper to reach each Epoch gate and assert that each presenter's state matches the stat (Core state, platform dormant/active, bay unlocked).
- **Reset matrix:** for every reset (Epoch, Power, Trials C1–C4, Supernova, Collapse I–IX, Galaxy Formation, Reality Break, Reality Echo, Stellar Shards, Cryo Condenser), snapshot all stats before/after and assert **the diff equals the `Resets` module's list** (this proves the presentation didn't alter logic) and that the confirm sheet listed exactly those items.
- **Save/load:** leave and rejoin at every milestone; all presenters restore with no first-time cinematics replaying (`SeenCinematics`).
- **Join mid-state:** load saves at Epoch 7, post-Supernova Epoch 12, Rank 800, Breach 3 + 5 Echoes. Everything renders correctly within 5 s of spawn.
- **Exploit:** confirm presentation code sends no remotes. Fuzz-fire every remote with bad args and confirm server behavior is unchanged vs baseline (the baseline is recorded in M0).

### 22.2 Economy checks (report only)

Dead currencies (displayed but no sink/effect), upgrades whose effect ≤ ×1.0001 over their range, content unreachable given gates (e.g. `Tier_Cost[13]` is a hard cap, which is expected), and runaway multipliers (e.g. the Droplets loop). Output goes to the owner and the Balance Auditor. **No fixes.**

### 22.3 Consistency lint (automated, blocking)

- **Banned player-facing terms** (case-insensitive, whole-word, in any `Text`, `PlaceholderText`, chat/system message, Lexicon value, store data, `Name` of leaderstats): `Energy, Flame, Realm Points, RP, Tickets, Flesh, Damage (as stat), Orbs (bare), Cubes (bare), Spheres, Droplets, Water, Ice (bare), Arctic, Arctic Points, AP, Icicles, Chromium, Chroma, Light (as currency), Reflection, Freeze, Chromatize, Chromatizer, Chromify, Chromifier, Ascension, Ascend, Tier, Rune(s), Rune Luck/Bulk/Speed, Elixir, Robux Tokens, R-Tokens, Loot, Hail, Haze, Shine, Gears, Realm One/Two, Spawn Island, Stud, and every internal rune name that has a different display name` (auto-generated from §5.5).
- Exceptions list: internal-only strings (instance `Name`s not rendered, datastore keys), the `Accelerator` word inside "Particle Accelerator", "Prisms", "Gravity", and developer console output.
- **Uniqueness:** each display name maps to exactly one internal ID (§6).
- **Coverage:** every stat, upgrade, rune, pack, layer and challenge has a Lexicon record, and no fallback renders.

### 22.4 Playtest Agent protocol

Brief: "You have never seen this game." Record: time to first Forge ignite, time to Epoch 1/3/5, every moment of hesitation > 10 s, and every UI opened without purpose. Answer the question *"Could I figure out what to do?"* with evidence. Target: no hesitation > 30 s before Epoch 3.

### 22.5 Visual QA checkpoints

Screenshots from 4 fixed cameras (spawn view, Core close-up, platform overview, sky up) at: **Epoch 0, 3, 6, 9, Supernova (during + after), Epoch 11, Galaxy Rank 1, Rank 10, Rank 1000, Breach 1, Breach 3, Echo ×1, Echo ×8**, plus each Trial active. Pass condition: a reviewer can order shuffled screenshots correctly by progress, and each step shows **visible, obvious** change.

### 22.6 Mobile matrix

Devices/resolutions per §14.7. Check touch target size, UI overlap (automated rect-intersection check on all visible GuiObjects), thermal/perf over a 20 min session on a mid-tier Android profile, and text legibility at 1334×750.

---

## 23. Open Questions (owner decisions needed)

1. **Baseline build:** convert `AI_copy.rbxl` (as uploaded) or `AI_copy_balanced.rbxl` (with the rune-payout fix and the Epoch 11 cost change)? *The spec assumes the balanced build.*
2. **Known bugs (§19):** fix or keep, each one.
3. **Remote talent buying:** allow the Cosmology Viewer to buy nodes remotely via `Buy_Upgrade`, or keep physical-pad-only buying?
4. **Stray assets:** delete `Donkey (Shrek)`, `Rig`, `Polygonal Treant`, and the `Later` folder?
5. **New place vs in-place:** publish as a new experience (fresh DataStore, clean slate) or convert the live game (existing saves, keys unchanged)? This affects whether §2.2 is a safety rule or a hard legal/player-trust rule.
6. **Gamepass/product names and icons:** these need re-upload on the Roblox website (display only, IDs unchanged).
7. **Global Goals:** keep disabled or enable (it's `noinit` today)?
8. **Galactic Expedition naming:** keep "Paracosm" or rename to "Multiverse" to close the arc? *Spec keeps Paracosm (object) and uses "Multiverse" for Epoch 12.*
9. **Studio MCP access** for the agent team, and which account/group owns uploaded assets.
10. The balance sheet counts **248** upgrade modules, but its table lists **247**. Identify the missing one.

---

## Appendix A — Client modules → presenters

| Client module | Presenter(s) | Primary world object |
|---|---|---|
| `Tier` | EpochPresenter, CorePresenter | Epoch Engine / Starlight Core |
| `Flame` | ForgePresenter | Stellar Forge |
| `Power` | GravityWellPresenter | Gravity Well |
| `Realm Points` | ResearchArrayPresenter | Research Array |
| `Tickets` | ChartPresenter | Chart Terminal |
| `Runes` (+UI Handlers ×13) | SurveyPresenter ×9, DiscoveryDirector | Telescope Bays |
| `Mobs` | AnomalyPresenter | Containment Ring |
| `Orbs` | OrbObservatoryPresenter | Orb Observatory |
| `Cubes` | CubeFusionPresenter | Cube Fusion Bay |
| `Gears` | GyroPresenter | Orbital Gyros |
| `Accelerator` | AcceleratorPresenter | Particle Accelerator |
| `Spheres` | PlanetariumPresenter | Planetarium |
| `Talent Tree` | CosmologyPresenter | Cosmology Isle / Viewer |
| `Challenges` | TrialPresenter + LightingOverride | Trial Gate |
| `Loot`, `Hail`, `Haze`, `Light`, `Ascended`, `Chroma`, `Shine` | BeaconPresenter ×7 | Beacons |
| `DropletsBoard` | DustFlowPresenter, DustSwarm | Dust Board / player swarm |
| `MultiplierButtons.Water` | NebulaEnginePresenter, SkyNebula | Nebula Engine |
| `MultiplierButtons.Ice`, `IceButtons` | AbsoluteZeroPresenter, FrostSpread | Absolute Zero Chamber |
| `Arctic Points` | CryoReactorPresenter | Cryo Reactor |
| `Freeze` | CollapseMonumentPresenter | Collapse Monument |
| `Icicles` | ShatterStarPresenter | Shatter Star |
| `Chromatize` | GalaxyCorePresenter | Galaxy Core (sky) |
| `Chromify` | RealityBreakDirector | Sector V |
| `Reflection` | EchoPresenter, EchoSkyRing | Paracosm |
| `RuneStarring`, `RuneStarring_Setup` | StarMappingPresenter | Star Mapping Altar |
| `PlaytimeRewards` | StreakPresenter | Observation streak console |

## Appendix B — Automation unlock gates (from `Libraries.Automations`)

Solar Energy pad E≥1 · Cosmic Points pad E≥1 · Gravity pad E≥2 · XP / Anomalies / Auto-Impact / Salvage E≥4 · Prisms E≥5 (×2 pad E≥6, Cosmology prism button E≥6) · Orbs E≥7 · Cubes E≥8 · Planets E≥9 · Meteor Shower E≥10 · Observation streak E≥11 · Collapse I E≥11 · Epoch-12 time / Global Goal rewards E≥12 · Solar Wind / Stellar Shards E≥13 · Dark Matter Rank≥1 · Astral Token tick 2.625 at Rank≥850 · Astral Beacon Rank≥1000 (+Primordial Star gate) · Radiance Beacon Breach≥1 · Convergence Beacon Breach≥2 · Echo pad Breach≥3.

## Appendix C — Cooldowns that drive animation cadence

Presenters sync to these (from `Shared.Modules.Cooldowns`): Starlight/XP/Planets/Frozen/Nebula 0.25 s (−Gyros) · Solar/Gravity/Echo 0.25 s · Research 1 s (÷3 at 2.5e14 Planets) · Epoch/Galaxy Forge/Reality Engine 1 s · Scans = `Rune_Speed` (≥ 1/60 s) · Prisms (15 + …)/Accelerator · Orbs 1 s · Cubes 2–20 s · Cosmic Dust 0.5 s · Cryo 1 s · Dark Matter ≤ 10 s · Stellar Shards 5 s · Astral Tokens 30–360 s. **Visual pulses must never exceed the real tick rate.** They are also limited to 4 Hz per object for readability.

## Appendix D — Reference files

- `reference/Stud_Incremental_Balance.md`: the full formulas, runes, systems and 248 upgrade configs. **Authoritative for all numbers in this spec.** If this spec and the sheet disagree on a number, the sheet wins. File a doc fix.
- `AI_copy.rbxl` (not committed, 1.7 MB binary): the place. Its extracted structure is summarized in §3.

---

*End of spec v1. Owners: System Architect (structure), Cosmic Design Director (identity). Update the version and changelog below on every revision.*

### Changelog
- **v1:** initial master spec: full Lexicon (currencies, layers, 9 surveys, 134 discoveries, 247 upgrades, anomalies), collision rulings, Epoch/Collapse/Galaxy/Reality progression, world/sky/UI/rendering/perf/audio specs, bug policy, 20-agent structure, roadmap, QA.
