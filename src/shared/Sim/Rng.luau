--!strict
--[[
	Sim/Rng.luau -- seeded, deterministic, allocation-free random stream.

	The research has no notion of a random number generator (it only states
	probabilities such as chest tier odds and the 4th-option luck roll), so
	the generator itself is an engine choice: a Lehmer / MINSTD linear
	congruential generator, state' = state * multiplier mod modulus. Both
	constants live in Tuning.rng and are flagged NOT from research. Every
	product stays below 2^53, so the sequence is exact in doubles and
	identical on every platform; two Rng.new(seed) with the same seed yield
	the same stream forever.

	Pure Luau: no Roblox APIs, no yields. Runs under the plain `luau` CLI.
	Nothing after Rng.new allocates: next/range/int/chance/pick are
	closure calls over one numeric upvalue.

	Types: src/shared/Types.luau is the contract, but it returns nil, which
	the plain `luau` CLI refuses to require ("module must return a table or
	function"). The alias below therefore restates Types.Rng structurally;
	Luau's structural typing makes it interchangeable with Types.Rng for
	every consumer. Keep it byte-for-byte in step with Types.luau.
]]

local Tuning = require("../Tuning")

-- Mirrors Types.Rng.
export type Rng = {
	next: (self: Rng) -> number, -- [0, 1)
	range: (self: Rng, min: number, max: number) -> number,
	int: (self: Rng, min: number, max: number) -> number, -- inclusive
	chance: (self: Rng, p: number) -> boolean, -- p in [0, 1]
	pick: <T>(self: Rng, list: { T }) -> T,
}

local MULTIPLIER = Tuning.rng.multiplier
local MODULUS = Tuning.rng.modulus

local Rng = {}

-- Creates an independent stream. Any finite number is a valid seed; it is
-- floored and folded into the generator's state range [1, modulus - 1], so
-- 0 and negative seeds are fine and the state is never the fixed point 0.
function Rng.new(seed: number): Rng
	if type(seed) ~= "number" or seed ~= seed or seed == math.huge or seed == -math.huge then
		error(string.format("Rng.new: seed must be a finite number, got %s", tostring(seed)))
	end
	local state = math.floor(seed) % (MODULUS - 1) + 1

	-- One step of the generator. The state stays in [1, modulus - 1], so the
	-- quotient is strictly inside (0, 1) and never reaches 1.
	local function draw(): number
		state = state * MULTIPLIER % MODULUS
		return state / MODULUS
	end

	local rng: Rng = {
		next = function(_self: Rng): number
			return draw()
		end,
		range = function(_self: Rng, min: number, max: number): number
			return min + draw() * (max - min)
		end,
		int = function(_self: Rng, min: number, max: number): number
			if max < min then
				error(string.format("Rng.int: max (%s) < min (%s)", tostring(max), tostring(min)))
			end
			-- draw() < 1, so floor(draw() * span) <= span - 1: both ends inclusive.
			return min + math.floor(draw() * (max - min + 1))
		end,
		chance = function(_self: Rng, p: number): boolean
			-- draw() is never exactly 0 and never 1, so chance(0) is never true
			-- and chance(1) is always true.
			return draw() < p
		end,
		pick = function<T>(_self: Rng, list: { T }): T
			local n = #list
			if n == 0 then
				error("Rng.pick: list is empty")
			end
			return list[1 + math.floor(draw() * n)]
		end,
	}
	return rng
end

return Rng
