--!strict
--[[
	Sim/DataAccess.luau -- the one place that knows about the Data sentinel.

	src/shared/Data marks a field that is absent from the shipped source as
	the sentinel `Module.UNKNOWN` (docs/DATA_CONVENTIONS.md): never 0, never
	false, never an invented number. Every read of a field that can carry it
	goes through DataAccess.num, which substitutes the engine default the
	caller names from Tuning.defaults and counts which default was used.
	No other module in Sim/ or server/ tests the sentinel itself, and nothing
	ever coerces it to zero with a boolean fallback.

	Each generated Data module owns its own sentinel table, so identity is
	checked against all of them.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.
]]

local Tuning = require("../Tuning")
local Characters = require("../Data/Characters")
local CoreLoop = require("../Data/CoreLoop")
local EnemiesWaves = require("../Data/EnemiesWaves")
local PassivesEvolutions = require("../Data/PassivesEvolutions")
local PickupsMeta = require("../Data/PickupsMeta")
local Weapons = require("../Data/Weapons")

local SENTINELS: { [any]: boolean } = {
	[Characters.UNKNOWN] = true,
	[CoreLoop.UNKNOWN] = true,
	[EnemiesWaves.UNKNOWN] = true,
	[PassivesEvolutions.UNKNOWN] = true,
	[PickupsMeta.UNKNOWN] = true,
	[Weapons.UNKNOWN] = true,
}

-- Tuning.defaults is a sealed table literal; index it by name through a map view.
local DEFAULTS = (Tuning.defaults :: any) :: { [string]: number }

-- defaultKey -> how many times that default was substituted this session.
local substitutions: { [string]: number } = {}

local DataAccess = {}

-- True only for the Data sentinel (any module's). 0, nil, false and every
-- real value are not unknown.
function DataAccess.isUnknown(value: any): boolean
	if value == nil then
		return false
	end
	return SENTINELS[value] == true
end

-- Reads a numeric Data field. A real number (including 0) passes through
-- untouched; the sentinel becomes Tuning.defaults[defaultKey]. The key is
-- validated on every call so a typo fails loudly even while the field
-- happens to be present. Anything else (nil, a string, a table) is a
-- programming error, not data, and errors.
function DataAccess.num(value: any, defaultKey: string): number
	local default = DEFAULTS[defaultKey]
	if type(default) ~= "number" then
		error(string.format("DataAccess.num: no Tuning.defaults entry named %q", tostring(defaultKey)))
	end
	if DataAccess.isUnknown(value) then
		local count = substitutions[defaultKey]
		if count == nil then
			count = 0
		end
		substitutions[defaultKey] = count + 1
		return default
	end
	if type(value) ~= "number" then
		error(string.format("DataAccess.num: expected a number or the Data sentinel, got %s", typeof(value)))
	end
	return value
end

-- Which defaults have been substituted so far, keyed by defaultKey. Lets a
-- test or a Studio print prove that no unknown field silently became 0.
function DataAccess.substitutions(): { [string]: number }
	return substitutions
end

return DataAccess
