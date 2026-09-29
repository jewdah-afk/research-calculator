local Framework = require(game.ReplicatedStorage.Framework)
--// Services \\--
local Collection_Service = Framework:GetService("CollectionService")
--// Classes \\--
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = Framework:GetLibrary("Upgrades")
--// Variables \\--
local Player = Framework:GetPlayer()
local Player_Upgrades = Player.Upgrades
local Upgrades_Client = {}
local Upgrade_Frames = {}

function UpdateVisibility(Upgrade_Class : {}, Upgrade : Frame)
	local Player_Upgrade = Player_Upgrades[Upgrade.Name]
	
	--[ Potential Caps ]--
	if Upgrade:FindFirstChild("Cap") then
		Upgrade.Cap.Text = `({Player_Upgrade.Value}/{Upgrade_Class:GetLevels(Player)})`
	end

	--[ Maxed Upgs ]--
	local Maxed = Upgrade_Class:IsMaxed(Player_Upgrade.Value, Player)
	Upgrade.Visible = not Maxed 
	

	if Upgrade_Class.HasRequirement then 
		local OwnsRequirement = Upgrade_Class.HasRequirement(Player)
		Upgrade.Visible = OwnsRequirement and (not Maxed)
		
		-- If we have the requirement but are maxed out 
		if Maxed and Upgrade_Class:StayVisible() then
			Upgrade.Visible = true	
		end
	else 
		
	end

	if Upgrade_Class.UpgradeReq then
		Upgrade.Visible = Player.Upgrades[Upgrade_Class.UpgradeReq].Value > 0 and not Maxed
	end
	
end

function AddUpgrade(Upgrade : Frame)
	local Upgrade_Name = Upgrade.Name
	local Player_Upgrade = Player_Upgrades:FindFirstChild(Upgrade.Name)
	if not Player_Upgrade then return warn(`CLIENT | UPGRADES | {Upgrade_Name} not found.`) end
	
	if Upgrade:GetAttribute("Initialized") then return end
	
	local Upgrade_Class = Upgrades(Upgrade.Name)
	table.insert(Upgrade_Frames, {Upgrade_Class = Upgrade_Class, Upgrade = Upgrade})
	
	--// Display \\--
	local function Update()
		local Current_Effect = EN.Format(Upgrade_Class:GetEffect(Player_Upgrade.Value, Player))
		
		if not Upgrade_Class:IsMaxed(Player_Upgrade.Value, Player) then
			local Next_Effect = EN.Format(Upgrade_Class:GetEffect(Player_Upgrade.Value + 1, Player))
			Upgrade.Multiplier.Text = Upgrade_Class.Effect_Display(Current_Effect, Next_Effect)
			
			local Price_Text = `Cost: {EN.Format(Upgrade_Class:GetCost(Player_Upgrade.Value, Player))} {Upgrade_Class.Currency}`
			Upgrade.Price.Text = Price_Text
			
			return
		end
		
		Upgrade.Multiplier.Text = `{Upgrade_Class.Effect_Display(Current_Effect)} (MAXED)`
		Upgrade.Price.Text = "MAXED"
	end

	if Upgrade:FindFirstChild("Buy") then 
		-- single upgrade
		Upgrade.Buy.Activated:Connect(function()
			Upgrade_Class:Buy(Player_Upgrade,false, Player)
		end)
	else 
		Upgrade.One.Activated:Connect(function()
			Upgrade_Class:Buy(Player_Upgrade,false, Player)
		end)
		Upgrade.Max.Activated:Connect(function()
			Upgrade_Class:Buy(Player_Upgrade, true, Player)
		end)
	end
	
	if not Upgrade_Class.StaticBoard then
		Update()
		Player_Upgrade:GetPropertyChangedSignal("Value"):Connect(Update)
	end

	--// Functionality \\--
		
	--// Changes \\--	
	--// Initialize \\--
	Upgrade:SetAttribute("Initialized", true)
end

function Upgrades_Client.init()
	Collection_Service:GetInstanceAddedSignal("Upgrades"):Connect(AddUpgrade)
	
	for _ , Upgrade in Collection_Service:GetTagged("Upgrades") do
		if Upgrade.Name == 'AP_Droplets1' then
			--print("HI")
		end
		
		AddUpgrade(Upgrade)
	end
	
	task.spawn(function()
		while task.wait(1/6) do
			for _ , Upgrade in Upgrade_Frames do
				UpdateVisibility(Upgrade.Upgrade_Class, Upgrade.Upgrade)
			end
		end
	end)
end

return Upgrades_Client
