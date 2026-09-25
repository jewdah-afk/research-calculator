#!/usr/bin/env bash
# The port's tests. Needs node (run `npm install` here once), python3 and luau (https://github.com/luau-lang/luau
# releases; set LUAU=/path/to/luau when it is not on PATH).
#
#   ./test.sh game [dir] [states] [seed]   the game: random saves + actions, JS vs Luau, every player/tmp value
#   ./test.sh view [dir]                   the screen: every tab of those saves, JS vs Luau, every view node
#   ./test.sh decimal                      Decimal ops: the game's break_eternity vs the port (TowerNum + BEcore)
#   ./test.sh strings                      new Decimal(string): the game's parser vs the port
#   ./test.sh html [dir]                   HTML -> RichText on every string the game showed in `view`
#   ./test.sh timeline                     2000 ticks of the deterministic bot, JS vs Luau
#   ./test.sh sim [seconds]                the Roblox Session end to end: 20 ticks/s, views, a bot, saves, import
#   ./test.sh roblox                       the Roblox scripts (server, Actor worker, DataStore, client UI) on a mock engine
#   ./test.sh all                          all of the above (game/view with 60 states, seed 7)
# Differences left in `game` / `view` are last-digit float noise (see README).
set -e
cd "$(dirname "$0")"
LUAU=${LUAU:-luau}
export LUAU

game() {
	local dir=${1:-fz} n=${2:-60} seed=${3:-7}
	mkdir -p data/$dir
	node gen_states.js $n $seed > data/$dir/states.json
	python3 tools/tolua.py data/$dir/states.json data/$dir/fz_states.luau
	echo "== game: $n states (seed $seed), JS side..."
	FZ_TIMEOUT=${FZ_TIMEOUT:-20000} node fuzz_js.js data/$dir/states.json data/$dir/js.txt > data/$dir/js.log 2>&1
	python3 tools/skiplist.py data/$dir/js.txt data/$dir/fz_skip.luau
	echo "== game: Luau side..."
	"$LUAU" -O2 run_fuzz.luau -a $dir > data/$dir/lua.txt
	python3 compare.py data/$dir/js.txt data/$dir/lua.txt 1e-9 | grep -v STATUS
}
view() {
	local dir=${1:-fz}
	echo "== view: JS side..."
	SKIP=$(sed 's/return "\(.*\)"/\1/' data/$dir/fz_skip.luau) node view_js.js data/$dir/states.json data/$dir/view_js.txt
	echo "== view: Luau side..."
	"$LUAU" -O2 view_run.luau -a $dir > data/$dir/view_lua.txt
	python3 view_cmp.py data/$dir/view_js.txt data/$dir/view_lua.txt
}
decimal() {
	mkdir -p data/dec
	node dec_gen.js 20000 3 > data/dec/cases.txt
	python3 tools/tolua.py data/dec/cases.txt data/dec/cases.luau
	"$LUAU" -O2 dec_run.luau
}
strings() {
	mkdir -p data/str
	node str_gen.js 6000 5 > data/str/cases.txt
	python3 tools/tolua.py data/str/cases.txt data/str/cases.luau
	"$LUAU" -O2 str_run.luau
}
html() {
	local dir=${1:-fz}
	mkdir -p data/html
	python3 tools/html_cases.py data/$dir/view_js.txt data/html/cases.luau
	"$LUAU" tests/html_test.luau
}
timeline() {
	mkdir -p data
	node js_run.js 2000 0.05 200 | grep -v '^--' > data/timeline_js.txt
	"$LUAU" -O2 run.luau -a 2000 0.05 200 | grep -v '^--' > data/timeline_lua.txt
	if diff data/timeline_js.txt data/timeline_lua.txt; then echo "timeline: identical"; else echo "timeline: DIFFERENT"; exit 1; fi
}
sim() {
	"$LUAU" -O2 tests/sim.luau -a ${1:-60}
}
roblox() {
	python3 tools/wrap_scripts.py
	"$LUAU" tests/roblox.luau
	"$LUAU" tests/roblox.luau -a studio
}

case ${1:-all} in
	game) shift; game "$@" ;;
	view) shift; view "$@" ;;
	decimal) decimal ;;
	strings) strings ;;
	html) shift; html "$@" ;;
	timeline) timeline ;;
	sim) shift; sim "$@" ;;
	roblox) roblox ;;
	all) node build.js; timeline; decimal; strings; game; view; html; sim 60; roblox ;;
	*) echo "unknown test $1"; exit 1 ;;
esac
