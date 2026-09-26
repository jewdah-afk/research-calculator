--!nocheck
--[[
	snap_mk.luau: a marketing variant of port/tools/snap/snap.luau (the real client on the mock engine, its PlayerGui
	written out as JSON). It adds a camera: the MapView the client builds is captured, so a still or a clip can be
	framed anywhere in the realm (world px, 3840 x 2560; z = map zoom, 0.24 .. 1.25).

	    cd port && luau ../art/marketing/snap_mk.luau -a <scene> <WxH> <cam> [clip:<frames>:<fps>]

	scene   <fixture>              play data/fixtures/<fixture> (e.g. s13_none, fresh_none, s19mv_none)
	        panel_<layer>          s13_none, tap the node, then that layer's fixture (as snap.luau)
	        open_<layer>@<frame>   clip only: s13_none, and the tap + fixture happen at clip frame <frame>
	cam     keep                   the client's own framing
	        x,y,z                  a fixed camera
	        x,y,z>x,y,z            clip only: a smoothstep dolly from the first to the second over the clip
	One JSON line per frame, as snap.luau (render with art/marketing/lib/snap.js).
]]
local M = require("../../port/tests/mock")
local E = require("../../port/tests/engine")(M)
local ARGS = { ... }
local SCENE = ARGS[1] or "s13_none"
local VW, VH = 1920, 1080
if ARGS[2] then
	local w, h = string.match(ARGS[2], "(%d+)x(%d+)")
	VW, VH = tonumber(w), tonumber(h)
end
local CAMSPEC = ARGS[3] or "keep"

local CLOCK = 0
local clipN, clipFps = 0, 30
local CLIP = ARGS[4] and string.match(ARGS[4], "^clip:(%d+):(%d+)$")
if CLIP then
	local n, fps = string.match(ARGS[4], "^clip:(%d+):(%d+)$")
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

-- the same AbsoluteSize / TextBounds shims as snap.luau
local Inst = getmetatable(Instance.new("Frame"))
local oldIndex = Inst.__index
local INSETS = {
	None = { 0, -58, VW, VH }, DeviceSafeInsets = { 0, -58, VW, VH }, CoreUISafeInsets = { 0, 0, VW, VH - 58 },
	TopbarSafeInsets = { 136, -58, VW - 136 - 76, 58 },
}
local GUI = { Frame = true, ScrollingFrame = true, TextLabel = true, TextButton = true, ImageButton = true, TextBox = true, ImageLabel = true, CanvasGroup = true }
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

-- capture the MapView the client builds (wrap MapView.new before any require runs)
local VIEW = nil
local function findModule(root, name)
	for _, c in root.__kids do
		if c.__class == "ModuleScript" and c.__props.Name == name then return c end
		local r = findModule(c, name)
		if r then return r end
	end
	return nil
end
local mv = findModule(client, "MapView")
assert(mv, "MapView module not found")
local load = mv.__module
mv.__module = function()
	local mod = load()
	local new = mod.new
	mod.new = function(...)
		local v = new(...)
		VIEW = v
		return v
	end
	return mod
end

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
	R.View.OnClientEvent:Fire(require("../../port/data/fixtures/" .. name))
	frames(0.3)
end

E.runMain("Main")
frames(0.5)
local pg = p:FindFirstChild("PlayerGui")
local nodes = pg.MapGui.Root.Box.Nodes

local function tap(layer)
	nodes["Node_" .. layer].Hit.Activated:Fire()
	frames(0.3)
	play(if layer == "p" or layer == "m" then "s13_" .. layer else "layer_" .. layer)
end

local openLayer, openAt = nil, -1
if string.sub(SCENE, 1, 6) == "panel_" then
	play("s13_none")
	frames(1)
	tap(string.sub(SCENE, 7))
	frames(3)
elseif string.sub(SCENE, 1, 5) == "open_" then
	local l, f = string.match(SCENE, "^open_(%w+)@(%d+)$")
	openLayer, openAt = l, tonumber(f)
	play("s13_none")
	frames(3)
else
	play(SCENE)
	frames(3)
end

-- ------------------------------------------------------------------------------------------------------ camera
local function parseCam(s)
	local x, y, z = string.match(s, "^([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)$")
	return { tonumber(x), tonumber(y), tonumber(z) }
end
local cam0, cam1 = nil, nil
if CAMSPEC ~= "keep" then
	local a, b = string.match(CAMSPEC, "^(.-)>(.-)$")
	if a then cam0, cam1 = parseCam(a), parseCam(b) else cam0 = parseCam(CAMSPEC) end
end
local function setCam(t)
	if not cam0 or not VIEW then return end
	local c = cam0
	if cam1 then
		local s = t * t * (3 - 2 * t)
		-- zoom interpolates in log space so a dolly feels even
		c = { cam0[1] + (cam1[1] - cam0[1]) * s, cam0[2] + (cam1[2] - cam0[2]) * s, math.exp(math.log(cam0[3]) + (math.log(cam1[3]) - math.log(cam0[3])) * s) }
	end
	VIEW:cancelFly()
	VIEW:setCamera(Vector2.new(c[1], c[2]), c[3])
end
if not CLIP then
	setCam(0)
	frames(0.2)
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
local function enc(o, out)
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
local function dump(i)
	local out = {}
	table.insert(out, '{"scene":' .. jstr(SCENE) .. ',"frame":' .. i .. ',"w":' .. VW .. ',"h":' .. VH .. ',"errors":' .. (M.errors or 0) .. ',"gui":')
	enc(pg, out)
	table.insert(out, "}")
	print(table.concat(out))
end

-- ------------------------------------------------------------------------------------------------------ ticker
-- clips send the server's view patches a real session would: the HUD points and the node values climb (numbers
-- going up), and the client never goes quiet long enough to show "Reconnecting"
local BASE = string.sub(SCENE, 1, 6) == "panel_" and "s13_none" or string.sub(SCENE, 1, 5) == "open_" and "s13_none" or SCENE
local baseView = require("../../port/data/fixtures/" .. BASE)
local function commas(n)
	local s = tostring(math.floor(n))
	local out = string.reverse(string.gsub(string.reverse(s), "(%d%d%d)", "%1,"))
	return (string.gsub(out, "^,", ""))
end
-- one value string moved on by t seconds at rate r (per second, in the string's own units)
local function bump(s, t, r)
	if type(s) ~= "string" then return s end
	local m, e = string.match(s, "^e(%d+%.%d+)e(%d+)$")
	if m then
		local v, x = tonumber(m) + r * 0.03 * t, tonumber(e)
		while v >= 10 do v /= 10; x += 1 end
		return string.format("e%.3fe%d", v, x)
	end
	m, e = string.match(s, "^(%d+%.%d+)e(%d+)$")
	if m then
		local l = math.log10(tonumber(m)) + tonumber(e) + r * 0.05 * t
		local x = math.floor(l)
		return string.format("%.2fe%d", 10 ^ (l - x), x)
	end
	m = string.match(s, "^e([%d,]+)$")
	if m then
		local v = tonumber((string.gsub(m, ",", "")))
		return "e" .. commas(v + math.floor(v * 0.0008 * r * t))
	end
	return s
end
local tickIds = {}
for id, v in baseView.set or {} do
	if type(v) == "table" and (v.t == "hud" or (v.t == "val" and v.pts)) then table.insert(tickIds, id) end
end
table.sort(tickIds)
local function tickPatch(t)
	local set = {}
	for k, id in tickIds do
		local v = table.clone(baseView.set[id])
		local r = 0.6 + ((k * 37) % 10) / 10 -- a steady per-node rate, so neighbours do not tick in lockstep
		v.pts = bump(v.pts, t, r)
		set[id] = v
	end
	return { full = false, del = {}, set = set }
end

if CLIP then
	for i = 0, clipN - 1 do
		CLOCK = 100 + i / clipFps
		if i % 3 == 0 then R.View.OnClientEvent:Fire(tickPatch(i / clipFps)) end
		if i == openAt and openLayer then
			-- the tap and the server's answer land inside this frame; the panel animates over the next ones
			nodes["Node_" .. openLayer].Hit.Activated:Fire()
			frames(1 / clipFps)
			R.View.OnClientEvent:Fire(require("../../port/data/fixtures/" .. (if openLayer == "p" or openLayer == "m" then "s13_" .. openLayer else "layer_" .. openLayer)))
			-- the panel's view carries the fixture's HUD values; put the ticked ones straight back
			R.View.OnClientEvent:Fire(tickPatch(i / clipFps))
		end
		-- no camera override once a panel is open (the client moves the map beside the sheet itself)
		if not (openLayer and i >= openAt) then setCam(if clipN > 1 then i / (clipN - 1) else 0) end
		frames(1 / clipFps)
		dump(i)
	end
else
	dump(0)
end
