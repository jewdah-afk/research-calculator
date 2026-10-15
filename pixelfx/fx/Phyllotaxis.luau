--!native
--!optimize 2
-- Vogel's phyllotaxis (1979): seed k at angle k·137.508°, radius c·√k. Used as a bloom
-- that unfurls over time (each seed scales in after its index delay) and rotates slowly.
-- VS use: Celestial Dusting flower drops, Garlic petal ring, Arcana card sigil, level-up burst.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M
local GOLDEN = math.rad(137.50776)

function M.new(opts: any?)
	opts = opts or {}
	return setmetatable({
		count = opts.count or 180, spacing = opts.spacing or 2.1, t = 0, spin = opts.spin or 0.4,
		grow = opts.grow or 0.9, lut = Core.ramp(opts.ramp or { {255,240,180}, {255,170,60}, {200,60,40} }),
	}, M)
end

function M:step(dt: number) self.t += dt end

function M:render(c, cx: number, cy: number)
	local n = self.count
	for k = 1, n do
		local appear = math.clamp((self.t - (k / n) * self.grow) / 0.12, 0, 1)
		if appear > 0 then
			local a = k * GOLDEN + self.t * self.spin
			local r = self.spacing * math.sqrt(k)
			local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
			local col = self.lut[math.floor(k / n * 255) + 1]
			local R, G, B = bit32.band(col, 255), bit32.band(bit32.rshift(col, 8), 255), bit32.band(bit32.rshift(col, 16), 255)
			local size = (0.6 + 0.8 * (k / n)) * appear
			-- tiny 4-point petal: centre + cross arms scaled by size
			Core.add(c, math.floor(x), math.floor(y), R, G, B)
			if size > 0.8 then
				for _, d in { {1,0}, {-1,0}, {0,1}, {0,-1} } do
					Core.add(c, math.floor(x) + d[1], math.floor(y) + d[2], R // 2, G // 2, B // 2)
				end
			end
		end
	end
end

return M
