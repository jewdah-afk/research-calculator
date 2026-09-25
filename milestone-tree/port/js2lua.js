// js2lua: transpiles the Milestone Tree NG+ (TMT) JavaScript into Luau that runs on JSRT (runtime.luau).
// Conventions: every non-arrow function takes `this` as its first parameter; every call passes one.
// Arrays are 0-based tables whose length lives in the runtime (JS.len); objects are plain tables.
const acorn = require('acorn');

const LUA_KW = new Set(['and','break','do','else','elseif','end','false','for','function','if','in','local','nil','not','or','repeat','return','then','true','until','while','continue','goto','self']);
const STATIC = new Set(['Math','Decimal','Object','JSON','Number','Array','String','Date','console','localStorage','document','window','Vue','navigator']);
// names that dispatch through JS.m (array / string / function / number builtins)
const BUILTIN = new Set(['push','pop','shift','unshift','includes','indexOf','lastIndexOf','join','slice','splice','sort','reduce','map','filter','forEach','find','findIndex','some','every','concat','replace','split','toFixed','toPrecision','toString','charAt','charCodeAt','toUpperCase','toLowerCase','repeat','padStart','padEnd','trim','startsWith','endsWith','substring','substr','bind','call','apply','fill','reverse','match','test','toLocaleString','valueOf','hasOwnProperty']);
const BOOL_METHODS = new Set(['gte','gt','lte','lt','eq','neq','includes','startsWith','endsWith','some','every','test','hasOwnProperty','isArray','isNaN','isFinite']);
const BOOL_FUNCS = new Set(['hasUpgrade','hasMilestone','hasAchievement','inChallenge','isNaN','isPlainObject','isFunction','canAffordUpgrade','canBuyBuyable','hasMalware','canReset','maxedChallenge','canCompleteChallenge','layerunlocked','isEndgame','player_has']);

const RESERVED = new Set(['math','bit32','pcall','error','JS','type','select','setmetatable','getmetatable','rawget','rawset','tostring','tonumber','string','table','next','pairs','ipairs','unpack','print','coroutine','os','debug','utf8','buffer','task','game','workspace','script','require','setfenv','getfenv','loadstring','_G','_','this']);
function ident(n) {
	let s = n.replace(/\$/g, '_S_');
	if (LUA_KW.has(s) || RESERVED.has(s)) s = s + '_';
	if (s.startsWith('__')) s = 'u' + s;
	return s;
}
const isLuaName = s => /^[A-Za-z_][A-Za-z0-9_]*$/.test(s) && !LUA_KW.has(s);
function luaStr(s) {
	return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t')
		.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, c => '\\' + c.charCodeAt(0)) + '"';
}
function canonKey(s) { // JS property keys that look like canonical integers become number keys
	if (typeof s === 'number') return String(s);
	if (/^(0|-?[1-9][0-9]{0,14})$/.test(s)) return s;
	return null;
}
function numLit(v) {
	if (v === Infinity) return 'math.huge';
	if (Number.isNaN(v)) return '(0/0)';
	let s = String(v);
	if (s.includes('e+')) s = s.replace('e+', 'e');
	return s;
}

class Ctx {
	constructor(parent, isFunc, isArrow) { this.parent = parent; this.isFunc = isFunc; this.isArrow = isArrow; this.loops = []; this.tmp = 0; }
}

class Gen {
	constructor() { this.uid = 0; this.regexes = []; }
	fresh(p) { return '__' + (p || 't') + (++this.uid); }

	// ---------- type-ish inference ----------
	isBool(n) {
		if (!n) return false;
		switch (n.type) {
			case 'Literal': return typeof n.value === 'boolean';
			case 'UnaryExpression': return n.operator === '!' || n.operator === 'delete';
			case 'BinaryExpression': return ['==','===','!=','!==','<','>','<=','>=','instanceof','in'].includes(n.operator);
			case 'LogicalExpression': return this.isBool(n.left) && this.isBool(n.right);
			case 'ConditionalExpression': return this.isBool(n.consequent) && this.isBool(n.alternate);
			case 'CallExpression':
				if (n.callee.type === 'MemberExpression' && !n.callee.computed) return BOOL_METHODS.has(n.callee.property.name);
				if (n.callee.type === 'Identifier') return BOOL_FUNCS.has(n.callee.name);
				return false;
		}
		return false;
	}
	isStr(n) {
		if (!n) return false;
		if (n.type === 'Literal') return typeof n.value === 'string';
		if (n.type === 'TemplateLiteral') return true;
		if (n.type === 'BinaryExpression' && n.operator === '+') return this.isStr(n.left) || this.isStr(n.right);
		if (n.type === 'CallExpression' && n.callee.type === 'Identifier' && ['format','formatWhole','formatTime','formatSmall','exponentialFormat','commaFormat','regularFormat','String'].includes(n.callee.name)) return true;
		if (n.type === 'CallExpression' && n.callee.type === 'MemberExpression' && !n.callee.computed && ['toString','toFixed','toPrecision','join','toUpperCase','toLowerCase','replace','charAt','repeat','padStart','slice','substring','toStringWithDecimalPlaces'].includes(n.callee.property.name) && n.callee.property.name !== 'slice') return true;
		return false;
	}
	isNum(n) {
		if (!n) return false;
		if (n.type === 'Literal') return typeof n.value === 'number';
		if (n.type === 'UnaryExpression' && n.operator === '-') return this.isNum(n.argument);
		if (n.type === 'BinaryExpression' && ['-','*','/','%','**'].includes(n.operator)) return true;
		if (n.type === 'BinaryExpression' && n.operator === '+') return this.isNum(n.left) && this.isNum(n.right);
		if (n.type === 'CallExpression' && n.callee.type === 'MemberExpression' && !n.callee.computed) {
			if (n.callee.object.type === 'Identifier' && n.callee.object.name === 'Math') return true;
			if (n.callee.property.name === 'toNumber') return true;
		}
		if (n.type === 'MemberExpression' && !n.computed && n.property.name === 'length') return true;
		return false;
	}
	isSimple(n) { // safe to evaluate twice
		if (n.type === 'Identifier' || n.type === 'Literal' || n.type === 'ThisExpression') return true;
		if (n.type === 'MemberExpression') return this.isSimple(n.object) && (!n.computed || this.isSimple(n.property)) && !(n.property.name === 'length' && !n.computed);
		return false;
	}

	// ---------- expressions ----------
	truthy(n, ctx) {
		if (this.isBool(n)) return this.expr(n, ctx);
		if (n.type === 'LogicalExpression' && (n.operator === '&&' || n.operator === '||'))
			return '(' + this.truthy(n.left, ctx) + (n.operator === '&&' ? ' and ' : ' or ') + this.truthy(n.right, ctx) + ')';
		if (n.type === 'UnaryExpression' && n.operator === '!') return '(not ' + this.truthy(n.argument, ctx) + ')';
		return 'JS.t(' + this.expr(n, ctx) + ')';
	}

	key(prop, computed, ctx) { // returns lua index expression inside [...]
		if (!computed) {
			const c = canonKey(prop.name);
			return c !== null ? c : luaStr(prop.name);
		}
		if (prop.type === 'Literal') {
			if (typeof prop.value === 'number') return numLit(prop.value);
			const c = canonKey(prop.value);
			return c !== null ? c : luaStr(prop.value);
		}
		if (prop.type === 'Identifier' && this.isCanon(prop.name, ctx)) return this.expr(prop, ctx);
		return 'JS.k(' + this.expr(prop, ctx) + ')';
	}
	isCanon(name, ctx) {
		for (let c = ctx; c; c = c.parent) {
			if (c.canon && c.canon.has(name)) return true;
			if (c.isFunc) return false;   // for-in keys only count in the function that owns the loop
		}
		return false;
	}
	member(n, ctx) {
		const obj = this.expr(n.object, ctx);
		const o = this.wrapObj(n.object, obj);
		if (!n.computed) {
			const name = n.property.name;
			if (name === 'length') return 'JS.len(' + obj + ')';
			if (name === 'constructor' || name === 'call' || name === 'apply' || name === 'bind') return 'JS.get(' + obj + ', ' + luaStr(name) + ')';
			// break_eternity fields: only Decimal reads need them computed
			if (name === 'mag' || name === 'sign' || name === 'mantissa' || (name === 'layer' && n.object.type === 'Identifier' && (n.object.name === 'decimal' || n.object.name === 'num')))
				return 'JS.P(' + obj + ', ' + luaStr(name) + ')';
			if (canonKey(name) === null && isLuaName(name)) return o + '.' + name;
			return o + '[' + this.key(n.property, false, ctx) + ']';
		}
		return o + '[' + this.key(n.property, true, ctx) + ']';
	}
	wrapObj(node, s) {
		if (node.type === 'Identifier' || node.type === 'MemberExpression' || node.type === 'ThisExpression' || (node.type === 'CallExpression')) return s;
		return '(' + s + ')';
	}

	expr(n, ctx) {
		switch (n.type) {
			case 'Literal':
				if (n.regex) { const id = this.regexes.length; this.regexes.push(n.regex); return 'JS.re(' + luaStr(n.regex.pattern) + ',' + luaStr(n.regex.flags) + ')'; }
				if (n.value === null) return 'JS.NULL';
				if (typeof n.value === 'string') return luaStr(n.value);
				if (typeof n.value === 'number') return numLit(n.value);
				return String(n.value);
			case 'Identifier':
				if (n.name === 'undefined') return 'nil';
				if (n.name === 'NaN') return '(0/0)';
				if (n.name === 'Infinity') return 'math.huge';
				return ident(n.name);
			case 'ThisExpression': return 'this';
			case 'TemplateLiteral': {
				const parts = [];
				n.quasis.forEach((q, i) => {
					if (q.value.cooked) parts.push(luaStr(q.value.cooked));
					if (i < n.expressions.length) parts.push(this.strPart(n.expressions[i], ctx));
				});
				if (!parts.length) return '""';
				return '(' + parts.join(' .. ') + ')';
			}
			case 'ArrayExpression':
				if (!n.elements.length) return 'JS.A(0)';
				return 'JS.A(' + n.elements.length + ', ' + n.elements.map(e => e ? this.expr(e, ctx) : 'nil').join(', ') + ')';
			case 'ObjectExpression': {
				if (!n.properties.length) return 'JS.O({})';
				const fields = [], order = [];
				for (const p of n.properties) {
					let k;
					if (p.computed) k = '[' + this.key(p.key, true, ctx) + ']';
					else {
						const raw = p.key.type === 'Identifier' ? p.key.name : p.key.value;
						const c = canonKey(raw);
						if (c !== null) k = '[' + c + ']';
						else { k = isLuaName(raw) ? raw : '[' + luaStr(raw) + ']'; order.push(luaStr(raw)); }
					}
					fields.push(k + ' = ' + this.expr(p.value, ctx));
				}
				const body = '{\n' + fields.map(f => '\t' + f).join(',\n') + '\n}';
				return order.length > 1 ? 'JS.O(' + body + ', {' + order.join(', ') + '})' : 'JS.O(' + body + ')';
			}
			case 'FunctionExpression': case 'ArrowFunctionExpression': return this.func(n, ctx);
			case '__raw': return n.s;
			case 'MemberExpression': return this.member(n, ctx);
			case 'ChainExpression': return this.chain(n.expression, ctx);
			case 'CallExpression': return this.call(n, ctx);
			case 'NewExpression': {
				const args = n.arguments.map(a => this.expr(a, ctx));
				if (n.callee.type === 'Identifier' && n.callee.name === 'Decimal') return 'JS.D(' + (args[0] || 'nil') + ')';
				return 'JS.new(' + this.expr(n.callee, ctx) + (args.length ? ', ' + args.join(', ') : '') + ')';
			}
			case 'UnaryExpression': {
				const a = n.argument;
				switch (n.operator) {
					case '!': return '(not ' + this.truthy(a, ctx) + ')';
					case '-': return '(-' + this.num(a, ctx) + ')';
					case '+': return 'JS.tonum(' + this.expr(a, ctx) + ')';
					case 'typeof': return 'JS.typeof(' + (a.type === 'Identifier' ? ident(a.name) : this.expr(a, ctx)) + ')';
					case 'void': return 'nil';
					case 'delete': return '(function() ' + this.assignTo(a, 'nil', ctx) + ' return true end)()';
				}
				throw new Error('unary ' + n.operator);
			}
			case 'BinaryExpression': return this.binary(n, ctx);
			case 'LogicalExpression': {
				const { left: l, right: r } = n;
				if (n.operator === '??') return 'JS.nc(' + this.expr(l, ctx) + ', function() return ' + this.expr(r, ctx) + ' end)';
				if (this.isBool(l) && this.isBool(r)) return '(' + this.expr(l, ctx) + (n.operator === '&&' ? ' and ' : ' or ') + this.expr(r, ctx) + ')';
				if (this.isSimple(l)) {
					const L = this.expr(l, ctx);
					const T = this.isBool(l) ? L : 'JS.t(' + L + ')';
					return n.operator === '&&' ? '(if ' + T + ' then ' + this.expr(r, ctx) + ' else ' + L + ')'
						: '(if ' + T + ' then ' + L + ' else ' + this.expr(r, ctx) + ')';
				}
				return (n.operator === '&&' ? 'JS.and_(' : 'JS.or_(') + this.expr(l, ctx) + ', function() return ' + this.expr(r, ctx) + ' end)';
			}
			case 'ConditionalExpression':
				return '(if ' + this.truthy(n.test, ctx) + ' then ' + this.expr(n.consequent, ctx) + ' else ' + this.expr(n.alternate, ctx) + ')';
			case 'AssignmentExpression': case 'UpdateExpression': {
				// used as a value: run it in a closure and return the new (or old, for postfix) value
				const t = this.fresh('v');
				if (n.type === 'UpdateExpression') {
					const cur = this.expr(n.argument, ctx);
					const op = n.operator === '++' ? '+' : '-';
					return '(function() local ' + t + ' = ' + cur + '; ' + this.assignTo(n.argument, '(' + t + ' ' + op + ' 1)', ctx) + ' return ' + (n.prefix ? '(' + t + ' ' + op + ' 1)' : t) + ' end)()';
				}
				return '(function() local ' + t + ' = ' + this.assignValue(n, ctx) + '; ' + this.assignTo(n.left, t, ctx) + ' return ' + t + ' end)()';
			}
			case 'SequenceExpression':
				return '(function() ' + n.expressions.slice(0, -1).map(e => this.exprStmt(e, ctx)).join(' ') + ' return ' + this.expr(n.expressions[n.expressions.length - 1], ctx) + ' end)()';
		}
		throw new Error('expr ' + n.type + ' at ' + (n.loc && n.loc.start.line));
	}
	strPart(n, ctx) {
		if (n.type === 'Literal' && typeof n.value === 'string') return luaStr(n.value);
		if (n.type === 'TemplateLiteral') return this.expr(n, ctx);
		if (n.type === 'BinaryExpression' && n.operator === '+' && this.isStr(n)) return this.expr(n, ctx);
		return 'JS.str(' + this.expr(n, ctx) + ')';
	}
	num(n, ctx) { const s = this.expr(n, ctx); return this.isNum(n) ? s : 'JS.tonum(' + s + ')'; }
	chain(n, ctx) {
		// a?.b / a?.b() : evaluate object once
		if (n.type === 'MemberExpression' && n.optional) {
			const t = this.fresh('c');
			const inner = Object.assign({}, n, { object: { type: '__raw', s: t }, optional: false });
			return '(function() local ' + t + ' = ' + this.chain(n.object, ctx) + '; if JS.isnil(' + t + ') then return nil end; return ' + this.expr(inner, ctx) + ' end)()';
		}
		if (n.type === 'CallExpression' && n.optional) {
			const t = this.fresh('c');
			return '(function() local ' + t + ' = ' + this.chain(n.callee, ctx) + '; if JS.isnil(' + t + ') then return nil end; return ' + t + '(nil' + n.arguments.map(a => ', ' + this.expr(a, ctx)).join('') + ') end)()';
		}
		if (n.type === 'MemberExpression') return this.member(Object.assign({}, n, { object: { type: '__raw', s: this.chain(n.object, ctx) } }), ctx);
		return this.expr(n, ctx);
	}
	binary(n, ctx) {
		const op = n.operator, l = n.left, r = n.right;
		const L = () => this.expr(l, ctx), R = () => this.expr(r, ctx);
		switch (op) {
			case '+':
				if (this.isNum(l) && this.isNum(r)) return '(' + L() + ' + ' + R() + ')';
				if (this.isStr(l) || this.isStr(r)) return '(' + this.strPart(l, ctx) + ' .. ' + this.strPart(r, ctx) + ')';
				return 'JS.add(' + L() + ', ' + R() + ')';
			case '-': case '*': case '/': return '(' + this.num(l, ctx) + ' ' + op + ' ' + this.num(r, ctx) + ')';
			case '%': return 'math.fmod(' + this.num(l, ctx) + ', ' + this.num(r, ctx) + ')';
			case '**': return '(' + this.num(l, ctx) + ' ^ ' + this.num(r, ctx) + ')';
			case '===': return this.eq(l, r, ctx, false, true);
			case '==': return this.eq(l, r, ctx, false, false);
			case '!==': return this.eq(l, r, ctx, true, true);
			case '!=': return this.eq(l, r, ctx, true, false);
			case '<': case '>': case '<=': case '>=':
				if (this.isNum(l) || this.isNum(r)) return '(' + this.num(l, ctx) + ' ' + op + ' ' + this.num(r, ctx) + ')';
				return 'JS.cmp(' + L() + ', ' + luaStr(op) + ', ' + R() + ')';
			case 'instanceof': return 'JS.instanceof(' + L() + ', ' + R() + ')';
			case 'in': return 'JS.has(' + R() + ', ' + L() + ')';
			case '&': return 'bit32.band(' + L() + ', ' + R() + ')';
			case '|': return 'bit32.bor(' + L() + ', ' + R() + ')';
		}
		throw new Error('binary ' + op);
	}
	eq(l, r, ctx, neg, strict) {
		const isNull = x => x.type === 'Literal' && x.value === null && !x.regex;
		const isUndef = x => x.type === 'Identifier' && x.name === 'undefined';
		let s;
		const nl = isNull(l) || isUndef(l), nr = isNull(r) || isUndef(r);
		if (nl || nr) {
			const lit = nl ? l : r, other = nl ? r : l;
			const o = this.expr(other, ctx);
			if (!strict) s = 'JS.isnil(' + o + ')';                       // x == null / x == undefined
			else if (isNull(lit)) s = '(' + o + ' == JS.NULL)';          // x === null
			else s = '(' + o + ' == nil)';                               // x === undefined
		}
		// a literal on one side makes == exact in Lua only for === / !==, or loose == against a non-numeric string
		// ("101" != 101 is false in JS, so loose comparisons with numbers keep JS.eq)
		else if ([l, r].some(x => x.type === 'Literal' && !x.regex && typeof x.value !== 'object' &&
			(strict || (typeof x.value === 'string' && x.value.trim() !== '' && isNaN(Number(x.value)))))) s = '(' + this.expr(l, ctx) + ' == ' + this.expr(r, ctx) + ')';
		else s = 'JS.eq(' + this.expr(l, ctx) + ', ' + this.expr(r, ctx) + ')';
		return neg ? '(not ' + s + ')' : s;
	}
	call(n, ctx) {
		const args = n.arguments.map(a => this.expr(a, ctx));
		const A = args.length ? ', ' + args.join(', ') : '';
		const c = n.callee;
		if (c.type === 'MemberExpression') {
			if (c.object.type === 'Identifier' && STATIC.has(c.object.name) && !c.computed)
				return ident(c.object.name) + '.' + c.property.name + '(' + args.join(', ') + ')';
			const obj = this.expr(c.object, ctx);
			if (!c.computed) {
				const name = c.property.name;
				if (BUILTIN.has(name)) return 'JS.m(' + obj + ', ' + luaStr(name) + A + ')';
				if (isLuaName(name)) return this.wrapObj(c.object, obj) + ':' + name + '(' + args.join(', ') + ')';
				return 'JS.mc(' + obj + ', ' + luaStr(name) + A + ')';
			}
			return 'JS.mc(' + obj + ', ' + this.key(c.property, true, ctx) + A + ')';
		}
		if (c.type === 'Identifier' && c.name === 'Decimal') return 'JS.D(' + (args[0] || 'nil') + ')';
		const f = this.expr(c, ctx);
		return (c.type === 'Identifier' ? f : '(' + f + ')') + '(nil' + A + ')';
	}

	// ---------- assignment ----------
	assignValue(n, ctx) {
		if (n.operator === '=') return this.expr(n.right, ctx);
		const cur = this.expr(n.left, ctx);
		const bop = n.operator.slice(0, -1);
		const fake = { type: 'BinaryExpression', operator: bop, left: n.left, right: n.right };
		if (bop === '||' || bop === '&&') return this.expr({ type: 'LogicalExpression', operator: bop, left: n.left, right: n.right }, ctx);
		return this.binary(fake, ctx);
	}
	assignTo(target, val, ctx) {
		if (target.type === 'Identifier') return ident(target.name) + ' = ' + val;
		if (target.type === 'MemberExpression') {
			if (!target.computed) {
				const name = target.property.name;
				if (name === 'length') return 'JS.setlen(' + this.expr(target.object, ctx) + ', ' + val + ')';
				const o = this.wrapObj(target.object, this.expr(target.object, ctx));
				if (canonKey(name) === null && isLuaName(name)) return 'JS.setk(' + o + ', ' + luaStr(name) + ', ' + val + ')';
				return 'JS.set(' + o + ', ' + this.key(target.property, false, ctx) + ', ' + val + ')';
			}
			return 'JS.set(' + this.expr(target.object, ctx) + ', ' + this.key(target.property, true, ctx) + ', ' + val + ')';
		}
		throw new Error('assign target ' + target.type);
	}
	exprStmt(e, ctx) {
		if (e.type === 'AssignmentExpression') return this.assignTo(e.left, this.assignValue(e, ctx), ctx);
		if (e.type === 'UpdateExpression') {
			const op = e.operator === '++' ? '+' : '-';
			return this.assignTo(e.argument, '(' + this.num(e.argument, ctx) + ' ' + op + ' 1)', ctx);
		}
		if (e.type === 'CallExpression' || e.type === 'NewExpression') return this.expr(e, ctx);
		if (e.type === 'SequenceExpression') return e.expressions.map(x => this.exprStmt(x, ctx)).join('\n');
		if (e.type === 'ChainExpression') return 'local _ = ' + this.expr(e, ctx);
		if (e.type === 'Literal') return ''; // "use strict"
		return 'local _ = ' + this.expr(e, ctx);
	}

	// ---------- functions & statements ----------
	collectHoist(body) { // var names + nested function declarations (not crossing function boundaries)
		const vars = new Set(), funcs = [];
		const visit = (n) => {
			if (!n || typeof n.type !== 'string') return;
			if (n.type === 'FunctionExpression' || n.type === 'ArrowFunctionExpression') return;
			if (n.type === 'FunctionDeclaration') { funcs.push(n); return; }
			if (n.type === 'VariableDeclaration' && n.kind === 'var') n.declarations.forEach(d => vars.add(d.id.name));
			for (const k in n) {
				if (k === 'loc' || k === 'start' || k === 'end') continue;
				const v = n[k];
				if (Array.isArray(v)) v.forEach(visit); else if (v && typeof v.type === 'string') visit(v);
			}
		};
		body.forEach(visit);
		return { vars: [...vars], funcs };
	}
	func(n, ctx) {
		const arrow = n.type === 'ArrowFunctionExpression';
		const fctx = new Ctx(ctx, true, arrow);
		const params = n.params.map(p => p.type === 'AssignmentPattern' ? ident(p.left.name) : ident(p.name));
		let out = 'function(' + [arrow ? '_' : 'this'].concat(params).join(', ') + ')\n';
		const pre = [];
		n.params.forEach(p => { if (p.type === 'AssignmentPattern') pre.push('if ' + ident(p.left.name) + ' == nil then ' + ident(p.left.name) + ' = ' + this.expr(p.right, fctx) + ' end'); });
		let bodyStmts;
		if (n.body.type === 'BlockStatement') bodyStmts = n.body.body;
		else bodyStmts = [{ type: 'ReturnStatement', argument: n.body }];
		fctx.declared = new Set(params);
		out += this.indent(pre.concat(this.hoisted(bodyStmts, fctx)).concat(this.stmts(bodyStmts, fctx)).join('\n'));
		return out + '\nend';
	}
	hoisted(body, ctx) {
		const { vars, funcs } = this.collectHoist(body);
		const lines = [];
		const names = vars.map(ident).filter(v => !ctx.declared.has(v));
		funcs.forEach(f => { const nm = ident(f.id.name); if (!names.includes(nm)) names.push(nm); });
		names.forEach(v => ctx.declared.add(v));
		ctx.hoistedVars = new Set(names);
		// Luau caps locals at 200 per function: past that, use a table
		if (names.length) lines.push('local ' + names.join(', '));
		funcs.forEach(f => lines.push(ident(f.id.name) + ' = ' + this.func(f, ctx)));
		return lines;
	}
	indent(s) { return s.split('\n').map(l => l.length ? '\t' + l : l).join('\n'); }
	stmts(list, ctx) { return list.map(s => this.stmt(s, ctx)).filter(s => s !== ''); }
	block(n, ctx) { return this.stmts(n.type === 'BlockStatement' ? n.body : [n], ctx).join('\n'); }

	stmt(n, ctx) {
		switch (n.type) {
			case 'EmptyStatement': return '';
			case 'ExpressionStatement': return this.exprStmt(n.expression, ctx);
			case 'VariableDeclaration': {
				const out = [];
				for (const d of n.declarations) {
					const name = ident(d.id.name);
					const val = d.init ? this.expr(d.init, ctx) : 'nil';
					if (!ctx.isFunc) { if (d.init || n.kind !== 'var') out.push(name + ' = ' + val); } // top level: globals
					else if (n.kind === 'var' && ctx.hoistedVars && ctx.hoistedVars.has(name)) { if (d.init) out.push(name + ' = ' + val); }
					else out.push('local ' + name + ' = ' + val);
				}
				return out.join('\n');
			}
			case 'FunctionDeclaration':
				if (!ctx.isFunc) return ''; // hoisted at file level
				return ''; // hoisted in function
			case 'ReturnStatement':
				return 'do return' + (n.argument ? ' ' + this.expr(n.argument, ctx) : '') + ' end';
			case 'IfStatement': {
				let s = 'if ' + this.truthy(n.test, ctx) + ' then\n' + this.indent(this.block(n.consequent, ctx));
				let alt = n.alternate;
				while (alt && alt.type === 'IfStatement') {
					s += '\nelseif ' + this.truthy(alt.test, ctx) + ' then\n' + this.indent(this.block(alt.consequent, ctx));
					alt = alt.alternate;
				}
				if (alt) s += '\nelse\n' + this.indent(this.block(alt, ctx));
				return s + '\nend';
			}
			case 'BlockStatement': return 'do\n' + this.indent(this.block(n, ctx)) + '\nend';
			case 'ForStatement': return this.forStmt(n, ctx);
			case 'ForInStatement': case 'ForOfStatement': {
				let v, pre = '';
				const t = this.fresh('k');
				if (n.left.type === 'VariableDeclaration') {
					v = ident(n.left.declarations[0].id.name);
					if (n.left.kind === 'var' && ctx.hoistedVars && ctx.hoistedVars.has(v)) pre = v + ' = ' + t + '\n';
					else pre = 'local ' + v + ' = ' + t + '\n';
				} else pre = this.assignTo(n.left, t, ctx) + '\n';
				ctx.loops.push({ kind: 'forin' });
				const keyName = n.left.type === 'VariableDeclaration' ? n.left.declarations[0].id.name : (n.left.type === 'Identifier' ? n.left.name : null);
				const canonOk = n.type === 'ForInStatement' && keyName && !this.assignsTo(n.body, keyName) && !this.hasNestedForIn(n.body, keyName);
				const prevCanon = ctx.canon;
				if (canonOk) { ctx.canon = new Set(prevCanon || []); ctx.canon.add(keyName); }
				const body = this.block(n.body, ctx);
				ctx.canon = prevCanon;
				ctx.loops.pop();
				return 'for _, ' + t + ' in ' + (n.type === 'ForInStatement' ? 'JS.keys(' : 'JS.vals(') + this.expr(n.right, ctx) + ') do\n' + this.indent(pre + body) + '\nend';
			}
			case 'WhileStatement': {
				ctx.loops.push({ kind: 'while' });
				const body = this.block(n.body, ctx);
				ctx.loops.pop();
				const g = this.fresh('g');
				return 'local ' + g + ' = 0\nwhile ' + this.truthy(n.test, ctx) + ' do\n' + this.indent(this.guard(g) + body) + '\nend';
			}
			case 'DoWhileStatement': {
				ctx.loops.push({ kind: 'while' });
				const body = this.block(n.body, ctx);
				ctx.loops.pop();
				const g = this.fresh('g');
				return 'local ' + g + ' = 0\nrepeat\n' + this.indent(this.guard(g) + body) + '\nuntil not ' + this.truthy(n.test, ctx);
			}
			case 'BreakStatement': {
				const L = ctx.loops[ctx.loops.length - 1];
				if (L && L.kind === 'switch') return 'break';
				return 'break';
			}
			case 'ContinueStatement': {
				// innermost real loop; switches in between are repeat..until true blocks
				let i = ctx.loops.length - 1, crossedSwitch = false;
				while (i >= 0 && ctx.loops[i].kind === 'switch') { crossedSwitch = true; i--; }
				const L = ctx.loops[i];
				if (crossedSwitch) throw new Error('continue inside switch');
				return (L && L.update ? L.update + '\n' : '') + 'continue';
			}
			case 'SwitchStatement': {
				const d = this.fresh('sw'), f = this.fresh('ft');
				let s = 'local ' + d + ' = ' + this.expr(n.discriminant, ctx) + '\nlocal ' + f + ' = false\nrepeat\n';
				ctx.loops.push({ kind: 'switch' });
				const cases = n.cases.filter(c => c.test).concat(n.cases.filter(c => !c.test));
				for (const c of cases) {
					const cond = c.test ? f + ' or JS.eq(' + d + ', ' + this.expr(c.test, ctx) + ')' : 'true';
					s += this.indent('if ' + cond + ' then\n' + this.indent(f + ' = true\n' + this.stmts(c.consequent, ctx).join('\n')) + '\nend') + '\n';
				}
				ctx.loops.pop();
				return 'do\n' + this.indent(s + 'until true') + '\nend';
			}
			case 'TryStatement': {
				const ok = this.fresh('ok'), err = this.fresh('e');
				let s = 'local ' + ok + ', ' + err + ' = pcall(function()\n' + this.indent(this.block(n.block, ctx)) + '\nend)';
				if (n.handler) s += '\nif not ' + ok + ' then\n' + this.indent((n.handler.param ? 'local ' + ident(n.handler.param.name) + ' = ' + err + '\n' : '') + this.block(n.handler.body, ctx)) + '\nend';
				if (n.finalizer) s += '\n' + this.block(n.finalizer, ctx);
				return 'do\n' + this.indent(s) + '\nend';
			}
			case 'ThrowStatement': return 'error(' + this.expr(n.argument, ctx) + ')';
		}
		throw new Error('stmt ' + n.type + ' at ' + (n.loc && n.loc.start.line));
	}
	assignsTo(node, name) {
		let hit = false;
		const visit = (n) => {
			if (hit || !n || typeof n.type !== 'string') return;
			if ((n.type === 'AssignmentExpression' && n.left.type === 'Identifier' && n.left.name === name) ||
				(n.type === 'UpdateExpression' && n.argument.type === 'Identifier' && n.argument.name === name)) { hit = true; return; }
			for (const k in n) { if (k === 'loc') continue; const v = n[k]; if (Array.isArray(v)) v.forEach(visit); else if (v && typeof v.type === 'string') visit(v); }
		};
		visit(node);
		return hit;
	}
	hasNestedForIn(node, name) { // a call in the body may re-run a for-in on the same implicit global; only trust local loop vars then
		let hit = false;
		const visit = (n) => {
			if (hit || !n || typeof n.type !== 'string') return;
			if ((n.type === 'ForInStatement' || n.type === 'ForOfStatement') && n.left.type === 'Identifier' && n.left.name === name) { hit = true; return; }
			for (const k in n) { if (k === 'loc') continue; const v = n[k]; if (Array.isArray(v)) v.forEach(visit); else if (v && typeof v.type === 'string') visit(v); }
		};
		visit(node);
		return hit;
	}
	// every while / do-while / generic for counts its turns: a loop that never ends in the web game (it happens in
	// some broken states) errors out after 5 million turns instead of freezing the server
	guard(g) { return g + ' += 1; if ' + g + ' > 5000000 then JS.runaway() end\n'; }
	forStmt(n, ctx) {
		// numeric fast path: for (let i = a; i < b; i++ / i-- / i += c)
		let v = null, start = null;
		if (n.init && n.init.type === 'VariableDeclaration' && n.init.declarations.length === 1 && n.init.declarations[0].init) { v = n.init.declarations[0].id.name; start = n.init.declarations[0].init; }
		else if (n.init && n.init.type === 'AssignmentExpression' && n.init.operator === '=' && n.init.left.type === 'Identifier') { v = n.init.left.name; start = n.init.right; }
		let step = null;
		const u = n.update;
		if (v && u) {
			if (u.type === 'UpdateExpression' && u.argument.type === 'Identifier' && u.argument.name === v) step = u.operator === '++' ? 1 : -1;
			else if (u.type === 'AssignmentExpression' && u.left.type === 'Identifier' && u.left.name === v && (u.operator === '+=' || u.operator === '-=') && u.right.type === 'Literal' && typeof u.right.value === 'number') step = u.operator === '+=' ? u.right.value : -u.right.value;
		}
		const t = n.test;
		if (step !== null && t && t.type === 'BinaryExpression' && t.left.type === 'Identifier' && t.left.name === v && ['<','<=','>','>='].includes(t.operator) && !this.assignsTo(n.body, v)) {
			const up = step > 0;
			if ((up && (t.operator === '<' || t.operator === '<=')) || (!up && (t.operator === '>' || t.operator === '>='))) {
				let lim = this.num(t.right, ctx);
				if (t.operator === '<') lim = (Number.isInteger(step) && Math.abs(step) === 1) ? '(' + lim + ') - 1' : lim + ' - 1e-9';
				if (t.operator === '>') lim = '(' + lim + ') + 1';
				const nm = ident(v);
				ctx.loops.push({ kind: 'for' });
				const body = this.block(n.body, ctx);
				ctx.loops.pop();
				// a var declared loop counter also lives on after the loop in JS
				const after = (ctx.hoistedVars && ctx.hoistedVars.has(nm)) || !ctx.isFunc ? '' : '';
				// a runaway bound (a huge number from the game's state) errors instead of freezing the server
				const st0 = this.num(start, ctx);
				const capped = start.type === 'Literal' && t.right.type === 'Literal' ? lim : 'JS.cap(' + st0 + ', ' + lim + ', ' + step + ')';
				return 'for ' + nm + ' = ' + st0 + ', ' + capped + (step !== 1 ? ', ' + step : '') + ' do\n' + this.indent(body) + '\nend' + after;
			}
		}
		// generic
		let s = 'do\n';
		let inner = '';
		if (n.init) inner += (n.init.type === 'VariableDeclaration' ? this.stmt(n.init, ctx) : this.exprStmt(n.init, ctx)) + '\n';
		const update = n.update ? this.exprStmt(n.update, ctx) : '';
		ctx.loops.push({ kind: 'for', update });
		const body = this.block(n.body, ctx);
		ctx.loops.pop();
		const g = this.fresh('g');
		inner += 'local ' + g + ' = 0\n';
		inner += 'while ' + (n.test ? this.truthy(n.test, ctx) : 'true') + ' do\n' + this.indent(this.guard(g) + body + (update ? '\n' + update : '')) + '\nend';
		return s + this.indent(inner) + '\nend';
	}

	program(src, name) {
		const ast = acorn.parse(src, { ecmaVersion: 2022, sourceType: 'script', locations: true });
		const ctx = new Ctx(null, false, false);
		ctx.declared = new Set();
		const out = ['-- transpiled from ' + name];
		// hoist top-level function declarations (JS hoisting within the file)
		for (const s of ast.body) if (s.type === 'FunctionDeclaration') out.push(ident(s.id.name) + ' = ' + this.func(s, ctx));
		for (const s of ast.body) {
			try { const r = this.stmt(s, ctx); if (r) out.push(r); }
			catch (e) { e.message = name + ':' + (s.loc && s.loc.start.line) + ' ' + e.message; throw e; }
		}
		return out.join('\n') + '\n';
	}
}

module.exports = { transpile: (src, name) => new Gen().program(src, name) };

if (require.main === module) {
	const fs = require('fs');
	const [inp, outp] = process.argv.slice(2);
	fs.writeFileSync(outp, module.exports.transpile(fs.readFileSync(inp, 'utf8'), inp));
}
