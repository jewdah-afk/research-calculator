--!strict
--[[
	Hud.client.luau — run timer, level, XP bar, health, kills and the slots.

	Reads Types.HudState pushed by the server (~5 Hz, Tuning.hud
	.updateInterval) and draws it. Nothing here simulates anything: if a value
	is not in the snapshot the HUD does not show it, because inventing a
	client-side estimate would make the HUD disagree with the authority.

	The one exception is the run clock, which is interpolated forward from the
	last snapshot so it ticks smoothly between pushes. It is display only and
	is overwritten by every snapshot; the run clock of record is the server's,
	and it stops while paused (HudState.paused), exactly as the level-up pause
	rule requires.

	Every string a player reads comes from DisplayNames. Data.*.name is never
	touched here — see docs/ARCHITECTURE.md rule 7.

	All geometry, colours and text sizes are Tuning.hud, flagged NOT from
	research: the reference is a 2D pixel-art HUD with no Roblox GUI units.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DisplayNames = require("../shared/DisplayNames")
local CoreLoop = require("../shared/Data/CoreLoop")
local Net = require("../shared/Net")
local Tuning = require("../shared/Tuning")

-- Net.HudState mirrors Types.HudState structurally (see shared/Net.luau).
type HudState = Net.HudState

local HUD = Tuning.hud
local COLORS = HUD.colors
local HALF = Tuning.uiHalf

-- Slot counts are research values (core_loop.md: 6 weapon + 6 passive slots),
-- so they are read from Data, not from Tuning. Tuning.hud.slotCountFallback
-- only covers the case where the shipped record leaves the field UNKNOWN.
local function slotCount(value: any): number
	if type(value) == "number" then
		return value
	end
	return HUD.slotCountFallback
end

local WEAPON_SLOTS = slotCount(CoreLoop.data.slots.weaponSlots)
local PASSIVE_SLOTS = slotCount(CoreLoop.data.slots.passiveSlots)

local function color(c: { r: number, g: number, b: number }): Color3
	return Color3.new(c.r, c.g, c.b)
end

--- mm:ss for the run clock. Tuning.secondsPerMinute is a unit conversion.
local function formatClock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	local minutes = math.floor(whole / Tuning.secondsPerMinute)
	return string.format("%02d:%02d", minutes, whole % Tuning.secondsPerMinute)
end

-- ------------------------------------------------------------------ widgets
local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: GuiObject, size: UDim2, position: UDim2, textSize: number, c: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = size
	t.Position = position
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamMedium
	t.TextSize = textSize
	t.TextColor3 = c
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = ""
	t.Parent = parent
	return t
end

--- A trough with a fill that is resized by fraction. Returns the fill.
local function bar(parent: GuiObject, position: UDim2, height: number, fillColor: Color3): Frame
	local trough = Instance.new("Frame")
	trough.Size = UDim2.new(0, HUD.barWidth, 0, height)
	trough.Position = position
	trough.BackgroundColor3 = color(COLORS.panel)
	trough.BackgroundTransparency = HUD.barBackgroundTransparency
	trough.BorderSizePixel = 0
	trough.Parent = parent
	corner(trough, HUD.cornerRadius)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = trough
	corner(fill, HUD.cornerRadius)
	return fill
end

--- A row of `count` empty slot boxes. Returns the boxes and their text labels.
local function slotRow(parent: Instance, position: UDim2, count: number): ({ Frame }, { TextLabel })
	local row = Instance.new("Frame")
	row.Size = UDim2.new(0, count * (HUD.slotSize + HUD.slotGap), 0, HUD.slotSize)
	row.Position = position
	row.BackgroundTransparency = 1
	row.Parent = parent

	local boxes: { Frame } = {}
	local texts: { TextLabel } = {}
	for i = 1, count do
		local box = Instance.new("Frame")
		box.Size = UDim2.new(0, HUD.slotSize, 0, HUD.slotSize)
		box.Position = UDim2.new(0, (i - 1) * (HUD.slotSize + HUD.slotGap), 0, 0)
		box.BackgroundColor3 = color(COLORS.slotEmpty)
		box.BackgroundTransparency = HUD.backgroundTransparency
		box.BorderSizePixel = 0
		box.Parent = row
		corner(box, HUD.cornerRadius)

		-- Placeholder art: the slot shows the initials of OUR display name and
		-- the item level. Icons replace this without touching any logic.
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = HUD.textSize
		text.TextColor3 = color(COLORS.text)
		text.TextScaled = true
		text.Text = ""
		text.Parent = box

		boxes[i] = box
		texts[i] = text
	end
	return boxes, texts
end

-- --------------------------------------------------------------------- gui
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "SurvivorsLikeHud"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

-- Run clock, centred at the top: the single most-read number in the run.
local clock = Instance.new("TextLabel")
clock.Size = UDim2.new(0, HUD.barWidth, 0, HUD.titleTextSize + HUD.padding)
clock.Position = UDim2.new(HALF, -HUD.barWidth * HALF, 0, HUD.margin)
clock.BackgroundTransparency = 1
clock.Font = Enum.Font.GothamBold
clock.TextSize = HUD.titleTextSize
clock.TextColor3 = color(COLORS.text)
clock.Text = formatClock(0)
clock.Parent = screen

-- Left panel: level, XP, health, kills. Row offsets are accumulated top-down
-- so every one is a sum of named Tuning heights rather than a padding
-- multiplier nobody can check against the layout.
local levelRowY = HUD.padding
local healthRowY = levelRowY + HUD.statRowHeight
local xpRowY = healthRowY + HUD.healthBarHeight + HUD.padding
local killsRowY = xpRowY + HUD.xpBarHeight + HUD.padding
local panelHeight = killsRowY + HUD.statRowHeight + HUD.padding

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, HUD.barWidth + HUD.padding * 2, 0, panelHeight)
panel.Position = UDim2.new(0, HUD.margin, 0, HUD.margin)
panel.BackgroundColor3 = color(COLORS.panel)
panel.BackgroundTransparency = HUD.backgroundTransparency
panel.BorderSizePixel = 0
panel.Parent = screen
corner(panel, HUD.cornerRadius)

local levelText = label(
	panel,
	UDim2.new(1, -HUD.padding * 2, 0, HUD.statRowHeight),
	UDim2.new(0, HUD.padding, 0, levelRowY),
	HUD.textSize,
	color(COLORS.text)
)

local healthFill = bar(panel, UDim2.new(0, HUD.padding, 0, healthRowY), HUD.healthBarHeight, color(COLORS.health))

local xpFill = bar(panel, UDim2.new(0, HUD.padding, 0, xpRowY), HUD.xpBarHeight, color(COLORS.xp))

local killsText = label(
	panel,
	UDim2.new(1, -HUD.padding * 2, 0, HUD.statRowHeight),
	UDim2.new(0, HUD.padding, 0, killsRowY),
	HUD.textSize,
	color(COLORS.dimText)
)

-- Slot rows, bottom-left: weapons above passives.
local passiveRowTop = -(HUD.margin + HUD.slotSize)
local weaponRowTop = passiveRowTop - (HUD.slotSize + HUD.slotGap)
local weaponBoxes, weaponTexts = slotRow(screen, UDim2.new(0, HUD.margin, 1, weaponRowTop), WEAPON_SLOTS)
local passiveBoxes, passiveTexts = slotRow(screen, UDim2.new(0, HUD.margin, 1, passiveRowTop), PASSIVE_SLOTS)

-- -------------------------------------------------------------------- state
local latest: HudState? = nil
-- Seconds since `latest` arrived, used only to tick the displayed clock.
local sinceSnapshot = 0
-- The clock text only changes once a second, so the whole second last drawn is
-- remembered and the string is reformatted only when it moves.
local lastClockSecond: number? = nil

--- Draws the clock, skipping the format and assignment within the same second.
local function setClock(seconds: number)
	local whole = math.max(0, math.floor(seconds))
	if whole == lastClockSecond then
		return
	end
	lastClockSecond = whole
	clock.Text = formatClock(whole)
end

--- Two letters of our display name — placeholder art, but never a raw id.
local function slotGlyph(category: DisplayNames.Category, id: string, level: number): string
	local name = DisplayNames.find(category, id)
	if name == nil then
		-- A missing entry is a bug in DisplayNames, not something to paper
		-- over by rendering the mechanical id at the player.
		return "?"
	end
	return string.upper(string.sub(name, 1, 2)) .. "\n" .. tostring(level)
end

local function paintSlots(
	boxes: { Frame },
	texts: { TextLabel },
	items: { { id: string, level: number } },
	category: DisplayNames.Category,
	filled: Color3
)
	for i = 1, #boxes do
		local item = items[i]
		if item == nil then
			boxes[i].BackgroundColor3 = color(COLORS.slotEmpty)
			texts[i].Text = ""
		else
			boxes[i].BackgroundColor3 = filled
			texts[i].Text = slotGlyph(category, item.id, item.level)
		end
	end
end

local function fraction(value: number, outOf: number): number
	if outOf <= 0 then
		return 0
	end
	return math.clamp(value / outOf, 0, 1)
end

local function render(state: HudState, displayTime: number)
	setClock(displayTime)
	levelText.Text = string.format("Level %d", state.level)
	killsText.Text = string.format("Kills %d    Gold %d", state.kills, state.gold)

	local healthRatio = fraction(state.health, state.maxHealth)
	healthFill.Size = UDim2.new(healthRatio, 0, 1, 0)
	healthFill.BackgroundColor3 = if healthRatio <= HUD.lowHealthFraction
		then color(COLORS.lowHealth)
		else color(COLORS.health)

	xpFill.Size = UDim2.new(fraction(state.xp, state.xpToNext), 0, 1, 0)

	paintSlots(weaponBoxes, weaponTexts, state.weapons, "weapon", color(COLORS.slotWeapon))
	paintSlots(passiveBoxes, passiveTexts, state.passives, "passive", color(COLORS.slotPassive))
end

-- Net.client() yields until the server has published the remotes. Every remote
-- name lives in shared/Net; this script never spells one.
local net = Net.client()

net.hud.OnClientEvent:Connect(function(state: HudState)
	latest = state
	sinceSnapshot = 0
	render(state, state.time)
end)

-- RunState is the authority on the pause, and arrives the moment it changes
-- rather than at the next HUD push, so the displayed clock stops on the same
-- frame the run does.
local paused = false
local finished = false

net.runState.OnClientEvent:Connect(function(run: Net.RunStatePayload)
	paused = run.paused
	finished = run.finished
	-- RunState carries the run clock of record; trust it over interpolation.
	local state = latest
	if state ~= nil then
		state.time = run.time
		sinceSnapshot = 0
		setClock(run.time)
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local state = latest
	if state == nil then
		return
	end
	-- The run clock stops while paused: the level-up pause freezes the clock
	-- of record on the server, so the display must not run ahead of it. It
	-- also stops for good once the run has finished.
	if paused or finished or state.paused then
		return
	end
	sinceSnapshot += dt
	setClock(state.time + sinceSnapshot)
end)
