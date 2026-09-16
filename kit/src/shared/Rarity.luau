--!nonstrict
--[[
	Rarity — the roller.

	Every pet declares `oneIn`. Luck divides it, so 2x luck really is 2x. Pets are
	tested rarest-first and the first hit wins; if nothing hits you get the
	commonest pet in the pool. This is the same shape the RNG/aura games use, and
	it has two properties worth keeping:

		* it is honest (a displayed 1-in-5,000 is a real 1-in-5,000 at 1x luck)
		* it is cheap (one RNG call per tier, ~6 tiers per roll)

	Everything here is pure, so it is unit-testable outside Roblox.

	One property worth knowing before you tune luck: because luck divides N and
	the result is floored to a minimum of 1, high luck erases the bottom tiers
	entirely (at 5x luck a 1-in-4 pet becomes 1-in-1 and the 1-in-1 pet below it
	stops appearing at all). That is the intended feel — luck should make commons
	vanish — but it means luck is a much bigger lever than it looks, so check any
	change in tools/economy-calculator.html before shipping it.
]]

local Rarity = {}

local rng = Random.new()

-- Sorts a pet list rarest-first without mutating the caller's table.
local function rarestFirst(pool)
	local sorted = table.clone(pool)
	table.sort(sorted, function(a, b)
		return a.oneIn > b.oneIn
	end)
	return sorted
end

function Rarity.effectiveOneIn(oneIn, luck)
	luck = math.max(luck or 1, 1)
	return math.max(1, math.floor(oneIn / luck))
end

--[[
	Rolls one pet out of `pool`.
	pool  : array of { id, oneIn, income, color }
	luck  : multiplier, 1 = no luck
	source: optional Random, pass one in for deterministic tests
]]
function Rarity.roll(pool, luck, source)
	assert(type(pool) == "table" and #pool > 0, "Rarity.roll: empty pool")
	local generator = source or rng
	local sorted = rarestFirst(pool)

	for _, pet in ipairs(sorted) do
		local odds = Rarity.effectiveOneIn(pet.oneIn, luck)
		if odds <= 1 or generator:NextInteger(1, odds) == 1 then
			return pet
		end
	end

	return sorted[#sorted]
end

-- Classic weighted roll, kept for anyone who prefers weights to 1-in-N.
function Rarity.rollWeighted(pool, source)
	local generator = source or rng
	local total = 0
	for _, entry in ipairs(pool) do
		total += entry.weight or 1
	end
	local ticket = generator:NextNumber() * total
	local running = 0
	for _, entry in ipairs(pool) do
		running += entry.weight or 1
		if ticket <= running then
			return entry
		end
	end
	return pool[#pool]
end

-- "1 in 12,500" for UI.
function Rarity.chanceText(oneIn, luck)
	local odds = Rarity.effectiveOneIn(oneIn, luck)
	local text = tostring(odds)
	local formatted = text
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return "1 in " .. formatted
end

-- Expected rolls to see a pet at a given luck. Used by the economy calculator.
function Rarity.expectedRolls(oneIn, luck)
	return Rarity.effectiveOneIn(oneIn, luck)
end

return Rarity
