--!native
--!optimize 2
-- Orbiting projectiles with persistent pixel trails, integrated with velocity-Verlet on a
-- radial spring (so orbits wobble when the player moves, instead of being rigidly locked) and
-- an optional Lissajous radius modulation. VS use: King Bible (round), Unholy Vespers
-- (larger, more books, faster), Peachone/Ebony Wings bird loops (lissajous figure-8).
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(w: number, h: number, opts: any?)
	opts = opts or {}
	local self = setmetatable({
		trail = Core.canvas(w, h), count = opts.count or 3, radius = opts.radius or 24,
		omega = opts.omega or 3.2, stiff = opts.stiffness or 80, damp = opts.damping or 10,
		liss = opts.lissajous, fade = opts.fade or 0.82, color = opts.color or { 120, 160, 255 },
		t = 0, cx = w / 2, cy = h / 2, bodies = {},
	}, M)
	for i = 1, self.count do
		local a = (i - 1) / self.count * math.pi * 2
		self.bodies[i] = { x = self.cx + math.cos(a) * self.radius, y = self.cy + math.sin(a) * self.radius, vx = 0, vy = 0 }
	end
	return self
end

function M:setCentre(x: number, y: number) self.cx, self.cy = x, y end

function M:step(dt: number)
	self.t += dt
	local sub = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / sub
	for _ = 1, sub do
		for i, b in self.bodies do
			local a = self.t * self.omega + (i - 1) / self.count * math.pi * 2
			local rx, ry = self.radius, self.radius
			if self.liss then ry = self.radius * math.sin(a * self.liss) end
			local tx, ty = self.cx + math.cos(a) * rx, self.cy + math.sin(a) * ry
			local ax = (tx - b.x) * self.stiff - b.vx * self.damp
			local ay = (ty - b.y) * self.stiff - b.vy * self.damp
			b.vx += ax * h; b.vy += ay * h
			b.x += b.vx * h; b.y += b.vy * h
		end
	end
	Core.fade(self.trail, self.fade)
	local col = self.color
	for _, b in self.bodies do
		local px, py = b.px or b.x, b.py or b.y
		Core.line(self.trail, px, py, b.x, b.y, col[1], col[2], col[3])
		b.px, b.py = b.x, b.y
	end
end

function M:render(c)
	local src, dst = self.trail.buf, c.buf
	for o = 0, c.w * c.h * 4 - 1, 4 do
		local a = buffer.readu8(src, o + 3) / 255
		local r, g, b = math.floor(buffer.readu8(src, o) * a), math.floor(buffer.readu8(src, o + 1) * a), math.floor(buffer.readu8(src, o + 2) * a)
		if r + g + b > 0 then Core.add(c, (o // 4) % c.w, (o // 4) // c.w, r, g, b) end
	end
	for _, b in self.bodies do
		for dy = -1, 1 do for dx = -1, 1 do Core.set(c, math.floor(b.x) + dx, math.floor(b.y) + dy, 255, 255, 255, 255) end end
	end
end

return M
