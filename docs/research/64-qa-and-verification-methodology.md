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
