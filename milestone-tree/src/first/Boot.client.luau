--!strict
-- The loading screen from the first frame: replaces Roblox's default one. The game's overlay (Overlay/Screens) drives
-- it from there (status, the asset preload's progress) and fades it out once the player's game is on screen and its
-- images are fetched (App + Core/Preload).
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local BootScreen = require(script.Parent:WaitForChild("BootScreen"))

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
BootScreen.show()
-- a safety net: if the game's client never took over (a script error), do not cover the screen for good
task.delay(45, function()
	if BootScreen.visible() and not BootScreen.claimed() then BootScreen.hide() end
end)

-- a holding server (the game was updated, see server/SoftShutdown) sends everyone back to a public server itself;
-- if this player is still here long after that, they go back on their own (a client may teleport itself)
task.spawn(function()
	local function holding(): boolean return workspace:GetAttribute("MT_Holding") == true end
	if not holding() then workspace:GetAttributeChangedSignal("MT_Holding"):Wait() end
	task.wait(40)
	for _ = 1, 3 do
		pcall(function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
		end)
		task.wait(20)
	end
end)
