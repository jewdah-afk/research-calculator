--!strict
--[[
	Fields: the three particle fields of art/REALM.md 6.3 (motesFar at f .7, motesNear at 1.3, particles at 1.6),
	drawn every frame from pools of ImageLabels in full-Box frames (F_motesFar, F_motesNear, F_particles).

	    local fields = Fields.new({ realm, frames, atlas, tier })
	    fields:step(t, C, z, V, w)      place every visible particle copy (MapCamera.fieldVisit), colour it (5)
	    fields:setAlpha("motesNear", k) the side-sheet fade of motesNear
	    fields:setReduced(b)            reduced motion: motesNear and particles hidden, motesFar frozen at t = 0
	    fields:setEnabled(b)            a full-screen panel covers the map: stop drawing

	Positions are Scale units of the Box (REALM.md 2.6), so nothing here depends on the device scale. A pool entry
	is written only when a value changed. Without the realm atlas the fields are skipped.
]]

local MapCamera = require(script.Parent:WaitForChild("MapCamera"))

local Fields = {}

type Pt = MapCamera.Pt
type Size = MapCamera.Size
type Weights = MapCamera.Weights

export type Atlas = { id: string, regions: { [string]: { number } }, k: number }
export type Options = { realm: any, frames: { [string]: Frame }, atlas: Atlas?, tier: string }
export type Fields = {
	step: (self: Fields, t: number, C: Pt, z: number, V: Size, w: Weights) -> (),
	setAlpha: (self: Fields, id: string, k: number) -> (),
	setReduced: (self: Fields, b: boolean) -> (),
	setEnabled: (self: Fields, b: boolean) -> (),
	destroy: (self: Fields) -> (),
}

type Entry = { img: ImageLabel, region: string, x: number, y: number, s: number, a: number, c: Color3?, shown: boolean }
type Field = { def: any, particles: { any }, frame: Frame, pool: { Entry }, alpha: number, used: number }

function Fields.new(o: Options): Fields
	local atlas = o.atlas
	local B = o.realm.biome
	local list: { Field } = {}
	local reduced = false
	local enabled = true
	local self = {} :: Fields

	if atlas then
		for _, def in o.realm.fields do
			local frame = o.frames[def.id]
			if not frame then continue end
			local parts = {}
			for _, p in def.particles do
				if o.tier ~= "LOW" or p.low == 1 then table.insert(parts, p) end
			end
			local pool: { Entry } = {}
			local n = def.pool[o.tier] or def.pool.HIGH
			for i = 1, n do
				local img = Instance.new("ImageLabel")
				img.Name = "P" .. i
				img.BackgroundTransparency = 1
				img.BorderSizePixel = 0
				img.Active = false
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Image = atlas.id
				img.Visible = false
				img.Parent = frame
				pool[i] = { img = img, region = "", x = -1, y = -1, s = -1, a = -1, c = nil, shown = false }
			end
			table.insert(list, { def = def, particles = parts, frame = frame, pool = pool, alpha = 1, used = 0 })
		end
	end

	local function setRegion(e: Entry, name: string)
		if e.region == name or atlas == nil then return end
		local r = atlas.regions[name]
		if r == nil then return end
		e.region = name
		local k = atlas.k
		e.img.ImageRectOffset = Vector2.new(r[1] * k, r[2] * k)
		e.img.ImageRectSize = Vector2.new(r[3] * k, r[4] * k)
	end
	local function hideFrom(f: Field, from: number)
		for i = from, #f.pool do
			local e = f.pool[i]
			if e.shown then
				e.shown = false
				e.img.Visible = false
			end
		end
	end
	local kindCache: { [any]: { [string]: any } } = {}
	local function kindOf(def: any, name: string): any
		local byName = kindCache[def]
		if byName == nil then
			byName = {}
			for _, k in def.kinds do (byName :: any)[k.name] = k end
			kindCache[def] = byName
		end
		return (byName :: any)[name]
	end

	function self.step(_: Fields, t: number, C: Pt, z: number, V: Size, w: Weights)
		if not enabled then return end
		for _, f in list do
			local def = f.def
			if reduced and def.id ~= "motesFar" then
				hideFrom(f, 1)
				f.frame.Visible = false
				continue
			end
			if f.alpha <= 0.001 then
				hideFrom(f, 1)
				f.frame.Visible = false
				continue
			end
			f.frame.Visible = true
			local time = if reduced then 0 else t
			local used = 0
			local pool = f.pool
			local k = f.alpha
			MapCamera.fieldVisit(def, f.particles, C, z, V, time, function(i: number, x: number, y: number, size: number, alpha: number): boolean?
				used += 1
				local e = pool[used]
				local p = f.particles[i]
				local kind = kindOf(def, p.k)
				if kind then setRegion(e, kind.regions[(p.t or 0) + 1] or kind.regions[1]) end
				local sx, sy = x / V.w, y / V.h
				if sx ~= e.x or sy ~= e.y then
					e.x, e.y = sx, sy
					e.img.Position = UDim2.fromScale(sx, sy)
				end
				if size ~= e.s then
					e.s = size
					e.img.Size = UDim2.fromScale(size / V.w, size / V.h)
				end
				local a = math.floor(alpha * k * 200 + 0.5) / 200
				if a ~= e.a then
					e.a = a
					e.img.ImageTransparency = 1 - a
				end
				if kind then
					local world = MapCamera.screenToWorld(C, z, V, { x = x, y = y })
					local c = MapCamera.biomeFieldColor(kind, p.c or 0, p.cg or 0.5, w, B, world)
					local col = Color3.fromRGB(c[1], c[2], c[3])
					if col ~= e.c then
						e.c = col
						e.img.ImageColor3 = col
					end
				end
				if not e.shown then
					e.shown = true
					e.img.Visible = true
				end
				return used >= #pool
			end)
			f.used = used
			hideFrom(f, used + 1)
		end
	end
	function self.setAlpha(_: Fields, id: string, k: number)
		for _, f in list do
			if f.def.id == id then f.alpha = k end
		end
	end
	function self.setReduced(_: Fields, b: boolean)
		reduced = b
	end
	function self.setEnabled(_: Fields, b: boolean)
		enabled = b
		if not b then
			for _, f in list do hideFrom(f, 1) end
		end
	end
	function self.destroy(_: Fields)
		for _, f in list do
			for _, e in f.pool do e.img:Destroy() end
		end
		table.clear(list)
	end
	return self
end

return Fields
