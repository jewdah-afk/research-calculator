#!/usr/bin/env node
/* roblox/upload.js: upload the realm tiles + sprite atlas to Roblox (Open Cloud Assets API) and generate the Luau
 * asset module the client reads.
 *
 *   node roblox/upload.js --dry-run              no network: list what would upload, write src/shared/Assets.luau
 *   ROBLOX_CREATOR=user:123 node roblox/upload.js      upload everything not uploaded yet, then write Assets.luau
 *   options: --tier HIGH|LOW  --only sky,world,atlas  --creator user:<id>|group:<id>  --rpm 50  --concurrency 2
 *            --force (re-upload even if the sha256 is recorded)  --luau <path>  --no-luau  --record <uploaded.json>
 *            --adopt <TIER>/<key>=<assetId>   record an asset found in the Creator Dashboard (see "unconfirmed" below)
 *            --retry-unconfirmed              upload the unconfirmed images again (may leave a duplicate on Roblox)
 *            --poll-max 120                   polls per operation before it counts as unconfirmed
 *
 * Reads roblox/manifest.json (from tile.js). A file is identified by its sha256: roblox/uploaded.json maps
 * sha256 -> { assetId, ... }, so re-running uploads only what changed, and an interrupted run resumes where it stopped
 * (the record is written after every finished asset).
 *
 * Auth: the API key header is added by the network proxy for apis.roblox.com, so none is required here. If
 * ROBLOX_API_KEY is set it is sent as x-api-key (local runs outside the proxy). The creator comes from --creator or
 * ROBLOX_CREATOR ("user:<id>" or "group:<id>").
 *
 * Protocol (https://create.roblox.com/docs/cloud/open-cloud/usage-assets):
 *   POST https://apis.roblox.com/assets/v1/assets  multipart: request = {assetType:"Image", displayName, description,
 *        creationContext:{creator:{userId|groupId}}}, fileContent = the PNG  -> an Operation { path: "operations/<id>" }
 *   GET  https://apis.roblox.com/assets/v1/operations/<id>  until done -> response.assetId
 * Every request goes through one rate limiter (--rpm, default 50/min, under the documented per-key limits).
 *
 * Retries. The poll (GET) is idempotent: network errors, 429 and 5xx retry with exponential backoff + jitter,
 * honouring Retry-After / x-ratelimit-reset. The create (POST) is not: a retry after Roblox made the asset would make a
 * second one. It is retried automatically only when Roblox cannot have processed it: HTTP 429, HTTP 503 with
 * Retry-After, or a network error before the connection was made (refused, DNS, connect timeout). Any other outcome
 * after the body was sent (another 5xx, a reset, a lost or unreadable response, or a poll that never finishes) is
 * "unconfirmed": the run logs it, records it under `unconfirmed` in uploaded.json (with the operation id when there is
 * one) and leaves the tile without an id. The next run resumes polling a recorded operation; one without an
 * operation id is skipped until you resolve it: find the image in the Creator Dashboard by its displayName
 * ("Realm HIGH sky_0_0", the description carries the sha256 prefix) and run --adopt HIGH/sky_0_0=<assetId>, or run
 * --retry-unconfirmed to upload it again.
 *
 * Output: src/shared/Assets.luau (a ModuleScript; ids are "rbxassetid://<id>", or nil when not uploaded, so the client
 * can fall back), and out/realm_assets.json (the REALM.md section 3 asset map).
 */
'use strict';
const fs = require('fs'), path = require('path');

const ROBLOX = __dirname, ART = path.resolve(ROBLOX, '..'), REPO = path.resolve(ART, '..');
const MANIFEST = path.join(ROBLOX, 'manifest.json');
let RECORD = path.join(ROBLOX, 'uploaded.json');
const API = process.env.ROBLOX_ASSETS_API || 'https://apis.roblox.com/assets/v1';   // override only to test against a mock
const TIERS = ['HIGH', 'LOW'];

function parse(argv) {
  const o = { dry: false, tiers: TIERS, only: null, creator: process.env.ROBLOX_CREATOR || null, rpm: 50, conc: 2, force: false,
    luau: path.join(REPO, 'src/shared/Assets.luau'), writeLuau: true, pollMax: 120, adopt: [], retryUnconfirmed: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i], v = () => argv[++i];
    if (a === '--dry-run' || a === '-n') o.dry = true;
    else if (a === '--tier') o.tiers = [v().toUpperCase()];
    else if (a === '--only') o.only = v().split(',');
    else if (a === '--creator') o.creator = v();
    else if (a === '--rpm') o.rpm = +v();
    else if (a === '--concurrency') o.conc = Math.max(1, +v());
    else if (a === '--force') o.force = true;
    else if (a === '--luau') o.luau = path.resolve(v());
    else if (a === '--no-luau') o.writeLuau = false;
    else if (a === '--record') RECORD = path.resolve(v());   // tests: keep the real record untouched
    else if (a === '--adopt') o.adopt.push(v());
    else if (a === '--retry-unconfirmed') o.retryUnconfirmed = true;
    else if (a === '--poll-max') o.pollMax = Math.max(1, +v());
    else if (a === '-h' || a === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); process.exit(0); }
    else throw new Error('unknown argument ' + a);
  }
  return o;
}
function creatorOf(s) {
  const m = /^(user|group):(\d+)$/.exec(String(s || '').trim());
  if (!m) return null;
  return m[1] === 'user' ? { userId: m[2] } : { groupId: m[2] };
}

// ------------------------------------------------------------------------------------------------ jobs
function jobs(man, o) {
  const out = [];
  for (const tier of o.tiers) {
    for (const L of man.tiers[tier].layers) {
      if (o.only && !o.only.includes(L.id)) continue;
      for (const t of L.tiles) if (!t.empty && t.file) out.push({ tier, key: `${L.id}_${t.i}_${t.j}`, file: t.file, sha256: t.sha256, bytes: t.bytes });
    }
    const at = man.atlas && man.atlas.tiers[tier];
    if (at && (!o.only || o.only.includes('atlas'))) out.push({ tier, key: 'atlas', file: at.file, sha256: at.sha256, bytes: at.bytes });
  }
  return out;
}
function loadRecord() {
  const r = fs.existsSync(RECORD) ? JSON.parse(fs.readFileSync(RECORD, 'utf8')) : {};
  return { assets: r.assets || {}, unconfirmed: r.unconfirmed || {} };
}
function saveRecord(rec) {
  const sorted = o => { const out = {}; for (const k of Object.keys(o).sort()) out[k] = o[k]; return out; };
  const body = {
    about: 'Roblox asset ids of uploaded realm images, keyed by the PNG sha256 (written by roblox/upload.js). Keep it in git: it is how re-runs skip what is already uploaded. ' +
      '`unconfirmed` lists creates whose outcome is unknown (the asset may exist): the next run polls a recorded operationId; otherwise resolve it with --adopt or --retry-unconfirmed.',
    assets: sorted(rec.assets) };
  if (Object.keys(rec.unconfirmed).length) body.unconfirmed = sorted(rec.unconfirmed);
  fs.writeFileSync(RECORD, JSON.stringify(body, null, 1) + '\n');
}

// ------------------------------------------------------------------------------------------------ network
const sleep = ms => new Promise(r => setTimeout(r, ms));
function limiter(rpm) { // one request every 60/rpm s, shared by uploads and polls
  let next = 0;
  return async () => { const now = Date.now(), at = Math.max(now, next); next = at + 60000 / rpm; if (at > now) await sleep(at - now); };
}
function headers(extra = {}) {
  const h = { ...extra };
  if (process.env.ROBLOX_API_KEY) h['x-api-key'] = process.env.ROBLOX_API_KEY;   // otherwise injected by the proxy
  return h;
}
/** The outcome of a create is unknown: Roblox may have made the asset. Never retried automatically. */
class Unconfirmed extends Error { constructor(msg, operationId = null) { super(msg); this.unconfirmed = true; this.operationId = operationId; } }
// network errors raised before a connection exists: the request never reached Roblox, so even a create may retry
const BEFORE_CONNECT = new Set(['ECONNREFUSED', 'ENOTFOUND', 'EAI_AGAIN', 'ENETUNREACH', 'EHOSTUNREACH', 'EADDRNOTAVAIL', 'UND_ERR_CONNECT_TIMEOUT']);
const errCode = e => { for (let c = e, n = 0; c && n < 5; c = c.cause, n++) if (c.code) return c.code; return (e && e.name) || 'error'; };
/** Retry-After (seconds or an HTTP date) or x-ratelimit-reset (seconds), in ms; null when absent. */
function retryAfterMs(res) {
  const ra = res.headers.get('retry-after'), rs = res.headers.get('x-ratelimit-reset');
  if (ra != null && ra.trim() !== '') { const n = Number(ra); if (Number.isFinite(n)) return Math.max(0, n * 1000); const d = Date.parse(ra); if (!Number.isNaN(d)) return Math.max(0, d - Date.now()); }
  if (rs != null && Number.isFinite(Number(rs))) return Math.max(0, Number(rs) * 1000);
  return null;
}
/** One JSON request through the rate limiter. create = true for the non-idempotent POST (see the header: it retries
 *  only where Roblox cannot have processed it and throws Unconfirmed where it may have). */
async function request(gate, url, init, what, { create = false, tries = 7 } = {}) {
  for (let k = 0; ; k++) {
    await gate();
    let res;
    try { res = await fetch(url, init); }
    catch (e) {
      const code = errCode(e);
      if (create && !BEFORE_CONNECT.has(code)) throw new Unconfirmed(`${what}: network error after the request was sent (${code}: ${e.message})`);
      if (k >= tries) throw new Error(`${what}: ${code} ${e.message}`);
      const wait = backoff(k); console.log(`  ${what}: ${code}, retry in ${(wait / 1000).toFixed(1)} s`); await sleep(wait); continue;
    }
    let body = null;
    try { body = await res.text(); } catch (e) { body = null; }
    if (res.ok) {
      let json = null;
      try { json = body ? JSON.parse(body) : {}; } catch (e) { json = null; }
      if (json) return json;
      if (create) throw new Unconfirmed(`${what}: HTTP ${res.status} but the response was ${body == null ? 'lost' : 'not JSON'}`);
      if (k >= tries) throw new Error(`${what}: HTTP ${res.status}, unreadable response`);
      await sleep(backoff(k)); continue;
    }
    const ra = retryAfterMs(res);
    const again = create ? res.status === 429 || (res.status === 503 && ra != null) : res.status === 429 || res.status >= 500;
    if (again && k < tries) {
      const wait = Math.max(ra || 0, backoff(k));
      console.log(`  ${what}: HTTP ${res.status}, retry in ${(wait / 1000).toFixed(1)} s`);
      await sleep(wait); continue;
    }
    const msg = `${what}: HTTP ${res.status} ${(body || '').slice(0, 400)}`;
    if (create && res.status >= 500 && !(res.status === 503 && ra != null)) throw new Unconfirmed(msg + ' (the asset may exist)');
    throw new Error(msg);
  }
}
const backoff = k => Math.min(60000, 1000 * 2 ** k) * (0.75 + Math.random() * 0.5);

/** Poll an operation until done -> { assetId, moderation }. Throws Unconfirmed (with the id) if it never finishes. */
async function pollOperation(gate, opId, o, what, op = { done: false }) {
  try {
    for (let k = 0; !op.done; k++) {
      if (k >= o.pollMax) throw new Error(`operation ${opId} not done after ${k} polls`);
      await sleep(Math.min(8000, 500 * 1.5 ** k));
      op = await request(gate, `${API}/operations/${opId}`, { headers: headers() }, `poll ${what}`);
    }
  } catch (e) { throw new Unconfirmed(`${what}: ${e.message}`, opId); }
  if (op.error) throw new Error(`${what}: ${JSON.stringify(op.error)}`);        // the create failed: nothing was made
  const r = op.response || {};
  if (!r.assetId) throw new Unconfirmed(`${what}: operation ${opId} finished without an assetId: ${JSON.stringify(op).slice(0, 300)}`, opId);
  return { assetId: String(r.assetId), moderation: r.moderationResult && r.moderationResult.moderationState || null };
}

async function uploadOne(gate, job, o, man) {
  const buf = fs.readFileSync(path.join(ROBLOX, job.file));
  const displayName = displayNameOf(job);
  const req = { assetType: 'Image', displayName, description: `Milestone Tree realm parallax ${job.tier} ${job.key} (manifest ${man.version}, sha256 ${job.sha256.slice(0, 16)})`,
    creationContext: { creator: creatorOf(o.creator) } };
  const form = new FormData();
  form.append('request', JSON.stringify(req));
  form.append('fileContent', new Blob([buf], { type: 'image/png' }), path.basename(job.file));
  const what = `${job.tier}/${job.key}`;
  const op = await request(gate, `${API}/assets`, { method: 'POST', headers: headers(), body: form }, `upload ${what}`, { create: true });
  const opId = op.operationId || (op.path || '').split('/').pop() || null;
  if (!op.done && !opId) throw new Unconfirmed(`upload ${what}: the response names no operation: ${JSON.stringify(op).slice(0, 300)}`);
  const r = await pollOperation(gate, opId, o, `upload ${what}`, op);
  return { ...r, operationId: opId, displayName };
}
const displayNameOf = job => `Realm ${job.tier} ${job.key}`.slice(0, 50);

// ------------------------------------------------------------------------------------------------ outputs
const lua = v => (typeof v === 'string' ? JSON.stringify(v) : typeof v === 'boolean' ? String(v) : Number.isInteger(v) ? String(v) : String(+v.toFixed(6)));
function luau(man, rec, R) {
  const idOf = sha => (sha && rec.assets[sha] ? `"rbxassetid://${rec.assets[sha].assetId}"` : 'nil');
  let total = 0, have = 0;
  const L = [];
  const p = s => L.push(s);
  p('--!strict');
  p('-- GENERATED by art/roblox/upload.js from art/roblox/manifest.json + art/roblox/uploaded.json. Do not edit by hand:');
  p('--   cd art && node roblox/tile.js && node roblox/upload.js [--dry-run]');
  p('-- The realm parallax textures (art/REALM.md section 3). Each layer is a grid of tiles in layer-local px (x, y, w, h);');
  p('-- the image holds the tile plus a `gutter` px border, so ImageRectOffset = (gutter, gutter) and ImageRectSize = (rw, rh).');
  p('-- id = nil means that image is not uploaded yet: skip the tile (the layers behind show through) or fall back to');
  p('-- the other tier. Fully transparent tiles are left out. Sprite regions are HIGH atlas px; the LOW atlas is half size.');
  p('-- Place tiles by the snapped recipe of art/REALM.md 9.3: the column / row edges (x, x + w; y, y + h) rounded to whole');
  p('-- device pixels, each edge shared by the two neighbours. No overlap: a tile drawn wider blends its edge strip twice.');
  p('');
  p('export type Tile = { i: number, j: number, x: number, y: number, w: number, h: number, rw: number, rh: number, id: string? }');
  p('export type Layer = { depth: number, f: number, w: number, h: number, scale: number, cols: number, rows: number, opaque: boolean, zHide: number, zShow: number, tiles: { Tile } }');
  p('export type Tier = { layers: { [string]: Layer }, order: { string }, atlas: { id: string?, w: number, h: number } }');
  p('export type Assets = { version: string, complete: boolean, uploaded: number, total: number, gutter: number, tiers: { HIGH: Tier, LOW: Tier }, sprites: { atlas: { HIGH: string?, LOW: string? }, size: { HIGH: { number }, LOW: { number } }, regions: { [string]: { number } }, sample: { [string]: { number } } } }');
  p('');
  p('local Assets: Assets = {');
  p(`\tversion = ${lua(man.version)},`);
  const posComplete = L.length; p('');                        // filled in below
  p(`\tgutter = ${man.gutter},`);
  p('\ttiers = {');
  for (const tier of TIERS) {
    p(`\t\t${tier} = {`);
    p('\t\t\tlayers = {');
    const order = [];
    for (const E of man.tiers[tier].layers) {
      if (E.missing) { p(`\t\t\t\t-- ${E.id}: not rendered yet (${E.error ? 'wrong size' : 'no out/' + E.id + '.png'})`); continue; }
      order.push(E.id);
      const cols = Math.max(...E.tiles.map(t => t.i)) + 1, rows = Math.max(...E.tiles.map(t => t.j)) + 1;
      p(`\t\t\t\t${E.id} = { depth = ${E.depth}, f = ${lua(E.f)}, w = ${E.size[0]}, h = ${E.size[1]}, scale = ${lua(E.scale)}, cols = ${cols}, rows = ${rows}, opaque = ${E.opaque}, zHide = ${lua(E.zHide || 0)}, zShow = ${lua(E.zShow || 0)}, tiles = {`);
      for (const t of E.tiles) {
        if (t.empty) continue;
        total++; if (rec.assets[t.sha256]) have++;
        p(`\t\t\t\t\t{ i = ${t.i}, j = ${t.j}, x = ${lua(t.local.x)}, y = ${lua(t.local.y)}, w = ${lua(t.local.w)}, h = ${lua(t.local.h)}, rw = ${t.rectSize[0]}, rh = ${t.rectSize[1]}, id = ${idOf(t.sha256)} },`);
      }
      p('\t\t\t\t} },');
    }
    p('\t\t\t},');
    p(`\t\t\torder = { ${order.map(lua).join(', ')} },`);
    const at = man.atlas && man.atlas.tiers[tier];
    const size = tier === 'HIGH' ? R.atlas.size : R.atlas.lowSize;
    if (at) { total++; if (rec.assets[at.sha256]) have++; }
    p(`\t\t\tatlas = { id = ${at ? idOf(at.sha256) : 'nil'}, w = ${size[0]}, h = ${size[1]} },`);
    p('\t\t},');
  }
  p('\t},');
  p('\tsprites = {');
  const aid = tier => (man.atlas && man.atlas.tiers[tier] ? idOf(man.atlas.tiers[tier].sha256) : 'nil');
  p(`\t\tatlas = { HIGH = ${aid('HIGH')}, LOW = ${aid('LOW')} },`);
  p(`\t\tsize = { HIGH = { ${R.atlas.size.join(', ')} }, LOW = { ${R.atlas.lowSize.join(', ')} } },`);
  p('\t\tregions = {');
  for (const [k, r] of Object.entries(R.atlas.regions)) p(`\t\t\t${k} = { ${r.join(', ')} },`);
  p('\t\t},');
  p('\t\t-- regions sampled through an inset rect instead of their own (HIGH atlas px; halve for LOW). The vignette keeps a');
  p('\t\t-- clear gutter inside its rect and its black runs a little past this rect, so stretched over the screen no edge shows.');
  const sr = (man.atlas && man.atlas.sampleRects) || {};
  p(`\t\tsample = { ${Object.entries(sr).map(([k, r]) => `${k} = { ${r.join(', ')} }`).join(', ')} },`);
  p('\t},');
  p('}');
  p('');
  p('return Assets');
  L[posComplete] = `\tcomplete = ${have === total && total > 0},\n\tuploaded = ${have},\n\ttotal = ${total},`;
  return { text: L.join('\n') + '\n', have, total };
}
function assetMap(man, rec) {
  const m = {};
  for (const tier of TIERS) {
    m[tier] = {};
    for (const E of man.tiers[tier].layers) for (const t of E.tiles) {
      if (t.empty) continue; (m[tier][E.id] = m[tier][E.id] || {})[`${t.i}_${t.j}`] = rec.assets[t.sha256] ? `rbxassetid://${rec.assets[t.sha256].assetId}` : null;
    }
    const at = man.atlas && man.atlas.tiers[tier];
    m[tier].atlas = at && rec.assets[at.sha256] ? `rbxassetid://${rec.assets[at.sha256].assetId}` : null;
  }
  return m;
}
function writeOutputs(man, rec, o) {
  const R = JSON.parse(fs.readFileSync(path.join(ART, 'realm.json'), 'utf8'));
  const { text, have, total } = luau(man, rec, R);
  if (o.writeLuau) { fs.mkdirSync(path.dirname(o.luau), { recursive: true }); fs.writeFileSync(o.luau, text); console.log(`wrote ${path.relative(REPO, o.luau)}: ${have}/${total} images have ids (version ${man.version})`); }
  const map = path.join(path.dirname(o.luau) === path.join(REPO, 'src/shared') ? path.join(ART, 'out') : path.dirname(o.luau), 'realm_assets.json');
  fs.mkdirSync(path.dirname(map), { recursive: true });
  fs.writeFileSync(map, JSON.stringify(assetMap(man, rec), null, 1) + '\n');
}

// ------------------------------------------------------------------------------------------------ main
/** --adopt <TIER>/<key>=<assetId> or <sha256 prefix>=<assetId>: record an asset that exists on Roblox. */
function adopt(specs, man, rec) {
  const every = jobs(man, { tiers: TIERS, only: null });
  for (const spec of specs) {
    const m = /^([^=]+)=(?:rbxassetid:\/\/)?(\d+)$/.exec(spec.trim());
    if (!m) throw new Error(`--adopt ${spec}: expected <TIER>/<key>=<assetId> or <sha256 prefix>=<assetId>`);
    const [, who, assetId] = m, k = who.toLowerCase();
    const hit = every.filter(j => `${j.tier}/${j.key}`.toLowerCase() === k || (k.length >= 8 && /^[0-9a-f]+$/.test(k) && j.sha256.startsWith(k)));
    const shas = [...new Set(hit.map(j => j.sha256))];
    if (shas.length !== 1) throw new Error(`--adopt ${spec}: ${shas.length ? 'ambiguous' : 'matches no image of manifest ' + man.version}`);
    const j = hit[0], u = rec.unconfirmed[j.sha256] || {};
    rec.assets[j.sha256] = { assetId, file: j.file, displayName: u.displayName || displayNameOf(j), creator: u.creator || null, operationId: u.operationId || null,
      moderation: null, manifest: man.version, uploadedAt: u.at || null, adoptedAt: new Date().toISOString() };
    delete rec.unconfirmed[j.sha256];
    console.log(`  adopted ${j.tier}/${j.key} = rbxassetid://${assetId}`);
  }
}
const logJob = (tag, job, rest) => console.log(`  ${tag.padEnd(4)} ${job.tier.padEnd(4)} ${job.key.padEnd(12)} ${rest}`);

async function main() {
  const o = parse(process.argv.slice(2));
  if (!fs.existsSync(MANIFEST)) throw new Error('no roblox/manifest.json: run `node roblox/tile.js` first');
  const man = JSON.parse(fs.readFileSync(MANIFEST, 'utf8')), rec = loadRecord();
  if (o.adopt.length) { adopt(o.adopt, man, rec); saveRecord(rec); }
  const all = jobs(man, o), seen = new Set();
  const unique = all.filter(j => !seen.has(j.sha256) && seen.add(j.sha256));        // identical PNGs upload once
  const unconf = unique.filter(j => !rec.assets[j.sha256] && rec.unconfirmed[j.sha256]);
  const pending = () => unique.filter(j => o.force || (!rec.assets[j.sha256] && (!rec.unconfirmed[j.sha256] || o.retryUnconfirmed)));
  let todo = pending();
  const mb = todo.reduce((a, j) => a + j.bytes, 0) / 1048576, have = unique.filter(j => rec.assets[j.sha256]).length;
  console.log(`manifest ${man.version}: ${all.length} images${unique.length < all.length ? ` (${unique.length} distinct)` : ''}, ${have} already uploaded, ` +
    `${todo.length} to upload (${mb.toFixed(1)} MB)${unconf.length ? `, ${unconf.length} unconfirmed` : ''}`);
  for (const tier of TIERS) if (man.budget && man.budget[tier]) console.log(`  ${tier}: ${man.budget[tier].images} images, ${man.budget[tier].textureMB} MB texture (${man.budget[tier].withMipsMB} MB with mips) of ${man.budget[tier].budgetMB} MB`);
  if (o.dry) {
    for (const j of todo) console.log(`  would upload ${j.tier.padEnd(4)} ${j.key.padEnd(12)} ${(j.bytes / 1024).toFixed(0).padStart(6)} KB  ${j.file}`);
    for (const j of unconf) { const u = rec.unconfirmed[j.sha256]; if (!o.retryUnconfirmed) console.log(`  ${u.operationId ? 'would poll operation ' + u.operationId + ' of' : 'unconfirmed (skipped until resolved)'} ${j.tier}/${j.key}`); }
    if (!creatorOf(o.creator)) console.log('  note: ROBLOX_CREATOR ("user:<id>" or "group:<id>") is not set; a real upload needs it');
    writeOutputs(man, rec, o);
    return;
  }
  if (!creatorOf(o.creator)) throw new Error('set ROBLOX_CREATOR="user:<id>" or "group:<id>" (or pass --creator); nothing was uploaded');
  if (typeof fetch !== 'function' || typeof FormData !== 'function') throw new Error('needs Node >= 18 (global fetch / FormData)');
  const gate = limiter(o.rpm);
  const done = (job, r) => {
    rec.assets[job.sha256] = { assetId: r.assetId, file: job.file, displayName: r.displayName || displayNameOf(job), creator: o.creator, operationId: r.operationId,
      moderation: r.moderation, manifest: man.version, uploadedAt: new Date().toISOString() };
    delete rec.unconfirmed[job.sha256];
    saveRecord(rec);
    logJob('ok', job, `rbxassetid://${r.assetId}${r.moderation ? '  (' + r.moderation + ')' : ''}`);
  };
  const unsure = (job, e) => {
    const prev = rec.unconfirmed[job.sha256] || {};
    rec.unconfirmed[job.sha256] = { file: job.file, tier: job.tier, key: job.key, displayName: displayNameOf(job), creator: o.creator,
      operationId: e.operationId || prev.operationId || null, reason: e.message.slice(0, 300), at: new Date().toISOString() };
    saveRecord(rec);
    logJob('????', job, `UNCONFIRMED ${e.message}`);
  };
  // 1. finish the operations an earlier run started (no new asset is created)
  for (const job of unconf) {
    const u = rec.unconfirmed[job.sha256];
    if (!u.operationId) continue;
    try { done(job, { ...(await pollOperation(gate, u.operationId, o, `resume ${job.tier}/${job.key}`)), operationId: u.operationId, displayName: u.displayName }); }
    catch (e) {
      if (e.unconfirmed) { unsure(job, e); continue; }
      delete rec.unconfirmed[job.sha256]; saveRecord(rec);                        // the operation failed: nothing exists
      logJob('info', job, `operation ${u.operationId} failed (${e.message}); uploading it again`);
    }
  }
  todo = pending();
  // 2. new uploads
  let i = 0, ok = 0, failed = 0;
  const worker = async () => {
    while (i < todo.length) {
      const job = todo[i++];
      try { done(job, await uploadOne(gate, job, o, man)); ok++; }
      catch (e) { if (e.unconfirmed) unsure(job, e); else { failed++; logJob('FAIL', job, e.message); } }
    }
  };
  await Promise.all(Array.from({ length: Math.min(o.conc, todo.length) }, worker));
  const left = unique.filter(j => !rec.assets[j.sha256] && rec.unconfirmed[j.sha256]);
  console.log(`uploaded ${ok}, failed ${failed}${failed ? " (not created: the next run retries them)" : ""}, unconfirmed ${left.length}`);
  if (left.length) {
    console.log('  unconfirmed images may already exist on Roblox, so they are not uploaded again automatically:');
    for (const j of left) { const u = rec.unconfirmed[j.sha256];
      console.log(`    ${j.tier}/${j.key}  "${displayNameOf(j)}"  sha256 ${j.sha256.slice(0, 16)}${u.operationId ? '  operation ' + u.operationId + ' (the next run polls it)' : ''}`); }
    console.log('  resolve: find the image in the Creator Dashboard and run --adopt <TIER>/<key>=<assetId>, or --retry-unconfirmed to upload it again');
  }
  writeOutputs(man, rec, o);
  if (failed || left.length) process.exitCode = 1;
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
module.exports = { luau, assetMap, jobs, creatorOf, request, Unconfirmed };
