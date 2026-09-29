local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Time = Framework:GetLibrary("Time")

local Folder = game.Workspace:WaitForChild("Areas"):WaitForChild("Arctic"):WaitForChild("IceButtons")

local module = {}
local Active = false

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Folder.Parent = workspace.Areas.Arctic
		return
	end
	if not HasReq then
		Active = false
		Folder.Parent = game.ReplicatedStorage.Layers_Storage
	end
end

return module