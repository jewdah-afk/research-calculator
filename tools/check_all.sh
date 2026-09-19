#!/usr/bin/env bash
# THE single verification entrypoint for the whole repo. Exit 0 only when
# everything passes. Contributors and agents run this before every commit;
# CI would run exactly this.
#
#   data gates   tools/run_gates.sh        generated modules vs research JSON
#   format       stylua --check            src/ tests/
#   types        luau-lsp analyze          Roblox globals + cross-file requires
#   mechanics    tools/run_tests.sh        headless tests under plain luau
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
step() { echo; echo "=== $1 ==="; }

step "data gates"
bash tools/run_gates.sh >/tmp/gates.out 2>&1
if [ $? -eq 0 ]; then echo "OK"; else tail -30 /tmp/gates.out; rc=1; fi

step "format (stylua)"
if stylua --check src tests; then echo "OK"; else rc=1; fi

step "types + lint (luau-lsp analyze, strict)"
mapfile -t FILES < <(find src tests -name '*.luau' | sort)
if luau-lsp analyze \
     --definitions=tools/types/globalTypes.d.luau \
     --platform=roblox \
     --base-luaurc=.luaurc \
     "${FILES[@]}" 2>&1 | grep -v '^\[INFO\]' | tee /tmp/analyze.out | grep -qE 'Error|Warning|Lint'; then
  cat /tmp/analyze.out | head -80; rc=1
else
  echo "OK (${#FILES[@]} files)"
fi

step "mechanics tests (headless luau)"
if bash tools/run_tests.sh; then :; else rc=1; fi

echo
if [ "$rc" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$rc"
