--!nonstrict
-- Geometry of the one shared Mega Board, used by the server (to build it) and by every client
-- (to simulate and draw orbs on it). Physics runs in logical units, then maps onto the board.
--
--   logical space: x 0..W (same x as the old board, so slot payouts are unchanged), y 0..H downward
--   world space:   board stands at the north end of the plaza, leaning back TILT degrees

local MegaBoard = {}

MegaBoard.W = 400
MegaBoard.H = 260
MegaBoard.STUD = 1.1 -- studs per logical unit -> 440 x 286 studs
MegaBoard.TILT = 12 -- degrees leaning back
MegaBoard.BOTTOM = Vector3.new(0, 10, -190) -- world position of the bottom-centre of the play area
MegaBoard.ORB_SCALE = 0.55 -- orbs are drawn/simulated smaller on the huge board
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

-- staggered peg field; spacing leaves room for the biggest orb (r 15 * 0.55)
local PEG_R = 3
local ROWS, COLS = 11, 16
local TOP, BOTTOM = 40, 220

function MegaBoard.pegs()
	local out = {}
	local sx = MegaBoard.W / COLS
	for r = 0, ROWS - 1 do
		local y = TOP + r * (BOTTOM - TOP) / (ROWS - 1)
		local off = (r % 2 == 1) and sx / 2 or 0
		local n = (r % 2 == 1) and COLS - 1 or COLS
		for c = 0, n - 1 do
			table.insert(out, { x = off + sx / 2 + c * sx, y = y, r = PEG_R, rest = 0.5 })
		end
	end
	-- a few big gold bumpers for drama
	for _, p in { { 100, 130 }, { 300, 130 }, { 200, 75 } } do
		table.insert(out, { x = p[1], y = p[2], r = 9, rest = 1.1, big = true })
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

-- slot dividers (logical x) shared by everyone; the payout per slot is per-player (their tier)
function MegaBoard.slotEdges()
	return { 0, 66, 155, 244, 333, 400 }
end

return MegaBoard
