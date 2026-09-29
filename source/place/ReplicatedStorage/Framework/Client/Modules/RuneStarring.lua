

local Framework = require(game.ReplicatedStorage.Framework)
local Player = Framework:GetPlayer()

--// Layer \\--
local Obj = workspace.Starring
local Active = false

local module = {}

function module.Toggle(HasReq : boolean)
	if HasReq then
		if Active then return end
		Active = true
		Obj.Parent = workspace
		return
	end
	if not HasReq then
		Active = false
		Obj.Parent = game.ReplicatedStorage.Layers_Storage
	end
end

return module