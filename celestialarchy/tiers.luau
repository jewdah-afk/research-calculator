--!strict
-- Governor colour projection: tier (luminance band) + reserved hue -> exact sRGB.
-- Every colour the level render uses comes from this table; nothing is hand-picked.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function toLin(c: number) return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4 end
local function toSrgb(c: number) return if c <= 0.0031308 then c * 12.92 else 1.055 * c ^ (1 / 2.4) - 0.055 end
local function lum(r: number, g: number, b: number) return 0.2126 * r + 0.7152 * g + 0.0722 * b end
local function hsv(h: number, s: number): (number, number, number)
	local i = math.floor(h / 60) % 6
	local f = h / 60 - math.floor(h / 60)
	local p, q, t = 1 - s, 1 - s * f, 1 - s * (1 - f)
	local tbl = { { 1, t, p }, { q, 1, p }, { p, 1, t }, { p, q, 1 }, { t, p, 1 }, { 1, p, q } }
	local c = tbl[i + 1]
	return c[1], c[2], c[3]
end

-- hit luminance Y exactly; if the hue cannot reach Y at saturation s, lower s until it can
local function project(h: number, s: number, Y: number)
	local sat = s
	for _ = 1, 64 do
		local r, g, b = hsv(h, sat)
		r, g, b = toLin(r), toLin(g), toLin(b)
		local k = Y / lum(r, g, b)
		if math.max(r, g, b) * k <= 1 + 1e-9 then
			r, g, b = r * k, g * k, b * k
			local function hex(c: number) return string.format("%02x", math.floor(toSrgb(math.min(1, c)) * 255 + 0.5)) end
			local R, G, B = toLin(tonumber(hex(r), 16) / 255), toLin(tonumber(hex(g), 16) / 255), toLin(tonumber(hex(b), 16) / 255)
			return { hex = "#" .. hex(r) .. hex(g) .. hex(b), Y = lum(R, G, B), sat = sat, wanted = s }
		end
		sat -= s / 64
	end
	return { hex = "#ffffff", Y = 1, sat = 0, wanted = s }
end

local TIERS = {
	{ id = "T0", role = "Player", lo = 0.86, hi = 0.95, h = 0, s = 0 },
	{ id = "T1", role = "Next collision threat", lo = 0.68, hi = 0.80, h = 0, s = 0.9 },
	{ id = "T2", role = "Safe gap", lo = 0.50, hi = 0.62, h = 120, s = 0.9 },
	{ id = "T3", role = "Reward", lo = 0.36, hi = 0.48, h = 50, s = 0.9 },
	{ id = "T4", role = "Walls and structure", lo = 0.16, hi = 0.28, h = -1, s = 0.25 },
	{ id = "T5", role = "Speed, rims, ghosts", lo = 0.06, hi = 0.14, h = -1, s = 0.25 },
	{ id = "T6", role = "Distant and ambient", lo = 0.01, hi = 0.04, h = -1, s = 0.25 },
}
local AMBIENT = { 195, 265, 305 } -- cyan, violet, magenta, rotated per level
local BANDS = { 0.45, 0.70, 1.00 } -- cel bands for face interiors

local out = { tiers = {}, levels = {}, checks = {} }
for _, t in TIERS do
	local Y = (t.lo + t.hi) / 2
	local entry = { id = t.id, role = t.role, lo = t.lo, hi = t.hi, Y = Y }
	if t.h >= 0 then
		entry.edge = project(t.h, t.s, Y)
		-- interiors may be darker: keep the reserved hue saturated by staying under 70% of its max luminance
		local r, g, b = hsv(t.h, t.s)
		entry.interior = project(t.h, t.s, math.min(Y * 0.45, 0.7 * lum(toLin(r), toLin(g), toLin(b))))
	end
	table.insert(out.tiers, entry)
end
for L = 1, 10 do
	local h = AMBIENT[(L - 1) % 3 + 1]
	local lv = { L = L, hue = h, T4 = {}, T5 = project(h, 0.25, 0.10), T6 = project(h, 0.25, 0.025), void = project(h, 0.25, 0.004) }
	-- face interiors sit under the T4 edge band (interiors may be darker); edges carry T4
	for i, k in BANDS do lv.T4[i] = project(h, 0.25, 0.10 * k) end
	lv.T4edge = project(h, 0.25, 0.22)
	lv.fine = project(h, 0.25, 0.10 * 0.70 + 0.025) -- fine voxel line: <= 0.03 contrast over mid band
	table.insert(out.levels, lv)
end

local function check(name: string, ok: boolean, note: string)
	table.insert(out.checks, { name = name, ok = ok, note = note })
end
for _, t in out.tiers do
	if t.edge then
		local e = t.edge
		check(t.id .. " edge Y in band", e.Y >= t.lo and e.Y <= t.hi, string.format("Y=%.3f, sat %.2f of %.2f wanted", e.Y, e.sat, e.wanted))
	end
end
local okAmb = true
for _, lv in out.levels do
	for _, c in { lv.T4edge, lv.T5, lv.T6 } do if c.sat > 0.25 + 1e-9 then okAmb = false end end
	if math.abs(lv.fine.Y - lv.T4[2].Y) > 0.0305 then okAmb = false end
end
check("Ambient sat <= 0.25, fine-line contrast <= 0.03", okAmb, "all 10 level palettes")
local order = true
for i = 2, #out.tiers do if out.tiers[i].Y >= out.tiers[i - 1].Y then order = false end end
check("Tier luminance strictly ordered T0 > ... > T6", order, "band midpoints")
-- Sensory Overload wall bands: saturated voxel bricks. Hues sit outside the reserved windows
-- (danger 0+-15, gold 50+-15, safe 120+-15) so red/gold/green stay owned by T1/T3/T2.
local GAME_HUES = { 100, 305, 270, 185, 25, 220 }
out.walls = {}
local hueOk = true
for _, h in GAME_HUES do
	local r, g, b = hsv(h, 0.88)
	for _, c in { 0, 50, 120 } do
		local dh = math.abs(((h - c + 180) % 360) - 180)
		if dh <= 15 then hueOk = false end
	end
	table.insert(out.walls, { h = h, rgb = { math.floor(r * 255), math.floor(g * 255), math.floor(b * 255) }, Y = lum(toLin(r), toLin(g), toLin(b)) })
end
check("Wall hues clear of reserved hue windows", hueOk, "lime, magenta, violet, cyan, orange, blue")
fs.writeFile("tiers.json", serde.encode("json", out))
for _, c in out.checks do print(if c.ok then "ok  " else "FAIL", c.name, c.note) end
