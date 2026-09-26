--!nocheck
--[[
	snap.luau: the real client on the mock engine, stopped at a scene, and its PlayerGui written out as JSON for
	tools/snap/render.js (which draws it in Chromium over the painted realm). No Studio needed for a look check.

	    python3 tools/wrap_scripts.py && ./test.sh capture                   (once: the wrapped client + fixtures)
	    luau tools/snap/snap.luau -a <scene> [WxH] > data/snap/<scene>.json

	Scenes: home (s13, the map alone), panel_<layer> (tap the node, then that layer's fixture), fresh (a new save).
	Each object: { c = class, n = name, p = { props }, a = { attributes }, k = { children } }. Datatypes become
	{ t = "UDim2", ... }; Enum items "Enum.X.Y"; Path2D points are kept as p.__points.
]]
local M = require("../../tests/mock")
local E = require("../../tests/engine")(M)
local ARGS = { ... }
local SCENE = ARGS[1] or "home"
local VW, VH = 1920, 1080
if ARGS[2] then
	local w, h = string.match(ARGS[2], "(%d+)x(%d+)")
	VW, VH = tonumber(w), tonumber(h)
end

-- clip mode (-a <scene> <WxH> clip:<frames>:<fps>): the client's clock is pinned per frame so the motion is exact
local CLOCK = 0
local CLIP = ARGS[3] and string.match(ARGS[3], "^clip:(%d+):(%d+)$")
local clipN, clipFps = 0, 30
if CLIP then
	local n, fps = string.match(ARGS[3], "^clip:(%d+):(%d+)$")
	clipN, clipFps = tonumber(n) :: number, tonumber(fps) :: number
	local fakeOs = table.clone(os)
	fakeOs.clock = function() return CLOCK end
	M.G.os = fakeOs
end

local game = M.game
local Instance = M.G.Instance
local Vector2 = E.Vector2
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
Workspace.CurrentCamera.__props.ViewportSize = Vector2.new(VW, VH)

-- a closer TextBounds than the mock's 8 px a character (layout code steps sizes on it)
local Inst = getmetatable(Instance.new("Frame"))
local oldIndex = Inst.__index
-- ScreenGui rects by ScreenInsets in abs space (abs y 0 is under the 58 px top bar), as render.js places them
local INSETS = {
	None = { 0, -58, VW, VH }, DeviceSafeInsets = { 0, -58, VW, VH }, CoreUISafeInsets = { 0, 0, VW, VH - 58 },
	TopbarSafeInsets = { 136, -58, VW - 136 - 76, 58 },
}
local GUI = { Frame = true, ScrollingFrame = true, TextLabel = true, TextButton = true, ImageButton = true, TextBox = true, ImageLabel = true, CanvasGroup = true }
-- x, y, w, h in abs px and k, the scale this object's descendants inherit (the product of the UIScales above them)
local function absRect(o)
	local p = rawget(o, "__props")
	if rawget(o, "__class") == "ScreenGui" then
		local r = INSETS[p.ScreenInsets and p.ScreenInsets.Name or "CoreUISafeInsets"] or INSETS.CoreUISafeInsets
		return r[1], r[2], r[3], r[4], 1
	end
	local parent = p.Parent
	local px, py, pw, ph, pk = 0, 0, VW, VH, 1
	if parent and (rawget(parent, "__class") == "ScreenGui" or GUI[rawget(parent, "__class")]) then px, py, pw, ph, pk = absRect(parent) end
	local s, pos, ap = p.Size, p.Position, p.AnchorPoint
	local own = 1
	for _, c in o.__kids do if c.__class == "UIScale" then own = c.__props.Scale or 1 end end
	local k = pk * own
	local w = if s then s.X.Offset * k + s.X.Scale * pw * own else 100
	local h = if s then s.Y.Offset * k + s.Y.Scale * ph * own else 40
	local x = px + (if pos then pos.X.Offset * pk + pos.X.Scale * pw else 0) - (if ap then ap.X * w else 0)
	local y = py + (if pos then pos.Y.Offset * pk + pos.Y.Scale * ph else 0) - (if ap then ap.Y * h else 0)
	return x, y, math.max(1, w), math.max(1, h), k
end
Inst.__index = function(o, k)
	if (k == "AbsoluteSize" or k == "AbsolutePosition") and (rawget(o, "__class") == "ScreenGui" or GUI[rawget(o, "__class")]) then
		local x, y, w, h = absRect(o)
		return if k == "AbsoluteSize" then Vector2.new(w, h) else Vector2.new(x, y)
	end
	if k == "TextBounds" then
		local p = rawget(o, "__props")
		local text = string.gsub(p.Text or "", "<[^>]->", "")
		local size = p.TextSize or 14
		return Vector2.new(math.ceil(#text * size * 0.62), math.ceil(size * (p.LineHeight or 1) * 1.2))
	end
	return oldIndex(o, k)
end

local client = E.buildClient()
local function folder(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end
local remotes = folder(RS, "MilestoneTreeRemotes")
local R = {}
for _, n in { "View", "Act", "Ready", "Prefs" } do
	local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = remotes
	R[n] = r
end
M.fireServer = function() end
local p = M.addPlayer("Tester", 1)
game:GetService("Players").__props.LocalPlayer = p

local frames = E.frames
local function play(name)
	R.View.OnClientEvent:Fire(require("../../data/fixtures/" .. name))
	frames(0.3)
end

if SCENE == "boot" then
	E.runMain("Boot")
	frames(0.2)
end
E.runMain("Main")
frames(0.5)
local pg = p:FindFirstChild("PlayerGui")
local nodes = pg.MapGui.Root.Box.Nodes

if SCENE == "boot" then
	-- the loading screen while the server loads the save
	R.View.OnClientEvent:Fire({ status = "Loading your save..." })
	frames(2.5)
elseif SCENE == "ranks" then
	-- the leaderboards with a sample page (the Board remote answers from here)
	local fn = Instance.new("RemoteFunction"); fn.Name = "Board"; fn.Parent = remotes
	local NAMES = { "NovaStrike", "Tester", "pixelmoth", "Quasar_9", "lunarfern", "Kestrel", "EchoVale", "moss_byte", "Orbit",
		"Tidewalker", "ashgrove", "Vantablack", "Juniper", "zephyr_22", "Cobalt", "Marigold" }
	local VALUES = { "ee198.2M", "e1.000M", "e184,209", "e10,000", "e3,003", "150NoNogNoce", "4.56NoNog", "84.2K" }
	M.invokeServer = function(_, key)
		local entries = {}
		for i = 1, 30 do
			entries[i] = { rank = i, id = if i == 2 then 1 else 1000 + i, name = NAMES[(i - 1) % #NAMES + 1],
				value = VALUES[math.min(#VALUES, math.ceil(i / 4))] }
		end
		return { ok = true, board = key, entries = entries, you = VALUES[1] }
	end
	play("s13_none")
	frames(1)
	pg.HudGui.Root.Dock.Ranks.Activated:Fire()
	frames(1)
elseif SCENE == "players" then
	-- the player list open with a few players (their published totals)
	local TN = M.require(RS.TowerNum)
	local Boards = M.require(RS.MilestoneTree.Boards)
	local list = { { "Tester", 1, "1e1.08e25", 5 * 3600 + 12 * 60 }, { "NovaStrike", 2, "ee198188918", 3 * 86400 + 4 * 3600 },
		{ "pixelmoth", 3, "84150", 42 * 60 }, { "Quasar_9", 4, "1e10000", 26 * 3600 }, { "lunarfern", 5, "1.5e3002", 9 * 3600 } }
	for _, e in list do
		local pl = if e[2] == 1 then p else M.addPlayer(e[1], e[2])
		pl.__props.DisplayName = e[1]
		local x = TN.from(e[3])
		pl:SetAttribute("MT_Pts", Boards.format(x))
		pl:SetAttribute("MT_PtsKey", TN.sortKey(x))
		pl:SetAttribute("MT_Played", e[4])
	end
	play("s13_none")
	frames(1)
	pg.TopbarGui.Root.PlayerList.Chip.Activated:Fire()
	frames(0.5)
elseif SCENE == "shop" then
	-- the Shop with sample ids (so the prices show) and the 2x Speed pass owned
	local Products = M.require(RS.MilestoneTree.Products)
	for i, pp in Products.passes do pp.id = 100 + i end
	for i, pp in Products.products do pp.id = 200 + i end
	p:SetAttribute("MT_Perks", '["speed"]')
	play("s13_none")
	frames(1)
	pg.HudGui.Root.Dock.Shop.Activated:Fire()
	frames(1)
elseif SCENE == "tut1" or SCENE == "tut3" then
	-- the tutorial on a fresh game: step 1 (the points bar), or step 3 (the Milestone panel's button)
	play("fresh_none")
	frames(1)
	if SCENE == "tut3" then
		pg.OverlayGui.Root.Guide.Card.Buttons.Next.Activated:Fire()
		frames(0.5)
		nodes.Node_m.Hit.Activated:Fire()
		frames(0.3)
		play("fresh_m")
		frames(1.5)
	end
elseif SCENE == "home" then
	play("s13_none")
	frames(3)
elseif SCENE == "fresh" then
	play("fresh_none")
	frames(3)
elseif string.sub(SCENE, 1, 6) == "panel_" then
	local layer = string.sub(SCENE, 7)
	play("s13_none")
	frames(1)
	local hit = nodes["Node_" .. layer].Hit
	hit.Activated:Fire()
	frames(0.3)
	local fx = if layer == "p" or layer == "m" then "s13_" .. layer else "layer_" .. layer
	play(fx)
	frames(3)
else
	error("unknown scene " .. SCENE)
end

-- ------------------------------------------------------------------------------------------------------ JSON
local function jstr(s)
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then return '\\"' end
		if c == "\\" then return "\\\\" end
		if c == "\n" then return "\\n" end
		if c == "\t" then return "\\t" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end
local function tname(v)
	local mt = getmetatable(v)
	if mt and rawget(mt, "__type") then return mt.__type end
	if mt and mt.__tostring then return tostring(v) end
	return nil
end
local enc
local function encValue(v, out)
	local t = type(v)
	if t == "string" then table.insert(out, jstr(v))
	elseif t == "number" then
		if v ~= v then table.insert(out, "0")
		elseif v == math.huge then table.insert(out, "1e9")
		elseif v == -math.huge then table.insert(out, "-1e9")
		else table.insert(out, string.format("%.6g", v)) end
	elseif t == "boolean" then table.insert(out, tostring(v))
	elseif t == "table" then
		if rawget(v, "EnumType") ~= nil and rawget(v, "Name") ~= nil then
			table.insert(out, jstr("Enum." .. tostring(v.EnumType) .. "." .. v.Name))
			return
		end
		local tn = tname(v)
		local fields = {}
		if tn then fields.t = tn end
		for k, x in v do
			if type(k) == "string" or type(k) == "number" then fields[k] = x end
		end
		-- arrays (ColorSequence keypoints, Path2D points)
		if #v > 0 and not tn then
			table.insert(out, "[")
			for i, x in ipairs(v) do
				if i > 1 then table.insert(out, ",") end
				encValue(x, out)
			end
			table.insert(out, "]")
			return
		end
		table.insert(out, "{")
		local first = true
		for k, x in fields do
			local tk = type(x)
			if tk == "function" or tk == "thread" or tk == "userdata" then continue end
			if type(x) == "table" and getmetatable(x) == Inst then continue end
			if not first then table.insert(out, ",") end
			first = false
			table.insert(out, jstr(tostring(k)) .. ":")
			encValue(x, out)
		end
		table.insert(out, "}")
	else
		table.insert(out, "null")
	end
end
local SKIP = { Parent = true, ClassName = true, Name = true }
enc = function(o, out)
	table.insert(out, '{"c":' .. jstr(o.__class) .. ',"n":' .. jstr(tostring(o.__props.Name)) .. ',"p":{')
	local first = true
	for k, v in o.__props do
		if SKIP[k] or type(k) ~= "string" then continue end
		local tv = type(v)
		if tv == "function" or tv == "thread" then continue end
		if tv == "table" and (getmetatable(v) == Inst or getmetatable(v) == M.Signal or rawget(v, "handlers")) then continue end
		if not first then table.insert(out, ",") end
		first = false
		table.insert(out, jstr(k) .. ":")
		encValue(v, out)
	end
	table.insert(out, '},"a":')
	encValue(o.__attrs or {}, out)
	table.insert(out, ',"k":[')
	for i, c in o.__kids do
		if i > 1 then table.insert(out, ",") end
		enc(c, out)
	end
	table.insert(out, "]}")
end

local function dump()
	local out = {}
	table.insert(out, '{"scene":' .. jstr(SCENE) .. ',"w":' .. VW .. ',"h":' .. VH .. ',"errors":' .. (M.errors or 0) .. ',"gui":')
	enc(pg, out)
	table.insert(out, "}")
	print(table.concat(out))
end
if CLIP then
	for i = 0, clipN - 1 do
		CLOCK = 100 + i / clipFps
		frames(1 / clipFps)
		dump()
	end
else
	dump()
end
