--!native
--!optimize 2
-- Data-oriented enemy crowd: struct-of-arrays in buffers, one loop for everything.
--   * Flow field: one breadth-first search from the player over a coarse grid each refresh; every
--     enemy follows the field toward the player. The cost is per grid cell, not per enemy.
--     Solid cells (props) are routed around.
--   * Separation: spatial hash (cell = 2 × radius). Each enemy is only pushed by enemies in its 3×3
--     neighbouring cells, so cost ~ O(n).
--   * Lean (a damped spring on velocity), per-enemy animation phase, hit-flash timer, facing flip.
--   * Render: blits baked frames into one canvas (one WritePixelsBuffer per frame in Roblox).
--     Far or dense enemies drop to every other animation frame (LOD).
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(cap: number, worldW: number, worldH: number, opts: any?)
	opts = opts or {}
	local cell = opts.flowCell or 8
	local gw, gh = math.ceil(worldW / cell), math.ceil(worldH / cell)
	local f32 = function() return buffer.create(cap * 4) end
	return setmetatable({
		cap = cap, n = 0, W = worldW, H = worldH,
		x = f32(), y = f32(), vx = f32(), vy = f32(), hp = f32(), phase = f32(), flash = f32(), kind = buffer.create(cap),
		speed = opts.speed or 30, radius = opts.radius or 5, push = opts.push or 25,
		cell = cell, gw = gw, gh = gh, dist = buffer.create(gw * gh * 2), solid = buffer.create(gw * gh),
		hashCell = (opts.radius or 5) * 2, heads = {}, nextIdx = buffer.create(cap * 4),
		queue = buffer.create(gw * gh * 4),
	}, M)
end

function M:spawn(x: number, y: number, kind: number?, hp: number?): number?
	if self.n >= self.cap then return nil end
	local i = self.n; self.n += 1
	buffer.writef32(self.x, i * 4, x); buffer.writef32(self.y, i * 4, y)
	buffer.writef32(self.vx, i * 4, 0); buffer.writef32(self.vy, i * 4, 0)
	buffer.writef32(self.hp, i * 4, hp or 10); buffer.writef32(self.flash, i * 4, 0)
	buffer.writef32(self.phase, i * 4, (i * 0.618034) % 1)
	buffer.writeu8(self.kind, i, kind or 1)
	return i
end

-- Swap-remove keeps the arrays dense (no holes to skip).
function M:kill(i: number)
	local last = self.n - 1
	for _, b in { self.x, self.y, self.vx, self.vy, self.hp, self.phase, self.flash } do
		buffer.writef32(b, i * 4, buffer.readf32(b, last * 4))
	end
	buffer.writeu8(self.kind, i, buffer.readu8(self.kind, last))
	self.n = last
end

function M:hit(i: number, dmg: number, kx: number, ky: number)
	buffer.writef32(self.hp, i * 4, buffer.readf32(self.hp, i * 4) - dmg)
	buffer.writef32(self.flash, i * 4, 0.06) -- 60 ms, the middle of the game's 30/60/120 ms hit-flash timings
	buffer.writef32(self.vx, i * 4, buffer.readf32(self.vx, i * 4) + kx)
	buffer.writef32(self.vy, i * 4, buffer.readf32(self.vy, i * 4) + ky)
end

function M:setSolid(cx: number, cy: number, v: boolean)
	buffer.writeu8(self.solid, cy * self.gw + cx, if v then 1 else 0)
end

-- BFS from the player's cell. dist is u16 (65535 = unreached).
function M:refreshFlow(px: number, py: number)
	local gw, gh, dist, q, solid = self.gw, self.gh, self.dist, self.queue, self.solid
	buffer.fill(dist, 0, 255)
	local s = math.clamp(math.floor(py / self.cell), 0, gh - 1) * gw + math.clamp(math.floor(px / self.cell), 0, gw - 1)
	buffer.writeu16(dist, s * 2, 0)
	local head, tail = 0, 1
	buffer.writeu32(q, 0, s)
	while head < tail do
		local c = buffer.readu32(q, head * 4); head += 1
		local d = buffer.readu16(dist, c * 2) + 1
		local cx, cy = c % gw, c // gw
		if cx > 0 then local nb = c - 1; if buffer.readu16(dist, nb * 2) == 65535 and buffer.readu8(solid, nb) == 0 then buffer.writeu16(dist, nb * 2, d); buffer.writeu32(q, tail * 4, nb); tail += 1 end end
		if cx < gw - 1 then local nb = c + 1; if buffer.readu16(dist, nb * 2) == 65535 and buffer.readu8(solid, nb) == 0 then buffer.writeu16(dist, nb * 2, d); buffer.writeu32(q, tail * 4, nb); tail += 1 end end
		if cy > 0 then local nb = c - gw; if buffer.readu16(dist, nb * 2) == 65535 and buffer.readu8(solid, nb) == 0 then buffer.writeu16(dist, nb * 2, d); buffer.writeu32(q, tail * 4, nb); tail += 1 end end
		if cy < gh - 1 then local nb = c + gw; if buffer.readu16(dist, nb * 2) == 65535 and buffer.readu8(solid, nb) == 0 then buffer.writeu16(dist, nb * 2, d); buffer.writeu32(q, tail * 4, nb); tail += 1 end end
	end
	self.px, self.py = px, py
end

local function flowDir(self, x, y)
	local gw, gh, dist = self.gw, self.gh, self.dist
	local cx, cy = math.clamp(math.floor(x / self.cell), 0, gw - 1), math.clamp(math.floor(y / self.cell), 0, gh - 1)
	local function d(ix, iy)
		if ix < 0 or iy < 0 or ix >= gw or iy >= gh then return 65535 end
		return buffer.readu16(dist, (iy * gw + ix) * 2)
	end
	local here = d(cx, cy)
	if here <= 1 then -- in or next to the player's cell: steer straight at the player
		local dx, dy = self.px - x, self.py - y
		local l = math.max(math.sqrt(dx * dx + dy * dy), 1e-3)
		return dx / l, dy / l
	end
	-- gradient (central difference), unreached cells clamped to here + 1
	local function dc(ix, iy) local v = d(ix, iy); return if v == 65535 then here + 1 else v end
	local gx, gy = dc(cx - 1, cy) - dc(cx + 1, cy), dc(cx, cy - 1) - dc(cx, cy + 1)
	local l = math.sqrt(gx * gx + gy * gy)
	if l < 1e-3 then return 0, 0 end
	return gx / l, gy / l
end

function M:step(dt: number)
	local n, X, Y, VX, VY = self.n, self.x, self.y, self.vx, self.vy
	-- build the spatial hash (linked lists through nextIdx)
	local hc, heads, nxt = self.hashCell, {}, self.nextIdx
	for i = 0, n - 1 do
		local k = math.floor(buffer.readf32(X, i * 4) / hc) * 73856093 + math.floor(buffer.readf32(Y, i * 4) / hc)
		buffer.writei32(nxt, i * 4, heads[k] or -1)
		heads[k] = i
	end
	local r2, push, spd = (self.radius * 2) ^ 2, self.push, self.speed
	for i = 0, n - 1 do
		local o = i * 4
		local x, y = buffer.readf32(X, o), buffer.readf32(Y, o)
		local dx, dy = flowDir(self, x, y)
		local sx, sy = 0, 0
		local hx, hy = math.floor(x / hc), math.floor(y / hc)
		for oy = -1, 1 do
			for ox = -1, 1 do
				local j = heads[(hx + ox) * 73856093 + hy + oy]
				while j and j >= 0 do
					if j ~= i then
						local ex, ey = x - buffer.readf32(X, j * 4), y - buffer.readf32(Y, j * 4)
						local d2 = ex * ex + ey * ey
						if d2 < r2 and d2 > 1e-4 then
							local d = math.sqrt(d2)
							local k = (1 - d / math.sqrt(r2)) / d
							sx += ex * k; sy += ey * k
						end
					end
					j = buffer.readi32(nxt, j * 4)
				end
			end
		end
		-- desired velocity = flow * speed + separation; spring the actual velocity toward it (knockback decays)
		local tvx, tvy = dx * spd + sx * push, dy * spd + sy * push
		local vx, vy = buffer.readf32(VX, o), buffer.readf32(VY, o)
		local k = math.min(1, dt * 8)
		vx += (tvx - vx) * k; vy += (tvy - vy) * k
		buffer.writef32(VX, o, vx); buffer.writef32(VY, o, vy)
		buffer.writef32(X, o, math.clamp(x + vx * dt, 0, self.W - 1))
		buffer.writef32(Y, o, math.clamp(y + vy * dt, 0, self.H - 1))
		local sp = math.sqrt(vx * vx + vy * vy)
		buffer.writef32(self.phase, o, (buffer.readf32(self.phase, o) + dt * sp / 24) % 1)
		buffer.writef32(self.flash, o, math.max(0, buffer.readf32(self.flash, o) - dt))
	end
end

-- Blit one sprite (opaque pixels only), mirrored if flip. Pixel-art: no filtering.
local function blit(c, s, ox, oy, flip)
	local w, h, cw, ch = s.w, s.h, c.w, c.h
	local sb, cb = s.buf, c.buf
	for y = 0, h - 1 do
		local ty = oy + y
		if ty >= 0 and ty < ch then
			for x = 0, w - 1 do
				local tx = ox + (if flip then w - 1 - x else x)
				if tx >= 0 and tx < cw then
					local px = buffer.readu32(sb, (y * w + x) * 4)
					if px >= 0x80000000 then buffer.writeu32(cb, (ty * cw + tx) * 4, px) end
				end
			end
		end
	end
end

-- sheets[kind] = EnemyBake result. Draws back-to-front by y (painter's sort) so lower enemies overlap higher ones.
function M:render(c, sheets, camX: number?, camY: number?)
	camX, camY = camX or 0, camY or 0
	local n, order = self.n, table.create(self.n)
	for i = 0, n - 1 do order[i + 1] = i end
	local Y = self.y
	table.sort(order, function(a, b) return buffer.readf32(Y, a * 4) < buffer.readf32(Y, b * 4) end)
	local lod = n > 600
	for _, i in order do
		local o = i * 4
		local sh = sheets[buffer.readu8(self.kind, i)]
		local x, y = buffer.readf32(self.x, o) - camX, buffer.readf32(Y, o) - camY
		local sx, sy = math.floor(x - sh.w / 2), math.floor(y - sh.h)
		if sx > -sh.w and sy > -sh.h and sx < c.w and sy < c.h then
			local nf = #sh.frames
			local f = math.floor(buffer.readf32(self.phase, o) * nf)
			if lod then f -= f % 2 end
			local spr = if buffer.readf32(self.flash, o) > 0 then sh.flash else sh.frames[f + 1]
			blit(c, spr, sx, sy, buffer.readf32(self.vx, o) < 0)
		end
	end
end

return M
