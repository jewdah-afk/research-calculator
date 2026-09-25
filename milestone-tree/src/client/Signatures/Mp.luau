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
local Motion = require(Core:WaitForChild("Motion"))
local Recipes = require(Core:WaitForChild("Recipes"))
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
	if rec.kind == "chal" and tostring(n.id) == "21" then
		local ok = Challenge.skin(rec, n, ctx)
		local root = rec.root :: Frame
		local compact = ctx.mode == "COMPACT"
		root.Size = UDim2.fromOffset(Kit.live(ctx).contentW, 0)
		if compact then
			Common.drop(root, "Portal")
			Common.drop(root, "Clear")
			return ok
		end
		local pad = Common.get(root, "Clear", "UIPadding") :: UIPadding
		pad.PaddingRight = UDim.new(0, 170)
		local holder = Common.get(root, "Portal", "Frame") :: Frame
		holder.Active = false
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, 150, 0, 80)
		holder.Size = UDim2.fromOffset(120, 120)
		holder.ZIndex = 4
		if holder:FindFirstChild("Ring") == nil then
			local ring = Recipes.ring(holder, { size = 112, thick = 6, color = Theme.lift(ctx.hue, 0.25), track = 0.75 })
			ring:set(0.72)
			Motion.loop(holder, function(dt: number)
				if not Motion.reduced() then holder.Rotation = (holder.Rotation + dt * 40) % 360 end
			end)
		end
		local core = Common.blob(holder, "Core", Theme.hue("m"), 0.55)
		if core then
			core.AnchorPoint = Vector2.new(0.5, 0.5)
			core.Position = UDim2.fromScale(0.5, 0.5)
			core.Size = UDim2.fromOffset(96, 96)
		end
		return ok
	end
	if rec.kind == "chal" then
		Common.drop(rec.root, "Portal")
		Common.drop(rec.root, "Clear")
		return false
	end
	return P.skin(rec, n, ctx)
end

return {
	layers = { "mp" },
	skin = skin,
	accent = rim,
}
