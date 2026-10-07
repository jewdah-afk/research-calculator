--!nonstrict
-- World: every island on one world tile grid (approved concept rc-main/concepts/islands.html), plus brick bridges
-- between EVERY pair of side-by-side islands (QoL: no running back through the chain).
--   * world tile (i, j): the Park keeps its MapData coords (0..39, 0..29); island g at grid (gx, gz) is centred on
--     (20 + gx*DX, 15 + gz*DZ). World studs = (i - 20) * S, so Island.toWorld / Controller.toWorld stay valid.
--   * tile codes: 0 void, 1 grass, 2 path, 3 water, 4 alt top (sand/stone/tilled/rock), 5 bridge deck
--   * an island only exists while it is unlocked (World.setOpen(state.island)); a bridge needs both ends open
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local Map = require(Shared:WaitForChild("MapData"))
local Defs = require(Shared:WaitForChild("Defs"))
local Data = require(Shared:WaitForChild("IslandData"))

local World = {}
local DX, DZ = 44, 34
local PCX, PCY = Map.COLS / 2, Map.ROWS / 2
World.DX, World.DZ = DX, DZ

local function needOf(id)
	for k, d in Defs.ISLANDS do if d.id == id then return k end end
	return 99
end

-- ---------------------------------------------------------------- islands
local ORDER = { "park", "garden", "castle", "bridge", "forest", "mine", "desert", "expedition", "echo" }
World.list, World.byId = {}, {}
for _, id in ORDER do
	local isl
	if id == "park" then
		isl = { id = "park", name = "THE PARK", gx = 0, gz = 0, W = Map.COLS, N = Map.ROWS, oi = 0, oj = 0, need = 1, park = true, props = {} }
		local codes = {}
		for j = 0, Map.ROWS - 1 do codes[j] = {}; for i = 0, Map.COLS - 1 do codes[j][i] = Map.tile(i, j) end end
		isl.codes = codes
		isl.H = function(i, j) return Map.height(i, j) end
		for _, o in Map.objects do table.insert(isl.props, { kind = o[1], x = o[2] / Map.PX, z = o[3] / Map.PX, park = true }) end
	else
		local d = Data[id]
		isl = { id = id, name = d.name, gx = d.gx, gz = d.gz, W = d.W, N = d.N, need = needOf(id), data = d, props = {} }
		isl.oi = PCX + d.gx * DX - math.floor(d.W / 2)
		isl.oj = PCY + d.gz * DZ - math.floor(d.N / 2)
		local codes, hs = {}, {}
		for j = 0, d.N - 1 do
			codes[j], hs[j] = {}, {}
			for i = 0, d.W - 1 do
				codes[j][i] = tonumber(string.sub(d.rows[j + 1], i + 1, i + 1))
				hs[j][i] = tonumber(string.sub(d.H[j + 1], i + 1, i + 1))
			end
		end
		isl.codes = codes
		isl.H = function(i, j) local r = hs[j - isl.oj]; return r and r[i - isl.oi] or 0 end
		for _, p in d.props do
			table.insert(isl.props, { kind = p[1], x = isl.oi + p[2], z = isl.oj + p[3], rot = p[4], bob = p[5], parts = p[6] })
		end
	end
	isl.cx, isl.cz = isl.oi + isl.W / 2, isl.oj + isl.N / 2
	table.insert(World.list, isl); World.byId[id] = isl
end

local function rawIsland(isl, i, j)
	local r = isl.codes[j - isl.oj]
	return r and r[i - isl.oi] or 0
end
local owner = {}   -- tile key -> island (land tiles only)
local function key(i, j) return (j + 500) * 2000 + i + 500 end
for _, isl in World.list do
	for j = isl.oj, isl.oj + isl.N - 1 do
		for i = isl.oi, isl.oi + isl.W - 1 do
			if rawIsland(isl, i, j) ~= 0 then
				if owner[key(i, j)] then warn("[World] overlap at " .. i .. "," .. j) end
				owner[key(i, j)] = isl
			end
		end
	end
end
function World.islandOfTile(i, j) return owner[key(i, j)] end

-- ---------------------------------------------------------------- props that block (footprint radius in tiles)
local WALK_PROPS = { rails = true, tilledrow = true, flowers = true, bones = true, twigs = true, pier = true, footbridge = true, log = true, vine = true }
for _, isl in World.list do
	for _, p in isl.props do
		if isl.park then p.r = if p.kind == "arch" then 0 else 0.8
		elseif WALK_PROPS[p.kind] then p.r = 0
		else
			local mnx, mxx, mnz, mxz = math.huge, -math.huge, math.huge, -math.huge
			local c, s = math.cos(p.rot or 0), math.sin(p.rot or 0)
			for _, q in p.parts do
				if q[6] - q[3] / 2 < 0.9 and q[13] == 0 then   -- parts touching the ground
					local x, z = q[5] * c + q[7] * s, -q[5] * s + q[7] * c
					mnx = math.min(mnx, x - q[2] / 2); mxx = math.max(mxx, x + q[2] / 2)
					mnz = math.min(mnz, z - q[4] / 2); mxz = math.max(mxz, z + q[4] / 2)
				end
			end
			p.r = if mnx == math.huge then 0 else math.clamp(math.min(mxx - mnx, mxz - mnz) / 2, 0.15, 2.6)
			if mnx ~= math.huge then p.box = { p.x + mnx, p.x + mxx, p.z + mnz, p.z + mxz } end
		end
	end
	-- small props scattered onto a bigger one (a cactus on the pyramid, a bush in the keep) are removed
	local list = {}
	for _, p in isl.props do if p.box then table.insert(list, p) end end
	table.sort(list, function(a, b) return (a.box[2] - a.box[1]) * (a.box[4] - a.box[3]) > (b.box[2] - b.box[1]) * (b.box[4] - b.box[3]) end)
	for k, big in list do
		if big.dropped then continue end
		for q = k + 1, #list do
			local sm = list[q]
			if sm.dropped then continue end
			local b, c = big.box, sm.box
			if c[2] > b[1] + 0.15 and c[1] < b[2] - 0.15 and c[4] > b[3] + 0.15 and c[3] < b[4] - 0.15 then sm.dropped = true end
		end
	end
end
-- inside a prop's ground footprint (+ margin, tiles)
function World.inProp(x, z, margin)
	for _, isl in World.list do
		for _, p in isl.props do
			local b = p.box
			if b and not p.dropped and x > b[1] - margin and x < b[2] + margin and z > b[3] - margin and z < b[4] + margin then return p end
		end
	end
	return nil
end
local function propNear(x, z, rad)
	for _, isl in World.list do
		for _, p in isl.props do
			if not p.dropped and (p.x - x) ^ 2 + (p.z - z) ^ 2 < (rad + (p.r or 0.8)) ^ 2 and (p.r or 0) > 0 then return true end
		end
	end
	return false
end

-- ---------------------------------------------------------------- bridges between grid neighbours
local bridgeTiles = {}   -- "i,j" -> bridge
World.bridges = {}
local function walk(isl, i, j)
	local c = rawIsland(isl, i, j)
	return (c == 1 or c == 2 or c == 4) and isl.H(i, j) == 0
end
local function makeBridge(a, b)
	-- axis: X when side by side, Z when stacked. u runs from a to b, v across the lane.
	local alongX = a.gz == b.gz
	local function T(u, v) if alongX then return u, v else return v, u end end
	local lo, hi
	if alongX then lo, hi = math.max(a.oj, b.oj) + 2, math.min(a.oj + a.N, b.oj + b.N) - 4
	else lo, hi = math.max(a.oi, b.oi) + 2, math.min(a.oi + a.W, b.oi + b.W) - 4 end
	local mid = math.floor(((if alongX then a.cz + b.cz else a.cx + b.cx) / 2)) - 1   -- lane v0..v0+1 straddles the midline
	local dir = if (alongX and b.gx > a.gx) or (not alongX and b.gz > a.gz) then 1 else -1
	-- score every lane: water / hills at a landing are fatal, a Park prop in the way is fatal (approved layout),
	-- an island prop in the way costs a little (it gets cleared), and distance from the middle breaks ties
	local best, bestScore
	for o = 0, 16 do
		for _, sgn in { 1, -1 } do
			local v0 = mid + o * sgn
			if v0 < lo or v0 > hi or (o == 0 and sgn < 0) then continue end
			local score, ea, sb = o * 0.5, nil, nil
			for v = v0, v0 + 1 do
				local u = math.floor(if alongX then a.cx else a.cz)
				local last
				for _ = 1, 40 do local i, j = T(u, v); if rawIsland(a, i, j) ~= 0 then last = u end; u += dir end
				local u2 = math.floor(if alongX then b.cx else b.cz)
				local first
				for _ = 1, 40 do local i, j = T(u2, v); if rawIsland(b, i, j) ~= 0 then first = u2 end; u2 -= dir end
				if not last or not first then score = math.huge; break end
				for k = 0, 2 do
					for _, side in { { a, last - k * dir }, { b, first + k * dir } } do
						local i, j = T(side[2], v)
						if not walk(side[1], i, j) then score += (if k < 2 then 1000 else 20) end
						for _, p in side[1].props do
							if (p.r or 0) > 0 and (p.x - i - 0.5) ^ 2 + (p.z - j - 0.5) ^ 2 < (p.r + 0.7) ^ 2 then score += if p.park then 1000 else 3 end
						end
					end
				end
				ea = if ea then (if dir > 0 then math.max(ea, last) else math.min(ea, last)) else last
				sb = if sb then (if dir > 0 then math.min(sb, first) else math.max(sb, first)) else first
			end
			if score < 1000 and (not bestScore or score < bestScore) then best, bestScore = { v0 = v0, ea = ea, sb = sb }, score end
		end
	end
	if not best then warn("[World] no bridge lane " .. a.id .. " -> " .. b.id); return end
	local br = { a = a, b = b, alongX = alongX, dir = dir, v0 = best.v0, tiles = {} }
	-- deck tiles (only over void), ordered from a to b; the path stripes 3 tiles inland on both sides
	local u = best.ea + dir
	while u ~= best.sb do
		for v = best.v0, best.v0 + 1 do
			local i, j = T(u, v)
			if not World.islandOfTile(i, j) then
				local t = { i = i, j = j, u = math.abs(u - best.ea), br = nil }
				table.insert(br.tiles, t); bridgeTiles[key(i, j)] = br
			end
		end
		u += dir
	end
	br.len = math.abs(best.sb - best.ea) - 1
	for _, t in br.tiles do t.sag = 0.9 * math.sin(math.pi * (t.u - 0.5) / br.len) end   -- rope sag, studs
	br.landA = { T(best.ea, best.v0) }; br.landB = { T(best.sb, best.v0) }
	-- walk targets (game px) on the lane centre, one tile inland on each side
	do
		local ax, ay = T(best.ea - dir + 0.5, best.v0 + 1)
		local bx, by = T(best.sb + dir + 0.5, best.v0 + 1)
		br.pa = { ax * 16, ay * 16 }; br.pb = { bx * 16, by * 16 }
	end
	br.stripe = {}
	for k = 0, 2 do
		for v = best.v0, best.v0 + 1 do
			for _, side in { { a, best.ea - k * dir }, { b, best.sb + k * dir } } do
				local i, j = T(side[2], v)
				local isl = side[1]
				table.insert(br.stripe, { i, j })
				if rawIsland(isl, i, j) == 1 or rawIsland(isl, i, j) == 4 then isl.codes[j - isl.oj][i - isl.oi] = 2 end
			end
		end
	end
	table.insert(World.bridges, br)
	return br
end
for _, a in World.list do
	for _, b in World.list do
		if (b.gx == a.gx + 1 and b.gz == a.gz) or (b.gz == a.gz + 1 and b.gx == a.gx) then
			-- build from the earlier-unlocked island towards the later one
			if a.need <= b.need then makeBridge(a, b) else makeBridge(b, a) end
		end
	end
end
-- island props standing on a landing stripe are cleared (the Park keeps its approved props; lanes avoid them)
for _, br in World.bridges do
	for _, isl in { br.a, br.b } do
		if isl.park then continue end
		for _, p in isl.props do
			if (p.r or 0) <= 0 then continue end
			for _, t in br.stripe do
				if (p.x - t[1] - 0.5) ^ 2 + (p.z - t[2] - 0.5) ^ 2 < (p.r + 0.7) ^ 2 then p.dropped = true end
			end
		end
	end
end

-- walkable decks on props (the Bridge island's footbridge over the river, the pier): every tile under a flat plank
-- becomes walkable at the plank's height (studs), so the bird climbs the hump instead of hitting the water
local decks = {}   -- key -> { isl, h }
local DECK_KINDS = { footbridge = true, pier = true }
for _, isl in World.list do
	if isl.park then continue end
	for _, p in isl.props do
		if not DECK_KINDS[p.kind] or p.dropped then continue end
		local i0, j0 = math.floor(p.x), math.floor(p.z)
		local c0 = rawIsland(isl, i0, j0)
		local base = if c0 == 3 then -0.2 elseif c0 == 2 then -0.4 else isl.H(i0, j0) * 2.4
		local c, s = math.cos(p.rot or 0), math.sin(p.rot or 0)
		for _, q in p.parts do
			if q[3] > 0.3 or (q[2] < 0.8 and q[4] < 0.8) then continue end   -- flat planks only
			local x, z = q[5] * c + q[7] * s, -q[5] * s + q[7] * c
			local hx = math.abs(q[2] / 2 * c) + math.abs(q[4] / 2 * s) + 0.08   -- planks have hairline gaps
			local hz = math.abs(q[2] / 2 * s) + math.abs(q[4] / 2 * c) + 0.08
			local top = base + (q[6] + q[3] / 2) * 4
			for j = math.floor(p.z + z - hz), math.floor(p.z + z + hz) do
				for i = math.floor(p.x + x - hx), math.floor(p.x + x + hx) do
					if math.abs(i + 0.5 - p.x - x) <= hx and math.abs(j + 0.5 - p.z - z) <= hz then
						local k = key(i, j)
						if not decks[k] or decks[k].h < top then decks[k] = { isl = isl, h = top } end
					end
				end
			end
		end
	end
end
function World.deckH(i, j)
	local d = decks[key(i, j)]
	if d then return d.h end
	local br = bridgeTiles[key(i, j)]
	if br then for _, t in br.tiles do if t.i == i and t.j == j then return -t.sag end end end
	return nil
end

-- ---------------------------------------------------------------- open state
World.open = 1
function World.setOpen(n) World.open = n end
function World.isOpen(isl) return World.open >= isl.need end
function World.bridgeOpen(br) return World.isOpen(br.a) and World.isOpen(br.b) end

-- raw (ignores unlocks) and live tile queries
function World.rawTile(i, j)
	local isl = World.islandOfTile(i, j)
	if isl then return rawIsland(isl, i, j), isl end
	local br = bridgeTiles[key(i, j)]
	if br then return 5, nil, br end
	return 0
end
function World.tile(i, j)
	local dk = decks[key(i, j)]
	if dk and World.isOpen(dk.isl) then return 5 end
	local isl = World.islandOfTile(i, j)
	if isl then return if World.isOpen(isl) then rawIsland(isl, i, j) else 0 end
	local br = bridgeTiles[key(i, j)]
	if br and World.bridgeOpen(br) then return 5 end
	return 0
end
function World.height(i, j)
	local isl = World.islandOfTile(i, j)
	return if isl then isl.H(i, j) else 0
end
-- island whose box is nearest a world tile point (camera / zone)
function World.nearest(x, z)
	local best, bd = World.list[1], math.huge
	for _, isl in World.list do
		if not World.isOpen(isl) then continue end
		local d = (math.max(0, math.abs(x - isl.cx) - isl.W / 2)) ^ 2 + (math.max(0, math.abs(z - isl.cz) - isl.N / 2)) ^ 2
		if d < bd then best, bd = isl, d end
	end
	return best
end
-- a free walkable tile near the island centre (for "Go to ...")
function World.arrival(isl)
	local best, bd
	for j = isl.oj, isl.oj + isl.N - 1 do
		for i = isl.oi, isl.oi + isl.W - 1 do
			local c = rawIsland(isl, i, j)
			if (c == 1 or c == 2 or c == 4) and isl.H(i, j) == 0 and not propNear(i + 0.5, j + 0.5, 1) then
				local d = (i + 0.5 - isl.cx) ^ 2 + (j + 0.5 - isl.cz - 3) ^ 2
				if not bd or d < bd then best, bd = { i, j }, d end
			end
		end
	end
	return best[1] + 0.5, best[2] + 0.5
end
-- the neighbour this island unlocks from (open earlier, adjacent; its bridge is built first)
function World.sourceBridge(isl)
	local best
	for _, br in World.bridges do
		if br.b == isl and (not best or br.a.need > best.a.need) and br.a.need < isl.need then best = br end
	end
	return best
end
return World
