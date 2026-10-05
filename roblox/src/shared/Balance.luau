--!nonstrict
-- Bonus budget: the rule that keeps the game infinitely playable no matter what gets added.
--
-- CORE progression (upgrades, rebirths, tiers, rarity bonus, skill tree) is the backbone and is
-- applied in full. Everything layered on top — weather, storm level, admin events, future
-- content, gamepasses — is a BONUS SOURCE. Bonus sources are summed (in log10 space) per stat
-- and then soft-capped against a budget that scales with the player's own core progress:
--
--   budget(stat) = max(floor, share * coreLog(stat))
--   applied      = raw                               if raw <= budget
--                = budget + (raw - budget) ^ 0.5     otherwise (diminishing returns)
--
-- So a new feature can make players faster by a bounded factor but can never leapfrog the
-- core curve or make old content trivial. To add content: register a source, done.

local Balance = {}

Balance.STATS = { "cash", "luck", "gems" }

-- floor: minimum log10 headroom (0.6 = x4); share: fraction of core progress allowed as bonus
Balance.BUDGET = {
	cash = { floor = 0.9, share = 0.2 },
	luck = { floor = 0.9, share = 0.2 },
	gems = { floor = 0.6, share = 0.5 },
}

local sources = {} -- [id] = { stat = "cash", fn = function(data, ctx) -> log10 }
local order = {}

-- Register a bonus source. fn(data, ctx) returns a log10 contribution (>= 0 recommended).
function Balance.register(id: string, stat: string, fn)
	assert(Balance.BUDGET[stat], "unknown stat " .. tostring(stat))
	if not sources[id] then
		table.insert(order, id)
	end
	sources[id] = { stat = stat, fn = fn }
end

function Balance.unregister(id: string)
	sources[id] = nil
	local i = table.find(order, id)
	if i then
		table.remove(order, i)
	end
end

-- Context shared by every source (server/client both set it): active global events, time.
Balance.ctx = { events = {}, now = 0 }

function Balance.setEvents(list)
	Balance.ctx.events = list or {}
end

function Balance.rawBonusLog(data, stat: string): (number, { [string]: number })
	local total, parts = 0, {}
	for _, id in order do
		local s = sources[id]
		if s.stat == stat then
			local ok, v = pcall(s.fn, data, Balance.ctx)
			if ok and type(v) == "number" and v == v and v ~= math.huge then
				v = math.max(v, 0)
				parts[id] = v
				total += v
			end
		end
	end
	return total, parts
end

function Balance.budget(stat: string, coreLog: number): number
	local b = Balance.BUDGET[stat]
	return math.max(b.floor, b.share * math.max(coreLog, 0))
end

function Balance.softcap(raw: number, budget: number): number
	if raw <= budget then
		return raw
	end
	return budget + math.sqrt(raw - budget)
end

-- Applied bonus (log10) for a stat given the player's core log for that stat.
function Balance.bonusLog(data, stat: string, coreLog: number): number
	local raw = Balance.rawBonusLog(data, stat)
	return Balance.softcap(raw, Balance.budget(stat, coreLog))
end

-- For UI: breakdown of what's feeding a stat and whether it's being capped.
function Balance.explain(data, stat: string, coreLog: number)
	local raw, parts = Balance.rawBonusLog(data, stat)
	local budget = Balance.budget(stat, coreLog)
	return { raw = raw, applied = Balance.softcap(raw, budget), budget = budget, parts = parts }
end

return Balance
