--!strict
--[[
	Band: the COMPACT panel band (DESIGN.md 5.10) that replaces the capsule while a full-screen panel is open on a
	phone: the layer's emblem, its title (R3, `title` COMPACT step), the READY switcher (up to 3 mini gems of the other
	READY layers + "+N" after a bolt; a tap opens that layer) and a 44 du close button left of the Roblox "···".

	    local part = Band.new(parent)
	    part:show(layer?, title?, sym?)   part:setReady({ { layer, sym } })   part.close ()   part.switch (layer)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Ready = require(script.Parent:WaitForChild("Ready"))

export type Entry = { layer: string, sym: string }
export type Band = {
	frame: Frame,
	close: Signal.Signal<>,
	switch: Signal.Signal<string>,
	show: (self: Band, layer: string?, title: string?, sym: string?) -> (),
	setReady: (self: Band, list: { Entry }) -> (),
	destroy: (self: Band) -> (),
}

local Band = {}

function Band.new(parent: GuiObject): Band
	local self = {} :: Band
	self.close = Signal.new() :: Signal.Signal<>
	self.switch = Signal.new() :: Signal.Signal<string>
	local f = Kit.frame(parent, "PanelBand", 8)
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, 6)
	f.Size = UDim2.new(1, -24, 0, 44)
	f.BackgroundColor3 = Theme.C.deep
	f.BackgroundTransparency = 0.08
	f.Visible = false
	Kit.corner(f, UDim.new(0, 14))
	local rim = Kit.stroke(f, 1.5, Theme.C.strokeHi, 1, "Rim")
	local title = Kit.label(f, "Title", "section", "", Color3.new(1, 1, 1))
	title.Position = UDim2.fromOffset(50, 0)
	title.Size = UDim2.new(1, -110, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	Kit.textStroke(title, 2, 0.9)
	local closeB = Kit.button(f, "Close")
	closeB.AnchorPoint = Vector2.new(1, 0.5)
	closeB.Position = UDim2.new(1, -4, 0.5, 0)
	closeB.Size = UDim2.fromOffset(44, 44)
	local x = Kit.glyph(closeB, "Icon", "x", Color3.new(1, 1, 1))
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)
	x.Size = UDim2.fromOffset(18, 18)
	closeB.Activated:Connect(function() self.close:Fire() end)
	self.frame = f
	-- the READY switcher, left of the close
	local sw = Kit.frame(f, "Switch", 9)
	sw.AnchorPoint = Vector2.new(1, 0.5)
	sw.Position = UDim2.new(1, -54, 0.5, 0)
	sw.Size = UDim2.fromOffset(0, 38)
	sw.AutomaticSize = Enum.AutomaticSize.X
	Kit.list(sw, "x", 2, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local current: string? = nil
	local entries: { Entry } = {}
	local swW = 0
	local function drawSwitch()
		for _, c in sw:GetChildren() do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		local shown, more = 0, 0
		for _, e in entries do
			if e.layer ~= current then
				if shown < 3 then
					shown += 1
					local b = Kit.button(sw, "Gem_" .. e.layer)
					b.LayoutOrder = 1 + shown
					b.Size = UDim2.fromOffset(28, 38)
					local g = Ready.gem(b, "Disc", e.layer, e.sym, 28)
					g.AnchorPoint = Vector2.new(0.5, 0.5)
					g.Position = UDim2.fromScale(0.5, 0.5)
					local layer = e.layer
					b.Activated:Connect(function() self.switch:Fire(layer) end)
				else
					more += 1
				end
			end
		end
		swW = 0
		if shown > 0 then
			local bolt = Kit.glyph(sw, "Bolt", "bolt", Color3.fromHex("ffe08a"))
			bolt.LayoutOrder = 1
			bolt.Size = UDim2.fromOffset(14, 14)
			swW = 16 + shown * 30
		end
		if more > 0 then
			local m = Kit.label(sw, "More", "badge", "+" .. more, Color3.fromHex("ffe08a"))
			m.LayoutOrder = 10
			m.AutomaticSize = Enum.AutomaticSize.X
			m.Size = UDim2.fromOffset(0, 38)
			swW += 30
		end
		title.Size = UDim2.new(1, -110 - swW, 1, 0)
	end
	function self.setReady(_: Band, list: { Entry })
		local sig = ""
		for _, e in list do sig ..= e.layer .. "," end
		if sw:GetAttribute("Sig") == sig .. tostring(current) then return end
		sw:SetAttribute("Sig", sig .. tostring(current))
		entries = list
		drawSwitch()
	end
	function self.show(_: Band, layer: string?, text: string?, sym: string?)
		if layer == nil then
			f.Visible = false
			current = nil
			return
		end
		if current ~= layer then
			current = layer
			sw:SetAttribute("Sig", nil)
			drawSwitch()
		end
		local old = f:FindFirstChild("Emblem")
		if old then old:Destroy() end
		local g = Ready.gem(f, "Emblem", layer, sym or string.upper(layer), 34)
		g.AnchorPoint = Vector2.new(0, 0.5)
		g.Position = UDim2.new(0, 8, 0.5, 0)
		rim.Color = Theme.lift(Theme.hue(layer), 0.3)
		title.Text = string.upper(text or layer)
		Theme.text(title, "section")
		f.Visible = true
	end
	function self.destroy(b: Band)
		b.close:DisconnectAll()
		b.switch:DisconnectAll()
		f:Destroy()
	end
	return self
end

return Band
