--!nonstrict
-- IconAlias: Figma icon name -> uploaded Roblox image id (shared/Icons.luau). All 426 icon names the Figma windows use
-- are uploaded (2026-10-09, claude/peckwood-isle c6c290f); the few Figma layer names that are not plain icon names map
-- to their icon here. 43 live Fishdex species (Defs.FISH) still have no painted icon: they show the generic fish
-- until theirs is uploaded. Anything else unknown shows nothing (never a vector, never a wrong stand-in); every miss is
-- listed in IconAlias.missing so the harness reports it.
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
		IconAlias.missing[name] = true
	end
	cache[name] = id
	return id
end

return IconAlias
