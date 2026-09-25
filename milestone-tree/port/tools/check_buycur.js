// Checks view.js's rbx_BUY_CUR (the currency each buyable's canAfford reads): for every save and every unlocked
// buyable in the table, have >= cost must be the game's own canAfford. usage: node tools/check_buycur.js states.json
// Prints each mismatch and exits 1 when there is one.
const fs = require('fs'), path = require('path');
const states = JSON.parse(fs.readFileSync(process.argv[2] || path.join(__dirname, '..', 'data', 'fz', 'states.json')));
const CHECK = `(function () {
	var out = [], n = 0
	for (var l in rbx_BUY_CUR) for (var id in rbx_BUY_CUR[l]) {
		var t = tmp[l].buyables && tmp[l].buyables[id]
		if (!t || !t.unlocked || t.cost === undefined) continue
		var have = rbx_buyHave(rbx_BUY_CUR[l][id])
		if (have === undefined) { out.push(l + " " + id + ": no currency"); continue }
		n++
		var mine = new Decimal(have).gte(t.cost), game = t.canAfford ? true : false
		if (mine != game) out.push(l + " " + id + ": have " + format(have) + " cost " + format(t.cost) + " table says " + mine + ", game " + game)
	}
	return JSON.stringify({ n: n, out: out })
})()`;
let bad = 0, checked = 0;
for (let i = 0; i < states.length; i++) {
	const G = require('../jsrbx')(); G.seed(states[i].seed); G.ctx.__save = states[i].save;
	try { G.run('rbx_boot(__save, "")'); } catch (e) { continue; }
	let r;
	try { r = JSON.parse(G.run(CHECK)); } catch (e) { console.log('S' + i + ' check failed: ' + e.message); bad++; continue; }
	checked += r.n;
	for (const m of r.out) { console.log('S' + i + ' ' + m); bad++; }
}
console.log('buyables checked ' + checked + ', mismatches ' + bad);
process.exit(bad ? 1 : 0);
