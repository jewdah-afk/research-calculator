local ClientFramework = require(game:GetService("ReplicatedStorage").Framework)

local EN = ClientFramework:GetLibrary("EternityNum")
local realm_Two = ClientFramework:GetEvent("realm_Two") ::RemoteEvent
local PopUp = ClientFramework:GetEvent("Popup")
local Formulas = ClientFramework:GetSharedModule("Formulas")

local purchase_Price = "1e3003" -- EN.Format("")
local ArcticTeleporter = workspace.Areas.Arctic.Teleporter.Teleporter:WaitForChild("Info")

local debounce = {}

realm_Two.OnServerEvent:Connect(function(Player)
	if debounce[Player] then return end
	debounce[Player] = true
	
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local humanoidRootPart = Character.HumanoidRootPart

	if Player.Stats.Realm.Value == "Two" then
		humanoidRootPart.CFrame = ArcticTeleporter.CFrame
		Player.Stats.Realm.Value = "Two"
		task.wait(1)
		debounce[Player] = nil
		return
	end
	
	if EN.leeq(Player.Stats.Energy.Value, purchase_Price) then return end
	
	humanoidRootPart.CFrame = ArcticTeleporter.CFrame
	Player.Stats.Realm.Value = "Two"
	realm_Two:FireClient(Player)
	task.wait(1)
	debounce[Player] = nil
end)