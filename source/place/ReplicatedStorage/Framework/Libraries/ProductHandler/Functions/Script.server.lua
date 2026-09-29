local Framework = require(game.ReplicatedStorage.Framework)
local Messenger = Framework:GetLibrary("Messenger")
Messenger.Publish({
	Sender = "Cookie";
	Type = "MR1000"
})