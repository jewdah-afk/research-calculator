#!/bin/bash
# Send JS (stdin) to tools/birbrepl.js running Birb live: echo "return game.state.parrot" | playtest/tools/q.sh
curl -s -X POST --data-binary @- http://127.0.0.1:9333/
