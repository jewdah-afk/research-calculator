#!/usr/bin/env bash
# Headless mechanics tests: every tests/*.test.luau runs under the plain `luau`
# CLI with no Roblox runtime. A test file returns 0 on success, non-zero on
# failure (see tests/_harness.luau). Exit 0 only when every file passes.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0; n=0
for f in tests/*.test.luau; do
  n=$((n+1))
  printf '%-44s ' "$f"
  out=$(luau "$f" 2>&1); code=$?
  # Belt and braces: trust the exit code, but also fail on any FAIL marker in
  # the output, so a harness that forgets to raise cannot report a green suite.
  if [ "$code" -eq 0 ] && ! printf '%s' "$out" | grep -q 'FAIL'; then
    echo "$out" | tail -1
  else
    echo; echo "$out" | tail -25; rc=1
  fi
done
[ "$n" -eq 0 ] && { echo "no tests found"; exit 1; }
if [ "$rc" -eq 0 ]; then echo "ALL TESTS PASSED ($n files)"; else echo "TESTS FAILED"; fi
exit "$rc"
