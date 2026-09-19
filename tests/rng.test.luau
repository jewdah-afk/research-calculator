--!strict
-- Sim/Rng. research/vs has no random number generator, only probabilities
-- (Tuning.luau "sim-core" section); these are the determinism and range
-- guarantees docs/ARCHITECTURE.md and Types.Rng promise.
local T = require("./_harness")
local Rng = require("../src/shared/Sim/Rng")

local N = 1000

T.test("RNG-01 ARCHITECTURE.md Sim/Rng: two Rng.new(42) streams are identical over 1000 draws", function()
	local a = Rng.new(42)
	local b = Rng.new(42)
	for i = 1, N do
		T.eq(a:next(), b:next(), "draw " .. i)
	end
end)

T.test("RNG-01 Types.md Rng.next: every value is in [0, 1)", function()
	local r = Rng.new(42)
	for i = 1, N do
		local v = r:next()
		T.truthy(v >= 0 and v < 1, "draw " .. i .. " = " .. v)
	end
end)

T.test("RNG-01 Types.md Rng.int: inclusive at both ends, nothing outside [1, 3]", function()
	local r = Rng.new(7)
	local sawMin, sawMax = false, false
	for _ = 1, N do
		local v = r:int(1, 3)
		T.truthy(v >= 1 and v <= 3, "int in range, got " .. v)
		T.eq(v, math.floor(v), "int is integral")
		if v == 1 then
			sawMin = true
		end
		if v == 3 then
			sawMax = true
		end
	end
	T.truthy(sawMin, "1 occurs")
	T.truthy(sawMax, "3 occurs")
end)

T.test("RNG-01 Types.md Rng.chance: chance(0) never, chance(1) always", function()
	local r = Rng.new(99)
	for _ = 1, N do
		T.eq(r:chance(0), false, "chance(0)")
		T.eq(r:chance(1), true, "chance(1)")
	end
end)

T.test("RNG-01 Types.md Rng.pick: always a member of the list", function()
	local r = Rng.new(3)
	local list = { "a", "b", "c", "d" }
	for _ = 1, N do
		T.truthy(table.find(list, r:pick(list)) ~= nil, "member")
	end
end)

T.test("RNG-01 Types.md Rng.range: within [min, max]", function()
	local r = Rng.new(5)
	for _ = 1, N do
		local v = r:range(-2, 2)
		T.truthy(v >= -2 and v <= 2, "range")
	end
end)

T.test("RNG-01 different seeds give different streams", function()
	local a = Rng.new(1)
	local b = Rng.new(2)
	local same = true
	for _ = 1, 10 do
		if a:next() ~= b:next() then
			same = false
		end
	end
	T.eq(same, false, "seed 1 vs seed 2")
end)

return T.finish()
