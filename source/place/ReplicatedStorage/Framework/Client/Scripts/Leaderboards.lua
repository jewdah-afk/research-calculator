local Framework = require(game.ReplicatedStorage.Framework)
local ReplicatedStorage = Framework:GetService("ReplicatedStorage")
local EN = Framework:GetLibrary("EternityNum")
local Thumbnail_Lib = Framework:GetLibrary("Thumbnail")
local Time = Framework:GetLibrary("Time")
local Get_TierData = Framework:GetEvent("Get_TierData") :: RemoteFunction

--local GlobalGoalsModule = Framework:GetClientModule("GlobalGoals")

local HOF = workspace.HallOfFame

local Playtime_LB = HOF.Playtime
local RobuxSpent_LB = HOF.RobuxSpent
local RunesOpened_LB = HOF.RunesOpened
local TotalEnergy_LB = HOF.TotalEnergy
local Prisms_LB = HOF.CurrentPrisms
local LB_Data = ReplicatedStorage:WaitForChild("Leaderboards", 10):WaitForChild("AnyTier")
local Tier12_LB_Data = ReplicatedStorage.Leaderboards:WaitForChild("TierTwelve")

local LeaderboardUpdate = Framework:GetEvent("LeaderboardUpdate") :: RemoteEvent

local ClearLBs = Framework:GetEvent("ClearLBs")


--local GlobalGoals = GlobalGoalsModule.GlobalGoalsModule()
--local RobuxSpentLB2 = GlobalGoals.RobuxGoal
--local TimePlayedLB2 = GlobalGoals.PlaytimeGoal
--local RunesOpenedLB2 = GlobalGoals.GlobalRunesGoal

local module = {}

function module.init()
	task.spawn(function()
		--[ Total Energy P2W LB ]--
		local function AddP2WFrame_Energy(child : Instance)
			local Template = script.Energy_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} TOTAL ENERGY`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = TotalEnergy_LB.SurfaceGui.Main.Content_P2W.Players
		end

		if LB_Data:FindFirstChild("TotalEnergy_P2W") then
			for _ , v in LB_Data.TotalEnergy_P2W:GetChildren() do
				AddP2WFrame_Energy(v)
			end

			LB_Data.TotalEnergy_P2W.ChildAdded:Connect(function(child)
				AddP2WFrame_Energy(child)
			end)
		end

		TotalEnergy_LB.SurfaceGui.Main.P2W.Activated:Connect(function()
			TotalEnergy_LB.SurfaceGui.Main.Content_F2P.Visible = false
			TotalEnergy_LB.SurfaceGui.Main.Content_P2W.Visible = true
		end)

		--[ Total Energy F2P LB ]--
		local function AddF2PFrame_Energy(child : Instance)
			local Template = script.Energy_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} TOTAL ENERGY`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = TotalEnergy_LB.SurfaceGui.Main.Content_F2P.Players
		end

		for _ , v in LB_Data.TotalEnergy_F2P:GetChildren() do
			AddF2PFrame_Energy(v)
		end

		LB_Data.TotalEnergy_F2P.ChildAdded:Connect(function(child)
			AddF2PFrame_Energy(child)
		end)

		TotalEnergy_LB.SurfaceGui.Main.F2P.Activated:Connect(function()
			TotalEnergy_LB.SurfaceGui.Main.Content_F2P.Visible = true
			TotalEnergy_LB.SurfaceGui.Main.Content_P2W.Visible = false
		end)
		
		
		
		--[ Total Prisms P2W LB ]--
		local function AddP2WFrame_Prisms(child : Instance)
			local Template = script.Prisms_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} PRISMS`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = Prisms_LB.SurfaceGui.Main.Content_P2W.Players
		end

		for _ , v in LB_Data.Prisms_P2W:GetChildren() do
			AddP2WFrame_Prisms(v)
		end

		LB_Data.Prisms_P2W.ChildAdded:Connect(function(child)
			AddP2WFrame_Prisms(child)
		end)

		Prisms_LB.SurfaceGui.Main.P2W.Activated:Connect(function()
			Prisms_LB.SurfaceGui.Main.Content_F2P.Visible = false
			Prisms_LB.SurfaceGui.Main.Content_P2W.Visible = true
		end)

		--[ Total Prisms F2P LB ]--
		local function AddF2PFrame_Prisms(child : Instance)
			local Template = script.Prisms_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} PRISMS`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = Prisms_LB.SurfaceGui.Main.Content_F2P.Players
		end

		for _ , v in LB_Data.Prisms_F2P:GetChildren() do
			AddF2PFrame_Prisms(v)
		end

		LB_Data.Prisms_F2P.ChildAdded:Connect(function(child)
			AddF2PFrame_Prisms(child)
		end)

		Prisms_LB.SurfaceGui.Main.F2P.Activated:Connect(function()
			Prisms_LB.SurfaceGui.Main.Content_F2P.Visible = true
			Prisms_LB.SurfaceGui.Main.Content_P2W.Visible = false
		end)
		
		
		--[ Total Robux Spent LB ]--
		local function AddFrame_RobuxSpent(child : Instance, Parent)
			local Template = script.RobuxSpent_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `R${EN.Format(child:GetAttribute("Amount"))} SPENT`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = Parent
		end
		
		
		local function RobuxSpentIdk(Frame, v)
			local Data = Get_TierData:InvokeServer(v:GetAttribute("Username"))
			
			if Data then
				Frame.Amount.Text = `{EN.Format(v:GetAttribute("Amount"))} ROBUX SPENT`
				Frame.Username.Text = v:GetAttribute("Username") or ""
			else
				Frame.Amount.Text = `0 ROBUX SPENT`
				Frame.Username.Text = "None"
			end
		end

		for _ , v: Instance in LB_Data.RobuxSpent:GetChildren() do
			AddFrame_RobuxSpent(v, RobuxSpent_LB.SurfaceGui.Main.Content.Players)
			--local Frame = RobuxSpentLB2.SurfaceGui.Main.TopContributors:FindFirstChild(v:GetAttribute("Pos"))
		--	if Frame then
		--		RobuxSpentIdk(Frame,v)
			--end
		end
		
		LB_Data.RobuxSpent.ChildAdded:Connect(function(child)
			AddFrame_RobuxSpent(child, RobuxSpent_LB.SurfaceGui.Main.Content.Players)
			--local Frame = RobuxSpentLB2.SurfaceGui.Main.TopContributors:FindFirstChild(child:GetAttribute("Pos"))
			--if Frame then
			--	RobuxSpentIdk(Frame,child)
			--end
		end)

		LB_Data.RobuxSpent.ChildAdded:Connect(function(child)
			AddFrame_RobuxSpent(child, RobuxSpent_LB.SurfaceGui.Main.Content.Players)
		end)
		

		--[ Top Playtime LB ]--
		local function AddFrame_Playtime(child : Instance)
			local Template = script.Playtime_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{Time(child:GetAttribute("Amount"), true)}`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = Playtime_LB.SurfaceGui.Main.Content.Players
		end
		
		local function TimePlayedidk(Frame, v)
			local Data = Get_TierData:InvokeServer(v:GetAttribute("Username"))
			
			if Data then
				Frame.Amount.Text = `{Time(v:GetAttribute("Amount"), true)}`
				Frame.Username.Text = v:GetAttribute("Username") or ""
			else
				Frame.Amount.Text = `{Time(0, true)}`
				Frame.Username.Text = "None"
			end
		end

		for _ , v in LB_Data.Playtime:GetChildren() do
			AddFrame_Playtime(v)
		--	local Frame = TimePlayedLB2.SurfaceGui.Main.TopContributors:FindFirstChild(v:GetAttribute("Pos"))
		--	if Frame then
			--	TimePlayedidk(Frame,v)
		--	end
		end

		LB_Data.Playtime.ChildAdded:Connect(function(child)
			AddFrame_Playtime(child)
			--local Frame = TimePlayedLB2.SurfaceGui.Main.TopContributors:FindFirstChild(child:GetAttribute("Pos"))
			--if Frame then
		--		TimePlayedidk(Frame,child)
		--	end
		end)



		--[ Top Runes Opened F2P LB ]--
		local function AddFrame_Rune(child : Instance)
			local Template = script.Rune_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} RUNES OPENED`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = RunesOpened_LB.SurfaceGui.Main.Content_F2P.Players
		end
		
		local function RuneOpenedidk(Frame, v)
			local Data = Get_TierData:InvokeServer(v:GetAttribute("Username"))
			
			if Data then
				Frame.Amount.Text = `{EN.Format(v:GetAttribute("Amount"))} RUNES OPENED`
				Frame.Username.Text = v:GetAttribute("Username") or ""
			else
				Frame.Amount.Text = `0 RUNES OPENED`
				Frame.Username.Text = "None"
			end
		end

		for _ , v in LB_Data.Runes_Opened_F2P:GetChildren() do
			AddFrame_Rune(v)
			--local Frame = RunesOpenedLB2.SurfaceGui.Main.TopContributors:FindFirstChild(v:GetAttribute("Pos"))
			--if Frame then
			--	RuneOpenedidk(Frame,v)
		--	end
			
		end

		LB_Data.Runes_Opened_F2P.ChildAdded:Connect(function(child)
			AddFrame_Rune(child)
		--	local Frame = RunesOpenedLB2.SurfaceGui.Main.TopContributors:FindFirstChild(child:GetAttribute("Pos"))
		--	if Frame then
		--		RuneOpenedidk(Frame,child)
		--	end
		end)

		RunesOpened_LB.SurfaceGui.Main.F2P.Activated:Connect(function()
			RunesOpened_LB.SurfaceGui.Main.Content_F2P.Visible = true
			RunesOpened_LB.SurfaceGui.Main.Content_NoBulk.Visible = false
			RunesOpened_LB.SurfaceGui.Main.Content_P2W.Visible = false
		end)


		--[ Top Runes Opened P2W LB ]--
		local function AddFrame_RuneP2W(child : Instance)
			local Template = script.Rune_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} RUNES OPENED`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = RunesOpened_LB.SurfaceGui.Main.Content_P2W.Players
		end

		for _ , v in LB_Data.Runes_Opened_P2W:GetChildren() do
			AddFrame_RuneP2W(v)
		end

		LB_Data.Runes_Opened_P2W.ChildAdded:Connect(function(child)
			AddFrame_RuneP2W(child)
		end)

		RunesOpened_LB.SurfaceGui.Main.P2W.Activated:Connect(function()
			RunesOpened_LB.SurfaceGui.Main.Content_F2P.Visible = false
			RunesOpened_LB.SurfaceGui.Main.Content_NoBulk.Visible = false
			RunesOpened_LB.SurfaceGui.Main.Content_P2W.Visible = true
		end)



		--[ Top Runes Opened No Bulk LB ]--
		local function AddFrame_RuneRaw(child : Instance)
			local Template = script.Rune_Template:Clone()
			Template.Spot.Text = `#{child:GetAttribute("Pos")}`
			Template.Amount.Text = `{EN.Format(child:GetAttribute("Amount"))} RUNES OPENED`
			Template.Username.Text = child:GetAttribute("Username") or ""
			Template.LayoutOrder = child:GetAttribute("Pos") or 99

			local UserId = tonumber(child.Name)
			local Thumbnail = Thumbnail_Lib.New(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			Template.Icon.Image = Thumbnail or "rbxassetid://0"

			child.AncestryChanged:Connect(function() -- Likely refreshed lb
				Template:Destroy()
			end)

			Template.Parent = RunesOpened_LB.SurfaceGui.Main.Content_NoBulk.Players
		end

		LB_Data.RawRunes_Opened.ChildAdded:Connect(function(child)
			AddFrame_RuneRaw(child)
		end)

		RunesOpened_LB.SurfaceGui.Main.NoBulk.Activated:Connect(function()
			RunesOpened_LB.SurfaceGui.Main.Content_F2P.Visible = false
			RunesOpened_LB.SurfaceGui.Main.Content_NoBulk.Visible = true
			RunesOpened_LB.SurfaceGui.Main.Content_P2W.Visible = false
		end)
		
		
		--[ Leaderboard Clearing ]--
		ClearLBs.OnClientEvent:Connect(function()
			for _ , v in RunesOpened_LB.SurfaceGui.Main.Content_F2P:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in RunesOpened_LB.SurfaceGui.Main.Content_NoBulk:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in RunesOpened_LB.SurfaceGui.Main.Content_P2W:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in Playtime_LB.SurfaceGui.Main.Content:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in RobuxSpent_LB.SurfaceGui.Main.Content:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in TotalEnergy_LB.SurfaceGui.Main.Content_F2P:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
			
			for _ , v in TotalEnergy_LB.SurfaceGui.Main.Content_P2W:GetChildren() do
				if v:IsA("Frame") then v:Destroy() end
			end
		end)
		
		
		--local GlobalGoals = workspace.Areas.Arctic:WaitForChild("GlobalGoals")
		
		--local function globalRunesGoals()
		--	local GlobalRunesGoals = GlobalGoals:WaitForChild("GlobalRunesGoal")
		--	local Contributers = GlobalRunesGoals.SurfaceGui.Main.TopContributors
			
		--	local TopRunePlayers = Tier12_LB_Data.RawRunes_Opened:GetChildren()
		--	local index = 1
			
		--	for _,frame in pairs(Contributers:GetChildren()) do
		--		if not frame:IsA("Frame") then continue end 
		--		local playerStats = TopRunePlayers[tonumber(frame.Name)]
				
		--		if not playerStats then 
		--			frame.Visible = false
		--			continue
		--		end
				
		--		frame.Visible = true
				
		--		frame.Amount.Text = `{EN.Format(playerStats:GetAttribute("Amount"))} RUNES OPENED`
		--		frame.Username.Text = playerStats:GetAttribute("Username") or ""
				
		--		index += 1
		--	end
		--end
		
		--local function playtimeGoal()
		--	local GlobalRunesGoals = GlobalGoals:WaitForChild("PlaytimeGoal")
		--	local Contributers = GlobalRunesGoals.SurfaceGui.Main.TopContributors

		--	local TopRunePlayers = Tier12_LB_Data.TierTwelvePlaytime:GetChildren()
		--	local index = 1

		--	for _,frame in pairs(Contributers:GetChildren()) do
		--		if not frame:IsA("Frame") then continue end 
		--		local playerStats = TopRunePlayers[tonumber(frame.Name)]

		--		if not playerStats then 
		--			frame.Visible = false
		--			continue
		--		end

		--		frame.Visible = true

		--		frame.Amount.Text = `{Time(playerStats:GetAttribute("Amount"), true)}`
		--		frame.Username.Text = playerStats:GetAttribute("Username") or ""

		--		index += 1
		--	end
		--end
		
		--local function robuxGoal()
		--	local GlobalRunesGoals = GlobalGoals:WaitForChild("RobuxGoal")
		--	local Contributers = GlobalRunesGoals.SurfaceGui.Main.TopContributors

		--	local TopRunePlayers = Tier12_LB_Data.RobuxSpent:GetChildren()
		--	local index = 1

		--	for _,frame in pairs(Contributers:GetChildren()) do
		--		if not frame:IsA("Frame") then continue end 
		--		local playerStats = TopRunePlayers[tonumber(frame.Name)]

		--		if not playerStats then 
		--			frame.Visible = false
		--			continue
		--		end

		--		frame.Visible = true

		--		frame.Amount.Text = `{EN.Format(playerStats:GetAttribute("Amount"))} ROBUX SPENT`
		--		frame.Username.Text = playerStats:GetAttribute("Username") or ""

		--		index += 1
		--	end
		--end
		
		LeaderboardUpdate.OnClientEvent:Connect(function()
			--globalRunesGoals()
			--playtimeGoal()
			--robuxGoal()
		end)
	end)
end

return module
