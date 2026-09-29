local Framework = require(game.ReplicatedStorage.Framework)
local EN = Framework:GetLibrary("EternityNum")
local Runes = Framework:GetLibrary("Runes")
local Formulas = Framework:GetSharedModule("Formulas")
local Cooldowns = Framework:GetSharedModule("Cooldowns")
local Popup = Framework:GetEvent("Popup")
local Rune_Reward = Framework:GetEvent("Rune_Reward")
local Time = Framework:GetLibrary("Time")

local ChatCommands = {
	Cache = {};
}

function TypeCheck(Player : Player, Val1 : any, Val2 : any)
	Val1 = tonumber(Val1) or Val1

	if typeof(Val1) == "number" and typeof(Val2) == "string" then return true end

	if typeof(Val1) ~= typeof(Val2) then
		Popup:FireClient(Player, "Error", `{typeof(Val1)} value type error compared to {typeof(Val2)}`)
		return false
	end
end

function ChatCommands.Register(Player : Player)
	ChatCommands.Cache[Player.UserId] = Player.Chatted:Connect(function(message : string)
		local Prefix = message:find("/")
		if Prefix then
			local Parameters = string.split(message, "/")
			table.remove(Parameters, 1) -- Removes the Prefix cause yes
			Parameters = string.split(Parameters[1], " ")
			local Folder = Parameters[1]
			local Instance = Parameters[2]
			local New_Value = Parameters[3]

			local Player_Folder = Player:FindFirstChild(Folder)
			if not Player_Folder then Popup:FireClient(Player, "Error", `{Folder} not found!`) return end

			local Stat_Instance = Player_Folder:FindFirstChild(Instance)
			if not Stat_Instance then Popup:FireClient(Player, "Error", `{Instance} not found in {Folder}!`) return end

			Stat_Instance.Value = New_Value
			Popup:FireClient(Player, "Success", `You have successfully updated the {Instance} Value!`)
			return
		end

		local Timewarp_Prefix = message:find("!timewarp")
		if Timewarp_Prefix then
			local Parameters = string.split(message, "!timewarp")
			table.remove(Parameters, 1) -- Removes the Prefix cause yes
			Parameters = string.split(Parameters[1], " ")[2]

			--[ Magic Stuff Down Here ]--
			local Interval = math.max(tonumber(Parameters) or 1) -- Default and Minimum is 1s

			--[ Energy Interval ]--
			local Energy_Interval =  (1 / Cooldowns.Energy(Player)) * Interval
			local Energy_Gain = Formulas.Energy(Player, 1)
			local Energy_Warped = EN.mul(Energy_Gain, Energy_Interval)
			Player.Stats.Energy.Value = EN.toString(EN.add(Player.Stats.Energy.Value, Energy_Warped))

			--[ XP Interval ]
			if Player.Stats.Tier.Value >= 4 then
				local XP_Interval =  (1 / Cooldowns.XP(Player)) * Interval
				local XP_Gain = Formulas.XP(Player, 1)
				local XP_Warped = EN.mul(XP_Gain, XP_Interval)
				Player.Stats.XP.Value = EN.toString(EN.add(Player.Stats.XP.Value, XP_Warped))
			end

			--[ Orbs Interval ]
			if Player.Stats.Tier.Value >= 7 then
				local Orbs_Interval =  (1 / Cooldowns.Orbs(Player)) * Interval
				local Orbs_Gain = Formulas.Orbs(Player, 1)
				local Orbs_Warped = EN.mul(Orbs_Gain, Orbs_Interval)
				Player.Stats.Orbs.Value = EN.toString(EN.add(Player.Stats.Orbs.Value, Orbs_Warped))
			end

			--[ Spheres Interval ]
			if Player.Stats.Tier.Value >= 9 then
				local Spheres_Interval =  (1 / Cooldowns.Spheres(Player)) * Interval
				local Spheres_Gain = Formulas.Spheres(Player, 1)
				local Spheres_Warped = EN.mul(Spheres_Gain, Spheres_Interval)
				Player.Stats.Spheres.Value = EN.toString(EN.add(Player.Stats.Spheres.Value, Spheres_Warped))
			end

			--[ Runes ]--
			local Rune_Button = Player:GetAttribute("Rune_Button")
			if Rune_Button then
				--[ Check Luck ]--
				local Luck = 1
				if Player.Settings.RuneLuck.Value then Luck = Formulas.Rune_Luck(Player) end
				local Rune_Class = Runes(Rune_Button)
				local Stat = Player.Stats[Rune_Class.Currency]
				local Cost = Rune_Class.Cost
				local Bulk = math.clamp(Formulas.Rune_Afford(Stat.Value, Cost), 0, Formulas.RPS(Formulas.Rune_Bulk(Player,false,Rune_Class.Name), Formulas.Rune_Speed(Player))  * Interval)

				if Bulk > 0 then
					local Rune_Result = Rune_Class:GetResult(Luck, Bulk, Player)
					Stat.Value = EN.toString(EN.sub(Stat.Value, EN.mul(Rune_Class.Cost, Bulk)))
					Player.Stats[`{Rune_Button}_Opened`].Value += Bulk
					Player.Stats.Runes_Opened.Value += Bulk

					Rune_Reward:FireClient(Player, Rune_Result.Rewards)
				end
			end

			Popup:FireClient(Player, "Success", `You have successfully time warped {Time(Interval, true)}!`)
		end

		local ResetData_Prefix = message:find("!resetdata")
		if ResetData_Prefix then
			for _, Stat in Player.Stats:GetChildren() do
				if Stat and Stat:IsA("NumberValue") then Stat.Value = 0 end
				if Stat and Stat:IsA("BoolValue") then Stat.Value = false end
			end

			for _, Gamepass in Player.Gamepasses:GetChildren() do
				if Gamepass then Gamepass.Value = false end
			end

			for _, Rune in Player.Runes:GetChildren() do
				if Rune then Rune.Value = 0 end
			end

			for _, Upgrade in Player.Upgrades:GetChildren() do
				if Upgrade then Upgrade.Value = 0 end
			end
		end
	end)
end

function ChatCommands.Remove(Player : Player)
	local Reference = ChatCommands.Cache[Player.UserId]
	if Reference then
		Reference:Disconnect()
		ChatCommands.Cache[Player.UserId] = nil
	end
end

return ChatCommands