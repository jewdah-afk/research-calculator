-- Exports the full World tile grid (all islands open) as JSON for concept pages: lune run tools/dump_world.luau > world.json (from roblox/)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
-- math.noise stand-in (Roblox Perlin isn't in Lune): smooth value noise in about -0.5..0.5
local function h3(x, y, z) local n = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return n - math.floor(n) end
local function noise(x, y, z) y = y or 0; z = z or 0
	local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z); local u, v, w = x - xi, y - yi, z - zi
	local s = function(t) return t * t * (3 - 2 * t) end; u, v, w = s(u), s(v), s(w)
	local function L(a, b, t) return a + (b - a) * t end
	local c = {}
	for dz = 0, 1 do for dy = 0, 1 do for dx = 0, 1 do c[dx + dy * 2 + dz * 4] = h3(xi + dx, yi + dy, zi + dz) end end end
	return L(L(L(c[0], c[1], u), L(c[2], c[3], u), v), L(L(c[4], c[5], u), L(c[6], c[7], u), v), w) - 0.5 end
local M = setmetatable({ noise = noise }, { __index = math })
local serde = require("@lune/serde")
local SHARED = "src/shared/"
local cache = {}
local DEFS_ISLANDS = {}
for _, id in { "park", "garden", "castle", "bridge", "forest", "mine", "desert", "expedition", "echo" } do table.insert(DEFS_ISLANDS, { id = id }) end
local function mod(name)
	if cache[name] then return cache[name] end
	if name == "Defs" then cache[name] = { ISLANDS = DEFS_ISLANDS }; return cache[name] end
	local src = fs.readFile(SHARED .. name .. ".luau")
	local fakeShared = setmetatable({}, { __index = function(_, k) return { __mod = k } end })
	fakeShared.WaitForChild = function(_, k) return { __mod = k } end
	local game = { GetService = function() return { WaitForChild = function() return fakeShared end } end }
	local env = setmetatable({ game = game, require = function(m) return mod(m.__mod) end,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, math = M }, { __index = getfenv() })
	local f = luau.load(src, { debugName = name, environment = env })
	cache[name] = f()
	return cache[name]
end
local World = mod("World")
World.setOpen(99)
local out = { islands = {}, tiles = {}, props = {} }
local mi, mj, xi, xj = math.huge, math.huge, -math.huge, -math.huge
for _, isl in World.all and World.all() or World.list do
	table.insert(out.islands, { id = isl.id, cx = isl.cx, cz = isl.cz, W = isl.W, N = isl.N })
end
for _, isl in World.list do
	mi = math.min(mi, isl.oi); mj = math.min(mj, isl.oj); xi = math.max(xi, isl.oi + isl.W); xj = math.max(xj, isl.oj + isl.N)
	for _, p in isl.props do table.insert(out.props, { p.kind, p.x, p.z, isl.id }) end
end
mi -= 12; mj -= 12; xi += 12; xj += 12
out.oi, out.oj, out.W, out.N = mi, mj, xi - mi, xj - mj
for j = mj, xj - 1 do
	local row, hrow = {}, {}
	for i = mi, xi - 1 do
		local c = World.tile(i, j)
		table.insert(row, tostring(c))
		table.insert(hrow, tostring(math.clamp(math.floor(((c ~= 0 and World.height(i, j)) or 0) + 0.5), 0, 9)))
	end
	table.insert(out.tiles, table.concat(row) .. "|" .. table.concat(hrow))
end
print(serde.encode("json", out))
