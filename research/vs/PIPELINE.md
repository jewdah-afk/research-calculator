# Build + QA pipeline

Reusable multi-agent pipeline for turning the research data into production code.
Script: `.claude/workflows/build-qa-loop.js`. Invoke by name (`build-qa-loop`) with `args`.

## Shape

```
Contract  ->  Build  ->  [ Gates -> Review -> Verify -> Fix -> QA ]  x N passes
   |                        |         |         |               |
  once                 mechanical  5 rubrics  refute      SHIP / ITERATE
                        no LLM     parallel   3 lenses    vs contract
```

Loop exits on `SHIP`, on a pass with zero confirmed findings (further passes are churn),
or at `maxPasses`. It never exits by silently running out of ideas.

## Why it differs from "reviewers reviewing reviewers"

**Verification points at the artifact, not at the review.** A meta-reviewer handed a review
tends to rubber-stamp it — it has no independent evidence to contradict. So instead every
finding goes to 3 fresh agents that reopen the file and try to *refute* the claim. Majority
rules, and **uncertainty defaults to refuted**, so unproven findings never reach the fix
stage. This is the single most important property: a polish loop that acts on false
positives gets *worse* every pass.

**Diversity comes from the rubric, not the headcount.** Five reviewers on five distinct
dimensions (fidelity, correctness, contract, ergonomics, perf) cover far more than five
reviewers on "find problems", because LLM reviewers on identical prompts correlate hard.

**Deterministic gates run first and cost nothing.** Parse checks, JSON validation, and
value-fidelity cross-checks against the source data catch more real defects than any review
layer. This is exactly how the weapons research earned trust: the per-level deltas summed to
the independently-quoted totals. Mechanical agreement > opinion.

**The contract is written before the build.** Without written, checkable acceptance criteria
the reviewers argue taste and the loop never converges. This is the highest-leverage phase
and it runs once.

## What it cannot do

It verifies fidelity, correctness and code quality. **It cannot tell you whether the game is
fun.** Feel — whether the 10→300 pressure ramp lands, whether a weapon's motion pattern is
satisfying — needs a running build and a human. Budget for playtest passes separately; no
number of review layers substitutes.

## Parameters

| arg | meaning | default |
|---|---|---|
| `target` | what is being built/reviewed | working tree |
| `spec` | source of truth to check against | `research/vs/` |
| `modules` | one build agent per entry | `['all']` |
| `maxPasses` | hard loop cap | 3 |
| `verifiers` | refuters per finding | 3 |
| `gateCommands` | exact deterministic checks to run | inferred |
| `rubrics` | review dimensions | the 5 above |

## Cost

Roughly `modules + passes x (1 gate + 5 reviews + 3 x findings + fixes + 1 QA)` agents.
A 3-pass run over ~6 modules with ~10 findings/pass is on the order of 100+ agents.
Scale `maxPasses` and `verifiers` down for cheap runs; the shape holds at any size.

## Tuning for this project

- `gateCommands` should include a Luau syntax check (`luau-analyze` or `selene`) and a
  script that diffs every numeric constant in the generated modules against the source JSON.
  That second one is worth writing by hand — it is the highest-value check in the pipeline.
- Feed `spec` the specific research file, not the whole directory, when building one module.
- The two open schema issues in `SUMMARY.md` (the `knockbackResistance` misnaming and the
  ×10 display scale) should be settled **before** the first build pass, not found by it.
