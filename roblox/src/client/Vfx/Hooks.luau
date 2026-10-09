--!nonstrict
-- Vfx/Hooks: wires the effects into the game, and the dev preview. Started once by Main (Vfx.start(Remotes)).
--   island_unlock  IslandView.onUnlock (called by IslandView.unlockIsland's animated path with its wave timing)
--   level_up       a companion's level going up (State: sparrow / seagull / dave / crow / parrot .level, same save
--                  mode, throttled to one per 2.5 s), Evolve and Molt toasts (bigger)
--   collect_pop    in Main's Collect handler (it knows the egg position); egg_hatch has no game event yet (no hatch
--                  screen): call Vfx.play("egg_hatch", groundPos, { rarity = ..., egg = model, pet = model }).
-- Dev preview (client): _G.__vfx(name, position?, opts?)  |  _G.__vfx("egg_hatch", "Mythic")  |  _G.__vfx("hatch_all")
--   or from the server command bar: PlayerGui:SetAttribute("PeckwoodVfx", "egg_hatch:Mythic#1") (nonce re-fires).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Peckwood")
local World = require(Shared:WaitForChild("World"))
local Map = require(Shared:WaitForChild("MapData"))
local Models = require(Shared:WaitForChild("Models"))
local client = script.Parent.Parent
local IslandView = require(client:WaitForChild("IslandView"))
local Birds = require(client:WaitForChild("Birds"))

local S = Models.S
local Hooks = {}
local plr = Players.LocalPlayer

-- feet of the local hen (IslandView.birdPos is written by Main every frame)
local function hen(): Vector3?
	if IslandView.birdPos then return IslandView.birdPos end
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	return hrp and (hrp.Position - Vector3.new(0, hrp.Size.Y / 2, 0)) or nil
end
Hooks.hen = hen

-- IslandView unlock data -> island_unlock info (centre, radius, wave timing, coast tiles with their rise times)
function Hooks.unlockInfo(raw)
	local top = raw.top or 0
	local centre = Vector3.new(raw.centre.X, top, raw.centre.Z)
	local edge, radius = {}, 8
	for _, x in raw.items do
		if not (x.fill and x.at) then continue end
		local i = math.floor(x.at.X / S + Map.COLS / 2)
		local j = math.floor(x.at.Z / S + Map.ROWS / 2)
		local pos = Vector3.new(x.at.X, top, x.at.Z)
		radius = math.max(radius, (Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)).Magnitude)
		local coast = false
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			if World.rawTile(i + o[1], j + o[2]) == 0 then coast = true; break end
		end
		if coast then
			local out = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
			table.insert(edge, { pos = pos, at = x.delay, out = if out.Magnitude > 0.01 then out.Unit else Vector3.xAxis })
		end
	end
	table.sort(edge, function(a, b) return a.at < b.at end)
	local step = raw.step or 0.045
	local d = raw.isl and raw.isl.data
	local dust, leaf
	if d and d.path and d.path[1] then dust = Color3.new(1, 1, 1):Lerp(Color3.fromHex(d.path[1]), 0.5) end
	return {
		centre = centre, radius = radius, landing = raw.landing or centre,
		waveStart = raw.waveStart or 0, waveEnd = raw.waveEnd or 2, step = step,
		maxD = math.max(1, ((raw.waveEnd or 2) - 0.8 - (raw.waveStart or 0)) / step),
		edge = edge, dust = dust, leaf = leaf,
	}
end

local function levelUp(Vfx, color: any, scale: number?)
	local p = hen()
	if not p then return end
	Vfx.play("level_up", p, { color = color, scale = scale or 1, follow = hen, punch = Birds.punch })
end

-- companion -> colour of its level-up column
local COMPANIONS = { sparrow = "ffc94a", seagull = "8fd0ff", dave = "e7b6ff", crow = "6fe0ff", parrot = "ff7a7a" }

function Hooks.start(Vfx, remotes: Instance?)
	-- island unlock
	IslandView.onUnlock = function(raw)
		local reduced = false -- IslandView skips the rise under Reduced Motion: nothing to ride then
		pcall(function() reduced = UserSettings():GetService("UserGameSettings").ReducedMotion end)
		if reduced then return end
		local ok, info = pcall(Hooks.unlockInfo, raw)
		if ok then Vfx.play("island_unlock", info.centre, { info = info }) else warn("[Vfx] unlock info: " .. tostring(info)) end
	end
	if remotes then
		-- Evolve / Molt toasts
		local toast = remotes:FindFirstChild("Toast")
		if toast then
			toast.OnClientEvent:Connect(function(kind)
				if kind == "evolve" then levelUp(Vfx, "ff5a8a", 1.25)
				elseif kind == "molt" then levelUp(Vfx, "b06cff", 1.3) end
			end)
		end
		-- companion level-ups (state diff; dev save switches change `mode` and are ignored)
		local state = remotes:FindFirstChild("State")
		if state then
			local last, lastMode, lastFx = nil, nil, 0
			state.OnClientEvent:Connect(function(s, d)
				if type(s) ~= "table" then return end
				local mode = d and d.mode
				local cur = {}
				for k in COMPANIONS do
					local c = s[k]
					cur[k] = type(c) == "table" and c.level or nil
				end
				if last and mode == lastMode and os.clock() - lastFx > 2.5 then
					for k, col in COMPANIONS do
						local a, b = last[k], cur[k]
						if a and b and b > a and b - a <= 25 then
							lastFx = os.clock()
							levelUp(Vfx, col, 1)
							break
						end
					end
				end
				last, lastMode = cur, mode
			end)
		end
	end
	-- ---------------------------------------------------------------- dev preview
	local function preview(name: string?, pos: any, options: { [string]: any }?)
		if name == nil or name == "list" or name == "help" then
			print("[Vfx] effects: " .. table.concat(Vfx.names(), ", ") .. "  |  hatch_all, shake, flash, stop, stats")
			print('[Vfx] _G.__vfx("egg_hatch", "Mythic")  _G.__vfx("collect_pop", nil, {golden = true})  _G.__vfx("island_unlock")')
			return nil
		end
		local opts: { [string]: any } = table.clone(options or {})
		if type(pos) == "string" then opts.rarity = pos; pos = nil end
		if name == "hatch_all" then
			local base = (if typeof(pos) == "Vector3" then pos else hen()) or Vector3.zero
			for i, r in Vfx.Palette.ORDER do
				task.delay((i - 1) * 4.6, function() preview("egg_hatch", base + Vector3.new(0, 0, 6), { rarity = r }) end)
			end
			return nil
		elseif name == "shake" then
			Vfx.shake(opts.amp or 1, opts.dur or 0.4)
			return nil
		elseif name == "flash" then
			Vfx.flash(Vfx.Palette.get(opts.rarity or "Legendary").hi, opts.strength or 0.25, opts.dur or 0.5)
			return nil
		elseif name == "stop" then
			Vfx.stopAll()
			return nil
		elseif name == "stats" then
			print("[Vfx] active", Vfx.activeCount(), "quality", Vfx.quality(), "pieces", Vfx.Layers.stats())
			return nil
		end
		opts.force = true -- show whatever layers exist, even before every texture is uploaded
		local base = if typeof(pos) == "Vector3" then pos elseif typeof(pos) == "CFrame" then pos.Position else hen()
		base = base or Vector3.zero
		if name == "egg_hatch" then
			if opts.preview == nil then opts.preview = true end
			opts.rarity = opts.rarity or "Legendary"
			if pos == nil then base += Vector3.new(0, 0, 6) end -- just in front of the hen (towards the camera)
		elseif name == "collect_pop" then
			if pos == nil then base += Vector3.new(3, 2, 0) end
			opts.groundY = opts.groundY or (base.Y - 2)
		elseif name == "level_up" then
			if pos == nil then opts.follow = opts.follow or hen end
			opts.punch = opts.punch or Birds.punch
		end
		return Vfx.play(name, base, opts)
	end
	_G.__vfx = preview
	local gui = plr:WaitForChild("PlayerGui")
	gui:GetAttributeChangedSignal("PeckwoodVfx"):Connect(function()
		local v = gui:GetAttribute("PeckwoodVfx")
		if typeof(v) ~= "string" then return end
		local body = string.match(v, "^([^#]+)") or v
		local name, arg = string.match(body, "^([%w_]+):?(.*)$")
		if not name then return end
		local opts = {}
		if arg and arg ~= "" then
			if arg == "golden" then opts.golden = true else opts.rarity = arg end
		end
		preview(name, nil, opts)
	end)
end

return Hooks
