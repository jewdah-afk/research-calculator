--!nonstrict
-- Vfx/MeshFx: VFX mesh shapes from Creator Store MESH assets (no scripts inside a mesh asset), loaded at runtime with
-- AssetService:CreateMeshPartAsync and handed out as pooled MeshPart clones. They cost NO EditableMesh slots: Roblox
-- caps live EditableMeshes at ~7 per client (fewer on phones) and the map uses 2, so the VFX uses 0 (QA round 2).
-- Everything is optional: a shape that fails to load, or is not loaded yet, returns nil and the effect plays its
-- particle layer instead.
--
-- Each asset's orientation is detected from its bounding box (template Size), so an export with Y-up or Z-up both
-- work: "plane" shapes (crescent, swirl, star, flat rings) use the THINNEST axis as their normal; "up" shapes (dome,
-- tornado, shock wall) use the odd-one-out axis (the one unlike the two equal diameters) as their axis. Per asset
-- `flip` turns it over, `alt` is a second id tried if the first fails. Swap ids here if a shape looks wrong in Studio.
local AssetService = game:GetService("AssetService")

local MeshFx = {}
MeshFx.enabled = true
MeshFx.MAX_PER_KIND = 16

-- Creator Store mesh assets (free, mesh-only). frame: "plane" (normal -> local Z) | "up" (axis -> local Y)
MeshFx.ASSETS = {
	crescent = { id = "92572984944785", alt = "129794830935741", frame = "plane" }, -- "Meshes/wide crescent vfx" (alt "long crescent")
	swirl = { id = "10895746627", alt = "2671071349", frame = "plane" }, -- "wind" swirl (alt "Swirl" spiral)
	wall = { id = "131187152008585", alt = "2788580299", frame = "up" }, -- "Meshes/Tall Shockwave" ring wall (alt "Meshes/shockwave")
	ringgap = { id = "7741808274", alt = "7753130413", frame = "plane" }, -- Akron "Circle4Gaps_Smooth" broken ring (alt 8 gaps)
	ring = { id = "7263678713", alt = "12640000893", frame = "plane" }, -- Akron "Pipe_Circle_Thin_Smooth" thin ring (alt "Smooth Torus 1")
	dome = { id = "7349045196", alt = "7349045384", frame = "up" }, -- Akron "Spheres_Sphere_Half" (alt 1-sided)
	tornado = { id = "7029892192", alt = "7028996145", frame = "up" }, -- "Tornado VFX" (alt "Cyliner Tornado VFX")
	star4 = { id = "15591537807", alt = "2620058380", frame = "plane" }, -- "4Star" (alt "Meshes/Flash")
}
MeshFx.KINDS = { "crescent", "swirl", "wall", "ringgap", "ring", "dome", "tornado", "star4" }

local templates = {} -- kind -> { part, size0, ax (1..3), corr (CFrame), frame } | false
local loading = {}
local free = {}
local live = {}
local FAR = CFrame.new(0, -25000, 0)
local folder: Folder? = nil

local function parentFolder(): Folder
	if folder and folder.Parent then return folder end
	local f = workspace:FindFirstChild("PeckwoodVfxParts")
	if not f then
		f = Instance.new("Folder")
		f.Name = "PeckwoodVfxParts"
		f.Parent = workspace
	end
	folder = f :: Folder
	return f :: Folder
end

local function comp(v: Vector3, i: number): number
	return if i == 1 then v.X elseif i == 2 then v.Y else v.Z
end

-- which local axis of the mesh is its normal ("plane") or its axis ("up")
local function detectAxis(size: Vector3, frame: string): number
	local d = { size.X, size.Y, size.Z }
	if frame == "plane" then
		local best = 1
		for i = 2, 3 do if d[i] < d[best] then best = i end end
		return best
	end
	-- "up": the axis whose size is least like the other two (which are equal diameters); a cube-ish bbox -> Y
	local score = {}
	for i = 1, 3 do
		local a, b = d[(i % 3) + 1], d[((i + 1) % 3) + 1]
		score[i] = if math.abs(a - b) <= 0.08 * math.max(a, b) then math.abs(d[i] - (a + b) / 2) else -1
	end
	local best = 2
	for i = 1, 3 do if score[i] > score[best] then best = i end end
	if best ~= 2 and score[best] - math.max(score[2], 0) < 0.05 * math.max(d[1], d[2], d[3]) then best = 2 end
	return best
end

-- rotation that takes mesh axis `ax` onto our local axis `t` (3 = Z for "plane", 2 = Y for "up")
local function correction(ax: number, t: number): CFrame
	if ax == t then return CFrame.identity end
	if t == 3 then
		return if ax == 2 then CFrame.Angles(math.pi / 2, 0, 0) else CFrame.Angles(0, -math.pi / 2, 0)
	end
	return if ax == 3 then CFrame.Angles(-math.pi / 2, 0, 0) else CFrame.Angles(0, 0, math.pi / 2)
end

local function createFrom(id: string): MeshPart?
	local uri = "rbxassetid://" .. id
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(uri), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if ok and mp then return mp end
	ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(uri) end) -- older signature
	if ok and mp then return mp end
	return nil
end

local function load(kind: string)
	if templates[kind] ~= nil or loading[kind] then return end
	local spec = MeshFx.ASSETS[kind]
	if not spec then templates[kind] = false; return end
	loading[kind] = true
	local mp = createFrom(spec.id) or (spec.alt and createFrom(spec.alt))
	loading[kind] = nil
	if not mp then
		templates[kind] = false
		warn("[Vfx] mesh asset '" .. kind .. "' did not load, using particles")
		return
	end
	mp.Name = "VfxMesh_" .. kind
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.CastShadow = false
	mp.Material = Enum.Material.Neon
	mp.Color = Color3.new(1, 1, 1)
	mp.Transparency = 1
	mp.CFrame = FAR
	pcall(function() mp.DoubleSided = true end) -- plugin-only on some versions; the meshes read from one side anyway
	mp.Parent = parentFolder()
	local size0 = mp.Size
	local t = if spec.frame == "up" then 2 else 3
	local ax = spec.axis or detectAxis(size0, spec.frame)
	local corr = correction(ax, t)
	if spec.flip then corr = corr * CFrame.Angles(math.pi, 0, 0) end
	templates[kind] = { part = mp, size0 = size0, ax = ax, t = t, corr = corr, frame = spec.frame }
end

-- load every shape in the background (call once at start; get() also triggers a load)
function MeshFx.warm()
	if not MeshFx.enabled then return end
	task.spawn(function()
		for _, kind in MeshFx.KINDS do
			load(kind)
			task.wait(0.03)
		end
	end)
end

function MeshFx.ready(kind: string): boolean
	local t = templates[kind]
	return MeshFx.enabled and t ~= nil and t ~= false
end

function MeshFx.template(kind: string)
	local t = templates[kind]
	return if t then t else nil
end

-- a pooled clone (or nil: not loaded yet / failed / capped). Never yields.
function MeshFx.get(kind: string): MeshPart?
	if not MeshFx.enabled then return nil end
	local t = templates[kind]
	if t == nil then
		task.spawn(load, kind)
		return nil
	end
	if t == false then return nil end
	local list = free[kind]
	local p = list and table.remove(list)
	if not (p and p.Parent) then
		if (live[kind] or 0) >= MeshFx.MAX_PER_KIND then return nil end
		p = t.part:Clone()
		p.Parent = parentFolder()
	end
	live[kind] = (live[kind] or 0) + 1
	p.Size = t.size0 -- explicit, from the template (QA: an unset clone once rendered skewed)
	return p
end

function MeshFx.put(kind: string, p: MeshPart)
	live[kind] = math.max(0, (live[kind] or 0) - 1)
	p.Transparency = 1
	p.CFrame = FAR -- parked far away: an invisible mesh must never sit in front of an outlined model
	if p.Parent then
		free[kind] = free[kind] or {}
		table.insert(free[kind], p)
	end
end

-- part Size for a desired size in OUR frame: D = (in-plane / X, axis-or-Y, in-plane / Z) for "up", (X, Y, normal)
-- for "plane". inPlane = studs across (the larger in-plane extent of the mesh maps to it, aspect kept), axisLen =
-- studs along the normal / axis (nil = keep the mesh's own proportion), xm / ym squash the two in-plane directions.
function MeshFx.sizeFor(kind: string, inPlane: number, axisLen: number?, xm: number?, ym: number?): Vector3
	local t = templates[kind]
	if not t then return Vector3.one end
	local s0 = t.size0
	local others = {}
	for i = 1, 3 do if i ~= t.ax then table.insert(others, i) end end
	local big = math.max(comp(s0, others[1]), comp(s0, others[2]), 1e-3)
	local k = inPlane / big
	local out = { 0, 0, 0 }
	out[others[1]] = comp(s0, others[1]) * k * (xm or 1)
	out[others[2]] = comp(s0, others[2]) * k * (ym or 1)
	out[t.ax] = axisLen or comp(s0, t.ax) * k
	return Vector3.new(math.max(out[1], 0.01), math.max(out[2], 0.01), math.max(out[3], 0.01))
end

-- the half-length of the mesh along OUR axis for a given part Size (to sit a dome / wall on the ground)
function MeshFx.halfAxis(kind: string, size: Vector3): number
	local t = templates[kind]
	if not t then return 0 end
	return comp(size, t.ax) / 2
end

function MeshFx.corr(kind: string): CFrame
	local t = templates[kind]
	return if t then t.corr else CFrame.identity
end

function MeshFx.stats()
	local out = {}
	for _, k in MeshFx.KINDS do
		out[k] = { ready = MeshFx.ready(k), live = live[k] or 0 }
	end
	return out
end

MeshFx.EDITABLE_MESHES = 0 -- live EditableMeshes the VFX holds at peak (budget: <= 2; the map uses 2 of ~7)

return MeshFx
