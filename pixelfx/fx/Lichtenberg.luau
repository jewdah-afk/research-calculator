--!native
--!optimize 2
-- Dielectric breakdown model (Niemeyer-Pietronero-Wiesmann 1984) for Lightning Ring / Thunder Loop.
-- Grows a branching discharge from a strike point, adding a candidate cell with probability
-- ~ phi^eta, where phi is the electric potential.
-- Higher eta = straighter bolt. The bolt then glows for `life` seconds and decays.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(w: number, h: number, opts: any?)
	opts = opts or {}
	local self = setmetatable({
		w = w, h = h, eta = opts.eta or 4, steps = opts.steps or 400,
		seed = opts.seed or 1, life = opts.life or 0.35, t = 0,
		bolt = buffer.create(w * h), age = Core.field(w, h),
		lut = Core.ramp(opts.ramp or { {0,0,0}, {40,60,200}, {140,180,255}, {255,255,255} }),
	}, M)
	return self
end

-- Strike from (sx,sy) toward the bottom edge. Fast DBM (Kim & Lin 2007): the potential at each
-- candidate is a sum of point-charge terms (1 - R/r) over bolt cells, updated incrementally
-- when a cell is added, so no Laplace solve is needed. A ground term pulls toward y = h.
function M:strike(sx: number, sy: number)
	local w, h, bolt = self.w, self.h, self.bolt
	buffer.fill(bolt, 0, 0)
	local rand = Core.rng(self.seed)
	self.seed += 7919
	local R = 0.5
	local cands: { [number]: number } = {} -- cell index -> potential
	local cells = {}
	local function addCell(i)
		buffer.writeu8(bolt, i, 1)
		table.insert(cells, i)
		cands[i] = nil
		local ix, iy = i % w, i // w
		for c, v in cands do
			local r = math.sqrt((c % w - ix) ^ 2 + (c // w - iy) ^ 2)
			cands[c] = v + (1 - R / r)
		end
		for _, d in { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {-1,1}, {1,-1}, {-1,-1} } do
			local nx, ny = ix + d[1], iy + d[2]
			if nx > 0 and ny > 0 and nx < w - 1 and ny < h - 1 then
				local n = ny * w + nx
				if buffer.readu8(bolt, n) == 0 and cands[n] == nil then
					local v = 0
					for _, b in cells do
						v += 1 - R / math.sqrt((n % w - b % w) ^ 2 + (n // w - b // w) ^ 2)
					end
					cands[n] = v
				end
			end
		end
	end
	addCell(sy * w + sx)
	for _ = 1, self.steps do
		local lo, hi = math.huge, -math.huge
		for _, v in cands do lo = math.min(lo, v); hi = math.max(hi, v) end
		local span = math.max(hi - lo, 1e-6)
		local total, list = 0, {}
		for c, v in cands do
			-- normalised charge potential, blended with the ground field
			local p = ((v - lo) / span) ^ self.eta * ((c // w) / (h - 1) + 0.02) ^ 3
			total += p
			table.insert(list, c); table.insert(list, p)
		end
		if total <= 0 then break end
		local r, pick = rand() * total, list[1]
		for k = 1, #list, 2 do r -= list[k + 1]; if r <= 0 then pick = list[k]; break end end
		addCell(pick)
		if pick // w >= h - 2 then break end
	end
	for i = 0, w * h - 1 do
		buffer.writef32(self.age, i * 4, if buffer.readu8(bolt, i) == 1 then 1 else 0)
	end
	self.t = 0
end

function M:step(dt: number)
	self.t += dt
	local k = math.max(0, 1 - dt / self.life)
	local w, h, age = self.w, self.h, self.age
	-- Decay plus a 1-px glow bleed so the core reads white and the halo blue.
	for y = 1, h - 2 do
		for x = 1, w - 2 do
			local i = (y * w + x) * 4
			local v = buffer.readf32(age, i)
			local n = (buffer.readf32(age, i - 4) + buffer.readf32(age, i + 4)
				+ buffer.readf32(age, i - w * 4) + buffer.readf32(age, i + w * 4)) * 0.25
			buffer.writef32(age, i, math.max(v, n * 0.6) * k)
		end
	end
end

function M:render(c)
	Core.shade(c, self.age, self.lut)
end

return M
