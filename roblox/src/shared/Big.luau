--!nonstrict
-- Thin wrapper around EternityNum so the economy never talks to the library directly.
-- Put the EternityNum ModuleScript next to this module (ReplicatedStorage.Shared.EternityNum),
-- or at ReplicatedStorage.Modules.EternityNum.
-- EternityNum functions accept EN tables, plain numbers and numeric strings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ENModule = script.Parent:FindFirstChild("EternityNum")
	or (ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("EternityNum"))
	or script.Parent:WaitForChild("EternityNum", 10)
assert(ENModule, "[OrbGame] EternityNum module not found: put it in ReplicatedStorage.Shared")
local EN = require(ENModule)

local Big = {}

function Big.new(x)
	if type(x) == "table" then
		return x
	end
	if EN.convert then
		return EN.convert(x)
	end
	return EN.add(x, 0)
end

Big.zero = function()
	return Big.new(0)
end

function Big.add(a, b) return EN.add(a, b) end
function Big.sub(a, b) return EN.sub(a, b) end
function Big.mul(a, b) return EN.mul(a, b) end
function Big.div(a, b) return EN.div(a, b) end
function Big.pow(a, b) return EN.pow(a, b) end

function Big.gt(a, b) return EN.me(a, b) end
function Big.gte(a, b) return EN.meeq(a, b) end
function Big.lt(a, b) return EN.le(a, b) end
function Big.lte(a, b) return EN.leeq(a, b) end

function Big.max(a, b)
	return if EN.meeq(a, b) then a else b
end

-- log10 as a plain number (fine for anything below 10^(1e308))
function Big.log10(a): number
	if EN.log10 then
		local r = EN.log10(a)
		return if type(r) == "table" then Big.toNumber(r) else r
	end
	-- fallback: parse "XeY" scientific string
	local s = EN.toScientific(Big.new(a))
	local m, e = string.match(s, "^([%d%.]+)e%+?(%-?[%d%.]+)$")
	if m then
		return tonumber(e) + math.log10(tonumber(m))
	end
	return math.log10(tonumber(s) or 0)
end

-- Plain number; returns math.huge when out of double range
function Big.toNumber(a): number
	if type(a) == "number" then
		return a
	end
	if EN.toNumber then
		return EN.toNumber(a)
	end
	local l = Big.log10(a)
	if l > 308 then
		return math.huge
	end
	return 10 ^ l
end

function Big.floor(a)
	if EN.floor then
		return EN.floor(a)
	end
	local n = Big.toNumber(a)
	if n < 2 ^ 53 then
		return Big.new(math.floor(n))
	end
	return a -- already an integer at this size
end

function Big.format(a): string
	return EN.short(Big.new(a))
end

-- DataStore helpers
function Big.serialize(a): string
	return EN.toString(Big.new(a))
end

function Big.deserialize(s: string)
	-- never let one corrupt value break a player's load: fall back to the plain number, then 0
	local ok, v = pcall(function()
		if EN.fromString then
			return EN.fromString(s)
		end
		return Big.new(s)
	end)
	if ok and v ~= nil then
		return v
	end
	return Big.new(tonumber(s) or 0)
end

return Big
