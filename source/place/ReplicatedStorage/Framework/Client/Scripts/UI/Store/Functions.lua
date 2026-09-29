local Framework = require(game.ReplicatedStorage.Framework)

local ReplicatedStorage = Framework:GetService("ReplicatedStorage")

local Player = Framework:GetPlayer()

local ScreenGui = Framework.Gui.Store
local Confirmation = ScreenGui.Confirmation

local Purchase_Product = Framework:GetEvent("Purchase_Product")
local Purchase_Gamepass = Framework:GetEvent("Purchase_Gamepass")
local Request_Gifting = Framework:GetEvent("Request_Gifting")

local RTokenPrices = require(ReplicatedStorage.Framework.Libraries.ProductHandler.RTokenPrices)

local Product_Display = nil
local Product_Type = nil
local Product_Price = nil
local Product_ID = nil

local BuyConnection
local CancelConnection

local Functions = {}

function Functions.UpdateConfirmation(Data)
	
	if Data then
		Product_Display =  Data.Product_Display
		Product_Type = Data.Product_Type
		Product_Price =  Data.Product_Price
		Product_ID =  Data.Product_ID
	end
	
	Confirmation.Display.Text = Product_Display
	Confirmation.Pricing.Text = `[{Product_Price} RTOKENS]`
	Confirmation.Visible = true

	if BuyConnection then
		BuyConnection:Disconnect()
		BuyConnection = nil
	end

	if CancelConnection then
		CancelConnection:Disconnect()
		CancelConnection = nil
	end

	BuyConnection = Confirmation.Buy.Activated:Connect(function()
		Confirmation.Visible = false
		if Product_Type == "Gamepass" then
			Purchase_Gamepass:FireServer(Product_ID)
			return
		end
		if Product_Type == "Product" then
			Purchase_Product:FireServer(Product_ID)
			return
		end
	end)

	CancelConnection = Confirmation.Cancel.Activated:Connect(function()
		Confirmation.Visible = false
	end)
end

function Functions.AddGamepass(Gamepass: Frame)
	if Gamepass.Name == "Seperator" then return end

	local PlayerGamepass = Player.Gamepasses:FindFirstChild(Gamepass.Name) :: ValueBase
	if not PlayerGamepass then
		Gamepass.Visible = false
		return warn(`CLIENT | GAMEPASSES | {Gamepass.Name} not found. Hiding Store Item to prevent purchases.`)
	end

	local function Update()
		Gamepass.Buy.Active = not PlayerGamepass.Value
		if PlayerGamepass.Value then
			Gamepass.Buy.Buy.Text = "OWNED"
			return
		end
		Gamepass.Buy.Buy.Text = "BUY"
	end

	Gamepass.Buy.Activated:Connect(function()
		local id = Gamepass:GetAttribute("ID")
		
		if Player:GetAttribute("RTokens") and RTokenPrices[id] then
			Product_Type = "Gamepass"
			Product_Display = Gamepass:GetAttribute("Display") or "MISSING GAMEPASS DISPLAY"
			Product_ID = id
			Product_Price = RTokenPrices[id] or 9999

			Functions.UpdateConfirmation()
			Confirmation.Visible = true
			return
		end
		Purchase_Gamepass:FireServer(id)
	end)

	if Gamepass:FindFirstChild("Price") then
		local OriginalText = Gamepass.Price.Text
		Player:GetAttributeChangedSignal("RTokens"):Connect(function()
			local id = Gamepass:GetAttribute("ID")
			if Player:GetAttribute("RTokens") then
				Gamepass.Price.Text = `{RTokenPrices[id]} Robux Tokens`
				return
			end
			Gamepass.Price.Text = OriginalText
		end)
	end

	Update()
	PlayerGamepass:GetPropertyChangedSignal("Value"):Connect(Update)
end

function Functions.AddProduct(Product: Frame)
	if Product.Name == "Separator" then return end
	if Product.Name == "Boost" then return end

	if Product.Name == "FasterSecretStats" or Product.Name == "DoubleChromium" then
		local productName = Product.Name 
		if Product.Name == "DoubleChromium" then 
			productName = "X2Chromium"
		end
		
		local PlayerGamepass = Player.Gamepasses:FindFirstChild(productName) :: ValueBase
		
		local function Update()			
			if productName == "X2Chromium" then 
				if PlayerGamepass.Value > 0 then 
					Product.Buy.Buy.Text = "OWNED"
				else 
					Product.Buy.Buy.Text = "BUY"
				end
			else 
			
				if PlayerGamepass.Value then
					Product.Buy.Buy.Text = "OWNED"
				else 
					Product.Buy.Buy.Text = "BUY"

				end
			end
		end
		
		
		Update()
		PlayerGamepass:GetPropertyChangedSignal("Value"):Connect(Update)
	end
	

	local function PromptPurchase(Id, Display)
		if Player:GetAttribute("RTokens") and RTokenPrices[Id] then
			Product_Type = "Product"
			Product_Display = Display or "MISSING PRODUCT DISPLAY"
			Product_ID = Id
			Product_Price = RTokenPrices[Id] or 9999

			Functions.UpdateConfirmation()
			Confirmation.Visible = true
			return
		end
		Purchase_Product:FireServer(Id)
	end

	local Button = Product:FindFirstChild("Buy")
	if Button then
		Button.Activated:Connect(function()
			PromptPurchase(Product:GetAttribute("ID"), Product:GetAttribute("Display"))
		end)
	end

	local Buy1 = Product:FindFirstChild("Buy 1")
	if Buy1 then
		Buy1.Activated:Connect(function()
			PromptPurchase(Product["Buy 1"]:GetAttribute("ID"), Product["Buy 1"]:GetAttribute("Display"))
		end)
	end
	
	local Buy10 = Product:FindFirstChild("Buy 10")
	if Buy10 then
		Buy10.Activated:Connect(function()
			PromptPurchase(Product["Buy 10"]:GetAttribute("ID"), Product["Buy 10"]:GetAttribute("Display"))
		end)
	end
	
	if Product:GetAttribute("Excluded") == true then return end
	
	local OriginalText = {
		Price = Product:FindFirstChild("Price") and Product.Price.Text;
		Price_1 = Product:FindFirstChild("Price_1") and Product.Price_1.Text;
		Price_10 = Product:FindFirstChild("Price_10") and Product.Price_10.Text;
	}		
	
	Player:GetAttributeChangedSignal("RTokens"):Connect(function()
		local productId = Product:GetAttribute("ID")
			
		if Product:GetAttribute("ID10") then
			productId = Product:GetAttribute("ID10")
		end
			
		if Player:GetAttribute("RTokens") then
			if Product:FindFirstChild("Price_1") then 
				local id = Product["Buy 1"]:GetAttribute("ID")
				if RTokenPrices[id] then 
					Product.Price_1.Text = `{RTokenPrices[id]} Robux Tokens`
				end
			end
				
			if Product:FindFirstChild("Price_10") then
				local id = Product["Buy 10"]:GetAttribute("ID")
				if RTokenPrices[id] then 
					Product.Price_10.Text = `{RTokenPrices[id]} Robux Tokens`
				end
			end
				
			if Product:FindFirstChild("Price") then
				if RTokenPrices[productId] then 
					Product.Price.Text = `{RTokenPrices[productId]} Robux Tokens`
				end
			end
				
			return
		end
			
		if OriginalText.Price then
			Product.Price.Text = OriginalText.Price
		end
		if OriginalText.Price_1 then 
			Product.Price_1.Text = OriginalText.Price_1
		end
		if OriginalText.Price_10 then
			Product.Price_10.Text = OriginalText.Price_10
		end
	end)
	

	if Product:FindFirstChild("BuyAll") then
		local Button = Product.BuyAll

		local productId = Button:GetAttribute("ID")
		if Product:GetAttribute("ID10") then
			productId = Product:GetAttribute("ID10")
		end
		local ProductDisplay = Button:GetAttribute("Display") or "MISSING PRODUCT DISPLAY"
		local ProductPrice = RTokenPrices[productId] or 9999
		local ProductStat = Product.Name.."Product"

		local Stat = Player.Stats[ProductStat]

		Button.Activated:Connect(function()
			if Player:GetAttribute("RTokens") ~= nil and RTokenPrices[productId] then
				Product_Type = "Product"
				Product_Display = ProductDisplay
				Product_ID = productId
				Product_Price = ProductPrice

				Functions.UpdateConfirmation()
				Confirmation.Visible = true
				return
			end

			Purchase_Gamepass:FireServer(productId)
		end)

		local function UpdateVisibility()
			local HasProduct = Stat.Value >= 1
			Button.Active = not HasProduct
			Button.Visible = not HasProduct
			if Product:FindFirstChild("SavePrice") then
				Product.SavePrice.Visible = not HasProduct
			end
		end

		UpdateVisibility()
		Stat:GetPropertyChangedSignal("Value"):Connect(UpdateVisibility)
	end
end

return Functions