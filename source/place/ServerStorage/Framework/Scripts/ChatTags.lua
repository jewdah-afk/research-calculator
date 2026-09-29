local Framework = require(game.ReplicatedStorage.Framework)
local Formulas = Framework:GetSharedModule("Formulas")
local Equip_Event = Framework:GetEvent("Equip_Event")
local Popup = Framework:GetEvent("Popup")

local ChatTags = {}

function ChatTags.init()
	Equip_Event.OnServerEvent:Connect(function(Player, Equip)
		if not Player:GetAttribute("Loaded") then return end

		local chatSettings = Player:FindFirstChild("ChatSettings")
		if not chatSettings then
			warn("ChatSettings not found for player " .. Player.Name)
			return
		end

		local targetToggle = chatSettings:FindFirstChild(Equip)
		if not targetToggle then
			warn("Equip toggle " .. Equip .. " not found for player " .. Player.Name)
			return
		end

		if Equip == "PrimePinned" then
			targetToggle.Value = not targetToggle.Value
		else
			for _, toggle in pairs(chatSettings:GetChildren()) do
				if toggle:IsA("BoolValue") and toggle.Name ~= "PrimePinned" then
					if toggle.Value and toggle.Name == Equip then toggle.Value = false continue end
					toggle.Value = (toggle.Name == Equip)
				end
			end
		end
	end)
end

return ChatTags