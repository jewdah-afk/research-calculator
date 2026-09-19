--!strict
--[[
	Sim/Experience.luau -- the XP curve, gem value and level progression.

	Oracle: research/vs/core_loop.md.
	  * §5, the piecewise formula:
	        n <= 20:        base(n) = 5 + 10 * (n - 1)
	        21 <= n <= 40:  base(n) = 195 + 13 * (n - 20)
	        n >= 41:        base(n) = 455 + 16 * (n - 40)
	        req(n) = base(n) + (600 if n == 20 else 2400 if n == 40 else 0)
	    Every constant is read from CoreLoop.data.experienceCurve
	    (firstLevelUpXp, incrementTier1..3, breakpoints[].level/extraXp).
	    195 and 455 are not stored fields: they are base(20) and base(40),
	    which the walk below reaches by accumulating the earlier tiers, so
	    the curve continues past the Lv100 table with the same arithmetic.
	  * §3: "Gem values are scaled by the Growth stat (base 100% = x1.0)".
	    gemValue = baseXp * growth.
	  * §3, gem merging: a merged gem "can grant several levels at once", so
	    addXp carries overflow across as many levels as the amount buys.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require. addXp therefore types its state
	as the three PlayerState fields it touches; a full Types.PlayerState is a
	structural subtype of that shape and passes unchanged.
]]

local CoreLoop = require("../Data/CoreLoop")

-- The subset of Types.PlayerState that addXp reads and writes.
export type XpState = {
	level: number,
	xp: number,
	xpToNext: number,
}

local curve = CoreLoop.data.experienceCurve
local curveMap = (curve :: any) :: { [string]: any }

-- Breakpoint levels ascending, with their one-off surcharges, straight from Data.
local boundaries: { number } = {}
local surcharges: { number } = {}
do
	local sorted: { { level: number, extraXp: number } } = {}
	for _, bp in curve.breakpoints :: { any } do
		table.insert(sorted, { level = bp.level, extraXp = bp.extraXp })
	end
	table.sort(sorted, function(a, b)
		return a.level < b.level
	end)
	for _, bp in sorted do
		table.insert(boundaries, bp.level)
		table.insert(surcharges, bp.extraXp)
	end
end

-- Per-level increment for each tier: tier i runs up to boundaries[i], the
-- last tier is open-ended. The Data names them incrementTier1, 2, 3, so
-- they are read by composed key rather than spelled out.
local increments: { number } = {}
for i = 1, #boundaries + 1 do
	local value = curveMap["incrementTier" .. i]
	if type(value) ~= "number" then
		error(string.format("Experience: CoreLoop.experienceCurve.incrementTier%d is missing", i))
	end
	increments[i] = value
end

local firstLevelUpXp: number = curve.firstLevelUpXp

local function assertLevel(level: number, context: string)
	if type(level) ~= "number" or level < 1 or level ~= math.floor(level) then
		error(string.format("Experience.%s: level must be an integer >= 1, got %s", context, tostring(level)))
	end
end

local Experience = {}

-- XP required to go from `level` to `level + 1` (core_loop.md §5).
function Experience.xpToNext(level: number): number
	assertLevel(level, "xpToNext")
	local xp = firstLevelUpXp
	local from = 1
	for i = 1, #boundaries do
		local boundary = boundaries[i]
		if level <= boundary then
			local surcharge = if level == boundary then surcharges[i] else 0
			return xp + increments[i] * (level - from) + surcharge
		end
		xp += increments[i] * (boundary - from)
		from = boundary
	end
	return xp + increments[#boundaries + 1] * (level - from)
end

-- Total XP spent reaching level + 1 from level 1: sum of xpToNext(1..level).
-- Matches the cumulativeXp column of the Lv100 table (core_loop.md §5).
function Experience.cumulativeAt(level: number): number
	assertLevel(level, "cumulativeAt")
	local total = 0
	for n = 1, level do
		total += Experience.xpToNext(n)
	end
	return total
end

-- XP a gem is worth to this player (core_loop.md §3: Growth multiplies).
function Experience.gemValue(baseXp: number, growth: number): number
	return baseXp * growth
end

-- Adds XP, carrying overflow across as many levels as it buys. Mutates
-- level / xp / xpToNext and returns the number of levels gained; the
-- caller re-derives Stats.effective and queues that many level-up offers.
function Experience.addXp(state: XpState, amount: number): number
	if type(amount) ~= "number" or amount < 0 or amount ~= amount then
		error(string.format("Experience.addXp: amount must be a number >= 0, got %s", tostring(amount)))
	end
	state.xp += amount
	local gained = 0
	while state.xp >= state.xpToNext do
		state.xp -= state.xpToNext
		state.level += 1
		gained += 1
		state.xpToNext = Experience.xpToNext(state.level)
	end
	return gained
end

return Experience
