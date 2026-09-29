local Framework = require(game.ReplicatedStorage.Framework)
local TeleportService = Framework:GetService("TeleportService") :: TeleportService
local Formulas = Framework:GetSharedModule("Formulas")
local Setting_Event = Framework:GetEvent("Toggle_Setting")
local Popup = Framework:GetEvent("Popup")

local Settings = {}

function Settings.init()
	Setting_Event.OnServerEvent:Connect(function(Player : Player, Setting : string, New_Value : any)
		if not Player:GetAttribute("Loaded") then return end
		
		local Player_Setting = Player.Settings[Setting]

		--[ Inputted Settings ]--
		if New_Value then
			--[ Wrong Value Type Sent | Possibly Exploiter ]--
			if typeof(New_Value) ~= typeof(Player_Setting.Value) then
				Popup:FireClient(Player, "Error", `Incorrect Value set for {Setting}.`)
				return
			end
			
			--[ Correct Value Type Sent | Perform Security Check]--
			if typeof(New_Value) == "number" then
				if Setting == "SetWalkSpeed" then
					New_Value = math.clamp(New_Value, 16, Formulas.Walkspeed(Player))
					Popup:FireClient(Player, "Success", `Walkspeed has been updated to {New_Value}.`)
				end
			end
			Player_Setting.Value = New_Value
			
			return
		end

		--[ Boolean Settings ]--
		Player_Setting.Value = not Player_Setting.Value
		
		if Player_Setting.Value then
			Popup:FireClient(Player, "Success", `{Setting} On`)
		else
			Popup:FireClient(Player, "Error", `{Setting} Off`)
		end
	end)
end

return Settings
