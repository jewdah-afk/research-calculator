# VS visual hierarchy + QA pipeline (Vampire Survivors v1.16 only)

Status: research notes, uncommitted. Tags: `[KEY]` = see References table; `inferred` = our reasoning from footage/engine behaviour, NOT stated by a source. Poncle has published no render-layer spec; every z-order row below is **inferred** unless tagged otherwise. Verify each against frame captures (section 2, step Q3).

Blocked/unreachable during research: reddit.com (no direct thread fetched; Reddit claims are only via Steam/forum mirrors), YouTube transcripts (not fetched; video URLs listed as technique refs only and marked unverified).

## 0. Facts established from sources

| Fact | Source |
|---|---|
| Options sections: Favorites, Display, Sound, Gameplay, Co-op, Account | [OPT] |
| Display: V-Sync, Borders (Solid/Transparent), Flashing VFX, Disable blood, Weapons ScreenShake, Pixel Font, Show Defanged Enemies | [OPT] |
| Gameplay: Damage Numbers, Show stage progression, Visually Invert Stages, Touch control stick, Joystick Type | [OPT] |
| Co-op: Player 1-4 colour, Show co-op indicators, **Permanent co-op outlines**, Tint UI selection | [OPT] |
| Damage Numbers toggle fixed in 0.9.0 so it no longer hides recovery (heal) numbers -> heal numbers are a separate always-on layer | [OPT] |
| Disable Blood + Pixel Font + Border Type added in 1.6.0 | [P16] [OPT] |
| 1.6.108: Pentagram flash now obeys Flashing VFX; VFX fixes at various aspect ratios | [P16108] [GN] |
| 1.7.0: various flashes removed when Flashing VFX is disabled; Gorgeous Moon wrong screen flash removed; damage-number display optimised | [P17] |
| Visually Invert Stages added in 1.0 | [OPT] [R10] |
| Engine Phaser (HTML5) until 1.6, Unity from 1.6 (so v1.16 = Unity renderer) | [WIKIP] [PHASER] [VSW] |
| Unity move motivated by sprite/effect/enemy count performance (secondary source) | [CYB] |
| No official "visual noise"/weapon-opacity slider; a Steam user recalls Poncle saying they do not intend to add one; players turn off damage numbers as workaround | [STEAM1] |
| Late game (Limit Break/endless) degrades to black screen / rainbow + damage numbers; competitors (Halls of Torment opacity slider, Soulstone "Special Effects Visibility") are cited as contrast | [STEAM1] [HOT] [SOUL] |
| Accessibility summary listing exists | [FGDB] |

Consequence: our build must NOT add a visual-noise slider in "1:1 mode"; offer one only behind a non-default accessibility flag (inferred design decision).

## 1. Z-order table and hierarchy rules

All layers inferred from footage behaviour + Unity sprite sorting; Roblox implementation column uses ScreenGui.DisplayOrder [RBSG] + GuiObject.ZIndex with ZIndexBehavior.Sibling [RBZ] [RBZB].

| Z | Layer | Contents | Blend | Notes |
|---|---|---|---|---|
| 0 | Ground tiles | stage tilemap | normal, opaque | low-saturation, mid/dark value (inferred) |
| 10 | Ground decals | Santa Water puddles, La Borra, blood (if enabled), floor pickups shadows | normal / alpha | under everything that moves (inferred) |
| 20 | Props / light sources | braziers, candles, stage props | normal | breakable; drawn below enemies (inferred) |
| 30 | Pickups | XP gems (blue/green/red), coins, chicken, chests, rosary, vacuum | normal | gems must stay legible under enemies? No: enemies draw over gems (inferred) |
| 40 | Ground auras | Garlic, Soul Eater, Laurel shield ring | alpha ~0.3-0.6 (inferred) | under enemies so crowd remains readable |
| 50 | Enemies | Y-sorted (lower y in front) | normal; hit flash = solid white overlay ~1 frame-ish (inferred) | bosses same layer, larger |
| 60 | Player(s) | character sprite, co-op outline [OPT] | normal | always above enemies (inferred) so the player never disappears in a crowd |
| 70 | Projectiles | knives, wand bolts, axes, bibles, runetracer, fire wand | normal; some additive glow (inferred) | above player: projectiles CAN hide player - root cause of complaints [STEAM1] |
| 75 | Screen-wide FX | Lightning Ring strikes, Pentagram/Rosary/Gorgeous Moon flash, Vandalier, Power of Sire black-out | additive / full-screen | gated by Flashing VFX [P16108] [P17] |
| 80 | Damage numbers | white digits, crit/large variants (inferred) | normal, short pop+fade | toggle [OPT]; 1.7 optimisation [P17] |
| 81 | Heal numbers | green digits | normal | NOT hidden by Damage Numbers toggle [OPT] |
| 85 | Off-screen indicators | chest/boss/co-op arrows | normal | "Show co-op indicators" [OPT] |
| 90 | HUD | XP bar top, timer, kill/gold counters, weapon/passive icons, HP bar under player (inferred) | normal | HP bar world-anchored but drawn on UI layer (inferred) |
| 95 | Border | Solid/Transparent frame | normal | [OPT] |
| 100 | Modal UI | level-up, chest opening, pause | dim overlay behind | freezes world (inferred) |

Rules (all inferred unless tagged):
- H1 Player always above enemies; projectiles may cover player (match game, do not "fix").
- H2 Value hierarchy: ground darkest/least saturated; enemies mid; pickups and projectiles brightest. Measure via Q-metrics VAL-STRAT.
- H3 Saturation budget: background chroma (OKLab C) median < enemies median < projectiles median [OKLAB].
- H4 Enemy hit flash is solid white and short; it is not gated by Flashing VFX, which only gates screen-wide flashes (inferred from [P17]).
- H5 Flashing VFX OFF: replace full-screen flashes with nothing or low-alpha tint; check vs WCAG 2.3.1 / ITU BT.1702 flash limits (3 flashes/s) [WCAGF] [BT1702] [GAG] [XAG].
- H6 Weapons ScreenShake toggle gates weapon-driven shake only [OPT]; shake must be small, decaying, translational (inferred; technique [SHAKE] [GAGSS]).
- H7 Disable blood removes layer 10 blood decals only [P16].
- H8 Pixel Font toggle swaps HUD/number font [P16].
- H9 Pixel-perfect: nearest-neighbour sampling (Roblox ResampleMode.Pixelated [RBIMG]), integer scale.
- H10 Sprites have no general outline; only co-op outlines (permanent optional) [OPT]; outline technique ref [PIXOUT], implement via 1px offset copies, not UIStroke (UIStroke outlines frame, not alpha) [RBUIS] (inferred).
- H11 Additive blend only for glows/flashes; Roblox GUI has no additive blend mode -> approximate with bright low-alpha ImageLabels (inferred; blend math [BLEND]).

## 2. QA pipeline

Q0 Contract: for each of the ~89 effects write a golden spec: stage, character, weapon level, timestamp, expected layer, colour palette, timing. Ties to research/vs PIPELINE gates (written contract first) [repo PIPELINE.md].

Q1 Reference capture: record real v1.16 at 1920x1080, 60 fps, lossless/high-bitrate; Flashing VFX ON and OFF; Damage Numbers ON/OFF; fixed seeds not available -> use deterministic setups (single enemy, Imelda, Mad Forest, minute 0) per CALIBRATION.md. Observe mechanics only; do not redistribute assets.

Q2 Frame extraction: `ffmpeg -ss T -i ref.mp4 -frames:v 1 -vsync 0 f.png` with accurate seek (-ss after -i for frame-exact) [FFSEEK]; dedupe with mpdecimate [FFMPDEC]; event frames via scene-change select [FFSCENE].

Q3 Our capture: Roblox harness drives a scripted scenario through RunService.Heartbeat-stepped deterministic sim [RBRS], screenshots via CaptureService [RBCAP] or offline render of our sim state to EditableImage [RBEI] for pixel reads; tests in TestEZ/Jest-Lua [TESTEZ] [JEST]; CI via Open Cloud Luau Execution [RBCLI] (logic only; rendering screenshots need a client).

Q4 Normalise: crop HUD/border, scale both to native pixel grid (divide by integer scale), align by template match on player sprite [OCVTM].

Q5 Metrics + thresholds (proposed, inferred; tune on 10 known-good pairs):
| Metric | Threshold pass | Source |
|---|---|---|
| SSIM (grey, native res) per golden | >= 0.85 static, >= 0.70 FX-heavy | [SSIM] [SKSSIM] [FFSSIM] |
| MS-SSIM | >= 0.90 | [MSSSIM] |
| PSNR | >= 25 dB (static only) | [FFPSNR] |
| Palette match: % pixels whose nearest ref-palette colour has CIEDE2000 < 3 | >= 95% | [CIEDE] [KMEANS] |
| Hue histogram correlation (HSV, 32 bins) | >= 0.90 | [OCVHIST] |
| EMD of value histogram | <= 0.05 | [EMD] |
| pHash Hamming | <= 8/64 | [PHASH] [IMGHASH] |
| LPIPS | <= 0.15 | [LPIPS] |
| FLIP mean | <= 0.10 | [FLIP] |
| Timing: event onset delta | <= 1 frame @60 | inferred |
| Duration delta | <= 5% | inferred |
| Motion (optical flow mag ratio) | 0.9-1.1 | [OCVOF] |
| Flash safety (OFF mode) | 0 failures | [WCAGF] [PEAT] |
| Video-level (optional) | VMAF >= 80 | [VMAF] |

Q6 Score rubric per effect (0-100): geometry/size 25, colour/palette 20, timing 20, layering 15, motion 10, readability 10. Ship >= 85, iterate 70-84, redo < 70. Feed failures into build-qa-loop Fix stage.

Q7 Regression: store goldens in repo (our own renders only), re-run diffs on every commit; any metric drop > 0.02 SSIM flags.

Q8 Human pass: side-by-side flip-book at 0.25x speed for top 10 worst scores.

## 3. Algorithm catalog

| id | name | purpose | algorithm | params | sources |
|---|---|---|---|---|---|
| Z01 | Layer table enforcement | verify DisplayOrder/ZIndex of every spawned GUI matches table | walk PlayerGui, assert layer range per tag | table 1 | RBSG RBZ |
| Z02 | Y-sort enemies | front/back ordering | ZIndex = base + floor(screenY/4) | bucket 4px | RBZB; inferred |
| Z03 | Player-above-enemy check | H1 | render mask test: player pixels never occluded by enemy layer | - | inferred |
| Z04 | Projectile occlusion ratio | measure how much FX covers player | % player bbox pixels covered by L70+ | report only | STEAM1 |
| Z05 | Heal-number separation | damage toggle must not hide heals | toggle off, spawn heal, assert visible | - | OPT |
| Z06 | Modal freeze check | world frozen under level-up | entity positions identical across 30 frames | - | inferred |
| C01 | Luminance stratification | H2 value hierarchy | median OKLab L per layer mask, assert order | - | OKLAB |
| C02 | Chroma budget | H3 | median OKLab C per layer | bg<enemy<proj | OKLAB |
| C03 | WCAG contrast of HUD text | HUD legibility | (L1+.05)/(L2+.05) | >=4.5 | WCAG |
| C04 | APCA Lc for damage digits | small-text contrast | APCA Lc vs local bg | |Lc|>=60 | APCA |
| C05 | Palette extraction | build ref palette | k-means in Lab on ref frames | k=32 | KMEANS |
| C06 | Palette match % | colour fidelity | nearest palette CIEDE2000 | dE<3, >=95% | CIEDE |
| C07 | HSV hist correlation | overall colour | cv.compareHist CORREL | 32 hue bins, >=0.9 | OCVHIST |
| C08 | Value EMD | tone distribution | 1D Wasserstein of L | <=0.05 | EMD |
| C09 | Hit-flash colour | white flash fidelity | sample enemy pixels on hit frame | all >= L 0.95 | inferred |
| C10 | Gem colour ID | gem tiers distinguishable | pairwise CIEDE2000 of gem hues | >20 | CIEDE |
| C11 | Additive approx error | H11 check | compare additive ref vs alpha approx | dE mean<5 | BLEND |
| C12 | Saturation clip detect | avoid blown FX | % pixels with S>0.95 & V>0.95 | <15% non-flash | inferred |
| P01 | SSIM | structural match | Wang 2004, 7x7 gaussian | K1=.01 K2=.03 | SSIM SKSSIM |
| P02 | MS-SSIM | multi-scale | 5 scales | weights Wang 2003 | MSSSIM |
| P03 | PSNR | raw error | 10log10(MAX^2/MSE) | >=25dB | FFPSNR |
| P04 | pHash | coarse match/robust to shift | DCT 32x32->8x8 | Hamming<=8 | PHASH IMGHASH |
| P05 | dHash | quick dedupe | gradient hash 9x8 | Hamming<=5 | IMGHASH |
| P06 | LPIPS | perceptual | AlexNet LPIPS | <=0.15 | LPIPS |
| P07 | FLIP | alternating-view diff | NVIDIA FLIP LDR | ppd=67 | FLIP |
| P08 | Masked SSIM | ignore HUD/random enemies | SSIM on mask of effect bbox | dilate 4px | SKSSIM; inferred |
| P09 | Pixel-exact sprite diff | static sprite placement | XOR on native-res crops | 0 diff px allowed 2% | inferred |
| P10 | Silhouette IoU | shape of FX | binarise alpha/threshold, IoU | >=0.85 | inferred |
| P11 | Size ratio | CALIBRATION B-series | bbox width / player width | +-5% | CALIBRATION.md |
| P12 | Template alignment | register frames | cv.matchTemplate TM_CCOEFF_NORMED on player | score>0.8 | OCVTM |
| P13 | Integer-scale detect | H9 | autocorrelation of edges -> scale factor | integer | RBIMG; inferred |
| P14 | Nearest-neighbour check | no blur | count unique colours in 2x2 blocks at native scale | <=1 within sprite | RBIMG |
| P15 | Outline presence | H10 | alpha-edge ring colour test | co-op only | OPT PIXOUT |
| T01 | Frame-accurate seek | extract at T | ffmpeg -ss after -i | -vsync 0 | FFSEEK |
| T02 | Scene-change events | find onset frames | select='gt(scene,0.3)' | 0.3 | FFSCENE |
| T03 | Duplicate removal | variable fps clean | mpdecimate | default | FFMPDEC |
| T04 | Onset delta | timing | first frame diff>thr vs trigger | <=1 frame | inferred |
| T05 | Duration | FX lifetime | frames with mask area>0 | +-5% | inferred |
| T06 | Cooldown periodicity | weapon cadence | autocorrelation of FX area signal | +-2% | inferred |
| T07 | Optical flow speed | projectile speed | Farneback mean magnitude | ratio .9-1.1 | OCVOF |
| T08 | Arc fit | axe gravity | fit parabola to centroid track | R2>.98 | CALIBRATION.md A5 |
| T09 | Fade curve fit | alpha fades | fit linear/exp to mean alpha per frame | RMSE<.05 | inferred |
| T10 | Damage number motion | pop/rise/fade | track digit centroid + alpha | match ref curve | inferred |
| T11 | Deterministic sim step | reproducible captures | fixed dt 1/60 from Heartbeat accumulator | seed fixed | RBRS |
| F01 | Flash rate detector | safety | count luminance transitions >10% area & dL>.1 | <=3/s | WCAGF BT1702 |
| F02 | Red flash detector | safety | saturated red transitions | <=3/s | WCAGF PEAT |
| F03 | Flashing VFX OFF parity | H5 | run screen-FX goldens with flag off; F01 must pass | 0 fails | P16108 P17 |
| F04 | Pentagram flash gate | known patch | assert no full-screen flash with flag off | - | P16108 |
| F05 | Gorgeous Moon no flash | 1.7 fix | assert no screen flash ever | - | P17 |
| F06 | Blackout duration | Power of Sire/black screens | % frames mean L<0.05 | report | STEAM1 |
| F07 | Pattern check | repetitive pattern hazard | FFT stripe energy | report | GAG |
| S01 | Shake amplitude | H6 | global frame offset via phase correlation | <= ref max | SHAKE; inferred |
| S02 | Shake toggle | option parity | flag off -> offset 0 for weapon shake | 0 | OPT GAGSS |
| S03 | Shake decay | feel | fit exp decay to offset | tau +-20% | SHAKE |
| R01 | Player findability | readability under chaos | time for detector (template) to find player in frame | score>0.6 in 95% frames | STEAM1; inferred |
| R02 | Clutter index | visual noise | edge density (Sobel) per area | report vs ref | inferred |
| R03 | Feature congestion | noise | Rosenholtz-style colour+contrast+orientation variance | report | inferred (technique not fetched) |
| R04 | Damage number density | toggle effect | digit pixels % of screen | report ON/OFF | STEAM1 P17 |
| R05 | Gem legibility | pickups readable | C10 + not occluded by aura (L40) | - | inferred |
| R06 | HP bar legibility | player status | contrast of bar vs neighbourhood | C03 | WCAG |
| R07 | Defanged enemies render | option | flag shows/hides defanged | - | OPT |
| R08 | Invert stage | option | mirrored ground only, HUD unmirrored | - | OPT R10 |
| R09 | Blood toggle | H7 | blood decal count 0 when off | - | P16 |
| R10 | Pixel font toggle | H8 | font asset swap | - | P16 |
| R11 | Border modes | Solid/Transparent | border alpha 1 vs <1 | - | OPT |
| R12 | Co-op colour distinctness | 4 players | pairwise CIEDE2000 of P1-4 colours | >25 | OPT CIEDE |
| R13 | Aspect-ratio FX | 1.6.108 fix | run goldens at 16:9, 16:10, 21:9, 4:3 | no clipping | P16108 |
| H01 | Golden store | per-effect goldens | PNG + JSON spec per effect id | 89 effects | inferred |
| H02 | Screenshot harness | automated capture | client script runs scenario list, CaptureService capture per timestamp | - | RBCAP |
| H03 | EditableImage readback | pixel reads in-engine | render sim to EditableImage, ReadPixelsBuffer | - | RBEI |
| H04 | Unit tests | logic | TestEZ/Jest-Lua for layer assignment & toggles | - | TESTEZ JEST |
| H05 | Cloud CI | headless logic | Open Cloud Luau execution | logic only | RBCLI |
| H06 | Score aggregator | rubric Q6 | weighted sum, worst-first report | ship>=85 | inferred |
| H07 | Regression gate | Q7 | fail if SSIM drop>.02 or score drop>5 | - | inferred |
| H08 | Flip-book review | human pass | alternate ref/ours 2 Hz | top 10 | FLIP |
| H09 | Video VMAF | full-run similarity | libvmaf on aligned clips | >=80 | VMAF |
| H10 | Value-fidelity gate | data checks | cross-check FX params vs research JSON | exact | repo PIPELINE.md |

Catalog entries: 77.

## References

| key | URL |
|---|---|
| OPT | https://vampire.survivors.wiki/w/Options |
| OPT2 | https://vampire.survivors.wiki/w/Option |
| P16 | https://gameranx.com/features/id/474222/article/vampire-survivors-version-1-6-patch-notes/ |
| P16108 | https://nintendoeverything.com/vampire-survivors-update-out-now-version-1-6-108-patch-notes |
| GN | https://www.gonintendo.com/contents/25984-vampire-survivors-updated-to-ver-1-6-108 |
| P17 | https://progameguides.com/vampire-survivors/vampire-survivors-full-patch-notes/ |
| STEAM1 | https://steamcommunity.com/app/1794680/discussions/0/4631482569784862180 |
| STEAM2 | https://steamcommunity.com/app/1794680/discussions/0/3194745319522730122 |
| STEAM3 | https://steamcommunity.com/app/1794680/discussions/0/4634862623030102973 |
| HOT | https://steamcommunity.com/app/2218750/discussions/0/3801652929323026410 |
| SOUL | https://steamcommunity.com/app/2066020/discussions/0/3591086730691827584 |
| FGDB | https://www.familygamingdatabase.com/accessibility/Vampire+Survivors |
| R10 | https://vampire.survivors.wiki/w/Updates/Road_to_v1.0:_Day_5 |
| WIKIP | https://en.wikipedia.org/wiki/Vampire_Survivors |
| PHASER | https://phaser.io/news/2024/02/vampire-survivors-space-54 |
| VSW | https://vampire.survivors.wiki/w/Vampire_Survivors |
| CYB | https://cyberpost.co/?p=474205 |
| SSIM | https://www.cns.nyu.edu/pub/eero/wang03-reprint.pdf |
| MSSSIM | https://ece.uwaterloo.ca/~z70wang/publications/msssim.pdf |
| SKSSIM | https://scikit-image.org/docs/stable/api/skimage.metrics.html |
| CIEDE | https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/ |
| OKLAB | https://bottosson.github.io/posts/oklab/ |
| FFSEEK | https://trac.ffmpeg.org/wiki/Seeking |
| FFSSIM | https://ffmpeg.org/ffmpeg-filters.html#ssim |
| FFPSNR | https://ffmpeg.org/ffmpeg-filters.html#psnr |
| FFSCENE | https://ffmpeg.org/ffmpeg-filters.html#select_002c-aselect |
| FFMPDEC | https://ffmpeg.org/ffmpeg-filters.html#mpdecimate |
| VMAF | https://github.com/Netflix/vmaf |
| LPIPS | https://github.com/richzhang/PerceptualSimilarity |
| FLIP | https://research.nvidia.com/publication/2020-07_flip-difference-evaluator-alternating-images |
| PHASH | https://www.phash.org/ |
| IMGHASH | https://github.com/JohannesBuchner/imagehash |
| OCVHIST | https://docs.opencv.org/4.x/d8/dc8/tutorial_histogram_comparison.html |
| OCVTM | https://docs.opencv.org/4.x/d4/dc6/tutorial_py_template_matching.html |
| OCVOF | https://docs.opencv.org/4.x/d4/dee/tutorial_optical_flow.html |
| EMD | https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wasserstein_distance.html |
| KMEANS | https://scikit-learn.org/stable/modules/clustering.html#k-means |
| WCAG | https://www.w3.org/TR/WCAG21/#contrast-minimum |
| WCAGF | https://www.w3.org/TR/WCAG21/#three-flashes-or-below-threshold |
| APCA | https://github.com/Myndex/SAPC-APCA |
| BT1702 | https://www.itu.int/rec/R-REC-BT.1702 |
| PEAT | https://trace.umd.edu/peat/ |
| XAG | https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/115 |
| GAG | https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/ |
| GAGSS | https://gameaccessibilityguidelines.com/allow-screen-shake-to-be-disabled/ |
| RBZ | https://create.roblox.com/docs/reference/engine/classes/GuiObject#ZIndex |
| RBSG | https://create.roblox.com/docs/reference/engine/classes/ScreenGui#DisplayOrder |
| RBZB | https://create.roblox.com/docs/reference/engine/enums/ZIndexBehavior |
| RBCAP | https://create.roblox.com/docs/reference/engine/classes/CaptureService |
| RBEI | https://create.roblox.com/docs/reference/engine/classes/EditableImage |
| RBRS | https://create.roblox.com/docs/reference/engine/classes/RunService |
| RBTE | https://create.roblox.com/docs/reference/engine/classes/TestService |
| RBCLI | https://create.roblox.com/docs/cloud/open-cloud/luau-execution |
| RBIMG | https://create.roblox.com/docs/reference/engine/enums/ResamplerMode |
| RBUIS | https://create.roblox.com/docs/reference/engine/classes/UIStroke |
| TESTEZ | https://github.com/Roblox/testez |
| JEST | https://github.com/jsdotlua/jest-lua |
| GDCJUICE | https://www.youtube.com/watch?v=Fy0aCDmgnxg |
| SHAKE | https://www.youtube.com/watch?v=tu-Qe66AvtY |
| PIXOUT | https://lospec.com/pixel-art-tutorials/tags/outline |
| BLEND | https://www.w3.org/TR/compositing-1/#blendingseparable |

Notes: GDCJUICE and SHAKE are general game-feel talks (YouTube, not fetched; unverified). Local: docs/CALIBRATION.md and research/vs/PIPELINE.md on origin/claude/vampire-survivors-mechanics-y1l323.