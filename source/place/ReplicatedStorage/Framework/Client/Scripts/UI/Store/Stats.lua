--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Services ]]--
local TextChatService = Framework:GetService("TextChatService")
local Players = Framework:GetService("Players")
local TweenService = Framework:GetService("TweenService")
local MarketplaceService = Framework:GetService("MarketplaceService")

--[[ Modules ]]--
local ChatData = Framework:GetSharedModule("ChatData")

--[[ Variables ]]--
local Leaderboards = game.ReplicatedStorage.Leaderboards
local Equip_Event = Framework:GetEvent("Equip_Event")
local Player = Framework:GetPlayer()
local ScreenGui = Framework.Gui.Stats

local GROUP_ID = 16143613

local StatsUI = {}

--[[ Formulas ]]--
local Equip_Info = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local Equipped_Goal = {BackgroundColor3 = Color3.fromRGB(255, 57, 57)}
local Unequipped_Goal = {BackgroundColor3 = Color3.fromRGB(61, 255, 67)}

--[[ Functions ]]--
local function AddEquipToggle(Player_Toggle, Toggle)
	local function Update()
		Toggle.Toggle.AutoButtonColor = false
		Toggle.Toggle.BackgroundTransparency = 0
		
		local animation = TweenService:Create(Toggle.Toggle, Equip_Info, (Player_Toggle.Value and Equipped_Goal) or Unequipped_Goal)
		animation:Play()
		
		Toggle.Toggle.Equip.Text = Player_Toggle.Value and "Unequip" or "Equip"
		Toggle.Toggle.Active = true
	end
	
	Update()
	Player_Toggle:GetPropertyChangedSignal("Value"):Connect(Update)
	
	Toggle.Toggle.Activated:Connect(function()
		Equip_Event:FireServer(Toggle.Name.."Pinned")
	end)
end

local function GetGroupTag(Player)
	local Rank = Player:GetRankInGroup(GROUP_ID)
	local Data = ChatData.Group_Roles[tostring(Rank)]
	
	return Data and string.format("<font color='rgb(%d,%d,%d)'>[%s]</font> ", Data.Color.R * 255, Data.Color.G * 255, Data.Color.B * 255, Data.Name) or ""
end

local function GetPrimeTag(Player)
	local Prime = Player.Gamepasses.Prime
	local PrimePinned = Player.ChatSettings.PrimePinned
	if Prime.Value and PrimePinned.Value then
		local color = ChatData.Gamepasses.Prime
		
		return string.format("<font color='rgb(%d,%d,%d)'>[PRIME]</font> ", color.R * 255, color.G * 255, color.B * 255)
	end
	return ""
end

local function GetOGTag(Player)
	local OGPinned = Player.ChatSettings.OGPinned
	if Player:GetAttribute("OG") and OGPinned.Value then
		local color = ChatData.Special.OG
		print(color)
		
		return string.format("<font color='rgb(%d,%d,%d)'>[OG]</font> ", color.R * 255, color.G * 255, color.B * 255)
	end
	return ""
end

local function GetLeaderboardName(Player)
	local Settings = Player:FindFirstChild("ChatSettings")
	if Settings then
		if Settings:FindFirstChild("PlaytimePinned").Value then 
			return "Playtime" 
		end
		
		if Settings:FindFirstChild("TotalEnergyPinned").Value then 
			return "TotalEnergy" 
		end
		
		if Settings:FindFirstChild("RunesOpenedPinned").Value then 
			return "RunesOpened" 
		end
		
		if Settings:FindFirstChild("RobuxSpentPinned").Value then 
			return "RobuxSpent" 
		end
		
		if Settings:FindFirstChild("PrismsPinned").Value then 
			return "Prisms" 
		end
	end
	return ""
end

local function GetActualLeaderboardName(Player, Pinned)
	if Pinned == "" then 
		return "" 
	end
	
	local SpentRobux = Player.Stats.RobuxSpent and Player.Stats.RobuxSpent.Value > 0
	
	if Pinned == "TotalEnergy" then 
		if SpentRobux then return "TotalEnergy_P2W" end
		return "TotalEnergy_F2P" 
	end
	
	if Pinned == "RunesOpened" then 
		if SpentRobux then return "Runes_Opened_P2W" end
		return "Runes_Opened_F2P" 
	end
	
	if Pinned == "Prisms" then 
		if SpentRobux then return "Prisms_P2W" end
		return "Prisms_F2P" 
	end
	
	if Pinned == "RobuxSpent" then
		return "RobuxSpent"
	end
	
	return Pinned
end

local function GetLeaderboardTag(Player, Name)
	local LeaderboardsFolder = Leaderboards:FindFirstChild(Name)
	if LeaderboardsFolder then
		local Spot = LeaderboardsFolder:FindFirstChild(tostring(Player.UserId))
		if Spot then
			local Position = Spot:GetAttribute("Pos") or 0
			local Data = ChatData.Leaderboard_Tags[Name]
			Name = ChatData.Leaderboard_Conversions[Name] or Name
			if Data then
				return string.format("<font color='rgb(%d,%d,%d)'>[%s #%d]</font> ", Data.Color.R * 255, Data.Color.G * 255, Data.Color.B * 255, Name, Position)
			end
		end
	end
	return ""
end

function StatsUI.init()
	for _, ToggleFrame in ScreenGui.Holder.Tags:GetChildren() do
		if ToggleFrame:IsA("Frame") then
			local SettingName = ToggleFrame.Name
			local ChatSettings = Player:FindFirstChild("ChatSettings")
			
			if ChatSettings then
				local ActualName = GetActualLeaderboardName(Player, SettingName)
				local hideToggle = (ActualName == "") or not Leaderboards:FindFirstChild(ActualName)
				
				if SettingName == "Prime" then
					hideToggle = not Player.Gamepasses.Prime.Value
					Player.Gamepasses.Prime:GetPropertyChangedSignal("Value"):Connect(function()
						ToggleFrame.Visible = Player.Gamepasses.Prime.Value
					end)
				end
				
				if SettingName == "OG" then
					hideToggle = not Player:GetAttribute("OG")
					Player:GetAttributeChangedSignal("OG"):Connect(function()
						ToggleFrame.Visible = Player:GetAttribute("OG")
					end)
				end
				
				ToggleFrame.Visible = not hideToggle
				
				local ToggleSetting = ChatSettings:FindFirstChild(SettingName.."Pinned")
				if ToggleSetting then 
					AddEquipToggle(ToggleSetting, ToggleFrame) 
				end
			end
		end
	end
	TextChatService.OnIncomingMessage = function(Message)
		local Props = Instance.new("TextChatMessageProperties")
		
		if Message.TextSource then
			local Player = Players:GetPlayerByUserId(Message.TextSource.UserId)
			
			if Player then
				local LeaderboardName = GetLeaderboardName(Player)
				local Lb_Name = GetActualLeaderboardName(Player, LeaderboardName)
				local Lb_Tag = GetLeaderboardTag(Player, Lb_Name)
				local FinalPrefix = `{Lb_Tag}{GetGroupTag(Player)}{GetPrimeTag(Player)}{GetOGTag(Player)}{Message.PrefixText}`
				Props.PrefixText = Player.Settings.ChatTags.Value and FinalPrefix or ""
			end
		end
		
		return Props
	end
end

return StatsUI