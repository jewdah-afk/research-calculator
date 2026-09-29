	local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
local GlobalRune = Framework:GetLibrary("GlobalRune")
local UltraRune = Framework:GetLibrary("UltraRune")
local AncientRune = Framework:GetLibrary("AncientRune")
local MadnessRune = Framework:GetLibrary("MadnessRune")

local RichText = Framework:GetLibrary("RichText")
local RunService = Framework:GetService("RunService")
local MessageEvent = Framework:GetEvent("GlobalMessage")

local Messenger = {}

local Prefix = RichText("[GLOBAL RUNES]")
Prefix:Colored(Color3.fromRGB(234, 76, 255))
Prefix:Bold()
Prefix = Prefix:Return()

local ElixirPrefix = RichText("[GLOBAL ELIXIR]")
ElixirPrefix:Colored(Color3.fromRGB(246, 219, 255))
ElixirPrefix:Bold()
ElixirPrefix = ElixirPrefix:Return()

local Global_Single = RichText("Global Rune")
Global_Single:Colored(Color3.fromRGB(234, 76, 255))
Global_Single = Global_Single:Return()

local Global_Plural = RichText("Global Runes")
Global_Plural:Colored(Color3.fromRGB(234, 76, 255))
Global_Plural = Global_Plural:Return()

local Ultra_Single = RichText("Ultra Rune")
Ultra_Single:Colored(Color3.fromRGB(255,0,0))
Ultra_Single = Ultra_Single:Return()

local Ultra_Plural = RichText("Ultra Runes")
Ultra_Plural:Colored(Color3.fromRGB(255,0,0))
Ultra_Plural = Ultra_Plural:Return()

local Ancient_Single = RichText("Ancient Rune")
Ancient_Single:Colored(Color3.fromRGB(255, 253, 131))
Ancient_Single = Ancient_Single:Return()

local Ancient_Plural = RichText("Ancient Runes")
Ancient_Plural:Colored(Color3.fromRGB(255, 253, 131))
Ancient_Plural = Ancient_Plural:Return()

local Madness_Single = RichText("Madness Rune")
Madness_Single:Colored(Color3.fromRGB(125,0,0))
Madness_Single = Madness_Single:Return()

local Madness_Plural = RichText("Madness Runes")
Madness_Plural:Colored(Color3.fromRGB(125,0,0))
Madness_Plural = Madness_Plural:Return()


--[ SERVER-ONLY FUNCTIONS ]--
if RunService:IsServer() then
	--[ SETTINGS ]--
	local HttpService = Framework:GetService("HttpService") :: HttpService
	local MessagingService = Framework:GetService("MessagingService") :: MessagingService
	
	local Key = "Global"
	
	local Publisher = MessagingService:SubscribeAsync(Key, function(Input : {})
		local Data = HttpService:JSONDecode(Input.Data)

		if Data.Type == "GR1" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					GlobalRune.Roll(Player)
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1 {Global_Single} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GR7" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 7 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 7 {Global_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GR10" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 10 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 10 {Global_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GR75" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 75 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 75 {Global_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GR25" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 25 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 25 {Global_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GR30" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 30 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 30 {Global_Plural} for EVERYONE!! WOW`})
			end)
			return
		end
		
		if Data.Type == "GR750" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 750 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 750 {Global_Plural} for EVERYONE!! OMGG`})
			end)
			return
		end
		
		if Data.Type == "GR100" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 100 {Global_Plural} for EVERYONE!! OMGG`})
			end)
			return
		end
		
		if Data.Type == "GR7500" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 7500 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 7500 {Global_Plural} for EVERYONE!! W IN THE CHAT`})
			end)
			return
		end
		
		if Data.Type == "GR250" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 250 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 250 {Global_Plural} for EVERYONE!! W IN THE CHAT`})
			end)
			return
		end
		
		if Data.Type == "GR10000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 10000 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 10K {Global_Plural} for EVERYONE!! W IN THE CHAT`})
			end)
			return
		end
		
		if Data.Type == "GR1000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 1000 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1K {Global_Plural} for EVERYONE!! GAWDAM`})
			end)
			return
		end
		
		if Data.Type == "GR100000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100000 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 100K {Global_Plural} for EVERYONE!! ??`})
			end)
			return
		end
		
		if Data.Type == "GR2500" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 2500 do
						GlobalRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 2500 {Global_Plural} for EVERYONE!! WHAT`})
			end)
			return
		end

		
		if Data.Type == "UR1" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					UltraRune.Roll(Player)
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1 {Ultra_Single} for EVERYONE!!`})
			end)
			return
		end

		if Data.Type == "UR50" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 50 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 50 {Ultra_Plural} for EVERYONE!!`})
			end)
			return
		end

		if Data.Type == "UR10" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 10 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 10 {Ultra_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "UR75" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 75 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 75 {Ultra_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "UR500" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 500 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 500 {Ultra_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "UR5000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 5000 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 5K {Ultra_Plural} for EVERYONE!! BTW USE CODE '<REDACTED>' :)`})
			end)
			return
		end
		
		if Data.Type == "UR50000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 50000 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 50K {Ultra_Plural} for EVERYONE!! YOU SHALL MAKE EVERYBODY LAG`})
			end)
			return
		end
		
		if Data.Type == "UR100" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 100 {Ultra_Plural} for EVERYONE!! HOLY`})
			end)
			return
		end
		
		if Data.Type == "UR7500" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 4000 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 7500 {Ultra_Plural} for EVERYONE!! WHAT THE HELLY`})
			end)
			return
		end
		
		if Data.Type == "UR2500" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 2500 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 2500 {Ultra_Plural} for EVERYONE!! WHAT`})
			end)
			return
		end
		
		if Data.Type == "UR100000" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100000 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 100000 {Ultra_Plural} for EVERYONE!! HOLY`})
			end)
			return
		end
		
		if Data.Type == "UR5" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 5 do
						UltraRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 5 {Ultra_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "GlobalElixir" then
			task.spawn(function()
				Messenger.SendAllClients({Message = `{ElixirPrefix} {Data.Sender} has activated a Global Elixir!`})
			end)
			
			return
		end
		
		if Data.Type == "GlobalElixirOver" then
			task.spawn(function()
				Messenger.SendAllClients({Message = `{ElixirPrefix} Global Elixir Boost has ran out!`})
			end)

			return
		end
			
			
		if Data.Type == "AR1" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					AncientRune.Roll(Player)
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1 {Ancient_Single} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR2" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 2 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 2 {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		
		if Data.Type == "AR10" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 10 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 10 {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR100" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 100 {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR1000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 1000 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1K {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR200" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 200 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 200 {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR10000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 10000 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 10K {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR2000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 2000 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 2000 {Ancient_Plural} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "AR100000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 100000 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} popped 100K Anc-.. ahh uh it lagged.. oh yeah also make sure to use code "BIGdrop".`})
			end)
			return
		end
		
		if Data.Type == "AR20000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 20000 do
						AncientRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 20000 {Ancient_Plural} for EVERYONE!! MAN...`})
			end)
			return
		end
		
		
		
		if Data.Type == "MR1" then
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					MadnessRune.Roll(Player)
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 1 {Madness_Single} for EVERYONE!!`})
			end)
			return
		end
		
		if Data.Type == "MR3" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 3 do
						MadnessRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 3 {Madness_Plural} for EVERYONE! "B O I N K"`})
			end)
			return
		end
		
		if Data.Type == "MR30" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 30 do
						MadnessRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 30 {Madness_Plural} for EVERYONE!!`})
			end)
			return
		end

		if Data.Type == "MR300" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 300 do
						MadnessRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 300 {Madness_Plural} for EVERYONE!!`})
			end)
			return
		end


		if Data.Type == "MR3000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 3000 do
						MadnessRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 3K {Madness_Plural} for EVERYONE!! WHOA`})
			end)
			return
		end

		if Data.Type == "MR30000" then 
			task.spawn(function()
				for _ , Player in Players:GetPlayers() do
					for i = 1, 30000 do
						MadnessRune.Roll(Player)
					end
				end

				Messenger.SendAllClients({Message = `{Prefix} {Data.Sender} has purchased 30K {Madness_Plural} for EVERYONE!! WOOOO`})
			end)
			return
		end


		

		if Data.Type == "System Message" then
			Messenger.SendAllClients(Data)
			return
		end
	end)
	
	function Messenger.SendClient(Player : Player, Data : {})
		MessageEvent:FireClient(Player, Data)
	end
	
	function Messenger.SendAllClients(Data : {})
		MessageEvent:FireAllClients(Data)
	end
	
	function Messenger.Publish(Data : {})
		local New_Data = HttpService:JSONEncode(Data)
		local succ, err = pcall(function()
			MessagingService:PublishAsync(Key, New_Data)
		end)
		if err then warn(`SERVER | MESSENGER | Error has occurred`, err) end
	end
end

--[ CLIENT-ONLY FUNCTIONS ]--
if RunService:IsClient() then
	function Messenger.Listener(func)
		return MessageEvent.OnClientEvent:Connect(func)
	end
end

return Messenger
