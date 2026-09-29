-- Optimized Leaderboard Module to avoid DataStore throttling

local Framework = require(game.ReplicatedStorage.Framework)
--[ Services ]--
local DataStoreService = Framework:GetService("DataStoreService") :: DataStoreService
local Players = Framework:GetService("Players")
local ReplicatedStorage = Framework:GetService("ReplicatedStorage")
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
local LeaderboardUpdate = Framework:GetEvent("LeaderboardUpdate")

local TierDS = DataStoreService:GetDataStore("TierDS") :: DataStore
local Ordered_DS_Cache = {}

local Decode = require(script.Decode)
local Encode = require(script.Encode)
local Username_Cache = {}

--[ Reconcile Folder ]--
if not ReplicatedStorage:FindFirstChild("Leaderboards") then
	local Folder = Instance.new("Folder")
	Folder.Name = "Leaderboards"
	Folder.Parent = ReplicatedStorage

	local Tier12Folder = Instance.new("Folder")
	Tier12Folder.Name = "TierTwelve"
	Tier12Folder.Parent = Folder

	local AnyTierFolder = Instance.new("Folder")
	AnyTierFolder.Name = "AnyTier"
	AnyTierFolder.Parent = Folder
end

local function CheckP2W(Player: Player)
	return Player.Stats.RobuxSpent.Value > 0
end

local Leaderboard = {}

function Leaderboard.New(Data: {}, onlyTierTwelveLB: boolean, isTierTwelveLB: boolean)
	-- Settings --
	local StatsName = Data.StatsName or "Cash"
	local Key = Data.Key or "Global_" .. StatsName
	local FolderName = Data.FolderName or StatsName
	local MaxItems = Data.MaxItems or 50
	local MinValueDisplay = 0
	local MaxValueDisplay = 1e33
	local UpdateIncrement = 180
	local P2W_Check = Data.P2WCheck or false

	-- Folder Setup --
	local Folder = ReplicatedStorage.Leaderboards
	local AnyTierFolder = Folder.AnyTier :: Folder
	local Tier12Folder = Folder.TierTwelve :: Folder

	if not AnyTierFolder:FindFirstChild(FolderName) then
		local f = Instance.new("Folder")
		f:SetAttribute("Loading", true)
		f.Name = FolderName
		f.Parent = AnyTierFolder
	end

	if not Tier12Folder:FindFirstChild(FolderName) and isTierTwelveLB then
		local f = Instance.new("Folder")
		f:SetAttribute("Loading", true)
		f.Name = FolderName
		f.Parent = Tier12Folder
	end

	-- Ordered DataStore --
	local Ordered_DS = Ordered_DS_Cache[Key] or DataStoreService:GetOrderedDataStore(Key)
	Ordered_DS_Cache[Key] = Ordered_DS

	-- Leaderboard Logic --
	local function SaveData(Player: Player)
		local Value = Player.Stats[StatsName].Value
		local isTier12 = Player.Stats.Tier.Value >= 12
		if Encode[StatsName] then Value = Encode[StatsName](Value) end

		local succ1, err1 = pcall(function()
			Ordered_DS:UpdateAsync(Player.UserId, function()
				return Value
			end)
		end)
		
		if err1 then warn(`Ordered_DS save error for {Player.Name}: {err1}`) end
	end

	local function LoadData()
		local Data = Ordered_DS:GetSortedAsync(false, MaxItems, MinValueDisplay, MaxValueDisplay)
		local TopPage = Data:GetCurrentPage()
		local TierTwelveCount = {}
		local firstLoop = true

		while #TierTwelveCount < 3 do
			for i, v in TopPage do
				local UserId = v.key
				local Value = v.value
				local isTier12 = false
				local Username = Username_Cache[UserId] or "[Not Loaded]"

				pcall(function()
					isTier12 = TierDS:GetAsync(UserId)
					Username = Players:GetNameFromUserIdAsync(UserId)
					Username_Cache[UserId] = Username
				end)

				if isTier12 and isTierTwelveLB and #TierTwelveCount < 3 then
					local PlayerData = Instance.new("Folder")
					PlayerData.Name = UserId
					PlayerData:SetAttribute("Pos", i)
					if Decode[StatsName] then Value = Decode[StatsName](Value) end
					PlayerData:SetAttribute("Amount", Value)
					PlayerData:SetAttribute("Username", Username)
					PlayerData.Parent = Tier12Folder[FolderName]
					table.insert(TierTwelveCount, UserId)
				end

				if onlyTierTwelveLB or not firstLoop then continue end

				local PlayerData = Instance.new("Folder")
				PlayerData.Name = UserId
				PlayerData:SetAttribute("Pos", i)
				if Decode[StatsName] then Value = Decode[StatsName](Value) end
				PlayerData:SetAttribute("Amount", Value)
				PlayerData:SetAttribute("Username", Username)
				PlayerData.Parent = AnyTierFolder[FolderName]
			end

			firstLoop = false
			if Data.IsFinished then break end
			Data:AdvanceToNextPageAsync()
		end
	end

	local function ClearData()
		for _, v in AnyTierFolder[FolderName]:GetChildren() do v:Destroy() end
		if not isTierTwelveLB then return end
		for _, v in Tier12Folder[FolderName]:GetChildren() do v:Destroy() end
	end

	-- Run Leaderboard in Cycle --
	task.spawn(function()
		task.wait(5)
		while true do
			local lastUpdateTime = 0
			local delayBetweenSaves = 1.2

			for _, Player in Players:GetPlayers() do
				if not Player:FindFirstChild("Stats") then continue end
				if P2W_Check and CheckP2W(Player) then continue end

				local now = tick()
				if now - lastUpdateTime < delayBetweenSaves then
					task.wait(delayBetweenSaves - (now - lastUpdateTime))
				end
				lastUpdateTime = tick()

				SaveData(Player)
			end

			LoadData()
			Folder:SetAttribute("Loading", false)
			LeaderboardUpdate:FireAllClients()
			task.wait(UpdateIncrement)
			Folder:SetAttribute("Loading", true)
			ClearData()
		end
	end)
end

return Leaderboard