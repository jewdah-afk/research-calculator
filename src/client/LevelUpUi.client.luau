--!strict
--[[
	LevelUpUi.client.luau — the level-up choice panel.

	The server pauses the run, builds the offer with Sim/LevelUp.offer and
	fires Net.levelUpOffer. This script renders it and replies on
	Net.chooseOption with exactly one of the four research-defined actions
	(research/vs/core_loop.md §2), as a Net.ChooseOptionPayload:

	  action "choose", index   take that option
	  action "reroll"          reshuffle the current offer
	  action "skip"            take the skip payout instead of an item
	  action "banish", index   remove that item id from the pool for the rest
	                           of the run, then reshuffle

	Every reply echoes the offer's `offerId`. The server validates it against
	the offer it actually sent, so a stale reply (the player clicked as a
	reroll arrived) or a forged one is dropped rather than applied.

	It decides nothing. Option count (3, or 4 by Luck), which items are legal,
	whether an offer is upgrade-only because the slots are full, and how many
	rerolls/skips/banishes are left are all server state; the panel draws what
	it is given and greys out an action whose remaining count is 0. That keeps
	the client non-authoritative — a modified client can still only send one of
	these four messages, and the server re-validates every one.

	Banish takes a second click by design: arm it, then pick the option to
	banish, so a stray click cannot burn a limited, irreversible resource.

	Names come from DisplayNames; Data.*.name is never read here.
	All geometry and colour is Tuning.levelUpUi, flagged NOT from research.
]]
local Players = game:GetService("Players")

local DisplayNames = require("../shared/DisplayNames")
local Net = require("../shared/Net")
local Tuning = require("../shared/Tuning")

-- Net's payload types mirror Types.LevelUpOffer / Types.LevelUpOption and add
-- the offerId the reply must echo (see shared/Net.luau).
type LevelUpOffer = Net.LevelUpOfferPayload
type LevelUpOption = Net.LevelUpOption

local UI = Tuning.levelUpUi
local COLORS = UI.colors
local HALF = Tuning.uiHalf

-- The four actions the server accepts on Net.chooseOption.
local ACTION_CHOOSE = "choose"
local ACTION_REROLL = "reroll"
local ACTION_SKIP = "skip"
local ACTION_BANISH = "banish"

local function color(c: { r: number, g: number, b: number }): Color3
	return Color3.new(c.r, c.g, c.b)
end

local function corner(parent: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, UI.cornerRadius)
	c.Parent = parent
end

-- --------------------------------------------------------------------- gui
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "SurvivorsLikeLevelUp"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Enabled = false
screen.Parent = playerGui

-- Backdrop dims the paused run and swallows clicks that miss a button.
local backdrop = Instance.new("TextButton")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = color(COLORS.backdrop)
backdrop.BackgroundTransparency = UI.backdropTransparency
backdrop.BorderSizePixel = 0
backdrop.AutoButtonColor = false
backdrop.Text = ""
backdrop.Parent = screen

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(HALF, HALF)
panel.Position = UDim2.new(HALF, 0, HALF, 0)
panel.BackgroundColor3 = color(COLORS.panel)
panel.BorderSizePixel = 0
panel.Parent = screen
corner(panel)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -UI.panelPadding * 2, 0, UI.titleHeight)
title.Position = UDim2.new(0, UI.panelPadding, 0, UI.panelPadding)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = UI.titleTextSize
title.TextColor3 = color(COLORS.text)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = ""
title.Parent = panel

-- Option buttons are created on demand and reused: the offer is 3 or 4
-- options, so the pool never grows past 4 in practice.
local optionButtons: { TextButton } = {}
local footerButtons: { TextButton } = {}

-- Set when Banish is armed; the next option click banishes instead of taking.
local banishArmed = false
local currentOffer: LevelUpOffer? = nil

-- Net.client() yields until the server has published the remotes; no remote
-- is ever named by a bare string here.
local net = Net.client()

--- The one way this script talks to the server. `index` is ignored by the
--- server for reroll and skip, but is always sent so the payload has a single
--- shape.
local function send(offer: LevelUpOffer, action: string, index: number)
	local payload: Net.ChooseOptionPayload = {
		offerId = offer.offerId,
		action = action,
		index = index,
	}
	net.chooseOption:FireServer(payload)
end

local function close()
	screen.Enabled = false
	banishArmed = false
	currentOffer = nil
end

--- Our name for the option, plus what taking it does. `toLevel` and `isNew`
--- are the server's; nothing is recomputed here.
local function optionText(option: LevelUpOption): (string, string)
	local category: DisplayNames.Category = if option.kind == "weapon" then "weapon" else "passive"
	local name = DisplayNames.find(category, option.itemId)
	local heading = if name == nil then "?" else name
	local detail = if option.isNew then "New " .. option.kind else string.format("Level %d", option.toLevel)
	return heading, detail
end

local function optionButton(index: number): TextButton
	local existing: TextButton? = optionButtons[index]
	if existing ~= nil then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -UI.panelPadding * 2, 0, UI.optionHeight)
	button.BackgroundColor3 = color(COLORS.option)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = panel
	corner(button)

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -UI.panelPadding * 2, HALF, 0)
	heading.Position = UDim2.new(0, UI.panelPadding, 0, 0)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = UI.optionTextSize
	heading.TextColor3 = color(COLORS.text)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextYAlignment = Enum.TextYAlignment.Bottom
	heading.Text = ""
	heading.Parent = button

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Size = UDim2.new(1, -UI.panelPadding * 2, HALF, 0)
	detail.Position = UDim2.new(0, UI.panelPadding, HALF, 0)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = UI.optionSubTextSize
	detail.TextColor3 = color(COLORS.dimText)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.Text = ""
	detail.Parent = button

	button.Activated:Connect(function()
		if currentOffer == nil then
			return
		end
		if banishArmed then
			send(currentOffer, ACTION_BANISH, index)
			banishArmed = false
			-- The server answers with a fresh offer; leave the panel open.
			return
		end
		send(currentOffer, ACTION_CHOOSE, index)
		close()
	end)

	optionButtons[index] = button
	return button
end

local function footerButton(index: number, text: string, onClick: () -> ()): TextButton
	local existing: TextButton? = footerButtons[index]
	if existing ~= nil then
		return existing
	end

	local width = UDim2.new(
		1 / UI.footerButtonCount,
		-(UI.buttonGap + UI.panelPadding * 2 / UI.footerButtonCount),
		0,
		UI.buttonHeight
	)

	local button = Instance.new("TextButton")
	button.Size = width
	button.BackgroundColor3 = color(COLORS.button)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = UI.buttonTextSize
	button.TextColor3 = color(COLORS.text)
	button.Text = text
	button.Parent = panel
	corner(button)
	button.Activated:Connect(onClick)

	footerButtons[index] = button
	return button
end

local function paintFooter(button: TextButton, label: string, left: number, armed: boolean)
	local enabled = left > 0
	button.Text = string.format("%s (%d)", label, left)
	button.AutoButtonColor = enabled
	button.Active = enabled
	if not enabled then
		button.BackgroundColor3 = color(COLORS.buttonDisabled)
		button.TextColor3 = color(COLORS.dimText)
	elseif armed then
		button.BackgroundColor3 = color(COLORS.banishArmed)
		button.TextColor3 = color(COLORS.text)
	else
		button.BackgroundColor3 = color(COLORS.button)
		button.TextColor3 = color(COLORS.text)
	end
end

local rerollButton = footerButton(1, "Reroll", function()
	local offer = currentOffer
	if offer == nil or offer.rerollsLeft <= 0 then
		return
	end
	banishArmed = false
	send(offer, ACTION_REROLL, 0)
end)

local skipButton = footerButton(2, "Skip", function()
	local offer = currentOffer
	if offer == nil or offer.skipsLeft <= 0 then
		return
	end
	send(offer, ACTION_SKIP, 0)
	close()
end)

-- Index 2 + 1: the third footer slot. Written this way because a bare 3 is
-- not permitted outside Data/Tuning; UI.footerButtonCount is the count.
local banishButton = footerButton(UI.footerButtonCount, "Banish", function()
	local offer = currentOffer
	if offer == nil or offer.banishesLeft <= 0 then
		return
	end
	banishArmed = not banishArmed
end)

local function layout(offer: LevelUpOffer)
	local count = #offer.options
	local optionsHeight = count * UI.optionHeight + math.max(0, count - 1) * UI.optionGap
	local height = UI.panelPadding * 2 + UI.titleHeight + optionsHeight + UI.optionGap + UI.buttonHeight
	panel.Size = UDim2.new(0, UI.panelWidth, 0, height)

	local y = UI.panelPadding + UI.titleHeight
	for i = 1, count do
		local button = optionButton(i)
		local option = offer.options[i]
		local heading, detail = optionText(option)

		button.Position = UDim2.new(0, UI.panelPadding, 0, y)
		button.Visible = true
		button.BackgroundColor3 = if option.isNew then color(COLORS.optionNew) else color(COLORS.option);
		(button:FindFirstChild("Heading") :: TextLabel).Text = heading;
		(button:FindFirstChild("Detail") :: TextLabel).Text = detail

		y += UI.optionHeight + UI.optionGap
	end

	-- An offer that shrank (4 options then 3 after a reroll) leaves stale
	-- buttons; hide rather than destroy so the pool stays allocation-free.
	for i = count + 1, #optionButtons do
		optionButtons[i].Visible = false
	end

	local footerY = y
	local slotWidth = (UI.panelWidth - UI.panelPadding * 2 - UI.buttonGap * (UI.footerButtonCount - 1))
		/ UI.footerButtonCount
	for i = 1, #footerButtons do
		local button = footerButtons[i]
		button.Size = UDim2.new(0, slotWidth, 0, UI.buttonHeight)
		button.Position = UDim2.new(0, UI.panelPadding + (i - 1) * (slotWidth + UI.buttonGap), 0, footerY)
	end

	paintFooter(rerollButton, "Reroll", offer.rerollsLeft, false)
	paintFooter(skipButton, "Skip", offer.skipsLeft, false)
	paintFooter(banishButton, "Banish", offer.banishesLeft, banishArmed)

	title.Text = if banishArmed then "Choose an option to banish" else "Level Up"
end

net.levelUpOffer.OnClientEvent:Connect(function(offer: LevelUpOffer)
	currentOffer = offer
	layout(offer)
	screen.Enabled = true
end)

-- Clicking the backdrop only cancels an armed banish; it never dismisses the
-- offer, because the run stays paused until the server gets an action.
backdrop.Activated:Connect(function()
	local offer = currentOffer
	if offer == nil or not banishArmed then
		return
	end
	banishArmed = false
	layout(offer)
end)
