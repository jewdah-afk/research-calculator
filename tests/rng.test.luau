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

-- AC-X02: determinism beyond the raw PRNG stream. A fixed input sequence is
-- stepped through the seeded mechanics modules, every step appends a line to
-- an event/damage log, and the serialized log must be byte-identical across
-- two independent runs. The GOLDEN checksum is committed, so a replay in a
-- fresh process (or on another machine) that drifts fails here too, not just
-- a same-process replay.
local Damage = require("../src/shared/Sim/Damage")
local Experience = require("../src/shared/Sim/Experience")

-- The fixed input sequence: (dt, base damage, enemy power, player armor).
local SCENARIO = {
	{ 0.25, 10, 6, 1 },
	{ 0.50, 12, 8, 2 },
	{ 0.75, 7, 5, 0 },
	{ 1.00, 20, 12, 3 },
	{ 1.25, 9, 4, 1 },
	{ 1.50, 15, 10, 5 },
}

-- Runs the scenario from a fixed seed and returns the serialized log.
local function runScenario(seed: number): string
	local rng = Rng.new(seed)
	local xp = { level = 1, xp = 0, xpToNext = Experience.xpToNext(1) }
	local lines: { string } = {}
	local t = 0
	for step = 1, 40 do
		local input = SCENARIO[(step - 1) % #SCENARIO + 1]
		local dt, base, power, armor = input[1], input[2], input[3], input[4]
		t += dt
		local hits = rng:int(1, 3)
		local total = 0
		local crits = 0
		for _ = 1, hits do
			local dmg, wasCrit = Damage.roll(base, 0.25, 2, rng)
			total += dmg
			if wasCrit then
				crits += 1
			end
		end
		local taken = Damage.toPlayer(power, armor)
		local gems = rng:range(1, 4)
		local gained = Experience.addXp(xp, Experience.gemValue(gems, 1.5))
		table.insert(
			lines,
			string.format(
				"%03d t=%.2f hits=%d dmg=%.4f crits=%d taken=%.4f gems=%.6f lvl=%d xp=%.6f up=%d",
				step,
				t,
				hits,
				total,
				crits,
				taken,
				gems,
				xp.level,
				xp.xp,
				gained
			)
		)
	end
	return table.concat(lines, "\n")
end

-- FNV-1a over the log, so the committed golden stays one short constant.
local function checksum(s: string): string
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return string.format("%08x", h)
end

local GOLDEN_SEED = 20240919
local GOLDEN_CHECKSUM = "e9afe290"

T.test("RNG-01 AC-X02 seeded scenario: two runs emit byte-identical event logs", function()
	local a = runScenario(GOLDEN_SEED)
	local b = runScenario(GOLDEN_SEED)
	T.eq(#a > 0, true, "log is non-empty")
	T.eq(a, b, "run 1 vs run 2 event log")
end)

T.test("RNG-01 AC-X02 seeded scenario: log matches the committed golden checksum", function()
	T.eq(checksum(runScenario(GOLDEN_SEED)), GOLDEN_CHECKSUM, "golden event-log checksum")
end)

T.test("RNG-01 AC-X02 seeded scenario: a different seed changes the log", function()
	T.eq(runScenario(GOLDEN_SEED) ~= runScenario(GOLDEN_SEED + 1), true, "seed affects the log")
end)

return T.finish()
