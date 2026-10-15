--!native
--!optimize 2
-- FABRIK inverse kinematics (Aristidou & Lasenby 2011) for a pinned chain chasing a target,
-- with per-joint angle limits so it curls instead of kinking. VS use: Bloody Tear lash
-- shape, Peachone tether, chained enemy (Mudman), Vento Sacro dash trail spine.
local Core = require(script and script.Parent.Parent.Core or "../Core")
local M = {}
M.__index = M

function M.new(n: number, segLen: number, opts: any?)
	opts = opts or {}
	local self = setmetatable({ n = n, len = segLen, iters = opts.iterations or 6,
		maxBend = math.rad(opts.maxBend or 35), pts = {}, color = opts.color or { 220, 40, 60 } }, M)
	for i = 1, n do self.pts[i] = { x = 0, y = i * segLen } end
	return self
end

function M:solve(rootX: number, rootY: number, tx: number, ty: number)
	local p, L = self.pts, self.len
	for _ = 1, self.iters do
		p[self.n].x, p[self.n].y = tx, ty
		for i = self.n - 1, 1, -1 do
			local dx, dy = p[i].x - p[i + 1].x, p[i].y - p[i + 1].y
			local d = math.max(math.sqrt(dx * dx + dy * dy), 1e-6)
			p[i].x, p[i].y = p[i + 1].x + dx / d * L, p[i + 1].y + dy / d * L
		end
		p[1].x, p[1].y = rootX, rootY
		for i = 2, self.n do
			local dx, dy = p[i].x - p[i - 1].x, p[i].y - p[i - 1].y
			local a = math.atan2(dy, dx)
			if i > 2 then
				local prev = math.atan2(p[i - 1].y - p[i - 2].y, p[i - 1].x - p[i - 2].x)
				local rel = (a - prev + math.pi) % (2 * math.pi) - math.pi
				a = prev + math.clamp(rel, -self.maxBend, self.maxBend)
			end
			p[i].x, p[i].y = p[i - 1].x + math.cos(a) * L, p[i - 1].y + math.sin(a) * L
		end
	end
end

function M:step(_dt: number) end

-- Tapered render: thickness shrinks from root to tip, tip gets a white hot pixel.
function M:render(c)
	local p, col = self.pts, self.color
	for i = 1, self.n - 1 do
		local thick = math.max(0, math.floor((1 - i / self.n) * 2.5))
		for o = -thick, thick do
			Core.line(c, p[i].x + o * 0.5, p[i].y - o * 0.5, p[i + 1].x + o * 0.5, p[i + 1].y - o * 0.5, col[1], col[2], col[3])
		end
	end
	Core.set(c, math.floor(p[self.n].x), math.floor(p[self.n].y), 255, 255, 255, 255)
end

return M
