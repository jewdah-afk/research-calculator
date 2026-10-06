--!nonstrict
-- Progressive reveal for the world's upgrade stands and the matching HUD buttons.
-- A new player sees only the big plinko board; everything else pops in as they approach it.
--
--   hidden -> teaser (black silhouette with "???", once you're close) -> open (pops in)
--
-- "open" is sticky: it's saved in data.unlocked, so a stand never disappears again after a
-- reset (rebirth / tier / ascension wipe the resources the conditions look at).

local Big = require(script.Parent.Big)
local Config = require(script.Parent.OrbConfig)
local Prestige = require(script.Parent.Prestige)

local Unlocks = {}

local function sumMain(d)
	return d.mainLevels[1] + d.mainLevels[2] + d.mainLevels[3]
end

local function prestigeState(layerId, teaserGap)
	return function(d)
		local L = Prestige.byId[layerId]
		local st = d.prestige and d.prestige[layerId]
		if st and st.count > 0 then
			return "open"
		end
		local have = if L.source == "rebirths" then d.rebirths else d.prestige.ascension.lifetime
		local need = Prestige.requirement(d, layerId)
		if have >= need then
			return "open"
		elseif have >= need - teaserGap then
			return "teaser"
		end
		return "hidden"
	end
end

-- In world order, walking away from the board.
Unlocks.STANDS = {
	{
		id = "cash", name = "CASH", color = { 255, 214, 74 },
		state = function(d)
			if Big.gte(d.totalMoney, Config.Main.Money.baseCost) or sumMain(d) > 0 then
				return "open"
			end
			return if Big.gt(d.totalMoney, 0) then "teaser" else "hidden"
		end,
	},
	{
		id = "gems", name = "GEMS", color = { 92, 242, 255 },
		state = function(d)
			if Big.gt(d.totalDiamonds, 0) then
				return "open"
			end
			return if sumMain(d) >= 3 then "teaser" else "hidden"
		end,
	},
	{
		id = "spawners", name = "SPAWNERS", color = { 124, 255, 91 },
		state = function(d)
			if d.spawnersUnlocked > 1 or Big.gte(d.money, Config.Spawners.UnlockCost[2]) then
				return "open"
			end
			return if sumMain(d) >= 8 then "teaser" else "hidden"
		end,
	},
	{
		id = "rebirth", name = "REBIRTH", color = { 255, 170, 40 },
		state = function(d)
			if d.mechanics >= 1 or d.rebirths > 0 then
				return "open"
			end
			return if Big.gt(d.totalDiamonds, 0) then "teaser" else "hidden"
		end,
	},
	{
		id = "skills", name = "SKILLS & TIER", color = { 255, 92, 170 },
		state = function(d)
			if d.mechanics >= 4 or d.tiers > 0 then
				return "open"
			end
			-- tier mechanic needs 15 rebirths: tease 10 off
			return if d.rebirths >= 5 then "teaser" else "hidden"
		end,
	},
	{
		id = "weather", name = "STORM", color = { 167, 110, 255 },
		state = function(d)
			if d.mechanics >= 5 then
				return "open"
			end
			return if d.tiers >= 1 then "teaser" else "hidden"
		end,
	},
	-- beside the Mega Board: the Rune Altar (stand on its pad to auto-roll) and the gem Rune Forge
	{
		id = "runes", name = "RUNE ALTAR", color = { 120, 220, 255 }, pos = { -150, -150 }, pad = true,
		state = function(d)
			if Big.gte(d.totalMoney, 10) or (d.runes and d.runes.opened > 0) then
				return "open"
			end
			return if Big.gt(d.totalMoney, 0) then "teaser" else "hidden"
		end,
	},
	{
		id = "forge", name = "RUNE FORGE", color = { 92, 242, 255 }, pos = { 150, -150 },
		state = function(d)
			if Big.gt(d.totalDiamonds, 0) and d.runes and d.runes.opened > 0 then
				return "open"
			end
			return if d.runes and d.runes.opened > 0 then "teaser" else "hidden"
		end,
	},
	-- "close" = 10 rebirths / 5 AP off the requirement, so it pops up just before you can use it
	{ id = "ascension", name = "ASCENSION", color = { 227, 166, 255 }, state = prestigeState("ascension", 10) },
	{ id = "transcension", name = "TRANSCENSION", color = { 255, 255, 255 }, state = prestigeState("transcension", 5) },
}

Unlocks.byId = {}
for i, s in Unlocks.STANDS do
	s.index = i
	Unlocks.byId[s.id] = s
end

function Unlocks.state(d, id: string): string
	if d.unlocked and d.unlocked[id] then
		return "open"
	end
	return Unlocks.byId[id].state(d)
end

-- marks newly opened stands permanently; returns the ids that opened just now
function Unlocks.update(d): { string }
	d.unlocked = d.unlocked or {}
	local opened = {}
	for _, s in Unlocks.STANDS do
		if not d.unlocked[s.id] and s.state(d) == "open" then
			d.unlocked[s.id] = true
			table.insert(opened, s.id)
		end
	end
	return opened
end

return Unlocks
