
local Framework = require(game.ReplicatedStorage.Framework)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local EN = Framework:GetLibrary("EternityNum")
local Time = Framework:GetLibrary("Time")
local Popup = Framework:GetEvent("Popup")

local GlobalGoalsUI = workspace.Areas.Arctic:WaitForChild("GlobalGoals")
local GlobalGoalsStats = game.ReplicatedStorage:WaitForChild("GlobalGoals")
local GlobalGoalsLB = Framework:GetBindableEvent("GlobalGoalsLB")

local GlobalGoals = {
	DatastoreKey = "Global_Goals_Release",
	DatastoreObj = nil,
	Autosave = true,
	
	Goals = {
		Playtime = 50_000 * 60 * 60,
		Runes = 100_000_000,
		Robux = 100_000
	};
	
	CurrentLBList = {
		RobuxSpent = {},
		RawRunes_Opened = {},
		TierTwelveTime = {},
	}
}

local ElixirTable = {
	"StatsElixir", "StatsElixirDuration", "RuneLuckElixir", "RuneLuckElixirDuration", "RuneSpeedElixir", "RuneSpeedElixirDuration"
}

function GlobalGoals.onGoalReached(statName, steps)
	
	for i,player in game:GetService("Players"):GetPlayers() do 
		if player.Stats.Tier.Value >= 12 then 
			local elxir = ElixirTable[math.random(#ElixirTable)]
			player.Stats[elxir].Value += steps
			
			local OriginalMsg = "Global Goals: " .. statName .. " goal has been reached! You have been rewarded " .. steps .. " " .. elxir
			Popup:FireClient(player, "Success", OriginalMsg)
		end
	end
end

function GlobalGoals.saveData()	
	for _, stat in pairs(GlobalGoalsStats.Server:GetChildren()) do
		local tries = 0
		repeat
			
			local oldData
			local succ, err = pcall(function()
				GlobalGoals.DatastoreObj:UpdateAsync(stat.Name, function(Old_Data)
					Old_Data = if Old_Data then Old_Data else 0
					oldData = Old_Data
					return EN.toString(EN.add(Old_Data,stat.Value))
				end)
			end)

			if succ then
				--warn(`GLOBAL GOALS | DATASTORE has successfully saved  data.`)
				
				local newValue = EN.toNumber(EN.add(oldData, stat.Value))

				-- Check if goal has been surpassed at each milestone
				local goalStep = GlobalGoals.Goals[stat.Name]
				if goalStep then
					local oldMilestone = EN.div(oldData,goalStep)
					local newMilestone = EN.div(newValue,goalStep)
					local steps = math.floor(EN.toNumber(EN.sub(newMilestone,oldMilestone)))
					
					if steps > 0 then
						GlobalGoals.onGoalReached(stat.Name, steps)
					end
				end
				
				stat.Value = "0"
			end

			if err then
				tries += 1
				warn(`GLOBAL GOALS | DATASTORE | Error : {err}`)
			end
		until succ or tries == 6
	end
end

function GlobalGoals.loadData()
	for _, stat in pairs(GlobalGoalsStats.Server:GetChildren()) do
		
		local data;
		local succ, err = pcall(function()
			data = GlobalGoals.DatastoreObj:GetAsync(stat.Name)
		end)

		if succ then
			GlobalGoalsStats.Global[stat.Name].Value = data or "0"
		end

		if err then
			warn(`Error loading data for GlobalGoals : {err}`)
		end
	end
end

function GlobalGoals._AutoSave()
	task.spawn(function()
		local Timer = 0
		while GlobalGoals.Autosave do
			Timer += task.wait()
			if Timer >= 60*2 then
				Timer = 0
				GlobalGoals.saveData()
				GlobalGoals.loadData()
			end
		end
	end)
end

function GlobalGoals.onBindableEvent(userList, statName)
	GlobalGoals.CurrentLBList[statName] = userList
	
	for i,player in pairs(Players:GetPlayers()) do
		local index = table.find(GlobalGoals.CurrentLBList[statName], tostring(player.UserId))
		if statName == "RobuxSpent" then
			player.Stats.GGRobuxRank.Value = index or 0
		elseif statName == "RawRunes_Opened" then
			if index and player.Stats.GGRunesRank.Value == 0 then
				player.Stats.GGRunesTimer.Value = tick()
			end
			player.Stats.GGRunesRank.Value = index or 0
		else
			if index and player.Stats.GGPlaytimeRank.Value == 0 then
				player.Stats.GGPlaytimeTimer.Value = tick()
			end
			player.Stats.GGPlaytimeRank.Value = index or 0
		end
	end
end

function GlobalGoals._Update(deltTime)
	
	for i,v in ipairs(GlobalGoals.CurrentLBList.RawRunes_Opened) do 
		local player = Players:GetPlayerByUserId(v)
		if not player then continue end
		
		-- 60 * 60 * 24 seconds = 1 day 
		local day = 60 * 60 * 24
		local timeElapsed = tick() - player.Stats.GGRunesTimer.Value
		
		if timeElapsed > day then 
			local amount = math.floor((tick() - player.Stats.GGRunesTimer.Value)/day)
			player.Stats.ServerElixir.Value += (3-i+1) * amount
			player.Stats.GGRunesTimer.Value = tick()
			
			local OriginalMsg = "Global Goals: You have been rewarded " .. (3-i+1) * amount .. " ServerElixir"
			Popup:FireClient(player, "Success", OriginalMsg)
		end
		
	end
	
	for i,v in ipairs(GlobalGoals.CurrentLBList.TierTwelveTime) do 
		local player = Players:GetPlayerByUserId(v)
		if not player then continue end

		-- 60 * 60 * 24 seconds = 1 day 
		local day = 60 
		local timeElapsed = tick() - player.Stats.GGPlaytimeTimer.Value

		if timeElapsed > (day*i) then 
			local amount = math.floor((tick() - player.Stats.GGPlaytimeTimer.Value)/(day*i))
			player.Stats.GlobalElixir.Value += amount
			player.Stats.GGPlaytimeTimer.Value = tick()
			
			local OriginalMsg = "Global Goals: You have been rewarded " .. amount .. " GlobalElixir"
			Popup:FireClient(player, "Success", OriginalMsg)
		end

	end
	
end

function GlobalGoals.onPlayerJoin(player : Player)
	local userId = player.UserId
	
	if player.Stats.GGRunesRank.Value > 0 then
		local day = 60 * 60 * 24

		if tick() - player.Stats.GGRunesTimer.Value > day then 
			local amount = math.floor((tick() - player.Stats.GGRunesTimer.Value)/day)
			player.Stats.ServerElixir.Value += (3-player.Stats.GGPlaytimeRank.Value+1) * amount
			player.Stats.GGRunesTimer.Value = tick()
			
			local OriginalMsg = "Global Goals: You have been rewarded " .. (3-player.Stats.GGPlaytimeRank.Value+1) * amount .. " ServerElixir"
			Popup:FireClient(player, "Success", OriginalMsg)
		end
		
		player.Stats.GGRunesRank.Value = 0
	end
	
	if player.Stats.GGPlaytimeRank.Value > 0 then

		local day = 60 * 60 * 24

		if tick() - player.Stats.GGPlaytimeTimer.Value > (day*player.Stats.GGPlaytimeRank.Value) then 
			local amount = math.floor((tick() - player.Stats.GGRunesTimer.Value)/(day*player.Stats.GGPlaytimeRank.Value))
			player.Stats.GlobalElixir.Value += amount
			player.Stats.GGRunesTimer.Value = tick()
			
			local OriginalMsg = "Global Goals: You have been rewarded " .. amount .. " GlobalElixir"
			Popup:FireClient(player, "Success", OriginalMsg)
		end

		player.Stats.GGPlaytimeRank.Value = 0
	end
	
	local index = table.find(GlobalGoals.CurrentLBList.RobuxSpent, userId)
	if index then 
		player.Stats.GGRobuxRank.Value = index
	end
end

function GlobalGoals.noinit()
	GlobalGoals.DatastoreObj = DataStoreService:GetDataStore(GlobalGoals.DatastoreKey)
	
	GlobalGoalsStats.Global.Playtime:GetPropertyChangedSignal("Value"):Connect(function()
		local Amount = GlobalGoalsUI.PlaytimeGoal.SurfaceGui.Main.Amount
		local amountTime = EN.toNumber(EN.fromDefaultStringFormat(GlobalGoalsStats.Global.Playtime.Value))
		local hours = math.floor((amountTime / 60*60))

		Amount.Text = `{EN.toSuffix(hours)} HRS`
	end)

	GlobalGoalsStats.Global.Robux:GetPropertyChangedSignal("Value"):Connect(function()
		local Amount = GlobalGoalsUI.RobuxGoal.SurfaceGui.Main.Amount
		Amount.Text = `{EN.toSuffix(GlobalGoalsStats.Global.Robux.Value)}`
	end)

	GlobalGoalsStats.Global.Runes:GetPropertyChangedSignal("Value"):Connect(function()
		local Amount = GlobalGoalsUI.GlobalRunesGoal.SurfaceGui.Main.Amount
		Amount.Text = `{EN.toSuffix(GlobalGoalsStats.Global.Runes.Value)}`
	end)
	

	GlobalGoals.loadData()
	GlobalGoals.Autosave = true
	GlobalGoals._AutoSave()
	
	GlobalGoalsLB.Event:Connect(GlobalGoals.onBindableEvent)
	game:GetService("RunService").Heartbeat:Connect(GlobalGoals._Update)
end

--GlobalGoals.init()

return GlobalGoals
