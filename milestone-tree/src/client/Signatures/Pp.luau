--!strict
--[[
	Pp: Prestige Power (DESIGN.md 6 row pp).

	    hero     "X Hz" (the game's own Hz value, as sent) over an oscilloscope strip in the free slot between the
	             resource block and the CTA; the wave scrolls (frozen with reduced motion). The source line leaves the
	             body.
	    accent   crimson-pink header stripes
	The Power Scaler buyable and the upgrades keep the template (P.skin: Hide owned).
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
local W, H, DOTS = 200, 38, 14

local function hzLine(h: string): boolean
	return string.find(h, "Hz powerful", 1, true) ~= nil
end

local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Pp")
	local line = Kit.line(store, hzLine)
	local hz = if line then string.match(Common.plain(line), "is%s+(%S+)%s+Hz") else nil
	local slot = if hz then Kit.heroSlot(a, "Scope", 230, 140) else nil
	if slot == nil then
		Common.drop(a, "Scope")
		return
	end
	local s = slot :: Frame
	local hue = Theme.textHue(ctx.layer)
	local value = Common.label(s, "Value", "numberHeavy", C.text, { wrap = false, align = Enum.TextXAlignment.Center })
	value.Position = UDim2.fromOffset(0, 4)
	Common.setText(value, Common.num((hz :: string) .. " Hz", "numberHeavy", C.text))
	-- the strip: two periods of dots on a sine, slid left forever (one write a frame)
	local strip = Common.get(s, "Strip", "Frame") :: Frame
	strip.Active = false
	strip.Position = UDim2.fromOffset(15, 40)
	strip.Size = UDim2.fromOffset(W, H + 16)
	strip.BackgroundColor3 = C.deep
	strip.BackgroundTransparency = 0.1
	strip.ClipsDescendants = true
	Common.corner(strip, 10)
	Common.stroke(strip, 1, hue, 0.5)
	local wave = strip:FindFirstChild("Wave") :: Frame?
	if wave == nil then
		local w = Instance.new("Frame")
		w.Name = "Wave"
		w.Active = false
		w.BackgroundTransparency = 1
		w.Size = UDim2.fromOffset(2 * W, H + 16)
		for i = 0, 2 * DOTS - 1 do
			local d = Instance.new("Frame")
			d.Name = "D" .. i
			d.Active = false
			d.BorderSizePixel = 0
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			local x = (i + 0.5) * W / DOTS
			d.Position = UDim2.fromOffset(x, 8 + H / 2 - math.sin(x / W * 2 * math.pi * 2) * H / 2)
			d.Size = UDim2.fromOffset(5, 5)
			d.BackgroundColor3 = hue
			d.Parent = w
		end
		w.Parent = strip
		local x = 0
		Motion.loop(w, function(dt: number)
			if Motion.reduced() then return end
			x = (x + dt * 60) % W
			w.Position = UDim2.fromOffset(-x, 0)
		end)
	end
	local cap = Common.get(s, "Cap", "TextLabel") :: TextLabel
	cap.Active = false
	Common.text(cap, "caps", C.soft)
	cap.Position = UDim2.fromOffset(0, 104)
	cap.Size = UDim2.new(1, 0, 0, 18)
	cap.TextXAlignment = Enum.TextXAlignment.Center
	Common.setText(cap, Common.caps("Prestige power"))
end

local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	Kit.stripes(Kit.accent(band, "Pp"), Theme.lift(ctx.hue, 0.2), 0.06, 22)
end

return {
	layers = { "pp" },
	skin = P.skin,
	hero = hero,
	accent = accent,
	claims = ({ { match = { cn = "display-text" }, make = Kit.noteClaim(hzLine) } } :: { any }),
}
