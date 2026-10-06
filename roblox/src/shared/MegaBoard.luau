--!nonstrict
-- Geometry of the one shared Mega Board, used by the server (to build it) and by every client
-- (to simulate and draw orbs on it). Physics runs in logical units, then maps onto the board.
--
--   logical space: x 0..W (slot payouts use x), y 0..H downward
--   world space:   board stands at the north end of the plaza, leaning back TILT degrees

local MegaBoard = {}

MegaBoard.W = 400
MegaBoard.H = 260
MegaBoard.STUD = 1.1 -- studs per logical unit -> 440 x 286 studs
MegaBoard.TILT = 12 -- degrees leaning back
MegaBoard.BOTTOM = Vector3.new(0, 10, -190) -- world position of the bottom-centre of the play area
MegaBoard.ORB_SCALE = 0.55 -- board scale for orbs
-- every orb is the same size (the size of the very first orb), whatever its rarity: bigger orbs
-- bounced differently, so a uniform size keeps the slot odds identical for everyone
MegaBoard.ORB_R = 5 * MegaBoard.ORB_SCALE
MegaBoard.SPAWN_Y = 12
MegaBoard.COLLECT_Y = 246
MegaBoard.SLOT_H = 14 -- logical height of the slot strip at the bottom
MegaBoard.GRAVITY = 520
MegaBoard.MAX_SPEED = 420

-- CFrame of the board plane: X = right, Y = up the board, -Z = into the board (towards the back)
MegaBoard.CF = CFrame.new(MegaBoard.BOTTOM) * CFrame.Angles(-math.rad(MegaBoard.TILT), 0, 0)

function MegaBoard.toWorld(x: number, y: number, depth: number?): Vector3
	local S = MegaBoard.STUD
	return MegaBoard.CF:PointToWorldSpace(Vector3.new((x - MegaBoard.W / 2) * S, (MegaBoard.H - y) * S, depth or 0))
end

-- Classic Plinko pyramid: orbs enter at the top centre and fan out row by row, so the far
-- slots are genuinely rare. Low bounce + sideways damping keeps it a real bell curve
-- (measured over 200k drops: see OrbConfig.Tiers.MegaSlots).
local ROWS, SP, TOP, BOTTOM = 16, 22, 30, 226
MegaBoard.PEG_REST = 0.22
MegaBoard.ORB_REST = 0.22
MegaBoard.DAMP = 0.65 -- sideways speed kept after each peg hit
MegaBoard.SPAWN_X0, MegaBoard.SPAWN_X1 = 196, 204

function MegaBoard.pegs()
	local out = {}
	for r = 0, ROWS - 1 do
		local y = TOP + r * (BOTTOM - TOP) / (ROWS - 1)
		local n = r + 3
		for c = 0, n - 1 do
			table.insert(out, { x = MegaBoard.W / 2 + (c - (n - 1) / 2) * SP, y = y, r = 3, rest = MegaBoard.PEG_REST })
		end
	end
	return out
end

-- guide rails along the pyramid's sides (segments, logical units)
function MegaBoard.rails()
	local out = {}
	for _, side in { -1, 1 } do
		table.insert(out, {
			x1 = MegaBoard.W / 2 + side * (1.5 * SP + SP * 0.6), y1 = TOP - 12,
			x2 = MegaBoard.W / 2 + side * ((ROWS + 2) / 2 * SP - SP * 0.2), y2 = BOTTOM - 4,
			half = 2,
		})
	end
	return out
end

-- uniform grid buckets so each orb only tests the few pegs near it
MegaBoard.CELL = 25
function MegaBoard.buckets(pegs)
	local cell = MegaBoard.CELL
	local grid = {}
	for _, p in pegs do
		local x0, x1 = math.floor((p.x - p.r) / cell), math.floor((p.x + p.r) / cell)
		local y0, y1 = math.floor((p.y - p.r) / cell), math.floor((p.y + p.r) / cell)
		for gx = x0, x1 do
			for gy = y0, y1 do
				local k = gy * 64 + gx
				grid[k] = grid[k] or {}
				table.insert(grid[k], p)
			end
		end
	end
	return grid
end

-- slot dividers (logical x), built from the symmetric MegaSlots bands; payout per slot is per-player
function MegaBoard.slotEdges(bands)
	local out = { 0, MegaBoard.W }
	for _, band in bands do
		if band.upTo < MegaBoard.W / 2 then
			table.insert(out, MegaBoard.W / 2 - band.upTo)
			table.insert(out, MegaBoard.W / 2 + band.upTo)
		end
	end
	table.sort(out)
	return out
end

return MegaBoard
