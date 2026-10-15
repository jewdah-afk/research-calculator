--!native
--!optimize 2
-- Jump Flooding Algorithm (Rong & Tan 2006) distance field from a sprite's alpha mask, giving
-- an outline + soft glow of any width in O(n log n). VS use: selected level-up card icon,
-- evolved weapon glow, co-op player outlines, chest item reveal halo.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

-- mask: buffer w*h u8 (non-zero = inside sprite)
function M.new(w: number, h: number, mask: buffer, opts: any?)
	opts = opts or {}
	local self = setmetatable({
		w = w, h = h, mask = mask, width = opts.width or 2, glow = opts.glow or 6,
		color = opts.color or { 255, 220, 90 }, t = 0, dist = Core.field(w, h),
	}, M)
	self:build()
	return self
end

function M:build()
	local w, h, mask = self.w, self.h, self.mask
	local seed = buffer.create(w * h * 4) -- packed nearest seed index+1, 0 = none
	for i = 0, w * h - 1 do
		if buffer.readu8(mask, i) ~= 0 then buffer.writeu32(seed, i * 4, i + 1) end
	end
	local nxt = buffer.create(w * h * 4)
	local step = 1
	while step * 2 < math.max(w, h) do step *= 2 end
	while step >= 1 do
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local best, bd = buffer.readu32(seed, (y * w + x) * 4), math.huge
				if best > 0 then
					local s = best - 1
					bd = (s % w - x) ^ 2 + (s // w - y) ^ 2
				end
				for dy = -step, step, step do
					for dx = -step, step, step do
						local nx, ny = x + dx, y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h then
							local s1 = buffer.readu32(seed, (ny * w + nx) * 4)
							if s1 > 0 then
								local s = s1 - 1
								local d = (s % w - x) ^ 2 + (s // w - y) ^ 2
								if d < bd then bd, best = d, s1 end
							end
						end
					end
				end
				buffer.writeu32(nxt, (y * w + x) * 4, best)
			end
		end
		seed, nxt = nxt, seed
		step //= 2
	end
	for i = 0, w * h - 1 do
		local s = buffer.readu32(seed, i * 4)
		local d = if s > 0 then math.sqrt(((s - 1) % w - i % w) ^ 2 + ((s - 1) // w - i // w) ^ 2) else 1e9
		buffer.writef32(self.dist, i * 4, d)
	end
end

function M:step(dt: number) self.t += dt end

-- Adds the outline (solid) and breathing glow (falloff) around the sprite, outside the mask only.
function M:render(c)
	local w, h, col = self.w, self.h, self.color
	local breathe = 0.75 + 0.25 * math.sin(self.t * math.pi * 2 / 2.8)
	for i = 0, w * h - 1 do
		if buffer.readu8(self.mask, i) == 0 then
			local d = buffer.readf32(self.dist, i * 4)
			local k = 0
			if d <= self.width then k = 1
			elseif d <= self.width + self.glow then k = (1 - (d - self.width) / self.glow) ^ 2 * 0.6 * breathe end
			if k > 0 then
				Core.add(c, i % w, i // w, math.floor(col[1] * k), math.floor(col[2] * k), math.floor(col[3] * k))
			end
		end
	end
end

return M
