--!nonstrict
-- Admin-droppable global events. Each event type is a bonus source (see Balance), so stacking
-- any number of events can never break progression: they go through the bonus budget.
--
-- An active event instance: { id = "cash2x", startedAt = unixTime, endsAt = unixTime, by = "admin name" }

local Events = {}

-- strength is log10 of the multiplier (0.301 = x2). stat: cash | luck | gems | spawn | weather
Events.TYPES = {
	cash2x = { name = "DOUBLE CASH", stat = "cash", strength = math.log10(2), color = { 124, 255, 91 }, minutes = 30 },
	luck2x = { name = "DOUBLE LUCK", stat = "luck", strength = math.log10(2), color = { 255, 225, 74 }, minutes = 30 },
	luck5x = { name = "LUCKY HOUR", stat = "luck", strength = math.log10(5), color = { 255, 184, 0 }, minutes = 60 },
	gemRain = { name = "GEM RAIN", stat = "gems", strength = math.log10(3), color = { 127, 227, 255 }, minutes = 20 },
	frenzy = { name = "ORB FRENZY", stat = "spawn", strength = 0.5, color = { 255, 61, 110 }, minutes = 15 }, -- spawners 50% faster
	superstorm = { name = "SUPERSTORM", stat = "weather", strength = 1, color = { 227, 166, 255 }, minutes = 20 }, -- +1x weather effects
}

local function active(ctx, stat)
	local now = ctx.now or os.time()
	local total = 0
	for _, ev in ctx.events or {} do
		local def = Events.TYPES[ev.id]
		if def and def.stat == stat and (ev.endsAt or 0) > now then
			total += def.strength
		end
	end
	return total
end
Events.activeStrength = active

-- Spawner speed multiplier (not a log stat; capped hard at 2x so the server loop stays sane)
function Events.spawnSpeed(ctx): number
	return math.min(1 + active(ctx, "spawn"), 2)
end

function Events.weatherBoost(ctx): number
	return active(ctx, "weather")
end

function Events.validate(id: string, minutes: number?)
	local def = Events.TYPES[id]
	if not def then
		return nil, "unknown event"
	end
	local m = math.clamp(math.floor(minutes or def.minutes), 1, 24 * 60)
	return def, m
end

return Events
