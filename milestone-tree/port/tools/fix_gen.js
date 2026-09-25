// Transpiles tools/fix_pre.js (the capture fixtures' scripted states) to data/fixtures/fix_pre.luau.
// usage: node tools/fix_gen.js   (run by ./test.sh capture before tools/capture.luau)
const fs = require('fs'), path = require('path');
const { transpile } = require('../js2lua');
const out = path.join(__dirname, '..', 'data', 'fixtures');
fs.mkdirSync(out, { recursive: true });
const lua = transpile(fs.readFileSync(path.join(__dirname, 'fix_pre.js'), 'utf8'), 'tools/fix_pre.js');
fs.writeFileSync(path.join(out, 'fix_pre.luau'), '--!nocheck\n-- transpiled from tools/fix_pre.js by tools/fix_gen.js: do not edit\nreturn function()\n' + lua + '\nend\n');
