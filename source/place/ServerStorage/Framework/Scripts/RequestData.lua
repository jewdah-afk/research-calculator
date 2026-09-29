local Players = game:GetService("Players")

local Framework = require(game:GetService("ReplicatedStorage").Framework)
local Request_Data: RemoteFunction = Framework:GetEvent("Request_Data")

local RequestData = {}

local function validateData(PlayerName, dataType, FolderName, DataValue)

	assert(type(PlayerName) == "string", "Type error: PlayerName")
	
	local relatedPlayer = Players:FindFirstChild(PlayerName)
	if not relatedPlayer then warn("Can't find player with name: "..PlayerName) return false end
	
	local dataFolder = relatedPlayer:FindFirstChild(FolderName)
	if not dataFolder then warn("Can't find "..FolderName.." in data") return false end
	
	local rawData = dataFolder[dataType]
	
	if rawData.Value ~= DataValue or rawData.Value == false then return false end
	
	return true
end

Request_Data.OnServerInvoke = function(playerName, AscensionName, FolderName, ClientValue)
	return validateData(playerName.Name, AscensionName, FolderName, ClientValue)
end

return RequestData
