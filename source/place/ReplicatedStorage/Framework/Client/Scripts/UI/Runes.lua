Framework = require(game.ReplicatedStorage.Framework)

local Player = Framework:GetPlayer()
local Gui = Framework.Gui
local Screen = Gui.Runes
repeat task.wait() until Player:GetAttribute("Loaded")

local Runes = {}

function Runes:init()
	for _ , Pack_Button in Screen.Holder.Packs:GetChildren() do
		if Pack_Button.ClassName ~= "TextButton" then continue end
		
		local Rune = Screen.Holder:FindFirstChild(Pack_Button.Name)
		
		if Rune and Rune :: ScrollingFrame then
			Pack_Button.Activated:Connect(function()
				Rune.Visible = true
				
				for _, Frame in Screen.Holder:GetChildren() do
					if not Frame:IsA("ScrollingFrame") then continue end
					
					if Frame.Name ~= Rune.Name and Frame.Name ~= "Packs" then
						Frame.Visible = false
					end
				end
			end)
		end
	end
end

return Runes