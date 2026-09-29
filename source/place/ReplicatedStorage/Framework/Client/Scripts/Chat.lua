local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")
local Messenger = Framework:GetLibrary("Messenger")
local replicatedStorage = Framework:GetService("ReplicatedStorage")
local textChatService = Framework:GetService("TextChatService")

local Player = Framework:GetPlayer()

local Chat = {}

function Chat.init()
	--[ GLOBAL MESSAGES] --
	Messenger.Listener(function(Data : {})
		Framework:SendClientMessage(Data.Message or "")
	end)
end

return Chat
