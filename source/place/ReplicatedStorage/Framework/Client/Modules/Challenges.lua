local Framework = require(game.ReplicatedStorage.Framework)
--[ Libraries ]--
local EN = Framework:GetLibrary("EternityNum")
--[ Events ]--
local Enter_Challenge = Framework:GetEvent("Enter_Challenge")
--[ Modules ]--

--[ Variables ]--
local Player = Framework:GetPlayer()
local Layer = workspace.Layers.Challenges
local ChallengesBoard = Layer.Challenges.SurfaceGui.Main.Challenges

local Challenges = {}

function Challenges.Toggle(HasReq : boolean)
	if HasReq then
		Layer.Parent = workspace.Layers
		return
	end
	
	Layer.Parent = game.ReplicatedStorage.Layers_Storage
end

function Challenges.Update()
	
	local ChallengesCompleted = 0
	
	--[ Challenge One ]--
	if Player.Stats.CurrentChallenge.Value == "C1" then
		ChallengesBoard.C1.Start.Upgrade.Text = "EXIT"
	else
		ChallengesBoard.C1.Start.Upgrade.Text = "START"
	end
	
	ChallengesBoard.C1.Start.Visible = not Player.Stats.C1.Value
	
	if Player.Stats.C1.Value then
		ChallengesCompleted += 1
	end
	
	
	--[ Challenge Two ]--
	ChallengesBoard.C2.Visible = Player.Stats.C1.Value
	if Player.Stats.CurrentChallenge.Value == "C2" then
		ChallengesBoard.C2.Start.Upgrade.Text = "EXIT"
	else
		ChallengesBoard.C2.Start.Upgrade.Text = "START"
	end

	ChallengesBoard.C2.Start.Visible = not Player.Stats.C2.Value
	if Player.Stats.C2.Value then
		ChallengesCompleted += 1
	end
	
	
	--[ Challenge Three ]--
	ChallengesBoard.C3.Visible = Player.Stats.C2.Value
	if Player.Stats.CurrentChallenge.Value == "C3" then
		ChallengesBoard.C3.Start.Upgrade.Text = "EXIT"
	else
		ChallengesBoard.C3.Start.Upgrade.Text = "START"
	end
	ChallengesBoard.C3.Start.Visible = not Player.Stats.C3.Value
	
	if Player.Stats.C3.Value then
		ChallengesCompleted += 1
	end
	
	
	--[ Challenge Four ]--
	ChallengesBoard.C4.Visible = Player.Stats.C3.Value
	if Player.Stats.CurrentChallenge.Value == "C4" then
		ChallengesBoard.C4.Start.Upgrade.Text = "EXIT"
	else
		ChallengesBoard.C4.Start.Upgrade.Text = "START"
	end
	ChallengesBoard.C4.Start.Visible = not Player.Stats.C4.Value
	
	if Player.Stats.C4.Value then
		ChallengesCompleted += 1
	end
	
	ChallengesBoard.Parent.Completed.Text = `{ChallengesCompleted}/4 Challenges Completed`
end

local db = false

ChallengesBoard.C1.Start.Activated:Connect(function()
	if not db then
		db = true
		Enter_Challenge:FireServer("C1")
		task.wait(1)
		db = false
	end
end)

ChallengesBoard.C2.Start.Activated:Connect(function()
	if not db then
		db = true
		Enter_Challenge:FireServer("C2")
		task.wait(1)
		db = false
	end
end)

ChallengesBoard.C3.Start.Activated:Connect(function()
	if not db then
		db = true
		Enter_Challenge:FireServer("C3")
		task.wait(1)
		db = false
	end
	
end)

ChallengesBoard.C4.Start.Activated:Connect(function()
	if not db then
		db = true
		Enter_Challenge:FireServer("C4")
		task.wait(1)
		db = false
	end
end)

return Challenges
