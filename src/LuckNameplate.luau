--!strict
--[[
	LuckNameplate — the "Luck#N" plate above a player's head.

	THE ZOOM FIX: BillboardGui.Size expressed in Scale is world-space studs, so
	the plate behaves like a physical object and shrinks as the camera pulls
	back. Expressed in OFFSET it is screen pixels, so it holds a constant
	on-screen size at any distance. Children must be offset-sized too, or they
	reintroduce the scaling.

	Verify in-engine — this is the documented meaning of the units, but I could
	not test it here.
]]

local RarityNames = require(script.Parent.RarityNames)
local RarityColor = require(script.Parent.RarityColor)

local LuckNameplate = {}
LuckNameplate.__index = LuckNameplate

local PLATE_W, PLATE_H = 260, 58   -- pixels, constant at every zoom level

export type Plate = typeof(setmetatable({} :: {
	gui: BillboardGui,
	label: TextLabel,
	sub: TextLabel,
	stroke: UIStroke,
	shown: number,
}, LuckNameplate))

function LuckNameplate.new(adornee: BasePart): Plate
	local gui = Instance.new("BillboardGui")
	gui.Name = "LuckNameplate"
	gui.Adornee = adornee
	-- OFFSET, not Scale. This is the whole fix.
	gui.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true          -- never clips into geometry or VFX
	gui.LightInfluence = 0          -- the room is dark; don't let it dim
	gui.MaxDistance = 180           -- cull distant plates rather than clutter
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(PLATE_W, 34)   -- offset, not scale
	label.Position = UDim2.fromOffset(0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextScaled = false                      -- scaling defeats the fix
	label.Text = ""
	label.Parent = gui

	-- Bold outline so it holds against a dark, busy room
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0.15
	stroke.Parent = label

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.fromOffset(PLATE_W, 20)
	sub.Position = UDim2.fromOffset(0, 34)
	sub.Font = Enum.Font.GothamMedium
	sub.TextSize = 15
	sub.TextScaled = false
	sub.TextColor3 = Color3.fromRGB(210, 214, 225)
	sub.Text = ""
	sub.Parent = gui

	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 2
	subStroke.Color = Color3.new(0, 0, 0)
	subStroke.Transparency = 0.35
	subStroke.Parent = sub

	return setmetatable({
		gui = gui, label = label, sub = sub, stroke = stroke, shown = -1,
	}, LuckNameplate)
end

--- Set the displayed rarity. Writes to the UI ONLY when the value actually
--- changed — assigning .Text is not free, and this runs per roll.
function LuckNameplate.set(self: Plate, index: number)
	if index == self.shown then
		return
	end
	local previous = self.shown
	self.shown = index

	self.label.Text = RarityNames.luckTag(index)       -- "Luck#100"
	self.sub.Text = RarityNames.display(index)         -- the name, secondary

	if previous < 0 then
		self.label.TextColor3 = RarityColor.forIndex(index)
		return
	end
	self:sweep(previous, index)
end

--- Sweep through the intermediate band colours instead of cutting straight to
--- the destination. Duration scales with how far the player jumped.
function LuckNameplate.sweep(self: Plate, fromIndex: number, toIndex: number)
	local duration = RarityColor.spikeDuration(fromIndex, toIndex)
	local RunService = game:GetService("RunService")
	local elapsed = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local a = math.min(elapsed / duration, 1)
		self.label.TextColor3 = RarityColor.spikeColorAt(fromIndex, toIndex, a)
		if a >= 1 then
			conn:Disconnect()
		end
	end)
end

function LuckNameplate.parentTo(self: Plate, container: Instance)
	self.gui.Parent = container
end

function LuckNameplate.destroy(self: Plate)
	self.gui:Destroy()
end

return LuckNameplate
