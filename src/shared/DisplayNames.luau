--!strict
--[[
	DisplayNames.luau — OUR names. The only source of player-facing strings.

	`Data.*.name` is a REFERENCE LABEL for the shipped record a mechanic was
	ported from. It is research provenance, not content, and nothing a player
	can see may read it (docs/ARCHITECTURE.md rule 7). Every id the simulation
	uses is looked up here instead, and everything below is original writing:
	no name, phrase or theme is carried over from the reference.

	The ids are the mechanical keys, so this table is exhaustive by
	construction — one entry for every id in Data.Weapons, Data
	.PassivesEvolutions, Data.EnemiesWaves and Data.Characters. A missing id is
	a bug, and `DisplayNames.of` says so loudly rather than rendering a raw id
	into the HUD.

	Pure Luau: no Roblox APIs, so the coverage test runs headless.
]]

--- Weapon ids -> our names. 11 base weapons.
local weapons: { [string]: string } = {
	whip = "Tide Cutter",
	magic_wand = "Seeker Spark",
	knife = "Splinter",
	axe = "Skyfell",
	runetracer = "Caromstone",
	fire_wand = "Emberjet",
	king_bible = "Orbit Codex",
	garlic = "Warding Bloom",
	santa_water = "Rainfall Flask",
	lightning_ring = "Stormcall",
	cross = "Returning Sigil",
}

--- Passive ids -> our names. 16 passives.
local passives: { [string]: string } = {
	spinach = "Ironroot",
	armor = "Scale Plating",
	hollow_heart = "Deep Lung",
	pummarola = "Mender's Knot",
	empty_tome = "Blank Folio",
	candelabrador = "Widening Lens",
	bracer = "Slipstream Band",
	spellbinder = "Long Echo",
	duplicator = "Split Token",
	wings = "Featherstep",
	attractorb = "Lodestone",
	clover = "Luckspur",
	crown = "Scholar's Circlet",
	stone_mask = "Coinmask",
	skull_omaniac = "Hex Sigil",
	tiragisu = "Second Wind",
}

--- Enemy ids -> our names. 21 statlines, including the five bosses.
local enemies: { [string]: string } = {
	bat1 = "Flittermite",
	bat2 = "Flittermite Swarmling",
	bat3 = "Flittermite Drifter",
	bat4 = "Emberwing",
	bat5 = "Silverwing",
	zombie = "Shambler",
	skeleton = "Rattlebone",
	ghost = "Pale Wisp",
	mudman1 = "Sludgeling",
	mudman2 = "Sludge Brute",
	werewolf = "Moonhound",
	xlbat = "Dread Wing",
	xlmantis = "Scytheclaw",
	xlmummy = "Bound Colossus",
	flower = "Thornwall",
	xlflower = "Bloomtyrant",
	boss_xlmantis = "Scytheclaw the Reaping",
	boss_werewolf = "Moonhound Alpha",
	boss_xlmummy = "Bound Colossus Unsealed",
	boss_xlflower = "Bloomtyrant Ascendant",
	boss_xldeath = "The Long Quiet",
}

--- Character ids -> our names. 6 starters.
local characters: { [string]: string } = {
	antonio = "Bruno Ferra",
	imelda = "Mira Ferra",
	pasqualina = "Nella Ferra",
	gennaro = "Tullio Ferra",
	arca = "Rea Vance",
	porta = "Wren Vance",
}

export type Category = "weapon" | "passive" | "enemy" | "character"

local DisplayNames = {
	weapons = weapons,
	passives = passives,
	enemies = enemies,
	characters = characters,
}

local byCategory: { [string]: { [string]: string } } = {
	weapon = weapons,
	passive = passives,
	enemy = enemies,
	character = characters,
}

--- Our name for `id` in `category`. Errors on an unknown id: a raw mechanical
--- key reaching a player is a bug, and failing here points at the missing
--- entry instead of shipping "boss_xldeath" into the HUD.
function DisplayNames.of(category: Category, id: string): string
	local table_ = byCategory[category]
	if table_ == nil then
		error("DisplayNames: unknown category " .. tostring(category))
	end
	local name = table_[id]
	if name == nil then
		error("DisplayNames: no " .. category .. " name for id " .. tostring(id))
	end
	return name
end

--- Non-raising lookup for UI that would rather render nothing than crash.
function DisplayNames.find(category: Category, id: string): string?
	local table_ = byCategory[category]
	if table_ == nil then
		return nil
	end
	return table_[id]
end

function DisplayNames.weapon(id: string): string
	return DisplayNames.of("weapon", id)
end

function DisplayNames.passive(id: string): string
	return DisplayNames.of("passive", id)
end

function DisplayNames.enemy(id: string): string
	return DisplayNames.of("enemy", id)
end

function DisplayNames.character(id: string): string
	return DisplayNames.of("character", id)
end

return DisplayNames
