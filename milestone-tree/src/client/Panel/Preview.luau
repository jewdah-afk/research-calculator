--!strict
--[[
	Preview: the new layer panel over the old page UI, in Studio only, until the app shell (package I) replaces the
	page. The old Main.client feeds every View patch here; the panel follows the server's open layer (map.open), the
	way App will (plan 1.12): pick a layer in the old menu (or press its hotkey) and its new panel opens at the right;
	X / closing sends the map's own close action. Every button fires its node's own action through the old client's
	press function (the server whitelist applies as always).

	    local preview = Preview.start({ press = fn(action, hold) })   -- nil outside Studio
	    preview:onPatch(patch)

	A small toggle at the bottom left switches the preview off and on. The panel sits above the map preview (M / the
	GAME button switch the map and the page as before).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Core = script.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local ViewStore = require(Core:WaitForChild("ViewStore"))
local Panel = require(script.Parent:WaitForChild("Panel"))

local Preview = {}
Preview.__index = Preview

export type Preview = typeof(setmetatable({} :: {
	store: any,
	panel: any,
	on: boolean,
	press: (action: any, hold: boolean) -> (),
	toggle: TextButton,
	errors: number,
	closing: string?,
}, Preview))

function Preview.start(o: { press: (action: any, hold: boolean) -> () }): Preview?
	if not RunService:IsStudio() then return nil end
	Theme.detect()
	local gui = Layout.screen("PanelGui", 20, Enum.ScreenInsets.CoreUISafeInsets)
	gui.DisplayOrder = 42 -- above the map preview (40) and its button bar (41)
	local store = ViewStore.new()
	local panel = Panel.new(gui, { store = store })
	-- the toggle
	local tg = Instance.new("ScreenGui")
	tg.Name = "PanelPreviewToggle"
	tg.ResetOnSpawn = false
	tg.DisplayOrder = 43
	tg.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 12, 1, -12)
	b.Size = UDim2.fromOffset(190, 36)
	b.BackgroundColor3 = Theme.C.panel2
	b.AutoButtonColor = true
	b.FontFace = Theme.font("label")
	b.TextSize = 14
	b.TextColor3 = Theme.C.text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.C.system
	stroke.Thickness = 2
	stroke.Parent = b
	b.Parent = tg
	tg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local self = setmetatable({ store = store, panel = panel, on = true, press = o.press, toggle = b, errors = 0, closing = nil :: string? }, Preview)
	panel.act:Connect(function(a: any, hold: boolean?)
		self.press(a, hold == true)
	end)
	panel.closeRequested:Connect(function()
		local ms = store:map()
		if ms.close then self.press(ms.close, false) end
		-- the panel closes at once; a patch still showing the layer open must not reopen it
		self.closing = panel:isOpen()
		panel:close()
	end)
	b.Activated:Connect(function()
		self:setOn(not self.on)
	end)
	self:setOn(true)
	return self
end

function Preview.setOn(self: Preview, on: boolean)
	self.on = on
	self.toggle.Text = if on then "NEW PANEL · ON" else "NEW PANEL · OFF"
	self.panel.gui.Enabled = on
	if on then
		-- catch up from the store (the tree is rebuilt for the current layer)
		self.panel:update(self.store, { full = true, tab = true, tabPatch = { set = {}, del = {}, full = true } })
		self:follow()
	else
		self.panel:close()
	end
end

-- open / close / switch with the server's open layer (plan 1.12 "the server moves the tab")
function Preview.follow(self: Preview)
	local ms = self.store:map()
	local open = ms.open
	if self.closing ~= nil then
		if open == self.closing then return end
		self.closing = nil
	end
	local key = self.panel:isOpen()
	if open == key then return end
	if open then
		self.panel:open(open, ms.nodes[open])
	else
		self.panel:close()
	end
end

function Preview.onPatch(self: Preview, patch: any)
	if type(patch) ~= "table" or patch.fatal or patch.status then return end
	local ok, err = pcall(function(): any
		local changes = self.store:apply(patch)
		if not self.on then return nil end
		self.panel:update(self.store, changes)
		self:follow()
		return nil
	end)
	if not ok then
		self.errors += 1
		if self.errors <= 5 then warn("[MilestoneTree] panel preview: " .. tostring(err)) end
	end
end

return Preview
