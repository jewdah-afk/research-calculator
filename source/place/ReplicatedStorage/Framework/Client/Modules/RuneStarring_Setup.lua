local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local Stats = Player:WaitForChild("Stats")

local Color_StarStage = Stats.Color_StarStage.Value
local Arctic_StarStage = Stats.Arctic_StarStage.Value
local Polychrome_StarStage = Stats.Polychrome_StarStage.Value
local Royal_StarStage = Stats.Royal_StarStage.Value

local runeStarring_Ui = PlayerGui:WaitForChild("RuneStarring")
local Holder = runeStarring_Ui.Holder

local Arctic = Holder.Arctic
local Color = Holder.Color
local Polychrome = Holder.Polychrome
local Royal = Holder.Royal

local Setup = {}

function Setup.init()
	
	for i, v in Color:GetChildren() do
		if not v:IsA("Frame") then continue end
		if v.Name == "Title" then 
			v.Star.Text = "[" .. Stats.Color_StarStage.Value .. "]"
			continue
		end
		v.Visible = false
	end
	
	for i, v in Arctic:GetChildren() do
		if not v:IsA("Frame") then continue end
		if v.Name == "Title" then 
			v.Star.Text = "[" .. Stats.Polychrome_StarStage.Value .. "]"
			continue
		end
		v.Visible = false
	end
	
	for i, v in Polychrome:GetChildren() do
		if not v:IsA("Frame") then continue end
		if v.Name == "Title" then 
			v.Star.Text = "[" .. Stats.Arctic_StarStage.Value .. "]"
			continue
		end
		v.Visible = false
	end
	
	for i, v in Royal:GetChildren() do
		if not v:IsA("Frame") then continue end
		if v.Name == "Title" then 
			v.Star.Text = "[" .. Stats.Royal_StarStage.Value .. "]"
			continue
		end
		v.Visible = false
	end

	
	
	Color[Color_StarStage == "Completed" and "Superstar" or Color_StarStage].Visible = true
	Arctic[Arctic_StarStage == "Completed" and "Superstar" or Arctic_StarStage].Visible = true
	Polychrome[Polychrome_StarStage == "Completed" and "Superstar" or Polychrome_StarStage].Visible = true
	Royal[Royal_StarStage == "Completed" and "Superstar" or Royal_StarStage].Visible = true
	
end

return Setup
