--!strict
--[[
	P: the tier board layers (DESIGN.md 6 rows p and hp; 5.6 "upgrades" and 5.7 "Tier board").

	The default skins already draw the tier board (the rail with Arabic tier badges, compact owned cards for a fully
	owned tier, the COMPACT owned fold). This signature adds:
	    Hide owned   a mini toggle at the right of the UPGRADES title row (WIDE / MEDIUM; session memory per layer):
	                 owned cards and fully owned tiers leave the board, the chips keep counting them
	    accent       p: sky-blue header stripes; hp: a frost glow in the header corner
	P.skin is shared by the other signatures whose tabs hold an upgrades board (Sp, Badges, Pp, Energy, Ap, T, ...).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local PanelF = Client:WaitForChild("Panel")
local Skins = PanelF:WaitForChild("Skins")
local Common = require(Skins:WaitForChild("Common"))
local Generic = require(Skins:WaitForChild("Generic"))
local Upgrade = require(Skins:WaitForChild("Upgrade"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local C = Theme.C

local P = {}

-- session memory: the layers whose owned upgrades are hidden
local hideOwned: { [string]: boolean } = {}
P.hideOwned = hideOwned

local function parentNode(ctx: any, id: string): any?
	local pid = Common.parentId(id)
	if pid == nil then return nil end
	return ctx.store:get(pid)
end

-- the Hide owned switch in the section title row (the rule flexes to leave it room at the right)
local function toggle(rec: any, ctx: any)
	local header = rec.root:FindFirstChild("SectionTitle")
	if header == nil or not header:IsA("Frame") then return end
	local on = hideOwned[ctx.layer] == true
	local rule = header:FindFirstChild("Rule")
	local flex = false
	if rule then
		flex = pcall(function()
			local f = Common.get(rule, "Flex", "UIFlexItem") :: any
			f.FlexMode = Enum.UIFlexMode.Fill
		end)
	end
	local b = Common.get(header, "HideOwned", "TextButton") :: TextButton
	b.LayoutOrder = if flex then 20 else 5
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(150, 28)
	b.AutomaticSize = Enum.AutomaticSize.None
	Common.text(b, "label", if on then C.text else C.soft)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextYAlignment = Enum.TextYAlignment.Center
	b.TextWrapped = false
	Common.setText(b, Common.esc("Hide owned"))
	local track = Common.get(b, "Track", "Frame") :: Frame
	track.Active = false
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -4, 0.5, 0)
	track.Size = UDim2.fromOffset(36, 20)
	track.BackgroundColor3 = if on then Theme.mix(C.deep, C.bought, 0.55) else C.panel3
	track.BackgroundTransparency = 0
	Common.corner(track, 0.5)
	local knob = Common.get(track, "Knob", "Frame") :: Frame
	knob.Active = false
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(if on then 1 else 0, if on then -10 else 10, 0.5, 0)
	knob.Size = UDim2.fromOffset(14, 14)
	knob.BackgroundColor3 = if on then C.ownedValue else C.soft
	knob.BackgroundTransparency = 0
	Common.corner(knob, 0.5)
	b:SetAttribute("State", if on then "owned" else "can")
	local layer = ctx.layer
	local render = ctx.render
	Kit.onPress(b, function()
		hideOwned[layer] = not hideOwned[layer]
		if render then render:refresh() end
	end)
end

-- the shared skin: returns true when it drew the node
function P.skin(rec: any, n: any, ctx: any): boolean
	if ctx.mode == "COMPACT" then return false end -- phones fold the owned upgrades into one row (Skins/Upgrade)
	if n.cn == "upgrades" and (n.t == "col" or n.t == "row") then
		Generic.skin(rec, n, ctx)
		toggle(rec, ctx)
		return true
	end
	if not hideOwned[ctx.layer] then return false end
	if rec.kind == "btn:upg" and n.cls == "bought" then
		local b = rec.root :: GuiObject
		b.Visible = false
		Common.state(b, "owned")
		return true
	end
	if n.t == "row" then
		local p = parentNode(ctx, rec.id)
		if type(p) == "table" and p.cn == "upgrades" and Upgrade.tierOwned(ctx.store, rec.id, ctx.cache) then
			(rec.root :: GuiObject).Visible = false
			return true
		end
	end
	return false
end

-- p: sky-blue stripes across the header band
function P.stripes(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "P")
	Kit.stripes(a, Theme.lift(ctx.hue, 0.3), 0.06, 22)
end

-- hp: a frost glow in the header's right corner
local function frost(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Hp")
	a.ClipsDescendants = true
	local blob = Common.blob(a, "Frost", Theme.lift(ctx.hue, 0.5), 0.35)
	if blob then
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.new(1, -120, 0, 0)
		blob.Size = UDim2.fromOffset(420, 220)
	end
end

return {
	{ layers = { "p" }, skin = P.skin, accent = P.stripes },
	{ layers = { "hp" }, skin = P.skin, accent = frost },
	P = P,
}
