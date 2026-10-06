--!nonstrict
-- First-time-player tutorial. Each step has a hint, the UI element it points at, and a `done`
-- check against player data. The server advances data.tutorialStep when a check passes
-- (so progress saves and can't be faked); the client only draws the hint.

local F = require(script.Parent.OrbFormulas)
local Big = require(script.Parent.Big)

local Tutorial = {}

Tutorial.STEPS = {
	{ text = "Your orbs drop on the MEGA BOARD with everyone else's. Where yours land pays CASH: check the slot multipliers!", target = "Board",
		done = function(d) return Big.gt(d.totalMoney, 40) end },
	{ text = "A stand just popped up! Walk to the CASH stand and buy your first CASH BOOST.", target = "UpgradesPanel",
		done = function(d) return d.mainLevels[1] >= 1 end },
	{ text = "LUCKY ORB makes rarer, more valuable orbs drop. Grab a level.", target = "UpgradesPanel",
		done = function(d) return d.mainLevels[2] >= 1 end },
	{ text = "Walk to the SPAWNERS stand and unlock a second spawner for more orbs.", target = "UpgradesPanel",
		done = function(d) return d.spawnersUnlocked >= 2 end },
	{ text = "Blue gems drop sometimes. Collect 50 GEMS, then unlock REBIRTH at the GEMS stand.", target = "UpgradesPanel",
		done = function(d) return d.mechanics >= 1 end },
	{ text = "REBIRTH resets your cash for a permanent x2 luck. Use the REBIRTH stand or button once!", target = "Dock",
		done = function(d) return d.rebirths >= 1 end },
	{ text = "You're set! More stands appear as you get close to them. Rarities, tiers and weather keep going forever!", target = nil,
		done = function(d) return d.timePlayed - (d.tutorialDoneAt or d.timePlayed) >= 0 end, final = true },
}

function Tutorial.current(data)
	local i = data.tutorialStep or 0
	return i > 0 and Tutorial.STEPS[i] or nil, i
end

-- Advance as many steps as are already satisfied. Returns true if the step changed.
function Tutorial.advance(data): boolean
	local changed = false
	for _ = 1, #Tutorial.STEPS do
		local step, i = Tutorial.current(data)
		if not step or step.final then
			break
		end
		local ok, done = pcall(step.done, data)
		if ok and done then
			data.tutorialStep = i + 1
			changed = true
		else
			break
		end
	end
	return changed
end

function Tutorial.finish(data)
	data.tutorialStep = 0
end

Tutorial._F = F
return Tutorial
