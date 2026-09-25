--!strict
--[[
	Legacy: the old page UI (the web page's "Revamped" layout: the menu of layers, the points header, the current
	layer's tab), kept for Studio only as a fallback while the new client settles. A small CLASSIC PAGE switch at
	the left edge turns it on over the new UI (and BACK TO THE MAP off). It is deleted with the old menu / head
	view roots.

	    local legacy = Legacy.start({ remotes, setActive = fn(on) })
	    legacy:onPatch(patch)     App forwards every View patch
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("MilestoneTree")
local Html = require(shared:WaitForChild("Html"))
local Style = require(script.Parent:WaitForChild("Style"))
local Render = require(script.Parent:WaitForChild("Render"))

local Legacy = {}

-- the page: built the first time the switch turns it on
local function build(remotes: Instance)
local player = Players.LocalPlayer
local actRemote = remotes:WaitForChild("Act") :: RemoteEvent
local importRemote = remotes:WaitForChild("Import") :: RemoteEvent

-- ------------------------------------------------------------------------------------------------------ the screen
local MENU_W = 325

local gui = Instance.new("ScreenGui")
gui.Name = "MilestoneTree"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local page = Instance.new("Frame")
page.Name = "Page"
page.Size = UDim2.fromScale(1, 1)
page.BackgroundColor3 = Style.BG
page.BorderSizePixel = 0
page.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = page

local menu = Instance.new("ScrollingFrame")
menu.Name = "Menu"
menu.Size = UDim2.new(0, MENU_W, 1, 0)
menu.BackgroundColor3 = Style.BG
menu.BorderSizePixel = 0
menu.ScrollBarThickness = 6
menu.CanvasSize = UDim2.new()
menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
menu.ZIndex = 5
menu.Parent = page
Style.stroke(menu, 3, Color3.fromRGB(122, 122, 122), 0)
local menuRoot = Instance.new("Frame")
menuRoot.Name = "MenuRoot"
menuRoot.BackgroundTransparency = 1
menuRoot.Size = UDim2.new(1, -8, 0, 0)
menuRoot.Position = UDim2.fromOffset(4, 8)
menuRoot.AutomaticSize = Enum.AutomaticSize.Y
menuRoot.Parent = menu

local main = Instance.new("ScrollingFrame")
main.Name = "Main"
main.BackgroundColor3 = Style.BG
main.BorderSizePixel = 0
main.ScrollBarThickness = 8
main.CanvasSize = UDim2.new()
main.AutomaticCanvasSize = Enum.AutomaticSize.Y
main.Parent = page
local mainList = Instance.new("UIListLayout")
mainList.SortOrder = Enum.SortOrder.LayoutOrder
mainList.HorizontalAlignment = Enum.HorizontalAlignment.Center
mainList.Padding = UDim.new(0, 10)
mainList.Parent = main
local mainPad = Instance.new("UIPadding")
mainPad.PaddingTop = UDim.new(0, 10)
mainPad.PaddingBottom = UDim.new(0, 60)
mainPad.PaddingLeft = UDim.new(0, 8)
mainPad.PaddingRight = UDim.new(0, 8)
mainPad.Parent = main

local function rootFrame(name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	f.Parent = main
	return f
end
local headRoot = rootFrame("HeadRoot", 1)
local tabRoot = rootFrame("TabRoot", 2)

-- what the page says while the server gets the game ready, and any error that stops it
local status = Instance.new("TextLabel")
status.Name = "Status"
status.LayoutOrder = 0
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -40, 0, 0)
status.AutomaticSize = Enum.AutomaticSize.Y
status.TextWrapped = true
status.RichText = true
status.FontFace = Style.FONT
status.TextSize = 20
status.TextColor3 = Style.TEXT
status.Text = "Loading your game..."
status.Parent = main
local function setStatus(text: string?, isError: boolean?)
	status.Visible = text ~= nil
	status.Text = if text then Html.escape(text) else ""
	status.TextColor3 = if isError then Color3.fromRGB(255, 90, 90) else Style.TEXT
end

local menuShown = true
local toggle = Instance.new("TextButton")
toggle.Name = "MenuToggle"
toggle.Size = UDim2.fromOffset(40, 60)
toggle.BackgroundColor3 = Style.BG
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.FontFace = Style.FONT
toggle.TextSize = 30
toggle.ZIndex = 6
toggle.Parent = page
Style.stroke(toggle, 2, Color3.fromRGB(122, 122, 122), 0)

local function layout()
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	-- the page is laid out for a 1280 px wide browser window and scaled to the screen
	local s = math.clamp(vp.X / 1280, 0.8, 1.6)
	uiScale.Scale = s
	local narrow = vp.X / s < 900
	menu.Visible = menuShown
	local left = if menuShown then MENU_W + 4 else 0
	main.Position = UDim2.fromOffset(left, 0)
	main.Size = UDim2.new(1, -left, 1, 0)
	toggle.Position = UDim2.fromOffset(if menuShown then MENU_W + 6 else 2, 70)
	toggle.Text = if menuShown then "<" else ">"
	if narrow and menuShown then main.Size = UDim2.new(1, -left, 1, 0) end
end
toggle.Activated:Connect(function()
	menuShown = not menuShown
	layout()
end)

-- --------------------------------------------------------------------------------------------- overlays (on top)
local overlay = Instance.new("ScreenGui")
overlay.Name = "MilestoneTreeOverlay"
overlay.ResetOnSpawn = false
overlay.DisplayOrder = 20
overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local overlayScale = Instance.new("UIScale")
overlayScale.Parent = overlay

-- tooltip
local tip = Instance.new("Frame")
tip.Name = "Tooltip"
tip.Visible = false
tip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
tip.BackgroundTransparency = 0.05
tip.AutomaticSize = Enum.AutomaticSize.XY
tip.Size = UDim2.new()
tip.ZIndex = 50
tip.Parent = overlay
Style.pad(tip, 7)
Style.corner(tip, 6)
Style.stroke(tip, 1, Style.TEXT, 0.6)
local tipText = Instance.new("TextLabel")
tipText.BackgroundTransparency = 1
tipText.AutomaticSize = Enum.AutomaticSize.XY
tipText.Size = UDim2.new()
tipText.RichText = true
tipText.TextWrapped = true
tipText.FontFace = Style.FONT
tipText.TextSize = 14
tipText.TextColor3 = Style.TEXT
tipText.ZIndex = 51
tipText.Parent = tip
local tipLimit = Instance.new("UISizeConstraint")
tipLimit.MaxSize = Vector2.new(320, math.huge)
tipLimit.Parent = tipText
local tipOwner: GuiObject? = nil

local function moveTip()
	if not tip.Visible then return end
	local m = UserInputService:GetMouseLocation()
	local s = overlayScale.Scale
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local size = tip.AbsoluteSize
	local x = math.clamp(m.X + 16, 0, math.max(0, vp.X - size.X - 4))
	local y = m.Y - size.Y - 12
	if y < 0 then y = m.Y + 20 end
	tip.Position = UDim2.fromOffset(x / s, y / s)
end

local function showTip(html: string?, over: GuiObject?)
	if html == nil then
		if tipOwner == over then tip.Visible = false; tipOwner = nil end
		return
	end
	tipOwner = over
	tipText.Text = Html.rich(html, 14)
	tip.Visible = true
	moveTip()
end
UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement then moveTip() end
end)

-- toasts (the page's popups: achievements, milestones, and messages from the server)
local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.BackgroundTransparency = 1
toasts.AnchorPoint = Vector2.new(1, 0)
toasts.Position = UDim2.new(1, -20, 0, 10)
toasts.Size = UDim2.fromOffset(300, 0)
toasts.AutomaticSize = Enum.AutomaticSize.Y
toasts.Parent = overlay
local toastList = Instance.new("UIListLayout")
toastList.Padding = UDim.new(0, 10)
toastList.SortOrder = Enum.SortOrder.LayoutOrder
toastList.Parent = toasts
local toastN = 0

local POPUP_BG = { ["achievement-popup"] = "7182BC", ["milestone-popup"] = "D1C23C", ["challenge-popup"] = "9BBC71", ["default-popup"] = "5a5a5a" }

local function toast(title: string?, message: string, bg: Color3?, border: Color3?, seconds: number?)
	toastN += 1
	local f = Instance.new("TextButton")
	f.Text = ""
	f.AutoButtonColor = false
	f.LayoutOrder = toastN
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = bg or Color3.fromRGB(60, 60, 60)
	f.Parent = toasts
	Style.corner(f, 7)
	Style.stroke(f, 4, border or Style.DARK, if border then 0 else 0.75)
	Style.pad(f, 10)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.RichText = true
	l.TextWrapped = true
	l.FontFace = Style.FONT
	l.TextSize = 14
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = (if title and title ~= "" then Html.rich("<h3>" .. title .. "</h3>", 14) .. "\n" else "") .. Html.rich(message, 16)
	l.Parent = f
	f.Activated:Connect(function() f:Destroy() end)
	task.delay(seconds or 4, function() if f.Parent then f:Destroy() end end)
	while #toasts:GetChildren() > 7 do
		local oldest: Instance? = nil
		for _, c in toasts:GetChildren() do
			if c:IsA("GuiObject") and (oldest == nil or c.LayoutOrder < (oldest :: GuiObject).LayoutOrder) then oldest = c end
		end
		if oldest then oldest:Destroy() else break end
	end
end

-- "not saving" banner
local banner = Instance.new("TextLabel")
banner.Name = "Unsaved"
banner.Visible = false
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 4)
banner.Size = UDim2.fromOffset(520, 26)
banner.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
banner.TextColor3 = Color3.new(1, 1, 1)
banner.FontFace = Style.FONT
banner.TextSize = 14
banner.Text = "Your progress is NOT being saved right now (see the messages). Rejoin to retry."
banner.Parent = overlay
Style.corner(banner, 6)

-- the export / import box
local modal = Instance.new("Frame")
modal.Name = "Modal"
modal.Visible = false
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(560, 300)
modal.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
modal.ZIndex = 40
modal.Parent = overlay
Style.corner(modal, 10)
Style.stroke(modal, 3, Color3.fromRGB(122, 122, 122), 0)
Style.pad(modal, 12)
local modalTitle = Instance.new("TextLabel")
modalTitle.BackgroundTransparency = 1
modalTitle.Size = UDim2.new(1, 0, 0, 28)
modalTitle.FontFace = Style.FONT
modalTitle.TextSize = 20
modalTitle.TextColor3 = Style.TEXT
modalTitle.ZIndex = 41
modalTitle.Parent = modal
local modalBox = Instance.new("TextBox")
modalBox.Position = UDim2.fromOffset(0, 36)
modalBox.Size = UDim2.new(1, 0, 1, -88)
modalBox.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
modalBox.TextColor3 = Style.TEXT
modalBox.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
modalBox.TextSize = 12
modalBox.TextWrapped = true
modalBox.TextXAlignment = Enum.TextXAlignment.Left
modalBox.TextYAlignment = Enum.TextYAlignment.Top
modalBox.MultiLine = true
modalBox.ClearTextOnFocus = false
modalBox.ClipsDescendants = true
modalBox.ZIndex = 41
modalBox.Parent = modal
Style.pad(modalBox, 6)
local function modalButton(text: string, x: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, x, 1, 0)
	b.Size = UDim2.fromOffset(130, 40)
	b.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = Style.FONT
	b.TextSize = 16
	b.Text = text
	b.ZIndex = 41
	b.Parent = modal
	Style.corner(b, 6)
	return b
end
local modalOk = modalButton("Import", -140)
local modalClose = modalButton("Close", 0)
local modalMode = "export"
modalClose.Activated:Connect(function() modal.Visible = false end)
modalOk.Activated:Connect(function()
	if modalMode == "import" and modalBox.Text ~= "" then
		importRemote:FireServer(modalBox.Text)
		modal.Visible = false
	end
end)

local function openModal(mode: string, text: string?)
	modalMode = mode
	modal.Visible = true
	modalOk.Visible = mode == "import"
	if mode == "export" then
		modalTitle.Text = "Your save (select it all and copy)"
		modalBox.Text = text or ""
		modalBox.PlaceholderText = ""
		task.defer(function()
			modalBox:CaptureFocus()
			modalBox.SelectionStart = 1
			modalBox.CursorPosition = #modalBox.Text + 1
		end)
	else
		modalTitle.Text = "Paste a save (from Export here or on the web game)"
		modalBox.Text = ""
		modalBox.PlaceholderText = "save string..."
		task.defer(function() modalBox:CaptureFocus() end)
	end
end

-- ---------------------------------------------------------------------------------------------------- the renderer
local lastPress = 0
local function press(a: any, hold: boolean)
	if not hold and os.clock() - lastPress < 0.03 then return end
	lastPress = os.clock()
	actRemote:FireServer(a, hold)
end
local renderer = Render.new({ menu = menuRoot, head = headRoot, tab = tabRoot }, {
	press = press,
	tip = showTip,
})

local keys: { [string]: boolean } = {}

local function applyTabStyle(st: any)
	main.BackgroundColor3 = Style.BG
	main.BackgroundTransparency = 0
	if type(st) == "table" then Style.apply(main, st) else Style.drop(main, "Gradient") end
end

local gotScreen = false
local failed = false
local active = true
local function onPatch(patch: any)
	if type(patch) ~= "table" then return end
	if patch.fatal then
		failed = true
		setStatus(tostring(patch.fatal) .. "\n\n(The same error is in Studio's Output window: View > Output.)", true)
		return
	end
	if patch.status then
		if not gotScreen and not failed then setStatus(tostring(patch.status)) end
		return
	end
	local ok, err = pcall(function() renderer:apply(patch) end)
	if not ok then
		warn("[MilestoneTree] drawing the screen failed: " .. tostring(err))
		setStatus("Drawing the screen failed: " .. tostring(err), true)
		failed = true
	elseif patch.set and next(patch.set) ~= nil and not failed then
		gotScreen = true
		setStatus(nil)
	end
	if patch.tabStyle then applyTabStyle(patch.tabStyle) end
	if patch.keys then
		keys = {}
		for _, k in patch.keys do keys[k] = true end
	end
	banner.Visible = patch.unsaved == true
	for _, p in patch.pop or {} do
		local bg = Html.color(p.color ~= "" and p.color or nil) or Color3.fromHex(POPUP_BG[p.type] or "5a5a5a")
		toast(p.title, p.message, bg, Html.color(p.bColor ~= "" and p.bColor or nil), 3)
	end
	for _, msg in patch.notice or {} do toast(nil, msg, nil, nil, 6) end
	if patch.export then openModal("export", patch.export) end
	if patch.askImport then openModal("import") end
end

-- ------------------------------------------------------------------------------------------------------- hotkeys
local ARROWS = {
	[Enum.KeyCode.Up] = "ArrowUp", [Enum.KeyCode.Down] = "ArrowDown", [Enum.KeyCode.Left] = "ArrowLeft", [Enum.KeyCode.Right] = "ArrowRight",
	[Enum.KeyCode.Return] = "Enter", [Enum.KeyCode.Space] = " ", [Enum.KeyCode.Escape] = "Escape", [Enum.KeyCode.Tab] = "Tab",
}
local function keyName(input: InputObject): string?
	local kc = input.KeyCode
	local name = ARROWS[kc]
	if name == nil then
		local v = kc.Value
		if v >= Enum.KeyCode.A.Value and v <= Enum.KeyCode.Z.Value then
			name = string.char(97 + v - Enum.KeyCode.A.Value)
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then name = string.upper(name :: string) end
		elseif v >= Enum.KeyCode.Zero.Value and v <= Enum.KeyCode.Nine.Value then
			name = tostring(v - Enum.KeyCode.Zero.Value)
		end
	end
	if name == nil then return nil end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		name = "ctrl+" .. (name :: string)
	end
	return name
end
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not active or processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if UserInputService:GetFocusedTextBox() then return end
	local name = keyName(input)
	if name and keys[name] then actRemote:FireServer({ "key", name }, false) end
end)

-- ---------------------------------------------------------------------------------------------------------- start
local function watchCamera()
	local cam = Workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

gui.Parent = player:WaitForChild("PlayerGui")
overlay.Parent = player:WaitForChild("PlayerGui")
return {
	onPatch = onPatch,
	setActive = function(on: boolean)
		active = on
		gui.Enabled = on
		overlay.Enabled = on
	end,
}
end

-- the switch (the left edge): CLASSIC shows the page, MAP goes back to the realm map
function Legacy.start(o: { remotes: Instance, setActive: (on: boolean) -> () })
	local readyRemote = o.remotes:WaitForChild("Ready") :: RemoteEvent
	local page: any = nil
	local on = false
	local sg = Instance.new("ScreenGui")
	sg.Name = "ClassicSwitch"
	sg.ResetOnSpawn = false
	sg.AutoLocalize = false
	sg.DisplayOrder = 60
	sg.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local b = Instance.new("TextButton")
	b.Name = "Switch"
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 6, 0.5, 0)
	b.Size = UDim2.fromOffset(120, 30)
	b.BackgroundColor3 = Color3.fromRGB(26, 22, 40)
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.fromRGB(200, 196, 220)
	b.FontFace = Style.FONT
	b.TextSize = 13
	b.AutoButtonColor = true
	Style.corner(b, 15)
	b.Parent = sg
	sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function set(v: boolean)
		on = v
		b.Text = if v then "BACK TO THE MAP" else "CLASSIC PAGE"
		if v and page == nil then page = build(o.remotes) end
		if page then page.setActive(v) end
		o.setActive(v)
		-- the page draws from a whole view
		if v then readyRemote:FireServer() end
	end
	b.Activated:Connect(function() set(not on) end)
	set(false)
	return {
		onPatch = function(_: any, patch: any)
			if on and page then page.onPatch(patch) end
		end,
	}
end

return Legacy
