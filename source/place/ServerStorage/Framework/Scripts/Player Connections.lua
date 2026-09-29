local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Automations = Framework:GetLibrary("Automations")
local MPS = Framework:GetService("MarketplaceService") :: MarketplaceService
local Character = Framework:GetLibrary("Character")
local ChatCommands = Framework:GetLibrary("ChatCommands")
local Datastore = Framework:GetLibrary("Datastore")
local EN = Framework:GetLibrary("EternityNum")
local Formulas = Framework:GetSharedModule("Formulas")
local Merger = Framework:GetLibrary("Merger")
local MobsHandler = Framework:GetLibrary("MobsHandler")
local Policy_Service = game:GetService("PolicyService")
local Run_Client = Framework:GetEvent("Run_Client")
local Mob = Framework:GetLibrary("Mob")
local Mob_Info = Framework:GetSharedModule("Mob_Info")
local ElixirDataStore = DataStoreService:GetDataStore("GlobalElixirDuration")
--local GlobalGoals = Framework:GetLibrary("GlobalGoals")


local PlayerConnections = {}

function OnJoin(Player : Player)
	Datastore.New(Player)
	Player:SetAttribute("Loaded", true)
	--GlobalGoals.init()
	Character(Player)
	Automations(Player)
	Merger.New(Player)
	
	Mob_Info[Player.UserId] = Mob.New({Player = Player})
	
	if game.PlaceId == 74525878631455 then
		print("Test Place detected. Initializing Chat Commands!")
		ChatCommands.Register(Player)
	end
	
	--[ OG Tag ]--
	local TimeJoined = os.date("*t", Player.Stats.TimeJoined.Value)
	Player:SetAttribute("OG", TimeJoined.month == 2 and TimeJoined.day == 9 and TimeJoined.year == 2024)

	local Role = Player:GetRoleInGroup(16143613)
	Player:SetAttribute("GroupMember", Role ~= "Guest")
	Player:SetAttribute("GroupRole", Role)
	
	Player.Gamepasses.Sprint:GetPropertyChangedSignal("Value"):Connect(function()
		Player.Settings.SetWalkSpeed.Value = Formulas.Walkspeed(Player)
	end)
	
	Player.Gamepasses.Prime:GetPropertyChangedSignal("Value"):Connect(function()
		Player.Settings.SetWalkSpeed.Value = Formulas.Walkspeed(Player)
	end)
	
	Player.Upgrades.Prisms_Walkspeed:GetPropertyChangedSignal("Value"):Connect(function()
		Player.Settings.SetWalkSpeed.Value = Formulas.Walkspeed(Player)
	end)
	
	--[ GAMEPASS TRACKER ]--
	local succ, err = pcall(function()
		if Player.Gamepasses.Grinder.Value or MPS:UserOwnsGamePassAsync(Player.UserId, 792138184) then
			Player.Gamepasses.Prime.Value = true
			Player.Gamepasses.MoreRuneSpeed.Value = true
			Player.Gamepasses.MoreRuneLuck.Value = true
			Player.Gamepasses.Sprint.Value = true
			Player.Gamepasses.MoreAttackSpeed.Value = true
			Player.Gamepasses.MoreDamage.Value = true
			Player.Gamepasses.MoreStats.Value = true
			Player.Gamepasses.MorePrisms.Value = true
			Player.Gamepasses.TripleEnergy.Value = true
			
			if not Player.Stats.GrinderBonus.Value then
				Player.Stats.Tickets.Value = EN.toString(EN.add(Player.Stats.Tickets.Value, 100))

				--Player.Stats.Tickets.Value += 100
				Player.Stats.GrinderBonus.Value = true
			end
			return
		end
		
		if MPS:UserOwnsGamePassAsync(Player.UserId, 1044507959) then
			Player.Gamepasses.TripleEnergy.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 792235071) then
			Player.Gamepasses.Prime.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 792134127) then
			Player.Gamepasses.MorePrisms.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 792703755) then
			Player.Stats.RuneBulkProduct.Value = math.max(Player.Stats.RuneBulkProduct.Value, 5)
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791941355) then
			Player.Gamepasses.MoreRuneSpeed.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791769975) then
			Player.Gamepasses.MoreRuneLuck.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791999108) then
			Player.Gamepasses.Sprint.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791995082) then
			Player.Gamepasses.MoreAttackSpeed.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791665991) then
			Player.Gamepasses.MoreDamage.Value = true
		end
		if MPS:UserOwnsGamePassAsync(Player.UserId, 791787809) then
			Player.Gamepasses.MoreStats.Value = true
		end
	end)
	
	local succ, err = pcall(function()
		local Policy = Policy_Service:GetPolicyInfoForPlayerAsync(Player)
		local linksAllowed = Policy["AllowedExternalLinkReferences"]

		for _ , Link in linksAllowed do
			Player:SetAttribute(`Link_{Link}`, true)
		end
		Player:SetAttribute("RNG_Banned", Policy["ArePaidRandomItemsRestricted"])

		Player:SetAttribute("Group_Role", Player:GetRoleInGroup(35328439))
	end)
	
	if succ then print(`{Player.Name} has successfully loaded their gamepasses.`) end
	
	--[ Leaderstats Stuff ]--
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local Ascension = Instance.new("NumberValue")
	Ascension.Name = "Ascension"
	Ascension.Parent = leaderstats
	local Tier = Instance.new("NumberValue")
	Tier.Name = "Tier"
	Tier.Parent = leaderstats
	
	leaderstats.Parent = Player
	
	Run_Client:FireClient(Player)
--	GlobalGoals.onPlayerJoin(Player)
	
	if math.floor(tick() - Player.Stats.PlaytimeStreak.Value) < 2*60 then
		Player.Stats.PlaytimeStreak.Value = 0
	end
	
	if math.floor(Player.Stats.LastLogin.Value) < 1 then
		Player.Stats.Energy.Value = 0
	end
	
	Player.Stats.LastLogin.Value = math.floor(tick())
end

function PlayerConnections.init()
	Players.PlayerAdded:Connect(OnJoin)
	
	Players.PlayerRemoving:Connect(function(Player : Player)
		local Data = Datastore(Player)
		if not Data then return end
		
		Data:Unlock()
		Data:Save(true)
	end)
end

return PlayerConnections