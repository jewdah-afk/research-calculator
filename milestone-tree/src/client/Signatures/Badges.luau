--!strict
--[[
	Badges: Prestige Boost and Hyper Boost (DESIGN.md 6 rows pb and hb).

	    hero     the power badge: a hue diamond with "^x" (the exponent the main display's effect line ends with, as
	             sent) in the free slot between the resource block and the CTA; it pulses once when the value changes
	    accent   pb mint / hb pale mint: a soft glow in the header corner
	The upgrades keep the tier board (P.skin: Hide owned).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Motion = require(Core:WaitForChild("Motion"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C

local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Badge")
	local md = Kit.find(store, "tab", function(n: any): boolean
		return n.cn == "main-display"
	end, 3)
	local eff = if md then Common.plain(Common.str(store:get(md).eff) or "") else ""
	local power = string.match(eff, "powered by%s+([%d%.,e%+]+)")
	local slot = if power then Kit.heroSlot(a, "Power", 170, 140) else nil
	if slot == nil then
		Common.drop(a, "Power")
		return
	end
	local s = slot :: Frame
	local hue = ctx.hue :: Color3
	local gem = Common.get(s, "Gem", "Frame") :: Frame
	gem.Active = false
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.new(0.5, 0, 0, 46)
	gem.Size = UDim2.fromOffset(62, 62)
	gem.Rotation = 45
	gem.BackgroundColor3 = Theme.mix(C.deep, hue, 0.55)
	gem.BackgroundTransparency = 0
	Common.corner(gem, 14)
	Common.stroke(gem, 3, Theme.lift(hue, 0.45), 0)
	Common.glow(gem, hue, 0.55, 16)
	local value = Common.get(s, "Value", "TextLabel") :: TextLabel
	value.Active = false
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = UDim2.new(0.5, 0, 0, 46)
	value.Size = UDim2.new(1, 0, 0, 44)
	value.ZIndex = 3
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.TextWrapped = false
	local text = "^" .. (power :: string)
	if value:GetAttribute("Sig") ~= text then
		local had = value:GetAttribute("Sig") ~= nil
		value:SetAttribute("Sig", text)
		Common.text(value, "index", C.text)
		value.Text = text
		local st = Common.stroke(value, 3, C.black, 0, "Stroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		if had then Motion.bump(gem, 0.12) end
	end
	local cap = Common.get(s, "Cap", "TextLabel") :: TextLabel
	cap.Active = false
	Common.text(cap, "caps", C.soft)
	cap.AnchorPoint = Vector2.new(0.5, 0)
	cap.Position = UDim2.new(0.5, 0, 0, 94)
	cap.Size = UDim2.new(1, 0, 0, 18)
	cap.TextXAlignment = Enum.TextXAlignment.Center
	Common.setText(cap, Common.caps("Power"))
end

local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Badges")
	a.ClipsDescendants = true
	local blob = Common.blob(a, "Glow", Theme.lift(ctx.hue, 0.3), 0.3)
	if blob then
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.new(1, -160, 0, 0)
		blob.Size = UDim2.fromOffset(420, 200)
	end
end

return {
	{ layers = { "pb" }, skin = P.skin, hero = hero, accent = accent },
	{ layers = { "hb" }, skin = P.skin, hero = hero, accent = accent },
}
