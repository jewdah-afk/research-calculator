// Cube Craft chunk mesher: blocks -> textured triangles with corner shading.
// Works on the chunk layout from planetgen.chunk(): the chunk plus a 1-block ring of neighbours,
// so faces between chunks are skipped and corner shading matches across chunk borders.
// Output is flat typed arrays per material group, ready for a GPU buffer (or an EditableMesh).
(function (root) {
  "use strict";
  // kinds: 0 air, 1 solid, 2 leaves, 3 glass, 4 water, 5 lava, 6 plant
  const KIND = { air: 0, solid: 1, leaves: 2, glass: 3, water: 4, lava: 5, plant: 6 };

  function Buf(n) { this.a = new Float32Array(n); this.n = 0; }
  Buf.prototype.need = function (k) {
    if (this.n + k > this.a.length) { const b = new Float32Array(Math.max(this.a.length * 2, this.n + k)); b.set(this.a.subarray(0, this.n)); this.a = b; }
  };
  function IBuf(n) { this.a = new Uint32Array(n); this.n = 0; }
  IBuf.prototype.need = function (k) {
    if (this.n + k > this.a.length) { const b = new Uint32Array(Math.max(this.a.length * 2, this.n + k)); b.set(this.a.subarray(0, this.n)); this.a = b; }
  };
  function Group() { this.pos = new Buf(8192); this.uv = new Buf(5462); this.col = new Buf(2731); this.idx = new IBuf(4096); this.v = 0; }

  // faces: normal, corners (BL, BR, TR, TL seen from outside), texture slot (0 top, 1 side, 2 bottom), shade
  const FACES = [
    { n: [1, 0, 0], c: [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]], slot: 1, shade: 0.86 },
    { n: [-1, 0, 0], c: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]], slot: 1, shade: 0.72 },
    { n: [0, 0, 1], c: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], slot: 1, shade: 0.8 },
    { n: [0, 0, -1], c: [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]], slot: 1, shade: 0.66 },
    { n: [0, 1, 0], c: [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]], slot: 0, shade: 1.0 },
    { n: [0, -1, 0], c: [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]], slot: 2, shade: 0.5 },
  ];
  const UVC = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const AO = [0.42, 0.6, 0.8, 1.0];
  // for each face and corner: three neighbour offsets (dx, dy, dz) in the layer the face looks into
  for (const f of FACES) {
    const ax = [0, 1, 2].filter((a) => f.n[a] === 0);
    f.ao = f.c.map((cc) => {
      const d0 = [0, 0, 0], d1 = [0, 0, 0];
      d0[ax[0]] = cc[ax[0]] ? 1 : -1;
      d1[ax[1]] = cc[ax[1]] ? 1 : -1;
      const s1 = [f.n[0] + d0[0], f.n[1] + d0[1], f.n[2] + d0[2]];
      const s2 = [f.n[0] + d1[0], f.n[1] + d1[1], f.n[2] + d1[2]];
      const s3 = [f.n[0] + d0[0] + d1[0], f.n[1] + d0[1] + d1[1], f.n[2] + d0[2] + d1[2]];
      return [s1, s2, s3];
    });
  }

  // blockInfo: array per block id of { kind (string), t, s, b (atlas tiles) }; atlas: { cols, rows, tile, pad, cell }
  function createMesher(blockInfo, atlas) {
    const nB = blockInfo.length;
    const K = new Uint8Array(256), T = new Uint16Array(256 * 3);
    for (let i = 0; i < nB; i++) {
      K[i] = KIND[blockInfo[i].kind] || 0;
      T[i * 3] = blockInfo[i].t; T[i * 3 + 1] = blockInfo[i].s; T[i * 3 + 2] = blockInfo[i].b;
    }
    const AW = atlas.cols * atlas.cell, AH = atlas.rows * atlas.cell;
    // per tile: u0, u1, v0, v1
    const TUV = new Float32Array(atlas.cols * atlas.rows * 4);
    for (let t = 0; t < atlas.cols * atlas.rows; t++) {
      const col = t % atlas.cols, row = Math.floor(t / atlas.cols);
      const x0 = col * atlas.cell + atlas.pad, y0 = row * atlas.cell + atlas.pad;
      TUV[t * 4] = x0 / AW; TUV[t * 4 + 1] = (x0 + atlas.tile) / AW;
      TUV[t * 4 + 2] = 1 - (y0 + atlas.tile) / AH; TUV[t * 4 + 3] = 1 - y0 / AH;
    }

    // walls: { nx, px, nz, pz } = treat that side's neighbour ring as empty (edge of the loaded area)
    return function mesh(ch, walls, yFrom, yTo) {
      const { W, SX, SZ, Y } = ch;
      const sZ = Y, sX = SZ * Y;
      walls = walls || {};
      const G = [new Group(), new Group(), new Group(), new Group()]; // opaque, transparent, plant, lava
      const kindAt = (i, j, y) => {
        if (y < 0 || y >= Y || i < 0 || j < 0 || i >= SX || j >= SZ) return 0;
        if ((walls.nx && i === 0) || (walls.px && i === SX - 1) || (walls.nz && j === 0) || (walls.pz && j === SZ - 1)) return 0;
        return K[W[i * sX + j * sZ + y]];
      };
      const occ = (i, j, y) => { const k = kindAt(i, j, y); return k === 1 || k === 2 ? 1 : 0; };

      function quad(g, x, y, z, f, tile, lights, liquidTop) {
        const p = g.pos, uv = g.uv, cl = g.col, ix = g.idx;
        p.need(12); uv.need(8); cl.need(4); ix.need(6);
        const u0 = TUV[tile * 4], u1 = TUV[tile * 4 + 1], v0 = TUV[tile * 4 + 2], v1 = TUV[tile * 4 + 3];
        for (let c = 0; c < 4; c++) {
          const cc = f.c[c];
          p.a[p.n++] = x + cc[0];
          p.a[p.n++] = y + (liquidTop && cc[1] === 1 ? 0.875 : cc[1]);
          p.a[p.n++] = z + cc[2];
          uv.a[uv.n++] = UVC[c][0] ? u1 : u0;
          uv.a[uv.n++] = UVC[c][1] ? v1 : v0;
          cl.a[cl.n++] = lights[c];
        }
        const b = g.v;
        if (lights[0] + lights[2] < lights[1] + lights[3]) { ix.a[ix.n++] = b + 1; ix.a[ix.n++] = b + 2; ix.a[ix.n++] = b + 3; ix.a[ix.n++] = b + 1; ix.a[ix.n++] = b + 3; ix.a[ix.n++] = b; }
        else { ix.a[ix.n++] = b; ix.a[ix.n++] = b + 1; ix.a[ix.n++] = b + 2; ix.a[ix.n++] = b; ix.a[ix.n++] = b + 2; ix.a[ix.n++] = b + 3; }
        g.v += 4;
      }
      function plantQuads(g, x, y, z, tile) {
        const p = g.pos, uv = g.uv, cl = g.col, ix = g.idx;
        const u0 = TUV[tile * 4], u1 = TUV[tile * 4 + 1], v0 = TUV[tile * 4 + 2], v1 = TUV[tile * 4 + 3];
        const a = 0.15, c = 0.85;
        const Q = [[a, a, c, c], [a, c, c, a]];
        for (const q of Q) {
          p.need(12); uv.need(8); cl.need(4); ix.need(6);
          const pts = [[q[0], 0, q[1]], [q[2], 0, q[3]], [q[2], 1, q[3]], [q[0], 1, q[1]]];
          for (let k = 0; k < 4; k++) {
            p.a[p.n++] = x + pts[k][0]; p.a[p.n++] = y + pts[k][1]; p.a[p.n++] = z + pts[k][2];
            uv.a[uv.n++] = UVC[k][0] ? u1 : u0; uv.a[uv.n++] = UVC[k][1] ? v1 : v0;
            cl.a[cl.n++] = k < 2 ? 0.76 : 0.95;
          }
          const b = g.v;
          ix.a[ix.n++] = b; ix.a[ix.n++] = b + 1; ix.a[ix.n++] = b + 2; ix.a[ix.n++] = b; ix.a[ix.n++] = b + 2; ix.a[ix.n++] = b + 3;
          g.v += 4;
        }
      }

      const lights = [0, 0, 0, 0];
      const ya = yFrom == null ? 0 : Math.max(0, yFrom), yb = yTo == null ? Y : Math.min(Y, yTo);
      for (let i = 1; i < SX - 1; i++) for (let j = 1; j < SZ - 1; j++) {
        const base = i * sX + j * sZ;
        for (let y = ya; y < yb; y++) {
          const id = W[base + y];
          if (!id) continue;
          const k = K[id];
          if (k === 6) { plantQuads(G[2], i, y, j, T[id * 3 + 1]); continue; }
          const liquid = k === 4 || k === 5;
          for (let fi = 0; fi < 6; fi++) {
            const f = FACES[fi];
            const ni = i + f.n[0], ny = y + f.n[1], nj = j + f.n[2];
            if (ny < 0) continue;
            const nk = kindAt(ni, nj, ny);
            if (k === 1 && nk === 1) continue;
            if ((k === 2 || k === 3) && (nk === 1 || W[ni * sX + nj * sZ + ny] === id)) continue;
            if (liquid && nk !== 0 && nk !== 6 && nk !== 3) continue;
            const tile = T[id * 3 + f.slot];
            if (liquid) {
              const lt = fi === 4 && kindAt(i, j, y + 1) !== k;
              const L = k === 5 ? 1 : f.shade;
              lights[0] = lights[1] = lights[2] = lights[3] = L;
              quad(k === 5 ? G[3] : G[1], i, y, j, f, tile, lights, lt || (fi < 4 && kindAt(i, j, y + 1) !== k));
              continue;
            }
            // corner shading from the three blocks around each corner, in the layer the face looks into
            for (let c = 0; c < 4; c++) {
              const o = f.ao[c];
              const o1 = occ(i + o[0][0], j + o[0][2], y + o[0][1]);
              const o2 = occ(i + o[1][0], j + o[1][2], y + o[1][1]);
              const o3 = occ(i + o[2][0], j + o[2][2], y + o[2][1]);
              lights[c] = AO[(o1 && o2) ? 0 : 3 - (o1 + o2 + o3)] * f.shade;
            }
            quad(k === 3 ? G[1] : G[0], i, y, j, f, tile, lights, false);
          }
        }
      }

      const out = {};
      const names = ["opaque", "trans", "plant", "lava"];
      let tris = 0;
      for (let g = 0; g < 4; g++) {
        const gr = G[g];
        if (!gr.idx.n) continue;
        out[names[g]] = { pos: gr.pos.a.slice(0, gr.pos.n), uv: gr.uv.a.slice(0, gr.uv.n), col: gr.col.a.slice(0, gr.col.n), idx: gr.idx.a.slice(0, gr.idx.n) };
        tris += gr.idx.n / 3;
      }
      out.tris = tris;
      return out;
    };
  }

  const api = { createMesher };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CubeMesher = api;
})(this);
