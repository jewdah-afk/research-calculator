local module = {}
local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))

local Water_Buttons_Event = Framework:GetEvent("Water_Buttons") :: RemoteFunction

local WaterButtons = workspace:WaitForChild("Areas").Arctic:WaitForChild("WaterButtons")

function module.init()
	--task.spawn(function()
	--	for _, button in WaterButtons:GetChildren() do
	--		if button:IsA("Model") then
	--			if button:FindFirstChild("Button") then
	--				button.Button.Touched:Connect(function()
	--					Water_Buttons_Event:InvokeServer(button.Name)
	--				end)
	--			end
	--		end
	--	end
	--end)
end

return module

