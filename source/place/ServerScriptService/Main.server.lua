local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
Framework:LoadServer()

--[ Leaderboards ]--
local Leaderboards = Framework:GetLibrary("Leaderboard")

local RuneStarring = require(game:GetService("ServerStorage").Framework.Modules.runeStarring)

RuneStarring.onEvent()

local Studio = game:GetService("RunService"):IsStudio() and "" or ""

--[ General Stats ]--
Leaderboards.New({
	StatsName = "Total_Energy";
	Key = "GlobalTotalEnergy_P2W_2" .. Studio;
	FolderName = "TotalEnergy_P2W";
	MaxItems = 50;
	P2WCheck = false;
})

Leaderboards.New({
	StatsName = "Total_Energy";
	Key = "GlobalTotalEnergy_F2P_2" .. Studio;
	FolderName = "TotalEnergy_F2P";
	MaxItems = 50;
	P2WCheck = true;
})



Leaderboards.New({
	StatsName = "Prisms";
	Key = "GlobalPrisms_P2W_1" .. Studio;
	FolderName = "Prisms_P2W";
	MaxItems = 50;
	P2WCheck = false;
})

Leaderboards.New({
	StatsName = "Prisms";
	Key = "GlobalPrisms_F2P_1" .. Studio;
	FolderName = "Prisms_F2P";
	MaxItems = 50;
	P2WCheck = true;
})

Leaderboards.New({
	StatsName = "Playtime";
	Key = "GlobalPlaytime_2" .. Studio;
	FolderName = "Playtime";
	MaxItems = 50;
})

Leaderboards.New({
	StatsName = "TierTwelveTime";
	Key = "TierTwelvePlaytime_2" .. Studio;
	FolderName = "TierTwelvePlaytime";
	MaxItems = 50;
},true,true)


--[ Runes ]--
Leaderboards.New({
	StatsName = "Runes_Opened";
	Key = "GlobalRunes_Opened_P2W_2" .. Studio;
	FolderName = "Runes_Opened_P2W";
	MaxItems = 50;
})

Leaderboards.New({
	StatsName = "Runes_Opened";
	Key = "GlobalRunes_Opened_F2P_2" .. Studio;
	FolderName = "Runes_Opened_F2P";
	MaxItems = 50;
	P2WCheck = true;
})

Leaderboards.New({
	StatsName = "RawRunes_Opened";
	Key = "GlobalRawRunes_Opened_2" .. Studio;
	FolderName = "RawRunes_Opened";
	MaxItems = 50;
},false,true)

--[ Robux Spent ]--
Leaderboards.New({
	StatsName = "RobuxSpent";
	Key = "GlobalRobuxSpent_2" .. Studio;
	FolderName = "RobuxSpent";
	MaxItems = 50;
},false,true)

