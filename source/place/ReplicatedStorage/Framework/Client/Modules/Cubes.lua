local Framework = require(game.ReplicatedStorage.Framework)
local Collection_Service = Framework:GetService("CollectionService")
local Tween_Service = Framework:GetService("TweenService")
local EN = Framework:GetLibrary("EternityNum")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Formulas = Framework:GetSharedModule("Formulas")
local Update_Cubes = Framework:GetEvent("Update_Cubes")
local Upgrades = Framework:GetLibrary("Upgrades")
local Player = Framework:GetPlayer()

local Top1_Cube = workspace.Layers.Merger.Merger.Top1
local Top2_Cube = workspace.Layers.Merger.Merger.Top2
local Top3_Cube = workspace.Layers.Merger.Merger.Top3
local Top4_Cube = workspace.Layers.Merger.Merger.Top4
local Top5_Cube = workspace.Layers.Merger.Merger.Top5

local Layer = workspace.Layers.Merger

local Cubes = {}

--[ Upgrades ]--
function UpdateUpgrade(UpgradeName : string)
	local Gui = Layer[UpgradeName].Button.BillboardGui
	local Upg_Class = Upgrades(UpgradeName)

	local Current = Player.Upgrades[UpgradeName].Value
	local CurrentEffect = Upg_Class:GetEffect(Current)

	if Upg_Class:IsMaxed(Current) then
		Gui.Price.Text = "MAXED"
		Gui.Display.Text = Upg_Class.Effect_Display(EN.Format(CurrentEffect))
		return
	end

	local Next = Current + 1
	local NextEffect = Upg_Class:GetEffect(Next)
	Gui.Price.Text = `Price: {EN.Format(Upg_Class:GetCost(Current))} Orbs`
	Gui.Display.Text = Upg_Class.Effect_Display(EN.Format(CurrentEffect), EN.Format(NextEffect))
end


function Cubes.Toggle(HasReq)
	if HasReq then
		Layer.Parent = workspace.Layers
		return
	end
	Layer.Parent = game.ReplicatedStorage.Layers_Storage
end

function Cubes.Update()
	local Cube_Level = Player.Stats.Cube_Level.Value
	
	Layer.Board.SurfaceGui.Main.CurrentLvl.Text = `(LEVEL {EN.Format(Cube_Level)})`
	Layer.Board.SurfaceGui.Main.Energy.Text = `x{EN.Format(Formulas.Cube_Energy(Cube_Level))} ENERGY`
	Layer.Board.SurfaceGui.Main.Orbs.Text = `x{EN.Format(Formulas.Cube_Orbs(Cube_Level))} ORBS`
	Layer.Board.SurfaceGui.Main.Power.Text = `x{EN.Format(Formulas.Cube_Power(Cube_Level))} POWER`
	Layer.Merger.Part.SurfaceGui.Level.Text = `Spawn Level: {EN.Format(Formulas.Cube_Level(Player))}`
	
	local Last_Cube = tick() - (Player:GetAttribute("Cubes") or tick())
	local Cooldown = Cooldowns.Cubes(Player)
	local Percentage = math.clamp(Last_Cube / Cooldown, 0, 0.987)
	Layer.Merger.Part.SurfaceGui.Background.Bar.Size = UDim2.new(Percentage, 0, 0.85, 0)
	Layer.Merger.Part.SurfaceGui.Timer.Text = `{EN.Format(math.clamp(Cooldown - Last_Cube, 0, 1))}S`

	UpdateUpgrade("Orbs_RuneBulk")
	UpdateUpgrade("Orbs_SpawnLevel")
	UpdateUpgrade("Orbs_SpawnTime")
	
	Layer.Board.SurfaceGui.Main.ScrollingFrame.Perk_5.Visible = Player.Stats.AscensionOne.Value
	Layer.Board.SurfaceGui.Main.ScrollingFrame.Perk_6.Visible = Player.Stats.AscensionOne.Value
	Layer.Board.SurfaceGui.Main.ScrollingFrame.Perk_7.Visible = Player.Stats.AscensionOne.Value
end

function UpdateCubeVisuals(Data : {})
	for Pos , CubeInfo in Data do
		local Cube = Layer.Merger[`Top{Pos}`]
		Cube.BillboardGui.Display.Text = `LVL {EN.Format(CubeInfo.Cube_Level)} (x{math.floor(CubeInfo.Amount)})`
		Cube:SetAttribute("Previous", CubeInfo.Cube_Level)
	end
end

--[ Cube Stuff ]--
local ColorInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
function RandomizeCubeColor(Cube : Model)
	local Tween = Tween_Service:Create(Cube, ColorInfo, {Color = Color3.fromRGB(math.random(1,255), math.random(1,255), math.random(1,255))})
	Tween:Play()
end

Top1_Cube:GetAttributeChangedSignal("Previous"):Connect(function()
	RandomizeCubeColor(Top1_Cube)
end)
Top2_Cube:GetAttributeChangedSignal("Previous"):Connect(function()
	RandomizeCubeColor(Top2_Cube)
end)
Top3_Cube:GetAttributeChangedSignal("Previous"):Connect(function()
	RandomizeCubeColor(Top3_Cube)
end)
Top4_Cube:GetAttributeChangedSignal("Previous"):Connect(function()
	RandomizeCubeColor(Top4_Cube)
end)
Top5_Cube:GetAttributeChangedSignal("Previous"):Connect(function()
	RandomizeCubeColor(Top5_Cube)
end)

Update_Cubes.OnClientEvent:Connect(function(Data : {})
	table.sort(Data, function(a, b)
		return a.Cube_Level < b.Cube_Level
	end)
	UpdateCubeVisuals(Data)
end)

return Cubes
