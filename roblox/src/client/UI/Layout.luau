--!nonstrict
-- Layout: the screen split Birb uses, and the ONE spacing table every HUD piece and window uses.
-- The upgrades SIDEBAR is a permanent right column (25 % of the width like Birb, full height, open by default, a small
-- collapse tab on its left edge at mid-height); everything left of it is the GAME AREA. HUD pieces and windows are
-- placed relative to the game area, never over the sidebar, and re-flow when the sidebar slides away or back.
-- All values are design px of the 1080-tall canvas (canvas UIScale = viewport height / 1080), on an 8 px grid.
--
--   0 ............................................... gameRight | sidebar (sidebarW) | W
--                                 rail (RAIL_W) | GAP | tab (TAB_W) |
--   windows live in [0, windowRight] (the rail strip and the collapse tab stay clear)
--
-- Birb measured (1600x900 captures, x1.2 for 1080p): screen edge margins 24-30, gaps between stacked boxes 8-10,
-- sidebar 25.25 % wide, docked windows 24 from the game-area edges, collapse tab 19x65 at mid-height.
local Layout = {}

-- spacing scale (8 px grid at 1080p): use these everywhere, never a literal
Layout.S = {
	U = 8,
	EDGE = 24,      -- screen / game-area edge margin
	GAP = 8,        -- between stacked pieces of one group (wallet rows, COMPANIONS -> AUTO, hotbar -> objective)
	GAP2 = 16,      -- between groups (AUTO -> rail, arrows -> hotbar, toast -> toast)
	TOPMIN = 32,    -- top margin when the Roblox top bar does not cover the corner (Birb: 30-32)
	WIN = 24,       -- window margin inside the game area (Birb docks its panels 24 from the edges)
	TAB_W = 24, TAB_H = 72,   -- sidebar collapse tab
	RAIL_W = 100,   -- area rail strip width (Figma hud/area rail)
	-- component scales (Figma HUD mock 229:7): one HUD scale, the wallet a touch bigger (it is #2 in the hierarchy)
	HUD = 0.8, WALLET = 0.85, RAIL = 1.0, CONTEXT = 0.8, TOAST = 0.8,
}
Layout.W, Layout.H = 1920, 1080
Layout.TOP = Layout.S.TOPMIN    -- shared top margin (raised below the Roblox top bar, see setInset)
Layout.sidebarOpen = true
Layout.SIDEBAR_FIGMA_W = 540    -- the Figma drawer frames (260:3088 ...) are 540 wide

local listeners = {}
function Layout.onChanged(fn) table.insert(listeners, fn) end
local function fire(animate)
	for _, fn in listeners do task.spawn(fn, animate) end
end

function Layout.snap(v: number): number   -- to the 8 px grid
	return math.floor(v / Layout.S.U + 0.5) * Layout.S.U
end
-- sidebar: a quarter of the screen (Birb), readable on narrow screens, never more than half
function Layout.sidebarW(): number
	return Layout.snap(math.clamp(Layout.W * 0.25, math.min(384, Layout.W * 0.5), Layout.W * 0.5))
end
function Layout.sidebarScale(): number
	return Layout.sidebarW() / Layout.SIDEBAR_FIGMA_W
end
-- left edge of the sidebar (= right edge of the game area); the screen edge while collapsed
function Layout.gameRight(): number
	return if Layout.sidebarOpen then Layout.W - Layout.sidebarW() else Layout.W
end
-- right edge of the HUD's right column (COMPANIONS, AUTO, rail, tiles): just left of the collapse tab
function Layout.columnRight(): number
	return Layout.gameRight() - Layout.S.TAB_W - Layout.S.GAP
end
-- windows live in [0, windowRight]
function Layout.windowRight(): number
	return Layout.columnRight() - Layout.S.RAIL_W * Layout.S.RAIL - Layout.S.GAP2
end
function Layout.gameCentre(): number
	return Layout.gameRight() / 2
end

function Layout.setCanvas(w: number, h: number)
	if math.abs(w - Layout.W) < 0.5 and math.abs(h - Layout.H) < 0.5 then return end
	Layout.W, Layout.H = w, h
	fire(false)
end
-- the Roblox top bar covers the top of the screen: the shared top margin starts under it, on the grid
function Layout.setInset(insetY: number)
	local top = if insetY > 0 then math.ceil((insetY + Layout.S.GAP) / Layout.S.U) * Layout.S.U else Layout.S.TOPMIN
	top = math.max(top, Layout.S.TOPMIN)
	if top ~= Layout.TOP then Layout.TOP = top; fire(false) end
end
function Layout.setSidebar(open: boolean)
	if Layout.sidebarOpen == open then return end
	Layout.sidebarOpen = open
	fire(true)
end

-- the WINDOW REGION: the game area minus the HUD bands (top band = banner / area meter / COMPANIONS + AUTO, left
-- column = the wallet when it runs down past the top band, bottom band = hotbar / objective / icon row, right = the
-- rail strip). The HUD measures its pieces and sets it; windows scale and dock inside it, so they never cover the
-- banner, the wallet or the bottom row. { x0, y0, x1, y1 } in design px.
Layout.region = nil
local regionListeners = {}
function Layout.onRegion(fn) table.insert(regionListeners, fn) end
function Layout.setRegion(x0: number, y0: number, x1: number, y1: number)
	-- whole pixels, rounded inward (UDim offsets are integers)
	x0, y0, x1, y1 = math.ceil(x0), math.ceil(y0), math.floor(x1), math.floor(y1)
	local r = Layout.region
	if r and math.abs(r[1] - x0) < 0.5 and math.abs(r[2] - y0) < 0.5 and math.abs(r[3] - x1) < 0.5 and math.abs(r[4] - y1) < 0.5 then return end
	Layout.region = { x0, y0, x1, y1 }
	for _, fn in regionListeners do task.spawn(fn) end
end
function Layout.windowRegion(): (number, number, number, number)
	local r = Layout.region
	if r then return r[1], r[2], r[3], r[4] end
	return Layout.S.WIN, Layout.S.WIN, Layout.windowRight(), Layout.H - Layout.S.WIN
end

-- visual bounds of a Figma component node (union of its children, drop shadows ignored): alignment edges come from
-- what you SEE (a wallet chip's icon sticks out left of its key, so the stack aligns on the icon)
function Layout.bounds(node): (number, number, number, number)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, c in node.k or {} do
		local n = string.lower(c.n or "")
		if not string.find(n, "shadow") then
			x0 = math.min(x0, c.x); y0 = math.min(y0, c.y); x1 = math.max(x1, c.x + c.w); y1 = math.max(y1, c.y + c.h)
		end
	end
	if x0 == math.huge then return 0, 0, node.w, node.h end
	return x0, y0, x1, y1
end

return Layout
