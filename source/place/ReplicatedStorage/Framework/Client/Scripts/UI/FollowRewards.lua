--[[ FRAMEWORK ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ SERVICES ]]--
local HttpService = Framework:GetService("HttpService")
local Players = Framework:GetService("Players")

--[ Events ]--
local Follow_Request = Framework:GetEvent("Follow_Request")

--[[ VARIABLES ]]--
local Player = Framework:GetPlayer()
local PlayerGui = Framework.Gui
local Screen = PlayerGui.FollowRewards
local People = Screen.Holder.People

local FollowData = {
	{User = "AknDevs", Button = People.Akn.Check, Frame = People.Akn.Icon, Request_Name = "Akn_Follow"};
	{User = "Icyy0vrdsd", Button = People.Icyy.Check, Frame = People.Icyy.Icon, Request_Name = "Icy_Follow"};
	{User = "irismwh", Button = People.Iris.Check, Frame = People.Iris.Icon, Request_Name = "Iris_Follow"};
	{User = "AylaDevs", Button = People.Ayla.Check, Frame = People.Ayla.Icon, Request_Name = "Ayla_Follow"};
	{User = "LuffyReformed", Button = People.Luffy.Check, Frame = People.Luffy.Icon, Request_Name = "Luffy_Follow"};
	{User = "DracoBullets", Button = People.Draco.Check, Frame = People.Draco.Icon, Request_Name = "Draco_Follow"};
	{User = "nexoAxl10", Button = People.Nexo.Check, Frame = People.Nexo.Icon, Request_Name = "Nexo_Follow"};
}


function UpdateProfile(Frame, User)
	local succ, err = pcall(function()
		local UserId = Players:GetUserIdFromNameAsync(User)
		if UserId then
			local ThumbnailURL = Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Frame.Image = ThumbnailURL
		else
			warn("Failed to find the UserId for "..User)
		end
	end)
	if err then warn(`Error setting Image for {User} in Follow Rewards.`) end
end

local FollowRewards = {}

function FollowRewards:init()
	task.spawn(function()
		for _, Data in FollowData do
			UpdateProfile(Data.Frame, Data.User)

			Data.Button.Activated:Connect(function()
				Follow_Request:FireServer(Data.Request_Name)
			end)

			local function Update()
				Data.Button.Visible = not Player.Stats[Data.Request_Name].Value
			end

			Update()
			Player.Stats[Data.Request_Name]:GetPropertyChangedSignal("Value"):Connect(Update)
			task.wait(1)
		end
	end)

end

return FollowRewards