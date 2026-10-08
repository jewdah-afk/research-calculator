// node playtest/tools/deps.js <bundleDir> game-XXXX.js name1,m:method,... [depth]  -> declarations + transitive deps across Birb bundles (follows imports). SKIP=a,b skips noisy helpers. Needs the .pretty.js files from fetch_birb.sh
const fs = require("fs"), path = require("path"), acorn = require("acorn"), walk = require("acorn-walk");
const [dir, entry, names, depthArg] = process.argv.slice(2);
const files = {};
function load(f) {
  if (files[f]) return files[f];
  const src = fs.readFileSync(path.join(dir, f.replace(/\.js$/, ".pretty.js")), "utf8");
  const ast = acorn.parse(src, { ecmaVersion: "latest", sourceType: "module" });
  const decl = new Map(), imports = new Map(), exports = new Map(), methods = new Map();
  for (const n of ast.body) {
    if (n.type === "ImportDeclaration") for (const sp of n.specifiers) imports.set(sp.local.name, { file: path.basename(n.source.value), name: sp.imported ? sp.imported.name : "default" });
    if (n.type === "ExportNamedDeclaration" && !n.declaration) for (const sp of n.specifiers) exports.set(sp.exported.name, sp.local.name);
    const node = n.type === "ExportNamedDeclaration" && n.declaration ? n.declaration : n;
    if (node.type === "FunctionDeclaration" || node.type === "ClassDeclaration") decl.set(node.id.name, node);
    else if (node.type === "VariableDeclaration") for (const d of node.declarations) if (d.id.type === "Identifier") decl.set(d.id.name, d);
  }
  walk.simple(ast, { MethodDefinition(m) { const k = m.key && (m.key.name || m.key.value); if (k) { if (!methods.has(k)) methods.set(k, []); methods.get(k).push(m); } } });
  return (files[f] = { src, decl, imports, exports, methods, f });
}
const maxDepth = +(depthArg || 3), seen = new Set((process.env.SKIP || "").split(",").filter(Boolean).flatMap((n) => [n, entry + ":" + n])), out = [];
const line = (F, node) => F.src.slice(0, node.start).split("\n").length;
function resolve(F, name) {
  if (F.decl.has(name)) return [F, name];
  const im = F.imports.get(name); if (!im) return null;
  const T = load(im.file), local = T.exports.get(im.name) || im.name; return T.decl.has(local) ? [T, local] : null;
}
function visit(F, name, node, d) {
  if (d > 0 && (node.type === "ClassDeclaration" || (node.init && node.init.type === "ClassExpression"))) { out.push("// ===== " + F.f + ":" + name + " (class) skipped"); return; }
  if (d > 0 && (node.type === "ClassDeclaration" || (node.init && node.init.type === "ClassExpression"))) { out.push(); return; }
  const txt = F.src.slice(node.start, node.end);
  out.push(`// ===== ${F.f}:${name} (line ${line(F, node)})\n` + (txt.length > 12000 ? txt.slice(0, 12000) + "\n/* ...cut */" : txt));
  if (d >= maxDepth) return;
  const ids = new Set(), locals = new Set();
  const addPat = (p) => { if (!p) return; if (p.type === "Identifier") locals.add(p.name); else if (p.type === "AssignmentPattern") addPat(p.left); else if (p.type === "RestElement") addPat(p.argument); else if (p.type === "ArrayPattern") p.elements.forEach(addPat); else if (p.type === "ObjectPattern") p.properties.forEach((q) => addPat(q.value || q.argument)); };
  walk.full(node, (x) => { if (x.params) x.params.forEach(addPat); if (x.type === "VariableDeclarator") addPat(x.id); if (x.type === "CatchClause") addPat(x.param); if ((x.type === "FunctionExpression") && x.id) locals.add(x.id.name); });
  walk.full(node, (x) => { if (x.type === "Identifier" && !locals.has(x.name)) ids.add(x.name); });
  // property keys (non computed) are not references
  walk.full(node, (x) => { if ((x.type === "Property" && !x.computed && x.key.type === "Identifier" && x.value !== x.key) ) ids.delete(x.key.name); if (x.type === "MemberExpression" && !x.computed) ids.delete(x.property.name); });
  for (const r of ids) { if (seen.has(r)) continue; const R = resolve(F, r); if (!R) continue; const key = R[0].f + ":" + R[1]; if (seen.has(key)) continue; seen.add(key); visit(R[0], R[1], R[0].decl.get(R[1]), d + 1); }
  walk.full(node, (x) => { if (x.type === "MemberExpression" && x.object.type === "ThisExpression" && x.property.name) { const k = "m:" + x.property.name; if (seen.has(k)) return; const ms = F.methods.get(x.property.name); if (!ms) return; seen.add(k); for (const m of ms) if (m.end - m.start < 8000) visit(F, "this." + x.property.name, m, d + 1); } });
}
const E = load(entry);
for (const n of names.split(",")) {
  if (n.startsWith("m:")) { const k = n.slice(2); seen.add("m:" + k); for (const m of E.methods.get(k) || []) visit(E, "method " + k, m, 0); }
  else { const R = resolve(E, n); if (R) { seen.add(R[0].f + ":" + R[1]); visit(R[0], R[1], R[0].decl.get(R[1]), 0); } else out.push("// ??? " + n); }
}
console.log(out.join("\n\n"));
