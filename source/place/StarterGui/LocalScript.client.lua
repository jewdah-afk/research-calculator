local Framework = require(game.ReplicatedStorage.Framework)

local Water_Buttons_Event = Framework:GetEvent("Water_Buttons") :: RemoteFunction

local WaterButtons = workspace.Areas.Arctic.WaterButtons

task.spawn(function()
	print("function called of waterbuttons")
	for _, button in WaterButtons:GetChildren() do
		if button:IsA("Model") then
			if button:FindFirstChild("Button") then
				button.Button.Touched:Connect(function()
					Water_Buttons_Event:InvokeServer(button.Name)
				end)
			end
		end
	end
end)


