--!strict
--[[
	CompactOwned: the quiet card of an owned upgrade inside a fully owned tier (WIDE / MEDIUM) and every expanded owned
	upgrade on phones (DESIGN.md 5.7): index + title (2 lines allowed) on the left, the effect value in the owned green
	at the bottom right ("Active" when the upgrade shows no value). No glow, no cost, no chip.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))

local CompactOwned = {}

local C = Theme.C

function CompactOwned.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local compact = ctx.mode == "COMPACT"
	b.Visible = true
	b.AutoButtonColor = false
	-- the full card's parts (a card that was BUY a moment ago): its bar, cost footer and the lit top edge
	for _, name in { "Num", "Gradient", "Glow", "Bar", "Foot", "MotionFlash" } do Common.drop(b, name) end
	for _, name in { "Chip", "TopLine", "TickV1", "TickV2" } do Common.drop(label, name) end
	Common.surface(b, "owned", ctx.hue, 12)
	b.Size = UDim2.fromOffset(ctx.cardW, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	local lim = Common.get(b, "Limit", "UISizeConstraint") :: UISizeConstraint
	lim.MinSize = Vector2.new(0, if compact then 56 else 72)
	lim.MaxSize = Vector2.new(math.huge, math.huge)
	Common.pad(b, 10, 12, 10, 12)
	Common.list(b, false, 4, { name = "CardList" })

	Common.text(label, "cardSmall", C.ownedTitle, 0)
	label.LayoutOrder = 1
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Visible = true
	local idx = Common.str(n.n) or Common.str(n.id) or ""
	local title = Common.plain(Common.str(n.ti) or "")
	local text = Common.run(Common.esc(idx), "badge", Color3.fromHex("7fe6a0"), 0.2) .. "  " .. Common.title(title, "cardSmall", C.ownedTitle)
	if compact then
		-- phones list each owned upgrade with its effect as body text (DESIGN.md 5.7 COMPACT)
		local ds = Common.html(n.ds, "body", ctx.layer)
		if ds ~= "" then text ..= "\n" .. string.format('<font transparency="0.18">%s</font>', ds) end
	end
	Common.setText(label, text)

	local eff = Common.get(b, "Eff", "TextLabel") :: TextLabel
	eff.LayoutOrder = 2
	eff.ZIndex = 3
	eff.BackgroundTransparency = 1
	eff.Size = UDim2.new(1, 0, 0, 22)
	eff.AutomaticSize = Enum.AutomaticSize.None
	eff.TextXAlignment = Enum.TextXAlignment.Right
	eff.TextYAlignment = Enum.TextYAlignment.Center
	eff.TextWrapped = false
	eff.TextTruncate = Enum.TextTruncate.AtEnd
	Common.drop(eff, "Corner")
	Common.drop(eff, "Border") -- the BUY card's value well
	local ef = Common.str(n.ef)
	if ef then
		Common.text(eff, "numberHeavy", C.ownedValue)
		Common.setText(eff, Common.num(ef, "numberHeavy", C.ownedValue))
	else
		Common.text(eff, "label", C.ownedValue)
		Common.setText(eff, "Active")
	end
	Common.state(b, "owned")
	Common.transition(ctx, n.a, "owned", b)
	return true
end

return CompactOwned
