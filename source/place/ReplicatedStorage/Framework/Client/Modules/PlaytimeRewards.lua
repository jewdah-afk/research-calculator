
local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Time = Framework:GetLibrary("Time")

local Board = game.Workspace:WaitForChild("Areas"):WaitForChild("Arctic"):WaitForChild("PlaytimeRwards")

local module = {}
local Active = false

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Board.Parent = workspace.Areas.Arctic
		return
	end
	if not HasReq then
		Active = false
		Board.Parent = game.ReplicatedStorage.Layers_Storage
	end
end


function module.Update(Player : Player)
	local PlaytimeStreak = Player.Stats.PlaytimeStreak.Value
	if not Active then return end
	
	
	-- Numbers already rounded in Automations
	if Player:GetAttribute("PlaytimeBulkIncrease") then
		Board.SurfaceGui.Main.RuneBulk.Text = `+{Player:GetAttribute("PlaytimeBulkIncrease")} RUNE BULK`
	end
	
	if Player:GetAttribute("PlaytimeLuckIncrease") then 
		Board.SurfaceGui.Main.RuneLuck.Text = `+{Player:GetAttribute("PlaytimeLuckIncrease")}% RUNE LUCK`
	end
	
	if PlaytimeStreak < 60 then 
		Board.SurfaceGui.Main.Time.Text = `{math.floor(PlaytimeStreak)}s`
	else 
		Board.SurfaceGui.Main.Time.Text = Time(PlaytimeStreak, true, true)
		
	end		
end

return module
