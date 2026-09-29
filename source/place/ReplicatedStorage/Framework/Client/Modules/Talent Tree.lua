local Framework = require(game.ReplicatedStorage.Framework)
local Collection_Service = Framework:GetService("CollectionService") :: CollectionService
local Tween_Service = Framework:GetService("TweenService")
local EN = Framework:GetLibrary("EternityNum")
local Upgrades = Framework:GetLibrary("Upgrades")
local Formulas = Framework:GetSharedModule("Formulas")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Player = Framework:GetPlayer()
local Mouse = Player:GetMouse()
local Prisms = Player.Stats.Prisms

local Layer = workspace.Layers.TalentTree
local Board = Layer.PrismsBoard
local PrismButton = Layer.PrismButton.PrismButton
local Button = PrismButton.Button

local RingInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

local TalentTree = {}
local Talents = {}

function Initialize(Upgrade : Model)
	if Upgrade:GetAttribute("Initialized") then return end
	Upgrade:SetAttribute("Initialized", true)
	
	local Upgrade_Name = Upgrade.Name
	local Player_Upgrade = Player.Upgrades:FindFirstChild(Upgrade_Name) :: ValueBase
	if not Player_Upgrade then return warn(`CLIENT | TALENT TREE ERRROR | {Upgrade_Name} not found`) end
	local Upgrade_Class = Upgrades(Upgrade_Name)
	
	local Ring = Upgrade.Ring
	Talents[Upgrade_Name] = {
		Player_Upgrade = Player_Upgrade;
		Upgrade = Upgrade;
		Upgrade_Class = Upgrade_Class;
		Afford_Tween = Tween_Service:Create(Ring, RingInfo, {Color = Color3.fromRGB(13, 255, 0)});
		CantAfford_Tween = Tween_Service:Create(Ring, RingInfo, {Color = Color3.fromRGB(255,0,0)});
		Owned_Tween = Tween_Service:Create(Ring, RingInfo, {Color = Color3.fromRGB(255, 255, 255)});
		Price_Label = Upgrade:FindFirstChild("Price", true);
		Currency = Player.Stats[Upgrade_Class.Currency];
	}
	
	local Max_Levels = Upgrade_Class.Levels
	local Cap = Upgrade:FindFirstChild("Cap", true)

	local function Update_Level()
		Cap.Text = `{EN.Format(Player_Upgrade.Value)}/{EN.Format(Max_Levels)}`
	end
	
	Update_Level()
	
	Player_Upgrade:GetPropertyChangedSignal("Value"):Connect(function()
		Update_Level()
	end)
end

local Active = false
function TalentTree.Toggle(HasReq)
	if HasReq then
		Active = true
		Layer.Parent = workspace.Layers
	else
		Active = false
		Layer.Parent = game.ReplicatedStorage.Layers_Storage
	end
	
	if Player.Stats.Tier.Value < 6 then
		PrismButton.Parent = game.ReplicatedStorage.Layers_Storage
	else
		PrismButton.Parent = Layer
	end
end


--[ Upgrade Visuals ]--
local function Update_Ring(Talent : {})
	if Talent.Upgrade_Class:IsMaxed(Talent.Player_Upgrade.Value) then
		Talent.Owned_Tween:Play()
		return
	end

	local can_afford = true 
	if Talent.Upgrade_Class.MultiBuy then 
		for _, priceTable in Talent.Upgrade_Class.MultiBuy do 
			local currency = nil
			if priceTable.isRune then
				currency = Player.Runes[priceTable.Currency]
			else 
				currency = Player.Stats[priceTable.Currency]
			end
			
			can_afford = can_afford and Talent.Upgrade_Class:CanAfford(Talent.Player_Upgrade.Value, currency.Value, Player, priceTable)
		end  
	else 
		can_afford = Talent.Upgrade_Class:CanAfford(Talent.Player_Upgrade.Value, Talent.Currency.Value, Player)
	end

	if can_afford then
		Talent.Afford_Tween:Play()
	else
		Talent.CantAfford_Tween:Play()
	end
end

local function Update_Price(Talent : {})

	
	if Talent.Upgrade_Class:IsMaxed(Talent.Player_Upgrade.Value) then
		if not Talent.Upgrade_Class.MultiBuy then
			Talent.Price_Label.Text = "MAXED"
		else 
			for _, priceTable in Talent.Upgrade_Class.MultiBuy do 
				Talent.Upgrade:FindFirstChild(priceTable.Currency, true).Text = "MAXED"
			end 
		end
		return
	end

	if Talent.Upgrade_Class.MultiBuy then 
		local currencyTable = Talent.Upgrade_Class:GetCost(Talent.Player_Upgrade.Value)

		for Currency_Name, priceTable in currencyTable do 
			Talent.Upgrade:FindFirstChild(Currency_Name, true).Text = `{EN.Format(priceTable[1])} {Currency_Name} {priceTable[2] and "RUNE" or ""}`
		end 
		return 
	end 

	Talent.Price_Label.Text = `{EN.Format(Talent.Upgrade_Class:GetCost(Talent.Player_Upgrade.Value))} {Talent.Upgrade_Class.Currency}`
end

function TalentTree.Update()
	if not Active then return end
	
	Board.SurfaceGui.Main.Amount.Text = EN.Format(Player.Stats.Prisms.Value)
	Board.SurfaceGui.Main.Multiplier.Text = `{EN.Format(Formulas.Prisms(Player))} every {EN.Format(Cooldowns.Prisms(Player))}s`
	
	if Player:GetAttribute("Prisms_X2") then
		Button.Material = Enum.Material.Neon
	else
		Button.Material = Enum.Material.Metal
	end
	
	local Updated = 0
	for _ , Talent in Talents do
		Updated += 1
		if Talent.Upgrade_Class.HasRequirement(Player) then
			Talent.Upgrade.Parent = Layer
			
			if Talent.Upgrade_Class.isPermanent then
				if Talent.Player_Upgrade.Value >= 1 and not Talent.Upgrade_Class.LastReq(Player) then
					for i,v in pairs(Talent.Upgrade:GetChildren()) do 
						if v.Name == "Connector" then
							v.Transparency = 1
						end
					end
				else
					for i,v in pairs(Talent.Upgrade:GetChildren()) do 
						if v.Name == "Connector" then
							v.Transparency = 0
						end
					end
				end
			end
			
			local Desc = Talent.Upgrade_Class.Update(Player)
			local Label = Talent.Upgrade:FindFirstChild("Desc", true)
			if Desc then
				Label.Text = Desc
			end
			Update_Price(Talent)
			Update_Ring(Talent)
		else
			Talent.Upgrade.Parent = Framework.Services.ReplicatedStorage.Talents_Storage
		end

		if Updated % 25 == 0 then task.wait() end
	end
end

Collection_Service:GetInstanceAddedSignal("TalentUpgrade"):Connect(Initialize)
for _ , Upgrade in Collection_Service:GetTagged("TalentUpgrade") do
	Initialize(Upgrade)
end

Mouse.Button1Up:Connect(function()
	local Result = Mouse.Target
	if Result and Result.Parent:HasTag("TalentUpgrade") then
		Framework.Events.Buy_Upgrade:FireServer(Result.Parent.Name)
	end
end)

return TalentTree
