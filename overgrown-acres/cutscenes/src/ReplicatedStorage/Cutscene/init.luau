-- Client-side cutscene player.
--
-- Cutscenes are plain data (see the Cutscenes folder): a list of actors and a
-- list of steps. The camera stays third person and keeps the player and NPCs in
-- frame, and lines appear in a dialogue box just above the inventory.
--
-- Usage (LocalScript):
--   local Cutscene = require(ReplicatedStorage.Cutscene)
--   local result = Cutscene.Play(require(ReplicatedStorage.Cutscene.Cutscenes.RowanAtTheFire))
--   -- result is "Completed", "Skipped", "Busy" or "Failed"

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local CameraDirector = require(script.CameraDirector)
local Config = require(script.Config)
local DialogueUI = require(script.DialogueUI)
local Util = require(script.Util)

local LocalPlayer = Players.LocalPlayer
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value + 50
local FIND_TIMEOUT = 5

local Cutscene = {}

local ui = nil
local playing = false

-- Helpers ---------------------------------------------------------------------

local function findByPath(path: string): Instance?
	local node: Instance? = game
	for name in string.gmatch(path, "[^%.]+") do
		if not node then
			return nil
		end
		-- WaitForChild so NPCs that are still streaming in can be found.
		node = if node == game then game:GetService(name) else node:WaitForChild(name, FIND_TIMEOUT)
	end
	return node
end

local function findMarker(name: string?): CFrame?
	if not name then
		return nil
	end
	local folder = Workspace:FindFirstChild(Config.MarkersFolder)
	local marker = folder and folder:FindFirstChild(name, true)
	if not marker then
		return nil
	elseif marker:IsA("BasePart") then
		return marker.CFrame
	elseif marker:IsA("Attachment") then
		return marker.WorldCFrame
	elseif marker:IsA("Model") then
		return marker:GetPivot()
	end
	return nil
end

local function getAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator
end

local function playAnimation(model: Model, id: string?, looped: boolean?, priority: Enum.AnimationPriority?): AnimationTrack?
	if not id or id == "" then
		return nil
	end
	local animator = getAnimator(model)
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn("[Cutscene] Couldn't load animation " .. id .. ": " .. tostring(track))
		return nil
	end
	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Action
	track:Play(0.2)
	return track
end

local function hideLocally(ctx, model: Model)
	local saved = {}
	local function set(item: Instance, property: string, value: any)
		table.insert(saved, { item, property, (item :: any)[property] })
		(item :: any)[property] = value
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			set(item, "LocalTransparencyModifier", 1)
			-- Also turn off collisions locally so stand-ins don't bump into the hidden original.
			set(item, "CanCollide", false)
		elseif item:IsA("Decal") then
			set(item, "LocalTransparencyModifier", 1)
		elseif item:IsA("ProximityPrompt") or item:IsA("BillboardGui") then
			set(item, "Enabled", false)
		end
	end
	table.insert(ctx.cleanups, function()
		for _, entry in saved do
			local item = entry[1]
			if item.Parent then
				(item :: any)[entry[2]] = entry[3]
			end
		end
	end)
end

-- NPCs are owned by the server, so the client can't move them reliably.
-- Instead, a local copy acts in the scene while the real one is hidden.
local function makeStandIn(ctx, original: Model, folder: Folder): Model
	local wasArchivable = original.Archivable
	original.Archivable = true
	local standIn = original:Clone()
	original.Archivable = wasArchivable

	for _, item in standIn:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ProximityPrompt") then
			item:Destroy()
		end
	end
	standIn.Parent = folder
	hideLocally(ctx, original)
	return standIn
end

local function resolvePosition(ctx, target): Vector3?
	if typeof(target) == "Vector3" then
		return target
	end
	local actor = ctx.actors[target]
	if actor then
		return actor:GetPivot().Position
	end
	local cf = findMarker(target)
	return cf and cf.Position
end

local function shotKey(spec): string
	return table.concat({
		tostring(spec.Shot),
		tostring(spec.Marker or ""),
		tostring(spec.A or ""),
		tostring(spec.B or ""),
		tostring(spec.From or ""),
		tostring(spec.To or ""),
		tostring(spec.Subject or ""),
		tostring(spec.Side or ""),
	}, "|")
end

local function resolveShot(ctx, spec)
	local kind = spec.Shot
	local shot
	if kind == "Marker" then
		local cf = findMarker(spec.Marker)
		if cf then
			shot = { Kind = "Marker", CFrame = cf, Subjects = {} }
		end
	elseif kind == "TwoShot" then
		local a, b = ctx.actors[spec.A or "Player"], ctx.actors[spec.B]
		if a and b then
			shot = { Kind = "TwoShot", A = a, B = b, Subjects = { a, b } }
		end
	elseif kind == "OverShoulder" then
		local from, to = ctx.actors[spec.From or "Player"], ctx.actors[spec.To]
		if from and to then
			shot = { Kind = "OverShoulder", From = from, To = to, Subjects = { from, to } }
		end
	elseif kind == "CloseUp" then
		local subject = ctx.actors[spec.Subject]
		if subject then
			shot = { Kind = "CloseUp", Subject = subject, Subjects = { subject } }
		end
	end

	if not shot then
		if spec.Fallback then
			return resolveShot(ctx, spec.Fallback)
		end
		return nil
	end
	shot.Side = spec.Side
	shot.FieldOfView = spec.FieldOfView
	shot.Key = shotKey(spec)
	return shot
end

local function setShot(ctx, spec, defaultBlend: number?): boolean
	local shot = resolveShot(ctx, spec)
	if not shot then
		warn("[Cutscene] Couldn't set up shot " .. shotKey(spec) .. " (missing actor or marker)")
		return false
	end
	local blend = spec.Time or defaultBlend or Config.Camera.BlendTime
	if ctx.skipped then
		blend = 0
	end
	ctx.camera:SetShot(shot, blend)
	ctx.shot = shot
	return true
end

local function faceTowards(ctx, model: Model, position: Vector3, time: number)
	local pivot = model:GetPivot()
	local flat = Vector3.new(position.X, pivot.Position.Y, position.Z)
	if (flat - pivot.Position).Magnitude < 0.05 then
		return
	end
	local goal = CFrame.lookAt(pivot.Position, flat)
	if time <= 0 or ctx.skipped then
		model:PivotTo(goal)
		return
	end
	local elapsed = 0
	while elapsed < time and not ctx.skipped do
		elapsed += task.wait()
		model:PivotTo(pivot:Lerp(goal, Util.easeInOut(math.min(elapsed / time, 1))))
	end
	model:PivotTo(goal)
end

local function moveActor(ctx, model: Model, position: Vector3, step)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local isPlayer = model == ctx.actors.Player
	local info = ctx.info[step.Actor] or {}

	local walk = nil
	if not isPlayer then
		walk = playAnimation(model, info.WalkAnimation or Config.Actors.WalkAnimation, true, Enum.AnimationPriority.Movement)
		if humanoid then
			humanoid.WalkSpeed = step.Speed or Config.Actors.WalkSpeed
		end
	end

	if humanoid and root and root:IsA("BasePart") and not root.Anchored then
		local done = false
		local connection = humanoid.MoveToFinished:Connect(function()
			done = true
		end)
		humanoid:MoveTo(position)
		Util.wait(step.Timeout or 10, function()
			return done or ctx.skipped
		end)
		connection:Disconnect()
	else
		-- Anchored NPCs can't walk, so glide them instead.
		local start = model:GetPivot()
		local goalPosition = Vector3.new(position.X, start.Position.Y, position.Z)
		local offset = goalPosition - start.Position
		if offset.Magnitude > 0.05 then
			local facing = CFrame.lookAt(start.Position, goalPosition)
			local duration = offset.Magnitude / (step.Speed or Config.Actors.WalkSpeed)
			local elapsed = 0
			while elapsed < duration and not ctx.skipped do
				elapsed += task.wait()
				model:PivotTo(facing + offset * math.min(elapsed / duration, 1))
			end
			model:PivotTo(facing + offset)
		end
	end

	if walk then
		walk:Stop(0.3)
	end
end

-- Step types ------------------------------------------------------------------

local steps = {}

function steps.Wait(ctx, step)
	if step.HideDialogue ~= false then
		ui:HideDialogue()
	end
	Util.wait(step.Time or 1, ctx.stop)
end

function steps.Fade(ctx, step)
	ui:Fade(step.To or 1, if ctx.skipped then 0 else step.Time or 0.5, ctx.stop)
end

function steps.Shot(ctx, step)
	setShot(ctx, step)
	if step.Wait then
		Util.wait(step.Time or Config.Camera.BlendTime, ctx.stop)
	end
end

function steps.Line(ctx, step)
	local info = step.Actor and ctx.info[step.Actor]
	local speaker = step.Actor and ctx.actors[step.Actor]

	-- Camera: an explicit shot wins; otherwise make sure the speaker is on screen.
	if type(step.Shot) == "table" then
		setShot(ctx, step.Shot)
	elseif step.Shot ~= false and speaker and Config.Camera.AutoShotOnLine then
		local inShot = false
		for _, subject in (ctx.shot and ctx.shot.Subjects) or {} do
			if subject == speaker then
				inShot = true
			end
		end
		if not inShot then
			local listener = step.Listener or (if step.Actor == "Player" then ctx.definition.Focus else "Player")
			if listener and listener ~= step.Actor then
				setShot(ctx, { Shot = "OverShoulder", From = listener, To = step.Actor })
			end
		end
	end

	if step.Animation and speaker then
		playAnimation(speaker, step.Animation, false)
	end

	ui:ShowLine({
		Speaker = step.Speaker or (info and info.DisplayName) or step.Actor,
		Color = step.Color or (info and info.Color),
		Text = step.Text,
		Voice = step.Voice,
		VoiceVolume = step.VoiceVolume,
		Style = step.Style,
		Auto = step.Auto,
		Hold = step.Hold,
	}, ctx.stop)
end

function steps.HideDialogue(_ctx, _step)
	ui:HideDialogue()
end

function steps.Face(ctx, step)
	local model = ctx.actors[step.Actor]
	local position = resolvePosition(ctx, step.Target)
	if not (model and position) then
		warn(("[Cutscene] Face: couldn't find %s or %s"):format(tostring(step.Actor), tostring(step.Target)))
		return
	end
	local run = function()
		faceTowards(ctx, model, position, step.Time or 0.6)
	end
	if step.Wait == false then
		task.spawn(run)
	else
		run()
	end
end

function steps.MoveTo(ctx, step)
	local model = ctx.actors[step.Actor]
	local position = resolvePosition(ctx, step.Target)
	if not (model and position) then
		warn(("[Cutscene] MoveTo: couldn't find %s or %s"):format(tostring(step.Actor), tostring(step.Target)))
		return
	end
	if step.Wait ~= false then
		ui:HideDialogue()
	end
	local run = function()
		moveActor(ctx, model, position, step)
	end
	if step.Wait == false then
		task.spawn(run)
	else
		run()
	end
end

function steps.Animation(ctx, step)
	local model = ctx.actors[step.Actor]
	if not model then
		return
	end
	local track = playAnimation(model, step.Id, step.Looped, step.Priority)
	if track and step.Wait then
		Util.wait(if track.Length > 0 then track.Length else 1, ctx.stop)
	end
end

function steps.Sound(ctx, step)
	if ctx.skipped then
		return
	end
	local sound = Util.make("Sound", {
		SoundId = step.Id,
		Volume = step.Volume or 0.5,
		Parent = game:GetService("SoundService"),
	})
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	table.insert(ctx.cleanups, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function steps.Callback(ctx, step)
	step.Run(ctx)
end

-- Setup and teardown ----------------------------------------------------------

local function setupActors(ctx)
	local character = LocalPlayer.Character
	ctx.actors.Player = character
	ctx.info.Player = { DisplayName = LocalPlayer.DisplayName, Color = Config.Dialogue.PlayerColor }
	table.insert(ctx.ignore, character)

	local folder = Instance.new("Folder")
	folder.Name = "CutsceneActors"
	folder.Parent = Workspace
	table.insert(ctx.ignore, folder)
	table.insert(ctx.cleanups, function()
		folder:Destroy()
	end)

	for name, spec in ctx.definition.Actors or {} do
		local original = spec.Path and findByPath(spec.Path)
		if not (original and original:IsA("Model")) then
			warn(("[Cutscene] Actor %q not found at %s"):format(name, tostring(spec.Path)))
			continue
		end
		local model = original
		if spec.StandIn ~= false then
			model = makeStandIn(ctx, original, folder)
			playAnimation(model, spec.IdleAnimation or Config.Actors.IdleAnimation, true, Enum.AnimationPriority.Idle)
		end
		table.insert(ctx.ignore, original)
		ctx.actors[name] = model
		ctx.info[name] = spec
	end
end

local function hideOtherPlayers(ctx)
	if not Config.Hide.OtherPlayers then
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Character then
			hideLocally(ctx, player.Character)
			table.insert(ctx.ignore, player.Character)
		end
	end
end

local function hideInterface(ctx)
	for _, coreType in Config.Hide.CoreGui do
		local wasEnabled = StarterGui:GetCoreGuiEnabled(coreType)
		StarterGui:SetCoreGuiEnabled(coreType, false)
		table.insert(ctx.cleanups, function()
			StarterGui:SetCoreGuiEnabled(coreType, wasEnabled)
		end)
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	for _, name in Config.Hide.ScreenGuis do
		local screenGui = playerGui and playerGui:FindFirstChild(name)
		if screenGui and screenGui:IsA("ScreenGui") then
			local wasEnabled = screenGui.Enabled
			screenGui.Enabled = false
			table.insert(ctx.cleanups, function()
				screenGui.Enabled = wasEnabled
			end)
		end
	end
end

local function freezePlayer(ctx)
	local ok, controls = pcall(function()
		local playerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", FIND_TIMEOUT) :: any)
		return playerModule:GetControls()
	end)
	if ok and controls then
		controls:Disable()
		table.insert(ctx.cleanups, function()
			controls:Enable()
		end)
	end

	local humanoid = ctx.actors.Player:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
		local autoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		table.insert(ctx.cleanups, function()
			humanoid.AutoRotate = autoRotate
		end)
		-- If the player dies mid-scene, end it cleanly.
		local died = humanoid.Died:Connect(function()
			ctx.skipped = true
		end)
		table.insert(ctx.cleanups, function()
			died:Disconnect()
		end)
	end
end

local function bindInput(ctx)
	ContextActionService:BindActionAtPriority("CutsceneAdvance", function(_, state)
		if state == Enum.UserInputState.Begin then
			ui:Advance()
		end
		return Enum.ContextActionResult.Sink
	end, false, INPUT_PRIORITY, table.unpack(Config.Input.AdvanceKeys))

	ContextActionService:BindActionAtPriority("CutsceneSkip", function(_, state)
		ctx.holdingSkip = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, INPUT_PRIORITY, table.unpack(Config.Input.SkipKeys))

	local connections = {
		ui.ClickCatcher.Activated:Connect(function()
			ui:Advance()
		end),
		ui.SkipButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				ctx.holdingSkip = true
			end
		end),
		ui.SkipButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				ctx.holdingSkip = false
			end
		end),
	}

	local progress = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not ctx.canSkip or ctx.skipped then
			return
		end
		if ctx.holdingSkip then
			progress = math.min(progress + dt / Config.Input.SkipHoldTime, 1)
		else
			progress = math.max(progress - dt * 2.5, 0)
		end
		ui:SetSkipProgress(progress)
		if progress >= 1 then
			ctx.skipped = true
		end
	end))

	table.insert(ctx.cleanups, function()
		ContextActionService:UnbindAction("CutsceneAdvance")
		ContextActionService:UnbindAction("CutsceneSkip")
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
end

-- Public API ------------------------------------------------------------------

-- Plays a cutscene definition and yields until it ends.
-- options.CanSkip: allow hold-to-skip (defaults to Config.Input.AllowSkipOnFirstView).
function Cutscene.Play(definition, options: { CanSkip: boolean? }?): string
	if playing then
		return "Busy"
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "Failed"
	end

	playing = true
	options = options or {}
	ui = ui or DialogueUI.new()

	local ctx = {
		definition = definition,
		actors = {},
		info = {},
		ignore = {},
		cleanups = {},
		skipped = false,
		holdingSkip = false,
		canSkip = if options.CanSkip ~= nil then options.CanSkip else Config.Input.AllowSkipOnFirstView,
		camera = CameraDirector.new(),
		shot = nil,
	}
	ctx.stop = function()
		return ctx.skipped
	end

	local ok, err = pcall(function()
		ui:Open(ctx.canSkip)
		setupActors(ctx)
		hideOtherPlayers(ctx)
		hideInterface(ctx)
		freezePlayer(ctx)
		ctx.camera:Start(ctx.ignore)
		bindInput(ctx)

		for index, step in definition.Steps do
			if ctx.skipped then
				break
			end
			local handler = steps[step.Type]
			if handler then
				handler(ctx, step)
			else
				warn(("[Cutscene] Unknown step type %q (step %d)"):format(tostring(step.Type), index))
			end
		end
	end)
	if not ok then
		warn(("[Cutscene] %s stopped with an error: %s"):format(tostring(definition.Id), tostring(err)))
	end
	if ctx.skipped and definition.OnSkip then
		pcall(definition.OnSkip, ctx)
	end

	-- Fade out, put everything back, fade in.
	ui:HideDialogue()
	ui:Fade(1, 0.35)
	ctx.camera:Stop()
	for i = #ctx.cleanups, 1, -1 do
		local cleaned, cleanupError = pcall(ctx.cleanups[i])
		if not cleaned then
			warn("[Cutscene] Cleanup error: " .. tostring(cleanupError))
		end
	end
	task.wait(0.15)
	ui:Fade(0, 0.6)
	ui:Close()
	playing = false

	if not ok then
		return "Failed"
	end
	return if ctx.skipped then "Skipped" else "Completed"
end

function Cutscene.IsPlaying(): boolean
	return playing
end

return Cutscene
