--!strict
--[[
	T: Transcend (DESIGN.md 6 row t).

	    accent   the crown rays behind the emblem: a gold glow and 8 thin rays turning once in 30 s (still with reduced
	             motion)
	The challenges, the Upgrades tier board (P.skin: Hide owned) and the special points keep the template.
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local Layout = require(Core:WaitForChild("Layout"))
local Motion = require(Core:WaitForChild("Motion"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local function rays(sheet: Frame, ctx: any)
	local emblem = sheet:FindFirstChild("Emblem") :: GuiObject?
	if emblem == nil or Layout.mode == "COMPACT" then return end
	local a = Kit.accent(sheet, "T")
	local cx = emblem.Position.X.Offset + emblem.Size.X.Offset / 2
	local cy = emblem.Position.Y.Offset + emblem.Size.Y.Offset / 2
	local glow = Common.blob(a, "Glow", ctx.hue, 0.35)
	if glow then
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromOffset(cx, cy)
		glow.Size = UDim2.fromOffset(200, 200)
	end
	local holder = Common.get(a, "Rays", "Frame") :: Frame
	holder.Active = false
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(cx, cy)
	holder.Size = UDim2.fromOffset(180, 180)
	for i = 1, 4 do
		local r = Common.get(holder, "Ray" .. i, "Frame") :: Frame
		r.Active = false
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromOffset(170, 6)
		r.Rotation = (i - 1) * 45
		r.BackgroundColor3 = Theme.lift(ctx.hue, 0.3)
		r.BackgroundTransparency = 0
		local g = Common.get(r, "Fade", "UIGradient") :: UIGradient
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.7, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	Motion.loop(holder, function(dt: number)
		if not Motion.reduced() then holder.Rotation = (holder.Rotation + dt * 12) % 360 end
	end)
end

return {
	layers = { "t" },
	skin = P.skin,
	accent = rays,
}
