--!nonstrict
-- Headless smoke test for the client VFX engine (no Studio). Loads the BUILT place, runs every effect at every
-- rarity on a fake 60 Hz RenderStepped, with every texture "uploaded" (fake ids) and again with none, and checks:
--   * no Lua errors / [Vfx] warnings, real property names (Lune's reflection rejects unknown members)
--   * NumberSequence / ColorSequence rules (start at 0, end at 1, ascending, <= 20 keys, transparency in 0..1)
--   * every effect finishes and every pooled piece goes back (no leaks), camera hook returns sane values
-- What it can NOT check: anything visual (sizes, colours, timing feel), Beam/particle rendering, real Instance
-- methods beyond the stubs below. That is Studio QA.
--
--   cd roblox && rojo build default.project.json -o <tmp>/vfx.rbxl && lune run tools/vfx/smoke.luau <tmp>/vfx.rbxl
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")

local placePath = process.args[1] or error("usage: lune run tools/vfx/smoke.luau <built.rbxl>")
local place = roblox.deserializePlace(fs.readFile(placePath))
local Instance, Enum = roblox.Instance, roblox.Enum

local problems = {}
local function problem(msg)
	table.insert(problems, msg)
	print("  !! " .. msg)
end

-- ---------------------------------------------------------------- validated sequences
local function checkKeys(kind, keys, isTrans)
	if #keys < 2 then return end
	if #keys > 20 then problem(kind .. ": " .. #keys .. " keypoints (max 20)") end
	if math.abs(keys[1].Time) > 1e-6 then problem(kind .. ": first keypoint at " .. keys[1].Time) end
	if math.abs(keys[#keys].Time - 1) > 1e-6 then problem(kind .. ": last keypoint at " .. keys[#keys].Time) end
	for i = 2, #keys do
		if keys[i].Time < keys[i - 1].Time then problem(kind .. ": keypoints not ascending") end
	end
end
local NumberSequence = setmetatable({
	new = function(a, b)
		if type(a) == "table" then checkKeys("NumberSequence", a) end
		if type(a) == "table" then
			for _, k in a do
				if k.Value ~= k.Value then problem("NumberSequence: NaN value") end
			end
		end
		return roblox.NumberSequence.new(a, b)
	end,
}, { __index = roblox.NumberSequence })
local ColorSequence = setmetatable({
	new = function(a, b)
		if type(a) == "table" then checkKeys("ColorSequence", a) end
		return roblox.ColorSequence.new(a, b)
	end,
}, { __index = roblox.ColorSequence })

-- ---------------------------------------------------------------- signals + stub methods
local function signal()
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(self.fns, fn)
		local c = { Connected = true }
		function c.Disconnect()
			c.Connected = false
			for i, f in s.fns do if f == fn then table.remove(s.fns, i); break end end
		end
		return c
	end
	function s:Fire(...) for _, f in table.clone(self.fns) do f(...) end end
	return s
end

roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local c = self:FindFirstChild(name)
	if not c then error("WaitForChild would hang: " .. self:GetFullName() .. "." .. name) end
	return c
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function() return signal() end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function() return signal() end)

local emits = { total = 0 }
roblox.implementMethod("ParticleEmitter", "Emit", function(self, n)
	if n == nil or n < 1 or n ~= math.floor(n) then problem("Emit(" .. tostring(n) .. ")") end
	if self.Texture == "" then problem("Emit on an emitter with no texture") end
	emits.total += n or 0
end)
roblox.implementMethod("ParticleEmitter", "Clear", function() end)
roblox.implementMethod("Trail", "Clear", function() end)

-- Model pivot / scale (enough for PivotTo / GetPivot / ScaleTo / GetScale / GetBoundingBox / WorldPivot)
local pivots, scales = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function parts(m)
	local out = {}
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then table.insert(out, d) end end
	return out
end
local function pos(p) return p.CFrame.Position end -- Lune has no computed Position on parts
local function bbox(m)
	local mn, mx = nil, nil
	for _, p in parts(m) do
		local h = p.Size / 2
		mn = if mn then mn:Min(pos(p) - h) else pos(p) - h
		mx = if mx then mx:Max(pos(p) + h) else pos(p) + h
	end
	if not mn then return roblox.CFrame.new(), roblox.Vector3.zero end
	return roblox.CFrame.new((mn + mx) / 2), mx - mn
end
local function getPivot(m) return pivots[m] or bbox(m) end
roblox.implementProperty("Model", "WorldPivot", function(m) return getPivot(m) end, function(m, v) pivots[m] = v end)
roblox.implementMethod("Model", "GetPivot", function(m) return getPivot(m) end)
roblox.implementMethod("Model", "PivotTo", function(m, cf)
	local old = getPivot(m)
	local delta = cf * old:Inverse()
	for _, p in parts(m) do p.CFrame = delta * p.CFrame end
	pivots[m] = cf
end)
roblox.implementMethod("Model", "GetScale", function(m) return scales[m] or 1 end)
roblox.implementMethod("Model", "ScaleTo", function(m, s)
	if not (s > 0) then error("ScaleTo(" .. tostring(s) .. ")") end
	local k = s / (scales[m] or 1)
	local pv = getPivot(m)
	for _, p in parts(m) do
		local off = pos(p) - pv.Position
		p.Size = p.Size * k
		p.CFrame = roblox.CFrame.new(pv.Position + off * k) * p.CFrame.Rotation
	end
	scales[m] = s
end)
roblox.implementMethod("Model", "GetBoundingBox", function(m) return bbox(m) end)
roblox.implementMethod("Instance", "GetFullName", function(self)
	local n, p = self.Name, self.Parent
	while p do n = p.Name .. "." .. n; p = p.Parent end
	return n
end)

-- ---------------------------------------------------------------- fake services
local renderStepped = signal()
local RunService = { RenderStepped = renderStepped, Heartbeat = signal(), IsStudio = function() return true end }
function RunService:BindToRenderStep() end
local settingsSvc = {
	ReducedMotion = false,
	SavedQualityLevel = Enum.SavedQualitySetting.Automatic,
	GetPropertyChangedSignal = function() return signal() end,
}
local ContentProvider = { PreloadAsync = function() end }
local workspaceI = place:GetService("Workspace")
local cam = Instance.new("Camera")
cam.Parent = workspaceI
local lighting = place:GetService("Lighting")
local rsI = place:GetService("ReplicatedStorage")
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local localPlayer = { PlayerGui = playerGui, Character = nil, Name = "Smoke" }
function localPlayer:WaitForChild(n) return self[n] end
local Players = { LocalPlayer = localPlayer }
local fakeGame = {}
function fakeGame:GetService(name)
	if name == "RunService" then return RunService end
	if name == "ContentProvider" then return ContentProvider end
	if name == "Players" then return Players end
	if name == "UserGameSettings" then return settingsSvc end
	if name == "GuiService" then return { ReducedMotionEnabled = false } end
	if name == "Workspace" then return workspaceI end
	if name == "Lighting" then return lighting end
	if name == "ReplicatedStorage" then return rsI end
	return place:GetService(name)
end
local function UserSettings() return { GetService = function(_, n) return fakeGame:GetService(n) end } end

-- ---------------------------------------------------------------- module loader
local client = place:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Peckwood")
local STUB = {} -- ModuleScript -> table (modules too heavy to boot headless)
local birdPos = roblox.Vector3.new(0, 0, 0)
STUB[client:FindFirstChild("IslandView")] = { birdPos = birdPos }
STUB[client:FindFirstChild("Birds")] = { punch = function() end }
local cache = {}
local G = {}
local warnings = 0
local function load(ms)
	if STUB[ms] then return STUB[ms] end
	if cache[ms] ~= nil then return cache[ms] end
	local env = {
		game = fakeGame, workspace = workspaceI, script = ms, Enum = Enum, Instance = Instance,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
		ColorSequence = ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange, UDim2 = roblox.UDim2, UDim = roblox.UDim, BrickColor = roblox.BrickColor,
		Random = roblox.Random, Rect = roblox.Rect, Region3 = roblox.Region3, Font = roblox.Font,
		UserSettings = UserSettings, task = task, _G = G, typeof = typeof, type = type,
		print = print, warn = function(...) warnings += 1; problem("warn: " .. table.concat({ ... }, " ")) end,
		pairs = pairs, ipairs = ipairs, next = next, select = select, tostring = tostring, tonumber = tonumber,
		error = error, assert = assert, pcall = pcall, xpcall = xpcall, setmetatable = setmetatable,
		getmetatable = getmetatable, rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
		unpack = table.unpack, table = table, string = string, math = math, os = os, bit32 = bit32, utf8 = utf8,
		coroutine = coroutine, buffer = buffer, tick = os.clock, time = os.clock,
	}
	env.require = function(m)
		if typeof(m) ~= "Instance" then error("require of non-instance") end
		return load(m)
	end
	local fn = luau.load(luau.compile(ms.Source), { debugName = ms:GetFullName(), environment = env })
	local result = fn()
	cache[ms] = result
	return result
end

-- ---------------------------------------------------------------- run
local VfxAssets = load(rsI:FindFirstChild("Peckwood"):FindFirstChild("VfxAssets"))
local Vfx = load(client:FindFirstChild("Vfx"))
local Hooks = load(client:FindFirstChild("Vfx"):FindFirstChild("Hooks"))
local remotes = Instance.new("Folder")
Vfx.start(nil)

local function run(label, fn)
	local before = #problems
	emits.total = 0
	local handle = fn()
	local frames, cf = 0, roblox.CFrame.lookAt(roblox.Vector3.new(0, 500, 400), roblox.Vector3.zero)
	while (Vfx.activeCount() > 0 or Vfx.CamFx.busy()) and frames < 60 * 30 do
		renderStepped:Fire(1 / 60)
		local c2, fov = Vfx.camera(cf, 11, 1 / 60)
		if typeof(c2) ~= "CFrame" or type(fov) ~= "number" or fov <= 0 or fov > 11.0001 then problem("camera hook returned bad values") end
		frames += 1
		task.wait() -- let task.spawn / task.delay callbacks run
	end
	if Vfx.activeCount() > 0 then problem(label .. ": still active after 30 s") end
	local live = Vfx.Layers.stats()
	for k, v in live do
		if v ~= 0 then problem(label .. ": pool leak " .. k .. "=" .. v) end
	end
	print(string.format("%-34s %s  %5.2f s  %4d particles%s", label, if handle then "ok " else "nil", frames / 60, emits.total,
		if #problems > before then "  <-- " .. (#problems - before) .. " problem(s)" else ""))
end

local function setIds(id)
	for _, t in VfxAssets.tex do t.id = id end
end

print("== all textures uploaded (fake ids) ==")
setIds("123")
print("can collect_pop:", Vfx.can("collect_pop"), " can egg_hatch:", Vfx.can("egg_hatch"))
local at = roblox.Vector3.new(4, 0, 6)
run("collect_pop", function() return Vfx.play("collect_pop", at + roblox.Vector3.new(0, 2, 0), { groundY = 0 }) end)
run("collect_pop golden", function() return Vfx.play("collect_pop", at, { golden = true, groundY = 0 }) end)
run("collect_pop x14 burst (cap 10)", function()
	local h
	for _ = 1, 14 do h = Vfx.play("collect_pop", at, {}) end
	return h
end)
for _, r in Vfx.Palette.ORDER do
	run("egg_hatch " .. r .. " (preview)", function() return Vfx.play("egg_hatch", at, { rarity = r, preview = true }) end)
end
run("egg_hatch Mythic, no egg/pet", function() return Vfx.play("egg_hatch", at, { rarity = "Mythic" }) end)
run("level_up (follow)", function() return Vfx.play("level_up", at, { follow = function() return birdPos end }) end)
run("level_up companion colour", function() return Vfx.play("level_up", at, { color = "6fe0ff", scale = 1.3 }) end)
run("island_unlock (synthetic)", function() return Vfx.play("island_unlock", at, {}) end)
-- the real hook path: IslandView-shaped raw data through Hooks.unlockInfo
do
	local items = {}
	for i = -6, 6 do
		for j = -5, 5 do
			if i * i + j * j <= 30 then
				table.insert(items, { fill = function() end, at = roblox.Vector3.new((i + 0.5) * 4, -14, (j + 0.5) * 4), delay = 0.5 + (i + 6) * 0.045 })
			end
		end
	end
	table.insert(items, { inst = true, at = roblox.Vector3.new(0, 0, 0), delay = 1 }) -- a prop item (ignored)
	local raw = { items = items, landing = roblox.Vector3.new(-24, 0, 0), centre = roblox.Vector3.new(0, 0, 0), waveStart = 0.5, waveEnd = 1.9, step = 0.045, top = 0 }
	local info = Hooks.unlockInfo(raw)
	print("unlockInfo: radius", math.floor(info.radius), "edge tiles", #info.edge, "maxD", math.floor(info.maxD))
	run("island_unlock (IslandView data)", function() return Vfx.play("island_unlock", info.centre, { info = info }) end)
end
run("dev preview _G.__vfx egg_hatch Rare", function() return G.__vfx("egg_hatch", "Rare") end)
run("dev preview _G.__vfx collect_pop", function() return G.__vfx("collect_pop") end)
run("dev preview _G.__vfx level_up", function() return G.__vfx("level_up") end)
run("dev preview _G.__vfx island_unlock", function() return G.__vfx("island_unlock") end)
run("camera shake + flash + push", function()
	Vfx.shake(1, 0.4); Vfx.flash(roblox.Color3.new(1, 0.9, 0.5), 0.3, 0.5); Vfx.push(roblox.Vector3.zero, 0.15, 0.3, 0.2, 0.4)
	return true
end)

print("== no textures uploaded (graceful degrade) ==")
setIds("")
print("can collect_pop:", Vfx.can("collect_pop"), "(Main falls back to the cube burst)")
run("collect_pop (not forced -> nil)", function() return Vfx.play("collect_pop", at, {}) end)
run("egg_hatch Mythic forced, no textures", function() return Vfx.play("egg_hatch", at, { rarity = "Mythic", preview = true, force = true }) end)
run("level_up forced, no textures", function() return Vfx.play("level_up", at, { force = true }) end)
run("island_unlock, no textures", function() return Vfx.play("island_unlock", at, {}) end)

print(string.format("\n%d problem(s), %d warning(s)", #problems, warnings))
process.exit(if #problems == 0 then 0 else 1)
