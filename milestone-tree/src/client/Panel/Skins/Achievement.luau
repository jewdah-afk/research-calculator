--!strict
--[[
	Achievement: a trophy tile (Figma 5:180, DESIGN.md 5.7): a done achievement is a gold medallion with its number, a
	missing one a quiet slate with the number dim. The name and goal stay in the game's tooltip (hover), as sent.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))

local Achievement = {}

local C = Theme.C

function Achievement.skin(rec: any, n: any, ctx: any): boolean
	local root = rec.root :: Frame
	local l = root:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local size = if ctx.mode == "COMPACT" then 72 else 92
	root.Visible = true
	root.Size = UDim2.fromOffset(size, size)
	root.AutomaticSize = Enum.AutomaticSize.None
	for _, name in { "Gradient", "List", "Pad", "Limit", "Shadow" } do Common.drop(root, name) end
	Common.drop(label, "Shadow")
	Common.drop(root, "Num")
	local kids = root:FindFirstChild("Kids")
	if kids and kids:IsA("GuiObject") then kids.Visible = false end
	if n.done then
		Common.fill(root, Theme.lift(C.gold, 0.25), Theme.shade(C.complete, 0.62))
		Common.corner(root, 0.5)
		Common.stroke(root, 3, Theme.lift(C.gold, 0.4), 0)
		Common.glow(root, C.gold, 0.35, 12)
	else
		Common.fill(root, C.panel3, C.panel2)
		Common.corner(root, 0.5)
		Common.stroke(root, 2, C.stroke, 0)
		Common.glow(root, nil)
	end
	Common.text(label, "index", if n.done then C.ink else C.muted)
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.new()
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.Visible = true
	Common.setText(label, Common.esc(Common.str(n.num) or Common.str(n.id) or "?"))
	Common.state(root, if n.done then "owned" else "locked")
	return true
end

return Achievement
