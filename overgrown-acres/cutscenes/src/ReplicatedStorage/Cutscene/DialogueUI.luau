-- Dialogue box shown at the bottom of the screen, just above the inventory.
-- Builds its own UI in code, so there's nothing to set up in StarterGui.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)

local D = Config.Dialogue
local make = Util.make

local NAMEPLATE_HEIGHT = 32
local ADVANCE_COOLDOWN = 0.15

local DialogueUI = {}
DialogueUI.__index = DialogueUI

local function stripTags(text: string): string
	return (text:gsub("<[^>]+>", ""))
end

local function isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function skipHint(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Hold to skip"
	elseif last.Name:match("^Gamepad") then
		return "Hold Y to skip"
	end
	return "Hold Tab to skip"
end

local function tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

function DialogueUI.new()
	local self = setmetatable({
		typing = false,
		finishTyping = false,
		waiting = false,
		lastAdvance = 0,
		lastSpeaker = nil,
		dialogueShown = false,
	}, DialogueUI)
	self:_build()
	return self
end

function DialogueUI:_build()
	local gui = make("ScreenGui", {
		Name = "CutsceneUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})

	-- Invisible full-screen button so a click or tap anywhere advances the dialogue.
	self.ClickCatcher = make("TextButton", {
		Name = "ClickCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = gui,
	})

	local root = make("CanvasGroup", {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(D.WidthScale, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}, {
		make("UISizeConstraint", { MaxSize = Vector2.new(D.MaxWidth, math.huge) }),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
		}),
	})
	self.scale = make("UIScale", { Parent = root })

	local panel = make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, NAMEPLATE_HEIGHT / 2),
		Size = UDim2.new(1, 0, 0, D.MinHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = D.PanelColor,
		BackgroundTransparency = D.PanelTransparency,
		Parent = root,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 14) }),
		make("UIStroke", {
			Color = D.StrokeColor,
			Transparency = 0.35,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175)),
		}),
		make("UIPadding", {
			PaddingTop = UDim.new(0, NAMEPLATE_HEIGHT / 2 + 12),
			PaddingBottom = UDim.new(0, 20),
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 52),
		}),
	})

	local body = make("TextLabel", {
		Name = "Body",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = D.Font,
		TextSize = D.TextSize,
		TextColor3 = D.TextColor,
		LineHeight = 1.12,
		Text = "",
		Parent = panel,
	})

	local nameplate = make("Frame", {
		Name = "Nameplate",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(20, NAMEPLATE_HEIGHT / 2),
		Size = UDim2.fromOffset(0, NAMEPLATE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = D.DefaultSpeakerColor,
		ZIndex = 12,
		Parent = root,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 8) }),
		make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 1 }),
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	self.nameScale = make("UIScale", { Parent = nameplate })
	local nameLabel = make("TextLabel", {
		Name = "Name",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = D.BoldFont,
		TextSize = D.NameSize,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 13,
		Parent = nameplate,
	})

	local indicator = make("TextLabel", {
		Name = "Continue",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -14),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Font = D.BoldFont,
		TextSize = 16,
		TextColor3 = D.StrokeColor,
		Text = "▼",
		Visible = false,
		ZIndex = 12,
		Parent = root,
	})
	TweenService:Create(
		indicator,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(1, -20, 1, -8) }
	):Play()

	-- Hold-to-skip button in the top-right corner.
	local skip = make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(160, 36),
		BackgroundColor3 = D.PanelColor,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 20,
		Parent = gui,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 10) }),
		make("UIStroke", { Color = D.StrokeColor, Transparency = 0.5, Thickness = 1 }),
	})
	local skipFill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = D.StrokeColor,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = skip,
	})
	local skipLabel = make("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = D.BoldFont,
		TextSize = 15,
		TextColor3 = D.TextColor,
		Text = skipHint(),
		ZIndex = 21,
		Parent = skip,
	})
	UserInputService.LastInputTypeChanged:Connect(function()
		skipLabel.Text = skipHint()
	end)

	local fade = make("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = gui,
	})

	if D.BlipSoundId ~= "" then
		self.blip = make("Sound", { SoundId = D.BlipSoundId, Volume = D.BlipVolume, Parent = gui })
	end

	self.gui = gui
	self.root = root
	self.panel = panel
	self.body = body
	self.nameplate = nameplate
	self.nameLabel = nameLabel
	self.indicator = indicator
	self.SkipButton = skip
	self.skipFill = skipFill
	self.fade = fade

	local function layout()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 900
		self.scale.Scale = math.clamp(height / 900, 0.7, 1.15)
		self.restPosition = UDim2.new(0.5, 0, 1, -(if isTouchDevice() then D.BottomOffsetTouch else D.BottomOffset))
		if self.dialogueShown then
			root.Position = self.restPosition
		end
	end
	layout()
	root.Position = self.restPosition + UDim2.fromOffset(0, 24)
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function DialogueUI:Open(canSkip: boolean)
	self.gui.Enabled = true
	self.SkipButton.Visible = canSkip
	self:SetSkipProgress(0)
end

function DialogueUI:Close()
	self:HideDialogue(true)
	self.SkipButton.Visible = false
	self.gui.Enabled = false
	self.lastSpeaker = nil
end

function DialogueUI:_showDialogue()
	if self.dialogueShown then
		return
	end
	self.dialogueShown = true
	self.root.Position = self.restPosition + UDim2.fromOffset(0, 24)
	tween(self.root, 0.35, { GroupTransparency = 0, Position = self.restPosition })
end

function DialogueUI:HideDialogue(instant: boolean?)
	if not self.dialogueShown then
		return
	end
	self.dialogueShown = false
	self.lastSpeaker = nil
	if instant then
		self.root.GroupTransparency = 1
	else
		tween(self.root, 0.25, {
			GroupTransparency = 1,
			Position = self.restPosition + UDim2.fromOffset(0, 16),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

function DialogueUI:SetSkipProgress(progress: number)
	self.skipFill.Size = UDim2.fromScale(progress, 1)
end

-- Fades the screen to black (`to` = 1) or back (`to` = 0).
function DialogueUI:Fade(to: number, time: number, shouldStop: (() -> boolean)?)
	local goal = 1 - to
	if time <= 0 then
		self.fade.BackgroundTransparency = goal
		return
	end
	local t = tween(self.fade, time, { BackgroundTransparency = goal }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	Util.wait(time, shouldStop)
	t:Cancel()
	self.fade.BackgroundTransparency = goal
end

-- Called by input. The first press finishes the typing, the next one advances.
function DialogueUI:Advance()
	local now = os.clock()
	if now - self.lastAdvance < ADVANCE_COOLDOWN then
		return
	end
	if self.typing then
		self.finishTyping = true
		self.lastAdvance = now
	elseif self.waiting then
		self.waiting = false
		self.lastAdvance = now
	end
end

function DialogueUI:_applyStyle(line)
	local isNote = line.Style == "Note"
	self.panel.BackgroundColor3 = if isNote then D.NoteColor else D.PanelColor
	self.body.TextColor3 = if isNote then D.NoteTextColor else D.TextColor
	self.body.Font = if isNote then D.NoteFont else D.Font
	self.body.TextSize = if isNote then D.TextSize + 3 else D.TextSize

	if line.Speaker then
		self.nameplate.Visible = true
		self.nameLabel.Text = line.Speaker
		self.nameplate.BackgroundColor3 = line.Color or D.DefaultSpeakerColor
		if line.Speaker ~= self.lastSpeaker then
			self.nameScale.Scale = 0.8
			tween(self.nameScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	else
		self.nameplate.Visible = false
	end
	self.lastSpeaker = line.Speaker
end

local function loadVoice(id: string, volume: number?): Sound?
	local sound = make("Sound", { SoundId = id, Volume = volume or 1, Parent = SoundService })
	local started = os.clock()
	while not sound.IsLoaded and os.clock() - started < 2 do
		task.wait()
	end
	if not sound.IsLoaded then
		warn("[Cutscene] Voice line failed to load: " .. id)
		sound:Destroy()
		return nil
	end
	return sound
end

-- Shows one line and yields until the player advances (or it auto-advances).
function DialogueUI:ShowLine(line, shouldStop: () -> boolean)
	self:_applyStyle(line)
	local text = line.Text or ""
	self.body.Text = if line.Style == "Note" then "<i>" .. text .. "</i>" else text
	self.body.MaxVisibleGraphemes = 0
	self.indicator.Visible = false
	self:_showDialogue()

	local characters = {}
	for _, code in utf8.codes(stripTags(text)) do
		table.insert(characters, utf8.char(code))
	end
	local total = #characters

	local voice = if line.Voice and line.Voice ~= "" then loadVoice(line.Voice, line.VoiceVolume) else nil
	local speed = D.CharactersPerSecond
	if voice then
		voice:Play()
		-- Match the typing to the voice so the text finishes just before it does.
		if voice.TimeLength > 0 then
			speed = math.clamp(total / (voice.TimeLength * 0.9), 12, 120)
		end
	end

	-- Typewriter
	self.typing = true
	self.finishTyping = false
	local shown, budget = 0, 0
	while shown < total and not self.finishTyping and not shouldStop() do
		budget += task.wait() * speed
		while budget >= 1 and shown < total do
			budget -= 1
			shown += 1
			local character = characters[shown]
			if self.blip and not voice and shown % D.BlipEvery == 0 and character:match("%S") then
				self.blip:Play()
			end
			local pause = if voice then nil else D.PunctuationPause[character]
			if pause and shown < total then
				budget -= pause * speed
				break
			end
		end
		self.body.MaxVisibleGraphemes = shown
	end
	self.body.MaxVisibleGraphemes = -1
	self.typing = false
	self.indicator.Visible = not line.Auto

	-- Wait for the player, or auto-advance.
	local timeout
	if line.Auto then
		if line.Hold then
			timeout = line.Hold
		elseif voice then
			timeout = math.max(voice.TimeLength - voice.TimePosition, 0) + 0.5
		else
			timeout = math.clamp(total * 0.035, 1.2, 4)
		end
	end
	self.waiting = true
	local started = os.clock()
	while self.waiting and not shouldStop() do
		if timeout and os.clock() - started >= timeout then
			break
		end
		task.wait()
	end
	self.waiting = false
	self.indicator.Visible = false

	if voice then
		voice:Stop()
		voice:Destroy()
	end
end

return DialogueUI
