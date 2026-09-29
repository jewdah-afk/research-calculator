local Framework = require(game.ReplicatedStorage.Framework)
local Purchase_Gamepass = Framework:GetEvent("Purchase_Gamepass")
local Player = Framework:GetPlayer()

--[ Ads ]--
local Fast = workspace.Areas["Spawn Island"].Map.Fast
local Damage = workspace.Areas["Spawn Island"].Map.x3Damage
local Walkspeed = workspace.Areas["Spawn Island"].Map.Walkspeed
local RuneLuck = workspace.Areas["Spawn Island"].Map.x2RuneLuck
local RuneSpeed = workspace.Areas["Spawn Island"].Map.x2RuneSpeed
local Energy = workspace.Areas["Spawn Island"].Map.x3Energy

local module = {}

function module.init()
	
	--[ Fast Ad ]--
	local Fast_GP = Player.Gamepasses.MoreAttackSpeed
	Fast.SurfaceGui.Main.Buy.Activated:Connect(function()
		Purchase_Gamepass:FireServer(791995082)
	end)
	
	local function Update_Fast()
		if Fast_GP.Value then
			Fast.SurfaceGui.Main.Buy.Upgrade.Text = "OWNED"
			Fast.SurfaceGui.Main.Buy.Active = false
			return
		end
		Fast.SurfaceGui.Main.Buy.Upgrade.Text = "BUY"
		Fast.SurfaceGui.Main.Buy.Active = true
	end
	Update_Fast()
	Fast_GP:GetPropertyChangedSignal("Value"):Connect(Update_Fast)
	
	
	--[ Damage Ad ]--
	local Damage_GP = Player.Gamepasses.MoreDamage
	Damage.SurfaceGui.Main.Buy.Activated:Connect(function()
		Purchase_Gamepass:FireServer(791665991)
	end)

	local function Update_Damage()
		if Damage_GP.Value then
			Damage.SurfaceGui.Main.Buy.Upgrade.Text = "OWNED"
			Damage.SurfaceGui.Main.Buy.Active = false
			return
		end
		Damage.SurfaceGui.Main.Buy.Upgrade.Text = "BUY"
		Damage.SurfaceGui.Main.Buy.Active = true
	end
	Update_Damage()
	Damage_GP:GetPropertyChangedSignal("Value"):Connect(Update_Damage)
	
	
	--[ Rune Luck Ad ]--
	local RuneLuck_GP = Player.Gamepasses.MoreRuneLuck
	RuneLuck.SurfaceGui.Main.Buy.Activated:Connect(function()
		Purchase_Gamepass:FireServer(791769975)
	end)

	local function Update_RuneLuck()
		if RuneLuck_GP.Value then
			RuneLuck.SurfaceGui.Main.Buy.Upgrade.Text = "OWNED"
			RuneLuck.SurfaceGui.Main.Buy.Active = false
			return
		end
		RuneLuck.SurfaceGui.Main.Buy.Upgrade.Text = "BUY"
		RuneLuck.SurfaceGui.Main.Buy.Active = true
	end
	Update_RuneLuck()
	RuneLuck_GP:GetPropertyChangedSignal("Value"):Connect(Update_RuneLuck)
	
	
	--[ Rune Speed Ad ]--
	local RuneSpeed_GP = Player.Gamepasses.MoreRuneSpeed
	RuneSpeed.SurfaceGui.Main.Buy.Activated:Connect(function()
		Purchase_Gamepass:FireServer(791941355)
	end)

	local function Update_RuneSpeed()
		if RuneSpeed_GP.Value then
			RuneSpeed.SurfaceGui.Main.Buy.Upgrade.Text = "OWNED"
			RuneSpeed.SurfaceGui.Main.Buy.Active = false
			return
		end
		RuneSpeed.SurfaceGui.Main.Buy.Upgrade.Text = "BUY"
		RuneSpeed.SurfaceGui.Main.Buy.Active = true
	end
	Update_RuneSpeed()
	RuneSpeed_GP:GetPropertyChangedSignal("Value"):Connect(Update_RuneSpeed)
	
	--[ Energy Ad ]--
	local Energy_GP = Player.Gamepasses.TripleEnergy
	Energy.SurfaceGui.Main.Buy.Activated:Connect(function()
		Purchase_Gamepass:FireServer(1044507959)
	end)

	local function Update_Energy()
		if Energy_GP.Value then
			Energy.SurfaceGui.Main.Buy.Upgrade.Text = "OWNED"
			Energy.SurfaceGui.Main.Buy.Active = false
			return
		end
		Energy.SurfaceGui.Main.Buy.Upgrade.Text = "BUY"
		Energy.SurfaceGui.Main.Buy.Active = true
	end
	Update_Energy()
	Energy_GP:GetPropertyChangedSignal("Value"):Connect(Update_Energy)
	
end

return module
