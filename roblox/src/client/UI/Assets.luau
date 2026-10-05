--!strict
-- Paste uploaded asset ids here (Studio: Asset Manager > Images > right-click > Copy ID).
-- Icons are the Blender renders in roblox/art/icons/out; textures/backgrounds are exported
-- from the Figma file (page "v4 – Clean Dark Blocky"). Leave 0 to fall back to plain shapes.

local function id(n: number): string
	return if n > 0 then "rbxassetid://" .. n else ""
end

return {
	Icons = {
		cash = id(0),
		gem = id(0),
		storm = id(0),
		clover = id(0),
		bolt = id(0),
		fastdrop = id(0),
		star = id(0),
		tier = id(0),
		spawn = id(0),
		rebirth = id(0),
		gear = id(0),
	},
	Textures = {
		studTile = id(0), -- Figma "Tex/StudTile" exported as PNG (tile it)
		stripes = id(0), -- Figma "Tex/Stripes"
		sheen = id(0), -- Figma "FX/Sheen"
		burst = id(0), -- Figma "FX/Burst"
	},
	-- Parallax layers are configured in ParallaxBackground.client.luau
}
