--!strict
--[[
	Perk: a perk slot (Figma 5:58, DESIGN.md 5.7): gold dashed "Explore a new perk" when it can be taken, mauve
	dashed when locked, the owned look once taken. The requirement (req) is shown as sent.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Common = require(script.Parent:WaitForChild("Common"))

local Perk = {}

local C = Theme.C

function Perk.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local state = if n.cls == "perked" or n.cls == "bought" then "owned" elseif n.cls == "perk" or n.cls == "can" then "can" else "locked"
	b.Visible = true
	b.AutoButtonColor = false
	for _, name in { "Gradient", "Glow", "Num", "Limit" } do Common.drop(b, name) end
	local p = Common.surface(b, if state == "can" then "gold" else state, ctx.hue, 14)
	local rim = b:FindFirstChild("Border")
	if rim and rim:IsA("UIStroke") and state ~= "owned" then
		Recipes.dashed(rim, { color = if state == "can" then C.gold else C.locked })
	elseif rim then
		Common.drop(rim, "Dash")
	end
	b.Size = UDim2.fromOffset(ctx.cardW, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	Common.pad(b, 14, 16, 14, 16)
	Common.text(label, "small", p.text)
	label.Visible = true
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	local parts: { string } = {}
	if state == "can" then table.insert(parts, Common.title("Explore a new perk", "card", C.text)) end
	local body = Common.html(n.h, "small", ctx.layer)
	if body ~= "" then table.insert(parts, body) end
	local req = Common.str(n.req)
	if req and state == "locked" then table.insert(parts, Common.caps("Requires", p.soft) .. "  " .. Common.html(req, "small", ctx.layer)) end
	Common.setText(label, table.concat(parts, "\n"))
	Common.state(b, state)
	return true
end

return Perk
