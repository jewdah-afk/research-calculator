--!strict
--[[
	server/RunGate.luau -- the one place that decides whether a run step
	advances the simulation.

	core_loop.md §2 ("Game pauses on level up"): while a run is paused the
	clock stops and NOTHING advances -- not run time, not a wave, not a
	weapon cooldown, not an enemy. GameLoop enforces that with a single
	early return; this module is that early return, lifted out of the
	engine-bound script so it can be stepped headlessly and the invariant
	asserted (tests/weapons_a.test.luau, "paused run advances nothing").

	It holds no engine types: the caller samples the player root and passes
	plain numbers, so the module is pure and testable under plain `luau`.
]]

local RunGate = {}

-- The part of a Run this gate reads and writes. GameLoop's Run is a
-- superset of it.
export type GateRun = {
	paused: boolean,
	seeded: boolean,
	lastX: number,
	lastZ: number,
}

-- Returns true when the caller should go on to step the simulation.
--
-- A finished run does nothing at all. A paused run keeps tracking where
-- the player is -- they keep walking on their own client -- so that the
-- first frame after the pause does not read the whole pause-time
-- displacement as one frame of movement; no facing is derived from it.
function RunGate.shouldAdvance(run: GateRun, finished: boolean, rootX: number?, rootZ: number?): boolean
	if finished then
		return false
	end
	if run.paused then
		if rootX ~= nil and rootZ ~= nil then
			run.lastX, run.lastZ = rootX, rootZ
			run.seeded = true
		end
		return false
	end
	return true
end

return RunGate
