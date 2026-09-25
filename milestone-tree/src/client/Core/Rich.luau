--!strict
--[[
	Rich: text helpers (DESIGN.md 9).

	    Rich.caps("ready")                   "R E A D Y" with U+200A hair spaces (Roblox has no letter-spacing)
	    Rich.html(html, 13, "p", preLine)   the game's HTML as RichText, game colours remapped (DESIGN.md 11.2)
	    Rich.fit(label, { 56, 48, 40 }, w)  the first size whose text fits the width
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Html = require(ReplicatedStorage:WaitForChild("MilestoneTree"):WaitForChild("Html"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Rich = {}

Rich.HAIR = utf8.char(0x200A)
-- switch off if the hair space renders as tofu (plan risk R10): caps then use plain upper case
Rich.useHair = true

-- upper case with a hair space between letters (spaces stay spaces)
function Rich.caps(s: string): string
	local up = string.upper(s)
	if not Rich.useHair then return up end
	local out = {}
	local prevLetter = false
	for _, cp in utf8.codes(up) do
		local ch = utf8.char(cp)
		local letter = ch ~= " " and ch ~= "\n"
		if letter and prevLetter then table.insert(out, Rich.HAIR) end
		table.insert(out, ch)
		prevLetter = letter
	end
	return table.concat(out)
end

-- the game's HTML -> RichText at a base size, with the colour remap of the layer
function Rich.html(html: string?, base: number, layer: string?, preLine: boolean?): string
	return Html.rich(html, base, preLine, Theme.remapper(layer))
end

-- the game's HTML as plain text (tooltips, plates)
function Rich.plain(html: string?): string
	return Html.plain(html)
end

-- step-fit: the first size in `sizes` (largest first) at which the label's text is at most maxW wide
function Rich.fit(l: TextLabel, sizes: { number }, maxW: number)
	for i, size in sizes do
		l.TextSize = size
		if i == #sizes or l.TextBounds.X <= maxW then return end
	end
end

return Rich
