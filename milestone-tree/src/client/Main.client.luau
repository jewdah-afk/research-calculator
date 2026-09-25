--!strict
--[[
	Milestone Tree NG+ on Roblox: the player's screen.

	The game runs on the server; this draws what it sends and sends button presses back. The realm map is the home
	screen: every layer is a node on the painted tree, and a node opens that layer's panel. App.luau does the work;
	this script only starts it.
]]

local App = require(script.Parent:WaitForChild("App"))

App.start()
