--[[ Framework ]]--
local Framework = require(game.ReplicatedStorage.Framework)

--[[ Modules ]]--

--[[ Variables ]]--
local Player = Framework:GetPlayer()

local Redeem_Code = Framework:GetEvent("Redeem_Code")

local ScreenGui = Framework.Gui.Store
local CodesGui = ScreenGui.Holder.Content.Codes
local ButtonsGui = ScreenGui.Holder.Buttons

local Codes = {}

function Codes.init()
	--if Player:GetAttribute("Link_Discord") then
		local RedeemBox = CodesGui.Redeem
		local TextBox = RedeemBox.TextBox
		
		TextBox.FocusLost:Connect(function()
			local Message = Redeem_Code:FireServer(TextBox.Text)
			
			if Message then
				RedeemBox.Notification.Text = Message or "null message"
			end
		end)
	--else
		--ButtonsGui.Codes:Destroy()
		--CodesGui:Destroy()
	--end
end

return Codes