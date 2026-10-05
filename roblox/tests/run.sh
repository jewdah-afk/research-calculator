#!/usr/bin/env bash
# Runs the QA suite outside Roblox with the standalone `luau` CLI.
#   LUAU=/path/to/luau ./tests/run.sh [pacing-tiers]
# Shared modules are copied to tests/.build with `script.Parent` requires rewritten to file paths,
# EternityNum replaced by a log-space shim, and Roblox's Random by a math.random shim.
set -euo pipefail
cd "$(dirname "$0")"
LUAU="${LUAU:-luau}"
rm -rf .build && mkdir -p .build
for f in ../src/shared/*.luau; do
  n=$(basename "$f")
  sed -e 's/require(script.Parent.\([A-Za-z]*\))/require(".\/\1")/' "$f" > ".build/$n"
  sed -i '1a local Random = require("./RandomShim")' ".build/$n"
done
python3 - <<'PY'
import re
p='.build/Big.luau'; s=open(p).read()
s=re.sub(r'local ReplicatedStorage = .*?local EN = require\(ENModule\)', 'local EN = require("./ENShim")', s, flags=re.S)
open(p,'w').write(s)
PY
cp shims/*.luau .build/
cp UnitTests.luau PacingSim.luau main.luau .build/
cd .build && "$LUAU" main.luau -a "${1:-30}"
