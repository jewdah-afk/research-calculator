--!strict
-- shared/DisplayNames. docs/ARCHITECTURE.md rule 7: "Data.*.data[id].name is a
-- reference label. Anything shown to a player reads src/shared/DisplayNames
-- .luau, authored by us." This test is the coverage gate on that claim: every
-- mechanical id the simulation can name must have one of OUR names, and none
-- of our names may reproduce a reference label.
local T = require("./_harness")
local DisplayNames = require("../src/shared/DisplayNames")
local Characters = require("../src/shared/Data/Characters")
local EnemiesWaves = require("../src/shared/Data/EnemiesWaves")
local PassivesEvolutions = require("../src/shared/Data/PassivesEvolutions")
local Weapons = require("../src/shared/Data/Weapons")

-- Ids as the Data modules key them, gathered once.
local weaponIds: { string } = {}
for id in pairs(Weapons.data) do
	table.insert(weaponIds, id)
end
local characterIds: { string } = {}
for id in pairs(Characters.data) do
	table.insert(characterIds, id)
end
local passiveIds: { string } = {}
for _, p in ipairs(PassivesEvolutions.data.passives) do
	table.insert(passiveIds, (p :: any).id)
end
local enemyIds: { string } = {}
for _, e in ipairs(EnemiesWaves.data.enemies) do
	table.insert(enemyIds, (e :: any).id)
end

local function assertCovered(category: DisplayNames.Category, ids: { string }, expectedCount: number)
	T.eq(#ids, expectedCount, category .. " id count")
	for _, id in ids do
		local name = DisplayNames.find(category, id)
		T.truthy(name ~= nil, "no " .. category .. " display name for id " .. id)
		T.truthy(type(name) == "string" and #(name :: string) > 0, "empty name for " .. id)
	end
end

-- Counts are the research scope (SUMMARY.md: 11 base weapons, 16 passives,
-- 21 Mad Forest enemies, 6 base starters), so a data change that adds an id
-- fails here rather than silently rendering a raw key at the player.
T.test("DN-01 ARCHITECTURE.md rule 7: every weapon id has one of our names", function()
	assertCovered("weapon", weaponIds, 11)
end)

T.test("DN-02 ARCHITECTURE.md rule 7: every passive id has one of our names", function()
	assertCovered("passive", passiveIds, 16)
end)

T.test("DN-03 ARCHITECTURE.md rule 7: every enemy id has one of our names", function()
	assertCovered("enemy", enemyIds, 21)
end)

T.test("DN-04 ARCHITECTURE.md rule 7: every character id has one of our names", function()
	assertCovered("character", characterIds, 6)
end)

T.test("DN-05 no DisplayNames entry exists for an id the Data modules do not have", function()
	local known: { [string]: { [string]: boolean } } = { weapon = {}, passive = {}, enemy = {}, character = {} }
	for _, id in weaponIds do
		known.weapon[id] = true
	end
	for _, id in passiveIds do
		known.passive[id] = true
	end
	for _, id in enemyIds do
		known.enemy[id] = true
	end
	for _, id in characterIds do
		known.character[id] = true
	end

	local tables: { [string]: { [string]: string } } = {
		weapon = DisplayNames.weapons,
		passive = DisplayNames.passives,
		enemy = DisplayNames.enemies,
		character = DisplayNames.characters,
	}
	for category, entries in pairs(tables) do
		for id in pairs(entries) do
			T.truthy(known[category][id], category .. " name for unknown id " .. id)
		end
	end
end)

T.test("DN-06 no display name reproduces a reference label from Data.*.name", function()
	-- The reference labels, lowercased, from every Data module that carries one.
	local reference: { [string]: boolean } = {}
	local function note(name: any)
		if type(name) == "string" then
			reference[string.lower(name)] = true
		end
	end
	for _, w in pairs(Weapons.data) do
		note((w :: any).name)
	end
	for _, c in pairs(Characters.data) do
		note((c :: any).name)
	end
	for _, p in ipairs(PassivesEvolutions.data.passives) do
		note((p :: any).name)
	end
	for _, e in ipairs(EnemiesWaves.data.enemies) do
		note((e :: any).name)
	end
	T.truthy(next(reference) ~= nil, "collected at least one reference label")

	for _, entries in pairs({
		DisplayNames.weapons,
		DisplayNames.passives,
		DisplayNames.enemies,
		DisplayNames.characters,
	}) do
		for id, name in pairs(entries) do
			T.truthy(not reference[string.lower(name)], "display name for " .. id .. " reuses a reference label")
		end
	end
end)

T.test("DN-07 of() raises on an unknown id rather than rendering a raw key", function()
	T.throws(function()
		DisplayNames.of("weapon", "no_such_weapon")
	end, "unknown weapon id")
	T.throws(function()
		DisplayNames.of("enemy", "no_such_enemy")
	end, "unknown enemy id")
end)

T.test("DN-08 the typed accessors agree with of()", function()
	T.eq(DisplayNames.weapon("whip"), DisplayNames.of("weapon", "whip"), "weapon()")
	T.eq(DisplayNames.passive("spinach"), DisplayNames.of("passive", "spinach"), "passive()")
	T.eq(DisplayNames.enemy("zombie"), DisplayNames.of("enemy", "zombie"), "enemy()")
	T.eq(DisplayNames.character("antonio"), DisplayNames.of("character", "antonio"), "character()")
end)

return T.finish()
