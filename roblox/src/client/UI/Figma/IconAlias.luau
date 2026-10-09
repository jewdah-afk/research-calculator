--!nonstrict
-- IconAlias: Figma icon name -> uploaded Roblox image id (shared/Icons.luau). Every icon is uploaded (992 names,
-- 2026-10-09, claude/peckwood-isle bc182f1: all of birb-icons/final and birb-icons/final/fish). This is only a safety
-- net: Figma layer names that are not plain icon names map to their icon, an unknown fish species shows the generic
-- fish, anything else unknown shows nothing (never a vector, never a wrong stand-in). Only names that resolve to
-- nothing land in IconAlias.missing (the harness requires it to stay empty).
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS:WaitForChild("Peckwood"):WaitForChild("Icons"))
local Defs = require(RS:WaitForChild("Peckwood"):WaitForChild("Defs"))

local IconAlias = {}

-- Figma layer names that are not icon names
local EXACT = {
	["seagull (third, locked)"] = "seagull",
}
IconAlias.missing = {}

local cache = {}
function IconAlias.id(name: string?): string
	if not name or name == "" then return "" end
	local c = cache[name]
	if c then return c end
	local id = Icons[name]
	if not id then
		local alt = EXACT[name] or (if Defs.FISH_BY_ID and Defs.FISH_BY_ID[name] then "fish" else nil)
		id = if alt then (Icons[alt] or "") else ""
		if id == "" then IconAlias.missing[name] = true end
	end
	cache[name] = id
	return id
end

return IconAlias
