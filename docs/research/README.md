# Roblox Mastery Corpus

Total command of building things inside Roblox `EditableImage` and
`EditableMesh`, and of Roblox game development generally — written as a
knowledge base for porting a large incremental game to the platform.

**37,000+ lines across 20 chapters.** Every chapter was written by a dedicated
research agent against primary sources, with unverifiable claims marked
`[UNVERIFIED]` rather than guessed.

## Part I — The editable-asset core

| # | Chapter | Answers |
|---|---------|---------|
| 20 | [EditableImage API](20-roblox-editableimage-api.md) | Complete verified API, buffer layout, every display sink, the three failure gates |
| 21 | [EditableMesh API](21-roblox-editablemesh-api.md) | All 94 methods with thread-safety, the id-based model, does mutation live-update |
| 40 | [EditableImage cookbook](40-editableimage-technique-cookbook.md) | Painting, canvases, minimaps, filters, software rendering, texture synthesis |
| 41 | [EditableMesh cookbook](41-editablemesh-technique-cookbook.md) | Deformation, destruction, voxels, slicing, procedural objects, debug draw |

## Part II — Engine mastery

| # | Chapter | Answers |
|---|---------|---------|
| 22 | [Luau performance](22-luau-performance-engineering.md) | buffers, native codegen, what is actually parallel-safe, profiling |
| 23 | [Rendering & materials](23-roblox-rendering-lighting-materials.md) | Art direction without shaders, runtime PBR, lighting recipes |
| 43 | [3D math toolkit](43-roblox-3d-math-toolkit.md) | CFrame algebra, quaternions, splines, springs, geometry queries |
| 49 | [AI & NPC behavior](49-roblox-ai-and-npc-behavior.md) | Pathfinding, behavior trees, utility AI, crowds at scale |

## Part III — Craft

| # | Chapter | Answers |
|---|---------|---------|
| 42 | [Genre atlas](42-roblox-genre-atlas.md) | What each genre demands; where the white space is |
| 46 | [Code architecture](46-roblox-code-architecture-and-frameworks.md) | Framework comparison, project structure, testing |
| 47 | [Security & anti-exploit](47-roblox-security-and-anti-exploit.md) | Threat model, server authority, information leakage |
| 48 | [Procedural generation](48-procedural-generation-toolkit.md) | Dungeons, WFC, erosion, L-systems, loot, solvability |
| 51 | [Live ops & growth](51-roblox-liveops-analytics-and-growth.md) | Discovery, funnel metrics, monetization, the honest picture |
| 31 | [Prior art & benchmarks](31-roblox-prior-art-and-benchmarks.md) | What exists already, reusable libraries, measured numbers |

## Part IV — The incremental-game port

| # | Chapter | Answers |
|---|---------|---------|
| 60 | [Big numbers & AlyaNum](60-luau-bignum-and-alyanum.md) | The magnitude ladder, library comparison, serialization, formatting |
| 61 | [Incremental architecture](61-incremental-game-architecture-roblox.md) | The tick loop, closed-form offline progress, multiplier stacking, persistence |
| 62 | [JS → Luau port method](62-js-to-luau-port-methodology.md) | Semantic gotchas, DOM→GUI mapping, equivalence testing |
| 63 | [Incremental UI](63-incremental-game-ui-roblox.md) | Number formatting, virtualized lists, the screens, mobile |
| 64 | [QA & verification](64-qa-and-verification-methodology.md) | Golden-master testing, property tests, CI, the review rubric |
| 65 | [Adversarial QA loops](65-adversarial-qa-loops.md) | Critic agents, staged gauntlets, what the evidence supports |

## Method

`create.roblox.com`, `devforum.roblox.com` and `luau.org` are unreachable from
this environment. Claims were verified against the authoritative upstreams
instead, which are reachable and higher-fidelity than the rendered pages:

- **`Roblox/creator-docs`** — the generated reference YAML the Creator Hub is
  built from. Carries full signatures, defaults and thread-safety metadata.
- **`MaximumADHD/Roblox-Client-Tracker`** — the live engine reflection dump,
  used to confirm security levels and catch undocumented members.
- **`luau-lang/luau`** — VM source and RFCs.

DevForum was reachable only through search summaries; every such figure is
flagged `[COMMUNITY, SECOND-HAND]`. Treat community performance numbers as
unmeasured until reproduced in-engine.
