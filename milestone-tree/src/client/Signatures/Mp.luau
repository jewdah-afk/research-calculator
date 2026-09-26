--!strict
--[[
	Mp: Multiverse (DESIGN.md 6 row mp).

	    accent   the split rim: violet (m) -> crimson (danger) around the sheet
	    portal   challenge 21 ("Enter The Prestige Multiverse") becomes the full-width PORTAL card: the default challenge
	             card widened, with a turning swirl ring at its right (still with reduced motion); its START button is
	             the challenge's own (the same ["chal", "mp", 21] as the map's gate)
	The other challenges and the upgrades keep the template (P.skin: Hide owned).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local PanelF = Client:WaitForChild("Panel")
local Skins = PanelF:WaitForChild("Skins")
local Common = require(Skins:WaitForChild("Common"))
local Challenge = require(Skins:WaitForChild("Challenge"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C

local function rim(sheet: Frame, ctx: any)
	if Layout.mode == "COMPACT" then return end
	local a = Kit.accent(sheet, "Mp")
	local f = Common.get(a, "Split", "Frame") :: Frame
	f.Active = false
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 4
	Common.corner(f, 22)
	local s = Common.stroke(f, 3, C.white, 0)
	local g = Common.get(s, "Split", "UIGradient") :: UIGradient
	g.Rotation = 0
	g.Color = ColorSequence.new(Theme.hue("m"), C.danger)
end

local function skin(rec: any, n: any, ctx: any): boolean
	if rec.kind == "chal" then
		-- every challenge (21, "Enter The Prestige Multiverse", included) is the same template card: the full-width
		-- portal banner broke the row rhythm (three small cards, then one big one)
		Common.drop(rec.root, "Portal")
		Common.drop(rec.root, "Clear")
		return Challenge.skin(rec, n, ctx)
	end
	return P.skin(rec, n, ctx)
end

return {
	layers = { "mp" },
	skin = skin,
	accent = rim,
}
