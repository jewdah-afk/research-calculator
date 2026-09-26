--!strict
-- The loading screen from the first frame: replaces Roblox's default one. The game's overlay (Overlay/Screens) drives
-- it from there (status, progress) and fades it out once the player's game is on screen.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local BootScreen = require(script.Parent:WaitForChild("BootScreen"))

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
BootScreen.show()
-- a safety net: if the game's client never took over (a script error), do not cover the screen for good
task.delay(45, function()
	if BootScreen.visible() and not BootScreen.claimed() then BootScreen.hide() end
end)
