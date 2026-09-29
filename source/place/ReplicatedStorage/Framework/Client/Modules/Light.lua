local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Areas.Arctic.Light
local Button = Obj.Light.Button
--local Multiplier = Obj.Multiplier
local Active = false

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Obj.Parent = workspace.Layers
		return
	end
	if not HasReq then
		Active = false
		Obj.Parent = game.ReplicatedStorage.Layers_Storage
	end
end

function module.Update()
	Button.BillboardGui.Cooldown.Text = `{Player.Stats.LightTotalTime.Value}s Cooldown`
	
	--[[ if not Active then return end
	
	local Second = 1
	local Minute = Second * 60
	local Hour = Minute * 60
	
	local startTime = Player.Stats.ChromeStartTime.Value
	local currentTime = tick()
	local differnceTime = currentTime - startTime
	local totalTime = math.max(Player.Stats.HazeTotalTime.Value - differnceTime, 0)

	local hours = math.floor((totalTime / Hour) % 24)
	local minutes = math.floor((totalTime / Minute) % 60)
	local seconds = math.floor(totalTime % 60)
	
	local timeLeft = (totalTime <= 0 and "Claim!") or string.format("%02i:%02i:%02i", hours, minutes, seconds)
	Button.BillboardGui.Cooldown.Text = timeLeft ]]--
end

return module
