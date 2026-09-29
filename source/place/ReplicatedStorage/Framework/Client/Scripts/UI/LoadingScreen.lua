local Framework = require(game.ReplicatedStorage.Framework)

local Player = Framework:GetPlayer()

local Gui = Framework.Gui
local Screen = Gui["Loading Screen"]
local Tip_Label = Screen.Canvas.BG.Tip

local LoadingScreen = {}
local Tips = {
	"I AM JUST HERE";
	"ME TOO";
}

function RandomizeTip()
	Tip_Label.Text = `TIP: {Tips[math.random(1,#Tips)]}`
end

function StartGame()
	if not Player.Stats.Tutorial_Finished.Value and Player.Stats.Playtime.Value < 300 then
		--print("new player detected")
	end
	
	Framework.Gui.Buttons.Enabled = true
	Framework.Gui.TierBar.Enabled = true
end

function LoadingScreen:init()
	task.spawn(function()
		local Timer = 0
		while Screen.Enabled do
			Timer += task.wait()
			if Timer >= 2.5 then
				Timer = 0
				RandomizeTip()
			end
		end
		StartGame()
	end)
end

return LoadingScreen