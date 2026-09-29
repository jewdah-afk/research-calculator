local Framework = require(game.ReplicatedStorage.Framework)
local Players = Framework:GetService("Players")

local Cache = {}
local Thumbnail = {}

function Thumbnail.New(UserId : number, ThumbnailType : Enum.ThumbnailType, ThumbnailSize : Enum.ThumbnailSize)
	if Cache[UserId] then return Cache[UserId] end
	
	local ThumbnailURL = "rbxassetid://0"
	local succ, err = pcall(function()
		ThumbnailURL = Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if succ then Cache[UserId] = ThumbnailURL end
	
	return ThumbnailURL
end

return Thumbnail
