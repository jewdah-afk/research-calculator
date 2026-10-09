--!nonstrict
-- Vfx/MeshFx: six small EditableMesh VFX shapes, each built ONCE (lazily, in a background thread, pcall-guarded) and
-- handed out as pooled MeshPart clones (Studio test: a clone of an EditableMesh MeshPart renders and shares the mesh;
-- the EditableMesh must stay alive, so it is kept here forever). Budget: the cliff skirt uses most of the EditableMesh
-- memory, so these are tiny (<= ~200 vertices each, 6 meshes total) and every failure just means "no mesh": the
-- effects fall back to their particle layers.
--
-- Shapes (all have per-face colour bands baked as vertex colours: a white leading strip and a 0.72 body, which
-- multiply the clone's Color, + UVs u = along the shape, v = across, for an optional scrolling texture):
--   arc      crescent band: a 210 deg piece of a cylinder wall (radius 1, band along Z in -0.5..0.5) whose height
--            tapers to 0 at both ends. Tilted towards the camera it reads as a crescent slash; Size.Z thins it.
--   spiral   open swirl band (1.3 turns, radius 0.42 -> 1, uneven width), band along Z.
--   wallring tapered ground ring: full circle wall with an uneven height profile and gaps (bottom at z = -0.5).
--            Laid flat (local Z -> world up) it is a shockwave wall; Size.Z thins / collapses it.
--   dome     shockwave dome: open-bottom half sphere, radius 1, y from -0.5 (rim) to +0.5 (top); white rim band.
--   tornado  spiral cone: a band winding 2.4 turns up a cone (radius 0.28 -> 1, y -0.5 -> 0.5).
--   star4    thin 4-point star, flat in XY (white inner star + body ring), for gleams / the level-up ding.
-- Every template's bounding box is forced symmetric (micro helper triangles at opposite corners), so clone scaling
-- never skews whether the engine scales about the origin or the box centre. Set clone Size = size0 * scale vector.
local AssetService = game:GetService("AssetService")

local MeshFx = {}
MeshFx.KINDS = { "arc", "spiral", "wallring", "dome", "tornado", "star4" }
MeshFx.MAX_PER_KIND = 16
MeshFx.enabled = true

local templates = {} -- kind -> MeshPart | false (failed, never retried)
local meshes = {} -- kind -> EditableMesh, kept alive
local size0 = {} -- kind -> template Size (the scale reference)
local building = {}
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

-- ---------------------------------------------------------------- tiny mesh builder
local function newBuilder()
	local ok, em = pcall(function() return AssetService:CreateEditableMesh({}) end)
	if not ok or not em then return nil end
	local b = { em = em, pos = {}, cols = {} }
	function b.v(p: Vector3): number
		local id = em:AddVertex(p)
		b.pos[id] = p
		return id
	end
	function b.col(g: number): number
		local c = b.cols[g]
		if not c then
			c = em:AddColor(Color3.new(g, g, g), 1)
			b.cols[g] = c
		end
		return c
	end
	-- one triangle (+ its back face when double); uvs = { Vector2 x3 }
	function b.tri(a: number, c1: number, c2: number, g: number, uvs, double: boolean?)
		local pa, pb, pc = b.pos[a], b.pos[c1], b.pos[c2]
		local n = (pb - pa):Cross(pc - pa)
		if n.Magnitude < 1e-9 then n = Vector3.zAxis else n = n.Unit end
		local cid = b.col(g)
		local u1, u2, u3 = em:AddUV(uvs[1]), em:AddUV(uvs[2]), em:AddUV(uvs[3])
		local f = em:AddTriangle(a, c1, c2)
		local ni = em:AddNormal(n)
		em:SetFaceNormals(f, { ni, ni, ni })
		em:SetFaceColors(f, { cid, cid, cid })
		em:SetFaceUVs(f, { u1, u2, u3 })
		if double then
			local f2 = em:AddTriangle(a, c2, c1)
			local nb = em:AddNormal(-n)
			em:SetFaceNormals(f2, { nb, nb, nb })
			em:SetFaceColors(f2, { cid, cid, cid })
			em:SetFaceUVs(f2, { u1, u3, u2 })
		end
	end
	-- a strip of cross-sections: sections[i] = { pts = { p1 .. pm }, u = number }, bands[j] = grey of the quad
	-- between points j and j+1. Quads whose section is degenerate on both sides are skipped (gaps / tapered tips).
	function b.strip(sections, bands, double: boolean?, minW: number?)
		local ids = {}
		for i, s in sections do
			ids[i] = {}
			for j, p in s.pts do ids[i][j] = b.v(p) end
		end
		local m = #bands + 1
		for i = 1, #sections - 1 do
			local s0, s1 = sections[i], sections[i + 1]
			local w0 = (s0.pts[m] - s0.pts[1]).Magnitude
			local w1 = (s1.pts[m] - s1.pts[1]).Magnitude
			if w0 < (minW or 1e-3) and w1 < (minW or 1e-3) then continue end
			for j = 1, m - 1 do
				local a, bb, c, d = ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]
				local va, vb = (j - 1) / (m - 1), j / (m - 1)
				b.tri(a, bb, c, bands[j], { Vector2.new(s0.u, va), Vector2.new(s1.u, va), Vector2.new(s1.u, vb) }, double)
				b.tri(a, c, d, bands[j], { Vector2.new(s0.u, va), Vector2.new(s1.u, vb), Vector2.new(s0.u, vb) }, double)
			end
		end
	end
	-- force a symmetric bounding box with two micro triangles at opposite corners
	function b.bounds(hx: number, hy: number, hz: number)
		for _, sgn in { -1, 1 } do
			local p = Vector3.new(hx, hy, hz) * sgn
			local a, c1, c2 = b.v(p), b.v(p + Vector3.new(1e-4, 0, 0)), b.v(p + Vector3.new(0, 1e-4, 0))
			b.tri(a, c1, c2, 1, { Vector2.zero, Vector2.zero, Vector2.zero }, false)
		end
	end
	return b
end

local WHITE, BODY = 1, 0.72

-- ---------------------------------------------------------------- shapes
local BUILD = {}

function BUILD.arc(b)
	local secs = {}
	local SEG = 36
	for i = 0, SEG do
		local s = i / SEG
		local a = math.rad(-105) + s * math.rad(210)
		local h = 0.5 * math.clamp(math.sin(math.pi * s) ^ 0.75 * (1 + 0.18 * math.sin(3 * math.pi * s)), 0, 1)
		local function P(z) local r = 1 + 0.06 * z; return Vector3.new(math.cos(a) * r, math.sin(a) * r, z) end
		table.insert(secs, { u = s, pts = { P(-h), P(h * 0.45), P(h) } })
	end
	b.strip(secs, { BODY, WHITE }, true)
	b.bounds(1.05, 1.05, 0.5)
end

function BUILD.spiral(b)
	local secs = {}
	local SEG = 60
	for i = 0, SEG do
		local s = i / SEG
		local a = s * math.pi * 2 * 1.3
		local r = 0.42 + 0.58 * s
		local taper = math.min(1, s / 0.08, (1 - s) / 0.1)
		local h = 0.5 * math.clamp(taper * (0.55 + 0.45 * math.sin(math.pi * s)) * (1 + 0.3 * math.sin(7 * math.pi * s)), 0, 1)
		local function P(z) return Vector3.new(math.cos(a) * r, math.sin(a) * r, z) end
		table.insert(secs, { u = s, pts = { P(-h), P(h * 0.4), P(h) } })
	end
	b.strip(secs, { BODY, WHITE }, true)
	b.bounds(1.02, 1.02, 0.5)
end

function BUILD.wallring(b)
	local secs = {}
	local SEG = 64
	for i = 0, SEG do
		local s = i / SEG
		local a = s * math.pi * 2
		local g = 0.5 + 0.36 * math.cos(a - 0.5) + 0.2 * math.cos(2 * a + 1.3) + 0.1 * math.cos(3 * a - 0.4)
		local h = math.clamp((g - 0.12) / 0.95, 0, 1) -- 0..1 of the full wall height
		local function P(z) local r = 1 + 0.05 * (z + 0.5); return Vector3.new(math.cos(a) * r, math.sin(a) * r, z) end
		table.insert(secs, { u = s, pts = { P(-0.5), P(-0.5 + h * 0.62), P(-0.5 + h) } })
	end
	b.strip(secs, { BODY, WHITE }, true, 0.01)
	b.bounds(1.06, 1.06, 0.5)
end

function BUILD.dome(b)
	local RINGS, SEG = 6, 24
	local secs = {}
	-- built as a strip per meridian: section = one meridian from rim to top
	for i = 0, SEG do
		local a = i / SEG * math.pi * 2
		local pts = {}
		for k = 0, RINGS do
			local phi = k / RINGS * math.pi / 2 * 0.985
			local rr = math.cos(phi)
			table.insert(pts, Vector3.new(math.cos(a) * rr, -0.5 + math.sin(phi), math.sin(a) * rr))
		end
		table.insert(secs, { u = i / SEG, pts = pts })
	end
	local bands = {}
	for k = 1, RINGS do bands[k] = if k == 1 then WHITE else BODY end
	b.strip(secs, bands, true)
	b.bounds(1.0, 0.5, 1.0)
end

function BUILD.tornado(b)
	local secs = {}
	local SEG = 72
	for i = 0, SEG do
		local s = i / SEG
		local a = s * math.pi * 2 * 2.4
		local y = -0.47 + s * 0.88
		local r = 0.28 + 0.72 * s ^ 0.85
		local taper = math.min(1, s / 0.1, (1 - s) / 0.1)
		local h = 0.075 * taper * (0.7 + 0.3 * math.sin(9 * s))
		local function P(dy, k) return Vector3.new(math.cos(a) * r * k, y + dy, math.sin(a) * r * k) end
		table.insert(secs, { u = s, pts = { P(-h, 1), P(h * 0.2, 1.01), P(h, 1.03) } })
	end
	b.strip(secs, { BODY, WHITE }, true)
	b.bounds(1.04, 0.5, 1.04)
end

function BUILD.star4(b)
	-- outline: 4 needle tips (radius 1) with concave sides and tiny valleys (0.16 at 45 deg)
	local function outline(k)
		local pts = {}
		for q = 0, 3 do
			local tip = q * math.pi / 2
			for side = 0, 1 do
				local a0 = if side == 0 then tip - math.pi / 4 else tip
				local a1 = if side == 0 then tip else tip + math.pi / 4
				local r0 = if side == 0 then 0.16 else 1
				local r1 = if side == 0 then 1 else 0.16
				for n = 0, 5 do
					local t = n / 6
					local a = a0 + (a1 - a0) * t
					local r = (r0 + (r1 - r0) * t) * (1 - 0.18 * math.sin(math.pi * t))
					table.insert(pts, Vector3.new(math.cos(a) * r * k, math.sin(a) * r * k, 0))
				end
			end
		end
		return pts
	end
	local outer, inner = outline(1), outline(0.55)
	local c = b.v(Vector3.zero)
	local io, ii = {}, {}
	for n, p in outer do io[n] = b.v(p) end
	for n, p in inner do ii[n] = b.v(p) end
	local function uv(p) return Vector2.new(p.X * 0.5 + 0.5, p.Y * 0.5 + 0.5) end
	local m = #outer
	for n = 1, m do
		local n2 = n % m + 1
		b.tri(c, ii[n], ii[n2], WHITE, { Vector2.new(0.5, 0.5), uv(inner[n]), uv(inner[n2]) }, true)
		b.tri(ii[n], io[n], io[n2], BODY, { uv(inner[n]), uv(outer[n]), uv(outer[n2]) }, true)
		b.tri(ii[n], io[n2], ii[n2], BODY, { uv(inner[n]), uv(outer[n2]), uv(inner[n2]) }, true)
	end
	b.bounds(1.0, 1.0, 0.05)
end

-- ---------------------------------------------------------------- templates (lazy, background, pcall-guarded)
local function build(kind: string)
	if templates[kind] ~= nil or building[kind] then return end
	building[kind] = true
	local ok, res = pcall(function()
		local b = newBuilder()
		if not b then error("CreateEditableMesh failed (memory budget?)") end
		BUILD[kind](b)
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(b.em))
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
		meshes[kind] = b.em
		return mp
	end)
	building[kind] = nil
	if ok and res then
		templates[kind] = res
		size0[kind] = res.Size
		res.Parent = parentFolder()
	else
		templates[kind] = false
		warn("[Vfx] mesh '" .. kind .. "' unavailable, using particles: " .. tostring(res))
	end
end

-- build every shape in the background, one per frame-ish (call once at start; get() also triggers a build)
function MeshFx.warm()
	if not MeshFx.enabled then return end
	task.spawn(function()
		for _, kind in MeshFx.KINDS do
			build(kind)
			task.wait(0.05)
		end
	end)
end

function MeshFx.ready(kind: string): boolean
	return MeshFx.enabled and templates[kind] ~= nil and templates[kind] ~= false
end

-- a pooled clone (or nil: not built yet / failed / capped). Never yields.
function MeshFx.get(kind: string): MeshPart?
	if not MeshFx.enabled then return nil end
	local t = templates[kind]
	if t == nil then
		task.spawn(build, kind)
		return nil
	end
	if t == false then return nil end
	local list = free[kind]
	local p = list and table.remove(list)
	if not (p and p.Parent) then
		if (live[kind] or 0) >= MeshFx.MAX_PER_KIND then return nil end
		p = t:Clone()
		p.Parent = parentFolder()
	end
	live[kind] = (live[kind] or 0) + 1
	p.Size = size0[kind] -- explicit, from the template (QA: an unset clone once rendered skewed)
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

function MeshFx.size(kind: string): Vector3
	return size0[kind] or Vector3.one
end

-- optional: slide every clone's texture along u (UVs are shared by the clones of one shape)
function MeshFx.scrollUV(kind: string, du: number)
	local em = meshes[kind]
	if not em then return end
	pcall(function()
		for _, id in em:GetUVs() do
			local uv = em:GetUV(id)
			em:SetUV(id, Vector2.new(uv.X + du, uv.Y))
		end
	end)
end

function MeshFx.stats()
	local out = {}
	for _, k in MeshFx.KINDS do
		out[k] = { ready = MeshFx.ready(k), live = live[k] or 0 }
	end
	return out
end

return MeshFx
