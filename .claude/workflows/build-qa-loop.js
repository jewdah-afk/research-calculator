export const meta = {
  name: 'build-qa-loop',
  description: 'Build a target, then loop: deterministic gates, dimension review, adversarial verify, fix, QA gate',
  whenToUse: 'Producing production-quality code or data from a spec, when correctness matters more than speed',
  phases: [
    { title: 'Contract',  detail: 'derive machine-checkable acceptance criteria before any building' },
    { title: 'Build',     detail: 'one agent per module, in parallel' },
    { title: 'Gates',     detail: 'deterministic checks: parse, schema, value fidelity vs source' },
    { title: 'Review',    detail: 'parallel reviewers, each with a distinct rubric' },
    { title: 'Verify',    detail: 'adversarial refutation of every finding, 3 lenses, majority rules' },
    { title: 'Fix',       detail: 'apply confirmed findings only' },
    { title: 'QA',        detail: 'single gate agent: SHIP or ITERATE against the contract' },
  ],
}

// ---------------------------------------------------------------- config
const cfg = args || {}
const TARGET      = cfg.target      || 'the current working tree'
const SPEC        = cfg.spec        || 'research/vs/'
const MODULES     = cfg.modules     || ['all']
const MAX_PASSES  = cfg.maxPasses   || 3
const VERIFIERS   = cfg.verifiers   || 3
const GATE_CMDS   = cfg.gateCommands || []

// Distinct rubrics, NOT N agents on the same rubric. Diversity comes from the
// lens, not the headcount -- correlated reviewers add cost, not coverage.
const RUBRICS = cfg.rubrics || [
  { key: 'fidelity',    prompt: 'Does every numeric value trace back to the source data, with the right units, scale and sign? Hunt transcription drift, unit mix-ups, and silently dropped fields.' },
  { key: 'correctness', prompt: 'Logic bugs: off-by-one, wrong operator, bad nil handling, unreachable branches, incorrect early return. Ignore style entirely.' },
  { key: 'contract',    prompt: 'Does it satisfy every acceptance criterion in the contract? Name any criterion that is unmet or only partly met.' },
  { key: 'ergonomics',  prompt: 'API shape and naming: would a teammate misuse this? Misleading names, leaky abstractions, inconsistent conventions across modules.' },
  { key: 'perf',        prompt: 'Hot-path cost: allocation in loops, repeated table lookups, O(n^2) over entity counts, anything that degrades at 2000+ entities.' },
]

const CONTRACT = { type: 'object', properties: {
  criteria: { type: 'array', items: { type: 'object', properties: {
    id: {type:'string'}, statement: {type:'string'}, checkable: {type:'boolean'}, howToCheck: {type:'string'},
  }, required: ['id','statement','checkable','howToCheck'] } },
  openQuestions: { type: 'array', items: {type:'string'} },
}, required: ['criteria','openQuestions'] }

const FINDINGS = { type: 'object', properties: {
  findings: { type: 'array', items: { type: 'object', properties: {
    id: {type:'string'}, file: {type:'string'}, line: {type:'number'},
    severity: {type:'string', enum:['blocker','major','minor','nit']},
    claim: {type:'string'}, evidence: {type:'string'}, suggestedFix: {type:'string'},
  }, required: ['id','file','claim','evidence','severity'] } },
}, required: ['findings'] }

const VERDICT = { type: 'object', properties: {
  refuted: {type:'boolean'}, confidence: {type:'string', enum:['low','medium','high']}, reasoning: {type:'string'},
}, required: ['refuted','confidence','reasoning'] }

const QA = { type: 'object', properties: {
  decision: {type:'string', enum:['SHIP','ITERATE']},
  unmetCriteria: { type:'array', items:{type:'string'} },
  rationale: {type:'string'},
  nextPassFocus: {type:'string'},
}, required: ['decision','unmetCriteria','rationale'] }

const key = f => `${f.file}:${f.line || 0}:${(f.claim||'').slice(0,80)}`

// ------------------------------------------------- phase 0: the contract
// Highest-value step in the whole pipeline. Without written, checkable
// acceptance criteria, reviewers argue taste and the loop never converges.
phase('Contract')
const contract = await agent(
  `Read the spec at ${SPEC} and the target ${TARGET}.
Write the acceptance criteria this work must meet BEFORE any of it is built or reviewed.
Prefer criteria a machine can check (value X in file Y equals value X in source Z) over
subjective ones. Mark each as checkable true/false and say exactly how to check it.
List open questions where the spec is genuinely ambiguous -- do not invent answers.`,
  { schema: CONTRACT, phase: 'Contract' })

if (!contract) { log('Contract stage failed -- aborting rather than building against nothing.'); return { error: 'no contract' } }
log(`Contract: ${contract.criteria.length} criteria (${contract.criteria.filter(c=>c.checkable).length} machine-checkable), ${contract.openQuestions.length} open questions`)

const contractText = contract.criteria.map(c => `[${c.id}] ${c.statement} -- check: ${c.howToCheck}`).join('\n')

// ------------------------------------------------------- phase 1: build
phase('Build')
await parallel(MODULES.map((m, i) => () => agent(
  `Build: ${m}
Target: ${TARGET}
Spec/source data: ${SPEC}

Acceptance criteria you must satisfy:
${contractText}

Write the code. Follow existing conventions in the repo. Do not invent values that are
not in the source data -- if something is missing there, leave it nil and say so.`,
  { label: `build:${m}`, phase: 'Build' })))

// ------------------------------------------- the loop: gates -> ... -> QA
const seen = new Set()
const allConfirmed = []
let decision = 'ITERATE'
let focus = ''

for (let pass = 1; pass <= MAX_PASSES && decision === 'ITERATE'; pass++) {
  log(`--- pass ${pass}/${MAX_PASSES} ---`)

  // Phase 2: deterministic gates. Cheap, objective, and they catch more real
  // defects than any amount of LLM review. Always run first.
  phase('Gates')
  const gate = await agent(
    `Run the deterministic checks on ${TARGET} and report failures verbatim.
${GATE_CMDS.length ? `Run exactly these commands:\n${GATE_CMDS.join('\n')}` : `Work out the right checks yourself: syntax/parse check every file, validate any JSON,
and cross-check emitted numeric values against the source data in ${SPEC}.`}
Report only what actually failed, with the real command output. Do not speculate.`,
    { label: 'gates', phase: 'Gates', effort: 'low' })

  // Phase 3: review. Distinct rubrics in parallel, each blind to the others.
  // Phase 4: verify. Pipelined so a rubric's findings start verification as
  // soon as that rubric lands -- no barrier, no idle reviewers.
  phase('Review')
  const rounds = await pipeline(
    RUBRICS,
    r => agent(
      `Review ${TARGET} on ONE dimension only: ${r.key}.
${r.prompt}

Contract:
${contractText}

Deterministic gate output from this pass:
${gate || '(none)'}
${focus ? `\nThe QA gate asked this pass to focus on: ${focus}` : ''}

Report concrete findings with file, line and the evidence you actually read.
Do not report anything you have not verified in the file. Empty list is a fine answer.`,
      { label: `review:${r.key}`, phase: 'Review', schema: FINDINGS }),

    (res, r) => {
      const fresh = (res?.findings || []).filter(f => !seen.has(key(f)))
      fresh.forEach(f => seen.add(key(f)))
      if (!fresh.length) return []
      // Adversarial verification -- this REPLACES "reviewers reviewing reviewers".
      // Each verifier re-examines the artifact and tries to refute the claim.
      // Uncertainty defaults to refuted, so unproven findings never reach Fix.
      return parallel(fresh.map(f => () =>
        parallel(Array.from({length: VERIFIERS}, (_, vi) => () => agent(
          `Try to REFUTE this ${r.key} finding by reading the actual file. Verifier ${vi+1}.
File: ${f.file}${f.line ? `:${f.line}` : ''}
Claim: ${f.claim}
Evidence given: ${f.evidence}

Open the file and check. If the claim does not hold, or you cannot confirm it from what
is actually written there, set refuted=true. Default to refuted=true when uncertain.`,
          { label: `verify:${f.id}.${vi+1}`, phase: 'Verify', schema: VERDICT })))
        .then(vs => {
          const ok = vs.filter(Boolean)
          const survives = ok.length && ok.filter(v => !v.refuted).length > ok.length / 2
          return survives ? f : null
        })))
    })

  const confirmed = rounds.flat(2).filter(Boolean)
  const rejected = seen.size - allConfirmed.length - confirmed.length
  log(`pass ${pass}: ${confirmed.length} findings confirmed, ~${Math.max(0,rejected)} refuted and dropped`)

  if (confirmed.length) {
    allConfirmed.push(...confirmed)
    phase('Fix')
    // Fix by file, so two agents never write the same file concurrently.
    const byFile = {}
    confirmed.forEach(f => (byFile[f.file] = byFile[f.file] || []).push(f))
    await parallel(Object.entries(byFile).map(([file, fs]) => () => agent(
      `Apply these verified findings to ${file}. Change nothing else.
${fs.map(f => `- [${f.severity}] ${f.claim}\n  fix: ${f.suggestedFix || 'use your judgement'}`).join('\n')}

Keep each fix minimal. Never delete or weaken a test to make something pass.
If a finding turns out to be wrong when you look at the code, skip it and say why.`,
      { label: `fix:${file.split('/').pop()}`, phase: 'Fix' })))
  }

  // Phase 6: one QA gate, judging against the contract -- not against vibes.
  phase('QA')
  const qa = await agent(
    `You are the release gate for ${TARGET}. Judge it against the contract ONLY.

${contractText}

This pass: ${confirmed.length} findings confirmed and fixed. Gate output:
${gate || '(none)'}

Check the criteria yourself against the current files. Answer SHIP only if every
criterion is met or explicitly waived. Otherwise ITERATE and name what to fix next.
Do not pass something because it is close.`,
    { label: 'qa-gate', phase: 'QA', schema: QA, effort: 'high' })

  decision = qa?.decision || 'ITERATE'
  focus = qa?.nextPassFocus || ''
  log(`pass ${pass}: QA says ${decision}${qa?.unmetCriteria?.length ? ` -- unmet: ${qa.unmetCriteria.join(', ')}` : ''}`)

  // Converged: gates quiet and nothing survived verification.
  if (!confirmed.length && decision === 'ITERATE') {
    log('No confirmed findings this pass -- further passes would be churn. Stopping.')
    break
  }
}

if (decision === 'ITERATE') log(`Stopped at the pass limit without a SHIP. Remaining work is real, not a formality.`)
return { decision, passes: MAX_PASSES, confirmed: allConfirmed, contract: contract.criteria.length, openQuestions: contract.openQuestions }
