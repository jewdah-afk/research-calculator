--!nonstrict
--[[
	Client — HUD, shop, pet list, toasts, hatch reveal.

	The client is a renderer. It holds no authority: it draws the last snapshot
	the server sent and sends back intents ("buy speed", "place this pet"). If
	you ever find yourself computing a coin total here, move it to Economy.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Reveal = require(script:WaitForChild("Reveal"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(16, 18, 24)
local PANEL = Color3.fromRGB(26, 30, 38)
local LINE = Color3.fromRGB(48, 54, 66)
local TEXT = Color3.fromRGB(228, 234, 242)
local MUTED = Color3.fromRGB(148, 158, 172)
local GOOD = Color3.fromRGB(126, 217, 128)
local WARN = Color3.fromRGB(255, 192, 74)
local BAD = Color3.fromRGB(255, 104, 104)

local state = nil

local function new(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(instance, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, instance)
	return instance
end

local function button(props, parent)
	local instance = new("TextButton", {
		BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(58, 118, 210),
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextSize = props.TextSize or 14,
		TextColor3 = TEXT,
		BorderSizePixel = 0,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromOffset(120, 34),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Button",
	}, parent)
	corner(instance, 7)
	return instance
end

local gui = new("ScreenGui", {
	Name = "SparkHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- ------------------------------------------------------------- top bar -----

local topBar = corner(new("Frame", {
	Name = "TopBar",
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.fromOffset(300, 78),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, gui), 10)

local coinsLabel = new("TextLabel", {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(272, 32),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WARN,
	Text = "0",
}, topBar)

local statsLabel = new("TextLabel", {
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.fromOffset(272, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = MUTED,
	Text = "0/s   ·   luck x1   ·   rebirth 0",
}, topBar)

-- --------------------------------------------------------- limited pill ----

local limitedPill = corner(new("Frame", {
	Name = "Limited",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(300, 34),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, gui), 17)

local limitedLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = TEXT,
	Text = "",
}, limitedPill)

-- -------------------------------------------------------------- vault ------

local vaultFrame = corner(new("Frame", {
	Name = "Vault",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -14),
	Size = UDim2.fromOffset(280, 64),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, gui), 10)

local vaultLabel = new("TextLabel", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.fromOffset(180, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = MUTED,
	Text = "Vault 0 / 0",
}, vaultFrame)

local barBack = corner(new("Frame", {
	Position = UDim2.fromOffset(12, 30),
	Size = UDim2.fromOffset(170, 12),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
}, vaultFrame), 6)

local barFill = corner(new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GOOD,
	BorderSizePixel = 0,
}, barBack), 6)

local collectButton = button({
	Text = "Collect",
	Position = UDim2.fromOffset(192, 16),
	Size = UDim2.fromOffset(76, 32),
	BackgroundColor3 = Color3.fromRGB(46, 150, 92),
}, vaultFrame)

collectButton.Activated:Connect(function()
	Remotes.event(Remotes.Names.Collect):FireServer()
end)

-- ------------------------------------------------------- side buttons ------

local sideBar = new("Frame", {
	Name = "SideBar",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -14),
	Size = UDim2.fromOffset(120, 160),
	BackgroundTransparency = 1,
}, gui)

new("UIListLayout", {
	Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, sideBar)

local shopButton = button({ Text = "Shop", LayoutOrder = 1 }, sideBar)
local petsButton = button({ Text = "Pets", LayoutOrder = 2,
	BackgroundColor3 = Color3.fromRGB(122, 84, 190) }, sideBar)
local dailyButton = button({ Text = "Daily", LayoutOrder = 3,
	BackgroundColor3 = Color3.fromRGB(198, 132, 44) }, sideBar)

dailyButton.Activated:Connect(function()
	Remotes.event(Remotes.Names.ClaimDaily):FireServer()
end)

-- -------------------------------------------------------------- panels -----

local function makePanel(title)
	local panel = corner(new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 400),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Visible = false,
	}, gui), 12)

	new("UIStroke", { Color = LINE, Thickness = 1 }, panel)

	new("TextLabel", {
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.fromOffset(300, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Text = title,
	}, panel)

	local close = button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(30, 28),
		BackgroundColor3 = Color3.fromRGB(70, 76, 90),
	}, panel)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)

	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	return panel, scroll
end

local shopPanel, shopList = makePanel("Shop")
local petsPanel, petsList = makePanel("Pets")

shopButton.Activated:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	petsPanel.Visible = false
end)
petsButton.Activated:Connect(function()
	petsPanel.Visible = not petsPanel.Visible
	shopPanel.Visible = false
end)

local function row(parent, order)
	local frame = corner(new("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, parent), 8)
	return frame
end

local function renderShop()
	if not state then
		return
	end
	for _, child in ipairs(shopList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local order = 0
	for _, key in ipairs(Config.UpgradeOrder) do
		local def = Config.Upgrades[key]
		local entry = state.upgrades[key]
		order += 1

		local frame = row(shopList, order)
		new("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -140, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT,
			Text = ("%s  ·  lvl %d"):format(def.label, entry.level),
		}, frame)

		new("TextLabel", {
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -140, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Text = def.desc,
		}, frame)

		local buy = button({
			Text = entry.maxed and "MAX" or Format.short(entry.cost),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(104, 34),
			BackgroundColor3 = entry.maxed and Color3.fromRGB(70, 76, 90)
				or (state.coins >= entry.cost and Color3.fromRGB(46, 150, 92) or Color3.fromRGB(70, 76, 90)),
		}, frame)

		if not entry.maxed then
			buy.Activated:Connect(function()
				Remotes.event(Remotes.Names.BuyUpgrade):FireServer(key)
			end)
		end
	end

	order += 1
	local rebirthRow = row(shopList, order)
	rebirthRow.BackgroundColor3 = Color3.fromRGB(44, 30, 60)

	new("TextLabel", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Text = ("Rebirth %d"):format(state.rebirths),
	}, rebirthRow)

	new("TextLabel", {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -140, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Text = ("Reset for +%d%% permanent income"):format(math.floor(Config.Rebirth.incomeBonus * 100)),
	}, rebirthRow)

	local rebirthBuy = button({
		Text = Format.short(state.rebirthCost),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(104, 34),
		BackgroundColor3 = state.coins >= state.rebirthCost and Color3.fromRGB(150, 92, 220)
			or Color3.fromRGB(70, 76, 90),
	}, rebirthRow)

	rebirthBuy.Activated:Connect(function()
		Remotes.event(Remotes.Names.Rebirth):FireServer()
	end)
end

local function renderPets()
	if not state then
		return
	end
	for _, child in ipairs(petsList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Group by biome/pet/tier so a 300-pet inventory is still readable.
	local groups, order = {}, {}
	for _, record in ipairs(state.inventory) do
		local key = ("%s|%s|%d"):format(record.biome, record.pet, record.tier)
		local group = groups[key]
		if not group then
			group = { biome = record.biome, pet = record.pet, tier = record.tier,
				income = record.income, count = 0, placed = 0, firstUid = record.uid, firstPad = record.pad }
			groups[key] = group
			table.insert(order, group)
		end
		group.count += 1
		if record.pad then
			group.placed += 1
			group.firstPad = group.firstPad or record.pad
		else
			group.firstUid = record.uid
		end
	end

	table.sort(order, function(a, b)
		return a.income > b.income
	end)

	if #order == 0 then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = MUTED,
			Text = "No pets yet — grab an egg from a nest.",
		}, petsList)
		return
	end

	for index, group in ipairs(order) do
		local frame = row(petsList, index)
		local tierName = Config.Fuse.tierNames[group.tier + 1] or ""

		new("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -190, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Config.Fuse.tierColors[group.tier + 1] or TEXT,
			Text = ("%s%s  x%d"):format(tierName, group.pet, group.count),
		}, frame)

		new("TextLabel", {
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -190, 0, 20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Text = ("%s/s each  ·  %d placed"):format(Format.short(group.income), group.placed),
		}, frame)

		local place = button({
			Text = group.placed < group.count and "Place" or "Store",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -96, 0.5, 0),
			Size = UDim2.fromOffset(78, 32),
		}, frame)

		place.Activated:Connect(function()
			if group.placed < group.count then
				Remotes.event(Remotes.Names.PlacePet):FireServer(group.firstUid)
			elseif group.firstPad then
				Remotes.event(Remotes.Names.StorePet):FireServer(group.firstPad)
			end
		end)

		local unplaced = group.count - group.placed
		local canFuse = unplaced >= Config.Fuse.copiesRequired and group.tier < Config.Fuse.maxTier
		local fuse = button({
			Text = ("Fuse %d"):format(Config.Fuse.copiesRequired),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(78, 32),
			BackgroundColor3 = canFuse and Color3.fromRGB(198, 132, 44) or Color3.fromRGB(70, 76, 90),
		}, frame)

		if canFuse then
			fuse.Activated:Connect(function()
				Remotes.event(Remotes.Names.Fuse):FireServer(group.biome, group.pet, group.tier)
			end)
		end
	end
end

local function render()
	if not state then
		return
	end

	coinsLabel.Text = Format.comma(math.floor(state.coins))
	statsLabel.Text = ("%s/s   ·   luck x%.2f   ·   speed %d   ·   rebirth %d")
		:format(Format.short(state.income), state.luck, math.floor(state.walkSpeed), state.rebirths)

	local ratio = state.storageCap > 0 and math.clamp(state.vault / state.storageCap, 0, 1) or 0
	vaultLabel.Text = ("Vault %s / %s"):format(Format.short(state.vault), Format.short(state.storageCap))
	TweenService:Create(barFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
	barFill.BackgroundColor3 = ratio > 0.95 and BAD or GOOD

	dailyButton.BackgroundColor3 = state.dailyReady and Color3.fromRGB(198, 132, 44)
		or Color3.fromRGB(70, 76, 90)
	dailyButton.Text = state.dailyReady and ("Daily +" .. Format.short(state.dailyReward)) or "Daily"

	if shopPanel.Visible then
		renderShop()
	end
	if petsPanel.Visible then
		renderPets()
	end
end

-- Rebuild the open panel when it is opened, not only on state changes.
shopButton.Activated:Connect(renderShop)
petsButton.Activated:Connect(renderPets)

-- --------------------------------------------------------------- toasts ----

local toastHolder = new("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(420, 200),
	BackgroundTransparency = 1,
}, gui)

new("UIListLayout", {
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local toastOrder = 0

local function toast(text, tone)
	toastOrder += 1
	local color = tone == "good" and GOOD or tone == "bad" and BAD or tone == "warn" and WARN or TEXT

	local frame = corner(new("Frame", {
		Size = UDim2.fromOffset(420, 30),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		LayoutOrder = toastOrder,
	}, toastHolder), 8)

	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = color,
		Text = text,
	}, frame)

	task.delay(4, function()
		TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		task.wait(0.35)
		frame:Destroy()
	end)
end

-- ------------------------------------------------------------- remotes -----

Reveal.mount(gui)

Remotes.event(Remotes.Names.StateChanged).OnClientEvent:Connect(function(snapshot)
	state = snapshot
	render()
end)

Remotes.event(Remotes.Names.Notify).OnClientEvent:Connect(toast)

Remotes.event(Remotes.Names.HatchResult).OnClientEvent:Connect(function(result)
	Reveal.play(result)
end)

Remotes.event(Remotes.Names.StealProgress).OnClientEvent:Connect(function(padIndex, active)
	if active then
		toast(("Someone is stealing from pad %d!"):format(padIndex), "bad")
	end
end)

-- The limited-egg countdown ticks locally between snapshots.
task.spawn(function()
	while true do
		task.wait(1)
		if state and state.limited then
			state.limited.secondsLeft = math.max((state.limited.secondsLeft or 0) - 1, 0)
			limitedLabel.Text = state.limited.active
				and ("⚡ %s egg boosted — %s left"):format(state.limited.petId, Format.clock(state.limited.secondsLeft))
				or ("Next limited egg: %s"):format(Format.clock(state.limited.secondsLeft))
			limitedLabel.TextColor3 = state.limited.active and WARN or MUTED
		end
	end
end)
