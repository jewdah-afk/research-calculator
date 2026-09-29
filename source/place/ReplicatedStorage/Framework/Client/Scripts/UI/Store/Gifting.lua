--[[ Framework ]]
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--

--[[ Variables ]]--
local Request_Gifting = Framework:GetEvent("Request_Gifting") ::RemoteFunction

local ScreenGui = Framework.Gui.Store
local Holder = ScreenGui.Holder
local GiftList = ScreenGui.GiftList

local GiftTemplate = script.Gifting_Template

local SelectedPlayer = 0
local SelectedGift = {
	Name = "None",
	ID = 0,
}

local Gifting = {}

--[[ Functions ]]--
function HandleGift(Gift: TextButton | ImageButton, Name)
	if not Gift then return end
	
	Gift.Activated:Connect(function()
		SelectedPlayer = tonumber(Gift.Name)
		GiftList.User.Text = "@"..Name
	end)
end

function AddAPlayer(Player: Player)
	if GiftList.PlayerList:FindFirstChild(Player.Name) then return end
	if Player.Name == game.Players.LocalPlayer.Name then  return end
	
	local Template = GiftTemplate:Clone()
	Template.Name = Player.UserId
	Template.User.Text = "@"..Player.Name
	Template.Parent = GiftList.PlayerList
	HandleGift(Template, Player.Name)
end

function RemoveAPlayer(Player: Player)
	if GiftList.PlayerList:FindFirstChild(Player.UserId) then
		GiftList.PlayerList:FindFirstChild(Player.UserId):Destroy()
	end
	if SelectedPlayer == Player.UserId then
		SelectedPlayer = 0
	end
end

--[[ Code ]]--
function Gifting.init()
	for _, Player in game.Players:GetPlayers() do
		AddAPlayer(Player)
	end
	game.Players.PlayerAdded:Connect(function(Player)
		AddAPlayer(Player)
	end)
	game.Players.PlayerRemoving:Connect(function(Player)
		RemoveAPlayer(Player)
	end)
	
	for _, v in Holder.Content:GetDescendants() do
		if v:IsA("TextButton") then
			if v.Name == "Gift" and v.Parent:FindFirstChild("Buy") then
				v.MouseButton1Click:Connect(function()
					GiftList.Visible = true
					SelectedGift.Name = v.Parent.Name
					SelectedGift.ID = v.Parent:GetAttribute("ID")
					GiftList.Gamepass.Text = "["..SelectedGift.Name.."]"
				end)
			end
		end
	end
	
	GiftList.Cancel.MouseButton1Click:Connect(function()
		GiftList.Visible = false
	end)
	
	GiftList.Gift.MouseButton1Click:Connect(function()
		if SelectedPlayer == 0 then return end
		
		GiftList.Visible = false
		Request_Gifting:InvokeServer(SelectedPlayer,SelectedGift)
	end)
end

return Gifting