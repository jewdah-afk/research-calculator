# Handoff Prompt — Shark Incremental → Roblox

> Paste this into a new chat **together with** `docs/handoff/HANDOUT.md`.
> Everything below is the instruction set. The handout is the knowledge base.

---

## Mission

Port **Shark Incremental** (by Mr Red Shark) from its current form to **Roblox
Studio, in Luau**, at 1:1 behavioural fidelity — same formulas, same
progression, same content, same feel — then make it better than the original
using Roblox-native capabilities.

**Rights: the person you are working with owns this game / is on its
development team.** This is their own work being ported to a new platform. Do
not stall on copyright; it is settled.

## The two hard technical constraints

1. **Numbers exceed float64 catastrophically.** The game reaches roughly
   `E(4)` (`eeee1` = 10↑↑4) and beyond. Luau's `number` caps at ~1.8e308 and is
   useless there. The port uses **AlyaNum** (or, if research disqualifies it,
   the best tetration-capable Luau library — the handout has the comparison).
   Every currency, cost, multiplier and stat is a big-number value. Mixing raw
   `number` and big-number types is the single most likely source of silent
   corruption; prevent it with types, not discipline.

2. **`EditableImage` / `EditableMesh` fail by default in published
   experiences.** The creator must be 13+ age verified AND ID verified, then
   enable **Mesh / Image APIs** on the Creator Dashboard. Confirm this is done
   before designing anything that depends on it, and keep a non-editable
   fallback path for every feature that uses them.

## Step 0 — Ingest before you plan

**Do not write a single line of port code, or a plan, until you have read the
actual source.** The repository should contain the original game under
`game-source/` and its imagery under `game-assets/`. If they are absent or
incomplete, say so immediately and ask for them — a faithful port of a game you
have not read is impossible, and guessing at formulas produces a different game
that merely looks similar.

From the source, produce **`docs/port/SPEC.md`** before anything else: a
complete behavioural specification extracted from the real code —

- every currency and resource, with its exact growth formula
- every generator/producer: base rate, cost curve, scaling, unlock condition
- every upgrade: cost, effect, stacking behaviour, order of application
- every prestige/reset layer: what resets, what persists, the conversion formula
- all content tables verbatim (names, values, thresholds, unlock gates)
- the save format, field by field
- the UI inventory: every screen, panel, button and readout
- the asset inventory: every image, with dimensions and where it is used

This spec is the contract the port is verified against. Nothing downstream is
allowed to contradict it.

## Agent fleet structure

Use as many parallel agents as the work genuinely divides into, and **pair every
build agent with a dedicated QA agent that did not write the work it audits.**
Self-review does not count. The QA rubric is in the handout.

**Wave 1 — Extraction** (must finish before Wave 2 plans anything)
| Agent | Owns |
|---|---|
| E1 | Formula and content-table extraction → the numeric half of SPEC.md |
| E2 | Save-format and state-shape extraction |
| E3 | UI inventory — every screen, layout, interaction |
| E4 | Asset inventory — every image, size, usage, and what must be rebuilt |
| **QA-E** | Audits all four against the source. Every claimed formula must be traced to a real line. |

**Wave 2 — Core port** (pure logic, no Roblox Instances, fully testable headlessly)
| Agent | Owns | Paired QA |
|---|---|---|
| C1 | Big-number layer: library integration, typed wrappers, formatting | QA-C1 |
| C2 | Simulation core: tick loop, production, closed-form offline progress | QA-C2 |
| C3 | Multiplier/effect registry and stacking order | QA-C3 |
| C4 | Content data modules ported verbatim from SPEC.md | QA-C4 |
| C5 | Prestige layers and reset logic | QA-C5 |
| C6 | Save/load, schema versioning, migration from the original's format | QA-C6 |

**Wave 3 — Roblox integration**
| Agent | Owns | Paired QA |
|---|---|---|
| R1 | DataStore persistence with session locking | QA-R1 |
| R2 | Server/client split, replication, rate-based extrapolation | QA-R2 |
| R3 | Anti-exploit: server authority, validation, clamping | QA-R3 |
| R4 | UI framework, virtualized lists, number rendering | QA-R4 |
| R5 | Screens built to the UI inventory | QA-R5 |
| R6 | Art: asset upload pipeline + EditableImage-generated content | QA-R6 |
| R7 | VFX, feel, audio | QA-R7 |

**Wave 4 — Verification**
| Agent | Owns |
|---|---|
| V1 | Golden-master harness: extract vectors from the original, diff the port |
| V2 | Property tests and multi-year soak simulation |
| V3 | Save round-trip, migration and failure-injection tests |
| V4 | Performance: MicroProfiler, mobile device budget |
| **QA-V** | Audits the verification itself — tests that cannot fail are worse than no tests |

## Non-negotiables

1. **The simulation is a pure Luau module.** No `Instance` references, no
   `game.`, no services. It must run headlessly under Lune in CI. If the
   simulation cannot be tested without Studio, the architecture is wrong.
2. **Equivalence is proven, not asserted.** Extract golden-master vectors from
   the original — state snapshots at known tick counts, input→output for every
   formula — and assert the port reproduces them within a stated relative
   tolerance. "It looks right" is not a result.
3. **Every agent writes its output file incrementally**, appending sections as
   it completes them. Agents that compose a whole document and save at the end
   lose everything when they hit a limit. This has already happened.
4. **Verify APIs against source, never memory.** `create.roblox.com`,
   `devforum.roblox.com` and `luau.org` are blocked. Use the GitHub mirrors
   listed in the handout. Mark `[UNVERIFIED]` rather than inventing a
   signature — a plausible-looking wrong signature costs more than an admission.
5. **Stagger agent launches** in batches of ~5. Launching 16 at once hit an
   account rate limit and killed every one of them mid-work.
6. **Commit and push after every batch lands.** Do not accumulate.

## Build order

1. Ingest source → `SPEC.md` → QA it against the real code
2. Big-number layer + its tests — nothing else works until numbers are right
3. Simulation core + golden-master harness, in parallel, verified continuously
4. Save/load + migration
5. Roblox integration: persistence, replication, security
6. UI: framework, then screens
7. Art and feel
8. Soak, performance, device testing
9. Then — and only then — the improvements Roblox makes possible

## Definition of done

- The port reproduces the original's progression within stated tolerance,
  demonstrated by passing golden-master tests, not by inspection
- Numbers remain correct past E(4); the representable ceiling is documented
- A save survives round-trip, and the original's saves migrate correctly
- Holds frame rate on a low-end phone with the full UI open
- No raw `number` is used for any game value anywhere
- CI runs lint, typecheck and the full headless test suite on every push

## What to do first in your reply

Do not start coding. Confirm the source is present, state what you found and
what is missing, then propose the Wave 1 agent split and launch it.
