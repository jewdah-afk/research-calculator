# The Milestone Tree NG+ on Roblox: FINAL client design

This is the build spec for the Roblox-native client: the parallax **realm map** is home, a **HUD** sits around it, and
each of the 21 layers opens as a **panel**. It is self-contained. You do not need the three competing specs to build
from it.

* **Base:** `design_juicy` won overall: premium simulator look, neon italic titles, gold capsule, medallion emblems,
  terminal CR.
* **Grafts:** the judges' graft lists from `design_hierarchy` (hierarchy discipline, HUD-safe framing, overlays) and
  `design_mobile` (thumb map, READY tray, Box-resize strip, performance budget).
* **Fixes:** every must-fix item of the three judges is resolved (§2).
* **Decisions:** all 30 open decisions from `understand_critic.md` are decided (§1).

Every element names its Roblox construction, either inline or as a recipe id `R#` (§13). Anything that has no Roblox
equivalent is not used: no backdrop blur, no CSS filters, no letter-spacing, no blend modes.

* Units are **du** (design units). The WIDE canvas is 1920×1080 du at UI scale 1 (§10). **World px** are pixels of
  the 3840×2560 world layer.
* `c` is the current layer hue.
* `lift(c,t) = c:Lerp(white,t)`, `shade(c,k) = c*k` and `mix(a,b,t)` are the Figma formulas.

## Mockups (`docs/design/mockups/`, sources in `final/src/`)

The repo keeps the renders as JPEG q86 in `docs/design/mockups/*.jpg` (same names as the `.png` files below; the
`@2x` phone renders stay in the scratch tree). `docs/design/mockups/compare/compare_*.jpg` puts the previous render
(left) beside the readability pass of §9 (right) for every screen.

Every mock is built from **one** real view dump, produced by the game's own `rbx_view()` in the scratch port copy
(`final/tools/gen_view.js`). Numbers on one screen never come from two saves.

| file | what it shows | save / state (tools) | camera |
|---|---|---|---|
| `a_map_1920.png` | map home + full HUD: capsule, dock, zoom, READY tray (3 ready + 4 can buy), `???` portal, 2 coalesced toasts + `+3 MORE`, sealed-rift hover teaser | **S13**: fuzz save 13, then a P reset, an SP reset, 7 P upgrade buys, malware m15 and a spark state (`tools/s13pre.js`) | HUD-safe start C (1901,1146), z .505 |
| `b_panel_p_1920.png` | Prestige sheet: tier board with owned tiers folded to compact effect cards, 2 glowing BUY cards, buyable with its hold strip and 91% progress | S13 | Box = strip 760×1080, C (1500,1580), z .9 |
| `c_panel_m_1920.png` | Milestone ladder: NEXT spotlight (40%), 4 newest done rows, decade folds, MALWARE section with INFECT, NOTES, JUMP TO | S13 | strip, C (1500,1900), z .9 |
| `d_panel_cp_1920.png` | Corrupted Prestige terminal: counters, CORRUPT, mode radio, 5×4 disks (Trojan lime, Backdoor crimson, active gold 63%), inspector with the game's ASCII bar; universe tag with FINISH | **S19 inside** the Multiverse + disk grid, ex state and cp buyable 22 (`tools/mv2.js`) | strip, clamped C (3418,1200), z .9 |
| `e_panel_ex_1920.png` | Exploration: zone map (14×12), D-pad from the 4 buyables, feature tiles; the sheet hugs its content | S19 inside | strip, C (3150,780), z .9 |
| `f_panel_sp_1920.png` | Super Prestige · Spark Milestones (infected SP): furnace box, ember burn bars (ashed / burning 63% / permanent), pager | S13 | strip, C (1330,1250), z .9 |
| `g_options_1920.png` | Options: save status, SAVE/EXPORT/IMPORT tiles, Offline Production, DISPLAY (game options, one press per tap), THIS DEVICE (client-only), DANGER ZONE, ABOUT + unlocked hotkeys | S13 | panel without a node: Box shrinks, C compensated to (753,1146) |
| `h_toasts_1920.png` | toast stack (kind+layer coalescing ×10 / ×5 / ×2), notification list opened from `+3 MORE`, READY hold in progress (conical ring), locked-node tooltip | S13 popups | as (a) |
| `i_export_1920.png` | export modal over Options (real 22,204-character save string, selected) | S13 | — |
| `j_system_1920.png` | system overlays: peek, Multiverse gate popover (FINISH), hard-reset confirm, import with inline error and cooldown, status chips, loading, OUT OF SYNC, end screen | S13 / S19 inside | — |
| `n_fresh_1920.png` | **new player**: fresh save (only M and the shrine), first-run cue, no tray, no rate pill, frontier `?` sockets | empty save + 20 ticks (`tools/gen_fresh.js`) | HUD-safe start |
| `k_map_844.png` (+`@2x`) | phone map home, LOW tier: compact capsule, dock, READY pill, `???` portal, edge markers (MP up, MM down), compact toast | S13 | touch zoom .34, C (1460,1202) |
| `l_panel_p_844.png` (+`@2x`) | phone Prestige: band in the top-bar strip with the READY switcher and a 44 du close, hero column with the CTA at the thumb, owned summary row, BUY cards | S13 | map disabled |
| `l_panel_p_844_scrolled.png` (+`@2x`) | the same phone Prestige sheet scrolled to the BUY cards and owned summary: reading type at the COMPACT sizes of §9.2 | S13 | map disabled |
| `m_panel_m_844.png` (+`@2x`) | phone Milestone ladder | S13 | map disabled |
| `n_fresh_844.png` (+`@2x`) | phone new player: START HERE cue on M | fresh | z .34, focus M at 60% down |

Re-render with the commands below. `realm_bg.js` drives the repo's own `art/preview/realm.html` with the REALM camera,
read-only, with the strip viewports at 760×1080 and the phones at 844×390 @2x on the LOW tier.

```sh
cd art && NODE_PATH=$(npm root -g) node <final>/tools/realm_bg.js <final>/tools/shots.json
cd <final>/src && NODE_PATH=$(npm root -g) node render.js a_map_1920.html ../png/a_map_1920.png 1920 1080
```

Mock cheats, all of them Roblox-equivalent:

* `box-shadow` stands in for UIShadow or a glow sprite.
* The `.tx` clone stands in for the Contextual UIStroke plus the shadow clone.
* `background-clip:text` stands in for a UIGradient on text.
* Inline SVG icons stand in for atlas sprites.
* The RBX / chat / ··· circles only mark the Roblox top-bar clearance.
* Font sizes and line heights come from `TY` in `lib.js`, a copy of the §9.2 role table; `theme.css` lifts any
  leftover page-level size below the §9.5 floors.

---------------------------------------------------------------------------------------------------------------------

## 1. Decisions (the critic's 30 open questions, all resolved)

| # | question | decision |
|---|---|---|
| Q-M1 | Zoom? | **Yes.** Wheel (×1.12/notch at the cursor), pinch, double-tap/double-click (×1.6), **double-tap-and-drag** one-finger zoom (1 pt up = ×1.006), and HOME toggles start ⇄ overview (zMin). Range is REALM `[zMin(V), 1.25]`. **No pan keys**; `-`/`=` zoom one notch only when not in `patch.keys`. |
| Q-M2 | Hidden layers | `show:false`: a sealed socket (dark glass cap α .7, no plate, inert). **Frontier** (a hidden node whose Figma parent is shown, same universe) gets a faint `?`. Hidden by universe (`val.dor`) is dormant: grey ring, moon badge, toast "Lives in the Normal Universe" on tap. Locked (`!lit`): real symbol, lock sprite, plate `🔒 val.req`. |
| Q-M3 | Node scale | Ring and gem scale with z inside the painted socket. **Floor** k = max(z, 36/132) with a mouse, max(z, 44/132) on touch, written as one UIScale **only while z is below the floor**. Plates and badges have a constant screen size. Plate LOD: FULL / CHIP / NONE by zoom (§3.9), plus occlusion fade under HUD rects and collision culling. |
| Q-M4 | Edges | Existence and lit state come from the live `br`; geometry from the Figma control points plus the new MP→PM bridge; colour is the TO (child) hue. **Malware P→M stays red.** Locked edges are dots every 15 world px on HIGH (≤ 400 in total) and one thin thread on LOW and phones. |
| Q-M5 | Painted veins | Accepted. The live Path2D stack on top carries the state. |
| Q-M6 | Gate | One visible entry point: the **portal button** (bottom-right), plus the **rift hotspot** (hover teaser, click = fly + popover). Inside the Multiverse, a **universe tag** under the capsule carries EXIT/FINISH, so it stays reachable while a panel is open. The standalone map gate chip was dropped (it duplicated the portal). |
| Q-M7 | Start camera / persistence / fly-to | Start = REALM §2.8 solved on the **HUD-safe rect** (1080p: z .505, C (1901,1146)). Phones: touch zoom .34 on the **centroid of the READY nodes**, shifted so no ring sits under the top band; M at 60% down for a new player. Not persisted: every join starts from the rule. `frameNodes(ids)` is used for universe changes and the READY `+N` list. Fly-to follows REALM (SmoothDamp .35 s, z = max(z, .9)) toward the free rect's centre. |
| Q-M8 | fg z-order / ReducedMotion | REALM z-order: fg and motesNear under Links/Nodes, particles over them at α ≤ .24, never taking input. fg and motesNear fade out (0.2 s) while a side sheet is open. ReducedMotion follows REALM §9.6, plus the UI rules in §8. |
| Q-L1 | Breakpoints (superseded by aspect scaling, §10) | **WIDE** (canvas 1920×1080 du), **MEDIUM** (≈1600×900 du), **COMPACT** (phones, V.y < 500 pt). s ≥ 1 on COMPACT and ≥ .90 on desktops, and `Theme.size` holds the floors, so no text renders below 12 px (caps) / 13 px (everything else) (§9.5, §10). |
| Q-L2 | Panel form | WIDE/MEDIUM: a **right side sheet**; the map Box is resized to the free strip and stays live (§3.6). COMPACT, and MEDIUM strips under 460 du: **full screen**, `MapGui.Enabled = false`. Always docked right; never left-docked. |
| Q-P1 | Sections | Titles come from `cn` (§5.6). Order is the tabFormat order, with main-display, reset and resource-display lifted into the hero. Per-layer exceptions are in §6. |
| Q-P2 | Buyable bar | Capped buyable: level / limit. Not affordable: **progress-to-afford** (`pr`, server-side, e.g. 91%). Affordable: none (the hold strip lights instead). |
| Q-P3 | Hidden / done challenges | The "Completed Challenges" option is honoured (the game removes them). Done = quiet green. If hiding empties a section, a slim row reads "All challenges completed · hidden by Options" with an OPTIONS link. |
| Q-P4 | m's 186 rows | **NEXT** spotlight, then the 4 newest done rows, then **decade folds** (each names its notable unlocks), then "1 – N · SHOW ALL". Expanding virtualises a pool of 16 rows. JUMP TO index in 25-blocks (WIDE). |
| Q-P5 | tabStyle / st | Dropped. Structural widths survive only for bespoke widgets. Game colours are remapped (§11.2). |
| Q-H1 | HUD contents | Capsule (points, rate, universe, warnings, status), universe tag, dock (HOME / TROPHIES n/18 / OPTIONS), zoom capsule (mouse), READY tray / pill, portal, toasts + notification list, edge markers. **No Alerts bell**: the READY tray replaces it. |
| Q-H2 | Chat | Chat stays enabled and is never moved. No HUD control sits in the top-left 420×300 du below the band; only map art is there (the shrine, which Trophies duplicates). |
| Q-H3 | Credits / hotkeys | An **ABOUT** card inside Options: the game credits, TMT, the Prestige Tree, and the **unlocked hotkeys** (the view's `keys`). This is not an info screen: no changelog, no dev notes, no time-played readout. |
| Q-O1 | Popup flood | Coalesce by **kind + layer** within 1.5 s: ×N chip, range sub ("18th – 27th Meta-Milestone"), life 3 s + 1 s per merge (max 6 s). Visible: 3 WIDE / 2 MEDIUM / 1 COMPACT. Overflow goes to `+N MORE`, which opens the notification list (the last 20). |
| Q-O2 | Hard reset | Options › HARD RESET… opens a confirm modal with EXPORT FIRST, CANCEL and **HOLD 2 s**. Completion sends `{"opt","hardReset"}` twice (the game's press-twice rule). |
| Q-T1 | Touch info | Nodes: long-press **peek**. Upgrades: long-press opens the detail sheet. Buyables: an ⓘ button (their long-press is the hold-to-buy). cp disks and ach: the inspector strip. Mouse: hover tooltips after 250 ms. |
| Q-G1 | Gamepad | Out of scope, but `Selectable` stays sane: the dock, READY gems, the portal and the panel CTA form the focus ring; B closes a panel. REALM stick pan and trigger zoom are kept. |
| Q-F1 | Figma first? | **Code-first mockups** (this workflow) are the source of truth. A follow-up task pushes these screens into Figma Screens 2:5 and Overlays 2:6 for the snapshot comparison. It does not block the build. |
| Q-F2 | Order of work | (1) view.js fields (§15) + v.map/v.hud + parity; (2) mock.luau additions (§16); (3) client skeleton: MapGui/TopbarGui/HudGui/MarkerGui/PanelGui/OverlayGui and ViewStore routing; (4) recipes and skins (§13), Theme.caps; (5) per-layer signatures (§6); (6) asset pipeline (tiles + ui_atlas + tile textures) in parallel; (7) snapshots, Studio verification (§17), `rojo build`, commit. |
| U1 | Art upload | Needs **the user**: an Open Cloud API key (Assets read+write) plus the creator id, or a manual Asset Manager import of about 34 tiles + 1 atlas + 6 tile textures. Until then `Assets.luau` returns nil and the fallback look applies: a procedural sky gradient + nodes + links, with every HUD and panel unchanged. |
| U2 | Publish / creator | Must match the key's creator (user or group). Asked with U1. |
| U3 | Devices | **PC + phones (landscape) + tablets.** Console is kept sane, not polished (Q-G1). |
| U4 | Credits and hotkeys in Options | Yes, as the ABOUT card (Q-H3). It respects "no info screens". |
| U5 | Figma vs code first | Code first (Q-F1). |
| U6 | "I don't see any" | Treated as "no art in Studio" (U1). The fallback look plus a clear "Map art not uploaded" dev-only chip (Studio only, `RunService:IsStudio()`) make it visible. |

Contradictions C1–C14 (critic §1):

* C1: use Montserrat **Heavy** (no Black exists).
* C2: no pan keys.
* C3: `v.map` / `v.hud`.
* C4: close = `["tab","none"]`.
* C5: the UI scale is in §10.
* C6: zMin is REALM's cover fit; the depth-scaled layers make the art cover it.
* C7: `br` gives existence, Figma gives geometry, the TO hue gives colour.
* C8: pulse = aura + bolt badge, glow = "!", selected = `map.open`, locked = `!lit`, hidden = `show:false`.
* C9: `Sibling` everywhere, and `SortOrder = LayoutOrder`.
* C10: GetInsetArea is used through pcall.
* C11: tiles ≤ 1024.
* C12: `N / 18`.
* C13: toast kind comes from `kind` (view) with a title/type/colour fallback.
* C14: the colour remap in §11.2.

---------------------------------------------------------------------------------------------------------------------

## 2. Every judge must-fix, resolved

| # | must-fix (short) | resolution | where |
|---|---|---|---|
| 1 | Owned cards and done rows outshine BUY / NEXT | Owned = quiet tier: `mix(panel, #4be07a, .14)`, 1.5 du stroke α .45, **no glow**, effect value. Only BUY / NEXT / CTA glow. | §5.7, mock b, c |
| 2 | Right third overcrowded (toasts, rail, gate card, portal, rift) | Rail removed (the dock is bottom-left), gate chip removed, one Multiverse entry (portal). Toasts are the only thing top-right, max 3 WIDE. | §4, mock a |
| 3 | P header + hero ≈ 370 px | Header 92 + hero 142 (stats inline under the CTA). Owned tiers fold to 72–88 du compact cards, so the P board needs one short scroll at 1080p with the larger reading type (§9). | §5.3, mock b |
| 4 | Phone close floats over the scrollbar | 44 du close **in the band**, left of the Roblox "···" (TopbarSafeInsets). | §5.10, mock l, m |
| 5 | No HUD-safe start framing | §3.3. T sits under the capsule at neither 1080p nor on phones. | mock a, k |
| 6 | Mock numbers mixed within a screen | One real dump per screen (tables above). | all |
| 7 | Dev note visible (hierarchy M) | Only the game's display-text lines appear, verbatim, as NOTES. No client-authored explanation copy. A lint rejects strings containing "virtualis", "Studio", "debug". | §5.6 |
| 8 | "0.00 OOMs/sec" | `hud.gen = null` when the rate is 0 (view). The client hides the pill when null. | §15, mock n |
| 9 | "Corrupt. Tooltip Pos." dropped | Kept as a **cycler**: mouse = the inspector docks on that side (right = inspector column); touch always uses the inspector. | §6 cp, mock g |
| 10 | Small web-like section titles | Section titles are Heavy Italic **24** (COMPACT 22) with a gradient, stroke and hue bar. Panel titles 44 (COMPACT 27). | §9 |
| 11 | READY tray as heavy text rows | **Gem row** with gain chips (desktop tray) or a pill (phone and strip). | §4.5 |
| 12 | Chrome/silver titles look disabled | Titles use `W → lift(c,.45)` plus a black Contextual stroke, never silver. | §9 |
| 13 | Orange "3 READY" bar competes inside panels | In the strip it is a small gold **READY pill** ("Tap a gem to switch"). The only CTA inside a panel is the panel's own. Orange is not a state hue. | §4.5, mock b |
| 14 | Rail owned-ring dead space | No rail ring. The desktop hero row is compact; the phone hero column holds stats + the CTA at the thumb. | §5.3, §5.10 |
| 15 | Phone plates under RBX/chat and the capsule | **Plate occlusion**: a plate whose rect meets a HUD rect (Roblox buttons and the strip edge included) first tries the slot above its ring, then the CHIP form, then fades to **α 0** (no ghost text); rings stay. Phone start framing keeps rings out of the top band. | §3.9, mock k |
| 16 | 14–16 "STABLE" labels | Empty disks are quiet tiles with only the slot number. | mock d |
| 17 | UIShadow has no text / inset / Path2D mode | Text glow = a **glow_rr sprite behind the label** sized to TextBounds. Bevel = 9-slice overlay (primary). Path2D glow = stacked strokes. | §13 |
| 18 | SelectRing square glow; tweening BlurRadius | SelectRing = `ring_dashed` + UICorner .5, or a glow_circle sprite. Pulses tween ImageTransparency / UIScale only. | §3.7, §8 |
| 19 | Links/Nodes vs fg order | Links and Nodes are separate siblings **after F_motesNear**, with the world transform. About 20 container writes per moving frame. | §3.1 |
| 20 | Band content in CoreUISafeInsets | **TopbarGui** (`ScreenInsets = TopbarSafeInsets`) holds the capsule, universe tag and the COMPACT panel band. | §3.1, §4.2 |
| 21 | Box-resize transition unspecified | Formulas, animation, zMin changes and the < 568 pt fallback are in §3.6. | §3.6 |
| 22 | Juicy strip clamp outside the tested domain | Replaced by mobile's **Box-resize strip**: V = strip, plain hard clamp, inside camera.js `--test`. | §3.6 |
| 23 | Gate chip / markers dirty HudGui | Edge markers live in a separate **MarkerGui**. The gate chip is gone. Plates live in MapGui. | §3.1 |
| 24 | "Build once per layer, destroy tabs after 30 s" vs path ids | **One Render tab tree**, re-skinned idempotently. Animations are keyed by `(layer, id)` from `a`. | §5.1 |
| 25 | Static bar parses reset.base/next strings | Server-side `reset.pr` / `pr` from Decimal (§15). | §15 |
| 26 | Client settings inside the game save | A separate DataStore key `client` (Motion, Map Detail, Map Labels, Interface Size). The save and export stay identical to the web game. | §6 Options |
| 27 | Node click semantics | A click on the **selected** node is a no-op (it re-flies to the node if the camera moved). A double-click on a node counts as one click (300 ms debounce). | §3.4 |
| 28 | Left dock + ChatWindowConfiguration | No left dock, and the chat is never touched. Rift layers reach the strip through the Box-resize clamp (CR lands at x 463 of the 760 strip). | §3.6, mock d |
| 29 | Dot spacing on zoom, uncapped dots | Fixed at 15 world px, capped at 400, built once in world scale units. LOW and phones use a thread. Node conditional parts (rays, aura, rings, badges, chips) are created lazily. | §3.8 |
| 30 | FACTS regex parsing | None. display-text lines render verbatim as NOTES rows. | §5.6 |
| 31 | Segmented controls on game cyclers → N presses | Game cyclers stay **cyclers** (one `opt` press per tap, page dots). Two-option game toggles are a segmented control (one press). Device options are client-only (direct set). | §6 Options |
| 32 | Map hold-to-prestige safety | The hold starts only while the press stays under the drag threshold and never during inertia or a pinch. Hold **0.6 s** (tray, peek). The server accepts `val.ra` because it is a view action (registered only while the layer can reset). | §3.4, §4.5 |
| 33 | Discord line on the end screen | Removed. | §7.11 |
| 34 | No test contract | §16: anchors, mock additions, snapshot mode. | §16 |
| 35 | Tiled textures from atlas regions | Tile textures are **standalone images** (§14.2), counted in the budget. | §14 |
| 36 | Read-only TextBox copy on mobile | Fallback: an editable TextBox whose Text is restored on every change. | §7.6 |
| 37 | No new-player mock | Mocks n (desktop + phone). First-run mode in §7.12. | mock n |
| 38 | Buyables lack an affordance state | A per-card **hold strip**: lit and "HOLD TO BUY" when affordable, otherwise the reason ("NOT ENOUGH PP"). | §5.7, mock b |
| 39 | Phone HUD lacks Trophies / Home; top-right thumb reach | Bottom-left dock HOME / TROPHIES / OPTIONS on every device. Portal and READY at the bottom-right. | §4 |
| 40 | Mobile READY tray lacks CAN BUY; no markers | The tray lists **PRESTIGE READY then CAN BUY** in fixed map order. Edge markers (≤ 4) point at off-screen ready and can-buy nodes. | §4.5, §3.10 |
| 41 | "N READY · HOLD TO PRESTIGE" ambiguous | The pill says "N READY" over "Tap to list" (or "Tap a gem to switch" in the strip). Only an individual gem or a peek holds. Never batch-prestige. | §4.5 |
| 42 | 10.5 px text on phones | Rendered floors on every device: 12 px caps, 13 px everything else, 14 px body paragraphs (§9.5). The COMPACT scale starts at caps 12 / body 15. Lint on every §10 row. | §9, §10 |
| 43 | Multiverse hold never says what resets | The gate popover lists the reset layers (the game's `onEnter` list). The ENTER / EXIT / FINISH hold is **1.2 s**. | §7.8 |
| 44 | Toasts cover phone nodes, jump position | One location: the **top-right of the free map rect** (phone: under the band, 240 du, max 1). Toasts are click-through (only `+N MORE` takes input). | §4.7 |
| 45 | No layer switch in a full-screen phone panel | A **READY switcher** (gems) in the band. Tapping a gem opens that layer. | §5.10, mock l |

---------------------------------------------------------------------------------------------------------------------

## 3. Map (home)

### 3.1 ScreenGuis and trees

| ScreenGui | DisplayOrder | ScreenInsets | holds |
|---|---|---|---|
| `MapGui` | 0 | None, SafeAreaCompatibility None | REALM §9.1 tree + Links, Nodes, Plates |
| `MarkerGui` | 5 | DeviceSafeInsets | edge markers (≤ 4), repositioned per camera frame; nothing else |
| `HudGui` | 10 | CoreUISafeInsets | dock, zoom capsule, READY tray / pill, portal |
| `TopbarGui` | 12 | **TopbarSafeInsets** | capsule, gen pill, warning chip, status chip, universe tag; the COMPACT panel band |
| `PanelGui` | 20 | CoreUISafeInsets | sheet backdrop, sheet |
| `OverlayGui` | 30 | DeviceSafeInsets | toasts, notification list, tooltip, peek, modals, loading, fatal, end screen |

All of them set `ZIndexBehavior = Sibling`, `ResetOnSpawn = false` and `AutoLocalize = false`. Every UIListLayout uses
`SortOrder = LayoutOrder`.

Other settings:

* `StarterPlayer.EnableMouseLockOption = false` (Shift hotkeys);
* `StarterGui.ScreenOrientation = LandscapeSensor`;
* `GuiService.TouchControlsEnabled = false`;
* `Camera.CameraType = Scriptable`;
* `SetCoreGuiEnabled` Backpack / Health / PlayerList false.

```
MapGui > Root (black) > Box (Frame, ClipsDescendants = true, + UIScale mapScale)          -- V = Box size (map pts)
  L0_sky, L1_clouds, L2_far, L3_mid, Wash, L4_near, F_motesFar, L5_world, L6_fg, F_motesNear   (REALM, unchanged)
  Links   (Frame, same Position/Size writes as L5_world)   Path2D stacks + dot Frames, all in scale units
  Nodes   (Frame, same transform)                          Node_<id> widgets in scale units, + the rift hotspot
  F_particles, Vignette                                    (REALM)
  Plates  (Frame, full Box, NOT scaled)                    Plate_<id>: one Frame + one RichText TextLabel, AnchorPoint (.5,0)
```

Per moving frame the client writes:

* 2 writes × (8 layers + Links + Nodes) = 20 container writes;
* 21 plate Positions;
* the field updater.

At rest it writes nothing. Map art has `Active = false` and `Interactable = false`. Only the node `Hit` buttons and
the rift hotspot take input (`InputSink = None`, so the map drag still sees the press).

### 3.2 Camera: the REALM contract, verbatim

`art/REALM.md` §2–§9 and `art/camera.js` apply unchanged:

| rule | value |
|---|---|
| layer zoom | the **dolly law** `s_L = z/(f + (1−f)z)`. The brief's `z^f` breaks depth order below z ≈ .3; REALM §2.3 explains it. |
| layer placement | `P_L = A + f(C − Wc)` |
| world transform | `q = Vc + z(p − C)` |
| zoom range | zMin = cover fit `max(V.w/3840, V.h/2560)`, zMax 1.25 |
| clamps | hard clamp at rest; rubber band while input is active |
| mapScale | REALM §2.6 |
| biome tint and wash | REALM §5 |
| ambient sprites and fields | REALM §6 |
| tiers and ReducedMotion | REALM §9.5 / §9.6 |

The client only chooses parameters inside the contract:

* the start framing;
* the touch rest zoom;
* the node floor;
* the Box size (§3.6).

### 3.3 Start, recenter, framing

* **HUD-safe start (WIDE/MEDIUM).** Solve REALM §2.8 on the safe rect V' = V minus the top band (100 du·s) and minus
  the bottom (96 du·s):
  * `z0 = clamp(min(V'.w/1500, V'.h/1750), zMin, 1)`;
  * `C0 = (1500, 1150) + (Vc − V'c)/z0`, then the hard clamp.

  At 1920×1080 that gives z .505 and C (1901, 1146): the whole realm width fits, and T's ring top sits at y 90,
  below the capsule and pill (mock a). The intro dolly-out from `min(1.12 z0, zMax)` runs 1.6 s quintOut (none with
  ReducedMotion).
* **Phone start (COMPACT).** z = **.34**, so the ring is 45 pt, above the 44 pt touch floor.
  * C = the **centroid of the READY nodes** (pulse + glow), then nudged vertically so no ring sits under the top band
    (76 du) and the lowest READY plate stays on screen.
  * No READY nodes: the last opened layer; otherwise the trunk (1500,1150).
  * New player: M at 60% down the safe rect (mock n phone: C (1500,1832)).
* **Inside the Multiverse** at boot: the same rules on the rift cluster (`frameNodes(shown)`).
* **frameNodes(ids)**:
  * bbox of the rings + plates;
  * `z = clamp(min(V'.w/bw, V'.h/bh), zMin, 1)`;
  * `C = centre + (Vc − V'c)/z`, then the hard clamp;
  * used for a universe change (0.9 s quintInOut), the READY `+N` list and HOME's second tap (overview = zMin).
* **HOME button**: fly to the start framing. If the camera is already there, toggle to the overview.
* **Closing a COMPACT sheet**: fly back to the node that was open.

### 3.4 Input arbitration

One module on `UserInputService` handles raw InputBegan / Changed / Ended, updated in `RunService.PreRender`.

* **Gate on press.** A press is ignored when `PlayerGui:GetGuiObjectsAtPosition(x, y)` finds an object of HudGui,
  TopbarGui, MarkerGui, PanelGui or OverlayGui on top.
* **Drag.** Past 6 pt (mouse) or 12 pt (touch), the press becomes a pan. The flag suppresses the node's `Activated`
  on release.

| gesture | on a node | on empty map |
|---|---|---|
| tap / click (< threshold) | open its panel (`["tab", id]`, sent once); **selected node: no-op** (re-fly if the camera moved); a double-click counts as one click (300 ms debounce) | none |
| hover 250 ms (mouse) | tooltip (§7.1) | none |
| long-press 450 ms, < 12 pt of travel (touch) / right-click (mouse) | **peek** (§7.2); never opens | none |
| drag | pan (works when it starts on a node) | pan + inertia (REALM feel) |
| wheel / pinch / double-tap-drag | zoom about the point | zoom |
| double-tap / double-click | — | ×1.6 toward the point, 0.35 s |
| `-` / `=` | one zoom notch if not in `patch.keys` | same |

**Hold safety (tray gems, peek HOLD TO PRESTIGE).** The hold starts only after 120 ms with < 10 pt of movement. It
never starts during inertia (|v| > 6 pt/s) or a pinch. It takes **0.6 s**, with a conical ring. Releasing early
rewinds it in 0.12 s.

### 3.5 Fly-to

REALM fly-to: SmoothDamp on C and on log z, smoothTime .35 s, z = max(current, .9). The target puts the node at the
centre of the **free rect** F: the Box (the strip while a sheet is open) minus the HUD band, `C* = N + (Vc − Fc)/z*`,
then the hard clamp. ReducedMotion cuts instead.

Triggers:

* opening a node (click, READY gem, notification row, edge marker, hotkey opening a layer);
* the portal (flies to the rift centre (3150, 1350) and opens the gate popover);
* a universe change;
* closing a COMPACT sheet.

### 3.6 The map while a side sheet is open: Box-resize strip

* **Geometry.** The sheet covers `[SX, W)`. At 1920×1080, SX = 760 du: the backdrop ramps over 24 du and the card
  starts at 784.
* **The Box is resized** to `[0, SX) × [0, H)`. `V` becomes the strip (760×1080 at 1080p, aspect .70) and
  `Box.ClipsDescendants = true` culls everything behind the sheet.
  * The strip is inside the contract domain (568–2560 × 320–1440 map pts, aspect .45–3.6), so coverage, clamps,
    zMin and `camera.js --test` all hold unchanged.
  * On MEDIUM, a strip narrower than 568 pt falls back to REALM mapScale < 1 (`s = min(w/568, h/320)`). For example
    1366×768: strip 498 pt → s .877.
  * A strip narrower than 460 du makes the sheet full screen and disables the map.
* **Transition (open).** The sheet slides in (Position +48 du → 0, 0.24 s quintOut). The Box width tweens with it.
  On every frame the camera is compensated so the world plane does not jump:
  `Vc_old + z(p − C) = Vc_new + z(p − C')` ⇒ **`C' = C + (Vc_new − Vc_old)/z`**. The fly-to then SmoothDamps C'
  toward the node.
  * Other layers slip by `ΔVc(1 − f·s_L/z)`: the sky moves almost the whole ΔVc, the world 0. This reads as a
    lateral dolly and is accepted.
  * ReducedMotion cuts: the Box snaps and C' is set directly.
* **zMin** drops to the strip's cover fit: .422 at 760×1080, against .5 full screen. **On close** the Box tweens back
  (0.16 s), C is compensated the same way, and if z < zMin(full) the zoom springs up with SmoothDamp 0.18 s.
* **A panel without a node** (Options) never flies: the Box shrinks and C is only compensated. Mock g: C (753,1146)
  at z .505.
* **Rift layers:** the plain strip clamp lands CR at x 463 and CM at x 625 of the 760 strip (mock d). No left dock
  is needed.
* **fg + motesNear** fade to 0 in 0.2 s while a sheet is open (foliage in a narrow strip is clutter), and fade back on
  close.
* COMPACT (full-screen sheet): after the slide, `MapGui.Enabled = false`, ambient tweens paused, field updater
  stopped (REALM §9.7).

### 3.7 Node widget (Figma Map Node 4:40, instance values) — ≤ 10 instances + lazy parts

```
Node_<id>   Frame, Size fromScale(180/3840, 200/2560), AnchorPoint (.5,.45), Position fromScale(N.x/3840, N.y/2560)
  UIScale   = k/z, written only while z < floor (k = max(z, 36/132) mouse, max(z, 44/132) touch)
  Glow      ImageLabel glow_circle 2×Ø, tint c, α .45 (pulse/selected α .9)                         (R2 fallback; else UIShadow on Ring)
  Ring      Frame Ø132, UICorner .5, UIGradient 135° lift(c,.35)/c/shade(c,.4) (keys 0,.1,.5,.9,1), bevel_ring overlay (R1)
  Gem       Frame Ø104, UIGradient Radial lift(c,.55)/c@.5/shade(c,.28) (R7), UIStroke 3 shade(c,.28)
  Shine     ImageLabel circle 60×26 at (0,−31), UIGradient transparency .45 → 1
  Symbol    TextLabel Sarpanch Heavy 44/40.5/31.7 (1/2/3 chars), white, UIStroke Contextual 4 black (★ = star sprite for ach)
  Hit       ImageButton transparent Ø max(132, 44/k), UICorner .5, InputSink None
  -- lazy (created on first need, then kept and toggled):
  Rays      ImageLabel rays 300, tint c, α .55, Rotation 12 s/rev                  [pulse, max 4 nodes at once]
  Aura      ImageLabel aura 220, tint c, α .55↔.30 (1.4 s sine)                     [pulse, selected]
  Select    ImageLabel ring_dashed 164, tint lift(c,.3), Rotation 20 s/rev (UICorner .5 if UIShadow is used)   [selected]
  ChalRing  ImageLabel ring_dashed 150, tint #ffc233, counter-rotating 14 s/rev     [ch ≠ null] + chip "C<id>"
  Badge     ImageLabel 26 (22 COMPACT) at (.72R, −.72R): **bolt** (gold) = pulse, **"!"** (danger) = glow (bolt wins)
  Lock      ImageLabel lock 20 (17) at (.62R, .62R)                                  [locked]
```

| state | condition | look |
|---|---|---|
| sealed | `show == false`, not frontier, not `dor` | dark glass cap Ø104 α .7, no plate, no link, inert |
| frontier | sealed, and a Figma parent in the same universe is shown | cap α 1, stroke #6a5f8f, faint `?` Sarpanch 44 #8d86a8; tooltip "???" |
| dormant | `show == false` and `val.dor` | grey ring α .8, symbol #5b5572, moon badge; tap → toast "Lives in the Normal Universe" / "…in the Prestige Multiverse" |
| locked | `!val.lit` | grey ring #898598/#4a4360/#1e1b26, gem #3a3352→#14111f, lock sprite, plate name #c9bfd0 + lock sprite + `val.req` in soft |
| available | `val.lit` | hue ring + gem, glow α .45 |
| can buy | `val.glow` | + "!" badge (pop 0.25 s Back Out); listed in READY as CAN BUY |
| prestige ready | `val.pulse` | + rays + aura + glow α .9 + bolt badge + plate line bolt sprite + "READY" (`plateSub`); flow sparks on its incoming edge |
| selected | `map.open == id` | dashed select ring + aura; plate always FULL |
| in challenge | `ch ≠ null` | gold counter-rotating ring + chip `C<id>` |
| infected | `col` is a malware variant (m #9f2846, p #c25757, sp rgb(238,112,112)) | hue → danger #ff3b5c for the ring, gem, plate and incoming edge; symbol glitch flicker (R12) every 3–6 s |

Priority: selected > pulse > glow > challenge > available. cp shows **CR**. pm's plate name is masked as the view
sends it. Hover gives UIScale 1.08 (0.12 s); press gives .94 (0.08 s).

### 3.8 Connections (Path2D; geometry from Figma, existence from `br`)

* **Existence and state:** each shown node's `br` (live TMT branches); drawn only when both ends are shown.
  * **Geometry:** the Figma cubic control points (`final/src/lib.js EDGES`) + the MP→PM bridge
    `(1878,699) (2330,610) (2860,1120) (3092,1521)`.
  * **Colour:** the child (TO) hue.
  * **Lit** when the child is lit.
* **Lit** (R11): 4 stacked Path2D, with thickness scaled by k = max(z, floor) and rewritten when z changes by > 2%.
  LOW and phones drop the hot stroke.

  | stroke | colour | thickness | transparency |
  |---|---|---|---|
  | halo | c | max(10, 24k) | .86 |
  | glow | c | max(6, 14k) | .68 |
  | core | lift(c,.3) | max(2.5, 4k) | 0 |
  | hot | white | max(1, 1.5k) | .15 |

* **Locked:**
  * HIGH: Ø3 dot Frames (#c7b8f2 α .45) every **15 world px** of arc length, sampled once with
    `Path2D:GetPositionOnCurveArcLength`, positioned in `Links` scale units. They never rebuild on zoom. There are
    **≤ 400 in total**; past the cap the remaining edges use the thread.
  * LOW and phones: one Path2D thread, 2.5 pt, #c7b8f2 α .42.
* **Secondary** (game colour theme slot 3: hp→sp, ap→hp): halo and glow at half alpha.
* **Infected** P→M (`#c86a6a`): danger strokes, with the core flickering on the R12 schedule.
* **Flow sparks** (HIGH only, none with ReducedMotion): 1 spark (glow_circle 26k + sparkle 12k) per edge into a
  pulse node, 1.6 s loop along a precomputed 32-point table. There are **≤ 6** in total.

### 3.9 Nameplates

* **Type** (§9.2): name `plate` 15 (COMPACT 13, ExtraBold Italic caps with hair spaces, UIGradient W → lift(c,.45),
  stroke 1.5 + shadow +1); amount `plateNum` 15 (14, Sarpanch Bold lift(c,.55), no stroke: the plate is its
  backing); READY line `plateSub` 13 (12, ExtraBold caps #ffe08a) with a bolt sprite. LineHeight 1.1.
* One Frame: AutomaticSize XY, UIPadding 5/12/6/12 (COMPACT 4/9/5/9), UICorner 10, UIGradient panel2 → deep α .95,
  UIStroke 1.5 `lift(c,.25)` (locked #4e4763; pulse: a 2 du white → lift(c,.4) → white gradient), shadow sprite.
  Plates live under `Plates`, which carries UIScale s, so they get the UI floors of §9.5.
* One RichText label: `NAME<br/>amount[<br/>READY]`, with the amount run in Sarpanch (`<font family>`) and the unit
  split per §9.9.
* **Names are whole words** (no "P. ENERGY"): the emblem symbol already names the family, so the plate shows the
  distinguishing word. m MILESTONE, mm META, em EXTRA, p PRESTIGE, pe ENERGY, sp SUPER, pb BOOST, pp POWER,
  se SUPER ENERGY, hp HYPER, ep EXOTIC, hb HYPER BOOST, ap ATOMIC, mp MULTIVERSE, t TRANSCEND, pm (masked as sent),
  pep PRESTIGED EXOTIC, cp CORRUPTED, cm CORRUPTED MILESTONE, ex EXPLORE, ach ACHIEVEMENTS. A name over 12 characters
  wraps to 2 lines. pm's redacted blocks render at α .6 in the hue, with the known letters bright.
* **Locked:** name #c9bfd0, then a lock sprite + `val.req` in `plateNum` soft.
* Text is written at ≤ 5 Hz and only when it changes.
* Size: WIDE ≈ 140 × 58 du with a READY line (46 without); COMPACT ≈ 110 × 40 (52 with READY).

**LOD**, with hysteresis ±.02:

| level | WIDE / MEDIUM | COMPACT |
|---|---|---|
| FULL | z ≥ .40 | z ≥ .30 |
| CHIP (amount only) | .28 ≤ z < .40 | .22 ≤ z < .30 |
| NONE | below that | below that |

The selected, hovered and peeked nodes always get FULL. The READY line and badges always show. On COMPACT, FULL shows
the amount only for READY, CAN BUY and selected nodes; the others show the name alone.

* **Occlusion:** a plate whose rect meets a HUD rect (capsule and pill, the Roblox buttons, dock, tray / pill, portal,
  visible toasts, and **the strip's right edge** while a sheet is open) first tries the slot **above** its ring, then
  the CHIP form, and otherwise fades to **α 0** over 0.15 s. No half-read ghost text, no half-cut plates at the sheet
  seam. Its ring stays.
* **Collision:** plates are placed greedily in priority order (selected > pulse > glow > available > locked, then by
  world y). A plate that overlaps a placed one by more than 4 pt first drops to CHIP, then fades. With the larger
  type the plates are about 35% taller, so the thresholds above are re-checked in the mocks (a, k) after this pass.
* Both are recomputed when z changes by 2%, the camera moves more than 8 pt, the HUD layout changes, or the node set
  changes. That is 21 rect tests.
* **Options › Map Labels:** AUTO (these rules) / ALWAYS (FULL at every zoom) / OFF (selected and hover only).

### 3.10 Edge markers (MarkerGui)

* Pulse and glow nodes whose ring is outside F get a marker: Ø50 (Ø38 COMPACT) emblem + white pointer + bolt or "!"
  badge.
* The marker sits where the ray from F's centre crosses F inset by 14 du, pushed out of HUD rects.
* At most **4** are shown, pulse first.
* Tap flies to the node. The marker pops in with Back Out 0.2 s.
* Mocks: d (MP, left) and k (MP up, MM down).

### 3.11 The rift (Multiverse gate)

* **Hotspot:** an invisible ImageButton ellipse, 520×960 world px at (3150, 1480), in `Nodes`, below PM.
* **Hover:** `rift_glow` +α .15, plus a tooltip:
  * sealed: title "The rift is sealed", body "Reach 185 milestones to reveal the Prestige Multiverse.", then two
    aligned rows "Need 185" / "Have 164" and the `gate.req` progress bar with its % (mock a);
  * revealed: the gate state line.
* **Click:** fly to the rift and open the gate popover (§7.8).
* The gate states themselves live on the portal (§4.6) and the universe tag (§4.3).

---------------------------------------------------------------------------------------------------------------------

## 4. HUD

### 4.1 Contents

| item | data | where |
|---|---|---|
| Points capsule | `hud.pts`, `hud.gen` (null → no pill), universe label from `map.inside`, warning chip from `hud.c` (value shown, e.g. "SOFTCAP e1.169e9"), status chip | TopbarGui, centred in `GuiService.TopbarInset` |
| Universe tag | `gate` (inside only): "Goal met: leaving will finish" + FINISH (hold 1.2 s), or "Goal not met: leaving exits early" + EXIT | TopbarGui, hanging under the capsule |
| Dock | HOME, TROPHIES (`N/18` badge, opens ach), OPTIONS (red dot while unsaved; white ring while open) | HudGui, bottom-left |
| Zoom capsule | `[−] 51% [+]` | HudGui, right of the dock; mouse only |
| READY tray | pulse nodes (+ `val.gain`), then glow nodes, in fixed map order | HudGui, bottom-right, left of the portal |
| Portal | `gate` | HudGui, bottom-right corner |
| Toasts + notification list | popups (`kind`) | OverlayGui, top-right of the free map rect |
| Edge markers | off-screen pulse and glow nodes | MarkerGui |

### 4.2 Placement

```
WIDE 1920×1080                                                          COMPACT 844×390
┌[RBX][chat]      ╭─ POINTS · NORMAL UNIVERSE ─╮          [···]┐      ┌[RBX][chat] ╭ e6.424e23 ╮           [···]┐
│                 ╰──── ↑ 6.21e24 OOMs/sec ────╯   ┌toast 400┐  │      │            ╰─ ↑ /sec ──╯  ┌toast 260┐     │
│ ░ chat area: no HUD in x<420, y<300 ░            │ toast   │  │      │ ░chat░       ▲ marker     └─────────┘     │
│                                                  └─+3 MORE─┘  │      │                                           │
│                                                               │      │                     ▼ marker              │
│ [HOME][TROPHIES][OPTIONS] [− 51% +]   ┌─ READY tray ─┐ (PORTAL)│      │ [HOME][TROPH][OPT]  (7 READY·TAP) (PORTAL)│
└───────────────────────────────────────────────────────────────┘      └───────────────────────────────────────────┘
```

| element | WIDE (du) | COMPACT (du) |
|---|---|---|
| capsule | 400×58 at y 6, centred in TopbarInset; drops below the bar (y 62, 0.2 s) if the strip < 200 du (unibar expanded) | 300×44 at y 6 |
| dock | buttons 64 (gap 20), caption pill **below** each button (`label` 14 Title Case, 22 tall); x 20, bottom 8 (the whole dock stays inside the 96 du bottom band) | buttons 50 (gap 18), caption pill `label` 13 (20 tall); x 12, bottom 6 |
| zoom capsule | glass 54 tall, after the dock | none |
| READY | tray (gem row, max 6 gems + `+N more`), right edge at W−170 | pill (≤ 3 mini gems + "N READY" / "Tap to list"); tap expands to the tray |
| portal | 140×160 (disc Ø112) at the bottom-right | 92×104 (disc Ø70) |
| toasts | 400 wide, y 68, pitch 84, max 3 (2 while the notification list is open) | 260 wide, y 58, max 1 (2 on tablets) |

**With a side sheet open** (WIDE/MEDIUM), everything re-centres on the strip:

* the capsule at the strip centre (x SX/2 + 40, clear of RBX/chat);
* the dock at the strip's bottom-left (56 du buttons);
* the READY tray collapses to the **READY pill** at the strip's bottom-right ("Tap a gem to switch"): each gem opens
  its layer;
* the portal is hidden: its function is the universe tag and the rift;
* the zoom capsule is hidden (wheel still works);
* toasts appear at the strip's top-right.

**COMPACT with a panel open:** the capsule is swapped for the panel band (§5.10). Toasts stay top-right, max 1.

### 4.3 Points capsule (the loved gold pill) — TopbarGui

```
Capsule     Frame 400×58, UICorner .5, UIGradient #2a2140→#0d0b16 α .04, UIStroke 2.5 + UIGradient #ffe89a→#ffc233 α .67,
            glow_rr gold α .6 (UIShadow if available), bevel_button overlay
├ Coin      Frame Ø68 at x −19 (breaks out): Radial #fff6cf→#ffd34d@.45→#a8761a, UIStroke 3 #fff1b8, sparkle sprite; spins 6 s/rev
├ Label     "POINTS · NORMAL UNIVERSE" / "POINTS · PRESTIGE MULTIVERSE", `caps` 13 #ffe9a3 (full alpha, hair spaces)
├ Amount    `capsule` Sarpanch Heavy 34, UIGradient W→#ffe89a→#ffc233, UIStroke 5 black + shadow clone (R4); steps 34→30→26
│           if > 250 du; anchored left (it ticks, §9.9)
├ Unit      "points" in Montserrat Bold 15 #ffe9a3 after a thin space (the §9.9 unit run)
├ GenPill   hangs at y 51: h 30, dark green gradient #1a7a3c→#0f4d26 (white ≥ 5.3:1), UIStroke 2 #b5f5c9, up sprite +
│           `Rich.num(hud.gen)`: the number in Sarpanch Bold 16, "OOMs/sec" in Montserrat Bold; no text outline
├ Warn      chip right of the capsule: gold stroke on a dark body, warn sprite + the first hud.c line's value (`label` 14);
│           tap → tooltip with all lines
└ Status    chip under the pill (`label` 14): SAVING… (gold) / NOT SAVING (danger) / RECONNECTING (info); SAVED shows
            1.5 s after a save
```

COMPACT: 300×44, coin Ø52, amount 28 (steps 26, 22), no caps label, the unit "pts" (`label` 13) while the amount is
≤ 150 du wide, pill h 26 / number 15. A tick bump (UIScale 1 → 1.05 → 1, 0.18 s) plays every second while points
grow. Numbers never tween.

**Universe tag** (inside the Multiverse), 40 tall (COMPACT 36): swirl sprite, status `small` 14 sentence case in
#ffd0dc ("Goal met: leaving will finish"), then the FINISH / EXIT hold chip: the verb in `label` 14 (13), dark ink
#2a1a00 on the gold gradient (≥ 10:1), with a small R6 ring sprite for the hold instead of a 9.5 px "HOLD" word.

### 4.4 Dock buttons

* `ImageButton`, UICorner 25%.
* UIGradient `lift(c,.2)` → c@.55 → `shade(c,.55)`, UIStroke 2.5 `lift(c,.55)`, `bevel_button` overlay, glow_rr hue
  α .55.
* Icon sprite at 48% size with a hard-shadow clone.
* **Caption** fully below the button, 2 du gap: a dark pill (#0d0b16 α .8, UICorner .5, padding 0/8) with the word in
  `label` 14 (COMPACT 13), **Title Case** ("Home", "Trophies", "Options"), white, no outline. Captions never overlap
  the bevel or each other: the button gap is at least the caption overhang (20 WIDE, 18 COMPACT).
* Hues: HOME #2fcf8f, TROPHIES #ffb020 (badge #b8860b `N/18`), OPTIONS #8a7cff.
* The active state gets a white 3 du stroke. Press: UIScale .94.

### 4.5 READY tray and pill

* **Entries:** every shown node with `val.pulse` (kind READY, gain chip `+val.gain` in gold), then every node with
  `val.glow` (kind CAN BUY, a "BUY" chip: danger stroke on a dark body, no "!"). Fixed map order inside each group,
  so nothing jumps.
  * Header: bolt sprite + "N READY" (`toast` 18, #ffe08a) and "· M can buy" (`label` 14, #ffb3c0).
  * The gesture hint ("Tap to open · hold to prestige", `small` 14 soft) shows only until the player's first
    successful hold; after that it lives in the gem tooltip.
  * Hidden when both are 0.
* **Gem:** a 52 du Frame circle (Radial gradient, symbol ≥ 18), the chip below (26 tall, `badge` 14 gold on #2a200a,
  short form for long gains per §9.9), **96 du pitch**. Max 6 gems + "+N more" (`label` 14 chip; tap →
  `frameNodes` + a list popover).
* **Tap a gem:** fly to the node and open its panel.
* **Hold a READY gem 0.6 s:** send `val.ra` (prestige), after the safety rules of §3.4.
  * A conical charge ring (R6) fills around the gem.
  * A two-line banner shows above the tray (mock h): "HOLDING · PRESTIGE <LAYER>  +gain" (`toast` 18 + the gain in
    `number` 16) over "Release to cancel" (`small` 14, #ffe9a3).
  * Releasing early cancels.
  * CAN BUY gems do not hold.
* **Pill** (COMPACT home, and the strip while a sheet is open): up to 3 mini gems (34 / 30 du, **2 du apart, never
  overlapping**, symbol ≥ 13 px) + "N READY" (`toast` 18 / 16) over "Tap to list" or "Tap a gem to switch" (`small`
  14 / 13, soft, sentence case), 4 du between the lines. Tapping expands it into the tray. The pill itself never
  holds.

### 4.6 Multiverse portal

* A Ø112 disc with a UIGradient **Conical** ring (#ff2e63, #b35cff, #ff5a1f, #ffd34d) rotating 8 s/rev.
* Inner void: Radial #05030b → #1a0a24 + swirl sprite.
* One glass pill (α .88, 2 du stroke in the state colour) hangs from the disc's lower rim, never wider than the
  portal box: WIDE "MULTIVERSE" (`tab` 16, white) over the state line (`label` 14 + `number` 14), 46 tall; COMPACT the
  state line only (`label` 13 / `number` 13), 26 tall. No text sits on the art without it (§9.7).

| state | from | pill |
|---|---|---|
| sealed | `gate.show == false` | "SEALED 164/185" (from `gate.req`; COMPACT "164/185"); the rift tooltip names the milestones; desaturated ring, no rotation; hidden entirely in first-run mode |
| locked | show, `!can` | LOCKED + lock sprite |
| enter | can, outside | ENTER, crimson aura |
| exit early | inside, `!fin` | EXIT EARLY, orange |
| finish | inside, `fin` | FINISH, gold aura breathing |

Tap: fly to the rift and open the gate popover (§7.8).

### 4.7 Toasts

The toast is the Figma Popup 4:91 at 400×72 (COMPACT 260×56):

* horizontal UIGradient `shade(k,.55)` → panel, UIStroke 2 k, hue glow;
* icon disc Ø44 (Ø32) (Radial);
* title `toast` 18 (16) with stroke 2, a ×N chip (`badge` 14 / 13 on #0d0b16 with a hue stroke), sub `small` 14 (13)
  in text α .92 (not soft: it sits on the hue gradient), one line, 4 du below the title;
* a 3 du life bar.
* Coalesced subs name the count or range ("3 achievements", "18th – 27th Meta-Milestone"), never joined names.
* `+N MORE`: a glass chip (α .88) 34 tall (COMPACT 30), bell sprite + `label` 14 / 13, hit area ≥ 44.
* Notification list rows: 56 tall, title `cardSmall` 17, sub `small` 14 soft; "Earlier" `caps` 13; CLEAR is a `label`
  14 text button with a 44 du hit area.

Kinds, from the view's `kind` (fallback: title/type/bColor):

| kind | colour |
|---|---|
| Milestone | gold |
| Achievement | info #7a8cff |
| Corruption fixed | lime |
| Challenge complete | gold, star icon |
| Notice | muted: saved, import result |

Rules:

* **Coalescing** per Q-O1. Milestone popups inside the Multiverse stay silent (game rule).
* **One location:** the top-right of the free map rect.
* Toasts are **click-through** (Interactable false). Only `+N MORE` takes input: it opens the notification list (the
  last 20, CLEAR; tapping a row flies to its layer).
* Enter: slide 60 du, Back Out 0.28 s. Exit: 0.2 s.

---------------------------------------------------------------------------------------------------------------------

## 5. Panel template

### 5.1 Form factor and protocol

| mode | geometry | map |
|---|---|---|
| WIDE | sheet backdrop from SX 760; card x 784, y 70, 1112 × up to 994 du; emblem breaks out top-left; close 52 at the top-right corner (y ≥ 56, under the Roblox "···"); **small panels hug their content** (min 560) | Box = strip (§3.6) |
| MEDIUM | card width clamp(.62·canvas.w, 900, 1112), right margin 16; full screen if the strip < 460 du | strip or disabled |
| COMPACT | full screen: band in the top-bar strip + a 226 du hero column + a scrolling content column (§5.10) | `MapGui.Enabled = false` |

**Protocol (C4).**

* **Open** sends `["tab", id]` once. The shell (emblem, title, hue, row) draws immediately from the node data. The body
  fills when `patch.tab == id`, with a skeleton for at most 1 frame.
* **Close** sends `map.close = ["tab","none"]`, through X, Esc, or a click on the strip's empty map.
* The client never re-sends `["tab", id]` for an open panel (that resets the subtab).
* There is **one Render tab tree**, re-skinned idempotently (`Style.child` get-or-create). Animations are keyed by
  `(layer, id)` from `a`, never by path id.
* Tabs that have content only while open (pm, cp, cm, pep Upgrades, ex Upgrades, ach) show the skeleton until their
  first patch.

### 5.2 Shell (WIDE)

```
Sheet (Frame 1112×H)
├ Rim         Frame, UICorner 22, UIGradient #221d33→#14111f@.28→#100d19, UIStroke 3 + UIGradient 135° lift(c,.4)→c@.4→shade(c,.55)@.75→c,
│             glow_rr c α .45 + black depth shadow (UIShadow if available), inner top lip (bevel_card)
├ HeaderBand  Frame h 90, UIGradient 0° mix(panel,c,.22)→transparent; stripes tile (standalone texture) α .035
├ HeaderRule  Frame h 2 at y 92, UIGradient c→α .75→1, glow
├ Emblem      Ø96 at (−18,−22): Radial lift(c,.6)/c@.45/shade(c,.4), UIStroke 3 lift(c,.5), bevel, glow_circle c α .9 (R7, R2)
├ Title       `title` Heavy Italic 44, UIGradient W→lift(c,.45), UIStroke 7, shadow +4 (R3), at (96,10)
├ SubRow      at y 60: chip "ROW 1" / "MULTIVERSE · ROW 1" (`label` 14, 26 tall) + the verb line in `small` 14, sentence
│             case, soft ("Resets for prestige points", "The root of the tree"). When a status chip is present
│             (INFECTED), the verb line is dropped
├ Tabs        in the header, right-aligned (y 24), when there are ≥ 2, 40 tall (Figma Tab 4:55): active = `tab` 16
│             ExtraBold Italic white on the hue gradient + glow (stroke 2); idle = `tab` 16 ExtraBold **upright** soft on
│             panel2; Notify dot
├ Close       ImageButton 52, UICorner 14, danger gradient, UIStroke #ffc2cc, bevel; X sprite; hover rotates 90°
├ Hero        §5.3 (pinned, not scrolling)
└ Body        styled Frame (UICorner, gradient) holding a transparent ScrollingFrame (§5.8)
```

Corrupted layers (cp, cm):

* body `black → #041a06 → #062b0a` + a scanline tile α .025;
* rim UIStroke 3 lime, **dashed** (R8), lime glow;
* RobotoMono for system text;
* terminal tabs `> CORRUPTIONS`;
* a breadcrumb `C:\MULTIVERSE\CORRUPTED>_`;
* a glitch title (R12).

### 5.3 Hero (y 104–256 WIDE)

* **Left: resource block.** "YOU HAVE" `caps` 13 soft, then the amount **`hero` Sarpanch Heavy 56** (UIGradient
  W@.08 → lift(c,.5)@.5 → c@.92, UIStroke 7, shadow +5, Radial glow blob 470×150 behind it at α .35). Long values step
  56 → 48 → 40 to fit 560 du.
  * Resource name `resource` 22 `lift(c,.6)`; a name over 20 characters ("INFECTED SUPER PRESTIGE POINTS") steps to 18.
  * Effect line `body` 16 in soft, up to 2 lines (RichText, colours remapped). Hidden when `eff` is null, which the
    view sends instead of the "undefined" quirk.
* **Right: CTA** 400×96 (static and locked 400×110; Figma Prestige Button 4:47 at 1.2×):
  * **Can:** UIGradient `lift(c,.15)`/c/`shade(c,.55)`, UIStroke `lift(c,.5)`, bevel, glow α .6, and a shine sweep
    (R5) every 2.8 s.
  * Title = the verb (PRESTIGE, GET +1 MILESTONE, COLLECT, EXPLORE, CORRUPT), `cta` Heavy Italic 26 + UIStroke 6,
    ≥ 12 du side padding (steps 26 → 22 when wider).
  * Gain line in a **value well** (R15, 26 tall): `+reset.gain` in `ctaSub` Sarpanch Bold 17 + the short unit
    ("PP", "SP", "EXP") in Montserrat Bold 14 (§9.9). No outline.
  * **Static layers** replace the gain with the `pr` bar and "40%" (`number` 16) at its right.
  * **Locked:** grey gradient, title kept, the `pr` bar with "40%", and a well "need e1.057e60 points" (`small` 14).
    Never "have / need" as two raw exponents. No glow.
  * A requirement line (ex "Req: …") never sits on the fill: it becomes a stat chip under the CTA.
  * The hotkey keycap (from `reset.hk`, `label` 13 dark ink on a 26 du light cap) shows **only when PreferredInput =
    KeyboardAndMouse**.
* **Stat chips** under the CTA (34 du, one row, 8 apart): resource-display lines as `LABEL ········ VALUE`, the label
  `caps` 13 soft, the value `number` 16 (word values such as "ON · META MILESTONES" in `label` 14)
  (POINTS e6.424e23 · PASSIVE +e1.073e25/s · AUTO-GET ON · PRESTIGE ASHES …).
* A divider at y 262. The body starts at y 272.

### 5.4 Prestige feedback (juice)

1. Press: UIScale .94 (0.08 s), then Back Out.
2. A burst ring (ring sprite, Ø120 → Ø360, α .6 → 1, 0.45 s) + 10 sparkles.
3. A **"+gain" floater** (Sarpanch Heavy 28 gold) flies from the CTA into the hero amount (0.6 s Quad Out).
4. The hero amount bumps (UIScale 1.12 → 1) and its glow flares.

ReducedMotion keeps a 0.1 s colour flash only. Buy an upgrade: card UIScale 1 → 1.06 → 1, a white flash α .5 → 1
(0.25 s), 8 sparkles, the chip swaps BUY → OWNED, and the card eases into the quiet tier (0.3 s).

### 5.5 Sub-tabs

Tabs sit in the header (§5.2) and send `["subtab", …]`. A single-tab bar (Main only) is hidden. Notify = a 10 du danger
dot. The newly active tab gets UIScale .92 → 1 (0.15 s).

### 5.6 Sections

The client inserts section titles from `cn`, grouping consecutive components of one kind. A title is:

* a 6×26 hue bar;
* `section` Heavy Italic **24** (COMPACT 22) with a UIGradient + UIStroke 5 (4);
* chips (28 tall, `label` 14 words + `badge` counts; READY in the hue, OWNED green);
* a hairline UIGradient c α .45 → 0;
* a right-side control, or a hint of ≤ 6 words in `small` 14 soft, sentence case. Hints that repeat a chip, a card
  strip or the CTA are dropped.

| cn | title | chips | right |
|---|---|---|---|
| buyables | BUYABLES | n | none (the card's hold strip says "HOLD TO BUY"; the ⓘ explains the rest) |
| upgrades | UPGRADES | **N READY** (hue) + **owned / total OWNED** (green) | "Hide owned" mini toggle (`label` 14, session memory) |
| milestones | per layer: MILESTONE LADDER, META LADDER… | done / total | "Newest first ▸" button (`label` 14; opens the Options order) |
| challenges | CHALLENGES | done / n | — |
| achievements | TROPHY SHELF | n / 18 | — |
| clickables | per layer (§6) | — | — |
| grid | C:\CORRUPTION\DISKS (terminal window header) | cols × rows · n CORRUPTED · n FIXING | — |
| display-text / raw html | none: **NOTES rows** (ⓘ + the game's line verbatim; no parsing) | — | long explainers collapse to one line + "MORE ▾" |
| blank, h-line, v-line | dropped | — | — |

Rhythm: WIDE body padding 32, section gap 28, title → content 14, card gap 12. COMPACT: 12 / 16 / 10 / 10.

### 5.7 Cards and states

| widget | can (actionable) | owned / done / maxed (quiet) | not yet (unlocked, unaffordable) | locked |
|---|---|---|---|---|
| Upgrade 5:47, 237 × auto (min 232, AutomaticSize Y) | hue surface `mix(panel,c,.38)→mix(deep,c,.15)`, stroke gradient, **glow α .55**, BUY chip, shine sweep (top band only), "Currently" value, COST white | `mix(panel,#4be07a,.14)`, stroke α .45, **no glow**, "✓ OWNED", footer: the effect value (✓ + value) or "✓ Active" | mauve surface, **pr% chip + 5 du bar**, COST #d9b3be | dim mauve, lock chip, the requirement text (≤ 4 lines), no cost |
| Compact owned, 237 × auto (72 with a 1-line title, 88 with 2) | — | index + title (2 lines allowed) + ✓ + the effect value: used for **fully owned tiers** in their slots | — | — |
| Buyable (wide ≤ 2 per section, else a 280 grid), 700 × auto (min 132) | hue surface; **hold strip lit "HOLD TO BUY"** (fills while held) | "MAX" green | mauve; hold strip = the reason ("Not enough PP") + the pr bar and % inside the card | — |
| Challenge 5:173 | idle hue, START | done green, COMPLETED, `cmp/lim` | — | requirement |
| Challenge active / completable | gold, EXIT EARLY / **FINISH** (glow) | | | |
| Milestone row | NEXT = spotlight card, 116 tall (78 du pill, glow) | done = quiet green row, 60 (title line + effect line; 78 with a 2-line effect) | future = faint pill + cost | infected = danger stroke + glitch stripe + second effect line |
| Perk 5:58 | gold dashed (R8) "EXPLORE A NEW PERK" | | | mauve dashed |
| Achievement 5:180 | — | gold medallion + star + glint | — | "?" slate |
| Corruption tile 104 | Trojan: lime dashed; Backdoor: **crimson dashed**; active / chosen: gold + fix bar | fixed: green solid | — | empty: quiet, slot number only (#5f8a58, 13) |

**Card type** (§9.2; WIDE / COMPACT). Everything grows with its text; nothing is clipped by a fixed card height.

| part | upgrade card | compact owned | buyable | milestone NEXT / done / fold |
|---|---|---|---|---|
| padding | 16 / 12 | 12 / 10 | 16×18 / 12 | 14×18 / 12 |
| index / level | `index` 28 / 22, lift(c,.5) α .8 (owned: soft α .8) | `badge` 14 soft | "LV" `caps` 13 + `big` 44 / 30 | pill number `number` 16 |
| title | `card` 20 / 18, Title Case, ≤ 2 lines | `cardSmall` 17 / 16, ≤ 2 lines | `card` 20 / 18 | NEXT `card` 20; done `cardSmall` 17 |
| text | `body` 16 / 15, LH 1.3, ≤ 4 lines, text α .92 (owned α .82) | — | effect `body` 16 / 15 | desc `body` 16 / 15; done effect `small` 14 soft (≤ 2 lines); fold: headline fact only, `small` 14 soft |
| labels | "Currently", COST `caps` 13 / 12 (text α .92 on BUY, soft elsewhere) | — | NEXT LEVEL `caps` 13 | NEXT MILESTONE, REQUIRES `caps` 13 |
| values | Currently: `number` 16 in a well; COST `numberHeavy` 18 / 17, 10 du above the bottom edge | effect `numberHeavy` 18 / 17, #a5efbc, ✓ before it (no "EFFECT" label) | NEXT LEVEL `numberHeavy` 18 | need `numberHeavy` 18 + unit `label` 14; % `number` 16 |
| chips | BUY / OWNED / LOCKED `label` 14 (28 tall); pr% `badge` 14 | — | hold strip 32 tall, `label` 14 caps | fold count `badge` 14; SHOW ALL is a `label` 14 button on the right |

**Tier board (WIDE upgrades).**

* One row per game row (11–14, 21–24…), with a 44 du **tier rail**: a badge "1" / "2" / "3" (Arabic, `badge` 16 in
  Sarpanch) on a glowing spine. An owned tier shows the ✓ on the spine beside the badge, not inside it.
* The row height is the tallest card in it (cards stretch to it). A fully owned tier shows its compact owned cards in
  the same slots, and the rail turns green. Slots never regroup across rows, because the ids are path-stable.
* Perk slots sit inline.
* COMPACT: all owned upgrades fold into **one summary row**, 48 tall: "✓ 14 OWNED" (`cardSmall` 16) + "Show"
  (`label` 13) and a chevron. **No effect values on the row**: expanding lists each owned upgrade on its own row with
  its name and effect (`body` 15). Then the remaining cards in index order (mock l).

Glow budget: ≤ 2 glowing elements per card and ≤ 24 per panel. Owned and locked never glow.

### 5.8 Scrolling and virtualisation

* A styled Frame holds a transparent ScrollingFrame: `AutomaticCanvasSize = Y`, `ScrollBarThickness = 6`,
  `ScrollBarImageColor3 = lift(c,.3)`, `ElasticBehavior = WhenScrollable`, `ScrollingDirection = Y`.
* An 80 du bottom-fade Frame sits on top (not interactive).
* The scroll position is remembered per layer/subtab for the session.
* **Touch safety:** a hold (buy, grid, click) starts after 120 ms with < 10 pt of movement. Earlier movement means a
  scroll, never a buy.
* **Virtualisation** for lists over 60 rows (the expanded m ladder, t's 28 upgrades, the mp buyables): a pool of fixed
  rows (viewport + 2), repositioned on `CanvasPosition`, with a spacer Frame.

### 5.9 Empty, locked and loading states

* **Locked layer** (opened from a locked node): the hero shows a lock emblem, "LOCKED" and `val.tip` with a `pr` bar.
  The CTA is in its Locked variant. The body is inert and its surfaces dim to the mauve locked tier; its text stays
  ≥ 4.5:1 (§9.6).
* **Empty section after hiding:** a slim row with an OPTIONS link (Q-P3).
* **Skeleton:** 3 shimmer bars (UIGradient Offset sweep 1.2 s).

### 5.10 COMPACT panel (phones)

* **Band** (TopbarGui, TopbarSafeInsets, 56 du; mock l / m): emblem 42 + `title` 27 (steps 24, 22 to fit) + ROW chip
  (`label` 13).
  * The **READY switcher**: 3 mini gems (28, 2 du apart, no overlap) + "+N" (`badge` 13) + a bolt, 38 tall. Tapping
    a gem opens that layer.
  * A **44 du close** left of the Roblox "···".
  * A neon rule under the band.
* **Hero column** (x 10, 226 wide, full height, left thumb): YOU HAVE (`caps` 12) + amount (`hero` 38, steps 34, 30) +
  resource name (`resource` 18) + stat chips (32 tall, `caps` 12 + `number` 15, one per row). The hero column uses its
  height: no empty flex gap above the CTA larger than 24 du. The **CTA is pinned at the bottom** (200×80; static and
  locked 200×96 with the `pr` bar): `cta` 20 (steps 18, 16 to keep 12 du side padding), the gain `ctaSub` 15 in a
  well, the % `number` 15.
* **Content** (x 248 → 832): section titles `section` 22, cards in 2 columns (upgrades, 284 wide, auto height ≈ 190
  with a 3-line description) or rows (buyables auto, min 96; milestone done rows 56, 2 lines), an ⓘ button on
  buyables, the owned summary row (48, no effect values), and the scrollbar at the right edge. Body text is 15 with
  LineHeight 1.3; labels 12; chips 26 tall.
* Toasts: top-right under the band, max 1, click-through.

---------------------------------------------------------------------------------------------------------------------

## 6. Per-layer signatures

Every panel uses the template. Each signature adds **one hero idea**, an **accent treatment** and at most **one bespoke
widget**, so no two panels read alike. "Hug" means the sheet height hugs its content (min 560 du).

| layer (hue) | hero | accent | sections (after the hero) | bespoke widget / behaviour | motion |
|---|---|---|---|---|---|
| **m** Milestone (#b35cff) | count "164 MILESTONES" + GET +1 MILESTONE (`pr` bar, M keycap) + AUTO-GET chip | violet; the ladder spine glows | NOTES (the game's display-text lines) → MILESTONE LADDER → MALWARE | **Ladder:** NEXT spotlight (REQUIRES + pr), 4 newest done rows (quiet), decade folds naming their unlocks, "1 – N SHOW ALL" (virtualised pool of 16). WIDE right column: NOTES + JUMP TO (NEXT + 25-blocks + MALWARE) + order/filter chips mirroring Options. MALWARE: infectable rows with **INFECT** (bug sprite + cost; lit when affordable). Honours Milestone Showing Mode and Order. (mock c, m) | new milestone: NEXT flashes gold, slides into done (0.35 s), the new NEXT slides in |
| **mm** Meta Milestone (#d17aff) | count + GET +1 (AUTO chip when em.best ≥ 1) | orchid; "M²" watermark | META LADDER (30) | same ladder, no malware | same |
| **em** Extra Milestone (#e88af2) | count + GET +1 (auto at m.best ≥ 170) | pink; "M³" watermark | EXTRA LADDER (19) | same ladder | same |
| **p** Prestige (#6fc3ff) | PP + PRESTIGE (P) + POINTS / PASSIVE | sky blue; header stripes | BUYABLES (wide + progress box) → UPGRADES tier board (rows 11–53) | perk slots (15/25/35/45 with malware m4; 51–53 in sp C11) as dashed gold cards; RESPEC PERKS small danger button in the UPGRADES title row (mock b, l) | shine on BUY; buy burst |
| **pe** Prestige Energy (#ff9a2e) | energy + COLLECT (E) with pr | orange; lightning watermark | rate chip ("×a per OoM of PP, ^b") → UPGRADES (8, 2×4) | none; **hug** | crackle on COLLECT |
| **sp** Super Prestige (#5fe0ff; infected → danger emblem; malware tabs → **ember #ff7a2e** accent) | SP + PRESTIGE (S); tabs Main / Prestige Ashes / Spark Milestones | cyan; ember rim on the malware tabs | Main: BUYABLES (2) → UPGRADES (17, perk 51). Ashes: ashes stat → challenge 11. Spark: furnace box → SPARK MILESTONES → pager | **Furnace** (the game's unlock box as a titled card: flame emblem, ashes bar, 3/3 UNLOCKED, IGNITE + auto-fill state, REIGNITE #n). **Ember burn bars** (a real `bar` node: p + st8): BURNING (flame gradient + ember sprites), ASHED (grey), PERMANENT (gold "skipped when burning"). SHOW cycler 1/3/5 (one press). Pager « ‹ Page a / b › » at 52×44, **hidden when there is one page**. Challenge 11 "Milestone Dilation" is a round 330 du portal card with a conical ring. (mock f) | embers rise from burning bars (≤ 6 per bar, none on LOW) |
| **pb** Prestige Boost (#57e0b0) | amount + GET; **power badge** "^x" (hexagon sprite, Sarpanch Heavy 40) | mint | UPGRADES (16) | power badge from main-display eff | badge pulses once per purchase |
| **pp** Prestige Power (#ff4d6d) | PP + PRESTIGE (W); "X Hz" Sarpanch Heavy 40 over an **oscilloscope strip** | crimson-pink | BUYABLE Power Scaler (wide) → UPGRADES (9, 3×3) | wave tile texture (standalone, ScaleType Tile) scrolled by Position | wave scroll; frozen with ReducedMotion |
| **se** Super Energy (#ff6a1f) | amount + COLLECT (Shift+E) | deep orange | rate chip → UPGRADES (4, one row) | none; **hug** | crackle |
| **hp** Hyper Prestige (#7fd9ff) | HP + PRESTIGE (H) | icy cyan; frost corner sprites | BUYABLES (2) → UPGRADES (16) | none | slow shimmer (5 s) |
| **ep** Exotic Prestige (#9be02c) | EP + PRESTIGE (X) | acid green | **EFFECT LADDER** (the 1st–8th effect lines the game sends) → BUYABLE Exotic Fusioner (docked) → UPGRADES (6) | rungs in milestone-row style; lines in `class='ef'` get a gold EMPOWERED chip; no rungs are invented | a new rung lights bottom-up (0.4 s) |
| **hb** Hyper Boost (#6dffb0) | amount + GET (Shift+B); two power badges | pale mint | UPGRADES (12) | badges as pb | as pb |
| **ap** Atomic Prestige (#8ff3f3) | AP + PRESTIGE (A); **atom orbit** on the emblem (two conical rings) | aqua | **CHALLENGES** (8, 4×2, the active one pinned with a gold ribbon) → BUYABLE Challenge Slayer → UPGRADES (12) | challenge grid as the main section | orbit rotation |
| **mp** Multiverse (#ff5a1f) | MP + GET (V); tabs Main / Upgrades / Fusioners / Scalings | **split rim** violet→crimson | Main: **PORTAL CARD** (challenge 21, full width) → CHALLENGES (4, "N completions"). Fusioners: MODE (2-option segmented, one press) → BUYABLES (6) + RESPEC. Scalings: level tiles | portal card = the gate popover's content (same `["chal","mp",21]`, same 1.2 s hold, the reset list) | swirl rotation; FINISH breathes |
| **t** Transcend (#ffe93a; dark text on yellow fills) | TP + PRESTIGE (T); **crown rays** behind the emblem | gold crown | Main: NOTES → CHALLENGES (6). Upgrades: tier board (28, 7 tiers, owned tiers compact, virtualised). Special: SPECIAL POINTS | **relic grid**: 6 tiles (kind, amount Sarpanch 28, effect, BOOST / CHOOSE) + RESPEC | rays 30 s/rev |
| **ach** Achievements (#ffc93c) | "13 / 18" Sarpanch 64 gold + the effect line | gold shrine | TROPHY SHELF | 2 shelves × 9 medallions on plank Frames; tap = an inspector strip (name + goal/done); hover = tooltip. No CTA. | a glint crosses one done medallion every 3 s |
| **pm** Prestige Milestone (#ff2e63) | count + GET (Ctrl+P); **glitch title** (R12); the masked name as sent | crimson; scanline α .05 | Main: debuff tile (red) + essence tile → PRESTIGE MILESTONE LADDER (16). Challenges: completions → "Current Unlocked Boosts" titled card → CHALLENGES (3, gold when completable) | glitch title; the resource-name flicker is kept as sent | glitch bursts 2–4 s, 80 ms |
| **pep** Prestiged-Exotic (#f2b04d) | PEP + GET (Ctrl+X) | amber **fusion core** (conical ring around the fusioner level) | EFFECT LADDER (5) → (Pr) Exotic Fusioner. Upgrades: 3 | effect ladder as ep | core ring rotation |
| **cp** Corrupted Prestige (#39ff14, symbol **CR**) | CAUSED / FIXED counters (Sarpanch 52) + essences line + **CORRUPT** (black glossy, lime, scanlines, CTRL+C, "n / 20 charges · next at X") | Corrupted treatment, terminal tabs, breadcrumb, RobotoMono | ESSENCE & RECHARGE MODE (radio, one press) → **DISK GRID** + inspector → explainer (one line + MORE) | **Disk grid** 4×4 → 6×6 of 104 du tiles from `grid.state/lv/kind`: empty = quiet slot number; Trojan lime dashed; Backdoor crimson dashed; active or algorithm-chosen gold + fix bar; a legend. **Inspector**: `grid.tip` split into fix / debuff / reward, pr shown **once** as the game's ASCII bar `[██████====] -< 63% >-` (the graphic bar is dropped), DEACTIVATE, other corruptions list. It docks on the side set by **Corrupt. Tooltip Pos.** (mouse); touch always uses the inspector. Antivirus: buyables + TrojanFix.scr / BackdoorRemove.scr process cards with conical cooldown rings. (mock d) | scanline scroll, cursor blink 1 s, glitch bars on a corruption; lime "CORRUPTION FIXED!" toast |
| **cm** Corrupted Milestone (#1fbf4a) | count + GET (C+M) | Corrupted treatment, darker green | CORRUPTED LADDER (5) | small lime terminal ladder; **hug** | cursor blink |
| **ex** Exploration (#45e07f) | EX + EXPLORE (Ctrl+E) + ZONE / AREA LIMITS chips | green cartography: 40 du grid tile α .05 | Main: **MAP** + **D-PAD** → feature tiles (new feature at (x;y); the danger line "new feature at zones: …"). Upgrades: 2. Rewards: the game's per-zone list | **Map**: the ZoneMaps SVG redrawn as Frames (cell lines, border), **cached by svg string**; position = a green gem, goal = a star sprite, portals (m14) = swirl sprites. **D-pad**: the 4 movement buyables as arrow keys around RESPEC POSITION, each with a level badge ("→ 6") and its cost in a well (short unit, full name in the tooltip); the arrow keys and R stay the game's hotkeys. **Hug** (mock e) | the position gem hops (0.15 s Back Out) |
| **Options** (#9d8cff) | gear emblem; no hero | bevel cards, section tags | **YOUR SAVE** (SAVED WITH YOUR GAME): status card ("ALL PROGRESS SAVED · saves live on the server for this Roblox account" / UNSAVED), SAVE / EXPORT / IMPORT tiles, Offline Production toggle · **DANGER ZONE**: HARD RESET… → modal (§7.7) · **ABOUT**: credits + the unlocked hotkeys (keycaps) · **DISPLAY** (SAVED WITH YOUR GAME): Milestone Showing Mode **cycler** (5 dots), Completed Challenges toggle, Corrupt. Tooltip Pos. **cycler** (4), Milestones Order segmented (2 options = one press) · **THIS DEVICE** (NOT PART OF THE SAVE): Motion SYSTEM/FULL/REDUCED, Map Detail AUTO/HIGH/LOW, Map Labels AUTO/ALWAYS/OFF, Interface Size 90/100/115% | game options send `["opt", …]`, one press per tap. Device options are client-only: stored in a separate DataStore key `client` through a tiny remote, never in the save string; `Player:SetAttribute` mirrors them for the client. (mock g) | tiles sweep on hover |
| **End screen** (`ended`) | full-screen OverlayGui over the frozen, dimmed map: gold rays + trophy emblem, "YOU BEAT THE GAME!" Heavy Italic 64 gold, winText, "IT TOOK YOU T" chip | gold | KEEP GOING (gold primary, `opt keepGoing`) · PLAY AGAIN (danger outline, **hold 2 s**, `opt playAgain`) | **no Discord line**; only `opt` actions run | confetti once (≤ 40 sprites) |

### 6.1 Type and density per signature

The template roles (§9.2) apply everywhere. These are the per-layer adjustments; each replaces a small or crammed run
in mocks b–j with one readable one.

* **m / mm / em ladder.** NEXT: `card` 20 title, `body` 16 desc, REQUIRES `caps` 13, the need `numberHeavy` 18 with
  the unit in Montserrat, % `number` 16. Done rows put the title and the effect on separate lines. Fold rows show the
  range (`number` 16), the count (`badge` 14) and one headline fact; SHOW ALL is a real button. NOTES: `body` 15
  LH 1.3 with inline numbers in Montserrat Bold (same x-height, no Sarpanch in running text). JUMP TO: `label` 15
  rows with soft chevrons. Filter chips become labelled buttons ("Show: All ▸", "Order: Newest first ▸", `label` 14).
  MALWARE: the "9 infectable" chip in `label` 14; **INFECT** buttons 44 tall: "INFECT" `label` 15 on one line, the
  cost `number` 15 beside it.
* **p.** The buyable's side box "Progress to next level" is dropped; its bar and % move inside the card under the
  cost. The tier badges are Arabic.
* **sp furnace**, two rows. Row 1: the ashes bar with "0.00 / 225.74 ashes" (`number` 16 + `label` 14). Row 2:
  IGNITE (title `tab` 16 + a separate ON/OFF toggle pill, `label` 13) and REIGNITE #2 / #5 buttons
  (`label` 14, cost `number` 14 + "ashes" in Montserrat). The gold "3 / 3 unlocked" chip uses dark ink #2a1a00. The
  hint line is dropped. **Spark rows**: ASHED dims only the surface and the state tag; the title stays #d9d3ec
  (`card` 20), the desc `body` 16 at α .82, "Currently" `caps` 13. Percentages to 1 decimal ("63%"); "Skipped when
  burning" in `small` 14, not Sarpanch.
* **cp terminal.** `terminal` 15 / 14 for the tabs, path, paragraph and footer; labels #9fdc92 at minimum, body
  #caffbf. Inspector keys and the mode subtitles in `small` 14 (Montserrat); values `number` 16 with units in
  Montserrat Bold; the "you have" line `small` 14 soft. The essence line becomes two stat rows ("Corruption essences
  e569,142,978", "Points & PE gain ×e423,228,229"; labels `small` 14, values `numberHeavy` 18); the parenthetical
  goes to a tooltip. Disk tiles 104: kind `caps` 13, "LV 3" `big` (step 24), slot id `label` 13 soft; empty slots #5f8a58
  (5.3:1). Legend `small` 14. CORRUPT's sub splits into "1 / 20 charges" and "next at 2,000,000 pts" (`terminal` 14);
  the CTRL+C keycap is `label` 13 in a 26 du cap. The footer explainer gets 2 lines before MORE.
* **ex.** D-pad keys 132×112: arrow + label `label` 16; the level as a dark badge ("↑ 0", `badge` 14); the cost in a
  well (`number` 14 + "PE" / "CE", full name in the tooltip). Map axes `number` 14 in #9fdc92; legend `small` 14;
  coordinates "6, 4"; the zone list as small chips.
* **Options.** Card titles `card` 20 with a tag chip (`small` 14, sentence case: "Saved with your game" / "Not part
  of the save"). Rows 64 tall: title `cardSmall` 17 (full names:
  "Corruption tooltip position"), subtitle `small` 14 soft LH 1.3, one sentence. Segmented controls 38 tall, options
  `label` 14 (idle ExtraBold soft upright, selected ExtraBold Italic white); cyclers `label` 15 with "Newest first" /
  "Oldest first" wording instead of an arrow. SAVE / EXPORT / IMPORT tiles: the title `cta` stepped to 20 (white + stroke), the sub
  `small` 14 in a well with 10 du side padding. ABOUT: `body` 16; hotkeys fold behind "Show hotkeys", keycaps `label` 13 in 26 du
  caps. DANGER ZONE text `body` 16 #f2d7dd.
* **End screen.** The win text is `body` 16 on a scrim band (black α .45, UICorner 12), balanced into 2 lines; "IT
  TOOK YOU" `caps` 13.

---------------------------------------------------------------------------------------------------------------------

## 7. Overlays (OverlayGui)

1. **Tooltip** (Figma 4:68): 360 du (COMPACT 300), UIPadding 14/16, UICorner 14, UIGradient panel3 → panel, UIStroke
   1.5 `lift(c,.2)`, shadow + hue glow.
   * Title `cardSmall` 17 `lift(c,.55)`; body `body` 16 LH 1.3 RichText (≤ 5 lines); have / need as two aligned rows
     ("Need 1e413,950 HP" / "Have e8.502e20 HP", labels `small` 14 soft, values `number` 16) + the `pr` bar with its
     %; foot `small` 14 soft, sentence case ("Click to open · right-click to peek").
   * Mouse only, after 250 ms, at the cursor + (16, −h−12). It flips to the side with fewer node rects and is clamped
     to the viewport. One owner at a time.
2. **Peek** (long-press 450 ms / right-click on a node; mock j):
   * The node grows ×1.25.
   * Scrim: a Frame α .62 plus a **square** Frame centred on the node with a Radial UIGradient transparency hole. A
     radial gradient on a full-screen frame would be elliptical, since its radius is (w+h)/4.
   * A 360 du card (COMPACT 320): emblem, name (`card` 20), amount (`number` 16 + unit `small` 14; "0" gets its unit,
     "0 milestones"), the `val.tip` line as `body` 16 have / need rows, **OPEN** (`tab` 16), and the **PRESTIGE** hold
     button (`tab` 16, one line, an R6 ring glyph before the verb shows that it holds) with the gain as a `badge` 14
     chip at the right (0.6 s; the hold fill darkens, R13; only when `val.ra` exists). Buttons 52 tall. A locked node shows its requirement instead.
   * Dismiss: tap the scrim, pan, or Esc. While a peek is up, toasts collapse to the newest.
3. **Toasts** §4.7; the **notification list** opens from `+N MORE` (mock h).
4. **Detail sheet** (touch; long-press an upgrade, or ⓘ on a buyable): a full-width bottom sheet with a drag handle,
   the full text (`body` 16 / 15, never clamped), CURRENTLY / COST / YOU HAVE (`caps` + `numberHeavy`) + pr, and the
   big action (BUY / HOLD TO BUY). Holds happen here, away
   from the scroll list. Dismiss: tap outside or drag down 60 du.
5. **Modal chrome:** a dimmer (black α .6, `Active = true`, `InputSink = All`) and a bevel card with a hue rim. Open:
   scale .96 → 1 (0.2 s).
6. **Export** (mock i): a read-only monospace TextBox (`terminal` 15 / 14, `TextEditable = false`,
   `ClearTextOnFocus = false`, TextWrapped, inside a styled Frame).
   * On open: CaptureFocus + select-all (`SelectionStart = 1`, `CursorPosition = #text + 1`).
   * Chip "22,204 characters · all selected" (`label` 14; the count in `badge`).
   * Hint (`body` 16 LH 1.3): "Press Ctrl+C to copy. On a phone: tap the box, then Select All and Copy. (Roblox games
     cannot write to your clipboard.)"
   * Buttons: SELECT ALL (primary; a darker teal gradient `shade(c,.2)` so white passes 3:1 without the outline),
     DONE.
   * **Fallback** where read-only select/copy fails on mobile: an editable TextBox whose Text is restored whenever it
     changes.
7. **Import:**
   * An editable TextBox (`terminal` 15, placeholder "Paste a save string (web saves work too)" in `small` 14 soft);
     IMPORT is disabled while the box is empty.
   * After a press: a **conical cooldown ring** for the server's 10 s `IMPORT_COOLDOWN` ("IMPORT · 4 s"). Disabled
     labels are `label` 15 upright soft; the ring carries the disabled meaning.
   * The result is shown inline: "That string is not a valid save (nothing was changed)." in danger; success closes
     the modal and shows a Notice toast.
   * **Hard reset confirm:** "HARD RESET?", what is lost (`body` 16), EXPORT FIRST · CANCEL · **HOLD TO RESET 2 s**
     (conical ring; the footnote "Release early to cancel" in `small` 14). Completion sends `{"opt","hardReset"}` twice, then a red edge flash + a Notice toast.
8. **Gate popover** (portal / rift / universe tag):
   * Conical swirl emblem, PRESTIGE MULTIVERSE (`section` 24), the context "MP challenge 21 · you are inside"
     (`small` 14 in the hue), a GOAL box (`gate.goal` in `body` 16; the state as a 14 du chip, "Goal met" green),
     completions (`done ≥ 1` = won). The consequence text is `body` 16.
   * **What happens:**
     * ENTER lists the layers that reset: the game's `onEnter` list, m mm em p pe sp pb pp se hp ep hb ap t.
     * FINISH: "completes it (+1) and returns you".
     * EXIT EARLY: "returns you without completing".
   * The action is a **1.2 s hold** with a conical ring (STAY / HOLD TO ENTER | EXIT | FINISH): the label `cta` (step 22) in
     white + stroke on a darker amber gradient (#b37400 → #6b4500), the time as a separate `badge` 14 chip. Locked
     shows a disabled bar "Unlock Multiverse (MP) first" (`label` 15 soft).
9. **Status** (TopbarGui, under the capsule; `label` 14, 28 tall): SAVED (green, 1.5 s after a save), SAVING… (gold,
   while `patch.unsaved`), NOT SAVING (danger; the data failed to load, tooltip explains), RECONNECTING… (info).
10. **Loading / fatal:**
    * Loading: a realm thumbnail card, "THE MILESTONE TREE" gradient title, a progress bar from the PreloadAsync count,
      "LOADING THE REALM…" (`caps` 13).
    * A render failure first auto-resyncs once (re-sends Ready), then shows **OUT OF SYNC · RESYNC**.
11. **End screen:** §6.
12. **First run** (while m.best == 0; mock n):
    * The READY tray, portal, zoom capsule and rate pill are hidden.
    * A **START HERE** pointer chip bobs above M, whose plate reads "⚡ READY". It is stacked: "START HERE" (`toast`
      18 / 16) over "Get your first milestone" (`body` 16 / 15, white), on a darker chip body `shade(c,.35)` so the
      white line reaches ≥ 7:1.
    * Sealed sockets stay quiet; only the frontier (MM, P) shows `?`.
    * The cue disappears after the first milestone. The normal HUD fades in over the next 2 s.

---------------------------------------------------------------------------------------------------------------------

## 8. Motion

| element | trigger | animation | ReducedMotion |
|---|---|---|---|
| camera, ambient realm | input / always | REALM §9.4 / §6 | REALM §9.6 |
| node hover / press | pointer | UIScale 1.08 (0.12 s) / .94 (0.08 s) | instant 1.04 |
| badge | glow or pulse on | pop 0 → 1.15 → 1 (0.25 s Back Out), then bob ±2 du 0.8 s | static |
| pulse aura / rays | pulse (≤ 4 nodes) | aura ImageTransparency .55 ↔ .30 1.2 s sine; rays Rotation 12 s/rev | static aura α .45 |
| select ring | open panel | Rotation 20 s/rev | static |
| flow sparks | pulse edges (HIGH) | 1.6 s loop, ≤ 6 | none |
| capsule tick / coin | 1 s / always | UIScale 1 → 1.05 → 1 (0.18 s) / coin 6 s/rev | none |
| shine sweep | BUY cards (top band: index + title), CTAs | UIGradient.Offset (−1,0) → (1,0), 0.9 s, every 2.8 s, random phase; peak α ≤ .18; never over a description (§9.6) | none |
| buy / prestige | cls change / reset | §5.4 | colour flash only |
| sheet open / close | tab | slide 48 du + Box tween (0.24 s quintOut) / (0.16 s quadIn); staggered cards y +12 → 0 (25 ms apart, first 12) | instant |
| tabs | switch | new active UIScale .92 → 1 (0.15 s) | instant |
| toasts | popup | slide 60 du Back Out 0.28 s; merge bump 1.06 → 1 | appear / disappear |
| holds | hold buttons, gems, peek | conical or linear fill ∝ time (a black α .22 sweep, never a white wash); rewind 0.12 s | same (functional) |
| universe change | `map.inside` flips | frameNodes fly (0.9 s) + a full-screen Radial flash (crimson in / violet out) α .6 → 1 | flash only |
| glitch (pm, cp, infected) | every 2–6 s | clone Position ±2–4 du for 60–140 ms | none |
| first-run cue | m.best == 0 | chip bob ±4 du 1 s sine | static |

Rules:

* Tween only Position, Size, Rotation, UIScale, transparencies and UIGradient **Offset / Rotation**. Never tween
  UIGradient sequences, `UIStroke.Thickness` on text, or `UIShadow.BlurRadius`.
* No CanvasGroup for sheets.
* Budget: ≤ 6 running tweens in HudGui and ≤ 40 outside the map. Loops pause with their gui's visibility.
* "Motion means change": idle panels do not animate except shine sweeps on actionable items.
* `GuiService.ReducedMotionEnabled` is watched. Options › Motion (SYSTEM / FULL / REDUCED) overrides it for the UI
  and the REALM layer alike.
* The snapshot mode forces REDUCED (§16).

---------------------------------------------------------------------------------------------------------------------

## 9. Type scale and readability

The type system has two halves.

* **Display type** stays exactly as loved. It covers panel titles, hero and capsule numbers, CTAs, section titles and
  resource names: Heavy Italic or Sarpanch Heavy, gradient fill, black outline and a hard shadow, at **≥ 20 du**.
* **Reading type** is everything a player reads for information: descriptions, effects, costs, labels, hints, toasts
  and options. It is upright, SemiBold to ExtraBold, has no outline, uses flat high-contrast colour and real line
  spacing, and is never below the floors of §9.5.

Hierarchy comes from **steps in size, weight and colour**, never from shrinking secondary text. Every size lives in
`Theme.ROLES` (`src/client/Core/Theme.luau`) and in the mock mirror `TY` (`final/src/lib.js`). A literal TextSize
anywhere else fails the lint (§16).

### 9.1 Fonts, weights and styles

`Font.fromName(name, weight, style)`:

* Montserrat Heavy is the heaviest weight (there is no Black). Sarpanch has no italic.
* **Weight follows size.** Montserrat Heavy's gap between letters is .05–.06 em, which is under 1 px at 13 px, so the
  letters fuse.
  * **Heavy** (900) only for the display roles (title, hero, capsule, big, CTA, section, resource), which are
    ≥ 20 du on WIDE; their COMPACT steps (down to 16) keep the weight.
  * **ExtraBold** (800) for 13–20 du labels: card title, cardSmall, toast title, tab, plate name, `label`.
  * **Bold** (700) for caps labels.
  * **SemiBold** (600) for body and small text.
* **Italic** only on display and title roles (title, CTA, section, resource, card, cardSmall, toast, active tab,
  plate), and only for ≤ 4 words (a longer card title is set upright). Never on body, small, caps, labels, numbers or
  any sentence. Game `<i>` spans inside body text stay italic at body size.
* **Uppercase** only for display roles and labels of 1–3 words: panel and section titles, CTA verbs, caps labels,
  plate names, tab names, chip words. **Card titles are Title Case in every state** (BUY, OWNED, NOT YET, LOCKED). Banners and tags put only the
  1–2 word verb in caps ("FINISH", "HOLDING"); the rest is sentence case.
* **Sarpanch is for numeral runs only**: digits and `. , e + − × % / ^`. Sarpanch has O = 0, l = 1 = I, a single-storey
  `a` that reads as `o`, and a colon that renders as a centred dot. Units, words and labels on the same line are a
  Montserrat Bold run (§9.9). Chips with words, keycaps, pager labels, jump buttons and tier badges use `label`
  (Montserrat ExtraBold). Node and gem **symbols** (M, PEP, CR…) stay Sarpanch Heavy at ≥ 13 px: they are all
  capital letters without O or I.
* **Hair spaces** (U+200A, `Rich.caps`) only on caps text ≤ 16 du: `caps`, caps chips, plate names, `plateSub`. Never
  on titles, sections, CTAs or numbers. There is no letter-spacing in Roblox.
* Italic labels get `UIPadding.PaddingRight = ceil(.1 × size)` for the overhang.

### 9.2 Role table

**WIDE** is du at s = 1 (1080p, 100%). **MED** is the rendered px on the smallest desktop (s = .90, §10); a value in
brackets is the du that `Theme.size` writes there to hold the floor. **COMPACT** is du on phones (s ≥ 1, so px ≥ du).
LH is the Roblox `LineHeight`. Strokes are UIStroke Contextual black, LineJoinMode Round, in du at the role size, in
three tiers: **display** (≥ 20 du, or ≥ 18 on art) gets the full outline (.14–.2 em) + a hard shadow; **labels on hue
fills, plates or glass** (plate name, active tab, toast title, badge on a disc) get a thin one (≤ .1 em, shadow ≤ 1);
everything on a solid panel or card surface under 20 du gets **none**.

| role | font · case | WIDE | MED | COMPACT | LH | stroke / shadow | colour |
|---|---|---|---|---|---|---|---|
| `hero` | Sarpanch Heavy | 56 (steps 48, 40) | 50 | 38 (34, 30) | 1.0 | 7 / 5 + shadow +5 + glow blob | UIGradient W → lift(c,.5) → c |
| `title` | Montserrat Heavy Italic · CAPS | 44 | 40 | 27 (steps 24, 22) | 1.0 | 7 / 5 + shadow +4 | UIGradient W → lift(c,.45) |
| `big` (LV, counters) | Sarpanch Heavy | 44 | 40 | 30 | 1.0 | 5 / 3 + shadow +3 | white |
| `capsule` | Sarpanch Heavy | 34 (30, 26) | 31 | 28 (26, 22) | 1.0 | 5 / 4 + shadow +3 | gold gradient |
| `index` (card №) | Sarpanch Heavy | 28 | 25 | 22 | 1.0 | none | lift(c,.5) α .8 |
| `cta` | Montserrat Heavy Italic · CAPS verb | 26 | 23 | 20 (18, 16) | 1.0 | 6 / 4 + shadow +3 | white |
| `section` | Montserrat Heavy Italic · CAPS | 24 | 22 | 22 | 1.0 | 5 / 4 + shadow +3 | UIGradient W → lift(c,.45) |
| `resource` | Montserrat Heavy Italic · CAPS | 22 (18 when > 20 chars) | 20 | 18 (16) | 1.0 | 4 / 3 + shadow +2 | lift(c,.6) |
| `card` | Montserrat ExtraBold Italic · Title Case | 20 | 18 | 18 | 1.1 | none | BUY: UIGradient W → lift(c,.45) (≥ 5.1:1 on the BUY surface); owned #d7f7e1; locked #c9bfd0 |
| `toast` | Montserrat ExtraBold Italic · ≤ 4 words | 18 | 16 | 16 | 1.0 | 2 (on hue / glass) | white |
| `numberHeavy` (values) | Sarpanch ExtraBold | 18 | 16 | 17 | 1.0 | none (well on fills) | white; not yet #d9b3be; owned #a5efbc |
| `cardSmall` | Montserrat ExtraBold Italic · Title Case | 17 | 15 | 16 | 1.1 | none | text / #d7f7e1 |
| `ctaSub` (gain line) | Sarpanch Bold + unit run | 17 | 15 | 15 | 1.0 | none; sits in a well (R15) | white |
| `body` | Montserrat SemiBold · sentence | 16 | 14.4 | 15 | 1.3 | none | text α .92 |
| `tab` | Montserrat ExtraBold, Italic when active · CAPS | 16 | 14.4 | 15 | 1.0 | 2 active on the fill; none idle | white / soft |
| `number` | Sarpanch Bold | 16 | 14.4 | 15 | 1.0 | none | white |
| `plate` | Montserrat ExtraBold Italic · CAPS + hair | 15 | 13.5 | 13 | 1.1 | 1.5 + shadow +1 | UIGradient W → lift(c,.45) |
| `plateNum` | Sarpanch Bold | 15 | 13.5 | 14 | 1.1 | none | lift(c,.55) |
| `terminal` / `terminalBold` | RobotoMono Medium / Bold | 15 | 13.5 | 14 | 1.35 | none | #caffbf / #9fdc92 |
| `small` (secondary) | Montserrat SemiBold · sentence | 14 | 13.5 [15] | 13 | 1.25 | none | soft; text α .92 on hue cards |
| `label` (chips, keys, buttons) | Montserrat ExtraBold · Title or CAPS ≤ 3 words | 14 | 13.5 [15] | 13 | 1.0 (1.15 wrapped) | none | per use |
| `badge` (counts ×10, 13/18) | Sarpanch ExtraBold · digits | 14 | 13.5 [15] | 13 | 1.0 | 2 on hue discs | white, or dark ink on light fills |
| `caps` (field labels) | Montserrat Bold · CAPS ≤ 3 words + hair | 13 | 12.6 [14] | 12 | 1.0 | none | soft #c9c3e6 |
| `plateSub` ("⚡ READY") | Montserrat ExtraBold · CAPS + hair | 13 | 12.6 [14] | 12 | 1.1 | none | #ffe08a |

Other display sizes stay as their signatures give them (§6): the `+gain` floater 28, pb/pp badges 40, cp counters
52, ach "13 / 18" 64, the end-screen title 64, node symbols 44 / 40.5 / 31.7. They follow the display rules.

### 9.3 The hierarchy ladder

Every step between adjacent levels is **≥ 1.2×**. The loved big type did not shrink; the small type grew.

| level | WIDE | ratio | COMPACT | ratio |
|---|---|---|---|---|
| hero | 56 | 1.27 | 38 | 1.41 |
| title | 44 | 1.83 | 27 | 1.23 |
| section | 24 | 1.20 | 22 | 1.22 |
| card | 20 | 1.25 | 18 | 1.20 |
| body | 16 | 1.23 | 15 | 1.25 |
| caption (`caps`) | 13 | — | 12 | — |

Siblings at one level are separated by colour and weight, not size: `small` is body-level secondary text (soft),
`number` sits beside body, `numberHeavy` is one step above its caps label, and `cardSmall` sits between card and
body.

### 9.4 Line spacing and padding

* `LineHeight` is per role (table). Single-line roles stay at 1.0 so their frames do not grow; multi-line roles
  get 1.1 (titles), 1.25–1.3 (body, small) or 1.35 (terminal). Roblox pitches lines at `floor(size × LineHeight)`.
  Size frames from `TextBounds` after LineHeight is set, and use `AutomaticSize = Y` for anything that wraps.
* Paragraphs and blocks are ≥ .5 em of body apart (8 WIDE / 8 COMPACT). Label → value is 4 du; title → body in a
  card 8 / 6.
* Text never touches a frame edge: at least 10 du of side padding on buttons, tiles and chips (8 in COMPACT chips),
  and 12–16 on cards.
* A chip is `1.9 × text` tall: 28 du for `label` 14, 30 for `number` 16, 26 for COMPACT 13.

### 9.5 Floors and scaling

**Rendered floors** (px on screen, TextSize × s, on every row of the §10 device table):

| text | floor | smallest WIDE du | smallest COMPACT du |
|---|---|---|---|
| caps labels, chip words, `plateSub` | **12 px** | 13 | 12 |
| mixed case, numbers, mono | **13 px** | 14 | 13 |
| running text (`body` paragraphs) | **14 px** | 16 | 15 |

* **`Theme.size(role)`** returns the COMPACT size on COMPACT. On WIDE and MEDIUM it returns
  `max(role.wide, ceil(floor / s))`: at s = .90 the floor roles (`small`, `label`, `badge`, `caps`, `plateSub`) are
  written one du larger (the bracketed MED values), so nothing renders below 12 / 13 px. Boxes around those roles use AutomaticSize or 2 du of slack.
* The desktop UI scale no longer goes below .90, and Interface Size can never push s below it (§10).
* `COMPACT_FLOOR` is 12. The old 11 px floor and the accepted 9.4 px caps are gone.
* **Game HTML** cannot go under the floor. `Html.open()` clamps a game `font-size` to
  `max(nsize, .88 × base, floor)` and caps enlarged sizes at 1.3 × base. The game's text-shadow → `<stroke>` is dropped
  below 16 du.
* **`Rich.fit`** step-fits only display roles, and its last step is never below the role's floor.
* **PreferredTextSize** (Larger / Largest): the engine already enlarges text. The client does **not** also scale s.
  * Reading roles (body, small, caps, number, terminal, label) follow the setting inside AutomaticSize-Y containers:
    card bodies, toasts, tooltips, the detail sheet.
  * Display roles ≥ 20 du get a `UITextSizeConstraint.MaxTextSize` equal to the role size.
  * Fixed-geometry single-line roles (plate, tab, badge, chips) get `MaxTextSize = round(1.2 × size)` plus
    `TextTruncate = AtEnd`, and their frames are sized with `TextService:GetTextSize`.
  * `TextScaled` is never used for text.

### 9.6 Colour and contrast

Text colour tokens (§11.1): **text** #f2f0ff (primary), **soft** #c9c3e6 (secondary, labels, hints), **muted**
#9a94b8 (tertiary only), **faint** #5c5775 (never text).

| surface | primary | secondary | measured |
|---|---|---|---|
| panel, panel2, panel3, deep, dim, notyet | text | soft | soft ≥ 9.1:1; muted ≥ 5.3:1 |
| owned green `mix(panel, bought, .14)` | #d7f7e1 / #a5efbc | soft | soft 8.4:1; #a5efbc 10.6:1 |
| hue-tinted BUY / NEXT cards `mix(panel, c, .38)` | text | **text α .92** (never soft or muted) | ≥ 4.8:1 on all 21 hues (t is the worst) |
| glass HUD (R10) carrying text, α ≥ .88 | text | soft | soft ≥ 8.9:1 even over white art |
| bright hue fills (buttons, tiles, chips, the gen pill) | white ≥ 20 du with stroke + shadow | a **value well** (R15) or dark ink #0d0b16 | well ≥ 5.1:1 on every hue; ink ≥ 6.4:1 |

Rules:

* Every reading string is **≥ 4.5:1** on its real surface. On dark surfaces secondary text is ≥ 7:1 (soft is ≥ 8.4:1
  everywhere dark). Display text ≥ 20 du needs ≥ 3:1 plus its outline.
* Caps labels and hints use **soft** at full alpha, not white α .55. muted is only for text ≥ 15 du on dark surfaces
  (disabled labels, timestamps), never on hue-tinted cards, glass or fills.
* **Dim the surface, not the words.** Locked, ashed and owned states change the surface, the stroke and a state chip.
  Their text stays ≥ 4.5:1 (ashed desc text α .82, locked title #c9bfd0, never α .55 or .6).
* Coloured text on panels uses `Theme.textHue` (the §11.2 lift) at ≥ 4.5:1.
* The shine sweep (R5) crosses only the top band of a card (index + title) at peak α ≤ .18, never the description.
  Hold fills darken (black α .22 sweep or a brighter rim); they never wash a label in white.
* A contrast unit test checks every role colour against every surface token for all 21 hues (§16).

### 9.7 Text on the map and art always has a backing

Text is never set directly on the parallax art, the rays or the sunburst. It needs one of:

* a **plate** (§3.9: panel2 → deep α .95);
* **glass** (R10) at α ≥ .88 (`BackgroundTransparency ≤ .12`, multiplied toward opaque by
  `GuiService.PreferredTransparency`);
* a **scrim band** (black α .45–.55, UICorner 12) behind a paragraph, e.g. the end-screen body;
* for display text **≥ 18 du only**, the display outline: stroke ≥ .15 em plus a hard shadow (node symbols, the
  end-screen and loading titles).

Every HUD string is checked against the brightest map frame (the portal rim, sparkles, lit clouds), not a flat comp.

### 9.8 Measure: lines and characters

| text | max | overflow rule |
|---|---|---|
| card title | 2 lines, ≈ 17 chars per line at 237 du | never ellipsized; the view's short name if longer. Two-line titles are **balanced**: the client breaks at the word boundary nearest the middle, so a lone "I" / "IV" never sits on line 2 |
| upgrade / challenge description | 4 lines (≈ 26 chars per line at 237 du WIDE, ≈ 30 COMPACT) | the card grows (AutomaticSize Y; the tier row takes the tallest card). Past 4 lines: clamp + ⓘ → the full text in the tooltip or detail sheet. Never cut an effect with "…" |
| milestone done row | title 1 line + effect ≤ 2 lines | the row grows 60 → 78 |
| fold row note | 1 line, the headline fact only | the rest on expand |
| notes, tooltips, modal text | 45–75 chars per line; tooltips ≤ 5 lines at 360 du | — |
| hints | ≤ 6 words, sentence case (`small`) | longer hints move into the ⓘ / tooltip, or a first-use coach mark |
| caps labels | 1–3 words | more words become sentence-case `small` |
| toast sub | 1 line, ≤ 40 chars | coalesced subs show a count or range ("3 achievements", "18th – 27th Meta-Milestone"), never joined names |
| summary rows | 1 number per row, with its owner's name | never ≥ 3 numbers joined by " · " on one line |
| plate name | whole words, ≤ 12 chars per line, 2 lines allowed | no initial-plus-period abbreviations (§3.9) |
| buttons and CTAs | 1 line, ≥ 12 du side padding | step-fit (cta 26 → 22, COMPACT 20 → 18 → 16), then the short verb |

### 9.9 Number presentation (client only; view.js parity is untouched)

`Rich.num(s, role)` turns a game-formatted string into RichText. `format()` output is never re-computed, only
re-typeset:

1. **Families.** Numeral runs stay in the role's Sarpanch face. Words and units ("PP", "points", "OOMs/sec",
   "weaker", "essences") become a `<font family=Montserrat weight=700 size=max(0.85×, small)>` run in soft (on dark surfaces)
   or the run's own colour at α .8 (on fills), after a thin space U+2009.
2. **Exponent markers.** Every `e` inside a numeral run gets `transparency=".3"` at the same size, so digit groups
   separate: "e1,329,005" versus "1e413,950" read differently at a glance. `×` before an `e` gets a thin space
   ("× e2.296e21").
3. **Percentages** the client shows (the `pr` bars, and game strings of the form `63.000%`) have 0 decimals from 10%
   and 1 decimal below ("63%", "4.2%", "0%"). "100%" only when have ≥ need.
4. **Have / need.** The % is the primary figure (`number` or `ctaSub`). The need is secondary (`small`: "need
   e1.057e60 points"). Tooltips show two aligned rows ("Need 1e413,950 HP" / "Have e8.502e20 HP") plus the bar.
   Never two raw exponents joined by a slash.
5. **Narrow slots** (chips and pills ≤ 100 du): an exponent run with ≥ 7 digits steps to the short form of the same
   value ("+e483,525,689" → "+e4.84e8"). The full value stays in the hero, tooltip or detail sheet.
6. **Tier badges and levels** use Arabic numerals ("TIER 1", "LV 3"). Game titles keep their roman numerals as sent.
7. **Coordinates** "(6;4)" show as "6, 4".
8. **Ticking values** are anchored to a stable edge (left for the capsule and hero, right for stat rows and costs)
   in a slot sized for one extra character. They are never centred, so they do not jitter.

---------------------------------------------------------------------------------------------------------------------

## 10. Breakpoints and UI scale

> **Superseded (2026-09-26): aspect-ratio scaling.** The shipped client no longer picks a COMPACT phone design. Every
> device gets the same 1920×1080 du layout, scaled by the tighter axis (`src/client/Core/Layout.luau`, `Layout.compute`):
>
> ```lua
> local s = math.clamp(math.min(V.X / 1920, V.Y / 1080) * userSize, 0.55, 2.0)   -- S_FLOOR .55 keeps phones legible
> local canvas = V / s
> local mode = (canvas.X < 1500 or canvas.Y < 860) and "MEDIUM" or "WIDE"     -- COMPACT is never chosen
> ```
>
> An 844×390 phone gets s .55 and a 1535×709 du canvas: the desktop side sheet with the map strip, scaled. Consoles and
> TVs follow the same rule (4K = s 2.0). `Theme.FLOOR` (rendered caps 7 / text 8 points) replaces the px floors below for
> s < 1. The COMPACT code paths (band, full-screen phone sheet, COMPACT type sizes) are left in place but unused; the
> formula, the table and the COMPACT rows below are the original spec, kept for reference.

```lua
local V = workspace.CurrentCamera.ViewportSize   -- points; recompute on change
local mode = (V.Y < 500) and "COMPACT" or ((V.X < 1500 or V.Y < 860) and "MEDIUM" or "WIDE")
local s = mode == "COMPACT" and math.clamp(V.Y / 390, 1.0, 1.3)
       or mode == "MEDIUM"  and math.clamp(math.min(V.X / 1600, V.Y / 900), 0.90, 1.0)
       or                        math.clamp(math.min(V.X / 1920, V.Y / 1080), 0.90, 2.0)
local S_MIN = mode == "COMPACT" and 1.0 or 0.90
s = math.max(s * userSize, S_MIN)   -- Options › Interface Size .90 / 1.00 / 1.15; never below S_MIN
-- PreferredTextSize does NOT change s: the engine enlarges text itself (§9.5)
-- one UIScale on each root of HudGui, TopbarGui, MarkerGui, PanelGui, OverlayGui; roots sized in offset = V / s (never a
-- Scale-sized full-screen frame under a UIScale); MapGui uses REALM mapScale only (Plates carry their own UIScale s)
```

* **The desktop floor is .90** (it was .85). The most common laptop setups land on it: 1366×768, 1440×900, and a
  1080p laptop at the Windows default of 125% (reported as 1536×864). At .90 body text renders at 14.4 px and caps at
  12.6 px; `Theme.size` lifts the four floor roles by one du (§9.5).
* **The WIDE ceiling is 2.0** (it was 1.5), so a 4K monitor at 100% gets the same physical text as 1080p.
* **Interface Size** .90 only shrinks screens where s > .90 (1440p and up); it can never push text under the floors.
* The strip width is `canvas.w − 1160` on WIDE and `canvas.w − sheet − 24` on MEDIUM, with
  `sheet = clamp(.62·canvas.w, 900, 1112)`. A strip under 568 pt uses REALM mapScale < 1; under 460 du the sheet is
  full screen (§3.6).

| device | mode | s | canvas (du) | sheet / strip | body / caps (px) |
|---|---|---|---|---|---|
| 1920×1080 | WIDE | 1.0 | 1920×1080 | side, SX 760 | 16 / 13 |
| 2560×1440 | WIDE | 1.333 | 1920×1080 | side, SX 760 | 21.3 / 17.3 |
| 3840×2160 (4K at 100%) | WIDE | 2.0 | 1920×1080 | side, SX 760 | 32 / 26 |
| 1600×900 | WIDE | .90 | 1778×1000 | side, strip 618 du (mapScale .979) | 14.4 / 12.6 |
| 1536×864 (1080p laptop at Windows 125%) | WIDE | .90 | 1707×960 | side, strip 547 du (mapScale .866) | 14.4 / 12.6 |
| 1440×900 (MacBook) | MEDIUM | .90 | 1600×1000 | side, strip 584 du (mapScale .925) | 14.4 / 12.6 |
| 1366×768 | MEDIUM | .90 | 1518×853 | side, strip 553 du (mapScale .876) | 14.4 / 12.6 |
| 1280×720 | MEDIUM | .90 | 1422×800 | side, strip 498 du (mapScale .789) | 14.4 / 12.6 |
| 1180×820 iPad | MEDIUM | .90 | 1311×911 | strip 387 du → full screen | 14.4 / 12.6 |
| 844×390 | COMPACT | 1.0 | 844×390 | full screen | 15 / 12 |
| 932×430 | COMPACT | 1.10 | 845×390 | full screen | 16.5 / 13.2 |
| 667×375 SE | COMPACT | 1.0 | 667×375 | full screen; content 1 card column | 15 / 12 |

Phones are **landscape only** (LandscapeSensor). Portrait falls into COMPACT and is not optimised.
`GuiService.PreferredTransparency` multiplies the glass and HUD background transparencies (not panel bodies).

---------------------------------------------------------------------------------------------------------------------

## 11. Colour

### 11.1 Tokens

| group | tokens |
|---|---|
| base | void #07060d, deep #0d0b16, panel #14111f, panel2 #1c1829, panel3 #262138, stroke #3a3352, strokeHi #6a5f8f, text #f2f0ff, **soft #c9c3e6** (secondary text, labels, hints), muted #9a94b8 (tertiary, ≥ 15 du only), faint #5c5775 (never text) |
| state | bought #4be07a, locked #8a6f7a, complete #ffc233, danger #ff3b5c, gold #ffd34d |
| extra | info #7a8cff, lockedLink #c7b8f2, ember #ff7a2e (sp malware tabs), system #9d8cff (Options) |
| text on surfaces | well = black α .55 (R15), ink #0d0b16 (dark text on light fills), ownedTitle #d7f7e1, ownedValue #a5efbc, lockedTitle #c9bfd0, notYet #d9b3be, dangerText #f2d7dd, termLime #caffbf, termDim #9fdc92, stableId #5f8a58 |

Layer hues (keyed by game id):

| layer | hue | layer | hue | layer | hue |
|---|---|---|---|---|---|
| m | #b35cff | se | #ff6a1f | t | #ffe93a |
| mm | #d17aff | hp | #7fd9ff | pm | #ff2e63 |
| em | #e88af2 | ep | #9be02c | pep | #f2b04d |
| p | #6fc3ff | hb | #6dffb0 | cp | #39ff14 |
| pe | #ff9a2e | ap | #8ff3f3 | cm | #1fbf4a |
| sp | #5fe0ff | mp | #ff5a1f | ex | #45e07f |
| pb | #57e0b0 | | | ach | #ffc93c |
| pp | #ff4d6d | | | | |

### 11.2 Rules

1. **One hue per panel** (the layer token). State hues override it on cards: owned green (always desaturated on
   surfaces: `mix(panel, bought, .14)`), complete/active gold, danger, locked mauve. **Gold #ffd34d = points and
   "ready"** only. The layer hue never paints a state.
2. **Game colours are remapped** wherever they arrive (`col`, `<h2 style=color>`, class colours, `st`):

   | game colour | token |
   |---|---|
   | #793784 | m |
   | #9f2846, #c25757, rgb(238,112,112), #c86a6a | danger |
   | #652021 | pp |
   | #648c11 | ep |
   | #d03800 | mp |
   | #FFFF00 | t |
   | black | cp lime |
   | darkgreen | cm |
   | gold | ach |
   | red / #ff0000 | danger |
   | lime / green | cp / bought |
   | yellow | complete |
   | black backgrounds | removed |

   Unknown colours fall back to `lift(c,.35)`.
3. **Contrast** (the full rules are §9.6): every reading string is ≥ 4.5:1 on its real surface; display text ≥ 20 du
   is ≥ 3:1 plus its outline. Coloured text on panels uses `lift(c,t)` with the smallest passing t, precomputed per
   layer (m .25, pp .20, mp .20, se .10, pm .35, others 0). Secondary text is **soft** #c9c3e6 (≥ 8.4:1 on every
   dark surface). On hue-tinted cards all reading text is text α .92 (≥ 4.8:1 on all 21 hues). muted is tertiary
   (≥ 15 du, dark surfaces only). faint is decoration only.
4. **Text on hue fills:** display text ≥ 20 du → white + Contextual black stroke + hard shadow. Anything smaller sits
   in a **value well** (R15: black α .55, ≥ 5.1:1 on every hue) in white without a stroke, or is dark ink #0d0b16
   (≥ 6.4:1) on the light fills (t, ach, cp, hb, ap, sp, hp, ep, pb, p, pep, ex, em). A 3–4 px outline on text under
   20 du is not allowed: it fills the counters.
5. **Glow budget:** ≤ 2 per card, α ≤ .55 (CTAs and pulse ≤ .9). Owned and locked never glow.
6. The **biome tint** affects map layers only, never the world layer, nodes or UI.
7. **Dim, don't hide, and dim the surface, not the words:** locked content stays visible through the mauve surface,
   the lock sprite and the stroke. Its text stays ≥ 4.5:1 (never α .6 on the text).

---------------------------------------------------------------------------------------------------------------------

## 12. Roblox trees (HUD, sheet, phone band)

```
TopbarGui (TopbarSafeInsets, DisplayOrder 12) > Root (+UIScale s)
  Capsule   Frame (R1 + R2 gold) > Coin, Label, Amount (R4), Unit, GenPill (hidden when hud.gen == nil), Warn, Status
  UniTag    Frame (inside only) > Swirl (R6 conical), Label, Finish (R13 hold 1.2 s)
  PanelBand Frame (COMPACT with a panel open; replaces Capsule) > Emblem, Title (R3), RowChip, ReadySwitch (gems), Close (44)
HudGui (CoreUISafeInsets, 10) > Root (+UIScale s)
  Dock > Home, Trophies (+Badge), Options (+Dot)          ImageButtons (R1 + icon sprite + shadow clone + caption R3)
  Zoom > Minus, Pct, Plus                                   R10 glass (mouse only)
  Ready > Header, Gem_<id> (Frame circle R7 + Symbol + Chip + Ring R6 while held)   | ReadyPill (collapsed form)
  Portal > Aura, Ring (R6 conical rotating), Void (R7), Swirl, Label, StatePill
MarkerGui (DeviceSafeInsets, 5) > Marker_<id> (≤ 4)
PanelGui (CoreUISafeInsets, 20) > Root (+UIScale s)
  Backdrop  Frame #07060d from SX (+24 du ramp) + 2 Radial washes (R7)
  Sheet     Rim, HeaderBand (+tile_stripes R9), HeaderRule, Emblem, Title, SubRow, Tabs, Close, Hero (Resource, Cta, Stats),
            Body (styled Frame) > Scroll (ScrollingFrame, transparent) > TabRoot (Render) + BottomFade
OverlayGui (DeviceSafeInsets, 30) > Root (+UIScale s)
  Toasts (UIListLayout, click-through) · More (+N) · NotifyList · Tooltip · Peek (+R14 scrim) · Sheet (touch detail)
  Modal (Dimmer InputSink All + Card) · Loading · Fatal · EndScreen
```

---------------------------------------------------------------------------------------------------------------------

## 13. Roblox construction reference

### 13.1 Feature detection (`Theme.caps`, filled by pcall at start)

`UIShadow = pcall(Instance.new, "UIShadow")` · `Radial`/`Conical` = pcall(set `UIGradient.Type`) · `TileMode` ·
`BorderStrokePosition` · `Path2D = pcall(Instance.new, "Path2D")` · per-corner UICorner.

Every recipe reads the flags and falls back to sprites.

### 13.2 Recipes

| id | name | construction | fallback |
|---|---|---|---|
| R1 | Bevel surface | Frame + UICorner r + UIGradient (Rotation 90) + UIStroke (Border, child UIGradient) + **`bevel_card` / `bevel_button` 9-slice ImageLabel as the last child** (primary recipe) | — |
| R2 | Glow / depth shadow | `UIShadow{Color, BlurRadius UDim, Spread, Transparency}` on **shapes only** | `glow_rr` / `glow_circle` sprite as a sibling **before** the body (children draw above parents) |
| R3 | Outlined title | TextLabel white + UIGradient (fill) + UIStroke Contextual black (LineJoinMode Round) + a hard shadow clone TextLabel behind (+2..5 y). **Display roles** (≥ 20 du; ≥ 18 on art, §9.7) get the full outline; plate, active tab, toast title and disc badges a thin one (≤ .1 em, shadow ≤ 1); thickness as in the §9.2 table, scaled with the label when it is step-fitted. Card, cardSmall and reading roles use the same recipe with `stroke = 0, shadow = 0` | — |
| R4 | Gold / hero number | Sarpanch Heavy + UIGradient + UIStroke + shadow clone; **glow = `glow_rr` sized to TextBounds + 2B behind** (never UIShadow on text) | — |
| R5 | Shine sweep | overlay Frame (same UICorner) white + UIGradient transparency 1 → .72@.5 → 1, Rotation 105; tween `Offset` | none |
| R6 | Conical ring (progress, hold, cooldown, portal) | ring Frame + inner hole Frame, UIGradient **Type Conical** with Transparency keys (0:0, p:0, p+.001:1, 1:1); shimmer = Rotation tween | two `halfdisc` sprites (classic radial progress) |
| R7 | Radial gem / aura / vignette / glow blob | Frame + UIGradient **Type Radial** | `radial_p50/60/70` + `radial_lin` stack, `aura` |
| R8 | Dashed rim | UIStroke + child UIGradient TileMode Repeat, Rotation 45, small Scale, stepped transparency | solid stroke α .7 |
| R9 | Tiled texture (scanlines, stripes, grid, wave) | ImageLabel **ScaleType Tile** with a **standalone** small image (§14.2); scroll via Position | none |
| R10 | Glass HUD | Frame #090711 α .72 + UIStroke W α .14 (no backdrop blur exists); **α .88 when it carries text** (§9.7) | — |
| R11 | Glowing curve | 4 Path2D (halo, glow, core, hot) with UDim2 control points in `Links` scale units; thickness from k | 24 rotated thin Frames per curve (only if Path2D is missing) |
| R12 | Glitch text | 3 TextLabels (white, #ff2e63 −2 x α .7, #2ee6ff +2 x α .55); the flicker moves the clones 60–140 ms | static |
| R13 | Hold button | TextButton + a fill Frame (Size.X ∝ hold) or R6; InputBegan/Ended; starts after 120 ms / < 10 pt; rewinds on release. The fill is a **black α .22 sweep** (or a brighter rim), never a white wash over the label | — |
| R14 | Scrim with a hole | full-screen Frame α .62 **minus** a square Frame centred on the target with a Radial transparency hole | plain scrim |
| R15 | Value well | Frame black α .55, UICorner 8, UIPadding 3/10/3/10, AutomaticSize XY; holds white `number` / `small` / `label` text **without a stroke**. Used for secondary text on bright fills: CTA gain lines, D-pad costs, tile subs, the gen pill value, hold-button gains | a dark #0d0b16 chip |

### 13.3 Mock CSS → Roblox

| CSS | Roblox |
|---|---|
| linear-gradient | UIGradient Linear (Rotation = CSS angle − 90) |
| radial-gradient | R7 |
| conic-gradient | R6 |
| border-radius | UICorner |
| border / gradient border-box | UIStroke (+ UIGradient) |
| dashed border | R8 |
| box-shadow outer | R2 |
| box-shadow inset | R1 bevel sprite |
| `.tx` clone + text-stroke | R3 |
| background-clip:text | UIGradient on the TextLabel |
| repeating stripes | R9 |
| inline SVG | atlas sprites |
| mask on rays | the `rays` sprite |
| SVG path | Path2D |
| `-webkit-line-clamp` | only for display labels: TextTruncate AtEnd + a fixed height. Descriptions never clamp (§9.8) |
| `line-height` (unitless, per role) | `TextLabel.LineHeight` of the role (§9.2); the mocks use the same numbers |
| `font-size` | `Theme.size(role)`; the mocks read the same table from `TY` in `lib.js` |

---------------------------------------------------------------------------------------------------------------------

## 14. Sprites

### 14.1 `ui_atlas` (1024×1024 PNG, alpha-bled; LOW = a 512² half-scale copy)

All regions are white or grey, tinted with ImageColor3, faded to α 0 within a 2 px border. Sizes are region sizes in
texture px (@2x where noted: display at half). 9-slice centers are `SliceCenter` Rects relative to the region.

| sprite | size | content | 9-slice / use |
|---|---|---|---|
| glow_rr | 256×256 | white rounded rect 128² (r 24), blur σ 16 | SliceCenter (112,112,144,144), SliceScale = B/32; behind cards, CTAs, capsule, text glows (R2, R4) |
| glow_circle | 256×256 | disc Ø128, blur σ 16 | ring, badge, emblem, gem glows |
| aura | 256×256 | radial α 1 → .27@.55 → 0 | node aura 220, tint c |
| rays | 300×300 | 12 soft rays, radial alpha fade | pulse node rays (rotating) |
| radial_p50 / p60 / p70 | 256×256 each | disc, α 1 to m, linear to 0 | radial gradient fallback (R7) |
| radial_lin | 256×256 | disc α 1 − r | with the above |
| circle | 256×256 | hard AA disc | shine ellipse, dots |
| halfdisc | 128×64 | half disc | R6 fallback (two halves) |
| bevel_button | 128×128 @2x | transparent rr r32: top lip 4 px W α .35, bottom lip 10 px black α .40 | SliceCenter (40,40,88,88), SliceScale .5·r/16 |
| bevel_card | 128×128 @2x | top lip 4 px W α .18, bottom 8 px black α .35 | SliceCenter (40,40,88,88) |
| bevel_ring | 264×264 @2x | crescent lips on Ø264 | node ring overlay 132 |
| ring_dashed | 312×312 @2x | Ø312 ring 6 px, 22 dashes (14:8) | select ring 164 / challenge ring 150 |
| shadow_card | 192×192 | black rr blur σ 20, offset baked 0 | SliceCenter (80,80,112,112); depth shadow |
| keycap | 48×48 @2x | light rr + 6 px dark bottom lip | SliceCenter (14,12,34,32) |
| chip | 64×64 @2x | rr r16 fill + 3 px inner stroke | SliceCenter (20,20,44,44); chips without UIStroke (fallback) |
| icons (white, 64×64 @2x each) | 64×64 | gear, star, home, bell, lock (pre-coloured gold 44×44), plus, minus, x, save, export, import, copy, trash, warn, info, check, chev, chevr, up, down, left, right, bolt (pre-coloured variant for badges), sparkle, swirl, moon, bug, flame, hand, clock, eye, sort, grid, motion, map, text, target, disk | `ImageRectOffset/Size` |
| badge_bolt / badge_bang | 52×52 @2x | pre-coloured gold bolt disc / danger "!" disc with white ring | node badges 26 |
| coin_star | 80×80 @2x | 4-point star with shade | capsule coin |
| hex | 96×96 @2x | hexagon | pb / hb power badges |
| ember, sparkle_small | 32×32 | soft ember dot / 4-point sparkle | spark flow, embers, bursts (the realm atlas has its own copies) |

### 14.2 Standalone tile textures (ScaleType Tile does not tile an ImageRect region)

| texture | size | use |
|---|---|---|
| tile_scan | 4×6 | cp / cm scanlines (α .025–.07) |
| tile_stripes | 28×28 | header band stripes α .035 |
| tile_grid40 | 40×40 | ex cartography grid α .05 |
| tile_wave | 256×64 | pp oscilloscope (scrolled by Position) |
| tile_dots | 16×16 | skeleton shimmer base |
| tile_noise | 128×128 | optional panel grain α .03 |

Upload count: 36 HIGH + 11 LOW realm tiles, 2 realm atlases, 2 UI atlases, 6 tile textures = **57 images**. UI memory:
≈ 5.3 MB HIGH (1024² + tiles), ≈ 1.4 MB LOW. That is inside the REALM budget headroom (§1: 88.2 / 120 MB HIGH,
22.1 / 35 MB LOW).

---------------------------------------------------------------------------------------------------------------------

## 15. Data contract (view.js, parity-tested; everything derivable from the game)

The base: `v.map` (fixed order `ach m mm em p pe sp pb pp se hp ep hb ap mp t pm pep cp cm ex` + gate) with node
`show unl col sym name st tab ch cur br a` and `val {can lit glow pulse pts res tip ra}`, `map.inside/open/close/opt`,
gate `{show inside can fin h goal done a}` (`done ≥ 1` = won), and `v.hud {pts name gen dev off c}`. Critic §3.1 adds
`cn` on components plus the per-component fields listed in the table below. **Added by this design:**

| field | value | used by |
|---|---|---|
| `val.req` | short "amount + base unit" from requires/nextAt ("1e13,760 P", "1.00e15 PP") | locked plates |
| `val.gain` | formatWhole(resetGain); static "+1" | READY gems, peek |
| `val.dor` | the layer was reached (unlocked or best > 0) but is hidden by the universe split | dormant state |
| `pr` on reset (static), upg, buy, map val (locked) | progress to cost, 0..1, from Decimal: a = log10(have), b = log10(need); `pr = a/b` if a/b ≥ .01, else `log10(a)/log10(b)` (tower numbers); 0 if have ≤ 1; < 1 when not affordable | CTA bars, 91% chips, NEXT spotlight |
| `reset.hk` | the hotkey label ("P", "CTRL+C") from `layers[l].hotkeys` | keycaps |
| `gate.req` | the reveal rule + have/need (m.best ≥ 185: "185 milestones", have 164) | `???` portal, sealed-rift teaser |
| popup `kind` | milestone / achievement / corruption / challenge / notice | toasts |
| `hud.gen` | **null when the rate is 0** | capsule pill hidden |
| `eff` | **null**, never the string "undefined" | hero effect line |
| `lv` | formatWhole(level) ("50", not "50.00") | buyables |
| `grid.state/lv/kind` + `grid.tip` split `{fix, debuff, reward}` + `grid.prog` | cp disks and inspector | mock d |
| sp burn bar node `{t:"bar", p, st8: burning/ashed/permanent}` | replaces the HTML div gradient | mock f |
| NaN guard | any formatted value that is "NaN" (e.g. "Currently: NaNx") becomes null and is hidden | cards |
| `ms.id / ti / ds / mal`, `upg.ti/ds/ef/co/cur`, `buy.id/ti/lv/max/co + h`, `chal.id/ti/ds/goal/rw/cur/cmp/lim/st8`, `ach.ti`, main-display `pts/res/eff`, reset `gain/res/verb/next/base/bres/static` | critic §3.1 | all cards |

The **client** derives: section titles (from `cn`), owned / READY counts, tier folding, the NEXT milestone (the first
`ms.done == false`), decade folds, toast coalescing, READY membership, plate LOD and occlusion, the colour remap, and
the camera. Nothing else is invented.

---------------------------------------------------------------------------------------------------------------------

## 16. Test contract

**Stable anchors.** These replace the `port/tests/roblox.luau` paths `Page.Menu.MenuRoot`, `Page.Main.HeadRoot`,
`Page.Main.TabRoot` and `MilestoneTreeOverlay.*`.

| anchor | what |
|---|---|
| `MapGui.Root.Box.Nodes.Node_<id>` (+ `.Hit`) | map nodes (the bot navigates by `n.t == "node"`) |
| `MapGui.Root.Box.Plates.Plate_<id>.Label` | plate text |
| `TopbarGui.Root.Capsule.Amount`, `.GenPill.Label`, `.Status` | points, rate, save status (was HeadRoot) |
| `HudGui.Root.Dock.Home` / `.Trophies` / `.Options`, `HudGui.Root.Ready.Gem_<id>`, `HudGui.Root.Portal` | HUD |
| `PanelGui.Root.Sheet.Header.Title`, `.Hero.Cta`, `.Header.Tabs` | panel chrome |
| `PanelGui.Root.Sheet.Body.Scroll.TabRoot` | the Render root (was `Page.Main.TabRoot`) |
| `OverlayGui.Root.Toasts`, `OverlayGui.Root.Modal.Box` (TextBox), `OverlayGui.Root.Modal.Primary` | overlays (was `MilestoneTreeOverlay.Modal`) |
| `TopbarGui.Root.Capsule.Status` = "NOT SAVING" | the unsaved check (was `MilestoneTreeOverlay.Unsaved`) |

The "locked" state is detected by the node attribute `State = "locked"` (every node sets `State`), no longer by the
`#bf8f8f` colour.

**mock.luau additions:**

* instances and enums: ImageButton, UIGridLayout, UIShadow, `Enum.InputSink`, `Enum.GradientType` (+ TileMode,
  Scale), Path2D (GuiBase; `SetControlPoints`, `GetPositionOnCurveArcLength`), Path2DControlPoint;
* services: TweenService (Create / Play / Pause / Cancel / Completed), RunService.PreRender (and RenderStepped),
  GuiService (TopbarInset, ReducedMotionEnabled, PreferredInput, PreferredTransparency, PreferredTextSize,
  ViewportDisplaySize), `PlayerGui:GetGuiObjectsAtPosition`, UserInputService raw input;
* guards: AbsoluteSize / AbsolutePosition, `Font.fromName` with a style.

**Deterministic snapshot mode:** the attribute `MT_Snapshot = true` on the client:

* ReducedMotion forced;
* RNG seeded (7);
* ambient and REALM time fixed at t = 7 s;
* no intro dolly;
* no flow sparks;
* toast life frozen at 60%;
* fonts preloaded.

Snapshots render MapGui at the REALM camera given in the case file, which is the same (C, z, V) as these mocks.

**Lints:**

* **type floors** on the rendered tree at every §10 device row: TextSize × s ≥ 12 px for caps and chip words, ≥ 13 px
  for everything else (mixed case, numbers, mono), ≥ 14 px for `body` paragraphs; the same check runs over the
  mockup DOM;
* no literal TextSize outside `Theme` (every label names a role); `TextScaled` never on text;
* LineHeight matches the role (1.3 body, 1.25 small, 1.35 terminal, 1.1 titles, 1.0 single-line);
* no italic or uppercase string longer than 4 words; card titles are never all caps;
* no Sarpanch label whose text contains a letter other than `e`/`x` inside a numeral run, or a colon (the
  `[A-DF-WYZa-df-wyz:]` check); symbols on nodes and gems are exempt;
* no UIStroke thicker than .1 em on text under 18 du, none at all on panel / card surfaces under 20 du, and no text
  on a hue fill under 20 du outside a value well or dark ink (thin-stroke labels of §9.2 excepted);
* contrast: every text colour ≥ 4.5:1 on its surface for all 21 hues (`core_theme`), ≥ 3:1 for display ≥ 20 du;
* no reading text directly on map art (it has a plate, glass ≥ .88, a scrim or a display outline, §9.7);
* no "…" ellipsis in an upgrade, challenge or milestone effect description;
* no client-authored text containing dev words ("virtualis", "Studio", "debug", "TODO");
* no raw game colour in rendered RichText (the remap is applied);
* ≤ 24 glows per panel.

---------------------------------------------------------------------------------------------------------------------

## 17. Performance budget (review gates)

| surface | budget | how |
|---|---|---|
| MapGui textures | HIGH 88 MB / LOW 22 MB (REALM) + ui_atlas 1024² (512² LOW) + tile textures | tier choice; PreloadAsync behind the splash, farthest first |
| MapGui instances | REALM (tiles 36/11, sprites 194/76, pools 93/48) + **nodes ≤ 21 × 10 (+ lazy parts)** + **Path2D ≤ 4 × 23** + **dots ≤ 400 (HIGH only)** + sparks ≤ 6 + plates 21 × 2 | no layout objects in moving containers; lazy node parts |
| MapGui per moving frame | 20 container writes + 21 plate positions + field updater; **0 at rest** | REALM §9.2 |
| MarkerGui | ≤ 4 markers, ≤ 8 writes per moving frame | isolated gui (HudGui cache untouched) |
| HudGui / TopbarGui | ≤ 80 instances, ≤ 6 running tweens | pulses only on READY / portal |
| PanelGui | ≤ 450 instances for the open panel; one Render tree re-skinned | cards ≤ 10 instances (fixed cells), virtualised long lists |
| glows | ≤ 24 per panel | owned and locked never glow |
| text writes | only changed strings; numbers ≤ 5 Hz | RichText merges runs |
| COMPACT + full-screen sheet | `MapGui.Enabled = false`, tweens paused | REALM §9.7 |

---------------------------------------------------------------------------------------------------------------------

## 18. Verify in Studio early (pcall + fallbacks already specified)

* UIShadow, Radial / Conical UIGradient, TileMode, BorderStrokePosition and per-corner UICorner work on a live server
  (the Theme.caps flags).
* Path2D with about 90 strokes renders at 60 fps on a phone; check whether the UIGradient follows the curve or its
  bbox.
* Montserrat Heavy **Italic**, ExtraBold Italic, Sarpanch Heavy and Sarpanch ExtraBold resolve (not synthesised).
* A type specimen at 1920×1080, 1536×864 (s .90) and 844×390: every §9.2 role, a 3-line body paragraph (the
  LineHeight 1.3 pitch), U+200A (`GetTextSize("A"..HAIR.."A") − GetTextSize("AA") ≈ .1 × size`; otherwise
  `Rich.useHair = false`), U+2009 for units, and a `<font family weight size transparency>` RichText run.
* PreferredTextSize Larger and Largest: measure the engine multipliers; cards, toasts and tooltips grow, fixed
  chips truncate (§9.5). Review the 1920 set at 100% on a physical 24" 1080p monitor and on a phone.
* A read-only TextBox allows select-all + copy on desktop and mobile (otherwise use the §7.6 fallback).
* `InputObject.Position` vs `GetMouseLocation` inset offsets on MapGui (ScreenInsets None) vs HudGui.
* `GuiService.TopbarInset` changes when the unibar expands (capsule drop rule).
* Box-resize + ClipsDescendants cost at 60 fps during the 0.24 s tween.
* Memory on a low-end phone (F9) with LOW + ui_atlas 512.
