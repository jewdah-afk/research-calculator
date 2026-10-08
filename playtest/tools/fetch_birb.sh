#!/bin/bash
# Downloads Birb's live JS bundles into a folder OUTSIDE the repo and pretty-prints them for reading.
# Birb's code must never be committed (project rule): only numbers are copied into the playtest.
# Usage: playtest/tools/fetch_birb.sh /tmp/birb      (needs node with prettier, acorn, acorn-walk, playwright)
set -e
OUT=${1:-/tmp/birb}; mkdir -p "$OUT"; cd "$OUT"
curl -sSL https://birbplay.com/ -o index.html
# index.html names the entry chunks; game-*.js is imported by main-*.js, so follow imports one level deep
for f in $(grep -o 'assets/[A-Za-z0-9_-]*\.js' index.html | sort -u); do curl -sSL "https://birbplay.com/$f" -o "$(basename $f)"; done
for f in $(cat *.js | grep -o '\./[A-Za-z0-9_-]*\.js' | sort -u); do [ -f "$(basename $f)" ] || curl -sSL "https://birbplay.com/assets/$(basename $f)" -o "$(basename $f)"; done
for f in *.js; do case $f in *.pretty.js) ;; *) npx --yes prettier --parser babel "$f" > "${f%.js}.pretty.js" 2>/dev/null || true;; esac; done
ls -la "$OUT"
