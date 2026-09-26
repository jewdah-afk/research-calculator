--!strict
--[[
	Boards: the leaderboards (server/Leaderboards stores them, the client's RANKS window shows them) and how their
	values read.

	    Boards.list                     { Board } in the order the RANKS window shows them
	    Boards.get(key) -> Board?
	    Boards.format(x)                a big number the leaderboard way (below)
	    Boards.show(board, key) -> string    a stored OrderedDataStore key as the board shows it
	    Boards.keyOf(board, value) -> number  the value (a TowerNum, a number, or a numeric string) as a stored key

	A board's kind says how its value is kept (OrderedDataStore holds whole numbers only):
	    big    any size (TowerNum.sortKey: a whole number that sorts like the value; read back with fromSortKey)
	    count  a whole number as it is (milestones, achievements)
	    time   whole seconds, read as "3d 4h", "5h 12m", "42m"
	    robux  whole Robux, read as "R$ 1,234"

	The leaderboard number format (Boards.format):
	    below 1,000        57, 12.5
	    below e3,003       the -illion suffixes with 3 figures: 1.23K, 45.6NoNog, 150NoNogNoce (1e3003 is the first
	                       value past the names)
	    from e3,003        scientific: e plus the exponent with commas: e3,003, e10,000, e100,000
	    exponent >= 1e6    the exponent suffixed with 4 figures: e1.000M, e198.2M; again for its own exponent
	                       (ee3,500, ee198.2M); taller towers than that read as TowerNum's 10^^ height
]]

local TowerNum = require(game:GetService("ReplicatedStorage"):WaitForChild("TowerNum")) :: any

export type Board = { key: string, title: string, kind: string, layer: string? }

local Boards = {}

-- every stat (the layers in the tree's own order, then the extra stats). layer: the node whose hue the tab takes
Boards.list = {
	{ key = "points", title = "Points", kind = "big" },
	{ key = "m", title = "Milestones", kind = "count", layer = "m" },
	{ key = "p", title = "Prestige Points", kind = "big", layer = "p" },
	{ key = "sp", title = "Super Prestige", kind = "big", layer = "sp" },
	{ key = "mm", title = "Meta-Milestones", kind = "count", layer = "mm" },
	{ key = "pb", title = "Prestige Boost", kind = "big", layer = "pb" },
	{ key = "hp", title = "Hyper Prestige", kind = "big", layer = "hp" },
	{ key = "ap", title = "Atomic Prestige", kind = "big", layer = "ap" },
	{ key = "t", title = "Transcend", kind = "big", layer = "t" },
	{ key = "hb", title = "Hyper Boost", kind = "big", layer = "hb" },
	{ key = "pe", title = "Prestige Energy", kind = "big", layer = "pe" },
	{ key = "se", title = "Super Energy", kind = "big", layer = "se" },
	{ key = "pp", title = "Prestige Power", kind = "big", layer = "pp" },
	{ key = "ep", title = "Exotic Prestige", kind = "big", layer = "ep" },
	{ key = "mp", title = "Multiversal Prestige", kind = "big", layer = "mp" },
	{ key = "em", title = "Extra-Milestones", kind = "count", layer = "em" },
	{ key = "pm", title = "Prestige Milestones", kind = "count", layer = "pm" },
	{ key = "pep", title = "Pr-Exotic Prestige", kind = "big", layer = "pep" },
	{ key = "cp", title = "Corruption", kind = "big", layer = "cp" },
	{ key = "cm", title = "Corrupted Milestones", kind = "count", layer = "cm" },
	{ key = "ex", title = "Exploration", kind = "big", layer = "ex" },
	{ key = "ach", title = "Achievements", kind = "count", layer = "ach" },
	{ key = "time", title = "Playtime", kind = "time" },
	{ key = "robux", title = "Robux Spent", kind = "robux" },
} :: { Board }

local byKey: { [string]: Board } = {}
for _, b in Boards.list do byKey[b.key] = b end
function Boards.get(key: string): Board?
	return byKey[key]
end

-- ------------------------------------------------------------------------------------------------------ format
local FIRST = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local UNITS = { "", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
local TENS = { "", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog" }
local HUNDREDS = { "", "Ce", "Dce", "Tce", "Qace", "Qice", "Sxce", "Spce", "Occe", "Noce" }
local MAX_K = 1000 -- 1e3000 (NoNogNoce); 1e3003 is the first value past the names
-- the suffix of 1e(3k), 1 <= k <= MAX_K
local function suffix(k: number): string
	if k <= 10 then return FIRST[k] end
	local n = k - 1 -- the -illion index: 1e(3n + 3)
	return UNITS[n % 10 + 1] .. TENS[math.floor(n / 10) % 10 + 1] .. HUNDREDS[math.floor(n / 100) % 10 + 1]
end
Boards.suffix = suffix

local function commas(n: number): string
	local s = string.format("%d", n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (string.gsub(out, "^,", ""))
end
-- m in [1, 1000) with `sig` significant figures (never "1000")
local function mant(m: number, sig: number): (string, boolean)
	local dec = sig - 1 - math.floor(math.log10(m) + 1e-9)
	dec = math.max(0, dec)
	local s = string.format("%." .. dec .. "f", m)
	if tonumber(s) :: number >= 1000 then return "", false end
	return s, true
end
-- 1000 <= x < 1e3003 (x a TowerNum): mantissa + suffix
local function suffixed(x: any, sig: number): string
	local e = math.floor(TowerNum.toNumber(TowerNum.log10(x)) + 1e-9)
	local k = math.floor(e / 3)
	local m = TowerNum.toNumber(TowerNum.div(x, TowerNum.pow(10, 3 * k)))
	local s, ok = mant(m, sig)
	if not ok then
		k += 1
		s = (mant(m / 1000, sig))
	end
	if k > MAX_K then return "e" .. commas(3 * k) end
	return s .. suffix(k)
end
-- the exponent E (>= 3003) after an "e": commas below 1e6, suffixed with 4 figures below 1e3003, then again
local function expo(E: any, depth: number): string
	if TowerNum.lt(E, 1e6) then return commas(math.floor(TowerNum.toNumber(E) + 1e-9)) end
	if TowerNum.lt(E, "1e3003") then return suffixed(E, 4) end
	if depth >= 4 then return TowerNum.format(E) end
	return "e" .. expo(TowerNum.log10(E), depth + 1)
end

function Boards.format(value: any): string
	local ok, x = pcall(TowerNum.from, value)
	if not ok or TowerNum.isNaN(x) or TowerNum.sign(x) <= 0 then return "0" end
	if TowerNum.isInf(x) then return "Infinity" end
	if TowerNum.lt(x, 1000) then
		local n = TowerNum.toNumber(x)
		if n == math.floor(n) then return tostring(math.floor(n)) end
		return (string.gsub(string.gsub(string.format("%.2f", n), "0+$", ""), "%.$", ""))
	end
	if TowerNum.lt(x, "1e3003") then return suffixed(x, 3) end
	-- towers of more than a handful of tens read as their height
	if TowerNum.slog10(x) >= 6 then return TowerNum.format(x) end
	return "e" .. expo(TowerNum.log10(x), 0)
end

local function duration(s: number): string
	s = math.max(0, math.floor(s))
	local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
	if d > 0 then return string.format("%dd %dh", d, h) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end
Boards.duration = duration

-- ------------------------------------------------------------------------------------------------------ keys
-- the stored whole number for a value (0 for nothing, never negative)
function Boards.keyOf(board: Board, value: any): number
	if board.kind == "big" then
		local ok, x = pcall(TowerNum.from, value)
		if not ok then return 0 end
		return TowerNum.sortKey(x)
	end
	local n = tonumber(value) or 0
	if n ~= n or n == math.huge then return 0 end
	return math.max(0, math.floor(n))
end

-- a stored key as the board shows it
function Boards.show(board: Board, key: number): string
	if board.kind == "big" then
		if key <= 0 then return "0" end
		-- the middle of the key's range (fromSortKey gives its bottom, a hair under the value that was stored)
		return Boards.format(TowerNum.fromSortKey(key + 0.5))
	elseif board.kind == "time" then
		return duration(key)
	elseif board.kind == "robux" then
		return "R$ " .. commas(key)
	end
	return commas(key)
end

return Boards
