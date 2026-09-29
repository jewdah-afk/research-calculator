local Framework = require(game.ReplicatedStorage.Framework)

local ReplicatedStorage = Framework:GetService("ReplicatedStorage")

local Time = Framework:GetLibrary("Time")
local EternityNum = Framework:GetLibrary("EternityNum")

local Functions = require(script.Parent.Functions)

local Player = Framework:GetPlayer()
repeat task.wait() until Player:GetAttribute("Loaded")

local Use_Elixir = Framework:GetEvent("Use_Elixir")
local Use_Global = Framework:GetEvent("Use_Global")
local Purchase_Product = Framework:GetEvent("Purchase_Product")

local Popup = Framework:GetEvent("Popup")

local ServerElixirDuration = ReplicatedStorage.ServerElixirDuration
local ElixirDuration = ReplicatedStorage.GlobalElixirDuration

local ScreenGui = Framework.Gui.Store
local ElixirsGui = ScreenGui.Holder.Content.Elixirs
local BundlesGui = ScreenGui.Holder.Content.Bundles

local Elixirs = {}

function AddElixir(Elixir: Frame)
	if Elixir.Name == "Separator" then return end

	local ElixirStat = Player.Stats:FindFirstChild(Elixir.Name) or Player.Stats:WaitForChild(Elixir.Name, 5)
	if not ElixirStat then
		warn(`Failed to find stat for elixir: {Elixir.Name}`)
		return
	end

	Elixir["Use"].Activated:Connect(function()
		if Elixir.Name == "GlobalElixir" then
			Use_Global:FireServer()
		else
			Use_Elixir:FireServer(Elixir.Name)
		end
	end)

	local function Update()
		Elixir.Use.Buy.Text = `USE [{EternityNum.Format(ElixirStat.Value)}]`
	end

	Update()
	ElixirStat:GetPropertyChangedSignal("Value"):Connect(Update)
end


function UpdateDuration(Duration, Elixir: Frame)
	if not Duration or not Duration:IsA("NumberValue") or not Elixir or not Elixir:FindFirstChild("Timer") then
		return
	end

	local TimerLabel = Elixir.Timer

	local function Update()
		if Elixir.Name == "ServerElixir" then
			if ServerElixirDuration.Value > 0 then
				TimerLabel.Text = `ACTIVE [{Time(ServerElixirDuration.Value, true)}]`
			else
				TimerLabel.Text = "INACTIVE"
			end
			return
		end
		
		if Elixir.Name == "GlobalElixir" then
			if ElixirDuration.Value > 0 then
				TimerLabel.Text = `ACTIVE [{Time(ElixirDuration.Value, true)}]`
			else
				TimerLabel.Text = "INACTIVE"
			end
			return
		end
		
		if Duration.Value > 0 then
			TimerLabel.Text = `ACTIVE [{Time(Duration.Value, true)}]`
		else
			TimerLabel.Text = "INACTIVE"
		end
	end

	local Connection
	if Elixir.Name ~= "GlobalElixir" or Elixir.Name ~= "ServerElixir" then
		Connection = Duration:GetPropertyChangedSignal("Value"):Connect(function()
			Update()
		end)
	end

	local GlobalConnection
	if Elixir.Name == "GlobalElixir" then
		Update()
		GlobalConnection = ElixirDuration:GetPropertyChangedSignal("Value"):Connect(function()
			Update()
		end)
	end
	
	local ServerConnection
	if Elixir.Name == "ServerElixir" then
		Update()
		ServerConnection = ServerElixirDuration:GetPropertyChangedSignal("Value"):Connect(function()
			Update()
		end)
	end

	Update()
end


function Elixirs.init()
	Functions.AddProduct(BundlesGui.InfElixirs)

	for _, Elixir in ElixirsGui:GetChildren() do
		if not Elixir:IsA("Frame") then continue end
		if Elixir.Name == "Separator" then continue end

		Functions.AddProduct(Elixir)
		AddElixir(Elixir)
		if Elixir.Name == "GlobalElixir" then UpdateDuration(ElixirDuration, Elixir) continue end
		local durationName = Elixir.Name .. "Duration"
		local Duration = Player.Stats:FindFirstChild(durationName)
		UpdateDuration(Duration, Elixir)
	end
end

return Elixirs