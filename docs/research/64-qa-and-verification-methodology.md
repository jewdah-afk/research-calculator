# QA and Verification Methodology for a Roblox Luau Game Port

> **Scope.** A reference chapter for a team porting a large incremental/idle game to Roblox
> Luau, where the acceptance bar is two-fold: the port must be **provably faithful** to the
> original simulation, and it must **not break under real players**. This is a QA chapter, not a
> testing-framework tutorial — the techniques here are chosen because they are the ones that
> actually catch port bugs (drifted formulas, save corruption, precision collapse at high
> magnitudes) rather than the ones that are easiest to write.
>
> **Verification policy for this chapter.** Every API claim below is traced to source I read
> directly (repository source files, official Roblox `creator-docs` markdown, or tool
> documentation in the tool's own repository). Claims I could not confirm against a primary
> source are marked `[UNVERIFIED]`. Community knowledge I could not verify first-hand is marked
> `[COMMUNITY, SECOND-HAND]`. `create.roblox.com`, `devforum.roblox.com` and `luau.org` were not
> reachable from the research environment, so Roblox documentation is cited from its GitHub
> source of record (`Roblox/creator-docs`) and Luau behaviour is cited from the compiler/analysis
> source in `luau-lang/luau`. See [Sources](#sources).

---

## Outline

1. [TL;DR](#tldr)
2. [The testability precondition](#1-the-testability-precondition)
3. [Test frameworks: TestEZ, Jest Lua, and running headless with Lune](#2-test-frameworks-testez-jest-lua-and-running-headless-with-lune)
4. [Golden-master / characterization testing](#3-golden-master--characterization-testing)
5. [Property-based testing](#4-property-based-testing)
6. [Simulation and soak testing](#5-simulation-and-soak-testing)
7. [Save-system testing](#6-save-system-testing)
8. [Static analysis and types](#7-static-analysis-and-types)
9. [The CI workflow](#the-ci-workflow)
10. [In-Studio and in-game QA](#8-in-studio-and-in-game-qa)
11. [Device and platform QA](#9-device-and-platform-qa)
12. [The review rubric](#the-review-rubric)
13. [Sources](#sources)

---

## TL;DR

- **Testability is an architecture decision, not a tooling decision.** The simulation (formulas,
  currency, upgrade costs, offline gain, prestige, save schema) must be a pure Luau module tree
  with **zero `Instance` references, zero service calls, and no ambient time source**. Everything
  the DataModel touches goes behind an injected port. If you get this right, ~80% of the codebase
  runs headlessly; if you get it wrong, no framework rescues you.
- **TestEZ is in maintenance.** Its own docs say "the internals of TestEZ are being reworked, so
  accessing other APIs at this time isn't recommended," and its README still points CI users at
  **Lemur**, a Lua 5.1 Roblox shim that is effectively dead. `TestBootstrap:run(roots, reporter,
  otherOptions)` is verified from source. Use TestEZ only if you already have a large TestEZ suite.
- **Jest Lua (`jsdotlua/jest-lua`) is the better framework, but its README states plainly: "Jest
  Lua can currently only run inside of Roblox."** Lune support is tracked as issue #2 and is not
  done. So Jest Lua gives you the better API and `jest.mock`/fake timers, at the cost of needing
  Studio or `run-in-roblox` in CI.
- **The CI-grade answer is neither: write your simulation tests as plain Luau and run them under
  Lune with a ~120-line runner you own.** Lune's `roblox` library manipulates *place and model
  files*; it has no `require` for `ModuleScript`s, no signals, and no task scheduler bound to
  instances (verified against Lune's own API-status page). It is a file manipulator, not a
  DataModel emulator. Design for that.
- **Stub the Roblox surface with `luau.load(source, { environment = env })`.** Lune's `@lune/luau`
  exposes `compile`/`load` with a `LoadOptions.environment` field — that is the supported hook for
  injecting fake `game`, `task`, `os.clock`, `workspace` globals into a module under test.
- **Golden-master testing is the only technique that proves a port is faithful.** Freeze
  input→output vectors from the *original* game (formula tables, state snapshots at known tick
  counts, full progression traces), commit them as fixtures, and make the port reproduce them
  bit-for-bit or within a declared tolerance. Nothing else catches "the upgrade cost exponent is
  1.15 in the original and 1.115 in the port."
- **Absolute epsilon is wrong.** `math.abs(a - b) < 1e-9` is meaningless at 1e300 (the smallest
  representable gap near 1e300 is ~1e284) and unnecessarily strict at 1e-300. Use a **relative**
  comparison on the mantissa/exponent pair, and for big-number types compare `(layer, sign,
  mag)` structurally with a relative epsilon on `mag` only.
- **Property tests catch the bugs fixtures cannot**: no NaN/Infinity ever reaches the UI,
  currency never goes negative, purchase cost is strictly increasing, offline gain over a span
  equals online gain over the same span, `save → load → save` is a fixed point, and multiplier
  stacking is commutative where the design says it is. A 60-line generator plus a naive shrinker
  is enough; you do not need a library.
- **Soak testing is a first-class deliverable, not a nice-to-have.** Fast-forward 10,000 in-game
  hours headlessly, emit a progression report (currency by hour, first-purchase times, prestige
  cadence), and assert on *representability*: the tick at which a value stops round-tripping
  through your own formatter is a bug, not a curiosity.
- **The save system is where real player harm happens.** Test round-trip fidelity, every historic
  schema version's migration path, truncated/corrupt payloads, session-lock behaviour on rejoin,
  injected DataStore failures, and the **4,194,304-byte per-key limit** as an actual assertion —
  that figure is documented in `Roblox/creator-docs` data-store limits, along with the 50-character
  key-name limit.
- **`--!strict` is a QA tool with a measurable yield.** Track "% of modules at `--!strict`" as a
  release metric. Pair it with Selene (`std = "roblox+testez"`, auto-generated Roblox std) and
  StyLua `--check`. Selene's `divide_by_zero`, `unbalanced_assignments`, `shadowing`,
  `mismatched_arg_count` and `undefined_variable` catch real port bugs; Luau's own linter has 29
  numbered codes, verified from `LinterConfig.h`.
- **Gate merges on a pipeline that runs without Studio**: Rokit installs the toolchain, Wally
  installs packages, StyLua checks format, Selene lints, `luau-lsp analyze` typechecks against a
  Rojo sourcemap, Lune runs the simulation tests and the golden-master suite, Rojo builds the
  place. A concrete workflow YAML is in [The CI workflow](#the-ci-workflow).
- **Ship a debug console that cannot ship enabled.** Gate it on a server-side allowlist plus a
  build-time constant that CI asserts is `false` on the release branch — not on a `RunService`
  check alone, and never on a client-side flag.
- **Assume your tests miss things and build the net**: `ScriptContext.Error` and
  `LogService.MessageOut` piped to an aggregator, staged rollout across place versions, and the
  Creator Hub crashes chart with out-of-memory snapshots (documented in `creator-docs`) as the
  backstop for what unit tests structurally cannot see.
- **The review rubric at the end is the deliverable for auditing AI-generated work.** Every API
  claim cites a verifiable source; every signature is verified rather than plausible; every
  performance number is measured rather than asserted; every snippet is actually runnable. Run it
  mechanically.

---
