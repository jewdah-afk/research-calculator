--!nonstrict
-- Registers every built-in bonus source with Balance. Add new content the same way:
--   Balance.register("myFeature", "cash", function(data, ctx) return log10Bonus end)
-- Required once by OrbFormulas, so it runs on server and client alike.

local Config = require(script.Parent.OrbConfig)
local Balance = require(script.Parent.Balance)
local Events = require(script.Parent.Events)
local Runes = require(script.Parent.Runes)

local Bonuses = {}

-- Weather: active weathers add to luck/cash/gems; storm level and superstorm events scale them.
local function weatherScale(data, ctx)
	return 1 + 0.1 * (data.stormLevel or 0) + Events.weatherBoost(ctx)
end

local function weatherSum(data, field)
	local s = 0
	for i, w in Config.Weather do
		if (data.weatherDuration[i] or 0) > 0 then
			s += w[field]
		end
	end
	return s
end

Balance.register("weather_luck", "luck", function(data, ctx)
	if data.mechanics < 5 then
		return 0
	end
	return math.log10(1 + weatherSum(data, "luck") * weatherScale(data, ctx))
end)
Balance.register("weather_gems", "gems", function(data, ctx)
	if data.mechanics < 5 then
		return 0
	end
	return math.log10(1 + weatherSum(data, "diamonds") * weatherScale(data, ctx))
end)
-- (weather "money" stays display-only, matching the original game's balance)

-- Starter runes 1-5: small capped cash boosts
Balance.register("runes_cash", "cash", function(data)
	return math.log10(1 + Runes.totals(data).cash)
end)

-- Admin events
for _, stat in Balance.STATS do
	Balance.register("events_" .. stat, stat, function(_, ctx)
		return Events.activeStrength(ctx, stat)
	end)
end

return Bonuses
