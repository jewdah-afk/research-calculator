--!nonstrict
--[[
	StealService — the PvP layer that turns an idle game into a social one.

	Rules, all enforced server-side:
		* you cannot steal from your own plot
		* a freshly placed pet is protected for Config.Steal.graceSeconds
		* a shielded plot cannot be robbed at all (Robux sink)
		* each pad lock level adds hold time (coin sink)
		* the thief must physically carry the pet home to keep it
]]

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CarryService = require(script.Parent:WaitForChild("CarryService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local PlayerService = require(script.Parent:WaitForChild("PlayerService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local StealService = {}

local cooldowns = {}   -- [thief] = { [plotIndex] = os.clock() }

local function lockLevel(data, padIndex)
	return (data.locks or {})[tostring(padIndex)] or 0
end

function StealService.holdTime(ownerData, padIndex)
	return Config.Steal.baseHoldSeconds + lockLevel(ownerData, padIndex) * Config.Steal.holdPerLock
end

local function refreshPrompt(plot, pad)
	if not pad.uid then
		if pad.prompt then
			pad.prompt:Destroy()
			pad.prompt = nil
		end
		return
	end

	local ownerData = plot.owner and DataService.get(plot.owner)
	local hold = ownerData and StealService.holdTime(ownerData, pad.index) or Config.Steal.baseHoldSeconds

	local prompt = pad.prompt
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = "Pet"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad.part
		pad.prompt = prompt

		prompt.PromptButtonHoldBegan:Connect(function(thief)
			if plot.owner and plot.owner ~= thief then
				PlayerService.notify(plot.owner, ("%s is stealing from pad %d!")
					:format(thief.DisplayName, pad.index), "bad")
				Remotes.event(Remotes.Names.StealProgress):FireClient(plot.owner, pad.index, true)
			end
		end)

		prompt.PromptButtonHoldEnded:Connect(function()
			if plot.owner then
				Remotes.event(Remotes.Names.StealProgress):FireClient(plot.owner, pad.index, false)
			end
		end)

		prompt.Triggered:Connect(function(thief)
			StealService.attempt(thief, plot, pad)
		end)
	end

	prompt.HoldDuration = hold
	prompt.ObjectText = plot.owner and (plot.owner.DisplayName .. "'s pet") or "Pet"
end

function StealService.attempt(thief, plot, pad)
	local owner = plot.owner
	if not owner or owner == thief then
		PlayerService.notify(thief, "You can't rob your own plot.", "warn")
		return
	end
	if not pad.uid then
		return
	end

	local ownerData = DataService.get(owner)
	if not ownerData then
		return
	end

	if (ownerData.shieldUntil or 0) > os.time() then
		PlayerService.notify(thief, "That plot is shielded right now.", "warn")
		return
	end

	if os.clock() - (pad.placedAt or 0) < Config.Steal.graceSeconds then
		local left = math.ceil(Config.Steal.graceSeconds - (os.clock() - pad.placedAt))
		PlayerService.notify(thief, ("Just placed — protected for %ds."):format(left), "warn")
		return
	end

	local bucket = cooldowns[thief]
	if not bucket then
		bucket = {}
		cooldowns[thief] = bucket
	end
	if bucket[plot.index] and os.clock() - bucket[plot.index] < Config.Steal.thiefCooldown then
		PlayerService.notify(thief, "Slow down — cooldown on this plot.", "warn")
		return
	end

	if CarryService.get(thief) then
		PlayerService.notify(thief, "Your hands are full.", "warn")
		return
	end

	local record = PetService.takeFromPad(owner, pad.index)
	if not record then
		return
	end

	bucket[plot.index] = os.clock()

	if CarryService.give(thief, { kind = "pet", record = record }) then
		PlayerService.notify(thief, ("Stole %s! Get it home."):format(record.pet), "good")
		PlayerService.notify(owner, ("%s stole your %s!"):format(thief.DisplayName, record.pet), "bad")
	else
		-- Could not attach (no character): give it straight back rather than void it.
		PetService.addRecord(owner, record)
	end
end

function StealService.buyLock(player, padIndex)
	local data = DataService.get(player)
	local plot = PlotService.plotOf(player)
	if not data or not plot then
		return
	end
	local pad = plot.pads[padIndex]
	if not pad then
		return
	end

	local level = lockLevel(data, padIndex)
	if level >= Config.Steal.maxLockLevel then
		PlayerService.notify(player, "That pad is already fully locked.", "warn")
		return
	end

	local cost = math.floor(Config.Steal.lockCostBase * Config.Steal.lockCostGrowth ^ level)
	if (data.coins or 0) < cost then
		PlayerService.notify(player, "Not enough coins for that lock.", "warn")
		return
	end

	data.coins -= cost
	data.locks = data.locks or {}
	data.locks[tostring(padIndex)] = level + 1
	PlayerService.syncLeaderstats(player)
	PlayerService.notify(player, ("Pad %d lock level %d — thieves now hold %.1fs.")
		:format(padIndex, level + 1, StealService.holdTime(data, padIndex)), "good")
	refreshPrompt(plot, pad)
	PlayerService.pushState(player)
end

function StealService.start()
	table.insert(PetService.padChanged, refreshPrompt)

	Remotes.event(Remotes.Names.BuyLock).OnServerEvent:Connect(function(player, padIndex)
		if PlayerService.rateLimit(player, "buy") then
			StealService.buyLock(player, tonumber(padIndex) or 0)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return StealService
