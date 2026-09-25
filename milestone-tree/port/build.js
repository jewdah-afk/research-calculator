// Transpiles the web game (../game-js) into Luau chunks, each `return function() ... end`, run in a player's
// game environment (see src/server/Session.luau).
//   ../src/server/Game/*.luau   what the Roblox game loads: the game files, stubs, rbx/session.js, rbx/view.js,
//                               in load order in Game/Manifest.luau
//   ./gen/*.luau                only for the headless tests: boot.js, bot.js, dump.js, view_dump.js
// usage: node build.js   (GAME_JS / GAME_OUT / GEN_OUT override the folders)
const fs = require('fs'), path = require('path');
const { transpile } = require('./js2lua');
const JSDIR = process.env.GAME_JS || path.join(__dirname, '..', 'game-js');
const GAME = process.env.GAME_OUT || path.join(__dirname, '..', 'src', 'server', 'Game');
const GEN = process.env.GEN_OUT || path.join(__dirname, 'gen');
const files = JSON.parse(fs.readFileSync(path.join(__dirname, 'files.json'))).filter(f => !f.includes('break_eternity'));
for (const d of [GAME, GEN]) {
	fs.mkdirSync(d, { recursive: true });
	for (const f of fs.readdirSync(d)) if (f.endsWith('.luau')) fs.unlinkSync(path.join(d, f));
}
let fail = 0;
function build(full, f, out) {
	const name = f.replace(/\.js$/, '').replace(/[\/]/g, '_');
	try {
		const lua = transpile(fs.readFileSync(full, 'utf8'), f);
		fs.writeFileSync(path.join(out, name + '.luau'), '--!nocheck\n-- transpiled from ' + f + ' by port/build.js: do not edit\nreturn function()\n' + lua + '\nend\n');
	} catch (e) { fail++; console.log('FAIL', f, e.message) }
	return name;
}
const game = files.map(f => build(path.join(JSDIR, f), f, GAME));
game.push(build(path.join(__dirname, 'stubs.js'), 'stubs.js', GAME));
const rbx = ['rbx/session.js', 'rbx/view.js'].map(f => build(path.join(__dirname, f), f, GAME));
for (const f of ['boot.js', 'bot.js', 'dump.js', 'view_dump.js']) build(path.join(__dirname, f), f, GEN);
fs.writeFileSync(path.join(GAME, 'Manifest.luau'), '-- load order of the game chunks (port/build.js)\nreturn "' + game.concat(rbx).join(',') + '"\n');
console.log('ok', game.length + rbx.length, 'game chunks, 4 harness chunks, fail', fail);
if (fail) process.exit(1);
