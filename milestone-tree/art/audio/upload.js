#!/usr/bin/env node
/* audio/upload.js: upload the audio sprite sheets (art/audio/sheets/*.ogg, built by pack.py) to Roblox as Audio assets
 * (Open Cloud Assets API), follow their moderation, and generate src/shared/AudioIds.luau.
 *
 *   node art/audio/upload.js --dry-run         no network: list what would upload, write AudioIds.luau from the record
 *   ROBLOX_CREATOR=user:123 node art/audio/upload.js    upload what is not uploaded yet, wait for moderation, write
 *   options: --creator user:<id>|group:<id>  --wait 900 (seconds to follow moderation; 0 = do not wait)
 *            --force (upload again even if the sha256 is recorded)  --luau <path>  --no-luau  --record <path>
 *            --adopt <sheet>=<assetId>   record a sheet found in the Creator Dashboard (see roblox/upload.js)
 *
 * Reuses roblox/upload.js for everything on the wire: one rate limiter, retries with backoff that honour
 * Retry-After, and the rule that a create (POST) is retried only when Roblox cannot have processed it (anything else
 * is "unconfirmed" and recorded, never blindly re-sent). Audio cannot be updated in place: a changed sheet is a new
 * file (a new sha256) and a new asset; the record (art/audio/uploaded.json, sha256 -> asset) keeps every one.
 *
 * Moderation. The create operation returns the asset id at once, usually with moderationState "Reviewing". The
 * script then polls GET assets/v1/assets/<id> every 20 s (up to --wait) and records the state. AudioIds.luau gets
 * `id` only for an Approved sheet: a sheet in review or rejected keeps id = nil (the game stays silent on it). A
 * sheet in review also gets `review` = its id, which the client tries only in Studio, where the owner can hear an
 * asset that is still in the queue. Re-run the script later (no upload happens) to pick up an approval.
 *
 * Auth: the API key header is added by the network proxy for apis.roblox.com; ROBLOX_API_KEY is sent only if set.
 */
'use strict';
const fs = require('fs'), path = require('path');
const R = require('../roblox/upload.js');

const HERE = __dirname, ART = path.resolve(HERE, '..'), REPO = path.resolve(ART, '..');
const MAP = path.join(HERE, 'sheets', 'map.json');
let RECORD = path.join(HERE, 'uploaded.json');
const FINAL = new Set(['Approved', 'Rejected']);

function parse(argv) {
  const o = { dry: false, creator: process.env.ROBLOX_CREATOR || null, wait: 900, force: false, adopt: [],
    luau: path.join(REPO, 'src/shared/AudioIds.luau'), writeLuau: true, pollMax: 120, rpm: 40 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    if (a === '--dry-run' || a === '-n') o.dry = true;
    else if (a === '--creator') o.creator = v();
    else if (a === '--wait') o.wait = Math.max(0, +v());
    else if (a === '--force') o.force = true;
    else if (a === '--adopt') o.adopt.push(v());
    else if (a === '--luau') o.luau = path.resolve(v());
    else if (a === '--no-luau') o.writeLuau = false;
    else if (a === '--record') RECORD = path.resolve(v());
    else if (a === '-h' || a === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); process.exit(0); }
    else throw new Error('unknown argument ' + a);
  }
  return o;
}

function loadRecord() {
  const r = fs.existsSync(RECORD) ? JSON.parse(fs.readFileSync(RECORD, 'utf8')) : {};
  return { assets: r.assets || {}, unconfirmed: r.unconfirmed || {} };
}
function saveRecord(rec) {
  const sorted = o => { const out = {}; for (const k of Object.keys(o).sort()) out[k] = o[k]; return out; };
  const body = { about: 'Roblox asset ids of the uploaded audio sheets, keyed by the file sha256 (written by art/audio/upload.js). ' +
    'Keep it in git: re-runs skip what is uploaded and follow moderation. `unconfirmed`: creates whose outcome is unknown.',
    assets: sorted(rec.assets) };
  if (Object.keys(rec.unconfirmed).length) body.unconfirmed = sorted(rec.unconfirmed);
  fs.writeFileSync(RECORD, JSON.stringify(body, null, 1) + '\n');
}
const displayNameOf = (key, map) => `Milestone Tree audio ${key} ${map.version}`.slice(0, 50);

async function uploadOne(gate, key, sheet, map, o) {
  const buf = fs.readFileSync(path.join(HERE, sheet.file));
  const req = { assetType: 'Audio', displayName: displayNameOf(key, map),
    description: `The Milestone Tree NG+: original ${key === 'bed' ? 'ambience bed' : 'sound-effect sprite sheet'} (${key}), ` +
      `synthesised by the game's own art/audio scripts. Sheet version ${map.version}, sha256 ${sheet.sha256.slice(0, 16)}.`,
    creationContext: { creator: R.creatorOf(o.creator) } };
  const form = new FormData();
  form.append('request', JSON.stringify(req));
  form.append('fileContent', new Blob([buf], { type: 'audio/ogg' }), path.basename(sheet.file));
  const op = await R.request(gate, `${R.API}/assets`, { method: 'POST', headers: R.headers(), body: form }, `upload ${key}`, { create: true });
  const opId = op.operationId || (op.path || '').split('/').pop() || null;
  if (!op.done && !opId) throw new R.Unconfirmed(`upload ${key}: the response names no operation: ${JSON.stringify(op).slice(0, 300)}`);
  const r = await R.pollOperation(gate, opId, o, `upload ${key}`, op);
  return { ...r, operationId: opId, displayName: req.displayName };
}

/** The asset's moderation state now ("Reviewing" | "Approved" | "Rejected" | null when the API does not say). */
async function moderationOf(gate, assetId) {
  let a;
  try { a = await R.request(gate, `${R.API}/assets/${assetId}?readMask=moderationResult`, { headers: R.headers() }, `asset ${assetId}`); }
  catch (e) { a = await R.request(gate, `${R.API}/assets/${assetId}`, { headers: R.headers() }, `asset ${assetId}`); }
  const m = a && a.moderationResult;
  return m && m.moderationState ? String(m.moderationState) : null;
}

// ------------------------------------------------------------------------------------------------ AudioIds.luau
const lua = v => (typeof v === 'string' ? JSON.stringify(v) : typeof v === 'boolean' ? String(v) : Number.isInteger(v) ? String(v) : String(+v.toFixed(6)));
function luau(map, rec) {
  const L = [], p = s => L.push(s);
  const bySha = sha => rec.assets[sha] || null;
  p('--!strict');
  p('-- GENERATED by art/audio/upload.js from art/audio/sheets/map.json + art/audio/uploaded.json. Do not edit by hand:');
  p('--   python3 art/audio/pack.py && node art/audio/upload.js [--dry-run]');
  p('-- The game\'s sounds (Core/Audio). A sound plays a region { start, length } (seconds) of a sheet; several regions');
  p('-- are its variants; a loop\'s region is exactly one period. id = nil: that sheet is not uploaded or not approved by');
  p('-- moderation yet, and every sound on it stays silent. review = the id of a sheet still in moderation: only Studio');
  p('-- (where its owner can hear it) tries it. lufs = each variant\'s loudness (momentary max; loops: integrated).');
  p('');
  p('export type Sheet = { id: string?, review: string?, moderation: string?, length: number }');
  p('export type Sound = { sheet: string, bus: string, loop: boolean, regions: { { number } }, lufs: { number } }');
  p('export type AudioIds = { version: string, sheets: { [string]: Sheet }, sounds: { [string]: Sound } }');
  p('');
  p('local AudioIds: AudioIds = {');
  p(`\tversion = ${lua(map.version)},`);
  p('\tsheets = {');
  let approved = 0, total = 0;
  for (const [key, s] of Object.entries(map.sheets)) {
    total++;
    const a = bySha(s.sha256);
    const mod = a ? a.moderation || null : null;
    const ok = a && mod === 'Approved';
    if (ok) approved++;
    const id = ok ? `"rbxassetid://${a.assetId}"` : 'nil';
    const review = a && !ok && mod !== 'Rejected' ? `"rbxassetid://${a.assetId}"` : 'nil';
    p(`\t\t${key} = { id = ${id}, review = ${review}, moderation = ${mod ? lua(mod) : a ? '"Unknown"' : 'nil'}, length = ${lua(s.length)} },`);
  }
  p('\t},');
  p('\tsounds = {');
  for (const [name, s] of Object.entries(map.sounds)) {
    const regions = s.regions.map(r => `{ ${lua(r[0])}, ${lua(r[1])} }`).join(', ');
    p(`\t\t${name} = { sheet = ${lua(s.sheet)}, bus = ${lua(s.bus)}, loop = ${s.loop}, regions = { ${regions} }, lufs = { ${(s.lufs || []).map(lua).join(', ')} } },`);
  }
  p('\t},');
  p('}');
  p('');
  p('return AudioIds');
  return { text: L.join('\n') + '\n', approved, total };
}
function writeLuau(map, rec, o) {
  if (!o.writeLuau) return;
  const { text, approved, total } = luau(map, rec);
  fs.mkdirSync(path.dirname(o.luau), { recursive: true });
  fs.writeFileSync(o.luau, text);
  console.log(`wrote ${path.relative(REPO, o.luau)}: ${approved}/${total} sheets approved (version ${map.version})`);
}

// ------------------------------------------------------------------------------------------------ main
async function main() {
  const o = parse(process.argv.slice(2));
  if (!fs.existsSync(MAP)) throw new Error('no art/audio/sheets/map.json: run `python3 art/audio/pack.py` first');
  const map = JSON.parse(fs.readFileSync(MAP, 'utf8')), rec = loadRecord();
  for (const spec of o.adopt) {
    const m = /^(\w+)=(?:rbxassetid:\/\/)?(\d+)$/.exec(spec.trim());
    if (!m || !map.sheets[m[1]]) throw new Error(`--adopt ${spec}: expected <sheet>=<assetId> with a sheet of ${Object.keys(map.sheets).join(', ')}`);
    const s = map.sheets[m[1]];
    rec.assets[s.sha256] = { assetId: m[2], sheet: m[1], file: s.file, version: map.version, moderation: null, adoptedAt: new Date().toISOString() };
    delete rec.unconfirmed[s.sha256];
    saveRecord(rec);
    console.log(`  adopted ${m[1]} = rbxassetid://${m[2]}`);
  }
  const todo = Object.entries(map.sheets).filter(([, s]) => o.force || (!rec.assets[s.sha256] && !rec.unconfirmed[s.sha256]));
  console.log(`audio sheets ${map.version}: ${Object.keys(map.sheets).length}, ${todo.length} to upload ` +
    `(${(todo.reduce((a, [, s]) => a + s.bytes, 0) / 1024).toFixed(0)} KB)`);
  if (o.dry) {
    for (const [k, s] of todo) console.log(`  would upload ${k.padEnd(4)} ${s.file}  ${(s.bytes / 1024).toFixed(0)} KB  ${s.length} s`);
    if (!R.creatorOf(o.creator)) console.log('  note: ROBLOX_CREATOR ("user:<id>" or "group:<id>") is not set; a real upload needs it');
    writeLuau(map, rec, o);
    return;
  }
  if (!R.creatorOf(o.creator)) throw new Error('set ROBLOX_CREATOR="user:<id>" or "group:<id>" (or pass --creator); nothing was uploaded');
  const gate = R.limiter(o.rpm);
  let failed = 0;
  // 1. resume operations an earlier run left unconfirmed
  for (const [sha, u] of Object.entries(rec.unconfirmed)) {
    if (!u.operationId) continue;
    try {
      const r = await R.pollOperation(gate, u.operationId, o, `resume ${u.sheet}`);
      rec.assets[sha] = { assetId: r.assetId, sheet: u.sheet, file: u.file, version: u.version, operationId: u.operationId,
        displayName: u.displayName, creator: u.creator, moderation: r.moderation, uploadedAt: u.at };
      delete rec.unconfirmed[sha];
      saveRecord(rec);
      console.log(`  ok   ${u.sheet} rbxassetid://${r.assetId} (resumed)`);
    } catch (e) { console.log(`  ???? ${u.sheet} still unconfirmed: ${e.message}`); }
  }
  // 2. uploads
  for (const [key, s] of todo) {
    if (rec.assets[s.sha256] && !o.force) continue;
    try {
      const r = await uploadOne(gate, key, s, map, o);
      rec.assets[s.sha256] = { assetId: r.assetId, sheet: key, file: s.file, version: map.version, operationId: r.operationId,
        displayName: r.displayName, creator: o.creator, moderation: r.moderation, uploadedAt: new Date().toISOString() };
      saveRecord(rec);
      console.log(`  ok   ${key.padEnd(4)} rbxassetid://${r.assetId}${r.moderation ? '  (' + r.moderation + ')' : ''}`);
    } catch (e) {
      if (e.unconfirmed) {
        rec.unconfirmed[s.sha256] = { sheet: key, file: s.file, version: map.version, displayName: displayNameOf(key, map), creator: o.creator,
          operationId: e.operationId || null, reason: e.message.slice(0, 300), at: new Date().toISOString() };
        saveRecord(rec);
        console.log(`  ???? ${key} UNCONFIRMED ${e.message}`);
      } else { failed++; console.log(`  FAIL ${key} ${e.message}`); }
    }
  }
  // 3. follow moderation of this version's sheets until each is final or --wait runs out
  const mine = Object.entries(map.sheets).map(([k, s]) => [k, rec.assets[s.sha256]]).filter(([, a]) => a);
  const until = Date.now() + o.wait * 1000;
  for (let round = 0; ; round++) {
    let open = 0;
    for (const [k, a] of mine) {
      if (FINAL.has(a.moderation)) continue;
      try {
        const m = await moderationOf(gate, a.assetId);
        if (m !== a.moderation) console.log(`  ${k.padEnd(4)} rbxassetid://${a.assetId}: ${a.moderation || 'unknown'} -> ${m || 'unknown'}`);
        a.moderation = m;
        a.checkedAt = new Date().toISOString();
        saveRecord(rec);
      } catch (e) { console.log(`  ${k}: moderation check failed: ${e.message}`); }
      if (!FINAL.has(a.moderation)) open++;
    }
    if (open === 0 || Date.now() >= until) break;
    if (round === 0) console.log(`  waiting for moderation (up to ${o.wait} s)...`);
    await R.sleep(20000);
  }
  for (const [k, a] of mine) console.log(`  ${k.padEnd(4)} rbxassetid://${a.assetId}  ${a.moderation || 'unknown'}`);
  writeLuau(map, rec, o);
  if (failed || Object.keys(rec.unconfirmed).length) process.exitCode = 1;
}

// Node's fetch ignores HTTPS_PROXY unless NODE_USE_ENV_PROXY=1 (Node >= 22.21): re-run under it for real uploads.
if (require.main === module) {
  const dry = process.argv.includes('--dry-run') || process.argv.includes('-n');
  if (!dry && (process.env.HTTPS_PROXY || process.env.https_proxy) && process.env.NODE_USE_ENV_PROXY !== '1') {
    const r = require('child_process').spawnSync(process.execPath, [__filename, ...process.argv.slice(2)], { stdio: 'inherit', env: { ...process.env, NODE_USE_ENV_PROXY: '1' } });
    process.exit(r.status == null ? 1 : r.status);
  }
  main().catch(e => { console.error(e.message); process.exit(1); });
}
module.exports = { luau };
