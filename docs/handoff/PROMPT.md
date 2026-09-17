# Handoff Prompt — Shark Incremental → Roblox

> Paste this into a new chat **together with** `docs/handoff/HANDOUT.md`.
> Everything below is the instruction set. The handout is the knowledge base.

---

## Mission

Port **Shark Incremental** (by Mr Red Shark) from its current form to **Roblox
Studio, in Luau**, at 1:1 behavioural fidelity — same formulas, same
progression, same content, same feel — then make it better than the original
using Roblox-native capabilities.

**Rights: settled — the person you are working with is working alongside
Mr Red Shark, the developer himself, with his rights and involvement.** This is
their own project being ported to a new platform. Do not stall on copyright, do
not re-litigate it, and do not ask them to prove it again. If a question of
scope or permission genuinely arises later, ask them directly — they have the
developer on hand to answer it.

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

1. **The simulation is a pure Luau module.** No `Instance`, no `game`, no
   services, no `task.*`, no `os.time`, no `math.random` — time and RNG are
   injected. If the simulation cannot run without Studio, the architecture is
   wrong and everything downstream becomes unverifiable.
   Enforce it mechanically: `luau.load(source, { environment = ... })` with
   every Roblox global replaced by a trap turns the convention into a build
   failure. (Note this deoptimizes the chunk, so use it as a gate, not in the
   soak hot path.)

2. **Equivalence is proven, not asserted.** Golden-master vectors extracted
   from the original, diffed against the port. "It looks right" is not a
   result.

3. **Make the ORIGINAL deterministic first — before porting.** Seeded PRNG,
   virtual clock, `stepN(n, dt)` replacing requestAnimationFrame, explicit key
   iteration order. Prove it by regenerating the golden data twice to a
   byte-identical result. Do this *before* the port exists, so you cannot
   unconsciously write vectors that match your own implementation.

4. **Tolerance is relative, never absolute.** One ULP near 1e300 is ~2e284, so
   `math.abs(a-b) < 1e-9` is vacuous above ~1e7. Write a tolerance policy into
   the repo: 0 ULP for pure non-accumulating formulas, ≤2 ULP where `pow`/`log`
   is involved, exact for integer-valued fields, NaN/Inf always a bug. For
   big-number values require exact sign and layer match and scale the mantissa
   budget by magnitude. TestEZ's only approximate matcher is absolute and is
   unusable here — write your own comparator.
   When a diff appears, "it's just floats" is the wrong diagnosis nine times
   out of ten. It is usually an operation-order difference in a multiplier
   chain, and it is fixable.

5. **Fixture governance — the control that stops an agent cheating.** Fixtures
   are generated from the original, NEVER from the port. `--regenerate` is not
   a runner flag; regeneration is its own fixtures-only pull request. Keep a
   `frozen/` subtree that CI treats as immutable. Without this, a failing
   golden-master test gets "fixed" by blessing the wrong output, and the entire
   verification story silently becomes theatre.

6. **Test stack — verified, and not what you would assume.** Jest Lua **cannot
   run under Lune** (its own README says so; it requires `run-in-roblox`).
   Lune's `roblox` library is a **file manipulator, not a DataModel emulator** —
   no `require` of ModuleScripts, no signals, no scheduler — so TestEZ's
   `TestBootstrap:run` cannot work under it unaltered. The workable path is
   plain Luau spec files plus a small Lune runner you own. Chapter 64 ships one.

7. **Lint in CI, not Studio.** Luau's linter has 29 codes and Studio hides six
   of them, including `LocalShadow`, `LocalUnused` and `ImplicitReturn`.
   `IntegerParsing`, `FormatString` and `MisleadingAndOr` are directly
   load-bearing for a big-number port. Playtesting structurally cannot surface
   these.

8. **Every agent writes its output file incrementally**, appending sections as
   it completes them. Agents that compose a whole document and save at the end
   lose everything when they hit a limit. This happened three times in the
   research session that produced this handout.

9. **Verify APIs against source, never memory.** `create.roblox.com`,
   `devforum.roblox.com` and `luau.org` are blocked. Use the mirrors in the
   handout. Mark `[UNVERIFIED]` rather than inventing a signature.

10. **Stagger agent launches** in batches of ~5. Launching 16 at once hit an
    account rate limit and killed every one of them mid-work.

11. **Commit and push after every batch lands.** Do not accumulate.

## What the research already settled — do not re-litigate

Read the handout, but these are the decisions:

- **AlyaNum is the number library.** It reaches `E(4)` with enormous headroom;
  its real ceiling is heptation. MIT, maintained, full operator overloading.
- **AlyaNum's addition saturates above `10^(9e15)`** — `a + b` returns
  `max(|a|,|b|)` while multiplication keeps working. At `E(4)`, `x + x == x`.
  **An additive income loop silently freezes.** Audit every income path in the
  original for this, express the economy multiplicatively where it matters, and
  put a test in CI that asserts it.
- **Offline progress is not a feature.** One `advanceTo(state, now)` that
  closed-form-integrates and re-anchors the timestamp in a single mutation.
  Online and offline become provably identical. The headline test: 12 hours in
  one jump equals 12 hours of 4Hz ticks.
- **`balance += rate*dt` silently no-ops at scale** in float64. Closed-form
  integration removes the bug class.
- **Generate art at edit time in a Studio plugin, upload, ship asset IDs.**
  This clears the verification gate, the memory budget, the replication
  landmine, the one-update-per-frame throttle and the mobile risk at once.
  Runtime generation only where content must genuinely change live.
- **`CreateMeshPartAsync` costs ~22 ms before a single triangle.** Streaming
  destructible geometry is not viable.
- **Vide for UI** — fine-grained reactivity suits hundreds of independent
  numbers updating at ~15 Hz. If the studio already runs React-Lua, keep it for
  structure and route the hot numeric path through imperative refs.
- **ProfileStore for persistence.** DataStore2 is officially deprecated.
- **Do not pre-compress saves** — Roblox compresses automatically, and bytes
  >127 fail `UpdateAsync` anyway. `EncodingService` provides native Zstd if you
  do need it.

## Resolve these in a scratch place before committing to an architecture

Eight questions could not be settled from documentation and are load-bearing.
A few hours here de-risks months:

1. Does `Opaque` DataModel-scoped `Content` replicate server→client?
2. Do `Beam`/`Trail`/`ParticleEmitter`/`Sky` sinks accept an EditableImage, or
   silently no-op?
3. What is the real editable-assets memory budget in MB — and do smaller
   canvases buy more of them?
4. Are removed `EditableMesh` IDs reused?
5. UV origin convention — V=0 top or bottom?
6. Do vertex colours render alongside `SurfaceAppearance`?
7. Does `RenderFidelity.Automatic` generate LODs for an EditableMesh-backed
   `MeshPart`?
8. Premultiplied or straight alpha in the `EditableImage` pixel buffer?

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
