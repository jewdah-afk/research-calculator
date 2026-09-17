# Adversarial and Iterative Verification Loops for AI-Generated Work

> **Scope.** A reference chapter for a team that wants a *maximally rigorous* multi-agent QA
> process over AI-generated Luau game code and technical documentation, where the acceptance bar
> is "provably faithful to an original game." It starts with a specific named technique — Matt
> Shumer's **Gauntlet Loop** — establishes exactly what is and is not verifiable about it, then
> surveys the well-documented technique family it belongs to, then proposes a concrete staged
> gauntlet this team can actually run in CI.
>
> **Verification policy for this chapter.** Every claim carries a confidence marker:
>
> | Marker | Meaning |
> |---|---|
> | `[PRIMARY]` | I read the primary artifact directly — the author's own repo file, the paper, the official docs. Quoted verbatim where it matters. |
> | `[SECOND-HAND]` | Reported by a third party (blog, news article, search-result summary) that I could read, but I could not open the primary artifact. |
> | `[SEARCH-SUMMARY]` | Sourced only from a search engine's summary of a page I could not open. Weakest tier. Treat as a lead, not a fact. |
> | `[INFERENCE]` | My own synthesis or judgement, not a reported fact. |
> | `[UNVERIFIED]` | Commonly repeated, could not confirm. |
>
> **Network constraint, stated up front.** This environment's egress proxy blocked `x.com`,
> `arxiv.org`, `aclanthology.org`, and most of the marketing-blog coverage of the Gauntlet Loop.
> `github.com` / `raw.githubusercontent.com` were reachable, which is fortunate: the single most
> load-bearing primary source for this chapter — Matt Shumer's original prompt — lives in a GitHub
> repo he owns, and I read it raw. Where a claim rests on a paper I could not open, it is marked
> `[SEARCH-SUMMARY]` and the arXiv ID is given so you can check it yourself. I have not pretended
> to have read anything I did not read. See [Sources](#sources).

---

## Outline

1. [TL;DR](#tldr)
2. [What is verifiable about the Gauntlet loop](#what-is-verifiable-about-the-gauntlet-loop)
3. [Matt Shumer's other published techniques](#matt-shumers-other-published-techniques)
4. [The technique family](#the-technique-family)
5. [What the evidence actually supports](#what-the-evidence-actually-supports)
6. [The proposed gauntlet for this project](#the-proposed-gauntlet-for-this-project)
7. [Anti-patterns](#anti-patterns)
8. [Sources](#sources)

---

## TL;DR

- **The Gauntlet Loop is real, it is Matt Shumer's, and the primary source is a 148-word prompt
  in a public repo he owns** — `github.com/mshumer/Claude-of-Duty/blob/main/prompt.md`. I read it
  raw and quote it in full below. `[PRIMARY]` This is not a case of a thinly-documented social-media
  technique that has to be reconstructed; the load-bearing artifact is checked into git.
- **What is *not* well documented is the "official" guide.** Shumer's own write-up ("How to Run a
  Gauntlet Loop") lives on X and `somethingbig.ai`, both of which this environment's proxy blocks.
  Everything I say about the guide's *contents* is `[SECOND-HAND]` or `[SEARCH-SUMMARY]`. The prompt,
  the demo repo, its architecture contract, its tooling and its results are `[PRIMARY]`.
- **The loop, as actually written, is five commitments**: (1) an agent — not the human — decomposes
  the goal; (2) each part gets a *specialist builder* sub-agent; (3) each part gets a *separate,
  harsh critic* sub-agent with fresh context; (4) the critic does a **blind side-by-side comparison
  against a real-world reference**, not a rubric score; (5) the loop exits on *winning*, not on a
  round count. `[PRIMARY]` from the prompt text.
- **The single most important design choice is the bar, not the critic.** Replacing "score this
  1–10" with "here are two artifacts, labels stripped, pick the better one" removes the score
  inflation that makes rubric-based self-grading useless by round three. `[PRIMARY]` for the
  intent (the prompt says "compare them side by side blind and say which one looks better");
  `[SECOND-HAND]` for the explicit "not a score out of 10, which drifts upward every round"
  framing, which comes from a downstream skill repo.
- **The flagship demo failed its own bar, and its README says so.** Claude of Duty's own README
  reports critic scores of 3.59 → 4.14 → 4.05 → 5.05 out of 10 and states that **"every critic in
  every round picked the real Call of Duty frame."** `[PRIMARY]` That is the most useful fact in
  this whole chapter: a loop that never terminated in success is still reported as a success by
  every secondary article about it. Read the repo, not the coverage.
- **The same README reports that parallel agent rounds underperformed sequential single-owner
  passes** — "three parallel rounds yielded +0.46 score improvement; one sequential pass achieved
  +1.00." `[PRIMARY]` If you are building a multi-agent QA process, this is a direct warning
  against fan-out as the default.
- **The part of the demo that actually worked was executable, not judgemental.** The repo ships
  `tools/capture.mjs`, `tools/imagediff.mjs`, `tools/perf.mjs`, `tools/baseline.mjs`,
  `tools/verify-live.mjs` (a Playwright harness that boots the app, waits on `window.__READY__`,
  collects JS errors and render stats, and screenshots), plus `selftest` modules in
  `src/physics/`, `src/audio/` and `src/ai/`. `ARCHITECTURE.md` makes it a hard gate: **"npm run
  build must pass and node tools/capture.mjs must produce a frame after your change."** `[PRIMARY]`
  The visual-quality scores moved a little; the measured numbers (p50 fps 12–17 → 28–30, worst
  frame 728–1236 ms → 66–82 ms, shader compiles 34–35 → 0) moved a lot, and were held honest by
  pixel-diff. `[PRIMARY]`
- **Independent replication found the loop degrades on smaller models specifically at the judging
  step, not the building step.** `github.com/NathanMaine/gauntletx` reports three runs and
  concludes "a smaller model builds almost as well and judges far worse," with critics reporting
  100% accuracy that was actually a string-comparison bug. `[PRIMARY]` (repo README).
- **The academic family this belongs to is well-mapped, and its central result is a warning.**
  Huang et al., *Large Language Models Cannot Self-Correct Reasoning Yet* (ICLR 2024,
  arXiv:2310.01798): intrinsic self-correction — revising using only the model's own judgement,
  with no external signal — **degrades** reasoning performance, and several headline self-correction
  gains in prior work came from using oracle labels to decide when to stop. `[SEARCH-SUMMARY]`
  Self-critique without an external signal is not free; it is negative-expected-value.
- **Everything that works in this family works because it imports an external signal.** Reflexion's
  91% HumanEval pass@1 rides on test execution; Self-Refine's ~20% average gain rides on
  task-specific feedback prompts and shows diminishing returns per iteration; Best-of-N works to
  the extent the verifier is better than the generator. Strip the external signal and the loop
  becomes an expensive way to make text longer. `[SEARCH-SUMMARY]` for the numbers.
- **LLM-as-judge is usable but is a biased instrument with named, measurable defects**: position
  bias, verbosity bias, and self-enhancement/self-preference bias (Zheng et al., arXiv:2306.05685;
  Panickssery et al., NeurIPS 2024, arXiv:2404.13076, which shows self-preference scales with
  self-recognition ability). `[SEARCH-SUMMARY]` The mitigations are mechanical: swap positions and
  require agreement, cap or normalize length, and never let the authoring model judge.
- **Multi-agent debate has a mixed-to-poor empirical record.** Multiple studies find it fails to
  reliably beat self-consistency at matched sample budget, and one reports it "significantly
  underperforms simple self-consistency using majority voting with an equivalent number of
  responses." `[SEARCH-SUMMARY]` Do not spend your budget there.
- **Executable verification dominates every judgement-based method, and it is not close.** A
  failing test is a *proof of defect*. A critic's disapproval is a *prior*. For this project —
  Luau code plus documentation that must be provably faithful to an original game — the strongest
  available signal is golden-master equivalence vectors extracted from the original, run headlessly
  in CI. One such vector failing outranks any number of agent approvals.
- **The recommended gauntlet is five stages with a hard iteration budget**: Stage 0 mechanical
  (parse/format/lint/typecheck) — 3 auto-fix attempts, no agent opinion involved; Stage 1 executable
  tests including golden-master vectors — 2 revision cycles then escalate; Stage 2 independent critic
  with a written rubric and a mandatory fail quota check — 2 cycles; Stage 3 adversarial agent whose
  *only* success condition is producing a committed failing input; Stage 4 human review of what
  survives. Total agent-revision budget **5 cycles**, then a human sees it regardless. Stop the
  loop on: bar met, two consecutive rounds with no *executable* delta, or budget exhausted.
- **The anti-patterns are all the same anti-pattern**: a reviewer that cannot cause work to be
  rejected. Rubber-stamp QA agents, critics with no failure channel, score-based rubrics that drift
  upward, self-review relabelled as independent review, and tests written by the agent that wrote
  the code all collapse to "the loop cannot fail, therefore the loop measures nothing." The
  structural fix is to make failure *the critic's product*: an adversarial stage that reports
  "found nothing" is a stage that failed, not a stage that passed.

---

## What is verifiable about the Gauntlet loop

### 2.1 Bottom line first

**The technique exists, under that name, and is Matt Shumer's.** This is not a case where I had to
reconstruct a plausible-sounding method from a vanished tweet. The originating artifact — the
prompt that produced the demo the technique is named after — is a file in a public GitHub
repository under Shumer's own account, and I read it raw. `[PRIMARY]`

What is *thinly* accessible from this environment is the **explanatory layer**: Shumer's own
narrative thread on X and his linked guide. Both are behind domains the egress proxy blocks
(`x.com`, `somethingbig.ai`). So the honest split is:

| Claim | Confidence | Why |
|---|---|---|
| The prompt text that produced Claude of Duty | `[PRIMARY]` | Read raw from `mshumer/Claude-of-Duty/prompt.md` |
| The demo repo's contents, tooling, architecture rules, self-reported results | `[PRIMARY]` | Read raw from the same repo |
| Shumer named the technique "the Gauntlet Loop" | `[SECOND-HAND]`, strong | Attributed identically by multiple independent downstream repos and by X post titles surfaced in search; the X post itself I could not open |
| The exact wording of Shumer's X thread and guide | `[SEARCH-SUMMARY]` | Search-engine summaries only |
| Downstream formalizations (skill files, prompt generators) | `[PRIMARY]` | Read raw from GitHub |
| Any claim that the technique "works" in a benchmarked sense | **Not established** | No controlled evaluation exists that I could find |

### 2.2 The primary artifact: the original prompt, in full

From `https://github.com/mshumer/Claude-of-Duty/blob/main/prompt.md`, read raw. `[PRIMARY]`

> I want you to build a first-person shooter at the level of the most recent Call of Duty games.
> It should be utterly perfect, visually beautiful, with every single thing done at AAA quality—from
> textures to physics to anything you could think of.
>
> Fan out sub-agents and have sub-agents tackle each one individually so that the game is utterly
> perfect. You should /loop on each item and have a separate sub-agent check it visually to ensure
> it looks triple A. That separate sub-agent should be a really harsh critic, and if it doesn't look
> triple A, it should keep going.
>
> Don't stop until each sub-agent is utterly wowed with the quality when compared with the actual
> Call of Duty game. It should literally compare them side by side blind and say which one looks
> better. Do this in ThreeJS. /loop until it's utterly perfect. Fan out sub-agents and ultracode.

That is the whole thing. Roughly 150 words. Note what is *not* in it: no rubric, no scoring scale,
no round budget, no evaluation criteria, no architecture, no tech-stack detail beyond "ThreeJS".
`/loop` and `ultracode` are Claude Code affordances (repeat-until-stopped, and opt-in multi-agent
orchestration respectively) `[SECOND-HAND]` — the prompt leans on the harness rather than
specifying the loop itself.

### 2.3 The loop structure, extracted

Reading only the primary text, the technique decomposes into five commitments. I am numbering them
so the rest of this chapter can refer to them; the numbering is mine `[INFERENCE]`, the content is
`[PRIMARY]`.

1. **Agent-side decomposition.** "Fan out sub-agents and have sub-agents tackle each one
   individually." The *model*, not the human, splits the goal into parts. Shumer emphasizes this
   in his naming post — "The agent (not you!!) breaks the goal into parts" `[SEARCH-SUMMARY]`.
2. **A specialist builder per part.** One sub-agent owns one piece of work.
3. **A separate critic per part, with fresh context.** "have a separate sub-agent check it" …
   "a really harsh critic." The separation is the point: the critic did not author the work and
   does not see the builder's reasoning.
4. **Blind comparison against a real-world reference, not a rubric.** "compare them side by side
   blind and say which one looks better." The bar is an external artifact that exists in the world
   (the actual Call of Duty), not a description of quality the agent wrote for itself.
5. **Exit on winning, not on a round count.** "if it doesn't look triple A, it should keep going" /
   "/loop until it's utterly perfect."

The downstream skill repo `robonuggets/gauntlet-loop` — which credits Shumer explicitly and links
to `prompt.md` as "the original prompt" — formalizes this the same way and adds the sharpest
statement of *why* a bar beats a rubric `[PRIMARY]`:

> A rubric asks the agent to grade itself against words it wrote. A bar makes it compare against
> something that already exists and is undeniably good.

and imposes three admissibility tests on the bar `[PRIMARY]`:

> - **Named.** A specific thing, not a category.
> - **Fetchable.** The critic can screenshot it, read it, run it, or open it. If the agent cannot
>   get the reference, it hallucinates the comparison and approves everything.
> - **Comparable.** Both can sit side by side and a judge can pick one.

and states the failure modes `[PRIMARY]`:

> - A vague bar. The critic invents a comparison and approves everything. By far the most common
>   failure.
> - The builder judging its own work. The critic needs fresh context and no knowledge of how hard
>   the builder tried.
> - A soft critic. Give it a binary job, not a score.
> - A fixed round count. The exit is winning, or you calling it.

**Confidence note.** That repo is a third party's packaging (Jay E / RoboNuggets, CC BY 4.0), not
Shumer's. Its *attribution* of the technique to Shumer is explicit and links to his repo, so I
treat the attribution as solid. Its *elaborations* — "not a score out of 10, which drifts upward
every round," the three-part bar test — are that author's formalization, not Shumer's words.
`[PRIMARY]` for what the repo says, `[SECOND-HAND]` for it being Shumer's intent.

A second independent packaging, `trilwu/gauntlet-loop-skills`, encodes a seven-phase version —
set bar and budget → LEAD splits → BUILDER builds in clean context → CRITIC returns PASS/FAIL with
evidence → fix and repeat → optional "smooth" pass by a fresh agent to harmonize independently
improved pieces → report with round log — and, importantly, **adds budget-based exit conditions**
that the original prompt lacks: stop when all units clear the bar, **or two consecutive rounds show
no improvement**, or the round/time/token budget is exhausted. `[PRIMARY]` (read raw). That
addition is the correct engineering instinct and I carry it into the design in §6.

### 2.4 The claimed results, and what the primary source actually says

This is where the coverage and the repository diverge sharply, and it is the most useful finding
in this chapter.

**What the secondary coverage says.** Search summaries of the news and blog coverage describe
Claude of Duty as a viral success — a 55,000-line Three.js FPS built from a single prompt, 3.8M
views on the announcement, "so real folks were convinced it was fake." `[SEARCH-SUMMARY]`

**What the repository's own README says.** `[PRIMARY]`

- Scale: "Roughly 55k lines across 11 subsystems, written by a fleet of AI agents under
  orchestration." No traditional art assets — "Every texture, mesh, animation and sound is generated
  procedurally at load time from code."
- **Quality outcome: it did not meet the bar.** Critic scores across rounds: **3.59 → 4.14 → 4.05 →
  5.05 out of 10**, with the note that scores at that level are in an "AMATEUR" band, and the
  conclusion: **"every critic in every round picked the real Call of Duty frame."** The README
  states plainly that the project does *not* match modern Call of Duty quality.
- Named residual defects: blocky hand geometry, procedural-looking surfaces, mannequin-like
  enemies, frame-rate constraints, and a known unfixed bug where "the viewmodel lighting delivers
  roughly 20× the irradiance of world lighting."
- **Process finding that contradicts the technique's own headline:** "Sequential single-owner
  development outperformed parallel agent work. Three parallel rounds yielded +0.46 score
  improvement; one sequential pass achieved +1.00."
- Measurement findings: "median frame time hides the actual problem" (94 fps static benchmark vs.
  unplayable gameplay due to >1000 ms shader-compilation stalls); "Captures were not reproducible"
  when pages were reused across shots, because state leaked forward — isolated fresh pages were
  required for bit-identical results.
- Performance deltas on Apple silicon at 1512×982, ultra preset: fps p50 **12–17 → 28–30**; fps p99
  **4–9 → 14–17**; worst frame **728–1236 ms → 66–82 ms**; shader compiles **34–35 → 0**. The
  optimization maintained "zero visual change," **verified by pixel-diff testing rather than
  assertions.**

**Read those two lists next to each other.** The *judgemental* loop — harsh critics doing blind
visual comparison — moved the score from 3.59 to 5.05 and never won. The *executable* loop —
Playwright capture, pixel diff, frame-time percentiles, shader-compile counts — produced roughly a
2× p50 improvement, a ~15× worst-frame improvement, eliminated a defect class entirely, and proved
it caused no regression. `[INFERENCE]` on the juxtaposition; both halves `[PRIMARY]`.

This is the empirical spine of the recommendation in §6: **the gauntlet is worth running, and the
part of it worth the most is the part you can execute.**

### 2.5 The executable scaffolding the demo actually shipped

The prompt says nothing about tooling. The repository is full of it. `[PRIMARY]` — file list read
from the GitHub tree API:

| Path | What it is |
|---|---|
| `tools/capture.mjs` | Frame capture (the gate in `ARCHITECTURE.md`) |
| `tools/shotset.mjs`, `tools/crop.mjs` | Deterministic screenshot sets for comparison |
| `tools/imagediff.mjs` | Pixel diff — how "zero visual change" was proven |
| `tools/perf.mjs`, `tools/profile.mjs`, `tools/baseline.mjs` | Frame-time percentiles and regression baselines |
| `tools/verify-live.mjs` | Playwright harness: boots headless Chromium, waits on `window.__READY__`, records HTTP status, boot ms, draw-call/triangle counts from `window.__RENDER_INFO__`, collects JS + console errors, screenshots after a fixed 90-frame settle, emits structured JSON |
| `tools/playtest.mjs`, `tools/probe.mjs`, `tools/dbgview.mjs`, `tools/analyze.mjs` | Driving and inspecting a running build |
| `src/physics/selftest.js`, `src/audio/selftest.js`, `src/ai/selftest.mjs` | Per-subsystem self-tests |

And `ARCHITECTURE.md` turns two of those into a hard merge gate `[PRIMARY]`:

> npm run build must pass and node tools/capture.mjs must produce a frame after your change.

plus a strict directory-ownership rule that is really a *concurrency* control for multi-agent work
`[PRIMARY]`:

> Never edit files outside it. Another agent owns every other directory and your edit will be
> clobbered or will break them.

`[INFERENCE]` **The lesson to carry:** the interesting content of the Gauntlet Loop is not the
prompt. It is that somebody built a deterministic instrument set so the critic had something real
to inspect, and then made passing those instruments non-negotiable. The `robonuggets` README says
the same thing in one line — "If the agent cannot get the reference, it hallucinates the comparison
and approves everything" — and a search summary of the coverage reports the same as the single
biggest predictor of a useful run: "whether the critic had something real to inspect."
`[SEARCH-SUMMARY]`

### 2.6 Independent replication: where it breaks

`github.com/NathanMaine/gauntletx` is an independent attempt to run Gauntlet Loops on small
local models (3B–35B on vLLM), credited as "Method by Matt Shumer; diagnosis, architecture, and
verification by Nathan Maine." `[PRIMARY]` (repo README). Its central finding:

> [All three] built competently… What degrades is self-assessment.

and:

> a smaller model builds almost as well and judges far worse.

Concretely, across three documented runs: a 35B coder model reported **100% accuracy** that was
actually a string-comparison bug in its own measurement code; another reported beating a baseline
that had been miscalculated; only the run on a stronger model correctly reported a poor number
(0.10%) and **failed its own round**, which held up on holdout data. `[PRIMARY]` for the README's
account; I did not re-run any of it.

The generalizable claim: **measurement code written by the agent is part of the attack surface.**
A critic that computes its own evidence can be wrong in the direction that flatters the builder,
and it will not crash — it will return a plausible number. Maine's remedy is "deterministic
contracts (baseline checks, status pages) that frontier models largely self-supply." `[PRIMARY]`

### 2.7 What I could not verify

Stated plainly, so nobody downstream treats these as established:

- **The exact text of Shumer's guide and X thread.** Blocked. Everything about the guide's
  *contents* here is `[SEARCH-SUMMARY]`.
- **Any controlled evaluation of the Gauntlet Loop.** I found none. There is no benchmark, no
  ablation, no A/B against a single-agent baseline, no held-out task set. The technique's evidence
  base is one public demo (which by its own README missed its bar), one small-model replication
  that found the judging step unreliable, and a body of enthusiastic secondary coverage. Treat
  "the Gauntlet Loop works" as **an untested hypothesis with a plausible mechanism**, not a result.
- **The 3.8M-views / "convinced it was fake" claims.** `[SEARCH-SUMMARY]` only, and irrelevant to
  engineering merit.
- **Whether `/loop` and `ultracode` behave as described.** Harness features; `[SECOND-HAND]`.
- **Claims that the technique has been successfully applied to "bug sweeps, legal memos, and
  fantasy football drafts."** `[SEARCH-SUMMARY]` from reply threads. No artifacts.

`[INFERENCE]` **Net assessment for this team.** The Gauntlet Loop is a *well-chosen name for a
correct instinct* — separate the critic from the builder, give it an external bar, make it pick
rather than score, and don't stop on a timer — with essentially no controlled evidence behind the
specific packaging. Adopt the instinct. Do not adopt the loop's open-ended termination condition,
which its own flagship demo demonstrates can run for rounds without ever reaching its bar. And
notice that the parts of the demo that produced hard, defensible improvements were the executable
ones.

---

## Matt Shumer's other published techniques

Same confidence discipline. Shumer's public output is mostly GitHub repos and X threads; the repos
are reachable from here and the threads are not, so this section is `[PRIMARY]` on code and
`[SEARCH-SUMMARY]` on narrative.

### 3.1 `gpt-prompt-engineer` — ELO tournament over candidate prompts

`github.com/mshumer/gpt-prompt-engineer` (~9.7k stars). `[PRIMARY]`, README read raw.

Mechanism: you supply a task description and test cases; the system generates many candidate
prompts, runs each against all test cases, and **ranks them by ELO** — every candidate starts at
1200 and ratings move on head-to-head comparative performance. A Claude 3 Opus variant adds
auto-generated test cases and multiple input variables.

**Why it matters for a QA process.** This is a *pairwise-comparison judging system with a rating
model*, which is exactly the LLM-as-judge pattern from the literature (§4.2) applied to prompts
instead of outputs. The ELO framing is a real improvement over absolute scoring: it forces the
judge to pick, and it aggregates many noisy pairwise picks into a stable ordering. The same idea
is what makes Chatbot Arena work. `[INFERENCE]`

**What to watch.** The README documents no mitigation for position bias — the single
best-characterized defect of pairwise LLM judging (§4.2). If A is presented first in every
comparison, the ELO table encodes the judge's positional preference as if it were quality.
`[INFERENCE]` The README's only stated caveat is cost ("can get expensive," start with 10 prompts)
`[PRIMARY]`. If you borrow this pattern, add order-swapping — it is a three-line change.

### 3.2 `OpenReasoningEngine` — test-time compute with tool-grounded checks

`github.com/mshumer/OpenReasoningEngine`. `[PRIMARY]`, README read raw. A modular test-time-compute
system for OpenAI-compatible models, with:

- **Self-reflection** — "Force the AI to validate reasoning steps as it thinks."
- **Python assertions** executed during reasoning, plus web search and Wolfram Alpha as tools.
- **Mixture-of-Agents** ensembling and **beam search** — "Sample multiple next reasoning step
  candidates at each turn, and choose the best."
- **Memory-based planning** over saved successful reasoning chains.

Stated limitations, verbatim `[PRIMARY]`: MoA "works but requires further testing"; "Performance
may vary based on the specific chains in your memory store," potentially dramatically.

**Relevance.** The pairing of *self-reflection* with *executed Python assertions* is the right
shape — reflection produces the hypothesis, execution adjudicates it. That is the same asymmetry
this whole chapter argues for. `[INFERENCE]`

### 3.3 `OpenDeepResearcher` — iterate-until-confident research loop

`github.com/mshumer/OpenDeepResearcher`. `[PRIMARY]`, README read raw. Generate queries → search
concurrently → dedupe and fetch → LLM judges each page's usefulness and extracts context → LLM
decides whether more research is needed → repeat, with a configurable max iteration count
defaulting to 10.

**Relevance and the caution.** This is an LLM-terminated loop: the model decides when it has
enough. The README acknowledges no limits on "search depth, query quality, or information
accuracy." `[PRIMARY]` A self-assessed stopping condition is exactly the thing the self-correction
literature says not to trust (§5.1) — but note that the repo *does* ship a hard iteration cap.
**Keep the cap; distrust the confidence.** `[INFERENCE]`

### 3.4 Other repos

`gpt-llm-trainer`, `gpt-author`, `autonomous-researcher` — task-specific scaffolds, not
verification techniques. `[PRIMARY]` on existence and star counts from the profile page; I did not
read them in depth because they are off-topic for QA.

### 3.5 The Reflection 70B episode — stated neutrally, because it is directly on-topic

In September 2024 Shumer announced **Reflection 70B**, claiming benchmark results superior to
GPT-4o and competitive with or beating Claude on some tests. Independent evaluators could not
reproduce the results; Artificial Analysis measured the released weights as roughly LLaMA 3-level
and below LLaMA 3.1. The training-data provider's founder stated that "the benchmark scores I
shared with Matt haven't been reproducible so far," and later published a post-mortem. Shumer
apologized on 10 September, saying he "got ahead of himself." An undisclosed investment in the
data provider was also reported. `[SEARCH-SUMMARY]` — VentureBeat and others; I could not open the
articles, so treat the details as reported rather than verified, and check them yourself before
repeating them.

**Why this belongs in a QA chapter, and what it is not.** It is not an argument that the Gauntlet
Loop is wrong — the Claude of Duty README is, if anything, unusually candid about its own failure,
which cuts the other way. It belongs here because it is a clean, high-profile instance of the exact
failure this chapter exists to prevent: **a self-reported evaluation that did not survive
independent replication.** The structural lesson is the one this document keeps returning to — the
entity that produced the work cannot be the entity that certifies it, and a number is only worth
what its reproduction procedure is worth. `[INFERENCE]`

Practical consequence for this team: when you adopt a technique from a practitioner source,
adopt the *mechanism* and re-derive the *evidence* yourself on your own task. Do not import claimed
results. That rule applies to this chapter too.

---
