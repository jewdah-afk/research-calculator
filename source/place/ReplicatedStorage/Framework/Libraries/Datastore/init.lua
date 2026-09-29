local Framework = require(game.ReplicatedStorage.Framework)
--[ SERVICES ]--
local DSS = Framework:GetService("DataStoreService")
local Players = Framework:GetService("Players")
local RunService = Framework:GetService("RunService") :: RunService
--[ CLASSES ]--
local Reconcile = require(script.Reconcile)
local RichText = Framework:GetLibrary("RichText")
--[ EVENTS ]--
local Popup = Framework:GetEvent("Popup")
local Get_TierData = Framework:GetEvent("Get_TierData") :: RemoteFunction

--[ DATASTORE SETTINGS ]--
local Game_Key = "Release_1"
local StudioSave = true

if game.PlaceId == 74525878631455 then
	Game_Key = "Test_101"
end

if RunService:IsStudio() then
	--print("HELLO FROM STUDIO")
	Game_Key = "Studio_201" -- Studio_13, reset to Studio_15
end

local Game_DS = DSS:GetDataStore(Game_Key)
--[ DECODING ]--
local Decode_Types = {
	["boolean"] = "BoolValue";
	["number"] = "NumberValue";
	["string"] = "StringValue";
}

--[ SESSION LOCKING ]--
local MemoryStoreService = Framework:GetService("MemoryStoreService") :: MemoryStoreService
local SessionLockData = MemoryStoreService:GetSortedMap("SessionLocks")

--[ MAIN ]--
local Player_Data = {}
local Datastore = {}
Datastore.__index = Datastore
Datastore.__call = function(Table, Key : Player)
	return Player_Data[Key]
end

-- TODO: https://github.com/Data-Oriented-House/Squash     Add if the DataStore request warning becomes to big of a problem... 

--[ MAIN FUNCTIONS ]--
function Datastore.New(Player : Player)
	if Player:GetAttribute("Loaded") then return warn(`Player is already loaded. Canceling datastore creation..`) end
	local PlayerDS = setmetatable({}, Datastore)

	task.wait(.1)

	--[ PLAYER DATA INITIALIZATION ]--
	PlayerDS.Player = Player
	PlayerDS.Data = nil
	PlayerDS.UserId = Player.UserId

	--[ PLAYER-SPECIFIC DATASTORE FUNCTIONS ]--
	function PlayerDS:Load()
		local succ, err = pcall(function()
			self.Data = Game_DS:GetAsync(self.UserId)
		end)
		
		if succ then
			self.Data = Reconcile(self.Data)
			--print(self.Data)
			--print(`{self.Player.Name} has loaded in. Reconciling data..`)
		end

		if err then
			warn(`Error loading data for {Player.Name} : {err}`)
			Player:Kick("There was an error loading your data. Please rejoin!")
			return
		end
	end

	function PlayerDS:Save(Left : boolean)
		if RunService:IsStudio() and not StudioSave then return warn("Studio Save is currently disabled.") end
		if self:IsLocked() then 
			
			warn(`{self.Player.Name}'s Session is currently locked. Not sending save request`) 
			local OriginalMsg = "Session is currently locked. Not sending save request!"
			Popup:FireClient(self.Player, "Failure", OriginalMsg)
			return
		end
		
		local tries = 0
		while DSS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 and tries < 3 do
			task.wait(0.5)
			tries += 1
		end
		
		self:Lock() -- Prevents further requests from being sent		

		local tries = 0
		repeat
			local succ, err = pcall(function()
				Game_DS:UpdateAsync(self.UserId, function(Old_Data)
					return self.Data
				end)
			end)

			if succ then
				warn(`SERVER | DATASTORE | {Player.Name} has successfully saved their data.`)
				local OriginalMsg = "Your data has been successfully saved!"
				Popup:FireClient(self.Player, "Success", OriginalMsg)
			end

			if err then
				tries += 1
				--warn(`SERVER | DATASTORE | {Player.Name} Error : {err}`)
				local OriginalMsg = "Your data has had trouble saving. If this persists, contact a developer!"
				Popup:FireClient(self.Player, "Error", OriginalMsg)
				task.wait(5)
			end
		until succ or tries == 10

		self:Unlock()
		
		if Left then
			Player_Data[self.Player] = nil
			self = nil
		end
	end

	function PlayerDS:ListVersions(maxDate: DateTime?)
		local timestamp = if maxDate then maxDate.UnixTimestampMillis else nil
		local success, pages = pcall(function()
			return Game_DS:ListVersionsAsync(self.UserId, Enum.SortDirection.Descending, nil, timestamp)
		end)
		if success then
			return pages:GetCurrentPage()
		else
			return {}
		end
	end

	function PlayerDS:Autosave()
		task.spawn(function()
			local Timer = 0
			while self.Player:IsDescendantOf(Players) do
				Timer += task.wait()
				if Timer >= math.random(120,120*2) then
					Timer = 0
					self:Save()
				end
			end
		end)
	end

	function PlayerDS:Set(Key : string, Value : any)
		self.Data[Key] = Value
	end

	function PlayerDS:Get(Key : string)
		return self.Data[Key]
	end

	function PlayerDS:GetData()
		return self.Data
	end

	function PlayerDS:Init()
		--[ PLAYER DATA INITIALIZATION ]--
		self:Load()

		--[ FOLDERS DATA INITIALIZATION ]--
		self:MakeFolder("Stats", self.Data.Stats)
		self:MakeFolder("Settings", self.Data.Settings)
		self:MakeFolder("Upgrades", self.Data.Upgrades)
		self:MakeFolder("Runes", self.Data.Runes)
		self:MakeFolder("Gamepasses", self.Data.Gamepasses)
		self:MakeFolder("OverheadPins", self.Data.OverheadPins)
		self:MakeFolder("ChatSettings", self.Data.ChatSettings)
		
		-- Temp energy fix
		
		--[ AUTOSAVE INITIALIZATION ]--
		self:Autosave()

		Player_Data[self.Player] = self
	end

	--[ SESSION LOCK DATASTORE FUNCTIONS ]--
	function PlayerDS:IsLocked()
		local Locked = false

		local succ , err = pcall(function()
			Locked = SessionLockData:GetAsync(Player.UserId)
		end)

		return Locked
	end

	function PlayerDS:Lock()
		local Timer = 10

		local succ, err = pcall(function()
			SessionLockData:SetAsync(Player.UserId, true, Timer)
		end)
		if succ then print(`Locked session for {Player.Name}.`) end
	end

	function PlayerDS:Unlock()
		local succ, err = pcall(function()
			SessionLockData:RemoveAsync(Player.UserId)
		end)
		if succ then print(`Unlocked session for {Player.Name}.`) end
	end


	--[ FOLDERS FUNCTIONS ]--
	function PlayerDS:MakeFolder(Folder_Name : string, Values : {})
		local Folder = Instance.new("Folder")

		for Key , Value in Values do
			if Value == "Inf" then
				Value = "0"
			end
			
			local Stat = Instance.new(Decode_Types[typeof(Value)])
			Stat.Name = Key
			Stat.Value = Value

			self:Set(Key, Stat.Value)
			Stat:GetPropertyChangedSignal("Value"):Connect(function()
				self:Set(Key, Stat.Value)
			end)

			Stat.Parent = Folder
		end

		Folder.Name = Folder_Name
		Folder.Parent = self.Player
	end


	--[ WAIT UNTIL SESSION IS UNLOCKED ]--
	if PlayerDS:IsLocked() then
		task.wait(1)
		
		local Checks = 0
		local MaxChecks = 6

		while Checks < MaxChecks do
			if not PlayerDS:IsLocked() then
				break
			end
			Checks += 1
			task.wait(2 + Checks) -- gradual backoff: 2s, 3s, 4s...
		end

		if Checks >= MaxChecks then
			PlayerDS:Release()
		end
	end
	
	Get_TierData.OnServerInvoke = function(Player, Username)
		local s,Data = pcall(function()
			return Game_DS:GetAsync(game.Players:GetUserIdFromNameAsync(Username))
		end)
		

		if Reconcile(Data).Stats.Tier >= 12 then
			return true
		else
			return false
		end
	end

	PlayerDS:Init()
end

return setmetatable({}, Datastore)
