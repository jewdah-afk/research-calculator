// Splits tools/capture.luau's output into one file per fixture: <name>.json and <name>.luau (return { ... }), plus
// index.json (the names). usage: luau tools/capture.luau | node tools/split_fix.js data/fixtures
const fs = require('fs'), path = require('path');
const dir = process.argv[2] || 'data/fixtures';
fs.mkdirSync(dir, { recursive: true });
const KW = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or',
	'repeat', 'return', 'then', 'true', 'until', 'while', 'continue', 'export', 'type', 'typeof']);
function luaStr(s) {
	return '"' + s.replace(/[\\"\x00-\x1f\x7f]/g, c => {
		if (c === '"') return '\\"';
		if (c === '\\') return '\\\\';
		if (c === '\n') return '\\n';
		if (c === '\r') return '\\r';
		if (c === '\t') return '\\t';
		return '\\' + String(c.charCodeAt(0)).padStart(3, '0');
	}) + '"';
}
function lua(v) {
	if (v === null || v === undefined) return 'nil';
	if (typeof v === 'boolean') return String(v);
	if (typeof v === 'number') return Number.isFinite(v) ? String(v) : (v > 0 ? 'math.huge' : '-math.huge');
	if (typeof v === 'string') return luaStr(v);
	if (Array.isArray(v)) return '{' + v.map(lua).join(', ') + '}';
	return '{' + Object.keys(v).map(k => ((/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) && !KW.has(k)) ? k : '[' + luaStr(k) + ']') + ' = ' + lua(v[k])).join(', ') + '}';
}
const lines = fs.readFileSync(0, 'utf8').split('\n');
const names = [];
let bad = 0;
for (let i = 0; i < lines.length; i++) {
	const line = lines[i];
	if (line.startsWith('-- ')) { console.log(line); continue; }
	if (!line.startsWith('@@FIX ')) continue;
	const name = line.slice(6).trim();
	let v;
	try { v = JSON.parse(lines[++i]); } catch (e) { console.log('bad fixture', name, e.message); bad++; continue; }
	fs.writeFileSync(path.join(dir, name + '.json'), JSON.stringify(v));
	fs.writeFileSync(path.join(dir, name + '.luau'), '--!nocheck\n-- ' + name + ': a full view patch written by ./test.sh capture (tools/capture.luau): do not edit\nreturn ' + lua(v) + '\n');
	names.push(name);
}
fs.writeFileSync(path.join(dir, 'index.json'), JSON.stringify(names));
console.log('fixtures:', names.length, names.join(' '));
if (bad || !names.length) process.exit(1);
