--!strict
--[[
	UniverseTag: inside the Prestige Multiverse, a tag hanging under the capsule (DESIGN.md 4.3): a swirl, the state in
	sentence case ("Goal met: leaving will finish" / "Goal not met: leaving exits early", `small`, #ffd0dc) and the
	FINISH / EXIT hold chip (dark ink on the gold gradient, a ring glyph for the hold; 1.2 s, Recipes.hold).

	    local part = UniverseTag.new(parent)
	    part:update(gate?)      shown only while gate.inside
	    part:setTop(y)          du below the Root top
	    part.hold ()            the hold completed (Hud forwards it as gateHold)
]]

local Core = script.Parent.Parent:WaitForChild("Core")
local Types = require(script.Parent.Parent:WaitForChild("Types"))
local Signal = require(Core:WaitForChild("Signal"))
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Rich = require(Core:WaitForChild("Rich"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Kit = require(script.Parent:WaitForChild("Kit"))

export type UniverseTag = {
	frame: Frame,
	hold: Signal.Signal<>,
	update: (self: UniverseTag, gate: Types.Gate?) -> (),
	setTop: (self: UniverseTag, y: number, x: number?) -> (),
	destroy: (self: UniverseTag) -> (),
}

local UniverseTag = {}

local CRIMSON = Color3.fromHex("ff2e63")
local PINK = Color3.fromHex("ffd0dc")
local INK = Color3.fromHex("2a1a00")

function UniverseTag.new(parent: GuiObject): UniverseTag
	local self = {} :: UniverseTag
	self.hold = Signal.new() :: Signal.Signal<>
	local f = Kit.frame(parent, "UniTag", 6)
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = Color3.fromHex("1a0a24")
	f.BackgroundTransparency = 0.08
	f.Visible = false
	Kit.corner(f)
	Kit.stroke(f, 1.5, CRIMSON, 0.9, "Rim")
	Kit.list(f, "x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	self.frame = f
	local swirl = Kit.glyph(f, "Swirl", "swirl", Theme.lift(CRIMSON, 0.2))
	swirl.LayoutOrder = 1
	local text = Kit.label(f, "Label", "small", "", PINK)
	text.LayoutOrder = 2
	text.AutomaticSize = Enum.AutomaticSize.X

	local chip = Kit.button(f, "Finish")
	chip.LayoutOrder = 3
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	Kit.corner(chip)
	Kit.grad(chip, { Color3.fromHex("ffe89a"), Color3.fromHex("ffc233"), Color3.fromHex("d99a1a") }, 90, nil, "Back")
	local inner = Kit.frame(chip, "Content")
	inner.AutomaticSize = Enum.AutomaticSize.X
	inner.Size = UDim2.fromScale(0, 1)
	Kit.list(inner, "x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local ring = Kit.glyph(inner, "Ring", "ring", INK)
	ring.LayoutOrder = 1
	local verb = Kit.label(inner, "Verb", "label", "", INK)
	verb.LayoutOrder = 2
	verb.AutomaticSize = Enum.AutomaticSize.X
	local holder = Recipes.hold(chip, { dur = 1.2, ring = false, color = Color3.new(0, 0, 0), onDone = function()
		self.hold:Fire()
	end })
	local _ = holder

	local function place()
		local compact = Layout.mode == "COMPACT"
		local h = if compact then 36 else 40
		f.Size = UDim2.fromOffset(0, h)
		Kit.pad(f, 0, 5, 0, 12)
		swirl.Size = UDim2.fromOffset(18, 18)
		Theme.text(text, "small")
		text.Size = UDim2.fromScale(0, 1)
		chip.Size = UDim2.fromOffset(0, h - 10)
		Kit.pad(chip, 0, 12, 0, 10)
		ring.Size = UDim2.fromOffset(14, 14)
		Theme.text(verb, "label")
		verb.Size = UDim2.fromScale(0, 1)
	end
	place()
	Layout.changed:Connect(place)

	function self.update(_: UniverseTag, gate: Types.Gate?)
		local on = gate ~= nil and gate.inside
		f.Visible = on
		if not on or gate == nil then return end
		text.Text = if gate.fin then "Goal met: leaving will finish" else "Goal not met: leaving exits early"
		verb.Text = Rich.caps(if gate.fin then "Finish" else "Exit")
	end
	function self.setTop(_: UniverseTag, y: number, x: number?)
		f.Position = if x then UDim2.fromOffset(x, y) else UDim2.new(0.5, 0, 0, y)
	end
	function self.destroy(u: UniverseTag)
		u.hold:DisconnectAll()
		holder:destroy()
		f:Destroy()
	end
	return self
end

return UniverseTag
