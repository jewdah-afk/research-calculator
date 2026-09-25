--!strict
--[[
	Ap: Atomic Prestige (DESIGN.md 6 row ap).

	    accent   the atom orbit: two elliptical rings around the emblem, turning (still with reduced motion)
	    active   the challenge being run is pinned with a gold ribbon ("ACTIVE") over its card
	The challenges, the Challenge Slayer buyable and the upgrades keep the template (P.skin: Hide owned).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local PanelF = Client:WaitForChild("Panel")
local Skins = PanelF:WaitForChild("Skins")
local Common = require(Skins:WaitForChild("Common"))
local Challenge = require(Skins:WaitForChild("Challenge"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C

local function orbit(sheet: Frame, ctx: any)
	local emblem = sheet:FindFirstChild("Emblem") :: GuiObject?
	if emblem == nil or Layout.mode == "COMPACT" then return end
	local a = Kit.accent(sheet, "Ap")
	local cx = emblem.Position.X.Offset + emblem.Size.X.Offset / 2
	local cy = emblem.Position.Y.Offset + emblem.Size.Y.Offset / 2
	local holder = Common.get(a, "Orbit", "Frame") :: Frame
	holder.Active = false
	holder.BackgroundTransparency = 1
	holder.ZIndex = 7
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(cx, cy)
	holder.Size = UDim2.fromOffset(150, 150)
	for i, rot in { 30, -30 } do
		local r = Common.get(holder, "Ring" .. i, "Frame") :: Frame
		r.Active = false
		r.BackgroundTransparency = 1
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromOffset(146, 52)
		r.Rotation = rot
		Common.corner(r, 0.5)
		Common.stroke(r, 2, Theme.lift(ctx.hue, 0.35), 0.25)
	end
	Motion.loop(holder, function(dt: number)
		if not Motion.reduced() then holder.Rotation = (holder.Rotation + dt * 18) % 360 end
	end)
end

-- the running challenge gets a gold ribbon over the default card
local function skin(rec: any, n: any, ctx: any): boolean
	if rec.kind == "chal" then
		local ok = Challenge.skin(rec, n, ctx)
		local active = n.st8 == "active" or n.st8 == "completable" or n.active == true
		if active then
			local rib = Common.chip(rec.root, "Ribbon", "ACTIVE", { color = C.ink, bg = C.gold, bgT = 0, h = 24 })
			rib.AnchorPoint = Vector2.new(1, 0)
			rib.Position = UDim2.new(1, 6, 0, -12)
			rib.ZIndex = 6
		else
			Common.drop(rec.root, "Ribbon")
		end
		return ok
	end
	return P.skin(rec, n, ctx)
end

return {
	layers = { "ap" },
	skin = skin,
	accent = orbit,
}
