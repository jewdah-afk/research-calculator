--!strict
--[[
	Opt: an Options row (DESIGN.md 6 Options, 6.1): the title (cardSmall) and the game's one-line subtitle (small, soft),
	the value as a chip at the right: ON / OFF for the two-state toggles (on), the cycler position for cyclers
	(idx / n), the shown value otherwise. One press per tap, the action as sent.
]]

local Core = script.Parent.Parent.Parent:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))

local Opt = {}

local C = Theme.C

function Opt.skin(rec: any, n: any, ctx: any): boolean
	local b = rec.root :: TextButton
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l == nil then return false end
	local label = l :: TextLabel
	local compact = ctx.mode == "COMPACT"
	b.Visible = true
	b.AutoButtonColor = false
	for _, name in { "Gradient", "Glow", "Num", "Limit" } do Common.drop(b, name) end
	Common.fill(b, C.panel3, C.panel2)
	Common.corner(b, 14)
	Common.stroke(b, 1.5, Theme.lift(ctx.hue, 0.2), 0.55)
	b.Size = UDim2.fromOffset(if compact then math.floor((ctx.contentW - 10) / 2) else 320, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	local lim = Common.get(b, "Limit", "UISizeConstraint") :: UISizeConstraint
	lim.MinSize = Vector2.new(0, 64)
	lim.MaxSize = Vector2.new(math.huge, math.huge)
	Common.pad(b, 12, 16, 12, 16)
	Common.text(label, "small", C.soft)
	label.Visible = true
	label.ZIndex = 3
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	-- the subtitle: the game's second line (after its first <br>), plain
	local h = Common.str(n.h) or ""
	local sub = string.match(h, "<br%s*/?>(.*)$")
	local subText = Common.plain(sub or "")
	subText = string.gsub(string.gsub(subText, "^%s+", ""), "%s+$", "")
	local title = Common.str(n.ti) or Common.plain(h)
	local chipText: string? = nil
	if n.on ~= nil then
		chipText = if n.on == true then "ON" else "OFF"
	elseif type(n.idx) == "number" and type(n.n) == "number" then
		chipText = tostring(n.val or "") .. "  " .. tostring(n.idx + 1) .. " / " .. tostring(n.n)
	elseif Common.str(n.val) then
		chipText = Common.str(n.val)
	end
	-- a subtitle that only repeats the value ("[ ALL ]") is dropped
	if chipText and string.find(subText, "^%[.*%]$") then subText = "" end
	local parts = { Common.title(title, "cardSmall", C.text) }
	if subText ~= "" then table.insert(parts, Common.esc(subText)) end
	Common.setText(label, table.concat(parts, "\n"))
	if chipText then
		local on = n.on == true
		local chip = Common.chip(label, "Chip", string.upper(chipText), {
			color = if n.on == nil then C.text elseif on then C.ownedValue else C.soft,
			bg = if on then Theme.mix(C.deep, C.bought, 0.3) else C.deep, bgT = 0, h = 26 })
		-- the text keeps clear of the chip (children sit in the padded box, so the chip steps back out of it)
		local clear = 110
		local pad = Common.get(label, "Clear", "UIPadding") :: UIPadding
		pad.PaddingRight = UDim.new(0, clear)
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, clear, 0, 0)
		chip.ZIndex = 4
	else
		Common.drop(label, "Chip")
		Common.drop(label, "Clear")
	end
	Common.state(b, "can")
	return true
end

return Opt
