--!strict
--[[
	Band: the COMPACT panel band (DESIGN.md 5.10) that replaces the capsule while a full-screen panel is open on a
	phone: the layer's emblem, its title (R3, `title` COMPACT step) and a 44 du close button left of the Roblox "···".

	    local part = Band.new(parent)
	    part:show(layer?, title?)   part.close ()
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Ready = require(script.Parent:WaitForChild("Ready"))

export type Band = {
	frame: Frame,
	close: Signal.Signal<>,
	show: (self: Band, layer: string?, title: string?) -> (),
	destroy: (self: Band) -> (),
}

local Band = {}

function Band.new(parent: GuiObject): Band
	local self = {} :: Band
	self.close = Signal.new() :: Signal.Signal<>
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
	function self.show(_: Band, layer: string?, text: string?)
		if layer == nil then
			f.Visible = false
			return
		end
		local old = f:FindFirstChild("Emblem")
		if old then old:Destroy() end
		local g = Ready.gem(f, "Emblem", layer, string.upper(layer), 34)
		g.AnchorPoint = Vector2.new(0, 0.5)
		g.Position = UDim2.new(0, 8, 0.5, 0)
		rim.Color = Theme.lift(Theme.hue(layer), 0.3)
		title.Text = string.upper(text or layer)
		Theme.text(title, "section")
		f.Visible = true
	end
	function self.destroy(b: Band)
		b.close:DisconnectAll()
		f:Destroy()
	end
	return self
end

return Band
