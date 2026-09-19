#!/usr/bin/env bash
# Single entrypoint for every gate over the generated reference-data modules.
# Exits 0 only when all of them pass. Re-run this; never re-derive the checks.
set -uo pipefail

cd "$(dirname "$0")/.."
LUAU_DIR=src/shared/Data
JSON_DIR=research/vs
rc=0

run() {
  local name="$1"; shift
  echo "=== $name ==="
  if "$@"; then echo "--- $name OK"; else echo "--- $name FAILED"; rc=1; fi
  echo
}

run "fidelity (AC-03: no unsourced numeric literal)" \
  python3 tools/check_luau_fidelity.py "$LUAU_DIR" "$JSON_DIR" \
    --map=Characters.luau=characters.json \
    --map=CoreLoop.luau=core_loop.json \
    --map=EnemiesWaves.luau=enemies_waves.json \
    --map=PassivesEvolutions.luau=passives_evolutions.json \
    --map=PickupsMeta.luau=pickups_meta.json \
    --map=Weapons.luau=weapons.json

run "coverage (AC-04: every source value carried through)" \
  python3 tools/check_coverage.py "$LUAU_DIR" "$JSON_DIR"

run "structure + referential integrity (AC-01,02,05..26)" \
  python3 tools/check_structure.py "$LUAU_DIR" "$JSON_DIR"

run "no verbatim shipped text (AC-29)" \
  python3 tools/check_no_verbatim_text.py "$LUAU_DIR" "$JSON_DIR"

run "determinism (AC-28: regeneration is byte-identical)" \
  python3 tools/check_determinism.py "$LUAU_DIR" "$JSON_DIR"

run "format (AC-02)" stylua --check "$LUAU_DIR"

# Real Luau toolchain. Required: AC-27 says this entrypoint's exit code covers
# AC-02/AC-23, so a missing toolchain is a gate failure, not a skip.
echo "=== luau-analyze (AC-02/AC-23) ==="
if ! command -v luau-analyze >/dev/null 2>&1; then
  echo "luau-analyze not installed; cannot gate AC-02/AC-23"
  echo "--- luau-analyze FAILED"
  rc=1
elif luau-analyze "$LUAU_DIR"/*.luau; then
  echo "--- luau-analyze OK"
else
  echo "--- luau-analyze FAILED"
  rc=1
fi
echo

if [ "$rc" -eq 0 ]; then echo "ALL GATES PASSED"; else echo "GATES FAILED"; fi
exit "$rc"
