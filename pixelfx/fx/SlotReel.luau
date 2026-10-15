--!native
--!optimize 2
-- Treasure chest roulette reel. Strip of icons scrolls with a critically-damped spring that
-- lands exactly on the target index after `spin` seconds (we solve the start velocity so the
-- stop is predetermined; the result is chosen by game logic first, the reel just tells it).
-- Motion blur: icons are drawn smeared vertically by speed; landing gives a squash bounce.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

-- icons: array of Canvas (all icon×icon); height: visible window in px
function M.new(icons: { any }, icon: number, height: number, opts: any?)
	opts = opts or {}
	return setmetatable({
		icons = icons, icon = icon, height = height, pos = 0, t = 0, spin = opts.spin or 2.4,
		laps = opts.laps or 4, from = 0, to = 0, settle = 0,
	}, M)
end

-- Ease: quintic out to the target then a decaying overshoot (spring tail) of ~6% of a cell.
local function ease(u) return 1 - (1 - u) ^ 5 end

function M:land(index: number)
	local n = #self.icons
	self.from = self.pos
	local base = math.floor(self.pos / n) * n
	self.to = base + self.laps * n + (index - 1)
	self.t = 0
end

function M:step(dt: number)
	self.t += dt
	local u = math.min(1, self.t / self.spin)
	local p = self.from + (self.to - self.from) * ease(u)
	if u >= 1 then
		local tail = self.t - self.spin
		p = self.to + 0.06 * math.exp(-tail * 9) * math.sin(tail * 28)
	end
	self.vel = (p - self.pos) / math.max(dt, 1e-4)
	self.pos = p
end

function M:render(c, ox: number, oy: number)
	local n, s, icons = #self.icons, self.icon, self.icons
	local smear = math.clamp(math.abs(self.vel or 0) * 0.02, 0, 1) -- 0..1 of a cell
	local centre = oy + self.height // 2 - s // 2
	local first = math.floor(self.pos) - 2
	for k = first, first + 5 do
		local ico = icons[(k % n) + 1]
		local y0 = centre + math.floor((k - self.pos) * s)
		local taps = 1 + math.floor(smear * 4)
		for tap = 0, taps - 1 do
			local dy = math.floor(tap * smear * s / taps)
			local weight = 1 / taps
			for y = 0, s - 1 do
				local yy = y0 + y + dy
				if yy >= oy and yy < oy + self.height then
					-- edge darkening: cosine falloff toward the window top/bottom (drum curvature)
					local edge = math.cos(((yy - oy) / self.height - 0.5) * math.pi) ^ 0.7
					for x = 0, s - 1 do
						local o = (y * s + x) * 4
						if buffer.readu8(ico.buf, o + 3) > 0 then
							local k2 = weight * edge
							Core.add(c, ox + x, yy, math.floor(buffer.readu8(ico.buf, o) * k2),
								math.floor(buffer.readu8(ico.buf, o + 1) * k2), math.floor(buffer.readu8(ico.buf, o + 2) * k2))
						end
					end
				end
			end
		end
	end
end

return M
