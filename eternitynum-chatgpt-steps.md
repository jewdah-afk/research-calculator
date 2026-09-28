# EternityNum optimization — ChatGPT prompts

Send one step at a time. Wait for the answer. After every change: re-run Step 2 (tests) and Step 3 (benchmark).
Each box has a copy button on GitHub.

## 1. Rules

```
We're optimizing the EternityNum module (FoundForces) for Roblox Luau. Rules for everything from now on:
1. Results must be IDENTICAL to the original (same sign/layer/exp and same formatted strings). Speed never excuses different output.
2. Keep the original untouched as "Original"; the new one is "Optimized". Same public API: names, arguments, return types.
3. One change at a time. After each: re-run correctness test, then benchmark.
4. Always give me the COMPLETE file, never "rest stays the same".
5. If you're not sure a change keeps identical results, say so.
```

## 2. Correctness test

```
Write a Luau test that runs the same inputs through Original and Optimized and reports every mismatch (function, input, both outputs). Cover every public function: add, sub, mul, div, pow, me, meeq, le, leeq, eq, between, conversions, parsing, short, suffix/notation, toString.
Inputs: 0, -0, 1, -1, 1e-10, negatives everywhere; around 999, 1000, 999999, 1e6 and every suffix boundary; around 1e303 and 1e308; layer 0->1->2 transitions and huge layers; NaN, inf, -inf, "", garbage strings; my real save strings; equal numbers and numbers 1 ulp apart; 10,000 random values across all layers with a fixed seed.
Print "ALL PASS" or the mismatch count plus the first 20.
```

## 3. Trustworthy benchmark

```
Fix the benchmark: warm up each workload first; run each 7+ times and report median/min/max; use os.clock(); build all inputs BEFORE timing; store results and use them afterward so nothing is skipped; same inputs for both versions. Tell me if it runs under --!native and --!optimize 2 (live servers use optimize 2, Studio may not).
```

## 4. Find the hot spots

```
Before optimizing more, list for each hot function in Optimized: tables created per call; math.log10 / 10^x / math.pow calls; string ops (format, gsub, split, concat, tostring/tonumber); metatable/setmetatable, pcall, varargs, closures per call; whether it normalizes inputs that are already normalized. Rank by likely cost.
```

## 5a. Comparisons (were still 0.99x)

```
Rewrite the comparison functions to exit early with no math: check sign, then layer, then exp; only do deeper math on a full tie. No new tables, no normalizing already-normalized inputs.
```

## 5b. Parsing

```
Make string parsing a single pass: string.find/string.byte instead of split/gsub, one tonumber per part, fast paths for plain numbers ("123", "1.5e20") and my save format. Identical results for every test input, including garbage.
```

## 5c. Suffixes / short()

```
Make short() and suffix formatting use lookup tables built once at module load, not per call. Avoid repeated string.format and concatenation. Find the suffix index with math.floor(log10/3) instead of loops.
```

## 5d. Fewer tables

```
Reduce table allocations: fixed-shape constructors {s, l, e} or table.create, no temporary tables inside math functions, skip normalization on results that are already normal.
```

## 5e. Luau tricks

```
Apply Luau performance practices: cache math functions in locals (local log10 = math.log10), add --!native and type annotations on hot functions, no varargs or pcall in hot paths, avoid ':' metatable method calls in hot paths, add a fast path when both values are plain layer-0 numbers.
```

## 5f. Pow / mul / div

```
In pow, mul and div: find any 10^x or log10 computed twice that can be reused, and whether integer exponents can take a cheaper path. Exact results must match.
```

## 6. When the test fails

```
The correctness test shows mismatches: [PASTE THEM]
Don't guess. Trace both versions step by step on the first mismatch with that exact input, show intermediate values, find the first line where they differ, fix only that, then re-run the full test.
```

## 6b. If it's still broken after 2 tries

```
Revert that last optimization completely and give me the last version that passed.
```

## 7. Final check

```
Final review: 1) run the full correctness test plus 1,000,000 random fuzz cases with a new seed; 2) re-run the full benchmark, Original vs Optimized; 3) list every change and why results stay identical; 4) list risks: edge cases, save compatibility, Roblox-only behavior.
```

## Red flags

- "Should be the same" without running the test.
- Function names, arguments or return values changed.
- Faster only because the benchmark changed.
- More than 10x on something simple: work probably got skipped.
- File cut off with "...".
- Old saves don't load. Test a real save every time.
