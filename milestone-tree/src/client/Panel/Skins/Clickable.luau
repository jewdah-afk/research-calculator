--!strict
--[[
	Clickable: the game's clickables (sp's ignite / reignite / show / pager, t's relics, cp's mode switch).

	    a short label ("<<", "<", ">")   a 52 x 44 pager key
	    anything else                    a card (237 du, auto height) with the game's text verbatim (colours remapped);
	                                     hue when it can be pressed, mauve when not
	Hold clickables keep Render's hold-to-repeat. Signatures give the special ones their own widgets.
]]

local Common = require(script.Parent:WaitForChild("Common"))

local Clickable = {}

function Clickable.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local state = if n.cls == "can" then "can" elseif n.cls == "bought" then "owned" else "notyet"
	local plain = Common.plain(n.h)
	plain = string.gsub(string.gsub(plain, "^%s+", ""), "%s+$", "")
	b.Visible = true
	b.AutoButtonColor = false
	for _, name in { "Gradient", "Glow", "Num", "Limit" } do Common.drop(b, name) end
	local p = Common.surface(b, state, ctx.hue, 12)
	label.Visible = true
	label.ZIndex = 3
	if utf8.len(plain) ~= nil and (utf8.len(plain) :: number) <= 3 then
		-- a pager key
		b.Size = UDim2.fromOffset(52, 44)
		b.AutomaticSize = Enum.AutomaticSize.None
		Common.drop(b, "Pad")
		Common.text(label, "label", p.title)
		label.Size = UDim2.fromScale(1, 1)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextWrapped = false
		Common.setText(label, Common.esc(plain))
	else
		b.Size = UDim2.fromOffset(if ctx.mode == "COMPACT" then math.floor((ctx.contentW - 10) / 2) else 237, 0)
		b.AutomaticSize = Enum.AutomaticSize.Y
		Common.pad(b, 12, 14, 12, 14)
		Common.text(label, "small", p.text)
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		Common.setText(label, Common.html(n.h, "small", ctx.layer))
	end
	Common.glow(b, if state == "can" then ctx.hue else nil, 0.4, 12)
	Common.state(b, state)
	return true
end

return Clickable
