--!native
--!optimize 2
-- Per-frame light map: three float channels (warm, cold, void-purple), each in "ramp levels"
-- (1.0 = one shade step brighter). Point lights fall off linearly so the quantised result is
-- evenly spaced concentric rings. Static ambient (with a dark vignette) is kept separately.

local Light = {}
Light.__index = Light

Light.WARM = 1
Light.COLD = 2
Light.VOID = 3

export type Light = typeof(setmetatable(
	{} :: {
		w: number,
		h: number,
		warm: buffer,
		cold: buffer,
		void: buffer,
		ambient: buffer,
		warmBase: buffer?,
	},
	Light
))

function Light.new(w: number, h: number): Light
	local n = w * h * 4
	return setmetatable({
		w = w,
		h = h,
		warm = buffer.create(n),
		cold = buffer.create(n),
		void = buffer.create(n),
		ambient = buffer.create(n),
		warmBase = nil,
	}, Light)
end

-- Ambient: `base` levels at the centre sinking by `vig` toward the corners.
function Light.setAmbient(self: Light, base: number, vig: number)
	local w, h, a = self.w, self.h, self.ambient
	for y = 0, h - 1 do
		local dy = (y + 0.5 - h / 2) / (h / 2)
		for x = 0, w - 1 do
			local dx = (x + 0.5 - w / 2) / (w / 2)
			local d = math.sqrt(dx * dx + dy * dy) / math.sqrt(2)
			local s = math.clamp((d - 0.5) / 0.5, 0, 1)
			s = s * s * (3 - 2 * s)
			buffer.writef32(a, (y * w + x) * 4, base - vig * s)
		end
	end
end

-- Freeze the current warm channel as the static base (e.g. a lantern that never moves); clear()
-- then restores it with one memcpy instead of re-splatting it every frame.
function Light.bakeWarm(self: Light)
	local b = buffer.create(buffer.len(self.warm))
	buffer.copy(b, 0, self.warm)
	self.warmBase = b
end

function Light.clear(self: Light)
	local wb = self.warmBase
	if wb then
		buffer.copy(self.warm, 0, wb)
	else
		buffer.fill(self.warm, 0, 0)
	end
	buffer.fill(self.cold, 0, 0)
	buffer.fill(self.void, 0, 0)
end

function Light.channel(self: Light, ch: number): buffer
	return if ch == 1 then self.warm elseif ch == 2 then self.cold else self.void
end

-- Linear falloff point light: amp at the centre, 0 at radius r. `sy` squashes vertically.
function Light.point(self: Light, ch: number, cx: number, cy: number, r: number, amp: number, sy: number?)
	if amp <= 0 or r <= 0 then
		return
	end
	local buf = self:channel(ch)
	local w, h = self.w, self.h
	local ky = 1 / (sy or 1)
	local ry = r * (sy or 1)
	local x0, x1 = math.max(0, math.floor(cx - r)), math.min(w - 1, math.ceil(cx + r))
	local y0, y1 = math.max(0, math.floor(cy - ry)), math.min(h - 1, math.ceil(cy + ry))
	local inv = 1 / r
	for y = y0, y1 do
		local dy = (y + 0.5 - cy) * ky
		local dy2 = dy * dy
		if dy2 < r * r then
			-- only the span of this row inside the circle
			local span = math.sqrt(r * r - dy2)
			local xa, xb = math.max(x0, math.ceil(cx - span - 0.5)), math.min(x1, math.floor(cx + span - 0.5))
			local row = y * w
			for x = xa, xb do
				local dx = x + 0.5 - cx
				local d = math.sqrt(dx * dx + dy2) * inv
				if d < 1 then
					local o = (row + x) * 4
					buffer.writef32(buf, o, buffer.readf32(buf, o) + amp * (1 - d))
				end
			end
		end
	end
end

return Light
