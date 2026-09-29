local Framework = require(game.ReplicatedStorage.Framework)
local VFX_Event = Framework:GetEvent("Layer_VFX")
local Player = Framework:GetPlayer()

local module = {}

function module.init()
	VFX_Event.OnClientEvent:Connect(function(Button : workspace)
		if not Player.Settings.Particles.Value then return end
		
		local VFX = Button.PrimaryPart:FindFirstChild("VFX")
		if VFX then
			for _ , Emitter : ParticleEmitter in VFX:GetChildren() do
				Emitter:Emit(Emitter:GetAttribute("EmitCount"))
			end
		end
	end)
end


return module
