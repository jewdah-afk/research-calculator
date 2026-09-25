--!strict
--[[
	GridTile: a corruption disk (cp grid cells, DESIGN.md 5.7 "Corruption tile" and 6 cp).

	    empty      quiet slot: the slot number only (#5f8a58)
	    corrupted  Trojan: lime dashed rim; Backdoor: crimson dashed rim; kind (caps) + LV (big)
	    active / chosen  gold rim and the fix bar from gp (per mille)
	From gs / lv / kind / gp only (plan P9: there is no "fixed" tile state).
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Recipes = require(Core:WaitForChild("Recipes"))
local Common = require(script.Parent:WaitForChild("Common"))

local GridTile = {}

local C = Theme.C

function GridTile.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local size = if ctx.mode == "COMPACT" then 84 else 104
	local gs = n.gs
	local backdoor = n.kind == "backdoor"
	local rimColor = if gs == "active" or gs == "chosen" then C.complete elseif backdoor then C.danger else C.termLime
	b.Visible = true
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(size, size)
	b.AutomaticSize = Enum.AutomaticSize.None
	for _, name in { "Gradient", "Glow", "Num", "Limit", "Pad" } do Common.drop(b, name) end
	Common.corner(b, 12)
	if gs == "empty" then
		Common.fill(b, Color3.fromRGB(8, 20, 10), Color3.fromRGB(4, 12, 6))
		Common.stroke(b, 1, C.stableId, 0.5)
	else
		Common.fill(b, Color3.fromRGB(10, 34, 14), Color3.fromRGB(4, 16, 7))
		local s = Common.stroke(b, 2, rimColor, 0)
		if gs == "corrupted" then Recipes.dashed(s, { color = rimColor }) else Common.drop(s, "Dash") end
	end
	Common.text(label, "small", C.termLime)
	label.Size = UDim2.fromScale(1, 1)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Visible = true
	local slot = Common.str(n.id) or ""
	local text: string
	if gs == "empty" then
		text = Common.run(Common.esc(slot), "label", C.stableId)
	else
		local kind = if backdoor then "Backdoor" else "Trojan"
		text = Common.caps(kind, rimColor) .. "\n" .. Common.caps("Lv", C.termDim) .. " " .. Common.num(Common.str(n.lv) or "0", "number", C.text)
			.. "\n" .. Common.run(Common.esc(slot), "label", C.termDim)
	end
	Common.setText(label, text)
	local gp = Common.pr(n.gp)
	if gp and (gs == "active" or gs == "chosen") then
		local bar = Common.bar(b, "Bar", gp, C.complete, 5)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -8)
		bar.Size = UDim2.new(1, -20, 0, 5)
		bar.ZIndex = 4
	else
		Common.drop(b, "Bar")
	end
	Common.state(b, if gs == "empty" then "notyet" else "can")
	return true
end

return GridTile
