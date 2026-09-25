--!strict
--[[
	Energy: Prestige Energy and Super Energy (DESIGN.md 6 rows pe and se). Small panels: the sheet hugs its content.

	    hero     the RATE chip under the CTA: "×16.00 per OoM of PP, ^1.00" (the game's two numbers, as sent, with the
	             short unit); the source line leaves the body
	    accent   a lightning bolt watermark in the header (three hue strokes)
	The upgrades keep the tier board (P.skin: Hide owned).
]]

local Client = script.Parent.Parent
local Core = Client:WaitForChild("Core")
local Theme = require(Core:WaitForChild("Theme"))
local PanelF = Client:WaitForChild("Panel")
local Common = require(PanelF:WaitForChild("Skins"):WaitForChild("Common"))
local Signatures = require(script.Parent:WaitForChild("Signatures"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local P = (require(script.Parent:WaitForChild("P")) :: any).P

local C = Theme.C

local function rateLine(h: string): boolean
	return string.find(h, "per OoM", 1, true) ~= nil
end

local function hero(f: Frame, store: any, ctx: any)
	local a = Kit.accent(f, "Energy")
	local line = Kit.line(store, rateLine)
	local plain = if line then Common.plain(line) else ""
	local per, res, pow = string.match(plain, "([%d%.,e%+]+) per OoM of (.-), then raised to a power of ([%d%.,e%+]+)")
	if per == nil or res == nil or pow == nil then
		Common.drop(a, "Rate")
		return
	end
	local unit = Signatures.unit(res)
	Kit.heroChip(a, f, "Rate", Common.caps("Rate", C.soft) .. "   " .. Common.num("×" .. per, "number", C.text)
		.. Common.run(Common.esc(" per OoM of " .. unit .. ", "), "small", C.soft) .. Common.num("^" .. pow, "number", C.text))
end

local function accent(sheet: Frame, ctx: any)
	local band = Kit.band(sheet)
	if band == nil then return end
	local a = Kit.accent(band, "Energy")
	local bolt = Common.get(a, "Bolt", "Frame") :: Frame
	bolt.Active = false
	bolt.BackgroundTransparency = 1
	bolt.AnchorPoint = Vector2.new(1, 0.5)
	bolt.Position = UDim2.new(1, -150, 0.5, 0)
	bolt.Size = UDim2.fromOffset(60, 80)
	local strokes = { { 34, 4, 24 }, { 30, 36, -62 }, { 26, 50, 24 } }
	for i, s in strokes do
		local b = Common.get(bolt, "S" .. i, "Frame") :: Frame
		b.Active = false
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.fromOffset(s[1], s[2])
		b.Size = UDim2.fromOffset(9, 34)
		b.Rotation = s[3]
		b.BackgroundColor3 = Theme.lift(ctx.hue, 0.2)
		b.BackgroundTransparency = 0.82
		Common.corner(b, 4)
	end
end

local function sig(layer: string): any
	return {
		layers = { layer },
		hug = true,
		skin = P.skin,
		hero = hero,
		accent = accent,
		claims = ({ { match = { cn = "display-text" }, make = Kit.noteClaim(rateLine) } } :: { any }),
	}
end

return { sig("pe"), sig("se") }
