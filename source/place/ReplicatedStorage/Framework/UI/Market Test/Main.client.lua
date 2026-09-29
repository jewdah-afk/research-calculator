local Framework = require(game.ReplicatedStorage.Framework)
local Purchase_Product = Framework:GetEvent("Purchase_Product")
local Purchase_Gamepass = Framework:GetEvent("Purchase_Gamepass")

script.Parent.Product.Activated:Connect(function()
	Purchase_Product:FireServer(2707655481)
end)

script.Parent.Gamepass.Activated:Connect(function()
	Purchase_Gamepass:FireServer(1041117185)
end)